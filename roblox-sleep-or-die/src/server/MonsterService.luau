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
local MonsterRig = require(script.Parent.MonsterRig)
local SoundLib = require(script.Parent.SoundService)
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
	Rig: any,
	Walk: number,
	LastStep: number,
	NextThink: number,
	LostSince: number,
	StunUntil: number,
	NextAttack: number,
	NextTrick: number,
	PatrolPoints: { Vector3 },
	PatrolIndex: number,
}

local agents: { Agent } = {}
local signalListeners: { (string, string, Vector3) -> () } = {}

-- Multiplicateurs imposés par l'éveil de la maison. Ils s'appliquent à TOUS
-- les monstres du serveur, y compris ceux déjà sur le terrain.
local globalSpeed, globalSight = 1, 1

function MonsterService.applyGlobal(speed: number, sight: number)
	globalSpeed, globalSight = speed, sight
end

function MonsterService.globals(): (number, number)
	return globalSpeed, globalSight
end

-- Multiplicateurs imposés par l'événement du serveur (§13). Ils sont tenus
-- SÉPARÉS de ceux de l'éveil, et pas écrits dans les mêmes variables : sinon
-- le dernier des deux services à parler effacerait l'autre, et on aurait un
-- événement qui annule l'éveil ou l'inverse selon l'ordre d'appel.
-- Les deux se cumulent par multiplication.
local eventSpeed, eventPopulation = 1, 1
local eventZone = "any"

function MonsterService.applyEvent(speed: number, population: number, zoneId: string)
	eventSpeed, eventPopulation, eventZone = speed, population, zoneId
end

local function factorsFor(zoneId: string): (number, number)
	if eventZone ~= "any" and eventZone ~= zoneId then
		return 1, 1
	end
	return eventSpeed, eventPopulation
end

function MonsterService.eventFactors(zoneId: string): (number, number)
	return factorsFor(zoneId)
end

-- Plafond de monstres d'un type dans une zone. Un seul endroit le calcule :
-- si le peuplement et l'apparition ne sont pas d'accord, la zone se remplit à
-- moitié et l'événement « Invasion de la rue » ne se voit jamais.
function MonsterService.capFor(def: MonsterConfig.Monster, zoneId: string): number
	local _, population = factorsFor(zoneId)
	return math.max(1, math.floor(def.MaxAlive * population))
end

function MonsterService.onSignal(fn: (string, string, Vector3) -> ())
	table.insert(signalListeners, fn)
end

local function signal(agent: Agent, kind: string)
	for _, fn in ipairs(signalListeners) do
		task.spawn(fn, agent.Def.Id, kind, agent.Root.Position)
	end
end

