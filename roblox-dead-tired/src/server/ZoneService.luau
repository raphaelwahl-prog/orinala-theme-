--[[
	ZoneService — inventaire des lieux interactifs de la carte.

	Une planque, c'est juste une BasePart taguée "SleepSpot" avec un attribut
	numérique "Tier" (1 à 5). Rien d'autre. Tu peux donc dessiner ta propre carte
	dans Studio sans toucher au code : tu poses une part, tu lui mets le tag et
	l'attribut, elle est jouable.

	Tags reconnus :
	  SleepSpot     — planque. Attribut requis : Tier (nombre 1-5).
	                  Attribut optionnel : SpotLabel (texte affiché).
	  BankTerminal  — coffre : dépose l'argent que tu as sur toi.
	  ShopTerminal  — ouvre la boutique d'équipement.
	  SkinTerminal  — ouvre la boutique de skins.
	  PatrolPoint   — point de passage du monstre en patrouille.
]]

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local ZoneService = {}

local TAG_SPOT = "SleepSpot"
local TAG_BANK = "BankTerminal"
local TAG_SHOP = "ShopTerminal"
local TAG_SKIN = "SkinTerminal"
local TAG_PATROL = "PatrolPoint"

local services
local occupant: { [BasePart]: Player } = {}
local spots: { BasePart } = {}

function ZoneService.init(registry)
	services = registry
end

-- ─── lecture d'une planque ──────────────────────────────────────────────────

function ZoneService.getTier(spot: BasePart): number
	local tier = spot:GetAttribute("Tier")
	if type(tier) ~= "number" then
		return 1
	end
	return math.clamp(math.floor(tier), 1, GameConfig.MaxTier)
end

function ZoneService.getTierData(spot: BasePart)
	return GameConfig.Tiers[ZoneService.getTier(spot)]
end

function ZoneService.getLabel(spot: BasePart): string
	local label = spot:GetAttribute("SpotLabel")
	if type(label) == "string" and #label > 0 then
		return label
	end
	return ZoneService.getTierData(spot).Name
end

--[[ Est-ce une planque VIP (réservée au game pass) ? ]]
function ZoneService.isVip(spot: BasePart): boolean
	return spot:GetAttribute("Vip") == true
end

-- ─── occupation ─────────────────────────────────────────────────────────────

function ZoneService.getOccupant(spot: BasePart): Player?
	local player = occupant[spot]
	if player and not player.Parent then
		occupant[spot] = nil
		return nil
	end
	return player
end

function ZoneService.claim(spot: BasePart, player: Player): boolean
	if ZoneService.getOccupant(spot) then
		return false
	end
	occupant[spot] = player
	ZoneService.refreshPrompt(spot)
	return true
end

function ZoneService.release(spot: BasePart)
	occupant[spot] = nil
	ZoneService.refreshPrompt(spot)
end

function ZoneService.releaseAllFor(player: Player)
	for spot, holder in pairs(occupant) do
		if holder == player then
			occupant[spot] = nil
			ZoneService.refreshPrompt(spot)
		end
	end
end

function ZoneService.getSpots(): { BasePart }
	return spots
end

function ZoneService.getPatrolPoints(): { BasePart }
	local points = {}
	for _, instance in ipairs(CollectionService:GetTagged(TAG_PATROL)) do
		if instance:IsA("BasePart") then
			table.insert(points, instance)
		end
	end
	return points
end

-- ─── invites (ProximityPrompt) ──────────────────────────────────────────────

function ZoneService.refreshPrompt(spot: BasePart)
	local prompt = spot:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	local tier = ZoneService.getTierData(spot)
	local taken = ZoneService.getOccupant(spot) ~= nil
	prompt.ActionText = taken and "Occupée" or "Dormir"
	prompt.ObjectText = ("%s — %d $/s · %s"):format(ZoneService.getLabel(spot), tier.Rate, tier.RiskLabel)
	prompt.Enabled = not taken
end

local function attachSpot(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	if table.find(spots, instance) then
		return
	end
	table.insert(spots, instance)

	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = instance
	end

	prompt.Triggered:Connect(function(player)
		services.Sleep.tryStart(player, instance)
	end)

	ZoneService.refreshPrompt(instance)
end

local function attachBank(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Déposer"
		prompt.ObjectText = "Coffre"
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = instance
	end
	prompt.Triggered:Connect(function(player)
		services.Economy.requestBank(player)
	end)
end

local function attachShop(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ouvrir"
		prompt.ObjectText = "Boutique"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = instance
	end
	prompt.Triggered:Connect(function(player)
		services.Shop.openFor(player)
	end)
end

local function attachSkinShop(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Ouvrir"
		prompt.ObjectText = "Skins"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = instance
	end
	prompt.Triggered:Connect(function(player)
		services.Cosmetic.openFor(player)
	end)
end

function ZoneService.start()
	for _, instance in ipairs(CollectionService:GetTagged(TAG_SPOT)) do
		attachSpot(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG_SPOT):Connect(attachSpot)

	for _, instance in ipairs(CollectionService:GetTagged(TAG_BANK)) do
		attachBank(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG_BANK):Connect(attachBank)

	for _, instance in ipairs(CollectionService:GetTagged(TAG_SHOP)) do
		attachShop(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG_SHOP):Connect(attachShop)

	for _, instance in ipairs(CollectionService:GetTagged(TAG_SKIN)) do
		attachSkinShop(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG_SKIN):Connect(attachSkinShop)

	CollectionService:GetInstanceRemovedSignal(TAG_SPOT):Connect(function(instance)
		local index = table.find(spots, instance)
		if index then
			table.remove(spots, index)
		end
		occupant[instance :: BasePart] = nil
	end)

	if #spots == 0 then
		warn("[ZoneService] aucune planque taguée \"SleepSpot\" trouvée. "
			.. "Vérifie que MapBuilder est activé ou que ta carte a les tags.")
	end
end

return ZoneService
