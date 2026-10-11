--!strict
-- §6 — inventaire. Court, parce que tout l'argent est dans EconomyService et
-- toute la pose de défenses dans ShelterService.

local ItemConfig = require(script.Parent.Parent.Shared.ItemConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}

function InventoryService.count(player: Player, itemId: string): number
	local profile = PlayerDataService.get(player)
	return profile and (profile.Inventory[itemId] or 0) or 0
end

function InventoryService.add(player: Player, itemId: string, amount: number?): boolean
	local profile = PlayerDataService.get(player)
	if not profile or not ItemConfig.get(itemId) then
		return false
	end
	local n = amount or 1
	if n <= 0 then
		return false
	end
	profile.Inventory[itemId] = (profile.Inventory[itemId] or 0) + n
	PlayerDataService.markDirty(player)
	return true
end

function InventoryService.remove(player: Player, itemId: string, amount: number?): boolean
	local profile = PlayerDataService.get(player)
	if not profile then
		return false
	end
	local n = amount or 1
	local owned = profile.Inventory[itemId] or 0
	if owned < n then
		return false
	end
	profile.Inventory[itemId] = owned - n
	PlayerDataService.markDirty(player)
	return true
end

function InventoryService.bestWeapon(player: Player): ItemConfig.Item?
	local profile = PlayerDataService.get(player)
	if not profile then
		return nil
	end
	local best: ItemConfig.Item? = nil
	for _, item in ipairs(ItemConfig.List) do
		if item.Kind == "weapon" and (profile.Inventory[item.Id] or 0) > 0 then
			if not best or item.Price > best.Price then
				best = item
			end
		end
	end
	return best
end

return InventoryService
