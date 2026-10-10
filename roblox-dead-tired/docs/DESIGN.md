# DEAD TIRED — document de conception

> Titre Roblox conseillé : **Sleep For Money**. Les joueurs Roblox cherchent
> littéralement ce qu'ils veulent faire dans la barre de recherche. Garde
> *DEAD TIRED* comme nom stylisé dans le logo si tu veux les deux.

---

## 1. La phrase du jeu

**Tu es payé pour dormir. Plus l'endroit est dangereux, plus ça paie.**

Tout le reste du jeu découle de cette phrase. Si une fonctionnalité ne sert pas
cette tension, elle ne rentre pas.

---

## 2. La boucle

```
JOUR (25 s)                      NUIT (180 s)
├─ ton argent est déposé         ├─ noir, le monstre patrouille
├─ tu achètes                    ├─ tu choisis une planque (palier 1 à 5)
└─ tu choisis ta stratégie       ├─ tu gagnes $/s dans ta poche "sur toi"
                                 ├─ toutes les 6 s : tirage de risque
                                 ├─ s'il tombe → tu es réveillé, il arrive
                                 └─ soit tu cours au coffre, soit tu continues
```

### Les deux poches d'argent

C'est le mécanisme central et il faut qu'il soit lisible en une seconde :

| Poche | Comment on la remplit | Ce qui peut arriver |
|---|---|---|
| **Sur toi** | en dormant | **tout perdu** si le monstre t'attrape |
| **En banque** | au coffre, ou automatiquement à l'aube | **jamais perdu** |

Un joueur qui ne comprend pas cette différence ne comprend pas le jeu. D'où
l'affichage : « en banque » est petit et gris, « sur toi » est gros, vert,
et la ligne en dessous passe au rouge dès qu'il y a quelque chose à perdre.

---

## 3. Les cinq planques

| Palier | Nom | $/s | Risque par tirage | Débloqué à |
|---|---|---|---|---|
| 1 | Dortoir | 1 | 0 % | début |
| 2 | Couloir de service | 3 | 1,5 % | début |
| 3 | Cave | 8 | 4,5 % | 2 500 $ déposés |
| 4 | Chambre froide | 18 | 10 % | 12 000 $ déposés |
| 5 | Le Nid | 45 | 22 % | 40 000 $ déposés |

Le déblocage est basé sur le **total déposé à vie**, pas sur l'argent en banque.
Sinon dépenser son argent ferait perdre l'accès aux planques, ce qui serait absurde.

### Level design : la distance est le deuxième risque

Dans la carte générée, plus un palier paie, plus sa salle est **loin du coffre**.
Le danger n'est donc pas seulement le tirage pendant le sommeil : c'est aussi
le trajet de retour avec la cagnotte sur toi, pendant que le monstre te cherche.

---

## 4. L'équilibrage, et pourquoi ces chiffres

Avec un tirage toutes les 6 s et une nuit de 180 s, un joueur a au maximum
**30 tirages**. L'espérance de gain si on dort `n` tirages d'affilée vaut :

```
EV(n) = (gain par tirage) × n × (1 − risque)^n
```

Cette fonction a un maximum. Les chiffres ont été choisis pour que ce maximum
soit **presque le même sur tous les paliers**, mais avec une variance qui explose.
Vérifié par simulation (200 000 nuits par palier) :

| Palier | n optimal | Gain moyen | Écart-type | Nuits à 0 $ | Si tu restes les 30 tirages |
|---|---|---|---|---|---|
| Dortoir | 30 | 180 $ | 0 $ | 0 % | 180 $ |
| Couloir | 30 | 343 $ | 260 $ | 36 % | 343 $ |
| Cave | 22 | 384 $ | 508 $ | 64 % | 362 $ |
| Chambre froide | 9 | 377 $ | 474 $ | 61 % | **137 $** |
| Le Nid | 4 | 399 $ | 521 $ | 63 % | **5 $** |

Ce que ce tableau dit, et c'est exactement l'effet voulu :

- **Aucun palier n'est objectivement meilleur** si on joue au hasard. Le Dortoir
  rapporte deux fois moins mais ne rate jamais.
- **La dernière colonne punit la cupidité.** Rester toute la nuit dans Le Nid
  rapporte 5 $ en moyenne. Le joueur doit *partir à temps*, et c'est là qu'est
  la décision intéressante.
- **La variance est le vrai produit.** Les paliers profonds ne vendent pas de
  l'argent, ils vendent de l'adrénaline et des histoires à raconter.

### Comment la progression devient gratifiante

Les chiffres ci-dessus supposent qu'un joueur repéré perd tout. **Ce n'est pas
le cas dans le jeu.** Un tirage qui tombe ne te prend pas ton argent : il te
réveille et lance le monstre sur toi, avec 4,5 s d'avance (plus si tu as le
réveil à vibration). Tu ne perds que si tu te fais **attraper**.

