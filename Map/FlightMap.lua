-- Flugkarte (WoW Forever): eigenes Fenster statt Blizzards quadratischer TaxiFrame.
--
--   ┌ Flugkarte · Darnassus                                             [x] ┐
--   │ ┌──────────────── Kontinent (Blizzards Kartenbild) ────────────────┐ │
--   │ │   ● Flugpunkte (Blizzards Pins aus der modernen Flugkarte),      │ │
--   │ │     Linien zu erreichbaren Zielen, Strecke beim Darüberfahren    │ │
--   │ └──────────────────────────────────────────────────────────────────┘ │
--   │                                Mausrad: Zoom · Ziehen: verschieben    │
--
-- Forever öffnet bei Flugmeistern das alte TaxiFrame (UIMapSystem.Taxi, Blizzard_Game/Mainline
-- HandleTaxiMapOpened). Dessen OnHide ruft CloseTaxiMap() > es darf nicht versteckt werden, solange
-- die Flugverbindung offen sein soll. Darum: unsichtbar und winzig (Alpha 0, Skalierung), unser
-- Fenster darüber. Kartenfläche = Blizzards MapCanvas (wie Map/WorldMap.lua), Flugpunkte = Blizzards
-- FlightMap_FlightPathDataProviderMixin aus Blizzard_FlightMap (Pins rufen TakeTaxiNode selbst auf,
-- die Flugzeit-Leiste hängt daran). Moderne Flugkarte (FlightMapFrame, andere Kartensysteme) bleibt
-- unangetastet – die ist schon zentriert und zoombar.
local _, ns = ...
local L = ns.L

local PAD = 18
local CANVAS_W, CANVAS_H = 1050, 700 -- Höchstmaße; Fenster passt sich ans Seitenverhältnis der Karte an
local EXTRA_ZOOM = { 1.5, 2.2, 3.2 } -- eigene Zoomstufen (Vielfache der Grundgröße), falls Blizzard keine hat

local window, canvas, titleText, blizzardHidden

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.flightWindow ~= false and MapCanvasMixin and TaxiFrame
end

-- Kartenfläche ------------------------------------------------------------------------------------

