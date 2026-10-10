--!strict
-- L'éveil de la maison : une jauge, un serveur, tout le monde dedans.
--
-- Elle monte pendant que des joueurs dorment dans les zones profondes, et
-- redescend quand plus personne ne le fait. Quand elle change de stade, les
-- monstres de tout le serveur changent avec elle — et les gains aussi.
--
-- C'est volontairement une mécanique de serveur et pas de joueur : on ne peut
-- pas s'en protéger seul, et c'est exactement ce qui force les joueurs à se
-- parler.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local AwakeningConfig = require(script.Parent.Parent.Shared.AwakeningConfig)
local MonsterService = require(script.Parent.MonsterService)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)

local AwakeningService = {}

local points = 0
local stage = 1
local listeners: { (number, number, any) -> () } = {}

function AwakeningService.onChanged(fn: (number, number, any) -> ())
	table.insert(listeners, fn)
end

function AwakeningService.points(): number
	return points
end

function AwakeningService.stage(): number
	return stage
end

function AwakeningService.data()
	return AwakeningConfig.stageData(stage)
end

-- Multiplicateur de gains : la contrepartie du risque partagé.
function AwakeningService.rewardMultiplier(): number
	return AwakeningConfig.stageData(stage).Reward
end

local function broadcast()
	local data = AwakeningConfig.stageData(stage)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, points, stage, {
			Name = data.Name, Color = data.Color, Text = data.Text,
			Next = AwakeningConfig.nextThreshold(stage),
			Reward = data.Reward,
		})
	end
end

local function applyStage()
	local data = AwakeningConfig.stageData(stage)
	-- Les monstres déjà sur le terrain changent tout de suite : on ne veut pas
	-- que le stade n'ait d'effet qu'après une réapparition.
	MonsterService.applyGlobal(data.Speed, data.Sight)
	Lighting.FogEnd = data.FogEnd
	Lighting.FogStart = math.min(40, data.FogEnd * 0.15)
	Lighting.FogColor = data.FogColor
	broadcast()
end

-- Appelé chaque seconde de sommeil par SurvivalService.
function AwakeningService.feed(zoneId: string, seconds: number)
	local zone = ZoneConfig.get(zoneId)
	if not zone then
		return
	end
	local gain = AwakeningConfig.gainFor(zone.Order) * seconds
	if gain <= 0 then
		return
	end
	points += gain
	local newStage = AwakeningConfig.stageFor(points)
	if newStage ~= stage then
		stage = newStage
		applyStage()
	end
end

function AwakeningService.init()
	applyStage()
	-- Décroissance : sans elle, un serveur qui tourne longtemps finit toujours
	-- au stade maximum et la jauge ne veut plus rien dire.
	task.spawn(function()
		while true do
			task.wait(1)
			if points > 0 then
				points = math.max(0, points - AwakeningConfig.DecayPerSecond)
				local newStage = AwakeningConfig.stageFor(points)
				if newStage ~= stage then
					stage = newStage
					applyStage()
				end
			end
		end
	end)
end

return AwakeningService
