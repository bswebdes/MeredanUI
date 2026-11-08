-- Eigene Buffs und Debuffs oben rechts, links neben der Minimap (ersetzt Blizzards Leiste).
--
--   [B][B][B][B][B][B][B][B][B][B][B][B] │ Minimap │   ← Buffs (Standard 36 px), wachsen nach
--   12m 45  3m  1h …                     │         │     links, zwei Reihen; Waffen-Verzauberungen
--   [B][B][B] …                          │         │     zuerst
--
--      [ D ][ D ][ D ] …                              ← Debuffs (Standard 40 px), Rahmen in
--       12   3m                                          Dispel-Farbe
--                     [P][P] …                        ← private Auren (Boss-Mechaniken), zeichnet
--                                                        Blizzard selbst; ersetzt deren Anker in
--                                                        der versteckten Blizzard-Debuffleiste
--
-- Gebaut auf Blizzards Aura-Container (12.1): Restzeit, Stapel, Dispel-Farbe, Tooltip und
-- Rechtsklick-Abbrechen erledigt Blizzard – auch bei geschützten Werten (Secrets). Wie ElvUI.
-- Größe, Anzahl, Zeit-Position und Abbrechen stehen beim Anlegen fest: Änderungen greifen nach
-- dem Neuladen; das Demo (Einstellungen > Buffs & Debuffs) zeigt sie sofort als Vorschau.
local _, ns = ...

local BUFF_ROWS, DEBUFF_ROWS = 2, 1
local SPACING = 4          -- zwischen den Icons
local TIME_HEIGHT = 14     -- Platz für die Restzeit unter dem Icon
local GAP = 10             -- Abstand zur Minimap
local GROUP_GAP = 18       -- zwischen Buffs, Debuffs und privaten Auren
local PRIVATE_COUNT = 6    -- so viele Anker legt Blizzard selbst an

local hidden = CreateFrame("Frame")
hidden:Hide()

-- Element-Ersatz für ns.StyleAuraButton (braucht dort nur die oUF-Farben für Dispel-Rahmen)
local styleElement = { __owner = { colors = ns.oUF.colors } }

local function TimeInside() return ns.db.auraTime == "inside" end
-- „Leiste“ (Benny 2026-11-08): statt Zahl eine dünne Leiste unter dem Icon, die abläuft; Farbe von
-- Salbei über Gelb nach Rot, je weniger Zeit übrig ist
local function TimeBar() return ns.db.auraTime == "bar" end
local BAR_HEIGHT, BAR_GAP = 5, 4 -- Benny 2026-11-08: etwas höher, mehr Abstand zum Icon
local SAGE, YELLOW, RED = { 0.557, 0.796, 0.706 }, { 0.93, 0.79, 0.36 }, { 0.88, 0.36, 0.32 }
local barCurve
if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
    barCurve = C_CurveUtil.CreateColorCurve()
    barCurve:AddPoint(0, CreateColor(RED[1], RED[2], RED[3]))
    barCurve:AddPoint(0.15, CreateColor(RED[1], RED[2], RED[3]))
    barCurve:AddPoint(0.35, CreateColor(YELLOW[1], YELLOW[2], YELLOW[3]))
    barCurve:AddPoint(0.6, CreateColor(SAGE[1], SAGE[2], SAGE[3]))
    barCurve:AddPoint(1, CreateColor(SAGE[1], SAGE[2], SAGE[3]))
end
local timeBars = {} -- [Leiste] = Aura-Knopf
-- Farbe alle 0,2 s aus Blizzards Dauer-Objekt (Werte können geschützt sein: nur durchreichen)
C_Timer.NewTicker(0.2, function()
    if not barCurve then return end
    for bar, button in pairs(timeBars) do
        -- Sichtbarkeit der Aura-Knöpfe ist geschützt (Secret) – nicht prüfen, einfach alle färben
        if button.GetAuraDuration then
            local ok, duration = pcall(button.GetAuraDuration, button)
            if ok and duration and duration.EvaluateRemainingPercent then
                local okColor, color = pcall(duration.EvaluateRemainingPercent, duration, barCurve)
                -- Farbe kann geschützt sein: nur durchreichen, Fehler schlucken (dann bleibt Salbei)
                if okColor and color then pcall(function() bar:SetStatusBarColor(color:GetRGB()) end) end
            end
        end
    end
end)

