-- Rechtsklick-Menü für Gildenmitglieder im mUI-Gildenfenster (Benny 2026-11-08).
--
--   Name
--   ─────────────
--   Flüstern
--   In Gruppe einladen
--   ─────────────
--   Befördern          ← sichere Makro-Knöpfe (/gpromote, /gdemote, /gremove)
--   Degradieren
--   Aus der Gilde entfernen   (erster Klick: „Wirklich entfernen?“, zweiter Klick führt aus)
--
-- Blizzards Menü (UnitPopup) aus Addon-Code geöffnet blockiert Befördern/Degradieren („geschützte
-- Funktion step()“). Die sicheren Chat-Befehle über SecureActionButtons (type = macro) sind erlaubt.
-- Makrotexte werden nur außerhalb des Kampfs gesetzt; im Kampf öffnet das Menü nicht.
local _, ns = ...
local L = ns.L

local WIDTH, ROW = 200, 24
local MAX_RANKS = 10
local lastArgs -- letzte Öffnung (für Neuaufbau nach jedem Rang-Schritt)

-- aktueller Rang (1 = höchster) eines Mitglieds aus der Gildenliste
local function CurrentRank(name)
    if not (GetNumGuildMembers and GetGuildRosterInfo) then return end
    local short = Ambiguate and Ambiguate(name, "none") or name
    for i = 1, GetNumGuildMembers() do
        local full, _, rankIndex = GetGuildRosterInfo(i)
        if full and (full == name or (Ambiguate and Ambiguate(full, "none") == short)) then
            return rankIndex and rankIndex + 1
        end
    end
end
local menu, rows = nil, {}
local current -- Name des Mitglieds

local function Slash(key, fallback) return (_G[key] or fallback) .. " " end

local function Close()
    if not menu or InCombatLockdown() then return end
    menu:Hide()
end

-- Zeile: secure = Makro-Knopf, sonst normaler Knopf mit onClick
local function Row(index, secure)
    local UI = ns.UI
    local row = CreateFrame("Button", "MeredanUIGuildMenuRow" .. index, menu, secure and "SecureActionButtonTemplate" or nil)
    row:SetHeight(ROW)
    row:RegisterForClicks("AnyUp", "AnyDown")
    if secure then row:SetAttribute("type", "macro") end
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(UI.HOVER))
    hover:Hide()
    row.text = UI.Text(row, 13, "LEFT")
    row.text:SetPoint("LEFT", 12, 0)
    row:SetScript("OnEnter", function() hover:Show() end)
    row:SetScript("OnLeave", function() hover:Hide() end)
    return row
end

