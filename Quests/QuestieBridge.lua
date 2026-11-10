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

-- 2. Map ----------------------------------------------------------------------------------------
-- Questie draws its world map icons through its own copy of HereBeDragons-Pins, whose data provider is
-- hard-wired to WorldMapFrame. mUI's map is its own MapCanvas (MeredanUIMapCanvas), so the provider is
-- moved over: removed from WorldMapFrame, a pin pool created on our canvas, provider added there.
-- Questie's icons, tooltips, clicks and scaling then work on our map. Its NPC path lines (drawn on
-- WorldMapFrame directly) are not moved.
local PIN_TEMPLATE = "HereBeDragonsPinsTemplateQuestie"
local mapCanvas

local function MoveProvider()
    if not (ready and mapCanvas) then return end
    local pins = LibStub and LibStub("HereBeDragonsQuestie-Pins-2.0", true)
    local provider, pinMixin = pins and pins.worldmapProvider, pins and pins.worldmapProviderPin
    if not (provider and pinMixin and type(provider.GetMap) == "function") then return end
    if provider:GetMap() == mapCanvas then return end
    -- Questie computes icon scale from the provider's map ID on every draw: never hand over a map
    -- without one
    if not mapCanvas:GetMapID() then
        mapCanvas:SetMapID(G("MapUtil").GetDisplayableMapForPlayer())
        if not mapCanvas:GetMapID() then return end
    end
    if not mapCanvas.pinPools[PIN_TEMPLATE] then
        local function create()
            local frame = CreateFrame("Frame", nil, mapCanvas:GetCanvas())
            frame:SetSize(1, 1)
            return Mixin(frame, pinMixin)
        end
        local function reset(_, pin)
            pin:Hide()
            pin:ClearAllPoints()
            pin:OnReleased()
            pin.pinTemplate = nil
            pin.owningMap = nil
        end
        local pool = G("CreateUnsecuredRegionPoolInstance")(PIN_TEMPLATE, create, reset)
        pool.parent = mapCanvas:GetCanvas()
        mapCanvas.pinPools[PIN_TEMPLATE] = pool
    end
    local ok, err = pcall(function()
        local old = provider:GetMap()
        if old then old:RemoveDataProvider(provider) end
        mapCanvas:AddDataProvider(provider)
        provider.forceUpdate = true
        provider:RefreshAllData()
    end)
    if not ok and DevLog then DevLog("MeredanUI", "Questie map: " .. tostring(err)) end
end

-- Called by Map/WorldMap.lua once its canvas exists
function Bridge.AttachMap(canvas)
    mapCanvas = canvas
    MoveProvider()
    -- if Questie (or a newer copy of its library) registers with WorldMapFrame again: move back
    canvas:HookScript("OnShow", MoveProvider)
end

function Bridge.IconsShown()
    local profile = Profile()
    return profile and profile.enabled ~= false
end

function Bridge.ToggleIcons()
    local profile = Profile()
    local quest = Module("QuestieQuest")
    if not (profile and quest and type(quest.ToggleNotes) == "function") then return end
    profile.enabled = not profile.enabled
    pcall(quest.ToggleNotes, quest, profile.enabled)
    local options = Module("QuestieOptionsEngine")
    if options and type(options.RefreshStates) == "function" then pcall(options.RefreshStates, options) end
end

-- Questie's town folk menu (right-click on its own map button)
function Bridge.ToggleMenu()
    local menu = Module("QuestieMenu")
    if not (menu and type(menu.IsOpen) == "function") then return end
    if menu.IsOpen() then
        if type(menu.Hide) == "function" then pcall(menu.Hide, menu) end
    elseif type(menu.Show) == "function" then
        pcall(menu.Show, menu)
    end
end

-- Setup -------------------------------------------------------------------------------------------

local function OnQuestieReady()
    if ready then return end
    ready = true
    CheckTrackerConflict()
    MoveProvider()
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
