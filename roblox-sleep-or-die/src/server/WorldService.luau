--!strict
-- Construit les sept zones au démarrage et retient, pour chacune, ses points
-- de ronde, ses points d'apparition et son point d'arrivée.
--
-- C'est le seul endroit qui connaît la géométrie. Les autres services ne
-- parlent qu'en identifiants de zone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local EndgameConfig = require(script.Parent.Parent.Shared.EndgameConfig)
local EndgameService = require(script.Parent.EndgameService)
local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)
local MonsterService = require(script.Parent.MonsterService)
local ZoneBuilder = require(script.Parent.ZoneBuilder)
local ZoneConfig = require(script.Parent.Parent.Shared.ZoneConfig)
local ZoneLayouts = require(script.Parent.ZoneLayouts)

local WorldService = {}

local layouts: { [string]: ZoneBuilder.Layout } = {}

function WorldService.build()
	ZoneBuilder.reset()
	for _, zone in ipairs(ZoneConfig.List) do
		local build = ZoneLayouts.ById[zone.Id]
		if build then
			local folder = ZoneBuilder.folder(zone.Id)
			layouts[zone.Id] = build(ZoneBuilder.origin(zone.Order), folder)
		end
	end
	return layouts
end

function WorldService.layout(zoneId: string): ZoneBuilder.Layout?
	return layouts[zoneId]
end

function WorldService.anchor(zoneId: string): Vector3?
	local layout = layouts[zoneId]
	return layout and layout.Anchor or nil
end

-- Téléporte le joueur au point d'arrivée d'une zone. Les zones sont à
-- 1600 studs les unes des autres : on ne s'y rend pas à pied.
function WorldService.teleport(player: Player, zoneId: string): boolean
	local anchor = WorldService.anchor(zoneId)
	local character = player.Character
	if not anchor or not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	character:PivotTo(CFrame.new(anchor))
	return true
end

-- Peuple chaque zone de son monstre, dans la limite de MaxAlive, et seulement
-- s'il y a quelqu'un dedans : inutile de faire tourner une IA dans une zone
-- vide, c'est du temps serveur gâché.
function WorldService.occupied(zoneId: string): boolean
	local zone = ZoneConfig.get(zoneId)
	if not zone then
		return false
	end
	local origin = ZoneBuilder.origin(zone.Order)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and math.abs(root.Position.X - origin.X) < ZoneBuilder.SPACING / 2 then
			return true
		end
	end
	return false
end

-- §13 — le mini-boss d'un événement. Pas un monstre inédit : celui de la zone,
-- agrandi et accéléré. Renvoie nil si la zone n'a pas de monstre ou pas de
-- carte, plutôt que de lever : un événement ne doit jamais casser le serveur.
--
-- Renvoie (modèle, nom affichable). Le nom est rendu à part parce que
-- `MonsterRig` nomme le modèle avec l'IDENTIFIANT du monstre (`prowler`) et non
-- son nom de scène : lire `model.Name` pour l'annoncer afficherait « prowler
-- est tombé ». Et on ne peut pas changer l'identifiant pour autant — c'est lui
-- qui choisit la silhouette et les sons.
function WorldService.spawnMiniBoss(zoneId: string): (Model?, string)
	local zone = ZoneConfig.get(zoneId)
	local layout = layouts[zoneId]
	local def = zone and MonsterConfig.get(zone.Monster)
	if not layout or not def or #layout.Spawns == 0 then
		return nil, ""
	end

	local boost = GameConfig.Events.MiniBoss
	local copy = table.clone(def)
	copy.Name = def.Name .. " — DÉMESURÉ"
	copy.WalkSpeed = def.WalkSpeed * boost.Speed
	copy.SightRange = def.SightRange * boost.Sight
	copy.HearRange = def.HearRange * boost.Sight
	copy.Damage = math.floor(def.Damage * boost.Damage)
	copy.Height = def.Height * boost.Scale

	local point = layout.Spawns[math.random(1, #layout.Spawns)]
	local model = MonsterService.spawnUnique(copy, zoneId, point, layout.Patrol)
	CollectionService:AddTag(model, "MiniBoss")
	return model, copy.Name
end

-- §8 — les documents de la collection. Un par zone, posé sur un point de
-- ronde : donc dans un endroit où le monstre passe, et pas dans un coin sûr.
--
-- Même procédé que les objectifs du §7 (une Part taguée, une invite de
-- proximité), avec une différence qui compte : un document ne disparaît pas
-- quand on le ramasse. Il est noté dans le profil du lecteur et reste là pour
-- les autres — le faire disparaître le rendrait introuvable pour tout le
-- serveur dès qu'un seul joueur passe devant.
function WorldService.placeDocuments()
	local placed = 0
	for _, document in ipairs(EndgameConfig.Documents) do
		local layout = layouts[document.Zone]
		if layout and #layout.Patrol > 0 then
			local point = layout.Patrol[(placed % #layout.Patrol) + 1]
			local part = Instance.new("Part")
			part.Name = "Document_" .. document.Id
			part.Size = Vector3.new(2.2, 3, 0.2)
			part.Anchored = true
			part.CanCollide = false
			part.Color = Color3.fromRGB(226, 216, 189)
			part.Material = Enum.Material.SmoothPlastic
			part.CFrame = CFrame.new(point + Vector3.new(0, 3.2, 0))
			part:SetAttribute("Document", document.Id)
			CollectionService:AddTag(part, "Document")

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Lire"
			prompt.ObjectText = document.Name
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = part

			local folder = ZoneBuilder.folder(document.Zone)
			part.Parent = folder
			placed += 1
		end
	end
	return placed
end

-- Branche les invites des documents. Appelé une fois, après `placeDocuments`.
function WorldService.bindDocuments(onRead: (Player, string) -> ())
	for _, part in ipairs(CollectionService:GetTagged("Document")) do
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		local id = part:GetAttribute("Document")
		if prompt and type(id) == "string" and not part:GetAttribute("Bound") then
			part:SetAttribute("Bound", true)
			prompt.Triggered:Connect(function(player)
				onRead(player, id)
			end)
		end
	end
end

function WorldService.startPopulating()
	task.spawn(function()
		while true do
			for _, zone in ipairs(ZoneConfig.List) do
				local layout = layouts[zone.Id]
				local def = MonsterConfig.get(zone.Monster)
				-- Le boss n'apparaît pas tout seul : BossService s'en charge.
				if layout and def and def.Rule ~= "boss_phases"
					and WorldService.occupied(zone.Id) then
					-- `capFor` et pas `def.MaxAlive` : c'est lui qui porte le
					-- relèvement du plafond pendant un événement d'invasion.
					if MonsterService.countInZone(zone.Id) < MonsterService.capFor(def, zone.Id) then
						local point = layout.Spawns[math.random(1, #layout.Spawns)]
						-- §8 — après le carnaval, une apparition sur cinq est
						-- une variante. `rollVariant` renvoie nil la plupart
						-- du temps, et toujours nil avant la victoire : le
						-- monstre normal naît alors, exactement comme avant.
						local variant = EndgameService.rollVariant(zone.Id)
						if variant then
							MonsterService.spawn(EndgameService.applyVariant(def, variant),
								zone.Id, point, layout.Patrol, variant.Id)
						else
							MonsterService.spawn(def, zone.Id, point, layout.Patrol)
						end
					end
				end
			end
			task.wait(15)
		end
	end)
end

return WorldService
