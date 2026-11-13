-- Friends window (WoW Forever) replacing Blizzard's SocialUIFrame - same window family as merchant,
-- mailbox, spellbook (header, tabs on the right).
--
--   [icon] Friends                               [x]
--          2 of 13 online
--   [o v]  Koratal#21168  [copy]                 [ignore]  <- status, copy BattleTag, ignore list
--   [Search                                ] [filter]      <- filter: status, tags
--   FRIENDS  2/13                                 -
--  | o BULLDOZER                         [App][+]          <- game icon (Blizzard), invite
--  |   Koratal - Lvl 23 - Darkshore
--   2 of 13 online                        [+ Friend]
--
-- Data, tooltips, context menus and invites come from Blizzard (FriendsListUtil,
-- FriendsListSocialCardMixin, UnitPopup_OpenMenu ...); only layout and look are ours.
-- O (TOGGLESOCIAL), the friends/raid keys, ToggleFriendsFrame and SocialUIControl (chat friends
-- button, request notices) are redirected to this window.
local _, ns = ...
local L = ns.L

local WIDTH = 400
local PAD = ns.NPC_PAD
local ROW_GAP = 2
local TAB_SIZE, TAB_STEP = 40, 46
local GREEN = { 0.56, 0.8, 0.71 }
local BNET_BLUE = { 0.31, 0.7, 1 }

local window, list, searchBox, searchHint, filterButton, filterMenu, statusButton, tagText, footerText
local emptyText, infoText, actionButton
local SyncSecure -- defined below
local secure, statusSecure, convertSecure -- secure buttons on their own layer (status, convert to raid)
local tabs, rows, headers = {}, {}, {}
local current = 1
local filterChecks = {}   -- filter option -> true (this session only, like Blizzard)
local collapsed = {}
local pending = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.friendsWindow ~= false and C_BattleNet and FriendsListUtil ~= nil
        and SocialUIUtil ~= nil
end

-- Tabs ------------------------------------------------------------------------------------------

local TABS = {
    { key = "friends", name = SOCIAL_UI_FRIENDS_TAB_NAME, atlas = "friends-icon-tab-friends",
      social = SocialUITabType and SocialUITabType.Friends,
      available = function() return C_BattleNet.IsBattleNetFriendsListEnabled() end },
    { key = "allies", name = SOCIAL_UI_RECENT_ALLIES_TAB_NAME, atlas = "friends-icon-tab-recentallies",
      social = SocialUITabType and SocialUITabType.RecentAllies,
      available = function() return C_RecentAllies and C_RecentAllies.IsSystemEnabled() end },
    { key = "requests", name = SOCIAL_UI_FRIEND_REQUESTS_TAB_NAME, atlas = "friends-icon-tab-friendrequest",
      social = SocialUITabType and SocialUITabType.FriendRequests,
      available = function() return C_BattleNet.IsBattleNetFriendsListEnabled() end,
      count = function() return BNGetNumFriendInvites() or 0 end },
    { key = "raid", name = SOCIAL_UI_RAID_TAB_NAME, atlas = "friends-icon-tab-raid",
      social = SocialUITabType and SocialUITabType.RaidList,
      available = function() return C_PartyInfo.IsRaidListEnabled() end },
}

local function TabIndex(key)
    for i, tab in ipairs(TABS) do
        if tab.key == key then return i end
    end
end

-- Widgets ---------------------------------------------------------------------------------------

local function Header(i)
    if headers[i] then return headers[i] end
    local UI = ns.UI
    local header = CreateFrame("Button", nil, list.child)
    header:SetHeight(26)
    UI.Box(header, { 0.1, 0.1, 0.11, 1 })
    header.text = UI.Heading(header, 13, "LEFT")
    header.text:SetPoint("LEFT", 8, 0)
    header.count = UI.Text(header, 12, "LEFT", UI.MUTED)
    header.count:SetPoint("LEFT", header.text, "RIGHT", 8, 0)
    header.sign = UI.Icon(header, "Minus", 12, UI.MUTED)
    header.sign:SetPoint("RIGHT", -8, 0)
    header:SetScript("OnClick", function(self)
        collapsed[self.key] = not collapsed[self.key] or nil
        window.Refresh()
    end)
    headers[i] = header
    return header
end

-- Small icon button in a row (invite, accept, decline)
local function RowButton(parent)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button.bg = UI.Box(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button:SetMotionScriptsWhileDisabled(true)
    button:HookScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(UI.HOVER)) end)
    button:HookScript("OnLeave", function(self) self.bg:SetColorTexture(unpack(UI.FIELD)) end)
    return button
end

