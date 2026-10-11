--[[
	ShopUI — la boutique.

	Elle n'affiche que ce que le serveur lui envoie (prix et niveaux déjà
	calculés). Le client ne décide rien : il envoie juste "je veux l'objet
	earplugs" et il attend la réponse. C'est ce qui rend la triche inutile.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local UiKit = require(script.Parent.UiKit)
local new = UiKit.new
local Colors = UiKit.Colors

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local ShopUI = {}

local player = Players.LocalPlayer
local frame: Frame
local list: ScrollingFrame
local cashLabel: TextLabel
local currentCash = 0

-- ─── construction ───────────────────────────────────────────────────────────

function ShopUI.build(gui: ScreenGui)
	frame = new("Frame", {
		Name = "Shop",
		Parent = gui,
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 520),
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
		TextColor3 = Colors.Text,
		Text = "Boutique",
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
		Text = "0 $ en banque",
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
		AutoButtonColor = true,
	}, { UiKit.corner(8) }) :: TextButton
	close.Activated:Connect(function()
		ShopUI.setVisible(false)
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

-- ─── lignes ─────────────────────────────────────────────────────────────────

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

local function itemRow(entry, order: number)
	local row = new("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 84),
		BackgroundColor3 = Colors.PanelLight,
		BorderSizePixel = 0,
	}, { UiKit.corner(10), UiKit.padding(12) })

	local levelText = ""
	if entry.MaxLevel > 1 then
		levelText = ("   ·   niveau %d/%d"):format(entry.Owned, entry.MaxLevel)
	elseif entry.Owned > 0 then
		levelText = "   ·   possédé"
	end

	new("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -120, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Text,
		Text = entry.Name .. levelText,
	})

	new("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -120, 0, 38),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = Colors.Muted,
		Text = entry.Desc,
	})

	local affordable = entry.CanBuy and currentCash >= entry.Price
	local button = new("TextButton", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(104, 38),
		BackgroundColor3 = entry.CanBuy and (affordable and Colors.Accent or Colors.Panel) or Colors.Panel,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = affordable and Color3.new(1, 1, 1) or Colors.Muted,
		Text = entry.CanBuy and UiKit.money(entry.Price) or "MAX",
		AutoButtonColor = entry.CanBuy,
	}, { UiKit.corner(8) }) :: TextButton

	if entry.CanBuy then
		button.Activated:Connect(function()
			;(Net.get("RequestBuy") :: RemoteEvent):FireServer(entry.Id)
		end)
	end
end

local function robuxRow(entry, order: number)
	local row = new("Frame", {
		Parent = list,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 76),
		BackgroundColor3 = Colors.PanelLight,
		BorderSizePixel = 0,
	}, { UiKit.corner(10), UiKit.padding(12) })

	new("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -120, 0, 20),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Unlock,
		Text = entry.Name,
	})

	new("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.new(1, -120, 0, 30),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = Colors.Muted,
		Text = entry.Desc,
	})

	local button = new("TextButton", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(104, 38),
		BackgroundColor3 = entry.Owned and Colors.Panel or Colors.Unlock,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = entry.Owned and Colors.Muted or Color3.new(1, 1, 1),
		Text = entry.Owned and "ACTIF" or "ROBUX",
		AutoButtonColor = not entry.Owned,
	}, { UiKit.corner(8) }) :: TextButton

	if not entry.Owned then
		button.Activated:Connect(function()
			if entry.Kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(player, entry.Id)
			else
				MarketplaceService:PromptProductPurchase(player, entry.Id)
			end
		end)
	end
end

-- ─── rendu ──────────────────────────────────────────────────────────────────

function ShopUI.render(catalog)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local order = 0
	sectionTitle("Équipement", order)
	order += 1
	for _, entry in ipairs(catalog.Items or {}) do
		order += 1
		itemRow(entry, order)
	end

	if catalog.Robux and #catalog.Robux > 0 then
		order += 1
		sectionTitle("Robux", order)
		for _, entry in ipairs(catalog.Robux) do
			order += 1
			robuxRow(entry, order)
		end
	end
end

function ShopUI.setCash(amount: number)
	currentCash = amount
	if cashLabel then
		cashLabel.Text = ("%s en banque"):format(UiKit.money(amount))
	end
end

function ShopUI.setVisible(visible: boolean)
	frame.Visible = visible
end

function ShopUI.isVisible(): boolean
	return frame.Visible
end

function ShopUI.refreshFromServer()
	local ok, catalog = pcall(function()
		return (Net.get("GetCatalog") :: RemoteFunction):InvokeServer()
	end)
	if ok and type(catalog) == "table" then
		ShopUI.render(catalog)
	end
end

return ShopUI
