--!strict
-- Point d'entrée serveur. Tout le câblage est ici, et nulle part ailleurs :
-- les services ne se connaissent que par appel direct, jamais par événement
-- global, pour qu'on puisse lire le jeu de haut en bas depuis ce fichier.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local GameConfig = require(Shared.GameConfig)
local MissionConfig = require(Shared.MissionConfig)
local MonsterConfig = require(Shared.MonsterConfig)
local Net = require(Shared.Net)
local ZoneConfig = require(Shared.ZoneConfig)

local CityBuilder = require(script.CityBuilder)
local CombatService = require(script.CombatService)
local EconomyService = require(script.EconomyService)
local EventService = require(script.EventService)
local InventoryService = require(script.InventoryService)
local MissionService = require(script.MissionService)
local MonetizationService = require(script.MonetizationService)
local MonsterService = require(script.MonsterService)
local PlayerDataService = require(script.PlayerDataService)
local ShelterService = require(script.ShelterService)
local ShopService = require(script.ShopService)
local SurvivalService = require(script.SurvivalService)
local ZoneService = require(script.ZoneService)

Net.build()

local function send(player: Player, event: string, ...)
	Net.get(event):FireClient(player, ...)
end

local function alert(player: Player, text: string, kind: string?)
	send(player, "Alert", text, kind or "info")
end

