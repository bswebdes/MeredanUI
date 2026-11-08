-- Nameplates (oUF): Aufbau wie Blizzards Standard-Plates, Optik flach im MUI-Look.
--
--   [D][D][D]                      [B][B]      ← eigene Debuffs links, Buffs zum Entreißen rechts
--   ┌───────────────────────────────────┐
--   │ Name                          87 % │ [CC] ← Lebensbalken in Prioritätsfarbe
--   └───────────────────────────────────┘
--   ┌──┬────────────────────────────────┐
--   │ i│ Zaubername     |           1.2 │       ← Castbar mit Symbol, Text im Balken;
--                      └ Kick-Strich: hier ist dein Kick wieder bereit
--   └──┴────────────────────────────────┘
--   12.5 %                                     ← M+-Anteil des Mobs (nur in M+)
--
-- Ziel: 15 % größer, weiße Pfeile links und rechts. Andere Plates halb durchsichtig (außer sie
-- zaubern). Maus drüber: Balken hellt auf.
--
-- Farben des Lebensbalkens (wichtigste zuerst):
--   Bedrohung (im Kampf): rot = Aggro falsch (DD hat sie / Tank hat sie verloren),
--   orange = wechselt gerade, türkis = anderer Tank hat sie, Salbei (DD) = jemand anderes hat sie.
--   In Dungeons/Raids nach Gegnerart: Boss dunkelblau, Leutnant lila, Caster magenta,
--   Nahkämpfer cyan, unwichtig grau. Sonst wie üblich (feindlich rot, neutral gelb …).
--
-- Midnight schützt viele Werte (Secrets): Ob dein Kick bereit ist, ob ein Zauber wichtig
-- oder unterbrechbar ist, wird nie gelesen, sondern von Blizzard direkt in Farben
-- umgerechnet (C_CurveUtil.EvaluateColorValueFromBoolean). Freundliche Plates: nur Namen.
local _, ns = ...
local oUF = ns.oUF
local L = ns.L

local WIDTH, HEALTH, CAST = 170, 20, 16
local AURA, CC_AURA = 22, 28
local GAP = 2
local PLATE_W, PLATE_H = WIDTH + 24, HEALTH + CAST + 14 -- Lebensbalken + Castbar + Luft
local NAME_WIDTH = WIDTH - 40 -- Rest bleibt für „100%“
local DIM_ALPHA = 0.5      -- Plates, die nicht dein Ziel sind (solange du eins hast)
local TARGET_SCALE = 1.15  -- Ziel-Plate etwas größer

local C = {
    -- Bedrohung
    warning = { 0.8, 0, 0 }, transition = { 1, 0.63, 0 }, offtank = { 0.06, 0.67, 0.78 },
    onTank = { 0.557, 0.796, 0.706 }, -- DD: Mob im Kampf, aber nicht auf dir (Tank/Begleiter hat ihn) – mUI-Salbei
    -- Gegnerart (Dungeons/Raids)
    boss = { 0, 0.23, 1 }, miniboss = { 0.43, 0, 0.92 }, caster = { 0.74, 0, 0.67 },
    melee = { 0, 0.93, 0.99 }, trivial = { 0.49, 0.48, 0.51 },
    -- sonst
    hostile = { 0.85, 0.1, 0.1 }, neutral = { 1, 0.93, 0.29 }, friendly = { 0.2, 0.8, 0.2 },
    tapped = { 0.43, 0.43, 0.43 },
    -- Castbar
    cast = { 0.99, 0.8, 0 }, channel = { 0, 0.45, 0.78 }, important = { 1, 0.39, 0 },
    uninterruptible = { 0.51, 0.51, 0.51 }, kickReady = { 0.1, 0.85, 0.1 }, interrupted = { 0.85, 0.15, 0.15 },
    targetsYou = { 1, 1, 1 },
}

-- Kick-Zauber je Klasse; genutzt wird, was der Charakter kennt
local INTERRUPTS = {
    DEATHKNIGHT = { 47528 }, DEMONHUNTER = { 183752 }, DRUID = { 106839, 78675 }, EVOKER = { 351338 },
    HUNTER = { 147362, 187707 }, MAGE = { 2139 }, MONK = { 116705 }, PALADIN = { 96231 },
    PRIEST = { 15487 }, ROGUE = { 1766 }, SHAMAN = { 57994 }, WARLOCK = { 19647, 132409 },
    WARRIOR = { 6552 },
}
local kickSpell

local function UpdateKickSpell()
    kickSpell = nil
    local _, class = UnitClass("player")
    for _, id in ipairs(INTERRUPTS[class] or {}) do
        if C_SpellBook.IsSpellKnownOrInSpellBook(id)
            or C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Pet) then -- Hexer: Kick des Begleiters
            kickSpell = id
            return
        end
    end
end
ns:On("PLAYER_LOGIN", UpdateKickSpell)
ns:On("SPELLS_CHANGED", UpdateKickSpell)

-- Namen über den Köpfen (Welt-Namen) in unserer Schrift – WoW liest das beim Laden der Welt
UNIT_NAME_FONT = ns.DEFAULT_FONT

local inInstance = false -- Dungeon oder Raid: Gegnerart-Farben
ns:On("PLAYER_ENTERING_WORLD", function()
    local _, instanceType = IsInInstance()
    inInstance = instanceType == "party" or instanceType == "raid"
end)

-- Hilfen --------------------------------------------------------------------------------------

-- oUF legt die Einheit bei Nameplates unter __unit ab (unit bleibt leer)
local function UnitOf(frame)
    return frame and (frame.__unit or frame.unit)
end

local function Readable(...)
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end

local function Bool(value) -- nil > false, ohne geschützte Werte anzufassen
    if issecretvalue(value) then return value end
    return value and true or false
end

-- Farbe nach (evtl. geschütztem) Wahrheitswert: Blizzard rechnet, wir lesen nie
local function Pick(bool, ifTrue, ifFalse)
    local E = C_CurveUtil.EvaluateColorValueFromBoolean
    return { E(bool, ifTrue[1], ifFalse[1]), E(bool, ifTrue[2], ifFalse[2]), E(bool, ifTrue[3], ifFalse[3]) }
end

local function IsTank()
    if ns.LayoutFlag and ns.LayoutFlag("tank") then return true end -- Layout „Tank“ (sicher)
    local spec = C_SpecializationInfo.GetSpecialization()
    local role = spec and select(5, C_SpecializationInfo.GetSpecializationInfo(spec))
    return role == "TANK"
