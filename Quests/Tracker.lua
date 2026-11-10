-- Own quest tracker (WoW Forever) instead of Blizzard's objective tracker - same rows as the map's
-- quest log, free-standing at the screen edge.
--
--   Dungeon                    -   <- instances only: Blizzard's scenario data, else our own list
--   | The Deadmines                   (dungeon journal + boss kill events)
--     v 1/1 Rhahk'Zor defeated
--     ! [18] Red Silk                <- quests of the instance
--   Quests  9/40               -   <- tracked quests (auto-collapsed inside instances)
--  |! [17] Cave Mushrooms      [#]  <- stripe = difficulty, ? = ready to turn in (green tint),
--  |   Scorched Stalker: 3/5           focus gray tint, item as image only (active green)
--   Professions                -   <- tracked recipes with reagents from the bags
--
-- Blizzard's ObjectiveTrackerFrame is only parked (reparented to a hidden frame) - its events keep
-- running (e.g. auto-tracking new quests). Quest items are used via our own bar to the left (like
-- Kaliel's Tracker): fixed slots, the active one on top with a keybind - so the tracker itself has no
-- protected buttons and can scroll in combat.
-- Retail keeps using Quests/QuestTracker.lua (restyled Blizzard tracker, Mythic+).
local _, ns = ...
local L = ns.L

local WIDTH = 290
local GAP, SIDE_GAP = 10, 60     -- gap to the buffs / to the right action bar
local ROW_GAP = 2
local ACTIVE_SIZE, ITEM_SIZE = 40, 30   -- item bar: active on top, others below
local BAR_GAP = 6
local ICON_SIZE = 18                     -- image in the quest row (display only)
local HEADER_H = 26
local SECTION_GAP = 12
local STICKY_H = HEADER_H + 6   -- sticky header while scrolling
local DONE = { 0.56, 0.8, 0.71 }
local RED = { 1, 0.31, 0.31 }

-- Shared with the map's quest log ----------------------------------------------------------------

function ns.QuestColor(questID)
    local difficulty = C_PlayerInfo.GetContentDifficultyQuestForPlayer and C_PlayerInfo.GetContentDifficultyQuestForPlayer(questID)
    local color = difficulty and GetDifficultyColor and GetDifficultyColor(difficulty)
    return color or { r = 1, g = 0.82, b = 0 }
end

function ns.IsGroupQuest(info)
    if (info.suggestedGroup or 0) > 1 then return true end
    local tag = C_QuestLog.GetQuestTagInfo(info.questID)
    if not tag then return false end
    if tag.isElite then return true end
    local T = Enum.QuestTag
    return T ~= nil and (tag.tagID == T.Group or tag.tagID == T.Dungeon or tag.tagID == T.Raid or tag.tagID == T.Heroic)
end

if not ns.IS_FOREVER then return end

local tracker, anchor, itemLayer, scroll, content, thumb
local headers, rows, bossLines, itemButtons, zoneLabels = {}, {}, {}, {}, {}
local instanceBlock
local pending, itemsPending = false, false
local lastItems = {}          -- quest items from the last layout (PickBarItems reorders them)
local barItems = {}           -- { questID, logIndex, link, texture, charges } - active first
local hasTimers = false
local hasItems = false      -- several items: re-pick the "nearest quest" periodically
local bossHidden = false
local hasTargets = false    -- Questie distances shown: refresh them in turn (UpdateNextDistance)
local arrowRow              -- row with the direction arrow (focus quest, else the first with a distance)
local instanceCollapse      -- in instances: quests collapsed (nil = saved setting)
local combatCollapse = false -- "Collapse in combat" while in combat
local kills, killsInstance = {}, nil

-- Tracker options (Settings > Quests): default on unless noted
local function Opt(key) return ns.db[key] ~= false end
local function OptOn(key) return ns.db[key] == true end -- default off
local function QuestieOn(key) return ns.Questie and ns.Questie.IsReady() and Opt(key) end

local function QuestCollapsed(questID) return ns.db.trackerQuestCollapsed and ns.db.trackerQuestCollapsed[questID] or false end
local function ToggleQuestCollapsed(questID)
    ns.db.trackerQuestCollapsed = ns.db.trackerQuestCollapsed or {}
    ns.db.trackerQuestCollapsed[questID] = not ns.db.trackerQuestCollapsed[questID] or nil
end

local function Collapsed(key)
    if key == "quests" and combatCollapse then return true end
    if key == "quests" and instanceCollapse ~= nil then return instanceCollapse end
    return ns.db.trackerCollapsed and ns.db.trackerCollapsed[key] or false
end

local function ToggleCollapsed(key)
    if key == "quests" and instanceCollapse ~= nil then
        instanceCollapse = not instanceCollapse
    else
        ns.db.trackerCollapsed = ns.db.trackerCollapsed or {}
        ns.db.trackerCollapsed[key] = not ns.db.trackerCollapsed[key] or nil
    end
    tracker.Refresh()
end

-- Building blocks --------------------------------------------------------------------------------

local function BuildHeader(parent)
    local UI = ns.UI
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(HEADER_H)
    header.text = UI.Text(header, 14, "LEFT", UI.ACCENT)
    header.text:SetPoint("LEFT")
    header.count = UI.Text(header, 12, "LEFT", UI.MUTED)
    header.count:SetPoint("LEFT", header.text, "RIGHT", 8, 0)
    header.sign = UI.Icon(header, "Minus", 12, UI.MUTED)
    header.sign:SetPoint("RIGHT", -2, 0)
    header.line = header:CreateTexture(nil, "ARTWORK")
    header.line:SetColorTexture(DONE[1], DONE[2], DONE[3], 0.7)
    header.line:SetHeight(1)
    header.line:SetPoint("BOTTOMLEFT")
    header.line:SetPoint("BOTTOMRIGHT")
    header:SetScript("OnClick", function(self) ToggleCollapsed(self.key) end)
    header:SetScript("OnEnter", function(self) self.sign:SetVertexColor(unpack(UI.ACCENT)) end)
    header:SetScript("OnLeave", function(self) self.sign:SetVertexColor(unpack(UI.MUTED)) end)
    return header
end

local function Header(i)
    if not headers[i] then headers[i] = BuildHeader(content) end
    return headers[i]
end

-- The header of the section being scrolled sticks at the top (until the next one pushes it away)
local sticky
local function UpdateSticky(offset)
    if not sticky then
        sticky = BuildHeader(tracker)
        sticky:SetFrameLevel(content:GetFrameLevel() + 20)
        sticky:SetWidth(WIDTH)
        sticky:SetPoint("TOPLEFT", tracker, "TOPLEFT")
    end
    -- section whose header has already slid under the sticky header
    local current
    for _, header in ipairs(headers) do
        if header:IsShown() and header.y and header.y <= offset then
            if not current or header.y > current.y then current = header end
        end
    end
    if offset <= 0 or not current then sticky:Hide() return end
    sticky.key = current.key
    sticky.text:SetText(current.text:GetText())
    sticky.count:SetText(current.count:GetText() or "")
    sticky.sign:SetTexture(ns.MEDIA .. "Icons\\" .. (Collapsed(current.key) and "Plus" or "Minus"))
    sticky:Show()
end

local function WowheadURL(questID)
    local lang = GetLocale():sub(1, 2)
    lang = lang == "en" and "" or ((lang == "zh" and "cn" or lang) .. "/")
    return "https://www.wowhead.com/forever/" .. lang .. "quest=" .. questID
end

local function LinkQuest(questID)
    local link = GetQuestLink(questID)
    if not link then return end
    if ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow() then
        ChatFrameUtil.InsertLink(link)
    else
        local open = _G["ChatFrame_OpenChat"]
        if open then open(link) end
    end
end

-- Waypoint to the nearest objective / turn-in (Questie data): TomTom or Blizzard's map pin
local function Waypoint(questID)
    local target = ns.Questie and ns.Questie.IsReady() and ns.Questie.Nearest(questID)
    if target then ns.Questie.SetWaypoint(target) end
end

-- Right-click menu, entries like Questie's tracker menu (map ones need Questie)
local function QuestMenu(row)
    local questID = row.questID
    local Q = ns.Questie and ns.Questie.IsReady() and ns.Questie or nil
    local complete = C_QuestLog.IsComplete(questID) or C_QuestLog.ReadyForTurnIn(questID)
    -- icons from the MDI set (Media/Icons/CREDITS.txt)
    local items = {}
    local target = Q and Q.Nearest(questID)
    if Q and not complete then
        -- objectives: click = show on map, small pin = waypoint
        for i, o in ipairs(Q.Objectives(questID)) do
            if i > 4 then break end
            items[#items + 1] = { value = "obj:" .. o.index, label = o.text or o.name or "?", icon = "Map", actions = {
                { icon = "Entrance", tooltip = L["Set waypoint"], onClick = function() Q.SetWaypoint(o) end },
            } }
        end
    end
    if Q and target then
        items[#items + 1] = { value = "qmap", label = complete and L["Show turn-in on map"] or L["Show on map"], icon = "Map",
            separator = #items > 0 }
        items[#items + 1] = { value = "waypoint", label = L["Set waypoint"], icon = "Entrance" }
    end
    if Q then
        items[#items + 1] = { value = "focus", label = Q.IsFocused(questID) and L["Unfocus on map"] or L["Focus on map"], icon = "Star" }
        items[#items + 1] = { value = "icons", label = Q.IconsHidden(questID) and L["Show map icons"] or L["Hide map icons"],
            icon = Q.IconsHidden(questID) and "Tracking" or "Phase" }
    end
    items[#items + 1] = { value = "collapse", label = QuestCollapsed(questID) and L["Expand quest"] or L["Collapse quest"],
        icon = QuestCollapsed(questID) and "Plus" or "Minus", separator = Q ~= nil }
    items[#items + 1] = { value = "log", label = L["Show in quest log"], icon = "Quest" }
    items[#items + 1] = { value = "link", label = L["Link to chat"], icon = "EmoteTALK" }
    items[#items + 1] = { value = "wowhead", label = L["Wowhead link"], icon = "Copy" }
    if C_QuestLog.IsPushableQuest(questID) and IsInGroup() then
        items[#items + 1] = { value = "share", label = L["Share"], icon = "Friends" }
    end
    if C_QuestLog.GetQuestWatchType(questID) ~= nil then
        items[#items + 1] = { value = "untrack", label = L["Stop tracking"], icon = "Phase" }
    end
    if C_QuestLog.CanAbandonQuest(questID) then
        items[#items + 1] = { value = "abandon", label = L["Abandon"], color = { 1, 0.38, 0.38 }, separator = true, icon = "Close" }
    end
    local title = C_QuestLog.GetTitleForQuestID(questID)
    ns.UI.OpenList(row, items, nil, function(value)
        local objective = type(value) == "string" and value:match("^obj:(%d+)$")
        local bridge = ns.Questie
        if objective and bridge then
            bridge.ShowOnMap(questID, tonumber(objective))
        elseif value == "qmap" and bridge then
            bridge.ShowOnMap(questID)
        elseif value == "waypoint" then
            Waypoint(questID)
        elseif value == "focus" and bridge then
            bridge.ToggleFocus(questID)
        elseif value == "icons" and bridge then
            bridge.ToggleQuestIcons(questID)
        elseif value == "collapse" then
            ToggleQuestCollapsed(questID)
            tracker.Refresh()
        elseif value == "log" then
            QuestMapFrame_OpenToQuestDetails(questID)
        elseif value == "link" then
            LinkQuest(questID)
        elseif value == "wowhead" then
            if ns.ShowLinkWindow then ns.ShowLinkWindow(WowheadURL(questID)) end
        elseif value == "share" then
            QuestLogPushQuest(C_QuestLog.GetLogIndexForQuestID(questID))
        elseif value == "untrack" then
            C_QuestLog.RemoveQuestWatch(questID)
        elseif value == "abandon" then
            C_QuestLog.SetSelectedQuest(questID)
            C_QuestLog.SetAbandonQuest()
            StaticPopup_Show("ABANDON_QUEST", C_QuestLog.GetTitleForQuestID(questID) or "")
        end
    end, { menu = true, title = title, titleIcon = "Quest" })
end

local function RecipeMenu(row)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(row.recipeID, false)
    ns.UI.OpenList(row, { { value = "untrack", label = L["Stop tracking"], icon = "Phase" } }, nil, function()
        C_TradeSkillUI.SetRecipeTracked(row.recipeID, false, false)
    end, { menu = true, title = schematic and schematic.name, titleIcon = "Crafting" })
end

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, content)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.tint = row:CreateTexture(nil, "BACKGROUND", nil, -1) -- ready to turn in / focus / failed
    row.tint:SetAllPoints()
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.04)
    row.hover:Hide()
    row.sign = UI.Text(row, 14, "CENTER")
    row.sign:SetPoint("TOPLEFT", 5, -6)
    row.sign:SetWidth(16)
    row.title = UI.Text(row, 13, "LEFT")
    row.title:SetPoint("TOPLEFT", 26, -6)
    row.title:SetWordWrap(true)
    row.goals = UI.Text(row, 12, "LEFT", UI.MUTED)
    row.goals:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
    row.goals:SetWordWrap(true)
    row.goals:SetSpacing(3)
    row.timer = UI.Text(row, 12, "LEFT")
    row.timerIcon = UI.Icon(row, "Hourglass", 12)
    row.timerIcon:SetPoint("RIGHT", row.timer, "LEFT", -4, 0) -- RIGHT/LEFT = vertically centered on the line
    row.timer:Hide()
    row.timerIcon:Hide()
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetHeight(12)
    row.bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    row.bar:SetStatusBarColor(DONE[1], DONE[2], DONE[3], 0.85)
    row.bar:SetMinMaxValues(0, 100)
    UI.Box(row.bar, { 0.04, 0.04, 0.05, 1 })
    row.bar.text = ns.CreateText(row.bar, 10, "CENTER")
    row.bar.text:SetPoint("CENTER")
    row.bar:Hide()
    -- quest item: image only (used via the bar); click = focus the quest
    row.item = CreateFrame("Button", nil, row)
    row.item:SetSize(ICON_SIZE, ICON_SIZE)
    row.item:SetPoint("TOPRIGHT", -6, -6)
    ns.AddBorder(row.item)
    row.item.icon = row.item:CreateTexture(nil, "ARTWORK")
    row.item.icon:SetAllPoints()
    row.item.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.item.active = CreateFrame("Frame", nil, row.item)
    row.item.active:SetAllPoints()
    for _, e in ipairs(ns.AddBorder(row.item.active, nil, 2)) do e:SetVertexColor(unpack(DONE)) end
    row.item.active:Hide()
    row.item:SetScript("OnClick", function() C_SuperTrack.SetSuperTrackedQuestID(row.questID) end)
    row.item:SetScript("OnEnter", function(self)
        row.hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.logIndex then GameTooltip:SetQuestLogSpecialItem(self.logIndex) else GameTooltip:SetItemByID(self.itemID) end
        GameTooltip:Show()
    end)
    row.item:SetScript("OnLeave", function() row.hover:Hide(); GameTooltip:Hide() end)
    row.item:Hide()
    -- Questie: nearest objective / turn-in with distance; click opens the map there
    row.dist = CreateFrame("Button", nil, row)
    row.dist:SetHeight(14)
    row.dist.arrow = UI.Icon(row.dist, "ChevronDown", 12, UI.ACCENT)
    row.dist.arrow:SetPoint("LEFT", 0, 0)
    row.dist.text = UI.Text(row.dist, 12, "LEFT", UI.MUTED)
    row.dist.text:SetWordWrap(false)
    row.dist:SetScript("OnClick", function(self)
        if self.target and self.target.uiMapID and ns.OpenWorldMap then ns.OpenWorldMap(self.target.uiMapID) end
    end)
    row.dist:SetScript("OnEnter", function(self)
        row.hover:Show()
        self.text:SetTextColor(unpack(UI.TEXT))
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.target and self.target.name or "", 1, 1, 1)
        if self.target and self.target.zone then GameTooltip:AddLine(self.target.zone, 0.6, 0.59, 0.56) end
        GameTooltip:AddLine(L["Click: show on map"], 0.56, 0.8, 0.71)
        GameTooltip:Show()
    end)
    row.dist:SetScript("OnLeave", function(self)
        row.hover:Hide()
        self.text:SetTextColor(unpack(UI.MUTED))
        GameTooltip:Hide()
    end)
    row.dist:Hide()
    row:SetScript("OnEnter", function(self) self.hover:Show() end)
    row:SetScript("OnLeave", function(self) self.hover:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if self.recipeID then
            if button == "RightButton" then return RecipeMenu(self) end
            if IsShiftKeyDown() then C_TradeSkillUI.SetRecipeTracked(self.recipeID, false, false) end
            return
        end
        local questID = self.questID
        if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow() then
            local link = GetQuestLink(questID)
            if link then ChatFrameUtil.InsertLink(link) end
            return
        end
        if button == "RightButton" then return QuestMenu(self) end
        if IsShiftKeyDown() then return C_QuestLog.RemoveQuestWatch(questID) end
        if IsControlKeyDown() then return Waypoint(questID) end
        if C_SuperTrack.GetSuperTrackedQuestID() == questID then
            QuestMapFrame_OpenToQuestDetails(questID)
        else
            C_SuperTrack.SetSuperTrackedQuestID(questID)
        end
    end)
    rows[i] = row
    return row
end

-- Zone name above a group of quests ("Group by zone")
local function ZoneLabel(i)
    if zoneLabels[i] then return zoneLabels[i] end
    local UI = ns.UI
    local label = CreateFrame("Frame", nil, content)
    label:SetHeight(18)
    label.text = UI.Text(label, 12, "LEFT", UI.MUTED)
    label.text:SetPoint("LEFT", 4, 0)
    label.text:SetPoint("RIGHT")
    label.text:SetWordWrap(false)
    zoneLabels[i] = label
    return label
end

-- Share of a quest's objectives done (0-1), for "By progress"
local function Progress(questID)
    if C_QuestLog.IsComplete(questID) or C_QuestLog.ReadyForTurnIn(questID) then return 1 end
    local done, total = 0, 0
    for _, obj in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local need = obj.numRequired or 0
        if need > 0 then
            done, total = done + math.min(obj.numFulfilled or 0, need) / need, total + 1
        else
            done, total = done + (obj.finished and 1 or 0), total + 1
        end
    end
    return total > 0 and done / total or 0
end

local function BossLine(i)
    if bossLines[i] then return bossLines[i] end
    local UI = ns.UI
    local line = CreateFrame("Frame", nil, content)
    line:SetHeight(20)
    line.check = UI.Icon(line, "Check", 11, DONE)
    line.check:SetPoint("LEFT", 6, 0)
    line.dot = line:CreateTexture(nil, "OVERLAY")
    line.dot:SetColorTexture(0.6, 0.59, 0.56, 1)
    line.dot:SetSize(4, 4)
    line.dot:SetPoint("CENTER", line.check, "CENTER")
    line.text = UI.Text(line, 12, "LEFT")
    line.text:SetPoint("LEFT", 24, 0)
    line.text:SetPoint("RIGHT")
    bossLines[i] = line
    return line
end

local function InstanceBlock()
    if instanceBlock then return instanceBlock end
    local UI = ns.UI
    instanceBlock = CreateFrame("Frame", nil, content)
    instanceBlock:SetHeight(34)
    local bg = instanceBlock:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.45)
    ns.AddBorder(instanceBlock)
    local strip = instanceBlock:CreateTexture(nil, "ARTWORK")
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("BOTTOMLEFT")
    strip:SetWidth(2)
    strip:SetColorTexture(DONE[1], DONE[2], DONE[3], 1)
    instanceBlock.text = UI.Text(instanceBlock, 15, "LEFT")
    instanceBlock.text:SetPoint("LEFT", 12, 0)
    instanceBlock.text:SetPoint("RIGHT", -8, 0)
    return instanceBlock
end

-- Quest items: own bar left of the tracker (secure buttons in fixed slots - assigned/reordered only
-- out of combat, usable always). Button 1 = active, with keybind.
local function ItemButton(i)
    if itemButtons[i] then return itemButtons[i] end
    local size = i == 1 and ACTIVE_SIZE or ITEM_SIZE
    local button = CreateFrame("Button", i == 1 and "MeredanUIQuestItem1" or nil, itemLayer, "SecureActionButtonTemplate")
    button:SetSize(size, size)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "item")
    local edges = ns.AddBorder(button, nil, i == 1 and 2 or 1)
    if i == 1 then
        for _, e in ipairs(edges) do e:SetVertexColor(unpack(DONE)) end
        local glow = button:CreateTexture(nil, "BACKGROUND", nil, -2) -- subtle glow around the green
        glow:SetPoint("TOPLEFT", -5, 5)
        glow:SetPoint("BOTTOMRIGHT", 5, -5)
        glow:SetColorTexture(DONE[1], DONE[2], DONE[3], 0.22)
        button.hotkey = ns.CreateText(button, 11, "RIGHT", "OUTLINE")
        button.hotkey:SetPoint("TOPRIGHT", -2, -3)
    end
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.count = ns.CreateText(button, 10, "RIGHT", "OUTLINE")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    button:SetScript("OnEnter", function(self)
        if not (self.logIndex or self.itemID) then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.logIndex then GameTooltip:SetQuestLogSpecialItem(self.logIndex) else GameTooltip:SetItemByID(self.itemID) end
        local title = self.questID and C_QuestLog.GetTitleForQuestID(self.questID)
        if title then GameTooltip:AddLine(title, DONE[1], DONE[2], DONE[3]) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- fixed slots: active top right of the layer, others below (with some spacing)
    if i == 1 then
        button:SetPoint("TOPRIGHT", itemLayer, "TOPRIGHT", 0, -2)
    else
        button:SetPoint("TOP", itemButtons[i - 1], "BOTTOM", 0, -(i == 2 and BAR_GAP * 2 or BAR_GAP))
    end
    itemButtons[i] = button
    return button
end

local function UpdateCooldowns()
    for _, button in ipairs(itemButtons) do
        if button:IsShown() and (button.logIndex or button.itemID) then
            local start, duration, enable
            if button.logIndex then
                start, duration, enable = GetQuestLogSpecialItemCooldown(button.logIndex)
            else
                start, duration, enable = C_Container.GetItemCooldown(button.itemID)
            end
            if start and duration and duration > 0 and enable ~= 0 then
                button.cooldown:SetCooldown(start, duration)
            else
                button.cooldown:Clear()
            end
        end
    end
end

local function UpdateHotkey()
    local button = itemButtons[1]
    if not button then return end
    local key = GetBindingKey("CLICK MeredanUIQuestItem1:LeftButton")
    button.hotkey:SetText(key and GetBindingText(key, true) or "")
end

-- Assign the bar (out of combat only); then the quest rows show which one is active
local appliedSig -- bar content last assigned (skip SetAttribute when nothing changed)
local function ItemsSig()
    local sig = ""
    for _, item in ipairs(barItems) do
        sig = sig .. (item.questID or 0) .. ":" .. tostring(item.itemID or item.link) .. ":" .. (item.charges or 0) .. ";"
    end
    return sig
end

local function MarkActiveRow()
    local active = itemButtons[1] and itemButtons[1]:IsShown() and itemButtons[1].questID
    for _, row in ipairs(rows) do
        if row.item then row.item.active:SetShown(row.item:IsShown() and row.questID == active) end
    end
end

local function ApplyItems()
    local sig = ItemsSig()
    if sig == appliedSig then return MarkActiveRow() end
    if InCombatLockdown() then
        if not itemsPending then
            itemsPending = true
            ns.AfterCombat(function() itemsPending = false; ApplyItems() end)
        end
        return
    end
    for i, item in ipairs(barItems) do
        local button = ItemButton(i)
        button.questID, button.logIndex, button.itemID = item.questID, item.logIndex, item.itemID
        local itemID = C_Item.GetItemInfoInstant(item.link)
        button:SetAttribute("item", itemID and ("item:" .. itemID) or item.link)
        button.icon:SetTexture(item.texture)
        button.count:SetText(item.charges and item.charges > 1 and item.charges or "")
        button:Show()
    end
    for i = #barItems + 1, #itemButtons do
        itemButtons[i].questID, itemButtons[i].logIndex, itemButtons[i].itemID = nil, nil, nil
        itemButtons[i]:Hide()
    end
    appliedSig = sig
    UpdateHotkey()
    UpdateCooldowns()
    MarkActiveRow()
end

-- Bar order: focus quest first, otherwise the closest quest with an item. force = always reapply;
-- the 2 s poll only reapplies when the first slot changes (no full tracker rebuild per poll)
local function PickBarItems(force)
    local items, superTracked = lastItems, C_SuperTrack.GetSuperTrackedQuestID()
    local active
    for _, item in ipairs(items) do
        if item.questID == superTracked then active = item end
    end
    if not active then
        local best
        for _, item in ipairs(items) do
            local dist = C_QuestLog.GetDistanceSqToQuest(item.questID)
            if dist and not issecretvalue(dist) and (not best or dist < best) then best, active = dist, item end
        end
    end
    active = active or items[1]
    if not force and active == barItems[1] then return end
    wipe(barItems)
    if active then barItems[1] = active end
    for _, item in ipairs(items) do
        if item ~= active then barItems[#barItems + 1] = item end
    end
    ApplyItems()
end

-- Data -------------------------------------------------------------------------------------------

local function TimeText(seconds)
    seconds = math.max(0, math.floor(seconds))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function QuestTag(info)
    local tag = C_QuestLog.GetQuestTagInfo(info.questID)
    local T = Enum.QuestTag
    if T and tag and (tag.tagID == T.Dungeon) then return L["Dungeon"] end
    if T and tag and (tag.tagID == T.Raid) then return L["Raid"] end
    if (info.suggestedGroup or 0) > 1 then return L["Group %d"]:format(info.suggestedGroup) end
    if tag and tag.isElite then return L["Elite"] end
end

-- Questie target line: "Objective · 320 yd (Zone)"; complete quests only the distance (the turn-in
-- line above already names NPC and zone)
local function UpdateDistance(row)
    local target, dist = row.dist.target, row.dist
    if not target then return end
    local name = not dist.complete and target.name or nil
    local yards = target.yards and L["%d yd"]:format(math.floor(target.yards + 0.5)) or nil
    local text = (name and yards) and (name .. "  ·  " .. yards) or name or yards or ""
    if not dist.complete and target.zone and target.zone ~= GetZoneText() then
        text = text .. (text ~= "" and "  " or "") .. "(" .. target.zone .. ")"
    end
    dist.text:SetText(text)
end

-- Direction arrow on one row only (focus quest, else the first with a distance); hidden where the
-- game hides the player position (instances)
-- Round-robin distance refresh (see the tracker's OnUpdate)
local distIndex = 0
local MOVE_YARDS = 5
local function UpdateNextDistance()
    local count = #rows
    for _ = 1, count do
        distIndex = distIndex % count + 1
        local row = rows[distIndex]
        if row:IsShown() and row.dist:IsShown() and row.questID then
            local x, y = UnitPosition("player")
            if x and not issecretvalue(x) and not issecretvalue(y) and row.dist.px
                and (x - row.dist.px) ^ 2 + (y - row.dist.py) ^ 2 < MOVE_YARDS * MOVE_YARDS then
                return -- standing still: the old distance is still right
            end
            if x and not issecretvalue(x) and not issecretvalue(y) then row.dist.px, row.dist.py = x, y end
            local target = ns.Questie.Nearest(row.questID)
            -- appeared/vanished: full layout (heights change), else only the text
            if (target == nil) ~= (row.dist.target == nil) then return tracker.Refresh() end
            row.dist.target = target
            UpdateDistance(row)
            return
        end
    end
end
UpdateNextDistance = ns.PerfProbe("Tracker: distance", UpdateNextDistance)

-- Re-anchoring only when the arrow appears/disappears (it runs ~20x per second)
local function SetArrowShown(dist, on)
    if dist.arrowOn == on then return end
    dist.arrowOn = on
    dist.arrow:SetShown(on)
    dist.text:ClearAllPoints()
    dist.text:SetPoint("LEFT", on and 16 or 0, 0)
    dist.text:SetPoint("RIGHT")
end

-- full = after a layout (rows may have changed quests): reset every row; otherwise only the
-- arrow row is touched
local function UpdateArrow(full)
    if full then
        for _, row in ipairs(rows) do
            if row.dist and row ~= arrowRow then SetArrowShown(row.dist, false) end
        end
    end
    local row = arrowRow
    local dist = row and row.dist
    if not (dist and row:IsShown() and dist:IsShown()) then return end
    local angle
    if ns.Questie and Opt("trackerQuestieArrow") then
        local ok, a = pcall(ns.Questie.Direction, dist.target)
        angle = ok and a or nil
    end
    SetArrowShown(dist, angle ~= nil)
    if angle then dist.arrow:SetRotation(angle + math.pi) end -- chevron art points down
end
UpdateArrow = ns.PerfProbe("Tracker: arrow", UpdateArrow)

-- A quest's objectives: lines (text) and optional percent for the bar
local function QuestGoals(questID, logIndex, complete, failed)
    local lines, percent = {}, nil
    if failed then
        lines[1] = "|cffff5050" .. (FAILED or L["Failed"]) .. "|r"
        return lines
    end
    for _, obj in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        if obj.type == "progressbar" and not obj.finished then
            percent = GetQuestProgressBarPercent(questID) or 0
        elseif obj.text and obj.text ~= "" and not (obj.finished and OptOn("trackerHideDoneGoals")) then
            lines[#lines + 1] = obj.finished and ("|cff8ecbb4" .. obj.text .. "|r") or obj.text
        end
    end
    if complete and #lines == 0 then
        local text = GetQuestLogCompletionText and GetQuestLogCompletionText(logIndex)
        lines[1] = "|cff8ecbb4" .. ((text and text ~= "") and text or (QUEST_WATCH_QUEST_READY or L["Ready to turn in"])) .. "|r"
    end
    -- Questie: who takes the quest back (Classic quests rarely say)
    if complete and QuestieOn("trackerQuestieTurnIn") then
        local npc, zone = ns.Questie.TurnIn(questID)
        if npc then lines[#lines + 1] = L["Turn in: %s"]:format(npc .. (zone and (" - " .. zone) or "")) end
    end
    -- Timed quest: time left always red so it stands out; in the last minute the line blinks every
    -- second (the tracker then refreshes every second)
    local total, elapsed = C_QuestLog.GetTimeAllowed(questID)
    if total and elapsed and not issecretvalue(total) and total > 0 then
        local left = total - elapsed
        hasTimers = true
        local color = (left < 60 and math.floor(left) % 2 == 1) and { 1, 0.62, 0.55 } or { 1, 0.31, 0.31 }
        -- separate line with a real texture instead of |T|t in text: hourglass exactly centered on the font
        return lines, percent, { text = L["Time left %s"]:format(TimeText(left)), color = color }
    end
    return lines, percent
end

-- Instance bosses: Blizzard's scenario data, otherwise dungeon journal + boss kill events
local function ScenarioBosses()
    local name, currentStage, numStages, _, _, _, _, _, _, scenarioType = C_Scenario.GetInfo()
    if not numStages or numStages == 0 or currentStage > numStages then return nil end
    local _, _, numCriteria = C_Scenario.GetStepInfo()
    local list = {}
    for i = 1, numCriteria or 0 do
        local c = C_ScenarioInfo.GetCriteriaInfo(i)
        if c and c.description and not issecretvalue(c.description) then
            local text = c.description
            if not c.isWeightedProgress and not c.isFormatted and c.quantity and not issecretvalue(c.quantity) then
                text = ("%d/%d %s"):format(c.quantity, c.totalQuantity, c.description)
            end
            list[#list + 1] = { text = text, done = c.completed and not issecretvalue(c.completed) }
        end
    end
    local header = scenarioType == LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY and (TRACKER_HEADER_DUNGEON or L["Dungeon"]) or name
    return list, header, name
end

-- Forever has no Adventure Guide: bosses from the bundled game data (DungeonBosses.lua),
-- killed = from ENCOUNTER_END or the instance lock
local function DataBosses()
    local instanceID = select(8, GetInstanceInfo())
    local bosses = instanceID and ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[instanceID]
    if not bosses then return nil end
    local german = GetLocale() == "deDE"
    local list = {}
    for _, boss in ipairs(bosses) do
        local name = german and boss[3] or boss[2]
        local done = kills[boss[1]] or kills[boss[2]] or kills[boss[3]] or false
        list[#list + 1] = { text = L["%d/%d %s defeated"]:format(done and 1 or 0, 1, name), done = done }
    end
    return #list > 0 and list or nil
end

local function JournalBosses()
    if not (EJ_GetInstanceForMap and EJ_GetEncounterInfoByIndex) then return DataBosses() end
    local mapID = C_Map.GetBestMapForUnit("player")
    local journalID = mapID and EJ_GetInstanceForMap(mapID)
    -- Forever: the function exists but returns nothing -> bundled data
    if not journalID or journalID == 0 then return DataBosses() end
    local list = {}
    for i = 1, 30 do
        local name, _, _, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(i, journalID)
        if not name then break end
        local done = kills[dungeonEncounterID or 0] or kills[name] or false
        list[#list + 1] = { text = L["%d/%d %s defeated"]:format(done and 1 or 0, 1, name), done = done }
    end
    if #list == 0 then return DataBosses() end
    return list
end

local function ReadInstanceLock()
    for i = 1, 30 do
        local name, _, killed = GetInstanceLockTimeRemainingEncounter(i)
        if not name then break end
        if killed then kills[name] = true end
    end
end

-- Layout -----------------------------------------------------------------------------------------

-- Bottom limit for the tracker: screen edge, but in the melee DPS layout (16:9) above the focus frame
-- when it sits below the tracker
local FOCUS_GAP = 20
local function BottomLimit()
    local limit = (UIParent:GetBottom() or 0) + ns.SCREEN_MARGIN
    if not (ns.LayoutFlag and ns.LayoutFlag("questlogAboveFocus")) then return limit end
    local player, focus = ns.frames and ns.frames.player, ns.sideFrames and ns.sideFrames.focus
    local focusLeft = ns.RightOfTargetEdge and ns.RightOfTargetEdge()
    local left, right = anchor and anchor:GetLeft(), anchor and anchor:GetRight()
    if not (player and player:GetTop() and focus and focusLeft and left and right) then return limit end
    -- focus is top-aligned with the unit frames; only avoid it when it lies horizontally below the tracker
    if focusLeft < right and focusLeft + focus:GetWidth() > left then
        limit = math.max(limit, player:GetTop() + FOCUS_GAP)
    end
    return limit
end

-- Boss frames above the tracker (melee DPS layout): if visible boss frames overlap the tracker (16:9),
-- it moves below the lowest visible boss and shows only the instance's quests. On wide screens the
-- bosses sit beside it and nothing changes.
-- Returns how far the tracker moves down (0 = not at all).
local BOSS_GAP = 14
local BOSS_AURAS = 30 -- debuff row below each boss frame
local function BossShift()
    if not (ns.LayoutFlag and ns.LayoutFlag("questlogUnderBosses")) or not ns.sideFrames then return 0 end
    local holder = _G["MeredanUIBossAnchor"]
    local top, left, right = anchor:GetTop(), anchor:GetLeft(), anchor:GetRight()
    if not (holder and holder:GetLeft() and top and left) then return 0 end
    -- boss frames including the spell icon to their right (as tall as the bar)
    if holder:GetLeft() >= right or holder:GetRight() + 30 <= left then return 0 end
    local lowest
    for i = 1, 5 do
        local boss = ns.sideFrames["boss" .. i]
        if boss and boss:IsShown() and boss:GetBottom() then
            lowest = math.min(lowest or math.huge, boss:GetBottom() - BOSS_AURAS)
        end
    end
    if not lowest then return 0 end
    return math.max(top - lowest + BOSS_GAP, 0)
end

-- Height: at most 500, and never below the limit computed by BottomLimit
local MAX_HEIGHT = 500
local function MaxHeight(top)
    local screen = (top or tracker:GetTop() or UIParent:GetTop()) - BottomLimit()
    return math.min(MAX_HEIGHT, screen)
end

local function Layout()
    pending = false
    if not tracker then return end
    local UI = ns.UI
    hasTimers = false
    hasTargets, arrowRow = false, nil
    local y, h, r, b, z = 0, 0, 0, 0, 0
    local superTracked = C_SuperTrack.GetSuperTrackedQuestID()
    local items = {}
    -- boss frames above the tracker: move below them, instance quests only (see BossShift)
    local shift = BossShift()
    local bossMode = shift > 0
    tracker:ClearAllPoints()
    tracker:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, -shift)

    local function AddHeader(key, text, count, gap)
        h = h + 1
        local header = Header(h)
        header.key = key
        header.text:SetText(text)
        header.count:SetText(count or "")
        header.sign:SetTexture(ns.MEDIA .. "Icons\\" .. (Collapsed(key) and "Plus" or "Minus"))
        y = y + (gap and SECTION_GAP or 0)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -y)
        header:SetWidth(WIDTH)
        header:Show()
        header.y = y
        y = y + HEADER_H + 6
    end

    local function AddQuest(questID)
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = logIndex and C_QuestLog.GetInfo(logIndex)
        if not info then return end
        r = r + 1
        local row = Row(r)
        row.questID, row.recipeID = questID, nil
        local complete = C_QuestLog.IsComplete(questID) or C_QuestLog.ReadyForTurnIn(questID)
        local failed = C_QuestLog.IsFailed and C_QuestLog.IsFailed(questID)
        local color = ns.QuestColor(questID)
        local stripColor = failed and RED or { color.r, color.g, color.b }
        row.strip:SetColorTexture(stripColor[1], stripColor[2], stripColor[3], 1)
        if failed then
            row.tint:SetColorTexture(1, 0.31, 0.31, 0.06)
        elseif complete then
            row.tint:SetColorTexture(DONE[1], DONE[2], DONE[3], 0.07)
        elseif questID == superTracked then
            row.tint:SetColorTexture(1, 1, 1, 0.06)
        end
        row.tint:SetShown(failed or complete or questID == superTracked)
        row.sign:SetText(complete and "?" or "!")
        row.sign:SetTextColor(unpack(failed and RED or (complete and { 1, 0.82, 0 } or { 0.55, 0.55, 0.55 })))
        local tag = QuestTag(info)
        local level = Opt("trackerShowLevel") and ("|cff99978f[" .. (info.difficultyLevel or info.level or 0) .. "]|r ") or ""
        row.title:SetText(level .. (info.title or "")
            .. (tag and ("|cff99978f  · " .. tag .. "|r") or ""))
        if failed then
            row.title:SetTextColor(unpack(RED))
        elseif questID == superTracked then
            row.title:SetTextColor(1, 1, 1)
        else
            row.title:SetTextColor(color.r, color.g, color.b)
        end
        -- item on the right?
        local link, itemTexture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
        local hasItem = link and (not complete or showWhenComplete)
        local itemLogIndex, itemID = logIndex, nil
        -- Questie knows usable items Blizzard doesn't flag as quest items
        if not hasItem and QuestieOn("trackerQuestieItems") then
            for _, id in ipairs(ns.Questie.QuestItems(questID, complete) or {}) do
                local count = C_Item.GetItemCount(id) or 0
                if count > 0 then
                    itemID, itemLogIndex = id, nil
                    link, itemTexture, charges = "item:" .. id, C_Item.GetItemIconByID(id) or 134400, count
                    hasItem = true
                    break
                end
            end
        end
        local right = hasItem and (ICON_SIZE + 10) or 6
        row.item:SetShown(hasItem and true or false)
        if hasItem then
            row.item.icon:SetTexture(itemTexture)
            row.item.logIndex, row.item.itemID = itemLogIndex, itemID
            items[#items + 1] = { questID = questID, logIndex = itemLogIndex, itemID = itemID, link = link, texture = itemTexture, charges = charges }
        end
        row.title:SetWidth(WIDTH - 26 - right)
        local lines, percent, timer = QuestGoals(questID, logIndex, complete, failed)
        -- collapsed (per quest from the menu, or finished quests with the option): title only,
        -- finished ones keep their turn-in line
        local folded = QuestCollapsed(questID) or (complete and OptOn("trackerCollapseDone"))
        if folded then
            local keep = {}
            if complete and not QuestCollapsed(questID) then
                for _, line in ipairs(lines) do
                    if line:find(L["Turn in: %s"]:gsub("%%s.*", ""), 1, true) then keep[#keep + 1] = line end
                end
            end
            lines, percent = keep, nil
        end
        row.goals:SetWidth(WIDTH - 26 - right)
        row.goals:SetText(table.concat(lines, "\n"))
        row.goals:SetShown(#lines > 0)
        local height = 6 + row.title:GetStringHeight() + (#lines > 0 and (3 + row.goals:GetStringHeight()) or 0)
        row.timer:SetShown(timer ~= nil)
        row.timerIcon:SetShown(timer ~= nil)
        if timer then
            row.timer:ClearAllPoints()
            row.timer:SetPoint("TOPLEFT", 26 + 16, -(height + 3)) -- 12 px hourglass + 4 px gap before it
            row.timer:SetText(timer.text)
            row.timer:SetTextColor(unpack(timer.color))
            row.timerIcon:SetVertexColor(unpack(timer.color))
            height = height + 3 + row.timer:GetStringHeight()
        end
        row.bar:SetShown(percent ~= nil)
        if percent then
            row.bar:ClearAllPoints()
            row.bar:SetPoint("TOPLEFT", 26, -(height + 4))
            row.bar:SetWidth(WIDTH - 26 - right)
            row.bar:SetValue(percent)
            row.bar.text:SetText(math.floor(percent) .. " %")
            height = height + 4 + 12
        end
        row.dist.target, row.dist.complete = nil, complete
        if QuestieOn("trackerQuestieDistance") and not failed and not folded then
            row.dist.target = ns.Questie.Nearest(questID)
        end
        row.dist:SetShown(row.dist.target ~= nil)
        if row.dist.target then
            hasTargets = true
            row.dist:ClearAllPoints()
            row.dist:SetPoint("TOPLEFT", 26, -(height + 4))
            row.dist:SetWidth(WIDTH - 26 - right)
            UpdateDistance(row)
            height = height + 4 + 14
            if not arrowRow or questID == superTracked then arrowRow = row end
        end
        height = math.max(height + 7, hasItem and (ICON_SIZE + 12) or 0)
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(WIDTH)
        row:Show()
        y = y + height + ROW_GAP
    end

    local function AddRecipe(recipeID)
        local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
        if not schematic then return end
        r = r + 1
        local row = Row(r)
        row.questID, row.recipeID = nil, recipeID
        row.strip:SetColorTexture(DONE[1], DONE[2], DONE[3], 1)
        row.tint:Hide()
        row.sign:SetText("")
        row.bar:Hide()
        row.item:Hide()
        row.dist:Hide()
        row.dist.target = nil
        row.title:SetText(schematic.name or "")
        row.title:SetTextColor(unpack(UI.TEXT))
        row.title:SetWidth(WIDTH - 32)
        local lines = {}
        for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
            local reagent = slot.reagents and slot.reagents[1]
            local basic = not Enum.CraftingReagentType or slot.reagentType == Enum.CraftingReagentType.Basic
            if reagent and reagent.itemID and basic and slot.required ~= false then
                local need, have = slot.quantityRequired or 1, C_Item.GetItemCount(reagent.itemID, false) or 0
                local text = (C_Item.GetItemNameByID(reagent.itemID) or "?") .. ": " .. math.min(have, need) .. "/" .. need
                lines[#lines + 1] = have >= need and ("|cff8ecbb4" .. text .. "|r") or text
            end
        end
        row.goals:SetWidth(WIDTH - 32)
        row.goals:SetText(table.concat(lines, "\n"))
        row.goals:SetShown(#lines > 0)
        local height = 6 + row.title:GetStringHeight() + (#lines > 0 and (3 + row.goals:GetStringHeight()) or 0) + 7
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(WIDTH)
        row:Show()
        y = y + height + ROW_GAP
    end

    -- 1) Instance
    local inInstance, instanceType = IsInInstance()
    local instanceName = inInstance and GetInstanceInfo() or nil
    local instanceQuests, inDungeonSection = {}, {}
    local zoneName
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        for index = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(index)
            if info and info.isHeader then
                zoneName = info.title
            -- header may read "The Deadmines" while the instance is "Deadmines": substring match suffices
            elseif info and zoneName and instanceName and (zoneName == instanceName or zoneName:find(instanceName, 1, true)
                or instanceName:find(zoneName, 1, true)) and not info.isHidden and info.questID and info.questID > 0 then
                instanceQuests[#instanceQuests + 1] = info.questID
                inDungeonSection[info.questID] = true
            end
        end
        local bosses, header, name = ScenarioBosses()
        if not bosses or #bosses == 0 then
            bosses, header, name = JournalBosses(), TRACKER_HEADER_DUNGEON or L["Dungeon"], instanceName
        end
        if instanceType == "raid" and header == (TRACKER_HEADER_DUNGEON or L["Dungeon"]) then header = L["Raid"] end
        AddHeader("dungeon", header or instanceName or "", nil, false)
        if bossMode then
            -- during boss fights only the instance quests (boss list and name need space)
            if instanceBlock then instanceBlock:Hide() end
            for _, questID in ipairs(instanceQuests) do AddQuest(questID) end
        elseif not Collapsed("dungeon") then
            local block = InstanceBlock()
            block.text:SetText(name or instanceName or "")
            block:ClearAllPoints()
            block:SetPoint("TOPLEFT", 0, -y)
            block:SetWidth(WIDTH)
            block:Show()
            y = y + 34 + 6
            for _, boss in ipairs(bosses or {}) do
                b = b + 1
                local line = BossLine(b)
                line.text:SetText(boss.text)
                line.text:SetTextColor(unpack(boss.done and DONE or UI.TEXT))
                line.check:SetShown(boss.done)
                line.dot:SetShown(not boss.done)
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", 0, -y)
                line:SetWidth(WIDTH)
                line:Show()
                y = y + 20
            end
            if #instanceQuests > 0 then y = y + 6 end
            for _, questID in ipairs(instanceQuests) do AddQuest(questID) end
        elseif instanceBlock then
            instanceBlock:Hide()
        end
    elseif instanceBlock then
        instanceBlock:Hide()
    end

    -- 2) Tracked quests
    local watched = {}
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID and not inDungeonSection[questID] then watched[#watched + 1] = questID end
    end
    -- Order (Settings > Quests): focus quest always first. "Standard": quests in the current zone,
    -- then the rest, each in the usual order (no jumping while moving); level / progress / distance
    -- (Questie) sort the rest.
    local mode = ns.db.trackerSort or "standard"
    if mode == "distance" and not (ns.Questie and ns.Questie.IsReady()) then mode = "standard" end
    local rank, order, key = {}, {}, {}
    for i, questID in ipairs(watched) do
        order[questID] = i
        rank[questID] = questID == superTracked and 0 or (mode ~= "standard" and 1 or (C_QuestLog.IsOnMap(questID) and 1 or 2))
        if mode == "level" then
            local info = C_QuestLog.GetInfo(C_QuestLog.GetLogIndexForQuestID(questID) or 0)
            key[questID] = info and (info.difficultyLevel or info.level) or 0
        elseif mode == "progress" then
            key[questID] = -Progress(questID)
        elseif mode == "distance" then
            local target = ns.Questie.Nearest(questID)
            key[questID] = target and target.yards or math.huge
        end
    end
    table.sort(watched, function(a, b)
        if rank[a] ~= rank[b] then return rank[a] < rank[b] end
        if key[a] and key[b] and key[a] ~= key[b] then return key[a] < key[b] end
        return order[a] < order[b]
    end)
    -- Bosses above the tracker: inside instances only their quests (on top); outside (world boss,
    -- preview) only quests of the current zone
    if bossMode then
        if inInstance then
            wipe(watched)
        else
            for i = #watched, 1, -1 do
                if watched[i] ~= superTracked and not C_QuestLog.IsOnMap(watched[i]) then table.remove(watched, i) end
            end
        end
    end
    if #watched > 0 then
        local numQuests = 0
        for index = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(index)
            if info and not info.isHeader and not info.isHidden and not info.isTask then numQuests = numQuests + 1 end
        end
        AddHeader("quests", L["Quests"], numQuests .. "/" .. C_QuestLog.GetMaxNumQuestsCanAccept(), h > 0)
        if not Collapsed("quests") then
            if OptOn("trackerGroupZone") then
                -- zone = the quest log header above the quest; groups in order of their first quest
                local zoneOf, current = {}, nil
                for index = 1, C_QuestLog.GetNumQuestLogEntries() do
                    local info = C_QuestLog.GetInfo(index)
                    if info and info.isHeader then current = info.title
                    elseif info and info.questID then zoneOf[info.questID] = current end
                end
                local groups, byName = {}, {}
                for _, questID in ipairs(watched) do
                    local name = zoneOf[questID] or L["Other"]
                    if not byName[name] then
                        byName[name] = { name = name }
                        groups[#groups + 1] = byName[name]
                    end
                    table.insert(byName[name], questID)
                end
                for _, group in ipairs(groups) do
                    z = z + 1
                    local label = ZoneLabel(z)
                    label.text:SetText(group.name)
                    label:ClearAllPoints()
                    label:SetPoint("TOPLEFT", 0, -y)
                    label:SetWidth(WIDTH)
                    label:Show()
                    y = y + 18 + 2
                    for _, questID in ipairs(group) do AddQuest(questID) end
                    y = y + 4
                end
            else
                for _, questID in ipairs(watched) do AddQuest(questID) end
            end
        end
    end

    -- 3) Tracked recipes
    local recipes = C_TradeSkillUI.GetRecipesTracked and C_TradeSkillUI.GetRecipesTracked(false) or {}
    if #recipes > 0 and not bossMode then
        AddHeader("recipes", L["Professions"], nil, h > 0)
        if not Collapsed("recipes") then
            for _, recipeID in ipairs(recipes) do AddRecipe(recipeID) end
        end
    end

    -- hide the rest
    for i = h + 1, #headers do headers[i]:Hide() end
    for i = r + 1, #rows do rows[i]:Hide() end
    for i = b + 1, #bossLines do bossLines[i]:Hide() end
    for i = z + 1, #zoneLabels do zoneLabels[i]:Hide() end
    if b == 0 and instanceBlock and not inInstance then instanceBlock:Hide() end
    -- taller than allowed: scroll (mouse wheel, out of combat only)
    content:SetHeight(math.max(y, 1))
    tracker:SetHeight(math.max(math.min(y, MaxHeight((anchor:GetTop() or UIParent:GetTop()) - shift)), 1))
    tracker.UpdateScroll()
    tracker:SetShown(h > 0 and not bossHidden)

    UpdateArrow(true)
    lastItems = items
    hasItems = #items > 1
    PickBarItems(true)
end
Layout = ns.PerfProbe("Tracker: layout", Layout)

-- Batched: quest/bag events come in bursts (kills, loot), one rebuild per 0.2 s is enough
local function Refresh()
    if pending or not tracker then return end
    pending = true
    C_Timer.After(0.2, Layout)
end

-- Position: right edge left of the inner right bar, top edge level with that bar (at most below the buffs)
local function PlaceAnchorDefault()
    local margin, gap = ns.Snap(ns.SCREEN_MARGIN), ns.Snap(GAP)
    local right = UIParent:GetRight() - margin
    -- innermost visible right bar (with bar 6 the tracker moves further left)
    local bar = ns.InnermostRightBar and ns.InnermostRightBar() or (ns.layoutFrames and ns.layoutFrames.bar5)
    if bar and bar:IsVisible() and bar:GetLeft() then right = bar:GetLeft() - ns.Snap(SIDE_GAP) end
    local top = UIParent:GetTop() - margin
    local auraBottom = ns.AuraStackBottom and ns.AuraStackBottom()
    local minimap = _G["MeredanUIMinimap"]
    if auraBottom then
        top = auraBottom - gap
    elseif minimap and minimap:GetBottom() then
        top = minimap:GetBottom() - gap
    end
    -- top edge flush with the right action bars, but never above the buffs/minimap
    if bar and bar:GetTop() then top = math.min(top, bar:GetTop()) end
    local cx, cy = UIParent:GetCenter()
    ns.PlaceFromCenter(anchor, "TOPRIGHT", right - cx, top - cy)
end

-- Bosses and arenas: hide (instances only - Forever reports boss units outdoors too).
-- A secure state driver detects boss/arena units; it hides the item layer itself (works in combat),
-- the tracker via a parentless watcher (Alt+Z, videos and cinematics hide UIParent - that must not
-- count as a boss fight).
local BOSS_STATE = "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists]"
    .. "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists][@boss5,exists] 1;0"
-- ininstance: bosses hide the tracker (in instances; not in the melee DPS layout - there it moves
-- below the boss frames). inraid: always hidden in raids (for future layouts).
local BOSS_SNIPPET = "if (newstate == 1 and self:GetAttribute('ininstance')) or self:GetAttribute('inraid') then self:Hide() else self:Show() end"
local watcher

local function SetupBossHiding()
    watcher = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
    watcher:SetAttribute("_onstate-muiboss", BOSS_SNIPPET)
    watcher:SetScript("OnHide", function() bossHidden = true; tracker:Hide() end)
    watcher:SetScript("OnShow", function() bossHidden = false; Refresh() end)
    RegisterStateDriver(watcher, "muiboss", BOSS_STATE)
    itemLayer:SetAttribute("_onstate-muiboss", BOSS_SNIPPET)
    RegisterStateDriver(itemLayer, "muiboss", BOSS_STATE)
end

local function UpdateInstanceFlag()
    if InCombatLockdown() then return ns.AfterCombat(UpdateInstanceFlag) end
    local isInstance, instanceType = IsInInstance()
    local flag = ns.LayoutFlag or function() return false end
    local hideWithBosses = (isInstance and not flag("questlogUnderBosses")) and true or false
    local inRaid = (flag("questlogHideInRaid") and instanceType == "raid") and true or false
    for _, frame in pairs({ watcher or false, itemLayer or false }) do if frame then
        frame:SetAttribute("ininstance", hideWithBosses)
        frame:SetAttribute("inraid", inRaid)
        -- re-evaluate the state: setting the same value again re-runs _onstate-muiboss
        frame:SetAttribute("state-muiboss", frame:GetAttribute("state-muiboss"))
    end end
end
ns.UpdateQuestlogHiding = function() if watcher then UpdateInstanceFlag() end end

local function Setup()
    -- park Blizzard's tracker (events keep running)
    local hidden = CreateFrame("Frame")
    hidden:Hide()
    -- (it contains Blizzard's secure item buttons: reparent only out of combat)
    local function Park()
        if ObjectiveTrackerFrame:GetParent() ~= hidden then ObjectiveTrackerFrame:SetParent(hidden) end
    end
    if ObjectiveTrackerFrame then
        -- reload in combat: reparent afterwards, but hide right away (alpha is allowed)
        ObjectiveTrackerFrame:SetAlpha(0)
        ns.AfterCombat(Park)
        hooksecurefunc(ObjectiveTrackerFrame, "SetParent", function(_, parent)
            if parent ~= hidden then ns.AfterCombat(Park) end
        end)
    end

    anchor = CreateFrame("Frame", "MeredanUIQuestAnchor", UIParent)
    anchor:SetSize(WIDTH, 200)
    tracker = CreateFrame("Frame", "MeredanUITracker", UIParent)
    tracker:SetWidth(WIDTH)
    tracker:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
    tracker:SetFrameStrata("LOW")
    tracker.Refresh = Refresh
    scroll = CreateFrame("ScrollFrame", nil, tracker)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT")
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH, 1)
    scroll:SetScrollChild(content)
    -- thin scrollbar on the right, only when scrollable
    thumb = tracker:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.3)
    thumb:SetWidth(2)
    thumb:Hide()
    -- tracker.offset = scroll position. Above 0 the sticky header shows at the top and the scroll area
    -- starts below it (rows vanish under its line, no box behind)
    tracker.offset = 0
    function tracker.UpdateScroll()
        local range = math.max(content:GetHeight() - tracker:GetHeight(), 0)
        local offset = math.min(tracker.offset, range)
        tracker.offset = offset
        local top = offset > 0 and STICKY_H or 0
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, -top)
        scroll:SetPoint("BOTTOMRIGHT")
        scroll:SetVerticalScroll(offset + top)
        thumb:SetShown(range > 0)
        UpdateSticky(offset)
        if range > 0 then
            local visible = tracker:GetHeight()
            local size = math.max(visible * visible / content:GetHeight(), 20)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 3, -(visible - size) * offset / range)
            thumb:SetHeight(size)
        end
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        tracker.offset = math.max(tracker.offset - delta * 40, 0)
        tracker.UpdateScroll()
    end)

    itemLayer = CreateFrame("Frame", "MeredanUITrackerItems", UIParent, "SecureHandlerStateTemplate")
    itemLayer:SetSize(ACTIVE_SIZE, 10)
    -- not parented to the tracker: it would become protected too and couldn't change its height in
    -- combat. The placeholder sits at the same corner and only moves out of combat.
    itemLayer:SetFrameStrata("MEDIUM")
    -- Anchored to the screen, not the (unprotected) tracker: otherwise the state driver lost access after
    -- the tracker was moved ("Invalid 'self' frame handle"). Position is synced out of combat.
    local function SyncItemLayer()
        if InCombatLockdown() then return ns.AfterCombat(SyncItemLayer) end
        local left, top = anchor:GetLeft(), anchor:GetTop()
        if not (left and top) then return end
        itemLayer:ClearAllPoints()
        itemLayer:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left - 12, top)
    end
    SyncItemLayer()

    hooksecurefunc(anchor, "SetPoint", function() C_Timer.After(0, function() SyncItemLayer() Refresh() end) end)
    ns.OnLayout(PlaceAnchorDefault)
    ns.layoutFrames.questlog = anchor
    if ns.PlaceBossFrames then ns.PlaceBossFrames() end -- boss frames to the left of it
    ns.ClampQuestlogHeight = Refresh
    if ns.TestMode then
        hooksecurefunc(ns.TestMode, "Start", Refresh)
        hooksecurefunc(ns.TestMode, "Stop", Refresh)
    end
    -- boss frames come and go (also in combat): tracker follows
    C_Timer.After(1, function()
        for i = 1, 5 do
            local boss = ns.sideFrames and ns.sideFrames["boss" .. i]
            if boss then
                boss:HookScript("OnShow", Refresh)
                boss:HookScript("OnHide", Refresh)
            end
        end
    end)

    tracker:SetScript("OnUpdate", function(self, elapsed)
        -- Questie distances: text every second, arrow ~20x per second (facing changes quickly)
        if hasTargets and self:IsVisible() then
            self.arrowElapsed = (self.arrowElapsed or 0) + elapsed
            if self.arrowElapsed >= 0.05 then
                self.distElapsed = (self.distElapsed or 0) + self.arrowElapsed
                self.arrowElapsed = 0
                -- one row per 0.5 s in turn (spreads Questie's spawn search), not in combat,
                -- and only when you moved since that row was last computed
                if self.distElapsed >= 0.5 and not InCombatLockdown() and not IsInInstance() then
                    self.distElapsed = 0
                    UpdateNextDistance()
                end
                UpdateArrow()
            end
        end
        if not (hasTimers or (hasItems and not InCombatLockdown())) then return end
        self.timerElapsed = (self.timerElapsed or 0) + elapsed
        if self.timerElapsed < (hasTimers and 1 or 2) then return end
        self.timerElapsed = 0
        if hasTimers then Refresh() else PickBarItems(false) end
    end)

    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "QUEST_ACCEPTED",
        "QUEST_REMOVED", "QUEST_TURNED_IN", "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "TRACKED_RECIPE_UPDATE",
        "ZONE_CHANGED_NEW_AREA" }) do
        ns:On(event, Refresh)
    end
    -- Loot fires this constantly: only rebuild when bag contents are shown (quest items, recipe
    -- reagents) or Questie may know items for tracked quests
    ns:On("BAG_UPDATE_DELAYED", function()
        if #lastItems > 0 or QuestieOn("trackerQuestieItems")
            or (C_TradeSkillUI.GetRecipesTracked and #(C_TradeSkillUI.GetRecipesTracked(false) or {}) > 0) then
            Refresh()
        end
    end)
    -- Questie: turn-in NPC, distances and database items once it is ready and on its quest updates
    if ns.Questie and ns.Questie.IsLoaded() then ns.Questie.OnQuestUpdate(Refresh) end
    ns:On("BAG_UPDATE_COOLDOWN", UpdateCooldowns)
    ns:On("UPDATE_BINDINGS", UpdateHotkey)
    ns:On("ENCOUNTER_END", function(_, encounterID, name, _, _, success)
        if success == 1 then
            kills[encounterID] = true
            if name then kills[name] = true end
            if ns.char then
                local saved = ns.char.trackerKills
                local instanceID = select(8, GetInstanceInfo())
                killsInstance = killsInstance or instanceID
                if not saved or saved.instance ~= instanceID then
                    saved = { instance = instanceID, kills = {} }
                    ns.char.trackerKills = saved
                end
                saved.kills[encounterID] = true
                if name then saved.kills[name] = true end
            end
            Refresh()
        end
    end)
    -- Also runs once directly during setup: the tracker starts after PLAYER_ENTERING_WORLD (otherwise the
    -- instance ID was missing and saved kills didn't match after /reload)
    local function OnEnterWorld()
        local inInstance, instanceType = IsInInstance()
        local instanceID = select(8, GetInstanceInfo())
        if instanceID ~= killsInstance then
            wipe(kills)
            killsInstance = instanceID
            -- kills survive /reload and disconnects: saved per character, only for the same instance while
            -- inside; cleared once outside
            local saved = ns.char and ns.char.trackerKills
            if saved and inInstance and saved.instance == instanceID then
                for key in pairs(saved.kills or {}) do kills[key] = true end
            elseif ns.char and not inInstance then
                ns.char.trackerKills = nil
            end
        end
        ReadInstanceLock()
        -- in dungeons/raids collapse the other quests, outside restore the saved setting
        instanceCollapse = (inInstance and (instanceType == "party" or instanceType == "raid")) and true or nil
        ns.AfterCombat(UpdateInstanceFlag)
        Refresh()
    end
    ns:On("PLAYER_ENTERING_WORLD", OnEnterWorld)
    OnEnterWorld()
    -- "Collapse in combat": quests fold while fighting, back afterwards
    ns:On("PLAYER_REGEN_DISABLED", function()
        if OptOn("trackerCombatCollapse") then combatCollapse = true; Refresh() end
    end)
    ns:On("PLAYER_REGEN_ENABLED", function()
        if combatCollapse then combatCollapse = false; Refresh() end
    end)
    ns.RefreshTracker = Refresh
    ns.AfterCombat(SetupBossHiding) -- state drivers can't be set up in combat
    ns.AfterCombat(UpdateInstanceFlag)
    Refresh()
end

-- after buffs and action bars (they set up on login)
ns:On("PLAYER_LOGIN", function() C_Timer.After(0.2, Setup) end)
