-- Gildeneinladung aus dem mUI-Gildenfenster (Benny 2026-11-08).
--
--   ┌ Gildenmitglied einladen ───────────────┐
--   │ [ Name eingeben…                     ] │
--   │   Vorschläge (online, nicht in Gilde)  │
--   │                [Abbrechen] [Einladen]  │
--   └────────────────────────────────────────┘
--
-- Blizzards Einladefunktion (C_GuildInfo.Invite) ist geschützt: ruft Addon-Code sie oder Blizzards
-- Dialog auf, verweigert das Spiel die Einladung. Erlaubt ist der Chat-Befehl /ginvite über einen
-- sicheren Makro-Knopf – Blizzards Makro-System führt ihn aus. „Einladen“ ist deshalb ein
-- SecureActionButton (type = macro), dessen Text beim Tippen auf „/ginvite Name“ gesetzt wird.
-- Enter: erster Vorschlag übernehmen, zweites Enter lädt ein (Tastenbelegung klickt den Knopf).
-- Im Kampf lassen sich geschützte Knöpfe nicht umstellen – dann nur ein Hinweis.
local _, ns = ...
local L = ns.L

local WIDTH, MAX_SUGGEST = 340, 6
local dialog, edit, invite, rows, hint

local function SlashInvite() return (SLASH_GUILD_INVITE1 or "/ginvite") .. " " end

local function Suggestions(text)
    if text == "" or not (C_AutoComplete and C_AutoComplete.GetAutoCompleteResults and AUTOCOMPLETE_LIST) then return {} end
    local list = AUTOCOMPLETE_LIST.GUILD_INVITE
    local ok, results = pcall(C_AutoComplete.GetAutoCompleteResults, text, MAX_SUGGEST, #text, true,
        list and list.include or 0, list and list.exclude or 0)
    return ok and results or {}
end

local function SetName(name)
    if InCombatLockdown() then return end
    name = strtrim(name or "")
    invite:SetAttribute("macrotext", name ~= "" and (SlashInvite() .. name) or "")
    invite:SetEnabled(name ~= "")
end

local function Refresh()
    local text = edit:GetText()
    local combat = InCombatLockdown()
    hint:SetShown(combat)
    if not combat then SetName(text) end
    local results = Suggestions(text)
    for i, row in ipairs(rows) do
        local r = results[i]
        local name = r and (r.name or r[1])
        row.name = name
        row.text:SetText(name or "")
        row:SetShown(name ~= nil and name ~= text)
    end
end

local function Close()
    if InCombatLockdown() then return end
    ClearOverrideBindings(dialog)
    dialog:Hide()
end

