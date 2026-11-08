-- Inspect window (other players' gear, WoW Forever): mUI window replacing Blizzard's InspectFrame,
-- sibling of the character window. Tabs as in Blizzard's: gear, PvP rank, guild (if any).
--
--   [Portrait] Lumina Moonspark                    [x]   [Tabs]
--              Level 17 - Warrior - Item level 13
--   [Slots]  [ model with race background ]  [Slots]
--            [Main][Off][Ranged]
--
-- Flow as in Blizzard_InspectUI.lua: NotifyInspect -> INSPECT_READY -> show; a target change closes
-- it (for "target"), closing frees the data (ClearInspectPlayer).
local _, ns = ...
local L = ns.L
local Char = ns.Char

local SLOT, SLOT_GAP = 40, 6
local DOLL_W = 400
local PAD = ns.NPC_PAD
local TOP = ns.NPC_HEADER_BOTTOM + 16
local TAB_SIZE, TAB_STEP = 40, 46
local WIDTH = DOLL_W + 2 * PAD

local LEFT_SLOTS = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "BACKSLOT", "CHESTSLOT", "SHIRTSLOT", "TABARDSLOT", "WRISTSLOT" }
local RIGHT_SLOTS = { "HANDSSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT" }
local BOTTOM_SLOTS = { "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT" }
local NO_LEVEL = { [INVSLOT_BODY or 4] = true, [INVSLOT_TABARD or 19] = true }

local window, unit, guid
local slots, tabButtons, views = {}, {}, {}
local current = "gear"
local UI

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.characterWindow ~= false
end

-- Gear -------------------------------------------------------------------------------------------

