-- MeredanUI: Kern – Flavor-Erkennung, Secret-sichere Helfer, Events, SavedVariables, Slash-Befehle.
local ADDON_NAME, ns = ...
local L = ns.L

-------------------------------------------------------------------------------
--  Flavor: Retail (Midnight) und WoW Forever teilen sich das Mainline-API.
--  Forever meldet WOW_PROJECT_ID 18 (WOW_PROJECT_CAMELOT). Features lieber per
--  API-Existenz prüfen als nur über die Projekt-ID verzweigen.
-------------------------------------------------------------------------------
ns.IS_FOREVER = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)
ns.IS_RETAIL = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or ""
ns.VERSION = version:find("^@") and "dev" or version

-------------------------------------------------------------------------------
--  Secret Values: Den Secret-Test IMMER zuerst – schon `v == nil` auf einem
--  Secret wirft einen Fehler. Secrets nur an Blizzard-Widgets durchreichen.
-------------------------------------------------------------------------------
local issecretvalue = issecretvalue or function() return false end
ns.issecretvalue = issecretvalue

-- Wert ist lesbar (kein Secret, nicht nil).
function ns.Readable(v)
    return not issecretvalue(v) and v ~= nil
end

-- Wert oder nil, falls Secret.
function ns.Plain(v)
    if not issecretvalue(v) then return v end
end

-------------------------------------------------------------------------------
--  Ausgabe
-------------------------------------------------------------------------------
-- Marke im Chat (Benny 2026-11-07): sonst „mUI“ – „m“ hell (#e9e6dd), „UI“ in Surf Green (#8ecbb4);
-- nur die Begrüßung beim Login zeigt den ganzen Namen „MeredanUI“.
local BRAND_SHORT = "|cffe9e6ddm|r|cff8ecbb4UI|r"
local BRAND_LONG = "|cffe9e6ddMeredan|r|cff8ecbb4UI|r"
local PREFIX = BRAND_SHORT .. ": "

function ns.Print(fmt, ...)
    local text = select("#", ...) > 0 and fmt:format(...) or fmt
    print(PREFIX .. text)
    if DevLog then DevLog(ADDON_NAME, text) end -- Dev-Hilfe (Workspace-Addon DevLog), sonst nichts
end

function ns.Debug(fmt, ...)
    if ns.db and ns.db.debug then ns.Print("|cff888888" .. fmt .. "|r", ...) end
end

-------------------------------------------------------------------------------
--  Events: ns:On("EVENT", function(event, ...) end)
-------------------------------------------------------------------------------
local handlers = {}
-- Jeder Handler einzeln abgesichert: ein Fehler landet im Fehlerfenster (BugSack), die übrigen
-- Module laufen trotzdem weiter (sonst bricht z. B. beim Login die ganze Kette ab).
local SafeCall = securecallfunction or function(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do SafeCall(list[i], event, ...) end
end)

function ns:On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], fn)
end

function ns:Off(event)
    handlers[event] = nil
    eventFrame:UnregisterEvent(event)
end

-- Läuft ein anderes Addon für dieselbe Aufgabe? Liefert dessen Ordnernamen (erstes geladenes aus
-- der Liste) oder nil. Ordnernamen exakt wie im AddOns-Ordner.
function ns.OtherAddon(names)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
    if not loaded then return end
    for _, name in ipairs(names) do
        if loaded(name) then return name end
    end
end

-- Auktionshaus-Addons (Benny 2026-11-08): läuft eins davon, bleibt das mUI-Auktionshaus aus –
-- kein Skin, kein Eingriff; Händler schwören auf ihr eigenes.
ns.AUCTION_ADDONS = { "Auctionator", "TradeSkillMaster", "Auc-Advanced", "AuctionFaster", "aux-addon" }
-- Briefkasten-Addons: hängen sich an Blizzards Postfenster – unseres würde sie verdecken
ns.MAIL_ADDONS = { "Postal", "TradeSkillMaster", "MailLogger" }

