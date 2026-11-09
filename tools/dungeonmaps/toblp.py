#!/usr/bin/env python3
"""PNG (768x512) -> BLP2 DXT1 texture 1024x512 (map in the left 768 px, rest black) for the addon.
usage: toblp.py <in.png> <out.blp>"""
import struct, sys
src = open(__file__.replace('toblp.py', 'parchment.py')).read().replace('\nmain()\n', '\n')
P = {'__name__': 'x'}; exec(compile(src, 'p', 'exec'), P)
TW, TH = 1024, 512

def to565(c):
    return ((c[0] >> 3) << 11) | ((c[1] >> 2) << 5) | (c[2] >> 3)

def from565(v):
    return ((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31

def block(px):
    lums = [p[0] * 3 + p[1] * 6 + p[2] for p in px]
    hi, lo = px[lums.index(max(lums))], px[lums.index(min(lums))]
    c0, c1 = to565(hi), to565(lo)
    if c0 < c1: c0, c1 = c1, c0
    if c0 == c1:
        return struct.pack('<HHI', c0, c1, 0)
    a, b = from565(c0), from565(c1)
    pal = [a, b, tuple((2 * a[i] + b[i]) // 3 for i in range(3)), tuple((a[i] + 2 * b[i]) // 3 for i in range(3))]
    idx = 0
    for i, p in enumerate(px):
        best = min(range(4), key=lambda k: (p[0] - pal[k][0]) ** 2 + (p[1] - pal[k][1]) ** 2 + (p[2] - pal[k][2]) ** 2)
        idx |= best << (2 * i)
    return struct.pack('<HHI', c0, c1, idx)

def main():
    w, h, px = P['read_png'](sys.argv[1])
    data = bytearray()
    for by in range(0, TH, 4):
        for bx in range(0, TW, 4):
            pxs = []
            for y in range(by, by + 4):
                for x in range(bx, bx + 4):
                    if x < w and y < h:
                        q = (y * w + x) * 4; pxs.append((px[q], px[q + 1], px[q + 2]))
                    else:
                        pxs.append((0, 0, 0))
            data += block(pxs)
    header = b'BLP2' + struct.pack('<IBBBB', 1, 2, 0, 0, 0) + struct.pack('<II', TW, TH)
    offs = [148 + 1024] + [0] * 15; sizes = [len(data)] + [0] * 15
    header += struct.pack('<16I', *offs) + struct.pack('<16I', *sizes) + b'\x00' * 1024
    open(sys.argv[2], 'wb').write(header + data)
    print('written', sys.argv[2], len(header) + len(data))

main()
