# Ruins of Lordaeron (map 2999)

- Level: 15-20 · Entrance: Tirisfal Glades (above Undercity) · Faction: Horde-leaning, Alliance can enter
- Status: **live** - new Forever dungeon
- Sources: http://worldofwarcraft.blizzard.com/en-us/news/24301455, https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://conquestcapped.com/guides/wow-forever/wow-forever-ruins-of-lordaeron-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10
- Keys / attunement: None

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | The Baron |  | — | 250660 ⚠ | — | guards one of the city streets |
| 2 |  | Witherfang | Welkzahn | 3353 | 250483 ⚠ | — | King's Alley, giant spider with patrols |
| 3 |  | The Abandoned (optional) | Der Verlassene | 3357 | 250631 ⚠ | — | event from statue with glowing green eyes |
| 4 |  | Bjork | Bjork | 3412 | 256097 ⚠ | — | courtyard with walls and pavilion |
| 5 |  | Viktor the Vile (optional) | Viktor der Üble | 3411 | 256035 ⚠ | — | burned house at south end; light chimney fire |
| 6 |  | Rath'mael | Rath'mael | 3354 | 250657 ⚠ | — | graveyard, usually last |
| – |  | The Butcher | Der Schlächter | 3355 | ? | — |  |

### Rares

| NPC ID | Name | Pin | Location (guide) |
|---|---|---|---|
| 255699 | Lordaeron Captain | — | roams north-west on some runs |

## Loot

