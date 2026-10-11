--[[
	ShopService — achats en argent du jeu.

	Règle de sécurité : le client n'envoie QUE l'identifiant de l'objet voulu.
	Jamais un prix, jamais un niveau. Tout est recalculé ici à partir du
	catalogue et du profil. Un client modifié ne peut donc pas s'offrir un objet
	gratuitement : c'est la base de tout système d'achat sur Roblox.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ShopCatalog = require(Shared.ShopCatalog)
local Monetization = require(Shared.Monetization)
local Net = require(Shared.Net)

local ShopService = {}

local services

function ShopService.init(registry)
	services = registry
end

--[[ Ce que le client a le droit de voir : catalogue + prix calculés pour LUI. ]]
local function buildCatalogFor(player: Player)
	local profile = services.Data.get(player)
	local total = profile and profile.TotalBanked or 0
	local entries = {}

	for _, item in ipairs(ShopCatalog.Items) do
		if not item.RequiresTotal or total >= item.RequiresTotal then
			local owned = services.Economy.getItemLevel(player, item.Id)
			table.insert(entries, {
				Id = item.Id,
				Name = item.Name,
				Desc = item.Desc,
				Kind = item.Kind,
				Order = item.Order,
				Owned = owned,
				MaxLevel = item.MaxLevel or item.MaxStock or 1,
				Price = ShopCatalog.getPrice(item, owned),
				CanBuy = ShopCatalog.canBuyMore(item, owned),
			})
		end
	end

	table.sort(entries, function(a, b)
		return a.Order < b.Order
	end)

	-- Offres Robux : uniquement celles dont l'ID a été renseigné.
	local robux = {}
	for key, pass in pairs(Monetization.activePasses()) do
		table.insert(robux, {
			Kind = "Pass",
			Key = key,
			Id = pass.Id,
			Name = pass.Name,
			Desc = pass.Desc,
			Owned = services.Monetization.ownsPass(player, key),
		})
	end
	for id, product in pairs(Monetization.activeProducts()) do
		table.insert(robux, {
			Kind = "Product",
			Id = id,
			Name = product.Name,
			Desc = product.Desc,
			Owned = false,
		})
	end

	return { Items = entries, Robux = robux }
end

function ShopService.openFor(player: Player)
	;(Net.get("ShopResult") :: RemoteEvent):FireClient(player, {
		Action = "Open",
		Catalog = buildCatalogFor(player),
	})
end

--[[ Tentative d'achat. Retourne (succès, message). ]]
function ShopService.buy(player: Player, itemId: string): (boolean, string)
	local item = ShopCatalog.ById[itemId]
	if not item then
		return false, "Objet inconnu."
	end

	local profile = services.Data.get(player)
	if not profile then
		return false, "Profil pas encore chargé."
	end

	if item.RequiresTotal and profile.TotalBanked < item.RequiresTotal then
		return false, ("Il te faut %d $ déposés au total."):format(item.RequiresTotal)
	end

	local owned = services.Economy.getItemLevel(player, itemId)
	if not ShopCatalog.canBuyMore(item, owned) then
		return false, (item.Kind == "Consumable") and "Stock maximum atteint." or "Niveau maximum atteint."
	end

	local price = ShopCatalog.getPrice(item, owned)
	if not services.Economy.spend(player, price) then
		return false, ("Il te manque %d $."):format(price - profile.Cash)
	end

	profile.Items[itemId] = owned + 1
	services.Economy.applyWalkSpeed(player)
	services.Economy.push(player)
	services.Data.save(player)

	return true, ("%s acheté — %d $."):format(item.Name, price)
end

--[[ Consomme un objet de type Consumable. true si un exemplaire a été retiré. ]]
function ShopService.consume(player: Player, itemId: string): boolean
	local profile = services.Data.get(player)
	if not profile then
		return false
	end
	local stock = profile.Items[itemId] or 0
	if stock <= 0 then
		return false
	end
	profile.Items[itemId] = stock - 1
	services.Economy.push(player)
	return true
end

function ShopService.start()
	;(Net.get("RequestBuy") :: RemoteEvent).OnServerEvent:Connect(function(player, itemId)
		if type(itemId) ~= "string" then
			return
		end
		local ok, message = ShopService.buy(player, itemId)
		;(Net.get("ShopResult") :: RemoteEvent):FireClient(player, {
			Action = "Buy",
			Success = ok,
			Message = message,
			Catalog = buildCatalogFor(player),
		})
		services.Notify.send(player, message, ok and "cash" or "info")
	end)

	;(Net.get("GetCatalog") :: RemoteFunction).OnServerInvoke = function(player)
		return buildCatalogFor(player)
	end
end

return ShopService
