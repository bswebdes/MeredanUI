-- Einrichtungsassistent (Benny 2026-11-07, Entwurf „mUI Einrichtungsassistent“):
-- Intro (Logo, Version, „Setup starten“) → Größe → Rolle → Stil (Klassisch/Komfort) → Leisten
-- (nicht bei Heiler) → Schadensanzeige → Chat + Spitzname → Fertig (Neu laden).
-- Rechts ein Mini-Bild des Bildschirms aus einfachen Flächen, das sich mit jeder Wahl ändert.
-- Erscheint einmal je Charakter beim ersten Login (ns.char.setupDone); erneut über /mui setup oder den Knopf
-- in den Einstellungen (Layouts). Stil setzt nur Startwerte (Core/Presets.lua).
local _, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT = 900, 500
local LEFT_W = 330                     -- Spalte mit Frage und Auswahl
local SHOT_W = WIDTH - LEFT_W - 3 * 22 -- Mini-Bildschirm
local SHOT_H = math.floor(SHOT_W * 9 / 16)
local PANEL2 = { 0.08, 0.09, 0.10, 1 }

local window, st
local stepIndex = 1


local function SizeItems()
    return {
        { value = "small", label = L["Small"], desc = L["Lots of room for the game world"] },
        { value = "medium", label = L["Medium"], desc = L["Right for most people"] },
        { value = "large", label = L["Large"], desc = L["Easy to read, also from a distance"] },
    }
end

local function RoleItems()
    return {
        { value = "melee", label = L["Melee"], desc = L["Warrior, rogue, enhancement …"] },
        { value = "ranged", label = L["Ranged"], desc = L["Hunter, mage, warlock …"] },
        { value = "tank", label = L["Tank"], desc = L["Threat always in view"] },
        { value = "healer", label = L["Healer"], desc = L["Group in the middle, bars stacked"] },
    }
end

local function StyleItems()
    local items = {}
    for _, style in ipairs(ns.STYLES) do items[#items + 1] = { value = style.id, label = style.name, desc = style.desc } end
    return items
end

local STEPS = {
    { id = "intro" },
    { id = "size", key = "size", title = L["How big should everything be?"],
        text = L["Applies to the whole interface. On big screens rather medium or large."], items = SizeItems },
    { id = "role", key = "role", title = L["What do you mainly play?"],
        text = L["Decides where player, target, group and bars sit."], items = RoleItems },
    { id = "style", key = "style", title = L["Which style suits you?"],
        text = L["Only sets the starting values. You can turn every single feature on or off later."], items = StyleItems },
    { id = "bars", key = "bars", title = L["Where should the action bars sit?"],
        text = L["Preselected to match the style."], skip = function() return st.role == "healer" end,
        items = function()
            return {
                { value = "stacked", label = L["Stacked"], desc = L["Three rows of 12 at the bottom, like in the old days"] },
                { value = "center", label = L["Centre 2 × 6"], desc = L["Compact main bar in the middle"] },
            }
        end },
    { id = "meter", key = "meter", title = L["Damage meter?"],
        text = L["Shows damage and healing of your group. Top left."],
        items = function()
            return { { value = true, label = L["Yes, show it"] }, { value = false, label = L["No, thanks"] } }
        end },
    { id = "chat", key = "chat", title = L["Set up the chat?"], nickname = true,
        text = L["One chat window plus Combat Log, channels in mUI colours. You leave Trade and General chat; join again anytime."],
        items = function()
            return { { value = true, label = L["Yes, the mUI way"] }, { value = false, label = L["No, leave it"] } }
        end },
    { id = "done" },
}

local function ActiveSteps()
    local list = {}
    for _, step in ipairs(STEPS) do
        if not (step.skip and step.skip()) then list[#list + 1] = step end
    end
    return list
end

-- Mini-Bildschirm ------------------------------------------------------------------------------
-- Ein verkleinertes Abbild des echten Layouts: Plätze wie in Core/Layouts.lua und ActionBars.lua
-- (unten 2–3 Reihen à 12, rechts zwei senkrechte Leisten, Minimap oben rechts …), echte Symbole
-- aus deinen Aktionsleisten und Buffs, dein Name in Klassenfarbe. Alles in Pixeln des Bildes,
-- Größen mal Stufe (Klein/Mittel/Groß).

local els = {}       -- alle Teile, werden pro Zeichnen erst versteckt, dann gebraucht
local screen         -- Bildfläche
local METER_CLASSES = { "WARRIOR", "MAGE", "HUNTER", "PRIEST", "ROGUE" }

local function ClassColor(class)
    local color = class and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 0.6, 0.6, 0.6
end

-- Teil holen bzw. einmal bauen
local function El(key, build)
    local el = els[key]
    if not el then
        el = build()
        els[key] = el
    end
    return el
end

local function Panel(alpha)
    local frame = CreateFrame("Frame", nil, screen)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0.03, 0.035, 0.04, alpha or 0.9)
    for _, edge in ipairs(ns.AddBorder(frame)) do edge:SetVertexColor(0, 0, 0, 1) end
    return frame
end

local function Place(frame, x, y, w, h)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", screen, "TOPLEFT", math.floor(x + 0.5), -math.floor(y + 0.5))
    frame:SetSize(math.max(math.floor(w + 0.5), 1), math.max(math.floor(h + 0.5), 1))
    frame:Show()
    return frame
end

local function Tex(frame, layer, r, g, b, a)
    local tex = frame:CreateTexture(nil, layer or "ARTWORK")
    if r then tex:SetColorTexture(r, g, b, a or 1) end
    return tex
end

-- Leiste aus cols × rows gleichen Feldern (bewusst ohne Symbole)
local function ActionBar(key, cols, rows, x, y, size, gap)
    local bar = El(key, function()
        local frame = CreateFrame("Frame", nil, screen)
        frame.cells = {}
        for i = 1, cols * rows do
            local cell = CreateFrame("Frame", nil, frame)
            cell.bg = Tex(cell, "BACKGROUND", 0.03, 0.035, 0.04, 0.95)
            cell.bg:SetAllPoints()
            cell.face = Tex(cell, "ARTWORK", 0.2, 0.23, 0.23, 1)
            cell.face:SetPoint("TOPLEFT", 1, -1)
            cell.face:SetPoint("BOTTOMRIGHT", -1, 1)
            frame.cells[i] = cell
        end
        return frame
    end)
    gap = gap or 1
    Place(bar, x, y, cols * size + (cols - 1) * gap, rows * size + (rows - 1) * gap)
    for i, cell in ipairs(bar.cells) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (size + gap), -row * (size + gap))
        cell:SetSize(size, size)
    end
    return bar
