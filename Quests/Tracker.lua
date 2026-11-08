-- Eigener Questtracker (WoW Forever) statt Blizzards Ziel-Tracker – gleiche Zeilen wie das
-- Questlog der Karte, frei am Bildschirmrand (Entwurf „Questtracker“, Benny 2026-11-07).
--
--   Dungeon                    −   ← nur in Instanzen: Blizzards Szenario-Daten, sonst eigene Liste
--   ┃ Die Todesminen                  (Dungeon-Journal + Bosskill-Meldungen)
--     ✓ 1/1 Rhahk'Zor besiegt
--     ! [18] Rote Seide              ← Quests der Instanz
--   Quests  9/40               −   ← verfolgte Quests (in Instanzen von selbst zugeklappt)
--  ▎! [17] Höhlenpilze         [▪]  ← Streifen = Schwierigkeit, ? = abgabebereit (grün unterlegt),
--  ▎   Schorfstängling: 3/5            Fokus grau unterlegt, Gegenstand nur als Bild (aktiv grün)
--   Berufe                     −   ← verfolgte Rezepte mit Material aus den Taschen
--
-- Blizzards ObjectiveTrackerFrame wird nur geparkt (an einen versteckten Rahmen gehängt) – seine
-- Ereignisse laufen weiter (z. B. neue Quests automatisch verfolgen). Quest-Gegenstände benutzt man
-- über eine eigene Leiste links daneben (wie Kaliel's Tracker): feste Plätze, der aktive oben mit
-- Taste – so hat der Tracker selbst keine geschützten Knöpfe und scrollt auch im Kampf.
-- Retail nutzt weiter Quests/QuestTracker.lua (Blizzards Tracker umgefärbt, Mythisch+).
local _, ns = ...
local L = ns.L

local WIDTH = 290
local GAP, SIDE_GAP = 10, 60     -- Abstand zu den Buffs / zur rechten Aktionsleiste
local ROW_GAP = 2
local ACTIVE_SIZE, ITEM_SIZE = 40, 30   -- Gegenstand-Leiste: aktiver oben, weitere darunter
local BAR_GAP = 6
local ICON_SIZE = 18                     -- Bild in der Questzeile (nur Anzeige)
local HEADER_H = 26
local SECTION_GAP = 12
local STICKY_H = HEADER_H + 6   -- fester Kopf beim Scrollen
local DONE = { 0.56, 0.8, 0.71 }
local RED = { 1, 0.31, 0.31 }

-- Geteilt mit dem Questlog der Karte --------------------------------------------------------------

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
local headers, rows, bossLines, itemButtons = {}, {}, {}, {}
local instanceBlock
local pending, itemsPending = false, false
local barItems = {}           -- { questID, logIndex, link, texture, charges } – aktiver zuerst
local hasTimers = false
local hasItems = false      -- mehrere Gegenstände: „nächste Quest“ regelmäßig neu wählen
local bossHidden = false
local instanceCollapse      -- in Instanzen: Quests zugeklappt (nil = gespeicherte Einstellung)
local kills, killsInstance = {}, nil

local function Collapsed(key)
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

-- Bausteine --------------------------------------------------------------------------------------

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

-- Kopf des Abschnitts, in dem man gerade scrollt, bleibt oben stehen (schiebt der nächste ihn weg)
local sticky
local function UpdateSticky(offset)
    if not sticky then
        sticky = BuildHeader(tracker)
        sticky:SetFrameLevel(content:GetFrameLevel() + 20)
        sticky:SetWidth(WIDTH)
        sticky:SetPoint("TOPLEFT", tracker, "TOPLEFT")
    end
    -- Abschnitt, dessen Kopf schon unter den festen Kopf gerutscht ist
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

local function QuestMenu(row)
    local questID = row.questID
    -- Symbole aus dem MDI-Satz (Media/Icons/CREDITS.txt): Karte, Gruppe, Auge durchgestrichen, X
    local items = { { value = "map", label = L["Show on map"], icon = "Map" } }
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
        if value == "map" then
            QuestMapFrame_OpenToQuestDetails(questID)
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
    row.tint = row:CreateTexture(nil, "BACKGROUND", nil, -1) -- abgabebereit / Fokus / fehlgeschlagen
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
    row.timerIcon:SetPoint("RIGHT", row.timer, "LEFT", -4, 0) -- RIGHT/LEFT = senkrecht mittig zur Zeile
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
    -- Quest-Gegenstand: nur Bild (benutzt wird er über die Leiste); Klick = Quest in den Fokus
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
        GameTooltip:SetQuestLogSpecialItem(self.logIndex)
        GameTooltip:Show()
    end)
    row.item:SetScript("OnLeave", function() row.hover:Hide(); GameTooltip:Hide() end)
    row.item:Hide()
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
        if C_SuperTrack.GetSuperTrackedQuestID() == questID then
            QuestMapFrame_OpenToQuestDetails(questID)
        else
            C_SuperTrack.SetSuperTrackedQuestID(questID)
        end
    end)
    rows[i] = row
    return row
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

