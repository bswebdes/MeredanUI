#!/usr/bin/env python3
"""World-space map of a Forever instance: ADT minimap tiles + every placed WMO's minimap (rotated).
usage: worldmap.py <dir> <out.png> <scale px/yd> [x1 z1 x2 z2 (placement coords crop)] [zmin zmax (world height filter)]
Placement coords: X/Z on the ground (image right/down), Y up. Transform verified against MODF bounds:
local (x,y,z) -> v = (y, z, x), rotate about Y by rot.y, add pos."""
import struct, sys, os, math, json, subprocess, csv
sys.path.insert(0, os.path.dirname(__file__))
src = open(os.path.join(os.path.dirname(__file__), 'wmomap.py')).read().replace('\nmain()\n', '\n')
W = {}; exec(compile(src, 'wmomap', 'exec'), W)
decode_blp, write_png, blit = W['decode_blp'], W['write_png'], W['blit']
BUILD = "1.60.1.70862"
TILE = 1600.0 / 3.0

d, outpng, s = sys.argv[1], sys.argv[2], float(sys.argv[3])
crop = [float(v) for v in sys.argv[4:8]] if len(sys.argv) >= 8 else None
zf = [float(v) for v in sys.argv[8:10]] if len(sys.argv) >= 10 else None

def get(fdid):
    p = os.path.join(d, f"{fdid}.bin")
    if not os.path.exists(p):
        subprocess.run(['curl', '-s', '-A', 'MeredanUI', '-o', p, f'https://wago.tools/api/casc/{fdid}?version={BUILD}'])
    return open(p, 'rb').read()

def chunks(data):
    o, c = 0, {}
    while o + 8 <= len(data):
        t = data[o:o + 4][::-1].decode('latin1'); n = struct.unpack('<I', data[o + 4:o + 8])[0]
        c.setdefault(t, data[o + 8:o + 8 + n]); o += 8 + n
    return c

info = json.load(open(os.path.join(d, 'info.json')))
# placements with full data (re-read obj ADTs for pos/rot; analyze kept them)
wmos = [w for w in info['wmos'] if w['tiles'] > 0]
mm = {}
for r in csv.DictReader(open(os.path.join(os.path.dirname(__file__), 'ej/WMOMinimapTexture.csv'))):
    mm.setdefault(int(r['WMOID']), []).append((int(r['GroupNum']), int(r['BlockX']), int(r['BlockY']), int(r['FileDataID'])))

def wmo_image(w, zfilter):
    """Marlamin-style local minimap image of one WMO (2 px/yd); groups outside the height band skipped."""
    groups = w['gb']; tiles = {}
    for g, bx, by, f in mm[w['wmoID']]: tiles.setdefault(g, []).append((bx, by, f))
    minx = min(int(b[0] * 2) for b in groups); miny = min(int(b[1] * 2) for b in groups)
    resx = max(int(b[3] * 2) - minx for b in groups); resy = max(int(b[4] * 2) - miny for b in groups)
    img = bytearray(resx * resy * 4)
    for gi, bb in enumerate(groups):
        if gi not in tiles: continue
        if zfilter:
            mid = w['pos'][1] + (bb[2] + bb[5]) / 2  # by group centre: tall shafts would join every floor
            if mid < zfilter[0] or mid > zfilter[1]: continue
        t = tiles[gi]
        mnx = min(a[0] for a in t); mxx = max(a[0] for a in t); mny = min(a[1] for a in t); mxy = max(a[1] for a in t)
        dec = {(bx, by): decode_blp(get(f)) for bx, by, f in t}
        if mnx == mxx == mny == mxy == 0:
            gw, gh, gpx = dec[(0, 0)]
        else:
            gw, gh = (mxx - mnx) * 256 + 256, (mxy - mny) * 256 + 256
            gpx = bytearray(gw * gh * 4)
            for (bx, by), (tw, th, tpx) in dec.items():
                blit(gpx, gw, gh, tpx, tw, th, (bx - mnx) * 256, (mxy - (by - mny)) * 256, tw, th, 0)
        x1, y1, x2, y2 = int(bb[0] * 2) - minx, int(bb[1] * 2) - miny, int(bb[3] * 2) - minx, int(bb[4] * 2) - miny
        blit(img, resx, resy, gpx, gw, gh, x1, resy - y2, x2 - x1, y2 - y1, gh - (y2 - y1))
    return dict(px=img, w=resx, h=resy, minx=minx, miny=miny)

# area
if crop:
    X1, Z1, X2, Z2 = crop
else:
    xs = [a[0] for a in info['adts']]; ys = [a[1] for a in info['adts']]
    X1, Z1, X2, Z2 = min(xs) * TILE, min(ys) * TILE, (max(xs) + 1) * TILE, (max(ys) + 1) * TILE
