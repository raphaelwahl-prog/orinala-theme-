--!strict
-- §4 — refuges : réservation, défenses, contestation.
--
-- Les refuges sont des modèles du Workspace marqués par l'attribut `Zone` et
-- le tag `Shelter`. Un refuge a au plus UN propriétaire à la fois (CDC §15).
--
-- Anti-harcèlement (CDC §4) : un joueur qui perd son refuge reçoit un bouclier
-- temporaire ; pendant ce délai, le joueur qui le lui a pris ne peut pas lui
-- reprendre un autre refuge. On empêche le ciblage répété sans empêcher la
-- contestation en général.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local ItemConfig = require(script.Parent.Parent.Shared.ItemConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ShelterService = {}

export type Shelter = {
	Model: Model,
	Id: string,
	ZoneId: string,
	Owner: Player?,
	ClaimedAt: number,
	LastSeen: number,          -- dernier instant où le propriétaire était présent
	Placed: { [string]: number },
	Wear: { [string]: number },  -- usure par objet posé
	Occupied: boolean,           -- une session de survie est en cours
	DisabledUntil: number?,      -- défenses neutralisées (couvent)
}

local shelters: { [string]: Shelter } = {}
local lastClaim: { [Player]: number } = {}
local shieldUntil: { [Player]: number } = {}
local shieldFrom: { [Player]: Player } = {}
local listeners: { (Shelter) -> () } = {}

function ShelterService.onChanged(fn: (Shelter) -> ())
	table.insert(listeners, fn)
end

local function fire(shelter: Shelter)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, shelter)
	end
end

function ShelterService.register(model: Model)
	local id = model:GetAttribute("ShelterId")
	if type(id) ~= "string" then
		id = model:GetFullName()
		model:SetAttribute("ShelterId", id)
	end
	local zoneId = model:GetAttribute("Zone")
	if type(zoneId) ~= "string" then
		zoneId = "street"
		model:SetAttribute("Zone", zoneId)
	end
	shelters[id] = {
		Model = model, Id = id, ZoneId = zoneId,
		Owner = nil, ClaimedAt = 0, LastSeen = 0,
		Placed = {}, Wear = {}, Occupied = false, DisabledUntil = nil,
	}
	model:SetAttribute("OwnerName", "")
end

function ShelterService.init()
	for _, model in ipairs(CollectionService:GetTagged("Shelter")) do
		if model:IsA("Model") then
			ShelterService.register(model)
		end
	end
	CollectionService:GetInstanceAddedSignal("Shelter"):Connect(function(instance)
		if instance:IsA("Model") then
			ShelterService.register(instance)
		end
	end)
end

function ShelterService.get(id: string): Shelter?
	return shelters[id]
end

function ShelterService.all(): { [string]: Shelter }
	return shelters
end

function ShelterService.ownedBy(player: Player): Shelter?
	for _, shelter in pairs(shelters) do
		if shelter.Owner == player then
			return shelter
		end
	end
	return nil
end

local function release(shelter: Shelter, reason: string)
	local previous = shelter.Owner
	shelter.Owner = nil
	shelter.ClaimedAt = 0
	shelter.Occupied = false
	shelter.Model:SetAttribute("OwnerName", "")
	if previous and reason == "contested" then
		shieldUntil[previous] = os.clock() + GameConfig.Shelter.HarassmentShieldSeconds
	end
	fire(shelter)
end

-- Un refuge est contestable si personne ne l'occupe, ou si son propriétaire
-- est parti / mort / absent depuis AbandonSeconds.
function ShelterService.isContestable(shelter: Shelter): boolean
	if not shelter.Owner then
		return true
	end
	if not shelter.Owner.Parent then
		return true
	end
	local character = shelter.Owner.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return true
	end
	if shelter.Occupied then
		return false
	end
	return os.clock() - shelter.LastSeen > GameConfig.Shelter.AbandonSeconds
end

-- Renvoie (succès, raison).
function ShelterService.claim(player: Player, id: string): (boolean, string)
	local shelter = shelters[id]
	if not shelter then
		return false, "Ce refuge n'existe pas."
	end
	if shelter.Owner == player then
		return true, "Tu l'as déjà."
	end

	local last = lastClaim[player]
	if last and os.clock() - last < GameConfig.Shelter.ClaimCooldownSeconds then
		local left = GameConfig.Shelter.ClaimCooldownSeconds - (os.clock() - last)
		return false, string.format("Attends %.0f s avant de réserver un autre refuge.", left)
	end

	if shelter.Owner and not ShelterService.isContestable(shelter) then
		return false, "Quelqu'un dort ici."
	end

	-- Anti-harcèlement : si le propriétaire actuel est protégé contre CE joueur.
	local current = shelter.Owner
	if current and shieldUntil[current] and os.clock() < shieldUntil[current]
		and shieldFrom[current] == player then
		return false, "Laisse-le tranquille un moment."
	end

	-- Le joueur ne garde qu'un refuge à la fois.
	local existing = ShelterService.ownedBy(player)
	if existing and existing.Id ~= id then
		release(existing, "moved")
	end

	if current then
		shieldFrom[current] = player
		release(shelter, "contested")
	end

	shelter.Owner = player
	shelter.ClaimedAt = os.clock()
	shelter.LastSeen = os.clock()
	shelter.Model:SetAttribute("OwnerName", player.Name)
	lastClaim[player] = os.clock()

	-- Les défenses posées suivent le joueur : on recharge les siennes.
	local profile = PlayerDataService.get(player)
	shelter.Placed = {}
	shelter.Wear = {}
	if profile then
		for itemId, count in pairs(profile.Placed) do
			shelter.Placed[itemId] = count
		end
	end

	fire(shelter)
	return true, "Refuge réservé."
