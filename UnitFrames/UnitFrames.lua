-- Layout der Unitframes (oUF-Style "Meredan"). Ziel spiegelt den Spieler.
--
--                       [Buffs, innen beginnend ...]
--   ●                                         NAME     ← Name groß, auf der Oberkante
--   ┌──────────────────────────────────────────────┐
--   │                  ⚔ / 💤                       │  ← Status in der Mitte; beim Zaubern
--   │                                              │    liegt hier die Zauberleiste drüber,
--   │                                              │    das Zauber-Icon außen daneben
--   │ Energie                                Leben │
--   └──────────────────────────────────────────────┘
--   ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬   ← Ressource, schmal, freistehend
--                      [Debuffs, eine Reihe, innen ...]
--                                          [Pet / Ziel des Ziels]
-- ● = Zielmarkierung. „Innen“ = zur Bildschirmmitte (Spieler rechts, Ziel links).
local _, ns = ...
local oUF = ns.oUF

local SIZE = {
    width = 270,       -- Stufe „Normal“; ns.db.frameSize skaliert (ns.FRAME_SCALES)
    health = 32,       -- Stufe „Normal“
    power = 6,
    classPower = 10,   -- Klassenleiste mittig zwischen den Frames: Kästchenhöhe (Breite = Hauptleiste)
    classPowerGap = 12, -- Abstand Klassenleiste ↔ Oberkante der Frames (darunter: Aktionsleiste)
    powerGap = 2,      -- Abstand Lebensbalken ↔ Ressource
    gap = 4,           -- Abstand zwischen den Leisten unter dem Lebensbalken
    nameSize = 24,
    valueSize = 12,    -- Leben/Energie im Balken
    auraSize = 30,     -- Ziel-Icongröße: breitere Frames zeigen mehr Auren statt größerer
    auraOffset = 6,    -- Abstand Frame ↔ Aura-Reihe
}

-- Kleine Frames (Pet, Ziel des Ziels): so breit wie der große Frame, Name und Prozent
-- im Lebensbalken, beim Pet darunter die Ressource.
local SMALL = {
    health = 22,
    power = 4,
}

-- Seitliche Frames (Fokus, Boss 1–5), schlank wie Pet/Ziel des Ziels (Name und Prozent im
-- Balken, Ressource darunter), dazu Zauberleiste als Overlay mit Icon außen rechts
-- (Unterbrechen!), Zielmarkierung auf der Oberkante und eine Reihe Debuffs darunter (eigene zuerst).
-- Fokus: rechts neben dem Ziel, oben bündig. Bosse: Spalte in einer Linie über dem Fokus, oben
-- bündig mit dem Questlog (Bennys Wunsch 2026-10-24 – rechts ist nach unten Platz für alle fünf).
local SIDE = {
    width = 200,     -- wird schmaler, wenn der Bildschirm (hohe UI-Skalierung) nicht reicht
    health = 26,
    power = 4,
    auraSize = 20,
    auraOffset = 6,  -- Abstand Frame ↔ Debuff-Reihe
    gap = 10,        -- Abstand zwischen den Boss-Frames (unter der Debuff-Reihe)
}
local SIDE_BUFFS = 3 -- wichtige Gegner-Buffs rechts in der Aura-Reihe (der Rest sind Debuffs)

-- Standardplatz der Frames: Innenkante INNER_X von der Bildschirmmitte, Oberkante TOP_Y darunter.
local INNER_X, TOP_Y = 260, 200

-- Größenstufen statt Regler (Benny 2026-11-07): Spieler + Ziel gemeinsam, Begleiter, Ziel des Ziels
-- und Fokus wachsen mit; Bossframes haben eine eigene Stufe. Anker bleiben (Innenkante, Oberkante),
-- die Frames wachsen nach außen und unten.
ns.FRAME_SCALES = { small = 0.88, medium = 1, large = 1.15 }
ns.BOSS_SCALES = { small = 0.85, medium = 1, large = 1.2 }
local function FrameScale() return ns.FRAME_SCALES[ns.db.frameSize] or 1 end
local function BossScale() return ns.BOSS_SCALES[ns.db.bossSize] or 1 end

-- Breite von Spieler/Ziel/Pet/Ziel des Ziels: aus der Stufe, aber höchstens so breit, dass die
-- Frames vom Standardplatz aus nicht über den Bildschirmrand ragen (16:9, hohe UI-Skalierung).
local function FrameWidth()
    local maxWidth = UIParent:GetWidth() / 2 - INNER_X - ns.SCREEN_MARGIN
    return ns.Snap(math.min(SIZE.width * FrameScale(), maxWidth))
end
ns.FrameWidth = FrameWidth
ns.FRAME_TOP_Y = TOP_Y -- Oberkante der Unitframes unter der Bildschirmmitte (Aktionsleiste richtet sich danach)

local BIG_DEBUFF_SIZE = 40 -- eigene Debuffs im Layout Tank (sonst ~30)

-- Wie viele Auren in eine Reihe passen: so viele, dass die Icons möglichst nah an
-- size (Standard SIZE.auraSize) liegen (sie werden dann minimal angepasst, damit die Reihe bündig ist).
local function AuraCount(width, size)
    size = size or SIZE.auraSize
    return math.max(math.floor((width + 4) / (size + 4) + 0.5), 1)
end

-- Icongröße, mit der count Icons samt 4-px-Abständen width füllen. Zweiter Wert:
-- Einzug, der den Rundungsrest gleichmäßig auf beide Seiten verteilt (Reihe mittig).
local function FitIcons(count, width)
    local px = ns.PixelSize()
    local totalPx = math.floor(width / px + 0.5)
    local sizePx = math.floor((totalPx - (count - 1) * 4) / count)
    local restPx = totalPx - count * sizePx - (count - 1) * 4
    return sizePx * px, math.floor(restPx / 2) * px
end

