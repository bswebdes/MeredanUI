-- Boss timers and warnings in MUI look (replaces DBM). Source is Blizzard's own boss data
-- from Midnight - the same data DBM gets there:
--   - Encounter Timeline (C_EncounterTimeline): upcoming boss abilities with remaining time
--   - Encounter Warnings (ENCOUNTER_WARNING): warning texts with target, color, severity
-- Blizzard's timeline display is disabled the intended way (overrideViewType = None, meant
-- for addons that fully replace the display).
-- Blizzard's warning frames stay active but invisible: sound and chat line still come from there.
-- Values may be secret in combat: bars run on Blizzard's Duration object, texts are only
-- passed through, comparisons (about to expire) are done by the API itself.
--
--  normal bars: left of the player frame, top-aligned, growing down
--  huge bars (<= HUGE_TIME s): top center, growing down - warnings directly above
--
--  [#] Flame Breath             12   <- icon with border (red = deadly), bar in Blizzard's color
local _, ns = ...
local L = ns.L

local BAR_WIDTH, BAR_HEIGHT = 220, 24
local HUGE_WIDTH, HUGE_HEIGHT = 260, 28
local GAP = 4            -- spacing between bars
local ICON_GAP = 4       -- icon <-> bar
local MAX_BARS, MAX_HUGE = 8, 4
local HUGE_TIME = 8      -- seconds: from here a bar moves up to the center
local SLIDE_SPEED = 12   -- slide-in like the toasts
local FADE = 0.25
local MAX_WARNINGS = 3
local WARNING_TIME = 4   -- seconds, if Blizzard gives no duration
local WARNING_SIZE = { [0] = 18, [1] = 22, [2] = 28 } -- by severity (low, medium, high)
local DEFAULT_COLOR = { 0.9, 0.55, 0.15 }

-- Pull timer: Blizzard's countdown for the whole group -----------------------------------------

local function Pull(arg)
    local seconds = tonumber(arg) or 10
    if not C_PartyInfo.DoCountdown(seconds) then ns.Print(L["Pull timer not possible right now."]) end
end
ns.AddCommand("pull", nil, Pull)
if not SlashCmdList.PULL then
    SLASH_MEREDANUIPULL1 = "/pull"
    SlashCmdList.MEREDANUIPULL = Pull
end

-- Forever (game type "camelot"): Blizzard loads neither the encounter timeline nor the
-- encounter warnings there (Blizzard_EncounterTimeline/-Warnings only for "standard"), so
-- there is nothing to show. Only /pull remains (Blizzard's own countdown).
if ns.IS_FOREVER then return end

local function Enabled() return ns.db.bossMods ~= false end
local Plain = ns.Plain -- value or nil if secret

-- Set text safely: secret values are only passed through
local function SafeFormat(fontString, fmt, value)
    if not pcall(fontString.SetFormattedText, fontString, fmt, value) then fontString:SetText("") end
end

local function Countdown(fontString, remaining)
    if remaining == nil then return fontString:SetText("") end
    if issecretvalue(remaining) then return SafeFormat(fontString, "%.0f", remaining) end
    if remaining <= 0 then
        fontString:SetText("")
    elseif remaining < 3 then
        fontString:SetFormattedText("%.1f", remaining)
    elseif remaining < 60 then
        fontString:SetFormattedText("%d", math.ceil(remaining))
    else
        fontString:SetFormattedText("%d:%02d", math.floor(remaining / 60), math.ceil(remaining % 60))
    end
end

-- Holders -------------------------------------------------------------------------------------

local normalHolder = CreateFrame("Frame", "MeredanUIBossBars", UIParent)
local hugeHolder = CreateFrame("Frame", "MeredanUIBossBarsLarge", UIParent)
local warningHolder = CreateFrame("Frame", "MeredanUIBossWarnings", UIParent)
for _, holder in ipairs({ normalHolder, hugeHolder, warningHolder }) do
    holder:SetSize(1, 1)
    holder:SetFrameStrata("HIGH")
end

local barWidth = BAR_WIDTH

local function PlaceHolders()
    local h = UIParent:GetHeight()
    -- normal bars: right edge = column left of the player frame, icon stays 25 px from the edge
    local player = ns.frames and ns.frames.player
    local edge = ns.LeftOfPlayerEdge()
    normalHolder:ClearAllPoints()
    if edge and player:GetTop() then
        barWidth = math.floor(math.min(BAR_WIDTH, edge - ns.SCREEN_MARGIN - BAR_HEIGHT - ICON_GAP))
        normalHolder:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", edge, player:GetTop())
    else
        normalHolder:SetPoint("TOPRIGHT", UIParent, "CENTER", -ns.Snap(300), ns.Snap(100))
    end
    -- huge bars a good quarter below the top edge, warnings above
    local hugeTop = -math.floor(h * 0.26)
    hugeHolder:ClearAllPoints()
    hugeHolder:SetPoint("TOP", UIParent, "TOP", (HUGE_HEIGHT + ICON_GAP) / 2, hugeTop)
    warningHolder:ClearAllPoints()
    warningHolder:SetPoint("BOTTOM", UIParent, "TOP", 0, hugeTop + ns.Snap(12))
    -- private auras (PlayerAuras) sit above the topmost bar, left edges aligned
    ns.bossBarColumn = { holder = normalHolder, width = barWidth + BAR_HEIGHT + ICON_GAP }
    if ns.PlacePrivateAuras then ns.PlacePrivateAuras() end
end

-- Bars ----------------------------------------------------------------------------------------

local pool, bars = {}, {} -- bars: eventID -> frame

local function CreateBar()
    local bar = CreateFrame("Frame", nil, UIParent)
    bar:SetFrameStrata("HIGH")
    bar:SetMouseClickEnabled(false)
    bar.icon = CreateFrame("Frame", nil, bar)
    bar.icon:SetPoint("TOPLEFT")
    bar.icon:SetPoint("BOTTOMLEFT")
    bar.icon.tex = bar.icon:CreateTexture(nil, "ARTWORK")
    bar.icon.tex:SetAllPoints()
    bar.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.icon.edges = ns.AddBorder(bar.icon, true)

    bar.status = CreateFrame("StatusBar", nil, bar)
    bar.status:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", ns.Snap(ICON_GAP), 0)
    bar.status:SetPoint("BOTTOMRIGHT")
    bar.status:SetStatusBarTexture(ns.STYLE.barTexture)
    local bg = bar.status:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    local border = CreateFrame("Frame", nil, bar.status)
    border:SetAllPoints()
    border:SetFrameLevel(bar.status:GetFrameLevel() + 2)
    ns.AddBorder(border, true)

    bar.time = border:CreateFontString(nil, "OVERLAY")
    bar.time:SetPoint("RIGHT", -ns.Snap(6), 0)
    bar.name = border:CreateFontString(nil, "OVERLAY")
    bar.name:SetPoint("LEFT", ns.Snap(6), 0)
    bar.name:SetPoint("RIGHT", bar.time, "LEFT", -ns.Snap(6), 0)
    bar.name:SetJustifyH("LEFT")
    bar.name:SetWordWrap(false)
    for _, text in ipairs({ bar.name, bar.time }) do text:SetFont(ns.STYLE.font, ns.FontPx(12), "OUTLINE") end -- SizeBar adjusts the size

    bar.flash = border:CreateTexture(nil, "ARTWORK")
    bar.flash:SetAllPoints(bar.status)
    bar.flash:SetColorTexture(1, 1, 1, 1)
    bar.flash:SetBlendMode("ADD")
    bar.flash:SetAlpha(0)

    bar:SetScript("OnEnter", function(self)
        if self.spellID and not issecretvalue(self.spellID) then
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return bar
end

-- Size per slot (normal or huge); font grows with it
local function SizeBar(bar, huge)
    if bar.huge == huge then return end
    bar.huge = huge
    local width, height = huge and HUGE_WIDTH or barWidth, huge and HUGE_HEIGHT or BAR_HEIGHT
    bar:SetSize(ns.Snap(width + height + ICON_GAP), ns.Snap(height))
    bar.icon:SetWidth(ns.Snap(height))
    local size = huge and 14 or 12
    bar.name:SetFont(ns.STYLE.font, size, "OUTLINE")
    bar.time:SetFont(ns.STYLE.font, size, "OUTLINE")
    bar.y = nil -- snap into the new slot instead of sliding across the screen
end

local function ColorBar(bar, eventID)
    local color = C_EncounterTimeline.GetEventColor(eventID)
    if color then
        bar.status:SetStatusBarColor(color:GetRGB())
    else
        bar.status:SetStatusBarColor(unpack(DEFAULT_COLOR))
    end
end

local function AcquireBar(eventID)
    local info = C_EncounterTimeline.GetEventInfo(eventID)
    if not info then return end
    local bar = table.remove(pool) or CreateBar()
    bar.eventID, bar.spellID, bar.age, bar.leaving, bar.flashLeft = eventID, info.spellID, 0, false, 0
    bar.huge, bar.y = nil, nil
    bar.icon.tex:SetTexture(info.iconFileID)
    bar.name:SetText(info.spellName)
    -- deadly: red icon border
    local deadly = not issecretvalue(info.icons) and FlagsUtil.IsSet(info.icons or 0, Enum.EncounterEventIconmask.DeadlyEffect)
    for _, edge in ipairs(bar.icon.edges) do
        if deadly then edge:SetVertexColor(0.9, 0.1, 0.1, 1) else edge:SetVertexColor(0, 0, 0, 1) end
    end
    local timer = C_EncounterTimeline.GetEventTimer(eventID)
    if timer then
        bar.status:SetTimerDuration(timer, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.RemainingTime)
    else
        bar.status:SetMinMaxValues(0, 1)
        bar.status:SetValue(1)
    end
    ColorBar(bar, eventID)
    bar:SetAlpha(0)
    bar:Show()
    bars[eventID] = bar
    return bar
end

local function ReleaseBar(bar)
    bar:Hide()
    bar.status:SetMinMaxValues(0, 0) -- keep no reference to Blizzard's timer
    bars[bar.eventID] = nil
    bar.eventID, bar.spellID = nil, nil
    pool[#pool + 1] = bar
end

-- Reorder the list: about-to-expire bars big in the center, the rest beside the player frame
local function SetIDs(list)
    local set = {}
    for _, id in ipairs(list) do set[id] = true end
    return set
end

local function Layout()
    if not C_EncounterTimeline.HasAnyEvents() and not next(bars) then return end
    -- With view "None" Blizzard puts all events on a track flagged hidden, so do NOT
    -- filter out hidden ones (only finished/cancelled)
    local huge = C_EncounterTimeline.GetSortedEventList(MAX_HUGE, HUGE_TIME, true, false) or {}
    local all = C_EncounterTimeline.GetSortedEventList(MAX_HUGE + MAX_BARS, nil, true, false) or {}
    local hugeSet, wanted = SetIDs(huge), SetIDs(all)
    -- hide bars that disappeared
    for id, bar in pairs(bars) do
        if not wanted[id] then bar.leaving = true end
    end
    local hugeIndex, normalIndex = 0, 0
    for _, id in ipairs(all) do
        local bar = bars[id] or AcquireBar(id)
        if bar then
            bar.leaving = false
            local isHuge = hugeSet[id] == true
            SizeBar(bar, isHuge)
            local index
            if isHuge then
                hugeIndex = hugeIndex + 1
                index = hugeIndex
            elseif normalIndex < MAX_BARS then
                normalIndex = normalIndex + 1
                index = normalIndex
            end
            if index then
                bar.holder = isHuge and hugeHolder or normalHolder
                bar.targetY = -(index - 1) * (ns.Snap(isHuge and HUGE_HEIGHT or BAR_HEIGHT) + ns.Snap(GAP))
                if not bar.y then bar.y = bar.targetY end
            else
                bar.leaving = true
            end
        end
    end
end

-- Per-frame animation, remaining time and fade-out
local function UpdateBar(bar, elapsed)
    if bar.leaving then
        bar.age = math.min(bar.age, FADE) - elapsed
        bar:SetAlpha(math.max(bar.age / FADE, 0))
        if bar.age <= 0 then ReleaseBar(bar) return end
    elseif bar.age < FADE then
        bar.age = bar.age + elapsed
        bar:SetAlpha(math.min(bar.age / FADE, 1))
    end
    if bar.y ~= bar.targetY and bar.targetY then
        local rest = bar.targetY - bar.y
        bar.y = math.abs(rest) < 0.5 and bar.targetY or bar.y + rest * math.min(1, elapsed * SLIDE_SPEED)
    end
    if bar.holder and bar.y then
        bar:ClearAllPoints()
        bar:SetPoint(bar.holder == normalHolder and "TOPRIGHT" or "TOP", bar.holder, bar.holder == normalHolder and "TOPRIGHT" or "TOP", 0, bar.y)
    end
    if bar.flashLeft > 0 then
        bar.flashLeft = math.max(bar.flashLeft - elapsed, 0)
        bar.flash:SetAlpha(0.4 * bar.flashLeft / 0.6)
    end
    if bar.eventID and not bar.leaving then
        Countdown(bar.time, C_EncounterTimeline.GetEventTimeRemaining(bar.eventID))
    end
end

local driver = CreateFrame("Frame")
local sinceLayout = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceLayout = sinceLayout + elapsed
    if sinceLayout >= 0.1 then
        sinceLayout = 0
        Layout()
    end
    for _, bar in pairs(bars) do UpdateBar(bar, elapsed) end
end)
driver:Hide()

-- Warnings ------------------------------------------------------------------------------------
-- up to three lines stacked, newest at the bottom (directly above the huge bars)

local warnings, warningPool = {}, {}

local function LayoutWarnings()
    for i, line in ipairs(warnings) do
        line:ClearAllPoints()
        local above = warnings[i - 1]
        if above then
            line:SetPoint("BOTTOM", above, "TOP", 0, ns.Snap(6))
        else
            line:SetPoint("BOTTOM", warningHolder, "BOTTOM")
        end
    end
end

local function CreateWarning()
    local line = CreateFrame("Frame", nil, warningHolder)
    line:SetSize(1, 1)
    line.text = line:CreateFontString(nil, "OVERLAY")
    line.text:SetPoint("CENTER")
    line.left = line:CreateTexture(nil, "ARTWORK")
    line.left:SetPoint("RIGHT", line.text, "LEFT", -ns.Snap(8), 0)
    line.right = line:CreateTexture(nil, "ARTWORK")
    line.right:SetPoint("LEFT", line.text, "RIGHT", ns.Snap(8), 0)
    for _, icon in ipairs({ line.left, line.right }) do icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    line:SetScript("OnUpdate", function(self, elapsed)
        self.age = self.age + elapsed
        local life = self.duration
        if self.age < FADE then
            self:SetAlpha(self.age / FADE)
        elseif self.age < life then
            self:SetAlpha(1)
        elseif self.age < life + FADE * 2 then
            self:SetAlpha(1 - (self.age - life) / (FADE * 2))
        else
            self:Hide()
            for i, l in ipairs(warnings) do
                if l == self then table.remove(warnings, i) break end
            end
            warningPool[#warningPool + 1] = self
            LayoutWarnings()
        end
    end)
    return line
end

-- Text like Blizzard: fill placeholders with caster and (class-colored) target
local function WarningText(info)
    local target = info.targetName
    if info.targetGUID and not issecretvalue(info.targetGUID) then
        local _, class = GetPlayerInfoByGUID(info.targetGUID)
        local color = class and C_ClassColor.GetClassColor(class)
        if color and target and not issecretvalue(target) then target = color:WrapTextInColorCode(target) end
    end
    local ok, text = pcall(string.format, info.text, info.casterName, target)
    return ok and text or info.text
end

local function ShowWarning(info)
    local severity = Plain(info.severity) or 1
    local line = table.remove(warningPool) or CreateWarning()
    local size = WARNING_SIZE[severity] or 22
    line.text:SetFont(ns.STYLE.font, size, severity >= 2 and "THICKOUTLINE" or "OUTLINE")
    line.text:SetText(WarningText(info))
    if Plain(info.isDeadly) then
        line.text:SetTextColor(1, 0.2, 0.2)
    elseif info.color then
        line.text:SetTextColor(info.color:GetRGB())
    else
        line.text:SetTextColor(1, 0.82, 0)
    end
    local iconSize = ns.Snap(size + 6)
    for _, icon in ipairs({ line.left, line.right }) do
        icon:SetSize(iconSize, iconSize)
        icon:SetTexture(info.iconFileID)
        icon:SetShown(issecretvalue(info.iconFileID) or info.iconFileID ~= nil)
    end
    line:SetHeight(iconSize)
    local duration = info.duration
    line.duration = (duration and not issecretvalue(duration) and duration > 0) and duration or WARNING_TIME
    line.age = 0
    line:SetAlpha(0)
    line:Show()
    table.insert(warnings, 1, line)
    while #warnings > MAX_WARNINGS do
        local old = table.remove(warnings)
        old.age = math.max(old.age, old.duration) -- let it fade out
        old:Hide()
        warningPool[#warningPool + 1] = old
    end
    LayoutWarnings()
end

-- Filter like Blizzard: warnings on/off and minimum severity from the game settings
ns:On("ENCOUNTER_WARNING", function(_, info)
    if not Enabled() or not info or Plain(info.shouldShowWarning) == false then return end
    if not C_CVar.GetCVarBool("encounterWarningsEnabled") then return end
    local minimum = tonumber(C_CVar.GetCVar("encounterWarningsLevel")) or 0
    if (Plain(info.severity) or 2) < minimum then return end
    ShowWarning(info)
end)

-- "Coming soon": bar flashes, short sound
ns:On("ENCOUNTER_TIMELINE_EVENT_HIGHLIGHT", function(_, eventID)
    local bar = Enabled() and bars[eventID]
    if not bar then return end
    bar.flashLeft = 0.6
    if ns.db.bossModsSound ~= false then PlaySound(SOUNDKIT.UI_COUNTDOWN_TIMER, "SFX") end
end)

ns:On("ENCOUNTER_TIMELINE_EVENT_COLOR_CHANGED", function(_, eventID)
    local bar = bars[eventID]
    if bar then ColorBar(bar, eventID) end
end)

-- Disable Blizzard's displays ---------------------------------------------------------------

local function TakeOver()
    -- timeline: official way for addons that replace the display
    if EncounterTimeline and not InCombatLockdown() then
        EncounterTimeline:SetAttribute("overrideViewType", Enum.EncounterTimelineViewType.None)
        C_EncounterTimeline.SetViewType(Enum.EncounterTimelineViewType.None)
    end
    -- warnings: invisible but active (sound + chat line still come from Blizzard)
    for _, frame in ipairs({ CriticalEncounterWarnings, MediumEncounterWarnings, MinorEncounterWarnings }) do
        frame:SetAlpha(0)
        if frame.View then frame.View:SetMouseMotionEnabled(false) end
    end
end

ns:On("PLAYER_LOGIN", function()
    ns.root.dbmSetup = nil -- leftover from the former DBM module
    if not Enabled() then return end
    -- without these game settings Blizzard delivers no data
    if not InCombatLockdown() then
        if not C_CVar.GetCVarBool("encounterTimelineEnabled") then C_CVar.SetCVar("encounterTimelineEnabled", "1") end
        if not C_CVar.GetCVarBool("encounterWarningsEnabled") then C_CVar.SetCVar("encounterWarningsEnabled", "1") end
    end
    TakeOver()
    ns.OnLayout(PlaceHolders)
    driver:Show()
end)

-- Demo (Settings > Boss Timers): Blizzard's own Edit Mode events run through the same
-- path as in combat, plus one sample warning per severity ----------------------------------

local demoTimer, demoWarnings

local function DemoLoop()
    local loop = C_EncounterTimeline.AddEditModeEvents()
    demoTimer = C_Timer.NewTimer(loop or 30, DemoLoop)
end

local function DemoWarnings()
    for severity = 0, 2 do
        local info = C_EncounterWarnings.GetEditModeWarningInfo(severity)
        if info then
            info.duration = 6
            ShowWarning(info)
        end
    end
end

ns.BossModsDemo = {
    Start = function()
        PlaceHolders()
        driver:Show()
        if ns.PrivateAurasDemo then ns.PrivateAurasDemo(true) end -- placeholder above the topmost bar
        DemoLoop()
        DemoWarnings()
        demoWarnings = C_Timer.NewTicker(7, DemoWarnings)
    end,
    Stop = function()
        if demoTimer then demoTimer:Cancel() end
        if demoWarnings then demoWarnings:Cancel() end
        demoTimer, demoWarnings = nil, nil
        if ns.PrivateAurasDemo then ns.PrivateAurasDemo(false) end
        C_EncounterTimeline.CancelEditModeEvents()
        for _, line in ipairs(warnings) do line.age = math.max(line.age, line.duration) end
    end,
    IsActive = function() return demoTimer ~= nil end,
}

ns:On("PLAYER_REGEN_DISABLED", function()
    if ns.BossModsDemo.IsActive() then ns.BossModsDemo.Stop() end
end)

