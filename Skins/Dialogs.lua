-- Bestätigungsfenster (StaticPopup1–4) im MUI-Look (Benny 2026-11-06): „Gegenstand zerstören?“,
-- Goldhandel mit ablaufender Zeit, Gruppeneinladung … Eigene Fenster gehen hier nicht – die Knöpfe
-- lösen teils geschützte Aktionen aus (Wiederbeleben, Gegenstand binden …). Deshalb nur die Optik:
-- Blizzards Rahmen/Hintergrund unsichtbar, darunter unsere Fläche mit Surf-Green-Kante, flache
-- Knöpfe, Eingabefeld und Zeitbalken im MUI-Look. Nichts an Blizzards Tabellen geschrieben, nur
-- Texturen/Schriften gesetzt und HookScript/hooksecurefunc – damit bleibt alles unverseucht.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local skinned = {} -- Rahmen > true (nicht als Feld am Blizzard-Rahmen speichern)
local fonts

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.skinDialogs ~= false
end

local function Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, color)
        local font = CreateFont(name)
        font:SetFont(ns.STYLE.font, ns.FontPx(13), "")
        font:SetTextColor(unpack(color))
        font:SetShadowOffset(1, -1)
        font:SetShadowColor(0, 0, 0, 1)
        return font
    end
    fonts = {
        normal = Make("MeredanUIDialogButton", UI.TEXT),
        highlight = Make("MeredanUIDialogButtonHighlight", UI.ACCENT),
        disabled = Make("MeredanUIDialogButtonDisabled", UI.MUTED),
    }
    return fonts
end

-- flacher Knopf: Blizzards Grafiken unsichtbar, darunter Fläche + 1-px-Rand, Hover hellt auf
local function SkinButton(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    local UI = ns.UI
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(),
        button:GetHighlightTexture() }) do
        if texture then texture:SetAlpha(0) end
    end
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.FIELD))
    ns.AddBorder(button)
    button:HookScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
    button:HookScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    local f = Fonts()
    button:SetNormalFontObject(f.normal)
    button:SetHighlightFontObject(f.highlight)
    button:SetDisabledFontObject(f.disabled)
end

local function SkinCloseButton(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    local UI = ns.UI
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(),
        button:GetHighlightTexture() }) do
        if texture then texture:SetAlpha(0) end
    end
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(unpack(UI.FIELD))
    local icon = UI.Icon(button, "Close", 14)
    icon:SetPoint("CENTER")
    button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
end

local function SkinEditBox(editBox)
    if not editBox or skinned[editBox] then return end
    skinned[editBox] = true
    local UI = ns.UI
    if editBox.NineSlice then editBox.NineSlice:SetAlpha(0) end
    local bg = editBox:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.FIELD))
    ns.AddBorder(editBox)
    local focus = ns.AddBorder(editBox, true)
    for _, edge in ipairs(focus) do
        edge:SetVertexColor(unpack(UI.ACCENT))
        edge:Hide()
    end
    editBox:HookScript("OnEditFocusGained", function() for _, e in ipairs(focus) do e:Show() end end)
    editBox:HookScript("OnEditFocusLost", function() for _, e in ipairs(focus) do e:Hide() end end)
end

-- Zeitbalken (z. B. Goldhandel): Blizzards Rahmen weg, flacher Balken in Surf Green
local function SkinProgressBar(popup)
    local border, fill = popup.ProgressBarBorder, popup.ProgressBarFill
    if not (border and fill) or skinned[border] then return end
    skinned[border] = true
    local UI = ns.UI
    border:SetAlpha(0)
    fill:SetTexture(ns.STYLE.barTexture or WHITE)
    fill:SetVertexColor(unpack(UI.ACCENT))
    local back = CreateFrame("Frame", nil, popup)
    back:SetPoint("TOPLEFT", border, "TOPLEFT", 4, -4)
    back:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -4, 4)
    back:SetFrameLevel(popup:GetFrameLevel())
    local bg = back:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.05, 1)
    ns.AddBorder(back)
    local function Sync() back:SetShown(border:IsShown()) end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do hooksecurefunc(border, method, Sync) end
    Sync()
end

local function ApplyText(popup)
    for _, region in ipairs({ popup.Text, popup.ConfirmText, popup.SubText }) do
        if region then
            local _, size = region:GetFont()
            region:SetFont(ns.STYLE.font, math.max(math.floor((size or 13) + 0.5), 12), "")
        end
    end
end

local function SkinPopup(popup)
    if not popup or skinned[popup] then return end
    skinned[popup] = true
    local UI = ns.UI
    if popup.BG then popup.BG:SetAlpha(0) end -- Blizzards Rahmen und Hintergrund (Atlas)
    local bg = popup:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    local c = ns.STYLE.panelColor
    bg:SetColorTexture(c[1], c[2], c[3], 0.96)
    ns.AddBorder(popup)
    local accent = popup:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    local container = popup.ButtonContainer
    for _, button in ipairs(container and container.Buttons or {}) do SkinButton(button) end
    SkinButton(popup.ExtraButton)
    SkinCloseButton(popup.CloseButton)
    SkinEditBox(popup.EditBox)
    SkinProgressBar(popup)
    if popup.ItemFrame and popup.ItemFrame.NameFrame then popup.ItemFrame.NameFrame:SetAlpha(0) end
    popup:HookScript("OnShow", ApplyText)
    -- Eingabefelder breiter: Blizzards Standard (130 px) ist für Namen und Notizen zu schmal
    -- (Benny 2026-11-07, „Gildenmitglied hinzufügen“). Nach Blizzards Aufbau einen Takt später.
    popup:HookScript("OnShow", function(self)
        C_Timer.After(0, function()
            local edit = self.EditBox
            if self:IsShown() and edit and edit:IsShown() and edit:GetWidth() < 240 then
                edit:SetWidth(260)
                if self:GetWidth() < 300 then self:SetWidth(320) end
            end
        end)
    end)
    if popup:IsShown() then ApplyText(popup) end
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    for i = 1, 4 do SkinPopup(_G["StaticPopup" .. i]) end
end)
