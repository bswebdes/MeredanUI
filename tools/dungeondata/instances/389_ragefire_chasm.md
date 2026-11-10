# Ragefire Chasm (map 389)

- Level: 13-18 · Entrance: Orgrimmar · Faction: Horde city (Alliance can enter, no quests)
- Status: **live** - classic dungeon in Forever's group finder list
- Sources: https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://www.warcrafttavern.com/forever/guides/dungeons/, https://conquestcapped.com/guides/wow-forever/wow-forever-ragefire-chasm-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10
- Keys / attunement: None

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Oggleflint | Flintauge | 2732 | 11517 | 1 0.56,0.38 | first trogg cave, with two adds |
| 2 |  | Taragaman the Hungerer | Taragaman der Hungerleider | 2733 | 11520 | 1 0.41,0.58 | lava platform in central chamber |
| 3 |  | Jergosh the Invoker | Jergosh der Herbeirufer | 2734 | 11518 | 1 0.33,0.85 | middle of the last room, two adds |
| 4 |  | Bazzalan | Bazzalan | 2735 | 11519 | 1 0.42,0.86 | up the ramp, right side of last room |

## Loot

Columns: guide % = Forever guide (some guides say their chances are classic values); WH-F % = Wowhead Forever tooltip drop chance (only when Wowhead's top source is this boss; caution: Wowhead shows such chances even for raids not open in Forever, so they are partly imported classic statistics); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (named for this boss by a Forever guide, or a new Forever item that Wowhead Forever ties to this boss). ✘ 404 = item ID does not exist on Wowhead Forever.

### Oggleflint

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 272996 | Trogg Scepter | Main Hand Mace | 3.3 | 13.46 |  | ✔ | guide+wowhead-forever |
| 272999 | Barbaric Crossbow | Crossbow | 3 | 12.48 |  | ✔ | guide+wowhead-forever |
| 272998 | Bone Knuckles | Fist Weapon | 2.7 | 13.79 |  | ✔ | guide+wowhead-forever |
| 1210 | Shadowgem |  |  |  | 1.9 |  | repo |

### Taragaman the Hungerer

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 14149 | Subterranean Cape | Back | 34.8 | 31.93 | 40 | ✔ | guide+repo+wowhead-forever |
| 14148 | Crystalline Cuffs | Wrist (Cloth) | 32.9 | 30.4 | 40 | ✔ | guide+repo+wowhead-forever |
| 14145 | Cursed Felblade | One-Hand Sword | 17.6 | 18.38 | 20 | ✔ | guide+repo+wowhead-forever |
| 14540 | Taragaman the Hungerer's Heart (quest) | Quest |  | 39.54 |  | ✔ | guide+wowhead-forever |

### Jergosh the Invoker

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 14147 | Cavedweller Bracers | Wrist (Mail) | 37.3 | 33.26 | 40 | ✔ | guide+repo+wowhead-forever |
| 14150 | Robe of Evocation | Chest (Cloth) | 36.4 | 36.11 | 40 | ✔ | guide+repo+wowhead-forever |
| 14151 | Chanting Blade | Dagger | 17.7 | 18.67 | 20 | ✔ | guide+repo+wowhead-forever |

### Bazzalan

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 273003 | Searing Dagger | Main Hand Dagger | 2.9 | 12.64 |  | ✔ | guide+wowhead-forever |
| 273005 | Satyrskin Cloak | Back | 2.9 | 12.28 |  | ✔ | guide+wowhead-forever |
| 273007 | Chasm Walkers | Feet (Leather) | 2.9 | 11.35 |  | ✔ | guide+wowhead-forever |
| 1210 | Shadowgem |  |  |  | 2.2 |  | repo |

### Differences to Map/DungeonLoot.lua

- Oggleflint: 272996 Trogg Scepter - in Forever guide, missing in DungeonLoot.lua
- Oggleflint: 272999 Barbaric Crossbow - in Forever guide, missing in DungeonLoot.lua
- Oggleflint: 272998 Bone Knuckles - in Forever guide, missing in DungeonLoot.lua
- Oggleflint: 1210 Shadowgem - in DungeonLoot.lua, not in guide (Wowhead Forever: no drop data)
- Bazzalan: 273003 Searing Dagger - in Forever guide, missing in DungeonLoot.lua
- Bazzalan: 273005 Satyrskin Cloak - in Forever guide, missing in DungeonLoot.lua
- Bazzalan: 273007 Chasm Walkers - in Forever guide, missing in DungeonLoot.lua
- Bazzalan: 1210 Shadowgem - in DungeonLoot.lua, not in guide (Wowhead Forever: no drop data)

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| 5728 | Hidden Enemies | 16 | Horde | Thrall (4949) | Orgrimmar | Hidden Enemies steps 5726, 5727 (Lieutenant's Insignia item=14544) | yes |
| 5724 | Returning the Lost Satchel | 16 | Horde | Maur Grimtotem (corpse) (11834) | Ragefire Chasm (inside) | Searching for the Lost Satchel (5722) from Rahauro npc=11833, Thunder Bluff; Grimtotem Satchel item=14381 | yes |
| 5725 | The Power to Destroy... | 16 | Horde | Varimathras (2425) | Undercity |  | yes |
| 5761 | Slaying the Beast | 16 | Horde | Neeru Fireblade (3216) | Orgrimmar |  | yes |
| 5723 | Testing an Enemy's Strength | 15 | Horde | Rahauro (11833) | Thunder Bluff |  | yes |
| 5722 | Searching for the Lost Satchel | 16 | Horde | Rahauro (11833) | Thunder Bluff |  | yes |

## Forever changes noted by guides

- Quest XP about twice Classic
- All boss items are blue
- Oggleflint and Bazzalan had no loot in Classic; now three new items each
- Taragaman and Jergosh drops reworked with better stats
- Subterranean Cape gains 5 health per 5 sec
- Cursed Felblade proc now removes 24 Attack Power
- New items: Garrison Cuffs, Trogg Scepter, Bone Knuckles, Barbaric Crossbow, Searing Dagger, Satyrskin Cloak, Chasm Walkers
- Beta (Oct 8) lowered several quest rewards blue->green (bracers, leggings)

## Open questions (check in game)

- none found

## Research notes

- Oggleflint/Bazzalan item chances ~3% as stated (seems low, possibly early data)
- Hidden Enemies chain 5726-5730; dungeon step is 5728; page says '3 steps' but lists 5
- Power to Destroy needs Spells of Shadow item=14395 and Incantations from the Nether item=14396 from Searing Blade Cultist npc=11322 / Warlock npc=11324
- Testing an Enemy's Strength: 8 Ragefire Trogg npc=11318, 8 Ragefire Shaman npc=11319
- Beta pages listed patterns item=252781, item=253906 as rare drops
- Slot for Barbaric Crossbow/Cursed Felblade not stated by page; inferred
