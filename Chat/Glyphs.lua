-- Emojis und Zeichen im Chat (Benny 2026-11-06):
--   • Smileys aus Text (:D, :-D, xD, <3, ^^ …) und echte Emojis werden zu kleinen Bildern
--     (Twemoji, Media/Emoji/<code>.tga, 64×64) – nur wer MUI hat, sieht die Bilder.
--   • Zeichen, die unsere Chat-Schrift (mUI) nicht kennt, erscheinen sonst als Rechteck:
--     bekannte als Text ersetzt (♥ > <3 …), übrige fallen weg. Abdeckung aus der Schriftdatei
--     gelesen (cmap von Media/Fonts/mUI.ttf, 390 Zeichen; Pfeile ← ↑ → ↓ kennt sie selbst).
local _, ns = ...

-- vorhandene Bilder (Unicode > Datei)
local IMAGES = {}
for _, code in ipairs({ 0x1F642, 0x1F600, 0x1F603, 0x1F604, 0x1F601, 0x1F606, 0x1F602, 0x1F923, 0x1F609,
    0x1F61B, 0x1F61C, 0x1F641, 0x1F622, 0x1F62D, 0x1F62E, 0x1F610, 0x1F611, 0x2764, 0x1F494, 0x1F60A, 0x1F63A,
    0x1F44B, 0x1F44D, 0x1F44E, 0x1F618, 0x1F60E, 0x1F620, 0x1F615, 0x1F60D, 0x1F914, 0x1F644, 0x1F973, 0x1F525,
    0x1F389, 0x1F480, 0x1F64F, 0x1F44F, 0x1F607, 0x1F605, 0x1F62C }) do
    IMAGES[code] = ("|T%sEmoji\\%x:0:0:0:-3|t"):format(ns.MEDIA, code) -- y -3: auf Schrifthöhe (Benny 2026-11-07)
end
IMAGES[0x2665] = IMAGES[0x2764] -- ♥ wie ❤
IMAGES[0x263A] = IMAGES[0x1F642] -- ☺

