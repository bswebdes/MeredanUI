#!/usr/bin/env python3
"""Analyze a Forever instance: ADT minimap tiles, placed WMOs with minimap tiles, floor clusters.
usage: analyze.py <instanceMapID> <wdtFDID> <outdir>"""
import struct, subprocess, os, csv, json, sys

BUILD = "1.60.1.70862"
inst, wdt, out = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)

def get(fdid):
    p = os.path.join(out, f"{fdid}.bin")
    if not os.path.exists(p):
        subprocess.run(['curl', '-s', '-A', 'MeredanUI', '-o', p, f'https://wago.tools/api/casc/{fdid}?version={BUILD}'])
    return open(p, 'rb').read()

def chunks(d, first=True):
    o, c = 0, {}
    while o + 8 <= len(d):
        tag = d[o:o + 4][::-1].decode('latin1'); size = struct.unpack('<I', d[o + 4:o + 8])[0]
        if first: c.setdefault(tag, d[o + 8:o + 8 + size])
        else: c.setdefault(tag, []).append(d[o + 8:o + 8 + size])
        o += 8 + size
    return c

w = chunks(get(wdt))
flags = struct.unpack('<I', w['MPHD'][:4])[0]
adts, placements = [], {}
def modf(m):
    for i in range(len(m) // 64):
        e = m[i * 64:(i + 1) * 64]
        nameId, uid = struct.unpack('<II', e[:8])
        placements[uid] = dict(fdid=nameId, pos=struct.unpack('<3f', e[8:20]), rot=struct.unpack('<3f', e[20:32]),
                               bb=struct.unpack('<6f', e[32:56]))
if 'MODF' in w: modf(w['MODF'])
if 'MAID' in w:
    maid = w['MAID']
    for i in range(4096):
        v = struct.unpack('<8I', maid[i * 32:(i + 1) * 32])
        if any(v):
            adts.append((i % 64, i // 64, v[7]))
            if v[1]:
                c = chunks(get(v[1]))
                if 'MODF' in c: modf(c['MODF'])
mm = {}
for r in csv.DictReader(open(os.path.join(os.path.dirname(__file__), 'ej/WMOMinimapTexture.csv'))):
    mm.setdefault(int(r['WMOID']), []).append(r)
wmos = []
for uid, p in placements.items():
    c = chunks(get(p['fdid']))
    if 'MOHD' not in c: continue
    n = struct.unpack('<I', c['MOHD'][4:8])[0]; wid = struct.unpack('<I', c['MOHD'][32:36])[0]
    groups = [struct.unpack('<I6f', c['MOGI'][i * 32:i * 32 + 28]) for i in range(n)]
    tiles = mm.get(wid, [])
    withtiles = sorted({int(t['GroupNum']) for t in tiles})
    wmos.append(dict(uid=uid, fdid=p['fdid'], wmoID=wid, groups=n, tiles=len(tiles), tiled=withtiles, pos=p['pos'], rot=p['rot'],
                     gb=[[round(v, 1) for v in g[1:]] for g in groups]))
wmos.sort(key=lambda x: -x['tiles'])
info = dict(inst=inst, mphd=hex(flags), adt_tiles=len(adts), adt_minimaps=sum(1 for a in adts if a[2]), wmos=wmos, adts=adts)
json.dump(info, open(os.path.join(out, 'info.json'), 'w'))
print(inst, 'MPHD', hex(flags), 'ADT tiles', len(adts), 'with minimap', info['adt_minimaps'])
for x in wmos[:6]:
    zs = [(g[2], g[5]) for i, g in enumerate(x['gb']) if i in x['tiled']]
    print('  WMO', x['fdid'], 'wmoID', x['wmoID'], 'groups', x['groups'], 'tiles', x['tiles'], 'rot', x['rot'],
          'Z ranges', sorted({(round(a), round(b)) for a, b in zs})[:12])
