-- Trainer knowledge for the player's class (WoW Forever), from Data/TrainerData.lua: which trainer
-- spells are waiting, leveling advice per spell rank (recommended / optional / skip) and the class
-- quest chains still open. Used by the spellbook's trainer tab, the level-up display and the
-- trainer window. Advice marks follow the setting "trainerAdvice".
local _, ns = ...
local L = ns.L

local T = {}
ns.TrainerInfo = T

local data, byID

local function Allowed(entry, race, faction)
    if entry.fa and entry.fa ~= faction then return false end
    if entry.ra then
        for _, id in ipairs(entry.ra) do
            if id == race then return true end
        end
        return false
    end
    return true
end

-- Class quests without a race list in the data: the starting-zone ones belong to the races starting
-- there, and quest givers in the other faction's zones aren't for us
local START_ZONES = {
    ["Elwynn Forest"] = { 1 }, ["Dun Morogh"] = { 3, 7 }, ["Teldrassil"] = { 4 }, ["Durotar"] = { 2, 8 },
    ["Tirisfal Glades"] = { 5 }, ["Mulgore"] = { 6 }, ["Zephras Isle"] = { 95, 96 },
}
local FACTION_ZONES = {
    ["Stormwind City"] = "Alliance", ["Ironforge"] = "Alliance", ["Darnassus"] = "Alliance", ["Elwynn Forest"] = "Alliance",
    ["Dun Morogh"] = "Alliance", ["Teldrassil"] = "Alliance", ["Darkshore"] = "Alliance", ["Loch Modan"] = "Alliance",
    ["Redridge Mountains"] = "Alliance", ["Orgrimmar"] = "Horde", ["Thunder Bluff"] = "Horde", ["Undercity"] = "Horde",
    ["Durotar"] = "Horde", ["Mulgore"] = "Horde", ["Tirisfal Glades"] = "Horde", ["The Barrens"] = "Horde",
}
local function QuestFits(chain, race, faction)
    if chain.ra then return true end -- races given: Allowed() checked them
    local zone = chain.st and chain.st.z
    if not zone then return true end
    local home = FACTION_ZONES[zone]
    if home and home ~= faction then return false end
    local starters = chain.lv <= 12 and START_ZONES[zone]
    if starters then
        for _, id in ipairs(starters) do
            if id == race then return true end
        end
        return false
    end
    return true
end

