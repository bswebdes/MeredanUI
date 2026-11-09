-- World map extras (WoW Forever):
--   1. Reveal whole map: Blizzard only draws explored areas (C_MapExplorationInfo); mUI draws the rest
--      from Map/MapRevealData.lua (same tiling as MapExplorationPinMixin:RefreshOverlays). ns.db.mapReveal.
--   2. Level range on the zone name on hover, colored by player level (like AreaLabelFrameMixin; Forever
--      returns no levels from C_Map.GetMapLevels, hence our own table). ns.db.mapZoneLevels.
--   3. Dungeon entrance pins (see below).
local _, ns = ...

-- Level ranges per uiMapID (Classic Era IDs, same in Forever; cities have none). Sources: warcraft.wiki.gg
-- "Zones by level (original)", Forever minimum levels from warcrafttavern.com (Searing Gorge from 43).
-- Shen'dralas: sources disagree (40 ... 45-55), 40-50 as a compromise.
local ZONE_LEVELS = {
    -- Kalimdor
    [1411] = { 1, 10 },  -- Durotar
    [1412] = { 1, 10 },  -- Mulgore
    [1413] = { 10, 25 }, -- The Barrens
    [1438] = { 1, 10 },  -- Teldrassil
    [1439] = { 10, 20 }, -- Darkshore
    [1440] = { 18, 30 }, -- Ashenvale
    [1441] = { 25, 35 }, -- Thousand Needles
    [1442] = { 15, 27 }, -- Stonetalon Mountains
    [1443] = { 30, 40 }, -- Desolace
    [1444] = { 40, 50 }, -- Feralas
    [1445] = { 35, 45 }, -- Dustwallow Marsh
    [1446] = { 40, 50 }, -- Tanaris
    [1447] = { 45, 55 }, -- Azshara
    [1448] = { 48, 55 }, -- Felwood
    [1449] = { 48, 55 }, -- Un'Goro Crater
    [1450] = { 55, 60 }, -- Moonglade
    [1451] = { 55, 60 }, -- Silithus
    [1452] = { 53, 60 }, -- Winterspring
    [2482] = { 60, 60 }, -- Hyjal (Forever, endgame)
    [2652] = { 40, 50 }, -- Shen'dralas (Forever, uncertain)
    [2521] = { 1, 12 },  -- Zephras Isle (Forever, starting zone)
    [2665] = { 1, 12 },  -- Zephras Isle (second map)
    -- Eastern Kingdoms
    [1416] = { 30, 40 }, -- Alterac Mountains
    [1417] = { 30, 40 }, -- Arathi Highlands
    [1418] = { 35, 45 }, -- Badlands
    [1419] = { 45, 55 }, -- Blasted Lands
    [1420] = { 1, 10 },  -- Tirisfal Glades
    [1421] = { 10, 20 }, -- Silverpine Forest
    [1422] = { 51, 58 }, -- Western Plaguelands
    [1423] = { 53, 60 }, -- Eastern Plaguelands
    [1424] = { 20, 30 }, -- Hillsbrad Foothills
    [1425] = { 40, 50 }, -- The Hinterlands
    [1426] = { 1, 10 },  -- Dun Morogh
    [1427] = { 43, 50 }, -- Searing Gorge
    [1428] = { 50, 58 }, -- Burning Steppes
    [1429] = { 1, 10 },  -- Elwynn Forest
    [1430] = { 55, 60 }, -- Deadwind Pass
    [1431] = { 18, 30 }, -- Duskwood
    [1432] = { 10, 20 }, -- Loch Modan
    [1433] = { 15, 25 }, -- Redridge Mountains
    [1434] = { 30, 45 }, -- Stranglethorn Vale
    [1435] = { 35, 45 }, -- Swamp of Sorrows
    [1436] = { 10, 20 }, -- Westfall
    [1437] = { 20, 30 }, -- Wetlands
    [2548] = { 35, 45 }, -- Riverglades (Forever)
}

