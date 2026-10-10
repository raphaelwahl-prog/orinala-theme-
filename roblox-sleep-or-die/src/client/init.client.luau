--!strict
-- Point d'entrée client. Il ne décide de rien : il affiche ce que le serveur
-- envoie et transmet les demandes du joueur.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Hud = require(script.Hud)
local Panels = require(script.Panels)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "SleepOrDie"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

Hud.build(screen)
Panels.build(screen, {
	buy = function(itemId)
		Net.get("RequestBuy"):FireServer(itemId)
	end,
	place = function(itemId)
		Net.get("RequestPlace"):FireServer(itemId)
	end,
	cosmetic = function(action, id)
		Net.get("RequestCosmetic"):FireServer(action, id)
	end,
})

local state: any = nil
local lastReport: any = nil

Net.get("StateChanged").OnClientEvent:Connect(function(payload)
	state = payload
	Hud.update(state)
	-- Si un panneau est ouvert, on le redessine avec les nouvelles données.
	local kind = Panels.currentKind()
	if kind == "shop" then
		Panels.openShop(state)
	elseif kind == "defenses" then
		Panels.openDefenses(state)
	elseif kind == "missions" then
		Panels.openMissions(state)
	elseif kind == "zones" then
		Panels.openZones(state)
	elseif kind == "cosmetics" then
		Panels.openCosmetics(state)
	end
end)

Net.get("AwakeningChanged").OnClientEvent:Connect(function(points, stage, data)
	Hud.setAwakening(points, stage, data)
	if stage >= 3 then
		Hud.flash(0.18)
	end
end)

Net.get("DownedChanged").OnClientEvent:Connect(function(name, isDown, secondsLeft)
	Hud.setDowned(name, isDown, secondsLeft, name == player.Name)
end)

Net.get("Alert").OnClientEvent:Connect(function(text, kind)
	Hud.toast(text, kind or "info")
	if kind == "danger" then
		Hud.flash(0.25)
	end
end)

Net.get("DeathReport").OnClientEvent:Connect(function(report)
	lastReport = report
	if state then
		Panels.openDeath(report, state)
	end
end)

Net.get("MonsterSignal").OnClientEvent:Connect(function(_monsterId, kind, position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local distance = (root.Position - position).Magnitude
	if distance > 140 then
		return
	end
	if kind == "spotted" then
		Hud.toast("Il t'a vu.", "danger")
		Hud.flash(0.3)
	elseif kind == "assault" then
		Hud.toast("Quelque chose frappe le refuge.", "danger")
		Hud.flash(0.2)
	end
end)

-- ── santé ─────────────────────────────────────────────────────────────────
local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	Hud.setHealth(humanoid.Health, humanoid.MaxHealth)
	humanoid.HealthChanged:Connect(function(value)
		Hud.setHealth(value, humanoid.MaxHealth)
		if value < humanoid.MaxHealth * 0.4 then
			Hud.flash(0.2)
		end
	end)
end

if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

-- ── interactions de proximité ─────────────────────────────────────────────
-- Le serveur a déjà posé des ProximityPrompt sur le coffre, la boutique, les
-- PNJ et la porte des égouts. On s'y branche sans en créer de nouveaux.
local function bindPrompts()
	for _, prompt in ipairs(Workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") and not prompt:GetAttribute("Bound") then
			prompt:SetAttribute("Bound", true)
			prompt.Triggered:Connect(function(triggering)
				if triggering ~= player then
					return
				end
				local target = prompt.Parent
				if not target then
					return
				end
				if CollectionService:HasTag(target, "Vault") then
					Net.get("RequestBank"):FireServer()
				elseif CollectionService:HasTag(target, "Shop") then
					if state then
						Panels.openShop(state)
					end
				elseif CollectionService:HasTag(target, "ZoneGate") then
					Net.get("RequestEnterZone"):FireServer(target:GetAttribute("Zone"))
				elseif target.Parent and CollectionService:HasTag(target.Parent, "Npc") then
					if state then
						Panels.openMissions(state)
					end
				end
			end)
		end
	end
end
bindPrompts()
Workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("ProximityPrompt") then
		task.defer(bindPrompts)
	end
end)

-- ── refuge le plus proche + invite contextuelle ───────────────────────────
local function nearestShelter(): (Model?, number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, math.huge
	end
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged("Shelter")) do
		if model:IsA("Model") and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best, bestDistance
end

RunService.RenderStepped:Connect(function()
	if not state then
		return
	end
	local shelter, distance = nearestShelter()
	if state.Sleeping then
		Hud.setPrompt("Espace — se réveiller")
		return
	end
	if shelter and distance < 16 then
		local owner = shelter:GetAttribute("OwnerName")
		if owner == player.Name then
			Hud.setPrompt("E — dormir ici  ·  B défenses")
		elseif owner == "" or owner == nil then
			Hud.setPrompt("E — réserver ce refuge")
		else
			Hud.setPrompt("Occupé par " .. tostring(owner))
		end
	else
		Hud.setPrompt(nil)
	end
end)

-- ── commandes ─────────────────────────────────────────────────────────────
local function interact()
	if not state then
		return
	end
	local shelter, distance = nearestShelter()
	if shelter and distance < 16 then
		local owner = shelter:GetAttribute("OwnerName")
		if owner == player.Name then
			Net.get("RequestSleep"):FireServer()
		else
			Net.get("RequestClaim"):FireServer(shelter:GetAttribute("ShelterId"))
		end
	end
end

local function attack()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local best, bestDistance = nil, 9
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		if model:IsA("Model") and model.PrimaryPart then
			local distance = (model.PrimaryPart.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	if best then
		Net.get("RequestAttack"):FireServer(best)
	end
end

local function onAction(name: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if name == "Interact" then
		interact()
	elseif name == "Wake" then
		Net.get("RequestWake"):FireServer()
	elseif name == "Defenses" then
		if state then
			Panels.openDefenses(state)
		end
	elseif name == "Missions" then
		if state then
			Panels.openMissions(state)
		end
	elseif name == "Zones" then
		if state then
			Panels.openZones(state)
		end
	elseif name == "Skins" then
		if state then
			Panels.openCosmetics(state)
		end
	elseif name == "Attack" then
		attack()
	elseif name == "Close" then
		Panels.close()
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("Interact", onAction, true, Enum.KeyCode.E)
ContextActionService:BindAction("Wake", onAction, false, Enum.KeyCode.Space)
ContextActionService:BindAction("Defenses", onAction, true, Enum.KeyCode.B)
ContextActionService:BindAction("Missions", onAction, true, Enum.KeyCode.M)
ContextActionService:BindAction("Zones", onAction, true, Enum.KeyCode.N)
ContextActionService:BindAction("Attack", onAction, true, Enum.KeyCode.F,
	Enum.UserInputType.MouseButton1)
ContextActionService:BindAction("Skins", onAction, true, Enum.KeyCode.C)
ContextActionService:BindAction("Close", onAction, false, Enum.KeyCode.Escape)

ContextActionService:SetTitle("Interact", "E")
ContextActionService:SetTitle("Defenses", "DÉFENSES")
ContextActionService:SetTitle("Missions", "MISSIONS")
ContextActionService:SetTitle("Attack", "FRAPPER")
ContextActionService:SetTitle("Skins", "SKINS")

Hud.toast("Trouve un refuge dans une ruelle. E pour le réserver, E pour dormir.", "info")