-- Maße einer Leiste – für die echten Leisten und das Demo gleich
local function Metrics(size, perRow, rows)
    local iconSize, spacing = ns.Snap(size), ns.Snap(SPACING)
    local timeBelow = TimeBar() and ns.Snap(BAR_HEIGHT + BAR_GAP + 1) or (not TimeInside() and ns.Snap(TIME_HEIGHT) or 0)
    local lineSpacing = spacing + timeBelow
    local width = perRow * iconSize + (perRow - 1) * spacing
    local height = rows * iconSize + (rows - 1) * lineSpacing + timeBelow
    return iconSize, spacing, lineSpacing, width, height
end

-- Größe als Stufe für beide (Buff, Debuff), Anzahl pro Reihe fest (Benny 2026-11-07)
local AURA_SIZES = { small = { 30, 34 }, medium = { 36, 40 }, large = { 42, 46 } }
local BUFFS_PER_ROW, DEBUFFS_PER_ROW = 12, 10
local function Sizes() return AURA_SIZES[ns.db.auraSize] or AURA_SIZES.medium end
local function BuffMetrics() return Metrics(Sizes()[1], BUFFS_PER_ROW, BUFF_ROWS) end
local function DebuffMetrics() return Metrics(Sizes()[2], DEBUFFS_PER_ROW, DEBUFF_ROWS) end

-- Restzeit unter oder im Icon, Stapel unten rechts
local function PlaceTexts(button, time, count)
    time:ClearAllPoints()
    if TimeInside() then
        time:SetPoint("CENTER", button, "CENTER", 0, 0)
    else
        time:SetPoint("TOP", button, "BOTTOM", 0, -ns.Snap(2))
    end
    count:ClearAllPoints()
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ns.Snap(1), ns.Snap(2))
end

local function InitButton(button, size, harmful)
    button:SetSize(size, size)
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT", 0, 0)
    if not harmful then
        -- Rechtsklick bricht den Buff ab (Blizzard macht das geschützt)
        button:SetCancelAuraButtons(C_CVar.GetCVarBool("ActionButtonUseKeyDown") and "RightButtonDown" or "RightButtonUp")
    end

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    button.Cooldown = cooldown
    button:SetDurationCooldown(cooldown)

    local icon = button:CreateTexture(nil, "BORDER")
    icon:SetAllPoints()
    button.Icon = icon
    button:SetIcon(icon)

    -- Texte über der Spirale
    local texts = CreateFrame("Frame", nil, button)
    texts:SetAllPoints()
    texts:SetFrameLevel(cooldown:GetFrameLevel() + 1)

    -- mit Schrift anlegen: Blizzard schreibt schon beim Verbinden Text hinein (MUI-Schrift danach)
    local count = texts:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.Count = count
    button:SetApplicationCount(count, {})

    local time = texts:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.Time = time
    if TimeBar() then
        -- Leiste statt Zahl: Blizzard lässt sie selbst ablaufen (SetTimerDuration)
        local bar = CreateFrame("StatusBar", nil, button)
        -- um die Rahmenbreite eingerückt: der Rahmen liegt außen und schließt dann bündig mit dem Icon ab
        local inset = ns.BORDER_PIXELS * ns.PixelSize()
        bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", inset, -ns.Snap(BAR_GAP))
        bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -inset, -ns.Snap(BAR_GAP))
        bar:SetHeight(ns.Snap(BAR_HEIGHT))
        bar:SetReverseFill(true) -- läuft von links nach rechts ab (Benny 2026-11-08)
        bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
        bar:SetStatusBarColor(unpack(SAGE))
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.06, 0.06, 0.9)
        ns.AddBorder(bar)
        button:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime })
        timeBars[bar] = button
        time:Hide()
    else
        button:SetDurationText(time, { textFormatter = ns.DurationFormatter })
    end

    -- MUI-Look wie an den Unitframes (Rahmen, Dispel-Farbe bei Debuffs, Spirale, Schrift)
    ns.StyleAuraButton(styleElement, button, { dispelBand = harmful and "harmful" or nil })
    PlaceTexts(button, time, count)
end

