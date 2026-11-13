-- Character window (WoW Forever): own mUI window replacing Blizzard's CharacterFrame, same family
-- as the guild and friends windows (portrait header, tabs on the outer right).
--
--   [Portrait] Koratal                                [x]   [Tabs]
--              Level 14 - Hunter - <Guild>                 Character, Reputation, Skills,
--   ... tab content ...                                    PvP, Currency, Statistics
--
-- Core: window, tabs, open/redirect and shared widgets (grouped list, detail pane, checkbox).
-- Each tab lives in its own file and registers via ns.Char.AddTab. Data and actions are Blizzard's.
local _, ns = ...
local L = ns.L

local WIDTH = 1000
local PAD = ns.NPC_PAD
local TOP = ns.NPC_HEADER_BOTTOM + 16
local TAB_SIZE, TAB_STEP = 40, 46
local LIST_W = 440
local ROW_H, HEAD_H = 28, 26

local Char = { tabs = {}, views = {} }
ns.Char = Char
Char.WIDTH, Char.PAD, Char.TOP, Char.LIST_W = WIDTH, PAD, TOP, LIST_W

local window
local tabButtons = {}
local current

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.characterWindow ~= false
end

-- Blizzard global string, or our translation as fallback
function Char.G(name, fallback)
    local value = _G[name]
    if type(value) == "string" and value ~= "" then return value end
    return L[fallback or name]
end

-- Gear slot labels (character + inspect window) ------------------------------------------------
-- Item name, item level and permanent enchant next to a slot, like the reference doll layouts.
-- side: "left" column = text right of the slot, "right" column = left of it, "bottom" = right of it.

local LABEL_GAP = 26    -- left/right columns: past the model box edge (slot + 14) plus 12px padding
local LABEL_LINE = 13   -- line height
local ENCHANT_COLOR = { 0.1, 1, 0.1 }
local ENCHANT_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.ItemEnchantmentPermanent
local enchantPrefix -- pattern for "Enchanted: %s" (Retail wording); Forever shows the bare effect

