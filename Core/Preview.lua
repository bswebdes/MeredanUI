-- Vorschau für alles (Benny 2026-11-07): EIN Schalter zeigt alle mUI-Teile gleichzeitig mit
-- Beispielwerten – Unitframes (samt Gruppe, Bedrohung, Schlagtimer, Würfeln), Buffs & Debuffs,
-- Minimap, Flugzeit, Klassen-Reagenzien, Schadensanzeige, Tooltip, Meldungen (auch seltene wie
-- Battle.net, Würfelergebnis, Haltbarkeit, Berufe), Kampf-Meldung, Weltaktualisierung und Chat.
-- Knopf oben im Einstellungsfenster und /mui t. Nur außerhalb des Kampfs; Kampfbeginn beendet sie.
-- Gruppe oder Schlachtzug gehen nicht gleichzeitig: Größe wählbar (5 / 25 / 40, Seite Gruppe).
local _, ns = ...
local L = ns.L

local active = false
local groupKind = "group"

-- Einzel-Vorschauen der Module (jede mit Start/Stop/IsActive); was es nicht gibt, fällt weg
local function Parts()
    return {
        ns.ReagentsDemo, ns.AurasDemo, ns.MinimapDemo, ns.FlightTimerDemo, ns.DamageMeterDemo,
        ns.TooltipDemo, ns.ToastsDemo, ns.ChatDemo, ns.CombatAlertDemo, ns.ShardTransferDemo,
        not ns.IS_FOREVER and ns.BossModsDemo or nil, not ns.IS_FOREVER and ns.QuestDemo or nil,
    }
end

local function Start()
    if active then return end
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    active = true
    ns.TestMode.Start(true) -- Unitframes, Gruppe, Bedrohung, Schlagtimer, Würfel
    if groupKind ~= "group" and ns.GroupDemo then ns.GroupDemo(groupKind) end
    for _, part in pairs(Parts()) do
        if part and part.Start then xpcall(part.Start, geterrorhandler()) end -- Fehler sichtbar, Rest läuft weiter
    end
    ns.Print(L["Preview on. %s again to end it."], "/mui t")
    if ns.OnPreviewChanged then ns.OnPreviewChanged() end -- Knopf im Einstellungsfenster
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
    -- "group" (5), "raid" (25), "raid40" (40); läuft die Vorschau, sofort umschalten
    GroupKind = function() return groupKind end,
    SetGroupKind = function(kind)
        groupKind = kind
        if active and ns.GroupDemo and not InCombatLockdown() then ns.GroupDemo(kind) end
    end,
}

ns:On("PLAYER_REGEN_DISABLED", function()
    if active then Stop() end
end)
