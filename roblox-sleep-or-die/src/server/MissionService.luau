--!strict
-- §7 — missions. Le CDC §15 exige qu'une mission ne puisse pas être réclamée
-- plusieurs fois : c'est `MissionsDone` pour les principales et secondaires, et
-- les clés de jour / de semaine pour les répétables.

local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local MissionConfig = require(script.Parent.Parent.Shared.MissionConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneService = require(script.Parent.ZoneService)

local MissionService = {}

local completionHandlers: { (Player, MissionConfig.Mission) -> () } = {}

function MissionService.onComplete(fn: (Player, MissionConfig.Mission) -> ())
	table.insert(completionHandlers, fn)
end

local function dayKey(): string
	return os.date("!%Y-%m-%d")
end

local function weekKey(): string
	-- Semaine ISO approximée : année + numéro de semaine UTC.
	return os.date("!%Y-W%W")
end

-- Remet à zéro les quotidiennes et hebdomadaires quand la période change.
function MissionService.rollPeriods(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local day, week = dayKey(), weekKey()
	if profile.DailyKey ~= day then
		profile.DailyKey = day
		profile.DailyProgress = {}
		PlayerDataService.markDirty(player)
	end
	if profile.WeeklyKey ~= week then
		profile.WeeklyKey = week
		profile.WeeklyProgress = {}
		PlayerDataService.markDirty(player)
	end
end

local function bucket(profile, mission: MissionConfig.Mission)
	if mission.Kind == "daily" then
		return profile.DailyProgress
	elseif mission.Kind == "weekly" then
		return profile.WeeklyProgress
	end
	return profile.Missions
end

local function isDone(profile, mission: MissionConfig.Mission): boolean
	if mission.Kind == "main" or mission.Kind == "side" then
		return profile.MissionsDone[mission.Id] == true
	end
	local done = bucket(profile, mission)[mission.Id .. "_done"]
	return done ~= nil and done > 0
end

local function markDone(player: Player, profile, mission: MissionConfig.Mission)
	if mission.Kind == "main" or mission.Kind == "side" then
		profile.MissionsDone[mission.Id] = true
		if mission.Kind == "main" then
			profile.MainMissions += 1
		end
	else
		bucket(profile, mission)[mission.Id .. "_done"] = 1
	end

	if mission.Reward.Cash > 0 then
		EconomyService.grant(player, mission.Reward.Cash, "mission:" .. mission.Id)
	end
	if mission.Reward.Items then
		for _, itemId in ipairs(mission.Reward.Items) do
			InventoryService.add(player, itemId, 1)
		end
	end
	if mission.Reward.Quest then
		profile.Quests[mission.Reward.Quest] = true
	end
	PlayerDataService.markDirty(player)
	ZoneService.refresh(player)

	for _, fn in ipairs(completionHandlers) do
		task.spawn(fn, player, mission)
	end
end

-- Avance toutes les missions dont l'objectif correspond. C'est le seul point
-- d'entrée : les services appellent `progress(player, "survive_session", 1)`.
function MissionService.progress(player: Player, goal: string, amount: number?)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	MissionService.rollPeriods(player)
	local step = amount or 1

	for _, mission in ipairs(MissionConfig.List) do
		if mission.Goal == goal and not isDone(profile, mission) then
			local store = bucket(profile, mission)
			local current = (store[mission.Id] or 0) + step
			store[mission.Id] = current
			if current >= mission.Target then
				markDone(player, profile, mission)
			end
			PlayerDataService.markDirty(player)
		end
	end
end

function MissionService.list(player: Player)
	local profile = PlayerDataService.get(player)
	local out = {}
	if not profile then
		return out
	end
	MissionService.rollPeriods(player)
	for _, mission in ipairs(MissionConfig.List) do
		local store = bucket(profile, mission)
		table.insert(out, {
			Id = mission.Id, Kind = mission.Kind, Name = mission.Name,
			Text = mission.Text, Giver = mission.Giver,
			Target = mission.Target, Progress = math.min(store[mission.Id] or 0, mission.Target),
			Done = isDone(profile, mission), Reward = mission.Reward.Cash,
		})
	end
	return out
end

return MissionService
