-- Auction house - My Auctions tab: toggle between auctions and bids; bottom has "Repost" and
-- "Cancel auction", or for bids a bid field, Bid and Buyout.
local _, ns = ...
local L = ns.L
local AH = ns.AH

local owned = { mode = "auctions" }
AH.owned = owned

local SORTS = { { sortOrder = Enum.AuctionHouseSortOrder.Name, reverseSort = false }, { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }

local function Columns()
    return {
        { title = L["Item"] },
        { title = L["Qty"], width = 60, align = "RIGHT" },
        { title = BID or L["Bid"], width = 150, align = "RIGHT" },
        { title = BUYOUT or L["Buyout"], width = 150, align = "RIGHT" },
        { title = L["Time left"], width = 110, align = "RIGHT" },
    }
end

-- "24 h" like Blizzard, otherwise a rough tier
local function TimeText(seconds, band)
    if seconds and seconds > 0 then
        if seconds >= 3600 then return ("%d h"):format(math.floor(seconds / 3600)) end
        return ("%d min"):format(math.max(math.floor(seconds / 60), 1))
    end
    return AH.TimeLeftText(band)
end

local function ItemName(itemKey, link)
    local info = AH.KeyInfo(itemKey)
    if info then return info.itemName, info.iconFileID, info.quality end
    if link then
        local name, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(link)
        return name, icon, quality
    end
end

local function Rows()
    local rows = {}
    if owned.mode == "auctions" then
        for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
            local a = C_AuctionHouse.GetOwnedAuctionInfo(i)
            if a then rows[#rows + 1] = a end
        end
    else
        for i = 1, C_AuctionHouse.GetNumBids() do
            local b = C_AuctionHouse.GetBidInfo(i)
            if b then rows[#rows + 1] = b end
        end
    end
    return rows
end

function AH.RefreshOwned()
    if not owned.list then return end
    local UI = ns.UI
    local rows = Rows()
    local selected
    owned.list:Fill(rows, function(row, a)
        local name, icon, quality = ItemName(a.itemKey, a.itemLink)
        row.icon:SetTexture(icon or 134400)
        local sold = owned.mode == "auctions" and a.status == Enum.AuctionStatus.Sold
        row.cells[1]:SetText((name or "…") .. (sold and ("  |cff8ecbb4" .. L["Sold"] .. "|r") or ""))
        row.cells[1]:SetTextColor(AH.QualityColor(quality))
        row.cells[2]:SetText(a.quantity or 1)
        local bid = a.bidAmount
        if owned.mode == "bids" and a.bidder and a.bidder ~= UnitGUID("player") then
            bid = bid and ("|cffe65050" .. AH.Money(bid) .. "|r") -- outbid
        else
            bid = bid and AH.Money(bid) or "|cff99978f–|r"
        end
        row.cells[3]:SetText(bid)
        local buyout = a.buyoutAmount
        if buyout and owned.mode == "auctions" and (a.quantity or 1) > 1 and a.itemKey and
            C_AuctionHouse.GetItemCommodityStatus and AH.KeyInfo(a.itemKey) and AH.KeyInfo(a.itemKey).isCommodity then
            row.cells[4]:SetText(AH.Money(buyout) .. " |cff99978f" .. L["/ unit"] .. "|r")
        else
            row.cells[4]:SetText(buyout and AH.Money(buyout) or "|cff99978f–|r")
        end
        row.cells[5]:SetText(sold and "" or TimeText(a.timeLeftSeconds, a.timeLeft))
        local isSelected = owned.selected == a.auctionID
        row:SetSelected(isSelected)
        if isSelected then selected = a end
        row.OnHover = function(self)
            if not a.itemLink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(a.itemLink)
            GameTooltip:Show()
        end
        row:SetScript("OnClick", function()
            owned.selected = a.auctionID
            owned.bidTouched = false
            AH.RefreshOwned()
        end)
    end)
    owned.selectedInfo = selected
    owned.empty:SetText(owned.mode == "auctions" and L["You have no auctions."] or L["You have no bids."])
    owned.empty:SetShown(#rows == 0)
    -- toggle with counts
    owned.tabAuctions.Text:SetText(L["Auctions (%d)"]:format(C_AuctionHouse.GetNumOwnedAuctions()))
    owned.tabBids.Text:SetText(L["Bids (%d)"]:format(C_AuctionHouse.GetNumBids()))
    for _, t in ipairs({ owned.tabAuctions, owned.tabBids }) do
        local on = t.mode == owned.mode
        for _, edge in ipairs(t.active) do edge:SetShown(on) end
        t.Text:SetTextColor(unpack(on and UI.ACCENT or UI.TEXT))
    end
    AH.window.npcTitle:SetText(L["Auction house"] .. "  ·  " .. L["%d auctions · %d bids"]:format(C_AuctionHouse.GetNumOwnedAuctions(), C_AuctionHouse.GetNumBids()))
    -- bottom buttons
    local isAuctions = owned.mode == "auctions"
    owned.auctionButtons:SetShown(isAuctions)
    owned.bidButtons:SetShown(not isAuctions)
    if isAuctions then
        local canCancel = selected and selected.status ~= Enum.AuctionStatus.Sold and C_AuctionHouse.CanCancelAuction(selected.auctionID)
        owned.cancel:SetEnabled(canCancel and true or false)
        owned.cancel:SetAlpha(canCancel and 1 or 0.45)
        local canRelist = selected and AH.FindInBags(selected.itemKey and selected.itemKey.itemID) ~= nil
        owned.relist:SetEnabled(canRelist and true or false)
        owned.relist:SetAlpha(canRelist and 1 or 0.45)
    else
        local minBid = selected and selected.minBid
        if selected and not owned.bidTouched then owned.bid:SetValue(minBid or 0) end
        local canBid = selected and minBid ~= nil
        owned.bidButton:SetEnabled(canBid and true or false)
        owned.bidButton:SetAlpha(canBid and 1 or 0.45)
        local canBuy = selected and selected.buyoutAmount ~= nil
        owned.buyButton:SetEnabled(canBuy and true or false)
        owned.buyButton:SetAlpha(canBuy and 1 or 0.45)
        owned.buyButton.Text:SetText((BUYOUT or L["Buyout"]) .. (canBuy and ("  ·  " .. AH.Money(selected.buyoutAmount)) or ""))
    end
end

-- first bag slot with this item (for "Repost")
function AH.FindInBags(itemID)
    if not itemID then return end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and not info.isLocked then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if C_AuctionHouse.IsSellItemValid(loc, false) then return loc end
            end
        end
    end
end

local function Query()
    if owned.mode == "auctions" then
        C_AuctionHouse.QueryOwnedAuctions(SORTS)
    else
        C_AuctionHouse.QueryBids(SORTS, g_activeBidAuctionIDs or {})
    end
end

function AH.ShowOwned()
    Query()
    AH.RefreshOwned()
    AH.SetFooter(L["Cancelling loses the deposit."])
end

local function SetMode(mode)
    owned.mode = mode
    owned.selected = nil
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    Query()
    AH.RefreshOwned()
end

function AH.CreateOwnedView(view)
    local UI = ns.UI
    local function Toggle(mode, x)
        local t = UI.Button(view, "", function() SetMode(mode) end, 140)
        t:SetHeight(28)
        t:SetPoint("TOPLEFT", x, 0)
        t.mode = mode
        t.active = ns.AddBorder(t, true)
        for _, edge in ipairs(t.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        return t
    end
    owned.tabAuctions = Toggle("auctions", 0)
    owned.tabBids = Toggle("bids", 146)
    local refresh = AH.RefreshButton(view, Query)
    refresh:SetPoint("TOPRIGHT", -16, 0)

    owned.list = AH.List(view, Columns(), true)
    owned.list.header:SetPoint("TOPLEFT", 0, -38)
    owned.list.header:SetPoint("TOPRIGHT", -16, -38)
    owned.list.area:SetPoint("BOTTOMRIGHT", -16, 44)
    owned.empty = UI.Text(view, 13, "CENTER", UI.MUTED)
    owned.empty:SetPoint("TOP", owned.list.header, "BOTTOM", 0, -60)

    -- auctions: Repost, Cancel
    owned.auctionButtons = CreateFrame("Frame", nil, view)
    owned.auctionButtons:SetPoint("BOTTOMLEFT")
    owned.auctionButtons:SetPoint("BOTTOMRIGHT", -16, 0)
    owned.auctionButtons:SetHeight(30)
    owned.cancel = UI.Button(owned.auctionButtons, L["Cancel auction"], function()
        local a = owned.selectedInfo
        if a then
            if AH.MarkPendingCancel then AH.MarkPendingCancel(a.auctionID, (ItemName(a.itemKey, a.itemLink)), a.quantity) end
            StaticPopup_Show("CANCEL_AUCTION", nil, nil, { auctionID = a.auctionID })
        end
    end, 170)
    owned.cancel:SetHeight(30)
    owned.cancel:SetPoint("RIGHT")
    owned.cancel:SetMotionScriptsWhileDisabled(true)
    owned.relist = UI.Button(owned.auctionButtons, L["List again"], function()
        local a = owned.selectedInfo
        local loc = a and AH.FindInBags(a.itemKey and a.itemKey.itemID)
        if loc then
            AH.SelectTab("sell")
            AH.SetSellItem(loc)
        end
    end, 150)
    owned.relist:SetHeight(30)
    owned.relist:SetPoint("RIGHT", owned.cancel, "LEFT", -6, 0)
    owned.relist:SetMotionScriptsWhileDisabled(true)
    owned.relist:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["List again"], 1, 1, 1)
        GameTooltip:AddLine(L["Opens Sell with this item, if you still have it in your bags."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    owned.relist:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- bids: bid field, Bid, Buyout
    owned.bidButtons = CreateFrame("Frame", nil, view)
    owned.bidButtons:SetPoint("BOTTOMLEFT")
    owned.bidButtons:SetPoint("BOTTOMRIGHT", -16, 0)
    owned.bidButtons:SetHeight(30)
    local bidLabel = UI.Text(owned.bidButtons, 12, "LEFT", UI.MUTED)
    bidLabel:SetPoint("LEFT", 0, 0)
    bidLabel:SetText(L["Your bid"])
    owned.bid = AH.MoneyInput(owned.bidButtons, function() owned.bidTouched = true end)
    owned.bid:SetPoint("LEFT", bidLabel, "RIGHT", 10, 0)
    owned.bidButton = UI.Button(owned.bidButtons, BID or L["Bid"], function()
        local b = owned.selectedInfo
        if not b then return end
        local amount = owned.bid:GetValue()
        if b.buyoutAmount and amount >= b.buyoutAmount then
            StaticPopup_Show("BUYOUT_AUCTION", nil, nil, { auctionID = b.auctionID, buyout = b.buyoutAmount })
        elseif b.minBid and amount < b.minBid then
            UIErrorsFrame:AddExternalErrorMessage(AUCTION_HOUSE_BID_AMOUNT_IS_TOO_LOW or L["Bid is too low."])
        else
            StaticPopup_Show("BID_AUCTION", nil, nil, { auctionID = b.auctionID, bid = amount })
        end
    end, 90)
    owned.bidButton:SetHeight(30)
    owned.bidButton:SetPoint("LEFT", owned.bid, "RIGHT", 6, 0)
    owned.bidButton:SetMotionScriptsWhileDisabled(true)
    owned.buyButton = UI.Button(owned.bidButtons, BUYOUT or L["Buyout"], function()
        local b = owned.selectedInfo
        if b and b.buyoutAmount then
            StaticPopup_Show("BUYOUT_AUCTION", nil, nil, { auctionID = b.auctionID, buyout = b.buyoutAmount })
            if AH.MarkPendingBuyout then AH.MarkPendingBuyout(b, b.itemKey) end
        end
    end, 200)
    owned.buyButton:SetHeight(30)
    owned.buyButton:SetPoint("RIGHT")
    owned.buyButton:SetMotionScriptsWhileDisabled(true)
    for _, e in ipairs(ns.AddBorder(owned.buyButton, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end
end

local function Visible()
    return AH.window and AH.window:IsShown() and AH.current == "owned"
end
ns:On("OWNED_AUCTIONS_UPDATED", function() if Visible() then AH.RefreshOwned() end end)
ns:On("BIDS_UPDATED", function() if Visible() then AH.RefreshOwned() end end)
ns:On("BID_ADDED", function() if Visible() then Query() end end)
ns:On("AUCTION_CANCELED", function() if Visible() then owned.selected = nil Query() end end)
ns:On("ITEM_KEY_ITEM_INFO_RECEIVED", function() if Visible() then AH.RefreshOwned() end end)
