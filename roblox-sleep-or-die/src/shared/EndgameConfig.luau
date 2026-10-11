--!strict
-- §8 — ce que le jeu propose APRÈS la victoire contre le boss final.
--
-- Le cahier des charges est explicite sur la condition d'ouverture : « Après
-- la victoire contre le boss final, le jeu doit proposer : des variantes de
-- monstres, des défis de survie avec des règles particulières, des contrats
-- rares, des classements saisonniers, des collections de monstres et de
-- documents, des succès et titres, des cosmétiques exclusifs, des événements
-- limités dans le temps. »
--
-- Les classements (LeaderboardService), les cosmétiques exclusifs
-- (CosmeticConfig) et les événements (EventService) existaient déjà. Ce
-- fichier porte les quatre qui manquaient : variantes, défis, contrats,
-- collections — et les titres qui couronnent les collections.
--
-- Rien ici ne s'applique tant que `Achievements.carnival_cleared` est faux.
-- C'est EndgameService qui tient cette porte, à un seul endroit.

local EndgameConfig = {}

-- ── variantes de monstres ─────────────────────────────────────────────────
--
-- Une variante n'est pas un monstre neuf : c'est le monstre de la zone avec
-- d'autres chiffres. Même silhouette, mêmes sons, même code — seul le
-- `table.clone` du def change, exactement comme le mini-boss d'événement.
--
-- Deux raisons de faire comme ça plutôt que d'ajouter sept monstres : le
-- joueur a passé cinq heures à apprendre à lire les signaux de chacun, et une
-- variante qui garde la silhouette mais déplace les chiffres récompense cet
-- apprentissage au lieu de l'annuler. Et `MaxAlive`, les sons et les gabarits
-- restent ceux qui ont été réglés.
--
-- `Rule` est le champ dangereux : L'AVEUGLE remplace la mécanique de la zone
-- par celle des égouts. C'est voulu, c'est le cœur de l'intérêt — mais il faut
-- que son nom le dise, sinon c'est une trahison et pas une variante.

export type Variant = {
	Id: string,
	Name: string,            -- suffixe accolé au nom du monstre
	Speed: number,
	Sight: number,
	Hear: number,
	Damage: number,
	Scale: number,
	GiveUp: number,
	Bounty: number,          -- multiplicateur de gain tant qu'elle est en vie
	Weight: number,          -- poids du tirage
	Rule: string?,           -- remplace la mécanique de la zone, si présent
	Tell: string,
}

EndgameConfig.Variants = {
	{ Id = "ancien", Name = "L'ANCIEN",
		Speed = 0.85, Sight = 1.6, Hear = 1.2, Damage = 1.5, Scale = 1.25,
		GiveUp = 1.5, Bounty = 2, Weight = 3,
		Tell = "Plus grand, plus lent, et il voit de bien plus loin." },

	{ Id = "famelique", Name = "LE FAMÉLIQUE",
		Speed = 1.45, Sight = 0.9, Hear = 1.4, Damage = 0.7, Scale = 0.85,
		GiveUp = 0.8, Bounty = 1.6, Weight = 4,
		Tell = "Maigre et rapide. Il frappe moins fort mais il te rattrape." },

	{ Id = "aveugle", Name = "L'AVEUGLE",
		Speed = 1, Sight = 0.15, Hear = 2.2, Damage = 1.2, Scale = 1,
		GiveUp = 1, Bounty = 1.8, Weight = 3, Rule = "sound",
		Tell = "Il ne voit rien. Tout ce que tu as appris sur son regard ne sert plus : c'est le bruit, maintenant." },

	{ Id = "hurleur", Name = "LE HURLEUR",
		Speed = 1.1, Sight = 1.1, Hear = 1.6, Damage = 1, Scale = 1.05,
		GiveUp = 1.2, Bounty = 1.7, Weight = 3,
		Tell = "Quand il te repère, la maison entière se réveille d'un coup." },

	{ Id = "patient", Name = "LE PATIENT",
		Speed = 0.7, Sight = 1.2, Hear = 1, Damage = 1.8, Scale = 1.1,
		GiveUp = 4, Bounty = 2.2, Weight = 2,
		Tell = "Il n'abandonne pas. Casser la ligne de vue ne suffit plus, il faut partir." },
} :: { Variant }

EndgameConfig.VariantById = {}
for _, variant in ipairs(EndgameConfig.Variants) do
	EndgameConfig.VariantById[variant.Id] = variant
end

-- Points d'éveil que LE HURLEUR ajoute d'un coup quand il repère quelqu'un.
-- La valeur vit ici et pas dans AwakeningConfig : c'est une propriété de la
-- variante. Les seuils de stade sont à 16, 40 et 76 — 14 points font donc
-- presque basculer un stade à eux seuls, ce qui est l'effet voulu.
EndgameConfig.HowlerFeed = 14

