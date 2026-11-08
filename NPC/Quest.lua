-- Quest (WoW Forever): eigenes Fenster statt Blizzards Quest-Fenster – Annehmen, Fortschritt und
-- Belohnung (Entwurf).
--
--   ┌ [Modell] Zarrin · Stufe 9                       [x] ┐
--   │          Gewürzte Wolfsflanken  (Gold)               │
--   │ Questtext …                                          │
--   │ Ziele          · Wolfsflanke                         │
--   │ Wähle eine Belohnung  [▣ Stiefel] [▣ Handschuhe]     │  ← Auswahl mit Surf-Green-Rahmen
--   │ Außerdem  420 EP  35s                                │
--   │                              [Ablehnen] [Annehmen]   │
--   └──────────────────────────────────────────────────────┘
--
-- Blizzards Quest-Fenster bleibt unsichtbar geparkt und entscheidet weiter, WANN es aufgeht (Quests
-- von Items/Gebieten nur als Popup usw.) – unser Fenster folgt nur, wenn es offen ist. Die Begrüßung
-- (QUEST_GREETING) zeigt NPC/Gossip.lua. Schließen beendet die Quest-Unterhaltung (CloseQuest).
local _, ns = ...
local L = ns.L

local WIDTH, PAD = 520, 18
local CARD_H, CARD_GAP = 52, 8

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, body, objHeader, objText, rewardHeader, extraLine, footerNote
local primary, secondary
local cards = {}
local mode       -- "detail", "progress", "complete"
local choice     -- gewählte Belohnung (Index)

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.questWindow ~= false
end

local function QualityColor(quality)
    if quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

-- Belohnungs-Karten -------------------------------------------------------------------------------

local function Card(i)
    if cards[i] then return cards[i] end
    local UI = ns.UI
    local card = CreateFrame("Button", nil, list.child)
    card:SetHeight(CARD_H)
    card.bg = UI.Box(card, ns.PARCHMENT_CARD)
    card.pick = ns.AddBorder(card, true)
    for _, edge in ipairs(card.pick) do
        edge:SetVertexColor(unpack(UI.ACCENT))
        edge:Hide()
    end
    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(38, 38)
    holder:SetPoint("LEFT", 7, 0)
    ns.AddSlotBackground(holder)
    card.border = ns.AddBorder(holder)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = ns.CreateText(holder, 11, "RIGHT", "OUTLINE")
    card.count:SetPoint("BOTTOMRIGHT", -2, 2)
    card.name = UI.Text(card, 13, "LEFT")
    card.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -3)
    card.name:SetPoint("RIGHT", -8, 0)
    card.sub = UI.Text(card, 11, "LEFT", UI.MUTED)
    card.sub:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", 10, 3)
    card.sub:SetPoint("RIGHT", -8, 0)
    card:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD_HOVER))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetQuestItem(self.kind, self.index)
        ns.ShowItemCompare(GameTooltip)
        GameTooltip:Show()
        self.UpdateTooltip = self:GetScript("OnEnter") -- Shift während der Maus drauf ist
    end)
    card:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD))
        GameTooltip:Hide()
    end)
    card:SetScript("OnClick", function(self)
        if HandleModifiedItemClick(GetQuestItemLink(self.kind, self.index)) then return end
        if self.kind == "choice" then
            choice = self.index
            window.Layout()
        end
    end)
    cards[i] = card
    return card
end

