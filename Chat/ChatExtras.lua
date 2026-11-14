-- Chat extras (ideas from Prat): arrow keys without Alt, hover tooltips for links, scrolling with
-- modifiers, clickable "inv" words, a spam brake for public channels and levels at player names.
-- All text work skips secret values (chat lockdown in instances): those lines stay untouched.
local _, ns = ...
local L = ns.L

local function AddFilter(event, fn)
    local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    add(event, fn)
end

local function Readable(...)
    for i = 1, select("#", ...) do
        if issecretvalue(select(i, ...)) then return false end
    end
    return true
end

-- Forever names have a surname ("First Last"); links and chat events may carry it with a space or a
-- hyphen and with or without realm. Compare without spaces/hyphens, own name as prefix.
local function Squash(name) return (name:gsub("[%s%-]", ""):lower()) end
local myNames
local function IsMe(author)
    if not author or author == "" then return false end
    if not myNames then
        myNames = {}
        for _, name in ipairs({ UnitName("player"), UnitNameUnmodified and UnitNameUnmodified("player"),
            GetUnitName("player", false) }) do
            if type(name) == "string" and not issecretvalue(name) and name ~= "" then myNames[#myNames + 1] = Squash(name) end
        end
        table.sort(myNames, function(a, b) return #a > #b end)
    end
    local squashed = Squash(author)
    local realm = Squash(GetRealmName() or "")
    for _, mine in ipairs(myNames) do
        if squashed == mine or squashed == mine .. realm then return true end
    end
    return false
end

-- Arrow keys --------------------------------------------------------------------------------------
-- Blizzard's chat input passes plain arrow keys to the game (Alt+arrows move the cursor and
-- recall sent lines). Without Alt mode the arrows work like in any text field. AutoComplete
-- switches the mode off itself while its list is open and restores the value it found.
local function ApplyArrowKeys(editBox)
    if editBox and editBox.SetAltArrowKeyMode then
        editBox:SetAltArrowKeyMode(ns.db.chatArrowKeys == false)
    end
end

function ns.ApplyChatArrowKeys()
    for _, name in ipairs(CHAT_FRAMES or {}) do ApplyArrowKeys(_G[name .. "EditBox"]) end
end

-- Hover tooltips ----------------------------------------------------------------------------------
local HOVER_TYPES = {
    item = true, spell = true, enchant = true, quest = true, achievement = true, currency = true,
    talent = true, glyph = true, instancelock = true,
}
local INV_LINK = "muiinv"
local showing

local function ShowOwnLinkTip(frame, kind, data)
    if kind == INV_LINK then
        local mode, name = data:match("^(%a+):(.+)$")
        if not name then return false end
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        GameTooltip:SetText(Ambiguate(name, "none"), 1, 1, 1)
        GameTooltip:AddLine(mode == "req" and L["Click: ask to join their group"] or L["Click: invite to your group"],
            ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3])
        GameTooltip:Show()
        return true
    elseif kind == "muiurl" then
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        GameTooltip:SetText(L["Click: copy link"], 1, 1, 1)
        GameTooltip:Show()
        return true
    end
    return false
end

local function OnLinkEnter(frame, link)
    if ns.db.chatHoverTips == false or type(link) ~= "string" or issecretvalue(link) then return end
    local kind, data = link:match("^([%a]+):(.*)$")
    if not kind then return end
    if HOVER_TYPES[kind] then
        GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
        if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
            GameTooltip:Show()
            showing = frame
        else
            GameTooltip:Hide()
        end
    elseif ShowOwnLinkTip(frame, kind, data) then
        showing = frame
    end
end

local function OnLinkLeave(frame)
    if showing == frame then
        showing = nil
        GameTooltip:Hide()
    end
end

-- Scrolling ---------------------------------------------------------------------------------------
-- After Blizzard's one-line scroll: Ctrl jumps to the top/bottom, Shift scrolls a page.
local function OnWheel(frame, delta)
    if ns.db.chatScrollKeys == false then return end
    if IsControlKeyDown() then
        if delta > 0 then frame:ScrollToTop() else frame:ScrollToBottom() end
    elseif IsShiftKeyDown() then
        if delta > 0 then frame:PageUp() else frame:PageDown() end
    end