-- Aktion außerhalb des Kampfes ausführen (sofort oder nach PLAYER_REGEN_ENABLED).
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
--  SavedVariables (account-weit) mit Profilen:
--    MeredanUIDB.profiles[Name] = Einstellungen (DEFAULTS), ns.db = aktives Profil
--    MeredanUIDB.chars["Vorname Nachname - Realm"] = { profile, setupDone, specAuto, specProfiles }
--    Neue Charaktere bekommen ein eigenes Profil mit ihrem Namen (s. ADDON_LOADED).
--    MeredanUIDB.newCharProfile = Profil für neu eingeloggte Charaktere (optional)
--  Neue Defaults werden beim Laden ergänzt. Profile verwaltet Profiles.lua. Das Layout (wo alles
--  sitzt, Core/Layouts.lua) ist eine Einstellung im Profil: ns.db.layout.
-------------------------------------------------------------------------------
ns.DEFAULT_PROFILE = "Standard"
-- Ein eingebautes Profil (nicht löschbar/umbenennbar); die Rolle steckt im Layout (Benny 2026-11-07).
ns.BUILTIN_PROFILES = { ns.DEFAULT_PROFILE }
ns.DEFAULT_LAYOUT = "melee" -- Nahkampf-DPS: Basis aller Layouts

