-- XP bar at the top center (inspired by Easy Experience Bar / Luxthos WeakAura).
--   600 x 18, no text, subtle ticks every 10 %. Segments: current XP | completed quests |
--   open quests; rested bonus as a thin blue strip along the bottom.
-- Tooltip: XP numbers, rested, XP/hour, time and kills to level, quest XP, time this level and
-- session. Hidden at max level (reputation etc. live below the minimap, TrackingBars.lua).
-- Blizzard's own status bars are hidden.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT = 600, 18
local PET_HEIGHT, PET_GAP = 6, 4 -- pet XP bar below (hunters)
local SECTIONS = 10 -- subtle tick lines like Blizzard's bar (every 10 %)
local WHITE = "Interface\\Buttons\\WHITE8X8"

local COLORS = {
    xp = { 0.557, 0.796, 0.706 },        -- Surf Green
    complete = { 1, 0.6, 0.15 },         -- completed quests: ready to turn in
    incomplete = { 1, 1, 1, 0.18 },      -- open quests: faint
    rested = { 0.31, 0.56, 1, 1 },       -- rested (bottom strip)
    pet = { 0.86, 0.66, 0.36 },          -- pet: warm amber, stands out from the green
}

local bar, petBar
local session = { start = GetTime(), gained = 0, kills = 0, killXP = 0, levelStart = GetTime() }
local lastXP, lastMax, pendingKill, lastGain, lastGainTime
local questXP = { complete = 0, incomplete = 0, completeCount = 0, incompleteCount = 0 }

-- Values -------------------------------------------------------------------------------------

local function AtMaxLevel()
    if IsXPUserDisabled and IsXPUserDisabled() then return true end
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    return maxLevel and UnitLevel("player") >= maxLevel or UnitXPMax("player") == 0
end

local function UpdateQuestXP()
    local complete, incomplete, completeCount, incompleteCount = 0, 0, 0, 0
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            local xp = GetQuestLogRewardXP(info.questID) or 0
            if xp > 0 then
                if C_QuestLog.IsComplete(info.questID) or C_QuestLog.ReadyForTurnIn(info.questID) then
                    complete, completeCount = complete + xp, completeCount + 1
                else
                    incomplete, incompleteCount = incomplete + xp, incompleteCount + 1
                end
            end
        end
    end
    questXP.complete, questXP.incomplete = complete, incomplete
    questXP.completeCount, questXP.incompleteCount = completeCount, incompleteCount
end
UpdateQuestXP = ns.PerfProbe("XP bar: quest XP", UpdateQuestXP)

-- XP gained this session (also across level-ups); kills are counted via the combat XP message.
local function TrackXP()
    local xp, max = UnitXP("player"), UnitXPMax("player")
    if lastXP then
        local gained = xp - lastXP
        if gained < 0 and lastMax then
            gained = (lastMax - lastXP) + xp -- level-up
            session.levelStart = GetTime()
        end
        if gained > 0 then
            session.gained = session.gained + gained
            lastGain, lastGainTime = gained, GetTime()
            if pendingKill then
                session.kills = session.kills + 1
                session.killXP = session.killXP + gained
                lastGain = nil
            end
        end
    end
    pendingKill = false
    lastXP, lastMax = xp, max
end

local function FormatTime(seconds)
    if not seconds or seconds <= 0 or seconds == math.huge then return "–" end
    local h, m = math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)
    if h > 0 then return ("%d:%02d h"):format(h, m) end
    return ("%d min"):format(math.max(m, 1))
end

local function Rates()
    local elapsed = GetTime() - session.start
    local perHour = elapsed > 60 and session.gained / elapsed * 3600 or 0
    local remaining = UnitXPMax("player") - UnitXP("player")
    local timeToLevel = perHour > 0 and remaining / perHour * 3600 or nil
    local perKill = session.kills > 0 and session.killXP / session.kills or nil
    local killsToLevel = perKill and math.ceil(remaining / perKill) or nil
    return perHour, timeToLevel, killsToLevel, remaining
end

-- Display ------------------------------------------------------------------------------------

-- from/to as fraction 0-1 of the bar width; height: thin strip at the bottom (else full height)
local function SetSegment(texture, from, to, height)
    from, to = math.max(from, 0), math.min(to, 1)
    if to <= from then
        texture:Hide()
        return
    end
    local width = bar:GetWidth()
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", from * width, 0)
    if height then
        texture:SetHeight(height)
    else
        texture:SetPoint("TOPLEFT", bar, "TOPLEFT", from * width, 0)
    end
    texture:SetWidth((to - from) * width)
    texture:Show()
end