-- Tooltip nur für vorhandene Einheiten (im Testmodus gibt es z. B. kein Ziel – Blizzards
-- Tooltip-Code wirft dann einen Fehler).
local function UnitFrame_OnEnterHook(self)
    if self.unit and UnitExists(self.unit) then UnitFrame_OnEnter(self) end
end

-- Leichter Schimmer über region, solange die Maus auf dem Frame ist.
local function AddHighlight(self, region) ns.AddHoverHighlight(self, region) end

-- Für [mui:name]: Name passend zur Breite des Namensfelds gekürzt
local function ShortenName(self, name)
    return ns.ShortenName(name, self.NameText)
end

local function SetupUnitButton(self)
    self.ShortenName = ShortenName
    self:RegisterForClicks("AnyUp")
    self:SetScript("OnEnter", UnitFrame_OnEnterHook)
    self:SetScript("OnLeave", UnitFrame_OnLeave)
end

local function SetupHealthColors(health)
    health.isHealth = true -- dunkles Theme: Füllung dunkel, fehlendes Leben heller
    health.colorDisconnected = true
    health.colorTapping = true
    health.colorClass = ns.STYLE.classHealth -- Theme „Klassenfarbe“
    health.colorReaction = true -- feindlich rot, neutral gelb, freundlich grün
    health.colorHealth = true
end

-- Text mit oUF-Tag; der Tag bleibt am FontString für den Testmodus.
local function TagText(self, text, tag)
    text.tagString = tag
    self:Tag(text, tag)
end

-- Aura-Reihe über (above) oder unter dem Frame, innen (far) beginnend.
local function CreateAuraRow(self, S, above, size, width, inset, offset)
    local near, far, dir = S.near, S.far, S.dir
    local vertical = above and "BOTTOM" or "TOP"
    local auras = self:CreateAuras({
        initialAnchor = vertical .. far,
        growthX = near,
        growthY = above and "UP" or "DOWN",
        layoutLimit = width + S.px / 2, -- halber Pixel Luft gegen Rundungsfehler
    })
    local edge = above and "TOP" or "BOTTOM"
    auras:SetPoint(vertical .. far, self, edge .. far, -inset * dir, above and offset or -offset)
    auras:SetSize(width, size)
    auras.size = size
    auras.elementSpacing = S.auraSpacing
    auras.lineSpacing = S.auraSpacing
    auras.showCount = true
    auras.showDuration = true
    auras.durationFormatter = ns.DurationFormatter
    auras.PostCreateButton = ns.StyleAuraButton
    return auras
end

-- Power:GetDisplayPower für den Spieler: Mana, wenn die Hauptressource in der Mitte steht;
-- sonst wie oUF (Sonder-Ressource von Begegnungen in Gruppen).
local function PlayerDisplayPower(_, unit)
    if ns.UsesCenterPower(unit) then return Enum.PowerType.Mana, 0 end
    local barInfo = GetUnitPowerBarInfo(unit)
    if barInfo and barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit) ~= nil) then
        return Enum.PowerType.Alternate, barInfo.minPower
    end
end

