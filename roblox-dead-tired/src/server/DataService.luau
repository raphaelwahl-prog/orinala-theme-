--[[
	DataService — sauvegarde persistante.

	Ce qui est persistant : l'argent déposé (Cash), le total déposé à vie
	(TotalBanked, qui débloque les planques) et l'inventaire de la boutique.

	Ce qui NE l'est PAS : l'argent non déposé de la nuit en cours. C'est voulu :
	si le serveur plante pendant que tu dors dans Le Nid, tu ne dois pas pouvoir
	garder la cagnotte sans l'avoir ramenée au coffre.

	⚠️  En Studio, les DataStores ne marchent que si tu as coché
	Game Settings → Security → "Enable Studio Access to API Services".
	Sinon le service bascule en mémoire : tu joues normalement, mais rien
	n'est gardé entre deux sessions. Un avertissement est affiché dans la console.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.GameConfig)

local DataService = {}

local STORE_NAME = "DeadTired_Profiles_v1"
local MAX_RETRIES = 4

local store: DataStore? = nil
local storeAvailable = false
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}

local function defaultProfile()
	return {
		Version = GameConfig.Misc.DataVersion,
		Cash = GameConfig.Economy.StartingCash,
		TotalBanked = 0,
		-- Items = { [itemId] = niveau ou stock }
		Items = {},
		-- Cosmetics = { Owned = { [id] = true }, Equipped = { [slot] = id } }
		Cosmetics = { Owned = {}, Equipped = {} },
		NightsSurvived = 0,
		DeepestTier = 1,
	}
end

--[[ Réessaie une opération DataStore avec un back-off simple. ]]
local function retry(label: string, fn)
	local delayTime = 0.6
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[DataService] %s a échoué (essai %d/%d) : %s"):format(label, attempt, MAX_RETRIES, tostring(result)))
		if attempt < MAX_RETRIES then
			task.wait(delayTime)
			delayTime *= 2
		end
	end
	return false, nil
end

local function keyFor(player: Player): string
	return "u_" .. tostring(player.UserId)
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		store = result
		storeAvailable = true
	else
		storeAvailable = false
		warn("[DataService] DataStore indisponible — les parties ne seront pas sauvegardées. "
			.. "En Studio : Game Settings → Security → Enable Studio Access to API Services.")
	end
end

--[[ Charge (ou crée) le profil d'un joueur. Bloquant. ]]
function DataService.load(player: Player)
	if profiles[player] then
		return profiles[player]
	end
	loading[player] = true

	local profile = defaultProfile()

	if storeAvailable and store then
		local ok, saved = retry("chargement " .. player.Name, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok and type(saved) == "table" then
			if saved.Version == GameConfig.Misc.DataVersion then
				profile = saved
				profile.Items = profile.Items or {}
			else
				warn(("[DataService] sauvegarde de %s en version %s, réinitialisée (version attendue %d)")
					:format(player.Name, tostring(saved.Version), GameConfig.Misc.DataVersion))
			end
		end
	end

	-- Le joueur est peut-être parti pendant le chargement.
	if not player.Parent then
		loading[player] = nil
		return nil
	end

	profiles[player] = profile
	loading[player] = nil
	return profile
end

--[[ Récupère le profil en mémoire. nil si pas encore chargé. ]]
function DataService.get(player: Player)
	return profiles[player]
end

--[[ Écrit le profil. UpdateAsync pour ne pas écraser une écriture concurrente. ]]
function DataService.save(player: Player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not (storeAvailable and store) then
		return false
	end

	local ok = retry("sauvegarde " .. player.Name, function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			-- On ne garde que la valeur la plus avantageuse pour le joueur sur
			-- TotalBanked : ça évite qu'un serveur en retard efface sa progression.
			if type(old) == "table" and old.Version == profile.Version then
				profile.TotalBanked = math.max(profile.TotalBanked, old.TotalBanked or 0)
			end
			return profile
		end)
	end)
	return ok
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
end

function DataService.isAvailable(): boolean
	return storeAvailable
end

function DataService.start()
	-- Autosauvegarde.
	task.spawn(function()
		while true do
			task.wait(GameConfig.Misc.AutosaveInterval)
			for player in pairs(profiles) do
				DataService.save(player)
			end
		end
	end)

	-- Dernière chance avant fermeture du serveur.
	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(DataService.save, player)
		end
		task.wait(3)
	end)
end

return DataService
