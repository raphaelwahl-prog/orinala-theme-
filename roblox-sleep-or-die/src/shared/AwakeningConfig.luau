--!strict
-- L'ÉVEIL DE LA MAISON — la jauge partagée par tout le serveur.
--
-- Reprise de la première version du jeu, parce que c'est la seule mécanique
-- qui rend le multijoueur autre chose que du solo côte à côte : dormir dans
-- une zone profonde remplit une jauge commune, et quand elle monte, les
-- monstres de TOUT le serveur deviennent plus rapides et voient plus loin.
--
-- La cupidité d'un seul met la partie entière en danger. C'est ce qui fait
-- parler les joueurs entre eux — et c'est ce qui les fait revenir.
--
-- Contrepartie assumée : plus l'éveil est haut, plus les gains montent. Sinon
-- personne n'aurait de raison de dormir profond, et la jauge ne bougerait
-- jamais.

local AwakeningConfig = {}

AwakeningConfig.Thresholds = { 0, 16, 40, 76 }

AwakeningConfig.Stages = {
	{
		Name = "CALME", Color = Color3.fromRGB(110, 226, 150),
		Speed = 1.0, Sight = 1.0, Reward = 1.0,
		FogEnd = 320, FogColor = Color3.fromRGB(8, 8, 13),
		Text = "La maison dort. Pour l'instant.",
	},
	{
		Name = "AGITÉ", Color = Color3.fromRGB(255, 196, 92),
		Speed = 1.08, Sight = 1.25, Reward = 1.15,
		FogEnd = 240, FogColor = Color3.fromRGB(14, 8, 10),
		Text = "Quelque chose s'est réveillé. Les gains montent de 15 %.",
	},
	{
		Name = "ÉVEILLÉ", Color = Color3.fromRGB(255, 86, 72),
		Speed = 1.16, Sight = 1.6, Reward = 1.35,
		FogEnd = 170, FogColor = Color3.fromRGB(22, 6, 8),
		Text = "Ils sont tous debout. +35 % de gains, et ils voient loin.",
	},
	{
		Name = "AFFAMÉ", Color = Color3.fromRGB(190, 130, 255),
		Speed = 1.24, Sight = 2.0, Reward = 1.6,
		FogEnd = 110, FogColor = Color3.fromRGB(34, 4, 6),
		Text = "La maison a faim. +60 % — si quelqu'un tient jusqu'au matin.",
	},
}

-- Points gagnés par seconde de sommeil, selon l'ordre de la zone.
-- Zone 1 ne remplit rien : dormir dans la rue est sans danger, donc sans
-- conséquence pour les autres.
function AwakeningConfig.gainFor(zoneOrder: number): number
	return math.max(0, zoneOrder - 1) * 0.09
end

-- La jauge redescend quand personne ne dort profond.
AwakeningConfig.DecayPerSecond = 0.22

function AwakeningConfig.stageFor(points: number): number
	local stage = 1
	for index, threshold in ipairs(AwakeningConfig.Thresholds) do
		if points >= threshold then
			stage = index
		end
	end
	return stage
end

function AwakeningConfig.stageData(stage: number)
	return AwakeningConfig.Stages[math.clamp(stage, 1, #AwakeningConfig.Stages)]
end

function AwakeningConfig.nextThreshold(stage: number): number?
	return AwakeningConfig.Thresholds[stage + 1]
end

return AwakeningConfig
