-- Calendar (CalendarFrame, Blizzard_Calendar, WoW Forever) in mUI style. Blizzard's frames keep all
-- logic (events, invites, RSVP, context menus, modal dialogs); we only restyle and re-place them:
--
--   +-[o] Calendar --------------------------------- [<] [>] [Filter v] [x]-+  +- event frame --+
--   |     November 2026                                                      |  | (view/create)  |
--   |  Mon     Tue     Wed     Thu     Fri     Sat     Sun                   |  |                |
--   | +------+------+------+------+------+------+------+                     |  |                |
--   | | 1    | 2    | ...  7x6 day grid, flat cells, events at the bottom    |  |                |
--   | +------+------+------+------+------+------+------+                     |  +----------------+
--   +------------------------------------------------------------------------+
--
-- Day cells: Blizzard swaps textures/anchors per state in CalendarFrame_Update (dark days, event art,
-- today frame, selection highlight). We recolor those textures once and mirror today/selected/pending
-- state onto our own regions after each update (hooksecurefunc), never replacing logic.
-- Rules as in Skins/Communities.lua: art only via SetAlpha(0) or recolor, no SetScript, no fields on
-- Blizzard tables, no ScrollBox view changes, no SetText on Blizzard edit boxes. Invite rows get
-- OnEnter via SetScript at runtime, so their hover look uses the HIGHLIGHT texture only.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = { 0, 0, 0, 1 }
local INPUT = { 0.04, 0.04, 0.05, 1 }
local BOX = { 0, 0, 0, 0.25 }
local PAD, ICON = 18, 46
local CELL_W, CELL_H = 91, 86          -- Blizzard: 91x91; 86 fits the grid into ns.NPC_HEIGHT
local WEEKDAY_H = 28
local GRID_TOP = PAD + ICON + 14       -- 78: weekday row
local DAYS_TOP = GRID_TOP + WEEKDAY_H  -- 106: first week
local WIDTH = 2 * PAD + 7 * CELL_W     -- 673
local GAP = 8                          -- event frames to the right of the calendar
local DAYS = 42

local EVENT_FRAMES = { "CalendarViewEventFrame", "CalendarCreateEventFrame", "CalendarViewHolidayFrame",
    "CalendarViewRaidFrame" }

local skinned = setmetatable({}, { __mode = "k" })
local own = setmetatable({}, { __mode = "k" })
local cells = setmetatable({}, { __mode = "k" }) -- day button -> our regions
local frame, subtitle
local fonts
local applied = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.calendarSkin ~= false
end

local function Once(object)
    if type(object) ~= "table" or skinned[object] then return false end
    if object.IsForbidden and object:IsForbidden() then return false end
    skinned[object] = true
    return true
end

local function IsTexture(region)
    return type(region) == "table" and region.IsObjectType and region:IsObjectType("Texture")
end

local function Fade(region)
    if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
end

local function FadeRegions(target, keep)
    if type(target) ~= "table" or not target.GetRegions then return end
    for _, region in ipairs({ target:GetRegions() }) do
        if IsTexture(region) and not own[region] and not (keep and keep[region]) then region:SetAlpha(0) end
    end
end

local function Tex(parent, layer, sublevel, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    if color then tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    own[tex] = true
    return tex
end

-- 1 px outer border around target (textures on parent)
local function Edges(parent, target, color, layer)
    local px = ns.PixelSize()
    local c = color or BLACK
    local edges = {}
    for i = 1, 4 do
        local edge = parent:CreateTexture(nil, layer or "BORDER")
        edge:SetTexture(WHITE)
        edge:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        edge:SetSnapToPixelGrid(false)
        edge:SetTexelSnappingBias(0)
        own[edge] = true
        edges[i] = edge
    end
    edges[1]:SetPoint("TOPLEFT", target, "TOPLEFT", -px, px)
    edges[1]:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", px, 0)
    edges[2]:SetPoint("TOPLEFT", target, "BOTTOMLEFT", -px, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, -px)
    edges[3]:SetPoint("TOPLEFT", target, "TOPLEFT", -px, 0)
    edges[3]:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", 0, 0)
    edges[4]:SetPoint("TOPLEFT", target, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, 0)
    return edges
end

local function Border(target, inside, thickness)
    local edges = ns.AddBorder(target, inside, thickness)
    for _, edge in ipairs(edges) do own[edge] = true end
    return edges
end

-- Background + border + Surf Green top line
local function Panel(target)
    local c = ns.STYLE.panelColor
    local bg = Tex(target, "BACKGROUND", -8, { c[1], c[2], c[3], 0.97 })
    bg:SetAllPoints()
    Edges(target, target)
    local accent = Tex(target, "OVERLAY", 7, ns.UI.ACCENT)
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
end

local function Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, base, color)
        local font = CreateFont(name)
        font:CopyFontObject(base)
        font:SetTextColor(color[1], color[2], color[3])
        return font
    end
    fonts = {
        normal = Make("MeredanUICalendarButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUICalendarButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUICalendarButtonDisabled", GameFontDisable, UI.MUTED),
    }
    return fonts
