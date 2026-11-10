-- Class icon in front of the sender's name in guild, group, raid and whispers (not Trade/General).
-- The event filter remembers the class per chat line (lineID -> class from the sender GUID);
-- the AddMessage wrapper in Chat/ChatStyle.lua puts the icon in front of that line's player link.
-- Secret values (encounters in instances) are skipped: the line just stays without icon.
local _, ns = ...

local EVENTS = {
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
}
local MAX_LINES = 100

local classByLine, order = {}, {}
local markup = {}

-- Size follows the chat font (a bit larger than the letters, never below 14), cached per size
local function Markup(class)
    local _, font = ChatFrame1 and ChatFrame1:GetFont()
    local size = math.max(14, math.floor((font or 14) * 1.15 + 0.5))
    local key = class .. size
    if markup[key] == nil then
        local atlas = "groupfinder-icon-class-" .. class:lower() .. "-c60-2x"
        if not C_Texture.GetAtlasInfo(atlas) then atlas = "groupfinder-icon-class-" .. class:lower() end
        -- y -3: centred on the letters (higher values sat too high)
        markup[key] = C_Texture.GetAtlasInfo(atlas) and CreateAtlasMarkup(atlas, size, size, 0, -3) or false
    end
    return markup[key] or nil
end

local function Remember(_, _, message, author, ...)
    if ns.db.chatClassIcons == false then return false, message, author, ... end
    local lineID, guid = select(9, ...), select(10, ...) -- 11th and 12th event argument
    if lineID and guid and not issecretvalue(lineID) and not issecretvalue(guid) and guid ~= ""
        and not classByLine[lineID] then
        local _, class = GetPlayerInfoByGUID(guid)
        if class and not issecretvalue(class) then
            classByLine[lineID] = class
            order[#order + 1] = lineID
            if #order > MAX_LINES then classByLine[table.remove(order, 1)] = nil end
        end
    end
    return false, message, author, ...
end

-- Player link: |Hplayer:Name-Realm:lineID:CHANNEL...|h[Name]|h
function ns.ChatClassIcons(text)
    if ns.db.chatClassIcons == false or not text:find("|Hplayer:", 1, true) then return text end
    -- only the first link (the sender), the line may name other players too
    return (text:gsub("(|Hplayer:[^:|]*:(%d+))", function(link, lineID)
        local class = classByLine[tonumber(lineID)]
        local icon = class and Markup(class)
        if not icon then return nil end
        return icon .. link -- no space: the gap before "[" already balances the one after "[G]"
    end, 1))
end

ns:On("PLAYER_LOGIN", function()
    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    for _, event in ipairs(EVENTS) do addFilter(event, Remember) end
end)
