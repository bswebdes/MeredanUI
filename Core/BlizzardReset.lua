-- "Back to Blizzard": before uninstalling mUI. Game settings mUI changes (CVars) go back to Blizzard's
-- defaults and the chat windows to Blizzard's layout; then mUI is disabled and the UI reloads. Everything
-- else mUI does (hidden Blizzard frames, own windows) disappears with the addon anyway.
local _, ns = ...
local L = ns.L

local CVARS = {
    -- nameplates and names
    "nameplateShowAll", "nameplateShowFriendlyNpcs", "nameplateShowFriendlyPlayers", "nameplateShowFriendlyPlayerPets",
    "nameplateSelectedScale", "nameplateMinScale", "nameplateMaxScale",
    "UnitNameNPC", "UnitNameFriendlySpecialNPCName", "UnitNameInteractiveNPC", "UnitNameFriendlyPetName",
    "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName", "UnitNameHostleNPC",
    "UnitNameFriendlyMinionName", "UnitNameEnemyMinionName", "UnitNamePlayerGuild", "UnitNamePlayerPVPTitle",
    -- sparkle (soft targeting)
    "softTargetInteract", "SoftTargetIconGameObject", "SoftTargetNameplateInteract", "SoftTargetInteractRange",
    -- chat, combat, misc
    "showTimestamps", "chatStyle", "enableMouseoverCast", "countdownForCooldowns", "autoQuestWatch",
    "encounterTimelineEnabled", "encounterWarningsEnabled", "damageMeterEnabled", "cameraDistanceMaxZoomFactor",
    "alwaysCompareItems",
}

local function ResetToBlizzard()
    if InCombatLockdown() then
        ns.Print(L["Not possible in combat."])
        return
    end
    for _, cvar in ipairs(CVARS) do
        local default = C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(cvar)
        if default and C_CVar.GetCVar(cvar) ~= nil then pcall(C_CVar.SetCVar, cvar, default) end
    end
    if FCF_ResetChatWindows then pcall(FCF_ResetChatWindows) end
    C_AddOns.DisableAddOn("MeredanUI")
    ReloadUI()
end

StaticPopupDialogs["MEREDANUI_BACK_TO_BLIZZARD"] = {
    text = L["Reset chat and all game settings mUI changed to Blizzard's defaults, turn mUI off and reload?\n\nYour mUI settings stay saved - turn mUI back on in the addon list any time."],
    button1 = YES, button2 = NO,
    OnAccept = ResetToBlizzard,
    showAlert = 1, timeout = 0, hideOnEscape = 1, whileDead = 1,
}

function ns.ConfirmBackToBlizzard() StaticPopup_Show("MEREDANUI_BACK_TO_BLIZZARD") end
