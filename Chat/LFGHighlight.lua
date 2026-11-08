-- Gruppensuche im Chat (Forever): Sucht jemand eine Gruppe für einen Dungeon/Schlachtzug,
-- der zu deiner Stufe passt, bekommt die Nachricht vorne einen Hinweis in MUI-Salbei:
--
--   [1] [Kräuterkalle]: LFM DM need heal               ← vorher
--   [1] [Kräuterkalle]: 🔍 Todesminen LFM DM need heal  ← nachher (nur wenn die Todesminen zu dir passen)
--
-- Erkannt wird: Gruppensuch-Wort (LFG, LFM, suche, need, Tank, Heiler …) + Dungeon (Kürzel oder
-- Name, deutsch und englisch). „Passt“ = deine Stufe liegt im Bereich des Dungeons (± 2).
-- Allgemeine Kanäle, Sagen, Schreien. Geheime Chat-Texte (Instanzen) bleiben unangetastet.
local _, ns = ...
local L = ns.L

local SLACK = 2 -- so viele Stufen darf man unter/über dem Bereich sein

-- { Stufe von, bis, Schlüsselwörter (klein) }; Name kommt aus den Locales
local DUNGEONS = {
    { "Ragefire Chasm", 13, 18, { "rfc", "ragefire", "flammenschlund" } },
    { "Wailing Caverns", 17, 24, { "wc", "wailing", "hdw", "höhlen des wehklagens", "wehklagen" } },
    { "The Deadmines", 17, 26, { "dm", "vc", "deadmines", "todesminen", "tm" } },
    { "Shadowfang Keep", 22, 30, { "sfk", "shadowfang", "bsf", "burg schattenfang", "schattenfang" } },
    { "Blackfathom Deeps", 24, 32, { "bfd", "blackfathom", "tsg", "tiefschwarze grotte" } },
    { "The Stockade", 24, 32, { "stocks", "stockade", "verlies" } },
    { "Gnomeregan", 29, 38, { "gnomer", "gnomeregan" } },
    { "Razorfen Kraul", 29, 38, { "rfk", "kraul", "kral", "kdk" } },
    { "Scarlet Monastery", 30, 45, { "sm", "scarlet", "kloster", "sm gy", "sm lib", "sm arm", "sm cath", "friedhof", "bibliothek", "waffenkammer", "kathedrale" } },
    { "Razorfen Downs", 37, 46, { "rfd", "downs", "hügel", "hdk" } },
    { "Uldaman", 41, 51, { "ulda", "uldaman" } },
    { "Zul'Farrak", 44, 54, { "zf", "zul'farrak", "zulfarrak", "farrak" } },
    { "Maraudon", 46, 55, { "mara", "maraudon" } },
    { "Sunken Temple", 50, 56, { "st", "sunken temple", "atal'hakkar", "versunkener tempel", "tempel" } },
    { "Blackrock Depths", 52, 60, { "brd", "brt", "blackrock depths", "schwarzfelstiefen", "blackrocktiefen" } },
    { "Lower Blackrock Spire", 55, 60, { "lbrs", "ubrs", "brs", "blackrock spire", "schwarzfelsspitze", "blackrockspitze" } },
    { "Dire Maul", 55, 60, { "dme", "dmw", "dmn", "dm east", "dm west", "dm north", "dm nord", "dm ost", "dire maul", "düsterbruch", "tribut", "tribute" } },
    { "Scholomance", 58, 60, { "scholo", "scholomance" } },
    { "Stratholme", 58, 60, { "strat", "strath", "stratholme", "strat ud", "strat live", "baron" } },
    { "Molten Core", 60, 60, { "mc", "molten core", "geschmolzener kern" } },
    { "Onyxia's Lair", 60, 60, { "ony", "onyxia" } },
    { "Zul'Gurub", 60, 60, { "zg", "zul'gurub", "zulgurub" } },
    { "Blackwing Lair", 60, 60, { "bwl", "blackwing", "pechschwingenhort" } },
    { "Ahn'Qiraj", 60, 60, { "aq", "aq20", "aq40", "ahn'qiraj", "ahnqiraj" } },
}

-- Wörter, an denen man eine Gruppensuche erkennt
local SEEKING = { "lfg", "lfm", "lf1m", "lf2m", "lf3m", "lf4m", "lf", "looking for", "need", "suche", "sucht",
    "suchen", "brauchen", "braucht", "tank", "heal", "healer", "heiler", "dps", "dd", "noch einer", "noch ein" }

local function Escape(word) return (word:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")) end

-- „ganzes Wort“: Frontier-Muster (vorne/hinten kein Buchstabe/keine Zahl)
local function Compile(words)
    local out = {}
    for i, word in ipairs(words) do out[i] = "%f[%w]" .. Escape(word) .. "%f[^%w]" end
    return out
end
local SEEKING_PATTERNS = Compile(SEEKING)
for _, dungeon in ipairs(DUNGEONS) do dungeon.patterns = Compile(dungeon[4]) end

local function Enabled() return ns.db.lfgHighlight ~= false and ns.IS_FOREVER end

local function AnyMatch(text, patterns)
    for _, pattern in ipairs(patterns) do
        if text:find(pattern) then return true end
    end
end

-- passender Dungeon zur eigenen Stufe (der erste Treffer)
local function MatchDungeon(text)
    local level = UnitLevel("player")
    for _, dungeon in ipairs(DUNGEONS) do
        if level >= dungeon[2] - SLACK and level <= dungeon[3] + SLACK and AnyMatch(text, dungeon.patterns) then
            return dungeon
        end
    end
end

local function Tag(dungeon)
    local r, g, b = ns.UI.ACCENT[1] * 255, ns.UI.ACCENT[2] * 255, ns.UI.ACCENT[3] * 255
    local icon = ("|T%sIcons\\LFG:14:14:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(ns.MEDIA, r, g, b)
    return ("%s |cff8ecbb4%s|r "):format(icon, L[dungeon[1]])
end

local function Filter(_, _, message, author, ...)
    if not Enabled() or issecretvalue(message) or type(message) ~= "string" then return false, message, author, ... end
    local text = message:lower()
    if not AnyMatch(text, SEEKING_PATTERNS) then return false, message, author, ... end
    local dungeon = MatchDungeon(text)
    if not dungeon then return false, message, author, ... end
    return false, Tag(dungeon) .. message, author, ...
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL" }) do addFilter(event, Filter) end
end)
