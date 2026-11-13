-- Collections (WoW Forever): own mUI window replacing Blizzard's CollectionsJournal.
--
--   +-[i] Collections ------------------------------ [=====   ] [x]-+  [Mounts]
--   |     Mounts - 87 of 412 collected                                 |  [Pets]
--   | [Search          ] [Filter v]  [All] [Favorites] [Missing]       |  [Toys]
--   | +- list / grid ---------+ +- preview ------------------------+   |  [Heirlooms]
--   | |                       | |                                  |   |  [Wardrobe]
--   | +-----------------------+ +----------------------------------+   |
--   | [footer left]                                  [main action]    |
--   +------------------------------------------------------------------+
--
-- This file: window, side tabs, header progress, shared widgets (search, chips, virtual list,
-- model preview). Each tab lives in its own file and registers via ns.Collections.Register.
-- Blizzard's journal is never shown: its openers (micro button, key binding, links, toasts) are
-- redirected here. Taint notes: mounts/pets/heirlooms are plain API calls from clicks (not
-- protected); toys use InsecureActionButtonTemplate (works out of combat, never makes this
-- window protected). Blizzard's journal filters (C_MountJournal etc.) are owned by this window
-- now, since Blizzard's journal no longer opens.
local _, ns = ...
local L = ns.L

local C = {}
ns.Collections = C

local WIDTH = 980
local PAD = 18
C.PAD = PAD
C.TOOLBAR_TOP = ns.NPC_HEADER_BOTTOM + 14  -- 78
C.CONTENT_TOP = C.TOOLBAR_TOP + 28 + 12    -- 118
C.FOOTER = 54
C.LIST_W = 330
C.WIDTH = WIDTH
local TAB_SIZE, TAB_STEP = 40, 46

local tabs, defs = {}, {}
local window, progressBar, progressFill
local current

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.collectionsWindow ~= false
end
C.Enabled = Enabled

