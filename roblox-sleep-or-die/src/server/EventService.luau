--!strict
-- §13 — événements. Le serveur seul décide de l'événement actif, et une
-- récompense d'événement ne peut pas être réclamée deux fois (clé = identifiant
-- de l'événement + sa période).
--
-- Chaque champ déclaré dans GameConfig.Events.List agit réellement :
--   · RewardMultiplier  → injecté dans EconomyService (gains de survie) ;
--   · MonsterMultiplier → relève le plafond de monstres (MonsterService.capFor) ;
--   · MonsterSpeed      → accélère tous les monstres concernés ;
--   · MiniBoss          → fait naître une version démesurée du monstre de zone ;
--   · Collective        → ouvre un défi serveur, et la récompense se mérite.
--   · Zone              → « any » ou un identifiant : limite la portée des deux
--                         effets sur les monstres.
--
-- Avant, seul `RewardMultiplier` était *lu* — et encore, par personne. Un
-- événement changeait le bandeau du HUD et rien d'autre.

local CollectionService = game:GetService("CollectionService")

local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)
local MonsterService = require(script.Parent.MonsterService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)

local EventService = {}

export type Active = {
	Id: string,
	Name: string,
	Text: string,
	Zone: string,
	RewardMultiplier: number,
	MonsterMultiplier: number,
	MonsterSpeed: number,
	MiniBoss: boolean,
	Collective: boolean,
	StartedAt: number,
	Period: string,
}

local current: Active? = nil
local listeners: { (Active) -> () } = {}
local rewardHandlers: { (Player, number) -> () } = {}

-- Défi collectif : compté sur le serveur entier, remis à zéro à chaque
-- rotation. `Failed` reste vrai jusqu'à la rotation suivante : un défi raté
-- est raté, on ne le repêche pas.
local collective = { Sessions = 0, Deaths = 0, Failed = false }

-- Mini-boss d'événement : un seul à la fois sur tout le serveur.
local miniBoss: { Model: Model, Label: string, Hits: number, Players: { Player } }? = nil

function EventService.onChanged(fn: (Active) -> ())
	table.insert(listeners, fn)
end

-- Le bootstrap branche ici le versement de la récompense, pour qu'EventService
-- n'ait pas à connaître EconomyService (qui, lui, reçoit déjà le multiplicateur
-- d'événement : la boucle serait circulaire).
function EventService.onReward(fn: (Player, number) -> ())
	table.insert(rewardHandlers, fn)
end

function EventService.active(): Active?
	return current
end

function EventService.rewardMultiplier(): number
	return current and current.RewardMultiplier or 1
end

-- ── défi collectif ────────────────────────────────────────────────────────
function EventService.collectiveState()
	local target = GameConfig.Events.Collective
	local open = current ~= nil and current.Collective
	return {
		Open = open,
		Sessions = collective.Sessions,
		Target = target.Sessions,
		Deaths = collective.Deaths,
		MaxDeaths = target.MaxDeaths,
		Failed = collective.Failed,
		Done = open and not collective.Failed and collective.Sessions >= target.Sessions,
	}
end

function EventService.noteSession()
	if not current or not current.Collective or collective.Failed then
		return
	end
	collective.Sessions += 1
end

function EventService.noteDeath()
	if not current or not current.Collective or collective.Failed then
		return
	end
	collective.Deaths += 1
	if collective.Deaths > GameConfig.Events.Collective.MaxDeaths then
		collective.Failed = true
	end
end

-- ── mini-boss ─────────────────────────────────────────────────────────────
local function clearMiniBoss()
	if miniBoss then
		MonsterService.despawn(miniBoss.Model)
		miniBoss = nil
	end
end

function EventService.miniBossAlive(): boolean
	return miniBoss ~= nil and miniBoss.Model.Parent ~= nil
end

-- Appelé par le bootstrap quand un joueur frappe un monstre tagué MiniBoss.
-- Renvoie (tombé, nom) : le bootstrap n'a qu'à relayer.
function EventService.registerMiniBossHit(player: Player, model: Model): (boolean, string)
	if not miniBoss or miniBoss.Model ~= model then
		return false, ""
	end
	local known = false
	for _, existing in ipairs(miniBoss.Players) do
		if existing == player then
			known = true
			break
		end
	end
	if not known then
		table.insert(miniBoss.Players, player)
	end

	miniBoss.Hits += 1
	if miniBoss.Hits < GameConfig.Events.MiniBoss.Hits then
		return false, ""
	end

	local participants = table.clone(miniBoss.Players)
	local name = miniBoss.Label
	clearMiniBoss()
	for _, participant in ipairs(participants) do
		local profile = PlayerDataService.get(participant)
		if profile then
			-- L'exploit ouvre le skin de l'événement. Il ne s'achète pas : un
			-- skin qu'on ne peut qu'obtenir vaut plus qu'un skin à 299 Robux.
			profile.Achievements.miniboss_down = true
			PlayerDataService.markDirty(participant)
		end
	end
	return true, name
