-- Gilde & Communitys (WoW Forever) statt Blizzards CommunitiesFrame – gleiche Fenster-Familie wie
-- Freunde (Kopfzeile, Tabs rechts). Aufbau 1:1 nach Bennys Screenshots, Entwurf „Gilde“ (2026-11-07):
--
--   [Wappen] Erben des Verfalls                                  [↙][x]
--            Gilde & Communitys · 3 von 19 online
--   ┌Community-Liste┐ ┌ Chat | Mitglieder | Info | Spieleinstellungen ┐  [Tabs]
--   │ Gilde         │ │ …                                            │
--   │ + beitreten   │ │                                              │
--   Fuß: Zähler links, Knopf rechts (Mitglied einladen / Gildeneinstellungen / Log ansehen)
--
-- Daten und Aktionen kommen von Blizzard (C_Club, C_GuildInfo, Blizzards Dialoge und Menüs) –
-- nur Aufbau und Optik sind unsere. Die Gildeneinstellungen stehen in GuildControl.lua.
local _, ns = ...
local L = ns.L

local WIDTH = 940
local COMPACT_WIDTH = 480
local PAD = ns.NPC_PAD
local LIST_W = 190
local CONTENT_X = PAD + LIST_W + 12
local TOP = ns.NPC_HEADER_BOTTOM + 14
local BOTTOM = 54
local TAB_SIZE, TAB_STEP = 40, 46
local ROW_H = 26
local MEMBER_W = 180
local MAX_CHAT_LINES = 500
local P = ns.Plain

local GREY = { 0.5, 0.5, 0.5 }

local window, emblem, emblemBg, minimizeButton
local clubRows, joinRow = {}, nil
local tabs, views = {}, {}
local currentTab = "chat"
local selectedClubId
local selectedStreams = {} -- clubId → streamId
local focused = {}         -- { clubId, streamId }
local compact = false
local pending = false
local footerText, footerButton

-- Hilfen ----------------------------------------------------------------------------------------

local function G(name, fallback)
    local value = _G[name]
    if type(value) == "string" and value ~= "" then return value end
    return L[fallback or name]
end

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.guildWindow ~= false and C_Club ~= nil and CommunitiesUtil ~= nil
end

local function LoadBlizzard()
    if not (C_AddOns.IsAddOnLoaded("Blizzard_Communities")) then C_AddOns.LoadAddOn("Blizzard_Communities") end
end

local function IsOnline(info)
    local presence = P(info.presence)
    local E = Enum.ClubMemberPresence
    return presence == E.Online or presence == E.Away or presence == E.Busy
end

local function ClassFile(info)
    local classID = P(info.classID)
    local classInfo = classID and C_CreatureInfo.GetClassInfo(classID)
    return classInfo and classInfo.classFile, classInfo and classInfo.className
end

local function ClassColor(info)
    local file = ClassFile(info)
    local color = file and RAID_CLASS_COLORS[file]
    if color then return { color.r, color.g, color.b } end
    return { BATTLENET_FONT_COLOR:GetRGB() }
end

local function LastOnlineText(info)
    local y, m, d, h = P(info.lastOnlineYear), P(info.lastOnlineMonth), P(info.lastOnlineDay), P(info.lastOnlineHour)
    if y and m and d and h then return TimeUtil.GetRecentTimeDate(y, m, d, h) end
    return ""
end

local function ClubInfo() return selectedClubId and C_Club.GetClubInfo(selectedClubId) end

local function IsGuildClub()
    local info = ClubInfo()
    return info ~= nil and info.clubType == Enum.ClubType.Guild
end

-- alle Mitglieder eines Clubs (Werte können Secrets sein – nur über P() lesen)
local function Members(clubId)
    local list = {}
    if not clubId then return list end
    for _, memberId in ipairs(C_Club.GetClubMembers(clubId) or {}) do
        local info = C_Club.GetMemberInfo(clubId, memberId)
        if info then list[#list + 1] = info end
    end
    return list
end

local function CountOnline(list)
    local online = 0
    for _, info in ipairs(list) do
        if IsOnline(info) then online = online + 1 end
    end
    return online
end

-- Rang-Symbol wie Blizzard: Krone für Leiter, Assistent für Moderatoren
-- Rang-Symbol: unsere Kronen wie in den Gruppenframes (Leiter gefüllt, Moderator Umriss)
local function RankIconTexture(info)
    local role = P(info.role)
    local R = Enum.ClubRoleIdentifier
    if role == R.Owner or role == R.Leader then return ns.MEDIA .. "Icons\\Leader", ns.STYLE.leaderColor end
    if role == R.Moderator then return ns.MEDIA .. "Icons\\Assistant", ns.STYLE.assistantColor end
end

-- Blizzards Rechtsklick-Menü für Mitglieder
local POPUP = {}
local function OpenMemberMenu(info)
    local clubInfo = ClubInfo()
    local name = P(info.name)
    if not (clubInfo and name) then return end
    if not next(POPUP) then
        POPUP[Enum.ClubType.BattleNet] = "COMMUNITIES_MEMBER"
        POPUP[Enum.ClubType.Character] = "COMMUNITIES_WOW_MEMBER"
        POPUP[Enum.ClubType.Guild] = "COMMUNITIES_GUILD_MEMBER"
    end
    UnitPopup_OpenMenu(POPUP[clubInfo.clubType], {
        name = name,
        clubMemberInfo = info,
        clubInfo = clubInfo,
        clubPrivileges = C_Club.GetClubPrivileges(clubInfo.clubId),
        clubAssignableRoles = C_Club.GetAssignableRoles(clubInfo.clubId, info.memberId),
        isSelf = info.isSelf,
        guid = P(info.guid),
        isMobile = P(info.presence) == Enum.ClubMemberPresence.OnlineMobile,
        isGuildMember = clubInfo.clubType == Enum.ClubType.Guild,
    })
end

-- Bausteine -------------------------------------------------------------------------------------

-- Auswahlfeld: Text links, Pfeil rechts; onClick baut die Liste
local function Dropdown(parent, width, onClick)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 28)
    local bg = UI.Box(button)
    button.Text = UI.Text(button, 13, "LEFT")
    button.Text:SetPoint("LEFT", 10, 0)
    button.Text:SetPoint("RIGHT", -24, 0)
    button.Text:SetWordWrap(false)
    local arrow = UI.Icon(button, "ChevronDown", 10, UI.MUTED)
    arrow:SetPoint("RIGHT", -8, 0)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() then bg:SetColorTexture(unpack(UI.HOVER)) end
    end)
    button:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    button:SetScript("OnClick", onClick)
    hooksecurefunc(button, "SetEnabled", function(self, on)
        self.Text:SetAlpha(on and 1 or 0.5)
        arrow:SetAlpha(on and 1 or 0.4)
    end)
    return button
end
ns.GuildDropdown = Dropdown

-- Häkchen mit Text
local function Check(parent, label, onClick)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(20)
    local box = CreateFrame("Frame", nil, button)
    box:SetSize(14, 14)
    box:SetPoint("LEFT")
    UI.CheckBg(box)
    local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
    tick:SetPoint("CENTER")
    button.Text = UI.Text(button, 13, "LEFT")
    button.Text:SetPoint("LEFT", box, "RIGHT", 8, 0)
    button.Text:SetText(label or "")
    button:SetWidth(22 + button.Text:GetUnboundedStringWidth())
    function button:SetChecked(on)
        self.checked = on and true or false
        tick:SetShown(self.checked)
    end
    function button:GetChecked() return self.checked end
    button:SetMotionScriptsWhileDisabled(true)
    hooksecurefunc(button, "SetEnabled", function(self, on)
        self:SetAlpha(on and 1 or 0.45)
    end)
    button:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if onClick then onClick(self, self.checked) end
    end)
    button:SetChecked(false)
    return button
end
ns.GuildCheck = Check

-- Überschrift einer Fläche (Surf Green) mit optionalem Symbolknopf rechts
local function SectionTitle(parent, text)
    local title = ns.UI.Text(parent, 13, "LEFT", ns.UI.ACCENT)
    title:SetText(text)
    return title
end

-- Fläche mit dunklem Grund und 1-px-Rahmen
local function Panel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    ns.UI.Box(panel, { 0.098, 0.098, 0.106, 1 })
    return panel
end

local function Tooltip(owner, text, anchor)
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(type(text) == "function" and text() or text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Mehrzeiliger Text-Editor (Nachricht des Tages, Gildeninformation, Kanal anlegen)
local editor
-- Grenzen wie Blizzard: Nachricht des Tages 255 Zeichen (Enter übernimmt), Gildeninfo 499
local function OpenTextEditor(title, text, maxLetters, onAccept, enterAccepts)
    local UI = ns.UI
    if not editor then
        editor = CreateFrame("Frame", "MeredanUIGuildTextEdit", UIParent)
        editor:SetSize(420, 260)
        editor:SetPoint("CENTER", 0, 80)
        editor:SetFrameStrata("DIALOG")
        editor:SetToplevel(true)
        editor:EnableMouse(true)
        UI.Box(editor, ns.STYLE.panelColor)
        local accent = editor:CreateTexture(nil, "OVERLAY")
        accent:SetColorTexture(unpack(UI.ACCENT))
        accent:SetPoint("TOPLEFT")
        accent:SetPoint("TOPRIGHT")
        accent:SetHeight(2 * ns.PixelSize())
        tinsert(UISpecialFrames, "MeredanUIGuildTextEdit")
        editor.title = UI.Text(editor, 15, "LEFT")
        editor.title:SetPoint("TOPLEFT", 16, -16)
        local close = UI.IconButton(editor, "Close", function() editor:Hide() end, 22)
        close:SetPoint("TOPRIGHT", -14, -14)
        local box = Panel(editor)
        box:SetPoint("TOPLEFT", 16, -48)
        box:SetPoint("BOTTOMRIGHT", -16, 52)
        local scroll = CreateFrame("ScrollFrame", nil, box, "ScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -24, 8)
        if scroll.ScrollBar then scroll.ScrollBar:SetAlpha(0.6) end
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFont(ns.STYLE.font, ns.FontPx(13), "")
        edit:SetTextColor(unpack(UI.TEXT))
        edit:SetWidth(340)
        edit:SetScript("OnEscapePressed", function() editor:Hide() end)
        scroll:SetScrollChild(edit)
        box:EnableMouse(true)
        box:SetScript("OnMouseDown", function() edit:SetFocus() end)
        editor.edit = edit
        editor.count = UI.Text(editor, 12, "LEFT", UI.MUTED)
        editor.count:SetPoint("BOTTOMLEFT", 16, 22)
        edit:SetScript("OnTextChanged", function(self)
            local max = self:GetMaxLetters()
            editor.count:SetText(max > 0 and (strlenutf8(self:GetText()) .. " / " .. max) or "")
        end)
        local accept = UI.Button(editor, ACCEPT or L["Accept"], function()
            if editor.onAccept then editor.onAccept(edit:GetText()) end
            editor:Hide()
        end, 110)
        accept:SetHeight(28)
        accept:SetPoint("BOTTOMRIGHT", -16, 14)
        local cancel = UI.Button(editor, CANCEL or L["Cancel"], function() editor:Hide() end, 110)
        cancel:SetHeight(28)
        cancel:SetPoint("RIGHT", accept, "LEFT", -6, 0)
    end
    editor.title:SetText(title)
    editor.edit:SetMaxLetters(maxLetters or 0)
    editor.edit:SetText(text or "")
    editor.onAccept = onAccept
    editor.edit:SetScript("OnEnterPressed", enterAccepts and function()
        if editor.onAccept then editor.onAccept(editor.edit:GetText()) end
        editor:Hide()
    end or nil)
    editor:Show()
    editor.edit:SetFocus()
    editor.edit:SetCursorPosition(#(text or ""))
end
ns.GuildTextEditor = OpenTextEditor

-- Community-Liste -------------------------------------------------------------------------------

local function SortedClubs()
    local clubs = C_Club.GetSubscribedClubs() or {}
    local guildId = C_Club.GetGuildClubId()
    table.sort(clubs, function(a, b)
        local ag, bg = a.clubId == guildId, b.clubId == guildId
        if ag ~= bg then return ag end
        if (a.favoriteTimeStamp ~= nil) ~= (b.favoriteTimeStamp ~= nil) then return a.favoriteTimeStamp ~= nil end
        return (a.name or "") < (b.name or "")
    end)
    return clubs
end

local function SetClubIcon(texture, bg, clubInfo)
    if clubInfo.clubType == Enum.ClubType.Guild then
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetSize(texture:GetParent():GetHeight() - 4, texture:GetParent():GetHeight() - 4)
        SetLargeGuildTabardTextures("player", texture, bg)
        bg:Show()
    else
        bg:Hide()
        texture:SetTexCoord(0, 1, 0, 1)
        texture:SetVertexColor(1, 1, 1)
        texture:SetSize(texture:GetParent():GetHeight() - 2, texture:GetParent():GetHeight() - 2)
        pcall(C_Club.SetAvatarTexture, texture, clubInfo.avatarId, clubInfo.clubType)
    end
end

local function ClubRow(i)
    if clubRows[i] then return clubRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, window)
    row:SetSize(LIST_W, 52)
    row.bg = UI.Box(row, { 0.098, 0.098, 0.106, 1 })
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.iconHolder = CreateFrame("Frame", nil, row)
    row.iconHolder:SetSize(32, 32)
    row.iconHolder:SetPoint("LEFT", 10, 0)
    ns.AddBorder(row.iconHolder)
    row.iconBg = row.iconHolder:CreateTexture(nil, "BACKGROUND")
    row.iconBg:SetAllPoints()
    row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("CENTER")
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 10, -2)
    row.name:SetPoint("RIGHT", -8, 0)
    row.name:SetWordWrap(false)
    row.kind = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.kind:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.unread = row:CreateTexture(nil, "OVERLAY")
    row.unread:SetSize(16, 16)
    row.unread:SetPoint("TOPRIGHT", -4, -4)
    row.unread:SetAtlas("communities-icon-notification")
    row:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.114, 0.114, 0.125, 1) end)
    row:SetScript("OnLeave", function(self) self:Refresh() end)
    function row:Refresh()
        local selected = self.clubId == selectedClubId
        self.bg:SetColorTexture(unpack(selected and { 0.122, 0.141, 0.133, 1 } or { 0.098, 0.098, 0.106, 1 }))
        self.strip:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], selected and 1 or 0)
        self.name:SetTextColor(unpack(selected and UI.ACCENT or UI.TEXT))
    end
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Blizzards Menü für den Eintrag (Favorit, Einstellungen, Verlassen …)
            local clubInfo = C_Club.GetClubInfo(self.clubId)
            if clubInfo and CommunitiesListEntryMixin and CommunitiesListEntryMixin.OpenDropdown then
                local fake = { clubInfo = clubInfo }
                Mixin(fake, CommunitiesListEntryMixin)
                pcall(fake.OpenDropdown, fake)
            end
            return
        end
        ns.SelectGuildClub(self.clubId)
    end)
    clubRows[i] = row
    return row
