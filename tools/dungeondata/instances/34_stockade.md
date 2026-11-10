# The Stockade (map 34)

- Level: 24-32 · Entrance: Stormwind City · Faction: Alliance city (Horde can enter, no quests)
- Status: **live** - classic dungeon
- Sources: https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://www.warcrafttavern.com/forever/guides/dungeons/, https://conquestcapped.com/guides/wow-forever/wow-forever-stockade-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10
- Keys / attunement: None

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Targorr the Dread | Targorr der Schreckliche | 2756 | 1696 | 1 0.50,0.24 | cell along central hall |
| 2 |  | Kam Deepfury | Kam Tiefenzorn | 2757 | 1666 | 1 0.69,0.31 | cell, north side of east hall |
| 3 |  | Hamhock | Hamhock | 2758 | 1717 | 1 0.78,0.46 | round room at east end |
| 4 |  | Bazil Thredd | Bazil Thredd | 2760 | 1716 | 1 0.86,0.51 | cell off the east round room |
| 5 |  | Dextren Ward | Dextren Ward | 2759 | 1663 | 1 0.15,0.21 | west wing round room or cells |

### Rares

| NPC ID | Name | Pin | Location (guide) |
|---|---|---|---|
| 1720 | Bruegal Ironknuckle | 1 0.38,0.24 | one of several cells off main hall; not every run |

## Loot

