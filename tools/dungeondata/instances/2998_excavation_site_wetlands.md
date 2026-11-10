# Excavation Site: Wetlands (map 2998)

- Level: 24-29 · Entrance: Wetlands (near Thelgen Rock) · Faction: both
- Status: **live** - new Forever dungeon (Blizzard 24-29; guides/beta 26-31)
- Sources: http://worldofwarcraft.blizzard.com/en-us/news/24301455, https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://conquestcapped.com/guides/wow-forever/wow-forever-excavation-site-wetlands-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10
- Keys / attunement: None

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Saltspine | Salzrücken | 3480 | 260322 | 1 0.80,0.06 | marsh near start, among elite crocolisks |
| 2 |  | Shadetooth | Schemenzahn | 3481 | 260325 | — | tall grass, appears after Thicket Matriarch dies |
| 3 |  | Highland Horror (optional) | Hochlandschrecken | 3644 | 260808 | — | Dragonmaw camp |
| 4 |  | Relic Guardian | Reliktwächter | 3482 | 260326 | — | end of spider trail; activated via Archival Panel |

## Loot

Columns: guide % = Forever guide; WH-F % = Wowhead Forever drop chance (only when Wowhead's top source is this boss); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (Wowhead Forever drop data for this boss, or listed with chance / as new item in a Forever guide).

### Saltspine

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 273022 | Supple Bellyskin Leggings | Legs (Leather) | 35 |  |  | ✔ | guide |
| 273023 | Saltscale Girdle | Waist (Mail) | 34 |  |  | ✔ | guide |
| 273024 | Glinteye Slippers | Feet (Cloth) | 31 |  |  | ✔ | guide |

### Shadetooth

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 273027 | Raptor's Gaze | Off-hand | 34 |  |  | ✔ | guide |
| 273026 | Garb of Florid Feathers | Chest (Leather) | 32 |  |  | ✔ | guide |
| 273025 | Raptorclaw Greaves | Feet (Mail) | 27 |  |  | ✔ | guide |
| 273106 | Blueprint: Greenhouse | Recipe | 8 |  |  | ✔ | guide |

### Highland Horror

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 270180 | Horrible Rootcore (quest) | Quest (95646) |  |  |  | ✔ | guide |

### Relic Guardian

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 273028 | Reliquary Mantle | Shoulder (Mail) | 34 |  |  | ✔ | guide |
| 273029 | Golemsight Long Gun | Gun | 31 |  |  | ✔ | guide |
| 273030 | Ring of Power Regulation | Finger | 30 |  |  | ✔ | guide |
| 270865 | Titan Relic (Alliance) (quest) | Quest starter (95810) | 27 |  |  | ✔ | guide |
| 270866 | Titan Relic (Horde) (quest) | Quest starter (95664) | 27 |  |  | ✔ | guide |
| 273097 | Blueprint: Rock Garden | Recipe | 7 |  |  | ✔ | guide |

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| 95810 | Lost Relic Carry | 24 | Alliance |  (item 270865) | Excavation Site: Wetlands (Relic Guardian drop) |  | **no** |
| 98824 | Prehistoric Prism | 24 | Alliance | Prospector Whelgar (1077) | Wetlands (Whelgar's Excavation) | Lost Relic Carry (95810) | **no** |
| 95772 | Songblade Search | 24 | Alliance | Dorin Songblade (956) | Redridge Mountains (Lakeshire) |  | **no** |
| 95795 | Fallen in the Fen | 24 | Alliance | Daewyn Songblade's body | Excavation Site: Wetlands (inside) | Songblade Search (95772) | **no** |
| 95646 | Horrors in the Highland | 31 | Alliance | Rethiel the Greenwarden (1244) | Wetlands | Blisters on the Land (275) | **no** |
| 463 | The Greenwarden | 21 | Alliance | First Mate Fitzsimmons (1239) | Wetlands (Menethil Harbor) |  | **no** |
| 276 | Tramping Paws | 21 | Alliance | Rethiel the Greenwarden (1244) | Wetlands | The Greenwarden (463) | **no** |
| 277 | Fire Taboo | 23 | Alliance | Rethiel the Greenwarden (1244) | Wetlands | Tramping Paws (276) | **no** |
| 275 | Blisters on the Land | 26 | Alliance | Rethiel the Greenwarden (1244) | Wetlands | Fire Taboo (277) | **no** |
| 95737 | Seeking Caitlin | 24 | Alliance | Llana (3970) | Ashenvale |  | **no** |
| 95647 | Lost in the Thicket Things | 24 | Alliance | Caitlin Grassman (1480) | Wetlands (Menethil Harbor) | Seeking Caitlin (95737) | **no** |
| 95809 | Heartwoven | 31 | Alliance | Ardin Grassman (262681) | Excavation Site: Wetlands (inside) | Lost in the Thicket Things (95647) | **no** |
| 484 | Young Crocolisk Skins | 22 | Alliance | James Halloran (2094) | Wetlands (Menethil Harbor) |  | **no** |
| 98815 | Highland Hides | 28 | Alliance | James Halloran (2094) | Wetlands (Menethil Harbor) | Young Crocolisk Skins (484) | **no** |
| 95664 | Elder Knowledge | 24 | Horde |  (item 270866) | Excavation Site: Wetlands (Relic Guardian drop) |  | **no** |
| 98823 | Earthen Echo | 24 | Horde | Bashana Runetotem (9087) | Thunder Bluff | Elder Knowledge (95664) | **no** |
| 95663 | Dragonmaw Rumors | 24 | Horde | Zaruk (2787) | Arathi Highlands (Hammerfall) |  | **no** |
| 95682 | Open the Maw | 31 | Horde | Deathstalker Agent (13155) | Excavation Site: Wetlands (entrance) | Dragonmaw Rumors (95663) | **no** |
| 95697 | Changing Tastes | 24 | Horde | Borstan (3368) | Orgrimmar |  | **no** |

## Forever changes noted by guides

- New WoW Forever dungeon (not in Classic)
- Achievement Novice Spelunker (62031) awards a Legacy Point

## Open questions (check in game)

- [ ] No pin for 'Shadetooth' (encounter 3481) in DungeonPinData.lua.
- [ ] No pin for 'Highland Horror' (encounter 3644) in DungeonPinData.lua.
- [ ] No pin for 'Relic Guardian' (encounter 3482) in DungeonPinData.lua.
- [ ] Quest 95810 'Lost Relic Carry' not found on Wowhead Forever - check ID.
- [ ] Quest 98824 'Prehistoric Prism' not found on Wowhead Forever - check ID.
- [ ] Quest 95772 'Songblade Search' not found on Wowhead Forever - check ID.
- [ ] Quest 95795 'Fallen in the Fen' not found on Wowhead Forever - check ID.
- [ ] Quest 95646 'Horrors in the Highland' not found on Wowhead Forever - check ID.
- [ ] Quest 463 'The Greenwarden' not found on Wowhead Forever - check ID.
- [ ] Quest 276 'Tramping Paws' not found on Wowhead Forever - check ID.
- [ ] Quest 277 'Fire Taboo' not found on Wowhead Forever - check ID.
- [ ] Quest 275 'Blisters on the Land' not found on Wowhead Forever - check ID.
- [ ] Quest 95737 'Seeking Caitlin' not found on Wowhead Forever - check ID.
- [ ] Quest 95647 'Lost in the Thicket Things' not found on Wowhead Forever - check ID.
- [ ] Quest 95809 'Heartwoven' not found on Wowhead Forever - check ID.
- [ ] Quest 484 'Young Crocolisk Skins' not found on Wowhead Forever - check ID.
- [ ] Quest 98815 'Highland Hides' not found on Wowhead Forever - check ID.
- [ ] Quest 95664 'Elder Knowledge' not found on Wowhead Forever - check ID.
- [ ] Quest 98823 'Earthen Echo' not found on Wowhead Forever - check ID.
- [ ] Quest 95663 'Dragonmaw Rumors' not found on Wowhead Forever - check ID.
- [ ] Quest 95682 'Open the Maw' not found on Wowhead Forever - check ID.
- [ ] Quest 95697 'Changing Tastes' not found on Wowhead Forever - check ID.

## Research notes

- Guide quest table lists level 24 for all quests; chain text gives 28 (98815), 31 (95809, 95646, 95682) - used chain values for level, 24 as min_level
- Guide summary placed James Halloran for quest 484 'inside the dungeon'; he is normally in Menethil Harbor - unverified
- Changing Tastes rewards: choice of 280766 or 280805, plus recipe 250185 and 250077
- Quest XP from beta