local function Style(self, unit)
    local mirrored = unit == "target" -- Ziel spiegelt das Spieler-Layout
    local near, far = mirrored and "RIGHT" or "LEFT", mirrored and "LEFT" or "RIGHT"
    local dir = mirrored and -1 or 1

    -- Alle Maße auf echte Pixel runden.
    local px = ns.PixelSize()
    local border = ns.BORDER_PIXELS
    local S = { px = px, near = near, far = far, dir = dir }
    for key, value in pairs(SIZE) do S[key] = ns.Snap(value) end
    -- Klassenleiste ist mittig verankert: gerade Pixelbreite, sonst lägen die Kanten auf halben Pixeln
    S.classPowerWidth = ns.MainBarWidth() -- Klassenleiste exakt so breit wie die Hauptaktionsleiste
    S.width, S.health = FrameWidth(), ns.Snap(SIZE.health * FrameScale())
    S.auraSpacing = 4 * px
    S.auraCount = AuraCount(S.width)
    S.aura, S.debuffInset = FitIcons(S.auraCount, S.width)
    S.buff, S.buffInset = FitIcons(S.auraCount, S.width)
    S.debuffCount = S.auraCount
    -- Layout Tank: eigene Debuffs größer (Boss-Mechaniken, Stapel); weniger passen in die Reihe,
    -- Begleiter rutscht darunter mit. Greift beim Aufbau (Layout-Wechsel > Neuladen).
    if unit == "player" and ns.LayoutFlag("bigDebuffs") then
        S.debuffCount = AuraCount(S.width, BIG_DEBUFF_SIZE)
        S.aura, S.debuffInset = FitIcons(S.debuffCount, S.width)
    end
    S.debuffWidth, S.buffWidth = S.width, S.width
    S.step = S.gap + 2 * border * px -- Abstand von Leiste zu Leiste, Rahmen eingerechnet

    -- Der Frame ist der Lebensbalken; alles andere hängt darüber und darunter.
    self:SetSize(S.width, S.health)
    SetupUnitButton(self)
    ns.CreateBackground(self)

    -- Leben
    local health = ns.CreateBar(self, S.health)
    health:SetAllPoints()
    health:SetReverseFill(mirrored)
    SetupHealthColors(health)
    ns.AddHealPrediction(health, mirrored) -- Heilung + Schild (Core/Style.lua)
    self.Health = health

    -- Texte über dem Balken auf eigener Ebene
    local texts = CreateFrame("Frame", nil, self)
    texts:SetAllPoints()
    texts:SetFrameLevel(health:GetFrameLevel() + 5)
    AddHighlight(self, texts)

    -- Zauberleiste als Overlay über dem Lebensbalken (nur beim Zaubern sichtbar),
    -- Zauber-Icon außen daneben
    local castbar = ns.CreateCastbar(self, S.health, mirrored, unit == "target", S.step)
    castbar:SetAllPoints(self)
    castbar:SetFrameLevel(texts:GetFrameLevel() + 1)
    self.Castbar = castbar

    -- Latenz (nur Spieler): rote Fläche am Ende der Leiste – drückst du dort schon den nächsten
    -- Zauber, geht keine Zeit verloren. Position und Breite (aus GetNetStats) setzt oUF je Zauber.
    if unit == "player" then
        local safeZone = castbar:CreateTexture(nil, "ARTWORK", nil, 2)
        safeZone:SetTexture("Interface\\Buttons\\WHITE8X8")
        safeZone:SetVertexColor(unpack(ns.STYLE.castLatencyColor))
        castbar.SafeZone = safeZone
        -- Tick-Striche bei kanalisierten Zaubern, GCD-Linie an der Unterkante (Core/Style.lua)
        castbar.channelTicks = {}
        castbar.PostCastStart = ns.UpdateChannelTicks
        local gcd = ns.CreateGCDBar(self, mirrored)
        gcd:SetFrameLevel(castbar:GetFrameLevel() + 3)
        castbar.muiHome = { self, S.health } -- Standardplatz (für das Zurückhängen)
        ns.playerCastbar = castbar
    elseif unit == "target" then
        ns.AddExecuteLine(health, "target")
    end

    -- Name und Zielmarkierung bleiben auch beim Zaubern sichtbar
    local top = CreateFrame("Frame", nil, self)
    top:SetAllPoints()
    top:SetFrameLevel(castbar:GetFrameLevel() + 5)

    local name = ns.CreateText(top, S.nameSize, far, "OUTLINE", "bold") -- großer Name: mUI Bold
    name:SetPoint(far, self, "TOP" .. far, -6 * dir, 2 * px) -- mittig auf der Oberkante, 2 px höher
    name:SetWidth(S.width * 0.8)
    -- Spieler: Stufe direkt vor dem Namen, solange unter der Höchststufe
    -- Spieler: Stufe in Surf Green (unter der Höchststufe) vor dem Namen; Ziel (gespiegelt): Stufe in
    -- Schwierigkeitsfarbe hinter dem Namen – beide Male zur Bildschirmmitte hin
    local nameTag = unit == "player" and "[mui:level][mui:name]"
        or unit == "target" and "[mui:name][mui:tlevel]" or "[mui:name]"
    TagText(self, name, nameTag)
    self.NameText = name

    local healthText = ns.CreateText(texts, S.valueSize, far, "OUTLINE")
    healthText:SetPoint("BOTTOM" .. far, self, "BOTTOM" .. far, -5 * dir, 4)
    TagText(self, healthText, "[mui:health]")
    self.HealthText = healthText

    local powerText = ns.CreateText(texts, S.valueSize, near, "OUTLINE")
    powerText:SetPoint("BOTTOM" .. near, self, "BOTTOM" .. near, 5 * dir, 4)
    TagText(self, powerText, "[mui:power]")
    self.PowerText = powerText

    -- Status (Kampf/Ausruhen) in der Mitte des Lebensbalkens, Zielmarkierung auf der
    -- äußeren oberen Ecke (wo im Entwurf der Kreis sitzt).

    -- Status-Symbole: eine Reihe mittig im Lebensbalken (sichtbare rücken zusammen);
    -- Ausruhen auf der äußeren oberen Ecke, halb über der Kante wie der Name.
    local STYLE = ns.STYLE
    local row = ns.CreateStatusRow(self, 18, 4)
    local function Status(name, color) return row.Add(ns.CreateStatusIcon(top, name, 18, color)) end

    self.DeadIcon = Status("Dead", STYLE.deadColor)
    self.GhostIcon = Status("Ghost", STYLE.ghostColor)
    self.ResurrectIndicator = Status("Resurrect", STYLE.resurrectColor)
    health.PostUpdate = ns.UpdateDeathIcons
    if unit == "player" then
        self.CombatIndicator = Status("Combat", STYLE.combatColor)
        local summon = Status("Summon", STYLE.summonColors[1])
        summon.PostUpdate = ns.UpdateSummonIcon
        self.SummonIndicator = summon

        local resting = ns.CreateStatusIcon(top, "Resting", 18, STYLE.restingColor)
        resting:SetPoint("CENTER", self, "TOP" .. near, 0, 2 * px)
        self.RestingIndicator = resting
    else
        self.QuestIndicator = Status("Quest", STYLE.questColor)
        self.PhaseIndicator = Status("Phase", STYLE.phaseColor)
    end

    local raidIcon = top:CreateTexture(nil, "OVERLAY", nil, 7)
    raidIcon:SetSize(22, 22)
    raidIcon:SetPoint("CENTER", self, "TOP" .. near, 0, 0)
    self.RaidTargetIndicator = raidIcon

    -- Klassenleiste (Combo-Punkte & Co. bzw. Runen): steht mittig zwischen Spieler und Ziel,
    -- platziert in der Factory (darunter kommt später die Hauptaktionsleiste).
    if unit == "player" then
        local _, class = UnitClass("player")
        if class == "DEATHKNIGHT" then
            self.Runes = ns.CreateRunes(top, S.classPower, S.classPowerWidth)
        else
            self.ClassPower = ns.CreateClassPower(top, S.classPower, S.classPowerWidth)
        end
        -- Braumeister: Staffelung am selben Platz, gleich breit
        if class == "MONK" then
            self.Stagger = ns.CreateStagger(top, S.classPower, S.classPowerWidth)
        end
        -- Eule/Shadow/Elementar: Hauptressource am selben Platz, Mana am Frame
        if class == "DRUID" or class == "PRIEST" or class == "SHAMAN" then
            self.CenterPower = ns.CreateCenterPower(top, S.classPower, S.classPowerWidth)
        end
    end

    -- Unter dem Lebensbalken: die Ressource, dicht dran
    local y = -(S.health + S.powerGap + 2 * border * px)

    local power = ns.CreateBar(self, S.power)
    power:SetPoint("TOPLEFT", self, "TOPLEFT", 0, y)
    power:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, y)
    power:SetReverseFill(mirrored)
    ns.AddBorder(power)
    power.frequentUpdates = true
    power.colorPower = true
    power.PostUpdateColor = ns.ColorPowerBar
    power.PostUpdate = ns.HideEmptyPowerText
    if unit == "player" then
        -- Steht die Hauptressource in der Mitte (Eule, Shadow, Elementar), zeigt der Balken Mana
        power.displayAltPower = true
        power.GetDisplayPower = PlayerDisplayPower
    end
    self.Power = power
    y = y - S.power - S.step

    -- Auren: oben Buffs (gut, über dem Namen), unten Debuffs (schlecht, eine Reihe).
    --   Spieler: alle Debuffs; kurze Buffs (≤ 2 min, ohne Heal-HoTs) – Potion, Heldentum, Procs.
    --   Ziel:    eigene Debuffs zuerst, dann fremde (grau); entfernbare Buffs (z. B. Wutanfall).
    S.aurasAbove = S.nameSize / 2 + S.auraOffset
    S.aurasBelow = -y - S.health + S.auraOffset - S.step

    local debuffs = CreateAuraRow(self, S, false, S.aura, S.width, S.debuffInset, S.aurasBelow)
    debuffs:SetClipsChildren(true) -- genau eine Reihe; der Container kennt keine Zeilengrenze
    local buffs = CreateAuraRow(self, S, true, S.buff, S.width, S.buffInset, S.aurasAbove)
    if unit == "player" then
        debuffs:AddGroup("HARMFUL", { maxFrameCount = S.debuffCount, dispelBand = "harmful" })
        buffs:AddGroup("HELPFUL|!RAID_IN_COMBAT", {
            maxFrameCount = 16,
            candidateFilters = { maxDuration = 120 }, -- schließt auch Dauer-Buffs (Mount, Wappenrock) aus
        })
    else
        debuffs:AddGroup("HARMFUL|PLAYER", { maxFrameCount = S.auraCount, dispelBand = "harmful" })
        debuffs:AddGroup("HARMFUL|!PLAYER", { maxFrameCount = S.auraCount, desaturate = true })
        buffs:AddGroup("HELPFUL|RAID_PLAYER_DISPELLABLE", { maxFrameCount = 8, dispelBand = "helpful" })
    end
    self.AuraRows = { debuffs, buffs }
    self.Sizes = S
