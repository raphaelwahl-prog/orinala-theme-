--[[
	AwakeningService — l'évolution des créatures.

	C'est la réponse à « le monstre évolue selon là où tu te caches ».

	Un compteur partagé par tout le serveur monte à chaque tirage de risque
	d'un dormeur, de (palier − 1) points. Dormir dans Le Nid remplit donc la
	jauge quatre fois plus vite que le couloir de service.

	Quatre stades : CALME → AGITÉ → ÉVEILLÉ → AFFAMÉ. À chaque stade les
	créatures sont plus rapides, plus grandes, voient plus loin, et le
	brouillard se referme. Au dernier stade, L'AFFAMÉ sort de sa chambre même
	si plus personne ne dort au palier 5.

	Conséquence de design voulue : la cupidité d'un seul joueur met toute la
	partie en danger. En multi, ça crée des engueulades — et les engueulades,
	c'est de la rétention.
]]

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EntityCatalog = require(Shared.EntityCatalog)
local Net = require(Shared.Net)

local AwakeningService = {}

local services
local points = 0
local stage = 1
local apexReleased = false

function AwakeningService.init(registry)
	services = registry
end

function AwakeningService.getPoints(): number
	return points
end

function AwakeningService.getStage(): number
	return stage
end

function AwakeningService.getStageData()
	return EntityCatalog.stageData(stage)
end

--[[ Points restants avant le prochain stade. nil si on est au maximum. ]]
local function pointsToNextStage(): number?
	local nextThreshold = EntityCatalog.Awakening.Thresholds[stage + 1]
	if not nextThreshold then
		return nil
	end
	return nextThreshold - points
end

local function broadcast()
	local data = AwakeningService.getStageData()
	;(Net.get("AwakeningUpdate") :: RemoteEvent):FireAllClients({
		Stage = stage,
		MaxStage = EntityCatalog.MaxStage,
		StageName = data.Name,
		Points = points,
		ToNext = pointsToNextStage(),
	})
end

function AwakeningService.pushTo(player: Player)
	local data = AwakeningService.getStageData()
	;(Net.get("AwakeningUpdate") :: RemoteEvent):FireClient(player, {
		Stage = stage,
		MaxStage = EntityCatalog.MaxStage,
		StageName = data.Name,
		Points = points,
		ToNext = pointsToNextStage(),
	})
end

local function applyStage(previousStage: number)
	local data = AwakeningService.getStageData()

	-- Le brouillard se referme : le joueur SENT le stade monter sans lire l'UI.
	Lighting.FogEnd = data.FogEnd
	Lighting.FogColor = data.FogColor

	-- Les créatures déjà sur la carte grandissent et accélèrent.
	services.Threat.rescale(stage)

	if stage > previousStage then
		services.Notify.broadcast(
			("La maison se réveille — %s."):format(data.Name),
			stage >= 3 and "danger" or "info"
		)
	end

	if data.ReleasesApex and not apexReleased then
		apexReleased = true
		services.Notify.broadcast("Quelque chose est sorti du Nid. Ce n'est plus votre maison.", "danger")
		services.Threat.releaseApex()
	end

	broadcast()
end

--[[ Appelé par SleepService à chaque tirage de risque. ]]
function AwakeningService.feed(tier: number)
	local gain = EntityCatalog.awakeningGain(tier)
	if gain <= 0 then
		return
	end
	points += gain

	local newStage = EntityCatalog.stageFor(points)
	if newStage ~= stage then
		local previous = stage
		stage = newStage
		applyStage(previous)
	else
		broadcast()
	end
end

--[[ Remise à zéro à l'aube. ]]
function AwakeningService.reset()
	local previous = stage
	points = 0
	stage = 1
	apexReleased = false
	if previous ~= 1 then
		applyStage(previous)
	else
		broadcast()
	end
end

function AwakeningService.start()
	broadcast()
end

return AwakeningService
