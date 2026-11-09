#!/usr/bin/env python3
"""Summon positions of scripted (event) bosses from cMaNGOS ScriptDevAI sources.
Finds `NPC_X = id` constants and literal `NPC_X, x, y, z` tuples (summon tables, SummonCreature calls).
usage: python3 -I tools/sd2_positions.py <ScriptDevAI/scripts dir> > positions.tsv  (entry \t x \t y \t z)"""
import re, sys, pathlib
consts, out = {}, []
files = list(pathlib.Path(sys.argv[1]).rglob("*.[ch]*"))
for f in files:
    for name, val in re.findall(r"\b(NPC_\w+)\s*=\s*(\d+)", f.read_text(errors="replace")):
        consts.setdefault(name, int(val))
num = r"(-?\d+(?:\.\d+)?)f?"
for f in files:
    t = f.read_text(errors="replace")
    for name, x, y, z in re.findall(r"\b(NPC_\w+)\s*,\s*" + num + r"\s*,\s*" + num + r"\s*,\s*" + num, t):
        if name in consts and abs(float(x)) > 5:
            out.append((consts[name], x, y, z))

def braced(t, i):
    """Text of the {...} block starting at t[i] == '{'."""
    depth = 0
    for j in range(i, len(t)):
        depth += {'{': 1, '}': -1}.get(t[j], 0)
        if depth == 0: return t[i + 1:j]
    return ""

def elements(block):
    """Top-level {...} elements of an array initializer."""
    res, i = [], 0
    while True:
        i = block.find('{', i)
        if i < 0: return res
        inner = braced(block, i); res.append(inner); i += len(inner) + 2

# SummonCreature(NPC_X, someArray[i].x / someArray[0], ...) -> position from the array initializer
for f in files:
    t = f.read_text(errors="replace")
    for name, arr, idx in re.findall(r"SummonCreature\(\s*(NPC_\w+)\s*,\s*(\w+)(?:\[(\d+)\])?", t):
        if name not in consts: continue
        d = None
        for g in files:
            gt = g.read_text(errors="replace")
            m = re.search(r"\b" + arr + r"\s*(?:\[[^\]]*\])*\s*=\s*(?://[^\n]*\s*)*\{", gt)
            if m: d = braced(gt, m.end() - 1); break
        if d is None: continue
        if idx:
            els = elements(d)
            if els:  # array of positions; a flat float array is used as x, y, z directly
                if int(idx) >= len(els): continue
                d = els[int(idx)]
        nums = re.findall(num, re.sub(r"//.*", "", d))
        if len(nums) >= 3 and abs(float(nums[0])) > 5:
            out.append((consts[name], nums[0], nums[1], nums[2]))
for row in dict.fromkeys(out):
    print("\t".join(map(str, row)))
