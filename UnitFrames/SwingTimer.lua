-- Schlagtimer (Forever): EINE schmale Leiste unter der Hauptaktionsleiste, die bis zum nächsten
-- automatischen Treffer vollläuft. Blizzard meldet jeden Schlag mit Dauer (PLAYER_SWING,
-- C_SwingTimer) – kein Kampflog nötig, funktioniert auch in Instanzen.
--
--   [ Hauptaktionsleiste            ]
--   ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▒▒▒▒▒▒▒▒▒▒▒▒▒▒       ← Haupthand bzw. Distanz (Autoschuss/Zauberstab), was läuft
--   ▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁                ← unten darin schmal & weiß: Nebenhand (nur mit zwei Waffen)
--   (darunter die Bedrohungsleiste)
--
-- Die Leiste erscheint mit dem ersten Schlag und verschwindet kurz nach dem letzten.
-- Retail hat kein C_SwingTimer > Modul aus.
local _, ns = ...

local HEIGHT = 6
local OFFHAND_HEIGHT = 2 -- weißer Streifen unten in der Leiste
local GAP = 4            -- zur Hauptleiste
local LINGER = 0.6       -- so lange bleibt ein Timer nach Ablauf stehen (dann gilt er als ruhend)

local holder, bar, offhand
local timers = {}        -- [swingType] = { start, duration }
local demo = false

local function Enabled() return ns.db.swingTimer ~= false and C_SwingTimer ~= nil end

local function ClassColor()
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS[class]
    return color and { color.r, color.g, color.b } or ns.UI.ACCENT
end

-- läuft der Timer dieser Schlagart noch (oder gerade erst abgelaufen)?
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
    -- oben: Distanz, wenn sie läuft (Schießen), sonst Haupthand
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

-- Höhe, die die Bedrohungsleiste darunter freilassen muss
function ns.SwingTimerReserve()
    if not holder or not Enabled() or (ns.LayoutFlag and ns.LayoutFlag("healerGroups")) then return 0 end
    return ns.Snap(HEIGHT) + ns.Snap(GAP)
end

-- direkt unter der Hauptleiste, gleich breit (solange nicht selbst verschoben)
local function Place()
    local top, width = ns.BelowMainBar(ns.Snap(GAP))
    if not (holder and top) then return end
    holder:SetWidth(width)
    -- Heiler: kein Schlagtimer (Benny 2026-11-07: braucht man als Heiler nicht)
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
    -- Nebenhand: schmaler weißer Streifen unten in der Leiste
    offhand = CreateFrame("StatusBar", nil, bar)
    offhand:SetPoint("BOTTOMLEFT")
    offhand:SetPoint("BOTTOMRIGHT")
    offhand:SetHeight(ns.Snap(OFFHAND_HEIGHT))
    offhand:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    offhand:SetStatusBarColor(1, 1, 1, 0.9)
    offhand:SetMinMaxValues(0, 1)
    offhand:SetFrameLevel(bar:GetFrameLevel() + 1)
    offhand:Hide()
    holder:SetScript("OnUpdate", OnUpdate) -- Halter bleibt sichtbar (Bearbeitungsmodus), die Leiste blendet sich
    bar:Hide()
end

-- Testmodus (/mui t): Haupthand und Nebenhand laufen in ihrem Takt
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
    if not C_SwingTimer or not Enum.PlayerSwingType then return end -- nur Forever
    Create()
    ns.layoutFrames.swing = holder
    C_Timer.After(0.1, function()
        ns.OnLayout(Place)
        Place()
        if ns.UpdateThreatBar then ns.UpdateThreatBar() end -- Bedrohungsleiste rückt darunter
    end)
    ns:On("PLAYER_SWING", function(_, duration, swingType)
        if Enabled() and not demo then StartSwing(swingType, duration) end
    end)
end)
