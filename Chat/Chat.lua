-- Chat-Kleinigkeiten (Ideen aus „CodeName“ von solowzrd):
--   Spitzname im Gildenchat: Steht einer in den Einstellungen, beginnt jede eigene
--   Gildennachricht mit „(Benny): “ – das sehen alle, auch ohne Addon. Eingehende
--   Gildennachrichten mit „(Name): “ bekommen den Namen in der Klassenfarbe des Absenders.
--   Letzten Chat merken: Nach Login/Reload schreibt man dort weiter, wo man aufgehört hat
--   (Gilde, Gruppe, Flüstern an …) – pro Charakter.
--
-- Midnight sperrt Chat für Addons in bestimmten Lagen (Bosskampf, M+, PvP …). Dann fassen wir
-- nichts an: C_ChatInfo.InChatMessagingLockdown() sagt das zuverlässig, und eingehende Texte
-- können dort geschützt (Secret) sein.
local _, ns = ...

local CHAT_TYPES = { GUILD = true } -- wo der Spitzname vorangestellt wird
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

-- Vor dem Senden (Enter) den Spitznamen voranstellen. OnKeyDown kommt vor Blizzards
-- OnEnterPressed, das den Text verschickt. Befehle (/…) bleiben unberührt.
local function OnKeyDown(editBox, key)
    if key ~= "ENTER" and key ~= "NUMPADENTER" then return end
    local prefix = Prefix()
    if not prefix or Locked() or not CHAT_TYPES[ChatType(editBox)] then return end
    local text = editBox:GetText() or ""
    if text == "" or text:find("^[/!#@?]") or StartsWith(text, prefix) then return end
    editBox:SetText((prefix .. text):sub(1, MAX_LENGTH))
end

-- Pfeil hoch/runter holt alte Nachrichten zurück – ohne den Spitznamen davor.
local function OnHistory(editBox, key)
    if key ~= "UP" and key ~= "DOWN" then return end
    local prefix = Prefix()
    if not prefix or Locked() then return end
    C_Timer.After(0, function()
        local text = editBox:GetText() or ""
        if StartsWith(text, prefix) then editBox:SetText(text:sub(#prefix + 1)) end
    end)
end

-- Letzten Chat merken: beim Senden Art (und Ziel) speichern, beim Login wiederherstellen.
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
        pendingRestore = true -- später nochmal (Kampfende, Zonenwechsel)
        return
    end
    if last.type == "WHISPER" and last.target then editBox:SetAttribute("tellTarget", last.target) end
    if last.type == "CHANNEL" and last.target then editBox:SetAttribute("channelTarget", last.target) end
    editBox:SetAttribute("chatType", last.type)
    editBox:SetAttribute("stickyType", last.type) -- Blizzard setzt die Art beim Öffnen darauf zurück
    if editBox.UpdateHeader then editBox:UpdateHeader() end
    pendingRestore = false
end

for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA" }) do
    ns:On(event, function() if pendingRestore then RestoreChat() end end)
end

-- Eingehend: „(Name): Text“ > Name in Klassenfarbe des Absenders.
local function ColorNickname(_, _, message, author, ...)
    if issecretvalue(message) or issecretvalue(author) then return false, message, author, ... end
    local name, rest = message:match("^%(([^%(%)]+)%)(%s*:.*)$")
    if not name then return false, message, author, ... end
    local guid = select(10, ...) -- 12. Argument des Chat-Events
    local class = guid and not issecretvalue(guid) and select(2, GetPlayerInfoByGUID(guid))
    local color = class and C_ClassColor.GetClassColor(class)
    if not color then return false, message, author, ... end
    return false, ("(%s)%s"):format(color:WrapTextInColorCode(name), rest), author, ...
end

-- Eingabezeile: „[1. Allgemein - Teldrassil]:“ nimmt viel Platz – mit kurzen Kanalnamen nur „[1]:“
-- (Benny 2026-11-06). Läuft nach Blizzards UpdateHeader und setzt den Textabstand neu.
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
    -- „Channel gewechselt/verlassen/beigetreten“ bei jedem Zonenwechsel ausblenden (Benny 2026-11-08:
    -- in Forever ständig, „total unnötig“); andere Kanal-Meldungen (Fehler, Sperren) bleiben
    -- ACHTUNG: Blizzard trägt bei YOU_CHANGED den Kanal ins Chatfenster ein (ChatFrame_CheckAddChannel,
    -- läuft nach den Filtern). Verschlucken ohne Eintragen = Allgemein/Handel stumm (Benny 2026-11-08).
    -- Darum hier vorher selbst eintragen, genau wie Blizzard (nur Hauptfenster, nur regionale Kanäle).
    local CHANNEL_NOISE = { YOU_CHANGED = true, YOU_LEFT = true, YOU_JOINED = true }
    addFilter("CHAT_MSG_CHANNEL_NOTICE", function(frame, _, notice, _, _, _, _, _, channelID)
        if issecretvalue(notice) or not CHANNEL_NOISE[notice] then return false end
        if notice == "YOU_CHANGED" and frame == DEFAULT_CHAT_FRAME and channelID and C_ChatInfo.IsChannelRegionalForChannelID
            and C_ChatInfo.IsChannelRegionalForChannelID(channelID) then
            frame:AddChannel(C_ChatInfo.GetChannelShortcutForChannelID(channelID))
        end
        return true
    end)
    C_Timer.After(2, RestoreChat) -- nach Blizzards eigener Chat-Einrichtung
end)