-- Kontinentkarten haben in Forever teils nur eine Zoomstufe > Mausrad täte nichts. Fehlende
-- Stufen ergänzen (gleiche Ebene, nur größer skaliert).
local function CreateZoomLevels(self)
    MapCanvasScrollControllerMixin.CreateZoomLevels(self)
    local levels = self.zoomLevels
    local last = levels[#levels]
    for _, factor in ipairs(EXTRA_ZOOM) do
        local scale = self.baseScale * factor
        if scale > levels[#levels].scale + 0.01 then
            levels[#levels + 1] = { scale = scale, layerIndex = last.layerIndex }
        end
    end
end

-- Kartennummer: zuerst der Kontinent unter dir (rechteckiges Weltkarten-Bild), Blizzards Taxi-Karte
-- nur als Notlösung – die ist in Forever das alte quadratische Bild (Benny 2026-11-08, Screenshot).
-- Die erste mit Kartenbild und Flugpunkten gewinnt.
local function PickMap()
    local candidates = {}
    local best = C_Map.GetBestMapForUnit("player")
    if best and MapUtil and MapUtil.GetMapParentInfo then
        local continent = MapUtil.GetMapParentInfo(best, Enum.UIMapType.Continent, true)
        if continent then candidates[#candidates + 1] = continent.mapID end
    end
    if GetTaxiMapID then candidates[#candidates + 1] = GetTaxiMapID() end
    for _, mapID in ipairs(candidates) do
        local layers = mapID and mapID > 0 and C_Map.GetMapArtLayers(mapID)
        local nodes = layers and #layers > 0 and C_TaxiMap.GetAllTaxiNodes(mapID)
        if nodes and #nodes > 0 then return mapID, nodes end
    end
    if DevLog then DevLog("FlightMap: keine Karte", candidates[1], candidates[2]) end
end

local function CreateCanvas(parent)
    local map = CreateFrame("Frame", "MeredanUIFlightCanvas", parent)
    map:SetPoint("CENTER")
    map:SetSize(CANVAS_W, CANVAS_H) -- Open() passt die Größe ans Seitenverhältnis des Kartenbilds an
    map.ScrollContainer = CreateFrame("ScrollFrame", nil, map, "MapCanvasFrameScrollContainerTemplate")
    map.ScrollContainer:ClearAllPoints()
    map.ScrollContainer:SetAllPoints(map)
    map.ScrollContainer.CreateZoomLevels = CreateZoomLevels
    map.BorderFrame = CreateFrame("Frame", nil, map)
    map.BorderFrame:SetAllPoints(map)
    map.BorderFrame:SetFrameLevel(map:GetFrameLevel() + 1500)
    map.BorderFrame:EnableMouse(false)
    Mixin(map, MapCanvasMixin)
    MapCanvasMixin.OnLoad(map)
    map:SetShouldNavigateOnClick(false) -- Klick ins Gebiet wechselt nicht die Karte
    map:SetShouldZoomInOnClick(false)
    map:SetShouldPanOnClick(false)
    map:SetGlobalPinScale(1)
    -- Flugpunkte die Blizzard-Titel/Symbol setzen wollen (Bastion o. Ä.) – bei uns ohne Wirkung
    function map:ResetTitleAndPortraitIcon() end
    function map:UpdateTitleAndPortraitIcon() end

    map:SetScript("OnEvent", function(self, event, ...) MapCanvasMixin.OnEvent(self, event, ...) end)
    map:SetScript("OnUpdate", function(self, elapsed) MapCanvasMixin.OnUpdate(self, elapsed) end)
    map:SetScript("OnHide", function(self) MapCanvasMixin.OnHide(self) end)

    map:AddDataProvider(CreateFromMixins(FlightMap_FlightPathDataProviderMixin))
    local levels = map:GetPinFrameLevelsManager()
    levels:AddFrameLevel("PIN_FRAME_LEVEL_FLIGHT_POINT")
    levels:AddFrameLevel("PIN_FRAME_LEVEL_MAP_HIGHLIGHT")
    return map
end

-- Fenster -----------------------------------------------------------------------------------------

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIFlightMap", UIParent)
    window:SetSize(CANVAS_W + 2 * PAD, CANVAS_H + PAD + 44 + 40)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:SetPoint("CENTER", 0, 30)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor)
    local accent = window:CreateTexture(nil, "OVERLAY")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    tinsert(UISpecialFrames, "MeredanUIFlightMap")

    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(PAD + 30)
    ns.MakeWindowDraggable(window, head)
    titleText = UI.Text(head, 16, "LEFT")
    titleText:SetPoint("TOPLEFT", PAD, -PAD - 4)
    local close = UI.IconButton(head, "Close", function() window:Hide() end, 26)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)

    local holder = CreateFrame("Frame", nil, window)
    window.holder = holder
    holder:SetPoint("TOPLEFT", PAD, -PAD - 44)
    holder:SetSize(CANVAS_W, CANVAS_H)
    ns.AddBorder(holder)
    holder:SetClipsChildren(true)
    canvas = CreateCanvas(holder)

    local hint = UI.Text(window, 12, "RIGHT", UI.MUTED)
    hint:SetPoint("BOTTOMRIGHT", -PAD, 14)
    hint:SetText(L["Mouse wheel: zoom · Drag: move"])

    window:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        -- Fenster zu = Flugmeister zu (wie Blizzards TaxiFrame)
        if TaxiFrame:IsShown() then HideUIPanel(TaxiFrame) else CloseTaxiMap() end
    end)
end

-- Blizzards TaxiFrame unsichtbar machen bzw. zurückholen
local function HideBlizzard(hide)
    if hide then
        TaxiFrame:SetAlpha(0)
        TaxiFrame:SetScale(0.001)
        TaxiFrame:EnableMouse(false)
        blizzardHidden = true
    elseif blizzardHidden then
        TaxiFrame:SetAlpha(1)
        TaxiFrame:SetScale(1)
        TaxiFrame:EnableMouse(true)
        blizzardHidden = nil
    end
end

local function Open()
    if not C_AddOns.IsAddOnLoaded("Blizzard_FlightMap") then C_AddOns.LoadAddOn("Blizzard_FlightMap") end
    if not FlightMap_FlightPathDataProviderMixin then return false end
    if FlightMap_FlightPointPinMixin and not FlightMap_FlightPointPinMixin.muiHooked then
        -- Flugzeit im Tooltip erreichbarer Ziele (Minimap/FlightTimer.lua); vor dem ersten Pin einhängen
        FlightMap_FlightPointPinMixin.muiHooked = true
        hooksecurefunc(FlightMap_FlightPointPinMixin, "OnMouseEnter", function(pin)
            local data = pin.taxiNodeData
            if data and data.state == Enum.FlightPathState.Reachable and ns.AddFlightTimeLine then
                ns.AddFlightTimeLine(GameTooltip, data.slotIndex)
            end
        end)
    end
    local mapID, nodes = PickMap()
    if not mapID then return false end
    if not window then CreateWindow() end
    -- Kartenfläche im Seitenverhältnis des Bildes, mittig (sonst klebt ein schmaleres Bild links oben)
    local layer = C_Map.GetMapArtLayers(mapID)[1]
    local scale = math.min(CANVAS_W / layer.layerWidth, CANVAS_H / layer.layerHeight)
    -- Fenster folgt der Karte (Benny 2026-11-08: sonst leerer Streifen über einer breiten Karte)
    local w, h = math.floor(layer.layerWidth * scale), math.floor(layer.layerHeight * scale)
    canvas:SetSize(w, h)
    window.holder:SetSize(w, h)
    window:SetSize(w + 2 * PAD, h + PAD + 44 + 40)
    window:Show()
    canvas:SetMapID(mapID)
    MapCanvasMixin.OnShow(canvas)
    -- Kein Start-Zoom mehr (Benny 2026-11-08): sanftes Hinzoomen schob die Karte bei Flugpunkten am
    -- Rand über den Kartenrand hinaus (leerer Streifen). Ganze Karte zeigen, Mausrad zoomt.
    canvas:ResetZoom()
    local here
    for _, node in ipairs(nodes) do
        if node.state == Enum.FlightPathState.Current then here = node.name end
    end
    titleText:SetText((FLIGHT_MAP or L["Flight map"]) .. (here and ("  ·  " .. here:match("^([^,]+)")) or ""))
    PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
    return true
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    TaxiFrame:HookScript("OnShow", function()
        if not Enabled() then return HideBlizzard(false) end
        -- klappt unser Fenster nicht (keine Karte gefunden), bleibt Blizzards Fenster sichtbar
        HideBlizzard(Open())
    end)
    TaxiFrame:HookScript("OnHide", function()
        HideBlizzard(false)
        if window and window:IsShown() then window:Hide() end
    end)
end)

ns:On("TAXIMAP_CLOSED", function()
    if window and window:IsShown() then window:Hide() end
end)