end

local function LayoutClubList()
    local y = TOP
    local clubs = SortedClubs()
    for i, clubInfo in ipairs(clubs) do
        local row = ClubRow(i)
        row.clubId = clubInfo.clubId
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, -y)
        row.name:SetText(clubInfo.name or "")
        local kind = clubInfo.clubType == Enum.ClubType.Guild and (GUILD or L["Guild"])
            or clubInfo.clubType == Enum.ClubType.BattleNet and (COMMUNITIES_INVITATION_FRAME_TYPE or L["Community"])
            or (COMMUNITIES_INVITATION_FRAME_TYPE_CHARACTER or L["Community"])
        row.kind:SetText(kind)
        SetClubIcon(row.icon, row.iconBg, clubInfo)
        row.unread:SetShown(CommunitiesUtil.DoesCommunityHaveUnreadMessages
            and CommunitiesUtil.DoesCommunityHaveUnreadMessages(clubInfo.clubId) or false)
        row:Refresh()
        row:SetShown(not compact)
        y = y + 56
    end
    for i = #clubs + 1, #clubRows do clubRows[i]:Hide() end
    if not joinRow then
        local UI = ns.UI
        joinRow = CreateFrame("Button", nil, window)
        joinRow:SetSize(LIST_W, 52)
        local bg = UI.Box(joinRow, { 0.098, 0.098, 0.106, 1 })
        local holder = CreateFrame("Frame", nil, joinRow)
        holder:SetSize(32, 32)
        holder:SetPoint("LEFT", 10, 0)
        UI.Box(holder, { 0.078, 0.078, 0.086, 1 })
        local plus = UI.Icon(holder, "Plus", 16, UI.ACCENT)
        plus:SetPoint("CENTER")
        local text = UI.Text(joinRow, 12, "LEFT")
        text:SetPoint("LEFT", holder, "RIGHT", 10, 0)
        text:SetPoint("RIGHT", -8, 0)
        text:SetText(COMMUNITIES_JOIN_OR_CREATE_COMMUNITY or L["Join or create a community"])
        joinRow:SetScript("OnEnter", function() bg:SetColorTexture(0.114, 0.114, 0.125, 1) end)
        joinRow:SetScript("OnLeave", function() bg:SetColorTexture(0.098, 0.098, 0.106, 1) end)
        joinRow:SetScript("OnClick", function()
            LoadBlizzard()
            if AddCommunitiesFlow_Toggle then AddCommunitiesFlow_Toggle() end
        end)
    end
    joinRow:ClearAllPoints()
    joinRow:SetPoint("TOPLEFT", PAD, -y)
    joinRow:SetShown(not compact)
    return clubs
end

-- Chat ------------------------------------------------------------------------------------------

local chat = {}

local function SelectedStream()
    return selectedClubId and selectedStreams[selectedClubId]
end

local function SortedStreams(clubId)
    local streams = C_Club.GetStreams(clubId) or {}
    if CommunitiesUtil.SortStreams then CommunitiesUtil.SortStreams(streams) end
    return streams
end

local function StreamName(clubId, stream)
    if stream.streamType == Enum.ClubStreamType.Guild then return COMMUNITIES_STREAM_FORMAT_GUILD or GUILD end
    if stream.streamType == Enum.ClubStreamType.Officer then return COMMUNITIES_STREAM_FORMAT_OFFICER or L["Officer"] end
    return stream.name or ""
end

local function ChatColor()
    local clubId, streamId = selectedClubId, SelectedStream()
    if clubId and streamId and ChatFrameUtil and ChatFrameUtil.GetCommunitiesChannelColor then
        local r, g, b = ChatFrameUtil.GetCommunitiesChannelColor(clubId, streamId)
        if r then return r, g, b end
    end
    return DEFAULT_CHAT_CHANNEL_COLOR:GetRGB()
end

-- Zeile wie Blizzards CommunitiesChatMixin:FormatMessage
local function FormatMessage(clubId, streamId, message)
    local author = message.author
    local name = author.name or " "
    local link
    if author.clubType == Enum.ClubType.BattleNet then
        link = GetBNPlayerCommunityLink(name, name, author.bnetAccountId, clubId, streamId, message.messageId.epoch, message.messageId.position)
    elseif author.discordInfo and author.discordInfo.fromDiscord then
        local playerName = ChatFrameUtil.GetNameForDiscordMessage(author.discordInfo)
        link = GetDiscordUserCommunityLink(playerName, author.bnetAccountId, author.discordInfo.userID, clubId, streamId, message.messageId.epoch, message.messageId.position)
    elseif author.clubType == Enum.ClubType.Character or author.clubType == Enum.ClubType.Guild then
        local classInfo = author.classID and C_CreatureInfo.GetClassInfo(author.classID)
        local color = classInfo and RAID_CLASS_COLORS[classInfo.classFile]
        link = GetPlayerCommunityLink(name, color and WrapTextInColorCode(name, color.colorStr) or name, clubId, streamId, message.messageId.epoch, message.messageId.position)
    end
    local content
    if message.destroyed then
        content = GRAY_FONT_COLOR:WrapTextInColorCode(message.destroyer and message.destroyer.name
            and COMMUNITIES_CHAT_MESSAGE_DESTROYED_BY:format(message.destroyer.name) or COMMUNITIES_CHAT_MESSAGE_DESTROYED)
    elseif message.edited then
        content = COMMUNITIES_CHAT_MESSAGE_EDITED_FMT:format(message.content, GRAY_FONT_COLOR:WrapTextInColorCode(COMMUNITIES_CHAT_MESSAGE_EDITED))
    else
        content = message.content
    end
    local fromDiscord = author.discordInfo and author.discordInfo.fromDiscord
    if fromDiscord and not message.destroyed then content = ChatFrameUtil.FormatDiscordMessage(author.discordInfo, content) end
    local format = ChatFrameUtil.GetTimestampFormat()
    local out = COMMUNITIES_CHAT_MESSAGE_FORMAT:format(link or name, content)
    if format then out = TimeUtil.BetterDate(format, message.messageId.epoch / 1000000) .. out end
    if fromDiscord then out = CreateAtlasMarkup("UI-ChatIcon-Discord") .. " " .. out end
    return out
end

-- Nach dem Neuladen kennt der Client von älteren Nachrichten oft nur Autor und Zeit, der Text
-- („Unbekannt“) kommt erst vom Server nach. Dann einmal nachfordern und neu zeichnen.
local function ContentMissing(message)
    local content = message.content
    if content == nil then return true end
    if ns.issecretvalue(content) then return false end
    local ok, text = pcall(tostring, content)
    return ok and (text == "" or text == UNKNOWN)
end

-- Textspeicher: Blizzard gibt den Nachrichtentext nur beim ersten Abholen lesbar heraus, später
-- (Scrollen, Neuzeichnen, nach /reload) kommt „Unbekannt“ (Benny 2026-11-07). Darum merken wir
-- uns jeden lesbaren Text je Nachricht (kontoweit, über /reload) und lesen zusätzlich den
-- normalen Gilden-/Offizierschat mit, um Lücken nach Autor + Zeit zu füllen.
local CACHE_MAX, LOG_MAX = 800, 400
local fallbackStore = { messages = {}, log = {} }
local function Store()
    if not ns.root then return fallbackStore end -- vor dem Laden der SavedVariables
    -- Version 2: ältere Speicher konnten Platzhalter statt Text enthalten – einmal leeren
    if not ns.root.guildChat or ns.root.guildChat.v ~= 3 then
        ns.root.guildChat = { v = 3, messages = {}, log = {} }
    end
    return ns.root.guildChat
end

local function MessageKey(clubId, streamId, message)
    local id = message.messageId
    return tostring(clubId) .. ":" .. tostring(streamId) .. ":" .. tostring(id.epoch) .. ":" .. tostring(id.position)
end

