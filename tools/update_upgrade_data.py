#!/usr/bin/env python3
"""Erzeugt Upgrades/UpgradeData.lua (Stat-Gewichte für die Upgrade-Bewertung) aus Bloodmallet.

  python3 tools/update_upgrade_data.py [--cache DIR]

Quellen:
  - Bloodmallet (SimulationCraft, aktuelle Saison): Sekundärwert-Verteilungen und Schmuck-Sims
    für alle DPS- und Tank-Specs. https://bloodmallet.com/faq („All data is free to use“)
  - Pawn/Ask Mr. Robot (github.com/VgerMods/Pawn, AskMrRobot.lua): nur für Heiler, die
    Bloodmallet nicht simuliert – und nur das Verhältnis der Sekundärwerte untereinander
    (die Zahlen sind von vor dem Midnight-Stat-Squish).

Sekundärwerte: Bloodmallet simuliert alle Aufteilungen von Krit/Tempo/Meisterschaft/
Vielseitigkeit in 10-%-Schritten bei fester Summe. Daraus wird ein Polynom 3. Grades in den
Anteilen (Krit, Tempo, Meisterschaft; Vielseitigkeit = Rest) gefittet – DPS als Bruchteil der
Basis-DPS. Das Addon bildet daraus den Gradienten an deiner aktuellen Aufteilung (also auch
abnehmenden Nutzen bei zu viel von einem Wert).

Schmuck: Zugewinn je Itemlevel als Bruchteil der Basis-DPS (Einzelziel).
"""
import argparse
import itertools
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import date

BASE = "https://bloodmallet.com/chart/get"
FIGHT_STYLE = "castingpatchwerk"
PAWN_URL = "https://raw.githubusercontent.com/VgerMods/Pawn/main/AskMrRobot.lua"
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Upgrades", "UpgradeData.lua")

CLASS_IDS = {
    "warrior": 1, "paladin": 2, "hunter": 3, "rogue": 4, "priest": 5, "death_knight": 6, "shaman": 7,
    "mage": 8, "warlock": 9, "monk": 10, "druid": 11, "demon_hunter": 12, "evoker": 13,
}
SPECS = {
    "death_knight": ["blood", "frost", "unholy"],
    "demon_hunter": ["havoc", "vengeance", "devourer"],
    "druid": ["balance", "feral", "guardian", "restoration"],
    "evoker": ["devastation", "augmentation", "preservation"],
    "hunter": ["beast_mastery", "marksmanship", "survival"],
    "mage": ["arcane", "fire", "frost"],
    "monk": ["brewmaster", "mistweaver", "windwalker"],
    "paladin": ["holy", "protection", "retribution"],
    "priest": ["discipline", "holy", "shadow"],
    "rogue": ["assassination", "outlaw", "subtlety"],
    "shaman": ["elemental", "enhancement", "restoration"],
    "warlock": ["affliction", "demonology", "destruction"],
    "warrior": ["arms", "fury", "protection"],
}
DEGREE = 3
# Reihenfolge der Polynom-Terme: Produkte der Anteile 1=Krit, 2=Tempo, 3=Meisterschaft
TERMS = [combo for d in range(DEGREE + 1) for combo in itertools.combinations_with_replacement((1, 2, 3), d)]
PAWN_STATS = {"CritRating": "crit", "HasteRating": "haste", "MasteryRating": "mastery", "Versatility": "vers"}


