-- Testmodus (/mui t): Frames ohne Ziel und Kampf anzeigen, Balken und
-- Klassenressource animiert, Beispiel-Auren an ihrem Platz. Nur außerhalb des Kampfes,
-- Kampfbeginn beendet ihn automatisch.
local _, ns = ...
local L = ns.L

local ELEMENTS = { "Health", "Power", "ClassPower", "Stagger", "RaidTargetIndicator", "Castbar" }
local CAST_TIME = 2.5 -- Sekunden pro Testzauber
local TEST_MAX_HEALTH = { player = 180000, target = 2400000 } -- für die Lebenszahl

-- Beispiel-Auren je Frame, eine Gruppe pro Aura-Reihe: { Icon, Restzeit, Stapel, Dispel-Art, fremd }
-- So viele, dass die Reihen voll werden – wie im echten Layout. above = über dem Frame,
-- oneRow = nur eine Reihe (Debuffs), fremd = Debuff eines anderen Spielers (grau).
local SAMPLE_AURAS = {
    player = {
        { size = "aura", oneRow = true, icons = {
            { 136139, "12", nil, "Curse" }, { 136007, "8", 3, "Poison" }, { 136071, "5", nil, "Magic" },
            { 136113, "21", nil, "Disease" }, { 132302, "14", 2, "Bleed" }, { 136091, "3" },
            { 136022, "9", nil, "Magic" }, { 136020, "17", nil, "Curse" }, { 136025, "2m" },
            { 136033, "30", nil, "Magic" },
        } },
        { size = "buff", above = true, icons = {
            { 134712, "25" }, { 136012, "38" }, { 132307, "12" }, { 132294, "4" }, { 458737, "19" },
            { 132306, "33" }, { 136114, "7" }, { 136101, "45" }, { 136103, "15" }, { 132285, "1m" },
            { 458733, "5" }, { 136088, "22" },
        } },
    },
    targettarget = {
        { size = "aura", oneRow = true, icons = {
            { 136139, "18", 6 }, { 136007, "9", 3, "Poison" }, { 136071, "4", nil, "Magic" },
        } },
    },
    focus = {
        { size = "aura", oneRow = true, icons = {
            { 132302, "14" }, { 136139, "22", nil, nil, true }, { 136007, "9", 3, nil, true },
        } },
        { size = "aura", oneRow = true, right = true, helpful = true, icons = {
            { 136075, "20", nil, "Magic" },
        } },
    },
    boss1 = {
        { size = "aura", oneRow = true, icons = {
            { 132302, "18" }, { 132297, "12", 2 }, { 236270, "6" }, { 136091, "14", nil, nil, true },
        } },
        -- rechts: purgebarer Buff (Band) und wichtige (Schild, Wutanfall)
        { size = "aura", oneRow = true, right = true, helpful = true, icons = {
            { 135940, "8" }, { 132117, "9" }, { 136075, "20", nil, "Magic" },
        } },
    },
    target = {
        { size = "aura", oneRow = true, icons = {
            { 132302, "18" }, { 132297, "12", 2 }, { 236270, "6" }, { 132298, "3" },
            { 136139, "22", nil, nil, true }, { 136007, "9", 3, nil, true }, { 136091, "14", nil, nil, true },
            { 136022, "5", nil, nil, true }, { 136025, "11", nil, nil, true },
        } },
        { size = "buff", above = true, icons = {
            { 132117, "9", nil, "Enrage" }, { 136075, "20", nil, "Magic" },
        } },
    },
}

local active = false
local ticker
local previews = {}

