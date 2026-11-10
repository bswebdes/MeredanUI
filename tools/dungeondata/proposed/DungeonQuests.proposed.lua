-- PROPOSAL (not loaded by the addon). Same format as Quests/DungeonQuests.lua. New quests have no
-- world position for the giver (map/x/y missing: no map pin until filled in).
local _, ns = ...

ns.DUNGEON_QUESTS = {
    [389] = { -- Ragefire Chasm
        { id = 5722, level = 16, min = 9, races = 178, classes = 0, title = "Searching for the Lost Satchel", giver = "Rahauro", map = 1, x = -1055.4, y = -215.4 },
        { id = 5723, level = 15, min = 9, races = 178, classes = 0, title = "Testing an Enemy's Strength", giver = "Rahauro", map = 1, x = -1055.4, y = -215.4 },
        { id = 5724, level = 16, min = 9, races = 178, classes = 0, title = "Returning the Lost Satchel", giver = "Maur Grimtotem", map = 389, x = -148.1, y = 23.6 },
        { id = 5725, level = 16, min = 9, races = 178, classes = 0, title = "The Power to Destroy...", giver = "Varimathras", map = 0, x = 1287.8, y = 333.5 },
        { id = 5728, level = 16, min = 9, races = 178, classes = 0, title = "Hidden Enemies", giver = "Thrall", map = 1, x = 1920.1, y = -4125.7 },
        { id = 5761, level = 16, min = 9, races = 178, classes = 0, title = "Slaying the Beast", giver = "Neeru Fireblade", map = 1, x = 1800.7, y = -4374.5 },
    },
    [3065] = { -- The Hall of Thanes
        { id = 96391, level = 0, min = 0, races = 77, classes = 0, title = "Underground Map", giver = "Earthseer Farsen" }, -- NEW, giver zone: Dun Morogh
        { id = 96394, level = 15, min = 10, races = 77, classes = 0, title = "The Restless Dead", giver = "Afadra Dunwall" }, -- NEW, giver zone: Ironforge
        { id = 96395, level = 15, min = 10, races = 0, classes = 0, title = "An Ancient Grudge", giver = "Ghostly Attendant" }, -- NEW, giver zone: The Hall of Thanes (inside)
        { id = 96403, level = 15, min = 10, races = 0, classes = 0, title = "Important Heirlooms", giver = "Thom Filch" }, -- NEW, giver zone: Old Ironforge (bridge before portal)
        { id = 96393, level = 16, min = 9, races = 77, classes = 0, title = "Old Ironforge Incursion", giver = "Earthseer Farsen" }, -- NEW, giver zone: Dun Morogh
        { id = 98423, level = 16, min = 9, races = 77, classes = 0, title = "The Treaty of Understanding", item = 281030 }, -- NEW, giver zone: The Hall of Thanes (last room)
    },
    [2999] = { -- Ruins of Lordaeron
        { id = 95161, level = 0, min = 0, races = 77, classes = 0, title = "Remember That I Love You (step 2)", giver = "Avette Fellwood" }, -- NEW, giver zone: Duskwood
        { id = 99156, level = 0, min = 0, races = 178, classes = 0, title = "Rear Guard Patrol (Riptear)", giver = "?" }, -- NEW, giver zone: Tirisfal Glades
        { id = 356, level = 11, min = 0, races = 178, classes = 0, title = "Rear Guard Patrol", giver = "Deathguard Linnea" }, -- NEW, giver zone: Tirisfal Glades
        { id = 95250, level = 21, min = 15, races = 77, classes = 0, title = "Abominable Creatures", giver = "Captain Truman" }, -- NEW, giver zone: Ruins of Lordaeron (inside entrance)
        { id = 97288, level = 21, min = 15, races = 178, classes = 0, title = "Unending Torment", item = 280438 }, -- NEW, giver zone: Ruins of Lordaeron (Abominable Head from The Baron)
        { id = 92401, level = 22, min = 15, races = 178, classes = 0, title = "A Frightened Request", giver = "Tabitha Heartweaver" }, -- NEW, giver zone: Silverpine Forest (Sepulcher)
        { id = 92415, level = 22, min = 15, races = 77, classes = 0, title = "Remember That I Love You", item = 251522 }, -- NEW, giver zone: Ruins of Lordaeron (graveyard); turn in Orphan Matron Nightingale npc=14450, Stormwind
        { id = 92421, level = 22, min = 15, races = 178, classes = 0, title = "Light's Justice", giver = "Morbin Lightbane" }, -- NEW, giver zone: Undercity (Royal Quarter)
        { id = 92422, level = 22, min = 15, races = 178, classes = 0, title = "The Wrath of Rath'mael", giver = "Deathguard Kristof" }, -- NEW, giver zone: Tirisfal Glades (SE of Brill)
        { id = 95189, level = 22, min = 15, races = 77, classes = 0, title = "Crest of Lordaeron", item = 268579 }, -- NEW, giver zone: Ruins of Lordaeron (inside); turn in Lady Dena Kennedy npc=15991, Stormwind
        { id = 95195, level = 22, min = 15, races = 77, classes = 0, title = "Bloodied Insignia", item = 268540 }, -- NEW, giver zone: Ruins of Lordaeron (drop inside); turn in General Marcus Jonathan npc=466, Stormwind
        { id = 95204, level = 22, min = 15, races = 178, classes = 0, title = "Crest of Lordaeron", item = 275521 }, -- NEW, giver zone: Ruins of Lordaeron (inside); turn in Oran Snakewrithe npc=7825, Undercity
        { id = 95216, level = 22, min = 15, races = 178, classes = 0, title = "The New Plague", giver = "Theodore Griffs" }, -- NEW, giver zone: Undercity (Apothecarium)
    },
    [43] = { -- Wailing Caverns
        { id = 3369, level = 0, min = 0, races = 0, classes = 0, title = "In Nightmares", giver = "Falla Sagewind" }, -- NEW, giver zone: hut above dungeon
        { id = 870, level = 13, min = 0, races = 178, classes = 0, title = "The Forgotten Pools", giver = "Tonga Runetotem" }, -- NEW, giver zone: The Barrens
        { id = 877, level = 16, min = 0, races = 178, classes = 0, title = "The Stagnant Oasis", giver = "Tonga Runetotem" }, -- NEW, giver zone: The Barrens
        { id = 880, level = 16, min = 0, races = 178, classes = 0, title = "Altered Beings", giver = "Tonga Runetotem" }, -- NEW, giver zone: The Barrens
        { id = 1489, level = 16, min = 12, races = 178, classes = 0, title = "Hamuul Runetotem", giver = "Tonga Runetotem", map = 1, x = -545.0, y = -2672.8 },
        { id = 1490, level = 16, min = 12, races = 178, classes = 0, title = "Nara Wildmane", giver = "Arch Druid Hamuul Runetotem", map = 1, x = -1048.7, y = -304.0 },
        { id = 1486, level = 17, min = 13, races = 255, classes = 0, title = "Deviate Hides", giver = "Nalpak", map = 1, x = -796.8, y = -2037.1 },
        { id = 865, level = 18, min = 0, races = 0, classes = 0, title = "Raptor Horns", giver = "Mebok Mizzyrix" }, -- NEW, giver zone: Ratchet
        { id = 959, level = 18, min = 14, races = 255, classes = 0, title = "Trouble at the Docks", giver = "Crane Operator Bigglefuzz", map = 1, x = -928.3, y = -3769.8 },
        { id = 962, level = 18, min = 14, races = 178, classes = 0, title = "Serpentbloom", giver = "Apothecary Zamah", map = 1, x = -995.4, y = 278.6 },
        { id = 1491, level = 18, min = 13, races = 255, classes = 0, title = "Smart Drinks", giver = "Mebok Mizzyrix", map = 1, x = -929.0, y = -3697.2 },
        { id = 1487, level = 21, min = 15, races = 255, classes = 0, title = "Deviate Eradication", giver = "Ebru", map = 1, x = -802.2, y = -2039.2 },
        { id = 914, level = 22, min = 11, races = 178, classes = 0, title = "Leaders of the Fang", giver = "Nara Wildmane", map = 1, x = -1070.0, y = -272.9 },
        { id = 6981, level = 26, min = 15, races = 255, classes = 0, title = "The Glowing Shard", item = 10441 },
    },
    [36] = { -- The Deadmines
        { id = 1654, level = 0, min = 20, races = 77, classes = 0, title = "The Test of Righteousness", giver = "Jordan Stilwell" }, -- NEW, giver zone: Dun Morogh (Ironforge entrance)
        { id = 214, level = 17, min = 14, races = 77, classes = 0, title = "Red Silk Bandanas", giver = "Scout Riell" }, -- NEW, giver zone: Westfall
        { id = 168, level = 18, min = 14, races = 77, classes = 0, title = "Collecting Memories", giver = "Wilder Thistlenettle" }, -- NEW, giver zone: Stormwind
        { id = 92753, level = 18, min = 9, races = 77, classes = 0, title = "Destruction in Deadmines", giver = "Alba Fairmoon" }, -- NEW, giver zone: Westfall (near Sentinel Hill)
        { id = 167, level = 20, min = 15, races = 77, classes = 0, title = "Oh Brother...", giver = "Wilder Thistlenettle" }, -- NEW, giver zone: Stormwind
        { id = 2040, level = 20, min = 15, races = 77, classes = 0, title = "Underground Assault", giver = "Shoni the Shilent" }, -- NEW, giver zone: Stormwind
        { id = 166, level = 22, min = 14, races = 77, classes = 0, title = "The Defias Brotherhood", giver = "Gryan Stoutmantle" }, -- NEW, giver zone: Westfall
    },
    [33] = { -- Shadowfang Keep
        { id = 1654, level = 0, min = 0, races = 77, classes = 0, title = "The Test of Righteousness", giver = "Jordan Stilwell" }, -- NEW, giver zone: Dun Morogh
        { id = 1098, level = 25, min = 18, races = 178, classes = 0, title = "Deathstalkers in Shadowfang", giver = "High Executor Hadrec", map = 0, x = 522.4, y = 1626.2 },
        { id = 1740, level = 25, min = 0, races = 0, classes = 0, title = "The Orb of Soran'ruk", giver = "Doan Karhan" }, -- NEW, giver zone: The Barrens
        { id = 1013, level = 26, min = 16, races = 178, classes = 0, title = "The Book of Ur", giver = "Keeper Bel'dugur", map = 0, x = 1529.4, y = 357.6 },
        { id = 95140, level = 26, min = 0, races = 178, classes = 0, title = "Old Fire-Eye", giver = "Lumina Windsinger" }, -- NEW, giver zone: ?
        { id = 1014, level = 27, min = 18, races = 178, classes = 0, title = "Arugal Must Die", giver = "Dalar Dawnweaver", map = 0, x = 552.1, y = 1593.6 },
    },
    [48] = { -- Blackfathom Deeps
        { id = 1654, level = 0, min = 0, races = 77, classes = 0, title = "The Test of Righteousness (chain 1649,1650,1651,1652,1653,1654,1806)", giver = "Duthorian Rall / Daphne Stilwell / Jordan Stilwell" }, -- NEW, giver zone: Stormwind / Westfall
        { id = 95042, level = 0, min = 0, races = 178, classes = 0, title = "Seeking the Kor Gem", giver = "Ulric Frostveil" }, -- NEW, giver zone: Ashenvale (Zoram'gar Outpost)
        { id = 6562, level = 22, min = 17, races = 178, classes = 0, title = "Trouble in the Deeps", giver = "Tsunaman", map = 1, x = 824.6, y = 933.3 },
        { id = 6563, level = 22, min = 17, races = 178, classes = 0, title = "The Essence of Aku'Mai", giver = "Je'neu Sancrea", map = 1, x = 3355.1, y = 1033.1 },
        { id = 6564, level = 22, min = 17, races = 178, classes = 0, title = "Allegiance to the Old Gods", item = 16790 },
        { id = 971, level = 23, min = 10, races = 77, classes = 0, title = "Knowledge in the Deeps", giver = "Gerrig Bonegrip", map = 0, x = -4598.9, y = -1115.5 },
        { id = 1198, level = 24, min = 18, races = 77, classes = 0, title = "In Search of Thaelrid", giver = "Dawnwatcher Shaedlass", map = 1, x = 10061.7, y = 2352.5 },
        { id = 1275, level = 24, min = 18, races = 77, classes = 0, title = "Researching the Corruption", giver = "Gershala Nightwhisper", map = 1, x = 6454.0, y = 431.3 },
        { id = 1740, level = 24, min = 0, races = 0, classes = 0, title = "The Orb of Soran'ruk", giver = "Doan Karhan" }, -- NEW, giver zone: The Barrens
        { id = 3765, level = 24, min = 0, races = 77, classes = 0, title = "The Corruption Abroad", giver = "Argos Nightwhisper" }, -- NEW, giver zone: Stormwind
        { id = 1199, level = 25, min = 20, races = 77, classes = 0, title = "Twilight Falls", giver = "Argent Guard Manados", map = 1, x = 10069.0, y = 2353.8 },
        { id = 6565, level = 26, min = 17, races = 178, classes = 0, title = "Allegiance to the Old Gods", giver = "Je'neu Sancrea", map = 1, x = 3355.1, y = 1033.1 },
        { id = 95140, level = 26, min = 0, races = 178, classes = 0, title = "Old Fire-Eye (chain 95034,95036,95111,95125,95126,95140)", giver = "Lumina Windsinger" }, -- NEW, giver zone: ?
        { id = 1200, level = 27, min = 18, races = 77, classes = 0, title = "Blackfathom Villainy", giver = "Argent Guard Thaelrid", map = 48, x = -531.6, y = 319.0 },
        { id = 6561, level = 27, min = 18, races = 178, classes = 0, title = "Blackfathom Villainy", giver = "Argent Guard Thaelrid", map = 48, x = -531.6, y = 319.0 },
        { id = 6921, level = 27, min = 21, races = 178, classes = 0, title = "Amongst the Ruins", giver = "Je'neu Sancrea", map = 1, x = 3355.1, y = 1033.1 },
        { id = 6922, level = 30, min = 21, races = 178, classes = 0, title = "Baron Aquanis", item = 16782 }, -- NEW, giver zone: Blackfathom Deeps (drop from Baron Aquanis)
    },
    [34] = { -- The Stockade
        { id = 373, level = 22, min = 0, races = 77, classes = 0, title = "The Unsent Letter", item = 2874 }, -- NEW, giver zone: The Deadmines (drop from Edwin VanCleef 639)
        { id = 389, level = 22, min = 0, races = 77, classes = 0, title = "Bazil Thredd", giver = "Baros Alexston" }, -- NEW, giver zone: Stormwind City (Cathedral Square)
        { id = 386, level = 25, min = 22, races = 77, classes = 0, title = "What Comes Around...", giver = "Guard Berton", map = 0, x = -9249.4, y = -2140.8 },
        { id = 377, level = 26, min = 22, races = 77, classes = 0, title = "Crime and Punishment", giver = "Councilman Millstipe", map = 0, x = -10576.9, y = -1108.5 },
        { id = 387, level = 26, min = 22, races = 77, classes = 0, title = "Quell The Uprising", giver = "Warden Thelwater", map = 0, x = -8799.6, y = 828.4 },
        { id = 388, level = 26, min = 22, races = 77, classes = 0, title = "The Color of Blood", giver = "Nikova Raskol", map = 0, x = -8733.1, y = 394.3 },
        { id = 378, level = 27, min = 22, races = 77, classes = 0, title = "The Fury Runs Deep", giver = "Motley Garmason", map = 0, x = -2650.4, y = -2443.5 },
        { id = 391, level = 29, min = 16, races = 77, classes = 0, title = "The Stockade Riots", giver = "Warden Thelwater", map = 0, x = -8799.6, y = 828.4 },
        { id = 303, level = 30, min = 0, races = 77, classes = 0, title = "The Dark Iron War", giver = "Motley Garmason" }, -- NEW, giver zone: Wetlands
    },
    [2998] = { -- Excavation Site: Wetlands
        { id = 276, level = 21, min = 0, races = 77, classes = 0, title = "Tramping Paws", giver = "Rethiel the Greenwarden" }, -- NEW, giver zone: Wetlands
        { id = 463, level = 21, min = 0, races = 77, classes = 0, title = "The Greenwarden", giver = "First Mate Fitzsimmons" }, -- NEW, giver zone: Wetlands (Menethil Harbor)
        { id = 484, level = 22, min = 0, races = 77, classes = 0, title = "Young Crocolisk Skins", giver = "James Halloran" }, -- NEW, giver zone: Wetlands (Menethil Harbor)
        { id = 277, level = 23, min = 0, races = 77, classes = 0, title = "Fire Taboo", giver = "Rethiel the Greenwarden" }, -- NEW, giver zone: Wetlands
        { id = 95647, level = 24, min = 24, races = 77, classes = 0, title = "Lost in the Thicket Things", giver = "Caitlin Grassman" }, -- NEW, giver zone: Wetlands (Menethil Harbor)
        { id = 95663, level = 24, min = 24, races = 178, classes = 0, title = "Dragonmaw Rumors", giver = "Zaruk" }, -- NEW, giver zone: Arathi Highlands (Hammerfall)
        { id = 95664, level = 24, min = 24, races = 178, classes = 0, title = "Elder Knowledge", item = 270866 }, -- NEW, giver zone: Excavation Site: Wetlands (Relic Guardian drop)
        { id = 95697, level = 24, min = 24, races = 178, classes = 0, title = "Changing Tastes", giver = "Borstan" }, -- NEW, giver zone: Orgrimmar
        { id = 95737, level = 24, min = 24, races = 77, classes = 0, title = "Seeking Caitlin", giver = "Llana" }, -- NEW, giver zone: Ashenvale
        { id = 95772, level = 24, min = 24, races = 77, classes = 0, title = "Songblade Search", giver = "Dorin Songblade" }, -- NEW, giver zone: Redridge Mountains (Lakeshire)
        { id = 95795, level = 24, min = 24, races = 77, classes = 0, title = "Fallen in the Fen", giver = "Daewyn Songblade's body" }, -- NEW, giver zone: Excavation Site: Wetlands (inside)
        { id = 95810, level = 24, min = 24, races = 77, classes = 0, title = "Lost Relic Carry", item = 270865 }, -- NEW, giver zone: Excavation Site: Wetlands (Relic Guardian drop)
        { id = 98823, level = 24, min = 24, races = 178, classes = 0, title = "Earthen Echo", giver = "Bashana Runetotem" }, -- NEW, giver zone: Thunder Bluff
        { id = 98824, level = 24, min = 24, races = 77, classes = 0, title = "Prehistoric Prism", giver = "Prospector Whelgar" }, -- NEW, giver zone: Wetlands (Whelgar's Excavation)
        { id = 275, level = 26, min = 0, races = 77, classes = 0, title = "Blisters on the Land", giver = "Rethiel the Greenwarden" }, -- NEW, giver zone: Wetlands
        { id = 98815, level = 28, min = 24, races = 77, classes = 0, title = "Highland Hides", giver = "James Halloran" }, -- NEW, giver zone: Wetlands (Menethil Harbor)
        { id = 95646, level = 31, min = 24, races = 77, classes = 0, title = "Horrors in the Highland", giver = "Rethiel the Greenwarden" }, -- NEW, giver zone: Wetlands
        { id = 95682, level = 31, min = 24, races = 178, classes = 0, title = "Open the Maw", giver = "Deathstalker Agent" }, -- NEW, giver zone: Excavation Site: Wetlands (entrance)
        { id = 95809, level = 31, min = 24, races = 77, classes = 0, title = "Heartwoven", giver = "Ardin Grassman" }, -- NEW, giver zone: Excavation Site: Wetlands (inside)
    },
    [2959] = { -- City of Dalaran
        { id = 92432, level = 0, min = 0, races = 77, classes = 0, title = "An Alarming Request", giver = "Emissary Jacques" }, -- NEW, giver zone: Hillsbrad Foothills (Southshore town hall)
        { id = 92434, level = 0, min = 0, races = 178, classes = 0, title = "Blood in the Streets", giver = "?" }, -- NEW, giver zone: ?
        { id = 93680, level = 0, min = 0, races = 178, classes = 0, title = "Key to the City", giver = "Magus Wordeen Voidglare" }, -- NEW, giver zone: Hillsbrad Foothills
        { id = 92456, level = 33, min = 24, races = 77, classes = 0, title = "A Green Sample", giver = "Shylamiir" }, -- NEW, giver zone: Stormwind City (The Park)
        { id = 92457, level = 33, min = 24, races = 77, classes = 0, title = "Starving Arcane", giver = "Image of Archmage Modera" }, -- NEW, giver zone: Alterac Mountains (sewer gate)
        { id = 92458, level = 33, min = 24, races = 77, classes = 0, title = "Heart of Disruption", giver = "Image of Archmage Modera" }, -- NEW, giver zone: Alterac Mountains (sewer gate)
        { id = 92489, level = 33, min = 24, races = 77, classes = 0, title = "Power Overwhelming", giver = "High Sorcerer Andromath" }, -- NEW, giver zone: Stormwind City (Mage Quarter)
        { id = 96984, level = 33, min = 24, races = 178, classes = 0, title = "Heart of Disruption", giver = "Image of Archmage Modera" }, -- NEW, giver zone: Alterac Mountains (sewer gate); turn in Tarren Mill
        { id = 96986, level = 33, min = 24, races = 178, classes = 0, title = "The Grave Knight", giver = "Melisara" }, -- NEW, giver zone: Hillsbrad Foothills (Tarren Mill)
        { id = 96987, level = 33, min = 24, races = 178, classes = 0, title = "Opportunistic Education", giver = "Rexxie Copperclutch" }, -- NEW, giver zone: Alterac Mountains (by sewer entrance)
        { id = 96988, level = 33, min = 24, races = 178, classes = 0, title = "Source of Power", giver = "Doctor Martin Felben" }, -- NEW, giver zone: Undercity
        { id = 544, level = 34, min = 0, races = 178, classes = 0, title = "Prison Break In", giver = "Magus Wordeen Voidglare" }, -- NEW, giver zone: Hillsbrad Foothills (61.6,20.9)
        { id = 545, level = 35, min = 0, races = 178, classes = 0, title = "Dalaran Patrols", giver = "?" }, -- NEW, giver zone: ?
    },
    [90] = { -- Gnomeregan
        { id = 2842, level = 0, min = 0, races = 178, classes = 0, title = "Chief Engineer Scooty", giver = "Sovik" }, -- NEW, giver zone: Orgrimmar
        { id = 2923, level = 0, min = 0, races = 77, classes = 0, title = "Tinkmaster Overspark", giver = "Brother Sarno" }, -- NEW, giver zone: Stormwind City
        { id = 2925, level = 0, min = 0, races = 77, classes = 0, title = "Klockmort's Essentials", giver = "Klockmort Spannerspan" }, -- NEW, giver zone: Ironforge (Tinker Town)
        { id = 2927, level = 0, min = 0, races = 77, classes = 0, title = "The Day After", giver = "Gnoarn" }, -- NEW, giver zone: Ironforge (Tinker Town)
        { id = 2922, level = 26, min = 20, races = 77, classes = 0, title = "Save Techbot's Brain!", giver = "Tinkmaster Overspark" }, -- NEW, giver zone: Ironforge (Tinker Town)
        { id = 2926, level = 27, min = 20, races = 77, classes = 0, title = "Gnogaine", giver = "Ozzie Togglevolt" }, -- NEW, giver zone: Dun Morogh (Kharanos)
        { id = 2904, level = 30, min = 24, races = 0, classes = 0, title = "A Fine Mess", giver = "Kernobee" }, -- NEW, giver zone: Gnomeregan (inside)
        { id = 2924, level = 30, min = 24, races = 77, classes = 0, title = "Essential Artificials", giver = "Klockmort Spannerspan" }, -- NEW, giver zone: Ironforge (Tinker Town)
        { id = 2928, level = 30, min = 20, races = 77, classes = 0, title = "Gyrodrillmatic Excavationators", giver = "Shoni the Shilent" }, -- NEW, giver zone: Stormwind City
        { id = 2930, level = 30, min = 25, races = 77, classes = 0, title = "Data Rescue", giver = "Master Mechanic Castpipe" }, -- NEW, giver zone: Ironforge (Tinker Town)
        { id = 2951, level = 30, min = 25, races = 0, classes = 0, title = "The Sparklematic 5200!", giver = "The Sparklematic 5200 (object 142487)" }, -- NEW, giver zone: Gnomeregan (Clean Zone)
        { id = 2952, level = 30, min = 25, races = 0, classes = 0, title = "The Sparklematic 5200! (part 2)", giver = "The Sparklematic 5200 (object 142487)" }, -- NEW, giver zone: Gnomeregan (Clean Zone)
        { id = 2962, level = 30, min = 20, races = 77, classes = 0, title = "The Only Cure is More Green Glow", giver = "Ozzie Togglevolt" }, -- NEW, giver zone: Dun Morogh (Kharanos)
        { id = 2945, level = 34, min = 28, races = 0, classes = 0, title = "Grime-Encrusted Ring", item = 9326 }, -- NEW, giver zone: Gnomeregan (Dark Iron Agent drop)
        { id = 2947, level = 34, min = 28, races = 77, classes = 0, title = "Return of the Ring", giver = "The Sparklematic 5200 (object 142487)" }, -- NEW, giver zone: Gnomeregan (inside)
        { id = 2949, level = 34, min = 28, races = 178, classes = 0, title = "Return of the Ring", giver = "The Sparklematic 5200 (object 142487)" }, -- NEW, giver zone: Gnomeregan (inside)
        { id = 2841, level = 35, min = 25, races = 178, classes = 0, title = "Rig Wars", giver = "Nogg" }, -- NEW, giver zone: Orgrimmar (Valley of Honor)
        { id = 2843, level = 35, min = 25, races = 178, classes = 0, title = "Gnomer-gooooone!", giver = "Scooty" }, -- NEW, giver zone: Stranglethorn Vale (Booty Bay)
        { id = 2929, level = 35, min = 25, races = 77, classes = 0, title = "The Grand Betrayal", giver = "High Tinker Mekkatorque" }, -- NEW, giver zone: Ironforge (Tinker Town)
        { id = 2948, level = 35, min = 0, races = 77, classes = 0, title = "Gnome Improvement", giver = "Talvash del Kissel" }, -- NEW, giver zone: Ironforge
        { id = 2950, level = 35, min = 0, races = 178, classes = 0, title = "Nogg's Ring Redo", giver = "Nogg" }, -- NEW, giver zone: Orgrimmar
    },
    [47] = { -- Razorfen Kraul
        { id = 1100, level = 0, min = 0, races = 77, classes = 0, title = "Lonebrow's Journal", item = 5791 }, -- NEW, giver zone: Thousand Needles (Henrig Lonebrow's body near Great Lift ~30,24)
        { id = 1701, level = 0, min = 0, races = 77, classes = 0, title = "Fire Hardened Mail", giver = "?" }, -- NEW, giver zone: ?
        { id = 1838, level = 0, min = 0, races = 178, classes = 0, title = "Brutal Armor", giver = "?" }, -- NEW, giver zone: ?
        { id = 79360, level = 0, min = 0, races = 178, classes = 0, title = "Elemental Aid", item = 274463 }, -- NEW, giver zone: ?
        { id = 96264, level = 0, min = 0, races = 77, classes = 0, title = "Elemental Aid", item = 274463 }, -- NEW, giver zone: ?
        { id = 1221, level = 26, min = 20, races = 0, classes = 0, title = "Blueleaf Tubers", giver = "Mebok Mizzyrix" }, -- NEW, giver zone: The Barrens (Ratchet)
        { id = 1142, level = 30, min = 25, races = 77, classes = 0, title = "Mortality Wanes", giver = "Heralath Fallowbrook" }, -- NEW, giver zone: Razorfen Kraul (inside, near Charlga)
        { id = 1144, level = 30, min = 23, races = 0, classes = 0, title = "Willix the Importer", giver = "Willix the Importer" }, -- NEW, giver zone: Razorfen Kraul (inside)
        { id = 1109, level = 33, min = 30, races = 178, classes = 0, title = "Going, Going, Guano!", giver = "Master Apothecary Faranell" }, -- NEW, giver zone: Undercity
        { id = 1101, level = 34, min = 29, races = 77, classes = 0, title = "The Crone of the Kraul", giver = "Falfindel Waywarder" }, -- NEW, giver zone: Feralas (Thalanaar)
        { id = 1102, level = 34, min = 29, races = 178, classes = 0, title = "A Vengeful Fate", giver = "Auld Stonespire" }, -- NEW, giver zone: Thunder Bluff
        { id = 6522, level = 36, min = 0, races = 178, classes = 0, title = "An Unholy Alliance", item = 17008 }, -- NEW, giver zone: Razorfen Kraul (Charlga drop)
    },
    [189] = { -- Scarlet Monastery
        { id = 1951, level = 0, min = 0, races = 0, classes = 0, title = "Rituals of Power", giver = "Tabetha" }, -- NEW, giver zone: Dustwallow Marsh
        { id = 78676, level = 0, min = 0, races = 0, classes = 0, title = "The Eye of Bhossca", giver = "?" }, -- NEW, giver zone: ?
        { id = 1051, level = 33, min = 25, races = 178, classes = 0, title = "Vorrel's Revenge", giver = "Vorrel Sengutz", map = 189, x = 1786.2, y = 1119.5 },
        { id = 1113, level = 33, min = 30, races = 178, classes = 0, title = "Hearts of Zeal", giver = "Master Apothecary Faranell", map = 0, x = 1434.5, y = 404.9 },
        { id = 1160, level = 36, min = 25, races = 178, classes = 0, title = "Test of Lore", giver = "Parqual Fintallas", map = 0, x = 1459.2, y = 318.7 },
        { id = 1049, level = 38, min = 28, races = 162, classes = 0, title = "Compendium of the Fallen", giver = "Sage Truthseeker", map = 1, x = -1176.1, y = 157.6 },
        { id = 1050, level = 38, min = 28, races = 77, classes = 0, title = "Mythology of the Titans", giver = "Librarian Mae Paledust", map = 0, x = -4635.1, y = -1306.4 },
        { id = 96800, level = 38, min = 30, races = 77, classes = 0, title = "Past Due", giver = "Magus Olvek" }, -- NEW, giver zone: Dalaran
        { id = 1053, level = 40, min = 34, races = 77, classes = 0, title = "In the Name of the Light", giver = "Raleigh the Devout", map = 0, x = -844.9, y = -580.3 },
        { id = 1048, level = 42, min = 33, races = 178, classes = 0, title = "Into The Scarlet Monastery", giver = "Varimathras", map = 0, x = 1287.8, y = 333.5 },
    },
    [2970] = { -- The Drowned City
        { id = 95786, level = 0, min = 0, races = 77, classes = 0, title = "An Acquaintance in Southshore", giver = "Brother Nimetz (likely)" }, -- NEW, giver zone: Stranglethorn Vale
        { id = 95798, level = 0, min = 0, races = 77, classes = 0, title = "The Web of Magic", giver = "Abra Cadabra" }, -- NEW, giver zone: Dalaran
        { id = 95799, level = 0, min = 0, races = 77, classes = 0, title = "Findings for the Explorer's League", giver = "Historian Karnik" }, -- NEW, giver zone: Ironforge
        { id = 629, level = 37, min = 30, races = 178, classes = 0, title = "The Vile Reef", giver = "Kin'weelay" }, -- NEW, giver zone: Stranglethorn Vale
        { id = 95773, level = 37, min = 30, races = 178, classes = 0, title = "Enemies in the Water", giver = "?" }, -- NEW, giver zone: Stranglethorn Vale (Grom'gol Base Camp)
        { id = 95776, level = 38, min = 30, races = 178, classes = 0, title = "The Only Good Brinescale...", giver = "?" }, -- NEW, giver zone: Stranglethorn Vale (Grom'gol Base Camp)
        { id = 95748, level = 40, min = 30, races = 178, classes = 0, title = "The Gurubashi Legends of Old", giver = "Kin'weelay" }, -- NEW, giver zone: Stranglethorn Vale
        { id = 95770, level = 40, min = 30, races = 178, classes = 0, title = "Locating the Lost City", giver = "Kin'weelay (likely)" }, -- NEW, giver zone: Stranglethorn Vale
        { id = 95775, level = 40, min = 30, races = 178, classes = 0, title = "The Drowned City", giver = "Kin'weelay (likely)" }, -- NEW, giver zone: Stranglethorn Vale
        { id = 95787, level = 40, min = 30, races = 77, classes = 0, title = "Take Two With Water", giver = "Loremaster Dibbs" }, -- NEW, giver zone: Hillsbrad Foothills (Southshore)
        { id = 95788, level = 40, min = 30, races = 77, classes = 0, title = "Magics of the Drowned City", giver = "Loremaster Dibbs" }, -- NEW, giver zone: Hillsbrad Foothills (Southshore)
        { id = 95789, level = 40, min = 34, races = 0, classes = 0, title = "Shady Saltseers", giver = "Krazek" }, -- NEW, giver zone: Booty Bay
        { id = 95791, level = 40, min = 34, races = 0, classes = 0, title = "The Saltseer Captain", giver = "?" }, -- NEW, giver zone: Booty Bay (likely)
        { id = 96774, level = 40, min = 30, races = 178, classes = 0, title = "Ancient Gurubashi Idol", giver = "Mazu'kon" }, -- NEW, giver zone: Mulgore
        { id = 97130, level = 40, min = 34, races = 77, classes = 0, title = "Ancient Gurubashi Secrets", giver = "Archmage Timear" }, -- NEW, giver zone: Dalaran (outside Violet Hold)
    },
    [129] = { -- Razorfen Downs
        { id = 6626, level = 35, min = 28, races = 255, classes = 0, title = "A Host of Evil", giver = "Myriam Moonsinger", map = 1, x = -4801.7, y = -2343.7 },
        { id = 6521, level = 36, min = 28, races = 178, classes = 0, title = "An Unholy Alliance", giver = "Varimathras", map = 0, x = 1287.8, y = 333.5 },
        { id = 6522, level = 36, min = 28, races = 178, classes = 0, title = "An Unholy Alliance", item = 17008 },
        { id = 3523, level = 37, min = 32, races = 255, classes = 0, title = "Scourge of the Downs", giver = "Belnistrasz", map = 129, x = 2610.7, y = 730.6 },
        { id = 3525, level = 37, min = 32, races = 255, classes = 0, title = "Extinguishing the Idol", giver = "Belnistrasz", map = 129, x = 2610.7, y = 730.6 },
        { id = 3341, level = 42, min = 37, races = 178, classes = 0, title = "Bring the End", giver = "Andrew Brownell", map = 0, x = 1664.8, y = 162.8 },
        { id = 3636, level = 42, min = 39, races = 77, classes = 0, title = "Bring the Light", giver = "Archbishop Benedictus", map = 0, x = -8522.6, y = 848.8 },
    },
    [3039] = { -- Krol'dok Stronghold
        { id = 94768, level = 0, min = 0, races = 178, classes = 0, title = "Bring Me His Head", giver = "Da'grosh" }, -- NEW, giver zone: Riverglades
        { id = 94890, level = 0, min = 0, races = 77, classes = 0, title = "Bring Me His Head", giver = "Sergeant Riftan" }, -- NEW, giver zone: Riverglades
        { id = 94907, level = 0, min = 0, races = 77, classes = 0, title = "A Small Favor", giver = "Ashe Amberhall" }, -- NEW, giver zone: Riverglades (Farholde Keep)
        { id = 94973, level = 0, min = 0, races = 178, classes = 0, title = "Krol'dok Moulding", giver = "Kreza Darkthorn" }, -- NEW, giver zone: Riverglades (Rog'mar)
        { id = 94974, level = 0, min = 0, races = 178, classes = 0, title = "Key Ingredients", giver = "Kreza Darkthorn" }, -- NEW, giver zone: Riverglades (Rog'mar)
        { id = 94980, level = 0, min = 0, races = 77, classes = 0, title = "Krol'dok Moulding", giver = "Alphonse Dumas" }, -- NEW, giver zone: Riverglades (Farholde Keep)
        { id = 94981, level = 0, min = 0, races = 77, classes = 0, title = "Key Ingredients", giver = "Alphonse Dumas" }, -- NEW, giver zone: Riverglades (Farholde Keep)
        { id = 94998, level = 0, min = 0, races = 77, classes = 0, title = "Curios of Curiosity", giver = "?" }, -- NEW, giver zone: Riverglades
        { id = 94975, level = 42, min = 38, races = 178, classes = 0, title = "A Token of Vengeance", giver = "Da'grosh (likely)" }, -- NEW, giver zone: Riverglades
        { id = 94983, level = 42, min = 38, races = 77, classes = 0, title = "Twilight Mementos", giver = "Sergeant Riftan (likely)" }, -- NEW, giver zone: Riverglades
        { id = 94972, level = 44, min = 39, races = 178, classes = 0, title = "Tome of Twilight", giver = "?" }, -- NEW, giver zone: ?
        { id = 94984, level = 44, min = 39, races = 77, classes = 0, title = "Tome of Twilight", giver = "Ashe Amberhall" }, -- NEW, giver zone: Riverglades (Farholde Keep)
        { id = 94968, level = 45, min = 40, races = 178, classes = 0, title = "Eye of Mugg", giver = "Krom'rosh" }, -- NEW, giver zone: Riverglades (Rog'mar)
        { id = 94982, level = 45, min = 40, races = 77, classes = 0, title = "Eye of Mugg", giver = "Commander Demar Brant" }, -- NEW, giver zone: Riverglades (Farholde Keep)
        { id = 96771, level = 45, min = 37, races = 77, classes = 0, title = "Vengeance of the Highborne", giver = "Ranath Nightstride" }, -- NEW, giver zone: Dalaran inn (Alterac Mountains)
    },
    [70] = { -- Uldaman
        { id = 2418, level = 36, min = 30, races = 0, classes = 0, title = "Power Stones", giver = "Rigglefuzz" }, -- NEW, giver zone: Badlands
        { id = 704, level = 38, min = 30, races = 77, classes = 0, title = "Agmond's Fate", giver = "Prospector Ironband" }, -- NEW, giver zone: Loch Modan
        { id = 709, level = 40, min = 30, races = 0, classes = 0, title = "Solution to Doom", giver = "Theldurin the Lost" }, -- NEW, giver zone: Badlands
        { id = 722, level = 40, min = 35, races = 77, classes = 0, title = "Amulet of Secrets", giver = "Hammertoe Grez" }, -- NEW, giver zone: Uldaman excavation (outside)
        { id = 1956, level = 40, min = 0, races = 0, classes = 0, title = "Power in Uldaman", giver = "Tabetha" }, -- NEW, giver zone: Dustwallow Marsh
        { id = 2240, level = 40, min = 35, races = 77, classes = 0, title = "The Hidden Chamber", giver = "Baelog" }, -- NEW, giver zone: Uldaman (inside)
        { id = 2198, level = 41, min = 37, races = 77, classes = 0, title = "The Shattered Necklace", giver = "Shattered Necklace (item)" }, -- NEW, giver zone: Uldaman (drop)
        { id = 2199, level = 41, min = 37, races = 77, classes = 0, title = "Lore for a Price", giver = "Talvash del Kissel" }, -- NEW, giver zone: Ironforge
        { id = 2283, level = 41, min = 37, races = 178, classes = 0, title = "Necklace Recovery", giver = "Dran Droffers" }, -- NEW, giver zone: Orgrimmar
        { id = 17, level = 42, min = 36, races = 77, classes = 0, title = "Uldaman Reagent Run", giver = "Ghak Healtouch" }, -- NEW, giver zone: Loch Modan
        { id = 2202, level = 42, min = 36, races = 178, classes = 0, title = "Uldaman Reagent Run", giver = "Jarkal Mossmeld" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 2338, level = 42, min = 37, races = 178, classes = 0, title = "Translating the Journal", giver = "Jarkal Mossmeld" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 1360, level = 43, min = 33, races = 77, classes = 0, title = "Reclaimed Treasures", giver = "Krom Stoutarm" }, -- NEW, giver zone: Ironforge
        { id = 2201, level = 43, min = 40, races = 77, classes = 0, title = "Find the Gems", giver = "Remains of a Paladin" }, -- NEW, giver zone: Uldaman (inside)
        { id = 2342, level = 43, min = 33, races = 178, classes = 0, title = "Reclaimed Treasures", giver = "Patrick Garrett" }, -- NEW, giver zone: Undercity
        { id = 2204, level = 44, min = 40, races = 77, classes = 0, title = "Restoring the Necklace", giver = "Talvash's Scrying Bowl (object 112877)" }, -- NEW, giver zone: Uldaman (inside)
        { id = 2339, level = 44, min = 37, races = 178, classes = 0, title = "Find the Gems and Power Source", giver = "Jarkal Mossmeld" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 2340, level = 44, min = 37, races = 178, classes = 0, title = "Deliver the Gems", giver = "Jarkal Mossmeld" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 2341, level = 44, min = 40, races = 178, classes = 0, title = "Necklace Recovery, Take 3", giver = "Dran Droffers" }, -- NEW, giver zone: Orgrimmar
        { id = 2361, level = 44, min = 40, races = 77, classes = 0, title = "Restoring the Necklace", giver = "Talvash del Kissel" }, -- NEW, giver zone: Ironforge
        { id = 1139, level = 45, min = 35, races = 77, classes = 0, title = "The Lost Tablets of Will", giver = "Advisor Belgrum" }, -- NEW, giver zone: Ironforge
        { id = 2279, level = 47, min = 40, races = 77, classes = 0, title = "The Platinum Discs", giver = "The Discs of Norgannon (object 131474)" }, -- NEW, giver zone: Uldaman (inside)
        { id = 2280, level = 47, min = 40, races = 178, classes = 0, title = "The Platinum Discs", giver = "The Discs of Norgannon (object 131474)" }, -- NEW, giver zone: Uldaman (inside)
    },
    [209] = { -- Zul'Farrak
        { id = 2865, level = 45, min = 40, races = 0, classes = 0, title = "Scarab Shells", giver = "Tran'rek" }, -- NEW, giver zone: Tanaris (Gadgetzan)
        { id = 2936, level = 45, min = 40, races = 178, classes = 0, title = "The Spider God", giver = "Master Gadrin" }, -- NEW, giver zone: Durotar (Sen'jin Village)
        { id = 3042, level = 45, min = 40, races = 0, classes = 0, title = "Troll Temper", giver = "Trenton Lighthammer" }, -- NEW, giver zone: Tanaris (Gadgetzan)
        { id = 2846, level = 46, min = 40, races = 0, classes = 0, title = "Tiara of the Deep", giver = "Tabetha" }, -- NEW, giver zone: Dustwallow Marsh
        { id = 2768, level = 47, min = 40, races = 0, classes = 0, title = "Divino-matic Rod", giver = "Chief Engineer Bilgewhizzle" }, -- NEW, giver zone: Tanaris (Gadgetzan)
        { id = 2991, level = 47, min = 40, races = 77, classes = 0, title = "Nekrum's Medallion", giver = "Thadius Grimshade" }, -- NEW, giver zone: Blasted Lands (Nethergarde Keep)
        { id = 3527, level = 47, min = 40, races = 0, classes = 0, title = "The Prophecy of Mosh'aru", giver = "Yeh'kinya" }, -- NEW, giver zone: Tanaris (Steamwheedle Port)
        { id = 2770, level = 50, min = 40, races = 0, classes = 0, title = "Gahz'rilla", giver = "Wizzle Brassbolts" }, -- NEW, giver zone: Thousand Needles (Shimmering Flats)
    },
    [349] = { -- Maraudon
        { id = 7068, level = 42, min = 38, races = 178, classes = 0, title = "Shadowshard Fragments", giver = "Uthel'nay", map = 1, x = 1466.9, y = -4229.9 },
        { id = 7070, level = 42, min = 38, races = 77, classes = 0, title = "Shadowshard Fragments", giver = "Archmage Tervosh", map = 1, x = -3757.5, y = -4462.3 },
        { id = 7028, level = 47, min = 41, races = 255, classes = 0, title = "Twisted Evils", giver = "Willow", map = 1, x = -735.9, y = 1437.1 },
        { id = 7029, level = 47, min = 41, races = 178, classes = 0, title = "Vyletongue Corruption", giver = "Vark Battlescar", map = 1, x = -1656.3, y = 3189.5 },
        { id = 7041, level = 47, min = 41, races = 77, classes = 0, title = "Vyletongue Corruption", giver = "Talendria", map = 1, x = 185.9, y = 1153.6 },
        { id = 7067, level = 48, min = 39, races = 255, classes = 0, title = "The Pariah's Instructions", giver = "Centaur Pariah", map = 1, x = -2145.7, y = 1966.4 },
        { id = 7044, level = 49, min = 41, races = 255, classes = 0, title = "Legends of Maraudon", giver = "Cavindra", map = 1, x = -1465.3, y = 2790.2 },
        { id = 7046, level = 49, min = 41, races = 0, classes = 0, title = "The Scepter of Celebras", giver = "Celebras the Redeemed" }, -- NEW, giver zone: Maraudon (inside)
        { id = 7064, level = 51, min = 45, races = 178, classes = 0, title = "Corruption of Earth and Seed", giver = "Selendra", map = 1, x = -1876.3, y = 3025.2 },
        { id = 7065, level = 51, min = 45, races = 77, classes = 0, title = "Corruption of Earth and Seed", giver = "Keeper Marandis", map = 1, x = 132.2, y = 1363.8 },
        { id = 7066, level = 51, min = 45, races = 0, classes = 0, title = "Seed of Life", giver = "Zaetar's Spirit" }, -- NEW, giver zone: Maraudon (after Princess Theradras)
    },
    [2994] = { -- Alcaz Prison
        { id = 95283, level = 53, min = 48, races = 178, classes = 0, title = "The Missing Kor'kron", giver = "?" }, -- NEW, giver zone: Dustwallow Marsh
        { id = 95284, level = 53, min = 48, races = 178, classes = 0, title = "The Elite of the Elite", giver = "?" }, -- NEW, giver zone: Dustwallow Marsh
        { id = 96772, level = 53, min = 46, races = 77, classes = 0, title = "The Dragon's Journal", giver = "Archmage Lan'dalock (probable)" }, -- NEW, giver zone: Alterac Mountains (Dalaran)
    },
    [109] = { -- Sunken Temple
        { id = 1445, level = 50, min = 38, races = 178, classes = 0, title = "The Temple of Atal'Hakkar", giver = "Fel'zerul", map = 0, x = -10458.5, y = -3322.3 },
        { id = 1475, level = 50, min = 41, races = 77, classes = 0, title = "Into The Temple of Atal'Hakkar", giver = "Brohann Caskbelly", map = 0, x = -8463.8, y = 516.2 },
        { id = 3446, level = 51, min = 46, races = 255, classes = 0, title = "Into the Depths", giver = "Marvon Rivetseeker", map = 1, x = -7987.5, y = -3855.6 },
        { id = 3447, level = 51, min = 46, races = 255, classes = 0, title = "Secret of the Circle", giver = "Marvon Rivetseeker", map = 1, x = -7987.5, y = -3855.6 },
        { id = 4143, level = 52, min = 47, races = 77, classes = 0, title = "Haze of Evil", giver = "Gregan Brewspewer" }, -- NEW, giver zone: Feralas
        { id = 4146, level = 52, min = 47, races = 178, classes = 0, title = "Zapper Fuel", giver = "Liv Rizzlefix", map = 1, x = -1004.5, y = -3705.2 },
        { id = 8232, level = 52, min = 0, races = 0, classes = 0, title = "The Green Drake", giver = "Ogtinc" }, -- NEW, giver zone: Azshara
        { id = 8236, level = 52, min = 0, races = 0, classes = 0, title = "The Azure Key", giver = "Archmage Xylem" }, -- NEW, giver zone: Azshara
        { id = 8253, level = 52, min = 0, races = 0, classes = 0, title = "Destroy Morphaz", giver = "Archmage Xylem" }, -- NEW, giver zone: Azshara
        { id = 8257, level = 52, min = 0, races = 0, classes = 0, title = "Blood of Morphaz", giver = "Ogtinc" }, -- NEW, giver zone: Azshara
        { id = 8413, level = 52, min = 0, races = 0, classes = 0, title = "Da Voodoo", giver = "Bath'rah the Windwatcher" }, -- NEW, giver zone: Alterac Mountains
        { id = 8418, level = 52, min = 0, races = 0, classes = 0, title = "Forging the Mightstone", giver = "Commander Ashlam Valorfist" }, -- NEW, giver zone: Western Plaguelands
        { id = 8422, level = 52, min = 0, races = 0, classes = 0, title = "Trolls of a Feather", giver = "Impsy" }, -- NEW, giver zone: Felwood
        { id = 8425, level = 52, min = 0, races = 0, classes = 0, title = "Voodoo Feathers", giver = "Fallen Hero of the Horde" }, -- NEW, giver zone: Swamp of Sorrows
        { id = 9053, level = 52, min = 0, races = 0, classes = 0, title = "A Better Ingredient", giver = "Torwa Pathfinder" }, -- NEW, giver zone: Un'Goro Crater
        { id = 1446, level = 53, min = 38, races = 255, classes = 0, title = "Jammal'an the Prophet", giver = "Atal'ai Exile", map = 0, x = -463.7, y = -2874.4 },
        { id = 3528, level = 53, min = 40, races = 255, classes = 0, title = "The God Hakkar", giver = "Yeh'kinya", map = 1, x = -6903.4, y = -4840.9 },
        { id = 3373, level = 55, min = 48, races = 255, classes = 0, title = "The Essence of Eranikus", item = 10454 },
    },
    [230] = { -- Blackrock Depths
        { id = 7848, level = 0, min = 0, races = 0, classes = 0, title = "Attunement to the Core", giver = "Lothos Riftwaker" }, -- NEW, giver zone: Blackrock Mountain
        { id = 3802, level = 52, min = 48, races = 0, classes = 0, title = "Dark Iron Legacy", giver = "Franclorn Forgewright (ghost)" }, -- NEW, giver zone: Blackrock Mountain
        { id = 4081, level = 52, min = 48, races = 178, classes = 0, title = "KILL ON SIGHT: Dark Iron Dwarves", giver = "WANTED poster (object 164867)" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4136, level = 53, min = 48, races = 0, classes = 0, title = "Ribbly Screwspigot", giver = "Yuka Screwspigot" }, -- NEW, giver zone: Burning Steppes (Flame Crest)
        { id = 4082, level = 54, min = 50, races = 178, classes = 0, title = "KILL ON SIGHT: High Ranking Dark Iron Officials", giver = "KILL ON SIGHT poster (object 164868)" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4201, level = 54, min = 50, races = 0, classes = 0, title = "The Love Potion", giver = "Mistress Nagmara" }, -- NEW, giver zone: Blackrock Depths (Grim Guzzler)
        { id = 4242, level = 54, min = 48, races = 77, classes = 0, title = "Abandoned Hope", giver = "Marshal Windsor" }, -- NEW, giver zone: Burning Steppes
        { id = 7201, level = 54, min = 48, races = 178, classes = 0, title = "The Last Element", giver = "Vivian Lagrave" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4083, level = 55, min = 40, races = 0, classes = 0, title = "The Spectral Chalice", giver = "Spectral Chalice (object 164869)" }, -- NEW, giver zone: Blackrock Depths
        { id = 4123, level = 55, min = 50, races = 0, classes = 0, title = "The Heart of the Mountain", giver = "Maxwort Uberglint" }, -- NEW, giver zone: Burning Steppes (Flame Crest)
        { id = 4126, level = 55, min = 50, races = 77, classes = 0, title = "Hurley Blackbreath", giver = "Ragnar Thunderbrew" }, -- NEW, giver zone: Dun Morogh (Kharanos)
        { id = 4134, level = 55, min = 50, races = 178, classes = 0, title = "Lost Thunderbrew Recipe", giver = "Vivian Lagrave" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 3907, level = 56, min = 48, races = 178, classes = 0, title = "Disharmony of Fire", giver = "Thunderheart" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4263, level = 56, min = 48, races = 77, classes = 0, title = "Incendius!", giver = "Jalinda Sprig" }, -- NEW, giver zone: Searing Gorge (Thorium Point)
        { id = 4286, level = 56, min = 50, races = 77, classes = 0, title = "The Good Stuff", giver = "Oralius" }, -- NEW, giver zone: Burning Steppes (Morgan's Vigil)
        { id = 4024, level = 58, min = 52, races = 0, classes = 0, title = "A Taste of Flame", giver = "Cyrus Therepentous" }, -- NEW, giver zone: Burning Steppes
        { id = 4063, level = 58, min = 52, races = 178, classes = 0, title = "The Rise of the Machines", giver = "Lotwil Veriatus" }, -- NEW, giver zone: Badlands
        { id = 4121, level = 58, min = 52, races = 178, classes = 0, title = "Precarious Predicament", giver = "Grark Lorkrub" }, -- NEW, giver zone: Burning Steppes
        { id = 4132, level = 58, min = 52, races = 178, classes = 0, title = "Operation: Death to Angerforge", giver = "Warlord Goretooth" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4264, level = 58, min = 50, races = 77, classes = 0, title = "A Crumpled Up Note", giver = "A Crumpled Up Note" }, -- NEW, giver zone: Blackrock Depths
        { id = 4282, level = 58, min = 50, races = 77, classes = 0, title = "A Shred of Hope", giver = "Marshal Windsor" }, -- NEW, giver zone: Blackrock Depths
        { id = 4322, level = 58, min = 50, races = 77, classes = 0, title = "Jail Break!", giver = "Marshal Windsor" }, -- NEW, giver zone: Blackrock Depths
        { id = 4003, level = 59, min = 48, races = 178, classes = 0, title = "The Royal Rescue", giver = "Thrall" }, -- NEW, giver zone: Orgrimmar
        { id = 4362, level = 59, min = 50, races = 77, classes = 0, title = "The Fate of the Kingdom", giver = "King Magni Bronzebeard" }, -- NEW, giver zone: Ironforge
        { id = 4363, level = 59, min = 50, races = 77, classes = 0, title = "The Princess's Surprise", giver = "Princess Moira Bronzebeard" }, -- NEW, giver zone: Blackrock Depths
        { id = 4004, level = 60, min = 48, races = 178, classes = 0, title = "The Princess Saved?", giver = "Princess Moira Bronzebeard" }, -- NEW, giver zone: Blackrock Depths
        { id = 7604, level = 60, min = 60, races = 0, classes = 0, title = "A Binding Contract", giver = "Thorium Brotherhood Contract" }, -- NEW, giver zone: ?
        { id = 9015, level = 60, min = 58, races = 0, classes = 0, title = "The Challenge", giver = "Falrin Treeshaper" }, -- NEW, giver zone: Dire Maul
    },
    [429] = { -- Dire Maul
        { id = 1193, level = 60, min = 56, races = 255, classes = 0, title = "A Broken Trap", giver = "Broken Trap", map = 429, x = 558.8, y = 550.1 },
        { id = 5526, level = 0, min = 0, races = 0, classes = 0, title = "Shards of the Felvine", giver = "Rabine Saturna" }, -- NEW, giver zone: Moonglade
        { id = 7481, level = 60, min = 54, races = 178, classes = 0, title = "Elven Legends", giver = "Sage Korolusk", map = 1, x = -4394.1, y = 212.5 },
        { id = 7482, level = 60, min = 54, races = 77, classes = 0, title = "Elven Legends", giver = "Scholar Runethorn", map = 1, x = -4401.7, y = 3275.5 },
        { id = 7483, level = 60, min = 58, races = 255, classes = 0, title = "Libram of Rapidity", giver = "Lorekeeper Lydros", map = 429, x = 164.3, y = 522.5 },
        { id = 7484, level = 60, min = 58, races = 255, classes = 0, title = "Libram of Focus", giver = "Lorekeeper Lydros", map = 429, x = 164.3, y = 522.5 },
        { id = 7485, level = 60, min = 58, races = 255, classes = 0, title = "Libram of Protection", giver = "Lorekeeper Lydros", map = 429, x = 164.3, y = 522.5 },
        { id = 7488, level = 57, min = 54, races = 77, classes = 0, title = "Lethtendris's Web", giver = "Latronicus Moonspear", map = 1, x = -4505.9, y = 3330.3 },
        { id = 7489, level = 57, min = 54, races = 178, classes = 0, title = "Lethtendris's Web", giver = "Talo Thornhoof", map = 1, x = -4397.7, y = 146.9 },
        { id = 7441, level = 58, min = 54, races = 255, classes = 0, title = "Pusillin and the Elder Azj'Tordin", giver = "Azj'Tordin", map = 1, x = -4097.2, y = 96.5 },
        { id = 1318, level = 60, min = 56, races = 0, classes = 0, title = "Unfinished Gordok Business", giver = "Captain Kromcrush" }, -- NEW, giver zone: Dire Maul North
        { id = 5518, level = 60, min = 56, races = 255, classes = 0, title = "The Gordok Ogre Suit", giver = "Knot Thimblejack", map = 429, x = 581.1, y = 523.3 },
        { id = 5525, level = 60, min = 57, races = 255, classes = 0, title = "Free Knot!", giver = "Knot Thimblejack", map = 429, x = 581.1, y = 523.3 },
        { id = 5528, level = 60, min = 57, races = 255, classes = 0, title = "The Gordok Taste Test", giver = "Stomper Kreeg", map = 429, x = 491.2, y = 97.4 },
        { id = 7461, level = 60, min = 56, races = 255, classes = 0, title = "The Madness Within", giver = "Shen'dralar Ancient", map = 429, x = 11.7, y = 396.1 },
        { id = 7462, level = 60, min = 56, races = 77, classes = 0, title = "The Treasure of the Shen'dralar", giver = "Shen'dralar Ancient", map = 429, x = 11.7, y = 396.1 },
        { id = 7463, level = 60, min = 60, races = 255, classes = 128, title = "Arcane Refreshment", giver = "Lorekeeper Lydros", map = 429, x = 164.3, y = 522.5 },
        { id = 7498, level = 60, min = 54, races = 255, classes = 8, title = "Garona: A Study on Stealth and Treachery", item = 18356 },
        { id = 7499, level = 60, min = 54, races = 255, classes = 1, title = "Codex of Defense", item = 18357 },
        { id = 7500, level = 60, min = 54, races = 255, classes = 128, title = "The Arcanist's Cookbook", item = 18358 },
        { id = 7501, level = 60, min = 54, races = 255, classes = 2, title = "The Light and How To Swing It", item = 18359 },
        { id = 7502, level = 60, min = 54, races = 255, classes = 256, title = "Harnessing Shadows", item = 18360 },
        { id = 7503, level = 60, min = 54, races = 255, classes = 4, title = "The Greatest Race of Hunters", item = 18361 },
        { id = 7504, level = 60, min = 54, races = 255, classes = 16, title = "Holy Bologna: What the Light Won't Tell You", item = 18362 },
        { id = 7505, level = 60, min = 54, races = 255, classes = 64, title = "Frost Shock and You", item = 18363 },
        { id = 7506, level = 60, min = 54, races = 255, classes = 1024, title = "The Emerald Dream...", item = 18364 },
        { id = 7507, level = 60, min = 60, races = 255, classes = 0, title = "Foror's Compendium", item = 18401 },
        { id = 7508, level = 60, min = 60, races = 255, classes = 0, title = "The Forging of Quel'Serrar", item = 18513 },
        { id = 7631, level = 60, min = 0, races = 0, classes = 0, title = "Dreadsteed of Xoroth", giver = "Mor'zul Bloodbringer" }, -- NEW, giver zone: Burning Steppes
        { id = 7877, level = 60, min = 56, races = 178, classes = 0, title = "The Treasure of the Shen'dralar", giver = "Shen'dralar Ancient", map = 429, x = 11.7, y = 396.1 },
        { id = 8948, level = 60, min = 58, races = 255, classes = 0, title = "Anthion's Old Friend", giver = "Anthion Harmon", map = 0, x = 3367.6, y = -3379.8 },
        { id = 8949, level = 60, min = 58, races = 255, classes = 0, title = "Falrin's Vendetta", giver = "Falrin Treeshaper", map = 429, x = 122.7, y = 444.6 },
        { id = 8950, level = 60, min = 58, races = 255, classes = 0, title = "The Instigator's Enchantment", giver = "Falrin Treeshaper", map = 429, x = 122.7, y = 444.6 },
        { id = 8967, level = 60, min = 58, races = 255, classes = 0, title = "The Left Piece of Lord Valthalak's Amulet", giver = "Bodley", map = 0, x = -7534.8, y = -1212.6 },
        { id = 8990, level = 60, min = 58, races = 255, classes = 0, title = "The Right Piece of Lord Valthalak's Amulet", giver = "Bodley", map = 0, x = -7534.8, y = -1212.6 },
    },
    [229] = { -- Blackrock Spire
        { id = 6821, level = 0, min = 0, races = 0, classes = 0, title = "Eye of the Emberseer", giver = "Duke Hydraxis" }, -- NEW, giver zone: Azshara
        { id = 7761, level = 0, min = 0, races = 0, classes = 0, title = "Blackhand's Command", item = 18987 }, -- NEW, giver zone: Upper Blackrock Spire
        { id = 4788, level = 58, min = 40, races = 0, classes = 0, title = "The Final Tablets", giver = "Prospector Ironboot" }, -- NEW, giver zone: Tanaris
        { id = 4701, level = 59, min = 55, races = 77, classes = 0, title = "Put Her Down", giver = "Helendis Riverhorn" }, -- NEW, giver zone: Burning Steppes (Morgan's Vigil)
        { id = 4724, level = 59, min = 55, races = 178, classes = 0, title = "The Pack Mistress", giver = "Galamav the Marksman" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4729, level = 59, min = 55, races = 0, classes = 0, title = "Kibler's Exotic Pets", giver = "Kibler" }, -- NEW, giver zone: Burning Steppes (Flame Crest)
        { id = 4862, level = 59, min = 55, races = 0, classes = 0, title = "En-Ay-Es-Tee-Why", giver = "Kibler" }, -- NEW, giver zone: Burning Steppes (Flame Crest)
        { id = 4982, level = 59, min = 55, races = 178, classes = 0, title = "Bijou's Belongings", giver = "Bijou" }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 4983, level = 59, min = 55, races = 178, classes = 0, title = "Bijou's Reconnaissance Report", giver = "Bijou" }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 5001, level = 59, min = 55, races = 77, classes = 0, title = "Bijou's Belongings", giver = "Bijou" }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 5002, level = 59, min = 55, races = 77, classes = 0, title = "Message to Maxwell", giver = "Bijou" }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 4734, level = 60, min = 57, races = 0, classes = 0, title = "Egg Freezing", giver = "Tinkee Steamboil" }, -- NEW, giver zone: Burning Steppes (Flame Crest)
        { id = 4735, level = 60, min = 57, races = 0, classes = 0, title = "Egg Collection", giver = "Tinkee Steamboil" }, -- NEW, giver zone: Burning Steppes (Flame Crest)
        { id = 4742, level = 60, min = 57, races = 0, classes = 0, title = "Seal of Ascension", giver = "Vaelan" }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 4743, level = 60, min = 57, races = 0, classes = 0, title = "Seal of Ascension", giver = "Vaelan" }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 4764, level = 60, min = 57, races = 77, classes = 0, title = "Doomrigger's Clasp", giver = "Mayara Brightwing" }, -- NEW, giver zone: Burning Steppes (Morgan's Vigil)
        { id = 4765, level = 60, min = 57, races = 77, classes = 0, title = "Delivery to Ridgewell", giver = "Mayara Brightwing" }, -- NEW, giver zone: Burning Steppes (Morgan's Vigil)
        { id = 4768, level = 60, min = 57, races = 178, classes = 0, title = "The Darkstone Tablet", giver = "Shadowmage Vivian Lagrave" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4866, level = 60, min = 55, races = 0, classes = 0, title = "Mother's Milk", giver = "Ragged John" }, -- NEW, giver zone: Burning Steppes (Flame Crest)
        { id = 4867, level = 60, min = 55, races = 0, classes = 0, title = "Urok Doomhowl", giver = "Warosh" }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 4903, level = 60, min = 55, races = 178, classes = 0, title = "Warlord's Command", giver = "Warlord Goretooth" }, -- NEW, giver zone: Badlands (Kargath)
        { id = 4974, level = 60, min = 55, races = 178, classes = 0, title = "For The Horde!", giver = "Thrall" }, -- NEW, giver zone: Orgrimmar
        { id = 5047, level = 60, min = 55, races = 0, classes = 0, title = "Finkle Einhorn, At Your Service!", giver = "Pip Quickwit" }, -- NEW, giver zone: Upper Blackrock Spire (after The Beast)
        { id = 5081, level = 60, min = 55, races = 77, classes = 0, title = "Maxwell's Mission", giver = "Marshal Maxwell" }, -- NEW, giver zone: Burning Steppes (Morgan's Vigil)
        { id = 5089, level = 60, min = 55, races = 77, classes = 0, title = "General Drakkisath's Command", item = 12780 }, -- NEW, giver zone: Lower Blackrock Spire
        { id = 5102, level = 60, min = 55, races = 77, classes = 0, title = "General Drakkisath's Demise", giver = "Marshal Maxwell" }, -- NEW, giver zone: Burning Steppes (Morgan's Vigil)
        { id = 5127, level = 60, min = 55, races = 0, classes = 0, title = "The Demon Forge", giver = "Lorax" }, -- NEW, giver zone: Winterspring
        { id = 5160, level = 60, min = 57, races = 0, classes = 0, title = "The Matron Protectorate", giver = "Awbee" }, -- NEW, giver zone: Upper Blackrock Spire
        { id = 6502, level = 60, min = 50, races = 77, classes = 0, title = "Drakefire Amulet", giver = "Haleh" }, -- NEW, giver zone: Winterspring
        { id = 6569, level = 60, min = 55, races = 178, classes = 0, title = "Oculus Illusions", giver = "Myranda the Hag" }, -- NEW, giver zone: Western Plaguelands
        { id = 6602, level = 60, min = 55, races = 178, classes = 0, title = "Blood of the Black Dragon Champion", giver = "Rexxar" }, -- NEW, giver zone: Feralas
        { id = 8966, level = 60, min = 58, races = 0, classes = 0, title = "The Left Piece of Lord Valthalak's Amulet", giver = "Bodley" }, -- NEW, giver zone: Blackrock Mountain
        { id = 8989, level = 60, min = 58, races = 0, classes = 0, title = "The Right Piece of Lord Valthalak's Amulet", giver = "Bodley" }, -- NEW, giver zone: Blackrock Mountain
        { id = 8995, level = 60, min = 58, races = 0, classes = 0, title = "Mea Culpa, Lord Valthalak", giver = "Bodley" }, -- NEW, giver zone: Blackrock Mountain
    },
    [2974] = { -- Blackmaw Hold
        { id = 92343, level = 55, min = 45, races = 178, classes = 0, title = "Get to the Roots of It", giver = "Nara Wildmane" }, -- NEW, giver zone: Thunder Bluff
        { id = 92344, level = 55, min = 45, races = 77, classes = 0, title = "Get to the Roots of It", giver = "Mathrengyl Bearwalker" }, -- NEW, giver zone: Darnassus
        { id = 92345, level = 55, min = 45, races = 77, classes = 0, title = "Beneath Nordrassil", giver = "?" }, -- NEW, giver zone: ?
        { id = 92346, level = 55, min = 45, races = 178, classes = 0, title = "Beneath Nordrassil", giver = "Jediga" }, -- NEW, giver zone: Azshara (Valormok)
        { id = 92069, level = 58, min = 45, races = 0, classes = 0, title = "Claws That Rend, Tusks that Gore", giver = "Ogtinc" }, -- NEW, giver zone: Azshara
        { id = 97173, level = 59, min = 52, races = 77, classes = 0, title = "Blackmaw Magic", giver = "?" }, -- NEW, giver zone: Dalaran? (unconfirmed)
        { id = 97198, level = 59, min = 52, races = 178, classes = 0, title = "Blackmaw Magic", giver = "?" }, -- NEW, giver zone: ?
    },
    [329] = { -- Stratholme
        { id = 5122, level = 60, min = 55, races = 255, classes = 0, title = "The Medallion of Faith", giver = "Aurius", map = 329, x = 3680.5, y = -3643.8 },
        { id = 5281, level = 0, min = 0, races = 0, classes = 0, title = "The Restless Souls", giver = "Caretaker Alen" }, -- NEW, giver zone: Eastern Plaguelands (Light's Hope)
        { id = 5305, level = 0, min = 0, races = 0, classes = 0, title = "Sweet Serenity", giver = "?" }, -- NEW, giver zone: ?
        { id = 5307, level = 0, min = 0, races = 0, classes = 0, title = "Corruption", giver = "Seril Scourgebane" }, -- NEW, giver zone: Winterspring
        { id = 5846, level = 0, min = 0, races = 0, classes = 0, title = "Of Love and Family", giver = "Tirion Fordring" }, -- NEW, giver zone: Eastern Plaguelands
        { id = 5125, level = 60, min = 55, races = 255, classes = 0, title = "Aurius' Reckoning", giver = "Aurius", map = 329, x = 3680.5, y = -3643.8 },
        { id = 5212, level = 60, min = 55, races = 255, classes = 0, title = "The Flesh Does Not Lie", giver = "Betina Bigglezink", map = 0, x = 2260.1, y = -5339.0 },
        { id = 5213, level = 60, min = 55, races = 255, classes = 0, title = "The Active Agent", giver = "Betina Bigglezink", map = 0, x = 2260.1, y = -5339.0 },
        { id = 5214, level = 60, min = 55, races = 255, classes = 0, title = "The Great Fras Siabi", giver = "Smokey LaRue", map = 0, x = 2303.4, y = -5305.5 },
        { id = 5243, level = 60, min = 55, races = 255, classes = 0, title = "Houses of the Holy", giver = "Leonid Barthalomew the Revered", map = 0, x = 2307.2, y = -5348.9 },
        { id = 5251, level = 60, min = 55, races = 255, classes = 0, title = "The Archivist", giver = "Duke Nicholas Zverenhoff", map = 0, x = 2255.9, y = -5337.7 },
        { id = 5262, level = 60, min = 55, races = 255, classes = 0, title = "The Truth Comes Crashing Down", item = 13250 },
        { id = 5263, level = 60, min = 55, races = 255, classes = 0, title = "Above and Beyond", giver = "Duke Nicholas Zverenhoff", map = 0, x = 2255.9, y = -5337.7 },
        { id = 5282, level = 60, min = 55, races = 255, classes = 0, title = "The Restless Souls", giver = "Egan", map = 0, x = 2929.1, y = -2744.7 },
        { id = 5463, level = 60, min = 57, races = 255, classes = 0, title = "Menethil's Gift", giver = "Leonid Barthalomew the Revered", map = 0, x = 2307.2, y = -5348.9 },
        { id = 5848, level = 60, min = 52, races = 255, classes = 0, title = "Of Love and Family", giver = "Artist Renfray", map = 0, x = 1206.1, y = -2411.5 },
        { id = 6163, level = 60, min = 56, races = 178, classes = 0, title = "Ramstein", giver = "Nathanos Blightcaller", map = 0, x = 1871.0, y = -3212.7 },
        { id = 8945, level = 60, min = 58, races = 255, classes = 0, title = "Dead Man's Plea", giver = "Anthion Harmon", map = 0, x = 3367.6, y = -3379.8 },
        { id = 8968, level = 60, min = 58, races = 255, classes = 0, title = "The Left Piece of Lord Valthalak's Amulet", giver = "Bodley", map = 0, x = -7534.8, y = -1212.6 },
        { id = 8991, level = 60, min = 58, races = 255, classes = 0, title = "The Right Piece of Lord Valthalak's Amulet", giver = "Bodley", map = 0, x = -7534.8, y = -1212.6 },
    },
    [289] = { -- Scholomance
        { id = 7629, level = 0, min = 0, races = 0, classes = 0, title = "Imp Delivery", giver = "Gorzeeki Wildeyes" }, -- NEW, giver zone: ?
        { id = 7647, level = 0, min = 0, races = 0, classes = 0, title = "Judgment and Redemption", giver = "?" }, -- NEW, giver zone: ?
        { id = 8258, level = 0, min = 0, races = 0, classes = 0, title = "The Darkreaver Menace", giver = "Sagorne Creststrider" }, -- NEW, giver zone: Orgrimmar
        { id = 838, level = 55, min = 0, races = 178, classes = 0, title = "Scholomance", giver = "High Executor Derrington" }, -- NEW, giver zone: Tirisfal Glades (The Bulwark)
        { id = 5533, level = 55, min = 0, races = 77, classes = 0, title = "Scholomance", giver = "Commander Ashlam Valorfist" }, -- NEW, giver zone: Western Plaguelands (Chillwind Camp)
        { id = 964, level = 57, min = 55, races = 178, classes = 0, title = "Skeletal Fragments", giver = "Apothecary Dithers" }, -- NEW, giver zone: Tirisfal Glades (The Bulwark)
        { id = 5514, level = 57, min = 55, races = 178, classes = 0, title = "Mold Rhymes With...", giver = "Apothecary Dithers" }, -- NEW, giver zone: Tirisfal Glades (The Bulwark)
        { id = 5537, level = 57, min = 55, races = 77, classes = 0, title = "Skeletal Fragments", giver = "Alchemist Arbington" }, -- NEW, giver zone: Western Plaguelands (Chillwind Camp)
        { id = 5538, level = 57, min = 55, races = 77, classes = 0, title = "Mold Rhymes With...", giver = "Alchemist Arbington" }, -- NEW, giver zone: Western Plaguelands (Chillwind Camp)
        { id = 5801, level = 57, min = 55, races = 77, classes = 0, title = "Fire Plume Forged", giver = "Krinkle Goodsteel" }, -- NEW, giver zone: Tanaris (Gadgetzan)
        { id = 5802, level = 57, min = 55, races = 178, classes = 0, title = "Fire Plume Forged", giver = "Krinkle Goodsteel" }, -- NEW, giver zone: Tanaris (Gadgetzan)
        { id = 5529, level = 58, min = 55, races = 255, classes = 0, title = "Plagued Hatchlings", giver = "Betina Bigglezink", map = 0, x = 2260.1, y = -5339.0 },
        { id = 4771, level = 60, min = 57, races = 255, classes = 0, title = "Dawn's Gambit", giver = "Betina Bigglezink", map = 0, x = 2260.1, y = -5339.0 },
        { id = 5341, level = 60, min = 52, races = 178, classes = 0, title = "Barov Family Fortune", giver = "Alexi Barov", map = 0, x = 1680.5, y = -719.8 },
        { id = 5342, level = 60, min = 52, races = 178, classes = 0, title = "The Last Barov", giver = "Alexi Barov" }, -- NEW, giver zone: Tirisfal Glades (The Bulwark)
        { id = 5343, level = 60, min = 52, races = 77, classes = 0, title = "Barov Family Fortune", giver = "Weldon Barov", map = 0, x = 966.4, y = -1451.7 },
        { id = 5344, level = 60, min = 52, races = 77, classes = 0, title = "The Last Barov", giver = "Weldon Barov" }, -- NEW, giver zone: Western Plaguelands (Chillwind Camp)
        { id = 5382, level = 60, min = 55, races = 255, classes = 0, title = "Doctor Theolen Krastinov, the Butcher", giver = "Eva Sarkhoff", map = 0, x = 1253.5, y = -2602.6 },
        { id = 5384, level = 60, min = 55, races = 255, classes = 0, title = "Kirtonos the Herald", giver = "Eva Sarkhoff", map = 0, x = 1253.5, y = -2602.6 },
        { id = 5466, level = 60, min = 57, races = 255, classes = 0, title = "The Lich, Ras Frostwhisper", giver = "Magistrate Marduke", map = 0, x = 1242.0, y = -2617.7 },
        { id = 5505, level = 60, min = 55, races = 77, classes = 0, title = "The Key to Scholomance", giver = "Alchemist Arbington" }, -- NEW, giver zone: Western Plaguelands (Chillwind Camp)
        { id = 5511, level = 60, min = 55, races = 178, classes = 0, title = "The Key to Scholomance", giver = "Apothecary Dithers" }, -- NEW, giver zone: Tirisfal Glades (The Bulwark)
        { id = 5515, level = 60, min = 55, races = 255, classes = 0, title = "Krastinov's Bag of Horrors", giver = "Eva Sarkhoff", map = 0, x = 1253.5, y = -2602.6 },
        { id = 5531, level = 60, min = 57, races = 255, classes = 0, title = "Betina Bigglezink", giver = "Leonid Barthalomew the Revered", map = 0, x = 2307.2, y = -5348.9 },
        { id = 5803, level = 60, min = 55, races = 77, classes = 0, title = "Araj's Scarab", giver = "?" }, -- NEW, giver zone: ?
        { id = 5804, level = 60, min = 55, races = 178, classes = 0, title = "Araj's Scarab", giver = "?" }, -- NEW, giver zone: ?
        { id = 8969, level = 60, min = 58, races = 255, classes = 0, title = "The Left Piece of Lord Valthalak's Amulet", giver = "Bodley", map = 0, x = -7534.8, y = -1212.6 },
        { id = 8992, level = 60, min = 58, races = 255, classes = 0, title = "The Right Piece of Lord Valthalak's Amulet", giver = "Bodley", map = 0, x = -7534.8, y = -1212.6 },
    },
}