local function CreateContainer(name, filter, perRow, rows, iconSize, spacing, lineSpacing, width, height)
    local container = CreateFrame("AuraContainer", name, UIParent, "CustomAuraContainerTemplate")
    container:SetFrameStrata("LOW")
    container.muiHeight = height
    container:SetSize(width, height)
    -- oben rechts beginnen, nach links und dann nach unten wachsen
    container:SetFlowLayoutAnchorPoint("TOPRIGHT")
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutMaximumLineSize(width + ns.PixelSize() / 2) -- halber Pixel gegen Rundungsfehler
    container:SetFlowLayoutPadding(0, 0, 0, 0)

    local harmful = filter == "HARMFUL"
    local layout = { elementSpacing = spacing, lineSpacing = lineSpacing }
    local function Init(button) InitButton(button, iconSize, harmful) end
    container:AddAuraGroup(filter, filter, {
        maxFrameCount = perRow * rows,
        sortMethod = AuraContainerSortMethod.Default,
        sortDirection = AuraContainerSortDirection.Normal,
        layout = layout,
        initializeFrame = Init,
    })
    if not harmful then
        -- Waffen-Verzauberungen (Gifte, Öle …) vor den Buffs
        for _, slot in ipairs({ AuraContainerItemEnchantmentSlot.MainHand, AuraContainerItemEnchantmentSlot.OffHand }) do
            container:AddItemEnchantment(slot, { initializeFrame = Init })
        end
        container:SetItemEnchantmentLayout({
            placement = CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups,
            elementSpacing = spacing,
            lineSpacing = lineSpacing,
        })
    end
    container:SetUnit("player")
    container:SetEnabled(true)
    container:Show()
    return container
end

-- Private Auren: nur Anker-Rahmen; Symbol, Rahmen und Restzeit setzt Blizzard hinein
local function CreatePrivateAuras(iconSize, spacing)
    local holder = CreateFrame("Frame", "MeredanUIPlayerPrivateAuras", UIParent)
    holder:SetFrameStrata("LOW")
    holder.muiHeight = iconSize
    holder:SetSize(PRIVATE_COUNT * iconSize + (PRIVATE_COUNT - 1) * spacing, iconSize)
    holder.slots = {}
    for index = 1, PRIVATE_COUNT do
        local aura = CreateFrame("Frame", nil, holder)
        holder.slots[index] = aura
        aura:SetSize(iconSize, iconSize)
        aura:SetPoint("TOPLEFT", holder, "TOPLEFT", (index - 1) * (iconSize + spacing), 0) -- wächst nach rechts
        C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = "player",
            auraIndex = index,
            parent = aura,
            isContainer = false,
            showCountdownFrame = true,
            showCountdownNumbers = true,
            iconInfo = {
                iconWidth = iconSize,
                iconHeight = iconSize,
                iconAnchor = { point = "CENTER", relativeTo = aura, relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
            },
        })
    end
    return holder
end

local buffs, debuffs, privates

-- Oben bündig mit der Minimap (ohne Minimap am Bildschirmrand), Buffs, Debuffs und private
-- Auren untereinander. Nie eigene Rahmen an einen Aura-Container hängen: der ist abgeschirmt –
-- deshalb jede Reihe einzeln am selben Anker mit ausgerechnetem Abstand.
local function StackAnchor()
    local minimap = _G["MeredanUIMinimap"]
    if minimap then return minimap, "TOPLEFT", -ns.Snap(GAP), 0 end
    return UIParent, "TOPRIGHT", -ns.Snap(ns.SCREEN_MARGIN), -ns.Snap(ns.SCREEN_MARGIN)
end

-- Reihen untereinander; liefert die nächste freie Höhe (für die privaten Auren ohne Boss-Modul)
local function Stack(frames)
    local anchor, point, x, y = StackAnchor()
    for _, frame in ipairs(frames) do
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("TOPRIGHT", anchor, point, x, y)
            y = y - frame.muiHeight - ns.Snap(GROUP_GAP)
        end
    end
    return anchor, point, x, y
end

