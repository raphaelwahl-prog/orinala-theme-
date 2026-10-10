--[[
	ThreatService — les créatures, leur comportement, leur traque.

	Ce n'est PAS un seul monstre. Il y a une créature par palier de planque,
	chacune avec son comportement et sa contre-mesure (voir EntityCatalog) :

	  Palier 2  LE VEILLEUR   lent, te perd si tu casses sa ligne de vue
	  Palier 3  LA RAMPANTE   aveugle, ne suit que le MOUVEMENT
	  Palier 4  LE MIME       se téléporte quand personne ne le regarde
	  Palier 5  L'AFFAMÉ      ne lâche jamais, ignore les murs du regard

	Le joueur n'apprend donc pas « le monstre », il apprend quatre monstres,
	et chacun lui demande un réflexe différent. C'est ça qui fait durer le jeu.

	Organisation du code : deux boucles séparées, exprès.
	  • Heartbeat        → déplacement, capture, balancement, lumières.
	    Doit être rapide et ne JAMAIS yielder.
	  • boucle décisions → choix de cible, calcul de chemin, téléportations.
	    Tourne 2 fois par seconde et peut yielder (ComputeAsync bloque).
	Mélanger les deux fait tomber le framerate du serveur en multijoueur.
]]

local Lighting = game:GetService("Lighting")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local EntityCatalog = require(Shared.EntityCatalog)
local GameConfig = require(Shared.GameConfig)
local Net = require(Shared.Net)

local EntityBuilder = require(script.Parent.EntityBuilder)

local ThreatService = {}

local FOLDER_NAME = "Entities"
local PARK_POSITION = Vector3.new(0, -500, 0)

local services
local folder: Folder
local instances: { [string]: any } = {}
local revealed: { [Player]: { [string]: boolean } } = {}
local trackedLights: { { Light: PointLight, Base: number } } = {}

function ThreatService.init(registry)
	services = registry
end

-- ─── utilitaires de monde ───────────────────────────────────────────────────

local function characterFilter(): { Instance }
	local filter = { folder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	return filter
end

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterFilter()

	local result = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -400, 0), params)
	if result then
		return result.Position
	end
	return position
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return nil
	end
	local part = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
	return part :: BasePart?
end

