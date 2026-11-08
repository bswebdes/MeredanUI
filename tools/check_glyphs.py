#!/usr/bin/env python3
"""Prüft, ob alle Sonderzeichen in den Lua-Texten von mUI in unseren Schriften vorhanden sind.

Hintergrund (Benny 2026-11-07): Zeichen, die die Schrift nicht kennt (✓, ⌀ …), erscheinen im Spiel
als leeres Rechteck. Das Skript liest die Zeichentabelle (cmap) direkt aus den TTF-Dateien – ohne
Zusatzpakete – und meldet jedes Nicht-ASCII-Zeichen in Lua-Strings, das in einer der mUI-Schriften
fehlt. Kommentare werden übersprungen. Läuft automatisch bei ./deploy.sh MeredanUI.

Aufruf: python3 tools/check_glyphs.py   (Exit-Code 1 bei Funden)
"""
import os
import re
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = ["Media/Fonts/mUI.ttf", "Media/Fonts/mUI-Text.ttf", "Media/Fonts/mUI-Bold.ttf"]
SKIP_DIRS = {"Libs", "libs", ".git", "tools", "tests"}
# Locale-Blöcke anderer Sprachen (z. B. Kyrillisch) nicht prüfen – nur Englisch und Deutsch
OTHER_LOCALE = re.compile(r'GetLocale\(\)\s*==\s*"(?!deDE)')


def cmap_codepoints(path):
    data = open(path, "rb").read()
    num_tables = struct.unpack(">H", data[4:6])[0]
    tables = {}
    for i in range(num_tables):
        tag, _, offset, length = struct.unpack(">4sIII", data[12 + 16 * i: 28 + 16 * i])
        tables[tag.decode("latin-1")] = offset
    base = tables["cmap"]
    count = struct.unpack(">H", data[base + 2: base + 4])[0]
    points = set()
    for i in range(count):
        _, _, offset = struct.unpack(">HHI", data[base + 4 + 8 * i: base + 12 + 8 * i])
        sub = base + offset
        fmt = struct.unpack(">H", data[sub: sub + 2])[0]
        if fmt == 4:
            seg2 = struct.unpack(">H", data[sub + 6: sub + 8])[0]
            segs = seg2 // 2
            ends = struct.unpack(">%dH" % segs, data[sub + 14: sub + 14 + seg2])
            starts = struct.unpack(">%dH" % segs, data[sub + 16 + seg2: sub + 16 + 2 * seg2])
            deltas = struct.unpack(">%dh" % segs, data[sub + 16 + 2 * seg2: sub + 16 + 3 * seg2])
            ro_pos = sub + 16 + 3 * seg2
            ranges = struct.unpack(">%dH" % segs, data[ro_pos: ro_pos + seg2])
            for s in range(segs):
                for c in range(starts[s], ends[s] + 1):
                    if c == 0xFFFF:
                        continue
                    if ranges[s] == 0:
                        glyph = (c + deltas[s]) & 0xFFFF
                    else:
                        addr = ro_pos + 2 * s + ranges[s] + 2 * (c - starts[s])
                        glyph = struct.unpack(">H", data[addr: addr + 2])[0]
                        if glyph:
                            glyph = (glyph + deltas[s]) & 0xFFFF
                    if glyph:
                        points.add(c)
        elif fmt == 12:
            groups = struct.unpack(">I", data[sub + 12: sub + 16])[0]
            for g in range(groups):
                start, end, _ = struct.unpack(">III", data[sub + 16 + 12 * g: sub + 28 + 12 * g])
                points.update(range(start, end + 1))
    return points


def strip_comments(line, in_block):
    """Gibt (Code ohne Kommentare, noch in Blockkommentar?) zurück – grob, reicht für unseren Code."""
    out, i, n = [], 0, len(line)
    quote = None
    while i < n:
        if in_block:
            end = line.find("]]", i)
            if end < 0:
                return "".join(out), True
            i, in_block = end + 2, False
            continue
        ch = line[i]
        if quote:
            out.append(ch)
            if ch == "\\":
                if i + 1 < n:
                    out.append(line[i + 1])
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in "\"'":
            quote = ch
            out.append(ch)
            i += 1
            continue
        if line.startswith("--[[", i):
            in_block = True
            i += 4
            continue
        if line.startswith("--", i):
            break
        out.append(ch)
        i += 1
    return "".join(out), in_block


def main():
    missing_any = set()
    fonts = {}
    for font in FONTS:
        fonts[font] = cmap_codepoints(os.path.join(ROOT, font))
    findings = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if not name.endswith(".lua"):
                continue
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, ROOT)
            in_block, skip_locale = False, False
            with open(path, encoding="utf-8") as fh:
                for number, line in enumerate(fh, 1):
                    if OTHER_LOCALE.search(line):
                        skip_locale = True
                    elif skip_locale and re.match(r"^(end|if )", line):
                        skip_locale = line.startswith("if ") and bool(OTHER_LOCALE.search(line))
                    code, in_block = strip_comments(line, in_block)
                    if skip_locale:
                        continue
                    for ch in set(code):
                        cp = ord(ch)
                        if cp < 128:
                            continue
                        lacking = [os.path.basename(f) for f, pts in fonts.items() if cp not in pts]
                        if lacking:
                            findings.append((rel, number, ch, cp, lacking))
                            missing_any.add(ch)
    if not findings:
        print("Glyphen: alle Sonderzeichen sind in den mUI-Schriften vorhanden.")
        return 0
    print("Glyphen: %d Stelle(n) mit Zeichen, die in einer mUI-Schrift fehlen (im Spiel = leeres Rechteck):" % len(findings))
    for rel, number, ch, cp, lacking in sorted(findings):
        print("  %s:%d  %r U+%04X  fehlt in: %s" % (rel, number, ch, cp, ", ".join(lacking)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
