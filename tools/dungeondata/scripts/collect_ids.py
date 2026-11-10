"""Collect npc / quest / item IDs from the raw guide extracts into id lists for fetch_tooltips.py."""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import raw_data
out = pathlib.Path(sys.argv[2]); npc, quest, item = [], [], []
for d in raw_data.load_all(sys.argv[1]).values():
    for b in d["bosses"] + d["rares"]:
        npc += b["npc_ids"]; item += [l["item_id"] for l in b["loot"] if l["item_id"]]
    for q in d["quests"]:
        if q["quest_id"]: quest.append(q["quest_id"])
        if q["giver_npc_id"]: npc.append(q["giver_npc_id"])
        item += q["rewards"]
for name, ids in (("npc", npc), ("quest", quest), ("item", item)):
    (out / f"ids_{name}.txt").write_text("\n".join(str(i) for i in dict.fromkeys(ids)))
    print(name, len(set(ids)))
