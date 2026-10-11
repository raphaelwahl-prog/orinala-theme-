--[[
	ProgressionService — paliers d'ouverture des planques.

	La progression est volontairement basée sur le TOTAL DÉPOSÉ À VIE
	(TotalBanked), pas sur l'argent en banque. Sinon il suffirait de dépenser
	son argent pour perdre l'accès aux planques profondes, ce qui serait absurde.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local ProgressionService = {}

local services
local announced: { [Player]: { [number]: boolean } } = {}

function ProgressionService.init(registry)
	services = registry
end

function ProgressionService.onPlayerAdded(player: Player)
	announced[player] = {}
end

function ProgressionService.onPlayerRemoving(player: Player)
	announced[player] = nil
end

--[[ Palier maximum accessible au joueur. ]]
function ProgressionService.maxTier(player: Player): number
	local profile = services.Data.get(player)
	local total = profile and profile.TotalBanked or 0
	local best = 1
	for tier = 1, GameConfig.MaxTier do
		if total >= GameConfig.Tiers[tier].UnlockTotal then
			best = tier
		end
	end
	return best
end

function ProgressionService.canUse(player: Player, tier: number): (boolean, string?)
	if tier <= ProgressionService.maxTier(player) then
		return true, nil
	end
	local needed = GameConfig.Tiers[tier].UnlockTotal
	return false, ("Il te faut %d $ déposés au total pour dormir ici."):format(needed)
end

--[[ Annonce les paliers franchis depuis le dernier appel. ]]
function ProgressionService.check(player: Player)
	local profile = services.Data.get(player)
	if not profile then
		return
	end
	local seen = announced[player]
	if not seen then
		return
	end
	for index, milestone in ipairs(GameConfig.Progression.Milestones) do
		if profile.TotalBanked >= milestone.Total and not seen[index] then
			seen[index] = true
			services.Notify.send(player, milestone.Message, "unlock")
		end
	end
end

return ProgressionService
