-- LFG highlight (Forever): chat messages looking for a group for a dungeon/raid that fits your
-- level get an accent-colored tag in front:
--   [1] [Someone]: LFM DM need heal  ->  [1] [Someone]: (icon) Deadmines LFM DM need heal
-- Match = seeking word (LFG, LFM, need, tank ...) + dungeon keyword (German and English),
-- and your level within the dungeon range +/- SLACK. Channels, say, yell; secret text is skipped.
local _, ns = ...
local L = ns.L

local SLACK = 2 -- allowed levels below/above the range

-- { name, min level, max level, lowercase keywords }; display name comes from the locales
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

-- Words indicating a group search (English and German)
local SEEKING = { "lfg", "lfm", "lf1m", "lf2m", "lf3m", "lf4m", "lf", "looking for", "need", "suche", "sucht",
    "suchen", "brauchen", "braucht", "tank", "heal", "healer", "heiler", "dps", "dd", "noch einer", "noch ein" }

local function Escape(word) return (word:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")) end

-- Whole-word match via frontier patterns
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

-- First matching dungeon that fits the player's level
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
