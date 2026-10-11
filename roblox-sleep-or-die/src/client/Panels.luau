--!strict
-- Boutique, défenses, missions, carte, skins, événement, classements,
-- paramètres et écran de mort (§9).
-- Un seul panneau est ouvert à la fois ; il se ferme avec Échap.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local Panels = {}

local INK = Color3.fromRGB(236, 237, 240)
local DIM = Color3.fromRGB(150, 152, 162)
local BACK = Color3.fromRGB(10, 10, 14)
local CARD = Color3.fromRGB(18, 18, 24)
local ROW = Color3.fromRGB(26, 26, 34)
local CASH = Color3.fromRGB(110, 226, 150)
local DANGER = Color3.fromRGB(255, 86, 72)

local gui: ScreenGui
local overlay: Frame
local card: ScrollingFrame
local titleLabel: TextLabel
local current: string? = nil
local onBuy: ((string) -> ())? = nil
local onPlace: ((string) -> ())? = nil
local onCosmetic: ((string, string) -> ())? = nil
local onSetting: ((string, boolean) -> ())? = nil
local onEventClaim: (() -> ())? = nil

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function clear()
	for _, child in ipairs(card:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

function Panels.build(screen: ScreenGui, callbacks: {
	buy: (string) -> (), place: (string) -> (), cosmetic: (string, string) -> (),
	setting: (string, boolean) -> (), eventClaim: () -> () })
	gui = screen
	onBuy = callbacks.buy
	onPlace = callbacks.place
	onCosmetic = callbacks.cosmetic
	onSetting = callbacks.setting
	onEventClaim = callbacks.eventClaim

	overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = BACK
	overlay.BackgroundTransparency = 0.15
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 5
	overlay.Parent = gui

	local box = Instance.new("Frame")
	box.Size = UDim2.new(0.5, 0, 0.7, 0)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.BackgroundColor3 = CARD
	box.BorderSizePixel = 0
	box.ZIndex = 6
	corner(box, 14)
	box.Parent = overlay

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(280, 300)
	constraint.MaxSize = Vector2.new(560, 720)
	constraint.Parent = box

	titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -28, 0, 40)
	titleLabel.Position = UDim2.new(0, 18, 0, 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = INK
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 7
	titleLabel.Parent = box

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 34, 0, 34)
	close.Position = UDim2.new(1, -44, 0, 12)
	close.BackgroundColor3 = ROW
	close.Text = "✕"
	close.TextColor3 = INK
	close.Font = Enum.Font.GothamBold
	close.TextSize = 16
	close.ZIndex = 7
	corner(close, 8)
	close.Parent = box
	close.Activated:Connect(function()
		Panels.close()
	end)

	card = Instance.new("ScrollingFrame")
	card.Size = UDim2.new(1, -28, 1, -70)
	card.Position = UDim2.new(0, 14, 0, 56)
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ScrollBarThickness = 4
	card.AutomaticCanvasSize = Enum.AutomaticSize.Y
	card.CanvasSize = UDim2.new()
	card.ZIndex = 7
	card.Parent = box

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card
end

local function row(height: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, height)
	frame.BackgroundColor3 = ROW
	frame.BorderSizePixel = 0
	frame.ZIndex = 7
	corner(frame, 9)
	frame.Parent = card
	return frame
end

local function text(parent: Instance, content: string, size: number, color: Color3,
	position: UDim2, width: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = content
	l.TextSize = size
	l.TextColor3 = color
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Position = position
	l.Size = width or UDim2.new(1, -120, 0, size + 6)
	l.ZIndex = 8
	l.Parent = parent
	return l
end

local function button(parent: Instance, content: string, enabled: boolean): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 104, 0, 32)
	b.Position = UDim2.new(1, -112, 0.5, -16)
	b.BackgroundColor3 = enabled and INK or Color3.fromRGB(44, 44, 52)
	b.TextColor3 = enabled and Color3.fromRGB(12, 12, 16) or DIM
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = content
	b.AutoButtonColor = enabled
	b.Active = enabled
	b.ZIndex = 8
	corner(b, 8)
	b.Parent = parent
	return b
