# Rendre le jeu vendable

Un bon jeu avec une mauvaise affiche ne se joue pas. Sur Roblox, la décision de
cliquer se prend en **moins d'une seconde**, sur trois éléments : l'image, le
titre, le nombre de joueurs en ligne. Ce fichier ne parle que de ça.

---

## 1. Le titre

**`Sleep For Money`**

Pourquoi celui-là et pas *DEAD TIRED* :

- Les joueurs Roblox **tapent ce qu'ils veulent faire**, pas des noms de marque.
  « sleep for money », « survive the night », « hide and seek » — ce sont des
  requêtes réelles. *DEAD TIRED* ne correspond à aucune recherche.
- Il contient la boucle entière en trois mots. Un joueur sait s'il veut y jouer
  avant d'avoir lu la description.
- L'anglais n'est pas négociable : le marché francophone de Roblox est une
  fraction du marché anglophone, et les joueurs français cherchent en anglais.

Garde **DEAD TIRED** comme nom stylisé dans le logo et sur l'affiche. Tu as les
deux : le mot-clé qui ramène les gens, et le nom qui fait sérieux.

Variantes à tester si celui-là est déjà pris : `Paid To Sleep`,
`Sleep For Cash`, `Don't Wake It`.

---

## 2. L'affiche (thumbnail)

### Ce qui est déjà généré

| Fichier | Format | Usage |
|---|---|---|
| Affiche principale | 2688 × 1520 | la grande image de la page du jeu |
| Icône | 1024 × 1024 | la vignette carrée dans les listes |
| 4 concepts de créatures | 1024 × 688 | référence pour modéliser, et visuels de mise à jour |

> ⚠️ Les PNG n'ont pas pu être rapatriés dans ce dépôt : le réseau de mon
> environnement bloque le CDN. **Récupère-les dans ta galerie Higgsfield**
> (ils y sont, générés avec ton compte). Les prompts exacts sont en bas de ce
> fichier pour pouvoir itérer.

### Ce qu'il te reste à faire sur l'affiche

L'image est volontairement **sans texte**, et le haut du cadre est laissé vide
et sombre. Deux raisons : l'IA écrit mal les logos de jeu, et un titre incrusté
devient faux le jour où tu renommes le jeu.

Ajoute le texte dans Canva (gratuit) :

1. Importe l'affiche.
2. Titre en haut, police **très grasse et condensée** (Anton, Archivo Black,
   Bebas Neue). Blanc avec un contour noir épais de 6-8 px.
3. Une accroche en bas à droite, deux fois plus petite : « *Plus c'est
   dangereux, plus ça paie* ».
4. Exporte en PNG, 1920 × 1080.

### La règle qu'il ne faut pas rater

**Teste ton affiche à 150 pixels de large.** C'est la taille réelle dans la
liste des jeux. Réduis-la dans Canva et regarde : si tu ne distingues plus le
visage ni la créature, l'affiche est à refaire, même si elle est belle en grand.
C'est l'erreur n°1 des débutants.

### Pourquoi cette composition marche

| Élément | Pourquoi |
|---|---|
| Visage terrifié en gros, en bas à gauche | l'émotion humaine est ce que l'œil trouve en premier |
| La créature en haut à droite, partiellement dans le noir | le cerveau complète le reste, et ce qu'il complète fait plus peur |
| La liasse de billets bien visible | elle dit l'enjeu sans un mot : argent + danger |
| Contraste extrême, fond noir pur | les listes Roblox sont sur fond clair : une image sombre y crée un trou noir qui attire l'œil |
| Deux couleurs seulement (cyan froid / rouge chaud) | lisible à 150 px, là où une image multicolore devient de la bouillie |

### Plus tard : teste, ne devine pas