-- Tab registry ---------------------------------------------------------------------------------
-- def = { key, name, icon, order, available(), Create(page), Refresh(page), Progress() -> have, total }
function C.Register(def)
    defs[#defs + 1] = def
    table.sort(defs, function(a, b) return a.order < b.order end)
end

-- Shared widgets ---------------------------------------------------------------------------------

-- Search field with hint; onChange(text) runs as you type
function C.Search(parent, width, onChange)
    local UI = ns.UI
    local box = UI.EditBox(parent, 28)
    box:SetWidth(width)
    local icon = UI.Icon(box, "Filter", 12, UI.MUTED) -- placeholder until a search icon exists
    icon:Hide()
    local hint = UI.Text(box, 13, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(SEARCH or L["Search"])
    box:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        onChange(self:GetText() or "")
    end)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

-- Row of toggle chips (only one active); items = { { value, label } }; onPick(value)
function C.Chips(parent, items, onPick)
    local UI = ns.UI
    local row = { buttons = {}, value = items[1] and items[1].value }
    local last
    for _, item in ipairs(items) do
        local button = CreateFrame("Button", nil, parent)
        button:SetHeight(28)
        UI.Box(button)
        button.edges = ns.AddBorder(button, true)
        for _, e in ipairs(button.edges) do e:SetVertexColor(unpack(UI.ACCENT)) end
        button.text = UI.Text(button, 13, "CENTER")
        button.text:SetPoint("CENTER")
        button.text:SetText(item.label)
        button:SetWidth(math.max(button.text:GetUnboundedStringWidth() + 24, 60))
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.05)
        if last then button:SetPoint("LEFT", last, "RIGHT", 6, 0) end
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            row:Set(item.value)
            onPick(item.value)
        end)
        button.value = item.value
        row.buttons[#row.buttons + 1] = button
        last = button
    end
    function row:Set(value)
        self.value = value
        for _, button in ipairs(self.buttons) do
            local on = button.value == value
            for _, e in ipairs(button.edges) do e:SetShown(on) end
            button.text:SetTextColor(unpack(on and UI.ACCENT or UI.MUTED))
        end
    end
    function row:SetPoint(...) self.buttons[1]:SetPoint(...) end
    row:Set(row.value)
    return row
end

-- Virtual list: fixed row height, only visible rows exist. create(row) builds a row once,
-- fill(row, item, index) fills it. list:SetItems(items) re-renders.
function C.List(parent, rowHeight, create, fill)
    local UI = ns.UI
    local list = CreateFrame("Frame", nil, parent)
    local bg = list:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.25)
    ns.AddBorder(list)
    list.rows, list.items, list.offset = {}, {}, 0
    local function Visible() return math.max(math.floor((list:GetHeight() - 2) / rowHeight), 1) end
    local function Range() return math.max((#list.items - Visible()) * rowHeight, 0) end
    local bar = UI.Scrollbar(list, {
        GetRange = Range,
        GetOffset = function() return list.offset * rowHeight end,
        SetOffset = function(value) list.offset = math.floor(value / rowHeight + 0.5) list:Render() end,
        GetRatio = function() return #list.items > 0 and Visible() / #list.items or 1 end,
        step = rowHeight, page = rowHeight * 6,
    })
    bar:SetPoint("TOPRIGHT", -2, -2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    list.bar = bar
    function list:Render()
        local visible = Visible()
        self.offset = math.min(math.max(self.offset, 0), math.max(#self.items - visible, 0))
        local scrolls = #self.items > visible
        for i = 1, visible do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, self)
                row:SetHeight(rowHeight)
                row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                row:RegisterForDrag("LeftButton")
                create(row)
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * rowHeight)
            row:SetPoint("RIGHT", self, "RIGHT", scrolls and -18 or -1, 0)
            local item = self.items[self.offset + i]
            if item then
                row.item = item
                fill(row, item, self.offset + i)
                row:Show()
            else
                row.item = nil
                row:Hide()
            end
        end
        for i = visible + 1, #self.rows do self.rows[i]:Hide() end
        bar:Update()
    end
    function list:SetItems(items, keepOffset)
        self.items = items
        if not keepOffset then self.offset = 0 end
        self:Render()
    end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(self, delta)
        self.offset = self.offset - delta * 3
        self:Render()
    end)
    list:SetScript("OnSizeChanged", function(self) self:Render() end)
    return list
end

-- Standard list row: icon, name (quality color), sub text, favorite star, selection stripe
function C.CreateRow(row)
    local UI = ns.UI
    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.12)
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetPoint("TOPLEFT")
    row.stripe:SetPoint("BOTTOMLEFT")
    row.stripe:SetWidth(2)
    row.stripe:SetColorTexture(unpack(UI.ACCENT))
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    local line = row:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(ns.PixelSize())
    line:SetColorTexture(1, 1, 1, 0.04)
    row.iconFrame = CreateFrame("Frame", nil, row)
    row.iconFrame:SetSize(32, 32)
    row.iconFrame:SetPoint("LEFT", 8, 0)
    ns.AddSlotBackground(row.iconFrame)
    ns.AddBorder(row.iconFrame, true)
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 1, -1)
    row.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.star = UI.Icon(row, "Star", 12, { 0.85, 0.71, 0.42 })
    row.star:SetPoint("RIGHT", -10, 0)
    row.right = UI.Text(row, 11, "RIGHT", UI.ACCENT)
    row.right:SetPoint("RIGHT", row.star, "LEFT", -6, 0)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 10, -1)
    row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
    row.name:SetWordWrap(false)
    row.sub = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.sub:SetPoint("BOTTOMLEFT", row.iconFrame, "BOTTOMRIGHT", 10, 1)
    row.sub:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
    row.sub:SetWordWrap(false)
end