-- Faction per zone (classic): name blue (Alliance), red (Horde), yellow (contested), crest in front.
-- Unlisted (Zephras Isle, battlegrounds) = Blizzard's default color.
local ALLIANCE, HORDE, BOTH = "Alliance", "Horde", "both"
local ZONE_FACTION = {
    [1429] = ALLIANCE, [1426] = ALLIANCE, [1438] = ALLIANCE, [1436] = ALLIANCE, [1432] = ALLIANCE,
    [1439] = ALLIANCE, [1433] = ALLIANCE, [1431] = ALLIANCE, [1437] = ALLIANCE,
    [1453] = ALLIANCE, [1455] = ALLIANCE, [1457] = ALLIANCE,
    [1411] = HORDE, [1412] = HORDE, [1420] = HORDE, [1413] = HORDE, [1421] = HORDE,
    [1454] = HORDE, [1456] = HORDE, [1458] = HORDE,
}
for id in pairs(ZONE_LEVELS) do ZONE_FACTION[id] = ZONE_FACTION[id] or BOTH end
local FACTION_COLOR = {
    [ALLIANCE] = CreateColor(0.35, 0.6, 1), [HORDE] = CreateColor(1, 0.3, 0.25), [BOTH] = CreateColor(1, 0.82, 0),
}
local FACTION_ATLAS = { [ALLIANCE] = { "alliancesymbol" }, [HORDE] = { "hordesymbol" }, [BOTH] = { "alliancesymbol", "hordesymbol" } }

function ns.ZoneLevels(mapID)
    local low, high = 0, 0
    if C_Map.GetMapLevels then low, high = C_Map.GetMapLevels(mapID) end
    if (low or 0) > 0 and (high or 0) > 0 then return low, high end
    local entry = ZONE_LEVELS[mapID]
    if entry then return entry[1], entry[2] end
end

-- Instance levels from Blizzard's group finder (C_LFGList activities carry mapID and suggested levels).
-- Multiple activities per instance (Dire Maul wings, Lower/Upper Blackrock Spire) are merged into one
-- range. Built once, then cached.
local instanceLevels
function ns.InstanceLevels(mapID)
    if not instanceLevels then
        instanceLevels = {}
        if C_LFGList and C_LFGList.GetAvailableCategories then
            for _, category in ipairs(C_LFGList.GetAvailableCategories() or {}) do
                for _, activity in ipairs(C_LFGList.GetAvailableActivities(category) or {}) do
                    local info = C_LFGList.GetActivityInfoTable(activity)
                    local low, high = info and info.minLevelSuggestion, info and info.maxLevelSuggestion
                    if info and info.mapID and info.mapID > 0 and low and low > 0 and high and high > 0 then
                        local entry = instanceLevels[info.mapID]
                        if entry then
                            entry[1], entry[2] = math.min(entry[1], low), math.max(entry[2], high)
                        else
                            instanceLevels[info.mapID] = { low, high }
                        end
                    end
                end
            end
        end
    end
    local entry = instanceLevels[mapID]
    if entry then return entry[1], entry[2] end
end

-- Blizzard-style color for a level range (gray = too easy ... red = too hard)
local function RangeColor(low, high)
    local level = UnitLevel("player")
    local color
    if level < low then
        color = GetQuestDifficultyColor(low)
    elseif level > high then
        color = GetQuestDifficultyColor(high - 2)
    else
        color = QuestDifficultyColors and QuestDifficultyColors.difficult
    end
    return color
end
ns.LevelRangeColor = RangeColor

-- " (18-30)" colored like Blizzard (gray = too easy ... red = too hard)
function ns.ZoneLevelText(mapID)
    local low, high = ns.ZoneLevels(mapID)
    if not low then return end
    local level = UnitLevel("player")
    local color
    if level < low then
        color = GetQuestDifficultyColor(low)
    elseif level > high then
        color = GetQuestDifficultyColor(high - 2) -- like Blizzard: far below no longer yellow
    else
        color = QuestDifficultyColors and QuestDifficultyColors.difficult
    end
    local range = low == high and tostring(low) or (low .. "–" .. high)
    return color and (RGBTableToColorCode(color) .. " (" .. range .. ")" .. FONT_COLOR_CODE_CLOSE) or (" (" .. range .. ")")
end

-- 1. Reveal -------------------------------------------------------------------------------------

