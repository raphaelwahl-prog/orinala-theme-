#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Les sept zones tiennent-elles debout ?

On ne peut pas lancer Roblox ici, mais on peut vérifier tout ce qui est
déclaratif : chaque zone a-t-elle une carte, des refuges, une porte d'entrée et
une porte de sortie, un point d'apparition, des rondes, un monstre ; le graphe
des portes relie-t-il bien les sept zones dans l'ordre ; et les dalles de
1600 studs sont-elles assez grandes pour ce qu'on y construit.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
layouts = (ROOT / "src/server/ZoneLayouts.luau").read_text(encoding="utf-8")
zones_src = (ROOT / "src/shared/ZoneConfig.luau").read_text(encoding="utf-8")
monsters_src = (ROOT / "src/shared/MonsterConfig.luau").read_text(encoding="utf-8")
builder = (ROOT / "src/server/ZoneBuilder.luau").read_text(encoding="utf-8")

zone_ids = re.findall(r'Id = "(\w+)", Order = (\d+)', zones_src)
zone_order = {z: int(o) for z, o in zone_ids}
zone_monster = dict(re.findall(r'Id = "(\w+)".*?Monster = "(\w+)"', zones_src, re.S))
monster_ids = set(re.findall(r'\{ Id = "(\w+)", Name =', monsters_src))
spacing = int(re.search(r"ZoneBuilder\.SPACING = (\d+)", builder).group(1))

# Découpe le fichier en une section par fonction de zone.
sections = {}
parts = re.split(r"\nfunction Layouts\.(\w+)\(", layouts)
for i in range(1, len(parts), 2):
    sections[parts[i]] = parts[i + 1]

fails, checks = [], 0
def ok(cond, label):
    global checks
    checks += 1
    print(("  OK    " if cond else "  ÉCHEC ") + label)
    if not cond:
        fails.append(label)

print("— chaque zone a sa carte —")
for zid in zone_order:
    ok(zid in sections, f"{zid} : fonction de construction présente")

print()
print("— contenu de chaque carte —")
gates = {}
for zid, body in sections.items():
    shelters = len(re.findall(r'B\.shelter\(', body))
    # une boucle `for ... B.shelter` compte pour plusieurs
    loops = len(re.findall(r'for .*?\n(?:[^\n]*\n)*?[^\n]*B\.shelter', body))
    ok(shelters >= 1, f"{zid} : {shelters} appel(s) à B.shelter")
    ok(len(re.findall(r'B\.spawnPoint\(', body)) >= 1, f"{zid} : point d'apparition")
    ok("Patrol = patrol" in body or "Patrol =" in body, f"{zid} : points de ronde renvoyés")
    ok("Spawns =" in body, f"{zid} : points d'apparition des monstres")
    ok("Anchor =" in body, f"{zid} : point d'arrivée défini")
    gates[zid] = re.findall(r'B\.gate\("(\w+)"', body)

print()
print("— le graphe des portes —")
chain = sorted(zone_order, key=lambda z: zone_order[z])
for i, zid in enumerate(chain):
    out = gates.get(zid, [])
    if i + 1 < len(chain):
        nxt = chain[i + 1]
        ok(nxt in out, f"{zid} → {nxt}")
    if i > 0:
        prev = chain[i - 1]
        ok(prev in out, f"{zid} → retour vers {prev}")

print()
print("— monstres —")
for zid, mid in zone_monster.items():
    ok(mid in monster_ids, f"{zid} : le monstre « {mid} » existe dans MonsterConfig")

print()
print("— emprise au sol : rien ne déborde sur la dalle voisine —")
# Plus grande coordonnée littérale employée dans chaque section (approximation
# volontairement pessimiste : on prend le maximum de tous les nombres).
for zid, body in sections.items():
    numbers = [abs(float(n)) for n in re.findall(r'-?\d+\.?\d*', body)]
    extent = max(numbers) if numbers else 0
    ok(extent < spacing / 2,
       f"{zid} : plus grande coordonnée {extent:.0f} < {spacing // 2} (demi-dalle)")

print()
print(f"{checks - len(fails)}/{checks} vérifications passées.")
sys.exit(1 if fails else 0)
