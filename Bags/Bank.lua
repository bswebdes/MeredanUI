-- Bank (WoW Forever): own window in the bag style replacing Blizzard's bank frame. Layout as in
-- Blizzard's (8 columns, up to 88 slots per page, page tabs on the right, bag slots and purchase
-- at the bottom), look of our bag window.
--
--   +- Bank ---------------------- 12 free [S] [x] -+ +--+
--   | [Search ................................]     | |# |  page 1 (Blizzard icon)
--   | [#][#][#][#][#][#][#][#]                      | +--+
--   | [#][#][#][#][#][#][#][#]                      | +--+
--   | --------------------------------------------- | |# |  page 2
--   | Bag slots:          [#][#][L][L][L][L]        | +--+
--   | Cost: 10s                        [Purchase]   |
--   | 14s 85c                                       |
--   +-----------------------------------------------+
--
-- Blizzard's bank frame is only parked invisibly (like Baganator): it must stay "open", otherwise
-- its OnHide would close the bank on the server. While hidden its OnShow/OnHide don't fire.
-- Forever bank: bank "tabs" are bags (C_Bank.ShouldUsePlayerBagsInBank) - tab 1 is the base
-- container, 2-9 hold bags. Slots of all tabs run continuously across the pages.
-- Purchase uses Blizzard's addon template (BankPanelPurchaseButtonScriptTemplate) because
-- C_Bank.PurchaseBankTab is protected.
local _, ns = ...
local L = ns.L

local SIZE, GAP, PAD = 36, 6, 14
local COLS = 8
local PER_PAGE = 88          -- as Blizzard's Forever bank (maximumTotalSlotsPerPage)
local SLOT_SIZE = 26         -- bag slots at the bottom
local BUY_HEIGHT = 24
local GRID_WIDTH = COLS * SIZE + (COLS - 1) * GAP
local BANK_TYPE = Enum.BankType.Character
local TAB_ICONS = {          -- Blizzard's page icons (BankPageTabTemplate)
    "Interface\\ICONS\\INV_SideTab_Bank_c60",
    "Interface\\ICONS\\ACHIEVEMENT_GUILDPERK_MOBILEBANKING",
    "Interface\\ICONS\\TRADE_ARCHAEOLOGY_CHESTOFTINYGLASSANIMALS",
    "Interface\\ICONS\\Ability_Racial_PackHobgoblin",
}

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, content, searchBox, freeText, goldText, divider
local bagLabel, costLabel, costText, buyButton
local holders, buttons = {}, {}   -- holders[bag] (ID = bag number), buttons[bag][slot]
local bagSlots, pageTabs = {}, {}
local page = 1

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.bags ~= false and C_Bank and C_Bank.ShouldUsePlayerBagsInBank
        and C_Bank.ShouldUsePlayerBagsInBank()
end

-- containers of purchased tabs in order (base container first)
local function Containers()
    local list = {}
    for _, tab in ipairs(C_Bank.FetchPurchasedBankTabData(BANK_TYPE) or {}) do list[#list + 1] = tab.ID end
    return list
end

-- "+ Reagents": moves trade goods and profession materials from the bags into the bank.
-- One at a time (the server needs a moment per move): onto a matching stack if it fits entirely,
-- else into the first free slot. Class reagents (ammo, Ankh ...) stay.
local depositing
local function IsMaterial(itemID)
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID == Enum.ItemClass.Tradegoods then return true end
    local isCraftingReagent = select(17, C_Item.GetItemInfo(itemID))
    return isCraftingReagent == true and classID ~= Enum.ItemClass.Projectile and classID ~= Enum.ItemClass.Quiver
end

local function DepositStep()
    if not (depositing and window and window:IsShown()) or CursorHasItem() then depositing = nil return end
    depositing.steps = depositing.steps + 1
    if depositing.steps > 300 then depositing = nil return end -- safety net in case a move fails silently
    -- next material in the bags (skip locked slots: a move is still in progress)
    local source, info
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if not source and item and not item.isLocked and not depositing.skip[item.itemID] and IsMaterial(item.itemID) then
                source, info = { bag, slot }, item
            end
        end
    end
    if not source then
        if depositing.moved > 0 then ns.Print(L["Deposited %d stacks."]:format(depositing.moved)) end
        depositing = nil
        return
    end
    local maxStack = C_Item.GetItemMaxStackSizeByID(info.itemID) or 1
    local target, empty
    for _, bag in ipairs(Containers()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = C_Container.GetContainerItemInfo(bag, slot)
            if not item then
                empty = empty or { bag, slot }
            elseif not target and not item.isLocked and item.itemID == info.itemID and item.stackCount + info.stackCount <= maxStack then
                target = { bag, slot }
            end
        end
    end
    target = target or empty
    if not target then
        ns.Print(L["The bank is full."])
        depositing = nil
        return
    end
    C_Container.PickupContainerItem(source[1], source[2])
    C_Container.PickupContainerItem(target[1], target[2])
    if CursorHasItem() then -- didn't fit (e.g. locked): put back and skip this material
        ClearCursor()
        depositing.skip[info.itemID] = true
    else
        depositing.moved = depositing.moved + 1
    end
    C_Timer.After(0.2, DepositStep)
end

local function DepositMaterials()
    if depositing then return end
    depositing = { moved = 0, skip = {}, steps = 0 }
    DepositStep()
end

local function GetButton(bag, slot)
    buttons[bag] = buttons[bag] or {}
    local button = buttons[bag][slot]
    if button then return button end
    local holder = holders[bag]
    if not holder then
        -- Blizzard's buttons read the bag number from the parent frame
        holder = CreateFrame("Frame", "MeredanUIBankHolder" .. bag, content)
        holder:SetID(bag)
        holder:SetAllPoints()
        holder.IsCombinedBagContainer = function() return false end
        holders[bag] = holder
    end
    button = CreateFrame("ItemButton", "MeredanUIBankItem" .. bag .. "_" .. slot, holder, "ContainerFrameItemButtonTemplate")
    -- No SetBagID: the value would come from addon code (taint) and Blizzard then blocks using the
    -- item in combat. Without bagID, GetBagID reads the parent's ID (holder:SetID), like Bagnon/Baganator.
    button:SetID(slot)
    ns.StyleBagButton(button)
    buttons[bag][slot] = button
    return button
end

local function IsGear(info)
    if not (info and info.itemID) then return false end
    local classID = select(6, C_Item.GetItemInfoInstant(info.itemID))
    return classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
end

local function ApplySearch()
    local query = searchBox and searchBox:GetText():lower() or ""
    for _, list in pairs(buttons) do
        for _, button in pairs(list) do
            if button:IsShown() then
                button:SetMatchesSearch(query == "" or (button.muiName or ""):find(query, 1, true) ~= nil)
            end
        end
    end
end

-- Layout --------------------------------------------------------------------------------------

local function UpdatePageTabs(numPages)
    for i = 1, math.max(numPages, #pageTabs) do
        local tab = pageTabs[i]
        if i <= numPages then
            if not tab then
                tab = CreateFrame("Button", nil, window)
                tab:SetSize(SIZE, SIZE)
                tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, -PAD - 58 - (i - 1) * (SIZE + GAP))
                tab.icon = tab:CreateTexture(nil, "ARTWORK")
                tab.icon:SetAllPoints()
                tab.icon:SetTexture(TAB_ICONS[i] or TAB_ICONS[1])
                tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                ns.AddBorder(tab)
                local hover = tab:CreateTexture(nil, "HIGHLIGHT")
                hover:SetAllPoints()
                hover:SetColorTexture(1, 1, 1, 0.12)
                tab.marker = tab:CreateTexture(nil, "OVERLAY")
                tab.marker:SetColorTexture(unpack(ns.UI.ACCENT))
                tab.marker:SetPoint("TOPLEFT")
                tab.marker:SetPoint("BOTTOMLEFT")
                tab.marker:SetWidth(2 * ns.PixelSize())
                tab:SetScript("OnClick", function()
                    page = i
                    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                    window.Layout()
                end)
                tab:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(PAGE_NUMBER and PAGE_NUMBER:format(i) or ("Page " .. i), 1, 1, 1)
                    GameTooltip:Show()
                end)
                tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
                pageTabs[i] = tab
            end
            local active = i == page
            tab.marker:SetShown(active)
            local shade = active and 1 or 0.6
            tab.icon:SetVertexColor(shade, shade, shade)
            tab.icon:SetDesaturated(not active) -- inactive tabs desaturated (as everywhere)
            tab:Show()
        elseif tab then
            tab:Hide()
        end
    end
end

local function UpdateBagSlots()
    local purchased = C_Bank.FetchNumPurchasedBankTabs(BANK_TYPE) or 0
    for bagNum, slotButton in pairs(bagSlots) do
        local bought = bagNum <= purchased
        local location = ItemLocation:CreateFromBagAndSlot(Enum.BagIndex.Characterbanktab, bagNum)
        local icon = bought and C_Item.DoesItemExist(location) and C_Item.GetItemIcon(location)
        slotButton.icon:SetTexture(icon or nil)
        slotButton.lock:SetShown(not bought)
        slotButton.bought = bought
    end
end

local function UpdateCost()
    local maxed = (C_Bank.FetchNumPurchasedBankTabs(BANK_TYPE) or 0) >= (C_Bank.FetchMaxNumBankTabs(BANK_TYPE) or 0)
    local data = not maxed and C_Bank.FetchNextPurchasableBankTabData(BANK_TYPE)
    costLabel:SetShown(data and true or false)
    costText:SetShown(data and true or false)
    buyButton:SetShown(data and true or false)
    if data then
        costText:SetText(GetMoneyString(data.tabCost, true))
        if data.canAfford then
            costText:SetTextColor(unpack(ns.UI.TEXT))
        else
            costText:SetTextColor(1, 0.3, 0.3)
        end
    end
    return data ~= nil and data ~= false
end

local function Layout()
    if not window then return end
    for _, list in pairs(buttons) do
        for _, button in pairs(list) do button:Hide() end
    end

    -- all slots of purchased tabs in sequence; show the current page
    local all, free = {}, 0
    for _, bag in ipairs(Containers()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do all[#all + 1] = { bag, slot } end
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
    end
    local numPages = math.max(1, math.ceil(#all / PER_PAGE))
    page = math.min(page, numPages)
    local first = (page - 1) * PER_PAGE + 1
    local last = math.min(#all, page * PER_PAGE)

    local shown = 0
    for index = first, last do
        local bag, slot = all[index][1], all[index][2]
        local button = GetButton(bag, slot)
        local info = C_Container.GetContainerItemInfo(bag, slot)
        ns.UpdateBagButton(button, info, IsGear(info))
        local col, row = shown % COLS, math.floor(shown / COLS)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", content, "TOPLEFT", col * (SIZE + GAP), -row * (SIZE + GAP))
        button:Show()
        shown = shown + 1
    end
    local rows = math.max(1, math.ceil(shown / COLS))
    local gridHeight = rows * SIZE + (rows - 1) * GAP

    -- bottom: divider, bag slots, cost/purchase, gold
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -gridHeight - 14)
    divider:SetWidth(GRID_WIDTH)
    UpdateBagSlots()
    local hasCost = UpdateCost()

    local width = 2 * PAD + GRID_WIDTH
    local height = PAD + 58 + gridHeight + 14 + 1 + 12 + SLOT_SIZE + (hasCost and (10 + BUY_HEIGHT) or 0) + 12 + 14 + PAD
    window:SetSize(width, height)

    freeText:SetText(L["%d free"]:format(free))
    goldText:SetText(GetMoneyString(GetMoney(), true))
    UpdatePageTabs(numPages)
    ApplySearch()
end

-- Window --------------------------------------------------------------------------------------

local function BagSlot(bagNum)
    local slotButton = CreateFrame("Button", nil, window)
    slotButton:SetSize(SLOT_SIZE, SLOT_SIZE)
    ns.AddSlotBackground(slotButton)
    ns.AddBorder(slotButton)
    slotButton.icon = slotButton:CreateTexture(nil, "ARTWORK")
    slotButton.icon:SetAllPoints()
    slotButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slotButton.lock = slotButton:CreateTexture(nil, "OVERLAY")
    slotButton.lock:SetPoint("CENTER")
    slotButton.lock:SetSize(SLOT_SIZE * 0.6, SLOT_SIZE * 0.6)
    if not slotButton.lock:SetAtlas("bankslot-icon-lock") then
        slotButton.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
    end
    slotButton.lock:SetDesaturated(true)
    slotButton.lock:SetVertexColor(0.7, 0.7, 0.7)
    local hover = slotButton:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)

    -- place/remove bank bags as Blizzard does (slot in Characterbanktab)
    local function Pickup()
        if slotButton.bought then C_Container.PickupContainerItem(Enum.BagIndex.Characterbanktab, bagNum) end
    end
    slotButton:RegisterForDrag("LeftButton")
    slotButton:SetScript("OnClick", Pickup)
    slotButton:SetScript("OnDragStart", Pickup)
    slotButton:SetScript("OnReceiveDrag", Pickup)
    slotButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if not (self.bought and GameTooltip:SetBagItem(Enum.BagIndex.Characterbanktab, bagNum)) then
            GameTooltip:SetText(self.bought and (BANK_BAG or "Bank bag") or (BANK_BAG_PURCHASE or "Purchasable bag slot"), 1, 1, 1)
        end
        GameTooltip:Show()
        -- highlight this bag's slots
        local container = Enum.BagIndex.CharacterBankTab_1 + bagNum - 1
        for bag, list in pairs(buttons) do
            for _, button in pairs(list) do
                if button:IsShown() then button:SetMatchesSearch(bag == container) end
            end
        end
    end)
    slotButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ApplySearch()
    end)
    bagSlots[bagNum] = slotButton
    return slotButton
end

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIBank", UIParent)
    window:SetFrameStrata("HIGH") -- above chat and raid frames
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor)
    tinsert(UISpecialFrames, "MeredanUIBank") -- Esc closes (and thus the bank)
    -- default: where the raid frames sit (90 px above chat, left aligned)
    window:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(90))
    window.Layout = Layout
    -- drag by the header; position resets on open
    local dragArea = CreateFrame("Frame", nil, window)
    dragArea:SetPoint("TOPLEFT")
    dragArea:SetPoint("TOPRIGHT")
    dragArea:SetHeight(PAD + 22)
    dragArea:SetFrameLevel(window:GetFrameLevel())
    ns.MakeWindowDraggable(window, dragArea)
    ns.WatchBlizzardFrame(window, function() return BankFrame end)
    -- size before first open (6 rows like Blizzard's base container) so the edit mode frame
    -- matches; Layout recalculates it on open
    window:SetSize(2 * PAD + GRID_WIDTH, PAD + 58 + 6 * SIZE + 5 * GAP + 14 + 1 + 12 + SLOT_SIZE + 10 + BUY_HEIGHT + 12 + 14 + PAD)

    -- header as in the bag window: title as active tab, free/sort/close on the right
    local title = UI.Text(window, 14, "LEFT", UI.ACCENT)
    title:SetPoint("TOPLEFT", PAD, -PAD - 3)
    title:SetText(_G.BANK or "Bank")
    local line = window:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(unpack(UI.ACCENT))
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    line:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -3)

    local close = UI.IconButton(window, "Close", function() window:Hide() end, 22)
    close:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 2)
    local sort = UI.IconButton(window, "Sort", function()
        C_Container.SortBank(BANK_TYPE)
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01 or SOUNDKIT.IG_BACKPACK_OPEN)
    end, 22)
    sort:SetPoint("RIGHT", close, "LEFT", -4, 0)
    sort:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(BAG_CLEANUP_BANK or L["Sort bags"], 1, 1, 1)
        GameTooltip:Show()
    end)
    sort:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local deposit = UI.Button(window, "+ " .. L["Reagents"], DepositMaterials, 10)
    deposit:SetHeight(22)
    deposit:SetWidth(deposit.Text:GetUnboundedStringWidth() + 20)
    deposit:SetPoint("RIGHT", sort, "LEFT", -4, 0)
    deposit:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Deposit reagents"], 1, 1, 1)
        GameTooltip:AddLine(L["Puts all trade goods and profession materials from your bags into the bank. Class reagents stay."], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    deposit:HookScript("OnLeave", function() GameTooltip:Hide() end)
    freeText = UI.Text(window, 12, "RIGHT", UI.MUTED)
    freeText:SetPoint("RIGHT", deposit, "LEFT", -8, 0)

    searchBox = UI.EditBox(window, 22)
    searchBox:SetPoint("TOPLEFT", PAD, -PAD - 24)
    searchBox:SetPoint("TOPRIGHT", -PAD, -PAD - 24)
    local hint = UI.Text(searchBox, 12, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 8, 0)
    hint:SetText(L["Search"])
    searchBox:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        ApplySearch()
    end)

    content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", PAD, -PAD - 58)
    content:SetSize(1, 1)

    divider = window:CreateTexture(nil, "BORDER")
    divider:SetColorTexture(1, 1, 1, 0.08)
    divider:SetHeight(ns.PixelSize())

    -- bag slots: label left, slots right aligned (tab 2 to max)
    bagLabel = UI.Text(window, 12, "LEFT")
    bagLabel:SetText(BAGSLOTTEXT_COLON or ((BAGSLOTTEXT or "Bag slots") .. ":"))
    local previous
    for bagNum = C_Bank.FetchMaxNumBankTabs(BANK_TYPE) or 9, 2, -1 do
        local slotButton = BagSlot(bagNum)
        if previous then
            slotButton:SetPoint("RIGHT", previous, "LEFT", -4, 0)
        else
            slotButton:SetPoint("TOPRIGHT", divider, "BOTTOMRIGHT", 0, -12)
        end
        previous = slotButton
    end
    bagLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -12)
    bagLabel:SetHeight(SLOT_SIZE)
    bagLabel:SetJustifyV("MIDDLE")

    -- cost and purchase (Blizzard's purchase dialog via the addon template)
    costLabel = UI.Text(window, 12, "LEFT", UI.MUTED)
    costLabel:SetText(COSTS_LABEL or "Cost:")
    costLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -12 - SLOT_SIZE - 10)
    costLabel:SetHeight(BUY_HEIGHT)
    costLabel:SetJustifyV("MIDDLE")
    costText = UI.Text(window, 12, "LEFT")
    costText:SetPoint("LEFT", costLabel, "RIGHT", 6, 0)
    buyButton = CreateFrame("Button", nil, window, "BankPanelPurchaseButtonScriptTemplate")
    buyButton:SetAttribute("overrideBankType", BANK_TYPE)
    buyButton:SetSize(110, BUY_HEIGHT)
    buyButton:SetPoint("TOPRIGHT", divider, "BOTTOMRIGHT", 0, -12 - SLOT_SIZE - 10)
    local buyBg = UI.Box(buyButton)
    local buyText = UI.Text(buyButton, 12, "CENTER")
    buyText:SetPoint("CENTER")
    buyText:SetText(BANKSLOTPURCHASE or "Purchase")
    buyButton:HookScript("OnEnter", function() buyBg:SetColorTexture(unpack(UI.HOVER)) end)
    buyButton:HookScript("OnLeave", function() buyBg:SetColorTexture(unpack(UI.FIELD)) end)

    goldText = UI.Text(window, 12, "LEFT")
    goldText:SetPoint("BOTTOMLEFT", PAD, PAD)

    window:SetScript("OnShow", function()
        ns.WindowOpened(window)
        ns.ResetWindowPosition(window, "bank", true)
        page = 1
        Layout()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        OpenAllBags(window) -- like Blizzard's bank: open the bags too
    end)
    window:SetScript("OnHide", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        CloseAllBags(window)
        -- only end our own still-running bank interaction (else it would hit the next NPC)
        if ns.StillInteracting("Banker", BankFrame) then C_Bank.CloseBankFrame() end
    end)
