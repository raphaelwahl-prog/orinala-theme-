#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Exécute la logique du jeu pour de vrai, hors de Roblox.

Les trois autres outils vérifient la FORME : `crosscheck.py` que les appels
existent, le compilateur Luau que la syntaxe tient, `checkzones.py` que les
cartes ne se chevauchent pas. Aucun des trois ne dit si le code FAIT ce qu'il
prétend faire.

Ce script-là le fait. Il assemble un seul morceau de Luau contenant :

  · un faux Roblox (game:GetService, Instance, task, Vector3, CollectionService…)
    assez complet pour les services qui ne touchent pas au moteur 3D ;
  · le VRAI code source des modules à tester, pris sur le disque, sans copie ni
    réécriture — si le source change, le test teste le nouveau ;
  · des bouchons pour ce qui demanderait le moteur (MonsterRig, SoundService,
    CombatService, ShelterService, WorldService) ;
  · les assertions.

Puis il l'exécute avec le vrai compilateur Luau (paquet npm `luau-web`).

    npm install luau-web      # une fois
    python3 tools/logictests.py

Astuce de conception qui fait tout marcher : `task.wait` lève une sentinelle, et
`task.spawn` exécute la fonction immédiatement en avalant cette sentinelle. Du
coup une boucle `while true do task.wait(1800) … end` se déroule une fois puis
s'arrête, tandis qu'un gestionnaire qui ne dort pas s'exécute en entier. On peut
donc observer les effets sans jamais se faire piéger par une boucle infinie.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Modules chargés depuis le disque, dans l'ordre des dépendances.
REAL = [
    ("Format", "shared/Format.luau"),
    ("GameConfig", "shared/GameConfig.luau"),
    ("ZoneConfig", "shared/ZoneConfig.luau"),
    ("MonsterConfig", "shared/MonsterConfig.luau"),
    ("CosmeticConfig", "shared/CosmeticConfig.luau"),
    ("PlayerDataService", "server/PlayerDataService.luau"),
    ("MonsterService", "server/MonsterService.luau"),
    ("EventService", "server/EventService.luau"),
]

