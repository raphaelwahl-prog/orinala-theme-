--!strict
-- §5 — un monstre par zone, chacun avec une mécanique différente.
-- Le CDC insiste : « Chaque zone doit introduire une mécanique différente
-- plutôt que simplement augmenter les dégâts et la résistance. » C'est le
-- champ `Rule` qui porte ça ; MonsterService l'applique.

export type Monster = {
	Id: string,
	Name: string,
	Zone: string,
	WalkSpeed: number,
	Damage: number,
	Health: number,          -- pour l'étourdissement, pas pour la mort
	SightRange: number,
	HearRange: number,
	AttackRange: number,
	GiveUpSeconds: number,   -- abandon d'une cible inaccessible
	MaxAlive: number,        -- plafond par serveur, pour les performances
	Height: number,          -- hauteur du corps en studs (sert au gabarit)
	Rule: string,            -- la mécanique propre à la zone
	Tell: string,            -- le signal que le joueur doit apprendre à lire
	Counter: string,
}

local MonsterConfig = {}

MonsterConfig.List = {
	{ Id = "prowler", Name = "LE RÔDEUR", Zone = "street",
		WalkSpeed = 13, Damage = 20, Health = 100, SightRange = 55, HearRange = 32,
		AttackRange = 4.5, GiveUpSeconds = 12, MaxAlive = 3, Height = 6,
		Rule = "none",
		Tell = "Il traîne les pieds. On l'entend avant de le voir.",
		Counter = "Casse la ligne de vue et reste immobile le temps qu'il passe." },

	{ Id = "sewer_thing", Name = "LA CHOSE DES ÉGOUTS", Zone = "sewers",
		WalkSpeed = 17, Damage = 28, Health = 140, SightRange = 34, HearRange = 48,
		AttackRange = 4.5, GiveUpSeconds = 14, MaxAlive = 3, Height = 4.6,
		Rule = "sound",
		Tell = "Elle voit mal et entend tout : c'est le bruit qui l'attire.",
		Counter = "Marche. Courir dans un tunnel, c'est l'appeler." },

	{ Id = "doll", Name = "LA POUPÉE", Zone = "dollhouse",
		WalkSpeed = 22, Damage = 34, Health = 160, SightRange = 60, HearRange = 20,
		AttackRange = 4, GiveUpSeconds = 20, MaxAlive = 2, Height = 4.2,
		Rule = "gaze",
		Tell = "Elle est toujours un peu plus près qu'au dernier regard.",
		Counter = "Garde-la dans ton champ de vision : regardée, elle ne bouge pas." },

	{ Id = "slasher", Name = "LE MASQUE", Zone = "slasher",
		WalkSpeed = 11, Damage = 55, Health = 400, SightRange = 70, HearRange = 40,
		AttackRange = 5, GiveUpSeconds = 45, MaxAlive = 1, Height = 7.2,
		Rule = "relentless",
		Tell = "Il ne court pas. Il ne s'arrête pas non plus.",
		Counter = "Les raccourcis et les pièges. Le combat frontal ne marche pas." },

	{ Id = "demon", Name = "L'ENTITÉ", Zone = "convent",
		WalkSpeed = 16, Damage = 62, Health = 500, SightRange = 65, HearRange = 45,
		AttackRange = 5, GiveUpSeconds = 25, MaxAlive = 2, Height = 9,
		Rule = "disable",
		Tell = "Les alarmes se taisent une par une avant qu'elle entre.",
		Counter = "Prévois une sortie : les défenses ne tiendront pas." },

	{ Id = "mimic_voice", Name = "LE MENTEUR", Zone = "hospital",
		WalkSpeed = 18, Damage = 70, Health = 520, SightRange = 55, HearRange = 55,
		AttackRange = 5, GiveUpSeconds = 25, MaxAlive = 2, Height = 6,
		Rule = "fake_alerts",
		Tell = "Une alerte sur trois est fausse. Celle qui ne l'est pas arrive sans bruit.",
		Counter = "Ne réagis qu'aux alertes confirmées par deux signaux." },

	{ Id = "clown_boss", Name = "LE CLOWN", Zone = "carnival",
		WalkSpeed = 20, Damage = 90, Health = 4000, SightRange = 90, HearRange = 90,
		AttackRange = 7, GiveUpSeconds = 999, MaxAlive = 1, Height = 12,
		Rule = "boss_phases",
		Tell = "Trois phases. Chacune reprend la mécanique d'une zone précédente.",
		Counter = "Tout ce que les six zones t'ont appris, dans l'ordre." },
} :: { Monster }

MonsterConfig.ById = {}
for _, monster in ipairs(MonsterConfig.List) do
	MonsterConfig.ById[monster.Id] = monster
end

-- §5 : les huit états demandés par le cahier des charges.
MonsterConfig.States = {
	PATROL = "patrol",
	INVESTIGATE = "investigate",
	DETECT = "detect",
	CHASE = "chase",
	ATTACK = "attack",
	SEARCH = "search",
	STUNNED = "stunned",
	RETURN = "return",
}

function MonsterConfig.get(id: string): Monster?
	return MonsterConfig.ById[id]
end

return MonsterConfig