end

-- Gegnerart: Boss, Leutnant, Caster (hat Mana), Nahkämpfer, unwichtig
local function EnemyType(unit)
    local classification = UnitClassification(unit)
    if not Readable(classification) then return end
    if classification == "minus" or classification == "trivial" then return "trivial" end
    local level, playerLevel = UnitLevel(unit), UnitLevel("player")
    if classification == "worldboss" or (Readable(level) and (level == -1 or level >= playerLevel + 2)) then
        return "boss"
    end
    local lieutenant = UnitIsLieutenant and UnitIsLieutenant(unit)
    if Readable(lieutenant) and lieutenant then return "miniboss" end
    local mana = UnitPowerMax(unit, Enum.PowerType.Mana)
    if Readable(mana) and mana > 0 then return "caster" end
    return "melee"
end

-- Bedrohung > Farbe oder nil (nichts Besonderes)
local function ThreatColor(unit)
    local inCombat = UnitAffectingCombat(unit)
    if not (Readable(inCombat) and inCombat) then return end
    local status = UnitThreatSituation("player", unit)
    if not Readable(status) then return end
    if IsTank() then
        if status == 1 or status == 2 then return C.transition end
        if status == nil or status == 0 then
            -- hat ein anderer Tank die Aggro? Dann türkis, sonst rot (verloren)
            for i = 1, GetNumGroupMembers() do
                local member = (IsInRaid() and "raid" or "party") .. i
                if UnitExists(member) and not UnitIsUnit(member, "player")
                    and UnitGroupRolesAssigned(member) == "TANK" then
                    local other = UnitThreatSituation(member, unit)
                    if Readable(other) and other == 3 then return C.offtank end
                end
            end
            return C.warning
        end
    else
        -- DD: rot nur, wenn du die Aggro hast; hält sie jemand anderes (Tank, dein Begleiter):
        -- Salbei statt der normalen Farbe (Benny 2026-11-07: „nicht so ein hässliches Grau“)
        if status == 3 then return C.warning end
        if status == 1 or status == 2 then return C.transition end
        return C.onTank
    end
end

local function HealthColor(unit)
    if not UnitCanAttack("player", unit) then
        return UnitIsFriend("player", unit) and C.friendly or C.neutral
    end
    local tapDenied = UnitIsTapDenied(unit)
    if Readable(tapDenied) and tapDenied and not UnitPlayerControlled(unit) then return C.tapped end
    local threat = ThreatColor(unit)
    if threat then return threat end
    if inInstance and not UnitIsPlayer(unit) then
        local kind = EnemyType(unit)
        if kind then return C[kind] end
    end
    local reaction = UnitReaction(unit, "player")
    if Readable(reaction) and reaction == 4 then return C.neutral end
    return C.hostile
end

-- oUF: Lebensfarbe komplett selbst bestimmen
local function UpdateHealthColor(self, event, unit)
    local own = UnitOf(self)
    if not own or (unit and unit ~= own) then return end
    local color = HealthColor(own)
    self.Health:SetStatusBarColor(color[1], color[2], color[3])
    ns.ColorBarBackground(self.Health)
end

-- Castbar-Farbe: nicht unterbrechbar (grau) > dein Kick ist bereit (grün) > normal
-- (gelb, Kanalisieren blau). Wichtige Zauber bekommen zusätzlich einen pulsierenden
-- orangen Rahmen – so bleibt jede Information sichtbar.
local function UpdateCastColor(castbar)
    local color = castbar.muiChannel and C.channel or C.cast
    if kickSpell then
        local duration = C_Spell.GetSpellCooldownDuration(kickSpell, true)
        if duration then color = Pick(duration:IsZero(), C.kickReady, color) end
    end
    color = Pick(Bool(castbar.muiNotInterruptible), C.uninterruptible, color)
    castbar:SetStatusBarColor(color[1], color[2], color[3])
    if castbar.importantGlow then
        -- spellID kann geschützt sein: nie direkt prüfen, nur an Blizzard weiterreichen
        local id, important = castbar.muiSpellID, false
        if issecretvalue(id) or id then important = Bool(C_Spell.IsSpellImportant(id)) end
        castbar.importantGlow:SetAlphaFromBoolean(important, 1, 0)
    end
    local unit = UnitOf(castbar.__owner)
    if castbar.targetGlow and unit and PlayerIsSpellTarget then
        local ok, targetsMe = pcall(PlayerIsSpellTarget, unit)
        castbar.targetGlow:SetAlphaFromBoolean(Bool(ok and targetsMe), 1, 0)
    end
end

-- Kick-Strich: weißer Strich auf der Castbar an der Stelle, an der dein Kick wieder bereit ist.
-- Abklingzeit und Zauberdauer können geschützt sein – deshalb rechnet eine unsichtbare
-- Hilfsleiste (Max = Zauberdauer, Wert = Rest-Abklingzeit) die Position aus, der Strich hängt
-- an ihrem Ende. Ist der Kick schon bereit, ist die Castbar grün und der Strich aus.
local function UpdateKickTick(castbar)
    local tick = castbar.kickTick
    local unit = UnitOf(castbar.__owner)
    if not (tick and kickSpell and unit) or castbar.muiChannel then
        if tick then tick:Hide() end
        return
    end
    local cooldown = C_Spell.GetSpellCooldownDuration(kickSpell, true)
    local cast = UnitCastingDuration(unit)
    if not (cooldown and cast) then
        tick:Hide()
        return
    end
    tick:SetMinMaxValues(0, cast:GetTotalDuration())
    tick:SetValue(cooldown:GetRemainingDuration())
    tick:SetAlphaFromBoolean(cooldown:IsZero(), 0, 1)
    tick:Show()
end

-- Sichtbarkeit: Ziel/Zauber voll, andere gedimmt, solange du ein Ziel hast
local function UpdateAlpha(frame)
    local unit = UnitOf(frame)
    if not unit then return end
    local hasTarget = UnitExists("target")
    local isTarget = UnitIsUnit(unit, "target")
    local casting = frame.Castbar and frame.Castbar:IsShown()
    local alpha = 1
    if hasTarget and not (Readable(isTarget) and isTarget) and not casting and not frame.hovered then
        alpha = DIM_ALPHA
    end
    frame:SetAlpha(alpha)
    local target = Readable(isTarget) and isTarget or false
    frame.targetBorder:SetShown(target)
    -- Skalierung um die Mitte (oUF-Frame füllt die Plate, Inhalt ist mittig verankert)
    frame:SetScale(target and TARGET_SCALE or 1)
    frame.hoverGlow:SetShown(frame.hovered or false)
