-- Bedienelemente für das Einstellungsfenster im MeredanUI-Look: flach, dunkel, 1-px-Rahmen,
-- Surf Green als Akzent. Jede Seite stapelt ihre Elemente von oben nach unten (page:Add…).
-- Elemente mit Wert haben :Refresh(), das den aktuellen Wert aus get() anzeigt.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local UI = {}
ns.UI = UI

-- Akzentfarbe der Marke: Surf Green (wie die Fender-Lackierung)
UI.ACCENT = { 0.557, 0.796, 0.706 } -- #8ecbb4
UI.TEXT = { 0.91, 0.9, 0.87 }
UI.MUTED = { 0.6, 0.59, 0.56 }
UI.FIELD = { 0.1, 0.1, 0.11, 1 }
UI.HOVER = { 0.16, 0.16, 0.18, 1 }

UI.TAG = { 0.85, 0.64, 0.25 }  -- Marke „Reload“ (gold)

local ROW_GAP = 12
local L = ns.L

-- Vom Fenster gesetzt: merkt sich Änderungen, die ein Neuladen brauchen (Leiste unten)
UI.MarkReload = function(_) end

-- Fläche mit 1-px-Rahmen und fester Farbe (nicht vom Theme abhängig).
function UI.Box(frame, color)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(color or UI.FIELD))
    ns.AddBorder(frame)
    return bg
end

-- Kästchen für Haken: dunkle Füllung mit hellem Rand, damit es auf dunklem Grund sichtbar ist
UI.CHECK_EDGE = { 0.36, 0.36, 0.38, 1 }
function UI.CheckBg(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.05, 1)
    -- Rahmen innen: liegt ein Kästchen ganz links in einer Liste mit Beschnitt, fehlte sonst die
    -- linke Kante (Benny 2026-11-07)
    for _, edge in ipairs(ns.AddBorder(frame, true)) do
        edge:SetVertexColor(unpack(UI.CHECK_EDGE))
        -- In scrollenden Listen liegt das Kästchen oft auf einem halben Pixel; die 1-px-Kante würde
        -- dann aufs Pixelraster „weggerundet“ (oben oder unten fehlte sie). Ohne Einrasten bleibt sie sichtbar.
        edge:SetSnapToPixelGrid(false)
        edge:SetTexelSnappingBias(0)
    end
    return bg
end

function UI.Text(parent, size, justify, color)
    local text = ns.CreateText(parent, size or 12, justify)
    text:SetTextColor(unpack(color or UI.TEXT))
    return text
end

-- Symbol aus Media/Icons (weiß angelegt), eingefärbt.
function UI.Icon(parent, name, size, color)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(size, size)
    icon:SetTexture(ns.MEDIA .. "Icons\\" .. name)
    icon:SetVertexColor(unpack(color or UI.TEXT))
    return icon
end

-- Knopf nur mit Symbol (z. B. Schließen); Hover hellt auf.
function UI.IconButton(parent, name, onClick, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size or 24, size or 24)
    local bg = UI.Box(button)
    local icon = UI.Icon(button, name, (size or 24) - 8)
    icon:SetPoint("CENTER")
    button.icon = icon
    button:SetScript("OnEnter", function()
        bg:SetColorTexture(unpack(UI.HOVER))
        icon:SetVertexColor(unpack(UI.ACCENT))
    end)
    button:SetScript("OnLeave", function()
        bg:SetColorTexture(unpack(UI.FIELD))
        icon:SetVertexColor(unpack(UI.TEXT))
    end)
    button:SetScript("OnClick", onClick)
    return button
end

-- Pfeil-Knopf zum Blättern ("left"/"right"), ausgegraut wenn deaktiviert.
function UI.ArrowButton(parent, direction, onClick, size)
    local button = UI.IconButton(parent, "ChevronDown", onClick, size)
    button.icon:SetRotation(direction == "left" and -math.pi / 2 or math.pi / 2)
    hooksecurefunc(button, "SetEnabled", function(self, on)
        self.icon:SetAlpha(on and 1 or 0.3)
    end)
    return button
end

