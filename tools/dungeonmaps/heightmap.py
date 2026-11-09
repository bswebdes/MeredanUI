"""WMO floor heightmap: top floor height + multi-level mask (2 px/yd, local WMO coords).
usage: PYTHONPATH=../pylib python3 height.py <workdir> <rootfdid>"""
import sys, struct, json, numpy as np
d, root = sys.argv[1], sys.argv[2]
def chunks(b, o=0, end=None):
    end = end or len(b); out = {}
    while o + 8 <= end:
        t = b[o:o+4][::-1].decode('latin1'); n = struct.unpack('<I', b[o+4:o+8])[0]
        out.setdefault(t, b[o+8:o+8+n]); o += 8 + n
    return out
r = open(f'{d}/{root}.bin','rb').read(); rc = chunks(r)
gf = struct.unpack(f'<{len(rc["GFID"])//4}I', rc['GFID'])
info = json.load(open(f'{d}/info.json')); gb = info['wmos'][0]['gb']
minx = min(b[0] for b in gb); miny = min(b[1] for b in gb); maxx = max(b[3] for b in gb); maxy = max(b[4] for b in gb)
S = 2.0; W = int((maxy-miny)*S)+2; H = int((maxx-minx)*S)+2   # image: right = +y, down = +x
NEG = -1e9
top = np.full((H, W), NEG, np.float32); lay2 = np.full((H, W), NEG, np.float32); grp = np.full((H, W), -1, np.int16)
for gi, f in enumerate(gf):
    g = open(f'{d}/{f}.bin','rb').read(); k = g.find(b'PGOM'); n = struct.unpack('<I', g[k+4:k+8])[0]
    sub = chunks(g, k+8+68, k+8+n)
    if 'TVOM' in sub: pass
    V = np.frombuffer(sub['MOVT'], np.float32).reshape(-1, 3); I = np.frombuffer(sub['MOVI'], np.uint16).reshape(-1, 3)
    P = np.frombuffer(sub['MOPY'], np.uint8).reshape(-1, 2) if 'MOPY' in sub else None
    for t, (a, b, c) in enumerate(I):
        if P is not None and (P[t, 1] == 0xFF and not (P[t, 0] & 0x08)): continue  # render-only, no collision
        A, B, C = V[a], V[b], V[c]
        nrm = np.cross(B - A, C - A); ln = np.linalg.norm(nrm)
        if ln == 0 or nrm[2] / ln < 0.6: continue  # walkable floors only
        # rasterize in image space: u = (y-miny)*S, v = (x-minx)*S
        pts = [((p[1]-miny)*S, (p[0]-minx)*S, p[2]) for p in (A, B, C)]
        u0 = int(max(0, min(p[0] for p in pts))); u1 = int(min(W-1, max(p[0] for p in pts))+1)
        v0 = int(max(0, min(p[1] for p in pts))); v1 = int(min(H-1, max(p[1] for p in pts))+1)
        if u1 <= u0 or v1 <= v0: continue
        uu, vv = np.meshgrid(np.arange(u0, u1) + 0.5, np.arange(v0, v1) + 0.5)
        (x1, y1, z1), (x2, y2, z2), (x3, y3, z3) = pts
        den = (y2-y3)*(x1-x3) + (x3-x2)*(y1-y3)
        if abs(den) < 1e-9: continue
        l1 = ((y2-y3)*(uu-x3) + (x3-x2)*(vv-y3)) / den; l2 = ((y3-y1)*(uu-x3) + (x1-x3)*(vv-y3)) / den; l3 = 1-l1-l2
        m = (l1 >= -0.01) & (l2 >= -0.01) & (l3 >= -0.01)
        if not m.any(): continue
        z = l1*z1 + l2*z2 + l3*z3
        T = top[v0:v1, u0:u1]; L = lay2[v0:v1, u0:u1]; G = grp[v0:v1, u0:u1]
        # keep top floor and the highest floor clearly below it (>= 8 yd) as second layer
        newtop = m & (z > T)
        demote = newtop & (T > NEG) & (T < z - 8)
        L[demote] = np.maximum(L[demote], T[demote])
        low = m & ~newtop & (z < T - 8)
        L[low] = np.maximum(L[low], z[low])
        T[newtop] = z[newtop]; G[newtop] = gi
np.save(f'{d}/top.npy', top); np.save(f'{d}/lay2.npy', lay2); np.save(f'{d}/hgrp.npy', grp)
valid = top > NEG
print('size', W, H, 'floor px', valid.sum(), 'z', top[valid].min(), top[valid].max(), 'two-level px', (lay2 > NEG).sum())
