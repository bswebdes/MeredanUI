#!/usr/bin/env python3
"""Prototype: compose a WMO dungeon minimap from Blizzard's minimap tiles (method of Marlamin's
WoWTools.MinimapCompileWMO). Pure Python: BLP2 decode (palette/DXT1/3/5/raw), PNG write.
usage: wmomap.py <workdir> <root.wmo> <wmoID> <tiles.txt> <out.png> [scale]"""
import struct, sys, zlib, os

def chunks(data):
    o, out = 0, {}
    while o + 8 <= len(data):
        tag = data[o:o + 4][::-1].decode('latin1'); size = struct.unpack('<I', data[o + 4:o + 8])[0]
        out.setdefault(tag, data[o + 8:o + 8 + size]); o += 8 + size
    return out

def c565(v):
    r = (v >> 11) & 31; g = (v >> 5) & 63; b = v & 31
    return (r * 255 // 31, g * 255 // 63, b * 255 // 31)

def dxt_colors(block, dxt1):
    c0, c1 = struct.unpack('<HH', block[:4])
    a, b = c565(c0), c565(c1)
    if c0 > c1 or not dxt1:
        cols = [a + (255,), b + (255,), tuple((2 * a[i] + b[i]) // 3 for i in range(3)) + (255,),
                tuple((a[i] + 2 * b[i]) // 3 for i in range(3)) + (255,)]
    else:
        cols = [a + (255,), b + (255,), tuple((a[i] + b[i]) // 2 for i in range(3)) + (255,), (0, 0, 0, 0)]
    idx = struct.unpack('<I', block[4:8])[0]
    return [cols[(idx >> (2 * i)) & 3] for i in range(16)]

def decode_blp(data):
    assert data[:4] == b'BLP2', 'not BLP2'
    _type, comp, alpha_depth, alpha_type, _mips = struct.unpack('<IBBBB', data[4:12])
    w, h = struct.unpack('<II', data[12:20])
    offs = struct.unpack('<16I', data[20:84]); sizes = struct.unpack('<16I', data[84:148])
    palette = struct.unpack('<256I', data[148:148 + 1024])
    raw = data[offs[0]:offs[0] + sizes[0]]
    px = bytearray(w * h * 4)
    if comp == 1:  # palettized
        for i in range(w * h):
            v = palette[raw[i]]
            px[i * 4:i * 4 + 4] = bytes(((v >> 16) & 255, (v >> 8) & 255, v & 255, 255))
        if alpha_depth == 8:
            for i in range(w * h): px[i * 4 + 3] = raw[w * h + i]
        elif alpha_depth == 1:
            for i in range(w * h): px[i * 4 + 3] = 255 if (raw[w * h + i // 8] >> (i % 8)) & 1 else 0
    elif comp == 2:  # DXT
        kind = 1 if alpha_type == 0 else (3 if alpha_type == 1 else 5)
        bs = 8 if kind == 1 else 16
        o = 0
        for by in range(0, h, 4):
            for bx in range(0, w, 4):
                blk = raw[o:o + bs]; o += bs
                if kind == 1:
                    cols = dxt_colors(blk, True)
                else:
                    cols = dxt_colors(blk[8:], False)
                    if kind == 3:
                        av = struct.unpack('<Q', blk[:8])[0]
                        cols = [c[:3] + ((((av >> (4 * i)) & 15) * 17),) for i, c in enumerate(cols)]
                    else:
                        a0, a1 = blk[0], blk[1]
                        if a0 > a1: al = [a0, a1] + [((7 - k) * a0 + k * a1) // 7 for k in range(1, 7)]
                        else: al = [a0, a1] + [((5 - k) * a0 + k * a1) // 5 for k in range(1, 5)] + [0, 255]
                        bits = int.from_bytes(blk[2:8], 'little')
                        cols = [c[:3] + (al[(bits >> (3 * i)) & 7],) for i, c in enumerate(cols)]
                for i in range(16):
                    x, y = bx + i % 4, by + i // 4
                    if x < w and y < h:
                        p = (y * w + x) * 4; px[p:p + 4] = bytes(cols[i])
    else:  # raw BGRA
        for i in range(w * h):
            b, g, r, a = raw[i * 4:i * 4 + 4]; px[i * 4:i * 4 + 4] = bytes((r, g, b, a))
    return w, h, px

def write_png(path, w, h, px):
    rows = b''.join(b'\x00' + bytes(px[y * w * 4:(y + 1) * w * 4]) for y in range(h))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))

def blit(dst, dw, dh, src, sw, sh, dx, dy, cw, ch, sy0):
    # copy src rows sy0..sy0+ch, cols 0..cw to dst at dx,dy (alpha over)
    for y in range(ch):
        sy = sy0 + y; ty = dy + y
        if sy < 0 or sy >= sh or ty < 0 or ty >= dh: continue
        for x in range(cw):
            if x >= sw: break
            tx = dx + x
            if tx < 0 or tx >= dw: continue
            s = (sy * sw + x) * 4; a = src[s + 3]
            if a == 0: continue
            d = (ty * dw + tx) * 4
            if a == 255: dst[d:d + 4] = src[s:s + 4]
            else:
                for k in range(3): dst[d + k] = (src[s + k] * a + dst[d + k] * (255 - a)) // 255
                dst[d + 3] = max(dst[d + 3], a)

def main():
    work, rootfile, wmoid, tilesfile, out = sys.argv[1:6]
    root = chunks(open(rootfile, 'rb').read())
    n = struct.unpack('<I', root['MOHD'][4:8])[0]
    mogi = root['MOGI']
    groups = []
    for i in range(n):
        e = mogi[i * 32:(i + 1) * 32]
        bb = struct.unpack('<6f', e[4:28])
        groups.append(bb)
    tiles = {}
    for line in open(tilesfile):
        w_, g, bx, by, f = line.split()
        if w_ != wmoid: continue
        tiles.setdefault(int(g), []).append((int(bx), int(by), int(f)))
    minx = min(int(b[0] * 2) for b in groups); miny = min(int(b[1] * 2) for b in groups)
    resx = max(int(b[3] * 2) - minx for b in groups); resy = max(int(b[4] * 2) - miny for b in groups)
    img = bytearray(resx * resy * 4)
    for i in range(resx * resy): img[i * 4:i * 4 + 4] = b'\x10\x12\x12\xff'
    for gi, bb in enumerate(groups):
        if gi not in tiles: continue
        t = tiles[gi]
        mnx = min(a[0] for a in t); mxx = max(a[0] for a in t); mny = min(a[1] for a in t); mxy = max(a[1] for a in t)
        decoded = {(bx, by): decode_blp(open(os.path.join(work, f't_{f}.blp'), 'rb').read()) for bx, by, f in t}
        if mnx == mxx == mny == mxy == 0:
            gw, gh, gpx = decoded[(0, 0)]
        else:
            gw, gh = (mxx - mnx) * 256 + 256, (mxy - mny) * 256 + 256
            gpx = bytearray(gw * gh * 4)
            for (bx, by), (tw, th, tpx) in decoded.items():
                blit(gpx, gw, gh, tpx, tw, th, (bx - mnx) * 256, (mxy - (by - mny)) * 256, tw, th, 0)
        x1, y1, x2, y2 = int(bb[0] * 2) - minx, int(bb[1] * 2) - miny, int(bb[3] * 2) - minx, int(bb[4] * 2) - miny
        w, h = x2 - x1, y2 - y1
        # Marlamin: bottom h rows of the group image, top-left at (x1, resy - y2)
        blit(img, resx, resy, gpx, gw, gh, x1, resy - y2, w, h, gh - h)
    write_png(out, resx, resy, img)
    print('written', out, resx, resy, 'groups with tiles', len(tiles))

main()
