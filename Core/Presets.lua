-- Stile „Klassisch“ und „Komfort“ (Benny 2026-11-07): NUR Startwerte, die der Assistent einmal
-- setzt. Danach lässt sich jede Funktion frei an- oder ausschalten – nie eine Funktion an den Stil
-- koppeln. Werte aus der abgestimmten Einstellungs-Tabelle (Artefakt „mUI Einstellungs-Inventur“).
-- Schlüssel mit Punkt („xpBar.mode“) gehen eine Ebene tiefer.
local _, ns = ...
local L = ns.L

-- Namen an EINER Stelle (Locales), Umbenennen = eine Zeile
ns.STYLES = {
    { id = "classic", name = L["Classic"], desc = L["Lean, close to the vanilla feeling. Just what you need."] },
    { id = "comfort", name = L["Comfort"], desc = L["The full mUI with all helpers."] },
}

-- gleich in beiden Stilen
local COMMON = {
    fontSize = "medium", fontEverywhere = true, nameFormat = "first",
    frameSize = "medium", bossSize = "medium",
    groupFrames = true, groupSolo = false, autoInvite = false,
    nameplates = true, plateClassification = true,
    auraSize = "medium", auraTime = "below",
    tooltipAnchor = "corner", tooltipHideInCombat = false, tooltipIDs = false, tooltipTarget = true,
    ["actionBars.bar1"] = "always", ["actionBars.bar2"] = "always", ["actionBars.bar3"] = "always",
    ["actionBars.bar4"] = "always", ["actionBars.bar5"] = "always", ["actionBars.petbar"] = "always",
    ["actionBars.stancebar"] = "always",
    addonBar = "mouseover",
    ["xpBar.mode"] = "always",
    chatFontSize = "medium", chatShortChannels = true, chatTimestamps = false, chatMentionSound = false,
    emoteBar = "hidden",
    toasts = true, durabilityWarning = true, hideTalkingHead = false,
    bags = true, protectTools = true, lootWindow = true, lootRolls = true, autoBuy = false,
    damageMeterFade = true, damageMeterSecond = false,
}

local STYLE_VALUES = {
    classic = {
        theme = "green", afkScreen = false,
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
        theme = "class", afkScreen = true,
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

-- Startwerte eines Stils ins aktive Profil schreiben (greift vollständig nach dem Neuladen).
-- Eigene Fenster bleiben alle an (gehören zum Look).
function ns.ApplyStylePreset(style)
    local values = STYLE_VALUES[style]
    if not values then return end
    for path, value in pairs(COMMON) do Set(ns.db, path, value) end
    for path, value in pairs(values) do Set(ns.db, path, value) end
    ns.db.style = style
end

-- Wert, den ein Stil für eine Einstellung vorsieht (z. B. für Vorauswahlen im Assistenten)
function ns.StyleDefault(style, path)
    local values = STYLE_VALUES[style]
    if values and values[path] ~= nil then return values[path] end
    return COMMON[path]
end
