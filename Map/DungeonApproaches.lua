-- Outer entrances of instances whose portal is hidden (cave, mountain, building), used for the dotted
-- line on the world map (Map/MapExtras.lua). [instanceMap] = { { uiMapID, x, y (0-1), hint }, ... }
-- Hints are kept short; the ring marks the spot. Sources: HandyNotes_DungeonLocations (Classic), warcraft.wiki.gg.
-- Converted continent coords are accurate to +-1-2; Maraudon is the least certain - verify in game.
local _, ns = ...
local L = ns.L

ns.DUNGEON_APPROACHES = {
    [43] = { { 1413, 0.4597, 0.3634, L["Cave above oasis"] } },                -- Wailing Caverns
    [36] = { { 1436, 0.4257, 0.7171, L["Moonbrook mine"] } },         -- The Deadmines
    [48] = { { 1440, 0.1400, 0.1310, L["Shore ruins"] } },           -- Blackfathom Deeps
    [90] = { { 1426, 0.2446, 0.3981, L["Gate"] } },                  -- Gnomeregan
    [47] = { { 1413, 0.4189, 0.8950, L["Thorn thicket"] } },          -- Razorfen Kraul
    [129] = { { 1413, 0.4913, 0.9348, L["Thorn hill"] } },  -- Razorfen Downs
    [70] = {                                                                       -- Uldaman
        { 1418, 0.4453, 0.1212, L["Front entrance"] },
        { 1418, 0.6505, 0.4337, L["Back entrance"] },
    },
    [189] = { { 1420, 0.8530, 0.3220, L["Courtyard"] } },    -- Scarlet Monastery
    [349] = {                                                                      -- Maraudon (uncertain)
        { 1443, 0.2910, 0.6250, L["Stone door"] },
        { 1443, 0.3016, 0.5462, L["Purple"] },
        { 1443, 0.3600, 0.6430, L["Orange"] },
    },
    [429] = {                                                                      -- Dire Maul
        { 1444, 0.5911, 0.4328, L["Path up"] },
        { 1444, 0.7706, 0.3695, L["Back door (key)"] },                  -- tunnel under Lariss Pavilion
    },
    [109] = { { 1435, 0.6950, 0.5250, L["Temple in the lake"] } },           -- Sunken Temple
    [329] = {                                                                      -- Stratholme
        { 1423, 0.2930, 0.1680, L["Main gate"] },
        { 1423, 0.4300, 0.1800, L["Side gate (key)"] },
    },
    [389] = { { 1454, 0.5240, 0.5800, L["Cleft of Shadow"] } },      -- Ragefire Chasm
    [249] = { { 1445, 0.5290, 0.7770, L["Cave"] } },                    -- Onyxia's Lair
}
-- Blackrock Depths, Blackrock Spire, Molten Core and Blackwing Lair share the entrances
local BLACKROCK = {
    { 1427, 0.3470, 0.8600, L["Blackrock Mountain"] },
    { 1428, 0.2994, 0.4778, L["Blackrock Mountain"] },
}
for _, id in ipairs({ 229, 230, 409, 469 }) do ns.DUNGEON_APPROACHES[id] = BLACKROCK end
