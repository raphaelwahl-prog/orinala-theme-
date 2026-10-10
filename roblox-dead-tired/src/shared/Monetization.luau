--!strict
--[[
	Monétisation Robux.

	⚠️  LIS-MOI : les IDs ci-dessous sont des ZÉROS = désactivés.
	Tant qu'un ID vaut 0, le jeu fonctionne normalement, l'objet n'apparaît
	simplement pas dans la boutique Robux. Rien ne plante.

	Pour activer :
	  1. Dans Roblox Studio, publie ton jeu.
	  2. Site Roblox → Créations → ton jeu → Monétisation.
	     - "Passes" pour les Game Passes (achat unique, permanent).
	     - "Developer Products" pour les achats répétables (packs d'argent).
	  3. Copie l'ID de chaque création et colle-le ici.

	Règle Roblox à respecter : on ne vend JAMAIS un avantage qui casse le jeu
	pour les autres. Un x2 d'argent et des vies en plus, c'est accepté et c'est
	ce que font tous les jeux du genre. Ne vends pas d'immunité au monstre :
	ça tue le jeu et ça fait fuir les joueurs.
]]

local Monetization = {}

-- ── GAME PASSES (achat unique, effet permanent) ──────────────────────────────
Monetization.Passes = {
	DoubleCash = {
		Id = 0, -- ← colle ici l'ID du Game Pass
		Name = "Double Argent",
		Desc = "Tous tes gains de sommeil sont multipliés par 2, pour toujours.",
		Effect = "CashMultiplier",
		Value = 2,
	},
	ExtraLife = {
		Id = 0,
		Name = "Seconde chance",
		Desc = "Une réanimation automatique gratuite par nuit.",
		Effect = "FreeRevivePerNight",
		Value = 1,
	},
	VipRoom = {
		Id = 0,
		Name = "Chambre VIP",
		Desc = "Accès à une planque de palier 3 totalement sûre.",
		Effect = "VipRoom",
		Value = 1,
	},
}

-- ── DEVELOPER PRODUCTS (achetables en boucle) ────────────────────────────────
Monetization.Products = {
	[0] = nil, -- placeholder, ignoré
}

-- Liste déclarative : le serveur lit celle-ci et construit la table par ID.
Monetization.ProductList = {
	{
		Id = 0, -- ← colle ici l'ID du Developer Product
		Name = "Petite liasse",
		Desc = "+2 500 $ tout de suite.",
		Effect = "GrantCash",
		Value = 2500,
	},
	{
		Id = 0,
		Name = "Grosse liasse",
		Desc = "+12 000 $ tout de suite.",
		Effect = "GrantCash",
		Value = 12000,
	},
	{
		Id = 0,
		Name = "Relevage immédiat",
		Desc = "Te remet debout instantanément quand tu es à terre.",
		Effect = "InstantRevive",
		Value = 1,
	},
}

--[[ Les entrées actives seulement (ID non nul). ]]
function Monetization.activePasses()
	local out = {}
	for key, pass in pairs(Monetization.Passes) do
		if pass.Id and pass.Id > 0 then
			out[key] = pass
		end
	end
	return out
end

function Monetization.activeProducts()
	local out = {}
	for _, product in ipairs(Monetization.ProductList) do
		if product.Id and product.Id > 0 then
			out[product.Id] = product
		end
	end
	return out
end

return Monetization
