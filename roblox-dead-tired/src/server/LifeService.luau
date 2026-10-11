--[[
	LifeService — être à terre, saigner, se faire relever.

	C'est le levier coopératif du jeu : quand quelqu'un est attrapé, il n'est pas
	mort, il est à terre. Un coéquipier peut le relever, mais il doit rester
	immobile 6 secondes à côté — donc à portée du monstre. Décider si ça vaut le
	coup, c'est le moment le plus intéressant d'une partie en multi.

	Récompense : celui qui relève récupère la moitié de l'argent que la victime
	avait perdu (voir GameConfig.Economy.UnbankedRecoveredOnRevive) — sinon
	personne ne prendrait le risque.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local LifeService = {}

local services
-- downed[player] = { At, BleedoutAt, LostAmount, Prompt, Reviver, HoldStart }
local downed: { [Player]: any } = {}
local freeReviveUsed: { [Player]: boolean } = {}

function LifeService.init(registry)
	services = registry
end

function LifeService.isDown(player: Player): boolean
	return downed[player] ~= nil
end

function LifeService.describe(player: Player)
	local entry = downed[player]
	if not entry then
		return nil
	end
	return {
		Down = true,
		SecondsLeft = math.max(0, entry.BleedoutAt - os.clock()),
		BleedoutSeconds = GameConfig.Downed.BleedoutSeconds,
		LostAmount = entry.LostAmount,
		BeingRevivedBy = entry.Reviver and entry.Reviver.Name or nil,
		ReviveProgress = entry.Reviver
			and math.clamp((os.clock() - entry.HoldStart) / GameConfig.Downed.ReviveHoldSeconds, 0, 1)
			or 0,
	}
end

-- ─── mise à terre ───────────────────────────────────────────────────────────

local function setRagdollLike(player: Player, down: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if down then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.PlatformStand = true
	else
		humanoid.PlatformStand = false
		humanoid.JumpPower = 50
		services.Economy.applyWalkSpeed(player)
	end
end

local function attachRevivePrompt(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Relever"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = GameConfig.Downed.ReviveHoldSeconds
	prompt.MaxActivationDistance = GameConfig.Downed.ReviveRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root

	prompt.PromptButtonHoldBegan:Connect(function(reviver)
		local entry = downed[player]
		if entry and not entry.Reviver then
			entry.Reviver = reviver
			entry.HoldStart = os.clock()
			services.Economy.push(player)
			services.Notify.send(reviver, ("Tu relèves %s. Ne bouge pas."):format(player.DisplayName), "info")
		end
	end)

	prompt.PromptButtonHoldEnded:Connect(function(reviver)
		local entry = downed[player]
		if entry and entry.Reviver == reviver then
			entry.Reviver = nil
			services.Economy.push(player)
		end
	end)

	prompt.Triggered:Connect(function(reviver)
		LifeService.revive(player, reviver)
	end)

	return prompt
end

--[[ Le joueur a été attrapé. ]]
function LifeService.down(player: Player, cause: string?)
	if downed[player] then
		return
	end
	if not player.Character then
		return
	end

	services.Sleep.stop(player, "caught")

	local lost = services.Economy.wipeUnbanked(player, GameConfig.Economy.UnbankedLossOnCatch)

	-- Pass "Seconde chance" : une réanimation gratuite par nuit.
	if not freeReviveUsed[player] and services.Monetization.ownsPass(player, "ExtraLife") then
		freeReviveUsed[player] = true
		services.Notify.send(player, "Seconde chance utilisée. Tu te relèves seul.", "unlock")
		services.Economy.addUnbanked(player, lost)
		return
	end

	-- Trousse de secours : se relever tout seul.
	if services.Shop.consume(player, "medkit") then
		services.Notify.send(player, "Trousse de secours utilisée. Debout.", "cash")
		services.Economy.addUnbanked(player, math.floor(lost * GameConfig.Economy.UnbankedRecoveredOnRevive))
		return
	end

	downed[player] = {
		At = os.clock(),
		BleedoutAt = os.clock() + GameConfig.Downed.BleedoutSeconds,
		LostAmount = lost,
		Reviver = nil,
		HoldStart = 0,
	}
	downed[player].Prompt = attachRevivePrompt(player)

	setRagdollLike(player, true)

	services.Notify.send(player, ("Il t'a eu. −%d $. Un coéquipier peut te relever."):format(lost), "danger")
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			services.Notify.send(other, ("%s est à terre."):format(player.DisplayName), "danger")
		end
	end
	services.Economy.push(player)
end

--[[ Relève le joueur. reviver = nil pour un relevage automatique (aube, produit). ]]
function LifeService.revive(player: Player, reviver: Player?)
	local entry = downed[player]
	if not entry then
		return
	end
	downed[player] = nil

	if entry.Prompt then
		entry.Prompt:Destroy()
	end
	setRagdollLike(player, false)

	local recovered = math.floor(entry.LostAmount * GameConfig.Economy.UnbankedRecoveredOnRevive)
	if recovered > 0 then
		services.Economy.addUnbanked(player, recovered)
	end

	if reviver then
		services.Notify.send(player, ("%s t'a relevé. +%d $ récupérés."):format(reviver.DisplayName, recovered), "cash")
		-- Celui qui prend le risque touche la même somme : sans ça, personne ne vient.
		if recovered > 0 then
			services.Economy.addUnbanked(reviver, recovered)
			services.Notify.send(reviver, ("Sauvetage réussi. +%d $."):format(recovered), "cash")
		end
	else
		services.Notify.send(player, "Tu reprends tes esprits.", "info")
	end

	services.Economy.push(player)
	if reviver then
		services.Economy.push(reviver)
	end
end

--[[ Mort définitive : personne n'est venu. ]]
local function bleedOut(player: Player)
	local entry = downed[player]
	if not entry then
		return
	end
	downed[player] = nil
	if entry.Prompt then
		entry.Prompt:Destroy()
	end
	services.Notify.send(player, "Tu n'as pas tenu. Tu repars à l'entrée.", "danger")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
	services.Economy.push(player)
end

function LifeService.reviveAll()
	for player in pairs(downed) do
		LifeService.revive(player, nil)
	end
end

function LifeService.resetNightFlags()
	freeReviveUsed = {}
end

function LifeService.onPlayerRemoving(player: Player)
	local entry = downed[player]
	if entry and entry.Prompt then
		entry.Prompt:Destroy()
	end
	downed[player] = nil
	freeReviveUsed[player] = nil
end

function LifeService.start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator += deltaTime
		if accumulator < 0.5 then
			return
		end
		accumulator = 0

		local now = os.clock()
		for player, entry in pairs(downed) do
			if not player.Parent then
				downed[player] = nil
			else
				-- Le secouriste s'est éloigné ? On annule.
				if entry.Reviver then
					local reviverChar = entry.Reviver.Character
					local victimChar = player.Character
					local tooFar = true
					if reviverChar and victimChar and reviverChar.PrimaryPart and victimChar.PrimaryPart then
						tooFar = (reviverChar.PrimaryPart.Position - victimChar.PrimaryPart.Position).Magnitude
							> GameConfig.Downed.ReviveRange + 2
					end
					if tooFar then
						entry.Reviver = nil
					end
				end

				if now >= entry.BleedoutAt then
					bleedOut(player)
				else
					services.Economy.push(player)
				end
			end
		end
	end)
end

return LifeService