-- Pfeil als Text-Symbol zwischen zwei Namen (statt ">")
-- Eigenes Symbol (Media/Icons) als Bild im Text, eingefärbt – statt Sonderzeichen wie ✓, die
-- unsere Schrift nicht hat (tools/check_glyphs.py prüft das beim Einspielen)
-- yOffset: positiv = höher. Neben Text sitzen Symbole sonst zu tief: bei 11–13 px Symbol und
-- normaler mUI-Schrift 1–2 (Uhr 13 px im Tracker: 1, 0 zu tief, 2 zu hoch; Benny 2026-11-08).
function UI.IconMarkup(name, size, color, yOffset)
    local c = color or UI.TEXT
    return ("|T%sIcons\\%s:%d:%d:0:%d:64:64:0:64:0:64:%d:%d:%d|t"):format(ns.MEDIA, name, size or 12, size or 12,
        yOffset or 0, c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.ArrowMarkup(size)
    return CreateAtlasMarkup("common-icon-forwardarrow", size or 10, size or 10, 0, 0, 150, 150, 150)
end

-- Erklär-Tooltip (das „i“ in den Einstellungen): normaler Fließtext in 12 px (11 war schwer lesbar, Benny 2026-11-08) statt Blizzards
-- fetter, größerer Titelzeile (SetText nutzt die Kopfschrift; Benny 2026-11-08: „viel zu fett“).
-- Die erste Zeile bekommt beim Verstecken ihre Kopfschrift zurück, sonst wären Item-Titel klein.
function UI.ShowHelp(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 0.91, 0.9, 0.87, 1, true)
    GameTooltipTextLeft1:SetFont(ns.FontFor("text"), ns.FontPx(12), "")
    GameTooltip:Show()
end
function UI.HideHelp()
    GameTooltip:Hide()
    GameTooltipTextLeft1:SetFontObject(GameTooltipHeaderText)
end

-- Schlichter Knopf mit Text; Hover hellt auf.
function UI.Button(parent, label, onClick, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 160, 24)
    local bg = UI.Box(button)
    local text = UI.Text(button, 12, "CENTER")
    text:SetPoint("CENTER")
    text:SetText(label)
    button.Text = text
    button:SetScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
    button:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    button:SetScript("OnClick", onClick)
    return button
end

-- Flaches Eingabefeld; Fokus zeigt einen Rahmen in Surf Green.
function UI.EditBox(parent, height)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetHeight(height or 24)
    box:SetAutoFocus(false)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetFont(ns.STYLE.font, ns.FontPx(12), "")
    box:SetTextColor(unpack(UI.TEXT))
    UI.Box(box)
    local focus = ns.AddBorder(box, true)
    for _, edge in ipairs(focus) do
        edge:SetVertexColor(unpack(UI.ACCENT))
        edge:Hide()
    end
    box:HookScript("OnEditFocusGained", function() for _, edge in ipairs(focus) do edge:Show() end end)
    box:HookScript("OnEditFocusLost", function() for _, edge in ipairs(focus) do edge:Hide() end end)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    return box
end

-- Scrollleiste im mUI-Look, für alle Listen (Benny 2026-11-07, auch wegen Barrierefreiheit):
-- Pfeile oben/unten, schmale Spur mit Griff in Surf Green. Griff zum Ziehen, Klick auf die Spur
-- blättert eine Seite, Hover macht den Griff breiter und heller; Klickflächen 14 px breit.
-- opts: GetRange() (max. Offset), GetOffset() (0 = oben), SetOffset(v), GetRatio() (sichtbarer
-- Anteil 0–1), step (Pfeil-Schritt), page (Seiten-Schritt)
function UI.Scrollbar(parent, opts)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(14)
    local function Arrow(rotation)
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(14, 16)
        button.icon = UI.Icon(button, "ChevronDown", 14, UI.MUTED)
        button.icon:SetPoint("CENTER")
        button.icon:SetRotation(rotation)
        button:SetScript("OnEnter", function(self) self.icon:SetVertexColor(unpack(UI.ACCENT)) end)
        button:SetScript("OnLeave", function(self) self.icon:SetVertexColor(unpack(UI.MUTED)) end)
        return button
    end
    local up, down = Arrow(math.pi), Arrow(0)
    up:SetPoint("TOP")
    down:SetPoint("BOTTOM")
    local track = CreateFrame("Button", nil, bar)
    track:SetPoint("TOP", up, "BOTTOM", 0, -2)
    track:SetPoint("BOTTOM", down, "TOP", 0, 2)
    track:SetWidth(14)
    local line = track:CreateTexture(nil, "BACKGROUND")
    line:SetPoint("TOP")
    line:SetPoint("BOTTOM")
    line:SetWidth(3)
    line:SetColorTexture(1, 1, 1, 0.06)
    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(14)
    local grip = thumb:CreateTexture(nil, "ARTWORK")
    grip:SetPoint("TOP")
    grip:SetPoint("BOTTOM")
    grip:SetWidth(3)
    grip:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.8)
    local hovered, dragging = false, nil
    local function Highlight()
        local on = hovered or dragging ~= nil
        grip:SetWidth(on and 5 or 3)
        grip:SetAlpha(on and 1 or 0.8)
    end
    for _, region in ipairs({ thumb, track }) do
        region:HookScript("OnEnter", function() hovered = true Highlight() end)
        region:HookScript("OnLeave", function() hovered = false Highlight() end)
    end

    local function Range() return math.max(opts.GetRange() or 0, 0) end
    local function Set(value)
        opts.SetOffset(math.min(math.max(value, 0), Range()))
        bar:Update()
    end
    function bar:Update()
        local range = Range()
        self:SetShown(range > 0)
        if range <= 0 then return end
        local height = track:GetHeight()
        local size = math.max(height * math.min(math.max(opts.GetRatio() or 0.5, 0), 1), 20)
        local offset = math.min(math.max(opts.GetOffset() or 0, 0), range)
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", 0, -(height - size) * offset / range)
    end

    local function CursorY() return select(2, GetCursorPosition()) / track:GetEffectiveScale() end
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        dragging = { y = CursorY(), offset = opts.GetOffset() or 0 }
        Highlight()
        self:SetScript("OnUpdate", function()
            local free = track:GetHeight() - thumb:GetHeight()
            if free <= 0 then return end
            Set(dragging.offset + (dragging.y - CursorY()) / free * Range())
        end)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        dragging = nil
        self:SetScript("OnUpdate", nil)
        Highlight()
    end)
    track:SetScript("OnClick", function()
        local page = opts.page or 120
        local thumbMid = (thumb:GetTop() + thumb:GetBottom()) / 2
        Set((opts.GetOffset() or 0) + (CursorY() < thumbMid and page or -page))
    end)
    up:SetScript("OnClick", function() Set((opts.GetOffset() or 0) - (opts.step or 40)) end)
    down:SetScript("OnClick", function() Set((opts.GetOffset() or 0) + (opts.step or 40)) end)
    bar:SetScript("OnSizeChanged", function(self) self:Update() end)
    return bar
