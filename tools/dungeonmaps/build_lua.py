#!/usr/bin/env python3
"""Map/DungeonMapDataForever.lua for Forever's new instances (maps in Media/DungeonMaps): Santiago Reyes'
maps (tools/dungeonmaps/santiago.py, credit = true) where he drew one, own parchment maps otherwise.
Calibration per floor comes from the jobs.sh run: worldmap crop (X1, Z1 placement coords, scale sc) and
parchment2's fit (scale s, offset ox/oy, 768x512 texture space). The region uses Blizzard's
UiMapAssignment order (minX, minY, minZ, maxX, maxY, maxZ in world coords) so pins work like classic maps."""
import pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
O = 17066.666  # placement origin: world X = O - placement Z, world Y = O - placement X
# inst, floor, en, de, sc, X1, Z1, s, ox, oy
FLOORS = [
    (2959, 1, "City of Dalaran", "Stadt Dalaran", 0.6, 16273, 16440, 0.546, 217.5, 45.8),
    (2959, 2, "Sewers", "Kanalisation", 0.6, 16273, 16440, 0.546, 217.5, 45.8),
    # classic instances: game-data minimap map on a themed background
    (43, 1, None, None, 1.0, -545, -195, 0.615, 100.6, 74.6),
]
# WMO-only maps place the WMO at 0,0,0: world = -placement there, no 17066 offset
ORIGIN = {43: 0.0}
# Santiago Reyes' maps (kept where game data can't split the floors: Dalaran has no sewer WMO with minimap
# tiles); their regions are the old calibration, only used by
# position-based pins, which these instances don't have (pins are placed relative to the art)
CREDIT = {2959}
# game-data maps rendered straight into a region (buildmap.py + compose.py): Blizzard's floor region for
# classic instances (pins stay valid), the fitted region buildmap.py prints for new instances
DIRECT = [
    (389, 1, None, None, (-452.95, -285.99, -10000.0, 39.62, 452.87, 1000000.0)),   # SKIP=5,6,7,8,10, --largest
    (3065, 1, None, None, (-142.0, -600.4, -100000.0, 646.1, 581.8, 100000.0)),     # NOADT=1
    # new Forever instances from game data, half size; region = REGION / fitted region printed by buildmap.py
    (2999, 1, None, None, (1184.4, -177.1, -100000.0, 1924.1, 932.4, 100000.0)),   # REGION=1184.4,-177.1,1924.1,932.4, --largest
    (2998, 1, None, None, (-4278.5, -2627.2, -100000.0, -3453.9, -1390.4, 100000.0)),   # REGION=-4278.5,-2627.2,-3453.9,-1390.4, --largest
    (2970, 1, "The Drowned City", "Die versunkene Stadt", (-13577.7, 2325.6, -100000.0, -13016.1, 3167.9, 100000.0)),   # ZMIN=-30 FLOOR=1
    (2970, 2, "Atal'Byzal", "Atal'Byzal", (-13676.6, 2427.3, -100000.0, -13392.7, 2853.1, 100000.0)),   # WMO=7748971 NOADT=1 FLOOR=2
    (2974, 1, None, None, (3062.1, 2617.9, -100000.0, 3972.3, 3983.1, 100000.0)),   # REGION=3062.1,2617.9,3972.3,3983.1 NOWMO=7212893 FLOOR=1
    (2974, 2, "Caverns", "Höhlen", (3310.7, 2675.3, -100000.0, 3774.1, 3370.3, 100000.0)),   # WMO=7212893 NOADT=1 FLOOR=2 (cave WMO)
    (3001, 1, None, None, (-7008.6, -2645.6, -100000.0, -5260.8, -23.9, 100000.0)),   # REGION=-7008.6,-2645.6,-5260.8,-23.9
    (2994, 1, None, None, (-8936.8, 2731.6, -100000.0, -8709.8, 3072.2, 100000.0)),   # NOADT=1, fitted region; one floor (no clean height split)
    (3039, 1, None, None, (-7894.1, -5261.4, -100000.0, -6543.1, -3234.9, 100000.0)),   # REGION=-7894.1,-5261.4,-6543.1,-3234.9, --largest
    # classic instances, half size (compose.py --half), Blizzard's floor regions
    (36, 1, 'The Deadmines', 'Die Todesminen', (-337.51, -796.62, -10000.0, 35.33, -237.36, 1000000.0)),   # plain
    (36, 2, 'Ironclad Cove', 'Eiserne Bucht', (-267.51, -1016.62, -10000.0, 65.33, -517.36, 1000000.0)),
    (33, 1, 'The Courtyard', 'Der Hof', (-319.88, 2003.77, -10000.0, -84.93, 2356.2, 1000000.0)),   # plain
    (33, 2, 'Dining Hall', 'Speisesaal', (-303.21, 2147.56, -10000.0, -161.6, 2359.98, 1000000.0)),
    (33, 3, 'The Vacant Den', 'Die Verwaiste Höhle', (-193.22, 2103.77, -10000.0, -91.6, 2256.2, 1000000.0)),
    (33, 4, 'Lower Observatory', 'Tieferes Observatorium', (-193.21, 2103.77, 127.0, -91.59, 2256.2, 1000000.0)),
    (33, 5, 'Upper Observatory', 'Oberes Observatorium', (-193.21, 2103.77, -10000.0, -91.59, 2256.2, 1000000.0)),
    (33, 6, "Lord Godfrey's Chamber", 'Lord Godfreys Kammer', (-182.55, 2080.77, -10000.0, -50.26, 2279.2, 1000000.0)),
    (33, 7, 'The Wall Walk', 'Der Wehrgang', (-278.22, 2023.77, -10000.0, -96.6, 2296.2, 1000000.0)),
    (34, 1, None, None, (-31.47, -188.33, -10000.0, 220.63, 189.82, 1000000.0)),   # plain
    (48, 1, "The Pool of Ask'Ar", "Der Teich von Ask'Ar", (-677.15, -381.3, -10000.0, -87.67, 502.92, 1000000.0)),   # plain
    (48, 2, 'Moonshrine Sanctum', 'Mondschreinsanktum', (-927.15, -581.3, -10000.0, -337.67, 302.92, 1000000.0)),
    (48, 3, 'The Forgotten Pool', 'Der Vergessene Teich', (-877.15, -281.3, -10000.0, -687.67, 2.93, 1000000.0)),
    (90, 1, 'The Hall of Gears', 'Die Halle der Zahnräder', (-694.0, -277.77, -10000.0, -180.89, 491.9, 1000000.0)),   # plain
    (90, 2, 'The Dormitory', 'Der Schlafsaal', (-714.0, -77.77, -10000.0, -200.89, 691.9, 1000000.0)),
    (90, 3, 'Launch Bay', 'Startrampe', (-967.33, -127.77, -10000.0, -387.55, 741.9, 1000000.0)),
    (90, 4, "Tinkers' Court", 'Tüftlerhof', (-937.33, 73.0, -10000.0, -357.55, 942.67, 1000000.0)),
    (47, 1, None, None, (1858.68, 1322.47, -10000.0, 2349.64, 2058.92, 1000000.0)),   # NOADT=1 SKIP=19 (exterior group = thorn canopy)
    (189, 1, 'Graveyard', 'Friedhof', (1616.86, 947.99, -10000.0, 2030.18, 1567.97, 1000000.0)),   # NOADT=1
    (189, 2, 'Library', 'Bibliothek', (93.91, -482.46, -10000.0, 307.37, -162.27, 1000000.0)),
    (189, 3, 'Armory', 'Arsenal', (1600.64, -562.42, -10000.0, 2009.1, 50.27, 1000000.0)),
    (189, 4, 'Cathedral', 'Kathedrale', (812.42, 1040.69, -10000.0, 1281.29, 1743.99, 1000000.0)),
    (129, 1, None, None, (2209.85, 570.89, -10000.0, 2682.55, 1279.94, 1000000.0)),   # NOADT=1 SKIP=10 (exterior group = thorn canopy)
    (70, 1, 'Hall of the Keepers', 'Halle der Bewahrer', (-391.47, -248.55, -10000.0, 204.31, 645.12, 1000000.0)),   # plain
    (70, 2, "Khaz'Goroth's Seat", "Khaz'goroths Sitz", (-57.77, 52.55, -10000.0, 270.61, 545.12, 1000000.0)),
    (209, 1, None, None, (1129.17, 241.67, -1000000.0, 2052.08, 1625.0, 1000000.0)),   # plain; compose --soft
    (349, 1, 'Caverns of Maraudon', 'Höhlen von Maraudon', (550.0, -827.5, -10000.0, 1200.0, 147.5, 1000000.0)),   # plain
    (349, 2, "Zaetar's Grave", 'Zaetars Grab', (-208.33, -1158.75, -10000.0, 883.33, 478.75, 1000000.0)),
    (109, 1, None, None, (-718.52, -252.27, -10000.0, -255.17, 442.76, 1000000.0)),   # plain
    (230, 1, 'Detention Block', 'Gefängnisblock', (248.64, -884.72, -10000.0, 1186.68, 522.34, 1000000.0)),   # plain
    (230, 2, 'Shadowforge City', 'Schattenschmiede', (495.3, -934.72, -10000.0, 1500.01, 572.34, 1000000.0)),
    (289, 1, 'The Reliquary', 'Das Reliquiarium', (104.33, -68.64, -10000.0, 317.7, 251.41, 1000000.0)),   # plain
    (289, 2, 'Chamber of Summoning', 'Kammer der Beschwörung', (44.33, -128.64, -10000.0, 337.7, 311.41, 1000000.0)),
    (289, 3, 'The Upper Study', 'Oberes Arbeitszimmer', (34.32, -113.64, -10000.0, 307.71, 296.44, 1000000.0)),
    (289, 4, "Headmaster's Study", 'Arbeitszimmer des Direktors', (-66.32, -174.12, -10000.0, 287.71, 356.92, 1000000.0)),
    (329, 1, "Crusader's Square", 'Kreuzzüglerplatz', (3338.97, -3617.68, -10000.0, 3809.45, -2911.96, 1000000.0)),   # plain
    (329, 2, 'The Gauntlet', 'Der Spießrutenlauf', (3498.97, -3967.68, -10000.0, 4169.45, -2961.96, 1000000.0)),
    (309, 1, None, None, (-12560.42, -2570.83, -1000000.0, -11308.33, -693.75, 1000000.0)),   # plain
    (249, 1, None, None, (-223.83, -371.73, -10000.0, 98.25, 111.38, 1000000.0)),   # plain
    (409, 1, None, None, (459.86, -1395.56, -10000.0, 1303.06, -130.76, 1000000.0)),   # plain
    (469, 1, 'Dragonmaw Garrison', 'Garnison des Drachenmals', (-7727.07, -1344.05, -10000.0, -7394.12, -844.62, 1000000.0)),   # plain
    (469, 2, 'Halls of Strife', 'Hallen des Zwists', (-7777.07, -1379.05, 420.0, -7344.12, -729.62, 1000000.0)),
    (469, 3, 'Crimson Laboratories', 'Blutrote Labore', (-7757.07, -1369.05, 445.0, -7324.12, -719.62, 1000000.0)),
    (469, 4, "Nefarian's Lair", 'Nefarians Unterschlupf', (-7637.07, -1419.05, -10000.0, -7204.12, -769.62, 1000000.0)),
    (429, 1, 'Dire Maul', 'Düsterbruch', (0.0, 0.0, -1000000.0, 0.0, 0.0, 1000000.0)),   # NOADT=1; floor 1: overview, fitted region (Blizzard has none)
    (429, 2, 'Gordok Commons', 'Gordokhallen', (200.0, -387.5, -10000.0, 1050.0, 887.5, 1000000.0)),
    (429, 3, 'Capital Gardens', 'Hauptstadtgärten', (-150.0, 125.0, -10000.0, 200.0, 650.0, 1000000.0)),
    (429, 4, 'Court of the Highborne', 'Hof der Hochgeborenen', (-150.0, 231.25, -10000.0, 175.0, 718.75, 1000000.0)),
    (429, 5, "Prison of Immol'Thar", "Gefängnis von Immol'thar", (-250.0, 325.0, -10000.0, 250.0, 1075.0, 1000000.0)),
    (429, 6, 'Warpwood Quarter', 'Wucherborkenviertel', (-281.67, -900.0, -10000.0, 251.67, -100.0, 1000000.0)),
    (429, 7, 'The Shrine of Eldretharr', 'Schrein von Eldretharr', (-200.0, -862.5, -10000.0, 450.0, 112.5, 1000000.0)),
    (509, 1, None, None, (-9908.33, 522.92, -1000000.0, -8233.33, 3035.42, 1000000.0)),   # plain
    (531, 1, 'The Hive Undergrounds', 'Untergrund des Schwarmbaus', (-9510.98, 138.08, -10000.0, -7659.29, 2915.62, 1000000.0)),   # plain
    (531, 2, 'The Temple Gates', 'Die Tempeltore', (-8703.5, 1538.07, -10000.0, -8051.8, 2515.63, 1000000.0)),
    (531, 3, "Vault of C'Thun", "Höhle von C'Thun", (-8720.17, 1738.07, -10000.0, -8335.13, 2315.63, 1000000.0)),
    # Blackrock Spire: Forever's rebuilt WMO, floors via the classic group IDs (same group order)
    (229, 1, "Tazz'Alor", "Tazz'Alor", (-286.83, -876.25, -10000.0, 304.4, 10.59, 1000000.0)),   # ASSIGNEDONLY=1 CLASSICGID=7952332:108373
    (229, 2, 'Skitterweb Tunnels', 'Listspinnertunnel', (-286.83, -876.25, 10.0, 304.4, 10.59, 1000000.0)),
    (229, 3, 'Hordemar City', 'Hordemar', (-286.83, -876.25, -10000.0, 304.4, 10.59, 1000000.0)),
    (229, 4, 'Hall of Blackhand', 'Schwarzfausthalle', (-286.83, -876.25, -10000.0, 304.4, 10.59, 1000000.0)),
    (229, 5, "Halycon's Lair", 'Halycons Hort', (-286.83, -876.25, -10000.0, 304.4, 10.59, 1000000.0)),
    (229, 6, 'Chamber of Battle', 'Kammer der Schlachten', (-286.83, -876.25, -10000.0, 304.4, 10.59, 1000000.0)),
]
def lua(v): return "nil" if v is None else '"' + v + '"'
out = ["-- GENERATED by tools/dungeonmaps/build_lua.py - do not edit by hand.",
       "-- Forever's new instances: Santiago Reyes' maps (credit = true, used with his permission), own parchment maps otherwise; classic instances in the mUI map style override Blizzard's art.",
       "local _, ns = ...", "", "ns.DUNGEON_MAPS = ns.DUNGEON_MAPS or {}"]