end

local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
    "GetCheckedTexture", "GetDisabledCheckedTexture" }
local function FadeButtonTextures(button)
    for _, getter in ipairs(BUTTON_TEXTURES) do
        local fn = button[getter]
        if fn then Fade(fn(button)) end
    end
end

-- Controls ---------------------------------------------------------------------------------------

-- flat button (UIPanelButtonTemplate); hover via HIGHLIGHT layer
local function SkinButton(button)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(button[key]) end
    FadeButtonTextures(button)
    local name = button:GetName()
    if name then Fade(_G[name .. "Border"]) end -- UI-Button-Borders art behind footer buttons
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    local hover = Tex(button, "HIGHLIGHT", 0, UI.HOVER)
    hover:SetAllPoints()
    Border(button)
    if button:GetFontString() then
        local f = Fonts()
        button:SetNormalFontObject(f.normal)
        button:SetHighlightFontObject(f.highlight)
        button:SetDisabledFontObject(f.disabled)
    end
end

-- Icon button: flat box, our icon, Surf Green on hover; dimmed while disabled
local function SkinIconButton(button, iconName, iconSize)
    if type(button) ~= "table" or not button.IsObjectType or not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = UI.Icon(button, iconName, iconSize or 14)
    own[icon] = true
    icon:SetPoint("CENTER", bg)
    local function Reflect() icon:SetAlpha(button:IsEnabled() and 1 or 0.35) end
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() then icon:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
    button:HookScript("OnEnable", Reflect)
    button:HookScript("OnDisable", Reflect)
    Reflect()
    return icon
end

