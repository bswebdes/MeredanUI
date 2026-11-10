# The Drowned City (map 2970)

- Level: 35-40 · Entrance: Stranglethorn Vale coast (underwater, west of Grom'gol) · Faction: both
- Status: **live** - new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet
- Sources: http://worldofwarcraft.blizzard.com/en-us/news/24301455, https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://conquestcapped.com/guides/wow-forever/wow-forever-the-drowned-city-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Zul'Alai | Zul'Alai | 3474 | 270882 | — | top of the hill after first city section |
| 2 |  | Var'Taka | Var'Taka | 3475 | 270883 | — | Brinescale naga leader with priestesses |
| 3 |  | Captain Dreadrise | Captain Dreadrise | 3476 | 270884 | — | Saltseer pirate captain |
| 4 |  | Deathless Marrow | Unsterbliche Wächter | 3478 | 270885 | — | flooded tomb, shared encounter with Primeval Elemental |
| 5 |  | Primeval Elemental | Urtümlicher Elementar | 3511 | 273738 | — | flooded tomb, same encounter as Deathless Marrow |
| 6 |  | Gill | Gill | — | 270888 | — |  |
| 7 |  | Min'loth the Serpent | Min'loth die Schlange | 3479 | 270886 | — | final room overlooking sunken pirate ship |

## Loot

Columns: guide % = Forever guide (some guides say their chances are classic values); WH-F % = Wowhead Forever tooltip drop chance (only when Wowhead's top source is this boss; caution: Wowhead shows such chances even for raids not open in Forever, so they are partly imported classic statistics); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (named for this boss by a Forever guide, or a new Forever item that Wowhead Forever ties to this boss). ✘ 404 = item ID does not exist on Wowhead Forever.

### Zul'Alai

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274600 | Berserker Shackles | Wrist (mail) |  | 32.84 |  | ✔ | guide+wowhead-forever |
| 274598 | Bloodslash Axe | One-hand axe |  | 26.96 |  | ✔ | guide+wowhead-forever |
| 274599 | Oathbound Bracers | Wrist (leather) |  | 40.2 |  | ✔ | guide+wowhead-forever |

### Var'Taka

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274602 | Brinebelly Leggings | Legs (leather) |  | 32.52 |  | ✔ | guide+wowhead-forever |
| 274601 | Harpoon of Command | Polearm |  | 39.84 |  | ✔ | guide+wowhead-forever |

### Captain Dreadrise

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274604 | Frosty Blunderbuss | Gun |  | 33.71 |  | ✔ | guide+wowhead-forever |
| 274605 | Briny Sash | Waist (cloth) |  | 33.14 |  | ✔ | guide+wowhead-forever |
| 274603 | Dreadfrost Saber | Main-hand sword |  | 33.14 |  | ✔ | guide+wowhead-forever |

### Deathless Marrow

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274606 | Bloodspine Staff | Staff |  | 33.6 |  | ✔ | guide+wowhead-forever |
| 274607 | Viscera Spaulders | Shoulder (mail) |  | 27.2 |  | ✔ | guide+wowhead-forever |

### Primeval Elemental

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274612 | Waterlogged Burial Shroud | Back |  | 24.29 |  | ✔ | guide+wowhead-forever |
| 274611 | Robe of the Drowned | Chest (cloth) |  | 32.86 |  | ✔ | guide+wowhead-forever |
| 274613 | Priestess Cloak | Back |  |  |  | ✔ | guide+wowhead-forever |
| 274614 | Knucklebone Ring | Finger |  |  |  | ✔ | guide+wowhead-forever |
| 274615 | Heart of the Primeval | Trinket |  | 42.86 |  | ✔ | guide+wowhead-forever |
| 276894 | Ancient Gurubashi Idol (quest) | Quest Item |  |  |  | ✔ | guide |

### Min'loth the Serpent

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274610 | Ritual-Binder's Gloves | Hands (leather) |  | 34.17 |  | ✔ | guide+wowhead-forever |
| 274608 | Maw of Min'loth | Shield |  | 35 |  | ✔ | guide+wowhead-forever |
| 274609 | Serpentbane Crown | Head (mail) |  | 30.83 |  | ✔ | guide+wowhead-forever |

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| 629 | The Vile Reef | 37 | Horde | Kin'weelay (2519) | Stranglethorn Vale |  | **no** |
| 95748 | The Gurubashi Legends of Old | 40 | Horde | Kin'weelay (2519) | Stranglethorn Vale | The Vile Reef (629) | **no** |
| 95770 | Locating the Lost City | 40 | Horde | Kin'weelay (likely) (2519) | Stranglethorn Vale | The Gurubashi Legends of Old (95748) | **no** |
| 95775 | The Drowned City | 40 | Horde | Kin'weelay (likely) (2519) | Stranglethorn Vale | Locating the Lost City (95770) | **no** |
| 95773 | Enemies in the Water | 37 | Horde |  | Stranglethorn Vale (Grom'gol Base Camp) |  | **no** |
| 95776 | The Only Good Brinescale... | 38 | Horde |  | Stranglethorn Vale (Grom'gol Base Camp) | Enemies in the Water (95773) | **no** |
| 96774 | Ancient Gurubashi Idol | 40 | Horde | Mazu'kon (264074) | Mulgore |  | **no** |
| 95789 | Shady Saltseers | 40 | Both | Krazek (773) | Booty Bay |  | **no** |
| 95791 | The Saltseer Captain | 40 | Both |  | Booty Bay (likely) |  | **no** |
| 95786 | An Acquaintance in Southshore |  | Alliance | Brother Nimetz (likely) (739) | Stranglethorn Vale |  | **no** |
| 95787 | Take Two With Water | 40 | Alliance | Loremaster Dibbs (2277) | Hillsbrad Foothills (Southshore) | An Acquaintance in Southshore (95786) | **no** |
| 95799 | Findings for the Explorer's League |  | Alliance | Historian Karnik (2916) | Ironforge | Take Two With Water (95787) | **no** |
| 95788 | Magics of the Drowned City | 40 | Alliance | Loremaster Dibbs (2277) | Hillsbrad Foothills (Southshore) |  | **no** |
| 95798 | The Web of Magic |  | Alliance | Abra Cadabra (252019) | Dalaran | Magics of the Drowned City (95788) | **no** |
| 97130 | Ancient Gurubashi Secrets | 40 | Alliance | Archmage Timear (31439) | Dalaran (outside Violet Hold) |  | **no** |

## Forever changes noted by guides

- Entirely new Forever dungeon (contested, swim-in only)
- Classic quest The Vile Reef (629) extended with new chain 95748/95770/95775
- All quests besides 629 are new; all boss loot is new (item IDs 2746xx)
- Counts toward Experienced Spelunker achievement (62032, 1 Legacy Point)

## Open questions (check in game)

- [ ] Guide 'Deathless Marrow' mapped to encounter 3478 'Deathless Guardians' (assumed same fight). Check in game.
- [ ] No pin for 'Zul'Alai' (encounter 3474) in DungeonPinData.lua.
- [ ] No pin for 'Var'Taka' (encounter 3475) in DungeonPinData.lua.
- [ ] No pin for 'Captain Dreadrise' (encounter 3476) in DungeonPinData.lua.
- [ ] No pin for 'Deathless Marrow' (encounter 3478) in DungeonPinData.lua.
- [ ] No pin for 'Primeval Elemental' (encounter 3511) in DungeonPinData.lua.
- [ ] Boss 'Gill' (guide) has no DungeonEncounter in DungeonBosses.lua - renamed, trash-boss or event boss?
- [ ] No pin for 'Min'loth the Serpent' (encounter 3479) in DungeonPinData.lua.

## Research notes

- No drop chances on guide; 7 of 18 items 'seen', 11 'probable' via journal addon data
- Primeval Elemental (273738) shares encounter with Deathless Marrow; listed separately here because loot is attributed separately
- Gill (270888): level, abilities, loot unknown
- Several quest givers marked likely/unconfirmed by guide
- Zin'aka shark (263742) is not a boss
- Brinescale Trident drops from Brinescale Skirmisher (262397); Voodoo-Infused Artifact from Saltseer pirates