-- Blizzard's recent-ally tooltip needs these methods on the row
local ALLY_METHODS = { "AddCharacterDataToTooltip", "AddStateDataToTooltip", "AddInteractionDataToTooltip",
    "AddInteractionsToTooltip", "GetMostRecentInteraction", "HasInteractions", "ConvertInteractionToTooltipString" }

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Reuse Blizzard's card methods (tooltip, menu) on our row; for allies only the tooltip helpers
    -- (ShowTooltip/OpenMenu stay those of the friends card)
    Mixin(row, FriendsListSocialCardMixin)
    for _, method in ipairs(ALLY_METHODS) do row[method] = RecentAlliesEntryMixin[method] end
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.04)
    row.hover:Hide()
    row.status = row:CreateTexture(nil, "ARTWORK")
    row.status:SetSize(12, 12)
    row.status:SetPoint("TOPLEFT", 10, -9)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("TOPLEFT", 30, -7)
    row.sub = UI.Text(row, 12, "LEFT", UI.MUTED)
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.sub2 = UI.Text(row, 12, "LEFT", { 0.47, 0.46, 0.43 })
    row.sub2:SetPoint("TOPLEFT", row.sub, "BOTTOMLEFT", 0, -2)
    -- right: actions, game icon left of them
    row.action = RowButton(row)
    row.action:SetPoint("RIGHT", -6, 0)
    Mixin(row.action, FriendsListSocialCardPartyButtonMixin)
    row.action.ActionIcon = row.action.icon
    function row.action:SetEnabledState(enabled)
        self:SetEnabled(enabled)
        self:SetAlpha(enabled and 1 or 0.5)
    end
    row.action2 = RowButton(row)
    row.action2:SetPoint("RIGHT", row.action, "LEFT", -4, 0)
    row.game = row:CreateTexture(nil, "ARTWORK")
    row.game:SetSize(20, 20)
    row.game:SetPoint("RIGHT", row.action, "LEFT", -8, 0)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        if self.ShowRowTooltip then self:ShowRowTooltip() end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    rows[i] = row
    return row
end

local function ResetRow(row)
    row.elementData, row.ShowRowTooltip, row.OnRowClick = nil, nil, nil
    row.sub2:SetText("")
    row.game:Hide()
    row.action:Hide()
    row.action2:Hide()
    row.action:SetScript("OnClick", nil)
    row.action:SetScript("OnEnter", nil)
    row.action:HookScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(ns.UI.HOVER)) end)
    row.action2:SetScript("OnClick", nil)
    row.action:SetEnabled(true)
    row.action:SetAlpha(1)
end

-- Row button icon: atlas or own icon (Media/Icons)
local function SetActionIcon(button, atlas, size, color)
    button.icon:SetAtlas(atlas)
    button.icon:SetSize(size or 16, size or 16)
    button.icon:SetVertexColor(unpack(color or { 1, 1, 1 }))
end

local function SetActionMedia(button, name, size, color)
    ns.SetIcon(button.icon, name)
    button.icon:SetTexCoord(0, 1, 0, 1) -- reset tex coords left over from an atlas
    button.icon:SetSize(size, size)
    button.icon:SetVertexColor(unpack(color))
end

-- Friends ---------------------------------------------------------------------------------------

local STATUS_FILTERS = {
    { label = SOCIAL_UI_PRESENCE_TYPE_LABEL_ONLINE, field = "isOnline" },
    { label = SOCIAL_UI_PRESENCE_TYPE_LABEL_AWAY, field = "isAFK" },
    { label = SOCIAL_UI_PRESENCE_TYPE_LABEL_BUSY, field = "isDND" },
    { label = SOCIAL_UI_PRESENCE_TYPE_LABEL_OFFLINE, field = "isOffline" },
}

-- Own search and filter (C_BattleNet.SearchFriends is protected): text matches account name,
-- BattleTag, character name and note; status and tags each match any of the selected options
local function MatchesFilters(info)
    local query = strtrim(searchBox:GetText() or ""):lower()
    if query ~= "" then
        local game = info.gameAccountInfo
        local haystack = table.concat({ info.accountName or "", info.battleTag or "", game.characterName or "",
            info.note or "" }, " "):lower()
        if not haystack:find(query, 1, true) then return false end
    end
    local wantStatus, statusOk, wantTag, tagOk = false, false, false, false
    local presence = SocialUIUtil.GetPresenceTypeForBattleNetAccountInfo(info)
    local P = Enum.SocialUIPresenceType
    for option in pairs(filterChecks) do
        if option.field then
            wantStatus = true
            if (option.field == "isOnline" and presence == P.Online) or (option.field == "isAFK" and presence == P.Away)
                or (option.field == "isDND" and presence == P.Busy) or (option.field == "isOffline" and presence == P.Offline) then
                statusOk = true
            end
        elseif option.tag then
            wantTag = true
            for _, tag in ipairs(info.friendTags or {}) do
                if tag == option.tag then tagOk = true end
            end
        end
    end
    return (not wantStatus or statusOk) and (not wantTag or tagOk)
end

local function PresenceAtlas(accountInfo)
    return SocialUIUtil.GetIconForPresenceType(SocialUIUtil.GetPresenceTypeForBattleNetAccountInfo(accountInfo))
end

