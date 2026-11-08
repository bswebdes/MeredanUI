-- Gildenfenster, Teil 2: Mitglieder-Details (Klappe rechts) und Gildeneinstellungen (Ränge,
-- Rangrechte, Bankfachrechte, Discord) – wie Blizzards GuildMemberDetailFrame und GuildControlUI,
-- nach Bennys Screenshots (2026-11-07). Aktionen über dieselben Aufrufe und Dialoge wie Blizzard.
local _, ns = ...
local L = ns.L

local TAB_STEP = 46
local P = ns.Plain
local MAX_RANKS = 10

local function Window(name, width, height, title)
    local UI = ns.UI
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    UI.Box(frame, ns.STYLE.panelColor)
    local accent = frame:CreateTexture(nil, "OVERLAY")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    tinsert(UISpecialFrames, name)
    frame.close = UI.IconButton(frame, "Close", function() frame:Hide() end, 22)
    frame.close:SetPoint("TOPRIGHT", -14, -14)
    if title then
        frame.title = UI.Text(frame, 15, "LEFT")
        frame.title:SetPoint("TOPLEFT", 16, -18)
        frame.title:SetText(title)
    end
    return frame
end

local function Panel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    ns.UI.Box(panel, { 0.098, 0.098, 0.106, 1 })
    return panel
end

-- Mitglieder-Details ----------------------------------------------------------------------------

local detail
local detailClub, detailMember

local function MemberInfo()
    if detailClub and detailMember then return C_Club.GetMemberInfo(detailClub, detailMember) end
end

local function NoteBox(parent, label)
    local UI = ns.UI
    local title = UI.Text(parent, 12, "LEFT", UI.ACCENT)
    title:SetText(label)
    local box = CreateFrame("Button", nil, parent)
    box:SetHeight(40)
    local bg = UI.Box(box, { 0.098, 0.098, 0.106, 1 })
    box.text = UI.Text(box, 12, "LEFT")
    box.text:SetPoint("TOPLEFT", 8, -6)
    box.text:SetPoint("BOTTOMRIGHT", -8, 6)
    box.text:SetJustifyV("TOP")
    box.text:SetWordWrap(true)
    box.edit = UI.Icon(box, "Edit", 12, UI.MUTED)
    box.edit:SetPoint("TOPRIGHT", -6, -6)
    box:SetScript("OnEnter", function(self) if self:IsEnabled() then bg:SetColorTexture(unpack(UI.HOVER)) end end)
    box:SetScript("OnLeave", function() bg:SetColorTexture(0.098, 0.098, 0.106, 1) end)
    box.title = title
    return box
end

local function OpenRankMenu(owner)
    local memberInfo = MemberInfo()
    local mine = detailClub and C_Club.GetMemberInfoForSelf(detailClub)
    local memberRank, myRank, guid = memberInfo and P(memberInfo.guildRankOrder), mine and P(mine.guildRankOrder), memberInfo and P(memberInfo.guid)
    if not (memberRank and myRank and guid) then return end
    local highest = CanGuildPromote() and (myRank + 1) or memberRank
    local lowest = CanGuildDemote() and GuildControlGetNumRanks() or memberRank
    local items = {}
    for rank = highest, lowest do
        local allowed = C_GuildInfo.IsGuildRankAssignmentAllowed(guid, rank)
        items[#items + 1] = { value = rank, label = allowed and GuildControlGetRankName(rank)
            or ("|cff77756e" .. GuildControlGetRankName(rank) .. "|r"), inert = not allowed }
    end
    -- SetGuildRankOrder ist für Addons geschützt (seit Midnight), Befördern/Degradieren nicht:
    -- Schritt für Schritt bis zum gewählten Rang (kleiner Abstand, damit der Server mitkommt)
    local name = memberInfo and P(memberInfo.name)
    ns.UI.OpenList(owner, items, memberRank, function(rank)
        if rank == memberRank or not name then return end
        local step = rank < memberRank and C_GuildInfo.Promote or C_GuildInfo.Demote
        for i = 1, math.abs(rank - memberRank) do
            C_Timer.After((i - 1) * 0.3, function() step(name) end)
        end
    end)
end

