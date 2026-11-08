-- Gruppenframes (Gruppe + Schlachtzug) im Grid-Stil, erste Version für DD/Tank. oUF-Header:
-- jede 5er-Gruppe eine Spalte, du selbst mit dabei; links mittig.
-- Blizzards Gruppen- und Schlachtzugsframes werden ausgeblendet.
--
--   ┌────────────────────┐
--   │♛     ✦       [◆][T]│  ← Leiter/Assistent · Zielmarker · Defensive (groß/extern) · Rolle
--   │       Name         │  ← Name mittig; darunter MUI-Status-Symbole (sichtbare rücken zusammen):
--   │ [☠][!]  [BOSS]  [▣]│    Tot, Geist, Offline, AFK, Wiederbelebung, Beschwörung, Phase, Bereitschaft
--   │▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬│  ← unten: dispellbare Debuffs (Rahmen in Dispel-Farbe, nur was DU
--   └────────────────────┘    entfernen kannst) · Boss-/Rollen-Debuffs groß mittig über dem Namen · private Auren
--                              Mana-Leiste nur bei Heilern (hat der Heiler noch Mana?)
-- Lebensbalken: Schild (hellblau) vom Ende her (keine Heil-Vorhersage – kommt mit dem Heiler) – die Werte
-- sind im Kampf Secrets und gehen nur durch oUF in StatusBar:SetValue. Dein Ziel bekommt einen
-- hellen Rahmen, unter der Maus schimmert der Frame leicht.
-- Gruppe und Schlachtzug sind getrennt: eigene Plätze, eigene Größen. Die Gruppe sitzt links
-- neben dem Spieler-Frame (bündig mit den Boss-Timern) und zeigt auch kleine Schlachtzüge bis
-- 15 Spieler (weitere Gruppen als Spalten nach links); ab 16 Spielern der Schlachtzug unten links
-- über dem Chat (Benny, 2026-10-25).
-- Testmodus (/mui t bzw. Demo der Unitframes): 5 Gruppen- und 40 Raid-Frames mit dir als Platzhalter.
-- Leben in Klassenfarbe (Theme), außer Reichweite blasser. Midnight: Auren und Leben sind im
-- Kampf geschützt – oUF und Blizzards Filter (HARMFUL|RAID, BIG/EXTERNAL_DEFENSIVE) erledigen das.
-- Heiler-Variante (HoTs, Dispel groß, Mana) kommt später.
local _, ns = ...
local oUF = ns.oUF
local UpdateAggro, UpdateMissingBuff, missingFrames -- unten definiert (Aggro, fehlende Buffs)

-- Feste Größen (keine Regler mehr, Benny 2026-11-07: Frames sitzen fest im Layout; Heiler hat
-- eigene Maße in ns.HEALER). kind = "group", "raid" oder "raid40".
local SIZES = { group = { 130, 62 }, raid = { 96, 44 }, raid40 = { 72, 32 } }
local function Size(kind)
    local size = SIZES[kind] or SIZES.raid
    return ns.Snap(size[1]), ns.Snap(size[2])
