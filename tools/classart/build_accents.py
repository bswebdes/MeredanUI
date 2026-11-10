#!/usr/bin/env python3
"""Muted class accent colors: each Blizzard class color moved to the lightness and chroma of mUI's
Surf Green (#8ecbb4) in OKLCH, hue kept. Writes accents.csv and previews/class_accents.jpg.

usage: python3 build_accents.py
"""
import csv
import math
import os

from PIL import Image, ImageDraw, ImageFont

import classart_lib as L

HERE = os.path.dirname(os.path.abspath(__file__))
SURF = (0x8e, 0xcb, 0xb4)
PANEL = (15, 15, 16)
NAMES = {"warrior": "Krieger", "paladin": "Paladin", "hunter": "Jäger", "rogue": "Schurke", "priest": "Priester",
         "shaman": "Schamane", "mage": "Magier", "warlock": "Hexenmeister", "druid": "Druide"}


def srgb_to_lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin_to_srgb(c):
    c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return max(0, min(255, round(c * 255)))


def to_oklch(rgb):
    r, g, b = (srgb_to_lin(v) for v in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (v ** (1 / 3) for v in (l, m, s))
    L_ = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    b2 = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L_, math.hypot(a, b2), math.atan2(b2, a)


def from_oklch(L_, C, h):
    a, b = C * math.cos(h), C * math.sin(h)
    l = (L_ + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L_ - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L_ - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return tuple(lin_to_srgb(v) for v in (r, g, bb))


def in_gamut(L_, C, h):
    a, b = C * math.cos(h), C * math.sin(h)
    l = (L_ + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L_ - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L_ - 0.0894841775 * a - 1.2914855480 * b) ** 3
    vals = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return all(-0.001 <= v <= 1.001 for v in vals)


def lum(rgb):
    r, g, b = (srgb_to_lin(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hexs(rgb):
    return "#%02x%02x%02x" % rgb


def muted(rgb):
    sl, sc, _ = to_oklch(SURF)
    l, c, h = to_oklch(rgb)
    C = min(c, sc)
    if c < 0.02:  # priest white -> warm light grey with a hint of chroma
        return from_oklch(sl + 0.04, 0.012, math.radians(85))
    while C > 0 and not in_gamut(sl, C, h):
        C -= 0.002
    return from_oklch(sl, C, h)


def main():
    rows = []
    for r in L.db2("ChrClasses"):
        c = r["Filename"].lower()
        if c in L.CLASSES:
            rgb = (int(r["ClassColorR"]), int(r["ClassColorG"]), int(r["ClassColorB"]))
            m = muted(rgb)
            dark = tuple(round(v * 0.35) for v in m)  # border/selection tint on dark panels
            rows.append(dict(cls=c, rgb=rgb, muted=m, dark=dark))
    rows.sort(key=lambda x: L.CLASSES.index(x["cls"]))
    with open(os.path.join(HERE, "accents.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["class", "blizzard_class_color", "muted_accent", "muted_accent_rgb01", "dark_tint", "contrast_on_#0f0f10"])
        for x in rows:
            w.writerow([x["cls"], hexs(x["rgb"]), hexs(x["muted"]),
                        "{ %.3f, %.3f, %.3f }" % tuple(v / 255 for v in x["muted"]), hexs(x["dark"]),
                        "%.1f" % contrast(x["muted"], PANEL)])
    # swatch sheet
    W, rowh, pad = 600, 58, 8
    f12, f14 = L.font(12), L.font(14)
    img = Image.new("RGB", (W, 40 + rowh * (len(rows) + 1) + pad), PANEL)
    d = ImageDraw.Draw(img)
    d.text((pad, 10), "Klassenfarbe (Blizzard)  ->  gedämpfter Akzent (Helligkeit/Sättigung wie Surf Green)", fill=(210, 208, 200), font=f14)
    allrows = [dict(cls="mUI", rgb=SURF, muted=SURF, dark=tuple(round(v * 0.35) for v in SURF))] + rows
    for n, x in enumerate(allrows):
        y = 40 + n * rowh
        name = "Surf Green (heute)" if x["cls"] == "mUI" else NAMES[x["cls"]]
        d.text((pad, y + 20), name, fill=(210, 208, 200), font=f12)
        d.rectangle((140, y + 6, 190, y + rowh - 10), fill=x["rgb"])
        d.text((140, y + rowh - 10), hexs(x["rgb"]), fill=(120, 120, 120), font=f12)
        d.rectangle((200, y + 6, 250, y + rowh - 10), fill=x["muted"])
        d.text((200, y + rowh - 10), hexs(x["muted"]), fill=(120, 120, 120), font=f12)
        # mini mUI panel: dark bg, 1-px accent border, title in accent, accent bar + selection
        px = 270
        d.rectangle((px, y + 4, W - pad, y + rowh - 6), fill=(22, 22, 23), outline=(45, 45, 46))
        d.line((px, y + 4, W - pad, y + 4), fill=x["muted"])
        d.text((px + 8, y + 9), "MeredanUI", fill=(233, 230, 221), font=f14)
        d.text((px + 92, y + 9), "Einstellungen", fill=x["muted"], font=f14)
        d.rectangle((px + 8, y + 32, px + 150, y + 40), fill=(38, 38, 40))
        d.rectangle((px + 8, y + 32, px + 110, y + 40), fill=x["muted"])
        d.rectangle((px + 170, y + 28, px + 310, y + 44), fill=x["dark"], outline=x["muted"])
        d.text((px + 178, y + 30), "Auswahl", fill=(233, 230, 221), font=f12)
    img.save(os.path.join(HERE, "previews", "class_accents.jpg"), quality=90)
    for x in rows:
        print(x["cls"], hexs(x["rgb"]), hexs(x["muted"]), "%.1f" % contrast(x["muted"], PANEL))


if __name__ == "__main__":
    main()
