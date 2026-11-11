#!/usr/bin/env python3
"""Class quests per class/race for the class quest reminder (Quests/ClassQuestReminder.lua).

Source: the Questie Forever database (github.com/Questie/QuestieDB), used as a fact reference only.
Download these files into one folder (raw.githubusercontent.com/Questie/QuestieDB/HEAD/<path>, slashes
replaced by underscores):
  data/Forever/foreverQuestDB.lua, data/Forever/foreverNpcDB.lua,
  src/corrections/Forever/legacy/classicQuestFixes.lua, src/corrections/Forever/legacy/classicNPCFixes.lua,
  src/corrections/Forever/generated/foreverBaseQuest.lua, src/corrections/Forever/generated/foreverBaseNpc.lua,
  src/corrections/Forever/foreverQuestFixes.lua, src/corrections/Forever/foreverNPCFixes.lua,
  src/corrections/enum/zones.lua, support/Forever/Zones/areaIdToUiMapId.lua,
  l10n/Forever/lookupQuests/deDE.lua, l10n/Forever/lookupNpcs/deDE.lua
A milestone = the quests whose reward is a class ability (FAMILIES below, by English quest name).
Per race: the chain start nearest to the race's home (capital first, then starting zone).
Output: Quests/ClassQuests.lua (ns.CLASS_QUESTS).
usage: python3 -I tools/build_class_quests.py <questie folder>"""
import json, re, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lualit import tokenize, P, parse_table_at, arr

ROOT = pathlib.Path(__file__).resolve().parent.parent
D = pathlib.Path(sys.argv[1])
def rd(name): return (D / name).read_text(encoding='utf-8', errors='replace')

# --- load + merge (base data, then legacy fixes, generated Forever delta, authored Forever fixes) ---
qsrc, nsrc = rd('data_Forever_foreverQuestDB.lua'), rd('data_Forever_foreverNpcDB.lua')
def keys(src, name):
    body = re.search(name + r" = \{(.*?)\n\}", src, re.S).group(1)
    return {k: int(v) for k, v in re.findall(r"^\s+\['(\w+)'\] = (\d+)", body, re.M)}
QK, NK = keys(qsrc, 'QuestieDB.questKeys'), keys(nsrc, 'QuestieDB.npcKeys')
MASK = dict(HUMAN=1, ORC=2, DWARF=4, NIGHT_ELF=8, UNDEAD=16, TAUREN=32, GNOME=64, TROLL=128, GOBLIN=256,
            SKYBORNE_ALLIANCE=1 << 32, SKYBORNE_HORDE=1 << 33, NONE=0)
MASK['ALL_ALLIANCE'] = 1 + 4 + 8 + 64 + (1 << 32)
MASK['ALL_HORDE'] = 2 + 16 + 32 + 128 + (1 << 33)
CLASS_BIT = dict(WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16, SHAMAN=64, MAGE=128, WARLOCK=256, DRUID=1024)
env = {'questKeys.' + k: k for k in QK}
env.update({'npcKeys.' + k: k for k in NK})
for k, v in MASK.items(): env['raceIDs.' + k] = env['raceKeys.' + k] = v
for k, v in CLASS_BIT.items(): env['classIDs.' + k] = env['classKeys.' + k] = v
env['classIDs.NONE'] = env['classKeys.NONE'] = 0
for k, v in dict(WARRIOR=-81, PALADIN=-141, HUNTER=-261, ROGUE=-162, PRIEST=-262, SHAMAN=-82, MAGE=-161,
                 WARLOCK=-61, DRUID=-263).items(): env['sortKeys.' + k] = v
for k, v in re.findall(r"^\s+([A-Z_0-9]+) = (\d+)", rd('src_corrections_enum_zones.lua'), re.M): env['zoneIDs.' + k] = int(v)

def base(src, keymap):
    body = src[src.index('[[return {') + 9: src.rindex(']]')]
    p = P(tokenize(body), env); p.expect('{'); tab = p.table()
    inv = {v: k for k, v in keymap.items()}
    return {str(i): {inv[j + 1]: val for j, val in enumerate(arr(rec)) if j + 1 in inv} for i, rec in tab.items()}

