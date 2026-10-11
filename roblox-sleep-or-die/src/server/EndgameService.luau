--!strict
-- §8 — les quatre mécaniques d'après-boss : variantes, défis, contrats,
-- collections. Le catalogue est dans `EndgameConfig` ; ici, ce qui agit.
--
-- La règle que je me suis donnée sur ce dépôt — « si ce n'est pas branché,
-- c'est pas fait » — vaut surtout ici, parce que le §13 avait précisément ce
-- défaut : une configuration complète, un calcul correct, et personne qui
-- l'appelait. Donc chaque chose de ce fichier a un appelant nommé dans
-- `init.server.luau`, et `tools/logictests.py` l'exécute.
--
-- La porte commune est `Achievements.carnival_cleared`, posée par
-- `BossService.finish`. Elle est lue à UN seul endroit, `unlocked`.

local Players = game:GetService("Players")

local EndgameConfig = require(script.Parent.Parent.Shared.EndgameConfig)
local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)
local MonsterService = require(script.Parent.MonsterService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EndgameService = {}

local alertHandlers: { (Player, string, string) -> () } = {}
local changeHandlers: { (Player) -> () } = {}
local awakeningJolt: ((number) -> ())? = nil

-- Défi armé pour la session en cours, par joueur. Volontairement hors du
-- profil : un défi ne survit pas à une déconnexion, sinon on se reconnecte
-- avec une règle qu'on ne se souvient pas d'avoir choisie.
local armed: { [Player]: string } = {}
local running: { [Player]: string } = {}

-- Dernier à-coup d'éveil provoqué par un hurleur, par joueur.
--
-- Sans ça : LA POUPÉE s'arrête quand on la regarde (mécanique « gaze »), donc
-- fixer puis détourner le regard la fait repasser en poursuite à chaque
-- bascule. Un hurleur-poupée laisserait alors remplir la jauge d'éveil — qui
-- est PARTAGÉE par tout le serveur — en quelques secondes, en dérangeant tout
-- le monde depuis un seul couloir.
local lastHowl: { [Player]: number } = {}
local HOWL_COOLDOWN = 20

function EndgameService.onAlert(fn: (Player, string, string) -> ())
	table.insert(alertHandlers, fn)
end

function EndgameService.onChanged(fn: (Player) -> ())
	table.insert(changeHandlers, fn)
end

-- AwakeningService est injecté plutôt que requis : sans ça, Awakening →
-- Monster → Endgame → Awakening ferait un cycle de `require`.
function EndgameService.setAwakeningJolt(fn: (number) -> ())
	awakeningJolt = fn
end

local function tell(player: Player, text: string, kind: string)
	for _, fn in ipairs(alertHandlers) do
		task.spawn(fn, player, text, kind)
	end
end

local function changed(player: Player)
	for _, fn in ipairs(changeHandlers) do
		task.spawn(fn, player)
	end
end

-- ── la porte ──────────────────────────────────────────────────────────────

function EndgameService.unlocked(player: Player): boolean
	local profile = PlayerDataService.get(player)
	return profile ~= nil and profile.Achievements.carnival_cleared == true
end

-- Une variante peut naître dans une zone si au moins un joueur PRÉSENT dans
-- cette zone a battu le boss. Les monstres sont partagés par tout le serveur :
-- on ne peut pas faire apparaître une variante pour un joueur et pas pour son
-- voisin. Au moins, de cette façon, personne ne croise de variante avant
-- d'avoir ouvert le chapitre — et celui qui l'a ouvert les voit.
function EndgameService.variantsAllowedIn(zoneId: string): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerDataService.get(player)
		if profile and profile.Loaded and profile.CurrentZone == zoneId
			and profile.Achievements.carnival_cleared then
			return true
		end
	end
	return false
end

-- ── variantes ─────────────────────────────────────────────────────────────

-- Fabrique le def d'une variante à partir de celui du monstre de la zone.
-- Même procédé que le mini-boss d'événement : on clone, on multiplie, on
-- renomme. On ne touche JAMAIS au catalogue partagé, et `Id` reste celui du
-- monstre de base parce que c'est lui qui choisit la silhouette et les sons.
function EndgameService.applyVariant(def: MonsterConfig.Monster, variant: EndgameConfig.Variant)
	local copy = table.clone(def)
	copy.Name = def.Name .. " — " .. variant.Name
	copy.WalkSpeed = def.WalkSpeed * variant.Speed
	copy.SightRange = def.SightRange * variant.Sight
	copy.HearRange = def.HearRange * variant.Hear
	copy.Damage = math.max(1, math.floor(def.Damage * variant.Damage))
	copy.Height = def.Height * variant.Scale
	copy.GiveUpSeconds = def.GiveUpSeconds * variant.GiveUp
	if variant.Rule then
		copy.Rule = variant.Rule
	end
	return copy
end

-- Tirage d'une variante pour une apparition. Renvoie nil la plupart du temps :
-- c'est l'appelant (WorldService) qui fait naître le monstre normal dans ce
-- cas. Jamais d'erreur levée — une apparition de monstre ne doit pas pouvoir
-- échouer à cause du §8.
function EndgameService.rollVariant(zoneId: string): EndgameConfig.Variant?
	if not EndgameService.variantsAllowedIn(zoneId) then
		return nil
	end
	if math.random() >= GameConfig.Endgame.VariantChance then
		return nil
	end
	return EndgameConfig.draw(EndgameConfig.Variants, function(v)
		return v.Weight
	end)
end

-- Prime de zone : tant qu'une variante est en vie là où tu dors, ça paie plus.
-- C'est la contrepartie du risque, comme l'éveil. On prend la meilleure et on
-- ne les cumule pas : deux variantes dans une zone, c'est déjà assez dur.
function EndgameService.zoneBounty(zoneId: string): number
	local best = 1
	for _, id in ipairs(MonsterService.variantsInZone(zoneId)) do
		local variant = EndgameConfig.variant(id)
		if variant and variant.Bounty > best then
			best = variant.Bounty
		end
	end
	return best
end

-- Une variante est « croisée » quand elle t'a vu. Branché sur
-- `MonsterService.onDetect`, qui ne part qu'une fois par poursuite.
function EndgameService.noteDetect(player: Player, _monsterId: string, variantId: string?)
	if not variantId then
		return
	end
	local variant = EndgameConfig.variant(variantId)
	if not variant then
		return
	end

	-- LE HURLEUR réveille la maison d'un coup quand il repère quelqu'un.
	-- Un à-coup et non `feed` : `feed` multiplie par le rang de la zone, et ce
	-- rang vaut 0 dans la rue — le hurleur n'y réveillerait rien du tout.
	if variantId == "hurleur" and awakeningJolt then
		local now = os.clock()
		if now - (lastHowl[player] or -math.huge) >= HOWL_COOLDOWN then
			lastHowl[player] = now
			awakeningJolt(EndgameConfig.HowlerFeed)
		end
	end

	local profile = PlayerDataService.get(player)
	if not profile or not profile.Loaded then
		return
	end

	EndgameService.note(player, "variant_met", 1, nil, variantId)
	EndgameService.note(player, "variant_" .. variantId, 1)

	if not profile.Variants[variantId] then
		profile.Variants[variantId] = true
		PlayerDataService.markDirty(player)
		tell(player, variant.Name .. " — " .. variant.Tell, "unlock")
		EndgameService.checkTitles(player)
		changed(player)
	end
end

-- ── défis ─────────────────────────────────────────────────────────────────

-- On arme avant de dormir. `start` ne vérifie pas si le joueur dort : c'est
-- SurvivalService qui décide quand une session commence, et lui seul appelle
-- `beginSession`.
function EndgameService.arm(player: Player, challengeId: string?): (boolean, string)
	if not EndgameService.unlocked(player) then
		return false, "Les défis s'ouvrent après le carnaval."
	end
	if challengeId == nil or challengeId == "" then
		armed[player] = nil
		changed(player)
		return true, "Défi retiré."
	end
	local challenge = EndgameConfig.challenge(challengeId)
	if not challenge then
		return false, "Défi inconnu."
	end
	if running[player] then
		return false, "Tu es déjà en train d'en tenir un."
	end
	armed[player] = challengeId
	changed(player)
	return true, challenge.Name .. " armé. " .. challenge.Text
end

function EndgameService.armedChallenge(player: Player): string?
	return armed[player]
end

-- Le défi en cours — celui qui agit. `armed` est une intention, `running` est
-- une règle. Les séparer évite qu'un joueur arme un défi au milieu d'une
-- session pour en toucher le bonus sans en avoir subi les règles.
function EndgameService.activeChallenge(player: Player): EndgameConfig.Challenge?
	local id = running[player]
	return id and EndgameConfig.challenge(id) or nil
end

function EndgameService.beginSession(player: Player)
	local id = armed[player]
	if id and EndgameService.unlocked(player) and EndgameConfig.challenge(id) then
		running[player] = id
		local challenge = EndgameConfig.challenge(id) :: EndgameConfig.Challenge
		tell(player, challenge.Name .. " — " .. challenge.Text, "danger")
	else
		running[player] = nil
	end
	changed(player)
end

-- Fin de session. La politique tient en deux lignes et vit ici, à un seul
-- endroit, parce que les deux notions se ressemblent assez pour être
-- confondues :
--
--   · un défi est TENU s'il s'est terminé sans mort ni interruption —
--     « SOMMEIL LÉGER » se termine au premier assaut, c'est sa règle, donc il
--     compte ;
--   · une session est COMPLÈTE si elle est allée jusqu'à MaxSessionSeconds.
--     Celle que « SOMMEIL LÉGER » coupe ne l'est pas, et ne remplit donc pas
--     le contrat du carnaval qui demande « une session complète ».
--
-- Sans cette distinction, un joueur armerait « SOMMEIL LÉGER », se ferait
-- couper au bout de dix secondes et empocherait une nuit survécue au
-- classement saisonnier.
function EndgameService.endSession(player: Player, reason: string, zoneId: string?)
	local held = reason == "complete" or reason == "challenge"
	local full = reason == "complete"

	local id = running[player]
	running[player] = nil
	if id then
		armed[player] = nil
		if held then
			local profile = PlayerDataService.get(player)
			if profile then
				profile.ChallengesDone += 1
				PlayerDataService.markDirty(player)
			end
			EndgameService.note(player, "challenge_done", 1)
			local challenge = EndgameConfig.challenge(id)
			tell(player, (challenge and challenge.Name or "Défi") .. " tenu.", "unlock")
		end
	end
	if full then
		EndgameService.note(player, "session_done", 1, zoneId)
	end
	changed(player)
	if held then
		EndgameService.offerContract(player)
	end
end

-- Les quatre règles, lues chacune à son point d'application.
function EndgameService.hasRule(player: Player, ruleId: string): boolean
	local challenge = EndgameService.activeChallenge(player)
	return challenge ~= nil and challenge.Id == ruleId
end

-- Multiplicateur de gain du défi en cours. Injecté dans EconomyService, au
-- même titre que celui de l'éveil et celui de l'événement — avec la prime de
-- zone des variantes, qui est l'autre moitié du §8 côté économie.
function EndgameService.earningBonus(player: Player): number
	local bonus = 1
	local challenge = EndgameService.activeChallenge(player)
	if challenge then
		bonus *= challenge.Reward
	end
	local profile = PlayerDataService.get(player)
	if profile then
		bonus *= EndgameService.zoneBounty(profile.CurrentZone)
	end
	return bonus
end

-- ── contrats rares ────────────────────────────────────────────────────────

local function activeContract(profile: any)
	local id = profile.Contract
	if id == "" or not EndgameConfig.contract(id) then
		return nil
	end
	if profile.ContractUntil > 0 and os.time() > profile.ContractUntil then
		return nil
	end
	return EndgameConfig.contract(id)
end

function EndgameService.contractOf(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return nil, 0, 0
	end
	-- Un contrat périmé est effacé à la lecture : sans ça, le tirage suivant
	-- ne pourrait jamais avoir lieu puisqu'un contrat occuperait la place.
	if profile.Contract ~= "" and not activeContract(profile) then
		profile.Contract = ""
		profile.ContractProgress = 0
		profile.ContractSeen = {}
		profile.ContractUntil = 0
		PlayerDataService.markDirty(player)
	end
	local contract = activeContract(profile)
	if not contract then
		return nil, 0, 0
	end
	return contract, profile.ContractProgress, profile.ContractUntil
end

-- Tirage, à la fin d'une session seulement, et rare. Ne propose jamais un
-- contrat quand un autre court, ni avant la fin du délai de repos.
function EndgameService.offerContract(player: Player)
	if not EndgameService.unlocked(player) then
		return nil
	end
	local profile = PlayerDataService.get(player)
	if not profile or not profile.Loaded then
		return nil
	end
	if EndgameService.contractOf(player) then
		return nil
	end
	if os.time() < profile.ContractRestUntil then
		return nil
	end
	if math.random() >= GameConfig.Endgame.ContractChance then
		return nil
	end

	local contract = EndgameConfig.draw(EndgameConfig.Contracts, function(c)
		return c.Weight
	end)
	if not contract then
		return nil
	end

	profile.Contract = contract.Id
	profile.ContractProgress = 0
	profile.ContractSeen = {}
	profile.ContractUntil = os.time() + contract.Seconds
	profile.ContractRestUntil = os.time() + GameConfig.Endgame.ContractCooldown
	PlayerDataService.markDirty(player)
	tell(player, "CONTRAT — " .. contract.Name .. " : " .. contract.Text, "unlock")
	changed(player)
	return contract
end

-- Compteur unique de tout le §8.
--
--   · `zoneId` ne sert qu'aux contrats zonés ; passé nil, un contrat zoné ne
--     progresse pas.
--   · `token` identifie CE QUI est compté, pour les contrats marqués
--     `Distinct` : deux fois le même jeton ne comptent qu'une fois. Un contrat
--     distinct sans jeton ne progresse pas du tout — mieux vaut un contrat qui
--     n'avance pas qu'un contrat qui se remplit de doublons.
function EndgameService.note(player: Player, kind: string, amount: number,
	zoneId: string?, token: string?)
	local profile = PlayerDataService.get(player)
	if not profile or not profile.Loaded then
		return
	end
	local contract = EndgameService.contractOf(player)
	if not contract or contract.Kind ~= kind then
		return
	end
	if contract.Zone and contract.Zone ~= zoneId then
		return
	end
	if contract.Distinct then
		if token == nil then
			return
		end
		if profile.ContractSeen[token] then
			return
		end
		profile.ContractSeen[token] = true
		amount = 1
	end

	profile.ContractProgress = math.min(contract.Target, profile.ContractProgress + amount)
	PlayerDataService.markDirty(player)
	if profile.ContractProgress >= contract.Target then
		tell(player, "CONTRAT rempli : " .. contract.Name .. ". Réclame-le.", "unlock")
	end
	changed(player)
end

-- Réclamation. Le serveur revérifie tout : le client ne transporte aucun
-- montant, il demande seulement.
function EndgameService.claimContract(player: Player): (boolean, string)
	local profile = PlayerDataService.get(player)
	if not profile or not profile.Loaded then
		return false, "Profil pas encore chargé."
	end
	local contract = EndgameService.contractOf(player)
	if not contract then
		return false, "Aucun contrat en cours."
	end
	if profile.ContractProgress < contract.Target then
		return false, "Pas encore rempli."
	end

	profile.Cash += contract.Cash
	profile.Contract = ""
	profile.ContractProgress = 0
	profile.ContractSeen = {}
	profile.ContractUntil = 0
	profile.ContractsDone += 1
	PlayerDataService.markDirty(player)
	changed(player)
	return true, contract.Name .. " payé."
end

-- ── collections et titres ─────────────────────────────────────────────────

function EndgameService.noteDocument(player: Player, documentId: string): (boolean, string)
	local document = EndgameConfig.document(documentId)
	if not document then
		return false, ""
	end
	local profile = PlayerDataService.get(player)
	if not profile or not profile.Loaded then
		return false, ""
	end
	if profile.Documents[documentId] then
		-- Déjà lu : on le redit, mais on ne recompte pas. L'objet reste dans
		-- le monde pour les autres joueurs, donc on repasse forcément dessus.
		return false, document.Name .. " — déjà dans tes archives."
	end
	profile.Documents[documentId] = true
	PlayerDataService.markDirty(player)
	EndgameService.note(player, "document_found", 1)
	EndgameService.checkTitles(player)
	changed(player)
	return true, document.Name .. " — " .. document.Text
end

-- Où en est chaque collection. Sert à l'écran et aux titres : un seul calcul,
-- pour que les deux ne puissent pas se contredire.
function EndgameService.collections(player: Player)
	local profile = PlayerDataService.get(player)
	local seen, variants, documents = 0, 0, 0
	if profile then
		for _, monster in ipairs(MonsterConfig.List) do
			if profile.MonstersSeen[monster.Id] then
				seen += 1
			end
		end
		for _, variant in ipairs(EndgameConfig.Variants) do
			if profile.Variants[variant.Id] then
				variants += 1
			end
		end
		for _, document in ipairs(EndgameConfig.Documents) do
			if profile.Documents[document.Id] then
				documents += 1
			end
		end
	end
	return {
		monsters = { Have = seen, Total = #MonsterConfig.List },
		variants = { Have = variants, Total = #EndgameConfig.Variants },
		documents = { Have = documents, Total = #EndgameConfig.Documents },
	}
end

function EndgameService.checkTitles(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile or not profile.Loaded then
		return
	end
	local sets = EndgameService.collections(player)
	for _, title in ipairs(EndgameConfig.Titles) do
		local set = sets[title.Set]
		if set and set.Have >= set.Total and not profile.Titles[title.Id] then
			profile.Titles[title.Id] = true
			PlayerDataService.markDirty(player)
			tell(player, "TITRE — « " .. title.Name .. " » : " .. title.Text, "unlock")
		end
	end
end

-- Vue complète pour l'écran du §8. Tout est calculé serveur : le client
-- n'affiche que ce qu'on lui envoie.
function EndgameService.view(player: Player)
	local profile = PlayerDataService.get(player)
	local contract, progress, until_ = EndgameService.contractOf(player)
	local challenges = {}
	for _, challenge in ipairs(EndgameConfig.Challenges) do
		table.insert(challenges, {
			Id = challenge.Id, Name = challenge.Name,
			Text = challenge.Text, Reward = challenge.Reward,
		})
	end
	local variants = {}
	for _, variant in ipairs(EndgameConfig.Variants) do
		table.insert(variants, {
			Id = variant.Id, Name = variant.Name,
			Seen = profile ~= nil and profile.Variants[variant.Id] == true,
			Tell = variant.Tell, Bounty = variant.Bounty,
		})
	end
	local documents = {}
	for _, document in ipairs(EndgameConfig.Documents) do
		local found = profile ~= nil and profile.Documents[document.Id] == true
		table.insert(documents, {
			Id = document.Id, Zone = document.Zone, Name = document.Name,
			Found = found,
			-- On n'envoie le texte que s'il a été trouvé : sinon l'écran
			-- raconte le document que le joueur n'a pas encore cherché.
			Text = found and document.Text or nil,
		})
	end
	local titles = {}
	for _, title in ipairs(EndgameConfig.Titles) do
		table.insert(titles, {
			Id = title.Id, Name = title.Name, Text = title.Text,
			Held = profile ~= nil and profile.Titles[title.Id] == true,
		})
	end
	return {
		Unlocked = EndgameService.unlocked(player),
		Armed = armed[player],
		Running = running[player],
		Challenges = challenges,
		Variants = variants,
		Documents = documents,
		Titles = titles,
		Collections = EndgameService.collections(player),
		Contract = contract and {
			Id = contract.Id, Name = contract.Name, Text = contract.Text,
			Target = contract.Target, Progress = progress,
			Cash = contract.Cash, Until = until_,
		} or nil,
		ContractsDone = profile and profile.ContractsDone or 0,
		ChallengesDone = profile and profile.ChallengesDone or 0,
	}
end

function EndgameService.cleanup(player: Player)
	armed[player] = nil
	running[player] = nil
	lastHowl[player] = nil
end

-- Exposé pour le banc d'essai : la temporisation du hurleur se mesure en temps
-- réel, et un test ne peut pas attendre vingt secondes.
function EndgameService.forgetHowl(player: Player)
	lastHowl[player] = nil
end

return EndgameService
