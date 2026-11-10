#!/usr/bin/env python3
"""Build tools/dungeondata/ (per-instance .md/.json, proposals, README, INSTANCES) from:
- the addon's Lua data (Quests/DungeonBosses.lua, Map/DungeonPinData.lua, Map/DungeonLoot.lua, Quests/DungeonQuests.lua)
- raw guide extracts (one JSON per instance, argv[1])
- cached Wowhead Forever tooltips (tools/dungeondata/cache/, see fetch_tooltips.py)
usage: python3 -I build.py <raw folder>"""
import json, re, sys, pathlib, html
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import repo_data, raw_data, meta

HERE = pathlib.Path(__file__).resolve().parent.parent
CACHE = HERE / "cache"
OUT = HERE / "instances"
PROP = HERE / "proposed"
WH = "https://www.wowhead.com/forever"

def cache(name):
    p = CACHE / name
    return json.loads(p.read_text()) if p.exists() else {}

T_ITEM, T_NPC, T_NPC_DE, T_QUEST = cache("forever_item.json"), cache("forever_npc.json"), cache("forever_npc_3.json"), cache("forever_quest.json")
T_ZONE, T_ZONE_DE = cache("forever_zone.json"), cache("forever_zone_3.json")
BOSSES, PINS, LOOT, QUESTS = repo_data.bosses(), repo_data.pins(), repo_data.loot(), repo_data.quests()
RAW = raw_data.load_all(sys.argv[1])

def norm(s):
    s = (s or "").lower().replace("’", "'")
    s = re.sub(r"\(.*?\)", "", s)
    s = re.sub(r"\b(the|of|and)\b", " ", s)
    return re.sub(r"[^a-z0-9]+", "", s)

def loose(s):
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower().replace("’", "'"))

def strip(s):
    return html.unescape(re.sub(r"<[^>]+>", " ", s or "")).strip()

def item_missing(iid):
    t = T_ITEM.get(str(iid))
    return bool(t and "404" in t.get("error", ""))

def item_info(iid):
    t = T_ITEM.get(str(iid))
    if not t or "error" in t or not t.get("name"):
        return None
    tip = t.get("tooltip", "")
    slot = None
    m = re.search(r'<table width="100%"><tr><td>(.*?)</td><th>(.*?)</th>', tip)
    if m:
        slot = " ".join(x for x in (strip(m.group(1)), strip(m.group(2))) if x)
    else:
        m = re.search(r"<br />(Neck|Back|Finger|Trinket|Held In Off-hand|Relic|Shirt|Tabard|Ranged|Thrown|\d+ Slot [^<]*)<", tip)
        if m: slot = m.group(1)
    if "Quest Item" in tip and not slot: slot = "Quest Item"
    by = re.search(r"Dropped by: ([^<]*)", tip)
    ch = re.search(r"Drop Chance: ([\d.]+)%", tip)
    return {"name": t["name"], "quality": t.get("quality"), "slot": slot,
            "dropped_by": html.unescape(by.group(1)).strip() if by else None,
            "chance": float(ch.group(1)) if ch else None}

def npc_info(nid, de=False):
    t = (T_NPC_DE if de else T_NPC).get(str(nid))
    if not t or "error" in t or not t.get("name"):
        return None
    return {"name": t["name"], "zone": (t.get("map") or {}).get("zone")}

def quest_info(qid):
    t = T_QUEST.get(str(qid))
    if not t or "error" in t or not t.get("name"):
        return None
    m = re.search(r"Level (\d+)", t.get("tooltip", ""))
    return {"title": t["name"], "level": int(m.group(1)) if m else None}

def pct(v):
    if v is None: return None
    if isinstance(v, (int, float)): return float(v)
    m = re.search(r"([\d.]+)\s*%", str(v)) or re.fullmatch(r"\s*([\d.]+)\s*", str(v))
    return float(m.group(1)) if m else None

def fmt(v):
    return "" if v is None else ("%g" % round(v, 2))

def md_cell(s):
    return str("" if s is None else s).replace("|", "/").replace("\n", " ")

def match_encounter(name, encs, used):
    n = norm(name)
    for eid, en, de in encs:
        if eid not in used and norm(en) == n: return eid
    for eid, en, de in encs:
        e = norm(en)
        if eid not in used and e and n and (e in n or n in e): return eid
    return None

RACE = {"alliance": 77, "horde": 178}

# Guide boss name -> DungeonEncounter ID where the names differ (checked by hand; each adds an open question)
ALIASES = {
    (3065, "Magmatus"): (3495, "Guide and Wowhead's dungeon journal call boss 2 'Magmatus'; the game's DungeonEncounter 3495 is 'Infurnus'. Same boss renamed? Check the name in game."),
    (48, "Gelihast"): (2914, "DungeonEncounter 2914 is spelled 'Geilhast' in the English game data (German: Gelihast); NPC name is Gelihast. Typo in Blizzard's data - panel shows the encounter name."),
    (3039, "Overlord Mugg"): (3451, "Guide says 'Overlord Mugg', game data 'Overseer Mugg' (3451). Check name in game."),
    (2970, "Deathless Marrow"): (3478, "Guide 'Deathless Marrow' mapped to encounter 3478 'Deathless Guardians' (assumed same fight). Check in game."),
    (289, "Kirtonos the Herald"): (2805, "Kirtonos the Herald = encounter 2805 'Kirtonos'."),
}

