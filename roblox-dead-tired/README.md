# DEAD TIRED

Jeu d'horreur coopératif Roblox. **Tu es payé pour dormir. Plus l'endroit est
dangereux, plus ça paie.**

Cinq planques, de 1 $/s sans aucun risque à 45 $/s dans la chambre du monstre.
L'argent gagné en dormant reste *sur toi* et se perd entièrement si tu es
attrapé — il faut le ramener au coffre. Chaque nuit est donc la même question :
une planque de plus, ou j'encaisse ?

## Démarrer

→ **[docs/SETUP.md](docs/SETUP.md)** — avec Rojo (2 min) ou à la main dans
Studio (10 min, rien à installer).

Au premier lancement le serveur **génère une carte jouable** : 5 salles, un
coffre, une boutique, un monstre, des points de patrouille. Tu peux jouer
immédiatement sans rien modéliser.

## Comprendre les choix de game design

→ **[docs/DESIGN.md](docs/DESIGN.md)** — la boucle, l'équilibrage des cinq
paliers (avec les calculs d'espérance de gain vérifiés par simulation),
le comportement du monstre, le levier coopératif, la monétisation, et la liste
de ce qu'il reste à faire par ordre de rentabilité.

## Commandes

| Touche | Action |
|---|---|
| `E` | interagir — dormir, déposer, ouvrir la boutique, relever un coéquipier |
| `Espace` | se réveiller |
| `B` | boutique |

## Organisation du code

```
src/shared/     GameConfig · ShopCatalog · Monetization · Net
src/server/     init.server + 12 services
src/client/     init.client + UiKit · Hud · ShopUI
```

Deux règles tenues partout dans le code :

- **Aucun nombre en dur hors de `GameConfig.luau`.** Pour rééquilibrer le jeu,
  tu ne touches qu'un seul fichier.
- **Le client ne décide de rien.** Il affiche et il transmet des intentions.
  Tout — argent, risque, achats, captures — est calculé et validé côté serveur.
  C'est la seule architecture qui tient face aux exploits sur Roblox.

Les 21 fichiers `.luau` ont été vérifiés avec le compilateur Luau officiel.