-- Dropdown (WowStyle1DropdownTemplate / FilterDropdown): flat field, our arrow
local function SkinDropdown(dropdown)
    if type(dropdown) ~= "table" or not dropdown.GetRegions or not Once(dropdown) then return end
    local UI = ns.UI
    Fade(dropdown.Background)
    Fade(dropdown.Arrow)
    if dropdown.Text then dropdown.Text:SetTextColor(unpack(UI.TEXT)) end -- Blizzard's yellow label
    local bg = Tex(dropdown, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Edges(dropdown, bg)
    local arrow = UI.Icon(dropdown, "ChevronDown", 10, UI.MUTED)
    own[arrow] = true
    arrow:SetPoint("RIGHT", -8, 0)
    local hover = Tex(dropdown, "HIGHLIGHT", 0, { 1, 1, 1, 0.05 })
    hover:SetAllPoints(bg)
    local function Reflect() arrow:SetAlpha(dropdown:IsEnabled() and 1 or 0.35) end
    dropdown:HookScript("OnEnter", function(self)
        if self:IsEnabled() then arrow:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    dropdown:HookScript("OnLeave", function() arrow:SetVertexColor(unpack(UI.MUTED)) end)
    dropdown:HookScript("OnEnable", Reflect)
    dropdown:HookScript("OnDisable", Reflect)
    Reflect()
end

-- Checkbox (UICheckButtonTemplate): dark box, Surf Green check
local function SkinCheck(check)
    if type(check) ~= "table" or not check.IsObjectType or not check:IsObjectType("CheckButton") then return end
    if not Once(check) then return end
    local UI = ns.UI
    FadeButtonTextures(check)
    local box = CreateFrame("Frame", nil, check)
    box:SetSize(16, 16)
    box:SetPoint("CENTER")
    UI.CheckBg(box)
    local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
    tick:SetPoint("CENTER")
    local hover = Tex(check, "HIGHLIGHT", 0, { 1, 1, 1, 0.08 })
    hover:SetAllPoints(box)
    local function Update()
        tick:SetShown(check:GetChecked() and true or false)
        tick:SetVertexColor(unpack(check:IsEnabled() and UI.ACCENT or UI.MUTED))
    end
    check:HookScript("OnClick", Update)
    check:HookScript("OnShow", Update)
    check:HookScript("OnEnable", Update)
    check:HookScript("OnDisable", Update)
    hooksecurefunc(check, "SetChecked", Update)
    Update()
end

-- Single-line edit box (InputBoxTemplate): dark field, Surf Green border on focus
local function SkinEditBox(box)
    if type(box) ~= "table" or not box.IsObjectType or not box:IsObjectType("EditBox") or not Once(box) then return end
    local UI = ns.UI
    FadeRegions(box)
    local bg = Tex(box, "BACKGROUND", -8, INPUT)
    bg:SetPoint("TOPLEFT", -6, 2)
    bg:SetPoint("BOTTOMRIGHT", 2, -2)
    local IDLE = UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 }
    local edges = Edges(box, bg, IDLE)
    box:HookScript("OnEditFocusGained", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    box:HookScript("OnEditFocusLost", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1) end
    end)
end

-- Scrollbar (MinimalScrollBar): chevron arrows, thin track, Surf Green thumb
local function SkinScrollBar(bar)
    if type(bar) ~= "table" or not bar.Track or not Once(bar) then return end
    local UI = ns.UI
    Fade(bar.Background)
    local track = bar.Track
    FadeRegions(track)
    local line = Tex(track, "BACKGROUND", 0, { 1, 1, 1, 0.06 })
    line:SetPoint("TOP")
    line:SetPoint("BOTTOM")
    line:SetWidth(3)
    local thumb = track.Thumb or (bar.GetThumb and bar:GetThumb())
    if type(thumb) == "table" and thumb.GetRegions then
        FadeRegions(thumb)
        local grip = Tex(thumb, "OVERLAY", 0, { UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 1 })
        grip:SetPoint("TOP")
        grip:SetPoint("BOTTOM")
        grip:SetWidth(3)
        grip:SetAlpha(0.8)
        thumb:HookScript("OnEnter", function() grip:SetWidth(5) grip:SetAlpha(1) end)
        thumb:HookScript("OnLeave", function() grip:SetWidth(3) grip:SetAlpha(0.8) end)
    end
    for key, rotation in pairs({ Back = math.pi, Forward = 0 }) do
        local stepper = bar[key]
        if type(stepper) == "table" and stepper.GetRegions then
            FadeRegions(stepper)
            Fade(stepper.Texture)
            local icon = UI.Icon(stepper, "ChevronDown", 12, UI.MUTED)
            own[icon] = true
            icon:SetPoint("CENTER")
            icon:SetRotation(rotation)
            local function Reflect() icon:SetAlpha(stepper:IsEnabled() and 1 or 0.3) end
            stepper:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
            stepper:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.MUTED)) end)
            stepper:HookScript("OnEnable", Reflect)
            stepper:HookScript("OnDisable", Reflect)
            Reflect()
        end
    end
end

-- ScrollBox rows: after each update skin all visible rows (new and recycled) once
local function HookScrollBox(box, fn)
    if type(box) ~= "table" or not box.ForEachFrame or not Once(box) then return end
    local function Each() if not box.GetView or box:GetView() then box:ForEachFrame(fn) end end -- no view until Blizzard fills the list
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
end

-- List row (invite list, event/texture picker): Blizzard's ADD highlight recolored to a flat tint.
-- Blizzard locks the highlight for the selected row, so selection gets the same tint.
local function SkinListRow(row)
    if type(row) ~= "table" or not row.GetHighlightTexture or not Once(row) then return end
    local UI = ns.UI
    local highlight = row:GetHighlightTexture()
    if IsTexture(highlight) then
        highlight:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.16)
        highlight:SetBlendMode("BLEND")
    end
end

