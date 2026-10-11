--!strict
-- À terre, pas mort : le coéquipier peut te relever.
--
-- Sans ça, une mort en multijoueur ne fait que renvoyer chacun à son coin.
-- Avec ça, un joueur qui tombe est une décision pour les autres : on va le
-- chercher pendant que le monstre est encore là, ou on le laisse ?
--
-- Tomber à terre ne coûte rien. Saigner jusqu'au bout coûte ce que coûte une
-- mort normale — c'est EconomyService qui s'en occupe, pas ce service.

local Players = game:GetService("Players")

local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local SoundLib = require(script.Parent.SoundService)

local LifeService = {}

local BLEED_SECONDS = 30
local REVIVE_SECONDS = 4
local REVIVE_RANGE = 10

type Downed = {
	Player: Player,
	Until: number,
	Prompt: ProximityPrompt,
	Connection: RBXScriptConnection?,
}

local downed: { [Player]: Downed } = {}
local listeners: { (Player, boolean, number) -> () } = {}
local deathHandlers: { (Player) -> () } = {}

function LifeService.onChanged(fn: (Player, boolean, number) -> ())
	table.insert(listeners, fn)
end

function LifeService.onBleedOut(fn: (Player) -> ())
	table.insert(deathHandlers, fn)
end

local function fire(player: Player, isDown: boolean, secondsLeft: number)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, player, isDown, secondsLeft)
	end
end

function LifeService.isDowned(player: Player): boolean
	return downed[player] ~= nil
end

local function standUp(player: Player, revived: boolean)
	local entry = downed[player]
	if not entry then
		return
	end
	downed[player] = nil
	if entry.Connection then
		entry.Connection:Disconnect()
	end
	entry.Prompt:Destroy()

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		if revived then
			humanoid.Health = math.max(humanoid.Health, humanoid.MaxHealth * 0.4)
			SoundLib.playFor(player, "revived")
		end
	end
	fire(player, false, 0)
end

local function bleedOut(player: Player)
	local entry = downed[player]
	if not entry then
		return
	end
	standUp(player, false)
	for _, fn in ipairs(deathHandlers) do
		task.spawn(fn, player)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end

-- Mettre à terre au lieu de tuer. Renvoie false si ce n'est pas possible
-- (joueur seul sur le serveur : on ne va pas le laisser agoniser sans issue).
function LifeService.knockDown(player: Player): boolean
	if downed[player] then
		return true
	end
	if #Players:GetPlayers() < 2 then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return false
	end

	humanoid.Health = 1
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Relever"
	prompt.ObjectText = player.Name
	prompt.HoldDuration = REVIVE_SECONDS
	prompt.MaxActivationDistance = REVIVE_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	local entry: Downed = {
		Player = player, Until = os.clock() + BLEED_SECONDS,
		Prompt = prompt, Connection = nil,
	}
	entry.Connection = prompt.Triggered:Connect(function(rescuer)
		if rescuer == player or not downed[player] then
			return
		end
		standUp(player, true)
	end)
	downed[player] = entry
	SoundLib.playFor(player, "downed")
	fire(player, true, BLEED_SECONDS)
	return true
end

function LifeService.init()
	task.spawn(function()
		while true do
			task.wait(1)
			for player, entry in pairs(downed) do
				local left = entry.Until - os.clock()
				if not player.Parent then
					downed[player] = nil
				elseif left <= 0 then
					bleedOut(player)
				else
					fire(player, true, left)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local entry = downed[player]
		if entry then
			if entry.Connection then
				entry.Connection:Disconnect()
			end
			downed[player] = nil
		end
	end)
end

return LifeService