end

-- Bereich mit Mausrad-Scrollen und mUI-Scrollleiste rechts (nur sichtbar, wenn der Inhalt
-- nicht hineinpasst). area.child nimmt den Inhalt auf; area:SetContentHeight(h) nach dem Füllen.
function UI.ScrollArea(parent)
    local area = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, area)
    child:SetSize(1, 1)
    area:SetScrollChild(child)
    area.child = child

    local function Range() return math.max(child:GetHeight() - area:GetHeight(), 0) end
    local scrollbar = UI.Scrollbar(area, {
        GetRange = Range,
        GetOffset = function() return area:GetVerticalScroll() end,
        SetOffset = function(value) area:SetVerticalScroll(value) end,
        GetRatio = function()
            local total = child:GetHeight()
            return total > 0 and area:GetHeight() / total or 1
        end,
        step = 40,
        page = 200,
    })
    scrollbar:SetPoint("TOPLEFT", area, "TOPRIGHT", 3, 0)
    scrollbar:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 3, 0)
    area.scrollbar = scrollbar

    local function Update()
        area:SetVerticalScroll(math.min(area:GetVerticalScroll(), Range()))
        scrollbar:Update()
    end

    function area:SetContentHeight(height)
        child:SetHeight(math.max(height, 1))
        Update()
    end

    function area:ScrollToTop()
        self:SetVerticalScroll(0)
        Update()
    end

    -- zu einer Stelle im Inhalt springen (begrenzt auf den Scrollbereich)
    function area:ScrollTo(offset)
        self:SetVerticalScroll(math.min(math.max(offset, 0), Range()))
        Update()
    end

    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(self, delta)
        UI.CloseList() -- die Liste würde sonst vom Feld wegrutschen
        self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - delta * 40, 0), Range()))
        Update()
    end)
    area:SetScript("OnSizeChanged", function(self, width)
        child:SetWidth(width)
        Update()
    end)
    return area
end