local function Update()
    if not bar then return end
    local settings = ns.db.xpBar
    if AtMaxLevel() or not ns.ShownByMode(settings.mode) then -- reputation etc.: bars below the minimap
        bar:Hide()
        return
    end
    bar:Show()
    bar.muiMouseover = ns.VisibilityMode(settings.mode) == "mouseover"
    local xp, max = UnitXP("player"), UnitXPMax("player")
    if max <= 0 then return end
    local cur = xp / max
    local complete = settings.quests ~= "none" and questXP.complete / max or 0
    local incomplete = settings.quests == "all" and questXP.incomplete / max or 0
    local rested = (GetXPExhaustion() or 0) / max
    SetSegment(bar.xp, 0, cur)
    SetSegment(bar.complete, cur, cur + complete)
    SetSegment(bar.incomplete, cur + complete, cur + complete + incomplete)
    SetSegment(bar.rested, cur, cur + rested, 3 * ns.PixelSize()) -- rested: bottom strip, covers nothing
end

-- Pet XP (Forever: GetPetExperience as in Classic); only shown while the pet still gains XP
local function UpdatePet()
    if not petBar then return end
    local xp, max = 0, 0
    if UnitExists("pet") and GetPetExperience then xp, max = GetPetExperience() end
    if not (max and max > 0) then
        petBar:Hide()
        return
    end
    petBar:Show()
    petBar.fill:SetWidth(math.max(petBar:GetWidth() * math.min(xp / max, 1), 0.01))
end

