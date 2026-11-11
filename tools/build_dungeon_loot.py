#!/usr/bin/env python3
"""Boss and rare loot for the dungeon panel from a classic world database dump (drop tables).

Bosses: matched by name (DungeonEncounter names from Quests/DungeonBosses.lua, enUS) to creatures that
spawn in the instance (same matching as build_dungeon_pins.py); rares: the NPC IDs of the rare pins in
Map/DungeonPinData.lua. Drop chances follow the loot table rules: rows with a fixed chance, group rows
without one share the rest of their group, references multiply in. Shared references (world drops used
by many creatures), items under 1 % and plain white drops (outside a loot group) are left out.
Output: Map/DungeonLoot.lua (ns.DUNGEON_LOOT).
usage: python3 -I tools/build_dungeon_loot.py <world.sql.gz>"""
import gzip, json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
sql = gzip.open(sys.argv[1], 'rt', encoding='utf-8', errors='replace').read()

def tuples(table):
    """Yield value tuples of INSERT INTO `table` VALUES (...),(...);"""
    for m in re.finditer(r"INSERT INTO `%s` VALUES (.*?);\n" % table, sql, re.S):
        body = m.group(1); i = 0; n = len(body)
        while i < n:
            if body[i] != '(':
                i += 1; continue
            i += 1; row = []; cur = ''; q = False
            while i < n:
                c = body[i]
                if q:
                    if c == '\\': cur += body[i + 1]; i += 2; continue
                    if c == "'": q = False
                    else: cur += c
                elif c == "'": q = True
                elif c == ',': row.append(cur); cur = ''
                elif c == ')': row.append(cur); i += 1; break
                else: cur += c
                i += 1
            yield row

def columns(table):
    body = re.search(r"CREATE TABLE `%s` \((.*?)\n\)" % table, sql, re.S).group(1)
    return re.findall(r"^\s+`(\w+)`", body, re.M)

ct = columns('creature_template')
iE, iN, iL = ct.index('Entry'), ct.index('Name'), ct.index('LootId')
loot_id, by_name = {}, {}
for r in tuples('creature_template'):
    loot_id[int(r[iE])] = int(r[iL])
    by_name.setdefault(r[iN].lower(), []).append(int(r[iE]))

it = columns('item_template')
jE, jQ, jC = it.index('entry'), it.index('Quality'), it.index('class')
quality, iclass = {}, {}
for r in tuples('item_template'):
    quality[int(r[jE])], iclass[int(r[jE])] = int(r[jQ]), int(r[jC])
GEAR = (1, 2, 4)  # container, weapon, armour

def table(name):
    rows = {}
    for r in tuples(name):
        rows.setdefault(int(r[0]), []).append((int(r[1]), float(r[2]), int(r[3]), int(r[4])))
    return rows
creature_loot, reference = table('creature_loot_template'), table('reference_loot_template')

# references used by many creatures are world-drop pools, not boss loot
ref_users = {}
for entry, rows in creature_loot.items():
    for item, chance, group, ref in rows:
        if ref < 0: ref_users.setdefault(-ref, set()).add(entry)

def expand(rows, mult, out, top):
    groups = {}
    for row in rows: groups.setdefault(row[2], []).append(row)
    for group, members in groups.items():
        rest = 0
        if group:
            fixed = sum(abs(c) for _, c, _, _ in members if c)
            zero = [m for m in members if not m[1]]
            rest = max(100 - fixed, 0) / len(zero) if zero else 0
        for item, chance, _, ref in members:
            c = abs(chance) if chance else rest
            if chance < 0: continue  # quest drops
            if ref < 0:
                if top and len(ref_users.get(-ref, ())) > 3: continue
                expand(reference.get(-ref, []), mult * c / 100, out, False)
            else:
                prev = out.get(item, (0, False))
                out[item] = (prev[0] + mult * c, prev[1] or bool(group) or not top)

def drops(entry):
    out = {}
    expand(creature_loot.get(loot_id.get(entry) or entry, []), 1.0, out, True)
    # Uncommon and up; white gear too when it sits in a boss loot group (e.g. a boss's bag)
    keep = [(i, c) for i, (c, grouped) in out.items()
            if c >= 1 and (quality.get(i, 0) >= 2 or (grouped and quality.get(i, 0) == 1 and iclass.get(i) in GEAR))]
    return sorted(keep, key=lambda ic: (-ic[1], ic[0]))

# creatures spawned per map, to pick the right one of several same-named entries
spawned = {}
for r in tuples('creature'):
    spawned.setdefault(int(r[2]), set()).add(int(r[1]))

