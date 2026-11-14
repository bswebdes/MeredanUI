#!/usr/bin/env python3
"""Build tools/trainerdata/TrainerSpells.lua: every spell rank the class trainers teach in WoW Forever,
with leveling advice.

Inputs (read-only, downloaded by hand, see SOURCES.md):
  <db2>   folder with Forever client tables as CSV from wago.tools (product wowf, build 1.60.1.70938):
          SpellName, Spell, SpellLevels, SpellMisc, SkillLineAbility, SkillLine
  <wt>    Classes/Camelot folder of the WhatsTraining addon, forever branch (trainer list + training cost,
          base price before reputation discount; QuestSpells.lua for spells learned from quests)
  advice/<CLASS>.json in this folder: hand-checked leveling advice per spell name (see README.md)

Only classes that have an advice file are written. Spell IDs without a name in the Forever client
(removed spells) are dropped and listed in checks.txt.

usage: python3 -I tools/trainerdata/build_trainer_spells.py <db2 folder> <wt Camelot folder>
"""
import csv, json, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
DB2 = pathlib.Path(sys.argv[1])
WT = pathlib.Path(sys.argv[2])
CLASSES = ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID']
CLASS_MASK = dict(WARRIOR=1, PALADIN=2, HUNTER=4, ROGUE=8, PRIEST=16, SHAMAN=64, MAGE=128, WARLOCK=256, DRUID=1024)
SCHOOLS = {1: 'Physical', 2: 'Holy', 4: 'Fire', 8: 'Nature', 16: 'Frost', 32: 'Shadow', 64: 'Arcane'}
# class skill lines (SkillLine.CategoryID 7) -> tree name
TREES = {'WARRIOR': ['26', '256', '257'], 'PALADIN': ['594', '184', '267'], 'HUNTER': ['50', '163', '51'],
         'ROGUE': ['253', '38', '39'], 'PRIEST': ['613', '56', '78'], 'SHAMAN': ['375', '373', '374'],
         'MAGE': ['237', '8', '6'], 'WARLOCK': ['355', '354', '593'], 'DRUID': ['574', '134', '573']}


def load(t):
    return list(csv.DictReader(open(DB2 / f'{t}.csv', encoding='utf-8')))


NAME = {r['ID']: r['Name_lang'] for r in load('SpellName')}
SUB = {r['ID']: r['NameSubtext_lang'] for r in load('Spell')}
LVL = {r['SpellID']: r for r in load('SpellLevels') if r['DifficultyID'] == '0'}
SCHOOL = {r['SpellID']: int(r['SchoolMask'] or 0) for r in load('SpellMisc') if r['DifficultyID'] == '0'}
SKL = {r['ID']: r['DisplayName_lang'] for r in load('SkillLine')}
SLA = load('SkillLineAbility')


def tree_of(cls, sid):
    for r in SLA:
        if r['Spell'] == str(sid) and r['SkillLine'] in TREES[cls]:
            cm = int(r['ClassMask'] or 0)
            if not cm or cm & CLASS_MASK[cls]:
                return SKL[r['SkillLine']]
    for r in SLA:
        if r['Spell'] == str(sid):
            return SKL.get(r['SkillLine'], 'General')
    return 'General'


def parse_wt(path):
    src = open(path, encoding='utf-8').read()
    body = src[src.index('spellsByLevel'):]
    heads = [(m.start(), int(m.group(1))) for m in re.finditer(r'\[(\d+)\]\s*=\s*\{', body)]
    out = []
    for e in re.finditer(r'\{id = (\d+),([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', body):
        lvl = [l for pos, l in heads if pos < e.start()][-1]
        rest = e.group(2)
        d = dict(id=int(e.group(1)), level=lvl)
        c = re.search(r'cost = (\d+)', rest)
        d['cost'] = int(c.group(1)) if c else None
        r = re.search(r'requiredIds = \{([\d, ]*)\}', rest)
        d['req'] = [int(x) for x in r.group(1).replace(' ', '').split(',') if x] if r else []
        t = re.search(r'requiredTalentId = (\d+)', rest)
        d['talent'] = int(t.group(1)) if t else None
        ra = re.search(r'\brace = (\d+)', rest)
        d['race'] = int(ra.group(1)) if ra else None
        f = re.search(r'faction = "(\w+)"', rest)
        d['faction'] = f.group(1) if f else None
        out.append(d)
    return out


