--!strict
-- §6 — la boutique. Le client envoie un identifiant d'objet, rien d'autre :
-- le prix vient toujours du serveur.

local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local ItemConfig = require(script.Parent.Parent.Shared.ItemConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)

local ShopService = {}

-- Un objet n'est en vente que si la zone qui le propose est débloquée.
function ShopService.isAvailable(player: Player, item: ItemConfig.Item): boolean
	local profile = PlayerDataService.get(player)
	if not profile then
		return false
	end
	return profile.Zones[item.Zone] == true
end

function ShopService.catalogue(player: Player): { { Id: string, Name: string, Price: number,
	Kind: string, Desc: string, Owned: number, Available: boolean, Zone: string } }
	local out = {}
	for _, item in ipairs(ItemConfig.List) do
		table.insert(out, {
			Id = item.Id, Name = item.Name, Price = item.Price, Kind = item.Kind,
			Desc = item.Desc, Owned = InventoryService.count(player, item.Id),
			Available = ShopService.isAvailable(player, item),
			Zone = (ZoneConfig.get(item.Zone) :: any).Name,
		})
	end
	return out
end

function ShopService.buy(player: Player, itemId: string): (boolean, string)
	local item = ItemConfig.get(itemId)
	if not item then
		return false, "Objet inconnu."
	end
	if not ShopService.isAvailable(player, item) then
		return false, "Débloque d'abord la zone correspondante."
	end
	-- Les armes ne se cumulent pas : une seule de chaque.
	if item.Kind == "weapon" and InventoryService.count(player, itemId) > 0 then
		return false, "Tu l'as déjà."
	end
	if not EconomyService.spend(player, item.Price) then
		return false, "Pas assez d'argent sécurisé."
	end
	InventoryService.add(player, itemId, 1)
	return true, item.Name .. " acheté."
end

return ShopService