-- Tooltip-backdrop box (description, invite list): NineSlice hidden, flat field
local function SkinBox(box, color, edge)
    if type(box) ~= "table" or not Once(box) then return end
    Fade(box.NineSlice)
    local bg = Tex(box, "BACKGROUND", -8, color or BOX)
    bg:SetAllPoints()
    Edges(box, bg, edge)
end

-- Header ------------------------------------------------------------------------------------------

local function UpdateTitle()
    if not subtitle or not frame then return end
    local month, year = frame.viewedMonth, frame.viewedYear
    local name = month and CALENDAR_MONTH_NAMES and CALENDAR_MONTH_NAMES[month]
    subtitle:SetText(name and year and (name .. " " .. year) or "")
end

-- Day grid ----------------------------------------------------------------------------------------

local function DayPart(button, suffix)
    return _G[button:GetName() .. suffix]
end

local function SkinEventButton(button)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    -- "black" = selected event (Blizzard only shows/hides it)
    local black = DayPart(button, "Black")
    if IsTexture(black) then
        black:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.3)
        black:SetBlendMode("BLEND")
    end
    local highlight = button:GetHighlightTexture()
    if IsTexture(highlight) then
        highlight:SetColorTexture(1, 1, 1, 0.08)
        highlight:SetBlendMode("BLEND")
    end
end

local function SkinDayButton(button)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    local parts = {}
    cells[button] = parts

    Fade(button:GetNormalTexture())
    local bg = Tex(button, "BACKGROUND", -8, BOX)
    bg:SetAllPoints()
    -- subtle stone grain on the cells (Blizzard's dark rock tile), so the grid isn't flat black
    local grain = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    grain:SetTexture(374155, "REPEAT", "REPEAT") -- interface/framegeneral/ui-background-rock
    grain:SetHorizTile(true)
    grain:SetVertTile(true)
    grain:SetAllPoints()
    grain:SetDesaturated(true)
    grain:SetVertexColor(0.55, 0.55, 0.55)
    grain:SetAlpha(0.35)
    own[grain] = true
    -- grid lines: right and bottom edge per cell (outer frame drawn around the grid)
    local px = ns.PixelSize()
    local right = Tex(button, "OVERLAY", 5, BLACK)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(px)
    local bottom = Tex(button, "OVERLAY", 5, BLACK)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(px)

    -- hover / selection: Blizzard sets the highlight alpha (0.5 hover, 1.0 selected) and locks it
    local highlight = button:GetHighlightTexture()
    if IsTexture(highlight) then
        highlight:ClearAllPoints()
        highlight:SetAllPoints()
        highlight:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.16)
        highlight:SetBlendMode("BLEND")
    end

    -- event art (dungeon/holiday images) kept as a faint hint inside the cell
    local eventTex = DayPart(button, "EventTexture")
    if IsTexture(eventTex) then
        eventTex:ClearAllPoints()
        eventTex:SetAllPoints()
        eventTex:SetAlpha(0.3)
    end
    local overlay = DayPart(button, "OverlayFrame")
    if overlay then overlay:SetAlpha(0.3) end
    local eventBg = DayPart(button, "EventBackgroundTexture")
    if IsTexture(eventBg) then
        eventBg:SetColorTexture(0, 0, 0, 0.35)
        eventBg:SetWidth(CELL_W)
    end

    -- days of other months: Blizzard's shadow halves recolored to a flat dim, resized to the cell
    local dark = DayPart(button, "DarkFrame")
    if dark then
        dark:ClearAllPoints()
        dark:SetAllPoints()
        for _, key in ipairs({ "Top", "Bottom" }) do
            local half = DayPart(button, "DarkFrame" .. key)
            if IsTexture(half) then
                half:SetColorTexture(0, 0, 0, 0.6)
                half:SetSize(CELL_W, CELL_H / 2)
            end
        end
    end

    -- pending invite: Blizzard's glow art replaced by our mail icon next to the date
    Fade(DayPart(button, "PendingInviteTexture"))
    local dateFrame = DayPart(button, "DateFrame")
    Fade(DayPart(button, "DateFrameBackground"))
    if dateFrame then
        local fill = Tex(dateFrame, "BACKGROUND", 0, UI.ACCENT)
        fill:SetPoint("TOPLEFT", -2, 0)
        fill:SetPoint("BOTTOMRIGHT", 2, 0)
        fill:Hide()
        parts.today = fill
        local mail = UI.Icon(button, "Mail", 12, UI.ACCENT)
        own[mail] = true
        mail:SetPoint("LEFT", dateFrame, "RIGHT", 3, 0)
        mail:Hide()
        parts.pending = mail
    end
    parts.date = DayPart(button, "DateFrameDate")

    local more = DayPart(button, "MoreEventsButton")
    if more then
        FadeButtonTextures(more)
        local arrow = UI.Icon(more, "ChevronDown", 10, UI.MUTED)
        own[arrow] = true
        arrow:SetPoint("CENTER")
        more:HookScript("OnEnter", function() arrow:SetVertexColor(unpack(UI.ACCENT)) end)
        more:HookScript("OnLeave", function() arrow:SetVertexColor(unpack(UI.MUTED)) end)
    end

    -- selected day: Surf Green frame inside the cell
    local selected = Border(button, true, 2)
    for _, edge in ipairs(selected) do
        edge:SetVertexColor(unpack(UI.ACCENT))
        edge:SetDrawLayer("OVERLAY", 7)
        edge:Hide()
    end
    parts.selected = selected

    for i = 1, 4 do SkinEventButton(DayPart(button, "EventButton" .. i)) end
