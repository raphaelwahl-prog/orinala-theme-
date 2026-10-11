# Le son — ce qui manque, et c'est le plus rentable

Je ne peux pas te livrer de fichiers audio : les sons sur Roblox sont des
**assets hébergés** avec un ID numérique, et il faut les prendre dans la
bibliothèque Roblox (ou les téléverser depuis ton compte).

Mais c'est la chose la moins chère et la plus efficace qui te reste à faire.
Dans un jeu d'horreur, **le son fait 80 % de la peur**. Une créature silencieuse
est un bloc qui glisse ; la même avec des pas qui se rapprochent devient
insoutenable.

---

## Comment trouver les IDs

1. Dans Roblox Studio : **View → Toolbox → onglet Audio**.
2. Tape la requête (colonne de droite du tableau).
3. Clique sur un son pour l'écouter, puis clic droit → **Copy Asset ID**.
4. Colle l'ID au format `rbxassetid://123456789`.

> Depuis les changements de licence audio de Roblox, beaucoup de sons longs sont
> limités à ton propre usage. Filtre sur **Audio → Free** et vérifie que le son
> est utilisable dans un jeu publié. Les sons courts (moins de 6 s) sont presque
> tous libres d'usage.

---

## Où coller quoi

### Les créatures — `src/shared/EntityCatalog.luau`

Chaque créature a deux champs, vides par défaut (`""` = silencieux, rien ne
plante) :

| Champ | Ce que c'est | À chercher dans la Toolbox |
|---|---|---|
| `StepSoundId` | un pas | `footstep concrete`, `heavy footstep` |
| `VoiceSoundId` | boucle de respiration / grognement, jouée en continu et spatialisée | `monster breathing loop`, `growl loop`, `creature ambience` |

Suggestions par créature, pour qu'on les reconnaisse **à l'oreille** avant de
les voir — c'est tout l'intérêt d'avoir cinq monstres :

| Créature | Son recherché | Effet voulu |
|---|---|---|
| LE VEILLEUR | pas lents et lourds, cliquetis de lanterne | on l'entend venir de loin, on a le temps |
| LA RAMPANTE | griffes rapides sur le béton, reniflements | on sait qu'il faut s'arrêter MAINTENANT |
| LE MIME | silence presque total, un craquement de bois sec | la peur vient de ne pas l'entendre |
| L'AFFAMÉ | souffle rauque très grave, basse continue | il remplit la pièce avant d'y entrer |

Le code les spatialise déjà (`RollOffMode.InverseTapered`, portée 140 studs) :
le volume et la direction se font tout seuls.

### Les trois sons qui changent le plus le jeu

À ajouter côté client, dans `src/client/init.client.luau` :

| Moment | Branche-le sur | Son à chercher |
|---|---|---|
| Tirage de risque qui tombe | l'événement `DangerAlert` | `heartbeat`, `horror sting`, `alarm clock` |
| Capture | l'événement `SleepChanged` (reason capture) ou `Notify` en `danger` | `jumpscare scream`, `impact hit` |
| Dépôt d'argent au coffre | `Notify` en `cash` | `cash register`, `coins` |

Exemple minimal, à coller dans `init.client.luau` :

```lua
local SoundService = game:GetService("SoundService")

local function playOnce(id: string, volume: number)
	if id == "" then return end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end

;(Net.get("DangerAlert") :: RemoteEvent).OnClientEvent:Connect(function(window)
	Hud.flashDanger(window or 4)
	playOnce("rbxassetid://TON_ID_ICI", 0.7)
end)
```

---

## Ce qui est déjà en place et ne coûte rien

Ces effets fonctionnent **sans aucun asset**, et ils sont déjà codés :

- **Les ampoules grésillent** quand une créature approche (`ThreatService`,
  fonction `updateFlicker`). Le joueur sait avant de voir. C'est l'effet le plus
  rentable du jeu et il est gratuit.
- **Les yeux pulsent** et brillent deux fois plus fort en chasse.
- **Le brouillard se referme** à chaque stade d'éveil : de 110 à 52 studs de
  visibilité. La pièce rétrécit sans qu'on touche à la carte.
- **La lanterne du Veilleur** est une lumière mobile visible de loin : la seule
  créature qu'on voit arriver, et donc la plus angoissante à attendre.

---

## L'ordre dans lequel je m'y prendrais

1. La boucle de respiration de **L'AFFAMÉ**. Un seul son, celui de la créature
   la plus rare : c'est le moment le plus marquant du jeu.
2. Les pas des quatre créatures. Les différencier à l'oreille vaut mieux que de
   les différencier visuellement, parce qu'on joue dans le noir.
3. Le battement de cœur sur l'alerte. Il transforme la fenêtre de fuite en
   panique.
4. Le reste (coffre, achats) : du confort, aucune urgence.
