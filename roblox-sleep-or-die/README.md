# SLEEP OR DIE

Jeu Roblox de survival horror multijoueur. **Tu dors pour gagner de l'argent.
Plus la zone est dangereuse, plus ça paie — et plus tu risques de tout perdre
avant d'avoir pu le déposer.**

Ce dépôt contient **les sept zones**, leurs sept monstres avec leurs sept
mécaniques, le boss final en trois phases, les missions et l'économie
complète. On peut aller de la rue au carnaval sans sortir du jeu.

## Ouvrir et jouer

Double-clique **`SleepOrDie.rbxlx`**. Roblox Studio s'ouvre avec les 24 scripts
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
| `F` ou clic | frapper (étourdit, ne tue pas) |
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
**[docs/CDC.md](docs/CDC.md)**. En résumé : §2, 3, 4, 5, 6, 7, 10, 11 et 12
sont faits ; §8, 9 et 13 sont partiels. Restent les étapes 9 et 10 du §14 :
rétention et lancement.

## Vérifier avant de publier

```sh
node /tmp/luaucheck/check.mjs src/*/*.luau   # compile les 28 fichiers
python3 tools/crosscheck.py                  # 364 liens entre modules
python3 tools/checkzones.py                  # 68 contrôles sur les 7 cartes
python3 tools/simulate.py                    # la courbe de progression
python3 tools/build_place.py                 # régénère SleepOrDie.rbxlx
```

`crosscheck.py` attrape ce que le compilateur ne voit pas : un appel vers une
fonction qui n'existe pas, un remote jamais déclaré, un service que le
bootstrap n'utilise jamais.

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
src/server/   init.server + 17 services (noms du CDC §10, plus
              WorldService · ZoneBuilder · ZoneLayouts · BossService
              · ObjectiveService)
src/client/   init.client + Hud + Panels
tools/        build_place.py · crosscheck.py · checkzones.py · simulate.py
```
