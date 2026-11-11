#!/usr/bin/env python3
"""Quests per dungeon for the dungeon panel's quest tab, from a classic world database dump.

A quest belongs to a dungeon when its zone is the dungeon's zone (AreaTable: the top area on the
instance map). Giver = first quest-starting creature/object with a spawn (continent map + world x/y,
turned into a map position in the game), else the item that starts it. Quests without any giver are
left out (unused in the game). Plus the quests of the Forever guides (tools/dungeondata/instances/*.json):
classic ones get their data from the dump, new Forever quests keep the guide data with the giver's zone
(zone = uiMapID, from the guide's zone name) instead of a position.
Output: Quests/DungeonQuests.lua (ns.DUNGEON_QUESTS).
usage: python3 -I tools/build_dungeon_quests.py <world.sql.gz> <AreaTable.csv>"""
import csv, gzip, json, re, sys, pathlib

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

# dungeon zone per instance map
zone_of = {}
for a in csv.DictReader(open(sys.argv[2], encoding='utf-8')):
    if a['ParentAreaID'] == '0':
        zone_of.setdefault(int(a['ContinentID']), int(a['ID']))
bosses = [int(x) for x in re.findall(r"^    \[(\d+)\] = ", (ROOT / "Quests" / "DungeonBosses.lua").read_text(encoding="utf-8"), re.M)]
instance_of_zone = {zone_of[i]: i for i in bosses if i in zone_of and i != 0}  # 0 = unused map entry

qc = columns('quest_template')
q = {name: qc.index(name) for name in ('entry', 'ZoneOrSort', 'MinLevel', 'QuestLevel', 'RequiredClasses', 'RequiredRaces', 'Title')}
quests = {}
for r in tuples('quest_template'):
    zone = int(r[q['ZoneOrSort']])
    if zone in instance_of_zone:
        quests[int(r[q['entry']])] = (instance_of_zone[zone], int(r[q['QuestLevel']]), int(r[q['MinLevel']]),
                                      int(r[q['RequiredRaces']]), int(r[q['RequiredClasses']]), r[q['Title']])

# quests from the Forever guide research (dungeon given by the file name)
by_entry = {int(r[q['entry']]): r for r in tuples('quest_template')}
uimap = {}
for r in csv.DictReader(open(ROOT / "tools" / "mapdata" / "UiMap_wowf.csv", encoding='utf-8')):
    if r['Type'] in ('3', '5'): uimap.setdefault(r['Name_lang'].lower(), int(r['ID']))
ZONE_ALIAS = {"stormwind": "stormwind city", "dalaran": "alterac mountains", "ratchet": "the barrens",
              "lower blackrock spire": "burning steppes", "upper blackrock spire": "burning steppes"}
def guide_zone(text):
    name = (text or "").split(" (")[0].strip().lower()
    return uimap.get(ZONE_ALIAS.get(name, name))
new_quests, guide_giver = {}, {}
for path in sorted((ROOT / "tools" / "dungeondata" / "instances").glob("*.json")):
    if not path.stem.isdigit(): continue
    inst = int(path.stem)
    for g in json.loads(path.read_text(encoding="utf-8")).get("quests", []):
        qid = g.get("quest_id")
        if not qid or qid in new_quests: continue
        guide_giver.setdefault(qid, (g.get("giver"), guide_zone(g.get("giver_zone"))))
        if qid in quests: continue
        r = by_entry.get(qid)
        if r:
            quests[qid] = (inst, int(r[q['QuestLevel']]), int(r[q['MinLevel']]), int(r[q['RequiredRaces']]),
                           int(r[q['RequiredClasses']]), r[q['Title']])
        else:
            new_quests[qid] = (inst, g.get("level") or 0, g.get("min_level") or 0, g.get("races") or 0, 0,
                               g.get("title") or "", g.get("giver"), g.get("giver_item_id"), guide_zone(g.get("giver_zone")))

ct = columns('creature_template')
cname = {int(r[ct.index('Entry')]): r[ct.index('Name')] for r in tuples('creature_template')}
gname = {int(r[0]): r[3] for r in tuples('gameobject_template')}
cspawn, gspawn = {}, {}
for r in tuples('creature'):
    cspawn.setdefault(int(r[1]), (int(r[2]), float(r[4]), float(r[5])))
for r in tuples('gameobject'):
    gspawn.setdefault(int(r[1]), (int(r[2]), float(r[4]), float(r[5])))
givers = {}
for table, names, spawns in (('creature_questrelation', cname, cspawn), ('gameobject_questrelation', gname, gspawn)):
    for r in tuples(table):
        who, quest = int(r[0]), int(r[1])
        if quest in quests and who in spawns and quest not in givers:
            givers[quest] = (names.get(who, ''),) + spawns[who]
it = columns('item_template')
iE, iN, iS = it.index('entry'), it.index('name'), it.index('startquest')
item_start = {}
for r in tuples('item_template'):
    if int(r[iS]) in quests: item_start.setdefault(int(r[iS]), (int(r[iE]), r[iN]))

def lua(s): return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
out = {}
for qid, (inst, level, minlevel, races, classes, title) in sorted(quests.items(), key=lambda kv: (kv[1][1], kv[0])):
    if qid in givers:
        name, cmap, x, y = givers[qid]
        giver = 'giver = %s, map = %d, x = %.1f, y = %.1f' % (lua(name), cmap, x, y)
    elif qid in item_start:
        giver = 'item = %d' % item_start[qid][0]
    elif guide_giver.get(qid, (None,))[0]:
        # giver summoned by a script (no spawn): guide name, zone if outside
        name, zone = guide_giver[qid]
        giver = 'giver = %s' % lua(name.split(" (")[0]) + (', zone = %d' % zone if zone else '')
    else:
        continue
    out.setdefault(inst, []).append('{ id = %d, level = %d, min = %d, races = %d, classes = %d, title = %s, %s }' % (
        qid, level, minlevel, races, classes, lua(title), giver))

for qid, (inst, level, minlevel, races, classes, title, giver, item, zone) in sorted(new_quests.items(), key=lambda kv: (kv[1][1], kv[0])):
    if item: where = 'item = %d' % item
    elif giver: where = 'giver = %s' % lua(giver) + (', zone = %d' % zone if zone else '')
    elif zone: where = 'zone = %d' % zone  # giver not known yet, only the zone
    else: continue
    out.setdefault(inst, []).append('{ id = %d, level = %d, min = %d, races = %d, classes = %d, title = %s, %s }' % (
        qid, level, minlevel, races, classes, lua(title), where))

lines = ["-- GENERATED by tools/build_dungeon_quests.py - do not edit by hand.",
         "-- Quests per dungeon (classic quest data). races/classes = bit masks (0 = all); giver = quest giver",
         "-- with continent map and world x/y (or only zone = uiMapID for new Forever quests), or item = the item",
         "-- that starts the quest.",
         "local _, ns = ...", "", "ns.DUNGEON_QUESTS = {"]
for inst in sorted(out):
    lines.append("    [%d] = {\n        %s,\n    }," % (inst, ",\n        ".join(out[inst])))
lines.append("}")
(ROOT / "Quests" / "DungeonQuests.lua").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("instances:", len(out), "quests:", sum(len(v) for v in out.values()))
