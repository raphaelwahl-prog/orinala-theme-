--!strict
-- §6 — les deux soldes, et toutes les règles d'argent.
--
-- Rien n'ajoute d'argent sans passer par ici, et rien ici n'accepte un montant
-- venu du client. Les trois garde-fous du CDC §15 sont des `assert` de fait :
--   · un achat ne peut pas faire passer le solde sous zéro ;
--   · pas de gains négatifs ;
--   · pas de double récompense (les appelants passent par des clés uniques).

local Format = require(script.Parent.Parent.Shared.Format)
local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)

local EconomyService = {}

local listeners: { (Player) -> () } = {}

-- L'éveil de la maison augmente les gains de tout le serveur. On l'injecte
-- depuis le bootstrap pour qu'EconomyService ne dépende pas d'AwakeningService
-- (qui, lui, dépend de MonsterService : la boucle serait circulaire).
local awakeningBonus: (() -> number)? = nil

function EconomyService.setAwakeningBonus(fn: () -> number)
	awakeningBonus = fn
end

-- Même mécanique pour le multiplicateur de l'événement en cours (§13). Il
-- était déclaré dans la configuration et calculé par EventService, mais
-- personne ne le lisait : les gains ne bougeaient pas d'un gramme pendant un
-- événement. Il est maintenant injecté ici, comme celui de l'éveil.
local eventBonus: (() -> number)? = nil

function EconomyService.setEventBonus(fn: () -> number)
	eventBonus = fn
end

function EconomyService.onChanged(fn: (Player) -> ())
	table.insert(listeners, fn)
end

local function fire(player: Player)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, player)
	end
end

function EconomyService.multiplier(player: Player): number
	local profile = PlayerDataService.get(player)
	if not profile then
		return 1
	end
	if profile.MultiplierUntil > os.time() then
		return math.min(profile.Multiplier, GameConfig.Monetization.MaxMultiplier)
	end
	return 1
end

-- Gain de survie pour `seconds` passées dans `zoneId`.
-- Renvoie le montant réellement crédité (jamais négatif).
function EconomyService.accrue(player: Player, zoneId: string, seconds: number, earnedThisSession: number): number
	if seconds <= 0 then
		return 0
	end
	local profile = PlayerDataService.get(player)
	local zone = ZoneConfig.get(zoneId)
	if not profile or not zone then
		return 0
	end

	local rate = zone.Rate * EconomyService.multiplier(player)
	if awakeningBonus then
		-- Contrepartie du risque partagé : plus la maison est réveillée, plus
		-- ça paie. Sans ça, personne n'aurait intérêt à remplir la jauge.
		rate *= awakeningBonus()
	end
	if eventBonus then
		rate *= eventBonus()
	end
	-- Plafond souple : au-delà, le taux est divisé. Sans ça, la zone 7 à
	-- 100 000 $/s rend toute la progression précédente sans objet.
	if earnedThisSession >= zone.SoftCapPerSession then
		rate /= GameConfig.Economy.SoftCapDivisor
	end

	local amount = rate * seconds
	if amount <= 0 or amount ~= amount then  -- NaN
		return 0
	end

	profile.UnbankedCash += amount
	PlayerDataService.markDirty(player)
	fire(player)
	return amount
end

-- Dépôt : l'argent non sécurisé devient sécurisé. C'est le seul endroit qui
-- alimente LifetimeBanked, qui sert aux déblocages de zones.
function EconomyService.bank(player: Player): number
	local profile = PlayerDataService.get(player)
	if not profile or profile.UnbankedCash <= 0 then
		return 0
	end
	local amount = profile.UnbankedCash
	profile.UnbankedCash = 0
	profile.Cash += amount
	profile.LifetimeBanked += amount
	PlayerDataService.markDirty(player)
	fire(player)
	return amount
end

-- Mort : on perd une part du non sécurisé, jamais du sécurisé (CDC §2).
function EconomyService.applyDeath(player: Player, zoneId: string): number
	local profile = PlayerDataService.get(player)
	local zone = ZoneConfig.get(zoneId)
	if not profile then
		return 0
	end
	local ratio = zone and zone.DeathLossRatio or 0.5
	local lost = profile.UnbankedCash * ratio
	profile.UnbankedCash = math.max(0, profile.UnbankedCash - lost)
	profile.Deaths += 1
	PlayerDataService.markDirty(player)
	fire(player)
	return lost
end

-- Déconnexion : CDC §4, « la déconnexion arrête les gains immédiatement ».
function EconomyService.applyDisconnect(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	if not GameConfig.Economy.DisconnectKeepsUnbanked then
		profile.UnbankedCash = 0
	end
	PlayerDataService.markDirty(player)
end

-- Dépense. Renvoie false si le solde ne suffit pas : aucun solde négatif.
function EconomyService.spend(player: Player, amount: number): boolean
	local profile = PlayerDataService.get(player)
	if not profile or amount < 0 then
		return false
	end
	if profile.Cash < amount then
		return false
	end
	profile.Cash -= amount
	PlayerDataService.markDirty(player)
	fire(player)
	return true
end

-- Récompense directe (mission, achat Robux). `reason` sert aux journaux.
function EconomyService.grant(player: Player, amount: number, reason: string): boolean
	local profile = PlayerDataService.get(player)
	if not profile or amount <= 0 then
		return false
	end
	profile.Cash += amount
	profile.LifetimeBanked += amount
	PlayerDataService.markDirty(player)
	if GameConfig.Debug.Verbose then
		print(("[Economy] %s +%s (%s)"):format(player.Name, Format.money(amount), reason))
	end
	fire(player)
	return true
end

function EconomyService.setMultiplier(player: Player, value: number, seconds: number)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	-- Les multiplicateurs ne se cumulent pas : on prend le meilleur, on
	-- additionne la durée si c'est le même.
	local capped = math.min(value, GameConfig.Monetization.MaxMultiplier)
	if profile.MultiplierUntil > os.time() and profile.Multiplier == capped then
		profile.MultiplierUntil += seconds
	else
		profile.Multiplier = capped
		profile.MultiplierUntil = os.time() + seconds
	end
	PlayerDataService.markDirty(player)
	fire(player)
end

return EconomyService
