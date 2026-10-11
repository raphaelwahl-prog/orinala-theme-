--[[
	EntityBuilder — construit le corps des créatures.

	Ce qui fait peur dans un jeu Roblox sombre, ce n'est pas le détail du
	modèle : c'est la SILHOUETTE et les YEUX. On ne voit presque jamais le
	corps. Chaque créature est donc construite sur trois principes :

	  1. Le corps est presque noir. Seuls les yeux émettent de la lumière.
	     On lit une forme qui bouge, pas un personnage.
	  2. Les proportions sont fausses exprès — tête trop petite, bras trop
	     longs, jambes trop fines. Le cerveau voit « humain », puis « non ».
	  3. La démarche est désarticulée (balancement calculé par ThreatService),
	     et pas une animation propre.

	⚠️  NOTE TECHNIQUE IMPORTANTE
	Toutes les parties sont `Anchored` : les créatures ne sont pas gérées par
	le moteur physique, on les déplace à la main. Du coup un `WeldConstraint`
	ne sert à RIEN ici — une soudure ne déplace pas une partie ancrée. C'est
	pour ça que chaque partie garde son décalage par rapport au torse
	(fonction `offsets`) et que ThreatService repositionne tout chaque frame.
	Si tu soudes des parties en pensant qu'elles suivront, elles resteront
	plantées sur place.

	Tu veux un vrai modèle à la place ? Mets-le dans
	`ServerStorage/Entities/<Id>` (watchman, crawler, mimic, starved) et il sera
	utilisé automatiquement. Il lui faut juste un PrimaryPart. Rien d'autre
	à changer dans le code.
]]

local ServerStorage = game:GetService("ServerStorage")

local EntityBuilder = {}