-- Smileys aus Text (nur als eigenes Wort, damit „http://“ oder „10:30“ unberührt bleiben)
local SMILEYS = {
    [":)"] = 0x1F642, [":-)"] = 0x1F642, ["(:"] = 0x1F642, [":]"] = 0x1F642,
    [":D"] = 0x1F600, [":-D"] = 0x1F600, ["=D"] = 0x1F600,
    ["xD"] = 0x1F606, ["XD"] = 0x1F606, ["xd"] = 0x1F606,
    [";)"] = 0x1F609, [";-)"] = 0x1F609,
    [":P"] = 0x1F61B, [":-P"] = 0x1F61B, [":p"] = 0x1F61B, [":-p"] = 0x1F61B,
    [";P"] = 0x1F61C, [";p"] = 0x1F61C,
    [":("] = 0x1F641, [":-("] = 0x1F641,
    [":'("] = 0x1F622, [";("] = 0x1F622,
    [":O"] = 0x1F62E, [":o"] = 0x1F62E, [":-O"] = 0x1F62E, [":-o"] = 0x1F62E,
    [":|"] = 0x1F610, [":-|"] = 0x1F610, ["-.-"] = 0x1F611, ["-_-"] = 0x1F611,
    ["<3"] = 0x2764, ["</3"] = 0x1F494,
    ["^^"] = 0x1F60A, ["^.^"] = 0x1F60A, ["^_^"] = 0x1F60A,
    [":3"] = 0x1F63A, [";3"] = 0x1F63A,
    [":*"] = 0x1F618, [":-*"] = 0x1F618,
    ["8)"] = 0x1F60E, ["B)"] = 0x1F60E, ["8-)"] = 0x1F60E,
    [">:("] = 0x1F620, [":/"] = 0x1F615, [":-/"] = 0x1F615,
    ["o/"] = 0x1F44B, ["\\o"] = 0x1F44B, ["(y)"] = 0x1F44D, ["(n)"] = 0x1F44E,
}

local function EmojiOn()
    return ns.db and ns.db.chatEmoji ~= false
end

local SUPPORTED = { -- Bereiche von bis (Unicode)
    { 0x20, 0x7E}, { 0xA0, 0xA3}, { 0xA5, 0xAC}, { 0xAE, 0xB4}, { 0xB6, 0x107}, { 0x10A, 0x11B},
    { 0x11E, 0x123}, { 0x126, 0x127}, { 0x12A, 0x133}, { 0x136, 0x137}, { 0x139, 0x148}, { 0x14A, 0x15B},
    { 0x15E, 0x17E}, { 0x192, 0x192}, { 0x218, 0x21B}, { 0x2C6, 0x2C7}, { 0x2D8, 0x2DD}, { 0x394, 0x394},
    { 0x3A9, 0x3A9}, { 0x3BC, 0x3BC}, { 0x3C0, 0x3C0}, { 0x1E80, 0x1E85}, { 0x1EF2, 0x1EF3},
    { 0x2013, 0x2014}, { 0x2018, 0x201A}, { 0x201C, 0x201E}, { 0x2020, 0x2022}, { 0x2026, 0x2026},
    { 0x2030, 0x2030}, { 0x2039, 0x203A}, { 0x2044, 0x2044}, { 0x2070, 0x2070}, { 0x2074, 0x2079},
    { 0x2080, 0x2089}, { 0x20AC, 0x20AC}, { 0x2117, 0x2117}, { 0x2122, 0x2122}, { 0x2153, 0x2154},
    { 0x215B, 0x215E}, { 0x2190, 0x2193}, { 0x2196, 0x2199}, { 0x2202, 0x2202}, { 0x220F, 0x220F},
    { 0x2211, 0x2212}, { 0x221A, 0x221A}, { 0x221E, 0x221E}, { 0x222B, 0x222B}, { 0x2248, 0x2248},
    { 0x2260, 0x2260}, { 0x2264, 0x2265}, { 0x25CA, 0x25CA}, { 0xFB01, 0xFB02},
}

local REPLACE = {
    [0x2665] = "<3", [0x2764] = "<3", [0x2661] = "<3", [0x1F495] = "<3", [0x1F496] = "<3", [0x1F497] = "<3",
    [0x263A] = ":)", [0x1F642] = ":)", [0x1F60A] = ":)", [0x1F60C] = ":)",
    [0x1F600] = ":D", [0x1F603] = ":D", [0x1F604] = ":D", [0x1F601] = ":D", [0x1F606] = "xD", [0x1F602] = "xD", [0x1F923] = "xD",
    [0x1F609] = ";)", [0x1F61B] = ":P", [0x1F61C] = ";P", [0x1F61D] = "xP",
    [0x1F622] = ":'(", [0x1F62D] = ":'(", [0x2639] = ":(", [0x1F641] = ":(", [0x1F61E] = ":(",
    [0x1F62E] = ":O", [0x1F632] = ":O", [0x1F610] = ":|", [0x1F914] = "hm",
    [0x1F44D] = "(y)", [0x1F44E] = "(n)",
    [0x2605] = "*", [0x2606] = "*", [0x2728] = "*",
    [0x2192] = "->", [0x2190] = "<-", [0x21D2] = "=>", [0x2194] = "<->",
    [0x266A] = "~", [0x266B] = "~", [0x2713] = "v", [0x2714] = "v", [0x2716] = "x", [0x2717] = "x",
    [0x00B4] = "'", [0x2032] = "'", [0x00AD] = "",
}

local supported = {} -- Zwischenspeicher je Zeichen
local function IsSupported(code)
    local known = supported[code]
    if known ~= nil then return known end
    for _, range in ipairs(SUPPORTED) do
        if code >= range[1] and code <= range[2] then
            supported[code] = true
            return true
        end
    end
    supported[code] = false
    return false
end

local function Decode(char)
    local b1, b2, b3, b4 = char:byte(1, 4)
    if not b2 then return b1 end
    if b1 < 0xE0 then return (b1 - 0xC0) * 0x40 + (b2 - 0x80) end
    if b1 < 0xF0 then return ((b1 - 0xE0) * 0x40 + (b2 - 0x80)) * 0x40 + (b3 - 0x80) end
    return (((b1 - 0xF0) * 0x40 + (b2 - 0x80)) * 0x40 + (b3 - 0x80)) * 0x40 + (b4 or 0x80) - 0x80
end

local function Fix(char)
    local code = Decode(char)
    if IsSupported(code) then return char end
    if code == 0xFE0F or code == 0x200D then return "" end -- Emoji-Anhängsel
    if EmojiOn() and IMAGES[code] then return IMAGES[code] end
    return REPLACE[code] or ""
end

-- Smileys nur außerhalb von Links ersetzen (|H…|h[Name]|h bleibt unverändert)
local function Smileys(text)
    local links = {}
    text = text:gsub("|H.-|h.-|h", function(link)
        links[#links + 1] = link
        return "\1" .. #links .. "\1"
    end)
    text = (" " .. text .. " "):gsub("(%s)(%S+)(%f[%s])", function(before, word, after)
        local code = SMILEYS[word]
        if code and IMAGES[code] then return before .. IMAGES[code] .. after end
    end)
    text = text:sub(2, -2):gsub("\1(%d+)\1", function(i) return links[tonumber(i)] end)
    return text
end

local function Filter(_, _, message, ...)
    if type(message) ~= "string" or issecretvalue(message) then return false end
    local fixed = message
    if fixed:find("[\128-\255]") then fixed = fixed:gsub("[\194-\244][\128-\191]*", Fix) end
    if EmojiOn() then fixed = Smileys(fixed) end
    if fixed == message then return false end
    return false, fixed, ...
end

ns:On("PLAYER_LOGIN", function()
    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    for _, event in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
        "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
        "CHAT_MSG_EMOTE", "CHAT_MSG_COMMUNITIES_CHANNEL", "CHAT_MSG_AFK", "CHAT_MSG_DND" }) do
        addFilter(event, Filter)
    end
end)
