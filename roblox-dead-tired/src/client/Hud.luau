--[[
	Hud — tout ce que le joueur lit à l'écran.

	Principe d'affichage : les deux poches d'argent ne se ressemblent pas.
	"En banque" est discret et stable. "Sur toi" est gros, vert, et pulse quand
	il monte — c'est ce que tu es en train de risquer. Le joueur doit sentir la
	différence sans qu'on lui explique.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)
local new = UiKit.new
local Colors = UiKit.Colors

local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local refs = {}
local state = { Cash = 0, Unbanked = 0, Sleep = nil, Life = nil }
local round = { Phase = "Dawn", SecondsLeft = 0, NightNumber = 0 }
local awakening = { Stage = 1, MaxStage = 4, StageName = "CALME", ToNext = nil }
local dangerUntil = 0
local revealUntil = 0

-- ─── construction ───────────────────────────────────────────────────────────

local function buildWallet(parent: Instance)
	local panel = new("Frame", {
		Name = "Wallet",
		Parent = parent,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(240, 92),
		Position = UDim2.fromOffset(16, 16),
	}, { UiKit.corner(10), UiKit.padding(12) })

	refs.CashLabel = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "En banque  0 $",
	})

	refs.UnbankedLabel = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "0 $",
	})

	refs.UnbankedHint = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "sur toi — perdu s'il t'attrape",
	})
end

local function buildClock(parent: Instance)
	local panel = new("Frame", {
		Name = "Clock",
		Parent = parent,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(200, 58),
	}, { UiKit.corner(10), UiKit.padding(10) })

	refs.PhaseLabel = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Colors.Muted,
		Text = "JOUR",
	})

	refs.TimerLabel = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = Colors.Text,
		Text = "0:00",
	})
end

local function buildSleepPanel(parent: Instance)
	local panel = new("Frame", {
		Name = "SleepPanel",
		Parent = parent,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(380, 120),
		Visible = false,
	}, { UiKit.corner(12), UiKit.padding(14) })
	refs.SleepPanel = panel

	refs.SleepTitle = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Text,
		Text = "Dortoir",
	})

	refs.SleepRate = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Cash,
		Text = "+0 $/s",
	})

	refs.SleepRisk = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Danger,
		Text = "risque 0 % par tirage",
	})

	-- Barre qui se vide : le temps avant le prochain tirage de risque.
	local track = new("Frame", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Colors.PanelLight,
		BorderSizePixel = 0,
	}, { UiKit.corner(3) })

	refs.RiskBar = new("Frame", {
		Parent = track,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Danger,
		BorderSizePixel = 0,
	}, { UiKit.corner(3) })

	refs.SleepHint = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "Espace pour te réveiller · le prochain tirage arrive",
	})
end

local function buildDanger(parent: Instance)
	refs.DangerFrame = new("Frame", {
		Name = "Danger",
		Parent = parent,
		BackgroundColor3 = Colors.Danger,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 5,
	})

	refs.DangerLabel = new("TextLabel", {
		Parent = refs.DangerFrame,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(600, 70),
		Font = Enum.Font.GothamBlack,
		TextSize = 44,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.2,
		Text = "IL ARRIVE — COURS",
	})
end

local function buildDowned(parent: Instance)
	refs.DownedFrame = new("Frame", {
		Name = "Downed",
		Parent = parent,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 4,
	})

	refs.DownedTitle = new("TextLabel", {
		Parent = refs.DownedFrame,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(700, 48),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		TextColor3 = Colors.Danger,
		Text = "À TERRE",
	})

	refs.DownedInfo = new("TextLabel", {
		Parent = refs.DownedFrame,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 28),
		Font = Enum.Font.Gotham,
		TextSize = 18,
		TextColor3 = Colors.Text,
		Text = "",
	})

	local track = new("Frame", {
		Parent = refs.DownedFrame,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(360, 8),
		BackgroundColor3 = Colors.PanelLight,
		BorderSizePixel = 0,
	}, { UiKit.corner(4) })

	refs.DownedBar = new("Frame", {
		Parent = track,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Colors.Danger,
		BorderSizePixel = 0,
	}, { UiKit.corner(4) })
end

--[[ La jauge d'ÉVEIL : le joueur doit voir que SES choix de planque réveillent
	 la maison. Sans cet affichage, l'évolution des créatures passerait pour de
	 l'arbitraire — et un joueur qui trouve le jeu arbitraire s'en va. ]]
