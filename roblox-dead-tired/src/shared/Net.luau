--!strict
--[[
	Création et accès aux Remotes.

	Le serveur appelle Net.build() une fois au démarrage : ça crée le dossier
	ReplicatedStorage/Net avec tous les RemoteEvent / RemoteFunction.
	Le client appelle Net.get("NomDuRemote") et attend si besoin.

	Avoir la liste au même endroit évite les fautes de frappe silencieuses :
	si tu demandes un remote qui n'existe pas dans la liste, ça lève une erreur
	immédiate au lieu de bloquer indéfiniment.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- Serveur → client
Net.Events = {
	"StateUpdate", -- état complet du joueur (argent, inventaire, sommeil…)
	"RoundUpdate", -- phase + temps restant
	"Notify", -- message à l'écran
	"DangerAlert", -- réveil d'alerte : le monstre arrive
	"SleepChanged", -- entré / sorti de sommeil (le client bloque les contrôles)
	"ShopResult", -- retour d'un achat
}

-- Client → serveur
-- Note : il n'y a pas de "RequestSleep". S'endormir passe par le ProximityPrompt
-- de la planque, dont l'événement Triggered est écouté côté SERVEUR : le client
-- n'a donc aucun moyen de prétendre dormir dans une planque où il n'est pas.
Net.Requests = {
	"RequestWake",
	"RequestBank",
	"RequestBuy", -- { itemId: string }
	"RequestRevive", -- { target: Player }
}

-- RemoteFunction (client demande, serveur répond)
Net.Functions = {
	"GetCatalog",
}

local FOLDER_NAME = "Net"

local function ensureFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

--[[ Serveur uniquement : crée tous les remotes. Idempotent. ]]
function Net.build(): Folder
	assert(RunService:IsServer(), "Net.build() ne doit être appelé que côté serveur")
	local folder = ensureFolder()

	local function make(className: string, name: string)
		if folder:FindFirstChild(name) then
			return
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end

	for _, name in ipairs(Net.Events) do
		make("RemoteEvent", name)
	end
	for _, name in ipairs(Net.Requests) do
		make("RemoteEvent", name)
	end
	for _, name in ipairs(Net.Functions) do
		make("RemoteFunction", name)
	end

	return folder
end

local function isKnown(name: string): boolean
	for _, list in ipairs({ Net.Events, Net.Requests, Net.Functions }) do
		for _, candidate in ipairs(list) do
			if candidate == name then
				return true
			end
		end
	end
	return false
end

--[[ Récupère un remote par son nom. Attend qu'il existe (client au démarrage). ]]
function Net.get(name: string): Instance
	if not isKnown(name) then
		error(("Remote inconnu : %q — ajoute-le dans Net.luau"):format(name), 2)
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 20)
	if not folder then
		error("Le dossier Net n'a jamais été créé — le serveur a-t-il démarré ?", 2)
	end
	local remote = folder:WaitForChild(name, 20)
	if not remote then
		error(("Remote %q absent du dossier Net"):format(name), 2)
	end
	return remote
end

return Net