end

local plates = {}

-- Aufbau einer Plate ----------------------------------------------------------------------------

local function CreateAuraRow(self, filterOptions, size, anchor, growthX, x, y, count)
    local auras = self:CreateAuras({
        initialAnchor = anchor,
        growthX = growthX,
        growthY = "UP",
        layoutLimit = count * (size + 2),
    })
    auras:SetPoint(anchor, self.Health, anchor:find("LEFT") and "TOPLEFT" or "TOPRIGHT", x, y)
    auras:SetSize(count * (size + 2), size)
    auras.size = size
    auras.elementSpacing = 2
    auras.showCount = true
    auras.showDuration = true
    auras.durationFormatter = ns.DurationFormatter
    auras.PostCreateButton = ns.StyleAuraButton
    for _, group in ipairs(filterOptions) do auras:AddGroup(group[1], group[2]) end
    return auras
end

local function Style(self, unit)
    ns.SnapBarsOnUnitChange(self)
    plates[self] = true
    local px = ns.PixelSize()
    self:SetSize(WIDTH, HEALTH)

    -- Leben
    local health = ns.CreateBar(self, ns.Snap(HEALTH))
    health:SetSize(ns.Snap(WIDTH), ns.Snap(HEALTH))
    health:SetPoint("CENTER")
    ns.AddBorder(health)
    health.UpdateColor = UpdateHealthColor
    health.colorThreat = true -- nur damit oUF die Bedrohungs-Events anmeldet; Farbe machen wir
    self.Health = health

    -- Ziel: zwei schlanke weiße Pfeile links und rechts, zeigen auf den Balken
    local targetBorder = CreateFrame("Frame", nil, health)
    targetBorder:SetAllPoints()
    for _, side in ipairs({ { "RIGHT", "LEFT", -1, -math.pi / 2 }, { "LEFT", "RIGHT", 1, math.pi / 2 } }) do
        local arrow = ns.UI.Icon(targetBorder, "ChevronDown", HEALTH + 8, { 1, 1, 1 })
        arrow:SetPoint(side[1], health, side[2], side[3], 0)
        arrow:SetRotation(side[4])
    end
    targetBorder:Hide()
    self.targetBorder = targetBorder

    -- Maus drüber: Balken hellt leicht auf
    local hoverGlow = health:CreateTexture(nil, "OVERLAY", nil, 1)
    hoverGlow:SetAllPoints(health:GetStatusBarTexture())
    hoverGlow:SetColorTexture(1, 1, 1, 0.18)
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:Hide()
    self.hoverGlow = hoverGlow

    local name = ns.CreateText(health, 12, "LEFT", "OUTLINE")
    name:SetPoint("LEFT", 4, 0)
    name:SetWidth(NAME_WIDTH)
    -- zu lange Namen kürzen („Lightfeather Petalwing“ > „L. Petalwing“)
    -- In Instanzen sind Namen geschützt (Secret) – dann schneidet WoW nur mit „…“ ab
    self.nameWidth = NAME_WIDTH -- kürzer, solange das Quest-Symbol davor steht
    self.ShortenName = function(frame, text) return ns.ShortenName(text, name, frame.nameWidth) end
    self:Tag(name, "[mui:name]")
    self.NameText = name
    -- Begleiter: kleine Zeile unter dem Namen („Kalitheras Begleiter“), nur bei freundlichen Plates
    local sub = ns.CreateText(self, 10, "CENTER", "OUTLINE")
    sub:SetTextColor(0.8, 0.8, 0.8)
    sub:Hide()
    self.SubText = sub

    local percent = ns.CreateText(health, 10, "RIGHT", "OUTLINE")
    percent:SetPoint("RIGHT", -4, 0)
    self:Tag(percent, "[perhp]%")
    self.PercentText = percent

    -- Castbar direkt unter dem Leben, gleich breit; Symbol links im Rahmen, Text im Balken
    local cast = ns.Snap(CAST)
    local castFrame = CreateFrame("Frame", nil, self)
    castFrame:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -GAP - 2 * px)
    castFrame:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -GAP - 2 * px)
    castFrame:SetHeight(cast)
    local castbar = ns.CreateBar(self, cast)
    castbar:SetPoint("TOPLEFT", castFrame, "TOPLEFT", cast + px, 0)
    castbar:SetPoint("BOTTOMRIGHT", castFrame, "BOTTOMRIGHT")
    castbar.PostUpdateColor = nil
    castFrame:SetParent(castbar) -- Rahmen samt Symbol nur sichtbar, solange gezaubert wird
    castFrame:SetFrameLevel(castbar:GetFrameLevel() + 2)
    ns.AddBorder(castFrame)
    local icon = castFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT")
    icon:SetSize(cast, cast)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon
    local divider = castFrame:CreateTexture(nil, "OVERLAY")
    divider:SetColorTexture(0, 0, 0, 1)
    divider:SetPoint("TOPLEFT", icon, "TOPRIGHT")
    divider:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT")
    divider:SetWidth(px)
    castbar.Text = ns.CreateText(castFrame, 11, "LEFT", "OUTLINE")
    castbar.Text:SetPoint("LEFT", castbar, "LEFT", 4, 0)
    castbar.Text:SetPoint("RIGHT", castbar, "RIGHT", -32, 0)
    castbar.Time = ns.CreateText(castFrame, 10, "RIGHT", "OUTLINE")
    castbar.Time:SetPoint("RIGHT", castbar, "RIGHT", -4, 0)
    castbar.timeToHold = 0.4
    -- wichtiger Zauber: orangener Rahmen, pulsierend (Sichtbarkeit setzt UpdateCastColor)
    local importantGlow = CreateFrame("Frame", nil, castbar)
    importantGlow:SetPoint("TOPLEFT", castFrame, -2 * px, 2 * px)
    importantGlow:SetPoint("BOTTOMRIGHT", castFrame, 2 * px, -2 * px)
    importantGlow:SetFrameLevel(castbar:GetFrameLevel() + 5)
    local pulseHolder = CreateFrame("Frame", nil, importantGlow)
    pulseHolder:SetAllPoints()
    for _, edge in ipairs(ns.AddBorder(pulseHolder, false, 2)) do edge:SetVertexColor(unpack(C.important)) end
    local pulse = pulseHolder:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.4)
    pulse:Play()
    importantGlow:SetAlpha(0)
    castbar.importantGlow = importantGlow
    local targetGlow = CreateFrame("Frame", nil, castbar)
    targetGlow:SetPoint("TOPLEFT", castFrame, -px, px)
    targetGlow:SetPoint("BOTTOMRIGHT", castFrame, px, -px)
    targetGlow:SetFrameLevel(castbar:GetFrameLevel() + 4)
    for _, edge in ipairs(ns.AddBorder(targetGlow, false, 2)) do edge:SetVertexColor(unpack(C.targetsYou)) end
    targetGlow:SetAlpha(0)
    castbar.targetGlow = targetGlow
    local kickTick = CreateFrame("StatusBar", nil, castbar)
    kickTick:SetAllPoints(castbar)
    kickTick:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    kickTick:GetStatusBarTexture():SetAlpha(0)
    kickTick:SetFrameLevel(castbar:GetFrameLevel() + 3)
    local line = kickTick:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(1, 1, 1, 1)
    line:SetWidth(2 * px)
    line:SetPoint("TOP", kickTick:GetStatusBarTexture(), "TOPRIGHT", 0, 2 * px)
    line:SetPoint("BOTTOM", kickTick:GetStatusBarTexture(), "BOTTOMRIGHT", 0, -2 * px)
    kickTick:Hide()
    castbar.kickTick = kickTick
    -- oUF hält Zauber-ID, Unterbrechbarkeit und Kanalisieren intern – wir merken sie uns aus
    -- den Rückmeldungen (Werte können geschützt sein, werden nur an Blizzard weitergereicht)
    castbar.PostCastStart = function(bar, unit, spellID, notInterruptible)
        local channel = UnitChannelInfo(unit)
        bar.muiChannel = issecretvalue(channel) or channel ~= nil
        bar.muiSpellID = spellID
        bar.muiNotInterruptible = notInterruptible
        UpdateCastColor(bar)
        UpdateKickTick(bar)
        UpdateAlpha(self)
    end
    castbar.PostCastInterruptible = function(bar, _, _, notInterruptible)
        bar.muiNotInterruptible = notInterruptible
        UpdateCastColor(bar)
    end
    castbar.PostCastStop = function() UpdateAlpha(self) end
    castbar.PostCastFail = function(bar)
        bar:SetStatusBarColor(unpack(C.interrupted))
        UpdateAlpha(self)
    end
    -- Kick kann mitten im Zauber bereit werden: Farbe regelmäßig nachziehen
    local elapsedSince = 0
    castbar:HookScript("OnUpdate", function(bar, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince > 0.1 then
            elapsedSince = 0
            UpdateCastColor(bar)
        end
    end)
    self.Castbar = castbar
    self.CastFrame = castFrame

    -- Auren: eigene Debuffs oben links, Buffs zum Entreißen/Beruhigen oben rechts,
    -- Kontrolleffekte rechts neben der Plate
    self.AuraRows = {
        CreateAuraRow(self, { { "HARMFUL|PLAYER|INCLUDE_NAME_PLATE_ONLY", { maxFrameCount = 5 } } },
            AURA, "BOTTOMLEFT", "RIGHT", 0, GAP + 2 * px, 5),
        CreateAuraRow(self, {
            { "HELPFUL|RAID_PLAYER_DISPELLABLE", { maxFrameCount = 3, dispelBand = "helpful" } },
            { "HELPFUL|IMPORTANT", { maxFrameCount = 2 } },
        }, AURA, "BOTTOMRIGHT", "LEFT", 0, GAP + 2 * px, 4),
    }
    local cc = self:CreateAuras({ initialAnchor = "LEFT", growthX = "RIGHT", growthY = "UP", layoutLimit = 2 * (CC_AURA + 2) })
    cc:SetPoint("LEFT", health, "RIGHT", GAP + 2 * px, 0)
    cc:SetSize(2 * (CC_AURA + 2), CC_AURA)
    cc.size = CC_AURA
    cc.elementSpacing = 2
    cc.showDuration = true
    cc.durationFormatter = ns.DurationFormatter
    cc.PostCreateButton = ns.StyleAuraButton
    cc:AddGroup("HARMFUL|CROWD_CONTROL", { maxFrameCount = 2 })
    self.AuraRows[3] = cc

    -- Zielmarkierung links, M+-Anteil unten links
    local raidIcon = health:CreateTexture(nil, "OVERLAY", nil, 7)
    raidIcon:SetSize(22, 22)
    raidIcon:Hide() -- sonst sieht man bis zum ersten Update das ganze Marker-Bild
    raidIcon:SetPoint("RIGHT", health, "LEFT", -HEALTH - 10, 0)
    self.RaidTargetIndicator = raidIcon

    local forces = ns.CreateText(self, 10, "LEFT", "OUTLINE")
    forces:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -GAP - cast - 4)
    forces:SetTextColor(1, 0.85, 0)
    self.ForcesText = forces

    -- Quest-Gegner: gelbes „!“ mit Fortschritt im Balken direkt vor dem Namen (der rückt dann nach
    -- rechts und wird entsprechend kürzer, siehe UpdateNamePrefix)
    local quest = CreateFrame("Frame", nil, health)
    quest:SetSize(14, 14)
    local questIcon = ns.UI.Icon(quest, "Quest", 14, ns.STYLE.questColor)
    questIcon:SetPoint("LEFT")
    local questText = ns.CreateText(quest, 11, "LEFT", "OUTLINE")
    questText:SetPoint("LEFT", questIcon, "RIGHT", 1, 0)
    questText:SetTextColor(unpack(ns.STYLE.questColor))
    quest.Text = questText
    quest:Hide()
    self.QuestMarker = quest

    -- Rar/Elite: Blizzards eigene Symbole davor (Elite nur außerhalb von Instanzen – dort ist fast alles Elite)
    local classIcon = health:CreateTexture(nil, "OVERLAY", nil, 6)
    classIcon:SetSize(16, 16)
    classIcon:Hide()
    self.ClassificationIcon = classIcon

    -- Execute-Linie (Core/Style.lua)
    ns.AddExecuteLine(health)