local function buildAwakening(parent: Instance)
	local panel = new("Frame", {
		Name = "Awakening",
		Parent = parent,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(212, 86),
	}, { UiKit.corner(10), UiKit.padding(12) })

	new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "ÉVEIL DE LA MAISON",
	})

	refs.AwakeningName = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 22),
		Font = Enum.Font.GothamBold,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Text,
		Text = "CALME",
	})

	-- Quatre segments : on lit le stade d'un coup d'oeil, sans chiffre.
	local segments = new("Frame", {
		Parent = panel,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 7),
		BackgroundTransparency = 1,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
		}),
	})

	refs.AwakeningSegments = {}
	for index = 1, 4 do
		refs.AwakeningSegments[index] = new("Frame", {
			Parent = segments,
			LayoutOrder = index,
			Size = UDim2.new(0.25, -3, 1, 0),
			BackgroundColor3 = Colors.PanelLight,
			BorderSizePixel = 0,
		}, { UiKit.corner(3) })
	end

	refs.AwakeningHint = new("TextLabel", {
		Parent = panel,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 14),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "dormir profond la réveille",
	})
end

--[[ Première rencontre avec une créature : on affiche son nom ET sa
	 contre-mesure. Un joueur qui meurt sans comprendre pourquoi ne revient
	 pas ; un joueur qui meurt en sachant ce qu'il aurait dû faire relance. ]]
local function buildReveal(parent: Instance)
	refs.RevealFrame = new("Frame", {
		Name = "Reveal",
		Parent = parent,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 8,
	})

	local card = new("Frame", {
		Parent = refs.RevealFrame,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 220),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.02,
	}, { UiKit.corner(14), UiKit.padding(22) })

	new("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "TU VIENS D'EN RÉVEILLER UN",
	})

	refs.RevealName = new("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 42),
		Font = Enum.Font.GothamBlack,
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Danger,
		Text = "LE VEILLEUR",
	})

	refs.RevealTagline = new("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 0, 40),
		Font = Enum.Font.GothamMedium,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = Colors.Text,
		Text = "",
	})

	new("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 0, 0, 14),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Colors.Muted,
		Text = "COMMENT T'EN SORTIR",
	})

	refs.RevealCounter = new("TextLabel", {
		Parent = card,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 136),
		Size = UDim2.new(1, 0, 0, 44),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextColor3 = Colors.Cash,
		Text = "",
	})
end

local function buildToasts(parent: Instance)
	refs.ToastList = new("Frame", {
		Name = "Toasts",
		Parent = parent,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(340, 220),
	}, {
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
		}),
	})
end

function Hud.build(parentGui: ScreenGui)
	gui = parentGui
	buildWallet(gui)
	buildClock(gui)
	buildSleepPanel(gui)
	buildAwakening(gui)
	buildReveal(gui)
	buildDanger(gui)
	buildDowned(gui)
	buildToasts(gui)
end

-- ─── mises à jour venues du serveur ─────────────────────────────────────────

function Hud.setState(newState)
	state = newState
end

function Hud.setRound(newRound)
	round = newRound
end

function Hud.setAwakening(data)
	awakening = data
end

function Hud.revealEntity(data)
	refs.RevealName.Text = data.Name or "?"
	refs.RevealName.TextColor3 = data.EyeColor or Colors.Danger
	refs.RevealTagline.Text = data.Tagline or ""
	refs.RevealCounter.Text = data.Counter or ""
	refs.RevealFrame.Visible = true
	revealUntil = os.clock() + 6
end

function Hud.flashDanger(window: number)
	dangerUntil = os.clock() + window
	refs.DangerFrame.Visible = true
end

local toastOrder = 0

function Hud.toast(message: string, kind: string)
	toastOrder += 1

	local color = Colors.Text
	if kind == "cash" then
		color = Colors.Cash
	elseif kind == "danger" then
		color = Colors.Danger
	elseif kind == "unlock" then
		color = Colors.Unlock
	end

	local frame = new("Frame", {
		Parent = refs.ToastList,
		LayoutOrder = toastOrder,
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = 0.12,
		Size = UDim2.new(1, 0, 0, 34),
	}, { UiKit.corner(8), UiKit.padding(8) })

	new("TextLabel", {
		Parent = frame,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		TextWrapped = true,
		Text = message,
	})

	task.delay(5, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			task.wait(0.35)
			frame:Destroy()
		end
	end)
end

-- ─── boucle d'affichage ─────────────────────────────────────────────────────

local lastUnbanked = 0

