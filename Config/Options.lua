-- Eigenes Einstellungsfenster im MeredanUI-Look: links die Bereiche in Gruppen, rechts die Seite.
-- Öffnen: /mui, Klick im Addon-Menü an der Minimap oder Button im Blizzard-Menü.
--
-- Aufbau jeder Seite (UX-Überarbeitung, Benny, 2026-10-25): Titel + ein Satz, was das ist. Dann der
-- Ein/Aus-Schalter des Moduls (wenn es einen gibt), dann die Optionen. Erklärungen stecken im „i“
-- am Label (Tooltip), nicht als Absätze. Optionen, die ein Neuladen brauchen, tragen die Marke
-- „RELOAD“; unten erscheint dann eine Leiste mit „Reload UI“. Der Knopf oben rechts startet die
-- Vorschau.
--
-- Verschlankt (Benny 2026-11-07): jedes Element behält eine eigene Einstellung, aber nur als
-- Schalter, wenige Stufen oder kleine Auswahl – keine Regler für Optik. Reine Optik-Zahlen
-- (Schrift, Textur, Abstände, Größen der Gruppenframes …) sind fest.
local _, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT, NAV_WIDTH = 860, 640, 220 -- Benny 2026-11-08: größer, weniger gedrängt (Entwurf Canvas „Einstellungen“)
local CONTENT_WIDTH = WIDTH - 10 - NAV_WIDTH - 20 - 28 -- rechts Platz für die Scroll-Leiste
local NAV_ROW, NAV_GROUP, NAV_SMALL = 26, 24, 22 -- NAV_SMALL: Module/Skins/Changelog unten, dezent
local window

-- Auswahllisten ------------------------------------------------------------------------

local function ThemeItems()
    local items = {}
    for _, key in ipairs(ns.THEME_ORDER) do items[#items + 1] = { value = key, label = ns.THEMES[key].name } end
    return items
end

-- Stufen Klein/Mittel/Groß (bzw. Klein/Normal/Groß bei den Unitframes)
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

-- Sichtbarkeit (Leisten): Immer / Mouseover / Aus
local function VisibilityItems()
    return {
        { value = "always", label = L["Always"] },
        { value = "mouseover", label = L["Mouseover"] },
        { value = "hidden", label = L["Hidden"] },
    }
end

-- Aktionsleisten: zusätzlich „Im Kampf“ (außerhalb ausgeblendet, per Maus sichtbar)
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
        { value = "categories", label = L["Sections (like BetterBags)"] },
        { value = "single", label = L["One big bag"] },
        { value = "separate", label = L["Separate bags"] },
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

-- Wert in ns.db lesen/schreiben, optional danach etwas ausführen
local function Getter(key) return function() return ns.db[key] end end
local function On(key) return function() return ns.db[key] ~= false end end -- Standard an
local function Setter(key, after)
    return function(value)
        ns.db[key] = value
        if after then after() end
    end
end
local RELOAD = { reload = true }
local function Help(text, reload) return { help = text, reload = reload } end

-- Eigene Fenster (Forever): Schlüssel in ns.db, Label, Erklärung
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
    { "guildWindow", "mUI guild window", "Guild & Communities in the mUI look: community list, chat, roster with details, info and news, preferred play settings and guild settings (ranks, permissions, bank tabs, Discord)." },
    { "characterWindow", "mUI character window", "Character, reputation, skills, PvP, currencies and statistics in the mUI look." },
    { "auctionWindow", "mUI auction house", "Auction house in the mUI look: buy with categories and favorites, sell with price suggestion and net breakdown, your auctions and bids, plus a history with income, expenses and fees." },
    { "merchantWindow", "mUI merchant window", "Own merchant window in the bag look instead of Blizzard's: cards in two columns, search, buyback, repair and sell junk." },
}
local WINDOW_BY_KEY = {}
for _, entry in ipairs(WINDOWS) do WINDOW_BY_KEY[entry[1]] = entry end
-- Skins-Seite in Gruppen (Entwurf Canvas „Einstellungen“, Benny 2026-11-08)
local SKIN_GROUPS = {
    { L["Character"], { "characterWindow", "spellbookWindow", "talentWindow", "professionWindow", "legacyWindow" } },
    { L["World"], { "mapWindow", "flightWindow" } },
    { L["NPCs"], { "merchantWindow", "trainerWindow", "gossipWindow", "questWindow", "mailWindow", "tradeWindow", "auctionWindow" } },
    { L["Social"], { "friendsWindow", "guildWindow", "skinDialogs" } },
}

