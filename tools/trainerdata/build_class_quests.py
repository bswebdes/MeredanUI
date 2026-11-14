#!/usr/bin/env python3
"""Build tools/trainerdata/ClassQuests.lua: every class quest chain in WoW Forever.

Inputs (all read-only, downloaded by hand, see SOURCES.md):
  <questie>  folder with the Questie Forever database files, same file list and naming as
             tools/build_class_quests.py (raw.githubusercontent.com/Questie/QuestieDB/HEAD/<path>, slashes -> '_')
  <wt>       Classes/Camelot/QuestSpells.lua of the WhatsTraining addon, forever branch (spell <- reward quest map)
  <db2>      folder with SpellName.csv of the Forever client (wago.tools, product wowf, build 1.60.1.70938)

A chain = a connected group of quests limited to one class (linked by pre-quest, next-quest, breadcrumb or
exclusive-to). One entry per chain. Abilities a chain unlocks come from the QuestSpells map plus the
hand-checked UNLOCK_EXTRA table below.

usage: python3 -I tools/trainerdata/build_class_quests.py <questie> <wt QuestSpells.lua> <db2 folder>
"""
import collections, csv, json, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
from lualit import tokenize, P, parse_table_at, arr  # noqa: E402

D = pathlib.Path(sys.argv[1])
WT_QS = pathlib.Path(sys.argv[2])
DB2 = pathlib.Path(sys.argv[3])


def rd(name):
    return (D / name).read_text(encoding='utf-8', errors='replace')


# ---------------------------------------------------------------- load + merge (same order as Questie)
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
for k, v in MASK.items():
    env['raceIDs.' + k] = env['raceKeys.' + k] = v
for k, v in CLASS_BIT.items():
    env['classIDs.' + k] = env['classKeys.' + k] = v
env['classIDs.NONE'] = env['classKeys.NONE'] = 0
SORT = dict(WARRIOR=-81, PALADIN=-141, HUNTER=-261, ROGUE=-162, PRIEST=-262, SHAMAN=-82, MAGE=-161, WARLOCK=-61, DRUID=-263)
for k, v in SORT.items():
    env['sortKeys.' + k] = v
ZONES = {}
for k, v in re.findall(r"^\s+([A-Z_0-9]+) = (\d+)", rd('src_corrections_enum_zones.lua'), re.M):
    env['zoneIDs.' + k] = int(v)
    ZONES.setdefault(int(v), k)


def base(src, keymap):
    body = src[src.index('[[return {') + 9: src.rindex(']]')]
    p = P(tokenize(body), env)
    p.expect('{')
    tab = p.table()
    inv = {v: k for k, v in keymap.items()}
    return {str(i): {inv[j + 1]: val for j, val in enumerate(arr(rec)) if j + 1 in inv} for i, rec in tab.items()}


def apply(fname, store):
    src = rd(fname)
    m = re.search(r"function \w+:Load\(\)", src)
    for rid, fields in parse_table_at(src, src.index('return {', m.end()), env).items():
        if not (isinstance(fields, dict) and isinstance(rid, int)):
            continue
        rec = store.setdefault(str(rid), {})
        for k, v in fields.items():
            if not isinstance(k, str):
                continue
            if k.endswith('_add') or k.endswith('_remove'):
                kk = k.rsplit('_', 1)[0]
                cur = dict(rec.get(kk) or {})
                for slot, lst in (v or {}).items():
                    old = [x for x in (arr(cur.get(slot)) or []) if x is not None]
                    new = [x for x in (arr(lst) or []) if x is not None]
                    cur[slot] = old + [x for x in new if x not in old] if k.endswith('_add') else [x for x in old if x not in new]
                rec[kk] = cur
            else:
                rec[k] = v


q, n = base(qsrc, QK), base(nsrc, NK)
for f in ('src_corrections_Forever_legacy_classicQuestFixes.lua', 'src_corrections_Forever_generated_foreverBaseQuest.lua',
          'src_corrections_Forever_foreverQuestFixes.lua'):
    apply(f, q)
for f in ('src_corrections_Forever_legacy_classicNPCFixes.lua', 'src_corrections_Forever_generated_foreverBaseNpc.lua',
          'src_corrections_Forever_foreverNPCFixes.lua'):
    apply(f, n)