end
local GAP = 4               -- zwischen den Frames und den Spalten
local DEBUFF_SIZE, DEBUFF_MAX = 16, 3
local BOSS_SIZE, BOSS_MAX = 30, 2 -- Boss-/Rollen-Debuffs groß mittig ÜBER dem Namen (eigene Ebene), Rahmen in Dispel-Farbe;
-- höchstens 2 – Blizzards Container passt seine Breite an, an der Mitte verankert bleiben 1 oder 2 zentriert
local ICON_SIZE = 12        -- Rolle, Defensiven, Leiter
local STATUS_ICON = 14      -- Status-Symbole unter dem Namen
local HOT_SIZE = 16          -- Heiler: eigene HoTs unten mittig
-- eigene HoTs (alle Ränge, Classic-IDs – im Spiel prüfen): je Gruppe ein fester Platz
local HEALER_HOTS = {
    { 139, 6074, 6075, 6076, 6077, 6078, 10927, 10928, 10929, 25315,              -- Erneuerung
      774, 1058, 1430, 2090, 2091, 3627, 8910, 9839, 9840, 9841, 25299 },         -- Verjüngung
    { 8936, 8938, 8939, 8940, 8941, 9750, 9856, 9857, 9858 },                     -- Nachwachsen
    { 17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901 },               -- Machtwort: Schild
}
local LEADER_SIZE = 13      -- Krone oben links: so groß wie Rollen-Symbole, nicht dominant (Benny 2026-11-07; früher 18, gold bei 12 kaum zu sehen – jetzt weiß)
local POWER_HEIGHT = 4      -- Mana-Leiste der Heiler (unten im Frame)
local BOSS_BAR_RESERVE = 260 -- rechts vom Schlachtzug frei für die Boss-Timer links neben dem Spieler-Frame
local RAID_CHAT_GAP = 90   -- Schlachtzug ↔ Oberkante des Chats (Platz für Eingabefeld und Reiter)
local testing = false       -- laufende Demo ("group"/"raid"/"raid40", unten): Mana auch ohne Heiler
local hidden = CreateFrame("Frame")
hidden:Hide()

local function Enabled() return ns.db.groupFrames ~= false end

-- Rolle mit MUI-Symbolen (Tank/Heiler; DDs ohne)
local ROLE_ICONS = { TANK = "RoleTank", HEALER = "RoleHeal" }
local function IsHealer(self)
    local role = self.unit and UnitGroupRolesAssigned(self.unit)
    return ns.Readable(role) and role == "HEALER"
end

-- Mana nur bei Heilern; oUF zeigt die Leiste sonst immer – nach jeder Aktualisierung entscheiden
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

-- Offline und AFK als Symbole (Secrets > lieber nichts zeigen); Health.PostUpdate und Flag-Events
local function UpdateFlags(self, _, unit)
    unit = self.unit
    if not unit or not self.OfflineIcon then return end
    local connected, afk = UnitIsConnected(unit), UnitIsAFK(unit)
    local offline = ns.Readable(connected) and connected == false
    local away = not offline and ns.Readable(afk) and afk == true
    self.OfflineIcon:SetShown(offline)
    self.AfkIcon:SetShown(away)
end

-- Heiler: fehlt Leben, steht statt des Namens „−123“ (weiß) an derselben Stelle (Benny 2026-11-07).
-- Leben kann geheim sein → nicht vergleichen, sondern über Stufen-Kurven die Textdeckkraft
-- setzen: bei 100 % Name sichtbar, darunter die Zahl. Tot/offline: immer der Name.
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

-- oUF setzt bei Leiter und Bereitschaft jedes Mal Blizzards Grafik: zurück auf unsere Symbole
local function UpdateLeaderIcon(icon, isLeader)
    if isLeader then icon:SetTexture(ns.MEDIA .. "Icons\\Leader") end
end

local READY_ICONS = { ready = "Check", notready = "Close", waiting = "ReadyPending" }
-- Am Ende des Checks (READY_CHECK_FINISHED) liefert Forever für alle keinen Status mehr > oUF ruft uns
-- mit nil auf, das Symbol fiel aufs Fragezeichen zurück (Benny 2026-11-08). Darum: letzten Stand
-- merken und bis zum Ausblenden zeigen; wer noch wartete, gilt als „nicht bereit“ (wie Blizzard).
local function UpdateReadyIcon(icon, status)
    if status then
        icon.muiLast = status
    elseif icon:IsShown() and icon.muiLast then
        status = icon.muiLast == "waiting" and "notready" or icon.muiLast
    end
    ns.SetStatusIcon(icon, READY_ICONS[status] or "ReadyPending")
    icon:SetVertexColor(unpack(ns.STYLE.readyColors[status] or ns.STYLE.readyColors.waiting))
end

