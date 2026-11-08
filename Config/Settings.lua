-- Entry in Blizzard's settings (Esc > Options > AddOns > MeredanUI): just a button that opens
-- mUI's own settings window (Options.lua).
local ADDON_NAME, ns = ...
local L = ns.L

-- Never close Blizzard's settings from code: HideUIPanel from addon code taints them (e.g.
-- C_Discord.IsUserOAuthed got blocked on next open). mUI's window sits on DIALOG strata above it.
local function OpenFromBlizzard()
    ns.ShowSettings()
end

-- Register as a canvas, NOT as a list with a button entry: list entries from addon code are
-- walked by Blizzard's settings search, which then counts as tainted and blocks
-- C_Discord.IsUserOAuthed (e.g. on the Contacts page). A canvas is not searched.
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
