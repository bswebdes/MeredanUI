-- Game menu (Esc) in mUI style: dark background with a Surf Green top line, title in mUI font,
-- flat dark buttons instead of Blizzard's red ones, plus a "mUI Settings" button on top.
-- Visual only: Blizzard's buttons keep text, click and order; their red parts are hidden.
-- Our button is inserted via layoutIndex 0.
local _, ns = ...
local L = ns.L

local BUTTON_H = 32
local button, skinned = nil, setmetatable({}, { __mode = "k" })
local fontNormal, fontDisabled

local function Fonts()
    if fontNormal then return end
    fontNormal = CreateFont("MeredanUIGameMenuFont")
    fontNormal:SetFont(ns.FontFor("bold"), ns.FontPx(14), "")
    fontNormal:SetTextColor(0.91, 0.9, 0.87)
    fontDisabled = CreateFont("MeredanUIGameMenuFontDisabled")
    fontDisabled:SetFont(ns.FontFor("bold"), ns.FontPx(14), "")
    fontDisabled:SetTextColor(0.45, 0.45, 0.43)
end

-- Reskin a Blizzard button (from the pool) once
local function SkinButton(b)
    if skinned[b] then return end
    skinned[b] = true
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Right", "Center" }) do
        if b[key] then b[key]:SetAlpha(0) end
    end
    local highlight = b:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.FIELD))
    b.muiBg = bg
    ns.AddBorder(b)
    b:HookScript("OnEnter", function(self) if self:IsEnabled() then self.muiBg:SetColorTexture(unpack(UI.HOVER)) end end)
    b:HookScript("OnLeave", function(self) self.muiBg:SetColorTexture(unpack(UI.FIELD)) end)
    b:SetNormalFontObject(fontNormal)
    b:SetHighlightFontObject(fontNormal)
    b:SetDisabledFontObject(fontDisabled)
    b:SetPushedTextOffset(0, -1)
end

local function SkinFrame(menu)
    if menu.muiSkinned then return end
    menu.muiSkinned = true
    local UI = ns.UI
    if menu.Border then menu.Border:SetAlpha(0) end
    if menu.Header then menu.Header:SetAlpha(0) end
    UI.Box(menu, ns.STYLE.panelColor, true)
    ns.RuneFrame(menu)
    local title = UI.Text(menu, 15, "CENTER")
    ns.SetFont(title, 15, "", "bold")
    title:SetPoint("TOP", 0, -16)
    title:SetText(MAINMENU_BUTTON or L["Game menu"])
end

local function Create(menu)
    local UI = ns.UI
    button = UI.Button(menu, "|cffe9e6ddm|r|cff8ecbb4UI|r" .. L["-Settings"], function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        HideUIPanel(menu)
        ns.OpenSettings()
    end, 200)
    button.layoutIndex = 0
    button.bottomPadding = 20 -- gap to "Options" like between Blizzard's sections
    for _, edge in ipairs(ns.AddBorder(button, true)) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    ns.SetFont(button.Text, 14, "", "bold")
end

local function Hook()
    if not GameMenuFrame or not GameMenuFrame.InitButtons or button ~= nil then return end
    button = false
    hooksecurefunc(GameMenuFrame, "InitButtons", function(menu)
        Fonts()
        SkinFrame(menu)
        if not button then Create(menu) end
        local width = 200
        for _, b in ipairs(menu.buttons or {}) do
            SkinButton(b)
            b:SetHeight(BUTTON_H)
            width = math.max(width, b:GetWidth())
        end
        if menu.closeButton then
            SkinButton(menu.closeButton)
            menu.closeButton:SetHeight(BUTTON_H)
        end
        button:SetSize(width, BUTTON_H)
        button:Show()
        menu:MarkDirty()
    end)
end

ns:On("PLAYER_LOGIN", function()
    if GameMenuFrame then Hook() else EventUtil.ContinueOnAddOnLoaded("Blizzard_GameMenu", Hook) end
end)
