-- Minimap im MeredanUI-Stil: quadratisch, 1-px-Rahmen,
-- Ortsname oben (PvP-Farbe), Uhr unten (Klick: Kalender), Koordinaten unten links.
-- Blizzards Knöpfe bleiben funktional, sehen aber flach aus (eigene Symbole). Blizzards
-- Rahmen, Kompass und Zoom-Knöpfe verschwinden; gezoomt wird mit dem Mausrad.
--
--   ┌────────────────────────────┐
--   │ [Tracking]   Ort      [M+12]│
--   │                    [Addons] │
--   │ [Post][Aufträge]            │
--   │ 37.4, 86.3   21:42 [Übersicht]│
--   └────────────────────────────┘
local _, ns = ...
local L = ns.L

local WIDTH = 220
local MASK = "Interface\\Buttons\\WHITE8X8" -- quadratisch

local holder
local CreateDifficulty, CreateCoordinates, SetupMouseover -- unten definiert
local hidden = CreateFrame("Frame") -- Ablage für Blizzard-Teile, die nicht wieder auftauchen sollen
hidden:Hide()

-- Blizzard-Teil an eine feste Stelle in unserer Minimap setzen. Blizzard setzt manche
-- Teile bei Edit-Mode-Änderungen neu; der Hook auf SetPoint holt sie zurück.
local function Place(frame, point, x, y, scale)
    if not frame then return end
    local function Apply()
        frame.muiPlacing = true
        frame:ClearAllPoints()
        frame:SetPoint(point, holder, point, x, y)
        frame.muiPlacing = false
    end
    frame:SetParent(holder)
    if scale then frame:SetScale(scale) end
    frame:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    Apply()
    if not frame.muiHooked then
        frame.muiHooked = true
        hooksecurefunc(frame, "SetPoint", function()
            if not frame.muiPlacing then Apply() end
        end)
    end
end

local function Hide(frame)
    if frame then frame:SetParent(hidden) end
end

-- Größe und quadratische Maske setzen (beim Aufbau und wenn Blizzards HybridMinimap nachlädt)
function ns.LayoutMinimap()
    if not holder then return end
    local width = ns.Snap(WIDTH)
    holder:SetSize(width, width)
    Minimap:SetSize(width, width)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER")
    Minimap:SetMaskTexture(MASK)
    if HybridMinimap then HybridMinimap.CircleMask:SetTexture(MASK) end
    -- Quest-/Gebiets-„Blobs“ zeichnen einen Ring am runden Kartenrand – bei der quadratischen Karte
    -- ein falscher grauer Bogen. Ring aus, die Gebietsfläche selbst bleibt.
    for _, kind in ipairs({ "Quest", "Task", "Arch" }) do
        local scalar, alpha = Minimap["Set" .. kind .. "BlobRingScalar"], Minimap["Set" .. kind .. "BlobRingAlpha"]
        if scalar then scalar(Minimap, 0) end
        if alpha then alpha(Minimap, 0) end
    end
    -- Die Maske wird erst beim Neuzeichnen übernommen: Zoom kurz hin und zurück erzwingt das –
    -- sofort und nochmal in den nächsten Frames, weil WoW die Maske teils erst dann übernimmt.
    local function Redraw()
        local zoom = Minimap:GetZoom()
        Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
        Minimap:SetZoom(zoom)
    end
    Redraw()
    C_Timer.After(0, Redraw)
    C_Timer.After(0.2, Redraw)
end

local ICON_SIZE = 16

-- Blizzard-Knopf behalten (Klick, Menü, Tooltip), aber flach zeigen: Blizzards Optik wird
-- unsichtbar (Alpha 0, Mausklicks gehen trotzdem), darüber liegt unser Symbol, das diese
-- Transparenz nicht erbt (ns.CreateButtonOverlay) und mit dem Knopf ein- und ausgeblendet wird.
-- hoverFrame: der Teil, der die Maus bekommt (Standard: frame selbst).
local function Skin(frame, iconName, hoverFrame)
    if not frame or frame.muiIcon then return end
    local UI = ns.UI
    frame:SetAlpha(0)
    local overlay = ns.CreateButtonOverlay(frame)
    overlay:SetSize(ICON_SIZE, ICON_SIZE)
    overlay:SetPoint("CENTER", frame, "CENTER")
    local icon = UI.Icon(overlay, iconName, ICON_SIZE)
    icon:SetPoint("CENTER")
    frame.muiIcon = icon
    frame.muiOverlay = overlay
    hoverFrame = hoverFrame or frame
    hoverFrame:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
    hoverFrame:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