-- Fill a standard row; opts = { icon, name, color, sub, right, fav, selected, missing }
function C.FillRow(row, opts)
    row.icon:SetTexture(opts.icon or 134400)
    row.icon:SetDesaturated(opts.missing and true or false)
    row.icon:SetAlpha(opts.missing and 0.6 or 1)
    row.name:SetText(opts.name or "")
    local c = opts.color or ns.UI.TEXT
    if opts.missing then c = ns.UI.MUTED end
    row.name:SetTextColor(c[1], c[2], c[3])
    row.sub:SetText(opts.sub or "")
    row.right:SetText(opts.right or "")
    row.star:SetShown(opts.fav and true or false)
    row.sel:SetShown(opts.selected and true or false)
    row.stripe:SetShown(opts.selected and true or false)
end

-- Quality color as { r, g, b }
function C.QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if not color then return ns.UI.TEXT end
    return { color.r, color.g, color.b }
end

-- Preview panel: name, sub, 3D model (drag to rotate, wheel to zoom), two info boxes.
-- panel:Show(opts) with { name, color, sub, displayID | creatureID, source, lore }
function C.Preview(parent)
    local UI = ns.UI
    local panel = CreateFrame("Frame", nil, parent)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.045, 0.055, 0.055, 1)
    -- Blizzard's mount journal backdrop, zoomed past its corner ornaments, faded over the mUI ground
    local art = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetAllPoints()
    art:SetTexture(651761) -- Interface\\PetBattles\\MountJournal-BG
    art:SetTexCoord(0.07, 0.715, 0.09, 0.91)
    art:SetAlpha(0.55)
    ns.AddBorder(panel)

    local model = CreateFrame("PlayerModel", nil, panel)
    model:SetPoint("TOPLEFT", 10, -64)
    model:SetPoint("BOTTOMRIGHT", -10, 10)
    panel.model = model
    local facing, zoom = 0.6, 0
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        local startX, startFacing = GetCursorPosition(), facing
        self:SetScript("OnUpdate", function()
            facing = startFacing + (GetCursorPosition() - startX) / 80
            self:SetFacing(facing)
        end)
    end)
    model:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    model:SetScript("OnMouseWheel", function(self, delta)
        zoom = math.min(math.max(zoom + delta * 0.1, -0.5), 0.6)
        self:SetPortraitZoom(zoom)
    end)

    panel.name = UI.Text(panel, 20, "LEFT")
    ns.SetFont(panel.name, 20, "", "bold")
    panel.name:SetPoint("TOPLEFT", 16, -14)
    panel.name:SetPoint("RIGHT", -60, 0)
    panel.name:SetWordWrap(false)
    panel.sub = UI.Text(panel, 12, "LEFT", UI.MUTED)
    panel.sub:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -4)
    panel.sub:SetPoint("RIGHT", -60, 0)

    panel.hint = UI.Text(panel, 11, "CENTER", { 0.6, 0.59, 0.56 })
    panel.hint:SetPoint("BOTTOM", 0, 14)
    panel.hint:SetText(L["Drag to rotate · mouse wheel to zoom"])

    local function Box(anchorLeft)
        local box = CreateFrame("Frame", nil, panel)
        box:SetHeight(66)
        UI.Box(box, { 0.04, 0.05, 0.05, 0.9 })
        ns.AddBorder(box)
        box.label = UI.Heading(box, 10, "LEFT")
        box.label:SetPoint("TOPLEFT", 10, -8)
        box.text = UI.Text(box, 12, "LEFT")
        box.text:SetPoint("TOPLEFT", box.label, "BOTTOMLEFT", 0, -4)
        box.text:SetPoint("RIGHT", -10, 0)
        box.text:SetPoint("BOTTOM", 0, 6)
        box.text:SetJustifyV("TOP")
        if anchorLeft then box:SetPoint("BOTTOMLEFT", 14, 12) end
        return box
    end
    panel.source = Box(true)
    panel.source.label:SetText(SOURCE and SOURCE:gsub(":%s*$", "") or L["Source"])
    panel.lore = Box(false)
    panel.lore:SetPoint("BOTTOMRIGHT", -14, 12)
    panel.lore.label:SetText(DESCRIPTION or L["Description"])
    panel.source:SetPoint("RIGHT", panel, "CENTER", -6, 0)
    panel.lore:SetPoint("LEFT", panel, "CENTER", 6, 0)

    function panel:ShowEntry(opts)
        self.name:SetText(opts.name or "")
        local c = opts.color or UI.TEXT
        self.name:SetTextColor(c[1], c[2], c[3])
        self.sub:SetText(opts.sub or "")
        self.source.text:SetText(opts.source or "")
        self.lore.text:SetText(opts.lore or "")
        self.source:SetShown(opts.source ~= nil and opts.source ~= "")
        self.lore:SetShown(opts.lore ~= nil and opts.lore ~= "")
        -- the model fills the panel down to the bottom; with info boxes it stops above them
        local boxes = self.source:IsShown() or self.lore:IsShown()
        model:SetPoint("BOTTOMRIGHT", -10, boxes and 88 or 10)
        self.hint:SetPoint("BOTTOM", 0, boxes and 82 or 14)
        model:ClearModel()
        facing, zoom = 0.6, 0
        if opts.displayID and opts.displayID > 0 then
            model:SetDisplayInfo(opts.displayID)
        elseif opts.creatureID and opts.creatureID > 0 then
            model:SetCreature(opts.creatureID)
        end
        model:SetFacing(facing)
        model:SetPortraitZoom(0)
        model:SetShown((opts.displayID or opts.creatureID) and true or false)
        self.hint:SetShown(model:IsShown())
    end
    return panel
