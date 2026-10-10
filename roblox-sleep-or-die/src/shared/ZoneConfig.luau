--!strict
-- Les 7 zones, telles que décrites au §3 du cahier des charges.
--
-- Les gains et les seuils sont ceux du document. Deux remarques honnêtes, à
-- lire avant d'équilibrer (le CDC dit lui-même que ce sont des valeurs à
-- tester) :
--
-- 1. La marche zone 6 → zone 7 est de x8 (12 500 → 100 000 $/s) alors que les
--    autres vont de x2,5 à x10. Surtout, à 100 000 $/s on gagne les 15 M$ qui
--    débloquent l'hôpital en 150 secondes : une fois le carnaval atteint, tout
--    le reste de l'économie n'existe plus. `Zone.SoftCapPerSession` plafonne
--    donc ce qu'une seule session peut rapporter, par zone.
-- 2. Les seuils de déblocage sont cumulatifs sur l'argent DÉPOSÉ (Cash gagné à
--    vie), pas sur le solde courant : sinon il suffit de ne rien dépenser.

export type Zone = {
	Id: string,
	Order: number,
	Name: string,
	Rate: number,              -- $ par seconde de survie éligible
	SoftCapPerSession: number, -- au-delà, le taux est divisé par 4
	MaxSessionSeconds: number, -- une session ne dure pas éternellement
	DeathLossRatio: number,    -- part du non sécurisé perdue à la mort
	Monster: string,
	Unlock: {
		Banked: number,            -- $ cumulés déposés
		Missions: number,          -- missions principales terminées
		NightsSurvived: number,
		SurvivalSeconds: number,
		RequiresQuest: string?,
	},
	Blurb: string,
	Mechanic: string,
}

local ZoneConfig = {}

ZoneConfig.List = {
	{
		Id = "street", Order = 1, Name = "La rue",
		Rate = 10, SoftCapPerSession = 4000, MaxSessionSeconds = 300,
		DeathLossRatio = 0.5, Monster = "prowler",
		Unlock = { Banked = 0, Missions = 0, NightsSurvived = 0, SurvivalSeconds = 0 },
		Blurb = "Des refuges précaires entre deux immeubles. On y apprend à dormir sans mourir.",
		Mechanic = "Tutoriel : réserver, barricader, dormir, se réveiller à temps.",
	},
	{
		Id = "sewers", Order = 2, Name = "Les égouts",
		Rate = 100, SoftCapPerSession = 30000, MaxSessionSeconds = 300,
		DeathLossRatio = 0.5, Monster = "sewer_thing",
		Unlock = { Banked = 10000, Missions = 2, NightsSurvived = 0, SurvivalSeconds = 0 },
		Blurb = "Tunnels étroits, embuscades, ressources cachées.",
		Mechanic = "Itinéraires : une seule sortie par section, il faut choisir avant de dormir.",
	},
	{
		Id = "dollhouse", Order = 3, Name = "La maison des poupées",
		Rate = 500, SoftCapPerSession = 120000, MaxSessionSeconds = 360,
		DeathLossRatio = 0.55, Monster = "doll",
		Unlock = { Banked = 200000, Missions = 3, NightsSurvived = 3, SurvivalSeconds = 0 },
		Blurb = "Elle ne bouge que quand personne ne la regarde.",
		Mechanic = "Observation : la poupée est figée tant qu'un joueur l'a dans son champ de vision.",
	},
	{
		Id = "slasher", Order = 4, Name = "Le quartier du slasher",
		Rate = 1500, SoftCapPerSession = 350000, MaxSessionSeconds = 360,
		DeathLossRatio = 0.6, Monster = "slasher",
		Unlock = { Banked = 1500000, Missions = 4, NightsSurvived = 0, SurvivalSeconds = 0,
			RequiresQuest = "chase" },
		Blurb = "Brume, pavillons, et quelqu'un qui ne s'arrête jamais.",
		Mechanic = "Lent mais increvable : on ne le combat pas, on gère les raccourcis.",
	},
	{
		Id = "convent", Order = 5, Name = "Le couvent maudit",
		Rate = 5000, SoftCapPerSession = 1000000, MaxSessionSeconds = 420,
		DeathLossRatio = 0.65, Monster = "demon",
		Unlock = { Banked = 5000000, Missions = 5, NightsSurvived = 0, SurvivalSeconds = 0,
			RequiresQuest = "vigil" },
		Blurb = "Les défenses tiennent. C'est elle qui décide quand elles lâchent.",
		Mechanic = "Les équipements peuvent être neutralisés : il faut une solution de repli.",
	},
	{
		Id = "hospital", Order = 6, Name = "L'hôpital des cauchemars",
		Rate = 12500, SoftCapPerSession = 2500000, MaxSessionSeconds = 420,
		DeathLossRatio = 0.7, Monster = "mimic_voice",
		Unlock = { Banked = 15000000, Missions = 6, NightsSurvived = 0, SurvivalSeconds = 0,
			RequiresQuest = "extreme_night" },
		Blurb = "Les alarmes mentent. Les voix aussi.",
		Mechanic = "Fausses alertes : une partie des signaux sonores et visuels est truquée.",
	},
	{
		Id = "carnival", Order = 7, Name = "Le carnaval de l'enfer",
		Rate = 100000, SoftCapPerSession = 8000000, MaxSessionSeconds = 480,
		DeathLossRatio = 0.75, Monster = "clown_boss",
		Unlock = { Banked = 60000000, Missions = 7, NightsSurvived = 0, SurvivalSeconds = 36000,
			RequiresQuest = "secret" },
		Blurb = "Zone finale. Un seul occupant, un seul boss, plusieurs phases.",
		Mechanic = "Combat de boss en phases : chaque phase reprend une mécanique d'une zone.",
	},
} :: { Zone }

ZoneConfig.ById = {}
for _, zone in ipairs(ZoneConfig.List) do
	ZoneConfig.ById[zone.Id] = zone
end

function ZoneConfig.get(id: string): Zone?
	return ZoneConfig.ById[id]
end

function ZoneConfig.first(): Zone
	return ZoneConfig.List[1]
end

-- Renvoie true + nil si la zone est accessible, false + la raison sinon.
function ZoneConfig.canEnter(zone: Zone, stats: {
	LifetimeBanked: number, MainMissions: number, NightsSurvived: number,
	SurvivalSeconds: number, Quests: { [string]: boolean },
}): (boolean, string?)
	local u = zone.Unlock
	if stats.LifetimeBanked < u.Banked then
		return false, string.format("Il faut %d $ déposés à vie.", u.Banked)
	end
	if stats.MainMissions < u.Missions then
		return false, string.format("Il faut %d missions principales.", u.Missions)
	end
	if stats.NightsSurvived < u.NightsSurvived then
		return false, string.format("Il faut %d nuits survécues.", u.NightsSurvived)
	end
	if stats.SurvivalSeconds < u.SurvivalSeconds then
		return false, string.format("Il faut %d heures de survie cumulées.",
			math.floor(u.SurvivalSeconds / 3600))
	end
	if u.RequiresQuest and not stats.Quests[u.RequiresQuest] then
		return false, "Une quête spéciale reste à terminer."
	end
	return true, nil
end

return ZoneConfig
