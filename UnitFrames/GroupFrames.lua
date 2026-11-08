-- Grid-style group and raid frames (oUF headers, one column per 5-man group, player included);
-- Blizzard's party/raid frames are hidden. Group (up to 15 players) sits left of the player frame,
-- raids from 16 players bottom left above the chat; the healer layout has its own placement.
-- Health/auras are secret in combat on Midnight - values only go through oUF into StatusBar:SetValue.
local _, ns = ...
local oUF = ns.oUF
local UpdateAggro, UpdateMissingBuff, missingFrames -- defined below (aggro, missing buffs)

-- Fixed sizes (healer layout has its own in ns.HEALER). kind = "group", "raid" or "raid40".
local SIZES = { group = { 130, 62 }, raid = { 96, 44 }, raid40 = { 72, 32 } }
local function Size(kind)
    local size = SIZES[kind] or SIZES.raid
    return ns.Snap(size[1]), ns.Snap(size[2])
end
local GAP = 4               -- between frames and columns
local DEBUFF_SIZE, DEBUFF_MAX = 16, 3
local BOSS_SIZE, BOSS_MAX = 30, 2 -- boss/role debuffs, large and centered above the name;
-- max 2 - Blizzard's container adapts its width, so anchored at the center 1 or 2 stay centered
local ICON_SIZE = 12        -- role, defensives, leader
local STATUS_ICON = 14      -- status icons below the name
local HOT_SIZE = 16          -- healer: own HoTs, bottom center
-- Own HoTs (all ranks, Classic IDs - verify in game): one fixed slot per group
local HEALER_HOTS = {
    { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315,              -- Renew
      774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 },         -- Rejuvenation
    { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 },                     -- Regrowth
    { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },               -- Power Word: Shield
}
local LEADER_SIZE = 13      -- crown top left, same size as role icons (white: gold is hard to see this small)
local POWER_HEIGHT = 4      -- healer mana bar (bottom of the frame)
local BOSS_BAR_RESERVE = 260 -- kept free right of the raid for the boss timers left of the player frame
local RAID_CHAT_GAP = 90   -- raid <-> top of the chat (room for edit box and tabs)
local testing = false       -- running demo ("group"/"raid"/"raid40", below): mana even without healers
local hidden = CreateFrame("Frame")
hidden:Hide()

local function Enabled() return ns.db.groupFrames ~= false end

-- Role with MUI icons (tank/healer; none for DPS)
local ROLE_ICONS = { TANK = "RoleTank", HEALER = "RoleHeal" }
local function IsHealer(self)
    local role = self.unit and UnitGroupRolesAssigned(self.unit)
    return ns.Readable(role) and role == "HEALER"
end

-- Mana for healers only; oUF would always show the bar, so decide after every update
local function PowerVisibility(power)
    power:SetShown(testing or IsHealer(power.__owner))
end

local function UpdateRole(self)
    local element = self.GroupRoleIndicator
    local role = UnitGroupRolesAssigned(self.unit)
    local icon = ns.Readable(role) and ROLE_ICONS[role]
    if self.Power then PowerVisibility(self.Power) end
    if icon then
        element:SetTexture(ns.MEDIA .. "Icons\\" .. icon)
        element:Show()
    else
        element:Hide()
    end
end

-- Offline and AFK icons (secret values -> show nothing); from Health.PostUpdate and flag events
local function UpdateFlags(self, _, unit)
    unit = self.unit
    if not unit or not self.OfflineIcon then return end
    local connected, afk = UnitIsConnected(unit), UnitIsAFK(unit)
    local offline = ns.Readable(connected) and connected == false
    local away = not offline and ns.Readable(afk) and afk == true
    self.OfflineIcon:SetShown(offline)
    self.AfkIcon:SetShown(away)
end

-- Healer: missing health ("-123") replaces the name in the same spot. Health can be secret, so
-- never compare it - step curves set the text alpha instead: at 100% the name shows, below it the
-- number. Dead/offline: always the name.
local nameAlphaCurve, deficitAlphaCurve
if C_CurveUtil and C_CurveUtil.CreateCurve then
    nameAlphaCurve = C_CurveUtil.CreateCurve()
    nameAlphaCurve:SetType(Enum.LuaCurveType.Step)
    nameAlphaCurve:AddPoint(0, 0)
    nameAlphaCurve:AddPoint(1, 1)
    deficitAlphaCurve = C_CurveUtil.CreateCurve()
    deficitAlphaCurve:SetType(Enum.LuaCurveType.Step)
    deficitAlphaCurve:AddPoint(0, 1)
    deficitAlphaCurve:AddPoint(1, 0)
end

local function UpdateNameOrDeficit(self, unit)
    local deficit = self.muiDeficit
    if not deficit or self.muiDemo or not nameAlphaCurve then return end
    unit = unit or self.unit
    local dead, online = UnitIsDeadOrGhost(unit), UnitIsConnected(unit)
    if (ns.Readable(dead) and dead) or (ns.Readable(online) and not online) then
        local r, g, b = self.muiName:GetTextColor()
        self.muiName:SetTextColor(r, g, b, 1)
        deficit:SetTextColor(1, 1, 1, 0)
        deficit.minus:SetTextColor(1, 1, 1, 0)
        return
    end
    local nameAlpha = UnitHealthPercent(unit, true, nameAlphaCurve)
    local deficitAlpha = UnitHealthPercent(unit, true, deficitAlphaCurve)
    local r, g, b = self.muiName:GetTextColor()
    self.muiName:SetTextColor(r, g, b, nameAlpha)
    deficit:SetTextColor(1, 1, 1, deficitAlpha)
    deficit.minus:SetTextColor(1, 1, 1, deficitAlpha)
end

local function UpdateStatusIcons(health, unit)
    ns.UpdateDeathIcons(health, unit)
    UpdateFlags(health.__owner, nil, unit)
    UpdateNameOrDeficit(health.__owner, unit)
end

