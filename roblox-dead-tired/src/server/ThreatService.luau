--[[
	ThreatService — le monstre.

	Deux états seulement, et c'est volontaire : un comportement lisible est plus
	effrayant qu'une IA compliquée que le joueur ne comprend pas.

	  PATROUILLE — il fait le tour des points tagués "PatrolPoint", lentement.
	  CHASSE     — il a été lancé sur une planque précise par SleepService.
	               Il apparaît à une distance calculée pour arriver pile à la fin
	               de la fenêtre de fuite du joueur, puis il avance tout droit.

	Pourquoi on le fait apparaître près du joueur au lieu de le faire traverser
	la carte : si le monstre était toujours loin, le tirage de risque ne voudrait
	rien dire. En le plaçant à `fenêtre × vitesse` studs, le danger est réel mais
	la fuite est toujours possible. Le joueur l'entend et le voit venir.
]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local ThreatService = {}

local TAG_MONSTER = "Monster"

local services
local monster: Model? = nil
local root: BasePart? = nil

local mode = "Idle" -- "Idle" | "Patrol" | "Hunt"
local waypoints: { Vector3 } = {}
local waypointIndex = 1
local huntTarget: Player? = nil
local huntSpotPosition: Vector3? = nil
local huntEndsAt = 0
local patrolIndex = 0

function ThreatService.init(registry)
	services = registry
end

-- ─── mise en place ──────────────────────────────────────────────────────────

local function bind(model: Instance)
	if not model:IsA("Model") then
		return
	end
	monster = model
	root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		warn("[ThreatService] le modèle du monstre n'a aucune BasePart.")
		return
	end
	-- Il ne doit pas être poussé par les joueurs ni tomber.
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Anchored = true
			descendant.Massless = true
		end
	end
end

function ThreatService.getModel(): Model?
	return monster
end

-- ─── déplacement ────────────────────────────────────────────────────────────

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = { }
	if monster then
		table.insert(filter, monster)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	params.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -300, 0), params)
	if result then
		return result.Position + Vector3.new(0, 3, 0)
	end
	return position
end

--[[ Calcule un chemin. Retombe sur la ligne droite si le pathfinding échoue
	 (carte sans navmesh propre, zone non atteignable…). ]]
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

local function setDestination(target: Vector3)
	if not root then
		return
	end
	waypoints = computePath(root.Position, target)
	waypointIndex = 1
end

-- ─── patrouille ─────────────────────────────────────────────────────────────

