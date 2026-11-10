#!/usr/bin/env python3
"""Fetch Wowhead tooltip JSON (forever or classic namespace) for a list of IDs, politely (one request
at a time, short pause), and cache it under tools/dungeondata/cache/<ns>_<kind>.json.
usage: python3 -I fetch_tooltips.py <forever|classic> <item|npc|quest|object> <ids.txt> [pause]"""
import json, sys, time, pathlib, urllib.request

ns, kind, idfile = sys.argv[1], sys.argv[2], sys.argv[3]
pause = float(sys.argv[4]) if len(sys.argv) > 4 else 0.8
cache = pathlib.Path(__file__).resolve().parent.parent / "cache" / f"{ns}_{kind}.json"
data = json.loads(cache.read_text()) if cache.exists() else {}
ids = [l.strip() for l in open(idfile) if l.strip()]
todo = [i for i in dict.fromkeys(ids) if i not in data]
print(len(todo), "to fetch", flush=True)
for n, i in enumerate(todo):
    url = f"https://nether.wowhead.com/{ns}/tooltip/{kind}/{i}?locale=0"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "addon-research/1.0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            data[i] = json.loads(r.read().decode("utf-8"))
    except Exception as e:
        data[i] = {"error": str(e)}
    if n % 25 == 0:
        cache.write_text(json.dumps(data, sort_keys=True, indent=0))
        print(n, flush=True)
    time.sleep(pause)
cache.write_text(json.dumps(data, sort_keys=True, indent=0))
print("done", len(data))
