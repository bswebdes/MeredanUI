-- Nameplates (oUF): layout like Blizzard's default plates, flat MUI look.
--
--   [D][D][D]                      [B][B]       <- own debuffs left, purgeable buffs right
--   +-----------------------------------+
--   | Name                         87 % | [CC]  <- health bar in priority color
--   +-----------------------------------+
--   +--+--------------------------------+
--   |i | Spell name      |          1.2 |       <- castbar with icon, text inside the bar;
--   +--+--------------------------------+          tick = where your interrupt is ready again
--   12.5 %                                      <- M+ forces of the mob (M+ only)
--
-- Target: 15 % larger, white arrows left and right, soft accent glow behind the bar. Other plates
-- are dimmed (unless casting).
-- Mouseover brightens the bar.
--
-- Health colors (highest priority first):
--   Threat (in combat): red = wrong aggro (DPS has it / tank lost it), orange = transitioning,
--   teal = another tank has it, sage (DPS) = someone else has it.
--   In dungeons/raids by enemy type: boss dark blue, lieutenant purple, caster magenta,
--   melee cyan, trivial gray. Otherwise the usual reaction colors (hostile red, neutral yellow ...).
--
-- Midnight protects many values (secrets): whether your interrupt is ready or a spell is important
-- or interruptible is never read, Blizzard converts it straight into colors
-- (C_CurveUtil.EvaluateColorValueFromBoolean). Friendly plates: name only.
local _, ns = ...
local oUF = ns.oUF
local L = ns.L

local WIDTH, HEALTH, CAST = 170, 20, 16
local AURA, CC_AURA = 22, 28
local GAP = 2
local PLATE_W, PLATE_H = WIDTH + 24, HEALTH + CAST + 14 -- health bar + castbar + padding
local NAME_WIDTH = WIDTH - 40 -- remainder is kept for "100%"
local DIM_ALPHA = 0.5      -- plates that are not your target (while you have one)
local TARGET_SCALE = 1.15  -- target plate slightly larger

local C = {
    -- Threat
    warning = { 0.8, 0, 0 }, transition = { 1, 0.63, 0 }, offtank = { 0.06, 0.67, 0.78 },
    onTank = { 0.557, 0.796, 0.706 }, -- DPS: mob in combat but not on you (tank/pet has it) - mUI sage
    -- Enemy type (dungeons/raids)
    boss = { 0, 0.23, 1 }, miniboss = { 0.43, 0, 0.92 }, caster = { 0.74, 0, 0.67 },
    melee = { 0, 0.93, 0.99 }, trivial = { 0.49, 0.48, 0.51 },
    -- Otherwise
    hostile = { 0.85, 0.1, 0.1 }, neutral = { 1, 0.93, 0.29 }, friendly = { 0.2, 0.8, 0.2 },
    tapped = { 0.43, 0.43, 0.43 },
    -- Castbar
    cast = { 0.99, 0.8, 0 }, channel = { 0, 0.45, 0.78 }, important = { 1, 0.39, 0 },
    uninterruptible = { 0.51, 0.51, 0.51 }, kickReady = { 0.1, 0.85, 0.1 }, interrupted = { 0.85, 0.15, 0.15 },
    targetsYou = { 1, 1, 1 },
}

-- Interrupt spells per class; the first one the character knows is used
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
            or C_SpellBook.IsSpellKnown(id, Enum.SpellBookSpellBank.Pet) then -- warlock: pet interrupt
            kickSpell = id
            return
        end
    end
end
ns:On("PLAYER_LOGIN", UpdateKickSpell)
ns:On("SPELLS_CHANGED", UpdateKickSpell)

-- Names above heads (world names) in our font - WoW reads this when the world loads
UNIT_NAME_FONT = ns.DEFAULT_FONT

local inInstance = false -- dungeon or raid: enemy type colors
ns:On("PLAYER_ENTERING_WORLD", function()
    local _, instanceType = IsInInstance()
    inInstance = instanceType == "party" or instanceType == "raid"
end)

