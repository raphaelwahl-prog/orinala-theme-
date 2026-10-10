#!/usr/bin/env python3
"""
Génère SleepOrDie.rbxlx : un fichier de place Roblox complet, prêt à ouvrir
dans Roblox Studio. Tu double-cliques, Studio s'ouvre, tu appuies sur Play.
Aucun Rojo, aucun copier-coller de module.

Usage, depuis le dossier roblox-sleep-or-die/ :

    python3 tools/build_place.py

Relance-le après chaque modification du code pour régénérer la place.

Un .rbxlx est du XML. Le source Lua est échappé en XML (pas de CDATA : si un
jour ton code contient la séquence ]]> le CDATA casserait sans prévenir).
"""

from pathlib import Path
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "SleepOrDie.rbxlx"

_ref = 0
def ref() -> str:
    global _ref
    _ref += 1
    return f"RBX{_ref}"


def esc(text: str) -> str:
    """Échappe pour XML. Les caractères de contrôle interdits en XML 1.0 sont
    retirés : ils ne devraient pas exister dans du Lua, mais un copier-coller
    malheureux suffirait à rendre le fichier illisible par Studio."""
    cleaned = "".join(
        c for c in text
        if c in "\t\n\r" or ord(c) >= 0x20
    )
    return escape(cleaned, {'"': "&quot;"})


def script_item(cls: str, name: str, source: str, children: str = "") -> str:
    return (
        f'<Item class="{cls}" referent="{ref()}">'
        f"<Properties>"
        f'<string name="Name">{esc(name)}</string>'
        f'<ProtectedString name="Source">{esc(source)}</ProtectedString>'
        f"</Properties>"
        f"{children}"
        f"</Item>"
    )


def folder_item(name: str, children: str = "") -> str:
    return (
        f'<Item class="Folder" referent="{ref()}">'
        f'<Properties><string name="Name">{esc(name)}</string></Properties>'
        f"{children}"
        f"</Item>"
    )


def service_item(cls: str, name: str, children: str = "", props: str = "") -> str:
    return (
        f'<Item class="{cls}" referent="{ref()}">'
        f'<Properties><string name="Name">{esc(name)}</string>{props}</Properties>'
        f"{children}"
        f"</Item>"
    )


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def modules_of(folder: Path, skip: set[str]) -> str:
    """Tous les .luau d'un dossier en ModuleScript, triés pour que le fichier
    généré soit stable d'une exécution à l'autre (utile en diff git)."""
    out = []
    for path in sorted(folder.glob("*.luau")):
        if path.name in skip:
            continue
        out.append(script_item("ModuleScript", path.stem, read(path)))
    return "".join(out)


def build() -> str:
    # ── ReplicatedStorage/Shared : les catalogues et les remotes
    shared = folder_item("Shared", modules_of(SRC / "shared", set()))
    replicated = service_item("ReplicatedStorage", "ReplicatedStorage", shared)

    # ── ServerScriptService/Server : le Script, avec les services en enfants
    server_children = modules_of(SRC / "server", {"init.server.luau"})
    server = script_item("Script", "Server", read(SRC / "server" / "init.server.luau"), server_children)
    server_service = service_item("ServerScriptService", "ServerScriptService", server)

    # ── StarterPlayer/StarterPlayerScripts/Client : le LocalScript et son UI
    client_children = modules_of(SRC / "client", {"init.client.luau"})
    client = script_item("LocalScript", "Client", read(SRC / "client" / "init.client.luau"), client_children)
    starter_scripts = service_item("StarterPlayerScripts", "StarterPlayerScripts", client)
    starter_player = service_item("StarterPlayer", "StarterPlayer", starter_scripts)

    # ── ServerStorage/Monsters : vide, mais prêt. Dépose ici tes modèles de
    #    monstres (un Model par identifiant de MonsterConfig) et ils
    #    remplaceront ceux générés en code, sans toucher au reste.
    monsters = folder_item("Monsters")
    props = folder_item("Props")
    server_storage = service_item("ServerStorage", "ServerStorage", monsters + props)

    # ── Workspace : volontairement vide. CityBuilder construit la rue au
    #    démarrage (immeubles, ruelles, refuges, PNJ, coffre, boutique,
    #    entrée des égouts, points de ronde et SpawnLocation).
    workspace = service_item(
        "Workspace", "Workspace", "",
        '<bool name="FilteringEnabled">true</bool>'
    )

    # ── Lighting : valeurs de départ. RoundService les écrase à chaque phase.
    lighting = service_item(
        "Lighting", "Lighting", "",
        # Nuit permanente : c'est le cadre du jeu (CDC §1).
        '<float name="Brightness">1</float>'
        '<float name="ClockTime">0.4</float>'
        '<token name="Technology">2</token>'
        '<float name="FogEnd">320</float>'
        '<float name="FogStart">40</float>'
        '<Color3 name="Ambient"><R>0.06</R><G>0.06</G><B>0.09</B></Color3>'
        '<Color3 name="OutdoorAmbient"><R>0.08</R><G>0.08</G><B>0.12</B></Color3>'
        '<Color3 name="FogColor"><R>0.03</R><G>0.03</G><B>0.05</B></Color3>'
    )

    parts = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        "<External>null</External>",
        "<External>nil</External>",
        workspace,
        lighting,
        replicated,
        server_service,
        server_storage,
        starter_player,
        "</roblox>",
    ]
    return "".join(parts)


def main() -> None:
    xml = build()

    # Contrôle : le fichier doit être du XML valide, et contenir tous les
    # modules présents sur le disque. Une place incomplète s'ouvre dans Studio
    # sans erreur et plante seulement au Play — autant le voir ici.
    root = ET.fromstring(xml)
    sources = root.findall(".//ProtectedString[@name='Source']")
    expected = len(list(SRC.glob("*/*.luau")))
    names = sorted(
        e.find("Properties/string[@name='Name']").text
        for e in root.iter("Item")
        if e.get("class") in {"Script", "LocalScript", "ModuleScript"}
    )

    OUT.write_text(xml, encoding="utf-8")

    print(f"écrit  : {OUT.relative_to(ROOT)}  ({OUT.stat().st_size // 1024} Ko)")
    print(f"XML    : valide")
    print(f"scripts: {len(sources)} / {expected} fichiers .luau du dossier src/")
    if len(sources) != expected:
        raise SystemExit("ERREUR : des modules manquent dans la place générée.")
    print("modules:", ", ".join(names))


if __name__ == "__main__":
    main()
