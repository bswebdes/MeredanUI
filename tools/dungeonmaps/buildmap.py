"""Game-data dungeon maps for every floor of an instance, in Blizzard's floor regions (pins stay valid).
WMO minimap tiles (Forever build), floor membership from UiMapAssignment.WMOGroupID (classic), fallback by
region/height; ADT minimap terrain only on floors Blizzard assigns by area (outdoor parts).
usage: PYTHONPATH=../pylib python3 buildmap.py <instanceID> [<instanceID> ...]
out: maps/<inst>_<floor>.png (1536x1024 RGBA, transparent outside the dungeon)"""
import sys, os, re, csv, json, struct, math, subprocess, pathlib
from concurrent.futures import ThreadPoolExecutor
import numpy as np
from PIL import Image, ImageFilter

BUILD = "1.60.1.70862"; TILE = 1600.0 / 3.0; CH = TILE / 16; OUTW, OUTH = 1536, 1024
HERE = pathlib.Path(__file__).resolve().parent
src = (HERE / 'wmomap.py').read_text().replace('\nmain()\n', '\n'); _W = {}; exec(compile(src, 'w', 'exec'), _W)
decode_blp = _W['decode_blp']
os.makedirs('maps', exist_ok=True); os.makedirs('cache', exist_ok=True)

def get(fdid):
    p = f'cache/{fdid}.bin'
    if not os.path.exists(p) or os.path.getsize(p) == 0:
        subprocess.run(['curl', '-s', '-A', 'MeredanUI', '-o', p, f'https://wago.tools/api/casc/{fdid}?version={BUILD}'])
    return open(p, 'rb').read()

def chunks(b, o=0, end=None, multi=False):
    end = end or len(b); out = {}
    while o + 8 <= end:
        t = b[o:o + 4][::-1].decode('latin1'); n = struct.unpack('<I', b[o + 4:o + 8])[0]
        if multi: out.setdefault(t, []).append((o + 8, n))
        else: out.setdefault(t, b[o + 8:o + 8 + n])
        o += 8 + n
    return out

def blp_np(fdid):
    b = get(fdid)
    if b[:4] != b'BLP2':   # failed/partial download: retry once, else leave the tile empty
        os.remove(f'cache/{fdid}.bin'); b = get(fdid)
        if b[:4] != b'BLP2':
            print('  tile missing', fdid, b[:60], flush=True); return np.zeros((256, 256, 4), np.uint8)
    w, h, px = decode_blp(b)
    return np.frombuffer(bytes(px), np.uint8).reshape(h, w, 4)

MAPS = {int(r['ID']): r for r in csv.DictReader(open('ej/Map.csv', encoding='utf-8'))}
MMT = {}
for r in csv.DictReader(open('ej/WMOMinimapTexture.csv')):
    MMT.setdefault(int(r['WMOID']), {}).setdefault(int(r['GroupNum']), []).append((int(r['BlockX']), int(r['BlockY']), int(r['FileDataID'])))
UIA = list(csv.DictReader(open('ej/UiMapAssignment.csv')))
AREAS = list(csv.DictReader(open('ej/Area.csv', encoding='utf-8')))
lua = (HERE.parents[1] / 'Map' / 'DungeonMapData.lua').read_text(encoding='utf-8')
FLOORS = {}
for m in re.finditer(r'^    \[(\d+)\] = \{(.*?)^    \},', lua, re.M | re.S):
    FLOORS[int(m.group(1))] = [dict(ui=int(u), en=n, region=[float(x) for x in r.split(',')])
                               for u, n, r in re.findall(r'ui = (\d+), en = "(.*?)".*?region = \{ ([-\d., ]+) \}', m.group(2))]

