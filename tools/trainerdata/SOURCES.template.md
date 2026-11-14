# Sources

Research data for trainer spells and class quests in WoW Forever. Date checked: 2026-11-14.
`SOURCES.md` is generated from this template by `build_trainer_spells.py` (the per-class part comes from
`advice/<CLASS>.json`). Edit this template, not `SOURCES.md`.

## Game data

| What | Source | Build / version |
|---|---|---|
| Spell IDs, names, ranks, spell level, school, tree | WoW Forever client tables via [wago.tools](https://wago.tools/db2) (product `wowf`): `SpellName`, `Spell` (rank text), `SpellLevels`, `SpellMisc` (school), `SkillLineAbility`, `SkillLine` | 1.60.1.70938 (newest Forever build on 2026-11-14) |
| Which spells each class trainer teaches, trainer level, cost | [WhatsTraining](https://github.com/fusionpit/WhatsTraining) addon, `forever` branch, `Classes/Camelot/*.lua` (MIT license). Costs are base prices before reputation discount. | commit `dd42564` (2026-11-03) |
| Spells learned from class quests (spell <- reward quest) | WhatsTraining `forever` branch, `Classes/Camelot/QuestSpells.lua` | commit `dd42564` |
| Class quests: IDs, chains, levels, races, start NPCs, coordinates, German names | [Questie database](https://github.com/Questie/QuestieDB), Forever data and corrections (same file list as `tools/build_class_quests.py`) | commit `4dbb824` |
| Spot checks of spell IDs (name + required level) | Wowhead Forever tooltips `nether.wowhead.com/forever/tooltip/spell/<id>`, results in `wowhead_check.txt` | live, 2026-11-14 |
| Official class changes | Blizzard news: [Mage and Shaman deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24302097/world-of-warcraft-forever-class-deep-dives-mage-and-shaman), [Priest and Warrior deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24301514/world-of-warcraft-forever-class-deep-dives-priest-and-warrior), [Hunter and Druid deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24301515), [Rogue and Warlock deep dive](https://worldofwarcraft.blizzard.com/en-us/news/24310968/world-of-warcraft-forever-class-deep-dives-rogue-and-warlock), [Beta development notes](https://us.forums.blizzard.com/en/wow/t/2360696/1) | 2026-09 to 2026-11 |

How the sources were checked against each other:

- Every trainer entry was matched against the Forever client: the spell must have a name in the client and the
  client `SpellLevels` must match the trainer level. Entries without a client name (spells removed in Forever, e.g.
  Paladin Blessing of Salvation / Light, Fire Nova Totem) are dropped. Remaining level differences are listed in
  `checks.txt`.
- A random sample of spell IDs per class was compared with Wowhead Forever (`wowhead_check.txt`).
- Training costs have only one Forever source (WhatsTraining, scanned from the live trainers). Wowhead pages
  that show training costs could not be read by a script. Treat costs as good but single-sourced.
- Trainer data is not in the game client (no Trainer table in the readable DB2 files), so the trainer list itself
  also depends on WhatsTraining. The client agrees on every spell name and nearly every level.

## Known limits (all classes)

- Hunter pet skills (Great Stamina, Natural Armor, resistances ...) are listed with `learnedFrom = "pettrainer"`
  (sold by the pet trainer). Warlock demon tomes (vendor books for pet spells) are not included.
- Class quests from the Questie Forever data include endgame chains (tier 0.5, Zul'Gurub, AQ, Naxxramas class
  quests). Some of that content may not be open yet in Forever; they are marked `category = "endgame"`.
- The totem items from the Shaman element quests are taken from Classic Era rules (`verified = "classic_era"` on
  that unlock); the Forever sources do not say whether the totem items are still needed.
- Leveling advice for new Forever spells relies on early Forever guides (written during beta/launch week).

<!-- CLASSES -->