local function limb(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = false
	part.Massless = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

--[[ Les yeux : la seule source de lumière du corps, et donc tout l'effet. ]]
local function addEyes(def, head: BasePart, model: Model)
	if def.EyeCount <= 0 then
		-- La Rampante n'a pas d'yeux du tout. Une bouche à la place : une fente
		-- claire, juste assez visible pour qu'on sache où est sa tête.
		local mouth = limb("Mouth", Vector3.new(1.5, 0.3, 0.2), Color3.fromRGB(230, 60, 70), model)
		mouth.Material = Enum.Material.Neon
		mouth.CFrame = head.CFrame * CFrame.new(0, -0.35, -head.Size.Z / 2 - 0.1)
		return
	end

	for index = 1, def.EyeCount do
		-- Un oeil : centré. Deux : symétriques. Plus : une couronne autour du crâne.
		local offsetX, offsetY
		if def.EyeCount == 1 then
			offsetX, offsetY = 0, 0.1
		elseif def.EyeCount == 2 then
			offsetX = (index == 1) and -0.42 or 0.42
			offsetY = 0.1
		else
			local angle = (index - 1) / def.EyeCount * math.pi * 2
			offsetX = math.cos(angle) * 0.5
			offsetY = math.sin(angle) * 0.4
		end

		local eye = limb("Eye" .. index, Vector3.new(0.34, 0.16, 0.18), def.EyeColor, model)
		eye.Material = Enum.Material.Neon
		eye.CFrame = head.CFrame * CFrame.new(offsetX, offsetY, -head.Size.Z / 2 - 0.08)
	end

	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Brightness = 1.2
	glow.Range = 18
	glow.Color = def.EyeColor
	glow.Parent = head
end

--[[ Construit la créature à partir de sa définition. ]]
function EntityBuilder.build(def): Model
	-- Un vrai modèle fourni par toi gagne toujours.
	local folder = ServerStorage:FindFirstChild("Entities")
	local override = folder and folder:FindFirstChild(def.Id)
	if override and override:IsA("Model") then
		local clone = override:Clone()
		clone.Name = def.Id
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart")
		end
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.Massless = true
			end
		end
		return clone
	end

	local model = Instance.new("Model")
	model.Name = def.Id

	local height = def.Height
	local crawling = height < 4.5

	-- Torse : étroit et haut. C'est le PrimaryPart, donc la référence de tous
	-- les déplacements et de tous les décalages.
	local torsoHeight = crawling and height * 0.5 or height * 0.46
	local torso = limb("Torso", Vector3.new(height * 0.26, torsoHeight, height * 0.17), def.BodyColor, model)
	torso.CFrame = CFrame.new(0, height * 0.55, 0)
	model.PrimaryPart = torso

	-- Tête : volontairement petite par rapport au corps.
	local headSize = height * 0.15
	local head = limb("Head", Vector3.new(headSize, headSize * 1.15, headSize),
		def.BodyColor:Lerp(Color3.new(0, 0, 0), 0.3), model)
	if crawling then
		-- La Rampante avance tête en avant, pas tête en haut.
		head.CFrame = torso.CFrame
			* CFrame.new(0, torsoHeight * 0.1, -torsoHeight * 0.75)
			* CFrame.Angles(math.rad(-25), 0, 0)
	else
		head.CFrame = torso.CFrame * CFrame.new(0, torsoHeight / 2 + headSize * 0.7, -0.15)
	end
	addEyes(def, head, model)

	-- Bras : trop longs. C'est le détail qui met mal à l'aise.
	for _, side in ipairs({ -1, 1 }) do
		local arm = limb(side < 0 and "LeftArm" or "RightArm",
			Vector3.new(height * 0.055, def.ArmLength, height * 0.055), def.BodyColor, model)
		arm.CFrame = torso.CFrame
			* CFrame.new(side * (torso.Size.X / 2 + arm.Size.X), torsoHeight / 2 - def.ArmLength / 2, 0)
	end

	-- Jambes.
	local legLength = height * 0.5
	for _, side in ipairs({ -1, 1 }) do
		local leg = limb(side < 0 and "LeftLeg" or "RightLeg",
			Vector3.new(height * 0.06, legLength, height * 0.06), def.BodyColor, model)
		leg.CFrame = torso.CFrame * CFrame.new(side * torso.Size.X * 0.26, -torsoHeight / 2 - legLength / 2, 0)
	end

	-- La lanterne du Veilleur : elle le trahit de loin, et c'est voulu.
	-- Une créature qu'on voit arriver fait plus peur qu'une qui surgit.
	if def.CarriesLantern then
		local lantern = limb("Lantern", Vector3.new(0.6, 0.8, 0.6), Color3.fromRGB(255, 200, 120), model)
		lantern.Material = Enum.Material.Neon
		lantern.CFrame = torso.CFrame * CFrame.new(torso.Size.X / 2 + 0.6, torsoHeight / 2 - def.ArmLength, 0)

		local light = Instance.new("PointLight")
		light.Name = "LanternLight"
		light.Brightness = 2.2
		light.Range = 34
		light.Color = Color3.fromRGB(255, 196, 120)
		light.Parent = lantern
	end

	-- Le déguisement du Mime : au repos, c'est un lit de plus dans la salle.
	if def.Teleports then
		local disguise = limb("Disguise", Vector3.new(7, 1.6, 12), Color3.fromRGB(90, 80, 92), model)
		disguise.Material = Enum.Material.Fabric
		disguise.CFrame = torso.CFrame * CFrame.new(0, -height * 0.55 + 0.8, 0)
	end

	-- Sons. Les IDs sont vides par défaut : voir docs/SOUND.md.
	local function sound(name: string, id: string, volume: number, looped: boolean)
		if id == "" then
			return
		end
		local instance = Instance.new("Sound")
		instance.Name = name
		instance.SoundId = id
		instance.Volume = volume
		instance.Looped = looped
		instance.RollOffMode = Enum.RollOffMode.InverseTapered
		instance.RollOffMaxDistance = 140
		instance.RollOffMinDistance = 8
		instance.Parent = torso
		if looped then
			instance:Play()
		end
	end
	sound("Step", def.StepSoundId, 0.6, false)
	sound("Voice", def.VoiceSoundId, 0.8, true)

	return model
end

--[[ Décalage de chaque partie par rapport au torse, mesuré une fois à la
	 construction. ThreatService s'en sert pour repositionner tout le corps
	 quand la créature avance (voir la note technique en haut du fichier). ]]
function EntityBuilder.offsets(model: Model)
	local torso = model.PrimaryPart
	if not torso then
		return {}
	end
	local list = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= torso then
			local offset = torso.CFrame:ToObjectSpace(descendant.CFrame)
			table.insert(list, {
				Part = descendant,
				Offset = offset,
				-- Décalage d'origine, jamais modifié : ThreatService.rescale en
				-- repart à chaque stade d'éveil pour ne pas cumuler l'erreur.
				BaseOffset = offset,
				-- Les membres se balancent, le reste suit rigidement.
				Swing = (descendant.Name == "LeftArm" and 1)
					or (descendant.Name == "RightArm" and -1)
					or (descendant.Name == "LeftLeg" and -1)
					or (descendant.Name == "RightLeg" and 1)
					or 0,
			})
		end
	end
	return list
end

return EntityBuilder
