--!strict
-- Construit « La rue » au démarrage : immeubles, ruelles, refuges, PNJ, coffre,
-- boutique, points de patrouille et l'entrée des égouts.
--
-- Tout est généré en code pour que la place s'ouvre et se joue sans qu'aucun
-- modèle ne soit à importer. Quand tu voudras une vraie ville modélisée, il
-- suffira de remplacer ce fichier : le reste du jeu ne connaît la carte que par
-- les tags (`Shelter`, `Npc`, `ZoneGate`) et les attributs.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local MissionConfig = require(script.Parent.Parent.Shared.MissionConfig)

local CityBuilder = {}

local STREET_LENGTH = 420
local STREET_WIDTH = 60

local function part(name: string, size: Vector3, position: Vector3, color: Color3,
	material: Enum.Material?, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function light(parent: BasePart, color: Color3, brightness: number, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Parent = parent
end

local function sign(text: string, parent: BasePart, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 2.4)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
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

local function buildShelter(index: number, position: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Shelter_" .. index

	local floor = part("Floor", Vector3.new(16, 1, 16), position, Color3.fromRGB(58, 54, 50),
		Enum.Material.WoodPlanks, model)
	part("WallBack", Vector3.new(16, 12, 1), position + Vector3.new(0, 6, -7.5),
		Color3.fromRGB(44, 42, 44), Enum.Material.Brick, model)
	part("WallLeft", Vector3.new(1, 12, 16), position + Vector3.new(-7.5, 6, 0),
		Color3.fromRGB(44, 42, 44), Enum.Material.Brick, model)
	part("WallRight", Vector3.new(1, 12, 16), position + Vector3.new(7.5, 6, 0),
		Color3.fromRGB(44, 42, 44), Enum.Material.Brick, model)
	part("Roof", Vector3.new(16, 1, 16), position + Vector3.new(0, 12, 0),
		Color3.fromRGB(36, 34, 36), Enum.Material.Metal, model)

	local bed = part("Bed", Vector3.new(6, 1.6, 10), position + Vector3.new(0, 1.3, 1),
		Color3.fromRGB(92, 62, 58), Enum.Material.Fabric, model)
	sign("REFUGE " .. index, bed, Color3.fromRGB(230, 226, 220))
	light(bed, Color3.fromRGB(255, 196, 120), 1.4, 22)

	model.PrimaryPart = floor
	model:SetAttribute("ShelterId", "street_" .. index)
	model:SetAttribute("Zone", "street")
	model:SetAttribute("OwnerName", "")
	CollectionService:AddTag(model, "Shelter")
	model.Parent = parent
	return model
end

local function buildNpc(def, position: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Npc_" .. def.Id

	local body = part("Torso", Vector3.new(2, 3, 1.2), position + Vector3.new(0, 3.5, 0),
		Color3.fromRGB(58, 70, 98), Enum.Material.Fabric, model)
	part("Head", Vector3.new(1.6, 1.6, 1.6), position + Vector3.new(0, 5.9, 0),
		Color3.fromRGB(214, 176, 132), Enum.Material.SmoothPlastic, model)
	part("Legs", Vector3.new(2, 2, 1.2), position + Vector3.new(0, 1, 0),
		Color3.fromRGB(38, 40, 48), Enum.Material.Fabric, model)
	sign(def.Name, body, Color3.fromRGB(255, 214, 140))
	light(body, Color3.fromRGB(255, 214, 140), 0.8, 16)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Parler"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	model.PrimaryPart = body
	model:SetAttribute("NpcId", def.Id)
	CollectionService:AddTag(model, "Npc")
	model.Parent = parent
	return model
end

function CityBuilder.build(): { Patrol: { Vector3 }, MonsterSpawns: { Vector3 } }
	local existing = Workspace:FindFirstChild("City")
	if existing then
		existing:Destroy()
	end

	local city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = Workspace

	-- Chaussée et trottoirs
	part("Road", Vector3.new(STREET_WIDTH, 1, STREET_LENGTH), Vector3.new(0, 0, 0),
		Color3.fromRGB(34, 34, 38), Enum.Material.Asphalt, city)
	for _, side in ipairs({ -1, 1 }) do
		part("Sidewalk" .. side, Vector3.new(10, 1.6, STREET_LENGTH),
			Vector3.new(side * (STREET_WIDTH / 2 - 5), 0.3, 0),
			Color3.fromRGB(62, 62, 66), Enum.Material.Concrete, city)
	end

	-- Immeubles des deux côtés, avec des ruelles régulières
	local buildings = Instance.new("Folder")
	buildings.Name = "Buildings"
	buildings.Parent = city
	for _, side in ipairs({ -1, 1 }) do
		local z = -STREET_LENGTH / 2 + 30
		while z < STREET_LENGTH / 2 - 30 do
			local depth = 46 + (z % 7) * 3
			local height = 60 + ((z + side * 13) % 11) * 9
			local x = side * (STREET_WIDTH / 2 + depth / 2 - 2)
			local tint = 38 + ((z + side * 5) % 9) * 3
			part("Block", Vector3.new(depth, height, 56),
				Vector3.new(x, height / 2, z),
				Color3.fromRGB(tint, tint - 2, tint + 4), Enum.Material.Brick, buildings)
			z += 56 + 24   -- 24 studs de ruelle entre deux immeubles
		end
	end

	-- Lampadaires
	for z = -STREET_LENGTH / 2 + 40, STREET_LENGTH / 2 - 40, 70 do
		for _, side in ipairs({ -1, 1 }) do
			local pole = part("Pole", Vector3.new(0.8, 18, 0.8),
				Vector3.new(side * (STREET_WIDTH / 2 - 8), 9, z),
				Color3.fromRGB(28, 28, 32), Enum.Material.Metal, city)
			local head = part("Lamp", Vector3.new(3, 0.8, 3),
				pole.Position + Vector3.new(0, 9, 0),
				Color3.fromRGB(255, 224, 170), Enum.Material.Neon, city)
			light(head, Color3.fromRGB(255, 220, 170), 2.2, 52)
		end
	end

	-- Refuges, dans les ruelles
	local shelters = Instance.new("Folder")
	shelters.Name = "Shelters"
	shelters.Parent = city
	local index = 0
	for _, side in ipairs({ -1, 1 }) do
		for step = 0, 2 do
			index += 1
			local z = -STREET_LENGTH / 2 + 95 + step * 110
			buildShelter(index, Vector3.new(side * (STREET_WIDTH / 2 + 12), 1, z), shelters)
		end
	end

	-- Coffre (dépôt) et boutique, au centre de la rue
	local vault = part("Vault", Vector3.new(10, 10, 6), Vector3.new(-18, 5, 0),
		Color3.fromRGB(46, 108, 70), Enum.Material.DiamondPlate, city)
	sign("COFFRE — E pour déposer", vault, Color3.fromRGB(120, 230, 160))
	light(vault, Color3.fromRGB(110, 230, 160), 2, 34)
	CollectionService:AddTag(vault, "Vault")
	local vaultPrompt = Instance.new("ProximityPrompt")
	vaultPrompt.ActionText = "Déposer"
	vaultPrompt.ObjectText = "Coffre"
	vaultPrompt.MaxActivationDistance = 14
	vaultPrompt.RequiresLineOfSight = false
	vaultPrompt.Parent = vault

	local shop = part("Shop", Vector3.new(10, 10, 6), Vector3.new(18, 5, 0),
		Color3.fromRGB(58, 70, 126), Enum.Material.Metal, city)
	sign("BOUTIQUE — E pour ouvrir", shop, Color3.fromRGB(150, 180, 255))
	light(shop, Color3.fromRGB(140, 170, 255), 2, 34)
	CollectionService:AddTag(shop, "Shop")
	local shopPrompt = Instance.new("ProximityPrompt")
	shopPrompt.ActionText = "Ouvrir"
	shopPrompt.ObjectText = "Boutique"
	shopPrompt.MaxActivationDistance = 14
	shopPrompt.RequiresLineOfSight = false
	shopPrompt.Parent = shop

	-- PNJ
	local npcs = Instance.new("Folder")
	npcs.Name = "Npcs"
	npcs.Parent = city
	for i, def in ipairs(MissionConfig.Npcs) do
		local z = -60 + (i - 1) * 24
		buildNpc(def, Vector3.new((i % 2 == 0) and 22 or -22, 1, z), npcs)
	end

	-- Entrée des égouts : la porte vers la zone 2
	local gate = part("SewerGate", Vector3.new(12, 1.2, 12), Vector3.new(0, 0.8, STREET_LENGTH / 2 - 50),
		Color3.fromRGB(70, 66, 58), Enum.Material.Metal, city)
	sign("ÉGOUTS — zone 2", gate, Color3.fromRGB(180, 230, 180))
	CollectionService:AddTag(gate, "ZoneGate")
	gate:SetAttribute("Zone", "sewers")
	local gatePrompt = Instance.new("ProximityPrompt")
	gatePrompt.ActionText = "Descendre"
	gatePrompt.ObjectText = "Les égouts"
	gatePrompt.MaxActivationDistance = 12
	gatePrompt.RequiresLineOfSight = false
	gatePrompt.Parent = gate

	-- Apparition des joueurs
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StreetSpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 1, -STREET_LENGTH / 2 + 30)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(70, 70, 78)
	spawn.Material = Enum.Material.Concrete
	spawn.Parent = city

	-- Points de ronde et d'apparition des monstres
	local patrol: { Vector3 } = {}
	for z = -STREET_LENGTH / 2 + 50, STREET_LENGTH / 2 - 50, 52 do
		table.insert(patrol, Vector3.new(-14, 3, z))
		table.insert(patrol, Vector3.new(14, 3, z + 26))
	end
	local spawns: { Vector3 } = {
		Vector3.new(0, 3, STREET_LENGTH / 2 - 70),
		Vector3.new(-20, 3, 40),
		Vector3.new(20, 3, -40),
	}

	return { Patrol = patrol, MonsterSpawns = spawns }
end

return CityBuilder
