# Alcaz Prison (map 2994)

- Level: 48-53 · Entrance: Dustwallow Marsh (Alcaz Island) · Faction: both
- Status: **live** - new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet
- Sources: http://worldofwarcraft.blizzard.com/en-us/news/24301455, https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://conquestcapped.com/guides/wow-forever/wow-forever-alcaz-prison-guide/, https://www.warcrafttavern.com/forever/guides/alcaz-island-prison/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10
- Keys / attunement: No entry key. Overseer's Keyring item=263992 (Overseer Wrex) opens lower-floor door.

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Overseer Wrex | Aufseher Wrex | 3403 | ? | — | jail room near entrance; calls jailers on pull |
| 2 |  | The Questioner | Der Verhörer | 3415 | 256236 | — | interrogation area (game list puts him 4th) |
| 3 |  | Tidemistress Ca'zass | Gezeitenherrin Ca'zass | 3410 | 255997 | — | naga room with caster adds |
| 4 |  | Katerina the Cleaner | Katerina die Aufräumerin | 3418 | 257016 | — | room with chained prisoners |
| 5 |  | Blazeroar | Blazeroar | 3409 | 255702, 255707 ⚠ | — | final room; disguised as prisoner Zarla Ober |

## Loot

Columns: guide % = Forever guide (some guides say their chances are classic values); WH-F % = Wowhead Forever tooltip drop chance (only when Wowhead's top source is this boss; caution: Wowhead shows such chances even for raids not open in Forever, so they are partly imported classic statistics); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (named for this boss by a Forever guide, or a new Forever item that Wowhead Forever ties to this boss). ✘ 404 = item ID does not exist on Wowhead Forever.

### Overseer Wrex

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 263992 | Overseer's Keyring | Key (opens lower floor) |  |  |  | ✔ | guide |
| 276733 | Grips of Control | Hands (Plate) |  |  |  | ✔ | guide |
| 276734 | Wrex's Pinky Ring | Finger |  |  |  | ✔ | guide |

### The Questioner

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 276742 | Girdle of Extracted Answers | Waist (Plate) |  |  |  | ✔ | guide |
| 276743 | Fingerbreaker Stamp | Trinket |  |  |  | ✔ | guide |
| 276741 | Defias Enforcer's Shoulderpads | Shoulder (Leather) |  | 100 |  | ✔ | guide+wowhead-forever |

### Tidemistress Ca'zass

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 276735 | Tidesong Wand | Wand |  |  |  | ✔ | guide |
| 276736 | Seascale Bracers | Wrist (Mail) |  |  |  | ✔ | guide |
| 276737 | Cloak of the Tidemistress | Back |  |  |  | ✔ | guide |
| 273883 | Ca'zass's Head (quest) | Quest |  |  |  | ✔ | guide |

### Katerina the Cleaner

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 276739 | Cutthroat Chestguard | Chest (Mail) |  |  |  | ✔ | guide |
| 276738 | Katerina's Shanker | One-Hand Dagger |  |  |  | ✔ | guide |

### Blazeroar

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 276890 | Zarla's Journal (quest) | Quest |  |  |  | ✔ | guide |

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| ? | No Orc Left Behind |  | Horde | Sergeant Ulka (260383) | Dustwallow Marsh (outside prison, 70.4,19.0) |  | **no** |
| ? | The Honor of the Kor'kron |  | Horde | Commander Folkar (260386) | Alcaz Prison (cells) | No Orc Left Behind | **no** |
| ? | Bad News for Folkar |  | Horde | Perfumed Note | Alcaz Prison (hidden room behind Blazeroar) | The Honor of the Kor'kron | **no** |
| ? | Thrall Needs to Know |  | Horde | Commander Folkar (260386) | Alcaz Prison | Bad News for Folkar; turn in Thrall (npc 4949) Orgrimmar | **no** |
| ? | Blood Red Bandanas |  | Horde | unconfirmed (Kor'kron at prison?) |  | 8x Blood Red Bandana 274028; turn in Eitrigg (npc 3144) Orgrimmar | **no** |
| ? | A Little Payback | 53 | Horde |  |  | 15 Strashaz Soldier (255995), 8 Strashaz Enchantress, Ca'zass's Head 273883 | **no** |
| 96772 | The Dragon's Journal | 53 | Alliance | Archmage Lan'dalock (probable) (20735) | Alterac Mountains (Dalaran) | Zarla's Journal 276890 from Blazeroar; rewards rep only | **no** |
| 95283 | The Missing Kor'kron | 53 | Horde |  | Dustwallow Marsh | probable lead-up; ends Nazeer Bloodpike (4791) Brackenwall | **no** |
| 95284 | The Elite of the Elite | 53 | Horde |  | Dustwallow Marsh | probable lead-up; link to Ulka unconfirmed | **no** |

## Forever changes noted by guides

- Entirely new Forever dungeon (instance zone=16620), open since Nov 4 launch
- Counts toward Master Spelunker achievement=62033
- New item set Defias Enforcer's Garb item-set=2136 (leather)

## Open questions (check in game)

- [ ] No pin for 'Overseer Wrex' (encounter 3403) in DungeonPinData.lua.
- [ ] No pin for 'The Questioner' (encounter 3415) in DungeonPinData.lua.
- [ ] No pin for 'Tidemistress Ca'zass' (encounter 3410) in DungeonPinData.lua.
- [ ] No pin for 'Katerina the Cleaner' (encounter 3418) in DungeonPinData.lua.
- [ ] NPC 255707 is 'Zarla Ober' on Wowhead Forever, guide says 'Blazeroar'.
- [ ] No pin for 'Blazeroar' (encounter 3409) in DungeonPinData.lua.

## Research notes

- conquestcapped: no drop chances stated; many quest IDs not public yet
- Boss levels: Wrex 50, Questioner 51, Ca'zass 50, Katerina 52, Blazeroar 53
- Overseer Wrex npc ID not listed on either source
- Cloak of the Tidemistress and Katerina's Shanker are 'probable' attributions
- Blazeroar boss loot not recorded yet
- Unattributed probable loot: Alcaz Willcrusher 276732 (2H Mace), Sentimental Locket 276740 (Neck), Defias Enforcer's Legguards 276746 (Legs leather); trash BoE: Defias Enforcer's Prowlers 287021, Mask 287019, Chest 287020
- warcrafttavern says level 48-55, pre-launch page with no IDs/quests
- Quest level range from conquestcapped: quests open at 46 or 48
- Commander Folkar hostile to Alliance; Horde equivalent giver note: Mazu'kon (264074) Mulgore
