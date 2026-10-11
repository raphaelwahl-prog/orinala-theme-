--!strict
--[[
	Catalogue de la boutique en argent du jeu (pas en Robux).

	Chaque objet a un `Kind` :
	  "Passive"  → effet permanent une fois acheté (s'achète une seule fois)
	  "Upgrade"  → plusieurs niveaux, le prix monte
	  "Consumable" → stock, consommé à l'usage

	Les effets sont lus par EconomyService / SleepService. Si tu ajoutes un objet
	avec un nouvel `Effect`, pense à l'implémenter là-bas (sinon il ne fera rien).
]]

export type ShopItem = {
	Id: string,
	Name: string,
	Desc: string,
	Kind: "Passive" | "Upgrade" | "Consumable",
	Price: number,
	-- Upgrade seulement
	MaxLevel: number?,
	PriceGrowth: number?,
	-- Consumable seulement
	MaxStock: number?,
	-- Pour trier l'affichage
	Order: number,
	-- Identifiant d'effet lu par le serveur
	Effect: string,
	-- Valeur de l'effet (par niveau pour les Upgrade)
	Value: number,
	-- Palier de total déposé requis pour voir l'objet
	RequiresTotal: number?,
}

local ShopCatalog = {}

ShopCatalog.Items = {
	-- ── Réduire le risque ───────────────────────────────────────────────────
	{
		Id = "earplugs",
		Name = "Bouchons d'oreille",
		Desc = "Tu respires moins fort. −15 % de chance d'être repéré par niveau.",
		Kind = "Upgrade",
		Price = 400,
		PriceGrowth = 2.1,
		MaxLevel = 4,
		Effect = "DetectMultiplier",
		Value = 0.15,
		Order = 10,
	},
	{
		Id = "alarm",
		Name = "Réveil à vibration",
		Desc = "Tu te réveilles plus tôt quand il approche. +1,2 s de fenêtre de fuite par niveau.",
		Kind = "Upgrade",
		Price = 650,
		PriceGrowth = 2.3,
		MaxLevel = 3,
		Effect = "WarningBonus",
		Value = 1.2,
		Order = 20,
	},

	-- ── Gagner plus ─────────────────────────────────────────────────────────
	{
		Id = "blanket",
		Name = "Couverture lestée",
		Desc = "Sommeil plus profond, donc mieux payé. +12 % de gains par niveau.",
		Kind = "Upgrade",
		Price = 900,
		PriceGrowth = 2.4,
		MaxLevel = 5,
		Effect = "EarnMultiplier",
		Value = 0.12,
		Order = 30,
	},
	{
		Id = "ledger",
		Name = "Carnet du veilleur",
		Desc = "Le coffre arrondit en ta faveur. +8 % sur chaque dépôt par niveau.",
		Kind = "Upgrade",
		Price = 2200,
		PriceGrowth = 2.6,
		MaxLevel = 3,
		Effect = "BankBonus",
		Value = 0.08,
		RequiresTotal = 2500,
		Order = 40,
	},

	-- ── Survivre ────────────────────────────────────────────────────────────
	{
		Id = "shoes",
		Name = "Baskets de contrebande",
		Desc = "+2 de vitesse de course par niveau. Pour atteindre le coffre à temps.",
		Kind = "Upgrade",
		Price = 750,
		PriceGrowth = 2.2,
		MaxLevel = 4,
		Effect = "WalkSpeedBonus",
		Value = 2,
		Order = 50,
	},
	{
		Id = "medkit",
		Name = "Trousse de secours",
		Desc = "Te relève tout seul une fois, sans coéquipier. Consommée à l'usage.",
		Kind = "Consumable",
		Price = 1200,
		MaxStock = 3,
		Effect = "SelfRevive",
		Value = 1,
		Order = 60,
	},
	{
		Id = "lantern",
		Name = "Lanterne à huile",
		Desc = "Tu vois plus loin dans le noir. Confort, pas de gain d'argent.",
		Kind = "Passive",
		Price = 500,
		Effect = "Lantern",
		Value = 1,
		Order = 70,
	},
}

-- Index par Id, construit au chargement.
ShopCatalog.ById = {} :: { [string]: ShopItem }
for _, item in ipairs(ShopCatalog.Items) do
	ShopCatalog.ById[item.Id] = item
end

--[[ Prix du prochain niveau d'une amélioration.
	 level = niveau actuel possédé (0 = rien). ]]
function ShopCatalog.getPrice(item: ShopItem, level: number): number
	if item.Kind == "Upgrade" then
		local growth = item.PriceGrowth or 2
		return math.floor(item.Price * (growth ^ level))
	end
	return item.Price
end

--[[ L'objet est-il encore achetable à ce niveau / ce stock ? ]]
function ShopCatalog.canBuyMore(item: ShopItem, owned: number): boolean
	if item.Kind == "Upgrade" then
		return owned < (item.MaxLevel or 1)
	elseif item.Kind == "Consumable" then
		return owned < (item.MaxStock or 1)
	end
	return owned < 1
end

return ShopCatalog
