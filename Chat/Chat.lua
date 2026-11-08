-- Chat tweaks (ideas from "CodeName" by solowzrd):
--   Guild nickname: own guild messages get a "(Nick): " prefix (visible to everyone);
--   incoming "(Name): " prefixes are tinted in the sender's class color.
--   Remember last chat type/target per character across login/reload.
-- Midnight locks chat for addons in some situations (boss, M+, PvP); then we touch nothing.
-- C_ChatInfo.InChatMessagingLockdown() reports this, and incoming text may be secret there.
local _, ns = ...

local CHAT_TYPES = { GUILD = true } -- chat types that get the nickname prefix
local MAX_LENGTH = 255

local function Nickname()
    local name = ns.root and ns.root.nickname
    if name and strtrim(name) ~= "" then return strtrim(name) end
end

local function Prefix()
    local name = Nickname()
    return name and ("(" .. name .. "): ")
end

local function Locked()
    return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function ChatType(editBox)
    return editBox:GetAttribute("chatType") or editBox.chatType
end

local function StartsWith(text, prefix)
    return text:sub(1, #prefix) == prefix
end

-- Prepend the nickname on Enter. OnKeyDown fires before Blizzard's OnEnterPressed sends
-- the text. Slash commands are left alone.
local function OnKeyDown(editBox, key)
    if key ~= "ENTER" and key ~= "NUMPADENTER" then return end
    local prefix = Prefix()
    if not prefix or Locked() or not CHAT_TYPES[ChatType(editBox)] then return end
    local text = editBox:GetText() or ""
    if text == "" or text:find("^[/!#@?]") or StartsWith(text, prefix) then return end
    editBox:SetText((prefix .. text):sub(1, MAX_LENGTH))
end

-- Strip the nickname from messages recalled via history (up/down arrow).
local function OnHistory(editBox, key)
    if key ~= "UP" and key ~= "DOWN" then return end
    local prefix = Prefix()
    if not prefix or Locked() then return end
    C_Timer.After(0, function()
        local text = editBox:GetText() or ""
        if StartsWith(text, prefix) then editBox:SetText(text:sub(#prefix + 1)) end
    end)
end

-- Save chat type (and target) on send, restore it on login.
local REMEMBER = {
    SAY = true, YELL = true, GUILD = true, OFFICER = true, PARTY = true, RAID = true,
    INSTANCE_CHAT = true, WHISPER = true, CHANNEL = true,
}
local pendingRestore = false

local function RememberChat(editBox, key)
    if key ~= "ENTER" and key ~= "NUMPADENTER" then return end
    if (editBox:GetText() or "") == "" then return end
    local chatType = ChatType(editBox)
    if not REMEMBER[chatType] then return end
    local target
    if chatType == "WHISPER" then
        target = editBox:GetAttribute("tellTarget")
    elseif chatType == "CHANNEL" then
        target = editBox:GetAttribute("channelTarget")
    end
    ns.char.lastChat = { type = chatType, target = target }
end

local function RestoreChat()
    local last = ns.char and ns.char.lastChat
    local editBox = ChatFrame1EditBox
    if not (last and editBox) then
        pendingRestore = false
        return
    end
    if Locked() or InCombatLockdown() then
        pendingRestore = true -- retry after combat / zone change
        return
    end
    if last.type == "WHISPER" and last.target then editBox:SetAttribute("tellTarget", last.target) end
    if last.type == "CHANNEL" and last.target then editBox:SetAttribute("channelTarget", last.target) end
    editBox:SetAttribute("chatType", last.type)
    editBox:SetAttribute("stickyType", last.type) -- Blizzard resets chatType to this on open
    if editBox.UpdateHeader then editBox:UpdateHeader() end
    pendingRestore = false
end

for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA" }) do
    ns:On(event, function() if pendingRestore then RestoreChat() end end)
end

-- Incoming "(Name): text" -> tint Name in the sender's class color.
local function ColorNickname(_, _, message, author, ...)
    if issecretvalue(message) or issecretvalue(author) then return false, message, author, ... end
    local name, rest = message:match("^%(([^%(%)]+)%)(%s*:.*)$")
    if not name then return false, message, author, ... end
    local guid = select(10, ...) -- 12th chat event argument
    local class = guid and not issecretvalue(guid) and select(2, GetPlayerInfoByGUID(guid))
    local color = class and C_ClassColor.GetClassColor(class)
    if not color then return false, message, author, ... end
    return false, ("(%s)%s"):format(color:WrapTextInColorCode(name), rest), author, ...
end

-- Short channel header in the edit box: "[1]:" instead of "[1. General - Teldrassil]:".
-- Runs after Blizzard's UpdateHeader and resets the text insets.
local function ShortHeader(editBox)
    if ns.db.chatShortChannels == false or editBox:GetChatType() ~= "CHANNEL" then return end
    local header = _G[editBox:GetName() .. "Header"]
    local suffix = _G[editBox:GetName() .. "HeaderSuffix"]
    local localID = editBox:GetChannelTarget()
    if not (header and localID) then return end
    header:SetWidth(0)
    header:SetText(("[%s]: "):format(localID))
    if suffix then suffix:Hide() end
    local language = editBox.UpdateLanguageHeader and editBox:UpdateLanguageHeader() or 0
    editBox:SetTextInsets(15 + header:GetWidth() + language, 13, 0, 0)
end

ns:On("PLAYER_LOGIN", function()
    local count = Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or NUM_CHAT_WINDOWS
    for i = 1, count do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            editBox:HookScript("OnKeyDown", OnKeyDown)
            editBox:HookScript("OnKeyDown", OnHistory)
            editBox:HookScript("OnKeyDown", RememberChat)
            if editBox.UpdateHeader then hooksecurefunc(editBox, "UpdateHeader", ShortHeader) end
        end
    end
    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    addFilter("CHAT_MSG_GUILD", ColorNickname)
    -- Hide "changed/left/joined channel" spam on zone changes; other channel notices stay.
    -- Pitfall: on YOU_CHANGED Blizzard adds the channel to the chat frame (ChatFrame_CheckAddChannel,
    -- runs after filters). Swallowing it without adding mutes General/Trade, so add it here
    -- the same way Blizzard does (main frame, regional channels only).
    local CHANNEL_NOISE = { YOU_CHANGED = true, YOU_LEFT = true, YOU_JOINED = true }
    addFilter("CHAT_MSG_CHANNEL_NOTICE", function(frame, _, notice, _, _, _, _, _, channelID)
        if issecretvalue(notice) or not CHANNEL_NOISE[notice] then return false end
        if notice == "YOU_CHANGED" and frame == DEFAULT_CHAT_FRAME and channelID and C_ChatInfo.IsChannelRegionalForChannelID
            and C_ChatInfo.IsChannelRegionalForChannelID(channelID) then
            frame:AddChannel(C_ChatInfo.GetChannelShortcutForChannelID(channelID))
        end
        return true
    end)
    C_Timer.After(2, RestoreChat) -- after Blizzard's own chat setup
end)