local function SplitIDs(text)
    local ids = {}
    for id in text:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
    return ids
end

local function RefreshReveal(canvas)
    local frame = canvas.muiReveal
    for _, tex in ipairs(frame.textures) do tex:Hide() end
    frame.used = 0
    if ns.db.mapReveal == false then return end
    local mapID = canvas:GetMapID()
    local data = mapID and ns.MAP_REVEAL_DATA and ns.MAP_REVEAL_DATA[mapID]
    local layers = data and C_Map.GetMapArtLayers(mapID)
    if not (layers and layers[1]) then return end
    local explored = {}
    for _, info in ipairs(C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}) do
        for _, id in ipairs(info.fileDataIDs or {}) do explored[id] = true end
    end
    local tileW, tileH = layers[1].tileWidth, layers[1].tileHeight
    frame:SetFrameLevel(canvas:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_MAP_EXPLORATION"))
    for _, overlay in ipairs(data) do
        local width, height, offsetX, offsetY = overlay[1], overlay[2], overlay[3], overlay[4]
        overlay.ids = overlay.ids or SplitIDs(overlay[5])
        if not explored[overlay.ids[1]] then
            local wide, tall = math.ceil(width / tileW), math.ceil(height / tileH)
            for j = 1, tall do
                local pixelH, fileH = tileH, tileH
                if j == tall then
                    pixelH = height % tileH
                    if pixelH == 0 then pixelH = tileH end
                    fileH = 16
                    while fileH < pixelH do fileH = fileH * 2 end
                end
                for k = 1, wide do
                    local pixelW, fileW = tileW, tileW
                    if k == wide then
                        pixelW = width % tileW
                        if pixelW == 0 then pixelW = tileW end
                        fileW = 16
                        while fileW < pixelW do fileW = fileW * 2 end
                    end
                    local id = overlay.ids[(j - 1) * wide + k]
                    if id then
                        frame.used = frame.used + 1
                        local tex = frame.textures[frame.used]
                        if not tex then
                            tex = frame:CreateTexture(nil, "ARTWORK")
                            frame.textures[frame.used] = tex
                            canvas:AddMaskableTexture(tex)
                        end
                        tex:SetSize(pixelW, pixelH)
                        tex:SetTexCoord(0, pixelW / fileW, 0, pixelH / fileH)
                        tex:ClearAllPoints()
                        tex:SetPoint("TOPLEFT", offsetX + tileW * (k - 1), -(offsetY + tileH * (j - 1)))
                        tex:SetTexture(id, nil, nil, "TRILINEAR")
                        tex:Show()
                    end
                end
            end
        end
    end
end

-- 2. Levels on zone names ----------------------------------------------------------------------

local function PatchAreaLabel(canvas, label)
    -- faction crests left of the name: real textures, aligned to the line's center
    label.muiFaction = {}
    for i = 1, 2 do
        local icon = label:CreateTexture(nil, "OVERLAY")
        icon:SetSize(30, 30) -- 22 was barely visible
        icon:Hide()
        label.muiFaction[i] = icon
    end
    label:SetScript("OnUpdate", function(self)
        AreaLabelFrameMixin.OnUpdate(self)
        for _, icon in ipairs(self.muiFaction) do icon:Hide() end
        if ns.db.mapZoneLevels == false or not canvas:IsCanvasMouseFocus() then return end
        local info = self.labelInfoByType[MAP_AREA_LABEL_TYPE.AREA_NAME]
        if not (info and info.name) then return end
        local x, y = canvas:GetNormalizedCursorPosition()
        local at = C_Map.GetMapInfoAtPosition(canvas:GetMapID(), x, y)
        if not (at and at.mapID ~= canvas:GetMapID()) then return end
        if not info.name:find("|c") then -- Blizzard supplied no levels (Forever)
            local text = ns.ZoneLevelText(at.mapID)
            if text then info.name = info.name .. text end
        end
        local faction = ZONE_FACTION[at.mapID]
        if faction then
            info.nameColor = FACTION_COLOR[faction]
            self.dirty = true
        end
        self.dirty = true
        self:EvaluateLabels()
        if faction then
            local half = (self.Name:GetStringWidth() or 0) / 2
            local prev
            for i, atlas in ipairs(FACTION_ATLAS[faction]) do
                local icon = self.muiFaction[i]
                icon:SetAtlas(atlas)
                icon:ClearAllPoints()
                if prev then
                    icon:SetPoint("RIGHT", prev, "LEFT", -2, 0)
                else
                    icon:SetPoint("RIGHT", self.Name, "CENTER", -half - 6, 0)
                end
                icon:Show()
                prev = icon
            end
        end
    end)
end

-- 3. Dungeon entrances --------------------------------------------------------------------------
-- Blizzard takes them from the Encounter Journal (C_EncounterJournal), which is disabled in Forever, so
-- the "Show dungeon entrances" option did nothing. Entrances from Blizzard's map table (Forever 1.60.1,
-- corpse point = ghost run target at the entrance): { instanceMap, continent, worldX, worldY, raid, name }.
-- Swirl like Retail: atlas "dungeon" (blue) or "raid" (green). New Forever instances have no point yet.
local ENTRANCES = {
    { 33, 0, -231.0, 1571.6, false, "Shadowfang Keep" },
    { 34, 0, -8762.4, 848.0, false, "Stormwind Stockade" },
    { 36, 0, -11207.8, 1681.2, false, "Deadmines" },
    { 43, 1, -751.1, -2209.2, false, "Wailing Caverns" },
    { 47, 1, -4459.4, -1660.2, false, "Razorfen Kraul" },
    { 48, 1, 4249.1, 748.4, false, "Blackfathom Deeps" },
    { 70, 0, -6060.2, -2955.0, false, "Uldaman" },
    { 90, 0, -5162.7, 931.6, false, "Gnomeregan" },
    { 109, 0, -10170.1, -3996.0, false, "Sunken Temple" },
    { 129, 1, -4662.9, -2535.9, false, "Razorfen Downs" },
    { 189, 0, 2892.2, -811.3, false, "Scarlet Monastery" },
    { 209, 1, -6790.6, -2891.3, false, "Zul'Farrak" },
    { 229, 0, -7522.5, -1233.0, false, "Blackrock Spire" },
    { 230, 0, -7178.1, -928.6, false, "Blackrock Depths" },
    { 249, 1, -4753.3, -3752.4, true, "Onyxia's Lair" },
    { 289, 0, 1274.8, -2552.6, false, "Scholomance" },
    { 309, 0, -11916.1, -1224.6, true, "Zul'Gurub" },
    { 329, 0, 3392.3, -3378.5, false, "Stratholme" },
    { 349, 1, -1432.7, 2925.0, false, "Maraudon" },
    { 389, 1, 1816.8, -4423.4, false, "Ragefire Chasm" },
    { 409, 0, -7510.6, -1036.7, true, "Molten Core" },
    { 429, 1, -3908.0, 1130.0, false, "Dire Maul" },
    { 469, 0, -7663.4, -1218.7, true, "Blackwing Lair" },
    { 509, 1, -8114.5, 1526.4, true, "Ruins of Ahn'Qiraj" },
    { 531, 1, -8111.7, 1526.8, true, "Ahn'Qiraj Temple" },
}
-- Forever's new instances have no corpse point in the game data, so their entrances are learned:
-- right before the loading screen into an instance (PLAYER_LEAVING_WORLD) the player still stands at
-- the portal. That spot is saved account-wide (MeredanUIDB.entrances[instanceMap]) and shown like
-- the built-in ones. Learned spots can later be copied into ENTRANCES above for everyone.
local KNOWN = {}
for _, e in ipairs(ENTRANCES) do KNOWN[e[1]] = true end
local lastOutside -- { continent, x, y, time } of the last spot before a loading screen

