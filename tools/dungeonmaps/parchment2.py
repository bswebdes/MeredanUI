#!/usr/bin/env python3
"""Composed dungeon minimap + playable-area mask -> parchment map (768x512, 3:2 like Blizzard's maps).
Inside the mask: light parchment shaded by the minimap's brightness (keeps rooms, paths, terrain);
outside: dark parchment with a faint hint of the surroundings; ink outline along the mask edge.
usage: parchment2.py <composite.png> <mask.png> <out.png>"""
import sys, random
src = open(__file__.replace('parchment2.py', 'parchment.py')).read().replace('\nmain()\n', '\n')
P = {'__name__': 'x'}; exec(compile(src, 'p', 'exec'), P)
read_png, write_png, dilate = P['read_png'], P['write_png'], P['dilate']
W, H = 768, 512

def noise(cell, seed):
    random.seed(seed)
    gw, gh = W // cell + 2, H // cell + 2
    g = [[random.random() for _ in range(gw)] for _ in range(gh)]
    def f(x, y):
        fx, fy = x / cell, y / cell; ix, iy = int(fx), int(fy); tx, ty = fx - ix, fy - iy
        tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
        a = g[iy][ix] * (1 - tx) + g[iy][ix + 1] * tx; b = g[iy + 1][ix] * (1 - tx) + g[iy + 1][ix + 1] * tx
        return a * (1 - ty) + b * ty
    return f
n1, n2, n3 = noise(110, 3), noise(28, 5), noise(6, 9)

def smooth(mask, r):
    # box blur (separable running sums) + threshold: rounds staircase edges, closes small gaps
    f = [float(v) for v in mask]; tmp = [0.0] * (W * H)
    for y in range(H):
        acc = 0.0; row = y * W
        for x in range(-r, W):
            if x + r < W: acc += f[row + x + r]
            if x - r - 1 >= 0: acc -= f[row + x - r - 1]
            if x >= 0: tmp[row + x] = acc / (2 * r + 1)
    out = bytearray(W * H)
    for x in range(W):
        acc = 0.0
        for y in range(-r, H):
            if y + r < H: acc += tmp[(y + r) * W + x]
            if y - r - 1 >= 0: acc -= tmp[(y - r - 1) * W + x]
            if y >= 0: out[y * W + x] = 1 if acc / (2 * r + 1) >= 0.5 else 0
    return out

def main():
    cw, ch, cpx = read_png(sys.argv[1]); mw, mh, mpx = read_png(sys.argv[2])
    # fit the mask's bounding box (plus margin) into the inner canvas
    xs, ys = [], []
    for y in range(0, mh, 2):
        for x in range(0, mw, 2):
            if mpx[(y * mw + x) * 4]: xs.append(x); ys.append(y)
    bx1, by1, bx2, by2 = min(xs), min(ys), max(xs), max(ys)
    m = 0.08 * max(bx2 - bx1, by2 - by1)
    bx1, by1, bx2, by2 = bx1 - m, by1 - m, bx2 + m, by2 + m
    s = min((W - 70) / (bx2 - bx1), (H - 70) / (by2 - by1))
    ox = (W - (bx2 - bx1) * s) / 2 - bx1 * s; oy = (H - (by2 - by1) * s) / 2 - by1 * s
    mask = bytearray(W * H); lum = [0.0] * (W * H)
    for y in range(H):
        sy = int((y - oy) / s)
        for x in range(W):
            sx = int((x - ox) / s)
            if 0 <= sx < cw and 0 <= sy < ch:
                i = y * W + x; p = (sy * cw + sx) * 4
                lum[i] = (0.3 * cpx[p] + 0.59 * cpx[p + 1] + 0.11 * cpx[p + 2]) / 255
                if sx < mw and sy < mh and mpx[(sy * mw + sx) * 4]: mask[i] = 1
    # optional: keep only brighter ground (e.g. sea floor vs. city), then smooth the blocky chunk edges
    thr = float(sys.argv[4]) if len(sys.argv) > 4 else 0
    if thr:
        for i in range(W * H):
            if mask[i] and lum[i] < thr: mask[i] = 0
    mask = smooth(mask, 7)
    edge_out = dilate(mask, W, H, 2)
    near_wall = dilate(bytearray(1 - v for v in mask), W, H, 2)
    out = bytearray(W * H * 4)
    for y in range(H):
        for x in range(W):
            i = y * W + x
            grain = 0.55 * n1(x, y) + 0.3 * n2(x, y) + 0.15 * n3(x, y)
            edge = min(x, y, W - 1 - x, H - 1 - y)
            ragged = 10 + 8 * n2((x * 3) % W, (y * 3) % H)
            if edge < ragged:
                r, g, b = 26, 17, 9
            elif mask[i]:
                t = 0.42 + 0.85 * lum[i] + 0.1 * (grain - 0.5)
                if near_wall[i]: t *= 0.82
                r, g, b = 232 * t, 206 * t, 152 * t
            elif edge_out[i]:
                k = 0.85 + 0.25 * grain
                r, g, b = 84 * k, 56 * k, 30 * k
            else:
                vig = min(1.0, edge / 60.0)
                k = (0.72 + 0.3 * grain) * (0.6 + 0.4 * vig) * (0.9 + 0.18 * lum[i])
                r, g, b = 178 * k, 140 * k, 88 * k
            q = i * 4
            out[q:q + 4] = bytes((max(0, min(255, int(r))), max(0, min(255, int(g))), max(0, min(255, int(b))), 255))
    write_png(sys.argv[3], W, H, out)
    print('written', sys.argv[3], 'scale', round(s, 3), 'offset', round(ox, 1), round(oy, 1))

main()
