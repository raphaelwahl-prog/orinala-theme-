--!strict
-- Les skins. Achetés avec l'argent du jeu ou gagnés en jouant, jamais les
-- deux : un skin qu'on ne peut pas acheter vaut plus qu'un skin à 299 Robux.

local CosmeticConfig = require(script.Parent.Parent.Shared.CosmeticConfig)
local EconomyService = require(script.Parent.EconomyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CosmeticService = {}

local function statsOf(profile)
	return {
		Nights = profile.NightsSurvived,
		Zones = profile.Zones,
		Achievements = profile.Achievements,
	}
end

function CosmeticService.catalogue(player: Player)
	local profile = PlayerDataService.get(player)
	local out = {}
	if not profile then
		return out
	end
	for _, item in ipairs(CosmeticConfig.List) do
		local unlocked, reason = CosmeticConfig.check(item, statsOf(profile))
		table.insert(out, {
			Id = item.Id, Name = item.Name, Desc = item.Desc, Price = item.Price,
			Owned = profile.Cosmetics[item.Id] == true or item.Id == "default",
			Unlockable = unlocked, Reason = reason,
			Equipped = profile.Skin == item.Id,
		})
	end
	return out
end

-- Acheter ou réclamer. Un skin gratuit « à condition » se réclame une fois la
-- condition remplie ; il n'est jamais achetable.
function CosmeticService.obtain(player: Player, id: string): (boolean, string)
	local profile = PlayerDataService.get(player)
	local item = CosmeticConfig.get(id)
	if not profile or not item then
		return false, "Skin inconnu."
	end
	if profile.Cosmetics[id] then
		return false, "Tu l'as déjà."
	end
	local unlocked, reason = CosmeticConfig.check(item, statsOf(profile))
	if not unlocked then
		return false, "Il te faut " .. reason .. "."
	end
	if item.Price > 0 then
		if not EconomyService.spend(player, item.Price) then
			return false, "Pas assez d'argent sécurisé."
		end
	end
	profile.Cosmetics[id] = true
	PlayerDataService.markDirty(player)
	return true, item.Name .. " débloqué."
end

function CosmeticService.equip(player: Player, id: string): (boolean, string)
	local profile = PlayerDataService.get(player)
	local item = CosmeticConfig.get(id)
	if not profile or not item then
		return false, "Skin inconnu."
	end
	if id ~= "default" and not profile.Cosmetics[id] then
		return false, "Tu ne l'as pas."
	end
	profile.Skin = id
	PlayerDataService.markDirty(player)
	CosmeticService.apply(player)
	return true, item.Name .. " équipé."
end

-- Applique les couleurs au personnage. Pas d'accessoire à charger : un skin
-- qui dépend d'un asset du catalogue Roblox casse le jour où l'asset est
-- modéré, et on ne s'en aperçoit jamais tout de suite.
function CosmeticService.apply(player: Player)
	local profile = PlayerDataService.get(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local item = CosmeticConfig.get(profile.Skin or "default")
	if not item then
		return
	end
	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		colors = Instance.new("BodyColors")
		colors.Parent = character
	end
	colors.TorsoColor3 = item.Shirt
	colors.LeftArmColor3 = item.Shirt
	colors.RightArmColor3 = item.Shirt
	colors.LeftLegColor3 = item.Pants
	colors.RightLegColor3 = item.Pants
	colors.HeadColor3 = item.Head
end

return CosmeticService