end

local function IsSelectedDay(button)
    if button ~= frame.selectedDayButton or not button.day or button.day ~= frame.selectedDay then return false end
    local info = C_Calendar.GetMonthInfo(button.monthOffset or 0)
    return info ~= nil and info.month == frame.selectedMonth and info.year == frame.selectedYear
end

-- Mirror Blizzard's day state (today, selected, pending invite) onto our regions
local function RefreshDays()
    if not frame then return end
    local UI = ns.UI
    local todayFrame = _G.CalendarTodayFrame
    local todayButton = todayFrame and todayFrame:IsShown() and todayFrame:GetParent()
    for i = 1, DAYS do
        local button = _G["CalendarDayButton" .. i]
        local parts = button and cells[button]
        if parts then
            local isToday = button == todayButton
            if parts.today then parts.today:SetShown(isToday) end
            if parts.date then
                if isToday then parts.date:SetTextColor(0.05, 0.05, 0.05) else parts.date:SetTextColor(unpack(UI.TEXT)) end
            end
            local on = IsSelectedDay(button)
            for _, edge in ipairs(parts.selected) do edge:SetShown(on) end
            local pending = DayPart(button, "PendingInviteTexture")
            if parts.pending then parts.pending:SetShown(pending and pending:IsShown() and true or false) end
        end
    end
end

-- Event side frames ---------------------------------------------------------------------------------

-- Dialog frame (DialogBorderDarkTemplate + DialogHeaderTemplate): flat panel, title top left
local function SkinDialog(f, closeButton)
    if type(f) ~= "table" or not Once(f) then return end
    Fade(f.Border)
    local name = f:GetName()
    if name then Fade(_G[name .. "ButtonBackground"]) end
    local header = f.Header
    if header then
        FadeRegions(header)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        header:SetHeight(30)
        if header.Text then
            header.Text:ClearAllPoints()
            header.Text:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -10)
            ns.SetFont(header.Text, 14, "", "bold")
            header.Text:SetTextColor(unpack(ns.UI.TEXT))
        end
    end
    Panel(f)
    if closeButton then
        SkinIconButton(closeButton, "Close", 14)
        closeButton:SetSize(28, 28)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    end
end

-- Event icon (view/create): thin border
local function FrameIcon(parent, icon)
    if not IsTexture(icon) or own[icon] then return end
    own[icon] = true
    Edges(parent, icon)
end

-- RSVP button glow (pending invite): Blizzard pulses its alpha; recolor to a Surf Green fill
local function SkinFlash(button)
    local name = button and button:GetName()
    local flash = name and _G[name .. "FlashTexture"]
    if not IsTexture(flash) then return end
    flash:ClearAllPoints()
    flash:SetAllPoints(button)
    flash:SetColorTexture(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.3)
    flash:SetBlendMode("ADD")
end

local function SkinInviteList(list)
    if type(list) ~= "table" then return end
    SkinBox(list)
    SkinScrollBar(list.ScrollBar)
    HookScrollBox(list.ScrollBox, SkinListRow)