-- Approximate entrances of the new instances from community guides (zone map %, uiMapID), shown
-- until the real spot is learned. { instanceMap, uiMapID, x, y, raid, name }
local APPROX = {
    { 3065, 1455, 43.5, 52.0, false, "The Hall of Thanes" },        -- Old Ironforge, left of the throne room
    { 2999, 1420, 62.0, 67.0, false, "Ruins of Lordaeron" },        -- east side of the Undercity courtyard (rough)
    { 2998, 1437, 53.9, 65.4, false, "Excavation Site: Wetlands" }, -- start of the path left of Thelgen Rock
    { 2959, 1416, 8.8, 59.6, false, "City of Dalaran" },            -- sewer gate, northwest of the city
    { 2970, 1434, 21.4, 27.8, false, "The Drowned City" },          -- underwater, west of Vile Reef
    { 2994, 1445, 75.3, 14.1, false, "Alcaz Prison" },              -- tower basement on Alcaz Island
    { 2974, 1447, 38.4, 32.6, false, "Blackmaw Hold" },             -- tunnel in northern Azshara
    { 3001, 1449, 48.1, 6.1, false, "Shaper's Terrace" },           -- hill above Marshal's Refuge (unconfirmed)
}
local approxWorld -- converted lazily (map API needs the world loaded)

