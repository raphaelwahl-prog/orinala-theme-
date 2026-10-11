--[[
	DEAD TIRED — point d'entrée serveur.

	Ce script ne contient aucune règle de jeu : il ne fait que créer les
	services, les présenter les uns aux autres, et les démarrer dans le bon
	ordre. Toute la logique est dans les modules à côté.

	Ordre important :
	  1. Net.build()   — les remotes doivent exister avant que le client démarre.
	  2. init(registry) sur tous les services — ils se gardent une référence
	     mutuelle, mais ne touchent encore à rien.
	  3. MapBuilder    — la carte doit exister avant ZoneService, qui la lit.
	  4. start()       — à partir de là, les boucles tournent.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.GameConfig)

-- 1. Remotes
Net.build()

-- 2. Services
local services = {
	Data = require(script.DataService),
	Notify = require(script.NotifyService),
	Economy = require(script.EconomyService),
	Progression = require(script.ProgressionService),
	Zone = require(script.ZoneService),
	Sleep = require(script.SleepService),
	Life = require(script.LifeService),
	Threat = require(script.ThreatService),
	Round = require(script.RoundService),
	Shop = require(script.ShopService),
	Monetization = require(script.MonetizationService),
	Awakening = require(script.AwakeningService),
	Cosmetic = require(script.CosmeticService),
}
local MapBuilder = require(script.MapBuilder)

services.Data.init()
for name, service in pairs(services) do
	if name ~= "Data" and type(service.init) == "function" then
		service.init(services)
	end
end

-- 3. Carte
MapBuilder.build()

-- 4. Boucles
for _, service in pairs(services) do
	if type(service.start) == "function" then
		service.start()
	end
end

-- ─── joueurs ────────────────────────────────────────────────────────────────

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("Humanoid", 5)
	services.Zone.releaseAllFor(player)
	services.Economy.applyWalkSpeed(player)
	-- Les skins se réappliquent à chaque réapparition, sinon on repart nu
	-- après chaque mort.
	services.Cosmetic.apply(player)
	services.Economy.push(player)
end

local function onPlayerAdded(player: Player)
	-- Le chargement est bloquant : on le fait dans sa propre tâche pour ne pas
	-- retarder l'arrivée des autres joueurs.
	local profile = services.Data.load(player)
	if not profile then
		return
	end

	services.Economy.onPlayerAdded(player)
	services.Progression.onPlayerAdded(player)
	services.Monetization.onPlayerAdded(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	services.Economy.push(player)
	services.Round.pushTo(player)
	services.Awakening.pushTo(player)
	services.Progression.check(player)

	if not services.Data.isAvailable() then
		services.Notify.send(player,
			"Sauvegarde désactivée (API Services off) — ta progression ne sera pas gardée.", "info")
	end
end

local function onPlayerRemoving(player: Player)
	services.Threat.onPlayerRemoving(player)
	services.Sleep.onPlayerRemoving(player)
	services.Life.onPlayerRemoving(player)
	services.Progression.onPlayerRemoving(player)
	services.Monetization.onPlayerRemoving(player)
	services.Economy.onPlayerRemoving(player)
	services.Data.release(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(onPlayerAdded, player)
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Joueurs déjà présents (rechargement d'un script en Studio).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ─── demandes du client ─────────────────────────────────────────────────────

;(Net.get("RequestWake") :: RemoteEvent).OnServerEvent:Connect(function(player)
	services.Sleep.requestWake(player)
end)

;(Net.get("RequestBank") :: RemoteEvent).OnServerEvent:Connect(function(player)
	services.Economy.requestBank(player)
end)

;(Net.get("RequestRevive") :: RemoteEvent).OnServerEvent:Connect(function(player, target)
	-- On revalide tout côté serveur : le client peut mentir sur la cible.
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end
	if not services.Life.isDown(target) then
		return
	end
	local a = player.Character and player.Character.PrimaryPart
	local b = target.Character and target.Character.PrimaryPart
	if not (a and b) then
		return
	end
	if (a.Position - b.Position).Magnitude > GameConfig.Downed.ReviveRange + 2 then
		return
	end
	services.Life.revive(target, player)
end)

print("[DEAD TIRED] serveur prêt.")