end

-- Footer button (flat, 170 px); accent = Surf Green border (main action)
function C.FooterButton(parent, label, onClick, accent)
    local UI = ns.UI
    local button = UI.Button(parent, label, onClick, 170)
    button:SetHeight(28)
    ns.SetFont(button.Text, 13, "", "bold")
    if accent then
        for _, e in ipairs(ns.AddBorder(button, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end
        button.Text:SetTextColor(unpack(UI.ACCENT))
    end
    return button
end

-- Case-insensitive plain search
function C.Matches(text, filter)
    if filter == "" then return true end
    return text and text:lower():find(filter, 1, true) ~= nil
end

-- Window -----------------------------------------------------------------------------------------

local function UpdateHeader()
    local def = current and defs[current]
    if not def then return end
    local have, total = 0, 0
    if def.Progress then have, total = def.Progress() end
    if def.HeaderText then
        window.npcTitle:SetText(def.HeaderText(have, total))
        if total and total > 0 then
            progressFill:SetWidth(math.max(progressBar:GetWidth() * have / total, 0.01))
        end
        progressBar:SetShown(total and total > 0)
    elseif total and total > 0 then
        window.npcTitle:SetText(L["%s · %d of %d collected"]:format(def.name, have, total))
        progressFill:SetWidth(math.max(progressBar:GetWidth() * have / total, 0.01))
        progressBar:Show()
    else
        window.npcTitle:SetText(def.name)
        progressBar:Hide()
    end
end
C.UpdateHeader = function() if window and window:IsShown() then UpdateHeader() end end

local function LayoutTabs()
    local slot = 0
    for i, def in ipairs(defs) do
        local button = tabs[i]
        local available = not def.available or def.available()
        button:SetShown(available)
        if available then
            slot = slot + 1
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", window, "TOPRIGHT", ns.SideTabX(), -60 - (slot - 1) * TAB_STEP)
        end
        local on = i == current
        for _, e in ipairs(button.active) do e:SetShown(on) end
        button.icon:SetDesaturated(not on)
    end
end

local function Select(index)
    local def = defs[index]
    if not def or (def.available and not def.available()) then return end
    current = index
    for i, other in ipairs(defs) do
        if other.page then other.page:SetShown(i == index) end
    end
    if not def.page then
        def.page = CreateFrame("Frame", nil, window)
        def.page:SetAllPoints()
        def.Create(def.page)
    end
    def.page:Show()
    LayoutTabs()
    if def.Refresh then def.Refresh(def.page) end
    UpdateHeader()
    ns.db.collectionsTab = def.key
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUICollections", WIDTH, ns.NPC_HEIGHT, "collections")
    window.extraRight = TAB_STEP
    window:SetNpc(nil, COLLECTIONS or L["Collections"], "", "Interface\\Icons\\INV_Horse3Saddle008_Chestnut")

    progressBar = CreateFrame("Frame", nil, window.header)
    progressBar:SetSize(200, 6)
    progressBar:SetPoint("RIGHT", window.close, "LEFT", -14, 0)
    UI.Box(progressBar, { 0.04, 0.05, 0.05, 1 })
    ns.AddBorder(progressBar)
    progressFill = progressBar:CreateTexture(nil, "ARTWORK")
    progressFill:SetPoint("TOPLEFT")
    progressFill:SetPoint("BOTTOMLEFT")
    progressFill:SetColorTexture(unpack(UI.ACCENT))
    window.npcName:SetPoint("RIGHT", progressBar, "LEFT", -14, 0)

    for i, def in ipairs(defs) do
        local button = CreateFrame("Button", nil, window)
        button:SetSize(TAB_SIZE, TAB_SIZE)
        UI.Box(button, ns.STYLE.panelColor)
        ns.AddBorder(button)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon:SetTexture(def.icon)
        button.active = ns.AddBorder(button, true, 2)
        for _, e in ipairs(button.active) do e:SetVertexColor(unpack(UI.ACCENT)) end
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.08)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(def.name, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Select(i)
        end)
        tabs[i] = button
    end

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        local index = current
        if not index then
            for i, def in ipairs(defs) do
                if def.key == ns.db.collectionsTab then index = i end
            end
        end
        Select(index or 1)
        if not current then Select(1) end
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        ns.UI.CloseList()
        local def = current and defs[current]
        if def and def.OnHide then def.OnHide(def.page) end
    end)