end

-- Schwierigkeit oben rechts als kurzes Kürzel: N, H, M, M+12, LFR, bei Szenarien/Tiefen
-- die Stufe. Draußen leer. Tooltip: voller Name.
local DIFFICULTY_COLORS = {
    normal = { 0.85, 0.85, 0.85 },
    heroic = { 0.35, 0.65, 1 },
    mythic = { 0.75, 0.45, 1 },
    challenge = { 1, 0.6, 0.2 },
    lfr = { 0.45, 0.85, 0.45 },
    scenario = { 0.95, 0.82, 0.4 },
}
local difficulty
local demoActive = false

local function DifficultyLabel()
    local _, instanceType, difficultyID, difficultyName = GetInstanceInfo()
    if instanceType == "none" or not difficultyID or difficultyID == 0 then return end
    local _, _, isHeroic, isChallengeMode, displayHeroic, displayMythic, _, isLFR = GetDifficultyInfo(difficultyID)
    if isChallengeMode then
        local level = C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo()
        return (level and level > 0) and ("M+" .. level) or "M+", "challenge", difficultyName
    elseif isLFR then
        return "LFR", "lfr", difficultyName
    elseif displayMythic then
        return "M", "mythic", difficultyName
    elseif isHeroic or displayHeroic then
        return "H", "heroic", difficultyName
    elseif instanceType == "scenario" then
        local tier = difficultyName and difficultyName:match("%d+")
        return tier or "S", "scenario", difficultyName
    end
    return "N", "normal", difficultyName
end

local function UpdateDifficulty()
    if not difficulty then return end
    local label, kind, name
    if demoActive then
        label, kind, name = "M+12", "challenge", L["Mythic Keystone"]
    else
        label, kind, name = DifficultyLabel()
    end
    difficulty.name = name
    difficulty:SetShown(label ~= nil)
    if not label then return end
    difficulty.text:SetText(label)
    difficulty.text:SetTextColor(unpack(DIFFICULTY_COLORS[kind]))
    difficulty:SetSize(difficulty.text:GetStringWidth() + 6, ICON_SIZE)
end

function CreateDifficulty()
    difficulty = CreateFrame("Frame", nil, holder)
    difficulty:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    difficulty:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -ns.Snap(4), -ns.Snap(4))
    difficulty.text = ns.CreateText(difficulty, 12, "RIGHT", "OUTLINE")
    difficulty.text:SetPoint("RIGHT")
    difficulty:EnableMouse(true)
    difficulty:SetScript("OnEnter", function(self)
        if not self.name then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(self.name, 1, 1, 1)
        GameTooltip:Show()
    end)
    difficulty:SetScript("OnLeave", function() GameTooltip:Hide() end)
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_DIFFICULTY_CHANGED", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START" }) do
        ns:On(event, UpdateDifficulty)
    end
    UpdateDifficulty()
end

-- Koordinaten unten links; in Instanzen (keine Position) ausgeblendet.
local coords

local function UpdateCoordinates()
    if not coords then return end
    if demoActive then
        coords:SetText("45.2, 61.8")
        coords:Show()
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if position then x, y = position:GetXY() end
    if not (ns.Readable(x) and ns.Readable(y)) or (x == 0 and y == 0) then
        coords:Hide()
        return
    end
    coords:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
    coords:Show()
end

function CreateCoordinates()
    coords = ns.CreateText(holder, 10, "LEFT", "OUTLINE")
    coords:SetParent(Minimap)
    coords:SetDrawLayer("OVERLAY", 7)
    coords:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", ns.Snap(5), ns.Snap(5))
    coords:SetTextColor(0.85, 0.85, 0.85)
    C_Timer.NewTicker(0.2, UpdateCoordinates)
end

-- Demo (Vorschau): alle Elemente sichtbar – Post, Berufsaufträge (nur Retail),
-- Schwierigkeit (M+12), Koordinaten, Erweiterungs-Übersicht.
local landingWasShown

