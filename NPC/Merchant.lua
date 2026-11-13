-- Merchant (WoW Forever): bag-styled window replacing Blizzard's MerchantFrame; item cards in two
-- scrolling columns, footer with repair all / sell junk / gold. Controls match Blizzard: right-click
-- buys, left-click picks up, shift-click picks a quantity, ctrl-click dresses up, dropping an item sells.
-- MerchantFrame is parked invisibly (OnShow/OnHide do not fire), so our window calls CloseMerchant.
local _, ns = ...
local L = ns.L

local WIDTH = 640
local PAD = 18
local CARD_H, CARD_GAP = 58, 8
local ICON = 40
local REPAIR_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local JUNK_ICON = "Interface\\Icons\\INV_Misc_Bag_10"

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, searchBox, gold, repairButton, junkButton, emptyText
local tabs = {}
local cards = {}
local view = "shop" -- "shop" or "buyback"

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.merchantWindow ~= false and ns.ModuleOn("bags")
end

local function QualityColor(quality)
    if quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

-- Grey line under the name, e.g. "Cloth - Chest - Level 5" or "Trade Goods - 5 per purchase"
local function SubLine(link, stackCount)
    if not link then return "" end
    local _, itemType, subType, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
    local parts = {}
    if classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
        if subType and subType ~= "" then parts[#parts + 1] = subType end
        local slot = equipLoc and equipLoc ~= "" and _G[equipLoc]
        if slot and slot ~= subType then parts[#parts + 1] = slot end
    elseif itemType and itemType ~= "" then
        parts[#parts + 1] = itemType
    end
    local minLevel = select(5, C_Item.GetItemInfo(link))
    if minLevel and minLevel > 1 then parts[#parts + 1] = L["Level %d"]:format(minLevel) end
    if stackCount and stackCount > 1 then parts[#parts + 1] = L["%d per purchase"]:format(stackCount) end
    return table.concat(parts, " · ")
end

-- Price as coin string, plus currency icons for extended-cost items
local function PriceText(index, price, extended)
    local text = ""
    if price and price > 0 then text = GetMoneyString(price, true) end
    if extended then
        for i = 1, (GetMerchantItemCostInfo(index) or 0) do
            local texture, value = GetMerchantItemCostItem(index, i)
            if texture and value then
                text = text .. (text ~= "" and "  " or "") .. value .. " |T" .. texture .. ":0|t"
            end
        end
    end
    return text
end

-- Card -------------------------------------------------------------------------------------------

-- Cursor like Blizzard: buy (red if unaffordable), buyback, dress-up with ctrl
local function UpdateCursor(card)
    if not card.index then return end
    if IsModifiedClick("DRESSUP") then
        ShowInspectCursor()
    elseif view == "shop" then
        SetCursor(CanAffordMerchantItem(card.index) == false and "BUY_ERROR_CURSOR" or "BUY_CURSOR")
    else
        ShowBuybackSellCursor(card.index)
    end
end

local function CardEnter(card)
    card.hover:Show()
    if not card.index then return end
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    if view == "shop" then
        GameTooltip:SetMerchantItem(card.index)
        GameTooltip_ShowCompareItem(GameTooltip)
    else
        GameTooltip:SetBuybackItem(card.index)
    end
    GameTooltip:Show()
    UpdateCursor(card)
    card:SetScript("OnUpdate", UpdateCursor) -- modifier/gold can change while hovering
end

local function CardLeave(card)
    card.hover:Hide()
    card:SetScript("OnUpdate", nil)
    GameTooltip:Hide()
    ResetCursor()
end

local function Buy(card, quantity)
    if card.extended then
        MerchantFrame_ConfirmExtendedItemCost(card, quantity)
    elseif card.price and card.price >= (MERCHANT_HIGH_PRICE_COST or 1500000) then
        MerchantFrame_ConfirmHighCostItem(card, quantity)
    else
        BuyMerchantItem(card.index, quantity)
    end
end

local function CardClick(card, button)
    if not card.index then return end
    if view == "buyback" then
        BuybackItem(card.index)
        return
    end
    if HandleModifiedItemClick(card.link) then return end
    if IsModifiedClick("SPLITSTACK") then
        local maxStack = GetMerchantItemMaxStack(card.index)
        if maxStack and maxStack > 1 then
            StackSplitFrame:OpenStackSplitFrame(maxStack, card, "BOTTOMLEFT", "TOPLEFT", card.count)
            return
        end
    end
    if button == "RightButton" then
        Buy(card)
    else
        PickupMerchantItem(card.index) -- dropping into a bag buys (like Blizzard)
    end
end

-- Dropping an item on the window or a card sells it
local function SellCursorItem()
    if CursorHasItem() then PickupMerchantItem(0) end
end

local function Card(i)
    if cards[i] then return cards[i] end
    local UI = ns.UI
    local card = CreateFrame("Button", nil, list.child)
    card:SetHeight(CARD_H)
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card:RegisterForDrag("LeftButton")
    UI.Box(card, { 0.098, 0.098, 0.106, 1 })
    card.hover = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.hover:SetAllPoints()
    card.hover:SetColorTexture(1, 1, 1, 0.04)
    card.hover:Hide()

    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("LEFT", 9, 0)
    ns.AddSlotBackground(holder)
    card.border = ns.AddBorder(holder)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = 1
    card.countText = ns.CreateText(holder, 11, "RIGHT", "OUTLINE")
    card.countText:SetPoint("BOTTOMRIGHT", -2, 2)

    card.price = nil
    card.priceText = UI.Text(card, 12, "RIGHT")
    card.priceText:SetPoint("RIGHT", -10, 0)
    card.name = UI.Text(card, 13, "LEFT")
    card.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -3)
    card.name:SetPoint("RIGHT", card.priceText, "LEFT", -8, 0)
    card.sub = UI.Text(card, 11, "LEFT", UI.MUTED)
    card.sub:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", 10, 3)
    card.sub:SetPoint("RIGHT", card.priceText, "LEFT", -8, 0)

    card:SetScript("OnEnter", CardEnter)
    card:SetScript("OnLeave", CardLeave)
    card:SetScript("OnClick", CardClick)
    card:SetScript("OnDragStart", function(self)
        if view == "shop" and self.index then PickupMerchantItem(self.index) end
    end)
    card:SetScript("OnReceiveDrag", SellCursorItem)
    -- Shift-click: Blizzard's StackSplitFrame calls SplitStack
    card.SplitStack = function(self, amount)
        if amount and amount > 0 then Buy(self, amount) end
    end
    card.GetID = function(self) return self.index end -- needed by Blizzard's confirmation dialogs
    cards[i] = card
    return card
end

local function Fill(card, entry)
    card.index = entry.index
    card.link = entry.link
    card.price = entry.price
    card.extended = entry.extended
    card.count = entry.count or 1
    card.icon:SetTexture(entry.texture)
    -- Unusable: red icon like Blizzard
    if entry.usable == false then card.icon:SetVertexColor(1, 0.25, 0.25) else card.icon:SetVertexColor(1, 1, 1) end
    card.countText:SetText(card.count > 1 and card.count or "")
    local r, g, b = QualityColor(entry.quality)
    card.name:SetText(entry.name or "")
    card.name:SetTextColor(r, g, b)
    local edge = (entry.quality and entry.quality >= Enum.ItemQuality.Uncommon) and { r, g, b } or { 0, 0, 0 }
    for _, e in ipairs(card.border) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
    card.sub:SetText(entry.sub or "")
    card.priceText:SetText(entry.priceText or "")
    if entry.tooExpensive then card.priceText:SetTextColor(1, 0.3, 0.3) else card.priceText:SetTextColor(unpack(ns.UI.TEXT)) end
end

-- Build -------------------------------------------------------------------------------------------

local function ShopEntries(query)
    local entries = {}
    local money = GetMoney()
    for index = 1, GetMerchantNumItems() do
        local info = C_MerchantFrame.GetItemInfo(index)
        if info and info.name then
            local link = GetMerchantItemLink(index)
            if query == "" or info.name:lower():find(query, 1, true) then
                local stock = info.numAvailable and info.numAvailable >= 0 and info.numAvailable
                local sub = SubLine(link, info.stackCount)
                if stock then sub = sub .. (sub ~= "" and " · " or "") .. L["%d left"]:format(stock) end
                entries[#entries + 1] = {
                    index = index, link = link, name = info.name, texture = info.texture, price = info.price,
                    count = info.stackCount, usable = info.isUsable, extended = info.hasExtendedCost,
                    quality = link and C_Item.GetItemQualityByID(link), sub = sub,
                    priceText = PriceText(index, info.price, info.hasExtendedCost),
                    tooExpensive = info.price and info.price > money,
                }
            end
        end
    end
    return entries
end

local function BuybackEntries(query)
    local entries = {}
    for index = 1, GetNumBuybackItems() do
        local name, texture, price, quantity, _, isUsable = GetBuybackItemInfo(index)
        if name and (query == "" or name:lower():find(query, 1, true)) then
            local link = GetBuybackItemLink(index)
            entries[#entries + 1] = {
                index = index, link = link, name = name, texture = texture, price = price, count = quantity,
                usable = isUsable, quality = link and C_Item.GetItemQualityByID(link), sub = SubLine(link),
                priceText = price and price > 0 and GetMoneyString(price, true) or "",
                tooExpensive = price and price > GetMoney(),
            }
        end
    end
    return entries
end

local function UpdateFooter()
    local UI = ns.UI
    local cost, canRepair = GetRepairAllCost()
    local repairable = CanMerchantRepair() and canRepair and cost and cost > 0
    repairButton:SetShown(CanMerchantRepair())
    -- Without repair, "Sell junk" moves left
    junkButton:ClearAllPoints()
    if repairButton:IsShown() then
        junkButton:SetPoint("LEFT", repairButton, "RIGHT", 8, 0)
    else
        junkButton:SetPoint("BOTTOMLEFT", PAD, 14)
    end
    repairButton.extra:SetText(repairable and GetMoneyString(cost, true) or "")
    repairButton:SetEnabled(repairable and true or false)
    repairButton.label:SetTextColor(unpack(repairable and UI.TEXT or UI.MUTED))
    local junk = C_MerchantFrame.GetNumJunkItems and C_MerchantFrame.GetNumJunkItems() or 0
    junkButton.extra:SetText(junk > 0 and junk or "")
    junkButton:SetEnabled(junk > 0)
    junkButton.label:SetTextColor(unpack(junk > 0 and UI.TEXT or UI.MUTED))
    gold:SetText(GetMoneyString(GetMoney(), true))
end

local function UpdateTabs()
    local UI = ns.UI
    for key, tab in pairs(tabs) do
        local active = key == view
        tab.text:SetTextColor(unpack(active and UI.TITLE or UI.MUTED))
        tab.line:SetShown(active)
    end
end

local function Layout()
    if not (window and window:IsShown()) then return end
    UpdateTabs()
    local query = searchBox:GetText():lower()
    local entries = view == "shop" and ShopEntries(query) or BuybackEntries(query)
    local width = (WIDTH - 2 * PAD - CARD_GAP) / 2
    for i, entry in ipairs(entries) do
        local card = Card(i)
        Fill(card, entry)
        card:SetWidth(width)
        card:ClearAllPoints()
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        card:SetPoint("TOPLEFT", list.child, "TOPLEFT", col * (width + CARD_GAP), -row * (CARD_H + CARD_GAP))
        card:Show()
    end
    for i = #entries + 1, #cards do
        cards[i]:Hide()
        cards[i].index = nil
    end
    local rows = math.ceil(#entries / 2)
    list:SetContentHeight(rows * CARD_H + math.max(rows - 1, 0) * CARD_GAP)
    emptyText:SetShown(#entries == 0)
    emptyText:SetText(view == "buyback" and L["Nothing sold yet."] or L["Nothing found."])
    UpdateFooter()
end

local pending
local function Refresh()
    if not (window and window:IsShown()) or pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        Layout()
    end)
end

-- Footer button with icon, label and extra text (cost/count)
local function FooterButton(icon, label, onClick)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, window)
    button:SetHeight(30)
    local bg = UI.Box(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(18, 18)
    button.icon:SetPoint("LEFT", 6, 0)
    button.icon:SetTexture(icon)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.label = UI.Text(button, 12, "LEFT")
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
    button.label:SetText(label)
    button.extra = UI.Text(button, 12, "LEFT", UI.MUTED)
    button.extra:SetPoint("LEFT", button.label, "RIGHT", 8, 0)
    button:SetScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
    button:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    button:SetScript("OnClick", onClick)
    function button:Fit()
        self:SetWidth(6 + 18 + 8 + self.label:GetUnboundedStringWidth() + 8 + self.extra:GetUnboundedStringWidth() + 12)
    end
    hooksecurefunc(button.extra, "SetText", function() button:Fit() end)
    button:Fit()
    return button
end

local function CreateWindow()
    local UI = ns.UI
    -- Shared NPC header (NPC/NpcWindow.lua): portrait, name, title, close, draggable
    window = ns.CreateNpcWindow("MeredanUIMerchant", WIDTH, ns.NPC_HEIGHT, "merchant")
    ns.WatchBlizzardFrame(window, function() return MerchantFrame end)
    -- Dropping an item on the window sells it (like Blizzard)
    window:SetScript("OnReceiveDrag", SellCursorItem)
    window:SetScript("OnMouseUp", SellCursorItem)

    -- Tabs below the header
    local previous
    for _, entry in ipairs({ { "shop", MERCHANT or L["Merchant"] }, { "buyback", BUYBACK or L["Buyback"] } }) do
        local key, label = entry[1], entry[2]
        local tab = CreateFrame("Button", nil, window)
        tab.text = UI.Title(tab, 15, "LEFT")
        tab.text:SetPoint("LEFT", 14, 0)
        tab.text:SetText(label)
        tab:SetSize(tab.text:GetUnboundedStringWidth() + 16, 22)
        tab.line = UI.Diamond(tab, 6) -- rune look: accent diamond marks the active tab
        tab.line:SetPoint("LEFT", 2, 0)
        tab:SetScript("OnEnter", function(self) if view ~= key then self.text:SetTextColor(unpack(UI.TEXT)) end end)
        tab:SetScript("OnLeave", UpdateTabs)
        tab:SetScript("OnClick", function()
            if view == key then return end
            view = key
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            list:ScrollToTop()
            Layout()
        end)
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 18, 0)
        else
            tab:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 16)
        end
        previous = tab
        tabs[key] = tab
    end

    searchBox = UI.EditBox(window, 30)
    searchBox:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 50)
    searchBox:SetPoint("TOPRIGHT", -PAD, -ns.NPC_HEADER_BOTTOM - 50)
    local hint = UI.Text(searchBox, 13, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search"])
    searchBox:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        Layout()
    end)

    -- Scrolling list (scrollbar outside the cards)
    list = UI.ScrollArea(window)
    list:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -14)
    list:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 64)
    emptyText = UI.Text(window, 13, "CENTER", UI.MUTED)
    emptyText:SetPoint("TOP", list, "TOP", 0, -40)

    -- Footer: divider, repair, junk, gold
    local line = window:CreateTexture(nil, "BORDER")
    line:SetColorTexture(1, 1, 1, 0.07)
    line:SetHeight(ns.PixelSize())
    line:SetPoint("BOTTOMLEFT", PAD, 52)
    line:SetPoint("BOTTOMRIGHT", -PAD, 52)
    repairButton = FooterButton(REPAIR_ICON, L["Repair all"], function()
        -- guild bank only with the setting on (same rule as the bags' auto repair)
        local useGuild = ns.UseGuildRepair and ns.UseGuildRepair(GetRepairAllCost()) or false
        RepairAllItems(useGuild)
        PlaySound(SOUNDKIT.ITEM_REPAIR)
    end)
    repairButton:SetPoint("BOTTOMLEFT", PAD, 14)
    junkButton = FooterButton(JUNK_ICON, L["Sell junk"], function()
        C_MerchantFrame.SellAllJunkItems()
    end)
    junkButton:SetPoint("LEFT", repairButton, "RIGHT", 8, 0)
    gold = UI.Text(window, 13, "RIGHT")
    gold:SetPoint("BOTTOMRIGHT", -PAD, 22)

    window:HookScript("OnShow", function()
        view = "shop"
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        list:ScrollToTop()
        Layout()
        OpenAllBags(window) -- bags open along, like Blizzard
    end)
    window:HookScript("OnHide", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        StackSplitFrame:Hide()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        CloseAllBags(window)
        -- Only close if our merchant interaction is still running; after switching to the next NPC,
        -- CloseMerchant would end the NEW interaction
        if ns.StillInteracting("Merchant", MerchantFrame) then CloseMerchant() end
    end)
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not MerchantFrame then return end
    CreateWindow()
    -- Park Blizzard's frame invisibly (IsShown must stay true or Blizzard closes the merchant)
    MerchantFrame:SetParent(hidden)

    ns:On("MERCHANT_SHOW", function()
        window:SetNpc("npc")
        window:Show()
    end)
    ns:On("MERCHANT_CLOSED", function() window:Hide() end)
    for _, event in ipairs({ "MERCHANT_UPDATE", "MERCHANT_FILTER_ITEM_UPDATE", "GET_ITEM_INFO_RECEIVED", "PLAYER_MONEY",
        "UPDATE_INVENTORY_DURABILITY", "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE" }) do
        ns:On(event, Refresh)
    end
end)