local function Create()
    local UI = ns.UI
    menu = CreateFrame("Frame", "MeredanUIGuildMemberMenu", UIParent)
    menu:SetWidth(WIDTH)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()
    UI.Box(menu, { 0.06, 0.06, 0.07, 0.98 })
    local accent = menu:CreateTexture(nil, "OVERLAY")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    tinsert(UISpecialFrames, "MeredanUIGuildMemberMenu")

    menu.title = UI.Text(menu, 13, "LEFT", UI.ACCENT)
    menu.title:SetPoint("TOPLEFT", 12, -10)

    -- normale Einträge
    rows.whisper = Row("Whisper")
    rows.whisper.text:SetText(WHISPER or L["Whisper"])
    rows.whisper:SetScript("OnClick", function()
        if current then ChatFrameUtil.SendTell(current) end
        Close()
    end)
    rows.invite = Row("Invite")
    rows.invite.text:SetText(PARTY_INVITE or INVITE or L["Invite"])
    rows.invite:SetScript("OnClick", function()
        if current then C_PartyInfo.InviteUnit(current) end
        Close()
    end)
    -- geschützte Einträge: sichere Makro-Knöpfe
    rows.promote = Row("Promote", true)
    rows.promote.text:SetText(GUILD_PROMOTE or L["Promote"])
    rows.demote = Row("Demote", true)
    rows.demote.text:SetText(GUILD_DEMOTE or L["Demote"])
    rows.remove = Row("Remove", true)
    rows.remove.text:SetTextColor(1, 0.38, 0.38)
    for _, key in ipairs({ "promote", "demote" }) do
        rows[key]:HookScript("PostClick", function(_, _, down)
            if not down then C_Timer.After(0, Close) end
        end)
    end
    -- Entfernen: erster Klick schaltet scharf, zweiter führt aus
    rows.remove:HookScript("PostClick", function(self, _, down)
        if down or InCombatLockdown() then return end
        if self.armed then
            C_Timer.After(0, Close)
        else
            self.armed = true
            self.text:SetText(L["Really remove?"])
            self:SetAttribute("macrotext", Slash("SLASH_GUILD_UNINVITE1", "/gremove") .. (current or ""))
        end
    end)

    -- „Rang festlegen“: je Rang ein sicherer Knopf; Blizzard kennt keinen Befehl „Rang X“, also so viele
    -- /gpromote bzw. /gdemote hintereinander, bis der Zielrang erreicht ist (Benny 2026-11-08: „zum Twink machen“)
    menu.rankHeader = UI.Text(menu, 11, "LEFT", UI.MUTED)
    menu.rankHeader:SetText(L["Set rank"]:upper())
    rows.ranks = {}
    for i = 1, MAX_RANKS do
        local row = Row("Rank" .. i, true)
        row.steps = row:CreateFontString(nil, "OVERLAY")
        row.steps:SetFont(ns.FontFor(), ns.FontPx(11), "")
        row.steps:SetTextColor(unpack(UI.MUTED))
        row.steps:SetPoint("RIGHT", -10, 0)
        -- ein Schritt je Klick (mehrere Befehle am Stück verarbeitet der Server falsch, Benny 2026-11-08);
        -- Menü bleibt offen und wird mit dem neuen Rang neu aufgebaut, sobald der Server ihn meldet
        row:HookScript("PostClick", function(_, _, down)
            if down then return end
            menu.waiting = true
            if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
        end)
        rows.ranks[i] = row
    end

    menu:SetScript("OnHide", function()
        local function Clean()
            for _, key in ipairs({ "promote", "demote", "remove" }) do rows[key]:SetAttribute("macrotext", "") end
            for _, row in ipairs(rows.ranks) do row:SetAttribute("macrotext", "") end
            rows.remove.armed = nil
        end
        if InCombatLockdown() then ns.AfterCombat(Clean) else Clean() end
    end)
    -- Klick daneben schließt; neuer Rang vom Server: Menü neu aufbauen
    menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    menu:RegisterEvent("GUILD_ROSTER_UPDATE")
    menu:SetScript("OnEvent", function(self, event)
        if event == "GUILD_ROSTER_UPDATE" then
            if self.waiting and self:IsShown() and lastArgs and not InCombatLockdown() then
                self.waiting = nil
                local rank = CurrentRank(lastArgs[1]) or lastArgs[3]
                ns.OpenGuildMemberMenu(lastArgs[1], lastArgs[2], rank, lastArgs[4])
            end
            return
        end
        if self:IsShown() and not self:IsMouseOver() then Close() end
    end)
end

