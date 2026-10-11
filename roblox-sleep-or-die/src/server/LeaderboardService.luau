--!strict
-- §8 — les classements saisonniers.
--
-- Trois classements (argent déposé, nuits survécues, boss battus), remis à zéro
-- à chaque saison. Une saison = un mois civil UTC : assez court pour qu'un
-- nouveau joueur puisse viser la tête, assez long pour que le classement veuille
-- dire quelque chose.
--
-- Trois règles que ce service se donne, et qui expliquent presque tout le code :
--
--   1. **Il ne publie jamais un profil non chargé.** Un joueur dont les données
--      n'ont pas pu être lues a un profil vide. Le publier écraserait son vrai
--      score par un zéro — exactement la faute que `profile.Loaded` existe pour
--      empêcher côté sauvegarde.
--   2. **Il ne lève jamais.** Un OrderedDataStore indisponible, un quota
--      dépassé, une saison qui change pendant une lecture : rien de tout ça ne
--      doit casser une partie. Tout est sous `pcall`, et en cas d'échec on
--      retombe sur les joueurs présents.
--   3. **Il ne bloque jamais la boucle de jeu.** Les lectures et écritures sont
--      des appels qui cèdent la main ; elles tournent dans leurs propres
--      tâches, à une cadence fixée par GameConfig (quotas Roblox).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local LeaderboardService = {}

export type Entry = { Rank: number, Name: string, Value: number, IsMe: boolean }

local config = GameConfig.Leaderboards

-- Classements en cache, par identifiant de classement.
local cache: { [string]: { Entry } } = {}
local names: { [number]: string } = {}
local published: { [number]: { [string]: number } } = {}
local available = true
local seasonId = ""

function LeaderboardService.season(): string
	return os.date("!%Y-%m")
end

function LeaderboardService.boards()
	return config.Boards
end

-- Bascule en mode dégradé, une fois pour toutes, en le disant une seule fois.
--
-- ⚠️ Le piège, et il est facile à manquer : en Studio sans accès API,
-- `GetOrderedDataStore` **ne lève pas**. Il rend un objet parfaitement normal,
-- et c'est seulement `GetSortedAsync` / `SetAsync` qui échouent. Si on ne
-- déclarait le mode dégradé qu'à l'échec de `GetOrderedDataStore`, le service
-- retomberait bien sur les joueurs présents (les pcall font leur travail) mais
-- `view.Local` resterait faux : l'écran afficherait six joueurs du serveur
-- comme s'ils étaient le classement mondial. C'est donc ici, et depuis chaque
-- appel qui échoue, qu'on le constate.
local function degrade(what: string, err: any)
	if available then
		available = false
		warn("[LeaderboardService] stockage classé indisponible (" .. what .. " : "
			.. tostring(err) .. ") — classements limités aux joueurs présents.")
	end
end

local function storeFor(boardId: string): OrderedDataStore?
	if not available then
		return nil
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(config.StoreName .. "_" .. boardId,
			LeaderboardService.season())
	end)
	if not ok then
		degrade("ouverture", store)
		return nil
	end
	return store
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = (ok and type(result) == "string") and result or ("Joueur " .. userId)
	names[userId] = resolved
	return resolved
end

-- Repli : le classement des joueurs actuellement sur le serveur. Ce n'est pas
-- le vrai classement, et l'interface le dit (`Local = true`) — mieux vaut un
-- tableau honnêtement partiel qu'un tableau vide.
local function localBoard(board): { Entry }
	local rows = {}
	for player, profile in pairs(PlayerDataService.all()) do
		if profile.Loaded then
			-- Lecture par nom de champ : le type Profile est une table typée,
			-- on passe donc par `any` pour que l'analyse de Studio ne crie pas
			-- sur un accès qu'elle ne peut pas vérifier statiquement.
			local value = (profile :: any)[board.Field]
			if type(value) == "number" and value > 0 then
				table.insert(rows, { Name = player.Name, Value = value, UserId = player.UserId })
			end
		end
	end
	table.sort(rows, function(a, b)
		return a.Value > b.Value
	end)
	local entries: { Entry } = {}
	for index, row in ipairs(rows) do
		if index > config.Size then
			break
		end
		table.insert(entries, { Rank = index, Name = row.Name, Value = row.Value, IsMe = false })
	end
	return entries