-- ── défis de survie ───────────────────────────────────────────────────────
--
-- « Des défis de survie avec des règles particulières. » Un défi s'arme avant
-- de dormir et vaut pour une session. Chaque règle est appliquée à UN seul
-- endroit du code — c'est la condition pour qu'elle soit vraiment là et pas
-- seulement écrite ici :
--
--   no_defense   → ShelterService.defensesDisabled
--   light_sleep  → SurvivalService, à l'assaut
--   all_in       → SurvivalService, le délai de grâce
--   blind        → init.server, l'envoi des alertes
--
-- Tous sont strictement individuels. Un défi ne change jamais le jeu des
-- autres joueurs du serveur : ce serait leur imposer un choix qu'ils n'ont
-- pas fait.

export type Challenge = {
	Id: string,
	Name: string,
	Reward: number,          -- multiplicateur de gain pendant la session
	Text: string,
}

EndgameConfig.Challenges = {
	{ Id = "no_defense", Name = "À NU", Reward = 1.5,
		Text = "Tes défenses ne retardent plus rien. Le refuge n'est qu'un lit." },
	{ Id = "light_sleep", Name = "SOMMEIL LÉGER", Reward = 2.1,
		Text = "Le premier assaut sur ton refuge met fin à la session. Tu gardes ce que tu as gagné." },
	{ Id = "all_in", Name = "TOUT OU RIEN", Reward = 1.6,
		Text = "Aucun délai de grâce, et mourir te prend tout ce qui n'est pas en banque." },
	{ Id = "blind", Name = "SANS ALERTE", Reward = 1.75,
		Text = "Plus un seul message. Ni les assauts, ni les repérages, ni les monstres." },
} :: { Challenge }

EndgameConfig.ChallengeById = {}
for _, challenge in ipairs(EndgameConfig.Challenges) do
	EndgameConfig.ChallengeById[challenge.Id] = challenge
end

-- ── contrats rares ────────────────────────────────────────────────────────
--
-- « Rares » est une contrainte, pas une décoration : un contrat qu'on peut
-- relancer à volonté est une mission secondaire. Un seul à la fois, un tirage
-- qui échoue la plupart du temps, un délai qui court en temps réel même
-- déconnecté — c'est `os.time` et pas `os.clock` pour cette raison.
--
-- `Kind` est compté par EndgameService.note, appelé depuis init.server. Aucun
-- contrat ne dépend d'un compteur que personne n'incrémente : c'est
-- exactement le défaut qu'avaient les événements du §13 avant correction.

export type Contract = {
	Id: string,
	Name: string,
	Kind: string,            -- compteur suivi
	Target: number,
	Zone: string?,           -- si présent, ne compte que dans cette zone
	-- Si vrai, compte des éléments DIFFÉRENTS et non des occurrences.
	-- « Croise trois variantes » veut dire trois variantes, pas trois fois la
	-- même — et c'est le genre de nuance qu'un test par mutation attrape et
	-- qu'une relecture laisse passer : sans ce champ, le contrat se remplissait
	-- en croisant trois fois LE FAMÉLIQUE.
	Distinct: boolean?,
	Cash: number,
	Seconds: number,         -- délai pour le tenir
	Weight: number,
	Text: string,
}

EndgameConfig.Contracts = {
	{ Id = "c_variants", Name = "RELEVÉ DE FORMES", Kind = "variant_met", Target = 3,
		Distinct = true, Cash = 4000000, Seconds = 1200, Weight = 4,
		Text = "Croise trois variantes DIFFÉRENTES, n'importe où." },

	{ Id = "c_patient", Name = "CELUI QUI ATTEND", Kind = "variant_patient", Target = 1,
		Cash = 5000000, Seconds = 1800, Weight = 2,
		Text = "Croise LE PATIENT. Il est le plus rare des cinq." },

	{ Id = "c_challenges", Name = "DEUX FOIS DE SUITE", Kind = "challenge_done", Target = 2,
		Cash = 6000000, Seconds = 1800, Weight = 3,
		Text = "Termine deux sessions sous défi. Peu importe lesquels." },

	{ Id = "c_archive", Name = "L'ARCHIVE", Kind = "document_found", Target = 3,
		Cash = 3000000, Seconds = 2400, Weight = 3,
		Text = "Retrouve trois documents dans les zones." },

	{ Id = "c_carnival", Name = "RETOUR AU CARNAVAL", Kind = "session_done", Target = 1,
		Zone = "carnival", Cash = 9000000, Seconds = 900, Weight = 1,
		Text = "Une session complète au carnaval. Là où tu l'as battu." },
} :: { Contract }