def apply(fname, store):
    src = rd(fname)
    m = re.search(r"function \w+:Load\(\)", src)
    for rid, fields in parse_table_at(src, src.index('return {', m.end()), env).items():
        if not (isinstance(fields, dict) and isinstance(rid, int)): continue
        rec = store.setdefault(str(rid), {})
        for k, v in fields.items():
            if not isinstance(k, str): continue
            if k.endswith('_add') or k.endswith('_remove'):
                kk = k.rsplit('_', 1)[0]; cur = dict(rec.get(kk) or {})
                for slot, lst in (v or {}).items():
                    old = [x for x in (arr(cur.get(slot)) or []) if x is not None]
                    new = [x for x in (arr(lst) or []) if x is not None]
                    cur[slot] = old + [x for x in new if x not in old] if k.endswith('_add') else [x for x in old if x not in new]
                rec[kk] = cur
            else:
                rec[k] = v

q, n = base(qsrc, QK), base(nsrc, NK)
for f in ('classicQuestFixes', 'foreverBaseQuest', 'foreverQuestFixes'):
    apply({'classicQuestFixes': 'src_corrections_Forever_legacy_classicQuestFixes.lua',
           'foreverBaseQuest': 'src_corrections_Forever_generated_foreverBaseQuest.lua',
           'foreverQuestFixes': 'src_corrections_Forever_foreverQuestFixes.lua'}[f], q)
for f in ('src_corrections_Forever_legacy_classicNPCFixes.lua', 'src_corrections_Forever_generated_foreverBaseNpc.lua',
          'src_corrections_Forever_foreverNPCFixes.lua'):
    apply(f, n)
