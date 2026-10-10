--!strict
-- Tous les RemoteEvents / RemoteFunctions du jeu, déclarés au même endroit.
-- Le serveur les crée au démarrage ; le client ne fait que les attendre.
-- Aucun remote ne transporte de montant d'argent depuis le client : le client
-- demande une action, le serveur décide et répond.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.Events = {
	-- serveur → client
	"StateChanged",      -- profil complet (argent, zones, inventaire, missions)
	"Alert",             -- message d'alerte (son/lumière côté client)
	"SessionChanged",    -- début/fin de session de survie
	"ShelterChanged",    -- état d'un refuge
	"MonsterSignal",     -- signal visuel/sonore d'un monstre
	"EventChanged",      -- événement serveur actif
	"AwakeningChanged",  -- jauge d'éveil partagée
	"DownedChanged",     -- un joueur à terre, et le temps qu'il lui reste
	"DeathReport",       -- bilan de mort
	-- client → serveur
	"RequestClaim",      -- réserver un refuge
	"RequestSleep",      -- démarrer une session
	"RequestWake",       -- se réveiller
	"RequestBank",       -- déposer l'argent non sécurisé
	"RequestBuy",        -- acheter un objet
	"RequestPlace",      -- poser une défense dans son refuge
	"RequestRepair",     -- réparer une défense
	"RequestEnterZone",  -- entrer dans une zone
	"RequestAttack",     -- frapper un monstre
	"RequestMission",    -- accepter / rendre une mission
	"RequestPurchase",   -- ouvrir une fenêtre d'achat Robux
	"RequestCosmetic",   -- débloquer ou équiper un skin
}

local cache: { [string]: RemoteEvent } = {}

-- Appelé une seule fois par le serveur.
function Net.build()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(Net.Events) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Net.get(name: string): RemoteEvent
	local cached = cache[name]
	if cached then
		return cached
	end
	local folder = ReplicatedStorage:WaitForChild("Remotes", 20) :: Folder
	local remote = folder:WaitForChild(name, 20) :: RemoteEvent
	cache[name] = remote
	return remote
end

return Net