end

-- Fortschritt der ersten offenen Quest-Zeile aus Blizzards Tooltip-Daten zur Einheit
-- („3/8 Kobolde getötet“ > „3/8“, „Gebiet befreit: 45 %“ > „45%“). Geschützt > nichts.
local QUEST_LINE = Enum.TooltipDataLineType.QuestObjective
local function QuestProgress(unit)
    local data = C_TooltipInfo.GetUnit(unit)
    if not Readable(data) or not data or not Readable(data.lines) or not data.lines then return end
    for _, line in ipairs(data.lines) do
        if Readable(line) and Readable(line.type, line.completed, line.leftText) and line.type == QUEST_LINE
            and not line.completed and line.leftText then
            local have, need = line.leftText:match("(%d+)%s*/%s*(%d+)")
            if have then return have .. "/" .. need end
            local percent = line.leftText:match("(%d+)%s*%%")
            if percent then return percent .. "%" end
            return ""
        end
    end
end

-- Symbol für Rar/Elite wie bei Blizzards Plates (NamePlateClassificationFrameMixin)
local function ClassificationAtlas(unit)
    if ns.db.plateClassification == false then return end
    local classification = UnitClassification(unit)
    if not Readable(classification) then return end
    if classification == "rare" then return "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" end
    if classification == "rareelite" then return "nameplates-icon-elite-silver" end
    if (classification == "elite" or classification == "worldboss") and not inInstance then
        return "nameplates-icon-elite-gold"
    end