local function FriendRow(row, friendIndex, accountInfo)
    local online = accountInfo.gameAccountInfo.isOnline
    row.elementData = { friendIndex = friendIndex, accountInfo = accountInfo }
    row.status:SetAtlas(PresenceAtlas(accountInfo))
    row.strip:SetColorTexture(BNET_BLUE[1], BNET_BLUE[2], BNET_BLUE[3], online and 1 or 0)
    row.name:SetText(FriendsListUtil.BuildFriendNameDisplayText(accountInfo))
    row.name:SetTextColor(unpack(online and BNET_BLUE or { 0.6, 0.6, 0.6 }))
    -- second line: character - level - location, else "last online ..."
    local parts = {}
    if online then
        local character = FriendsListUtil.BuildCharacterNameDisplayText(accountInfo)
        local level = FriendsListUtil.BuildCharacterLevelDisplayText(accountInfo)
        if character and character ~= "" then parts[#parts + 1] = character end
        if level and level ~= "" then parts[#parts + 1] = level end
        local location = FriendsListUtil.BuildLocationDisplayText(accountInfo)
        if location and location ~= "" then parts[#parts + 1] = location end
    else
        parts[1] = FriendsListUtil.GetLastOnlineText(accountInfo) or ""
    end
    row.sub:SetText(table.concat(parts, "  ·  "))
    row:SetAlpha(online and 1 or 0.75)
    -- Blizzard's game icon (WoW, App, ...)
    local game = accountInfo.gameAccountInfo
    if online and game.clientProgram and game.clientProgram ~= "" then
        C_Texture.SetTitleIconTexture(row.game, game.clientProgram, Enum.TitleIconVersion.Small, game.subIcon)
        row.game:SetAlpha(FriendsListUtil.IsPlayingDifferentWoWProject(game) and 0.6 or 1)
        row.game:Show()
    end
    -- Invite (Blizzard's logic: restrictions, multiple game accounts, request instead of invite)
    local action = row.action
    action:Initialize(row.elementData)
    action.icon:SetSize(18, 18)
    action:SetScript("OnClick", function(self) self:TryInviteFriend() end)
    action:HookScript("OnEnter", function(self) self:TryShowTooltip() end)
    action:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(ns.UI.FIELD))
        GameTooltip:Hide()
    end)
    action:Show()
    row.ShowRowTooltip = function(self) self:ShowTooltip() end
    row.OnRowClick = function(self, button)
        if button == "RightButton" then self:OpenMenu() end
    end
    return 44
end

local function BuildFriends(add)
    local favorites, others = {}, {}
    local favOnline, otherOnline = 0, 0
    local found = 0
    for index = 1, BNGetNumFriends() or 0 do
        local info = C_BattleNet.GetFriendAccountInfo(index)
        if info and MatchesFilters(info) then
            found = found + 1
            local online = info.gameAccountInfo.isOnline
            if info.isFavorite then
                favorites[#favorites + 1] = { index, info }
                if online then favOnline = favOnline + 1 end
            else
                others[#others + 1] = { index, info }
                if online then otherOnline = otherOnline + 1 end
            end
        end
    end
    local function Group(key, title, entries, online)
        if #entries == 0 then return end
        add.header(key, title, online .. "/" .. #entries)
        if collapsed[key] then return end
        table.sort(entries, function(a, b) return a[1] < b[1] end)
        for _, entry in ipairs(entries) do add.row(FriendRow, entry[1], entry[2]) end
    end
    Group("favorites", L["Favorites"], favorites, favOnline)
    Group("friends", SOCIAL_UI_FRIENDS_TAB_NAME, others, otherOnline)
    local total, numOnline = BNGetNumFriends()
    return L["%d of %d online"]:format(numOnline or 0, total or 0), found == 0 and L["No friends found."] or nil
end

-- Recent allies ---------------------------------------------------------------------------------

local function AllyRow(row, ally)
    local character, state = ally.characterData, ally.stateData
    row.elementData = ally
    local online = state.isOnline
    row.status:SetTexture(not online and "Interface\\FriendsFrame\\StatusIcon-Offline"
        or state.isAFK and "Interface\\FriendsFrame\\StatusIcon-Away"
        or state.isDND and "Interface\\FriendsFrame\\StatusIcon-DnD" or "Interface\\FriendsFrame\\StatusIcon-Online")
    local classInfo = C_CreatureInfo.GetClassInfo(character.classID)
    local color = online and classInfo and GetClassColorObj(classInfo.classFile)
    row.strip:SetColorTexture(1, 1, 1, 0)
    row.name:SetText(RecentAlliesUtil.GetBestDisplayNameForCharacter(character)
        .. "|cff99978f  " .. L["Level %d"]:format(character.level or 0)
        .. (classInfo and ("  ·  " .. classInfo.className) or "") .. "|r")
    if color then row.name:SetTextColor(color:GetRGB()) else row.name:SetTextColor(0.6, 0.6, 0.6) end
    local interaction = ally.interactionData and ally.interactionData.interactions and ally.interactionData.interactions[1]
    row.sub:SetText(interaction and interaction.description or "")
    row.sub2:SetText(online and (state.currentLocation or "") or (FRIENDS_LIST_OFFLINE or L["Offline"]))
    row:SetAlpha(online and 1 or 0.7)
    -- invite
    local action = row.action
    SetActionIcon(action, online and "friends-icon-friendsAvailable" or "friends-icon-friendsAvailable-dis", 18)
    action:SetEnabled(online)
    action:SetAlpha(online and 1 or 0.5)
    action:SetScript("OnClick", function()
        if character.fullName then C_PartyInfo.InviteUnit(character.fullName) end
    end)
    action:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip_AddHighlightLine(GameTooltip, RECENT_ALLIES_PARTY_BUTTON_TOOLTIP)
        if not online then GameTooltip_AddErrorLine(GameTooltip, RECENT_ALLIES_PARTY_BUTTON_OFFLINE_TOOLTIP) end
        GameTooltip:Show()
    end)
    action:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(ns.UI.FIELD))
        GameTooltip:Hide()
    end)
    action:Show()
    row.ShowRowTooltip = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        RecentAlliesEntryMixin.BuildRecentAllyTooltip(self, GameTooltip)
        GameTooltip:Show()
    end
    row.OnRowClick = function(self, button)
        if button == "RightButton" then RecentAlliesEntryMixin.OpenMenu(self) end
    end
    return (row.sub2:GetText() or "") ~= "" and 58 or 44
end

local function BuildAllies(add)
    -- TryRequestRecentAlliesData is protected; wait for RECENT_ALLIES_CACHE_UPDATE instead
    if not C_RecentAllies.IsRecentAllyDataReady() then return "", L["Loading …"] end
    local allies = C_RecentAllies.GetRecentAllies() or {}
    local query = strtrim(searchBox:GetText() or ""):lower()
    local shown, online = {}, 0
    for _, ally in ipairs(allies) do
        local name = ally.characterData and ally.characterData.fullName or ""
        if query == "" or name:lower():find(query, 1, true) then
            shown[#shown + 1] = ally
            if ally.stateData.isOnline then online = online + 1 end
        end
    end
    add.header("allies", SOCIAL_UI_RECENT_ALLIES_TAB_NAME, online .. "/" .. #shown)
    if not collapsed.allies then
        for _, ally in ipairs(shown) do add.row(AllyRow, ally) end
    end
    return L["%d of %d online"]:format(online, #shown), #shown == 0 and L["No recent allies yet."] or nil
end

-- Requests --------------------------------------------------------------------------------------

local function RequestRow(row, index, invite)
    row.elementData = invite
    row.status:SetAtlas("friends-status-online")
    row.strip:SetColorTexture(BNET_BLUE[1], BNET_BLUE[2], BNET_BLUE[3], 1)
    row.name:SetText(invite.accountName or "")
    row.name:SetTextColor(unpack(BNET_BLUE))
    local age = invite.creationTimestamp and (GetServerTime() - invite.creationTimestamp)
    row.sub:SetText(age and age > 0 and L["%s ago"]:format(SecondsToTime(age, false, true, 1)) or "")
    row:SetAlpha(1)
    -- Decline (menu as in Blizzard's UI: decline, report, block invites)
    local decline = row.action
    SetActionMedia(decline, "Close", 14, { 0.9, 0.31, 0.31 })
    decline:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(_, root)
            root:CreateButton(DECLINE, function() BNDeclineFriendInvite(invite.inviteID) end)
            root:CreateButton(REPORT_PLAYER, function()
                local location = PlayerLocation:CreateFromBattleNetID(invite.inviteID)
                local report = ReportInfo:CreateReportInfoFromType(Enum.ReportType.Friend)
                ReportFrame:InitiateReport(report, invite.accountName, location, true)
            end)
            if FriendsListUtil.CanAddFriendRequestSenderToBattleNetBlockList(index) then
                root:CreateButton(BLOCK_INVITES, function()
                    StaticPopup_Show("CONFIRM_BLOCK_INVITES", invite.accountName, nil, invite.inviteID)
                end)
            end
        end)
    end)
    decline:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(DECLINE)
        GameTooltip:Show()
    end)
    decline:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(ns.UI.FIELD))
        GameTooltip:Hide()
    end)
    decline:Show()
    local accept = row.action2
    SetActionMedia(accept, "Check", 14, GREEN)
    accept:SetScript("OnClick", function() BNAcceptFriendInvite(invite.inviteID) end)
    accept:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(unpack(ns.UI.HOVER))
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ACCEPT)
        GameTooltip:Show()
    end)
    accept:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(ns.UI.FIELD))
        GameTooltip:Hide()
    end)
    accept:Show()
    return 44