Columns: guide % = Forever guide (some guides say their chances are classic values); WH-F % = Wowhead Forever tooltip drop chance (only when Wowhead's top source is this boss; caution: Wowhead shows such chances even for raids not open in Forever, so they are partly imported classic statistics); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (named for this boss by a Forever guide, or a new Forever item that Wowhead Forever ties to this boss). ✘ 404 = item ID does not exist on Wowhead Forever.

### Targorr the Dread

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 3630 | Head of Targorr (quest) | Quest |  | 37.1 |  | ✔ | guide+wowhead-forever |
| 273804 | Executioner Mantle | Shoulder (Leather) |  | 3.29 |  | ✔ | guide+wowhead-forever |
| 273805 | Blackrock Harness | Chest (Leather) |  | 3.51 |  | ✔ | guide+wowhead-forever |
| 273806 | Dark Horde Band | Finger |  | 3.52 |  | ✔ | guide+wowhead-forever |

### Kam Deepfury

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 3640 | Head of Deepfury (quest) | Quest |  | 20.11 |  | ✔ | guide+wowhead-forever |
| 2280 | Kam's Walking Stick | Staff | 0.9 | 5.42 | 1.2 | ✔ | guide+repo+wowhead-forever |
| 273807 | Demolition Girdle | Waist |  | 4.72 |  | ✔ | guide+wowhead-forever |
| 273808 | Bridgebreaker Bindings | Wrist (Cloth) |  | 4.12 |  | ✔ | guide+wowhead-forever |

### Hamhock

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 273809 | Hamhock's Cleaver | Main Hand Axe |  | 3.76 |  | ✔ | guide+wowhead-forever |
| 273810 | Ogre Grips | Hands (Mail) |  | 2.96 |  | ✔ | guide+wowhead-forever |
| 273811 | Repurposed Rack | Shield |  | 3.72 |  | ✔ | guide+wowhead-forever |

### Bazil Thredd

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 2926 | Head of Bazil Thredd (quest) | Quest |  | 43.26 |  | ✔ | guide+wowhead-forever |
| 273827 | Debt Collector | One-Hand Sword (caster) |  | 2.63 |  | ✔ | guide+wowhead-forever |
| 273829 | Concealed Hand Crossbow | Crossbow |  | 1.85 |  | ✔ | guide+wowhead-forever |
| 273825 | Red Wool Cloak | Back |  | 2.19 |  | ✔ | guide+wowhead-forever |
| 273824 | Defias Jailbreakers | Hands (Leather) |  | 2.3 |  | ✔ | guide+wowhead-forever |

### Dextren Ward

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 3628 | Hand of Dextren Ward (quest) | Quest |  | 44.05 |  | ✔ | guide+wowhead-forever |
| 273817 | Graverobber's Shovel | Two-Hand Mace |  | 4.27 |  | ✔ | guide+wowhead-forever |
| 273819 | Boneslicer | Polearm |  | 3.94 |  | ✔ | guide+wowhead-forever |
| 273820 | Nightskulker Ring | Finger |  | 3.25 |  | ✔ | guide+wowhead-forever |

### Bruegal Ironknuckle

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 3228 | Jimmied Handcuffs | Wrist Mail | 56 | 53.98 | 33.3 | ✔ | guide+repo+wowhead-forever |
| 2941 | Prison Shank | Dagger | 19 | 20.12 | 33.3 | ✔ | guide+repo+wowhead-forever |
| 2942 | Iron Knuckles | Fist Weapon | 17.5 | 18.76 | 33.3 | ✔ | guide+repo+wowhead-forever |

### Differences to Map/DungeonLoot.lua

- Targorr the Dread: 273804 Executioner Mantle - in Forever guide, missing in DungeonLoot.lua
- Targorr the Dread: 273805 Blackrock Harness - in Forever guide, missing in DungeonLoot.lua
- Targorr the Dread: 273806 Dark Horde Band - in Forever guide, missing in DungeonLoot.lua
- Kam Deepfury: 273807 Demolition Girdle - in Forever guide, missing in DungeonLoot.lua
- Kam Deepfury: 273808 Bridgebreaker Bindings - in Forever guide, missing in DungeonLoot.lua
- Hamhock: 273809 Hamhock's Cleaver - in Forever guide, missing in DungeonLoot.lua
- Hamhock: 273810 Ogre Grips - in Forever guide, missing in DungeonLoot.lua
- Hamhock: 273811 Repurposed Rack - in Forever guide, missing in DungeonLoot.lua
- Bazil Thredd: 273827 Debt Collector - in Forever guide, missing in DungeonLoot.lua
- Bazil Thredd: 273829 Concealed Hand Crossbow - in Forever guide, missing in DungeonLoot.lua
- Bazil Thredd: 273825 Red Wool Cloak - in Forever guide, missing in DungeonLoot.lua
- Bazil Thredd: 273824 Defias Jailbreakers - in Forever guide, missing in DungeonLoot.lua
- Dextren Ward: 273817 Graverobber's Shovel - in Forever guide, missing in DungeonLoot.lua
- Dextren Ward: 273819 Boneslicer - in Forever guide, missing in DungeonLoot.lua
- Dextren Ward: 273820 Nightskulker Ring - in Forever guide, missing in DungeonLoot.lua
- Bruegal Ironknuckle: 3228 Jimmied Handcuffs - chance repo 33.3% vs Forever 53.98%
- Bruegal Ironknuckle: 2941 Prison Shank - chance repo 33.3% vs Forever 20.12%
- Bruegal Ironknuckle: 2942 Iron Knuckles - chance repo 33.3% vs Forever 18.76%

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| 387 | Quell the Uprising | 26 | Alliance | Warden Thelwater (1719) | Stormwind City |  | yes |
| 388 | The Color of Blood | 26 | Alliance | Nikova Raskol (1721) | Stormwind City (Old Town) |  | yes |
| 378 | The Fury Runs Deep | 27 | Alliance | Motley Garmason (1074) | Wetlands (Dun Modr) | The Dark Iron War (303) | yes |
| 377 | Crime and Punishment | 26 | Alliance | Councilman Millstipe (270) | Duskwood (Darkshire) |  | yes |
| 386 | What Comes Around... | 25 | Alliance | Guard Berton (859) | Redridge Mountains (Lakeshire) |  | yes |
| 391 | The Stockade Riots | 29 | Alliance | Warden Thelwater (1719) | Stormwind City | The Unsent Letter (373) and Bazil Thredd (389) | yes |
| 303 | The Dark Iron War | 30 | Alliance | Motley Garmason (1074) | Wetlands |  | **no** |
| 373 | The Unsent Letter | 22 | Alliance |  (item 2874) | The Deadmines (drop from Edwin VanCleef 639) |  | **no** |
| 389 | Bazil Thredd | 22 | Alliance | Baros Alexston (1646) | Stormwind City (Cathedral Square) | The Unsent Letter (373) | **no** |

## Forever changes noted by guides

- Every boss received new blue items (273804-273829)
- New quest rewards 270036, 270029, 270027
- Dungeon quest XP roughly doubled vs Classic
- Iron Knuckles pummel proc 4 -> 25 damage
- Kam's Walking Stick now 32 spell power

## Open questions (check in game)

- none found

## Research notes

- Most boss loot has no drop chance on the guide
- Follow-ups after The Stockade Riots: The Curious Visitor (392), Shadow of the Past (393)
- Min level 16 for 391 as per guide table; may be a typo
- Guide states Hamhock, Kam etc. levels; Bruegal treated as rare