-- Helpers ------------------------------------------------------------------------------------

-- oUF stores the nameplate unit in __unit (unit stays empty)
local function UnitOf(frame)
    return frame and (frame.__unit or frame.unit)
end

local function Readable(...)
    for i = 1, select("#", ...) do
        if issecretvalue((select(i, ...))) then return false end
    end
    return true
end

local function Bool(value) -- nil -> false, without touching secret values
    if issecretvalue(value) then return value end
    return value and true or false
end

-- Color from a (possibly secret) boolean: Blizzard evaluates, we never read it.
-- Returns r, g, b (no table: runs every 0.1 s per casting plate).
local function Pick(bool, ifTrue, r, g, b)
    local E = C_CurveUtil.EvaluateColorValueFromBoolean
    return E(bool, ifTrue[1], r), E(bool, ifTrue[2], g), E(bool, ifTrue[3], b)
end

-- Spec role is cached (threat colors ask per plate and threat event); reset on spec change
local specTank
local function IsTank()
    if ns.LayoutFlag and ns.LayoutFlag("tank") then return true end -- layout "Tank" (secret-safe)
    if specTank == nil then
        local spec = C_SpecializationInfo.GetSpecialization()
        local role = spec and select(5, C_SpecializationInfo.GetSpecializationInfo(spec))
        specTank = role == "TANK"
    end
    return specTank
end
for _, event in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_ENTERING_WORLD" }) do
    ns:On(event, function() specTank = nil end)
end

