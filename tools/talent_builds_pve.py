#!/usr/bin/env python3
"""Stufe-60-PvE-Builds (Dungeon/Raid) -> tools/talent-builds-pve.json (Eingabe für build_talent_builds.py).

Eingaben:
  * Wowhead-Forever-Talentdaten (nether.wowhead.com/forever/data/talents-classic, als JSON gespeichert:
    die Seitendaten-Blöcke, Schlüssel "wow.talentCalcClassic.classicplus.data")
  * Recherche-Dateien: { "WARRIOR": [ { "spec", "role", "kind": "dungeon"|"raid", "points",
    "talents": { "WarriorArms": { "Talentname": Ränge } }, "sources": [ {url, date, matches} ], "note" } ] }

Die Recherche liefert nur den Endstand (51 Punkte). Die Lernreihenfolge wird abgeleitet: Hauptbaum zuerst,
je Baum Reihe für Reihe (Voraussetzungen vor dem Talent) – damit ist jede Zwischenstufe gültig.
Aufruf: python3 tools/talent_builds_pve.py <talents.json> <recherche.json> [...]
"""
import collections
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGET = ROOT / "tools" / "talent-builds-pve.json"

CLASS_PREFIX = {"Warrior": "WARRIOR", "Paladin": "PALADIN", "Hunter": "HUNTER", "Rogue": "ROGUE", "Priest": "PRIEST",
                "Shaman": "SHAMAN", "Mage": "MAGE", "Warlock": "WARLOCK", "Druid": "DRUID"}
# German tree name per English spec name (as in the talent window)
SPEC_DE = {
    "Arms": "Waffen", "Fury": "Furor", "Protection": "Schutz", "Holy": "Heilig", "Retribution": "Vergeltung",
    "Discipline": "Disziplin", "Shadow": "Schatten", "Elemental": "Elementar", "Enhancement": "Verstärkung",
    "Restoration": "Wiederherstellung", "Arcane": "Arkan", "Fire": "Feuer", "Frost": "Frost",
    "Assassination": "Meucheln", "Combat": "Kampf", "Subtlety": "Täuschung", "Beast Mastery": "Tierherrschaft",
    "Marksmanship": "Treffsicherheit", "Survival": "Überleben", "Affliction": "Gebrechen", "Demonology": "Dämonologie",
    "Destruction": "Zerstörung", "Balance": "Gleichgewicht", "Feral Combat": "Wilder Kampf", "Feral": "Wilder Kampf",
    "Feral DPS": "Wilder Kampf", "Feral Tank": "Wilder Kampf",
}
KIND_DE = {"dungeon": "Dungeon", "raid": "Schlachtzug", "leveling": "Leveln"}
# leveling builds with a real learning order (Maxroll planner) win over derived ones of the same name
EXISTING = [ROOT / "tools" / "talent-builds.json", ROOT / "tools" / "talent-builds-custom.json"]


def load_talents(path):
    data = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    data = data.get("wow.talentCalcClassic.classicplus.data", data)
    by_name, by_id = {}, {}
    for tree_id, talents in data["talents"].items():
        desc = data["trees"][tree_id]["description"]
        for t in talents.values():
            t["tree"] = desc
            by_name[(desc, t["name"])] = t
            by_id[t["id"]] = t
    return by_name, by_id


def build_name(spec, role, kind):
    tree = SPEC_DE.get(spec, spec)
    if tree == "Wilder Kampf":
        tree += " – Bär" if role == "tank" else " – Katze"
    return f"{tree} ({KIND_DE[kind]})"


def derive_order(talents, by_name, by_id):
    """Endstand -> Lernreihenfolge; wirft ValueError bei ungültigem Build."""
    picks, per_tree = [], collections.Counter()
    for tree, ranks in talents.items():
        for name, count in ranks.items():
            t = by_name.get((tree, name))
            if not t:
                raise ValueError(f"Talent nicht gefunden: {tree} / {name}")
            if not 0 < count <= len(t["ranks"]):
                raise ValueError(f"{name}: {count} Ränge (max {len(t['ranks'])})")
            picks.append((t, count))
            per_tree[tree] += count
    if sum(per_tree.values()) != 51:
        raise ValueError(f"{sum(per_tree.values())} statt 51 Punkte")
    have = {t["id"]: c for t, c in picks}
    order, spent, done = [], collections.Counter(), collections.Counter()
    for tree, _ in per_tree.most_common():
        todo = sorted([p for p in picks if p[0]["tree"] == tree], key=lambda p: (p[0]["row"], p[0]["col"]))
        while todo:
            for i, (t, count) in enumerate(todo):
                reqs = t.get("requires") or []
                if all(done[r["id"]] >= r["qty"] for r in reqs):
                    break
            else:
                raise ValueError(f"Voraussetzung fehlt: {todo[0][0]['name']}")
            todo.pop(i)
            for r in t.get("requires") or []:
                if have.get(r["id"], 0) < r["qty"]:
                    raise ValueError(f"{t['name']} braucht {by_id[r['id']]['name']} {r['qty']}")
            if spent[tree] < 5 * t["row"]:
                raise ValueError(f"{t['name']} (Reihe {t['row'] + 1}): nur {spent[tree]} Punkte im Baum")
            for _ in range(count):
                order.append([t["ranks"][0], t["name"]])
            spent[tree] += count
            done[t["id"]] += count
    return order


def main():
    by_name, by_id = load_talents(sys.argv[1])
    out = {"_meta": {
        "content": "Stufe-60-PvE-Builds (Dungeon/Raid), Konsens aus mehreren Guides; Lernreihenfolge abgeleitet.",
        "by": "tools/talent_builds_pve.py",
    }}
    problems = 0
    taken = set()
    for path in EXISTING:
        for cls, builds in json.loads(path.read_text(encoding="utf-8")).items():
            if not cls.startswith("_"):
                taken.update((cls, b["name"]) for b in builds)
    for path in sys.argv[2:]:
        research = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
        for cls, builds in research.items():
            if cls.startswith("_"):
                continue
            for b in builds:
                if b.get("kind") not in KIND_DE or not b.get("talents"):
                    continue
                name = build_name(b["spec"], b.get("role"), b["kind"])
                if (cls, name) in taken:
                    print(f"vorhanden (Maxroll-Reihenfolge), übersprungen: {cls} {name}")
                    continue
                try:
                    order = derive_order(b["talents"], by_name, by_id)
                except ValueError as e:
                    print(f"FEHLER {cls} {name}: {e}")
                    problems += 1
                    continue
                sources = [s for s in b.get("sources", []) if s.get("matches", True)] or b.get("sources", [])
                if any(x["name"] == name for x in out.get(cls, [])):
                    print(f"doppelt, übersprungen: {cls} {name}")
                    continue
                out.setdefault(cls, []).append({
                    "name": name, "kind": b["kind"], "role": b.get("role"),
                    "source": sources[0]["url"] if sources else "",
                    "sources": [s["url"] for s in sources],
                    "date": max((s.get("date") or "" for s in sources), default=""),
                    "derivedOrder": True, "firstLevel": 10, "points": b.get("points"),
                    "note": b.get("note", ""), "order": order,
                })
                print(f"ok     {cls} {name}")
    TARGET.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{TARGET.relative_to(ROOT)}: {sum(len(v) for k, v in out.items() if not k.startswith('_'))} Builds, {problems} Fehler")


if __name__ == "__main__":
    main()
