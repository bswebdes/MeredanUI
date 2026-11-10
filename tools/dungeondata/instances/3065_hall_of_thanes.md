# The Hall of Thanes (map 3065)

- Level: 13-18 · Entrance: Ironforge (Old Ironforge) · Faction: Alliance-leaning, Horde can enter
- Status: **live** - new Forever dungeon
- Sources: http://worldofwarcraft.blizzard.com/en-us/news/24301455, https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/, https://conquestcapped.com/guides/wow-forever/wow-forever-hall-of-thanes-guide/
- Item/NPC/quest checks: Wowhead Forever tooltips (`https://www.wowhead.com/forever/item=ID`), fetched 2026-11-10
- Keys / attunement: None (no attunement or key)

## Bosses (kill order from the guide)

| # | Wing | Boss (en) | Boss (de) | Encounter | NPC ID(s) | Pin (floor x,y) | Location (guide) |
|---|---|---|---|---|---|---|---|
| 1 |  | Faldrim Anvilmar | Faldrim Anvilmar | 3493 | 261306 ⚠ | 1 0.49,0.73 | Anvilmar's Rest, central hall near entrance |
| 2 |  | Magmatus |  | — | 261316 ⚠ | — | Dark Iron dig east of central hall |
| 3 |  | Plunder | Plünderung | 3494 | 261311 ⚠ | 1 0.49,0.64 | hall before the last boss |
| 4 |  | Durgen Dirgehammer | Durgen Dirgehammer | 3496 | 261319 ⚠ | 1 0.49,0.37 | Reliquary of Kings, far end |
| – |  | Infurnus | Infurnus | 3495 | ? | 1 0.63,0.60 |  |

## Loot

Columns: guide % = Forever guide; WH-F % = Wowhead Forever drop chance (only when Wowhead's top source is this boss); repo % = Map/DungeonLoot.lua (classic tables). ✔ = confirmed for Forever (Wowhead Forever drop data for this boss, or listed with chance / as new item in a Forever guide).

### Faldrim Anvilmar

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 270227 | Ephemeral Choker | Neck | 33 |  |  | ✔ | guide |
| 271096 | Aetherwisp Bracers | Wrist (Cloth) | 33 |  |  | ✔ | guide |
| 271097 | Spiritwraith Drape | Back | 34 |  |  | ✔ | guide |

### Magmatus

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 270230 | Kindlegem Girdle | Waist (Mail) | 36 |  |  | ✔ | guide |
| 270231 | Flamefist Grips | Hands (Leather) | 29 |  |  | ✔ | guide |
| 271095 | Fang of Magmatus | Dagger | 35 |  |  | ✔ | guide |

### Plunder

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 270228 | Golemheart Stave | Staff | 34 |  |  | ✔ | guide |
| 270229 | Treads of the Protector Golem | Feet (Mail) | 34 |  |  | ✔ | guide |
| 271098 | Golemguard Chest | Chest (Mail) | 31 |  |  | ✔ | guide |

### Durgen Dirgehammer

| Item ID | Name | Slot / type | guide % | WH-F % | repo % | ✔ | Source |
|---|---|---|---|---|---|---|---|
| 270256 | Durgen's Crescent Axe | One-Hand Axe | 28 |  |  | ✔ | guide |
| 270260 | Direhammer Leggings | Legs (Leather) | 23 |  |  | ✔ | guide |
| 270261 | Robes of the Disgraced Thane | Chest (Cloth) | 23 |  |  | ✔ | guide |
| 274286 | Durgen Dirgehammer's Head (quest) | Quest | 50 |  |  | ✔ | guide |

## Quests

| Quest ID | Title | Lvl | Faction | Giver (NPC ID) | Giver zone | Prerequisite / notes | In DungeonQuests.lua |
|---|---|---|---|---|---|---|---|
| 96391 | Underground Map |  | Alliance | Earthseer Farsen (264936) | Dun Morogh | Dark Iron Map item=274268 from Dark Iron Spy npc=6123 | **no** |
| 96393 | Old Ironforge Incursion | 16 | Alliance | Earthseer Farsen (264936) | Dun Morogh | Underground Map (96391) | **no** |
| 96394 | The Restless Dead | 15 | Alliance | Afadra Dunwall (264943) | Ironforge |  | **no** |
| 96395 | An Ancient Grudge | 15 | Both | Ghostly Attendant (265002) | The Hall of Thanes (inside) |  | **no** |
| 96403 | Important Heirlooms | 15 | Both | Thom Filch (265003) | Old Ironforge (bridge before portal) |  | **no** |
| 98423 | The Treaty of Understanding | 16 | Alliance |  (item 281030) | The Hall of Thanes (last room) |  | **no** |

## Forever changes noted by guides

- New WoW Forever dungeon with four new bosses dropping blue gear
- Each boss drops one of its three items

## Open questions (check in game)

- [ ] NPC 261306 (Faldrim Anvilmar) not found on Wowhead Forever - check ID.
- [ ] Boss 'Magmatus' (guide) has no DungeonEncounter in DungeonBosses.lua - renamed, trash-boss or event boss?
- [ ] NPC 261316 (Magmatus) not found on Wowhead Forever - check ID.
- [ ] NPC 261311 (Plunder) not found on Wowhead Forever - check ID.
- [ ] NPC 261319 (Durgen Dirgehammer) not found on Wowhead Forever - check ID.
- [ ] Encounter 3495 'Infurnus' is in DungeonBosses.lua but not in the guide's boss list - check in game.
- [ ] Quest 96391 'Underground Map' not found on Wowhead Forever - check ID.
- [ ] Quest 96393 'Old Ironforge Incursion' not found on Wowhead Forever - check ID.
- [ ] Quest 96394 'The Restless Dead' not found on Wowhead Forever - check ID.
- [ ] Quest 96395 'An Ancient Grudge' not found on Wowhead Forever - check ID.
- [ ] Quest 96403 'Important Heirlooms' not found on Wowhead Forever - check ID.
- [ ] Quest 98423 'The Treaty of Understanding' not found on Wowhead Forever - check ID.

## Research notes

- Treaty of Understanding turned in to King Magni Bronzebeard npc=2784
- Important Heirlooms needs 8x Dwarven Heirloom item=274289
- Restless Dead targets: Enraged Apparition npc=263389, Tormented Soul npc=263390
- Magmatus adds: Dark Iron Summoner npc=263438, Fiery Assistant npc=263467; Durgen guarded by Lesser Stone Golem npc=263466
- min_level values given as 'from 9/10' unlabeled in source
- Achievement Novice Spelunker achievement=62031