-- Seiten -------------------------------------------------------------------------------
-- key bleibt stabil (ShowSettings(key)); group = Überschrift in der Navigation;
-- bottom = unten in der Navigation. Vorschau: ein Knopf oben rechts für alles (Core/Preview.lua).

local PAGES = {
    {
        key = "appearance", label = L["Appearance"],
        build = function(page)
            page:AddTitle(L["Appearance"], L["Size, font size and colours of everything mUI draws."])
            -- Größe der Oberfläche (account-weit, Core/Style.lua); 1-px-Rahmen brauchen ein Neuladen
            page:AddDropdown(L["Size"], StageItems, function() return ns.root.uiSize or "medium" end, function(value)
                ns.root.uiSize = value ~= "medium" and value or nil
                ns.ApplyUIScale()
                ns.Relayout()
            end, RELOAD)
            -- Schriftgröße aller mUI-Texte (pro Profil); manches (Tooltip, Toasts …) erst nach dem Neuladen
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
                Help(L["Class colour: health in class colour. Dark: dark health bars, class-coloured power. Classic green: green health bars."]))
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
            -- Vor- und Nachname gibt es nur in Forever; gilt für alle Frames und Namensplaketten
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
            -- Munition & Reagenzien gibt es nur in Forever (Vorschau überall)
            page:AddHeader(L["Class reagents"])
            if ns.IS_FOREVER then
                page:AddCheckbox(L["Show class reagents"], On("ammoCounter"), Setter("ammoCounter", ns.UpdateAmmoCounter),
                    Help(L["Ammunition and spell reagents of your class (soul shards, runes, candles …) next to the player frame. Warns when they run low."]))
            else
                page:AddNote(L["Only in WoW Forever – Retail has no ammunition or reagents like these."])
            end
            -- welche Reagenzien angezeigt werden – nur für die eigene Klasse
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
            page:AddCheckbox(L["Ready check: remind me of missing food, flask and rune"], On("readyCheckReminder"),
                Setter("readyCheckReminder"))
            page:AddHeader(L["Preview"])
            -- Größe in der Vorschau (Gruppe und Schlachtzug gehen nicht gleichzeitig)
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
            page:AddTitle(L["Nameplates"], ns.IS_FOREVER -- Forever: kein Mythisch+
                and L["Enemy plates with priority colours, interrupt-ready cast bar and your debuffs. Friendly plates show names only."]
                or L["Enemy plates with priority colours, interrupt-ready cast bar, Mythic+ percentage and your debuffs. Friendly plates show names only."])
            page:AddCheckbox(L["mUI nameplates"], On("nameplates"), Setter("nameplates"), RELOAD)
            page:AddCheckbox(L["Rare and elite symbol"], On("plateClassification"), Setter("plateClassification"),
                Help(L["Blizzard's star or dragon in front of the name. Elite only outside dungeons and raids – almost everything is elite there."]))
        end,
    },
    {
        key = "auras", label = L["Buffs & debuffs"],
        build = function(page)
            local function Live(key) return Setter(key, ns.RefreshAurasDemo) end -- Vorschau zeigt Änderungen sofort
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
            page:AddHeader(L["Players"])
            page:AddCheckbox(L["Item level"], On("tooltipItemLevel"), Live("tooltipItemLevel"))
            if not ns.IS_FOREVER then -- Forever: kein Mythisch+
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
            page:AddDropdown(L["Arrangement"], function()
                return {
                    { value = "center", label = L["Centre (2 × 6)"] },
                    { value = "stacked", label = L["Stacked (3 × 12 at the bottom)"] },
                }
            end, Getter("barVariant"), Setter("barVariant"),
                Help(L["Centre: main bar between player and target. Stacked: three rows of 12 at the bottom. The healer layout is always stacked."], true))
            for _, key in ipairs({ "bar1", "bar2", "bar3", "bar4", "bar5", "petbar", "stancebar", "bar6", "bar7", "bar8" }) do
                if key == "bar6" then page:AddHeader(L["Extra bars"]) end
                -- links Sichtbarkeit, rechts Texte auf den Knöpfen mit Haken (Benny 2026-11-08)
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
            page:AddHeader(L["Settings"]) -- gilt für alle Leisten, nicht nur die Zusatzleisten
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
            -- jedes Addon einzeln ein-/ausblenden (Liste zum Zeitpunkt des Öffnens)
            for _, entry in ipairs(ns.AddonBarEntries and ns.AddonBarEntries() or {}) do
                page:AddCheckbox(entry.label,
                    function() return not ns.db.addonBarHidden[entry.key] end,
                    function(value)
                        ns.db.addonBarHidden[entry.key] = (not value) or nil
                        ns.UpdateAddonBar()
                    end)
            end
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
            -- Thema wählen, darunter nur dessen Emotes (alle Themen liegen an derselben Stelle)
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
            end, function() return selectedGroup end, ShowGroup)
            local startY, maxY = page.y, page.y
            for i, group in ipairs(ns.EMOTE_GROUPS or {}) do
                page.y = startY
                local before = #page.items
                local emotes = {}
                for _, token in ipairs(group.list) do
                    emotes[#emotes + 1] = {
                        label = ns.EmoteLabel(token),
                        get = function()
                            local choice = ns.db.emoteBarEmotes[token]
                            if choice == nil then return ns.EMOTE_DEFAULTS[token] or false end
                            return choice
                        end,
                        set = function(value)
                            ns.db.emoteBarEmotes[token] = value
                            if ns.UpdateEmoteBar then ns.UpdateEmoteBar() end
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
                page:AddCheckbox(L["Profession reminder"], On("professionReminder"), Setter("professionReminder"),
                    Help(L["One notification when you can learn the next rank of a profession at the trainer – before the skill is capped."]))
            end
            page:AddCheckbox(L["Show the group's loot"], On("toastsGroupLoot"), Setter("toastsGroupLoot"),
                Help(L["In a group: who won a roll (hover shows every roll) and what others looted, from the same quality as your own loot."]))
            page:AddCheckbox(L["Repair warning"], On("durabilityWarning"), Setter("durabilityWarning"),
                Help(L["Once, when an item drops below 20 % durability."]))
            if type(Screenshot) == "function" then -- Forever: Addons dürfen keine Screenshots machen
                page:AddCheckbox(L["Screenshot on new achievements"], On("achievementScreenshot"), Setter("achievementScreenshot"))
            end
            page:AddCheckbox(L["Combat message"], On("combatAlert"), Setter("combatAlert"),
                Help(L["Short \"+ Combat\" / \"− Combat\" above the middle of the screen."]))
            page:AddHeader(L["Blizzard noise"])
            page:AddCheckbox(L["Hide combat error messages"], On("hideErrors"),
                Setter("hideErrors", ns.ApplyErrorMessages),
                Help(L["Red text like \"Not enough energy\", \"Out of range\", \"Not ready yet\" while pressing keys. All other messages (bags full, quest progress …) stay. The character's voice is Blizzard's setting: Audio > Error speech."]))
            page:AddCheckbox(L["Hide NPC speech pop-ups"], On("hideTalkingHead"), Setter("hideTalkingHead"),
                Help(L["The talking head that appears during quests and in dungeons."]))
        end,
    },
    {
        key = "bags", label = L["Bags"], group = L["Windows"],
        build = function(page)
            page:AddTitle(L["Bags"], L["One window for all bags, sorted into sections."])
            page:AddCheckbox(L["mUI bags"], On("bags"), Setter("bags"), RELOAD)
            page:AddDropdown(L["Layout"], BagStyleItems, function() return ns.db.bagsStyle or "categories" end,
                Setter("bagsStyle", function() if ns.RefreshBags then ns.RefreshBags() end end),
                Help(L["Sections like BetterBags, one big bag, or separate bags. Alt+right-click an item to put it into your own section."]))
            page:AddCheckbox(L["Sell junk and repair at merchants"], On("bagsAutoJunk"), Setter("bagsAutoJunk"),
                Help(L["Repairs use the guild bank when allowed."]))
            page:AddCheckbox(L["Protect profession tools"], On("protectTools"), Setter("protectTools"),
                Help(L["Skinning knife, mining pick, blacksmith hammer, fishing poles and other tools can't be deleted by accident. Off: deleting asks with a big red warning instead."]))
            page:AddHeader(L["Loot"])
            page:AddCheckbox(L["mUI loot window"], On("lootWindow"), Setter("lootWindow"),
                Help(L["Slim loot window at the mouse instead of Blizzard's. Upgrades show an arrow."], true))
            page:AddCheckbox(L["mUI roll windows"], On("lootRolls"), Setter("lootRolls"),
                Help(L["Slim need/greed rows instead of Blizzard's group loot frames. Test mode shows examples."], true))
            page:AddCheckbox(L["Fast loot"], On("fastLoot"), Setter("fastLoot"),
                Help(L["With auto loot on, everything is picked up instantly instead of waiting for the loot window."]))
            -- Nachkaufen beim Händler (nur Forever: Munition und Reagenzien gibt es nur dort)
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
            if not ns.IS_FOREVER then -- Forever hat keine Boss-Zeitleiste/-Warnungen von Blizzard
                page:AddHeader(L["Boss timers"])
                page:AddCheckbox(L["mUI boss timers and warnings"], On("bossMods"), Setter("bossMods"),
                    Help(L["Uses Blizzard's own boss data (encounter timeline and warnings), the same data boss mods get in Midnight. Bars left of the player frame, big abilities at the top centre. Pull timer: /pull 10. Which warnings you see is set in Blizzard's options (Gameplay > Combat > Boss warnings)."], true))
                page:AddCheckbox(L["Warning sound before an ability"], On("bossModsSound"), Setter("bossModsSound"))
            end
            page:AddHeader(L["Damage meter"])
            page:AddCheckbox(L["mUI damage meter"], On("damageMeter"), Setter("damageMeter", function()
                if ns.SyncDamageMeterCVar then ns.SyncDamageMeterCVar() end
            end), Help(L["Own window top left with Blizzard's numbers. Also turns Blizzard's damage meter on or off (Options > Advanced)."], true))
            page:AddCheckbox(L["Hide out of combat"], On("damageMeterFade"), Setter("damageMeterFade"),
                Help(L["Mouse over shows it."]))
            page:AddCheckbox(L["Second window"], On("damageMeterSecond"), Setter("damageMeterSecond", function()
                if ns.RelayoutDamageMeter then ns.RelayoutDamageMeter() end
            end))
            if not ns.IS_FOREVER then -- Forever hat kein Mythisch+ (Benny 2026-11-07)
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
    -- Unten, dezent in Grau (Benny 2026-11-08): Module = eigene Bausteine, Skins = Blizzard-Fenster im
    -- mUI-Look, Changelog. Darunter Profile.
    {
        key = "modules", label = L["Modules"], extra = true,
        build = function(page)
            page:AddTitle(L["Modules"], L["mUI's own building blocks. Turned off, Blizzard or another addon takes over. Takes effect after a reload."])
            page:AddNote(L["Always on: unit frames, action bars, minimap and chat."])
            local function Module(key, label, comfort)
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
                        -- anderes Auktionshaus-Addon aktiv: Hinweis, unseres bleibt aus
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
        key = "profiles", label = L["Profiles"], bottom = true, -- unten in der Navigation
        build = function(page)
            local Profiles = ns.Profiles
            local function ProfileItems(extra)
                local items = extra and { extra } or {}
                for _, name in ipairs(Profiles.List()) do items[#items + 1] = { value = name, label = name } end
                return items
            end

            page:AddTitle(L["Profiles"], L["A profile holds all your settings, including the layout. Each character uses one. Switching reloads the UI."])
            page:AddButton(L["Run the setup again"], function() ns.OpenSetup() end)
            -- Layout = wo alles sitzt (Core/Layouts.lua), gehört zum Profil; Wechsel ohne Neuladen
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

            -- Automatisch je Spezialisierung (Standard aus)
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
        end,
    },
}

-- Fenster ------------------------------------------------------------------------------

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
    -- auf kleinen Bildschirmen bzw. großer UI-Skalierung niedriger; der Inhalt scrollt dann
    window:SetSize(WIDTH, math.min(HEIGHT, UIParent:GetHeight() - 120))
    window:SetPoint("TOP", UIParent, "TOP", 0, -160) -- oberhalb der Frames, damit sie sichtbar bleiben
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    UI.Box(window, { 0.05, 0.05, 0.06, 0.97 })
    tinsert(UISpecialFrames, "MeredanUIOptions") -- Esc schließt

    -- Titel: „Meredan“ hell, „UI“ in Surf Green
    local title = UI.Text(window, 18, "LEFT")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Meredan|cff8ecbb4UI|r")
    local version = UI.Text(window, 11, "LEFT", UI.MUTED)
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetText(ns.VERSION)

    local close = UI.IconButton(window, "Close", function() window:Hide() end, 24)
    close:SetPoint("TOPRIGHT", -10, -10)

    -- Einklappen während der Vorschau (Benny 2026-11-07): nur die Kopfzeile bleibt, halb
    -- durchsichtig (unter der Maus voll) – so sieht man die ganze Vorschau
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
    -- erscheint nur während der Vorschau: links neben „Vorschau“, damit die direkt am X bleibt
    collapse:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(collapsed and L["Expand"] or L["Collapse"])
        GameTooltip:Show()
    end)
    collapse:HookScript("OnLeave", function() GameTooltip:Hide() end)
    collapse:Hide()

    -- eine Vorschau für alles; Einklappen gibt es nur, solange sie läuft
    function window.UpdatePreviewButton()
        local active = ns.Preview.IsActive()
        previewButton.Text:SetText(active and L["Stop preview"] or L["Preview"])
        previewButton.Text:SetTextColor(unpack(active and UI.ACCENT or UI.TEXT))
        collapse:SetShown(active)
        if not active then SetCollapsed(false) end
    end
    -- eine Vorschau für alles (Core/Preview.lua), immer an dieser Stelle; läuft auch nach dem
    -- Schließen weiter (/mui t beendet sie)
    previewButton = UI.Button(window, "", function()
        ns.Preview.Toggle()
        window.UpdatePreviewButton()
    end, 170)
    previewButton:SetPoint("RIGHT", close, "LEFT", -6, 0)
    collapse:SetPoint("RIGHT", previewButton, "LEFT", -6, 0)
    for _, frame in ipairs({ close, collapse, previewButton }) do keep[frame] = true end
    ns.OnPreviewChanged = window.UpdatePreviewButton -- auch bei /mui t und Kampfbeginn

    -- Navigation links: Bereiche in Gruppen, Profile unten
    local nav = CreateFrame("Frame", nil, window)
    nav:SetPoint("TOPLEFT", 10, -48)
    nav:SetPoint("BOTTOMLEFT", 10, 10)
    nav:SetWidth(NAV_WIDTH)
    UI.Box(nav, { 0.08, 0.08, 0.09, 1 })

    -- Reload-Leiste unten rechts: erscheint, sobald eine Option mit Marke geändert wurde
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

    -- Inhalt rechts, scrollt bei langen Seiten; mit Leiste unten kürzer
    local scroll = UI.ScrollArea(window)
    scroll:SetPoint("TOPLEFT", nav, "TOPRIGHT", 20, -6)
    scroll:SetPoint("BOTTOMRIGHT", -28, 16)
    scroll.child:SetWidth(CONTENT_WIDTH) -- vor dem Aufbau setzen, damit Hinweise richtig umbrechen
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
            extras[#extras + 1] = button -- Platz erst nach der Schleife (über Profile)
        else
            button:SetPoint("TOPLEFT", 1, -y)
            button:SetPoint("TOPRIGHT", -1, -y)
            y = y + NAV_ROW
        end
        local hover = button:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(unpack(UI.HOVER))
        hover:Hide()
        button.selected = button:CreateTexture(nil, "BACKGROUND", nil, 1) -- gewählter Bereich, etwas heller
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
        button.text:SetPoint("RIGHT", -6, 0) -- falls eine Übersetzung doch zu lang ist: kürzen statt überlappen
        button.text:SetWordWrap(false)
        button.text:SetText(entry.label)
        button:SetScript("OnEnter", function() hover:Show() end)
        button:SetScript("OnLeave", function() hover:Hide() end)
        button:SetScript("OnClick", function() SelectPage(entry.key) end)
        entry.nav = button

        entry.page = UI.Page(content)
        entry.build(entry.page)
    end
    -- Fenster wächst mit der Navigation (Benny 2026-11-06: neue Menüpunkte sollen immer Platz haben):
    -- oben 48 px Kopf, Einträge, Abstand zu den unteren Einträgen, unten 10 px Rand
    -- Module/Skins/Changelog über Profile, oben zuerst; je eine Trennlinie darüber und darunter
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
    Line(base) -- über Profile
    if #extras > 0 then Line(base + extraHeight) end -- über Module

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

-- Einstellungen öffnen, gleich auf einem bestimmten Bereich (z. B. von der Minimap aus)
function ns.ShowSettings(key)
    if not window then CreateWindow() end
    window.current = key or window.current
    if window:IsShown() then SelectPage(window.current) else window:Show() end
end
ns.OnCompartmentClick = ns.OpenSettings

-- Fenster ausblenden (z. B. vor dem RP-Modus).
function ns.HideSettings()
    if window then window:Hide() end
end