local function nextPatrolTarget(): Vector3?
	local points = services.Zone.getPatrolPoints()
	if #points == 0 then
		return nil
	end
	patrolIndex = (patrolIndex % #points) + 1
	return groundAt(points[patrolIndex].Position)
end

function ThreatService.startPatrol()
	mode = "Patrol"
	huntTarget = nil
	huntSpotPosition = nil
	local target = nextPatrolTarget()
	if target then
		setDestination(target)
	else
		waypoints = {}
	end
end

function ThreatService.park()
	mode = "Idle"
	huntTarget = nil
	huntSpotPosition = nil
	waypoints = {}
	-- On le remet sur un point de patrouille, hors de vue des planques.
	local points = services.Zone.getPatrolPoints()
	if root and #points > 0 then
		root.CFrame = CFrame.new(groundAt(points[1].Position))
	end
end

-- ─── chasse ─────────────────────────────────────────────────────────────────

--[[ Choisit un point d'apparition à `distance` studs de la planque.
	 On privilégie un point de patrouille existant (donc sur le sol et
	 atteignable) dont l'éloignement est le plus proche de la cible. ]]
local function pickSpawn(spotPosition: Vector3, distance: number): Vector3
	local best: Vector3? = nil
	local bestError = math.huge

	for _, point in ipairs(services.Zone.getPatrolPoints()) do
		local gap = (point.Position - spotPosition).Magnitude
		local errorMargin = math.abs(gap - distance)
		if gap > 12 and errorMargin < bestError then
			bestError = errorMargin
			best = point.Position
		end
	end

	if best then
		return groundAt(best)
	end

	-- Aucun point utilisable : on décale dans une direction au hasard.
	local angle = math.random() * math.pi * 2
	local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
	return groundAt(spotPosition + offset)
end

--[[ Lancé par SleepService quand un dormeur est repéré.
	 `window` = secondes de fuite promises au joueur. ]]
function ThreatService.beginHunt(spot: BasePart, player: Player, window: number)
	if not (monster and root) then
		return
	end
	if not spot.Parent then
		return
	end

	mode = "Hunt"
	huntTarget = player
	huntSpotPosition = spot.Position
	huntEndsAt = os.clock() + GameConfig.Threat.HuntTimeout

	local distance = math.max(18, window * GameConfig.Threat.HuntSpeed)
	root.CFrame = CFrame.new(pickSpawn(spot.Position, distance))
	setDestination(groundAt(spot.Position))
end

function ThreatService.isHunting(): boolean
	return mode == "Hunt"
end

-- ─── capture ────────────────────────────────────────────────────────────────

local function tryCatch()
	if not root then
		return
	end
	local origin = root.Position

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local primary = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
		if primary then
			local gap = ((primary :: BasePart).Position - origin).Magnitude
			if gap <= GameConfig.Threat.CatchRadius and not services.Life.isDown(player) then
				services.Life.down(player, "monster")
			end
		end
	end
end

--[[ Pendant une chasse, s'il croise quelqu'un de plus près que sa cible,
	 il change d'avis. C'est ce qui rend les sauvetages tendus. ]]
local function retargetOpportunistically()
	if not (root and mode == "Hunt") then
		return
	end
	local origin = root.Position
	local closest: Player? = nil
	local closestGap = GameConfig.Threat.OpportunisticSightRange

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local primary = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
		if primary and not services.Life.isDown(player) then
			local gap = ((primary :: BasePart).Position - origin).Magnitude
			if gap < closestGap then
				closestGap = gap
				closest = player
			end
		end
	end

	if closest then
		local character = closest.Character
		local primary = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
		if primary then
			huntTarget = closest
			setDestination(groundAt((primary :: BasePart).Position))
		end
	end
end

-- ─── boucle ─────────────────────────────────────────────────────────────────

function ThreatService.start()
	for _, instance in ipairs(CollectionService:GetTagged(TAG_MONSTER)) do
		bind(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG_MONSTER):Connect(bind)

	if not monster then
		warn("[ThreatService] aucun modèle tagué \"Monster\". Le jeu tourne, "
			.. "mais personne ne viendra te chercher.")
	end

	local retargetAccumulator = 0

	RunService.Heartbeat:Connect(function(deltaTime)
		if not (monster and root) or mode == "Idle" then
			return
		end

		local speed = (mode == "Hunt") and GameConfig.Threat.HuntSpeed or GameConfig.Threat.PatrolSpeed

		-- Avance vers le prochain point du chemin.
		local target = waypoints[waypointIndex]
		if target then
			local current = root.Position
			local direction = target - current
			local flat = Vector3.new(direction.X, 0, direction.Z)

			if flat.Magnitude < 2.5 then
				waypointIndex += 1
			else
				local step = flat.Unit * math.min(speed * deltaTime, flat.Magnitude)
				local nextPosition = groundAt(current + step)
				root.CFrame = CFrame.lookAt(nextPosition, nextPosition + flat.Unit)
			end
		else
			-- Plus de chemin.
			if mode == "Patrol" then
				local nextTarget = nextPatrolTarget()
				if nextTarget then
					setDestination(nextTarget)
				end
			elseif mode == "Hunt" then
				-- Arrivé sur la planque : il fouille un peu, puis repart.
				if huntTarget then
					local character = huntTarget.Character
					local primary = character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
					if primary then
						setDestination(groundAt((primary :: BasePart).Position))
					end
				end
			end
		end

		tryCatch()

		if mode == "Hunt" then
			retargetAccumulator += deltaTime
			if retargetAccumulator >= 1.5 then
				retargetAccumulator = 0
				retargetOpportunistically()
			end
			if os.clock() >= huntEndsAt then
				services.Notify.broadcast("Il a lâché la piste.", "info")
				ThreatService.startPatrol()
			end
		end
	end)
end

return ThreatService