-- Other tanks in the group, rebuilt on roster/role changes instead of per threat check
local otherTanks = {}
local function UpdateOtherTanks()
    wipe(otherTanks)
    local raid = IsInRaid()
    for i = 1, GetNumGroupMembers() do
        local member = (raid and "raid" or "party") .. i
        if UnitExists(member) and not UnitIsUnit(member, "player") then
            local role = UnitGroupRolesAssigned(member)
            if Readable(role) and role == "TANK" then otherTanks[#otherTanks + 1] = member end
        end
    end
end
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD" }) do
    ns:On(event, UpdateOtherTanks)
end

-- Enemy type: boss, lieutenant, caster (has mana), melee, trivial
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

-- Threat -> color, or nil (nothing special)
local function ThreatColor(unit)
    local inCombat = UnitAffectingCombat(unit)
    if not (Readable(inCombat) and inCombat) then return end
    local status = UnitThreatSituation("player", unit)
    if not Readable(status) then return end
    if IsTank() then
        if status == 1 or status == 2 then return C.transition end
        if status == nil or status == 0 then
            -- Does another tank have aggro? Then teal, else red (lost)
            for _, member in ipairs(otherTanks) do
                local other = UnitThreatSituation(member, unit)
                if Readable(other) and other == 3 then return C.offtank end
            end
            return C.warning
        end
    else
        -- DPS: red only if you have aggro; if someone else holds it (tank, your pet): sage
        -- instead of the normal color
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

-- oUF override: we determine the health color entirely ourselves
local function UpdateHealthColor(self, event, unit)
    local own = UnitOf(self)
    if not own or (unit and unit ~= own) then return end
    local color = HealthColor(own)
    self.Health:SetStatusBarColor(color[1], color[2], color[3])
    ns.ColorBarBackground(self.Health)
end
UpdateHealthColor = ns.PerfProbe("Plates: health color", UpdateHealthColor)

-- Castbar color: uninterruptible (gray) > your interrupt is ready (green) > normal (yellow,
-- channel blue). Important spells additionally get a pulsing orange border, so every piece of
-- information stays visible.
-- Interrupt cooldown: asked once per frame, shared by all casting plates
-- IsZero() may be secret: never tested here, only handed to Pick (has = whether there is one)
local kickAt, kickHas, kickReady
local function KickReady()
    local now = GetTime()
    if kickAt ~= now then
        kickAt = now
        local duration = kickSpell and C_Spell.GetSpellCooldownDuration(kickSpell, true)
        kickHas = duration and true or false
        if kickHas then kickReady = duration:IsZero() else kickReady = false end
    end
    return kickHas, kickReady
end

-- full = cast start/change: also the "important spell" glow (fixed per cast); the 0.1 s
-- refresh only updates the colors and the "targets you" glow
local function UpdateCastColor(castbar, full)
    local base = castbar.muiChannel and C.channel or C.cast
    local r, g, b = base[1], base[2], base[3]
    local has, ready = KickReady()
    if has then r, g, b = Pick(ready, C.kickReady, r, g, b) end
    r, g, b = Pick(Bool(castbar.muiNotInterruptible), C.uninterruptible, r, g, b)
    castbar:SetStatusBarColor(r, g, b)
    if full and castbar.importantGlow then
        -- spellID may be secret: never test it directly, only pass it to Blizzard
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
UpdateCastColor = ns.PerfProbe("Plates: cast color", UpdateCastColor)

-- Interrupt tick: white line on the castbar where your interrupt becomes ready again.
-- Cooldown and cast time may be secret, so an invisible helper bar (max = cast time,
-- value = remaining cooldown) computes the position and the line hangs at its end.
-- If the interrupt is already ready, the castbar is green and the tick hidden.
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

-- Visibility: target/casters full, others dimmed while you have a target
-- Questie hangs its quest icon at the left of Blizzard's plate frame (wider than our bar), far off
-- the bar. Questie anchors it only when creating it ("LEFT" point), so re-anchoring that point is
-- safe. Fixed spot close to the (unscaled) bar, drawn above the plate so the larger target plate
-- doesn't cover it.
local function PlaceQuestieIcon(frame)
    local plate = frame:GetParent()
    if not plate then return end
    for _, child in ipairs({ plate:GetChildren() }) do
        if child ~= frame and child.Icon and child.lastIcon ~= nil and not child:GetName() then
            child:SetPoint("LEFT", plate, "CENTER", -(WIDTH / 2 + 3 + child:GetWidth()), 0)
            child:SetFrameStrata(frame:GetFrameStrata())
            child:SetFrameLevel(frame:GetFrameLevel() + 20)
        end
    end
end

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
    -- game objects get a plate with soft targeting (Loot/Sparkle.lua): nothing of ours to show
    local isObject = UnitIsGameObject(unit)
    if Readable(isObject) and isObject then alpha = 0 end
    -- corpses only get a plate as soft-interact target (sparkle): no health bar on them
    local dead = UnitIsDead(unit)
    if Readable(dead) and dead then alpha = 0 end
    if frame.muiAlpha ~= alpha then
        frame.muiAlpha = alpha
        frame:SetAlpha(alpha)
    end
    local target = Readable(isTarget) and isTarget or false
    frame.targetBorder:SetShown(target)
    frame.targetGlow:SetShown(target and not frame.isFriendly) -- friendly plates are name only: no glow on text
    -- Scale around the center (oUF frame fills the plate, content is anchored centrally)
    local scale = target and TARGET_SCALE or 1
    if frame.muiScale ~= scale then
        frame.muiScale = scale
        frame:SetScale(scale)
    end
    frame.hoverGlow:SetShown(frame.hovered or false)
end

local plates = {}

-- Plate setup ---------------------------------------------------------------------------------

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

    -- Health
    local health = ns.CreateBar(self, ns.Snap(HEALTH))
    health:SetSize(ns.Snap(WIDTH), ns.Snap(HEALTH))
    health:SetPoint("CENTER")
    -- light look: shaded bar (B3) and a very thin shell (black, material edge, black); the shell's
    -- filled shadow goes on the plate below the bar
    health:SetStatusBarTexture(ns.MEDIA .. "BarShade")
    health.muiShaded = true
    local _, healthShell = ns.AddDeepShell(health, 0, { shadow = 4, shadowParent = self })
    self.HealthShadow = healthShell.shadow
    health.UpdateColor = UpdateHealthColor
    health.colorThreat = true -- only so oUF registers the threat events; we do the coloring
    self.Health = health

    -- Target: two slim white arrows left and right, pointing at the bar
    local targetBorder = CreateFrame("Frame", nil, health)
    targetBorder:SetAllPoints()
    for _, side in ipairs({ { "RIGHT", "LEFT", -1, -math.pi / 2 }, { "LEFT", "RIGHT", 1, math.pi / 2 } }) do
        local arrow = ns.UI.Icon(targetBorder, "ChevronDown", HEALTH + 8, { 1, 1, 1 })
        arrow:SetPoint(side[1], health, side[2], side[3], 0)
        arrow:SetRotation(side[4])
    end
    targetBorder:Hide()
    self.targetBorder = targetBorder
    -- plus a soft accent glow behind the bar, fading out on all sides (like Plater's target highlight).
    -- On the plate itself, so it sits under the bar (the bar is a child frame).
    local glow = self:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ns.MEDIA .. "Glow")
    glow:SetPoint("TOPLEFT", health, "TOPLEFT", -30, 14)
    glow:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 30, -14)
    glow:SetVertexColor(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.7)
    glow:SetBlendMode("ADD") -- brightens the ground: reads as light, not as a coloured patch
    glow:Hide()
    self.targetGlow = glow

    -- Mouseover: bar brightens slightly
    local hoverGlow = health:CreateTexture(nil, "OVERLAY", nil, 1)
    hoverGlow:SetAllPoints(health:GetStatusBarTexture())
    hoverGlow:SetColorTexture(1, 1, 1, 0.18)
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:Hide()
    self.hoverGlow = hoverGlow

    local name = ns.CreateText(health, 12, "LEFT", "OUTLINE")
    name:SetPoint("LEFT", 4, 0)
    name:SetWidth(NAME_WIDTH)
    -- Shorten long names ("Lightfeather Petalwing" -> "L. Petalwing").
    -- Names are secret in instances - then WoW just truncates with "..."
    self.nameWidth = NAME_WIDTH -- shorter while the quest icon is in front
    self.ShortenName = function(frame, text) return ns.ShortenName(text, name, frame.nameWidth) end
    self:Tag(name, "[mui:name]")
    self.NameText = name
    -- Pet owner: small line below the name ("Kalithera's pet"), friendly plates only
    local sub = ns.CreateText(self, 10, "CENTER", "OUTLINE")
    sub:SetTextColor(0.8, 0.8, 0.8)
    sub:Hide()
    self.SubText = sub

    local percent = ns.CreateText(health, 10, "RIGHT", "OUTLINE")
    percent:SetPoint("RIGHT", -4, 0)
    self:Tag(percent, "[perhp]%")
    self.PercentText = percent

    -- Castbar directly below the health bar, same width; icon left inside the border, text in the bar
    local cast = ns.Snap(CAST)
    local castFrame = CreateFrame("Frame", nil, self)
    castFrame:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -GAP - 6 * px) -- clear of both thin shells
    castFrame:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -GAP - 6 * px)
    castFrame:SetHeight(cast)
    local castbar = ns.CreateBar(self, cast)
    castbar:SetPoint("TOPLEFT", castFrame, "TOPLEFT", cast + px, 0)
    castbar:SetPoint("BOTTOMRIGHT", castFrame, "BOTTOMRIGHT")
    castbar.PostUpdateColor = nil
    castbar:SetStatusBarTexture(ns.MEDIA .. "BarShade")
    castbar.muiShaded = true
    castFrame:SetParent(castbar) -- border and icon only visible while casting
    castFrame:SetFrameLevel(castbar:GetFrameLevel() + 2)
    ns.AddDeepShell(castFrame, 0, { shadow = 4, shadowParent = castbar })
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
    -- Important spell: pulsing orange border (visibility set by UpdateCastColor)
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
    -- oUF keeps spell ID, interruptibility and channeling internal - we capture them from the
    -- callbacks (values may be secret and are only passed on to Blizzard)
    castbar.PostCastStart = function(bar, unit, spellID, notInterruptible)
        local channel = UnitChannelInfo(unit)
        bar.muiChannel = issecretvalue(channel) or channel ~= nil
        bar.muiSpellID = spellID
        bar.muiNotInterruptible = notInterruptible
        UpdateCastColor(bar, true)
        UpdateKickTick(bar)
        UpdateAlpha(self)
    end
    castbar.PostCastInterruptible = function(bar, _, _, notInterruptible)
        bar.muiNotInterruptible = notInterruptible
        UpdateCastColor(bar, true)
    end
    castbar.PostCastStop = function() UpdateAlpha(self) end
    castbar.PostCastFail = function(bar)
        bar:SetStatusBarColor(unpack(C.interrupted))
        UpdateAlpha(self)
    end
    -- The interrupt can come off cooldown mid-cast: refresh the color regularly
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

    -- Auras: own debuffs top left, purgeable/soothable buffs top right,
    -- crowd control to the right of the plate
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

    -- Raid marker on the left, M+ forces bottom left
    local raidIcon = health:CreateTexture(nil, "OVERLAY", nil, 7)
    raidIcon:SetSize(22, 22)
    raidIcon:Hide() -- otherwise the whole marker sheet shows until the first update
    raidIcon:SetPoint("RIGHT", health, "LEFT", -HEALTH - 10, 0)
    self.RaidTargetIndicator = raidIcon

    local forces = ns.CreateText(self, 10, "LEFT", "OUTLINE")
    forces:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -GAP - cast - 4)
    forces:SetTextColor(1, 0.85, 0)
    self.ForcesText = forces

    -- Quest mobs: yellow "!" with progress inside the bar right before the name (the name shifts
    -- right and gets shorter accordingly, see UpdateNamePrefix)
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

    -- Rare/elite: Blizzard's own icons in front (elite only outside instances - almost everything is elite there)
    local classIcon = health:CreateTexture(nil, "OVERLAY", nil, 6)
    classIcon:SetSize(16, 16)
    classIcon:Hide()
    self.ClassificationIcon = classIcon

    -- Execute line (Core/Style.lua)
    ns.AddExecuteLine(health)
