--!strict
-- §12 — Robux.
--
-- Deux règles non négociables du CDC :
--   · « Les récompenses d'achat doivent être attribuées côté serveur et ne
--     jamais être données plusieurs fois pour le même reçu. » → `Receipts`
--     dans le profil, consulté AVANT d'accorder et écrit AVANT de renvoyer
--     PurchaseGranted.
--   · « Les achats d'argent ne doivent pas permettre de contourner les quêtes
--     et les conditions d'accès aux zones finales. » → l'argent acheté
--     alimente Cash mais PAS LifetimeBanked, qui seul débloque les zones.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local EconomyService = require(script.Parent.EconomyService)
local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local MonetizationService = {}

local byProductId: { [number]: any } = {}

local function grantProduct(player: Player, product): boolean
	if product.Effect == "cash" then
		local profile = PlayerDataService.get(player)
		if not profile then
			return false
		end
		-- Volontairement : Cash seulement. LifetimeBanked reste intact, donc
		-- acheter de l'argent ne débloque aucune zone.
		profile.Cash += product.Value
		PlayerDataService.markDirty(player)
		return true
	elseif product.Effect == "multiplier" then
		EconomyService.setMultiplier(player, product.Value, product.Seconds or 900)
		return true
	end
	return false
end

function MonetizationService.init()
	for _, product in ipairs(GameConfig.Monetization.Products) do
		if product.DevProductId and product.DevProductId > 0 then
			byProductId[product.DevProductId] = product
		end
	end

	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			-- Le joueur est parti : on ne consomme pas le reçu, Roblox le
			-- represente à la prochaine connexion.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local profile = PlayerDataService.get(player)
		if not profile or not profile.Loaded then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local key = tostring(info.PurchaseId)
		if profile.Receipts[key] then
			-- Déjà accordé : on confirme sans redonner.
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local product = byProductId[info.ProductId]
		if not product then
			warn("[Monetization] produit inconnu : " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if not grantProduct(player, product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		profile.Receipts[key] = true
		PlayerDataService.markDirty(player)
		-- La sauvegarde doit réussir AVANT de confirmer : sinon un crash juste
		-- après ferait perdre l'achat au joueur.
		local saved = PlayerDataService.save(player, true)
		if not saved then
			profile.Receipts[key] = nil
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

function MonetizationService.prompt(player: Player, productKey: string)
	for _, product in ipairs(GameConfig.Monetization.Products) do
		if product.Id == productKey and product.DevProductId > 0 then
			MarketplaceService:PromptProductPurchase(player, product.DevProductId)
			return true
		end
	end
	for _, pass in ipairs(GameConfig.Monetization.Passes) do
		if pass.Id == productKey and pass.GamePassId > 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
			return true
		end
	end
	return false
end

return MonetizationService