local function SubLine(link, count)
    local parts = {}
    if link then
        local _, itemType, subType, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
        if classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
            if subType and subType ~= "" then parts[#parts + 1] = subType end
            local slot = equipLoc and equipLoc ~= "" and _G[equipLoc]
            if slot and slot ~= subType then parts[#parts + 1] = slot end
        elseif itemType then
            parts[#parts + 1] = itemType
        end
    end
    if count and count > 1 then parts[#parts + 1] = L["%d per purchase"]:format(count) end
    return table.concat(parts, " · ")
end

-- Aufbau -----------------------------------------------------------------------------------------

local function ItemEntries(kind, num)
    local entries = {}
    for i = 1, num do
        local name, texture, count, quality, isUsable = GetQuestItemInfo(kind, i)
        if name then
            local link = GetQuestItemLink(kind, i)
            entries[#entries + 1] = { kind = kind, index = i, name = name, texture = texture, count = count,
                quality = quality, usable = isUsable, sub = SubLine(link, count) }
        end
    end
    return entries
end

local function Layout()
    if not (window and window:IsShown()) then return end
    local UI = ns.UI
    local width = list:GetWidth()
    local y = 0
    local function Place(region, gap)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", 0, -y)
        region:SetWidth(width)
        region:Show()
        y = y + (region.GetStringHeight and region:GetStringHeight() or region:GetHeight()) + (gap or 16)
    end

    -- Titel in der Kopfzeile: oben klein NPC · Stufe, darunter der Quest-Titel in Gold
    local questID = GetQuestID and GetQuestID()
    local level = questID and C_QuestLog.GetQuestDifficultyLevel and C_QuestLog.GetQuestDifficultyLevel(questID)
    local npc = UnitName("questnpc") or UnitName("npc") or ""
    window.npcTitle:SetText(npc .. ((level and level > 0) and (" · " .. L["Level %d"]:format(level)) or ""))
    window.npcName:SetText(GetTitleText() or "")

    -- Text und Ziele je nach Stand
    local objectives
    if mode == "detail" then
        body:SetText(GetQuestText() or "")
        objectives = GetObjectiveText()
    elseif mode == "progress" then
        body:SetText(GetProgressText() or "")
    else
        body:SetText(GetRewardText() or "")
    end
    Place(body, 18)
    objHeader:Hide()
    objText:Hide()
    if objectives and objectives ~= "" then
        objHeader:SetText(QUEST_OBJECTIVES or L["Objectives"])
        Place(objHeader, 6)
        objText:SetText(objectives)
        Place(objText, 18)
    end

    -- Karten: beim Fortschritt die benötigten Items, sonst Belohnungen (Auswahl + feste)
    local groups = {}
    if mode == "progress" then
        local items = ItemEntries("required", GetNumQuestItems())
        if #items > 0 then groups[#groups + 1] = { title = L["Required"], items = items } end
    else
        local choices = ItemEntries("choice", GetNumQuestChoices())
        if #choices == 1 then choice = 1 end
        if #choices > 0 then
            groups[#groups + 1] = { title = #choices > 1 and L["Choose a reward"] or L["You receive"], items = choices, pick = #choices > 1 }
        end
        local rewards = ItemEntries("reward", GetNumQuestRewards())
        if #rewards > 0 then groups[#groups + 1] = { title = L["You also receive"], items = rewards } end
    end
    local n = 0
    local cardW = (width - CARD_GAP) / 2
    for gi, group in ipairs(groups) do
        local header = rewardHeader[gi]
        if not header then
            header = UI.Text(list.child, 12, "LEFT", UI.ACCENT)
            rewardHeader[gi] = header
        end
        header:SetText(group.title)
        Place(header, 8)
        for i, item in ipairs(group.items) do
            n = n + 1
            local card = Card(n)
            card.kind, card.index = item.kind, item.index
            card.icon:SetTexture(item.texture)
            card.icon:SetVertexColor(1, item.usable == false and 0.25 or 1, item.usable == false and 0.25 or 1)
            card.count:SetText(item.count and item.count > 1 and item.count or "")
            local r, g, b = QualityColor(item.quality)
            card.name:SetText(item.name)
            card.name:SetTextColor(r, g, b)
            local edge = (item.quality and item.quality >= Enum.ItemQuality.Uncommon) and { r, g, b } or { 0, 0, 0 }
            for _, e in ipairs(card.border) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
            card.sub:SetText(item.sub)
            local picked = group.pick and choice == item.index and item.kind == "choice"
            for _, e in ipairs(card.pick) do e:SetShown(picked) end
            card:SetWidth(cardW)
            card:ClearAllPoints()
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            card:SetPoint("TOPLEFT", col * (cardW + CARD_GAP), -(y + row * (CARD_H + CARD_GAP)))
            card:Show()
        end
        local rows = math.ceil(#group.items / 2)
        y = y + rows * CARD_H + math.max(rows - 1, 0) * CARD_GAP + 16
    end
    for i = #groups + 1, #rewardHeader do rewardHeader[i]:Hide() end
    for i = n + 1, #cards do cards[i]:Hide() end

    -- Außerdem: Erfahrung, Geld (beim Fortschritt: verlangtes Geld)
    local extras = {}
    if mode == "progress" then
        local money = GetQuestMoneyToGet()
        if money and money > 0 then extras[#extras + 1] = (REQUIRED_MONEY or L["Required"]) .. " " .. GetMoneyString(money, true) end
    else
        local xp = GetRewardXP and GetRewardXP()
        if xp and xp > 0 then extras[#extras + 1] = L["%d XP"]:format(xp) end
        local money = GetRewardMoney()
        if money and money > 0 then extras[#extras + 1] = GetMoneyString(money, true) end
    end
    if #extras > 0 then
        extraLine:SetText("|cff8ecbb4" .. L["Also"] .. "|r   " .. table.concat(extras, "    "))
        Place(extraLine, 8)
    else
        extraLine:Hide()
    end
    list:SetContentHeight(y)

    -- Knöpfe je Stand
    if mode == "detail" then
        primary.Text:SetText(QuestGetAutoAccept and QuestGetAutoAccept() and (OKAY or "OK") or (ACCEPT or "Accept"))
        secondary.Text:SetText(DECLINE or "Decline")
        secondary:SetShown(not (QuestGetAutoAccept and QuestGetAutoAccept()))
        primary:SetEnabled(true)
    elseif mode == "progress" then
        primary.Text:SetText(CONTINUE or "Continue")
        secondary.Text:SetText(CANCEL or "Cancel")
        secondary:Show()
        primary:SetEnabled(IsQuestCompletable())
    else
        primary.Text:SetText(COMPLETE_QUEST or "Complete Quest")
        secondary:Hide()
        primary:SetEnabled(GetNumQuestChoices() <= 1 or choice ~= nil)
    end
    primary.Text:SetTextColor(unpack(primary:IsEnabled() and UI.ACCENT or UI.MUTED))
    for _, edge in ipairs(primary.edges) do edge:SetShown(primary:IsEnabled()) end
    footerNote:SetText(mode == "complete" and GetNumQuestChoices() > 1 and not choice and L["Choose a reward first."] or "")
end

local function Primary()
    if mode == "detail" then
        if QuestGetAutoAccept and QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
    elseif mode == "progress" then
        CompleteQuest()
    else
        if GetNumQuestChoices() > 1 and not choice then return end
        GetQuestReward(choice or 1)
    end
    PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
end

local function Secondary()
    if mode == "detail" then DeclineQuest() else window:Hide() end
end

-- Fenster ----------------------------------------------------------------------------------------

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIQuest", WIDTH, ns.NPC_HEIGHT, "quest")
    ns.WatchBlizzardFrame(window, function() return QuestFrame end)
    window.Layout = Layout
    -- Kopfzeile umgedreht: oben klein NPC · Stufe, darunter groß der Quest-Titel in Gold
    window.npcName:ClearAllPoints()
    window.npcTitle:ClearAllPoints()
    window.npcTitle:SetPoint("TOPLEFT", window.header, "TOPLEFT", PAD + 46 + 14, -PAD - 4)
    window.npcTitle:SetPoint("RIGHT", window.header, "RIGHT", -PAD - 36, 0)
    window.npcName:SetPoint("TOPLEFT", window.npcTitle, "BOTTOMLEFT", 0, -5)
    window.npcName:SetPoint("RIGHT", window.npcTitle, "RIGHT")
    ns.SetFont(window.npcName, 17)
    window.npcName:SetTextColor(1, 0.82, 0)

    -- ein Pergament für den ganzen Inhalt (wie ein Auftragsschreiben), darauf scrollt die Liste
    local paper = ns.CreateParchmentPanel(window)
    paper:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 22)
    paper:SetPoint("BOTTOMRIGHT", -PAD, 56)
    list = UI.ScrollArea(paper)
    -- mehr Luft rundum auf dem Pergament (Benny 2026-11-06)
    list:SetPoint("TOPLEFT", 34, -30)
    list:SetPoint("BOTTOMRIGHT", -40, 28)
    body = UI.Text(list.child, 14, "LEFT", ns.PARCHMENT_TEXT)
    body:SetWordWrap(true)
    body:SetSpacing(4)
    objHeader = UI.Text(list.child, 12, "LEFT", UI.ACCENT)
    objText = UI.Text(list.child, 13, "LEFT", ns.PARCHMENT_TEXT)
    objText:SetWordWrap(true)
    objText:SetSpacing(3)
    rewardHeader = {}
    extraLine = UI.Text(list.child, 13, "LEFT", ns.PARCHMENT_TEXT)

    primary = UI.Button(window, "", Primary, 130)
    primary:SetHeight(30)
    primary:SetPoint("BOTTOMRIGHT", -PAD, 12)
    primary.edges = ns.AddBorder(primary, true)
    for _, edge in ipairs(primary.edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    secondary = UI.Button(window, "", Secondary, 110)
    secondary:SetHeight(30)
    secondary:SetPoint("RIGHT", primary, "LEFT", -8, 0)
    footerNote = UI.Text(window, 12, "LEFT", UI.MUTED)
    footerNote:SetPoint("BOTTOMLEFT", PAD, 21)

    window:HookScript("OnShow", function() PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN) end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
        GameTooltip:Hide()
        if ns.StillInteracting("QuestGiver", QuestFrame) then CloseQuest() end -- nur die eigene, noch laufende Unterhaltung
    end)
end

local function ShowMode(newMode)
    C_Timer.After(0, function()
        -- Blizzard entscheidet: nur wenn sein (geparktes) Fenster aufgeht
        if not QuestFrame:IsShown() then return end
        mode = newMode
        choice = nil
        window:SetNpc("questnpc", GetTitleText(), "")
        if window:IsShown() then
            list:ScrollToTop()
            Layout()
        else
            window:Show()
            list:ScrollToTop()
            Layout()
        end
    end)
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not QuestFrame then return end
    CreateWindow()
    -- unsichtbar parken: Blizzard prüft nur IsShown, OnShow/OnHide feuern unsichtbar nicht
    QuestFrame:SetParent(hidden)
    -- Unsichtbar läuft Blizzards OnShow der Quest-Seiten nie > QuestInfo_Display setzt kein Template,
    -- und QUEST_ITEM_UPDATE ruft dann QuestInfo_ShowRewards mit leerem Template auf (Lua-Fehler
    -- QuestInfo.lua:716 „ACTIVE_TEMPLATE nil“, Benny 2026-11-07). Unser Fenster frischt selbst auf.
    QuestFrame:UnregisterEvent("QUEST_ITEM_UPDATE")
    -- Blizzards gemeinsamer Quest-Inhalt (Belohnungen …) hängt sonst frei auf dem Bildschirm: er wird
    -- nur beim Zeigen von Blizzards Quest-Fenster umgehängt, frischt sich aber bei QUEST_ITEM_UPDATE
    -- trotzdem auf (Benny sah „Belohnungen“ mitten im Bild). Die Weltkarte hängt sich ihre Teile
    -- weiter selbst um.
    for _, name in ipairs({ "QuestInfoFrame", "QuestInfoObjectivesFrame", "QuestInfoSpecialObjectivesFrame",
        "QuestInfoTimerFrame", "QuestInfoRequiredMoneyFrame", "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }) do
        local frame = _G[name] -- freistehende Rahmen ohne Elternteil (QuestInfo.xml)
        if frame and frame:GetParent() ~= WorldMapFrame and not (frame:GetParent() and frame:GetParent():IsVisible()) then
            frame:SetParent(hidden)
        end
    end
    ns:On("QUEST_DETAIL", function() ShowMode("detail") end)
    ns:On("QUEST_PROGRESS", function() ShowMode("progress") end)
    ns:On("QUEST_COMPLETE", function() ShowMode("complete") end)
    ns:On("QUEST_FINISHED", function() if window:IsShown() then window:Hide() end end)
    ns:On("QUEST_ITEM_UPDATE", function() if window:IsShown() then Layout() end end)
    ns:On("GET_ITEM_INFO_RECEIVED", function() if window:IsShown() then Layout() end end)
end)
