-- Swing timer (Forever): one thin bar below the main action bar that fills up until the next
-- auto attack. Blizzard reports each swing with its duration (PLAYER_SWING, C_SwingTimer), so no
-- combat log is needed and it works in instances. Main hand or ranged on top, off hand as a thin
-- white strip at the bottom (dual wield only). Retail has no C_SwingTimer, so the module is off.
local _, ns = ...

local HEIGHT = 6
local OFFHAND_HEIGHT = 2 -- off-hand strip at the bottom of the bar
local GAP = 4            -- to the main bar
local LINGER = 0.6       -- a finished timer stays this long before it counts as idle

local holder, bar, offhand
local timers = {}        -- [swingType] = { start, duration }
local demo = false

local function Enabled() return ns.db.swingTimer ~= false and C_SwingTimer ~= nil end

local function ClassColor()
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS[class]
    return color and { color.r, color.g, color.b } or ns.UI.ACCENT
end

-- Is this swing type still running (or just finished)?
local function Active(swingType, now)
    local t = timers[swingType]
    return t and now - t.start <= t.duration + LINGER
end

local function Progress(swingType, now)
    local t = timers[swingType]
    return math.min((now - t.start) / t.duration, 1)
end

local function OnUpdate()
    local now = GetTime()
    local T = Enum.PlayerSwingType
    -- Top: ranged while shooting, otherwise main hand
    local main = Active(T.Ranged, now) and T.Ranged or (Active(T.MainHand, now) and T.MainHand)
    if main then
        bar:SetValue(Progress(main, now))
    end
    local off = Active(T.OffHand, now)
    if off then offhand:SetValue(Progress(T.OffHand, now)) end
    offhand:SetShown(off and true or false)
    bar:SetShown((main or off or demo) and true or false)
end

local function StartSwing(swingType, duration)
    if not holder or not duration or duration <= 0 then return end
    timers[swingType] = { start = GetTime(), duration = duration }
    bar:Show()
end

-- Height the threat bar below has to leave free
function ns.SwingTimerReserve()
    if not holder or not Enabled() or (ns.LayoutFlag and ns.LayoutFlag("healerGroups")) then return 0 end
    return ns.Snap(HEIGHT) + ns.Snap(GAP)
end

-- Directly below the main bar, same width (unless moved by the user)
local function Place()
    local top, width = ns.BelowMainBar(ns.Snap(GAP))
    if not (holder and top) then return end
    holder:SetWidth(width)
    -- No swing timer for healers
    holder:SetShown(not (ns.LayoutFlag and ns.LayoutFlag("healerGroups")))
    ns.PlaceFromCenter(holder, "TOP", 0, top)
end

local function Create()
    holder = CreateFrame("Frame", "MeredanUISwingTimer", UIParent)
    holder:SetSize(1, ns.Snap(HEIGHT))
    holder:SetFrameStrata("LOW")
    bar = CreateFrame("StatusBar", nil, holder)
    bar:SetAllPoints()
    bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetStatusBarColor(unpack(ClassColor()))
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    ns.AddBorder(bar)
    -- Off hand: thin white strip at the bottom of the bar
    offhand = CreateFrame("StatusBar", nil, bar)
    offhand:SetPoint("BOTTOMLEFT")
    offhand:SetPoint("BOTTOMRIGHT")
    offhand:SetHeight(ns.Snap(OFFHAND_HEIGHT))
    offhand:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    offhand:SetStatusBarColor(1, 1, 1, 0.9)
    offhand:SetMinMaxValues(0, 1)
    offhand:SetFrameLevel(bar:GetFrameLevel() + 1)
    offhand:Hide()
    holder:SetScript("OnUpdate", OnUpdate) -- holder stays shown (Edit Mode), only the bar hides
    bar:Hide()
end

-- Test mode (/mui t): main and off hand run at their own speed
local demoTicker
function ns.SwingTestStart()
    if not holder then return end
    demo = true
    local speeds = { [Enum.PlayerSwingType.MainHand] = 2.4, [Enum.PlayerSwingType.OffHand] = 1.6 }
    for swingType, speed in pairs(speeds) do StartSwing(swingType, speed) end
    demoTicker = C_Timer.NewTicker(0.1, function()
        for swingType, speed in pairs(speeds) do
            if GetTime() - timers[swingType].start >= speed then StartSwing(swingType, speed) end
        end
    end)
end

function ns.SwingTestStop()
    demo = false
    if demoTicker then demoTicker:Cancel(); demoTicker = nil end
    wipe(timers)
    if bar then bar:Hide() end
end

function ns.UpdateSwingTimer()
    if not holder then return end
    if not Enabled() then wipe(timers); bar:Hide() end
    if ns.UpdateThreatBar then ns.UpdateThreatBar() end
end

ns:On("PLAYER_LOGIN", function()
    if not C_SwingTimer or not Enum.PlayerSwingType then return end -- Forever only
    Create()
    ns.layoutFrames.swing = holder
    C_Timer.After(0.1, function()
        ns.OnLayout(Place)
        Place()
        if ns.UpdateThreatBar then ns.UpdateThreatBar() end -- threat bar moves below
    end)
    ns:On("PLAYER_SWING", function(_, duration, swingType)
        if Enabled() and not demo then StartSwing(swingType, duration) end
    end)
end)
