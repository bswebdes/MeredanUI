#!/usr/bin/env python3
"""Shared helpers for the class-art inventory (tools/classart).

- wago.tools access with a local cache (CLASSART_CACHE, default ~/.cache/meredanui-classart)
- DB2 tables as CSV for the Forever build
- atlas lookup (UiTextureAtlasMember -> texture FileDataID + pixel rect)
- BLP2 decoder (palettized, DXT1/3/5, raw ARGB) on numpy, returns RGBA arrays

Needs: pip install numpy pillow
"""
import csv
import io
import os
import struct
import time
import urllib.parse
import urllib.request

import numpy as np

BUILD = os.environ.get("CLASSART_BUILD", "1.60.1.70862")
UA = "MeredanUI"
CACHE = os.path.expanduser(os.environ.get("CLASSART_CACHE", "~/.cache/meredanui-classart"))

CLASSES = ["warrior", "paladin", "hunter", "rogue", "priest", "shaman", "mage", "warlock", "druid"]
RETAIL_CLASSES = ["deathknight", "monk", "demonhunter", "evoker"]
CLASS_ID = {"warrior": 1, "paladin": 2, "hunter": 3, "rogue": 4, "priest": 5, "shaman": 7,
            "mage": 8, "warlock": 9, "druid": 11}


# --- HTTP + cache ------------------------------------------------------------------------------

def _get(url, retries=4):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except Exception:
            if attempt == retries - 1:
                raise
            time.sleep(2 ** (attempt + 1))


def _cached(name, url):
    path = os.path.join(CACHE, name)
    if os.path.exists(path):
        with open(path, "rb") as f:
            return f.read()
    data = _get(url)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return data


def db2(table):
    """DB2 table of the build as a list of dicts."""
    data = _cached(f"db2/{BUILD}/{table}.csv", f"https://wago.tools/db2/{table}/csv?build={BUILD}")
    return list(csv.DictReader(io.StringIO(data.decode("utf-8"))))


def casc(fdid):
    """Raw file bytes from the build, or None if the file is not in the build."""
    data = _cached(f"casc/{BUILD}/{fdid}", f"https://wago.tools/api/casc/{fdid}?version={BUILD}")
    if len(data) < 16 or data[:1] == b"{":
        return None
    return data


def file_search(term):
    """wago.tools listfile search -> {fdid: path}."""
    q = urllib.parse.quote(term)
    data = _cached(f"search/{BUILD}/{q}.json", f"https://wago.tools/api/files?search={q}&version={BUILD}")
    import json
    d = json.loads(data.decode("utf-8") or "{}")
    return {int(k): v for k, v in (d.items() if isinstance(d, dict) else [])}


# --- lookups -----------------------------------------------------------------------------------

_atlas = None
_manifest = None


def manifest():
    """FileDataID -> interface path (ManifestInterfaceData)."""
    global _manifest
    if _manifest is None:
        _manifest = {}
        for r in db2("ManifestInterfaceData"):
            _manifest[int(r["ID"])] = (r["FilePath"] + r["FileName"]).replace("\\", "/")
        _by_path.update({v.lower(): k for k, v in _manifest.items()})
    return _manifest


_by_path = {}


def fdid_of(path):
    manifest()
    p = path.replace("\\", "/").lower()
    if not p.endswith(".blp"):
        p += ".blp"
    if p in _by_path:
        return _by_path[p]
    hits = file_search(p)
    for k, v in hits.items():
        if v.lower() == p:
            return k
    return None


def atlases():
    """atlas name (lower) -> dict(fdid, aw, ah, l, r, t, b, w, h)."""
    global _atlas
    if _atlas is None:
        tex = {r["ID"]: r for r in db2("UiTextureAtlas")}
        _atlas = {}
        for m in db2("UiTextureAtlasMember"):
            t = tex.get(m["UiTextureAtlasID"])
            if not t:
                continue
            _atlas[m["CommittedName"].lower()] = dict(
                fdid=int(t["FileDataID"]), aw=int(t["AtlasWidth"]), ah=int(t["AtlasHeight"]),
                l=int(m["CommittedLeft"]), r=int(m["CommittedRight"]),
                t=int(m["CommittedTop"]), b=int(m["CommittedBottom"]),
                w=int(m["Width"]), h=int(m["Height"]))
    return _atlas


