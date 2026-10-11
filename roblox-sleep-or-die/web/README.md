# SLEEP OR DIE — la version navigateur

`sleep-or-die.html` est un **fichier unique** qui s'ouvre d'un double-clic, sur
Mac, PC ou téléphone. Rien à installer.

## Pourquoi elle existe

Un `.rbxlx` ne s'ouvre que dans **Roblox Studio**, qui n'existe que sur Windows
et macOS — pas sur téléphone, et Roblox n'accepte plus qu'on téléverse une place
depuis son site. Tant qu'on n'a pas Studio sous la main, le jeu Roblox est
invisible. Cette version-là se regarde et se joue tout de suite.

**Ce n'est pas le jeu Roblox.** C'est le même jeu, porté sur un moteur
navigateur, avec les valeurs exactes des fichiers `src/shared/*.luau` :

| Repris à l'identique | Absent, et ça ne peut pas être autrement |
|---|---|
| Les 7 zones, leurs taux, plafonds, durées de session et pertes à la mort | Le multijoueur — l'éveil est une jauge de **serveur** ; ici elle n'est qu'à toi |
| Les 7 monstres et leurs 7 mécaniques (§5 du CDC) | Les achats Robux |
| La jauge d'éveil : seuils 0/16/40/76, quatre stades, effet sur vitesse, vue et gains | Les classements saisonniers |
| Les 12 objets de `ItemConfig` à leurs prix | Les refuges disputés entre joueurs |
| Le boss en trois phases qui rejouent `sound`, `gaze`, `relentless` | Les missions et les PNJ |

Les zones non débloquées restent **visitables en aperçu** — l'intérêt de cette
version est qu'on voie les sept monstres sans jouer cinq heures — mais les gains
n'y sont pas crédités, sinon la progression ne voudrait plus rien dire.

## Le parvis

On n'arrive plus directement dans la rue. On arrive sur **le parvis** : une
place sûre, hors de la ville. Aucun monstre n'y entre, on n'y dort pas, on n'y
gagne rien. Elle existe pour deux raisons.

**Expliquer sans bloquer.** Trois bornes en travers du chemin, qu'on lit en
passant — dormir paie, ce qu'on porte se perd, la maison se réveille. Pas de
panneau qui met la partie en pause et qu'il faut fermer.

**Donner un point de départ.** Sept portails alignés au fond, un par zone, du
plus proche au plus lointain. Chacun a la couleur de sa zone et un tapis au
sol : on le reconnaît avant de lire. On les **traverse**, on ne les active pas.
Chaque zone a son portail de retour à côté du point d'arrivée.

Un verrou d'une seconde et demie suit chaque voyage : sans lui, on arrive à
côté du portail de retour, il se déclenche dans la foulée, et on fait
l'aller-retour en boucle.

## Commandes

| Touche | Action |
|---|---|
| `ZQSD` · `WASD` · flèches | se déplacer — **toutes les dispositions** |
| souris | regarder (deux monstres réagissent au regard) |
| `E` | dormir · déposer au coffre · boutique |
| `F` ou clic | frapper — ça étourdit, ça ne tue pas |
| traverser un portail | changer de zone |
| `N` | la liste des zones (raccourci) |
| `Maj` | courir — et se faire entendre |
| `Espace` | se réveiller |
| `Échap` | pause |
| `G` | menu (bouton tactile unique sur téléphone) |

## Deux corrections qui méritent d'être expliquées

**« ZQSD ne marche pas ».** Une touche a deux identités : `e.key` (ce qui est
écrit dessus) et `e.code` (où elle se trouve). Le jeu lit maintenant **les
deux** — donc AZERTY, QWERTY, QWERTZ et même ЙЦУКЕН fonctionnent sans réglage.
Mais la vraie cause de l'impression de clavier cassé était ailleurs : un
panneau ouvert (révélation d'un monstre, pause) met la partie en pause, et on
peut marteler ZQSD sans que rien ne bouge. Désormais **une touche de
déplacement referme le panneau et relance la partie**.

**« C'est moche et pixelisé ».** Trois causes, toutes mesurées :
les textures faisaient 64 px étirés sur des murs de 50 studs ; il n'y avait
aucun **filtrage anisotrope**, donc toute surface vue en biais partait en
bouillie ; et il n'y avait aucune ombre portée. Maintenant : textures 256 px,
anisotropie 16×, ombres douces projetées par la torche, matériaux à vraie
rugosité avec carte de relief, halos additifs, et une palette propre à chaque
zone. Une première tentative avait monté l'éclairage ambiant — résultat plus
clair mais **plus plat, donc plus laid** : ce qui fait une image, c'est le
contraste entre la flaque de lumière et le noir autour.

## Vérifier

```sh
cd /tmp && npm i playwright          # les navigateurs sont déjà présents
mkdir -p /tmp/threejs && cd /tmp/threejs && npm pack three@0.136.0 \
  && tar xzf three-0.136.0.tgz       # Three.js en local (les CDN sont bloqués ici)

node tools/test_web.js               # on JOUE au jeu, on ne le relit pas
node tools/shots_web.js /tmp/shots   # une capture par zone
```

`test_web.js` lance un vrai Chromium, clique sur Jouer, appuie sur les touches
dans quatre dispositions de clavier, voyage dans les sept zones, met chacune des
sept mécaniques à l'épreuve, vérifie l'économie au centime, balaye 1 800
positions de caméra et joue une session complète jusqu'au dépôt au coffre.

C'est cette méthode — jouer plutôt que relire — qui avait sorti six bugs
invisibles sur le prototype, et qui a encore trouvé ici la caméra en vue
plongeante dans les petites pièces et le `shadow.radius` ignoré par
`PCFSoftShadowMap`.