end

-- Gehört der Gegner zu einer aktiven Quest? Fragt Blizzard direkt (C_QuestLog), kein Tooltip-Raten.
-- Nicht in M+ (Quests zählen dort nicht).
local function IsQuestUnit(unit)
    if C_PartyInfo.IsChallengeModeActive and C_PartyInfo.IsChallengeModeActive() then return false end
    local related = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    return Readable(related) and related or false
end

-- Reihe im Balken vor dem Namen: [Rar/Elite][! 3/8] Name. Der Name rückt nach rechts und wird
-- entsprechend kürzer. Läuft nach ApplyFriendly (setzt den Namen zurück).
local function UpdateNamePrefix(frame)
    local unit = UnitOf(frame)
    local enemy = unit and not frame.isFriendly
    local atlas = enemy and ClassificationAtlas(unit)
    local quest = enemy and IsQuestUnit(unit)
    local icon, marker, name = frame.ClassificationIcon, frame.QuestMarker, frame.NameText

    local x = 2
    icon:ClearAllPoints()
    if atlas then
        icon:SetAtlas(atlas)
        icon:SetPoint("LEFT", frame.Health, "LEFT", x, 0)
        x = x + 16 + 2
    end
    icon:SetShown(atlas and true or false)
    marker:ClearAllPoints()
    if quest then
        local progress = QuestProgress(unit) or ""
        marker.Text:SetText(progress)
        local markerWidth = 14 + (progress ~= "" and marker.Text:GetStringWidth() + 1 or 0)
        marker:SetWidth(markerWidth)
        marker:SetPoint("LEFT", frame.Health, "LEFT", x, 0)
        x = x + markerWidth + 3
    end
    marker:SetShown(quest)

    local offset = x > 2 and x or 4
    -- freundliche Namens-Plates (NPCs, Spieler, Begleiter): ohne Kürzung/„…“ (Benny 2026-11-08)
    local width = frame.isFriendly and 400 or NAME_WIDTH - (offset - 4)
    if frame.nameWidth ~= width then
        frame.nameWidth = width
        name:SetWidth(width)
        frame:UpdateTags() -- Name passend zur neuen Breite neu kürzen
    end
    if frame.isFriendly then return end
    name:ClearAllPoints()
    name:SetPoint("LEFT", frame.Health, "LEFT", offset, 0)
end

-- M+-Anteil (Blizzard rechnet; nur in aktiven Schlüsselsteinen, nur Gegner)
local function UpdateForces(frame)
    local unit = UnitOf(frame)
    local show = unit and C_PartyInfo.IsChallengeModeActive and C_PartyInfo.IsChallengeModeActive()
        and UnitCanAttack("player", unit) and not UnitIsPlayer(unit)
    local percent
    if show then percent = select(2, C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)) end
    if show and percent then
        frame.ForcesText:SetFormattedText("%.2f%%", percent)
        frame.ForcesText:Show()
    else
        frame.ForcesText:Hide()
    end
end

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Blizzards eigener Plate-Knopf bleibt bei oUF unsichtbar über unserer Plate liegen und fängt den
-- Klick ab. Er bleibt an seinem Platz (das Spiel stapelt die Plates nach ihm), wird aber
-- unsichtbar und klick-durchlässig – samt allen Kindern.
local function NoMouse(frame)
    if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
    for _, child in ipairs({ frame:GetChildren() }) do NoMouse(child) end
end

local function ParkBlizzardFrame(frame)
    local nameplate = frame:GetParent()
    local blizz = nameplate and nameplate.UnitFrame
    if not blizz then return end
    blizz:SetAlpha(0)
    NoMouse(blizz)
    -- Blizzards „Soft Target“-Symbol (Schwert/Hand) hängt oUF an die Plate – liegt mitten im Namen
    if blizz.SoftTargetFrame and blizz.SoftTargetFrame:GetParent() ~= hiddenParent then
        blizz.SoftTargetFrame:SetParent(hiddenParent)
    end
end

-- Klickbereich wie bei Blizzard: Lebensbalken plus etwas Rand, direkt an der Plate
local function SetHitBox(frame)
    local nameplate = frame:GetParent()
    if not (nameplate and nameplate.SetAllHitTestPoints) then return end
    if nameplate.CanChangeHitTestPoints and not nameplate:CanChangeHitTestPoints() then return end
    if not frame.HitBox then
        frame.HitBox = CreateFrame("Frame", nil, nameplate)
        frame.HitBox:SetPoint("CENTER", nameplate, "CENTER")
        frame.HitBox:SetSize(WIDTH + 20, HEALTH + 10)
    end
    nameplate:ClearAllHitTestPoints()
    nameplate:SetAllHitTestPoints(frame.HitBox)
end