end

-- Unitframe: Lebensbalken (Füllung), Ressource darunter, Name im Balken
local function UnitFrame(key, x, y, w, h, color, fill, mirrored)
    local frame = El(key, function()
        local f = Panel(0.95)
        f.hp = Tex(f, "ARTWORK")
        f.pw = Tex(f, "ARTWORK", 0.18, 0.44, 0.82)
        return f
    end)
    Place(frame, x, y, w, h)
    local power = math.max(math.floor(h * 0.22), 2)
    frame.hp:ClearAllPoints()
    frame.hp:SetPoint(mirrored and "TOPRIGHT" or "TOPLEFT")
    frame.hp:SetSize(w * fill, h - power - 1)
    frame.hp:SetColorTexture(color[1], color[2], color[3], 1)
    frame.pw:ClearAllPoints()
    frame.pw:SetPoint("BOTTOMLEFT")
    frame.pw:SetPoint("BOTTOMRIGHT")
    frame.pw:SetHeight(power)
    return frame
end

-- schmale Leiste mit Füllung (Bedrohung, Schlagtimer, Zauberleiste)
local function Strip(key, x, y, w, h, r, g, b, fill)
    local frame = El(key, function()
        local f = Panel(0.9)
        f.fill = Tex(f, "ARTWORK")
        f.fill:SetPoint("TOPLEFT")
        f.fill:SetPoint("BOTTOMLEFT")
        return f
    end)
    Place(frame, x, y, w, h)
    frame.fill:SetWidth(math.max(w * fill, 1))
    frame.fill:SetColorTexture(r, g, b, 1)
    return frame
end