end

-- Fait naître le mini-boss dans une zone occupée, s'il n'y en a pas déjà un.
local function tendMiniBoss()
	if not current or not current.MiniBoss then
		clearMiniBoss()
		return
	end
	if miniBoss then
		if miniBoss.Model.Parent then
			return
		end
		-- Mort par une autre voie (étourdi hors limite, zone nettoyée) :
		-- on oublie celui-là, le suivant pourra naître.
		miniBoss = nil
	end

	for _, zone in ipairs(ZoneConfig.List) do
		-- Jamais dans la zone du boss. Sans ce garde, un événement « toutes
		-- zones » pouvait faire naître un clown démesuré dans l'arène pendant
		-- le vrai combat en trois phases : deux clowns, dont un qui ne suit
		-- aucune des mécaniques que le joueur vient d'apprendre.
		local def = MonsterConfig.get(zone.Monster)
		if def and def.Rule ~= "boss_phases"
			and (current.Zone == "any" or current.Zone == zone.Id)
			and WorldService.occupied(zone.Id) then
			local model, label = WorldService.spawnMiniBoss(zone.Id)
			if model then
				miniBoss = { Model = model, Label = label, Hits = 0, Players = {} }
				return
			end
		end
	end
end

-- ── rotation ──────────────────────────────────────────────────────────────
local function pick()
	local list = GameConfig.Events.List
	local chosen = list[math.random(1, #list)]
	current = {
		Id = chosen.Id,
		Name = chosen.Name,
		Text = chosen.Text,
		Zone = chosen.Zone or "any",
		RewardMultiplier = chosen.RewardMultiplier or 1,
		MonsterMultiplier = chosen.MonsterMultiplier or 1,
		MonsterSpeed = chosen.MonsterSpeed or 1,
		MiniBoss = chosen.MiniBoss == true,
		Collective = chosen.Collective == true,
		StartedAt = os.time(),
		-- La période rend la clé de récompense unique : même événement demain,
		-- récompense à nouveau réclamable, mais pas deux fois dans l'heure.
		Period = os.date("!%Y%m%d%H"),
	}

	-- Les effets s'appliquent AVANT d'annoncer : un joueur qui lit « les gains
	-- montent, la rue devient invivable » doit déjà jouer contre cette rue.
	MonsterService.applyEvent((current :: Active).MonsterSpeed,
		(current :: Active).MonsterMultiplier, (current :: Active).Zone)
	collective.Sessions, collective.Deaths, collective.Failed = 0, 0, false
	clearMiniBoss()

	for _, fn in ipairs(listeners) do
		task.spawn(fn, current :: Active)
	end
end

-- ── réclamation ───────────────────────────────────────────────────────────
-- Renvoie (réussi, message). Un défi collectif non rempli refuse, en disant
-- où en est le serveur : c'est l'information qui pousse les joueurs à se parler.
function EventService.claim(player: Player): (boolean, string)
	local profile = PlayerDataService.get(player)
	if not profile or not current then
		return false, "Aucun événement en cours."
	end

	if current.Collective then
		local state = EventService.collectiveState()
		if state.Failed then
			return false, ("Défi collectif perdu : %d morts sur le serveur (%d permises). "
				.. "Rendez-vous au prochain événement."):format(state.Deaths, state.MaxDeaths)
		end
		if not state.Done then
			return false, ("Défi collectif : %d sessions tenues sur %d. Il en manque %d.")
				:format(state.Sessions, state.Target, state.Target - state.Sessions)
		end
	end

	local key = "ev_" .. current.Id .. "_" .. current.Period
	if profile.Achievements[key] then
		return false, "Déjà réclamé pour cet événement."
	end
	profile.Achievements[key] = true
	PlayerDataService.markDirty(player)

	local amount = math.floor(GameConfig.Events.ClaimBase * current.RewardMultiplier)
	for _, fn in ipairs(rewardHandlers) do
		task.spawn(fn, player, amount)
	end
	return true, current.Name
end

function EventService.init()
	pick()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Events.RotationSeconds)
			pick()
		end
	end)
	-- Le mini-boss est surveillé à part : il doit pouvoir naître quand un
	-- joueur entre dans une zone bien après le début de l'événement.
	--
	-- Le contrôle passe AVANT l'attente, et pas après. Avec l'attente en
	-- premier, un joueur déjà sur place au lancement de l'événement voyait le
	-- mini-boss arriver jusqu'à cinq secondes après l'annonce — un trou qui se
	-- remarque, puisque l'annonce dit « un mini-boss apparaît ».
	task.spawn(function()
		while true do
			local ok, err = pcall(tendMiniBoss)
			if not ok and GameConfig.Debug.Verbose then
				warn("[EventService] " .. tostring(err))
			end
			task.wait(5)
		end
	end)
end

-- Utilisé par le bootstrap pour reconnaître la cible d'un coup.
function EventService.isMiniBoss(model: Instance): boolean
	return CollectionService:HasTag(model, "MiniBoss")
end

return EventService