def fetch(url, cache, name):
    path = cache and os.path.join(cache, name)
    if path and os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return f.read()
    request = urllib.request.Request(url, headers={"User-Agent": "MeredanUI-upgrade-data/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            text = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        print(f"  {name}: HTTP {error.code}", file=sys.stderr)
        return None
    time.sleep(0.5)  # Bloodmallet schonen
    if path:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    return text


def fetch_json(url, cache, name):
    text = fetch(url, cache, name)
    if not text:
        return None
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    return None if data.get("status") == "error" else data  # z. B. Heiler: „No standard chart“


def solve(a, b):
    n = len(a)
    m = [row[:] + [b[i]] for i, row in enumerate(a)]
    for c in range(n):
        p = max(range(c, n), key=lambda r: abs(m[r][c]))
        m[c], m[p] = m[p], m[c]
        for r in range(n):
            if r != c:
                f = m[r][c] / m[c][c]
                for k in range(c, n + 1):
                    m[r][k] -= f * m[c][k]
    return [m[i][n] / m[i][i] for i in range(n)]


def term_values(x):
    out = []
    for combo in TERMS:
        v = 1.0
        for i in combo:
            v *= x[i - 1]
        out.append(v)
    return out


def fit_secondaries(chart):
    tier = next(iter(chart["data"]))
    base = chart["profile"]["metadata"]["base_dps"]
    rows, values = [], []
    for key, dps in chart["data"][tier].items():
        crit, haste, mastery, _vers = (int(p) / 100 for p in key.split("_"))
        rows.append(term_values((crit, haste, mastery)))
        values.append(dps / base)
    n = len(TERMS)
    a = [[sum(r[i] * r[j] for r in rows) for j in range(n)] for i in range(n)]
    b = [sum(r[i] * v for r, v in zip(rows, values)) for i in range(n)]
    coeffs = solve(a, b)
    error = max(abs(sum(c * t for c, t in zip(coeffs, r)) - v) for r, v in zip(rows, values))
    return tier, coeffs, error, chart["secondary_sum"]


def trinket_gains(chart):
    base = chart["profile"]["metadata"]["base_dps"]
    items = {}
    for name, by_ilvl in chart["data"].items():
        item_id = chart["item_ids"].get(name)
        if not item_id or not isinstance(by_ilvl, dict):
            continue
        gains = {int(ilvl): dps / base - 1 for ilvl, dps in by_ilvl.items()}
        # Varianten („[Crit]“ usw.) desselben Items: die beste zählt (die wählt man dann)
        known = items.get(item_id)
        if not known or max(gains.values()) > max(known.values()):
            items[item_id] = gains
    return items


def pawn_fallback(cache, wanted):
    text = fetch(PAWN_URL, cache, "pawn_AskMrRobot.lua")
    out = {}
    if not text:
        return out
    pattern = re.compile(r"PawnAddPluginScaleFromTemplate\(\s*\w+,\s*(\d+),[^\n]*\n\s*(\d+),[^\n]*\n\s*\{([^}]*)\}")
    for class_id, spec_index, body in pattern.findall(text):
        key = (int(class_id), int(spec_index))
        if key not in wanted:
            continue
        stats = dict(re.findall(r"(\w+)=([\d.]+)", body))
        weights = {PAWN_STATS[k]: float(v) for k, v in stats.items() if k in PAWN_STATS}
        if len(weights) == 4:
            mean = sum(weights.values()) / 4
            out[wanted[key]] = {k: v / mean for k, v in weights.items()}
    return out


def lua_number(v):
    return f"{v:.6g}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", help="Ordner für heruntergeladene Dateien (zum Wiederholen ohne Netz)")
    args = parser.parse_args()
    if args.cache:
        os.makedirs(args.cache, exist_ok=True)

    specs, missing, tiers = {}, {}, set()
    for class_slug, spec_slugs in SPECS.items():
        for index, spec_slug in enumerate(spec_slugs, 1):
            name = f"{class_slug}_{spec_slug}"
            chart = fetch_json(f"{BASE}/secondary_distributions/{FIGHT_STYLE}/{class_slug}/{spec_slug}",
                               args.cache, f"sec_{name}.json")
            if not chart:
                missing[(CLASS_IDS[class_slug], index)] = name
                continue
            tier, coeffs, error, total = fit_secondaries(chart)
            tiers.add(tier)
            trinkets = fetch_json(f"{BASE}/trinkets/{FIGHT_STYLE}/{class_slug}/{spec_slug}",
                                  args.cache, f"trk_{name}.json")
            specs[chart["spec_id"]] = {
                "name": name,
                "coeffs": coeffs,
                "total": total,
                "trinkets": trinket_gains(trinkets) if trinkets else {},
            }
            print(f"  {name}: Fit-Fehler max {error * 100:.2f} %, {len(specs[chart['spec_id']]['trinkets'])} Schmuckstücke")

    # Specs ohne Bloodmallet-Daten (Heiler u. a.): Verhältnis aus Pawn
    fallback = pawn_fallback(args.cache, missing)
    for name in missing.values():
        print(f"  {name}: {'Pawn-Verhältnis' if name in fallback else 'FEHLT'}")

    lines = [
        "-- Automatisch erzeugt von tools/update_upgrade_data.py – nicht von Hand ändern.",
        f"-- Stand {date.today().isoformat()}, Saison {', '.join(sorted(tiers))}. Quellen: bloodmallet.com (SimulationCraft),",
        "-- Specs ohne Bloodmallet-Daten (Heiler u. a.): Verhältnis der Sekundärwerte aus Pawn/Ask Mr. Robot.",
        "local _, ns = ...",
        "-- Retail-only sims: skip on Forever so ~300 KB of tables are never built (load-time memory spike)",
        "if ns.IS_FOREVER then return end",
        "",
        "ns.UPGRADE_DATA = {",
        f'    updated = "{date.today().isoformat()}",',
        "    -- Polynom-Terme: Produkte der Anteile 1 = Krit, 2 = Tempo, 3 = Meisterschaft (Rest = Vielseitigkeit)",
        "    terms = { " + ", ".join("{ " + ", ".join(map(str, t)) + " }" if t else "{}" for t in TERMS) + " },",
        "    -- [specID] = { total = Summe der Sekundärwertung im Sim, fit = Koeffizienten (DPS / Basis-DPS),",
        "    --             trinkets = { [itemID] = { [ilvl] = Zugewinn } } }",
        "    specs = {",
    ]
    for spec_id in sorted(specs):
        spec = specs[spec_id]
        lines.append(f"        [{spec_id}] = {{ -- {spec['name']}")
        lines.append(f"            total = {spec['total']},")
        lines.append("            fit = { " + ", ".join(lua_number(c) for c in spec["coeffs"]) + " },")
        lines.append("            trinkets = {")
        for item_id in sorted(spec["trinkets"]):
            gains = spec["trinkets"][item_id]
            lines.append(f"                [{item_id}] = {{ " + ", ".join(
                f"[{ilvl}] = {lua_number(g)}" for ilvl, g in sorted(gains.items())) + " },")
        lines.append("            },")
        lines.append("        },")
    lines.append("    },")
    lines.append("    -- Ohne Bloodmallet: [\"Klassen-ID-Spec-Index\"] = Verhältnis der Sekundärwerte (Mittel = 1)")
    lines.append("    fallback = {")
    for (class_id, index), name in sorted(missing.items()):
        weights = fallback.get(name)
        if weights:
            lines.append(f'        ["{class_id}-{index}"] = {{ crit = {lua_number(weights["crit"])}, haste = {lua_number(weights["haste"])}, '
                         f'mastery = {lua_number(weights["mastery"])}, vers = {lua_number(weights["vers"])} }}, -- {name}')
    lines.append("    },")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"→ {OUT}: {len(specs)} Specs mit Bloodmallet, {len(fallback)} mit Pawn-Verhältnis")


if __name__ == "__main__":
    main()
