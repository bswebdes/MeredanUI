-- RP mode: fades out the whole UI except chat, emote bar and toasts; also hides nameplates and
-- unit names via CVars (old values saved and restored on exit, even after /reload).
-- Toggle: mask button on the emote bar, /rp, or a key binding. Entering combat ends it at once.
-- UIParent goes to alpha 0 and kept frames use SetIgnoreParentAlpha - nothing is hidden or
-- reparented, so no taint and it works in combat lockdown. Invisible bars remain clickable.
local _, ns = ...
local L = ns.L

local FADE = 0.3

local active = false
local alpha = 1      -- current UI alpha (1 -> 0 when enabling)
local kept = {}      -- frame -> previous IgnoreParentAlpha value
local fader

-- Base alpha used by the AFK screen
function ns.RPModeAlpha() return alpha end
function ns.RPModeActive() return active end

-- Nameplate and unit name CVars (only those the client has are touched)
local NAME_CVARS = {
    "nameplateShowEnemies", "nameplateShowFriendlyPlayers", "nameplateShowFriendlyNpcs",
    "UnitNameOwn", "UnitNameNPC", "UnitNameInteractiveNPC", "UnitNameHostleNPC",
    "UnitNameFriendlySpecialNPCName", "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName",
    "UnitNameFriendlyMinionName", "UnitNameEnemyMinionName", "UnitNamePlayerGuild", "UnitNamePlayerPVPTitle",
}

local function HideNames()
    if ns.char.rpCVars then return end
    local saved = {}
    for _, name in ipairs(NAME_CVARS) do
        local value = C_CVar.GetCVar(name)
        if value ~= nil then
            saved[name] = value
            C_CVar.SetCVar(name, "0")
        end
    end
    ns.char.rpCVars = saved -- persisted in case of a reload during RP mode
end

local function RestoreNames()
    local saved = ns.char and ns.char.rpCVars
    if not saved then return end
    for name, value in pairs(saved) do C_CVar.SetCVar(name, value) end
    ns.char.rpCVars = nil
end

-- Frames that stay visible in RP mode
local function KeepList()
    local list = {}
    local function Add(frame) if frame and frame.SetIgnoreParentAlpha then list[#list + 1] = frame end end
    local count = Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        Add(_G["ChatFrame" .. i])
        Add(_G["ChatFrame" .. i .. "Tab"])
        Add(_G["ChatFrame" .. i .. "EditBox"])
    end
    for _, name in ipairs(CHAT_FRAMES or {}) do -- whisper windows etc.
        Add(_G[name]); Add(_G[name .. "Tab"]); Add(_G[name .. "EditBox"])
    end
    Add(GeneralDockManager)
    Add(MeredanUIChatAnchor)
    Add(MeredanUIEmoteBar)
    Add(MeredanUIToasts)
    Add(GameTooltip)
    Add(ItemRefTooltip)
    for i = 1, 4 do Add(_G["StaticPopup" .. i]) end
    return list
end

local function Keep()
    for _, frame in ipairs(KeepList()) do
        if kept[frame] == nil then
            kept[frame] = frame:IsIgnoringParentAlpha() and true or false
            frame:SetIgnoreParentAlpha(true)
        end
    end
end

local function Release()
    for frame, old in pairs(kept) do frame:SetIgnoreParentAlpha(old) end
    wipe(kept)
end

-- The minimap's player arrow, quest arrows and blips ignore alpha, so the (unprotected) MUI
-- minimap holder is actually hidden in RP mode
local minimapWasShown
local function HideMinimap()
    local holder = MeredanUIMinimap or MinimapCluster
    if holder and minimapWasShown == nil then
        minimapWasShown = holder:IsShown()
        holder:Hide()
    end
end
local function ShowMinimap()
    local holder = MeredanUIMinimap or MinimapCluster
    if holder and minimapWasShown then holder:Show() end
    minimapWasShown = nil
end

local function Apply()
    UIParent:SetAlpha(alpha)
    if active and alpha <= 0 then HideMinimap() end
    if not active and alpha >= 1 then Release() end
end

local function OnUpdate(_, elapsed)
    local goal = active and 0 or 1
    local step = elapsed / FADE
    alpha = goal < alpha and math.max(goal, alpha - step) or math.min(goal, alpha + step)
    Apply()
    if alpha == goal then fader:SetScript("OnUpdate", nil) end
end

local function UpdateButton()
    local button = ns.rpButton
    if button and button.UpdateColor then button.UpdateColor() end
end

function ns.SetRPMode(on)
    on = on and true or false
    if on == active then return end
    if on and InCombatLockdown() then
        ns.Print(L["Not possible in combat."])
        return
    end
    active = on
    if active then Keep(); HideNames() else RestoreNames(); ShowMinimap() end
    fader:SetScript("OnUpdate", OnUpdate)
    UpdateButton()
    if ns.UpdateEmoteBar then ns.UpdateEmoteBar() end -- emote bar is always shown in RP mode
end

function ns.ToggleRPMode() ns.SetRPMode(not active) end

-- Key bindings (Bindings.xml)
BINDING_HEADER_MEREDANUI = "MeredanUI"
BINDING_NAME_MEREDANUI_RPMODE = L["Toggle RP mode"]
_G["BINDING_NAME_CLICK MeredanUIQuestItem1:LeftButton"] = L["Use quest item"] -- Quests/Tracker.lua
function MeredanUI_ToggleRPMode() ns.ToggleRPMode() end

SLASH_MEREDANUIRP1 = "/rp"
SlashCmdList.MEREDANUIRP = function() ns.ToggleRPMode() end
ns.AddCommand("rp", nil, function() ns.ToggleRPMode() end)

fader = CreateFrame("Frame")

-- Combat: restore everything immediately
ns:On("PLAYER_REGEN_DISABLED", function()
    if not active then return end
    active = false
    alpha = 1
    Apply()
    RestoreNames() -- before lockdown: nameplate CVars are locked in combat
    ShowMinimap()
    fader:SetScript("OnUpdate", nil)
    UpdateButton()
    if ns.UpdateEmoteBar then ns.UpdateEmoteBar() end
    if ns.AddToast then
        ns.AddToast({ title = L["RP mode"], text = L["Ended – you are in combat."], icon = ns.MEDIA .. "Icons\\RPMode",
            color = { 1, 0.25, 0.25 } })
    end
end)

-- Restore names after a /reload or crash during RP mode
ns:On("PLAYER_LOGIN", function() C_Timer.After(1, function() ns.AfterCombat(RestoreNames) end) end)
