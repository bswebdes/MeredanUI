#!/usr/bin/env python3
"""Boss-Liste je Instanz für den Questtracker (Forever hat keinen Abenteuerführer).
Quelle: wago.tools DungeonEncounter, product=wowf, enUS + deDE (tools/encounterdata/).
Nur normale Schwierigkeit (DifficultyID 0/1), Reihenfolge nach OrderIndex.
Ausgabe: Quests/DungeonBosses.lua – ns.DUNGEON_BOSSES[instanceMapID] = { { encounterID, enUS, deDE }, … }"""
import csv, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
data = root / "tools" / "encounterdata"

def load(loc):
    with open(data / f"enc_{loc}.csv", encoding="utf-8") as f:
        return {int(r["ID"]): r for r in csv.DictReader(f)}

en, de = load("enUS"), load("deDE")
maps = {}
for eid, r in en.items():
    if r["DifficultyID"] not in ("0", "1"):
        continue
    maps.setdefault(int(r["MapID"]), []).append((int(r["OrderIndex"]), eid, r["Name_lang"], de.get(eid, r)["Name_lang"]))

def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

out = ["-- AUTOMATISCH ERZEUGT von tools/build_dungeon_bosses.py – nicht von Hand ändern.",
       "-- Bosse je Instanz (Karten-ID) für den Questtracker; Quelle: wago.tools DungeonEncounter (wowf).",
       "local _, ns = ...", "", "ns.DUNGEON_BOSSES = {"]
for mid in sorted(maps):
    seen, rows = set(), []
    for order, eid, n_en, n_de in sorted(maps[mid]):
        if n_en in seen:
            continue
        seen.add(n_en)
        rows.append("{ %d, %s, %s }" % (eid, lua(n_en), lua(n_de)))
    out.append("    [%d] = { %s }," % (mid, ", ".join(rows)))
out.append("}")
(root / "Quests" / "DungeonBosses.lua").write_text("\n".join(out) + "\n", encoding="utf-8")
print("Instanzen:", len(maps))
