--[[
	RoundService — cycle nuit / aube.

	NUIT  : noir, monstre actif, on peut dormir.
	AUBE  : lumière, monstre rangé, tout le monde est relevé, et l'argent que
	        les survivants ont encore sur eux est déposé automatiquement.

	Le dépôt automatique à l'aube est important : sans lui, un joueur pourrait
	garder sa cagnotte indéfiniment et le risque disparaîtrait. Avec lui, chaque
	nuit est une décision complète — tu encaisses, ou tu tentes une planque de
	plus avant le lever du jour.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local RoundService = {}

local services
local phase = "Dawn"
local phaseEndsAt = 0
local nightNumber = 0

function RoundService.init(registry)
	services = registry
end

function RoundService.getPhase(): string
	return phase
end

function RoundService.getNightNumber(): number
	return nightNumber
end

local function broadcast()
	;(Net.get("RoundUpdate") :: RemoteEvent):FireAllClients({
		Phase = phase,
		SecondsLeft = math.max(0, phaseEndsAt - os.clock()),
		Duration = (phase == "Night") and GameConfig.Round.NightDuration or GameConfig.Round.DawnDuration,
		NightNumber = nightNumber,
	})
end

function RoundService.pushTo(player: Player)
	;(Net.get("RoundUpdate") :: RemoteEvent):FireClient(player, {
		Phase = phase,
		SecondsLeft = math.max(0, phaseEndsAt - os.clock()),
		Duration = (phase == "Night") and GameConfig.Round.NightDuration or GameConfig.Round.DawnDuration,
		NightNumber = nightNumber,
	})
end

-- ─── ambiance ───────────────────────────────────────────────────────────────

local function setNightLighting(night: boolean)
	if night then
		Lighting.ClockTime = 0
		Lighting.Brightness = 0.35
		Lighting.Ambient = Color3.fromRGB(14, 14, 22)
		Lighting.OutdoorAmbient = Color3.fromRGB(18, 18, 30)
		Lighting.FogEnd = 110
		Lighting.FogColor = Color3.fromRGB(10, 10, 16)
	else
		Lighting.ClockTime = 7.2
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(110, 110, 120)
		Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
		Lighting.FogEnd = 420
		Lighting.FogColor = Color3.fromRGB(150, 155, 165)
	end
end

-- ─── transitions ────────────────────────────────────────────────────────────

local function beginNight()
	nightNumber += 1
	phase = "Night"
	phaseEndsAt = os.clock() + GameConfig.Round.NightDuration
	setNightLighting(true)

	services.Life.resetNightFlags()
	services.Threat.startPatrol()

	services.Notify.broadcast(("Nuit %d. Va dormir — plus c'est moche, plus ça paie."):format(nightNumber), "danger")
	broadcast()
	services.Economy.pushAll()
end

local function beginDawn()
	phase = "Dawn"
	phaseEndsAt = os.clock() + GameConfig.Round.DawnDuration
	setNightLighting(false)

	services.Sleep.stopAll("dawn")
	services.Threat.park()
	services.Life.reviveAll()
	services.Awakening.reset()

	-- Dépôt automatique des survivants.
	for _, player in ipairs(Players:GetPlayers()) do
		local amount = services.Economy.getUnbanked(player)
		if amount > 0 then
			local credited = services.Economy.bank(player)
			services.Notify.send(player, ("Le jour se lève. +%d $ déposés."):format(credited), "cash")
		end
		local profile = services.Data.get(player)
		if profile then
			profile.NightsSurvived += 1
			services.Data.save(player)
		end
	end

	services.Notify.broadcast("Jour. Dépose, achète, respire.", "info")
	broadcast()
	services.Economy.pushAll()
end

function RoundService.start()
	setNightLighting(false)
	phase = "Dawn"
	phaseEndsAt = os.clock() + GameConfig.Round.DawnDuration

	task.spawn(function()
		-- Petite marge pour laisser les autres services finir leur démarrage.
		task.wait(2)
		while true do
			broadcast()
			if os.clock() >= phaseEndsAt then
				if phase == "Night" then
					beginDawn()
				else
					beginNight()
				end
			end
			task.wait(1)
		end
	end)
end

return RoundService
