-- Beim Händler nachkaufen (Forever): Munition und Klassen-Reagenzien werden auf eine Wunschmenge
-- AUFGEFÜLLT – 320 Pfeile da, 1000 gewünscht > 680 kaufen. An/aus und Mengen: Einstellungen > Taschen.
--
-- Munition: welche Art, entscheidet die angelegte Fernkampfwaffe (Bogen/Armbrust > Pfeile,
-- Schusswaffe > Kugeln). Gekauft wird immer die beste Munition, die der Händler hat und die du
-- schon nutzen kannst (höchste Mindeststufe ≤ deine Stufe). Gezählt wird ALLE Munition dieser Art in
-- den Taschen (Benny 2026-11-06: „maximal 1000“ – vorher nur die neue Sorte, dann lagen 1000 alte
-- plus 1000 neue Pfeile in der Tasche). Die beste Sorte wird eingelegt.
-- Reagenzien: die Liste aus ClassReagents.lua (nur deine Klasse, nur was Händler verkaufen).
--
-- Gekauft wird in Blizzards Schritten (Pfeile z. B. je 200): aufgerundet, damit die Wunschmenge
-- sicher erreicht wird, und nie mehr, als das Gold hergibt.
local _, ns = ...
local L = ns.L

ns.AUTOBUY_AMMO_DEFAULT = 1000

local function Enabled() return ns.IS_FOREVER and ns.db.autoBuy == true end

-- Wunschmenge je Eintrag ("ammo" oder Item-ID); 0 = nicht kaufen
function ns.AutoBuyAmount(key, default)
    local amount = ns.db.autoBuyAmounts and ns.db.autoBuyAmounts[key]
    if amount == nil then return default or 0 end
    return amount
end

local function WantedAmmoClass() return ns.WantedAmmoClass() end -- UnitFrames/ClassReagents.lua

local function MinLevel(itemID)
    local _, _, _, itemLevel, minLevel = C_Item.GetItemInfo(itemID)
    return minLevel, itemLevel
end

-- beste passende Munition beim Händler; missing = Item-Daten noch nicht geladen
local function BestAmmo(ammoClass)
    local best, bestLevel, bestItemLevel, missing
    local myLevel = UnitLevel("player")
    for index = 1, GetMerchantNumItems() do
        local itemID = GetMerchantItemID(index)
        local info = itemID and C_MerchantFrame.GetItemInfo(index)
        if info and info.isPurchasable and not info.hasExtendedCost then
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
            if classID == Enum.ItemClass.Projectile and subClassID == ammoClass then
                local minLevel, itemLevel = MinLevel(itemID)
                if not minLevel then
                    missing = true
                    C_Item.RequestLoadItemDataByID(itemID)
                elseif minLevel <= myLevel and (not best or minLevel > bestLevel
                    or (minLevel == bestLevel and (itemLevel or 0) > bestItemLevel)) then
                    best, bestLevel, bestItemLevel = index, minLevel, itemLevel or 0
                end
            end
        end
    end
    return best, missing
end