def parse_quest_spells(path):
    """CLASS -> spellId -> list of {races, level, quests}"""
    out, cls, sid = {}, None, None
    for line in open(path, encoding='utf-8'):
        m = re.match(r'\s{4}([A-Z]+) = \{', line)
        if m:
            cls = m.group(1)
            out[cls] = {}
            continue
        m = re.match(r'\s+\[(\d+)\] = \{', line)
        if m and cls:
            sid = int(m.group(1))
            out[cls][sid] = []
            continue
        m = re.search(r'races = \{([\d, ]+)\}, level = (\d+),.*quests = \{([\d, ]+)\}', line)
        if m and cls and sid:
            out[cls][sid].append(dict(races=[int(x) for x in m.group(1).replace(' ', '').split(',')],
                                      level=int(m.group(2)), quests=[int(x) for x in m.group(3).replace(' ', '').split(',')]))
    return out


QS = parse_quest_spells(WT / 'QuestSpells.lua')
# Hunter pet abilities are taught by the pet trainer, not the class trainer
PET_IDS = {int(x) for x in re.findall(r'\[(\d+)\] = true', (WT / 'HunterPets.lua').read_text(encoding='utf-8'))}


def rank_of(sid):
    m = re.match(r'Rank (\d+)', SUB.get(str(sid), '') or '')
    return int(m.group(1)) if m else None


def advice_for(adv, name, rank):
    a = adv['spells'].get(name)
    if not a:
        return None
    res = {k: a.get(k) for k in ('advice', 'reason_en', 'reason_de', 'role')}
    res['roles'] = a.get('roles')
    r = (a.get('ranks') or {}).get(str(rank)) if rank else None
    if r:
        for k in ('advice', 'reason_en', 'reason_de', 'role'):
            if r.get(k):
                res[k] = r[k]
        if r.get('roles'):
            res['roles'] = r['roles']
    return res


def lua(v):
    if v is None:
        return 'nil'
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, int):
        return str(v)
    if isinstance(v, list):
        return '{ ' + ', '.join(lua(x) for x in v) + ' }'
    if isinstance(v, dict):
        return '{ ' + ', '.join('%s = %s' % (k, lua(x)) for k, x in v.items() if x is not None) + ' }'
    return '"' + str(v).replace('\\', '\\\\').replace('"', '\\"') + '"'


checks = []
blocks = {}
missing_advice = {}
for cls in CLASSES:
    af = HERE / 'advice' / f'{cls}.json'
    if not af.exists():
        continue
    adv = json.loads(af.read_text(encoding='utf-8'))
    rows = []
    for d in parse_wt(WT / f'{cls.capitalize()}.lua'):
        s = str(d['id'])
        if s not in NAME:
            checks.append(f'{cls}: {s} (trainer level {d["level"]}) has no name in the Forever client - dropped (removed spell)')
            continue
        L = LVL.get(s, {})
        dbl = int(L.get('BaseLevel') or 0) or int(L.get('SpellLevel') or 0)
        if dbl and dbl != d['level']:
            checks.append(f'{cls}: {s} {NAME[s]} {SUB.get(s, "")}: trainer level {d["level"]}, client SpellLevels {dbl} (trainer level used)')
        req = {}
        if d['req']:
            req['spell'] = d['req'][0] if len(d['req']) == 1 else d['req']
        if d['talent']:
            req['talent'] = d['talent']
        if d['race']:
            req['races'] = [d['race']]
        if d['faction']:
            req['faction'] = d['faction']
        rows.append(dict(id=d['id'], name=NAME[s], rank=rank_of(s), level=d['level'], cost=d['cost'],
                         learnedFrom='talent' if d['talent'] else ('pettrainer' if cls == 'HUNTER' and d['id'] in PET_IDS else 'trainer'), req=req))
    # spells learned from class quests (rank 1 of totems, pets, stances, forms, racials ...)
    have = {r['id'] for r in rows}
    for sid, variants in (QS.get(cls) or {}).items():
        if sid in have or str(sid) not in NAME:
            continue
        races = sorted({r for v in variants for r in v['races']})
        quests = sorted({x for v in variants for x in v['quests']})
        lv = min(v['level'] for v in variants)
        req = {'quest': quests}
        if len(races) < 10:
            req['races'] = races
        rows.append(dict(id=sid, name=NAME[str(sid)], rank=rank_of(sid), level=lv, cost=0, learnedFrom='quest', req=req))
    rows.sort(key=lambda r: (r['level'], r['name'], r['rank'] or 0))
    out = []
    for r in rows:
        s = str(r['id'])
        a = advice_for(adv, r['name'], r['rank'])
        if (not a or not a.get('advice')) and r['learnedFrom'] == 'quest':
            a = dict(advice='recommended', reason_en='Learned from a class quest, not the trainer.',
                     reason_de='Lernst du durch eine Klassenquest, nicht beim Lehrer.')
        if not a or not a.get('advice'):
            missing_advice.setdefault(cls, set()).add(r['name'])
            a = dict(advice='optional', reason_en='No guide data yet.', reason_de='Noch keine Guide-Daten.')
        sm = SCHOOL.get(s, 0)
        e = dict(id=r['id'], name=r['name'], rank=r['rank'], level=r['level'], cost=r['cost'],
                 school=SCHOOLS.get(sm, 'Physical' if not sm else str(sm)), tree=tree_of(cls, r['id']),
                 learnedFrom=r['learnedFrom'], requires=r['req'] or None,
                 advice=a['advice'], reason_en=a.get('reason_en'), reason_de=a.get('reason_de'),
                 role=a.get('role'), roles=a.get('roles'), verified='forever')
        out.append(e)
    blocks[cls] = out

