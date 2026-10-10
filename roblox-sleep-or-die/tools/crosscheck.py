#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Contrôle statique : les appels entre modules existent-ils vraiment ?

Le compilateur Luau vérifie la syntaxe, pas qu'un `ShelterService.claim(...)`
corresponde à une fonction réellement définie. Ce script relit tout le dossier
src/ et vérifie quatre choses :

  1. chaque `require(...)` pointe vers un fichier qui existe ;
  2. chaque `Module.fonction(` appelée est définie dans ce module ;
  3. chaque `Net.get("X")` figure dans la liste Net.Events ;
  4. aucun module serveur n'est oublié par le bootstrap.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

files = sorted(SRC.glob("*/*.luau"))
sources = {f: f.read_text(encoding="utf-8") for f in files}

# Nom de module -> fichier
by_name = {}
for f in files:
    name = f.stem.replace(".server", "").replace(".client", "")
    by_name[name] = f

errors = []
checked = 0

# ── 1. les require ────────────────────────────────────────────────────────
REQUIRE = re.compile(r'local\s+(\w+)\s*=\s*require\(([^)]+)\)')
aliases = {}  # fichier -> {alias local: nom de module}
for f, text in sources.items():
    aliases[f] = {}
    for alias, target in REQUIRE.findall(text):
        last = target.strip().split(".")[-1].strip()
        aliases[f][alias] = last
        checked += 1
        if last not in by_name and last not in ("Shared",):
            errors.append(f"{f.name} : require d'un module introuvable → {target.strip()}")

# ── 2. les fonctions appelées existent ───────────────────────────────────
DEF = re.compile(r'function\s+(\w+)\.(\w+)\s*\(')
defined = {}
for f, text in sources.items():
    name = f.stem.replace(".server", "").replace(".client", "")
    found = set()
    for owner, fn in DEF.findall(text):
        found.add(fn)
    # champs de table exportés : `Config.List = `, `Config.ById = `
    for field in re.findall(r'^(\w+)\.(\w+)\s*=', text, re.M):
        found.add(field[1])
    defined[name] = found

CALL = re.compile(r'\b(\w+)\.(\w+)\s*\(')
for f, text in sources.items():
    for alias, fn in CALL.findall(text):
        module = aliases[f].get(alias)
        if not module or module not in defined:
            continue
        checked += 1
        if fn not in defined[module] and fn not in ("new", "get"):
            errors.append(f"{f.name} : {alias}.{fn}() n'existe pas dans {module}.luau")

# ── 3. les remotes ───────────────────────────────────────────────────────
net_text = (SRC / "shared" / "Net.luau").read_text(encoding="utf-8")
block = net_text.split("Net.Events = {", 1)[1].split("}", 1)[0]
declared = set(re.findall(r'"([A-Za-z]+)"', block))
for f, text in sources.items():
    for remote in re.findall(r'Net\.get\("([^"]+)"\)', text):
        checked += 1
        if remote not in declared:
            errors.append(f"{f.name} : remote « {remote} » non déclaré dans Net.Events")

# ── 4. tout service serveur est requis par le bootstrap ──────────────────
boot = (SRC / "server" / "init.server.luau").read_text(encoding="utf-8")
for f in files:
    if f.parent.name == "server" and not f.name.startswith("init"):
        checked += 1
        if f.stem not in boot:
            errors.append(f"init.server.luau n'utilise jamais {f.name}")

print(f"{len(files)} fichiers, {checked} liens vérifiés.")
if errors:
    for e in errors:
        print("  ERREUR " + e)
    sys.exit(1)
print("Aucun appel orphelin, aucun remote fantôme, aucun service oublié.")