def build_instance(row):
    key, slug, kind, name_en, level, zone, faction, status, status_note, sources, new = row
    raw = RAW.get(str(key)) or {}
    mid = key if isinstance(key, int) else None
    encs = BOSSES.get(mid, []) if mid else []
    pins = PINS.get(mid, []) if mid else []
    repo_loot = LOOT.get(mid, {}) if mid else {}
    repo_q = QUESTS.get(mid, []) if mid else []
    open_q, notes = [], []

    # ---- bosses
    used, bosses = set(), []
    pre = {}
    for i, b in enumerate(raw.get("bosses", [])):  # pass 0: known renames (see ALIASES)
        a = ALIASES.get((mid, b.get("name")))
        if a and any(e[0] == a[0] for e in encs):
            pre[i] = a[0]; used.add(a[0]); open_q.append(a[1])
    for i, b in enumerate(raw.get("bosses", [])):  # pass 1: exact names
        for eid, en, de in encs:
            if eid not in used and norm(en) == norm(b.get("name")):
                pre[i] = eid; used.add(eid); break
    for i, b in enumerate(raw.get("bosses", [])):  # pass 2: partial names
        if i not in pre:
            eid = match_encounter(b.get("name"), encs, used)
            if eid: pre[i] = eid; used.add(eid)
    for i, b in enumerate(raw.get("bosses", [])):
        eid = pre.get(i)
        enc = next((e for e in encs if e[0] == eid), None)
        npcs = []
        for nid in b["npc_ids"]:
            info = npc_info(nid)
            de = npc_info(nid, True)
            npcs.append({"id": nid, "wowhead_name": info and info["name"], "zone": info and info["zone"],
                         "name_de": de and de["name"],
                         "name_ok": bool(info and loose(info["name"]) and (loose(info["name"]) in loose(b.get("name")) or loose(b.get("name")) in loose(info["name"]) or norm(info["name"]) in norm(b.get("name"))))})
        pin = next((p for p in pins if p["kind"] == "boss" and p["id"] == eid), None) if eid else None
        bosses.append({"order": b.get("order"), "wing": b.get("wing"), "name": b.get("name"),
                       "name_de": enc[2] if enc else (npcs[0]["name_de"] if len(npcs) == 1 else None),
                       "encounter_id": eid, "npcs": npcs, "location": b.get("location"),
                       "optional": b.get("optional"),
                       "pin": pin and {"floor": pin["floor"], "x": pin["x"], "y": pin["y"]}, "loot_raw": b["loot"]})
        if not eid and mid:
            open_q.append(f"Boss '{b.get('name')}' (guide) has no DungeonEncounter in DungeonBosses.lua - renamed, trash-boss or event boss?")
        for n in npcs:
            if n["wowhead_name"] is None:
                open_q.append(f"NPC {n['id']} ({b.get('name')}) not found on Wowhead Forever - check ID.")
            elif not n["name_ok"]:
                open_q.append(f"NPC {n['id']} is '{n['wowhead_name']}' on Wowhead Forever, guide says '{b.get('name')}'.")
        if eid and not pin and mid:
            open_q.append(f"No pin for '{b.get('name')}' (encounter {eid}) in DungeonPinData.lua.")
    for eid, en, de in encs:  # encounters that are part of a grouped guide entry ("Green Dragons (A, B, C)")
        if eid in used: continue
        for b in bosses:
            if loose(en) and loose(en) in loose(b["name"]):
                used.add(eid); b.setdefault("group_encounters", []).append(eid)
                pin = next((p for p in pins if p["kind"] == "boss" and p["id"] == eid), None)
                b.setdefault("group_pins", []).append({"encounter_id": eid, "name": en, "pin": pin and {"floor": pin["floor"], "x": pin["x"], "y": pin["y"]}})
                break
    rare_names = {norm(r.get("name")) for r in raw.get("rares", [])}
    for eid, en, de in encs:
        if eid not in used and norm(en) in rare_names:
            used.add(eid)
            open_q.append(f"Encounter {eid} '{en}' is listed as a rare in the guide (DungeonBosses.lua has it as boss).")
    for eid, en, de in encs:
        if eid not in used:
            bosses.append({"order": None, "wing": None, "name": en, "name_de": de, "encounter_id": eid, "npcs": [],
                           "location": None, "optional": None, "loot_raw": [],
                           "pin": (lambda p: p and {"floor": p["floor"], "x": p["x"], "y": p["y"]})(next((p for p in pins if p["kind"] == "boss" and p["id"] == eid), None))})
            if raw:
                open_q.append(f"Encounter {eid} '{en}' is in DungeonBosses.lua but not in the guide's boss list - check in game.")
    # rares
    rares = []
    for r in raw.get("rares", []):
        nid = r["npc_ids"][0] if r["npc_ids"] else None
        info = npc_info(nid) if nid else None
        pin = next((p for p in pins if p["kind"] == "rare" and p["id"] == nid), None) if nid else None
        rares.append({"name": r.get("name"), "npc_id": nid, "wowhead_name": info and info["name"],
                      "location": r.get("location"), "pin": pin and {"floor": pin["floor"], "x": pin["x"], "y": pin["y"]},
                      "loot_raw": r["loot"]})
    for p in pins:
        if p["kind"] == "rare" and not any(r["npc_id"] == p["id"] for r in rares):
            rares.append({"name": p["name"], "npc_id": p["id"], "wowhead_name": (npc_info(p["id"]) or {}).get("name"),
                          "location": None, "pin": {"floor": p["floor"], "x": p["x"], "y": p["y"]}, "loot_raw": []})
            if raw: open_q.append(f"Rare pin {p['id']} '{p['name']}' is not mentioned in the guide.")

    # ---- pin sanity: two different bosses (not in the same group entry) almost on the same spot
    bp = [p for p in pins if p["kind"] == "boss"]
    grouped = {e for b in bosses for e in b.get("group_encounters", [])}
    encname = {e[0]: e[1] for e in encs}
    for i in range(len(bp)):
        for j in range(i + 1, len(bp)):
            a, c = bp[i], bp[j]
            if a["floor"] == c["floor"] and abs(a["x"] - c["x"]) < 0.02 and abs(a["y"] - c["y"]) < 0.02 and not (a["id"] in grouped and c["id"] in grouped):
                open_q.append(f"Pins of '{encname.get(a['id'], a['id'])}' and '{encname.get(c['id'], c['id'])}' are almost on the same spot (floor {a['floor']}) - intended?")
    known = {e[0] for e in encs}
    for p in bp:
        if p["id"] not in known:
            open_q.append(f"Pin with encounter ID {p['id']} has no boss in DungeonBosses.lua.")

    # ---- loot (merge guide + repo + Wowhead Forever tooltip)
    def loot_rows(owner_name, raw_loot, repo_rows):
        rows, seen = [], set()
        repo = {i: c for i, c in repo_rows}
        for l in raw_loot:
            iid = l["item_id"]
            if iid in seen: continue
            if iid: seen.add(iid)
            rows.append(merge_item(owner_name, iid, l, repo.get(iid)))
        for iid, c in repo_rows:
            if iid not in seen:
                seen.add(iid)
                rows.append(merge_item(owner_name, iid, None, c))
        return rows

    def merge_item(owner, iid, g, repo_c):
        info = item_info(iid) if iid else None
        wh_by = info and info["dropped_by"]
        wh_match = bool(wh_by and norm(owner) and (norm(wh_by) in norm(owner) or norm(owner) in norm(wh_by)))
        src = []
        if g: src.append("guide")
        if repo_c is not None: src.append("repo")
        if info and info["chance"] is not None: src.append("wowhead-forever")
        # Forever-confirmed = named for this boss by a Forever guide, or a new Forever item that Wowhead Forever
        # ties to this boss. Wowhead Forever drop chances alone are NOT proof: Wowhead shows them even for raids
        # that are not open in Forever (probably imported classic statistics).
        confirmed = bool(g) or bool(wh_match and iid and iid >= 250000)
        return {"item_id": iid, "name": (info and info["name"]) or (g and g.get("name")),
                "slot": (g and g.get("slot")) or (info and info["slot"]),
                "quality": info and info["quality"], "quest_item": bool(g and g.get("quest_item")),
                "chance_guide": pct(g and g.get("chance")), "chance_wowhead_forever": info and info["chance"] if wh_match else None,
                "wowhead_dropped_by": wh_by, "chance_repo": repo_c, "in_guide": bool(g), "in_repo": repo_c is not None,
                "forever_confirmed": confirmed and not item_missing(iid), "not_on_wowhead_forever": item_missing(iid) if iid else False,
                "sources": src}

    for b in bosses:
        b["loot"] = loot_rows(b["name"], b.pop("loot_raw"), repo_loot.get(str(b["encounter_id"]), []) if b["encounter_id"] else [])
    for r in rares:
        enc_r = next((e[0] for e in encs if norm(e[1]) == norm(r["name"])), None)
        r["encounter_id"] = enc_r
        r["loot"] = loot_rows(r["name"], r.pop("loot_raw"), repo_loot.get(f"rare:{r['npc_id']}", []) + (repo_loot.get(str(enc_r), []) if enc_r else []))

    loot_diffs = []
    for b in bosses + rares:
        for l in b["loot"]:
            if l["quest_item"]: continue
            if l["in_guide"] and not l["in_repo"] and repo_loot:
                loot_diffs.append(f"{b['name']}: {l['item_id']} {l['name']} - in Forever guide, missing in DungeonLoot.lua")
            elif l["in_repo"] and not l["in_guide"] and raw:
                note = f" (Wowhead Forever: {fmt(l['chance_wowhead_forever'])}%)" if l["chance_wowhead_forever"] else (" (Wowhead Forever: no drop data)" if not l["wowhead_dropped_by"] else f" (Wowhead Forever says dropped by {l['wowhead_dropped_by']})")
                loot_diffs.append(f"{b['name']}: {l['item_id']} {l['name']} - in DungeonLoot.lua, not in guide{note}")
            ref = l["chance_wowhead_forever"] if l["chance_wowhead_forever"] is not None else l["chance_guide"]
            if l["in_repo"] and ref is not None and l["chance_repo"] is not None:
                a, c = l["chance_repo"], ref
                if abs(a - c) >= 10 and (max(a, c) / max(min(a, c), 0.1)) >= 1.5:
                    loot_diffs.append(f"{b['name']}: {l['item_id']} {l['name']} - chance repo {fmt(a)}% vs Forever {fmt(c)}%")
            if l["wowhead_dropped_by"] and not (l["chance_wowhead_forever"] is not None) and l["in_repo"]:
                loot_diffs.append(f"{b['name']}: {l['item_id']} {l['name']} - Wowhead Forever lists it as dropped by '{l['wowhead_dropped_by']}'")
    for b in bosses + rares:
        for l in b["loot"]:
            if l["not_on_wowhead_forever"]:
                loot_diffs.append(f"{b['name']}: {l['item_id']} {l['name'] or ''} - item does NOT exist on Wowhead Forever (404): removed, replaced or not datamined yet")
    for k in repo_loot:
        if k.startswith("rare:") and not any(f"rare:{r['npc_id']}" == k for r in rares):
            loot_diffs.append(f"DungeonLoot.lua has {k} but no rare with that NPC")

    # ---- quests
    quests, guide_ids = [], set()
    repo_ids = {q["id"] for q in repo_q}
    for q in raw.get("quests", []):
        qid = q["quest_id"]
        if qid: guide_ids.add(qid)
        info = quest_info(qid) if qid else None
        fac = (q.get("faction") or "").lower()
        quests.append({"quest_id": qid, "title": q.get("title"), "level": q.get("level"), "min_level": q.get("min_level"),
                       "faction": q.get("faction"), "giver": q.get("giver"), "giver_npc_id": q.get("giver_npc_id"),
                       "giver_item_id": q.get("giver_item_id"), "giver_zone": q.get("giver_zone"), "prereq": q.get("prereq"),
                       "rewards": q.get("rewards"), "in_repo": qid in repo_ids,
                       "wowhead_title": info and info["title"], "wowhead_level": info and info["level"],
                       "races": 77 if fac.startswith("alliance") and "horde" not in fac else (178 if fac.startswith("horde") and "alliance" not in fac else 0)})
        if qid and not info:
            open_q.append(f"Quest {qid} '{q.get('title')}' not found on Wowhead Forever - check ID.")
        elif info and norm(info["title"]) != norm(q.get("title")):
            open_q.append(f"Quest {qid}: guide title '{q.get('title')}', Wowhead Forever '{info['title']}'.")
    missing_q = [q for q in quests if q["quest_id"] and not q["in_repo"]]
    extra_q = [q for q in repo_q if q["id"] not in guide_ids] if raw else []

    for n in raw.get("notes", []) or []:
        notes.append(str(n))
    data = {"key": key, "slug": slug, "kind": kind, "name_en": name_en, "level": level, "zone": zone,
            "faction": faction, "status": status, "status_note": status_note, "sources": sources,
            "guide_sources": raw.get("source_urls", []), "new_in_forever": new,
            "keys_attunement": raw.get("keys_attunement"), "forever_changes": raw.get("forever_changes", []),
            "bosses": sorted(bosses, key=lambda b: (b["order"] is None, b["order"] or 0)), "rares": rares,
            "quests": quests, "repo_quests_not_in_guide": [{"id": q["id"], "title": q["title"], "level": q["level"]} for q in extra_q],
            "loot_differences": loot_diffs, "open_questions": open_q, "guide_notes": notes}
    return data