Roblox te donne le taux de clic dans les statistiques du jeu. Change **une
seule chose** à la fois (l'affiche, puis le titre), attends 48 h, compare. Deux
changements en même temps ne t'apprennent rien.

---

## 3. La description de la page

Les quatre premières lignes sont les seules visibles sans cliquer « plus ».
Elles doivent contenir la boucle, pas du lore.

```
Tu es payé pour dormir. Plus la planque est dangereuse, plus elle paie.

Le dortoir rapporte 1 $ par seconde et rien ne t'y arrivera jamais.
Le Nid rapporte 45 $ par seconde — mais c'est sa chambre.

L'argent gagné en dormant reste SUR TOI. Si elle t'attrape, tu perds tout.
Ramène-le au coffre avant le lever du jour.

🩸 5 créatures, une par planque. Chacune chasse différemment.
💰 Des skins qui ne s'achètent pas : il faut les mériter.
👥 Fais-toi relever par tes potes — ou laisse-les crever.

Dors mal. Gagne bien.
```

Tags à mettre : `horror`, `survival`, `multiplayer`, `hide and seek`, `scary`,
`money`, `night`.

---

## 4. Les 30 premières secondes décident de tout

Un joueur Roblox quitte un jeu en moins d'une minute s'il ne comprend pas quoi
faire. Ce qui est déjà en place pour ça :

- **La première nuit arrive après 25 s de jour.** Assez pour regarder autour,
  pas assez pour s'ennuyer.
- **Chaque planque affiche son prix et son risque au-dessus d'elle.** Pas de
  tutoriel à lire : le choix est posé en évidence.
- **La fiche de créature à la première rencontre** affiche son nom, sa phrase,
  et surtout **comment s'en sortir**. Un joueur qui meurt sans comprendre ne
  revient pas ; un joueur qui meurt en sachant ce qu'il aurait dû faire relance.
- **Les deux poches d'argent sont affichées différemment** (petit et gris vs
  gros et vert qui pulse) pour qu'on sente ce qu'on risque sans lire de texte.

Ce qu'il manque et qui vaut le plus cher : **le son**. Voir `SOUND.md`.

---

## 5. Ce qui fait revenir les joueurs

| Levier | Comment c'est fait ici |
|---|---|
| **Statut visible** | les titres au-dessus de la tête et les skins sont appliqués côté serveur : tout le monde les voit. « A dormi dans Le Nid » ne s'achète pas sans l'avoir fait. |
| **Progression lisible** | les planques se débloquent au total déposé à vie, annoncé par un message quand le palier tombe. |
| **Histoires à raconter** | la variance énorme des paliers profonds produit des récits (« j'avais 8 000 $ sur moi et il m'a eu à deux mètres du coffre »). C'est ça qui se raconte en cours. |
| **Tension sociale** | la jauge d'ÉVEIL monte quand quelqu'un dort profond, et elle est partagée. Le cupide met tout le serveur en danger. Les engueulades, c'est de la rétention. |
| **Nouveauté peu coûteuse** | ajouter une créature = une entrée dans `EntityCatalog.luau`. Ajouter un skin = une entrée dans `CosmeticCatalog.luau`. Tu peux faire une mise à jour par semaine sans toucher au moteur du jeu. |

---

## 6. Monétisation — ce qui se vend sans tuer le jeu

Déjà codé (IDs à remplir, voir `SETUP.md`) :

- **Double Argent** (pass) — ×2 sur les gains de sommeil.
- **Seconde chance** (pass) — une réanimation auto par nuit.
- **Chambre VIP** (pass) — une planque de palier 3 sûre.
- **Liasses** (produits) — de l'argent direct.

**Ce qu'il ne faut jamais vendre : l'immunité aux créatures.** Le jour où
l'achat supprime le risque, il supprime le jeu. Les skins, en revanche, tu peux
en vendre autant que tu veux : ils ne donnent aucun avantage, et c'est écrit
dans le code comme une règle (`CosmeticCatalog.luau`).

Les skins les plus chers du jeu demandent une **preuve** en plus de l'argent
(avoir dormi au palier 5, avoir survécu à 25 nuits). C'est fait exprès : un
cosmétique qui s'achète en dix secondes avec des Robux ne donne aucun statut.

---

