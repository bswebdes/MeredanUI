-- Controls for the settings window in mUI style: flat, dark, 1 px border, Surf Green accent.
-- Each page stacks its elements top to bottom (page:Add...).
-- Elements with a value have :Refresh(), which shows the current value from get().
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local UI = {}
ns.UI = UI

-- Brand accent color: Surf Green
UI.ACCENT = { 0.557, 0.796, 0.706 } -- #8ecbb4
UI.ACCENT_HEX = "|cff8ecbb4"

-- Optional class accent: Blizzard class colours brought to Surf Green's lightness and chroma
-- (OKLCH), hue kept. Priest gets a warm grey since white has no hue.
local CLASS_ACCENTS = {
    WARRIOR = "dbb48b", PALADIN = "e1a9c0", HUNTER = "afc594", ROGUE = "c2bf8a", PRIEST = "ccc8c0",
    SHAMAN = "9ebee9", MAGE = "87c7db", WARLOCK = "b3b7e9", DRUID = "e2af93",
}
-- Called once the profile is loaded, before windows are built; changes in place so every
-- reference to UI.ACCENT sees it. Switching back needs a reload.
-- classAccent: false = mUI green, true = muted class colour, "blizzard" = Blizzard's class colour
function UI.ApplyClassAccent()
    if not (ns.db and ns.db.classAccent) then return end
    local _, class = UnitClass("player")
    local hex = class and CLASS_ACCENTS[class]
    if ns.db.classAccent == "blizzard" then
        local c = class and RAID_CLASS_COLORS[class]
        hex = c and ("%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
    end
    if not hex then return end
    for i = 1, 3 do UI.ACCENT[i] = tonumber(hex:sub(i * 2 - 1, i * 2), 16) / 255 end
    UI.ACCENT_HEX = "|cff" .. hex
end
UI.TEXT = { 0.91, 0.9, 0.87 }
UI.MUTED = { 0.6, 0.59, 0.56 }
UI.FIELD = { 0.09, 0.075, 0.05, 1 } -- buttons, inputs: dark warm brown (rune look)
UI.HOVER = { 0.16, 0.13, 0.085, 1 }

UI.TAG = { 0.85, 0.64, 0.25 }  -- "Reload" badge (gold)

local ROW_GAP = 12
local L = ns.L

-- Set by the window: tracks changes that need a reload (bar at the bottom)
UI.MarkReload = function(_) end

-- Background with 1 px border and fixed color (independent of the theme).
-- noBorder: windows in the rune look draw ns.RuneFrame instead of the outline
function UI.Box(frame, color, noBorder)
    -- a plain field (no colour, with border) is a sunk groove (building block B11)
    if not color and not noBorder then return UI.Groove(frame) end
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(color or UI.FIELD))
    if not noBorder then ns.AddBorder(frame) end
    return bg
end

local function Line(frame, layer, sub)
    local t = frame:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(WHITE)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
    return t
end

-- Groove (B11): dark field sunk into the surface - black top/left edge, lit bottom edge in the
-- frame material, a soft shadow under the top edge. Returns the fill (callers recolour it on hover).
function UI.Groove(frame)
    local px = ns.PixelSize()
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.FIELD))
    local shade = Line(frame, "BACKGROUND", 1)
    shade:SetPoint("TOPLEFT")
    shade:SetPoint("TOPRIGHT")
    shade:SetHeight(ns.Snap(4))
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.7))
    local m = ns.Material()
    local top, left, bottom, right = Line(frame, "BORDER"), Line(frame, "BORDER"), Line(frame, "BORDER"), Line(frame, "BORDER")
    top:SetPoint("TOPLEFT") top:SetPoint("TOPRIGHT") top:SetHeight(px)
    left:SetPoint("TOPLEFT") left:SetPoint("BOTTOMLEFT") left:SetWidth(px)
    bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(px)
    right:SetPoint("TOPRIGHT") right:SetPoint("BOTTOMRIGHT") right:SetWidth(px)
    top:SetVertexColor(0, 0, 0, 1)
    left:SetVertexColor(0, 0, 0, 1)
    bottom:SetVertexColor(m.item[1], m.item[2], m.item[3], 0.85)
    right:SetGradient("VERTICAL", CreateColor(m.item[1], m.item[2], m.item[3], 0.85), CreateColor(0, 0, 0, 1))
    frame.muiGrooveEdges = { top, bottom, left, right }
    return bg
