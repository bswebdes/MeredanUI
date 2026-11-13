-- Unit frame layout (oUF style "Meredan"). The target mirrors the player.
--
--                     [buffs, starting inside ...]
--   o                                       NAME    <- name large, on the top edge
--   +--------------------------------------------+
--   |                 status                     |  <- cast bar overlays the health bar,
--   | power                               health |     spell icon outside next to it
--   +--------------------------------------------+
--   ============================================      <- resource bar, thin, detached
--                     [debuffs, one row, starting inside ...]
--                                     [pet / target of target]
-- o = raid marker. "Inside" = towards screen center (player: right, target: left).
local _, ns = ...
local oUF = ns.oUF

local SIZE = {
    width = 235,       -- "medium" size; ns.db.frameSize scales it (ns.FRAME_SCALES)
    health = 28,       -- "medium" size
    power = 6,
    classPower = 10,   -- class bar centered between the frames: pip height (width = main bar)
    classPowerGap = 12, -- class bar <-> top of the frames (action bar below)
    powerGap = 2,      -- health bar <-> resource
    gap = 4,           -- between the bars below the health bar
    nameSize = 18,     -- Cinzel caps above the frame
    valueSize = 12,    -- power text (hidden on player/target), small frames
    healthValueSize = 15,
    platePad = 2,      -- dark band between the health bar and the bronze hairline
    auraSize = 30,     -- target icon size: wider frames show more auras, not bigger ones
    auraOffset = 6,    -- frame <-> aura row
}

-- Small frames (pet, target of target): as wide as the big frame, name and percent in the
-- health bar, pet has a resource bar below.
local SMALL = {
    health = 22,
    power = 4,
}

-- Side frames (focus, boss 1-5): slim like pet/target of target, cast bar overlay with the icon
-- outside right (for interrupts), raid marker on the top edge, one debuff row below (own first).
-- Focus: right of the target, top-aligned. Bosses: column in line with the focus, top-aligned
-- with the quest tracker (there is room below for all five).
local SIDE = {
    width = 200,     -- shrinks if the screen is too narrow (high UI scale)
    health = 26,
    power = 4,
    auraSize = 20,
    auraOffset = 6,  -- frame <-> debuff row
    gap = 10,        -- between boss frames (below the debuff row)
}
local SIDE_BUFFS = 3 -- important enemy buffs on the right of the aura row (the rest are debuffs)

-- Default position: inner edge INNER_X from screen center, top edge TOP_Y below it.
local INNER_X, TOP_Y = 220, 200

-- Size steps: player + target together, pet, target of target and focus follow; boss frames have
-- their own step. Anchors stay (inner edge, top edge), frames grow outwards and down.
ns.FRAME_SCALES = { small = 0.88, medium = 1, large = 1.15 }
ns.BOSS_SCALES = { small = 0.85, medium = 1, large = 1.2 }
local function FrameScale() return ns.FRAME_SCALES[ns.db.frameSize] or 1 end
local function BossScale() return ns.BOSS_SCALES[ns.db.bossSize] or 1 end

-- Width of player/target/pet/target of target: from the size step, but capped so the frames do not
-- extend past the screen edge from the default position (16:9, high UI scale).
local function FrameWidth()
    local maxWidth = UIParent:GetWidth() / 2 - INNER_X - ns.SCREEN_MARGIN
    return ns.Snap(math.min(SIZE.width * FrameScale(), maxWidth))
end
ns.FrameWidth = FrameWidth
ns.FRAME_TOP_Y = TOP_Y -- top of the unit frames below screen center (the action bar aligns to it)

local BIG_DEBUFF_SIZE = 40 -- own debuffs in the tank layout (otherwise ~30)

-- How many auras fit in a row: as many as keep the icons closest to size (default SIZE.auraSize);
-- they are then adjusted slightly so the row is flush.
local function AuraCount(width, size)
    size = size or SIZE.auraSize
    return math.max(math.floor((width + 4) / (size + 4) + 0.5), 1)
end

-- Icon size at which count icons plus 4 px gaps fill width. Second value: inset that spreads the
-- rounding remainder evenly on both sides (row centered).
local function FitIcons(count, width)
    local px = ns.PixelSize()
    local totalPx = math.floor(width / px + 0.5)
    local sizePx = math.floor((totalPx - (count - 1) * 4) / count)
    local restPx = totalPx - count * sizePx - (count - 1) * 4
    return sizePx * px, math.floor(restPx / 2) * px
end