ORDER = ['id', 'name', 'rank', 'level', 'cost', 'school', 'tree', 'learnedFrom', 'requires', 'advice',
         'reason_en', 'reason_de', 'role', 'roles', 'verified']
L = ['-- Generated by tools/trainerdata/build_trainer_spells.py - do not edit by hand (edit advice/<CLASS>.json).',
     '-- Research data (not loaded by the addon yet). Format: see tools/trainerdata/README.md.',
     '-- Spell data: WoW Forever client 1.60.1.70938 (wago.tools) + trainer list/costs from the WhatsTraining',
     '-- forever branch. Costs are base prices in copper before reputation discount.',
     'local TRAINER_SPELLS = {']
for cls in CLASSES:
    if cls not in blocks:
        continue
    L.append('    %s = {' % cls)
    for e in blocks[cls]:
        L.append('        { ' + ', '.join('%s = %s' % (k, lua(e[k])) for k in ORDER if e.get(k) is not None) + ' },')
    L.append('    },')
L.append('}')
L.append('')
L.append('return TRAINER_SPELLS')
(HERE / 'TrainerSpells.lua').write_text('\n'.join(L) + '\n', encoding='utf-8')
for cls, names in missing_advice.items():
    checks.append(f'{cls}: no advice for: ' + ', '.join(sorted(names)))
(HERE / 'checks.txt').write_text('# Generated by build_trainer_spells.py: differences between sources and missing data\n'
                                 + '\n'.join(checks) + '\n', encoding='utf-8')

# ---------------------------------------------------------------- LearningOrder.md and SOURCES.md (per class part)
NICE = {c: c.capitalize() for c in CLASSES}
lo = ['# Leveling plan per class (WoW Forever)', '',
      'What to buy at the trainer while leveling 1-60, what to skip, and money tips. Generated from',
      '`advice/<CLASS>.json` by `build_trainer_spells.py`; the per-spell marks are in `TrainerSpells.lua`.',
      'Default viewpoint: solo leveling. Costs: see `TrainerSpells.lua` (base price, before reputation discount).', '']
src_parts = []
for cls in CLASSES:
    af = HERE / 'advice' / f'{cls}.json'
    if not af.exists():
        continue
    adv = json.loads(af.read_text(encoding='utf-8'))
    sold = [e for e in blocks[cls] if e['learnedFrom'] in ('trainer', 'talent')]
    total = sum(e['cost'] or 0 for e in sold)
    rec = sum(e['cost'] or 0 for e in sold if e['advice'] == 'recommended')
    skip = sum(e['cost'] or 0 for e in sold if e['advice'] == 'skip')
    def g(c):
        return '%dg %02ds' % (c // 10000, (c // 100) % 100)
    lo += ['## %s' % NICE[cls], '',
           '_All class trainer ranks 1-60: %s. Marked recommended: %s. Marked skip: %s._' % (g(total), g(rec), g(skip)), '',
           adv['learning_order'].strip(), '']
    src_parts += ['## %s' % NICE[cls], '', 'Leveling advice sources (read %s):' % ', '.join(sorted({x.get('checked', '') for x in adv['sources']})), '']
    src_parts += ['- [%s](%s) (%s)' % (x['title'], x['url'], x['kind']) for x in adv['sources']]
    for title, key in (('Forever differences that matter for training', 'forever_differences'),
                       ('Guide disagreements', 'disagreements'), ('Open questions', 'open_questions')):
        if adv.get(key):
            src_parts += ['', '**%s**' % title, ''] + ['- ' + x for x in adv[key]]
    src_parts.append('')
(HERE / 'LearningOrder.md').write_text('\n'.join(lo), encoding='utf-8')
tpl = (HERE / 'SOURCES.template.md').read_text(encoding='utf-8')
(HERE / 'SOURCES.md').write_text(tpl.replace('<!-- CLASSES -->', '\n'.join(src_parts).rstrip() + '\n'), encoding='utf-8')
print({c: len(v) for c, v in blocks.items()}, len(checks), 'check notes')
