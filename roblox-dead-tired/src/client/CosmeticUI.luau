--[[
	CosmeticUI — la boutique de skins.

	Choix d'affichage volontaire : les skins VERROUILLÉS restent visibles, avec
	leur condition écrite en clair (« il faut avoir dormi au palier 5 »).
	Cacher ce qu'on ne peut pas encore avoir, c'est se priver du seul truc qui
	donne envie de continuer à jouer. On montre la carotte.
]]

local Players = game:GetService("Players")

local UiKit = require(script.Parent.UiKit)
local new = UiKit.new
local Colors = UiKit.Colors

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local CosmeticUI = {}

local frame: Frame
local list: ScrollingFrame
local cashLabel: TextLabel
local currentCash = 0

local SLOT_LABELS = {
	Skin = "Apparence",
	Trail = "Traînée",
	Aura = "Aura",
	Title = "Titre",
	BedSkin = "Literie",
}

function CosmeticUI.build(gui: ScreenGui)
	frame = new("Frame", {
		Name = "Cosmetics",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(540, 540),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.04,
		ZIndex = 10,
	}, { UiKit.corner(14), UiKit.padding(18) }) :: Frame

	new("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 28),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Unlock,
		Text = "Skins",
	})

	cashLabel = new("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, -40, 0, 18),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Cash,
		Text = "0 $ en banque · aucun skin ne donne d'avantage",
	}) :: TextLabel

	local close = new("TextButton", {
		Parent = frame,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Colors.PanelLight,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Colors.Text,
		Text = "✕",
	}, { UiKit.corner(8) }) :: TextButton
	close.Activated:Connect(function()
		CosmeticUI.setVisible(false)
	end)

	list = new("ScrollingFrame", {
		Parent = frame,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, {
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	}) :: ScrollingFrame
end

local function sectionTitle(text: string, order: number)
	new("TextLabel", {
		Parent = list,
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = text:upper(),
	})
end

local function row(entry, order: number)
	local container = new("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 78),
		BackgroundColor3 = Colors.PanelLight,
		BorderSizePixel = 0,
	}, { UiKit.corner(10), UiKit.padding(12) })

	-- Pastille de couleur : on voit le skin avant de l'acheter.
	new("Frame", {
		Parent = container,
		Size = UDim2.fromOffset(10, 54),
		BackgroundColor3 = entry.Color or Colors.Muted,
		BorderSizePixel = 0,
	}, { UiKit.corner(5) })

	new("TextLabel", {
		Parent = container,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -140, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = entry.Locked and Colors.Muted or Colors.Text,
		Text = entry.Name,
	})

	new("TextLabel", {
		Parent = container,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 22),
		Size = UDim2.new(1, -140, 0, 34),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = entry.Locked and Colors.Danger or Colors.Muted,
		Text = entry.Locked and (entry.LockReason or "Verrouillé") or entry.Desc,
	})

	-- Un seul bouton, trois états : ÉQUIPÉ / ÉQUIPER / le prix.
	local text, color, enabled
	if entry.Equipped then
		text, color, enabled = "ÉQUIPÉ", Colors.Panel, false
	elseif entry.Owned then
		text, color, enabled = "ÉQUIPER", Colors.Accent, true
	elseif entry.Locked then
		text, color, enabled = "🔒", Colors.Panel, false
	else
		local affordable = currentCash >= entry.Price
		text = entry.Price > 0 and UiKit.money(entry.Price) or "GRATUIT"
		color = affordable and Colors.Unlock or Colors.Panel
		enabled = affordable
	end

	local button = new("TextButton", {
		Parent = container,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(106, 38),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = enabled and Color3.new(1, 1, 1) or Colors.Muted,
		Text = text,
		AutoButtonColor = enabled,
	}, { UiKit.corner(8) }) :: TextButton

	if enabled then
		button.Activated:Connect(function()
			;(Net.get("RequestCosmetic") :: RemoteEvent):FireServer({
				action = entry.Owned and "equip" or "buy",
				id = entry.Id,
			})
		end)
	end
end

function CosmeticUI.render(catalog)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local order = 0
	for _, slot in ipairs(catalog.Slots or {}) do
		local slotEntries = {}
		for _, entry in ipairs(catalog.Items or {}) do
			if entry.Slot == slot then
				table.insert(slotEntries, entry)
			end
		end
		if #slotEntries > 0 then
			order += 1
			sectionTitle(SLOT_LABELS[slot] or slot, order)
			for _, entry in ipairs(slotEntries) do
				order += 1
				row(entry, order)
			end
		end
	end
end

function CosmeticUI.setCash(amount: number)
	currentCash = amount
	if cashLabel then
		cashLabel.Text = ("%s en banque · aucun skin ne donne d'avantage"):format(UiKit.money(amount))
	end
end

function CosmeticUI.setVisible(visible: boolean)
	frame.Visible = visible
end

function CosmeticUI.isVisible(): boolean
	return frame.Visible
end

return CosmeticUI
