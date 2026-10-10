--!strict
-- §8 et §12 — les skins.
--
-- Deux façons de les obtenir, et c'est volontaire : certains s'achètent avec
-- l'argent du jeu, d'autres ne s'obtiennent qu'en faisant quelque chose. Un
-- skin qui ne s'achète pas vaut plus cher aux yeux des joueurs qu'un skin à
-- 299 Robux — et il ne coûte rien à produire.

export type Cosmetic = {
	Id: string,
	Name: string,
	Desc: string,
	Price: number,          -- 0 = pas en vente
	Shirt: Color3,
	Pants: Color3,
	Head: Color3,
	Requires: { Nights: number?, Deaths: number?, Zone: string?, Achievement: string? }?,
}

local CosmeticConfig = {}

CosmeticConfig.List = {
	{ Id = "default", Name = "Tenue de départ", Desc = "Celle avec laquelle tu arrives.",
		Price = 0, Shirt = Color3.fromRGB(63, 127, 191), Pants = Color3.fromRGB(75, 155, 75),
		Head = Color3.fromRGB(242, 207, 82) },

	{ Id = "nightshift", Name = "Équipe de nuit", Desc = "Gilet réfléchissant. Ironique.",
		Price = 15000, Shirt = Color3.fromRGB(230, 180, 40), Pants = Color3.fromRGB(40, 42, 50),
		Head = Color3.fromRGB(226, 190, 140) },

	{ Id = "sewerman", Name = "Égoutier", Desc = "Ça sent, mais ça tient chaud.",
		Price = 90000, Shirt = Color3.fromRGB(64, 92, 74), Pants = Color3.fromRGB(44, 56, 48),
		Head = Color3.fromRGB(198, 170, 130) },

	{ Id = "porcelain", Name = "Porcelaine", Desc = "Tu lui ressembles un peu trop.",
		Price = 600000, Shirt = Color3.fromRGB(226, 210, 214), Pants = Color3.fromRGB(180, 150, 160),
		Head = Color3.fromRGB(240, 232, 230),
		Requires = { Zone = "dollhouse" } },

	{ Id = "survivor", Name = "Le Survivant", Desc = "Dix nuits sans mourir. Ça se voit.",
		Price = 0, Shirt = Color3.fromRGB(96, 70, 54), Pants = Color3.fromRGB(58, 48, 42),
		Head = Color3.fromRGB(214, 176, 132),
		Requires = { Nights = 10 } },

	{ Id = "clown", Name = "Trophée du Clown", Desc = "Tu l'as fait tomber. Porte-le.",
		Price = 0, Shirt = Color3.fromRGB(180, 40, 70), Pants = Color3.fromRGB(240, 240, 240),
		Head = Color3.fromRGB(250, 250, 250),
		Requires = { Achievement = "carnival_cleared" } },
}

CosmeticConfig.ById = {}
for _, item in ipairs(CosmeticConfig.List) do
	CosmeticConfig.ById[item.Id] = item
end

function CosmeticConfig.get(id: string): Cosmetic?
	return CosmeticConfig.ById[id]
end

-- Renvoie (débloqué, raison de ne pas l'être).
function CosmeticConfig.check(item: Cosmetic, stats: {
	Nights: number, Zones: { [string]: boolean }, Achievements: { [string]: boolean },
}): (boolean, string)
	local req = item.Requires
	if not req then
		return true, ""
	end
	if req.Nights and stats.Nights < req.Nights then
		return false, string.format("%d nuits survécues (tu en as %d)", req.Nights, stats.Nights)
	end
	if req.Zone and not stats.Zones[req.Zone] then
		return false, "débloquer la zone correspondante"
	end
	if req.Achievement and not stats.Achievements[req.Achievement] then
		return false, "battre le boss du carnaval"
	end
	return true, ""
end

return CosmeticConfig
