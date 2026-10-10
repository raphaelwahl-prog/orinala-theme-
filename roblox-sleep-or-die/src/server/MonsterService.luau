--!strict
-- §5 — les monstres et leur IA.
--
-- Deux boucles, comme toujours quand il y a du pathfinding :
--   · Heartbeat : déplacement, portée d'attaque, signaux. Ne cède JAMAIS la
--     main (pas de wait, pas de ComputeAsync) — sinon tout le serveur saccade.
--   · boucle à 2 Hz : décisions et calculs de chemin, qui eux peuvent céder.
--
-- Les huit états du CDC sont dans MonsterConfig.States. La mécanique propre à
-- chaque zone est portée par `Rule` et appliquée dans `decide`.

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CombatService = require(script.Parent.CombatService)
local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)
local ShelterService = require(script.Parent.ShelterService)

local MonsterService = {}

local S = MonsterConfig.States

type Agent = {
	Def: MonsterConfig.Monster,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	ZoneId: string,
	Home: Vector3,
	State: string,
	Target: Player?,
	LastKnown: Vector3?,
	Path: { Vector3 },
	PathIndex: number,
	NextThink: number,
	LostSince: number,
	StunUntil: number,
	NextAttack: number,
	PatrolPoints: { Vector3 },
	PatrolIndex: number,
}

local agents: { Agent } = {}
local signalListeners: { (string, string, Vector3) -> () } = {}

function MonsterService.onSignal(fn: (string, string, Vector3) -> ())
	table.insert(signalListeners, fn)
end

local function signal(agent: Agent, kind: string)
	for _, fn in ipairs(signalListeners) do
		task.spawn(fn, agent.Def.Id, kind, agent.Root.Position)
	end
end

local function countInZone(zoneId: string): number
	local n = 0
	for _, agent in ipairs(agents) do
		if agent.ZoneId == zoneId then
			n += 1
		end
	end
	return n
end

-- Le joueur regarde-t-il l'agent ? (mécanique « gaze » de la poupée)
local function isWatched(agent: Agent): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if head then
			local toAgent = agent.Root.Position - head.Position
			local distance = toAgent.Magnitude
			if distance < agent.Def.SightRange * 1.5 then
				local facing = head.CFrame.LookVector
				if facing:Dot(toAgent.Unit) > 0.55 and CombatService.hasLineOfSight(
					head.Position, agent.Root.Position, agent.Model) then
					return true
				end
			end
		end
	end
	return false
end

