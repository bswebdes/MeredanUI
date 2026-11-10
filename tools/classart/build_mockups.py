#!/usr/bin/env python3
"""Mockups of the proposed optional class theme in mUI's flat style (dark panels, 1-px borders,
accent line). Only game artwork from the Forever client + flat drawing. Writes previews/mock_*.jpg.

usage: python3 build_mockups.py   (run build_accents.py first for accents.csv)
"""
import csv
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

import classart_lib as L

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "previews")
PANEL = (15, 15, 16)
FIELD = (26, 26, 28)
EDGE = (48, 48, 50)
TEXT = (233, 230, 221)
MUTED = (153, 150, 143)
SURF = (0x8e, 0xcb, 0xb4)
NAMES = {"warrior": "Krieger", "paladin": "Paladin", "hunter": "Jäger", "rogue": "Schurke", "priest": "Priester",
         "shaman": "Schamane", "mage": "Magier", "warlock": "Hexenmeister", "druid": "Druide"}


def accents():
    out = {}
    with open(os.path.join(HERE, "accents.csv")) as f:
        for r in csv.DictReader(f):
            h = r["muted_accent"].lstrip("#")
            out[r["class"]] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return out


def tint(img, color, alpha):
    """desaturate, use luminance as mask, colorize with accent, scale alpha"""
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    lum = (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255
    lum = np.clip(lum / max(lum.max(), 1e-3), 0, 1)
    out = np.zeros_like(a)
    for i in range(3):
        out[..., i] = color[i] * (0.35 + 0.65 * lum)
    out[..., 3] = a[..., 3] * alpha
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def darken(img, f):
    rgb = ImageEnhance.Brightness(img.convert("RGBA")).enhance(f)
    return rgb


def box(d, xy, fill=FIELD, edge=EDGE):
    d.rectangle(xy, fill=fill, outline=edge)


def window(w, h, accent, title, sub=None):
    img = Image.new("RGB", (w, h), (8, 8, 9))
    d = ImageDraw.Draw(img)
    box(d, (0, 0, w - 1, h - 1), PANEL)
    d.rectangle((0, 0, w - 1, 1), fill=accent)
    d.text((14, 12), title, fill=TEXT, font=L.font(16, True))
    if sub:
        d.text((14, 34), sub, fill=MUTED, font=L.font(12))
    return img, d


def paste_fit(dst, src, box_xy, mode="cover"):
    x0, y0, x1, y1 = box_xy
    bw, bh = x1 - x0, y1 - y0
    s = (max if mode == "cover" else min)(bw / src.width, bh / src.height)
    im = src.resize((max(1, round(src.width * s)), max(1, round(src.height * s))), Image.LANCZOS)
    if mode == "cover":
        l, t = (im.width - bw) // 2, (im.height - bh) // 2
        im = im.crop((l, t, l + bw, t + bh))
        dst.paste(im, (x0, y0), im)
    else:
        dst.paste(im, (x0 + (bw - im.width) // 2, y0 + (bh - im.height) // 2), im)


def circle(src, size):
    im = src.convert("RGBA").resize((size * 4, size * 4), Image.LANCZOS)
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, im.width - 1, im.height - 1), fill=255)
    im.putalpha(mask)
    return im.resize((size, size), Image.LANCZOS)


def mock_watermarks(acc):
    """bronze crest, desaturated + tinted with the muted class accent, ~20% alpha, on a flat panel"""
    cw, ch, pad = 192, 150, 6
    img = Image.new("RGB", (600, 26 + 3 * (ch + pad) + pad), (8, 8, 9))
    d = ImageDraw.Draw(img)
    d.text((pad, 6), "Wappen als Wasserzeichen: Bronze-Wappen entsättigt, Akzent getönt, 22 % Deckkraft", fill=TEXT, font=L.font(13))
    for n, c in enumerate(L.CLASSES):
        x, y = pad + (n % 3) * (cw + pad), 26 + (n // 3) * (ch + pad)
        sub = Image.new("RGB", (cw, ch), PANEL)
        sd = ImageDraw.Draw(sub)
        sd.rectangle((0, 0, cw - 1, ch - 1), outline=EDGE)
        sd.rectangle((0, 0, cw - 1, 1), fill=acc[c])
        crest = L.atlas_image(f"legionmission-landingpage-background-{c}")
        paste_fit(sub, tint(crest, acc[c], 0.22), (40, 14, cw - 40, ch - 8), "contain")
        sd.text((10, 10), NAMES[c], fill=acc[c], font=L.font(13, True))
        sd.text((10, ch - 22), "Stufe 60", fill=MUTED, font=L.font(11))
        img.paste(sub, (x, y))
    img.save(os.path.join(OUT, "mock_watermarks.jpg"), quality=86)


def mock_character(acc, c="mage"):
    a = acc[c]
    img, d = window(600, 380, a, "Meredan", f"Stufe 60 {NAMES[c]}  ·  <Gilde>")
    # header crest: round class icon 36 px with 1-px accent ring
    icon = circle(L.atlas_image(f"ui-hud-unitframe-player-portrait-classicon-{c}-2x"), 34)
    img.paste(icon, (600 - 14 - 34 - 34, 10), icon)
    d.ellipse((600 - 14 - 34 - 35, 9, 600 - 14 - 34, 44), outline=a)
    d.text((600 - 30, 16), "×", fill=MUTED, font=L.font(16))
    # left: model area with dressing room background darkened
    x0, y0, x1, y1 = 14, 58, 330, 366
    bg = darken(L.atlas_image(f"dressingroom-background-{c}"), 0.42)
    paste_fit(img, bg, (x0, y0, x1, y1))
    d.rectangle((x0, y0, x1, y1), outline=EDGE)
    for i in range(8):  # gear slots flat
        d.rectangle((x0 + 6, y0 + 8 + i * 37, x0 + 38, y0 + 40 + i * 37), fill=FIELD, outline=EDGE)
        d.rectangle((x1 - 38, y0 + 8 + i * 37, x1 - 6, y0 + 40 + i * 37), fill=FIELD, outline=EDGE)
    d.text((x0 + 120, y0 + 140), "(3D-Modell)", fill=MUTED, font=L.font(12))
    # right: stats pane on the Forever c60 class background
    x0, x1 = 340, 586
    bg = L.atlas_image(f"ui-character-info-{c}-bg-c60")
    paste_fit(img, bg, (x0, y0, x1, y1))
    d.rectangle((x0, y0, x1, y1), outline=EDGE)
    rows = [("Attribute", None), ("Stärke", "41"), ("Beweglichkeit", "52"), ("Ausdauer", "212"), ("Intelligenz", "289"),
            ("Willenskraft", "188"), ("Zauber", None), ("Zaubermacht", "412"), ("Kritisch", "6,8 %"), ("Trefferchance", "4 %")]
    y = y0 + 10
    for k, v in rows:
        if v is None:
            d.text((x0 + 12, y), k, fill=a, font=L.font(13, True))
            y += 22
        else:
            d.text((x0 + 12, y), k, fill=TEXT, font=L.font(12))
            d.text((x1 - 12 - d.textlength(v, font=L.font(12)), y), v, fill=TEXT, font=L.font(12))
            y += 20
    img.save(os.path.join(OUT, "mock_character.jpg"), quality=86)


def mock_talents(acc, c="warlock"):
    a = acc[c]
    trees = [(n, b, ic) for n, b, ic in L_trees()[c]]
    img, d = window(600, 330, a, "Talente", f"{NAMES[c]}  ·  51 Punkte verteilt")
    cw = (600 - 28 - 12) // 3
    for i, (name, base, icon_id) in enumerate(trees):
        x0, y0 = 14 + i * (cw + 6), 58
        x1, y1 = x0 + cw, 316
        parts = [L.texture(L.fdid_of(f"Interface/TalentFrame/{base}-{p}")) for p in ("TopLeft", "TopRight", "BottomLeft", "BottomRight")]
        tl, tr, bl, br = parts
        q = Image.new("RGBA", (tl.width + tr.width, tl.height + bl.height))
        q.paste(tl, (0, 0)); q.paste(tr, (tl.width, 0)); q.paste(bl, (0, tl.height)); q.paste(br, (tl.width, tl.height))
        q = q.crop((0, 0, 296, 330))  # visible part of the classic frame
        paste_fit(img, darken(q, 0.38), (x0, y0, x1, y1))
        d.rectangle((x0, y0, x1, y1), outline=EDGE)
        ic = L.texture(icon_id).crop((5, 5, 59, 59)).resize((20, 20), Image.LANCZOS)
        img.paste(ic, (x0 + 8, y0 + 8))
        d.rectangle((x0 + 7, y0 + 7, x0 + 28, y0 + 28), outline=EDGE)
        d.text((x0 + 36, y0 + 10), name, fill=TEXT, font=L.font(13, True))
        d.text((x1 - 30, y0 + 10), ("31", "15", "5")[i], fill=a, font=L.font(13, True))
        for r in range(4):  # flat talent buttons
            for k in range(4):
                if (r + k + i) % 3 == 1:
                    continue
                bx, by = x0 + 22 + k * 40, y0 + 46 + r * 52
                on = (r * 4 + k) % 5 != 0 and r < 4 - i
                d.rectangle((bx, by, bx + 30, by + 30), fill=(30, 30, 32), outline=a if on else EDGE)
    img.save(os.path.join(OUT, "mock_talents.jpg"), quality=86)


def mock_setup(acc, c="paladin"):
    a = acc[c]
    img = Image.new("RGB", (600, 340), PANEL)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 599, 339), outline=EDGE)
    d.rectangle((0, 0, 599, 1), fill=a)
    fid = L.fdid_of(f"Interface/Pictures/ArtifactBook-{c}-Cover")
    crest = L.texture(fid)
    paste_fit(img, tint(crest, a, 0.16), (330, 10, 590, 330), "contain")
    d.text((30, 90), "Meredan", fill=TEXT, font=L.font(34, True))
    d.text((30 + d.textlength("Meredan", font=L.font(34, True)), 90), "UI", fill=a, font=L.font(34, True))
    d.text((32, 138), f"Willkommen, Meredan – {NAMES[c]}", fill=MUTED, font=L.font(14))
    d.text((32, 178), "Klassen-Theme", fill=TEXT, font=L.font(13, True))
    d.rectangle((32, 200, 46, 214), fill=(10, 10, 11), outline=a)
    d.line((35, 207, 39, 211, 44, 202), fill=a, width=2)
    d.text((54, 200), "Wappen, Hintergründe und Akzent in Klassenfarbe", fill=TEXT, font=L.font(12))
    d.rectangle((32, 270, 182, 300), fill=(a[0] // 3, a[1] // 3, a[2] // 3), outline=a)
    d.text((62, 277), "Einrichtung starten", fill=TEXT, font=L.font(12, True))
    # class row as in a setup "class" step
    for i, cc in enumerate(L.CLASSES):
        ic = circle(L.atlas_image(f"classicon-{cc}"), 22)
        if cc != c:
            ic = ImageEnhance.Brightness(ic).enhance(0.45)
        img.paste(ic, (32 + i * 28, 236), ic)
    img.save(os.path.join(OUT, "mock_setup.jpg"), quality=86)


def mock_unitframe(acc):
    img = Image.new("RGB", (600, 200), (8, 8, 9))
    d = ImageDraw.Draw(img)
    d.text((8, 6), "Spielerrahmen mit kleinem Klassen-Icon · Tooltip mit Inline-Icon", fill=TEXT, font=L.font(13))
    for n, c in enumerate(("warrior", "druid", "shaman")):
        a = acc[c]
        x, y = 10, 32 + n * 54
        d.rectangle((x, y, x + 260, y + 44), fill=PANEL, outline=EDGE)
        d.rectangle((x + 30, y + 6, x + 254, y + 28), fill=(30, 30, 32))
        d.rectangle((x + 30, y + 6, x + 210, y + 28), fill=tuple(int(v) for v in L_classcolor(c)))
        d.rectangle((x + 30, y + 32, x + 254, y + 38), fill=(30, 30, 32))
        d.rectangle((x + 30, y + 32, x + 180, y + 38), fill=(0, 112, 221) if c != "warrior" else (200, 40, 40))
        ic = circle(L.atlas_image(f"ui-hud-unitframe-player-portrait-classicon-{c}-2x"), 20)
        img.paste(ic, (x + 5, y + 7), ic)
        d.ellipse((x + 4, y + 6, x + 25, y + 27), outline=a)
        d.text((x + 36, y + 9), "Meredan", fill=(10, 10, 10), font=L.font(12, True))
    # tooltip
    x, y = 300, 40
    d.rectangle((x, y, x + 280, y + 120), fill=PANEL, outline=EDGE)
    d.rectangle((x, y, x + 280, y + 1), fill=acc["druid"])
    d.text((x + 10, y + 10), "Meredan", fill=tuple(int(v) for v in L_classcolor("druid")), font=L.font(14, True))
    ic = L.atlas_image("groupfinder-icon-class-druid-c60").resize((16, 16), Image.LANCZOS)
    img.paste(ic, (x + 10, y + 36), ic)
    d.text((x + 32, y + 36), "Stufe 60 Nachtelf Druide", fill=TEXT, font=L.font(12))
    d.text((x + 10, y + 58), "<Gilde>", fill=acc["druid"], font=L.font(12))
    d.text((x + 10, y + 80), "Ziel: Ragnaros", fill=MUTED, font=L.font(12))
    img.save(os.path.join(OUT, "mock_unitframe.jpg"), quality=88)


def L_classcolor(c):
    for r in L.db2("ChrClasses"):
        if r["Filename"].lower() == c:
            return (int(r["ClassColorR"]), int(r["ClassColorG"]), int(r["ClassColorB"]))


def L_trees():
    import build_inventory
    return build_inventory.trees()


def main():
    acc = accents()
    mock_watermarks(acc)
    mock_character(acc)
    mock_talents(acc)
    mock_setup(acc)
    mock_unitframe(acc)
    print("ok")


if __name__ == "__main__":
    main()