-- Stapeln: Blizzard schiebt Plates nach diesem Bereich auseinander – Lebensbalken plus Castbar,
-- sonst überlappt die Castbar die Plate darunter. Wie Plater (Midnight): Bereich hängt mittig am
-- eigenen Plate-Frame und wird bei jedem Anzeigen neu gemeldet. /mui stack zeigt ihn grün.
local STACK_H = HEALTH + GAP + CAST + 10
local showStackBoxes = false
local function SetStackBox(frame)
    local nameplate = frame:GetParent()
    if not (nameplate and nameplate.SetStackingBoundsFrame) then return end
    if not frame.StackBox then
        frame.StackBox = CreateFrame("Frame", nil, frame)
        frame.StackBox.debug = frame.StackBox:CreateTexture(nil, "BACKGROUND")
        frame.StackBox.debug:SetAllPoints()
    end
    local box = frame.StackBox
    box:ClearAllPoints()
    -- Lebensbalken sitzt mittig, Castbar darunter: Bereich mittig um beides
    box:SetPoint("CENTER", frame, "CENTER", 0, -(GAP + CAST) / 2)
    box:SetSize(WIDTH + 10, STACK_H)
    -- Blizzard zählt nur einen Bereich mit gezeichneter Fläche: Textur immer an, sonst unsichtbar
    -- (wie Plater; ohne sie stapelte nichts – Benny 2026-11-07)
    box.debug:SetColorTexture(0.1, 0.8, 0.1, showStackBoxes and 0.35 or 0)
    nameplate:SetStackingBoundsFrame(box)
end

ns.AddCommand("stack", "show the nameplate stacking area", function()
    showStackBoxes = not showStackBoxes
    for frame in pairs(plates) do
        if frame.StackBox then frame.StackBox.debug:SetColorTexture(0.1, 0.8, 0.1, showStackBoxes and 0.35 or 0) end
    end
    local value = C_CVar.GetCVar("nameplateStackingTypes")
    local on = C_CVar.GetCVarBitfield and C_CVar.GetCVarBitfield("nameplateStackingTypes", Enum.NamePlateStackType.Enemy)
    ns.Print("Stacking: %s (CVar %s)", tostring(on), tostring(value))
end)

-- Blizzard markiert Nebenmobs als „vereinfacht“ und verkleinert dann intern ihre Plate – sie
-- werden mit viel zu wenig Abstand gestapelt. Unsere Plates sind immer gleich groß > aus.
local function NotSimplified(unit)
    if unit and C_NamePlateManager.SetNamePlateSimplified then
        pcall(C_NamePlateManager.SetNamePlateSimplified, unit, false)
    end
end
if NamePlateUnitFrameMixin and NamePlateUnitFrameMixin.UpdateIsSimplified then
    hooksecurefunc(NamePlateUnitFrameMixin, "UpdateIsSimplified", function(blizzFrame)
        local nameplate = blizzFrame.GetNamePlateFrame and blizzFrame:GetNamePlateFrame()
        if nameplate and nameplate.unitFrame and nameplate.unitFrame.isNamePlate then NotSimplified(blizzFrame.unit) end
    end)
end

-- Blizzards (versteckter) Plate-Frame setzt den Klickbereich bei jeder Anpassung neu auf seinen
-- eigenen Balken – direkt danach wieder unseren setzen (gleicher Tick, auch im Kampf erlaubt)
if NamePlateUnitFrameMixin and NamePlateUnitFrameMixin.UpdateHitTestArea then
    hooksecurefunc(NamePlateUnitFrameMixin, "UpdateHitTestArea", function(blizzFrame)
        local nameplate = blizzFrame.GetNamePlateFrame and blizzFrame:GetNamePlateFrame()
        local frame = nameplate and nameplate.unitFrame
        if frame and frame.isNamePlate and frame:IsShown() then SetHitBox(frame) end
    end)
end