end

local function SmallStyle(self, unit)
    local mirrored = unit == "targettarget" -- sitzt unter dem Ziel, gespiegelt wie dieses
    local near, far = mirrored and "RIGHT" or "LEFT", mirrored and "LEFT" or "RIGHT"
    local dir = mirrored and -1 or 1
    local px = ns.PixelSize()
    local S = { px = px, near = near, far = far, dir = dir }
    for key, value in pairs(SMALL) do S[key] = ns.Snap(value) end
    local hasPower = unit == "pet"

    self:SetSize(FrameWidth(), S.health + (hasPower and (px + S.power) or 0))
    SetupUnitButton(self)
    ns.CreateBackground(self)
    AddHighlight(self, self)

    local health = ns.CreateBar(self, S.health)
    health:SetPoint("TOPLEFT")
    health:SetPoint("TOPRIGHT")
    health:SetReverseFill(mirrored)
    SetupHealthColors(health)
    ns.AddHealPrediction(health, mirrored) -- Heilung + Schild (Core/Style.lua)
    self.Health = health

    local healthText = ns.CreateText(health, nil, far, "OUTLINE")
    healthText:SetPoint(far, health, far, -4 * dir, 0)
    TagText(self, healthText, "[dead][offline][perhp]%")
    self.HealthText = healthText

    local name = ns.CreateText(health, nil, near, "OUTLINE")
    name:SetPoint(near, health, near, 4 * dir, 0)
    name:SetPoint(far, healthText, near, -4 * dir, 0)
    TagText(self, name, "[mui:name]")
    self.NameText = name

    if hasPower then
        local power = ns.CreateBar(self, S.power)
        power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -px)
        power:SetPoint("BOTTOMRIGHT")
        power.colorPower = true
        power.PostUpdateColor = ns.ColorPowerBar
        self.Power = power
    end

    -- Debuffs am Ziel des Ziels (eine Reihe, innen beginnend) – z. B. damit Tanks
    -- an den Stapeln sehen, wann sie spotten müssen.
    if unit == "targettarget" then
        local width = self:GetWidth()
        S.auraSpacing = 4 * px
        S.auraCount = AuraCount(width)
        S.aura, S.debuffInset = FitIcons(S.auraCount, width)
        S.debuffWidth = width
        S.aurasBelow = ns.Snap(SIZE.auraOffset)
        local auras = CreateAuraRow(self, S, false, S.aura, width, S.debuffInset, S.aurasBelow)
        auras:SetClipsChildren(true)
        auras:AddGroup("HARMFUL", { maxFrameCount = S.auraCount, dispelBand = "harmful" })
        self.AuraRows = { auras }
        self.Sizes = S
    end
end

-- Breite der seitlichen Frames: SIDE.width, aber höchstens so breit, dass die Spalte rechts neben
-- dem Ziel noch auf den Bildschirm passt (Rand eingerechnet).
local function SideWidth(scale)
    local edge = ns.RightOfTargetEdge()
    local width = SIDE.width * scale
    if edge then width = math.min(width, UIParent:GetRight() - edge - ns.SCREEN_MARGIN) end
    return ns.Snap(math.max(width, 120))
end