local DEFAULTS = {
    debug = false,
    nameFormat = "first", -- Namen (Forever: Vor- und Nachname): "first", "full", "firstInitial", "initialLast", "last"
    panelOpacity = "normal", -- Deckkraft aller mUI-Hintergründe: "solid", "normal", "light" (Core/Style.lua)
    fontSize = "medium", -- Schriftgröße aller mUI-Texte: "small", "medium", "large" (Core/Style.lua)
    layout = "melee", -- Layout (Core/Layouts.lua): Nahkampf-DPS ist die Basis
    theme = "class", -- "class", "dark" oder "green"
    minimapExtras = "always", -- Texte (Zone, Uhr, Koordinaten) und Symbole: "always" oder "mouseover"
    frameSize = "medium", -- Spieler + Ziel (Begleiter, Ziel des Ziels, Fokus wachsen mit): "small", "medium", "large"
    bossSize = "medium",  -- Bossframes: "small", "medium", "large"
    chatShortChannels = true, -- Kanalnamen im Chat kürzen ([G], [P], [1] …)
    chatTimestamps = true,    -- schlichte Zeitstempel (12:04) vor Chatzeilen
    chatFontSize = "medium",  -- Schriftgröße im Chat: "small", "medium", "large" (Chat/ChatStyle.lua)
    chatEmoji = true,         -- Smileys und Emojis als Bilder im Chat
    chatReputation = true,    -- Ruf im Chat mit Balken statt Blizzards Zeile
    chatMentionSound = true,  -- Ton, wenn dein Name/Spitzname im Chat fällt
    -- Tooltip: Position "corner" (unten rechts) oder "cursor"; Spieler-Zeilen einzeln
    tooltipAnchor = "corner",
    tooltipHideInCombat = false, -- im Kampf ausblenden (Shift zeigt ihn trotzdem)
    tooltipItemLevel = true, tooltipMythic = true, tooltipTarget = true,
    chatBubbles = true,          -- Sprechblasen im MUI-Look (Chat/ChatBubbles.lua)
    emoteBar = "hidden",         -- Emote-Leiste (Chat/EmoteBar.lua): "always", "mouseover", "hidden"
    emoteBarEmotes = {},         -- [Emote] = true/false; fehlt = Standard (ns.EMOTE_DEFAULTS)
    tooltipAuraSource = true,    -- Buff-/Debuff-Tooltip: „Von: Name“
    tooltipIDs = true,           -- IDs (Zauber, Items, NPCs …) unten im Tooltip
    mplusChests = true,          -- M+-Timer: Restzeit für +3/+2
    mplusForces = "detail",      -- Feindliche Truppen: "detail" (62.47% · 287/460) oder "percent" (Blizzard)
    mplusSplits = true,          -- Boss-Zeiten in den Ziel-Zeilen
    mplusMobTooltip = true,      -- Truppen-Wert eines Gegners im Tooltip
    mplusAutoKeystone = true,    -- Schlüssel am Sockel automatisch einsetzen
    mplusAutoGossip = true,      -- im Schlüssel einzige Gesprächsoption automatisch wählen
    mplusGroupKeys = true,       -- Gruppen-Schlüssel neben dem Mythisch+-Fenster
    hideErrors = true,           -- rote Fehlermeldungen + Sprachausgabe aus (Core/Quiet.lua)
    hideTalkingHead = true,
    combatAlert = true,          -- „+ Kampf“/„− Kampf“ über der Bildschirmmitte (Toasts/CombatAlert.lua)
    toastsGroupLoot = true,      -- Toasts: Würfel-Ergebnisse und Beute der Gruppe
    spellRanks = true,           -- Forever: Pfeil + Toast bei alten Zauberrängen auf den Leisten
    trainerReminder = true,      -- Forever: Toast beim Stufenaufstieg, wenn beim Lehrer Zauber warten
    lootRolls = true,            -- eigene Würfel-Fenster (Loot/LootRoll.lua)
    lootWindow = true,           -- eigenes Beute-Fenster (Loot/LootWindow.lua)
    fastLoot = true,             -- Beute bei Auto-Plündern sofort einsammeln (Loot/FastLoot.lua)
    castbar = "full",            -- Zauberleiste: "simple" (nur Leiste) oder "full" (GCD-Linie + Tick-Striche)
    executeLine = true,          -- Execute-Linie im Ziel-Lebensbalken und auf Nameplates
    npNameSize = "medium",       -- Namensgröße freundlicher Namens-Plates: small 12, medium 14, large 16
    npNpcTitle = true,           -- Titel unter NPC-Namen („Bergbaulehrer“)
    npPetOwner = true,           -- Besitzer unter Begleitern („Koratals Begleiter“)
    plateClassification = true,  -- Rar/Elite-Symbol vor dem Namen auf Nameplates
    autoInvite = false,          -- Einladungen von Freunden/Gilde annehmen (Standard aus, Benny)
    autoRole = true,             -- Rollenabfrage mit der Spec-Rolle bestätigen
    readyCheckReminder = true,   -- Bereitschaftscheck: Toast, wenn Essen/Fläschchen/Rune fehlen
    durabilityWarning = true,    -- Toast, wenn ein Teil unter 20 % Haltbarkeit fällt
    achievementScreenshot = true, -- Screenshot bei neuen Erfolgen
    characterItemLevels = true,  -- Itemlevel an den Plätzen im Charakter-/Betrachten-Fenster
    afkScreen = true,            -- AFK-Bildschirm „Kino“ (AFK/AFK.lua)
    groupManager = true,         -- Gruppenleiste (ersetzt Blizzards Schlachtzugsleiter-Leiste)
    groupFrames = true,          -- MUI-Gruppenframes (Gruppe + Schlachtzug) statt Blizzards
    groupSolo = false, -- Gruppenframes auch allein zeigen (zum Testen)
    fontEverywhere = true,       -- MUI-Schrift für alle Schrift-Objekte des Spiels (Core/Fonts.lua)
    bossMods = true,             -- MUI-Boss-Timer und -Warnungen statt Blizzards Anzeige
    bossModsSound = true,        -- kurzer Ton, wenn eine Boss-Fähigkeit gleich kommt
    toasts = true,               -- MUI-Toasts statt Blizzards Popups (aus: nach Neuladen)
    characterWindow = true,      -- eigenes mUI-Charakterfenster (Forever; aus: nach Neuladen)
    guildOverview = true,        -- Gilde: Reiter „Übersicht“ (Klassen, Stufen) – Skins/Communities.lua
    guildInactive = true,        -- Gilde: ab 14 Tagen offline dezent rot (Ränge mit „Twink“/„Alt“ ausgenommen)
    guildSkin = true,            -- Blizzards Gildenfenster im mUI-Look (Skins/Communities.lua)
    damageMeter = true,          -- eigenes mUI-Damage-Meter statt Blizzards Fenster (aus: nach Neuladen)
    damageMeterSecond = false,   -- zweites Damage-Meter-Fenster darunter (eigene Art wählbar)
    damageMeterFade = true,      -- Damage Meter außerhalb vom Kampf ausblenden (Maus drauf zeigt es)
    bagsStyle = "categories",    -- Taschen: "categories" (Abschnitte), "single" (ein Raster), "separate" (je Tasche)
    bagsShowSlots = false,       -- Taschenplätze unten im Taschenfenster (Knopf oben im Fenster)
    mapReveal = true,            -- Weltkarte: ganze Karte aufdecken (Komfort)
    mapZoneLevels = true,        -- Weltkarte: Stufenbereich am Gebietsnamen (Komfort)
    emptySlots = true,           -- Taschen: Items für leere Ausrüstungsplätze markieren (Komfort)
    upgrades = "damage",         -- Upgrade-Bewertung: "damage" (% Gesamtschaden), "item" (% vom Item), "off"
    -- eigene Buffs/Debuffs links der Minimap (greifen nach dem Neuladen)
    auraSize = "medium",    -- Größe Buffs/Debuffs: "small", "medium", "large"
    auraTime = "below",     -- Restzeit "below" (unter dem Icon) oder "inside" (im Icon)
    microMenu = "always", -- Mikromenü unten rechts: "always", "mouseover", "hidden"
    addonBar = "mouseover", -- Minimap-Knöpfe anderer Addons als Leiste über dem Mikromenü
    addonBarHidden = {},    -- [Schlüssel] = true: Addon nicht in der Leiste zeigen
    -- Info-Leiste unten: Sichtbarkeit ("always", "mouseover", "hidden") und Felder
    infoBar = {
        mode = "always",
        fields = { gold = true, bags = true, durability = true, fps = true,
            spec = false, guild = false, friends = false, time = false, weaponskill = true },
    },
    -- Fortschrittsleisten: eine Sichtbarkeit für EP, Ruf, Ehre, Hausgunst
    xpBar = { mode = "always", quests = "all" }, -- quests: "all", "complete", "none"
    ammoCounter = true,          -- Munitionszähler unter dem Spieler-Frame (nur Forever, nur mit Munition)
    petHelper = true,            -- Begleiter-Helfer: Pfote am Tier-Frame, füttern + Laune-Toast (nur Forever, Jäger)
    lfgHighlight = true,         -- Gruppensuche im Chat hervorheben (Chat/LFGHighlight.lua, nur Forever)
    professionReminder = true,   -- Berufe-Erinnerung: nächste Rangstufe lernbar (Toasts/ProfessionReminder.lua, nur Forever)
    autoBuy = false,             -- beim Händler Munition/Reagenzien auffüllen (Bags/AutoBuy.lua)
    autoBuyAmounts = {},         -- [Item-ID | "ammo"] = Wunschmenge; fehlt = Standard, 0 = nicht kaufen
    reagentShow = {},            -- [Item-ID | "ammo"] = true/false; fehlt = Standard (nur das erste je Klasse)
    flightTimer = true,          -- Flugzeit-Leiste oben mittig (Minimap/FlightTimer.lua)
    swingTimer = true,           -- Forever: Schlagtimer unter der Hauptleiste
    threatBar = "group", -- Bedrohungsleiste: "group" (Gruppe oder Begleiter), "always", "hidden"
    barVariant = "center",       -- Leisten-Anordnung: "center" (Mittig 2×6) oder "stacked" (3 × 12 unten)
    mouseoverHeal = false,       -- Mouseover-Zauber auf den Leisten (CVar enableMouseoverCast)
    -- Sichtbarkeit der Aktionsleisten: "always", "mouseover", "hidden"
    actionBars = {
        bar1 = "always", bar2 = "always", bar3 = "always", bar4 = "always", bar5 = "always",
        bar6 = "hidden", bar7 = "hidden", bar8 = "hidden", -- Zusatzleisten: erst in den Einstellungen dazuschalten
        petbar = "always", stancebar = "mouseover",
    },
    actionBarTexts = {}, -- [Leiste] = { hotkey = false, macro = false } blendet Texte aus; fehlt = an
    actionBarFont = "medium", -- Schriftgröße der Tastenbelegung: "small", "medium", "large"
}