end

-- Progress of the first open quest objective from Blizzard's unit tooltip data
-- ("3/8 Kobolds slain" -> "3/8", "Area liberated: 45 %" -> "45%"). Secret -> nothing.
local QUEST_LINE = Enum.TooltipDataLineType.QuestObjective

-- Tooltip scans are cached: quest progress per GUID until the next quest update, NPC titles per
-- NPC ID, pet owners per GUID. GUIDs may be secret (instances): then no cache, scan as before.
local progressCache, titleCache, ownerCache, cacheCount = {}, {}, {}, 0
local NONE = false -- cached "nothing found"
local function CacheKey(unit, npcOnly)
    local guid = UnitGUID(unit)
    if not guid or not Readable(guid) then return end
    if npcOnly then
        local kind, _, _, _, _, npcID = strsplit("-", guid)
        if kind ~= "Creature" and kind ~= "Vehicle" then return end
        return npcID
    end
    return guid
end
local function CacheStore(cache, key, value)
    cacheCount = cacheCount + 1
    if cacheCount > 600 then -- cap: busy cities would grow it forever
        wipe(progressCache); wipe(titleCache); wipe(ownerCache)
        cacheCount = 0
    end
    if value == nil then cache[key] = NONE else cache[key] = value end
end
local function Cached(cache, key, scan, unit)
    if not key then return scan(unit) end
    local value = cache[key]
    if value == nil then
        value = scan(unit)
        CacheStore(cache, key, value)
        return value
    end
    if value == NONE then return nil end
    return value