local function CreateDetail()
    local UI = ns.UI
    detail = Window("MeredanUIGuildMember", 280, 330)
    detail:SetFrameStrata("HIGH")
    detail.name = UI.Text(detail, 15, "LEFT")
    detail.name:SetPoint("TOPLEFT", 16, -16)
    detail.name:SetPoint("RIGHT", -44, 0)
    detail.name:SetWordWrap(false)
    detail.level = UI.Text(detail, 12, "LEFT", UI.MUTED)
    detail.level:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -5)

    local function Label(text, y)
        local label = UI.Text(detail, 12, "LEFT", UI.ACCENT)
        label:SetPoint("TOPLEFT", 16, y)
        label:SetText(text)
        local value = UI.Text(detail, 12, "LEFT")
        value:SetPoint("TOPLEFT", 108, y)
        value:SetPoint("RIGHT", -16, 0)
        value:SetWordWrap(false)
        return label, value
    end
    detail.zoneLabel, detail.zone = Label(ZONE_COLON and (ZONE_COLON:gsub(":%s*$", "")) or L["Zone"], -66)
    detail.rankLabel = UI.Text(detail, 12, "LEFT", UI.ACCENT)
    detail.rankLabel:SetPoint("TOPLEFT", 16, -96)
    detail.rankLabel:SetText(RANK or L["Rank"])
    detail.rankButton = ns.GuildDropdown(detail, 156, function(self) OpenRankMenu(self) end)
    detail.rankButton:SetPoint("TOPLEFT", 100, -88)
    detail.rankText = UI.Text(detail, 12, "LEFT")
    detail.rankText:SetPoint("TOPLEFT", 108, -96)
    detail.onlineLabel, detail.online = Label(L["Last online"], -126)

    detail.note = NoteBox(detail, L["Note"])
    detail.note.title:SetPoint("TOPLEFT", 16, -154)
    detail.note:SetPoint("TOPLEFT", 16, -172)
    detail.note:SetPoint("RIGHT", -16, 0)
    detail.note:SetScript("OnClick", function()
        local info = MemberInfo()
        local guid = info and P(info.guid)
        if guid then
            ns.OpenBlizzardGuild() -- C_GuildInfo.SetNote ist für Addons geschützt (seit Midnight)
        end
    end)
    detail.officer = NoteBox(detail, L["Officer note"])
    detail.officer.title:SetPoint("TOPLEFT", detail.note, "BOTTOMLEFT", 0, -10)
    detail.officer:SetPoint("TOPLEFT", detail.officer.title, "BOTTOMLEFT", 0, -6)
    detail.officer:SetPoint("RIGHT", -16, 0)
    detail.officer:SetScript("OnClick", function()
        local info = MemberInfo()
        local guid = info and P(info.guid)
        if guid then
            ns.OpenBlizzardGuild()
        end
    end)

    detail.remove = UI.Button(detail, REMOVE or L["Remove"], function()
        local info = MemberInfo()
        local name, guid = info and P(info.name), info and P(info.guid)
        -- Blizzards REMOVE_GUILDMEMBER nutzt RemoveFromGuild (für Addons geschützt) – eigener Dialog mit
        -- C_GuildInfo.Uninvite (erlaubt)
        if name and guid then StaticPopup_Show("MEREDANUI_GUILD_REMOVE", name, nil, name) end
    end, 120)
    detail.remove:SetHeight(28)
    detail.remove:SetPoint("BOTTOMLEFT", 16, 16)
    detail.remove:SetMotionScriptsWhileDisabled(true)
    detail.invite = UI.Button(detail, GROUP_INVITE or L["Group invite"], function()
        local info = MemberInfo()
        local name = info and P(info.name)
        if name then C_PartyInfo.InviteUnit(name) end
    end, 120)
    detail.invite:SetHeight(28)
    detail.invite:SetPoint("BOTTOMRIGHT", -16, 16)
    detail.invite:SetMotionScriptsWhileDisabled(true)
    detail:HookScript("OnHide", function()
        detailMember = nil
        ns.RefreshGuild()
    end)
end

local function SetButtonEnabled(button, on)
    button:SetEnabled(on)
    button:SetAlpha(on and 1 or 0.45)
end

function ns.RefreshGuildMemberDetail()
    if not (detail and detail:IsShown()) then return end
    local UI = ns.UI
    local info = MemberInfo()
    local mine = detailClub and C_Club.GetMemberInfoForSelf(detailClub)
    if not (info and P(info.name) and P(info.guildRankOrder) and mine and P(mine.guildRankOrder)) then
        detail:Hide()
        return
    end
    detail.name:SetText(P(info.name))
    local classID = P(info.classID)
    local classInfo = classID and C_CreatureInfo.GetClassInfo(classID)
    local color = classInfo and RAID_CLASS_COLORS[classInfo.classFile]
    if color then detail.name:SetTextColor(color.r, color.g, color.b) else detail.name:SetTextColor(unpack(UI.TEXT)) end
    detail.level:SetText(classInfo and FRIENDS_LEVEL_TEMPLATE:format(P(info.level) or 0, classInfo.className) or "")
    detail.zone:SetText(P(info.zone) or "")
    local lastHour = P(info.lastOnlineHour)
    if lastHour == nil then
        detail.online:SetText(GUILD_ONLINE_LABEL or L["Online"])
    else
        detail.online:SetText(TimeUtil.GetRecentTimeDate(P(info.lastOnlineYear) or 0, P(info.lastOnlineMonth) or 0,
            P(info.lastOnlineDay) or 0, lastHour))
    end
    -- Rang: Auswahl nur, wenn befördern/degradieren erlaubt (wie Blizzard)
    local maxRank, myRank, rank = GuildControlGetNumRanks(), P(mine.guildRankOrder), P(info.guildRankOrder)
    local canPromote = CanGuildPromote() and rank > myRank + 1
    local canDemote = CanGuildDemote() and rank < maxRank and rank > myRank
    detail.rankButton:SetShown(canPromote or canDemote)
    detail.rankText:SetShown(not (canPromote or canDemote))
    detail.rankButton.Text:SetText(P(info.guildRank) or "")
    detail.rankText:SetText(P(info.guildRank) or "")
    -- Notizen
    local note = P(info.memberNote)
    local canEdit = info.isSelf or CanEditPublicNote()
    if canEdit and (not note or note == "") then note = GUILD_NOTE_EDITLABEL or L["Click here to set a note."] end
    detail.note.text:SetText(note or "")
    detail.note.text:SetTextColor(unpack(canEdit and UI.TEXT or { 0.65, 0.65, 0.65 }))
    detail.note:SetEnabled(canEdit)
    detail.note.edit:SetShown(canEdit)
    local canView = C_GuildInfo.CanViewOfficerNote()
    detail.officer:SetShown(canView)
    detail.officer.title:SetShown(canView)
    if canView then
        local officerNote = P(info.officerNote)
        local canEditOfficer = C_GuildInfo.CanEditOfficerNote()
        if canEditOfficer and (not officerNote or officerNote == "") then officerNote = GUILD_OFFICERNOTE_EDITLABEL or L["Click here to set a note."] end
        detail.officer.text:SetText(officerNote or "")
        detail.officer.text:SetTextColor(unpack(canEditOfficer and UI.TEXT or { 0.65, 0.65, 0.65 }))
        detail.officer:SetEnabled(canEditOfficer)
        detail.officer.edit:SetShown(canEditOfficer)
    end
    detail:SetHeight(canView and 330 or 270)
    SetButtonEnabled(detail.remove, CanGuildRemove() and rank > myRank)
    local presence = P(info.presence)
    SetButtonEnabled(detail.invite, lastHour == nil and not P(info.isRemoteChat) and presence ~= Enum.ClubMemberPresence.OnlineMobile)