-- Besitzer eines Begleiters aus der Tooltip-Zeile („Begleiter von Kalithera Novaris“ / „X's Pet“) –
-- nur der Vorname. In Instanzen können Texte geschützt sein, dann keine Zeile.
local OWNER_PATTERNS
local function OwnerPatterns()
    if OWNER_PATTERNS then return OWNER_PATTERNS end
    OWNER_PATTERNS = {}
    for _, key in ipairs({ "UNITNAME_TITLE_PET", "UNITNAME_TITLE_MINION", "UNITNAME_TITLE_GUARDIAN",
        "UNITNAME_TITLE_COMPANION", "UNITNAME_TITLE_CHARM", "UNITNAME_TITLE_CREATION" }) do
        local format = _G[key]
        if type(format) == "string" and format:find("%%s") then
            local escaped = format:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
            local pattern = "^" .. escaped:gsub("%%s", "(.+)") .. "$"
            OWNER_PATTERNS[#OWNER_PATTERNS + 1] = pattern
        end
    end
    return OWNER_PATTERNS
end

local function PetOwner(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    local lines = ok and data and data.lines
    if not lines then return end
    for i = 2, math.min(#lines, 3) do
        local text = lines[i] and lines[i].leftText
        if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
            for _, pattern in ipairs(OwnerPatterns()) do
                local owner = text:match(pattern)
                if owner then return (owner:match("^(%S+)")) end
            end
        end
    end
end

local FRIENDLY_NAME_SIZE = { small = 12, medium = 14, large = 16 } -- Einstellung „Namensgröße“

-- Titel eines NPCs aus der Tooltip-Zeile unter dem Namen („Bergbaulehrer“); Stufen-Zeilen zählen nicht
local function NpcTitle(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    local line = ok and data and data.lines and data.lines[2]
    local text = line and line.leftText
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) or text == "" then return end
    if text:find("%d") then return end -- „Stufe 30“, „Level 12 Humanoid“
    return text
end

-- „Kalitheras Begleiter“ / „Mox' Begleiter“ (deutscher Genitiv), sonst „Kalithera's pet“
local function PetTitle(owner)
    if GetLocale() == "deDE" then
        local ends = owner:lower():match("[sßxz]$") or owner:lower():match("tz$")
        return (ends and (owner .. "'") or (owner .. "s")) .. " " .. L["Companion"]
    end
    return L["%s's pet"]:format(owner)
end

-- Freundliche Plates: nur der Name (Klassen- bzw. Reaktionsfarbe, 14 px), keine Balken; Begleiter mit
-- kurzer Besitzer-Zeile darunter (Benny 2026-11-08)
local function ApplyFriendly(frame, unit)
    local friendly = not UnitCanAttack("player", unit)
    frame.isFriendly = friendly
    frame.Health:SetAlpha(friendly and 0 or 1)
    frame.Castbar:SetAlpha(friendly and 0 or 1)
    for _, row in ipairs(frame.AuraRows) do row:SetShown(not friendly) end
    frame.NameText:ClearAllPoints()
    frame.NameText:SetParent(friendly and frame or frame.Health)
    local controlled = friendly and UnitPlayerControlled(unit)
    if issecretvalue and issecretvalue(controlled) then controlled = false end -- in Instanzen ggf. geschützt
    local isPlayer = UnitIsPlayer(unit)
    if issecretvalue and issecretvalue(isPlayer) then isPlayer = false end
    local owner = controlled and not isPlayer and PetOwner(unit) or nil
    -- zweite Zeile: Besitzer beim Begleiter, sonst Titel des NPCs („Bergbaulehrer“)
    if ns.db.npPetOwner == false then owner = nil end
    local subline = owner and PetTitle(owner)
        or (friendly and not isPlayer and not controlled and ns.db.npNpcTitle ~= false and NpcTitle(unit)) or nil
    ns.SetFont(frame.NameText, friendly and (FRIENDLY_NAME_SIZE[ns.db.npNameSize or "medium"] or 14) or 12, "OUTLINE")
    frame.SubText:SetShown(subline ~= nil)
    if subline then
        frame.SubText:ClearAllPoints()
        frame.SubText:SetPoint("TOP", frame.NameText, "BOTTOM", 0, -1)
        frame.SubText:SetText(subline)
    end
    if friendly then
        frame.NameText:SetPoint("CENTER", frame, "CENTER", 0, subline and 6 or 0)
        frame.NameText:SetJustifyH("CENTER")
        -- Spieler: Klassenfarbe; NPCs/Begleiter: freundlich Salbei, neutral gelb, feindlich (nicht
        -- angreifbar, z. B. Horde auf PvE) rot (Benny 2026-11-08)
        local _, class = UnitClass(unit)
        local color = isPlayer and Readable(class) and class and RAID_CLASS_COLORS[class]
        if color then
            frame.NameText:SetTextColor(color.r, color.g, color.b)
        elseif not isPlayer then
            local reaction = UnitReaction(unit, "player")
            if not Readable(reaction) then reaction = nil end
            local c = (reaction and reaction >= 5 and ns.UI.ACCENT) or (reaction == 4 and C.neutral)
                or (reaction and reaction <= 3 and C.hostile) or ns.UI.ACCENT
            frame.NameText:SetTextColor(c[1], c[2], c[3])
        else
            frame.NameText:SetTextColor(1, 1, 1)
        end
        frame.PercentText:Hide()
    else
        frame.NameText:SetPoint("LEFT", frame.Health, "LEFT", 4, 0)
        frame.NameText:SetJustifyH("LEFT")
        frame.NameText:SetTextColor(1, 1, 1)
        frame.PercentText:Show()
    end
end

oUF:RegisterStyle("MeredanPlate", Style)

oUF:Factory(function(self)
    if ns.db.nameplates == false then return end
    -- zwei Nameplate-Addons gleichzeitig vertragen sich nicht
    if C_AddOns.IsAddOnLoaded("Plater") then
        ns.Print(L["Another nameplate addon is active – mUI nameplates stay off. Disable it to use ours."])
        return
    end
    self:SetActiveStyle("MeredanPlate")
    local driver = self:SpawnNamePlates("MeredanUIPlate")
    driver:SetSize(PLATE_W, PLATE_H) -- Größe der Plate (Klickbereich ist darauf begrenzt)
    -- Blizzard setzt die Plate-Größe bei jedem Optionen-/Fenster-Wechsel auf seine eigene zurück
    -- (auch beim Einloggen) – danach stapelt es zu eng. Unsere Größe direkt wieder setzen.
    if NamePlateDriverFrame and NamePlateDriverFrame.UpdateNamePlateSize then
        hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateSize", function()
            ns.AfterCombat(function() C_NamePlate.SetNamePlateSize(PLATE_W, PLATE_H) end)
        end)
    end
    driver:SetAddedCallback(function(frame, _, unit)
        ParkBlizzardFrame(frame)
        SetHitBox(frame)
        SetStackBox(frame)
        NotSimplified(unit)
        ApplyFriendly(frame, unit)
        UpdateForces(frame)
        UpdateNamePrefix(frame)
        UpdateAlpha(frame)
    end)
    driver:SetTargetCallback(function() end)
    -- oUF vergrößert den Klickbereich mit riesigen negativen Werten – das macht die Plates
    -- unklickbar. 0 = genau unser HitBox-Bereich.
    local function ResetInsets()
        ns.AfterCombat(function()
            C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy, 0, 0, 0, 0)
            C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Friendly, 0, 0, 0, 0)
        end)
    end
    ResetInsets()
    C_Timer.After(0, ResetInsets) -- nach oUFs eigenem PLAYER_LOGIN
    -- Feindliche Plates stapeln statt überlappen (Blizzard-Option, einmalig; danach gilt deine Wahl)
    if not ns.db.nameplatesStackSet and C_CVar.GetCVar("nameplateStackingTypes") then
        ns.AfterCombat(function()
            local ok = pcall(C_CVar.SetCVarBitfield, "nameplateStackingTypes", Enum.NamePlateStackType.Enemy, true)
            if ok then ns.db.nameplatesStackSet = true end
        end)
    end
    -- Alle Plates gleich groß (einmalig): Blizzard vergrößert sonst das Ziel (120 %) und verkleinert
    -- entfernte – gestapelt wird aber nach der normalen Größe, das Ziel überlappte dann die anderen
    -- (Benny 2026-11-07, Dungeon). Das Ziel hebt mUI über das Dimmen der anderen hervor.
    if not ns.db.nameplatesScaleSet then
        ns.AfterCombat(function()
            for _, cvar in ipairs({ "nameplateSelectedScale", "nameplateMinScale", "nameplateMaxScale" }) do
                if C_CVar.GetCVar(cvar) then C_CVar.SetCVar(cvar, "1") end
            end
            ns.db.nameplatesScaleSet = true
        end)
    end
    -- Begleiter freundlicher Spieler mit unserer Plate statt Blizzards Weltnamen (der Text dort lässt sich
    -- nicht kürzen) – einmalig; wer es danach umstellt, behält es (Benny 2026-11-08)
    if not ns.db.nameplatesPetsSet then
        ns.AfterCombat(function()
            if C_CVar.GetCVar("nameplateShowFriendlyPlayerPets") then C_CVar.SetCVar("nameplateShowFriendlyPlayerPets", "1") end
            if C_CVar.GetCVar("UnitNameFriendlyPetName") then C_CVar.SetCVar("UnitNameFriendlyPetName", "0") end
            ns.db.nameplatesPetsSet = true
        end)
    end
    -- Freundliche NPCs (Händler, Lehrer …) mit unserer Namens-Plate statt Blizzards Weltnamen (einmalig;
    -- wer es danach umstellt, behält es) – Benny 2026-11-08
    if not ns.db.nameplatesNpcSet then
        ns.AfterCombat(function()
            if C_CVar.GetCVar("nameplateShowFriendlyNpcs") then C_CVar.SetCVar("nameplateShowFriendlyNpcs", "1") end
            for _, cvar in ipairs({ "UnitNameNPC", "UnitNameFriendlySpecialNPCName", "UnitNameInteractiveNPC" }) do
                if C_CVar.GetCVar(cvar) then C_CVar.SetCVar(cvar, "0") end
            end
            ns.db.nameplatesNpcSet = true
        end)
    end
    -- Blizzards Weltnamen ganz aus, nur noch mUI-Namen (Benny 2026-11-08: „Blizzard-Namensanzeige
    -- ausschalten“) – einmalig; der eigene Name bleibt wie eingestellt (dafür gibt es keine Plate)
    if not ns.db.nameplatesWorldNamesSet then
        ns.AfterCombat(function()
            if C_CVar.GetCVar("nameplateShowFriendlyPlayers") then C_CVar.SetCVar("nameplateShowFriendlyPlayers", "1") end
            for _, cvar in ipairs({ "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNameHostleNPC",
                "UnitNamePlayerGuild", "UnitNameFriendlyGuardianName", "UnitNameFriendlyMinionName",
                "UnitNameFriendlyTotemName", "UnitNameEnemyPetName", "UnitNameEnemyGuardianName",
                "UnitNameEnemyMinionName", "UnitNameEnemyTotemName" }) do
                if C_CVar.GetCVar(cvar) then C_CVar.SetCVar(cvar, "0") end
            end
            ns.db.nameplatesWorldNamesSet = true
        end)
    end
    -- Plates immer zeigen, nicht nur im Kampf (einmalig; wer es danach umstellt, behält es)
    if not ns.db.nameplatesShowAllSet then
        ns.db.nameplatesShowAllSet = true
        C_CVar.SetCVar("nameplateShowAll", "1")
    end
end)

-- Ziel gewechselt: alle Plates neu dimmen; Kampf/Bedrohung: Farben neu
-- „mUI-Namen statt Blizzard-Namen“ (Benny 2026-11-08): an = Blizzards Weltnamen aus, freundliche NPCs
-- und Begleiter auf mUI-Plates; aus = alles auf Blizzards Standardwerte. Reine CVars, wirkt ohne Reload.
local WORLD_NAME_CVARS = { "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNameHostleNPC",
    "UnitNamePlayerGuild", "UnitNameFriendlyGuardianName", "UnitNameFriendlyMinionName", "UnitNameFriendlyTotemName",
    "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameEnemyMinionName", "UnitNameEnemyTotemName",
    "UnitNameNPC", "UnitNameFriendlySpecialNPCName", "UnitNameInteractiveNPC", "UnitNameFriendlyPetName" }
local MUI_PLATE_CVARS = { "nameplateShowFriendlyNpcs", "nameplateShowFriendlyPlayerPets", "nameplateShowFriendlyPlayers" }
function ns.SetMuiNames(useMui)
    ns.db.npMuiNames = useMui and true or false
    ns.AfterCombat(function()
        local function Default(cvar)
            local value = C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(cvar)
            return value or "1"
        end
        for _, cvar in ipairs(WORLD_NAME_CVARS) do
            if C_CVar.GetCVar(cvar) then C_CVar.SetCVar(cvar, useMui and "0" or Default(cvar)) end
        end
        for _, cvar in ipairs(MUI_PLATE_CVARS) do
            if C_CVar.GetCVar(cvar) then C_CVar.SetCVar(cvar, useMui and "1" or Default(cvar)) end
        end
    end)
end

-- Einstellungen geändert (Namensgröße, Titel, Besitzer): alle offenen Plates neu aufbauen
function ns.RefreshNamePlates()
    for frame in pairs(plates) do
        local unit = UnitOf(frame)
        if unit and frame:IsShown() then
            ApplyFriendly(frame, unit)
            UpdateNamePrefix(frame)
        end
    end
end

ns:On("PLAYER_TARGET_CHANGED", function()
    for frame in pairs(plates) do UpdateAlpha(frame) end
end)
-- Quest-Fortschritt geändert: alle Plates einmal gesammelt nachziehen (Ereignisse kommen gehäuft)
local questPending = false
local function QueueQuestUpdate()
    if questPending then return end
    questPending = true
    C_Timer.After(0.2, function()
        questPending = false
        for frame in pairs(plates) do if UnitOf(frame) then UpdateNamePrefix(frame) end end
    end)
end
ns:On("QUEST_LOG_UPDATE", QueueQuestUpdate)
ns:On("UNIT_CLASSIFICATION_CHANGED", QueueQuestUpdate)
ns:On("QUEST_LOG_CRITERIA_UPDATE", QueueQuestUpdate)
ns:On("UNIT_QUEST_LOG_CHANGED", function(_, unit) if unit == "player" then QueueQuestUpdate() end end)
ns:On("SCENARIO_CRITERIA_UPDATE", function()
    for frame in pairs(plates) do if UnitOf(frame) then UpdateForces(frame) end end
end)
for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_THREAT_LIST_UPDATE" }) do
    ns:On(event, function()
        for frame in pairs(plates) do
            if UnitOf(frame) and not frame.isFriendly then UpdateHealthColor(frame) end
        end
    end)
end

-- Maus über einer Plate: es gibt kein „Maus weg“-Ereignis, deshalb kurz nachprüfen
local hoverTicker
local function UpdateHover()
    local any = false
    for frame in pairs(plates) do
        local unit = UnitOf(frame)
        local over = false
        if unit and frame:IsShown() then
            local same = UnitIsUnit(unit, "mouseover")
            over = Readable(same) and same or false
        end
        if frame.hovered ~= over then
            frame.hovered = over
            UpdateAlpha(frame)
        end
        any = any or over
    end
    if not any and hoverTicker then
        hoverTicker:Cancel()
        hoverTicker = nil
    end
end
ns:On("UPDATE_MOUSEOVER_UNIT", function()
    UpdateHover()
    if not hoverTicker then hoverTicker = C_Timer.NewTicker(0.1, UpdateHover) end
end)