ns.DEFAULTS = DEFAULTS -- z. B. für „Zurücksetzen“ in den Einstellungen

function ns.ApplyDefaults(db, defaults)
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(db[k]) == "table" then
            ns.ApplyDefaults(db[k], v)
        end
    end
end

-- Profil umbenennen samt allen Verweisen (Charaktere, Spec-Zuordnungen, neue Charaktere)
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

-- Profile vereinfacht (2026-11-07): aus „Standard (DPS)“ wird wieder „Standard“; die leeren
-- Altlasten „Standard (Tank)“/„(Heal)“ fallen weg, wenn sie niemand nutzt – sonst bleiben sie als
-- eigene Profile. Spec-Wechsel ist Standard aus (bleibt, wer ihn eingeschaltet hat).
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

-- Einstellungen verschlankt (2026-11-07): Regler wurden Stufen, manches ist fest. Alte Werte
-- werden einmalig übernommen, ungenutzte Schlüssel entfernt.
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

local function MigrateSettings(db)
    if (db.settingsVersion or 1) >= 2 then return end
    db.settingsVersion = 2
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

-- Servername kurz (Benny 2026-11-07): Forever heißt „CAMWOW EU5 Realm 10 RP“ > kurz „RP“,
-- etwas länger „EU5-10 RP“. Andere Server bleiben, wie sie sind.
function ns.ShortRealm(realm)
    local region, number, kind = (realm or ""):match("^%S+ (%S+) Realm (%d+) (.+)$")
    if not kind then return realm, realm end
    return kind, region .. "-" .. number .. " " .. kind
