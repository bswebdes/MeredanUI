-- mUI damage meter: up to two stacked windows top left (damage above, healing below); meter
-- type and session switchable by click. Data comes from Blizzard (C_DamageMeter); Blizzard's own
-- window is hidden.
--
--     Damage v             Current  1:23  R    <- header
--    [i]|1. Felyra        2,41M (29K) ######   <- spec icon, bar in class color
--    [i]|2. Kesh          2,18M (26K) ####
--    [i]|8. Brakk (own row, stays pinned)
--
-- Combat lockdown: values may be secrets in combat. NEVER do math or comparisons on them - only
-- pass them to Blizzard widgets (StatusBar:SetValue, AbbreviateLargeNumbers, SetFormattedText,
-- Texture:SetTexture). Blizzard delivers the list pre-sorted. Percentages and the spell breakdown
-- only work out of combat.
local _, ns = ...
local L = ns.L

-- Default is ONE window (second one optional); 5 rows in party, more in raid
local WIDTH = 335
local HEADER = 22
local ROW = 22
local GAP = 2          -- between rows
local PIN_GAP = 4      -- own (pinned) row slightly offset
local WINDOW_GAP = 8   -- between the two windows
local PARTY_ROWS = 5   -- solo/party
local RAID_ROWS = 10   -- raid (fewer if space is short)
local BOTTOM_GAP = 10  -- gap to the group frames below
local BAR_BG = { 0, 0, 0, 0.4 }
local COMBAT_COLOR = { 0.878, 0.541, 0.235 } -- #e08a3c: combat in progress
local GRAY = { r = 0.6, g = 0.6, b = 0.6 }
local REFRESH = 0.2    -- seconds: Blizzard fires very often in combat
-- Fading: visible only in combat and for a while afterwards; mouseover shows it any time
local LINGER = 30      -- seconds after combat
local FADE_SPEED = 4   -- alpha per second (~0.25 s)

local Type, SessionType = Enum.DamageMeterType, Enum.DamageMeterSessionType

local TYPES = { -- menu order; divider before entries with sep
    { Type.DamageDone, DAMAGE_METER_TYPE_DAMAGE_DONE },
    { Type.Dps, DAMAGE_METER_TYPE_DPS },
    { Type.HealingDone, DAMAGE_METER_TYPE_HEALING_DONE, sep = true },
    { Type.Hps, DAMAGE_METER_TYPE_HPS },
    { Type.Absorbs, DAMAGE_METER_TYPE_ABSORBS },
    { Type.Interrupts, DAMAGE_METER_TYPE_INTERRUPTS, sep = true },
    { Type.Dispels, DAMAGE_METER_TYPE_DISPELS },
    { Type.DamageTaken, DAMAGE_METER_TYPE_DAMAGE_TAKEN, sep = true },
    { Type.AvoidableDamageTaken, DAMAGE_METER_TYPE_AVOIDABLE_DAMAGE_TAKEN },
    { Type.Deaths, DAMAGE_METER_TYPE_DEATHS },
}
local TYPE_NAMES = {}
for _, entry in ipairs(TYPES) do TYPE_NAMES[entry[1]] = entry[2] end

-- Same as Blizzard (DamageMeterSessionWindow.lua)
local PER_SECOND_FIRST = { [Type.Dps] = true, [Type.Hps] = true }
local NO_PER_SECOND = { [Type.Interrupts] = true, [Type.Dispels] = true, [Type.Deaths] = true }
local PIN_SELF = {
    [Type.DamageDone] = true, [Type.Dps] = true, [Type.HealingDone] = true, [Type.Hps] = true,
    [Type.Absorbs] = true, [Type.Interrupts] = true, [Type.Dispels] = true,
    [Type.DamageTaken] = true, [Type.AvoidableDamageTaken] = true,
}

local DEFAULT_TYPES = { Type.DamageDone, Type.HealingDone }

local function Enabled() return ns.db.damageMeter ~= false end
local function SecondOn() return ns.db.damageMeterSecond == true end
local function FadeOn() return ns.db.damageMeterFade ~= false end
local function MeterOn()
    if not GetCVarBool("damageMeterEnabled") then return false end
    return C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable() == true
end

local holder
local ShowDetail -- spell breakdown on hover (defined below)
local windows = {}
local demoActive = false

-- Rows ---------------------------------------------------------------------------------------

