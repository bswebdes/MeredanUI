-- Boss-Timer und Warnungen im MUI-Look (ersetzt DBM, Benny 2026-10-23). Quelle sind Blizzards
-- eigene Boss-Daten aus Midnight – dieselben, die DBM dort auch nur noch bekommt:
--   • Encounter Timeline (C_EncounterTimeline): kommende Boss-Fähigkeiten mit Restzeit
--   • Encounter Warnings (ENCOUNTER_WARNING): Warnungstexte mit Ziel, Farbe, Wichtigkeit
-- Blizzards eigene Timeline-Anzeige schaltet MUI über den dafür vorgesehenen Weg ab
-- (Attribut overrideViewType = None, „für Addons, die die Anzeige komplett übernehmen“).
-- Blizzards Warnungsfenster bleiben unsichtbar aktiv: Ton und Chatzeile kommen weiter von dort.
-- Werte können im Kampf geschützt sein (Secrets): Balken laufen über Blizzards Duration-Objekt,
-- Texte werden nur durchgereicht, Vergleiche (kurz vor Ablauf) macht die API selbst.
--
--   normale Balken: links neben dem Spieler-Frame, oben bündig, nach unten
--   große Balken (≤ HUGE_TIME s): oben mittig, nach unten – Warnungen direkt darüber
--
--   [▣] Flammenatem              12   ← Symbol mit Rahmen (rot = tödlich), Balken in Blizzards Farbe
local _, ns = ...
local L = ns.L

local BAR_WIDTH, BAR_HEIGHT = 220, 24
local HUGE_WIDTH, HUGE_HEIGHT = 260, 28
local GAP = 4            -- Abstand der Balken untereinander
local ICON_GAP = 4       -- Symbol ↔ Balken
local MAX_BARS, MAX_HUGE = 8, 4
local HUGE_TIME = 8      -- Sekunden: ab hier wandert ein Balken nach oben in die Mitte
local SLIDE_SPEED = 12   -- Nachrücken wie bei den Toasts
local FADE = 0.25
local MAX_WARNINGS = 3
local WARNING_TIME = 4   -- Sekunden, falls Blizzard keine Dauer mitgibt
local WARNING_SIZE = { [0] = 18, [1] = 22, [2] = 28 } -- nach Wichtigkeit (niedrig, mittel, hoch)
local DEFAULT_COLOR = { 0.9, 0.55, 0.15 }

-- Pull-Timer: Blizzards Countdown für die ganze Gruppe ---------------------------------------

local function Pull(arg)
    local seconds = tonumber(arg) or 10
    if not C_PartyInfo.DoCountdown(seconds) then ns.Print(L["Pull timer not possible right now."]) end
end
ns.AddCommand("pull", L["pull timer for the group (/mui pull 10)"], Pull)
if not SlashCmdList.PULL then
    SLASH_MEREDANUIPULL1 = "/pull"
    SlashCmdList.MEREDANUIPULL = Pull
end

-- Forever (Spieltyp „camelot“): Blizzard lädt dort weder die Boss-Zeitleiste noch die Boss-
-- Warnungen (Blizzard_EncounterTimeline/-Warnings nur für „standard“) – es gäbe nichts anzuzeigen.
-- Nur /pull bleibt (Blizzards eigener Countdown). Benny 2026-11-07: „raus aus Forever“.
if ns.IS_FOREVER then return end

local function Enabled() return ns.db.bossMods ~= false end
local Plain = ns.Plain -- Wert oder nil, falls geschützt

-- Text sicher setzen: geschützte Werte nur durchreichen
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

-- Halter ------------------------------------------------------------------------------------

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
    -- normale Balken: rechte Kante = Spalte links neben dem Spieler-Frame, Symbol bleibt 25 px vom Rand
    local player = ns.frames and ns.frames.player
    local edge = ns.LeftOfPlayerEdge()
    normalHolder:ClearAllPoints()
    if edge and player:GetTop() then
        barWidth = math.floor(math.min(BAR_WIDTH, edge - ns.SCREEN_MARGIN - BAR_HEIGHT - ICON_GAP))
        normalHolder:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", edge, player:GetTop())
    else
        normalHolder:SetPoint("TOPRIGHT", UIParent, "CENTER", -ns.Snap(300), ns.Snap(100))
    end
    -- große Balken gut ein Viertel unter dem oberen Rand, Warnungen darüber
    local hugeTop = -math.floor(h * 0.26)
    hugeHolder:ClearAllPoints()
    hugeHolder:SetPoint("TOP", UIParent, "TOP", (HUGE_HEIGHT + ICON_GAP) / 2, hugeTop)
    warningHolder:ClearAllPoints()
    warningHolder:SetPoint("BOTTOM", UIParent, "TOP", 0, hugeTop + ns.Snap(12))
    -- private Auren (PlayerAuras) sitzen über der obersten Leiste, linke Kante bündig
    ns.bossBarColumn = { holder = normalHolder, width = barWidth + BAR_HEIGHT + ICON_GAP }
    if ns.PlacePrivateAuras then ns.PlacePrivateAuras() end
end

-- Balken ------------------------------------------------------------------------------------