local function ShowPetTooltip(self)
    local xp, max = GetPetExperience()
    if not (max and max > 0) then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
    GameTooltip:AddLine((UnitName("pet") or PET or "Pet") .. " · " .. L["Level %d"]:format(UnitLevel("pet")), 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Experience"], ("%s / %s (%.1f %%)"):format(BreakUpLargeNumbers(xp), BreakUpLargeNumbers(max), xp / max * 100),
        0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine(L["Remaining"], BreakUpLargeNumbers(max - xp), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:Show()
end

-- Classic XP curve (Forever uses the same, 4,084,700 XP from 1 to 60): XP needed to leave level n
local XP_TABLE = { 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400,
    16000, 17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
    50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800,
    117500, 123200, 129100, 135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000,
    202300, 209800 }
-- Share of the way to the max level (only when the max level matches the table)
local function JourneyPercent(level, xp)
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60
    if maxLevel ~= #XP_TABLE + 1 or level >= maxLevel then return end
    local done, total = xp, 0
    for i, need in ipairs(XP_TABLE) do
        total = total + need
        if i < level then done = done + need end
    end
    return done / total * 100
end

local function ShowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
    local xp, max = UnitXP("player"), UnitXPMax("player")
    local perHour, timeToLevel, killsToLevel, remaining = Rates()
    local rested = GetXPExhaustion() or 0
    local function Line(label, value) GameTooltip:AddDoubleLine(label, value, 0.8, 0.8, 0.8, 1, 1, 1) end
    local function Pct(v) return ("%.1f %%"):format(v / max * 100) end
    -- Swatch in the segment's color before the line, so the tooltip doubles as a legend
    local function Key(color, label)
        local alpha = color[4] and 0.5 or 1 -- faint segment (open quests) as light gray
        return ("|T%s:10:10:0:0:8:8:0:8:0:8:%d:%d:%d|t "):format(WHITE, color[1] * 255 * alpha, color[2] * 255 * alpha,
            color[3] * 255 * alpha) .. label
    end

    GameTooltip:AddLine(L["Level %d"]:format(UnitLevel("player")), 1, 1, 1)
    Line(Key(COLORS.xp, L["Experience"]), ("%s / %s (%s)"):format(BreakUpLargeNumbers(xp), BreakUpLargeNumbers(max), Pct(xp)))
    Line(L["Remaining"], BreakUpLargeNumbers(remaining))
    local journey = JourneyPercent(UnitLevel("player"), xp)
    if journey then Line(L["Way to level %d"]:format(#XP_TABLE + 1), ("%.1f %%"):format(journey)) end
    if rested > 0 then Line(Key(COLORS.rested, L["Rested"]), ("%s (%s)"):format(BreakUpLargeNumbers(rested), Pct(rested))) end
    GameTooltip:AddLine(" ")
    Line(L["XP per hour"], perHour > 0 and BreakUpLargeNumbers(math.floor(perHour)) or "–")
    Line(L["Level-up in"], FormatTime(timeToLevel))
    Line(L["Kills to level"], killsToLevel and tostring(killsToLevel) or "–")
    GameTooltip:AddLine(" ")
    Line(Key(COLORS.complete, L["Quests ready to turn in"]), ("%d · %s (%s)"):format(questXP.completeCount,
        BreakUpLargeNumbers(questXP.complete), Pct(questXP.complete)))
    Line(Key(COLORS.incomplete, L["Open quests"]), ("%d · %s (%s)"):format(questXP.incompleteCount,
        BreakUpLargeNumbers(questXP.incomplete), Pct(questXP.incomplete)))
    Line(L["After turning in"], Pct(math.min(xp + questXP.complete, max)) ..
        (xp + questXP.complete >= max and (" · " .. L["Level-up!"]) or ""))
    GameTooltip:AddLine(" ")
    Line(L["Time this level"], FormatTime(GetTime() - session.levelStart))
    Line(L["Time this session"], FormatTime(GetTime() - session.start))
    GameTooltip:Show()
end

-- Setup --------------------------------------------------------------------------------------

local function HideBlizzard()
    -- Reparent the manager, not the bars: Edit Mode calls bar:GetParent():CheckForLayoutChange(),
    -- so the parent must stay the real manager (a replacement function would taint Edit Mode).
    -- Alpha 0 alone is not enough - Blizzard's fade-in animation brings the bars back.
    local hidden = CreateFrame("Frame")
    hidden:Hide()
    if StatusTrackingBarManager then StatusTrackingBarManager:SetParent(hidden) end
end

local function Create()
    bar = CreateFrame("Frame", "MeredanUIXPBar", UIParent)
    bar:SetSize(ns.Snap(WIDTH), ns.Snap(HEIGHT))
    bar:SetFrameStrata("LOW")
    bar:EnableMouse(true)
    ns.CreateBackground(bar)

    local function Segment(color, layer, sub)
        local tex = bar:CreateTexture(nil, layer, nil, sub)
        tex:SetTexture(ns.STYLE.barTexture or WHITE)
        tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        tex:Hide()
        return tex
    end
    bar.incomplete = Segment(COLORS.incomplete, "BORDER", 1)
    bar.rested = Segment(COLORS.rested, "OVERLAY", 1)
    bar.complete = Segment(COLORS.complete, "ARTWORK", 1)
    bar.xp = Segment(COLORS.xp, "ARTWORK", 2)

    -- Tick lines above all segments, 1 px, semi-transparent dark
    local px = ns.PixelSize()
    for i = 1, SECTIONS - 1 do
        local line = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        line:SetColorTexture(0, 0, 0, 0.45)
        line:SetWidth(px)
        -- Without this WoW rounds some 1 px lines to 0, so only every other tick would show
        line:SetSnapToPixelGrid(false)
        line:SetTexelSnappingBias(0)
        local x = math.floor(bar:GetWidth() * i / SECTIONS / px + 0.5) * px
        line:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
        line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
    end

    bar:SetScript("OnEnter", ShowTooltip)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Pet XP: same width, thin, directly below (parented to the XP bar: same visibility)
    petBar = CreateFrame("Frame", nil, bar)
    petBar:SetSize(bar:GetWidth(), ns.Snap(PET_HEIGHT))
    petBar:SetPoint("TOP", bar, "BOTTOM", 0, -ns.Snap(PET_GAP))
    petBar:EnableMouse(true)
    ns.CreateBackground(petBar)
    petBar.fill = petBar:CreateTexture(nil, "ARTWORK")
    petBar.fill:SetTexture(ns.STYLE.barTexture or WHITE)
    petBar.fill:SetVertexColor(unpack(COLORS.pet))
    petBar.fill:SetPoint("TOPLEFT")
    petBar.fill:SetPoint("BOTTOMLEFT")
    petBar:SetScript("OnEnter", ShowPetTooltip)
    petBar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    petBar:Hide()

    -- Top center, 25 px from the edge
    ns.OnLayout(function()
        ns.PlaceFromCenter(bar, "TOP", 0, UIParent:GetHeight() / 2 - ns.Snap(ns.SCREEN_MARGIN))
    end)
    ns.layoutFrames.xpbar = bar
    ns.RegisterMouseover(bar)
end

ns:On("PLAYER_LOGIN", function()
    HideBlizzard()
    Create()
    lastXP, lastMax = UnitXP("player"), UnitXPMax("player")
    UpdateQuestXP()
    Update()
    UpdatePet()
end)

ns:On("UNIT_PET_EXPERIENCE", UpdatePet)
ns:On("UNIT_PET", function(_, unit) if unit == "player" then C_Timer.After(0.2, UpdatePet) end end)
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, UpdatePet) end)

ns:On("PLAYER_XP_UPDATE", function() TrackXP(); Update() end)
ns:On("PLAYER_LEVEL_UP", function() C_Timer.After(0.5, Update) end)
ns:On("UPDATE_EXHAUSTION", Update)
ns:On("PLAYER_REGEN_DISABLED", Update)
ns:On("PLAYER_REGEN_ENABLED", Update)
ns.UpdateXPBar = function() Update() end
-- Lowest visible top bar (XP or pet XP); e.g. the flight bar anchors below it
function ns.XPBarBottom()
    if petBar and petBar:IsVisible() then return petBar end
    if bar and bar:IsVisible() then return bar end
end
-- Quest XP only matters below max level (no quest log scan at 60)
ns.OnQuestsChanged(function()
    if AtMaxLevel() then return end
    UpdateQuestXP()
    Update()
end)
-- Kill XP: the combat XP message arrives either before or after the XP update - handle both.
ns:On("CHAT_MSG_COMBAT_XP_GAIN", function()
    if lastGain and lastGainTime and GetTime() - lastGainTime < 0.2 then
        session.kills = session.kills + 1
        session.killXP = session.killXP + lastGain
        lastGain = nil
    else
        pendingKill = true
    end
end)
