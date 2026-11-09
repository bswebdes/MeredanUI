#!/usr/bin/env python3
"""Santiago Reyes' dungeon maps (Atlas de Azeroth: Forever, sreyesmaps.com, used with his permission;
watermark stays untouched, credit shown on the map) -> Media/DungeonMaps/<inst>_<floor>.blp.
3000x2000 JPG -> 1536x1024 (ffmpeg) -> BLP2 DXT1 2048x1024, map in the left 1536 px (texCoord 0..0.75).
usage: python3 -I tools/dungeonmaps/santiago.py <download dir>"""
import pathlib, struct, subprocess, sys, urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
CDN = "https://cdn.sanity.io/images/uomo7a9a/production/"
# inst, floor, image id
MAPS = [
    (3065, 1, "2f84b5f1122715547a7f9290e7da27436a4da8dd"),  # Hall of Thanes
    (2999, 1, "2905022d7097a9494239d686e79b919dbc942ada"),  # Ruins of Lordaeron
    (2998, 1, "3f554cf2a1aada5052f241b9660c826777c95bf5"),  # Excavation Site: Wetlands (v2.0)
    (2959, 1, "9ba8b6ebf8a446f8b4faeaf2aeee2c367e297eb2"),  # City of Dalaran
    (2959, 2, "59306714ec76d9bdd2c0a47661782ba05fe357ab"),  # Dalaran sewers
    (2970, 1, "54dae4b3bd673a65eb8af548503f630f5ed1da12"),  # The Drowned City
    (2970, 2, "3ce86151f7ab78c323fc1e2c8471c9c3fc1e6f3d"),  # Atal'Byzal
    (2994, 1, "7a9fa5d64f38cda71216ec3fab454e03726e9860"),  # Alcaz Prison: main pavilion
    (2994, 2, "faddb79c0a9aeb39a738d1068ce8697d31a221fd"),  # Alcaz Prison: maximum security
    (3001, 1, "7389e3424ed2de6fb969502e3afc5ad8e365328b"),  # Shaper's Terrace
    (3039, 1, "8c76db457e5bef41effc364b3cd45fa3c86fb8ec"),  # Krol'dok (pre-beta)
]
W, H, TW, TH = 1536, 1024, 2048, 1024


def to565(c):
    return ((c[0] >> 3) << 11) | ((c[1] >> 2) << 5) | (c[2] >> 3)


def from565(v):
    return ((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31


def block(px):
    # endpoints: per-channel bounding box (better than luminance extremes for parchment tones)
    lo = tuple(min(p[i] for p in px) for i in range(3))
    hi = tuple(max(p[i] for p in px) for i in range(3))
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


def to_blp(raw, out):
    data = bytearray()
    for by in range(0, TH, 4):
        for bx in range(0, TW, 4):
            pxs = []
            for y in range(by, by + 4):
                for x in range(bx, bx + 4):
                    if x < W:
                        q = (y * W + x) * 3
                        pxs.append((raw[q], raw[q + 1], raw[q + 2]))
                    else:
                        pxs.append((0, 0, 0))
            data += block(pxs)
    header = b'BLP2' + struct.pack('<IBBBB', 1, 2, 0, 0, 0) + struct.pack('<II', TW, TH)
    offs = [148 + 1024] + [0] * 15
    sizes = [len(data)] + [0] * 15
    header += struct.pack('<16I', *offs) + struct.pack('<16I', *sizes) + b'\x00' * 1024
    out.write_bytes(header + data)


def main():
    work = pathlib.Path(sys.argv[1])
    work.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[2:])
    for inst, floor, img in MAPS:
        key = f"{inst}_{floor}"
        if only and key not in only: continue
        jpg = work / f"{key}.jpg"
        if not jpg.exists():
            req = urllib.request.Request(CDN + img + "-3000x2000.jpg", headers={"User-Agent": "Mozilla/5.0 (mUI map import)"})
            jpg.write_bytes(urllib.request.urlopen(req).read())
        raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(jpg), "-vf", f"scale={W}:{H}:flags=lanczos",
                              "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
        assert len(raw) == W * H * 3, (key, len(raw))
        to_blp(raw, ROOT / "Media" / "DungeonMaps" / f"{key}.blp")
        print("written", key, flush=True)


main()
