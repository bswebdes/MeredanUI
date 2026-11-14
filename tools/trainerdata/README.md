# Trainer and class quest data (WoW Forever)

Research data for future MeredanUI features: show waiting trainer spells on level-up and in a spellbook tab,
mark recommended / skippable ranks at the trainer, remind about class quests. Nothing here is loaded by the
addon yet; the folder is excluded from the packaged addon (`.pkgmeta` ignores `tools`).

## Files

| File | What |
|---|---|
| `TrainerSpells.lua` | Every spell rank taught by the class trainers (plus spells learned from class quests), with leveling advice. Generated. |
| `ClassQuests.lua` | Every class quest chain in Forever: first quest, level, races, start NPC, what it unlocks. Generated. |
| `LearningOrder.md` | Short leveling plan per class (what to buy when, what to skip, money tips). Generated. |
| `SOURCES.md` | Sources, builds, date checked, Forever differences, open questions. Generated from `SOURCES.template.md`. |
| `advice/<CLASS>.json` | Hand-checked leveling advice per spell name (the input for the advice fields). Edit these. |
| `checks.txt` | Differences between the sources found by the build (e.g. trainer level vs. client level). Generated. |
| `wowhead_check.txt` | Spot checks of spell IDs against Wowhead Forever tooltips. |
| `build_trainer_spells.py` | Builds `TrainerSpells.lua`, `LearningOrder.md`, `SOURCES.md`, `checks.txt`. |
| `build_class_quests.py` | Builds `ClassQuests.lua`. |
| `check_data.py` | Parses both Lua files and checks the format below. |
| `check_wowhead.py` | Spot-check script for spell IDs. |

Rebuild (input folders are downloaded by hand, see the script headers and `SOURCES.md`):

```
python3 -I tools/trainerdata/build_trainer_spells.py <db2 csv folder> <WhatsTraining Classes/Camelot folder>
python3 -I tools/trainerdata/build_class_quests.py <questie folder> <.../Classes/Camelot/QuestSpells.lua> <db2 csv folder>
python3 -I tools/trainerdata/check_data.py
```

## Loading

Both Lua files are plain data: one `local` table and `return` at the end, no functions. To use them in the addon
later, change the first line to `ns.TRAINER_SPELLS = {` / `ns.CLASS_QUESTS = {` (or load them with
`loadfile` in a tool) and drop the `return`. Keys are class tokens as returned by `UnitClass` (3rd value):
`WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID`. Race IDs are the 3rd value of `UnitRace`
(1 Human, 2 Orc, 3 Dwarf, 4 Night Elf, 5 Undead, 6 Tauren, 7 Gnome, 8 Troll, 95 Skyborne (Alliance),
96 Skyborne (Horde)).

## TrainerSpells.lua

```lua
local TRAINER_SPELLS = {
    SHAMAN = {   -- list, sorted by level, then name, then rank
        { id = 8044, name = "Earth Shock", rank = 2, level = 8, cost = 100, school = "Nature",
          tree = "Elemental Combat", learnedFrom = "trainer", requires = { spell = 8042 },
          advice = "recommended", reason_en = "...", reason_de = "...", verified = "forever" },
        ...
    },
}
```