end

function Panels.openShop(state)
	current = "shop"
	titleLabel.Text = "Boutique  ·  " .. Format.money(state.Cash)
	clear()
	for _, item in ipairs(state.Shop) do
		local frame = row(66)
		text(frame, item.Name, 14, INK, UDim2.new(0, 12, 0, 8)).Font = Enum.Font.GothamBold
		text(frame, item.Desc, 11.5, DIM, UDim2.new(0, 12, 0, 28))
		text(frame, (item.Owned > 0 and ("possédé x" .. item.Owned .. "  ·  ") or "")
			.. item.Zone, 10.5, Color3.fromRGB(120, 122, 134), UDim2.new(0, 12, 0, 46))

		local affordable = item.Available and state.Cash >= item.Price
		local b = button(frame, item.Available and Format.money(item.Price) or "verrouillé", affordable)
		if affordable and onBuy then
			b.Activated:Connect(function()
				(onBuy :: any)(item.Id)
			end)
		end
	end
	overlay.Visible = true
end

function Panels.openDefenses(state)
	current = "defenses"
	titleLabel.Text = "Défenses du refuge"
	clear()
	local any = false
	for _, item in ipairs(state.Shop) do
		local owned = state.Inventory[item.Id] or 0
		if item.Kind == "defense" and owned > 0 then
			any = true
			local placed = state.Placed[item.Id] or 0
			local frame = row(58)
			text(frame, item.Name, 14, INK, UDim2.new(0, 12, 0, 8)).Font = Enum.Font.GothamBold
			text(frame, ("posées %d / %d possédées"):format(placed, owned), 11.5, DIM,
				UDim2.new(0, 12, 0, 30))
			local b = button(frame, "Poser", placed < owned)
			if placed < owned and onPlace then
				b.Activated:Connect(function()
					(onPlace :: any)(item.Id)
				end)
			end
		end
	end
	if not any then
		local frame = row(54)
		text(frame, "Aucune défense en stock. Passe à la boutique.", 13, DIM,
			UDim2.new(0, 12, 0, 16), UDim2.new(1, -24, 0, 30))
	end
	overlay.Visible = true
end

function Panels.openMissions(state)
	current = "missions"
	titleLabel.Text = "Missions"
	clear()
	local order = { main = 1, side = 2, daily = 3, weekly = 4 }
	local sorted = table.clone(state.Missions)
	table.sort(sorted, function(a, b)
		if a.Done ~= b.Done then
			return not a.Done
		end
		return (order[a.Kind] or 9) < (order[b.Kind] or 9)
	end)
	for _, mission in ipairs(sorted) do
		local frame = row(64)
		local kindText = ({ main = "PRINCIPALE", side = "SECONDAIRE",
			daily = "QUOTIDIENNE", weekly = "HEBDOMADAIRE" })[mission.Kind] or ""
		text(frame, kindText, 9.5, Color3.fromRGB(120, 122, 134), UDim2.new(0, 12, 0, 6))
		text(frame, mission.Name, 14, mission.Done and DIM or INK,
			UDim2.new(0, 12, 0, 20)).Font = Enum.Font.GothamBold
		text(frame, mission.Text, 11, DIM, UDim2.new(0, 12, 0, 40))
		local status = mission.Done and "terminée"
			or (mission.Progress .. " / " .. mission.Target)
		local b = button(frame, status, false)
		b.TextColor3 = mission.Done and CASH or DIM
	end
	overlay.Visible = true
end

