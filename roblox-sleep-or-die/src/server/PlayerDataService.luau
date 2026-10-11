--!strict
-- §11 — profils joueurs et DataStore.
--
-- Règle qui compte le plus (CDC §11) : « Si les données ne peuvent pas être
-- chargées, le jeu ne doit pas écraser les données existantes avec un profil
-- vide. » C'est le rôle de `profile.Loaded`. Tant qu'il est faux, aucune
-- sauvegarde n'est écrite pour ce joueur, et il joue en lecture seule.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.Parent.Shared.GameConfig)

local PlayerDataService = {}

export type Profile = {
	Loaded: boolean,
	Dirty: boolean,
	LastSave: number,

	Cash: number,
	UnbankedCash: number,
	LifetimeBanked: number,

	Zones: { [string]: boolean },
	CurrentZone: string,
	Quests: { [string]: boolean },

	Inventory: { [string]: number },
	Placed: { [string]: number },

	Missions: { [string]: number },      -- id → progression
	MissionsDone: { [string]: boolean },
	MainMissions: number,

	MonstersSeen: { [string]: boolean },
	Cosmetics: { [string]: boolean },
	Skin: string,
	Achievements: { [string]: boolean },

	SurvivalSeconds: number,
	NightsSurvived: number,
	Deaths: number,
	BossesBeaten: number,

	DailyKey: string,
	DailyProgress: { [string]: number },
	WeeklyKey: string,
	WeeklyProgress: { [string]: number },

	Receipts: { [string]: boolean },     -- anti-doublon ProcessReceipt
	MultiplierUntil: number,
	Multiplier: number,

	-- §9 — les réglages de l'écran de paramètres. Ils vivent dans le profil et
	-- pas côté client : un joueur photosensible qui coupe les flashs ne doit
	-- pas avoir à le refaire depuis son téléphone.
	Settings: { [string]: boolean },
}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}

local function defaultSettings(): { [string]: boolean }
	local settings = {}
	for _, entry in ipairs(GameConfig.Ui.Settings) do
		settings[entry.Id] = entry.Default
	end
	return settings
end

local function blank(): Profile
	return {
		Loaded = false, Dirty = false, LastSave = 0,
		Cash = GameConfig.Economy.StartingCash,
		UnbankedCash = 0,
		LifetimeBanked = 0,
		Zones = { street = true },
		CurrentZone = "street",
		Quests = {},
		Inventory = {},
		Placed = {},
		Missions = {},
		MissionsDone = {},
		MainMissions = 0,
		MonstersSeen = {},
		Cosmetics = { default = true },
		Skin = "default",
		Achievements = {},
		SurvivalSeconds = 0,
		NightsSurvived = 0,
		Deaths = 0,
		BossesBeaten = 0,
		DailyKey = "",
		DailyProgress = {},
		WeeklyKey = "",
		WeeklyProgress = {},
		Receipts = {},
		MultiplierUntil = 0,
		Multiplier = 1,
		Settings = defaultSettings(),
	}
end

-- Recopie champ par champ : une sauvegarde d'une version précédente peut ne pas
-- contenir toutes les clés, et un `profile = saved` effacerait les nouvelles.
local function merge(profile: Profile, saved: any)
	if type(saved) ~= "table" then
		return
	end
	for key, value in pairs(saved) do
		if profile[key] ~= nil and type(profile[key]) == type(value) then
			profile[key] = value
		end
	end
	profile.Zones = profile.Zones or {}
	profile.Zones.street = true

	-- `merge` remplace la table entière : une sauvegarde faite avant l'ajout
	-- d'un réglage n'en contient pas la clé, et ce réglage serait alors `nil`
	-- au lieu de sa valeur par défaut. On recomplète, clé par clé.
	profile.Settings = profile.Settings or {}
	for _, entry in ipairs(GameConfig.Ui.Settings) do
		if type(profile.Settings[entry.Id]) ~= "boolean" then
			profile.Settings[entry.Id] = entry.Default
		end
	end
end

local function key(player: Player): string
	return "p_" .. tostring(player.UserId)
end

local function retry<T>(fn: () -> T): (boolean, T?)
	local delay = 1
	for attempt = 1, GameConfig.Data.MaxRetries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < GameConfig.Data.MaxRetries then
			task.wait(delay)
			delay *= GameConfig.Data.RetryBackoff
		else
			warn("[PlayerDataService] échec après " .. attempt .. " essais : " .. tostring(result))
		end
	end
	return false, nil
end

function PlayerDataService.init()
	if RunService:IsStudio() then
		-- En Studio sans accès API, GetDataStore lève. On joue alors en mémoire.
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(GameConfig.Data.StoreName)
		end)
		store = ok and result or nil
		if not store then
			warn("[PlayerDataService] DataStore indisponible (Studio) : profils en mémoire.")
		end
	else
		store = DataStoreService:GetDataStore(GameConfig.Data.StoreName)
	end
end

function PlayerDataService.load(player: Player): Profile
	local profile = blank()
	profiles[player] = profile

	if not store then
		profile.Loaded = true   -- mode mémoire : on accepte d'écrire (dans le vide)
		return profile
	end

	local ok, saved = retry(function()
		return (store :: DataStore):GetAsync(key(player))
	end)

	if ok then
		merge(profile, saved)
		profile.Loaded = true
	else
		-- Lecture impossible : le joueur joue, mais on n'écrasera rien.
		profile.Loaded = false
		warn("[PlayerDataService] profil non chargé pour " .. player.Name ..
			" — sauvegarde désactivée pour cette session.")
	end
	return profile
end

function PlayerDataService.get(player: Player): Profile?
	return profiles[player]
end

function PlayerDataService.markDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

function PlayerDataService.save(player: Player, force: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.Loaded then
		return false
	end
	if not force and not profile.Dirty then
		return false
	end
	if not store then
		profile.Dirty = false
		return true
	end

	-- On recopie les champs persistants, sans les drapeaux de session.
	local payload = {}
	for field, value in pairs(profile) do
		if field ~= "Loaded" and field ~= "Dirty" and field ~= "LastSave" then
			payload[field] = value
		end
	end

	local ok = retry(function()
		-- UpdateAsync plutôt que SetAsync : si deux serveurs écrivent en même
		-- temps (reconnexion rapide), le dernier lu gagne proprement.
		(store :: DataStore):UpdateAsync(key(player), function(_old)
			return payload
		end)
		return true
	end)

	if ok then
		profile.Dirty = false
		profile.LastSave = os.clock()
	end
	return ok
end

function PlayerDataService.release(player: Player)
	PlayerDataService.save(player, true)
	profiles[player] = nil
end

function PlayerDataService.all(): { [Player]: Profile }
	return profiles
end

function PlayerDataService.startAutosave()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				PlayerDataService.save(player, false)
			end
		end
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerDataService.save(player, true)
		end
		task.wait(1)
	end)
end

return PlayerDataService