ALIAS = {"Sneed": ["Sneed's Shredder"], "Ras Frostwhisperer": ["Ras Frostwhisper"], "Geilhast": ["Gelihast"],
         "Balnazzar": ["Grand Crusader Dathrohan"]}
bosses = {}
for m in re.finditer(r"\[(\d+)\] = \{ (.*?) \},\n", (ROOT / "Quests" / "DungeonBosses.lua").read_text(encoding="utf-8")):
    bosses[int(m.group(1))] = re.findall(r'\{ (\d+), "((?:[^"\\]|\\.)*)", "(?:[^"\\]|\\.)*" \}', m.group(2))
rares = {}
pins_text = (ROOT / "Map" / "DungeonPinData.lua").read_text(encoding="utf-8")
for m in re.finditer(r"\[(\d+)\] = \{\n(.*?)\n    \},", pins_text, re.S):
    rares[int(m.group(1))] = [int(x) for x in re.findall(r'kind = "rare", id = (\d+)', m.group(2))]

# Forever loot from the guide research (tools/dungeondata/instances/<mapID>.json, live instances): per boss
# the items confirmed for Forever or with a Wowhead Forever drop chance, plus the other classic rows
# between 5 and 100 % (no quest items, none missing on Wowhead Forever). Chance: Wowhead Forever, else guide, else classic. Replaces the classic entry of that
# encounter when anything is left.
def forever_loot():
    result = {}
    for path in sorted((ROOT / "tools" / "dungeondata" / "instances").glob("*.json")):
        if not path.stem.isdigit(): continue
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get("status") != "live": continue
        entries = {}
        sources = [(b.get("encounter_id"), b) for b in data.get("bosses", [])]
        sources += [(r.get("encounter_id") or ("rare:%d" % r["npc_id"] if r.get("npc_id") else None), r) for r in data.get("rares", [])]
        for key, src in sources:
            if not key: continue
            items = []
            for it in src.get("loot", []):
                if it.get("quest_item") or it.get("not_on_wowhead_forever"): continue
                wh = it.get("chance_wowhead_forever")
                repo = it.get("chance_repo") or 0
                # unconfirmed classic rows stay unless small fry (< 5 %) or 100 % event/quest stuff
                if not (it.get("forever_confirmed") or wh or 5 <= repo < 100): continue
                chance = wh or it.get("chance_guide") or it.get("chance_repo")
                if chance and it["item_id"] not in [i for i, _ in items]: items.append((it["item_id"], chance))
            if items: entries[key] = sorted(items, key=lambda i: -i[1])
        if entries: result[int(path.stem)] = entries
    return result
FOREVER = forever_loot()

out, report = {}, []
for inst in sorted(set(bosses) | set(rares)):
    here = spawned.get(inst, set())
    entries = {}
    for enc, name in bosses.get(inst, []):
        found = None
        for want in [name] + ALIAS.get(name, []):
            cands = by_name.get(want.lower().replace('\\"', '"'), [])
            found = next((e for e in cands if e in here), None) or (cands[0] if cands else None)
            if found: break
        if not found:
            report.append(f"{inst}: no creature for '{name}'"); continue
        items = drops(found)
        if items: entries[int(enc)] = items
        else: report.append(f"{inst}: no loot for '{name}' ({found})")
    for npc in rares.get(inst, []):
        items = drops(npc)
        if items: entries["rare:%d" % npc] = items
    entries.update(FOREVER.get(inst, {}))
    if entries: out[inst] = entries

lines = ["-- GENERATED by tools/build_dungeon_loot.py - do not edit by hand.",
         "-- Boss and rare loot per instance with drop chance in percent (classic drop tables; Forever can differ,",
         "-- the panel marks items seen dropping in Forever; FOREVER in the script overrides reworked bosses).",
         "-- [instanceID] = { [encounterID or \"rare:<npcID>\"] =",
         "-- { { itemID, chance }, ... } }",
         "local _, ns = ...", "", "ns.DUNGEON_LOOT = {"]
for inst, entries in out.items():
    lines.append("    [%d] = {" % inst)
    for key, items in entries.items():
        k = ('["%s"]' % key) if isinstance(key, str) else ("[%d]" % key)
        lines.append("        %s = { %s }," % (k, ", ".join("{ %d, %s }" % (i, ("%.1f" % c).rstrip('0').rstrip('.')) for i, c in items)))
    lines.append("    },")
lines.append("}")
(ROOT / "Map" / "DungeonLoot.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("instances:", len(out), "sources:", sum(len(e) for e in out.values()))
print("\n".join(report))
