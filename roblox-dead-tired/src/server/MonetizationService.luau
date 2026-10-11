--[[
	MonetizationService — Robux.

	Deux choses à savoir si tu n'as jamais fait ça :

	1. ProcessReceipt doit TOUJOURS renvoyer une valeur de
	   Enum.ProductPurchaseDecision. Si tu renvoies NotProcessedYet, Roblox
	   rappellera la fonction plus tard (utile si la sauvegarde a échoué : le
	   joueur ne perd pas ses Robux). Si tu renvoies PurchaseGranted, l'achat
	   est consommé définitivement.

	2. Tant que `Monetization.luau` ne contient que des IDs à 0, ce service ne
	   fait rien du tout et n'affiche rien. Le jeu reste parfaitement jouable.
]]

local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Monetization = require(Shared.Monetization)

local MonetizationService = {}

local services
-- cache[player][passKey] = booléen
local cache: { [Player]: { [string]: boolean } } = {}

function MonetizationService.init(registry)
	services = registry
end

function MonetizationService.onPlayerAdded(player: Player)
	cache[player] = {}
	-- Pré-chargement des pass possédés, en arrière-plan : un appel réseau raté
	-- ne doit jamais empêcher le joueur de jouer.
	task.spawn(function()
		for key, pass in pairs(Monetization.activePasses()) do
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and cache[player] then
				cache[player][key] = owns and true or false
			end
		end
		if services.Economy then
			services.Economy.push(player)
		end
	end)
end

function MonetizationService.onPlayerRemoving(player: Player)
	cache[player] = nil
end

--[[ Possède-t-il ce pass ? false si l'ID n'est pas configuré. ]]
function MonetizationService.ownsPass(player: Player, passKey: string): boolean
	local pass = Monetization.Passes[passKey]
	if not pass or not pass.Id or pass.Id <= 0 then
		return false
	end
	local entry = cache[player]
	return (entry and entry[passKey]) == true
end

local function applyProduct(player: Player, product): boolean
	if product.Effect == "GrantCash" then
		services.Economy.grantCash(player, product.Value)
		services.Notify.send(player, ("+%d $ crédités. Merci."):format(product.Value), "cash")
		return true
	elseif product.Effect == "InstantRevive" then
		if services.Life.isDown(player) then
			services.Life.revive(player, nil)
			return true
		end
		-- Rien à soigner : on refuse plutôt que de prendre l'argent pour rien.
		services.Notify.send(player, "Tu n'es pas à terre — achat annulé.", "info")
		return false
	end
	warn(("[MonetizationService] effet non implémenté : %s"):format(tostring(product.Effect)))
	return false
end

function MonetizationService.start()
	local products = Monetization.activeProducts()

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = game:GetService("Players"):GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- Le joueur est parti : on réessaiera à sa prochaine session.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local product = products[receiptInfo.ProductId]
		if not product then
			warn(("[MonetizationService] produit %d inconnu"):format(receiptInfo.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local ok, granted = pcall(applyProduct, player, product)
		if not (ok and granted) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- On ne confirme l'achat qu'une fois la sauvegarde réussie, sinon le
		-- joueur pourrait payer et perdre son argent au prochain redémarrage.
		if services.Data.isAvailable() and not services.Data.save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		for key, pass in pairs(Monetization.Passes) do
			if pass.Id == passId then
				if cache[player] then
					cache[player][key] = true
				end
				services.Notify.send(player, ("%s activé."):format(pass.Name), "unlock")
				services.Economy.push(player)
			end
		end
	end)
end

return MonetizationService