end

local function BuildRequests(add)
    local count = BNGetNumFriendInvites() or 0
    add.header("requests", L["Received"], tostring(count))
    if not collapsed.requests then
        for i = 1, count do
            local invite = C_BattleNet.GetFriendInviteInfo(i)
            if invite then add.row(RequestRow, i, invite) end
        end
    end
    return "", count == 0 and L["No open requests."] or nil
end

-- Raid ----------------------------------------------------------------------------------------

local function BuildRaid()
    local inRaid = IsInRaid()
    if inRaid then
        infoText:SetText(L["You are in a raid with %d players."]:format(GetNumGroupMembers())
            .. "\n\n|cff99978f" .. L["The raid groups view follows in its own design."] .. "|r")
    else
        infoText:SetText(RAID_DESCRIPTION or "")
    end
    infoText:Show()
    return "", nil
end

-- Layout ----------------------------------------------------------------------------------------

local function SelfPresence()
    local P = Enum.SocialUIPresenceType
    if UnitIsAFK("player") then return P.Away end
    if UnitIsDND("player") then return P.Busy end
    return SocialUIUtil.GetPresenceTypeSelf()
end

local function UpdateStatus()
    local presence = SelfPresence()
    statusButton.dot:SetAtlas(SocialUIUtil.GetIconForPresenceType(presence))
    local _, battleTag = BNGetInfo()
    local name, number = (battleTag or ""):match("^(.-)(#%d+)$")
    tagText:SetText("|cff4fb3ff" .. (name or battleTag or "") .. "|r|cff4a6a80" .. (number or "") .. "|r")
