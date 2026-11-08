-- Weltaktualisierung (Layer-/Shard-Wechsel, Forever): Blizzard zeigt über dem Chat „Weltaktualisierung
-- in 10 Minuten“; erst ein Klick darauf öffnet ein Fenster mit „Jetzt aktualisieren“. Hier eine
-- Meldung im MUI-Look mit dem Knopf direkt darin (Benny 2026-11-06).
--
--   ┃ [◈]  Weltaktualisierung in 9 Minuten          [Jetzt aktualisieren] [x]
--
-- C_PlayerInteractionManager.ShardTransferConfirm ist nicht geschützt; im Kampf lässt das Spiel den
-- Wechsel nicht zu (Knopf gesperrt, Tooltip wie bei Blizzard).
local _, ns = ...
local L = ns.L

local frame, timer, dismissed

local function Text()
    if not timer or timer <= 0 then return SHARD_TRANSFER_ANYTIME or L["The world can refresh at any time."] end
    local minutes = timer >= 60
    local value = minutes and math.ceil(timer / 60) or math.ceil(timer)
    local unit = minutes and (MINUTES or "min") or (SECONDS or "sec")
    if SHARD_TRANSFER_REFRESH_MESSAGE then return SHARD_TRANSFER_REFRESH_MESSAGE:format(value, unit) end
    return L["World refresh in %d %s"]:format(value, unit)
end

local function Create()
    local UI = ns.UI
    frame = CreateFrame("Frame", "MeredanUIShardTransfer", UIParent)
    frame:SetSize(ns.Snap(420), ns.Snap(40))
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(true)
    frame:Hide()
    UI.Box(frame, ns.STYLE.panelColor)
    local edge = frame:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(unpack(UI.ACCENT))
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("BOTTOMLEFT")
    edge:SetWidth(2 * ns.PixelSize())
    local icon = UI.Icon(frame, "Phase", 18, UI.ACCENT)
    icon:SetPoint("LEFT", 12, 0)

    local close = UI.IconButton(frame, "Close", function()
        dismissed = true -- bis zur nächsten Ankündigung
        frame:Hide()
    end, 22)
    close:SetPoint("RIGHT", -9, 0)
    local now = UI.Button(frame, SHARD_TRANSFER_NOW_BUTTON or L["Refresh now"], function()
        if UnitAffectingCombat("player") then return end
        C_PlayerInteractionManager.ShardTransferConfirm()
    end, 10)
    now:SetHeight(24)
    now:SetWidth(now.Text:GetUnboundedStringWidth() + 24)
    now:SetPoint("RIGHT", close, "LEFT", -6, 0)
    now.Text:SetTextColor(unpack(UI.ACCENT))
    for _, e in ipairs(ns.AddBorder(now, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end
    now:HookScript("OnEnter", function(self)
        if not UnitAffectingCombat("player") then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(SHARD_TRANSFER_COMBAT or L["Not possible in combat."], 1, 0.3, 0.3, 1, true)
        GameTooltip:Show()
    end)
    now:HookScript("OnLeave", function() GameTooltip:Hide() end)
    frame.now = now

    frame.text = UI.Text(frame, 13, "LEFT")
    frame.text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    frame.text:SetPoint("RIGHT", now, "LEFT", -10, 0)
    frame.text:SetWordWrap(false)

    local elapsedSince = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
        if timer then timer = timer - elapsed end
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < 0.25 then return end
        elapsedSince = 0
        self.text:SetText(Text())
        local fighting = UnitAffectingCombat("player")
        self.now.Text:SetTextColor(unpack(fighting and UI.MUTED or UI.ACCENT))
    end)

    -- über dem Chat, wo Blizzard die Meldung zeigt
    frame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(70)) -- über Reitern und Eingabefeld (Benny 2026-11-07: lag darunter)
    ns.layoutFrames.shardtransfer = frame
end

local function Show()
    if not frame then Create() end
    timer = GetEvictionTimeRemaining and GetEvictionTimeRemaining() or timer
    if dismissed then return end
    frame.text:SetText(Text())
    frame:Show()
end

local function Hide()
    timer, dismissed = nil, nil
    if frame then frame:Hide() end
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    -- Blizzards Meldung und Minimieren-Knopf unsichtbar parken (bleiben aktiv, nur nicht zu sehen)
    local hidden = CreateFrame("Frame")
    hidden:Hide()
    for _, name in ipairs({ "ShardTransferImminentFrame", "ShardTransferImminentMinimizeButton" }) do
        local blizzard = _G[name]
        if blizzard then blizzard:SetParent(hidden) end
    end
    ns:On("SHARD_TRANSFER_IMMINENT", function()
        dismissed = nil
        Show()
    end)
    -- nach /reload läuft eine Ankündigung evtl. schon (das Ereignis kommt nicht noch einmal)
    C_Timer.After(2, function()
        if GetEvictionTimeRemaining and (GetEvictionTimeRemaining() or 0) > 0 then Show() end
    end)
    ns:On("SHARD_TRANSFER_CANCELLED", Hide)
    ns:On("SHARD_TRANSFER", Hide)
end)

-- Vorschau (Core/Preview.lua): Ankündigung mit Beispielzeit; echte Ankündigungen bleiben unberührt
local demoActive = false
ns.ShardTransferDemo = {
    Start = function()
        if not ns.IS_FOREVER or (frame and frame:IsShown()) then return end
        demoActive = true
        if not frame then Create() end
        timer = 600
        frame.text:SetText(Text())
        frame:Show()
    end,
    Stop = function()
        if not demoActive then return end
        demoActive = false
        Hide()
    end,
    IsActive = function() return demoActive end,
}