function Hud.start()
	RunService.RenderStepped:Connect(function()
		-- Porte-monnaie
		refs.CashLabel.Text = ("En banque  %s"):format(UiKit.money(state.Cash or 0))
		local unbanked = state.Unbanked or 0
		refs.UnbankedLabel.Text = UiKit.money(unbanked)
		refs.UnbankedLabel.TextColor3 = (unbanked > 0) and Colors.Cash or Colors.Muted
		refs.UnbankedHint.TextColor3 = (unbanked > 0) and Colors.Danger or Colors.Muted

		if unbanked > lastUnbanked + 0.01 then
			refs.UnbankedLabel.TextSize = 28
		else
			refs.UnbankedLabel.TextSize = 26
		end
		lastUnbanked = unbanked

		-- Horloge
		local remaining = math.max(0, round.SecondsLeft - (os.clock() - (round.ReceivedAt or os.clock())))
		refs.PhaseLabel.Text = (round.Phase == "Night")
			and ("NUIT %d"):format(round.NightNumber or 0)
			or "JOUR"
		refs.PhaseLabel.TextColor3 = (round.Phase == "Night") and Colors.Danger or Colors.Accent
		refs.TimerLabel.Text = UiKit.clockText(remaining)

		-- Panneau de sommeil
		local sleep = state.Sleep
		if sleep then
			refs.SleepPanel.Visible = true
			refs.SleepTitle.Text = sleep.SpotLabel or sleep.TierName
			refs.SleepRate.Text = ("+%.1f $/s   ·   %s gagnés ici"):format(
				sleep.RatePerSecond or 0, UiKit.money(sleep.Earned or 0))
			if (sleep.RiskPercent or 0) <= 0 then
				refs.SleepRisk.Text = "aucun risque — mais ça ne paie rien"
				refs.SleepRisk.TextColor3 = Colors.Muted
			else
				refs.SleepRisk.Text = ("risque %.1f %% à chaque tirage (toutes les %d s)"):format(
					sleep.RiskPercent, sleep.TickInterval or 6)
				refs.SleepRisk.TextColor3 = Colors.Danger
			end
			local fraction = 0
			if (sleep.TickInterval or 0) > 0 then
				fraction = math.clamp((sleep.SecondsToNextRoll or 0) / sleep.TickInterval, 0, 1)
			end
			refs.RiskBar.Size = UDim2.fromScale(fraction, 1)
		else
			refs.SleepPanel.Visible = false
		end

		-- Éveil de la maison
		refs.AwakeningName.Text = awakening.StageName or "CALME"
		local stageColors = { Colors.Cash, Color3.fromRGB(230, 200, 90), Color3.fromRGB(240, 140, 70), Colors.Danger }
		local stage = awakening.Stage or 1
		refs.AwakeningName.TextColor3 = stageColors[math.clamp(stage, 1, 4)]
		for index, segment in ipairs(refs.AwakeningSegments) do
			segment.BackgroundColor3 = (index <= stage)
				and stageColors[math.clamp(stage, 1, 4)]
				or Colors.PanelLight
		end
		if awakening.ToNext then
			refs.AwakeningHint.Text = ("stade suivant dans %d pts"):format(math.max(0, awakening.ToNext))
		else
			refs.AwakeningHint.Text = "maximum — il est dehors"
		end

		-- Fiche de créature
		if refs.RevealFrame.Visible and os.clock() >= revealUntil then
			refs.RevealFrame.Visible = false
		end

		-- Alerte
		if refs.DangerFrame.Visible then
			local left = dangerUntil - os.clock()
			if left <= -1.5 then
				refs.DangerFrame.Visible = false
				refs.DangerFrame.BackgroundTransparency = 1
			else
				local pulse = 0.78 + 0.1 * math.sin(os.clock() * 14)
				refs.DangerFrame.BackgroundTransparency = pulse
				refs.DangerLabel.Text = (left > 0)
					and ("IL ARRIVE — COURS   %.1f s"):format(left)
					or "IL EST LÀ"
			end
		end

		-- À terre
		local life = state.Life
		if life and life.Down then
			refs.DownedFrame.Visible = true
			refs.DownedBar.Size = UDim2.fromScale(
				math.clamp((life.SecondsLeft or 0) / (life.BleedoutSeconds or 1), 0, 1), 1)
			if life.BeingRevivedBy then
				refs.DownedInfo.Text = ("%s te relève… %d %%"):format(
					life.BeingRevivedBy, math.floor((life.ReviveProgress or 0) * 100))
				refs.DownedBar.BackgroundColor3 = Colors.Cash
			else
				refs.DownedInfo.Text = ("%s perdus · %d s avant de lâcher"):format(
					UiKit.money(life.LostAmount or 0), math.floor(life.SecondsLeft or 0))
				refs.DownedBar.BackgroundColor3 = Colors.Danger
			end
		else
			refs.DownedFrame.Visible = false
		end
	end)
end

return Hud