-- Seite: Elemente werden untereinander gestapelt.
function UI.Page(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.y = 0
    page.items = {}

    -- Platz für ein Element reservieren und dessen Rahmen zurückgeben.
    function page:Row(height)
        local row = CreateFrame("Frame", nil, self)
        row:SetPoint("TOPLEFT", 0, -self.y)
        row:SetPoint("TOPRIGHT", 0, -self.y)
        row:SetHeight(height)
        self.y = self.y + height + ROW_GAP
        self.items[#self.items + 1] = row
        return row
    end

    -- Zusätze hinter einem Label: Marke „Reload“ (gold) und ein „i“ mit Erklärung im Tooltip.
    -- opts = { reload = true, help = "…" }
    local function Decorate(row, after, opts)
        if not opts then return end
        local anchor = after
        if opts.reload then
            local tag = UI.Text(row, 9, "LEFT", UI.TAG)
            tag:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
            tag:SetText(L["RELOAD"])
            anchor = tag
        end
        if opts.help then
            local info = CreateFrame("Frame", nil, row)
            info:SetSize(14, 14)
            info:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
            info:SetFrameLevel(row:GetFrameLevel() + 10) -- über Checkbox-Knopf, Regler und Auswahl
            UI.Box(info)
            local i = UI.Text(info, 10, "CENTER", UI.MUTED)
            i:SetPoint("CENTER", 0, 0)
            i:SetText("i")
            info:EnableMouse(true)
            info:SetScript("OnEnter", function(self)
                i:SetTextColor(unpack(UI.ACCENT))
                UI.ShowHelp(self, opts.help)
            end)
            info:SetScript("OnLeave", function()
                i:SetTextColor(unpack(UI.MUTED))
                UI.HideHelp()
            end)
        end
    end

    -- set() mit Reload-Marke: merkt die Änderung für die Leiste unten
    local function Wrap(set, label, opts)
        if not (opts and opts.reload) then return set end
        return function(value)
            set(value)
            UI.MarkReload(label)
        end
    end

    -- Eine Zeile je Einstellung: Name links (linke Hälfte), Bedienelement rechts ab der Mitte
    local function RowLabel(row, label, opts)
        local name = UI.Text(row, 12, "LEFT")
        name:SetPoint("LEFT")
        name:SetWordWrap(false)
        name:SetText(label)
        name:SetWidth(math.min(name:GetStringWidth() + 2, 300))
        Decorate(row, name, opts)
        return name
    end

    -- Seitentitel mit einem Satz darunter: Was ist das, wo ist es?
    function page:AddTitle(title, subtitle)
        local row = self:Row(subtitle and 40 or 22)
        local text = UI.Text(row, 17, "LEFT")
        text:SetPoint("TOPLEFT")
        text:SetText(title)
        if subtitle then
            local sub = UI.Text(row, 11, "LEFT", UI.MUTED)
            sub:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
            sub:SetPoint("RIGHT")
            sub:SetWordWrap(true)
            sub:SetText(subtitle)
            local height = 22 + 4 + math.max(sub:GetStringHeight(), 12)
            row:SetHeight(height)
            self.y = self.y - 40 + height
        end
        return row
    end

    function page:Refresh()
        for _, item in ipairs(self.items) do
            if item.Refresh then item:Refresh() end
        end
    end

    function page:AddHeader(text)
        local row = self:Row(22)
        local label = UI.Text(row, 11, "LEFT", UI.ACCENT)
        label:SetPoint("BOTTOMLEFT")
        label:SetText(text:upper())
        local line = row:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.35)
        line:SetPoint("BOTTOMLEFT", 0, -4)
        line:SetPoint("BOTTOMRIGHT", 0, -4)
        line:SetHeight(ns.PixelSize())
        return row
    end

    function page:AddNote(text)
        local label = UI.Text(self, 11, "LEFT", UI.MUTED)
        label:SetWordWrap(true)
        local width = self:GetParent():GetWidth() -- Breite des Inhaltsbereichs (fest gesetzt)
        label:SetWidth(width > 1 and width or 440)
        label:SetText(text)
        local row = self:Row(math.max(label:GetStringHeight(), 14))
        label:SetParent(row)
        label:SetPoint("TOPLEFT")
        label:SetPoint("TOPRIGHT")
        return row
    end

    function page:AddButton(label, onClick)
        local row = self:Row(24)
        row.button = UI.Button(row, label, onClick, 200)
        row.button:SetPoint("LEFT")
        return row
    end

    -- Texteingabe mit Knopf daneben; Enter oder Klick ruft onSubmit(text) auf. Gibt
    -- onSubmit true zurück, wird das Feld geleert.
    function page:AddInput(label, buttonLabel, onSubmit)
        local row = self:Row(24)
        RowLabel(row, label)

        local box = UI.EditBox(row)
        box:SetPoint("LEFT", row, "CENTER")
        box:SetPoint("RIGHT", -128, 0)
        box:SetMaxLetters(32)

        local function Submit()
            if onSubmit(box:GetText()) then box:SetText("") end
            box:ClearFocus()
        end
        box:SetScript("OnEnterPressed", Submit)
        UI.Button(row, buttonLabel, Submit, 120):SetPoint("RIGHT")
        return row
    end

    -- Textfeld mit gespeichertem Wert: Enter oder Verlassen des Felds speichert (set(text)).
    function page:AddTextField(label, get, set, maxLetters)
        local row = self:Row(24)
        RowLabel(row, label)

        local box = UI.EditBox(row)
        box:SetPoint("LEFT", row, "CENTER")
        box:SetPoint("RIGHT")
        box:SetMaxLetters(maxLetters or 32)
        box:SetScript("OnEnterPressed", box.ClearFocus)
        box:HookScript("OnEditFocusLost", function() set(strtrim(box:GetText() or "")) end)

        function row:Refresh() box:SetText(get() or "") end
        return row
    end

    -- Haken mit Text; Klick schaltet um.
    -- Viele kurze Haken nebeneinander (z. B. Emotes): je Zeile `columns` Stück, gleich breite Spalten.
    -- entries = { { label = …, get = fn, set = fn }, … }
    function page:AddCheckboxGrid(entries, columns)
        columns = columns or 3
        for first = 1, #entries, columns do
            local row = self:Row(20)
            local refreshers = {}
            for col = 0, columns - 1 do
                local entry = entries[first + col]
                if entry then
                    local set = Wrap(entry.set, entry.label, entry.opts)
                    local button = CreateFrame("Button", nil, row)
                    button:SetHeight(20)
                    button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                    button:SetPoint("RIGHT", row, "LEFT", 0, 0)
                    -- Spalte: Anteil der Zeilenbreite (Zeile hat beim Bau evtl. noch keine Breite)
                    row:HookScript("OnSizeChanged", function(_, width)
                        local w = width / columns
                        button:ClearAllPoints()
                        button:SetPoint("TOPLEFT", row, "TOPLEFT", col * w, 0)
                        button:SetSize(w - 8, 20)
                    end)
                    local box = CreateFrame("Frame", nil, button)
                    box:SetSize(16, 16)
                    box:SetPoint("LEFT")
                    UI.Box(box)
                    local check = UI.Icon(box, "Check", 14, UI.ACCENT)
                    check:SetPoint("CENTER")
                    local text = UI.Text(button, 12, "LEFT")
                    text:SetPoint("LEFT", box, "RIGHT", 8, 0)
                    text:SetPoint("RIGHT", button, "RIGHT", 0, 0)
                    text:SetWordWrap(false)
                    text:SetText(entry.label)
                    refreshers[#refreshers + 1] = function() check:SetShown(entry.get() and true or false) end
                    button:SetScript("OnClick", function()
                        set(not entry.get())
                        check:SetShown(entry.get() and true or false)
                    end)
                end
            end
            function row:Refresh() for _, refresh in ipairs(refreshers) do refresh() end end
            if row:GetWidth() and row:GetWidth() > 0 then
                row:GetScript("OnSizeChanged")(row, row:GetWidth(), row:GetHeight())
            end
        end
    end

    function page:AddCheckbox(label, get, set, opts)
        set = Wrap(set, label, opts)
        local row = self:Row(20)
        local button = CreateFrame("Button", nil, row)
        button:SetAllPoints()
        local box = CreateFrame("Frame", nil, button)
        box:SetSize(16, 16)
        box:SetPoint("LEFT")
        UI.CheckBg(box)
        local check = UI.Icon(box, "Check", 14, UI.ACCENT)
        check:SetPoint("CENTER")
        local text = UI.Text(button, 12, "LEFT")
        text:SetPoint("LEFT", box, "RIGHT", 8, 0)
        text:SetText(label)
        text:SetWidth(math.min(text:GetStringWidth() + 2, 440))
        Decorate(row, text, opts)
        function row:Refresh() check:SetShown(get() and true or false) end
        button:SetScript("OnClick", function()
            set(not get())
            row:Refresh()
        end)
        return row
    end

    -- Schieberegler: Name links, Leiste ab der Mitte, Wert rechts. Mausrad verstellt in Schritten.
    -- format(value) optional für die Anzeige (z. B. 0 > „Auto“).
    -- Schieberegler: Wert rechts zum Anklicken und Eintippen, daneben (mit default)
    -- ein Knopf, der auf den Standardwert zurücksetzt.
    function page:AddSlider(label, minValue, maxValue, step, get, set, format, default, opts)
        set = Wrap(set, label, opts)
        local row = self:Row(20)
        RowLabel(row, label, opts)

        local reset
        if default ~= nil then
            reset = UI.IconButton(row, "Reset", nil, 20)
            reset:SetPoint("RIGHT")
        end

        local value = UI.EditBox(row, 20)
        value:SetWidth(56)
        value:SetJustifyH("RIGHT")
        value:SetTextInsets(6, 6, 0, 0)
        value:SetTextColor(unpack(UI.ACCENT))
        value:SetPoint("RIGHT", reset or row, reset and "LEFT" or "RIGHT", reset and -6 or 0, 0)

        local slider = CreateFrame("Slider", nil, row)
        slider:SetOrientation("HORIZONTAL")
        slider:SetHeight(16)
        slider:SetPoint("LEFT", row, "CENTER")
        slider:SetPoint("RIGHT", value, "LEFT", -10, 0)
        slider:SetMinMaxValues(minValue, maxValue)
        slider:SetValueStep(step)
        slider:SetObeyStepOnDrag(true)
        slider:EnableMouseWheel(true)
        slider:SetHitRectInsets(0, 0, -4, -4)

        -- Leiste als Texturen unter dem Griff (ein eigener Frame läge darüber)
        local track = slider:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
        track:SetHeight(4)
        track:SetColorTexture(unpack(UI.HOVER))

        slider:SetThumbTexture(WHITE)
        local thumb = slider:GetThumbTexture()
        thumb:SetDrawLayer("OVERLAY")
        thumb:SetSize(10, 16)
        thumb:SetVertexColor(unpack(UI.ACCENT))

        local fill = slider:CreateTexture(nil, "ARTWORK") -- gefüllter Teil bis zum Griff
        fill:SetPoint("LEFT", track, "LEFT")
        fill:SetPoint("RIGHT", thumb, "CENTER")
        fill:SetHeight(4)
        fill:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.45)

        local updating = false
        local function Round(v)
            return math.floor(v / step + 0.5) * step
        end
        local function Show(v)
            value:SetText(format and format(v) or tostring(v))
            if reset then reset:SetAlpha(v == default and 0.35 or 1) end
        end
        local function Apply(v)
            v = math.min(math.max(Round(v), minValue), maxValue)
            slider:SetValue(v)
            Show(v) -- OnValueChanged kommt nicht, wenn sich der Wert nicht ändert
        end
        slider:SetScript("OnValueChanged", function(_, v)
            v = Round(v)
            Show(v)
            if not updating then set(v) end
        end)
        slider:SetScript("OnMouseWheel", function(_, delta)
            Apply(slider:GetValue() + delta * step)
        end)

        value:SetScript("OnEnterPressed", function()
            local v = tonumber((value:GetText():gsub(",", ".")))
            Apply(v or slider:GetValue())
            value:ClearFocus()
        end)
        value:HookScript("OnEditFocusGained", function() value:HighlightText() end)
        value:HookScript("OnEditFocusLost", function() Show(Round(slider:GetValue())) end)

        if reset then
            reset:SetScript("OnClick", function() Apply(default) end)
        end

        function row:Refresh()
            updating = true
            slider:SetValue(get())
            Show(get())
            updating = false
        end
        return row
    end

    -- Auswahl: Knopf mit aktuellem Eintrag, Klick öffnet eine Liste.
    -- items() liefert { { value = …, label = …, font = Pfad?, texture = Pfad? }, … }.
    function page:AddDropdown(label, items, get, set, opts)
        set = Wrap(set, label, opts)
        local row = self:Row(24)
        RowLabel(row, label, opts)

        local button = CreateFrame("Button", nil, row)
        button:SetPoint("LEFT", row, "CENTER")
        button:SetPoint("RIGHT")
        button:SetHeight(24)
        local bg = UI.Box(button)
        local current = UI.Text(button, 12, "LEFT")
        current:SetPoint("LEFT", 8, 0)
        current:SetPoint("RIGHT", -24, 0)
        local arrow = UI.Icon(button, "ChevronDown", 16, UI.ACCENT)
        arrow:SetPoint("RIGHT", -6, 0)
        button:SetScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
        button:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)

        function row:Refresh()
            local value = get()
            current:SetText(value)
            for _, item in ipairs(items()) do
                if item.value == value then current:SetText(item.label) end
            end
        end
        button:SetScript("OnClick", function()
            UI.OpenList(button, items(), get(), function(value)
                set(value)
                row:Refresh()
            end)
        end)
        return row
    end

    return page
