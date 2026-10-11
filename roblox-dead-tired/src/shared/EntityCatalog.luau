--!strict
--[[
	EntityCatalog — les créatures.

	Le principe : **ce n'est pas le même monstre selon l'endroit où tu dors.**
	Chaque palier de planque a sa créature, avec son comportement, sa
	silhouette et sa contre-mesure. Le joueur n'apprend donc pas « le monstre »,
	il apprend cinq monstres, et c'est ça qui fait durer le jeu.

	Et par-dessus ça, un niveau d'ÉVEIL partagé par le serveur : plus les
	joueurs dorment profond, plus les créatures montent en stade (plus rapides,
	plus grandes, elles voient plus loin). Dormir dans Le Nid ne met donc pas
	seulement TA vie en jeu : ça réveille la maison pour tout le monde.

	Comportements implémentés par ThreatService :
	  LosesTrack  — perd ta trace si tu casses la ligne de vue assez longtemps
	  Blind       — ne te suit que si tu BOUGES. S'arrêter net la rend aveugle.
	  Teleports   — se rapproche par sauts quand personne ne la regarde
	  Relentless  — ne lâche jamais, ignore la ligne de vue
]]

export type EntityDef = {
	Id: string,
	Name: string,
	Tagline: string,
	Counter: string,
	Tier: number,
	BaseSpeed: number,
	CatchRadius: number,
	SightRange: number,
	HuntTimeout: number,
	Height: number,
	BodyColor: Color3,
	EyeColor: Color3,
	EyeCount: number,
	ArmLength: number,
	-- comportements
	LosesTrack: number?,
	Blind: number?,
	Teleports: number?,
	Relentless: boolean?,
	-- ambiance
	FlickerRange: number,
	CarriesLantern: boolean?,
	-- sons : colle des IDs Roblox ici, "" = silencieux (voir docs/SOUND.md)
	StepSoundId: string,
	VoiceSoundId: string,
}

local EntityCatalog = {}