local function SideStyle(self, unit)
    local px = ns.PixelSize()
    local border = ns.BORDER_PIXELS
    -- near/far/dir nur für die Aura-Reihe: „innen“ (Start) ist hier links, zur Bildschirmmitte
    local S = { px = px, near = "RIGHT", far = "LEFT", dir = -1, valueSize = ns.Snap(SIZE.valueSize) }
    local scale = unit == "focus" and FrameScale() or BossScale()
    for key, value in pairs(SIDE) do S[key] = ns.Snap(value) end
    for _, key in ipairs({ "health", "power", "auraSize" }) do S[key] = ns.Snap(SIDE[key] * scale) end
    S.width = SideWidth(scale)
    S.step = ns.Snap(SIZE.gap) + 2 * border * px
    S.auraSpacing = 4 * px
    S.auraCount = AuraCount(S.width, S.auraSize)
    S.aura, S.debuffInset = FitIcons(S.auraCount, S.width)
    S.debuffWidth = S.width
    S.aurasBelow = S.auraOffset
    -- Höhe eines Blocks in der Spalte: Frame + Debuff-Reihe (für den Abstand der Bosse)
    S.block = S.health + px + S.power + S.auraOffset + S.aura

    self:SetSize(S.width, S.health + px + S.power)
    SetupUnitButton(self)
    ns.CreateBackground(self)

    local health = ns.CreateBar(self, S.health)
    health:SetPoint("TOPLEFT")
    health:SetPoint("TOPRIGHT")
    SetupHealthColors(health)
    ns.AddHealPrediction(health, false)
    self.Health = health

    local texts = CreateFrame("Frame", nil, self)
    texts:SetAllPoints(health)
    texts:SetFrameLevel(health:GetFrameLevel() + 5)
    AddHighlight(self, texts)

    local healthText = ns.CreateText(texts, S.valueSize, "RIGHT", "OUTLINE")
    healthText:SetPoint("RIGHT", health, "RIGHT", -4, 0)
    TagText(self, healthText, "[dead][offline][perhp]%")
    self.HealthText = healthText

    local name = ns.CreateText(texts, S.valueSize, "LEFT", "OUTLINE")
    name:SetPoint("LEFT", health, "LEFT", 4, 0)
    name:SetPoint("RIGHT", healthText, "LEFT", -4, 0)
    TagText(self, name, "[mui:name]")
    self.NameText = name

    -- Zauberleiste über dem Lebensbalken; Texte mittig wie Name und Prozent, Icon außen rechts
    -- (die Spalte liegt rechts, „außen“ ist hier also rechts – anders als beim Spieler-Frame)
    local castbar = ns.CreateCastbar(self, S.health, false, true, S.step)
    castbar:SetAllPoints(health)
    castbar:SetFrameLevel(texts:GetFrameLevel() + 1)
    castbar.Time:ClearAllPoints()
    castbar.Time:SetPoint("RIGHT", castbar, "RIGHT", -4, 0)
    castbar.Text:ClearAllPoints()
    castbar.Text:SetPoint("LEFT", castbar, "LEFT", 4, 0)
    castbar.Text:SetPoint("RIGHT", castbar.Time, "LEFT", -4, 0)
    local iconFrame = castbar.Icon:GetParent()
    iconFrame:ClearAllPoints()
    iconFrame:SetPoint("LEFT", castbar, "RIGHT", S.step, 0)
    self.Castbar = castbar

    -- Zielmarkierung mittig auf der Oberkante, auch beim Zaubern sichtbar
    local top = CreateFrame("Frame", nil, self)
    top:SetAllPoints()
    top:SetFrameLevel(castbar:GetFrameLevel() + 5)
    local raidIcon = top:CreateTexture(nil, "OVERLAY", nil, 7)
    raidIcon:SetSize(16, 16)
    raidIcon:SetPoint("CENTER", self, "TOP", 0, 0)
    self.RaidTargetIndicator = raidIcon

    local power = ns.CreateBar(self, S.power)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -px)
    power:SetPoint("BOTTOMRIGHT")
    power.colorPower = true
    power.PostUpdateColor = ns.ColorPowerBar
    self.Power = power

    -- Eine Reihe unter dem Frame: links (innen) die Debuffs, eigene zuerst, dann fremde (grau);
    -- rechts außen wichtige Buffs des Gegners wie auf den Namensplaketten (purgebare mit
    -- Dispel-Band, dazu Blizzards „wichtige“: Schilde, Immunitäten, Wutanfälle – wegen denen
    -- man das Ziel wechselt), zusammen höchstens SIDE_BUFFS.
    local debuffMax = math.max(S.auraCount - SIDE_BUFFS, 1)
    local debuffs = CreateAuraRow(self, S, false, S.aura, S.width, S.debuffInset, S.aurasBelow)
    debuffs:SetClipsChildren(true)
    debuffs:AddGroup("HARMFUL|PLAYER", { maxFrameCount = debuffMax, dispelBand = "harmful" })
    debuffs:AddGroup("HARMFUL|!PLAYER", { maxFrameCount = debuffMax, desaturate = true })
    local R = { px = px, near = "LEFT", far = "RIGHT", dir = 1, auraSpacing = S.auraSpacing }
    local buffs = CreateAuraRow(self, R, false, S.aura, S.width, S.debuffInset, S.aurasBelow)
    buffs:SetClipsChildren(true)
    buffs:AddGroup("HELPFUL|RAID_PLAYER_DISPELLABLE", { maxFrameCount = 1, dispelBand = "helpful" })
    buffs:AddGroup("HELPFUL|IMPORTANT", { maxFrameCount = SIDE_BUFFS - 1 })
    self.AuraRows = { debuffs, buffs }
    self.Sizes = S
end