function Panels.openZones(state)
	current = "zones"
	titleLabel.Text = "Les sept zones"
	clear()
	for _, zone in ipairs(state.Zones) do
		local frame = row(72)
		text(frame, zone.Order .. ". " .. zone.Name, 14,
			zone.Unlocked and INK or DIM, UDim2.new(0, 12, 0, 8)).Font = Enum.Font.GothamBold
		text(frame, Format.rate(zone.Rate) .. "  ·  " .. zone.Mechanic, 11, DIM,
			UDim2.new(0, 12, 0, 28))
		text(frame, zone.Unlocked and zone.Blurb or ("Verrouillée — " .. zone.Reason),
			10.5, zone.Unlocked and Color3.fromRGB(120, 122, 134) or DANGER,
			UDim2.new(0, 12, 0, 48))
	end
	overlay.Visible = true
end

function Panels.openCosmetics(state)
	current = "cosmetics"
	titleLabel.Text = "Skins  ·  " .. Format.money(state.Cash)
	clear()
	for _, item in ipairs(state.Cosmetics or {}) do
		local frame = row(64)
		text(frame, item.Name, 14, item.Owned and INK or DIM,
			UDim2.new(0, 12, 0, 8)).Font = Enum.Font.GothamBold
		text(frame, item.Desc, 11.5, DIM, UDim2.new(0, 12, 0, 28))
		if not item.Owned and not item.Unlockable then
			text(frame, "Il te faut " .. item.Reason .. ".", 10.5, DANGER,
				UDim2.new(0, 12, 0, 46))
		end

		local labelText, enabled, action
		if item.Equipped then
			labelText, enabled, action = "équipé", false, nil
		elseif item.Owned then
			labelText, enabled, action = "Équiper", true, "equip"
		elseif not item.Unlockable then
			labelText, enabled, action = "verrouillé", false, nil
		elseif item.Price > 0 then
			labelText = Format.money(item.Price)
			enabled = state.Cash >= item.Price
			action = "buy"
		else
			labelText, enabled, action = "Réclamer", true, "buy"
		end

		local b = button(frame, labelText, enabled)
		if enabled and action and onCosmetic then
			b.Activated:Connect(function()
				(onCosmetic :: any)(action, item.Id)
			end)
		end
	end
	overlay.Visible = true
end

-- ── le menu (§9, contrainte mobile) ──────────────────────────────────────
-- Sur ordinateur, les trois écrans ajoutés s'ouvrent à la touche (V, L, P).
-- Sur téléphone, chaque action liée par `ContextActionService` fabrique un
-- bouton tactile : trois de plus en auraient fait NEUF empilés dans un coin de
-- l'écran. Le CDC demande une interface « lisible sur ordinateur et mobile ».
-- Donc un seul bouton tactile, « MENU », qui mène aux trois.
function Panels.openMenu(entries: { { Name: string, Desc: string, Open: () -> () } })
	current = "menu"
	titleLabel.Text = "Menu"
	clear()
	for _, entry in ipairs(entries) do
		local frame = row(56)
		text(frame, entry.Name, 13.5, INK, UDim2.new(0, 12, 0, 8),
			UDim2.new(1, -130, 0, 20)).Font = Enum.Font.GothamBold
		text(frame, entry.Desc, 11, DIM, UDim2.new(0, 12, 0, 30), UDim2.new(1, -130, 0, 20))
		local b = button(frame, "Ouvrir", true)
		b.Activated:Connect(entry.Open)
	end
	overlay.Visible = true
end

