--!strict
-- LE SON.
--
-- Roblox ne sait pas fabriquer un son : il lui faut des fichiers. Mais toutes
-- les installations de Roblox embarquent une petite bibliothèque locale,
-- accessible par `rbxasset://sounds/…`. Rien à téléverser, rien à modérer,
-- rien qui puisse disparaître un jour.
--
-- Le problème : ces chemins ne sont garantis par aucune documentation. Alors
-- au démarrage, ce service les ESSAIE un par un et écrit dans la sortie
-- lesquels ont chargé. Tu sais donc exactement ce qui marche chez toi, au lieu
-- de te demander pourquoi c'est silencieux.
--
-- Avec cinq ou six échantillons on fait tout le jeu : la hauteur (PlaybackSpeed)
-- et les effets intégrés (réverbération, passe-bas, distorsion) suffisent à
-- transformer un même son en pas, en coup contre une porte ou en battement de
-- cœur. C'est ce que font tous les jeux : peu de sons, beaucoup de variantes.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local SoundServiceRoblox = game:GetService("SoundService")

local SoundLib = {}

-- Plusieurs candidats par effet : on garde le premier qui charge.
local CANDIDATES: { [string]: { string } } = {
	step = { "rbxasset://sounds/action_footsteps_plastic.mp3" },
	thud = { "rbxasset://sounds/impact_water.mp3", "rbxasset://sounds/snap.mp3" },
	alarm = { "rbxasset://sounds/electronicpingshort.wav" },
	click = { "rbxasset://sounds/switch3.wav", "rbxasset://sounds/clickfast.ogg" },
	drone = { "rbxasset://sounds/bass.mp3" },
	hurt = { "rbxasset://sounds/uuhhh.mp3" },
	getup = { "rbxasset://sounds/action_get_up.mp3" },
	fall = { "rbxasset://sounds/action_falling.mp3" },
	swoosh = { "rbxasset://sounds/swoosh.mp3", "rbxasset://sounds/action_jump.mp3" },
}

-- Comment chaque effet du jeu se fabrique à partir d'un échantillon.
type Recipe = {
	Sample: string,
	Volume: number,
	Speed: number,
	Vary: number?,       -- variation aléatoire de hauteur
	Looped: boolean?,
	RollOff: number?,    -- distance d'atténuation pour un son placé dans le monde
	Lowpass: number?,    -- fréquence de coupure, pour étouffer
	Reverb: boolean?,
	Distort: number?,
}

local RECIPES: { [string]: Recipe } = {
	-- Monstres
	monster_step = { Sample = "step", Volume = 0.55, Speed = 0.7, Vary = 0.12,
		RollOff = 70, Lowpass = 900 },
	monster_heavy = { Sample = "thud", Volume = 0.7, Speed = 0.55, Vary = 0.08,
		RollOff = 95, Lowpass = 600, Reverb = true },
	monster_spot = { Sample = "swoosh", Volume = 0.8, Speed = 0.6, RollOff = 120,
		Distort = 0.25 },
	monster_attack = { Sample = "thud", Volume = 0.9, Speed = 0.8, Vary = 0.1,
		RollOff = 70, Distort = 0.4 },

	-- Refuge
	assault = { Sample = "thud", Volume = 1, Speed = 0.45, RollOff = 80,
		Lowpass = 500, Reverb = true },
	alarm = { Sample = "alarm", Volume = 0.7, Speed = 1.4, RollOff = 90 },
	defense_break = { Sample = "thud", Volume = 0.85, Speed = 1.3, RollOff = 60,
		Distort = 0.3 },

	-- Joueur
	hurt = { Sample = "hurt", Volume = 0.75, Speed = 0.95, Vary = 0.1 },
	downed = { Sample = "fall", Volume = 0.8, Speed = 0.7 },
	revived = { Sample = "getup", Volume = 0.8, Speed = 1 },

	-- Interface
	cash = { Sample = "click", Volume = 0.6, Speed = 1.6 },
	buy = { Sample = "click", Volume = 0.55, Speed = 1.2 },
	unlock = { Sample = "alarm", Volume = 0.6, Speed = 1.9 },
	deny = { Sample = "click", Volume = 0.5, Speed = 0.7 },

	-- Ambiance
	drone = { Sample = "drone", Volume = 0.14, Speed = 0.35, Looped = true,
		Lowpass = 260, Reverb = true },
}

local loaded: { [string]: string } = {}   -- effet → chemin retenu
local report: { string } = {}
local drone: Sound? = nil