local function DrawScreen(target)
    screen = target
    for _, el in pairs(els) do el:Hide() end
    -- Maße wie im Spiel (UIParent ~1920 × 1080 Einheiten), verkleinert aufs Bild
    local W, H = SHOT_W, SHOT_H
    local k = H / 1080
    local function U(v) return v * k end
    local s = ({ small = 0.85, medium = 1, large = 1.15 })[st.size] or 1
    local comfort = st.style == "comfort"
    local healer = st.role == "healer"
    local stacked = healer or st.bars == "stacked"
    local cx, cy = W / 2, H / 2
    local margin = U(25)
    local _, myClass = UnitClass("player")
    local hpColor = comfort and { ClassColor(myClass) } or { 0.25, 0.64, 0.3 }

    -- Leisten unten (ActionBars.lua): Zusatzleisten 36, Hauptleiste 42, Abstand 4
    local b, gap = U(36 * s), math.max(U(4), 1)
    local rowW = 12 * b + 11 * gap
    local shiftY = H - margin - b
    ActionBar("shift", 12, 1, cx - rowW / 2, shiftY, b, gap)
    ActionBar("alt", 12, 1, cx - rowW / 2, shiftY - b - gap, b, gap)
    local bottomTop = shiftY - b - gap
    if stacked then
        ActionBar("main12", 12, 1, cx - rowW / 2, bottomTop - b - gap, b, gap)
        bottomTop = bottomTop - b - gap
    end
    -- rechts: zwei senkrechte Leisten am Rand, senkrecht mittig
    local colH = 12 * b + 11 * gap
    ActionBar("right", 1, 12, W - margin - b, cy - colH / 2, b, gap)
    ActionBar("inner", 1, 12, W - margin - 2 * b - gap, cy - colH / 2, b, gap)
    -- große Zauberleiste über den unteren Leisten (Fernkampf, Heiler)
    if st.role == "ranged" or healer then
        local castH = U(32 * s)
        Strip("cast", cx - rowW / 2, bottomTop - U(6) - castH, rowW, castH, 0.85, 0.7, 0.3, 0.55)
        bottomTop = bottomTop - U(6) - castH
    end

    -- Spieler / Ziel (UnitFrames.lua): Innenkante 260 von der Mitte, Oberkante 200 unter der Mitte
    local uw, uh = U(270 * s), U(40 * s)
    local inner, unitTop = U(260), cy + U(200)
    if healer then
        -- Heiler (Core/Layouts.lua HealerGeometry): Gruppe mittig über der Zauberleiste,
        -- Spieler und Ziel oben bündig daneben
        local cols, rows = 5, 4
        local fw, fh, fgap = U(107), U(61), U(4)
        local gridW, gridH = cols * fw + (cols - 1) * fgap, rows * fh + (rows - 1) * fgap
        local gy = bottomTop - U(10) - gridH
        for i = 1, cols * rows do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            local class = METER_CLASSES[(i - 1) % #METER_CLASSES + 1]
            UnitFrame("hgroup" .. i, cx - gridW / 2 + col * (fw + fgap), gy + row * (fh + fgap), fw, fh,
                { ClassColor(class) }, 0.55 + ((i * 37) % 45) / 100)
        end
        inner, unitTop = gridW / 2 + U(32), gy
    end
    UnitFrame("player", cx - inner - uw, unitTop, uw, uh, hpColor, 0.82)
    UnitFrame("target", cx + inner, unitTop, uw, uh, { 0.8, 0.25, 0.2 }, 0.64, true)

    -- Mitte: Hauptleiste 2 × 6 auf Höhe des Spielers; darunter Bedrohung und Schlagtimer
    local mb = U(42 * s)
    local mainW = 6 * mb + 5 * gap
    local belowY = unitTop
    if not stacked then
        ActionBar("main", 6, 2, cx - mainW / 2, unitTop, mb, gap)
        belowY = unitTop + 2 * mb + gap + U(6)
    end
    if healer then belowY = unitTop - U(30) end
    if st.role == "tank" or comfort then
        Strip("threat", cx - mainW / 2, belowY, mainW, U(10), 0.79, 0.63, 0.23, 0.6)
        belowY = belowY + U(14)
    end
    if comfort and not healer then Strip("swing", cx - mainW / 2, belowY, mainW, U(6), 0.85, 0.85, 0.85, 0.4) end

    -- Gruppe (GroupFrames.lua): links neben dem Spieler, Oberkante 300 ÜBER der Mitte
    if not healer then
        local gw, gh, ggap = U(130), U(62), U(4)
        local gx = cx - inner - uw - U(68) - gw
        for i = 1, 5 do
            local class = i == 1 and myClass or METER_CLASSES[i]
            UnitFrame("group" .. i, gx, cy - U(300) + (i - 1) * (gh + ggap), gw, gh, { ClassColor(class) },
                0.5 + ((i * 29) % 50) / 100)
        end
    end

    -- Minimap oben rechts, Buffs links daneben, Questlog darunter
    local mm = U(200 * s)
    local minimap = El("minimap", function()
        local f = Panel(1)
        f.map = Tex(f, "ARTWORK", 0.2, 0.26, 0.2)
        f.map:SetPoint("TOPLEFT", 1, -1)
        f.map:SetPoint("BOTTOMRIGHT", -1, 1)
        f.water = Tex(f, "ARTWORK", 0.16, 0.24, 0.3)
        f.arrow = f:CreateTexture(nil, "OVERLAY")
        f.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
        f.arrow:SetPoint("CENTER")
        return f
    end)
    Place(minimap, W - margin - mm, margin, mm, mm)
    minimap.water:ClearAllPoints()
    minimap.water:SetPoint("BOTTOMLEFT", 1, 1)
    minimap.water:SetSize(mm * 0.45, mm * 0.35)
    minimap.arrow:SetSize(U(30), U(30))

    local icon, count = U(36 * s), 6
    local buffs = El("buffs", function()
        local f = CreateFrame("Frame", nil, screen)
        f.icons = {}
        for i = 1, 8 do f.icons[i] = Tex(f, "ARTWORK", 0.2, 0.23, 0.23, 1) end
        return f
    end)
    Place(buffs, W - margin - mm - U(16) - count * (icon + gap), margin, count * (icon + gap), icon)
    for i, tex in ipairs(buffs.icons) do
        tex:SetShown(i <= count)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", (i - 1) * (icon + gap), 0)
        tex:SetSize(icon, icon)
    end

    local quest = El("quest", function()
        local f = CreateFrame("Frame", nil, screen)
        f.lines = {}
        for i = 1, 12 do
            local isTitle = (i - 1) % 3 == 0
            f.lines[i] = Tex(f, "ARTWORK", isTitle and 1 or 0.8, isTitle and 0.82 or 0.8, isTitle and 0.2 or 0.78,
                isTitle and 0.9 or 0.45)
        end
        return f
    end)
    local questW, questTop = U(240), margin + mm + U(30)
    local questBottom = cy - colH / 2 - U(20)
    Place(quest, W - margin - questW, questTop, questW, math.max(questBottom - questTop, 10))
    local ly, lineH = 0, math.max(U(5), 2)
    for i, line in ipairs(quest.lines) do
        local isTitle = (i - 1) % 3 == 0
        line:ClearAllPoints()
        line:SetPoint("TOPRIGHT", 0, -ly)
        line:SetSize(questW * (isTitle and 0.75 or (0.5 + (i % 3) * 0.2)), lineH)
        line:SetShown(ly + lineH <= quest:GetHeight())
        ly = ly + lineH + U(isTitle and 10 or 8) + (i % 3 == 0 and U(10) or 0)
    end

    -- Chat unten links (ChatStyle.lua 440 × 160)
    local chatW, chatH = U(440), U(160)
    local chat = El("chat", function()
        local f = Panel(0.55)
        f.lines = {}
        local colors = { { 0.25, 1, 0.25 }, { 1, 1, 1 }, { 0.56, 0.8, 0.71 }, { 1, 1, 1 }, { 0.25, 1, 0.25 }, { 1, 0.62, 0.36 }, { 1, 1, 1 } }
        for i, c in ipairs(colors) do f.lines[i] = Tex(f, "ARTWORK", c[1], c[2], c[3], 0.7) end
        return f
    end)
    Place(chat, margin, H - margin - chatH, chatW, chatH)
    for i, line in ipairs(chat.lines) do
        line:ClearAllPoints()
        line:SetPoint("BOTTOMLEFT", U(12), U(12) + (i - 1) * U(20))
        line:SetSize((chatW - U(24)) * (0.35 + ((i * 41) % 60) / 100), math.max(U(5), 2))
        line:SetShown(U(12) + (i - 1) * U(20) + U(5) <= chatH - U(8))
    end

    -- Schadensanzeige oben links
    if st.meter then
        local meter = El("meter", function()
            local f = Panel(0.85)
            f.head = Tex(f, "ARTWORK", 0.56, 0.8, 0.71, 0.9)
            f.head:SetPoint("TOPLEFT", 1, -1)
            f.head:SetPoint("TOPRIGHT", -1, -1)
            f.head:SetHeight(2)
            f.bars = {}
            for i, class in ipairs(METER_CLASSES) do f.bars[i] = Tex(f, "ARTWORK", ClassColor(class)) end
            return f
        end)
        local mw, mh = U(260), U(150)
        Place(meter, margin, margin, mw, mh)
        local barH = math.max(math.floor((mh - U(16)) / #METER_CLASSES) - 1, 2)
        for i, bar in ipairs(meter.bars) do
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", 2, -U(12) - (i - 1) * (barH + 1))
            bar:SetSize((mw - 4) * (1 - (i - 1) * 0.17), barH)
        end
    end

    -- Flugzeit oben mittig (Komfort)
    if comfort then Strip("flight", cx - U(160), margin, U(320), U(14), 0.56, 0.8, 0.71, 0.45) end
end

-- Unterschiede Klassisch/Komfort (Stil-Schritt, unter dem Mini-Bild)
local DIFF = {
    { L["Info bar"], false, true },
    { L["Health bars"], L["sage"], L["class colour"] },
    { L["Swing timer"], false, true },
    { L["Cast bar"], L["Simple"], L["Full"] },
    { L["Flight time"], false, true },
    { L["Trainer reminders"], false, true },
    { L["Emojis, reputation bar in chat"], false, true },
    { L["Red error texts"], true, false },
}

-- Fenster -------------------------------------------------------------------------------------

local Render

local function OptionButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(unpack(PANEL2))
    button.edges = ns.AddBorder(button)
    button.bar = button:CreateTexture(nil, "ARTWORK")
    button.bar:SetPoint("TOPLEFT")
    button.bar:SetPoint("BOTTOMLEFT")
    button.bar:SetWidth(3)
    button.bar:SetColorTexture(unpack(UI.ACCENT))
    button.title = UI.Text(button, 13, "LEFT")
    button.title:SetPoint("TOPLEFT", 12, -8)
    button.desc = UI.Text(button, 11, "LEFT", UI.MUTED)
    button.desc:SetPoint("TOPLEFT", button.title, "BOTTOMLEFT", 0, -3)
    button.desc:SetPoint("RIGHT", -10, 0)
    button:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetColorTexture(unpack(UI.HOVER)) end end)
    button:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(PANEL2)) end)
    function button:SetSelected(selected)
        self.selected = selected
        self.bar:SetShown(selected)
        for _, edge in ipairs(self.edges) do
            if selected then edge:SetVertexColor(unpack(UI.ACCENT)) else edge:SetVertexColor(1, 1, 1, 0.12) end
        end
    end
    return button
