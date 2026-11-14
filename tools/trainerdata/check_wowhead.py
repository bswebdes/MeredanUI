#!/usr/bin/env python3
"""Spot-check spell IDs in TrainerSpells.lua against Wowhead Forever tooltips (name + "Requires level N").
Polite: one request at a time with a pause. Appends results to wowhead_check.txt.
usage: python3 -I tools/trainerdata/check_wowhead.py <CLASS> [samples=12]"""
import json, pathlib, random, re, sys, time, urllib.request

HERE = pathlib.Path(__file__).resolve().parent
cls = sys.argv[1]
k = int(sys.argv[2]) if len(sys.argv) > 2 else 12
src = (HERE / 'TrainerSpells.lua').read_text(encoding='utf-8')
block = re.search(r'\n    %s = \{\n(.*?)\n    \},' % cls, src, re.S).group(1)
rows = [(int(m.group(1)), m.group(2), int(m.group(3)))
        for m in re.finditer(r'\{ id = (\d+), name = "([^"]+)",.*?level = (\d+),', block)]
random.seed(cls)
sample = random.sample(rows, min(k, len(rows)))
lines = []
for sid, name, level in sorted(sample):
    url = 'https://nether.wowhead.com/forever/tooltip/spell/%d?locale=0' % sid
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'addon-research/1.0'})
        with urllib.request.urlopen(req, timeout=20) as r:
            d = json.loads(r.read().decode('utf-8'))
        m = re.search(r'Requires level (\d+)', d.get('tooltip', ''))
        wl = int(m.group(1)) if m else None
        ok = d.get('name') == name and (wl is None or wl == level)
        lines.append('%s %d %s L%d -> wowhead "%s" L%s %s' % (cls, sid, name, level, d.get('name'), wl, 'OK' if ok else 'MISMATCH'))
    except Exception as e:  # network errors are reported, not fatal
        lines.append('%s %d %s -> error %s' % (cls, sid, name, e))
    time.sleep(1.0)
with open(HERE / 'wowhead_check.txt', 'a', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')
print('\n'.join(lines))