-- Munition einer Art (Pfeile/Kugeln) in den Taschen; mit except: alles außer dieser Sorte.
-- Liefert Gesamtzahl und die Plätze (für „alte Pfeile wegwerfen“).
local function AmmoInBags(ammoClass, except)
    local total, slots = 0, {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and info.itemID ~= except then
                local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
                if classID == Enum.ItemClass.Projectile and subClassID == ammoClass then
                    total = total + (info.stackCount or 0)
                    slots[#slots + 1] = { bag, slot, info.itemID, info.stackCount or 0 }
                end
            end
        end
    end
    return total, slots
end

-- schlechtere Munition als best in den Taschen (Mindeststufe kleiner)
local function OldAmmo(ammoClass, best)
    local bestLevel = MinLevel(best) or 0
    local total, list = 0, {}
    local _, slots = AmmoInBags(ammoClass, best)
    for _, entry in ipairs(slots) do
        if (MinLevel(entry[3]) or 0) < bestLevel then
            total = total + entry[4]
            list[#list + 1] = entry
        end
    end
    return total, list
end

-- Nachfrage „Alte Pfeile wegwerfen?“ (verkaufen geht nicht, Verkaufspreis 0) – nur mit Ja
local discardClass, discardBest
local function OfferDiscard(ammoClass, best)
    local total, list = OldAmmo(ammoClass, best)
    if total == 0 then return end
    local names = {}
    for _, entry in ipairs(list) do
        local name = C_Item.GetItemNameByID(entry[3]) or ("Item " .. entry[3])
        if not tContains(names, name) then names[#names + 1] = name end
    end
    discardClass, discardBest = ammoClass, best
    StaticPopup_Show("MEREDANUI_DISCARD_AMMO", ("%d× %s"):format(total, table.concat(names, ", ")))
end

local function DiscardOldAmmo()
    if not (discardClass and discardBest) or InCombatLockdown() then return end
    local _, list = OldAmmo(discardClass, discardBest)
    local i = 0
    local function Next()
        i = i + 1
        local entry = list[i]
        if not entry or CursorHasItem() then return end
        C_Container.PickupContainerItem(entry[1], entry[2])
        if CursorHasItem() then DeleteCursorItem() end
        C_Timer.After(0.2, Next)
    end
    Next()
end

StaticPopupDialogs["MEREDANUI_DISCARD_AMMO"] = {
    text = L["Throw away old ammo? (%s)"],
    button1 = YES, button2 = NO,
    OnAccept = DiscardOldAmmo,
    showAlert = 1, timeout = 0, hideOnEscape = 1, whileDead = 1,
}

local function MerchantIndex(itemID)
    for index = 1, GetMerchantNumItems() do
        if GetMerchantItemID(index) == itemID then return index end
    end
end

-- Kaufmenge: auf Blizzards Schritt aufrunden, durch Gold und Vorrat begrenzen
local function Quantity(index, need)
    local info = C_MerchantFrame.GetItemInfo(index)
    if not info or need <= 0 then return 0 end
    local step = math.max(info.stackCount or 1, 1)
    local quantity = math.ceil(need / step) * step
    if info.price and info.price > 0 then
        local affordable = math.floor(GetMoney() / (info.price / step) / step) * step
        quantity = math.min(quantity, affordable)
    end
    if info.numAvailable and info.numAvailable >= 0 then
        quantity = math.min(quantity, info.numAvailable * step)
    end
    return quantity, info.price / step
end

-- in Portionen kaufen (höchstens ein Stapel je Kauf, kurz nacheinander)
local function Buy(index, quantity)
    local maxStack = math.max(GetMerchantItemMaxStack(index) or quantity, 1)
    local delay = 0
    while quantity > 0 do
        local portion = math.min(quantity, maxStack)
        C_Timer.After(delay, function()
            if MerchantFrame and MerchantFrame:IsShown() then BuyMerchantItem(index, portion) end
        end)
        quantity = quantity - portion
        delay = delay + 0.3
    end
end

local equipAfter   -- Item-ID der neuen Munition, nach dem Kauf einlegen
local discardAfter -- Munitionsart: nach dem Einlegen fragen, ob die alte weg soll

local function Run(retry)
    if not Enabled() or not (MerchantFrame and MerchantFrame:IsShown()) then return end
    local bought = {}
    local spent = 0
    local function Purchase(index, itemID, need)
        local quantity, unitPrice = Quantity(index, need)
        if quantity <= 0 then return end
        Buy(index, quantity)
        spent = spent + quantity * (unitPrice or 0)
        bought[#bought + 1] = ("%d× %s"):format(quantity, C_Item.GetItemNameByID(itemID) or ("Item " .. itemID))
    end

    -- Munition
    local _, class = UnitClass("player")
    local target = ns.AutoBuyAmount("ammo", ns.AUTOBUY_AMMO_DEFAULT)
    local ammoClass = class == "HUNTER" and target > 0 and WantedAmmoClass()
    if ammoClass then
        local index, missing = BestAmmo(ammoClass)
        if missing and not retry then
            C_Timer.After(0.6, function() Run(true) end) -- Item-Daten nachladen, dann alles nochmal
            return
        end
        if index then
            local itemID = GetMerchantItemID(index)
            -- gibt es schlechtere Munition in der Tasche, zählt sie nicht mit (sie kann weg)
            local old = OldAmmo(ammoClass, itemID)
            local have = old > 0 and C_Item.GetItemCount(itemID) or AmmoInBags(ammoClass)
            Purchase(index, itemID, target - have)
            if old > 0 then equipAfter, discardAfter = itemID, ammoClass end
            -- bessere Munition als die eingelegte > nach dem Kauf einlegen
            local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
            local equipped = ok and slot and GetInventoryItemID("player", slot)
            if equipped ~= itemID and (not equipped or (MinLevel(itemID) or 0) >= (MinLevel(equipped) or 0)) then
                equipAfter = itemID
            end
        end
    end

    -- Reagenzien der eigenen Klasse
    for _, reagent in ipairs(ns.CLASS_REAGENTS[class] or {}) do
        if reagent.item and reagent.buy then
            local wanted = ns.AutoBuyAmount(reagent.item, reagent.buy)
            local index = wanted > 0 and MerchantIndex(reagent.item)
            if index then Purchase(index, reagent.item, wanted - C_Item.GetItemCount(reagent.item)) end
        end
    end

    -- schon genug von der besseren Sorte da (nichts gekauft): gleich einlegen
    if equipAfter and C_Item.GetItemCount(equipAfter) > 0 and not InCombatLockdown() and #bought == 0 then
        C_Item.EquipItemByName(equipAfter)
        if discardAfter then OfferDiscard(discardAfter, equipAfter) end
        equipAfter, discardAfter = nil, nil
    end

    if #bought > 0 then
        ns.Print(L["Restocked: %s (%s)."]:format(table.concat(bought, ", "), GetMoneyString(math.floor(spent), true)))
    end
end

-- nur einmal je Händlerbesuch (sonst zählten zwei Läufe dieselben, noch nicht angekommenen Käufe nicht mit)
local ranThisVisit
ns:On("MERCHANT_SHOW", function()
    if not Enabled() or ranThisVisit then return end
    ranThisVisit = true
    C_Timer.After(0.3, function() Run(false) end)
end)
ns:On("MERCHANT_CLOSED", function() ranThisVisit = nil end)

-- neue Munition einlegen, sobald sie in der Tasche ist (außerhalb des Kampfes)
ns:On("BAG_UPDATE_DELAYED", function()
    if not equipAfter or InCombatLockdown() or C_Item.GetItemCount(equipAfter) == 0 then return end
    local itemID, ammoClass = equipAfter, discardAfter
    equipAfter, discardAfter = nil, nil
    C_Item.EquipItemByName(itemID)
    if ammoClass then C_Timer.After(0.5, function() OfferDiscard(ammoClass, itemID) end) end
end)
