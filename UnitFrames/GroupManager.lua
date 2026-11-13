-- Group manager: replaces Blizzard's CompactRaidFrameManager in the mUI look (ready check, roles,
-- countdown, raid/world markers, ping restriction, leave buttons; collapsible tab on the left).
-- Markers are secure buttons (raidtarget/worldmarker) so they work in combat; expand/tabs use
-- SecureHandlerClickTemplate, layout changes only out of combat. Shown only while grouped.
local _, ns = ...
local L = ns.L

local WIDTH, PAD, TAB_W, TAB_H = 230, 12, 18, 40
local INNER = WIDTH - 2 * PAD
local CELL, GAP = 36, 5
local PANEL_BG = { 0.086, 0.075, 0.059, 0.96 }
local ICON_PATH = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"

-- Blizzard order: skull, cross, square, moon / triangle, diamond, circle, star
local UNIT_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1 }
-- Raid target icon -> world marker index (inverse of Blizzard's WORLD_RAID_MARKER_ORDER)
local WORLD_FOR_ICON = { [8] = 8, [7] = 4, [6] = 1, [5] = 7, [4] = 2, [3] = 3, [2] = 6, [1] = 5 }

local root, panel, tab
local sections = {}
local unitButtons, worldButtons = {}, {}
local ticker

local function Enabled() return ns.db and ns.db.groupManager ~= false end

-- Check for secret values first (Midnight API); when in doubt: false
local function Bool(v)
    if issecretvalue and issecretvalue(v) then return false end
    return v and true or false
end

local function IsLeader() return Bool(UnitIsGroupLeader("player")) end
local function HasRights()
    return IsLeader() or (IsInRaid() and Bool(UnitIsGroupAssistant("player")))
end
local function CanMark() return not IsInRaid() or HasRights() end
local function PingsEnabled() return C_Ping and C_Ping.IsPingSystemEnabled and C_Ping.IsPingSystemEnabled() end

-- Widgets ------------------------------------------------------------------------------------------

local function Tooltip(frame, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(type(text) == "function" and text() or text, 1, 1, 1)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function SectionLabel(text)
    local label = ns.UI.Heading(panel, 11, "LEFT")
    label:SetText(text:upper())
    return label
end

-- Field background with border; hover brightens, :SetMarked(true) = sage border
local function Cell(button)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.UI.FIELD))
    local edges = ns.AddBorder(button)
    local normal = { edges[1]:GetVertexColor() }
    button.bg, button.edges = bg, edges
    function button:SetMarked(on)
        local c = on and ns.UI.ACCENT or normal
        for _, e in ipairs(edges) do e:SetVertexColor(c[1], c[2], c[3], 1) end
    end
    button:HookScript("OnEnter", function() bg:SetColorTexture(unpack(ns.UI.HOVER)) end)
    button:HookScript("OnLeave", function() bg:SetColorTexture(unpack(ns.UI.FIELD)) end)
    button:SetMarked(false)
end