end

function ShelterService.abandon(player: Player)
	local shelter = ShelterService.ownedBy(player)
	if shelter then
		release(shelter, "left")
	end
end

function ShelterService.touch(player: Player)
	local shelter = ShelterService.ownedBy(player)
	if shelter then
		shelter.LastSeen = os.clock()
	end
end

function ShelterService.setOccupied(player: Player, occupied: boolean)
	local shelter = ShelterService.ownedBy(player)
	if shelter then
		shelter.Occupied = occupied
		shelter.LastSeen = os.clock()
		fire(shelter)
	end
end

-- Pose une défense. Les emplacements sont limités : aucun refuge n'est
-- imprenable (CDC §4).
function ShelterService.place(player: Player, itemId: string): (boolean, string)
	local shelter = ShelterService.ownedBy(player)
	if not shelter then
		return false, "Réserve d'abord un refuge."
	end
	local profile = PlayerDataService.get(player)
	local item = ItemConfig.get(itemId)
	if not profile or not item or item.Kind ~= "defense" then
		return false, "Objet inconnu."
	end
	local owned = profile.Inventory[itemId] or 0
	local placed = shelter.Placed[itemId] or 0
	if owned <= placed then
		return false, "Tu n'en as pas d'autre."
	end

	local profileAfter = {}
	for id, count in pairs(shelter.Placed) do
		profileAfter[id] = count
	end
	profileAfter[itemId] = placed + 1
	local used = ItemConfig.defenseProfile(profileAfter).Slots
	if used > GameConfig.Shelter.MaxSlots then
		return false, string.format("Plus de place : %d emplacements au maximum.",
			GameConfig.Shelter.MaxSlots)
	end

	shelter.Placed[itemId] = placed + 1
	shelter.Wear[itemId] = 0
	profile.Placed[itemId] = shelter.Placed[itemId]
	PlayerDataService.markDirty(player)
	fire(shelter)
	return true, item.Name .. " posé."
end

-- Appelé par MonsterService à chaque assaut : les défenses s'usent et
-- finissent par céder. Renvoie le délai gagné, en secondes.
function ShelterService.absorbAssault(shelter: Shelter): number
	if ShelterService.defensesDisabled(shelter) then
		return 0
	end
	local gained = 0
	for itemId, count in pairs(shelter.Placed) do
		if count > 0 then
			local item = ItemConfig.get(itemId)
			if item then
				gained += (item.DelaySeconds or 0)
				local wear = (shelter.Wear[itemId] or 0) + 1
				shelter.Wear[itemId] = wear
				if item.Durability and wear >= item.Durability then
					shelter.Placed[itemId] = count - 1
					shelter.Wear[itemId] = 0
					local owner = shelter.Owner
					if owner then
						local profile = PlayerDataService.get(owner)
						if profile then
							profile.Placed[itemId] = shelter.Placed[itemId]
							profile.Inventory[itemId] = math.max(0, (profile.Inventory[itemId] or 1) - 1)
							PlayerDataService.markDirty(owner)
						end
					end
				end
			end
		end
	end
	fire(shelter)
	return math.min(gained, 40)
end

function ShelterService.profileOf(shelter: Shelter)
	if shelter.DisabledUntil and os.clock() < shelter.DisabledUntil then
		-- Défenses neutralisées : le refuge est nu, mais pas détruit.
		return { Delay = 0, Warning = 0, Detection = 1, Slots = 0 }
	end
	return ItemConfig.defenseProfile(shelter.Placed)
end

-- Mécanique du couvent (CDC §3, zone 5) : l'entité éteint les défenses pendant
-- un temps. Rien n'est consommé, mais pendant ce temps le refuge ne retarde
-- plus rien du tout.
function ShelterService.disableDefenses(shelter: Shelter, seconds: number)
	shelter.DisabledUntil = os.clock() + seconds
	fire(shelter)
end

function ShelterService.defensesDisabled(shelter: Shelter): boolean
	return shelter.DisabledUntil ~= nil and os.clock() < shelter.DisabledUntil
end

function ShelterService.cleanup(player: Player)
	ShelterService.abandon(player)
	lastClaim[player] = nil
	shieldUntil[player] = nil
	shieldFrom[player] = nil
	for other, from in pairs(shieldFrom) do
		if from == player then
			shieldFrom[other] = nil
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	ShelterService.cleanup(player)
end)

return ShelterService