local function CreateRow(window)
    local row = CreateFrame("Frame", nil, window)
    row:SetHeight(ns.Snap(ROW))
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT")
    row.icon:SetSize(ns.Snap(ROW), ns.Snap(ROW))
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local iconFrame = CreateFrame("Frame", nil, row)
    iconFrame:SetAllPoints(row.icon)
    ns.AddBorder(iconFrame, true)
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture(ns.STYLE.barTexture)
    row.bar:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", ns.Snap(1), 0)
    row.bar:SetPoint("BOTTOMRIGHT")
    local bg = row.bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(BAR_BG))
    local edge = CreateFrame("Frame", nil, row.bar)
    edge:SetAllPoints()
    edge:SetFrameLevel(row.bar:GetFrameLevel() + 2)
    row.edges = ns.AddBorder(edge, true)
    row.value = ns.CreateText(edge, 12, "RIGHT", "OUTLINE")
    row.value:SetPoint("RIGHT", -ns.Snap(5), 0)
    row.name = ns.CreateText(edge, 12, "LEFT", "OUTLINE")
    row.name:SetPoint("LEFT", ns.Snap(5), 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -ns.Snap(6), 0)
    row.window = window
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) if ShowDetail then ShowDetail(self) end end)
    -- Mouse wheel over a row scrolls the window
    row:SetScript("OnMouseWheel", function(_, delta)
        local scroll = window:GetScript("OnMouseWheel")
        if scroll then scroll(window, delta) end
    end)
    return row
end

local function SetSelf(row, isSelf)
    local color = isSelf and ns.UI.ACCENT or { 0, 0, 0 }
    for _, edge in ipairs(row.edges) do edge:SetVertexColor(color[1], color[2], color[3], 1) end
end

-- source: entry from combatSources (real) or a demo table with the same fields
local function FillRow(row, rank, source, maxAmount, kind)
    local color = RAID_CLASS_COLORS[source.classFilename] or GRAY
    row.bar:SetStatusBarColor(color.r, color.g, color.b)
    row.bar:SetMinMaxValues(0, maxAmount)
    row.bar:SetValue(source.totalAmount)
    local icon = source.specIconID
    if issecretvalue(icon) or (icon and icon ~= 0) then
        row.icon:SetTexture(icon)
    elseif source.classFilename and source.classFilename ~= "" then
        row.icon:SetAtlas(GetClassAtlas(source.classFilename))
    else
        row.icon:SetColorTexture(0.15, 0.15, 0.15, 1)
    end
    row.name:SetFormattedText("%d. %s", rank, source.name)
    local total, perSecond = AbbreviateLargeNumbers(source.totalAmount), AbbreviateLargeNumbers(source.amountPerSecond)
    if NO_PER_SECOND[kind] then
        row.value:SetText(total)
    elseif PER_SECOND_FIRST[kind] then
        row.value:SetFormattedText("%s (%s)", perSecond, total)
    else
        row.value:SetFormattedText("%s (%s)", total, perSecond)
    end
    SetSelf(row, source.isLocalPlayer == true)
    -- For the breakdown: keep only readable values (may be secrets in combat)
    local guid, creature, name = source.sourceGUID, source.sourceCreatureID, source.name
    row.guid = not issecretvalue(guid) and guid or nil
    row.creatureID = not issecretvalue(creature) and creature or nil
    row.sourceName = not issecretvalue(name) and name or nil
    row.classFilename = source.classFilename
    row.demoSpells, row.demoTotal = source.demoSpells, source.demoSpells and source.totalAmount or nil
    row:Show()
end

-- Spell breakdown: hovering a player after combat shows their spells in a dark panel next to the
-- meter (5 rows, rest scrollable). Disabled in combat: the lookup needs the source GUID, which is
-- secret then.
local DETAIL_W, DETAIL_ROW, DETAIL_ROWS = 300, 20, 5
local detail

