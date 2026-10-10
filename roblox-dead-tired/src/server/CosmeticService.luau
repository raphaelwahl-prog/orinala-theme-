--[[
	CosmeticService — achat, équipement et application des skins.

	Les cosmétiques sont appliqués CÔTÉ SERVEUR, sur le personnage lui-même.
	C'est important : un skin que seul son propriétaire voit ne sert à rien.
	Tout l'intérêt est que les autres joueurs le voient — c'est du statut, et
	le statut n'existe que s'il est public.

	Comme pour la boutique d'équipement, le client n'envoie qu'un identifiant.
	Prix, conditions et possession sont vérifiés ici.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CosmeticCatalog = require(Shared.CosmeticCatalog)
local Net = require(Shared.Net)

local CosmeticService = {}

local services

function CosmeticService.init(registry)
	services = registry
end

-- ─── accès au profil ────────────────────────────────────────────────────────

local function store(player: Player)
	local profile = services.Data.get(player)
	if not profile then
		return nil
	end
	profile.Cosmetics = profile.Cosmetics or { Owned = {}, Equipped = {} }
	profile.Cosmetics.Owned = profile.Cosmetics.Owned or {}
	profile.Cosmetics.Equipped = profile.Cosmetics.Equipped or {}

	-- Les gratuits sont possédés d'office, et équipés si rien ne l'est.
	for slot, id in pairs(CosmeticCatalog.Defaults) do
		profile.Cosmetics.Owned[id] = true
		if not profile.Cosmetics.Equipped[slot] then
			profile.Cosmetics.Equipped[slot] = id
		end
	end
	return profile.Cosmetics
end

local function statsOf(player: Player)
	local profile = services.Data.get(player)
	return {
		TotalBanked = profile and profile.TotalBanked or 0,
		DeepestTier = profile and profile.DeepestTier or 1,
		NightsSurvived = profile and profile.NightsSurvived or 0,
	}
end

function CosmeticService.getEquipped(player: Player, slot: string): string?
	local data = store(player)
	return data and data.Equipped[slot] or nil
end

function CosmeticService.equippedItem(player: Player, slot: string)
	local id = CosmeticService.getEquipped(player, slot)
	return id and CosmeticCatalog.ById[id] or nil
end

-- ─── application visuelle ───────────────────────────────────────────────────

local function clearEffects(character: Model)
	for _, name in ipairs({ "CosmeticAura", "CosmeticTitle" }) do
		local existing = character:FindFirstChild(name, true)
		if existing then
			existing:Destroy()
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, child in ipairs(root:GetChildren()) do
			if child:IsA("Trail") or child:IsA("Attachment") and child.Name:match("^Cosmetic") then
				child:Destroy()
			end
		end
	end
end

local function applySkin(character: Model, item)
	if not item then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Color = item.Color or descendant.Color
			if item.Material then
				descendant.Material = item.Material
			end
			-- La tête garde son visage : on ne la rend pas transparente.
			if item.Transparency and descendant.Name ~= "Head" then
				descendant.Transparency = item.Transparency
			end
		end
	end
end

local function applyTrail(character: Model, item)
	if not item then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local top = Instance.new("Attachment")
	top.Name = "CosmeticTrailTop"
	top.Position = Vector3.new(0, 1.2, 0)
	top.Parent = root

	local bottom = Instance.new("Attachment")
	bottom.Name = "CosmeticTrailBottom"
	bottom.Position = Vector3.new(0, -1.2, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "CosmeticTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.55
	trail.MinLength = 0.1
	trail.LightEmission = 0.4
	trail.Color = ColorSequence.new(item.Color or Color3.new(1, 1, 1), item.Color2 or item.Color or Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = root
end

local function applyAura(character: Model, item)
	if not item then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "CosmeticAura"
	light.Color = item.Color or Color3.new(1, 1, 1)
	light.Range = item.LightRange or 14
	light.Brightness = 1.4
	light.Parent = root
end

local function applyTitle(character: Model, item)
	if not item or not item.Text then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CosmeticTitle"
	gui.Size = UDim2.fromScale(10, 1.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 90
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = item.Color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = item.Text
	label.Parent = gui
end

--[[ Applique tout ce qui est équipé. Appelé à chaque apparition de personnage. ]]
function CosmeticService.apply(player: Player)
	local character = player.Character
	if not character then
		return
	end
	clearEffects(character)
	applySkin(character, CosmeticService.equippedItem(player, "Skin"))
	applyTrail(character, CosmeticService.equippedItem(player, "Trail"))
	applyAura(character, CosmeticService.equippedItem(player, "Aura"))
	applyTitle(character, CosmeticService.equippedItem(player, "Title"))
end

--[[ La literie s'applique à la planque pendant qu'on dort. ]]
function CosmeticService.dressSpot(player: Player, spot: BasePart)
	local item = CosmeticService.equippedItem(player, "BedSkin")
	if not item then
		return
	end
	spot:SetAttribute("OriginalColor", spot:GetAttribute("OriginalColor") or spot.Color)
	spot.Color = item.Color or spot.Color
	if item.Material then
		spot.Material = item.Material
	end
end

function CosmeticService.undressSpot(spot: BasePart)
	local original = spot:GetAttribute("OriginalColor")
	if typeof(original) == "Color3" then
		spot.Color = original
	end
	spot.Material = Enum.Material.Fabric
end

-- ─── catalogue envoyé au client ─────────────────────────────────────────────

local function buildCatalogFor(player: Player)
	local data = store(player)
	if not data then
		return { Items = {}, Equipped = {} }
	end
	local stats = statsOf(player)
	local entries = {}

	for _, item in ipairs(CosmeticCatalog.Items) do
		local ok, reason = CosmeticCatalog.meetsRequirement(item, stats)
		table.insert(entries, {
			Id = item.Id,
			Name = item.Name,
			Desc = item.Desc,
			Slot = item.Slot,
			Price = item.Price,
			Order = item.Order,
			Owned = data.Owned[item.Id] == true,
			Equipped = data.Equipped[item.Slot] == item.Id,
			Locked = not ok,
			LockReason = reason,
			Color = item.Color,
		})
	end

	table.sort(entries, function(a, b)
		return a.Order < b.Order
	end)

	return { Items = entries, Equipped = data.Equipped, Slots = CosmeticCatalog.Slots }
end

function CosmeticService.openFor(player: Player)
	;(Net.get("CosmeticResult") :: RemoteEvent):FireClient(player, {
		Action = "Open",
		Catalog = buildCatalogFor(player),
	})
end

-- ─── achat / équipement ─────────────────────────────────────────────────────

function CosmeticService.buy(player: Player, id: string): (boolean, string)
	local item = CosmeticCatalog.ById[id]
	if not item then
		return false, "Skin inconnu."
	end
	local data = store(player)
	if not data then
		return false, "Profil pas encore chargé."
	end
	if data.Owned[id] then
		return false, "Tu l'as déjà."
	end

	local ok, reason = CosmeticCatalog.meetsRequirement(item, statsOf(player))
	if not ok then
		return false, reason or "Conditions non remplies."
	end

	if item.Price > 0 and not services.Economy.spend(player, item.Price) then
		local profile = services.Data.get(player)
		return false, ("Il te manque %d $."):format(item.Price - (profile and profile.Cash or 0))
	end

	data.Owned[id] = true
	data.Equipped[item.Slot] = id
	CosmeticService.apply(player)
	services.Economy.push(player)
	services.Data.save(player)
	return true, ("%s débloqué et équipé."):format(item.Name)
end

function CosmeticService.equip(player: Player, id: string): (boolean, string)
	local item = CosmeticCatalog.ById[id]
	if not item then
		return false, "Skin inconnu."
	end
	local data = store(player)
	if not data or not data.Owned[id] then
		return false, "Tu ne possèdes pas ce skin."
	end
	data.Equipped[item.Slot] = id
	CosmeticService.apply(player)
	services.Economy.push(player)
	services.Data.save(player)
	return true, ("%s équipé."):format(item.Name)
end

function CosmeticService.start()
	;(Net.get("RequestCosmetic") :: RemoteEvent).OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" then
			return
		end
		local action, id = payload.action, payload.id
		if type(action) ~= "string" or type(id) ~= "string" then
			return
		end

		-- "open" : le client demande juste le catalogue (touche N).
		if action == "open" then
			CosmeticService.openFor(player)
			return
		end

		local ok, message
		if action == "buy" then
			ok, message = CosmeticService.buy(player, id)
		elseif action == "equip" then
			ok, message = CosmeticService.equip(player, id)
		else
			return
		end

		;(Net.get("CosmeticResult") :: RemoteEvent):FireClient(player, {
			Action = action,
			Success = ok,
			Message = message,
			Catalog = buildCatalogFor(player),
		})
		services.Notify.send(player, message, ok and "unlock" or "info")
	end)
end

return CosmeticService
