# The Drowned City (map 2970)

- Level: 35-40 · Entrance: Stranglethorn Vale coast (underwater, west of Grom'gol) · Faction: both
- Status: **live** - new Forever dungeon
- Sources: http://worldofwarcraft.blizzard.com/en-us/news/24301455, https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://conquestcapped.com/guides/wow-forever/wow-forever-the-drowned-city-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Zul'Alai | Zul'Alai | 3474 | 270882 | — | top of the hill after first city section |
| 2 |  | Var'Taka | Var'Taka | 3475 | 270883 | — | Brinescale naga leader with priestesses |
| 3 |  | Captain Dreadrise | Captain Dreadrise | 3476 | 270884 | — | Saltseer pirate captain |
| 4 |  | Deathless Marrow |  | — | 270885 | — | flooded tomb, shared encounter with Primeval Elemental |
| 5 |  | Primeval Elemental | Urtümlicher Elementar | 3511 | 273738 | — | flooded tomb, same encounter as Deathless Marrow |
| 6 |  | Gill |  | — | 270888 | — |  |
| 7 |  | Min'loth the Serpent | Min'loth die Schlange | 3479 | 270886 | — | final room overlooking sunken pirate ship |
| – |  | Deathless Guardians | Unsterbliche Wächter | 3478 | ? | — |  |

## Loot

Columns: guide % = Forever guide; WH-F % = Wowhead Forever drop chance (only when Wowhead's top source is this boss); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (Wowhead Forever drop data for this boss, or listed with chance / as new item in a Forever guide).

### Zul'Alai

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274600 | Berserker Shackles | Wrist (mail) |  |  |  | ✔ | guide |
| 274598 | Bloodslash Axe | One-hand axe |  |  |  | ✔ | guide |
| 274599 | Oathbound Bracers | Wrist (leather) |  |  |  | ✔ | guide |

### Var'Taka

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274602 | Brinebelly Leggings | Legs (leather) |  |  |  | ✔ | guide |
| 274601 | Harpoon of Command | Polearm |  |  |  | ✔ | guide |

### Captain Dreadrise

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274604 | Frosty Blunderbuss | Gun |  |  |  | ✔ | guide |
| 274605 | Briny Sash | Waist (cloth) |  |  |  | ✔ | guide |
| 274603 | Dreadfrost Saber | Main-hand sword |  |  |  | ✔ | guide |

### Deathless Marrow

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274606 | Bloodspine Staff | Staff |  |  |  | ✔ | guide |
| 274607 | Viscera Spaulders | Shoulder (mail) |  |  |  | ✔ | guide |

### Primeval Elemental

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274612 | Waterlogged Burial Shroud | Back |  |  |  | ✔ | guide |
| 274611 | Robe of the Drowned | Chest (cloth) |  |  |  | ✔ | guide |
| 274613 | Priestess Cloak | Back |  |  |  | ✔ | guide |
| 274614 | Knucklebone Ring | Finger |  |  |  | ✔ | guide |
| 274615 | Heart of the Primeval | Trinket |  |  |  | ✔ | guide |
| 276894 | Ancient Gurubashi Idol (quest) |  |  |  |  | ✔ | guide |

### Min'loth the Serpent

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 274610 | Ritual-Binder's Gloves | Hands (leather) |  |  |  | ✔ | guide |
| 274608 | Maw of Min'loth | Shield |  |  |  | ✔ | guide |
| 274609 | Serpentbane Crown | Head (mail) |  |  |  | ✔ | guide |

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

- [ ] No pin for 'Zul'Alai' (encounter 3474) in DungeonPinData.lua.
- [ ] No pin for 'Var'Taka' (encounter 3475) in DungeonPinData.lua.
- [ ] No pin for 'Captain Dreadrise' (encounter 3476) in DungeonPinData.lua.
- [ ] Boss 'Deathless Marrow' (guide) has no DungeonEncounter in DungeonBosses.lua - renamed, trash-boss or event boss?
- [ ] No pin for 'Primeval Elemental' (encounter 3511) in DungeonPinData.lua.
- [ ] Boss 'Gill' (guide) has no DungeonEncounter in DungeonBosses.lua - renamed, trash-boss or event boss?
- [ ] No pin for 'Min'loth the Serpent' (encounter 3479) in DungeonPinData.lua.
- [ ] Encounter 3478 'Deathless Guardians' is in DungeonBosses.lua but not in the guide's boss list - check in game.
- [ ] Quest 629 'The Vile Reef' not found on Wowhead Forever - check ID.
- [ ] Quest 95748 'The Gurubashi Legends of Old' not found on Wowhead Forever - check ID.
- [ ] Quest 95770 'Locating the Lost City' not found on Wowhead Forever - check ID.
- [ ] Quest 95775 'The Drowned City' not found on Wowhead Forever - check ID.
- [ ] Quest 95773 'Enemies in the Water' not found on Wowhead Forever - check ID.
- [ ] Quest 95776 'The Only Good Brinescale...' not found on Wowhead Forever - check ID.
- [ ] Quest 96774 'Ancient Gurubashi Idol' not found on Wowhead Forever - check ID.
- [ ] Quest 95789 'Shady Saltseers' not found on Wowhead Forever - check ID.
- [ ] Quest 95791 'The Saltseer Captain' not found on Wowhead Forever - check ID.
- [ ] Quest 95786 'An Acquaintance in Southshore' not found on Wowhead Forever - check ID.
- [ ] Quest 95787 'Take Two With Water' not found on Wowhead Forever - check ID.
- [ ] Quest 95799 'Findings for the Explorer's League' not found on Wowhead Forever - check ID.
- [ ] Quest 95788 'Magics of the Drowned City' not found on Wowhead Forever - check ID.
- [ ] Quest 95798 'The Web of Magic' not found on Wowhead Forever - check ID.
- [ ] Quest 97130 'Ancient Gurubashi Secrets' not found on Wowhead Forever - check ID.

## Research notes

- No drop chances on guide; 7 of 18 items 'seen', 11 'probable' via journal addon data
- Primeval Elemental (273738) shares encounter with Deathless Marrow; listed separately here because loot is attributed separately
- Gill (270888): level, abilities, loot unknown
- Several quest givers marked likely/unconfirmed by guide
- Zin'aka shark (263742) is not a boss
- Brinescale Trident drops from Brinescale Skirmisher (262397); Voodoo-Infused Artifact from Saltseer pirates