end

local function SkinViewEvent()
    local f = _G.CalendarViewEventFrame
    SkinDialog(f, _G.CalendarViewEventCloseButton)
    if f and f.HeaderFrame then FrameIcon(f.HeaderFrame, _G.CalendarViewEventIcon) end
    local desc = _G.CalendarViewEventDescriptionContainer
    if desc then
        SkinBox(desc)
        SkinScrollBar(desc.ScrollBar)
    end
    Fade(_G.CalendarViewEventDivider)
    for _, key in ipairs({ "Accept", "Tentative", "Decline" }) do
        local button = _G["CalendarViewEvent" .. key .. "Button"]
        SkinButton(button)
        SkinFlash(button)
    end
    SkinButton(_G.CalendarViewEventRemoveButton)
    SkinInviteList(_G.CalendarViewEventInviteList)
end

local function SkinCreateEvent()
    local f = _G.CalendarCreateEventFrame
    SkinDialog(f, _G.CalendarCreateEventCloseButton)
    if f then
        FrameIcon(f, _G.CalendarCreateEventIcon)
        for _, key in ipairs({ "EventTypeDropdown", "HourDropdown", "MinuteDropdown", "AMPMDropdown",
            "DifficultyOptionDropdown", "CommunityDropdown" }) do
            SkinDropdown(f[key])
        end
    end
    SkinEditBox(_G.CalendarCreateEventTitleEdit)
    SkinEditBox(_G.CalendarCreateEventInviteEdit)
    local desc = _G.CalendarCreateEventDescriptionContainer
    if desc then
        SkinBox(desc, INPUT, ns.UI.CHECK_EDGE)
        SkinScrollBar(desc.ScrollBar)
    end
    Fade(_G.CalendarCreateEventDivider)
    SkinCheck(_G.CalendarCreateEventAutoApproveCheck)
    SkinCheck(_G.CalendarCreateEventLockEventCheck)
    SkinInviteList(_G.CalendarCreateEventInviteList)
    for _, button in ipairs({ _G.CalendarCreateEventInviteButton, _G.CalendarCreateEventMassInviteButton,
        _G.CalendarCreateEventRaidInviteButton, _G.CalendarCreateEventCreateButton }) do
        SkinButton(button)
    end
end

local function SkinMassInvite()
    local f = _G.CalendarMassInviteFrame
    SkinDialog(f, _G.CalendarMassInviteCloseButton)
    if f then
        SkinDropdown(f.CommunityDropdown)
        SkinDropdown(f.RankDropdown)
    end
    SkinEditBox(_G.CalendarMassInviteMinLevelEdit)
    SkinEditBox(_G.CalendarMassInviteMaxLevelEdit)
    SkinButton(_G.CalendarMassInviteAcceptButton)
end

local function SkinPicker(f, buttons)
    if type(f) ~= "table" then return end
    SkinDialog(f)
    SkinScrollBar(f.ScrollBar)
    HookScrollBox(f.ScrollBox, SkinListRow)
    for _, button in ipairs(buttons) do SkinButton(button) end
end

-- Class counters next to the invite list
local function SkinClassButtons()
    local UI = ns.UI
    local i = 1
    while _G["CalendarClassButton" .. i] do
        local button = _G["CalendarClassButton" .. i]
        if Once(button) then
            local icon = button:GetNormalTexture()
            FadeRegions(button, icon and { [icon] = true } or nil)
            local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
            bg:SetAllPoints()
            Border(button)
            if IsTexture(icon) then
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", 1, -1)
                icon:SetPoint("BOTTOMRIGHT", -1, 1)
            end
        end
        i = i + 1
    end
    local totals = _G.CalendarClassTotalsButton
    if totals and Once(totals) then
        FadeRegions(totals)
        local bg = Tex(totals, "BACKGROUND", -8, UI.FIELD)
        bg:SetPoint("TOPLEFT", 0, 4)
        bg:SetPoint("BOTTOMRIGHT", 0, -4)
        Edges(totals, bg)
    end
end

-- Layout ----------------------------------------------------------------------------------------------

local function PlaceSide(f)
    if type(f) ~= "table" then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", frame, "TOPRIGHT", GAP, 0)
end

