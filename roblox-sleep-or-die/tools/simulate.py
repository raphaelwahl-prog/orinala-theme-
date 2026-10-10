#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Combien de temps pour aller au bout ?

Le cahier des charges donne des gains par seconde et des seuils de déblocage,
mais pas le temps que ça représente. Ce script le calcule à partir des valeurs
réellement écrites dans ZoneConfig.luau — pas de chiffres recopiés à la main.

Modèle d'une session :
  · on gagne au taux plein jusqu'au plafond souple ;
  · au-delà, le taux est divisé par 4 (GameConfig.SoftCapDivisor) ;
  · la session s'arrête à MaxSessionSeconds ;
  · il faut ~25 s pour rejoindre le coffre, déposer et se recoucher.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
zone_src = (ROOT / "src/shared/ZoneConfig.luau").read_text(encoding="utf-8")
cfg_src = (ROOT / "src/shared/GameConfig.luau").read_text(encoding="utf-8")

divisor = float(re.search(r"SoftCapDivisor\s*=\s*([\d.]+)", cfg_src).group(1))
OVERHEAD = 25.0

zones = []
for block in re.findall(r"\{\s*Id = \"(\w+)\".*?Blurb", zone_src, re.S):
    pass
for m in re.finditer(
    r'Id = "(\w+)", Order = (\d+), Name = "([^"]+)",\s*'
    r'Rate = ([\d.]+), SoftCapPerSession = ([\d.]+), MaxSessionSeconds = ([\d.]+),.*?'
    r'Unlock = \{ Banked = ([\d.]+)', zone_src, re.S):
    zones.append({
        "id": m.group(1), "order": int(m.group(2)), "name": m.group(3),
        "rate": float(m.group(4)), "cap": float(m.group(5)),
        "max": float(m.group(6)), "banked": float(m.group(7)),
    })

if len(zones) != 7:
    print("ERREUR : %d zones lues au lieu de 7" % len(zones))
    sys.exit(1)

def session_yield(z):
    """Gain d'une session menée à son terme."""
    full_time = min(z["max"], z["cap"] / z["rate"])
    earned = full_time * z["rate"]
    rest = z["max"] - full_time
    if rest > 0:
        earned += rest * z["rate"] / divisor
    return earned

def human(seconds):
    h = int(seconds // 3600)
    m = int(seconds % 3600 // 60)
    return (f"{h} h {m:02d}" if h else f"{m} min")

print("Par session (durée maximale incluse) :")
print()
print(f"  {'zone':<26} {'taux':>12} {'gain/session':>16} {'durée':>8}")
for z in zones:
    print(f"  {z['order']}. {z['name']:<23} {z['rate']:>10,.0f} $/s "
          f"{session_yield(z):>14,.0f} $ {human(z['max'] + OVERHEAD):>8}")

print()
print("Temps pour débloquer la zone suivante (en jouant la zone précédente) :")
print()
total = 0.0
problems = []
for i in range(1, len(zones)):
    previous, target = zones[i - 1], zones[i]
    need = target["banked"] - previous["banked"]
    per = session_yield(previous)
    sessions = need / per
    seconds = sessions * (previous["max"] + OVERHEAD)
    total += seconds
    print(f"  {previous['name']:<26} → {target['name']:<26} "
          f"{sessions:>7.1f} sessions  {human(seconds):>10}")
    if seconds < 300:
        problems.append(f"{previous['name']} → {target['name']} : {human(seconds)}, "
                        "c'est trop vite pour qu'un palier ait du sens")
    if seconds > 40 * 3600:
        problems.append(f"{previous['name']} → {target['name']} : {human(seconds)}, "
                        "c'est un mur")

print()
print(f"Total pour atteindre {zones[-1]['name']} : {human(total)} de jeu effectif.")
print()

# Le vrai risque : la dernière zone rend tout le reste sans objet.
last, before = zones[-1], zones[-2]
ratio = session_yield(last) / session_yield(before)
print(f"Une session au {last['name']} rapporte {ratio:.0f} fois une session à "
      f"{before['name']}.")
if ratio > 12:
    problems.append(f"Le {last['name']} rapporte x{ratio:.0f} : une fois atteint, "
                    "plus rien d'autre ne vaut la peine d'être joué.")

# Plafond des entiers 32 bits : le piège classique sur Roblox.
print()
seconds_to_overflow = 2**31 / last["rate"]
print(f"À {last['rate']:,.0f} $/s, un compteur entier 32 bits saturerait en "
      f"{human(seconds_to_overflow)} — d'où le stockage en nombre à virgule "
      f"flottante (Format.luau).")

print()
if problems:
    print("À REGARDER :")
    for p in problems:
        print("  · " + p)
else:
    print("Aucune marche aberrante dans la progression.")
