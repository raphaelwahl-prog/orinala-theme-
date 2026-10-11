--!strict
-- §5 et §15 — tous les dégâts passent ici, et tous sont validés côté serveur.
--
-- Les deux critères de validation du CDC §15 (« les monstres ne frappent pas à
-- travers les murs ou à distance impossible ») sont littéralement les deux
-- vérifications de `monsterHit`. Le client ne peut jamais infliger de dégâts :
-- il demande une frappe, le serveur mesure la distance et la ligne de vue.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameConfig = require(script.Parent.Parent.Shared.GameConfig)
local ItemConfig = require(script.Parent.Parent.Shared.ItemConfig)
local LifeService = require(script.Parent.LifeService)
local MonsterConfig = require(script.Parent.Parent.Shared.MonsterConfig)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CombatService = {}

local lastAttack: { [Player]: number } = {}
local repelHandlers: { (Player, string) -> () } = {}

function CombatService.onRepel(fn: (Player, string) -> ())
	table.insert(repelHandlers, fn)
end

-- Ligne de vue : un rayon qui ignore les personnages et le monstre lui-même.
function CombatService.hasLineOfSight(from: Vector3, to: Vector3, ignore: Instance?): boolean
	if not GameConfig.Combat.RequireLineOfSight then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter: { Instance } = {}
	if ignore then
		table.insert(filter, ignore)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	params.FilterDescendantsInstances = filter

	local direction = to - from
	local result = Workspace:Raycast(from, direction, params)
	return result == nil
end

-- Dégâts infligés par un monstre. Refusés si trop loin ou à travers un mur.
function CombatService.monsterHit(def: MonsterConfig.Monster, origin: Vector3, player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	local distance = (root.Position - origin).Magnitude
	if distance > math.min(def.AttackRange + 1.5, GameConfig.Combat.MaxHitDistance) then
		return false
	end
	if not CombatService.hasLineOfSight(origin, root.Position, character) then
		return false
	end

	-- Le coup qui tuerait met à terre, s'il y a quelqu'un pour relever. Sinon
	-- il tue, comme avant : on ne laisse pas un joueur seul agoniser sans
	-- aucune issue.
	if humanoid.Health - def.Damage <= 0 then
		if LifeService.knockDown(player) then
			return true
		end
	end

	humanoid:TakeDamage(def.Damage)
	return true
end

-- Frappe du joueur. Le client dit « j'attaque ce modèle » ; le serveur décide.
-- Les monstres ne meurent pas : ils sont étourdis. C'est le CDC §5 (« état
-- d'étourdissement ou de ralentissement temporaire »), et ça évite le farm de
-- monstres comme source d'argent.
function CombatService.playerAttack(player: Player, target: Model): (boolean, string, number)
	local profile = PlayerDataService.get(player)
	if not profile then
		return false, "Profil introuvable.", 0
	end

	-- Meilleure arme possédée.
	local best: ItemConfig.Item? = nil
	for _, item in ipairs(ItemConfig.List) do
		if item.Kind == "weapon" and (profile.Inventory[item.Id] or 0) > 0 then
			if not best or item.Price > best.Price then
				best = item
			end
		end
	end
	if not best then
		return false, "Tu n'as pas d'arme.", 0
	end

	local now = os.clock()
	local last = lastAttack[player] or 0
	if now - last < (best.Cooldown or 1) then
		return false, "Pas encore.", 0
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = target.PrimaryPart
	if not root or not targetRoot then
		return false, "Cible invalide.", 0
	end
	if (targetRoot.Position - root.Position).Magnitude > GameConfig.Combat.PlayerAttackReach then
		return false, "Trop loin.", 0
	end
	if not CombatService.hasLineOfSight(root.Position, targetRoot.Position, target) then
		return false, "Pas de ligne de vue.", 0
	end

	lastAttack[player] = now
	local monsterId = target:GetAttribute("MonsterId")
	if type(monsterId) == "string" then
		profile.MonstersSeen[monsterId] = true
		PlayerDataService.markDirty(player)
		for _, fn in ipairs(repelHandlers) do
			task.spawn(fn, player, monsterId)
		end
	end
	return true, best.Name, best.StunSeconds or 1
end

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)

return CombatService