PRELUDE = r"""
-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Faux Roblox                                                         ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- `emit` est fourni par le lanceur JavaScript : on écrit au fil de l'eau plutôt
-- que de rendre un tableau à la fin. Une table Luau rendue au JavaScript ne
-- traverse pas proprement la frontière d'interop ; un nombre, si.
local function say(line) emit(line) end

local checks, fails = 0, 0
local function ok(condition, label)
	checks += 1
	if condition then
		say("  OK    " .. label)
	else
		fails += 1
		say("  ÉCHEC " .. label)
	end
end
local function eq(got, want, label)
	ok(got == want, label .. "  (obtenu " .. tostring(got) .. ", attendu " .. tostring(want) .. ")")
end

-- Enum auto-vivifiant : Enum.Material.Fabric rend { Name = "Fabric" }.
local Enum = setmetatable({}, { __index = function(_, family)
	return setmetatable({}, { __index = function(_, key)
		return { Name = key, EnumType = family }
	end })
end })

local Vector3 = {}
local V3 = {}
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.max(1e-9, (self :: any).Magnitude)
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	end
	return V3[key]
end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__mul = function(a, k)
	if type(k) == "number" then return Vector3.new(a.X * k, a.Y * k, a.Z * k) end
	return Vector3.new(a.X * k.X, a.Y * k.Y, a.Z * k.Z)
end
function V3.Dot(self, other) return self.X * other.X + self.Y * other.Y + self.Z * other.Z end
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
end

local Color3 = {}
function Color3.fromRGB(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end
function Color3.new(r, g, b) return { R = r, G = g, B = b } end

local CFrame = {}
function CFrame.new(...) return { _cf = true, Position = Vector3.new(0, 0, 0) } end
function CFrame.Angles(...) return CFrame.new() end
CFrame.fromEulerAnglesXYZ = CFrame.Angles

local UDim = { new = function(a, b) return { Scale = a, Offset = b } end }
local UDim2 = {
	new = function(a, b, c, d) return { X = { Scale = a, Offset = b } } end,
	fromScale = function(a, b) return { X = { Scale = a } } end,
}

-- task : voir l'explication en tête de fichier. `wait` lève, `spawn` avale.
local STOP = newproxy and newproxy(false) or {}
local task = {}
function task.wait(_) error(STOP) end
function task.spawn(fn, ...)
	local packed = table.pack(...)
	local success, err = pcall(function()
		return fn(table.unpack(packed, 1, packed.n))
	end)
	if not success and err ~= STOP then
		say("  !! erreur dans une tâche : " .. tostring(err))
	end
end
function task.defer(fn, ...) return task.spawn(fn, ...) end
function task.delay(_, _fn) return nil end

local function warn(...)
	local parts = {}
	for _, piece in ipairs({ ... }) do table.insert(parts, tostring(piece)) end
	say("  (warn) " .. table.concat(parts, " "))
end
local function print_(...) warn(...) end

-- Instance minimale : seulement ce que les modules testés manipulent.
local Instance = {}
function Instance.new(class)
	local self
	self = {
		ClassName = class, Name = class, Parent = nil, _children = {}, _attrs = {}, _tags = {},
	}
	function self.Destroy(s) s.Parent = nil end
	function self.SetAttribute(s, key, value) s._attrs[key] = value end
	function self.GetAttribute(s, key) return s._attrs[key] end
	function self.IsA(s, want) return s.ClassName == want end
	function self.FindFirstChild(s, name) return s._children[name] end
	function self.FindFirstChildOfClass(s, want)
		for _, child in pairs(s._children) do
			if child.ClassName == want then return child end
		end
		return nil
	end
	function self.GetChildren(s)
		local list = {}
		for _, child in pairs(s._children) do table.insert(list, child) end
		return list
	end
	return self
end

local tagged = {}
local CollectionService = {}
function CollectionService.AddTag(_, instance, tag)
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], instance)
	instance._tags = instance._tags or {}
	instance._tags[tag] = true
end
function CollectionService.HasTag(_, instance, tag)
	return (instance._tags and instance._tags[tag]) == true
end
function CollectionService.GetTagged(_, tag) return tagged[tag] or {} end
function CollectionService.RemoveTag(_, instance, tag)
	if instance._tags then instance._tags[tag] = nil end
end

local players = {}
local Players = {}
function Players.GetPlayers(_) return players end
function Players.GetNameFromUserIdAsync(_, id) return "Joueur" .. tostring(id) end

local RunService = {}
function RunService.IsStudio(_) return true end
RunService.Heartbeat = { Connect = function() return { Disconnect = function() end } end }

-- DataStore : rend ce que le test a posé dans `savedData`.
local savedData = nil
local writes = {}
local DataStoreService = {}
function DataStoreService.GetDataStore(_, _name)
	return {
		GetAsync = function(_, _key) return savedData end,
		UpdateAsync = function(_, key, transform)
			writes[key] = transform(savedData)
			return writes[key]
		end,
		SetAsync = function(_, key, value) writes[key] = value end,
	}
end
function DataStoreService.GetOrderedDataStore(_, _name, _scope)
	error("pas de stockage classé dans le banc d'essai")
end

local Workspace = Instance.new("Workspace")
local PathfindingService = { CreatePath = function() return {
	ComputeAsync = function() end, GetWaypoints = function() return {} end,
	Status = { Name = "NoPath" },
} end }

local services = {
	CollectionService = CollectionService,
	DataStoreService = DataStoreService,
	PathfindingService = PathfindingService,
	Players = Players,
	RunService = RunService,
	Workspace = Workspace,
	ContentProvider = { PreloadAsync = function() end },
	SoundService = Instance.new("SoundService"),
	TweenService = { Create = function() return { Play = function() end } end },
	Lighting = Instance.new("Lighting"),
	ReplicatedStorage = Instance.new("ReplicatedStorage"),
	MarketplaceService = {},
}

local game = {}
function game.GetService(_, name)
	local service = services[name]
	if not service then
		service = Instance.new(name)
		services[name] = service
	end
	return service
end
function game.BindToClose(_, _fn) end

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Chargeur de modules                                                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝
-- Les modules écrivent `require(script.Parent.Machin)`. On modélise l'arbre de
-- scripts par un nœud qui se souvient de son dernier segment, et on résout par
-- ce segment : les noms de modules sont uniques dans ce projet (c'est déjà
-- l'hypothèse de crosscheck.py).
local MODULES = {}
local LOADED = {}

local NODE = {}
NODE.__index = function(self, key)
	if key == "Parent" then
		-- La chaîne de parents doit être infinie : `script.Parent.Parent.Shared`
		-- remonte deux crans. Un parent manquant est fabriqué à la demande,
		-- sinon on indexe nil au deuxième cran.
		local parent = rawget(self, "_parent")
		if not parent then
			parent = setmetatable({ _name = "Parent" }, NODE)
			rawset(self, "_parent", parent)
		end
		return parent
	end
	return setmetatable({ _name = key, _parent = self }, NODE)
end
local function node(name, parent)
	return setmetatable({ _name = name, _parent = parent }, NODE)
end

local function require(target)
	local name = type(target) == "table" and rawget(target, "_name") or tostring(target)
	if LOADED[name] ~= nil then
		return LOADED[name]
	end
	local factory = MODULES[name]
	if not factory then
		error("module absent du banc d'essai : " .. tostring(name), 0)
	end
	LOADED[name] = factory(node(name, node("Parent")))
	return LOADED[name]
end
"""

