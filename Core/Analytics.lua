-- Anonymous usage statistics via Wago Analytics (https://addons.wago.io/docs/analytics).
-- libs/WagoAnalyticsShim does nothing on its own; only players who run the Wago app have the real
-- WagoAnalytics addon, which records and uploads anonymously. It also reports Lua errors from mUI's
-- files automatically (matched by the X-Wago-ID in the TOC), so bugs show up without a report.
-- Here: which style, modules, helpers and other addons are in use - on/off switches, nothing else.
local _, ns = ...

local MODULES = { "groupFrames", "groupManager", "nameplates", "bossMods", "toasts", "damageMeter",
    "bags", "lootWindow", "lootRolls" }
local HELPERS = { "questAutoAccept", "questAutoTurnIn", "questAutoGossip", "questBestReward", "autoSummon",
    "autoResurrect", "declineDuels", "skipCinematics", "buffReminder", "altItemCount", "chatClassIcons",
    "tooltipClassIcon", "classAccent" }

local function Report()
    local lib = LibStub and LibStub("WagoAnalytics", true)
    if not (lib and lib.RegisterAddon and ns.db and ns.char and ns.char.setupDone) then return end
    local wago = lib:RegisterAddon("MeredanUI")
    if not wago then return end
    wago:Switch("Style: " .. (ns.db.style == "comfort" and "Comfort" or "Classic"), true)
    for _, key in ipairs(MODULES) do wago:Switch("Module: " .. key, ns.ModuleOn and ns.ModuleOn(key) or false) end
    for _, key in ipairs(HELPERS) do wago:Switch("Option: " .. key, ns.db[key] == true) end
    for _, entry in ipairs(ns.OtherAddonsFound and ns.OtherAddonsFound() or {}) do
        wago:Switch("Other addon: " .. entry.addon, true)
    end
end

ns:On("PLAYER_LOGIN", function() C_Timer.After(10, Report) end)
