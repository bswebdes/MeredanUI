-- Weltkarte-Extras (WoW Forever, Komfort; Benny 2026-11-08):
--   1. Ganze Karte aufdecken: Blizzard zeichnet nur erkundete Flächen (C_MapExplorationInfo); mUI
--      zeichnet die übrigen aus Map/MapRevealData.lua dazu (gleiche Kachel-Logik wie Blizzards
--      MapExplorationPinMixin:RefreshOverlays). Schalter ns.db.mapReveal, im „Anzeigen“-Menü der Karte.
--   2. Stufenbereich am Gebietsnamen beim Drüberfahren, gefärbt nach eigener Stufe (wie Blizzards
--      AreaLabelFrameMixin – Forever liefert aber keine Stufen über C_Map.GetMapLevels, daher eigene
--      Tabelle). Schalter ns.db.mapZoneLevels.
local _, ns = ...

-- Stufenbereiche je uiMapID (Classic-Era-IDs, in Forever gleich; Städte ohne Stufen). Quellen
-- (Recherche 2026-11-08): warcraft.wiki.gg „Zones by level (original)“, Forever-Mindeststufen von
-- warcrafttavern.com/forever/guides/leveling (Sengende Schlucht ab 43), neue Gebiete von
-- warcraft.wiki.gg. Shen'dralas: Quellen uneinig (ab 40 … 45–55) > 40–50 als Mittelweg.
local ZONE_LEVELS = {
    -- Kalimdor
    [1411] = { 1, 10 },  -- Durotar
    [1412] = { 1, 10 },  -- Mulgore
    [1413] = { 10, 25 }, -- Brachland
    [1438] = { 1, 10 },  -- Teldrassil
    [1439] = { 10, 20 }, -- Dunkelküste
    [1440] = { 18, 30 }, -- Eschental
    [1441] = { 25, 35 }, -- Tausend Nadeln
    [1442] = { 15, 27 }, -- Steinkrallengebirge
    [1443] = { 30, 40 }, -- Desolace
    [1444] = { 40, 50 }, -- Feralas
    [1445] = { 35, 45 }, -- Düstermarschen
    [1446] = { 40, 50 }, -- Tanaris
    [1447] = { 45, 55 }, -- Azshara
    [1448] = { 48, 55 }, -- Teufelswald
    [1449] = { 48, 55 }, -- Krater von Un'Goro
    [1450] = { 55, 60 }, -- Mondlichtung
    [1451] = { 55, 60 }, -- Silithus
    [1452] = { 53, 60 }, -- Winterquell
    [2482] = { 60, 60 }, -- Hyjal (Forever, Endgame)
    [2652] = { 40, 50 }, -- Shen'dralas (Forever, unsicher)
    [2521] = { 1, 12 },  -- Zephras Isle (Forever, Startgebiet)
    [2665] = { 1, 12 },  -- Zephras Isle (zweite Karte)
    -- Östliche Königreiche
    [1416] = { 30, 40 }, -- Alteracgebirge
    [1417] = { 30, 40 }, -- Arathihochland
    [1418] = { 35, 45 }, -- Ödland
    [1419] = { 45, 55 }, -- Verwüstete Lande
    [1420] = { 1, 10 },  -- Tirisfal
    [1421] = { 10, 20 }, -- Silberwald
    [1422] = { 51, 58 }, -- Westliche Pestländer
    [1423] = { 53, 60 }, -- Östliche Pestländer
    [1424] = { 20, 30 }, -- Vorgebirge des Hügellands
    [1425] = { 40, 50 }, -- Hinterland
    [1426] = { 1, 10 },  -- Dun Morogh
    [1427] = { 43, 50 }, -- Sengende Schlucht
    [1428] = { 50, 58 }, -- Brennende Steppe
    [1429] = { 1, 10 },  -- Wald von Elwynn
    [1430] = { 55, 60 }, -- Gebirgspass der Totenwinde
    [1431] = { 18, 30 }, -- Dämmerwald
    [1432] = { 10, 20 }, -- Loch Modan
    [1433] = { 15, 25 }, -- Rotkammgebirge
    [1434] = { 30, 45 }, -- Schlingendorntal
    [1435] = { 35, 45 }, -- Sümpfe des Elends
    [1436] = { 10, 20 }, -- Westfall
    [1437] = { 20, 30 }, -- Sumpfland
    [2548] = { 35, 45 }, -- Riverglades (Forever)
}

-- Fraktion je Gebiet (klassisch; Benny 2026-11-08): Name blau (Allianz), rot (Horde), gelb (umkämpft)
-- mit Wappen davor. Nicht eingetragen (Zephras Isle, Schlachtfelder) = Blizzards normale Farbe.
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

-- Stufen von Instanzen aus Blizzards Gruppensuche (C_LFGList-Aktivitäten haben mapID und empfohlene
-- Stufen; Benny 2026-11-08). Mehrere Aktivitäten je Instanz (Düsterbruch-Flügel, Schwarzfelsspitze
-- unten/oben) werden zu einem Bereich zusammengefasst. Einmal gebaut, dann zwischengespeichert.
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

-- Farbe wie Blizzard (grau zu leicht … rot zu schwer) für einen Stufenbereich
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

-- „ (18–30)“ in der Farbe wie Blizzard (grau zu leicht … rot zu schwer)
function ns.ZoneLevelText(mapID)
    local low, high = ns.ZoneLevels(mapID)
    if not low then return end
    local level = UnitLevel("player")
    local color
    if level < low then
        color = GetQuestDifficultyColor(low)
    elseif level > high then
        color = GetQuestDifficultyColor(high - 2) -- wie Blizzard: ganz darunter nicht mehr gelb
    else
        color = QuestDifficultyColors and QuestDifficultyColors.difficult
    end
    local range = low == high and tostring(low) or (low .. "–" .. high)
    return color and (RGBTableToColorCode(color) .. " (" .. range .. ")" .. FONT_COLOR_CODE_CLOSE) or (" (" .. range .. ")")