Columns: guide % = Forever guide; WH-F % = Wowhead Forever drop chance (only when Wowhead's top source is this boss); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (Wowhead Forever drop data for this boss, or listed with chance / as new item in a Forever guide).

### The Baron

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 271205 | Abomination Bones | Chest (Mail) | 29 |  |  | ✔ | guide |
| 271206 | Leftover Abomination Skin | Chest (Cloth) | 31 |  |  | ✔ | guide |
| 271204 | Meathook Slicer | Dagger |  |  |  | ✔ | guide |
| 280438 | Abominable Head (quest) | Quest | 41 |  |  | ✔ | guide |
| 268518 | Head of the Baron (quest) | Quest |  |  |  | ✔ | guide |

### Witherfang

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 271203 | Segmented Spider Leg | Staff | 31 |  |  | ✔ | guide |
| 271202 | Witherbite Bracers | Wrist (Leather) | 29 |  |  | ✔ | guide |
| 271201 | Atrophic Girdle | Waist (Mail) | 26 |  |  | ✔ | guide |
| 275443 | Highly Toxic Strain (quest) | Quest |  |  |  | ✔ | guide |

### The Abandoned

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 271207 | Rotmender's Leggings | Legs (Cloth) | 34 |  |  | ✔ | guide |
| 271216 | Scepter of the Abandoned | One-Hand Mace | 34 |  |  | ✔ | guide |
| 271208 | Grip of Fear | Hands (Mail) | 32 |  |  | ✔ | guide |

### Bjork

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 271217 | Corpse Chopper | Two-Hand Axe | 33 |  |  | ✔ | guide |
| 271210 | Tuskwrap Belt | Waist (Cloth) | 34 |  |  | ✔ | guide |
| 271209 | Bonerust Leggings | Legs (Mail) | 33 |  |  | ✔ | guide |

### Viktor the Vile

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 271211 | Vilewalkers | Feet (Mail) | 35 |  |  | ✔ | guide |
| 271212 | Bloodied Chestwraps | Chest (Leather) | 33 |  |  | ✔ | guide |
| 271218 | Vileblood Scimitar | One-Hand Sword | 32 |  |  | ✔ | guide |

### Rath'mael

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 271213 | Mirror of Rath'mael | Shield | 37 |  |  | ✔ | guide |
| 271215 | Coldspire Staff | Staff | 33 |  |  | ✔ | guide |
| 271214 | Rotmender's Treads | Feet (Cloth) | 30 |  |  | ✔ | guide |
| 273085 | Blueprint: Fermenter | Recipe | 8 |  |  | ✔ | guide |
| 273103 | Blueprint: Arcane Salvager | Recipe |  |  |  | ✔ | guide |

### Lordaeron Captain

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 6641 | Haunting Blade | Two-Hand Sword |  |  |  | ✔ | guide |
| 6642 | Phantom Armor | Chest Mail |  |  |  | ✔ | guide |

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| 95195 | Bloodied Insignia | 22 | Alliance |  (item 268540) | Ruins of Lordaeron (drop inside); turn in General Marcus Jonathan npc=466, Stormwind | needs 10 insignias | **no** |
| 92415 | Remember That I Love You | 22 | Alliance |  (item 251522) | Ruins of Lordaeron (graveyard); turn in Orphan Matron Nightingale npc=14450, Stormwind |  | **no** |
| 95161 | Remember That I Love You (step 2) |  | Alliance | Avette Fellwood (228) | Duskwood | 92415 | **no** |
| 95189 | Crest of Lordaeron | 22 | Alliance |  (item 268579) | Ruins of Lordaeron (inside); turn in Lady Dena Kennedy npc=15991, Stormwind |  | **no** |
| 95250 | Abominable Creatures | 21 | Alliance | Captain Truman (265701) | Ruins of Lordaeron (inside entrance) | Head of the Baron item=268518 | **no** |
| 92422 | The Wrath of Rath'mael | 22 | Horde | Deathguard Kristof (251001) | Tirisfal Glades (SE of Brill) | Rear Guard Patrol (356) and Rear Guard Patrol (99156, kill Riptear npc=276020) | **no** |
| 95216 | The New Plague | 22 | Horde | Theodore Griffs (11835) | Undercity (Apothecarium) | A Recipe For Death 447 -> 450 -> 451 | **no** |
| 95204 | Crest of Lordaeron | 22 | Horde |  (item 275521) | Ruins of Lordaeron (inside); turn in Oran Snakewrithe npc=7825, Undercity |  | **no** |
| 97288 | Unending Torment | 21 | Horde |  (item 280438) | Ruins of Lordaeron (Abominable Head from The Baron) | chain ends at 97290; needs items 281246, 281300, 8923, 281327 | **no** |
| 92421 | Light's Justice | 22 | Horde | Morbin Lightbane (266484) | Undercity (Royal Quarter) | 25 Intact Limbs item=268580 | **no** |
| 92401 | A Frightened Request | 22 | Horde | Tabitha Heartweaver (250686) | Silverpine Forest (Sepulcher) |  | **no** |
| 356 | Rear Guard Patrol | 11 | Horde | Deathguard Linnea (1495) | Tirisfal Glades |  | **no** |
| 99156 | Rear Guard Patrol (Riptear) |  | Horde |  | Tirisfal Glades | 356 | **no** |

## Forever changes noted by guides

- New WoW Forever dungeon: open city, six bosses in any order
- The Abandoned and Viktor the Vile appear only after events
- Since Nov 4 launch, Wrath of Rath'mael and New Plague have pre-quest chains
- Since Nov 2 update all quests available from level 15

## Open questions (check in game)

- [ ] Boss 'The Baron' (guide) has no DungeonEncounter in DungeonBosses.lua - renamed, trash-boss or event boss?
- [ ] NPC 250660 (The Baron) not found on Wowhead Forever - check ID.
- [ ] NPC 250483 (Witherfang) not found on Wowhead Forever - check ID.
- [ ] No pin for 'Witherfang' (encounter 3353) in DungeonPinData.lua.
- [ ] NPC 250631 (The Abandoned) not found on Wowhead Forever - check ID.
- [ ] No pin for 'The Abandoned' (encounter 3357) in DungeonPinData.lua.
- [ ] NPC 256097 (Bjork) not found on Wowhead Forever - check ID.
- [ ] No pin for 'Bjork' (encounter 3412) in DungeonPinData.lua.
- [ ] NPC 256035 (Viktor the Vile) not found on Wowhead Forever - check ID.
- [ ] No pin for 'Viktor the Vile' (encounter 3411) in DungeonPinData.lua.
- [ ] NPC 250657 (Rath'mael) not found on Wowhead Forever - check ID.
- [ ] No pin for 'Rath'mael' (encounter 3354) in DungeonPinData.lua.
- [ ] Encounter 3408 'Lordaeron Captain' is listed as a rare in the guide (DungeonBosses.lua has it as boss).
- [ ] Encounter 3355 'The Butcher' is in DungeonBosses.lua but not in the guide's boss list - check in game.
- [ ] Quest 95195 'Bloodied Insignia' not found on Wowhead Forever - check ID.
- [ ] Quest 92415 'Remember That I Love You' not found on Wowhead Forever - check ID.
- [ ] Quest 95161 'Remember That I Love You (step 2)' not found on Wowhead Forever - check ID.
- [ ] Quest 95189 'Crest of Lordaeron' not found on Wowhead Forever - check ID.
- [ ] Quest 95250 'Abominable Creatures' not found on Wowhead Forever - check ID.
- [ ] Quest 92422 'The Wrath of Rath'mael' not found on Wowhead Forever - check ID.
- [ ] Quest 95216 'The New Plague' not found on Wowhead Forever - check ID.
- [ ] Quest 95204 'Crest of Lordaeron' not found on Wowhead Forever - check ID.
- [ ] Quest 97288 'Unending Torment' not found on Wowhead Forever - check ID.
- [ ] Quest 92421 'Light's Justice' not found on Wowhead Forever - check ID.
- [ ] Quest 92401 'A Frightened Request' not found on Wowhead Forever - check ID.
- [ ] Quest 356 'Rear Guard Patrol' not found on Wowhead Forever - check ID.
- [ ] Quest 99156 'Rear Guard Patrol (Riptear)' not found on Wowhead Forever - check ID.

## Research notes

- Per-boss levels not given
- Rare loot item IDs listed as integers (Haunting Blade 6641, Phantom Armor 6642, level 22)
- Trash: Stone Watcher npc=250629 drops Rotmender's Gloves item=286979 ~8%; Rotmender's Sash 286980 and Garb 286978 from trash
- Two head items: Abominable Head 280438 (~41%, starts Unending Torment) vs Head of the Baron 268518 (Abominable Creatures); page is ambiguous
- Page says bosses drop blue gear but some items labeled green
- Quest XP: Horde 29,800, Alliance 22,500
