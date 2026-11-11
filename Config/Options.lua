-- mUI settings window: navigation with grouped sections on the left, the page on the right.
-- Opened via /mui, the minimap addon menu or the button in Blizzard's settings.
--
-- Page layout: title + one sentence, then the module's on/off toggle (if any), then the options.
-- Explanations live in the "i" tooltip on the label, not as paragraphs. Options that need a reload
-- carry a "RELOAD" badge; a "Reload UI" bar then appears at the bottom. The button top right
-- starts the preview.
--
-- Every element keeps its own setting, but only as a toggle, a few steps or a small dropdown -
-- no sliders for looks. Pure visual numbers (fonts, textures, spacing, group frame sizes ...)
-- are fixed.
local _, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT, NAV_WIDTH = 860, 640, 220
local CONTENT_WIDTH = WIDTH - 10 - NAV_WIDTH - 20 - 28 -- room for the scrollbar on the right
local NAV_ROW, NAV_GROUP, NAV_SMALL = 26, 24, 22 -- NAV_SMALL: Modules/Skins/Changelog at the bottom, subdued
local window

-- Dropdown choices ----------------------------------------------------------------------

local function ThemeItems()
    local items = {}
    for _, key in ipairs(ns.THEME_ORDER) do items[#items + 1] = { value = key, label = ns.THEMES[key].name } end
    return items
end

-- Steps Small/Medium/Large (Small/Normal/Large for unit frames)
local function StageItems()
    return {
        { value = "small", label = L["Small"] },
        { value = "medium", label = L["Medium"] },
        { value = "large", label = L["Large"] },
    }
end
local function FrameStageItems()
    return {
        { value = "small", label = L["Small"] },
        { value = "medium", label = L["Normal"] },
        { value = "large", label = L["Large"] },
    }
end

-- Visibility (bars): Always / Mouseover / Off
local function VisibilityItems()
    return {
        { value = "always", label = L["Always"] },
        { value = "mouseover", label = L["Mouseover"] },
        { value = "hidden", label = L["Hidden"] },
    }
end

-- Action bars: additionally "In combat" (hidden outside, visible on mouseover)
local function BarVisibilityItems()
    return {
        { value = "always", label = L["Always"] },
        { value = "combat", label = L["In combat"] },
        { value = "mouseover", label = L["Mouseover"] },
        { value = "hidden", label = L["Hidden"] },
    }
end

local function AlwaysOrHover()
    return { { value = "always", label = L["Always"] }, { value = "mouseover", label = L["Mouseover"] } }
end

local function TooltipAnchorItems()
    return { { value = "corner", label = L["Bottom right"] }, { value = "cursor", label = L["At the mouse"] } }
end

local function BagStyleItems()
    return {
        { value = "categories", label = L["Sections"] },
        { value = "single", label = L["One big bag"] },
    }
end

local function ForcesItems()
    return {
        { value = "detail", label = L["Percent with 2 decimals and count"] },
        { value = "percent", label = L["Percent only (Blizzard)"] },
    }
end

local function UpgradeModeItems()
    return {
        { value = "damage", label = L["Total damage"] },
        { value = "item", label = L["Compared to equipped item (like Pawn)"] },
        { value = "off", label = L["Off"] },
    }
end

local function AuraTimeItems()
    return { { value = "below", label = L["Below the icon"] }, { value = "inside", label = L["Inside the icon"] },
        { value = "bar", label = L["Bar below the icon"] } }
end

local function QuestXPItems()
    return {
        { value = "all", label = L["Completed and open"] },
        { value = "complete", label = L["Completed only"] },
        { value = "none", label = L["Off"] },
    }
end

-- Read/write a value in ns.db, optionally run something afterwards
local function Getter(key) return function() return ns.db[key] end end
local function On(key) return function() return ns.db[key] ~= false end end -- default on
local function Setter(key, after)
    return function(value)
        ns.db[key] = value
        if after then after() end
    end
end
local RELOAD = { reload = true }
local function Help(text, reload) return { help = text, reload = reload } end
-- Settings of a module another addon has taken over: greyed out, tooltip names the addon
local function LockForOther(page, key, first, last)
    local other = ns.OtherAddonFor and ns.OtherAddonFor(key)
    if not other or first > (last or #page.items) then return end
    page:LockRows(first, last, L["%s does this job right now. These settings apply again when you switch back to mUI on the Modules page."]:format(ns.OtherAddonTitle(other)))
end

-- Module label + grey "<Addon> active" while another addon does the job (Core/OtherAddons.lua)
local function ModuleLabel(label, key)
    local other = ns.OtherAddonFor and ns.OtherAddonFor(key)
    if not other then return label end
    return label .. "  |cff8a918e" .. L["%s active"]:format(ns.OtherAddonTitle(other)) .. "|r"
end

-- Own windows (Forever): key in ns.db, label, explanation
local WINDOWS = {
    { "trainerWindow", "mUI trainer window", "Own trainer window for class, profession and pet trainers: list with categories, details with Blizzard's profession art, learn all." },
    { "gossipWindow", "mUI conversation window", "Greeting, quests and conversation options when you talk to an NPC." },
    { "questWindow", "mUI quest window", "Accept, progress and rewards (pick one with a click)." },
    { "mailWindow", "mUI mailbox", "Inbox with selection, open all (everything, gold only, auction house), address book and quick attach – the best of Postal." },
    { "legacyWindow", "mUI legacy window", "Legacy rewards, challenges and the three legacy trees in one window, tabs on the right." },
    { "talentWindow", "mUI talent window", "Three trees side by side on Blizzard's art, search, hide passives, show ranks, primary and secondary talents." },
    { "tradeWindow", "mUI trade window", "Trading with players in the mUI look: both sides as cards, gold fields, ready marker." },
    { "skinDialogs", "Confirmation dialogs in mUI look", "Blizzard's confirmation dialogs (destroy item, gold trade timer, invitations …) with mUI frame, buttons and timer bar." },
    { "professionWindow", "mUI profession window", "Recipes with search, filter and favorites, reagents from your bags, create (all); overview of all professions with their spells; tabs on the right." },
    { "spellbookWindow", "mUI spellbook", "Spells on parchment, tabs per tree on the right, search, passives and lower ranks on demand; cast, drag onto bars." },
    { "mapWindow", "mUI map", "World map with Blizzard's markers, breadcrumbs, coordinates and map pin, plus your own quest log next to it." },
    { "flightWindow", "mUI flight map", "Flight master map as a large, centered window: zoom with the mouse wheel, drag to move." },
    { "friendsWindow", "mUI friends window", "Friends, recent allies, friend requests and raid in the mUI look: status, BattleTag, search and filter, game icons, invite; Blizzard's menus and dialogs." },
    { "guildSkin", "Guild window in mUI look", "Blizzard's guild & communities window in the mUI look: chat, members, info, settings and all sub-windows; functions stay Blizzard's." },
    { "guildOverview", "Guild overview tab", "Extra tab in the guild window: members per class and per level range, plus members, online and average level." },
    { "guildInactive", "Mark inactive guild members", "Members offline for 14 days or more get a faint red background. Alt ranks (“Twink” or “Alt” in the name) are ignored." },
    { "characterWindow", "mUI character window", "Character, reputation, skills, PvP, currencies and statistics in the mUI look." },
    { "auctionWindow", "mUI auction house", "Auction house in the mUI look: buy with categories and favorites, sell with price suggestion and net breakdown, your auctions and bids, plus a history with income, expenses and fees." },
    { "readyCheckWindow", "mUI ready check", "Ready check in the mUI look: who asked, time bar, ready / not ready." },
    { "addonListWindow", "mUI addon list", "Addon list in the mUI look: search, groups, this character or all, reload marker; opens from the game menu." },
    { "dressUpSkin", "Dressing room in mUI look", "Blizzard's dressing room in the mUI look, at the fixed window spot next to the other windows; functions stay Blizzard's." },
    { "collectionsWindow", "mUI collections", "Mounts, pets, toys, heirlooms and wardrobe in one mUI window with search, favorites and 3D preview; replaces Blizzard's collections." },
    { "calendarSkin", "Calendar in mUI look", "Blizzard's calendar in the mUI look: flat day grid, event windows on the right; functions stay Blizzard's." },
    { "stableSkin", "Stable in mUI look", "Blizzard's hunter stable in the mUI look at the fixed window spot; functions stay Blizzard's." },
    { "scoreboardSkin", "Scoreboard in mUI look", "Blizzard's battleground scoreboard and match results in the mUI look; position and functions stay Blizzard's." },
    { "socketSkin", "Item socketing in mUI look", "Blizzard's socketing window in the mUI look: gem slots in socket colors; functions stay Blizzard's." },
    { "tabardSkin", "Tabard designer in mUI look", "Blizzard's tabard designer in the mUI look: model left, emblem choices and crest right; functions stay Blizzard's." },
    { "petitionSkin", "Guild charter in mUI look", "Guild registrar and guild charter in the mUI look on parchment; functions stay Blizzard's." },
    { "clockSkin", "Clock in mUI look", "Blizzard's clock (alarm, time format) and stopwatch in the mUI look; functions stay Blizzard's." },
    { "deathRecapSkin", "Death recap in mUI look", "Blizzard's death recap in the mUI look, killing blow in the header; functions stay Blizzard's." },
    { "questieSkin", "Questie settings in mUI look", "Questie's settings window in the mUI look (only with Questie installed); functions stay Questie's." },
    { "macroSkin", "Macros in mUI look", "Blizzard's macro window in the mUI look: macros on the left, large edit area on the right; functions stay Blizzard's." },
    { "groupFinderSkin", "Group finder in mUI look", "Blizzard's group finder in the mUI look: list your group, browse groups, who list; at the fixed window spot, functions stay Blizzard's." },
    { "merchantWindow", "mUI merchant window", "Own merchant window in the bag look instead of Blizzard's: cards in two columns, search, buyback, repair and sell junk." },
}
local WINDOW_BY_KEY = {}
for _, entry in ipairs(WINDOWS) do WINDOW_BY_KEY[entry[1]] = entry end
-- Skins page in groups
local SKIN_GROUPS = {
    { L["Character"], { "characterWindow", "spellbookWindow", "talentWindow", "professionWindow", "legacyWindow", "dressUpSkin", "collectionsWindow", "stableSkin", "socketSkin", "tabardSkin" } },
    { L["World"], { "mapWindow", "flightWindow" } },
    { L["NPCs"], { "merchantWindow", "trainerWindow", "gossipWindow", "questWindow", "mailWindow", "tradeWindow", "auctionWindow" } },
    { L["Social"], { "friendsWindow", "guildSkin", "groupFinderSkin", "scoreboardSkin", "petitionSkin", "skinDialogs", "readyCheckWindow", "guildOverview", "guildInactive" } },
    { L["System"], { "addonListWindow", "macroSkin", "calendarSkin", "clockSkin", "deathRecapSkin", "questieSkin" } },
}

-- Pages --------------------------------------------------------------------------------
-- key stays stable (ShowSettings(key)); group = heading in the navigation;
-- bottom = bottom of the navigation. Preview: one button top right for everything (Core/Preview.lua).

local PAGES = {
    {
        key = "appearance", label = L["Appearance"],
        build = function(page)
            page:AddTitle(L["Appearance"], L["Size, font size and colours of everything mUI draws."])
            -- UI size (account-wide, Core/Style.lua); 1 px borders need a reload
            page:AddDropdown(L["Size"], StageItems, function() return ns.root.uiSize or "medium" end, function(value)
                ns.root.uiSize = value ~= "medium" and value or nil
                ns.ApplyUIScale()
                ns.Relayout()
            end, RELOAD)
            -- Font size of all mUI texts (per profile); some (tooltip, toasts ...) only after a reload
            page:AddDropdown(L["Font size"], StageItems, function() return ns.db.fontSize or "medium" end, function(value)
                ns.db.fontSize = value
                ns.RefreshStyle()
            end, RELOAD)
            page:AddDropdown(L["Background opacity"], function()
                return {
                    { value = "solid", label = L["Solid"] },
                    { value = "normal", label = L["Normal"] },
                    { value = "light", label = L["See-through"] },
                }
            end, function() return ns.db.panelOpacity or "normal" end, function(value)
                ns.db.panelOpacity = value
                ns.RefreshStyle()
            end, RELOAD)
            page:AddDropdown(L["Theme"], ThemeItems, Getter("theme"), Setter("theme", ns.RefreshStyle),
                Help(L["Class colour: health in class colour. Blizzard: Blizzard's class colours and bright green. Dark: dark health bars, class-coloured power. mUI: sage green health bars."]))
            page:AddDropdown(L["Accent colour"], function()
                return {
                    { value = "mui", label = L["mUI green"] },
                    { value = "class", label = L["Class colour (muted)"] },
                    { value = "blizzard", label = L["Class colour (Blizzard)"] },
                }
            end, function()
                local v = ns.db.classAccent
                return v == "blizzard" and "blizzard" or v and "class" or "mui"
            end, function(value)
                ns.db.classAccent = value == "blizzard" and "blizzard" or value == "class"
            end, Help(L["Lines, headings and selections."], true))
            page:AddCheckbox(L["Use the mUI font in Blizzard windows too"], On("fontEverywhere"),
                Setter("fontEverywhere", ns.ApplyGlobalFonts),
                Help(L["Windows, menus and tooltips. Turning it off needs a reload."], true))
            page:AddHeader(L["Away"])
            page:AddCheckbox(L["Cinema screen while AFK"], On("afkScreen"), Setter("afkScreen"),
                Help(L["Cinema bars slide in, the interface fades out and the camera slowly circles your character. Move or click to come back."]))
        end,
    },
    {
        key = "unitframes", label = L["Unit frames"], group = L["Frames"],
        build = function(page)
            page:AddTitle(L["Unit frames"], L["Player, target, focus and boss frames."])
            -- First and last name only exist in Forever; applies to all frames and nameplates
            if ns.IS_FOREVER then
                page:AddDropdown(L["Names"], function()
                    return {
                        { value = "full", label = L["First and last name"] },
                        { value = "first", label = L["First name only"] },
                        { value = "last", label = L["Last name only"] },
                        { value = "firstInitial", label = L["Koratal R."] },
                        { value = "initialLast", label = L["K. Rabenruf"] },
                    }
                end, function() return ns.db.nameFormat or "first" end, function(value)
                    ns.db.nameFormat = value
                    ns.UpdateNameTags()
                end)
            end
            page:AddDropdown(L["Size of player and target"], FrameStageItems, Getter("frameSize"), Setter("frameSize"),
                Help(L["Pet, target of target and focus grow with them."], true))
            page:AddDropdown(L["Size of boss frames"], StageItems, Getter("bossSize"), Setter("bossSize"), RELOAD)
            page:AddHeader(L["Cast bar"])
            page:AddDropdown(L["Style"], function()
                return { { value = "simple", label = L["Simple"] }, { value = "full", label = L["Full"] } }
            end, Getter("castbar"), Setter("castbar"),
                Help(L["Simple: just the bar. Full: with a global cooldown line and tick marks on channelled spells."]))
            page:AddHeader(L["Target"])
            page:AddCheckbox(L["Execute line"], On("executeLine"), Setter("executeLine", ns.UpdateExecuteLines),
                Help(L["Line in the health bar of your target and enemy nameplates where your execute ability becomes usable (e.g. 20 % or 35 %). Only if your class has one."]))
            -- Ammo & reagents only exist in Forever (preview everywhere)
            page:AddHeader(L["Class reagents"])
            if ns.IS_FOREVER then
                page:AddCheckbox(L["Show class reagents"], On("ammoCounter"), Setter("ammoCounter", ns.UpdateAmmoCounter),
                    Help(L["Ammunition and spell reagents of your class (soul shards, runes, candles …) next to the player frame. Warns when they run low."]))
            else
                page:AddNote(L["Only in WoW Forever – Retail has no ammunition or reagents like these."])
            end
            -- which reagents are shown - own class only
            local _, myClass = UnitClass("player")
            local entries = {}
            for index, reagent in ipairs(ns.CLASS_REAGENTS[myClass] or {}) do
                local key = ns.ReagentKey(reagent)
                entries[#entries + 1] = {
                    label = reagent.ammo and L["Ammunition"] or (C_Item.GetItemNameByID(reagent.item) or ("Item " .. reagent.item)),
                    get = function() return ns.ReagentShown(reagent, index) end,
                    set = function(value)
                        ns.db.reagentShow[key] = value
                        if ns.UpdateAmmoCounter then ns.UpdateAmmoCounter() end
                    end,
                }
            end
            if #entries > 0 then
                page:AddCheckboxGrid(entries, 2)
            else
                page:AddNote(L["Your class doesn't use reagents."])
            end
            if ns.IS_FOREVER then
                page:AddHeader(L["Swing timer"])
                page:AddCheckbox(L["Show swing timer"], On("swingTimer"), Setter("swingTimer", ns.UpdateSwingTimer),
                    Help(L["Thin bars below the main bar that fill up until your next automatic hit: Auto Shot or wand, main hand and off hand. Only while you attack. Test mode shows all three."]))
            end
            if ns.IS_FOREVER and select(2, UnitClass("player")) == "HUNTER" then
                page:AddHeader(L["Pet helper"])
                page:AddCheckbox(L["Show pet helper"], On("petHelper"), Setter("petHelper", ns.UpdatePetHelper),
                    Help(L["Paw left of your pet frame: colour shows its mood, click feeds it with suitable food from your bags. One notification when its mood drops."]))
            end
            page:AddHeader(L["Threat bar"])
            page:AddDropdown(L["Visibility"], function()
                return {
                    { value = "group", label = L["In a group or with a pet"] },
                    { value = "always", label = L["Always (also solo)"] },
                    { value = "hidden", label = L["Hidden"] },
                }
            end,
                function() return ns.db.threatBar or "group" end,
                function(value) ns.db.threatBar = value; if ns.UpdateThreatBar then ns.UpdateThreatBar() end end,
                Help(L["Below the main bar, in combat only. The fuller and redder, the closer the aggro gets to the wrong player. Pulsing red: wrong aggro."]))
        end,
    },
    {
        key = "groupframes", label = L["Group & raid"],
        build = function(page)
            page:AddTitle(L["Group & raid"], L["Party and raids up to 15 players sit next to the player frame. Raids from 16 players sit bottom left above the chat."])
            page:AddCheckbox(L["mUI group frames"], On("groupFrames"), Setter("groupFrames"),
                Help(L["Each group a column, you included. Shows boss debuffs, debuffs you can dispel, aggro (red border), missing buffs of your class, absorbs, role, leader, ready check and range."], true))
            page:AddCheckbox(L["Show group frames when solo"], Getter("groupSolo"), Setter("groupSolo"), RELOAD)
            page:AddCheckbox(L["mUI group tools"], On("groupManager"), Setter("groupManager"),
                Help(L["Replaces Blizzard's raid leader bar on the left edge: ready check, role check, countdown, markers, pings and leave group."], true))
            page:AddHeader(L["Helpers"])
            page:AddCheckbox(L["Accept invites from friends and guild"], Getter("autoInvite"), Setter("autoInvite"),
                Help(L["Battle.net friends, friends and guild members only. Invites from anyone else still ask."]))
            page:AddCheckbox(L["Confirm role checks with your spec role"], On("autoRole"), Setter("autoRole"))
            page:AddCheckbox(L["Accept summons"], Getter("autoSummon"), Setter("autoSummon"),
                Help(L["Out of combat, after 5 seconds. Decline the pop-up to stop it."]))
            page:AddCheckbox(L["Accept resurrections"], Getter("autoResurrect"), Setter("autoResurrect"),
                Help(L["Not while the caster is still fighting."]))
            page:AddCheckbox(L["Decline duels"], Getter("declineDuels"), Setter("declineDuels"),
                Help(L["Friends and guild members can still ask."]))
            page:AddCheckbox(L["Ready check: remind me of missing food, flask and rune"], On("readyCheckReminder"),
                Setter("readyCheckReminder"))
            page:AddHeader(L["Preview"])
            -- Preview size (party and raid can't be shown at the same time)
            page:AddDropdown(L["Preview size"], function()
                return {
                    { value = "group", label = L["Party (5)"] },
                    { value = "group10", label = L["Raid (10)"] },
                    { value = "group15", label = L["Raid (15)"] },
                    { value = "group20", label = L["Raid (20)"] },
                    { value = "raid", label = L["Raid (21–25)"] },
                    { value = "raid40", label = L["Raid (40)"] },
                }
            end, function() return ns.Preview.GroupKind() end, function(kind) ns.Preview.SetGroupKind(kind) end)
        end,
    },
    {
        key = "nameplates", label = L["Nameplates"],
        build = function(page)
            page:AddTitle(L["Nameplates"], ns.IS_FOREVER -- Forever: no Mythic+
                and L["Enemy plates with priority colours, interrupt-ready cast bar and your debuffs. Friendly plates show names only."]
                or L["Enemy plates with priority colours, interrupt-ready cast bar, Mythic+ percentage and your debuffs. Friendly plates show names only."])
            page:AddCheckbox(ModuleLabel(L["mUI nameplates"], "nameplates"), On("nameplates"), Setter("nameplates"), RELOAD)
            if ns.OtherAddonFor("nameplates") == "Plater" then
                page:AddCheckbox(L["Plater in the mUI look"], On("platerStyle"), Setter("platerStyle", function()
                    if ns.db.platerStyle ~= false then ns.ApplyPlaterProfile(true) end
                end), Help(L["mUI font and flat bars, set once in Plater's profile. Everything else stays Plater's."]))
            end
            page:AddCheckbox(L["Rare and elite symbol"], On("plateClassification"), Setter("plateClassification"),
                Help(L["Blizzard's star or dragon in front of the name. Elite only outside dungeons and raids – almost everything is elite there."]))
            LockForOther(page, "nameplates", #page.items, #page.items)
            -- Display: Blizzard's own nameplate toggles in one place (take effect immediately)
            page:AddHeader(L["Show"])
            -- one checkbox can set several Blizzard CVars (e.g. companions, guardians, minions, totems)
            local function CVarCheck(label, ...)
                local cvars = { ... }
                return {
                    label = label,
                    get = function() return C_CVar.GetCVarBool(cvars[1]) end,
                    set = function(on)
                        ns.AfterCombat(function()
                            for _, cvar in ipairs(cvars) do
                                if C_CVar.GetCVar(cvar) then C_CVar.SetCVar(cvar, on and "1" or "0") end
                            end
                        end)
                    end,
                }
            end
            page:AddCheckboxGrid({
                CVarCheck(L["Friendly players"], "nameplateShowFriendlyPlayers"),
                CVarCheck(L["Friendly NPCs"], "nameplateShowFriendlyNpcs"),
                CVarCheck(L["Players' companions"], "nameplateShowFriendlyPlayerPets"),
                CVarCheck(L["Always show (otherwise only in combat)"], "nameplateShowAll"),
                CVarCheck(L["Enemies"], "nameplateShowEnemies"),
                CVarCheck(L["Enemy pets and minions"], "nameplateShowEnemyPets", "nameplateShowEnemyGuardians",
                    "nameplateShowEnemyMinions", "nameplateShowEnemyTotems"),
                CVarCheck(L["Minor enemies"], "nameplateShowEnemyMinus"),
            }, 2)
            -- Names above everything you can't attack
            local namesFirst = #page.items + 1
            page:AddHeader(L["Names"])
            page:AddCheckbox(L["mUI names instead of Blizzard names"], On("npMuiNames"), function(on)
                if ns.SetMuiNames then ns.SetMuiNames(on) end
            end, Help(L["Off: Blizzard's own names above characters and NPCs, as in the original. Takes effect right away."]))
            page:AddDropdown(L["Name size"], StageItems, function() return ns.db.npNameSize or "medium" end, function(value)
                ns.db.npNameSize = value
                if ns.RefreshNamePlates then ns.RefreshNamePlates() end
            end)
            page:AddCheckbox(L["Title below NPC names"], On("npNpcTitle"), Setter("npNpcTitle", ns.RefreshNamePlates))
            page:AddCheckbox(L["Owner below companions"], On("npPetOwner"), Setter("npPetOwner", ns.RefreshNamePlates))
            LockForOther(page, "nameplates", namesFirst)
        end,
    },
    {
        key = "auras", label = L["Buffs & debuffs"],
        build = function(page)
            local function Live(key) return Setter(key, ns.RefreshAurasDemo) end -- preview shows changes immediately
            page:AddTitle(L["Buffs & debuffs"], L["Your buffs and debuffs left of the minimap. The preview shows changes right away."])
            page:AddDropdown(L["Size"], StageItems, Getter("auraSize"), Live("auraSize"), RELOAD)
            page:AddDropdown(L["Time remaining"], AuraTimeItems, Getter("auraTime"), Live("auraTime"), RELOAD)
        end,
    },
    {
        key = "tooltip", label = L["Tooltip"],
        build = function(page)
            local function Live(key) return Setter(key, ns.RefreshTooltipDemo) end
            page:AddTitle(L["Tooltip"], L["What tooltips show and where they appear."])
            page:AddDropdown(L["Position"], TooltipAnchorItems, Getter("tooltipAnchor"), Live("tooltipAnchor"))
            page:AddCheckbox(L["Hide in combat"], Getter("tooltipHideInCombat"), Live("tooltipHideInCombat"),
                Help(L["Hold Shift to show it anyway."]))
            page:AddCheckbox(L["Show who cast buffs and debuffs"], On("tooltipAuraSource"), Setter("tooltipAuraSource"),
                Help(L["Adds “From: name” to aura tooltips, also when you're not in a group. Not for Blizzard's own buff bar at the top right (its tooltip is protected)."]))
            page:AddCheckbox(L["Show IDs"], On("tooltipIDs"), Live("tooltipIDs"),
                Help(L["Spells, items, NPCs. Handy for WeakAuras and macros."]))
            page:AddCheckbox(L["Item count on your characters"], On("altItemCount"), Setter("altItemCount"),
                Help(L["Bags, bank and mail of all your characters. Bank and mail as of your last visit."]))
            page:AddCheckbox(L["Rare and elite behind NPC names"], On("tooltipClassification"), Live("tooltipClassification"))
            page:AddHeader(L["Players"])
            page:AddCheckbox(L["Class icon"], On("tooltipClassIcon"), Live("tooltipClassIcon"))
            page:AddCheckbox(L["Item level"], On("tooltipItemLevel"), Live("tooltipItemLevel"))
            if not ns.IS_FOREVER then -- Forever: no Mythic+
                page:AddCheckbox(L["Mythic+ rating"], On("tooltipMythic"), Live("tooltipMythic"))
            end
            page:AddCheckbox(L["Target"], On("tooltipTarget"), Live("tooltipTarget"))
            page:AddHeader(L["Character window"])
            page:AddCheckbox(L["Item levels on the equipment slots"], On("characterItemLevels"), Setter("characterItemLevels"),
                Help(L["Also when inspecting other players. Coloured by quality."]))
            page:AddHeader(L["Upgrade rating"])
            page:AddDropdown(L["Show +/− % as"], UpgradeModeItems, ns.UpgradeMode,
                Setter("upgrades", function() if ns.RefreshBags then ns.RefreshBags() end end),
                Help(L["Compares an item with what you wear, like Pawn. Weights come from Bloodmallet."]))
            page:AddCheckbox(L["Mark items for empty slots"], On("emptySlots"),
                Setter("emptySlots", function() if ns.RefreshBags then ns.RefreshBags() end end),
                Help(L["Green frame in your bags on items you can wear in a slot that is still empty."]))
        end,
    },
    {
        key = "actionbars", label = L["Action bars"], group = L["Screen"],
        build = function(page)
            page:AddTitle(L["Action bars"], L["Arrangement and when each bar is visible."])
            local barsFirst = #page.items + 1
            page:AddDropdown(L["Arrangement"], function()
                return {
                    { value = "center", label = L["Centre (2 × 6)"] },
                    { value = "stacked", label = L["Stacked (3 × 12 at the bottom)"] },
                }
            end, Getter("barVariant"), Setter("barVariant"),
                Help(L["Centre: main bar between player and target. Stacked: three rows of 12 at the bottom. The healer layout is always stacked."], true))
            for _, key in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5", "petbar", "stancebar", "bar6", "bar7", "bar8" }) do
                if key == "bar6" then page:AddHeader(L["Extra bars"]) end
                -- visibility on the left, button text checkboxes on the right
                local function Shown(what) return not ns.ActionBarTextShown or ns.ActionBarTextShown(key, what) end
                page:AddDualDropdown(L["MOVER_" .. key], BarVisibilityItems,
                    function() return ns.ActionBarMode and ns.ActionBarMode(key) or ns.VisibilityMode(ns.db.actionBars[key]) end,
                    function(value)
                        ns.db.actionBars[key] = value
                        ns.ApplyActionBarVisibility()
                    end,
                    function()
                        return {
                            { value = "hotkey", label = L["Key binding"], checked = Shown("hotkey") },
                            { value = "macro", label = L["Macro name"], checked = Shown("macro") },
                        }
                    end,
                    function(what)
                        ns.db.actionBarTexts[key] = ns.db.actionBarTexts[key] or {}
                        ns.db.actionBarTexts[key][what] = not Shown(what)
                        if ns.ApplyActionBarTexts then ns.ApplyActionBarTexts() end
                    end,
                    function()
                        local hotkey, macro = Shown("hotkey"), Shown("macro")
                        if hotkey and macro then return L["Key, macro"] end
                        if hotkey then return L["Key"] end
                        if macro then return L["Macro"] end
                        return L["No texts"]
                    end)
            end
            page:AddHeader(L["Settings"]) -- applies to all bars, not just the extra bars
            page:AddDropdown(L["Key binding text size"], function()
                return { { value = "small", label = L["Small"] }, { value = "medium", label = L["Medium"] }, { value = "large", label = L["Large"] } }
            end, Getter("actionBarFont"), Setter("actionBarFont", function() if ns.ApplyActionBarTexts then ns.ApplyActionBarTexts() end end))
            page:AddCheckbox(L["Mouseover casting"], Getter("mouseoverHeal"), Setter("mouseoverHeal", ns.ApplyMouseoverCast),
                Help(L["Spells go to the unit under the mouse (e.g. a group frame) without targeting it. Same switch as Blizzard's mouseover cast."]))
            if ns.IS_FOREVER then
                page:AddCheckbox(L["Mark old spell ranks"], On("spellRanks"), Setter("spellRanks", ns.RefreshSpellRanks),
                    Help(L["Small golden arrow on buttons whose spell has a higher rank you already know, and one notification when you learn one – click it to update your bars."]))
            end
            page:AddHeader(L["Micro menu"])
            page:AddDropdown(L["Visibility"], VisibilityItems,
                function() return ns.VisibilityMode(ns.db.microMenu) end,
                function(value) ns.db.microMenu = value; ns.UpdateMicroMenu() end)
            page:AddHeader(L["Addon buttons"])
            page:AddDropdown(L["Visibility"], VisibilityItems,
                function() return ns.VisibilityMode(ns.db.addonBar) end,
                function(value) ns.db.addonBar = value; if ns.UpdateAddonBar then ns.UpdateAddonBar() end end,
                Help(L["The minimap buttons of your other addons, as a row above the micro menu."]))
            -- show/hide each addon individually (list as of opening)
            for _, entry in ipairs(ns.AddonBarEntries and ns.AddonBarEntries() or {}) do
                page:AddCheckbox(entry.label,
                    function() return not ns.db.addonBarHidden[entry.key] end,
                    function(value)
                        ns.db.addonBarHidden[entry.key] = (not value) or nil
                        ns.UpdateAddonBar()
                    end)
            end
            LockForOther(page, "actionBarModule", barsFirst)
        end,
    },
    {
        key = "minimap", label = L["Minimap & info bar"],
        build = function(page)
            page:AddTitle(L["Minimap & info bar"], L["The minimap and everything attached to it."])
            page:AddDropdown(L["Texts and icons"], AlwaysOrHover, Getter("minimapExtras"), Setter("minimapExtras"),
                Help(L["Zone, clock, coordinates, tracking, addon menu and overview on the minimap."]))
            page:AddHeader(L["Progress bars"])
            page:AddDropdown(L["Visibility"], VisibilityItems,
                function() return ns.VisibilityMode(ns.db.xpBar.mode) end,
                function(value)
                    ns.db.xpBar.mode = value
                    ns.UpdateXPBar()
                    ns.UpdateTrackingBars()
                end,
                Help(L["Experience, reputation, honour and house favour below the minimap."]))
            page:AddDropdown(L["Quest XP"], QuestXPItems,
                function() return ns.db.xpBar.quests end,
                function(value) ns.db.xpBar.quests = value; ns.UpdateXPBar() end,
                Help(L["Shows the experience you would get from your quests as a lighter part of the bar."]))
            page:AddCheckbox(L["Show flight time"], On("flightTimer"), Setter("flightTimer"),
                Help(L["Bar at the top centre while you fly: destination and time left. The first flight on a route counts up, mUI then remembers its duration (for all characters)."]))
            page:AddHeader(L["Info bar"])
            page:AddDropdown(L["Visibility"], VisibilityItems,
                function() return ns.VisibilityMode(ns.db.infoBar.mode) end,
                function(value) ns.db.infoBar.mode = value; ns.UpdateInfoBar() end)
            local fields = {}
            for _, entry in ipairs({
                { "gold", L["Gold"] }, { "bags", L["Bags"] }, { "durability", L["Durability"] }, { "fps", "FPS" },
                { "spec", L["Spec"] }, { "guild", L["Guild"] }, { "friends", L["Friends"] }, { "time", L["Time"] },
                ns.IS_FOREVER and { "weaponskill", L["Weapon skill"] } or nil,
            }) do
                local key = entry[1]
                fields[#fields + 1] = {
                    label = entry[2],
                    get = function() return ns.db.infoBar.fields[key] end,
                    set = function(value) ns.db.infoBar.fields[key] = value; ns.UpdateInfoBar() end,
                }
            end
            page:AddCheckboxGrid(fields, 3)
        end,
    },
    {
        key = "chat", label = L["Chat"],
        build = function(page)
            page:AddTitle(L["Chat"], L["Text, sounds and extras of the chat window."])
            page:AddTextField(L["Nickname in guild chat"], function() return ns.root.nickname end,
                function(text) ns.root.nickname = text ~= "" and text or nil end, 24)
            page:AddDropdown(L["Font size"], StageItems, Getter("chatFontSize"), Setter("chatFontSize", ns.ApplyChatFont))
            page:AddCheckbox(L["Short channel names ([G], [P], [1] …)"], Getter("chatShortChannels"), Setter("chatShortChannels"))
            page:AddCheckbox(L["Class icons before names"], On("chatClassIcons"), Setter("chatClassIcons"),
                Help(L["Guild, group, raid and whispers. Not in Trade or General."]))
            page:AddCheckbox(L["Timestamps (12:04)"], Getter("chatTimestamps"), Setter("chatTimestamps", ns.ApplyChatTimestamps))
            page:AddCheckbox(L["Emojis as pictures"], On("chatEmoji"), Setter("chatEmoji"),
                Help(L[":D, :-D, <3, ^^ and real emojis become small pictures. Only players with mUI see them."], true))
            page:AddCheckbox(L["Reputation with a bar"], On("chatReputation"), Setter("chatReputation"),
                Help(L["Instead of Blizzard's line: gain, faction, a bar in the standing's color, progress and this session's total."], true))
            page:AddCheckbox(L["Sound when someone mentions you"], Getter("chatMentionSound"), Setter("chatMentionSound"),
                Help(L["Your name or nickname."]))
            page:AddCheckbox(L["Speech bubbles in mUI look"], On("chatBubbles"), Setter("chatBubbles"),
                Help(L["Flat box instead of Blizzard's ornate bubble. In dungeons and raids Blizzard locks the bubbles for addons – only the font changes there."], true))
            if ns.IS_FOREVER then
                page:AddCheckbox(L["Highlight group searches"], On("lfgHighlight"), Setter("lfgHighlight"),
                    Help(L["Someone looking for a group for a dungeon or raid that fits your level: the message gets a small marker with the dungeon's name."]))
            end
            page:AddHeader(L["Emote bar"])
            page:AddDropdown(L["Visibility"], VisibilityItems,
                function() return ns.VisibilityMode(ns.db.emoteBar or "hidden") end,
                function(value) ns.db.emoteBar = value; if ns.UpdateEmoteBar then ns.UpdateEmoteBar() end end,
                Help(L["Buttons for emotes with animation, for roleplay. With a target, the emote is aimed at it."]))
            -- Pick a theme, below it only its emotes (all themes share the same spot)
            local groupRows, selectedGroup = {}, 1
            local function ShowGroup(index)
                selectedGroup = index
                for i, rows in ipairs(groupRows) do
                    for _, row in ipairs(rows) do row:SetShown(i == index) end
                end
            end
            page:AddDropdown(L["Category"], function()
                local items = {}
                for i, group in ipairs(ns.EMOTE_GROUPS or {}) do items[#items + 1] = { value = i, label = L[group.title] } end
                return items
            end, function() return selectedGroup end, ShowGroup,
                Help(L["Up to 12 emotes on the bar, plus the RP mode button."]))
            local startY, maxY = page.y, page.y
            for i, group in ipairs(ns.EMOTE_GROUPS or {}) do
                page.y = startY
                local before = #page.items
                local emotes = {}
                for _, token in ipairs(group.list) do
                    emotes[#emotes + 1] = {
                        label = ns.EmoteLabel(token),
                        get = function() return ns.EmoteChosen(token) end,
                        -- twelve picked: the rest is greyed out until one is removed
                        disabled = function()
                            return not ns.EmoteChosen(token) and ns.EmoteChosenCount() >= ns.EMOTE_MAX
                        end,
                        set = function(value)
                            ns.db.emoteBarEmotes[token] = value
                            if ns.UpdateEmoteBar then ns.UpdateEmoteBar() end
                            page:Refresh() -- other checkboxes grey out or come back
                        end,
                    }
                end
                page:AddCheckboxGrid(emotes, 3)
                groupRows[i] = {}
                for j = before + 1, #page.items do groupRows[i][#groupRows[i] + 1] = page.items[j] end
                maxY = math.max(maxY, page.y)
            end
            page.y = maxY
            ShowGroup(1)
            page:AddHeader(L["RP mode"])
            page:AddNote(L["RP mode: hide everything except chat and emotes, also nameplates and names. Mask button at the end of the emote bar, /rp or your own key (Key Bindings > AddOns > MeredanUI). Combat ends it."])
            page:AddButton(L["Turn on RP mode"], function()
                if ns.HideSettings then ns.HideSettings() end
                ns.SetRPMode(true)
            end)
            page:AddHeader(L["Setup"])
            page:AddButton(L["Set up chat the mUI way"], function() ns.SetupChat() end)
            page:AddNote(L["One chat window plus Combat Log, channels in mUI colours. You leave Trade and General chat; join again anytime."])
            page:AddButton(L["Reset chat"], function() ns.ResetChat() end)
        end,
    },
    {
        key = "alerts", label = L["Alerts"],
        build = function(page)
            page:AddTitle(L["Alerts"], L["Pop-ups and messages from the game."])
            page:AddCheckbox(L["mUI alerts instead of Blizzard's pop-ups"], On("toasts"), Setter("toasts"),
                Help(L["Loot (rare and better, quest items always), gold, currencies, achievements, quests and level-ups. Right of the damage meter. Same things are combined; during boss fights they wait until the fight is over."], true))
            if ns.IS_FOREVER then
                page:AddCheckbox(L["Class trainer reminder"], On("trainerReminder"), Setter("trainerReminder"),
                    Help(L["On level-up: one notification when new spells are waiting at your class trainer."]))
                page:AddCheckbox(L["Buff reminder"], On("buffReminder"), Setter("buffReminder"),
                    Help(L["Your class buffs missing or with an old rank, weapon oil or stone run out. Not in combat or in cities."]))
                page:AddCheckbox(L["Profession reminder"], On("professionReminder"), Setter("professionReminder"),
                    Help(L["One notification when you can learn the next rank of a profession at the trainer – before the skill is capped."]))
            end
            page:AddCheckbox(L["Show the group's loot"], On("toastsGroupLoot"), Setter("toastsGroupLoot"),
                Help(L["In a group: who won a roll (hover shows every roll) and what others looted, from the same quality as your own loot."]))
            page:AddCheckbox(L["Repair warning"], On("durabilityWarning"), Setter("durabilityWarning"),
                Help(L["Once, when an item drops below 20 % durability."]))
            if type(Screenshot) == "function" then -- Forever: addons can't take screenshots
                page:AddCheckbox(L["Screenshot on new achievements"], On("achievementScreenshot"), Setter("achievementScreenshot"))
            end
            page:AddCheckbox(L["Combat message"], On("combatAlert"), Setter("combatAlert"),
                Help(L["Short \"+ Combat\" / \"− Combat\" above the middle of the screen."]))
            page:AddHeader(L["Blizzard noise"])
            page:AddCheckbox(L["Hide combat error messages"], On("hideErrors"),
                Setter("hideErrors", ns.ApplyErrorMessages),
                Help(L["Red text like \"Not enough energy\", \"Out of range\", \"Not ready yet\" while pressing keys. All other messages (bags full, quest progress …) stay. The character's voice is Blizzard's setting: Audio > Error speech."]))
            page:AddCheckbox(L["Skip cinematics you have seen"], Getter("skipCinematics"), Setter("skipCinematics"))
            page:AddCheckbox(L["Hide NPC speech pop-ups"], On("hideTalkingHead"), Setter("hideTalkingHead"),
                Help(L["The talking head that appears during quests and in dungeons."]))
        end,
    },
    {
        key = "bags", label = L["Bags"], group = L["Windows"],
        build = function(page)
            page:AddTitle(L["Bags"], L["One window for all bags, sorted into sections."])
            page:AddCheckbox(ModuleLabel(L["mUI bags"], "bags"), On("bags"), Setter("bags"), RELOAD)
            if ns.OtherAddonFor("bags") == "Bagnon" then
                page:AddCheckbox(L["Bagnon in the mUI look"], On("bagnonStyle"), Setter("bagnonStyle", ns.ApplyBagnonStyle),
                    Help(L["Flat mUI frame and font, fixed spot bottom right, tooltips above it."]))
            end
            local bagsFirst = #page.items + 1
            page:AddDropdown(L["Layout"], BagStyleItems, function() return ns.db.bagsStyle == "single" and "single" or "categories" end,
                Setter("bagsStyle", function() if ns.RefreshBags then ns.RefreshBags() end end),
                Help(L["Sections or one big bag. Alt+right-click an item to put it into your own section."]))
            page:AddCheckbox(L["Sell junk and repair at merchants"], On("bagsAutoJunk"), Setter("bagsAutoJunk"),
                Help(L["Repairs use the guild bank when allowed."]))
            page:AddCheckbox(L["Protect profession tools"], On("protectTools"), Setter("protectTools"),
                Help(L["Skinning knife, mining pick, blacksmith hammer, fishing poles and other tools can't be deleted by accident. Off: deleting asks with a big red warning instead."]))
            LockForOther(page, "bags", bagsFirst, #page.items)
            page:AddHeader(L["Loot"])
            page:AddCheckbox(L["mUI loot window"], On("lootWindow"), Setter("lootWindow"),
                Help(L["Slim loot window at the mouse instead of Blizzard's. Upgrades show an arrow."], true))
            page:AddCheckbox(L["mUI roll windows"], On("lootRolls"), Setter("lootRolls"),
                Help(L["Slim need/greed rows instead of Blizzard's group loot frames. Test mode shows examples."], true))
            page:AddCheckbox(L["Fast loot"], On("fastLoot"), Setter("fastLoot"),
                Help(L["With auto loot on, everything is picked up instantly instead of waiting for the loot window."]))
            if ns.IS_FOREVER then
                page:AddHeader(L["Fishing"])
                page:AddCheckbox(L["Fishing bag"], On("fishingBag"), Setter("fishingBag"),
                    Help(L["Opens when you equip a fishing pole: catches of this fishing trip, lures for the pole, fishing logbook. /mui angeln opens it."]))
                page:AddCheckbox(L["Double-click to cast"] .. "  |cff8a918e" .. L["Comfort"] .. "|r",
                    function() return ns.db.fishingDoubleClick == true end, Setter("fishingDoubleClick"),
                    Help(L["Double right-click in the world casts Fishing while a pole is equipped (out of combat)."]))
            end
            -- Restock at vendors (Forever only: ammo and reagents only exist there)
            if ns.IS_FOREVER then
                page:AddHeader(L["Restock at merchants"])
                page:AddCheckbox(L["Restock ammunition and reagents"], function() return ns.db.autoBuy == true end,
                    Setter("autoBuy"),
                    Help(L["Tops up to the amount you set: with 320 arrows and 1000 wanted, 680 are bought. Always the best ammunition you can use, matching your ranged weapon (bow/crossbow: arrows, gun: bullets); new ammunition is put into the ammo slot."]))
                local function Off(value) return value == 0 and L["Off"] or BreakUpLargeNumbers(value) end
                local function Amount(key, default)
                    return function() return ns.AutoBuyAmount(key, default) end,
                        function(value) ns.db.autoBuyAmounts[key] = value end
                end
                local _, myClass = UnitClass("player")
                local any = false
                for _, reagent in ipairs(ns.CLASS_REAGENTS[myClass] or {}) do
                    if reagent.ammo then
                        local get, set = Amount("ammo", ns.AUTOBUY_AMMO_DEFAULT)
                        page:AddSlider(L["Ammunition"], 0, 4000, 200, get, set, Off, ns.AUTOBUY_AMMO_DEFAULT)
                        any = true
                    elseif reagent.buy then
                        local get, set = Amount(reagent.item, reagent.buy)
                        local name = C_Item.GetItemNameByID(reagent.item) or ("Item " .. reagent.item)
                        page:AddSlider(name, 0, math.max(reagent.buy * 4, 20), 1, get, set, Off, reagent.buy)
                        any = true
                    end
                end
                if not any then page:AddNote(L["Your class has nothing to restock."]) end
            end
        end,
    },
    {
        key = "dungeons", label = L["Dungeons & raids"], group = L["Combat"],
        build = function(page)
            local function Live(key) return Setter(key, ns.RefreshMythicPlusDemo) end
            page:AddTitle(L["Dungeons & raids"], ns.IS_FOREVER and L["Damage meter."] or L["Boss timers, damage meter and Mythic+."])
            if not ns.IS_FOREVER then -- Forever has no Blizzard boss timeline/warnings
                page:AddHeader(L["Boss timers"])
                page:AddCheckbox(ModuleLabel(L["mUI boss timers and warnings"], "bossMods"), On("bossMods"), Setter("bossMods"),
                    Help(L["Uses Blizzard's own boss data (encounter timeline and warnings), the same data boss mods get in Midnight. Bars left of the player frame, big abilities at the top centre. Pull timer: /pull 10. Which warnings you see is set in Blizzard's options (Gameplay > Combat > Boss warnings)."], true))
                page:AddCheckbox(L["Warning sound before an ability"], On("bossModsSound"), Setter("bossModsSound"))
            end
            if ns.OtherAddonFor("bossMods") == "BigWigs" then
                if ns.IS_FOREVER then page:AddHeader(L["Boss timers"]) end
                page:AddCheckbox(L["BigWigs in the mUI look"], On("bigwigsStyle"), Setter("bigwigsStyle", function()
                    if ns.db.bigwigsStyle ~= false then ns.ApplyBigWigsProfile(true) end
                end), Help(L["Bar style \"MeredanUI\": flat bars above your player frame, big bars top centre, mUI font."]))
            end
            if ns.OtherAddonFor("bossMods") == "DBM-Core" then
                if ns.IS_FOREVER then page:AddHeader(L["Boss timers"]) end
                page:AddCheckbox(L["DBM in the mUI look"], On("dbmStyle"), Setter("dbmStyle", function()
                    if ns.db.dbmStyle ~= false then ns.ApplyDBMProfile(true) end
                end), Help(L["Own DBM profile \"MeredanUI\": flat bars left of the player frame, big bars top centre, mUI font. Your old DBM profile stays."]))
            end
            page:AddHeader(L["Damage meter"])
            page:AddCheckbox(ModuleLabel(L["mUI damage meter"], "damageMeter"), On("damageMeter"), Setter("damageMeter", function()
                if ns.SyncDamageMeterCVar then ns.SyncDamageMeterCVar() end
            end), Help(L["Own window top left with Blizzard's numbers. Also turns Blizzard's damage meter on or off (Options > Advanced)."], true))
            if ns.OtherAddonFor("damageMeter") == "Details" then
                page:AddCheckbox(L["Details! in the mUI look"], On("detailsStyle"), Setter("detailsStyle", ns.ApplyDetailsStyle),
                    Help(L["Flat mUI window, font and bars. Details' own settings stay usable."]))
            end
            page:AddCheckbox(L["Hide out of combat"], On("damageMeterFade"), Setter("damageMeterFade", function()
                if ns.ApplyDetailsStyle then ns.ApplyDetailsStyle() end -- Details follows the same switch
            end),
                Help(L["Mouse over shows it."]))
            page:AddCheckbox(L["Second window"], On("damageMeterSecond"), Setter("damageMeterSecond", function()
                if ns.RelayoutDamageMeter then ns.RelayoutDamageMeter() end
            end))
            LockForOther(page, "damageMeter", #page.items, #page.items)
            if not ns.IS_FOREVER then -- Forever has no Mythic+
                page:AddHeader(L["Mythic+"])
                page:AddCheckbox(L["Chest timers (+3 / +2)"], On("mplusChests"), Live("mplusChests"),
                    Help(L["Blizzard's Mythic+ block in the objective tracker, in the mUI look. Timer colour = the chest you still make."]))
                page:AddDropdown(L["Enemy forces"], ForcesItems, function() return ns.db.mplusForces or "detail" end, Live("mplusForces"))
                page:AddCheckbox(L["Boss kill times"], On("mplusSplits"), Live("mplusSplits"))
                page:AddCheckbox(L["Enemy forces in mob tooltips"], On("mplusMobTooltip"), Live("mplusMobTooltip"))
                page:AddCheckbox(L["Insert the keystone automatically"], On("mplusAutoKeystone"), Setter("mplusAutoKeystone"))
                page:AddCheckbox(L["Pick the only gossip option automatically"], On("mplusAutoGossip"), Setter("mplusAutoGossip"),
                    Help(L["In Mythic+ only, when an NPC offers a single dialogue option."]))
                page:AddCheckbox(L["Group keystones next to the Mythic+ window"], On("mplusGroupKeys"),
                    Setter("mplusGroupKeys", function() if ns.UpdateGroupKeystones then ns.UpdateGroupKeystones() end end))
            end
        end,
    },
    -- Bottom, subdued grey: Modules = own components, Skins = Blizzard frames in mUI style,
    -- Changelog. Profiles below.
    {
        -- opens the "New in mUI" window (Config/WhatsNew.lua) instead of a page; Blizzard's NEW badge
        -- until clicked once after an update with new entries
        key = "whatsnew", label = L["What's new"], extra = true, build = function() end,
        action = function() if ns.ShowWhatsNew then ns.ShowWhatsNew(nil, true) end end,
        badge = function() return ns.WhatsNewUnopened and ns.WhatsNewUnopened() end,
    },
    {
        key = "modules", label = L["Modules"], extra = true,
        build = function(page)
            page:AddTitle(L["Modules"], L["mUI's own building blocks. Turned off, Blizzard or another addon takes over. Takes effect after a reload."])
            page:AddNote(L["Always on: unit frames, minimap and chat."])
            local function Module(key, label, comfort)
                local other = ns.OtherAddonFor(key)
                if other then label = label .. "  |cff8a918e" .. L["%s active"]:format(ns.OtherAddonTitle(other)) .. "|r" end
                return { label = comfort and (label .. "  |cff8a918e" .. L["Comfort"] .. "|r") or label,
                    get = function() return ns.db[key] ~= false end, set = Setter(key), opts = RELOAD }
            end
            page:AddHeader(L["Frames"])
            page:AddCheckboxGrid({
                Module("groupFrames", L["Group & raid frames"]),
                Module("groupManager", L["Group tools"]),
                Module("nameplates", L["Nameplates"]),
                Module("bossMods", L["Boss timers"]),
            }, 2)
            page:AddHeader(L["Screen"])
            page:AddCheckboxGrid({
                Module("actionBarModule", L["Action bars"]),
                Module("toasts", L["Alerts"]),
                Module("damageMeter", L["Damage meter"]),
            }, 2)
            page:AddHeader(L["Bags & loot"])
            page:AddCheckboxGrid({
                Module("bags", L["Bags & bank"]),
                Module("lootWindow", L["Loot window"]),
                Module("lootRolls", L["Roll windows"]),
                { label = L["Upgrade arrows"] .. "  |cff8a918e" .. L["Comfort"] .. "|r",
                    get = function() return ns.db.upgrades ~= "off" end,
                    set = function(value) ns.db.upgrades = value and "damage" or "off" end },
            }, 2)
            -- Another addon for the same job (Core/OtherAddons.lua): pick mUI or the addon
            local found = ns.OtherAddonsFound()
            if #found > 0 then
                page:AddHeader(L["Other addons"])
                for _, entry in ipairs(found) do
                    local areaID, title = entry.area.id, ns.OtherAddonTitle(entry.addon)
                    local picked = "addon" -- the addon is running; "mUI" disables it for this character
                    page:AddDropdown(entry.area.label, function()
                        return { { value = "addon", label = title }, { value = "mui", label = "mUI" } }
                    end, function() return picked end, function(value)
                        picked = value
                        if value == "mui" then ns.ChooseOtherAddon(areaID, "mui") else
                            C_AddOns.EnableAddOn(entry.addon, UnitName("player"))
                        end
                    end, RELOAD)
                end
            end
        end,
    },
    {
        key = "skins", label = L["Skins"], extra = true,
        build = function(page)
            page:AddTitle(L["Skins"], L["Blizzard windows in the mUI look. Turned off, the game shows the original again. Takes effect after a reload."])
            if not ns.IS_FOREVER then
                page:AddNote(L["Only in WoW Forever for now."])
                return
            end
            page:AddCheckbox(L["All skins"], function()
                for _, entry in ipairs(WINDOWS) do
                    if ns.db[entry[1]] == false then return false end
                end
                return true
            end, function(value)
                for _, entry in ipairs(WINDOWS) do ns.db[entry[1]] = value end
                page:Refresh()
            end, RELOAD)
            for _, group in ipairs(SKIN_GROUPS) do
                page:AddHeader(group[1])
                local entries = {}
                for _, key in ipairs(group[2]) do
                    local entry = WINDOW_BY_KEY[key]
                    if entry then
                        local label = L[entry[2]]
                        -- another auction house addon is active: show a notice, ours stays off
                        local other = (key == "auctionWindow" and ns.OtherAddon(ns.AUCTION_ADDONS))
                            or (key == "mailWindow" and ns.OtherAddon(ns.MAIL_ADDONS))
                        if other then label = label .. "  |cffd9b25b" .. L["%s active"]:format(other) .. "|r" end
                        entries[#entries + 1] = { label = label, get = function() return ns.db[key] ~= false end,
                            set = Setter(key), opts = Help(L[entry[3]], true) }
                    end
                end
                page:AddCheckboxGrid(entries, 3)
            end
        end,
    },
    {
        key = "changelog", label = L["Changelog"], extra = true,
        build = function(page)
            page:AddTitle(L["Changelog"], L["What changed in the latest versions. Same text as on CurseForge."])
            for _, release in ipairs(ns.CHANGELOG or {}) do
                local current = release.version == ns.VERSION or ns.VERSION:find("^" .. release.version:gsub("%p", "%%%0") .. "%+")
                page:AddHeader(release.version .. (current and ("   |cff8ecbb4" .. L["installed"] .. "|r") or ""))
                for _, item in ipairs(release.items) do page:AddNote("•  " .. item) end
            end
        end,
    },
    {
        key = "profiles", label = L["Profiles"], bottom = true, -- bottom of the navigation
        build = function(page)
            local Profiles = ns.Profiles
            local function ProfileItems(extra)
                local items = extra and { extra } or {}
                for _, name in ipairs(Profiles.List()) do items[#items + 1] = { value = name, label = name } end
                return items
            end

            page:AddTitle(L["Profiles"], L["A profile holds all your settings, including the layout. Each character uses one. Switching reloads the UI."])
            page:AddButton(L["Run the setup again"], function() ns.OpenSetup() end)
            -- Layout = where everything sits (Core/Layouts.lua), part of the profile; switches without reload
            page:AddDropdown(L["Screen layout"], function()
                local items = {}
                for _, layout in ipairs(ns.LAYOUTS) do items[#items + 1] = { value = layout.id, label = layout.name } end
                return items
            end, function() return ns.CurrentLayout().id end, function(id) ns.SetLayout(id) end, RELOAD)
            page:AddDropdown(L["Profile of this character"], ProfileItems, function() return ns.char.profile end,
                function(name) Profiles.Switch(name) end)
            page:AddCheckbox(L["Default for new characters"],
                function() return ns.root.newCharProfile == ns.profileName end,
                function(value) ns.root.newCharProfile = value and ns.profileName or nil end)
            page:AddInput(L["New profile (copy of the current one)"], L["Create"], function(text)
                local name = Profiles.Create(text)
                if name then
                    ns.Print(L["Profile \"%s\" created."], name)
                    return true
                end
                ns.Print(L["Please enter a name that is not taken yet."])
            end)
            page:AddInput(L["Rename current profile"], L["Rename"], function(text)
                if Profiles.IsBuiltin(ns.profileName) then
                    ns.Print(L["\"Standard\" can't be renamed. Create a copy instead."])
                    return
                end
                local name = Profiles.Rename(ns.profileName, text)
                if name then
                    ns.Print(L["Profile renamed to \"%s\"."], name)
                    page:Refresh()
                    return true
                end
                ns.Print(L["Please enter a name that is not taken yet."])
            end)

            local toDelete
            page:AddDropdown(L["Delete profile"], function()
                local items = {}
                for _, name in ipairs(Profiles.List()) do
                    if name ~= ns.profileName and not Profiles.IsBuiltin(name) then
                        items[#items + 1] = { value = name, label = name }
                    end
                end
                return items
            end, function() return toDelete or "" end, function(name) toDelete = name end)
            page:AddButton(L["Delete"], function()
                if toDelete and Profiles.Delete(toDelete) then
                    ns.Print(L["Profile \"%s\" deleted."], toDelete)
                    toDelete = nil
                    page:Refresh()
                end
            end)

            -- Automatic per specialization (default off)
            local specs = Profiles.Specs()
            if #specs > 0 then
                page:AddHeader(L["Specialization"])
                page:AddCheckbox(L["Switch profile with the specialization"],
                    function() return ns.char.specAuto end,
                    function(value) ns.char.specAuto = value end)
                for _, spec in ipairs(specs) do
                    page:AddDropdown(spec.name,
                        function() return ProfileItems({ value = "", label = L["(no change)"] }) end,
                        function() return ns.char.specProfiles[spec.index] or "" end,
                        function(name) ns.char.specProfiles[spec.index] = name ~= "" and name or nil end)
                end
            end

            -- Before uninstalling: game settings and chat back to Blizzard's defaults (Core/BlizzardReset.lua)
            page:AddHeader(L["Back to Blizzard"])
            page:AddButton(L["Reset game settings and turn mUI off"], function() ns.ConfirmBackToBlizzard() end)
        end,
    },
}

-- Quest tracker (Forever: own tracker, Quests/Tracker.lua), after "Minimap & info bar"
if ns.IS_FOREVER then
    local function TrackerSetter(key) return Setter(key, function() if ns.RefreshTracker then ns.RefreshTracker() end end) end
    local function SortItems()
        local items = {
            { value = "standard", label = L["Standard"] },
            { value = "level", label = L["By level"] },
            { value = "progress", label = L["By progress"] },
        }
        if ns.Questie and ns.Questie.IsLoaded() then items[#items + 1] = { value = "distance", label = L["By distance"] } end
        return items
    end
    local index = #PAGES + 1
    for i, entry in ipairs(PAGES) do if entry.key == "minimap" then index = i + 1 end end
    table.insert(PAGES, index, {
        key = "quests", label = L["Quests"],
        build = function(page)
            page:AddTitle(L["Quests"], L["The quest tracker on the right."])
            page:AddCheckbox(L["Track new quests automatically"], function() return GetCVarBool("autoQuestWatch") end,
                function(value) SetCVar("autoQuestWatch", value and "1" or "0") end)
            page:AddDropdown(L["Sort"], SortItems, function() return ns.db.trackerSort or "standard" end, TrackerSetter("trackerSort"),
                Help(L["The focus quest always stays on top."]))
            page:AddCheckbox(L["Group by zone"], function() return ns.db.trackerGroupZone == true end, TrackerSetter("trackerGroupZone"))
            page:AddCheckbox(L["Show quest level"], On("trackerShowLevel"), TrackerSetter("trackerShowLevel"))
            page:AddCheckbox(L["Hide finished objectives"], function() return ns.db.trackerHideDoneGoals == true end,
                TrackerSetter("trackerHideDoneGoals"))
            page:AddCheckbox(L["Collapse finished quests"], function() return ns.db.trackerCollapseDone == true end,
                TrackerSetter("trackerCollapseDone"))
            page:AddCheckbox(L["Collapse in combat"], function() return ns.db.trackerCombatCollapse == true end,
                TrackerSetter("trackerCombatCollapse"))
            page:AddHeader(L["Helpers"])
            page:AddCheckbox(L["Accept quests automatically"], Getter("questAutoAccept"), Setter("questAutoAccept"),
                Help(L["Grey quests are skipped. Hold Shift to talk normally."]))
            page:AddCheckbox(L["Hand in quests automatically"], Getter("questAutoTurnIn"), Setter("questAutoTurnIn"),
                Help(L["Not when you have to pick a reward or the quest costs gold or materials."]))
            page:AddCheckbox(L["Mark the most valuable reward"], On("questBestReward"), Setter("questBestReward"),
                Help(L["Gold coin on the reward that sells for the most."]))
            page:AddCheckbox(L["Skip single conversation options"], Getter("questAutoGossip"), Setter("questAutoGossip"),
                Help(L["NPCs without quests and only one chat option. Never merchants, trainers or flight masters."]))
            if ns.IS_FOREVER then
                page:AddCheckbox(L["Remind me of class quests"], Getter("classQuestReminder"), Setter("classQuestReminder"),
                    Help(L["When a class quest for a new ability becomes available, e.g. Bear Form or the Voidwalker. Click the message to put a pin on the map."]))
            end
            page:AddCheckbox(L["Sparkle on herbs, ore and quest objects"], Getter("sparkle"),
                Setter("sparkle", function() if ns.UpdateSparkle then ns.UpdateSparkle() end end),
                Help(L["The nearest object you can use glitters: green herbs, orange ore, red for skinning, yellow quest objects. Dimmed while out of reach. Off in combat."]))
            page:AddCheckbox(L["Also other objects (benches, chests, mailboxes)"], Getter("sparkleOther"),
                Setter("sparkleOther", function() if ns.UpdateSparkle then ns.UpdateSparkle() end end))
            if ns.Questie and ns.Questie.IsLoaded() then
                page:AddHeader("Questie")
                page:AddCheckbox(L["Next objective with distance"], On("trackerQuestieDistance"), TrackerSetter("trackerQuestieDistance"))
                page:AddCheckbox(L["Direction arrow"], On("trackerQuestieArrow"), TrackerSetter("trackerQuestieArrow"))
                page:AddCheckbox(L["Turn-in NPC"], On("trackerQuestieTurnIn"), TrackerSetter("trackerQuestieTurnIn"))
                page:AddCheckbox(L["Quest items from Questie"], On("trackerQuestieItems"), TrackerSetter("trackerQuestieItems"))
            end
        end,
    })
end

-- Window -------------------------------------------------------------------------------

local function SelectPage(key)
    for _, each in ipairs(PAGES) do
        local selected = each.key == key
        each.page:SetShown(selected)
        each.nav.text:SetTextColor(unpack(selected and UI.ACCENT or (each.extra and UI.MUTED or UI.TEXT)))
        each.nav.marker:SetShown(selected)
        each.nav.selected:SetShown(selected)
        if selected then
            each.page:Refresh()
            window.scroll:SetContentHeight(each.page.y)
            window.scroll:ScrollToTop()
        end
    end
    window.current = key
    window.UpdatePreviewButton()
end

local function CreateWindow()
    window = CreateFrame("Frame", "MeredanUIOptions", UIParent)
    -- lower on small screens / large UI scale; the content scrolls then
    window:SetSize(WIDTH, math.min(HEIGHT, UIParent:GetHeight() - 120))
    window:SetPoint("TOP", UIParent, "TOP", 0, -160) -- above the frames so they stay visible
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    UI.Box(window, { 0.05, 0.05, 0.06, 0.97 })
    tinsert(UISpecialFrames, "MeredanUIOptions") -- Esc closes

    -- Title: "Meredan" light, "UI" in Surf Green
    local title = UI.Text(window, 18, "LEFT")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Meredan|cff8ecbb4UI|r")
    local version = UI.Text(window, 11, "LEFT", UI.MUTED)
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetText(ns.VERSION)

    local close = UI.IconButton(window, "Close", function() window:Hide() end, 24)
    close:SetPoint("TOPRIGHT", -10, -10)

    -- Collapse during preview: only the header stays, semi-transparent (opaque on mouseover)
    -- - so the whole preview is visible
    local COLLAPSED_HEIGHT, COLLAPSED_ALPHA = 44, 0.55
    local collapsed, fullHeight, hiddenChildren = false, nil, {}
    local collapse, previewButton
    local keep = {}
    local function SetCollapsed(state)
        if state == collapsed then return end
        collapsed = state
        if state then
            fullHeight = window:GetHeight()
            wipe(hiddenChildren)
            for _, child in ipairs({ window:GetChildren() }) do
                if not keep[child] and child:IsShown() then
                    hiddenChildren[#hiddenChildren + 1] = child
                    child:Hide()
                end
            end
            window:SetHeight(COLLAPSED_HEIGHT)
            window:SetScript("OnUpdate", function(self)
                self:SetAlpha(self:IsMouseOver() and 1 or COLLAPSED_ALPHA)
            end)
        else
            window:SetScript("OnUpdate", nil)
            window:SetAlpha(1)
            if fullHeight then window:SetHeight(fullHeight) end
            for _, child in ipairs(hiddenChildren) do child:Show() end
            wipe(hiddenChildren)
        end
        collapse.icon:SetTexture(ns.MEDIA .. "Icons\\" .. (state and "Plus" or "Minus"))
    end
    collapse = UI.IconButton(window, "Minus", function() SetCollapsed(not collapsed) end, 24)
    -- only shown during preview: left of "Preview" so that one stays next to the X
    collapse:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(collapsed and L["Expand"] or L["Collapse"])
        GameTooltip:Show()
    end)
    collapse:HookScript("OnLeave", function() GameTooltip:Hide() end)
    collapse:Hide()

    -- one preview for everything; collapsing only exists while it runs
    function window.UpdatePreviewButton()
        local active = ns.Preview.IsActive()
        previewButton.Text:SetText(active and L["Stop preview"] or L["Preview"])
        previewButton.Text:SetTextColor(unpack(active and UI.ACCENT or UI.TEXT))
        collapse:SetShown(active)
        if not active then SetCollapsed(false) end
    end
    -- one preview for everything (Core/Preview.lua), always in this spot; keeps running after
    -- closing (/mui t ends it)
    previewButton = UI.Button(window, "", function()
        ns.Preview.Toggle()
        window.UpdatePreviewButton()
    end, 170)
    previewButton:SetPoint("RIGHT", close, "LEFT", -6, 0)
    collapse:SetPoint("RIGHT", previewButton, "LEFT", -6, 0)
    for _, frame in ipairs({ close, collapse, previewButton }) do keep[frame] = true end
    ns.OnPreviewChanged = window.UpdatePreviewButton -- also on /mui t and entering combat

    -- Navigation on the left: sections in groups, profiles at the bottom
    local nav = CreateFrame("Frame", nil, window)
    nav:SetPoint("TOPLEFT", 10, -48)
    nav:SetPoint("BOTTOMLEFT", 10, 10)
    nav:SetWidth(NAV_WIDTH)
    UI.Box(nav, { 0.08, 0.08, 0.09, 1 })

    -- Reload bar bottom right: appears once a badged option was changed
    local reloadBar = CreateFrame("Frame", nil, window)
    reloadBar:SetHeight(32)
    reloadBar:SetPoint("BOTTOMLEFT", nav, "BOTTOMRIGHT", 20, 0)
    reloadBar:SetPoint("BOTTOMRIGHT", -10, 10)
    UI.Box(reloadBar, { 0.1, 0.09, 0.06, 1 })
    for _, edge in ipairs(ns.AddBorder(reloadBar, true)) do edge:SetVertexColor(unpack(UI.TAG)) end
    local reloadText = UI.Text(reloadBar, 12, "LEFT")
    reloadText:SetPoint("LEFT", 10, 0)
    reloadText:SetPoint("RIGHT", -240, 0)
    reloadText:SetWordWrap(false)
    local reloadNow = UI.Button(reloadBar, L["Reload UI now"], ReloadUI, 120)
    reloadNow:SetPoint("RIGHT", -6, 0)
    reloadBar:Hide()

    -- Content on the right, scrolls for long pages; shorter with the bar at the bottom
    local scroll = UI.ScrollArea(window)
    scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", 20, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 16)
    scroll.child:SetWidth(CONTENT_WIDTH) -- set before building so hints wrap correctly
    window.scroll = scroll
    local content = scroll.child

    local pending, pendingOrder = {}, {}
    local function ShowReloadBar(shown)
        reloadBar:SetShown(shown)
        scroll:SetPoint("BOTTOMRIGHT", -28, shown and 52 or 16)
    end
    UI.MarkReload = function(label)
        if not pending[label] then
            pending[label] = true
            pendingOrder[#pendingOrder + 1] = label
        end
        reloadText:SetText(L["Needs a reload: %s"]:format(table.concat(pendingOrder, ", ")))
        ShowReloadBar(true)
    end
    local later = UI.Button(reloadBar, L["Later"], function()
        wipe(pending)
        wipe(pendingOrder)
        ShowReloadBar(false)
    end, 90)
    later:SetPoint("RIGHT", reloadNow, "LEFT", -6, 0)

    local y = 1
    local bottom = 0
    local extras = {}
    for _, entry in ipairs(PAGES) do
        if entry.group then
            local header = UI.Text(nav, 10, "LEFT", UI.MUTED)
            header:SetPoint("TOPLEFT", 12, -y - 9)
            header:SetText(entry.group:upper())
            y = y + NAV_GROUP
        end
        local button = CreateFrame("Button", nil, nav)
        button:SetHeight(entry.extra and NAV_SMALL or NAV_ROW)
        if entry.bottom then
            button:SetPoint("BOTTOMLEFT", 1, 1 + bottom * NAV_ROW)
            button:SetPoint("BOTTOMRIGHT", -1, 1 + bottom * NAV_ROW)
            bottom = bottom + 1
        elseif entry.extra then
            extras[#extras + 1] = button -- spacing only after the loop (above Profiles)
        else
            button:SetPoint("TOPLEFT", 1, -y)
            button:SetPoint("TOPRIGHT", -1, -y)
            y = y + NAV_ROW
        end
        local hover = button:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(unpack(UI.HOVER))
        hover:Hide()
        button.selected = button:CreateTexture(nil, "BACKGROUND", nil, 1) -- selected section, slightly brighter
        button.selected:SetAllPoints()
        button.selected:SetColorTexture(1, 1, 1, 0.06)
        button.selected:Hide()
        button.marker = button:CreateTexture(nil, "ARTWORK")
        button.marker:SetColorTexture(unpack(UI.ACCENT))
        button.marker:SetPoint("TOPLEFT")
        button.marker:SetPoint("BOTTOMLEFT")
        button.marker:SetWidth(2)
        button.text = UI.Text(button, entry.extra and 12 or 13, "LEFT", entry.extra and UI.MUTED or nil)
        button.text:SetPoint("LEFT", 12, 0)
        button.text:SetPoint("RIGHT", -6, 0) -- in case a translation is too long: truncate instead of overlapping
        button.text:SetWordWrap(false)
        button.text:SetText(entry.label)
        button:SetScript("OnEnter", function() hover:Show() end)
        button:SetScript("OnLeave", function() hover:Hide() end)
        button:SetScript("OnClick", function()
            if not entry.action then return SelectPage(entry.key) end
            entry.action()
            if button.badge then button.badge:SetShown(entry.badge()) end
        end)
        if entry.badge then
            local badge = CreateFrame("Frame", nil, button, "NewFeatureLabelTemplate")
            badge:SetScale(0.8)
            badge:SetPoint("LEFT", button.text, "LEFT", (button.text:GetUnboundedStringWidth() + 10) / 0.8, 0)
            badge:SetShown(entry.badge())
            button.badge = badge
            button:HookScript("OnShow", function() badge:SetShown(entry.badge()) end)
        end
        entry.nav = button

        entry.page = UI.Page(content)
        entry.build(entry.page)
    end
    -- Window grows with the navigation so new entries always fit:
    -- 48 px header, entries, gap to the bottom entries, 10 px bottom margin.
    -- Modules/Skins/Changelog above Profiles, top first; a divider above and below each
    local base = 1 + bottom * NAV_ROW
    for i, button in ipairs(extras) do
        local offset = base + 6 + (#extras - i) * NAV_SMALL
        button:SetPoint("BOTTOMLEFT", 1, offset)
        button:SetPoint("BOTTOMRIGHT", -1, offset)
    end
    local extraHeight = #extras > 0 and (#extras * NAV_SMALL + 12) or 0
    local needed = 48 + y + 16 + bottom * NAV_ROW + extraHeight + 2 + 10
    window:SetHeight(math.min(math.max(HEIGHT, needed), UIParent:GetHeight() - 40))
    local function Line(offset)
        local line = nav:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 0.08)
        line:SetPoint("BOTTOMLEFT", 1, offset)
        line:SetPoint("BOTTOMRIGHT", -1, offset)
        line:SetHeight(ns.PixelSize())
    end
    Line(base) -- above Profiles
    if #extras > 0 then Line(base + extraHeight) end -- above Modules

    window:SetScript("OnShow", function()
        SelectPage(window.current or PAGES[1].key)
    end)
    window:SetScript("OnHide", function()
        UI.CloseList()
    end)
    window:Hide()
end

function ns.OpenSettings()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
end

-- Open settings, optionally on a specific section (e.g. from the minimap)
function ns.ShowSettings(key)
    if not window then CreateWindow() end
    window.current = key or window.current
    if window:IsShown() then SelectPage(window.current) else window:Show() end
end
ns.OnCompartmentClick = ns.OpenSettings

-- Hide the window (e.g. before RP mode).
function ns.HideSettings()
    if window then window:Hide() end
end
