--!strict
-- §7 — les objectifs de mission qui ont besoin d'objets dans le monde.
--
-- Les quatre types ramassables (`collect`, `repair`, `rescue`, `deliver`) sont
-- des Part taguées `Objective` posées par ZoneLayouts. Elles réapparaissent
-- après un délai, sinon la zone se vide et les missions répétables deviennent
-- impossibles.
--
-- Les trois objectifs particuliers sont déduits du jeu, pas d'un bouton :
--   · `escape_chase`    — avoir été poursuivi, puis avoir semé le monstre ;
--   · `survive_extreme` — une session complète au couvent, aucune défense ;
--   · `find_secret`     — avoir trouvé et franchi la porte du carnaval.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MissionService = require(script.Parent.MissionService)
local ShelterService = require(script.Parent.ShelterService)

local ObjectiveService = {}

local RESPAWN = 45

local chased: { [Player]: number } = {}
local alertHandlers: { (Player, string) -> () } = {}

function ObjectiveService.onFeedback(fn: (Player, string) -> ())
	table.insert(alertHandlers, fn)
end

local function tell(player: Player, text: string)
	for _, fn in ipairs(alertHandlers) do
		task.spawn(fn, player, text)
	end
end

local function bind(part: BasePart)
	if part:GetAttribute("Bound") then
		return
	end
	part:SetAttribute("Bound", true)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(player)
		local goal = part:GetAttribute("Goal")
		if type(goal) ~= "string" or not part.Parent then
			return
		end
		MissionService.progress(player, goal, 1)
		tell(player, "Objectif : +1 (" .. goal .. ")")

		-- On cache l'objet plutôt que de le détruire : il revient tout seul.
		part.Transparency = 1
		part.CanCollide = false
		prompt.Enabled = false
		task.delay(RESPAWN, function()
			if part.Parent then
				part.Transparency = 0
				part.CanCollide = true
				prompt.Enabled = true
			end
		end)
	end)
end

function ObjectiveService.init()
	for _, part in ipairs(CollectionService:GetTagged("Objective")) do
		if part:IsA("BasePart") then
			bind(part)
		end
	end
	CollectionService:GetInstanceAddedSignal("Objective"):Connect(function(instance)
		if instance:IsA("BasePart") then
			bind(instance)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		chased[player] = nil
	end)
end

-- Branché sur les signaux de MonsterService : « repéré » marque le début d'une
-- poursuite, et tenir 25 secondes sans se faire reprendre vaut l'objectif.
function ObjectiveService.noteChase(player: Player)
	chased[player] = os.clock()
	task.delay(25, function()
		local started = chased[player]
		if started and os.clock() - started >= 25 then
			chased[player] = nil
			MissionService.progress(player, "escape_chase", 1)
			tell(player, "Tu l'as semé.")
		end
	end)
end

function ObjectiveService.noteCaught(player: Player)
	chased[player] = nil
end

-- Une session terminée : on regarde si elle vaut « nuit extrême ».
function ObjectiveService.noteSession(player: Player, zoneId: string, reason: string)
	if reason ~= "complete" then
		return
	end
	if zoneId ~= "convent" then
		return
	end
	local shelter = ShelterService.ownedBy(player)
	if not shelter then
		return
	end
	local placed = 0
	for _, count in pairs(shelter.Placed) do
		placed += count
	end
	if placed == 0 then
		MissionService.progress(player, "survive_extreme", 1)
		tell(player, "Une nuit entière au couvent, sans rien poser. Noté.")
	end
end

-- Franchir la porte cachée de l'hôpital vaut la quête secrète.
function ObjectiveService.noteZoneEntered(player: Player, zoneId: string)
	if zoneId == "carnival" then
		MissionService.progress(player, "find_secret", 1)
	end
end

return ObjectiveService
