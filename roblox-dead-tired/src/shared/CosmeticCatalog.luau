--!strict
--[[
	CosmeticCatalog — skins et effets achetables avec l'argent du jeu.

	Règle absolue : **rien ici ne donne le moindre avantage.** Pas de vitesse,
	pas de réduction de risque, pas de gain. Que du visuel.

	Pourquoi c'est une règle et pas une préférence : le jour où un skin rend
	meilleur, les joueurs qui ne l'ont pas arrêtent de jouer, et ceux qui l'ont
	s'ennuient. Les cosmétiques doivent se vendre parce qu'ils donnent un STATUT,
	pas parce qu'ils donnent de la puissance.

	Et c'est justement pour ça que les meilleurs skins ne s'achètent pas avec de
	l'argent seulement : ils demandent une PREUVE. « Survivre une nuit dans Le
	Nid » n'est pas un prix, c'est un trophée — et un trophée que les autres
	voient sur toi, c'est le meilleur moteur de rétention qui existe.

	Emplacements (un équipé à la fois par emplacement) :
	  Skin · Trail · Aura · Title · BedSkin
]]

export type Requirement = {
	TotalBanked: number?,
	DeepestTier: number?,
	NightsSurvived: number?,
}

export type Cosmetic = {
	Id: string,
	Name: string,
	Desc: string,
	Slot: string,
	Price: number,
	Order: number,
	Requires: Requirement?,
	-- données visuelles, lues par CosmeticService
	Color: Color3?,
	Color2: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	LightRange: number?,
	Text: string?,
}

local CosmeticCatalog = {}

CosmeticCatalog.Slots = { "Skin", "Trail", "Aura", "Title", "BedSkin" }