def build(inst):
    wdtid = int(MAPS[inst]['WdtFileDataID']); wdt = get(wdtid); wc = chunks(wdt)
    O = 0.0 if 'MODF' in wc else 17066.666   # WDT-global WMO: placement = -world, ADT maps: offset origin
    placements = {}
    def modf(m):
        for i in range(len(m) // 64):
            e = m[i * 64:(i + 1) * 64]; nameId, uid = struct.unpack('<II', e[:8])
            placements[uid] = dict(fdid=nameId, pos=struct.unpack('<3f', e[8:20]), rot=struct.unpack('<3f', e[20:32]))
    if 'MODF' in wc: modf(wc['MODF'])
    adts = []
    if 'MAID' in wc:
        maid = wc['MAID']
        for i in range(4096):
            v = struct.unpack('<8I', maid[i * 32:(i + 1) * 32])
            if v[0]:
                adts.append((i % 64, i // 64, v[0], v[7]))
                if v[1]:
                    c = chunks(get(v[1]))
                    if 'MODF' in c: modf(c['MODF'])
    if os.environ.get('NOADT'): adts = []   # WMO-only look (terrain tiles missing/unwanted)
    # WMOs with minimap tiles, their groups (uniqueID, world z centre, local image)
    wmos = []
    for uid, p in placements.items():
        root = get(p['fdid']); rc = chunks(root)
        if 'MOHD' not in rc: continue
        n = struct.unpack('<I', rc['MOHD'][4:8])[0]; wid = struct.unpack('<I', rc['MOHD'][32:36])[0]
        tiles = MMT.get(wid)
        if not tiles: continue
        mogi = [struct.unpack('<I6f', rc['MOGI'][i * 32:i * 32 + 28]) for i in range(n)]; gb = [m[1:] for m in mogi]
        gf = struct.unpack(f'<{len(rc["GFID"]) // 4}I', rc['GFID']) if 'GFID' in rc else []
        with ThreadPoolExecutor(8) as ex: list(ex.map(get, [gf[i] for i in tiles if i < len(gf)]))
        minx = min(int(b[0] * 2) for b in gb); miny = min(int(b[1] * 2) for b in gb)
        resy = max(int(b[4] * 2) for b in gb) - miny
        groups = []
        for gi, t in tiles.items():
            if gi >= n: continue
            gid = 0
            if gi < len(gf):
                g = get(gf[gi]); k = g.find(b'PGOM')
                if k >= 0: gid = struct.unpack('<I', g[k + 8 + 56:k + 8 + 60])[0]
            mnx = min(a[0] for a in t); mxx = max(a[0] for a in t); mny = min(a[1] for a in t); mxy = max(a[1] for a in t)
            dec = {(bx, by): blp_np(f) for bx, by, f in t}
            if mnx == mxx == mny == mxy == 0:
                img = dec[(0, 0)]
            else:
                img = np.zeros(((mxy - mny) * 256 + 256, (mxx - mnx) * 256 + 256, 4), np.uint8)
                for (bx, by), a in dec.items():
                    y0 = (mxy - (by - mny)) * 256; x0 = (bx - mnx) * 256
                    img[y0:y0 + a.shape[0], x0:x0 + a.shape[1]] = a
            gh, gw = img.shape[:2]; bb = gb[gi]
            x1, y1, x2, y2 = int(bb[0] * 2) - minx, int(bb[1] * 2) - miny, int(bb[3] * 2) - minx, int(bb[4] * 2) - miny
            hh = y2 - y1; sy0 = gh - hh   # bottom-aligned like Marlamin's compositor
            cw = min(x2 - x1, gw)
            ty0 = resy - y2
            if sy0 < 0: ty0 -= sy0; hh += sy0; sy0 = 0
            sub = img[sy0:sy0 + hh, :cw]
            zc = p['pos'][1] + (bb[2] + bb[5]) / 2
            cx, cy = (bb[0] + bb[3]) / 2, (bb[1] + bb[4]) / 2
            groups.append(dict(ext=bool(mogi[gi][0] & 0x8), bb=bb, gi=gi, gid=gid, z=zc, img=sub, col0=x1, row0=ty0, lc=(cx, cy), zr=(p['pos'][1] + bb[2], p['pos'][1] + bb[5])))
        wmos.append(dict(p=p, minx=minx, miny=miny, resy=resy, groups=groups))
    skip = {int(v) for v in os.environ.get('SKIP', '').split(',') if v}   # group indices to leave out
    if skip:
        for w in wmos: w['groups'] = [g for g in w['groups'] if g['gi'] not in skip]
    if os.environ.get('MAINWMO'):   # only the instance's own WMO (drops pieces of a neighbouring city WMO)
        wmos = [max(wmos, key=lambda w: len(w['groups']))]
    # floor membership
    floors = FLOORS.get(inst)   # None: new instance without a Blizzard map -> region fitted below
    uim = {}
    for r in UIA:
        if int(r['MapID']) == inst:
            uim.setdefault(int(r['UiMapID']), []).append(r)
    def to_world(p, lx, ly, z=0):
        th = math.radians(p['rot'][1]); c, s = math.cos(th), math.sin(th)
        vx, vz = ly, lx
        px = p['pos'][0] + vx * c + vz * s; pz = p['pos'][2] - vx * s + vz * c
        return O - pz, O - px          # world X, world Y
    allg = []
    for w in wmos:
        for g in w['groups']:
            bb = g['bb']; cs = [to_world(w['p'], x, y) for x in (bb[0], bb[3]) for y in (bb[1], bb[4])]
            g['wb'] = (min(c[0] for c in cs), min(c[1] for c in cs), max(c[0] for c in cs), max(c[1] for c in cs))
            allg.append(g)
    if floors is None:   # one floor, 3:2 region around all groups with a margin
        x0 = min(g['wb'][0] for g in allg); y0 = min(g['wb'][1] for g in allg)
        x1 = max(g['wb'][2] for g in allg); y1 = max(g['wb'][3] for g in allg)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        hx, hy = (x1 - x0) / 2 * 1.08, (y1 - y0) / 2 * 1.08
        if hy < hx * 1.5: hy = hx * 1.5
        else: hx = hy / 1.5
        floors = [dict(ui=0, en=None, region=[cx - hx, cy - hy, -100000.0, cx + hx, cy + hy, 100000.0])]
        print(f'{inst} fitted region:', ', '.join(f'{v:.1f}' for v in floors[0]['region']), flush=True)
    def ov(a, b):   # overlap of two world XY boxes relative to the smaller one
        ix = max(0, min(a[2], b[2]) - max(a[0], b[0])); iy = max(0, min(a[3], b[3]) - max(a[1], b[1]))
        sa = max(1e-6, min((a[2] - a[0]) * (a[3] - a[1]), (b[2] - b[0]) * (b[3] - b[1])))
        return ix * iy / sa
    for w in wmos:
        for g in w['groups']:
            g['floors'] = {f['ui'] for f in floors if any(int(r['WMOGroupID']) == g['gid'] and g['gid'] for r in uim.get(f['ui'], []))}
            if not g['floors']:   # fallback: smallest floor region holding the group's centre at its height
                wx, wy = to_world(w['p'], *g['lc'])
                cand = [f for f in floors if f['region'][0] <= wx <= f['region'][3] and f['region'][1] <= wy <= f['region'][4]
                        and f['region'][2] <= g['zr'][1] and g['zr'][0] <= f['region'][5]]
                if cand:
                    best = min(cand, key=lambda f: (f['region'][3] - f['region'][0]) * (f['region'][4] - f['region'][1]))
                    g['floors'] = {best['ui']}
    # fill-in: each floor also shows groups of other floors inside its region that don't stack over/under its own
    for f in floors:
        # stacked floors (same region as another floor) show only their own parts
        if any(o is not f and [round(v) for v in o['region'][:2] + o['region'][3:5]] == [round(v) for v in f['region'][:2] + f['region'][3:5]] for o in floors):
            continue
        own = [g for g in allg if f['ui'] in g['floors']]
        x0w, y0w, z0, x1w, y1w, z1 = f['region']
        for g in allg:
            if f['ui'] in g['floors'] or g.get('fill', set()) & {f['ui']}: continue
            b = g['wb']
            if b[2] < x0w or b[0] > x1w or b[3] < y0w or b[1] > y1w: continue
            if g['zr'][1] < z0 or g['zr'][0] > z1: continue
            if own:   # same height band as the floor's own parts only (no pieces of other storeys)
                lo = min(o['zr'][0] for o in own); hi = max(o['zr'][1] for o in own)
                if min(g['zr'][1], hi) - max(g['zr'][0], lo) < 0.5 * max(1.0, g['zr'][1] - g['zr'][0]): continue
            if not any(ov(b, o['wb']) >= 0.15 for o in own):
                g.setdefault('fill', set()).add(f['ui'])
    for g in allg: g['floors'] = g['floors'] | g.get('fill', set())
    # instance areas for the terrain mask
    ids = {int(a['ID']) for a in AREAS if a['ContinentID'] == str(inst)}
    results = []
    for fi, f in enumerate(floors, 1):
        x0w, y0w, z0, x1w, y1w, z1 = f['region']
        vv, uu = np.mgrid[0:OUTH, 0:OUTW].astype(np.float32)
        WY = y1w - (uu + 0.5) / OUTW * (y1w - y0w); WX = x1w - (vv + 0.5) / OUTH * (x1w - x0w)
        PX = O - WY; PZ = O - WX
        out = np.zeros((OUTH, OUTW, 4), np.uint8)
        rows = uim.get(f['ui'], [])
        own_ext = any(g['ext'] for w in wmos for g in w['groups'] if f['ui'] in g['floors'])
        use_adt = adts and (any(r['WMOGroupID'] == '0' for r in rows) or not rows or own_ext)
        if use_adt:
            cells = np.zeros((OUTH, OUTW), bool)
            for tx, ty, root_fd, mm_fd in adts:
                ax, az = tx * TILE, ty * TILE
                m = (PX >= ax) & (PX < ax + TILE) & (PZ >= az) & (PZ < az + TILE)
                if not m.any(): continue
                if mm_fd:
                    t = blp_np(mm_fd); th_, tw_ = t.shape[:2]
                    sx = ((PX[m] - ax) / TILE * tw_).astype(int).clip(0, tw_ - 1); sy = ((PZ[m] - az) / TILE * th_).astype(int).clip(0, th_ - 1)
                    out[m] = t[sy, sx]; out[m, 3] = 0
                # chunk area ids -> which terrain belongs to the instance
                data = get(root_fd); o = 0; amap = np.zeros((16, 16), np.int64)
                while o + 8 <= len(data):
                    tg = data[o:o + 4][::-1].decode('latin1'); n = struct.unpack('<I', data[o + 4:o + 8])[0]
                    if tg == 'MCNK':
                        ix, iy = struct.unpack('<II', data[o + 12:o + 20]); amap[iy, ix] = struct.unpack('<I', data[o + 8 + 0x34:o + 8 + 0x38])[0]
                    o += 8 + n
                cx = ((PX[m] - ax) / CH).astype(int).clip(0, 15); cz = ((PZ[m] - az) / CH).astype(int).clip(0, 15)
                inside = np.isin(amap[cz, cx], list(ids)) if ids else np.ones(m.sum(), bool)
                cells[np.nonzero(m)[0][inside], np.nonzero(m)[1][inside]] = True
            tcells = cells
        else:
            tcells = None
        drawn = []
        for w in wmos:
            p = w['p']; th = math.radians(p['rot'][1]); c, s = math.cos(th), math.sin(th)
            dx, dz = PX - p['pos'][0], PZ - p['pos'][2]
            lyv = dx * c - dz * s; lxv = dx * s + dz * c
            col = np.floor(lxv * 2).astype(np.int32) - w['minx']; row = w['resy'] - (np.floor(lyv * 2).astype(np.int32) - w['miny'])
            for g in w['groups']:
                if f['ui'] in g['floors']: drawn.append((g['z'], g, col, row))
        for _, g, col, row in sorted(drawn, key=lambda t: t[0]):
            cc = col - g['col0']; rr = row - g['row0']; h, wd = g['img'].shape[:2]
            m = (cc >= 0) & (cc < wd) & (rr >= 0) & (rr < h)
            if not m.any(): continue
            px = g['img'][rr[m], cc[m]]; a = px[:, 3] > 30
            idx = np.nonzero(m); sel = (idx[0][a], idx[1][a])
            out[sel] = px[a]; out[sel[0], sel[1], 3] = 255
        if tcells is not None:   # terrain only around this floor's buildings (instance areas often cover the whole map)
            wm = out[..., 3] == 255
            area_floor = any(r['WMOGroupID'] == '0' for r in rows) or not rows   # Blizzard maps this floor by area: outdoor instance
            if wm.sum() > 2000 and not area_floor:
                near = np.asarray(Image.fromarray((wm * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(61))) > 0
                tcells = tcells & near
            t = tcells & ~wm; out[t, 3] = 255
            out[~(wm | t), 3] = 0
        path = f'maps/{inst}_{fi}.png'; Image.fromarray(out, 'RGBA').save(path)
        results.append((fi, f['en'], int((out[..., 3] > 0).sum()), len(drawn), bool(use_adt)))
    json.dump({'O': O}, open(f'maps/{inst}.json', 'w'))
    return results

for a in sys.argv[1:]:
    inst = int(a)
    try:
        for fi, name, px, ng, adt in build(inst):
            print(f'{inst} {fi} {name}: {px} px, {ng} groups{", terrain" if adt else ""}', flush=True)
    except Exception as e:
        import traceback; traceback.print_exc(); print(f'{inst} FEHLER {e}', flush=True)
