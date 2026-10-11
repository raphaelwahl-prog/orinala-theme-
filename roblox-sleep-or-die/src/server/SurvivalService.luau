--!strict
-- §2 et §4 — la session de survie : la boucle centrale du jeu.
--
-- Une session démarre quand le joueur dort dans SON refuge. Elle crédite
-- l'argent non sécurisé seconde par seconde, et s'arrête à la mort, à la
-- déconnexion, au réveil volontaire, ou au bout de MaxSessionSeconds.
--
-- Le CDC §2 dit : « Le jeu ne doit pas devenir un simple système de farming
-- passif ». Trois choses l'empêchent ici :
--   · la session a une durée maximale, après quoi il faut se lever et déposer ;
--   · des assauts arrivent à intervalle irrégulier et demandent une réaction ;
--   · le plafond souple d'EconomyService divise le taux au-delà d'un seuil.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EconomyService = require(script.Parent.EconomyService)
local EndgameService = require(script.Parent.EndgameService)
local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)
local AwakeningService = require(script.Parent.AwakeningService)
local ShelterService = require(script.Parent.ShelterService)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)

local SurvivalService = {}

export type Session = {
	Player: Player,
	ZoneId: string,
	ShelterId: string,
	StartedAt: number,
	EligibleSeconds: number,
	Earned: number,
	NextAssault: number,
	Carry: number,           -- fraction de seconde en attente
}

local sessions: { [Player]: Session } = {}
local listeners: { (Player, Session?, string) -> () } = {}
local assaultHandlers: { (Session) -> () } = {}

function SurvivalService.onChanged(fn: (Player, Session?, string) -> ())
	table.insert(listeners, fn)
end

function SurvivalService.onAssault(fn: (Session) -> ())
	table.insert(assaultHandlers, fn)
end

local function fire(player: Player, session: Session?, reason: string)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, player, session, reason)
	end
end

function SurvivalService.get(player: Player): Session?
	return sessions[player]
end

local function scheduleAssault(session: Session)
	local jitter = (math.random() * 2 - 1) * GameConfig.Survival.AssaultJitter
	session.NextAssault = os.clock() + GameConfig.Survival.BaseAssaultInterval + jitter
end

function SurvivalService.start(player: Player): (boolean, string)
	if sessions[player] then
		return false, "Tu dors déjà."
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return false, "Profil introuvable."
	end
	local shelter = ShelterService.ownedBy(player)
	if not shelter then
		return false, "Il te faut un refuge réservé."
	end
	local zone = ZoneConfig.get(shelter.ZoneId)
	if not zone then
		return false, "Zone inconnue."
	end
	if not profile.Zones[zone.Id] then
		return false, "Cette zone n'est pas débloquée."
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Pas dans cet état."
	end

	local session: Session = {
		Player = player, ZoneId = zone.Id, ShelterId = shelter.Id,
		StartedAt = os.clock(), EligibleSeconds = 0, Earned = 0,
		NextAssault = 0, Carry = 0,
	}
	scheduleAssault(session)
	sessions[player] = session
	ShelterService.setOccupied(player, true)
	profile.CurrentZone = zone.Id
	PlayerDataService.markDirty(player)
	-- §8 — le défi armé devient la règle de CETTE session. Appelé après
	-- l'enregistrement de la session : avant, `beginSession` parlerait d'une
	-- session qui pourrait encore échouer à démarrer.
	EndgameService.beginSession(player)
	fire(player, session, "start")
	return true, "Bonne nuit."
end

function SurvivalService.stop(player: Player, reason: string): Session?
	local session = sessions[player]
	if not session then
		return nil
	end
	sessions[player] = nil
	ShelterService.setOccupied(player, false)

	local profile = PlayerDataService.get(player)
	if profile then
		profile.SurvivalSeconds += session.EligibleSeconds
		-- Une « nuit survécue » = une session menée jusqu'à son terme sans mourir.
		if reason == "complete" then
			profile.NightsSurvived += 1
		end
		PlayerDataService.markDirty(player)
	end

	-- §8 — avant `fire`, pour que l'état poussé au client porte déjà le
	-- résultat du défi et l'éventuel contrat tiré.
	EndgameService.endSession(player, reason, session.ZoneId)
	fire(player, session, reason)
	return session
end

local function tick(dt: number)
	for player, session in pairs(sessions) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player.Parent or not humanoid or humanoid.Health <= 0 then
			SurvivalService.stop(player, "interrupted")
			continue
		end

		ShelterService.touch(player)

		local elapsed = os.clock() - session.StartedAt
		-- §8, défi « TOUT OU RIEN » : pas de délai de grâce. Les gains partent
		-- à la première seconde, et la mort prend tout (LifeService).
		local grace = EndgameService.hasRule(player, "all_in")
			and 0 or GameConfig.Survival.GraceSeconds
		if elapsed < grace then
			continue
		end

		-- On crédite par pas d'une seconde : c'est ce que le CDC appelle la
		-- « durée de survie réellement éligible ».
		session.Carry += dt
		if session.Carry >= GameConfig.Economy.PayoutInterval then
			local whole = math.floor(session.Carry / GameConfig.Economy.PayoutInterval)
			local seconds = whole * GameConfig.Economy.PayoutInterval
			session.Carry -= seconds
			session.EligibleSeconds += seconds
			session.Earned += EconomyService.accrue(player, session.ZoneId, seconds, session.Earned)
			-- Chaque seconde de sommeil profond réveille un peu la maison,
			-- pour tout le monde.
			AwakeningService.feed(session.ZoneId, seconds)
		end

		if os.clock() >= session.NextAssault then
			scheduleAssault(session)
			for _, fn in ipairs(assaultHandlers) do
				task.spawn(fn, session)
			end
			-- §8, défi « SOMMEIL LÉGER » : le premier assaut met fin à la
			-- session. Le joueur garde ce qu'il a gagné — `stop` ne retire
			-- rien — mais la session n'est pas « complète » pour autant.
			if EndgameService.hasRule(player, "light_sleep") then
				SurvivalService.stop(player, "challenge")
				continue
			end
		end

		local zone = ZoneConfig.get(session.ZoneId)
		if zone and session.EligibleSeconds >= zone.MaxSessionSeconds then
			SurvivalService.stop(player, "complete")
		end
	end
end

function SurvivalService.init()
	RunService.Heartbeat:Connect(tick)

	Players.PlayerRemoving:Connect(function(player)
		if sessions[player] then
			SurvivalService.stop(player, "disconnect")
		end
		EconomyService.applyDisconnect(player)
	end)
end

function SurvivalService.onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local session = sessions[player]
		local zoneId = session and session.ZoneId
			or (PlayerDataService.get(player) and (PlayerDataService.get(player) :: any).CurrentZone)
			or "street"
		if session then
			SurvivalService.stop(player, "death")
		end
		EconomyService.applyDeath(player, zoneId)
	end)
end

return SurvivalService