CosmeticCatalog.Items = {
	-- ── SKINS (couleur + matière du personnage) ─────────────────────────────
	{
		Id = "skin_default",
		Name = "Pyjama rayé",
		Desc = "Celui avec lequel tu as commencé. Gratuit, et personne n'est impressionné.",
		Slot = "Skin",
		Price = 0,
		Color = Color3.fromRGB(190, 190, 200),
		Material = Enum.Material.Fabric,
		Order = 1,
	},
	{
		Id = "skin_insomniac",
		Name = "L'Insomniaque",
		Desc = "Cernes, peau grise, regard vide. Tu ne dors plus, tu travailles.",
		Slot = "Skin",
		Price = 1500,
		Color = Color3.fromRGB(126, 126, 134),
		Material = Enum.Material.Sand,
		Order = 2,
	},
	{
		Id = "skin_gold",
		Name = "Doré sur tranche",
		Desc = "Pour prévenir tout le monde que tu as de l'argent. Mauvaise idée, bon skin.",
		Slot = "Skin",
		Price = 12000,
		Color = Color3.fromRGB(226, 182, 70),
		Material = Enum.Material.Metal,
		Requires = { TotalBanked = 20000 },
		Order = 3,
	},
	{
		Id = "skin_survivor",
		Name = "Le Revenant",
		Desc = "Tu as dormi dans Le Nid et tu es revenu. Ce skin ne s'achète pas sans ça.",
		Slot = "Skin",
		Price = 25000,
		Color = Color3.fromRGB(58, 20, 24),
		Material = Enum.Material.Slate,
		Requires = { DeepestTier = 5, NightsSurvived = 15 },
		Order = 4,
	},
	{
		Id = "skin_glass",
		Name = "Verre dépoli",
		Desc = "À moitié transparent. Tu n'es pas plus discret, tu es juste beau.",
		Slot = "Skin",
		Price = 40000,
		Color = Color3.fromRGB(190, 225, 235),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		Requires = { TotalBanked = 75000 },
		Order = 5,
	},

	-- ── TRAÎNÉES ────────────────────────────────────────────────────────────
	{
		Id = "trail_cash",
		Name = "Traînée de billets",
		Desc = "Tu sèmes des billets en courant. Purement décoratif, aucune perte.",
		Slot = "Trail",
		Price = 3500,
		Color = Color3.fromRGB(120, 225, 150),
		Color2 = Color3.fromRGB(40, 110, 60),
		Order = 10,
	},
	{
		Id = "trail_blood",
		Name = "Traînée rouge",
		Desc = "On ne sait pas d'où elle vient. Toi non plus.",
		Slot = "Trail",
		Price = 8000,
		Color = Color3.fromRGB(190, 30, 34),
		Color2 = Color3.fromRGB(60, 6, 8),
		Requires = { NightsSurvived = 10 },
		Order = 11,
	},
	{
		Id = "trail_void",
		Name = "Traînée du Nid",
		Desc = "Une fumée violette qui te suit depuis que tu es descendu là-bas.",
		Slot = "Trail",
		Price = 30000,
		Color = Color3.fromRGB(168, 70, 180),
		Color2 = Color3.fromRGB(28, 10, 34),
		Requires = { DeepestTier = 5 },
		Order = 12,
	},

	-- ── AURAS (lumière autour de toi — visible par tous, y compris… eux) ────
	{
		Id = "aura_candle",
		Name = "Lueur de bougie",
		Desc = "Une lumière chaude et faible autour de toi.",
		Slot = "Aura",
		Price = 2000,
		Color = Color3.fromRGB(255, 196, 120),
		LightRange = 14,
		Order = 20,
	},
	{
		Id = "aura_eyes",
		Name = "Œil pour œil",
		Desc = "La même lumière rouge que la leur. Les autres joueurs détestent ça.",
		Slot = "Aura",
		Price = 15000,
		Color = Color3.fromRGB(255, 42, 36),
		LightRange = 18,
		Requires = { DeepestTier = 4 },
		Order = 21,
	},

	-- ── TITRES (texte au-dessus de la tête) ─────────────────────────────────
	{
		Id = "title_rookie",
		Name = "Titre : Nouveau",
		Desc = "Tout le monde commence là.",
		Slot = "Title",
		Price = 0,
		Text = "Nouveau",
		Color = Color3.fromRGB(150, 150, 160),
		Order = 30,
	},
	{
		Id = "title_sleeper",
		Name = "Titre : Dormeur professionnel",
		Desc = "Dix nuits survécues.",
		Slot = "Title",
		Price = 1000,
		Text = "Dormeur professionnel",
		Color = Color3.fromRGB(120, 225, 150),
		Requires = { NightsSurvived = 10 },
		Order = 31,
	},
	{
		Id = "title_bait",
		Name = "Titre : Appât",
		Desc = "Pour ceux qui réveillent la maison et laissent les autres mourir.",
		Slot = "Title",
		Price = 6000,
		Text = "Appât",
		Color = Color3.fromRGB(255, 160, 60),
		Requires = { DeepestTier = 4 },
		Order = 32,
	},
	{
		Id = "title_nest",
		Name = "Titre : A dormi dans Le Nid",
		Desc = "Le seul titre que personne ne peut acheter sans l'avoir fait.",
		Slot = "Title",
		Price = 20000,
		Text = "A dormi dans Le Nid",
		Color = Color3.fromRGB(190, 130, 255),
		Requires = { DeepestTier = 5 },
		Order = 33,
	},

	-- ── LITERIE (visible pendant que tu dors) ───────────────────────────────
	{
		Id = "bed_default",
		Name = "Matelas d'origine",
		Desc = "Taché. Fonctionnel.",
		Slot = "BedSkin",
		Price = 0,
		Color = Color3.fromRGB(150, 150, 150),
		Material = Enum.Material.Fabric,
		Order = 40,
	},
	{
		Id = "bed_silk",
		Name = "Draps de soie",
		Desc = "Dormir dans une chambre froide, mais avec classe.",
		Slot = "BedSkin",
		Price = 9000,
		Color = Color3.fromRGB(226, 220, 240),
		Material = Enum.Material.Fabric,
		Requires = { TotalBanked = 15000 },
		Order = 41,
	},
	{
		Id = "bed_coffin",
		Name = "Cercueil capitonné",
		Desc = "Autant être prêt.",
		Slot = "BedSkin",
		Price = 35000,
		Color = Color3.fromRGB(44, 26, 30),
		Material = Enum.Material.WoodPlanks,
		Requires = { NightsSurvived = 25 },
		Order = 42,
	},
} :: { Cosmetic }

CosmeticCatalog.ById = {} :: { [string]: Cosmetic }
for _, item in ipairs(CosmeticCatalog.Items) do
	CosmeticCatalog.ById[item.Id] = item
end

--[[ Ce qui est équipé par défaut, pour qu'un nouveau joueur ait déjà une tête. ]]
CosmeticCatalog.Defaults = {
	Skin = "skin_default",
	Title = "title_rookie",
	BedSkin = "bed_default",
}

--[[ Le joueur remplit-il les conditions ? Retourne (ok, raison). ]]
function CosmeticCatalog.meetsRequirement(item: Cosmetic, stats): (boolean, string?)
	local requires = item.Requires
	if not requires then
		return true, nil
	end
	if requires.TotalBanked and stats.TotalBanked < requires.TotalBanked then
		return false, ("Il te faut %d $ déposés au total."):format(requires.TotalBanked)
	end
	if requires.DeepestTier and stats.DeepestTier < requires.DeepestTier then
		return false, ("Il faut avoir dormi au palier %d."):format(requires.DeepestTier)
	end
	if requires.NightsSurvived and stats.NightsSurvived < requires.NightsSurvived then
		return false, ("Il faut avoir survécu à %d nuits."):format(requires.NightsSurvived)
	end
	return true, nil
end

return CosmeticCatalog
