-- Boss and rare pins on the dungeon maps, placed in game with /mui pins (Map/DungeonPins.lua) and
-- copied here from MeredanUIDB.dungeonPins: [instanceMapID] = { { kind, id, floor, x, y }, ... },
-- kind "boss" (id = DungeonEncounter ID) or "rare" (id = NPC ID, name); x/y relative to the map art.
local _, ns = ...

ns.DUNGEON_PINS = {}
