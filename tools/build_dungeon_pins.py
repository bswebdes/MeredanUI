#!/usr/bin/env python3
"""Boss and rare pins for the classic dungeon maps from cMaNGOS classic-db spawn positions.

Bosses: matched by name (DungeonEncounter names from Quests/DungeonBosses.lua, enUS) to creature
templates; rares: creatures of rank 2/4 spawned in the instance. Position -> floor via the floor's world
region (Map/DungeonMapData.lua), x/y relative to the map art. Group encounters with no single creature
of that name (e.g. "The Seven") are left out and placed by hand (/mui pins, dev).
Output: Map/DungeonPinData.lua (ns.DUNGEON_PINS), keeps hand-placed pins for instances not generated here.
usage: python3 -I tools/build_dungeon_pins.py <ClassicDB.sql.gz>"""
import gzip, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
DB = sys.argv[1]

def tuples(sql, table):
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

sql = gzip.open(DB, 'rt', encoding='utf-8', errors='replace').read()
cols = re.search(r"CREATE TABLE `creature_template` \((.*?)\n\)", sql, re.S).group(1)
names = re.findall(r"^\s+`(\w+)`", cols, re.M)
iE, iN, iM, iR = names.index('Entry'), names.index('Name'), names.index('ModelId1'), names.index('Rank')
templates = {}
for r in tuples(sql, 'creature_template'):
    templates[int(r[iE])] = (r[iN], int(r[iM]), int(r[iR]))
# random-entry spawns (id 0) carry their candidates in creature_spawn_entry
alt = {}
for r in tuples(sql, 'creature_spawn_entry'):
    alt.setdefault(int(r[0]), []).append(int(r[1]))
# spawn groups: guids of a group take one of the group's entries
gguids, gentries = {}, {}
for r in tuples(sql, 'spawn_group_spawn'):
    gguids.setdefault(int(r[0]), []).append(int(r[1]))
for r in tuples(sql, 'spawn_group_entry'):
    gentries.setdefault(int(r[0]), []).append(int(r[1]))
for gid, guids in gguids.items():
    for g in guids:
        alt.setdefault(g, []).extend(gentries.get(gid, []))
spawns = {}
for r in tuples(sql, 'creature'):
    pos = (float(r[4]), float(r[5]), float(r[6]))
    for entry in ([int(r[1])] if int(r[1]) else alt.get(int(r[0]), [])):
        spawns.setdefault(int(r[2]), []).append((entry,) + pos)
# event bosses: summon positions from db scripts (command 10 = summon creature; no map, checked per floor)
summons = {}
for table in re.findall(r"CREATE TABLE `(dbscripts_on_\w+)`", sql):
    for r in tuples(sql, table):
        if r[3] == '10' and int(r[4]) in templates:
            summons.setdefault(int(r[4]), (float(r[15]), float(r[16]), float(r[17])))

# floors per instance from the generated map data
maps = {}
text = (ROOT / "Map" / "DungeonMapData.lua").read_text(encoding="utf-8")
for m in re.finditer(r"\[(\d+)\] = \{(.*?)\n    \},", text, re.S):
    floors = []
    for f in re.finditer(r"region = \{ ([-\d., ]+) \}", m.group(2)):
        floors.append([float(v) for v in f.group(1).split(', ')])
    maps[int(m.group(1))] = floors
bosses = {}
for m in re.finditer(r"\[(\d+)\] = \{ (.*?) \},\n", (ROOT / "Quests" / "DungeonBosses.lua").read_text(encoding="utf-8")):
    bosses[int(m.group(1))] = re.findall(r'\{ (\d+), "((?:[^"\\]|\\.)*)", "(?:[^"\\]|\\.)*" \}', m.group(2))

def place(floors, x, y, z):
    best = None
    for i, (x1, y1, z1, x2, y2, z2) in enumerate(floors):
        if not (x1 <= x <= x2 and y1 <= y <= y2): continue
        dz = 0 if z1 <= z <= z2 else min(abs(z - z1), abs(z - z2))
        if best is None or dz < best[0]: best = (dz, i, (y2 - y) / (y2 - y1), (x2 - x) / (x2 - x1))
    return best

out = {}
report = []
for inst, floors in sorted(maps.items()):
    pins = []
    here = spawns.get(inst, [])
    byname = {}
    for entry, x, y, z in here:
        t = templates.get(entry)
        if t: byname.setdefault(t[0].lower(), []).append((entry, x, y, z))
    bossNames = {n.lower() for _, n in bosses.get(inst, [])}
    for enc, name in bosses.get(inst, []):
        hit = byname.get(name.replace("\\'", "'").lower())
        if not hit:
            for entry, pos in summons.items():
                if templates[entry][0].lower() == name.lower() and place(floors, *pos):
                    hit = [(entry,) + pos]; break
        if not hit:
            # name drift between DungeonEncounter and the DB (e.g. "Frostwhisperer"/"Frostwhisper")
            first = name.lower().split()[0]
            for key, h in byname.items():
                if key.split()[0] == first and len(first) > 3 and templates[h[0][0]][2] in (1, 3):
                    hit = h; break
        if not hit:
            report.append(f"{inst}: no spawn for boss '{name}'"); continue
        entry, x, y, z = hit[0]
        p = place(floors, x, y, z)
        if not p:
            report.append(f"{inst}: '{name}' outside all floors"); continue
        pins.append(('boss', int(enc), p[1] + 1, p[2], p[3], templates[entry][1], None))
    seen = set()
    for entry, x, y, z in here:
        t = templates.get(entry)
        if not t or t[2] not in (2, 4) or entry in seen or t[0].lower() in bossNames: continue
        seen.add(entry)
        p = place(floors, x, y, z)
        if p: pins.append(('rare', entry, p[1] + 1, p[2], p[3], t[1], t[0]))
    if pins: out[inst] = pins

def lua(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
lines = ["-- GENERATED by tools/build_dungeon_pins.py (spawn positions: cMaNGOS classic-db) - plus hand-placed",
         "-- pins from /mui pins (dev). [instanceMapID] = { { kind, id, floor, x, y, display, name }, ... }",
         "-- kind \"boss\" (id = DungeonEncounter ID) or \"rare\" (id = NPC ID); x/y relative to the map art;",
         "-- display = creature display ID for the round portrait.",
         "local _, ns = ...", "", "ns.DUNGEON_PINS = {"]
for inst, pins in out.items():
    rows = []
    for kind, pid, fl, x, y, disp, name in pins:
        rows.append('{ kind = "%s", id = %d, floor = %d, x = %.4f, y = %.4f, display = %d%s }' % (
            kind, pid, fl, x, y, disp, (', name = ' + lua(name)) if name else ''))
    lines.append("    [%d] = {\n        %s,\n    }," % (inst, ",\n        ".join(rows)))
lines.append("}")
(ROOT / "Map" / "DungeonPinData.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("instances:", len(out), "pins:", sum(len(p) for p in out.values()))
print("\n".join(report))