end

-- 1. Aufdecken ----------------------------------------------------------------------------------

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

-- 2. Stufen am Gebietsnamen -------------------------------------------------------------------

local function PatchAreaLabel(canvas, label)
    -- Wappen links neben dem Namen: echte Bilder, an der Zeilenmitte ausgerichtet
    label.muiFaction = {}
    for i = 1, 2 do
        local icon = label:CreateTexture(nil, "OVERLAY")
        icon:SetSize(30, 30) -- 22 war kaum zu erkennen (Benny 2026-11-08)
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
        if not info.name:find("|c") then -- Blizzard hat keine Stufen geliefert (Forever)
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

-- 3. Dungeon-Eingänge ---------------------------------------------------------------------------
-- Blizzard holt sie aus dem Dungeonkompendium (C_EncounterJournal), das in Forever aus ist > der Haken
-- „Dungeon-Eingänge zeigen“ tat nichts (Benny 2026-11-08). Eingänge aus Blizzards Map-Tabelle (Forever
-- 1.60.1, Corpse-Punkt = Geisterlauf-Ziel am Eingang): { Instanz-Map, Kontinent, Welt-X, Welt-Y, Raid, Name }.
-- Wirbel wie in Retail: Atlas „dungeon“ (blau) bzw. „raid“ (grün). Neue Forever-Instanzen haben dort
-- noch keinen Punkt.
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
-- Größe nach Kartenebene (Benny 2026-11-08): auf der Zonenkarte deutlich größer, damit der Eingang auffällt
local PIN_SIZE = { continent = 22, zone = 36 }

-- Wege zum Portal (Benny 2026-11-08): viele Portale liegen tief in Höhlen/Bergen. Außen-Eingänge je
-- Instanz-Map: { uiMapID, x, y (0–1), Hinweis }. Beim Drüberfahren über den Wirbel auf der Zonenkarte:
-- Salbei-Ring mit Punkt an jedem Eingang, Hinweis darunter. Keine Linie mehr (Benny 2026-11-08: den
-- echten Weg kann eine gerade Linie nicht zeigen, sie verwirrte nur).
local APPROACHES = ns.DUNGEON_APPROACHES or {}
local ARROW_SIZE = 16 -- Ring am Eingang

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
            -- Strecke in Bildschirm-Pixeln (Kartenpixel × Zoom), damit die Punkte immer gleich dicht sind
            local ax, ay, px, py = a[2] * w, a[3] * h, pin.x * w, pin.y * h
            local length = math.sqrt(((px - ax) * scale) ^ 2 + ((py - ay) * scale) ^ 2)
            if length >= 30 then -- sonst liegt der Eingang praktisch am Portal: kein Weg nötig
            -- Ring am Eingang, gegen-skaliert (gleich groß bei jedem Zoom)
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
                mark.text:SetWidth(120) -- schmal umbrechen; Hinweise kurz halten, kein Einzelwort breiter als ~120 px (Benny 2026-11-08)
                mark.text:SetWordWrap(true)
                mark.text:SetTextColor(unpack(ns.UI.ACCENT))
                self.path.marks[marks] = mark
            end
            -- Ring mit Punkt = „hier geht's rein“ (Pfeile wirkten wie Wegweiser woandershin, Benny 2026-11-08)
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

-- Pins hängen in der Kartenfläche (zoomen mit), Gegen-Skalierung hält sie gleich groß
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
    -- erst ab Kontinent, auf der Azeroth-Gesamtkarte zu unruhig (Benny 2026-11-08)
    local info = C_Map.GetMapInfo(mapID)
    if not info or info.mapType <= Enum.UIMapType.World then return end
    self.pins = self.pins or {}
    local level = map:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_DUNGEON_ENTRANCE")
    for _, e in ipairs(ENTRANCES) do
        local _, pos = C_Map.GetMapPosFromWorldPos(e[2], CreateVector2D(e[3], e[4]), mapID)
        local x, y
        if pos then x, y = pos:GetXY() end -- nicht „pos and pos:GetXY()“: das liefert nur einen Wert
        if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
            self.used = self.used + 1
            local pin = self.pins[self.used]
            if not pin then
                pin = CreateFrame("Frame", nil, map:GetCanvas())
                pin.icon = pin:CreateTexture(nil, "ARTWORK")
                pin.icon:SetAllPoints()
                pin:EnableMouse(true)
                pin:SetMouseClickEnabled(false) -- Klicks gehen an die Karte (Zoom, Ebene hoch)
                local provider = self
                pin:SetScript("OnEnter", function(self)
                    -- links oberhalb: die Eingangs-Hinweise stehen unter ihren Ringen (Benny 2026-11-08)
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
                    -- Weg vom Außen-Eingang nur auf der Zonenkarte
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
            pin.x, pin.y, pin.raid, pin.instance = x, y, e[5], e[1]
            pin.name = (GetRealZoneText and GetRealZoneText(e[1])) or e[6]
            if not pin.name or pin.name == "" then pin.name = e[6] end
            pin:Show()
        end
    end
    self:Place()
end

function EntranceProvider:OnCanvasScaleChanged() self:Place() end
function EntranceProvider:OnCanvasSizeChanged() self:Place() end

-- Einhängen in eine Kartenfläche (Map/WorldMap.lua); areaLabelProvider = Blizzards Gebietsnamen
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
