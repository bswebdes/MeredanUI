-- Profession reminder (Forever): one toast as soon as the next profession rank can be learned
-- at the trainer, before the skill caps and points are wasted.
--
--   [icon] Mining 52/75
--          Journeyman can be learned at the trainer
--
-- Classic rules: Journeyman (150) at skill 50 + level 10, Expert (225) at 125 + level 20,
-- Artisan (300) at 200 + level 35. Also fires (once) if already capped.
-- Remembered per character and rank (ns.char.profReminded).
local _, ns = ...
local L = ns.L

-- Primary and secondary professions (skill line IDs)
local PROFESSIONS = {
    [164] = true, [165] = true, [171] = true, [182] = true, [186] = true, [197] = true, [202] = true,
    [333] = true, [393] = true, [129] = true, [185] = true, [356] = true,
}

-- current max rank -> { min skill, min level, next rank name }
local NEXT_RANK = {
    [75] = { 50, 10, "Journeyman" },
    [150] = { 125, 20, "Expert" },
    [225] = { 200, 35, "Artisan" },
}

local function Enabled() return ns.db.professionReminder ~= false and ns.IS_FOREVER end

local function Check()
    if not Enabled() or not (C_SkillInfo and C_SkillInfo.GetNumSkillLines) then return end
    ns.char.profReminded = ns.char.profReminded or {}
    local done = ns.char.profReminded
    local level = UnitLevel("player")
    for i = 1, C_SkillInfo.GetNumSkillLines() do
        local info = C_SkillInfo.GetSkillLineInfo(i)
        local nextRank = info and not info.isHeader and PROFESSIONS[info.skillID] and NEXT_RANK[info.maxRank]
        if nextRank then
            local key = info.skillID .. ":" .. info.maxRank
            if not done[key] and info.rank >= nextRank[1] and level >= nextRank[2] then
                done[key] = true
                if ns.AddToast then
                    ns.AddToast({
                        title = ("%s %d/%d"):format(info.name, info.rank, info.maxRank),
                        text = L["%s can be learned at the trainer"]:format(L[nextRank[3]]),
                        icon = ns.IconPath("Crafting"), color = ns.UI.ACCENT,
                    })
                end
            end
        end
    end
end

local pending
local function Request()
    if pending then return end
    pending = true
    C_Timer.After(1, function() pending = false; Check() end)
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    C_Timer.After(5, Check) -- after login, once toasts are ready
    ns:On("SKILL_LINES_CHANGED", Request)
    ns:On("PLAYER_LEVEL_UP", Request)
end)