-- Aggro am Gruppenframe (oUF ThreatIndicator, eigene Darstellung) -----------------------------
local aggroLog = {}
local AGGRO_COLOR, WARN_COLOR = { 0.85, 0.12, 0.12 }, { 1, 0.6, 0.1 }
function UpdateAggro(self, _, unit)
    if self.muiDemo then return end
    local own = self.unit
    if unit and unit ~= own then return end
    local element = self.ThreatIndicator
    local status = own and UnitThreatSituation(own)
    -- Fehlersuche (Benny 2026-11-08: als DD keine Aggro am Gruppenframe): Status-Wechsel ins DevLog
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

-- Eigene Abfrage statt nur oUF-Ereignis: in Forever kam UNIT_THREAT_SITUATION_UPDATE am Gruppenframe
-- nie an (Benny 2026-11-08: als DD keine Aggro sichtbar, DevLog leer). Alle 0,3 s im Kampf, danach
-- einmal zum Aufräumen. Nur Werte lesen, nichts Geschütztes.
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

-- Fehlende Buffs deiner Klasse -----------------------------------------------------------------
-- Je Klasse eine Liste: hat das Gruppenmitglied IRGENDEINEN davon (alle Ränge, Gruppen-Version),
-- fehlt nichts. Nur wenn du den Zauber kennst. Auren können im Kampf geschützt sein: dann bleibt
-- der letzte Stand stehen (nachgeprüft wird außerhalb des Kampfs).
local CLASS_BUFFS = {
    MAGE = { 1459, 23028 },                          -- Arkane Intelligenz, Arkane Brillanz
    PRIEST = { 1243, 21562 },                        -- Machtwort: Seelenstärke, Gebet der Seelenstärke
    DRUID = { 1126, 21849 },                         -- Mal der Wildnis, Gabe der Wildnis
    PALADIN = { 19740, 19742, 20217, 1038, 19977, 20911, -- irgendein Segen (auch die großen)
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
    if InCombatLockdown() then return end -- Auren evtl. geschützt: letzten Stand behalten
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
    -- Rechtsklick-Menü & Co.: RegisterForClicks ist im Kampf gesperrt – baut Blizzard im Kampf einen
    -- neuen Gruppen-Frame (jemand tritt bei), erst nach dem Kampf nachholen (bis dahin nur Linksklick)
    if InCombatLockdown() then
        ns.AfterCombat(function() self:RegisterForClicks("AnyUp") end)
    else
        self:RegisterForClicks("AnyUp")
    end
    -- Tooltip: Header-Knöpfe tragen ihre Einheit als Attribut (Blizzards UnitFrame_OnEnter sucht
    -- self.unit und wirft sonst einen Fehler) – Tooltip darum selbst an der Standard-Position
    self:SetScript("OnEnter", function(frame)
        local target = frame.unit or frame:GetAttribute("unit")
        if not (target and UnitExists(target)) then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, frame)
        GameTooltip:SetUnit(target)
    end)
    self:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ns.CreateBackground(self)

    -- Größe des eigenen Headers (Gruppe oder Schlachtzug), siehe Spawn
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

    -- Schild (hellblau, vom Balkenende her über dem Leben); Heil-Vorhersage nur im Layout Heiler
    -- (Benny 2026-11-07: DD/Tank brauchen sie nicht)
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

    -- Ziel: heller 2-px-Rahmen (Akzent) innen; Maus darüber: leichter Schimmer
    local target = CreateFrame("Frame", nil, overlay)
    target:SetAllPoints()
    for _, edge in ipairs(ns.AddBorder(target, true, 2)) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    target:Hide()
    self.TargetIndicator = target
    ns.AddHoverHighlight(self, overlay, 0.08)

    -- Aggro: roter Rahmen, wenn ein Mob dieses Gruppenmitglied angreift, orange kurz davor (Benny
    -- 2026-11-07: Tank sieht sofort, wen er zurückholen muss). Beim Tank selbst nicht – dort normal.
    local aggro = CreateFrame("Frame", nil, overlay)
    aggro:SetAllPoints()
    aggro:SetFrameLevel(target:GetFrameLevel() + 1)
    aggro.edges = ns.AddBorder(aggro, true, 2)
    aggro:Hide()
    aggro.Override = UpdateAggro
    self.ThreatIndicator = aggro

    -- fehlender Buff deiner Klasse (Arkane Intelligenz, Seelenstärke …): kleines Symbol oben links
    -- neben der Krone (Benny 2026-11-07)
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
    self:Tag(name, "[mui:name]") -- Vor-/Nachname nach Einstellung (UnitFrames.lua)

    -- Status-Symbole unter dem Namen, mittig (MUI-Symbole, sichtbare rücken zusammen)
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

    -- Leiter (Krone, gold) oder Assistent (Krone, Umriss) oben links – nie beides
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

    -- Unten: links dispellbare Debuffs (RAID = nur was DU entfernen kannst, Rahmen in Dispel-Farbe),
    -- Boss-/Rollen-Debuffs groß über dem Namen (egal ob dispellbar – wer hat den Kram?), rechts private Auren.
    -- Platz links/rechts richtet sich nach der Breite (Schlachtzugsframes sind schmaler).
    local bottom = ns.Snap(POWER_HEIGHT) + 3
    -- Boss-Debuff höchstens halb so hoch wie der Frame (flache Schlachtzugsframes: kleiner), max. BOSS_SIZE
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

    -- Boss-/Rollen-Debuffs groß genau in der Mitte, eine Ebene über dem Namen (der darf verdeckt
    -- sein – Benny 2026-11-07), Rahmen in Dispel-Farbe
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

    -- große und externe Defensiven (wer ist gerade geschützt?) links neben der Rolle – nur Retail:
    -- Forever kennt die Filter BIG_DEFENSIVE/EXTERNAL_DEFENSIVE nicht und lieferte beliebige Buffs,
    -- doppelt (Benny 2026-11-07: fremde Buffs interessieren nicht, nur fehlende eigene)
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

    -- private Auren (Blizzard zeichnet sie selbst) unten rechts
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
    self.muiAuraFrames = { debuffs, boss, defensives } -- für die Vorschau (Beispielgruppe); defensives fehlt in Forever

    if ns.LayoutFlag("healerGroups") then
        -- Heiler (Recherche 2026-11-07): eigene HoTs als kleine Symbole mit Restzeit unten mittig, in
        -- fester Reihenfolge (Erneuerung/Verjüngung, Nachwachsen, Machtwort: Schild). Hilfreiche Auren
        -- auf Gruppenmitgliedern darf ein Addon per Zauber-ID filtern – auch im Kampf. Dazu als Test
        -- „Geschwächte Seele“ (eigener Debuff des Priesters, Filter HARMFUL|PLAYER).
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
        hots:AddSlot("HARMFUL|PLAYER", { desaturate = true }) -- Geschwächte Seele (Test)
        self.muiAuraFrames[#self.muiAuraFrames + 1] = hots

        -- fehlendes Leben statt des Namens (Classic-Heiler wählen danach den Zauber-Rang); das
        -- Minus ist ein eigener Text links daneben (geheime Zahl nicht mit Text verketten)
        local deficit = ns.CreateText(overlay, 12, "CENTER", "OUTLINE")
        deficit:SetPoint("CENTER", name, "CENTER", ns.Snap(2), 0)
        deficit:SetTextColor(1, 1, 1, 0)
        self:Tag(deficit, "[mui:deficit]")
        local minus = ns.CreateText(overlay, 12, "RIGHT", "OUTLINE")
        minus:SetPoint("RIGHT", deficit, "LEFT", ns.Snap(2), 0) -- Glyphen-Rand des Minus ausgleichen
        minus:SetText("-")
        minus:SetTextColor(1, 1, 1, 0)
        deficit.minus = minus
        self.muiDeficit = deficit
    end

    -- Heiler: kannst du einen Debuff entfernen, bekommt der ganze Frame einen 2-px-Rahmen in der
    -- Dispel-Farbe (Magie blau, Fluch lila, Gift grün, Krankheit braun). Trick: ein Aura-Knopf so
    -- groß wie der Frame, Symbol unsichtbar – Blizzard färbt dessen Rahmen selbst (geht auch mit
    -- geschützten Werten im Kampf). Filter HARMFUL|RAID = nur was DU entfernen kannst.
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

-- Blizzards Schlachtzugsframes aus (Gruppenframes übernimmt oUF selbst)
local function HideBlizzardRaid()
    local container = _G["CompactRaidFrameContainer"]
    if container then
        container:UnregisterAllEvents()
        container:Hide()
        container:SetParent(hidden)
    end
end

-- Fehlendes Leben (Heiler): leer bei vollem Leben, tot oder offline; Werte nur durchreichen (Secrets)
oUF.Tags.Methods["mui:deficit"] = [[function(u)
    local dead, online = UnitIsDeadOrGhost(u), UnitIsConnected(u)
    if (not issecretvalue(dead) and dead) or (not issecretvalue(online) and not online) then return end
    return C_StringUtil.TruncateWhenZero(UnitHealthMissing(u))
end]]
oUF.Tags.Events["mui:deficit"] = "UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION"

oUF:RegisterStyle("MeredanGroup", Style)

-- Header für Gruppe (5er) oder Schlachtzug spawnen, mit Platzhalter (Größe einer
-- vollen 5er-Spalte); der Header hängt oben links daran.
-- Schlachtzug: höchstens so breit, dass rechts Platz für die Boss-Timer bleibt (links neben dem
-- Spieler-Frame) – sonst werden die einzelnen Frames schmaler. columns = Gruppen nebeneinander.
local function FitWidth(width, columns)
    local edge = ns.LeftOfPlayerEdge()
    if not edge then return width end
    -- Platz für die Boss-Timer nur, wenn es sie gibt (Forever: keine Boss-Daten von Blizzard)
    local reserve = (ns.IS_FOREVER or ns.db.bossMods == false) and 0 or ns.Snap(BOSS_BAR_RESERVE)
    local available = edge - reserve - ns.Snap(ns.SCREEN_MARGIN) - (columns - 1) * ns.Snap(GAP)
    return math.max(math.min(width, ns.Snap(math.floor(available / columns))), ns.Snap(40))
end

-- growLeft: erste Gruppe am Platzhalter, weitere Spalten nach links (Gruppe neben dem Spieler-Frame);
-- sonst nach rechts und bei mehreren Spalten auf die freie Breite eingepasst (Schlachtzug).
-- rows: Heiler-Gruppe – Mitglieder nebeneinander, jede Gruppe eine Reihe darunter (w, h fest)
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
    -- vor der Sichtbarkeit: die Knöpfe entstehen erst, wenn er sichtbar wird
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

    -- Gruppe: rechtsbündig mit den Boss-Timern links neben dem Spieler-Frame (gemeinsame Kante,
    -- ns.LeftOfPlayerEdge), Oberkante über der Bildschirmmitte. Zeigt auch Schlachtzüge bis 15
    -- Spieler (3 Spalten, weitere Gruppen nach links); ab dem 16. schaltet WoW selbst um
    -- ([@raid16,exists]), auch im Kampf.
    -- Layout Heiler (Benny 2026-11-07, Entwurf „Heiler-Layout“): Gruppe und 10er mittig unter den
    -- Unitframes – 5 nebeneinander, so breit wie die unteren Leisten, zweite Gruppe als zweite Reihe;
    -- ab 11 Spielern der Schlachtzug links (20er/40er passen nicht in die Mitte). Beim Aufbau
    -- festgelegt > Layout-Wechsel braucht Neuladen.
    local healer = ns.LayoutFlag("healerGroups")
    local rows, raidRows, raid40Rows
    if healer then
        -- Heiler (Skizze „Spielwiese Heiler“): Gruppe zwischen Spieler und Ziel über der Zauberleiste,
        -- immer im selben Kasten (4 × 61 hoch):
        --   bis 20: Reihen à 5 (~107 × 61) · 21–25: 5 Reihen à 5, flacher (~107 × 48; Benny: lieber
        --   flacher als schmaler) · 26–40: 4 Reihen à 10 (~51 × 61)
        local H = ns.HEALER
        local width, gap = ns.Snap(H.groupWidth), ns.Snap(GAP)
        local boxHeight = H.rows * ns.Snap(H.frameH) + (H.rows - 1) * gap
        rows = { per = 5, w = ns.Snap((width - 4 * gap) / 5), h = ns.Snap(H.frameH) }
        raidRows = { per = 5, w = rows.w, h = ns.Snap((boxHeight - 4 * gap) / 5) }
        raid40Rows = { per = 10, w = ns.Snap((width - 9 * gap) / 10), h = ns.Snap(H.frameH) }
    end
    -- Einstellung „Gruppenframes auch allein zeigen“ (Benny 2026-11-07, z. B. zum Testen)
    local solo = ns.db.groupSolo == true
    local groupRest = solo and "show" or "[group] show; hide"
    local group, groupAnchor, groupWidth = SpawnGroup(self, "group", "MeredanUIGroup",
        (healer and "custom [@raid21,exists] hide; " or "custom [@raid16,exists] hide; ") .. groupRest,
        healer and 4 or 3, not healer, rows, "showParty", true, "showRaid", true, "showSolo", solo)
    group.muiSolo = solo
    -- Heiler: Oberkante der Gruppe = gemeinsame Oberkante mit Spieler/Ziel (Core/Layouts.lua)
    local function PlaceHealer(anchor)
        local _, cy = UIParent:GetCenter()
        ns.PlaceFromCenter(anchor, "TOPLEFT", -anchor:GetWidth() / 2, ns.HealerGeometry().groupTop - cy)
    end
    ns.OnLayout(function()
        local cx = UIParent:GetCenter()
        if healer then return PlaceHealer(groupAnchor) end
        local edge = ns.LeftOfPlayerEdge()
        -- (ns.Snap rundet nie unter 1 px – darum erst runden, dann negativ)
        local x = edge and (edge - groupWidth - cx) or -ns.Snap(UIParent:GetWidth() / 4)
        ns.PlaceFromCenter(groupAnchor, "TOPLEFT", x, ns.Snap(300))
    end)
    ns.layoutFrames.groupframes = groupAnchor

    -- Schlachtzug ab 16 Spielern: unten links über dem Chat (über Eingabefeld und Reitern), Gruppen
    -- als Spalten nach rechts. Bis 25 Spieler (5 Gruppen) der normale, ab dem 26. der 40er mit
    -- kleineren Frames – WoW schaltet selbst um ([@raid16,exists], [@raid26,exists]), auch im Kampf.
    local raid, raidAnchor = SpawnGroup(self, "raid", "MeredanUIRaid",
        healer and "custom [@raid26,exists] hide; [@raid21,exists] show; hide" or "custom [@raid26,exists] hide; [@raid16,exists] show; hide",
        5, false, raidRows, "showParty", false, "showRaid", true)
    local raid40, raid40Anchor = SpawnGroup(self, "raid40", "MeredanUIRaid40",
        "custom [@raid26,exists] show; hide", healer and 4 or 8, false, raid40Rows, "showParty", false, "showRaid", true)
    -- gleicher Platz wie der Schlachtzug, aber unten bündig (gleicher Abstand zum Chat; der 40er
    -- ist niedriger). Der Header wächst von oben nach unten: Oberkante = Unterkante + Blockhöhe.
    if healer then
        ns.OnLayout(function() PlaceHealer(raid40Anchor) end) -- Heiler: eigener Platz, gleicher Kasten
    else
        raid40:ClearAllPoints()
        raid40:SetPoint("TOPLEFT", raidAnchor, "BOTTOMLEFT", 0, raid40Anchor:GetHeight())
        raid40Anchor:Hide()
    end
    ns.OnLayout(function()
        if healer then return PlaceHealer(raidAnchor) end -- Heiler: 21–40 am Platz der Gruppe
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

-- Demos (Einstellungen > Gruppenframes): „Gruppe (5)“, „Schlachtzug (25)“, „Schlachtzug (40)“ – immer
-- nur eine; der Header zeigt die Größe auch allein, Lücken füllt er mit dir als Platzhalter (echte
-- Mitspieler bleiben). /mui t zeigt die Gruppe mit. Nur außerhalb des Kampfs (geschützte Frames);
-- der Kampfbeginn beendet die Demo.
-- Vorschau-Größen: group10 = 10er (Barrow Deeps, Warsongschlucht) – läuft über die Gruppenframes
local TEST_COUNT = { group = 5, group10 = 10, group15 = 15, group20 = 20, raid = 25, raid40 = 40 }
-- welcher Header zeigt die Größe? Heiler: bis 20 die Gruppe, darüber der Schlachtzug (Reihen à 10)
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

-- Beispielgruppe für die Vorschau (Benny 2026-11-07: „komplett nichtssagend“): Tank, Heiler, drei
-- DD in Klassenfarben; alle 4 s wechseln die Zustände (3 Durchgänge), damit man Aggro-Rahmen,
-- Debuffs, fehlenden Buff, Schild, Tod, Offline, Bereitschaft und Ziel einmal sieht. Nur die
-- Platzhalter-Frames (unit = player) werden so gefüllt; oUF-Elemente sind solange aus.
local DEMO_PHASES = 3
local DEMO_SECONDS = 4
local DEMO_ELEMENTS = { "Health", "Power", "GroupRoleIndicator", "ThreatIndicator", "LeaderIndicator",
    "AssistantIndicator", "ReadyCheckIndicator", "Range", "TargetIndicator", "ResurrectIndicator",
    "SummonIndicator", "PhaseIndicator", "PrivateAuras", "RaidTargetIndicator" }
local MAGIC, CURSE, POISON = 136071, 136139, 136007   -- Beispiel-Symbole (wie im Unitframe-Test)
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
            -- Heiler: Rahmen in Dispel-Farbe um den ganzen Frame
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
    -- Leben in Klassenfarbe (oder Theme-Farbe), Schild
    local health = button.Health
    local hp = data.hp[phase] or 100
    health:Show() -- oUF versteckt den Balken beim Abschalten des Elements
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
    -- Mana nur beim Heiler
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
    -- Rolle, Leiter, Ziel, Aggro
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
    -- fehlender Buff (Beispiel: Arkane Intelligenz)
    local missing = data.missing and data.missing[phase]
    if missing then button.MissingBuff:SetTexture(C_Spell.GetSpellTexture(1459) or 135932) end
    button.MissingBuff:SetShown(missing or false)
    -- Status unter dem Namen
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
    -- Debuffs: dispellbar (Rahmen in Dispel-Farbe) unten links, Boss-Debuff groß mittig
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
            if not button:GetAttribute("unit") then -- nur Platzhalter, echte Mitspieler bleiben
                UnregisterUnitWatch(button)
                button:SetAttribute("unit", "player")
                button.muiTestFill = true
                RegisterUnitWatch(button, true)
                button:Show()
                if button.UpdateAllElements then button:UpdateAllElements("MeredanGroupTest") end
            end
        end
        -- Beispielgruppe mit wechselnden Zuständen
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
        RestoreDemo(button) -- auch der eigene Frame (allein unterwegs)
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

-- kind: "group", "raid" oder "raid40"
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

-- /mui t (Unitframes-Test): die Gruppe zeigt sich mit
function ns.GroupTestStart() if not testing then ns.GroupDemo("group") end end
function ns.GroupTestStop() if testing == "group" then ns.GroupDemoStop() end end

ns:On("PLAYER_REGEN_DISABLED", function() ns.GroupDemoStop() end)
