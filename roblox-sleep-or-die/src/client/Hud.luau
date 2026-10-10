--!strict
-- §9 — l'interface. Tout ce que le cahier des charges demande d'afficher :
-- argent sécurisé et non sécurisé, zone, santé, objectifs, état du refuge,
-- alertes, temps de survie, inventaire, carte, écran de mort, paramètres.
--
-- Contrainte du CDC : « lisible sur ordinateur et mobile ». Les panneaux sont
-- donc dimensionnés en échelle, pas en pixels, et se réorganisent sous 600 px.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AwakeningConfig = require(Shared.AwakeningConfig)
local Format = require(Shared.Format)

local Hud = {}

local INK = Color3.fromRGB(236, 237, 240)
local DIM = Color3.fromRGB(150, 152, 162)
local PANEL = Color3.fromRGB(14, 14, 19)
local CASH = Color3.fromRGB(110, 226, 150)
local DANGER = Color3.fromRGB(255, 86, 72)
local ACCENT = Color3.fromRGB(120, 160, 255)

local gui: ScreenGui
local refs: { [string]: any } = {}
local toasts: { Frame } = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function panel(name: string, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.new(0, 0)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	corner(frame, 10)
	frame.Parent = gui
	return frame
end

local function label(parent: Instance, text: string, size: number, color: Color3,
	position: UDim2, width: UDim2?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.Font = Enum.Font.GothamMedium
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Position = position
	l.Size = width or UDim2.new(1, -16, 0, size + 6)
	l.Parent = parent
	return l
end

function Hud.build(screen: ScreenGui)
	gui = screen

	-- Argent (haut gauche)
	local wallet = panel("Wallet", UDim2.new(0, 220, 0, 86), UDim2.new(0, 14, 0, 14))
	refs.cash = label(wallet, "0 $", 13, DIM, UDim2.new(0, 12, 0, 8))
	refs.unbanked = label(wallet, "0 $", 26, DIM, UDim2.new(0, 12, 0, 26))
	refs.unbanked.Font = Enum.Font.GothamBold
	refs.hint = label(wallet, "sur toi", 11, DIM, UDim2.new(0, 12, 0, 60))

	-- Zone et session (haut centre)
	local status = panel("Status", UDim2.new(0, 230, 0, 70), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
	refs.zone = label(status, "LA RUE", 12, ACCENT, UDim2.new(0, 12, 0, 8))
	refs.zone.Font = Enum.Font.GothamBold
	refs.session = label(status, "éveillé", 18, INK, UDim2.new(0, 12, 0, 26))
	refs.sessionBarBg = Instance.new("Frame")
	refs.sessionBarBg.Size = UDim2.new(1, -24, 0, 5)
	refs.sessionBarBg.Position = UDim2.new(0, 12, 0, 54)
	refs.sessionBarBg.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
	refs.sessionBarBg.BorderSizePixel = 0
	corner(refs.sessionBarBg, 3)
	refs.sessionBarBg.Parent = status
	refs.sessionBar = Instance.new("Frame")
	refs.sessionBar.Size = UDim2.new(0, 0, 1, 0)
	refs.sessionBar.BackgroundColor3 = CASH
	refs.sessionBar.BorderSizePixel = 0
	corner(refs.sessionBar, 3)
	refs.sessionBar.Parent = refs.sessionBarBg

	-- Santé et refuge (haut droite)
	local state = panel("State", UDim2.new(0, 210, 0, 86), UDim2.new(1, -14, 0, 14), Vector2.new(1, 0))
	refs.health = label(state, "100 / 100", 16, INK, UDim2.new(0, 12, 0, 8))
	refs.shelter = label(state, "aucun refuge", 12, DIM, UDim2.new(0, 12, 0, 32))
	refs.event = label(state, "", 11, Color3.fromRGB(200, 140, 255), UDim2.new(0, 12, 0, 54))

	-- Objectif courant (bas centre)
	local objective = panel("Objective", UDim2.new(0, 330, 0, 54), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
	refs.objectiveTitle = label(objective, "Objectif", 13, INK, UDim2.new(0, 12, 0, 7))
	refs.objectiveTitle.Font = Enum.Font.GothamBold
	refs.objectiveText = label(objective, "", 11.5, DIM, UDim2.new(0, 12, 0, 27))

	-- Invite d'action (au-dessus de l'objectif)
	refs.prompt = panel("Prompt", UDim2.new(0, 300, 0, 32), UDim2.new(0.5, 0, 1, -82), Vector2.new(0.5, 1))
	refs.promptText = label(refs.prompt, "", 13, INK, UDim2.new(0, 12, 0, 6))
	refs.prompt.Visible = false

	-- Zone des alertes (bas gauche)
	refs.toasts = Instance.new("Frame")
	refs.toasts.Name = "Toasts"
	refs.toasts.Size = UDim2.new(0, 320, 0, 200)
	refs.toasts.Position = UDim2.new(0, 14, 1, -14)
	refs.toasts.AnchorPoint = Vector2.new(0, 1)
	refs.toasts.BackgroundTransparency = 1
	refs.toasts.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = refs.toasts

	-- Éveil de la maison : la jauge partagée par tout le serveur.
	local awake = panel("Awake", UDim2.new(0, 210, 0, 74), UDim2.new(1, -14, 0, 108),
		Vector2.new(1, 0))
	refs.awakeLabel = label(awake, "ÉVEIL DE LA MAISON", 9.5, DIM, UDim2.new(0, 12, 0, 7))
	refs.awakeStage = label(awake, "CALME", 16, CASH, UDim2.new(0, 12, 0, 22))
	refs.awakeStage.Font = Enum.Font.GothamBold
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -24, 0, 5)
	barBg.Position = UDim2.new(0, 12, 0, 46)
	barBg.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
	barBg.BorderSizePixel = 0
	corner(barBg, 3)
	barBg.Parent = awake
	refs.awakeBar = Instance.new("Frame")
	refs.awakeBar.Size = UDim2.new(0, 0, 1, 0)
	refs.awakeBar.BackgroundColor3 = CASH
	refs.awakeBar.BorderSizePixel = 0
	corner(refs.awakeBar, 3)
	refs.awakeBar.Parent = barBg
	refs.awakeFoot = label(awake, "", 9.5, DIM, UDim2.new(0, 12, 0, 55))

	-- Bandeau « à terre » : il doit être impossible à manquer.
	refs.downed = panel("Downed", UDim2.new(0, 360, 0, 52), UDim2.new(0.5, 0, 0, 96),
		Vector2.new(0.5, 0))
	refs.downedText = label(refs.downed, "", 14, DANGER, UDim2.new(0, 12, 0, 6))
	refs.downedText.Font = Enum.Font.GothamBold
	refs.downedSub = label(refs.downed, "", 11.5, DIM, UDim2.new(0, 12, 0, 28))
	refs.downed.Visible = false

	-- Voile rouge de danger
	refs.tint = Instance.new("Frame")
	refs.tint.Size = UDim2.fromScale(1, 1)
	refs.tint.BackgroundColor3 = DANGER
	refs.tint.BackgroundTransparency = 1
	refs.tint.BorderSizePixel = 0
	refs.tint.ZIndex = 0
	refs.tint.Parent = gui
end

function Hud.toast(text: string, kind: string)
	local colors = {
		info = INK, warn = Color3.fromRGB(255, 196, 92),
		danger = DANGER, cash = CASH, unlock = Color3.fromRGB(190, 130, 255),
		event = Color3.fromRGB(200, 140, 255),
	}
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 34)
	frame.BackgroundColor3 = PANEL
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	corner(frame, 8)
	frame.Parent = refs.toasts

	local l = label(frame, text, 12.5, colors[kind] or INK, UDim2.new(0, 10, 0, 0))
	l.Size = UDim2.new(1, -20, 1, 0)
	l.TextWrapped = true

	table.insert(toasts, frame)
	task.delay(5, function()
		local tween = TweenService:Create(frame, TweenInfo.new(0.3),
			{ BackgroundTransparency = 1 })
		tween:Play()
		TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		tween.Completed:Wait()
		frame:Destroy()
	end)
end

function Hud.setPrompt(text: string?)
	refs.prompt.Visible = text ~= nil
	if text then
		refs.promptText.Text = text
	end
end

function Hud.flash(amount: number)
	refs.tint.BackgroundTransparency = 1 - math.clamp(amount, 0, 0.35)
	TweenService:Create(refs.tint, TweenInfo.new(0.6),
		{ BackgroundTransparency = 1 }):Play()
end

function Hud.update(state)
	refs.cash.Text = "En banque  " .. Format.money(state.Cash)
	refs.unbanked.Text = Format.money(state.Unbanked)
	refs.unbanked.TextColor3 = state.Unbanked > 0 and CASH or DIM
	refs.hint.Text = state.Unbanked > 0 and "sur toi — perdu s'il t'attrape" or "sur toi"
	refs.hint.TextColor3 = state.Unbanked > 0 and DANGER or DIM

	for _, zone in ipairs(state.Zones) do
		if zone.Id == state.Zone then
			refs.zone.Text = string.upper(zone.Name) .. "  ·  " .. Format.rate(zone.Rate)
		end
	end

	if state.Sleeping then
		refs.session.Text = Format.money(state.SessionEarned) .. " gagnés"
		refs.session.TextColor3 = CASH
		local ratio = state.SessionMax > 0 and state.SessionSeconds / state.SessionMax or 0
		refs.sessionBar.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
	else
		refs.session.Text = "éveillé"
		refs.session.TextColor3 = INK
		refs.sessionBar.Size = UDim2.new(0, 0, 1, 0)
	end

	refs.shelter.Text = state.ShelterId ~= "" and ("refuge : " .. state.ShelterId)
		or "aucun refuge"

	if state.Multiplier > 1 then
		refs.event.Text = "gains x" .. state.Multiplier
	elseif state.Event then
		refs.event.Text = state.Event.Name
	else
		refs.event.Text = ""
	end

	-- Objectif : la première mission non terminée, principales d'abord.
	local best = nil
	for _, mission in ipairs(state.Missions) do
		if not mission.Done then
			if not best or (mission.Kind == "main" and best.Kind ~= "main") then
				best = mission
			end
		end
	end
	if best then
		refs.objectiveTitle.Text = best.Name .. "  (" .. best.Progress .. "/" .. best.Target .. ")"
		refs.objectiveText.Text = best.Text
	else
		refs.objectiveTitle.Text = "Tout est fait"
		refs.objectiveText.Text = "Reviens demain pour les quotidiennes."
	end
end

-- L'éveil est une information de serveur : elle arrive par son propre remote,
-- pas avec l'état du joueur.
function Hud.setAwakening(points: number, stage: number, data)
	refs.awakeStage.Text = data.Name
	refs.awakeStage.TextColor3 = data.Color
	refs.awakeBar.BackgroundColor3 = data.Color
	local nextThreshold = data.Next
	if nextThreshold then
		local previous = AwakeningConfig.Thresholds[stage] or 0
		local span = math.max(1, nextThreshold - previous)
		refs.awakeBar.Size = UDim2.new(math.clamp((points - previous) / span, 0, 1), 0, 1, 0)
		refs.awakeFoot.Text = ("stade suivant dans %d pts · gains x%.2f")
			:format(math.max(0, math.ceil(nextThreshold - points)), data.Reward)
	else
		refs.awakeBar.Size = UDim2.new(1, 0, 1, 0)
		refs.awakeFoot.Text = ("maximum · gains x%.2f"):format(data.Reward)
	end
end

function Hud.setDowned(name: string, isDown: boolean, secondsLeft: number, isMe: boolean)
	if not isDown then
		refs.downed.Visible = false
		return
	end
	refs.downed.Visible = true
	refs.downedText.Text = isMe and "TU ES À TERRE" or (string.upper(name) .. " EST À TERRE")
	refs.downedSub.Text = isMe
		and ("Un coéquipier peut te relever. %d s."):format(math.ceil(secondsLeft))
		or ("Approche et maintiens E pour le relever. %d s."):format(math.ceil(secondsLeft))
end

function Hud.setHealth(current: number, max: number)
	refs.health.Text = math.floor(current) .. " / " .. math.floor(max)
	refs.health.TextColor3 = current < max * 0.35 and DANGER or INK
end

return Hud