end
ns:On("PLAYER_ENTERING_WORLD", function()
    wipe(progressCache); wipe(titleCache); wipe(ownerCache)
    cacheCount = 0
end)

local function ScanQuestProgress(unit)
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
local function QuestProgress(unit) return Cached(progressCache, CacheKey(unit), ScanQuestProgress, unit) end

-- Rare/elite icon like Blizzard's plates (NamePlateClassificationFrameMixin)
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

-- Is the mob part of an active quest? Asks Blizzard directly (C_QuestLog), no tooltip guessing.
-- Not in M+ (quests don't count there).
local function IsQuestUnit(unit)
    if C_PartyInfo.IsChallengeModeActive and C_PartyInfo.IsChallengeModeActive() then return false end
    local related = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
    return Readable(related) and related or false
end

-- Row inside the bar before the name: [rare/elite][! 3/8] Name. The name shifts right and gets
-- shorter accordingly. Runs after ApplyFriendly (which resets the name).
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
    -- Friendly name plates (NPCs, players, pets): no truncation/"..."
    local width = frame.isFriendly and 400 or NAME_WIDTH - (offset - 4)
    if frame.nameWidth ~= width then
        frame.nameWidth = width
        name:SetWidth(width)
        frame:UpdateTags() -- re-shorten the name for the new width
    end
    if frame.isFriendly then return end
    name:ClearAllPoints()
    name:SetPoint("LEFT", frame.Health, "LEFT", offset, 0)
end
UpdateNamePrefix = ns.PerfProbe("Plates: name prefix", UpdateNamePrefix)

-- M+ forces (computed by Blizzard; active keystones and enemies only)
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

-- With oUF, Blizzard's own plate frame stays invisibly on top of ours and swallows clicks.
-- It keeps its position (the game stacks plates by it) but is made invisible and
-- click-through, including all children.
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
    -- Blizzard's "soft target" icon (sword/hand) gets attached to the plate by oUF - right on the name
    if blizz.SoftTargetFrame and blizz.SoftTargetFrame:GetParent() ~= hiddenParent then
        blizz.SoftTargetFrame:SetParent(hiddenParent)
    end
end

-- Hit area like Blizzard's: health bar plus some margin, anchored to the plate
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

-- Stacking: Blizzard pushes plates apart by this area - health bar plus castbar, otherwise the
-- castbar overlaps the plate below. Like Plater (Midnight): the area is centered on our plate frame
-- and re-registered on every show. /mui stack shows it in green.
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
    -- Health bar is centered, castbar below: center the area on both
    box:SetPoint("CENTER", frame, "CENTER", 0, -(GAP + CAST) / 2)
    box:SetSize(WIDTH + 10, STACK_H)
    -- Blizzard only counts an area with a drawn texture: keep the texture on, invisible otherwise
    -- (same as Plater; without it nothing stacks)
    box.debug:SetColorTexture(0.1, 0.8, 0.1, showStackBoxes and 0.35 or 0)
    nameplate:SetStackingBoundsFrame(box)
end

ns.AddCommand("stack", L["Show the nameplate stacking area"], function()
    showStackBoxes = not showStackBoxes
    for frame in pairs(plates) do
        if frame.StackBox then frame.StackBox.debug:SetColorTexture(0.1, 0.8, 0.1, showStackBoxes and 0.35 or 0) end
    end
    local value = C_CVar.GetCVar("nameplateStackingTypes")
    local on = C_CVar.GetCVarBitfield and C_CVar.GetCVarBitfield("nameplateStackingTypes", Enum.NamePlateStackType.Enemy)
    ns.Print("Stacking: %s (CVar %s)", tostring(on), tostring(value))
end, true)

-- Blizzard marks minor mobs as "simplified" and shrinks their plate internally, so they stack
-- far too tightly. Our plates always have the same size -> turn it off.
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

-- Blizzard's (hidden) plate frame resets the hit area to its own bar on every update - set ours
-- again right after (same tick, allowed in combat too)
if NamePlateUnitFrameMixin and NamePlateUnitFrameMixin.UpdateHitTestArea then
    hooksecurefunc(NamePlateUnitFrameMixin, "UpdateHitTestArea", function(blizzFrame)
        local nameplate = blizzFrame.GetNamePlateFrame and blizzFrame:GetNamePlateFrame()
        local frame = nameplate and nameplate.unitFrame
        if frame and frame.isNamePlate and frame:IsShown() then SetHitBox(frame) end
    end)
end

-- Pet owner from the tooltip line ("Pet of Kalithera Novaris" / "X's Pet") - first name only.
-- Texts may be secret in instances; then no line.
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

local function ScanPetOwner(unit)
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

local FRIENDLY_NAME_SIZE = { small = 12, medium = 14, large = 16 } -- "Name size" setting

-- NPC title from the tooltip line below the name ("Mining Trainer"); level lines don't count
local function ScanNpcTitle(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    local line = ok and data and data.lines and data.lines[2]
    local text = line and line.leftText
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) or text == "" then return end
    if text:find("%d") then return end -- "Level 30", "Level 12 Humanoid"
    return text
end
local function PetOwner(unit) return Cached(ownerCache, CacheKey(unit), ScanPetOwner, unit) end
local function NpcTitle(unit) return Cached(titleCache, CacheKey(unit, true), ScanNpcTitle, unit) end

-- German genitive ("Kalitheras" / "Mox'") on deDE, otherwise "Kalithera's pet"
local function PetTitle(owner)
    if GetLocale() == "deDE" then
        local ends = owner:lower():match("[sßxz]$") or owner:lower():match("tz$")
        return (ends and (owner .. "'") or (owner .. "s")) .. " " .. L["Companion"]
    end
    return L["%s's pet"]:format(owner)
end

-- Friendly plates: name only (class or reaction color, 14 px), no bars; pets get a short owner
-- line below
local function ApplyFriendly(frame, unit)
    local friendly = not UnitCanAttack("player", unit)
    frame.isFriendly = friendly
    frame.Health:SetAlpha(friendly and 0 or 1)
    frame.HealthShadow:SetAlpha(friendly and 0 or 1) -- lies on the plate, not on the bar
    frame.Castbar:SetAlpha(friendly and 0 or 1)
    for _, row in ipairs(frame.AuraRows) do row:SetShown(not friendly) end
    frame.NameText:ClearAllPoints()
    frame.NameText:SetParent(friendly and frame or frame.Health)
    local controlled = friendly and UnitPlayerControlled(unit)
    if issecretvalue and issecretvalue(controlled) then controlled = false end -- may be secret in instances
    local isPlayer = UnitIsPlayer(unit)
    if issecretvalue and issecretvalue(isPlayer) then isPlayer = false end
    local owner = controlled and not isPlayer and PetOwner(unit) or nil
    -- Second line: owner for pets, otherwise the NPC title ("Mining Trainer")
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
        -- Players: class color; NPCs/pets: friendly sage, neutral yellow, hostile (not attackable,
        -- e.g. Horde on a PvE realm) red
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
ApplyFriendly = ns.PerfProbe("Plates: friendly", ApplyFriendly)

oUF:RegisterStyle("MeredanPlate", Style)

oUF:Factory(function(self)
    -- off, or another nameplate addon does the job (Core/OtherAddons.lua)
    if not ns.ModuleOn("nameplates") then return end
    self:SetActiveStyle("MeredanPlate")
    local driver = self:SpawnNamePlates("MeredanUIPlate")
    driver:SetSize(PLATE_W, PLATE_H) -- plate size (the hit area is limited to it)
    if ns.Questie then ns.Questie.RestoreNameplateSettings() end
    -- Blizzard resets the plate size to its own on every options/window change (also on login),
    -- after which plates stack too tightly. Re-apply our size right away.
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
        C_Timer.After(0, function() PlaceQuestieIcon(frame) end) -- Questie adds its icon on the same event
    end)
    driver:SetTargetCallback(function() end)
    -- oUF enlarges the hit area with huge negative insets, which makes plates unclickable.
    -- 0 = exactly our HitBox area.
    local function ResetInsets()
        ns.AfterCombat(function()
            C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy, 0, 0, 0, 0)
            C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Friendly, 0, 0, 0, 0)
        end)
    end
    ResetInsets()
    C_Timer.After(0, ResetInsets) -- after oUF's own PLAYER_LOGIN
    -- Stack enemy plates instead of overlapping (Blizzard option, set once; your later choice wins)
    if not ns.db.nameplatesStackSet and C_CVar.GetCVar("nameplateStackingTypes") then
        ns.AfterCombat(function()
            local ok = pcall(C_CVar.SetCVarBitfield, "nameplateStackingTypes", Enum.NamePlateStackType.Enemy, true)
            if ok then ns.db.nameplatesStackSet = true end
        end)
    end
    -- mUI's plate CVars, temporary (ns.LookCVar), every login: same size for all plates (otherwise
    -- Blizzard enlarges the target and stacks by the normal size, so it overlapped the others; mUI
    -- dims the others instead), always show plates, and mUI names instead of Blizzard's world names
    ns.AfterCombat(function()
        for _, cvar in ipairs({ "nameplateSelectedScale", "nameplateMinScale", "nameplateMaxScale" }) do
            ns.LookCVar(cvar, "1")
        end
        ns.LookCVar("nameplateShowAll", "1")
        ns.SetMuiNames(ns.db.npMuiNames ~= false)
    end)
