# Baut die mUI-Schriften aus Blue Highway (CC0): CFF -> TrueType, umbenennen, „Text“ mit +1 % Abstand.
# Aufruf: PYTHONPATH=<fontTools> python3 tools/build_fonts.py  (Quelle: ~/wow-addons/_fonts/bluehighway, CC0)
import sys
from fontTools.ttLib import TTFont, newTable
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

SRC = "/home/benja/wow-addons/_fonts/bluehighway/"
OUT = "/home/benja/wow-addons/MeredanUI/Media/Fonts/"

from fontTools.pens.transformPen import TransformPen

class TeePen:
    """Zeichnet in die Zielfeder einmal normal und einmal um dx versetzt (Halbfett durch Verbreitern)."""
    def __init__(self, glyph, dx):
        self.glyph, self.dx = glyph, dx
    def drawTo(self, pen):
        self.glyph.draw(pen)
        if self.dx:
            self.glyph.draw(TransformPen(pen, (1, 0, 0, 1, self.dx, 0)))

def otf_to_ttf(font, max_err=1.0, embolden=0):
    order = font.getGlyphOrder()
    font["loca"] = newTable("loca")
    glyf = font["glyf"] = newTable("glyf")
    glyf.glyphOrder = order
    glyf.glyphs = {}
    gs = font.getGlyphSet()
    for name in order:
        pen = TTGlyphPen(gs)
        TeePen(gs[name], embolden).drawTo(Cu2QuPen(pen, max_err, reverse_direction=True))
        glyf[name] = pen.glyph()
    if embolden:
        # Buchstaben werden um embolden breiter; nur einen Teil davon als Vorschub, sonst wirkt der
        # Zeichenabstand zu groß (Benny 2026-11-07)
        hmtx = font["hmtx"]
        for g, (adv, lsb) in list(hmtx.metrics.items()):
            if adv > 0:
                hmtx.metrics[g] = (adv + round(embolden * ADVANCE_SHARE), lsb)
    font["head"].glyphDataFormat = 0
    maxp = font["maxp"] = newTable("maxp")
    maxp.tableVersion = 0x00010000
    for attr in ("maxZones", "maxTwilightPoints", "maxStorage", "maxFunctionDefs", "maxInstructionDefs",
                 "maxStackElements", "maxSizeOfInstructions", "maxComponentElements"):
        setattr(maxp, attr, 0)
    maxp.maxZones = 1
    maxp.maxComponentDepth = 0
    post = font["post"]
    post.formatType = 2.0
    post.extraNames = []
    post.mapping = {}
    post.glyphOrder = order
    for tag in ("CFF ", "VORG"):
        if tag in font:
            del font[tag]
    font.sfntVersion = "\x00\x01\x00\x00"

def rename(font, family, sub, full, ps):
    name = font["name"]
    note = "mUI font for MeredanUI. Based on Blue Highway by Raymond Larabie (typodermicfonts.com), released under CC0 1.0."
    for rec in list(name.names):
        if rec.nameID in (16, 17, 21, 22):
            name.removeNames(nameID=rec.nameID)
    for nid, value in ((1, family), (2, sub), (3, ps + ";mUI"), (4, full), (6, ps), (10, note)):
        name.setName(value, nid, 3, 1, 0x409)
        name.setName(value, nid, 1, 0, 0)

def track(font, percent):
    upm = font["head"].unitsPerEm
    add = round(upm * percent / 100.0)
    hmtx = font["hmtx"]
    for g, (adv, lsb) in list(hmtx.metrics.items()):
        if adv > 0:
            hmtx.metrics[g] = (adv + add, lsb)
    return add

EMBOLDEN = 50  # Einheiten (von 1000): Regular ist in WoW zu dünn (Benny 2026-11-07) – alle Grundschnitte kräftig
ADVANCE_SHARE = 0.4  # Anteil der Verbreiterung, der zum Vorschub kommt
BOLD_EXTRA = 30  # Bold noch etwas kräftiger, damit Namen über dem kräftigen Grundtext liegen
jobs = [
    ("Blue Highway Rg.otf", "mUI.ttf", ("mUI", "SemiBold", "mUI", "mUI-SemiBold"), 0),
    # Fließtext: Halbfett (Benny 2026-11-07, Regular war zu dünn) + 1 % Abstand
    ("Blue Highway Rg.otf", "mUI-Text.ttf", ("mUI Text", "SemiBold", "mUI Text SemiBold", "mUIText-SemiBold"), 0),
    ("Blue Highway Bd.otf", "mUI-Bold.ttf", ("mUI", "Bold", "mUI Bold", "mUI-Bold"), 0),
]
for src, out, names, percent in jobs:
    f = TTFont(SRC + src)
    semibold = names[1] == "SemiBold"  # mUI und mUI Text: kräftig (Regular gibt es nicht mehr)
    otf_to_ttf(f, embolden=EMBOLDEN if semibold else (BOLD_EXTRA if names[1] == "Bold" else 0))
    if semibold:
        f["OS/2"].usWeightClass = 600
    rename(f, *names)
    extra = track(f, percent) if percent else 0
    if names[1] == "Bold":
        f["OS/2"].usWeightClass = 700
        f["OS/2"].fsSelection = (f["OS/2"].fsSelection | 0x20) & ~0x40
        f["head"].macStyle |= 1
    raw = OUT + out + ".raw"
    f.save(raw)
    # Hinting (ttfautohint): ohne Hinting zeichnet WoW die Schrift bei kleinen Größen dünn und weich.
    # -a nnn: natürliches Hinting – erhält die Strichstärke (sss zog alles auf gleiche Pixel); -n: keine Notiz
    import subprocess, os
    subprocess.run(["ttfautohint", "-n", "-a", "nnn", raw, OUT + out], check=True)
    os.remove(raw)
    print(out, "ok (hinted)", "tracking", extra, "units of", f["head"].unitsPerEm)

# Zeichenabdeckung (für Chat/Glyphs.lua)
cmap = sorted(TTFont(OUT + "mUI.ttf").getBestCmap().keys())
ranges, start, prev = [], None, None
for c in cmap:
    if start is None: start = prev = c
    elif c == prev + 1: prev = c
    else: ranges.append((start, prev)); start = prev = c
ranges.append((start, prev))
print("COVER", len(cmap), ", ".join("{ 0x%X, 0x%X }" % r for r in ranges))