STUBS = r"""
-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Bouchons : ce qui demanderait le moteur 3D                          ║
-- ╚══════════════════════════════════════════════════════════════════════╝
local rigBuilds = 0
MODULES.MonsterRig = function()
	local MonsterRig = {}
	function MonsterRig.build(def, position)
		rigBuilds += 1
		local model = Instance.new("Model")
		model.Name = def.Id
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Position = position
		local humanoid = Instance.new("Humanoid")
		humanoid.Health = def.Health
		humanoid.MaxHealth = def.Health
		humanoid.WalkSpeed = 0
		humanoid.MoveDirection = Vector3.new(0, 0, 0)
		function humanoid.MoveTo() end
		model._children.HumanoidRootPart = root
		model._children.Humanoid = humanoid
		model.PrimaryPart = root
		return model, { _rig = true }
	end
	function MonsterRig.animate() end
	function MonsterRig.look() return {} end
	return MonsterRig
end

local soundsPlayed = {}
MODULES.SoundService = function()
	local SoundLib = {}
	function SoundLib.init() end
	function SoundLib.playAt(effect) table.insert(soundsPlayed, effect) end
	function SoundLib.playFor(_, effect) table.insert(soundsPlayed, effect) end
	function SoundLib.playForAll(effect) table.insert(soundsPlayed, effect) end
	function SoundLib.startAmbience() end
	function SoundLib.setTension() end
	function SoundLib.setUiSound() end
	function SoundLib.forget() end
	function SoundLib.available() return {} end
	return SoundLib
end

MODULES.CombatService = function()
	local CombatService = {}
	function CombatService.hasLineOfSight() return true end
	function CombatService.monsterHit() return true end
	function CombatService.playerAttack() return false, "", 0 end
	function CombatService.onRepel() end
	return CombatService
end

MODULES.ShelterService = function()
	local ShelterService = {}
	function ShelterService.get() return nil end
	function ShelterService.absorbAssault() return 0 end
	function ShelterService.profileOf() return { Detection = 0, Delay = 0 } end
	function ShelterService.ownedBy() return nil end
	return ShelterService
end

-- WorldService bouchonné : on observe les demandes de mini-boss sans construire
-- 1600 studs de décor.
local miniBossRequests = {}
local occupiedZones = {}
local lastMiniBoss = nil
MODULES.WorldService = function()
	local WorldService = {}
	function WorldService.occupied(zoneId) return occupiedZones[zoneId] == true end
	function WorldService.spawnMiniBoss(zoneId)
		table.insert(miniBossRequests, zoneId)
		local model = Instance.new("Model")
		model.Name = "miniboss_" .. zoneId
		model.Parent = Workspace
		CollectionService:AddTag(model, "MiniBoss")
		lastMiniBoss = model
		return model, "LE MONSTRE DE " .. zoneId .. " — DÉMESURÉ"
	end
	function WorldService.layout() return nil end
	function WorldService.anchor() return nil end
	function WorldService.build() return {} end
	function WorldService.teleport() return true end
	function WorldService.startPopulating() end
	return WorldService
end
"""

