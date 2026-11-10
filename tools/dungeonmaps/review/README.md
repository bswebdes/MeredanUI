# Dungeon map review

All maps below are built from the game's own data (WMO minimap tiles + terrain) with `buildmap.py`,
composed with `compose.py --half` (768x512 map in a 1024x512 BLP, ~256 KB). Previews: 768x512 JPG.

Unchanged: Wailing Caverns (43), Ragefire Chasm (389), Hall of Thanes (3065) - full size, already done.

## Left on the old map

| Instance | Why |
|---|---|
| 533 Naxxramas | Forever's Naxxramas geometry doesn't fit Blizzard's floor regions: floors 1-4 all show the whole necropolis, floor 5 is empty. Stays on Blizzard's map. |
| 2959 City of Dalaran | City renders fine, but there is no sewer WMO with minimap tiles, so floor 2 (Sewers) can't be built. Stays on Santiago's maps. |

## New maps

### 229 Blackrock Spire

- Floors: 6
- Switches: `ASSIGNEDONLY=1 CLASSICGID=7952332:108373` (Forever's rebuilt WMO has the classic group order, so floors map by the classic group IDs)
- Problems: Upper Blackrock Spire has no Blizzard floor and is not shown.


### 36 Deadmines

- Floors: 2
- Switches: plain
- Problems: Floor 2 (Ironclad Cove) is all terrain/water; the ship is not in the minimap tiles.

| Floor 1 | Floor 2 |
|---|---|
| ![36 floor 1](36_1.jpg) | ![36 floor 2](36_2.jpg) |

### 33 Shadowfang Keep

- Floors: 7
- Switches: plain
- Problems: Upper and Lower Observatory look almost the same (stacked floors); Wall Walk shows loose pieces.

| Floor 1 | Floor 2 | Floor 3 | Floor 4 | Floor 5 | Floor 6 | Floor 7 |
|---|---|---|---|---|---|---|
| ![33 floor 1](33_1.jpg) | ![33 floor 2](33_2.jpg) | ![33 floor 3](33_3.jpg) | ![33 floor 4](33_4.jpg) | ![33 floor 5](33_5.jpg) | ![33 floor 6](33_6.jpg) | ![33 floor 7](33_7.jpg) |

### 34 Stockade

- Floors: 1
- Switches: plain
- Problems: none seen

| Floor 1 |
|---|
| ![34 floor 1](34_1.jpg) |

### 48 Blackfathom Deeps

- Floors: 3
- Switches: plain
- Problems: Floor 3 (Forgotten Pool) is only a small pool.

| Floor 1 | Floor 2 | Floor 3 |
|---|---|---|
| ![48 floor 1](48_1.jpg) | ![48 floor 2](48_2.jpg) | ![48 floor 3](48_3.jpg) |

### 90 Gnomeregan

- Floors: 4
- Switches: plain
- Problems: none seen

| Floor 1 | Floor 2 | Floor 3 | Floor 4 |
|---|---|---|---|
| ![90 floor 1](90_1.jpg) | ![90 floor 2](90_2.jpg) | ![90 floor 3](90_3.jpg) | ![90 floor 4](90_4.jpg) |

### 47 Razorfen Kraul

- Floors: 1
- Switches: `NOADT=1 SKIP=19`
- Problems: Thorn canopy removed (exterior group 19 left out); some thorn vines inside the caves remain.

| Floor 1 |
|---|
| ![47 floor 1](47_1.jpg) |

### 189 Scarlet Monastery

- Floors: 4
- Switches: `NOADT=1`
- Problems: none seen

| Floor 1 | Floor 2 | Floor 3 | Floor 4 |
|---|---|---|---|
| ![189 floor 1](189_1.jpg) | ![189 floor 2](189_2.jpg) | ![189 floor 3](189_3.jpg) | ![189 floor 4](189_4.jpg) |

### 129 Razorfen Downs

- Floors: 1
- Switches: `NOADT=1 SKIP=10`
- Problems: Thorn canopy removed (exterior group 10 left out); some thorn vines remain.

| Floor 1 |
|---|
| ![129 floor 1](129_1.jpg) |

### 70 Uldaman

- Floors: 2
- Switches: plain
- Problems: none seen

| Floor 1 | Floor 2 |
|---|---|
| ![70 floor 1](70_1.jpg) | ![70 floor 2](70_2.jpg) |

### 209 Zul'Farrak

- Floors: 1
- Switches: plain
- Switches: `compose.py --soft` (flat orange fill dropped, outline faded)
- Problems: Outdoor dungeon: terrain covers the whole region; the edge of the neighbouring canyon stays (top right).

| Floor 1 |
|---|
| ![209 floor 1](209_1.jpg) |

### 349 Maraudon

- Floors: 2
- Switches: plain
- Problems: none seen

| Floor 1 | Floor 2 |
|---|---|
| ![349 floor 1](349_1.jpg) | ![349 floor 2](349_2.jpg) |

### 109 Sunken Temple

- Floors: 1
- Switches: plain
- Problems: none seen

| Floor 1 |
|---|
| ![109 floor 1](109_1.jpg) |

### 230 Blackrock Depths

- Floors: 2
- Switches: plain
- Problems: Lava is drawn as flat orange areas (that's how the minimap tiles look).

| Floor 1 | Floor 2 |
|---|---|
| ![230 floor 1](230_1.jpg) | ![230 floor 2](230_2.jpg) |

### 289 Scholomance

- Floors: 4
- Switches: plain
- Problems: none seen

| Floor 1 | Floor 2 | Floor 3 | Floor 4 |
|---|---|---|---|
| ![289 floor 1](289_1.jpg) | ![289 floor 2](289_2.jpg) | ![289 floor 3](289_3.jpg) | ![289 floor 4](289_4.jpg) |

### 329 Stratholme

- Floors: 2
- Switches: plain
- Problems: Small loose terrain squares around single buildings.

| Floor 1 | Floor 2 |
|---|---|
| ![329 floor 1](329_1.jpg) | ![329 floor 2](329_2.jpg) |

### 309 Zul'Gurub

- Floors: 1
- Switches: plain
- Problems: Outdoor dungeon: terrain covers the whole region, grey mountains of the neighbouring area on the right.

| Floor 1 |
|---|
| ![309 floor 1](309_1.jpg) |

### 249 Onyxia's Lair

- Floors: 1
- Switches: plain
- Problems: none seen

| Floor 1 |
|---|
| ![249 floor 1](249_1.jpg) |

### 409 Molten Core

- Floors: 1
- Switches: plain
- Problems: none seen

| Floor 1 |
|---|
| ![409 floor 1](409_1.jpg) |

### 469 Blackwing Lair

- Floors: 4
- Switches: plain
- Problems: none seen

| Floor 1 | Floor 2 | Floor 3 | Floor 4 |
|---|---|---|---|
| ![469 floor 1](469_1.jpg) | ![469 floor 2](469_2.jpg) | ![469 floor 3](469_3.jpg) | ![469 floor 4](469_4.jpg) |

### 429 Dire Maul

- Floors: 7
- Switches: `NOADT=1` (floor 1: overview, fitted region)
- Problems: Floor 1: Blizzard has no region for its overview, so it's a new overview of all wings (player dot not possible, same as before). Capital Gardens is cut at the left edge (Blizzard's region).

| Floor 1 | Floor 2 | Floor 3 | Floor 4 | Floor 5 | Floor 6 | Floor 7 |
|---|---|---|---|---|---|---|
| ![429 floor 1](429_1.jpg) | ![429 floor 2](429_2.jpg) | ![429 floor 3](429_3.jpg) | ![429 floor 4](429_4.jpg) | ![429 floor 5](429_5.jpg) | ![429 floor 6](429_6.jpg) | ![429 floor 7](429_7.jpg) |

### 509 Ruins of Ahn'Qiraj

- Floors: 1
- Switches: plain
- Problems: Two grey squares in the bottom corners (missing terrain tiles).

| Floor 1 |
|---|
| ![509 floor 1](509_1.jpg) |

### 531 Temple of Ahn'Qiraj

- Floors: 3
- Switches: plain
- Problems: Floor 2 (Temple Gates): grey strip at the right edge (missing terrain tiles).

| Floor 1 | Floor 2 | Floor 3 |
|---|---|---|
| ![531 floor 1](531_1.jpg) | ![531 floor 2](531_2.jpg) | ![531 floor 3](531_3.jpg) |

### 2999 Ruins of Lordaeron

- Floors: 1
- Switches: `REGION=1184.4,-177.1,1924.1,932.4`, `--largest`
- Problems: none seen

| Floor 1 |
|---|
| ![2999 floor 1](2999_1.jpg) |

### 2998 Excavation Site: Wetlands

- Floors: 1
- Switches: `REGION=-4278.5,-2627.2,-3453.9,-1390.4`, `--largest`
- Problems: Boss pin converted from the old art to the new region (approximate, please check in-game).

| Floor 1 |
|---|
| ![2998 floor 1](2998_1.jpg) |

### 2970 The Drowned City

- Floors: 2
- Switches: floor 1 `ZMIN=-30`; floor 2 `WMO=7748971 NOADT=1`
- Problems: Floor 2 (Atal'Byzal) = the sunken WMO below sea level; please check it is really Atal'Byzal.

| Floor 1 | Floor 2 |
|---|---|
| ![2970 floor 1](2970_1.jpg) | ![2970 floor 2](2970_2.jpg) |

### 2974 Blackmaw Hold

- Floors: 2
- Switches: floor 1 `REGION=3062.1,2617.9,3972.3,3983.1 NOWMO=7212893`; floor 2 `WMO=7212893 NOADT=1`
- Problems: Floor 1: square terrain blocks, grey/white snow tiles at the top (terrain of the area).

| Floor 1 | Floor 2 |
|---|---|
| ![2974 floor 1](2974_1.jpg) | ![2974 floor 2](2974_2.jpg) |

### 3001 The Shaper's Terrace

- Floors: 1
- Switches: `REGION=-7008.6,-2645.6,-5260.8,-23.9`
- Problems: Some black holes in the terrain (missing water/terrain tiles).

| Floor 1 |
|---|
| ![3001 floor 1](3001_1.jpg) |

### 3039 Krol'dok Stronghold

- Floors: 1
- Switches: `REGION=-7894.1,-5261.4,-6543.1,-3234.9`, `--largest`
- Problems: none seen

| Floor 1 |
|---|
| ![3039 floor 1](3039_1.jpg) |

