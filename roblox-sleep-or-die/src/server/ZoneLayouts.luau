--!strict
-- Les sept cartes. Une fonction par zone, toutes bâties avec les primitives de
-- ZoneBuilder, toutes renvoyant la même chose : points de ronde, points
-- d'apparition des monstres, et le point d'arrivée quand on entre dans la zone.
--
-- Chaque zone a son identité visuelle (couleur, matière, densité) parce que
-- c'est ce qui fait qu'on sait où on est sans lire le HUD.

local CollectionService = game:GetService("CollectionService")

local MissionConfig = require(script.Parent.Parent.Shared.MissionConfig)
local ZoneBuilder = require(script.Parent.ZoneBuilder)

local B = ZoneBuilder
local Layouts = {}

local function npc(def, position: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Npc_" .. def.Id
	local body = B.part("Torso", Vector3.new(2, 3, 1.2), position + Vector3.new(0, 3.5, 0),
		Color3.fromRGB(58, 70, 98), Enum.Material.Fabric, model)
	B.part("Head", Vector3.new(1.6, 1.6, 1.6), position + Vector3.new(0, 5.9, 0),
		Color3.fromRGB(214, 176, 132), Enum.Material.SmoothPlastic, model)
	B.part("Legs", Vector3.new(2, 2, 1.2), position + Vector3.new(0, 1, 0),
		Color3.fromRGB(38, 40, 48), Enum.Material.Fabric, model)
	B.sign(def.Name, body, Color3.fromRGB(255, 214, 140))
	B.light(body, Color3.fromRGB(255, 214, 140), 0.8, 16)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Parler"
	prompt.ObjectText = def.Name
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	model.PrimaryPart = body
	model:SetAttribute("NpcId", def.Id)
	CollectionService:AddTag(model, "Npc")
	model.Parent = parent
	return model
end

-- ═══ 1. LA RUE ════════════════════════════════════════════════════════════
-- Ville ouverte, immeubles hauts, ruelles. C'est ici que vivent le coffre, la
-- boutique et les six PNJ : on y revient entre chaque session.
function Layouts.street(origin: Vector3, folder: Folder): ZoneBuilder.Layout
	local LENGTH, WIDTH = 420, 60
	local asphalt = Color3.fromRGB(34, 34, 38)

	B.part("Road", Vector3.new(WIDTH, 1, LENGTH), origin, asphalt, Enum.Material.Asphalt, folder)
	for _, side in ipairs({ -1, 1 }) do
		B.part("Sidewalk", Vector3.new(10, 1.6, LENGTH),
			origin + Vector3.new(side * (WIDTH / 2 - 5), 0.3, 0),
			Color3.fromRGB(62, 62, 66), Enum.Material.Concrete, folder)
		local z = -LENGTH / 2 + 30
		while z < LENGTH / 2 - 30 do
			local depth = 46 + (z % 7) * 3
			local height = 60 + ((z + side * 13) % 11) * 9
			local tint = 38 + ((z + side * 5) % 9) * 3
			B.part("Block", Vector3.new(depth, height, 56),
				origin + Vector3.new(side * (WIDTH / 2 + depth / 2 - 2), height / 2, z),
				Color3.fromRGB(tint, tint - 2, tint + 4), Enum.Material.Brick, folder)
			z += 80
		end
	end

	for z = -LENGTH / 2 + 40, LENGTH / 2 - 40, 70 do
		for _, side in ipairs({ -1, 1 }) do
			local pole = B.part("Pole", Vector3.new(0.8, 18, 0.8),
				origin + Vector3.new(side * (WIDTH / 2 - 8), 9, z),
				Color3.fromRGB(28, 28, 32), Enum.Material.Metal, folder)
			local head = B.part("Lamp", Vector3.new(3, 0.8, 3),
				pole.Position + Vector3.new(0, 9, 0),
				Color3.fromRGB(255, 224, 170), Enum.Material.Neon, folder)
			B.light(head, Color3.fromRGB(255, 220, 170), 2.2, 52)
		end
	end

	for _, side in ipairs({ -1, 1 }) do
		for step = 0, 2 do
			B.shelter("street", origin + Vector3.new(side * (WIDTH / 2 + 12), 1,
				-LENGTH / 2 + 95 + step * 110), Color3.fromRGB(92, 62, 58), folder)
		end
	end

	-- Coffre et boutique : ils n'existent que dans la rue, c'est le camp de base.
	local vault = B.part("Vault", Vector3.new(10, 10, 6), origin + Vector3.new(-18, 5, 0),
		Color3.fromRGB(46, 108, 70), Enum.Material.DiamondPlate, folder)
	B.sign("COFFRE — déposer", vault, Color3.fromRGB(120, 230, 160))
	B.light(vault, Color3.fromRGB(110, 230, 160), 2, 34)
	CollectionService:AddTag(vault, "Vault")
	local vp = Instance.new("ProximityPrompt")
	vp.ActionText = "Déposer"; vp.ObjectText = "Coffre"
	vp.MaxActivationDistance = 14; vp.RequiresLineOfSight = false
	vp.Parent = vault

	local shop = B.part("Shop", Vector3.new(10, 10, 6), origin + Vector3.new(18, 5, 0),
		Color3.fromRGB(58, 70, 126), Enum.Material.Metal, folder)
	B.sign("BOUTIQUE", shop, Color3.fromRGB(150, 180, 255))
	B.light(shop, Color3.fromRGB(140, 170, 255), 2, 34)
	CollectionService:AddTag(shop, "Shop")
	local sp = Instance.new("ProximityPrompt")
	sp.ActionText = "Ouvrir"; sp.ObjectText = "Boutique"
	sp.MaxActivationDistance = 14; sp.RequiresLineOfSight = false
	sp.Parent = shop

	for i, def in ipairs(MissionConfig.Npcs) do
		npc(def, origin + Vector3.new((i % 2 == 0) and 22 or -22, 1, -60 + (i - 1) * 24), folder)
	end

	for i = 1, 5 do
		B.objective("collect", "street", origin + Vector3.new(
			(i % 2 == 0) and 24 or -24, 3, -150 + i * 60), folder)
	end
	B.objective("deliver", "street", origin + Vector3.new(0, 3, -120), folder)

	B.gate("sewers", "ÉGOUTS — zone 2", origin + Vector3.new(0, 0.8, LENGTH / 2 - 50),
		Color3.fromRGB(70, 90, 70), folder)

	local spawn = B.spawnPoint(origin + Vector3.new(0, 1, -LENGTH / 2 + 30), folder)
	spawn.Enabled = true
	B.particles(origin + Vector3.new(0, 6, 0), Vector3.new(WIDTH, 2, LENGTH), "dust", folder)

	local patrol = {}
	for z = -LENGTH / 2 + 50, LENGTH / 2 - 50, 52 do
		table.insert(patrol, origin + Vector3.new(-14, 3, z))
		table.insert(patrol, origin + Vector3.new(14, 3, z + 26))
	end
	return {
		Patrol = patrol,
		Spawns = {
			origin + Vector3.new(0, 3, LENGTH / 2 - 70),
			origin + Vector3.new(-20, 3, 40),
			origin + Vector3.new(20, 3, -40),
		},
		Anchor = origin + Vector3.new(0, 4, -LENGTH / 2 + 30),
	}
end

-- ═══ 2. LES ÉGOUTS ════════════════════════════════════════════════════════
-- Tunnels étroits en grille. Peu de lumière, beaucoup d'angles morts : c'est la
-- zone où le son compte plus que la vue, et le monstre est fait pour ça.
function Layouts.sewers(origin: Vector3, folder: Folder): ZoneBuilder.Layout
	local stone = Color3.fromRGB(46, 50, 46)
	local H = 16
	local patrol, spawns = {}, {}

	-- Trois galeries est-ouest reliées par trois puits nord-sud.
	for row = -1, 1 do
		local z = row * 90
		B.corridor(origin + Vector3.new(-200, 0, z), origin + Vector3.new(200, 0, z),
			22, H, stone, Enum.Material.Slate, folder)
		for x = -160, 160, 80 do
			table.insert(patrol, origin + Vector3.new(x, 3, z))
		end
	end
	for col = -1, 1 do
		local x = col * 150
		B.corridor(origin + Vector3.new(x, 0, -90), origin + Vector3.new(x, 0, 90),
			20, H, stone, Enum.Material.Slate, folder)
		table.insert(patrol, origin + Vector3.new(x, 3, 0))
	end

	-- Canal central : l'eau empêche de couper droit.
	B.part("Water", Vector3.new(360, 1, 10), origin + Vector3.new(0, 0.4, 0),
		Color3.fromRGB(36, 56, 50), Enum.Material.Water, folder)

	-- Lanternes espacées, volontairement insuffisantes.
	for x = -170, 170, 85 do
		for _, z in ipairs({ -90, 0, 90 }) do
			local lamp = B.part("Lamp", Vector3.new(2, 0.6, 2),
				origin + Vector3.new(x, H - 2, z), Color3.fromRGB(150, 200, 160),
				Enum.Material.Neon, folder)
			B.light(lamp, Color3.fromRGB(130, 200, 160), 1.4, 36)
		end
	end

	-- Alcôves : cinq refuges au bout de niches, un seul accès chacun.
	for i, spot in ipairs({
		Vector3.new(-190, 1, -90), Vector3.new(190, 1, -90),
		Vector3.new(-190, 1, 90), Vector3.new(190, 1, 90),
		Vector3.new(0, 1, 90),
	}) do
		B.shelter("sewers", origin + spot, Color3.fromRGB(64, 92, 74), folder)
	end

	for i = 1, 3 do
		B.objective("repair", "sewers", origin + Vector3.new(-120 + i * 120, 3, -90), folder)
	end
	B.objective("rescue", "sewers", origin + Vector3.new(0, 3, -90), folder)

	B.gate("street", "RETOUR — la rue", origin + Vector3.new(-200, 0.8, 0),
		Color3.fromRGB(90, 90, 70), folder)
	B.gate("dollhouse", "MAISON DES POUPÉES — zone 3", origin + Vector3.new(200, 0.8, 0),
		Color3.fromRGB(120, 80, 110), folder)
	B.spawnPoint(origin + Vector3.new(-170, 1, 0), folder)
	for _, z in ipairs({ -90, 0, 90 }) do
		B.particles(origin + Vector3.new(0, 4, z), Vector3.new(380, 2, 16), "dust", folder)
	end

	spawns = {
		origin + Vector3.new(120, 3, 90),
		origin + Vector3.new(-120, 3, -90),
		origin + Vector3.new(0, 3, 60),
	}
	return { Patrol = patrol, Spawns = spawns, Anchor = origin + Vector3.new(-170, 4, 0) }
end

-- ═══ 3. LA MAISON DES POUPÉES ═════════════════════════════════════════════
-- Une maison bourgeoise : hall central, six chambres autour. Les lignes de vue
-- sont longues et dégagées — c'est ce qui rend la mécanique du regard jouable.
function Layouts.dollhouse(origin: Vector3, folder: Folder): ZoneBuilder.Layout
	local wood = Color3.fromRGB(78, 58, 46)
	local H = 22
	local patrol = {}

	B.room(origin, 120, 90, H, wood, Enum.Material.WoodPlanks, folder,
		{ "north", "south", "east", "west" })
	table.insert(patrol, origin + Vector3.new(0, 3, 0))

	local rooms = {
		{ Vector3.new(-110, 0, -70), "east" }, { Vector3.new(110, 0, -70), "west" },
		{ Vector3.new(-110, 0, 70), "east" }, { Vector3.new(110, 0, 70), "west" },
		{ Vector3.new(0, 0, -110), "south" }, { Vector3.new(0, 0, 110), "north" },
	}
	for i, entry in ipairs(rooms) do
		local center = origin + entry[1]
		B.room(center, 70, 60, H, wood, Enum.Material.WoodPlanks, folder, { entry[2] })
		B.corridor(center, origin, 16, H, wood, Enum.Material.WoodPlanks, folder)
		B.shelter("dollhouse", center + Vector3.new(0, 1, 0), Color3.fromRGB(150, 96, 120), folder)
		table.insert(patrol, center + Vector3.new(14, 3, 0))
		table.insert(patrol, center + Vector3.new(-14, 3, 0))
	end

	-- Lustres : la maison est éclairée, et c'est voulu. On la voit arriver.
	for _, point in ipairs({ Vector3.new(0, 0, 0), Vector3.new(-110, 0, -70),
		Vector3.new(110, 0, 70) }) do
		local lamp = B.part("Chandelier", Vector3.new(5, 1, 5),
			origin + point + Vector3.new(0, H - 3, 0),
			Color3.fromRGB(255, 216, 170), Enum.Material.Neon, folder)
		B.light(lamp, Color3.fromRGB(255, 210, 160), 2.4, 70)
	end

	for i = 1, 5 do
		B.objective("collect", "dollhouse",
			origin + rooms[i][1] + Vector3.new(20, 3, 18), folder)
	end

	B.gate("sewers", "RETOUR — les égouts", origin + Vector3.new(-55, 1.4, 0),
		Color3.fromRGB(70, 90, 70), folder)
	B.gate("slasher", "QUARTIER DU SLASHER — zone 4", origin + Vector3.new(55, 1.4, 0),
		Color3.fromRGB(130, 60, 60), folder)
	B.spawnPoint(origin + Vector3.new(0, 1, 30), folder)
	B.particles(origin + Vector3.new(0, 8, 0), Vector3.new(110, 2, 80), "dust", folder)

	return {
		Patrol = patrol,
		Spawns = { origin + Vector3.new(0, 3, -110), origin + Vector3.new(110, 3, 70) },
		Anchor = origin + Vector3.new(0, 4, 30),
	}
end

-- ═══ 4. LE QUARTIER DU SLASHER ════════════════════════════════════════════
-- Pavillons autour d'une boucle, haies, raccourcis entre les jardins. Le
-- monstre est lent : toute la zone est dessinée pour qu'on puisse le semer en
-- connaissant les passages.
function Layouts.slasher(origin: Vector3, folder: Folder): ZoneBuilder.Layout
	local road = Color3.fromRGB(42, 40, 44)
	local patrol = {}
	local R = 170

	-- Boucle de bitume
	for angle = 0, 350, 10 do
		local a = math.rad(angle)
		local next_a = math.rad(angle + 10)
		local from = origin + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
		local to = origin + Vector3.new(math.cos(next_a) * R, 0, math.sin(next_a) * R)
		local mid = (from + to) / 2
		local seg = (to - from).Magnitude + 4
		local piece = B.part("Road", Vector3.new(seg, 1, 26), mid, road,
			Enum.Material.Asphalt, folder)
		piece.Orientation = Vector3.new(0, -angle - 5, 0)
		if angle % 40 == 0 then
			table.insert(patrol, mid + Vector3.new(0, 3, 0))
		end
	end

	-- Six pavillons, chacun avec son garage-refuge
	for i = 0, 5 do
		local a = math.rad(i * 60 + 20)
		local center = origin + Vector3.new(math.cos(a) * (R + 55), 0, math.sin(a) * (R + 55))
		B.room(center, 60, 50, 20, Color3.fromRGB(70, 62, 58), Enum.Material.Brick, folder,
			{ "south" })
		B.shelter("slasher", center + Vector3.new(0, 1, 34), Color3.fromRGB(170, 70, 60), folder)
		table.insert(patrol, center + Vector3.new(0, 3, 40))
		-- Haies : elles cassent la ligne de vue sans bloquer le passage.
		for side = -1, 1, 2 do
			B.part("Hedge", Vector3.new(4, 9, 40), center + Vector3.new(side * 34, 4.5, 20),
				Color3.fromRGB(34, 56, 38), Enum.Material.Grass, folder)
		end
	end

	-- Brume : un plafond bas et sombre au-dessus de la boucle.
	B.part("Fog", Vector3.new(R * 2.6, 1, R * 2.6), origin + Vector3.new(0, 40, 0),
		Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic, folder)

	for i = 1, 3 do
		B.objective("deliver", "slasher",
			origin + Vector3.new(math.cos(i * 2) * R, 3, math.sin(i * 2) * R), folder)
	end

	B.gate("dollhouse", "RETOUR — la maison", origin + Vector3.new(0, 1.4, -R + 10),
		Color3.fromRGB(120, 80, 110), folder)
	B.gate("convent", "COUVENT MAUDIT — zone 5", origin + Vector3.new(0, 1.4, R - 10),
		Color3.fromRGB(90, 80, 130), folder)
	B.spawnPoint(origin + Vector3.new(0, 1, 0), folder)
	-- La brume du quartier, c'est la moitié de la peur : on l'entend arriver
	-- avant de le voir.
	for i = 0, 5 do
		local a = math.rad(i * 60)
		B.particles(origin + Vector3.new(math.cos(a) * R, 4, math.sin(a) * R),
			Vector3.new(90, 2, 90), "fog", folder)
	end

	return {
		Patrol = patrol,
		Spawns = { origin + Vector3.new(R, 3, 0) },
		Anchor = origin + Vector3.new(0, 4, 0),
	}
end

-- ═══ 5. LE COUVENT MAUDIT ═════════════════════════════════════════════════
-- Nef, cloître carré, cellules. L'entité neutralise les défenses : la zone
-- donne donc beaucoup de portes et de sorties, parce qu'il faut pouvoir fuir.
function Layouts.convent(origin: Vector3, folder: Folder): ZoneBuilder.Layout
	local stone = Color3.fromRGB(62, 60, 66)
	local H = 34
	local patrol = {}

	B.room(origin + Vector3.new(0, 0, -120), 70, 200, H, stone, Enum.Material.Marble, folder,
		{ "south" })
	for z = -200, -40, 32 do
		for side = -1, 1, 2 do
			B.part("Column", Vector3.new(7, H, 7),
				origin + Vector3.new(side * 24, H / 2, z), stone, Enum.Material.Marble, folder)
		end
		table.insert(patrol, origin + Vector3.new(0, 3, z))
	end

	-- Cloître : un carré ouvert au centre, six cellules autour.
	local C = 110
	B.part("CloisterFloor", Vector3.new(C * 2, 1, C * 2), origin + Vector3.new(0, 0, 60),
		Color3.fromRGB(48, 52, 44), Enum.Material.Grass, folder)
	for i = 0, 5 do
		local a = math.rad(i * 60 + 30)
		local center = origin + Vector3.new(math.cos(a) * C, 0, 60 + math.sin(a) * C)
		B.room(center, 44, 40, 22, stone, Enum.Material.Marble, folder, { "north" })
		B.shelter("convent", center + Vector3.new(0, 1, 0), Color3.fromRGB(120, 100, 180), folder)
		table.insert(patrol, center + Vector3.new(0, 3, 26))
	end

	for _, point in ipairs({ Vector3.new(0, 0, -120), Vector3.new(0, 0, 60) }) do
		local brazier = B.part("Brazier", Vector3.new(6, 2, 6),
			origin + point + Vector3.new(0, 4, 0),
			Color3.fromRGB(255, 140, 70), Enum.Material.Neon, folder)
		B.light(brazier, Color3.fromRGB(255, 130, 60), 3, 90)
	end

	B.objective("collect", "convent", origin + Vector3.new(0, 3, -200), folder)

	B.gate("slasher", "RETOUR — le quartier", origin + Vector3.new(-40, 1.4, 60),
		Color3.fromRGB(130, 60, 60), folder)
	B.gate("hospital", "HÔPITAL DES CAUCHEMARS — zone 6", origin + Vector3.new(40, 1.4, 60),
		Color3.fromRGB(80, 120, 130), folder)
	B.spawnPoint(origin + Vector3.new(0, 1, 0), folder)
	for _, point in ipairs({ Vector3.new(0, 0, -120), Vector3.new(0, 0, 60) }) do
		B.particles(origin + point + Vector3.new(0, 6, 0), Vector3.new(8, 2, 8),
			"embers", folder)
	end

	return {
		Patrol = patrol,
		Spawns = { origin + Vector3.new(0, 3, -180), origin + Vector3.new(C, 3, 60) },
		Anchor = origin + Vector3.new(0, 4, 0),
	}
end

-- ═══ 6. L'HÔPITAL DES CAUCHEMARS ══════════════════════════════════════════
-- Un couloir central très long, huit chambres de chaque côté. Les portes se
-- ressemblent toutes : c'est le décor qui rend les fausses alertes efficaces.
function Layouts.hospital(origin: Vector3, folder: Folder): ZoneBuilder.Layout
	local tile = Color3.fromRGB(78, 84, 86)
	local H = 20
	local patrol = {}

	B.corridor(origin + Vector3.new(0, 0, -200), origin + Vector3.new(0, 0, 200),
		26, H, tile, Enum.Material.Concrete, folder)
	for z = -180, 180, 45 do
		table.insert(patrol, origin + Vector3.new(0, 3, z))
	end

	for i = 0, 7 do
		local side = (i % 2 == 0) and -1 or 1
		local z = -170 + math.floor(i / 2) * 110
		local center = origin + Vector3.new(side * 60, 0, z)
		B.room(center, 70, 70, H, tile, Enum.Material.Concrete, folder,
			{ side < 0 and "east" or "west" })
		B.corridor(center, origin + Vector3.new(0, 0, z), 14, H, tile,
			Enum.Material.Concrete, folder)
		if i < 6 then
			B.shelter("hospital", center + Vector3.new(0, 1, 0),
				Color3.fromRGB(90, 150, 160), folder)
		end
		table.insert(patrol, center + Vector3.new(0, 3, 0))
	end

	for z = -160, 160, 80 do
		local tube = B.part("Tube", Vector3.new(8, 0.6, 2),
			origin + Vector3.new(0, H - 2, z), Color3.fromRGB(200, 240, 245),
			Enum.Material.Neon, folder)
		B.light(tube, Color3.fromRGB(190, 235, 245), 1.8, 46)
	end

	for i = 1, 3 do
		B.objective("repair", "hospital", origin + Vector3.new(0, 3, -120 + i * 110), folder)
	end

	B.gate("convent", "RETOUR — le couvent", origin + Vector3.new(0, 1.4, -200),
		Color3.fromRGB(90, 80, 130), folder)
	-- L'entrée du carnaval n'est pas sur le couloir : elle est au fond d'une
	-- chambre, comme le demande la mission « La porte derrière l'hôpital ».
	B.gate("carnival", "??? — une porte qui ne devrait pas être là",
		origin + Vector3.new(60, 1.4, 160), Color3.fromRGB(180, 60, 110), folder)
	B.spawnPoint(origin + Vector3.new(0, 1, -190), folder)
	B.particles(origin + Vector3.new(0, 5, 0), Vector3.new(24, 2, 380), "dust", folder)

	return {
		Patrol = patrol,
		Spawns = { origin + Vector3.new(0, 3, 150), origin + Vector3.new(-60, 3, -60) },
		Anchor = origin + Vector3.new(0, 4, -190),
	}
end

-- ═══ 7. LE CARNAVAL DE L'ENFER ════════════════════════════════════════════
-- Six tentes autour d'un chapiteau. Le chapiteau est l'arène du boss : un
-- cercle dégagé, sans mur pour se cacher, avec seulement des mâts.
function Layouts.carnival(origin: Vector3, folder: Folder): ZoneBuilder.Layout
	local ground = Color3.fromRGB(48, 36, 40)
	local patrol = {}
	local R = 150

	B.part("Ground", Vector3.new(560, 1, 560), origin, ground, Enum.Material.Ground, folder)

	-- Chapiteau : anneau de mâts et toit.
	for angle = 0, 350, 30 do
		local a = math.rad(angle)
		local mast = B.part("Mast", Vector3.new(5, 60, 5),
			origin + Vector3.new(math.cos(a) * 110, 30, math.sin(a) * 110),
			Color3.fromRGB(140, 40, 50), Enum.Material.Fabric, folder)
		if angle % 90 == 0 then
			B.light(mast, Color3.fromRGB(255, 90, 90), 2, 70)
			table.insert(patrol, origin + Vector3.new(math.cos(a) * 80, 3, math.sin(a) * 80))
		end
	end
	B.part("BigTop", Vector3.new(250, 2, 250), origin + Vector3.new(0, 60, 0),
		Color3.fromRGB(120, 32, 44), Enum.Material.Fabric, folder)
	local ring = B.part("Ring", Vector3.new(180, 0.6, 180), origin + Vector3.new(0, 0.8, 0),
		Color3.fromRGB(90, 30, 36), Enum.Material.Sand, folder)
	CollectionService:AddTag(ring, "BossArena")
	ring:SetAttribute("Zone", "carnival")

	-- Six tentes de forains, quatre abritent un refuge.
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local center = origin + Vector3.new(math.cos(a) * (R + 90), 0, math.sin(a) * (R + 90))
		B.room(center, 56, 56, 26, Color3.fromRGB(96, 44, 70), Enum.Material.Fabric, folder,
			{ "north" })
		if i < 4 then
			B.shelter("carnival", center + Vector3.new(0, 1, 0),
				Color3.fromRGB(190, 70, 150), folder)
		end
		table.insert(patrol, center + Vector3.new(0, 3, 34))
		local bulb = B.part("Bulb", Vector3.new(3, 3, 3), center + Vector3.new(0, 24, 0),
			Color3.fromRGB(255, 120, 200), Enum.Material.Neon, folder)
		B.light(bulb, Color3.fromRGB(255, 110, 190), 2.2, 60)
	end

	B.objective("collect", "carnival", origin + Vector3.new(0, 3, R + 40), folder)

	B.gate("hospital", "RETOUR — l'hôpital", origin + Vector3.new(0, 1.4, -(R + 150)),
		Color3.fromRGB(80, 120, 130), folder)
	B.spawnPoint(origin + Vector3.new(0, 1, -(R + 120)), folder)
	B.particles(origin + Vector3.new(0, 3, 0), Vector3.new(170, 2, 170), "embers", folder)

	return {
		Patrol = patrol,
		Spawns = { origin + Vector3.new(0, 3, 0) },
		Anchor = origin + Vector3.new(0, 4, -(R + 120)),
	}
end

Layouts.ById = {
	street = Layouts.street,
	sewers = Layouts.sewers,
	dollhouse = Layouts.dollhouse,
	slasher = Layouts.slasher,
	convent = Layouts.convent,
	hospital = Layouts.hospital,
	carnival = Layouts.carnival,
}

return Layouts
