-- Reputation chat line with a bar (inspired by Pretty Reputation). Replaces Blizzard's message:
--   +250 Darnassus  [###-------]  Friendly 2,340 / 6,000  - Session +1,250
-- The bar is 10 segments colored by standing. Printed shortly after Blizzard's message so the
-- new standing is already available; Blizzard's line is filtered out.
local _, ns = ...
local L = ns.L

local BAR_HEIGHT = 8
local session = {} -- reputation gained per faction since login

local function Enabled()
    return ns.db and ns.db.chatReputation ~= false
end

-- Turn Blizzard's global strings into match patterns (locale-independent)
local patterns = {}
for _, name in ipairs({ "FACTION_STANDING_INCREASED", "FACTION_STANDING_INCREASED_ACCOUNT_WIDE",
    "FACTION_STANDING_INCREASED_BONUS", "FACTION_STANDING_INCREASED_DOUBLE_BONUS",
    "FACTION_STANDING_INCREASED_ACH_BONUS", "FACTION_STANDING_INCREASED_ACH_BONUS_ACCOUNT_WIDE",
    "FACTION_STANDING_DECREASED", "FACTION_STANDING_DECREASED_ACCOUNT_WIDE" }) do
    local template = _G[name]
    if type(template) == "string" then
        -- Protect placeholders, escape magic chars, then insert captures
        local p = template:gsub("%%%d%$", "%%"):gsub("%%%.1f", "\1"):gsub("%%s", "\2"):gsub("%%d", "\3")
        p = p:gsub("([%(%)%.%-%+%[%]%?%^%$%*])", "%%%1")
        p = p:gsub("\1", "[%%d%%.,]+"):gsub("\2", "(.-)"):gsub("\3", "(%%d+)")
        patterns[#patterns + 1] = { pattern = "^" .. p, sign = name:find("DECREASED") and -1 or 1 }
    end
end

local function Parse(text)
    if not text or issecretvalue(text) then return end
    for _, entry in ipairs(patterns) do
        local faction, amount = text:match(entry.pattern)
        amount = tonumber(amount)
        if faction and amount then return faction, amount * entry.sign end
    end
end

-- Name -> faction ID from FACTION_STANDING_CHANGED; works even when the faction's header is
-- collapsed in the reputation pane
local idByName = {}
ns:On("FACTION_STANDING_CHANGED", function(_, factionID)
    local data = factionID and C_Reputation.GetFactionDataByID(factionID)
    if data and data.name then idByName[data.name] = factionID end
end)

local function FindFaction(name)
    local id = idByName[name]
    local data = id and C_Reputation.GetFactionDataByID(id)
    if data then return data end
    for i = 1, C_Reputation.GetNumFactions() do
        data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.name == name and not (data.isHeader and not data.isHeaderWithRep) then return data end
    end
end

-- 10 segments like the combo points; Segment.tga has a transparent gap on the right,
-- which spaces the segments apart.
local SEGMENTS, SEGMENT_WIDTH = 10, 10
local SEGMENT = ns.MEDIA .. "Segment"
local function Bar(fill, color)
    local full = math.floor(SEGMENTS * math.min(math.max(fill, 0), 1) + 0.5)
    local parts = {}
    for i = 1, SEGMENTS do
        local r, g, b = 0.2, 0.21, 0.21
        if i <= full then r, g, b = color.r, color.g, color.b end
        -- y -4: center on the text (Expressway sits low)
        parts[i] = ("|T%s:%d:%d:0:-4:16:16:0:16:0:16:%d:%d:%d|t"):format(SEGMENT, BAR_HEIGHT, SEGMENT_WIDTH,
            r * 255, g * 255, b * 255)
    end
    return table.concat(parts)
end

local function Line(name, amount)
    session[name] = (session[name] or 0) + amount
    local sign = amount >= 0 and "+" or "-"
    local accent = amount >= 0 and "|cff8ecbb4" or "|cffff6060"
    local text = accent .. sign .. BreakUpLargeNumbers(math.abs(amount)) .. "|r " .. name
    local data = FindFaction(name)
    if data and data.reaction then
        local r, g, b = ns.RepColor(data.reaction)
        local color = { r = r, g = g, b = b }
        local low, high = data.currentReactionThreshold or 0, data.nextReactionThreshold or 0
        local standing = _G["FACTION_STANDING_LABEL" .. data.reaction] or ""
        local hex = ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
        if high > low then
            local have, need = (data.currentStanding or 0) - low, high - low
            text = text .. "  " .. Bar(have / need, color) .. "  " .. hex .. standing .. "|r "
                .. BreakUpLargeNumbers(have) .. " / " .. BreakUpLargeNumbers(need)
        else -- max standing
            text = text .. "  " .. Bar(1, color) .. "  " .. hex .. standing .. "|r"
        end
    end
    if session[name] ~= amount then
        text = text .. "  |cff99978f· " .. L["Session"] .. " " .. (session[name] >= 0 and "+" or "-")
            .. BreakUpLargeNumbers(math.abs(session[name])) .. "|r"
    end
    return text
end

-- Print to every chat frame that shows reputation messages
local function Print(text)
    local info = ChatTypeInfo and ChatTypeInfo.COMBAT_FACTION_CHANGE
    local r, g, b = info and info.r or 0.5, info and info.g or 0.5, info and info.b or 1
    local count = Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or NUM_CHAT_WINDOWS
    for i = 1, count do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.ContainsMessageGroup and frame:ContainsMessageGroup("COMBAT_FACTION_CHANGE") then
            frame:AddMessage(text, r, g, b)
        end
    end
end

ns:On("PLAYER_LOGIN", function()
    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    addFilter("CHAT_MSG_COMBAT_FACTION_CHANGE", function(_, _, text)
        return Enabled() and Parse(text) ~= nil -- our line replaces Blizzard's
    end)
end)

ns:On("CHAT_MSG_COMBAT_FACTION_CHANGE", function(_, text)
    if not Enabled() then return end
    local faction, amount = Parse(text)
    if not faction then return end
    C_Timer.After(0.2, function() Print(Line(faction, amount)) end) -- new standing is available by then
end)
