-- Gespräch (WoW Forever): eigenes Fenster statt Blizzards Gesprächsfenster – Begrüßung, Quests und
-- Gesprächsoptionen (Entwurf).
--
--   ┌ [Modell] Zarrin                                 [x] ┐
--   │          Kochlehrerin                               │
--   │ Hallo, Koratal. Wenn Ihr das eine oder andere …      │
--   │ Quests                                               │
--   │ [! Gewürzte Wolfsflanken                  Stufe 9]   │
--   │ Gespräch                                             │
--   │ [▣ Ich würde gern Kochunterricht bekommen.     ›]    │
--   │                                       [Lebt wohl]    │
--   └──────────────────────────────────────────────────────┘
--
-- Zwei Quellen: GOSSIP_SHOW (C_GossipInfo) und QUEST_GREETING (NPCs nur mit Quests, alte API).
-- Blizzard entscheidet weiter, ob sein Fenster aufgeht (z. B. wählt es eine einzige Option selbst):
-- unser Fenster kommt nur, wenn Blizzards Fenster danach offen ist (IsShown – es ist unsichtbar
-- geparkt). Schließen beendet das Gespräch (macht sonst Blizzards OnHide).
local _, ns = ...
local L = ns.L

local WIDTH, PAD = 520, 18
local ROW_H, ROW_GAP = 40, 6

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, greeting
local rows, headers = {}, {}
local source -- "gossip" oder "greeting"

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.gossipWindow ~= false
end

-- Inhalt -----------------------------------------------------------------------------------------

local function QuestRow(info, active)
    -- „!“ neue Quest, „?“ gelb abgabebereit, „?“ grau noch nicht fertig
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
        -- wie Blizzards Begrüßung: Titel/Status je Index, Stufe über die Quest-ID
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

-- Zeilen -----------------------------------------------------------------------------------------

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
    local header = ns.UI.Text(list.child, 12, "LEFT", ns.UI.ACCENT)
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

-- Fenster ----------------------------------------------------------------------------------------

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIGossip", WIDTH, ns.NPC_HEIGHT, "gossip")
    window.replaceable = true -- Quest/Händler/Lehrer ersetzen das Gespräch: kein Platz neben ihm
    ns.WatchBlizzardFrame(window, function() return source == "greeting" and QuestFrame or GossipFrame end)
    -- ein Pergament für den ganzen Inhalt (wie im Quest-Fenster)
    local paper = ns.CreateParchmentPanel(window)
    paper:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 22)
    paper:SetPoint("BOTTOMRIGHT", -PAD, 56)
    list = UI.ScrollArea(paper)
    -- mehr Luft rundum auf dem Pergament (Benny 2026-11-06)
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
        -- nur die eigene, noch laufende Unterhaltung beenden (sonst träfe es den nächsten NPC)
        if source == "greeting" then
            if ns.StillInteracting("QuestGiver", QuestFrame) then CloseQuest() end
        elseif ns.StillInteracting("Gossip", GossipFrame) then
            C_GossipInfo.CloseGossip()
        end
    end)
end

-- Blizzards Fenster nur zeigen lassen, wenn es wirklich aufgeht; dann unser Fenster
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
    -- unsichtbar parken: Blizzard prüft nur IsShown, OnShow/OnHide feuern unsichtbar nicht
    GossipFrame:SetParent(hidden)
    ns:On("GOSSIP_SHOW", function() ShowFor("gossip", GossipFrame, "npc") end)
    ns:On("GOSSIP_CLOSED", function() if source == "gossip" then window:Hide() end end)
    ns:On("QUEST_LOG_UPDATE", function() if window:IsShown() then Layout() end end)
    -- NPCs nur mit Quests begrüßen über Blizzards Quest-Fenster (Begrüßung) – das parkt NPC/Quest.lua
    ns:On("QUEST_GREETING", function() ShowFor("greeting", QuestFrame, "questnpc") end)
    ns:On("QUEST_FINISHED", function() if source == "greeting" and window:IsShown() then window:Hide() end end)
    for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
        -- Quest gewählt: Begrüßung zu, ohne die Quest-Unterhaltung zu beenden
        ns:On(event, function()
            if source == "greeting" and window:IsShown() then
                source = nil
                window:Hide()
            end
        end)
    end
end)

ns.GossipWindowEnabled = Enabled