| Field | Type | Meaning |
|---|---|---|
| `id` | number | Spell ID of this rank (one entry per rank). Use with `IsSpellKnown(id)` / `IsPlayerSpell(id)`. |
| `name` | string | English spell name (enUS client). Use `GetSpellInfo(id)` for the local name. |
| `rank` | number or nil | Rank number; nil for spells without ranks. |
| `level` | number | Character level needed at the trainer (for quest spells: level of the first quest). |
| `cost` | number | Training cost in copper, base price before reputation discount. 0 for quest spells. |
| `school` | string | Physical, Holy, Fire, Nature, Frost, Shadow, Arcane. |
| `tree` | string | Class skill line from the client (talent tree name, e.g. "Elemental Combat"), or the general skill line for armor/weapon skills. |
| `learnedFrom` | string | `"trainer"`, `"talent"` (higher rank of a talent spell: trainer only shows it if you have the talent), `"quest"` (learned from a class quest, not the trainer). |
| `requires` | table or nil | `spell` = previous rank ID (or list of IDs) that must be known; `talent` = talent spell ID needed; `races` = list of race IDs that can learn it (Priest racials); `faction` = `"Alliance"`/`"Horde"` (e.g. Mage portals); `quest` = list of quest IDs that reward the spell. |
| `advice` | string | `"recommended"`, `"optional"` or `"skip"` for solo leveling. |
| `reason_en`, `reason_de` | string | Short reason (about 70 characters max). |
| `role` | string or nil | `"tank"`, `"heal"` or `"dps"` when the spell mainly matters for that role in groups. |
| `roles` | table or nil | Overrides by role: `roles = { heal = { advice = "recommended", reason_en = "...", reason_de = "..." } }`. Use when the player picked a role. |
| `verified` | string | `"forever"` = spell/level checked against Forever data; `"classic_era"` = only Classic Era data. |

Notes for the addon:

- Waiting spells on level-up: entries with `level <= UnitLevel("player")`, `learnedFrom ~= "quest"`, not known
  (`IsSpellKnown`), all `requires.spell` known, `requires.races`/`faction` matching, and for `learnedFrom ==
  "talent"` the `requires.talent` spell known.
- Rank 1 of spells every character starts with (e.g. Lightning Bolt, Healing Wave) is not listed (not sold).

## ClassQuests.lua

```lua
local CLASS_QUESTS = {
    SHAMAN = {   -- ability chains first, then by level
        {
            first = 1516, name = "Call of Earth", name_de = "Ruf der Erde", level = 4, category = "ability",
            faction = "Horde", races = { 2, 5, 6, 8, 96 },
            start = { npc = 5887, npc_en = "Canaga Earthcaller", npc_de = "...", zone = "Durotar", map = 1411, x = 42.4, y = 69.17 },
            starts = { { quest = 1516, level = 4, races = { ... }, start = { ... } }, ... },  -- only when the chain has several starts
            quests = { ... }, finals = { 1518 }, final_name = "Call of Earth",
            unlocks = { { type = "spell", id = 8071, name = "Stoneskin Totem", quest = 1518, verified = "forever" } },
            required = true, verified = "forever",
        },
    },
}
```

| Field | Meaning |
|---|---|
| `first` | Quest ID of the main start quest (the start open to the most races). |
| `name`, `name_de` | Quest name (English; German from the Questie deDE data when it differs). |
| `level` | Lowest required level of any quest in the chain. |
| `category` | `"ability"` (chain rewards a spell/form/pet/stance), `"leveling"` (other class quests below level 55, usually item rewards), `"endgame"` (level 55+). |
| `faction`, `races` | `"Alliance"`, `"Horde"` or `"both"`; race IDs allowed (empty list = all races). |
| `start` | Start NPC of `first`: NPC ID, English/German name, zone name, `map` = uiMapID, `x`/`y` in percent. Some starts are an object or item (`object = id` / `item = id`). |
| `starts` | All start quests of the chain with their races and NPCs (race-specific starts). |
| `quests` | All quest IDs of the chain (to detect a started or finished chain with `C_QuestLog.IsQuestFlaggedCompleted`). |
| `finals`, `final_name` | Last quest(s) of the chain. |
| `unlocks` | What the chain gives: `type = "spell"` (spell ID; the player must do the quest to learn it) or `"item"`. `quest` = the quest that gives it. |
| `required` | `true` when the chain is the only way to learn a spell (Shaman totems, Druid forms, Warlock pets, Hunter taming, Warrior stances, Paladin Redemption, Rogue poisons, Priest racials ...). |
| `verified` | `"forever"` = the quest is in the Forever quest data. |