end)

-- "mUI names instead of Blizzard names": on = Blizzard world names off, friendly NPCs and pets on
-- mUI plates; off = the player's own settings again. Temporary CVars, works without reload.
local WORLD_NAME_CVARS = { "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNameHostleNPC",
    "UnitNamePlayerGuild", "UnitNameFriendlyGuardianName", "UnitNameFriendlyMinionName", "UnitNameFriendlyTotemName",
    "UnitNameEnemyPetName", "UnitNameEnemyGuardianName", "UnitNameEnemyMinionName", "UnitNameEnemyTotemName",
    "UnitNameNPC", "UnitNameFriendlySpecialNPCName", "UnitNameInteractiveNPC", "UnitNameFriendlyPetName" }
local MUI_PLATE_CVARS = { "nameplateShowFriendlyNpcs", "nameplateShowFriendlyPlayerPets", "nameplateShowFriendlyPlayers" }
function ns.SetMuiNames(useMui)
    ns.db.npMuiNames = useMui and true or false
    ns.AfterCombat(function()
        -- temporary values; off = drop them, the player's own settings apply again
        for _, cvar in ipairs(WORLD_NAME_CVARS) do ns.LookCVar(cvar, useMui and "0" or nil) end
        for _, cvar in ipairs(MUI_PLATE_CVARS) do ns.LookCVar(cvar, useMui and "1" or nil) end
    end)
