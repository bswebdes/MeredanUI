-- RP-Modus: blendet die ganze Oberfläche weich aus – übrig bleiben Chat, Emote-Leiste und Toasts.
-- Auf Wunsch (Standard) auch Namensplaketten und Namen über den Köpfen (per CVars, die alten
-- Werte werden gemerkt und beim Beenden – auch nach /reload – zurückgesetzt).
--
--   An/aus: Masken-Knopf am Ende der Emote-Leiste · /rp · eigene Taste (Tastenbelegung > MeredanUI)
--   Kampf beendet den Modus sofort (Toast), damit du nie ohne Leisten kämpfst.
--
-- Technik: UIParent auf Alpha 0 (wie der AFK-Bildschirm); was sichtbar bleiben soll, ignoriert
-- für die Zeit die Eltern-Transparenz (SetIgnoreParentAlpha). Nichts wird versteckt oder
-- umgehängt > kein Taint, geht auch mit Kampfsperre. Unsichtbare Leisten bleiben klickbar.
local _, ns = ...
local L = ns.L

local FADE = 0.3

local active = false
local alpha = 1      -- aktuelle UI-Deckkraft (1 > 0 beim Einschalten)
local kept = {}      -- frame > vorheriger IgnoreParentAlpha-Wert
local fader

-- Deckkraft, die der AFK-Bildschirm als Basis nimmt
function ns.RPModeAlpha() return alpha end
function ns.RPModeActive() return active end

-- Namensplaketten und Namen über den Köpfen (nur, was es im Client gibt)
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
    ns.char.rpCVars = saved -- gemerkt, falls mitten im RP-Modus neu geladen wird
end

local function RestoreNames()
    local saved = ns.char and ns.char.rpCVars
    if not saved then return end
    for name, value in pairs(saved) do C_CVar.SetCVar(name, value) end
    ns.char.rpCVars = nil
end

-- alles, was im RP-Modus sichtbar bleibt
local function KeepList()
    local list = {}
    local function Add(frame) if frame and frame.SetIgnoreParentAlpha then list[#list + 1] = frame end end
    local count = Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        Add(_G["ChatFrame" .. i])
        Add(_G["ChatFrame" .. i .. "Tab"])
        Add(_G["ChatFrame" .. i .. "EditBox"])
    end
    for _, name in ipairs(CHAT_FRAMES or {}) do -- Flüsterfenster u. ä.
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

-- Minimap: Spielerpfeil, Quest-Pfeile und Punkte zeichnet das Spiel ohne Transparenz →
-- die Minimap (MUI-Halter, nicht geschützt) wird im RP-Modus richtig versteckt
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
    if ns.UpdateEmoteBar then ns.UpdateEmoteBar() end -- Emote-Leiste ist im RP-Modus immer da
end

function ns.ToggleRPMode() ns.SetRPMode(not active) end

-- Tastenbelegung (Bindings.xml)
BINDING_HEADER_MEREDANUI = "MeredanUI"
BINDING_NAME_MEREDANUI_RPMODE = L["Toggle RP mode"]
_G["BINDING_NAME_CLICK MeredanUIQuestItem1:LeftButton"] = L["Use quest item"] -- Quests/Tracker.lua
function MeredanUI_ToggleRPMode() ns.ToggleRPMode() end

SLASH_MEREDANUIRP1 = "/rp"
SlashCmdList.MEREDANUIRP = function() ns.ToggleRPMode() end
ns.AddCommand("rp", L["toggle RP mode (only chat and emotes)"], function() ns.ToggleRPMode() end)

fader = CreateFrame("Frame")

-- Kampf: sofort alles zurück
ns:On("PLAYER_REGEN_DISABLED", function()
    if not active then return end
    active = false
    alpha = 1
    Apply()
    RestoreNames() -- vor der Kampfsperre: Plaketten-CVars sind im Kampf gesperrt
    ShowMinimap()
    fader:SetScript("OnUpdate", nil)
    UpdateButton()
    if ns.UpdateEmoteBar then ns.UpdateEmoteBar() end
    if ns.AddToast then
        ns.AddToast({ title = L["RP mode"], text = L["Ended – you are in combat."], icon = ns.MEDIA .. "Icons\\RPMode",
            color = { 1, 0.25, 0.25 } })
    end
end)

-- /reload oder Absturz mitten im RP-Modus: Namen wieder herstellen
ns:On("PLAYER_LOGIN", function() C_Timer.After(1, function() ns.AfterCombat(RestoreNames) end) end)
