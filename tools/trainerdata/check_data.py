#!/usr/bin/env python3
"""Parse TrainerSpells.lua and ClassQuests.lua with the tiny Lua literal parser (tools/lualit.py) and check the
format described in README.md. usage: python3 -I tools/trainerdata/check_data.py"""
import pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from lualit import tokenize, P  # noqa: E402

ADVICE = {'recommended', 'optional', 'skip'}
ROLES = {'tank', 'heal', 'dps'}
FROM = {'trainer', 'quest', 'talent', 'pettrainer'}
errors = []


def parse(fname, var):
    src = (HERE / fname).read_text(encoding='utf-8')
    i = src.index('local %s = {' % var) + len('local %s = ' % var)
    p = P(tokenize(src[i:src.index('\nreturn ' + var)]), {})
    p.expect('{')
    return p.table()


def lst(t):
    if isinstance(t, dict):
        return [t[k] for k in sorted(k for k in t if isinstance(k, int))]
    return t or []


def utf8_len(s):
    return len(s) if isinstance(s, str) else 0


ts = parse('TrainerSpells.lua', 'TRAINER_SPELLS')
for cls, rows in ts.items():
    seen = set()
    for e in lst(rows):
        tag = '%s %s' % (cls, e.get('id'))
        for k in ('id', 'name', 'level', 'cost', 'school', 'tree', 'learnedFrom', 'advice', 'reason_en', 'reason_de', 'verified'):
            if e.get(k) is None:
                errors.append(tag + ': missing ' + k)
        if e.get('id') in seen:
            errors.append(tag + ': duplicate id')
        seen.add(e.get('id'))
        if e.get('advice') not in ADVICE:
            errors.append(tag + ': bad advice %r' % e.get('advice'))
        if e.get('role') and e['role'] not in ROLES:
            errors.append(tag + ': bad role %r' % e.get('role'))
        for r, o in (e.get('roles') or {}).items():
            if r not in ROLES or o.get('advice') not in ADVICE:
                errors.append(tag + ': bad roles entry %r' % r)
        if e.get('learnedFrom') not in FROM:
            errors.append(tag + ': bad learnedFrom')
        if not (1 <= (e.get('level') or 0) <= 60):
            errors.append(tag + ': bad level')
        for k in ('reason_en', 'reason_de'):
            if utf8_len(e.get(k)) > 90:
                errors.append(tag + ': %s too long (%d)' % (k, utf8_len(e.get(k))))
        if e.get('verified') not in ('forever', 'classic_era'):
            errors.append(tag + ': bad verified')
    print(cls, len(lst(rows)), 'spells')

cq = parse('ClassQuests.lua', 'CLASS_QUESTS')
for cls, rows in cq.items():
    for e in lst(rows):
        tag = '%s quest %s' % (cls, e.get('first'))
        for k in ('first', 'name', 'level', 'category', 'faction', 'quests', 'finals', 'required', 'verified'):
            if e.get(k) is None:
                errors.append(tag + ': missing ' + k)
        if e.get('first') not in lst(e.get('quests')):
            errors.append(tag + ': first not in quests')
    print(cls, len(lst(rows)), 'quest chains')

print('\n'.join(errors) if errors else 'OK')
sys.exit(1 if errors else 0)