end

local function Finish(useDefaults)
    ns.char.setupDone = true
    if useDefaults then
        window:Hide()
        return
    end
    ns.ApplyStylePreset(st.style)
    ns.root.uiSize = st.size ~= "medium" and st.size or nil
    ns.db.layout = st.role
    if st.role ~= "healer" then ns.db.barVariant = st.bars end
    ns.db.damageMeter = st.meter
    if st.nick and st.nick ~= "" then ns.root.nickname = st.nick end
    if ns.SyncDamageMeterCVar then ns.SyncDamageMeterCVar() end
    if ns.ApplyMouseoverCast then ns.ApplyMouseoverCast() end
    if st.chat and ns.SetupChat then ns.SetupChat() end
    ReloadUI()
end

local function CreateWindow()
    window = CreateFrame("Frame", "MeredanUISetup", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", 0, 40)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    UI.Box(window, { 0.05, 0.06, 0.06, 0.98 })
    tinsert(UISpecialFrames, "MeredanUISetup") -- Esc schließt (wie „Später“)
    local accent = window:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2)
    accent:SetColorTexture(unpack(UI.ACCENT))

    -- Kopf: Titel, Fortschritt, „Später“
    local title = UI.Text(window, 15, "LEFT")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Meredan|cff8ecbb4UI|r  ·  " .. L["Setup"])
    window.dots = {}
    for i = 1, 6 do
        local dot = window:CreateTexture(nil, "ARTWORK")
        dot:SetSize(7, 7)
        dot:SetPoint("LEFT", title, "RIGHT", 14 + (i - 1) * 13, 0)
        window.dots[i] = dot
    end
    local later = UI.Button(window, L["Set up later"], function() window:Hide() end, 140)
    later:SetPoint("TOPRIGHT", -10, -10)
    local headLine = window:CreateTexture(nil, "ARTWORK")
    headLine:SetColorTexture(1, 1, 1, 0.08)
    headLine:SetPoint("TOPLEFT", 0, -44)
    headLine:SetPoint("TOPRIGHT", 0, -44)
    headLine:SetHeight(1)

    -- Fuß: Zurück / Weiter
    local footLine = window:CreateTexture(nil, "ARTWORK")
    footLine:SetColorTexture(1, 1, 1, 0.08)
    footLine:SetPoint("BOTTOMLEFT", 0, 48)
    footLine:SetPoint("BOTTOMRIGHT", 0, 48)
    footLine:SetHeight(1)
    window.back = UI.Button(window, L["Back"], function()
        stepIndex = math.max(1, stepIndex - 1)
        Render()
    end, 110)
    window.back:SetPoint("BOTTOMLEFT", 12, 12)
    window.next = UI.Button(window, L["Next"], function() end, 200)
    window.next:SetPoint("BOTTOMRIGHT", -12, 12)
    window.next.Text:SetTextColor(unpack(UI.ACCENT))

    -- Intro
    local intro = CreateFrame("Frame", nil, window)
    intro:SetPoint("TOPLEFT", 0, -44)
    intro:SetPoint("BOTTOMRIGHT", 0, 48)
    local logo = intro:CreateFontString(nil, "OVERLAY")
    logo:SetFont(ns.DISPLAY_FONT, 96, "")
    logo:SetPoint("TOP", 0, -40)
    logo:SetText("m|cff8ecbb4UI|r")
    local sub = intro:CreateFontString(nil, "OVERLAY")
    sub:SetFont(ns.DISPLAY_FONT, 22, "")
    sub:SetPoint("TOP", logo, "BOTTOM", 0, -6)
    sub:SetText("MEREDAN|cff8ecbb4UI|r")
    local version = UI.Text(intro, 11, "CENTER", UI.MUTED)
    version:SetPoint("TOP", sub, "BOTTOM", 0, -6)
    version:SetText(ns.VERSION)
    local introText = UI.Text(intro, 13, "CENTER", UI.MUTED)
    introText:SetWordWrap(true)
    introText:SetWidth(420)
    introText:SetPoint("TOP", version, "BOTTOM", 0, -20)
    introText:SetText(L["A few short questions and everything is in place. Takes less than a minute and can be repeated anytime."])
    local start = UI.Button(intro, L["Start setup"], function()
        stepIndex = 2
        Render()
    end, 200)
    start:SetPoint("TOP", introText, "BOTTOM", 0, -22)
    start.Text:SetTextColor(unpack(UI.ACCENT))
    window.intro = intro

    -- Frage-Schritte: links Text + Auswahl, rechts Mini-Bild
    local page = CreateFrame("Frame", nil, window)
    page:SetPoint("TOPLEFT", 0, -44)
    page:SetPoint("BOTTOMRIGHT", 0, 48)
    page.kicker = UI.Text(page, 10, "LEFT", UI.ACCENT)
    page.kicker:SetPoint("TOPLEFT", 22, -22)
    page.title = page:CreateFontString(nil, "OVERLAY")
    page.title:SetFont(ns.DISPLAY_FONT, 20, "")
    page.title:SetTextColor(unpack(UI.TEXT))
    page.title:SetJustifyH("LEFT")
    page.title:SetWordWrap(true)
    page.title:SetWidth(LEFT_W)
    page.title:SetPoint("TOPLEFT", page.kicker, "BOTTOMLEFT", 0, -6)
    page.text = UI.Text(page, 12, "LEFT", UI.MUTED)
    page.text:SetWordWrap(true)
    page.text:SetWidth(LEFT_W)
    page.text:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
    page.options = {}
    page.nickLabel = UI.Text(page, 12, "LEFT", UI.MUTED)
    page.nickLabel:SetText(L["Nickname in guild chat (optional)"])
    page.nick = UI.EditBox(page, 26)
    page.nick:SetWidth(LEFT_W)
    page.nick:SetMaxLetters(24)
    page.nick:SetScript("OnTextChanged", function(self) st.nick = strtrim(self:GetText() or "") end)
    page.nick:SetScript("OnEnterPressed", page.nick.ClearFocus)
    -- Zusammenfassung (Fertig)
    page.summary = {}
    for i = 1, 7 do
        local row = CreateFrame("Frame", nil, page)
        row:SetSize(LEFT_W, 22)
        row:SetPoint("TOPLEFT", page.text, "BOTTOMLEFT", 0, -16 - (i - 1) * 26)
        row.key = UI.Text(row, 12, "LEFT")
        row.key:SetPoint("LEFT")
        row.value = UI.Text(row, 12, "RIGHT", UI.MUTED)
        row.value:SetPoint("RIGHT")
        local line = row:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 0.08)
        line:SetPoint("BOTTOMLEFT")
        line:SetPoint("BOTTOMRIGHT")
        line:SetHeight(1)
        page.summary[i] = row
    end

    local screen = CreateFrame("Frame", nil, page)
    screen:SetSize(SHOT_W, SHOT_H)
    screen:SetPoint("TOPRIGHT", -22, -22)
    -- Spielwelt angedeutet: Himmel oben heller, Boden unten dunkler
    local world = screen:CreateTexture(nil, "BACKGROUND")
    world:SetAllPoints()
    world:SetColorTexture(1, 1, 1, 1)
    world:SetGradient("VERTICAL", CreateColor(0.09, 0.12, 0.10, 1), CreateColor(0.24, 0.30, 0.31, 1))
    ns.AddBorder(screen)
    page.screen = screen
    page.caption = UI.Text(page, 11, "LEFT", UI.MUTED)
    page.caption:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, -8)
    page.diff = {}
    for i, entry in ipairs(DIFF) do
        local text = UI.Text(page, 11, "LEFT")
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        text:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", col * (SHOT_W / 2), -10 - row * 18)
        text:SetWidth(SHOT_W / 2 - 8)
        text.entry = entry
        page.diff[i] = text
    end
    window.page = page
    window:Hide()