EntityCatalog.Entities = {
	-- Palier 1 : personne ne vient. Le dortoir est vraiment sûr.

	[2] = {
		Id = "watchman",
		Name = "LE VEILLEUR",
		Tagline = "Il fait sa ronde. Il n'est pas pressé.",
		Counter = "Casse sa ligne de vue trois secondes et il te perd.",
		Tier = 2,
		BaseSpeed = 11,
		CatchRadius = 5.5,
		SightRange = 42,
		HuntTimeout = 24,
		Height = 7.5,
		BodyColor = Color3.fromRGB(38, 36, 34),
		EyeColor = Color3.fromRGB(255, 196, 92),
		EyeCount = 1,
		ArmLength = 3.2,
		LosesTrack = 3,
		FlickerRange = 24,
		CarriesLantern = true,
		StepSoundId = "",
		VoiceSoundId = "",
	},

	[3] = {
		Id = "crawler",
		Name = "LA RAMPANTE",
		Tagline = "Elle n'a pas d'yeux. Elle n'en a pas besoin.",
		Counter = "Elle ne suit que le mouvement. Arrête-toi net et deviens invisible.",
		Tier = 3,
		BaseSpeed = 18,
		CatchRadius = 5,
		SightRange = 30,
		HuntTimeout = 30,
		Height = 3.6,
		BodyColor = Color3.fromRGB(196, 186, 170),
		EyeColor = Color3.fromRGB(255, 255, 255),
		EyeCount = 0,
		ArmLength = 4.6,
		Blind = 1.1,
		FlickerRange = 18,
		StepSoundId = "",
		VoiceSoundId = "",
	},

	[4] = {
		Id = "mimic",
		Name = "LE MIME",
		Tagline = "Il y avait un lit de plus que la veille.",
		Counter = "Garde-le dans ton champ de vision : regardé, il ne peut pas sauter.",
		Tier = 4,
		BaseSpeed = 13,
		CatchRadius = 6,
		SightRange = 38,
		HuntTimeout = 34,
		Height = 6.2,
		BodyColor = Color3.fromRGB(74, 48, 52),
		EyeColor = Color3.fromRGB(120, 255, 180),
		EyeCount = 2,
		ArmLength = 3.8,
		Teleports = 6,
		FlickerRange = 22,
		StepSoundId = "",
		VoiceSoundId = "",
	},

	[5] = {
		Id = "starved",
		Name = "L'AFFAMÉ",
		Tagline = "Tu dors dans sa chambre.",
		Counter = "Aucune. Cours, et compte tes secondes.",
		Tier = 5,
		BaseSpeed = 15,
		CatchRadius = 6.5,
		SightRange = 70,
		HuntTimeout = 999,
		Height = 11,
		BodyColor = Color3.fromRGB(22, 18, 20),
		EyeColor = Color3.fromRGB(255, 42, 36),
		EyeCount = 6,
		ArmLength = 6.5,
		Relentless = true,
		FlickerRange = 34,
		StepSoundId = "",
		VoiceSoundId = "",
	},
} :: { [number]: EntityDef }

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉVEIL — l'évolution partagée
-- ─────────────────────────────────────────────────────────────────────────────
--[[
	Le compteur monte quand quelqu'un dort profond : chaque tirage de risque
	ajoute (palier − 1) points. Dormir dans Le Nid remplit donc la jauge quatre
	fois plus vite que le couloir de service.

	Il redescend à zéro à l'aube. C'est une pression qui monte DANS la nuit.
]]
EntityCatalog.Awakening = {
	-- Points nécessaires pour entrer dans chaque stade.
	Thresholds = { 0, 14, 34, 64 },
	Stages = {
		[1] = {
			Name = "CALME",
			SpeedMultiplier = 1.0,
			SightMultiplier = 1.0,
			CatchBonus = 0,
			ScaleMultiplier = 1.0,
			FogEnd = 110,
			FogColor = Color3.fromRGB(10, 10, 16),
		},
		[2] = {
			Name = "AGITÉ",
			SpeedMultiplier = 1.08,
			SightMultiplier = 1.25,
			CatchBonus = 0.5,
			ScaleMultiplier = 1.06,
			FogEnd = 90,
			FogColor = Color3.fromRGB(14, 8, 10),
		},
		[3] = {
			Name = "ÉVEILLÉ",
			SpeedMultiplier = 1.16,
			SightMultiplier = 1.6,
			CatchBonus = 1,
			ScaleMultiplier = 1.14,
			FogEnd = 68,
			FogColor = Color3.fromRGB(22, 6, 8),
		},
		[4] = {
			Name = "AFFAMÉ",
			SpeedMultiplier = 1.24,
			SightMultiplier = 2.0,
			CatchBonus = 1.5,
			ScaleMultiplier = 1.24,
			FogEnd = 52,
			FogColor = Color3.fromRGB(34, 4, 6),
			-- À ce stade, L'AFFAMÉ sort même si personne ne dort au palier 5.
			ReleasesApex = true,
		},
	},
}

EntityCatalog.MaxStage = 4

--[[ Points gagnés par tirage de risque pour un palier donné. ]]
function EntityCatalog.awakeningGain(tier: number): number
	return math.max(0, tier - 1)
end

--[[ Stade (1 à 4) correspondant à un total de points. ]]
function EntityCatalog.stageFor(points: number): number
	local stage = 1
	for index, threshold in ipairs(EntityCatalog.Awakening.Thresholds) do
		if points >= threshold then
			stage = index
		end
	end
	return math.min(stage, EntityCatalog.MaxStage)
end

function EntityCatalog.stageData(stage: number)
	return EntityCatalog.Awakening.Stages[math.clamp(stage, 1, EntityCatalog.MaxStage)]
end

--[[ La créature attachée à un palier. nil pour le palier 1. ]]
function EntityCatalog.forTier(tier: number): EntityDef?
	return EntityCatalog.Entities[tier]
end

--[[ Stats effectives d'une créature à un stade d'éveil donné. ]]
function EntityCatalog.resolve(def: EntityDef, stage: number)
	local scaling = EntityCatalog.stageData(stage)
	return {
		Speed = def.BaseSpeed * scaling.SpeedMultiplier,
		SightRange = def.SightRange * scaling.SightMultiplier,
		CatchRadius = def.CatchRadius + scaling.CatchBonus,
		Scale = scaling.ScaleMultiplier,
		HuntTimeout = def.HuntTimeout,
	}
end

return EntityCatalog