end

-- Bevel (B9): raised button - black outline, edge lit from above in the frame material, a warm
-- fill shading top to bottom. button.muiBevel(state) with "normal", "hover" or "down".
local BEVEL_FILL = {
    normal = { { 0.235, 0.188, 0.133 }, { 0.149, 0.114, 0.078 } },
    hover = { { 0.329, 0.263, 0.184 }, { 0.2, 0.153, 0.106 } },
    down = { { 0.094, 0.071, 0.047 }, { 0.165, 0.125, 0.086 } },
}
function UI.Bevel(button)
    local px = ns.PixelSize()
    local m = ns.Material()
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture(WHITE)
    fill:SetPoint("TOPLEFT", 2 * px, -2 * px)
    fill:SetPoint("BOTTOMRIGHT", -2 * px, 2 * px)
    -- outline (black) and lit edge inside it
    for _, e in ipairs(ns.AddBorder(button, true, 1)) do e:SetVertexColor(0, 0, 0, 1) end
    local top, bottom, left, right = Line(button, "BORDER", 1), Line(button, "BORDER", 1), Line(button, "BORDER", 1), Line(button, "BORDER", 1)
    top:SetPoint("TOPLEFT", px, -px) top:SetPoint("TOPRIGHT", -px, -px) top:SetHeight(px)
    bottom:SetPoint("BOTTOMLEFT", px, px) bottom:SetPoint("BOTTOMRIGHT", -px, px) bottom:SetHeight(px)
    left:SetPoint("TOPLEFT", px, -px) left:SetPoint("BOTTOMLEFT", px, px) left:SetWidth(px)
    right:SetPoint("TOPRIGHT", -px, -px) right:SetPoint("BOTTOMRIGHT", -px, px) right:SetWidth(px)
    top:SetVertexColor(unpack(m.lit))
    bottom:SetVertexColor(unpack(m.dark))
    for _, e in ipairs({ left, right }) do e:SetGradient("VERTICAL", CreateColor(unpack(m.dark)), CreateColor(unpack(m.lit))) end
    local shine = Line(button, "BACKGROUND", 1)
    shine:SetPoint("TOPLEFT", 2 * px, -2 * px)
    shine:SetPoint("TOPRIGHT", -2 * px, -2 * px)
    shine:SetHeight(px)
    shine:SetVertexColor(1, 0.9, 0.7, 0.18)
    local function State(state)
        local c = BEVEL_FILL[state] or BEVEL_FILL.normal
        fill:SetGradient("VERTICAL", CreateColor(c[2][1], c[2][2], c[2][3], 1), CreateColor(c[1][1], c[1][2], c[1][3], 1))
        shine:SetShown(state ~= "down")
    end
    State("normal")
    button.muiBevel = State
    button:HookScript("OnMouseDown", function() State("down") end)
    button:HookScript("OnMouseUp", function(self) State(self:IsMouseOver() and "hover" or "normal") end)
    return fill
end

-- Checkbox: dark fill with a light border so it is visible on dark backgrounds
UI.CHECK_EDGE = { 0.5, 0.4, 0.24, 1 } -- bronze
function UI.CheckBg(frame)
    -- B12: a sunk groove inside a frame-material edge (like a tiny item frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.04, 0.03, 1)
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetTexture(WHITE)
    shade:SetPoint("TOPLEFT")
    shade:SetPoint("TOPRIGHT")
    shade:SetHeight(ns.Snap(4))
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.8))
    -- Border drawn inside: otherwise a checkbox at the far left of a clipped list lost its left edge
    for _, edge in ipairs(ns.AddBorder(frame, true)) do
        edge:SetVertexColor(unpack(ns.Material().item))
        -- In scrolling lists the box often sits on a half pixel; pixel snapping would round the 1 px edge
        -- away (top or bottom missing). Without snapping it stays visible.
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

-- Rune look: section headings in Cinzel and bronze-gold, window titles in Cinzel (UI.Title)
UI.HEADING = { 0.79, 0.67, 0.45 }
UI.TITLE = { 0.94, 0.91, 0.84 }
function UI.Heading(parent, size, justify)
    local text = ns.CreateText(parent, size or 12, justify, nil, "display")
    text:SetTextColor(unpack(UI.HEADING))
    return text
end