local function SetDemo(on)
    demoActive = on
    local indicators = MinimapCluster.IndicatorFrame
    if indicators then
        -- Forever hat keine Berufsaufträge (CraftingOrderFrame fehlt) – jedes Teil einzeln prüfen
        local mail, orders = indicators.MailFrame, indicators.CraftingOrderFrame
        if on then
            if mail then mail:Show() end
            if orders then orders:Show() end
        else
            if mail then mail:SetShown(HasNewMail()) end
            if orders then
                local counts = orders.countInfos
                orders:SetShown(counts ~= nil and #counts > 0)
            end
        end
        if indicators.Layout then indicators:Layout() end
    end
    local landing = ExpansionLandingPageMinimapButton
    if landing then
        if on then
            landingWasShown = landing:IsShown()
            if landing.title then landing:Show() end -- ohne Titel hätte Blizzards Tooltip einen Fehler
        elseif landingWasShown == false then
            landing:Hide()
        end
    end
    UpdateDifficulty()
    UpdateCoordinates()
end

ns.MinimapDemo = {
    Start = function() SetDemo(true) end,
    Stop = function() SetDemo(false) end,
    IsActive = function() return demoActive end,
}

local function UpdateZone(zoneText)
    zoneText:SetText(GetMinimapZoneText())
    local pvpType = C_PvP.GetZonePVPInfo()
    if pvpType == "sanctuary" then
        zoneText:SetTextColor(0.41, 0.8, 0.94)
    elseif pvpType == "arena" or pvpType == "hostile" then
        zoneText:SetTextColor(1, 0.1, 0.1)
    elseif pvpType == "friendly" then
        zoneText:SetTextColor(0.1, 1, 0.1)
    elseif pvpType == "contested" then
        zoneText:SetTextColor(1, 0.7, 0)
    else
        zoneText:SetTextColor(1, 0.82, 0)
    end
end

local function CreateClock()
    local clock = CreateFrame("Button", nil, holder)
    clock:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    clock:SetPoint("BOTTOM", holder, "BOTTOM", 0, ns.Snap(3))
    local text = ns.CreateText(clock, 12, "CENTER")
    ns.SetFont(text, 12, "OUTLINE")
    text:SetPoint("CENTER")
    local function Update()
        text:SetText(date("%H:%M"))
        clock:SetSize(text:GetStringWidth() + 8, text:GetStringHeight() + 4)
    end
    Update()
    C_Timer.NewTicker(1, Update)
    clock:SetScript("OnClick", function() ToggleCalendar() end)
    return clock
end

-- Einstellungen „Texte“/„Symbole“: bei „mouseover“ nur sichtbar, solange die Maus über der
-- Minimap ist. Post, Berufsaufträge und Schwierigkeit bleiben immer sichtbar (Hinweise).
local mouseoverTexts, mouseoverIcons = {}, {}

local function coordsText() return coords end

SetupMouseover = function(texts, icons)
    for _, region in ipairs(texts) do if region then mouseoverTexts[#mouseoverTexts + 1] = region end end
    for _, region in ipairs(icons) do if region then mouseoverIcons[#mouseoverIcons + 1] = region end end
    C_Timer.NewTicker(0.1, function()
        local over = holder:IsMouseOver()
        local showTexts = over or ns.db.minimapExtras ~= "mouseover" -- Texte und Symbole: eine Einstellung
        local showIcons = showTexts
        for _, region in ipairs(mouseoverTexts) do region:SetAlpha(showTexts and 1 or 0) end
        for _, region in ipairs(mouseoverIcons) do region:SetAlpha(showIcons and 1 or 0) end
    end)
end

local function Setup()
    if not Minimap then return end
    if not ns.HEALTH_COLOR then ns.ApplySettings() end -- falls oUF später lädt als wir
    -- Reste der früheren eckigen Form aus den gespeicherten Einstellungen entfernen
    ns.db.minimapShape, ns.db.minimapTopAligned = nil, nil
    holder = CreateFrame("Frame", "MeredanUIMinimap", UIParent)
    holder:SetFrameStrata("LOW")
    -- Der Rahmen liegt auf einem eigenen Frame über der Karte.
    local background = holder:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(unpack(ns.STYLE.panelColor))
    local border = CreateFrame("Frame", nil, UIParent)
    border:SetAllPoints(holder)
    border:SetFrameStrata("LOW")
    border:SetFrameLevel(holder:GetFrameLevel() + 20)
    ns.AddBorder(border)

    Minimap:SetParent(holder)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER")
    Minimap:SetScale(1)
    ns.LayoutMinimap()

    -- Blizzard-Deko weg
    Hide(MinimapCluster.BorderTop)
    Hide(MinimapCluster.ZoneTextButton)
    Hide(MinimapCompassTexture)
    -- Rundes Standbild, das Blizzard im eigenen Haus (Housing) statt der Karte zeigt – passt
    -- nicht in die quadratische Karte; dort bleibt einfach unser flacher Hintergrund.
    ---@diagnostic disable-next-line: undefined-field
    Hide(MinimapBackdrop and MinimapBackdrop.StaticOverlayTexture)
    ---@diagnostic disable-next-line: undefined-field
    Hide(Minimap.ZoomIn)
    ---@diagnostic disable-next-line: undefined-field
    Hide(Minimap.ZoomOut)
    Hide(GameTimeFrame)
    Hide(TimeManagerClockButton) -- falls schon geladen; sonst siehe ADDON_LOADED unten
    -- Blizzards Koordinaten unter der Karte (seit 12.1.5): ersetzt durch unsere in der Karte
    Hide(MinimapCluster.MinimapContainer and MinimapCluster.MinimapContainer.PlayerCoords)

    -- Blizzard-Teile in die Ecken, flach dargestellt
    local inset = ns.Snap(4)
    local tracking = MinimapCluster.Tracking
    Place(tracking, "TOPLEFT", inset, -inset)
    Skin(tracking, "Tracking", tracking and tracking.Button)
    Hide(MinimapCluster.InstanceDifficulty) -- ersetzt durch eigene Anzeige (CreateDifficulty)
    Place(AddonCompartmentFrame, "TOPRIGHT", -inset, -ns.Snap(24))
    Skin(AddonCompartmentFrame, "Addons")
    local indicators = MinimapCluster.IndicatorFrame
    Place(indicators, "BOTTOMLEFT", inset, ns.Snap(20)) -- über den Koordinaten
    Skin(indicators and indicators.MailFrame, "Mail")
    Skin(indicators and indicators.CraftingOrderFrame, "Crafting")
    local landing = ExpansionLandingPageMinimapButton
    if landing then
        Place(landing, "BOTTOMRIGHT", -inset, inset)
        -- Blizzard setzt die Größe je nach Saison-Grafik neu: auf Symbolgröße halten
        local function KeepSize()
            if landing.muiSizing then return end
            landing.muiSizing = true
            landing:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
            landing.muiSizing = false
        end
        hooksecurefunc(landing, "SetSize", KeepSize)
        KeepSize()
        Skin(landing, "Landing")
    end
    CreateDifficulty()
    CreateCoordinates()

    -- Ortsname oben, Uhr unten
    local zoneText = ns.CreateText(holder, 12, "CENTER")
    ns.SetFont(zoneText, 12, "OUTLINE")
    zoneText:SetParent(Minimap)
    zoneText:SetDrawLayer("OVERLAY", 7)
    zoneText:SetPoint("TOP", holder, "TOP", 0, -ns.Snap(6))
    zoneText:SetWidth(ns.Snap(WIDTH - 70))
    UpdateZone(zoneText)
    for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        ns:On(event, function() UpdateZone(zoneText) end)
    end
    -- Kein „Wer hat gepingt“: MINIMAP_PING ist in Midnight für Addons gesperrt (HasRestrictions,
    -- geschützte Daten) – Registrieren bricht mit Fehler ab (2026-10-25 probiert).
    local clock = CreateClock()
    SetupMouseover({ zoneText, clock, coordsText() }, {
        tracking and tracking.muiOverlay, AddonCompartmentFrame and AddonCompartmentFrame.muiOverlay,
        landing and landing.muiOverlay,
    })

    -- fester Platz oben rechts, 25 px vom Rand
    ns.OnLayout(function()
        local margin = ns.Snap(ns.SCREEN_MARGIN)
        ns.PlaceFromCenter(holder, "TOPRIGHT", UIParent:GetWidth() / 2 - margin, UIParent:GetHeight() / 2 - margin)
    end)
    ns.layoutFrames.minimap = holder
end

ns:On("PLAYER_LOGIN", Setup)

-- Nachgeladene Blizzard-Teile: eigene Uhr ersetzt die von Blizzard; HybridMinimap
-- (z. B. in manchen Instanzen) bekommt dieselbe Maske.
ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_TimeManager" then
        Hide(TimeManagerClockButton)
    elseif name == "Blizzard_HybridMinimap" then
        ns.LayoutMinimap()
    end
end)

