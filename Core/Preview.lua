-- Global preview: one toggle shows all mUI elements at once with sample data (button in the settings
-- window and /mui t). Out of combat only; entering combat ends it.
-- Party and raid can't show together: size is selectable (5 / 25 / 40, Group page).
local _, ns = ...
local L = ns.L

local active = false
local groupKind = "group"

-- Per-module previews (each with Start/Stop/IsActive); missing ones are skipped
local function Parts()
    return {
        ns.ReagentsDemo, ns.AurasDemo, ns.MinimapDemo, ns.FlightTimerDemo, ns.DamageMeterDemo,
        ns.TooltipDemo, ns.ToastsDemo, ns.QueueStatusDemo, ns.ChatDemo, ns.CombatAlertDemo, ns.ShardTransferDemo, ns.ReadyCheckDemo,
        not ns.IS_FOREVER and ns.BossModsDemo or nil, not ns.IS_FOREVER and ns.QuestDemo or nil,
    }
end

local function Start()
    if active then return end
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    active = true
    ns.TestMode.Start(true) -- unit frames, group, threat, swing timer, loot rolls
    if groupKind ~= "group" and ns.GroupDemo then ns.GroupDemo(groupKind) end
    for _, part in pairs(Parts()) do
        if part and part.Start then xpcall(part.Start, geterrorhandler()) end -- report errors, keep starting the rest
    end
    ns.Print(L["Preview on. %s again to end it."], "/mui t")
    if ns.OnPreviewChanged then ns.OnPreviewChanged() end -- settings window button
end

local function Stop()
    if not active or InCombatLockdown() then return end
    active = false
    for _, part in pairs(Parts()) do
        if part and part.Stop and (not part.IsActive or part.IsActive()) then xpcall(part.Stop, geterrorhandler()) end
    end
    if ns.GroupDemoStop then ns.GroupDemoStop() end
    if ns.TestMode.IsActive() then ns.TestMode.Stop(true) end
    ns.Print(L["Preview off."])
    if ns.OnPreviewChanged then ns.OnPreviewChanged() end
end

ns.Preview = {
    Start = Start,
    Stop = Stop,
    IsActive = function() return active end,
    Toggle = function() if active then Stop() else Start() end end,
    -- "group" (5), "raid" (25), "raid40" (40); switches immediately while the preview runs
    GroupKind = function() return groupKind end,
    SetGroupKind = function(kind)
        groupKind = kind
        if active and ns.GroupDemo and not InCombatLockdown() then ns.GroupDemo(kind) end
    end,
}

ns:On("PLAYER_REGEN_DISABLED", function()
    if active then Stop() end
end)