area2map = {int(a): int(b) for a, b in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", rd('support_Forever_Zones_areaIdToUiMapId.lua'))}
def lookup(fname):
    return {m.group(1): m.group(2).replace('\\"', '"') for m in
            re.finditer(r'^\[(\d+)\] = \{"((?:\\.|[^"\\])*)"', rd(fname), re.M)}
npc_de, quest_de = lookup('l10n_Forever_lookupNpcs_deDE.lua'), lookup('l10n_Forever_lookupQuests_deDE.lua')
# German names from Wowhead Forever tooltips win (new Forever quests/NPCs are missing above). Fetch with
# tools/dungeondata/scripts/fetch_tooltips.py forever <quest|npc> tools/classquests_ids_<kind>.txt 1 3
CACHE = ROOT / 'tools' / 'dungeondata' / 'cache'
for kind, target in (('quest', quest_de), ('npc', npc_de)):
    f = CACHE / ('forever_%s_3.json' % kind)
    if f.exists():
        for i, rec in json.loads(f.read_text()).items():
            if rec.get('name') and not rec.get('error'): target[i] = rec['name']

# --- milestones ---
# race ID (UnitRace 3rd return) -> requiredRaces bit, home maps (capital first)
RACES = {1: (1, [1453, 1429]), 3: (4, [1455, 1426]), 4: (8, [1457, 1438]), 7: (64, [1455, 1426]), 95: (1 << 32, [2521]),
         2: (2, [1454, 1411]), 5: (16, [1458, 1420]), 6: (32, [1456, 1412]), 8: (128, [1454, 1411]), 96: (1 << 33, [2521])}
ALL = sum(b for b, _ in RACES.values())
ALLIANCE_BITS = {1, 4, 8, 64, 1 << 32}
# class, reward (English, translated in Core/Locales.lua), quest names of the reward quests ("name@level" if ambiguous)
FAMILIES = [
    ('WARRIOR', 'Defensive Stance', {"Bartleby's Mug", "Vejrek", "Vorlus Vilehoof", "Path of Defense", "Ulag the Cleaver", "The Skybreaker Bulwark"}),
    ('WARRIOR', 'Berserker Stance', {"The Affray"}),
    ('PALADIN', 'Redemption', {"The Tome of Divinity", "A Lesson in Divinity"}),
    ('PALADIN', 'Summon Warhorse', {"The Tome of Nobility", "A Paladin's Steed"}),
    ('PALADIN', 'Summon Charger', {"Judgment and Redemption", "The Reliquary of Tyr"}),
    ('HUNTER', 'Tame Beast', {"Training the Beast"}),
    ('ROGUE', 'Poisons', {"Klaven's Tower", "Hinott's Assistance"}),
    ('SHAMAN', 'Earth Totem', {"Call of Earth"}),
    ('SHAMAN', 'Fire Totem', {"Call of Fire"}),
    ('SHAMAN', 'Water Totem', {"Call of Water"}),
    ('SHAMAN', 'Air Totem', {"Call of Air"}),
    ('WARLOCK', 'Summon Voidwalker', {"The Binding@10"}),
    ('WARLOCK', 'Summon Succubus', {"The Binding@20"}),
    ('WARLOCK', 'Summon Felhunter', {"The Binding@30"}),
    ('WARLOCK', 'Summon Felsteed', {"Summon Felsteed"}),
    ('WARLOCK', 'Inferno', {"Kroshius' Infernal Core"}),
    ('WARLOCK', 'Ritual of Doom', {"Suppression"}),
    ('WARLOCK', 'Summon Dreadsteed', {"Dreadsteed of Xoroth"}),
    ('DRUID', 'Bear Form', {"Body and Heart", "Strength and Mercy"}),
    ('DRUID', 'Cure Poison', {"Power over Poison"}),
    ('DRUID', 'Aquatic Form', {"Aquatic Form"}),
    ('DRUID', 'Cat Form', {"Blessings of the Great Cat Spirit"}),
    ('PRIEST', 'Racial spell', {"Desperate Prayer", "Stars of Elune", "Hex of Weakness", "Touch of Weakness", "Divine Grace", "Confounding Flash", "Returning Home"}),
    ('PRIEST', 'Racial spell', {"Arcane Feedback", "A Lack of Fear", "Elune's Grace", "Shadowguard", "Devouring Plague", "Contingency Plan", "Chastise", "Dark Sacrifice"}),
]

def ids(t, slot):
    t = t.get(slot) if isinstance(t, dict) else None
    return [str(x) for x in (t.values() if isinstance(t, dict) else []) if x is not None]
prevmap = {}
for k, v in q.items():
    for key in ('preQuestSingle', 'preQuestGroup'):
        for p in ids({'x': v.get(key)}, 'x'): prevmap.setdefault(k, []).append(p)
    if v.get('nextQuestInChain'): prevmap.setdefault(str(v['nextQuestInChain']), []).append(k)
nextmap = {}
for k, ps in prevmap.items():
    for p in ps: nextmap.setdefault(p, []).append(k)

def roots(final, bit):
    """chain starts leading to `final` -> (race mask valid along the path, quest ids on the path)"""
    out = {}
    def walk(k, mask, path):
        mask &= q[k].get('requiredRaces') or ALL
        ps = [p for p in prevmap.get(k, []) if p in q and (q[p].get('requiredClasses') or 0) & bit and p not in path]
        if not ps:
            m, s = out.get(k, (0, set())); out[k] = (m | mask, s | set(path)); return
        for p in ps: walk(p, mask, path | {p})
    walk(final, ALL, {final})
    return out

def giver(qid, homes, side):
    """(npc id, de, en, uiMap, x, y) of the quest start, preferring a spawn on the home maps.
    A starter hostile to the player's side (e.g. a Horde city NPC for a quest open to all) is skipped
    in favour of the quest's turn-in NPC, which is where the chain really begins for that side."""
    for slot_key in ('startedBy', 'finishedBy'):
        for i in ids(q[qid].get(slot_key) or {}, 1):
            rec = n.get(i)
            if not rec or 'Innkeeper' in str(rec.get('subName') or ''): continue  # breadcrumb letters
            if side not in str(rec.get('friendlyToFaction') or 'AH'): continue
            spots = []
            for area, pts in (rec.get('spawns') or {}).items():
                for pt in (pts or {}).values():
                    if isinstance(pt, dict) and pt.get(1) is not None:
                        spots.append((area2map.get(int(area)), pt[1], pt[2]))
            if not spots: continue
            spots.sort(key=lambda s: homes.index(s[0]) if s[0] in homes else 9)
            return (int(i), npc_de.get(i) or rec.get('name'), rec.get('name')) + spots[0]
    return None

out = {}
for cls, reward, names in FAMILIES:
    bit = CLASS_BIT[cls]
    fam = [k for k, v in q.items() if (v.get('requiredClasses') or 0) & bit
           and ((v.get('name') or '') in names or '%s@%s' % (v.get('name'), v.get('requiredLevel')) in names)]
    finals = sorted({k for k in fam if not any(x in fam for x in nextmap.get(k, []))}, key=int)
    starts, quest_ids, level = {}, set(finals), None
    candidates = []
    for f in finals:
        for head, (mask, path) in roots(f, bit).items():
            quest_ids |= path
            candidates.append((head, mask))
    for race, (rbit, homes) in RACES.items():
        best = None
        for head, mask in candidates:
            if not mask & rbit: continue
            g = giver(head, homes, 'A' if rbit in ALLIANCE_BITS else 'H')
            rank = (0 if g and g[3] in homes else 1, homes.index(g[3]) if g and g[3] in homes else 9, 0 if g else 1, int(head))
            if best is None or rank < best[0]: best = (rank, head, g)
        if best:
            head, g = best[1], best[2]
            starts[race] = dict(quest=int(head), qde=quest_de.get(head), qen=q[head].get('name'), g=g)
            lv = q[head].get('requiredLevel') or 0
            level = lv if level is None else min(level, lv)
    if starts:
        out.setdefault(cls, []).append(dict(reward=reward, level=level, ids=sorted(int(x) for x in quest_ids),
                                            finals=[int(x) for x in finals], starts=starts))

# --- write Lua ---
def lua(s): return '"' + str(s).replace('\\', '\\\\').replace('"', '\\"') + '"'
lines = ['-- Generated by tools/build_class_quests.py - do not edit.',
         '-- Class quests that unlock an ability: per class a list of { level, reward, finals (reward quests),',
         '-- ids (all quests of the milestone, to see a started chain), starts[raceID] = { quest, name, nameEN, npc, npcEN, map, x, y } }.',
         'local _, ns = ...', '', 'ns.CLASS_QUESTS = {']
for cls in sorted(out):
    lines.append('    %s = {' % cls)
    for m in sorted(out[cls], key=lambda m: (m['level'], m['reward'])):
        lines.append('        { level = %d, reward = %s, finals = { %s },' % (m['level'], lua(m['reward']), ', '.join(map(str, m['finals']))))
        lines.append('            ids = { %s },' % ', '.join(map(str, m['ids'])))
        lines.append('            starts = {')
        for race in sorted(m['starts']):
            s = m['starts'][race]; g = s['g']
            parts = ['quest = %d' % s['quest'], 'nameEN = %s' % lua(s['qen'])]
            if s['qde'] and s['qde'] != s['qen']: parts.append('name = %s' % lua(s['qde']))
            if g:
                parts.append('npcEN = %s' % lua(g[2]))
                if g[1] != g[2]: parts.append('npc = %s' % lua(g[1]))
                if g[3]: parts += ['map = %d' % g[3], 'x = %.2f' % g[4], 'y = %.2f' % g[5]]
            lines.append('                [%d] = { %s },' % (race, ', '.join(parts)))
        lines.append('            } },')
    lines.append('    },')
lines.append('}')
(ROOT / 'Quests' / 'ClassQuests.lua').write_text('\n'.join(lines) + '\n', encoding='utf-8')
used = {'quest': set(), 'npc': set()}
for v in out.values():
    for m in v:
        for st in m['starts'].values():
            used['quest'].add(st['quest'])
            if st['g']: used['npc'].add(st['g'][0])
for kind, idset in used.items():
    (ROOT / 'tools' / ('classquests_ids_%s.txt' % kind)).write_text('\n'.join(map(str, sorted(idset))) + '\n')
print(sum(len(v) for v in out.values()), 'milestones,', sum(len(m['starts']) for v in out.values() for m in v), 'race starts')