-- Gleiche Anordnung wie die echten Aura-Reihen: innen starten, nach außen wachsen,
-- Buffs nach oben, Debuffs nach unten.
local function CreatePreviewAuras(unit, frame)
    local S = frame.Sizes
    local list = {}

    for _, group in ipairs(SAMPLE_AURAS[unit]) do
        -- innen starten (far), nach außen wachsen; right = von der anderen Seite (Gegner-Buffs
        -- rechts in der Reihe bei Fokus/Bossen), helpful = zweite Aura-Reihe, kein Debuff-Band
        local far, outward = S.far, -S.dir
        if group.right then far, outward = S.near, S.dir end
        local size = S[group.size]
        local step = size + S.auraSpacing
        local width = group.above and S.buffWidth or S.debuffWidth
        local inset = group.above and S.buffInset or S.debuffInset
        local perLine = math.max(math.floor((width + S.auraSpacing + 0.01) / step), 1)
        local vertical = group.above and "BOTTOM" or "TOP"
        local edge = group.above and "TOP" or "BOTTOM"
        local y0 = group.above and S.aurasAbove or -S.aurasBelow
        local up = group.above and 1 or -1
        for i, data in ipairs(group.icons) do
            if group.oneRow and i > perLine then break end
            local column, line = (i - 1) % perLine, math.floor((i - 1) / perLine)
            local button = CreateFrame("Button", nil, frame)
            button:EnableMouse(false)
            button:SetSize(size, size)
            button:SetPoint(vertical .. far, frame, edge .. far, (inset + column * step) * outward, y0 + line * step * up)
            button.Icon = button:CreateTexture(nil, "BORDER")
            button.Icon:SetAllPoints()
            button.Icon:SetTexture(data[1])
            button.Time = button:CreateFontString(nil, "OVERLAY")
            button.Count = button:CreateFontString(nil, "OVERLAY")
            -- Band wie bei echten Auren: Debuffs (außer fremden) und Auren mit Dispel-Art
            local dispelBand = (data[4] or (not group.above and not group.helpful and not data[5])) and "preview" or nil
            ns.StyleAuraButton(frame.AuraRows[group.helpful and 2 or 1], button, { desaturate = data[5], dispelBand = dispelBand })
            button.Time:SetText(data[2])
            button.Count:SetText(data[3] and tostring(data[3]) or "")

            -- Band nach Dispel-Art färben, wie es Blizzard bei echten Auren macht
            local dispel = data[4] and frame.colors.dispel[data[4]]
            if dispel then
                for _, edge in ipairs(button.FrameBorder) do edge:SetVertexColor(dispel:GetRGB()) end
            end
            list[#list + 1] = button
        end
    end
    return list
end

-- Kleine Frames (Pet, Ziel des Ziels) und seitliche (Fokus, Bosse): Name, Leben, Ressource;
-- die seitlichen dazu Zauberleiste und Zielmarkierung (Boss 1–5 zeigen Markierung 1–5).
local SMALL_ELEMENTS = { "Health", "Power", "Castbar", "RaidTargetIndicator" }

local function SmallName(unit)
    if unit == "pet" then return L["Test Pet"] end
    local boss = unit:match("^boss(%d)$")
    if boss then return L["Boss %d"]:format(boss) end
    return UnitName("player")
end

local function StartSmall(unit, frame)
    for _, element in ipairs(SMALL_ELEMENTS) do
        if frame[element] then frame:DisableElement(element) end
    end
    if SAMPLE_AURAS[unit] then
        for _, auras in ipairs(frame.AuraRows) do auras:Hide() end
        previews[unit] = previews[unit] or CreatePreviewAuras(unit, frame)
        for _, button in ipairs(previews[unit]) do button:Show() end
    end
    frame:Untag(frame.NameText)
    frame:Untag(frame.HealthText)
    UnregisterUnitWatch(frame)
    frame:Show()

    frame.NameText:SetText(SmallName(unit))
    frame.Health:SetMinMaxValues(0, 1)
    frame.Health:Show()
    local boss = unit:match("^boss(%d)$")
    frame.Health:SetStatusBarColor((boss and frame.colors.reaction[2] or frame.colors.health):GetRGB())
    ns.ColorBarBackground(frame.Health)
    if frame.Power then
        frame.Power:SetMinMaxValues(0, 1)
        frame.Power:Show()
        frame.Power:SetStatusBarColor(frame.colors.power[boss and "ENERGY" or "FOCUS"]:GetRGB())
        ns.ColorBarBackground(frame.Power)
    end
    if frame.Castbar then
        frame.Castbar:SetMinMaxValues(0, 1)
        frame.Castbar.Text:SetText(L["Test Spell"])
        frame.Castbar.Icon:SetTexture(135807)
    end
    if frame.RaidTargetIndicator then
        frame.RaidTargetIndicator:SetSpriteSheetCell(tonumber(boss) or 8, 4, 4)
        frame.RaidTargetIndicator:Show()
    end
end

local function StopSmall(unit, frame)
    for _, button in ipairs(previews[unit] or {}) do button:Hide() end
    for _, auras in ipairs(frame.AuraRows or {}) do auras:Show() end
    frame:Tag(frame.NameText, frame.NameText.tagString)
    frame:Tag(frame.HealthText, frame.HealthText.tagString)
    RegisterUnitWatch(frame)
    for _, element in ipairs(SMALL_ELEMENTS) do
        if frame[element] then frame:EnableElement(element) end
    end
    frame:UpdateAllElements("MeredanTestEnd")
end

local function AnimateSmall(unit, frame, t)
    local phase = unit == "pet" and 4 or (tonumber(unit:match("%d$")) or 1)
    local health = 0.6 + 0.4 * math.sin(t * 0.9 + phase)
    frame.Health:SetValue(health)
    frame.HealthText:SetFormattedText("%d%%", health * 100)
    if frame.Power then frame.Power:SetValue(0.5 + 0.5 * math.sin(t * 1.6 + phase)) end
    -- Testzauber im Wechsel mit Pausen, jeder zweite nicht unterbrechbar (grau)
    local castbar = frame.Castbar
    if castbar then
        local cycle = (t + phase) % (2 * CAST_TIME)
        castbar:SetShown(cycle < CAST_TIME)
        local progress = cycle / CAST_TIME
        castbar:SetValue(progress)
        castbar.Time:SetFormattedText("%.1f", math.max(1 - progress, 0) * CAST_TIME)
        if castbar.Shield then castbar.Shield:SetAlpha(math.floor((t + phase) / (2 * CAST_TIME)) % 2) end
    end
end

-- Pet, Ziel des Ziels, Fokus und Bosse
local function SmallFrames()
    local list = {}
    for unit, frame in pairs(ns.smallFrames or {}) do list[unit] = frame end
    for unit, frame in pairs(ns.sideFrames or {}) do list[unit] = frame end
    return list
end

local function Animate()
    local t = GetTime()
    for unit, frame in pairs(SmallFrames()) do AnimateSmall(unit, frame, t) end
    for unit, frame in pairs(ns.frames) do
        local phase = unit == "target" and 2 or 0
        local health = 0.55 + 0.45 * math.sin(t * 0.7 + phase)
        local power = 0.5 + 0.5 * math.sin(t * 1.3 + phase)
        frame.Health:SetValue(health)
        frame.Power:SetValue(power)
        frame.HealthText:SetText(AbbreviateNumbers(math.floor(health * TEST_MAX_HEALTH[unit])))
        frame.PowerText:SetText(AbbreviateNumbers(math.floor(power * 100)))

        if unit == "target" then -- Zielmarkierungen 1–8 wechseln alle 1,5 s
            -- Symbolblatt 4×4 wie Blizzards SetRaidTargetIconTexture
            frame.RaidTargetIndicator:SetSpriteSheetCell(math.floor(t / 1.5) % 8 + 1, 4, 4)
        end

        -- Testzauber im Wechsel mit Pausen (sonst sähe man das Leben unter dem Overlay nie);
        -- beim Ziel jeder zweite nicht unterbrechbar (grau)
        local castbar = frame.Castbar
        local cycle = (t + phase) % (2 * CAST_TIME)
        castbar:SetShown(cycle < CAST_TIME)
        local progress = cycle / CAST_TIME
        castbar:SetValue(progress)
        castbar.Time:SetFormattedText("%.1f", math.max(1 - progress, 0) * CAST_TIME)
        if castbar.Shield then
            castbar.Shield:SetAlpha(math.floor((t + phase) / (2 * CAST_TIME)) % 2)
        end
        if castbar.SafeZone then -- Latenz wie bei ~150 ms auf einen 1,5-s-Zauber
            castbar.SafeZone:ClearAllPoints()
            castbar.SafeZone:SetPoint("TOPRIGHT")
            castbar.SafeZone:SetPoint("BOTTOMRIGHT")
            castbar.SafeZone:SetWidth(castbar:GetWidth() * 0.1)
        end
        if castbar.testPips then
            local empowered = math.floor((t + phase) / (2 * CAST_TIME)) % 2 == 1
            for _, pip in ipairs(castbar.testPips) do pip:SetShown(empowered) end
            castbar.Text:SetText(empowered and L["Empowered Spell"] or L["Test Spell"])
        end

        local stagger = unit == "player" and frame.Stagger
        if stagger and stagger:IsShown() then
            local percent = (math.sin(t * 0.8) + 1) / 2 * 0.8 -- 0–80 %
            stagger:SetValue(percent)
            stagger:SetStatusBarColor(unpack(ns.StaggerColor(percent)))
            ns.ColorBarBackground(stagger)
            stagger.Text:SetText(AbbreviateNumbers(math.floor(percent * TEST_MAX_HEALTH.player)))
        end

        local centerPower = unit == "player" and frame.CenterPower
        if centerPower and centerPower:IsShown() then
            local value = (math.sin(t * 0.6) + 1) / 2
            centerPower:SetValue(value)
            centerPower.Text:SetText(math.floor(value * 100))
        end

        local classPower = unit == "player" and frame.ClassPower
        if classPower and classPower.strip:IsShown() then
            local cur = math.floor(t * 1.5) % (classPower.testMax + 1)
            for i = 1, classPower.testMax do
                classPower[i]:SetValue(i <= cur and 1 or 0)
            end
        end
    end
end

local function SetBarColor(bar, color)
    bar:SetStatusBarColor(color:GetRGB())
    ns.ColorBarBackground(bar)
end

local function Start(quiet)
    if InCombatLockdown() then
        ns.Print(L["Test mode is not available in combat."])
        return
    end
    active = true

    for unit, frame in pairs(ns.frames) do
        for _, element in ipairs(ELEMENTS) do
            if frame[element] then frame:DisableElement(element) end
        end
        frame:Untag(frame.HealthText)
        frame:Untag(frame.PowerText)
        for _, auras in ipairs(frame.AuraRows) do auras:Hide() end

        for _, bar in ipairs({ frame.Health, frame.Power, frame.Castbar }) do
            bar:SetMinMaxValues(0, 1)
            bar:Show()
        end
        frame.Castbar.Text:SetText(L["Test Spell"])
        -- Spieler: jeder zweite Testzauber ist ein Ermächtigungszauber mit Stufengrenzen
        if unit == "player" then
            local castbar = frame.Castbar
            if not castbar.testPips then
                castbar.testPips = {}
                for stage, fraction in ipairs({ 0.3, 0.55, 0.8 }) do
                    local pip = ns.CreateCastbarPip(castbar)
                    pip:SetPoint("TOP", castbar, "TOPLEFT", castbar:GetWidth() * fraction, 0)
                    pip:SetPoint("BOTTOM", castbar, "BOTTOMLEFT", castbar:GetWidth() * fraction, 0)
                    castbar.testPips[stage] = pip
                end
            end
        end
        frame.Castbar.Icon:SetTexture(135807)

        if unit == "target" then
            frame:Untag(frame.NameText)
            UnregisterUnitWatch(frame)
            frame:Show()
            -- absichtlich lang: zeigt das Kürzen („U. S. der Tiefe“)
            frame.NameText:SetText(ns.ShortenName(L["Ancient Shadowblade Guardian of the Deep"], frame.NameText))
            frame.RaidTargetIndicator:Show()
            SetBarColor(frame.Health, frame.colors.reaction[2])
            SetBarColor(frame.Power, frame.colors.power.MANA)
        else
            -- Theme „Klassenfarbe“: eigene Klassenfarbe, sonst das Grün des Themes
            local _, class = UnitClass("player")
            SetBarColor(frame.Health, ns.STYLE.classHealth and frame.colors.class[class] or frame.colors.health)
        end

        -- Braumeister: Staffelung statt Klassenleiste
        local brewmaster = unit == "player" and frame.Stagger
            and C_SpecializationInfo.GetSpecialization() == (SPEC_MONK_BREWMASTER or 1)
        if frame.Stagger then
            frame.Stagger:SetShown(brewmaster)
            frame.Stagger:SetMinMaxValues(0, 1)
        end

        -- Eule/Shadow/Elementar: Hauptressource in der Mitte statt Klassenleiste
        local centerPower = unit == "player" and frame.CenterPower and ns.UsesCenterPower("player")
        if frame.CenterPower then
            frame.CenterPower:Update() -- Farbe der echten Ressource übernehmen
            frame.CenterPower.testing = true
            frame.CenterPower:SetShown(centerPower)
            frame.CenterPower:SetMinMaxValues(0, 1)
        end

        local classPower = unit == "player" and not brewmaster and not centerPower and frame.ClassPower
        if frame.ClassPower and (brewmaster or centerPower) then frame.ClassPower.strip:Hide() end
        if classPower then
            local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
            classPower.testMax = (ns.Readable(max) and max > 0) and max or 5
            classPower.strip:Show()
            ns.LayoutClassPower(classPower, classPower.testMax)
            for i = 1, #classPower do
                local bar = classPower[i]
                bar:SetMinMaxValues(0, 1)
                bar:SetShown(i <= classPower.testMax)
                if i <= classPower.testMax then
                    bar:SetStatusBarColor(ns.ComboPointColor(i, classPower.testMax))
                    ns.ColorBarBackground(bar)
                end
            end
        end

        previews[unit] = previews[unit] or CreatePreviewAuras(unit, frame)
        for _, button in ipairs(previews[unit]) do button:Show() end
    end
    for unit, frame in pairs(SmallFrames()) do StartSmall(unit, frame) end
    if ns.GroupTestStart then ns.GroupTestStart() end
    if ns.ThreatTestStart then ns.ThreatTestStart() end
    if ns.SwingTestStart then ns.SwingTestStart() end
    if ns.LootRollTestStart then ns.LootRollTestStart() end

    ticker = C_Timer.NewTicker(0.03, Animate)
    if not quiet then ns.Print(L["Test mode on. %s again to end it."], "/mui t") end
end

local function Stop(quiet)
    active = false
    if ticker then
        ticker:Cancel()
        ticker = nil
    end

    for unit, frame in pairs(ns.frames) do
        for _, button in ipairs(previews[unit] or {}) do button:Hide() end
        for _, auras in ipairs(frame.AuraRows) do auras:Show() end
        frame:Tag(frame.HealthText, frame.HealthText.tagString)
        frame:Tag(frame.PowerText, frame.PowerText.tagString)

        if unit == "target" then
            frame:Tag(frame.NameText, frame.NameText.tagString)
            RegisterUnitWatch(frame)
        end

        for _, pip in ipairs(frame.Castbar.testPips or {}) do pip:Hide() end
        for _, element in ipairs(ELEMENTS) do
            if frame[element] then frame:EnableElement(element) end
        end
        frame:UpdateAllElements("MeredanTestEnd")
        if frame.CenterPower then
            frame.CenterPower.testing = nil
            frame.CenterPower:Update()
        end
    end
    for unit, frame in pairs(SmallFrames()) do StopSmall(unit, frame) end
    if ns.GroupTestStop then ns.GroupTestStop() end
    if ns.ThreatTestStop then ns.ThreatTestStop() end
    if ns.SwingTestStop then ns.SwingTestStop() end
    if ns.LootRollTestStop then ns.LootRollTestStop() end
    if not quiet then ns.Print(L["Test mode off."]) end
end

-- /mui t = Vorschau für alles (Core/Preview.lua), nicht nur die Unitframes
local function Toggle()
    if ns.Preview then return ns.Preview.Toggle() end
    if active then Stop() else Start() end
end

ns.AddCommand("test", L["test mode: show and animate all frames"], Toggle)
ns.AddCommand("t", L["short for %s"]:format("test"), Toggle)
ns.TestMode = { Start = Start, Stop = Stop, IsActive = function() return active end }

-- Kampfbeginn beendet den Testmodus. PLAYER_REGEN_DISABLED kommt noch vor der
-- Kampfsperre, geschützte Änderungen (RegisterUnitWatch) sind hier noch erlaubt.
ns:On("PLAYER_REGEN_DISABLED", function()
    if active then Stop() end
end)
