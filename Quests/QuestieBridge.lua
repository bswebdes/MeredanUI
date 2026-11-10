-- Questie integration (optional). Every access to Questie goes through this file: Questie has almost
-- no public API, so internals are read defensively (pcall + function checks). If Questie is missing or
-- changes, the bridge simply reports "not ready" and mUI behaves exactly as without it.
--
--   1. Tracker conflict: Questie brings its own tracker; with mUI's Forever tracker the player would
--      see two. Asked once whether to turn Questie's off (it reloads the UI).
--   2. Map: Questie's HereBeDragons world map provider is moved onto mUI's map canvas (Map/WorldMap.lua).
--   3. Tracker data: turn-in NPC, nearest objective + distance, quest items from Questie's database.
local _, ns = ...
local L = ns.L

local Bridge = {}
ns.Questie = Bridge

-- globals of other addons / SavedVariables: read via _G[...] (not declared for the language server)
local function G(name) return _G[name] end

local ready = false
local readyCallbacks = {}

local function QuestieLoaded()
    return C_AddOns.IsAddOnLoaded("Questie") and type(G("Questie")) == "table" or false
end

function Bridge.IsLoaded() return QuestieLoaded() end
function Bridge.IsReady() return ready end

-- fn runs once Questie is ready (right away if it already is)
function Bridge.OnReady(fn)
    if ready then return pcall(fn) end
    readyCallbacks[#readyCallbacks + 1] = fn
end

-- Questie module or nil. ImportModule creates an empty table for unknown names, so callers must check
-- the functions they use.
local function Module(name)
    local loader = G("QuestieLoader")
    if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return nil end
    local ok, mod = pcall(loader.ImportModule, loader, name)
    return ok and type(mod) == "table" and mod or nil
end
Bridge.Module = Module

local function Profile()
    local q = G("Questie")
    return q and q.db and q.db.profile
end
Bridge.Profile = Profile

-- 1. Tracker conflict --------------------------------------------------------------------------

StaticPopupDialogs["MEREDANUI_QUESTIE_TRACKER"] = {
    text = L["Turn off Questie's tracker? mUI shows Questie's info in its own tracker."],
    button1 = G("YES") or "Yes",
    button2 = G("NO") or "No",
    OnAccept = function()
        G("MeredanUIDB").questieTrackerAsked = true
        ns.AfterCombat(function()
            local tracker = Module("QuestieTracker")
            if tracker and type(tracker.Disable) == "function" then pcall(tracker.Disable, tracker) end -- reloads the UI
        end)
    end,
    OnCancel = function() G("MeredanUIDB").questieTrackerAsked = true end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
}

local function CheckTrackerConflict()
    local db = G("MeredanUIDB")
    if not ns.IS_FOREVER or not db or db.questieTrackerAsked then return end
    local profile = Profile()
    if not (profile and profile.trackerEnabled) then return end
    ns.AfterCombat(function() StaticPopup_Show("MEREDANUI_QUESTIE_TRACKER") end)
end

-- Setup -------------------------------------------------------------------------------------------

local function OnQuestieReady()
    if ready then return end
    ready = true
    CheckTrackerConflict()
    for _, fn in ipairs(readyCallbacks) do
        local ok, err = pcall(fn)
        if not ok and DevLog then DevLog("MeredanUI", "Questie bridge: " .. tostring(err)) end
    end
    wipe(readyCallbacks)
end

ns:On("PLAYER_LOGIN", function()
    if not QuestieLoaded() then return end
    local api = G("Questie").API
    if type(api) == "table" and type(api.RegisterOnReady) == "function" then
        pcall(api.RegisterOnReady, OnQuestieReady)
    end
end)
