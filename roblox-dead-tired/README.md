# DEAD TIRED — *Sleep For Money*

Jeu d'horreur coopératif Roblox. **Tu es payé pour dormir. Plus l'endroit est
dangereux, plus ça paie.**

Cinq planques, de 1 $/s sans aucun risque à 45 $/s dans la chambre de la
créature. L'argent gagné en dormant reste *sur toi* et se perd entièrement si on
t'attrape — il faut le ramener au coffre avant l'aube. Chaque nuit, la même
question : une planque de plus, ou j'encaisse ?

## Le truc qui fait la différence

**Ce n'est pas un monstre qui devient plus dur. C'est une créature différente
selon l'endroit où tu dors**, et chacune se contre autrement :

| Palier | Créature | Comment s'en sortir |
|---|---|---|
| 2 | LE VEILLEUR | casse sa ligne de vue 3 secondes |
| 3 | LA RAMPANTE | elle est aveugle — **arrête-toi net** |
| 4 | LE MIME | garde-le en vue, regardé il ne peut pas se téléporter |
| 5 | L'AFFAMÉ | aucune. Cours. |

Et par-dessus : une jauge d'**ÉVEIL** partagée par tout le serveur, qui monte
quand quelqu'un dort profond. Les créatures grandissent, accélèrent, voient plus
loin, le brouillard se referme. Au dernier stade, L'AFFAMÉ sort de sa chambre.
Ta cupidité met toute la partie en danger.

## Les documents

| Fichier | Pour quoi |
|---|---|
| **[docs/SETUP.md](docs/SETUP.md)** | mettre le jeu en route — Rojo (2 min) ou à la main dans Studio (10 min, rien à installer) |
| **[docs/MARKETING.md](docs/MARKETING.md)** | le titre, l'affiche, l'icône, la description, et ce qui fait cliquer sur Roblox |
| **[docs/DESIGN.md](docs/DESIGN.md)** | les calculs d'équilibrage vérifiés par simulation, les créatures, l'éveil, les skins |
| **[docs/SOUND.md](docs/SOUND.md)** | ce qui manque et qui vaut le plus cher, avec les requêtes exactes à taper |

Au premier lancement le serveur **génère une carte jouable** : 5 salles, coffre,
boutique, borne de skins, points de patrouille, et les 4 créatures. Tu peux
jouer immédiatement sans rien modéliser.

## Commandes

| Touche | Action |
|---|---|
| `E` | interagir — dormir, déposer, ouvrir une borne, relever un coéquipier |
| `Espace` | se réveiller |
| `B` | boutique d'équipement |
| `N` | skins |

## Organisation du code

```
src/shared/   GameConfig · Net · ShopCatalog · Monetization
              EntityCatalog (les créatures + l'éveil)
              CosmeticCatalog (les skins)

src/server/   init.server + 15 services
              ThreatService  → comportement des créatures
              EntityBuilder  → leurs corps
              AwakeningService → l'évolution partagée
              CosmeticService  → skins appliqués côté serveur

src/client/   init.client + UiKit · Hud · ShopUI · CosmeticUI
```

Quatre règles tenues partout :

- **Aucun nombre en dur hors des catalogues.** Rééquilibrer le jeu = un fichier.
- **Le client ne décide de rien.** Argent, risque, achats, captures : tout est
  calculé et validé serveur. C'est la seule architecture qui tient face aux
  exploits sur Roblox.
- **Aucun cosmétique ne donne d'avantage.** C'est une règle, pas une préférence :
  un skin qui rend meilleur casse le jeu pour ceux qui ne l'ont pas.
- **Ajouter du contenu ne demande pas de code.** Une créature = une entrée dans
  `EntityCatalog`. Un skin = une entrée dans `CosmeticCatalog`.

Les 25 fichiers `.luau` (6 000 lignes) sont vérifiés avec le compilateur Luau
officiel, et un contrôle statique vérifie que tous les appels entre services,
tous les `require` et tous les Remotes existent réellement.
