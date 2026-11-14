-- Game menu (Esc) in mUI style: dark background with a Surf Green top line, title in mUI font,
-- bevel buttons instead of Blizzard's red ones, plus a "mUI Settings" button on top.
-- Visual only: Blizzard's buttons keep text, click and order; their red parts are hidden.
-- Our button is inserted via layoutIndex 0.
local _, ns = ...
local L = ns.L

local BUTTON_H = 32
local BUTTON_GAP = 6
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

-- Reskin a Blizzard button (from the pool) once: bevel like mUI's own buttons (Skins/Kit.lua; its
-- hover watcher survives Blizzard clearing OnEnter/OnLeave on every InitButtons)
local function SkinButton(b)
    if skinned[b] then return end
    skinned[b] = true
    ns.SkinKit.Button(b)
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
    local title = UI.Title(menu, 16, "CENTER") -- window titles are Cinzel in the rune look
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
        for i, b in ipairs(menu.buttons or {}) do
            SkinButton(b)
            b:SetHeight(BUTTON_H)
            -- gap between buttons of a section (bevels touching looked cramped); section starts keep
            -- Blizzard's own 20 px. AddButton sets topPadding fresh on every InitButtons.
            if i > 1 and not b.topPadding then b.topPadding = BUTTON_GAP end
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

-- Opening another window (e.g. the guild via its key) while the game menu is open: close the menu
-- instead of letting Blizzard's panel manager shove it beside the window. HideUIPanel goes through
-- Blizzard's secure FramePositionDelegate, so calling it from addon code is safe. Windows the menu
-- itself opens (Options, AddOns, Macros ...) hide the menu first, so they never get here.
hooksecurefunc("ShowUIPanel", function(frame)
    if not GameMenuFrame or frame == GameMenuFrame or not GameMenuFrame:IsShown() then return end
    C_Timer.After(0, function()
        if GameMenuFrame:IsShown() and frame and frame.IsShown and frame:IsShown() then HideUIPanel(GameMenuFrame) end
    end)
end)

ns:On("PLAYER_LOGIN", function()
    if GameMenuFrame then Hook() else EventUtil.ContinueOnAddOnLoaded("Blizzard_GameMenu", Hook) end
end)
