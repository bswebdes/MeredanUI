-- Quest helpers (Comfort, each with its own switch; Settings > Quests), modelled on Leatrix Plus:
--   - questAutoAccept: pick and accept available quests (grey/trivial ones are skipped)
--   - questAutoTurnIn: pick and hand in finished quests; never when a reward has to be chosen or the
--     quest costs gold, currency or crafting reagents
--   - questAutoGossip: an NPC with no quests and exactly one chat option gets it picked (never vendors,
--     trainers, flight masters - their options carry other icons; nothing that asks for confirmation)
-- Holding Shift while talking to the NPC pauses all of it. Works with and without the mUI windows:
-- the windows open one frame later and only if Blizzard's frame is still open (NPC/Quest.lua,
-- NPC/Gossip.lua), so an automated step never flashes a window.
local _, ns = ...

local function On(key) return ns.db and ns.db[key] == true end

-- NPCs where automation has consequences (choices, reputation hand-ins, faction picks)
local NPC_BLOCK = {
    [15192] = true,  -- Anachronos (Caverns of Time)
    [45400] = true,  -- Fiona's Caravan (Eastern Plaguelands)
}
-- Only "pick a quest" is blocked: repeatable reputation hand-ins the player wants to choose themselves
local NPC_BLOCK_SELECT = {
    [12944] = true,  -- Lokhtos Darkbargainer (Thorium Brotherhood)
    [10307] = true,  -- Witch Doctor Mau'ari (E'Ko, Winterspring)
}

local GOSSIP_ICONS = { [132053] = true, [1019848] = true } -- chat bubble: plain conversation

local function NpcID()
    local guid = UnitGUID("npc") or UnitGUID("questnpc")
    if not ns.Readable(guid) or not guid then return nil end
    local unitType, _, _, _, _, id = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
    return tonumber(id)
end

local function Blocked(select)
    local id = NpcID()
    return id and (NPC_BLOCK[id] or (select and NPC_BLOCK_SELECT[id])) or false
end

local function Paused() return IsShiftKeyDown() end

local function Trivial(questID)
    return questID and C_QuestLog.IsQuestTrivial and C_QuestLog.IsQuestTrivial(questID) or false
end

-- Hand-in costs something the player might want to keep
local function CostsSomething()
    local money = GetQuestMoneyToGet and GetQuestMoneyToGet()
    if money and money > 0 then return true end
    for i = 1, GetNumQuestItems() do
        local link = GetQuestItemLink("required", i)
        if link then
            local isReagent = select(17, C_Item.GetItemInfo(link))
            if isReagent then return true end
        end
    end
    if GetNumQuestCurrencies and GetNumQuestCurrencies() > 0 then return true end
    return false
end

-- Greeting / gossip: pick a finished quest first, then a new one
local function PickFromGossip()
    if On("questAutoTurnIn") then
        for _, info in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if info.isComplete and info.questID then
                C_GossipInfo.SelectActiveQuest(info.questID)
                return true
            end
        end
    end
    if On("questAutoAccept") and not Blocked(true) then
        for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
            if info.questID and not info.isTrivial and not info.isIgnored then
                C_GossipInfo.SelectAvailableQuest(info.questID)
                return true
            end
        end
    end
    return false
end

local function PickFromGreeting()
    if On("questAutoTurnIn") then
        for i = 1, GetNumActiveQuests() do
            local title, complete = GetActiveTitle(i)
            if title and complete then
                SelectActiveQuest(i)
                return true
            end
        end
    end
    if On("questAutoAccept") and not Blocked(true) then
        for i = 1, GetNumAvailableQuests() do
            local trivial = GetAvailableQuestInfo(i)
            if not trivial then
                SelectAvailableQuest(i)
                return true
            end
        end
    end
    return false
end

-- Exactly one chat option and nothing else to do: pick it (no confirmation popups)
local function PickOnlyOption()
    if not On("questAutoGossip") then return end
    if #(C_GossipInfo.GetActiveQuests() or {}) > 0 or #(C_GossipInfo.GetAvailableQuests() or {}) > 0 then return end
    local options = C_GossipInfo.GetOptions() or {}
    if #options ~= 1 then return end
    local option = options[1]
    if option.selectOptionWhenOnlyOption then return end -- Blizzard already picks these itself
    if not GOSSIP_ICONS[option.icon] or option.spellID or (option.rewards and #option.rewards > 0) then return end
    if option.failureDescription or (option.status and option.status ~= 0) then return end
    if not option.gossipOptionID then return end
    C_GossipInfo.SelectOption(option.gossipOptionID)
end

local function Anything()
    return On("questAutoAccept") or On("questAutoTurnIn") or On("questAutoGossip")
end

local function OnEvent(event, arg1)
    if not Anything() or Paused() then return end
    if event == "GOSSIP_SHOW" then
        if Blocked(false) then return end
        if not PickFromGossip() then PickOnlyOption() end
    elseif event == "QUEST_GREETING" then
        if Blocked(false) then return end
        PickFromGreeting()
    elseif event == "QUEST_DETAIL" then
        if not On("questAutoAccept") or Blocked(false) then return end
        local questID = GetQuestID()
        if Trivial(questID) then return end
        if QuestGetAutoAccept and QuestGetAutoAccept() then
            AcknowledgeAutoAcceptQuest()
        else
            AcceptQuest()
        end
    elseif event == "QUEST_ACCEPT_CONFIRM" then
        -- escort quest started by a group member
        if not On("questAutoAccept") then return end
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
    elseif event == "QUEST_PROGRESS" then
        if not On("questAutoTurnIn") or Blocked(false) or not IsQuestCompletable() or CostsSomething() then return end
        CompleteQuest()
    elseif event == "QUEST_COMPLETE" then
        if not On("questAutoTurnIn") or Blocked(false) or CostsSomething() then return end
        local choices = GetNumQuestChoices()
        if choices <= 1 then GetQuestReward(choices) end
    elseif event == "QUEST_AUTOCOMPLETE" then
        if not On("questAutoTurnIn") or not arg1 then return end
        local index = C_QuestLog.GetLogIndexForQuestID(arg1)
        local info = index and C_QuestLog.GetInfo(index)
        if info and info.isAutoComplete and ShowQuestComplete then ShowQuestComplete(arg1) end
    end
end

for _, event in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_ACCEPT_CONFIRM",
    "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_AUTOCOMPLETE" }) do
    ns:On(event, function(_, arg1) OnEvent(event, arg1) end)
end
