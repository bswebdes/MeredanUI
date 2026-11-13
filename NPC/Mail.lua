-- Mailbox (WoW Forever): NPC-style window with the best of Postal - open all (everything / gold only /
-- AH only, never COD), checkbox selection, shift/ctrl-click, address book, quick attach by type,
-- gold without subject uses the amount as subject. Blizzard's MailFrame is parked invisibly (it only
-- checks IsShown). Right-click attaching from bags depends on SetSendMailShowing, set by our send tab.
local _, ns = ...
local L = ns.L

local WIDTH, PAD = 560, 18
local ROW_H, ROW_GAP = 54, 6
local SLOT = 38
local MAIL_ICON = "Interface\\MailFrame\\Mail-Icon"
local LETTER_ICON = "Interface\\Icons\\INV_Letter_15"
local MAX_RECEIVE = ATTACHMENTS_MAX_RECEIVE or 16
local MAX_SEND = ATTACHMENTS_MAX_SEND or 12
local QUICK = { -- quick attach: trade goods subclasses
    { label = "Herbs", sub = 9 }, { label = "Ore", sub = 7 }, { label = "Cloth", sub = 5 }, { label = "Leather", sub = 6 },
}

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, view
local inbox, read, send = {}, {}, {}
local tabs = {}
local selected = {}
local openMail          -- index of the mail being read
local opening           -- running "open all" state
local openMode = "all"  -- "all", "money", "ah"

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.mailWindow ~= false
        and not ns.OtherAddon(ns.MAIL_ADDONS) -- stay off if another mailbox addon is loaded
end

local function Store()
    ns.root.mail = ns.root.mail or { chars = {}, recent = {} }
    local realm = GetRealmName()
    ns.root.mail.chars[realm] = ns.root.mail.chars[realm] or {}
    ns.root.mail.recent[realm] = ns.root.mail.recent[realm] or {}
    return ns.root.mail.chars[realm], ns.root.mail.recent[realm]
end

local function DaysText(days)
    if not days then return "" end
    if days < 1 then return L["less than a day"] end
    return L["%d days left"]:format(math.floor(days))
end

-- Open all / open selected ---------------------------------------------------------------------

local function Header(i)
    local packageIcon, stationeryIcon, sender, subject, money, cod, days, hasItem, wasRead, wasReturned,
        _, canReply, isGM = GetInboxHeaderInfo(i)
    return { package = packageIcon, stationery = stationeryIcon, sender = sender, subject = subject, money = money or 0,
        cod = cod or 0, days = days, hasItem = hasItem, read = wasRead, returned = wasReturned, canReply = canReply,
        gm = isGM }
end

-- Count attachments in the whole inbox (summary reports only what was actually taken)
local function CountAttachments()
    local total = 0
    for i = 1, GetInboxNumItems() do
        for a = 1, MAX_RECEIVE do
            if GetInboxItem(i, a) then total = total + 1 end
        end
    end
    return total
end

local function StopOpening(reason)
    if not opening then return end
    opening.items = math.max((opening.startItems or 0) - CountAttachments(), 0)
    local earned = GetMoney() - opening.startMoney
    local parts = {}
    if earned > 0 then parts[#parts + 1] = GetMoneyString(earned, true) end
    if opening.items > 0 then parts[#parts + 1] = L["%d items"]:format(opening.items) end
    if #parts > 0 then ns.Print(L["Mail: %s."]:format(table.concat(parts, " " .. L["and"] .. " "))) end
    if reason then ns.Print(reason) end
    opening = nil
    wipe(selected)
    if window and window:IsShown() then window.Layout() end
end

local function Wanted(h, i)
    if h.cod > 0 or h.gm then return false end -- COD must be confirmed manually
    if opening.only and not opening.only[i] then return false end
    if opening.mode == "money" then return h.money > 0 end
    if opening.mode == "ah" then return GetInboxInvoiceInfo(i) ~= nil end
    return h.money > 0 or h.hasItem
end

local function Step()
    if not opening then return end
    opening.steps = opening.steps + 1
    if opening.steps > 400 then return StopOpening() end
    while opening.index >= 1 do
        local i = opening.index
        local h = Header(i)
        opening.tries[i] = (opening.tries[i] or 0) + 1
        if h.sender and opening.tries[i] <= 8 and Wanted(h, i) and (h.money > 0 or (h.hasItem and opening.mode ~= "money")) then
            if h.money > 0 then
                TakeInboxMoney(i)
            else
                -- Like Blizzard's "open all": stop when bags are full instead of failing silently
                if C_Container.CalculateTotalNumberOfFreeBagSlots() == 0 then
                    return StopOpening(ERR_INV_FULL or L["Your bags are full."])
                end
                AutoLootMailItem(i)
            end
            C_Timer.After(0.45, Step) -- give the server time; the same mail is checked again
            return
        end
        opening.index = i - 1
    end
    StopOpening()
end

local function StartOpening(mode, only)
    if opening then return end
    opening = { mode = mode, only = only, index = (GetInboxNumItems()), startMoney = GetMoney(), items = 0, steps = 0,
        tries = {}, startItems = CountAttachments() }
    Step()
end

-- Inbox ------------------------------------------------------------------------------------------

local function InboxRow(i)
    if inbox.rows[i] then return inbox.rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, inbox.list.child)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.bg = UI.Box(row, { 0.098, 0.098, 0.106, 1 })
    row.strip = row:CreateTexture(nil, "OVERLAY")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.strip:SetColorTexture(unpack(UI.ACCENT))
    -- Selection checkbox
    row.check = CreateFrame("Button", nil, row)
    row.check:SetSize(14, 14)
    row.check:SetPoint("LEFT", 10, 0)
    UI.CheckBg(row.check)
    row.tick = UI.Icon(row.check, "Check", 12, UI.ACCENT)
    row.tick:SetPoint("CENTER")
    row.check:SetScript("OnClick", function()
        selected[row.index] = not selected[row.index] or nil
        window.Layout()
    end)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(38, 38)
    holder:SetPoint("LEFT", row.check, "RIGHT", 10, 0)
    ns.AddBorder(holder)
    row.icon = holder:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.money = UI.Text(row, 12, "RIGHT")
    row.money:SetPoint("TOPRIGHT", -12, -12)
    row.items = UI.Text(row, 11, "RIGHT", UI.MUTED)
    row.items:SetPoint("BOTTOMRIGHT", -12, 12)
    row.subject = UI.Text(row, 13, "LEFT")
    row.subject:SetPoint("TOPLEFT", holder, "TOPRIGHT", 12, -4)
    row.subject:SetPoint("RIGHT", row, "RIGHT", -110, 0)
    row.sub = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.sub:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", 12, 4)
    row.sub:SetPoint("RIGHT", row, "RIGHT", -110, 0)
    row:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.133, 0.133, 0.149, 1) end)
    row:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.098, 0.098, 0.106, 1) end)
    row:SetScript("OnClick", function(self)
        local i = self.index
        if IsShiftKeyDown() then -- take all (Postal Express)
            local h = Header(i)
            if h.cod > 0 then return end
            if h.money > 0 then TakeInboxMoney(i) end
            if h.hasItem then AutoLootMailItem(i) end
        elseif IsControlKeyDown() then -- return to sender
            if not InboxItemCanDelete(i) then ReturnInboxItem(i) end
        else
            openMail = i
            view = "read"
            PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
            window.Layout()
        end
    end)
    inbox.rows[i] = row
    return row