function UI.Title(parent, size, justify)
    local text = ns.CreateText(parent, size or 16, justify, nil, "display")
    text:SetTextColor(unpack(UI.TITLE))
    return text
end

-- Divider (rune look): bronze lines fading in towards an accent diamond in the middle.
-- Returns a frame (height 10) for the caller to anchor left and right.
function UI.Divider(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(10)
    local r, g, b = unpack(ns.BRONZE)
    local px = ns.PixelSize()
    local function Half(fromLeft)
        local tex = holder:CreateTexture(nil, "ARTWORK")
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetHeight(px)
        local faded, full = CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.8)
        if fromLeft then
            tex:SetPoint("LEFT")
            tex:SetPoint("RIGHT", holder, "CENTER", -10, 0)
            tex:SetGradient("HORIZONTAL", faded, full)
        else
            tex:SetPoint("LEFT", holder, "CENTER", 10, 0)
            tex:SetPoint("RIGHT")
            tex:SetGradient("HORIZONTAL", full, faded)
        end
    end
    Half(true)
    Half(false)
    UI.Diamond(holder, 7):SetPoint("CENTER")
    return holder
end

-- Small accent diamond, the rune look's mark (a rotated square)
-- Accent mark: a small cut gem in its bezel (B4). Returns the gem texture (tintable); the bezel
-- follows its position and visibility. size = the old diamond size, the gem is drawn larger.
function UI.Diamond(parent, size, color, layer)
    local px = ns.PixelSize()
    local pixels = math.floor((size or 6) * 1.9 / px + 0.5)
    if pixels % 2 == 0 then pixels = pixels + 1 end -- odd: sits centred on a 1 px line
    local bezel = parent:CreateTexture(nil, layer or "OVERLAY", nil, 1)
    bezel:SetTexture(ns.MEDIA .. "GemBezel")
    ns.StyleOrnament(bezel)
    local tex = parent:CreateTexture(nil, layer or "OVERLAY", nil, 2)
    tex:SetTexture(ns.MEDIA .. "Gem")
    tex:SetVertexColor(unpack(color or UI.ACCENT))
    tex:SetSize(pixels * px, pixels * px)
    bezel:SetAllPoints(tex)
    hooksecurefunc(tex, "Show", function() bezel:Show() end)
    hooksecurefunc(tex, "Hide", function() bezel:Hide() end)
    hooksecurefunc(tex, "SetShown", function(_, shown) bezel:SetShown(shown) end)
    hooksecurefunc(tex, "SetAlpha", function(_, a) bezel:SetAlpha(a) end)
    tex.muiBezel = bezel
    return tex
end

-- Icon from Media/Icons (authored white), tinted.
function UI.Icon(parent, name, size, color, flat)
    local icon = parent:CreateTexture(nil, "OVERLAY")
    icon:SetSize(size, size)
    ns.SetIcon(icon, name, flat)
    icon:SetVertexColor(unpack(color or UI.TEXT))
    return icon
end

-- Icon-only button (e.g. close); brightens on hover.
function UI.IconButton(parent, name, onClick, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size or 24, size or 24)
    -- no box: the (painted) icon stands on its own and brightens on hover
    local icon = UI.Icon(button, name, (size or 24) - 4)
    icon:SetPoint("CENTER")
    button.icon = icon
    button:SetScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
    button:SetScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
    button:SetScript("OnClick", onClick)
    return button
end

-- Arrow button for paging ("left"/"right"), greyed out when disabled.
function UI.ArrowButton(parent, direction, onClick, size)
    local button = UI.IconButton(parent, "ChevronDown", onClick, size)
    button.icon:SetRotation(direction == "left" and -math.pi / 2 or math.pi / 2)
    hooksecurefunc(button, "SetEnabled", function(self, on)
        self.icon:SetAlpha(on and 1 or 0.3)
    end)
    return button
end

