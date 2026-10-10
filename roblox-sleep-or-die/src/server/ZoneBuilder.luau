--!strict
-- Primitives de construction, partagées par les sept zones.
--
-- Chaque zone occupe une dalle de 1600 studs sur l'axe X : la rue en 0, les
-- égouts en 1600, et ainsi de suite. Elles ne se voient pas, ne s'entendent pas
-- et ne se gênent pas. On passe de l'une à l'autre par une porte (`ZoneGate`)
-- qui téléporte — personne ne traverse 1600 studs à pied.
--
-- Le reste du jeu ne connaît les zones que par trois tags (`Shelter`, `Npc`,
-- `ZoneGate`) et des attributs. Remplacer une de ces fonctions par une vraie
-- carte modélisée ne demande de toucher à aucun service.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ZoneBuilder = {}

ZoneBuilder.SPACING = 1600

export type Layout = {
	Patrol: { Vector3 },
	Spawns: { Vector3 },
	Anchor: Vector3,
}

function ZoneBuilder.origin(order: number): Vector3
	return Vector3.new((order - 1) * ZoneBuilder.SPACING, 0, 0)
end

function ZoneBuilder.part(name: string, size: Vector3, position: Vector3, color: Color3,
	material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function ZoneBuilder.light(parent: BasePart, color: Color3, brightness: number, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Parent = parent
end

function ZoneBuilder.sign(text: string, parent: BasePart, color: Color3, distance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(11, 2.6)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.MaxDistance = distance or 130
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

-- Un sol plat avec quatre murs et un plafond. `gaps` liste les ouvertures :
-- "north", "south", "east", "west".
function ZoneBuilder.room(center: Vector3, width: number, depth: number, height: number,
	color: Color3, material: Enum.Material, parent: Instance, gaps: { string }?)
	local open: { [string]: boolean } = {}
	for _, side in ipairs(gaps or {}) do
		open[side] = true
	end
	local T = 2
	ZoneBuilder.part("Floor", Vector3.new(width, 1, depth), center, color, material, parent)
	ZoneBuilder.part("Ceiling", Vector3.new(width, 1, depth),
		center + Vector3.new(0, height, 0), color, material, parent)

	local function wall(name: string, size: Vector3, offset: Vector3, side: string)
		if open[side] then
			-- Une ouverture de 16 studs au milieu : deux pans au lieu d'un mur.
			local along = size.X > size.Z
			local span = along and size.X or size.Z
			local piece = (span - 16) / 2
			if piece <= 0 then
				return
			end
			for _, sign in ipairs({ -1, 1 }) do
				local shift = along and Vector3.new(sign * (span - piece) / 2, 0, 0)
					or Vector3.new(0, 0, sign * (span - piece) / 2)
				local newSize = along and Vector3.new(piece, size.Y, size.Z)
					or Vector3.new(size.X, size.Y, piece)
				ZoneBuilder.part(name, newSize, center + offset + shift, color, material, parent)
			end
		else
			ZoneBuilder.part(name, size, center + offset, color, material, parent)
		end
	end

	wall("WallN", Vector3.new(width, height, T), Vector3.new(0, height / 2, -depth / 2), "north")
	wall("WallS", Vector3.new(width, height, T), Vector3.new(0, height / 2, depth / 2), "south")
	wall("WallW", Vector3.new(T, height, depth), Vector3.new(-width / 2, height / 2, 0), "west")
	wall("WallE", Vector3.new(T, height, depth), Vector3.new(width / 2, height / 2, 0), "east")
end

function ZoneBuilder.corridor(from: Vector3, to: Vector3, width: number, height: number,
	color: Color3, material: Enum.Material, parent: Instance)
	local delta = to - from
	local length = delta.Magnitude
	local center = from + delta / 2
	local along = math.abs(delta.X) > math.abs(delta.Z)
	local size = along and Vector3.new(length, 1, width) or Vector3.new(width, 1, length)
	ZoneBuilder.part("Floor", size, center, color, material, parent)
	ZoneBuilder.part("Ceiling", size, center + Vector3.new(0, height, 0), color, material, parent)
	local wallSize = along and Vector3.new(length, height, 2) or Vector3.new(2, height, length)
	local side = along and Vector3.new(0, 0, width / 2) or Vector3.new(width / 2, 0, 0)
	local up = Vector3.new(0, height / 2, 0)
	ZoneBuilder.part("WallA", wallSize, center + side + up, color, material, parent)
	ZoneBuilder.part("WallB", wallSize, center - side + up, color, material, parent)
end

local shelterCount = 0

-- Un refuge : plateforme, trois murs, un lit. C'est le seul objet que
-- ShelterService regarde, via son tag et ses attributs.
function ZoneBuilder.shelter(zoneId: string, position: Vector3, bedColor: Color3,
	parent: Instance): Model
	shelterCount += 1
	local index = shelterCount
	local model = Instance.new("Model")
	model.Name = "Shelter_" .. zoneId .. "_" .. index

	local floor = ZoneBuilder.part("Floor", Vector3.new(16, 1, 16), position,
		Color3.fromRGB(58, 54, 50), Enum.Material.WoodPlanks, model)
	ZoneBuilder.part("WallBack", Vector3.new(16, 11, 1), position + Vector3.new(0, 5.5, -7.5),
		Color3.fromRGB(44, 42, 44), Enum.Material.Brick, model)
	ZoneBuilder.part("WallLeft", Vector3.new(1, 11, 16), position + Vector3.new(-7.5, 5.5, 0),
		Color3.fromRGB(44, 42, 44), Enum.Material.Brick, model)
	ZoneBuilder.part("WallRight", Vector3.new(1, 11, 16), position + Vector3.new(7.5, 5.5, 0),
		Color3.fromRGB(44, 42, 44), Enum.Material.Brick, model)
	ZoneBuilder.part("Roof", Vector3.new(16, 1, 16), position + Vector3.new(0, 11, 0),
		Color3.fromRGB(36, 34, 36), Enum.Material.Metal, model)

	local bed = ZoneBuilder.part("Bed", Vector3.new(6, 1.6, 10),
		position + Vector3.new(0, 1.3, 1), bedColor, Enum.Material.Fabric, model)
	ZoneBuilder.sign("REFUGE " .. index, bed, Color3.fromRGB(230, 226, 220))
	ZoneBuilder.light(bed, bedColor, 1.3, 22)

	model.PrimaryPart = floor
	model:SetAttribute("ShelterId", zoneId .. "_" .. index)
	model:SetAttribute("Zone", zoneId)
	model:SetAttribute("OwnerName", "")
	CollectionService:AddTag(model, "Shelter")
	model.Parent = parent
	return model
end

function ZoneBuilder.gate(targetZone: string, label: string, position: Vector3,
	color: Color3, parent: Instance): Part
	local gate = ZoneBuilder.part("Gate_" .. targetZone, Vector3.new(14, 1.4, 14), position,
		color, Enum.Material.Metal, parent)
	ZoneBuilder.sign(label, gate, Color3.fromRGB(220, 230, 220))
	ZoneBuilder.light(gate, color, 2, 30)
	CollectionService:AddTag(gate, "ZoneGate")
	gate:SetAttribute("Zone", targetZone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Passer"
	prompt.ObjectText = label
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Parent = gate
	return gate
end

-- Objets de mission : caisse à ramasser, pièce à réparer, survivant à aider,
-- colis à livrer. Tous marqués par un tag ; MissionService écoute leurs
-- ProximityPrompt côté serveur.
function ZoneBuilder.objective(kind: string, zoneId: string, position: Vector3,
	parent: Instance): Part
	local palette = {
		collect = Color3.fromRGB(190, 150, 70),
		repair = Color3.fromRGB(90, 150, 200),
		rescue = Color3.fromRGB(200, 120, 120),
		deliver = Color3.fromRGB(150, 190, 120),
	}
	local labels = {
		collect = "Ressources", repair = "Pièce de générateur",
		rescue = "Survivant", deliver = "Colis",
	}
	local color = palette[kind] or Color3.fromRGB(160, 160, 160)
	local part = ZoneBuilder.part("Objective_" .. kind, Vector3.new(3.5, 4, 3.5), position,
		color, Enum.Material.WoodPlanks, parent)
	ZoneBuilder.sign(labels[kind] or kind, part, color, 70)
	ZoneBuilder.light(part, color, 1, 14)
	CollectionService:AddTag(part, "Objective")
	part:SetAttribute("Goal", kind)
	part:SetAttribute("Zone", zoneId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Prendre"
	prompt.ObjectText = labels[kind] or kind
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return part
end

-- Particules d'ambiance. On n'utilise que les textures livrées avec Roblox
-- (`rbxasset://`) : elles existent dans toutes les installations, il n'y a
-- rien à téléverser et rien qui puisse être modéré un jour.
function ZoneBuilder.particles(position: Vector3, size: Vector3, kind: string, parent: Instance)
	local anchor = ZoneBuilder.part("Ambience", size, position,
		Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, parent)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false

	local emitter = Instance.new("ParticleEmitter")
	emitter.Parent = anchor
	emitter.Rate = 14
	emitter.Lifetime = NumberRange.new(6, 12)
	emitter.Speed = NumberRange.new(0.4, 1.4)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-12, 12)
	emitter.LightEmission = 0.15
	emitter.LockedToPart = false

	if kind == "dust" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(150, 160, 140))
		emitter.Size = NumberSequence.new(1.2)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Acceleration = Vector3.new(0.2, 0.3, 0)
	elseif kind == "fog" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(160, 162, 170))
		emitter.Size = NumberSequence.new(26)
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(14, 22)
		emitter.Speed = NumberRange.new(0.2, 0.6)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.92),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif kind == "embers" then
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 120, 90))
		emitter.Size = NumberSequence.new(0.5)
		emitter.LightEmission = 0.9
		emitter.Rate = 20
		emitter.Speed = NumberRange.new(1, 3)
		emitter.Acceleration = Vector3.new(0, 2.5, 0)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	emitter.EmissionDirection = Enum.NormalId.Top
	return anchor
end

function ZoneBuilder.spawnPoint(position: Vector3, parent: Instance): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = position
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = false   -- une seule apparition active : celle de la rue
	spawn.Color = Color3.fromRGB(70, 70, 78)
	spawn.Material = Enum.Material.Concrete
	spawn.Parent = parent
	return spawn
end

function ZoneBuilder.folder(zoneId: string): Folder
	local root = Workspace:FindFirstChild("Zones")
	if not root then
		root = Instance.new("Folder")
		root.Name = "Zones"
		root.Parent = Workspace
	end
	local existing = root:FindFirstChild(zoneId)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = zoneId
	folder.Parent = root
	return folder
end

function ZoneBuilder.reset()
	shelterCount = 0
	local root = Workspace:FindFirstChild("Zones")
	if root then
		root:Destroy()
	end
end

return ZoneBuilder