-- Leere Kraft bei anderen (Tiere ohne Energie …) ausblenden. Die Kraft fremder Einheiten ist in
-- Forever/Midnight geschützt (Secret) – vergleichen geht nicht, aber eine Stufen-Kurve macht aus dem
-- Prozentwert direkt die Transparenz des Textes (0 % > unsichtbar), wie Blizzard es selbst nutzt.
local ZERO_CURVE
if C_CurveUtil and C_CurveUtil.CreateCurve then
    ZERO_CURVE = C_CurveUtil.CreateCurve()
    ZERO_CURVE:SetType(Enum.LuaCurveType.Step)
    ZERO_CURVE:AddPoint(0, 0)
    ZERO_CURVE:AddPoint(0.001, 1)
end

function ns.HideEmptyPowerText(element, unit)
    local text = element.__owner and element.__owner.PowerText
    if not text then return end
    if not ZERO_CURVE or not UnitPowerPercent or UnitIsUnit(unit, "player") then return text:SetAlpha(1) end
    local alpha = UnitPowerPercent(unit, nil, false, ZERO_CURVE)
    if issecretvalue(alpha) then
        text:SetAlpha(alpha) -- SetAlpha nimmt geschützte Werte an
    elseif type(alpha) == "number" then
        text:SetAlpha(alpha)
    else
        text:SetAlpha(1)
    end
end

-- Vor- und Nachname (Forever, Benny 2026-11-07): UnitName liefert den Nachnamen als zweiten Wert.
-- ns.db.nameFormat: "first" Koratal · "full" Koratal Rabenruf · "firstInitial" Koratal R. ·
-- "initialLast" K. Rabenruf · "last" Rabenruf. Geschützte Namen (Secrets) nur durchreichen.
local function FirstChar(text)
    return text:match("^[%z\1-\127\194-\244][\128-\191]*") or text:sub(1, 1)
end
function ns.FormatUnitName(unit)
    local first, last = UnitName(unit)
    if first == nil or issecretvalue(first) then return first end
    if last == nil or issecretvalue(last) or last == "" then return first end
    local mode = ns.db and ns.db.nameFormat or "full"
    if mode == "first" then return first end
    if mode == "last" then return last end -- RP: Nachname als Rufname
    if mode == "firstInitial" then return first .. " " .. FirstChar(last) .. "." end
    if mode == "initialLast" then return FirstChar(first) .. ". " .. last end
    return first .. " " .. last
end
oUF.Tags.Vars.muiFormatName = ns.FormatUnitName

-- Alle Namen neu schreiben (Einstellung geändert)
function ns.UpdateNameTags()
    for _, object in ipairs(oUF.objects) do
        if object.UpdateTags then object:UpdateTags() end
    end
end

-- Name, bei Bedarf gekürzt (ns.ShortenName); _FRAME ist der Frame, an dem der Tag hängt.
oUF.Tags.Methods["mui:name"] = [[function(u, r)
    local name = _VARS.muiFormatName(r or u)
    if _FRAME and _FRAME.ShortenName then return _FRAME:ShortenName(name) end
    return name
end]]
oUF.Tags.Events["mui:name"] = "UNIT_NAME_UPDATE"

-- Stufe in Surf Green mit Leerzeichen dahinter, nur unter der Höchststufe (sonst leer)
oUF.Tags.Methods["mui:level"] = [[function(u)
    local level = UnitLevel(u)
    if issecretvalue(level) or not level or level <= 0 or level >= GetMaxLevelForPlayerExpansion() then return end
    return "|cff8ecbb4" .. level .. "|r "
end]]
oUF.Tags.Events["mui:level"] = "UNIT_LEVEL PLAYER_LEVEL_UP"

-- Stufe des Ziels in Schwierigkeitsfarbe (grau/grün/gelb/orange/rot wie Classic), Boss „??“ rot
oUF.Tags.Methods["mui:tlevel"] = [[function(u)
    local level = UnitLevel(u)
    if issecretvalue(level) or not level then return end
    if level <= 0 then return " |cffff2020??|r" end
    local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
    if not color then return " " .. level end
    -- „gleiche Stufe“ (Blizzard: gelb) in MUI-Salbei, die übrigen Gefahrenfarben bleiben
    if QuestDifficultyColors and color == QuestDifficultyColors.difficult then return " |cff8ecbb4" .. level .. "|r" end
    return (" |cff%02x%02x%02x%d|r"):format(color.r * 255, color.g * 255, color.b * 255, level)
end]]
oUF.Tags.Events["mui:tlevel"] = "UNIT_LEVEL PLAYER_LEVEL_UP PLAYER_TARGET_CHANGED"