local function EnchantText(unit, slot)
    if not (ENCHANT_LINE and C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return end
    local data = C_TooltipInfo.GetInventoryItem(unit, slot)
    if not data or issecretvalue(data) then return end
    for _, line in ipairs(data.lines or {}) do
        local kind, text = line.type, line.leftText
        if not issecretvalue(kind) and kind == ENCHANT_LINE and not issecretvalue(text) and text and text ~= "" then
            if enchantPrefix == nil then
                local fmt = type(ENCHANTED_TOOLTIP_LINE) == "string" and ENCHANTED_TOOLTIP_LINE or ""
                enchantPrefix = fmt:find("%s", 1, true)
                    and "^" .. fmt:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", "(.+)", 1) .. "$" or false
            end
            return enchantPrefix and text:match(enchantPrefix) or text
        end
    end
end

-- layer: frame above the model, so the text is not hidden behind it
function Char.AddSlotLabel(button, side, width, layer)
    local label = CreateFrame("Frame", nil, layer)
    label:SetAllPoints(button)
    local justify = side == "right" and "RIGHT" or "LEFT"
    local function Line(size)
        local text = ns.CreateText(label, size, justify)
        text:SetWidth(width)
        return text
    end
    label.lines = { Line(12), Line(11), Line(11) }
    if side == "right" then
        label.point, label.relative, label.x = "RIGHT", "LEFT", -LABEL_GAP
    else
        label.point, label.relative, label.x = "LEFT", "RIGHT", side == "bottom" and 8 or LABEL_GAP
    end
    label:SetShown(button:IsShown())
    button:HookScript("OnShow", function() label:Show() end)
    button:HookScript("OnHide", function() label:Hide() end)
    button.label = label
end

-- link nil = empty slot (slot name + "Empty"); level nil = no item level line (option off, shirt ...)
function Char.UpdateSlotLabel(button, unit, link, quality, level)
    local label = button.label
    if not label then return end
    local muted = ns.UI.MUTED
    local slotText = _G[button.slotName] or button.slotName
    local rows = {}
    if link then
        local r, g, b = 1, 1, 1
        if quality then r, g, b = C_Item.GetItemQualityColor(quality) end
        rows[1] = { link:match("%[(.-)%]") or "", r, g, b }
        if level then
            rows[#rows + 1] = { L["iLvl %d"]:format(level), unpack(muted) } -- short and not confused with the character level
        else
            rows[#rows + 1] = { slotText, unpack(muted) }
        end
        local enchant = EnchantText(unit, button.slot)
        if enchant then rows[#rows + 1] = { enchant, unpack(ENCHANT_COLOR) } end
    else
        rows[1] = { slotText, unpack(muted) }
        rows[2] = { Char.G("EMPTY", "Empty"), unpack(muted) }
    end
    for i, text in ipairs(label.lines) do
        local row = rows[i]
        if row then
            text:ClearAllPoints()
            text:SetPoint(label.point, label, label.relative, label.x, ((#rows - 1) / 2 - (i - 1)) * LABEL_LINE)
            text:SetText(row[1])
            text:SetTextColor(row[2], row[3], row[4])
            text:SetAlpha(link and 1 or 0.6)
            text:Show()
        else
            text:Hide()
        end
    end
end

-- Register a tab: { key, order, icon (texture or function(texture)), tip, Create(view),
-- Refresh(view), events = { ... } } - events only trigger refreshes while the tab is open
function Char.AddTab(def)
    Char.tabs[#Char.tabs + 1] = def
    table.sort(Char.tabs, function(a, b) return a.order < b.order end)
end

local function TabByKey(key)
    for _, def in ipairs(Char.tabs) do
        if def.key == key then return def end
    end
end

-- Shared widgets ----------------------------------------------------------------------------

local UI -- = ns.UI (only available after Config/Widgets.lua has loaded)

-- Checkbox with a short label (detail panes: At war, Inactive ...)
function Char.Check(parent, label, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(220, 20)
    local box = CreateFrame("Frame", nil, button)
    box:SetSize(14, 14)
    box:SetPoint("LEFT")
    UI.CheckBg(box)
    local mark = box:CreateTexture(nil, "OVERLAY")
    ns.SetIcon(mark, "Check")
    mark:SetSize(12, 12)
    mark:SetPoint("CENTER")
    mark:SetVertexColor(unpack(UI.ACCENT))
    button.text = UI.Text(button, 12, "LEFT")
    button.text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    button.text:SetText(label)
    function button:SetChecked(on) mark:SetShown(on and true or false) end
    hooksecurefunc(button, "SetEnabled", function(self, on)
        self.text:SetTextColor(unpack(on and UI.TEXT or UI.MUTED))
        box:SetAlpha(on and 1 or 0.4)
    end)
    button:SetScript("OnClick", onClick)
    return button
end

-- Status bar with centered text (reputation, skills, XP)
function Char.Bar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height or 18)
    bar:SetStatusBarTexture(ns.STYLE.barTexture)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)
    local edge = CreateFrame("Frame", nil, bar)
    edge:SetAllPoints()
    edge:SetFrameLevel(bar:GetFrameLevel() + 2)
    ns.AddBorder(edge, true)
    bar.text = ns.CreateText(edge, 11, "CENTER", "OUTLINE")
    bar.text:SetPoint("CENTER")
    function bar:Set(value, max, color, text)
        self:SetMinMaxValues(0, math.max(max or 1, 1))
        self:SetValue(value or 0)
        self:SetStatusBarColor(color[1], color[2], color[3])
        self.text:SetText(text or "")
    end
    return bar
end

-- Scrolling list with collapsible groups. SetData(entries):
--   { header = true, text, collapsed, onClick }
--   { text, color, indent, selected, bar = { value, max, color, text }, right, rightColor,
--     icon, onClick(entry, button), onEnter(row, entry), height }
function Char.List(parent)
    local list = UI.ScrollArea(parent)
    local rows = {}

    local function Row(i)
        if rows[i] then return rows[i] end
        local row = CreateFrame("Button", nil, list.child)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.line = row:CreateTexture(nil, "BORDER")
        row.line:SetPoint("BOTTOMLEFT")
        row.line:SetPoint("BOTTOMRIGHT")
        row.line:SetHeight(ns.PixelSize())
        row.line:SetColorTexture(0, 0, 0, 1)
        row.sign = UI.Text(row, 13, "LEFT", UI.ACCENT)
        row.sign:SetPoint("LEFT", 8, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.text = UI.Text(row, 13, "LEFT")
        row.right = UI.Text(row, 12, "RIGHT", UI.MUTED)
        row.right:SetPoint("RIGHT", -8, 0)
        row.bar = Char.Bar(row, 18)
        row.bar:SetWidth(180)
        row.bar:SetPoint("RIGHT", -8, 0)
        row.hover = row:CreateTexture(nil, "HIGHLIGHT")
        row.hover:SetAllPoints()
        row.hover:SetColorTexture(1, 1, 1, 0.04)
        row:SetScript("OnClick", function(self, button)
            if self.entry and self.entry.onClick then self.entry.onClick(self.entry, button) end
        end)
        row:SetScript("OnEnter", function(self)
            if self.entry and self.entry.onEnter then self.entry.onEnter(self, self.entry) end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = row
        return row
    end

    function list:SetData(entries)
        local y = 0
        for i, entry in ipairs(entries) do
            local row = Row(i)
            row.entry = entry
            local header = entry.header
            local height = entry.height or (header and HEAD_H or ROW_H)
            local gap = header and i > 1 and 6 or 0
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(y + gap))
            row:SetPoint("RIGHT", list.child, "RIGHT")
            row:SetHeight(height)
            row.bg:SetColorTexture(unpack(header and { 0.1, 0.1, 0.11, 1 } or entry.selected and { 0.14, 0.14, 0.15, 1 } or { 0, 0, 0, 0 }))
            row.line:SetShown(header)
            row.sign:SetShown(header)
            row.sign:SetText(entry.collapsed and "+" or "−")
            local left = header and 24 or 8 + (entry.indent or 0)
            row.icon:SetShown(entry.icon ~= nil)
            if entry.icon then
                row.icon:SetTexture(entry.icon)
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", left, 0)
                left = left + 26
            end
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", left, 0)
            row.text:SetText(entry.text or "")
            ns.SetFont(row.text, header and 13 or 13, "", header and "bold" or nil)
            row.text:SetTextColor(unpack(header and UI.ACCENT or entry.color or UI.TEXT))
            local bar = entry.bar
            row.bar:SetShown(bar ~= nil)
            if bar then row.bar:Set(bar.value, bar.max, bar.color, bar.text) end
            row.right:SetText(entry.right or "")
            row.right:SetTextColor(unpack(entry.rightColor or UI.MUTED))
            row.right:ClearAllPoints()
            row.right:SetPoint("RIGHT", bar and row.bar or row, bar and "LEFT" or "RIGHT", -8, 0)
            row.text:SetPoint("RIGHT", (entry.right and entry.right ~= "") and row.right or (bar and row.bar or row),
                (entry.right and entry.right ~= "" or bar) and "LEFT" or "RIGHT", -8, 0)
            row:Show()
            y = y + gap + height + 2
        end
        for i = #entries + 1, #rows do rows[i]:Hide() end
        list:SetContentHeight(y)
    end
    return list
end

-- Right-hand detail pane: title, subtitle, bar, text, grid, checkboxes at the bottom.
-- Fill(data) / Empty(text)
--   data = { title, sub, subColor, bar = { value, max, color, text }, text,
--            grid = { { a, b, c, color, bColor, cColor, header } }, checks = { { label, checked, enabled, onClick } } }
function Char.Detail(parent)
    local pane = CreateFrame("Frame", nil, parent)
    UI.Box(pane, { 0.07, 0.07, 0.08, 1 })
    local inner = 16
    pane.empty = UI.Text(pane, 13, "CENTER", { 0.47, 0.46, 0.43 })
    pane.empty:SetPoint("LEFT", inner, 0)
    pane.empty:SetPoint("RIGHT", -inner, 0)
    pane.empty:SetWordWrap(true)
    pane.title = UI.Text(pane, 16, "LEFT")
    ns.SetFont(pane.title, 16, "", "bold")
    pane.title:SetPoint("TOPLEFT", inner, -inner)
    pane.title:SetPoint("RIGHT", -inner, 0)
    pane.title:SetWordWrap(true)
    pane.sub = UI.Text(pane, 12, "LEFT", UI.MUTED)
    pane.sub:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -4)
    pane.bar = Char.Bar(pane, 18)
    pane.bar:SetPoint("TOPLEFT", pane.sub, "BOTTOMLEFT", 0, -10)
    pane.bar:SetPoint("RIGHT", -inner, 0)
    pane.text = UI.Text(pane, 13, "LEFT", { 0.79, 0.78, 0.75 })
    ns.SetFont(pane.text, 13, "", "text")
    pane.text:SetWordWrap(true)
    pane.text:SetJustifyV("TOP")
    pane.text:SetSpacing(3)
    pane.text:SetPoint("RIGHT", -inner, 0)
    pane.gridRows, pane.checks = {}, {}

    local function Hide(...) for _, region in ipairs({ ... }) do region:Hide() end end

    function pane:Empty(text)
        Hide(self.title, self.sub, self.bar, self.text)
        for _, r in ipairs(self.gridRows) do r:Hide() end
        for _, c in ipairs(self.checks) do c:Hide() end
        self.empty:SetText(text or "")
        self.empty:Show()
    end

    function pane:Fill(data)
        self.empty:Hide()
        self.title:SetText(data.title or "")
        self.title:Show()
        self.sub:SetText(data.sub or "")
        self.sub:SetTextColor(unpack(data.subColor or UI.MUTED))
        self.sub:SetShown(data.sub ~= nil and data.sub ~= "")
        local anchor = self.sub:IsShown() and self.sub or self.title
        self.bar:ClearAllPoints()
        self.bar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
        self.bar:SetPoint("RIGHT", -inner, 0)
        self.bar:SetShown(data.bar ~= nil)
        if data.bar then
            self.bar:Set(data.bar.value, data.bar.max, data.bar.color, data.bar.text)
            anchor = self.bar
        end
        self.text:ClearAllPoints()
        self.text:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
        self.text:SetPoint("RIGHT", -inner, 0)
        self.text:SetText(data.text or "")
        self.text:SetShown(data.text ~= nil and data.text ~= "")
        if self.text:IsShown() then anchor = self.text end
        -- Grid (e.g. weapon skill: same level / boss)
        for i, line in ipairs(data.grid or {}) do
            local r = self.gridRows[i]
            if not r then
                r = CreateFrame("Frame", nil, self)
                r:SetHeight(20)
                r.a = UI.Text(r, 12, "LEFT")
                r.a:SetPoint("LEFT")
                r.c = UI.Text(r, 12, "RIGHT")
                r.c:SetPoint("RIGHT")
                r.c:SetWidth(80)
                r.b = UI.Text(r, 12, "RIGHT")
                r.b:SetPoint("RIGHT", r.c, "LEFT", -6, 0)
                r.b:SetWidth(90)
                r.rule = r:CreateTexture(nil, "BORDER") -- rule under header rows
                r.rule:SetPoint("BOTTOMLEFT", 0, -3)
                r.rule:SetPoint("BOTTOMRIGHT", 0, -3)
                r.rule:SetHeight(ns.PixelSize())
                r.rule:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.6)
                self.gridRows[i] = r
            end
            r:ClearAllPoints()
            -- Spacing: wide before a new header, medium right below one, tight otherwise
            local gap = i == 1 and -12 or line.header and -16 or data.grid[i - 1].header and -8 or -2
            r:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap)
            r:SetPoint("RIGHT", -inner, 0)
            -- Header rows in accent color; value cells may have their own color (bColor/cColor)
            for _, key in ipairs({ "a", "b", "c" }) do
                r[key]:SetText(line[key] or "")
                r[key]:SetTextColor(unpack(line.header and UI.ACCENT or line[key .. "Color"] or line.color or UI.TEXT))
            end
            r.rule:SetShown(line.header == true)
            r:Show()
            anchor = r
        end
        for i = #(data.grid or {}) + 1, #self.gridRows do self.gridRows[i]:Hide() end
        self.lastAnchor = anchor -- for extras placed below (e.g. reward card)
        -- Checkboxes stacked bottom-up
        local checks = data.checks or {}
        for i, def in ipairs(checks) do
            local check = self.checks[i]
            if not check then
                check = Char.Check(self, "", function(button) if button.def and button.def.onClick then button.def.onClick() end end)
                self.checks[i] = check
            end
            check.def = def
            check.text:SetText(def.label)
            check:SetChecked(def.checked)
            check:SetEnabled(def.enabled ~= false)
            check:ClearAllPoints()
            check:SetPoint("BOTTOMLEFT", inner, inner + (#checks - i) * 24)
            check:Show()
        end
        for i = #checks + 1, #self.checks do self.checks[i]:Hide() end
    end
    return pane
end

-- Race background behind a model like Blizzard's SetPaperDollBackground: four tiles of the DressUp
-- art, desaturated, with a per-race overlay. :SetUnit(unit) (character, inspect)
local OVERLAY_ALPHA = { HUMAN = 1, DWARF = 0.93, NIGHTELF = 0.5, TROLL = 0.85, ORC = 0.75, SCOURGE = 0.2 }
function Char.RaceBackdrop(stage)
    local backdrop = CreateFrame("Frame", nil, stage)
    backdrop:SetPoint("TOPLEFT", 1, -1)
    backdrop:SetPoint("BOTTOMRIGHT", -1, 1)
    local function Tile(left, right, top, bottom)
        local tex = backdrop:CreateTexture(nil, "BACKGROUND")
        tex:SetTexCoord(left, right, top, bottom)
        tex:SetDesaturated(true)
        return tex
    end
    local tiles = { Tile(0.171875, 1, 0.0392, 1), Tile(0, 0.296875, 0.0392, 1), Tile(0.171875, 1, 0, 0.62), Tile(0, 0.296875, 0, 0.62) }
    tiles[1]:SetPoint("TOPLEFT")
    tiles[1]:SetPoint("BOTTOMRIGHT", -79, 129)
    tiles[2]:SetPoint("TOPRIGHT")
    tiles[2]:SetPoint("BOTTOMRIGHT", 0, 129)
    tiles[2]:SetWidth(80)
    tiles[3]:SetPoint("BOTTOMLEFT")
    tiles[3]:SetPoint("BOTTOMRIGHT", -79, 0)
    tiles[3]:SetHeight(130)
    tiles[4]:SetPoint("BOTTOMRIGHT")
    tiles[4]:SetSize(80, 130)
    local overlay = backdrop:CreateTexture(nil, "BORDER")
    overlay:SetAtlas("UI-Character-Info-RaceBG-Overlay")
    overlay:SetAllPoints()
    function backdrop:SetUnit(unit)
        local _, raceFile = UnitRace(unit)
        local path = "Interface\\DressUpFrame\\DressUpBackground-" .. (raceFile or "Orc")
        for i, tex in ipairs(tiles) do tex:SetTexture(path .. i) end
        overlay:SetAlpha(OVERLAY_ALPHA[strupper(raceFile or "")] or 0.85)
    end
    return backdrop
end

-- Default tab layout: list left, details right
function Char.ListAndDetail(view)
    view.list = Char.List(view)
    view.list:SetPoint("TOPLEFT")
    view.list:SetPoint("BOTTOMLEFT")
    view.list:SetWidth(LIST_W - 12) -- room for the scroll bar
    view.detail = Char.Detail(view)
    view.detail:SetPoint("TOPLEFT", LIST_W + 14, 0)
    view.detail:SetPoint("BOTTOMRIGHT")
end

-- Window ----------------------------------------------------------------------------------------

local function Subtitle()
    local level = UnitLevel("player")
    local class, classFile = UnitClass("player")
    local color = RAID_CLASS_COLORS[classFile]
    if color then class = color:WrapTextInColorCode(class) end
    local parts = { L["Level %d"]:format(level), class }
    local guild = GetGuildInfo("player")
    if guild then parts[#parts + 1] = "<" .. guild .. ">" end
    return table.concat(parts, " · ")
end

local function UpdateHeader()
    if not window then return end
    local def = TabByKey(current)
    local name = UnitName("player")
    local title = (not def or def.key == "character") and (UnitPVPName and ns.Plain(UnitPVPName("player")) or name) or def.tip
    window:SetNpc("player", title or name, Subtitle())
end
Char.UpdateHeader = UpdateHeader

local pending = false
local function RefreshCurrent()
    pending = false
    if not (window and window:IsShown()) then return end
    local def = TabByKey(current)
    local view = def and Char.views[def.key]
    if view and def.Refresh then def.Refresh(view) end
end
-- Coalesce several events within one frame into a single rebuild
function Char.Refresh()
    if pending then return end
    pending = true
    C_Timer.After(0, RefreshCurrent)
end

-- Tab events live on an own frame that listens only while the window is open; UNIT_* events
-- only for player and pet (RegisterUnitEvent), so raid-wide aura/health events never reach us.
local watched, watcher = {}, CreateFrame("Frame")
watcher:SetScript("OnEvent", function(_, event)
    local active = TabByKey(current)
    if not (window and window:IsShown() and active) then return end
    for _, e in ipairs(active.events or {}) do
        if e == event then return Char.Refresh() end
    end
end)
local function WatchEvents(def)
    for _, event in ipairs(def.events or {}) do
        -- events differ between Retail and Forever: an unknown one would throw
        if not (C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event)) then
            watched[event] = true
        end
    end
end
local function StartWatching()
    for event in pairs(watched) do
        if event:find("^UNIT_") then
            watcher:RegisterUnitEvent(event, "player", "pet")
        else
            watcher:RegisterEvent(event)
        end
    end
end
local function StopWatching() watcher:UnregisterAllEvents() end

local function TabIcon(button, def)
    if type(def.icon) == "function" then def.icon(button.icon) else button.icon:SetTexture(def.icon) end
end

local function Select(key)
    local def = TabByKey(key) or Char.tabs[1]
    if def.available and not def.available() then def = Char.tabs[1] end
    current = def.key
    for _, button in ipairs(tabButtons) do
        local active = button.def.key == current
        for _, edge in ipairs(button.active) do edge:SetShown(active) end
        TabIcon(button, button.def)
        button.icon:SetDesaturated(not active) -- inactive tabs slightly gray (like guild)
        button.icon:SetAlpha(active and 1 or 0.75)
    end
    for k, view in pairs(Char.views) do view:SetShown(k == current) end
    local view = Char.views[current]
    if not view then
        view = CreateFrame("Frame", nil, window)
        view:SetPoint("TOPLEFT", PAD, -TOP)
        view:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        Char.views[current] = view
        def.Create(view)
    end
    view:Show()
    UpdateHeader()
    if def.Refresh then def.Refresh(view) end
end
Char.Select = Select
function Char.Current() return current end

local function CreateWindow()
    UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUICharacter", WIDTH, ns.NPC_HEIGHT, "character")
    window.extraRight = TAB_STEP
    Char.window = window

    -- Round class icon next to the close button (shipped with the client, hidden if missing)
    local _, classFile = UnitClass("player")
    local atlas = classFile and ("ui-hud-unitframe-player-portrait-classicon-" .. classFile:lower() .. "-2x")
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        local classIcon = window.header:CreateTexture(nil, "ARTWORK")
        classIcon:SetAtlas(atlas)
        classIcon:SetSize(28, 28)
        classIcon:SetPoint("RIGHT", window.close, "LEFT", -8, 0)
        window.npcName:SetPoint("RIGHT", classIcon, "LEFT", -8, 0)
    end

    for i, def in ipairs(Char.tabs) do
        local button = CreateFrame("Button", nil, window)
        button:SetSize(TAB_SIZE, TAB_SIZE)
        button:SetPoint("TOPLEFT", window, "TOPRIGHT", 6, -60 - (i - 1) * TAB_STEP) -- like guild, professions, spellbook
        UI.Box(button, ns.STYLE.panelColor)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.active = ns.AddBorder(button, true, 2)
        for _, edge in ipairs(button.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        button.def = def
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(def.tip, 1, 1, 1)
            if def.available and not def.available() and def.unavailable then
                GameTooltip:AddLine(def.unavailable, 1, 0.3, 0.3, true)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            if def.available and not def.available() then return end
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Select(def.key)
        end)
        tabButtons[i] = button
        WatchEvents(def)
    end

    window:HookScript("OnShow", function()
        StartWatching()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        if CharacterMicroButton and CharacterMicroButton.SetPushed then CharacterMicroButton:SetPushed() end
        Select(current or "character")
    end)
    window:HookScript("OnHide", function()
        StopWatching()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        if CharacterMicroButton and CharacterMicroButton.SetNormal then CharacterMicroButton:SetNormal() end
        for _, def in ipairs(Char.tabs) do
            if def.OnHide and Char.views[def.key] then def.OnHide(Char.views[def.key]) end
        end
    end)
end

-- Opening ------------------------------------------------------------------------------------------

-- Map Blizzard tab names (ToggleCharacter("ReputationFrame") ...) to ours
local BLIZZARD_TABS = {
    PaperDollFrame = "character", ReputationFrame = "reputation", SkillFrame = "skills", SkillsFrame = "skills",
    PVPRankFrame = "pvp", PVPFrame = "pvp", HonorFrame = "pvp", TokenFrame = "currency", StatisticsFrame = "statistics",
}

local function Toggle(key)
    if not window then CreateWindow() end
    if C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule and Enum.GameRule.CharacterPanelDisabled
        and C_GameRules.IsGameRuleActive(Enum.GameRule.CharacterPanelDisabled) then
        return
    end
    if window:IsShown() and (not key or key == current) then
        window:Hide()
        return
    end
    if key then current = key end
    if window:IsShown() then Select(current) else window:Show() end
end
Char.Toggle = Toggle
function Char.Open(key)
    if not window then CreateWindow() end
    if key then current = key end
    if window:IsShown() then Select(current) else window:Show() end
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()

    -- Key bindings (character, reputation, PvP, currency) overridden onto our buttons
    local buttons = {}
    local function Button(name, key)
        local button = CreateFrame("Button", name, UIParent)
        button:SetScript("OnClick", function() Toggle(key) end)
        buttons[#buttons + 1] = { button, name }
        return button
    end
    local bindings = {
        { "TOGGLECHARACTER0", Button("MeredanUICharacterToggle", "character") },
        { "TOGGLECHARACTER2", Button("MeredanUIReputationToggle", "reputation") },
        { "TOGGLECHARACTER4", Button("MeredanUIPvPToggle", "pvp") },
        { "TOGGLECURRENCY", Button("MeredanUICurrencyToggle", "currency") },
    }
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        for _, entry in ipairs(buttons) do ClearOverrideBindings(entry[1]) end
        for _, entry in ipairs(bindings) do
            for _, key in ipairs({ GetBindingKey(entry[1]) }) do
                SetOverrideBindingClick(entry[2], false, key, entry[2]:GetName(), "LeftButton")
            end
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)

    -- Replace Blizzard's global opener (micro menu, achievements, gamepad ...). Only this global -
    -- never overwrite methods on Blizzard frames (CharacterFrame.ToggleTokenFrame stays untouched)
    ToggleCharacter = function(tab, onlyShow)
        local key = BLIZZARD_TABS[tab] or "character"
        if onlyShow then Char.Open(key) else Toggle(key) end
    end
    if CharacterMicroButton then CharacterMicroButton:SetScript("OnClick", function() Toggle("character") end) end
    -- If Blizzard's frame still opens (e.g. currency button on the backpack), close it and open ours
    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function(frame)
            frame:Hide()
            Char.Open(TokenFrame and TokenFrame:IsShown() and "currency" or nil)
        end)
    end

    ns:On("PLAYER_LEVEL_UP", function() if window:IsShown() then C_Timer.After(0, UpdateHeader) end end)
    ns:On("PLAYER_GUILD_UPDATE", function() if window:IsShown() then UpdateHeader() end end)
    ns:On("UNIT_NAME_UPDATE", function(_, unit) if unit == "player" and window:IsShown() then UpdateHeader() end end)
    ns:On("PLAYER_AVG_ITEM_LEVEL_UPDATE", function() if window:IsShown() then UpdateHeader() end end)
end)
