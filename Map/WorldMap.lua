-- World map & quest log (WoW Forever): own window instead of Blizzard's WorldMapFrame.
--
--   +- Map  World > Kalimdor v > Teldrassil v                 [Display v] [Pin] [x] +
--   | +--------------- Blizzard's map art --------------+ [Search quest log]  9/40  |
--   | |  with all markers (quests, flight points,      | TELDRASSIL                 |
--   | |  player arrow, zone names, map pin ...)        | | ! [9] Crown of Earth [x] |
--   | | 53.6, 54.2 - Mouse 48.1, 61.0                  | |   Tourmaline Phial 0/1   |
--   | +------------------------------------------------+ ...                        |
--   | Teldrassil - Level 1-11            Ctrl+click: map pin - Right-click: up      |
--
-- The map area is Blizzard's MapCanvas (like the battlefield map): ScrollContainer first, then
-- MapCanvasMixin, forward events. Data providers from Blizzard_SharedMapDataProviders.
-- WorldMapFrame stays untouched (ContentTracking and QuestMapFrame depend on it). Opened via override
-- bindings (M, L), the quest log micro button and Blizzard's global opener functions.
local _, ns = ...
local L = ns.L

-- Height chosen so the map area is exactly 3:2 like Blizzard's map art (850 x 567, no top/bottom gap):
-- width 1240 - 2*18 - 340 - 14 = 850; height 567 + 18 + 44 (header) + 40 (footer) = 669
local WIDTH, HEIGHT, PAD = 1240, 669, 18
local LOG_W = 340
local ROW_GAP = 2

local window, canvas, crumbs, coords, footer, logList, logSearch, logCount, pinButton, options, optionsButton
local rows, headers, collapsedZones = {}, {}, {}
local expandedQuest
local scrollToQuest -- tracker click: list scrolls to this quest once
local listTracked   -- focus came from our own list (no scroll; the click handles expand/collapse)
local pinMode = false
local pendingLog

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.mapWindow ~= false and MapCanvasMixin and WorldMapFrame
end

-- Map canvas ---------------------------------------------------------------------------------------

local function AddProviders(map)
    local function Add(mixin, setup)
        if not mixin then return end
        local provider = CreateFromMixins(mixin)
        if setup then setup(provider) end
        map:AddDataProvider(provider)
        return provider
    end
    Add(MapExplorationDataProviderMixin)
    Add(MapHighlightDataProviderMixin)
    Add(FogOfWarDataProviderMixin)
    Add(QuestBlobDataProviderMixin)
    Add(QuestOfferDataProviderMixin)
    Add(VignetteDataProviderMixin)
    Add(QuestDataProviderMixin)
    Add(GossipDataProviderMixin)
    Add(FlightPointDataProviderMixin)
    Add(PetTamerDataProviderMixin)
    Add(DigSiteDataProviderMixin)
    Add(DungeonEntranceDataProviderMixin)
    Add(MapLinkDataProviderMixin)
    Add(SelectableGraveyardDataProviderMixin)
    Add(AreaPOIDataProviderMixin)
    Add(AreaPOIEventDataProviderMixin)
    Add(DeathMapDataProviderMixin)
    Add(VehicleDataProviderMixin)
    Add(BattlefieldFlagDataProviderMixin)
    Add(WaypointLocationDataProviderMixin)
    Add(SuperTrackWaypointDataProviderMixin)
    map.areaLabelProvider = Add(AreaLabelDataProviderMixin, function(p) p:SetOffsetY(-10) end) -- offset must be set before adding
    Add(GroupMembersDataProviderMixin)

    -- layer order as in Blizzard's world map (Blizzard_WorldMap.lua)
    local levels = map:GetPinFrameLevelsManager()
    for _, entry in ipairs({
        "PIN_FRAME_LEVEL_MAP_EXPLORATION", "PIN_FRAME_LEVEL_EVENT_OVERLAY", "PIN_FRAME_LEVEL_FOG_OF_WAR",
        "PIN_FRAME_LEVEL_QUEST_BLOB", "PIN_FRAME_LEVEL_SCENARIO_BLOB", "PIN_FRAME_LEVEL_MAP_HIGHLIGHT",
        "PIN_FRAME_LEVEL_DIG_SITE", "PIN_FRAME_LEVEL_DUNGEON_ENTRANCE", "PIN_FRAME_LEVEL_FLIGHT_POINT",
        "PIN_FRAME_LEVEL_INVASION", "PIN_FRAME_LEVEL_PET_TAMER", "PIN_FRAME_LEVEL_SELECTABLE_GRAVEYARD",
        "PIN_FRAME_LEVEL_AREA_POI", "PIN_FRAME_LEVEL_GOSSIP", "PIN_FRAME_LEVEL_MAP_LINK",
        { "PIN_FRAME_LEVEL_VIGNETTE", 200 },
        { "PIN_FRAME_LEVEL_QUEST_OFFER", QuestOfferDataProviderMixin and QuestOfferDataProviderMixin.PIN_LEVEL_RANGE },
        "PIN_FRAME_LEVEL_SCENARIO", "PIN_FRAME_LEVEL_AREA_POI_EVENT", "PIN_FRAME_LEVEL_QUEST_PING",
        "PIN_FRAME_LEVEL_TRACKED_CONTENT", { "PIN_FRAME_LEVEL_ACTIVE_QUEST", C_QuestLog.GetMaxNumQuests() },
        "PIN_FRAME_LEVEL_SUPER_TRACKED_CONTENT", "PIN_FRAME_LEVEL_SUPER_TRACKED_QUEST",
        "PIN_FRAME_LEVEL_VEHICLE_BELOW_GROUP_MEMBER", "PIN_FRAME_LEVEL_BATTLEFIELD_FLAG",
        "PIN_FRAME_LEVEL_WAYPOINT_LOCATION", "PIN_FRAME_LEVEL_GROUP_MEMBER",
        "PIN_FRAME_LEVEL_VEHICLE_ABOVE_GROUP_MEMBER", "PIN_FRAME_LEVEL_CORPSE" }) do
        if type(entry) == "table" then levels:AddFrameLevel(entry[1], entry[2]) else levels:AddFrameLevel(entry) end
    end
end

local OnMapChanged -- defined below (breadcrumbs, footer, quest log)