-- oUF sets Blizzard's texture for leader and ready check every time: switch back to ours
local function UpdateLeaderIcon(icon, isLeader)
    if isLeader then icon:SetTexture(ns.MEDIA .. "Icons\\Leader") end
end

local READY_ICONS = { ready = "Check", notready = "Close", waiting = "ReadyPending" }
-- On READY_CHECK_FINISHED Forever returns no status for anyone, so oUF calls us with nil. Keep the
-- last status until fade-out; anyone still waiting counts as "not ready" (like Blizzard).
local function UpdateReadyIcon(icon, status)
    if status then
        icon.muiLast = status
    elseif icon:IsShown() and icon.muiLast then
        status = icon.muiLast == "waiting" and "notready" or icon.muiLast
    end
    ns.SetStatusIcon(icon, READY_ICONS[status] or "ReadyPending")
    icon:SetVertexColor(unpack(ns.STYLE.readyColors[status] or ns.STYLE.readyColors.waiting))
end

-- Aggro on group frames (oUF ThreatIndicator, custom display) -----------------------------------
local aggroLog = {}
local AGGRO_COLOR, WARN_COLOR = { 0.85, 0.12, 0.12 }, { 1, 0.6, 0.1 }
function UpdateAggro(self, _, unit)
    if self.muiDemo then return end
    local own = self.unit
    if unit and unit ~= own then return end
    local element = self.ThreatIndicator
    local status = own and UnitThreatSituation(own)
    -- Debug: log status changes to DevLog
    if DevLog and own then
        local shown = issecretvalue and issecretvalue(status) and "secret" or tostring(status)
        if aggroLog[own] ~= shown then
            aggroLog[own] = shown
            DevLog("Aggro", own, UnitName(own), shown, UnitGroupRolesAssigned(own))
        end
    end
    if status == nil or (issecretvalue and issecretvalue(status)) then return element:Hide() end
    local isTank = UnitGroupRolesAssigned(own) == "TANK"
    local color
    if status >= 2 and not isTank then color = AGGRO_COLOR elseif status == 1 and not isTank then color = WARN_COLOR end
    if not color then return element:Hide() end
    for _, edge in ipairs(element.edges) do edge:SetVertexColor(color[1], color[2], color[3], 1) end
    element:Show()
end

-- Own polling instead of relying on the oUF event: on Forever UNIT_THREAT_SITUATION_UPDATE never
-- reached the group frames. Every 0.3 s in combat, then once more to clean up. Read-only.
do
    local wasInCombat = false
    C_Timer.NewTicker(0.3, function()
        local combat = UnitAffectingCombat("player")
        if issecretvalue and issecretvalue(combat) then combat = false end
        local inCombat = combat or InCombatLockdown()
        if not inCombat and not wasInCombat then return end
        wasInCombat = inCombat and true or false
        for frame in pairs(missingFrames or {}) do
            if frame.unit and frame.ThreatIndicator and frame:IsVisible() then UpdateAggro(frame) end
        end
    end)
end

-- Missing class buffs --------------------------------------------------------------------------
-- One list per class: if the member has ANY of them (all ranks, group version), nothing is missing.
-- Only if you know the spell. Auras may be secret in combat: keep the last state, recheck out of combat.
local CLASS_BUFFS = {
    MAGE = { 1459, 23028 },                          -- Arcane Intellect, Arcane Brilliance
    PRIEST = { 1243, 21562 },                        -- Power Word: Fortitude, Prayer of Fortitude
    DRUID = { 1126, 21849 },                         -- Mark of the Wild, Gift of the Wild
    PALADIN = { 19740, 19742, 20217, 1038, 19977, 20911, -- any blessing (incl. greater)
        25782, 25894, 25898, 25895, 25890, 25899 },
}
missingFrames = {}
local buffNames, buffIcon

local function PrepareBuffs()
    local _, class = UnitClass("player")
    local list = CLASS_BUFFS[class]
    buffNames, buffIcon = nil, nil
    if not (list and C_SpellBook.IsSpellKnownOrInSpellBook(list[1])) then return end
    buffNames = {}
    for _, id in ipairs(list) do
        local name = C_Spell.GetSpellName(id)
        if name then buffNames[#buffNames + 1] = name end
    end
    buffIcon = C_Spell.GetSpellTexture(list[1])
end

function UpdateMissingBuff(self, _, unit)
    if self.muiDemo then return end
    local own = self.unit
    if unit and unit ~= own then return end
    local icon = self.MissingBuff
    if InCombatLockdown() then return end -- auras may be secret: keep the last state
    if not (buffNames and own and UnitExists(own)) or UnitIsDeadOrGhost(own) or not UnitIsConnected(own) then
        return icon:Hide()
    end
    for _, name in ipairs(buffNames) do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, own, name, "HELPFUL")
        if not ok or (issecretvalue and issecretvalue(aura)) then return end
        if aura then return icon:Hide() end
    end
    icon:SetTexture(buffIcon)
    icon:Show()
end

local function RefreshMissingBuffs()
    PrepareBuffs()
    for frame in pairs(missingFrames) do UpdateMissingBuff(frame) end
end
ns:On("PLAYER_LOGIN", RefreshMissingBuffs)
ns:On("SPELLS_CHANGED", RefreshMissingBuffs)
ns:On("GROUP_ROSTER_UPDATE", RefreshMissingBuffs)
ns:On("PLAYER_REGEN_ENABLED", RefreshMissingBuffs)