local function canSee(agent: Agent, player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local distance = (root.Position - agent.Root.Position).Magnitude

	-- Mécanique « sound » : la Chose des égouts vise le bruit, pas la vue.
	if agent.Def.Rule == "sound" then
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local loud = moving and humanoid.WalkSpeed > 17
		local range = loud and agent.Def.HearRange or agent.Def.HearRange * 0.45
		return distance <= range
	end

	if distance > agent.Def.SightRange then
		return false
	end
	return CombatService.hasLineOfSight(agent.Root.Position, root.Position, agent.Model)
end

local function nearestVisible(agent: Agent): (Player?, number)
	local best, bestDistance = nil, math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if canSee(agent, player) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local distance = (root.Position - agent.Root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = player, distance
				end
			end
		end
	end
	return best, bestDistance
end

local function computePath(agent: Agent, goal: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false,
	})
	local ok = pcall(function()
		path:ComputeAsync(agent.Root.Position, goal)
	end)
	agent.Path = {}
	agent.PathIndex = 1
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in ipairs(path:GetWaypoints()) do
			table.insert(agent.Path, waypoint.Position)
		end
	else
		-- Pas de chemin : on vise en ligne droite, ça vaut mieux que rien.
		agent.Path = { goal }
	end
end

-- Décisions. Appelée à 2 Hz, elle a le droit de céder la main.
local function decide(agent: Agent)
	if os.clock() < agent.StunUntil then
		agent.State = S.STUNNED
		return
	end

	local target, distance = nearestVisible(agent)

	-- Mécanique « gaze » : regardée, la poupée ne bouge pas du tout.
	if agent.Def.Rule == "gaze" and isWatched(agent) then
		agent.State = S.DETECT
		agent.Path = {}
		return
	end

	if target then
		local root = (target.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		agent.Target = target
		agent.LastKnown = root.Position
		agent.LostSince = 0
		if distance <= agent.Def.AttackRange then
			agent.State = S.ATTACK
		else
			if agent.State ~= S.CHASE then
				agent.State = S.CHASE
				signal(agent, "spotted")
			end
			computePath(agent, root.Position)
		end
		return
	end

	if agent.State == S.CHASE or agent.State == S.ATTACK then
		agent.State = S.SEARCH
		agent.LostSince = os.clock()
		if agent.LastKnown then
			computePath(agent, agent.LastKnown)
		end
		return
	end

	if agent.State == S.SEARCH then
		local patience = agent.Def.GiveUpSeconds
		-- Le Masque n'abandonne pratiquement jamais (mécanique « relentless »).
		if agent.Def.Rule == "relentless" then
			patience *= 3
		end
		if os.clock() - agent.LostSince > patience then
			agent.State = S.RETURN
			computePath(agent, agent.Home)
		end
		return
	end

	if agent.State == S.RETURN then
		if (agent.Root.Position - agent.Home).Magnitude < 8 then
			agent.State = S.PATROL
		end
		return
	end

	-- Patrouille : on passe au point suivant quand on est arrivé.
	agent.State = S.PATROL
	if #agent.PatrolPoints > 0 then
		local point = agent.PatrolPoints[agent.PatrolIndex]
		if not point or (agent.Root.Position - point).Magnitude < 7 then
			agent.PatrolIndex = agent.PatrolIndex % #agent.PatrolPoints + 1
			computePath(agent, agent.PatrolPoints[agent.PatrolIndex])
		elseif #agent.Path == 0 then
			computePath(agent, point)
		end
	end
end

-- Déplacement. Appelée à chaque image, ne cède jamais la main.
local function move(agent: Agent, dt: number)
	if os.clock() < agent.StunUntil then
		agent.Humanoid.WalkSpeed = 0
		return
	end

	local speed = agent.Def.WalkSpeed
	if agent.State == S.PATROL then
		speed *= 0.55
	end
	agent.Humanoid.WalkSpeed = speed

	local point = agent.Path[agent.PathIndex]
	while point and (Vector3.new(point.X, agent.Root.Position.Y, point.Z)
		- Vector3.new(agent.Root.Position.X, agent.Root.Position.Y, agent.Root.Position.Z)).Magnitude < 4 do
		agent.PathIndex += 1
		point = agent.Path[agent.PathIndex]
	end
	if point then
		agent.Humanoid:MoveTo(point)
	end

	if agent.State == S.ATTACK and agent.Target and os.clock() >= agent.NextAttack then
		agent.NextAttack = os.clock() + 1.2
		CombatService.monsterHit(agent.Def, agent.Root.Position, agent.Target)
		signal(agent, "attack")
	end
end

function MonsterService.spawn(def: MonsterConfig.Monster, zoneId: string, position: Vector3,
	patrol: { Vector3 }): Model?
	if countInZone(zoneId) >= def.MaxAlive then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = def.Id

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 5.5, 2)
	root.Position = position + Vector3.new(0, 3, 0)
	root.Anchored = false
	root.CanCollide = true
	root.Color = Color3.fromRGB(28, 24, 26)
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 2, 2)
	head.Color = Color3.fromRGB(40, 30, 32)
	head.CanCollide = false
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = head
	head.Position = root.Position + Vector3.new(0, 3.5, 0)

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("MonsterId", def.Id)
	model:SetAttribute("Zone", zoneId)
	CollectionService:AddTag(model, "Monster")
	model.Parent = Workspace

	local agent: Agent = {
		Def = def, Model = model, Root = root, Humanoid = humanoid,
		ZoneId = zoneId, Home = position,
		State = S.PATROL, Target = nil, LastKnown = nil,
		Path = {}, PathIndex = 1, NextThink = 0, LostSince = 0,
		StunUntil = 0, NextAttack = 0,
		PatrolPoints = patrol, PatrolIndex = 1,
	}
	table.insert(agents, agent)
	return model
end

function MonsterService.stun(model: Model, seconds: number)
	for _, agent in ipairs(agents) do
		if agent.Model == model then
			agent.StunUntil = math.max(agent.StunUntil, os.clock() + seconds)
			agent.State = S.STUNNED
			signal(agent, "stunned")
			return true
		end
	end
	return false
end

function MonsterService.despawn(model: Model)
	for index = #agents, 1, -1 do
		if agents[index].Model == model then
			table.remove(agents, index)
		end
	end
	model:Destroy()
end

function MonsterService.count(): number
	return #agents
end

function MonsterService.init()
	RunService.Heartbeat:Connect(function(dt)
		for index = #agents, 1, -1 do
			local agent = agents[index]
			if not agent.Model.Parent or agent.Humanoid.Health <= 0 then
				table.remove(agents, index)
				agent.Model:Destroy()
			else
				move(agent, dt)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, agent in ipairs(agents) do
				if agent.Model.Parent then
					local ok, err = pcall(decide, agent)
					if not ok and GameConfig.Debug.Verbose then
						warn("[MonsterService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

-- Un assaut : le monstre le plus proche du refuge est envoyé dessus, et les
-- défenses lui coûtent du temps avant qu'il arrive.
function MonsterService.assault(shelterId: string)
	local shelter = ShelterService.get(shelterId)
	if not shelter or not shelter.Owner then
		return
	end
	local pivot = shelter.Model:GetPivot().Position
	local best, bestDistance = nil, math.huge
	for _, agent in ipairs(agents) do
		if agent.ZoneId == shelter.ZoneId then
			local distance = (agent.Root.Position - pivot).Magnitude
			if distance < bestDistance then
				best, bestDistance = agent, distance
			end
		end
	end
	if not best then
		return
	end

	local delay = ShelterService.absorbAssault(shelter)
	local profile = ShelterService.profileOf(shelter)
	signal(best, "assault")

	task.spawn(function()
		if delay > 0 then
			task.wait(delay)
		end
		if best.Model.Parent then
			best.State = S.CHASE
			best.LastKnown = pivot
			best.Target = shelter.Owner
			computePath(best, pivot)
		end
	end)
	-- Le profil de défense ne sert pas qu'au délai : il réduit aussi la chance
	-- que l'assaut suivant trouve le refuge.
	shelter.Model:SetAttribute("Detection", profile.Detection)
end

return MonsterService