-- Own icon (Media/Icons) as inline texture, tinted - instead of special characters like a check
-- mark that our font lacks (tools/check_glyphs.py checks this).
-- yOffset: positive = higher. Next to text, icons otherwise sit too low: for 11-13 px icons and
-- the normal mUI font use 1-2 (13 px clock in the tracker: 1; 0 too low, 2 too high).
function UI.IconMarkup(name, size, color, yOffset)
    local c = ns.PAINTED_ICONS[name] and { 1, 1, 1 } or color or UI.TEXT
    return ("|T%s:%d:%d:0:%d:64:64:0:64:0:64:%d:%d:%d|t"):format(ns.IconPath(name), size or 12, size or 12,
        yOffset or 0, c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.ArrowMarkup(size)
    return CreateAtlasMarkup("common-icon-forwardarrow", size or 10, size or 10, 0, 0, 150, 150, 150)
end

-- Help tooltip (the "i" in settings): plain 12 px body text instead of Blizzard's bold, larger
-- title line (SetText uses the header font). The first line gets its header font back on hide,
-- otherwise item titles would be small.
function UI.ShowHelp(owner, text)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 0.91, 0.9, 0.87, 1, true)
    GameTooltipTextLeft1:SetFont(ns.FontFor("text"), ns.FontPx(12), "")
    -- more line spacing: wrapped explanations read more easily
    if not UI.helpSpacing then UI.helpSpacing = GameTooltipTextLeft1:GetSpacing() or 0 end
    GameTooltipTextLeft1:SetSpacing(4)
    GameTooltip:Show()
end
function UI.HideHelp()
    GameTooltip:Hide()
    GameTooltipTextLeft1:SetFontObject(GameTooltipHeaderText)
    GameTooltipTextLeft1:SetSpacing(UI.helpSpacing or 0)
end

-- Plain text button; brightens on hover.
function UI.Button(parent, label, onClick, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 160, 26)
    UI.Bevel(button)
    local text = UI.Text(button, 12, "CENTER")
    text:SetPoint("CENTER")
    text:SetText(label)
    button.Text = text
    button:SetScript("OnEnter", function(self) self.muiBevel("hover") text:SetTextColor(1, 0.95, 0.84) end)
    button:SetScript("OnLeave", function(self) self.muiBevel("normal") text:SetTextColor(unpack(UI.TEXT)) end)
    button:SetScript("OnClick", onClick)
    return button
end

-- Flat edit box; focus shows a Surf Green border.
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

-- mUI-style scrollbar for all lists (also for accessibility): arrows top/bottom, thin track
-- with a Surf Green thumb. Drag the thumb, click the track to page, hover widens and brightens
-- the thumb; hit areas are 14 px wide.
-- opts: GetRange() (max offset), GetOffset() (0 = top), SetOffset(v), GetRatio() (visible
-- fraction 0-1), step (arrow step), page (page step)
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
    -- B13: narrow groove with a frame-material grip
    local groove = CreateFrame("Frame", nil, track)
    groove:SetPoint("TOP")
    groove:SetPoint("BOTTOM")
    groove:SetWidth(ns.Snap(6))
    UI.Groove(groove)
    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(14)
    local grip = thumb:CreateTexture(nil, "ARTWORK")
    grip:SetTexture(WHITE)
    grip:SetPoint("TOP")
    grip:SetPoint("BOTTOM")
    grip:SetWidth(ns.Snap(6))
    local gm = ns.Material()
    grip:SetGradient("HORIZONTAL", CreateColor(unpack(gm.dark)), CreateColor(unpack(gm.lit)))
    local hovered, dragging = false, nil
    local function Highlight()
        local on = hovered or dragging ~= nil
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

-- Area with mouse wheel scrolling and mUI scrollbar on the right (only shown when the content
-- doesn't fit). area.child holds the content; call area:SetContentHeight(h) after filling.
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

    -- jump to a position in the content (clamped to the scroll range)
    function area:ScrollTo(offset)
        self:SetVerticalScroll(math.min(math.max(offset, 0), Range()))
        Update()
    end

    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(self, delta)
        UI.CloseList() -- otherwise the list would drift away from the field
        self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - delta * 40, 0), Range()))
        Update()
    end)
    area:SetScript("OnSizeChanged", function(self, width)
        -- room for the 1px borders that sit outside right-aligned fields (else clipped by the scroll frame)
        child:SetWidth(width - 2)
        Update()
    end)
    return area
end