-- Tooltip only for existing units (e.g. no target in test mode - Blizzard's tooltip code errors).
local function UnitFrame_OnEnterHook(self)
    if self.unit and UnitExists(self.unit) then UnitFrame_OnEnter(self) end
end

-- Slight highlight over region while the mouse is over the frame.
local function AddHighlight(self, region) ns.AddHoverHighlight(self, region) end

-- For [mui:name]: name shortened to fit the name field width
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
    health.isHealth = true -- dark theme: dark fill, missing health lighter
    health.colorDisconnected = true
    health.colorTapping = true
    health.colorClass = ns.STYLE.classHealth -- "class color" theme
    health.colorReaction = true -- hostile red, neutral yellow, friendly green
    health.colorHealth = true
end

-- Text with an oUF tag; the tag is kept on the FontString for test mode.
local function TagText(self, text, tag)
    text.tagString = tag
    self:Tag(text, tag)
end

-- Aura row above or below the frame, starting inside (far).
local function CreateAuraRow(self, S, above, size, width, inset, offset)
    local near, far, dir = S.near, S.far, S.dir
    local vertical = above and "BOTTOM" or "TOP"
    local auras = self:CreateAuras({
        initialAnchor = vertical .. far,
        growthX = near,
        growthY = above and "UP" or "DOWN",
        layoutLimit = width + S.px / 2, -- half a pixel slack against rounding errors
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

-- Power:GetDisplayPower for the player: mana when the main resource is shown in the center;
-- otherwise like oUF (encounter alternate power in groups).
local function PlayerDisplayPower(_, unit)
    if ns.UsesCenterPower(unit) then return Enum.PowerType.Mana, 0 end
    local barInfo = GetUnitPowerBarInfo(unit)
    if barInfo and barInfo.showOnRaid and (UnitInParty(unit) or UnitInRaid(unit) ~= nil) then
        return Enum.PowerType.Alternate, barInfo.minPower
    end
end

local function Style(self, unit)
    local mirrored = unit == "target" -- target mirrors the player layout
    local near, far = mirrored and "RIGHT" or "LEFT", mirrored and "LEFT" or "RIGHT"
    local dir = mirrored and -1 or 1

    -- Round all sizes to real pixels.
    local px = ns.PixelSize()
    local border = ns.BORDER_PIXELS
    local S = { px = px, near = near, far = far, dir = dir }
    for key, value in pairs(SIZE) do S[key] = ns.Snap(value) end
    -- Class bar is center-anchored: use an even pixel width, otherwise edges land on half pixels
    S.classPowerWidth = ns.MainBarWidth() -- class bar exactly as wide as the main action bar
    S.width, S.health = FrameWidth(), ns.Snap(SIZE.health * FrameScale())
    S.auraSpacing = 4 * px
    S.auraCount = AuraCount(S.width)
    S.aura, S.debuffInset = FitIcons(S.auraCount, S.width)
    S.buff, S.buffInset = FitIcons(S.auraCount, S.width)
    S.debuffCount = S.auraCount
    -- Tank layout: bigger own debuffs (boss mechanics, stacks); fewer fit in the row, the pet moves
    -- down with it. Applied at build time (layout change needs a reload).
    if unit == "player" and ns.LayoutFlag("bigDebuffs") then
        S.debuffCount = AuraCount(S.width, BIG_DEBUFF_SIZE)
        S.aura, S.debuffInset = FitIcons(S.debuffCount, S.width)
    end
    S.debuffWidth, S.buffWidth = S.width, S.width
    S.step = S.gap + 2 * border * px -- bar-to-bar distance including borders

    -- The frame is the health bar; everything else hangs above and below it.
    self:SetSize(S.width, S.health)
    SetupUnitButton(self)

    -- Shell around the bar, from the inside out: black line, warm dark band, bronze edge lit from
    -- above, black outline, soft shadow. Depth comes from the stacked lines, not from one border.
    -- one shell around health and resource bar (resource sits right below, 1 px black seam)
    local body = CreateFrame("Frame", nil, self)
    body:SetPoint("TOPLEFT")
    body:SetPoint("BOTTOMRIGHT", 0, -(px + S.power))
    S.plateOut = ns.AddDeepShell(body, S.platePad)

    -- Health
    local health = ns.CreateBar(self, S.health)
    health:SetAllPoints()
    health:SetReverseFill(mirrored)
    SetupHealthColors(health)
    ns.ShadeBar(health, mirrored)
    ns.AddHealPrediction(health, mirrored) -- heals + shield (Core/Style.lua)
    self.Health = health

    -- Texts above the bar on their own level
    local texts = CreateFrame("Frame", nil, self)
    texts:SetAllPoints()
    texts:SetFrameLevel(health:GetFrameLevel() + 5)
    AddHighlight(self, texts)

    -- Cast bar as overlay on the health bar (visible only while casting), spell icon outside
    local castbar = ns.CreateCastbar(self, S.health, mirrored, unit == "target", S.step)
    castbar:SetAllPoints(self)
    castbar:SetFrameLevel(texts:GetFrameLevel() + 1)
    self.Castbar = castbar

    -- Latency (player only): red zone at the end of the bar - queue the next spell there and no
    -- time is lost. oUF sets position and width (from GetNetStats) per cast.
    if unit == "player" then
        local safeZone = castbar:CreateTexture(nil, "ARTWORK", nil, 2)
        safeZone:SetTexture("Interface\\Buttons\\WHITE8X8")
        safeZone:SetVertexColor(unpack(ns.STYLE.castLatencyColor))
        castbar.SafeZone = safeZone
        -- Tick marks for channeled spells, GCD line on the bottom edge (Core/Style.lua)
        castbar.channelTicks = {}
        castbar.PostCastStart = ns.UpdateChannelTicks
        local gcd = ns.CreateGCDBar(self, mirrored)
        gcd:SetFrameLevel(castbar:GetFrameLevel() + 3)
        castbar.muiHome = { self, S.health } -- default spot (for re-attaching)
        ns.playerCastbar = castbar
    elseif unit == "target" then
        ns.AddExecuteLine(health, "target")
    end

    -- Name and raid marker stay visible while casting
    local top = CreateFrame("Frame", nil, self)
    top:SetAllPoints()
    top:SetFrameLevel(castbar:GetFrameLevel() + 5)

    -- Name in Cinzel capitals above the plate, on the outer side (player left, target right)
    local name = ns.CreateText(top, S.nameSize, near, nil, "display")
    name:SetShadowOffset(0, -2)
    name:SetShadowColor(0, 0, 0, 0.85)
    name:SetPoint("BOTTOM" .. near, self, "TOP" .. near, -S.plateOut * dir, S.plateOut + 4 * px)
    name:SetWidth(S.width * 0.8)
    -- Player: level in Surf Green before the name (below max level); target (mirrored): level in
    -- difficulty color after the name
    local nameTag = unit == "player" and "[mui:level][mui:uname]"
        or unit == "target" and "[mui:uname][mui:tlevel]" or "[mui:uname]"
    TagText(self, name, nameTag)
    self.NameText = name

    -- accent gem on the inner end (below): an odd number of pixels, so it can sit exactly centred
    -- on the 1 px bronze edge at any UI scale
    local gemPixels = math.floor(18 / px + 0.5)
    if gemPixels % 2 == 0 then gemPixels = gemPixels + 1 end
    local gemSize = gemPixels * px
    local healthText = ns.CreateText(texts, S.healthValueSize, far, "OUTLINE")
    healthText:SetPoint(far, self, far, -(gemSize / 2 + 4) * dir, 0)
    TagText(self, healthText, "[mui:health]")
    self.HealthText = healthText

    -- power value: kept for test mode, not shown in this look
    local powerText = ns.CreateText(texts, S.valueSize, near, "OUTLINE")
    powerText:SetPoint("BOTTOM" .. near, self, "BOTTOM" .. near, 5 * dir, 4)
    TagText(self, powerText, "[mui:power]")
    powerText:Hide()
    self.PowerText = powerText

    -- cut gem in a bronze bezel, sitting on the bronze edge at the inner end like a clasp; the
    -- gem texture is grey and takes the accent colour
    local bezel = top:CreateTexture(nil, "OVERLAY", nil, 1)
    bezel:SetTexture(ns.MEDIA .. "GemBezel")
    bezel:SetSize(gemSize, gemSize)
    bezel:SetPoint("CENTER", body, far, (S.plateOut - px / 2) * dir, 0) -- middle of the bronze edge
    local gem = top:CreateTexture(nil, "OVERLAY", nil, 2)
    gem:SetTexture(ns.MEDIA .. "Gem")
    gem:SetAllPoints(bezel)
    gem:SetVertexColor(unpack(ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 }))
    self.AccentGem = gem

    -- Status icons: one row centered in the health bar (visible ones close ranks); resting icon
    -- and raid marker on the top corner, half over the edge like the name.
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
        resting:SetPoint("CENTER", self, "TOP" .. far, -14 * dir, 2 * px)
        self.RestingIndicator = resting
    else
        self.QuestIndicator = Status("Quest", STYLE.questColor)
        self.PhaseIndicator = Status("Phase", STYLE.phaseColor)
    end

    local raidIcon = top:CreateTexture(nil, "OVERLAY", nil, 7)
    raidIcon:SetSize(22, 22)
    raidIcon:SetPoint("CENTER", self, "TOP", 0, S.plateOut)
    self.RaidTargetIndicator = raidIcon

    -- Class bar (combo points etc. or runes): centered between player and target, placed in the
    -- factory (the main action bar goes below it).
    if unit == "player" then
        local _, class = UnitClass("player")
        if class == "DEATHKNIGHT" then
            self.Runes = ns.CreateRunes(top, S.classPower, S.classPowerWidth)
        else
            self.ClassPower = ns.CreateClassPower(top, S.classPower, S.classPowerWidth)
        end
        -- Brewmaster: stagger in the same spot, same width
        if class == "MONK" then
            self.Stagger = ns.CreateStagger(top, S.classPower, S.classPowerWidth)
        end
        -- Balance/Shadow/Elemental: main resource in the same spot, mana on the frame
        if class == "DRUID" or class == "PRIEST" or class == "SHAMAN" then
            self.CenterPower = ns.CreateCenterPower(top, S.classPower, S.classPowerWidth)
        end
    end

    -- Resource bar inside the shell, below the health bar with a 1 px black seam
    local y = -(S.health + px)

    local seam = self:CreateTexture(nil, "BORDER")
    seam:SetColorTexture(0, 0, 0, 1)
    seam:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
    seam:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT")
    seam:SetHeight(px)

    local power = ns.CreateBar(self, S.power)
    power:SetPoint("TOPLEFT", self, "TOPLEFT", 0, y)
    power:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, y)
    power:SetReverseFill(mirrored)
    power.frequentUpdates = true
    power.colorPower = true
    power.PostUpdateColor = ns.ColorPowerBar
    ns.ShadeBar(power, mirrored) -- wraps PostUpdateColor, so after it is set
    power.PostUpdate = ns.HideEmptyPowerText
    if unit == "player" then
        -- If the main resource is shown in the center (Balance, Shadow, Elemental), the bar shows mana
        power.displayAltPower = true
        power.GetDisplayPower = PlayerDisplayPower
    end
    self.Power = power
    y = y - S.power - S.plateOut - S.step

    -- Auras: buffs above the name, debuffs below (one row).
    --   Player: all debuffs; short buffs (<= 2 min, no heal HoTs) - potions, Heroism, procs.
    --   Target: own debuffs first, then others (gray); dispellable buffs (e.g. Enrage).
    S.aurasAbove = S.plateOut + S.nameSize + 6 + S.auraOffset
    S.aurasBelow = -y - S.health + S.auraOffset - S.step

    local debuffs = CreateAuraRow(self, S, false, S.aura, S.width, S.debuffInset, S.aurasBelow)
    debuffs:SetClipsChildren(true) -- exactly one row; the container has no row limit
    -- Player buffs: one row starting at the right edge and growing left; shortest-running on the
    -- right, longer ones to the left - when the row is full the longest drop out, never the short ones
    local buffs = CreateAuraRow(self, S, true, S.buff, S.width, S.buffInset, S.aurasAbove)
    if unit == "player" then
        debuffs:AddGroup("HARMFUL", { maxFrameCount = S.debuffCount, dispelBand = "harmful" })
        buffs:AddGroup("HELPFUL|!RAID_IN_COMBAT", {
            maxFrameCount = S.auraCount,
            sortMethod = AuraContainerSortMethod.ExpirationOnly,
            sortDirection = AuraContainerSortDirection.Normal,
            candidateFilters = { maxDuration = 120 }, -- also excludes permanent buffs (mount, tabard)
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
    local mirrored = unit == "targettarget" -- sits below the target, mirrored like it
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
    ns.AddHealPrediction(health, mirrored) -- heals + shield (Core/Style.lua)
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

    -- Debuffs on target of target (one row, starting inside) - e.g. so tanks see stacks for taunt swaps
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

-- Side frame width: SIDE.width, capped so the column right of the target still fits on screen
-- (margin included).
local function SideWidth(scale)
    local edge = ns.RightOfTargetEdge()
    local width = SIDE.width * scale
    if edge then width = math.min(width, UIParent:GetRight() - edge - ns.SCREEN_MARGIN) end
    return ns.Snap(math.max(width, 120))
end

local function SideStyle(self, unit)
    local px = ns.PixelSize()
    local border = ns.BORDER_PIXELS
    -- near/far/dir only for the aura row: "inside" (start) is left here, towards screen center
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
    -- Height of one block in the column: frame + debuff row (for boss spacing)
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

    -- Cast bar over the health bar; texts centered like name and percent, icon outside right
    -- (the column is on the right, so "outside" is right here - unlike the player frame)
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

    -- Raid marker centered on the top edge, visible while casting too
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

    -- One row below the frame: debuffs on the left (inside), own first, then others (gray); on the
    -- far right important enemy buffs like on nameplates (purgeable with dispel band, plus Blizzard's
    -- "important" ones: shields, immunities, enrages), at most SIDE_BUFFS in total.
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

-- Hide empty power on other units (e.g. beasts without energy). Other units' power is secret on
-- Forever/Midnight, so it cannot be compared - a step curve turns the percentage directly into
-- text alpha (0% -> invisible), as Blizzard does itself.
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
        text:SetAlpha(alpha) -- SetAlpha accepts secret values
    elseif type(alpha) == "number" then
        text:SetAlpha(alpha)
    else
        text:SetAlpha(1)
    end
end

-- First and last name (Forever): UnitName returns the surname as second value.
-- ns.db.nameFormat: "first" Koratal, "full" Koratal Rabenruf, "firstInitial" Koratal R.,
-- "initialLast" K. Rabenruf, "last" Rabenruf. Secret names are passed through as is.
local function FirstChar(text)
    return text:match("^[%z\1-\127\194-\244][\128-\191]*") or text:sub(1, 1)
end
function ns.FormatUnitName(unit)
    local first, last = UnitName(unit)
    if first == nil or issecretvalue(first) then return first end
    if last == nil or issecretvalue(last) or last == "" then return first end
    local mode = ns.db and ns.db.nameFormat or "full"
    if mode == "first" then return first end
    if mode == "last" then return last end -- RP: surname as call name
    if mode == "firstInitial" then return first .. " " .. FirstChar(last) .. "." end
    if mode == "initialLast" then return FirstChar(first) .. ". " .. last end
    return first .. " " .. last
end
oUF.Tags.Vars.muiFormatName = ns.FormatUnitName

-- Rewrite all names (setting changed)
function ns.UpdateNameTags()
    for _, object in ipairs(oUF.objects) do
        if object.UpdateTags then object:UpdateTags() end
    end
end

-- Name, shortened if needed (ns.ShortenName); _FRAME is the frame the tag belongs to.
oUF.Tags.Methods["mui:name"] = [[function(u, r)
    local name = _VARS.muiFormatName(r or u)
    if _FRAME and _FRAME.ShortenName then return _FRAME:ShortenName(name) end
    return name
end]]
oUF.Tags.Events["mui:name"] = "UNIT_NAME_UPDATE"

-- Name in capitals (Cinzel); secret names pass through unchanged
oUF.Tags.Methods["mui:uname"] = [[function(u, r)
    local name = _VARS.muiFormatName(r or u)
    if name ~= nil and not issecretvalue(name) then name = name:upper() end
    if _FRAME and _FRAME.ShortenName then return _FRAME:ShortenName(name) end
    return name
end]]
oUF.Tags.Events["mui:uname"] = "UNIT_NAME_UPDATE"

-- Level in Surf Green plus a trailing space, only below max level (empty otherwise)
oUF.Tags.Methods["mui:level"] = [[function(u)
    local level = UnitLevel(u)
    if issecretvalue(level) or not level or level <= 0 or level >= GetMaxLevelForPlayerExpansion() then return end
    return "|cff8ecbb4" .. level .. "|r "
end]]
oUF.Tags.Events["mui:level"] = "UNIT_LEVEL PLAYER_LEVEL_UP"

-- Target level in difficulty color (gray/green/yellow/orange/red like Classic), boss "??" red
oUF.Tags.Methods["mui:tlevel"] = [[function(u)
    local level = UnitLevel(u)
    if issecretvalue(level) or not level then return end
    if level <= 0 then return " |cffff2020??|r" end
    local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
    if not color then return " " .. level end
    -- "same level" (Blizzard: yellow) in mUI sage; the other difficulty colors stay
    if QuestDifficultyColors and color == QuestDifficultyColors.difficult then return " |cff8ecbb4" .. level .. "|r" end
    return (" |cff%02x%02x%02x%d|r"):format(color.r * 255, color.g * 255, color.b * 255, level)
end]]
oUF.Tags.Events["mui:tlevel"] = "UNIT_LEVEL PLAYER_LEVEL_UP PLAYER_TARGET_CHANGED"

-- Current health or power, abbreviated (107.9K). AbbreviateNumbers accepts secret values.
oUF.Tags.Methods["mui:health"] = [[function(u)
    return _TAGS.dead(u) or _TAGS.offline(u) or AbbreviateNumbers(UnitHealth(u))
end]]
oUF.Tags.Events["mui:health"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

-- If the main resource is shown in the center, the frame text shows mana (like the bar).
oUF.Tags.Methods["mui:power"] = function(u)
    local powerType = ns.UsesCenterPower(u) and Enum.PowerType.Mana or nil
    local max = UnitPowerMax(u, powerType)
    if not issecretvalue(max) and max == 0 then return end
    local power = UnitPower(u, powerType)
    -- Hide empty power on others (e.g. beasts without energy); on yourself the 0 stays
    if not issecretvalue(power) and power == 0 and not UnitIsUnit(u, "player") then return end
    return AbbreviateNumbers(power)
end
oUF.Tags.Events["mui:power"] = "UNIT_POWER_FREQUENT UNIT_MAXPOWER UNIT_DISPLAYPOWER"

-- Deep shell (player/target): stacked 1 px lines around region with a band of pad between the
-- inner black line and the bronze edge. Returns how far the shell reaches beyond region.
local SHELL_BAND = { 0.075, 0.062, 0.045, 0.92 }
local BRONZE_LIT, BRONZE_DARK = { 0.86, 0.70, 0.44, 1 }, { 0.36, 0.25, 0.13, 1 }
function ns.AddDeepShell(region, pad)
    local px = ns.PixelSize()
    local shell = CreateFrame("Frame", nil, region)
    shell:SetFrameLevel(region:GetFrameLevel())
    local function Box(out, layer, sub)
        local t = shell:CreateTexture(nil, layer, nil, sub)
        t:SetPoint("TOPLEFT", region, "TOPLEFT", -out, out)
        t:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", out, -out)
        return t
    end
    -- ring of 1 px at distance out; top/bottom colours (sides get a vertical gradient)
    local function Ring(out, top, bottom, sub)
        local edges = {}
        for i = 1, 4 do
            local t = shell:CreateTexture(nil, "BORDER", nil, sub)
            t:SetTexture("Interface\\Buttons\\WHITE8X8")
            t:SetSnapToPixelGrid(false)
            t:SetTexelSnappingBias(0)
            edges[i] = t
        end
        local o, i1 = out, out - px
        edges[1]:SetPoint("TOPLEFT", region, "TOPLEFT", -o, o)
        edges[1]:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", o, i1)
        edges[1]:SetVertexColor(unpack(top))
        edges[2]:SetPoint("TOPLEFT", region, "BOTTOMLEFT", -o, -i1)
        edges[2]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", o, -o)
        edges[2]:SetVertexColor(unpack(bottom))
        edges[3]:SetPoint("TOPLEFT", region, "TOPLEFT", -o, i1)
        edges[3]:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", -i1, -i1)
        edges[4]:SetPoint("TOPLEFT", region, "TOPRIGHT", i1, i1)
        edges[4]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", o, -i1)
        for k = 3, 4 do
            edges[k]:SetGradient("VERTICAL", CreateColor(unpack(bottom)), CreateColor(unpack(top)))
        end
        return edges
    end
    local inner = px                -- black line touching the bar
    local band = inner + pad         -- warm dark band
    local edge = band + px           -- bronze edge
    local outline = edge + px        -- black outline
    local bandTex = Box(band, "BACKGROUND", 1)
    bandTex:SetColorTexture(unpack(SHELL_BAND))
    -- lit top of the band: a hint of light catching the inner rim
    local lit = shell:CreateTexture(nil, "BORDER", nil, 0)
    lit:SetColorTexture(1, 0.9, 0.7, 0.10)
    lit:SetPoint("TOPLEFT", region, "TOPLEFT", -band, band)
    lit:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", band, band - px)
    Ring(inner, { 0, 0, 0, 1 }, { 0, 0, 0, 1 }, 1)
    Ring(edge, BRONZE_LIT, BRONZE_DARK, 2)
    Ring(outline, { 0, 0, 0, 0.9 }, { 0, 0, 0, 0.9 }, 3)
    local shadow = shell:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetTexture(ns.SHADOW_TEXTURE)
    shadow:SetTextureSliceMargins(24, 24, 24, 24)
    if Enum.UITextureSliceMode then shadow:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    shadow:SetPoint("TOPLEFT", region, "TOPLEFT", -outline - 12, outline + 12)
    shadow:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", outline + 12, -outline - 12)
    return outline
end

-- Shaded bar: own texture with soft vertical shading, colour as a gentle horizontal gradient
-- (darker at the start, full colour at the filled end). Re-applied after every colour update.
local BAR_SHADE = ns.MEDIA .. "BarShade"
local GRADIENT_DEPTH = 0.72
local function ApplyGradient(bar)
    local tex = bar:GetStatusBarTexture()
    if not tex then return end
    local r, g, b = bar:GetStatusBarColor()
    if not (ns.Readable(r) and ns.Readable(g) and ns.Readable(b)) then return end
    local deep = CreateColor(r * GRADIENT_DEPTH, g * GRADIENT_DEPTH, b * GRADIENT_DEPTH, 1)
    local full = CreateColor(r, g, b, 1)
    if bar.muiMirrored then tex:SetGradient("HORIZONTAL", full, deep) else tex:SetGradient("HORIZONTAL", deep, full) end
end

function ns.ShadeBar(bar, mirrored)
    bar.muiMirrored = mirrored
    bar:SetStatusBarTexture(BAR_SHADE)
    bar.muiShaded = true -- style refreshes keep this texture
    local post = bar.PostUpdateColor
    bar.PostUpdateColor = function(element, ...)
        if post then post(element, ...) end
        ApplyGradient(element)
    end
    -- thin bevel over the fill: light top line, dark bottom line
    local top = bar:CreateTexture(nil, "OVERLAY", nil, 6)
    top:SetColorTexture(1, 1, 1, 0.10)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(ns.PixelSize())
    local bottom = bar:CreateTexture(nil, "OVERLAY", nil, 6)
    bottom:SetColorTexture(0, 0, 0, 0.35)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(ns.PixelSize())
end

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
    -- Health color from the theme; friendly units get the same green.
    oUF.colors.health:SetRGB(unpack(ns.HEALTH_COLOR))
    ns.ApplyPowerColors()
    for reaction = 5, 8 do
        oUF.colors.reaction[reaction] = oUF.colors.health
    end

    self:SetActiveStyle("Meredan")
    -- Anchor at the inner top corner: all sizes are whole pixels, so all edges land on whole pixels.
    ns.frames = {
        player = self:Spawn("player"),
        target = self:Spawn("target"),
    }
    ns.OnLayout(function()
        local x, y = ns.Snap(INNER_X), ns.Snap(TOP_Y)
        if ns.LayoutFlag("healerGroups") then
            -- Healer: left/right of the group, top-aligned with it (Core/Layouts.lua)
            local geo = ns.HealerGeometry()
            local _, cy = UIParent:GetCenter()
            x, y = ns.Snap(geo.innerX), cy - geo.groupTop
        end
        ns.PlaceFromCenter(ns.frames.player, "TOPRIGHT", -x, -y)
        ns.PlaceFromCenter(ns.frames.target, "TOPLEFT", x, -y)
    end)

    -- Class bar centered between the frames, a bit above the health bars' top edge (the main
    -- action bar sits at frame height).
    local playerFrame = ns.frames.player
    local classBar = playerFrame.ClassPower or playerFrame.Runes
    if classBar then
        ns.OnLayout(function()
            if ns.LayoutFlag("healerGroups") then return end -- healer: ActionBars.lua places it above the group
            ns.PlaceFromCenter(classBar.strip, "BOTTOM", 0, -ns.Snap(TOP_Y) + ns.Snap(SIZE.classPowerGap))
        end)
        ns.layoutFrames.classpower = classBar.strip
        -- Stagger follows the class bar
        if playerFrame.Stagger then playerFrame.Stagger:SetPoint("CENTER", classBar.strip, "CENTER") end
        if playerFrame.CenterPower then playerFrame.CenterPower:SetPoint("CENTER", classBar.strip, "CENTER") end
    end

    -- Pet and target of target below the debuff row, inner edges aligned
    local S = ns.frames.player.Sizes
    local below = S.aurasBelow + S.aura + 3 * S.auraOffset
    ns.smallFrames = {
        pet = self:Spawn("pet"),
        targettarget = self:Spawn("targettarget"),
    }
    ns.smallFrames.pet:SetPoint("TOPRIGHT", ns.frames.player, "BOTTOMRIGHT", 0, -below)
    ns.smallFrames.targettarget:SetPoint("TOPLEFT", ns.frames.target, "BOTTOMLEFT", 0, -below)

    -- Focus: right of the target (shared edge ns.RightOfTargetEdge), top-aligned
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

    -- Bosses hang on an anchor next to the quest tracker. Its anchor only exists after login
    -- (Quests/QuestTracker.lua then calls ns.PlaceBossFrames); until then, or without the tracker,
    -- right below the minimap.
    local bossAnchor = CreateFrame("Frame", "MeredanUIBossAnchor", UIParent)
    local bossCount = 5 -- like Blizzard's MAX_BOSS_FRAMES
    local side, step
    for i = 1, bossCount do
        local boss = self:Spawn("boss" .. i)
        side = side or boss.Sizes -- bosses have their own size step
        step = step or (side.block + side.gap)
        boss:SetPoint("TOPLEFT", bossAnchor, "TOPLEFT", 0, -(i - 1) * step)
        ns.sideFrames["boss" .. i] = boss
    end
    bossAnchor:SetSize(side.width, bossCount * step - side.gap)
    -- Left edge like the focus (follows the target, not the screen edge), top like the quest tracker.
    -- On 16:9 this overlaps the tracker - in the melee DPS layout the tracker moves below the visible
    -- boss frames and shows instance quests only (Quests/Tracker.lua).
    local function PlaceBossAnchor()
        local cx = UIParent:GetCenter()
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
    -- Called by the quest tracker module after login
    function ns.PlaceBossFrames()
        -- Boss frames hang on the anchor: locked in combat (e.g. /reload in combat) -> defer
        if InCombatLockdown() then return ns.AfterCombat(ns.PlaceBossFrames) end
        PlaceBossAnchor()
        ns.layoutFrames.boss = bossAnchor
    end
    C_Timer.After(1, ns.PlaceBossFrames) -- in case the quest tracker module never calls

end)

-- Shared edges next to player and target frames (boss timers, group frames): the cast bar icon
-- sits outside the frame (health bar height + gap), then SIDE_GAP.
local SIDE_GAP = 30
local function CastIconSpace(frame)
    local sizes = frame and frame.Sizes
    return sizes and (sizes.health or 0) + (sizes.step or 0) or 0
end

-- Right edge of the column left of the player frame (nil until it is placed)
function ns.LeftOfPlayerEdge()
    local player = ns.frames and ns.frames.player
    if not (player and player:GetLeft()) then return end
    return player:GetLeft() - CastIconSpace(player) - ns.Snap(SIDE_GAP)
end

-- Left edge of the column right of the target frame
function ns.RightOfTargetEdge()
    local target = ns.frames and ns.frames.target
    if not (target and target:GetRight()) then return end
    return target:GetRight() + CastIconSpace(target) + ns.Snap(SIDE_GAP)
end

-- mUI's own power colours, or Blizzard's (theme "Blizzard"; oUF's defaults are Blizzard's)
function ns.ApplyPowerColors()
    for token, color in pairs(ns.POWER_COLORS) do
        local c = oUF.colors.power[token]
        if c then
            c.muiBlizzard = c.muiBlizzard or { c:GetRGB() }
            c:SetRGB(unpack(ns.STYLE.blizzardPower and c.muiBlizzard or color))
        end
    end
end

-- After a theme, font or texture change: let oUF recompute colors.
function ns.OnStyleRefreshed()
    oUF.colors.health:SetRGB(unpack(ns.HEALTH_COLOR))
    ns.ApplyPowerColors()
    for _, list in ipairs({ ns.frames, ns.smallFrames, ns.sideFrames }) do
        for _, frame in pairs(list) do
            frame.Health.colorClass = ns.STYLE.classHealth
            frame:UpdateAllElements("MeredanStyle")
        end
    end
end

-- Player cast bar in the ranged layout: detached from the player frame, large above the bottom
-- action bars - as wide as the bars (icon on the left included), above the stance bar.
-- Otherwise an overlay in the player frame.
local BIG_CASTBAR_HEIGHT, BIG_CASTBAR_GAP = 32, 6 -- same height as the player's health bar
function ns.PlacePlayerCastbar()
    local castbar = ns.playerCastbar
    if not (castbar and castbar.muiHome) then return end
    local home, homeHeight = castbar.muiHome[1], castbar.muiHome[2]
    local iconFrame = castbar.Icon and castbar.Icon:GetParent()
    -- Ranged: above bar 3 (stance bar above that); healer: above the main bar (bottom 3 rows,
    -- stance bar sits to the left there)
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
        -- Own 1 px border (inside the player frame it shares the frame's border)
        castbar.muiBorder = castbar.muiBorder or ns.AddBorder(castbar)
        for _, edge in ipairs(castbar.muiBorder) do edge:Show() end
        castbar.muiDetached = true
    else
        for _, edge in ipairs(castbar.muiBorder or {}) do edge:Hide() end
        castbar:SetAllPoints(home)
        if iconFrame and castbar.muiDetached then
            -- Back to the default spot: outside the player frame, as high as the bar
            iconFrame:SetSize(homeHeight, homeHeight)
            iconFrame:ClearAllPoints()
            iconFrame:SetPoint(castbar.muiIconPoint[1], castbar, castbar.muiIconPoint[2], castbar.muiIconPoint[3], 0)
        end
        castbar.muiDetached = nil
    end
end
-- After the action bars (they set up on login)
ns:On("PLAYER_LOGIN", function()
    C_Timer.After(0.2, function()
        local castbar = ns.playerCastbar
        local iconFrame = castbar and castbar.Icon and castbar.Icon:GetParent()
        if iconFrame then -- remember the default icon spot
            local point, _, relPoint, x = iconFrame:GetPoint(1)
            castbar.muiIconPoint = { point, relPoint, x }
        end
        ns.OnLayout(ns.PlacePlayerCastbar)
    end)
end)
