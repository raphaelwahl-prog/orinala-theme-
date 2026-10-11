--[[
	EconomyService — argent, multiplicateurs, et la poussée d'état vers le client.

	Deux poches distinctes, c'est tout le jeu :
	  • Unbanked  — ce que tu as gagné cette nuit, sur toi. Perdu si tu es attrapé.
	  • Cash      — déposé au coffre. Jamais perdu.

	Tout l'argent passe par ici. Aucun autre script ne doit modifier le profil
	directement : comme ça il n'y a qu'un endroit à relire quand un chiffre est faux.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)
local ShopCatalog = require(Shared.ShopCatalog)
local Net = require(Shared.Net)

local EconomyService = {}

local services
local unbanked: { [Player]: number } = {}
local passCache: { [Player]: { [string]: boolean } } = {}

function EconomyService.init(registry)
	services = registry
end

-- ─── leaderstats ────────────────────────────────────────────────────────────
local function ensureLeaderstats(player: Player)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local function ensureValue(name: string)
		local value = folder:FindFirstChild(name)
		if not value then
			value = Instance.new("IntValue")
			value.Name = name
			value.Parent = folder
		end
		return value
	end
	return ensureValue("Argent"), ensureValue("Sur toi")
end

function EconomyService.onPlayerAdded(player: Player)
	unbanked[player] = 0
	passCache[player] = {}
	ensureLeaderstats(player)
end

function EconomyService.onPlayerRemoving(player: Player)
	unbanked[player] = nil
	passCache[player] = nil
end

-- ─── multiplicateurs ────────────────────────────────────────────────────────

--[[ Niveau possédé d'un objet de boutique (0 si rien). ]]
function EconomyService.getItemLevel(player: Player, itemId: string): number
	local profile = services.Data.get(player)
	if not profile then
		return 0
	end
	return profile.Items[itemId] or 0
end

--[[ Somme des effets d'un type donné, tous objets confondus. ]]
local function sumEffect(player: Player, effectName: string): number
	local total = 0
	for _, item in ipairs(ShopCatalog.Items) do
		if item.Effect == effectName then
			local level = EconomyService.getItemLevel(player, item.Id)
			if level > 0 then
				total += item.Value * level
			end
		end
	end
	return total
end

--[[ Tous les modificateurs actifs du joueur, en une table.
	 C'est la seule fonction que les autres services doivent appeler. ]]
function EconomyService.getModifiers(player: Player)
	local earnBonus = sumEffect(player, "EarnMultiplier")
	local detectReduction = sumEffect(player, "DetectMultiplier")
	local warningBonus = sumEffect(player, "WarningBonus")
	local walkBonus = sumEffect(player, "WalkSpeedBonus")
	local bankBonus = sumEffect(player, "BankBonus")

	local passMultiplier = 1
	if services.Monetization and services.Monetization.ownsPass(player, "DoubleCash") then
		passMultiplier = 2
	end

	return {
		-- multiplicateur de gains par seconde
		Earn = (1 + earnBonus) * passMultiplier,
		-- facteur appliqué à la chance de détection : 0.55 = −45 % de risque.
		-- Plancher à 0.2 pour qu'aucun objet ne rende un palier totalement sûr.
		Detect = math.max(0.2, 1 - detectReduction),
		-- secondes de fenêtre de fuite en plus
		Warning = warningBonus,
		-- vitesse de marche
		WalkSpeed = GameConfig.Misc.BaseWalkSpeed + walkBonus,
		-- bonus au dépôt
		BankBonus = bankBonus,
	}
end

function EconomyService.applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = EconomyService.getModifiers(player).WalkSpeed
	end
end

-- ─── mouvements d'argent ────────────────────────────────────────────────────

function EconomyService.getUnbanked(player: Player): number
	return unbanked[player] or 0
end

--[[ Ajoute à la poche non déposée.
	 silent = true : n'envoie pas l'état au client. La boucle de sommeil l'utilise
	 pour accumuler sans saturer le réseau ; elle pousse elle-même deux fois
	 par seconde. ]]
function EconomyService.addUnbanked(player: Player, amount: number, silent: boolean?)
	if amount <= 0 then
		return
	end
	unbanked[player] = (unbanked[player] or 0) + amount
	if not silent then
		EconomyService.push(player)
	end
end

--[[ Dépose tout ce que le joueur a sur lui. Retourne le montant crédité. ]]
function EconomyService.bank(player: Player): number
	local profile = services.Data.get(player)
	local amount = unbanked[player] or 0
	if not profile or amount <= 0 then
		return 0
	end

	local bonus = EconomyService.getModifiers(player).BankBonus
	local credited = math.floor(amount * (1 + bonus))

	profile.Cash += credited
	profile.TotalBanked += credited
	unbanked[player] = 0

	services.Progression.check(player)
	EconomyService.push(player)
	return credited
end

--[[ Supprime l'argent non déposé (capture). Retourne ce qui a été perdu. ]]
function EconomyService.wipeUnbanked(player: Player, fraction: number): number
	local amount = unbanked[player] or 0
	local lost = math.floor(amount * fraction)
	unbanked[player] = amount - lost
	EconomyService.push(player)
	return lost
end

--[[ Dépense de l'argent déposé. false si fonds insuffisants. ]]
function EconomyService.spend(player: Player, amount: number): boolean
	local profile = services.Data.get(player)
	if not profile or profile.Cash < amount then
		return false
	end
	profile.Cash -= amount
	EconomyService.push(player)
	return true
end

--[[ Crédit direct (achat Robux). ]]
function EconomyService.grantCash(player: Player, amount: number)
	local profile = services.Data.get(player)
	if not profile then
		return
	end
	profile.Cash += amount
	EconomyService.push(player)
end

-- ─── synchronisation client ─────────────────────────────────────────────────

--[[ Envoie l'état complet au client. Appelé après chaque changement. ]]
function EconomyService.push(player: Player)
	local profile = services.Data.get(player)
	if not profile then
		return
	end

	local cashValue, unbankedValue = ensureLeaderstats(player)
	cashValue.Value = math.floor(profile.Cash)
	unbankedValue.Value = math.floor(unbanked[player] or 0)

	local modifiers = EconomyService.getModifiers(player)
	local sleepState = services.Sleep and services.Sleep.describe(player) or nil

	;(Net.get("StateUpdate") :: RemoteEvent):FireClient(player, {
		Cash = math.floor(profile.Cash),
		Unbanked = math.floor(unbanked[player] or 0),
		TotalBanked = math.floor(profile.TotalBanked),
		Items = profile.Items,
		NightsSurvived = profile.NightsSurvived,
		DeepestTier = profile.DeepestTier,
		Modifiers = {
			Earn = modifiers.Earn,
			Detect = modifiers.Detect,
			Warning = modifiers.Warning,
		},
		Sleep = sleepState,
		Life = services.Life and services.Life.describe(player) or nil,
		DataSaving = services.Data.isAvailable(),
	})
end

--[[ Demande de dépôt venue du coffre. Vérifie que le joueur est bien debout. ]]
function EconomyService.requestBank(player: Player)
	if services.Sleep.isSleeping(player) then
		services.Notify.send(player, "Tu dors. Réveille-toi d'abord.", "info")
		return
	end
	if services.Life.isDown(player) then
		return
	end
	local amount = EconomyService.getUnbanked(player)
	if amount <= 0 then
		services.Notify.send(player, "Tu n'as rien sur toi.", "info")
		return
	end
	local credited = EconomyService.bank(player)
	services.Notify.send(player, ("+%d $ déposés. C'est à toi pour de bon."):format(credited), "cash")
end

function EconomyService.pushAll()
	for _, player in ipairs(Players:GetPlayers()) do
		EconomyService.push(player)
	end
end

return EconomyService