local function CreateCanvas(parent)
    local map = CreateFrame("Frame", "MeredanUIMapCanvas", parent)
    map:SetAllPoints(parent)
    -- ScrollContainer must exist before MapCanvasMixin.OnLoad (its GetCanvas needs it)
    map.ScrollContainer = CreateFrame("ScrollFrame", nil, map, "MapCanvasFrameScrollContainerTemplate")
    map.ScrollContainer:ClearAllPoints()
    map.ScrollContainer:SetAllPoints(map)
    -- BorderFrame: Blizzard's lock layer above the map (EvaluateLockReasons accesses it)
    map.BorderFrame = CreateFrame("Frame", nil, map)
    map.BorderFrame:SetAllPoints(map)
    map.BorderFrame:SetFrameLevel(map:GetFrameLevel() + 1500)
    map.BorderFrame:EnableMouse(false)
    Mixin(map, MapCanvasMixin)
    MapCanvasMixin.OnLoad(map)
    -- AcquirePin calls pin:SetPassThroughButtons, which is blocked for addon code in combat (map opened
    -- in a fight -> ADDON_ACTION_BLOCKED). Patch every pin our canvas creates: skip it in combat (only
    -- costs right-click passthrough on pins acquired mid-fight). Pools are hooked on creation, before
    -- the first Acquire.
    setmetatable(map.pinPools, { __newindex = function(pools, template, pool)
        local acquire = pool.Acquire
        pool.Acquire = function(p, ...)
            local pin, isNew = acquire(p, ...)
            if isNew then
                local check = pin.CheckMouseButtonPassthrough
                pin.CheckMouseButtonPassthrough = function(self, ...)
                    if InCombatLockdown() then return end
                    return check(self, ...)
                end
            end
            return pin, isNew
        end
        rawset(pools, template, pool)
    end })
    -- only accept maps with art (quests in instances etc. yield maps without layers, which breaks
    -- Blizzard's zoom levels)
    local setMapID = map.SetMapID
    function map:SetMapID(mapID)
        local layers = mapID and mapID > 0 and C_Map.GetMapArtLayers(mapID)
        if not (layers and #layers > 0) then return end
        setMapID(self, mapID)
    end
    map:SetShouldNavigateOnClick(true)
    map:SetShouldZoomInOnClick(false)
    map:SetShouldPanOnClick(false)
    map:SetGlobalPinScale(1)
    -- right-click: one level up, but not beyond World (Forever ends there)
    function map:NavigateToParentMap()
        local info = C_Map.GetMapInfo(self:GetMapID())
        if info and info.mapType and info.mapType > Enum.UIMapType.World and (info.parentMapID or 0) > 0 then
            self:SetMapID(info.parentMapID)
        end
    end
    function map:OnMapChanged()
        MapCanvasMixin.OnMapChanged(self)
        if ns.DungeonMapView then ns.DungeonMapView.Hide() end
        C_QuestLog.SetMapForQuestPOIs(self:GetMapID())
        if self.RefreshReveal then self:RefreshReveal() end
        if OnMapChanged then OnMapChanged() end
    end
    map:SetScript("OnEvent", function(self, event, ...) MapCanvasMixin.OnEvent(self, event, ...) end)
    map:SetScript("OnUpdate", function(self, elapsed) MapCanvasMixin.OnUpdate(self, elapsed) end)
    map:SetScript("OnShow", function(self)
        local wanted = self.wantedMap
        self.wantedMap = nil
        if wanted then self:SetMapID(wanted) end
        if not wanted or self:GetMapID() ~= wanted then self:SetMapID(MapUtil.GetDisplayableMapForPlayer()) end
        MapCanvasMixin.OnShow(self)
    end)
    map:SetScript("OnHide", function(self) MapCanvasMixin.OnHide(self) end)
    AddProviders(map)
    -- reveal whole map, levels on zone names (Map/MapExtras.lua)
    if ns.AttachMapExtras then ns.AttachMapExtras(map, map.areaLabelProvider) end
    return map
end

-- Breadcrumbs --------------------------------------------------------------------------------------

local function Crumbs()
    local UI = ns.UI
    for _, b in ipairs(crumbs.buttons) do b:Hide() end
    for _, s in pairs(crumbs.seps) do s:Hide() end
    local chain = {}
    local mapID = canvas:GetMapID()
    local info = mapID and C_Map.GetMapInfo(mapID)
    while info do
        if info.name and info.name ~= "" then table.insert(chain, 1, info) end
        if info.mapType <= Enum.UIMapType.World or (info.parentMapID or 0) == 0 then break end
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    local prev
    for i, entry in ipairs(chain) do
        local button = crumbs.buttons[i]
        if not button then
            button = CreateFrame("Button", nil, crumbs)
            button:SetHeight(22)
            button.text = UI.Text(button, 13, "LEFT")
            button.text:SetPoint("LEFT")
            button.chevron = UI.Icon(button, "ChevronDown", 10, UI.MUTED)
            button.chevron:SetPoint("LEFT", button.text, "RIGHT", 4, 0)
            button:SetScript("OnClick", function(self)
                if self.isLast and self.siblings and #self.siblings > 1 then
                    UI.OpenList(self, self.siblings, canvas:GetMapID(), function(value) canvas:SetMapID(value) end)
                elseif not self.isLast then
                    canvas:SetMapID(self.mapID)
                elseif self.siblings then
                    UI.OpenList(self, self.siblings, canvas:GetMapID(), function(value) canvas:SetMapID(value) end)
                end
            end)
            button:SetScript("OnEnter", function(self) self.text:SetTextColor(unpack(UI.TEXT)) end)
            button:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(self.isLast and UI.ACCENT or UI.MUTED)) end)
            crumbs.buttons[i] = button
        end
        button.mapID, button.isLast = entry.mapID, i == #chain
        button.text:SetText(entry.name)
        button.text:SetTextColor(unpack(button.isLast and UI.ACCENT or UI.MUTED))
        -- dropdown of neighboring zones (and floors) on the last crumb
        button.siblings = nil
        if button.isLast then
            local list = {}
            local groupID = C_Map.GetMapGroupID(entry.mapID)
            if groupID then
                for _, member in ipairs(C_Map.GetMapGroupMembersInfo(groupID) or {}) do
                    list[#list + 1] = { value = member.mapID, label = member.name }
                end
            elseif (entry.parentMapID or 0) > 0 then
                for _, child in ipairs(C_Map.GetMapChildrenInfo(entry.parentMapID) or {}) do
                    if C_Map.IsMapValidForNavBarDropdown(child.mapID) then list[#list + 1] = { value = child.mapID, label = child.name } end
                end
                table.sort(list, function(a, b) return a.label < b.label end)
            end
            button.siblings = #list > 1 and list or nil
        end
        button.chevron:SetShown(button.isLast and button.siblings ~= nil)
        button:SetWidth(button.text:GetUnboundedStringWidth() + (button.chevron:IsShown() and 16 or 0))
        button:ClearAllPoints()
        if prev then
            local sep = crumbs.seps[i]
            if not sep then
                -- slim arrow instead of ">"
                sep = UI.Icon(crumbs, "ChevronDown", 9, { 0.42, 0.42, 0.42 })
                sep:SetRotation(math.pi / 2)
                crumbs.seps[i] = sep
            end
            sep:ClearAllPoints()
            sep:SetPoint("LEFT", prev, "RIGHT", 10, 0)
            sep:Show()
            button:SetPoint("LEFT", sep, "RIGHT", 10, 0)
        else
            button:SetPoint("LEFT", 0, 0)
        end
        button:Show()
        prev = button
    end
end

-- Quest log ---------------------------------------------------------------------------------------

local function Header(i)
    if headers[i] then return headers[i] end
    local UI = ns.UI
    local header = CreateFrame("Button", nil, logList.child)
    header:SetHeight(28)
    UI.Box(header, { 0.098, 0.098, 0.106, 1 })
    header.text = UI.Text(header, 13, "LEFT", UI.ACCENT)
    header.text:SetPoint("LEFT", 8, 0)
    header.sign = UI.Text(header, 14, "RIGHT", UI.MUTED)
    header.sign:SetPoint("RIGHT", -8, 0)
    header:SetScript("OnClick", function(self)
        collapsedZones[self.key] = not collapsedZones[self.key] or nil
        window.RefreshLog()
    end)
    headers[i] = header
    return header
end

local function QuestMenu(row)
    local UI = ns.UI
    local questID, title = row.questID, row.questTitle
    local items = {}
    local watched = C_QuestLog.GetQuestWatchType(questID) ~= nil
    items[#items + 1] = { value = "track", label = watched and L["Stop tracking"] or L["Track"] }
    if C_QuestLog.IsPushableQuest(questID) and IsInGroup() then items[#items + 1] = { value = "share", label = L["Share"] } end
    if C_QuestLog.CanAbandonQuest(questID) then items[#items + 1] = { value = "abandon", label = "|cffff6060" .. L["Abandon"] .. "|r" } end
    UI.OpenList(row, items, nil, function(value)
        if value == "track" then
            if watched then C_QuestLog.RemoveQuestWatch(questID) else C_QuestLog.AddQuestWatch(questID) end
        elseif value == "share" then
            QuestLogPushQuest(C_QuestLog.GetLogIndexForQuestID(questID))
        elseif value == "abandon" then
            C_QuestLog.SetSelectedQuest(questID)
            C_QuestLog.SetAbandonQuest()
            StaticPopup_Show("ABANDON_QUEST", title)
        end
    end)
end

-- Rewards of the expanded quest (like our quest frame: cards in two columns) ------------------------
local REWARD_H, REWARD_GAP = 46, 6
local rewardBox, rewardCards, rewardHeaders = nil, {}, {}

local function QualityColor(quality)
    if quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

local function RewardCard(i)
    if rewardCards[i] then return rewardCards[i] end
    local UI = ns.UI
    local card = CreateFrame("Button", nil, rewardBox)
    card:SetHeight(REWARD_H)
    card.bg = UI.Box(card, { 1, 1, 1, 0.04 })
    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(34, 34)
    holder:SetPoint("LEFT", 6, 0)
    ns.AddSlotBackground(holder)
    card.border = ns.AddBorder(holder)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = ns.CreateText(holder, 11, "RIGHT", "OUTLINE")
    card.count:SetPoint("BOTTOMRIGHT", -2, 2)
    card.name = UI.Text(card, 12, "LEFT")
    card.name:SetPoint("LEFT", holder, "RIGHT", 8, 0)
    card.name:SetPoint("RIGHT", -6, 0)
    card.name:SetWordWrap(true)
    card.name:SetMaxLines(2)
    card:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0.08)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetQuestLogItem(self.kind, self.index, self.questID)
        ns.ShowItemCompare(GameTooltip)
        GameTooltip:Show()
        self.UpdateTooltip = self:GetScript("OnEnter") -- refresh while Shift is pressed over the card
    end)
    card:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(1, 1, 1, 0.04)
        GameTooltip:Hide()
    end)
    card:SetScript("OnClick", function(self)
        local link = GetQuestLogItemLink(self.kind, self.index, self.questID)
        if link then HandleModifiedItemClick(link) end
    end)
    rewardCards[i] = card
    return card
end

-- fills rewards below `anchor` in `row`, returns the height (0 = none)
local function FillRewards(row, anchor, questID, width)
    local UI = ns.UI
    if not rewardBox then
        rewardBox = CreateFrame("Frame", nil, row)
        rewardBox.extra = UI.Text(rewardBox, 12, "LEFT")
    end
    rewardBox:SetParent(row)
    rewardBox:ClearAllPoints()
    rewardBox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    rewardBox:SetWidth(width)
    local groups = {}
    local function Items(kind, num, getter)
        local list = {}
        for i = 1, num do
            local name, texture, count, quality, isUsable = getter(i, questID)
            if name then list[#list + 1] = { kind = kind, index = i, name = name, texture = texture, count = count, quality = quality, usable = isUsable } end
        end
        return list
    end
    local choices = Items("choice", GetNumQuestLogChoices(questID) or 0, GetQuestLogChoiceInfo)
    if #choices > 0 then groups[#groups + 1] = { title = #choices > 1 and L["Choose a reward"] or L["You receive"], items = choices } end
    local rewards = Items("reward", GetNumQuestLogRewards(questID) or 0, GetQuestLogRewardInfo)
    if #rewards > 0 then groups[#groups + 1] = { title = #choices > 0 and L["You also receive"] or L["You receive"], items = rewards } end

    local y, n = 0, 0
    local cardW = (width - REWARD_GAP) / 2
    for gi, group in ipairs(groups) do
        local header = rewardHeaders[gi]
        if not header then
            header = UI.Text(rewardBox, 12, "LEFT", UI.ACCENT)
            rewardHeaders[gi] = header
        end
        header:SetText(group.title)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -y)
        header:Show()
        y = y + header:GetStringHeight() + 6
        for i, item in ipairs(group.items) do
            n = n + 1
            local card = RewardCard(n)
            card.kind, card.index, card.questID = item.kind, item.index, questID
            card.icon:SetTexture(item.texture)
            card.icon:SetVertexColor(1, item.usable == false and 0.25 or 1, item.usable == false and 0.25 or 1)
            card.count:SetText(item.count and item.count > 1 and item.count or "")
            local r, g, b = QualityColor(item.quality)
            card.name:SetText(item.name)
            card.name:SetTextColor(r, g, b)
            local edge = (item.quality and item.quality >= Enum.ItemQuality.Uncommon) and { r, g, b } or { 0, 0, 0 }
            for _, e in ipairs(card.border) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
            card:SetWidth(cardW)
            card:ClearAllPoints()
            local col, line = (i - 1) % 2, math.floor((i - 1) / 2)
            card:SetPoint("TOPLEFT", col * (cardW + REWARD_GAP), -(y + line * (REWARD_H + REWARD_GAP)))
            card:Show()
        end
        local lines = math.ceil(#group.items / 2)
        y = y + lines * REWARD_H + math.max(lines - 1, 0) * REWARD_GAP + 10
    end
    for i = #groups + 1, #rewardHeaders do rewardHeaders[i]:Hide() end
    for i = n + 1, #rewardCards do rewardCards[i]:Hide() end

    -- XP and money
    local extras = {}
    local xp = GetQuestLogRewardXP(questID)
    if xp and xp > 0 then extras[#extras + 1] = L["%d XP"]:format(xp) end
    local money = GetQuestLogRewardMoney(questID)
    if money and money > 0 then extras[#extras + 1] = GetMoneyString(money, true) end
    if #extras > 0 then
        rewardBox.extra:SetText("|cff8ecbb4" .. (#groups > 0 and L["Also"] or L["You receive"]) .. "|r   " .. table.concat(extras, "    "))
        rewardBox.extra:ClearAllPoints()
        rewardBox.extra:SetPoint("TOPLEFT", 0, -y)
        rewardBox.extra:Show()
        y = y + rewardBox.extra:GetStringHeight() + 4
    else
        rewardBox.extra:Hide()
    end
    if y == 0 then rewardBox:Hide() return 0 end
    rewardBox:SetHeight(y)
    rewardBox:Show()
    return 12 + y
end

-- Buttons of the expanded quest: share, abandon (icons like Blizzard, text in tooltip)
local questActions

local function ActionButton(parent, icon, color, label, onClick)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(22, 22)
    local bg = UI.Box(button)
    button.icon = UI.Icon(button, icon, 14, color)
    button.icon:SetPoint("CENTER")
    button.color = color
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        bg:SetColorTexture(unpack(UI.HOVER))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, self.color[1], self.color[2], self.color[3])
        if not self:IsEnabled() and self.why then GameTooltip:AddLine(self.why, 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        bg:SetColorTexture(unpack(UI.FIELD))
        GameTooltip:Hide()
    end)
    return button
end

local function SetActionEnabled(button, on, why)
    button:SetEnabled(on)
    button.why = why
    if on then button.icon:SetVertexColor(unpack(button.color)) else button.icon:SetVertexColor(0.35, 0.35, 0.35) end
end

-- places the buttons below `anchor` in `row`, returns the height
local function FillActions(row, anchor, questID)
    if not questActions then
        questActions = CreateFrame("Frame", nil, row)
        questActions:SetSize(50, 22)
        questActions.abandon = ActionButton(questActions, "Close", { 0.9, 0.25, 0.25 }, ABANDON_QUEST_ABBREV or L["Abandon"], function()
            local id = questActions.questID
            C_QuestLog.SetSelectedQuest(id)
            C_QuestLog.SetAbandonQuest()
            StaticPopup_Show("ABANDON_QUEST", C_QuestLog.GetTitleForQuestID(id) or "")
        end)
        questActions.abandon:SetPoint("RIGHT")
        questActions.share = ActionButton(questActions, "Friends", ns.UI.TEXT, SHARE_QUEST_ABBREV or L["Share"], function()
            QuestLogPushQuest(C_QuestLog.GetLogIndexForQuestID(questActions.questID))
        end)
        questActions.share:SetPoint("RIGHT", questActions.abandon, "LEFT", -6, 0)
    end
    questActions.questID = questID
    questActions:SetParent(row)
    questActions:ClearAllPoints()
    questActions:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -10)
    SetActionEnabled(questActions.abandon, C_QuestLog.CanAbandonQuest(questID), nil)
    local pushable = C_QuestLog.IsPushableQuest(questID)
    SetActionEnabled(questActions.share, pushable and IsInGroup(),
        not pushable and L["This quest can't be shared."] or L["You're not in a group."])
    questActions:Show()
    return 10 + 22
end

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, logList.child)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    -- ready to turn in: subtle green background
    row.ready = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.ready:SetAllPoints()
    row.ready:SetColorTexture(0.56, 0.8, 0.71, 0.07)
    row.ready:Hide()
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.04)
    row.hover:Hide()
    row.sign = UI.Text(row, 15, "CENTER")
    row.sign:SetPoint("TOPLEFT", 6, -6)
    row.sign:SetWidth(18)
    row.title = UI.Text(row, 13, "LEFT")
    row.title:SetPoint("TOPLEFT", 30, -7)
    row.title:SetPoint("RIGHT", -28, 0)
    row.title:SetWordWrap(false)
    row.goals = UI.Text(row, 12, "LEFT", UI.MUTED)
    row.goals:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.goals:SetPoint("RIGHT", -28, 0)
    row.goals:SetWordWrap(true)
    row.goals:SetSpacing(3)
    row.desc = UI.Text(row, 12, "LEFT", { 0.79, 0.78, 0.75 })
    row.desc:SetPoint("TOPLEFT", row.goals, "BOTTOMLEFT", 0, -6)
    row.desc:SetPoint("RIGHT", -28, 0)
    row.desc:SetWordWrap(true)
    row.desc:SetSpacing(2)
    -- track checkbox
    row.track = CreateFrame("Button", nil, row)
    row.track:SetSize(14, 14)
    row.track:SetPoint("TOPRIGHT", -6, -8)
    UI.CheckBg(row.track)
    row.tick = UI.Icon(row.track, "Check", 10, UI.ACCENT)
    row.tick:SetPoint("CENTER")
    row.track:SetScript("OnClick", function()
        if C_QuestLog.GetQuestWatchType(row.questID) then C_QuestLog.RemoveQuestWatch(row.questID) else C_QuestLog.AddQuestWatch(row.questID) end
    end)
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:SetShown(self.questID == expandedQuest) end) -- expanded quest keeps its gray highlight
    row:SetScript("OnClick", function(self, button)
        if IsModifiedClick("CHATLINK") then
            local link = GetQuestLink(self.questID)
            if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
            return
        end
        if button == "RightButton" then return QuestMenu(self) end
        -- click: map to the quest, set focus, expand/collapse text
        expandedQuest = expandedQuest ~= self.questID and self.questID or nil
        listTracked = self.questID
        C_SuperTrack.SetSuperTrackedQuestID(self.questID)
        local mapID = GetQuestUiMapID and GetQuestUiMapID(self.questID)
        if mapID and mapID > 0 then canvas:SetMapID(mapID) end
        EventRegistry:TriggerEvent("MapCanvas.PingQuestID", self.questID)
        window.RefreshLog()
    end)
    rows[i] = row
    return row
end

-- Filter (icon next to the search; text only in the menu) ------------------------------------------
local QUEST_FILTERS = {
    { key = "thisMap", label = "Only this map" },
    { key = "hideGray", label = "Hide gray quests" },
    { key = "readyFirst", label = "Ready to turn in first" },
    { key = "trackedOnly", label = "Only tracked" },
    { key = "hideGroup", label = "Hide group and dungeon quests" },
}
local filterButton, filterMenu
local trackAll, visibleQuests = nil, {}

local function Filters()
    ns.db.mapQuestFilters = ns.db.mapQuestFilters or {}
    return ns.db.mapQuestFilters
end

local function AnyFilter()
    for _, entry in ipairs(QUEST_FILTERS) do
        if Filters()[entry.key] then return true end
    end
    return false
end

-- is the quest on the shown map (or one of its child maps)?
local function OnShownMap(questID, zoneName)
    local shown = canvas:GetMapID()
    local mapID = GetQuestUiMapID and GetQuestUiMapID(questID)
    if mapID and mapID > 0 then
        for _ = 1, 10 do
            if mapID == shown then return true end
            local info = C_Map.GetMapInfo(mapID)
            mapID = info and info.parentMapID
            if not mapID or mapID == 0 then break end
        end
        return false
    end
    -- no map point: compare the zone header with the map name
    local info = C_Map.GetMapInfo(shown)
    return info ~= nil and info.name == zoneName
end

local function PassesFilters(info, zoneName, complete)
    local f = Filters()
    if f.trackedOnly and C_QuestLog.GetQuestWatchType(info.questID) == nil then return false end
    if f.hideGray and not complete then
        local difficulty = C_PlayerInfo.GetContentDifficultyQuestForPlayer and C_PlayerInfo.GetContentDifficultyQuestForPlayer(info.questID)
        if Enum.RelativeContentDifficulty and difficulty == Enum.RelativeContentDifficulty.Trivial then return false end
    end
    if f.hideGroup and ns.IsGroupQuest(info) then return false end
    if f.thisMap and not OnShownMap(info.questID, zoneName) then return false end
    return true
end

local function LayoutLog()
    if not (window and window:IsShown()) then return end
    local query = strtrim(logSearch:GetText() or ""):lower()
    local width = logList:GetWidth()
    local y, r, h = 0, 0, 0
    local zone, zoneKey
    local numQuests = 0
    local superTracked = C_SuperTrack.GetSuperTrackedQuestID()
    local anyExpanded = false
    local targetY
    -- collect zones with their (filtered) quests
    local zones, current = {}, nil
    local readyFirst = Filters().readyFirst
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and info.isHeader then
            current = { info = info, quests = {} }
            zones[#zones + 1] = current
        elseif info and not info.isHidden and not info.isTask and info.questID and info.questID > 0 then
            numQuests = numQuests + 1
            if not current then
                current = { info = { title = "", isHeader = true }, quests = {} }
                zones[#zones + 1] = current
            end
            -- searched quest: expand its zone so it is visible
            if info.questID == scrollToQuest then collapsedZones[current.info.title] = nil end
            local complete = C_QuestLog.IsComplete(info.questID) or C_QuestLog.ReadyForTurnIn(info.questID)
            local matches = query == "" or (info.title or ""):lower():find(query, 1, true)
            if matches and PassesFilters(info, current.info.title, complete) then
                current.quests[#current.quests + 1] = { info = info, complete = complete, order = #current.quests }
            end
        end
    end
    local entries = {}
    wipe(visibleQuests)
    for _, z in ipairs(zones) do
        for _, q in ipairs(z.quests) do visibleQuests[#visibleQuests + 1] = q.info.questID end
        if #z.quests > 0 then
            if readyFirst then
                table.sort(z.quests, function(a, b)
                    if a.complete ~= b.complete then return a.complete end
                    return a.order < b.order
                end)
            end
            entries[#entries + 1] = z.info
            for _, q in ipairs(z.quests) do entries[#entries + 1] = q.info end
        end
    end

    for _, info in ipairs(entries) do
        if info.isHeader then
            zone, zoneKey = info.title, info.title
            if query == "" and zone ~= "" then
                h = h + 1
                local header = Header(h)
                header.key = zoneKey
                header.text:SetText(zone)
                header.sign:SetText(collapsedZones[zoneKey] and "+" or "−")
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", 0, -y - (y > 0 and 6 or 0))
                header:SetWidth(width)
                header:Show()
                y = y + 28 + (y > 0 and 6 or 0) + ROW_GAP
            end
        else
            if query ~= "" or not collapsedZones[zoneKey] then
                r = r + 1
                local row = Row(r)
                row.questID, row.questTitle = info.questID, info.title
                local complete = C_QuestLog.IsComplete(info.questID) or C_QuestLog.ReadyForTurnIn(info.questID)
                local color = ns.QuestColor(info.questID)
                row.strip:SetColorTexture(color.r, color.g, color.b, 1)
                row.sign:SetText(complete and "?" or "!")
                row.ready:SetShown(complete)
                row.sign:SetTextColor(unpack(complete and { 1, 0.82, 0 } or { 0.55, 0.55, 0.55 }))
                local prefix = QuestUtilsOverrides and QuestUtilsOverrides.GetQuestTitlePrefix and QuestUtilsOverrides.GetQuestTitlePrefix(info)
                    or ("[" .. (info.level or 0) .. "] ")
                row.title:SetText("|cff99978f" .. prefix .. "|r" .. (info.title or ""))
                row.title:SetTextColor(color.r, color.g, color.b)
                if info.questID == superTracked then row.title:SetTextColor(1, 1, 1) end
                -- objectives
                local lines = {}
                for _, obj in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                    if obj.text and obj.text ~= "" then
                        lines[#lines + 1] = (obj.finished and "|cff8ecbb4" or "") .. obj.text .. (obj.finished and "|r" or "")
                    end
                end
                if #lines == 0 and complete then lines[1] = "|cff8ecbb4" .. (QUEST_WATCH_QUEST_READY or L["Ready to turn in"]) .. "|r" end
                row.goals:SetWidth(width - 58)
                row.goals:SetText(table.concat(lines, "\n"))
                -- expanded: quest text
                local expanded = expandedQuest == info.questID
                row.desc:SetShown(expanded)
                row.hover:SetShown(expanded or row:IsMouseOver())
                local rewardsH = 0
                if expanded then
                    C_QuestLog.SetSelectedQuest(info.questID)
                    local text = GetQuestLogQuestText()
                    row.desc:SetWidth(width - 58)
                    row.desc:SetText(text or "")
                    rewardsH = FillRewards(row, row.desc, info.questID, width - 58)
                    rewardsH = rewardsH + FillActions(row, rewardsH > 0 and rewardBox or row.desc, info.questID)
                    anyExpanded = true
                end
                row.tick:SetShown(C_QuestLog.GetQuestWatchType(info.questID) ~= nil)
                local height = 7 + row.title:GetStringHeight() + 4 + (#lines > 0 and row.goals:GetStringHeight() or 0)
                    + (expanded and (6 + row.desc:GetStringHeight() + rewardsH) or 0) + 8
                row:SetHeight(height)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetWidth(width)
                row:Show()
                if info.questID == scrollToQuest then targetY = y end
                y = y + height + ROW_GAP
            end
        end
    end
    if rewardBox and not anyExpanded then rewardBox:Hide() end
    if questActions and not anyExpanded then questActions:Hide() end
    for i = r + 1, #rows do rows[i]:Hide() end
    for i = h + 1, #headers do headers[i]:Hide() end
    logList:SetContentHeight(y)
    if targetY then logList:ScrollTo(targetY - 6) end
    scrollToQuest = nil
    if trackAll then trackAll.Update() end
    logCount:SetText("|cffe8e6de" .. numQuests .. "|r/" .. C_QuestLog.GetMaxNumQuestsCanAccept()) -- numbers only, text in tooltip
end

local function RefreshLog()
    if pendingLog then return end
    pendingLog = true
    C_Timer.After(0, function()
        pendingLog = nil
        LayoutLog()
    end)
end

-- Header, footer, coordinates ---------------------------------------------------------------------

OnMapChanged = function()
    if not (window and window:IsShown()) then return end
    Crumbs()
    if ns.DungeonPanel then ns.DungeonPanel.Refresh() end
    local dungeon = ns.DungeonMapView and ns.DungeonMapView.CurrentName()
    if dungeon then
        footer:SetText(dungeon)
        return
    end
    if Filters().thisMap then RefreshLog() end
    local mapID = canvas:GetMapID()
    local info = C_Map.GetMapInfo(mapID)
    local text = info and info.name or ""
    local low, high
    if ns.ZoneLevels then low, high = ns.ZoneLevels(mapID) end -- Forever: own table (Map/MapExtras.lua)
    if low and high and high > 0 then
        text = text .. "  ·  " .. (low == high and L["Level %d"]:format(low) or L["Level %d–%d"]:format(low, high))
    end
    footer:SetText(text)
end

local function UpdateCoords()
    local mapID = canvas:GetMapID()
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local text = ""
    if position then
        local x, y = position:GetXY()
        if x and not issecretvalue(x) and (x > 0 or y > 0) then text = ("%.1f, %.1f"):format(x * 100, y * 100) end
    end
    if canvas:IsCanvasMouseFocus() then
        local mx, my = canvas:GetNormalizedCursorPosition()
        if mx and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then
            text = text .. (text ~= "" and "  " or "") .. "|cff99978f" .. L["Mouse"] .. " " .. ("%.1f, %.1f"):format(mx * 100, my * 100) .. "|r"
        end
    end
    coords.text:SetText(text)
    coords:SetShown(text ~= "")
    coords:SetWidth(coords.text:GetUnboundedStringWidth() + 20)
end

local function SetPinMode(on)
    pinMode = on
    canvas:TriggerEvent("WaypointLocationToggleUpdate", on)
    for _, e in ipairs(pinButton.active) do e:SetShown(on) end
end

local CVAR_OPTIONS = {
    -- short labels (long ones overflowed)
    { cvar = "questPOI", label = "Quest objectives" },
    { cvar = "showDungeonEntrancesOnMap", label = "Dungeon entrances" },
    { db = "mapReveal", label = "Whole map" },          -- Map/MapExtras.lua: reveal whole map
    { db = "mapZoneLevels", label = "Level and faction" }, -- Map/MapExtras.lua: on zone names
}

local function CreateOptions()
    local UI = ns.UI
    options = CreateFrame("Frame", nil, window)
    options:SetSize(240, #CVAR_OPTIONS * 28 + 12)
    options:SetPoint("TOPRIGHT", optionsButton, "BOTTOMRIGHT", 0, -4)
    options:SetFrameStrata("DIALOG")
    UI.Box(options, { 0.078, 0.078, 0.086, 1 })
    options:Hide()
    local widest = 0
    for i, entry in ipairs(CVAR_OPTIONS) do
        local row = CreateFrame("Button", nil, options)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", 0, -6 - (i - 1) * 28)
        row:SetPoint("RIGHT", options, "RIGHT")
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.06)
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 12, 0)
        UI.CheckBg(box)
        local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
        tick:SetPoint("CENTER")
        local text = UI.Text(row, 13, "LEFT")
        text:SetPoint("LEFT", box, "RIGHT", 10, 0)
        text:SetText(L[entry.label])
        widest = math.max(widest, text:GetUnboundedStringWidth())
        local function IsOn()
            if entry.db then return ns.db[entry.db] ~= false end
            return GetCVarBool(entry.cvar)
        end
        row.Update = function() tick:SetShown(IsOn()) end
        row:SetScript("OnClick", function()
            if entry.db then
                ns.db[entry.db] = not IsOn()
                if canvas.RefreshReveal then canvas:RefreshReveal() end
            else
                SetCVar(entry.cvar, GetCVarBool(entry.cvar) and "0" or "1")
            end
            row.Update()
            canvas:RefreshAllDataProviders()
        end)
        options[i] = row
    end
    options:SetWidth(math.max(160, math.ceil(widest) + 60)) -- never narrower than the text
    options:RegisterEvent("GLOBAL_MOUSE_DOWN")
    options:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not optionsButton:IsMouseOver() then self:Hide() end
    end)
end

local function UpdateFilterButton()
    local on = AnyFilter()
    filterButton.icon:SetVertexColor(unpack(on and ns.UI.ACCENT or ns.UI.TEXT))
end

local function CreateFilterMenu()
    local UI = ns.UI
    filterMenu = CreateFrame("Frame", nil, window)
    filterMenu:SetPoint("TOPRIGHT", filterButton, "BOTTOMRIGHT", 0, -4)
    filterMenu:SetFrameStrata("DIALOG")
    UI.Box(filterMenu, { 0.078, 0.078, 0.086, 1 })
    filterMenu:Hide()
    local widest = 0
    for i, entry in ipairs(QUEST_FILTERS) do
        local row = CreateFrame("Button", nil, filterMenu)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", 0, -6 - (i - 1) * 28)
        row:SetPoint("RIGHT", filterMenu, "RIGHT")
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.06)
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 12, 0)
        UI.CheckBg(box)
        local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
        tick:SetPoint("CENTER")
        local text = UI.Text(row, 13, "LEFT")
        text:SetPoint("LEFT", box, "RIGHT", 10, 0)
        text:SetText(L[entry.label])
        widest = math.max(widest, text:GetUnboundedStringWidth())
        row.Update = function() tick:SetShown(Filters()[entry.key] == true) end
        row:SetScript("OnClick", function()
            Filters()[entry.key] = not Filters()[entry.key] or nil
            row.Update()
            UpdateFilterButton()
            RefreshLog()
        end)
        filterMenu[i] = row
    end
    filterMenu:SetSize(math.ceil(widest) + 60, #QUEST_FILTERS * 28 + 12)
    filterMenu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    filterMenu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not filterButton:IsMouseOver() then self:Hide() end
    end)
end

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIWorldMap", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:SetPoint("CENTER", 0, 30)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor, true)
    ns.RuneFrame(window)
    tinsert(UISpecialFrames, "MeredanUIWorldMap")
    window.RefreshLog = RefreshLog
    ns.layoutFrames.worldmap = window

    -- header (drag handle)
    local head = CreateFrame("Frame", nil, window)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(PAD + 30)
    ns.MakeWindowDraggable(window, head)
    local titleText = UI.Text(head, 16, "LEFT")
    titleText:SetPoint("TOPLEFT", PAD, -PAD - 4)
    titleText:SetText(WORLD_MAP or L["Map"])
    crumbs = CreateFrame("Frame", nil, head)
    crumbs:SetPoint("LEFT", titleText, "RIGHT", 22, 0)
    crumbs:SetSize(600, 22)
    crumbs.buttons, crumbs.seps = {}, {}
    local close = UI.IconButton(head, "Close", function() window:Hide() end, 26)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)
    -- Map pin mode: on = clicking the map places the pin (otherwise Ctrl+click).
    -- The button sits on the map, top left; CreateWindow sets position and level after the map holder.
    pinButton = CreateFrame("Button", nil, head)
    pinButton:SetSize(26, 26)
    local pinBg = UI.Box(pinButton)
    local pinIcon = pinButton:CreateTexture(nil, "ARTWORK")
    pinIcon:SetSize(18, 18)
    pinIcon:SetPoint("CENTER")
    pinIcon:SetAtlas("Waypoint-MapPin-Untracked")
    pinButton:SetScript("OnClick", function() SetPinMode(not pinMode) end)
    pinButton:SetScript("OnEnter", function() pinBg:SetColorTexture(unpack(UI.HOVER)) end)
    pinButton:SetScript("OnLeave", function() pinBg:SetColorTexture(unpack(UI.FIELD)) end)
    pinButton.active = ns.AddBorder(pinButton, true, 2)
    for _, e in ipairs(pinButton.active) do
        e:SetVertexColor(unpack(UI.ACCENT))
        e:Hide()
    end
    pinButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(MAP_PIN or L["Map pin"], 1, 1, 1)
        GameTooltip:AddLine(L["Click the map to place a pin (or Ctrl+click anytime). Click the pin again to remove it."], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    pinButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    optionsButton = UI.Button(head, L["Display"], function()
        options:SetShown(not options:IsShown())
        for _, row in ipairs(options) do row.Update() end
    end, 110)
    optionsButton:SetHeight(26)
    optionsButton:SetPoint("RIGHT", close, "LEFT", -6, 0)
    local chevron = UI.Icon(optionsButton, "ChevronDown", 12, UI.MUTED)
    chevron:SetPoint("RIGHT", -8, 0)
    optionsButton.Text:ClearAllPoints()
    optionsButton.Text:SetPoint("CENTER", -6, 0)

    -- map on the left
    local holder = CreateFrame("Frame", nil, window)
    holder:SetPoint("TOPLEFT", PAD, -PAD - 44)
    holder:SetPoint("BOTTOMRIGHT", -PAD - LOG_W - 14, 40)
    ns.AddBorder(holder)
    holder:SetClipsChildren(true)
    canvas = CreateCanvas(holder)
    pinButton:SetParent(holder)
    pinButton:ClearAllPoints()
    pinButton:SetPoint("TOPLEFT", 12, -12)
    pinButton:SetFrameLevel(9000) -- above all map pins and revealed areas (Map/MapExtras.lua)
    -- Questie installed: its icons move onto our map (Quests/QuestieBridge.lua), toggle below the pin button
    if ns.Questie and ns.Questie.IsLoaded() then
        ns.Questie.AttachMap(canvas)
        local questieButton = CreateFrame("Button", nil, holder)
        questieButton:SetSize(26, 26)
        questieButton:SetPoint("TOP", pinButton, "BOTTOM", 0, -6)
        questieButton:SetFrameLevel(9000)
        questieButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local bg = UI.Box(questieButton)
        local icon = questieButton:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\AddOns\\Questie\\Icons\\available")
        local active = ns.AddBorder(questieButton, true, 2)
        for _, e in ipairs(active) do e:SetVertexColor(unpack(UI.ACCENT)) end
        local function Update()
            local on = ns.Questie.IconsShown()
            for _, e in ipairs(active) do e:SetShown(on) end
            icon:SetDesaturated(not on)
        end
        local function Tooltip(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText("Questie", 1, 1, 1)
            GameTooltip:AddLine(ns.Questie.IconsShown() and L["Click: hide Questie icons"] or L["Click: show Questie icons"], 0.56, 0.8, 0.71)
            GameTooltip:AddLine(L["Right-click: Questie menu"], 0.56, 0.8, 0.71)
            GameTooltip:Show()
        end
        questieButton:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                ns.Questie.ToggleMenu()
            else
                ns.Questie.ToggleIcons()
                Update()
                Tooltip(self)
            end
        end)
        questieButton:SetScript("OnEnter", function(self) bg:SetColorTexture(unpack(UI.HOVER)) Tooltip(self) end)
        questieButton:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) GameTooltip:Hide() end)
        questieButton:SetScript("OnShow", Update)
        Update()
    end
    if ns.DungeonMapView then ns.DungeonMapView.Attach(holder, function() OnMapChanged() end) end
    coords = CreateFrame("Frame", nil, holder)
    coords:SetHeight(22)
    coords:SetPoint("BOTTOMLEFT", 12, 12)
    coords:SetFrameLevel(9000) -- above all map pins and revealed areas (Map/MapExtras.lua)
    UI.Box(coords, { 0, 0, 0, 0.6 })
    coords.text = UI.Text(coords, 12, "LEFT")
    coords.text:SetPoint("LEFT", 10, 0)
    local tick = 0
    coords:SetScript("OnUpdate", function(_, elapsed)
        tick = tick + elapsed
        if tick < 0.1 then return end
        tick = 0
        UpdateCoords()
    end)
    coords:Show()

    -- quest log on the right
    logSearch = UI.EditBox(window, 30)
    logSearch:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, 0)
    logSearch:SetWidth(LOG_W - 128)
    local hint = UI.Text(logSearch, 13, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search quest log"])
    logSearch:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        RefreshLog()
    end)
    -- filter: icon only, text in tooltip/menu
    filterButton = UI.IconButton(window, "Filter", function()
        if not filterMenu then CreateFilterMenu() end
        for _, row in ipairs(filterMenu) do row.Update() end
        filterMenu:SetShown(not filterMenu:IsShown())
        GameTooltip:Hide()
    end, 30)
    filterButton.icon:SetSize(16, 16)
    filterButton:SetPoint("LEFT", logSearch, "RIGHT", 6, 0)
    filterButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Filter"])
        for _, entry in ipairs(QUEST_FILTERS) do
            if Filters()[entry.key] then GameTooltip:AddLine(L[entry.label], 0.56, 0.8, 0.71) end
        end
        GameTooltip:Show()
    end)
    filterButton:HookScript("OnLeave", function()
        GameTooltip:Hide()
        UpdateFilterButton()
    end)
    UpdateFilterButton()
    logCount = UI.Text(window, 12, "RIGHT", UI.MUTED)
    -- one checkbox for all (visible) quests, aligned above the rows' track checkboxes
    trackAll = CreateFrame("Button", nil, window)
    trackAll:SetSize(14, 14)
    trackAll:SetPoint("RIGHT", window, "RIGHT", -PAD - 8 - 6, 0)
    trackAll:SetPoint("TOP", logSearch, "CENTER", 0, 7)
    UI.CheckBg(trackAll)
    local allTick = UI.Icon(trackAll, "Check", 10, UI.ACCENT)
    allTick:SetPoint("CENTER")
    local function AllTracked()
        if #visibleQuests == 0 then return false end
        for _, id in ipairs(visibleQuests) do
            if C_QuestLog.GetQuestWatchType(id) == nil then return false end
        end
        return true
    end
    trackAll.Update = function() allTick:SetShown(AllTracked()) end
    trackAll:SetScript("OnClick", function()
        local on = not AllTracked()
        for _, id in ipairs(visibleQuests) do
            if on then C_QuestLog.AddQuestWatch(id) else C_QuestLog.RemoveQuestWatch(id) end
        end
        RefreshLog()
    end)
    trackAll:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(AllTracked() and L["Untrack all"] or L["Track all"])
        GameTooltip:Show()
    end)
    trackAll:SetScript("OnLeave", function() GameTooltip:Hide() end)
    logCount:SetPoint("LEFT", filterButton, "RIGHT", 8, 0)
    logCount:SetPoint("RIGHT", trackAll, "LEFT", -10, 0)
    logList = UI.ScrollArea(window)
    logList:SetPoint("TOPLEFT", logSearch, "BOTTOMLEFT", 0, -10)
    logList:SetPoint("BOTTOMRIGHT", -PAD - 8, 40)
    logList.child:SetWidth(LOG_W - 8)
    if ns.DungeonPanel then ns.DungeonPanel.Attach(window, logSearch, logList, { logSearch, filterButton, logCount, trackAll, logList }) end

    footer = UI.Text(window, 12, "LEFT", UI.MUTED)
    footer:SetPoint("BOTTOMLEFT", PAD, 14)
    local footerHint = UI.Text(window, 12, "RIGHT", UI.MUTED)
    footerHint:SetPoint("BOTTOMRIGHT", -PAD, 14)
    footerHint:SetText(L["Ctrl+click: map pin · Right-click: up one level · Mouse wheel: zoom"])
    CreateOptions()

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
        -- dungeon map: the clicked swirl, else the instance you are in. Next frame, after the canvas
        -- has set its zone (a map change closes the dungeon view).
        local view = ns.DungeonMapView
        if view then
            local wanted = view.wanted
            view.wanted = nil
            C_Timer.After(0, function()
                if not window:IsShown() then return end
                local inInstance, kind = IsInInstance()
                local instance = inInstance and (kind == "party" or kind == "raid") and select(8, GetInstanceInfo())
                view.Show(wanted or instance)
            end)
        end
        OnMapChanged()
        LayoutLog()
        -- On first open Blizzard computes the zoom before layout (map too big, bottom cut off):
        -- after layout, rebuild zoom levels and show the whole map
        C_Timer.After(0, function()
            if window:IsShown() and canvas:GetMapID() then
                canvas.ScrollContainer:CreateZoomLevels()
                canvas:ResetZoom()
            end
        end)
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
        options:Hide()
        if pinMode then SetPinMode(false) end
    end)
