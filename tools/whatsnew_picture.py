#!/usr/bin/env python3
"""Screenshot crop -> picture for the "New in mUI" window: 512x256 BLP2 DXT1 (~64 KB), no mipmaps.
Blur names/chat in the crop before (or pass blur boxes in screenshot pixels).
usage: whatsnew_picture.py <screenshot.png> <left> <top> <right> <bottom> <out.blp> [blur x1,y1,x2,y2 ...]
Needs Pillow."""
import struct, sys
from PIL import Image, ImageFilter

W, H = 512, 256
src, box, out = sys.argv[1], tuple(int(v) for v in sys.argv[2:6]), sys.argv[6]
im = Image.open(src).convert('RGB')
for spec in sys.argv[7:]:
    b = tuple(int(v) for v in spec.split(','))
    im.paste(im.crop(b).filter(ImageFilter.GaussianBlur(12)), b[:2])
im = im.crop(box).resize((W, H), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 60, 2))
px = im.load()

def to565(c): return ((c[0] >> 3) << 11) | ((c[1] >> 2) << 5) | (c[2] >> 3)
def from565(v): return ((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31

def block(pxs):
    lums = [p[0] * 3 + p[1] * 6 + p[2] for p in pxs]
    hi, lo = pxs[lums.index(max(lums))], pxs[lums.index(min(lums))]
    c0, c1 = to565(hi), to565(lo)
    if c0 < c1: c0, c1 = c1, c0
    if c0 == c1: return struct.pack('<HHI', c0, c1, 0)
    a, b = from565(c0), from565(c1)
    pal = [a, b, tuple((2 * a[i] + b[i]) // 3 for i in range(3)), tuple((a[i] + 2 * b[i]) // 3 for i in range(3))]
    idx = 0
    for i, p in enumerate(pxs):
        best = min(range(4), key=lambda k: sum((p[j] - pal[k][j]) ** 2 for j in range(3)))
        idx |= best << (2 * i)
    return struct.pack('<HHI', c0, c1, idx)

data = bytearray()
for by in range(0, H, 4):
    for bx in range(0, W, 4):
        data += block([px[x, y] for y in range(by, by + 4) for x in range(bx, bx + 4)])
header = b'BLP2' + struct.pack('<IBBBB', 1, 2, 0, 0, 0) + struct.pack('<II', W, H)
header += struct.pack('<16I', 148 + 1024, *[0] * 15) + struct.pack('<16I', len(data), *[0] * 15) + b'\x00' * 1024
open(out, 'wb').write(header + data)
im.save(out.rsplit('.', 1)[0] + '.preview.png')
print('written', out, len(header) + len(data))
