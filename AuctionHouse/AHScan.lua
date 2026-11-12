-- Auction house prices: full scan (C_AuctionHouse.ReplicateItems, allowed once per 15 minutes) plus
-- prices picked up from normal searches. Cheapest unit buyout per itemID, per AH scope (realm =
-- ruleset + faction, see AH.Scope), with the day it was seen. Shown in item tooltips (setting
-- ahTooltipPrice, Comfort).
local _, ns = ...
local L = ns.L
local AH = ns.AH

local SCAN_COOLDOWN = 15 * 60
local BATCH = 500 -- replicate rows per frame (a full AH has tens of thousands)

local function Today() return math.floor(time() / 86400) end
local function Prices() return AH.ScopeTable("ahPrices") end
local function Days() return AH.ScopeTable("ahPriceDay") end

-- Cheapest of the day wins; a new day replaces older data
function AH.RecordPrice(itemID, unitPrice)
    if not (itemID and unitPrice and unitPrice > 0) then return end
    local prices, days, today = Prices(), Days(), Today()
    if days[itemID] == today and prices[itemID] and prices[itemID] <= unitPrice then return end
    prices[itemID], days[itemID] = unitPrice, today
end

function AH.PriceOf(itemID)
    local scoped = ns.root and ns.root.ahPrices and ns.root.ahPrices[AH.Scope()]
    local price = scoped and scoped[itemID]
    if not price then return end
    local day = ns.root.ahPriceDay and ns.root.ahPriceDay[AH.Scope()] and ns.root.ahPriceDay[AH.Scope()][itemID]
    return price, day and (Today() - day) or nil
end

-- Full scan --------------------------------------------------------------------------------------

local scan = { running = false }
AH.scan = scan

local function SecondsLeft()
    return math.max((ns.root.ahScanLast or 0) + SCAN_COOLDOWN - time(), 0)
end

local function UpdateButton()
    local button = scan.button
    if not button then return end
    local left = SecondsLeft()
    local ready = not scan.running and left == 0
    button:SetEnabled(ready)
    button.Text:SetAlpha(ready and 1 or 0.45)
    if scan.running then button.Text:SetText(L["Scanning …"])
    elseif left > 0 then button.Text:SetText(L["Scan in %d min"]:format(math.ceil(left / 60)))
    else button.Text:SetText(L["Scan auction house"]) end
end

-- Progress bar in the footer, from the left edge to the scan button (replaces the footer text)
local function ShowProgress(fraction)
    local bar = scan.bar
    if not bar then return end
    if not fraction then
        bar:Hide()
        return
    end
    local window, button = AH.window, scan.button
    if window and button and window:GetLeft() and button:GetLeft() then
        bar:SetWidth(math.max(button:GetLeft() - window:GetLeft() - ns.NPC_PAD - 12, 50))
    end
    bar:SetValue(fraction)
    bar.text:SetText(L["Scanning … %d%%"]:format(math.floor(fraction * 100)))
    bar:Show()
end

local function Finish(count)
    ShowProgress(nil)
    scan.running = false
    ns.root.ahScanLast = time()
    ns.root.ahScanCount = ns.root.ahScanCount or {}
    ns.root.ahScanCount[AH.Scope()] = count
    AH.SetFooter(L["Scan done: prices for %d items."]:format(count))
    UpdateButton()
end

local function Process()
    local total = C_AuctionHouse.GetNumReplicateItems() or 0
    local best, index = {}, 0
    local ticker
    ticker = C_Timer.NewTicker(0, function()
        local last = math.min(index + BATCH, total) - 1
        for i = index, last do -- replicate indices are 0-based
            local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
            if itemID and buyout and buyout > 0 then
                local unit = math.floor(buyout / math.max(count or 1, 1))
                if not best[itemID] or unit < best[itemID] then best[itemID] = unit end
            end
        end
        index = last + 1
        ShowProgress(total > 0 and math.min(index / total, 1) or 1)
        if index >= total then
            ticker:Cancel()
            local prices, days, today, n = Prices(), Days(), Today(), 0
            for itemID, unit in pairs(best) do
                prices[itemID], days[itemID], n = unit, today, n + 1
            end
            Finish(n)
        end
    end)