end

-- Events --------------------------------------------------------------------------------------

local pending
local function Refresh()
    if not (window and window:IsShown()) or pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        if window:IsShown() then Layout() end
    end)
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or C_AddOns.IsAddOnLoaded("BetterBags") then return end
    CreateWindow()
    ns.layoutFrames.bank = window
    -- park Blizzard's bank frame invisibly (don't close it, see above)
    if BankFrame then BankFrame:SetParent(hidden) end

    ns:On("BANKFRAME_OPENED", function() window:Show() end)
    ns:On("BANKFRAME_CLOSED", function() window:Hide() end)
    ns:On("BAG_UPDATE_DELAYED", Refresh)
    ns:On("PLAYERBANKSLOTS_CHANGED", Refresh)
    ns:On("BANK_TABS_CHANGED", Refresh)
    ns:On("BAG_CONTAINER_UPDATE", Refresh)
    ns:On("PLAYER_MONEY", Refresh)
    ns:On("ITEM_LOCK_CHANGED", function(_, bag, slot)
        local button = bag and slot and buttons[bag] and buttons[bag][slot]
        if button and button:IsShown() then
            local info = C_Container.GetContainerItemInfo(bag, slot)
            SetItemButtonDesaturated(button, info and info.isLocked)
        end
    end)
    ns:On("BAG_UPDATE_COOLDOWN", function()
        if not window:IsShown() then return end
        for _, list in pairs(buttons) do
            for _, button in pairs(list) do
                if button:IsShown() and button.muiItemID then button:UpdateCooldown(button:HasItem()) end
            end
        end
    end)
end)