# ------------------------------------------------------------------ output
def write_md(d):
    L = []
    k = d["key"]
    L.append(f"# {d['name_en']} ({'map ' + str(k) if isinstance(k, int) else 'map ID unknown'})\n")
    L.append(f"- Level: {d['level']} · Entrance: {d['zone']} · Faction: {d['faction']}")
    L.append(f"- Status: **{d['status']}** - {d['status_note']}")
    L.append("- Sources: " + ", ".join(d["sources"] + d["guide_sources"]))
    L.append("- Item/NPC/quest checks: Wowhead Forever tooltips (`" + WH + "/item=ID`), fetched " + "2026-11-10")
    if d.get("keys_attunement"): L.append(f"- Keys / attunement: {md_cell(d['keys_attunement'])}")
    L.append("")
    L.append("## Bosses (kill order from the guide)\n")
    L.append("| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |")
    L.append("|---|---|---|---|---|---|---|---|")
    for b in d["bosses"]:
        npcs = ", ".join(f"{n['id']}" + ("" if n["name_ok"] else " ⚠") for n in b["npcs"]) or "?"
        pin = f"{b['pin']['floor']} {b['pin']['x']:.2f},{b['pin']['y']:.2f}" if b["pin"] else "—"
        opt = " (optional)" if b.get("optional") else ""
        enc = str(b['encounter_id'] or '') + (" " + "+".join(str(e) for e in b.get("group_encounters", [])) if b.get("group_encounters") else "")
        if b.get("group_pins"):
            pin = (pin + "; " if b["pin"] else "") + "; ".join(f"{g['encounter_id']}: " + (f"{g['pin']['floor']} {g['pin']['x']:.2f},{g['pin']['y']:.2f}" if g["pin"] else "—") for g in b["group_pins"])
        L.append(f"| {b['order'] or '–'} | {md_cell(b['wing'] or '')} | {md_cell(b['name'])}{opt} | {md_cell(b['name_de'] or '')} | {enc.strip() or '—'} | {npcs} | {pin} | {md_cell(b['location'] or '')} |")
    if d["rares"]:
        L.append("\n### Rares\n")
        L.append("| NPC ID | Name | Pin | Location (guide) |")
        L.append("|---|---|---|---|")
        for r in d["rares"]:
            pin = f"{r['pin']['floor']} {r['pin']['x']:.2f},{r['pin']['y']:.2f}" if r["pin"] else "—"
            L.append(f"| {r['npc_id'] or '?'} | {md_cell(r['name'])} | {pin} | {md_cell(r['location'] or '')} |")
    L.append("\n## Loot\n")
    L.append("Columns: guide % = Forever guide (some guides say their chances are classic values); WH-F % = Wowhead Forever tooltip drop chance (only when Wowhead's top source is this boss; caution: Wowhead shows such chances even for raids not open in Forever, so they are partly imported classic statistics); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (named for this boss by a Forever guide, or a new Forever item that Wowhead Forever ties to this boss). ✘ 404 = item ID does not exist on Wowhead Forever.\n")
    for b in d["bosses"] + d["rares"]:
        if not b["loot"]: continue
        L.append(f"### {b['name']}\n")
        L.append("| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |")
        L.append("|---|---|---|---|---|---|---|---|")
        for l in b["loot"]:
            name = md_cell(l["name"]) + (" (quest)" if l["quest_item"] else "")
            L.append(f"| {l['item_id'] or '?'} | {name} | {md_cell(l['slot'] or '')} | {fmt(l['chance_guide'])} | {fmt(l['chance_wowhead_forever'])} | {fmt(l['chance_repo'])} | {'✔' if l['forever_confirmed'] else ('✘ 404' if l['not_on_wowhead_forever'] else '')} | {'+'.join(l['sources'])} |")
        L.append("")
    if d["loot_differences"]:
        L.append("### Differences to Map/DungeonLoot.lua\n")
        L += [f"- {x}" for x in d["loot_differences"]]
        L.append("")
    L.append("## Quests\n")
    if d["quests"]:
        L.append("| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |")
        L.append("|---|---|---|---|---|---|---|---|")
        for q in d["quests"]:
            giver = md_cell(q["giver"] or "") + (f" ({q['giver_npc_id']})" if q["giver_npc_id"] else "") + (f" (item {q['giver_item_id']})" if q["giver_item_id"] else "")
            lvl = q["level"] if q["level"] is not None else (q["wowhead_level"] or "")
            L.append(f"| {q['quest_id'] or '?'} | {md_cell(q['title'])} | {lvl} | {md_cell(q['faction'] or '')} | {giver} | {md_cell(q['giver_zone'] or '')} | {md_cell(q['prereq'] or '')} | {'yes' if q['in_repo'] else '**no**'} |")
    else:
        L.append("No quest data collected.")
    if d["repo_quests_not_in_guide"]:
        L.append("\nIn DungeonQuests.lua but not in the guide (check if still in Forever):\n")
        L += [f"- {q['id']} {q['title']} (level {q['level']})" for q in d["repo_quests_not_in_guide"]]
    if d["forever_changes"]:
        L.append("\n## Forever changes noted by guides\n")
        L += [f"- {md_cell(x)}" for x in d["forever_changes"]]
    L.append("\n## Open questions (check in game)\n")
    L += [f"- [ ] {x}" for x in d["open_questions"]] or ["- none found"]
    if d["guide_notes"]:
        L.append("\n## Research notes\n")
        L += [f"- {md_cell(x)}" for x in d["guide_notes"]]
    key = d["key"]
    (OUT / f"{key}_{d['slug']}.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    (OUT / f"{key}.json").write_text(json.dumps(d, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

DE_NAMES = {  # German names from the Forever client tables (Map / LFGDungeons, deDE) where the zone tooltip has none
    389: "Ragefireabgrund", 3065: "Die Halle der Thanen", 2999: "Ruinen von Lordaeron", 43: "Höhlen des Wehklagens",
    36: "Die Todesminen", 33: "Burg Shadowfang", 48: "Blackfathom-Tiefe", 34: "Das Verlies", 2998: "Ausgrabungsstätte: Sumpfland",
    2959: "Dalaran", 90: "Gnomeregan", 47: "Kral von Razorfen", 189: "Scharlachrotes Kloster", 2970: "Die versunkene Stadt",
    129: "Hügel von Razorfen", 70: "Uldaman", 209: "Zul'Farrak", 349: "Maraudon", 109: "Versunkener Tempel",
    230: "Blackrocktiefen", 429: "Düsterbruch", 229: "Blackrockspitze", 329: "Stratholme", 289: "Scholomance",
    249: "Onyxias Hort", 409: "Geschmolzener Kern", 309: "Zul'Gurub", 469: "Pechschwingenhort", 509: "Ruinen von Ahn'Qiraj",
    531: "Tempel von Ahn'Qiraj", 533: "Naxxramas"}

def write_index(all_data):
    order = {"live": 0, "announced": 1, "not-announced": 2}
    # INSTANCES.md
    L = ["# Instances in World of Warcraft: Forever", "",
         "Dungeons by level (lowest first), raids at the end. Status checked 2026-11-10.",
         "German name: zone name from Wowhead Forever (deDE) if available, else the Forever client's Map/LFGDungeons table.",
         "Level: Blizzard's range for the new dungeons; classic dungeons use the group-finder ranges quoted by guides (Blizzard has not published Forever ranges for them).", "",
         "| Map ID | Name (en) | Name (de) | Level | Location | Faction access | Status | Sources |",
         "|---|---|---|---|---|---|---|---|"]
    for d in all_data:
        de = d["zone_name_de"] or DE_NAMES.get(d["key"], "?")
        kind = " (raid)" if d["kind"] == "raid" else ""
        new = " · NEW" if d["new_in_forever"] else ""
        src = " ".join(f"[{i + 1}]({u})" for i, u in enumerate(d["sources"]))
        L.append(f"| {d['key'] if isinstance(d['key'], int) else '?'} | {d['name_en']}{kind}{new} | {de} | {d['level']} | {md_cell(d['zone'])} | {md_cell(d['faction'])} | {d['status']}: {md_cell(d['status_note'])} | {src} |")
    L += ["", "## Other instance maps in Forever's game data (not playable / not announced)", "",
          "| Map ID | Name (en) | Name (de) | Status | Note | Source |", "|---|---|---|---|---|---|"]
    for mid, en, de, st, note, src in meta.OTHER_MAPS:
        L.append(f"| {mid or '?'} | {en} | {de or '?'} | {st} | {note} | {('[link](' + src + ')') if src else 'Forever client tables (Map / DungeonEncounter)'} |")
    L += ["", "## Sources", "",
          f"- Blizzard, new dungeons overview (Oct 20, 2026): {meta.BLIZZ_DUNGEONS}",
          f"- Blizzard, raid overview (Oct 20, 2026; raids open Dec 9): {meta.BLIZZ_RAIDS}",
          f"- Roadmap coverage (no date for the classic 60 raids): {meta.ROADMAP}",
          f"- Conquest Capped dungeon list (levels): {meta.CC_OVERVIEW}",
          f"- Warcraft Tavern dungeon list (levels, datamined maps): {meta.WT_DUNGEONS}",
          "- Forever client tables (Map, LFGDungeons, DungeonEncounter, ContentTuning; product wowf) via wago.tools",
          "- Notes: the instance map IDs of Barrow Deeps and Hyjal Summit are not in the readable client tables (probably encrypted until release)."]
    (HERE / "INSTANCES.md").write_text("\n".join(L) + "\n", encoding="utf-8")
    # README.md
    R = ["# Dungeon data research (tools/dungeondata)", "",
         "Research data for finishing the in-game dungeon panel one instance at a time. **Nothing here is loaded by the addon.**",
         "Only Wailing Caverns (43) is released in the panel (`READY` in Map/DungeonPanel.lua).", "",
         "- `INSTANCES.md` - every instance in Forever with map ID, names, levels, status and sources",
         "- `instances/<mapID>_<name>.md` - bosses, pins, loot, quests, differences and open questions per instance; `instances/<mapID>.json` - same data machine-readable",
         "- `proposed/DungeonLoot.proposed.lua`, `proposed/DungeonQuests.proposed.lua` - blocks in the exact format of the real files, to copy per dungeon",
         "- `scripts/` - how it was built: `fetch_tooltips.py` (Wowhead Forever tooltips, cached in `cache/`, not committed), `build.py` (merges guide extracts + repo data + tooltips)", "",
         "Legend: ok / partial / missing = research data completeness. Bosses ok = every guide boss has a checked NPC ID (name matches Wowhead Forever) and a DungeonEncounter ID. Pins = encounters with a pin in DungeonPinData.lua. Loot ok = every boss has at least one item confirmed for Forever (named by a Forever guide or a new Forever item). Quests = quest IDs found on Wowhead Forever (number in brackets = already in DungeonQuests.lua). Forever-confirmed = share of loot rows confirmed by Forever sources (yes >= 80 %).", "",
         "| Map | Instance | Level | Status | Bosses | Pins | Loot (confirmed/rows) | Quests (in addon) | Forever-confirmed | Most important open points |",
         "|---|---|---|---|---|---|---|---|---|---|"]
    for d in all_data:
        a = d["assessment"]
        f = f"instances/{d['key']}_{d['slug']}.md"
        pts = "<br>".join(md_cell(p) for p in d["top_points"]) or "—"
        R.append(f"| {d['key'] if isinstance(d['key'], int) else '?'} | [{d['name_en']}]({f}) | {d['level']} | {d['status']} | {a['bosses']} ({a['boss_ok']}/{a['boss_count']}) | {a['pins']} ({a['pin_ok']}/{a['enc_count']}) | {a['loot']} ({a['loot_confirmed']}/{a['loot_rows']}) | {a['quests']} ({a['quests_in_addon']}/{a['q_tot']}) | {a['forever_confirmed']} | {pts} |")
    R += ["", "## General findings", ""] + [f"- {x}" for x in GENERAL] + [""]
    (HERE / "README.md").write_text("\n".join(R) + "\n", encoding="utf-8")

GENERAL = [
    "Quests: the live instances have 411 dungeon quests in the guides; 280 of them are missing in Quests/DungeonQuests.lua. build_dungeon_quests.py only finds quests whose zone is the dungeon's top area, so Deadmines, Gnomeregan, Razorfen Kraul, Uldaman, Zul'Farrak, Blackrock Depths, Blackrock Spire and all new Forever dungeons have no quest list in the addon.",
    "Bug in Quests/DungeonQuests.lua: block [0] holds 32 Dun Morogh quests. DungeonBosses.lua has a map 0 entry ('No Longer in Use'), and AreaTable's first area on continent 0 is Dun Morogh, so the quest builder treated it as a dungeon. Harmless while no dungeon has map ID 0, but the generator should skip map 0.",
    "Forever changed classic loot: about 200 new item IDs (250000+) drop from bosses of the live instances (many classic bosses got extra Forever items). These are in the guide data and in proposed/DungeonLoot.proposed.lua, but not in Map/DungeonLoot.lua.",
    "Wowhead Forever tooltips (nether.wowhead.com/forever/tooltip/item/ID) show 'Dropped by' and a drop chance. They also show chances for raids that are not open in Forever (Molten Core, AQ40), so these numbers are partly imported classic statistics - useful, but not proof.",
    "41 loot items of live dungeons (and ~400 raid items, e.g. tier sets) return 404 on Wowhead Forever (e.g. Felstriker 12590, Pip's Skinner 12709, Lord Valthalak's Staff of Command 22335). Either removed/replaced in Forever or simply not datamined yet - check in game before showing them.",
    "German instance names differ between the client tables: Map table says 'Ragefireabgrund' / 'Burg Shadowfang', the group finder table (LFGDungeons) says 'Flammenschlund' / 'Burg Schattenfang'. Wowhead's German zone names follow the Map table. Check which one the German client shows.",
    "New Forever instances have no pins yet except Hall of Thanes (3065) and partly Excavation Site (2998). Boss locations from the guides are in each instance file to help placing them with /mui pins.",
    "Shaper's Terrace (3001), Barrow Deeps and Hyjal Summit: no loot, NPC IDs or quests published by any source checked (Conquest Capped, Warcraft Tavern, Wowhead). Shaper's Terrace has 11 encounters in the game data (bosses are summoned at consoles).",
    "Sources: Conquest Capped Forever guides (read with a web reader; boss/item/quest IDs from their links), Blizzard news, Wowhead Forever tooltips for checking names/IDs. warcraft.wiki.gg blocks automated requests (HTTP 403); Wowhead pages show loot tables only with JavaScript, so loot lists came from the guides.",
]

def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'

def proposals(all_data):
    lo = ["-- PROPOSAL (not loaded by the addon). Same format as Map/DungeonLoot.lua; copy one instance block",
          "-- into the real file when that dungeon is finished. Chance = Wowhead Forever if available, else",
          "-- Forever guide, else classic table. { itemID } without chance = chance unknown.",
          "local _, ns = ...", "", "ns.DUNGEON_LOOT = {"]
    qo = ["-- PROPOSAL (not loaded by the addon). Same format as Quests/DungeonQuests.lua. New quests have no",
          "-- world position for the giver (map/x/y missing: no map pin until filled in).",
          "local _, ns = ...", "", "ns.DUNGEON_QUESTS = {"]
    for d in all_data:
        if not isinstance(d["key"], int): continue
        blocks = []
        for b in d["bosses"] + d["rares"]:
            k = b.get("encounter_id")
            key = str(k) if k else (f'"rare:{b["npc_id"]}"' if b.get("npc_id") else None)
            if not key: continue
            rows = []
            for l in b["loot"]:
                if not l["item_id"] or l["quest_item"]: continue
                c = l["chance_wowhead_forever"] if l["chance_wowhead_forever"] is not None else (l["chance_guide"] if l["chance_guide"] is not None else l["chance_repo"])
                if l["in_repo"] and not l["in_guide"] and l["chance_wowhead_forever"] is None and d["guide_sources"]:
                    continue  # classic-only item, not seen in Forever sources
                rows.append((l["item_id"], c))
            rows.sort(key=lambda r: -(r[1] or 0))
            if rows:
                blocks.append(f"        [{key}] = {{ " + ", ".join(f"{{ {i}, {fmt(c)} }}" if c is not None else f"{{ {i} }}" for i, c in rows) + " },")
        if blocks:
            lo.append(f"    [{d['key']}] = {{ -- {d['name_en']}")
            lo += blocks
            lo.append("    },")
        qs = []
        repo = {q["id"]: q for q in QUESTS.get(d["key"], [])}
        for q in sorted(d["quests"], key=lambda q: (q["level"] or q["wowhead_level"] or 0, q["quest_id"] or 0)):
            if not q["quest_id"]: continue
            if q["quest_id"] in repo:
                qs.append("        " + repo[q["quest_id"]]["line"] + ",")
                continue
            lvl = q["level"] or q["wowhead_level"] or 0
            mn = q["min_level"] or 0
            giver = f"giver = {lua_str(q['giver'])}" if q["giver"] else (f"item = {q['giver_item_id']}" if q["giver_item_id"] else 'giver = "?"')
            qs.append(f"        {{ id = {q['quest_id']}, level = {lvl}, min = {mn}, races = {q['races']}, classes = 0, title = {lua_str(q['title'])}, {giver} }}, -- NEW, giver zone: {q['giver_zone'] or '?'}")
        if qs:
            qo.append(f"    [{d['key']}] = {{ -- {d['name_en']}")
            qo += qs
            qo.append("    },")
    lo.append("}"); qo.append("}")
    PROP.mkdir(exist_ok=True)
    (PROP / "DungeonLoot.proposed.lua").write_text("\n".join(lo) + "\n", encoding="utf-8")
    (PROP / "DungeonQuests.proposed.lua").write_text("\n".join(qo) + "\n", encoding="utf-8")

def zone_of(d):
    zs = [n["zone"] for b in d["bosses"] for n in b["npcs"] if n.get("zone")]
    return max(set(zs), key=zs.count) if zs else None

def names(d):
    z = d.get("zone_id")
    en = (T_ZONE.get(str(z)) or {}).get("name") if z else None
    de = (T_ZONE_DE.get(str(z)) or {}).get("name") if z else None
    return en, de

def grade(have, total):
    if total == 0: return "missing"
    return "ok" if have >= total else ("partial" if have else "missing")

def assess(d):
    raw = bool(d["guide_sources"])
    bosses = [b for b in d["bosses"] if b["order"] is not None]
    b_ok = sum(1 for b in bosses if b["npcs"] and all(n["name_ok"] for n in b["npcs"]) and (b["encounter_id"] or not isinstance(d["key"], int)))
    enc = [b for b in d["bosses"] if b["encounter_id"]]
    p_ok = sum(1 for b in enc if b["pin"])
    l_ok = sum(1 for b in bosses if any(l["item_id"] and not l["quest_item"] and l["forever_confirmed"] for l in b["loot"]))
    q_tot = len(d["quests"]); q_ok = sum(1 for q in d["quests"] if q["quest_id"] and q["wowhead_title"])
    rows = [l for b in d["bosses"] + d["rares"] for l in b["loot"] if l["item_id"] and not l["quest_item"]]
    conf = sum(1 for l in rows if l["forever_confirmed"])
    chance = sum(1 for l in rows if l["chance_wowhead_forever"] is not None or l["chance_guide"] is not None)
    fc = "yes" if rows and conf / len(rows) >= 0.8 else ("partly" if conf else "no")
    return {"bosses": grade(b_ok, len(bosses)) if raw else ("repo only" if enc else "missing"),
            "pins": grade(p_ok, len(enc)) if enc else ("missing" if bosses else "—"),
            "loot": grade(l_ok, len(bosses)) if bosses else "missing",
            "quests": (grade(q_ok, q_tot) if q_tot else "missing"),
            "quests_in_addon": sum(1 for q in d["quests"] if q["in_repo"]),
            "loot_rows": len(rows), "loot_confirmed": conf, "loot_with_chance": chance, "forever_confirmed": fc,
            "boss_count": len(bosses), "boss_ok": b_ok, "pin_ok": p_ok, "enc_count": len(enc), "q_tot": q_tot}

def top_points(d, a):
    pts = []
    oq = d["open_questions"]
    for pref in ("has no DungeonEncounter", "No pin for", "not in the guide's boss list", "Wowhead Forever, guide says", "not found on Wowhead Forever"):
        hit = [x for x in oq if pref in x]
        if hit: pts.append(hit[0] if len(hit) == 1 else f"{hit[0]} (+{len(hit) - 1} more)")
    if a["q_tot"] and a["quests_in_addon"] < a["q_tot"]:
        pts.insert(0, f"{a['q_tot'] - a['quests_in_addon']} of {a['q_tot']} quests missing in DungeonQuests.lua")
    if a["loot_rows"] and a["loot_with_chance"] < a["loot_rows"]:
        pts.append(f"{a['loot_rows'] - a['loot_with_chance']} loot rows without drop chance")
    miss = [x for x in d["loot_differences"] if "404" in x]
    if miss: pts.append(f"{len(miss)} items not on Wowhead Forever (404)")
    return pts[:3]

def main():
    OUT.mkdir(exist_ok=True)
    all_data = [build_instance(r) for r in meta.INSTANCES]
    for d in all_data:
        d["zone_id"] = zone_of(d)
        d["zone_name_en"], d["zone_name_de"] = names(d)
        d["assessment"] = assess(d)
        d["top_points"] = top_points(d, d["assessment"])
        write_md(d)
    proposals(all_data)
    write_index(all_data)
    json.dump([{k: d[k] for k in ("key", "name_en", "status")} for d in all_data], sys.stdout)

if __name__ == "__main__":
    main()
