--!strict
-- Le corps des monstres.
--
-- Avant, un monstre c'était deux boîtes soudées qui glissaient sur le sol.
-- Ici c'est un vrai squelette R6 : HumanoidRootPart, Torso, Head, deux bras,
-- deux jambes, reliés par des Motor6D — exactement la structure d'un
-- personnage Roblox. Deux conséquences :
--
--   · Humanoid:MoveTo() fonctionne normalement (collisions, pentes, pathfinding) ;
--   · on peut animer les membres en faisant tourner les Motor6D, sans aucun
--     fichier d'animation à téléverser.
--
-- Chaque monstre a sa silhouette, et c'est elle qu'on reconnaît de loin avant
-- de voir la couleur : LA RAMPANTE est à quatre pattes, L'AFFAMÉ est étiré,
-- LE MENTEUR porte l'apparence d'un joueur.

local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)

local MonsterRig = {}

-- Proportions R6 d'origine, en studs, pour un monstre de 5 de haut.
local TORSO = Vector3.new(2, 2, 1)
local HEAD = Vector3.new(1.6, 1.6, 1.6)
local LIMB = Vector3.new(1, 2, 1)

export type Look = {
	Body: Color3,
	Skin: Color3,
	Eye: Color3,
	Eyes: number,
	ArmLength: number,
	Crawl: boolean,
	Thin: boolean,
	Hat: Color3?,
	Lantern: boolean,
}

-- Apparence par monstre. Tout est déduit du catalogue sauf ce qui est
-- purement visuel, qui vit ici pour ne pas polluer MonsterConfig.
local LOOKS: { [string]: Look } = {
	prowler = { Body = Color3.fromRGB(42, 38, 36), Skin = Color3.fromRGB(96, 84, 74),
		Eye = Color3.fromRGB(255, 196, 92), Eyes = 2, ArmLength = 2.4,
		Crawl = false, Thin = false, Hat = nil, Lantern = false },
	sewer_thing = { Body = Color3.fromRGB(96, 112, 90), Skin = Color3.fromRGB(120, 134, 108),
		Eye = Color3.fromRGB(230, 60, 70), Eyes = 0, ArmLength = 2.8,
		Crawl = true, Thin = false, Hat = nil, Lantern = false },
	doll = { Body = Color3.fromRGB(226, 210, 214), Skin = Color3.fromRGB(244, 236, 234),
		Eye = Color3.fromRGB(120, 255, 180), Eyes = 2, ArmLength = 2.2,
		Crawl = false, Thin = false, Hat = nil, Lantern = false },
	slasher = { Body = Color3.fromRGB(34, 34, 38), Skin = Color3.fromRGB(220, 220, 222),
		Eye = Color3.fromRGB(255, 70, 60), Eyes = 1, ArmLength = 2.6,
		Crawl = false, Thin = false, Hat = Color3.fromRGB(20, 20, 24), Lantern = false },
	demon = { Body = Color3.fromRGB(58, 30, 38), Skin = Color3.fromRGB(80, 36, 44),
		Eye = Color3.fromRGB(255, 120, 40), Eyes = 4, ArmLength = 3.4,
		Crawl = false, Thin = true, Hat = nil, Lantern = false },
	mimic_voice = { Body = Color3.fromRGB(180, 186, 190), Skin = Color3.fromRGB(226, 214, 190),
		Eye = Color3.fromRGB(140, 255, 220), Eyes = 2, ArmLength = 2.5,
		Crawl = false, Thin = false, Hat = nil, Lantern = true },
	clown_boss = { Body = Color3.fromRGB(190, 40, 70), Skin = Color3.fromRGB(248, 244, 240),
		Eye = Color3.fromRGB(255, 40, 40), Eyes = 6, ArmLength = 4.2,
		Crawl = false, Thin = false, Hat = Color3.fromRGB(230, 60, 100), Lantern = false },
}

function MonsterRig.look(id: string): Look
	return LOOKS[id] or LOOKS.prowler
end

