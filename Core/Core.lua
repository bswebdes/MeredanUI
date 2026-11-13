-- MeredanUI core: flavor detection, secret-safe helpers, events, SavedVariables, slash commands.
local ADDON_NAME, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
--  Flavor: Retail (Midnight) and WoW Forever share the Mainline API.
--  Forever reports WOW_PROJECT_ID 18 (WOW_PROJECT_CAMELOT). Prefer checking for API
--  existence over branching on the project ID.
-------------------------------------------------------------------------------
ns.IS_FOREVER = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)
ns.IS_RETAIL = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""
ns.VERSION = version:find("^@") and "dev" or version

-------------------------------------------------------------------------------
--  Secret values: ALWAYS test for secrets first - even `v == nil` on a secret
--  throws. Only pass secrets through to Blizzard widgets.
-------------------------------------------------------------------------------
local issecretvalue = issecretvalue or function() return false end
ns.issecretvalue = issecretvalue

-- Value is readable (not a secret, not nil).
function ns.Readable(v)
    return not issecretvalue(v) and v ~= nil
end

-- Value, or nil if secret.
function ns.Plain(v)
    if not issecretvalue(v) then return v end
end

-------------------------------------------------------------------------------
--  Output
-------------------------------------------------------------------------------
-- Chat brand "mUI": "m" light (#e9e6dd), "UI" in Surf Green (#8ecbb4);
-- only the login greeting shows the full name "MeredanUI".
local BRAND_SHORT = "|cffe9e6ddm|r|cff8ecbb4UI|r"
local BRAND_LONG = "|cffe9e6ddMeredan|r|cff8ecbb4UI|r"
local PREFIX = BRAND_SHORT .. ": "

function ns.Print(fmt, ...)
    local text = select("#", ...) > 0 and fmt:format(...) or fmt
    print(PREFIX .. text)
    if DevLog then DevLog(ADDON_NAME, text) end -- dev helper (workspace addon DevLog), no-op otherwise
end

function ns.Debug(fmt, ...)
    if ns.db and ns.db.debug then ns.Print("|cff888888" .. fmt .. "|r", ...) end
end

-------------------------------------------------------------------------------
--  Events: ns:On("EVENT", function(event, ...) end)
-------------------------------------------------------------------------------
local handlers = {}
-- Each handler is isolated: an error goes to the error handler (BugSack) and the remaining
-- handlers still run (otherwise one error breaks the whole login chain).
local SafeCall = securecallfunction or function(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end
local eventFrame = CreateFrame("Frame")
local function Dispatch(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do SafeCall(list[i], event, ...) end
end
eventFrame:SetScript("OnEvent", Dispatch)

-- Measurement (/mui perf, Core/Perf.lua): while a sink is set the dispatcher is swapped for a
-- timed one; otherwise there is no extra cost at all.
local eventSink
local function DispatchTimed(_, event, ...)
    local list = handlers[event]
    if not list then return end
    local start = debugprofilestop()
    for i = 1, #list do SafeCall(list[i], event, ...) end
    eventSink(event, debugprofilestop() - start)
end
function ns.SetEventSink(sink)
    eventSink = sink
    eventFrame:SetScript("OnEvent", sink and DispatchTimed or Dispatch)
end

function ns:On(event, fn)
    if not handlers[event] then
        -- events differ between Retail and Forever: an unknown one would throw and abort the calling file
        if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
            if ns.Debug then ns.Debug("unknown event %s", event) end
            return
        end
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

function ns:Off(event)
    handlers[event] = nil
    eventFrame:UnregisterEvent(event)
end

-- "Quests changed": QUEST_LOG_UPDATE comes in bursts (every kill, loot, objective). Subscribers
-- run once per burst, 0.2 s after the first event.
local questSubscribers, questPending = {}, false
function ns.OnQuestsChanged(fn)
    if #questSubscribers == 0 then
        ns:On("QUEST_LOG_UPDATE", function()
            if questPending then return end
            questPending = true
            C_Timer.After(0.2, function()
                questPending = false
                for i = 1, #questSubscribers do SafeCall(questSubscribers[i]) end
            end)
        end)
    end
    questSubscribers[#questSubscribers + 1] = fn
end

-- Is another addon for the same job loaded? Returns its folder name (first loaded from the
-- list) or nil. Names must match the AddOns folder exactly.
function ns.OtherAddon(names)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    if not loaded then return end
    for _, name in ipairs(names) do
        if loaded(name) then return name end
    end
end

-- Auction house addons: if one is loaded, the mUI auction house stays off entirely (no skin, no hooks).
ns.AUCTION_ADDONS = { "Auctionator", "TradeSkillMaster", "Auc-Advanced", "AuctionFaster", "aux-addon" }
-- Mail addons hook Blizzard's mail frame - ours would cover them
ns.MAIL_ADDONS = { "Postal", "TradeSkillMaster", "MailLogger" }

-- Run outside combat (immediately or on PLAYER_REGEN_ENABLED).
local afterCombat = {}
function ns.AfterCombat(fn)
    if not InCombatLockdown() then return fn() end
    table.insert(afterCombat, fn)
end
ns:On("PLAYER_REGEN_ENABLED", function()
    local queue = afterCombat
    afterCombat = {}
    for i = 1, #queue do queue[i]() end
end)

-------------------------------------------------------------------------------
--  SavedVariables (account-wide) with profiles:
--    MeredanUIDB.profiles[name] = settings (DEFAULTS), ns.db = active profile
--    MeredanUIDB.chars["First Last - Realm"] = { profile, setupDone, specAuto, specProfiles }
--    New characters get their own profile named after them (see ADDON_LOADED).
--    MeredanUIDB.newCharProfile = profile for newly logged-in characters (optional)
--  Missing defaults are filled in on load. Profiles.lua manages profiles. The layout
--  (Core/Layouts.lua) is a per-profile setting: ns.db.layout.
-------------------------------------------------------------------------------
ns.DEFAULT_PROFILE = "Standard"
-- One built-in profile (cannot be deleted/renamed); the role lives in the layout.
ns.BUILTIN_PROFILES = { ns.DEFAULT_PROFILE }
ns.DEFAULT_LAYOUT = "melee" -- melee DPS: base of all layouts

local DEFAULTS = {
    debug = false,
    nameFormat = "first", -- names (Forever: first and last name): "first", "full", "firstInitial", "initialLast", "last"
    panelOpacity = "normal", -- opacity of all mUI backgrounds: "solid", "normal", "light" (Core/Style.lua)
    fontSize = "medium", -- font size of all mUI texts: "small", "medium", "large" (Core/Style.lua)
    layout = "melee", -- Core/Layouts.lua; melee DPS is the base
    theme = "class", -- "class", "dark" or "green"
    minimapExtras = "always", -- texts (zone, clock, coordinates) and icons: "always" or "mouseover"
    frameSize = "medium", -- player + target (pet, target of target, focus scale along): "small", "medium", "large"
    bossSize = "medium",  -- boss frames: "small", "medium", "large"
    chatShortChannels = true, -- shorten channel names in chat ([G], [P], [1] ...)
    bagnonStyle = true,
    detailsStyle = true,
    platerStyle = true,
    dbmStyle = true,
    bigwigsStyle = true,      -- BigWigs bar style and profile in the mUI look (BossMods/BigWigsSkin.lua)          -- DBM profile "MeredanUI" in the mUI look (BossMods/DBMSkin.lua)       -- Plater profile values in the mUI look (NamePlates/PlaterProfile.lua)      -- Details! in the mUI look (DamageMeter/DetailsSkin.lua)       -- Bagnon in the mUI look and spot (Bags/BagnonSkin.lua)
    chatClassIcons = true,    -- class icon before names in guild, group, raid and whispers
    chatTimestamps = true,    -- plain timestamps (12:04) before chat lines
    chatFontSize = "medium",  -- chat font size: "small", "medium", "large" (Chat/ChatStyle.lua)
    chatSize = "medium",      -- main chat window size: "small", "medium", "large" (Chat/ChatStyle.lua)
    chatEmoji = true,         -- smileys and emojis as images in chat
    chatReputation = true,    -- reputation in chat with a bar instead of Blizzard's line
    chatMentionSound = true,  -- sound when your name/nickname is mentioned
    -- Tooltip: position "corner" (bottom right) or "cursor"; player lines individually
    tooltipAnchor = "corner",
    tooltipHideInCombat = false, -- hide in combat (Shift still shows it)
    tooltipItemLevel = true, tooltipMythic = true, tooltipTarget = true,
    tooltipClassIcon = true,     -- class icon in front of the level line
    tooltipClassification = true, -- "Rare" / "Elite" behind NPC names
    classAccent = false,         -- accent in muted class colour instead of Surf Green (reload)
    chatBubbles = true,          -- mUI-styled chat bubbles (Chat/ChatBubbles.lua)
    emoteBar = "hidden",         -- emote bar (Chat/EmoteBar.lua): "always", "mouseover", "hidden"
    emoteBarEmotes = {},         -- [emote] = true/false; missing = default (ns.EMOTE_DEFAULTS)
    tooltipAuraSource = true,    -- buff/debuff tooltip: "From: name"
    tooltipIDs = true,           -- IDs (spells, items, NPCs ...) at the bottom of the tooltip
    mplusChests = true,          -- M+ timer: time left for +3/+2
    mplusForces = "detail",      -- enemy forces: "detail" (percent + count, e.g. 62.47% 287/460) or "percent" (Blizzard)
    mplusSplits = true,          -- boss split times in the objective lines
    mplusMobTooltip = true,      -- enemy forces value of a mob in the tooltip
    mplusAutoKeystone = true,    -- insert keystone automatically at the pedestal
    mplusAutoGossip = true,      -- auto-select the only gossip option in the key dungeon
    mplusGroupKeys = true,       -- group keystones next to the Mythic+ window
    hideErrors = true,           -- red error messages + error speech off (Core/Quiet.lua)
    hideTalkingHead = true,
    combatAlert = true,          -- "+ Combat"/"- Combat" above screen center (Toasts/CombatAlert.lua)
    toastsGroupLoot = true,      -- toasts: roll results and group loot
    spellRanks = true,           -- Forever: arrow + toast for outdated spell ranks on the bars
    trainerReminder = true,      -- Forever: toast on level-up when spells await at the trainer
    lootRolls = true,            -- custom loot roll frames (Loot/LootRoll.lua)
    lootWindow = true,           -- custom loot window (Loot/LootWindow.lua)
    fastLoot = true,             -- loot instantly with auto-loot (Loot/FastLoot.lua)
    fishingBag = true,           -- Forever: fishing bag + logbook, opens with a fishing pole (Loot/Fishing.lua)
    fishingDoubleClick = false,  -- Forever: double right-click casts Fishing (Comfort)
    actionBarArt = true,         -- class animals / gryphons at the bottom action bars (ActionBars/Gryphons.lua)
    sparkle = false,             -- Comfort: glitter on the nearby herb/ore/quest object (Loot/Sparkle.lua)
    sparkleOther = true,         -- sparkle also on other objects (benches, chests, mailboxes) in white
    classQuestReminder = false,  -- Comfort, Forever: toast when a class quest unlocks (Quests/ClassQuestReminder.lua)
    castbar = "full",            -- castbar: "simple" (bar only) or "full" (GCD line + tick marks)
    executeLine = true,          -- execute line in target health bar and on nameplates
    npMuiNames = true,           -- mUI names instead of Blizzard's world names (NamePlates.lua, ns.SetMuiNames)
    npNameSize = "medium",       -- name size on friendly name plates: small 12, medium 14, large 16
    npNpcTitle = true,           -- title under NPC names ("Mining Trainer")
    npPetOwner = true,           -- owner under pets ("Koratal's Pet")
    plateClassification = true,  -- rare/elite icon before the name on nameplates
    autoInvite = false,          -- accept invites from friends/guild (off by default)
    questAutoAccept = false,     -- Comfort: accept available quests (NPC/AutoQuest.lua, Shift pauses)
    questAutoTurnIn = false,     -- Comfort: hand in finished quests (no reward choice, no costs)
    questAutoGossip = false,     -- Comfort: pick the only chat option of an NPC without quests
    autoSummon = false,          -- Comfort: accept summons out of combat after 5 s (Core/Comfort.lua)
    autoResurrect = false,       -- Comfort: accept resurrections unless the caster is in combat
    declineDuels = false,        -- Comfort: decline duels (not from friends/guild)
    skipCinematics = false,      -- Comfort: skip movies/cinematics seen before
    buffReminder = true,         -- Comfort, Forever: missing/outdated class buffs, expired weapon enchant (Toasts/BuffReminder.lua)
    ahTooltipPrice = true,       -- Comfort: cheapest auction price in item tooltips (AuctionHouse/AHScan.lua)
    altItemCount = true,         -- Comfort: item counts of all characters in item tooltips (Tooltip/AltItems.lua)
    questBestReward = true,      -- Comfort: coin on the choice reward with the highest vendor value (NPC/Quest.lua)
    autoRole = true,             -- confirm role check with the spec role
    readyCheckReminder = true,   -- ready check: toast when food/flask/rune is missing
    durabilityWarning = true,    -- toast when an item drops below 20% durability
    achievementScreenshot = true, -- screenshot on new achievements
    characterItemLevels = true,  -- item levels on slots in the character/inspect window
    afkScreen = true,            -- AFK "cinema" screen (AFK/AFK.lua)
    groupManager = true,         -- group bar (replaces Blizzard's raid manager)
    groupFrames = true,          -- mUI group frames (party + raid) instead of Blizzard's
    groupSolo = false, -- show group frames solo too (for testing)
    fontEverywhere = true,       -- mUI font for all game font objects (Core/Fonts.lua)
    bossMods = true,             -- mUI boss timers and warnings instead of Blizzard's display
    bossModsSound = true,        -- short sound right before a boss ability
    toasts = true,               -- mUI toasts instead of Blizzard popups (off: after reload)
    characterWindow = true,      -- custom mUI character window (Forever; off: after reload)
    guildOverview = true,        -- guild: "Overview" tab (classes, levels) - Skins/Communities.lua
    guildInactive = true,        -- guild: subtle red after 14 days offline (ranks containing "Twink"/"Alt" excluded)
    guildSkin = true,            -- Blizzard guild window in mUI style (Skins/Communities.lua)
    damageMeter = true,          -- custom mUI damage meter instead of Blizzard's window (off: after reload)
    damageMeterSecond = false,   -- second damage meter window below (own type selectable)
    damageMeterFade = true,      -- fade damage meter out of combat (mouseover shows it)
    bagsShowSlots = false,       -- bag slots at the bottom of the bag window (button at the top of the window)
    mapReveal = true,            -- world map: reveal the whole map (Comfort)
    mapZoneLevels = true,        -- world map: level range at the zone name (Comfort)
    emptySlots = true,           -- bags: mark items for empty gear slots (Comfort)
    upgrades = "damage",         -- upgrade rating: "damage" (% total damage), "item" (% of item), "off"
    -- own buffs/debuffs left of the minimap (apply after reload)
    auraSize = "medium",    -- buff/debuff size: "small", "medium", "large"
    auraTime = "below",     -- time left "below" (under the icon) or "inside" (in the icon)
    microMenu = "always", -- micro menu bottom right: "always", "mouseover", "hidden"
    addonBar = "mouseover", -- other addons' minimap buttons as a bar above the micro menu
    addonBarHidden = {},    -- [key] = true: hide addon from the bar
    -- Info bar at the bottom: visibility ("always", "mouseover", "hidden") and fields
    infoBar = {
        mode = "always",
        fields = { gold = true, bags = true, durability = true, fps = true,
            spec = false, guild = false, friends = false, time = false, weaponskill = true },
    },
    -- Progress bars: one visibility for XP, reputation, honor, house favor
    xpBar = { mode = "always", quests = "all" }, -- quests: "all", "complete", "none"
    ammoCounter = true,          -- ammo counter below the player frame (Forever only, with ammo only)
    petHelper = true,            -- pet helper: paw on the pet frame, feeding + happiness toast (Forever only, hunters)
    lfgHighlight = true,         -- highlight group finder messages in chat (Chat/LFGHighlight.lua, Forever only)
    professionReminder = true,   -- profession reminder: next rank learnable (Toasts/ProfessionReminder.lua, Forever only)
    autoBuy = false,             -- restock ammo/reagents at merchants (Bags/AutoBuy.lua)
    autoBuyAmounts = {},         -- [item ID | "ammo"] = desired amount; missing = default, 0 = don't buy
    reagentShow = {},            -- [item ID | "ammo"] = true/false; missing = default (only the first per class)
    flightTimer = true,          -- flight timer bar top center (Minimap/FlightTimer.lua)
    swingTimer = true,           -- Forever: swing timer below the main bar
    threatBar = "group", -- threat bar: "group" (in group or with pet), "always", "hidden"
    barVariant = "center",       -- bar arrangement: "center" (centered 2x6) or "stacked" (3 x 12 at the bottom)
    mouseoverHeal = false,       -- mouseover casting on the bars (CVar enableMouseoverCast)
    -- Action bar visibility: "always", "mouseover", "hidden"
    actionBars = {
        bar1 = "always", bar2 = "always", bar3 = "always", bar4 = "always", bar5 = "always",
        bar6 = "hidden", bar7 = "hidden", bar8 = "hidden", -- extra bars: enabled in settings
        petbar = "always", stancebar = "mouseover",
    },
    actionBarTexts = {}, -- [bar] = { hotkey = false, macro = false } hides texts; missing = shown
    actionBarFont = "medium", -- keybinding font size: "small", "medium", "large"
}

ns.DEFAULTS = DEFAULTS -- e.g. for "Reset" in settings

function ns.ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(db[k]) == "table" then
            ns.ApplyDefaults(db[k], v)
        end
    end
end

-- Rename a profile incl. all references (characters, spec assignments, new characters)
local function MoveProfile(root, old, new)
    root.profiles[new] = root.profiles[old]
    root.profiles[old] = nil
    if root.newCharProfile == old then root.newCharProfile = new end
    for _, char in pairs(root.chars) do
        if char.profile == old then char.profile = new end
        for spec, profile in pairs(char.specProfiles or {}) do
            if profile == old then char.specProfiles[spec] = new end
        end
    end
end

-- Profile migration v2: "Standard (DPS)" becomes "Standard"; the empty legacy profiles
-- "Standard (Tank)"/"(Heal)" are removed if unused, otherwise kept as custom profiles.
local function MigrateProfiles(root)
    if root.profilesVersion == 2 then return end
    root.profilesVersion = 2
    if root.profiles["Standard (DPS)"] and not root.profiles[ns.DEFAULT_PROFILE] then
        MoveProfile(root, "Standard (DPS)", ns.DEFAULT_PROFILE)
    end
    for _, old in ipairs({ "Standard (Tank)", "Standard (Heal)" }) do
        local used = root.newCharProfile == old
        for _, char in pairs(root.chars) do
            if char.profile == old then used = true end
            for _, profile in pairs(char.specProfiles or {}) do
                if profile == old then used = true end
            end
        end
        if root.profiles[old] and not used then root.profiles[old] = nil end
    end
end

-- Settings migration v2: sliders became stages, some options became fixed. Old values are
-- converted once, unused keys removed.
local REMOVED_KEYS = { "font", "texture", "minimapTexts", "minimapIcons", "frameWidth", "frameHeight",
    "chatFadeSeconds", "chatLineSpacing", "chatChannelGap", "tooltipGuild", "tooltipItemBorder", "combatTextFont",
    "gcdBar", "channelTicks", "groupWidth", "groupHeight", "raidWidth", "raidHeight", "raid40Width", "raid40Height",
    "toastArt", "buffSize", "debuffSize", "buffsPerRow", "debuffsPerRow", "auraCancel", "bagsBar",
    "bagsBarDefaultHidden", "trackingBars", "rpHideNames", "questlogMaxHeight", "ammoWarnAt", "skins", "skinWindows" }

local function Stage(value, smallBelow, largeFrom)
    if type(value) ~= "number" then return nil end
    if value <= smallBelow then return "small" elseif value >= largeFrom then return "large" end
    return "medium"
end

local function MigrateSettingsV2(db)
    db.frameSize = db.frameSize or Stage(db.frameWidth, 250, 300)
    db.auraSize = db.auraSize or Stage(db.buffSize, 32, 40)
    if type(db.chatFontSize) == "number" then db.chatFontSize = Stage(db.chatFontSize, 12, 16) end
    if db.castbar == nil and db.gcdBar == false and db.channelTicks == false then db.castbar = "simple" end
    if db.minimapExtras == nil and (db.minimapTexts == "mouseover" or db.minimapIcons == "mouseover") then
        db.minimapExtras = "mouseover"
    end
    local function Simple(mode) return (mode == "combat" or mode == "nocombat") and "always" or mode end
    for key, mode in pairs(db.actionBars or {}) do db.actionBars[key] = Simple(mode) end
    if db.xpBar then db.xpBar.mode = Simple(db.xpBar.mode) end
    if db.infoBar then db.infoBar.mode = Simple(db.infoBar.mode) end
    for _, key in ipairs(REMOVED_KEYS) do db[key] = nil end
end

local function MigrateSettings(db)
    local version = db.settingsVersion or 1
    if version < 2 then MigrateSettingsV2(db) end
    -- v3 (rune look): the class animals at the action bars are on for everyone, once
    if version < 3 then db.actionBarArt = true end
    db.settingsVersion = 3
end

-- Short realm name: Forever's "CAMWOW EU5 Realm 10 RP" -> short "RP", long "EU5-10 RP".
-- Other realms stay unchanged.
function ns.ShortRealm(realm)
    local region, number, kind = (realm or ""):match("^%S+ (%S+) Realm (%d+) (.+)$")
    if not kind then return realm, realm end
    return kind, region .. "-" .. number .. " " .. kind
end

-- "Name - Realm" key for display: "Koratal Rabenruf (RP)"
function ns.CharDisplayName(key)
    local name, realm = (key or ""):match("^(.-) %- (.+)$")
    if not name then return key end
    return name .. " (" .. (ns.ShortRealm(realm)) .. ")"
end

ns:On("ADDON_LOADED", function(_, name)
    -- Only react to our own addon but keep the event registered: modules wait for
    -- Blizzard load-on-demand addons (e.g. Blizzard_TimeManager).
    if name ~= ADDON_NAME then return end
    MeredanUIDB = MeredanUIDB or {}
    local root = MeredanUIDB

    -- Migrate pre-profile flat settings into the default profile
    if not root.profiles then
        local old = {}
        for key, value in pairs(root) do old[key] = value end
        wipe(root)
        root.profiles = { [ns.DEFAULT_PROFILE] = old }
    end
    root.chars = root.chars or {}
    MigrateProfiles(root)
    for _, name in ipairs(ns.BUILTIN_PROFILES) do root.profiles[name] = root.profiles[name] or {} end
    -- Frame moving was removed: drop old saved positions
    for _, profile in pairs(root.profiles) do profile.positions = nil end
    ns.root = root

    -- Setup flag used to be account-wide (root.setupDone), now per character; existing characters
    -- count as set up.
    if root.setupDone then
        for _, known in pairs(root.chars) do known.setupDone = true end
        root.setupDone = nil
    end

    -- Character key = first AND last name + realm (two characters with the same first name on one
    -- realm would otherwise share key, profile and setup). Forever returns the last name as the
    -- second value of UnitName; Retail has none, so the key stays first name only.
    local first, last = UnitName("player")
    if last and (issecretvalue and issecretvalue(last) or last == "") then last = nil end
    local fullName = last and (first .. " " .. last) or first
    local realm = GetRealmName()
    ns.charName = fullName
    ns.charKey = fullName .. " - " .. realm
    local char = root.chars[ns.charKey]
    if not char then
        char = {}
        root.chars[ns.charKey] = char
        -- Previously stored by first name only? Take over its settings
        local oldKey = first .. " - " .. realm
        local old = oldKey ~= ns.charKey and root.chars[oldKey] or nil
        local shared = root.newCharProfile
        if shared and root.profiles[shared] then
            -- "Default for new characters" chosen: share that profile, it is already set up
            char.profile, char.setupDone = shared, true
        else
            -- Own profile named after the character; on a name clash append the short realm
            -- ("(RP)", then "(EU5-10 RP)", then a number)
            local short, long = ns.ShortRealm(realm)
            local name, n = fullName, 1
            if root.profiles[name] then name = fullName .. " (" .. short .. ")" end
            if root.profiles[name] then name = fullName .. " (" .. long .. ")" end
            local base = name
            while root.profiles[name] do n = n + 1; name = base .. " " .. n end
            local source = old and old.profile and root.profiles[old.profile]
            root.profiles[name] = source and CopyTable(source) or {}
            char.profile = name
            -- Carry over other character data (talent advisor, chat history ...) but NOT the setup
            -- flag: it came from the account-wide flag and doesn't apply to this character
            for key, value in pairs(old or {}) do
                if key ~= "profile" and key ~= "setupDone" then
                    char[key] = type(value) == "table" and CopyTable(value) or value
                end
            end
        end
        if old and root.gold then root.gold[oldKey] = nil end -- gold list: re-added under the new name
    end
    -- Delete the old first-name-only entry after migrating, otherwise every further character with
    -- the same first name inherits its profile and setup flag
    if last then
        local oldKey = first .. " - " .. realm
        if oldKey ~= ns.charKey then root.chars[oldKey] = nil end
    end
    -- One-time reset: all setup flags came from the account-wide flag or the first-name entry,
    -- so every character is offered the setup again
    if not root.setupPerChar then
        for _, known in pairs(root.chars) do known.setupDone = nil end
        root.setupPerChar = true
    end
    char.profile = root.profiles[char.profile] and char.profile or ns.DEFAULT_PROFILE
    char.specProfiles = char.specProfiles or {}
    -- Leftovers of the former per-character layout; the layout now lives in the profile
    char.layout, char.specLayouts, root.newCharLayout = nil, nil, nil
    ns.char = char
    ns.UseProfile(char.profile)
end)

-- Load a profile as active settings (ns.db); created if missing.
function ns.UseProfile(name)
    local profiles = ns.root.profiles
    profiles[name] = profiles[name] or {}
    MigrateSettings(profiles[name])
    ns.ApplyDefaults(profiles[name], DEFAULTS)
    ns.db = profiles[name]
    ns.profileName = name
    if ns.UI and ns.UI.ApplyClassAccent then ns.UI.ApplyClassAccent() end
    if ns.ApplySettings then ns.ApplySettings() end -- theme border colour before any frame is built
end

ns:On("PLAYER_LOGIN", function()
    ns.Debug("v%s, %s", ns.VERSION, ns.IS_FOREVER and "Forever" or "Retail")
    -- Greeting: full brand name, muted version, name in class color, hint to /mui
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS[class]
    local name = UnitName("player") or ""
    if color then name = color:WrapTextInColorCode(name) end
    print(("%s |cff99978fv%s|r  ·  %s  ·  |cff99978f%s|r"):format(BRAND_LONG, ns.VERSION,
        L["Welcome back, %s!"]:format(name), L["/mui opens the settings"]))
end)

-------------------------------------------------------------------------------
--  Slash commands: /meredanui or /mui [command]
-------------------------------------------------------------------------------
local commands = {}

-- dev = developer tool: only listed and usable in developer mode (/mui debug)
function ns.AddCommand(name, help, fn, dev)
    commands[name] = { help = help, fn = fn, dev = dev }
end

-- Only player commands are listed; aliases, "help" and developer commands work but never show
local function ShowHelp()
    ns.Print(L["Commands:"])
    local names = {}
    for name, cmd in pairs(commands) do
        if cmd.help then names[#names + 1] = name end
    end
    table.sort(names)
    local function Line(name, help)
        print(("  |cff8ecbb4/mui%s|r  %s"):format(name ~= "" and " " .. name or "", help))
    end
    Line("", L["Open settings"])
    for _, name in ipairs(names) do
        local cmd = commands[name]
        if not cmd.dev then Line(name, cmd.help) end
    end
end

ns.AddCommand("help", nil, ShowHelp)
-- Developer mode: always usable, but not listed for players
commands.debug = { help = L["Developer mode on/off"], fn = function()
    ns.db.debug = not ns.db.debug
    ns.Print(L["Developer mode: %s"], ns.db.debug and L["on"] or L["off"])
end, dev = true }

SLASH_XMEREDANUI1 = "/meredanui"
SLASH_XMEREDANUI2 = "/mui"
SlashCmdList["XMEREDANUI"] = function(msg)
    local name, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    if name == "" and ns.OpenSettings then return ns.OpenSettings() end
    local cmd = commands[name:lower()]
    if cmd and cmd.dev and name:lower() ~= "debug" and not ns.db.debug then cmd = nil end
    if cmd then cmd.fn(rest) else ShowHelp() end
end

-- Click on the addon compartment entry (minimap menu);
-- opens settings (Settings.lua sets ns.OnCompartmentClick).
function MeredanUI_OnAddonCompartmentClick()
    if ns.OnCompartmentClick then ns.OnCompartmentClick() else ShowHelp() end
end

-------------------------------------------------------------------------------
--  Never anchor secure buttons (Secure...Template) to insecure frames: WoW then protects the
--  frame they hang on, incl. its window, which can no longer be shown/hidden in combat.
--  So the secure layer is anchored only to UIParent, mirroring the window's rect, and buttons
--  attach only to that layer. Positions are set out of combat (the layer is hidden in combat).
-------------------------------------------------------------------------------
-- Place frame over target's rect, anchored only to relativeTo (default: UIParent)
function ns.MirrorRect(frame, target, relativeTo)
    if InCombatLockdown() then return end
    relativeTo = relativeTo or UIParent
    local l, b, w, h = target:GetRect()
    local rl, rb = relativeTo:GetRect()
    if not (l and rl) then return end
    local scale = frame:GetEffectiveScale()
    local s, rs = target:GetEffectiveScale() / scale, relativeTo:GetEffectiveScale() / scale
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", relativeTo, "BOTTOMLEFT", l * s - rl * rs, b * s - rb * rs)
    frame:SetSize(w * s, h * s)
end

-- Layer follows target (window dragged or resized): small watcher on the window
function ns.FollowFrame(layer, target)
    local watcher = CreateFrame("Frame", nil, target)
    local lastL, lastB, lastW, lastH
    watcher:SetScript("OnUpdate", function()
        if InCombatLockdown() then return end
        local l, b, w, h = target:GetRect()
        if not l then return end
        -- compare numbers, not a formatted string: this runs every frame while the window is open
        if l == lastL and b == lastB and w == lastW and h == lastH then return end
        lastL, lastB, lastW, lastH = l, b, w, h
        ns.MirrorRect(layer, target)
    end)
    ns.MirrorRect(layer, target)
end

-- Game settings mUI needs for its look: set as temporary CVars (not saved by the game), reapplied at
-- every login. Without mUI the player's own values are back on the next start. value nil = drop
-- mUI's temporary value. Falls back to a normal CVar where the temporary call isn't available.
function ns.LookCVar(name, value)
    if C_CVar.GetCVar(name) == nil then return end
    if C_CVar.SetTempCVar then
        local ok, err = pcall(C_CVar.SetTempCVar, name, value)
        if ok then return end
        if DevLog then DevLog("MeredanUI", "LookCVar fallback " .. name .. ": " .. tostring(err)) end
    end
    if value == nil then value = C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(name) end
    if value ~= nil then C_CVar.SetCVar(name, value) end
end
