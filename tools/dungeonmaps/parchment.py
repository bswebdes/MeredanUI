#!/usr/bin/env python3
"""Turn a composed minimap (dark background) into a parchment dungeon map in the style of Blizzard's
drawn dungeon maps. Pure Python. usage: parchment.py <in.png> <out.png>
Canvas 1002x668 like Blizzard's map art; the floor plan keeps its exact geometry."""
import struct, zlib, sys, math, random

W, H = 1002, 668
BG = (0x10, 0x12, 0x12)

def read_png(path):
    d = open(path, 'rb').read(); o = 8; idat = b''
    while o < len(d):
        n = struct.unpack('>I', d[o:o + 4])[0]; t = d[o + 4:o + 8]; c = d[o + 8:o + 8 + n]
        if t == b'IHDR': w, h = struct.unpack('>II', c[:8])
        if t == b'IDAT': idat += c
        o += 12 + n
    raw = zlib.decompress(idat); px = bytearray()
    for y in range(h): px += raw[y * (w * 4 + 1) + 1:(y + 1) * (w * 4 + 1)]
    return w, h, px

def write_png(path, w, h, px):
    rows = b''.join(b'\x00' + bytes(px[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))

# value noise for paper grain and stains
random.seed(7)
def make_noise(cell):
    gw, gh = W // cell + 2, H // cell + 2
    g = [[random.random() for _ in range(gw)] for _ in range(gh)]
    def f(x, y):
        fx, fy = x / cell, y / cell; ix, iy = int(fx), int(fy); tx, ty = fx - ix, fy - iy
        tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
        a = g[iy][ix] * (1 - tx) + g[iy][ix + 1] * tx; b = g[iy + 1][ix] * (1 - tx) + g[iy + 1][ix + 1] * tx
        return a * (1 - ty) + b * ty
    return f
n1, n2, n3 = make_noise(140), make_noise(35), make_noise(7)

def dilate(mask, w, h, r):
    # square max filter, separable
    out = bytearray(len(mask)); tmp = bytearray(len(mask))
    for y in range(h):
        row = mask[y * w:(y + 1) * w]
        for x in range(w):
            lo, hi = max(0, x - r), min(w, x + r + 1)
            tmp[y * w + x] = 1 if any(row[lo:hi]) else 0
    for x in range(w):
        col = tmp[x::w]
        for y in range(h):
            lo, hi = max(0, y - r), min(h, y + r + 1)
            out[y * w + x] = 1 if any(col[lo:hi]) else 0
    return out

def main():
    sw, sh, src = read_png(sys.argv[1])
    # fit plan into the inner area (margins for frame and title band)
    s = min((W - 140) / sw, (H - 150) / sh)
    pw, ph = int(sw * s), int(sh * s)
    ox, oy = (W - pw) // 2, (H - ph) // 2 + 22
    mask = bytearray(W * H); lum = [0.0] * (W * H)
    for y in range(ph):
        sy = min(int(y / s), sh - 1)
        for x in range(pw):
            sx = min(int(x / s), sw - 1); p = (sy * sw + sx) * 4
            r, g, b, a = src[p:p + 4]
            if a > 40 and (abs(r - BG[0]) + abs(g - BG[1]) + abs(b - BG[2])) > 18:
                i = (oy + y) * W + ox + x
                mask[i] = 1; lum[i] = (0.3 * r + 0.59 * g + 0.11 * b) / 255
    # close tiny gaps between tiles, then outline bands
    mask = dilate(mask, W, H, 1)
    outer = dilate(mask, W, H, 4)
    inner_shadow = dilate([1 - m for m in mask], W, H, 3)  # floor pixels near a wall
    out = bytearray(W * H * 4)
    for y in range(H):
        for x in range(W):
            i = y * W + x
            grain = 0.55 * n1(x, y) + 0.3 * n2(x, y) + 0.15 * n3(x, y)
            # vignette and burnt edge
            dx, dy = min(x, W - 1 - x), min(y, H - 1 - y)
            edge = min(dx, dy)
            vig = min(1.0, edge / 70.0)
            ragged = 14 + 10 * n2((x * 3) % W, (y * 3) % H)
            if edge < ragged:
                r, g, b = 28, 18, 10
            else:
                base = (196, 160, 104)
                k = 0.78 + 0.32 * grain
                k *= 0.55 + 0.45 * vig
                r, g, b = base[0] * k, base[1] * k, base[2] * k
                if mask[i]:
                    fl = (226, 204, 156)
                    t = 0.88 + 0.12 * lum[i] + 0.1 * (grain - 0.5)
                    r, g, b = fl[0] * t, fl[1] * t, fl[2] * t
                    if inner_shadow[i]:
                        r, g, b = r * 0.86, g * 0.84, b * 0.8
                elif outer[i]:
                    r, g, b = 92 * (0.8 + 0.3 * grain), 62 * (0.8 + 0.3 * grain), 34 * (0.8 + 0.3 * grain)
            p = i * 4
            out[p:p + 4] = bytes((max(0, min(255, int(r))), max(0, min(255, int(g))), max(0, min(255, int(b))), 255))
    write_png(sys.argv[2], W, H, out)
    print('written', sys.argv[2])

main()
