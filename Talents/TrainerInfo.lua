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
            quests[#quests + 1] = chain
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

-- Class quest chains open at this level: ability chains (totems, forms, pets ...) from any level up
-- to now, other class quests only when they start exactly at this level. Variants of the same chain
-- (several starts) count once.
function T.OpenQuests(level)
    local d = Data()
    if not d then return {} end
    local list, seen = {}, {}
    for _, chain in ipairs(d.quests) do
        local relevant = chain.lv <= level and (chain.cat == "ability" or chain.lv == level)
        local key = chain.sp and chain.sp[1] or chain.n
        if relevant and not seen[key] and not Done(chain) then
            seen[key] = true
            local st = chain.st
            local npc = st and (GERMAN and st.de or st.en)
            list[#list + 1] = {
                id = chain.id, level = chain.lv, ability = chain.cat == "ability",
                name = GERMAN and chain.nde or chain.n,
                where = npc and (st.z and (npc .. ", " .. st.z) or npc) or (st and st.z),
            }
        end
    end
    table.sort(list, function(a, b) return a.level > b.level end)
    return list
end

-- advice lines below a tooltip (spell, trainer service), under the gem divider
function T.AddAdviceLines(tooltip, spellID)
    local code, reason = T.Advice(spellID)
    if not code then return end
    local label, color = T.AdviceLabel(code)
    tooltip.muiAdding = true -- our own lines: no "other addon" divider (Tooltip.lua)
    if ns.TooltipSection then ns.TooltipSection(tooltip) end
    tooltip:AddLine(label, color[1], color[2], color[3])
    if reason and reason ~= "" then tooltip:AddLine(reason, 0.64, 0.6, 0.53, true) end
    tooltip.muiAdding = nil
end
