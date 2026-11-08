-- Bedrohungsleiste unter der Hauptaktionsleiste – nur im Kampf gegen ein angreifbares Ziel.
-- KEIN Text (Benny 2026-11-07: „ich bin ein visueller Mensch, keine Zahlen“): die Leiste zeigt
-- „Gefahr“ – je voller, desto näher kommt jemand an die falsche Aggro; die Farbe läuft fließend
-- Salbei > Gelb > Orange > Rot.
--
--   [███▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒]   Salbei: ruhig
--   [████████████▒▒▒▒▒▒▒▒▒]   Orange: wird knapp
--   [█████████████████████]   Rot + pulsiert: Aggro falsch
--
--   DD/Heiler: eigene Bedrohung (voll = die Aggro springt auf dich; hast du sie: rot, pulsiert)
--   Tank: der Mitspieler, der deiner Aggro am nächsten ist (voll = er zieht; verloren: rot, pulsiert)
-- Retail kann die Werte in Instanzen schützen (Secrets): dann nur den Balken durchreichen, Farbe
-- neutral. Forever liefert alles lesbar.
local _, ns = ...

local HEIGHT = 8
local HEALER_WIDTH = 160 -- Layout Heiler: schmale Leiste über der Gruppe
local GAP = 4              -- Abstand zur Hauptleiste
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

-- Gruppe oder Begleiter (Jäger/Hexenmeister-Pet tankt solo)
local function WantedNow()
    local mode = Mode()
    if mode == "hidden" then return false end
    if mode == "group" and not (IsInGroup() or UnitExists("pet")) then return false end
    return UnitAffectingCombat("player") and UnitExists("target") and UnitCanAttack("player", "target")
        and not UnitIsDead("target")
end

-- Unit-Namen einmal anlegen (läuft im Kampf alle 0,2 s)
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

-- Tank: Mitspieler mit der höchsten Bedrohung relativ zur Aggro-Schwelle (100 % = zieht)
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

-- Farbe nach Gefahr (0–100), fließend: Salbei > Gelb (70) > Orange (90) > Rot (100)
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

-- danger: 0–100; wrong = Aggro falsch (voll rot, pulsiert)
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

    -- Geschützt (Retail-Instanz): Blizzards Wert nur durchreichen, neutrale Farbe
    if Secret(isTanking, status, scaled) then
        bar:SetValue(scaled)
        SetColor(unpack(ns.UI.ACCENT))
        return bar:Show()
    end
    if status == nil then return bar:Hide() end -- nicht auf der Bedrohungsliste

    -- Tank: Layout „Tank“ (sicher) oder Blizzards Rollen-Erkennung
    if (ns.LayoutFlag and ns.LayoutFlag("tank")) or (PlayerUtil and PlayerUtil.IsPlayerEffectivelyTank()) then
        if not isTanking then return Show(100, true) end -- Aggro verloren
        local unit, pct = Closest()
        return Show(unit and pct or 0)
    end
    if isTanking then return Show(100, true) end -- du hast die Aggro
    Show(scaled or 0)
end

local function Create()
    bar = CreateFrame("StatusBar", "MeredanUIThreatBar", UIParent)
    bar:SetFrameStrata("LOW")
    bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 100)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    ns.AddBorder(bar)
    -- Pulsieren bei falscher Aggro
    bar.pulse = bar:CreateAnimationGroup()
    bar.pulse:SetLooping("BOUNCE")
    local fade = bar.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.4)
    fade:SetSmoothing("IN_OUT")
    bar:Hide()
end

-- Unter der Hauptleiste, gleich breit (solange nicht selbst verschoben)
local function Place()
    local top, width = ns.BelowMainBar(ns.Snap(GAP))
    if not (bar and top) then return end
    bar:SetSize(width, ns.Snap(HEIGHT))
    local _, cy = UIParent:GetCenter()
    if ns.LayoutFlag and ns.LayoutFlag("healerGroups") then
        -- Heiler: schmal und mittig direkt über der Gruppe (Benny: „auf gar keinen Fall so breit“)
        bar:SetWidth(ns.Snap(HEALER_WIDTH))
        ns.PlaceFromCenter(bar, "BOTTOM", 0, ns.HealerGeometry().groupTop - cy + ns.Snap(8))
        return
    end
    -- Schlagtimer (Forever) sitzen direkt unter der Hauptleiste – dann darunter
    local reserve = ns.SwingTimerReserve and ns.SwingTimerReserve() or 0
    ns.PlaceFromCenter(bar, "TOP", 0, top - reserve)
end

-- Testmodus (/mui t): Gefahr steigt langsam an, wird rot und pulsiert kurz, dann wieder ruhig
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
    -- nach den Aktionsleisten (die richten sich beim Login ein)
    C_Timer.After(0.1, function()
        ns.OnLayout(Place)
        Place()
    end)
end)

ns:On("PLAYER_REGEN_DISABLED", function() StartTicker(); Update() end)
ns:On("PLAYER_REGEN_ENABLED", StopTicker)
ns:On("PLAYER_TARGET_CHANGED", Update)
ns:On("UNIT_THREAT_LIST_UPDATE", Update)
ns:On("UNIT_THREAT_SITUATION_UPDATE", Update)