-- Private Auren (Boss-Mechaniken, Blizzard zeichnet sie): über der obersten Boss-Leiste, linke
-- Kante bündig mit den Leisten-Symbolen, nach rechts wachsend (Benny, 2026-10-25). BossMods meldet
-- die Spalte in ns.bossBarColumn und ruft das hier nach jedem Umbau auf. Ohne Boss-Modul: unter
-- den Debuffs.
local PRIVATE_BOSS_GAP = 6
function ns.PlacePrivateAuras()
    if not privates then return end
    privates:ClearAllPoints()
    local column = ns.bossBarColumn
    if column then
        -- Restzeit „unter dem Icon“ braucht Luft zur obersten Leiste (Demo-Platzhalter; Blizzard
        -- schreibt die echte Zahl ins Icon)
        local gap = ns.Snap(PRIVATE_BOSS_GAP) + (TimeInside() and 0 or ns.Snap(TIME_HEIGHT))
        privates:SetPoint("BOTTOMLEFT", column.holder, "TOPRIGHT", -ns.Snap(column.width), gap)
    else
        -- NIE an den Debuff-Container hängen (abgeschirmt > „Anchoring disallowed“): Höhe ausrechnen
        local anchor, point, x, y = StackAnchor()
        for _, frame in ipairs({ buffs, debuffs }) do
            if frame then y = y - frame.muiHeight - ns.Snap(GROUP_GAP) end
        end
        privates:SetPoint("TOPRIGHT", anchor, point, x, y)
    end
end