local function CreateSlot(parent, slotName)
    local slot, texture = C_PaperDollInfo.GetInventorySlotInfo(slotName)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SLOT, SLOT)
    button.slot, button.slotName, button.emptyTexture = slot, slotName, texture
    ns.AddSlotBackground(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.border = ns.AddBorder(button)
    button.level = ns.CreateText(button, 12, "CENTER", "OUTLINE")
    button.level:SetPoint("BOTTOM", 0, 3)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.12)
    -- Shift click = link to chat, ctrl click = dress up (HandleModifiedItemClick)
    button:SetScript("OnClick", function(self)
        local link = unit and GetInventoryItemLink(unit, self.slot)
        if link and not issecretvalue(link) then HandleModifiedItemClick(link) end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if unit and GetInventoryItemLink(unit, self.slot) then
            GameTooltip:SetInventoryItem(unit, self.slot)
        else
            GameTooltip:SetText(_G[self.slotName] or self.slotName, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slots[#slots + 1] = button
    return button
end

local function UpdateSlot(button)
    local link = GetInventoryItemLink(unit, button.slot)
    if link and issecretvalue(link) then link = nil end
    local texture = link and GetInventoryItemTexture(unit, button.slot)
    local quality = link and select(3, C_Item.GetItemInfo(link))
    button.icon:SetTexture(texture or button.emptyTexture)
    button.icon:SetDesaturated(not texture)
    button.icon:SetAlpha(texture and 1 or 0.35)
    local r, g, b = 0, 0, 0
    if quality and quality > 1 then r, g, b = C_Item.GetItemQualityColor(quality) end
    for _, edge in ipairs(button.border) do edge:SetVertexColor(r, g, b, 1) end
    -- Item level as in the character window (same option)
    local level = link and ns.db.characterItemLevels ~= false and not NO_LEVEL[button.slot] and C_Item.GetDetailedItemLevelInfo(link)
    if level and not issecretvalue(level) and level > 1 then
        local qr, qg, qb = 1, 1, 1
        if quality then qr, qg, qb = C_Item.GetItemQualityColor(quality) end
        button.level:SetTextColor(qr, qg, qb)
        button.level:SetText(level)
        button.level:Show()
    else
        button.level:Hide()
    end
end

local function CreateGear(view)
    local stage = CreateFrame("Frame", nil, view)
    stage:SetPoint("TOPLEFT", SLOT + 14, 0)
    stage:SetPoint("BOTTOMRIGHT", -(SLOT + 14), SLOT + 22)
    UI.Box(stage, { 0.08, 0.08, 0.09, 1 })
    view.backdrop = Char.RaceBackdrop(stage)
    local model = CreateFrame("PlayerModel", nil, stage)
    model:SetPoint("TOPLEFT", 1, -1)
    model:SetPoint("BOTTOMRIGHT", -1, 1)
    model.zoom = 1
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
    model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
    model:SetScript("OnUpdate", function(self)
        if not self.dragX then return end
        local x = GetCursorPosition()
        self:SetFacing(self:GetFacing() + (x - self.dragX) * 0.012)
        self.dragX = x
    end)
    model:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.min(math.max(self.zoom - delta * 0.1, 0.5), 1.4)
        self:SetCamDistanceScale(self.zoom)
    end)
    view.model = model
    for i, name in ipairs(LEFT_SLOTS) do CreateSlot(view, name):SetPoint("TOPLEFT", 0, -(i - 1) * (SLOT + SLOT_GAP)) end
    for i, name in ipairs(RIGHT_SLOTS) do CreateSlot(view, name):SetPoint("TOPRIGHT", 0, -(i - 1) * (SLOT + SLOT_GAP)) end
    local total = #BOTTOM_SLOTS * SLOT + (#BOTTOM_SLOTS - 1) * SLOT_GAP
    for i, name in ipairs(BOTTOM_SLOTS) do
        CreateSlot(view, name):SetPoint("BOTTOMLEFT", (DOLL_W - total) / 2 + (i - 1) * (SLOT + SLOT_GAP), 0)
    end
end

local function RefreshGear(view)
    for _, button in ipairs(slots) do UpdateSlot(button) end
    view.backdrop:SetUnit(unit)
    if view.model.guid ~= guid then
        view.model:ClearModel()
        view.model:SetUnit(unit)
        view.model:SetCamDistanceScale(view.model.zoom)
        view.model.guid = guid
    end
end

-- PvP rank (GetInspectHonorData, as in Blizzard's InspectPVPFrame) --------------------------------

local function RankName(rank)
    if not rank or rank <= 0 then return PVP_RANK_0_NAME or "" end
    local alliance = UnitFactionGroup(unit) == "Alliance" and 1 or 0
    return GetText("PVP_RANK_" .. (Enum.PvPRanks.Rank_1 + rank - 1) .. "_" .. alliance, UnitSex(unit)) or ""
end

local function CreatePvP(view)
    local block = CreateFrame("Frame", nil, view)
    block:SetSize(DOLL_W, 400)
    block:SetPoint("CENTER", 0, 10)
    view.badge = block:CreateTexture(nil, "ARTWORK")
    view.badge:SetSize(120, 120)
    view.badge:SetPoint("TOP", 0, -10)
    view.rank = UI.Text(block, 20, "CENTER")
    ns.SetFont(view.rank, 20, "", "bold")
    view.rank:SetPoint("TOP", view.badge, "BOTTOM", 0, -14)
    view.rankNumber = UI.Text(block, 13, "CENTER", UI.MUTED)
    view.rankNumber:SetPoint("TOP", view.rank, "BOTTOM", 0, -6)
    view.barLabel = UI.Text(block, 12, "LEFT", UI.MUTED)
    view.barLabel:SetPoint("TOPLEFT", view.rankNumber, "BOTTOM", -130, -16)
    view.barLabel:SetText(L["Rank points"])
    view.bar = Char.Bar(block, 20)
    view.bar:SetSize(260, 20)
    view.bar:SetPoint("TOP", view.rankNumber, "BOTTOM", 0, -34)
    -- Honorable kills as a small grid (accent header like the character window)
    view.rows = {}
    local function Row(i, header)
        local row = CreateFrame("Frame", nil, block)
        row:SetSize(260, header and 24 or 22)
        row:SetPoint("TOP", view.bar, "BOTTOM", 0, -24 - (i - 1) * 24)
        row.a = UI.Text(row, header and 12 or 13, "LEFT", header and UI.ACCENT or UI.MUTED)
        row.a:SetPoint("LEFT")
        row.c = UI.Text(row, 13, "RIGHT")
        row.c:SetPoint("RIGHT")
        if header then
            local rule = row:CreateTexture(nil, "BORDER")
            rule:SetPoint("BOTTOMLEFT", 0, -1)
            rule:SetPoint("BOTTOMRIGHT", 0, -1)
            rule:SetHeight(ns.PixelSize())
            rule:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.6)
        end
        view.rows[i] = row
        return row
    end
    Row(1, true).a:SetText(Char.G("HONORABLE_KILLS", "Honorable kills"))
    Row(2).a:SetText(Char.G("HONOR_LIFETIME", "Lifetime"))
    Row(3).a:SetText(Char.G("HONOR_TODAY", "Today"))
end

local function RefreshPvP(view)
    local today, lifetime, rank, points, nextPoints
    if GetInspectHonorData then
        local data = { GetInspectHonorData() }
        today, lifetime, rank, points, nextPoints = data[1], data[5], data[7], data[8], data[9]
    end
    rank, points, nextPoints = rank or 0, points or 0, nextPoints or 0
    view.rank:SetText(RankName(rank))
    view.rankNumber:SetText(rank > 0 and (PVP_RANK_NUMBER or "%d"):format(rank) or "")
    view.bar:Set(points, nextPoints, { 0.24, 0.44, 0.82 }, ("%s/%s"):format(BreakUpLargeNumbers(points), BreakUpLargeNumbers(nextPoints)))
    local atlas = rank > 0 and ("UI-Character-Info-Honor-Icon-%d"):format(rank)
    if not (atlas and C_Texture.GetAtlasInfo(atlas)) then
        atlas = UnitFactionGroup(unit) == "Horde" and "UI-Character-Info-Honor-Icon-Horde" or "UI-Character-Info-Honor-Icon-Alliance"
    end
    view.badge:SetAtlas(atlas)
    view.rows[2].c:SetText(BreakUpLargeNumbers(lifetime or 0))
    view.rows[3].c:SetText(BreakUpLargeNumbers(today or 0))
end

-- Guild (C_PaperDollInfo.GetInspectGuildInfo, as in Blizzard's InspectGuildFrame) -----------------

local function CreateGuild(view)
    local block = CreateFrame("Frame", nil, view)
    block:SetSize(DOLL_W, 300)
    block:SetPoint("CENTER", 0, 20)
    view.tabard = CreateFrame("Frame", nil, block)
    view.tabard:SetSize(96, 96)
    view.tabard:SetPoint("TOP")
    view.banner = view.tabard:CreateTexture(nil, "BACKGROUND")
    view.banner:SetAllPoints()
    view.bannerBorder = view.tabard:CreateTexture(nil, "BORDER")
    view.bannerBorder:SetAllPoints()
    view.left = view.tabard:CreateTexture(nil, "ARTWORK")
    view.left:SetPoint("TOPLEFT")
    view.left:SetPoint("BOTTOMRIGHT", view.tabard, "BOTTOM")
    view.right = view.tabard:CreateTexture(nil, "ARTWORK")
    view.right:SetPoint("TOPRIGHT")
    view.right:SetPoint("BOTTOMLEFT", view.tabard, "BOTTOM")
    view.name = UI.Text(block, 20, "CENTER")
    ns.SetFont(view.name, 20, "", "bold")
    view.name:SetPoint("TOP", view.tabard, "BOTTOM", 0, -16)
    view.faction = UI.Text(block, 13, "CENTER", UI.MUTED)
    view.faction:SetPoint("TOP", view.name, "BOTTOM", 0, -8)
    view.members = UI.Text(block, 13, "CENTER", UI.MUTED)
    view.members:SetPoint("TOP", view.faction, "BOTTOM", 0, -4)
end

local function GuildInfo()
    if not unit then return end
    local _, members, name = C_PaperDollInfo.GetInspectGuildInfo(unit)
    if name and name ~= "" then return name, members end
end

local function RefreshGuild(view)
    local name, members = GuildInfo()
    view.name:SetText(name or "")
    local _, factionName = UnitFactionGroup(unit)
    view.faction:SetText(factionName and INSPECT_GUILD_FACTION and INSPECT_GUILD_FACTION:format(factionName) or "")
    view.members:SetText(members and INSPECT_GUILD_NUM_MEMBERS and INSPECT_GUILD_NUM_MEMBERS:format(members) or "")
    if SetDoubleGuildTabardTextures then SetDoubleGuildTabardTextures(unit, view.left, view.right, view.banner, view.bannerBorder) end
end

-- Window -----------------------------------------------------------------------------------------

local TABS = {
    { key = "gear", tip = function() return Char.G("CHARACTER_FRAME_TAB_CHARACTER", "Character") end, Create = CreateGear, Refresh = RefreshGear },
    { key = "pvp", tip = function() return Char.G("CHARACTER_FRAME_TAB_PVP", "PvP") end, Create = CreatePvP, Refresh = RefreshPvP },
    { key = "guild", tip = function() return GUILD end, Create = CreateGuild, Refresh = RefreshGuild,
      available = function() return GuildInfo() ~= nil end },
}

local function Subtitle()
    local parts = { L["Level %d"]:format(UnitLevel(unit) or 0) }
    local class, classFile = UnitClass(unit)
    local color = classFile and RAID_CLASS_COLORS[classFile]
    if class then parts[#parts + 1] = color and color:WrapTextInColorCode(class) or class end
    local level = C_PaperDollInfo.GetInspectItemLevel and C_PaperDollInfo.GetInspectItemLevel(unit)
    if level and not issecretvalue(level) and level > 0 then parts[#parts + 1] = L["Item level"] .. " " .. math.floor(level) end
    return table.concat(parts, " · ")
end

local function Select(key)
    for _, def in ipairs(TABS) do
        if def.key == key and def.available and not def.available() then key = "gear" end
    end
    current = key
    local y = 60
    for i, def in ipairs(TABS) do
        local button = tabButtons[i]
        local shown = not def.available or def.available()
        button:SetShown(shown)
        if shown then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", window, "TOPRIGHT", 6, -y)
            y = y + TAB_STEP
        end
        local active = def.key == current
        for _, edge in ipairs(button.active) do edge:SetShown(active) end
        button.icon:SetDesaturated(not active)
        button.icon:SetAlpha(active and 1 or 0.75)
    end
    for _, def in ipairs(TABS) do
        local view = views[def.key]
        if def.key == current then
            if not view then
                view = CreateFrame("Frame", nil, window)
                view:SetPoint("TOPLEFT", PAD, -TOP)
                view:SetPoint("BOTTOMRIGHT", -PAD, PAD)
                views[def.key] = view
                def.Create(view)
            end
            view:Show()
            def.Refresh(view)
        elseif view then
            view:Hide()
        end
    end
end

local function UpdateTabIcons()
    SetPortraitTexture(tabButtons[1].icon, unit)
    tabButtons[1].icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tabButtons[2].icon:SetTexture(UnitFactionGroup(unit) == "Horde" and 8197098 or 8197097)
    tabButtons[3].icon:SetTexture("Interface\\Icons\\INV_Shirt_GuildTabard_01")
end

local function Refresh()
    if not (window and unit and UnitExists(unit)) then return end
    window:SetNpc(unit, GetUnitName(unit, true), Subtitle())
    UpdateTabIcons()
    Select(current)
end

local function CreateWindow()
    UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIInspect", WIDTH, ns.NPC_HEIGHT, "inspect")
    window.extraRight = TAB_STEP
    for i, def in ipairs(TABS) do
        local button = CreateFrame("Button", nil, window)
        button:SetSize(TAB_SIZE, TAB_SIZE)
        UI.Box(button, ns.STYLE.panelColor)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.active = ns.AddBorder(button, true, 2)
        for _, edge in ipairs(button.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(def.tip(), 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Select(def.key)
        end)
        tabButtons[i] = button
    end
    window:HookScript("OnShow", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        unit, guid = nil, nil
        if not (PlayerSpellsFrame and PlayerSpellsFrame.IsInspecting and PlayerSpellsFrame:IsInspecting()) then ClearInspectPlayer() end
    end)
end

-- Show immediately (name, portrait, model); gear fills in on INSPECT_READY. Blizzard waits for the
-- data before showing the window, which feels unresponsive.
local function Open(target)
    if not window then CreateWindow() end
    if not target or not CanInspect(target, true) then return end
    window:Hide()
    unit, guid = target, UnitGUID(target)
    current = "gear"
    NotifyInspect(target)
    window:Show()
    Refresh()
end
Char.Inspect = Open
-- Tooltip.lua skips its own inspect requests while we wait or are open
-- (the server answers only one request at a time)
function ns.InspectBusy() return window ~= nil and window:IsShown() end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    -- Replace Blizzard's opener ("Inspect" menu, ctrl click ...) - only this global
    InspectUnit = function(target) Open(target) end
    ns:On("INSPECT_READY", function(_, readyGUID)
        if not unit or readyGUID ~= guid then return end
        if window:IsShown() then Refresh() end
    end)
    ns:On("INSPECT_HONOR_UPDATE", function() if window:IsShown() and current == "pvp" then Refresh() end end)
    ns:On("PLAYER_TARGET_CHANGED", function() if unit == "target" and window:IsShown() then window:Hide() end end)
    ns:On("GROUP_ROSTER_UPDATE", function() if unit and unit ~= "target" and window:IsShown() then window:Hide() end end)
    ns:On("UNIT_INVENTORY_CHANGED", function(_, changed) if changed == unit and window:IsShown() then Refresh() end end)
end)