local function DetailRow(i)
    local row = detail.rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, detail.list.child)
    row:SetHeight(ns.Snap(DETAIL_ROW))
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ns.Snap(DETAIL_ROW))
    row:SetPoint("RIGHT", detail.list.child, "RIGHT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ns.Snap(DETAIL_ROW - 4), ns.Snap(DETAIL_ROW - 4))
    row.icon:SetPoint("LEFT", ns.Snap(2), 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.pct = ns.CreateText(row, 11, "RIGHT")
    row.pct:SetPoint("RIGHT", -ns.Snap(4), 0)
    row.pct:SetWidth(ns.Snap(36))
    row.pct:SetTextColor(unpack(ns.UI.MUTED))
    row.amount = ns.CreateText(row, 12, "RIGHT")
    row.amount:SetPoint("RIGHT", row.pct, "LEFT", -ns.Snap(4), 0)
    row.name = ns.CreateText(row, 12, "LEFT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ns.Snap(6), 0)
    row.name:SetPoint("RIGHT", row.amount, "LEFT", -ns.Snap(6), 0)
    detail.rows[i] = row
    return row
end

local function CreateDetail()
    detail = CreateFrame("Frame", "MeredanUIDamageMeterDetail", holder)
    detail:SetFrameStrata("TOOLTIP")
    detail:SetWidth(ns.Snap(DETAIL_W))
    detail:EnableMouse(true)
    local bg = detail:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.03, 0.97) -- darker than other panels for readability
    ns.AddBorder(detail)
    local pad = ns.Snap(8)
    detail.title = ns.CreateText(detail, 13, "LEFT", nil, "bold")
    detail.title:SetPoint("TOPLEFT", pad, -pad)
    detail.total = ns.CreateText(detail, 13, "RIGHT", nil, "bold")
    detail.total:SetPoint("TOPRIGHT", -pad, -pad)
    detail.title:SetPoint("RIGHT", detail.total, "LEFT", -ns.Snap(6), 0)
    detail.list = ns.UI.ScrollArea(detail)
    detail.list:SetPoint("TOPLEFT", pad, -pad - ns.Snap(22))
    detail.list:SetPoint("RIGHT", -pad - ns.Snap(8), 0) -- room for the scrollbar
    detail.list:SetHeight(ns.Snap(DETAIL_ROW) * DETAIL_ROWS)
    detail.rows = {}
    detail:SetHeight(pad * 2 + ns.Snap(22) + ns.Snap(DETAIL_ROW) * DETAIL_ROWS)
end

local function Percent(part, whole)
    if issecretvalue(part) or issecretvalue(whole) or not whole or whole <= 0 then return "" end
    return ("%d %%"):format(math.floor(part / whole * 100 + 0.5))
end

local function SpellLabel(spellID, creatureName)
    if issecretvalue(spellID) then return nil end
    local name = C_Spell.GetSpellName(spellID)
    if not name then return nil end
    if not issecretvalue(creatureName) and creatureName and creatureName ~= "" then
        return DAMAGE_METER_SPELL_ENTRY_CREATURE:format(name, creatureName)
    end
    return name
end

ShowDetail = function(row)
    local window = row.window
    if UnitAffectingCombat("player") or window.kind == Type.Deaths then return end
    local spells, total
    if row.demoSpells then
        spells, total = {}, row.demoTotal
        for _, entry in ipairs(row.demoSpells) do
            spells[#spells + 1] = { spellID = entry[1], totalAmount = total * entry[2] }
        end
    else
        if not (row.guid or row.creatureID) then return end
        local source
        if window.sessionID then
            source = C_DamageMeter.GetCombatSessionSourceFromID(window.sessionID, window.kind, row.guid, row.creatureID)
        else
            source = C_DamageMeter.GetCombatSessionSourceFromType(window.sessionType, window.kind, row.guid, row.creatureID)
        end
        spells, total = source and source.combatSpells or {}, source and source.totalAmount
    end
    if #spells == 0 then return end
    if not detail then CreateDetail() end
    local color = RAID_CLASS_COLORS[row.classFilename] or GRAY
    detail.title:SetText(row.sourceName or "")
    detail.title:SetTextColor(color.r, color.g, color.b)
    detail.total:SetText(issecretvalue(total) and "" or AbbreviateLargeNumbers(total or 0))
    local shown = 0
    for _, spell in ipairs(spells) do
        local label = SpellLabel(spell.spellID, spell.creatureName)
        if label then
            shown = shown + 1
            local line = DetailRow(shown)
            line.icon:SetTexture(C_Spell.GetSpellTexture(spell.spellID) or 134400)
            line.name:SetText(label)
            line.amount:SetText(AbbreviateLargeNumbers(spell.totalAmount))
            line.pct:SetText(Percent(spell.totalAmount, total))
            line:Show()
        end
    end
    for i = shown + 1, #detail.rows do detail.rows[i]:Hide() end
    if shown == 0 then detail:Hide() return end
    detail.list:SetContentHeight(shown * ns.Snap(DETAIL_ROW))
    detail.list:ScrollToTop()
    detail.row, detail.away = row, 0
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", window, "TOPRIGHT", ns.Snap(8), 0)
    detail:SetPoint("TOP", row, "TOP", 0, 0)
    detail:Show()
end

-- Close when the mouse is on neither the row nor the panel (short grace period for the way between)
local function UpdateDetail(delta)
    if not (detail and detail:IsShown()) then return end
    if detail:IsMouseOver() or (detail.row and detail.row:IsMouseOver()) then
        detail.away = 0
        return
    end
    detail.away = detail.away + delta
    if detail.away > 0.3 then detail:Hide() end
end

-- Windows --------------------------------------------------------------------------------------

-- Header shows a single letter like Blizzard (C = current, O = overall, # = older session);
-- the full name is in the tooltip
local function SessionLabel(window)
    if window.sessionID then return "#" .. window.sessionID end
    if window.sessionType == SessionType.Overall then return L["DM_OVERALL_SHORT"] end
    return L["DM_CURRENT_SHORT"]
end

local function SessionName(window)
    if window.sessionID then return window.sessionName or DAMAGE_METER_COMBAT_NUMBER:format(window.sessionID) end
    if window.sessionType == SessionType.Overall then return DAMAGE_METER_OVERALL_SESSION end
    return DAMAGE_METER_CURRENT_SESSION
end

local function GetSession(window)
    if window.sessionID then return C_DamageMeter.GetCombatSessionFromID(window.sessionID, window.kind) end
    return C_DamageMeter.GetCombatSessionFromType(window.sessionType, window.kind)
end

local function SetClock(window, seconds)
    local clock = window.clock
    -- issecretvalue first: even "== nil" throws on a secret. Duration should never be secret;
    -- if it is, show nothing rather than error
    if issecretvalue(seconds) or seconds == nil then clock:SetText("") return end
    clock:SetText(SecondsToClock(seconds))
    local live = not window.sessionID and UnitAffectingCombat("player")
    local color = live and COMBAT_COLOR or ns.UI.MUTED
    clock:SetTextColor(color[1], color[2], color[3])
end

local function VisibleRows(window)
    return window.rowCount or PARTY_ROWS
end

-- Draws the list; sources = sorted list, maxAmount = top value (both may be secrets)
local function Render(window, sources, maxAmount)
    local count = #sources
    local visible = VisibleRows(window)
    window.offset = math.max(0, math.min(window.offset or 0, count - visible))
    local offset = window.offset
    -- Own row: if it is outside the visible range, it replaces the last row
    local selfIndex
    if PIN_SELF[window.kind] then
        for i, source in ipairs(sources) do
            if source.isLocalPlayer then selfIndex = i break end
        end
    end
    local pinned = selfIndex and (selfIndex <= offset or selfIndex > offset + visible) and count > visible
    local last = window.rows[visible]
    if last then
        last:SetPoint("TOPLEFT", window.header, "BOTTOMLEFT", 0,
            -ns.Snap(GAP) - (visible - 1) * (ns.Snap(ROW) + ns.Snap(GAP)) - (pinned and ns.Snap(PIN_GAP) or 0))
    end
    for slot = 1, visible do
        local row = window.rows[slot]
        local index = offset + slot
        if pinned and slot == visible then index = selfIndex end
        local source = sources[index]
        if source then
            FillRow(row, index, source, maxAmount, window.kind)
        else
            row:Hide()
        end
    end
    window.count = count
end

local function Refresh(window)
    window.title:SetText(TYPE_NAMES[window.kind] or "?")
    window.session:SetText(SessionLabel(window))
    if demoActive then return end
    local session = GetSession(window)
    local sources = session and session.combatSources or {}
    -- No "x or 0" on possibly secret values (the truth test throws)
    local maxAmount = session and session.maxAmount
    if not issecretvalue(maxAmount) and maxAmount == nil then maxAmount = 0 end
    Render(window, sources, maxAmount)
    local seconds = session and session.durationSeconds
    if not window.sessionID and window.sessionType ~= SessionType.Overall then
        local live = C_DamageMeter.GetSessionDurationSeconds(window.sessionType)
        if issecretvalue(live) or live ~= nil then seconds = live end
    end
    SetClock(window, seconds)
end

local dirty, elapsed = false, 0
local function RefreshAll()
    dirty = false
    for _, window in ipairs(windows) do Refresh(window) end
end
local function MarkDirty() dirty = true end

-- Menus
local openMenu -- last opened menu: keeps the meter visible while open
local function SaveTypes()
    ns.db.damageMeterTypes = { windows[1].kind, windows[2].kind }
end

local function OpenTypeMenu(window)
    openMenu = MenuUtil.CreateContextMenu(window.typeButton, function(_, root)
        local function IsSelected(kind) return window.kind == kind end
        local function SetSelected(kind)
            window.kind, window.offset = kind, 0
            SaveTypes()
            Refresh(window)
            if demoActive and ns.DamageMeterDemo.Update then ns.DamageMeterDemo.Update() end
        end
        for _, entry in ipairs(TYPES) do
            if entry.sep then root:CreateDivider() end
            root:CreateRadio(entry[2], IsSelected, SetSelected, entry[1])
        end
    end)
end

local function OpenSessionMenu(window)
    openMenu = MenuUtil.CreateContextMenu(window.sessionButton, function(_, root)
        local function IsSelected(data)
            return window.sessionID == data.id and (data.id ~= nil or window.sessionType == data.type)
        end
        local function SetSelected(data)
            window.sessionType, window.sessionID, window.sessionName, window.offset = data.type, data.id, data.name, 0
            Refresh(window)
        end
        root:CreateRadio(DAMAGE_METER_CURRENT_SESSION, IsSelected, SetSelected, { type = SessionType.Current })
        root:CreateRadio(DAMAGE_METER_OVERALL_SESSION, IsSelected, SetSelected, { type = SessionType.Overall })
        local sessions = C_DamageMeter.GetAvailableCombatSessions() or {}
        if #sessions > 0 then root:CreateDivider() end
        -- Newest first
        for i = #sessions, 1, -1 do
            local info = sessions[i]
            local name = info.name
            if not name or name == "" then name = DAMAGE_METER_COMBAT_NUMBER:format(info.sessionID) end
            local label = name
            if info.durationSeconds then label = ("%s  %s"):format(name, SecondsToClock(info.durationSeconds)) end
            root:CreateRadio(label, IsSelected, SetSelected, { id = info.sessionID, name = name })
        end
    end)
end

local function Tooltip(button, text)
    button:SetScript("OnEnter", function(self)
        if self.icon then self.icon:SetVertexColor(unpack(ns.UI.ACCENT)) end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(text)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        if self.icon then self.icon:SetVertexColor(unpack(ns.UI.MUTED)) end
        GameTooltip:Hide()
    end)
end

local function CreateWindow(index)
    local window = CreateFrame("Frame", "MeredanUIDamageMeter" .. index, holder)
    window:SetWidth(ns.Snap(WIDTH))
    window.kind = (ns.db.damageMeterTypes and ns.db.damageMeterTypes[index]) or DEFAULT_TYPES[index]
    window.sessionType = SessionType.Current
    window.rows = {}

    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(ns.Snap(HEADER))
    -- Header without background or border, only muted text and icons; hover: Surf Green
    window.header = header
    local pad = ns.Snap(6)

    -- Meter type (left): click opens the type list
    local typeButton = CreateFrame("Button", nil, header)
    typeButton:SetPoint("TOPLEFT")
    typeButton:SetPoint("BOTTOMLEFT")
    window.title = ns.CreateText(typeButton, 12, "LEFT", nil, "bold")
    window.title:SetPoint("LEFT", pad, 0)
    window.title:SetTextColor(unpack(ns.UI.MUTED))
    local chevron = typeButton:CreateTexture(nil, "OVERLAY")
    chevron:SetTexture(ns.MEDIA .. "Icons\\ChevronDown")
    chevron:SetSize(10, 10)
    chevron:SetPoint("LEFT", window.title, "RIGHT", ns.Snap(4), 0)
    chevron:SetVertexColor(unpack(ns.UI.MUTED))
    typeButton:SetScript("OnClick", function() OpenTypeMenu(window) end)
    typeButton:SetScript("OnEnter", function()
        window.title:SetTextColor(unpack(ns.UI.ACCENT))
        chevron:SetVertexColor(unpack(ns.UI.ACCENT))
    end)
    typeButton:SetScript("OnLeave", function()
        window.title:SetTextColor(unpack(ns.UI.MUTED))
        chevron:SetVertexColor(unpack(ns.UI.MUTED))
    end)
    hooksecurefunc(window.title, "SetText", function()
        typeButton:SetWidth(pad + window.title:GetStringWidth() + ns.Snap(18))
    end)
    window.typeButton = typeButton

    -- Right side: reset, clock, session
    local reset = CreateFrame("Button", nil, header)
    reset:SetSize(ns.Snap(HEADER), ns.Snap(HEADER))
    reset:SetPoint("RIGHT", -ns.Snap(2), 0)
    reset.icon = reset:CreateTexture(nil, "OVERLAY")
    reset.icon:SetTexture(ns.MEDIA .. "Icons\\Reset")
    reset.icon:SetSize(12, 12)
    reset.icon:SetPoint("CENTER")
    reset.icon:SetVertexColor(unpack(ns.UI.MUTED))
    reset:SetScript("OnClick", function()
        if demoActive then return end
        C_DamageMeter.ResetAllCombatSessions()
    end)
    Tooltip(reset, DAMAGE_METER_RESET_ALL_SESSIONS)

    window.clock = ns.CreateText(header, 12, "RIGHT")
    window.clock:SetPoint("RIGHT", reset, "LEFT", -ns.Snap(2), 0)

    -- Session: a single letter (C/O/#3), name in the tooltip
    local sessionButton = CreateFrame("Button", nil, header)
    sessionButton:SetHeight(ns.Snap(HEADER))
    sessionButton:SetPoint("RIGHT", window.clock, "LEFT", -ns.Snap(6), 0)
    window.session = ns.CreateText(sessionButton, 12, "CENTER", nil, "bold")
    window.session:SetPoint("CENTER", 0, 0)
    window.session:SetTextColor(unpack(ns.UI.MUTED))
    hooksecurefunc(window.session, "SetText", function()
        sessionButton:SetWidth(math.max(ns.Snap(HEADER - 6), window.session:GetStringWidth() + ns.Snap(8)))
    end)
    sessionButton:SetScript("OnClick", function() OpenSessionMenu(window) end)
    sessionButton:SetScript("OnEnter", function(self)
        window.session:SetTextColor(unpack(ns.UI.ACCENT))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(SessionName(window))
        GameTooltip:Show()
    end)
    sessionButton:SetScript("OnLeave", function()
        window.session:SetTextColor(unpack(ns.UI.MUTED))
        GameTooltip:Hide()
    end)
    window.sessionButton = sessionButton

    -- Mouse wheel: scroll
    window:EnableMouseWheel(true)
    window:SetScript("OnMouseWheel", function(self, delta)
        self.offset = (self.offset or 0) - delta
        if demoActive then
            if ns.DamageMeterDemo.Update then ns.DamageMeterDemo.Update() end
        else
            Refresh(self)
        end
    end)
    return window
end

-- Create/arrange rows for the available height
local function LayoutRows(window, rowCount)
    window.rowCount = rowCount
    for i = 1, rowCount do
        local row = window.rows[i] or CreateRow(window)
        window.rows[i] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window.header, "BOTTOMLEFT", 0, -ns.Snap(GAP) - (i - 1) * (ns.Snap(ROW) + ns.Snap(GAP)))
        row:SetPoint("RIGHT", window, "RIGHT")
    end
    for i = rowCount + 1, #window.rows do window.rows[i]:Hide() end
    window:SetHeight(ns.Snap(HEADER) + rowCount * (ns.Snap(ROW) + ns.Snap(GAP)))
end

-- Raid sized? Live: IsInRaid; in the preview the size chosen there (5/25/40)
local function RaidSized()
    if demoActive then return ns.Preview and ns.Preview.GroupKind and ns.Preview.GroupKind() ~= "group" end
    return IsInRaid()
end

-- Position: top left corner. Rows: 5 solo/party, up to 10 in raid - but never lower than just
-- above the group frames (healer layout: group sits centered, left side is free)
local function Place()
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", margin, -margin)
    local count = SecondOn() and 2 or 1
    local rowHeight = ns.Snap(ROW) + ns.Snap(GAP)
    local wanted = RaidSized() and RAID_ROWS or PARTY_ROWS
    if not ns.LayoutFlag("healerGroups") then
        local _, cy = UIParent:GetCenter()
        local available = (UIParent:GetTop() - margin) - (cy + ns.Snap(300) + ns.Snap(BOTTOM_GAP))
        local perWindow = (available - (count - 1) * ns.Snap(WINDOW_GAP)) / count - ns.Snap(HEADER) - ns.Snap(PIN_GAP)
        wanted = math.max(3, math.min(wanted, math.floor(perWindow / rowHeight)))
    end
    for i, window in ipairs(windows) do
        LayoutRows(window, wanted)
        window:SetShown(i <= count)
        window:ClearAllPoints()
        if i == 1 then
            window:SetPoint("TOPLEFT", holder, "TOPLEFT")
        else
            window:SetPoint("TOPLEFT", windows[i - 1], "BOTTOMLEFT", 0, -ns.Snap(WINDOW_GAP + PIN_GAP))
        end
    end
    holder:SetSize(ns.Snap(WIDTH), count * windows[1]:GetHeight() + (count - 1) * ns.Snap(WINDOW_GAP + PIN_GAP))
    if holder:IsShown() then MarkDirty() end
end
ns.RelayoutDamageMeter = function() if holder then Place() end end

local function UpdateShown()
    local show = demoActive or MeterOn()
    holder:SetShown(show)
    if show then MarkDirty() end
    if ns.PlaceToastHolder then ns.PlaceToastHolder() end -- toasts sit to the right of the meter
end

-- Blizzard's window stays hidden while ours runs. Blizzard re-shows it on combat/group/Edit Mode,
-- so hide it again every time; only Hide, no fields/functions on the frame (taint).
local function HideBlizzard()
    local meter = DamageMeter
    if not meter then return end
    local function Hide(self) self:Hide() end
    meter:HookScript("OnShow", Hide)
    meter:Hide()
end

-- Start --------------------------------------------------------------------------------------

-- Blizzard's toggle (Options > Advanced) follows the mUI meter: on = Blizzard data on (off by
-- default in Forever), off = both off. The settings call this when toggling.
function ns.SyncDamageMeterCVar()
    if ns.HasCVar and not ns.HasCVar("damageMeterEnabled") then return end
    SetCVar("damageMeterEnabled", Enabled() and "1" or "0")
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not C_DamageMeter then return end
    if not GetCVarBool("damageMeterEnabled") then ns.SyncDamageMeterCVar() end
    holder = CreateFrame("Frame", "MeredanUIDamageMeter", UIParent)
    holder:SetFrameStrata("LOW")
    windows[1] = CreateWindow(1)
    windows[2] = CreateWindow(2)
    ns.layoutFrames.damagemeter = holder
    ns.OnLayout(Place)
    local combatEnd, wheel = 0, nil
    ns:On("PLAYER_REGEN_ENABLED", function() combatEnd = GetTime() end)
    holder:SetScript("OnUpdate", function(self, delta)
        -- Fade in/out every frame, alpha only - no Show/Hide, so the mouse can still find it
        local want = 1
        if FadeOn() and not demoActive and not UnitAffectingCombat("player") and GetTime() - combatEnd > LINGER
            and not self:IsMouseOver() and not (openMenu and openMenu:IsShown()) and not (detail and detail:IsShown()) then
            want = 0
        end
        local alpha = self:GetAlpha()
        if alpha ~= want then
            alpha = want > alpha and math.min(want, alpha + delta * FADE_SPEED) or math.max(want, alpha - delta * FADE_SPEED)
            self:SetAlpha(alpha)
        end
        -- Invisible: don't swallow the mouse wheel (camera zoom top left would break)
        local visible = alpha > 0
        if visible ~= wheel then
            wheel = visible
            for _, window in ipairs(windows) do
                window:EnableMouseWheel(visible)
                for _, row in ipairs(window.rows) do -- invisible: don't swallow clicks/mouse wheel
                    row:EnableMouse(visible)
                    row:EnableMouseWheel(visible)
                end
            end
        end
        UpdateDetail(delta)
        elapsed = elapsed + delta
        if elapsed < REFRESH then return end
        elapsed = 0
        -- In combat the clock keeps running even without new numbers
        if dirty or UnitAffectingCombat("player") then
            if not demoActive then RefreshAll() end
        end
    end)
    HideBlizzard()
    UpdateShown()
    ns:On("DAMAGE_METER_COMBAT_SESSION_UPDATED", MarkDirty)
    ns:On("DAMAGE_METER_CURRENT_SESSION_UPDATED", MarkDirty)
    ns:On("DAMAGE_METER_RESET", function()
        for _, window in ipairs(windows) do
            -- A selected old session no longer exists after a reset
            window.sessionID, window.sessionName, window.offset = nil, nil, 0
            window.sessionType = window.sessionType or SessionType.Current
        end
        MarkDirty()
    end)
    -- Party -> raid: more rows (our frames are not protected, so this works in combat)
    local wasRaid = IsInRaid()
    ns:On("GROUP_ROSTER_UPDATE", function()
        if IsInRaid() ~= wasRaid then
            wasRaid = IsInRaid()
            Place()
        end
    end)
    ns:On("PLAYER_REGEN_DISABLED", function()
        MarkDirty()
        if detail then detail:Hide() end
    end)
    ns:On("PLAYER_REGEN_ENABLED", MarkDirty)
    ns:On("CVAR_UPDATE", function(_, name)
        if name == "damageMeterEnabled" then UpdateShown() end
    end)
    ns:On("PLAYER_ENTERING_WORLD", UpdateShown)
    ns:On("PLAYER_LEVEL_UP", UpdateShown)
end)

-- Preview (/mui t): sample group like the group preview, values count up --------------------

-- First five = sample group of the group preview (Brakk = you); ten in raid
local DEMO = { -- name, class, spec ID, damage/s, healing/s, you
    { "Brakk", "WARRIOR", 73, 13500, 2500, true }, { "Lunara", "PRIEST", 257, 3700, 19800 },
    { "Felyra", "MAGE", 63, 29000, 200 }, { "Kesh", "ROGUE", 260, 26000, 800 },
    { "Thalor", "HUNTER", 254, 22500, 500 }, { "Velra", "WARLOCK", 266, 31000, 600 },
    { "Orrin", "PALADIN", 70, 24000, 9500 }, { "Morwen", "DRUID", 102, 21000, 900 },
    { "Daran", "SHAMAN", 262, 27500, 400 }, { "Isolde", "MAGE", 62, 30000, 150 },
}
-- Sample spells per class for the preview breakdown: spell ID, share
local DEMO_SPELLS = {
    WARRIOR = { { 12294, 0.34 }, { 78, 0.24 }, { 6603, 0.2 }, { 6343, 0.12 }, { 772, 0.06 }, { 845, 0.04 } },
    PRIEST = { { 585, 0.5 }, { 589, 0.3 }, { 8092, 0.2 } },
    MAGE = { { 133, 0.46 }, { 11366, 0.25 }, { 2136, 0.16 }, { 2120, 0.08 }, { 6603, 0.05 } },
    ROGUE = { { 1752, 0.38 }, { 6603, 0.3 }, { 2098, 0.22 }, { 1943, 0.1 } },
    HUNTER = { { 75, 0.36 }, { 3044, 0.28 }, { 1978, 0.16 }, { 2643, 0.12 }, { 17253, 0.08 } },
    WARLOCK = { { 686, 0.55 }, { 172, 0.2 }, { 980, 0.15 }, { 3110, 0.1 } },
    PALADIN = { { 6603, 0.45 }, { 20271, 0.3 }, { 879, 0.25 } },
    DRUID = { { 5176, 0.5 }, { 8921, 0.3 }, { 6603, 0.2 } },
    SHAMAN = { { 403, 0.5 }, { 8042, 0.3 }, { 6603, 0.2 } },
}
local demoTicker, demoElapsed, demoTotals

local function DemoSources(kind)
    local healing = kind == Type.HealingDone or kind == Type.Hps or kind == Type.Absorbs
    local list = {}
    local size = RaidSized() and #DEMO or 5
    for i, data in ipairs(DEMO) do
        if i > size then break end
        local total = demoTotals[i][healing and 2 or 1]
        local icon = GetSpecializationInfoByID and select(4, GetSpecializationInfoByID(data[3]))
        list[#list + 1] = {
            name = data[1], classFilename = data[2], specIconID = icon or 0, isLocalPlayer = data[6] == true,
            totalAmount = total, amountPerSecond = total / math.max(demoElapsed, 1),
            demoSpells = DEMO_SPELLS[data[2]],
        }
    end
    -- Same combat duration for all: sorted by total = sorted by per second
    table.sort(list, function(a, b) return a.totalAmount > b.totalAmount end)
    return list
end

local function UpdateDemo()
    if not demoActive then return end
    for _, window in ipairs(windows) do
        local list = DemoSources(window.kind)
        Render(window, list, math.max(list[1] and list[1].totalAmount or 0, 1))
        SetClock(window, demoElapsed)
    end
end

local demoRaid
local function DemoTick()
    demoElapsed = demoElapsed + 0.5
    if RaidSized() ~= demoRaid then -- size changed in the preview
        demoRaid = RaidSized()
        Place()
    end
    for i, data in ipairs(DEMO) do
        demoTotals[i][1] = demoTotals[i][1] + data[4] * 0.5 * (0.7 + math.random() * 0.6)
        demoTotals[i][2] = demoTotals[i][2] + data[5] * 0.5 * (0.7 + math.random() * 0.6)
    end
    UpdateDemo()
end

ns.DamageMeterDemo = {
    Start = function()
        if not holder then return end
        demoActive, demoElapsed, demoTotals, demoRaid = true, 0, {}, nil
        for i = 1, #DEMO do demoTotals[i] = { 0, 0 } end
        UpdateShown()
        for _, window in ipairs(windows) do Refresh(window) end
        DemoTick()
        if demoTicker then demoTicker:Cancel() end
        demoTicker = C_Timer.NewTicker(0.5, DemoTick)
    end,
    Stop = function()
        if demoTicker then demoTicker:Cancel() end
        demoTicker = nil
        if not demoActive then return end
        demoActive = false
        if holder then
            Place()
            UpdateShown()
        end
    end,
    IsActive = function() return demoActive end,
    Update = UpdateDemo,
}

ns:On("PLAYER_REGEN_DISABLED", function()
    if demoActive then ns.DamageMeterDemo.Stop() end
end)

-- Diagnostics (/mui dmeter): state to chat + DevLog. Values in combat are secrets, so print them
-- only as "secret", never compare.
local function S(v)
    if issecretvalue(v) then return "secret" end
    return tostring(v)
end

local function Dump()
    local P = ns.Print
    if not C_DamageMeter then P("dmeter: C_DamageMeter fehlt") return end
    local available, reason = C_DamageMeter.IsDamageMeterAvailable()
    P("dmeter: verfügbar=%s (%s) cvar=%s mUI=%s kampf=%s instanz=%s", S(available), S(reason),
        tostring(GetCVar("damageMeterEnabled")), tostring(Enabled()), tostring(InCombatLockdown()), tostring(select(2, IsInInstance())))
    local sessions = C_DamageMeter.GetAvailableCombatSessions() or {}
    P("dmeter: %d Sitzungen", #sessions)
    for i, session in ipairs(sessions) do
        if i <= 5 then P("  #%s %s %s s", S(session.sessionID), S(session.name), S(session.durationSeconds)) end
    end
    for _, kind in ipairs({ { "Gesamt", SessionType.Overall }, { "Aktuell", SessionType.Current } }) do
        local session = C_DamageMeter.GetCombatSessionFromType(kind[2], Type.DamageDone)
        local sources = session and session.combatSources
        P("dmeter: %s: Quellen=%s gesamt=%s max=%s dauer=%s", kind[1], sources and #sources or "nil",
            S(session and session.totalAmount), S(session and session.maxAmount), S(session and session.durationSeconds))
        local first = sources and sources[1]
        if first then
            P("  1. %s (%s) %s /s %s icon=%s ich=%s", S(first.name), S(first.classFilename), S(first.totalAmount),
                S(first.amountPerSecond), S(first.specIconID), S(first.isLocalPlayer))
        end
    end
    P("dmeter: Fenster=%s sichtbar=%s Blizzard sichtbar=%s", tostring(holder ~= nil), tostring(holder and holder:IsShown()),
        tostring(DamageMeter and DamageMeter:IsShown()))
    for i, window in ipairs(windows) do
        P("  %d: Art=%s Sitzung=%s/%s Zeilen=%s Quellen=%s", i, S(window.kind), S(window.sessionType), S(window.sessionID),
            S(window.rowCount), S(window.count))
    end
end

ns.AddCommand("dmeter", L["damage meter diagnostics to chat + DevLog"], Dump)