local function Create()
    local UI = ns.UI
    dialog = CreateFrame("Frame", "MeredanUIGuildInvite", UIParent)
    dialog:SetSize(WIDTH, 96 + MAX_SUGGEST * 22)
    dialog:SetPoint("CENTER", 0, 120)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:Hide()
    UI.Box(dialog, ns.STYLE.panelColor)
    local accent = dialog:CreateTexture(nil, "OVERLAY")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    tinsert(UISpecialFrames, "MeredanUIGuildInvite") -- Esc schließt
    -- beim Schließen (auch per Esc) Enter-Belegung und Makrotext sofort weg
    dialog:SetScript("OnHide", function(self)
        local function Clean()
            ClearOverrideBindings(self)
            invite:SetAttribute("macrotext", "")
        end
        if InCombatLockdown() then ns.AfterCombat(Clean) else Clean() end
    end)

    local title = UI.Text(dialog, 14, "LEFT")
    ns.SetFont(title, 14, "", "bold")
    title:SetPoint("TOPLEFT", 14, -14)
    title:SetText(ADD_GUILDMEMBER_LABEL and ADD_GUILDMEMBER_LABEL:gsub(":%s*$", "") or L["Invite to guild"])

    edit = UI.EditBox(dialog, 26)
    edit:SetPoint("TOPLEFT", 14, -40)
    edit:SetPoint("TOPRIGHT", -14, -40)
    edit:SetMaxLetters(48)
    edit:SetAutoFocus(false)
    edit:SetScript("OnTextChanged", Refresh)
    edit:SetScript("OnEscapePressed", Close)
    edit:SetScript("OnEnterPressed", function(self)
        -- erster Vorschlag übernehmen; danach nimmt die Tastenbelegung das nächste Enter (Einladen)
        local first = rows[1] and rows[1]:IsShown() and rows[1].name
        if first then self:SetText(first) end
        self:ClearFocus()
    end)

    rows = {}
    for i = 1, MAX_SUGGEST do
        local row = CreateFrame("Button", nil, dialog)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -4 - (i - 1) * 22)
        row:SetPoint("TOPRIGHT", edit, "BOTTOMRIGHT", 0, -4 - (i - 1) * 22)
        local hover = row:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(unpack(UI.HOVER))
        hover:Hide()
        row.text = UI.Text(row, 12, "LEFT")
        row.text:SetPoint("LEFT", 8, 0)
        row:SetScript("OnEnter", function() hover:Show() row.text:SetTextColor(unpack(UI.ACCENT)) end)
        row:SetScript("OnLeave", function() hover:Hide() row.text:SetTextColor(unpack(UI.TEXT)) end)
        row:SetScript("OnClick", function(self)
            edit:SetText(self.name or "")
            edit:ClearFocus()
        end)
        row:Hide()
        rows[i] = row
    end

    -- Einladen: sicherer Makro-Knopf (führt /ginvite Name aus)
    invite = CreateFrame("Button", "MeredanUIGuildInviteButton", dialog, "SecureActionButtonTemplate")
    invite:SetSize(120, 26)
    invite:SetPoint("BOTTOMRIGHT", -14, 14)
    invite:RegisterForClicks("AnyUp", "AnyDown")
    invite:SetAttribute("type", "macro")
    local bg = UI.Box(invite)
    local label = UI.Text(invite, 12, "CENTER")
    label:SetPoint("CENTER")
    label:SetText(INVITE or L["Invite"])
    invite:SetScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
    invite:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    invite:HookScript("OnDisable", function() label:SetTextColor(unpack(UI.MUTED)) end)
    invite:HookScript("OnEnable", function() label:SetTextColor(unpack(UI.TEXT)) end)
    -- nach dem Klick (der sichere Teil läuft vorher) schließen
    invite:HookScript("PostClick", function(_, _, down)
        if down == false or down == nil then C_Timer.After(0, Close) end
    end)
    for _, e in ipairs(ns.AddBorder(invite, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end

    local cancel = UI.Button(dialog, CANCEL or L["Cancel"], Close, 120)
    cancel:SetHeight(26)
    cancel:SetPoint("RIGHT", invite, "LEFT", -8, 0)

    hint = UI.Text(dialog, 11, "LEFT", UI.MUTED)
    hint:SetPoint("BOTTOMLEFT", 14, 20)
    hint:SetText(L["Not possible in combat."])
    hint:Hide()
end

function ns.OpenGuildInvite()
    if InCombatLockdown() then
        return UIErrorsFrame:AddMessage(L["Not possible in combat."], 1, 0.1, 0.1)
    end
    if not dialog then Create() end
    edit:SetText("")
    Refresh()
    dialog:Show()
    edit:SetFocus()
    -- zweites Enter (Feld ohne Fokus) klickt „Einladen“ – über eine Tastenbelegung, also sicher
    SetOverrideBindingClick(dialog, true, "ENTER", "MeredanUIGuildInviteButton", "LeftButton")
end

ns:On("PLAYER_REGEN_DISABLED", function() if dialog and dialog:IsShown() then hint:Show() end end)
ns:On("PLAYER_REGEN_ENABLED", function() if dialog and dialog:IsShown() then Refresh() end end)