end

-- „Name - Server“ (Schlüssel) für die Anzeige: „Koratal Rabenruf (RP)“
function ns.CharDisplayName(key)
    local name, realm = (key or ""):match("^(.-) %- (.+)$")
    if not name then return key end
    return name .. " (" .. (ns.ShortRealm(realm)) .. ")"
end

ns:On("ADDON_LOADED", function(_, name)
    -- Nur auf das eigene Addon reagieren, das Event aber angemeldet lassen: Module
    -- warten darauf, dass Blizzard Teile nachlädt (z. B. Blizzard_TimeManager).
    if name ~= ADDON_NAME then return end
    MeredanUIDB = MeredanUIDB or {}
    local root = MeredanUIDB

    -- Umzug aus der Zeit vor den Profilen: flache Einstellungen werden das Standardprofil
    if not root.profiles then
        local old = {}
        for key, value in pairs(root) do old[key] = value end
        wipe(root)
        root.profiles = { [ns.DEFAULT_PROFILE] = old }
    end
    root.chars = root.chars or {}
    MigrateProfiles(root)
    for _, name in ipairs(ns.BUILTIN_PROFILES) do root.profiles[name] = root.profiles[name] or {} end
    -- Verschieben gibt es nicht mehr (Benny 2026-11-07): alte gespeicherte Positionen weg
    for _, profile in pairs(root.profiles) do profile.positions = nil end
    ns.root = root

    -- Setup-Merker war account-weit (root.setupDone) > jetzt je Charakter; wer schon da war, gilt
    -- als eingerichtet.
    if root.setupDone then
        for _, known in pairs(root.chars) do known.setupDone = true end
        root.setupDone = nil
    end

    -- Charakter = Vor- UND Nachname + Server (Benny 2026-11-07: zwei „Koratal“ mit verschiedenen
    -- Nachnamen auf einem Server teilten sich Schlüssel, Profil und Setup). Forever liefert den
    -- Nachnamen als zweiten Wert von UnitName; Retail hat keinen > Schlüssel wie bisher.
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
        -- früher nur mit Vornamen gespeichert? Dann dessen Einstellungen übernehmen
        local oldKey = first .. " - " .. realm
        local old = oldKey ~= ns.charKey and root.chars[oldKey] or nil
        local shared = root.newCharProfile
        if shared and root.profiles[shared] then
            -- „Standard für neue Charaktere“ gewählt: dieses Profil teilen, es ist schon eingerichtet
            char.profile, char.setupDone = shared, true
        else
            -- eigenes Profil mit dem Charakternamen; bei Namensgleichheit kurzer Server dahinter
            -- („(RP)“, dann „(EU5-10 RP)“, dann Nummer)
            local short, long = ns.ShortRealm(realm)
            local name, n = fullName, 1
            if root.profiles[name] then name = fullName .. " (" .. short .. ")" end
            if root.profiles[name] then name = fullName .. " (" .. long .. ")" end
            local base = name
            while root.profiles[name] do n = n + 1; name = base .. " " .. n end
            local source = old and old.profile and root.profiles[old.profile]
            root.profiles[name] = source and CopyTable(source) or {}
            char.profile = name
            -- übrige Charakter-Daten mitnehmen (Talent-Berater, Chat-Verlauf …), aber NICHT den
            -- Setup-Merker: der stammt aus dem account-weiten Merker und gilt nicht für diesen Charakter
            for key, value in pairs(old or {}) do
                if key ~= "profile" and key ~= "setupDone" then
                    char[key] = type(value) == "table" and CopyTable(value) or value
                end
            end
        end
        if old and root.gold then root.gold[oldKey] = nil end -- Gold-Liste: kommt unter dem neuen Namen wieder
    end
    -- Alten Eintrag nur mit Vornamen nach dem Umzug löschen, sonst erbt jeder weitere Charakter mit
    -- gleichem Vornamen (zweiter „Koratal“) dessen Profil und Setup-Merker
    if last then
        local oldKey = first .. " - " .. realm
        if oldKey ~= ns.charKey then root.chars[oldKey] = nil end
    end
    -- Einmalig (Benny 2026-11-08): alle Setup-Merker stammten aus dem account-weiten Merker bzw. waren
    -- vom Vornamen-Eintrag geerbt > jeder Charakter bekommt das Setup noch einmal angeboten
    if not root.setupPerChar then
        for _, known in pairs(root.chars) do known.setupDone = nil end
        root.setupPerChar = true
    end
    char.profile = root.profiles[char.profile] and char.profile or ns.DEFAULT_PROFILE
    char.specProfiles = char.specProfiles or {}
    -- Reste eines kurzen Zwischenstands (Layout pro Charakter); das Layout steckt jetzt im Profil
    char.layout, char.specLayouts, root.newCharLayout = nil, nil, nil
    ns.char = char
    ns.UseProfile(char.profile)
end)