end

local function LayoutInbox()
    local num, total = GetInboxNumItems()
    local y, money, items = 0, 0, 0
    local count = 0
    for i = 1, num do
        local h = Header(i)
        local row = InboxRow(i)
        row.index = i
        row.icon:SetTexture(h.package or h.stationery or LETTER_ICON)
        row.subject:SetText(h.subject or "")
        row.subject:SetTextColor(unpack(h.read and { 0.79, 0.78, 0.75 } or { 1, 1, 1 }))
        row.strip:SetShown(not h.read)
        local days = DaysText(h.days)
        local soon = h.days and h.days < 3
        row.sub:SetText((h.sender or "") .. " · " .. (soon and "|cffff5050" .. days .. "|r" or days))
        local n = 0
        if h.hasItem then
            for a = 1, MAX_RECEIVE do if GetInboxItem(i, a) then n = n + 1 end end
        end
        row.money:SetText(h.money > 0 and GetMoneyString(h.money, true) or (h.cod > 0 and ("|cffff5050" .. L["COD"] .. " " .. GetMoneyString(h.cod, true) .. "|r") or ""))
        row.items:SetText(n > 0 and L["%d items"]:format(n) or "")
        row.tick:SetShown(selected[i] and true or false)
        money, items = money + h.money, items + n
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", inbox.list.child, "RIGHT")
        row:Show()
        y = y + ROW_H + ROW_GAP
        count = count + 1
    end
    for i = num + 1, #inbox.rows do inbox.rows[i]:Hide() end
    inbox.list:SetContentHeight(y)
    inbox.empty:SetShown(num == 0)
    tabs.inbox.count:SetText(total and total > 0 and total or "")
    local picked = 0
    for i in pairs(selected) do if i <= num then picked = picked + 1 end end
    inbox.summary:SetShown(picked == 0)
    inbox.openSelected:SetShown(picked > 0)
    inbox.returnSelected:SetShown(picked > 0)
    inbox.openSelected.Text:SetText(L["Open selected (%d)"]:format(picked))
    local parts = {}
    if money > 0 then parts[#parts + 1] = GetMoneyString(money, true) end
    if items > 0 then parts[#parts + 1] = L["%d items"]:format(items) end
    inbox.summary:SetText(#parts > 0 and (L["In total"] .. " " .. table.concat(parts, " · ")) or "")
    if total and total > num then
        inbox.summary:SetText(inbox.summary:GetText() .. "  |cff99978f(" .. L["%d more on the server"]:format(total - num) .. ")|r")
    end
    inbox.openAll.Text:SetText(opening and L["Opening …"] or L["Open all"])
end

-- Read mail --------------------------------------------------------------------------------------

local function Attachment(i)
    if read.slots[i] then return read.slots[i] end
    local slot = CreateFrame("Button", nil, read.panel)
    slot:SetSize(40, 40)
    ns.AddSlotBackground(slot)
    slot.border = ns.AddBorder(slot)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetAllPoints()
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.count = ns.CreateText(slot, 11, "RIGHT", "OUTLINE")
    slot.count:SetPoint("BOTTOMRIGHT", -2, 2)
    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInboxItem(openMail, self.index)
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slot:SetScript("OnClick", function(self)
        if HandleModifiedItemClick(GetInboxItemLink(openMail, self.index)) then return end
        local h = Header(openMail)
        if h.cod > 0 then
            StaticPopup_Show("MEREDANUI_MAIL_COD", GetMoneyString(h.cod, true), nil, { mail = openMail, index = self.index })
        else
            TakeInboxItem(openMail, self.index)
        end
    end)
    read.slots[i] = slot
    return slot
end

local function LayoutRead()
    local h = openMail and Header(openMail)
    if not (h and h.sender) then
        view = "inbox"
        return LayoutInbox()
    end
    local body, _, _, _, isInvoice = GetInboxText(openMail)
    read.subject:SetText(h.subject or "")
    read.days:SetText(DaysText(h.days))
    read.from:SetText(L["From: %s"]:format(h.sender))
    if isInvoice then
        -- Format invoices like Blizzard's mail frame instead of the raw "buyer"/"seller" kind
        local kind, itemName, player, bid, _, deposit, consignment, _, etaHour, etaMin, count = GetInboxInvoiceInfo(openMail)
        if kind then
            player = player or (kind == "buyer" and AUCTION_HOUSE_MAIL_MULTIPLE_SELLERS or AUCTION_HOUSE_MAIL_MULTIPLE_BUYERS) or ""
            if count and count > 1 then itemName = AUCTION_MAIL_ITEM_STACK:format(itemName or "", count) end
            local money = function(v) return GetMoneyString(v or 0, true) end
            local lines = {}
            if kind == "buyer" then
                lines[#lines + 1] = ITEM_PURCHASED_COLON .. " " .. (itemName or "")
                lines[#lines + 1] = SOLD_BY_COLON .. " " .. player
                lines[#lines + 1] = AMOUNT_PAID_COLON .. " " .. money(bid)
            else
                lines[#lines + 1] = ITEM_SOLD_COLON .. " " .. (itemName or "")
                lines[#lines + 1] = PURCHASED_BY_COLON .. " " .. player
                if kind == "seller" then
                    lines[#lines + 1] = ""
                    lines[#lines + 1] = L["Price"] .. ": " .. money(bid)
                    lines[#lines + 1] = L["Deposit"] .. ": " .. money(deposit)
                    lines[#lines + 1] = L["Fee"] .. ": |cffe65050− " .. money(consignment) .. "|r"
                    lines[#lines + 1] = AMOUNT_RECEIVED_COLON .. " " .. money((bid or 0) + (deposit or 0) - (consignment or 0))
                else -- seller_temp_invoice: money arrives later
                    lines[#lines + 1] = AUCTION_INVOICE_PENDING_FUNDS_COLON .. " " .. money((bid or 0) + (deposit or 0) - (consignment or 0))
                    if etaHour and GameTime_GetFormattedTime then
                        lines[#lines + 1] = AUCTION_INVOICE_FUNDS_DELAY:format(GameTime_GetFormattedTime(etaHour, etaMin, true))
                    end
                end
            end
            body = table.concat(lines, "\n")
        end
    end
    read.body:SetWidth(read.list:GetWidth())
    read.body:SetText(body or "")
    read.list:SetContentHeight(read.body:GetStringHeight())
    -- Attached: gold + items
    local n, x = 0, 0
    read.money:SetShown(h.money > 0)
    if h.money > 0 then
        read.money.Text:SetText(GetMoneyString(h.money, true) .. "  |cff99978f" .. L["take"] .. "|r")
        read.money:SetWidth(read.money.Text:GetUnboundedStringWidth() + 24)
        x = read.money:GetWidth() + 8
    end
    for a = 1, MAX_RECEIVE do
        local name, _, texture, count, quality = GetInboxItem(openMail, a)
        if name then
            n = n + 1
            local slot = Attachment(n)
            slot.index = a
            slot.icon:SetTexture(texture)
            slot.count:SetText(count and count > 1 and count or "")
            local edge = (quality and quality >= Enum.ItemQuality.Uncommon) and { C_Item.GetItemQualityColor(quality) } or { 0, 0, 0 }
            for _, e in ipairs(slot.border) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
            slot:ClearAllPoints()
            local col, row = (n - 1) % 9, math.floor((n - 1) / 9)
            slot:SetPoint("BOTTOMLEFT", read.panel, "BOTTOMLEFT", 20 + (row == 0 and x or 0) + col * 46, 18 + row * 46)
            slot:Show()
        end
    end
    for i = n + 1, #read.slots do read.slots[i]:Hide() end
    read.attachLabel:SetShown(n > 0 or h.money > 0)
    local canDelete = InboxItemCanDelete(openMail)
    read.ret:SetShown(not canDelete)
    read.delete:SetShown(canDelete and true or false)
    -- Buttons shift right when there is no Reply (system and AH mail)
    local anchor = h.canReply and read.reply or nil
    for _, button in ipairs({ read.ret, read.delete }) do
        button:ClearAllPoints()
        if anchor then button:SetPoint("RIGHT", anchor, "LEFT", -8, 0) else button:SetPoint("BOTTOMRIGHT") end
    end
    read.reply:SetShown(h.canReply)
    if h.cod > 0 then read.attachLabel:SetText(L["Attached"] .. "  |cffff5050" .. L["COD"] .. " " .. GetMoneyString(h.cod, true) .. "|r") else read.attachLabel:SetText(L["Attached"]) end
end

-- Send mail ----------------------------------------------------------------------------------------

local function SendSlot(i)
    if send.slots[i] then return send.slots[i] end
    local slot = CreateFrame("Button", nil, send.frame)
    slot:SetSize(SLOT, SLOT)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")
    ns.AddSlotBackground(slot)
    slot.border = ns.AddBorder(slot)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetAllPoints()
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.count = ns.CreateText(slot, 11, "RIGHT", "OUTLINE")
    slot.count:SetPoint("BOTTOMRIGHT", -2, 2)
    slot:SetID(i)
    slot:SetScript("OnClick", function(self, button) ClickSendMailItemButton(self:GetID(), button == "RightButton") end)
    slot:SetScript("OnReceiveDrag", function(self) ClickSendMailItemButton(self:GetID()) end)
    slot:SetScript("OnDragStart", function(self) ClickSendMailItemButton(self:GetID()) end)
    slot:SetScript("OnEnter", function(self)
        if not GetSendMailItem(self:GetID()) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSendMailItem(self:GetID())
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    send.slots[i] = slot
    return slot
end

local function LayoutSend()
    for i = 1, MAX_SEND do
        local slot = SendSlot(i)
        local name, _, texture, count, quality = GetSendMailItem(i)
        slot.icon:SetTexture(name and texture or nil)
        slot.count:SetText(name and count and count > 1 and count or "")
        local edge = (name and quality and quality >= Enum.ItemQuality.Uncommon) and { C_Item.GetItemQualityColor(quality) } or { 0, 0, 0 }
        for _, e in ipairs(slot.border) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
    end
    send.price:SetText(L["Postage"] .. " |cffe8e6de" .. GetMoneyString(GetSendMailPrice() or 0, true) .. "|r")
    send.gold:SetText(GetMoneyString(GetMoney(), true))
    send.codTick:SetShown(send.cod)
end

local function MoneyInput()
    local g = tonumber(send.coins[1]:GetText()) or 0
    local s = tonumber(send.coins[2]:GetText()) or 0
    local c = tonumber(send.coins[3]:GetText()) or 0
    return g * 10000 + s * 100 + c
end

local function ResetSend()
    send.to:SetText("")
    send.subject:SetText("")
    send.body:SetText("")
    for _, box in ipairs(send.coins) do box:SetText("") end
    send.cod = false
end

local function DoSend()
    local to = strtrim(send.to:GetText() or "")
    if to == "" then return send.to:SetFocus() end
    local copper = MoneyInput()
    local subject = strtrim(send.subject:GetText() or "")
    -- Postal Wire: gold without subject uses the amount as subject
    if subject == "" and copper > 0 then subject = C_CurrencyInfo.GetCoinText(copper, " ") end
    for i = 1, MAX_SEND do
        if subject ~= "" then break end
        subject = GetSendMailItem(i) or ""
    end
    SetSendMailCOD(0)
    SetSendMailMoney(0)
    if copper > 0 then
        if send.cod then SetSendMailCOD(copper) else SetSendMailMoney(copper) end
    end
    send.pendingTo = to
    SendMail(to, subject, send.body:GetText() or "")
end

-- Address book: own characters, recent, friends, guild - filtered by the typed prefix
local function Contacts(prefix)
    prefix = (prefix or ""):lower()
    local chars, recent = Store()
    local me = UnitName("player")
    local seen, out = {}, {}
    local function Add(group, name, class)
        if not name or name == "" or name == me or seen[name] then return end
        if prefix ~= "" and not name:lower():find("^" .. prefix:gsub("%p", "%%%0")) then return end
        seen[name] = true
        out[#out + 1] = { group = group, name = name, class = class }
    end
    for name, class in pairs(chars) do Add(L["Own characters"], name, class) end
    for _, name in ipairs(recent) do Add(L["Recent"], name) end
    for i = 1, (C_FriendList.GetNumFriends() or 0) do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info then Add(L["Friends"], info.name and info.name:match("^[^-]+"), info.className and info.className:upper()) end
    end
    if IsInGuild() then
        for i = 1, (GetNumGuildMembers() or 0) do
            local name, _, _, _, _, _, _, _, _, _, class = GetGuildRosterInfo(i)
            Add(GUILD or "Guild", name and name:match("^[^-]+"), class)
        end
    end
    return out
end

local function ShowContacts()
    local UI = ns.UI
    local list = Contacts(send.to:GetText())
    local box = send.book
    for _, line in pairs(box.lines) do line:Hide() end
    for _, button in pairs(box.buttons) do button:Hide() end
    if #list == 0 or not send.to:HasFocus() then return box:Hide() end
    local y, n, lastGroup = 4, 0, nil
    for _, entry in ipairs(list) do
        if n >= 10 then break end
        if entry.group ~= lastGroup then
            n = n + 1
            local head = box.lines[n] or UI.Text(box, 10, "LEFT", UI.ACCENT)
            box.lines[n] = head
            head.isHead = true
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", 10, -y)
            head:SetText(entry.group:upper())
            head:Show()
            y = y + 16
            lastGroup = entry.group
        end
        n = n + 1
        local line = box.buttons[n]
        if not line then
            line = CreateFrame("Button", nil, box)
            line:SetHeight(20)
            line.text = UI.Text(line, 13, "LEFT")
            line.text:SetPoint("LEFT", 10, 0)
            local hover = line:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(1, 1, 1, 0.08)
            line:SetScript("OnClick", function(self)
                send.to:SetText(self.name)
                box:Hide()
                send.subject:SetFocus()
            end)
            box.buttons[n] = line
        end
        if box.lines[n] and box.lines[n].isHead then box.lines[n]:Hide() end
        line.name = entry.name
        line.text:SetText(entry.name)
        local color = entry.class and RAID_CLASS_COLORS[entry.class]
        if color then line.text:SetTextColor(color.r, color.g, color.b) else line.text:SetTextColor(unpack(UI.TEXT)) end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetPoint("RIGHT", box, "RIGHT")
        line:Show()
        y = y + 20
    end
    box:SetHeight(y + 4)
    box:Show()
end

-- Quick attach: matching bag items, one after another
local function QuickAttach(sub)
    local queue = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not info.isBound and not info.isLocked then
                local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
                if classID == Enum.ItemClass.Tradegoods and subClassID == sub then queue[#queue + 1] = { bag, slot } end
            end
        end
    end
    -- Pick up and drop into the first free attachment slot (UseContainerItem is protected for addons)
    local function Next()
        local free
        for i = 1, MAX_SEND do
            if not free and not GetSendMailItem(i) then free = i end
        end
        local item = table.remove(queue, 1)
        if not (item and free and view == "send") or CursorHasItem() then return end
        C_Container.PickupContainerItem(item[1], item[2])
        ClickSendMailItemButton(free)
        C_Timer.After(0.25, Next)
    end
    Next()
end

-- Build -------------------------------------------------------------------------------------------

local function Layout()
    if not (window and window:IsShown()) then return end
    local UI = ns.UI
    for key, tab in pairs(tabs) do
        local active = (key == "send") == (view == "send")
        tab.text:SetTextColor(unpack(active and UI.ACCENT or UI.MUTED))
        tab.line:SetShown(active)
    end
    inbox.frame:SetShown(view == "inbox")
    read.frame:SetShown(view == "read")
    send.frame:SetShown(view == "send")
    window.npcTitle:SetText(view == "send" and (SENDMAIL or L["Send mail"]) or (view == "read" and L["Reading"] or (INBOX or L["Inbox"])))
    if view == "inbox" then LayoutInbox() elseif view == "read" then LayoutRead() else LayoutSend() end
end

local function SetView(key)
    view = key
    SetSendMailShowing(key == "send") -- enables right-click attaching from bags
    if key ~= "send" then send.book:Hide() end
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    Layout()
end

local function Tab(key, label, previous)
    local UI = ns.UI
    local tab = CreateFrame("Button", nil, window)
    tab.text = UI.Text(tab, 14, "LEFT")
    tab.text:SetPoint("LEFT")
    tab.text:SetText(label)
    tab.count = UI.Text(tab, 12, "LEFT", UI.MUTED)
    tab.count:SetPoint("LEFT", tab.text, "RIGHT", 6, 0)
    tab:SetSize(tab.text:GetUnboundedStringWidth() + 26, 20)
    tab.line = tab:CreateTexture(nil, "OVERLAY")
    tab.line:SetColorTexture(unpack(UI.ACCENT))
    tab.line:SetPoint("BOTTOMLEFT", 0, -2)
    tab.line:SetPoint("BOTTOMRIGHT", tab.text, "BOTTOMRIGHT", 0, -5)
    tab.line:SetHeight(2)
    tab:SetScript("OnClick", function() SetView(key) end)
    if previous then tab:SetPoint("LEFT", previous, "RIGHT", 14, 0) else tab:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 16) end
    tabs[key] = tab
    return tab
end

local function ViewFrame()
    local frame = CreateFrame("Frame", nil, window)
    frame:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 48)
    frame:SetPoint("BOTTOMRIGHT", -PAD, 16)
    return frame
end

local function AccentButton(parent, label, onClick, width)
    local button = ns.UI.Button(parent, label, onClick, width)
    button:SetHeight(30)
    button.Text:SetTextColor(unpack(ns.UI.ACCENT))
    for _, edge in ipairs(ns.AddBorder(button, true)) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    return button
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIMail", WIDTH, ns.NPC_HEIGHT, "mail")
    window.Layout = Layout
    ns.WatchBlizzardFrame(window, function() return MailFrame end)
    Tab("send", SENDMAIL or L["Send mail"], Tab("inbox", INBOX or L["Inbox"]))

    -- Inbox
    inbox.frame = ViewFrame()
    inbox.rows = {}
    inbox.list = UI.ScrollArea(inbox.frame)
    inbox.list:SetPoint("TOPLEFT")
    inbox.list:SetPoint("BOTTOMRIGHT", -8, 64)
    inbox.empty = UI.Text(inbox.frame, 13, "CENTER", UI.MUTED)
    inbox.empty:SetPoint("TOP", 0, -60)
    inbox.empty:SetText(L["No mail."])
    local hint = UI.Text(inbox.frame, 11, "LEFT", UI.MUTED)
    hint:SetPoint("BOTTOMLEFT", 0, 44)
    hint:SetText(L["Shift-click: take all · Ctrl-click: return · COD mail is never opened automatically"])
    inbox.openAll = AccentButton(inbox.frame, "", function()
        if opening then StopOpening() else StartOpening(openMode) end
    end, 120)
    inbox.openAll:SetPoint("BOTTOMRIGHT")
    local MODES = { { value = "all", label = L["Everything"] }, { value = "money", label = L["Gold only"] },
        { value = "ah", label = L["Auction house only"] } }
    inbox.mode = UI.Button(inbox.frame, L["Everything"], function(self)
        UI.OpenList(self, MODES, openMode, function(value)
            openMode = value
            for _, m in ipairs(MODES) do if m.value == value then self.Text:SetText(m.label) end end
        end)
    end, 140)
    inbox.mode:SetHeight(30)
    inbox.mode:SetPoint("RIGHT", inbox.openAll, "LEFT", -8, 0)
    inbox.summary = UI.Text(inbox.frame, 12, "LEFT", UI.MUTED)
    inbox.summary:SetPoint("LEFT", inbox.frame, "BOTTOMLEFT", 0, 15)
    inbox.summary:SetPoint("RIGHT", inbox.mode, "LEFT", -8, 0)
    inbox.openSelected = UI.Button(inbox.frame, "", function()
        local only = {}
        for i in pairs(selected) do only[i] = true end
        StartOpening("all", only)
    end, 150)
    inbox.openSelected:SetHeight(30)
    inbox.openSelected:SetPoint("BOTTOMLEFT")
    inbox.returnSelected = UI.Button(inbox.frame, L["Return"], function()
        local list = {}
        for i in pairs(selected) do
            if not InboxItemCanDelete(i) then list[#list + 1] = i end -- system/AH mail cannot be returned
        end
        table.sort(list, function(a, b) return a > b end) -- back to front, indices shift otherwise
        for n, i in ipairs(list) do C_Timer.After((n - 1) * 0.4, function() ReturnInboxItem(i) end) end
        wipe(selected)
    end, 120)
    inbox.returnSelected:SetHeight(30)
    inbox.returnSelected:SetPoint("LEFT", inbox.openSelected, "RIGHT", 8, 0)

    -- Read mail: everything on parchment
    read.frame = ViewFrame()
    read.slots = {}
    read.panel = ns.CreateParchmentPanel(read.frame)
    read.panel:SetPoint("TOPLEFT")
    read.panel:SetPoint("BOTTOMRIGHT", 0, 46)
    read.subject = UI.Text(read.panel, 15, "LEFT", { 1, 0.82, 0 })
    read.subject:SetPoint("TOPLEFT", 20, -18)
    read.subject:SetPoint("RIGHT", -110, 0)
    read.days = UI.Text(read.panel, 11, "RIGHT", { 0.7, 0.65, 0.56 })
    read.days:SetPoint("TOPRIGHT", -20, -20)
    read.from = UI.Text(read.panel, 12, "LEFT", { 0.7, 0.65, 0.56 })
    read.from:SetPoint("TOPLEFT", read.subject, "BOTTOMLEFT", 0, -6)
    read.list = UI.ScrollArea(read.panel)
    read.list:SetPoint("TOPLEFT", read.from, "BOTTOMLEFT", 0, -14)
    read.list:SetPoint("BOTTOMRIGHT", -24, 90)
    read.body = UI.Text(read.list.child, 14, "LEFT", ns.PARCHMENT_TEXT)
    read.body:SetPoint("TOPLEFT")
    read.body:SetWordWrap(true)
    read.body:SetSpacing(4)
    read.attachLabel = UI.Text(read.panel, 12, "LEFT", UI.ACCENT)
    read.attachLabel:SetPoint("BOTTOMLEFT", 20, 66)
    read.money = UI.Button(read.panel, "", function() if openMail then TakeInboxMoney(openMail) end end, 140)
    read.money:SetHeight(40)
    read.money:SetPoint("BOTTOMLEFT", 20, 18)
    local back = UI.Button(read.frame, BACK or L["Back"], function() SetView("inbox") end, 90)
    back:SetHeight(30)
    back:SetPoint("BOTTOMLEFT")
    read.reply = AccentButton(read.frame, REPLY_MESSAGE or L["Reply"], function()
        local h = openMail and Header(openMail)
        SetView("send")
        if h then
            send.to:SetText(h.sender or "")
            send.subject:SetText(((h.subject or ""):find("^RE:") and "" or "RE: ") .. (h.subject or ""))
            send.body:SetFocus()
        end
    end, 110)
    read.reply:SetPoint("BOTTOMRIGHT")
    read.ret = UI.Button(read.frame, MAIL_RETURN or L["Return"], function()
        if openMail then ReturnInboxItem(openMail) end
        SetView("inbox")
    end, 120)
    read.ret:SetHeight(30)
    read.ret:SetPoint("RIGHT", read.reply, "LEFT", -8, 0)
    read.delete = UI.Button(read.frame, DELETE or L["Delete"], function()
        local h = openMail and Header(openMail)
        if not h then return end
        if h.money > 0 or h.hasItem then
            StaticPopup_Show("MEREDANUI_MAIL_DELETE", nil, nil, openMail)
        else
            DeleteInboxItem(openMail)
            SetView("inbox")
        end
    end, 90)
    read.delete:SetHeight(30)
    read.delete:SetPoint("RIGHT", read.reply, "LEFT", -8, 0)

    -- Send mail
    send.frame = ViewFrame()
    send.slots = {}
    send.to = UI.EditBox(send.frame, 30)
    send.to:SetPoint("TOPLEFT")
    send.to:SetWidth(200)
    send.to:SetAutoFocus(false)
    local toHint = UI.Text(send.to, 13, "LEFT", UI.MUTED)
    toHint:SetPoint("LEFT", 10, 0)
    toHint:SetText(L["To (name)"])
    send.subject = UI.EditBox(send.frame, 30)
    send.subject:SetPoint("LEFT", send.to, "RIGHT", 8, 0)
    send.subject:SetPoint("RIGHT", send.frame, "RIGHT")
    send.subject:SetMaxLetters(64)
    local subjectHint = UI.Text(send.subject, 13, "LEFT", UI.MUTED)
    subjectHint:SetPoint("LEFT", 10, 0)
    subjectHint:SetText(L["Subject"])
    send.to:HookScript("OnTextChanged", function(self)
        toHint:SetShown(self:GetText() == "")
        ShowContacts()
    end)
    send.to:HookScript("OnEditFocusGained", ShowContacts)
    send.to:HookScript("OnEditFocusLost", function() C_Timer.After(0.2, function() send.book:Hide() end) end)
    send.to:SetScript("OnTabPressed", function() send.subject:SetFocus() end)
    send.to:SetScript("OnEnterPressed", function() send.subject:SetFocus() end)
    send.subject:HookScript("OnTextChanged", function(self) subjectHint:SetShown(self:GetText() == "") end)
    send.subject:SetScript("OnTabPressed", function() send.body:SetFocus() end)
    send.subject:SetScript("OnEnterPressed", function() send.body:SetFocus() end)
    send.book = CreateFrame("Frame", nil, send.frame)
    send.book:SetPoint("TOPLEFT", send.to, "BOTTOMLEFT", 0, -2)
    send.book:SetPoint("TOPRIGHT", send.to, "BOTTOMRIGHT", 0, -2)
    send.book:SetFrameLevel(send.frame:GetFrameLevel() + 30)
    UI.Box(send.book, { 0.078, 0.078, 0.086, 1 })
    send.book.lines, send.book.buttons = {}, {}
    send.book:Hide()

    local paper = ns.CreateParchmentPanel(send.frame)
    paper:SetPoint("TOPLEFT", send.to, "BOTTOMLEFT", 0, -10)
    paper:SetPoint("RIGHT", send.frame, "RIGHT")
    paper:SetPoint("BOTTOM", send.frame, "BOTTOM", 0, 140)
    send.body = CreateFrame("EditBox", nil, paper)
    send.body:SetPoint("TOPLEFT", 16, -14)
    send.body:SetPoint("BOTTOMRIGHT", -16, 14)
    send.body:SetMultiLine(true)
    send.body:SetAutoFocus(false)
    send.body:SetMaxLetters(500)
    send.body:SetFont(ns.STYLE.font, ns.FontPx(14), "")
    send.body:SetTextColor(unpack(ns.PARCHMENT_TEXT))
    send.body:SetScript("OnEscapePressed", send.body.ClearFocus)
    paper:EnableMouse(true)
    paper:SetScript("OnMouseDown", function() send.body:SetFocus() end)

    local attachLabel = UI.Text(send.frame, 12, "LEFT", UI.ACCENT)
    attachLabel:SetPoint("TOPLEFT", paper, "BOTTOMLEFT", 0, -12)
    attachLabel:SetText(L["Attachments"])
    local prev = attachLabel
    for _, q in ipairs(QUICK) do
        local b = UI.Button(send.frame, "+ " .. L[q.label], function() QuickAttach(q.sub) end, 10)
        b:SetHeight(22)
        b:SetWidth(b.Text:GetUnboundedStringWidth() + 16)
        b:SetPoint("LEFT", prev, "RIGHT", prev == attachLabel and 10 or 6, 0)
        prev = b
    end
    local rightHint = UI.Text(send.frame, 11, "LEFT", UI.MUTED)
    rightHint:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    rightHint:SetText(L["Right-click in the bag attaches"])
    for i = 1, MAX_SEND do
        local slot = SendSlot(i)
        slot:SetPoint("TOPLEFT", attachLabel, "BOTTOMLEFT", (i - 1) * (SLOT + 6), -10)
    end

    local moneyLabel = UI.Text(send.frame, 12, "LEFT")
    moneyLabel:SetPoint("TOPLEFT", attachLabel, "BOTTOMLEFT", 0, -10 - SLOT - 14)
    moneyLabel:SetText(MONEY or L["Gold"])
    send.coins = {}
    local coinColors = { { 0.85, 0.69, 0.29 }, { 0.72, 0.74, 0.77 }, { 0.75, 0.48, 0.27 } }
    local last = moneyLabel
    for n = 1, 3 do
        local box = UI.EditBox(send.frame, 28)
        box:SetWidth(54)
        box:SetNumeric(true)
        box:SetMaxLetters(n == 1 and 6 or 2)
        box:SetJustifyH("RIGHT")
        box:SetPoint("LEFT", last, "RIGHT", n == 1 and 10 or 14, 0)
        local dot = box:CreateTexture(nil, "OVERLAY")
        dot:SetSize(9, 9)
        dot:SetPoint("LEFT", box, "RIGHT", 4, 0)
        dot:SetTexture("Interface\\COMMON\\Indicator-Gray")
        dot:SetVertexColor(unpack(coinColors[n]))
        send.coins[n] = box
        last = box
    end
    send.codButton = UI.Button(send.frame, "      " .. (COD or L["COD"]), function()
        send.cod = not send.cod
        send.codTick:SetShown(send.cod)
    end, 110)
    send.codButton:SetHeight(28)
    send.codButton:SetPoint("RIGHT", send.frame, "RIGHT")
    send.codButton:SetPoint("TOP", moneyLabel, "TOP", 0, 8)
    local box = CreateFrame("Frame", nil, send.codButton)
    box:SetSize(12, 12)
    box:SetPoint("LEFT", 12, 0)
    UI.CheckBg(box)
    send.codTick = UI.Icon(box, "Check", 10, UI.ACCENT)
    send.codTick:SetPoint("CENTER")

    send.price = UI.Text(send.frame, 12, "LEFT", UI.MUTED)
    send.price:SetPoint("BOTTOMLEFT", 0, 9)
    local sendButton = AccentButton(send.frame, SEND_LABEL or L["Send"], DoSend, 120)
    sendButton:SetPoint("BOTTOMRIGHT")
    send.gold = UI.Text(send.frame, 12, "RIGHT", UI.MUTED)
    send.gold:SetPoint("RIGHT", sendButton, "LEFT", -12, 0)

    window:HookScript("OnShow", function()
        view = "inbox"
        wipe(selected)
        ResetSend()
        SetSendMailShowing(false)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        inbox.list:ScrollToTop()
        Layout()
    end)
    window:HookScript("OnHide", function()
        StopOpening()
        send.book:Hide()
        SetSendMailShowing(false)
        StaticPopup_Hide("MEREDANUI_MAIL_DELETE")
        StaticPopup_Hide("MEREDANUI_MAIL_COD")
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        if ns.StillInteracting("MailInfo", MailFrame) then CloseMail() end -- only our own, still running interaction
    end)
end

StaticPopupDialogs["MEREDANUI_MAIL_DELETE"] = {
    text = L["Delete this mail with its attachments?"],
    button1 = YES, button2 = NO,
    OnAccept = function(_, index)
        DeleteInboxItem(index)
        if window then
            view = "inbox"
            window.Layout()
        end
    end,
    showAlert = 1, timeout = 0, hideOnEscape = 1,
}
StaticPopupDialogs["MEREDANUI_MAIL_COD"] = {
    text = L["Pay %s cash on delivery?"],
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function(_, data) TakeInboxItem(data.mail, data.index) end,
    timeout = 0, hideOnEscape = 1,
}

ns:On("PLAYER_LOGIN", function()
    -- Record own characters for the address book (even with the window disabled)
    local chars = Store()
    local _, class = UnitClass("player")
    chars[UnitName("player")] = class
    if not Enabled() then return end
    EventUtil.ContinueOnAddOnLoaded("Blizzard_MailFrame", function()
        if window or not MailFrame then return end
        CreateWindow()
        MailFrame:SetParent(hidden) -- park invisibly (Blizzard only checks IsShown)
        ns:On("MAIL_SHOW", function()
            C_Timer.After(0, function()
                if MailFrame:IsShown() then
                    window:SetNpc(nil, L["Mailbox"], INBOX, MAIL_ICON)
                    window:Show()
                end
            end)
        end)
        ns:On("MAIL_CLOSED", function() window:Hide() end)
        for _, event in ipairs({ "MAIL_INBOX_UPDATE", "MAIL_SEND_INFO_UPDATE", "PLAYER_MONEY" }) do
            ns:On(event, function() if window:IsShown() then Layout() end end)
        end
        ns:On("MAIL_SEND_SUCCESS", function()
            -- Remember recipient (recent list, max 10)
            local _, recent = Store()
            local to = send.pendingTo
            if to then
                for i = #recent, 1, -1 do if recent[i] == to then table.remove(recent, i) end end
                table.insert(recent, 1, to)
                while #recent > 10 do table.remove(recent) end
            end
            ResetSend()
            if window:IsShown() then Layout() end
        end)
        ns:On("MAIL_FAILED", function() if opening then StopOpening() end end)
        ns:On("UI_ERROR_MESSAGE", function(_, _, message)
            if opening and (message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT) then
                StopOpening(L["Bags are full – stopped opening mail."])
            end
        end)
    end)
end)
