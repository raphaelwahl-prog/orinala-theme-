#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Validation par mutation de `logictests.py`.

    python3 tools/mutate.py

On casse une règle à la fois dans le VRAI code source, on relance le banc
d'essai, et on exige qu'il le voie. Une mutation qui survit désigne une règle
que le test prétend surveiller sans la surveiller — un test qui passe quoi
qu'on fasse ne vaut rien.

Le fichier modifié est TOUJOURS remis en l'état, même si la commande échoue
(le `try/finally` autour de l'exécution). Aucune mutation ne doit survivre à
cette commande ; si l'une survit, elle est soit un trou dans le test, soit une
mutation *équivalente* — et dans ce second cas, il faut le démontrer et non le
supposer.

Ce qu'il a trouvé la première fois qu'on l'a passé sur le §8 : le contrat
« croise trois variantes » se remplissait en croisant trois fois la même.
Ce n'était pas un défaut du test, c'était un défaut du jeu.
"""
import subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

MUTATIONS = [
    ("la porte du §8 est grande ouverte",
     "server/EndgameService.luau",
     "\treturn profile ~= nil and profile.Achievements.carnival_cleared == true",
     "\treturn profile ~= nil"),

    ("applyVariant mute le catalogue partagé au lieu de le cloner",
     "server/EndgameService.luau",
     "\tlocal copy = table.clone(def)\n\tcopy.Name = def.Name",
     "\tlocal copy = def\n\tcopy.Name = def.Name"),

    ("L'AVEUGLE ne remplace plus la mécanique de la zone",
     "server/EndgameService.luau",
     "\tif variant.Rule then\n\t\tcopy.Rule = variant.Rule\n\tend",
     "\tif false then\n\t\tcopy.Rule = variant.Rule\n\tend"),

    ("les variantes naissent partout, pas seulement là où un vainqueur se trouve",
     "server/EndgameService.luau",
     "and profile.CurrentZone == zoneId\n\t\t\tand profile.Achievements.carnival_cleared then",
     "and profile.Achievements.carnival_cleared then"),

    ("le comptage distinct des contrats accepte les doublons",
     "server/EndgameService.luau",
     "\t\tif profile.ContractSeen[token] then\n\t\t\treturn\n\t\tend",
     "\t\tif false then\n\t\t\treturn\n\t\tend"),

    ("un contrat distinct se remplit même sans jeton d'identité",
     "server/EndgameService.luau",
     "\t\tif token == nil then\n\t\t\treturn\n\t\tend",
     "\t\tif false then\n\t\t\treturn\n\t\tend"),

    ("un nouveau contrat hérite des éléments déjà comptés",
     "server/EndgameService.luau",
     "\tprofile.ContractProgress = 0\n\tprofile.ContractSeen = {}\n\tprofile.ContractUntil = os.time() + contract.Seconds",
     "\tprofile.ContractProgress = 0\n\tprofile.ContractUntil = os.time() + contract.Seconds"),

    ("on peut changer de défi au milieu d'une session",
     "server/EndgameService.luau",
     "\tif running[player] then\n\t\treturn false, \"Tu es déjà en train d'en tenir un.\"\n\tend",
     "\tif false then\n\t\treturn false, \"Tu es déjà en train d'en tenir un.\"\n\tend"),

    ("une session interrompue tient quand même le défi",
     "server/EndgameService.luau",
     '\tlocal held = reason == "complete" or reason == "challenge"',
     '\tlocal held = true'),

    ("« SOMMEIL LÉGER » coupé compte comme une session complète",
     "server/EndgameService.luau",
     '\tlocal full = reason == "complete"',
     '\tlocal full = held'),

    ("le filtre de zone des contrats ne filtre rien",
     "server/EndgameService.luau",
     "\tif contract.Zone and contract.Zone ~= zoneId then\n\t\treturn\n\tend",
     "\tif false then\n\t\treturn\n\tend"),

    ("un contrat périmé reste en place et bloque les suivants",
     "server/EndgameService.luau",
     "\tif profile.ContractUntil > 0 and os.time() > profile.ContractUntil then\n\t\treturn nil\n\tend",
     "\tif false then\n\t\treturn nil\n\tend"),

    ("la prime de zone déborde sur les autres zones",
     "server/MonsterService.luau",
     "\t\tif agent.ZoneId == zoneId and agent.Variant then",
     "\t\tif agent.Variant then"),

    ("l'écran envoie le texte des documents non trouvés",
     "server/EndgameService.luau",
     "\t\t\tText = found and document.Text or nil,",
     "\t\t\tText = document.Text,"),

    ("un contrat payé n'est pas effacé : on le réclame en boucle",
     "server/EndgameService.luau",
     '\tprofile.Cash += contract.Cash\n\tprofile.Contract = ""',
     '\tprofile.Cash += contract.Cash\n\tprofile.Contract = profile.Contract'),

    ("le tirage pondéré ignore les poids nuls et rend quand même une entrée",
     "shared/EndgameConfig.luau",
     "\tif total <= 0 then\n\t\treturn nil\n\tend",
     "\tif false then\n\t\treturn nil\n\tend"),

    ("la temporisation du hurleur sautée : la jauge partagée se remplit en boucle",
     "server/EndgameService.luau",
     "\t\tif now - (lastHowl[player] or -math.huge) >= HOWL_COOLDOWN then",
     "\t\tif true then"),

    ("n'importe quelle variante réveille la maison, pas seulement le hurleur",
     "server/EndgameService.luau",
     '\tif variantId == "hurleur" and awakeningJolt then',
     "\tif awakeningJolt then"),

    ("le compteur de progression peut dépasser la cible",
     "server/EndgameService.luau",
     "\tprofile.ContractProgress = math.min(contract.Target, profile.ContractProgress + amount)",
     "\tprofile.ContractProgress = profile.ContractProgress + amount"),
]


def run() -> tuple[int, str, bool]:
    done = subprocess.run([sys.executable, "-I", "tools/logictests.py"],
                          cwd=ROOT, capture_output=True, text=True)
    # Un banc d'essai qui PLANTE est une détection, pas une survie : la
    # mutation a cassé le code au point qu'il ne tourne plus. Le signe, c'est
    # que la ligne de total ne sort jamais.
    finished = "vérifications passées" in done.stdout
    return done.returncode, done.stdout, finished


caught, survived = 0, []
for label, relative, old, new in MUTATIONS:
    path = SRC / relative
    original = path.read_text(encoding="utf-8")
    if old not in original:
        survived.append((label, "MOTIF INTROUVABLE — la mutation n'a pas été appliquée"))
        print(f"  ?? {label}\n       motif introuvable dans {relative}")
        continue
    path.write_text(original.replace(old, new, 1), encoding="utf-8")
    try:
        code, out, finished = run()
    finally:
        path.write_text(original, encoding="utf-8")

    failures = out.count("ÉCHEC")
    if code != 0 and failures > 0:
        caught += 1
        first = next((l.strip() for l in out.splitlines() if "ÉCHEC" in l), "")
        print(f"  vu   {label}\n       → {failures} échec(s), 1er : {first[:96]}")
    elif code == 2:
        caught += 1
        print(f"  vu   {label}\n       → ne compile plus")
    elif code != 0 and not finished:
        caught += 1
        print(f"  vu   {label}\n       → le banc d'essai plante avant la fin")
    else:
        survived.append((label, f"code={code}, échecs={failures}"))
        print(f"  SURVIT  {label}  ({code=}, {failures=})")

print()
print(f"{caught}/{len(MUTATIONS)} mutations détectées.")
if survived:
    print("\nMUTATIONS SURVIVANTES — le test ne surveille pas ces règles :")
    for label, why in survived:
        print(f"  · {label}  [{why}]")
    sys.exit(1)