-- Profil als aktive Einstellungen (ns.db) laden; fehlt es, wird es angelegt.
function ns.UseProfile(name)
    local profiles = ns.root.profiles
    profiles[name] = profiles[name] or {}
    MigrateSettings(profiles[name])
    ns.ApplyDefaults(profiles[name], DEFAULTS)
    ns.db = profiles[name]
    ns.profileName = name
end

ns:On("PLAYER_LOGIN", function()
    ns.Debug("v%s, %s", ns.VERSION, ns.IS_FOREVER and "Forever" or "Retail")
    -- Begrüßung: ganzer Name, Version gedämpft, Name in Klassenfarbe, Hinweis auf /mui
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS[class]
    local name = UnitName("player") or ""
    if color then name = color:WrapTextInColorCode(name) end
    print(("%s |cff99978fv%s|r  ·  %s  ·  |cff99978f%s|r"):format(BRAND_LONG, ns.VERSION,
        L["Welcome back, %s!"]:format(name), L["/mui opens the settings"]))
end)

-------------------------------------------------------------------------------
--  Slash-Befehle: /meredanui oder /mui [befehl]
-------------------------------------------------------------------------------
local commands = {}

function ns.AddCommand(name, help, fn)
    commands[name] = { help = help, fn = fn }
end

local function ShowHelp()
    ns.Print(L["Commands:"])
    for name, cmd in pairs(commands) do
        print(("  /mui %s – %s"):format(name, cmd.help))
    end
end

ns.AddCommand("help", L["show this help"], ShowHelp)
ns.AddCommand("debug", L["toggle debug output"], function()
    ns.db.debug = not ns.db.debug
    ns.Print(L["Debug output: %s"], ns.db.debug and L["on"] or L["off"])
end)

SLASH_XMEREDANUI1 = "/meredanui"
SLASH_XMEREDANUI2 = "/mui"
SlashCmdList["XMEREDANUI"] = function(msg)
    local name, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    if name == "" and ns.OpenSettings then return ns.OpenSettings() end
    local cmd = commands[name:lower()]
    if cmd then cmd.fn(rest) else ShowHelp() end
end

-- Klick auf den Eintrag im Addon-Kompartiment (Minimap-Menü).
-- Klick öffnet die Einstellungen (Settings.lua setzt ns.OnCompartmentClick).
function MeredanUI_OnAddonCompartmentClick()
    if ns.OnCompartmentClick then ns.OnCompartmentClick() else ShowHelp() end
end

-------------------------------------------------------------------------------
--  Geschützte Knöpfe (Secure…Template) nie an ungeschützten Rahmen verankern: WoW schützt sonst
--  den Rahmen, an dem sie hängen, samt Fenster mit – das lässt sich dann im Kampf nicht mehr
--  öffnen/schließen (Benny 2026-11-07: „MeredanUIFriends:Show() blockiert“). Darum liegt die
--  geschützte Ebene nur an UIParent, an der Stelle des Fensters, und Knöpfe hängen nur an der Ebene.
--  Positionen werden außerhalb des Kampfs gesetzt (im Kampf ist die Ebene ohnehin versteckt).
-------------------------------------------------------------------------------
-- frame an die Stelle von target legen, verankert nur an relativeTo (Standard: UIParent)
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

-- Ebene folgt target (Fenster wird gezogen, Größe ändert sich): kleiner Wächter am Fenster
function ns.FollowFrame(layer, target)
    local watcher = CreateFrame("Frame", nil, target)
    local last = ""
    watcher:SetScript("OnUpdate", function()
        if InCombatLockdown() then return end
        local l, b, w, h = target:GetRect()
        if not l then return end
        local key = ("%.1f:%.1f:%.1f:%.1f"):format(l, b, w, h)
        if key == last then return end
        last = key
        ns.MirrorRect(layer, target)
    end)
    ns.MirrorRect(layer, target)
end