--[[ Y a-t-il un mur entre la créature et le joueur ? ]]
local function hasLineOfSight(from: Vector3, target: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterFilter()

	local delta = target.Position - from
	local result = Workspace:Raycast(from, delta, params)
	return result == nil
end

--[[ Un joueur vivant a-t-il cette créature dans son champ de vision ?

	 Le serveur ne connaît pas l'orientation des caméras : on approxime avec
	 l'orientation du PERSONNAGE. C'est volontairement généreux (demi-angle
	 d'environ 70°) et ça reste explicable au joueur : « tourne-toi vers lui et
	 il ne peut pas sauter ». Une règle un peu fausse mais lisible vaut mieux
	 qu'une règle exacte que personne ne comprend. ]]
local function isObservedByAnyone(position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterFilter()

	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		if root and not services.Life.isDown(player) then
			local delta = position - root.Position
			if delta.Magnitude < 90 and delta.Magnitude > 0.1 then
				local facing = root.CFrame.LookVector
				if facing:Dot(delta.Unit) > 0.35 then
					-- Dans le champ ET sans mur entre les deux.
					if Workspace:Raycast(root.Position, delta, params) == nil then
						return true
					end
				end
			end
		end
	end
	return false
end

local function playerSpeed(player: Player): number
	local root = rootOf(player)
	if not root then
		return 0
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

-- ─── création / cycle de vie des créatures ──────────────────────────────────

local function ensureFolder(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
    if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = Workspace
	return created
end

local function spawnInstance(def)
	local model = EntityBuilder.build(def)
	model.Parent = folder

	local instance = {
		Def = def,
		Model = model,
		Root = model.PrimaryPart,
		Offsets = EntityBuilder.offsets(model),
		BaseSizes = {},
		Mode = "Parked",
		Target = nil,
		LastKnown = nil,
		Waypoints = {},
		WaypointIndex = 1,
		HuntEndsAt = 0,
		LostSightFor = 0,
		StillFor = 0,
		NextTeleportAt = 0,
		NextRepathAt = 0,
		WalkPhase = 0,
		PatrolIndex = 0,
		Stats = EntityCatalog.resolve(def, 1),
	}

	-- Tailles d'origine, pour pouvoir agrandir la créature quand l'éveil monte.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			instance.BaseSizes[descendant] = descendant.Size
		end
	end

	if instance.Root then
		instance.Root.CFrame = CFrame.new(PARK_POSITION)
	end

	instances[def.Id] = instance
	return instance
end

local function getInstance(def)
	local instance = instances[def.Id]
	if instance and instance.Model and instance.Model.Parent then
		return instance
	end
	return spawnInstance(def)
end

--[[ Place le corps entier : torse d'abord, puis chaque partie à son décalage.
	 Obligatoire parce que les parties sont ancrées — voir la note technique
	 en haut de EntityBuilder.luau. ]]
local function placeBody(instance, cframe: CFrame, deltaTime: number, moving: boolean)
	local root = instance.Root
	if not root then
		return
	end
	root.CFrame = cframe

	if moving then
		instance.WalkPhase += deltaTime * (instance.Stats.Speed * 0.45)
	end
	local swing = math.sin(instance.WalkPhase) * (moving and 0.5 or 0.06)

	for _, entry in ipairs(instance.Offsets) do
		local part = entry.Part
		if part.Parent then
			if entry.Swing ~= 0 then
				part.CFrame = cframe * entry.Offset * CFrame.Angles(swing * entry.Swing, 0, 0)
			else
				part.CFrame = cframe * entry.Offset
			end
		end
	end
end

function ThreatService.park(def)
	for _, instance in pairs(instances) do
		instance.Mode = "Parked"
		instance.Target = nil
		instance.LastKnown = nil
		instance.Waypoints = {}
		if instance.Root then
			placeBody(instance, CFrame.new(PARK_POSITION), 0, false)
		end
		local disguise = instance.Model:FindFirstChild("Disguise")
		if disguise then
			disguise.Transparency = 0
		end
	end
end

--[[ Agrandit et accélère les créatures quand l'éveil monte. ]]
function ThreatService.rescale(stage: number)
	for _, instance in pairs(instances) do
		instance.Stats = EntityCatalog.resolve(instance.Def, stage)
		local scale = instance.Stats.Scale
		for part, baseSize in pairs(instance.BaseSizes) do
			if part.Parent then
				part.Size = baseSize * scale
			end
		end
		-- Les décalages doivent suivre l'échelle, sinon le corps se disloque.
		-- On repart TOUJOURS de BaseOffset (le décalage d'origine) : recalculer
		-- à partir de la valeur déjà mise à l'échelle accumulerait l'erreur à
		-- chaque changement de stade.
		for _, entry in ipairs(instance.Offsets) do
			local base = entry.BaseOffset
			local rotation = base - base.Position
			entry.Offset = CFrame.new(base.Position * scale) * rotation
		end
	end
end

-- ─── patrouille ─────────────────────────────────────────────────────────────

local function patrolPoints(): { BasePart }
	return services.Zone.getPatrolPoints()
end

local function nextPatrolTarget(instance): Vector3?
	local points = patrolPoints()
	if #points == 0 then
		return nil
	end
	instance.PatrolIndex = (instance.PatrolIndex % #points) + 1
	return groundAt(points[instance.PatrolIndex].Position)
end

--[[ Le Veilleur patrouille en permanence pendant la nuit : il y a toujours
	 quelque chose qui marche quelque part. C'est l'ambiance de base. ]]
function ThreatService.startPatrol()
	ThreatService.park()
	local watchman = EntityCatalog.forTier(2)
	if not watchman then
		return
	end
	local instance = getInstance(watchman)
	instance.Mode = "Patrol"
	local points = patrolPoints()
	if #points > 0 and instance.Root then
		placeBody(instance, CFrame.new(groundAt(points[1].Position)), 0, false)
	end
end

--[[ Stade 4 : L'AFFAMÉ sort, et il erre pour de bon. ]]
function ThreatService.releaseApex()
	local apex = EntityCatalog.forTier(5)
	if not apex then
		return
	end
	local instance = getInstance(apex)
	if instance.Mode == "Parked" then
		instance.Mode = "Patrol"
		local points = patrolPoints()
		if #points > 0 and instance.Root then
			placeBody(instance, CFrame.new(groundAt(points[#points].Position)), 0, false)
		end
	end
end

-- ─── chasse ─────────────────────────────────────────────────────────────────

--[[ Point d'apparition à `distance` studs de la planque : on veut que la
	 créature arrive pile à la fin de la fenêtre de fuite du joueur. ]]
local function pickSpawn(spotPosition: Vector3, distance: number): Vector3
	local best, bestError = nil, math.huge
	for _, point in ipairs(patrolPoints()) do
		local gap = (point.Position - spotPosition).Magnitude
		local errorMargin = math.abs(gap - distance)
		if gap > 12 and errorMargin < bestError then
			bestError, best = errorMargin, point.Position
		end
	end
	if best then
		return groundAt(best)
	end
	local angle = math.random() * math.pi * 2
	return groundAt(spotPosition + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance)
end

--[[ Appelé par SleepService quand un dormeur est repéré. ]]
function ThreatService.beginHunt(spot: BasePart, player: Player, window: number)
	local tier = services.Zone.getTier(spot)
	local def = EntityCatalog.forTier(tier)
	if not def then
		return -- palier 1 : personne ne vient.
	end

	local instance = getInstance(def)
	instance.Mode = "Hunt"
	instance.Target = player
	instance.LastKnown = spot.Position
	instance.HuntEndsAt = os.clock() + instance.Stats.HuntTimeout
	instance.LostSightFor = 0
	instance.StillFor = 0
	instance.NextTeleportAt = os.clock() + (def.Teleports or 999)
	instance.Waypoints = {}
	instance.NextRepathAt = 0

	local distance = math.max(18, window * instance.Stats.Speed)
	if instance.Root then
		placeBody(instance, CFrame.new(pickSpawn(spot.Position, distance)), 0, false)
	end

	-- Le déguisement du Mime tombe quand il chasse.
	local disguise = instance.Model:FindFirstChild("Disguise")
	if disguise then
		disguise.Transparency = 1
	end

	-- Première rencontre : on montre au joueur à qui il a affaire, avec la
	-- contre-mesure. Un joueur qui ne comprend pas pourquoi il meurt s'en va.
	revealed[player] = revealed[player] or {}
	if not revealed[player][def.Id] then
		revealed[player][def.Id] = true
		;(Net.get("EntityReveal") :: RemoteEvent):FireClient(player, {
			Name = def.Name,
			Tagline = def.Tagline,
			Counter = def.Counter,
			EyeColor = def.EyeColor,
		})
	end
end

function ThreatService.isHunting(): boolean
	for _, instance in pairs(instances) do
		if instance.Mode == "Hunt" then
			return true
		end
	end
	return false
end

--[[ Quelle créature est active en ce moment ? Pour le HUD. ]]
function ThreatService.activeEntityName(): string?
	for _, instance in pairs(instances) do
		if instance.Mode == "Hunt" then
			return instance.Def.Name
		end
	end
	return nil
end

function ThreatService.onPlayerRemoving(player: Player)
	revealed[player] = nil
	for _, instance in pairs(instances) do
		if instance.Target == player then
			instance.Target = nil
			instance.Mode = (instance.Mode == "Hunt") and "Search" or instance.Mode
		end
	end
end

-- ─── capture ────────────────────────────────────────────────────────────────

local function tryCatch(instance)
	local root = instance.Root
	if not root then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local target = rootOf(player)
		if target and not services.Life.isDown(player) then
			if (target.Position - root.Position).Magnitude <= instance.Stats.CatchRadius then
				services.Life.down(player, instance.Def.Id)
			end
		end
	end
end

-- ─── lumières qui vacillent ─────────────────────────────────────────────────

local function collectLights()
	trackedLights = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("PointLight") and not descendant:IsDescendantOf(folder) then
			table.insert(trackedLights, { Light = descendant, Base = descendant.Brightness })
		end
	end
end

--[[ Une ampoule qui grésille quand la créature approche, c'est l'effet le
	 moins cher et le plus efficace du jeu : le joueur sait avant de voir. ]]
local function updateFlicker()
	for _, entry in ipairs(trackedLights) do
		local light = entry.Light
		if light.Parent then
			local lightPosition = light.Parent:IsA("BasePart") and (light.Parent :: BasePart).Position or nil
			if lightPosition then
				local nearest = math.huge
				local flickerRange = 0
				for _, instance in pairs(instances) do
					if instance.Mode ~= "Parked" and instance.Root then
						local gap = (instance.Root.Position - lightPosition).Magnitude
						if gap < nearest then
							nearest = gap
							flickerRange = instance.Def.FlickerRange
						end
					end
				end
				if nearest < flickerRange then
					local closeness = 1 - (nearest / flickerRange)
					local noise = math.noise(os.clock() * 9, lightPosition.X * 0.1) * 0.5 + 0.5
					light.Brightness = entry.Base * (1 - closeness * (0.75 + 0.25 * noise))
				elseif light.Brightness ~= entry.Base then
					light.Brightness = entry.Base
				end
			end
		end
	end
end

-- ─── boucle de décisions (peut yielder) ─────────────────────────────────────

local function computePath(from: Vector3, to: Vector3): { Vector3 }
	local ok, result = pcall(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 3,
			AgentHeight = 6,
			AgentCanJump = false,
		})
		path:ComputeAsync(from, to)
		if path.Status ~= Enum.PathStatus.Success then
			return nil
		end
		local points = {}
		for _, waypoint in ipairs(path:GetWaypoints()) do
			table.insert(points, waypoint.Position)
		end
		return points
	end)
	if ok and type(result) == "table" and #result > 1 then
		return result
	end
	return { to }
end

local function setDestination(instance, target: Vector3)
	if not instance.Root then
		return
	end
	instance.Waypoints = computePath(instance.Root.Position, target)
	instance.WaypointIndex = 1
end

local function decideHunt(instance, step: number)
	local def = instance.Def
	local player = instance.Target
	local target = player and rootOf(player)

	if not target or (player and services.Life.isDown(player)) then
		instance.Target = nil
		instance.Mode = "Search"
		return
	end

	local root = instance.Root
	if not root then
		return
	end

	local gap = (target.Position - root.Position).Magnitude
	local sees = gap <= instance.Stats.SightRange and hasLineOfSight(root.Position + Vector3.new(0, 2, 0), target)

	-- LA RAMPANTE : aveugle. Elle ne suit que ce qui bouge.
	if def.Blind then
		if playerSpeed(player) < 2.5 then
			instance.StillFor += step
			if instance.StillFor >= def.Blind then
				instance.LastKnown = target.Position
				instance.Target = nil
				instance.Mode = "Search"
				return
			end
		else
			instance.StillFor = 0
		end
		-- Elle n'a pas besoin de ligne de vue : elle entend.
		sees = gap <= instance.Stats.SightRange
	end

	-- LE VEILLEUR : perd la trace si on casse sa ligne de vue assez longtemps.
	if def.LosesTrack and not def.Relentless then
		if sees then
			instance.LostSightFor = 0
		else
			instance.LostSightFor += step
			if instance.LostSightFor >= def.LosesTrack then
				instance.Target = nil
				instance.Mode = "Search"
				return
			end
		end
	end

	-- LE MIME : se rapproche par sauts, mais seulement si personne ne le regarde.
	if def.Teleports and os.clock() >= instance.NextTeleportAt then
		if not isObservedByAnyone(root.Position) then
			local candidates = patrolPoints()
			local best, bestGap = nil, gap
			for _, point in ipairs(candidates) do
				local candidateGap = (point.Position - target.Position).Magnitude
				if candidateGap < bestGap and candidateGap > 10 then
					bestGap, best = candidateGap, point.Position
				end
			end
			if best then
				placeBody(instance, CFrame.new(groundAt(best)), 0, false)
				instance.Waypoints = {}
			end
		end
		instance.NextTeleportAt = os.clock() + def.Teleports
	end

	if sees or def.Relentless then
		instance.LastKnown = target.Position
	end

	setDestination(instance, groundAt(instance.LastKnown or target.Position))

	if not def.Relentless and os.clock() >= instance.HuntEndsAt then
		instance.Target = nil
		instance.Mode = "Search"
	end
end

local function decideSearch(instance)
	local root = instance.Root
	if not root then
		return
	end
	-- Elle fouille le dernier endroit connu, puis repart en ronde.
	if instance.LastKnown and (root.Position - instance.LastKnown).Magnitude > 6 then
		setDestination(instance, groundAt(instance.LastKnown))
	else
		instance.LastKnown = nil
		instance.Mode = (instance.Def.Tier == 2 or instance.Def.Relentless) and "Patrol" or "Parked"
		if instance.Mode == "Parked" then
			placeBody(instance, CFrame.new(PARK_POSITION), 0, false)
		end
	end
end

local function decidePatrol(instance)
	if #instance.Waypoints == 0 or instance.WaypointIndex > #instance.Waypoints then
		local target = nextPatrolTarget(instance)
		if target then
			setDestination(instance, target)
		end
	end

	-- En ronde, une créature qui te croise de près te prend en chasse.
	local root = instance.Root
	if not root then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local target = rootOf(player)
		if target and not services.Life.isDown(player) then
			local gap = (target.Position - root.Position).Magnitude
			if gap <= instance.Stats.SightRange * 0.5 then
				local visible = instance.Def.Blind
					and playerSpeed(player) > 2.5
					or hasLineOfSight(root.Position + Vector3.new(0, 2, 0), target)
				if visible then
					instance.Mode = "Hunt"
					instance.Target = player
					instance.LastKnown = target.Position
					instance.HuntEndsAt = os.clock() + instance.Stats.HuntTimeout
					instance.LostSightFor = 0
					instance.StillFor = 0
					services.Notify.send(player, ("%s t'a vu."):format(instance.Def.Name), "danger")
					;(Net.get("DangerAlert") :: RemoteEvent):FireClient(player, 2)
					return
				end
			end
		end
	end
end

-- ─── démarrage ──────────────────────────────────────────────────────────────

function ThreatService.start()
	folder = ensureFolder()
	folder:ClearAllChildren()

	for tier = 2, GameConfig.MaxTier do
		local def = EntityCatalog.forTier(tier)
		if def then
			spawnInstance(def)
		end
	end

	collectLights()
	task.delay(5, collectLights)

	-- Boucle de décisions : peut yielder (le pathfinding bloque).
	task.spawn(function()
		local step = 0.5
		while true do
			task.wait(step)
			for _, instance in pairs(instances) do
				if instance.Mode == "Hunt" then
					decideHunt(instance, step)
				elseif instance.Mode == "Search" then
					decideSearch(instance)
				elseif instance.Mode == "Patrol" then
					decidePatrol(instance)
				end
			end
		end
	end)

	-- Boucle de rendu : déplacement, capture, corps, lumières. Jamais de yield.
	RunService.Heartbeat:Connect(function(deltaTime)
		for _, instance in pairs(instances) do
			if instance.Mode ~= "Parked" and instance.Root then
				local root = instance.Root
				local target = instance.Waypoints[instance.WaypointIndex]
				local moving = false

				if target then
					local current = root.Position
					local flat = Vector3.new(target.X - current.X, 0, target.Z - current.Z)
					if flat.Magnitude < 2.5 then
						instance.WaypointIndex += 1
					else
						local direction = flat.Unit
						local travel = math.min(instance.Stats.Speed * deltaTime, flat.Magnitude)
						local nextPosition = current + direction * travel
						local grounded = groundAt(nextPosition)
						local eyeHeight = instance.Def.Height * 0.55 * instance.Stats.Scale
						local placed = Vector3.new(nextPosition.X, grounded.Y + eyeHeight, nextPosition.Z)
						placeBody(instance, CFrame.lookAt(placed, placed + direction), deltaTime, true)
						moving = true
					end
				end

				if not moving then
					-- Respiration sur place : elle n'est jamais complètement immobile.
					placeBody(instance, root.CFrame, deltaTime, false)
				end

				-- Les yeux pulsent plus fort quand elle chasse.
				local head = instance.Model:FindFirstChild("Head")
				local glow = head and head:FindFirstChildOfClass("PointLight")
				if glow then
					local base = (instance.Mode == "Hunt") and 2.4 or 1.1
					glow.Brightness = base + math.sin(os.clock() * 6) * 0.35
				end

				tryCatch(instance)
			end
		end

		updateFlicker()
	end)
end

return ThreatService