-- ── état complet envoyé au client ─────────────────────────────────────────
local function pushState(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local session = SurvivalService.get(player)
	local shelter = ShelterService.ownedBy(player)
	send(player, "StateChanged", {
		Cash = profile.Cash,
		Unbanked = profile.UnbankedCash,
		LifetimeBanked = profile.LifetimeBanked,
		Zone = profile.CurrentZone,
		Zones = ZoneService.overview(player),
		Inventory = profile.Inventory,
		Placed = shelter and shelter.Placed or {},
		Missions = MissionService.list(player),
		Shop = ShopService.catalogue(player),
		Sleeping = session ~= nil,
		SessionEarned = session and session.Earned or 0,
		SessionSeconds = session and session.EligibleSeconds or 0,
		SessionMax = session and (ZoneConfig.get(session.ZoneId) :: any).MaxSessionSeconds or 0,
		ShelterId = shelter and shelter.Id or "",
		Multiplier = EconomyService.multiplier(player),
		Event = EventService.active(),
		Stats = {
			Nights = profile.NightsSurvived,
			Deaths = profile.Deaths,
			Survival = profile.SurvivalSeconds,
			Main = profile.MainMissions,
		},
	})
end

EconomyService.onChanged(pushState)
ShelterService.onChanged(function(shelter)
	if shelter.Owner then
		pushState(shelter.Owner)
	end
end)

-- ── construction de la ville et peuplement ────────────────────────────────
PlayerDataService.init()
PlayerDataService.startAutosave()
local city = CityBuilder.build()
ShelterService.init()
MonsterService.init()
SurvivalService.init()
EventService.init()
MonetizationService.init()

EventService.onChanged(function(active)
	for _, player in ipairs(Players:GetPlayers()) do
		send(player, "EventChanged", active)
		alert(player, active.Name .. " — " .. active.Text, "event")
	end
end)

-- Le rôdeur peuple la rue, dans la limite de MaxAlive.
task.spawn(function()
	local prowler = MonsterConfig.get("prowler")
	if not prowler then
		return
	end
	while true do
		if MonsterService.count() < prowler.MaxAlive then
			local point = city.MonsterSpawns[math.random(1, #city.MonsterSpawns)]
			MonsterService.spawn(prowler, "street", point, city.Patrol)
		end
		task.wait(20)
	end
end)

MonsterService.onSignal(function(monsterId, kind, position)
	for _, player in ipairs(Players:GetPlayers()) do
		send(player, "MonsterSignal", monsterId, kind, position)
	end
end)

-- ── sessions de survie ────────────────────────────────────────────────────
SurvivalService.onAssault(function(session)
	alert(session.Player, "Quelque chose vient vers ton refuge.", "danger")
	MonsterService.assault(session.ShelterId)
end)

SurvivalService.onChanged(function(player, session, reason)
	send(player, "SessionChanged", reason, session and {
		Earned = session.Earned, Seconds = session.EligibleSeconds, Zone = session.ZoneId,
	} or nil)

	if reason == "complete" and session then
		MissionService.progress(player, "survive_session", 1)
		alert(player, ("Session terminée. %s sur toi — va les déposer.")
			:format(Format.money(session.Earned)), "cash")
	elseif reason == "death" and session then
		send(player, "DeathReport", {
			Zone = session.ZoneId, Earned = session.Earned,
			Seconds = session.EligibleSeconds,
		})
	end
	pushState(player)
end)

CombatService.onRepel(function(player, _monsterId)
	MissionService.progress(player, "repel", 1)
end)

-- ── remotes ───────────────────────────────────────────────────────────────
local function onClaim(player: Player, shelterId: unknown)
	if type(shelterId) ~= "string" then
		return
	end
	local ok, message = ShelterService.claim(player, shelterId)
	alert(player, message, ok and "info" or "warn")
	pushState(player)
end

local function onSleep(player: Player)
	local ok, message = SurvivalService.start(player)
	alert(player, message, ok and "info" or "warn")
	pushState(player)
end

local function onWake(player: Player)
	local session = SurvivalService.stop(player, "wake")
	if session then
		alert(player, ("Réveillé. %s sur toi."):format(Format.money(session.Earned)), "info")
	end
	pushState(player)
end

local function onBank(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local vault = Workspace:FindFirstChild("City") and (Workspace.City :: any):FindFirstChild("Vault")
	if not root or not vault then
		return
	end
	if (root.Position - (vault :: BasePart).Position).Magnitude > GameConfig.Economy.BankRadius then
		alert(player, "Trop loin du coffre.", "warn")
		return
	end
	local amount = EconomyService.bank(player)
	if amount > 0 then
		alert(player, ("+%s déposés. C'est à toi pour de bon."):format(Format.money(amount)), "cash")
		MissionService.progress(player, "bank", 1)
		local opened = ZoneService.refresh(player)
		for _, name in ipairs(opened) do
			alert(player, name .. " — zone débloquée.", "unlock")
		end
	else
		alert(player, "Tu n'as rien sur toi.", "info")
	end
	pushState(player)
end

local function onBuy(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local ok, message = ShopService.buy(player, itemId)
	alert(player, message, ok and "cash" or "warn")
	pushState(player)
end

local function onPlace(player: Player, itemId: unknown)
	if type(itemId) ~= "string" then
		return
	end
	local ok, message = ShelterService.place(player, itemId)
	alert(player, message, ok and "info" or "warn")
	pushState(player)
end

local function onEnterZone(player: Player, zoneId: unknown)
	if type(zoneId) ~= "string" then
		return
	end
	local ok, message = ZoneService.enter(player, zoneId)
	alert(player, ok and ("Zone : " .. message) or message, ok and "info" or "warn")
	pushState(player)
end

local function onAttack(player: Player, target: unknown)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return
	end
	if not CollectionService:HasTag(target, "Monster") then
		return
	end
	local ok, label, stun = CombatService.playerAttack(player, target)
	if ok then
		MonsterService.stun(target, stun)
		alert(player, label .. " — il recule.", "info")
	end
end

local function onMission(player: Player, action: unknown, missionId: unknown)
	if type(action) ~= "string" or type(missionId) ~= "string" then
		return
	end
	local mission = MissionConfig.get(missionId)
	if not mission then
		return
	end
	-- Les missions se valident par la progression, pas par un bouton : ce
	-- remote ne sert qu'à afficher le détail côté client.
	pushState(player)
end

local function onPurchase(player: Player, productKey: unknown)
	if type(productKey) ~= "string" then
		return
	end
	if not MonetizationService.prompt(player, productKey) then
		alert(player, "Ce produit n'est pas encore configuré sur le tableau de bord.", "warn")
	end
end

Net.get("RequestClaim").OnServerEvent:Connect(onClaim)
Net.get("RequestSleep").OnServerEvent:Connect(onSleep)
Net.get("RequestWake").OnServerEvent:Connect(onWake)
Net.get("RequestBank").OnServerEvent:Connect(onBank)
Net.get("RequestBuy").OnServerEvent:Connect(onBuy)
Net.get("RequestPlace").OnServerEvent:Connect(onPlace)
Net.get("RequestEnterZone").OnServerEvent:Connect(onEnterZone)
Net.get("RequestAttack").OnServerEvent:Connect(onAttack)
Net.get("RequestMission").OnServerEvent:Connect(onMission)
Net.get("RequestPurchase").OnServerEvent:Connect(onPurchase)
Net.get("RequestRepair").OnServerEvent:Connect(function(player)
	alert(player, "Les défenses se remplacent à la boutique.", "info")
end)

-- ── cycle de vie des joueurs ──────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	local profile = PlayerDataService.load(player)
	MissionService.rollPeriods(player)
	ZoneService.refresh(player)

	if not profile.Loaded then
		alert(player, "Tes données n'ont pas pu être chargées. "
			.. "Rien ne sera écrasé, mais cette session ne sera pas sauvegardée.", "warn")
	end

	player.CharacterAdded:Connect(function(character)
		SurvivalService.onCharacterAdded(player, character)
		task.wait(0.5)
		pushState(player)
	end)

	task.wait(1)
	pushState(player)
	alert(player, "Trouve un refuge, barricade-le, dors. L'argent vient en survivant.", "info")
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataService.release(player)
end)

print("[SLEEP OR DIE] serveur prêt — " .. #ZoneConfig.List .. " zones, "
	.. #MissionConfig.List .. " missions.")