-- the player's class table, filtered to what this character can learn (built once)
local function Data()
    if data ~= nil then return data or nil end
    local _, class = UnitClass("player")
    local make = ns.IS_FOREVER and ns.TrainerData and ns.TrainerData[class]
    data = make and make() or false
    ns.TrainerData = nil -- the other classes' functions can go
    if not data then return nil end
    local _, _, race = UnitRace("player")
    local faction = UnitFactionGroup("player")
    local spells = {}
    byID = {}
    for _, spell in ipairs(data.spells) do
        if Allowed(spell, race, faction) then
            spells[#spells + 1] = spell
            byID[spell.id] = spell
        end
    end
    data.spells = spells
    local quests = {}
    for _, chain in ipairs(data.quests) do
        if Allowed(chain, race, faction) then
            -- race-specific start: the one for this race
            for _, s in ipairs(chain.sts or {}) do
                if Allowed(s, race, faction) then
                    chain.st, chain.lv = s.st or chain.st, s.lv or chain.lv
                    break
                end
            end
            if QuestFits(chain, race, faction) then quests[#quests + 1] = chain end
        end
    end
    data.quests = quests
    return data
end

function T.Has() return Data() ~= nil end

function T.AdviceOn() return ns.db and ns.db.trainerAdvice ~= false end

local function Known(id) return C_SpellBook.IsSpellKnown(id) end

local function AnyKnown(list)
    for _, id in ipairs(list) do
        if Known(id) then return true end
    end
    return false
end

local GERMAN = GetLocale() == "deDE"

-- advice for a spell rank: code ("r" recommended, "o" optional, "s" skip), reason in the client language
function T.Advice(spellID)
    if not (T.AdviceOn() and spellID and Data()) then return end
    local spell = byID[spellID]
    if not (spell and spell.a) then return end
    return spell.a, GERMAN and spell.de or spell.en
end

local LABELS = {
    r = { "Recommended", { 0.557, 0.796, 0.706 } },
    o = { "Optional", { 0.788, 0.671, 0.447 } },
    s = { "You can skip it", { 0.64, 0.6, 0.53 } },
}
function T.AdviceLabel(code)
    local label = LABELS[code]
    if label then return L[label[1]], label[2] end
end

-- Spells waiting at the trainer: not known yet, previous rank known (or waiting too), talent known
-- for talent ranks. ready = level reached. Upcoming ones up to `ahead` levels above the current.
function T.Waiting(level, ahead)
    local d = Data()
    if not d then return {} end
    local list, waiting = {}, {}
    for _, spell in ipairs(d.spells) do
        if spell.f ~= "pettrainer" and spell.lv <= level + (ahead or 0) and not Known(spell.id) then
            local ok = true
            if spell.req and not AnyKnown(spell.req) then
                ok = false
                for _, id in ipairs(spell.req) do
                    if waiting[id] then ok = true break end
                end
            end
            if ok and spell.t and not AnyKnown(spell.t) then ok = false end
            if ok then
                waiting[spell.id] = true
                local name = C_Spell.GetSpellName(spell.id)
                if name then
                    list[#list + 1] = {
                        id = spell.id, name = name, icon = C_Spell.GetSpellTexture(spell.id),
                        rank = spell.rk and ((RANK or "Rank") .. " " .. spell.rk) or nil,
                        level = spell.lv, cost = spell.c or 0, quest = spell.f == "quest",
                        ready = spell.lv <= level, advice = T.AdviceOn() and spell.a or nil,
                    }
                end
            end
        end
    end
    return list
end

local function Done(chain)
    for _, id in ipairs(chain.fin or chain.qs) do
        if C_QuestLog.IsQuestFlaggedCompleted(id) then return true end
    end
    return false
end

local function InLog(chain)
    for _, id in ipairs(chain.qs) do
        if C_QuestLog.GetLogIndexForQuestID(id) then return true end
    end
    return false
end

local function Where(st)
    if not st then return end
    local npc = GERMAN and st.de or st.en
    local zone = st.m and C_Map.GetMapInfo(st.m)
    zone = zone and zone.name or st.z
    if npc and zone then return npc .. ", " .. zone end
    return npc or zone
end

-- Map pin with the on-screen arrow on the quest giver, and the map opened there
function T.SetPin(entry)
    local st = entry and entry.start
    if not (st and st.m and C_Map.CanSetUserWaypointOnMap(st.m)) then return end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(st.m, st.x / 100, st.y / 100))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    ns.Print(L["Map pin set: %s"], entry.where or entry.name)
    if ns.OpenWorldMap and not InCombatLockdown() then ns.OpenWorldMap(st.m) end
end

-- One entry per chain: state "done", "active" (in the quest log), "open" (level reached) or "later".
-- Variants of the same chain (several starts) count once, the one furthest along wins.
local STATE_ORDER = { done = 4, active = 3, open = 2, later = 1 }
function T.ClassQuests(level)
    local d = Data()
    if not d then return {} end
    local byKey, order = {}, {}
    for _, chain in ipairs(d.quests) do
        local state = Done(chain) and "done" or InLog(chain) and "active" or chain.lv <= level and "open" or "later"
        local reward = chain.sp and chain.sp[1]
        local entry = {
            id = chain.id, level = chain.lv, ability = chain.cat == "ability", state = state,
            name = GERMAN and chain.nde or chain.n, reward = reward,
            rewardName = reward and C_Spell.GetSpellName(reward), icon = reward and C_Spell.GetSpellTexture(reward),
            start = chain.st, where = Where(chain.st),
        }
        local key = (reward or chain.n) .. (entry.ability and "" or ("|" .. chain.id))
        local old = byKey[key]
        if not old then
            byKey[key] = entry
            order[#order + 1] = key
        elseif STATE_ORDER[state] > STATE_ORDER[old.state] then
            byKey[key] = entry
        end
    end
    local list = {}
    for _, key in ipairs(order) do list[#list + 1] = byKey[key] end
    table.sort(list, function(a, b)
        if a.ability ~= b.ability then return a.ability end
        if a.level ~= b.level then return a.level < b.level end
        return (a.rewardName or a.name) < (b.rewardName or b.name)
    end)
    return list
end

-- Class quests to mention on level-up: ability chains open by now (not done, not in the quest log),
-- other class quests only when they start exactly at this level
function T.OpenQuests(level)
    local list = {}
    for _, entry in ipairs(T.ClassQuests(level)) do
        if entry.state == "open" and (entry.ability or entry.level == level) then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b) return a.level > b.level end)
    return list
end

-- Advice lines below the tooltip of a spellbook card / trainer row (the owner carries muiAdviceID),
-- under the gem divider. As a tooltip postcall: the game rebuilds spell tooltips once their data has
-- loaded, lines added after SetSpellByID would be lost.
local function AddAdviceLines(tooltip)
    if tooltip ~= GameTooltip then return end
    local owner = tooltip:GetOwner()
    local spellID = owner and owner.muiAdviceID
    if not spellID then return end
    local code, reason = T.Advice(spellID)
    if not code then return end
    local label, color = T.AdviceLabel(code)
    if ns.TooltipSection then ns.TooltipSection(tooltip) end
    tooltip:AddLine(label, color[1], color[2], color[3])
    if reason and reason ~= "" then tooltip:AddLine(reason, 0.64, 0.6, 0.53, true) end
end

ns:On("PLAYER_LOGIN", function()
    if ns.IS_FOREVER and ns.AddTooltipPostCall then ns.AddTooltipPostCall(TooltipDataProcessor.AllTypes, AddAdviceLines) end
end)