-- Unterkante des Aura-Stapels oben rechts (Buffs, Debuffs, private Auren nur ohne Boss-Modul –
-- mit Boss-Modul hängen sie über den Boss-Leisten). Für das Questlog darunter. Gerechnet, nicht
-- gemessen: Aura-Container sind abgeschirmt.
function ns.AuraStackBottom()
    if not (buffs or debuffs) then return end
    local anchor, point, x, y = StackAnchor()
    local top = anchor:GetTop() -- Minimap-Oberkante bzw. Bildschirm-Oberkante (beide „TOP…“)
    if not top then return end
    local frames = { buffs, debuffs }
    if privates and not ns.bossBarColumn then frames[#frames + 1] = privates end
    local bottom = top + y
    for _, frame in ipairs(frames) do
        if frame then bottom = bottom - frame.muiHeight - ns.Snap(GROUP_GAP) end
    end
    return bottom + ns.Snap(GROUP_GAP)
end

local function Place()
    Stack({ buffs, debuffs })
    ns.PlacePrivateAuras()
end

local function HideBlizzard()
    for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
        if frame then
            frame:UnregisterAllEvents()
            frame:SetParent(hidden)
            frame:Hide()
        end
    end
    -- sonst meldet der Bearbeitungsmodus einen Fehler (wie ElvUI)
    if BuffFrame then BuffFrame.numHideableBuffs = 0 end
end

-- Demo: Beispiel-Icons mit den aktuellen Einstellungen (auch noch nicht neu geladenen) ----------

local DEMO_BUFFS = { 21562, 1459, 6673, 1126, 381748, 462854, 2825, 465, 1022, 774, 17, 139 }
local DEMO_DEBUFFS = { 589, 172, 8936, 980, 1079, 6788 }
local DEMO_TIMES = { "58m", "12m", "45", "3m", "1h", "9", "27", "2m" }
local DEMO_DISPEL = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

local demoActive = false
local demoFrames = {}

local function DemoIcon(parent, spellID, size, harmful, index)
    local button = CreateFrame("Frame", nil, parent)
    button:SetSize(size, size)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(C_Spell.GetSpellTexture(spellID) or 134400)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = ns.AddBorder(button, true, harmful and 2 or ns.BORDER_PIXELS)
    local color = harmful and ns.oUF.colors.dispel[DEMO_DISPEL[(index - 1) % #DEMO_DISPEL + 1]]
    if color then
        for _, edge in ipairs(border) do edge:SetVertexColor(color:GetRGB()) end
    end
    local time = ns.CreateText(button, ns.STYLE.fontSize + 1, "CENTER", "OUTLINE")
    time:SetText(DEMO_TIMES[(index - 1) % #DEMO_TIMES + 1])
    if TimeBar() then
        time:SetText("")
        local bar = CreateFrame("StatusBar", nil, button)
        -- um die Rahmenbreite eingerückt: der Rahmen liegt außen und schließt dann bündig mit dem Icon ab
        local inset = ns.BORDER_PIXELS * ns.PixelSize()
        bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", inset, -ns.Snap(BAR_GAP))
        bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -inset, -ns.Snap(BAR_GAP))
        bar:SetHeight(ns.Snap(BAR_HEIGHT))
        bar:SetReverseFill(true) -- läuft von links nach rechts ab (Benny 2026-11-08)
        bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
        bar:SetMinMaxValues(0, 1)
        local fill = ({ 0.9, 0.55, 0.3, 0.1 })[(index - 1) % 4 + 1]
        bar:SetValue(fill)
        local c = fill > 0.6 and SAGE or fill > 0.25 and YELLOW or RED
        bar:SetStatusBarColor(unpack(c))
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.06, 0.06, 0.9)
        ns.AddBorder(bar)
    end
    local count = ns.CreateText(button, ns.STYLE.fontSize - 2, "RIGHT", "OUTLINE")
    count:SetText(index % 4 == 0 and "3" or "")
    PlaceTexts(button, time, count)
    return button
end

-- Platzhalter für private Auren (BossMods-Demo): die echten zeichnet Blizzard, eine Demo kann sie
-- nicht vortäuschen – das hier zeigt nur, WO sie erscheinen.
local DEMO_PRIVATE = { 589, 172, 8936 }
local privateDemo
function ns.PrivateAurasDemo(show)
    if not privates then return end
    if show and not privateDemo then
        privateDemo = {}
        for index, spellID in ipairs(DEMO_PRIVATE) do
            local icon = DemoIcon(privates, spellID, privates.muiHeight, false, index)
            icon:SetPoint("CENTER", privates.slots[index], "CENTER")
            privateDemo[index] = icon
        end
    end
    for _, icon in ipairs(privateDemo or {}) do icon:SetShown(show) end
end

local function DemoRow(spells, perRow, rows, harmful, metrics)
    local iconSize, spacing, lineSpacing, width, height = metrics()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetSize(width, height)
    frame.muiHeight = height
    for index = 1, perRow * rows do
        local icon = DemoIcon(frame, spells[(index - 1) % #spells + 1], iconSize, harmful, index)
        local col, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
        icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -col * (iconSize + spacing), -row * (iconSize + lineSpacing))
    end
    return frame
end

local function StopDemo()
    for _, frame in ipairs(demoFrames) do frame:Hide() end
    wipe(demoFrames)
    for _, frame in ipairs({ buffs, debuffs, privates }) do frame:Show() end
    demoActive = false
end

local function StartDemo()
    if demoActive then StopDemo() end
    for _, frame in ipairs({ buffs, debuffs, privates }) do frame:Hide() end
    demoFrames = {
        DemoRow(DEMO_BUFFS, BUFFS_PER_ROW, BUFF_ROWS, false, BuffMetrics),
        DemoRow(DEMO_DEBUFFS, DEBUFFS_PER_ROW, DEBUFF_ROWS, true, DebuffMetrics),
    }
    Stack(demoFrames)
    demoActive = true
end

ns.AurasDemo = {
    Start = StartDemo,
    Stop = StopDemo,
    IsActive = function() return demoActive end,
}

-- Einstellung geändert: läuft das Demo, mit den neuen Werten neu aufbauen
function ns.RefreshAurasDemo()
    if demoActive then StartDemo() end
end

ns:On("PLAYER_LOGIN", function()
    if not AuraContainerSortMethod then return end -- Client ohne Aura-Container: Blizzards Leiste bleibt
    HideBlizzard()
    local buffSize, buffSpacing, buffLines, buffWidth, buffHeight = BuffMetrics()
    buffs = CreateContainer("MeredanUIPlayerBuffs", "HELPFUL", BUFFS_PER_ROW, BUFF_ROWS,
        buffSize, buffSpacing, buffLines, buffWidth, buffHeight)
    local debuffSize, debuffSpacing, debuffLines, debuffWidth, debuffHeight = DebuffMetrics()
    debuffs = CreateContainer("MeredanUIPlayerDebuffs", "HARMFUL", DEBUFFS_PER_ROW, DEBUFF_ROWS,
        debuffSize, debuffSpacing, debuffLines, debuffWidth, debuffHeight)
    if C_UnitAuras.AddPrivateAuraAnchor then privates = CreatePrivateAuras(debuffSize, debuffSpacing) end
    ns.OnLayout(Place)
end)