local function tryLoad(name: string, paths: { string }): string?
	for _, path in ipairs(paths) do
		local probe = Instance.new("Sound")
		probe.SoundId = path
		probe.Volume = 0
		probe.Parent = SoundServiceRoblox
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ probe })
		end)
		local worked = ok and probe.IsLoaded
		probe:Destroy()
		if worked then
			return path
		end
	end
	return nil
end

function SoundLib.init()
	for name, paths in pairs(CANDIDATES) do
		local path = tryLoad(name, paths)
		if path then
			loaded[name] = path
			table.insert(report, "  ✓ " .. name .. " → " .. path)
		else
			table.insert(report, "  ✗ " .. name .. " — aucun candidat n'a chargé")
		end
	end
	table.sort(report)
	print("[SON] échantillons disponibles :")
	for _, line in ipairs(report) do
		print(line)
	end
	local count = 0
	for _ in pairs(loaded) do
		count += 1
	end
	if count == 0 then
		warn("[SON] aucun échantillon local n'est disponible. Le jeu tournera "
			.. "en silence. Remplace les chemins de CANDIDATES par des "
			.. "rbxassetid:// de ta bibliothèque pour avoir du son.")
	end
	SoundLib.startAmbience()
end

-- Construit un Sound prêt à jouer. `parent` décide si le son est placé dans
-- le monde (une BasePart → son 3D) ou global (SoundService).
local function build(effect: string, parent: Instance): Sound?
	local recipe = RECIPES[effect]
	if not recipe then
		return nil
	end
	local path = loaded[recipe.Sample]
	if not path then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.SoundId = path
	sound.Volume = recipe.Volume
	sound.PlaybackSpeed = recipe.Speed + (recipe.Vary and (math.random() * 2 - 1) * recipe.Vary or 0)
	sound.Looped = recipe.Looped or false
	if recipe.RollOff then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = recipe.RollOff
		sound.RollOffMinDistance = 8
	end
	if recipe.Lowpass then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.HighGain = -40
		eq.MidGain = recipe.Lowpass < 700 and -12 or 0
		eq.LowGain = 4
		eq.Parent = sound
	end
	if recipe.Reverb then
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 2.4
		reverb.Density = 0.7
		reverb.WetLevel = -4
		reverb.Parent = sound
	end
	if recipe.Distort then
		local distort = Instance.new("DistortionSoundEffect")
		distort.Level = recipe.Distort
		distort.Parent = sound
	end
	sound.Parent = parent
	return sound
end

-- Son placé dans le monde : tout le monde l'entend selon la distance.
function SoundLib.playAt(effect: string, part: BasePart?)
	if not part or not part.Parent then
		return
	end
	local sound = build(effect, part)
	if not sound then
		return
	end
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	-- Filet de sécurité : si Ended ne part jamais (son coupé), on nettoie.
	task.delay(10, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

-- Réglage par joueur (§9, écran de paramètres). Le serveur fabrique les sons
-- d'interface dans le PlayerGui du joueur : c'est donc ici, et pas côté client,
-- qu'on peut honnêtement les couper. Les sons du monde (`playAt`) sont entendus
-- par tout le monde selon la distance : ils ne peuvent pas être coupés par un
-- seul joueur, et l'écran de paramètres ne le propose pas.
local muted: { [Player]: boolean } = {}

function SoundLib.setUiSound(player: Player, enabled: boolean)
	muted[player] = not enabled
end

function SoundLib.forget(player: Player)
	muted[player] = nil
end

-- Son d'interface pour un joueur précis.
function SoundLib.playFor(player: Player, effect: string)
	if muted[player] then
		return
	end
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return
	end
	local sound = build(effect, gui)
	if not sound then
		return
	end
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	task.delay(10, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

function SoundLib.playForAll(effect: string)
	for _, player in ipairs(Players:GetPlayers()) do
		SoundLib.playFor(player, effect)
	end
end

-- Nappe continue. Elle monte avec l'éveil de la maison : c'est le seul son
-- qu'on entend tout le temps, donc le seul qui peut porter la tension.
function SoundLib.startAmbience()
	if drone then
		return
	end
	drone = build("drone", SoundServiceRoblox)
	if drone then
		(drone :: Sound):Play()
	end
end

function SoundLib.setTension(stage: number)
	if not drone then
		return
	end
	local d = drone :: Sound
	d.Volume = 0.14 + (stage - 1) * 0.06
	d.PlaybackSpeed = 0.35 + (stage - 1) * 0.07
end

function SoundLib.available(): { string }
	return report
end

return SoundLib
