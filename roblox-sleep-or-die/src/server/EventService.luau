--!strict
-- §13 — événements. Le serveur seul décide de l'événement actif, et une
-- récompense d'événement ne peut pas être réclamée deux fois (clé = identifiant
-- de l'événement + sa période).

local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EventService = {}

local current: { Id: string, Name: string, Text: string, RewardMultiplier: number,
	StartedAt: number, Period: string }? = nil
local listeners: { (any) -> () } = {}

function EventService.onChanged(fn: (any) -> ())
	table.insert(listeners, fn)
end

function EventService.active()
	return current
end

function EventService.rewardMultiplier(): number
	return current and current.RewardMultiplier or 1
end

local function pick()
	local list = GameConfig.Events.List
	local chosen = list[math.random(1, #list)]
	current = {
		Id = chosen.Id,
		Name = chosen.Name,
		Text = chosen.Text,
		RewardMultiplier = chosen.RewardMultiplier or 1,
		StartedAt = os.time(),
		-- La période rend la clé de récompense unique : même événement demain,
		-- récompense à nouveau réclamable, mais pas deux fois aujourd'hui.
		Period = os.date("!%Y%m%d%H"),
	}
	for _, fn in ipairs(listeners) do
		task.spawn(fn, current)
	end
end

-- Réclamation d'une récompense d'événement, une seule fois par période.
function EventService.claim(player: Player): (boolean, string)
	local profile = PlayerDataService.get(player)
	if not profile or not current then
		return false, "Aucun événement en cours."
	end
	local key = "ev_" .. current.Id .. "_" .. current.Period
	if profile.Achievements[key] then
		return false, "Déjà réclamé."
	end
	profile.Achievements[key] = true
	PlayerDataService.markDirty(player)
	return true, current.Name
end

function EventService.init()
	pick()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Events.RotationSeconds)
			pick()
		end
	end)
end

return EventService
