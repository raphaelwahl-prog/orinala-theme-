--!strict
-- Tout ce qui touche à Lighting vit ici, et nulle part ailleurs.
--
-- Roblox sans Atmosphere ni post-traitement a l'air d'un jeu de 2015 : des
-- aplats de couleur sous une lumière plate. Avec, et sans un seul fichier à
-- téléverser, on gagne la profondeur, le halo des lampes et le grain d'un
-- jeu d'horreur récent.
--
-- Deux sources changent l'image, et elles se combinent :
--   · la ZONE où est le joueur (étalonnage de couleur propre à chaque lieu) ;
--   · l'ÉVEIL de la maison (le brouillard se resserre, l'image vire au rouge).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local AtmosphereService = {}

type Grade = {
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	Brightness: number,
	Haze: number,
	FogColor: Color3,
}

-- Une identité visuelle par zone. C'est ce qui fait qu'on sait où on est les
-- yeux fermés à moitié, avant même de lire le HUD.
local GRADES: { [string]: Grade } = {
	street = { Tint = Color3.fromRGB(226, 232, 255), Saturation = -0.08, Contrast = 0.08,
		Brightness = -0.02, Haze = 1.6, FogColor = Color3.fromRGB(8, 8, 13) },
	sewers = { Tint = Color3.fromRGB(214, 255, 220), Saturation = -0.22, Contrast = 0.16,
		Brightness = -0.06, Haze = 3.2, FogColor = Color3.fromRGB(10, 16, 12) },
	dollhouse = { Tint = Color3.fromRGB(255, 232, 206), Saturation = 0.06, Contrast = 0.2,
		Brightness = 0, Haze = 1.2, FogColor = Color3.fromRGB(18, 12, 10) },
	slasher = { Tint = Color3.fromRGB(226, 226, 232), Saturation = -0.34, Contrast = 0.1,
		Brightness = -0.04, Haze = 4.5, FogColor = Color3.fromRGB(16, 16, 18) },
	convent = { Tint = Color3.fromRGB(206, 218, 255), Saturation = -0.1, Contrast = 0.24,
		Brightness = -0.05, Haze = 2.2, FogColor = Color3.fromRGB(10, 10, 20) },
	hospital = { Tint = Color3.fromRGB(216, 248, 244), Saturation = -0.18, Contrast = 0.18,
		Brightness = -0.03, Haze = 2.0, FogColor = Color3.fromRGB(10, 18, 18) },
	carnival = { Tint = Color3.fromRGB(255, 212, 236), Saturation = 0.18, Contrast = 0.22,
		Brightness = -0.02, Haze = 2.6, FogColor = Color3.fromRGB(22, 6, 14) },
}

local atmosphere: Atmosphere
local bloom: BloomEffect
local color: ColorCorrectionEffect
local blur: DepthOfFieldEffect

local current = GRADES.street
local target = GRADES.street
local fogTarget, fogColorTarget = 320, GRADES.street.FogColor
local awakeningTint = Color3.new(1, 1, 1)

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing :: any
	end
	local instance = Instance.new(className :: any)
	instance.Name = name
	instance.Parent = Lighting
	return instance :: any
end

function AtmosphereService.init()
	-- `Lighting.Technology` n'est PAS assignable depuis un script : l'affecter
	-- ici lèverait une erreur et tout le reste de cette fonction ne tournerait
	-- jamais. Elle est donc fixée dans le fichier de place et dans le projet
	-- Rojo (valeur Future), pas ici.
	Lighting.ClockTime = 0.4
	Lighting.Brightness = 1
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(14, 14, 20)
	Lighting.OutdoorAmbient = Color3.fromRGB(20, 20, 30)
	Lighting.FogStart = 30
	Lighting.FogEnd = 320

	atmosphere = ensure("Atmosphere", "Air")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(28, 30, 40)
	atmosphere.Decay = Color3.fromRGB(70, 74, 96)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6

	bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.65
	bloom.Size = 22
	bloom.Threshold = 1.1

	color = ensure("ColorCorrectionEffect", "Grade")
	color.Brightness = 0
	color.Contrast = 0.08
	color.Saturation = -0.08
	color.TintColor = GRADES.street.Tint

	blur = ensure("DepthOfFieldEffect", "Depth")
	blur.FarIntensity = 0.12
	blur.NearIntensity = 0
	blur.FocusDistance = 24
	blur.InFocusRadius = 42

	-- Transition douce : un changement de zone ne doit pas claquer d'un coup.
	RunService.Heartbeat:Connect(function(dt)
		local k = math.min(1, dt * 1.6)
		current = {
			Tint = current.Tint:Lerp(target.Tint, k),
			Saturation = current.Saturation + (target.Saturation - current.Saturation) * k,
			Contrast = current.Contrast + (target.Contrast - current.Contrast) * k,
			Brightness = current.Brightness + (target.Brightness - current.Brightness) * k,
			Haze = current.Haze + (target.Haze - current.Haze) * k,
			FogColor = current.FogColor:Lerp(target.FogColor, k),
		}
		color.TintColor = current.Tint:Lerp(awakeningTint, 0.45)
		color.Saturation = current.Saturation
		color.Contrast = current.Contrast
		color.Brightness = current.Brightness
		atmosphere.Haze = current.Haze
		Lighting.FogEnd += (fogTarget - Lighting.FogEnd) * k
		Lighting.FogStart = math.min(30, Lighting.FogEnd * 0.12)
		Lighting.FogColor = Lighting.FogColor:Lerp(fogColorTarget, k)
	end)
end

-- Appelée quand un joueur change de zone. Avec plusieurs joueurs dans des
-- zones différentes, c'est le dernier entré qui donne le ton : Lighting est
-- un service global, il n'y a pas d'étalonnage par joueur côté serveur.
function AtmosphereService.setZone(zoneId: string)
	target = GRADES[zoneId] or GRADES.street
	fogColorTarget = target.FogColor
end

-- Appelée par AwakeningService à chaque changement de stade.
function AtmosphereService.setAwakening(stage: number, data)
	fogTarget = data.FogEnd
	fogColorTarget = data.FogColor
	-- Plus la maison est réveillée, plus l'image vire vers sa couleur.
	local strength = (stage - 1) / 3
	awakeningTint = Color3.new(1, 1, 1):Lerp(data.Color, strength * 0.35)
	bloom.Intensity = 0.65 + strength * 0.5
	blur.FarIntensity = 0.12 + strength * 0.2
end

return AtmosphereService
