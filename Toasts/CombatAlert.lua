-- Kampf-Meldung: kurz „+ Kampf“ (rot) bzw. „− Kampf“ (Surf Green) über der Bildschirmmitte –
-- flach, ohne Kasten, blendet ein und wieder aus. Einstellungen > Meldungen.
local _, ns = ...
local L = ns.L

local HOLD, FADE_IN, FADE_OUT = 0.8, 0.15, 0.5
local IN_COLOR = { 0.95, 0.3, 0.25 } -- wie das Kampf-Symbol am Spieler-Frame

local frame, text, anim

local function Create()
    frame = CreateFrame("Frame", "MeredanUICombatAlert", UIParent)
    frame:SetSize(300, 30)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    text = ns.CreateText(frame, 20, "CENTER", "OUTLINE")
    text:SetPoint("CENTER")

    anim = frame:CreateAnimationGroup()
    local fadeIn = anim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(FADE_IN)
    fadeIn:SetOrder(1)
    local fadeOut = anim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetStartDelay(HOLD)
    fadeOut:SetDuration(FADE_OUT)
    fadeOut:SetOrder(2)
    anim:SetScript("OnFinished", function() frame:Hide() end)
end

local function Show(entering)
    if ns.db.combatAlert == false then return end
    if not frame then Create() end
    if entering then
        text:SetText(L["+ Combat"])
        text:SetTextColor(unpack(IN_COLOR))
    else
        text:SetText(L["− Combat"])
        text:SetTextColor(unpack(ns.UI.ACCENT))
    end
    anim:Stop()
    frame:Show()
    anim:Play()
end

ns:On("PLAYER_REGEN_DISABLED", function() Show(true) end)
ns:On("PLAYER_REGEN_ENABLED", function() Show(false) end)

-- Vorschau (Core/Preview.lua): „+ Kampf“ und „− Kampf“ im Wechsel, alle 3 Sekunden
local demoTicker
ns.CombatAlertDemo = {
    Start = function()
        local entering = true
        Show(entering)
        demoTicker = C_Timer.NewTicker(3, function()
            entering = not entering
            Show(entering)
        end)
    end,
    Stop = function()
        if demoTicker then demoTicker:Cancel(); demoTicker = nil end
        if frame then frame:Hide() end
    end,
    IsActive = function() return demoTicker ~= nil end,
}