-- Aktuelles Leben bzw. aktuelle Ressource, abgekürzt (107.9K). AbbreviateNumbers darf
-- auch geschützte Werte (Secrets) verarbeiten.
oUF.Tags.Methods["mui:health"] = [[function(u)
    return _TAGS.dead(u) or _TAGS.offline(u) or AbbreviateNumbers(UnitHealth(u))
end]]
oUF.Tags.Events["mui:health"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- Steht die Hauptressource in der Mitte, zeigt der Text am Frame das Mana (wie der Balken).
oUF.Tags.Methods["mui:power"] = function(u)
    local powerType = ns.UsesCenterPower(u) and Enum.PowerType.Mana or nil
    local max = UnitPowerMax(u, powerType)
    if not issecretvalue(max) and max == 0 then return end
    local power = UnitPower(u, powerType)
    -- leere Kraft bei anderen (z. B. Tiere ohne Energie) ausblenden; bei dir selbst bleibt die 0
    if not issecretvalue(power) and power == 0 and not UnitIsUnit(u, "player") then return end
    return AbbreviateNumbers(power)
end
oUF.Tags.Events["mui:power"] = "UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER"

oUF:RegisterStyle("Meredan", function(self, unit)
    ns.SnapBarsOnUnitChange(self)
    if unit == "pet" or unit == "targettarget" then
        SmallStyle(self, unit)
    elseif unit == "focus" or unit:match("^boss%d$") then
        SideStyle(self, unit)
    else
        Style(self, unit)
    end
end)

oUF:Factory(function(self)
    ns.ApplySettings()
    -- Lebensfarbe vom Theme; freundliche Einheiten bekommen dasselbe Grün.
    oUF.colors.health:SetRGB(unpack(ns.HEALTH_COLOR))
    for token, color in pairs(ns.POWER_COLORS) do
        if oUF.colors.power[token] then oUF.colors.power[token]:SetRGB(unpack(color)) end
    end
    for reaction = 5, 8 do
        oUF.colors.reaction[reaction] = oUF.colors.health
    end

    self:SetActiveStyle("Meredan")
    -- An der inneren oberen Ecke verankern: Alle Größen sind ganze Pixel, so liegen
    -- auch alle Kanten auf ganzen Pixeln.
    ns.frames = {
        player = self:Spawn("player"),
        target = self:Spawn("target"),
    }
    ns.OnLayout(function()
        local x, y = ns.Snap(INNER_X), ns.Snap(TOP_Y)
        if ns.LayoutFlag("healerGroups") then
            -- Heiler: links/rechts neben der Gruppe, oben bündig mit ihr (Core/Layouts.lua)
            local geo = ns.HealerGeometry()
            local _, cy = UIParent:GetCenter()
            x, y = ns.Snap(geo.innerX), cy - geo.groupTop
        end
        ns.PlaceFromCenter(ns.frames.player, "TOPRIGHT", -x, -y)
        ns.PlaceFromCenter(ns.frames.target, "TOPLEFT", x, -y)
    end)

    -- Klassenleiste mittig zwischen den Frames, mit etwas Abstand über der Oberkante der
    -- Lebensbalken: Auf Höhe der Frames kommt später die Hauptaktionsleiste.
    local playerFrame = ns.frames.player
    local classBar = playerFrame.ClassPower or playerFrame.Runes
    if classBar then
        ns.OnLayout(function()
            if ns.LayoutFlag("healerGroups") then return end -- Heiler: setzt ActionBars.lua über die Gruppe
            ns.PlaceFromCenter(classBar.strip, "BOTTOM", 0, -ns.Snap(TOP_Y) + ns.Snap(SIZE.classPowerGap))
        end)
        ns.layoutFrames.classpower = classBar.strip
        -- Staffelung folgt der Klassenleiste
        if playerFrame.Stagger then playerFrame.Stagger:SetPoint("CENTER", classBar.strip, "CENTER") end
        if playerFrame.CenterPower then playerFrame.CenterPower:SetPoint("CENTER", classBar.strip, "CENTER") end
    end

    -- Pet und Ziel des Ziels unter der Debuff-Reihe, innen bündig
    local S = ns.frames.player.Sizes
    local below = S.aurasBelow + S.aura + 3 * S.auraOffset
    ns.smallFrames = {
        pet = self:Spawn("pet"),
        targettarget = self:Spawn("targettarget"),
    }
    ns.smallFrames.pet:SetPoint("TOPRIGHT", ns.frames.player, "BOTTOMRIGHT", 0, -below)
    ns.smallFrames.targettarget:SetPoint("TOPLEFT", ns.frames.target, "BOTTOMLEFT", 0, -below)

    -- Fokus: rechts neben dem Ziel (gemeinsame Kante ns.RightOfTargetEdge), oben bündig
    ns.sideFrames = { focus = self:Spawn("focus") }
    ns.OnLayout(function()
        local cx, cy = UIParent:GetCenter()
        local edge = ns.RightOfTargetEdge()
        local top = ns.frames.target:GetTop()
        local x = edge and (edge - cx) or ns.Snap(INNER_X + SIZE.width + 70)
        local y = top and (top - cy) or -ns.Snap(TOP_Y)
        ns.PlaceFromCenter(ns.sideFrames.focus, "TOPLEFT", x, y)
    end)
    ns.layoutFrames.focus = ns.sideFrames.focus

    -- Bosse: hängen an einem Platzhalter links neben dem Questlog.
    -- Dessen Platzhalter entsteht erst nach dem Login (Quests/QuestTracker.lua ruft dann
    -- ns.PlaceBossFrames); bis dahin bzw. ohne Questlog rechts unter der Minimap.
    local bossAnchor = CreateFrame("Frame", "MeredanUIBossAnchor", UIParent)
    local bossCount = 5 -- wie Blizzards MAX_BOSS_FRAMES
    local side, step
    for i = 1, bossCount do
        local boss = self:Spawn("boss" .. i)
        side = side or boss.Sizes -- Bosse haben eine eigene Größenstufe
        step = step or (side.block + side.gap)
        boss:SetPoint("TOPLEFT", bossAnchor, "TOPLEFT", 0, -(i - 1) * step)
        ns.sideFrames["boss" .. i] = boss
    end
    bossAnchor:SetSize(side.width, bossCount * step - side.gap)
    -- Linke Kante wie der Fokus (eine Linie, folgt dem Ziel – nicht dem Bildschirmrand; Benny
    -- 2026-11-07), Oberkante wie das Questlog. Auf 16:9 liegt das im Questlog – das rückt im Layout
    -- Nahkampf-DPS unter die sichtbaren Bossframes und zeigt nur Instanz-Quests (Quests/Tracker.lua). Benny 2026-10-24: direkt neben dem Questlog überlappte es.
    local function PlaceBossAnchor()
        local cx, cy = UIParent:GetCenter()
        local quest = _G["MeredanUIQuestAnchor"]
        local left = ns.sideFrames.focus:GetLeft() or (cx + ns.Snap(INNER_X + SIZE.width + 70))
        left = ns.Snap(left)
        bossAnchor:ClearAllPoints()
        bossAnchor:SetPoint("LEFT", UIParent, "LEFT", left, 0)
        if quest then
            bossAnchor:SetPoint("TOP", quest, "TOP", 0, 0)
        else
            local minimap = _G["MeredanUIMinimap"]
            local top = minimap and minimap:GetBottom() and (minimap:GetBottom() - ns.Snap(30)) or (UIParent:GetTop() - ns.Snap(300))
            bossAnchor:SetPoint("TOP", UIParent, "BOTTOM", 0, ns.Snap(top))
        end
    end
    ns.OnLayout(PlaceBossAnchor)
    -- Questlog-Modul ruft nach dem Login: Bosse links neben dem Questlog
    function ns.PlaceBossFrames()
        -- Bossframes hängen am Anker: im Kampf gesperrt (z. B. /reload im Kampf) > danach
        if InCombatLockdown() then return ns.AfterCombat(ns.PlaceBossFrames) end
        PlaceBossAnchor()
        ns.layoutFrames.boss = bossAnchor
    end
    C_Timer.After(1, ns.PlaceBossFrames) -- falls das Questlog-Modul nicht ruft

end)

-- Gemeinsame Kanten neben Spieler- und Ziel-Frame (Boss-Timer, Gruppenframes):
-- außen am Frame sitzt das Castbar-Symbol (so hoch wie der Lebensbalken + Lücke), dann SIDE_GAP.
local SIDE_GAP = 30
local function CastIconSpace(frame)
    local sizes = frame and frame.Sizes
    return sizes and (sizes.health or 0) + (sizes.step or 0) or 0
end

-- rechte Kante der Spalte links neben dem Spieler-Frame (nil, solange er nicht steht)
function ns.LeftOfPlayerEdge()
    local player = ns.frames and ns.frames.player
    if not (player and player:GetLeft()) then return end
    return player:GetLeft() - CastIconSpace(player) - ns.Snap(SIDE_GAP)
end

-- linke Kante der Spalte rechts neben dem Ziel-Frame
function ns.RightOfTargetEdge()
    local target = ns.frames and ns.frames.target
    if not (target and target:GetRight()) then return end
    return target:GetRight() + CastIconSpace(target) + ns.Snap(SIDE_GAP)
end

-- Nach einem Wechsel von Theme, Schrift oder Textur: Farben von oUF neu berechnen lassen.
function ns.OnStyleRefreshed()
    oUF.colors.health:SetRGB(unpack(ns.HEALTH_COLOR))
    for _, list in ipairs({ ns.frames, ns.smallFrames, ns.sideFrames }) do
        for _, frame in pairs(list) do
            frame.Health.colorClass = ns.STYLE.classHealth
            frame:UpdateAllElements("MeredanStyle")
        end
    end
end

-- Zauberleiste des Spielers im Layout Fernkampf (Benny 2026-11-07): raus aus dem Spielerframe, groß
-- über den unteren Aktionsleisten – so breit wie die Leisten (Symbol links eingerechnet), über dem
-- Platz der Haltungsleiste. Sonst wieder als Overlay im Spielerframe.
local BIG_CASTBAR_HEIGHT, BIG_CASTBAR_GAP = 32, 6 -- so hoch wie der Lebensbalken des Spielers
function ns.PlacePlayerCastbar()
    local castbar = ns.playerCastbar
    if not (castbar and castbar.muiHome) then return end
    local home, homeHeight = castbar.muiHome[1], castbar.muiHome[2]
    local iconFrame = castbar.Icon and castbar.Icon:GetParent()
    -- Fernkampf: über Alt (darüber die Haltungsleiste); Heiler: über der Hauptleiste (unterste 3 Reihen,
    -- Haltung steht dort links daneben)
    local healer = ns.StackedBars()
    local alt = ns.layoutFrames and (healer and ns.layoutFrames.bar1 or ns.layoutFrames.bar3)
    castbar:ClearAllPoints()
    if ns.LayoutFlag("castbarAboveBars") and alt and alt:GetLeft() then
        local height = ns.Snap(BIG_CASTBAR_HEIGHT)
        local gap = ns.Snap(BIG_CASTBAR_GAP)
        local stance = ns.layoutFrames.stancebar
        local above = healer and gap or ((stance and stance:GetHeight() or 0) + 2 * gap)
        local iconSpace = height + ns.Snap(4)
        castbar:SetHeight(height)
        castbar:SetPoint("BOTTOMLEFT", alt, "TOPLEFT", iconSpace, above)
        castbar:SetPoint("BOTTOMRIGHT", alt, "TOPRIGHT", 0, above)
        if iconFrame then
            iconFrame:SetSize(height, height)
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint("RIGHT", castbar, "LEFT", -ns.Snap(4), 0)
        end
        -- eigener 1-px-Rahmen (im Spielerframe nutzt sie dessen Rahmen mit)
        castbar.muiBorder = castbar.muiBorder or ns.AddBorder(castbar)
        for _, edge in ipairs(castbar.muiBorder) do edge:Show() end
        castbar.muiDetached = true
    else
        for _, edge in ipairs(castbar.muiBorder or {}) do edge:Hide() end
        castbar:SetAllPoints(home)
        if iconFrame and castbar.muiDetached then
            -- zurück an den Standardplatz: außen neben dem Spielerframe, so hoch wie der Balken
            iconFrame:SetSize(homeHeight, homeHeight)
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint(castbar.muiIconPoint[1], castbar, castbar.muiIconPoint[2], castbar.muiIconPoint[3], 0)
        end
        castbar.muiDetached = nil
    end
end
-- nach den Aktionsleisten (die richten sich beim Login ein)
ns:On("PLAYER_LOGIN", function()
    C_Timer.After(0.2, function()
        local castbar = ns.playerCastbar
        local iconFrame = castbar and castbar.Icon and castbar.Icon:GetParent()
        if iconFrame then -- Standard-Symbolplatz merken
            local point, _, relPoint, x = iconFrame:GetPoint(1)
            castbar.muiIconPoint = { point, relPoint, x }
        end
        ns.OnLayout(ns.PlacePlayerCastbar)
    end)
end)
