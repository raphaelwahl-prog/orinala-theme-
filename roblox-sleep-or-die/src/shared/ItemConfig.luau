--!strict
-- Équipements du §6. Les prix sont ceux du cahier des charges.
--
-- Le CDC précise : « Ils ne doivent jamais rendre le joueur invincible. »
-- C'est appliqué ici par trois règles tenues côté serveur :
--   · tout équipement de défense a une DURABILITÉ (il se consomme) ;
--   · aucun ne met la détection ou les dégâts à zéro, seulement en pourcentage ;
--   · chaque refuge a un nombre de emplacements limité (ShelterService).

export type Kind = "weapon" | "defense"

export type Item = {
	Id: string,
	Name: string,
	Kind: Kind,
	Price: number,
	Zone: string,          -- zone minimale où l'objet est en vente
	Desc: string,
	-- armes
	Damage: number?,
	StunSeconds: number?,
	Cooldown: number?,
	-- défenses
	Slots: number?,        -- emplacements occupés dans le refuge
	Durability: number?,   -- nombre d'assauts encaissés avant destruction
	DelaySeconds: number?, -- temps gagné sur un assaut
	DetectionCut: number?, -- réduction de la chance d'être repéré (0..0.6)
	WarningSeconds: number?,
}

local ItemConfig = {}

ItemConfig.List = {
	-- Armes
	{ Id = "bat_wood", Name = "Batte en bois", Kind = "weapon", Price = 2500, Zone = "street",
		Damage = 12, StunSeconds = 0.8, Cooldown = 0.9,
		Desc = "Repousse. Ne tue pas." },
	{ Id = "bat_steel", Name = "Batte renforcée", Kind = "weapon", Price = 100000, Zone = "sewers",
		Damage = 30, StunSeconds = 1.2, Cooldown = 0.9,
		Desc = "Assez lourde pour faire reculer ce qui vit sous la ville." },
	{ Id = "stun_baton", Name = "Matraque électrique", Kind = "weapon", Price = 1000000, Zone = "dollhouse",
		Damage = 45, StunSeconds = 3.0, Cooldown = 2.5,
		Desc = "Trois secondes d'immobilité. C'est long, trois secondes." },
	{ Id = "pulse_gun", Name = "Arme à impulsion", Kind = "weapon", Price = 25000000, Zone = "convent",
		Damage = 110, StunSeconds = 4.0, Cooldown = 4.0,
		Desc = "Souffle le monstre en arrière. Recharge lente." },
	{ Id = "legendary", Name = "Arme légendaire", Kind = "weapon", Price = 150000000, Zone = "hospital",
		Damage = 260, StunSeconds = 5.0, Cooldown = 6.0,
		Desc = "Ne tue toujours pas le boss. Elle fait gagner du temps." },

	-- Défenses
	{ Id = "alarm", Name = "Alarme de proximité", Kind = "defense", Price = 5000, Zone = "street",
		Slots = 1, Durability = 8, WarningSeconds = 3.5,
		Desc = "Prévient 3,5 s avant l'assaut. Se déclenche 8 fois." },
	{ Id = "snare", Name = "Piège ralentisseur", Kind = "defense", Price = 25000, Zone = "street",
		Slots = 1, Durability = 4, DelaySeconds = 4,
		Desc = "Retient le monstre 4 s. Quatre usages." },
	{ Id = "barricade", Name = "Barricade renforcée", Kind = "defense", Price = 150000, Zone = "sewers",
		Slots = 2, Durability = 6, DelaySeconds = 7,
		Desc = "Sept secondes de plus. Elle finit toujours par céder." },
	{ Id = "camera", Name = "Caméra de surveillance", Kind = "defense", Price = 750000, Zone = "dollhouse",
		Slots = 1, Durability = 20, DetectionCut = 0.15, WarningSeconds = 6,
		Desc = "Voir venir vaut mieux que résister." },
	{ Id = "steel_door", Name = "Porte blindée", Kind = "defense", Price = 5000000, Zone = "slasher",
		Slots = 2, Durability = 10, DelaySeconds = 12, DetectionCut = 0.1,
		Desc = "Douze secondes. Dix assauts. Pas un de plus." },
	{ Id = "shield", Name = "Bouclier anti-monstre", Kind = "defense", Price = 25000000, Zone = "convent",
		Slots = 3, Durability = 6, DelaySeconds = 18, DetectionCut = 0.2,
		Desc = "Le couvent sait le neutraliser. Pas partout." },
	{ Id = "ultimate", Name = "Refuge ultime", Kind = "defense", Price = 500000000, Zone = "hospital",
		Slots = 5, Durability = 12, DelaySeconds = 25, DetectionCut = 0.35,
		Desc = "Le meilleur abri du jeu. Il tombe en douze assauts." },
} :: { Item }

ItemConfig.ById = {}
for _, item in ipairs(ItemConfig.List) do
	ItemConfig.ById[item.Id] = item
end

function ItemConfig.get(id: string): Item?
	return ItemConfig.ById[id]
end

-- Somme des effets des défenses posées, bornée pour qu'aucun refuge ne soit
-- imprenable : la détection ne descend jamais sous 40 % de sa valeur de base.
function ItemConfig.defenseProfile(placed: { [string]: number }): {
	Delay: number, Warning: number, Detection: number, Slots: number,
}
	local delay, warning, cut, slots = 0, 0, 0, 0
	for id, count in pairs(placed) do
		local item = ItemConfig.ById[id]
		if item and item.Kind == "defense" and count > 0 then
			delay += (item.DelaySeconds or 0) * count
			warning = math.max(warning, item.WarningSeconds or 0)
			cut += (item.DetectionCut or 0) * count
			slots += (item.Slots or 1) * count
		end
	end
	return {
		Delay = math.min(delay, 40),
		Warning = warning,
		Detection = math.max(0.4, 1 - math.min(cut, 0.6)),
		Slots = slots,
	}
end

return ItemConfig
