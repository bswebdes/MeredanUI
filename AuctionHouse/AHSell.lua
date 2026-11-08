-- Auction house - Sell tab. Left: bags; center: form with price suggestion, duration, buyout
-- mode and net calculation; right: current listings.
-- Profession tools are missing from the list while tool protection is on (Bags/ToolGuard.lua).
local _, ns = ...
local L = ns.L
local AH = ns.AH

local BAGS_W, OFFERS_W = 220, 250
local CUT = 0.05 -- AH cut; Blizzard has no API for it

local sell = { bagRows = {}, duration = 2, buyoutMode = true }
AH.sell = sell

local function IsCommodity(loc)
    local status = C_AuctionHouse.GetItemCommodityStatus(loc)
    return status == Enum.ItemCommodityStatus.Commodity
end

-- Bags: sellable items, grouped by item ---------------------------------------------------------

local function BagItems()
    local list, byKey = {}, {}
    local filter = strlower(strtrim(sell.filter and sell.filter:GetText() or ""))
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not info.isLocked then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                local protected = ns.db.protectTools ~= false and ns.IsProfessionTool and ns.IsProfessionTool(info.itemID)
                if not protected and C_Item.DoesItemExist(loc) and C_AuctionHouse.IsSellItemValid(loc, false) then
                    local key = IsCommodity(loc) and info.itemID or info.hyperlink
                    local entry = byKey[key]
                    if not entry then
                        local name = C_Item.GetItemNameByID(info.itemID) or info.itemName or ""
                        entry = { key = key, itemID = info.itemID, name = name, icon = info.iconFileID,
                            quality = info.quality, link = info.hyperlink, count = 0, bag = bag, slot = slot }
                        byKey[key] = entry
                        if filter == "" or strlower(name):find(filter, 1, true) then list[#list + 1] = entry end
                    end
                    entry.count = entry.count + (info.stackCount or 1)
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function RefreshBags()
    if not sell.bagArea then return end
    local UI = ns.UI
    local list = BagItems()
    local width = sell.bagArea:GetWidth()
    for i, entry in ipairs(list) do
        local row = sell.bagRows[i]
        if not row then
            row = AH.Row(sell.bagArea.child, { { title = "" }, { title = "", width = 40, align = "RIGHT" } }, true)
            sell.bagRows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 30)
        row:SetWidth(width)
        row.icon:SetTexture(entry.icon)
        row.cells[1]:SetText(entry.name)
        row.cells[1]:SetTextColor(AH.QualityColor(entry.quality))
        row.cells[2]:SetText(entry.count > 1 and entry.count or "")
        row.cells[2]:SetTextColor(unpack(UI.MUTED))
        row:SetSelected(sell.entry and sell.entry.key == entry.key)
        row.OnHover = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(entry.bag, entry.slot)
            GameTooltip:Show()
        end
        row:SetScript("OnClick", function()
            AH.SetSellItem(ItemLocation:CreateFromBagAndSlot(entry.bag, entry.slot))
        end)
        row:Show()
    end
    for i = #list + 1, #sell.bagRows do sell.bagRows[i]:Hide() end
    sell.bagArea.child:SetWidth(width)
    sell.bagArea:SetContentHeight(#list * 30)
    sell.bagEmpty:SetShown(#list == 0)
end

-- Form ------------------------------------------------------------------------------------------

local function Quantity()
    return math.max(tonumber(sell.quantity:GetText()) or 0, 0)
end

local function Durations()
    return { AUCTION_DURATION_ONE or "12 Std.", AUCTION_DURATION_TWO or "24 Std.", AUCTION_DURATION_THREE or "48 Std." }
end

-- Net: sale price - cut; the deposit is returned on sale
function AH.UpdateSellSummary()
    local entry = sell.entry
    if not entry then return end
    local qty = Quantity()
    local price = sell.price:GetValue()
    local total = sell.commodity and price * qty or price
    local deposit
    if sell.commodity then
        deposit = C_AuctionHouse.CalculateCommodityDeposit(entry.itemID, sell.duration, math.max(qty, 1))
    elseif C_Item.DoesItemExist(sell.location) then
        deposit = C_AuctionHouse.CalculateItemDeposit(sell.location, sell.duration, math.max(qty, 1))
    end
    deposit = deposit or 0
    local cut = math.floor(total * CUT)
    sell.totalText:SetText(AH.Money(total))
    sell.depositText:SetText(AH.Money(deposit))
    sell.cutText:SetText(total > 0 and ("− " .. GetMoneyString(cut, true)) or "–")
    sell.netText:SetText(total > 0 and AH.Money(total - cut) or "–")
    -- hint for per-unit price on non-stackables with quantity > 1
    local bid = (not sell.commodity and not sell.buyoutMode) and sell.bid:GetValue() or 0
    local valid = qty > 0 and qty <= (sell.max or 0)
    if sell.commodity then
        valid = valid and price > 0
    elseif sell.buyoutMode then
        valid = valid and price > 0
    else
        valid = valid and bid > 0 and (price == 0 or price >= bid)
    end
    valid = valid and GetMoney() >= deposit
    -- like Blizzard: only once the AH accepts requests again (briefly throttled after searches)
    local ready = C_AuctionHouse.IsThrottledMessageSystemReady()
    sell.post:SetEnabled(valid and ready)
    sell.post:SetAlpha((valid and ready) and 1 or 0.45)
    sell.post.Text:SetText(ready and L["Create auction"] or L["One moment …"])
end

local function SelectDuration(index)
    sell.duration = index
    ns.db.ahDuration = index
    for i, button in ipairs(sell.durationButtons) do
        for _, edge in ipairs(button.active) do edge:SetShown(i == index) end
        button.Text:SetTextColor(unpack(i == index and ns.UI.ACCENT or ns.UI.TEXT))
    end
    AH.UpdateSellSummary()
end

local function SetBuyoutMode(on)
    sell.buyoutMode = on
    sell.buyoutCheck:SetChecked(on)
    local itemOnly = not sell.commodity
    sell.bidLabel:SetShown(itemOnly and not on)
    sell.bid:SetShown(itemOnly and not on)
    sell.priceLabel:SetText(sell.commodity and L["Price / unit"]
        or (on and (BUYOUT or L["Buyout"]) or L["Buyout (optional)"]))
    AH.UpdateSellSummary()
end

-- Suggestion: 1 copper (or 1 silver) below the cheapest foreign listing.
-- Non-stackables only in whole silver (server rejects copper), commodities may use copper
local function ItemStep() return sell.commodity and AH.Step() or 100 end
local function RoundPrice(copper)
    if sell.commodity then return AH.Sanitize(copper) end
    -- like Auctionator (NormalizePrice): round up to silver, at least 1 silver
    return math.max(math.ceil((copper or 0) / 100) * 100, (copper or 0) > 0 and 100 or 0)
end

local function Suggest(lowest, ownLowest)
    if sell.touched then return end
    local price
    if lowest then price = math.max(lowest - ItemStep(), ItemStep())
    elseif ownLowest then price = ownLowest
    else price = ns.root.ahLastPrice and ns.root.ahLastPrice[sell.entry.itemID] end
    if price then
        sell.price:SetValue(RoundPrice(price))
        sell.hint:SetText(lowest and L["%s below the cheapest"]:format(GetMoneyString(ItemStep(), true))
            or (ownLowest and L["Your price is the cheapest"]) or L["Last price you used"])
    else
        sell.price:SetValue(0)
        sell.hint:SetText(L["No offers – choose a price"])
    end
    AH.UpdateSellSummary()
end

-- Listings (right) ------------------------------------------------------------------------------

local function RefreshOffers()
    local entry = sell.entry
    if not entry or not sell.offers then return end
    local rows, lowest, ownLowest, sellers = {}, nil, nil, 0
    if sell.commodity then
        for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(entry.itemID) do
            local r = C_AuctionHouse.GetCommoditySearchResultInfo(entry.itemID, i)
            if r then
                local own = (r.numOwnerItems or 0) > 0
                rows[#rows + 1] = { price = r.unitPrice, qty = r.quantity, own = own }
                if own then ownLowest = ownLowest or r.unitPrice
                elseif not lowest then lowest = r.unitPrice end
                sellers = sellers + (r.totalNumberOfOwners or 0)
            end
        end
        local total = C_AuctionHouse.GetCommoditySearchResultsQuantity(entry.itemID) or 0
        sell.offerCount:SetText(L["%d available"]:format(total))
    elseif sell.searchKey then
        for i = 1, C_AuctionHouse.GetNumItemSearchResults(sell.searchKey) do
            local r = C_AuctionHouse.GetItemSearchResultInfo(sell.searchKey, i)
            if r then
                local own = AH.IsOwn(r.owners)
                local price = r.buyoutAmount or r.bidAmount or r.minBid
                rows[#rows + 1] = { price = price, qty = r.quantity, own = own, bidOnly = not r.buyoutAmount }
                if r.buyoutAmount then
                    if own then ownLowest = ownLowest or r.buyoutAmount
                    elseif not lowest or r.buyoutAmount < lowest then lowest = r.buyoutAmount end
                end
            end
        end
        sell.offerCount:SetText(L["%d available"]:format(#rows))
    end
    local cheapestMarked = false
    sell.offers:Fill(rows, function(row, data)
        row.cells[1]:SetText(AH.Money(data.price) .. (data.bidOnly and ("  |cff99978f" .. (BID or L["Bid"]) .. "|r") or ""))
        row.cells[2]:SetText(data.qty)
        local chip = ""
        if data.own then chip = "|cff8ecbb4" .. L["You"] .. "|r"
        elseif not cheapestMarked and not data.bidOnly then chip = "|cffe9e6dd" .. L["Cheapest"] .. "|r" cheapestMarked = true end
        row.cells[3]:SetText(chip)
        row:SetSelected(false)
        row:SetScript("OnClick", function()
            -- take a listing's price (1 below it)
            if data.price then
                sell.touched = true
                sell.price:SetValue(RoundPrice(math.max(data.price - (data.own and 0 or ItemStep()), ItemStep())))
                sell.hint:SetText("")
                AH.UpdateSellSummary()
            end
        end)
    end)
    sell.offersEmpty:SetShown(#rows == 0)
    Suggest(lowest, ownLowest)
end

function AH.OnSellResults(itemKey, itemID)
    local entry = sell.entry
    if not entry or AH.current ~= "sell" then return end
    if sell.commodity and itemID == entry.itemID then RefreshOffers()
    elseif not sell.commodity and itemKey and itemKey.itemID == entry.itemID then
        sell.searchKey = itemKey
        RefreshOffers()
    end
end

local function QueryOffers()
    local entry = sell.entry
    if not entry then return end
    local key = C_AuctionHouse.GetItemKeyFromItem(sell.location)
    if not key then return end
    if sell.commodity then
        C_AuctionHouse.SendSearchQuery(key, { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }, false)
    else
        local info = C_AuctionHouse.GetItemKeyInfo(key)
        local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Buyout, reverseSort = false }, { sortOrder = Enum.AuctionHouseSortOrder.Bid, reverseSort = false } }
        if info and info.isEquipment then
            sell.searchKey = AuctionHouseUtil.ConvertItemSellItemKey(key)
            C_AuctionHouse.SendSellSearchQuery(sell.searchKey, sorts, false)
        else
            sell.searchKey = key
            C_AuctionHouse.SendSearchQuery(key, sorts, false)
        end
    end
end

-- Select item (list on the left, right-click in bags, drag into the slot)
function AH.SetSellItem(loc)
    if not (loc and C_Item.DoesItemExist(loc)) or not sell.form then return end
    if not C_AuctionHouse.IsSellItemValid(loc, true) then return end
    local itemID = C_Item.GetItemID(loc)
    if ns.db.protectTools ~= false and ns.IsProfessionTool and ns.IsProfessionTool(itemID) then
        UIErrorsFrame:AddMessage(L["%s is a profession tool and protected."]:format(C_Item.GetItemName(loc) or ""), 1, 0.35, 0.3)
        return
    end
    local bag, slot = loc:GetBagAndSlot()
    local link = C_Item.GetItemLink(loc)
    sell.location = loc
    sell.commodity = IsCommodity(loc)
    sell.entry = { key = sell.commodity and itemID or link, itemID = itemID, bag = bag, slot = slot, link = link }
    sell.searchKey = nil
    sell.touched = false
    sell.max = C_AuctionHouse.GetAvailablePostCount(loc) or 1
    local name = C_Item.GetItemName(loc) or ""
    local quality = C_Item.GetItemQuality(loc)
    sell.icon:SetTexture(C_Item.GetItemIcon(loc))
    sell.name:SetText(name)
    sell.name:SetTextColor(AH.QualityColor(quality))
    local vendor = select(11, C_Item.GetItemInfo(itemID))
    sell.sub:SetText(L["%d in your bags"]:format(sell.max)
        .. (vendor and vendor > 0 and ("  ·  " .. L["Vendor pays %s"]:format(GetMoneyString(vendor, true))) or ""))
    sell.quantity:SetText(tostring(sell.commodity and sell.max or 1))
    sell.perUnit:SetShown(sell.commodity)
    sell.price:SetCopperShown(sell.commodity)
    sell.bid:SetCopperShown(false)
    sell.buyoutRow:SetShown(not sell.commodity)
    sell.bid:SetValue(0)
    SetBuyoutMode(sell.commodity or ns.db.ahBuyoutMode ~= false)
    sell.formContent:Show()
    sell.formEmpty:Hide()
    sell.offers.rows = sell.offers.rows or {}
    sell.offers:Fill({}, function() end)
    sell.offerCount:SetText("")
    sell.hint:SetText(L["Loading …"])
    RefreshBags()
    QueryOffers()
end

local function ClearSell()
    sell.entry, sell.location, sell.searchKey = nil, nil, nil
    if not sell.form then return end
    sell.formContent:Hide()
    sell.formEmpty:Show()
    sell.offers:Fill({}, function() end)
    sell.offersEmpty:Hide()
    sell.offerCount:SetText("")
end

-- Posting (with Blizzard's confirmation on unusual prices) ---------------------------------------

local pending
local function DoPost(confirm)
    local p = pending
    if not p then return end
    local needsConfirm
    if p.commodity then
        if confirm then C_AuctionHouse.ConfirmPostCommodity(p.loc, p.duration, p.qty, p.price)
        else needsConfirm = C_AuctionHouse.PostCommodity(p.loc, p.duration, p.qty, p.price) end
    else
        if confirm then C_AuctionHouse.ConfirmPostItem(p.loc, p.duration, p.qty, p.bid, p.buyout)
        else needsConfirm = C_AuctionHouse.PostItem(p.loc, p.duration, p.qty, p.bid, p.buyout) end
    end
    -- debug log (DevLog addon in the workspace, otherwise nothing)
    if DevLog then
        DevLog("MeredanUI", ("AH post %s: loc=%s dur=%s qty=%s price=%s bid=%s buyout=%s copper=%s valid=%s ready=%s confirm=%s -> %s"):format(
            p.commodity and "commodity" or "item", tostring(p.loc and p.loc:IsValid() and table.concat({ p.loc:GetBagAndSlot() }, "/")),
            tostring(p.duration), tostring(p.qty), tostring(p.price), tostring(p.bid), tostring(p.buyout),
            tostring(C_AuctionHouse.SupportsCopperValues()), tostring(C_AuctionHouse.IsSellItemValid(p.loc, false)), tostring(C_AuctionHouse.IsThrottledMessageSystemReady()),
            tostring(confirm), tostring(needsConfirm)))
    end
    if needsConfirm then return end -- AUCTION_HOUSE_POST_WARNING follows
end

StaticPopupDialogs["MEREDANUI_AH_POST_WARNING"] = {
    text = CONFIRM_AUCTION_POSTING_TEXT or "Dieser Preis weicht stark vom Marktpreis ab. Trotzdem einstellen?",
    button1 = ACCEPT or OKAY,
    button2 = CANCEL,
    OnAccept = function() DoPost(true) end,
    showAlert = true,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
}

local function Post()
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then return end
    local entry = sell.entry
    if not entry or not C_Item.DoesItemExist(sell.location) then return end
    local qty = Quantity()
    local price = RoundPrice(sell.price:GetValue())
    pending = { loc = sell.location, duration = sell.duration, qty = qty, commodity = sell.commodity,
        itemID = entry.itemID, name = C_Item.GetItemName(sell.location) or "" }
    if sell.commodity then
        pending.price = price
        pending.deposit = C_AuctionHouse.CalculateCommodityDeposit(entry.itemID, sell.duration, qty) or 0
    else
        if sell.buyoutMode then
            pending.buyout = price
        else
            pending.bid = RoundPrice(sell.bid:GetValue())
            pending.buyout = price > 0 and price or nil
        end
        pending.deposit = C_AuctionHouse.CalculateItemDeposit(sell.location, sell.duration, qty) or 0
    end
    ns.root.ahLastPrice = ns.root.ahLastPrice or {}
    ns.root.ahLastPrice[entry.itemID] = price > 0 and price or nil
    DoPost(false)
end

ns:On("AUCTION_HOUSE_POST_WARNING", function()
    if AH.window and AH.window:IsShown() and pending then StaticPopup_Show("MEREDANUI_AH_POST_WARNING") end
end)
ns:On("AUCTION_HOUSE_POST_ERROR", function()
    if AH.window and AH.window:IsShown() then
        UIErrorsFrame:AddExternalErrorMessage(AUCTION_POSTING_ERROR_TEXT or L["The auction could not be created."])
    end
end)
ns:On("AUCTION_HOUSE_AUCTION_CREATED", function(_, auctionID)
    if not (AH.window and AH.window:IsShown()) then return end
    ChatFrameUtil.AddSystemMessage(ERR_AUCTION_STARTED)
    PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN or SOUNDKIT.LOOT_WINDOW_COIN_SOUND)
    if pending and AH.RecordPosted then AH.RecordPosted(auctionID, pending) end
    pending = nil
    -- same item still there? Keep it selected, otherwise clear
    C_Timer.After(0.3, function()
        if AH.current ~= "sell" then return end
        local entry = sell.entry
        if entry and sell.location and C_Item.DoesItemExist(sell.location) then
            AH.SetSellItem(sell.location)
        else
            ClearSell()
            RefreshBags()
        end
    end)
end)

-- Setup -----------------------------------------------------------------------------------------

function AH.CreateSellView(view)
    local UI = ns.UI
    -- bags
    local bags = AH.Panel(view)
    bags:SetPoint("TOPLEFT")
    bags:SetPoint("BOTTOMLEFT")
    bags:SetWidth(BAGS_W)
    sell.filter = UI.EditBox(bags, 28)
    sell.filter:SetPoint("TOPLEFT", 6, -6)
    sell.filter:SetPoint("TOPRIGHT", -6, -6)
    sell.filter:SetScript("OnTextChanged", function() RefreshBags() end)
    sell.filter:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local filterHint = UI.Text(sell.filter, 12, "LEFT", { 0.47, 0.46, 0.43 })
    filterHint:SetPoint("LEFT", 10, 0)
    filterHint:SetText(L["Search bags"])
    sell.filter:HookScript("OnTextChanged", function(self) filterHint:SetShown(self:GetText() == "") end)
    sell.bagArea = UI.ScrollArea(bags)
    sell.bagArea:SetPoint("TOPLEFT", 2, -40)
    sell.bagArea:SetPoint("BOTTOMRIGHT", -14, 4)
    sell.bagEmpty = UI.Text(bags, 12, "CENTER", UI.MUTED)
    sell.bagEmpty:SetPoint("TOP", 0, -70)
    sell.bagEmpty:SetWidth(BAGS_W - 30)
    sell.bagEmpty:SetWordWrap(true)
    sell.bagEmpty:SetText(L["Nothing in your bags can be sold here."])

    -- listings
    local offersFrame = CreateFrame("Frame", nil, view)
    offersFrame:SetPoint("TOPRIGHT")
    offersFrame:SetPoint("BOTTOMRIGHT")
    offersFrame:SetWidth(OFFERS_W)
    sell.offerCount = UI.Text(offersFrame, 12, "LEFT", UI.MUTED)
    sell.offerCount:SetPoint("TOPLEFT", 2, -8)
    local refresh = AH.RefreshButton(offersFrame, QueryOffers)
    refresh:SetPoint("TOPRIGHT", -16, 0)
    sell.offers = AH.List(offersFrame, {
        { title = L["Price / unit"], width = 120 }, { title = L["Qty"], width = 50, align = "RIGHT" }, { title = "" },
    })
    sell.offers.header:SetPoint("TOPLEFT", 0, -34)
    sell.offers.header:SetPoint("TOPRIGHT", -16, -34)
    sell.offers.area:SetPoint("BOTTOMRIGHT", -16, 0)
    sell.offersEmpty = UI.Text(offersFrame, 12, "CENTER", UI.MUTED)
    sell.offersEmpty:SetPoint("TOP", sell.offers.header, "BOTTOM", 0, -30)
    sell.offersEmpty:SetText(L["No offers right now."])
    sell.offersEmpty:Hide()

    -- form
    local form = AH.Panel(view)
    form:SetPoint("TOPLEFT", bags, "TOPRIGHT", 10, 0)
    form:SetPoint("BOTTOMRIGHT", offersFrame, "BOTTOMLEFT", -10, 0)
    sell.form = form
    sell.formEmpty = UI.Text(form, 13, "CENTER", UI.MUTED)
    sell.formEmpty:SetPoint("CENTER")
    sell.formEmpty:SetWidth(260)
    sell.formEmpty:SetWordWrap(true)
    sell.formEmpty:SetText(L["Click an item on the left, right-click it in your bags or drag it here."])
    local content = CreateFrame("Frame", nil, form)
    content:SetAllPoints()
    content:Hide()
    sell.formContent = content
    -- drag into the form
    local function Drop()
        local kind, _, _ = GetCursorInfo()
        if kind ~= "item" then return end
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.isLocked then
                    ClearCursor()
                    AH.SetSellItem(ItemLocation:CreateFromBagAndSlot(bag, slot))
                    return
                end
            end
        end
    end
    form:EnableMouse(true)
    form:SetScript("OnReceiveDrag", Drop)
    form:SetScript("OnMouseUp", Drop)

    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(44, 44)
    holder:SetPoint("TOPLEFT", 16, -16)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    sell.icon = holder:CreateTexture(nil, "ARTWORK")
    sell.icon:SetAllPoints()
    sell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder:EnableMouse(true)
    holder:SetScript("OnEnter", function(self)
        if not sell.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(sell.entry.bag, sell.entry.slot)
        GameTooltip:Show()
    end)
    holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    sell.name = UI.Text(content, 16, "LEFT")
    ns.SetFont(sell.name, 16, "", "bold")
    sell.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 12, -4)
    sell.name:SetPoint("RIGHT", -16, 0)
    sell.name:SetWordWrap(false)
    sell.sub = UI.Text(content, 12, "LEFT", UI.MUTED)
    sell.sub:SetPoint("TOPLEFT", sell.name, "BOTTOMLEFT", 0, -5)

    local LABEL_X, FIELD_X = 16, 150
    local function Label(text, y)
        local label = UI.Text(content, 13, "LEFT", UI.MUTED)
        label:SetPoint("TOPLEFT", LABEL_X, y)
        label:SetText(text)
        return label
    end
    local y = -84
    Label(L["Quantity"], y - 8)
    sell.quantity = UI.EditBox(content, 30)
    sell.quantity:SetNumeric(true)
    sell.quantity:SetMaxLetters(5)
    sell.quantity:SetWidth(80)
    sell.quantity:SetPoint("TOPLEFT", FIELD_X, y)
    sell.quantity:SetScript("OnTextChanged", function(_, user) if user then AH.UpdateSellSummary() end end)
    sell.quantity:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local max = UI.Button(content, L["Max"], function()
        sell.quantity:SetText(tostring(sell.max or 1))
        AH.UpdateSellSummary()
    end, 56)
    max:SetHeight(30)
    max:SetPoint("LEFT", sell.quantity, "RIGHT", 6, 0)

    y = y - 42
    sell.priceLabel = Label(L["Price / unit"], y - 8)
    sell.price = AH.MoneyInput(content, function() sell.touched = true sell.hint:SetText("") AH.UpdateSellSummary() end)
    sell.price:SetPoint("TOPLEFT", FIELD_X, y)
    sell.perUnit = UI.Text(content, 12, "LEFT", UI.MUTED)
    sell.perUnit:SetPoint("LEFT", sell.price, "RIGHT", 8, 0)
    sell.perUnit:SetText(L["/ unit"])
    sell.hint = UI.Text(content, 11, "LEFT", UI.ACCENT)
    sell.hint:SetPoint("TOPLEFT", FIELD_X, y - 34)

    y = y - 56
    sell.bidLabel = Label(BID or L["Bid"], y - 8)
    sell.bid = AH.MoneyInput(content, function() AH.UpdateSellSummary() end)
    sell.bid:SetPoint("TOPLEFT", FIELD_X, y)

    y = y - 42
    Label(L["Duration"], y - 8)
    sell.durationButtons = {}
    for i, text in ipairs(Durations()) do
        local button = UI.Button(content, text, function() SelectDuration(i) end, 76)
        button:SetHeight(30)
        button:SetPoint("TOPLEFT", FIELD_X + (i - 1) * 82, y)
        button.active = ns.AddBorder(button, true)
        for _, edge in ipairs(button.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        sell.durationButtons[i] = button
    end

    y = y - 44
    sell.buyoutRow = CreateFrame("Frame", nil, content)
    sell.buyoutRow:SetPoint("TOPLEFT", LABEL_X, y)
    sell.buyoutRow:SetSize(300, 22)
    sell.buyoutCheck = UI.LabelCheck(sell.buyoutRow, L["Buyout mode"], function(_, on)
        ns.db.ahBuyoutMode = on
        SetBuyoutMode(on)
    end)
    if sell.buyoutCheck then sell.buyoutCheck:SetPoint("LEFT") end
    local buyoutHint = UI.Text(sell.buyoutRow, 11, "LEFT", UI.MUTED)
    buyoutHint:SetPoint("TOPLEFT", 0, -24)
    buyoutHint:SetText(L["Off: extra bid price, buyout optional"])

    -- net calculation
    local summary = CreateFrame("Frame", nil, content)
    summary:SetPoint("BOTTOMLEFT", 16, 60)
    summary:SetPoint("BOTTOMRIGHT", -16, 60)
    summary:SetHeight(104)
    UI.Box(summary, { 0.098, 0.098, 0.106, 1 })
    local function Line(text, i, bold)
        local label = UI.Text(summary, 13, "LEFT", bold and UI.TEXT or UI.MUTED)
        label:SetPoint("TOPLEFT", 12, -10 - (i - 1) * 22)
        label:SetText(text)
        local value = UI.Text(summary, 13, "RIGHT")
        value:SetPoint("TOPRIGHT", -12, -10 - (i - 1) * 22)
        if bold then ns.SetFont(value, 14, "", "bold") ns.SetFont(label, 13, "", "bold") end
        return value
    end
    sell.totalText = Line(L["Total sale price"], 1)
    sell.depositText = Line(L["Deposit (back when sold)"], 2)
    sell.cutText = Line(L["Auction house cut 5 %"], 3)
    sell.netText = Line(L["You get"], 4, true)

    sell.post = UI.Button(content, L["Create auction"], Post, 220)
    sell.post:SetHeight(32)
    sell.post:SetPoint("BOTTOM", 0, 16)
    sell.post:SetMotionScriptsWhileDisabled(true)
    for _, e in ipairs(ns.AddBorder(sell.post, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end

    SelectDuration(ns.db.ahDuration or 2)
end

function AH.ShowSell()
    RefreshBags()
    if sell.entry and sell.location and C_Item.DoesItemExist(sell.location) then
        AH.SetSellItem(sell.location)
    else
        ClearSell()
    end
    AH.SetFooter(L["Right-click an item in your bags to sell it"])
end

ns:On("BAG_UPDATE_DELAYED", function()
    if AH.window and AH.window:IsShown() and AH.current == "sell" then RefreshBags() end
end)

-- Throttle over / request sent: re-evaluate the button (like Blizzard's sell frame)
local function ThrottleChanged()
    if AH.window and AH.window:IsShown() and AH.current == "sell" and sell.entry then AH.UpdateSellSummary() end
end
ns:On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", ThrottleChanged)
ns:On("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", ThrottleChanged)
