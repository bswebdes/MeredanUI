"""Static instance list for World of Warcraft: Forever (status, levels, sources). Hand-maintained.
status: live | announced | datamined | not-in-forever"""

BLIZZ_DUNGEONS = "http://worldofwarcraft.blizzard.com/en-us/news/24301455"
BLIZZ_RAIDS = "http://worldofwarcraft.blizzard.com/en-us/news/24303009"
CC_OVERVIEW = "https://conquestcapped.com/guides/wow-forever/wow-forever-dungeons-overview/"
WT_DUNGEONS = "https://www.warcrafttavern.com/forever/guides/dungeons/"
ROADMAP = "https://www.icy-veins.com/wow-forever/news/warcraft-forever-roadmap-unveils-raid-unlocks-and-major-updates/"

# key, slug, kind, en, level, entrance zone, faction note, status, status note, sources, new?
INSTANCES = [
    (389, "ragefire_chasm", "dungeon", "Ragefire Chasm", "13-18", "Orgrimmar", "Horde city (Alliance can enter, no quests)", "live", "classic dungeon in Forever's group finder list", [CC_OVERVIEW, WT_DUNGEONS], False),
    (3065, "hall_of_thanes", "dungeon", "The Hall of Thanes", "13-18", "Ironforge (Old Ironforge)", "Alliance-leaning, Horde can enter", "live", "new Forever dungeon", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (2999, "ruins_of_lordaeron", "dungeon", "Ruins of Lordaeron", "15-20", "Tirisfal Glades (above Undercity)", "Horde-leaning, Alliance can enter", "live", "new Forever dungeon", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (43, "wailing_caverns", "dungeon", "Wailing Caverns", "17-24", "The Barrens", "both", "live", "classic dungeon; released in MeredanUI panel", [CC_OVERVIEW, WT_DUNGEONS], False),
    (36, "deadmines", "dungeon", "The Deadmines", "17-26", "Westfall", "both (quests Alliance)", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (33, "shadowfang_keep", "dungeon", "Shadowfang Keep", "22-30", "Silverpine Forest", "both (quests Horde)", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (48, "blackfathom_deeps", "dungeon", "Blackfathom Deeps", "24-32", "Ashenvale", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (34, "stockade", "dungeon", "The Stockade", "24-32", "Stormwind City", "Alliance city (Horde can enter, no quests)", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (2998, "excavation_site_wetlands", "dungeon", "Excavation Site: Wetlands", "24-29", "Wetlands (near Thelgen Rock)", "both", "live", "new Forever dungeon (Blizzard 24-29; guides/beta 26-31)", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (2959, "city_of_dalaran", "dungeon", "City of Dalaran", "28-33", "Alterac Mountains", "both (attunement quest per faction)", "live", "new Forever dungeon", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (90, "gnomeregan", "dungeon", "Gnomeregan", "29-38", "Dun Morogh", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (47, "razorfen_kraul", "dungeon", "Razorfen Kraul", "29-38", "The Barrens (south)", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (189, "scarlet_monastery", "dungeon", "Scarlet Monastery", "30-46", "Tirisfal Glades", "both", "live", "classic dungeon, 4 wings (GY 30-38, Lib 33-41, Arm 36-44, Cath 38-46)", [CC_OVERVIEW, WT_DUNGEONS], False),
    (2970, "drowned_city", "dungeon", "The Drowned City", "35-40", "Stranglethorn Vale coast (underwater, west of Grom'gol)", "both", "live", "new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (129, "razorfen_downs", "dungeon", "Razorfen Downs", "37-46", "The Barrens / Thousand Needles", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (3039, "kroldok_stronghold", "dungeon", "Krol'dok Stronghold", "40-45", "Riverglades", "both", "live", "new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (70, "uldaman", "dungeon", "Uldaman", "41-51", "Badlands", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (209, "zulfarrak", "dungeon", "Zul'Farrak", "44-54", "Tanaris", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (349, "maraudon", "dungeon", "Maraudon", "46-55", "Desolace", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (2994, "alcaz_prison", "dungeon", "Alcaz Prison", "48-53", "Dustwallow Marsh (Alcaz Island)", "both", "live", "new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (109, "sunken_temple", "dungeon", "Sunken Temple", "50-60", "Swamp of Sorrows", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (230, "blackrock_depths", "dungeon", "Blackrock Depths", "52-60", "Blackrock Mountain", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    (429, "dire_maul", "dungeon", "Dire Maul", "54-60", "Feralas", "both", "live", "classic dungeon, 3 wings (East 54-60, West/North 56-60)", [CC_OVERVIEW, WT_DUNGEONS], False),
    (229, "blackrock_spire", "dungeon", "Blackrock Spire", "55-60", "Blackrock Mountain", "both", "live", "classic dungeon (LBRS 55-60, UBRS 59-60; one map ID)", [CC_OVERVIEW, WT_DUNGEONS], False),
    (2974, "blackmaw_hold", "dungeon", "Blackmaw Hold", "55-60", "Azshara (north, Furbolg gate)", "both", "live", "new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (3001, "shapers_terrace", "dungeon", "Shaper's Terrace", "58-60", "Un'Goro Crater (northern hills)", "both", "live", "new Forever dungeon; guides report it open since launch (Nov 4), but Wowhead's dungeon journal and the readable client tables (Map, LFGDungeons) do not list it yet", [BLIZZ_DUNGEONS, CC_OVERVIEW], True),
    (329, "stratholme", "dungeon", "Stratholme", "58-60", "Eastern Plaguelands", "both", "live", "classic dungeon (Main Gate + Service Gate)", [CC_OVERVIEW, WT_DUNGEONS], False),
    (289, "scholomance", "dungeon", "Scholomance", "58-60", "Western Plaguelands", "both", "live", "classic dungeon", [CC_OVERVIEW, WT_DUNGEONS], False),
    # raids
    ("barrow_deeps", "barrow_deeps", "raid", "Barrow Deeps", "60", "Mount Hyjal (entrances Hyjal, Winterspring, Blackmaw Hold)", "both", "announced", "opens 2026-12-09 (10 players, 8 bosses)", [BLIZZ_RAIDS], True),
    ("hyjal_summit", "hyjal_summit", "raid", "Hyjal Summit", "60", "Mount Hyjal (summit, near Nordrassil)", "both", "announced", "opens 2026-12-09 (20 players, 13 bosses)", [BLIZZ_RAIDS], True),
    (249, "onyxias_lair", "raid", "Onyxia's Lair", "60", "Dustwallow Marsh", "both (Drakefire Amulet needed)", "announced", "opens 2026-12-09 (40 players)", [BLIZZ_RAIDS], False),
    (409, "molten_core", "raid", "Molten Core", "60", "Blackrock Mountain", "both", "not-announced", "in game data, no Forever date (roadmap)", [BLIZZ_RAIDS, ROADMAP], False),
    (309, "zulgurub", "raid", "Zul'Gurub", "60", "Stranglethorn Vale", "both", "not-announced", "in game data, no Forever date", [BLIZZ_RAIDS, ROADMAP], False),
    (469, "blackwing_lair", "raid", "Blackwing Lair", "60", "Blackrock Mountain", "both", "not-announced", "in game data, no Forever date", [BLIZZ_RAIDS, ROADMAP], False),
    (509, "ruins_of_ahnqiraj", "raid", "Ruins of Ahn'Qiraj", "60", "Silithus", "both", "not-announced", "in game data, no Forever date", [BLIZZ_RAIDS, ROADMAP], False),
    (531, "temple_of_ahnqiraj", "raid", "Temple of Ahn'Qiraj", "60", "Silithus", "both", "not-announced", "in game data, no Forever date", [BLIZZ_RAIDS, ROADMAP], False),
    (533, "naxxramas", "raid", "Naxxramas", "60", "Eastern Plaguelands", "both", "not-announced", "in game data, no Forever date", [BLIZZ_RAIDS, ROADMAP], False),
]

# Instance maps in Forever's game data that are not part of Forever (leftovers) or only datamined.
OTHER_MAPS = [
    (3109, "Manor Mistmantle", "Anwesen der Mistmantles", "datamined", "map in game data, possible future dungeon (Duskwood)", WT_DUNGEONS),
    (None, "Half-Pint Tavern", None, "datamined", "named by guides as datamined (Arathi Highlands); map ID not found", WT_DUNGEONS),
    (3002, "(unknown, encounters Deathulus / Crushfist Bloodbreaker)", None, "unknown", "encounters in game data only; map row encrypted/missing", None),
    (2720, "The Searing Basin", "Das Sengende Becken", "not-in-forever", "game-data leftover (test encounter Testwerk)", None),
    (2784, "Demon Fall Canyon", "Demonfall-Canyon", "not-in-forever", "Season of Discovery instance, game-data leftover", None),
    (2789, "The Tainted Scar", "Faulende Narbe", "not-in-forever", "Season of Discovery raid (Kazzak), leftover", None),
    (2791, "Storm Cliffs", "Sturmklippen", "not-in-forever", "Season of Discovery raid (Azuregos), leftover", None),
    (2804, "The Crystal Vale", "Kristalltal", "not-in-forever", "Season of Discovery raid (Thunderaan), leftover", None),
    (2832, "Nightmare Grove", "Alptraumhain", "not-in-forever", "Season of Discovery raid (Emerald dragons), leftover", None),
    (2856, "Scarlet Enclave", "Scharlachrote Enklave", "not-in-forever", "Season of Discovery raid, leftover", None),
    (2875, "Karazhan Crypts", "Karazhangruften", "not-in-forever", "Season of Discovery dungeon, leftover", None),
    (2921, "Naxxramas (Mograine event map)", "Naxxramas", "not-in-forever", "Season of Discovery event map, leftover", None),
    (13, "Test Dungeon", "Test Dungeon", "not-in-forever", "test map", None),
]