area2map = {int(a): int(b) for a, b in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", rd('support_Forever_Zones_areaIdToUiMapId.lua'))}


def lookup(fname):
    return {m.group(1): m.group(2).replace('\\"', '"') for m in
            re.finditer(r'^\[(\d+)\] = \{"((?:\\.|[^"\\])*)"', rd(fname), re.M)}


npc_de, quest_de = lookup('l10n_Forever_lookupNpcs_deDE.lua'), lookup('l10n_Forever_lookupQuests_deDE.lua')
spell_name = {r['ID']: r['Name_lang'] for r in csv.DictReader(open(DB2 / 'SpellName.csv', encoding='utf-8'))}

# ---------------------------------------------------------------- spell unlocks
# WhatsTraining QuestSpells: CLASS -> spellId -> list of { races, quests = reward quest ids }
wt_src = WT_QS.read_text(encoding='utf-8')
UNLOCK = collections.defaultdict(list)  # reward quest id -> [(class, spellID)]
cur_cls = None
for line in wt_src.splitlines():
    m = re.match(r'\s{4}([A-Z]+) = \{', line)
    if m:
        cur_cls = m.group(1)
        continue
    m = re.match(r'\s+\[(\d+)\] = \{', line)
    if m:
        cur_spell = int(m.group(1))
        continue
    m = re.search(r'quests = \{([\d, ]+)\}', line)
    if m and cur_cls:
        for qid in m.group(1).replace(' ', '').split(','):
            UNLOCK[qid].append((cur_cls, cur_spell))

# Hand-checked extra unlocks (quest id -> list of (type, id, name)). Items are the classic totem items, which the
# Forever quests still hand out (quest names and Questie objectives match Classic Era).
UNLOCK_EXTRA = {
    # Shaman totem items (needed in the bag to drop totems of that element, Classic Era rule)
    'Call of Earth': [('item', 5175, 'Earth Totem')],
    'Call of Fire': [('item', 5176, 'Fire Totem')],
    'Call of Water': [('item', 5177, 'Water Totem')],
    'Call of Air': [('item', 5178, 'Air Totem')],
}

RACE_BITS = [(1, 1), (2, 2), (4, 3), (8, 4), (16, 5), (32, 6), (64, 7), (128, 8), (1 << 32, 95), (1 << 33, 96)]
ALLIANCE = {1, 3, 4, 7, 95}
HORDE = {2, 5, 6, 8, 96}


def races_of(mask):
    if not mask:
        return []
    return [r for b, r in RACE_BITS if mask & b]


def faction_of(rs):
    if not rs:
        return 'both'
    s = set(rs)
    if s <= ALLIANCE:
        return 'Alliance'
    if s <= HORDE:
        return 'Horde'
    return 'both'


def ids(v):
    if isinstance(v, dict):
        return [str(x) for x in v.values() if x is not None]
    if isinstance(v, list):
        return [str(x) for x in v if x is not None]
    return []


def class_quests(cls):
    b = CLASS_BIT[cls]
    return {k for k, v in q.items() if (v.get('requiredClasses') or 0) & b and v.get('name')}


def links(k):
    v = q[k]
    out = set(ids(v.get('preQuestSingle'))) | set(ids(v.get('preQuestGroup')))
    if v.get('nextQuestInChain'):
        out.add(str(v['nextQuestInChain']))
    if v.get('breadcrumbForQuestId'):
        out.add(str(v['breadcrumbForQuestId']))
    out |= set(ids(v.get('exclusiveTo')))
    return out


def prereqs(k, S):
    v = q[k]
    out = set(ids(v.get('preQuestSingle'))) | set(ids(v.get('preQuestGroup')))
    if v.get('breadcrumbForQuestId') is None:
        out |= {x for x in S if str(q[x].get('nextQuestInChain') or '') == k}
    out |= {x for x in S if str(q[x].get('breadcrumbForQuestId') or '') == k}
    return out & S


def components(cls):
    S = class_quests(cls)
    adj = collections.defaultdict(set)
    for k in S:
        for l in links(k):
            if l in S:
                adj[k].add(l)
                adj[l].add(k)
    seen, comps = set(), []
    for k in sorted(S, key=int):
        if k in seen:
            continue
        st, c = [k], set()
        while st:
            x = st.pop()
            if x in c:
                continue
            c.add(x)
            st.extend(adj[x])
        seen |= c
        comps.append(sorted(c, key=int))
    return comps


def spawn_of(npc_id):
    rec = n.get(str(npc_id))
    if not rec:
        return None
    for area, pts in (rec.get('spawns') or {}).items():
        for pt in (pts or {}).values():
            if isinstance(pt, dict) and pt.get(1) is not None:
                return dict(npc=int(npc_id), npc_en=rec.get('name'), npc_de=npc_de.get(str(npc_id)),
                            zone=ZONES.get(int(area), str(area)).replace('_', ' ').title(), area=int(area),
                            map=area2map.get(int(area)), x=pt[1], y=pt[2])
    return dict(npc=int(npc_id), npc_en=rec.get('name'), npc_de=npc_de.get(str(npc_id)))


def starter(qid):
    sb = q[qid].get('startedBy') or {}
    for slot, kind in ((1, 'npc'), (2, 'object'), (3, 'item')):
        lst = ids((sb.get(slot) if isinstance(sb, dict) else None) or [])
        for i in lst:
            if kind == 'npc':
                s = spawn_of(i)
                if s and s.get('map'):
                    return s
            else:
                return {kind: int(i)}
        if kind == 'npc' and lst:
            return spawn_of(lst[0])
    return None


def category(level, names):
    if level >= 55:
        return 'endgame'
    return 'leveling'


out = {}
for cls in CLASS_BIT:
    S = class_quests(cls)
    entries = []
    for comp in components(cls):
        cs = set(comp)
        heads = [k for k in comp if not prereqs(k, cs)]
        finals = [k for k in comp if not any(k in prereqs(x, cs) for x in comp)]
        level = min((q[k].get('requiredLevel') or 0) for k in comp)
        mask = 0
        for k in comp:
            mask |= q[k].get('requiredRaces') or 0
        if any(not (q[k].get('requiredRaces') or 0) for k in comp):
            mask = 0
        rs = races_of(mask)
        unlocks, seen_u = [], set()
        for k in comp:
            for c2, sid in UNLOCK.get(k, []):
                if c2 == cls and ('spell', sid) not in seen_u:
                    seen_u.add(('spell', sid))
                    unlocks.append(dict(type='spell', id=sid, name=spell_name.get(str(sid), '?'), quest=int(k), verified='forever'))
        for k in finals:
            for t, i, nm in UNLOCK_EXTRA.get(q[k].get('name'), []):
                if (t, i) not in seen_u:
                    seen_u.add((t, i))
                    unlocks.append(dict(type=t, id=i, name=nm, quest=int(k), verified='classic_era'))
        def nraces(k):
            r = q[k].get('requiredRaces') or 0
            return 99 if not r else len(races_of(r))
        head = sorted(heads, key=lambda k: (-nraces(k), int(k)))[0]
        starts = [dict(quest=int(k), level=q[k].get('requiredLevel') or 0, races=races_of(q[k].get('requiredRaces') or 0),
                       start=starter(k)) for k in sorted(heads, key=int)]
        entries.append(dict(
            first=int(head), heads=[int(x) for x in sorted(heads, key=int)], name=q[head].get('name'),
            name_de=quest_de.get(head), level=level, races=rs, faction=faction_of(rs),
            start=starter(head), starts=starts, quests=[int(x) for x in comp], finals=[int(x) for x in sorted(finals, key=int)],
            final_name=q[sorted(finals, key=int)[-1]].get('name'),
            unlocks=unlocks, required=bool(any(u['type'] == 'spell' for u in unlocks)),
            category='ability' if any(u['type'] == 'spell' for u in unlocks) else category(level, [])))
    entries.sort(key=lambda e: (e['category'] != 'ability', e['level'], e['first']))
    out[cls] = entries


# ---------------------------------------------------------------- write Lua
def lua(v):
    if v is None:
        return 'nil'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int,)):
        return str(v)
    if isinstance(v, float):
        return ('%.2f' % v).rstrip('0').rstrip('.')
    return '"' + str(v).replace('\\', '\\\\').replace('"', '\\"').replace('\n', ' ') + '"'