end

local function TabIndex(key)
    for i, def in ipairs(defs) do
        if def.key == key then return i end
    end
end

-- key nil = toggle; with a key: switch to that tab, or close if it is already shown
function C.Toggle(key)
    if not window then CreateWindow() end
    local index = key and TabIndex(key)
    if window:IsShown() and (not index or index == current) then
        window:Hide()
        return
    end
    window:Show()
    if index then Select(index) end
end

function C.Open(key)
    if not window then CreateWindow() end
    window:Show()
    local index = key and TabIndex(key)
    if index then Select(index) end
end

-- Refresh the visible tab (data events)
function C.RefreshTab(key)
    if not (window and window:IsShown() and current) then return end
    local def = defs[current]
    if key and def.key ~= key then return end
    if def.Refresh then def.Refresh(def.page) end
    UpdateHeader()
end

-- Blizzard tab indices -> our keys
local BLIZZARD_TABS = { "mounts", "pets", "toys", "heirlooms", "wardrobe" }

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    -- Only these globals are replaced (micro button, key binding, links, toasts, tutorials call them)
    ToggleCollectionsJournal = function(tab) C.Toggle(tab and BLIZZARD_TABS[tab] or nil) end
    SetCollectionsJournalShown = function(shown, tab)
        if shown then C.Open(tab and BLIZZARD_TABS[tab] or nil) elseif window then window:Hide() end
    end
    ToggleToyCollection = function() C.Open("toys") end
    -- If Blizzard's journal still opens somehow, close it and open ours
    local function Watch()
        if CollectionsJournal then
            CollectionsJournal:HookScript("OnShow", function(frame)
                frame:Hide()
                C.Open()
            end)
            return true
        end
    end
    if not Watch() then
        ns:On("ADDON_LOADED", function(_, name)
            if name == "Blizzard_Collections" then Watch() end
        end)
    end
end)
