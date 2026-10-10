--!strict
-- Mise en forme des nombres.
--
-- ⚠️ POINT TECHNIQUE QUI A DES CONSÉQUENCES SUR TOUT LE JEU
-- Le cahier des charges prévoit 100 000 $/seconde en zone 7 et un refuge à
-- 500 000 000 $. Un IntValue Roblox est un entier 32 bits : il sature à
-- 2 147 483 647. À 100 000 $/s, un joueur atteint ce plafond en 5 h 58 de jeu,
-- et ensuite son argent arrête de monter (ou devient négatif).
-- Donc : l'argent est stocké en `number` (double, exact jusqu'à 2^53) et
-- affiché avec des suffixes. Aucun IntValue n'est utilisé pour l'argent.

local Format = {}

local UNITS = {
	{ 1e12, "T" },
	{ 1e9, "Md" },
	{ 1e6, "M" },
	{ 1e3, "k" },
}

-- 12 450 → "12,4 k $"  ·  1 500 000 000 → "1,50 Md $"
function Format.money(value: number): string
	local sign = value < 0 and "-" or ""
	local n = math.abs(value)
	for _, unit in ipairs(UNITS) do
		local scale, suffix = unit[1], unit[2]
		if n >= scale then
			local scaled = n / scale
			local decimals = scaled < 10 and 2 or (scaled < 100 and 1 or 0)
			local text = string.format("%." .. decimals .. "f", scaled)
			return sign .. (text:gsub("%.", ",")) .. " " .. suffix .. " $"
		end
	end
	return sign .. string.format("%d", math.floor(n + 0.5)) .. " $"
end

-- Taux par seconde, lisible dans le HUD.
function Format.rate(value: number): string
	return Format.money(value) .. "/s"
end

function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor(seconds % 3600 / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

return Format