-- Quest-Gegenstände: eigene Leiste links neben dem Tracker (Secure-Knöpfe an festen Plätzen –
-- belegt/umgestellt nur außerhalb des Kampfs, benutzbar immer). Knopf 1 = aktiv, mit Taste.
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
        local glow = button:CreateTexture(nil, "BACKGROUND", nil, -2) -- leichtes Leuchten ums Grün
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
        if not self.logIndex then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetQuestLogSpecialItem(self.logIndex)
        local title = self.questID and C_QuestLog.GetTitleForQuestID(self.questID)
        if title then GameTooltip:AddLine(title, DONE[1], DONE[2], DONE[3]) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- feste Plätze: aktiver oben rechts an der Ebene, weitere darunter (mit etwas Abstand)
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
        if button:IsShown() and button.logIndex then
            local start, duration, enable = GetQuestLogSpecialItemCooldown(button.logIndex)
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

-- Leiste belegen (nur außerhalb des Kampfs); danach zeigen die Questzeilen, welcher aktiv ist
local function ApplyItems()
    if InCombatLockdown() then
        if not itemsPending then
            itemsPending = true
            ns.AfterCombat(function() itemsPending = false; ApplyItems() end)
        end
        return
    end
    for i, item in ipairs(barItems) do
        local button = ItemButton(i)
        button.questID, button.logIndex = item.questID, item.logIndex
        local itemID = C_Item.GetItemInfoInstant(item.link)
        button:SetAttribute("item", itemID and ("item:" .. itemID) or item.link)
        button.icon:SetTexture(item.texture)
        button.count:SetText(item.charges and item.charges > 1 and item.charges or "")
        button:Show()
    end
    for i = #barItems + 1, #itemButtons do
        itemButtons[i].questID, itemButtons[i].logIndex = nil, nil
        itemButtons[i]:Hide()
    end
    UpdateHotkey()
    UpdateCooldowns()
    local active = itemButtons[1] and itemButtons[1]:IsShown() and itemButtons[1].questID
    for _, row in ipairs(rows) do
        if row.item then row.item.active:SetShown(row.item:IsShown() and row.questID == active) end
    end
end

-- Daten ------------------------------------------------------------------------------------------

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