local function Style(self, unit)
    ns.SnapBarsOnUnitChange(self)
    local px = ns.PixelSize()
    -- RegisterForClicks is blocked in combat - if a header creates a new button in combat (someone
    -- joins), defer it until after combat (left click only until then)
    if InCombatLockdown() then
        ns.AfterCombat(function() self:RegisterForClicks("AnyUp") end)
    else
        self:RegisterForClicks("AnyUp")
    end
    -- Header buttons carry their unit as an attribute (Blizzard's UnitFrame_OnEnter expects
    -- self.unit and errors otherwise) - so show the tooltip ourselves at the default anchor
    self:SetScript("OnEnter", function(frame)
        local target = frame.unit or frame:GetAttribute("unit")
        if not (target and UnitExists(target)) then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, frame)
        GameTooltip:SetUnit(target)
    end)
    self:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.CreateBackground(self)

    -- Size of the own header (group or raid), see Spawn
    local header = self:GetParent()
    local width, height = header and header.muiWidth, header and header.muiHeight
    if not width then width, height = Size(header and header.muiKind or "group") end
    local health = ns.CreateBar(self, height)
    health:SetAllPoints()
    health.isHealth = true
    health.colorDisconnected = true
    health.colorClass = ns.STYLE.classHealth
    health.colorHealth = true
    self.Health = health

    -- Shield (light blue, from the bar end over health); heal prediction only in the healer layout
    local healPrediction = ns.LayoutFlag("healPrediction")
    ns.AddHealPrediction(health, false, not healPrediction, healPrediction)

    local power = ns.CreateBar(self, ns.Snap(POWER_HEIGHT))
    power:SetPoint("BOTTOMLEFT", px, px)
    power:SetPoint("BOTTOMRIGHT", -px, px)
    power:SetFrameLevel(health:GetFrameLevel() + 2)
    power.colorPower = true
    power.PostUpdate = PowerVisibility
    self.Power = power

    local overlay = CreateFrame("Frame", nil, self)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(health:GetFrameLevel() + 5)

    -- Target: bright 2 px inner border (accent); mouseover: slight highlight
    local target = CreateFrame("Frame", nil, overlay)
    target:SetAllPoints()
    for _, edge in ipairs(ns.AddBorder(target, true, 2)) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    target:Hide()
    self.TargetIndicator = target
    ns.AddHoverHighlight(self, overlay, 0.08)

    -- Aggro: red border when a mob attacks this member, orange just before. Not on tanks.
    local aggro = CreateFrame("Frame", nil, overlay)
    aggro:SetAllPoints()
    aggro:SetFrameLevel(target:GetFrameLevel() + 1)
    aggro.edges = ns.AddBorder(aggro, true, 2)
    aggro:Hide()
    aggro.Override = UpdateAggro
    self.ThreatIndicator = aggro

    -- Missing class buff (Arcane Intellect, Fortitude, ...): small icon top left next to the crown
    local missing = overlay:CreateTexture(nil, "OVERLAY")
    missing:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    missing:SetPoint("TOPLEFT", LEADER_SIZE + 4, -3)
    missing:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    missing:Hide()
    self.MissingBuff = missing
    self:RegisterEvent("UNIT_AURA", UpdateMissingBuff)
    missingFrames[self] = true

    local name = ns.CreateText(overlay, 12, "CENTER", "OUTLINE")
    self.muiName = name
    name:SetPoint("CENTER", 0, 2)
    name:SetWidth(width - ns.Snap(8))
    name:SetWordWrap(false)
    self:Tag(name, "[mui:name]") -- name format per setting (UnitFrames.lua)

    -- Status icons centered below the name (visible ones close ranks)
    local STYLE = ns.STYLE
    local statusAnchor = CreateFrame("Frame", nil, overlay)
    statusAnchor:SetSize(1, STATUS_ICON)
    statusAnchor:SetPoint("TOP", name, "BOTTOM", 0, -1)
    local row = ns.CreateStatusRow(statusAnchor, STATUS_ICON, 3)
    local function Status(icon, color) return row.Add(ns.CreateStatusIcon(overlay, icon, STATUS_ICON, color)) end
    self.DeadIcon = Status("Dead", STYLE.deadColor)
    self.GhostIcon = Status("Ghost", STYLE.ghostColor)
    self.OfflineIcon = Status("Offline", STYLE.offlineColor)
    self.AfkIcon = Status("Resting", STYLE.afkColor)
    self.ResurrectIndicator = Status("Resurrect", STYLE.resurrectColor)
    local summon = Status("Summon", STYLE.summonColors[1])
    summon.PostUpdate = ns.UpdateSummonIcon
    self.SummonIndicator = summon
    self.PhaseIndicator = Status("Phase", STYLE.phaseColor)
    local ready = Status("ReadyPending", STYLE.readyColors.waiting)
    ready.PostUpdate = UpdateReadyIcon
    ready.PostUpdateFadeOut = function(icon) icon.muiLast = nil end
    self.ReadyCheckIndicator = ready
    health.PostUpdate = UpdateStatusIcons
    self:RegisterEvent("UNIT_FLAGS", UpdateFlags)
    self:RegisterEvent("PLAYER_FLAGS_CHANGED", UpdateFlags)

    local role = overlay:CreateTexture(nil, "OVERLAY") ---@type table
    role:SetSize(ICON_SIZE, ICON_SIZE)
    role:SetPoint("TOPRIGHT", -3, -3)
    role:SetVertexColor(unpack(ns.UI.TEXT))
    role.Override = UpdateRole
    self.GroupRoleIndicator = role

    -- Leader (crown) or assistant (crown outline) top left - never both
    local leader = ns.CreateStatusIcon(overlay, "Leader", LEADER_SIZE, STYLE.leaderColor)
    leader:SetPoint("TOPLEFT", 2, -2)
    leader.PostUpdate = UpdateLeaderIcon
    self.LeaderIndicator = leader
    local assistant = ns.CreateStatusIcon(overlay, "Assistant", LEADER_SIZE, STYLE.assistantColor)
    assistant:SetPoint("TOPLEFT", 2, -2)
    self.AssistantIndicator = assistant

    local marker = overlay:CreateTexture(nil, "OVERLAY")
    marker:SetSize(16, 16)
    marker:SetPoint("CENTER", self, "TOP", 0, 0)
    self.RaidTargetIndicator = marker

    -- Bottom left: dispellable debuffs (RAID = only what YOU can remove, border in dispel color);
    -- boss/role debuffs large over the name (dispellable or not); bottom right: private auras.
    -- Side space depends on the width (raid frames are narrower).
    local bottom = ns.Snap(POWER_HEIGHT) + 3
    -- Boss debuff at most half the frame height (flat raid frames: smaller), max BOSS_SIZE
    local bossSize = math.min(BOSS_SIZE, ns.Snap(math.floor(height * 0.5)))
    self.muiBossSize = bossSize
    local bossWidth = BOSS_MAX * (bossSize + 2)
    local sideMax = math.max(1, math.min(DEBUFF_MAX, math.floor((width - bossWidth - 12) / 2 / (DEBUFF_SIZE + 2))))

    local debuffs = self:CreateAuras({ initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP" })
    debuffs:SetPoint("BOTTOMLEFT", 3, bottom)
    debuffs:SetSize(sideMax * (DEBUFF_SIZE + 2), DEBUFF_SIZE)
    debuffs.size = DEBUFF_SIZE
    debuffs.elementSpacing = 2 * px
    debuffs.showCount = true
    debuffs.disableMouse = true
    debuffs.PostCreateButton = ns.StyleAuraButton
    debuffs:AddGroup("HARMFUL|RAID", { maxFrameCount = sideMax, dispelBand = "harmful",
        candidateFilters = { isBossOrRoleAura = false } })

    -- Boss/role debuffs large in the exact center, one level above the name (may cover it),
    -- border in dispel color
    local boss = self:CreateAuras({ initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP" })
    boss:SetPoint("CENTER", self, "CENTER", 0, 0)
    boss:SetFrameLevel(overlay:GetFrameLevel() + 3)
    boss:SetSize(bossWidth, bossSize)
    boss.size = bossSize
    boss.elementSpacing = 2 * px
    boss.showCount = true
    boss.showDuration = true
    boss.durationFormatter = ns.DurationFormatter
    boss.disableMouse = true
    boss.PostCreateButton = ns.StyleAuraButton
    boss:AddGroup("HARMFUL", { maxFrameCount = BOSS_MAX, dispelBand = "harmful",
        candidateFilters = { isBossOrRoleAura = true } })

    -- Big and external defensives left of the role icon - Retail only: Forever does not know the
    -- BIG_DEFENSIVE/EXTERNAL_DEFENSIVE filters and returns arbitrary buffs (duplicated)
    local defensives
    if not ns.IS_FOREVER then
        defensives = self:CreateAuras({ initialAnchor = "TOPRIGHT", growthX = "LEFT", growthY = "DOWN" })
        defensives:SetPoint("TOPRIGHT", role, "TOPLEFT", -2, 0)
        defensives:SetSize(2 * (ICON_SIZE + 2), ICON_SIZE)
        defensives.size = ICON_SIZE
        defensives.elementSpacing = 2 * px
        defensives.disableMouse = true
        defensives.PostCreateButton = ns.StyleAuraButton
        defensives:AddGroup("HELPFUL|BIG_DEFENSIVE", { maxFrameCount = 1 })
        defensives:AddGroup("HELPFUL|EXTERNAL_DEFENSIVE", { maxFrameCount = 1 })
    end

    -- Private auras (drawn by Blizzard) bottom right
    local private = CreateFrame("Frame", nil, overlay)
    private:SetPoint("BOTTOMRIGHT", -3, bottom)
    private:SetSize(math.min(sideMax, 2) * (DEBUFF_SIZE + 2), DEBUFF_SIZE)
    private.size = DEBUFF_SIZE
    private.spacing = 2
    private.num = math.min(sideMax, 2)
    private.growthX = "LEFT"
    private.initialAnchor = "BOTTOMRIGHT"
    private.disableCooldownText = true
    self.PrivateAuras = private
    self.muiAuraFrames = { debuffs, boss, defensives } -- for the preview (sample group); defensives is nil on Forever

    if ns.LayoutFlag("healerGroups") then
        -- Healer: own HoTs as small icons with remaining time, bottom center, in fixed order
        -- (Renew/Rejuvenation, Regrowth, Power Word: Shield). Addons may filter helpful auras on
        -- group members by spell ID, even in combat. Plus "Weakened Soul" as a test (priest's own
        -- debuff, filter HARMFUL|PLAYER).
        local hots = self:CreateAuras({ initialAnchor = "BOTTOMLEFT", growthX = "RIGHT", growthY = "UP" })
        hots:SetPoint("BOTTOM", 0, bottom)
        hots:SetSize(4 * (HOT_SIZE + 2), HOT_SIZE)
        hots:SetFrameLevel(overlay:GetFrameLevel() + 1)
        hots.size = HOT_SIZE
        hots.elementSpacing = 2 * px
        hots.showDuration = true
        hots.durationFormatter = ns.DurationFormatter
        hots.disableMouse = true
        hots.PostCreateButton = ns.StyleAuraButton
        for _, ids in ipairs(HEALER_HOTS) do
            local set = {}
            for _, id in ipairs(ids) do set[id] = true end
            hots:AddSlot("HELPFUL|PLAYER", { candidateFilters = { includeSpellIDs = set } })
        end
        hots:AddSlot("HARMFUL|PLAYER", { desaturate = true }) -- Weakened Soul (test)
        self.muiAuraFrames[#self.muiAuraFrames + 1] = hots

        -- Missing health instead of the name (Classic healers pick spell ranks by it); the minus is
        -- a separate text to the left (never concatenate a secret number with text)
        local deficit = ns.CreateText(overlay, 12, "CENTER", "OUTLINE")
        deficit:SetPoint("CENTER", name, "CENTER", ns.Snap(2), 0)
        deficit:SetTextColor(1, 1, 1, 0)
        self:Tag(deficit, "[mui:deficit]")
        local minus = ns.CreateText(overlay, 12, "RIGHT", "OUTLINE")
        minus:SetPoint("RIGHT", deficit, "LEFT", ns.Snap(2), 0) -- compensate the minus glyph padding
        minus:SetText("-")
        minus:SetTextColor(1, 1, 1, 0)
        deficit.minus = minus
        self.muiDeficit = deficit
    end

    -- Healer: if you can dispel a debuff, the whole frame gets a 2 px border in the dispel color.
    -- Trick: an aura button the size of the frame with a hidden icon - Blizzard colors its border
    -- itself (works with secret values in combat). HARMFUL|RAID = only what YOU can remove.
    if ns.LayoutFlag("healerGroups") then
        local dispel = self:CreateAuras({ initialAnchor = "TOPLEFT", growthX = "RIGHT", growthY = "DOWN" })
        dispel:SetPoint("TOPLEFT")
        dispel:SetSize(width, height)
        dispel:SetFrameLevel(overlay:GetFrameLevel() + 2)
        dispel.width, dispel.height = width, height
        dispel.disableMouse = true
        dispel.disableCooldown = true
        dispel.PostCreateButton = function(element, button, options)
            ns.StyleAuraButton(element, button, options)
            button.Icon:SetAlpha(0)
        end
        dispel:AddGroup("HARMFUL|RAID", { maxFrameCount = 1, dispelBand = "harmful" })
        self.muiAuraFrames[#self.muiAuraFrames + 1] = dispel
        self.muiDispelFrame = dispel
    end

    self.Range = { insideAlpha = 1, outsideAlpha = 0.4 }
end

-- Hide Blizzard's raid frames (oUF handles party frames itself)
local function HideBlizzardRaid()
    local container = _G["CompactRaidFrameContainer"]
    if container then
        container:UnregisterAllEvents()
        container:Hide()
        container:SetParent(hidden)
    end
end

-- Missing health (healer): empty at full health, dead or offline; pass values through (secrets)
oUF.Tags.Methods["mui:deficit"] = [[function(u)
    local dead, online = UnitIsDeadOrGhost(u), UnitIsConnected(u)
    if (not issecretvalue(dead) and dead) or (not issecretvalue(online) and not online) then return end
    return C_StringUtil.TruncateWhenZero(UnitHealthMissing(u))
end]]
oUF.Tags.Events["mui:deficit"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

oUF:RegisterStyle("MeredanGroup", Style)

-- Raid width: leave room on the right for the boss timers (left of the player frame), otherwise
-- the frames get narrower. columns = groups side by side.
local function FitWidth(width, columns)
    local edge = ns.LeftOfPlayerEdge()
    if not edge then return width end
    -- Reserve boss timer space only if they exist (Forever: no boss data from Blizzard)
    local reserve = (ns.IS_FOREVER or ns.db.bossMods == false) and 0 or ns.Snap(BOSS_BAR_RESERVE)
    local available = edge - reserve - ns.Snap(ns.SCREEN_MARGIN) - (columns - 1) * ns.Snap(GAP)
    return math.max(math.min(width, ns.Snap(math.floor(available / columns))), ns.Snap(40))
end

-- Spawns a group or raid header plus an anchor frame (size of a full 5-man column).
-- growLeft: first group at the anchor, more columns to the left (group next to the player frame);
-- otherwise to the right, fitted to the free width (raid).
-- rows: healer layout - members side by side, one row per group (fixed w, h)
local function SpawnGroup(factory, kind, name, visibility, columns, growLeft, rows, ...)
    local w, h = Size(kind)
    if rows then w, h = rows.w, rows.h end
    if columns > 1 and not growLeft and not rows then w = FitWidth(w, columns) end
    local gap = ns.Snap(GAP)
    local layout = rows
        and { "point", "LEFT", "xOffset", gap, "columnAnchorPoint", "TOP", "columnSpacing", gap }
        or { "point", "TOP", "yOffset", -gap, "columnAnchorPoint", growLeft and "RIGHT" or "LEFT", "columnSpacing", gap }
    local header = factory:SpawnHeader(name, nil,
        "showPlayer", true, "showSolo", false,
        "groupBy", "GROUP", "groupingOrder", "1,2,3,4,5,6,7,8",
        "maxColumns", columns, "unitsPerColumn", rows and rows.per or 5,
        layout[1], layout[2], layout[3], layout[4], layout[5], layout[6], layout[7], layout[8],
        "oUF-initialConfigFunction", ([[ self:SetWidth(%f) self:SetHeight(%f) ]]):format(w, h), ...)
    -- Before visibility: the buttons are only created once the header is shown
    header.muiKind, header.muiWidth, header.muiHeight = kind, w, h
    header.muiVisibility = visibility
    header:SetVisibility(visibility)
    local anchor = CreateFrame("Frame", name .. "Anchor", UIParent)
    if rows then
        anchor:SetSize(rows.per * w + (rows.per - 1) * gap, columns * h + (columns - 1) * gap)
    else
        anchor:SetSize(w, 5 * h + 4 * gap)
    end
    local corner = growLeft and "TOPRIGHT" or "TOPLEFT"
    header:SetPoint(corner, anchor, corner)
    return header, anchor, w
end

oUF:Factory(function(self)
    if not Enabled() then return end
    self:SetActiveStyle("MeredanGroup")

    -- Group: right-aligned with the boss timers left of the player frame (ns.LeftOfPlayerEdge), top
    -- above screen center. Also shows raids up to 15 (3 columns, growing left); from the 16th player
    -- the state driver switches ([@raid16,exists]), even in combat.
    -- Healer layout: fixed when built, so a layout change needs a reload.
    local healer = ns.LayoutFlag("healerGroups")
    local rows, raidRows, raid40Rows
    if healer then
        -- Healer: group between player and target above the cast bar, always in the same box
        -- (4 x 61 high): up to 20: rows of 5 (~107 x 61); 21-25: 5 rows of 5, flatter (~107 x 48);
        -- 26-40: 4 rows of 10 (~51 x 61)
        local H = ns.HEALER
        local width, gap = ns.Snap(H.groupWidth), ns.Snap(GAP)
        local boxHeight = H.rows * ns.Snap(H.frameH) + (H.rows - 1) * gap
        rows = { per = 5, w = ns.Snap((width - 4 * gap) / 5), h = ns.Snap(H.frameH) }
        raidRows = { per = 5, w = rows.w, h = ns.Snap((boxHeight - 4 * gap) / 5) }
        raid40Rows = { per = 10, w = ns.Snap((width - 9 * gap) / 10), h = ns.Snap(H.frameH) }
    end
    -- Setting "show group frames when solo"
    local solo = ns.db.groupSolo == true
    local groupRest = solo and "show" or "[group] show; hide"
    local group, groupAnchor, groupWidth = SpawnGroup(self, "group", "MeredanUIGroup",
        (healer and "custom [@raid21,exists] hide; " or "custom [@raid16,exists] hide; ") .. groupRest,
        healer and 4 or 3, not healer, rows, "showParty", true, "showRaid", true, "showSolo", solo)
    group.muiSolo = solo
    -- Healer: group top = shared top edge with player/target (Core/Layouts.lua)
    local function PlaceHealer(anchor)
        local _, cy = UIParent:GetCenter()
        ns.PlaceFromCenter(anchor, "TOPLEFT", -anchor:GetWidth() / 2, ns.HealerGeometry().groupTop - cy)
    end
    ns.OnLayout(function()
        local cx = UIParent:GetCenter()
        if healer then return PlaceHealer(groupAnchor) end
        local edge = ns.LeftOfPlayerEdge()
        -- (ns.Snap never rounds below 1 px - so round first, then negate)
        local x = edge and (edge - groupWidth - cx) or -ns.Snap(UIParent:GetWidth() / 4)
        ns.PlaceFromCenter(groupAnchor, "TOPLEFT", x, ns.Snap(300))
    end)
    ns.layoutFrames.groupframes = groupAnchor

    -- Raid from 16 players: bottom left above the chat, groups as columns to the right. Up to 25 the
    -- normal raid, from 26 the raid40 header with smaller frames - the state driver switches
    -- ([@raid16,exists], [@raid26,exists]), even in combat.
    local raid, raidAnchor = SpawnGroup(self, "raid", "MeredanUIRaid",
        healer and "custom [@raid26,exists] hide; [@raid21,exists] show; hide" or "custom [@raid26,exists] hide; [@raid16,exists] show; hide",
        5, false, raidRows, "showParty", false, "showRaid", true)
    local raid40, raid40Anchor = SpawnGroup(self, "raid40", "MeredanUIRaid40",
        "custom [@raid26,exists] show; hide", healer and 4 or 8, false, raid40Rows, "showParty", false, "showRaid", true)
    -- Same spot as the raid but bottom-aligned (same gap to the chat; raid40 is shorter). The header
    -- grows top-down: top = bottom + block height.
    if healer then
        ns.OnLayout(function() PlaceHealer(raid40Anchor) end) -- healer: own spot, same box
    else
        raid40:ClearAllPoints()
        raid40:SetPoint("TOPLEFT", raidAnchor, "BOTTOMLEFT", 0, raid40Anchor:GetHeight())
        raid40Anchor:Hide()
    end
    ns.OnLayout(function()
        if healer then return PlaceHealer(raidAnchor) end -- healer: 21-40 in the group's spot
        raidAnchor:ClearAllPoints()
        if ChatFrame1 then
            raidAnchor:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(RAID_CHAT_GAP))
        else
            raidAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ns.Snap(ns.SCREEN_MARGIN), ns.Snap(300))
        end
    end)
    ns.layoutFrames.raidframes = raidAnchor

    self:SetActiveStyle("Meredan")
    ns.groupHeaders = { group = group, raid = raid, raid40 = raid40 }
    HideBlizzardRaid()
end)

-- Demos (Settings > Group Frames), one at a time: the header shows the size even when solo and
-- fills gaps with you as placeholder (real members stay). /mui t includes the group. Out of combat
-- only (protected frames); entering combat ends the demo.
-- group10 = 10-man (Barrow Deeps, Warsong Gulch) - runs on the group frames
local TEST_COUNT = { group = 5, group10 = 10, group15 = 15, group20 = 20, raid = 25, raid40 = 40 }
-- Which header shows the size? Healer: group up to 20, above that the raid (rows of 10)
local function TestHeader(kind)
    local healer = ns.LayoutFlag("healerGroups")
    if kind == "group" or kind == "group10" or kind == "group15" then return "group" end
    if kind == "group20" then return healer and "group" or "raid" end
    if kind == "raid40" then return "raid40" end
    if kind == "raid" then return "raid" end
end

local function Buttons(header)
    local list = {}
    for _, child in ipairs({ header:GetChildren() }) do
        if child:IsObjectType("Button") then list[#list + 1] = child end
    end
    return list
end

-- Sample group for the preview: tank, healer, three DPS in class colors; states change every 4 s
-- (3 phases) to show aggro, debuffs, missing buff, shield, death, offline, ready check and target.
-- Only placeholder frames (unit = player) are filled; their oUF elements are disabled meanwhile.
local DEMO_PHASES = 3
local DEMO_SECONDS = 4
local DEMO_ELEMENTS = { "Health", "Power", "GroupRoleIndicator", "ThreatIndicator", "LeaderIndicator",
    "AssistantIndicator", "ReadyCheckIndicator", "Range", "TargetIndicator", "ResurrectIndicator",
    "SummonIndicator", "PhaseIndicator", "PrivateAuras", "RaidTargetIndicator" }
local MAGIC, CURSE, POISON = 136071, 136139, 136007   -- sample icons (as in the unit frame test)
local BOSS_ICON = 136113
local DEMO_GROUP = {
    { name = "Brakk", class = "WARRIOR", role = "TANK", hp = { 92, 70, 85 }, absorb = { 0, 25, 10 },
        target = { false, false, true } },
    { name = "Lunara", class = "PRIEST", role = "HEALER", hp = { 100, 64, 100 }, mana = { 80, 55, 30 },
        aggro = { "red", "orange", nil } },
    { name = "Felyra", class = "MAGE", hp = { 100, 90, 100 }, missing = { false, true, false },
        debuff = { { MAGIC, "Magic" }, nil, { CURSE, "Curse" } } },
    { name = "Kesh", class = "ROGUE", hp = { 75, 28, 60 }, boss = { { BOSS_ICON, "Magic" }, nil, { BOSS_ICON, "Disease" } },
        debuff = { nil, { POISON, "Poison" }, nil } },
    { name = "Thalor", class = "HUNTER", hp = { 100, 0, 100 }, leader = true, dead = { false, true, false },
        offline = { false, false, true }, ready = { "waiting", nil, "ready" } },
}
local demoPhase, demoTicker = 1, nil

local function DemoAura(button, container, size, thick)
    local aura = CreateFrame("Button", nil, button.muiDemoLayer)
    aura:EnableMouse(false)
    aura:SetSize(size, size)
    aura.Icon = aura:CreateTexture(nil, "BORDER")
    aura.Icon:SetAllPoints()
    aura.Time = aura:CreateFontString(nil, "OVERLAY")
    aura.Count = aura:CreateFontString(nil, "OVERLAY")
    ns.StyleAuraButton(container, aura, thick and { dispelBand = "preview" } or {})
    return aura
end

local function SetAura(aura, data, colors)
    if not data then return aura:Hide() end
    local icon, dispel = data, nil
    if type(data) == "table" then icon, dispel = data[1], data[2] end
    aura.Icon:SetTexture(icon)
    local color = dispel and colors and colors.dispel and colors.dispel[dispel]
    for _, edge in ipairs(aura.FrameBorder) do
        if color then edge:SetVertexColor(color:GetRGB()) else edge:SetVertexColor(0, 0, 0, 1) end
    end
    aura:Show()
end

local function ApplyDemo(button, data, phase)
    if not button.muiDemo then
        button.muiDemo = true
        for _, element in ipairs(DEMO_ELEMENTS) do
            if button[element] then button:DisableElement(element) end
        end
        if button.muiName then button:Untag(button.muiName) end
        if button.muiDeficit then button:Untag(button.muiDeficit) end
        for _, frame in ipairs(button.muiAuraFrames or {}) do frame:Hide() end
        if not button.muiDemoLayer then
            local layer = CreateFrame("Frame", nil, button)
            layer:SetAllPoints()
            layer:SetFrameLevel(button:GetFrameLevel() + 8)
            button.muiDemoLayer = layer
            local frames = button.muiAuraFrames or {}
            local bottom = ns.Snap(POWER_HEIGHT) + 3
            button.muiDemoDebuff = DemoAura(button, frames[1], DEBUFF_SIZE)
            button.muiDemoDebuff:SetPoint("BOTTOMLEFT", 3, bottom)
            button.muiDemoBoss = DemoAura(button, frames[2], button.muiBossSize or BOSS_SIZE, true)
            button.muiDemoBoss:SetPoint("CENTER", button, "CENTER", 0, 0)
            -- Healer: dispel-colored border around the whole frame
            local dispelBorder = CreateFrame("Frame", nil, layer)
            dispelBorder:SetAllPoints(button)
            dispelBorder.edges = ns.AddBorder(dispelBorder, true, 2)
            dispelBorder:Hide()
            button.muiDemoDispel = dispelBorder
        end
        button.muiDemoLayer:Show()
    end
    local class = RAID_CLASS_COLORS[data.class]
    if button.muiName then button.muiName:SetText(data.name) end
    if button.muiDeficit then
        local hp = data.hp[phase] or 100
        local dead = data.dead and data.dead[phase]
        local missing = hp < 100 and not dead
        button.muiDeficit:SetText(missing and tostring((100 - hp) * 52) or "")
        local a = missing and 1 or 0
        button.muiDeficit:SetTextColor(1, 1, 1, a)
        button.muiDeficit.minus:SetTextColor(1, 1, 1, a)
        local r, g, b = button.muiName:GetTextColor()
        button.muiName:SetTextColor(r, g, b, 1 - a)
    end
    -- Health in class color (or theme color), shield
    local health = button.Health
    local hp = data.hp[phase] or 100
    health:Show() -- oUF hides the bar when the element is disabled
    health:SetMinMaxValues(0, 100)
    health:SetValue(hp)
    if ns.STYLE.classHealth and class then
        health:SetStatusBarColor(class.r, class.g, class.b)
    else
        health:SetStatusBarColor(unpack(ns.HEALTH_COLOR))
    end
    ns.ColorBarBackground(health)
    if health.DamageAbsorb then
        local absorb = data.absorb and data.absorb[phase] or 0
        health.DamageAbsorb:SetMinMaxValues(0, 100)
        health.DamageAbsorb:SetValue(absorb)
        health.DamageAbsorb:SetShown(absorb > 0)
    end
    -- Mana for the healer only
    local mana = data.mana and data.mana[phase]
    if button.Power then
        button.Power:SetShown(mana ~= nil)
        if mana then
            local color = button.colors and button.colors.power and button.colors.power.MANA
            button.Power:SetMinMaxValues(0, 100)
            button.Power:SetValue(mana)
            if color then button.Power:SetStatusBarColor(color:GetRGB()) end
        end
    end
    -- Role, leader, target, aggro
    local role = button.GroupRoleIndicator
    if ROLE_ICONS[data.role or ""] then
        role:SetTexture(ns.MEDIA .. "Icons\\" .. ROLE_ICONS[data.role])
        role:Show()
    else
        role:Hide()
    end
    if button.LeaderIndicator then
        UpdateLeaderIcon(button.LeaderIndicator, true)
        button.LeaderIndicator:SetShown(data.leader == true)
    end
    if button.AssistantIndicator then button.AssistantIndicator:Hide() end
    if button.TargetIndicator then button.TargetIndicator:SetShown(data.target and data.target[phase] or false) end
    local aggro = data.aggro and data.aggro[phase]
    local threat = button.ThreatIndicator
    if threat then
        local color = aggro == "red" and AGGRO_COLOR or aggro == "orange" and WARN_COLOR
        if color then
            for _, edge in ipairs(threat.edges) do edge:SetVertexColor(color[1], color[2], color[3], 1) end
        end
        threat:SetShown(color and true or false)
    end
    -- Missing buff (example: Arcane Intellect)
    local missing = data.missing and data.missing[phase]
    if missing then button.MissingBuff:SetTexture(C_Spell.GetSpellTexture(1459) or 135932) end
    button.MissingBuff:SetShown(missing or false)
    -- Status below the name
    if button.DeadIcon then button.DeadIcon:SetShown(data.dead and data.dead[phase] or false) end
    if button.GhostIcon then button.GhostIcon:Hide() end
    if button.OfflineIcon then button.OfflineIcon:SetShown(data.offline and data.offline[phase] or false) end
    if button.AfkIcon then button.AfkIcon:Hide() end
    for _, key in ipairs({ "ResurrectIndicator", "SummonIndicator", "PhaseIndicator" }) do
        if button[key] then button[key]:Hide() end
    end
    local ready = data.ready and data.ready[phase]
    if button.ReadyCheckIndicator then
        if ready then UpdateReadyIcon(button.ReadyCheckIndicator, ready) end
        button.ReadyCheckIndicator:SetShown(ready ~= nil)
    end
    button:SetAlpha((data.offline and data.offline[phase]) and 0.4 or 1)
    -- Debuffs: dispellable (dispel-colored border) bottom left, boss debuff large in the center
    SetAura(button.muiDemoDebuff, data.debuff and data.debuff[phase], button.colors)
    local debuff = data.debuff and data.debuff[phase]
    local dispelColor = button.muiDispelFrame and type(debuff) == "table" and button.colors.dispel and button.colors.dispel[debuff[2]]
    if dispelColor then
        for _, edge in ipairs(button.muiDemoDispel.edges) do edge:SetVertexColor(dispelColor:GetRGB()) end
    end
    button.muiDemoDispel:SetShown(dispelColor and true or false)
    SetAura(button.muiDemoBoss, data.boss and data.boss[phase], button.colors)
end

local function RestoreDemo(button)
    if not button.muiDemo then return end
    button.muiDemo = nil
    if button.muiDemoLayer then button.muiDemoLayer:Hide() end
    for _, frame in ipairs(button.muiAuraFrames or {}) do frame:Show() end
    for _, element in ipairs(DEMO_ELEMENTS) do
        if button[element] then button:EnableElement(element) end
    end
    if button.muiName then button:Tag(button.muiName, "[mui:name]") end
    if button.muiDeficit then button:Tag(button.muiDeficit, "[mui:deficit]") end
    if button.ThreatIndicator then button.ThreatIndicator:Hide() end
    button.MissingBuff:Hide()
    button:SetAlpha(1)
    if not button.muiTestFill and button.UpdateAllElements then button:UpdateAllElements("MeredanGroupTestEnd") end
end

local function DemoButtons(header)
    local list = {}
    local solo = not IsInGroup()
    for _, button in ipairs(Buttons(header)) do
        if button.muiTestFill or (solo and button:IsShown() and button:GetAttribute("unit")) then
            list[#list + 1] = button
        end
    end
    return list
end

local function UpdateDemo(header)
    for i, button in ipairs(DemoButtons(header)) do
        ApplyDemo(button, DEMO_GROUP[(i - 1) % #DEMO_GROUP + 1], demoPhase)
    end
end

local function StartHeader(header, kind)
    header:SetVisibility("custom show")
    header:SetAttribute("showSolo", true)
    header:SetAttribute("showParty", true)
    local fill = math.max(TEST_COUNT[kind] - math.max(GetNumGroupMembers(), 1), 0)
    header:SetAttribute("startingIndex", 1 - fill)
    C_Timer.After(0, function()
        if testing ~= kind then return end
        for _, button in ipairs(Buttons(header)) do
            if not button:GetAttribute("unit") then -- placeholders only, real members stay
                UnregisterUnitWatch(button)
                button:SetAttribute("unit", "player")
                button.muiTestFill = true
                RegisterUnitWatch(button, true)
                button:Show()
                if button.UpdateAllElements then button:UpdateAllElements("MeredanGroupTest") end
            end
        end
        -- Sample group with changing states
        demoPhase = 1
        UpdateDemo(header)
        if demoTicker then demoTicker:Cancel() end
        demoTicker = C_Timer.NewTicker(DEMO_SECONDS, function()
            if testing ~= kind then return end
            demoPhase = demoPhase % DEMO_PHASES + 1
            UpdateDemo(header)
        end)
    end)
end

local function StopHeader(header)
    if demoTicker then demoTicker:Cancel(); demoTicker = nil end
    for _, button in ipairs(Buttons(header)) do
        RestoreDemo(button) -- also the own frame (when solo)
        if button.muiTestFill then
            button.muiTestFill = nil
            UnregisterUnitWatch(button)
            button:SetAttribute("unit", nil)
            RegisterUnitWatch(button)
        end
    end
    header:SetAttribute("startingIndex", 1)
    header:SetAttribute("showSolo", header.muiSolo or false)
    header:SetAttribute("showParty", header.muiKind == "group")
    header:SetVisibility(header.muiVisibility)
end

function ns.GroupDemoStop()
    local headers = ns.groupHeaders
    if not headers or not testing or InCombatLockdown() then return end
    local header = headers[TestHeader(testing)]
    testing = false
    if header then StopHeader(header) end
end

-- kind: "group", "raid" or "raid40"
function ns.GroupDemo(kind)
    local headers = ns.groupHeaders
    if not headers or not TestHeader(kind) or not headers[TestHeader(kind)] then return end
    if InCombatLockdown() then
        ns.Print(ns.L["Not possible in combat."])
        return
    end
    ns.GroupDemoStop()
    testing = kind
    StartHeader(headers[TestHeader(kind)], kind)
end

-- /mui t (unit frame test): the group shows too
function ns.GroupTestStart() if not testing then ns.GroupDemo("group") end end
function ns.GroupTestStop() if testing == "group" then ns.GroupDemoStop() end end

ns:On("PLAYER_REGEN_DISABLED", function() ns.GroupDemoStop() end)
