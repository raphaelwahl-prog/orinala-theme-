# Mettre le jeu en route

Deux chemins. Le **B** est plus rapide si tu n'as jamais utilisé Rojo.

---

## Chemin A — avec Rojo (recommandé si tu veux continuer à coder)

Rojo synchronise les fichiers de ce dossier vers Roblox Studio en direct : tu
édites dans ton éditeur, Studio se met à jour tout seul.

1. Installe Rojo : https://rojo.space/docs/v7/getting-started/installation/
2. Installe le plugin **Rojo** dans Roblox Studio (bouton « Install Plugin » sur
   la même page).
3. Dans un terminal, à la racine de `roblox-dead-tired/` :
   ```
   rojo serve
   ```
4. Dans Studio : onglet **Plugins** → **Rojo** → **Connect**.
5. Appuie sur **Play**. C'est tout.

---

## Chemin B — à la main, sans rien installer

Tu crées la même arborescence à la main dans Studio. Compte 10 minutes.
L'important, ce sont **les noms** : les scripts se cherchent par leur nom.

### 1. ReplicatedStorage

Crée un **Folder** nommé exactement `Shared`, et dedans 6 **ModuleScript**, qui
reprennent chacun le nom du fichier correspondant dans `src/shared/` :

`GameConfig` · `ShopCatalog` · `Monetization` · `Net` · `EntityCatalog` ·
`CosmeticCatalog`

### 2. ServerScriptService

Crée un **Script** (pas un ModuleScript) nommé `Server`, colle dedans
`src/server/init.server.luau`.

Puis crée **à l'intérieur de ce Script** 15 **ModuleScript** :

`DataService` · `NotifyService` · `EconomyService` · `ProgressionService` ·
`ZoneService` · `SleepService` · `LifeService` · `ThreatService` ·
`RoundService` · `ShopService` · `MonetizationService` · `MapBuilder` ·
`AwakeningService` · `CosmeticService` · `EntityBuilder`

Chacun reçoit le fichier du même nom dans `src/server/`.

> Pour créer un enfant : clic droit sur le Script `Server` → Insert Object →
> ModuleScript. Oui, un Script peut contenir des ModuleScripts.

### 3. StarterPlayer → StarterPlayerScripts

Crée un **LocalScript** nommé `Client`, colle `src/client/init.client.luau`.

Dedans, 4 **ModuleScript** : `UiKit`, `Hud`, `ShopUI`, `CosmeticUI` — contenu
des fichiers du même nom dans `src/client/`.

### 4. Lance

Appuie sur **Play**. Au bout de 25 secondes la première nuit commence.

---

## Activer la sauvegarde

Par défaut, en Studio, les DataStores sont bloqués : tu joueras normalement mais
rien ne sera gardé entre deux sessions. Le jeu te le dit dans le chat au
démarrage.

Pour l'activer : **Home → Game Settings → Security → Enable Studio Access to
API Services** (il faut que le jeu soit publié).

---

## Activer les achats Robux

1. Publie le jeu.
2. Site Roblox → **Créations** → ton jeu → **Monétisation**.
   - **Passes** → crée « Double Argent », « Seconde chance », « Chambre VIP ».
   - **Developer Products** → crée « Petite liasse », « Grosse liasse »,
     « Relevage immédiat ».
3. Copie chaque ID dans `src/shared/Monetization.luau` (remplace les `0`).

Tant qu'un ID vaut `0`, l'offre n'apparaît pas et rien ne plante.

---

## Utiliser ta propre carte

Mets `GameConfig.Map.UseGeneratedMap = false`, puis tague tes parts.
Pour mettre un tag : sélectionne la part → fenêtre **Tags** (View → Tags).

| Tag | Sur quoi | Attributs à ajouter |
|---|---|---|
| `SleepSpot` | la part sur laquelle on dort | `Tier` (nombre, 1 à 5) — et `SpotLabel` (texte) si tu veux un nom à toi, `Vip` (booléen) pour la chambre VIP |
| `BankTerminal` | le coffre | — |
| `ShopTerminal` | la borne d'équipement | — |
| `SkinTerminal` | la borne de skins | — |
| `PatrolPoint` | des parts invisibles sur le trajet du monstre | — |


Il n'y a **plus de tag `Monster`** : les créatures sont créées automatiquement
par `ThreatService` à partir de `EntityCatalog.luau`. Si tu veux fournir tes
propres modèles, mets-les dans `ServerStorage/Entities/` nommés `watchman`,
`crawler`, `mimic`, `starved` (un PrimaryPart suffit) — ils seront utilisés
sans aucune modification de code.

Pour ajouter un attribut : sélectionne la part → panneau **Properties** →
tout en bas, section **Attributes** → **+**.

Mets au moins 5 ou 6 `PatrolPoint` répartis sur la carte : ce sont aussi les
points d'apparition du monstre quand il vient chercher un dormeur. S'il n'y en
a pas, il apparaît dans une direction au hasard — ça marche, mais c'est moins bon.

---

## Régler l'équilibrage

Tout est dans `src/shared/GameConfig.luau`. Les réglages qui changent le plus
la sensation du jeu, dans l'ordre :

| Réglage | Effet si tu l'augmentes |
|---|---|
| `Round.RiskTickInterval` | moins de tirages par nuit → jeu plus permissif |
| `Round.WarningLead` | plus de temps pour fuir → beaucoup plus facile |
| `Tiers[n].DetectChance` | le palier devient plus dangereux |
| `Tiers[n].Rate` | le palier paie plus |
| `EntityCatalog.Entities[n].BaseSpeed` | **attention** : au-delà de 16 la créature court plus vite que le joueur et la fuite devient impossible (la Rampante est à 18 exprès : on l'arrête en ne bougeant plus) |
| `EntityCatalog.Awakening.Thresholds` | des seuils plus hauts = l'éveil monte moins vite |
| `Downed.BleedoutSeconds` | plus de temps pour être sauvé → multi plus pardonnant |

Après chaque changement de `Rate` ou `DetectChance`, relis le tableau
d'espérance de gain dans `DESIGN.md` : si un palier devient strictement meilleur
que les autres, tous les joueurs n'iront plus que là et le jeu perd ses cinq
niveaux de tension.