def path_of(fdid):
    return manifest().get(fdid, "")


# --- BLP decoding ------------------------------------------------------------------------------

def _rgb565(c):
    r = ((c >> 11) & 31).astype(np.uint16) * 255 // 31
    g = ((c >> 5) & 63).astype(np.uint16) * 255 // 63
    b = (c & 31).astype(np.uint16) * 255 // 31
    return np.stack([r, g, b], -1).astype(np.int32)


def _dxt_color(blocks, dxt1):
    """blocks: (n, 8) uint8 color part -> (n, 16, 4) RGBA."""
    c0 = blocks[:, 0].astype(np.uint16) | (blocks[:, 1].astype(np.uint16) << 8)
    c1 = blocks[:, 2].astype(np.uint16) | (blocks[:, 3].astype(np.uint16) << 8)
    a, b = _rgb565(c0), _rgb565(c1)
    n = len(blocks)
    pal = np.zeros((n, 4, 4), np.int32)
    pal[:, 0, :3], pal[:, 1, :3] = a, b
    pal[:, :, 3] = 255
    four = (c0 > c1) | (not dxt1)
    pal[:, 2, :3] = np.where(four[:, None], (2 * a + b) // 3, (a + b) // 2)
    pal[:, 3, :3] = np.where(four[:, None], (a + 2 * b) // 3, 0)
    if dxt1:
        pal[:, 3, 3] = np.where(four, 255, 0)
    idx = blocks[:, 4:8].astype(np.uint32)
    idx = idx[:, 0] | (idx[:, 1] << 8) | (idx[:, 2] << 16) | (idx[:, 3] << 24)
    sel = (idx[:, None] >> (2 * np.arange(16, dtype=np.uint32))) & 3
    return np.take_along_axis(pal, sel[:, :, None].astype(np.int64).repeat(4, 2), 1)


def _dxt5_alpha(blocks):
    a0 = blocks[:, 0].astype(np.int32)
    a1 = blocks[:, 1].astype(np.int32)
    n = len(blocks)
    pal = np.zeros((n, 8), np.int32)
    pal[:, 0], pal[:, 1] = a0, a1
    big = a0 > a1
    for i in range(1, 7):
        pal[:, i + 1] = np.where(big, ((7 - i) * a0 + i * a1) // 7, 0)
    for i in range(1, 5):
        pal[:, i + 1] = np.where(big, pal[:, i + 1], ((5 - i) * a0 + i * a1) // 5)
    pal[:, 6] = np.where(big, pal[:, 6], 0)
    pal[:, 7] = np.where(big, pal[:, 7], 255)
    bits = np.zeros(n, np.uint64)
    for i in range(6):
        bits |= blocks[:, 2 + i].astype(np.uint64) << np.uint64(8 * i)
    sel = (bits[:, None] >> (np.uint64(3) * np.arange(16, dtype=np.uint64))) & np.uint64(7)
    return np.take_along_axis(pal, sel.astype(np.int64), 1)


def decode_blp(data):
    """BLP2 bytes -> RGBA uint8 array (h, w, 4), largest mip."""
    if data[:4] != b"BLP2":
        raise ValueError("not BLP2")
    _type, comp, adepth, atype, _mips = struct.unpack("<IBBBB", data[4:12])
    w, h = struct.unpack("<II", data[12:20])
    offs = struct.unpack("<16I", data[20:84])
    sizes = struct.unpack("<16I", data[84:148])
    raw = np.frombuffer(data[offs[0]:offs[0] + sizes[0]], np.uint8)
    if comp == 1:  # palettized
        pal = np.frombuffer(data[148:148 + 1024], np.uint8).reshape(256, 4)  # BGRA
        idx = raw[:w * h]
        rgb = pal[idx][:, [2, 1, 0]]
        if adepth == 8:
            a = raw[w * h:w * h * 2]
        elif adepth == 4:
            ab = raw[w * h:]
            a = np.repeat(ab, 2)[:w * h].copy()
            a[0::2] = (ab[:len(a[0::2])] & 15) * 17
            a[1::2] = (ab[:len(a[1::2])] >> 4) * 17
        elif adepth == 1:
            a = np.unpackbits(raw[w * h:], bitorder="little")[:w * h] * 255
        else:
            a = np.full(w * h, 255, np.uint8)
        out = np.concatenate([rgb, a[:, None].astype(np.uint8)], 1)
        return out.reshape(h, w, 4)
    if comp == 2:  # DXT
        kind = 1 if atype == 0 else (3 if atype == 1 else 5)
        if adepth == 0:
            kind = 1
        bw, bh = max(1, (w + 3) // 4), max(1, (h + 3) // 4)
        bs = 8 if kind == 1 else 16
        blocks = raw[:bw * bh * bs].reshape(-1, bs)
        if kind == 1:
            px = _dxt_color(blocks, True)
        else:
            px = _dxt_color(blocks[:, 8:], False)
            if kind == 3:
                ab = blocks[:, :8]
                a = np.stack([ab & 15, ab >> 4], -1).reshape(-1, 16).astype(np.int32) * 17
            else:
                a = _dxt5_alpha(blocks[:, :8])
            px[:, :, 3] = a
        img = px.reshape(bh, bw, 4, 4, 4).transpose(0, 2, 1, 3, 4).reshape(bh * 4, bw * 4, 4)
        return img[:h, :w].astype(np.uint8)
    if comp == 3:  # raw BGRA
        return raw[:w * h * 4].reshape(h, w, 4)[:, :, [2, 1, 0, 3]].copy()
    raise ValueError(f"unsupported compression {comp}")


_img_cache = {}


def texture(fdid):
    """PIL RGBA image of a texture, or None if missing in the build."""
    from PIL import Image
    if fdid in _img_cache:
        return _img_cache[fdid]
    data = casc(fdid)
    img = None
    if data and data[:4] == b"BLP2":
        try:
            img = Image.fromarray(decode_blp(data), "RGBA")
        except Exception as e:  # keep going, report as unreadable
            print("decode failed", fdid, e)
    _img_cache[fdid] = img
    return img


def blp_size(fdid):
    data = casc(fdid)
    if not data or data[:4] != b"BLP2":
        return None
    return struct.unpack("<II", data[12:20])


def atlas_image(name):
    a = atlases().get(name.lower())
    if not a:
        return None
    img = texture(a["fdid"])
    if img is None:
        return None
    sx, sy = img.width / a["aw"], img.height / a["ah"]
    return img.crop((round(a["l"] * sx), round(a["t"] * sy), round(a["r"] * sx), round(a["b"] * sy)))


def font(size, bold=False):
    """mUI's own font from Media/Fonts (has umlauts), falls back to Pillow's default."""
    from PIL import ImageFont
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "..", "..", "Media", "Fonts", "mUI-Bold.ttf" if bold else "mUI-Text.ttf")
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        try:
            return ImageFont.load_default(size)
        except TypeError:
            return ImageFont.load_default()


_presence = None
import threading
_plock = threading.Lock()


def present(fdid):
    """True if the file is in the build. Reads only the first bytes (no full download), cached in JSON."""
    import json
    global _presence
    pfile = os.path.join(CACHE, f"presence-{BUILD}.json")
    if _presence is None:
        try:
            with open(pfile) as f:
                _presence = json.load(f)
        except OSError:
            _presence = {}
    key = str(fdid)
    if key not in _presence:
        if os.path.exists(os.path.join(CACHE, f"casc/{BUILD}/{fdid}")):
            _presence[key] = casc(fdid) is not None
        else:
            req = urllib.request.Request(f"https://wago.tools/api/casc/{fdid}?version={BUILD}", headers={"User-Agent": UA})
            head = b""
            for attempt in range(4):
                try:
                    with urllib.request.urlopen(req, timeout=60) as r:
                        head = r.read(8)
                    break
                except Exception:
                    time.sleep(2 ** (attempt + 1))
            _presence[key] = len(head) >= 4 and head[:1] != b"{"
        with _plock:
            os.makedirs(CACHE, exist_ok=True)
            with open(pfile + ".tmp", "w") as f:
                json.dump(dict(_presence), f)
            os.replace(pfile + ".tmp", pfile)
    return _presence[key]
