#!/usr/bin/env python3
"""Forever-Pawn: Stat-Gewichte je Klasse und Talentbaum nach Upgrades/ForeverWeights.lua schreiben.

Quellen (Stand 2026-11):
  * WoWSims Forever (github.com/wowsims/forever, MIT): EP-Presets in ui/specs/<klasse>/<spec>/presets.ts
  * Forever Codex (gevil.github.io/forever-codex): je simuliertem Build "weights" (Jäger, Magier, Hexer)

Specs ohne eigene Simulation bekommen die Werte einer ähnlichen Rolle (siehe FALLBACK-Hinweise).
Aufruf (im MeredanUI-Ordner):  python3 tools/update_forever_weights.py
"""
import json
import re
import statistics
import sys
import urllib.request

WOWSIMS = "https://raw.githubusercontent.com/wowsims/forever/master/ui/specs/"
CODEX = "https://raw.githubusercontent.com/Gevil/forever-codex/HEAD/{}/index.html"

# WoWSims-Schlüssel → MUI-Schlüssel (Wertungen bleiben Wertungen; *_pct = je 1 %)
WOWSIMS_KEYS = {
    "StatStrength": "str", "StatAgility": "agi", "StatStamina": "sta", "StatIntellect": "int",
    "StatSpirit": "spi", "StatAttackPower": "ap", "StatRangedAttackPower": "rap",
    "StatSpellDamage": "sp", "StatHealingPower": "heal", "StatMP5": "mp5",
    "StatHitRating": "hit", "StatCritRating": "crit", "StatHasteRating": "haste",
    "StatExpertiseRating": "exp", "StatArmorPenetration": "arp", "StatSpellPiercing": "spellpen",
    "StatDefenseRating": "def", "StatDodgeRating": "dodge", "StatParryRating": "parry",
    "StatBlockValue": "blockvalue", "StatArmor": "armor", "StatBonusArmor": "armor",
    "StatFireDamage": "fire", "StatFrostDamage": "frost", "StatShadowDamage": "shadow",
    "StatArcaneDamage": "arcane", "StatNatureDamage": "nature", "StatHolyDamage": "holy",
    "PseudoStatMainHandDps": "mhdps", "PseudoStatOffHandDps": "ohdps", "PseudoStatRangedDps": "rangeddps",
    "PseudoStatMeleeHitPercent": "hit_pct", "PseudoStatMeleeCritPercent": "crit_pct",
    "PseudoStatSpellHitPercent": "spellhit_pct", "PseudoStatSpellCritPercent": "spellcrit_pct",
    "PseudoStatMeleeHastePercent": "haste_pct", "PseudoStatSpellHastePercent": "spellhaste_pct",
    "PseudoStatExpertisePercent": "exp_pct",
}
CODEX_KEYS = {
    "Strength": "str", "Agility": "agi", "Stamina": "sta", "Intellect": "int", "Spirit": "spi",
    "AttackPower": "ap", "RangedAttackPower": "rap", "HitRating": "hit", "CritRating": "crit",
    "HasteRating": "haste", "ArmorPenetration": "arp", "ExpertiseRating": "exp", "MP5": "mp5",
    "SpellDamage": "sp", "FireDamage": "fire", "FrostDamage": "frost", "ShadowDamage": "shadow",
    "ArcaneDamage": "arcane", "NatureDamage": "nature", "HolyDamage": "holy", "SpellPiercing": "spellpen",
    # Kurzformen (hunter-codex)
    "Str": "str", "Agi": "agi", "Sta": "sta", "Int": "int", "Spi": "spi", "AP": "ap", "RAP": "rap",
    "Hit": "hit", "Crit": "crit", "Haste": "haste", "ArPen": "arp", "Exp": "exp",
}