end

-- Settings changed (name size, title, owner): rebuild all visible plates
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
-- Quest progress changed: update all plates once, batched (events arrive in bursts)
local questPending = false
local function QueueQuestUpdate()
    if questPending then return end
    questPending = true
    C_Timer.After(0.2, function()
        questPending = false
        wipe(progressCache) -- progress changed: scan again
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
local function RecolorAll()
    for frame in pairs(plates) do
        if UnitOf(frame) and not frame.isFriendly then UpdateHealthColor(frame) end
    end
end
ns:On("PLAYER_REGEN_DISABLED", RecolorAll)
ns:On("PLAYER_REGEN_ENABLED", RecolorAll)
-- Threat changes come per mob: recolor only that plate. Other tokens (target, boss1 ...) or
-- events without unit: one batched pass over all plates (threat events are unreliable in
-- Forever, so nothing is dropped).
local recolorPending = false
ns:On("UNIT_THREAT_LIST_UPDATE", function(_, unit)
    if unit then
        for frame in pairs(plates) do
            if UnitOf(frame) == unit then
                if not frame.isFriendly then UpdateHealthColor(frame) end
                return
            end
        end
    end
    if recolorPending then return end
    recolorPending = true
    C_Timer.After(0.2, function()
        recolorPending = false
        RecolorAll()
    end)
end)

-- Mouse over a plate: there is no "mouse left" event, so poll briefly
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