TESTS = r"""
-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Les assertions                                                      ║
-- ╚══════════════════════════════════════════════════════════════════════╝
local GameConfig = require(node("GameConfig"))
local MonsterConfig = require(node("MonsterConfig"))
local CosmeticConfig = require(node("CosmeticConfig"))
local MonsterService = require(node("MonsterService"))
local PlayerDataService = require(node("PlayerDataService"))
local EventService = require(node("EventService"))

local prowler = MonsterConfig.get("prowler")
local sewer = MonsterConfig.get("sewer_thing")

say("— §13 : le plafond de monstres suit l'événement —")
MonsterService.applyEvent(1, 1, "any")
eq(MonsterService.capFor(prowler, "street"), prowler.MaxAlive,
	"sans événement, le plafond est MaxAlive")

MonsterService.applyEvent(1, 2, "street")
eq(MonsterService.capFor(prowler, "street"), prowler.MaxAlive * 2,
	"invasion de la rue : plafond doublé dans la rue")
eq(MonsterService.capFor(sewer, "sewers"), sewer.MaxAlive,
	"invasion de la rue : les égouts ne changent pas (filtre de zone)")

MonsterService.applyEvent(1.2, 1, "any")
local speedAny = (MonsterService.eventFactors("sewers"))
eq(speedAny, 1.2, "lune de sang : vitesse relevée dans toutes les zones")
eq(MonsterService.capFor(sewer, "sewers"), sewer.MaxAlive,
	"lune de sang : le plafond ne bouge pas")

MonsterService.applyEvent(1, 0.1, "street")
ok(MonsterService.capFor(prowler, "street") >= 1,
	"un multiplicateur ridicule ne vide jamais la zone (plancher à 1)")

say("")
say("— §13 : l'apparition respecte ce plafond, et l'unique passe outre —")
MonsterService.applyEvent(1, 1, "any")
local spawned = 0
for _ = 1, prowler.MaxAlive + 2 do
	if MonsterService.spawn(prowler, "street", Vector3.new(0, 0, 0), {}) then
		spawned += 1
	end
end
eq(spawned, prowler.MaxAlive, "on ne dépasse pas MaxAlive sans événement")
eq(MonsterService.countInZone("street"), prowler.MaxAlive, "le compte de la zone est juste")

MonsterService.applyEvent(1, 2, "street")
local extra = 0
for _ = 1, 5 do
	if MonsterService.spawn(prowler, "street", Vector3.new(0, 0, 0), {}) then
		extra += 1
	end
end
eq(extra, prowler.MaxAlive, "l'événement laisse entrer exactement MaxAlive de plus")

local unique = MonsterService.spawnUnique(prowler, "street", Vector3.new(0, 0, 0), {})
ok(unique ~= nil, "spawnUnique passe outre un plafond atteint (boss et mini-boss)")

say("")
say("— §13 : le défi collectif —")
-- `pick()` est privé et tire au hasard : on relance init() jusqu'à tomber sur
-- l'événement voulu. Si on n'y arrive pas, c'est la liste qui a un problème.
local function forceEvent(id)
	for _ = 1, 400 do
		EventService.init()
		local active = EventService.active()
		if active and active.Id == id then
			return active
		end
	end
	return nil
end

local blood = forceEvent("blood_moon")
ok(blood ~= nil, "l'événement « lune de sang » est atteignable")
if blood then
	eq(EventService.collectiveState().Open, false, "un événement normal n'ouvre pas de défi")
	eq(EventService.rewardMultiplier(), blood.RewardMultiplier,
		"le multiplicateur de gains est celui de l'événement")
	local speed = (MonsterService.eventFactors("street"))
	eq(speed, blood.MonsterSpeed, "la vitesse des monstres a été appliquée à l'allumage")
end

local endless = forceEvent("endless_night")
ok(endless ~= nil, "l'événement « nuit sans fin » est atteignable")

local alice = { Name = "Alice", UserId = 11 }
players = { alice }
savedData = nil
PlayerDataService.init()
PlayerDataService.load(alice)

local granted = 0
EventService.onReward(function(_player, amount) granted += amount end)

if endless then
	local state = EventService.collectiveState()
	eq(state.Open, true, "la nuit sans fin ouvre un défi collectif")
	local okClaim, message = EventService.claim(alice)
	eq(okClaim, false, "on ne réclame pas un défi collectif non rempli")
	ok(string.find(message, "sessions") ~= nil, "le refus dit où en est le serveur")

	for _ = 1, GameConfig.Events.Collective.Sessions do
		EventService.noteSession()
	end
	eq(EventService.collectiveState().Done, true, "défi rempli après assez de sessions")

	granted = 0
	local okNow, name = EventService.claim(alice)
	eq(okNow, true, "défi rempli : la récompense se réclame")
	eq(name, endless.Name, "le message nomme l'événement")
	eq(granted, math.floor(GameConfig.Events.ClaimBase * endless.RewardMultiplier),
		"le montant versé suit le multiplicateur de l'événement")

	local again = EventService.claim(alice)
	eq(again, false, "pas deux fois dans la même période")
end

-- Échec du défi : les morts du serveur entier le font tomber, et ça ne se
-- repêche pas en tenant d'autres sessions.
local endless2 = forceEvent("endless_night")
if endless2 then
	for _ = 1, GameConfig.Events.Collective.MaxDeaths + 1 do
		EventService.noteDeath()
	end
	eq(EventService.collectiveState().Failed, true, "trop de morts : défi perdu")
	for _ = 1, GameConfig.Events.Collective.Sessions * 2 do
		EventService.noteSession()
	end
	eq(EventService.collectiveState().Failed, true, "un défi perdu ne se repêche pas")
	eq(EventService.collectiveState().Done, false, "et ne devient pas réclamable")
	local okFailed, failedMessage = EventService.claim(alice)
	eq(okFailed, false, "réclamation refusée sur un défi perdu")
	ok(string.find(failedMessage, "perdu") ~= nil, "le refus le dit franchement")
end

say("")
say("— §13 : le mini-boss —")
local carnivalZone = nil
for _, zone in ipairs(require(node("ZoneConfig")).List) do
	local def = MonsterConfig.get(zone.Monster)
	if def and def.Rule == "boss_phases" then
		carnivalZone = zone.Id
	end
end
ok(carnivalZone ~= nil, "une zone porte bien le boss à phases")

-- Cas négatif : SEULE l'arène du boss est occupée. `init()` déclenche la
-- surveillance tout de suite (le contrôle passe avant l'attente), donc si le
-- garde sautait, une demande apparaîtrait ici.
occupiedZones = { [carnivalZone] = true }
miniBossRequests = {}
local carnival = forceEvent("forbidden_carnival")
ok(carnival ~= nil, "l'événement « carnaval interdit » est atteignable")
eq(#miniBossRequests, 0,
	"aucun mini-boss dans l'arène du boss, même si c'est la seule zone occupée")

-- Cas positif : la rue est occupée aussi. Un mini-boss doit naître, et dans la
-- rue — pas dans l'arène.
occupiedZones = { street = true, [carnivalZone] = true }
miniBossRequests = {}
lastMiniBoss = nil
local carnival2 = forceEvent("forbidden_carnival")
if carnival2 then
	eq(#miniBossRequests, 1, "un seul mini-boss à la fois sur le serveur")
	eq(miniBossRequests[1], "street", "il naît dans une zone jouable, pas dans l'arène")
	eq(EventService.miniBossAlive(), true, "le service le sait vivant")

	-- Il tombe au nombre de coups annoncé, pas avant.
	local hits = GameConfig.Events.MiniBoss.Hits
	local down, label = false, ""
	for index = 1, hits - 1 do
		down, label = EventService.registerMiniBossHit(alice, lastMiniBoss)
		if down then
			ok(false, "il est tombé au coup " .. index .. " au lieu de " .. hits)
			break
		end
	end
	ok(not down, "il tient " .. (hits - 1) .. " coups")
	down, label = EventService.registerMiniBossHit(alice, lastMiniBoss)
	eq(down, true, "il tombe au coup " .. hits)
	ok(string.find(label, "DÉMESURÉ") ~= nil,
		"l'annonce porte son nom de scène, pas son identifiant  (« " .. label .. " »)")
	eq(EventService.miniBossAlive(), false, "il n'est plus là après être tombé")

	local hitProfile = PlayerDataService.get(alice)
	eq(hitProfile and hitProfile.Achievements.miniboss_down, true,
		"celui qui l'a frappé débloque l'exploit du skin")

	-- Un coup sur un modèle qui n'est pas le mini-boss courant ne compte pas.
	local stranger = Instance.new("Model")
	local strayDown = EventService.registerMiniBossHit(alice, stranger)
	eq(strayDown, false, "un coup sur un autre monstre ne fait pas tomber le mini-boss")
end

say("")
say("— §9 : les réglages survivent à une vieille sauvegarde —")
local bob = { Name = "Bob", UserId = 12 }
players = { bob }
-- Sauvegarde d'avant l'écran de paramètres : un seul réglage connu, et il est
-- coupé. Les autres doivent revenir à leur valeur par défaut, pas rester nil.
savedData = { Cash = 4200, Settings = { Flash = false } }
PlayerDataService.init()
local profile = PlayerDataService.load(bob)
eq(profile.Cash, 4200, "la sauvegarde est bien relue")
eq(profile.Settings.Flash, false, "le réglage sauvegardé est conservé")
for _, entry in ipairs(GameConfig.Ui.Settings) do
	if entry.Id ~= "Flash" then
		eq(type(profile.Settings[entry.Id]), "boolean",
			"le réglage « " .. entry.Id .. " » absent de la sauvegarde est recomplété")
	end
end

say("")
say("— §8 : le motif de déblocage est propre à chaque skin —")
local stats = { Nights = 0, Zones = {}, Achievements = {} }
local _, clownReason = CosmeticConfig.check(CosmeticConfig.get("clown"), stats)
local _, revelerReason = CosmeticConfig.check(CosmeticConfig.get("reveler"), stats)
ok(string.find(clownReason, "carnaval") ~= nil, "le trophée du clown parle du carnaval")
ok(string.find(revelerReason, "mini%-boss") ~= nil, "Le Fêtard parle du mini-boss")
ok(clownReason ~= revelerReason,
	"deux skins à exploit n'affichent pas le même motif (c'était le cas avant)")

say("")
say(string.format("%d/%d vérifications passées.", checks - fails, checks))
return fails
"""


