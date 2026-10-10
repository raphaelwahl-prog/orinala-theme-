--!strict
-- Construit les sept zones au démarrage et retient, pour chacune, ses points
-- de ronde, ses points d'apparition et son point d'arrivée.
--
-- C'est le seul endroit qui connaît la géométrie. Les autres services ne
-- parlent qu'en identifiants de zone.

local Players = game:GetService("Players")

local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)
local MonsterService = require(script.Parent.MonsterService)
local ZoneBuilder = require(script.Parent.ZoneBuilder)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)
local ZoneLayouts = require(script.Parent.ZoneLayouts)

local WorldService = {}

local layouts: { [string]: ZoneBuilder.Layout } = {}

function WorldService.build()
	ZoneBuilder.reset()
	for _, zone in ipairs(ZoneConfig.List) do
		local build = ZoneLayouts.ById[zone.Id]
		if build then
			local folder = ZoneBuilder.folder(zone.Id)
			layouts[zone.Id] = build(ZoneBuilder.origin(zone.Order), folder)
		end
	end
	return layouts
end

function WorldService.layout(zoneId: string): ZoneBuilder.Layout?
	return layouts[zoneId]
end

function WorldService.anchor(zoneId: string): Vector3?
	local layout = layouts[zoneId]
	return layout and layout.Anchor or nil
end

-- Téléporte le joueur au point d'arrivée d'une zone. Les zones sont à
-- 1600 studs les unes des autres : on ne s'y rend pas à pied.
function WorldService.teleport(player: Player, zoneId: string): boolean
	local anchor = WorldService.anchor(zoneId)
	local character = player.Character
	if not anchor or not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	character:PivotTo(CFrame.new(anchor))
	return true
end

-- Peuple chaque zone de son monstre, dans la limite de MaxAlive, et seulement
-- s'il y a quelqu'un dedans : inutile de faire tourner une IA dans une zone
-- vide, c'est du temps serveur gâché.
local function occupied(zoneId: string): boolean
	local origin = ZoneBuilder.origin((ZoneConfig.get(zoneId) :: any).Order)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and math.abs(root.Position.X - origin.X) < ZoneBuilder.SPACING / 2 then
			return true
		end
	end
	return false
end

function WorldService.startPopulating()
	task.spawn(function()
		while true do
			for _, zone in ipairs(ZoneConfig.List) do
				local layout = layouts[zone.Id]
				local def = MonsterConfig.get(zone.Monster)
				-- Le boss n'apparaît pas tout seul : BossService s'en charge.
				if layout and def and def.Rule ~= "boss_phases" and occupied(zone.Id) then
					if MonsterService.countInZone(zone.Id) < def.MaxAlive then
						local point = layout.Spawns[math.random(1, #layout.Spawns)]
						MonsterService.spawn(def, zone.Id, point, layout.Patrol)
					end
				end
			end
			task.wait(15)
		end
	end)
end

return WorldService
