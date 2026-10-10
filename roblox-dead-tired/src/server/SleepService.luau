--[[
	SleepService — la boucle centrale du jeu.

	Quand un joueur dort :
	  • il gagne `Tier.Rate × multiplicateurs` dollars par seconde, dans sa poche
	    non déposée ;
	  • toutes les `RiskTickInterval` secondes, on tire un dé contre
	    `Tier.DetectChance × multiplicateur de discrétion`.

	Si le dé tombe : le joueur est RÉVEILLÉ par l'alerte et le monstre part vers
	sa planque. Il a `WarningLead + bonus` secondes pour décoller. C'est cette
	fenêtre qui fait que les paliers profonds sont jouables au skill, et pas une
	simple loterie — voir docs/DESIGN.md.
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local SleepService = {}

local services
-- state[player] = { Spot, Tier, StartedAt, Earned, NextRiskAt, Alerted }
local state: { [Player]: any } = {}

function SleepService.init(registry)
	services = registry
end

-- ─── lecture d'état ─────────────────────────────────────────────────────────

function SleepService.isSleeping(player: Player): boolean
	return state[player] ~= nil
end

--[[ Résumé envoyé au client pour le HUD. nil si le joueur ne dort pas. ]]
function SleepService.describe(player: Player)
	local entry = state[player]
	if not entry then
		return nil
	end
	local tierData = GameConfig.Tiers[entry.Tier]
	local modifiers = services.Economy.getModifiers(player)
	return {
		Tier = entry.Tier,
		TierName = tierData.Name,
		SpotLabel = services.Zone.getLabel(entry.Spot),
		RatePerSecond = tierData.Rate * modifiers.Earn,
		-- risque effectif par tick, en %, ce que le joueur doit vraiment voir
		RiskPercent = tierData.DetectChance * modifiers.Detect * 100,
		Earned = entry.Earned,
		SecondsToNextRoll = math.max(0, entry.NextRiskAt - os.clock()),
		TickInterval = GameConfig.Round.RiskTickInterval,
	}
end

-- ─── entrer / sortir du sommeil ─────────────────────────────────────────────

local function anchorCharacter(player: Player, spot: BasePart, anchored: boolean)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return
	end

	if anchored then
		-- On pose le personnage sur la planque, puis on le fige.
		local target = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + 2.5, 0)
		character:PivotTo(target)
		root.Anchored = true
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	else
		root.Anchored = false
		humanoid.AutoRotate = true
		humanoid.JumpPower = 50
		services.Economy.applyWalkSpeed(player)
	end
end

function SleepService.tryStart(player: Player, spot: BasePart)
	if not spot or not spot.Parent then
		return
	end
	if state[player] then
		services.Notify.send(player, "Tu dors déjà.", "info")
		return
	end
	if services.Life.isDown(player) then
		return
	end
	if services.Round.getPhase() ~= "Night" then
		services.Notify.send(player, "C'est le jour. Dépose, achète, et attends la nuit.", "info")
		return
	end

	local tier = services.Zone.getTier(spot)

	if services.Zone.isVip(spot) and not services.Monetization.ownsPass(player, "VipRoom") then
		services.Notify.send(player, "Chambre VIP — réservée aux détenteurs du pass.", "info")
		return
	end

	local allowed, reason = services.Progression.canUse(player, tier)
	if not allowed then
		services.Notify.send(player, reason or "Planque verrouillée.", "info")
		return
	end

	if not services.Zone.claim(spot, player) then
		services.Notify.send(player, "Quelqu'un dort déjà là.", "info")
		return
	end

	state[player] = {
		Spot = spot,
		Tier = tier,
		StartedAt = os.clock(),
		Earned = 0,
		NextRiskAt = os.clock() + GameConfig.Round.RiskTickInterval,
		Alerted = false,
	}

	anchorCharacter(player, spot, true)

	local profile = services.Data.get(player)
	if profile and tier > (profile.DeepestTier or 1) then
		profile.DeepestTier = tier
	end

	;(Net.get("SleepChanged") :: RemoteEvent):FireClient(player, true, SleepService.describe(player))
	services.Economy.push(player)
end

--[[ reason : "manual" | "alert" | "caught" | "dawn" | "left" ]]
function SleepService.stop(player: Player, reason: string)
	local entry = state[player]
	if not entry then
		return
	end
	state[player] = nil
	services.Zone.release(entry.Spot)

	if reason ~= "left" then
		anchorCharacter(player, entry.Spot, false)
	end

	;(Net.get("SleepChanged") :: RemoteEvent):FireClient(player, false, nil)

	if reason == "manual" then
		services.Notify.send(player, ("Réveillé. %d $ sur toi — ramène-les au coffre."):format(
			services.Economy.getUnbanked(player)), "info")
	end

	services.Economy.push(player)
end

function SleepService.requestWake(player: Player)
	if not state[player] then
		return
	end
	SleepService.stop(player, "manual")
end

function SleepService.stopAll(reason: string)
	for player in pairs(state) do
		SleepService.stop(player, reason)
	end
end

function SleepService.getSpotOf(player: Player): BasePart?
	local entry = state[player]
	return entry and entry.Spot or nil
end

function SleepService.onPlayerRemoving(player: Player)
	if state[player] then
		SleepService.stop(player, "left")
	end
	services.Zone.releaseAllFor(player)
end

-- ─── la boucle ──────────────────────────────────────────────────────────────

local function rollRisk(player: Player, entry)
	local tierData = GameConfig.Tiers[entry.Tier]
	local modifiers = services.Economy.getModifiers(player)
	local chance = tierData.DetectChance * modifiers.Detect

	if chance <= 0 then
		return
	end
	if math.random() >= chance then
		return
	end

	-- Repéré. On réveille, on prévient, et le monstre se met en route.
	entry.Alerted = true
	local window = GameConfig.Round.WarningLead + modifiers.Warning
	local spot = entry.Spot

	SleepService.stop(player, "alert")
	;(Net.get("DangerAlert") :: RemoteEvent):FireClient(player, window)
	services.Notify.send(player, "Un bruit. Il vient par ici — BOUGE.", "danger")
	services.Threat.beginHunt(spot, player, window)
end

function SleepService.start()
	local accumulator = 0
	local pushAccumulator = 0

	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		pushAccumulator += deltaTime
		if accumulator < 0.25 then
			return
		end
		local step = accumulator
		accumulator = 0

		local now = os.clock()

		for player, entry in pairs(state) do
			if not player.Parent then
				state[player] = nil
				services.Zone.release(entry.Spot)
			else
				local tierData = GameConfig.Tiers[entry.Tier]
				local modifiers = services.Economy.getModifiers(player)

				-- Gains (silencieux : on pousse l'état plus bas, 2 fois/s)
				local gain = tierData.Rate * modifiers.Earn * step
				entry.Earned += gain
				services.Economy.addUnbanked(player, gain, true)

				-- Tirage de risque
				if now >= entry.NextRiskAt then
					entry.NextRiskAt = now + GameConfig.Round.RiskTickInterval
					rollRisk(player, entry)
				end
			end
		end

		-- Rafraîchissement du HUD des dormeurs, deux fois par seconde.
		if pushAccumulator >= 0.5 then
			pushAccumulator = 0
			for player in pairs(state) do
				services.Economy.push(player)
			end
		end
	end)
end

return SleepService
