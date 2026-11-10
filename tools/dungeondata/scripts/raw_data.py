"""Load and normalise the raw guide extracts (one JSON per instance) - tolerant of small schema slips."""
import json, pathlib

def _int(v):
    try: return int(v)
    except (TypeError, ValueError): return None

def _loot(rows):
    out = []
    for l in rows or []:
        if isinstance(l, int): l = {"item_id": l}
        elif not isinstance(l, dict): continue
        out.append({"item_id": _int(l.get("item_id")), "name": l.get("name"), "slot": l.get("slot"),
                    "chance": l.get("chance"), "quest_item": bool(l.get("quest_item"))})
    return out

def load(path):
    d = json.loads(pathlib.Path(path).read_text())
    for b in d.get("bosses") or []:
        ids = b.get("npc_ids")
        if ids is None and b.get("npc_id") is not None: ids = [b["npc_id"]]
        if isinstance(ids, int): ids = [ids]
        b["npc_ids"] = [i for i in (_int(x) for x in ids or []) if i]
        b["loot"] = _loot(b.get("loot"))
    for r in d.get("rares") or []:
        if isinstance(r, str): r = {"name": r}
        ids = r.get("npc_ids") or ([r["npc_id"]] if r.get("npc_id") else [])
        if isinstance(ids, int): ids = [ids]
        r["npc_ids"] = [i for i in (_int(x) for x in ids) if i]
        r["loot"] = _loot(r.get("loot"))
    d["rares"] = [r for r in d.get("rares") or [] if isinstance(r, dict)]
    qs = []
    for q in d.get("quests") or []:
        if not isinstance(q, dict): continue
        q["quest_id"] = _int(q.get("quest_id"))
        q["giver_npc_id"] = _int(q.get("giver_npc_id"))
        q["rewards"] = [i for i in (_int(r if not isinstance(r, dict) else r.get("item_id")) for r in q.get("rewards") or []) if i]
        qs.append(q)
    d["quests"] = qs
    return d

def load_all(folder):
    out = {}
    for f in sorted(pathlib.Path(folder).glob("*.json")):
        d = load(f)
        out[str(d.get("key", f.stem))] = d
    return out