-- Page: elements are stacked vertically.
function UI.Page(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.y = 0
    page.items = {}

    -- Reserve space for an element and return its frame.
    function page:Row(height)
        local row = CreateFrame("Frame", nil, self)
        row:SetPoint("TOPLEFT", 0, -self.y)
        row:SetPoint("TOPRIGHT", 0, -self.y)
        row:SetHeight(height)
        self.y = self.y + height + ROW_GAP
        self.items[#self.items + 1] = row
        return row
    end

    -- Rows first..last (page.items indices) greyed out and not clickable, e.g. while another addon
    -- does the job; a mouse-catching layer on top explains why (reason = tooltip text)
    function page:LockRows(first, last, reason)
        for i = first, math.min(last or #self.items, #self.items) do
            local row = self.items[i]
            row:SetAlpha(0.35)
            local shield = CreateFrame("Frame", nil, row)
            shield:SetAllPoints()
            shield:SetFrameLevel(row:GetFrameLevel() + 60) -- above checkboxes, dropdowns and "i"
            shield:EnableMouse(true)
            if reason then
                shield:SetScript("OnEnter", function(self) UI.ShowHelp(self, reason) end)
                shield:SetScript("OnLeave", function() UI.HideHelp() end)
            end
        end
    end

    -- Extras after a label: "Reload" badge (gold) and an "i" with an explanation tooltip.
    -- opts = { reload = true, help = "..." }
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
            info:SetFrameLevel(row:GetFrameLevel() + 10) -- above checkbox button, slider and dropdown
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

    -- set() with reload badge: records the change for the bar at the bottom
    local function Wrap(set, label, opts)
        if not (opts and opts.reload) then return set end
        return function(value)
            set(value)
            UI.MarkReload(label)
        end
    end

    -- One row per setting: name on the left half, control from the middle to the right
    local function RowLabel(row, label, opts)
        local name = UI.Text(row, 12, "LEFT")
        name:SetPoint("LEFT")
        name:SetWordWrap(false)
        name:SetText(label)
        name:SetWidth(math.min(name:GetStringWidth() + 2, 300))
        Decorate(row, name, opts)
        return name
    end

    -- Page title with one sentence below: what is it, where is it?
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

    -- rune look: diamond, Cinzel heading, bronze line running to the right
    function page:AddHeader(text)
        local row = self:Row(22)
        local diamond = UI.Diamond(row, 5)
        diamond:SetPoint("BOTTOMLEFT", 1, 4)
        local label = UI.Heading(row, 12, "LEFT")
        label:SetPoint("BOTTOMLEFT", 14, 0)
        label:SetText(text:upper())
        local line = row:CreateTexture(nil, "ARTWORK")
        local br, bg, bb = unpack(ns.BRONZE)
        line:SetColorTexture(br, bg, bb, 0.3)
        line:SetPoint("LEFT", label, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", row, "RIGHT")
        line:SetHeight(ns.PixelSize())
        return row
    end

    function page:AddNote(text)
        local label = UI.Text(self, 11, "LEFT", UI.MUTED)
        label:SetWordWrap(true)
        local width = self:GetParent():GetWidth() -- content area width (fixed)
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

    -- Text input with a button; Enter or click calls onSubmit(text). If onSubmit returns true,
    -- the field is cleared.
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

    -- Text field with a stored value: Enter or leaving the field saves (set(text)).
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

    -- Checkbox with text; click toggles.
    -- Many short checkboxes side by side (e.g. emotes): `columns` per row, equal-width columns.
    -- entries = { { label = ..., get = fn, set = fn, disabled = fn? }, ... }; disabled() greys an
    -- entry out and ignores clicks (e.g. a limit is reached)
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
                    -- Column: fraction of the row width (the row may have no width yet while building)
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
                    local function Refresh()
                        check:SetShown(entry.get() and true or false)
                        button:SetAlpha(entry.disabled and entry.disabled() and 0.35 or 1)
                    end
                    refreshers[#refreshers + 1] = Refresh
                    button:SetScript("OnClick", function()
                        if entry.disabled and entry.disabled() then return end
                        set(not entry.get())
                        Refresh()
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

    -- Slider: name on the left, bar from the middle, value on the right. Mouse wheel steps.
    -- format(value) optional for display (e.g. 0 -> "Auto"). The value can be clicked and typed;
    -- with default, a button next to it resets to the default value.
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

        -- Bar as textures below the thumb (a separate frame would sit on top)
        -- B12: groove track, filled part in the frame material, a gem as the thumb
        local trackFrame = CreateFrame("Frame", nil, slider)
        trackFrame:SetPoint("LEFT")
        trackFrame:SetPoint("RIGHT")
        trackFrame:SetHeight(ns.Snap(6))
        trackFrame:SetFrameLevel(math.max(slider:GetFrameLevel() - 1, 0))
        UI.Groove(trackFrame)
        local track = trackFrame

        slider:SetThumbTexture(ns.MEDIA .. "GemBezel")
        local thumb = slider:GetThumbTexture()
        thumb:SetDrawLayer("OVERLAY", 1)
        local tpx = ns.PixelSize()
        local tsize = (math.floor(17 / tpx) % 2 == 0 and math.floor(17 / tpx) + 1 or math.floor(17 / tpx)) * tpx
        thumb:SetSize(tsize, tsize)
        ns.StyleOrnament(thumb)
        local gem = slider:CreateTexture(nil, "OVERLAY", nil, 2)
        gem:SetTexture(ns.MEDIA .. "Gem")
        gem:SetVertexColor(unpack(UI.ACCENT))
        gem:SetAllPoints(thumb)

        local fill = slider:CreateTexture(nil, "ARTWORK") -- filled part up to the thumb
        fill:SetTexture(WHITE)
        fill:SetPoint("LEFT", track, "LEFT", tpx, 0)
        fill:SetPoint("RIGHT", thumb, "CENTER")
        fill:SetHeight(ns.Snap(4))
        local fm = ns.Material()
        fill:SetGradient("VERTICAL", CreateColor(unpack(fm.dark)), CreateColor(unpack(fm.lit)))

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
            Show(v) -- OnValueChanged doesn't fire if the value doesn't change
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

    -- Dropdown: button with the current entry, click opens a list.
    -- items() returns { { value = ..., label = ..., font = path?, texture = path? }, ... }.
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

    -- Two dropdowns in one row (action bars: visibility + texts).
    -- Left a normal one (items/get/set), right one with checkboxes: multi = function() ->
    -- { { value, label, checked }, ... }, toggle(value) toggles a checkbox, summary() = short text.
    function page:AddDualDropdown(label, items, get, set, multi, toggle, summary, opts)
        set = Wrap(set, label, opts)
        local row = self:Row(24)
        RowLabel(row, label, opts)
        local function Field()
            local button = CreateFrame("Button", nil, row)
            button:SetHeight(24)
            local bg = UI.Box(button)
            button.current = UI.Text(button, 12, "LEFT")
            button.current:SetPoint("LEFT", 8, 0)
            button.current:SetPoint("RIGHT", -24, 0)
            button.current:SetWordWrap(false)
            local arrow = UI.Icon(button, "ChevronDown", 16, UI.ACCENT)
            arrow:SetPoint("RIGHT", -6, 0)
            button:SetScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
            button:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
            return button
        end
        local left, right = Field(), Field()
        left:SetPoint("LEFT", row, "CENTER")
        left:SetPoint("RIGHT", row, "RIGHT", -100 - 6, 0) -- leave room for the second field on the right
        right:SetPoint("LEFT", left, "RIGHT", 6, 0)
        right:SetPoint("RIGHT")
        -- left field slightly wider: visibility has the longer words
        row:HookScript("OnSizeChanged", function(_, width)
            local half = width / 2
            left:SetPoint("RIGHT", row, "RIGHT", -math.floor((half - 6) * 0.45) - 6, 0)
        end)

        function row:Refresh()
            local value = get()
            left.current:SetText(value)
            for _, item in ipairs(items()) do
                if item.value == value then left.current:SetText(item.label) end
            end
            right.current:SetText(summary())
        end
        left:SetScript("OnClick", function()
            UI.OpenList(left, items(), get(), function(value)
                set(value)
                row:Refresh()
            end)
        end)
        right:SetScript("OnClick", function()
            UI.OpenList(right, multi(), nil, function(value)
                toggle(value)
                row:Refresh()
            end, { multi = multi })
        end)
        return row
    end

    return page
end

-- Dropdown list (one shared by all dropdowns). Shows up to MAX_ROWS entries, mouse wheel scrolls.
-- Entries with font render in that font, with texture on a preview bar.
-- inert = heading (no hover, no click); actions = small icons on the right of the row
-- ({ icon = media name or atlas = atlas, tooltip, onClick }), e.g. rename/delete.
local MAX_ROWS = 16 -- talent advisor: categories with headings
local ROW_HEIGHT = 22
local list

local function CreateList()
    list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:EnableMouse(true)
    list:EnableMouseWheel(true)
    UI.Box(list, { 0.06, 0.06, 0.07, 0.98 })
    -- Context menu: accent line on top like mUI windows
    list.accent = ns.RuneFrame(list, { small = true })
    list.accent:SetShown(false)
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
        -- Icon on the left (item.icon = media name), vertically centered in the row
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
            if list.multi then -- checkbox list stays open, re-read entries
                list.items = list.multi()
                list:Render()
                return
            end
            list:Hide()
        end)
        rowButton.hover = hover
        -- Divider above the entry (separator = true), e.g. before "Abandon"
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
        -- Rows stacked; titles (item.title) get more height, context menu gets top/bottom padding
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
                    ns.SetIcon(rowButton.icon, item.icon)
                    rowButton.icon:SetVertexColor(unpack(item.iconColor or item.color or UI.MUTED))
                end
                if list.multi then -- checkbox on the left, text always indented the same
                    rowButton.icon:SetShown(item.checked and true or false)
                    ns.SetIcon(rowButton.icon, "Check")
                    rowButton.icon:SetVertexColor(unpack(UI.ACCENT))
                    rowButton.text:SetTextColor(unpack(item.checked and UI.TEXT or UI.MUTED))
                end
                rowButton.text:SetPoint("LEFT", (item.icon or list.multi) and 30 or 8, 0)
                for a, action in ipairs(rowButton.actions) do
                    local info = item.actions and item.actions[a]
                    action:SetShown(info ~= nil)
                    if info then
                        if info.atlas then
                            action.icon:SetAtlas(info.atlas)
                        else
                            ns.SetIcon(action.icon, info.icon)
                            action.icon:SetTexCoord(0, 1, 0, 1) -- reset atlas tex coords from a previous row
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

    -- Clicking outside closes the list
    list:RegisterEvent("GLOBAL_MOUSE_DOWN")
    list:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
            self:Hide()
        end
    end)
end

-- opts.menu = context menu (right-click): at the cursor instead of below the owner, width fits
-- content, accent line on top; opts.title = heading (e.g. quest name) with a line below.
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
    list.multi = opts and opts.multi or nil
    list.offset = 0
    for index, item in ipairs(items) do -- scroll the selection into view
        if item.value == selected then list.offset = math.max(math.min(index - 3, #items - MAX_ROWS), 0) end
    end
    -- at least as wide as the owner, otherwise as wide as the longest entry (never truncate names)
    if not list.measure then
        -- invisible but not hidden: hidden font strings sometimes measure 0 (the list stayed as narrow
        -- as the owner and truncated long names)
        list.measure = list:CreateFontString(nil, "OVERLAY")
        list.measure:SetAlpha(0)
        list.measure:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 100, -100)
    end
    local menu = opts and opts.menu
    local width = menu and 160 or owner:GetWidth()
    for _, item in ipairs(items) do
        if not (item.font and list.measure:SetFont(item.font, 13, "")) then list.measure:SetFont(ns.STYLE.font, ns.FontPx(13), "") end
        list.measure:SetText(item.label or "")
        -- margin: 1 px border + 8 px text inset per side + rounding buffer (else names get truncated)
        local needed = list.measure:GetUnboundedStringWidth() + 28 + (item.actions and #item.actions * 20 or 0)
            + ((item.icon or (opts and opts.multi)) and 22 or 0)
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

-- Checkbox with text (e.g. auction house "Buyout mode")
function UI.LabelCheck(parent, label, onClick)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(20)
    local box = CreateFrame("Frame", nil, button)
    box:SetSize(14, 14)
    box:SetPoint("LEFT")
    UI.CheckBg(box)
    local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
    tick:SetPoint("CENTER")
    button.Text = UI.Text(button, 13, "LEFT")
    button.Text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    button.Text:SetText(label or "")
    button:SetWidth(22 + button.Text:GetUnboundedStringWidth())
    function button:SetChecked(on)
        self.checked = on and true or false
        tick:SetShown(self.checked)
    end
    function button:GetChecked() return self.checked end
    button:SetMotionScriptsWhileDisabled(true)
    hooksecurefunc(button, "SetEnabled", function(self, on)
        self:SetAlpha(on and 1 or 0.45)
    end)
    button:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if onClick then onClick(self, self.checked) end
    end)
    button:SetChecked(false)
    return button
end
