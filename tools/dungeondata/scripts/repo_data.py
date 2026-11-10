"""Read the addon's generated Lua data tables (bosses, pins, loot, quests) into Python dicts."""
import re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[3]

def _blocks(text):
    out = {}
    for m in re.finditer(r"^    \[(\d+)\] = \{(.*?)^    \},?$", text, re.S | re.M):
        out[int(m.group(1))] = m.group(2)
    return out

def bosses():
    t = (ROOT / "Quests/DungeonBosses.lua").read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r"^    \[(\d+)\] = \{ (.*) \},$", t, re.M):
        out[int(m.group(1))] = [(int(a), b, c) for a, b, c in
                                re.findall(r'\{ (\d+), "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)" \}', m.group(2))]
    return out

def pins():
    t = (ROOT / "Map/DungeonPinData.lua").read_text(encoding="utf-8")
    out = {}
    for inst, body in _blocks(t).items():
        rows = []
        for line in body.splitlines():
            m = re.search(r'kind = "(\w+)", id = (\d+), floor = (\d+), x = ([\d.]+), y = ([\d.]+)', line)
            if m:
                n = re.search(r'name = "([^"]*)"', line)
                rows.append({"kind": m.group(1), "id": int(m.group(2)), "floor": int(m.group(3)),
                             "x": float(m.group(4)), "y": float(m.group(5)), "name": n.group(1) if n else None})
        out[inst] = rows
    return out

def loot():
    t = (ROOT / "Map/DungeonLoot.lua").read_text(encoding="utf-8")
    out = {}
    for inst, body in _blocks(t).items():
        d = {}
        for m in re.finditer(r'^\s+\[("rare:\d+"|\d+)\] = \{ (.*) \},$', body, re.M):
            key = m.group(1).strip('"')
            d[key] = [(int(a), float(b)) for a, b in re.findall(r"\{ (\d+), ([\d.]+) \}", m.group(2))]
        out[inst] = d
    return out

def quests():
    t = (ROOT / "Quests/DungeonQuests.lua").read_text(encoding="utf-8")
    out = {}
    for inst, body in _blocks(t).items():
        rows = []
        for line in body.splitlines():
            m = re.search(r"id = (\d+), level = (-?\d+), min = (\d+), races = (\d+), classes = (\d+), title = \"((?:[^\"\\]|\\.)*)\"", line)
            if m:
                g = re.search(r'giver = "((?:[^"\\]|\\.)*)"', line)
                it = re.search(r"item = (\d+)", line)
                rows.append({"id": int(m.group(1)), "level": int(m.group(2)), "min": int(m.group(3)),
                             "races": int(m.group(4)), "classes": int(m.group(5)), "title": m.group(6),
                             "giver": g.group(1) if g else None, "item": int(it.group(1)) if it else None,
                             "line": line.strip().rstrip(",")})
        out[inst] = rows
    return out

if __name__ == "__main__":
    b, p, l, q = bosses(), pins(), loot(), quests()
    print(len(b), len(p), len(l), len(q), sum(len(v) for v in q.values()))
