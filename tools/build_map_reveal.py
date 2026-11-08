#!/usr/bin/env python3
"""Erzeugt Map/MapRevealData.lua – alle Kartenflächen (WorldMapOverlay) je Zone für „Ganze Karte aufdecken“.

Quellen (tools/mapdata/, wago.tools, product=wowf = WoW Forever 1.60.1):
  UiMapXMapArt   uiMap > UiMapArt
  WorldMapOverlay  Fläche: UiMapArtID, TextureWidth/Height, OffsetX/Y
  WorldMapOverlayTile  Kacheln der Fläche (RowIndex, ColIndex, LayerIndex, FileDataID)

Ausgabe je uiMapID: { Breite, Höhe, OffsetX, OffsetY, "Kachel-IDs zeilenweise, kommagetrennt" }.
mUI zeichnet daraus die Flächen, die C_MapExplorationInfo.GetExploredMapTextures (noch) nicht liefert.

Aufruf: python3 tools/build_map_reveal.py
"""
import csv
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "tools" / "mapdata"
TARGET = ROOT / "Map" / "MapRevealData.lua"


def rows(name):
    with open(DATA / f"{name}_wowf.csv", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main():
    art_maps = defaultdict(set)
    for r in rows("UiMapXMapArt"):
        art_maps[int(r["UiMapArtID"])].add(int(r["UiMapID"]))
    tiles = defaultdict(list)
    for r in rows("WorldMapOverlayTile"):
        if int(r["LayerIndex"]) == 0:
            tiles[int(r["WorldMapOverlayID"])].append((int(r["RowIndex"]), int(r["ColIndex"]), int(r["FileDataID"])))
    maps = defaultdict(list)
    for r in rows("WorldMapOverlay"):
        overlay = int(r["ID"])
        t = sorted(tiles.get(overlay, []))
        if not t or any(f == 0 for _, _, f in t):
            continue
        entry = (int(r["TextureWidth"]), int(r["TextureHeight"]), int(r["OffsetX"]), int(r["OffsetY"]),
                 ",".join(str(f) for _, _, f in t))
        for ui_map in art_maps.get(int(r["UiMapArtID"]), ()):
            maps[ui_map].append(entry)
    out = [
        "-- Automatisch erzeugt von tools/build_map_reveal.py – nicht von Hand ändern.",
        "-- Kartenflächen je Zone (uiMapID): { Breite, Höhe, OffsetX, OffsetY, \"Kachel-FileDataIDs\" }",
        "local _, ns = ...",
        "ns.MAP_REVEAL_DATA = {",
    ]
    for ui_map in sorted(maps):
        out.append(f"    [{ui_map}] = {{")
        for w, h, x, y, ids in sorted(maps[ui_map], key=lambda e: (e[3], e[2])):
            out.append(f'        {{ {w}, {h}, {x}, {y}, "{ids}" }},')
        out.append("    },")
    out.append("}")
    TARGET.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"{TARGET.relative_to(ROOT)}: {len(maps)} Karten, {sum(len(v) for v in maps.values())} Flächen")


if __name__ == "__main__":
    main()