local function Place()
    local f = frame
    f:SetSize(WIDTH, ns.NPC_HEIGHT)

    -- weekday row and grid (day buttons chain off weekday 1 / each other in Blizzard's anchors)
    local first = _G.CalendarWeekday1Background
    if first then
        first:ClearAllPoints()
        first:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -GRID_TOP)
    end
    for i = 1, 7 do
        local weekday = _G["CalendarWeekday" .. i .. "Background"]
        if weekday then weekday:SetSize(CELL_W, WEEKDAY_H) end
    end
    for i = 1, DAYS do
        local button = _G["CalendarDayButton" .. i]
        if button then button:SetSize(CELL_W, CELL_H) end
    end

    -- header toolbar: [<] [>] [Filter] [x]
    local close = _G.CalendarCloseButton
    if close then
        close:SetSize(34, 34)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -(PAD - 4), -(PAD - 4))
    end
    local filter = f.FilterButton
    if filter then
        filter:ClearAllPoints()
        filter:SetPoint("RIGHT", close or f, close and "LEFT" or "TOPRIGHT", -6, 0)
        filter:SetSize(120, 28)
        if filter.Text then
            filter.Text:ClearAllPoints()
            filter.Text:SetPoint("LEFT", 10, 0)
            filter.Text:SetPoint("RIGHT", -24, 0)
        end
    end
    local nextButton, prevButton = _G.CalendarNextMonthButton, _G.CalendarPrevMonthButton
    if nextButton then
        nextButton:SetSize(36, 36)
        nextButton:ClearAllPoints()
        nextButton:SetPoint("RIGHT", filter or f, filter and "LEFT" or "TOPRIGHT", -4, 0)
    end
    if prevButton then
        prevButton:SetSize(36, 36)
        prevButton:ClearAllPoints()
        prevButton:SetPoint("RIGHT", nextButton or f, nextButton and "LEFT" or "TOPRIGHT", 2, 0)
    end

    -- side frames hang right of the calendar, top aligned
    for _, name in ipairs(EVENT_FRAMES) do PlaceSide(_G[name]) end
    PlaceSide(_G.CalendarTexturePickerFrame)
    local blocker = _G.CalendarEventFrameBlocker
    if blocker then PlaceSide(blocker) end
    local dummy = _G.CalendarModalDummy
    if dummy then
        dummy:ClearAllPoints()
        dummy:SetAllPoints(f)
    end
end

local function PlaceClassButtons(parent)
    local container = _G.CalendarClassButtonContainer
    if not container or type(parent) ~= "table" then return end
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", parent, "TOPRIGHT", 6, -30)
end

local function Reposition(opening)
    if frame:IsShown() and ns.ResetWindowPosition then
        ns.ResetWindowPosition(frame, "calendar", opening and not InCombatLockdown())
    end
end

local function SkinShell(f)
    local UI = ns.UI
    FadeRegions(f) -- frame art, weekday art, month/year backgrounds, last-day shadow
    Panel(f)

    -- Header like mUI windows
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    local glyph = UI.Icon(holder, "Clock", 26, UI.ACCENT)
    glyph:SetPoint("CENTER")
    local title = UI.Text(holder, 16, "LEFT")
    ns.SetFont(title, 16, "", "bold")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    title:SetWidth(220)
    title:SetText(ns.L and ns.L["Calendar"] or "Calendar")
    subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetWidth(220)
    subtitle:SetWordWrap(false)
    -- Blizzard's month/year labels: we show them in the subtitle
    Fade(_G.CalendarMonthName)
    Fade(_G.CalendarYearName)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -280, 0) -- leave the toolbar clickable
    header:SetHeight(PAD + ICON + 6)
    ns.MakeWindowDraggable(f, header)

    SkinIconButton(_G.CalendarCloseButton, "Close", 18)
    local prevIcon = SkinIconButton(_G.CalendarPrevMonthButton, "ChevronDown", 14)
    if prevIcon then prevIcon:SetRotation(-math.pi / 2) end
    local nextIcon = SkinIconButton(_G.CalendarNextMonthButton, "ChevronDown", 14)
    if nextIcon then nextIcon:SetRotation(math.pi / 2) end
    SkinDropdown(f.FilterButton)

    -- weekday row: faint band, muted names; selected weekday as Surf Green tint
    local band = Tex(f, "BACKGROUND", -6, { 1, 1, 1, 0.04 })
    band:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -GRID_TOP)
    band:SetSize(7 * CELL_W, WEEKDAY_H)
    for i = 1, 7 do
        local label = _G["CalendarWeekday" .. i .. "Name"]
        if label then
            ns.SetFont(label, 12, "", "bold")
            label:SetTextColor(unpack(UI.MUTED))
        end
    end
    local weekdaySelected = _G.CalendarWeekdaySelectedTexture
    if IsTexture(weekdaySelected) then
        weekdaySelected:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.14)
        weekdaySelected:SetBlendMode("BLEND")
        weekdaySelected:SetSize(CELL_W, WEEKDAY_H)
        weekdaySelected:SetAlpha(1)
    end

    -- grid box with outer border
    local grid = CreateFrame("Frame", nil, f)
    grid:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -DAYS_TOP)
    grid:SetSize(7 * CELL_W, 6 * CELL_H)
    Edges(f, grid)

    -- today: Blizzard's pulsing glow frame hidden (we mark the date instead)
    Fade(_G.CalendarTodayFrame)
    for i = 1, DAYS do SkinDayButton(_G["CalendarDayButton" .. i]) end
