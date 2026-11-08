-- Battle.net-Meldungen (Freund online/offline, Statusnachricht, Einladungen) als MUI-Toasts statt
-- Blizzards Kasten über dem Chat (Benny 2026-11-06: „soll einfach in die Toasts mit rein“).
--
-- mUI hört selbst auf die Battle.net-Ereignisse (wie Blizzards BNToastMixin:OnEvent). Früher hing
-- mUI an BNToastFrame:AddToast – das kam in Forever nie an (Benny 2026-11-08: Freund online, nur
-- Chatzeile, kein Toast, keine Spur im DevLog). Blizzards Kasten bleibt geparkt und bekommt die
-- Ereignisse nicht mehr (sonst doppelter Ton); den Ton spielt jetzt mUI.
local _, ns = ...

local BNET_BLUE = { 0.51, 0.773, 1 }
-- eigene Toast-Arten: Forever kennt Blizzards BN_TOAST_TYPE_* nicht (alle nil > „offline“ landete im
-- online-Zweig, DevLog „Typ=nil“, 2026-11-08)
local T = { ONLINE = 1, OFFLINE = 2, BROADCAST = 3, PENDING_INVITES = 4, NEW_INVITE = 5, CLUB_INVITATION = 6 }
local GREY = { 0.6, 0.59, 0.56 }
local ICON = ns.MEDIA .. "Icons\\Friends"

local hidden = CreateFrame("Frame")
hidden:Hide()

local function Account(id)
    return id and C_BattleNet and C_BattleNet.GetAccountInfoByID(id)
end

-- Spielfigur des Freundes, wenn er gerade WoW spielt (sonst nur der Battle.net-Name)
local function CharacterLine(info)
    local game = info.gameAccountInfo
    local name = game and game.characterName
    if not name or name == "" then return nil end
    local class = game.className
    for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
        if localized == class then
            local color = RAID_CLASS_COLORS[token]
            if color then return color:WrapTextInColorCode(name) end
        end
    end
    return name
end

local function Whisper(info)
    return function()
        if info and info.accountName and ChatFrameUtil and ChatFrameUtil.SendBNetTell then
            ChatFrameUtil.SendBNetTell(info.accountName)
        end
    end
end

local function OpenFriends()
    if ns.OpenFriends then
        ns.OpenFriends("friends") -- mUI-Freundesfenster (Forever)
    elseif FriendsFrame and not FriendsFrame:IsShown() and ToggleFriendsFrame then
        ToggleFriendsFrame(FRIEND_TAB_FRIENDS)
    end
end

-- stille Spur im DevLog (Benny 2026-11-07: Freund kam online, nur der Ton, kein Toast)
local function Trace(fmt, ...)
    if DevLog then DevLog("MeredanUI", fmt:format(...)) end
end

local function Show(toastType, toastData)
    local data
    Trace("BNet-Toast Typ=%s Daten=%s Konto=%s", tostring(toastType), tostring(toastData),
        tostring(Account(type(toastData) == "number" and toastData or nil) ~= nil))
    if toastType == T.ONLINE then
        local info = Account(toastData)
        if not info then return end
        local character = CharacterLine(info)
        data = { title = info.accountName, color = BNET_BLUE, onClick = Whisper(info),
            text = (character and character .. " – " or "") .. "|cff33ff33" .. (BN_TOAST_ONLINE or "online") .. "|r" }
    elseif toastType == T.OFFLINE then
        local info = Account(toastData)
        if not info then return end
        data = { title = info.accountName, color = GREY, text = BN_TOAST_OFFLINE or "offline" }
    elseif toastType == T.BROADCAST then
        local info = Account(toastData)
        if not info or not info.customMessage or info.customMessage == "" then return end
        data = { title = info.accountName, color = BNET_BLUE, text = info.customMessage, onClick = Whisper(info) }
    elseif toastType == T.NEW_INVITE then
        data = { title = FRIENDS or "Friends", color = BNET_BLUE, text = BN_TOAST_NEW_INVITE, onClick = OpenFriends }
    elseif toastType == T.PENDING_INVITES then
        data = { title = FRIENDS or "Friends", color = BNET_BLUE, onClick = OpenFriends,
            text = BN_TOAST_PENDING_INVITES and BN_TOAST_PENDING_INVITES:format(toastData or 0) }
    elseif toastType == T.CLUB_INVITATION then
        local name = toastType == T.CLUB_INVITATION and toastData and toastData.club and toastData.club.name
            or (toastData and toastData.name)
        data = { title = COMMUNITIES or "Communities", color = BNET_BLUE,
            text = BN_TOAST_NEW_CLUB_INVITATION and BN_TOAST_NEW_CLUB_INVITATION:format(name or "") }
    end
    if not data or not data.text then Trace("BNet-Toast verworfen (kein Text)") return end
    data.icon = ICON
    data.key = "bnet:" .. tostring(toastType) .. ":" .. tostring(toastData)
    if SOUNDKIT and SOUNDKIT.UI_BNET_TOAST then PlaySound(SOUNDKIT.UI_BNET_TOAST) end
    Trace("BNet-Toast an mUI: %s / %s -> %s", tostring(data.title), tostring(data.text), tostring(ns.AddToast(data)))
end

-- Ereignis > Toast-Art (wie Blizzard_BNet/Mainline/BNet.lua); Mobil-App-Logins meldet auch Blizzard nicht
local EVENTS = {
    BN_FRIEND_ACCOUNT_ONLINE = function(id, companion) if not companion then Show(T.ONLINE, id) end end,
    BN_FRIEND_ACCOUNT_OFFLINE = function(id, companion) if not companion then Show(T.OFFLINE, id) end end,
    BN_CUSTOM_MESSAGE_CHANGED = function(id) if id then Show(T.BROADCAST, id) end end, -- nil = eigene Nachricht
    BN_FRIEND_INVITE_ADDED = function() Show(T.NEW_INVITE) end,
    BN_FRIEND_INVITE_LIST_INITIALIZED = function(count) if (count or 0) > 0 then Show(T.PENDING_INVITES, count) end end,
    CLUB_INVITATION_ADDED_FOR_SELF = function(invitation) Show(T.CLUB_INVITATION, invitation) end,
}

ns:On("PLAYER_LOGIN", function()
    if ns.db.toasts == false then return end
    local frame = BNToastFrame
    if frame then
        frame:SetParent(hidden) -- Blizzards Kasten unsichtbar
        for event in pairs(EVENTS) do frame:UnregisterEvent(event) end
    end
    local listener = CreateFrame("Frame")
    for event in pairs(EVENTS) do pcall(listener.RegisterEvent, listener, event) end
    listener:SetScript("OnEvent", function(_, event, ...)
        Trace("BNet-Ereignis %s %s %s", event, tostring((...)), tostring(select(2, ...)))
        EVENTS[event](...)
    end)
end)