by = {}
for inst, fl, en, de, sc, X1, Z1, s, ox, oy in FLOORS:
    k = sc * s
    px0, px1 = X1 + (0 - ox) / k, X1 + (768 - ox) / k
    pz0, pz1 = Z1 + (0 - oy) / k, Z1 + (512 - oy) / k
    o = ORIGIN.get(inst, O)
    region = (o - pz1, o - px1, -100000, o - pz0, o - px0, 100000)
    by.setdefault(inst, []).append(
        '{ en = %s, de = %s, file = "Interface\\\\AddOns\\\\MeredanUI\\\\Media\\\\DungeonMaps\\\\%d_%d", '
        'texCoord = { 0, 0.75, 0, 1 }, region = { %s }%s }' % (lua(en), lua(de), inst, fl, ", ".join(f"{v:.1f}" for v in region),
                                                             ", credit = true" if inst in CREDIT else ""))
for inst, fl, en, de, region in DIRECT:
    by.setdefault(inst, []).append(
        '{ en = %s, de = %s, file = "Interface\\\\AddOns\\\\MeredanUI\\\\Media\\\\DungeonMaps\\\\%d_%d", '
        'texCoord = { 0, 0.75, 0, 1 }, region = { %s } }' % (lua(en), lua(de), inst, fl, ", ".join(f"{v:.2f}" for v in region)))
for inst, floors in by.items():
    out.append("ns.DUNGEON_MAPS[%d] = {\n    %s,\n}" % (inst, ",\n    ".join(floors)))
(ROOT / "Map" / "DungeonMapDataForever.lua").write_text("\n".join(out) + "\n", encoding="utf-8")
print("instances:", len(by))
