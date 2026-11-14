#!/usr/bin/env python3
"""Write tools/trainerdata/quest_links.json: for the class quests in ClassQuests.lua the links Questie
knows between them - exclusiveTo (alternative starts, only one can be done) and the pre-quests of
each chain's first quest. export_addon.py adds them to the addon data.
Input: Questie's Forever quest database (raw.githubusercontent.com/Questie/QuestieDB/HEAD/data/Forever/foreverQuestDB.lua).
usage: python3 -I tools/trainerdata/questie_links.py <foreverQuestDB.lua>"""
import json, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from lualit import tokenize, P  # noqa: E402

PRE_GROUP, PRE_SINGLE, EXCLUSIVE = 12, 13, 16


def lst(t):
    if isinstance(t, dict):
        return [t[k] for k in sorted(k for k in t if isinstance(k, int))]
    return t or []


def ids(v):
    return [int(x) for x in lst(v) if isinstance(x, (int, float))]


def main():
    src = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8', errors='replace')
    cq = (HERE / 'ClassQuests.lua').read_text(encoding='utf-8')
    wanted = {int(x) for x in re.findall(r'\bquests = \{([^}]*)\}', cq) for x in re.findall(r'\d+', x)}
    links = {}
    for m in re.finditer(r'^\[(\d+)\] = (\{.*\}),\s*$', src, re.M):
        qid = int(m.group(1))
        if qid not in wanted:
            continue
        p = P(tokenize(m.group(2)), {})
        p.expect('{')
        row = p.table()
        get = (lambda i: row.get(i) if isinstance(row, dict) else (row[i - 1] if len(row) >= i else None))
        entry = {}
        for key, idx in (('ex', EXCLUSIVE), ('pre', PRE_SINGLE), ('preg', PRE_GROUP)):
            v = ids(get(idx))
            if v:
                entry[key] = v
        if entry:
            links[qid] = entry
    out = HERE / 'quest_links.json'
    out.write_text(json.dumps(links, sort_keys=True, indent=0) + '\n', encoding='utf-8')
    print(out, len(links), 'quests with links')


if __name__ == '__main__':
    main()