# Klasse → Talentbaum (1–3, Classic-Reihenfolge) → (Datei, Konstante) bzw. "codex"
SPECS = {
    "WARRIOR": {1: ("warrior/dps/presets.ts", "PreBiSArmsEpWeights"),
                2: ("warrior/dps/presets.ts", "PreBiSFuryEpWeights"),
                3: ("warrior/protection/presets.ts", "PreBiSEpWeights")},
    "ROGUE": {1: ("rogue/dps/presets.ts", "EP_PRESET_ASSASSINATION"),
              2: ("rogue/dps/presets.ts", "EP_PRESET_COMBAT_SINISTER"),
              3: ("rogue/dps/presets.ts", "EP_PRESET_SUBTLETY")},
    "PRIEST": {1: ("priest/healer/presets.ts", "DiscRaidHealingEpWeights"),
               2: ("priest/healer/presets.ts", "HolyRaidHealingEpWeights"),
               3: ("priest/dps/presets.ts", "ShadowEpWeights")},
    "DRUID": {1: ("druid/balance/presets.ts", "P1EpWeights"),
              2: ("druid/feral_ep.ts", "CatEp"),
              3: ("priest/healer/presets.ts", "HolyRaidHealingEpWeights")},   # FALLBACK: Heiler wie Holy-Priester
    "SHAMAN": {1: ("shaman/elemental/presets.ts", "DefaultEpWeights"),
               2: ("shaman/enhancement/presets.ts", "PreBiSEpWeights"),
               3: ("priest/healer/presets.ts", "HolyRaidHealingEpWeights")},  # FALLBACK: Heiler wie Holy-Priester
    "PALADIN": {1: ("priest/healer/presets.ts", "HolyRaidHealingEpWeights"),  # FALLBACK: Heiler wie Holy-Priester
                2: ("warrior/protection/presets.ts", "PreBiSEpWeights"),     # FALLBACK: Tank wie Schutz-Krieger
                3: ("paladin/retribution/presets.ts", "UnsealedWrathEpWeights")},
    "HUNTER": "codex:hunter", "MAGE": "codex:mage", "WARLOCK": "codex:warlock",
}
FALLBACK_NOTES = {("DRUID", 3), ("SHAMAN", 3), ("PALADIN", 1), ("PALADIN", 2)}

_cache = {}


def fetch(url):
    if url not in _cache:
        with urllib.request.urlopen(url, timeout=30) as r:
            _cache[url] = r.read().decode("utf-8", "replace")
    return _cache[url]


def balanced(text, start):
    """Text ab der ersten '(' bei start bis zur passenden ')'."""
    i = text.index("(", start)
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "(":
            depth += 1
        elif text[j] == ")":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
    raise ValueError("unbalanced")


def wowsims_weights(path, const):
    text = fetch(WOWSIMS + path)
    m = re.search(r"export const " + re.escape(const) + r"\s*=", text)
    if not m:
        raise SystemExit(f"{const} nicht in {path} gefunden")
    body = balanced(text, m.end())
    weights = {}
    for name, value in re.findall(r"\[(?:Pseudo)?Stat\.(\w+)\]\s*:\s*(-?[\d.]+)", body):
        key = WOWSIMS_KEYS.get(name)
        if key:
            weights[key] = weights.get(key, 0) + float(value)
    if not weights:
        raise SystemExit(f"{const} in {path}: keine Gewichte gelesen")
    return weights


def codex_weights(cls):
    text = fetch(CODEX.format(cls))
    builds = [json.loads(m) for m in re.findall(r'"weights":(\{[^{}]*\})', text)]
    if not builds:
        raise SystemExit(f"Codex {cls}: keine Builds")
    keys = {CODEX_KEYS[k] for b in builds for k in b if k in CODEX_KEYS}
    out = {}
    for key in keys:
        values = [sum(v for k, v in b.items() if CODEX_KEYS.get(k) == key) for b in builds]
        out[key] = statistics.median(values)
    return out, len(builds)


def lua_table(weights):
    parts = [f"{k} = {round(v, 4)}" for k, v in sorted(weights.items()) if abs(v) > 1e-9]
    return "{ " + ", ".join(parts) + " }"


def main():
    lines = [
        "-- AUTOMATISCH ERZEUGT von tools/update_forever_weights.py – nicht von Hand ändern.",
        "-- Forever-Pawn: Stat-Gewichte je Klasse und Talentbaum (1–3).",
        "-- Quellen: WoWSims Forever (MIT) EP-Presets, Forever Codex (Median der simulierten Builds).",
        "-- Einheiten: Wertungen je Punkt Wertung, *_pct je 1 %, *dps je 1 Waffen-DPS.",
        "local _, ns = ...",
        "",
        "ns.FOREVER_WEIGHTS = {",
    ]
    for cls, spec in SPECS.items():
        lines.append(f"    {cls} = {{")
        if isinstance(spec, str):
            weights, n = codex_weights(spec.split(":")[1])
            for tree in (1, 2, 3):
                lines.append(f"        [{tree}] = {lua_table(weights)}, -- Codex, Median aus {n} Builds")
        else:
            for tree, (path, const) in spec.items():
                note = " -- ERSATZ (keine eigene Simulation)" if (cls, tree) in FALLBACK_NOTES else ""
                lines.append(f"        [{tree}] = {lua_table(wowsims_weights(path, const))},{note}")
        lines.append("    },")
    lines.append("}")
    out = "\n".join(lines) + "\n"
    target = sys.argv[1] if len(sys.argv) > 1 else "Upgrades/ForeverWeights.lua"
    with open(target, "w", encoding="utf-8") as f:
        f.write(out)
    print(out)


if __name__ == "__main__":
    main()
