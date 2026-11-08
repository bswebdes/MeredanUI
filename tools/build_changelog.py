#!/usr/bin/env python3
"""CHANGELOG.md → Config/ChangelogData.lua (ns.CHANGELOG) für die Seite „Changelog“ im Spiel.
Läuft bei deploy.sh; die erzeugte Datei wird mit committet (der CurseForge-Packager baut aus dem Repo).
Nur die letzten MAX Versionen, Markdown-Zeichen entfernt."""
import pathlib, re, sys

MAX = 6
root = pathlib.Path(__file__).resolve().parent.parent
src = root / "CHANGELOG.md"
dst = root / "Config" / "ChangelogData.lua"

releases, cur = [], None
for line in src.read_text(encoding="utf-8").splitlines():
    m = re.match(r"^##\s+(v\S+)", line)
    if m:
        cur = {"version": m.group(1), "items": []}
        releases.append(cur)
        continue
    m = re.match(r"^\s*[-*]\s+(.*)", line)
    if m and cur is not None:
        text = re.sub(r"[*_`]", "", m.group(1)).strip()
        text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
        cur["items"].append(text)

def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

out = ["-- AUTOMATISCH ERZEUGT von tools/build_changelog.py aus CHANGELOG.md – nicht von Hand ändern.",
       "local _, ns = ...", "", "ns.CHANGELOG = {"]
for r in releases[:MAX]:
    out.append("    { version = %s, items = {" % lua(r["version"]))
    for it in r["items"]:
        out.append("        %s," % lua(it))
    out.append("    } },")
out.append("}")
new = "\n".join(out) + "\n"
if not dst.exists() or dst.read_text(encoding="utf-8") != new:
    dst.write_text(new, encoding="utf-8")
    print("Changelog-Daten aktualisiert:", dst.relative_to(root))