function MonsterService.countInZone(zoneId: string): number
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
		local range = (loud and agent.Def.HearRange or agent.Def.HearRange * 0.45) * globalSight
		return distance <= range
	end

	if distance > agent.Def.SightRange * globalSight then
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

		-- Mécanique « disable » (le couvent) : en approchant, l'entité éteint
		-- les défenses du refuge de sa cible. Le CDC le dit : « Les défenses
		-- peuvent être neutralisées. » C'est ce qui oblige à prévoir une fuite.
		if agent.Def.Rule == "disable" and os.clock() >= agent.NextTrick then
			agent.NextTrick = os.clock() + 20
			local shelter = ShelterService.ownedBy(target)
			if shelter and shelter.Occupied then
				ShelterService.disableDefenses(shelter, 14)
				signal(agent, "disable")
			end
		end
		if distance <= agent.Def.AttackRange then
			agent.State = S.ATTACK
		else
			if agent.State ~= S.CHASE then
				agent.State = S.CHASE
				signal(agent, "spotted")
				SoundLib.playAt("monster_spot", agent.Root)
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

	-- Mécanique « fake_alerts » (l'hôpital) : le menteur émet régulièrement un
	-- signal d'assaut depuis un endroit où il n'est pas. Une alerte sur trois
	-- est vraie ; les joueurs doivent apprendre à croiser deux signaux.
	if agent.Def.Rule == "fake_alerts" and os.clock() >= agent.NextTrick then
		agent.NextTrick = os.clock() + 9 + math.random() * 7
		local decoy = agent.PatrolPoints[math.random(1, math.max(1, #agent.PatrolPoints))]
		if decoy then
			for _, fn in ipairs(signalListeners) do
				task.spawn(fn, agent.Def.Id, "fake", decoy)
			end
		end
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
		-- Étourdi : les membres retombent au lieu de rester figés en pleine
		-- foulée, c'est ce qui fait lire l'état d'un coup d'œil.
		MonsterRig.animate(agent.Rig, 0, 0)
		return
	end

	local eSpeed = (factorsFor(agent.ZoneId))
	local speed = agent.Def.WalkSpeed * globalSpeed * eSpeed
	if agent.State == S.PATROL then
		speed *= 0.55
	end
	agent.Humanoid.WalkSpeed = speed

	-- Animation : la phase avance avec la vitesse réelle, donc les jambes
	-- suivent le déplacement au lieu de pédaler dans le vide.
	local moving = agent.Path[agent.PathIndex] ~= nil
	agent.Walk += dt * speed * 0.42
	MonsterRig.animate(agent.Rig, agent.Walk, moving and 0.85 or 0.06)

	-- Un pas par demi-cycle de jambes : le son colle à l'animation, et c'est
	-- ce qui permet d'entendre arriver un monstre avant de le voir.
	if moving and agent.Walk >= agent.LastStep + math.pi then
		agent.LastStep = agent.Walk
		SoundLib.playAt(agent.Def.Height > 8 and "monster_heavy" or "monster_step", agent.Root)
	end

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
		SoundLib.playAt("monster_attack", agent.Root)
	end
end

local function create(def: MonsterConfig.Monster, zoneId: string, position: Vector3,
	patrol: { Vector3 }): Model
	-- Un vrai squelette R6, avec des membres qui bougent.
	local model, rig = MonsterRig.build(def, position)
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	model:SetAttribute("Zone", zoneId)
	CollectionService:AddTag(model, "Monster")
	model.Parent = Workspace

	local agent: Agent = {
		Def = def, Model = model, Root = root, Humanoid = humanoid,
		ZoneId = zoneId, Home = position,
		State = S.PATROL, Target = nil, LastKnown = nil,
		Path = {}, PathIndex = 1, NextThink = 0, LostSince = 0,
		Rig = rig, Walk = 0, LastStep = 0,
		StunUntil = 0, NextAttack = 0, NextTrick = 0,
		PatrolPoints = patrol, PatrolIndex = 1,
	}
	table.insert(agents, agent)
	return model
end

function MonsterService.spawn(def: MonsterConfig.Monster, zoneId: string, position: Vector3,
	patrol: { Vector3 }): Model?
	if MonsterService.countInZone(zoneId) >= MonsterService.capFor(def, zoneId) then
		return nil
	end
	return create(def, zoneId, position, patrol)
end

-- Apparition qui ignore le plafond, pour les monstres uniques : le boss du
-- carnaval et le mini-boss d'événement. Sans elle, un unique ne naît pas quand
-- la zone est pleine — et c'est exactement pendant un événement d'invasion
-- qu'elle est pleine, donc précisément quand on a besoin de lui.
function MonsterService.spawnUnique(def: MonsterConfig.Monster, zoneId: string,
	position: Vector3, patrol: { Vector3 }): Model
	return create(def, zoneId, position, patrol)
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

-- Accès contrôlé pour BossService : il pilote les phases du clown.
function MonsterService.find(model: Model)
	for _, agent in ipairs(agents) do
		if agent.Model == model then
			return agent
		end
	end
	return nil
end

function MonsterService.setRule(model: Model, rule: string)
	local agent = MonsterService.find(model)
	if agent then
		-- On remplace la règle de l'agent sans toucher au catalogue partagé.
		local copy = table.clone(agent.Def)
		copy.Rule = rule
		agent.Def = copy
	end
end

function MonsterService.boost(model: Model, speed: number, sight: number)
	local agent = MonsterService.find(model)
	if agent then
		local copy = table.clone(agent.Def)
		copy.WalkSpeed = speed
		copy.SightRange = sight
		agent.Def = copy
	end
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
	local pivotPart = shelter.Model.PrimaryPart
	SoundLib.playAt("assault", pivotPart)
	if delay > 0 then
		SoundLib.playAt("alarm", pivotPart)
	end

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