def ltab(d, order):
    parts = []
    for k in order:
        if k in d and d[k] is not None:
            parts.append('%s = %s' % (k, lua(d[k])))
    return '{ ' + ', '.join(parts) + ' }'


L = ['-- Generated by tools/trainerdata/build_class_quests.py - do not edit by hand.',
     '-- Research data (not loaded by the addon yet). Format: see tools/trainerdata/README.md.',
     '-- Sources: Questie Forever database (quests, NPCs, races), WhatsTraining forever branch (spell rewards),',
     '-- Forever client SpellName (build 1.60.1.70938). verified = "forever" means the quest is in the Forever quest data.',
     'local CLASS_QUESTS = {']
for cls in sorted(out):
    L.append('    %s = {' % cls)
    for e in out[cls]:
        L.append('        {')
        L.append('            first = %d, name = %s,%s level = %d, category = %s,' % (
            e['first'], lua(e['name']), (' name_de = %s,' % lua(e['name_de'])) if e['name_de'] and e['name_de'] != e['name'] else '',
            e['level'], lua(e['category'])))
        L.append('            faction = %s, races = { %s },' % (lua(e['faction']), ', '.join(map(str, e['races']))))
        if e['start']:
            L.append('            start = %s,' % ltab(e['start'], ['npc', 'npc_en', 'npc_de', 'object', 'item', 'zone', 'map', 'x', 'y']))
        if len(e['starts']) > 1:
            L.append('            starts = {')
            for st in e['starts']:
                L.append('                { quest = %d, level = %d, races = { %s }%s },' % (st['quest'], st['level'], ', '.join(map(str, st['races'])),
                         (', start = ' + ltab(st['start'], ['npc', 'npc_en', 'object', 'item', 'zone', 'map', 'x', 'y'])) if st['start'] else ''))
            L.append('            },')
        L.append('            quests = { %s },' % ', '.join(map(str, e['quests'])))
        L.append('            finals = { %s }, final_name = %s,' % (', '.join(map(str, e['finals'])), lua(e['final_name'])))
        if e['unlocks']:
            L.append('            unlocks = {')
            for u in e['unlocks']:
                L.append('                %s,' % ltab(u, ['type', 'id', 'name', 'quest', 'verified']))
            L.append('            },')
        L.append('            required = %s, verified = "forever",' % lua(e['required']))
        L.append('        },')
    L.append('    },')
L.append('}')
L.append('')
L.append('return CLASS_QUESTS')
(HERE / 'ClassQuests.lua').write_text('\n'.join(L) + '\n', encoding='utf-8')
print({c: len(v) for c, v in out.items()})
print('ability chains:', {c: sum(1 for e in v if e['category'] == 'ability') for c, v in out.items()})
