#!/usr/bin/env python3
"""Sweep: every atlas and interface file whose name contains a class token, checked against the
Forever build. Writes presence_sweep.csv (kind, name, class, fileDataID, in_forever) and prints
what is missing (= retail only).

usage: python3 sweep_presence.py
"""
import csv
import os
import re
from concurrent.futures import ThreadPoolExecutor

import classart_lib as L

HERE = os.path.dirname(os.path.abspath(__file__))
TOK = re.compile("(" + "|".join(sorted(L.CLASSES + L.RETAIL_CLASSES, key=len, reverse=True)) + ")")
SKIP = re.compile(r"^interface/(icons|addons|worldmap|glues/credits|encounterjournal)/")


def main():
    rows = []
    for name, a in L.atlases().items():
        m = TOK.search(name.replace("-", ""))
        if m:
            rows.append(["atlas", name, m.group(1), a["fdid"]])
    for fid, path in L.manifest().items():
        p = path.lower()
        m = TOK.search(p.rsplit("/", 1)[-1].replace("-", ""))
        if m and not SKIP.match(p):
            rows.append(["file", path, m.group(1), fid])
    fids = sorted({r[3] for r in rows})
    with ThreadPoolExecutor(8) as ex:
        res = dict(zip(fids, ex.map(L.present, fids)))
    with open(os.path.join(HERE, "presence_sweep.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["kind", "name", "class", "fileDataID", "in_forever"])
        for r in sorted(rows, key=lambda r: (r[0], r[1])):
            w.writerow(r + ["yes" if res[r[3]] else "no"])
    total = len(rows)
    miss = [r for r in rows if not res[r[3]]]
    print(f"checked {total} names on {len(fids)} textures, missing {len(miss)} names on {sum(1 for v in res.values() if not v)} textures")
    for r in sorted(miss, key=lambda r: r[1])[:400]:
        print("MISSING", r[0], r[1], r[3])


if __name__ == "__main__":
    main()