def wrap(name: str, source: str) -> str:
    return "MODULES[%s] = function(script)\n%s\nend\n" % (json.dumps(name), source)


def build_chunk() -> str:
    parts = [PRELUDE, STUBS]
    for name, relative in REAL:
        source = (SRC / relative).read_text(encoding="utf-8")
        parts.append(wrap(name, source))
    parts.append(TESTS)
    return "\n".join(parts)


def main() -> None:
    if shutil.which("node") is None:
        raise SystemExit("ERREUR : node est introuvable.")

    chunk = build_chunk()
    work = Path(tempfile.mkdtemp(prefix="sod-logic-"))
    (work / "chunk.luau").write_text(chunk, encoding="utf-8")

    runner = """
import { readFileSync } from 'node:fs';
import { LuauState } from 'luau-web';
const state = await LuauState.createAsync({
  emit: (line) => console.log(String(line)),
});
const source = readFileSync(process.argv[2], 'utf8');
let fn;
try {
  fn = state.loadstring(source, 'logictests', true);
} catch (err) {
  console.log('ERREUR DE COMPILATION ' + String(err.message ?? err));
  process.exit(2);
}
const fails = await fn();
process.exit(Number(fails) > 0 ? 1 : 0);
"""
    (work / "runner.mjs").write_text(runner, encoding="utf-8")

    # `luau-web` est une dépendance de développement, hors du dépôt : on la
    # cherche là où npm l'a posée, sans l'imposer dans l'arborescence du jeu.
    candidates = [
        os.environ.get("LUAU_WEB_PATH"),
        str(ROOT.parent / "node_modules"),
        "/tmp/node_modules",
        str(Path.home() / "node_modules"),
    ]
    node_path = next((c for c in candidates if c and Path(c, "luau-web").is_dir()), None)
    if node_path is None:
        raise SystemExit(
            "ERREUR : paquet `luau-web` introuvable.\n"
            "  npm install luau-web   (puis relance, ou pose LUAU_WEB_PATH)"
        )

    env = dict(os.environ, NODE_PATH=node_path)
    done = subprocess.run(
        ["node", str(work / "runner.mjs"), str(work / "chunk.luau")],
        capture_output=True, text=True, env=env,
    )
    sys.stdout.write(done.stdout)
    if done.stderr.strip():
        sys.stderr.write(done.stderr)
    shutil.rmtree(work, ignore_errors=True)
    raise SystemExit(done.returncode)


if __name__ == "__main__":
    main()
