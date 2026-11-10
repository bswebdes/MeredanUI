-- Questie integration (optional). Every access to Questie goes through this file: Questie has almost
-- no public API, so internals are read defensively (pcall + function checks). If Questie is missing or
-- changes, the bridge simply reports "not ready" and mUI behaves exactly as without it.
--
--   1. Tracker conflict: Questie brings its own tracker; mUI's Forever tracker stays the only one,
--      Questie's is switched off silently.
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

-- mUI's tracker is the only tracker (it shows Questie's info itself), no question asked: Questie's
-- tracker option is switched off (applies from the next load) and its frame is kept hidden right away.
local function HideQuestieTracker()
    local frame = G("Questie_BaseFrame")
    if not frame or frame.mUIHidden then return end
    frame.mUIHidden = true
    frame:Hide()
    hooksecurefunc(frame, "Show", function(self) self:Hide() end)
end

local function CheckTrackerConflict()
    if not ns.IS_FOREVER then return end
    local profile = Profile()
    if profile and profile.trackerEnabled then profile.trackerEnabled = false end
    HideQuestieTracker()
    -- Questie builds its tracker frame a bit after it is ready
    C_Timer.After(2, HideQuestieTracker)
    C_Timer.After(10, HideQuestieTracker)
end

-- 2. Map ----------------------------------------------------------------------------------------
-- Questie draws its world map icons through its own copy of HereBeDragons-Pins, whose data provider is
-- hard-wired to WorldMapFrame. mUI's map is its own MapCanvas (MeredanUIMapCanvas), so the provider is
-- moved over: removed from WorldMapFrame, a pin pool created on our canvas, provider added there.
-- Questie's icons, tooltips, clicks and scaling then work on our map. Its NPC path lines (drawn on
-- WorldMapFrame directly) are not moved.
local PIN_TEMPLATE = "HereBeDragonsPinsTemplateQuestie"
local mapCanvas

-- Questie's own icon click only acts on Blizzard's WorldMapFrame (and Shift/Ctrl). On mUI's map a plain
-- left click makes the quest the active one in mUI's tracker (direction arrow), or - for a quest not yet
-- accepted - puts Blizzard's map pin on the quest giver. Added after Questie's handler, never instead.
local hookedIcons = setmetatable({}, { __mode = "k" })
local function OnIconClick(icon, button)
    if button ~= "LeftButton" or IsModifierKeyDown() then return end
    local data = icon.data
    local questID = data and tonumber(data.Id)
    if not questID then return end
    if C_QuestLog.GetLogIndexForQuestID(questID) then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
        PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    elseif icon.UiMapID and icon.x and icon.y then
        local title = C_QuestLog.GetTitleForQuestID(questID) or data.Name
        if Bridge.SetWaypoint({ name = title, uiMapID = icon.UiMapID, x = icon.x, y = icon.y }) then
            PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end
end

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
            Mixin(frame, pinMixin)
            -- our pin frame: wrap OnAcquired to hook each Questie icon it carries (once per icon)
            local acquired = frame.OnAcquired
            frame.OnAcquired = function(pin, icon, ...)
                acquired(pin, icon, ...)
                if icon and not hookedIcons[icon] and icon.HookScript then
                    hookedIcons[icon] = true
                    icon:HookScript("OnClick", OnIconClick)
                end
            end
            return frame
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