end

-- Opening -----------------------------------------------------------------------------------------

local function Open(mapID)
    if not window then CreateWindow() end
    if window:IsShown() then
        if mapID then canvas:SetMapID(mapID) end
        return
    end
    canvas.wantedMap = mapID
    window:Show()
end

-- Dungeon swirl click (Map/MapExtras.lua): show that dungeon's map
function ns.OpenDungeonMap(instance)
    local view = ns.DungeonMapView
    if not (view and view.Has(instance)) then return false end
    if window and window:IsShown() then return view.Show(instance) end
    view.wanted = instance
    Open()
    return true
end

local function Toggle()
    if window and window:IsShown() then window:Hide() else Open() end
end
ns.ToggleWorldMap = Toggle
-- open on a given map (tracker: Questie target zone)
function ns.OpenWorldMap(mapID)
    if Enabled() then Open(mapID) elseif OpenWorldMap then OpenWorldMap(mapID) end
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    -- M and L open our window directly (override bindings; Blizzard's bindings stay untouched)
    local toggle = CreateFrame("Button", "MeredanUIWorldMapToggle", UIParent)
    toggle:SetScript("OnClick", Toggle)
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        ClearOverrideBindings(toggle)
        for _, action in ipairs({ "TOGGLEWORLDMAP", "TOGGLEQUESTLOG" }) do
            for _, key in ipairs({ GetBindingKey(action) }) do
                SetOverrideBindingClick(toggle, false, key, "MeredanUIWorldMapToggle", "LeftButton")
            end
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)
    if QuestLogMicroButton then QuestLogMicroButton:SetScript("OnClick", Toggle) end
    -- Redirect Blizzard's global openers (tracker click, minimap zone name, map pin links ...) to our
    -- window. Only these global names, no methods on Blizzard frames.
    ToggleWorldMap = Toggle
    ToggleQuestLog = Toggle
    OpenWorldMap = function(mapID) Open(mapID) end
    OpenQuestLog = function(mapID) Open(mapID) end
    QuestMapFrame_OpenToQuestDetails = function(questID)
        if questID then
            expandedQuest, scrollToQuest = questID, questID
            C_SuperTrack.SetSuperTrackedQuestID(questID)
            if logSearch and logSearch:GetText() ~= "" then logSearch:SetText("") end -- the search would hide it
        end
        Open(questID and GetQuestUiMapID and GetQuestUiMapID(questID) or nil)
        RefreshLog()
    end
    OpenMapToUserWaypoint = function()
        local point = C_Map.GetUserWaypoint()
        Open(point and point.uiMapID)
    end

    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED",
        "QUEST_TURNED_IN", "SUPER_TRACKING_CHANGED", "UNIT_QUEST_LOG_CHANGED" }) do
        ns:On(event, function() if window:IsShown() then RefreshLog() end end)
    end
    -- Focus changed elsewhere (tracker, map pin ...) while the map is open: collapse old quest, expand
    -- new one, scroll the list to it, show its zone. Nothing happens while the map is closed.
    ns:On("SUPER_TRACKING_CHANGED", function()
        if not window:IsShown() then return end
        local questID = C_SuperTrack.GetSuperTrackedQuestID()
        if listTracked then
            local own = listTracked == questID
            listTracked = nil
            if own then return end
        end
        if not questID or questID == 0 or questID == expandedQuest then return end
        expandedQuest, scrollToQuest = questID, questID
        local mapID = GetQuestUiMapID and GetQuestUiMapID(questID)
        if mapID and mapID > 0 and canvas:GetMapID() ~= mapID then canvas:SetMapID(mapID) end
        RefreshLog()
    end)
    -- map follows the player on zone change (only while it shows the player's map)
    local playerMap = MapUtil.GetDisplayableMapForPlayer()
    for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "NEW_WMO_CHUNK" }) do
        ns:On(event, function()
            local now = MapUtil.GetDisplayableMapForPlayer()
            if window:IsShown() and canvas:GetMapID() == playerMap and now ~= playerMap then canvas:SetMapID(now) end
            playerMap = now
        end)
    end
    ns:On("USER_WAYPOINT_UPDATED", function() if pinMode then SetPinMode(false) end end)
end)