EndgameConfig.ContractById = {}
for _, contract in ipairs(EndgameConfig.Contracts) do
	EndgameConfig.ContractById[contract.Id] = contract
end

-- ── collections ───────────────────────────────────────────────────────────
--
-- « Des collections de monstres et de documents. » Les monstres se remplissent
-- tout seuls, avec `MonstersSeen` qui existait déjà pour l'écran des
-- révélations. Les documents demandent des objets dans le monde : un par zone,
-- posés par WorldService sur un point de ronde, sur le modèle des objectifs du
-- §7 (une Part taguée, une invite de proximité).
--
-- Un document ne disparaît pas quand on le ramasse, contrairement aux
-- objectifs : il est noté dans le profil du joueur et reste là pour les
-- autres. Le faire disparaître le rendrait introuvable pour tout le serveur
-- dès qu'un seul joueur passe.

export type Document = {
	Id: string,
	Zone: string,
	Name: string,
	Text: string,
}

EndgameConfig.Documents = {
	{ Id = "d_street", Zone = "street", Name = "AVIS D'ÉVACUATION",
		Text = "« Quartier fermé jusqu'à nouvel ordre. Ne dormez pas dehors. » Le tampon est daté, le mois est illisible." },
	{ Id = "d_sewers", Zone = "sewers", Name = "RAPPORT D'ENTRETIEN",
		Text = "« Bruit dans la conduite 4 depuis trois semaines. Ne descendez pas seuls. » Deux noms sont rayés." },
	{ Id = "d_dollhouse", Zone = "dollhouse", Name = "PAGE DE CARNET",
		Text = "« Elle ne bouge pas quand on la regarde. On a essayé de ne plus jamais la regarder. Ça n'a pas marché. »" },
	{ Id = "d_slasher", Zone = "slasher", Name = "COUPURE DE PRESSE",
		Text = "« Sixième disparition dans le quartier. L'enquête ne retient aucune piste. » Le reste de la page manque." },
	{ Id = "d_convent", Zone = "convent", Name = "REGISTRE DU COUVENT",
		Text = "« Les lampes s'éteignent avant qu'elle entre. Nous avons cessé de les rallumer. »" },
	{ Id = "d_hospital", Zone = "hospital", Name = "FEUILLE DE GARDE",
		Text = "« L'interphone appelle des chambres vides. Ne répondez jamais au premier appel. »" },
	{ Id = "d_carnival", Zone = "carnival", Name = "AFFICHE DE LA FÊTE",
		Text = "« Trois tours, trois visages, un seul gagnant. » Au dos, à la main : « il recommence »." },
} :: { Document }

EndgameConfig.DocumentById = {}
for _, document in ipairs(EndgameConfig.Documents) do
	EndgameConfig.DocumentById[document.Id] = document
end

-- ── titres ────────────────────────────────────────────────────────────────
--
-- « Des succès et titres. » Le boss donnait déjà un trophée et un titre ; ces
-- trois-là couronnent les collections, donc ils ne s'achètent pas et ne se
-- tirent pas au sort : ils se remplissent.

export type Title = {
	Id: string,
	Name: string,
	Set: string,             -- "monsters" | "variants" | "documents"
	Text: string,
}

EndgameConfig.Titles = {
	{ Id = "t_veilleur", Name = "VEILLEUR", Set = "monsters",
		Text = "Les sept monstres croisés au moins une fois." },
	{ Id = "t_formes", Name = "LECTEUR DE FORMES", Set = "variants",
		Text = "Les cinq variantes croisées au moins une fois." },
	{ Id = "t_archiviste", Name = "ARCHIVISTE", Set = "documents",
		Text = "Les sept documents retrouvés." },
} :: { Title }

function EndgameConfig.variant(id: string): Variant?
	return EndgameConfig.VariantById[id]
end

function EndgameConfig.challenge(id: string): Challenge?
	return EndgameConfig.ChallengeById[id]
end

function EndgameConfig.contract(id: string): Contract?
	return EndgameConfig.ContractById[id]
end

function EndgameConfig.document(id: string): Document?
	return EndgameConfig.DocumentById[id]
end

-- Tirage pondéré. Renvoie nil si la liste est vide, jamais une erreur : un
-- tirage raté ne doit pas casser une apparition de monstre.
function EndgameConfig.draw<T>(list: { T }, weightOf: (T) -> number): T?
	local total = 0
	for _, entry in ipairs(list) do
		total += math.max(0, weightOf(entry))
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for _, entry in ipairs(list) do
		roll -= math.max(0, weightOf(entry))
		if roll <= 0 then
			return entry
		end
	end
	return list[#list]
end

return EndgameConfig
