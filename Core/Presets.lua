-- "Classic" and "Comfort" styles: only initial values the setup wizard applies once. Every feature
-- stays freely toggleable afterwards - never tie a feature to the style.
-- Dotted keys ("xpBar.mode") address one level deeper.
local _, ns = ...
local L = ns.L

ns.STYLES = {
    { id = "classic", name = L["Classic"], desc = L["Lean, close to the vanilla feeling. Just what you need."] },
    { id = "comfort", name = L["Comfort"], desc = L["The full mUI with all helpers."] },
}

-- Shared by both styles
local COMMON = {
    fontSize = "medium", fontEverywhere = true, nameFormat = "first",
    frameSize = "medium", bossSize = "medium",
    groupFrames = true, groupSolo = false, autoInvite = false,
    nameplates = true, plateClassification = true,
    auraSize = "medium",
    tooltipAnchor = "corner", tooltipHideInCombat = false, tooltipIDs = false, tooltipTarget = true,
    ["actionBars.bar1"] = "always", ["actionBars.bar2"] = "always", ["actionBars.bar3"] = "always",
    ["actionBars.bar4"] = "always", ["actionBars.bar5"] = "always", ["actionBars.petbar"] = "always",
    ["actionBars.stancebar"] = "always",
    addonBar = "mouseover",
    ["xpBar.mode"] = "always",
    chatFontSize = "medium", chatShortChannels = true, chatTimestamps = false, chatMentionSound = false,
    emoteBar = "hidden",
    toasts = true, durabilityWarning = true, hideTalkingHead = false,
    bags = true, protectTools = true, lootWindow = true, lootRolls = true, autoBuy = false, fishingBag = true,
    damageMeterFade = true, damageMeterSecond = false,
}

local STYLE_VALUES = {
    classic = {
        theme = "green", afkScreen = false, auraTime = "below",
        castbar = "simple", executeLine = false, ammoCounter = false, swingTimer = false, petHelper = false,
        threatBar = "hidden",
        autoRole = false, readyCheckReminder = false,
        tooltipAuraSource = false, tooltipItemLevel = false, characterItemLevels = false, upgrades = "off", emptySlots = false, mapReveal = false, mapZoneLevels = false,
        barVariant = "stacked", spellRanks = false, microMenu = "always", mouseoverHeal = false,
        minimapExtras = "always", ["xpBar.quests"] = "none", flightTimer = false, ["infoBar.mode"] = "hidden",
        chatEmoji = false, chatReputation = false, chatBubbles = false, lfgHighlight = false,
        trainerReminder = false, professionReminder = false, toastsGroupLoot = false, combatAlert = false,
        hideErrors = false,
        bagsStyle = "single", bagsAutoJunk = false, fastLoot = false,
        damageMeter = false,
    },
    comfort = {
        theme = "class", afkScreen = true, auraTime = "bar",
        castbar = "full", executeLine = true, ammoCounter = true, swingTimer = true, petHelper = true,
        threatBar = "group",
        autoRole = true, readyCheckReminder = true,
        tooltipAuraSource = true, tooltipItemLevel = true, characterItemLevels = true, upgrades = "damage", emptySlots = true, mapReveal = true, mapZoneLevels = true,
        barVariant = "center", spellRanks = true, microMenu = "mouseover", mouseoverHeal = true,
        minimapExtras = "mouseover", ["xpBar.quests"] = "all", flightTimer = true, ["infoBar.mode"] = "always",
        chatEmoji = true, chatReputation = true, chatBubbles = true, lfgHighlight = true,
        trainerReminder = true, professionReminder = true, toastsGroupLoot = true, combatAlert = true,
        hideErrors = true,
        bagsStyle = "categories", bagsAutoJunk = true, fastLoot = true,
        damageMeter = true,
    },
}

local function Set(db, path, value)
    local parent, key = path:match("^(%w+)%.(%w+)$")
    if parent then
        db[parent] = type(db[parent]) == "table" and db[parent] or {}
        db[parent][key] = value
    else
        db[path] = value
    end
end

-- Write a style's initial values into the active profile (fully applied after reload).
function ns.ApplyStylePreset(style)
    local values = STYLE_VALUES[style]
    if not values then return end
    for path, value in pairs(COMMON) do Set(ns.db, path, value) end
    for path, value in pairs(values) do Set(ns.db, path, value) end
    ns.db.style = style
end

-- Value a style uses for a setting (e.g. for wizard preselection)
function ns.StyleDefault(style, path)
    local values = STYLE_VALUES[style]
    if values and values[path] ~= nil then return values[path] end
    return COMMON[path]
end