end

local function refresh(board)
	local store = storeFor(board.Id)
	if not store then
		cache[board.Id] = localBoard(board)
		return
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, config.Size)
	end)
	if not ok or not pages then
		degrade("lecture " .. board.Id, pages)
		cache[board.Id] = localBoard(board)
		return
	end
	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or type(page) ~= "table" then
		cache[board.Id] = localBoard(board)
		return
	end

	local entries: { Entry } = {}
	for index, row in ipairs(page) do
		local userId = tonumber(row.key) or 0
		table.insert(entries, {
			Rank = index,
			Name = nameOf(userId),
			Value = row.value,
			IsMe = false,
		})
	end
	cache[board.Id] = entries
end

-- Écrit le score d'un joueur, pour chaque classement, s'il a bougé.
function LeaderboardService.publish(player: Player)
	local profile = PlayerDataService.get(player)
	-- Règle 1 : jamais un profil non chargé.
	if not profile or not profile.Loaded then
		return
	end
	local seen = published[player.UserId]
	if not seen then
		seen = {}
		published[player.UserId] = seen
	end

	for _, board in ipairs(config.Boards) do
		local value = (profile :: any)[board.Field]
		if type(value) == "number" then
			local rounded = math.floor(value)
			-- OrderedDataStore n'accepte que des entiers positifs.
			if rounded > 0 and seen[board.Id] ~= rounded then
				local store = storeFor(board.Id)
				if store then
					local ok, err = pcall(function()
						(store :: OrderedDataStore):SetAsync(tostring(player.UserId), rounded)
					end)
					if ok then
						seen[board.Id] = rounded
					else
						degrade("écriture " .. board.Id, err)
					end
				else
					seen[board.Id] = rounded
				end
			end
		end
	end
end

function LeaderboardService.forget(player: Player)
	published[player.UserId] = nil
end

-- Tout ce qu'il faut pour dessiner l'écran, du point de vue d'un joueur.
function LeaderboardService.view(player: Player)
	local profile = PlayerDataService.get(player)
	local boards = {}
	for _, board in ipairs(config.Boards) do
		local entries = {}
		for _, entry in ipairs(cache[board.Id] or {}) do
			table.insert(entries, {
				Rank = entry.Rank, Name = entry.Name, Value = entry.Value,
				IsMe = entry.Name == player.Name,
			})
		end
		-- Le score du joueur, pas son rang : connaître son rang exact
		-- demanderait de parcourir tout le classement à chaque ouverture.
		-- Afficher un rang approximatif serait un mensonge d'interface.
		local mine = profile and (profile :: any)[board.Field] or 0
		table.insert(boards, {
			Id = board.Id, Name = board.Name, Kind = board.Kind,
			Entries = entries,
			Mine = type(mine) == "number" and math.floor(mine) or 0,
		})
	end
	return {
		Season = seasonId ~= "" and seasonId or LeaderboardService.season(),
		Local = not available,
		Boards = boards,
	}
end

function LeaderboardService.init()
	seasonId = LeaderboardService.season()

	task.spawn(function()
		while true do
			for _, board in ipairs(config.Boards) do
				local ok, err = pcall(refresh, board)
				if not ok and GameConfig.Debug.Verbose then
					warn("[LeaderboardService] lecture " .. board.Id .. " : " .. tostring(err))
				end
			end
			-- Changement de saison en cours de partie : les classements
			-- repartent de zéro sans redémarrer le serveur, et les scores déjà
			-- publiés doivent l'être à nouveau dans la nouvelle saison.
			local now = LeaderboardService.season()
			if now ~= seasonId then
				seasonId = now
				published = {}
			end
			task.wait(config.RefreshSeconds)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(config.PublishSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(LeaderboardService.publish, player)
				if not ok and GameConfig.Debug.Verbose then
					warn("[LeaderboardService] écriture " .. player.Name .. " : " .. tostring(err))
				end
			end
		end
	end)
end

return LeaderboardService
