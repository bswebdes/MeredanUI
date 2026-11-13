-- Gossip window (WoW Forever): replaces Blizzard's gossip frame - greeting, quests and dialog options.
-- Two sources: GOSSIP_SHOW (C_GossipInfo) and QUEST_GREETING (quest-only NPCs, legacy API).
-- Blizzard still decides whether its frame opens (it may auto-pick a single option); we only show
-- when its hidden-parked frame IsShown afterwards. Closing ours ends the conversation.
local _, ns = ...
local L = ns.L

local WIDTH, PAD = 520, 18
local ROW_H, ROW_GAP = 40, 6

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, greeting
local rows, headers = {}, {}
local source -- "gossip" or "greeting"
local serverClosed = false -- GOSSIP_CLOSED hid the window: the game ended the gossip already

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.gossipWindow ~= false
end

-- Content -----------------------------------------------------------------------------------------

local function QuestRow(info, active)
    -- "!" new quest, yellow "?" ready to turn in, grey "?" not complete yet
    local complete = info.isComplete
    local sign = active and "?" or "!"
    local color = (active and not complete) and { 0.55, 0.55, 0.55 } or { 1, 0.82, 0 }
    local level = info.questLevel and info.questLevel > 0 and L["Level %d"]:format(info.questLevel) or ""
    return { sign = sign, signColor = color, text = info.title or "", level = level,
        muted = (active and not complete) or info.isTrivial, onClick = info.onClick }
end

local function Collect()
    local quests, options = {}, {}
    local text
    if source == "greeting" then
        text = GetGreetingText()
        -- Like Blizzard's greeting: title/status per index, level via quest ID
        local function Level(questID)
            return questID and C_QuestLog.GetQuestDifficultyLevel and C_QuestLog.GetQuestDifficultyLevel(questID)
        end
        for i = 1, GetNumActiveQuests() do
            local title, complete = GetActiveTitle(i)
            quests[#quests + 1] = QuestRow({ title = title, questLevel = Level(GetActiveQuestID and GetActiveQuestID(i)),
                isComplete = complete, isTrivial = IsActiveQuestTrivial and IsActiveQuestTrivial(i),
                onClick = function() SelectActiveQuest(i) end }, true)
        end
        for i = 1, GetNumAvailableQuests() do
            local trivial, _, _, _, questID = GetAvailableQuestInfo(i)
            quests[#quests + 1] = QuestRow({ title = GetAvailableTitle(i), questLevel = Level(questID),
                isTrivial = trivial, onClick = function() SelectAvailableQuest(i) end }, false)
        end
    else
        text = C_GossipInfo.GetText()
        for _, info in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            local questID = info.questID
            info.onClick = function() C_GossipInfo.SelectActiveQuest(questID) end
            quests[#quests + 1] = QuestRow(info, true)
        end
        for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            local questID = info.questID
            info.onClick = function() C_GossipInfo.SelectAvailableQuest(questID) end
            quests[#quests + 1] = QuestRow(info, false)
        end
        local list = C_GossipInfo.GetOptions() or {}
        table.sort(list, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
        for _, option in ipairs(list) do
            local index = option.orderIndex
            options[#options + 1] = { text = option.name or "", icon = option.overrideIconID or option.icon,
                onClick = function() C_GossipInfo.SelectOptionByIndex(index) end }
        end
    end
    return text or "", quests, options
end

-- Rows -------------------------------------------------------------------------------------------

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(ROW_H)
    row.bg = UI.Box(row, ns.PARCHMENT_CARD)
    row.sign = UI.Text(row, 17, "CENTER")
    row.sign:SetPoint("LEFT", 10, 0)
    row.sign:SetWidth(20)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(20, 20)
    holder:SetPoint("LEFT", 10, 0)
    ns.AddBorder(holder)
    row.iconHolder = holder
    row.icon = holder:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.right = UI.Text(row, 11, "RIGHT", UI.MUTED)
    row.right:SetPoint("RIGHT", -12, 0)
    row.arrow = UI.Icon(row, "ChevronDown", 10, UI.MUTED)
    row.arrow:SetPoint("RIGHT", -12, 0)
    row.arrow:SetRotation(math.pi / 2)
    row.text = UI.Text(row, 13, "LEFT")
    row.text:SetPoint("LEFT", 42, 0)
    row.text:SetPoint("RIGHT", row.right, "LEFT", -10, 0)
    row:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD_HOVER)) end)
    row:SetScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD)) end)
    row:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
        if self.onClick then self.onClick() end
    end)
    rows[i] = row
    return row
end

local function Header(i)
    if headers[i] then return headers[i] end
    local header = ns.UI.Heading(list.child, 12, "LEFT")
    headers[i] = header
    return header
end

