-- Threat bar below the main action bar, only in combat against an attackable target. No text:
-- the fill shows "danger" (how close someone is to wrong aggro), color fades sage > yellow >
-- orange > red; red + pulsing = aggro is wrong. DPS/healer: own threat. Tank: the group member
-- closest to pulling. Retail may return secret values in instances: pass them through, neutral color.
local _, ns = ...

local HEIGHT = 8
local HEALER_WIDTH = 160 -- healer layout: narrow bar above the group
local GAP = 4              -- gap to the main bar
local UPDATE_INTERVAL = 0.2

local bar, ticker
local demo = false

local function Secret(...)
    for i = 1, select("#", ...) do
        if issecretvalue and issecretvalue((select(i, ...))) then return true end
    end
    return false
end

local function Mode() return ns.db.threatBar or "group" end

-- Group or pet (hunter/warlock pets tank solo)
local function WantedNow()
    local mode = Mode()
    if mode == "hidden" then return false end
    if mode == "group" and not (IsInGroup() or UnitExists("pet")) then return false end
    return UnitAffectingCombat("player") and UnitExists("target") and UnitCanAttack("player", "target")
        and not UnitIsDead("target")
end

-- Build unit tokens once (runs every 0.2 s in combat)
local RAID_UNITS, PARTY_UNITS = { "pet" }, { "pet" }
for i = 1, 40 do
    RAID_UNITS[#RAID_UNITS + 1] = "raid" .. i
    RAID_UNITS[#RAID_UNITS + 1] = "raidpet" .. i
end
for i = 1, 4 do
    PARTY_UNITS[#PARTY_UNITS + 1] = "party" .. i
    PARTY_UNITS[#PARTY_UNITS + 1] = "partypet" .. i
end

local function GroupUnits()
    return IsInRaid() and RAID_UNITS or PARTY_UNITS
end

-- Tank: group member with the highest threat relative to the pull threshold (100% = pulls)
local function Closest()
    local bestUnit, bestPct
    for _, unit in ipairs(GroupUnits()) do
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local _, _, scaled = UnitDetailedThreatSituation(unit, "target")
            if scaled and not Secret(scaled) and (not bestPct or scaled > bestPct) then
                bestUnit, bestPct = unit, scaled
            end
        end
    end
    return bestUnit, bestPct
end

local function SetColor(r, g, b)
    bar:SetStatusBarColor(r, g, b)
    bar.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 0.8)
end

-- Color by danger (0-100), smooth: sage > yellow (70) > orange (90) > red (100)
local STOPS = {
    { 0, 0.557, 0.796, 0.706 },
    { 55, 0.557, 0.796, 0.706 },
    { 75, 0.95, 0.82, 0.3 },
    { 90, 1, 0.55, 0.12 },
    { 100, 0.9, 0.15, 0.15 },
}
local function DangerColor(pct)
    pct = math.max(0, math.min(pct, 100))
    for i = 2, #STOPS do
        local a, b = STOPS[i - 1], STOPS[i]
        if pct <= b[1] then
            local t = (pct - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
        end
    end
    local last = STOPS[#STOPS]
    return last[2], last[3], last[4]
end

-- danger: 0-100; wrong = aggro is wrong (full red, pulsing)
local function Show(danger, wrong)
    if wrong then
        bar:SetValue(100)
        SetColor(0.9, 0.15, 0.15)
        if not bar.pulse:IsPlaying() then bar.pulse:Play() end
    else
        bar:SetValue(math.max(math.min(danger, 100), 0))
        SetColor(DangerColor(danger))
        if bar.pulse:IsPlaying() then bar.pulse:Stop() end
        bar:SetAlpha(1)
    end
    bar:Show()
end

local function Update()
    if not bar or demo then return end
    if not WantedNow() then return bar:Hide() end

    local isTanking, status, scaled = UnitDetailedThreatSituation("player", "target")

    -- Secret (Retail instance): pass Blizzard's value through, neutral color
    if Secret(isTanking, status, scaled) then
        bar:SetValue(scaled)
        SetColor(unpack(ns.UI.ACCENT))
        return bar:Show()
    end
    if status == nil then return bar:Hide() end -- not on the threat table

    -- Tank: "Tank" layout (reliable) or Blizzard's role detection
    if (ns.LayoutFlag and ns.LayoutFlag("tank")) or (PlayerUtil and PlayerUtil.IsPlayerEffectivelyTank()) then
        if not isTanking then return Show(100, true) end -- aggro lost
        local unit, pct = Closest()
        return Show(unit and pct or 0)
    end
    if isTanking then return Show(100, true) end -- you have aggro
    Show(scaled or 0)
end
Update = ns.PerfProbe("Threat bar", Update)

local function Create()
    bar = CreateFrame("StatusBar", "MeredanUIThreatBar", UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetStatusBarTexture(ns.MEDIA .. "BarShade")
    bar:SetMinMaxValues(0, 100)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(ns.MEDIA .. "BarShade")
    ns.AddThinShell(bar)
    -- Pulse on wrong aggro
    bar.pulse = bar:CreateAnimationGroup()
    bar.pulse:SetLooping("BOUNCE")
    local fade = bar.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.4)
    fade:SetSmoothing("IN_OUT")
    bar:Hide()
end

-- Below the main bar, same width (unless moved by the user)
local function Place()
    local top, width = ns.BelowMainBar(ns.Snap(GAP) + ns.ThinShellReach())
    if not (bar and top) then return end
    bar:SetSize(width, ns.Snap(HEIGHT))
    local _, cy = UIParent:GetCenter()
    if ns.LayoutFlag and ns.LayoutFlag("healerGroups") then
        -- Healer: narrow and centered directly above the group
        bar:SetWidth(ns.Snap(HEALER_WIDTH))
        ns.PlaceFromCenter(bar, "BOTTOM", 0, ns.HealerGeometry().groupTop - cy + ns.Snap(8))
        return
    end
    -- Swing timers (Forever) sit directly below the main bar - go below them
    local reserve = ns.SwingTimerReserve and ns.SwingTimerReserve() or 0
    ns.PlaceFromCenter(bar, "TOP", 0, top - reserve)
end

-- Test mode (/mui t): danger rises slowly, turns red and pulses briefly, then calms down
local demoTicker
function ns.ThreatTestStart()
    if not bar or Mode() == "hidden" then return end
    demo = true
    local t = 0
    demoTicker = C_Timer.NewTicker(0.05, function()
        t = (t + 0.05) % 10
        if t < 7 then Show(t / 7 * 100) else Show(100, true) end
    end)
end

function ns.ThreatTestStop()
    demo = false
    if demoTicker then demoTicker:Cancel(); demoTicker = nil end
    if bar then
        bar.pulse:Stop()
        bar:SetAlpha(1)
        bar:Hide()
    end
    Update()
end

function ns.UpdateThreatBar() Place(); Update() end

local function StartTicker()
    if not ticker then ticker = C_Timer.NewTicker(UPDATE_INTERVAL, Update) end
end

local function StopTicker()
    if ticker then ticker:Cancel(); ticker = nil end
    Update()
end

ns:On("PLAYER_LOGIN", function()
    Create()
    ns.layoutFrames.threat = bar
    -- After the action bars (they set up on login)
    C_Timer.After(0.1, function()
        ns.OnLayout(Place)
        Place()
    end)
end)

ns:On("PLAYER_REGEN_DISABLED", function() StartTicker(); Update() end)
ns:On("PLAYER_REGEN_ENABLED", StopTicker)
ns:On("PLAYER_TARGET_CHANGED", Update)
-- Threat events come for every mob/member: only the target's matter (the 0.2 s combat ticker
-- covers the rest, threat events are unreliable in Forever anyway)
ns:On("UNIT_THREAT_LIST_UPDATE", function(_, unit) if unit == "target" then Update() end end)
ns:On("UNIT_THREAT_SITUATION_UPDATE", function(_, unit) if unit == "player" then Update() end end)
