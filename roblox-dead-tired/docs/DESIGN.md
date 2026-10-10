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

## 5. Le monstre

Deux états, et c'est tout. Un comportement lisible fait plus peur qu'une IA
compliquée que le joueur ne comprend pas.

- **Patrouille** — il fait le tour des points de passage, lentement (7 studs/s).
- **Chasse** — lancé sur une planque précise. Il apparaît à
  `fenêtre de fuite × vitesse` studs de la planque, puis avance à 13,5 studs/s.

**Pourquoi on le fait apparaître près du joueur** : s'il devait traverser toute
la carte, un joueur dans une salle éloignée ne risquerait rien et le tirage ne
voudrait plus rien dire. En le plaçant à distance calculée, le danger est réel
mais la fuite est toujours possible — et le joueur le voit arriver, ce qui est
bien plus angoissant qu'une mort subite.

Le joueur court à 16 studs/s, le monstre à 13,5. **La fuite est toujours gagnante
en ligne droite.** On perd parce qu'on hésite, parce qu'on se trompe de couloir,
ou parce qu'on revient chercher un coéquipier. C'est voulu : les morts doivent
être de la faute du joueur, jamais de celle du jeu.

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

## 8. Ce qui n'est PAS fait, et dans quel ordre l'ajouter

Le code livré est un jeu complet et jouable, pas un jeu fini. Par ordre de
rentabilité :

1. **Son.** C'est 80 % de la peur et ça coûte presque rien : des pas qui
   approchent, un souffle, un cœur qui bat quand le monstre est proche. À
   brancher sur `DangerAlert` côté client et sur la distance du monstre.
2. **Une vraie carte.** Mets `GameConfig.Map.UseGeneratedMap = false` et
   construis la tienne, en gardant les tags. Des couloirs étroits et des
   lignes de vue courtes valent mieux que des grandes salles.
3. **Animation de sommeil.** Aujourd'hui le personnage est juste figé. Une
   animation couchée change tout visuellement.
4. **Classement.** Un `OrderedDataStore` sur `TotalBanked` pour un tableau des
   meilleurs veilleurs : c'est le moteur de rétention le moins cher qui existe.
5. **Modèle de monstre.** Celui généré est deux blocs et deux yeux rouges. Ça
   marche étonnamment bien dans le noir, mais un vrai rig fera la différence
   sur les miniatures et donc sur les clics.
6. **Événements de nuit.** Une nuit sur cinq : deux monstres, ou gains doublés,
   ou coffre fermé. C'est ce qui empêche la boucle de devenir mécanique.
