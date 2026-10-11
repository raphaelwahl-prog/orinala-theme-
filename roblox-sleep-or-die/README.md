# SLEEP OR DIE

Jeu Roblox de survival horror multijoueur. **Tu dors pour gagner de l'argent.
Plus la zone est dangereuse, plus ça paie — et plus tu risques de tout perdre
avant d'avoir pu le déposer.**

Ce dépôt contient **les sept zones**, leurs sept monstres avec leurs sept
mécaniques, le combat final en trois phases, les missions et l'économie
complète. On peut aller de la rue au carnaval sans sortir du jeu.

C'est la version aboutie de ce qui s'appelait **DEAD TIRED** (dossier
`roblox-dead-tired/`, gardé comme prototype). Tout ce que le prototype avait
de bon est ici : la jauge d'éveil partagée, le relevage entre joueurs, les
skins.

## Ouvrir et jouer

Double-clique **`SleepOrDie.rbxlx`**. Roblox Studio s'ouvre avec les 39 scripts
en place. Appuie sur **F5**. Rien à installer, pas de Rojo.

Au démarrage, le serveur construit la rue : immeubles, ruelles, six refuges,
le coffre, la boutique, les six PNJ, l'entrée des égouts et les rôdeurs.

| Touche | Action |
|---|---|
| `E` | réserver un refuge · dormir · parler · déposer au coffre |
| `Espace` | se réveiller |
| `B` | défenses du refuge |
| `M` | missions |
| `N` | les sept zones |
| `C` | skins |
| `V` | l'événement en cours, et sa récompense |
| `L` | les classements de la saison |
| `K` | après le carnaval — variantes, défis, contrats, collections |
| `P` | paramètres (flashs, bandeaux, invites, sons d'interface) |
| `G` | menu — les quatre écrans ci-dessus, pour le tactile |
| `F` ou clic | frapper (étourdit, ne tue pas) |
| `E` maintenu | relever un coéquipier à terre |
| `Échap` | fermer un panneau |

## Comment ça marche

L'argent existe en deux soldes, comme dans le cahier des charges :

- **Cash** — sécurisé. Sert à acheter. Une mort n'y touche pas.
- **UnbankedCash** — gagné pendant une session de survie. **Une mort en reprend
  la moitié** (davantage dans les zones profondes), et une déconnexion le perd
  entièrement.

Une session de survie démarre quand tu dors dans ton refuge. Elle paie à la
seconde, s'arrête à la mort, à la déconnexion, au réveil ou au bout de sa durée
maximale. Des assauts arrivent à intervalle irrégulier : tes défenses les
retardent, s'usent, et finissent par céder. **Aucun refuge n'est imprenable.**

## L'éveil de la maison

C'est ce qui rend le jeu multijoueur au lieu d'être du solo côte à côte.

Chaque seconde passée à dormir dans une zone profonde remplit une **jauge
partagée par tout le serveur**. Quand elle change de stade, les monstres de
toutes les zones deviennent plus rapides et voient plus loin — **pour tout le
monde**, y compris ceux qui dormaient tranquillement dans la rue.

| Stade | Vitesse | Vue | Gains |
|---|---|---|---|
| CALME | ×1,00 | ×1,00 | ×1,00 |
| AGITÉ | ×1,08 | ×1,25 | ×1,15 |
| ÉVEILLÉ | ×1,16 | ×1,60 | ×1,35 |
| AFFAMÉ | ×1,24 | ×2,00 | ×1,60 |

Les gains montent avec le danger : sinon personne n'aurait de raison de
remplir la jauge. La cupidité d'un seul met la partie entière en danger, et
c'est exactement le but — c'est ce qui fait que les joueurs se parlent.

La jauge redescend quand plus personne ne dort profond.

## À terre, pas mort

Le coup qui te tuerait te met **à terre** s'il y a au moins un autre joueur
sur le serveur. Tu as 30 secondes ; un coéquipier qui maintient `E` à côté de
toi pendant 4 secondes te relève à 40 % de vie. Personne ne vient : tu meurs
normalement, avec la perte d'argent qui va avec.

Seul sur le serveur, le coup tue directement — on ne laisse pas quelqu'un
agoniser sans aucune issue.

## Ce que ça donne à l'écran

Tout est construit en pièces Roblox et en code — **aucun asset à téléverser**,
rien qui puisse être modéré un jour et casser le jeu sans prévenir.

- **Les monstres ont un vrai squelette R6** : torse, tête, deux bras, deux
  jambes, reliés par des `Motor6D`. Leurs membres sont animés en code, la
  phase du cycle de marche suit la vitesse réelle. Avant, c'étaient deux
  boîtes soudées qui glissaient sur le sol.
- **Une silhouette par monstre** : LA CHOSE des égouts est à quatre pattes,
  L'ENTITÉ du couvent est étirée, LE MASQUE porte une casquette, LE MENTEUR
  de l'hôpital se promène avec une lanterne, LE CLOWN fait douze studs.
- **Atmosphere, Bloom, étalonnage de couleur, profondeur de champ** et
  `Technology = Future` (ombres réelles). Chaque zone a son étalonnage : vert
  délavé aux égouts, chaud et contrasté dans la maison, gris désaturé chez le
  slasher, bleu froid au couvent, cyan maladif à l'hôpital, magenta saturé au
  carnaval. La transition est progressive, pas un claquement.
- **L'éveil repeint l'image** : plus la jauge monte, plus le brouillard se
  resserre, plus le bloom déborde et plus l'image vire vers la couleur du
  stade.
- **Particules** : poussière dans la rue, les égouts, la maison et l'hôpital ;
  nappes de brume chez le slasher ; braises au couvent et au carnaval. Textures
  `rbxasset://`, livrées avec Roblox.

- **Des formes, pas que des boîtes** : les têtes des monstres utilisent
  `MeshType.Head` (la vraie tête arrondie d'un avatar), les colonnes du
  couvent et les mâts du carnaval sont des cylindres, les toits du quartier
  sont des coins, les ampoules des sphères. Toutes des formes **intégrées** à
  Roblox — aucun fichier.
- **LE MENTEUR porte le visage classique Roblox** (`rbxasset://textures/face.png`).
  C'est toute la créature : de loin, on croit voir un joueur.

## Le son

Roblox ne sait pas fabriquer un son, il lui faut des fichiers. Mais chaque
installation embarque une petite bibliothèque locale accessible par
`rbxasset://sounds/…` : rien à téléverser, rien à modérer.

Le problème, c'est que ces chemins ne sont garantis par aucune documentation.
Alors **le jeu les essaie un par un au démarrage** et écrit dans la sortie
lesquels ont chargé :

```
[SON] échantillons disponibles :
  ✓ step → rbxasset://sounds/action_footsteps_plastic.mp3
  ✗ swoosh — aucun candidat n'a chargé
```

Tu sais donc exactement ce qui marche chez toi, au lieu de te demander
pourquoi c'est silencieux. Si tout échoue, un avertissement te dit quoi
remplacer.

Avec cinq échantillons on fait tout le jeu : la hauteur (`PlaybackSpeed`) et
les effets intégrés (réverbération, égaliseur, distorsion) transforment le
même son en pas de monstre, en coup contre une porte ou en battement sourd.
C'est ce que font tous les jeux — peu de sons, beaucoup de variantes.

Ce qui sonne : les pas des monstres (calés sur l'animation, plus lourds pour
les gros), le moment où l'un te repère, ses attaques, les coups contre ton
refuge, l'alarme de proximité, la mise à terre et le relevage, l'encaissement,
les achats, les déblocages, les refus. Et une **nappe grave continue** dont le
volume et la hauteur montent avec l'éveil de la maison.

Ce qui manque encore : aucun MeshPart (il faudrait téléverser des modèles), et
les animations sont procédurales plutôt que des `Animation` importées.

## Les sept zones

| # | Zone | Taux | Pour y entrer | Monstre |
|---|---|---|---|---|
| 1 | La rue | 10 $/s | départ | Le Rôdeur |
| 2 | Les égouts | 100 $/s | 10 k$ déposés, 2 missions | La Chose |
| 3 | La maison des poupées | 500 $/s | 200 k$, 3 missions, 3 nuits | La Poupée |
| 4 | Le quartier du slasher | 1,5 k$/s | 1,5 M$, quête de poursuite | Le Masque |
| 5 | Le couvent maudit | 5 k$/s | 5 M$, quête de veillée | L'Entité |
| 6 | L'hôpital des cauchemars | 12,5 k$/s | 15 M$, nuit extrême | Le Menteur |
| 7 | Le carnaval de l'enfer | 100 k$/s | 60 M$, quête secrète, 10 h de survie | Le Clown (boss) |

**Les sept sont construites.** Chacune occupe une dalle de 1600 studs et a sa
propre identité : tunnels étroits aux égouts, grandes lignes de vue dégagées
dans la maison des poupées (c'est ce qui rend la mécanique du regard jouable),
haies et raccourcis chez le slasher, cloître et cellules au couvent, couloir
interminable aux portes identiques à l'hôpital, chapiteau sans abri au
carnaval. On passe de l'une à l'autre par une porte, qui téléporte.

Le coffre et la boutique n'existent que dans la rue : c'est le camp de base,
et c'est ce qui rend le retour obligatoire.

## Ce qui est fait, ce qui ne l'est pas

Le détail honnête, section par section du cahier des charges, est dans
**[docs/CDC.md](docs/CDC.md)**. En résumé : tout est fait côté code sauf le §9
bis (rendu), qui attend des MeshPart et des animations importées — deux choses
qui demandent de téléverser, donc toi. Le §12 est écrit mais **les identifiants
de produits Robux sont à `0`** : il faut les créer sur le tableau de bord
Roblox. Reste l'étape 10 du §14, le lancement : mesures de performances, test
sur un vrai téléphone, équilibrage d'après les retours — trois choses qui se
mesurent et ne s'écrivent pas.

### Après le carnaval (§8)

Battre LE CLOWN ouvre un chapitre entier, et c'est la seule porte :
`Achievements.carnival_cleared`, lue à un seul endroit du code.

| | |
|---|---|
| **5 variantes** | Le monstre de la zone avec d'autres chiffres — même silhouette, mêmes sons, donc tout ce que tu as appris sert encore. Sauf avec **L'AVEUGLE**, qui ne voit plus rien et t'entend partout : la mécanique de la zone est remplacée par celle des égouts. Une apparition sur cinq. Tant qu'une variante vit là où tu dors, ça paie plus. |
| **4 défis** | Une règle particulière, armée avant de dormir, valable une session. À NU (tes défenses ne retardent plus rien), SOMMEIL LÉGER (le premier assaut met fin à la session), TOUT OU RIEN (aucun délai de grâce, la mort prend tout), SANS ALERTE (plus un seul message). Chacun est appliqué à **un seul endroit** du code. |
| **5 contrats rares** | Un seul à la fois, proposé à la fin d'une session, trois fois sur quatre refusé. Le délai court en temps réel : se déconnecter ne l'arrête pas. |
| **2 collections** | 7 monstres, 5 formes, et **7 documents** posés dans le monde — sur un point de ronde, donc là où le monstre passe. Un document ne disparaît pas quand on le lit : il reste pour les autres joueurs. |
| **3 titres** | Ils ne s'achètent pas et ne se tirent pas au sort. Ils se remplissent. |

Les multiplicateurs se cumulent, jusqu'à **×4,62** — mais il faut un défi en
cours *et* une variante en vie à côté de toi, c'est-à-dire avoir accepté de
dormir sans défenses auprès de quelque chose qui frappe plus fort.

## Vérifier avant de publier

```sh
npm install luau-web                         # une fois, pour les deux premiers
node check.mjs src/*/*.luau                  # compile les 39 fichiers
python3 tools/logictests.py                  # 140 contrôles : le code FAIT-il ce qu'il dit ?
python3 tools/crosscheck.py                  # 638 liens entre modules
python3 tools/mutate.py                      # 19 mutations : le TEST tient-il ?
python3 tools/checkzones.py                  # 68 contrôles sur les 7 cartes
python3 tools/simulate.py                    # la courbe de progression
python3 tools/build_place.py                 # régénère SleepOrDie.rbxlx
```

`crosscheck.py` attrape ce que le compilateur ne voit pas : un appel vers une
fonction qui n'existe pas, un remote jamais déclaré, un service que le
bootstrap n'utilise jamais.

`logictests.py` attrape ce que `crosscheck.py` ne voit pas : du code qui existe,
qui s'appelle correctement, et qui ne fait rien. Il monte un faux Roblox autour
du vrai code source et l'**exécute** — c'est comme ça qu'on a découvert que les
événements du §13 ne changeaient absolument rien à la partie, bien que tous
leurs réglages soient écrits dans `GameConfig` depuis le début. Il est validé
par mutation : casse une des règles qu'il surveille, il doit échouer. Sinon
c'est lui qui est cassé, pas le jeu.

## Avant de mettre en ligne

1. Créer les Developer Products et les Game Passes sur le tableau de bord
   Roblox, puis recopier leurs identifiants dans `GameConfig.Monetization`
   (ils sont à `0`, donc inactifs).
2. Activer l'accès aux API Studio pour que le DataStore fonctionne en test.
3. Tester sur un vrai téléphone : l'interface est prévue pour, ce n'est pas
   vérifié.

## Organisation

```
src/shared/   GameConfig · ZoneConfig · ItemConfig · MissionConfig
              MonsterConfig · Net · Format
src/server/   init.server + 18 services (noms du CDC §10, plus
              WorldService · ZoneBuilder · ZoneLayouts · BossService
              · ObjectiveService)
src/client/   init.client + Hud + Panels
tools/        build_place.py · crosscheck.py · checkzones.py
              · logictests.py · simulate.py
```