## 7. Les prompts, pour régénérer les visuels

Modèle utilisé : `gpt_image_2_5`, `quality: high`. Affiche en `2k` / `16:9`,
icône en `1k` / `1:1`, concepts en `1k` / `3:2`.

### Affiche principale

```
Roblox game store thumbnail, glossy stylized 3D render in authentic Roblox
avatar style: characters have blocky rectangular heads, cylindrical arms and
legs, shiny plastic toy material. BOTTOM-LEFT FOREGROUND: a Roblox-style boy in
striped blue pyjamas lying on a filthy stained mattress on a wet concrete
basement floor, his blocky head turned to camera, eyes drawn enormous and
bulging with pure terror, mouth wide open mid-scream, both cylindrical arms
hugging a thick fat bundle of green dollar bills tight against his chest, a few
loose bills scattered on the mattress. TOP-RIGHT, looming out of total
darkness: a colossal emaciated ash-grey humanoid creature, ribs showing,
impossibly long thin arms with clawed hands reaching down toward the boy, head a
smooth featureless mask with two narrow glowing blood-red slit eyes and a mouth
torn far too wide. LIGHTING: hard cold cyan rim light raking the boy from screen
left, hot red light spilling from the creature's eyes onto the damp concrete
wall behind, everything else crushed to black. Thick volumetric fog, extreme
contrast, heavily saturated, dramatic cinematic game-cover composition with
strong diagonal. Keep the upper-centre of the frame dark and uncluttered for a
title to be added later. Absolutely no text, no letters, no numbers, no logo,
no watermark.
```

### Icône

```
Roblox game icon, square, glossy stylized 3D render in authentic Roblox avatar
style: blocky rectangular head, shiny plastic toy material. Extreme tight
close-up of a Roblox-style boy's blocky head filling almost the whole frame,
eyes drawn enormous and bulging with terror with tiny pupils, mouth wide open
screaming, cold blue light hitting the left side of his face. Immediately behind
his head, in total blackness, two narrow glowing blood-red slit eyes of a
creature, very close and slightly out of focus. One green dollar bill caught
mid-air in the bottom-left corner. Pitch black background, extreme contrast,
heavily saturated, punchy simple bold composition that stays readable shrunk to
a tiny thumbnail. Absolutely no text, no letters, no numbers, no logo, no
watermark.
```

### Concepts de créatures

Base commune, en remplaçant la partie en majuscules :

```
Character concept art sheet for a video game creature, on a flat dark charcoal
background with a soft grey floor shadow. <CRÉATURE>. Full body, three-quarter
view, clean silhouette, stylized low-poly-friendly shapes suitable for building
in a blocky 3D game engine. Dramatic single light source. No text, no letters,
no watermark.
```

| Créature | Description à insérer |
|---|---|
| LE VEILLEUR | `THE WATCHMAN: a gaunt tall humanoid night watchman, stooped posture, tattered grey uniform and peaked cap, face hidden in shadow under the cap brim with one dim yellow glowing eye, carrying a rusted oil lantern casting weak amber light. Slow and heavy build.` |
| LA RAMPANTE | `THE CRAWLER: an eyeless pale creature sprinting on all fours, head tilted up and turned sideways listening, enormous ragged ears, skin stretched tight over the skull, no eyes at all, mouth full of needle teeth, long spindly limbs with the joints bent the wrong way. Fast and twitchy.` |
| LE MIME | `THE MIMIC: a creature disguised as an ordinary bed, the mattress splitting open down the middle to reveal a vertical mouth lined with human-like teeth, two small black eyes opening on the headboard, thin grey limbs unfolding from underneath the bed frame. Half-transformed, caught mid-reveal.` |
| L'AFFAMÉ | `THE STARVED: an immensely tall skeletal horror, ribs exposed and splayed outward like a cage, hollow stomach cavity, arms so long the clawed hands drag on the floor, head a smooth featureless skull with a ring of many small blood-red glowing eyes, jaw hanging unhinged. Towering and emaciated.` |