Donc le gain réel est supérieur au tableau, et il dépend de deux choses que le
joueur peut améliorer :

1. **Son skill** — connaître la carte, partir au bon moment, prendre le bon couloir.
2. **Son équipement** — les bouchons d'oreille réduisent le risque jusqu'à −60 %,
   le réveil allonge la fenêtre de fuite, les baskets raccourcissent le trajet.

C'est ce qui fait qu'un joueur équipé et expérimenté gagne beaucoup plus dans
Le Nid qu'un débutant — sans qu'on ait eu besoin de truquer les chiffres.

> ⚠️ Le plancher à 0,2 sur la réduction de risque (`EconomyService.getModifiers`)
> est volontaire : aucun empilement d'objets ne doit rendre un palier
> **totalement** sûr. Le jour où un joueur peut dormir dans Le Nid sans risque,
> le jeu est mort.

---

## 5. Les créatures — une par planque

Ce n'est pas un seul monstre qui devient plus dur. **C'est une créature
différente selon l'endroit où tu dors**, chacune avec son comportement et sa
contre-mesure. Le joueur n'apprend donc pas « le monstre », il apprend quatre
monstres, et chacun lui demande un réflexe différent.

| Palier | Créature | Comportement | Vitesse | Comment s'en sortir |
|---|---|---|---|---|
| 1 | — | personne ne vient | — | le dortoir est vraiment sûr |
| 2 | **LE VEILLEUR** | marche, porte une lanterne visible de loin | 11 | casse sa ligne de vue 3 s et il te perd |
| 3 | **LA RAMPANTE** | aveugle, ne suit que le **mouvement** | 18 | **arrête-toi net** et deviens invisible |
| 4 | **LE MIME** | déguisé en lit ; se téléporte quand personne ne le regarde | 13 | garde-le en vue : regardé, il ne peut pas sauter |
| 5 | **L'AFFAMÉ** | ne lâche jamais, ignore les murs du regard | 15 | aucune. Cours. |

Le joueur court à **16**. La Rampante est donc la seule plus rapide que lui —
et c'est justement celle qu'on arrête en ne bougeant plus. Chaque créature a
une réponse, et aucune réponse ne marche sur deux créatures. C'est ça qui fait
qu'on continue à jouer après avoir compris la première.

### Pourquoi la créature apparaît près du joueur

Elle est placée à `fenêtre de fuite × vitesse` studs de la planque. Si elle
devait traverser la carte, un joueur dans une salle éloignée ne risquerait rien
et le tirage de risque ne voudrait plus rien dire. Là, le danger est réel mais
la fuite reste possible — et le joueur la **voit arriver**, ce qui est bien plus
angoissant qu'une mort subite.

### La fiche de première rencontre

À la première fois qu'une créature te prend en chasse, le jeu affiche son nom,
sa phrase, et **comment s'en sortir**. Ce n'est pas de la décoration : un joueur
qui meurt sans comprendre pourquoi ne revient pas, un joueur qui meurt en
sachant ce qu'il aurait dû faire relance une partie.

---

## 5 bis. L'ÉVEIL — « le monstre évolue selon là où tu te caches »

Un compteur **partagé par tout le serveur** monte à chaque tirage de risque
d'un dormeur, de `palier − 1` points. Dormir dans Le Nid remplit donc la jauge
quatre fois plus vite que le couloir de service.

| Stade | Nom | Vitesse | Portée de vue | Taille | Visibilité |
|---|---|---|---|---|---|
| 1 | CALME | ×1 | ×1 | ×1 | 110 studs |
| 2 | AGITÉ | ×1,08 | ×1,25 | ×1,06 | 90 studs |
| 3 | ÉVEILLÉ | ×1,16 | ×1,6 | ×1,14 | 68 studs |
| 4 | AFFAMÉ | ×1,24 | ×2 | ×1,24 | 52 studs |

Au stade 4, **L'AFFAMÉ sort de sa chambre** même si plus personne ne dort au
palier 5, et il erre pour de bon.

Le compteur retombe à zéro à l'aube : c'est une pression qui monte **dans** la
nuit, pas une difficulté qui s'installe définitivement.

Trois choses que ce système apporte, et c'est pour ça qu'il existe :

1. **Les créatures grandissent littéralement.** Le joueur voit la silhouette
   s'allonger et le brouillard se refermer. Il n'a pas besoin de lire la jauge
   pour sentir que ça tourne mal.
2. **La cupidité devient collective.** Celui qui descend dans Le Nid met tout le
   serveur en danger. En multi, ça crée des engueulades — et les engueulades,
   c'est de la rétention.
3. **C'est de la difficulté gratuite.** Les mêmes quatre créatures fournissent
   seize comportements effectifs sans une ligne d'IA en plus.

---

## 6. Le multijoueur : pourquoi on vient te chercher