-- ── l'événement en cours (§13) ────────────────────────────────────────────
function Panels.openEvent(state)
	current = "event"
	titleLabel.Text = "Événement"
	clear()

	local active = state.Event
	if not active then
		local frame = row(54)
		text(frame, "Aucun événement en cours.", 13, DIM,
			UDim2.new(0, 12, 0, 16), UDim2.new(1, -24, 0, 30))
		overlay.Visible = true
		return
	end

	local head = row(96)
	text(head, active.Name, 16, INK, UDim2.new(0, 12, 0, 10),
		UDim2.new(1, -24, 0, 22)).Font = Enum.Font.GothamBold
	text(head, active.Text, 11.5, DIM, UDim2.new(0, 12, 0, 34), UDim2.new(1, -24, 0, 34))
	local scope = active.Zone == "any" and "toutes les zones" or ("zone : " .. active.Zone)
	text(head, ("gains x%.2f  ·  %s"):format(active.RewardMultiplier, scope), 11,
		CASH, UDim2.new(0, 12, 0, 70), UDim2.new(1, -24, 0, 20))

	-- Ce que l'événement change réellement, dit sans détour.
	local effects = {}
	if active.MonsterMultiplier > 1 then
		table.insert(effects, ("%.0f%% de monstres en plus")
			:format((active.MonsterMultiplier - 1) * 100))
	end
	if active.MonsterSpeed > 1 then
		table.insert(effects, ("monstres %.0f%% plus rapides")
			:format((active.MonsterSpeed - 1) * 100))
	end
	if active.MiniBoss then
		table.insert(effects, "un mini-boss rôde")
	end
	if #effects > 0 then
		local frame = row(44)
		text(frame, "Ce que ça change : " .. table.concat(effects, ", ") .. ".", 11.5,
			DANGER, UDim2.new(0, 12, 0, 12), UDim2.new(1, -24, 0, 24))
	end

	local col = state.EventCollective
	if col and col.Open then
		local frame = row(64)
		text(frame, "Défi collectif — tout le serveur", 13, INK,
			UDim2.new(0, 12, 0, 8), UDim2.new(1, -24, 0, 20)).Font = Enum.Font.GothamBold
		local line = ("%d / %d sessions tenues  ·  %d mort%s sur %d permise%s")
			:format(col.Sessions, col.Target, col.Deaths, col.Deaths == 1 and "" or "s",
				col.MaxDeaths, col.MaxDeaths == 1 and "" or "s")
		text(frame, col.Failed and "Défi perdu. Rendez-vous au prochain." or line, 11.5,
			col.Failed and DANGER or DIM, UDim2.new(0, 12, 0, 32), UDim2.new(1, -24, 0, 24))
	end

	local claimable = not (col and col.Open) or (col.Done == true)
	local frame = row(54)
	text(frame, claimable and "Récompense disponible"
		or "Récompense verrouillée par le défi", 13,
		claimable and INK or DIM, UDim2.new(0, 12, 0, 16), UDim2.new(1, -130, 0, 24))
	local b = button(frame, "Réclamer", claimable)
	if claimable and onEventClaim then
		b.Activated:Connect(function()
			(onEventClaim :: any)()
		end)
	end
	overlay.Visible = true
end

