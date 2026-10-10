--[[
	DEAD TIRED — client.

	Il ne décide de rien : il affiche ce que le serveur envoie et transmet les
	intentions du joueur. Toutes les règles (argent, risque, capture) sont côté
	serveur. C'est la seule architecture qui résiste aux exploits sur Roblox.

	Touches :
	  E       — interagir (dormir, déposer, ouvrir la boutique, relever) via les invites
	  Espace  — se réveiller
	  B       — ouvrir/fermer la boutique
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Hud = require(script.Hud)
local ShopUI = require(script.ShopUI)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── interface ──────────────────────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "DeadTiredUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

Hud.build(gui)
ShopUI.build(gui)
Hud.start()

-- ─── réception serveur ─────────────────────────────────────────────────────

local isSleeping = false

;(Net.get("StateUpdate") :: RemoteEvent).OnClientEvent:Connect(function(state)
	Hud.setState(state)
	ShopUI.setCash(state.Cash or 0)
end)

;(Net.get("RoundUpdate") :: RemoteEvent).OnClientEvent:Connect(function(round)
	round.ReceivedAt = os.clock()
	Hud.setRound(round)
end)

;(Net.get("Notify") :: RemoteEvent).OnClientEvent:Connect(function(message, kind)
	Hud.toast(message, kind or "info")
end)

;(Net.get("DangerAlert") :: RemoteEvent).OnClientEvent:Connect(function(window)
	Hud.flashDanger(window or 4)
end)

;(Net.get("SleepChanged") :: RemoteEvent).OnClientEvent:Connect(function(sleeping)
	isSleeping = sleeping == true
	-- On coupe le saut pendant le sommeil pour que Espace serve au réveil.
	if isSleeping then
		ShopUI.setVisible(false)
	end
end)

;(Net.get("ShopResult") :: RemoteEvent).OnClientEvent:Connect(function(payload)
	if payload.Catalog then
		ShopUI.render(payload.Catalog)
	end
	if payload.Action == "Open" then
		ShopUI.setVisible(true)
	end
end)

-- ─── entrées ────────────────────────────────────────────────────────────────

local function onWake(actionName: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if not isSleeping then
		return Enum.ContextActionResult.Pass
	end
	;(Net.get("RequestWake") :: RemoteEvent):FireServer()
	return Enum.ContextActionResult.Sink
end

-- BindActionAtPriority : on passe devant le saut par défaut, mais seulement
-- quand le joueur dort (sinon on rend l'input au jeu avec Pass).
ContextActionService:BindActionAtPriority(
	"DeadTiredWake",
	onWake,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.Space
)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		if ShopUI.isVisible() then
			ShopUI.setVisible(false)
		elseif not isSleeping then
			ShopUI.refreshFromServer()
			ShopUI.setVisible(true)
		end
	end
end)

-- ─── confort ────────────────────────────────────────────────────────────────

-- On masque la liste des joueurs par défaut : le HUD donne déjà l'argent, et
-- l'écran doit rester sombre et vide pour que le jeu fasse peur.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

ShopUI.refreshFromServer()

print("[DEAD TIRED] client prêt.")
