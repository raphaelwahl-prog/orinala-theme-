--!strict
-- §3 zone 7 — le combat de boss.
--
-- Le CDC demande « plusieurs phases » et « de maîtriser les mécaniques apprises
-- dans les zones précédentes ». C'est pris au mot : chaque phase rejoue une
-- mécanique déjà vue, dans l'ordre où le joueur les a apprises.
--
--   phase 1 — « sound »      : il vise le bruit, comme la Chose des égouts.
--   phase 2 — « gaze »       : regardé, il se fige, comme la Poupée.
--   phase 3 — « relentless » : il ne lâche plus rien, comme Le Masque.
--
-- Il ne meurt pas de dégâts : on le fait reculer d'une phase à chaque série de
-- coups encaissés, et c'est tenir les trois phases qui compte comme victoire.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)
local MonsterService = require(script.Parent.MonsterService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)

local BossService = {}

local PHASES = {
	{ Rule = "sound", Hits = 6, Speed = 18, Sight = 70,
		Text = "Phase 1 — il suit le bruit. Marche, ne cours pas." },
	{ Rule = "gaze", Hits = 8, Speed = 24, Sight = 95,
		Text = "Phase 2 — regardé, il se fige. Ne le quitte pas des yeux." },
	{ Rule = "relentless", Hits = 10, Speed = 26, Sight = 120,
		Text = "Phase 3 — il ne lâche plus. Tiens, c'est tout ce qu'il reste." },
}

local active: { Model: Model, Phase: number, Hits: number, Players: { Player } }? = nil
local listeners: { (number, string) -> () } = {}
local victoryHandlers: { (Player) -> () } = {}

function BossService.onPhase(fn: (number, string) -> ())
	table.insert(listeners, fn)
end

function BossService.onVictory(fn: (Player) -> ())
	table.insert(victoryHandlers, fn)
end

local function announce(phase: number, text: string)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, phase, text)
	end
end

local function applyPhase(index: number)
	if not active then
		return
	end
	local phase = PHASES[index]
	MonsterService.setRule(active.Model, phase.Rule)
	MonsterService.boost(active.Model, phase.Speed, phase.Sight)
	active.Phase = index
	active.Hits = 0
	announce(index, phase.Text)
end

function BossService.isActive(): boolean
	return active ~= nil and active.Model.Parent ~= nil
end

function BossService.start(): boolean
	if BossService.isActive() then
		return false
	end
	local def = MonsterConfig.get("clown_boss")
	local layout = WorldService.layout("carnival")
	if not def or not layout then
		return false
	end
	local model = MonsterService.spawn(def, "carnival", layout.Spawns[1], layout.Patrol)
	if not model then
		return false
	end
	CollectionService:AddTag(model, "Boss")
	active = { Model = model, Phase = 0, Hits = 0, Players = {} }
	applyPhase(1)
	return true
end

-- Appelé par CombatService à chaque coup porté au boss.
function BossService.registerHit(player: Player)
	if not active or not active.Model.Parent then
		return
	end
	local known = false
	for _, existing in ipairs(active.Players) do
		if existing == player then
			known = true
			break
		end
	end
	if not known then
		table.insert(active.Players, player)
	end

	active.Hits += 1
	local phase = PHASES[active.Phase]
	if active.Hits < phase.Hits then
		return
	end

	if active.Phase < #PHASES then
		applyPhase(active.Phase + 1)
	else
		BossService.finish()
	end
end

function BossService.finish()
	if not active then
		return
	end
	local participants = active.Players
	MonsterService.despawn(active.Model)
	active = nil
	announce(0, "Le clown est tombé. Le carnaval se tait.")

	for _, player in ipairs(participants) do
		local profile = PlayerDataService.get(player)
		if profile then
			profile.BossesBeaten += 1
			profile.Achievements.carnival_cleared = true
			profile.Cosmetics.clown_trophy = true
			PlayerDataService.markDirty(player)
		end
		for _, fn in ipairs(victoryHandlers) do
			task.spawn(fn, player)
		end
	end
end

-- Le boss n'apparaît que lorsqu'un joueur entre dans l'arène.
function BossService.init()
	task.spawn(function()
		while true do
			task.wait(3)
			if not BossService.isActive() then
				for _, arena in ipairs(CollectionService:GetTagged("BossArena")) do
					if arena:IsA("BasePart") then
						for _, player in ipairs(Players:GetPlayers()) do
							local character = player.Character
							local root = character
								and character:FindFirstChild("HumanoidRootPart") :: BasePart?
							if root and (root.Position - arena.Position).Magnitude < 95 then
								BossService.start()
								break
							end
						end
					end
				end
			end
		end
	end)
end

return BossService