Quand tu es attrapé tu n'es pas mort, tu es **à terre** : 45 s avant de lâcher.
Un coéquipier peut te relever en maintenant E pendant 6 s — donc en restant
immobile, à portée du monstre, qui peut changer de cible en cours de route.

Et surtout : **celui qui te relève touche la même somme que celle que tu
récupères** (la moitié de ce que tu avais perdu). Sans cette récompense, personne
ne prendrait jamais le risque, et le multi ne servirait à rien. Avec elle,
sauver quelqu'un qui dormait dans Le Nid devient un pari rentable.

---

## 6 bis. Les skins — vendre du statut, jamais de la puissance

**Aucun cosmétique ne donne le moindre avantage.** Pas de vitesse, pas de
réduction de risque, pas de gain. C'est écrit comme une règle en haut de
`CosmeticCatalog.luau`, et ce n'est pas de la pudeur : le jour où un skin rend
meilleur, les joueurs qui ne l'ont pas arrêtent de jouer et ceux qui l'ont
s'ennuient.

Cinq emplacements, un équipé à la fois : **apparence · traînée · aura · titre ·
literie** (visible pendant que tu dors).

Ce qui fait marcher le système, c'est que les meilleurs skins **ne s'achètent
pas avec de l'argent seulement** :

| Skin | Prix | Condition en plus |
|---|---|---|
| Doré sur tranche | 12 000 $ | 20 000 $ déposés à vie |
| Le Revenant | 25 000 $ | avoir dormi au palier 5 **et** survécu à 15 nuits |
| Verre dépoli | 40 000 $ | 75 000 $ déposés à vie |
| Titre « A dormi dans Le Nid » | 20 000 $ | avoir dormi au palier 5 |
| Cercueil capitonné | 35 000 $ | 25 nuits survécues |

Un cosmétique qui s'achète en dix secondes ne donne aucun statut. Un titre que
les autres voient au-dessus de ta tête et qu'ils savent impossible à acheter,
oui. Et tout est appliqué **côté serveur**, donc visible par tout le monde :
un skin que seul son propriétaire voit ne sert à rien.

Les skins verrouillés restent **affichés**, avec leur condition écrite en clair.
Cacher ce qu'on ne peut pas encore avoir, c'est se priver de la seule chose qui
donne envie de continuer.

---

## 7. Monétisation

Ce qui se vend sans casser le jeu :

| Offre | Type | Effet |
|---|---|---|
| Double Argent | Game Pass | ×2 sur les gains de sommeil |
| Seconde chance | Game Pass | une réanimation auto par nuit |
| Chambre VIP | Game Pass | une planque de palier 3 totalement sûre |
| Petite / Grosse liasse | Developer Product | +2 500 $ / +12 000 $ |
| Relevage immédiat | Developer Product | te remet debout quand tu es à terre |

**Ce qu'il ne faut pas vendre :** l'immunité au monstre. Le jour où l'achat
supprime le risque, il supprime le jeu, et les joueurs partent. La Chambre VIP
est à la limite acceptable parce qu'elle est plafonnée au palier 3 : elle fait
gagner du temps, pas la partie.

Tant que les IDs valent `0` dans `Monetization.luau`, rien de tout ça
n'apparaît et le jeu tourne normalement.

---

## 8. Ce qui reste à faire, par ordre de rentabilité

1. **Le son.** C'est 80 % de la peur et ça ne coûte rien. Toute la plomberie est
   déjà en place (champs `StepSoundId` / `VoiceSoundId` par créature, spatialisation
   réglée) : il ne manque que les IDs. Voir **SOUND.md**, avec les requêtes exactes
   à taper dans la Toolbox et le son à faire en premier.
2. **Le texte sur l'affiche.** L'image est générée et volontairement sans texte.
   Dix minutes dans Canva. Voir **MARKETING.md**.
3. **Les modèles de créatures.** Les quatre sont construits en code et lisibles
   dans le noir (silhouette + yeux), mais un vrai modèle changerait l'impression
   sur les miniatures. Les quatre concepts sont générés comme référence. Dépose
   un modèle dans `ServerStorage/Entities/<id>` et il est pris automatiquement :
   aucune ligne de code à changer.
4. **Animation de sommeil.** Le personnage est figé avec un balancement calculé.
   Une vraie animation couchée changerait beaucoup visuellement.
5. **Classement.** Un `OrderedDataStore` sur `TotalBanked`. C'est le moteur de
   rétention le moins cher qui existe.
6. **Une vraie carte.** `GameConfig.Map.UseGeneratedMap = false` et tu tagues la
   tienne. Des couloirs étroits valent mieux que des grandes salles — et pense
   aux lignes de vue, deux créatures sur quatre en dépendent.
7. **Événements de nuit.** Une nuit sur cinq : deux créatures en même temps,
   gains doublés, coffre fermé. C'est ce qui empêche la boucle de devenir
   mécanique.
