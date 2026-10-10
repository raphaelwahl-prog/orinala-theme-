# Mettre le jeu en route

## Le plus rapide — la place déjà construite

Double-clic sur `SleepOrDie.rbxlx`. C'est tout. Studio s'ouvre, tout est en
place, F5 lance la partie.

Pour que les sauvegardes marchent en test : dans Studio, **Fichier → Paramètres
du jeu → Sécurité → Activer l'accès aux services d'API Studio**. Sans ça, le
jeu tourne quand même : `PlayerDataService` bascule en mémoire et prévient dans
la sortie.

## Avec Rojo, si tu préfères coder dans un éditeur

```sh
rojo serve default.project.json
```

Puis dans Studio : plugin Rojo → Connect. Chaque sauvegarde de fichier est
poussée dans la place en direct.

## Après chaque modification du code

```sh
python3 tools/build_place.py
```

Le script refuse d'écrire si un module manque dans la place générée — ça évite
le cas pénible où Studio s'ouvre sans erreur et plante seulement au Play.

## Remplacer les modèles générés par les tiens

Le code construit tout en primitives pour que ça tourne tout de suite. Pour
mettre tes propres modèles :

- **Monstres** : dépose un `Model` dans `ServerStorage/Monsters`, nommé comme
  l'identifiant dans `MonsterConfig` (`prowler`, `doll`, …). Il doit contenir un
  `Humanoid` et une `PrimaryPart`.
- **Refuges** : n'importe quel `Model` avec le tag `Shelter` et les attributs
  `ShelterId` (texte unique) et `Zone`. Le jeu ne connaît rien d'autre d'eux.
- **PNJ** : un `Model` avec le tag `Npc` et l'attribut `NpcId`.
- **Porte de zone** : une `Part` avec le tag `ZoneGate` et l'attribut `Zone`.

Tant que les tags et attributs sont là, tu peux remplacer `CityBuilder.luau`
par une vraie ville sans toucher à une ligne des services.
