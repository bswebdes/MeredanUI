-- Other addons for the same job as an mUI module. Four areas where the player picks mUI or the
-- other addon; the other addon always wins while it is enabled, so nothing ever shows twice:
--   nameplates  -> mUI nameplates      (ns.db.nameplates)
--   bags        -> mUI bags/bank/guild bank (ns.db.bags)
--   bossmods    -> mUI boss timers     (ns.db.bossMods)
--   meter       -> mUI damage meter    (ns.db.damageMeter)
-- Picking mUI disables the other addon for this character and reloads; picking the addon just
-- remembers the answer (the mUI module is already off). Asked in the setup (step "Other addons") or
-- once in a dialog when a new one shows up. Action bar addons are not supported: one hint only.
-- Detection works at file load already (enable state), not only after the other addon has loaded.
local _, ns = ...
local L = ns.L

ns.OTHER_ADDON_AREAS = {
    { id = "nameplates", key = "nameplates", label = L["Nameplates"],
        addons = { "Plater", "Platynator", "Kui_Nameplates", "TidyPlates_ThreatPlates" } },
    { id = "bags", key = "bags", label = L["Bags & bank"],
        addons = { "Bagnon", "BetterBags", "AdiBags", "ArkInventory", "Baganator" } },
    { id = "bossmods", key = "bossMods", label = L["Boss timers"],
        addons = { "DBM-Core", "BigWigs" } },
    { id = "meter", key = "damageMeter", label = L["Damage meter"],
        addons = { "Details", "Skada", "Recount" } },
}
local BAR_ADDONS = { "Bartender4", "Dominos" }

local AREA_BY_KEY = {}
for _, area in ipairs(ns.OTHER_ADDON_AREAS) do AREA_BY_KEY[area.key] = area end

local function Character() return UnitName("player") end

-- Enabled for this character and able to load (or already loaded)
local function Active(name)
    if not C_AddOns.DoesAddOnExist(name) then return false end
    if C_AddOns.IsAddOnLoaded(name) then return true end
    if C_AddOns.GetAddOnEnableState(name, Character()) == 0 then return false end
    if C_AddOns.IsAddOnLoadOnDemand(name) then return false end
    return (C_AddOns.IsAddOnLoadable(name, Character())) == true
end

local function Title(name)
    local title = C_AddOns.GetAddOnTitle(name)
    title = title and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "") or name
    title = strtrim(title)
    if name == "DBM-Core" then return "DBM" end
    if name == "Kui_Nameplates" then return "KuiNameplates" end
    if name == "TidyPlates_ThreatPlates" then return "Threat Plates" end
    return title ~= "" and title or name
end
ns.OtherAddonTitle = Title

-- First active other addon of an area (folder name) or nil
function ns.OtherAddonFor(areaOrKey)
    local area = AREA_BY_KEY[areaOrKey]
    if not area then
        for _, a in ipairs(ns.OTHER_ADDON_AREAS) do if a.id == areaOrKey then area = a end end
    end
    if not area then return nil end
    for _, name in ipairs(area.addons) do
        if Active(name) then return name end
    end
    return nil
end

-- mUI module for key on? Own switch on and no other addon for the job.
function ns.ModuleOn(key)
    if not ns.db or ns.db[key] == false then return false end
    return AREA_BY_KEY[key] == nil or ns.OtherAddonFor(key) == nil
end

-- Areas with an active other addon: { area, addon } in list order
function ns.OtherAddonsFound()
    local found = {}
    for _, area in ipairs(ns.OTHER_ADDON_AREAS) do
        local name = ns.OtherAddonFor(area.id)
        if name then found[#found + 1] = { area = area, addon = name } end
    end
    return found
end

-- Remember the answer per character and addon (so the dialog asks only once)
local function Remember(name, choice)
    ns.char.otherAddons = ns.char.otherAddons or {}
    ns.char.otherAddons[name] = choice
end

-- choice "mui": disable all other addons of the area for this character (reload needed, returns true)
function ns.ChooseOtherAddon(areaID, choice)
    for _, area in ipairs(ns.OTHER_ADDON_AREAS) do
        if area.id == areaID then
            local changed = false
            for _, name in ipairs(area.addons) do
                if Active(name) then
                    Remember(name, choice)
                    if choice == "mui" then
                        C_AddOns.DisableAddOn(name, Character())
                        changed = true
                    end
                end
            end
            if choice == "mui" and ns.db[area.key] == false then ns.db[area.key] = nil end
            return changed
        end
    end
    return false
end

-- New-addon dialog -------------------------------------------------------------------------------

local queue = {}

StaticPopupDialogs["MEREDANUI_OTHER_ADDON"] = {
    text = "%s",
    button1 = "",   -- set to the addon's name before showing
    button2 = "mUI",
    OnAccept = function(_, data) ns.ChooseOtherAddon(data.area.id, "addon") end,
    OnCancel = function(_, data, reason)
        if reason == "clicked" and ns.ChooseOtherAddon(data.area.id, "mui") then ReloadUI() end
    end,
    OnHide = function() C_Timer.After(0.2, function() if ns.ShowNextOtherAddon then ns.ShowNextOtherAddon() end end) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
}

function ns.ShowNextOtherAddon()
    if InCombatLockdown() then return ns.AfterCombat(ns.ShowNextOtherAddon) end
    local entry = table.remove(queue, 1)
    if not entry then return end
    local text = L["%s found (%s). Use it or mUI?"]:format(Title(entry.addon), entry.area.label)
    StaticPopupDialogs["MEREDANUI_OTHER_ADDON"].button1 = Title(entry.addon)
    StaticPopup_Show("MEREDANUI_OTHER_ADDON", text, nil, entry)
end

-- After the setup only: ask once per newly found addon. Before the setup, its step asks.
ns:On("PLAYER_LOGIN", function()
    C_Timer.After(4, function()
        if not ns.char or not ns.char.setupDone then return end
        local asked = ns.char.otherAddons or {}
        for _, entry in ipairs(ns.OtherAddonsFound()) do
            if not asked[entry.addon] then queue[#queue + 1] = entry end
        end
        -- action bar addons: not supported, one hint per addon
        for _, name in ipairs(BAR_ADDONS) do
            if Active(name) and not asked[name] then
                Remember(name, "hint")
                ns.Print(L["%s is not supported: its bars overlap mUI's action bars."]:format(Title(name)))
            end
        end
        ns.ShowNextOtherAddon()
    end)
end)