end

-- Aufklappliste (eine für alle Auswahlen). Zeigt bis zu MAX_ROWS Einträge, Mausrad blättert.
-- Einträge mit font erscheinen in ihrer Schrift, mit texture auf einem Vorschau-Balken.
-- inert = Überschrift (kein Hover, kein Klick); actions = kleine Symbole rechts in der Zeile
-- ({ icon = Media-Name oder atlas = Atlas, tooltip, onClick }), z. B. Umbenennen/Löschen.
local MAX_ROWS = 16 -- Talent-Berater: Kategorien mit Überschriften
local ROW_HEIGHT = 22
local list

local function CreateList()
    list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    UI.Box(list, { 0.06, 0.06, 0.07, 0.98 })
    -- Kontextmenü: Salbei-Linie oben wie bei den mUI-Fenstern
    list.accent = list:CreateTexture(nil, "OVERLAY")
    list.accent:SetPoint("TOPLEFT")
    list.accent:SetPoint("TOPRIGHT")
    list.accent:SetHeight(2 * ns.PixelSize())
    list.accent:SetColorTexture(unpack(UI.ACCENT))
    list.accent:Hide()
    list.rows = {}
    list.pad = 0
    for i = 1, MAX_ROWS do
        local rowButton = CreateFrame("Button", nil, list)
        rowButton:SetHeight(ROW_HEIGHT)
        local hover = rowButton:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(unpack(UI.HOVER))
        hover:Hide()
        rowButton.preview = rowButton:CreateTexture(nil, "BORDER")
        rowButton.preview:SetPoint("TOPLEFT", 4, -3)
        rowButton.preview:SetPoint("BOTTOMRIGHT", -4, 3)
        -- Symbol links (item.icon = Media-Name), senkrecht mittig zur Zeile
        rowButton.icon = rowButton:CreateTexture(nil, "OVERLAY")
        rowButton.icon:SetSize(14, 14)
        rowButton.icon:SetPoint("LEFT", 8, 0)
        rowButton.icon:Hide()
        rowButton.text = rowButton:CreateFontString(nil, "OVERLAY")
        rowButton.text:SetPoint("LEFT", 8, 0)
        rowButton.text:SetPoint("RIGHT", -8, 0)
        rowButton.text:SetJustifyH("LEFT")
        rowButton.text:SetWordWrap(false)
        rowButton.text:SetShadowOffset(1, -1)
        rowButton:SetScript("OnEnter", function(self) hover:SetShown(not self.inert) end)
        rowButton:SetScript("OnLeave", function() hover:Hide() end)
        rowButton:SetScript("OnClick", function(self)
            if self.inert then return end
            list.onSelect(self.value)
            list:Hide()
        end)
        rowButton.hover = hover
        -- Trennlinie über dem Eintrag (separator = true), z. B. vor „Aufgeben“
        rowButton.sep = rowButton:CreateTexture(nil, "ARTWORK")
        rowButton.sep:SetPoint("TOPLEFT", 8, 0)
        rowButton.sep:SetPoint("TOPRIGHT", -8, 0)
        rowButton.sep:SetHeight(ns.PixelSize())
        rowButton.sep:SetColorTexture(1, 1, 1, 0.1)
        rowButton.sep:Hide()
        rowButton.actions = {}
        for a = 1, 2 do
            local action = CreateFrame("Button", nil, rowButton)
            action:SetSize(16, 16)
            action:SetPoint("RIGHT", -6 - (a - 1) * 20, 0)
            action.icon = action:CreateTexture(nil, "OVERLAY")
            action.icon:SetAllPoints()
            action:SetScript("OnEnter", function(self)
                hover:Show()
                self.icon:SetVertexColor(unpack(UI.ACCENT))
                if self.tooltip then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.tooltip)
                    GameTooltip:Show()
                end
            end)
            action:SetScript("OnLeave", function(self)
                hover:Hide()
                self.icon:SetVertexColor(unpack(UI.MUTED))
                GameTooltip:Hide()
            end)
            action:SetScript("OnClick", function(self)
                list:Hide()
                GameTooltip:Hide()
                if self.onClick then self.onClick() end
            end)
            rowButton.actions[a] = action
        end
        list.rows[i] = rowButton
    end

    function list:Render()
        -- Zeilen untereinander; Titel (item.title) bekommt mehr Höhe, Kontextmenü Rand oben/unten
        local y = 1 + self.pad
        for i, rowButton in ipairs(self.rows) do
            local item = self.items[self.offset + i]
            local h = item and item.title and (ROW_HEIGHT + 6) or ROW_HEIGHT
            rowButton:SetHeight(h)
            rowButton:ClearAllPoints()
            rowButton:SetPoint("TOPLEFT", 1, -y)
            rowButton:SetPoint("TOPRIGHT", -1, -y)
            if item then y = y + h end
        end
        self.contentHeight = y - 1 - self.pad
        for i, rowButton in ipairs(self.rows) do
            local item = self.items[self.offset + i]
            rowButton:SetShown(item ~= nil)
            if item then
                rowButton.value = item.value
                if not (item.font and rowButton.text:SetFont(item.font, 13, "")) then
                    rowButton.text:SetFont(ns.STYLE.font, ns.FontPx(13), "")
                end
                rowButton.text:SetText(item.label)
                local selected = item.value == self.selected
                rowButton.text:SetTextColor(unpack(selected and UI.ACCENT or UI.TEXT))
                rowButton.preview:SetShown(item.texture ~= nil)
                if item.texture then
                    rowButton.preview:SetTexture(item.texture)
                    rowButton.preview:SetVertexColor(0.19, 0.6, 0.15)
                end
                rowButton.inert = item.inert
                rowButton.sep:SetShown(item.separator and true or false)
                if item.color then rowButton.text:SetTextColor(unpack(item.color)) end
                rowButton.icon:SetShown(item.icon ~= nil)
                if item.icon then
                    rowButton.icon:SetTexture(ns.MEDIA .. "Icons\\" .. item.icon)
                    rowButton.icon:SetVertexColor(unpack(item.iconColor or item.color or UI.MUTED))
                end
                rowButton.text:SetPoint("LEFT", item.icon and 30 or 8, 0)
                for a, action in ipairs(rowButton.actions) do
                    local info = item.actions and item.actions[a]
                    action:SetShown(info ~= nil)
                    if info then
                        if info.atlas then
                            action.icon:SetAtlas(info.atlas)
                        else
                            action.icon:SetTexture(ns.MEDIA .. "Icons\\" .. info.icon)
                            action.icon:SetTexCoord(0, 1, 0, 1) -- Atlas-Ausschnitt einer früheren Zeile zurücksetzen
                        end
                        action.icon:SetDesaturated(true)
                        action.icon:SetVertexColor(unpack(UI.MUTED))
                        action.tooltip, action.onClick = info.tooltip, info.onClick
                    end
                end
                rowButton.text:SetPoint("RIGHT", -8 - (item.actions and #item.actions * 20 or 0), 0)
            end
        end
    end

    list:SetScript("OnMouseWheel", function(self, delta)
        local maxOffset = math.max(#self.items - MAX_ROWS, 0)
        self.offset = math.min(math.max(self.offset - delta * 3, 0), maxOffset)
        self:Render()
    end)

    -- Klick daneben schließt die Liste
    list:RegisterEvent("GLOBAL_MOUSE_DOWN")
    list:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
            self:Hide()
        end
    end)
end

-- opts.menu = Kontextmenü (Rechtsklick): an der Maus statt unter dem Auslöser, Breite nach Inhalt,
-- Salbei-Linie oben; opts.title = Überschrift (z. B. Questname) mit Linie darunter.
function UI.OpenList(owner, items, selected, onSelect, opts)
    if not list then CreateList() end
    if opts and opts.title then
        local withTitle = { { value = "__title", inert = true, title = true, label = opts.title, color = UI.ACCENT,
            icon = opts.titleIcon } }
        for index, item in ipairs(items) do
            withTitle[#withTitle + 1] = item
            if index == 1 then item.separator = true end
        end
        items = withTitle
    end
    if list:IsShown() and list.owner == owner then
        list:Hide()
        return
    end
    list.owner, list.items, list.selected, list.onSelect = owner, items, selected, onSelect
    list.offset = 0
    for index, item in ipairs(items) do -- Auswahl sichtbar machen
        if item.value == selected then list.offset = math.max(math.min(index - 3, #items - MAX_ROWS), 0) end
    end
    -- mindestens so breit wie der Auslöser, sonst so breit wie der längste Eintrag (Namen nie abschneiden)
    if not list.measure then
        -- unsichtbar, aber nicht versteckt: versteckte Texte messen teils 0 (Liste blieb so schmal
        -- wie der Auslöser und schnitt lange Namen ab)
        list.measure = list:CreateFontString(nil, "OVERLAY")
        list.measure:SetAlpha(0)
        list.measure:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100)
    end
    local menu = opts and opts.menu
    local width = menu and 160 or owner:GetWidth()
    for _, item in ipairs(items) do
        if not (item.font and list.measure:SetFont(item.font, 13, "")) then list.measure:SetFont(ns.STYLE.font, ns.FontPx(13), "") end
        list.measure:SetText(item.label or "")
        -- Rand: 1 px Rahmen + 8 px Text-Einzug je Seite + Puffer für Rundung (sonst „Östliche Königreic…“)
        local needed = list.measure:GetUnboundedStringWidth() + 28 + (item.actions and #item.actions * 20 or 0)
            + (item.icon and 22 or 0)
            + (#items > MAX_ROWS and 6 or 0)
        if needed > width then width = needed end
    end
    list:ClearAllPoints()
    if menu then
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 4, y / scale - 4)
    else
        list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    end
    list.accent:SetShown(menu and true or false)
    list.pad = menu and 4 or 0
    list:SetWidth(math.ceil(width))
    list:SetClampedToScreen(true)
    list:Render()
    list:SetHeight(list.contentHeight + 2 + 2 * list.pad)
    list:Show()
end

function UI.CloseList()
    if list then list:Hide() end
end
