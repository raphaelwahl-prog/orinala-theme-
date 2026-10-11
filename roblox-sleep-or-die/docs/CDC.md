# Conformité au cahier des charges

Ce tableau dit, section par section, ce qui est **fait**, ce qui est **partiel**
et ce qui **n'existe pas encore**. Il est écrit pour être relu avant chaque
étape de développement, pas pour faire joli.

La règle que je me suis donnée : si une chose n'est pas réellement branchée
dans le code, elle est marquée « pas fait », même si la configuration existe.

| § | Sujet | État | Où ça vit | Ce qui manque |
|---|---|---|---|---|
| 1 | Présentation | — | — | — |
| 2 | Boucle de jeu | **fait** | `SurvivalService`, `EconomyService` | — |
| 3 | Les 7 zones | **fait** | `ZoneConfig.luau`, `ZoneLayouts.luau` | Les sept cartes existent, chacune avec son identité, ses refuges et ses portes. Elles occupent des dalles de 1600 studs et se rejoignent par téléportation. |
| 4 | Sommeil et refuges | **fait** | `ShelterService`, `SurvivalService` | — |
| 5 | Monstres et IA | **fait** | `MonsterService`, `BossService` | Les 8 états et **les 7 mécaniques** : `sound`, `gaze`, `relentless`, `disable` (le couvent éteint tes défenses), `fake_alerts` (l'hôpital émet de fausses alertes), `boss_phases` (3 phases qui rejouent les mécaniques apprises). |
| 6 | Économie et équipements | **fait** | `EconomyService`, `ItemConfig`, `ShopService` | — |
| 7 | Missions et PNJ | **fait** | `MissionService`, `ObjectiveService` | 16 missions, 6 PNJ, et **les 11 types d'objectifs branchés**. Les quatre ramassables sont des objets du monde qui réapparaissent ; `escape_chase`, `survive_extreme` et `find_secret` se déduisent du jeu, pas d'un bouton. |
| 8 | Progression à long terme | **fait** | `BossService`, `CosmeticService`, `LeaderboardService` | Sept skins, dont quatre qui ne s'achètent pas (dix nuits survécues, la maison des poupées débloquée, le carnaval battu, le mini-boss d'événement abattu). Le boss accorde un trophée et un titre. **Trois classements saisonniers** (argent déposé, nuits survécues, boss battus), remis à zéro chaque mois civil, par OrderedDataStore — avec repli sur les joueurs présents quand le stockage classé est inaccessible, et l'écran le dit. Restent les variantes de monstres et les contrats rares. |
| 8 bis | Éveil partagé | **fait** | `AwakeningService` | Jauge commune à tout le serveur, quatre stades, effet sur la vitesse et la vue de **tous** les monstres, contrepartie en gains, décroissance quand personne ne dort profond. Repris du prototype DEAD TIRED. |
| 8 ter | Entraide | **fait** | `LifeService` | Le coup fatal met à terre plutôt que de tuer quand un autre joueur est là : 30 s de saignement, 4 s de maintien pour relever. Seul sur le serveur, le coup tue. |
| 9 | Interface | **fait** | `Hud.luau`, `Panels.luau` | Neuf panneaux : boutique, défenses, missions, carte, skins, **événement** (V), **classements** (L), **paramètres** (P), écran de mort. Les quatre réglages agissent réellement : flashs d'écran, bandeaux d'alerte, invites contextuelles, sons d'interface. Ils vivent dans le profil, donc ils suivent le compte. |
| 9 bis | Rendu | **partiel** | `MonsterRig`, `AtmosphereService` | Squelettes R6 animés par Motor6D, une silhouette par monstre, têtes `MeshType.Head`, cylindres, sphères et coins, visage classique sur Le Menteur, Atmosphere + Bloom + étalonnage par zone + profondeur de champ, ombres réelles, particules. **Manquent : les MeshPart et les animations importées — les deux demandent de téléverser.** |
| 9 ter | Son | **fait, à vérifier chez toi** | `SoundService` | Pas, repérage, attaques, assauts sur le refuge, alarme, mise à terre, relevage, encaissement, achats, déblocages, et une nappe continue qui monte avec l'éveil. Tout vient de la bibliothèque locale `rbxasset://sounds/`. Le service **teste chaque chemin au démarrage** et écrit dans la sortie ce qui a chargé : si c'est silencieux, tu sais pourquoi en une ligne. |
| 10 | Architecture technique | **fait** | arborescence `src/` | Les noms de services sont exactement ceux du CDC. |
| 11 | Sauvegarde | **fait** | `PlayerDataService` | — |
| 12 | Monétisation | **fait, à configurer** | `MonetizationService` | Le code est complet. **Les identifiants de produits sont à 0** : il faut créer les Developer Products et les Game Passes sur le tableau de bord Roblox et recopier leurs identifiants dans `GameConfig.Monetization`. |
| 13 | Événements | **fait** | `EventService`, `MonsterService`, `WorldService` | Les cinq champs de chaque événement agissent : gains (injectés dans `EconomyService`), **plafond de monstres** (`MonsterService.capFor`), **vitesse des monstres**, **mini-boss** (le monstre de la zone agrandi, jamais dans l'arène du boss), **défi collectif** (sessions et morts comptées sur tout le serveur). La récompense se réclame par un bouton, une fois par période, et son montant suit le multiplicateur. |
| 14 bis | Zones construites | **7 sur 7** | `ZoneLayouts.luau` | Rue, égouts, maison des poupées, quartier du slasher, couvent, hôpital, carnaval. |
| 14 | Ordre de développement | **étapes 1 à 9** | — | L'étape 9 (rétention) est faite : événements complets et classements saisonniers. Reste l'étape 10, le lancement : mesures de performances, tests sur un vrai téléphone, équilibrage d'après les retours — trois choses qui se mesurent et ne s'écrivent pas. |
| 15 | Critères de validation | **9 sur 10 tenus dans le code** | voir ci-dessous | — |

## §15 — les critères, un par un

| Critère | Tenu par |
|---|---|
| Les gains s'arrêtent à la mort et à la déconnexion | `SurvivalService.stop` sur `Died` et `PlayerRemoving`, plus `EconomyService.applyDisconnect`. |
| Les achats ne peuvent pas faire passer le solde sous zéro | `EconomyService.spend` refuse avant de débiter. C'est le seul chemin de dépense. |
| Les zones ne se débloquent pas sans remplir les conditions | `ZoneService.canEnter` revérifie à **chaque** entrée, pas seulement au déblocage. |
| Les missions et récompenses ne peuvent pas être réclamées plusieurs fois | `MissionsDone` pour les uniques, clés de jour/semaine pour les répétables. |
| Les refuges ne peuvent pas avoir plusieurs propriétaires | `ShelterService` : un seul `Owner`, et réserver en relâche un autre. |
| Les monstres ne frappent pas à travers les murs ni à distance impossible | `CombatService.monsterHit` : distance **et** raycast, les deux côté serveur. |
| Les sauvegardes résistent aux erreurs et reconnexions | `retry` avec recul exponentiel, `UpdateAsync`, et `Loaded = false` qui interdit d'écrire. |
| Les achats Robux sont traités sans doublons | `Receipts[PurchaseId]` consulté avant, écrit après, et **sauvegardé avant** de renvoyer `PurchaseGranted`. |
| Le jeu fonctionne sur mobile et PC | Interface en échelle, `ContextActionService` avec boutons tactiles. **À vérifier sur un vrai téléphone.** |
| Les performances restent acceptables en multijoueur | `MaxAlive` par monstre, pathfinding à 2 Hz hors du Heartbeat. **À mesurer avec de vrais joueurs.** |

Les deux derniers ne peuvent pas être « tenus par du code » : ils se mesurent.

## Les quatre couches de vérification

Elles tournent à chaque modification, et chacune attrape ce que les autres ne
voient pas :

| Outil | Ce qu'il prouve | Dernier passage |
|---|---|---|
| compilateur Luau (`luau-web`) | la syntaxe de chaque fichier | 37 fichiers, 0 échec |
| `tools/crosscheck.py` | chaque appel entre modules existe, chaque remote est déclaré, aucun module n'est mort | 542 liens |
| `tools/checkzones.py` | les sept cartes se tiennent et ne débordent pas | 68 contrôles |
| `tools/logictests.py` | **le code fait ce qu'il prétend faire** | 48 contrôles |

La quatrième est la plus utile et la plus récente. Les trois premières vérifient
la forme ; aucune ne dit si un événement change réellement quelque chose.
`logictests.py` assemble un faux Roblox (`game:GetService`, `Instance`, `task`,
`Vector3`, DataStore…) autour du **vrai code source pris sur le disque**, puis
l'exécute. Il a été validé par mutation : on casse volontairement chacune des
six règles qu'il surveille, et on vérifie qu'il le voit. Un test qui passe quoi
qu'on fasse ne vaut rien.

Ce qu'il a trouvé, et que la relecture n'avait pas vu :

* le contrôle du mini-boss était placé **après** son attente de 5 s — le
  monstre arrivait cinq secondes après l'annonce qui le promettait ;
* le plafond de la zone refusait le **boss du carnaval** si un monstre
  traînait dans l'arène (d'où `MonsterService.spawnUnique`) ;
* `model.Name` porte l'**identifiant** du monstre, pas son nom de scène :
  l'annonce de victoire aurait affiché « prowler est tombé ».

## Deux écarts assumés par rapport au document

**1. Un plafond souple par session.** Le CDC donne 100 000 $/s au carnaval et
15 M$ pour débloquer l'hôpital : sans plafond, on gagne de quoi débloquer
l'hôpital en 150 secondes et toute l'économie précédente ne sert plus à rien.
`Zone.SoftCapPerSession` divise le taux par 4 au-delà d'un seuil. Avec ça,
`tools/simulate.py` donne **5 h 33 de jeu effectif** pour aller de la rue au
carnaval, et une session au carnaval vaut 6 fois une session à l'hôpital —
au lieu de 30 fois.

**2. L'argent est un nombre à virgule flottante, jamais un entier.** Un
`IntValue` Roblox sature à 2 147 483 647. À 100 000 $/s, c'est atteint en
**5 h 57**. Au-delà, le compteur se bloque ou repart en négatif. Tout l'argent
passe donc par des `number` et s'affiche via `Format.money` (12,4 k $,
1,50 Md $). Aucun `IntValue` n'est utilisé pour de l'argent dans ce dépôt.