-- Ziele einer Quest: Zeilen (Text) und ggf. Prozent für den Balken
local function QuestGoals(questID, logIndex, complete, failed)
    local lines, percent = {}, nil
    if failed then
        lines[1] = "|cffff5050" .. (FAILED or L["Failed"]) .. "|r"
        return lines
    end
    for _, obj in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        if obj.type == "progressbar" and not obj.finished then
            percent = GetQuestProgressBarPercent(questID) or 0
        elseif obj.text and obj.text ~= "" then
            lines[#lines + 1] = obj.finished and ("|cff8ecbb4" .. obj.text .. "|r") or obj.text
        end
    end
    if complete and #lines == 0 then
        local text = GetQuestLogCompletionText and GetQuestLogCompletionText(logIndex)
        lines[1] = "|cff8ecbb4" .. ((text and text ~= "") and text or (QUEST_WATCH_QUEST_READY or L["Ready to turn in"])) .. "|r"
    end
    -- Zeitquest: Restzeit immer rot mit Uhr, damit sie auffällt (Benny 2026-11-08); in der letzten
    -- Minute blinkt die Zeile im Sekundentakt (der Tracker aktualisiert dann jede Sekunde)
    local total, elapsed = C_QuestLog.GetTimeAllowed(questID)
    if total and elapsed and not issecretvalue(total) and total > 0 then
        local left = total - elapsed
        hasTimers = true
        local color = (left < 60 and math.floor(left) % 2 == 1) and { 1, 0.62, 0.55 } or { 1, 0.31, 0.31 }
        -- eigene Zeile mit echtem Bild statt |T|t im Text: Sanduhr exakt mittig zur Schrift (Benny 2026-11-08)
        return lines, percent, { text = L["Time left %s"]:format(TimeText(left)), color = color }
    end
    return lines, percent
end

-- Bosse der Instanz: Blizzards Szenario-Daten, sonst Dungeon-Journal + Bosskill-Meldungen
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

-- Forever hat keinen Abenteuerführer: Bosse aus den mitgelieferten Spieldaten (DungeonBosses.lua),
-- tot = aus ENCOUNTER_END bzw. der Instanz-ID (Benny 2026-11-08: „sollten da nicht die Bosse stehen?“)
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
    -- Forever: Funktion gibt es noch, liefert aber nichts → mitgelieferte Daten
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

-- Aufbau -----------------------------------------------------------------------------------------

-- Unterkante, bis zu der das Questlog reichen darf: Bildschirmrand, im Layout Nahkampf-DPS (16:9)
-- aber über dem Fokus, wenn der unter dem Questlog liegt (Benny 2026-11-07, Entwurf „Rollen-Layouts“)
local FOCUS_GAP = 20
local function BottomLimit()
    local limit = (UIParent:GetBottom() or 0) + ns.SCREEN_MARGIN
    if not (ns.LayoutFlag and ns.LayoutFlag("questlogAboveFocus")) then return limit end
    local player, focus = ns.frames and ns.frames.player, ns.sideFrames and ns.sideFrames.focus
    local focusLeft = ns.RightOfTargetEdge and ns.RightOfTargetEdge()
    local left, right = anchor and anchor:GetLeft(), anchor and anchor:GetRight()
    if not (player and player:GetTop() and focus and focusLeft and left and right) then return limit end
    -- Fokus oben bündig mit den Unitframes; nur ausweichen, wenn er waagerecht unter dem Questlog liegt
    if focusLeft < right and focusLeft + focus:GetWidth() > left then
        limit = math.max(limit, player:GetTop() + FOCUS_GAP)
    end
    return limit
end

-- Bossframes über dem Questlog (Layout Nahkampf-DPS, Benny 2026-11-07): Liegen sichtbare Bossframes
-- auf dem Questlog (16:9), rückt er unter den untersten sichtbaren Boss und zeigt nur noch die
-- Quests der Instanz. Auf breiten Bildschirmen stehen die Bosse daneben – dann bleibt alles, wie es ist.
-- Gibt zurück, um wie viel das Questlog nach unten rückt (0 = gar nicht).
local BOSS_GAP = 14
local BOSS_AURAS = 30 -- Debuff-Reihe unter jedem Bossframe
local function BossShift()
    if not (ns.LayoutFlag and ns.LayoutFlag("questlogUnderBosses")) or not ns.sideFrames then return 0 end
    local holder = _G["MeredanUIBossAnchor"]
    local top, left, right = anchor:GetTop(), anchor:GetLeft(), anchor:GetRight()
    if not (holder and holder:GetLeft() and top and left) then return 0 end
    -- Bossframes samt Zauber-Symbol rechts daneben (so hoch wie der Balken)
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

-- Höhe: höchstens 500 (früher Regler, Benny 2026-11-07: „höher will ich es nicht“), und nie
-- unter die Unterkante, die BottomLimit ausrechnet
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
    local y, h, r, b = 0, 0, 0, 0
    local superTracked = C_SuperTrack.GetSuperTrackedQuestID()
    local items = {}
    -- Bossframes über dem Questlog: darunter rücken, nur Instanz-Quests (s. BossShift)
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
        row.title:SetText("|cff99978f[" .. (info.difficultyLevel or info.level or 0) .. "]|r " .. (info.title or "")
            .. (tag and ("|cff99978f  · " .. tag .. "|r") or ""))
        if failed then
            row.title:SetTextColor(unpack(RED))
        elseif questID == superTracked then
            row.title:SetTextColor(1, 1, 1)
        else
            row.title:SetTextColor(color.r, color.g, color.b)
        end
        -- Gegenstand rechts?
        local link, itemTexture, charges, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
        local hasItem = link and (not complete or showWhenComplete)
        local right = hasItem and (ICON_SIZE + 10) or 6
        row.item:SetShown(hasItem and true or false)
        if hasItem then
            row.item.icon:SetTexture(itemTexture)
            row.item.logIndex = logIndex
            items[#items + 1] = { questID = questID, logIndex = logIndex, link = link, texture = itemTexture, charges = charges }
        end
        row.title:SetWidth(WIDTH - 26 - right)
        local lines, percent, timer = QuestGoals(questID, logIndex, complete, failed)
        row.goals:SetWidth(WIDTH - 26 - right)
        row.goals:SetText(table.concat(lines, "\n"))
        row.goals:SetShown(#lines > 0)
        local height = 6 + row.title:GetStringHeight() + (#lines > 0 and (3 + row.goals:GetStringHeight()) or 0)
        row.timer:SetShown(timer ~= nil)
        row.timerIcon:SetShown(timer ~= nil)
        if timer then
            row.timer:ClearAllPoints()
            row.timer:SetPoint("TOPLEFT", 26 + 16, -(height + 3)) -- 12 px Sanduhr + 4 px Abstand davor
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

    -- 1) Instanz
    local inInstance, instanceType = IsInInstance()
    local instanceName = inInstance and GetInstanceInfo() or nil
    local instanceQuests, inDungeonSection = {}, {}
    local zoneName
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        for index = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(index)
            if info and info.isHeader then
                zoneName = info.title
            -- Kopfzeile kann „Die Todesminen“ heißen, die Instanz „Todesminen“: Teilstring reicht
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
            -- im Bosskampf nur die Quests der Instanz (Bossliste und Name brauchen Platz)
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

    -- 2) verfolgte Quests
    local watched = {}
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID and not inDungeonSection[questID] then watched[#watched + 1] = questID end
    end
    -- Reihenfolge: Fokus-Quest, dann Quests im aktuellen Gebiet, dann der Rest (jeweils in der
    -- gewohnten Reihenfolge – nach Entfernung sortiert würde die Liste beim Laufen springen)
    local rank, order = {}, {}
    for i, questID in ipairs(watched) do
        order[questID] = i
        rank[questID] = questID == superTracked and 0 or (C_QuestLog.IsOnMap(questID) and 1 or 2)
    end
    table.sort(watched, function(a, b)
        if rank[a] ~= rank[b] then return rank[a] < rank[b] end
        return order[a] < order[b]
    end)
    -- Bosse über dem Questlog: in Instanzen nur deren Quests (oben), draußen (Weltboss, Vorschau)
    -- nur Quests des aktuellen Gebiets
    if bossMode then
        if inInstance then
            wipe(watched)
        else
            for i = #watched, 1, -1 do
                if rank[watched[i]] == 2 then table.remove(watched, i) end
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
            for _, questID in ipairs(watched) do AddQuest(questID) end
        end
    end

    -- 3) verfolgte Rezepte
    local recipes = C_TradeSkillUI.GetRecipesTracked and C_TradeSkillUI.GetRecipesTracked(false) or {}
    if #recipes > 0 and not bossMode then
        AddHeader("recipes", L["Professions"], nil, h > 0)
        if not Collapsed("recipes") then
            for _, recipeID in ipairs(recipes) do AddRecipe(recipeID) end
        end
    end

    -- Rest ausblenden, „+N weitere“
    for i = h + 1, #headers do headers[i]:Hide() end
    for i = r + 1, #rows do rows[i]:Hide() end
    for i = b + 1, #bossLines do bossLines[i]:Hide() end
    if b == 0 and instanceBlock and not inInstance then instanceBlock:Hide() end
    -- höher als erlaubt: scrollen (Mausrad, nur außerhalb des Kampfs)
    content:SetHeight(math.max(y, 1))
    tracker:SetHeight(math.max(math.min(y, MaxHeight((anchor:GetTop() or UIParent:GetTop()) - shift)), 1))
    tracker.UpdateScroll()
    tracker:SetShown(h > 0 and not bossHidden)

    -- Leiste: Fokus-Quest zuerst, sonst die nächste Quest mit Gegenstand
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
    wipe(barItems)
    if active or items[1] then barItems[1] = active or items[1] end
    for _, item in ipairs(items) do
        if item ~= barItems[1] then barItems[#barItems + 1] = item end
    end
    hasItems = #items > 1
    ApplyItems()
end

local function Refresh()
    if pending or not tracker then return end
    pending = true
    C_Timer.After(0, Layout)
end

-- Platz: rechte Kante links neben der inneren rechten Leiste, Oberkante wie die Leiste (höchstens unter den Buffs)
local function PlaceAnchorDefault()
    local margin, gap = ns.Snap(ns.SCREEN_MARGIN), ns.Snap(GAP)
    local right = UIParent:GetRight() - margin
    -- innerste sichtbare rechte Leiste (mit Leiste 6 rückt der Tracker weiter nach links)
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
    -- Oberkante bündig mit den rechten Aktionsleisten (Benny 2026-11-07, vorher von Hand so
    -- verschoben), aber nie höher als unter Buffs/Minimap
    if bar and bar:GetTop() then top = math.min(top, bar:GetTop()) end
    local cx, cy = UIParent:GetCenter()
    ns.PlaceFromCenter(anchor, "TOPRIGHT", right - cx, top - cy)
end

-- Bosse und Arena: ausblenden (nur in Instanzen – Forever meldet auch draußen Boss-Gegner).
-- Ein abgesicherter Zustands-Schalter erkennt Boss-/Arena-Gegner; die Gegenstands-Ebene blendet er
-- selbst aus (geht auch im Kampf), den Tracker über einen elternlosen Wächter (Alt+Z, Videos und
-- Zwischensequenzen verstecken UIParent – das darf nicht wie ein Bosskampf wirken).
local BOSS_STATE = "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists]"
    .. "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists][@boss5,exists] 1;0"
-- ininstance: Bosse blenden das Questlog aus (in Instanzen; nicht im Layout Nahkampf-DPS – dort rückt
-- es unter die Bossframes). inraid: im Schlachtzug immer aus (für spätere Layouts).
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
        -- Zustand neu auswerten: gleichen Wert noch mal setzen > _onstate-muiboss läuft erneut
        frame:SetAttribute("state-muiboss", frame:GetAttribute("state-muiboss"))
    end end
end
ns.UpdateQuestlogHiding = function() if watcher then UpdateInstanceFlag() end end

local function Setup()
    -- Blizzards Tracker parken (Ereignisse laufen weiter)
    local hidden = CreateFrame("Frame")
    hidden:Hide()
    -- (enthält Blizzards Secure-Gegenstandsknöpfe: umhängen nur außerhalb des Kampfs)
    local function Park()
        if ObjectiveTrackerFrame:GetParent() ~= hidden then ObjectiveTrackerFrame:SetParent(hidden) end
    end
    if ObjectiveTrackerFrame then
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
    -- dünner Balken rechts, nur wenn gescrollt werden kann
    thumb = tracker:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.3)
    thumb:SetWidth(2)
    thumb:Hide()
    -- tracker.offset = wie weit gescrollt ist. Ab > 0 steht oben der feste Kopf, der Scrollbereich
    -- beginnt darunter (Zeilen verschwinden unter seiner Linie, ohne Kasten dahinter)
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
    -- nicht an den Tracker hängen: sonst wird er mitgeschützt und darf im Kampf seine Höhe nicht
    -- ändern. Der Platzhalter liegt an derselben Ecke und bewegt sich nur außerhalb des Kampfs.
    itemLayer:SetFrameStrata("MEDIUM")
    -- Nicht am (ungeschützten) Questtracker verankert, sondern am Bildschirm: sonst verlor der
    -- Zustandstreiber nach Verschieben des Trackers den Zugriff („Invalid 'self' frame handle",
    -- Benny 2026-11-08). Position wird außerhalb des Kampfs nachgeführt.
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
    if ns.PlaceBossFrames then ns.PlaceBossFrames() end -- Bossframes links daneben
    ns.ClampQuestlogHeight = Refresh
    if ns.TestMode then
        hooksecurefunc(ns.TestMode, "Start", Refresh)
        hooksecurefunc(ns.TestMode, "Stop", Refresh)
    end
    -- Bossframes kommen und gehen (auch im Kampf): Questlog rückt mit
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
        if not (hasTimers or (hasItems and not InCombatLockdown())) then return end
        self.timerElapsed = (self.timerElapsed or 0) + elapsed
        if self.timerElapsed < (hasTimers and 1 or 2) then return end
        self.timerElapsed = 0
        Refresh()
    end)

    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "QUEST_ACCEPTED",
        "QUEST_REMOVED", "QUEST_TURNED_IN", "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "TRACKED_RECIPE_UPDATE",
        "BAG_UPDATE_DELAYED", "ZONE_CHANGED_NEW_AREA" }) do
        ns:On(event, Refresh)
    end
    ns:On("BAG_UPDATE_COOLDOWN", UpdateCooldowns)
    ns:On("UPDATE_BINDINGS", UpdateHotkey)
    ns:On("ENCOUNTER_END", function(_, encounterID, name, _, _, success)
        if success == 1 then
            kills[encounterID] = true
            if name then kills[name] = true end
            if ns.char then
                local saved = ns.char.trackerKills
                if not saved or saved.instance ~= killsInstance then
                    saved = { instance = killsInstance, kills = {} }
                    ns.char.trackerKills = saved
                end
                saved.kills[encounterID] = true
                if name then saved.kills[name] = true end
            end
            Refresh()
        end
    end)
    ns:On("PLAYER_ENTERING_WORLD", function()
        local inInstance, instanceType = IsInInstance()
        local instanceID = select(8, GetInstanceInfo())
        if instanceID ~= killsInstance then
            wipe(kills)
            killsInstance = instanceID
            -- Kills überleben /reload und Verbindungsabbruch (Benny 2026-11-08): gespeichert je Charakter,
            -- nur für dieselbe Instanz, solange man drin bleibt; draußen wird der Merker gelöscht
            local saved = ns.char and ns.char.trackerKills
            if saved and inInstance and saved.instance == instanceID then
                for key in pairs(saved.kills or {}) do kills[key] = true end
            elseif ns.char and not inInstance then
                ns.char.trackerKills = nil
            end
        end
        ReadInstanceLock()
        -- in Dungeons/Raids die übrigen Quests zuklappen, draußen wieder die eigene Einstellung
        instanceCollapse = (inInstance and (instanceType == "party" or instanceType == "raid")) and true or nil
        ns.AfterCombat(UpdateInstanceFlag)
        Refresh()
    end)
    ns.AfterCombat(SetupBossHiding) -- Zustandstreiber geht im Kampf nicht
    ns.AfterCombat(UpdateInstanceFlag)
    Refresh()
end

-- nach Buffs und Aktionsleisten (die richten sich beim Login ein)
ns:On("PLAYER_LOGIN", function() C_Timer.After(0.2, Setup) end)
