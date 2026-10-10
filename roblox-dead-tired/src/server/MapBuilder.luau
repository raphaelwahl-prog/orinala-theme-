--[[
	MapBuilder — génère une carte jouable au démarrage.

	Pourquoi générer la carte en code plutôt que te livrer un fichier à importer :
	tu peux lancer le jeu immédiatement, sans rien modéliser, et tu vois tout de
	suite si l'équilibrage te plaît. Quand tu auras ta vraie carte, tu mets
	`GameConfig.Map.UseGeneratedMap = false` et tu tagues tes propres parts.

	Choix de level design volontaire : plus un palier paie, plus sa salle est
	LOIN du coffre. Le risque n'est donc pas seulement le tirage pendant le
	sommeil, c'est aussi le trajet de retour avec l'argent sur toi.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local MapBuilder = {}

local FOLDER_NAME = "GeneratedMap"

local function part(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

local function label(parent: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Text = text
	textLabel.Parent = gui
end

-- ─── éléments ───────────────────────────────────────────────────────────────

local function buildRoom(folder: Folder, tier: number, center: Vector3)
	local tierData = GameConfig.Tiers[tier]
	local roomSize = Vector3.new(34, 1, 30)

	local floor = part({
		Name = ("Floor_T%d"):format(tier),
		Size = roomSize,
		Position = center,
		Color = Color3.fromRGB(46, 46, 52),
		Material = Enum.Material.Slate,
	})
	floor.Parent = folder

	-- Murs : trois côtés, l'entrée reste ouverte vers le hall.
	local wallHeight = 14
	local walls = {
		{ Vector3.new(roomSize.X, wallHeight, 1), center + Vector3.new(0, wallHeight / 2, -roomSize.Z / 2) },
		{ Vector3.new(1, wallHeight, roomSize.Z), center + Vector3.new(-roomSize.X / 2, wallHeight / 2, 0) },
		{ Vector3.new(1, wallHeight, roomSize.Z), center + Vector3.new(roomSize.X / 2, wallHeight / 2, 0) },
	}
	for index, spec in ipairs(walls) do
		local wall = part({
			Name = ("Wall_T%d_%d"):format(tier, index),
			Size = spec[1],
			Position = spec[2],
			Color = Color3.fromRGB(34, 34, 40),
			Material = Enum.Material.Brick,
		})
		wall.Parent = folder
	end

	-- La planque elle-même.
	local bed = part({
		Name = ("SleepSpot_T%d"):format(tier),
		Size = Vector3.new(7, 1.6, 12),
		Position = center + Vector3.new(0, 1.3, -4),
		Color = tierData.Color,
		Material = Enum.Material.Fabric,
	})
	bed:SetAttribute("Tier", tier)
	bed:SetAttribute("SpotLabel", tierData.Name)
	bed.Parent = folder
	CollectionService:AddTag(bed, "SleepSpot")

	label(bed, ("%s\n%d $/s · risque %s"):format(tierData.Name, tierData.Rate, tierData.RiskLabel:lower()), tierData.Color)

	-- Une lumière faible : juste assez pour trouver la salle, pas pour s'y sentir bien.
	local lamp = part({
		Name = ("Lamp_T%d"):format(tier),
		Size = Vector3.new(2, 0.4, 2),
		Position = center + Vector3.new(0, 12, 6),
		Color = Color3.fromRGB(20, 20, 20),
	})
	lamp.Parent = folder
	local light = Instance.new("PointLight")
	light.Brightness = 1.4
	light.Range = 26
	light.Color = tierData.Color:Lerp(Color3.new(1, 1, 1), 0.5)
	light.Parent = lamp

	-- Point de patrouille dans la salle : c'est aussi un point d'apparition
	-- possible pour le monstre quand il vient chercher quelqu'un.
	local patrol = part({
		Name = ("Patrol_T%d"):format(tier),
		Size = Vector3.new(2, 2, 2),
		Position = center + Vector3.new(0, 2, 10),
		Transparency = 1,
		CanCollide = false,
	})
	patrol.Parent = folder
	CollectionService:AddTag(patrol, "PatrolPoint")
end

local function buildLobby(folder: Folder)
	local floor = part({
		Name = "LobbyFloor",
		Size = Vector3.new(60, 1, 60),
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(62, 62, 70),
		Material = Enum.Material.Pavement,
	})
	floor.Parent = folder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1, 18)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.BrickColor = BrickColor.new("Institutional white")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Parent = folder

	-- Coffre.
	local vault = part({
		Name = "BankTerminal",
		Size = Vector3.new(6, 7, 3),
		Position = Vector3.new(-14, 4.5, 0),
		Color = Color3.fromRGB(70, 150, 90),
		Material = Enum.Material.Metal,
	})
	vault.Parent = folder
	CollectionService:AddTag(vault, "BankTerminal")
	label(vault, "COFFRE\nE pour déposer", Color3.fromRGB(130, 230, 160))

	-- Boutique.
	local shop = part({
		Name = "ShopTerminal",
		Size = Vector3.new(6, 7, 3),
		Position = Vector3.new(14, 4.5, 0),
		Color = Color3.fromRGB(90, 110, 190),
		Material = Enum.Material.Metal,
	})
	shop.Parent = folder
	CollectionService:AddTag(shop, "ShopTerminal")
	label(shop, "BOUTIQUE\nE pour ouvrir", Color3.fromRGB(150, 180, 255))

	-- Lumière du hall : c'est le seul endroit vraiment éclairé.
	local ceiling = part({
		Name = "LobbyLight",
		Size = Vector3.new(6, 0.4, 6),
		Position = Vector3.new(0, 16, 0),
		Color = Color3.fromRGB(240, 240, 220),
		Material = Enum.Material.Neon,
	})
	ceiling.Parent = folder
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 60
	light.Parent = ceiling

	-- Points de patrouille du hall.
	for _, position in ipairs({ Vector3.new(-22, 2, -22), Vector3.new(22, 2, -22), Vector3.new(0, 2, 24) }) do
		local patrol = part({
			Name = "Patrol_Lobby",
			Size = Vector3.new(2, 2, 2),
			Position = position,
			Transparency = 1,
			CanCollide = false,
		})
		patrol.Parent = folder
		CollectionService:AddTag(patrol, "PatrolPoint")
	end
end

local function buildCorridor(folder: Folder, from: Vector3, to: Vector3)
	local middle = (from + to) / 2
	local delta = to - from
	local length = Vector3.new(delta.X, 0, delta.Z).Magnitude

	local floor = part({
		Name = "Corridor",
		Size = Vector3.new(12, 1, length),
		CFrame = CFrame.lookAt(middle, middle + Vector3.new(delta.X, 0, delta.Z).Unit),
		Color = Color3.fromRGB(40, 40, 46),
		Material = Enum.Material.Slate,
	})
	floor.Parent = folder

	local patrol = part({
		Name = "Patrol_Corridor",
		Size = Vector3.new(2, 2, 2),
		Position = middle + Vector3.new(0, 2, 0),
		Transparency = 1,
		CanCollide = false,
	})
	patrol.Parent = folder
	CollectionService:AddTag(patrol, "PatrolPoint")
end

local function buildMonster(folder: Folder)
	local model = Instance.new("Model")
	model.Name = "Monster"

	local torso = part({
		Name = "Torso",
		Size = Vector3.new(3.5, 6, 2),
		Position = Vector3.new(0, 4, -60),
		Color = Color3.fromRGB(16, 12, 18),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	torso.Parent = model

	local head = part({
		Name = "Head",
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = torso.Position + Vector3.new(0, 4.2, 0),
		Color = Color3.fromRGB(26, 20, 28),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = head
	weld.Parent = torso

	-- Deux yeux : c'est ce qu'on voit en premier dans le noir, et ça suffit.
	for _, side in ipairs({ -0.6, 0.6 }) do
		local eye = part({
			Name = "Eye",
			Size = Vector3.new(0.45, 0.45, 0.2),
			Position = head.Position + Vector3.new(side, 0.2, -1.25),
			Color = Color3.fromRGB(255, 70, 60),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		eye.Parent = model
		local eyeWeld = Instance.new("WeldConstraint")
		eyeWeld.Part0 = head
		eyeWeld.Part1 = eye
		eyeWeld.Parent = head
	end

	local glow = Instance.new("PointLight")
	glow.Brightness = 1.1
	glow.Range = 16
	glow.Color = Color3.fromRGB(255, 60, 50)
	glow.Parent = head

	model.PrimaryPart = torso
	model.Parent = folder
	CollectionService:AddTag(model, "Monster")
end

-- ─── point d'entrée ─────────────────────────────────────────────────────────

function MapBuilder.build()
	if not GameConfig.Map.UseGeneratedMap then
		return
	end

	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	if GameConfig.Map.RemoveBaseplate then
		local baseplate = Workspace:FindFirstChild("Baseplate")
		if baseplate then
			baseplate:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	buildLobby(folder)

	-- Les salles s'éloignent du hall à mesure que le palier monte : plus ça
	-- paie, plus le retour au coffre est long.
	local layout = {
		[1] = Vector3.new(-50, 0, 0),
		[2] = Vector3.new(50, 0, 0),
		[3] = Vector3.new(0, 0, -62),
		[4] = Vector3.new(-78, 0, -70),
		[5] = Vector3.new(84, 0, -84),
	}

	for tier, center in pairs(layout) do
		buildRoom(folder, tier, center)
		buildCorridor(folder, Vector3.new(0, 0, 0), center)
	end

	buildMonster(folder)

	print("[MapBuilder] carte générée : 5 planques, coffre, boutique, 1 monstre.")
end

return MapBuilder