-- Button with text and arrow (dropdown)
local function Dropdown(parent, width, height, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    Cell(button)
    button.Text = ns.UI.Text(button, 13, "LEFT")
    button.Text:SetPoint("LEFT", 8, 0)
    local arrow = ns.UI.Icon(button, "ChevronDown", 12, ns.UI.MUTED)
    arrow:SetPoint("RIGHT", -8, 0)
    button.arrow = arrow
    button:SetScript("OnClick", onClick)
    return button
end

local function IconButton(parent, icon, tip, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(40, 34)
    Cell(button)
    button.icon = ns.UI.Icon(button, icon, 18)
    button.icon:SetPoint("CENTER")
    button:SetScript("OnClick", onClick)
    Tooltip(button, tip)
    return button
end

local function TextButton(parent, label, color, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(INNER, 28)
    Cell(button)
    button.Text = ns.UI.Text(button, 13, "CENTER", color)
    button.Text:SetPoint("CENTER")
    button.Text:SetText(label)
    button.color = color or ns.UI.TEXT
    button:SetScript("OnClick", onClick)
    hooksecurefunc(button, "SetEnabled", function(self, on)
        self.Text:SetTextColor(unpack(on and self.color or { 0.36, 0.39, 0.38 }))
    end)
    return button
end

-- Secure marker button; kind = "raidtarget" or "worldmarker"
local function MarkerButton(parent, kind, marker, special)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    b:SetSize(CELL, CELL)
    b:RegisterForClicks("AnyUp", "AnyDown")
    Cell(b)
    b:SetAttribute("type", kind)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")
    if special then
        local name = special == "remove" and "Close" or "Reset"
        tex:SetTexture(ns.MEDIA .. "Icons\\" .. name)
        tex:SetSize(16, 16)
        tex:SetVertexColor(unpack(ns.UI.MUTED))
    else
        tex:SetTexture(ICON_PATH .. marker)
        tex:SetSize(22, 22)
    end
    if kind == "raidtarget" then
        b:SetAttribute("unit", "target")
        if special == "remove" then
            b:SetAttribute("action", "clear")
            Tooltip(b, L["Remove marker from target"])
        elseif special == "reset" then
            b:SetAttribute("action", "clear-all")
            Tooltip(b, L["Remove all markers"])
        else
            b:SetAttribute("marker", marker) -- default action "toggle": second click removes it
            Tooltip(b, function() return _G["RAID_TARGET_" .. marker] or "" end)
        end
    else
        if special == "reset" then
            b:SetAttribute("action", "clear") -- no marker = all world markers
            Tooltip(b, L["Clear all world markers"])
        else
            local world = WORLD_FOR_ICON[marker]
            b:SetAttribute("marker", world)
            b:SetAttribute("action1", "set")   -- left: place (ground target)
            b:SetAttribute("action2", "clear") -- right: remove
            b.world = world
            Tooltip(b, function()
                return (_G["RAID_TARGET_" .. marker] or "") .. "\n|cff999999" .. L["Left: place · Right: remove"] .. "|r"
            end)
        end
    end
    return b
end

-- Display ------------------------------------------------------------------------------------------

local function UpdateCount()
    local total, alive = GetNumGroupMembers(), 0
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, total do
        local unit = (prefix == "party" and i == total) and "player" or (prefix .. i)
        local dead = UnitIsDeadOrGhost(unit)
        local online = UnitIsConnected(unit)
        if not (Bool(dead)) and not (not issecretvalue(online) and not online) then alive = alive + 1 end
    end
    sections.count:SetText(("|cffe9e6dd%d|r/%d"):format(alive, total))
    sections.mode.Text:SetText(IsInRaid() and (RAID or "Raid") or (PARTY or "Party"))
    sections.modeLabel:SetText(IsInRaid() and (RAID or "Raid") or (PARTY or "Party"))
end

local function UpdateUnitMarks()
    local index = UnitExists("target") and GetRaidTargetIndex("target")
    if issecretvalue and issecretvalue(index) then index = nil end
    for _, b in ipairs(unitButtons) do b:SetMarked(b.marker and b.marker == index) end
end

local function UpdateWorldMarks()
    for _, b in ipairs(worldButtons) do
        if b.world then b:SetMarked(Bool(IsRaidMarkerActive(b.world))) end
    end
end

-- Tab visuals (text/underline); the secure click does the actual switching
local function ShowTabVisual(which)
    for key, t in pairs(sections.tabs) do
        local on = key == which
        t.Text:SetTextColor(unpack(on and ns.UI.TITLE or ns.UI.MUTED))
        t.line:SetShown(on)
    end
    if ticker then ticker:Cancel(); ticker = nil end
    if which == "world" then
        UpdateWorldMarks()
        ticker = C_Timer.NewTicker(0.5, function()
            if panel:IsVisible() then UpdateWorldMarks() end
        end)
    else
        UpdateUnitMarks()
    end
end

local function UpdateLeave()
    sections.leaveInstance:SetEnabled(PartyUtil and PartyUtil.CanLeaveInstance and PartyUtil.CanLeaveInstance() or false)
end

local function UpdatePings()
    if not sections.pings then return end
    local value = C_PartyInfo.GetRestrictPings()
    for _, item in ipairs(sections.pingItems) do
        if item.value == value then sections.pings.Text:SetText(item.label) end
    end
end

-- Stack sections by permissions; out of combat only (panel is protected)
local function Layout()
    if not panel then return end
    if InCombatLockdown() then return ns.AfterCombat(Layout) end
    local rights, leader, mark = HasRights(), IsLeader(), CanMark()
    local y = -PAD

    -- Header: dropdown for the leader only, plain text otherwise
    sections.mode:SetShown(leader)
    sections.modeLabel:SetShown(not leader)
    y = y - 26

    local function Place(region, height, gap)
        y = y - (gap or 0)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", PAD, y)
        y = y - height
    end

    sections.leaderLabel:SetShown(rights)
    sections.leaderRow:SetShown(rights)
    if rights then
        Place(sections.leaderLabel, 12, 14)
        Place(sections.leaderRow, 34, 6)
    end

    sections.markLabel:SetShown(mark)
    sections.tabRow:SetShown(mark)
    sections.grids:SetShown(mark)
    if mark then
        Place(sections.markLabel, 12, 14)
        Place(sections.tabRow, 24, 6)
        Place(sections.grids, 2 * CELL + GAP, 8)
    end

    local pings = sections.pings and leader
    if sections.pings then
        sections.pingLabel:SetShown(pings)
        sections.pings:SetShown(pings)
    end
    if pings then
        Place(sections.pingLabel, 12, 14)
        Place(sections.pings, 28, 6)
    end

    Place(sections.leave, 28, 14)
    Place(sections.leaveInstance, 28, 8)
    panel:SetHeight(-y + PAD + 2)

    UpdateCount()
    UpdateLeave()
    UpdatePings()
    UpdateUnitMarks()
end

-- Build -------------------------------------------------------------------------------------------

local function BuildGrid(parent, kind)
    local grid = CreateFrame("Frame", nil, parent, "SecureFrameTemplate")
    grid:SetAllPoints()
    local list = kind == "raidtarget" and unitButtons or worldButtons
    local cells = {}
    for i = 1, 4 do cells[#cells + 1] = MarkerButton(grid, kind, UNIT_ORDER[i]) end
    -- Unit grid: "remove" top right; world markers clear individually via right-click -> gap
    if kind == "raidtarget" then cells[#cells + 1] = MarkerButton(grid, kind, nil, "remove") else cells[#cells + 1] = false end
    for i = 5, 8 do cells[#cells + 1] = MarkerButton(grid, kind, UNIT_ORDER[i]) end
    cells[#cells + 1] = MarkerButton(grid, kind, nil, "reset")
    for index, b in ipairs(cells) do
        if b then
            local col, row = (index - 1) % 5, math.floor((index - 1) / 5)
            b:SetPoint("TOPLEFT", col * (CELL + GAP), -row * (CELL + GAP))
            b.marker = kind == "raidtarget" and b:GetAttribute("marker") or nil
            list[#list + 1] = b
        end
    end
    return grid
end

local function MarkerTab(parent, label, key, x)
    local t = CreateFrame("Button", nil, parent, "SecureHandlerClickTemplate")
    t:SetSize(56, 24)
    t:SetPoint("TOPLEFT", x, 0)
    t.Text = ns.UI.Title(t, 13, "LEFT")
    t.Text:SetPoint("LEFT", 12, 0)
    t.Text:SetText(label)
    t:SetWidth(t.Text:GetUnboundedStringWidth() + 16)
    t.line = ns.UI.Diamond(t, 5) -- rune look: accent diamond marks the active tab
    t.line:SetPoint("LEFT", 2, 0)
    t:SetAttribute("which", key)
    t:SetAttribute("_onclick", [=[
        local unit, world = self:GetFrameRef("unit"), self:GetFrameRef("world")
        local which = self:GetAttribute("which")
        if which == "unit" then unit:Show(); world:Hide() else world:Show(); unit:Hide() end
    ]=])
    t:HookScript("OnClick", function()
        ns.db.groupManagerTab = key
        ShowTabVisual(key)
    end)
    return t
end

local function Build()
    root = CreateFrame("Frame", "MeredanUIGroupManager", UIParent, "SecureHandlerStateTemplate")
    root:SetSize(1, 1)
    root:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -220)
    root:SetFrameStrata("MEDIUM")
    RegisterStateDriver(root, "visibility", "[group] show; hide")

    panel = CreateFrame("Frame", nil, root, "SecureFrameTemplate")
    panel:SetPoint("TOPLEFT")
    panel:SetSize(WIDTH, 300)
    panel:EnableMouse(true)
    ns.UI.Box(panel, PANEL_BG, true)
    ns.RuneFrame(panel)

    -- Header
    sections.mode = Dropdown(panel, 150, 26, function(self)
        local items = {
            { value = "party", label = PARTY or "Party" },
            { value = "raid", label = RAID or "Raid" },
        }
        ns.UI.OpenList(self, items, IsInRaid() and "raid" or "party", function(value)
            local toRaid = value == "raid"
            if toRaid == IsInRaid() then return end
            if not C_PartyInfo.AllowedToDoPartyConversion(toRaid) then
                return UIErrorsFrame:AddMessage(L["Not possible right now."], 1, 0.1, 0.1)
            end
            if toRaid then C_PartyInfo.ConvertToRaid() else C_PartyInfo.ConvertToParty() end
        end)
    end)
    sections.mode:SetPoint("TOPLEFT", PAD, -PAD)
    sections.modeLabel = ns.UI.Text(panel, 14, "LEFT")
    sections.modeLabel:SetPoint("LEFT", sections.mode, "LEFT", 0, 0)
    sections.count = ns.UI.Text(panel, 13, "RIGHT", ns.UI.MUTED)
    sections.count:SetPoint("RIGHT", panel, "TOPRIGHT", -PAD, -PAD - 13)

    -- Leader
    sections.leaderLabel = SectionLabel(L["Leader"])
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(INNER, 34)
    sections.leaderRow = row
    local icons = {
        IconButton(row, "Check", READY_CHECK or L["Ready check"], function() C_PartyInfo.DoReadyCheck() end),
        IconButton(row, "RolePoll", ROLE_POLL or L["Role check"], function() InitiateRolePoll() end),
        IconButton(row, "Countdown", L["Countdown (10 sec.)"], function() C_PartyInfo.DoCountdown(10) end),
        IconButton(row, "Settings", L["Group settings"], function() ns.ShowSettings("groupframes") end),
    }
    for i, b in ipairs(icons) do b:SetPoint("LEFT", (i - 1) * 46, 0) end

    -- Markers
    sections.markLabel = SectionLabel(L["Markers"])
    local tabRow = CreateFrame("Frame", nil, panel)
    tabRow:SetSize(INNER, 24)
    sections.tabRow = tabRow
    local divider = tabRow:CreateTexture(nil, "BACKGROUND")
    divider:SetColorTexture(0.15, 0.18, 0.17, 1)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 0, -1)
    divider:SetPoint("BOTTOMRIGHT", 0, -1)
    local grids = CreateFrame("Frame", nil, panel, "SecureFrameTemplate")
    grids:SetSize(5 * CELL + 4 * GAP, 2 * CELL + GAP)
    sections.grids = grids
    local unitGrid, worldGrid = BuildGrid(grids, "raidtarget"), BuildGrid(grids, "worldmarker")
    local unitTab = MarkerTab(tabRow, L["Unit"], "unit", 0)
    local worldTab = MarkerTab(tabRow, L["Ground"], "world", unitTab:GetWidth() + 14)
    for _, t in ipairs({ unitTab, worldTab }) do
        t:SetFrameRef("unit", unitGrid)
        t:SetFrameRef("world", worldGrid)
    end
    sections.tabs = { unit = unitTab, world = worldTab }
    local startTab = ns.db.groupManagerTab == "world" and "world" or "unit"
    unitGrid:SetShown(startTab == "unit")
    worldGrid:SetShown(startTab == "world")
    ShowTabVisual(startTab)

    -- Pings (only when the ping system is enabled)
    if PingsEnabled() and C_PartyInfo.GetRestrictPings and Enum.RestrictPingsTo then
        sections.pingLabel = SectionLabel(L["Restrict pings to"])
        sections.pingItems = {
            { value = Enum.RestrictPingsTo.None, label = NONE or L["Nobody"] },
            { value = Enum.RestrictPingsTo.Lead, label = RAID_MANAGER_RESTRICT_PINGS_TO_LEAD or L["Leader"] },
            { value = Enum.RestrictPingsTo.Assist, label = RAID_MANAGER_RESTRICT_PINGS_TO_ASSIST or L["Assistants"] },
            { value = Enum.RestrictPingsTo.TankHealer, label = RAID_MANAGER_RESTRICT_PINGS_TO_TANKS_HEALERS or L["Tanks & healers"] },
        }
        sections.pings = Dropdown(panel, INNER, 28, function(self)
            ns.UI.OpenList(self, sections.pingItems, C_PartyInfo.GetRestrictPings(), function(value)
                C_PartyInfo.SetRestrictPings(value)
                C_Timer.After(0.2, UpdatePings)
            end)
        end)
    end

    -- Leave
    sections.leave = TextButton(panel, PARTY_LEAVE or L["Leave group"], { 1, 0.38, 0.38 }, function()
        C_PartyInfo.LeaveParty()
    end)
    for _, e in ipairs(sections.leave.edges) do e:SetVertexColor(0.29, 0.15, 0.15, 1) end
    sections.leave.SetMarked = function() end
    sections.leaveInstance = TextButton(panel, INSTANCE_PARTY_LEAVE or L["Leave instance group"], nil, function()
        if ConfirmOrLeaveParty then ConfirmOrLeaveParty() else C_PartyInfo.LeaveParty(LE_PARTY_CATEGORY_INSTANCE) end
    end)

    -- Tab: secure expand/collapse (works in combat)
    tab = CreateFrame("Button", nil, root, "SecureHandlerClickTemplate")
    tab:SetSize(TAB_W, TAB_H)
    tab:SetFrameLevel(panel:GetFrameLevel() + 5)
    -- Seamless with the panel: opaque, no left edge (overlaps the panel border by 1 px),
    -- accent line on top continues
    local tabBg = tab:CreateTexture(nil, "BACKGROUND")
    tabBg:SetAllPoints()
    tabBg:SetColorTexture(PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 1)
    local tabEdges = ns.AddBorder(tab)
    tabEdges[3]:Hide()
    local tabAccent = tab:CreateTexture(nil, "ARTWORK")
    tabAccent:SetColorTexture(unpack(ns.UI.ACCENT))
    tabAccent:SetPoint("TOPLEFT")
    tabAccent:SetPoint("TOPRIGHT")
    tabAccent:SetHeight(2)
    tab.icon = ns.UI.Icon(tab, "ChevronDown", 12, ns.UI.ACCENT)
    tab.icon:SetPoint("CENTER")
    tab:SetFrameRef("panel", panel)
    tab:SetAttribute("_onclick", [=[
        local p = self:GetFrameRef("panel")
        if p:IsShown() then p:Hide() else p:Show() end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", p:IsShown() and ]=] .. (WIDTH - 1) .. [=[ or 0, 0)
        self:SetAttribute("open", p:IsShown())
    ]=])
    tab:SetScript("OnAttributeChanged", function(self, name, value)
        if name ~= "open" then return end
        self.icon:SetRotation(value and -math.pi / 2 or math.pi / 2) -- < open, > closed
        ns.db.groupManagerOpen = value and true or false
    end)
    tab:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Group tools"], 1, 1, 1)
        GameTooltip:Show()
    end)
    tab:HookScript("OnLeave", GameTooltip_Hide)

    local open = ns.db.groupManagerOpen ~= false
    panel:SetShown(open)
    tab:SetPoint("TOPLEFT", root, "TOPLEFT", open and (WIDTH - 1) or 0, 0)
    tab:SetAttribute("open", open)
end

-- Hide Blizzard's manager (like HideBlizzardRaid in GroupFrames.lua)
local hidden
local function HideBlizzard()
    local manager = _G["CompactRaidFrameManager"]
    if not manager then return end
    if InCombatLockdown() then return ns.AfterCombat(HideBlizzard) end
    hidden = hidden or CreateFrame("Frame")
    hidden:Hide()
    manager:UnregisterAllEvents()
    manager:SetParent(hidden)
    manager:Hide()
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    ns.AfterCombat(function()
        Build()
        HideBlizzard()
        Layout()
    end)
end)

local function OnRoster()
    if not panel then return end
    Layout() -- defers itself until after combat
    if not InCombatLockdown() then return end
    UpdateCount()
    UpdateLeave()
end
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD" }) do
    ns:On(event, OnRoster)
end
ns:On("RAID_TARGET_UPDATE", function() if panel then UpdateUnitMarks() end end)
ns:On("PLAYER_TARGET_CHANGED", function() if panel then UpdateUnitMarks() end end)
ns:On("UNIT_FLAGS", function() if panel and panel:IsVisible() then UpdateCount() end end)
ns:On("PLAYER_FLAGS_CHANGED", function() if panel and panel:IsVisible() then UpdateCount() end end)