local function part(name: string, size: Vector3, color: Color3, parent: Instance,
	material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

-- Construit le corps. `scale` vient de la hauteur déclarée dans MonsterConfig.
function MonsterRig.build(def: MonsterConfig.Monster, position: Vector3): (Model, any)
	local look = MonsterRig.look(def.Id)
	local s = def.Height / 5
	local model = Instance.new("Model")
	model.Name = def.Id

	local torsoSize = TORSO * s
	if look.Thin then
		torsoSize = Vector3.new(TORSO.X * 0.72, TORSO.Y * 1.25, TORSO.Z * 0.8) * s
	end
	if look.Crawl then
		-- À quatre pattes : le torse est couché, plus long que haut.
		torsoSize = Vector3.new(TORSO.X * 0.95, TORSO.Y * 0.55, TORSO.Z * 2.6) * s
	end

	-- HumanoidRootPart : c'est lui qui porte la collision et que l'Humanoid pilote.
	local root = part("HumanoidRootPart", torsoSize, look.Body, model)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(position + Vector3.new(0, torsoSize.Y / 2 + LIMB.Y * s, 0))

	local torso = part("Torso", torsoSize, look.Body, model, Enum.Material.Fabric)
	local head = part("Head", HEAD * s, look.Skin, model)

	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	local headOffset = look.Crawl
		and CFrame.new(0, 0, -(torsoSize.Z / 2 + HEAD.Z * s / 2))
		or CFrame.new(0, torsoSize.Y / 2 + HEAD.Y * s / 2, 0)
	motor("Neck", torso, head, headOffset, CFrame.new())

	local limbSize = Vector3.new(LIMB.X, look.ArmLength, LIMB.Z) * s
	local legSize = LIMB * s
	if look.Crawl then
		limbSize = Vector3.new(LIMB.X * 0.7, look.ArmLength * 0.85, LIMB.Z * 0.7) * s
		legSize = limbSize
	end

	local joints = {}
	local function limb(name: string, jointName: string, size: Vector3, attach: CFrame)
		local p = part(name, size, look.Body, model, Enum.Material.Fabric)
		-- Le pivot est en haut du membre : une rotation doit partir de
		-- l'épaule ou de la hanche, pas du sol.
		joints[jointName] = motor(jointName, torso, p, attach,
			CFrame.new(0, size.Y / 2, 0))
	end

	if look.Crawl then
		local front = -torsoSize.Z / 2 + limbSize.Z
		local back = torsoSize.Z / 2 - limbSize.Z
		limb("Left Arm", "Left Shoulder", limbSize,
			CFrame.new(-torsoSize.X / 2, -torsoSize.Y / 2, front))
		limb("Right Arm", "Right Shoulder", limbSize,
			CFrame.new(torsoSize.X / 2, -torsoSize.Y / 2, front))
		limb("Left Leg", "Left Hip", legSize,
			CFrame.new(-torsoSize.X / 2, -torsoSize.Y / 2, back))
		limb("Right Leg", "Right Hip", legSize,
			CFrame.new(torsoSize.X / 2, -torsoSize.Y / 2, back))
	else
		limb("Left Arm", "Left Shoulder", limbSize,
			CFrame.new(-(torsoSize.X / 2 + limbSize.X / 2), torsoSize.Y / 2 - limbSize.X / 2, 0))
		limb("Right Arm", "Right Shoulder", limbSize,
			CFrame.new(torsoSize.X / 2 + limbSize.X / 2, torsoSize.Y / 2 - limbSize.X / 2, 0))
		limb("Left Leg", "Left Hip", legSize,
			CFrame.new(-legSize.X / 2, -torsoSize.Y / 2, 0))
		limb("Right Leg", "Right Hip", legSize,
			CFrame.new(legSize.X / 2, -torsoSize.Y / 2, 0))
	end

	-- Yeux : souvent la seule chose qu'on voit d'un monstre dans le noir.
	if look.Eyes > 0 then
		for i = 1, look.Eyes do
			local eye = part("Eye", Vector3.new(0.3, 0.16, 0.1) * s, look.Eye, model,
				Enum.Material.Neon)
			local x, y = 0, 0
			if look.Eyes == 2 then
				x = (i == 1 and -0.38 or 0.38)
			elseif look.Eyes > 2 then
				local a = i / look.Eyes * math.pi * 2
				x, y = math.cos(a) * 0.45, math.sin(a) * 0.35
			end
			motor("EyeJoint" .. i, head, eye,
				CFrame.new(x * s, y * s, -(HEAD.Z * s / 2 + 0.05)), CFrame.new())
		end
		local glow = Instance.new("PointLight")
		glow.Color = look.Eye
		glow.Brightness = 1.4
		glow.Range = 22 * s
		glow.Parent = head
	else
		-- La Rampante n'a pas d'yeux : une bouche claire, cousue en travers.
		local mouth = part("Mouth", Vector3.new(1.1, 0.2, 0.1) * s, look.Eye, model,
			Enum.Material.Neon)
		motor("MouthJoint", head, mouth,
			CFrame.new(0, -0.2 * s, -(HEAD.Z * s / 2 + 0.05)), CFrame.new())
	end

	if look.Hat then
		local hat = part("Hat", Vector3.new(HEAD.X * 1.1, 0.5, HEAD.Z * 1.1) * s,
			look.Hat, model, Enum.Material.Fabric)
		motor("HatJoint", head, hat, CFrame.new(0, HEAD.Y * s / 2 + 0.25 * s, 0), CFrame.new())
	end

	if look.Lantern then
		local lamp = part("Lantern", Vector3.new(0.7, 0.9, 0.7) * s,
			Color3.fromRGB(255, 200, 120), model, Enum.Material.Neon)
		motor("LanternJoint", torso, lamp,
			CFrame.new(torsoSize.X / 2 + 0.6 * s, -0.4 * s, -0.4 * s), CFrame.new())
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 196, 120)
		light.Brightness = 2.4
		light.Range = 46
		light.Parent = lamp
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = def.Health
	humanoid.Health = def.Health
	humanoid.WalkSpeed = def.WalkSpeed
	humanoid.HipHeight = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("MonsterId", def.Id)

	-- On range les Motor6D animables dans un dossier pour ne pas les
	-- rechercher à chaque image.
	local rig = {
		Joints = joints,
		Neck = torso:FindFirstChild("Neck") :: Motor6D,
		Crawl = look.Crawl,
		Base = {},
	}
	for name, joint in pairs(joints) do
		rig.Base[name] = joint.C0
	end
	return model, rig :: any
end

-- Cycle de marche. `phase` avance avec la distance parcourue, `amount` est
-- l'amplitude : 0 à l'arrêt, ~1 en pleine course.
function MonsterRig.animate(rig, phase: number, amount: number)
	if not rig or not rig.Joints then
		return
	end
	local swing = math.sin(phase) * amount
	local function set(name: string, angle: number)
		local joint = rig.Joints[name]
		local base = rig.Base[name]
		if joint and base then
			joint.C0 = base * CFrame.Angles(angle, 0, 0)
		end
	end
	if rig.Crawl then
		-- Quatre pattes : les diagonales vont ensemble.
		set("Left Shoulder", swing)
		set("Right Hip", swing * 0.9)
		set("Right Shoulder", -swing)
		set("Left Hip", -swing * 0.9)
	else
		set("Left Shoulder", swing)
		set("Right Shoulder", -swing)
		set("Left Hip", -swing)
		set("Right Hip", swing)
	end
end

return MonsterRig