local function Remember(key, text)
    local store = Store()
    if not store.messages[key] then store.count = (store.count or 0) + 1 end
    store.messages[key] = { text = text, t = time() }
    if store.count > CACHE_MAX then
        -- älteste Hälfte verwerfen
        local list = {}
        for k, v in pairs(store.messages) do list[#list + 1] = { k = k, t = v.t or 0 } end
        table.sort(list, function(x, y) return x.t < y.t end)
        for i = 1, math.floor(#list / 2) do store.messages[list[i].k] = nil end
        store.count = #list - math.floor(#list / 2)
    end
end

local function ShortName(name)
    if not name or ns.issecretvalue(name) then return nil end
    return (name:match("^([^%-]+)") or name):lower()
end

local function FromChatLog(message, streamType)
    local author = ShortName(message.author and message.author.name)
    if not author then return nil end
    local when = message.messageId.epoch / 1000000
    local kind = streamType == Enum.ClubStreamType.Officer and "OFFICER" or "GUILD"
    local best, bestDiff
    for _, entry in ipairs(Store().log) do
        if entry.c == kind and entry.n == author then
            local diff = math.abs((entry.t or 0) - when)
            if diff <= 30 and (not bestDiff or diff < bestDiff) then best, bestDiff = entry.x, diff end
        end
    end
    return best
end

-- Blizzard liefert Chattexte als geschützten Code (|Kw2911|k), den WoW erst beim Anzeigen
-- auflöst – Addons sollen Chattexte nicht lesen. Die Codes laufen ab: gespeichert und später
-- gezeigt ergeben sie „Unbekannt“. Darum nie Codes speichern, immer frisch von Blizzard nehmen
-- (wie Blizzards eigenes Fenster). Nur echter Klartext darf in den Speicher.
local function IsProtected(text)
    return type(text) == "string" and text:find("|K", 1, true) ~= nil
end

local function ResolveContent(clubId, streamId, message)
    if message.destroyed then return end
    local content = message.content
    if content == nil or ns.issecretvalue(content) then return end
    local ok, text = pcall(tostring, content)
    if not ok then return end
    -- geschützter Code: unverändert durchreichen (frisch, also gültig)
    if IsProtected(text) then return end
    local key = MessageKey(clubId, streamId, message)
    if text ~= "" and text ~= UNKNOWN then
        Remember(key, text)
        return
    end
    -- Text fehlt: gemerkten Klartext oder Mitschrift nehmen
    local cached = Store().messages[key]
    local fallback = cached and not IsProtected(cached.text) and cached.text
    if not fallback then
        local stream = C_Club.GetStreamInfo(clubId, streamId)
        fallback = stream and FromChatLog(message, stream.streamType)
        if fallback and IsProtected(fallback) then fallback = nil end
    end
    if fallback then message.content = fallback end
end

-- normalen Gildenchat mitschreiben (Name, Text, Zeit)
local function LogChat(kind, text, sender)
    if not text or ns.issecretvalue(text) or ns.issecretvalue(sender) then return end
    if text:find("|K", 1, true) then return end -- geschützter Code: läuft ab, nicht merken
    local log = Store().log
    log[#log + 1] = { c = kind, n = ShortName(sender), x = text, t = GetServerTime() }
    while #log > LOG_MAX do table.remove(log, 1) end
end
ns:On("CHAT_MSG_GUILD", function(_, text, sender) LogChat("GUILD", text, sender) end)
ns:On("CHAT_MSG_OFFICER", function(_, text, sender) LogChat("OFFICER", text, sender) end)

local function AddMessage(message, backfill)
    local clubId, streamId = selectedClubId, SelectedStream()
    ResolveContent(clubId, streamId, message)
    if ContentMissing(message) and not message.destroyed then chat.missing = true end
    local ok, text = pcall(FormatMessage, clubId, streamId, message)
    if not ok then text = message.content or "" end
    local r, g, b = ChatColor()
    if backfill then
        chat.messages:BackFillMessage(text, r, g, b, clubId, streamId, message.messageId, message.author.memberId)
    else
        chat.messages:AddMessage(text, r, g, b, clubId, streamId, message.messageId, message.author.memberId)
    end
end

local function RangeIsEmpty(range)
    local newest, oldest = range.newestMessageId, range.oldestMessageId
    return newest.epoch < oldest.epoch or (newest.epoch == oldest.epoch and newest.position < oldest.position)
end

local function DisplayChat()
    if not chat.messages then return end
    chat.messages:Clear()
    chat.oldest = nil
    local clubId, streamId = selectedClubId, SelectedStream()
    if not (clubId and streamId) then return end
    local ranges = C_Club.GetMessageRanges(clubId, streamId)
    if not ranges or #ranges == 0 or RangeIsEmpty(ranges[#ranges]) then
        C_Club.RequestMoreMessagesBefore(clubId, streamId, nil)
        chat.requested = true
        return
    end
    local messages = C_Club.GetMessagesBefore(clubId, streamId, ranges[#ranges].newestMessageId, 50) or {}
    for _, message in ipairs(messages) do AddMessage(message) end
    if messages[1] then chat.oldest = messages[1].messageId end
    -- Nachricht des Tages wie bei Blizzard unten anhängen
    local clubInfo = C_Club.GetClubInfo(clubId)
    if clubInfo and clubInfo.broadcast and clubInfo.broadcast ~= "" then
        chat.messages:AddMessage(" ")
        chat.messages:AddMessage(COMMUNITIES_MESSAGE_OF_THE_DAY_FORMAT:format(clubInfo.broadcast), YELLOW_FONT_COLOR:GetRGB())
    end
    C_Club.AdvanceStreamViewMarker(clubId, streamId)
    -- (kein wiederholtes Neuzeichnen mehr: jedes Neuzeichnen holt die geschützten Text-Codes neu,
    -- und wiederverwendete Codes zeigen „Unbekannt“ – Blizzard zeichnet nur beim Öffnen/Kanalwechsel)
end

local function BackfillMessages()
    local clubId, streamId = selectedClubId, SelectedStream()
    if not (clubId and streamId and chat.oldest) then return end
    local messages = C_Club.GetMessagesBefore(clubId, streamId, chat.oldest, 50) or {}
    if #messages == 0 then return end
    local last = #messages
    local newest = messages[last].messageId
    if newest.epoch == chat.oldest.epoch and newest.position == chat.oldest.position then last = last - 1 end
    for index = last, 1, -1 do AddMessage(messages[index], true) end
    chat.oldest = messages[1].messageId
end

local function RequestMoreHistory()
    local clubId, streamId = selectedClubId, SelectedStream()
    if not (clubId and streamId) or chat.requested then return end
    if chat.oldest and C_Club.IsBeginningOfStream(clubId, streamId, chat.oldest) then return end
    if C_Club.RequestMoreMessagesBefore(clubId, streamId, chat.oldest, 50) then
        BackfillMessages()
    else
        chat.requested = true
    end
end

local function SendChat(text)
    local clubId, streamId = selectedClubId, SelectedStream()
    if not (clubId and streamId) then return end
    if C_Club.IsSubscribedToStream(clubId, streamId) then
        local stream = C_Club.GetStreamInfo(clubId, streamId)
        if not stream then return end
        if (stream.streamType == Enum.ClubStreamType.Guild or stream.streamType == Enum.ClubStreamType.Discord)
            and not C_GuildInfo.CanSpeakInGuildChat() then
            chat.messages:AddMessage(ERR_GUILD_PERMISSIONS, YELLOW_FONT_COLOR:GetRGB())
            return
        end
        C_Club.SendMessage(clubId, streamId, text)
    elseif C_Club.IsAccountMuted(clubId) then
        UIErrorsFrame:AddExternalErrorMessage(ERR_PARENTAL_CONTROLS_CHAT_MUTED)
    end
end

local function FocusStream(clubId, streamId)
    if focused.clubId and focused.streamId then C_Club.UnfocusStream(focused.clubId, focused.streamId) end
    focused.clubId, focused.streamId = clubId, streamId
    if clubId and streamId then
        C_Club.FocusStream(clubId, streamId)
        C_Club.SetAutoAdvanceStreamViewMarker(clubId, streamId)
    end
end

local function SelectStream(streamId)
    if not selectedClubId then return end
    selectedStreams[selectedClubId] = streamId
    chat.requested = false
    chat.refetched = false
    chat.retries = 0
    if window and window:IsShown() then FocusStream(selectedClubId, streamId) end
    local stream = streamId and C_Club.GetStreamInfo(selectedClubId, streamId)
    chat.streamButton.Text:SetText(stream and StreamName(selectedClubId, stream) or "")
    if stream and chat.headset and chat.headset.Button and chat.headset.Button.SetCommunityInfo then
        chat.headset.Button:SetCommunityInfo(selectedClubId, stream)
    end
    if streamId and C_Club.IsSubscribedToStream(selectedClubId, streamId) then
        local ranges = C_Club.GetMessageRanges(selectedClubId, streamId)
        if not ranges or #ranges == 0 or RangeIsEmpty(ranges[#ranges]) then
            C_Club.RequestMoreMessagesBefore(selectedClubId, streamId, nil)
        end
    end
    DisplayChat()
end

-- Kanal anlegen wie Blizzards Dialog (Screenshot Benny 2026-11-07): Channelname, Beschreibung
-- (optional), „Nur Moderatoren“, Annehmen (erst mit Namen aktiv) / Abbrechen > C_Club.CreateStream
local channelDialog
local function CreateChannel()
    local UI = ns.UI
    if not channelDialog then
        local d = CreateFrame("Frame", "MeredanUIGuildCreateChannel", UIParent)
        d:SetSize(400, 300)
        d:SetPoint("CENTER", 0, 80)
        d:SetFrameStrata("DIALOG")
        d:SetToplevel(true)
        d:EnableMouse(true)
        UI.Box(d, ns.STYLE.panelColor)
        local accent = d:CreateTexture(nil, "OVERLAY")
        accent:SetColorTexture(unpack(UI.ACCENT))
        accent:SetPoint("TOPLEFT")
        accent:SetPoint("TOPRIGHT")
        accent:SetHeight(2 * ns.PixelSize())
        tinsert(UISpecialFrames, "MeredanUIGuildCreateChannel")
        local title = UI.Text(d, 15, "CENTER")
        title:SetPoint("TOP", 0, -18)
        title:SetText(COMMUNITIES_CREATE_CHANNEL or L["Create channel"])
        local nameLabel = UI.Text(d, 12, "LEFT", UI.ACCENT)
        nameLabel:SetPoint("TOPLEFT", 20, -52)
        nameLabel:SetText(COMMUNITIES_EDIT_DIALOG_NAME_LABEL or L["Channel name"])
        d.name = UI.EditBox(d, 28)
        d.name:SetPoint("TOPLEFT", 20, -70)
        d.name:SetPoint("RIGHT", -20, 0)
        d.name:SetFont(ns.STYLE.font, ns.FontPx(13), "")
        d.name:SetMaxLetters(30)
        local subjectLabel = UI.Text(d, 12, "LEFT", UI.ACCENT)
        subjectLabel:SetPoint("TOPLEFT", 20, -110)
        subjectLabel:SetText(COMMUNITIES_EDIT_DIALOG_DESCRIPTION_LABEL or L["Description"])
        local box = Panel(d)
        box:SetPoint("TOPLEFT", 20, -128)
        box:SetPoint("RIGHT", -20, 0)
        box:SetHeight(62)
        d.subject = CreateFrame("EditBox", nil, box)
        d.subject:SetMultiLine(true)
        d.subject:SetAutoFocus(false)
        d.subject:SetMaxLetters(255)
        d.subject:SetFont(ns.STYLE.font, ns.FontPx(13), "")
        d.subject:SetTextColor(unpack(UI.TEXT))
        d.subject:SetPoint("TOPLEFT", 8, -6)
        d.subject:SetPoint("BOTTOMRIGHT", -8, 6)
        d.subject:SetScript("OnEscapePressed", function() d:Hide() end)
        box:EnableMouse(true)
        box:SetScript("OnMouseDown", function() d.subject:SetFocus() end)
        local hint = UI.Text(box, 12, "LEFT", { 0.47, 0.46, 0.43 })
        hint:SetPoint("TOPLEFT", 8, -6)
        hint:SetText(OPTIONAL or L["Optional"])
        d.subject:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
        d.modsOnly = Check(d, COMMUNITIES_EDIT_DIALOG_MODERATORS_ONLY or L["Moderators only"])
        d.modsOnly:SetPoint("TOP", box, "BOTTOM", 0, -14)
        d.accept = UI.Button(d, ACCEPT or L["Accept"], function()
            local name = strtrim(d.name:GetText() or "")
            if name ~= "" and d.clubId then
                C_Club.CreateStream(d.clubId, name, d.subject:GetText() or "", d.modsOnly:GetChecked() and true or false)
            end
            d:Hide()
        end, 120)
        d.accept:SetHeight(28)
        d.accept:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -4, 18)
        d.accept:SetMotionScriptsWhileDisabled(true)
        local cancel = UI.Button(d, CANCEL or L["Cancel"], function() d:Hide() end, 120)
        cancel:SetHeight(28)
        cancel:SetPoint("BOTTOMLEFT", d, "BOTTOM", 4, 18)
        local function UpdateAccept()
            local ok = strtrim(d.name:GetText() or "") ~= ""
            d.accept:SetEnabled(ok)
            d.accept:SetAlpha(ok and 1 or 0.45)
        end
        d.name:SetScript("OnTextChanged", UpdateAccept)
        d.name:SetScript("OnEnterPressed", function() if d.accept:IsEnabled() then d.accept:Click() end end)
        d.name:SetScript("OnTabPressed", function() d.subject:SetFocus() end)
        d.UpdateAccept = UpdateAccept
        channelDialog = d
    end
    local d = channelDialog
    d.clubId = selectedClubId
    d.name:SetText("")
    d.subject:SetText("")
    d.modsOnly:SetChecked(false)
    d.UpdateAccept()
    d:Show()
    d.name:SetFocus()
end

-- Benachrichtigungen wie Blizzards Dialog (Screenshot Benny 2026-11-07): Club-Auswahl oben rechts,
-- „Benachrichtigung bei Schnellbeitritt“, je Kanal Alle/Keine (Spalten), Alle-/Keine-Knöpfe, OK/Abbrechen.
-- Gespeichert wird erst bei OK (C_Club.SetSocialQueueingEnabled + SetClubStreamNotificationSettings).
local notify
local RefreshNotifyRows
local function NotifyRadio(parent)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    UI.CheckBg(button)
    local dot = button:CreateTexture(nil, "ARTWORK")
    dot:SetPoint("TOPLEFT", 4, -4)
    dot:SetPoint("BOTTOMRIGHT", -4, 4)
    dot:SetColorTexture(unpack(UI.ACCENT))
    function button:SetChecked(on) dot:SetShown(on and true or false) end
    button:SetChecked(false)
    return button
end

local function RefreshNotify()
    local UI = ns.UI
    local clubId = notify.clubId
    local clubInfo = clubId and C_Club.GetClubInfo(clubId)
    notify.club.Text:SetText(clubInfo and clubInfo.name or "")
    local quick = clubInfo and clubInfo.clubType ~= Enum.ClubType.BattleNet
    notify.quick:SetShown(quick and true or false)
    if quick then notify.quick:SetChecked(clubInfo.socialQueueingEnabled) end
    notify.header:ClearAllPoints()
    notify.header:SetPoint("TOPLEFT", 20, quick and -112 or -72)
    notify.header:SetPoint("RIGHT", -20, 0)
    local lookup = {}
    for _, setting in ipairs(clubId and C_Club.GetClubStreamNotificationSettings(clubId) or {}) do
        lookup[setting.streamId] = setting.filter
    end
    notify.filters = {}
    local F = Enum.ClubStreamNotificationFilter
    local streams = clubId and SortedStreams(clubId) or {}
    for i, stream in ipairs(streams) do
        local row = notify.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, notify)
            row:SetHeight(50)
            local line = row:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(1, 1, 1, 0.08)
            line:SetHeight(1)
            line:SetPoint("BOTTOMLEFT")
            line:SetPoint("BOTTOMRIGHT")
            row.name = UI.Text(row, 13, "LEFT", UI.ACCENT)
            row.name:SetPoint("LEFT", 12, 0)
            row.all = NotifyRadio(row)
            -- gleiche Spalten wie die Knöpfe „Alle“ (Mitte −126) und „Keine“ (Mitte −50) im Kopf
            row.all:SetPoint("CENTER", row, "RIGHT", -126, 0)
            row.none = NotifyRadio(row)
            row.none:SetPoint("CENTER", row, "RIGHT", -50, 0)
            row.all:SetScript("OnClick", function() notify.filters[row.streamId] = F.All RefreshNotifyRows() end)
            row.none:SetScript("OnClick", function() notify.filters[row.streamId] = F.None RefreshNotifyRows() end)
            notify.rows[i] = row
        end
        row.streamId = stream.streamId
        row.name:SetText(stream.name ~= "" and stream.name or StreamName(clubId, stream))
        notify.filters[stream.streamId] = lookup[stream.streamId] or F.None
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", notify.header, "BOTTOMLEFT", 0, -10 - (i - 1) * 50)
        row:SetPoint("RIGHT", notify.header, "RIGHT")
        row:Show()
    end
    for i = #streams + 1, #notify.rows do notify.rows[i]:Hide() end
    notify.count = #streams
    RefreshNotifyRows()
end

RefreshNotifyRows = function()
    local F = Enum.ClubStreamNotificationFilter
    for i = 1, notify.count or 0 do
        local row = notify.rows[i]
        local filter = notify.filters[row.streamId]
        row.all:SetChecked(filter == F.All)
        row.none:SetChecked(filter ~= F.All)
    end
end

local function OpenNotificationMenu()
    local UI = ns.UI
    if not notify then
        local d = CreateFrame("Frame", "MeredanUIGuildNotifications", UIParent)
        d:SetSize(560, 440)
        d:SetPoint("CENTER", 0, 60)
        d:SetFrameStrata("DIALOG")
        d:SetToplevel(true)
        d:EnableMouse(true)
        UI.Box(d, ns.STYLE.panelColor)
        local accent = d:CreateTexture(nil, "OVERLAY")
        accent:SetColorTexture(unpack(UI.ACCENT))
        accent:SetPoint("TOPLEFT")
        accent:SetPoint("TOPRIGHT")
        accent:SetHeight(2 * ns.PixelSize())
        tinsert(UISpecialFrames, "MeredanUIGuildNotifications")
        local title = UI.Text(d, 15, "LEFT")
        title:SetPoint("TOPLEFT", 20, -22)
        title:SetText(COMMUNITIES_NOTIFICATION_SETTINGS or L["Notifications"])
        d.club = Dropdown(d, 190, function(self)
            local items = {}
            for _, clubInfo in ipairs(SortedClubs()) do items[#items + 1] = { value = clubInfo.clubId, label = clubInfo.name } end
            UI.OpenList(self, items, d.clubId, function(value)
                d.clubId = value
                RefreshNotify()
            end)
        end)
        d.club:SetPoint("TOPRIGHT", -20, -16)
        local line = d:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(0, 0, 0, 1)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 0, -56)
        line:SetPoint("TOPRIGHT", 0, -56)
        d.quick = Check(d, COMMUNITIES_NOTIFICATIONS_QUICK_JOIN or L["Notify on quick join"])
        d.quick:SetPoint("TOPLEFT", 20, -76)
        d.header = CreateFrame("Frame", nil, d)
        d.header:SetHeight(28)
        local headerText = UI.Text(d.header, 13, "LEFT")
        headerText:SetPoint("LEFT", 12, 0)
        headerText:SetText(COMMUNITIES_NOTIFICATION_SETTINGS or L["Notifications"])
        local headerLine = d.header:CreateTexture(nil, "ARTWORK")
        headerLine:SetColorTexture(1, 1, 1, 0.08)
        headerLine:SetHeight(1)
        headerLine:SetPoint("BOTTOMLEFT", 0, -6)
        headerLine:SetPoint("BOTTOMRIGHT", 0, -6)
        local F = Enum.ClubStreamNotificationFilter
        d.noneButton = UI.Button(d.header, COMMUNITIES_NOTIFICATION_SETTINGS_DIALOG_NONE or L["None"], function()
            for id in pairs(d.filters) do d.filters[id] = F.None end
            RefreshNotifyRows()
        end, 60)
        d.noneButton:SetPoint("RIGHT", -20, 0)
        d.allButton = UI.Button(d.header, COMMUNITIES_NOTIFICATION_SETTINGS_DIALOG_ALL or L["All"], function()
            for id in pairs(d.filters) do d.filters[id] = F.All end
            RefreshNotifyRows()
        end, 60)
        d.allButton:SetPoint("RIGHT", d.noneButton, "LEFT", -16, 0)
        d.rows = {}
        d.filters = {}
        local cancel = UI.Button(d, CANCEL or L["Cancel"], function() d:Hide() end, 110)
        cancel:SetHeight(28)
        cancel:SetPoint("BOTTOMRIGHT", -20, 16)
        local ok = UI.Button(d, OKAY or "OK", function()
            local clubId = d.clubId
            if clubId then
                local clubInfo = C_Club.GetClubInfo(clubId)
                if clubInfo and clubInfo.clubType ~= Enum.ClubType.BattleNet then
                    C_Club.SetSocialQueueingEnabled(clubId, d.quick:GetChecked() and true or false)
                end
                local list = {}
                for i = 1, d.count or 0 do
                    local id = d.rows[i].streamId
                    list[#list + 1] = { streamId = id, filter = d.filters[id] }
                end
                C_Club.SetClubStreamNotificationSettings(clubId, list)
            end
            d:Hide()
        end, 110)
        ok:SetHeight(28)
        ok:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
        notify = d
    end
    notify.clubId = selectedClubId
    notify:Show()
    RefreshNotify()
end

local function OpenStreamMenu(owner)
    local clubId = selectedClubId
    if not clubId then return end
    local UI = ns.UI
    local items = {}
    local streams = SortedStreams(clubId)
    for _, stream in ipairs(streams) do
        local subscribed = C_Club.IsSubscribedToStream(clubId, stream.streamId)
        local label = StreamName(clubId, stream)
        if not subscribed then label = "|cff99978f" .. label .. "|r  " .. CreateAtlasMarkup("Forge-Lock", 12, 14) end
        if CommunitiesUtil.DoesCommunityStreamHaveUnreadMessages and CommunitiesUtil.DoesCommunityStreamHaveUnreadMessages(clubId, stream.streamId) then
            label = CreateAtlasMarkup("communities-icon-notification", 12, 12) .. " " .. label
        end
        items[#items + 1] = { value = stream.streamId, label = label, inert = not subscribed }
    end
    local privileges = C_Club.GetClubPrivileges(clubId)
    local clubInfo = C_Club.GetClubInfo(clubId)
    local limits = C_Club.GetClubLimits(clubInfo and clubInfo.clubType or Enum.ClubType.Character)
    if privileges and privileges.canCreateStream and limits and #streams < limits.maximumNumberOfStreams then
        items[#items + 1] = { value = "create", label = "|cff8ecbb4+  " .. (COMMUNITIES_CREATE_CHANNEL or L["Create channel"]) .. "|r" }
    end
    items[#items + 1] = { value = "notify", label = COMMUNITIES_NOTIFICATION_SETTINGS or L["Notifications"] }
    UI.OpenList(owner, items, SelectedStream(), function(value)
        if value == "create" then
            CreateChannel()
        elseif value == "notify" then
            C_Timer.After(0, OpenNotificationMenu)
        else
            SelectStream(value)
        end
    end)
end

-- Mitglieder-Spalte rechts im Chat
local chatRows = {}
local function ChatMemberRow(i)
    if chatRows[i] then return chatRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, chat.memberList.child)
    row:SetHeight(22)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    hover:Hide()
    -- gewählt (Details offen): unterlegt mit Surf-Green-Streifen wie in der Mitgliederliste
    row.selectedBg = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.selectedBg:SetAllPoints()
    row.selectedBg:SetColorTexture(0.122, 0.141, 0.133, 1)
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.strip:SetColorTexture(unpack(UI.ACCENT))
    row.presence = row:CreateTexture(nil, "ARTWORK")
    row.presence:SetSize(12, 12)
    row.presence:SetPoint("LEFT", 6, 0)
    row.name = UI.Text(row, 12, "LEFT")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetWordWrap(false)
    row.rank = row:CreateTexture(nil, "ARTWORK")
    row.rank:SetSize(12, 12)
    row:SetScript("OnEnter", function() hover:Show() end)
    row:SetScript("OnLeave", function() hover:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if not self.info then return end
        if button == "RightButton" then
            OpenMemberMenu(self.info)
        elseif IsGuildClub() then
            -- wie in der Mitgliederliste: Details rechts daneben
            ns.ShowGuildMemberDetail(selectedClubId, self.info.memberId)
        end
    end)
    chatRows[i] = row
    return row
end

local function SortChatMembers(list)
    table.sort(list, function(a, b)
        local ao, bo = IsOnline(a), IsOnline(b)
        if ao ~= bo then return ao end
        local ar, br = P(a.guildRankOrder) or 99, P(b.guildRankOrder) or 99
        if ar ~= br then return ar < br end
        return (P(a.name) or "") < (P(b.name) or "")
    end)
end

local function RefreshChatMembers(list)
    local width = MEMBER_W - 8
    SortChatMembers(list)
    local y = 4
    local selectedMember = ns.GuildDetailMember and ns.GuildDetailMember()
    for i, info in ipairs(list) do
        local row = ChatMemberRow(i)
        row.info = info
        local selected = selectedMember ~= nil and info.memberId == selectedMember
        row.selectedBg:SetShown(selected)
        row.strip:SetShown(selected)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        local online = IsOnline(info)
        local presence = P(info.presence)
        local E = Enum.ClubMemberPresence
        local icon = presence == E.Away and FRIENDS_TEXTURE_AFK or presence == E.Busy and FRIENDS_TEXTURE_DND
            or presence == E.OnlineMobile and "Interface\\ChatFrame\\UI-ChatIcon-ArmoryChat" or nil
        row.presence:SetShown(icon ~= nil)
        if icon then row.presence:SetTexture(icon) end
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", icon and 20 or 8, 0)
        row.name:SetText(P(info.name) or "")
        row.name:SetTextColor(unpack(online and ClassColor(info) or GREY))
        row.name:SetWidth(math.min(row.name:GetUnboundedStringWidth(), width - 30))
        local rank, rankColor = RankIconTexture(info)
        row.rank:SetShown(rank ~= nil)
        if rank then
            row.rank:SetTexture(rank)
            row.rank:SetVertexColor(unpack(rankColor or { 1, 1, 1 }))
            row.rank:ClearAllPoints()
            row.rank:SetPoint("LEFT", row.name, "RIGHT", 3, 0)
        end
        row:Show()
        y = y + 22
    end
    for i = #list + 1, #chatRows do chatRows[i]:Hide() end
    chat.memberList.child:SetWidth(width)
    chat.memberList:SetContentHeight(y + 4)
end

local function CreateChatView(view)
    local UI = ns.UI
    chat.view = view
    chat.streamButton = Dropdown(view, 180, function(self) OpenStreamMenu(self) end)
    chat.streamButton:SetPoint("TOPLEFT")
    chat.streamButton.Text:SetTextColor(unpack(UI.ACCENT))
    -- Kompakt: Club wählen statt Liste
    chat.clubButton = Dropdown(view, 180, function(self)
        local items = {}
        for _, clubInfo in ipairs(SortedClubs()) do items[#items + 1] = { value = clubInfo.clubId, label = clubInfo.name } end
        UI.OpenList(self, items, selectedClubId, function(value) ns.SelectGuildClub(value) end)
    end)
    chat.clubButton:SetPoint("TOPLEFT")
    chat.clubButton:Hide()

    chat.count = UI.Text(view, 12, "LEFT", UI.MUTED)
    chat.count:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, -8)
    chat.count:SetWidth(MEMBER_W - 10)
    -- Sprachchat: Blizzards Kopfhörer-Knopf (gleiche Logik wie im Original)
    local ok, headset = pcall(CreateFrame, "Frame", nil, view, "VoiceChatHeadsetTemplate")
    if ok and headset then
        chat.headset = headset
        headset:SetSize(54, 27)
        headset:SetPoint("RIGHT", chat.count, "LEFT", -6, 0)
    end

    -- Mitglieder rechts
    local memberBg = Panel(view)
    memberBg:SetPoint("TOPRIGHT", 0, -36)
    memberBg:SetPoint("BOTTOMRIGHT")
    memberBg:SetWidth(MEMBER_W)
    chat.memberBg = memberBg
    chat.memberList = UI.ScrollArea(memberBg)
    chat.memberList:SetPoint("TOPLEFT", 4, -2)
    chat.memberList:SetPoint("BOTTOMRIGHT", -10, 2)

    -- Nachrichten
    local messageBg = Panel(view)
    messageBg:SetPoint("TOPLEFT", 0, -36)
    messageBg:SetPoint("BOTTOMRIGHT", memberBg, "BOTTOMLEFT", -8, 36)
    chat.messageBg = messageBg
    local messages = CreateFrame("ScrollingMessageFrame", nil, messageBg)
    messages:SetPoint("TOPLEFT", 10, -8)
    messages:SetPoint("BOTTOMRIGHT", -18, 8)
    messages:SetFont(ns.FontFor("text"), ns.FontPx(13), "") -- Chat = Fließtext: mUI Text
    messages:SetSpacing(4) -- mehr Luft zwischen den Zeilen (Benny 2026-11-07)
    messages:SetShadowOffset(1, -1)
    messages:SetJustifyH("LEFT")
    messages:SetFading(false)
    messages:SetMaxLines(MAX_CHAT_LINES)
    messages:SetIndentedWordWrap(true)
    messages:SetHyperlinksEnabled(true)
    messages:EnableMouseWheel(true)
    messages:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then
            if IsShiftKeyDown() then self:ScrollToTop() else self:ScrollUp() end
        else
            if IsShiftKeyDown() then self:ScrollToBottom() else self:ScrollDown() end
        end
        if chat.UpdateScrollbar then chat.UpdateScrollbar() end
    end)
    messages:SetScript("OnHyperlinkClick", function(self, link, text, button) SetItemRef(link, text, button, self) end)
    -- Scrollleiste im mUI-Look (UI.Scrollbar); Offset der Nachrichten: 0 = ganz unten
    local function ChatLines()
        local _, fontHeight = messages:GetFont()
        return math.max(math.floor(messages:GetHeight() / ((fontHeight or 13) + 3)), 1)
    end
    local scrollbar = UI.Scrollbar(messageBg, {
        GetRange = function() return messages:GetMaxScrollRange() or 0 end,
        GetOffset = function() return (messages:GetMaxScrollRange() or 0) - (messages:GetScrollOffset() or 0) end,
        SetOffset = function(value)
            messages:SetScrollOffset(math.floor((messages:GetMaxScrollRange() or 0) - value + 0.5))
        end,
        GetRatio = function()
            local visible = ChatLines()
            return visible / (visible + (messages:GetMaxScrollRange() or 0))
        end,
        step = 3,
        page = 15,
    })
    scrollbar:SetPoint("TOPRIGHT", -4, -6)
    scrollbar:SetPoint("BOTTOMRIGHT", -4, 6)
    local function UpdateScrollbar() scrollbar:Update() end
    chat.UpdateScrollbar = UpdateScrollbar
    hooksecurefunc(messages, "AddMessage", function() C_Timer.After(0, UpdateScrollbar) end)
    hooksecurefunc(messages, "BackFillMessage", function() C_Timer.After(0, UpdateScrollbar) end)
    hooksecurefunc(messages, "Clear", function() C_Timer.After(0, UpdateScrollbar) end)
    messages:HookScript("OnSizeChanged", UpdateScrollbar)
    if messages.SetOnScrollChangedCallback then
        messages:SetOnScrollChangedCallback(function(frame, offset)
            UpdateScrollbar()
            if frame:GetNumMessages() >= MAX_CHAT_LINES then return end
            if frame:GetNumMessages() - offset <= 5 then RequestMoreHistory() end
        end)
    end
    chat.messages = messages

    -- Eingabe
    local input = UI.EditBox(view, 30)
    input:SetPoint("BOTTOMLEFT")
    input:SetPoint("BOTTOMRIGHT", memberBg, "BOTTOMLEFT", -8, 0)
    input:SetFont(ns.STYLE.font, ns.FontPx(13), "")
    input:SetMaxLetters(255)
    input:SetScript("OnEnterPressed", function(self)
        local text = self:GetText()
        if text ~= "" then
            SendChat(text)
            self:SetText("")
        end
        self:ClearFocus()
    end)
    input:HookScript("OnEditFocusGained", function(self)
        if ChatFrameUtil and ChatFrameUtil.SetChatFocusOverride then ChatFrameUtil.SetChatFocusOverride(self) end
    end)
    input:HookScript("OnEditFocusLost", function(self)
        if ChatFrameUtil and ChatFrameUtil.GetChatFocusOverride and ChatFrameUtil.GetChatFocusOverride() == self then
            ChatFrameUtil.ClearChatFocusOverride()
        end
    end)
    chat.input = input
end

local function RefreshChat()
    if not chat.view then return end
    local clubId = selectedClubId
    -- gewählten Kanal prüfen (sonst den ersten abonnierten)
    local streamId = selectedStreams[clubId or 0]
    local streams = clubId and SortedStreams(clubId) or {}
    local valid = false
    for _, stream in ipairs(streams) do
        if stream.streamId == streamId then valid = true end
    end
    if not valid then
        streamId = nil
        for _, stream in ipairs(streams) do
            if C_Club.IsSubscribedToStream(clubId, stream.streamId) then streamId = stream.streamId break end
        end
        if streamId then SelectStream(streamId) end
    elseif focused.streamId ~= streamId then
        SelectStream(streamId)
    end
    local list = Members(clubId)
    chat.count:SetText(COMMUNITIES_MEMBER_LIST_MEMBER_COUNT_FORMAT and
        COMMUNITIES_MEMBER_LIST_MEMBER_COUNT_FORMAT:format(CountOnline(list), #list)
        or (CountOnline(list) .. "/" .. #list .. " online"))
    RefreshChatMembers(list)
    -- Kompakt: Club-Auswahl vor dem Kanal, keine Mitglieder-Spalte
    chat.clubButton:SetShown(compact)
    local info = ClubInfo()
    chat.clubButton.Text:SetText(info and info.name or "")
    chat.streamButton:ClearAllPoints()
    if compact then
        chat.streamButton:SetPoint("LEFT", chat.clubButton, "RIGHT", 6, 0)
    else
        chat.streamButton:SetPoint("TOPLEFT")
    end
    chat.memberBg:SetShown(not compact)
    chat.count:SetShown(not compact)
    chat.messageBg:SetPoint("BOTTOMRIGHT", compact and chat.view or chat.memberBg, compact and "BOTTOMRIGHT" or "BOTTOMLEFT",
        compact and 0 or -8, 36)
    chat.input:SetPoint("BOTTOMRIGHT", compact and chat.view or chat.memberBg, compact and "BOTTOMRIGHT" or "BOTTOMLEFT",
        compact and 0 or -8, 0)
end

-- Mitglieder ------------------------------------------------------------------------------------

local roster = { rows = {}, sort = "level", reverse = false }
local COLUMNS = {
    { key = "level", title = "COMMUNITIES_ROSTER_COLUMN_TITLE_LEVEL", fallback = "Level", width = 44 },
    { key = "class", title = "COMMUNITIES_ROSTER_COLUMN_TITLE_CLASS", fallback = "Class", width = 50 },
    { key = "name", title = "COMMUNITIES_ROSTER_COLUMN_TITLE_NAME", fallback = "Name", width = 150 },
    { key = "zone", title = "COMMUNITIES_ROSTER_COLUMN_TITLE_ZONE", fallback = "Zone", width = 120 },
    { key = "rank", title = "COMMUNITIES_ROSTER_COLUMN_TITLE_RANK", fallback = "Rank", width = 104 },
    { key = "note", title = "COMMUNITIES_ROSTER_COLUMN_TITLE_NOTE", fallback = "Note" },
}

local function ShowOffline() return C_CVar.GetCVarBool("communitiesShowOffline") end

local function SortValue(info, key)
    if key == "level" then return P(info.level) or 0 end
    if key == "class" then return select(2, ClassFile(info)) or "" end
    if key == "name" then return (P(info.name) or ""):lower() end
    if key == "zone" then return IsOnline(info) and (P(info.zone) or "") or "~" .. (P(info.lastOnlineYear) or 0) end
    if key == "rank" then return P(info.guildRankOrder) or 99 end
    return (P(info.memberNote) or ""):lower()
end

local function SortRoster(list)
    local key, reverse = roster.sort, roster.reverse
    -- Standard wie bei Blizzard: Stufe absteigend; online immer zuerst
    local descending = key == "level"
    if reverse then descending = not descending end
    table.sort(list, function(a, b)
        local ao, bo = IsOnline(a), IsOnline(b)
        if ao ~= bo then return ao end
        local av, bv = SortValue(a, key), SortValue(b, key)
        if av ~= bv then
            if descending then return av > bv end
            return av < bv
        end
        return (P(a.name) or "") < (P(b.name) or "")
    end)
end

local function SetClassIcon(texture, info)
    local file = ClassFile(info)
    local atlas = file and ("classicon-" .. file:lower())
    if atlas and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
        texture:Show()
    elseif file and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file] then
        texture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        texture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[file]))
        texture:Show()
    else
        texture:Hide()
    end
end

local function RosterRow(i)
    if roster.rows[i] then return roster.rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, roster.list.child)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.cells = {}
    local x = 10
    for c, column in ipairs(COLUMNS) do
        if column.key == "class" then
            row.classIcon = row:CreateTexture(nil, "ARTWORK")
            row.classIcon:SetSize(18, 18)
            row.classIcon:SetPoint("LEFT", x + 2, 0)
        else
            local text = UI.Text(row, 12, "LEFT")
            text:SetPoint("LEFT", x, 0)
            text:SetWordWrap(false)
            if column.width then text:SetWidth(column.width - 8) else text:SetPoint("RIGHT", -8, 0) end
            row.cells[column.key] = text
        end
        x = x + (column.width or 0)
    end
    row.rankIcon = row:CreateTexture(nil, "ARTWORK")
    row.rankIcon:SetSize(12, 12)
    row.presence = row:CreateTexture(nil, "ARTWORK")
    row.presence:SetSize(12, 12)
    row:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetColorTexture(1, 1, 1, 0.04) end end)
    row:SetScript("OnLeave", function(self) if not self.selected then self.bg:SetColorTexture(0, 0, 0, 0) end end)
    row:SetScript("OnClick", function(self, button)
        if not self.info then return end
        if button == "RightButton" then
            OpenMemberMenu(self.info)
        elseif IsGuildClub() then
            ns.ShowGuildMemberDetail(selectedClubId, self.info.memberId)
        end
    end)
    roster.rows[i] = row
    return row
end

local function RefreshRoster()
    if not roster.view then return end
    local UI = ns.UI
    local all = Members(selectedClubId)
    local online = CountOnline(all)
    local list = {}
    local showOffline = ShowOffline()
    for _, info in ipairs(all) do
        if showOffline or IsOnline(info) then list[#list + 1] = info end
    end
    SortRoster(list)
    roster.offline:SetChecked(showOffline)
    for _, header in ipairs(roster.headers) do
        local active = header.key == roster.sort
        header.Text:SetTextColor(unpack(active and UI.ACCENT or UI.MUTED))
    end
    local width = roster.list:GetWidth()
    local selectedMember = ns.GuildDetailMember and ns.GuildDetailMember()
    for i, info in ipairs(list) do
        local row = RosterRow(i)
        row.info = info
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetWidth(width)
        local isOnline = IsOnline(info)
        local text = isOnline and UI.TEXT or GREY
        local cells = row.cells
        cells.level:SetText(P(info.level) or "")
        cells.level:SetTextColor(unpack(text))
        SetClassIcon(row.classIcon, info)
        row.classIcon:SetDesaturated(not isOnline)
        row.classIcon:SetAlpha(isOnline and 1 or 0.6)
        local presence = P(info.presence)
        local E = Enum.ClubMemberPresence
        local icon = presence == E.Away and FRIENDS_TEXTURE_AFK or presence == E.Busy and FRIENDS_TEXTURE_DND
            or presence == E.OnlineMobile and "Interface\\ChatFrame\\UI-ChatIcon-ArmoryChat" or nil
        row.presence:SetShown(icon ~= nil)
        cells.name:ClearAllPoints()
        if icon then
            row.presence:SetTexture(icon)
            row.presence:ClearAllPoints()
            row.presence:SetPoint("LEFT", 10 + COLUMNS[1].width + COLUMNS[2].width, 0)
            cells.name:SetPoint("LEFT", row.presence, "RIGHT", 2, 0)
        else
            cells.name:SetPoint("LEFT", 10 + COLUMNS[1].width + COLUMNS[2].width, 0)
        end
        cells.name:SetText(P(info.name) or "")
        cells.name:SetTextColor(unpack(isOnline and ClassColor(info) or GREY))
        cells.name:SetWidth(math.min(cells.name:GetUnboundedStringWidth(), COLUMNS[3].width - (icon and 34 or 22)))
        local rank, rankColor = RankIconTexture(info)
        row.rankIcon:SetShown(rank ~= nil)
        if rank then
            row.rankIcon:SetTexture(rank)
            row.rankIcon:SetVertexColor(unpack(rankColor or { 1, 1, 1 }))
            row.rankIcon:ClearAllPoints()
            row.rankIcon:SetPoint("LEFT", cells.name, "RIGHT", 3, 0)
        end
        if presence == E.OnlineMobile then
            cells.zone:SetText(COMMUNITIES_PRESENCE_MOBILE_CHAT or "")
        elseif isOnline then
            cells.zone:SetText(P(info.zone) or "")
        else
            cells.zone:SetText(LastOnlineText(info))
        end
        cells.zone:SetTextColor(unpack(text))
        cells.rank:SetText(P(info.guildRank) or "")
        cells.rank:SetTextColor(unpack(text))
        cells.note:SetText(P(info.memberNote) or "")
        cells.note:SetTextColor(unpack(text))
        row.selected = selectedMember ~= nil and info.memberId == selectedMember
        row.bg:SetColorTexture(unpack(row.selected and { 0.122, 0.141, 0.133, 1 } or { 0, 0, 0, 0 }))
        row.strip:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], row.selected and 1 or 0)
        row:Show()
    end
    for i = #list + 1, #roster.rows do roster.rows[i]:Hide() end
    roster.list.child:SetWidth(width)
    roster.list:SetContentHeight(#list * ROW_H)
    roster.footer = L["%d of %d online"]:format(online, #all)
end

local function CreateRosterView(view)
    local UI = ns.UI
    roster.view = view
    roster.offline = Check(view, COMMUNITIES_MEMBER_LIST_SHOW_OFFLINE or L["Show offline members"], function(_, on)
        SetCVar("communitiesShowOffline", on and "1" or "0")
        ns.RefreshGuild()
    end)
    roster.offline:SetPoint("TOPLEFT", 0, -4)

    local header = CreateFrame("Frame", nil, view)
    header:SetPoint("TOPLEFT", 0, -36)
    header:SetPoint("TOPRIGHT", 0, -36)
    header:SetHeight(26)
    UI.Box(header, { 0.098, 0.098, 0.106, 1 })
    roster.headers = {}
    local x = 0
    for _, column in ipairs(COLUMNS) do
        local button = CreateFrame("Button", nil, header)
        button:SetPoint("TOPLEFT", x, 0)
        button:SetPoint("BOTTOMLEFT", x, 0)
        if column.width then button:SetWidth(column.width) else button:SetPoint("RIGHT") end
        button.key = column.key
        button.Text = UI.Text(button, 12, "LEFT", UI.MUTED)
        button.Text:SetPoint("LEFT", 10, 0)
        button.Text:SetText(G(column.title, column.fallback))
        button:SetScript("OnEnter", function(self) self.Text:SetTextColor(unpack(UI.TEXT)) end)
        button:SetScript("OnLeave", function() ns.RefreshGuild() end)
        button:SetScript("OnClick", function(self)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            if roster.sort == self.key then roster.reverse = not roster.reverse else roster.sort, roster.reverse = self.key, false end
            ns.RefreshGuild()
        end)
        roster.headers[#roster.headers + 1] = button
        x = x + (column.width or 0)
    end

    roster.list = UI.ScrollArea(view)
    roster.list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    roster.list:SetPoint("BOTTOMRIGHT", -10, 0)
end

-- Info ------------------------------------------------------------------------------------------

local info = { newsRows = {} }

local function NewsRow(i)
    if info.newsRows[i] then return info.newsRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, info.news.child)
    row:SetHeight(26)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.bgTex = row:CreateTexture(nil, "BACKGROUND")
    row.bgTex:SetAllPoints()
    row.bgTex:SetColorTexture(0.078, 0.078, 0.086, 1)
    -- Felder, die Blizzards GuildNewsButton_SetNews/SetMOTD erwartet
    row.text = UI.Text(row, 12, "LEFT")
    row.text:SetPoint("LEFT", 24, 0)
    row.text:SetPoint("RIGHT", -8, 0)
    row.text:SetWordWrap(false)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 6, 0)
    row.dash = UI.Text(row, 12, "LEFT", UI.MUTED)
    row.dash:SetPoint("LEFT", 10, 0)
    row.dash:SetText("–")
    row.header = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.header:SetAllPoints()
    row.header:SetColorTexture(0.122, 0.141, 0.133, 1)
    row:SetScript("OnEnter", function(self)
        local news = self.newsInfo
        if not news or news.isHeader then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local what = news.whatText
        if what and what:find("|H") then
            GameTooltip:SetHyperlink(what:match("|H(.-)|h"))
        elseif self.newsType == NEWS_PLAYER_ACHIEVEMENT or self.newsType == NEWS_GUILD_ACHIEVEMENT then
            local link = self.id and GetAchievementLink(self.id)
            if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(self.text:GetText() or "", 1, 1, 1, 1, true) end
        else
            GameTooltip:SetText(self.text:GetText() or "", 1, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if button ~= "RightButton" or not self.index or not self.newsInfo then return end
        local index, sticky = self.index, self.newsInfo.isSticky
        MenuUtil.CreateContextMenu(self, function(_, root)
            if sticky then
                root:CreateButton(GUILD_NEWS_REMOVE_STICKY, function() GuildNewsSetSticky(index, 0) end)
            else
                root:CreateButton(GUILD_NEWS_MAKE_STICKY, function() GuildNewsSetSticky(index, 1) end)
            end
        end)
    end)
    info.newsRows[i] = row
    return row
end

local function ResetNewsRow(row)
    row.newsInfo, row.index, row.newsType, row.id = nil, nil, nil, nil
    row.icon:Hide()
    row.dash:Hide()
    row.header:Hide()
    row:Enable()
    row.text:SetPoint("LEFT", 24, 0)
end

local function RefreshNews()
    local width = info.news:GetWidth()
    local n = 0
    local function Next()
        n = n + 1
        local row = NewsRow(n)
        ResetNewsRow(row)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(n - 1) * 28)
        row:SetWidth(width)
        row:Show()
        return row
    end
    if CanReplaceGuildMaster and CanReplaceGuildMaster() then
        local row = Next()
        row.text:SetText("|cffff8040" .. (GUILD_IMPEACH_POPUP_TEXT and L["Replace the guild master"] or L["Replace the guild master"]) .. "|r")
        row:SetScript("OnMouseUp", function() StaticPopup_Show("GUILD_IMPEACH") end)
    end
    local motd = C_GuildInfo.GetMOTD()
    if motd and motd ~= "" then GuildNewsButton_SetMOTD(Next(), motd) end
    for index = 1, math.min(7, C_Calendar.GetNumGuildEvents() or 0) do
        local row = Next()
        local ok = CommunitiesGuildNewsButton_SetEvent and pcall(CommunitiesGuildNewsButton_SetEvent, row, index)
        if not ok then row:Hide() n = n - 1 end
    end
    for index = 1, GetNumGuildNews() or 0 do GuildNewsButton_SetNews(Next(), index) end
    for i = n + 1, #info.newsRows do info.newsRows[i]:Hide() end
    info.news.child:SetWidth(width)
    info.news:SetContentHeight(n * 28)
    info.noNews:SetShown(n == 0)
end

local function RefreshInfo()
    if not info.view then return end
    local motd = C_GuildInfo.GetMOTD() or ""
    info.motd:SetText(motd ~= "" and motd or ("|cff77756e" .. L["No message of the day."] .. "|r"))
    local text = C_GuildInfo.GetInfoText() or ""
    info.details:SetText(text ~= "" and text or ("|cff77756e" .. L["No guild information."] .. "|r"))
    info.motdEdit:SetShown(CanEditMOTD())
    info.detailsEdit:SetShown(CanEditGuildInfo())
    info.detailsScroll.child:SetHeight(math.max(info.details:GetStringHeight() + 4, 1))
    info.detailsScroll:SetContentHeight(info.details:GetStringHeight() + 4)
    RefreshNews()
end

local function OpenNewsFilter(owner)
    local filters = { GetGuildNewsFilters() }
    local items = {}
    for index = 1, #filters do
        local label = _G["GUILD_NEWS_FILTER" .. index]
        if label then
            items[#items + 1] = { value = index, label = (filters[index] and "|cff8ecbb4" .. CreateAtlasMarkup("common-icon-checkmark", 12, 12) .. "|r  " or "      ") .. label }
        end
    end
    ns.UI.OpenList(owner, items, nil, function(index)
        SetGuildNewsFilter(index, filters[index] and 0 or 1)
        C_Timer.After(0, function() OpenNewsFilter(owner) end)
    end)
end

local function CreateInfoView(view)
    local UI = ns.UI
    info.view = view
    local half = (WIDTH - CONTENT_X - PAD - TAB_STEP * 0 - 12) / 2

    -- links oben: Nachricht des Tages
    local motdTitle = SectionTitle(view, GUILD_MOTD_LABEL2 and L["Message of the Day"] or L["Message of the Day"])
    motdTitle:SetPoint("TOPLEFT", 0, -6)
    info.motdEdit = UI.IconButton(view, "Edit", function()
        ns.OpenBlizzardGuild() -- SetMOTD ist für Addons geschützt
    end, 22)
    info.motdEdit:SetPoint("TOPLEFT", half - 22, 0)
    Tooltip(info.motdEdit, L["Click to edit"])
    local motdBox = Panel(view)
    motdBox:SetPoint("TOPLEFT", 0, -28)
    motdBox:SetPoint("BOTTOMLEFT", 0, 186)
    motdBox:SetWidth(half)
    local motdStrip = motdBox:CreateTexture(nil, "ARTWORK")
    motdStrip:SetPoint("TOPLEFT")
    motdStrip:SetPoint("BOTTOMLEFT")
    motdStrip:SetWidth(2)
    motdStrip:SetColorTexture(unpack(UI.ACCENT))
    info.motd = UI.Text(motdBox, 13, "LEFT")
    info.motd:SetPoint("TOPLEFT", 12, -10)
    info.motd:SetPoint("RIGHT", -12, 0)
    info.motd:SetJustifyV("TOP")
    info.motd:SetWordWrap(true)
    info.motd:SetPoint("BOTTOM", 0, 10)
    info.motd:SetSpacing(3)

    -- links unten: Gildeninformation
    local detailsTitle = SectionTitle(view, L["Guild Information"])
    detailsTitle:SetPoint("BOTTOMLEFT", 0, 162)
    info.detailsEdit = UI.IconButton(view, "Edit", function()
        ns.OpenBlizzardGuild() -- SetInfoText ist für Addons geschützt
    end, 22)
    info.detailsEdit:SetPoint("BOTTOMLEFT", half - 22, 158)
    Tooltip(info.detailsEdit, L["Click to edit"])
    local detailsBox = Panel(view)
    detailsBox:SetPoint("BOTTOMLEFT")
    detailsBox:SetSize(half, 150)
    info.detailsScroll = UI.ScrollArea(detailsBox)
    info.detailsScroll:SetPoint("TOPLEFT", 12, -10)
    info.detailsScroll:SetPoint("BOTTOMRIGHT", -16, 10)
    info.details = UI.Text(info.detailsScroll.child, 13, "LEFT")
    info.details:SetPoint("TOPLEFT")
    info.details:SetWidth(half - 32)
    info.details:SetJustifyV("TOP")
    info.details:SetWordWrap(true)
    info.details:SetSpacing(3)

    -- rechts: Gildenneuigkeiten
    local newsTitle = SectionTitle(view, GUILD_NEWS_TITLE or L["Guild News"])
    newsTitle:SetPoint("TOPLEFT", half + 12, -6)
    local filter = UI.IconButton(view, "Filter", function(self) OpenNewsFilter(self) end, 22)
    filter.icon:SetSize(12, 12)
    filter:SetPoint("TOPRIGHT", 0, 0)
    Tooltip(filter, L["Set up filters"])
    local newsBox = Panel(view)
    newsBox:SetPoint("TOPLEFT", half + 12, -28)
    newsBox:SetPoint("BOTTOMRIGHT")
    info.news = UI.ScrollArea(newsBox)
    info.news:SetPoint("TOPLEFT", 4, -4)
    info.news:SetPoint("BOTTOMRIGHT", -12, 4)
    info.noNews = UI.Text(newsBox, 13, "CENTER", UI.MUTED)
    info.noNews:SetPoint("TOP", 0, -40)
    info.noNews:SetText(GUILD_NEWS_NO_NEWS or L["No news yet."])
end

-- Ereignisprotokoll (Log ansehen)
local logFrame
local function UpdateLog()
    if not (logFrame and logFrame:IsShown()) then return end
    local lines = {}
    for i = GetNumGuildEvents(), 1, -1 do
        local kind, player1, player2, rank, year, month, day, hour = GetGuildEventInfo(i)
        player1, player2 = player1 or UNKNOWN, player2 or UNKNOWN
        local msg
        if kind == "invite" then msg = GUILDEVENT_TYPE_INVITE:format(player1, player2)
        elseif kind == "join" then msg = GUILDEVENT_TYPE_JOIN:format(player1)
        elseif kind == "promote" then msg = GUILDEVENT_TYPE_PROMOTE:format(player1, player2, rank)
        elseif kind == "demote" then msg = GUILDEVENT_TYPE_DEMOTE:format(player1, player2, rank)
        elseif kind == "remove" then msg = GUILDEVENT_TYPE_REMOVE:format(player1, player2)
        elseif kind == "quit" then msg = GUILDEVENT_TYPE_QUIT:format(player1)
        end
        if msg then lines[#lines + 1] = msg .. GUILD_BANK_LOG_TIME:format(TimeUtil.GetRecentTimeDate(year, month, day, hour)) end
    end
    logFrame.text:SetText(#lines > 0 and table.concat(lines, "\n") or ("|cff77756e" .. L["No entries yet."] .. "|r"))
    logFrame.scroll:SetContentHeight(logFrame.text:GetStringHeight() + 8)
end

local function ToggleLog()
    local UI = ns.UI
    if not logFrame then
        logFrame = CreateFrame("Frame", "MeredanUIGuildLog", UIParent)
        logFrame:SetSize(360, 420)
        logFrame:SetFrameStrata("HIGH")
        logFrame:SetToplevel(true)
        logFrame:EnableMouse(true)
        UI.Box(logFrame, ns.STYLE.panelColor)
        local accent = logFrame:CreateTexture(nil, "OVERLAY")
        accent:SetColorTexture(unpack(UI.ACCENT))
        accent:SetPoint("TOPLEFT")
        accent:SetPoint("TOPRIGHT")
        accent:SetHeight(2 * ns.PixelSize())
        tinsert(UISpecialFrames, "MeredanUIGuildLog")
        local title = UI.Text(logFrame, 15, "LEFT")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText(GUILD_EVENT_LOG or L["Guild log"])
        local close = UI.IconButton(logFrame, "Close", function() logFrame:Hide() end, 22)
        close:SetPoint("TOPRIGHT", -14, -14)
        local box = Panel(logFrame)
        box:SetPoint("TOPLEFT", 16, -48)
        box:SetPoint("BOTTOMRIGHT", -16, 16)
        logFrame.scroll = UI.ScrollArea(box)
        logFrame.scroll:SetPoint("TOPLEFT", 10, -8)
        logFrame.scroll:SetPoint("BOTTOMRIGHT", -16, 8)
        logFrame.text = UI.Text(logFrame.scroll.child, 12, "LEFT")
        logFrame.text:SetPoint("TOPLEFT")
        logFrame.text:SetWidth(280)
        logFrame.text:SetJustifyV("TOP")
        logFrame.text:SetWordWrap(true)
        logFrame.text:SetNonSpaceWrap(true)
        logFrame.text:SetSpacing(4)
    end
    if logFrame:IsShown() then logFrame:Hide() return end
    logFrame:ClearAllPoints()
    logFrame:SetPoint("TOPLEFT", window, "TOPRIGHT", TAB_STEP + 8, 0)
    logFrame:Show()
    QueryGuildEventLog()
    UpdateLog()
end

-- Spieleinstellungen ----------------------------------------------------------------------------

local prefs = { stagedLocale = 0, stagedDatacenter = 0 }

local function LockoutSeconds(lastChange, cooldownDays)
    if not lastChange or lastChange <= 0 then return 0 end
    return math.max(0, lastChange + (cooldownDays or 0) * 86400 - time())
end

local function PrefsAvailable()
    local canLocale, canDatacenter = C_GuildInfo.GetPreferredPlaySettingsFeatures()
    return canLocale or canDatacenter
end

local function NameFor(ids, names, id)
    for index, value in ipairs(ids or {}) do
        if value == id then return names and names[index] or tostring(id) end
    end
    return ""
end

local function RefreshPrefs()
    if not prefs.view then return end
    local loaded, localeID, datacenterID, lastLocale, lastDatacenter, cooldown = C_GuildInfo.GetPreferredPlaySettings()
    if prefs.stagedLocale == 0 then prefs.stagedLocale = localeID or 0 end
    if prefs.stagedDatacenter == 0 then prefs.stagedDatacenter = datacenterID or 0 end
    local canLocale, canDatacenter = C_GuildInfo.GetPreferredPlaySettingsFeatures()
    local isLeader = IsGuildLeader()
    local localeIDs, localeNames = C_AccountServices.GetPreferredLocales()
    local dcIDs, dcNames = C_AccountServices.GetPreferredDatacenterLocalities()
    prefs.localeGroup:SetShown(canLocale)
    prefs.localeButton.Text:SetText(NameFor(localeIDs, localeNames, prefs.stagedLocale))
    prefs.localeButton:SetEnabled(isLeader)
    local localeLock = LockoutSeconds(lastLocale, cooldown)
    prefs.localeApply.lockout = localeLock > 0 and PREFERRED_PLAY_SETTINGS_LOCKED_REASON_FORMAT and
        PREFERRED_PLAY_SETTINGS_LOCKED_REASON_FORMAT:format(SecondsToTime(localeLock)) or nil
    local canApplyLocale = isLeader and loaded and localeLock == 0 and prefs.stagedLocale ~= localeID
    prefs.localeApply:SetEnabled(canApplyLocale)
    prefs.localeApply:SetAlpha(canApplyLocale and 1 or 0.45)
    prefs.dcGroup:SetShown(canDatacenter)
    prefs.dcGroup:ClearAllPoints()
    prefs.dcGroup:SetPoint("TOPLEFT", 0, canLocale and -110 or -46)
    prefs.dcButton.Text:SetText(NameFor(dcIDs, dcNames, prefs.stagedDatacenter))
    prefs.dcButton:SetEnabled(isLeader)
    local dcLock = LockoutSeconds(lastDatacenter, cooldown)
    prefs.dcApply.lockout = dcLock > 0 and PREFERRED_PLAY_SETTINGS_LOCKED_REASON_FORMAT and
        PREFERRED_PLAY_SETTINGS_LOCKED_REASON_FORMAT:format(SecondsToTime(dcLock)) or nil
    local canApplyDC = isLeader and loaded and dcLock == 0 and prefs.stagedDatacenter ~= datacenterID
    prefs.dcApply:SetEnabled(canApplyDC)
    prefs.dcApply:SetAlpha(canApplyDC and 1 or 0.45)
end

local function CreatePrefsView(view)
    local UI = ns.UI
    prefs.view = view
    local title = UI.Text(view, 16, "LEFT")
    title:SetPoint("TOPLEFT", 4, -8)
    title:SetText(PREFERRED_PLAY_SETTINGS or L["Preferred play settings"])
    local function Group(label, pick, apply)
        local group = CreateFrame("Frame", nil, view)
        group:SetSize(420, 56)
        local text = UI.Text(group, 12, "LEFT", UI.ACCENT)
        text:SetPoint("TOPLEFT", 4, 0)
        text:SetText(label)
        local button = Dropdown(group, 220, pick)
        button:SetPoint("TOPLEFT", 4, -20)
        local applyButton = UI.Button(group, APPLY or L["Apply"], apply, 110)
        applyButton:SetHeight(28)
        applyButton:SetPoint("LEFT", button, "RIGHT", 6, 0)
        applyButton:SetMotionScriptsWhileDisabled(true)
        applyButton:HookScript("OnEnter", function(self)
            if self.lockout then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.lockout, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        applyButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
        return group, button, applyButton
    end
    prefs.localeGroup, prefs.localeButton, prefs.localeApply = Group(PREFERRED_LOCALE_LABEL or L["Preferred online language"], function(self)
        local ids, names = C_AccountServices.GetPreferredLocales()
        local items = {}
        for index, id in ipairs(ids or {}) do items[#items + 1] = { value = id, label = names and names[index] or tostring(id) } end
        UI.OpenList(self, items, prefs.stagedLocale, function(id) prefs.stagedLocale = id RefreshPrefs() end)
    end, function()
        local _, localeID = C_GuildInfo.GetPreferredPlaySettings()
        if prefs.stagedLocale ~= localeID then C_GuildInfo.SetPreferredPlaySettings(prefs.stagedLocale, 0) end
    end)
    prefs.localeGroup:SetPoint("TOPLEFT", 0, -46)
    prefs.dcGroup, prefs.dcButton, prefs.dcApply = Group(PREFERRED_GUILD_DATACENTER_LOCALITY_LABEL or L["Preferred guild location"], function(self)
        local ids, names = C_AccountServices.GetPreferredDatacenterLocalities()
        local items = {}
        for index, id in ipairs(ids or {}) do items[#items + 1] = { value = id, label = names and names[index] or tostring(id) } end
        UI.OpenList(self, items, prefs.stagedDatacenter, function(id) prefs.stagedDatacenter = id RefreshPrefs() end)
    end, function()
        local _, _, datacenterID = C_GuildInfo.GetPreferredPlaySettings()
        if prefs.stagedDatacenter ~= datacenterID then C_GuildInfo.SetPreferredPlaySettings(0, prefs.stagedDatacenter) end
    end)
end

-- Tabs, Fuß, Layout -----------------------------------------------------------------------------

local TABS = {
    { key = "chat", icon = "Interface\\Icons\\UI_Chat", tip = "COMMUNITIES_CHAT_TAB_TOOLTIP", fallback = "Chat" },
    { key = "roster", icon = "Interface\\Icons\\achievement_guildperk_everybodysfriend", tip = "COMMUNITIES_ROSTER_TAB_TOOLTIP", fallback = "Roster" },
    { key = "info", icon = "Interface\\Icons\\inv_misc_scrollunrolled01", tip = "COMMUNITIES_GUILD_INFO_TAB_TOOLTIP", fallback = "Guild Info", guild = true },
    { key = "prefs", icon = "Interface\\Icons\\inv_misc_map02", tip = "PREFERRED_PLAY_SETTINGS", fallback = "Preferred play settings", guild = true, available = PrefsAvailable },
}

local function TabAvailable(def)
    if def.guild and not IsGuildClub() then return false end
    if def.available and not def.available() then return false end
    return true
end

local function Layout()
    pending = false
    if not window or not window:IsShown() then return end
    LayoutClubList()
    if not selectedClubId then
        selectedClubId = C_Club.GetGuildClubId() or (SortedClubs()[1] and SortedClubs()[1].clubId)
    end
    local clubInfo = ClubInfo()
    -- Kopf
    local list = Members(selectedClubId)
    window.npcName:SetText(clubInfo and clubInfo.name or (GUILD or ""))
    window.npcTitle:SetText(L["Guild & Communities"] .. "  ·  " .. L["%d of %d online"]:format(CountOnline(list), #list))
    if clubInfo then SetClubIcon(emblem, emblemBg, clubInfo) end
    -- Tabs: nicht verfügbare ausblenden, dann ggf. auf Chat zurück
    if compact then currentTab = "chat" end
    local y = 60
    for i, def in ipairs(TABS) do
        local button = tabs[i]
        local available = TabAvailable(def) and not compact
        button:SetShown(available)
        if available then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, -y)
            y = y + TAB_STEP
        elseif def.key == currentTab then
            currentTab = "chat"
        end
    end
    for i, def in ipairs(TABS) do
        local active = def.key == currentTab
        for _, edge in ipairs(tabs[i].active) do edge:SetShown(active) end
        tabs[i].icon:SetDesaturated(not active)
        tabs[i].icon:SetAlpha(active and 1 or 0.75)
    end
    for key, view in pairs(views) do view:SetShown(key == currentTab) end
    -- Inhalt
    local footer, buttonText, buttonAction = "", nil, nil
    if currentTab == "chat" then
        RefreshChat()
        local privileges = selectedClubId and C_Club.GetClubPrivileges(selectedClubId)
        if privileges and privileges.canSendInvitation then
            buttonText, buttonAction = COMMUNITIES_INVITE_MANAGER_BUTTON_TEXT or L["Invite member"], function()
                -- Gilde: eigener Dialog mit sicherem /ginvite (Blizzards Dialog wird aus Addon-Fenstern
                -- blockiert, Benny 2026-11-08); andere Communities: Blizzards Dialog (nicht geschützt)
                if IsGuildClub() and ns.OpenGuildInvite then
                    ns.OpenGuildInvite()
                else
                    CommunitiesUtil.OpenInviteDialog(selectedClubId, SelectedStream())
                end
            end
        end
    elseif currentTab == "roster" then
        RefreshRoster()
        footer = roster.footer or ""
        if IsGuildClub() and (IsGuildLeader() or (C_Discord and C_Discord.IsEnabled and C_Discord.IsEnabled() and C_GuildInfo.IsGuildOfficer())) then
            buttonText, buttonAction = GUILD_CONTROL_BUTTON_TEXT or L["Guild settings"], function() ns.ToggleGuildControl() end
        end
    elseif currentTab == "info" then
        RefreshInfo()
        buttonText, buttonAction = L["View log"], ToggleLog
    elseif currentTab == "prefs" then
        RefreshPrefs()
    end
    footerText:SetText(footer)
    footerButton:SetShown(buttonText ~= nil)
    if buttonText then
        footerButton.Text:SetText(buttonText)
        footerButton:SetWidth(math.max(150, footerButton.Text:GetUnboundedStringWidth() + 28))
        footerButton.action = buttonAction
    end
    if ns.RefreshGuildMemberDetail then ns.RefreshGuildMemberDetail() end
end

function ns.RefreshGuild()
    if pending or not window then return end
    pending = true
    C_Timer.After(0, Layout)
end

function ns.SelectGuildClub(clubId)
    if clubId == selectedClubId then return end
    selectedClubId = clubId
    if ns.HideGuildMemberDetail then ns.HideGuildMemberDetail() end
    if window and window:IsShown() then
        C_Club.SetClubPresenceSubscription(clubId)
        if clubId == C_Club.GetGuildClubId() then C_GuildInfo.GuildRoster() end
    end
    ns.RefreshGuild()
end

local function SelectTab(key)
    local fromOther = currentTab ~= key
    currentTab = key
    if key == "chat" and fromOther and window and window:IsShown() then C_Timer.After(0, DisplayChat) end
    if ns.HideGuildMemberDetail then ns.HideGuildMemberDetail() end
    if key == "info" then
        C_Calendar.OpenCalendar()
        QueryGuildNews()
        GuildNewsSort(0)
    elseif key == "prefs" then
        prefs.stagedLocale, prefs.stagedDatacenter = 0, 0
        C_GuildInfo.RequestPreferredPlaySettings()
    elseif key == "roster" then
        if IsGuildClub() then C_GuildInfo.GuildRoster() end
    end
    ns.RefreshGuild()
end

local function SetCompact(on)
    compact = on
    window:SetWidth(compact and COMPACT_WIDTH or WIDTH)
    views.chat:ClearAllPoints()
    views.chat:SetPoint("TOPLEFT", compact and PAD or CONTENT_X, -TOP)
    views.chat:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM)
    minimizeButton.icon:SetRotation(compact and math.pi or 0)
    window.extraRight = compact and 0 or TAB_STEP
    ns.RefreshGuild()
end

local function CreateWindow()
    local UI = ns.UI
    LoadBlizzard()
    window = ns.CreateNpcWindow("MeredanUIGuild", WIDTH, ns.NPC_HEIGHT, "guild")
    window.extraRight = TAB_STEP

    -- Wappen über dem Porträt-Platz
    local holder = CreateFrame("Frame", nil, window.header)
    holder:SetSize(46, 46)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    holder:SetFrameLevel(window.header:GetFrameLevel() + 5)
    ns.AddBorder(holder)
    emblemBg = holder:CreateTexture(nil, "BACKGROUND")
    emblemBg:SetAllPoints()
    emblem = holder:CreateTexture(nil, "ARTWORK")
    emblem:SetPoint("CENTER")
    emblem:SetSize(42, 42)

    -- Verkleinern (nur Chat) links vom Schließen
    minimizeButton = UI.IconButton(window.header, "ChevronDown", function() SetCompact(not compact) end, 26)
    minimizeButton:SetPoint("RIGHT", window.close, "LEFT", -6, 0)
    minimizeButton.icon:SetRotation(0)
    Tooltip(minimizeButton, function() return compact and L["Maximize"] or L["Minimize: chat only"] end, "ANCHOR_BOTTOM")

    -- Tabs rechts
    for i, def in ipairs(TABS) do
        local button = CreateFrame("Button", nil, window)
        button:SetSize(TAB_SIZE, TAB_SIZE)
        UI.Box(button, ns.STYLE.panelColor)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetTexture(def.icon)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.active = ns.AddBorder(button, true, 2)
        for _, edge in ipairs(button.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(G(def.tip, def.fallback), 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            SelectTab(def.key)
        end)
        tabs[i] = button
    end

    -- Ansichten
    for _, def in ipairs(TABS) do
        local view = CreateFrame("Frame", nil, window)
        view:SetPoint("TOPLEFT", CONTENT_X, -TOP)
        view:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM)
        view:Hide()
        views[def.key] = view
    end
    CreateChatView(views.chat)
    CreateRosterView(views.roster)
    CreateInfoView(views.info)
    CreatePrefsView(views.prefs)

    -- Fuß
    footerText = UI.Text(window, 12, "LEFT", UI.MUTED)
    footerText:SetPoint("BOTTOMLEFT", PAD, 20)
    footerButton = UI.Button(window, "", function(self) if self.action then self.action() end end, 150)
    footerButton:SetHeight(28)
    footerButton:SetPoint("BOTTOMRIGHT", -PAD, 14)

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        if not selectedClubId then selectedClubId = C_Club.GetGuildClubId() end
        if selectedClubId then C_Club.SetClubPresenceSubscription(selectedClubId) end
        if IsInGuild() then C_GuildInfo.GuildRoster() end
        local streamId = SelectedStream()
        if streamId then FocusStream(selectedClubId, streamId) end
        Layout()
        -- wie Blizzard: beim Öffnen den Chat frisch holen (alte Zeilen haben abgelaufene Text-Codes)
        if currentTab == "chat" then DisplayChat() end
        if UpdateMicroButtons then UpdateMicroButtons() end
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        ns.UI.CloseList()
        if ns.HideGuildMemberDetail then ns.HideGuildMemberDetail() end
        if logFrame then logFrame:Hide() end
        C_Club.ClearClubPresenceSubscription()
        C_Club.ClearAutoAdvanceStreamViewMarker()
        C_Club.Flush()
        FocusStream(nil, nil)
        if UpdateMicroButtons then UpdateMicroButtons() end
    end)
end

local function Toggle(tabKey)
    if not window then CreateWindow() end
    if window:IsShown() and (not tabKey or tabKey == currentTab) then
        window:Hide()
        return
    end
    if tabKey then SelectTab(tabKey) end
    window:Show()
end
ns.ToggleGuild = Toggle
function ns.GuildWindow() return window end

-- Öffnen und Ereignisse -------------------------------------------------------------------------

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end

    -- Taste J (Gilde & Communitys) und alle Blizzard-Öffner auf unser Fenster
    local button = CreateFrame("Button", "MeredanUIGuildToggle", UIParent)
    button:SetScript("OnClick", function() Toggle() end)
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        ClearOverrideBindings(button)
        for _, key in ipairs({ GetBindingKey("TOGGLEGUILDTAB") }) do
            SetOverrideBindingClick(button, false, key, "MeredanUIGuildToggle", "LeftButton")
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)

    local function Open()
        if IsCommunitiesUIDisabledByTrialAccount and IsCommunitiesUIDisabledByTrialAccount() then
            UIErrorsFrame:AddMessage(ERR_RESTRICTED_ACCOUNT_TRIAL, 1.0, 0.1, 0.1, 1.0)
            return
        end
        if not BNConnected() then
            UIErrorsFrame:AddMessage(ERR_GUILD_AND_COMMUNITIES_UNAVAILABLE, 1.0, 0.1, 0.1, 1.0)
            return
        end
        Toggle()
    end
    -- Blizzards Original merken: Notizen, Nachricht des Tages, Gildeninfo und Ränge darf seit Midnight
    -- (Hotfix März 2026) nur noch Blizzards eigenes Gildenfenster schreiben (geschützt für Addons)
    -- (Blizzards ToggleGuildFrame ruft intern ToggleCommunitiesFrame auf – das zeigt auf mUI; darum
    -- Blizzards Fenster direkt öffnen)
    function ns.OpenBlizzardGuild()
        if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
        if window and window:IsShown() then window:Hide() end
        if not C_AddOns.IsAddOnLoaded("Blizzard_Communities") then C_AddOns.LoadAddOn("Blizzard_Communities") end
        if CommunitiesFrame then ShowUIPanel(CommunitiesFrame) end
        ns.Print(L["Edit it in Blizzard's guild window – addons are not allowed to change this."])
    end
    ToggleGuildFrame = Open
    ToggleCommunitiesFrame = Open
    -- Blizzards Communities-Addon definiert ToggleCommunitiesFrame beim Laden neu
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Communities", function() ToggleCommunitiesFrame = Open end)

    local function Update() if window and window:IsShown() then ns.RefreshGuild() end end
    for _, event in ipairs({ "CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED", "CLUB_MEMBER_UPDATED",
        "CLUB_MEMBER_PRESENCE_UPDATED", "CLUB_MEMBER_ROLE_UPDATED", "CLUB_ADDED", "CLUB_REMOVED", "CLUB_UPDATED",
        "CLUB_STREAMS_LOADED", "CLUB_STREAM_ADDED", "CLUB_STREAM_REMOVED", "CLUB_STREAM_UPDATED",
        "STREAM_VIEW_MARKER_UPDATED", "GUILD_ROSTER_UPDATE", "GUILD_MOTD", "GUILD_NEWS_UPDATE", "GUILD_RANKS_UPDATE",
        "PLAYER_GUILD_UPDATE", "GUILD_PREFERRED_PLAY_SETTINGS_UPDATED", "CALENDAR_UPDATE_GUILD_EVENTS" }) do
        ns:On(event, Update)
    end
    ns:On("GUILD_EVENT_LOG_UPDATE", UpdateLog)
    ns:On("CLUB_MESSAGE_ADDED", function(_, clubId, streamId, messageId)
        if not (window and window:IsShown()) or clubId ~= selectedClubId or streamId ~= SelectedStream() then return end
        local message = C_Club.GetMessageInfo(clubId, streamId, messageId)
        if message then AddMessage(message) end
    end)
    ns:On("CLUB_MESSAGE_HISTORY_RECEIVED", function(_, clubId, streamId)
        chat.requested = false
        if not (window and window:IsShown()) or clubId ~= selectedClubId or streamId ~= SelectedStream() then return end
        if chat.messages and chat.messages:GetNumMessages() > 0 and chat.oldest then BackfillMessages() else DisplayChat() end
    end)
    -- CLUB_MESSAGE_UPDATED (bearbeitet/gelöscht): nicht alles neu zeichnen – das würde alle
    -- geschützten Text-Codes neu holen; die Änderung erscheint beim nächsten Öffnen
end)
