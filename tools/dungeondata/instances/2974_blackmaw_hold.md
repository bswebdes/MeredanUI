# Blackmaw Hold (map 2974)

- Level: 55-60 · Entrance: Azshara (north, Furbolg gate) · Faction: both
- Status: **live** - new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet
- Sources: http://worldofwarcraft.blizzard.com/en-us/news/24301455, https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://conquestcapped.com/guides/wow-forever/wow-forever-blackmaw-hold-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Withermaw | Welkschlund | 3315 | 247195 | — |  |
| 2 |  | Impaan the Imprisoner | Impaan der Kerkermeister | 3316 | 247206 | — |  |
| 3 |  | Elder Shaman Bloodmane | Schamanenältester Bloodmane | 3327 | 247209 | — |  |
| 4 |  | Bonesnout the Unbroken | Knochenschnauze der Ungebrochene | 3322 | 247198 | — |  |
| 5 |  | Varrox Bleakhoof | Varrox Bleakhoof | 3334 | 247234 | — |  |
| 6 |  | Blackmaw Behemoth | Behemoth des Schwarzschlunds | 3323 | 247207 ⚠ | — |  |
| 7 |  | Unbound Spirit | Ungebundener Geist | 3336 | 247231 | — |  |

### Rares

| NPC ID | Name | Pin | Location (guide) |
|---|---|---|---|
| 269104 | Moontouched Wanderer | — |  |

## Loot

Columns: guide % = Forever guide (some guides say their chances are classic values); WH-F % = Wowhead Forever tooltip drop chance (only when Wowhead's top source is this boss; caution: Wowhead shows such chances even for raids not open in Forever, so they are partly imported classic statistics); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (named for this boss by a Forever guide, or a new Forever item that Wowhead Forever ties to this boss). ✘ 404 = item ID does not exist on Wowhead Forever.

### Withermaw

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 249697 | Claws of the Great Bear (quest) | Quest |  | 100 |  | ✔ | guide+wowhead-forever |
| 280064 | Withering Grips | Hands (Leather) |  |  |  | ✔ | guide |

### Impaan the Imprisoner

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 280058 | Impish Chain Hood | Head (Mail) |  |  |  | ✔ | guide |

### Elder Shaman Bloodmane

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 276893 | Blackmaw Ritual Totem (quest) | Quest |  | 100 |  | ✔ | guide+wowhead-forever |
| 286415 | Reliquary of Tyr (quest) | Quest (Paladin, epic) |  | 100 |  | ✔ | guide+wowhead-forever |

### Bonesnout the Unbroken

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 249696 | Tusks of the Unbroken (quest) | Quest |  | 100 |  | ✔ | guide+wowhead-forever |
| 280060 | Lucky Shovelnose Tuft | Trinket |  |  |  | ✔ | guide |

### Varrox Bleakhoof

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 249692 | Head of Varrox Bleakhoof (quest) | Quest |  | 100 |  | ✔ | guide+wowhead-forever |
| 272027 | Mark of Xavius (quest) | Quest |  | 100 |  | ✔ | guide+wowhead-forever |

### Moontouched Wanderer

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 280080 | Claymore of Two Moons | Two-Hand Sword |  |  |  | ✔ | guide |

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| 92069 | Claws That Rend, Tusks that Gore | 58 | Both | Ogtinc (8405) | Azshara |  | **no** |
| 92346 | Beneath Nordrassil | 55 | Horde | Jediga (8587) | Azshara (Valormok) |  | **no** |
| 92343 | Get to the Roots of It | 55 | Horde | Nara Wildmane (5770) | Thunder Bluff | Beneath Nordrassil (92346) | **no** |
| 97198 | Blackmaw Magic | 59 | Horde |  |  |  | **no** |
| 92345 | Beneath Nordrassil | 55 | Alliance |  |  |  | **no** |
| 92344 | Get to the Roots of It | 55 | Alliance | Mathrengyl Bearwalker (4217) | Darnassus | Beneath Nordrassil (92345) | **no** |
| 97173 | Blackmaw Magic | 59 | Alliance |  | Dalaran? (unconfirmed) |  | **no** |

## Forever changes noted by guides

- New Forever dungeon; the old northern Azshara 'Timbermaw Hold' gate now leads here
- Beneath Nordrassil / Blackmaw Magic quests are Forever content
- Counts toward Master Spelunker (achievement 62033)
- Deep tunnels lead toward Barrow Deeps raid

## Open questions (check in game)

- [ ] No pin for 'Withermaw' (encounter 3315) in DungeonPinData.lua.
- [ ] No pin for 'Impaan the Imprisoner' (encounter 3316) in DungeonPinData.lua.
- [ ] No pin for 'Elder Shaman Bloodmane' (encounter 3327) in DungeonPinData.lua.
- [ ] No pin for 'Bonesnout the Unbroken' (encounter 3322) in DungeonPinData.lua.
- [ ] No pin for 'Varrox Bleakhoof' (encounter 3334) in DungeonPinData.lua.
- [ ] NPC 247207 (Blackmaw Behemoth) not found on Wowhead Forever - check ID.
- [ ] No pin for 'Blackmaw Behemoth' (encounter 3323) in DungeonPinData.lua.
- [ ] No pin for 'Unbound Spirit' (encounter 3336) in DungeonPinData.lua.

## Research notes

- No drop chances published on the guide
- Boss locations not given; order is the guide's encounter numbering
- Ogtinc as giver of 92069 marked 'most likely' by the guide
- Horde Blackmaw Magic linked as 97198 in one place, 97173 in another; 97173 is the Alliance version
- Unassigned quest items: Totem of Ursol 249693, Totem of Ursoc 249694, Feathered Charm Necklace 249698, Blackmaw Pouch 273050
- Get to the Roots of It requires 10x Nordrassil Root Cap (250773)