-- ── classements saisonniers (§8) ──────────────────────────────────────────
function Panels.openLeaderboard(view)
	current = "leaderboard"
	titleLabel.Text = "Classements  ·  saison " .. (view and view.Season or "?")
	clear()

	if not view then
		local frame = row(54)
		text(frame, "Chargement des classements…", 13, DIM,
			UDim2.new(0, 12, 0, 16), UDim2.new(1, -24, 0, 30))
		overlay.Visible = true
		return
	end

	if view.Local then
		-- On le dit franchement plutôt que de faire passer six joueurs pour
		-- un classement mondial.
		local frame = row(52)
		text(frame, "Classement limité aux joueurs de ce serveur : "
			.. "le stockage classé n'est pas accessible.", 11.5, DANGER,
			UDim2.new(0, 12, 0, 12), UDim2.new(1, -24, 0, 32))
	end

	for _, board in ipairs(view.Boards) do
		local head = row(40)
		text(head, board.Name, 14, INK, UDim2.new(0, 12, 0, 10),
			UDim2.new(1, -140, 0, 20)).Font = Enum.Font.GothamBold
		local mine = board.Kind == "money" and Format.money(board.Mine) or tostring(board.Mine)
		text(head, "toi : " .. mine, 11, CASH, UDim2.new(1, -128, 0, 13),
			UDim2.new(0, 116, 0, 18)).TextXAlignment = Enum.TextXAlignment.Right

		if #board.Entries == 0 then
			local frame = row(34)
			text(frame, "Personne encore. La place est libre.", 11, DIM,
				UDim2.new(0, 12, 0, 9), UDim2.new(1, -24, 0, 18))
		end
		for _, entry in ipairs(board.Entries) do
			local frame = row(30)
			if entry.IsMe then
				frame.BackgroundColor3 = Color3.fromRGB(34, 40, 34)
			end
			text(frame, ("%d."):format(entry.Rank), 11.5, DIM,
				UDim2.new(0, 12, 0, 7), UDim2.new(0, 28, 0, 18))
			text(frame, entry.Name, 11.5, entry.IsMe and CASH or INK,
				UDim2.new(0, 42, 0, 7), UDim2.new(1, -170, 0, 18))
			local value = board.Kind == "money" and Format.money(entry.Value)
				or tostring(entry.Value)
			text(frame, value, 11.5, INK, UDim2.new(1, -128, 0, 7),
				UDim2.new(0, 116, 0, 18)).TextXAlignment = Enum.TextXAlignment.Right
		end
	end
	overlay.Visible = true
end

-- ── paramètres (§9) ───────────────────────────────────────────────────────
function Panels.openSettings(state, entries)
	current = "settings"
	titleLabel.Text = "Paramètres"
	clear()

	for _, entry in ipairs(entries) do
		local on = state.Settings == nil or state.Settings[entry.Id] ~= false
		local frame = row(58)
		text(frame, entry.Name, 13.5, INK, UDim2.new(0, 12, 0, 8),
			UDim2.new(1, -130, 0, 20)).Font = Enum.Font.GothamBold
		text(frame, entry.Desc, 11, DIM, UDim2.new(0, 12, 0, 30), UDim2.new(1, -130, 0, 20))
		local b = button(frame, on and "ACTIVÉ" or "COUPÉ", true)
		if not on then
			b.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
			b.TextColor3 = DIM
		end
		if onSetting then
			b.Activated:Connect(function()
				(onSetting :: any)(entry.Id, not on)
			end)
		end
	end

	local note = row(58)
	text(note, "Le brouillard et la nappe sonore ne sont pas réglables : "
		.. "ce sont des objets partagés par tout le serveur. Les couper pour "
		.. "toi les couperait pour les autres.", 11, DIM,
		UDim2.new(0, 12, 0, 10), UDim2.new(1, -24, 0, 40))
	overlay.Visible = true
end

function Panels.openDeath(report, state)
	current = "death"
	titleLabel.Text = "Tu es mort"
	clear()
	local frame = row(120)
	text(frame, "Il t'a eu dans " .. (report.Zone or "la rue") .. ".", 15, DANGER,
		UDim2.new(0, 12, 0, 12), UDim2.new(1, -24, 0, 22)).Font = Enum.Font.GothamBold
	text(frame, ("Session : %s gagnés en %s."):format(
		Format.money(report.Earned or 0), Format.clock(report.Seconds or 0)),
		13, INK, UDim2.new(0, 12, 0, 40), UDim2.new(1, -24, 0, 20))
	text(frame, ("Tu gardes %s en banque. Une partie de ce que tu avais sur toi est perdue.")
		:format(Format.money(state.Cash)), 11.5, DIM,
		UDim2.new(0, 12, 0, 66), UDim2.new(1, -24, 0, 40))
	overlay.Visible = true
end

function Panels.close()
	overlay.Visible = false
	current = nil
end

function Panels.isOpen(): boolean
	return overlay ~= nil and overlay.Visible
end

function Panels.currentKind(): string?
	return current
end

return Panels
