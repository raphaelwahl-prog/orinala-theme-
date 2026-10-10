--!strict
--[[
	DEAD TIRED — Configuration centrale.

	TOUS les nombres qui se règlent sont dans ce fichier. Si tu veux changer
	l'équilibrage du jeu, tu ne touches qu'ici : aucun autre script ne contient
	de valeur en dur.

	Le coeur du jeu : plus la planque est dangereuse, plus elle paie, mais
	plus souvent le monstre te trouve. Voir docs/DESIGN.md pour le calcul
	d'espérance de gain qui justifie ces chiffres.
]]

local GameConfig = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- CYCLE DE JEU
-- ─────────────────────────────────────────────────────────────────────────────
GameConfig.Round = {
	-- Durée d'une nuit, en secondes.
	NightDuration = 180,
	-- Pause entre deux nuits (dépôt automatique, achats, respawn).
	DawnDuration = 25,
	-- Intervalle entre deux tirages de risque pour un joueur endormi.
	RiskTickInterval = 6,
	-- Délai entre l'alerte ("un bruit dans le couloir") et l'arrivée du monstre.
	-- C'est la fenêtre de fuite : c'est ce qui rend le jeu skill et pas loterie.
	WarningLead = 4.5,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- ÉCONOMIE
-- ─────────────────────────────────────────────────────────────────────────────
GameConfig.Economy = {
	StartingCash = 0,
	-- Part de l'argent NON déposé perdue quand on est attrapé. 1.0 = tout.
	UnbankedLossOnCatch = 1.0,
	-- Part de l'argent non déposé conservée si on est réanimé par un coéquipier.
	-- (On applique la perte au moment de la capture ; ceci rend une partie.)
	UnbankedRecoveredOnRevive = 0.5,
	-- L'argent déposé au coffre ne se perd jamais.
	BankFeePercent = 0,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- LES PLANQUES — le coeur du jeu
-- Rate         = $ par seconde de sommeil
-- DetectChance = probabilité, à CHAQUE tick de risque, que le monstre te repère
-- UnlockTotal  = total déposé (cumulé, persistant) nécessaire pour y dormir
-- ─────────────────────────────────────────────────────────────────────────────
GameConfig.Tiers = {
	[1] = {
		Name = "Dortoir",
		RiskLabel = "Aucun risque",
		Rate = 1,
		DetectChance = 0.00,
		UnlockTotal = 0,
		Color = Color3.fromRGB(104, 190, 132),
	},
	[2] = {
		Name = "Couloir de service",
		RiskLabel = "Faible",
		Rate = 3,
		DetectChance = 0.015,
		UnlockTotal = 0,
		Color = Color3.fromRGB(196, 202, 108),
	},
	[3] = {
		Name = "Cave",
		RiskLabel = "Élevé",
		Rate = 8,
		DetectChance = 0.045,
		UnlockTotal = 2500,
		Color = Color3.fromRGB(216, 150, 84),
	},
	[4] = {
		Name = "Chambre froide",
		RiskLabel = "Très élevé",
		Rate = 18,
		DetectChance = 0.10,
		UnlockTotal = 12000,
		Color = Color3.fromRGB(214, 98, 84),
	},
	[5] = {
		Name = "Le Nid",
		RiskLabel = "Suicidaire",
		Rate = 45,
		DetectChance = 0.22,
		UnlockTotal = 40000,
		Color = Color3.fromRGB(168, 70, 180),
	},
}

GameConfig.MaxTier = 5

-- ─────────────────────────────────────────────────────────────────────────────
-- ÊTRE À TERRE / RÉANIMATION (le levier coop)
-- ─────────────────────────────────────────────────────────────────────────────
GameConfig.Downed = {
	-- Temps avant la mort définitive si personne ne vient.
	BleedoutSeconds = 45,
	-- Temps de maintien de la touche pour relever quelqu'un.
	ReviveHoldSeconds = 6,
	-- Distance maximale pour pouvoir relever.
	ReviveRange = 9,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- LE MONSTRE
-- ─────────────────────────────────────────────────────────────────────────────
GameConfig.Threat = {
	-- Vitesse de déplacement en chasse (studs/s). Un joueur court à 16 par défaut.
	HuntSpeed = 13.5,
	-- Vitesse en patrouille, quand il n'a repéré personne.
	PatrolSpeed = 7,
	-- Distance à laquelle il attrape.
	CatchRadius = 5.5,
	-- Temps au bout duquel il abandonne une chasse et repart en patrouille.
	HuntTimeout = 26,
	-- Il voit aussi les joueurs réveillés qui passent trop près pendant une chasse.
	OpportunisticSightRange = 22,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- PROGRESSION — paliers d'ouverture, basés sur le total déposé à vie
-- ─────────────────────────────────────────────────────────────────────────────
GameConfig.Progression = {
	Milestones = {
		{ Total = 2500, Message = "Cave débloquée." },
		{ Total = 12000, Message = "Chambre froide débloquée." },
		{ Total = 40000, Message = "Le Nid est ouvert. Bonne chance." },
	},
}

-- ─────────────────────────────────────────────────────────────────────────────
-- DIVERS
-- ─────────────────────────────────────────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────────────────────
-- CARTE
-- ─────────────────────────────────────────────────────────────────────────────
GameConfig.Map = {
	-- true  : le serveur génère une carte jouable au démarrage (5 salles, coffre,
	--         boutique, monstre, points de patrouille). Parfait pour tester tout
	--         de suite sans rien modéliser.
	-- false : tu utilises ta propre carte. Il faut alors taguer tes parts
	--         toi-même (SleepSpot + attribut Tier, BankTerminal, ShopTerminal,
	--         PatrolPoint, Monster). Voir docs/SETUP.md.
	UseGeneratedMap = true,
	-- Supprime le Baseplate par défaut de Studio pour éviter deux sols superposés.
	RemoveBaseplate = true,
}

GameConfig.Misc = {
	-- Vitesse de marche normale / avec les baskets du magasin.
	BaseWalkSpeed = 16,
	-- Intervalle d'autosauvegarde (secondes).
	AutosaveInterval = 120,
	-- Version du format de sauvegarde. À incrémenter si tu changes la structure
	-- des données : les anciennes sauvegardes seront alors réinitialisées.
	-- v2 : ajout des cosmétiques.
	DataVersion = 2,
}

return GameConfig