end

function ns.ShowGuildMemberDetail(clubId, memberId)
    if not detail then CreateDetail() end
    if detail:IsShown() and detailMember == memberId then
        detail:Hide()
        return
    end
    detailClub, detailMember = clubId, memberId
    local window = ns.GuildWindow()
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", window, "TOPRIGHT", TAB_STEP + 8, -60)
    detail:Show()
    ns.RefreshGuildMemberDetail()
    ns.RefreshGuild()
end

function ns.HideGuildMemberDetail()
    if detail then detail:Hide() end
end

function ns.GuildDetailMember()
    return detail and detail:IsShown() and detailMember or nil
end

-- Gildeneinstellungen ---------------------------------------------------------------------------

local control
local mode -- "ranks", "perms", "bank", "discord"
local currentRank = 2
local discord = { server = -1, channel = -1 }

local OFFICER_STRINGS = { "GUILD_OFFICER_PERMISSION_ACCESS_CHANNELS", "GUILD_OFFICER_PERMISSION_REMOVE_FROM_VOICE",
    "GUILD_OFFICER_PERMISSION_DELETE_MESSAGES", "GUILD_OFFICER_PERMISSION_DELETE_EVENTS",
    "GUILD_OFFICER_PERMISSION_OFFICER_NOTES", "GUILD_OFFICER_PERMISSION_PUBLIC_NOTES", "GUILD_OFFICER_PERMISSION_GUILD_INFO",
    "GUILD_OFFICER_PERMISSION_MOTD", "GUILD_OFFICER_PERMISSION_FINDER_LIST", "GUILD_OFFICER_PERMISSION_INVITE_APPLICANTS",
    "GUILD_OFFICER_PERMISSION_SET_DISCORD" }
local BASE_FLAGS = { 5, 6, 7, 8, 2, 21 }   -- Befördern, Rückstufen, Einladen, Entfernen, Gildenchat, Rekrutierung
local BANK_FLAGS = { 15, 19, 16 }          -- Reparatur, Bankreiter ändern, Gold abheben
local AUTH_FLAG, OFFICER_FLAG = 18, 22

