#!/usr/bin/env python3
"""Write the addon's compact trainer data (Data/TrainerData.lua) from TrainerSpells.lua and ClassQuests.lua.
One function per class, so the game only builds the player's own class table.
usage: python3 -I tools/trainerdata/export_addon.py"""
import pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from lualit import tokenize, P  # noqa: E402


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

OUT = HERE.parent.parent / 'Data' / 'TrainerData.lua'
ADVICE = {'recommended': 'r', 'optional': 'o', 'skip': 's'}


def lua(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'
    if isinstance(v, list):
        return '{' + ','.join(lua(x) for x in v) + '}'
    if isinstance(v, dict):
        return '{' + ','.join('%s=%s' % (k, lua(x)) for k, x in v.items()) + '}'
    raise TypeError(v)


def ids(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return [int(v)]
    return [int(x) for x in lst(v)]


def clean(text):
    """Players see this in Forever anyway: drop the "in Forever" notes the research added for Classic."""
    for pat in ('Forever-Guides: ', 'Forever guides: ', 'Forever: '):
        if text.startswith(pat):
            text = text[len(pat):]
    text = re.sub(r'\bIn Forever ([a-zäöü])', lambda m: m.group(1).upper(), text)
    text = text.replace('In Forever ', '').replace(' in Forever', '').replace('in Forever ', '')
    text = text.strip()
    text = text[:1].upper() + text[1:]
    return REWORD.get(text, text)


# Reasons that still compare with Classic ("now", "buffed", "cheaper" ...): plain wording for Forever players
REWORD = {
    "AoE builds only; slow nerfed": "AoE builds only; weak slow",
    "Baseline at 20; main single-target shot": "Main single-target shot",
    "Baseline instant damage; costs health if target lives": "Instant damage; costs health if target lives",
    "Baseline; Spirit buff for mana regen": "Spirit buff for mana regen",
    "Better mana regen (buffed); swap for long fights": "Better mana regen; swap for long fights",
    "Big Cat opener from behind; buffed": "Big Cat opener from behind",
    "Big tank cooldown, now 15 min": "Big tank cooldown, 15 min",
    "Buffed; worth it on long or boss fights": "Worth it on long or boss fights",
    "Cheaper; good self-heal between pulls": "Good self-heal between pulls",
    "Escape tool, now usable in forms and indoors": "Escape tool, usable in forms and indoors",
    "Free passive procs, now baseline": "Free passive procs",
    "Full heal, now 20 min cooldown": "Full heal, 20 min cooldown",
    "Improved version is baseline: more damage for you and pet": "More damage for you and your pet",
    "Now a weapon imbue (Fire dmg, crit); good for Destro": "Weapon imbue (Fire damage, crit); good for Destruction",
    "Now a weapon imbue (Shadow dmg, haste); for Shadow Bolt users": "Weapon imbue (Shadow damage, haste); for Shadow Bolt",
    "Now baseline and cheap; DoT that heals you": "Cheap DoT that heals you",
    "Now baseline and cheap; vs fearing mobs": "Cheap; against mobs that fear",
    "Now stacks with Banes; Classic guides skip it": "Stacks with Banes; optional",
    "Racial; damage buffed a lot, cheap ranks": "Racial; strong damage, cheap ranks",
    "Threat drop doubled; helps in groups": "Big threat drop; helps in groups",
    "Bedrohungssenkung verdoppelt; gut in Gruppen": "Starke Bedrohungssenkung; gut in Gruppen",
    "Bessere Manaregeneration (gestärkt); für lange Kämpfe": "Bessere Manaregeneration; für lange Kämpfe",
    "Billiger; gute Selbstheilung zwischen Kämpfen": "Gute Selbstheilung zwischen Kämpfen",
    "Effiziente Blutung; skaliert jetzt mit AP": "Effiziente Blutung; skaliert mit Angriffskraft",
    "Fallen gehen jetzt im Kampf; gut für Überleben/AoE": "Fallen gehen im Kampf; gut für Überleben/AoE",
    "Fluchthilfe, jetzt in Gestalten und drinnen nutzbar": "Fluchthilfe, in Gestalten und drinnen nutzbar",
    "Für alle; Sofortschaden, kostet Leben wenn Ziel überlebt": "Sofortschaden; kostet Leben, wenn das Ziel überlebt",
    "Für alle; Willenskraft für Manaregeneration": "Willenskraft für Manaregeneration",
    "Gratis passive Procs, jetzt Grundfähigkeit": "Gratis passive Procs",
    "Großer Tank-Cooldown, jetzt 15 Min.": "Großer Tank-Cooldown, 15 Min.",
    "Harte Kontrolle für Adds; jetzt im Kampf nutzbar": "Harte Kontrolle für Adds; im Kampf nutzbar",
    "Jetzt Waffenverzauberung (Feuer, Krit); gut für Zerstörung": "Waffenverzauberung (Feuer, Krit); gut für Zerstörung",
    "Jetzt Waffenverzauberung (Schatten, Tempo); für Schattenblitz": "Waffenverzauberung (Schatten, Tempo); für Schattenblitz",
    "Jetzt für alle und billig; DoT, der dich heilt": "Billiger DoT, der dich heilt",
    "Jetzt für alle und billig; gegen Furcht-Gegner": "Billig; gegen Gegner, die fürchten",
    "Läuft jetzt neben Banen; Classic-Guides lassen ihn aus": "Läuft neben Banen; optional",
    "Nur für Flächen-Skillung; Verlangsamung schwächer": "Nur für Flächen-Skillung; schwache Verlangsamung",
    "Starker Katzen-Eröffner von hinten; gestärkt": "Starker Katzen-Eröffner von hinten",
    "Stärker; lohnt bei langen/Boss-Kämpfen": "Lohnt bei langen/Boss-Kämpfen",
    "Volksfähigkeit; viel stärker, billige Ränge": "Volksfähigkeit; starker Schaden, billige Ränge",
    "Volle Heilung, jetzt 20 Min. Abklingzeit": "Volle Heilung, 20 Min. Abklingzeit",
    "Dämonologie mit Talent; Classic-Guides lassen ihn aus": "Nur für Dämonologie mit Talent; beim Leveln unnötig",
    "Verbrennt dich mit; Classic-Guides lassen ihn aus": "Verbrennt dich mit; beim Leveln unnötig",
    "Burns you too; Classic guides skip it for leveling": "Burns you too; not needed for leveling",
    "Demonology with Decimation; Classic guides skip it": "Demonology with Decimation only; not needed for leveling",
}


def spell(s):
    req = s.get('requires') or {}
    out = {'id': int(s['id']), 'lv': int(s['level'])}
    if s.get('rank'):
        out['rk'] = int(s['rank'])
    if s.get('cost'):
        out['c'] = int(s['cost'])
    if s.get('learnedFrom', 'trainer') != 'trainer':
        out['f'] = s['learnedFrom']
    for key, short in (('spell', 'req'), ('quest', 'q'), ('races', 'ra')):
        if req.get(key) is not None:
            out[short] = ids(req[key])
    if req.get('talent') is not None:
        out['t'] = ids(req['talent'])
    if req.get('faction'):
        out['fa'] = req['faction']
    if s.get('advice'):
        out['a'] = ADVICE[s['advice']]
        out['en'] = clean(s.get('reason_en', ''))
        out['de'] = clean(s.get('reason_de', ''))
    roles = s.get('roles')
    if isinstance(roles, dict) and roles:
        out['ro'] = {k: {'a': ADVICE[v['advice']], 'en': clean(v.get('reason_en', '')), 'de': clean(v.get('reason_de', ''))}
                     for k, v in roles.items() if isinstance(v, dict) and v.get('advice')}
    return out


def start(st):
    if not isinstance(st, dict):
        return None
    out = {}
    if st.get('npc_en'):
        out['en'] = st['npc_en']
    if st.get('npc_de') and st.get('npc_de') != st.get('npc_en'):
        out['de'] = st['npc_de']
    if st.get('zone'):
        out['z'] = st['zone']
    return out or None


def quest(q):
    out = {'id': int(q['first']), 'lv': int(q['level']), 'n': q['name'], 'cat': q['category']}
    if q.get('name_de') and q['name_de'] != q['name']:
        out['nde'] = q['name_de']
    if q.get('faction') and q['faction'] != 'both':
        out['fa'] = q['faction']
    if lst(q.get('races')):
        out['ra'] = ids(q['races'])
    out['qs'] = ids(q.get('quests')) or [out['id']]
    if q.get('finals'):
        out['fin'] = ids(q['finals'])
    st = start(q.get('start'))
    if st:
        out['st'] = st
    starts = []
    for s in lst(q.get('starts')):
        e = {'lv': int(s.get('level', q['level']))}
        if lst(s.get('races')):
            e['ra'] = ids(s['races'])
        st2 = start(s.get('start'))
        if st2:
            e['st'] = st2
        starts.append(e)
    if starts:
        out['sts'] = starts
    spells = [int(u['id']) for u in lst(q.get('unlocks')) if u.get('type') == 'spell']
    if spells:
        out['sp'] = spells
    if q.get('required'):
        out['req'] = True
    return out


def main():
    spells = parse('TrainerSpells.lua', 'TRAINER_SPELLS')
    quests = parse('ClassQuests.lua', 'CLASS_QUESTS')
    lines = [
        '-- Generated by tools/trainerdata/export_addon.py from the trainer research data - do not edit by hand.',
        '-- Per class: trainer spell ranks with leveling advice (a = r recommended / o optional / s skip) and the',
        '-- class quest chains. A function per class: only the player\'s own class table gets built.',
        'local _, ns = ...',
        'ns.TrainerData = {',
    ]
    for cls in sorted(spells):
        sp = [spell(s) for s in lst(spells[cls]) if s.get('learnedFrom') != 'pettrainer']
        qs = [quest(q) for q in lst(quests.get(cls)) if q.get('category') != 'endgame']  # 55+ chains: not shown
        lines.append('    %s = function() return {' % cls)
        lines.append('        spells = {')
        lines += ['            %s,' % lua(s) for s in sp]
        lines.append('        },')
        lines.append('        quests = {')
        lines += ['            %s,' % lua(q) for q in qs]
        lines.append('        },')
        lines.append('    } end,')
    lines.append('}')
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(OUT, OUT.stat().st_size, 'bytes')


if __name__ == '__main__':
    main()