end

function AH.StartScan()
    if scan.running or SecondsLeft() > 0 then return end
    scan.running = true
    scan.waiting = true
    UpdateButton()
    ShowProgress(0)
    C_AuctionHouse.ReplicateItems()
end

-- The list can arrive in several updates; process once it has been quiet for a moment
local settle
ns:On("REPLICATE_ITEM_LIST_UPDATE", function()
    if not scan.waiting then return end
    if settle then settle:Cancel() end
    settle = C_Timer.NewTimer(1, function()
        settle = nil
        scan.waiting = false
        Process()
    end)
end)

ns:On("AUCTION_HOUSE_CLOSED", function()
    if scan.waiting then scan.waiting, scan.running = false, false ShowProgress(nil) end
end)

-- Button in the buy tab's footer (only visible with that tab)
function AH.CreateScanButton(view)
    local UI = ns.UI
    local button = UI.Button(view, "", function() AH.StartScan() end, 170)
    button:SetHeight(28)
    button:SetPoint("RIGHT", AH.footerRight, "RIGHT", 0, 0)
    button:SetMotionScriptsWhileDisabled(true)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Scan auction house"], 1, 1, 1)
        GameTooltip:AddLine(L["Saves the cheapest price of every item for tooltips. Blizzard allows it every 15 minutes."], 0.8, 0.8, 0.8, true)
        local count = ns.root.ahScanCount and ns.root.ahScanCount[AH.Scope()]
        if ns.root.ahScanLast and count then
            GameTooltip:AddLine(L["Last scan: %s (%d items)"]:format(date("%d.%m. %H:%M", ns.root.ahScanLast), count), 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    scan.button = button
    local bar = CreateFrame("StatusBar", nil, view)
    bar:SetHeight(18)
    bar:SetPoint("RIGHT", button, "LEFT", -12, 0)
    bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(unpack(UI.ACCENT))
    bar:SetMinMaxValues(0, 1)
    UI.Box(bar, UI.FIELD)
    bar.text = UI.Text(bar, 11, "CENTER")
    bar.text:SetPoint("CENTER")
    -- footer text makes room while the bar is visible (also when switching tabs mid-scan)
    bar:SetScript("OnShow", function() if AH.footerText then AH.footerText:Hide() end end)
    bar:SetScript("OnHide", function() if AH.footerText then AH.footerText:Show() end end)
    bar:Hide()
    scan.bar = bar
    view:HookScript("OnShow", UpdateButton)
    C_Timer.NewTicker(20, function() if button:IsVisible() then UpdateButton() end end)
    UpdateButton()
end

-- Tooltip ----------------------------------------------------------------------------------------

local function StackCount(data)
    if not data.guid or not C_Item.GetItemLocation then return 1 end
    local ok, loc = pcall(C_Item.GetItemLocation, data.guid)
    if not ok or not loc or not loc:IsValid() then return 1 end
    local okCount, count = pcall(C_Item.GetStackCount, loc)
    return okCount and count or 1
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not (ns.db and ns.db.ahTooltipPrice ~= false) or not data then return end
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end -- comparison tooltips are secure
        local itemID = data.id
        if not ns.Readable(itemID) or type(itemID) ~= "number" then return end
        local price, age = AH.PriceOf(itemID)
        if not price then return end
        local count = tooltip == GameTooltip and StackCount(data) or 1
        if not ns.Readable(count) then count = 1 end
        local label = L["Auction house"] .. (count > 1 and (" ×" .. count) or "")
        if age and age >= 1 then label = label .. "  |cff77756e" .. L["%d d ago"]:format(age) .. "|r" end
        -- Vendor pays more than a sale would bring (after the 5 % AH cut): price in red
        local vendor = select(11, C_Item.GetItemInfo(itemID))
        local vendorBetter = vendor and vendor > 0 and price * 0.95 <= vendor
        local money = GetMoneyString(price * count, true)
        if vendorBetter then money = "|cffe65050" .. money .. "|r" end -- red: the vendor pays more
        tooltip:AddLine(" ") -- own block, like the character counts below
        tooltip:AddDoubleLine(label, money, 0.56, 0.8, 0.71, 1, 1, 1)
    end)
end)