end

local function Layout()
    pending = false
    if not (window and window:IsShown()) then return end
    local tab = TABS[current]
    -- tabs on the right
    local slot = 0
    for i, def in ipairs(TABS) do
        local button = tabs[i]
        local available = def.available()
        button:SetShown(available)
        if available then
            slot = slot + 1
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", window, "TOPRIGHT", ns.SideTabX(), -60 - (slot - 1) * TAB_STEP)
            local active = i == current
            button.icon:SetAtlas(active and def.atlas or (def.atlas .. "-inactive"))
            button.icon:SetDesaturated(not active) -- inactive tabs desaturated (as everywhere)
            for _, e in ipairs(button.active) do e:SetShown(active) end
            local count = def.count and def.count() or 0
            button.count:SetText(count > 0 and count or "")
        end
    end
    window:SetNpc("player", tab.name, nil)
    UpdateStatus()
    local searchable = tab.key == "friends" or tab.key == "allies"
    searchBox:SetShown(searchable)
    filterButton:SetShown(tab.key == "friends")
    searchBox:SetPoint("RIGHT", window, "RIGHT", tab.key == "friends" and -(PAD + 34) or -PAD, 0)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -(ns.NPC_HEADER_BOTTOM + (searchable and 86 or 50)))
    list:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD - 8, 52)

    local width = list:GetWidth()
    local y, h, r = 0, 0, 0
    local add = {}
    function add.header(key, title, count)
        h = h + 1
        local header = Header(h)
        header.key = key
        header.text:SetText(title)
        header.count:SetText(count or "")
        ns.SetIcon(header.sign, (collapsed[key] and "Plus" or "Minus"))
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -(y + (y > 0 and 6 or 0)))
        header:SetWidth(width)
        header:Show()
        y = y + 26 + (y > 0 and 6 or 0) + ROW_GAP
    end
    function add.row(fill, ...)
        r = r + 1
        local row = Row(r)
        ResetRow(row)
        row.name:SetWidth(width - 100)
        row.sub:SetWidth(width - 100)
        row.sub2:SetWidth(width - 100)
        local height = fill(row, ...)
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        row:SetScript("OnClick", function(self, button) if self.OnRowClick then self:OnRowClick(button) end end)
        row:Show()
        y = y + height + ROW_GAP
    end

    infoText:Hide()
    local footer, empty
    if tab.key == "friends" then
        footer, empty = BuildFriends(add)
    elseif tab.key == "allies" then
        footer, empty = BuildAllies(add)
    elseif tab.key == "requests" then
        footer, empty = BuildRequests(add)
    else
        footer, empty = BuildRaid()
    end
    for i = h + 1, #headers do headers[i]:Hide() end
    for i = r + 1, #rows do rows[i]:Hide() end
    list.child:SetWidth(width)
    list:SetContentHeight(y)
    emptyText:SetText(empty or "")
    emptyText:SetShown(empty ~= nil)
    footerText:SetText(footer or "")
    SyncSecure()
    window.npcTitle:SetText(footer or "")
    -- footer button: add friend or convert to raid
    if tab.key == "raid" then
        actionButton.Text:SetText(CONVERT_TO_RAID or L["Convert to raid"])
        actionButton:SetShown(not IsInRaid())
        local allowed = C_PartyInfo.AllowedToDoPartyConversion(true)
        actionButton:SetEnabled(allowed)
        actionButton:SetAlpha(allowed and 1 or 0.5)
    else
        actionButton.Text:SetText("+  " .. L["Friend"])
        actionButton:SetEnabled(true)
        actionButton:SetAlpha(1)
        actionButton:Show()
    end
end

SyncSecure = function()
    if not secure or InCombatLockdown() then return end
    local wanted = window and window:IsShown() or false
    if wanted and not secure.driven then
        RegisterStateDriver(secure, "visibility", "[combat] hide; show")
        secure.driven = true
    elseif not wanted and secure.driven then
        UnregisterStateDriver(secure, "visibility")
        secure.driven = nil
    end
    secure:SetShown(wanted)
    -- place secure buttons over their visible counterparts, anchored only to the layer
    ns.MirrorRect(secure, window)
    ns.MirrorRect(statusSecure, statusButton, secure)
    ns.MirrorRect(convertSecure, actionButton, secure)
    local raidTab = TABS[current].key == "raid"
    convertSecure:SetShown(raidTab and not IsInRaid() and C_PartyInfo.AllowedToDoPartyConversion(true))
end

local function Refresh()
    if pending or not window then return end
    pending = true
    C_Timer.After(0, Layout)
end

local function SelectTab(index)
    if not index or not TABS[index] then return end
    current = index
    if searchBox then searchBox:SetText("") end
    Refresh()
end