end

local hooked = {}
local function HookFrame(name)
    local frame = _G[name]
    if not frame or hooked[frame] then return end
    hooked[frame] = true
    frame:HookScript("OnHyperlinkEnter", OnLinkEnter)
    frame:HookScript("OnHyperlinkLeave", OnLinkLeave)
    frame:HookScript("OnMouseWheel", OnWheel)
    local editBox = _G[name .. "EditBox"]
    ApplyArrowKeys(editBox)
end

local function HookAll()
    for _, name in ipairs(CHAT_FRAMES or {}) do HookFrame(name) end
end

-- Clickable "inv" -------------------------------------------------------------------------------
-- "inv", "invite", "invme" in someone else's message becomes a link. Click invites the sender - or,
-- when the message looks for more players (LFM), asks to join the sender's group instead.
local INV_WORDS = { inv = true, invite = true, invme = true, invit = true }
local INV_EVENTS = { "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER" }
local LFM_PATTERNS = { "%f[%a]lf%d*m%f[%A]", "looking for more", "%f[%a]need%f[%A]" }

local function LooksForMore(text)
    local lower = text:lower()
    for _, pattern in ipairs(LFM_PATTERNS) do
        if lower:find(pattern) then return true end
    end
    return false
end

-- Run fn on the text outside of links (|H...|h...|h), links stay as they are
local function OutsideLinks(text, fn)
    local links = {}
    text = text:gsub("|H.-|h.-|h", function(link)
        links[#links + 1] = link
        return "\001" .. #links .. "\001"
    end)
    text = fn(text)
    return (text:gsub("\001(%d+)\001", function(i) return links[tonumber(i)] end))
end

local function InviteFilter(_, _, message, author, ...)
    if ns.db.chatInviteLinks == false or not Readable(message, author) or not author or author == ""
        or IsMe(author) then
        return false, message, author, ...
    end
    if not message:lower():find("inv", 1, true) then return false, message, author, ... end
    local mode = LooksForMore(message) and "req" or "inv"
    local done = false
    local result = OutsideLinks(message, function(text)
        return (text:gsub("%f[%a](%a+)%f[%A]", function(word)
            if done or not INV_WORDS[word:lower()] then return nil end
            done = true
            return ("%s|H%s:%s:%s|h[%s]|h|r"):format(ns.UI.ACCENT_HEX, INV_LINK, mode, author, word)
        end))
    end)
    return false, result, author, ...
end

if LinkUtil and LinkUtil.RegisterLinkHandler and not LinkUtil.IsLinkHandlerRegistered(INV_LINK) then
    LinkUtil.RegisterLinkHandler(INV_LINK, function(_, _, linkData)
        local mode, name = (linkData.options or ""):match("^(%a+):(.+)$")
        if name then
            if mode == "req" and C_PartyInfo.RequestInviteFromUnit then
                C_PartyInfo.RequestInviteFromUnit(name)
            else
                C_PartyInfo.InviteUnit(name)
            end
        end
        return LinkProcessorResponse.Handled
    end)
end

-- Spam brake --------------------------------------------------------------------------------------
-- The same message from the same player in a public channel shows once per SPAM_WINDOW seconds.
-- Filters run once per chat frame for the same line, so the line ID that passed is let through again.
local SPAM_WINDOW = 180
local seen, seenCount = {}, 0

local function SpamKey(author, message)
    local text = message:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", " ")
    return author .. "\001" .. strtrim(text)
end

local function Prune(now)
    for key, entry in pairs(seen) do
        if now - entry.time > SPAM_WINDOW then
            seen[key] = nil
            seenCount = seenCount - 1
        end
    end
end

local function SpamFilter(_, _, message, author, ...)
    if ns.db.chatSpamFilter == false then return false end
    local lineID = select(9, ...)
    if not Readable(message, author, lineID) or not author or IsMe(author) then return false end
    local key, now = SpamKey(author, message), GetTime()
    local entry = seen[key]
    if entry and entry.line ~= lineID and now - entry.time < SPAM_WINDOW then return true end
    if not entry or entry.line ~= lineID then
        if not entry then seenCount = seenCount + 1 end
        seen[key] = { time = now, line = lineID }
        if seenCount > 400 then Prune(now) end
    end
    return false
end

-- Levels at names ---------------------------------------------------------------------------------
-- Known levels from group, guild, friends, /who and units you look at. Max-level players get no
-- number (at the level cap nearly everyone has it).
local levels = {}

local function Store(name, level)
    if not name or not level or issecretvalue(name) or issecretvalue(level) or level <= 0 then return end
    levels[Ambiguate(name, "none")] = level
end

local function StoreUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    local name, realm = UnitName(unit)
    if issecretvalue(name) or issecretvalue(realm) then return end
    if name and realm and realm ~= "" then name = name .. "-" .. realm end
    Store(name, UnitLevel(unit))
end

local function ScanGroup()
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do StoreUnit("raid" .. i) end
    else
        for i = 1, 4 do StoreUnit("party" .. i) end
    end
end

local function ScanGuild()
    if not IsInGuild() then return end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, level = GetGuildRosterInfo(i)
        Store(name, level)
    end
end

local function ScanFriends()
    for i = 1, C_FriendList.GetNumFriends() do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected then Store(info.name, info.level) end
    end
end

local function ScanWho()
    local num = C_FriendList.GetNumWhoResults and C_FriendList.GetNumWhoResults() or 0
    for i = 1, num do
        local info = C_FriendList.GetWhoInfo(i)
        if info then Store(info.fullName, info.level) end
    end
end

local LEVEL_EVENTS = {
    GROUP_ROSTER_UPDATE = ScanGroup, GUILD_ROSTER_UPDATE = ScanGuild, FRIENDLIST_UPDATE = ScanFriends,
    WHO_LIST_UPDATE = ScanWho,
    PLAYER_TARGET_CHANGED = function() StoreUnit("target") end,
    UPDATE_MOUSEOVER_UNIT = function() StoreUnit("mouseover") end,
    UNIT_LEVEL = function(_, unit) if unit and not issecretvalue(unit) then StoreUnit(unit) end end,
}

local function MaxLevel()
    return GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 60
end

-- Player link: |Hplayer:Name-Realm:lineID...|h[Name]|h -> [Name:12], level in difficulty color
function ns.ChatLevels(text)
    if ns.db.chatLevels == false or not text:find("|Hplayer:", 1, true) then return text end
    return (text:gsub("(|Hplayer:([^:|]+)[^|]*|h%[)(.-)(%]|h)", function(open, name, shown, close)
        local short = Ambiguate(name, "none")
        local level = levels[short]
        if not level or level >= MaxLevel() or IsMe(name) then return nil end
        local color = GetQuestDifficultyColor(level)
        local hex = ("|cff%02x%02x%02x"):format(color.r * 255, color.g * 255, color.b * 255)
        return ("%s%s|r:%s%d|r%s"):format(open, shown, hex, level, close)
    end, 1))
end

-- Demo (Settings > Chat, /mui t): a group search line showing level, "inv" link and a hoverable item
function ns.ChatExtrasDemo(frame)
    local name = "Thalordin"
    levels[name] = math.max(1, math.min(MaxLevel() - 1, UnitLevel("player") + 2))
    local message = "LFM Deadmines, need tank, w/ inv |cff0070dd|Hitem:2042::::::::|h[Staff of Westfall]|h|r"
    local _, text = InviteFilter(nil, nil, message, name)
    local info = ChatTypeInfo.CHANNEL1 or ChatTypeInfo.CHANNEL
    local line = ("|Hchannel:channel:4|h[4. LookingForGroup]|h |Hplayer:%s:0|h[%s]|h: %s"):format(name, name, text)
    frame:AddMessage(line, info.r, info.g, info.b)
end

-- Setup -------------------------------------------------------------------------------------------
ns:On("PLAYER_LOGIN", function()
    HookAll()
    if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", HookAll) end
    for _, event in ipairs(INV_EVENTS) do AddFilter(event, InviteFilter) end
    AddFilter("CHAT_MSG_CHANNEL", SpamFilter)
    for event, fn in pairs(LEVEL_EVENTS) do ns:On(event, fn) end
    ScanGroup()
    ScanFriends()
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end)
