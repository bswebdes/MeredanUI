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

    menu:SetScript("OnHide", function()
        local function Clean()
            for _, key in ipairs({ "promote", "demote", "remove" }) do rows[key]:SetAttribute("macrotext", "") end
            rows.remove.armed = nil
        end
        if InCombatLockdown() then ns.AfterCombat(Clean) else Clean() end
    end)
    -- Klick daneben schließt
    menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    menu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() then Close() end
    end)
end

-- info: Mitgliedsdaten aus der Gildenliste; canManage: Beförderungs-Einträge zeigen
function ns.OpenGuildMemberMenu(name, isSelf)
    if InCombatLockdown() then
        return UIErrorsFrame:AddMessage(L["Not possible in combat."], 1, 0.1, 0.1)
    end
    if not menu then Create() end
    current = name
    menu.title:SetText(Ambiguate and Ambiguate(name, "guild") or name)
    local officer = (IsGuildLeader and IsGuildLeader()) or (C_GuildInfo.IsGuildOfficer and C_GuildInfo.IsGuildOfficer())
    local list = { "whisper", "invite" }
    if officer and not isSelf then
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
    menu:SetHeight(y + 6)
    local x, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 4, cy / scale - 4)
    menu:Show()
end