local function Modes()
    local list = {}
    if IsGuildLeader() then
        list[#list + 1] = { value = "ranks", label = GUILDCONTROL_GUILDRANKS or L["Guild ranks"] }
        list[#list + 1] = { value = "perms", label = GUILDCONTROL_RANK_PERMISSIONS or L["Rank permissions"] }
        if C_GuildBank.IsGuildBankEnabled() then
            list[#list + 1] = { value = "bank", label = GUILDCONTROL_BANK_PERMISSIONS or L["Bank tab permissions"] }
        end
    end
    if C_Discord and C_Discord.IsEnabled() then
        list[#list + 1] = { value = "discord", label = GUILDCONTROL_DISCORD_SETTINGS
            and GUILDCONTROL_DISCORD_SETTINGS:format(CreateAtlasMarkup("UI-ChatIcon-Discord")) or L["Discord settings"] }
    end
    return list
end

local function ModeLabel(value)
    for _, entry in ipairs(Modes()) do
        if entry.value == value then return entry.label end
    end
    return ""
end

local function ClampRank()
    if currentRank < 2 or currentRank > GuildControlGetNumRanks() then currentRank = 2 end
    GuildControlSetRank(currentRank)
end

-- Gildenränge
local function RefreshRanks()
    local UI = ns.UI
    local page = control.pages.ranks
    local numRanks = GuildControlGetNumRanks()
    for i = 1, MAX_RANKS do
        local row = page.rows[i]
        row:SetShown(i <= numRanks)
        if i <= numRanks then
            row.label:SetText((RANK or L["Rank"]) .. " " .. i .. ":")
            if not row.name:HasFocus() then row.name:SetText(GuildControlGetRankName(i) or "") end
            local canUp, canDown, canDelete = false, false, false
            if numRanks > 2 and i > 1 then
                canDelete = GetNumMembersInRank(i) == 0
                if canDelete and i == numRanks and C_GuildInfo.GuildControlGetRankFlags(i - 1)[AUTH_FLAG] then canDelete = false end
                canUp, canDown = GuildControlGetAllowedShifts(i)
            end
            row.up:SetEnabled(canUp and true or false)
            row.down:SetEnabled(canDown and true or false)
            row.delete:SetEnabled(canDelete)
            row.delete.icon:SetVertexColor(unpack(canDelete and { 0.9, 0.76, 0.29 } or UI.MUTED))
            if i > 1 or IsGuildLeader() then row.name:Enable() else row.name:Disable() end
        end
    end
    page.new:SetShown(numRanks < MAX_RANKS)
end

local function CreateRanksPage(page)
    local UI = ns.UI
    page.rows = {}
    for i = 1, MAX_RANKS do
        local row = CreateFrame("Frame", nil, page)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 34)
        row:SetPoint("RIGHT")
        row.label = UI.Text(row, 12, "RIGHT", UI.ACCENT)
        row.label:SetPoint("LEFT")
        row.label:SetWidth(56)
        row.name = UI.EditBox(row, 26)
        row.name:SetMaxLetters(15)
        row.name:SetPoint("LEFT", 64, 0)
        row.name:SetWidth(150)
        row.name:SetScript("OnEditFocusGained", function(self) self.startName = self:GetText() end)
        row.name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        row.name:SetScript("OnEscapePressed", function(self)
            self:SetText(self.startName or "")
            self:ClearFocus()
        end)
        row.name:HookScript("OnEditFocusLost", function(self)
            local text = self:GetText()
            if self.startName and self.startName ~= text and text ~= "" then
                GuildControlSetRank(i)
                GuildControlSaveRank(text)
            elseif self.startName then
                self:SetText(self.startName)
            end
            self.startName = nil
        end)
        row.up = UI.ArrowButton(row, "left", function()
            GuildControlShiftRankUp(i)
        end, 24)
        row.up.icon:SetRotation(math.pi)
        row.up:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
        row.down = UI.ArrowButton(row, "right", function()
            GuildControlShiftRankDown(i)
        end, 24)
        row.down.icon:SetRotation(0)
        row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)
        row.delete = UI.IconButton(row, "Phase", function() GuildControlDelRank(i) end, 24)
        row.delete:SetPoint("LEFT", row.down, "RIGHT", 14, 0)
        row.delete:SetMotionScriptsWhileDisabled(true)
        row.delete:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self:IsEnabled() then
                GameTooltip:SetText(GUILDREMOVERANK_BUTTON_TOOLTIP or L["Remove rank"], 1, 1, 1)
            else
                GameTooltip:SetText(ERR_GUILD_RANK_IN_USE or L["Rank in use"], 1, 1, 1, 1, true)
            end
            GameTooltip:Show()
        end)
        row.delete:HookScript("OnLeave", function() GameTooltip:Hide() end)
        hooksecurefunc(row.delete, "SetEnabled", function(self, on) self:SetAlpha(on and 1 or 0.5) end)
        page.rows[i] = row
    end
    page.new = UI.Button(page, "+  " .. (GUILD_NEW_RANK or L["New rank"]), function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        GuildControlAddRank(GUILD_NEW_RANK or L["New rank"])
    end, 140)
    page.new:SetHeight(28)
    page.new:SetPoint("BOTTOMLEFT")
end

-- Rangrechte
local function RefreshPerms()
    local page = control.pages.perms
    ClampRank()
    local flags = C_GuildInfo.GuildControlGetRankFlags(currentRank) or {}
    page.auth:SetChecked(flags[AUTH_FLAG])
    local numRanks = GuildControlGetNumRanks()
    local authLocked = currentRank == numRanks or (GetNumMembersInRank(currentRank) > 0 and not flags[AUTH_FLAG])
    page.auth:SetEnabled(not authLocked)
    page.auth.lockReason = currentRank == numRanks and AUTHENTICATOR_GUILD_RANK_LAST
        or authLocked and AUTHENTICATOR_GUILD_RANK_IN_USE or nil
    page.officer:SetChecked(flags[OFFICER_FLAG])
    for id, check in pairs(page.flags) do check:SetChecked(flags[id]) end
    local bank = C_GuildBank.IsGuildBankEnabled()
    page.bankBox:SetShown(bank)
    if bank then
        local goldEnabled = flags[15] or flags[16]
        page.gold:SetEnabled(goldEnabled and true or false)
        page.gold:SetAlpha(goldEnabled and 1 or 0.5)
        if not page.gold:HasFocus() then page.gold:SetText(GetGuildBankWithdrawGoldLimit() or 0) end
    end
end