local function Layout()
    if not (window and window:IsShown()) then return end
    local UI = ns.UI
    local text, quests, options = Collect()
    local width = list:GetWidth()
    greeting:SetWidth(width)
    greeting:SetText(text)
    greeting:SetShown(text ~= "")
    local y = text ~= "" and (greeting:GetStringHeight() + 18) or 0
    local r, h = 0, 0
    local function Section(title, entries, isQuest)
        if #entries == 0 then return end
        h = h + 1
        local header = Header(h)
        header:SetText(title)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -y)
        header:Show()
        y = y + 20
        for _, entry in ipairs(entries) do
            r = r + 1
            local row = Row(r)
            row.onClick = entry.onClick
            row.sign:SetShown(isQuest)
            row.iconHolder:SetShown(not isQuest)
            row.arrow:SetShown(not isQuest)
            row.right:SetShown(isQuest)
            if isQuest then
                row.sign:SetText(entry.sign)
                row.sign:SetTextColor(unpack(entry.signColor))
                row.right:SetText(entry.level)
            else
                row.icon:SetTexture(entry.icon or 132053)
            end
            row.text:SetText(entry.text)
            row.text:SetTextColor(unpack(entry.muted and UI.MUTED or UI.TEXT))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", list.child, "RIGHT")
            row:Show()
            y = y + ROW_H + ROW_GAP
        end
        y = y + 12
    end
    Section(L["Quests"], quests, true)
    Section(L["Conversation"], options, false)
    for i = r + 1, #rows do rows[i]:Hide() end
    for i = h + 1, #headers do headers[i]:Hide() end
    list:SetContentHeight(y)
end

-- Window ----------------------------------------------------------------------------------------

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIGossip", WIDTH, ns.NPC_HEIGHT, "gossip")
    window.replaceable = true -- quest/merchant/trainer windows replace gossip instead of docking beside it
    ns.WatchBlizzardFrame(window, function() return source == "greeting" and QuestFrame or GossipFrame end)
    -- One parchment for all content (like the quest window)
    local paper = ns.CreateParchmentPanel(window)
    paper:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 22)
    paper:SetPoint("BOTTOMRIGHT", -PAD, 56)
    list = UI.ScrollArea(paper)
    list:SetPoint("TOPLEFT", 34, -30)
    list:SetPoint("BOTTOMRIGHT", -40, 28)
    greeting = UI.Text(list.child, 14, "LEFT", ns.PARCHMENT_TEXT)
    greeting:SetPoint("TOPLEFT")
    greeting:SetWordWrap(true)
    greeting:SetSpacing(4)
    local goodbye = UI.Button(window, GOODBYE or "Goodbye", function() window:Hide() end, 110)
    goodbye:SetHeight(30)
    goodbye:SetPoint("BOTTOMRIGHT", -PAD, 16)
    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
        list:ScrollToTop()
        Layout()
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
        -- The game already closed the gossip (an option opened the bank, a vendor ...): ending the
        -- interaction now would close that next window right away
        if serverClosed then
            serverClosed = false
            return
        end
        -- Only end our own, still running interaction (otherwise it would hit the next NPC)
        if source == "greeting" then
            if ns.StillInteracting("QuestGiver", QuestFrame) then CloseQuest() end
        elseif ns.StillInteracting("Gossip", GossipFrame) then
            C_GossipInfo.CloseGossip()
        end
    end)
end

-- Show ours only if Blizzard's frame actually opened (checked one frame later)
local function ShowFor(kind, blizzard, unit)
    C_Timer.After(0, function()
        if not (blizzard and blizzard:IsShown()) then return end
        source = kind
        window:SetNpc(unit)
        if window:IsShown() then Layout() else window:Show() end
    end)
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not GossipFrame then return end
    CreateWindow()
    -- Park invisibly: Blizzard only checks IsShown, and OnShow/OnHide do not fire while parked
    GossipFrame:SetParent(hidden)
    ns:On("GOSSIP_SHOW", function() ShowFor("gossip", GossipFrame, "npc") end)
    ns:On("GOSSIP_CLOSED", function()
        if source == "gossip" and window:IsShown() then
            serverClosed = true
            window:Hide()
        end
    end)
    ns.OnQuestsChanged(function() if window:IsShown() then Layout() end end)
    -- Quest-only NPCs greet via Blizzard's QuestFrame, which NPC/Quest.lua parks
    ns:On("QUEST_GREETING", function() ShowFor("greeting", QuestFrame, "questnpc") end)
    ns:On("QUEST_FINISHED", function() if source == "greeting" and window:IsShown() then window:Hide() end end)
    for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
        -- Quest picked: close the greeting without ending the quest interaction
        ns:On(event, function()
            if source == "greeting" and window:IsShown() then
                source = nil
                window:Hide()
            end
        end)
    end
end)

ns.GossipWindowEnabled = Enabled