local pool, bars = {}, {} -- bars: eventID > Frame

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
    for _, text in ipairs({ bar.name, bar.time }) do text:SetFont(ns.STYLE.font, ns.FontPx(12), "OUTLINE") end -- SizeBar passt die Größe an

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

-- Größe je Platz (normal oder groß); Schrift wächst mit
local function SizeBar(bar, huge)
    if bar.huge == huge then return end
    bar.huge = huge
    local width, height = huge and HUGE_WIDTH or barWidth, huge and HUGE_HEIGHT or BAR_HEIGHT
    bar:SetSize(ns.Snap(width + height + ICON_GAP), ns.Snap(height))
    bar.icon:SetWidth(ns.Snap(height))
    local size = huge and 14 or 12
    bar.name:SetFont(ns.STYLE.font, size, "OUTLINE")
    bar.time:SetFont(ns.STYLE.font, size, "OUTLINE")
    bar.y = nil -- an neuem Platz sofort stehen, nicht quer über den Bildschirm gleiten
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
    -- tödlich: Symbolrahmen rot
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
    bar.status:SetMinMaxValues(0, 0) -- keinen Verweis auf Blizzards Timer behalten
    bars[bar.eventID] = nil
    bar.eventID, bar.spellID = nil, nil
    pool[#pool + 1] = bar
end

-- Liste neu ordnen: kurz vor Ablauf groß in der Mitte, Rest neben dem Spieler-Frame
local function SetIDs(list)
    local set = {}
    for _, id in ipairs(list) do set[id] = true end
    return set
end

local function Layout()
    if not C_EncounterTimeline.HasAnyEvents() and not next(bars) then return end
    -- Mit Ansicht „None“ legt Blizzard alle Ereignisse auf eine als versteckt markierte Spur –
    -- darum versteckte NICHT ausfiltern (nur beendete/abgebrochene)
    local huge = C_EncounterTimeline.GetSortedEventList(MAX_HUGE, HUGE_TIME, true, false) or {}
    local all = C_EncounterTimeline.GetSortedEventList(MAX_HUGE + MAX_BARS, nil, true, false) or {}
    local hugeSet, wanted = SetIDs(huge), SetIDs(all)
    -- verschwundene ausblenden
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

-- Animation, Restzeit und Ausblenden pro Bild
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

-- Warnungen ---------------------------------------------------------------------------------
-- bis zu drei Zeilen übereinander, neueste unten (direkt über den großen Balken)

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

-- Text wie bei Blizzard: Platzhalter mit Zaubernden und (klassenfarbenem) Ziel füllen
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
        old.age = math.max(old.age, old.duration) -- ausblenden lassen
        old:Hide()
        warningPool[#warningPool + 1] = old
    end
    LayoutWarnings()
end

-- wie Blizzard filtern: Warnungen an/aus und Mindest-Wichtigkeit aus den Spieleinstellungen
ns:On("ENCOUNTER_WARNING", function(_, info)
    if not Enabled() or not info or Plain(info.shouldShowWarning) == false then return end
    if not C_CVar.GetCVarBool("encounterWarningsEnabled") then return end
    local minimum = tonumber(C_CVar.GetCVar("encounterWarningsLevel")) or 0
    if (Plain(info.severity) or 2) < minimum then return end
    ShowWarning(info)
end)

-- „Bald dran“: Balken leuchtet auf, kurzer Ton
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

-- Blizzards Anzeigen abschalten -------------------------------------------------------------

local function TakeOver()
    -- Timeline: offizieller Weg für Addons, die die Anzeige ersetzen
    if EncounterTimeline and not InCombatLockdown() then
        EncounterTimeline:SetAttribute("overrideViewType", Enum.EncounterTimelineViewType.None)
        C_EncounterTimeline.SetViewType(Enum.EncounterTimelineViewType.None)
    end
    -- Warnungen: unsichtbar, aber aktiv (Ton + Chatzeile kommen weiter von Blizzard)
    for _, frame in ipairs({ CriticalEncounterWarnings, MediumEncounterWarnings, MinorEncounterWarnings }) do
        frame:SetAlpha(0)
        if frame.View then frame.View:SetMouseMotionEnabled(false) end
    end
end

ns:On("PLAYER_LOGIN", function()
    ns.root.dbmSetup = nil -- Rest des früheren DBM-Moduls
    if not Enabled() then return end
    -- ohne diese Spieleinstellungen liefert Blizzard keine Daten
    if not InCombatLockdown() then
        if not C_CVar.GetCVarBool("encounterTimelineEnabled") then C_CVar.SetCVar("encounterTimelineEnabled", "1") end
        if not C_CVar.GetCVarBool("encounterWarningsEnabled") then C_CVar.SetCVar("encounterWarningsEnabled", "1") end
    end
    TakeOver()
    ns.OnLayout(PlaceHolders)
    driver:Show()
end)

-- Demo (Einstellungen > Boss-Timer): Blizzards eigene Bearbeitungsmodus-Ereignisse laufen über
-- denselben Weg wie im Kampf, dazu je eine Beispiel-Warnung pro Wichtigkeit ---------------------

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
        if ns.PrivateAurasDemo then ns.PrivateAurasDemo(true) end -- Platzhalter über der obersten Leiste
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