-- "Hold Shift" (detailed icon tooltip): Questie redraws it on Shift only over Blizzard's WorldMapFrame;
-- do the same over mUI's map with Questie's own rebuild function
local shiftWatch = CreateFrame("Frame")
shiftWatch:SetScript("OnEvent", function(_, _, key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    if not (mapCanvas and mapCanvas:IsVisible() and mapCanvas:IsMouseOver()) then return end
    local tip = GameTooltip
    if not (tip and tip:IsShown() and type(tip._Rebuild) == "function") then return end
    tip:Hide()
    tip:ClearLines()
    tip:SetOwner(tip._owner or mapCanvas, "ANCHOR_CURSOR")
    pcall(tip._Rebuild, tip)
    tip:SetFrameStrata("TOOLTIP")
    tip:Show()
end)

-- Called by Map/WorldMap.lua once its canvas exists
function Bridge.AttachMap(canvas)
    mapCanvas = canvas
    shiftWatch:RegisterEvent("MODIFIER_STATE_CHANGED")
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

-- 3. Tracker data -------------------------------------------------------------------------------
-- Read-only lookups for Quests/Tracker.lua. Distances are world yards (HereBeDragons); Questie adds
-- 500000 for targets on another continent/instance, those only report their zone.
local FAR = 500000
local nearestCache = {} -- questID -> { time, result }
local turnInCache = {}  -- questID -> { name, zone } or false; cleared on Questie's quest updates
local NEAREST_TTL = 2   -- >= the tracker's per-row refresh, so a refresh never recomputes twice

local function Quest(questID)
    local db = Module("QuestieDB")
    if not (ready and db and type(db.GetQuest) == "function") then return nil end
    local ok, quest = pcall(db.GetQuest, questID)
    return ok and type(quest) == "table" and quest or nil
end

local function ZoneName(areaID)
    local utils = Module("TrackerUtils")
    if utils and type(utils.GetZoneNameByID) == "function" then
        local ok, name = pcall(utils.GetZoneNameByID, utils, areaID)
        if ok and type(name) == "string" then return name end
    end
    return C_Map.GetAreaInfo(areaID)
end

local function UiMapID(areaID)
    local zones = Module("ZoneDB")
    if not (zones and type(zones.GetUiMapIdByAreaId) == "function") then return nil end
    local ok, id = pcall(zones.GetUiMapIdByAreaId, zones, areaID)
    return ok and id or nil
end

-- Nearest objective (or turn-in once complete): { name, zone, uiMapID, x, y (0-100), yards } or nil.
-- yards is nil when the target is on another continent/instance. Cached for a second.
function Bridge.Nearest(questID)
    local now = GetTime()
    local cached = nearestCache[questID]
    if cached and now - cached[1] < NEAREST_TTL then return cached[2] end
    local result
    local quest = Quest(questID)
    local distance = Module("DistanceUtils")
    if quest and distance and type(distance.GetNearestSpawnForQuest) == "function" then
        local ok, spawn, areaID, name, yards = pcall(distance.GetNearestSpawnForQuest, quest)
        if ok and type(spawn) == "table" and areaID and type(yards) == "number" and yards < 999999999 then
            result = { name = name, zone = ZoneName(areaID), uiMapID = UiMapID(areaID), x = spawn[1], y = spawn[2],
                yards = yards < FAR and yards or nil }
        end
    end
    if cached then
        cached[1], cached[2] = now, result
    else
        nearestCache[questID] = { now, result }
    end
    return result
end

-- Turn-in NPC/object: name, zone name (nearest friendly finisher) or nil
local function ScanTurnIn(questID)
    local quest = Quest(questID)
    local distance = Module("DistanceUtils")
    if not (quest and quest.Finisher and distance and type(distance.GetNearestFinisherOrStarter) == "function") then return nil end
    local ok, _, areaID, name = pcall(distance.GetNearestFinisherOrStarter, quest.Finisher)
    if not (ok and name) then return nil end
    return name, areaID and ZoneName(areaID) or nil
end

-- Cached per quest: the tracker asks on every rebuild for each finished quest. "Nearest" finisher
-- depends on where you are, so a zone change clears it.
ns:On("ZONE_CHANGED_NEW_AREA", function() wipe(turnInCache) end)
function Bridge.TurnIn(questID)
    local cached = turnInCache[questID]
    if cached == nil then
        local name, zone = ScanTurnIn(questID)
        cached = name and { name, zone } or false
        turnInCache[questID] = cached
    end
    if cached then return cached[1], cached[2] end
    return nil
end

-- Usable quest item IDs from Questie's database (the quest log's special item comes first if owned)
function Bridge.QuestItems(questID, complete)
    local quest = Quest(questID)
    local utils = Module("TrackerUtils")
    if not (quest and utils and type(utils.GetQuestItemIds) == "function") then return nil end
    local ok, ids = pcall(utils.GetQuestItemIds, quest, complete and 1 or 0)
    return ok and type(ids) == "table" and ids or nil
end

-- Objectives with map locations: { { index, text, name, zone, uiMapID, x, y, yards } } (nearest spawn each)
function Bridge.Objectives(questID)
    local quest = Quest(questID)
    local distance = Module("DistanceUtils")
    local list = {}
    if not (quest and type(quest.Objectives) == "table" and distance and type(distance.GetNearestObjective) == "function") then
        return list
    end
    for index, objective in pairs(quest.Objectives) do
        if type(objective) == "table" and objective.spawnList then
            local ok, spawn, areaID, name, yards = pcall(distance.GetNearestObjective, objective.spawnList)
            if ok and type(spawn) == "table" and areaID then
                list[#list + 1] = { index = index, text = objective.Description or name, name = name or objective.Description,
                    zone = ZoneName(areaID), uiMapID = UiMapID(areaID), x = spawn[1], y = spawn[2],
                    yards = type(yards) == "number" and yards < FAR and yards or nil }
            end
        end
    end
    table.sort(list, function(a, b) return a.index < b.index end)
    return list
end