-- Filter menu: status and tags (checkboxes), like the map filter menu
local function CreateFilterMenu()
    local UI = ns.UI
    filterMenu = CreateFrame("Frame", nil, window)
    filterMenu:SetPoint("TOPRIGHT", filterButton, "BOTTOMRIGHT", 0, -4)
    filterMenu:SetFrameStrata("DIALOG")
    UI.Box(filterMenu, { 0.078, 0.078, 0.086, 1 })
    filterMenu:Hide()
    local entries = { { title = SOCIAL_FILTER_DROPDOWN_STATUS } }
    for _, option in ipairs(STATUS_FILTERS) do entries[#entries + 1] = option end
    local function AddTags(title, tags)
        if not tags or #tags == 0 then return end
        entries[#entries + 1] = { title = title }
        for _, tag in ipairs(tags) do
            entries[#entries + 1] = { label = SocialUIUtil.GetLabelForBattleNetFriendTag(tag), tag = tag }
        end
    end
    if C_BattleNet.AreFriendTagsEnabled and C_BattleNet.AreFriendTagsEnabled() then
        AddTags(SOCIAL_UI_BATTLE_NET_FRIEND_TAG_LABEL_INTERESTS, SocialUIUtil.GetSupportedBattleNetFriendTagInterestsForCurrentGameType())
        AddTags(SOCIAL_UI_BATTLE_NET_FRIEND_TAG_ROLES_LABEL, SocialUIUtil.GetSupportedBattleNetFriendTagRolesForCurrentGameType())
    end
    local y, widest = 6, 0
    for _, entry in ipairs(entries) do
        if entry.title then
            local title = UI.Heading(filterMenu, 12, "LEFT")
            title:SetPoint("TOPLEFT", 12, -(y + 6))
            title:SetText(entry.title)
            widest = math.max(widest, title:GetUnboundedStringWidth())
            y = y + 24
        else
            local row = CreateFrame("Button", nil, filterMenu)
            row:SetHeight(24)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", filterMenu, "RIGHT")
            local hover = row:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(1, 1, 1, 0.06)
            local box = CreateFrame("Frame", nil, row)
            box:SetSize(14, 14)
            box:SetPoint("LEFT", 12, 0)
            UI.CheckBg(box)
            local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
            tick:SetPoint("CENTER")
            tick:Hide()
            local text = UI.Text(row, 13, "LEFT")
            text:SetPoint("LEFT", box, "RIGHT", 10, 0)
            text:SetText(entry.label or "")
            widest = math.max(widest, text:GetUnboundedStringWidth() + 24)
            row:SetScript("OnClick", function()
                filterChecks[entry] = not filterChecks[entry] or nil
                tick:SetShown(filterChecks[entry] == true)
                filterButton.icon:SetVertexColor(unpack(next(filterChecks) and UI.ACCENT or UI.TEXT))
                Refresh()
            end)
            y = y + 24
        end
    end
    filterMenu:SetSize(math.ceil(widest) + 36, y + 6)
    filterMenu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    filterMenu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not filterButton:IsMouseOver() then self:Hide() end
    end)
end

-- Ignore list: players (ignored) and Battle.net (blocked invites), with remove
local function OpenIgnoreList(owner)
    local UI = ns.UI
    local items = {}
    for i = 1, C_FriendList.GetNumIgnores() or 0 do
        local name = C_FriendList.GetIgnoreName(i)
        local index = i
        items[#items + 1] = { value = "i" .. i, label = name or UNKNOWN, inert = true, actions = {
            { icon = "Close", tooltip = REMOVE or L["Remove"], onClick = function() C_FriendList.DelIgnoreByIndex(index) end },
        } }
    end
    for i = 1, BNGetNumBlocked() or 0 do
        local blockID, blockName = BNGetBlockedInfo(i)
        -- unblocking Battle.net accounts is protected - display only
        items[#items + 1] = { value = "b" .. (blockID or i), label = "|cff4fb3ff" .. (blockName or UNKNOWN) .. "|r", inert = true }
    end
    if #items == 0 then items[1] = { value = "none", label = "|cff99978f" .. L["Nobody ignored."] .. "|r", inert = true } end
    items[#items + 1] = { value = "add", label = "|cff8ecbb4+  " .. (ADD_IGNORE or L["Ignore player"]) .. "|r" }
    UI.OpenList(owner, items, nil, function(value)
        if value == "add" then
            local name = UnitIsPlayer("target") and GetUnitName("target", true)
            if name then C_FriendList.AddIgnore(name) else StaticPopup_Show("ADD_IGNORE") end
        end
    end)
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIFriends", WIDTH, ns.NPC_HEIGHT, "friends")
    window.Refresh = Refresh
    window.extraRight = TAB_STEP -- tabs on the right: neighbor windows keep extra distance

    -- tabs
    for i, def in ipairs(TABS) do
        local button = CreateFrame("Button", nil, window)
        button:SetSize(TAB_SIZE, TAB_SIZE)
        UI.Box(button, ns.STYLE.panelColor)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(26, 26)
        button.icon:SetPoint("CENTER")
        button.active = ns.AddBorder(button, true, 2)
        for _, e in ipairs(button.active) do e:SetVertexColor(unpack(UI.ACCENT)) end
        button.count = ns.CreateText(button, 11, "RIGHT", "OUTLINE")
        button.count:SetPoint("BOTTOMRIGHT", -2, 2)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(def.name or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            SelectTab(i)
        end)
        tabs[i] = button
    end

    -- Battle.net bar: status, BattleTag (copy), ignore list
    local top = -(ns.NPC_HEADER_BOTTOM + 14)
    statusButton = CreateFrame("Button", nil, window)
    statusButton:SetSize(28, 28) -- square like the other icon buttons
    statusButton:SetPoint("TOPLEFT", PAD, top)
    local statusBg = UI.Box(statusButton)
    statusButton.dot = statusButton:CreateTexture(nil, "ARTWORK")
    statusButton.dot:SetSize(14, 14)
    statusButton.dot:SetPoint("CENTER")
    local chevron = UI.Icon(statusButton, "ChevronDown", 10, UI.MUTED)
    chevron:SetPoint("RIGHT", -6, 0)
    chevron:Hide()
    -- C_BattleNet.SetAFK etc. are protected: a secure macro button sits on top -
    -- left-click /afk, right-click /dnd (each toggles)
    statusButton.statusBg = statusBg
    function statusButton.ShowTip(owner)
        statusBg:SetColorTexture(unpack(UI.HOVER))
        GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
        GameTooltip:SetText(SocialUIUtil.GetLabelForPresenceType(SelfPresence()), 1, 1, 1)
        GameTooltip:AddLine(L["Left-click: away on/off"], 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L["Right-click: do not disturb on/off"], 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end
    function statusButton.HideTip()
        statusBg:SetColorTexture(unpack(UI.FIELD))
        GameTooltip:Hide()
    end

    local ignoreButton = UI.IconButton(window, "Phase", function(self) OpenIgnoreList(self) end, 28)
    ignoreButton:SetPoint("TOPRIGHT", -PAD, top)
    ignoreButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(IGNORE_LIST or L["Ignore list"], 1, 1, 1)
        GameTooltip:Show()
    end)
    ignoreButton:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local tagBox = CreateFrame("Frame", nil, window)
    tagBox:SetHeight(28)
    tagBox:SetPoint("LEFT", statusButton, "RIGHT", 6, 0)
    tagBox:SetPoint("RIGHT", ignoreButton, "LEFT", -6, 0)
    UI.Box(tagBox, { 0.07, 0.07, 0.08, 1 })
    tagText = UI.Text(tagBox, 13, "CENTER")
    tagText:SetPoint("CENTER", -10, 0)
    local copy = UI.IconButton(tagBox, "Copy", function()
        local _, battleTag = BNGetInfo()
        if battleTag then
            CopyToClipboard(battleTag)
            ns.Print(L["BattleTag copied."])
        end
    end, 22)
    copy:SetPoint("RIGHT", -3, 0)
    copy:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Copy BattleTag"], 1, 1, 1)
        GameTooltip:Show()
    end)
    copy:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- search + filter
    searchBox = UI.EditBox(window, 28)
    searchBox:SetPoint("TOPLEFT", statusButton, "BOTTOMLEFT", 0, -8)
    searchHint = UI.Text(searchBox, 13, "LEFT", UI.MUTED)
    searchHint:SetPoint("LEFT", 10, 0)
    searchHint:SetText(SEARCH or L["Search"])
    searchBox:HookScript("OnTextChanged", function(self)
        searchHint:SetShown(self:GetText() == "")
        Refresh()
    end)
    filterButton = UI.IconButton(window, "Filter", function()
        if not filterMenu then CreateFilterMenu() end
        filterMenu:SetShown(not filterMenu:IsShown())
        GameTooltip:Hide()
    end, 28)
    filterButton.icon:SetSize(14, 14)
    filterButton:SetPoint("TOPRIGHT", -PAD, top - 36)
    filterButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(FILTER or L["Filter"], 1, 1, 1)
        GameTooltip:Show()
    end)
    filterButton:HookScript("OnLeave", function()
        GameTooltip:Hide()
        filterButton.icon:SetVertexColor(unpack(next(filterChecks) and UI.ACCENT or UI.TEXT))
    end)

    list = UI.ScrollArea(window)
    emptyText = UI.Text(window, 13, "CENTER", UI.MUTED)
    emptyText:SetPoint("TOP", list, "TOP", 0, -60)
    infoText = UI.Text(window, 13, "LEFT")
    infoText:SetPoint("TOPLEFT", PAD, -(ns.NPC_HEADER_BOTTOM + 60))
    infoText:SetPoint("RIGHT", -PAD, 0)
    infoText:SetWordWrap(true)
    infoText:SetSpacing(3)
    infoText:Hide()

    footerText = UI.Text(window, 12, "LEFT", UI.MUTED)
    footerText:SetPoint("BOTTOMLEFT", PAD, 20)
    actionButton = UI.Button(window, "", function()
        if TABS[current].key ~= "raid" then AddFriendFrame_Show() end -- raid: secure button on top handles it
    end, 150)
    actionButton:SetHeight(28)
    actionButton:SetPoint("BOTTOMRIGHT", -PAD, 14)

    -- secure buttons: own layer above the window (shown only while open and out of combat)
    secure = CreateFrame("Frame", "MeredanUIFriendsSecure", UIParent, "SecureHandlerStateTemplate")
    secure:SetFrameStrata("DIALOG")
    ns.FollowFrame(secure, window) -- not SetAllPoints: would make the window protected too (Core.lua)
    secure:Hide()
    statusSecure = CreateFrame("Button", nil, secure, "SecureActionButtonTemplate")
    statusSecure:RegisterForClicks("AnyUp", "AnyDown") -- addon secure buttons fire on key down
    statusSecure:SetAttribute("type1", "macro")
    statusSecure:SetAttribute("macrotext1", "/afk")
    statusSecure:SetAttribute("type2", "macro")
    statusSecure:SetAttribute("macrotext2", "/dnd")
    statusSecure:SetScript("OnEnter", function(self) statusButton.ShowTip(self) end)
    statusSecure:SetScript("OnLeave", function() statusButton.HideTip() end)
    statusSecure:HookScript("OnClick", function() C_Timer.After(0.3, Refresh) end)
    -- convert to raid: click Blizzard's own (hidden) button
    convertSecure = CreateFrame("Button", nil, secure, "SecureActionButtonTemplate")
    convertSecure:RegisterForClicks("AnyUp", "AnyDown")
    convertSecure:SetAttribute("type", "click")
    local raidView = SocialUIFrame and SocialUIFrame.RaidFrame
    convertSecure:SetAttribute("clickbutton", raidView and raidView.ConvertToRaidButton or RaidFrameConvertToRaidButton)
    convertSecure:Hide()

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        -- tab unavailable (e.g. system disabled): fall back to the first available one
        if not TABS[current].available() then
            for i, def in ipairs(TABS) do
                if def.available() then current = i break end
            end
        end
        Layout()
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        if filterMenu then filterMenu:Hide() end
        ns.UI.CloseList()
        SyncSecure()
    end)