local function ApproxEntrances()
    if approxWorld then return approxWorld end
    approxWorld = {}
    for _, a in ipairs(APPROX) do
        local continent, world = C_Map.GetWorldPosFromMapPos(a[2], CreateVector2D(a[3] / 100, a[4] / 100))
        if continent and world then
            local x, y = world:GetXY()
            approxWorld[#approxWorld + 1] = { a[1], continent, x, y, a[5], a[6], true }
        end
    end
    local list = approxWorld
    if #list == 0 then approxWorld = nil end -- map data not ready yet: try again next time
    return list
end

local function AllEntrances()
    local learned = MeredanUIDB and MeredanUIDB.entrances or {}
    local list = {}
    for _, e in ipairs(ENTRANCES) do list[#list + 1] = e end
    for instance, e in pairs(learned) do
        if not KNOWN[instance] then list[#list + 1] = { instance, e[1], e[2], e[3], e[4], e[5] } end
    end
    for _, e in ipairs(ApproxEntrances()) do
        if not KNOWN[e[1]] and not learned[e[1]] then list[#list + 1] = e end
    end
    return list
end

ns:On("PLAYER_LEAVING_WORLD", function()
    lastOutside = nil
    if IsInInstance() then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local continent, world = C_Map.GetWorldPosFromMapPos(mapID, pos)
    if not (continent and world) then return end
    local x, y = world:GetXY()
    lastOutside = { continent, x, y, GetTime() }
end)

ns:On("PLAYER_ENTERING_WORLD", function()
    local spot = lastOutside
    lastOutside = nil
    if not spot or GetTime() - spot[4] > 120 or not MeredanUIDB then return end
    local inInstance, kind = IsInInstance()
    if not inInstance or (kind ~= "party" and kind ~= "raid") then return end
    local name, _, _, _, _, _, _, instance = GetInstanceInfo()
    if not instance or KNOWN[instance] then return end
    MeredanUIDB.entrances = MeredanUIDB.entrances or {}
    if MeredanUIDB.entrances[instance] then return end
    MeredanUIDB.entrances[instance] = { spot[1], spot[2], spot[3], kind == "raid", name or "" }
    if DevLog then DevLog("MeredanUI", ("Dungeon entrance learned: %s (%d) at %d, %.1f, %.1f"):format(name or "?", instance, spot[1], spot[2], spot[3])) end
end)

-- size per map level: much larger on the zone map so the entrance stands out
local PIN_SIZE = { continent = 22, zone = 36 }

-- Approaches to the portal: many portals lie deep in caves/mountains. Outer entrances per instance map:
-- { uiMapID, x, y (0-1), hint }. Hovering the swirl on the zone map shows an accent ring with a dot at
-- each entrance and the hint below. No connecting line: a straight line cannot show the real path.
local APPROACHES = ns.DUNGEON_APPROACHES or {}
local ARROW_SIZE = 16 -- ring at the entrance

local EntranceProvider = CreateFromMixins(MapCanvasDataProviderMixin)

function EntranceProvider:HidePaths()
    if not self.path then return end
    for _, mark in ipairs(self.path.marks) do mark:Hide() end
end

function EntranceProvider:ShowPaths(pin)
    self:HidePaths()
    local map = self:GetMap()
    local mapID = map:GetMapID()
    local list = APPROACHES[pin.instance]
    if not list then return end
    local child = map:GetCanvas()
    local w, h, scale = child:GetWidth(), child:GetHeight(), map:GetCanvasScale()
    if not self.path then
        self.path = CreateFrame("Frame", nil, child)
        self.path:SetAllPoints()
        self.path.marks = {}
    end
    self.path:SetFrameLevel(pin:GetFrameLevel() - 1)
    local marks = 0
    local hints = {}
    for _, a in ipairs(list) do
        if a[1] == mapID then
            -- distance in screen pixels (map pixels x zoom) so the threshold is zoom-independent
            local ax, ay, px, py = a[2] * w, a[3] * h, pin.x * w, pin.y * h
            local length = math.sqrt(((px - ax) * scale) ^ 2 + ((py - ay) * scale) ^ 2)
            if length >= 30 then -- otherwise the entrance is practically at the portal: no path needed
            -- ring at the entrance, counter-scaled (same size at every zoom)
            marks = marks + 1
            local mark = self.path.marks[marks]
            if not mark then
                mark = CreateFrame("Frame", nil, self.path)
                mark:SetSize(ARROW_SIZE, ARROW_SIZE)
                mark.shadow = mark:CreateTexture(nil, "ARTWORK", nil, 1)
                mark.shadow:SetTexture(ns.MEDIA .. "Icons\\Entrance")
                mark.shadow:SetVertexColor(0, 0, 0, 0.9)
                mark.shadow:SetSize(ARROW_SIZE + 4, ARROW_SIZE + 4)
                mark.shadow:SetPoint("CENTER")
                mark.arrow = mark:CreateTexture(nil, "ARTWORK", nil, 2)
                mark.arrow:SetTexture(ns.MEDIA .. "Icons\\Entrance")
                mark.arrow:SetVertexColor(unpack(ns.UI.ACCENT))
                mark.arrow:SetAllPoints()
                mark.text = ns.CreateText(mark, 12, "CENTER", "OUTLINE")
                mark.text:SetPoint("TOP", mark, "BOTTOM", 0, -3)
                mark.text:SetWidth(120) -- narrow wrap; keep hints short, no single word wider than ~120 px
                mark.text:SetWordWrap(true)
                mark.text:SetTextColor(unpack(ns.UI.ACCENT))
                self.path.marks[marks] = mark
            end
            -- ring with dot = "enter here" (arrows looked like signposts pointing elsewhere)
            mark.text:SetText(a[4] or "")
            mark:SetScale(1 / scale)
            mark:ClearAllPoints()
            mark:SetPoint("CENTER", child, "TOPLEFT", ax * scale, -ay * scale)
            mark:Show()
            if a[4] then hints[#hints + 1] = a[4] end
            end
        end
    end
    return hints
end

function EntranceProvider:RemoveAllData()
    self:HidePaths()
    for _, pin in ipairs(self.pins or {}) do pin:Hide() end
    self.used = 0
end

-- Pins live in the canvas (zoom with it); counter-scaling keeps them a constant size
function EntranceProvider:Place()
    local map = self:GetMap()
    local child = map:GetCanvas()
    local scale = map:GetCanvasScale()
    for i = 1, self.used or 0 do
        local pin = self.pins[i]
        pin:SetScale(1 / scale)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", child, "TOPLEFT", pin.x * child:GetWidth() * scale, -pin.y * child:GetHeight() * scale)
    end
end

function EntranceProvider:RefreshAllData()
    self:RemoveAllData()
    if not GetCVarBool("showDungeonEntrancesOnMap") then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    if not mapID then return end
    -- continent level and below only; too cluttered on the Azeroth map
    local info = C_Map.GetMapInfo(mapID)
    if not info or info.mapType <= Enum.UIMapType.World then return end
    self.pins = self.pins or {}
    local level = map:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
    for _, e in ipairs(AllEntrances()) do
        local _, pos = C_Map.GetMapPosFromWorldPos(e[2], CreateVector2D(e[3], e[4]), mapID)
        local x, y
        if pos then x, y = pos:GetXY() end -- not "pos and pos:GetXY()": that yields only one value
        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            self.used = self.used + 1
            local pin = self.pins[self.used]
            if not pin then
                pin = CreateFrame("Frame", nil, map:GetCanvas())
                pin.icon = pin:CreateTexture(nil, "ARTWORK")
                pin.icon:SetAllPoints()
                pin:EnableMouse(true)
                local provider = self
                -- left-click opens the dungeon map (Map/DungeonMap.lua), right-click: zone up like the map
                pin:SetScript("OnMouseUp", function(pinFrame, button)
                    if button == "LeftButton" and ns.OpenDungeonMap and ns.OpenDungeonMap(pinFrame.instance) then return end
                    if button == "RightButton" then provider:GetMap():NavigateToParentMap() end
                end)
                pin:SetScript("OnEnter", function(self)
                    -- above left: the entrance hints sit below their rings
                    GameTooltip:SetOwner(self, "ANCHOR_NONE")
                    GameTooltip:ClearAllPoints()
                    GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", -4, 4)
                    GameTooltip:SetText(self.name, 1, 1, 1)
                    local kind = self.raid and (RAID or "Raid") or ns.L["Dungeon"]
                    local low, high = ns.InstanceLevels(self.instance)
                    if low then
                        local color = RangeColor(low, high)
                        local range = low == high and tostring(low) or (low .. "–" .. high)
                        GameTooltip:AddDoubleLine(kind, ns.L["Level %s"]:format(range), 0.6, 0.59, 0.56,
                            color and color.r or 1, color and color.g or 1, color and color.b or 1)
                    else
                        GameTooltip:AddLine(kind, 0.6, 0.59, 0.56)
                    end
                    if ns.DungeonMapView and ns.DungeonMapView.Has(self.instance) then
                        GameTooltip:AddLine(ns.L["Click: dungeon map"], 0.56, 0.8, 0.71)
                    end
                    if self.approx then
                        GameTooltip:AddLine(ns.L["Approximate entrance (community info) - corrected once you enter."], 0.85, 0.71, 0.42, true)
                    end
                    -- approach paths only on the zone map
                    local zone = (C_Map.GetMapInfo(provider:GetMap():GetMapID()) or {}).mapType == Enum.UIMapType.Zone
                    local hints = zone and provider:ShowPaths(self)
                    if hints and #hints > 0 then
                        GameTooltip:AddLine(ns.L["Entrances marked on the map."], 0.56, 0.8, 0.71, true)
                    end
                    GameTooltip:Show()
                end)
                pin:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                    provider:HidePaths()
                end)
                self.pins[self.used] = pin
            end
            local size = info.mapType >= Enum.UIMapType.Zone and PIN_SIZE.zone or PIN_SIZE.continent
            pin:SetSize(size, size)
            pin:SetFrameLevel(level)
            pin.icon:SetAtlas(e[5] and "raid" or "dungeon")
            pin.x, pin.y, pin.raid, pin.instance, pin.approx = x, y, e[5], e[1], e[7]
            pin.name = (GetRealZoneText and GetRealZoneText(e[1])) or e[6]
            if not pin.name or pin.name == "" then pin.name = e[6] end
            pin:Show()
        end
    end
    self:Place()
end

function EntranceProvider:OnCanvasScaleChanged() self:Place() end
function EntranceProvider:OnCanvasSizeChanged() self:Place() end

-- Attach to a map canvas (Map/WorldMap.lua); areaLabelProvider = Blizzard's area label provider
function ns.AttachMapExtras(canvas, areaLabelProvider)
    local frame = CreateFrame("Frame", nil, canvas:GetCanvas())
    frame:SetAllPoints()
    frame.textures, frame.used = {}, 0
    canvas.muiReveal = frame
    canvas:AddDataProvider(CreateFromMixins(EntranceProvider))
    canvas.RefreshReveal = RefreshReveal
    if areaLabelProvider and areaLabelProvider.Label then PatchAreaLabel(canvas, areaLabelProvider.Label) end
    local events = CreateFrame("Frame")
    events:RegisterEvent("MAP_EXPLORATION_UPDATED")
    events:SetScript("OnEvent", function() if canvas:IsVisible() then RefreshReveal(canvas) end end)
end
