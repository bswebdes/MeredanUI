-- Skills tab (Forever): professions, secondary and weapon skills (+ defense) with blue bars; details
-- show the description, and for weapons a small "same level / boss" grid
-- (formulas as in Blizzard's SkillsFrame.lua: 0.04 % per point, raid boss level 63).
local _, ns = ...
local L = ns.L
local Char = ns.Char

local BLUE = { 0.24, 0.44, 0.82 }
local DEFENSE_SKILL_ID = 95
local RAID_BOSS_LEVEL = 63
local HIDDEN_CATEGORIES = { [7] = true } -- class skills
local WEAPONS = { -- skillID -> ranged?
    [43] = false, [44] = false, [45] = true, [46] = true, [54] = false, [55] = false, [136] = false, [160] = false,
    [172] = false, [173] = false, [176] = true, [226] = true, [228] = true, [229] = false, [162] = false, [3014] = false,
}

local selectedID -- skillID

local function Shown(info)
    if info.isHeader then return not HIDDEN_CATEGORIES[info.skillID] end
    return not HIDDEN_CATEGORIES[info.skillLineCategoryID]
end

local function RankText(info)
    if info.modifier and info.modifier ~= 0 then
        return ("%d |cff6ed278(%+d)|r/%d"):format(info.rank, info.modifier, info.maxRank)
    end
    return ("%d/%d"):format(info.rank, info.maxRank)
end

-- Color by sign: negative muted red, positive green, zero accent
local MINUS, PLUS = { 0.88, 0.45, 0.42 }, { 0.43, 0.82, 0.47 }
local function SignColor(v)
    if v < -0.005 then return MINUS end
    if v > 0.005 then return PLUS end
    return ns.UI.ACCENT
end

local function Signed(v)
    local text = ("%.2f %%"):format(math.abs(v)):gsub("%.", L["DECIMAL_SEPARATOR"], 1)
    return (v > 0 and "+" or v < 0 and "−" or "±") .. text
end

-- Hit/crit difference vs. a target of level (player level + offset)
local function Diff(levelOffset, skill)
    return (skill - (UnitLevel("player") + levelOffset) * 5) * 0.04
end

local function Refresh(view)
    local entries = {}
    local selected, firstSkill
    for index = 1, C_SkillInfo.GetNumSkillLines() do
        local info = C_SkillInfo.GetSkillLineInfo(index)
        if info and info.parentSkillLineID == 0 and Shown(info) then
            if info.skillID == DEFENSE_SKILL_ID then info.modifier = select(2, UnitDefenseSkill("player")) or 0 end
            if info.isHeader then
                entries[#entries + 1] = {
                    header = true, text = info.name, collapsed = info.isCollapsed,
                    onClick = function()
                        if info.isCollapsed then C_SkillInfo.ExpandSkillHeader(index) else C_SkillInfo.CollapseSkillHeader(index) end
                    end,
                }
            else
                firstSkill = firstSkill or info
                if info.skillID == selectedID then selected = info end
                local single = info.maxRank == 1
                entries[#entries + 1] = {
                    text = info.name, selected = info.skillID == selectedID,
                    bar = not single and { value = info.rank, max = info.maxRank, color = BLUE, text = RankText(info) } or nil,
                    onClick = function()
                        selectedID = info.skillID
                        C_SkillInfo.SetSelectedSkill(index)
                        Char.Refresh()
                    end,
                }
            end
        end
    end
    -- An empty detail pane looks broken: select the first skill (like Blizzard)
    if not selected and firstSkill then
        selectedID, selected = firstSkill.skillID, firstSkill
        for _, entry in ipairs(entries) do
            if entry.text == firstSkill.name and not entry.header then entry.selected = true break end
        end
    end
    view.list:SetData(entries)
    if not selected then
        view.detail:Empty(Char.G("SKILL_DETAIL_SELECT_PROMPT", "Select a skill to see its details."))
        return
    end
    local data = {
        title = selected.name,
        bar = selected.maxRank > 1 and { value = selected.rank, max = selected.maxRank, color = BLUE, text = RankText(selected) } or nil,
        text = selected.description,
    }
    local ranged = WEAPONS[selected.skillID]
    if ranged ~= nil then
        local skill = selected.rank + (selected.modifier or 0)
        local boss = RAID_BOSS_LEVEL - UnitLevel("player")
        data.sub = L["Weapon skill"]
        local same, vsBoss = Diff(0, skill), Diff(boss, skill)
        data.grid = {
            { a = "", b = L["Same level"], c = L["Boss"], header = true },
            { a = Char.G("STAT_HIT_CHANCE", "Hit"), b = Signed(same), c = Signed(vsBoss), bColor = SignColor(same), cColor = SignColor(vsBoss) },
            { a = Char.G("STAT_CRITICAL_STRIKE", "Critical strike"), b = Signed(same), c = Signed(vsBoss), bColor = SignColor(same), cColor = SignColor(vsBoss) },
        }
        if not ranged and GetGlancingBlowChance then
            local defense = RAID_BOSS_LEVEL * 5
            local chance = GetGlancingBlowChance(skill, defense)
            local penalty = GetGlancingBlowPenalty and GetGlancingBlowPenalty(skill, defense)
            if chance and not issecretvalue(chance) then
                data.grid[#data.grid + 1] = { a = L["Glancing blows"], b = "", c = ("%.0f %%"):format(chance * 100), cColor = chance > 0 and MINUS or ns.UI.ACCENT }
            end
            if penalty and not issecretvalue(penalty) then
                data.grid[#data.grid + 1] = { a = L["Glancing damage"], b = "", c = ("−%.0f %%"):format(penalty * 100), cColor = penalty > 0 and MINUS or ns.UI.ACCENT }
            end
        end
    end
    view.detail:Fill(data)
end

Char.AddTab({
    key = "skills", order = 3, tip = Char.G("CHARACTER_FRAME_TAB_SKILLS", "Skills"), icon = "Interface\\Icons\\Ability_Racial_JackofAllTrades",
    Create = Char.ListAndDetail, Refresh = Refresh,
    events = { "SKILL_LINES_CHANGED", "UNIT_STATS" },
})