end

local function Unmanage()
    if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
    if SetUIPanelAttribute then SetUIPanelAttribute(frame, "area", nil) end
    for _, name in ipairs(UISpecialFrames) do
        if name == "CalendarFrame" then return end
    end
    tinsert(UISpecialFrames, "CalendarFrame") -- Esc still closes
end

local function Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

-- Width of whatever hangs on the right (event frame, texture picker, class counters)
local function SideWidth()
    local width = 0
    for _, name in ipairs(EVENT_FRAMES) do
        local f = _G[name]
        if f and f:IsShown() then width = math.max(width, f:GetWidth()) end
    end
    local picker = _G.CalendarTexturePickerFrame
    if picker and picker:IsShown() then width = math.max(width, picker:GetWidth()) end
    if width == 0 then return 0 end
    local classes = _G.CalendarClassButtonContainer
    if classes and classes:IsShown() then width = width + 6 + classes:GetWidth() end
    return GAP + width
end

local function Apply()
    if applied or not Enabled() or type(_G.CalendarFrame) ~= "table" then return end
    applied = true
    frame = _G.CalendarFrame
    Try(SkinShell, frame)
    Try(SkinViewEvent)
    Try(SkinCreateEvent)
    Try(SkinMassInvite)
    Try(SkinDialog, _G.CalendarViewHolidayFrame, _G.CalendarViewHolidayCloseButton)
    Try(SkinDialog, _G.CalendarViewRaidFrame, _G.CalendarViewRaidCloseButton)
    Try(SkinPicker, _G.CalendarEventPickerFrame, { _G.CalendarEventPickerCloseButton })
    Try(SkinPicker, _G.CalendarTexturePickerFrame,
        { _G.CalendarTexturePickerAcceptButton, _G.CalendarTexturePickerCancelButton })
    Try(SkinClassButtons)
    -- holiday art behind the description (Blizzard only sets its texture / shows it)
    if _G.CalendarViewHolidayFrame then Fade(_G.CalendarViewHolidayFrame.Texture) end
    Unmanage()
    Try(Place)

    if ns.EXTRA_RIGHT then ns.EXTRA_RIGHT[frame] = SideWidth end

    hooksecurefunc("CalendarFrame_Update", RefreshDays)
    hooksecurefunc("CalendarFrame_SetSelectedDay", RefreshDays)
    hooksecurefunc("CalendarFrame_UpdateTitle", UpdateTitle)
    hooksecurefunc("CalendarClassButtonContainer_Show", PlaceClassButtons)
    -- an event frame opening/closing changes the space we need on the right
    hooksecurefunc("CalendarFrame_ShowEventFrame", function()
        C_Timer.After(0, function() Reposition() end)
    end)

    frame:HookScript("OnShow", function()
        Place()
        UpdateTitle()
        RefreshDays()
        C_Timer.After(0, function() Reposition(true) end)
    end)
    UpdateTitle()
    RefreshDays()
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_Calendar" then Apply() end
end)

ns:On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Calendar") then Apply() end
end)