end

-- tabKey nil = toggle; with a tab: switch to it, or close if it is already shown
local function Toggle(tabKey)
    if not window then CreateWindow() end
    local index = tabKey and TabIndex(tabKey)
    if window:IsShown() and (not index or index == current) then
        window:Hide()
        return
    end
    if index then SelectTab(index) end
    window:Show()
end

local function Open(tabKey)
    if not window then CreateWindow() end
    local index = tabKey and TabIndex(tabKey)
    if index then SelectTab(index) end
    window:Show()
end
ns.ToggleFriends = Toggle

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    ns.OpenFriends = Open

    -- key bindings: O (social), friends tab, raid tab
    local buttons = {}
    local function Button(name, tabKey)
        local button = CreateFrame("Button", name, UIParent)
        button:SetScript("OnClick", function() Toggle(tabKey) end)
        buttons[#buttons + 1] = button
        return button
    end
    local bindings = {
        { "TOGGLESOCIAL", Button("MeredanUIFriendsToggle") },
        { "TOGGLEFRIENDSTAB", Button("MeredanUIFriendsTabToggle", "friends") },
        { "TOGGLERAIDTAB", Button("MeredanUIRaidTabToggle", "raid") },
    }
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        for _, button in ipairs(buttons) do ClearOverrideBindings(button) end
        for _, entry in ipairs(bindings) do
            for _, key in ipairs({ GetBindingKey(entry[1]) }) do
                SetOverrideBindingClick(entry[2], false, key, entry[2]:GetName(), "LeftButton")
            end
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)

    -- redirect Blizzard's openers (chat friends button, notices, menus) to this window
    local FRIEND_TAB = { [FRIEND_TAB_FRIENDS or 1] = "friends", [FRIEND_TAB_RAID or 2] = "raid" }
    local SOCIAL_TAB = {}
    for _, def in ipairs(TABS) do
        if def.social then SOCIAL_TAB[def.social] = def.key end
    end
    ToggleFriendsFrame = function(tab) Toggle(tab and FRIEND_TAB[tab] or nil) end
    ToggleSocialUI = function() Toggle() end
    if SocialUIControl then
        SocialUIControl.Toggle = function() Toggle() end
        SocialUIControl.ToggleToTab = function(tabType) Toggle(SOCIAL_TAB[tabType] or "friends") end
        SocialUIControl.OpenToTab = function(tabType) Open(SOCIAL_TAB[tabType] or "friends") end
        SocialUIControl.ToggleToTabAndSideWindow = function(tabType) Toggle(SOCIAL_TAB[tabType] or "friends") end
        SocialUIControl.Hide = function() if window then window:Hide() end end
    end

    for _, event in ipairs({ "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_INFO_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED",
        "BN_INFO_CHANGED", "PLAYER_FLAGS_CHANGED", "BN_FRIEND_INVITE_ADDED", "BN_FRIEND_INVITE_REMOVED",
        "BN_FRIEND_INVITE_LIST_INITIALIZED", "RECENT_ALLIES_CACHE_UPDATE", "RECENT_ALLIES_SYSTEM_STATUS_UPDATED",
        "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "IGNORELIST_UPDATE", "BN_BLOCK_LIST_UPDATED",
        "BATTLE_NET_FRIEND_TAG_ENABLED_STATUS_UPDATED" }) do
        ns:On(event, function() if window:IsShown() then Refresh() end end)
    end
    ns:On("PLAYER_REGEN_ENABLED", function() C_Timer.After(0, SyncSecure) end)
end)
