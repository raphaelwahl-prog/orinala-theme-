--!strict
-- §7 — missions principales, secondaires, quotidiennes et hebdomadaires.
-- Les missions principales débloquent les zones (leur compte alimente
-- `MainMissions` dans ZoneConfig.canEnter).

export type Kind = "main" | "side" | "daily" | "weekly"

export type Mission = {
	Id: string,
	Kind: Kind,
	Name: string,
	Zone: string,
	Goal: string,            -- type d'objectif, lu par MissionService
	Target: number,
	Giver: string,           -- PNJ qui la donne
	Reward: { Cash: number, Items: { string }?, Quest: string? },
	Text: string,
}

local MissionConfig = {}

MissionConfig.List = {
	-- Principales : la colonne vertébrale, une par palier de zone.
	{ Id = "m1_first_night", Kind = "main", Name = "Ta première nuit", Zone = "street",
		Goal = "survive_session", Target = 1, Giver = "guide",
		Reward = { Cash = 2000 },
		Text = "Réserve un refuge, barricade-le et tiens une session complète." },
	{ Id = "m2_supplies", Kind = "main", Name = "Des provisions", Zone = "street",
		Goal = "collect", Target = 5, Giver = "merchant",
		Reward = { Cash = 6000 },
		Text = "Ramasse cinq caisses de ressources dans la rue." },
	{ Id = "m3_three_nights", Kind = "main", Name = "Trois nuits d'affilée", Zone = "sewers",
		Goal = "survive_session", Target = 3, Giver = "guide",
		Reward = { Cash = 60000 },
		Text = "Survis trois sessions complètes sans mourir une seule fois." },
	{ Id = "m4_chase", Kind = "main", Name = "La poursuite", Zone = "dollhouse",
		Goal = "escape_chase", Target = 1, Giver = "researcher",
		Reward = { Cash = 400000, Quest = "chase" },
		Text = "Attire la poupée hors de la maison et sème-la." },
	{ Id = "m5_vigil", Kind = "main", Name = "La veillée", Zone = "slasher",
		Goal = "survive_session", Target = 5, Giver = "mechanic",
		Reward = { Cash = 1500000, Quest = "vigil" },
		Text = "Tiens cinq sessions dans le quartier sans perdre un refuge." },
	{ Id = "m6_extreme", Kind = "main", Name = "Nuit extrême", Zone = "convent",
		Goal = "survive_extreme", Target = 1, Giver = "informant",
		Reward = { Cash = 6000000, Quest = "extreme_night" },
		Text = "Une session entière au couvent, sans aucune défense posée." },
	{ Id = "m7_secret", Kind = "main", Name = "La porte derrière l'hôpital", Zone = "hospital",
		Goal = "find_secret", Target = 1, Giver = "researcher",
		Reward = { Cash = 25000000, Quest = "secret" },
		Text = "Trouve l'entrée du carnaval. Elle n'est pas sur la carte." },

	-- Secondaires : argent, ressources, cosmétiques.
	{ Id = "s_lost_item", Kind = "side", Name = "Un objet perdu", Zone = "street",
		Goal = "collect", Target = 1, Giver = "survivor",
		Reward = { Cash = 1500 },
		Text = "Quelqu'un a laissé tomber quelque chose près du métro." },
	{ Id = "s_parcel", Kind = "side", Name = "Livrer un colis", Zone = "street",
		Goal = "deliver", Target = 1, Giver = "merchant",
		Reward = { Cash = 2500 },
		Text = "Porte ce paquet au mécanicien. Sans traîner." },
	{ Id = "s_generator", Kind = "side", Name = "Réparer le générateur", Zone = "sewers",
		Goal = "repair", Target = 3, Giver = "mechanic",
		Reward = { Cash = 25000 },
		Text = "Trois pièces à remettre en place pendant que ça rôde." },
	{ Id = "s_rescue", Kind = "side", Name = "Aider un survivant", Zone = "sewers",
		Goal = "rescue", Target = 1, Giver = "survivor",
		Reward = { Cash = 40000 },
		Text = "Il est coincé. Il ne tiendra pas la nuit tout seul." },

	-- Quotidiennes : petites récompenses, remises à zéro chaque jour.
	{ Id = "d_survive", Kind = "daily", Name = "Dormir une fois", Zone = "street",
		Goal = "survive_session", Target = 1, Giver = "guide",
		Reward = { Cash = 3000 },
		Text = "Une session complète, n'importe où." },
	{ Id = "d_repel", Kind = "daily", Name = "Repousser un monstre", Zone = "street",
		Goal = "repel", Target = 2, Giver = "mechanic",
		Reward = { Cash = 5000 },
		Text = "Étourdis deux monstres." },
	{ Id = "d_bank", Kind = "daily", Name = "Mettre à l'abri", Zone = "street",
		Goal = "bank", Target = 1, Giver = "merchant",
		Reward = { Cash = 2000 },
		Text = "Dépose au moins une fois ce que tu as gagné." },

	-- Hebdomadaires : gros bonus.
	{ Id = "w_marathon", Kind = "weekly", Name = "La semaine longue", Zone = "street",
		Goal = "survive_session", Target = 15, Giver = "guide",
		Reward = { Cash = 120000 },
		Text = "Quinze sessions complètes dans la semaine." },
	{ Id = "w_hunter", Kind = "weekly", Name = "Chasseur", Zone = "sewers",
		Goal = "repel", Target = 25, Giver = "researcher",
		Reward = { Cash = 250000 },
		Text = "Vingt-cinq monstres repoussés." },
} :: { Mission }

MissionConfig.ById = {}
for _, mission in ipairs(MissionConfig.List) do
	MissionConfig.ById[mission.Id] = mission
end

MissionConfig.Npcs = {
	{ Id = "guide", Name = "Le Guide", Role = "Explique les règles et suit ta progression." },
	{ Id = "merchant", Name = "Le Marchand", Role = "Vend les équipements, reprend les ressources." },
	{ Id = "mechanic", Name = "Le Mécanicien", Role = "Répare et améliore les refuges." },
	{ Id = "informant", Name = "L'Informateur", Role = "Vend des renseignements sur les zones." },
	{ Id = "survivor", Name = "Les Survivants", Role = "Donnent des missions d'entraide." },
	{ Id = "researcher", Name = "Le Chercheur", Role = "Étudie les monstres. Paie pour des observations." },
}

function MissionConfig.get(id: string): Mission?
	return MissionConfig.ById[id]
end

function MissionConfig.ofKind(kind: Kind): { Mission }
	local out = {}
	for _, mission in ipairs(MissionConfig.List) do
		if mission.Kind == kind then
			table.insert(out, mission)
		end
	end
	return out
end

return MissionConfig