-- Opens mUI's map on the target's zone and flashes the quest's icons (or one objective's)
function Bridge.ShowOnMap(questID, objectiveIndex)
    local quest = Quest(questID)
    local target
    if objectiveIndex then
        for _, o in ipairs(Bridge.Objectives(questID)) do
            if o.index == objectiveIndex then target = o end
        end
    else
        target = Bridge.Nearest(questID)
    end
    if not (quest and target and target.uiMapID and ns.OpenWorldMap) then return false end
    ns.OpenWorldMap(target.uiMapID)
    local utils = Module("TrackerUtils")
    -- after the map has placed its pins
    C_Timer.After(0.1, function()
        if not utils then return end
        if objectiveIndex and type(utils.FlashObjective) == "function" and quest.Objectives[objectiveIndex] then
            pcall(utils.FlashObjective, utils, quest.Objectives[objectiveIndex])
        elseif type(utils.FlashFinisher) == "function" then
            pcall(utils.FlashFinisher, utils, quest)
        end
    end)
    return true
end

-- Questie's map focus: only this quest's icons stay bright
function Bridge.IsFocused(questID)
    local q = G("Questie")
    return q and q.db and q.db.char and q.db.char.TrackerFocus == questID or false
end

function Bridge.ToggleFocus(questID)
    local utils, questMod = Module("TrackerUtils"), Module("QuestieQuest")
    if not (utils and questMod and type(questMod.ToggleQuestNotes) == "function") then return end
    if Bridge.IsFocused(questID) then
        if type(utils.UnFocus) == "function" and pcall(utils.UnFocus, utils) then pcall(questMod.ToggleQuestNotes, true) end
    elseif type(utils.FocusQuest) == "function" then
        local ok, done = pcall(utils.FocusQuest, utils, questID)
        if ok and done then pcall(questMod.ToggleQuestNotes, false) end
    end
end

-- Hide / show one quest's map icons (saved by Questie per character)
function Bridge.IconsHidden(questID)
    local q = G("Questie")
    return q and q.db and q.db.char and q.db.char.TrackerHiddenQuests and q.db.char.TrackerHiddenQuests[questID] and true or false
end

function Bridge.ToggleQuestIcons(questID)
    local q, quest, questMod = G("Questie"), Quest(questID), Module("QuestieQuest")
    if not (q and q.db and q.db.char and q.db.char.TrackerHiddenQuests and quest and questMod
        and type(questMod.ToggleQuestNotes) == "function") then return end
    local hide = not Bridge.IconsHidden(questID)
    quest.HideIcons = hide or nil
    q.db.char.TrackerHiddenQuests[questID] = hide or nil
    pcall(questMod.ToggleQuestNotes, not hide)
end

-- Waypoint to a target ({ name, uiMapID, x, y (0-100) }): TomTom if loaded, else Blizzard's map pin
local tomWaypoint
function Bridge.SetWaypoint(target)
    if not (target and target.uiMapID and target.x and target.y) then return false end
    local tom = G("TomTom")
    if type(tom) == "table" and type(tom.AddWaypoint) == "function" then
        if tomWaypoint and type(tom.RemoveWaypoint) == "function" then pcall(tom.RemoveWaypoint, tom, tomWaypoint) end
        local ok, uid = pcall(tom.AddWaypoint, tom, target.uiMapID, target.x / 100, target.y / 100,
            { title = target.name, crazy = true, from = "MeredanUI" })
        if ok then tomWaypoint = uid end
        return ok
    end
    if not (C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(target.uiMapID)) then return false end
    C_Map.SetUserWaypoint({ uiMapID = target.uiMapID, position = CreateVector2D(target.x / 100, target.y / 100) })
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    return true
end

-- fn() after Questie's own quest updates (objective progress, accept, turn-in)
function Bridge.OnQuestUpdate(fn)
    Bridge.OnReady(function()
        local api = G("Questie").API
        if type(api.RegisterForQuestUpdates) == "function" then
            api.RegisterForQuestUpdates(function() wipe(nearestCache); wipe(turnInCache); fn() end)
        end
        fn()
    end)
end

-- Direction to a target from the player, relative to the facing (radians, 0 = straight ahead,
-- counter-clockwise) or nil (no position in instances, facing restricted, other continent)
function Bridge.Direction(target)
    local hbd = LibStub and LibStub("HereBeDragonsQuestie-2.0", true)
    if not (hbd and target and target.uiMapID and target.yards) then return nil end
    local px, py, instance = hbd:GetPlayerWorldPosition()
    if issecretvalue(px) or issecretvalue(py) or not (px and py) then return nil end
    local tx, ty, tInstance = hbd:GetWorldCoordinatesFromZone(target.x / 100, target.y / 100, target.uiMapID)
    if not tx or instance ~= tInstance then return nil end
    local angle = hbd:GetWorldVector(instance, px, py, tx, ty)
    local facing = GetPlayerFacing()
    if issecretvalue(facing) or not (angle and facing) then return nil end
    return angle - facing
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