OW, OH = int((X2 - X1) * s), int((Z2 - Z1) * s)
out = bytearray(OW * OH * 4)
for i in range(OW * OH): out[i * 4:i * 4 + 4] = b'\x10\x12\x12\xff'

# ADT minimap layer (left out for underground floors: NOADT=1)
for tx, ty, f in ([] if os.environ.get('NOADT') else info['adts']):
    if not f: continue
    ax, az = tx * TILE, ty * TILE
    if ax > X2 or az > Z2 or ax + TILE < X1 or az + TILE < Z1: continue
    tw, th, tpx = decode_blp(get(f))
    u0, v0 = int((ax - X1) * s), int((az - Z1) * s); size = TILE * s
    for v in range(max(0, v0), min(OH, int(v0 + size))):
        sy = int((v - v0) / size * th)
        for u in range(max(0, u0), min(OW, int(u0 + size))):
            sx = int((u - u0) / size * tw)
            p = (sy * tw + sx) * 4; q = (v * OW + u) * 4
            out[q:q + 3] = tpx[p:p + 3]; out[q + 3] = 255

wmask = bytearray(OW * OH)
# WMO layer (inverse mapping per output pixel inside the WMO's footprint)
for w in sorted(wmos, key=lambda w: w['tiles']):
    im = wmo_image(w, zf)
    pos, th = w['pos'], math.radians(w['rot'][1]); c, sn = math.cos(th), math.sin(th)
    # footprint in placement coords from local bbox corners
    lb = [min(b[0] for b in w['gb']), min(b[1] for b in w['gb']), max(b[3] for b in w['gb']), max(b[4] for b in w['gb'])]
    pts = []
    for lx in (lb[0], lb[2]):
        for ly in (lb[1], lb[3]):
            vx, vz = ly, lx
            pts.append((pos[0] + vx * c + vz * sn, pos[2] - vx * sn + vz * c))
    fx1, fz1 = min(p[0] for p in pts), min(p[1] for p in pts); fx2, fz2 = max(p[0] for p in pts), max(p[1] for p in pts)
    for v in range(max(0, int((fz1 - Z1) * s)), min(OH, int((fz2 - Z1) * s) + 1)):
        pz = Z1 + v / s
        for u in range(max(0, int((fx1 - X1) * s)), min(OW, int((fx2 - X1) * s) + 1)):
            px = X1 + u / s
            dx, dz = px - pos[0], pz - pos[2]
            vx = dx * c - dz * sn; vz = dx * sn + dz * c
            lx, ly = vz, vx
            col = int(lx * 2) - im['minx']; row = im['h'] - (int(ly * 2) - im['miny'])
            if 0 <= col < im['w'] and 0 <= row < im['h']:
                p = (row * im['w'] + col) * 4
                if im['px'][p + 3] > 30:
                    q = (v * OW + u) * 4; out[q:q + 3] = im['px'][p:p + 3]; out[q + 3] = 255
                    wmask[v * OW + u] = 1
# dim everything outside the dungeon's own areas (terrain chunks tagged with its AreaTable IDs)
cp = os.path.join(d, 'cells.json')
if (os.environ.get('DIM') or os.environ.get('MASK')) and os.path.exists(cp) and not os.environ.get('NOADT'):
    CH = TILE / 16
    inside = bytearray(OW * OH)
    for cx, cz, _ in json.load(open(cp)):
        for v in range(max(0, int((cz - Z1) * s)), min(OH, int((cz + CH - Z1) * s) + 1)):
            for u in range(max(0, int((cx - X1) * s)), min(OW, int((cx + CH - X1) * s) + 1)):
                inside[v * OW + u] = 1
    if os.environ.get('MASK'):
        m = bytearray(OW * OH * 4)
        for i in range(OW * OH):
            if inside[i] or wmask[i]: m[i * 4:i * 4 + 4] = b'\xff\xff\xff\xff'
        write_png(os.environ['MASK'], OW, OH, m)
    for i in range(OW * OH):
        if not os.environ.get('DIM'): break
        if not inside[i]:
            q = i * 4; out[q] = out[q] * 35 // 100; out[q + 1] = out[q + 1] * 35 // 100; out[q + 2] = out[q + 2] * 35 // 100
if os.environ.get('MASK') and (os.environ.get('NOADT') or not os.path.exists(cp)):
    m = bytearray(OW * OH * 4)
    for i in range(OW * OH):
        if wmask[i]: m[i * 4:i * 4 + 4] = b'\xff\xff\xff\xff'
    write_png(os.environ['MASK'], OW, OH, m)
write_png(outpng, OW, OH, out)
print('written', outpng, OW, OH, 'area', round(X1), round(Z1), round(X2), round(Z2))