local function CreatePermsPage(page)
    local UI = ns.UI
    page.flags = {}
    page.auth = ns.GuildCheck(page, GUILDCONTROL_OPTION18 or L["Requires authenticator"], function(self, on)
        if not on and GetNumMembersInRank(currentRank) > 0 then
            self:SetChecked(true)
            StaticPopup_Show("MEREDANUI_CONFIRM_AUTH_REMOVE",
                REMOVE_AUTHENTICATOR_FROM_RANK and REMOVE_AUTHENTICATOR_FROM_RANK:format(GuildControlGetRankName(currentRank)) or "")
            return
        end
        GuildControlSetRankFlag(AUTH_FLAG, on)
    end)
    page.auth:SetPoint("TOPLEFT", 0, 0)
    page.auth:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(GUILD_RANK_AUTHENTICATOR_TOOLTIP or "", 1, 1, 1, 1, true)
        if self.lockReason then GameTooltip:AddLine(self.lockReason, 1, 0.2, 0.2, true) end
        GameTooltip:Show()
    end)
    page.auth:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local officerBox = Panel(page)
    officerBox:SetPoint("TOPLEFT", 0, -28)
    officerBox:SetPoint("RIGHT")
    page.officer = ns.GuildCheck(officerBox, GUILD_CONTROL_RANK_PERMISSION_HAS_OFFICER_PRIVLEGES or L["Officer"], function(_, on)
        GuildControlSetRankFlag(OFFICER_FLAG, on)
    end)
    page.officer:SetPoint("TOPLEFT", 10, -8)
    local lines = {}
    for _, key in ipairs(OFFICER_STRINGS) do
        if _G[key] then lines[#lines + 1] = "– " .. _G[key] end
    end
    local officerText = UI.Text(officerBox, 11, "LEFT", { 0.79, 0.78, 0.75 })
    officerText:SetPoint("TOPLEFT", 32, -32)
    officerText:SetPoint("RIGHT", -10, 0)
    officerText:SetSpacing(2)
    officerText:SetText(table.concat(lines, "\n"))
    officerBox:SetHeight(44 + officerText:GetStringHeight())

    local baseBox = Panel(page)
    baseBox:SetPoint("TOPLEFT", officerBox, "BOTTOMLEFT", 0, -8)
    baseBox:SetPoint("RIGHT")
    baseBox:SetHeight(84)
    for index, id in ipairs(BASE_FLAGS) do
        local check = ns.GuildCheck(baseBox, _G["GUILDCONTROL_OPTION" .. id] or tostring(id), function(_, on)
            GuildControlSetRankFlag(id, on)
        end)
        local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
        check:SetPoint("TOPLEFT", 10 + column * 160, -10 - line * 24)
        page.flags[id] = check
    end

    page.bankBox = Panel(page)
    page.bankBox:SetPoint("TOPLEFT", baseBox, "BOTTOMLEFT", 0, -8)
    page.bankBox:SetPoint("RIGHT")
    page.bankBox:SetHeight(86)
    local bankTitle = UI.Text(page.bankBox, 12, "LEFT", UI.ACCENT)
    bankTitle:SetPoint("TOPLEFT", 10, -8)
    bankTitle:SetText(GUILD_BANK or L["Guild bank"])
    for index, id in ipairs(BANK_FLAGS) do
        local check = ns.GuildCheck(page.bankBox, _G["GUILDCONTROL_OPTION" .. id] or tostring(id), function(_, on)
            GuildControlSetRankFlag(id, on)
        end)
        local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
        check:SetPoint("TOPLEFT", 10 + column * 160, -30 - line * 24)
        page.flags[id] = check
    end
    page.gold = UI.EditBox(page.bankBox, 24)
    page.gold:SetNumeric(true)
    page.gold:SetMaxLetters(9)
    page.gold:SetWidth(70)
    page.gold:SetPoint("TOPLEFT", 170, -52)
    page.gold:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.gold:HookScript("OnEditFocusLost", function(self)
        SetGuildBankWithdrawGoldLimit(tonumber(self:GetText()) or 0)
        GuildControlSaveRank()
    end)
    local goldLabel = UI.Text(page.bankBox, 12, "LEFT", UI.MUTED)
    goldLabel:SetPoint("LEFT", page.gold, "RIGHT", 6, 0)
    goldLabel:SetText(GOLD_PER_DAY or L["(Gold/day)"])
end

-- Bankfachrechte
local function RefreshBank()
    local UI = ns.UI
    local page = control.pages.bank
    ClampRank()
    local numTabs = GetNumGuildBankTabs() or 0
    local maxTabs = MAX_BUY_GUILDBANK_TABS or 6
    local y = 0
    for i = 1, numTabs do
        local row = page.rows[i]
        if not row then
            row = Panel(page.list.child)
            row:SetHeight(74)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(30, 30)
            row.icon:SetPoint("TOPLEFT", 10, -10)
            row.name = UI.Text(row, 13, "LEFT")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
            row.name:SetWidth(120)
            row.name:SetWordWrap(false)
            row.view = ns.GuildCheck(row, GUILDCONTROL_VIEW_TAB or L["View tab"], function(_, on)
                SetGuildBankTabPermissions(row.tab, 1, on)
            end)
            row.view:SetPoint("TOPLEFT", 180, -8)
            row.deposit = ns.GuildCheck(row, GUILDCONTROL_DEPOSIT_ITEMS or L["Deposit items"], function(_, on)
                SetGuildBankTabPermissions(row.tab, 2, on)
            end)
            row.deposit:SetPoint("TOPLEFT", 180, -30)
            row.withdraw = UI.EditBox(row, 22)
            row.withdraw:SetNumeric(true)
            row.withdraw:SetMaxLetters(6)
            row.withdraw:SetWidth(54)
            row.withdraw:SetPoint("TOPLEFT", 180, -50)
            row.withdraw:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
            row.withdraw:HookScript("OnEditFocusLost", function(self)
                SetGuildBankTabItemWithdraw(row.tab, tonumber(self:GetText()) or 0)
            end)
            local label = UI.Text(row, 11, "LEFT", UI.MUTED)
            label:SetPoint("LEFT", row.withdraw, "RIGHT", 6, 0)
            label:SetText(GUILDCONTROL_WITHDRAW_ITEMS or L["Withdrawals per day"])
            page.rows[i] = row
        end
        row.tab = i
        local name, icon = GetGuildBankTabInfo(i)
        local isViewable, canDeposit, _, numWithdrawals = GetGuildBankTabPermissions(i)
        row.icon:SetTexture(icon)
        row.name:SetText(name or "")
        row.view:SetChecked(isViewable)
        row.deposit:SetChecked(canDeposit)
        row.deposit:SetEnabled(isViewable and true or false)
        row.withdraw:SetEnabled(isViewable and true or false)
        row.withdraw:SetAlpha(isViewable and 1 or 0.5)
        if not row.withdraw:HasFocus() then row.withdraw:SetText(numWithdrawals or 0) end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", page.list.child, "RIGHT")
        row:Show()
        y = y + 80
    end
    for i = numTabs + 1, #page.rows do page.rows[i]:Hide() end
    -- nächstes Fach kaufen
    local canBuy = numTabs < maxTabs
    page.buy:SetShown(canBuy)
    if canBuy then
        page.buy:ClearAllPoints()
        page.buy:SetPoint("TOPLEFT", 0, -y)
        page.buy:SetPoint("RIGHT", page.list.child, "RIGHT")
        local cost = GetGuildBankTabCost() or 0
        local affordable = (GetMoney() + (GetGuildBankMoney() or 0)) >= cost
        page.buy.cost:SetText((affordable and "|cffffffff" or "|cffe65050") .. GetMoneyString(cost, true) .. "|r")
        page.buy.button:SetEnabled(affordable)
        page.buy.button:SetAlpha(affordable and 1 or 0.45)
        y = y + 80
    end
    page.list.child:SetWidth(page.list:GetWidth())
    page.list:SetContentHeight(y)
end

local function CreateBankPage(page)
    local UI = ns.UI
    page.rows = {}
    page.list = UI.ScrollArea(page)
    page.list:SetPoint("TOPLEFT")
    page.list:SetPoint("BOTTOMRIGHT", -10, 0)
    page.buy = Panel(page.list.child)
    page.buy:SetHeight(74)
    local text = UI.Text(page.buy, 13, "CENTER")
    text:SetPoint("TOP", 0, -12)
    text:SetText(PURCHASE_TAB_TEXT or L["Purchase this guild bank tab?"])
    local costLabel = UI.Text(page.buy, 12, "LEFT", UI.ACCENT)
    costLabel:SetPoint("BOTTOMLEFT", 12, 16)
    costLabel:SetText(COSTS_LABEL or L["Cost:"])
    page.buy.cost = UI.Text(page.buy, 13, "LEFT")
    page.buy.cost:SetPoint("LEFT", costLabel, "RIGHT", 8, 0)
    page.buy.button = UI.Button(page.buy, BANKSLOTPURCHASE or L["Purchase"], function()
        StaticPopup_Show("CONFIRM_BUY_GUILDBANK_TAB")
    end, 120)
    page.buy.button:SetHeight(26)
    page.buy.button:SetPoint("BOTTOMRIGHT", -12, 10)
    page.buy.button:SetMotionScriptsWhileDisabled(true)
end

-- Discord
local function RefreshDiscord()
    local page = control.pages.discord
    local oauthed = C_Discord.IsUserOAuthed()
    local linked, channelName, serverName = C_Discord.GetGuildLinkStatus()
    page.oauth:SetShown(not oauthed)
    page.linked:SetShown(oauthed and linked)
    page.select:SetShown(oauthed and not linked)
    if oauthed and linked then
        page.linked.server:SetText(DISCORD_GUILD_LINKED_SERVER and DISCORD_GUILD_LINKED_SERVER:format(serverName or "") or serverName or "")
        page.linked.channel:SetText(DISCORD_GUILD_LINKED_CHANNEL and DISCORD_GUILD_LINKED_CHANNEL:format(channelName or "") or channelName or "")
        page.linked.separate:SetChecked(C_Discord.IsGuildSettingSet(Enum.DiscordGuildSettings.SeparateStream))
    elseif oauthed then
        local select = page.select
        select.server.Text:SetText(discord.server ~= -1 and C_Discord.GetServerName(discord.server) or "")
        local hasServer = discord.server ~= -1
        select.channelGroup:SetShown(hasServer)
        if hasServer then
            local numChannels, valid = C_Discord.GetNumDiscordChannels(discord.server)
            select.empty:SetShown(valid and numChannels == 0)
            select.channelTitle:SetText(DISCORD_VALID_SERVER_CHANNEL_LIST and
                DISCORD_VALID_SERVER_CHANNEL_LIST:format(C_Discord.GetServerName(discord.server) or "") or "")
            select.channel.Text:SetText(discord.channel ~= -1 and C_Discord.GetDiscordChannelName(discord.server, discord.channel) or "")
            select.link:SetEnabled(discord.channel ~= -1)
            select.link:SetAlpha(discord.channel ~= -1 and 1 or 0.45)
        end
    end
end

local function CreateDiscordPage(page)
    local UI = ns.UI
    -- nicht verbunden: anmelden
    page.oauth = CreateFrame("Frame", nil, page)
    page.oauth:SetAllPoints()
    local need = UI.Text(page.oauth, 13, "CENTER")
    need:SetPoint("TOP", 0, -40)
    need:SetPoint("LEFT", 10, 0)
    need:SetPoint("RIGHT", -10, 0)
    need:SetText(DISCORD_GUILD_NEED_TO_OAUTH or "")
    local oauthButton = UI.Button(page.oauth, DISCORD_SETUP_OAUTH or L["Connect"], function()
        C_Discord.Authorize()
        RefreshDiscord()
    end, 180)
    oauthButton:SetHeight(28)
    oauthButton:SetPoint("TOP", need, "BOTTOM", 0, -16)

    -- verbunden: Status, eigener Kanal, Trennen
    page.linked = CreateFrame("Frame", nil, page)
    page.linked:SetAllPoints()
    local linkedTitle = UI.Text(page.linked, 15, "CENTER")
    linkedTitle:SetPoint("TOP", 0, -30)
    linkedTitle:SetText(DISCORD_GUILD_SERVER_CHANNEL_LINKED or "")
    page.linked.server = UI.Text(page.linked, 13, "CENTER")
    page.linked.server:SetPoint("TOP", linkedTitle, "BOTTOM", 0, -12)
    page.linked.channel = UI.Text(page.linked, 13, "CENTER")
    page.linked.channel:SetPoint("TOP", page.linked.server, "BOTTOM", 0, -6)
    page.linked.separate = ns.GuildCheck(page.linked, DISCORD_GUILD_SETTING_SEPARATE_STREAM or "", function(_, on)
        C_Discord.SetGuildSetting(Enum.DiscordGuildSettings.SeparateStream, on)
    end)
    page.linked.separate:SetPoint("TOP", page.linked.channel, "BOTTOM", 0, -18)
    local unlink = UI.Button(page.linked, DISCORD_SERVER_UNLINK_PROMPT or L["Unlink"], function()
        C_Discord.GuildUnlink()
        RefreshDiscord()
    end, 180)
    unlink:SetHeight(28)
    unlink:SetPoint("TOP", page.linked.separate, "BOTTOM", 0, -18)

    -- Server und Kanal wählen
    local select = CreateFrame("Frame", nil, page)
    select:SetAllPoints()
    page.select = select
    local serverLabel = UI.Text(select, 12, "LEFT", UI.ACCENT)
    serverLabel:SetPoint("TOPLEFT", 0, -46)
    serverLabel:SetText(DISCORD_SELECT_SERVER or L["Discord server:"])
    select.server = ns.GuildDropdown(select, 190, function(self)
        local items = {}
        for i = 1, C_Discord.GetNumDiscordServers() do items[#items + 1] = { value = i, label = C_Discord.GetServerName(i) } end
        ns.UI.OpenList(self, items, discord.server, function(index)
            discord.server, discord.channel = index, -1
            C_Discord.GetServerLinkableChannels(index)
            RefreshDiscord()
        end)
    end)
    select.server:SetPoint("LEFT", serverLabel, "RIGHT", 10, 0)
    select.channelGroup = CreateFrame("Frame", nil, select)
    select.channelGroup:SetPoint("TOPLEFT", 0, -90)
    select.channelGroup:SetPoint("BOTTOMRIGHT")
    select.channelTitle = UI.Text(select.channelGroup, 12, "CENTER")
    select.channelTitle:SetPoint("TOPLEFT")
    select.channelTitle:SetPoint("TOPRIGHT")
    select.empty = UI.Text(select.channelGroup, 12, "CENTER", { 1, 0.5, 0.3 })
    select.empty:SetPoint("TOP", 0, -24)
    select.empty:SetWidth(280)
    select.empty:SetText(DISCORD_GUILD_SETTING_CHANNEL_LIST_EMPTY or "")
    local channelLabel = UI.Text(select.channelGroup, 12, "LEFT", UI.ACCENT)
    channelLabel:SetPoint("TOPLEFT", 0, -60)
    channelLabel:SetText(DISCORD_SELECT_CHANNEL or L["Channel:"])
    select.channel = ns.GuildDropdown(select.channelGroup, 190, function(self)
        local items = {}
        local count = C_Discord.GetNumDiscordChannels(discord.server) or 0
        for i = 1, count do items[#items + 1] = { value = i, label = C_Discord.GetDiscordChannelName(discord.server, i) } end
        ns.UI.OpenList(self, items, discord.channel, function(index)
            discord.channel = index
            RefreshDiscord()
        end)
    end)
    select.channel:SetPoint("LEFT", channelLabel, "RIGHT", 10, 0)
    select.link = UI.Button(select.channelGroup, DISCORD_CHANNEL_LINK_PROMPT or L["Link channel"], function()
        if discord.channel ~= -1 then C_Discord.GuildLink(discord.server, discord.channel) end
    end, 190)
    select.link:SetHeight(28)
    select.link:SetPoint("TOPLEFT", select.channel, "BOTTOMLEFT", 0, -12)
    select.link:SetMotionScriptsWhileDisabled(true)
end

local REFRESH = { ranks = RefreshRanks, perms = RefreshPerms, bank = RefreshBank, discord = RefreshDiscord }

local function RefreshControl()
    if not (control and control:IsShown()) then return end
    local modes = Modes()
    local valid = false
    for _, entry in ipairs(modes) do
        if entry.value == mode then valid = true end
    end
    if not valid then mode = modes[1] and modes[1].value end
    if not mode then control:Hide() return end
    control.mode.Text:SetText(ModeLabel(mode))
    local withRank = mode == "perms" or mode == "bank"
    control.rankRow:SetShown(withRank)
    if withRank then
        ClampRank()
        control.rank.Text:SetText(GuildControlGetRankName(currentRank) or "")
    end
    control.line:ClearAllPoints()
    control.line:SetPoint("TOPLEFT", 0, withRank and -124 or -88)
    control.line:SetPoint("TOPRIGHT", 0, withRank and -124 or -88)
    for key, page in pairs(control.pages) do
        page:SetShown(key == mode)
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", 16, withRank and -132 or -96)
        page:SetPoint("BOTTOMRIGHT", -16, 16)
    end
    REFRESH[mode]()
end

local function CreateControl()
    local UI = ns.UI
    control = Window("MeredanUIGuildControl", 380, 600, GUILDCONTROL or L["Guild settings"])
    local optionsLabel = UI.Text(control, 12, "LEFT", UI.ACCENT)
    optionsLabel:SetPoint("TOPLEFT", 16, -60)
    optionsLabel:SetWidth(90)
    optionsLabel:SetText(L["Options"])
    control.mode = ns.GuildDropdown(control, 240, function(self)
        UI.OpenList(self, Modes(), mode, function(value)
            mode = value
            if value == "discord" then
                discord.server, discord.channel = -1, -1
                C_Discord.UpdateDiscordServers()
                C_Discord.UpdateGuildLobby()
            end
            RefreshControl()
        end)
    end)
    control.mode:SetPoint("TOPRIGHT", -16, -52)
    control.rankRow = CreateFrame("Frame", nil, control)
    control.rankRow:SetPoint("TOPLEFT", 16, -88)
    control.rankRow:SetPoint("RIGHT", -16, 0)
    control.rankRow:SetHeight(28)
    local rankLabel = UI.Text(control.rankRow, 12, "LEFT", UI.ACCENT)
    rankLabel:SetPoint("LEFT")
    rankLabel:SetText(((GUILDCONTROL_SELECTRANK or L["Change rank:"]):gsub(":%s*$", "")))
    control.rank = ns.GuildDropdown(control.rankRow, 240, function(self)
        local items = {}
        for i = 2, GuildControlGetNumRanks() do items[#items + 1] = { value = i, label = GuildControlGetRankName(i) } end
        UI.OpenList(self, items, currentRank, function(rank)
            currentRank = rank
            GuildControlSetRank(rank)
            RefreshControl()
        end)
    end)
    control.rank:SetPoint("RIGHT")
    local line = control:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0, 0, 0, 1)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 0, -90)
    line:SetPoint("TOPRIGHT", 0, -90)
    control.line = line

    control.pages = {}
    for _, key in ipairs({ "ranks", "perms", "bank", "discord" }) do
        control.pages[key] = CreateFrame("Frame", nil, control)
    end
    CreateRanksPage(control.pages.ranks)
    CreatePermsPage(control.pages.perms)
    CreateBankPage(control.pages.bank)
    CreateDiscordPage(control.pages.discord)
    control:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        RefreshControl()
    end)
    control:HookScript("OnHide", function()
        ns.UI.CloseList()
        StaticPopup_Hide("MEREDANUI_CONFIRM_AUTH_REMOVE")
    end)

    StaticPopupDialogs["MEREDANUI_CONFIRM_AUTH_REMOVE"] = {
        text = "%s",
        button1 = YES,
        button2 = NO,
        OnAccept = function() GuildControlSetRankFlag(AUTH_FLAG, false) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function ns.ToggleGuildControl()
    if not control then CreateControl() end
    if control:IsShown() then control:Hide() return end
    if not mode then mode = IsGuildLeader() and "ranks" or "discord" end
    local window = ns.GuildWindow()
    control:ClearAllPoints()
    control:SetPoint("TOPLEFT", window, "TOPRIGHT", TAB_STEP + 8, 0)
    control:Show()
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    local function Update() RefreshControl() end
    for _, event in ipairs({ "GUILD_RANKS_UPDATE", "GUILD_RANKS_UPDATE_ACTIVE_PLAYER", "GUILDBANK_UPDATE_TABS",
        "PLAYER_MONEY", "DISCORD_LINK_UPDATE", "DISCORD_STATUS_UPDATE", "DISCORD_SERVER_LIST_UPDATE",
        "DISCORD_GUILD_LOBBY_UPDATE", "DISCORD_GUILD_SETTINGS_UPDATE" }) do
        ns:On(event, Update)
    end
    ns:On("GUILD_ROSTER_UPDATE", function() if ns.RefreshGuildMemberDetail then ns.RefreshGuildMemberDetail() end end)
end)

StaticPopupDialogs["MEREDANUI_GUILD_REMOVE"] = {
    text = REMOVE_GUILDMEMBER_LABEL or "Remove %s from the guild?",
    button1 = YES, button2 = NO,
    OnAccept = function(_, name) if name then C_GuildInfo.Uninvite(name) end end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