end

local SIZE_NAMES = { small = "Small", medium = "Medium", large = "Large" }
local ROLE_NAMES = { melee = "Melee", ranged = "Ranged", tank = "Tank", healer = "Healer" }

local function StyleName(id)
    for _, style in ipairs(ns.STYLES) do if style.id == id then return style.name end end
    return id
end

Render = function()
    local steps = ActiveSteps()
    stepIndex = math.min(stepIndex, #steps)
    local step = steps[stepIndex]
    local page = window.page
    -- Fortschritt: nur die Fragen
    local questions = #steps - 2
    for i, dot in ipairs(window.dots) do
        dot:SetShown(i <= questions)
        if i < stepIndex then dot:SetColorTexture(unpack(UI.ACCENT)) else dot:SetColorTexture(1, 1, 1, 0.15) end
    end

    window.intro:SetShown(step.id == "intro")
    page:SetShown(step.id ~= "intro")
    if step.id == "intro" then
        window.back.Text:SetText(L["Start without setup"])
        window.back:SetWidth(240)
        window.back:SetScript("OnClick", function() Finish(true) end)
        window.next:Hide()
        return
    end
    window.back.Text:SetText(L["Back"])
    window.back:SetWidth(110)
    window.back:SetScript("OnClick", function()
        stepIndex = math.max(1, stepIndex - 1)
        Render()
    end)
    window.next:Show()

    local options = step.items and step.items() or {}
    page.kicker:SetText(step.id == "done" and L["Done"]:upper() or L["Step %d"]:format(stepIndex - 1):upper())
    page.title:SetText(step.id == "done" and L["All set"] or step.title)
    page.text:SetText(step.id == "done"
        and L["After the reload everything sits like this. You can change anything anytime with /mui, and restart the setup there."]
        or step.text)

    -- Auswahl
    local anchor, y = page.text, -16
    for i, item in ipairs(options) do
        local button = page.options[i] or OptionButton(page)
        page.options[i] = button
        button:SetSize(LEFT_W, item.desc and 46 or 32)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
        button.title:SetText(item.label)
        button.desc:SetText(item.desc or "")
        button.title:ClearAllPoints()
        if item.desc then button.title:SetPoint("TOPLEFT", 12, -8) else button.title:SetPoint("LEFT", 12, 0) end
        button:SetSelected(st[step.key] == item.value)
        button:SetScript("OnClick", function()
            st[step.key] = item.value
            if step.key == "style" then -- Leisten und Schadensanzeige passend zum Stil vorwählen
                st.bars = ns.StyleDefault(item.value, "barVariant")
                st.meter = ns.StyleDefault(item.value, "damageMeter")
            end
            Render()
        end)
        button:Show()
        anchor, y = button, -8
    end
    for i = #options + 1, #page.options do page.options[i]:Hide() end

    page.nickLabel:SetShown(step.nickname == true)
    page.nick:SetShown(step.nickname == true)
    if step.nickname then
        page.nickLabel:ClearAllPoints()
        page.nickLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
        page.nick:ClearAllPoints()
        page.nick:SetPoint("TOPLEFT", page.nickLabel, "BOTTOMLEFT", 0, -6)
        page.nick:SetText(st.nick or "")
    end

    -- Zusammenfassung
    local done = step.id == "done"
    local rows = {
        { L["Size"], L[SIZE_NAMES[st.size]] },
        { L["Screen layout"], L[ROLE_NAMES[st.role]] },
        { L["Style"], StyleName(st.style) },
        { L["Action bars"], (st.role == "healer" or st.bars == "stacked") and L["Stacked"] or L["Centre 2 × 6"] },
        { L["Damage meter"], st.meter and L["Yes"] or L["No"] },
        { L["Chat"], st.chat and L["mUI style"] or L["unchanged"] },
        (st.nick and st.nick ~= "") and { L["Nickname"], st.nick } or nil,
    }
    for i, row in ipairs(page.summary) do
        local entry = rows[i]
        row:SetShown(done and entry ~= nil)
        if entry then
            row.key:SetText(entry[1])
            row.value:SetText(entry[2])
        end
    end

    -- Mini-Bild + Unterschiede beim Stil
    DrawScreen(page.screen)
    local isStyle = step.id == "style"
    page.caption:SetShown(not isStyle)
    page.caption:SetText(done and L["This is how your screen will look."] or L["Preview of your choice"])
    local comfort = st.style == "comfort"
    for _, text in ipairs(page.diff) do
        text:SetShown(isStyle)
        local name, classic, full = unpack(text.entry)
        local value = comfort and full or classic
        local on = value == true or (type(value) == "string" and comfort)
        local shown = type(value) == "string" and value or (value and L["on"] or L["off"])
        local color = on and "|cff8ecbb4" or "|cff99978f"
        text:SetText(("%s%s|r  %s: %s"):format(color, on and "+" or "–", name, shown))
    end

    if done then
        window.next.Text:SetText(L["Reload and start"])
        window.next:SetScript("OnClick", function() Finish(false) end)
    else
        window.next.Text:SetText(L["Next"])
        window.next:SetScript("OnClick", function()
            stepIndex = stepIndex + 1
            Render()
        end)
    end
end

-- Assistent öffnen (Werte vorausgefüllt mit dem, was gerade eingestellt ist)
function ns.OpenSetup()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    if not window then CreateWindow() end
    if ns.HideSettings then ns.HideSettings() end
    local style = ns.db.style or "classic"
    st = {
        size = ns.root.uiSize or "medium",
        role = ns.db.layout or ns.DEFAULT_LAYOUT,
        style = style,
        bars = ns.db.barVariant or ns.StyleDefault(style, "barVariant"),
        meter = ns.db.damageMeter ~= false,
        chat = true,
        nick = ns.root.nickname or "",
    }
    stepIndex = 1
    window:Show()
    Render()
end

ns.AddCommand("setup", L["start the setup again"], function() ns.OpenSetup() end)

-- Beim ersten Login einmal von selbst (nach dem Ladebildschirm)
ns:On("PLAYER_LOGIN", function()
    if ns.char.setupDone then return end
    C_Timer.After(3, function()
        if not ns.char.setupDone and not InCombatLockdown() then ns.OpenSetup() end
    end)
end)