-- info: Mitgliedsdaten aus der Gildenliste; canManage: Beförderungs-Einträge zeigen
-- opts.ranksOnly: nur „Rang festlegen“ (Rang-Auswahl im Detailfenster), opts.owner: darunter öffnen,
-- opts.guid: nicht erlaubte Ränge grau und ohne Befehl (C_GuildInfo.IsGuildRankAssignmentAllowed)
function ns.OpenGuildMemberMenu(name, isSelf, rankOrder, opts)
    opts = opts or {}
    lastArgs = { name, isSelf, rankOrder, opts }
    if InCombatLockdown() then
        return UIErrorsFrame:AddMessage(L["Not possible in combat."], 1, 0.1, 0.1)
    end
    if not menu then Create() end
    current = name
    menu.title:SetText(Ambiguate and Ambiguate(name, "guild") or name)
    local officer = (IsGuildLeader and IsGuildLeader()) or (C_GuildInfo.IsGuildOfficer and C_GuildInfo.IsGuildOfficer())
    local list = opts.ranksOnly and {} or { "whisper", "invite" }
    if officer and not isSelf and not opts.ranksOnly then
        list[#list + 1] = "promote"
        list[#list + 1] = "demote"
        list[#list + 1] = "remove"
    end
    for _, key in ipairs({ "whisper", "invite", "promote", "demote", "remove" }) do rows[key]:Hide() end
    rows.promote:SetAttribute("macrotext", Slash("SLASH_GUILD_PROMOTE1", "/gpromote") .. name)
    rows.demote:SetAttribute("macrotext", Slash("SLASH_GUILD_DEMOTE1", "/gdemote") .. name)
    rows.remove:SetAttribute("macrotext", "") -- erst nach dem ersten Klick scharf
    rows.remove.armed = nil
    rows.remove.text:SetText(GUILD_UNINVITE or L["Remove from guild"])
    local y = 30
    for i, key in ipairs(list) do
        local row = rows[key]
        row:ClearAllPoints()
        if key == "promote" then y = y + 6 end -- Abstand vor den Rang-Einträgen
        row:SetPoint("TOPLEFT", 1, -y)
        row:SetPoint("TOPRIGHT", -1, -y)
        row:Show()
        y = y + ROW
    end
    -- Rang festlegen (Rangfolge: 1 = Gildenmeister, größer = niedriger)
    for _, row in ipairs(rows.ranks) do row:Hide() end
    menu.rankHeader:Hide()
    local numRanks = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
    if officer and not isSelf and rankOrder and numRanks > 1 then
        y = y + (opts.ranksOnly and -14 or 8)
        menu.rankHeader:ClearAllPoints()
        menu.rankHeader:SetPoint("TOPLEFT", 12, -y)
        menu.rankHeader:Show()
        y = y + 16
        local promote = Slash("SLASH_GUILD_PROMOTE1", "/gpromote") .. name
        local demote = Slash("SLASH_GUILD_DEMOTE1", "/gdemote") .. name
        for i = 2, math.min(numRanks, MAX_RANKS) do -- Rang 1 (Gildenmeister) nur per Übergabe
            local row = rows.ranks[i - 1]
            local steps = i - rankOrder
            local lines = {}
            if steps ~= 0 then lines[1] = steps > 0 and demote or promote end -- genau ein Schritt
            row.steps:SetText(steps ~= 0 and L["%d steps"]:format(math.abs(steps)) or "")
            local allowed = steps == 0 or not (opts.guid and C_GuildInfo.IsGuildRankAssignmentAllowed)
                or C_GuildInfo.IsGuildRankAssignmentAllowed(opts.guid, i)
            row:SetAttribute("macrotext", allowed and table.concat(lines, "\n") or "")
            row.text:SetText(GuildControlGetRankName(i) or ("#" .. i))
            row.text:SetTextColor(unpack(steps == 0 and ns.UI.ACCENT or (allowed and ns.UI.TEXT or ns.UI.MUTED)))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 1, -y)
            row:SetPoint("TOPRIGHT", -1, -y)
            row:Show()
            y = y + ROW
        end
    end
    menu:SetHeight(y + 6)
    menu:ClearAllPoints()
    menu.title:SetShown(not opts.ranksOnly)
    if opts.owner then
        menu:SetPoint("TOPLEFT", opts.owner, "BOTTOMLEFT", 0, -2)
    else
        local x, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 4, cy / scale - 4)
    end
    menu:Show()
end
