-- Eintrag im Blizzard-Menü (Esc > Optionen > AddOns > MeredanUI): nur ein Button, der das
-- eigene Einstellungsfenster öffnet (Options.lua).
local ADDON_NAME, ns = ...
local L = ns.L

-- Blizzards Fenster NICHT per Code schließen (HideUIPanel aus Addon-Code verseucht die Optionen:
-- beim nächsten Öffnen wurde z. B. C_Discord.IsUserOAuthed blockiert). MUIs Fenster liegt eine
-- Ebene höher (DIALOG) und erscheint einfach darüber.
local function OpenFromBlizzard()
    ns.ShowSettings()
end

-- Als eigene Fläche (Canvas) anmelden, NICHT als Liste mit Knopf-Eintrag: Listen-Einträge aus
-- Addon-Code durchsucht Blizzards Suche mit – danach galt der Suchlauf als „von mUI berührt“ und
-- WoW blockte bei „Kontakte“ C_Discord.IsUserOAuthed (Benny 2026-11-07, Suche nach „Name“).
-- Eine Canvas-Fläche taucht in der Suche nicht auf.
ns:On("PLAYER_LOGIN", function()
    local panel = CreateFrame("Frame")
    panel:Hide()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Meredan|cff8ecbb4UI|r")
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    text:SetText(L["All settings are in mUI's own window (also /mui)."])
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(200, 26)
    button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
    button:SetText(L["Open mUI settings"])
    button:SetScript("OnClick", OpenFromBlizzard)
    local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME)
    Settings.RegisterAddOnCategory(category)
end)
