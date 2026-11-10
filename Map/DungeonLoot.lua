-- Boss loot per instance for the dungeon panel (Map/DungeonPanel.lua). Forever has no Adventure Guide,
-- so loot tables aren't in the client: starting data comes from AtlasLootClassic (classic drop
-- lists, see CREDITS.txt) and is shown as "unconfirmed".
-- [instanceID] = { [encounterID or "rare:<npcID>"] = { itemID, ... } } - encounter IDs as in
-- Quests/DungeonBosses.lua, rares as in Map/DungeonPinData.lua.
local _, ns = ...

ns.DUNGEON_LOOT = {
    [43] = { -- Wailing Caverns
        [585] = { 10412, 5404, 6446 },          -- Lady Anacondra
        [586] = { 6460, 10410, 6465 },          -- Lord Cobrahn
        [587] = { 13245, 6447 },                -- Kresh
        [588] = { 6472, 6473 },                 -- Lord Pythas
        [589] = { 6449, 6448 },                 -- Skum
        [590] = { 6469, 5970, 10411, 6459 },    -- Lord Serpentis
        [591] = { 6630, 6631, 6629 },           -- Verdan the Everliving
        [592] = { 6461, 6627, 6463, 10441 },    -- Mutanus the Devourer
        ["rare:5912"] = { 5243, 6632 },         -- Deviate Faerie Dragon
    },
}
