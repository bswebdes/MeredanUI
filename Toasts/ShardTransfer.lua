-- World refresh (layer/shard transfer, Forever): replaces Blizzard's notice above the chat, which
-- needs an extra click to reach "Refresh now", with an mUI bar that has the button inline.
--
--   | [icon]  World refresh in 9 minutes          [Refresh now] [x]
--
-- C_PlayerInteractionManager.ShardTransferConfirm is not protected; the game refuses the transfer
-- in combat (button disabled, tooltip as in Blizzard's UI).
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
    UI.Box(frame, ns.STYLE.panelColor, true)
    ns.RuneFrame(frame, { small = true })
    local icon = UI.Icon(frame, "Phase", 18, UI.ACCENT)
    icon:SetPoint("LEFT", 12, 0)

    local close = UI.IconButton(frame, "Close", function()
        dismissed = true -- until the next announcement
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

    -- above the chat (clearing tabs and edit box), where Blizzard shows the notice
    frame:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(70))
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
    -- Park Blizzard's notice and minimize button hidden (they stay functional, just invisible)
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
    -- After /reload an announcement may already be running (the event does not fire again)
    C_Timer.After(2, function()
        if GetEvictionTimeRemaining and (GetEvictionTimeRemaining() or 0) > 0 then Show() end
    end)
    ns:On("SHARD_TRANSFER_CANCELLED", Hide)
    ns:On("SHARD_TRANSFER", Hide)
end)

-- Preview (Core/Preview.lua): announcement with a sample time; real announcements are left alone
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
