-- Alt item counts in item tooltips (Comfort: altItemCount), like the bag addons do:
--   Koratal Rabenruf   15 (Bank 12, Mail 1)
--   Meredan Illthared   3
--   Total              18
-- Per character (account-wide, MeredanUIDB.items[charKey]): item ID -> count for bags, bank (saved
-- when it was last open), mailbox (last visit) and worn gear. Only counts are stored, no links.
-- Scans are debounced; the tooltip just sums a few small tables.
local _, ns = ...
local L = ns.L

local DELAY = 1
local PLACES = { "bags", "bank", "mail", "equip" }
local PLACE_LABEL = { bank = L["Bank"], mail = L["Mail"], equip = L["Worn"] }
-- Items every character carries: a list of all alts says nothing
local SKIP = { [6948] = true } -- Hearthstone

local function Enabled() return ns.db and ns.db.altItemCount ~= false end

local function Store()
    if not (ns.root and ns.charKey) then return nil end
    ns.root.items = ns.root.items or {}
    local entry = ns.root.items[ns.charKey]
    if not entry then
        entry = {}
        ns.root.items[ns.charKey] = entry
    end
    local _, class = UnitClass("player")
    entry.class = class
    return entry
end

local function Count(list, bag)
    for slot = 1, C_Container.GetContainerNumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID and not issecretvalue(info.itemID) then
            list[info.itemID] = (list[info.itemID] or 0) + (info.stackCount or 1)
        end
    end
end

local function ScanBags()
    local entry = Store()
    if not entry then return end
    local list = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do Count(list, bag) end
    local keyring = Enum.BagIndex and Enum.BagIndex.Keyring
    if keyring and ns.IS_FOREVER then Count(list, keyring) end
    entry.bags = list
end

local bankOpen, mailOpen = false, false

local function ScanBank()
    local entry = Store()
    if not (entry and bankOpen) then return end
    local list = {}
    if C_Bank and C_Bank.FetchPurchasedBankTabData then
        for _, tab in ipairs(C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character) or {}) do Count(list, tab.ID) end
    end
    entry.bank = list
end

local function ScanMail()
    local entry = Store()
    if not (entry and mailOpen) then return end
    local list = {}
    for i = 1, GetInboxNumItems() do
        for j = 1, _G["ATTACHMENTS_MAX_RECEIVE"] or 16 do
            local _, itemID, _, count = GetInboxItem(i, j)
            if itemID then list[itemID] = (list[itemID] or 0) + (count or 1) end
        end
    end
    entry.mail = list
end

local function ScanEquip()
    local entry = Store()
    if not entry then return end
    local list = {}
    for slot = _G["INVSLOT_FIRST_EQUIPPED"] or 1, _G["INVSLOT_LAST_EQUIPPED"] or 19 do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then list[itemID] = (list[itemID] or 0) + 1 end
    end
    entry.equip = list
end

-- Debounced scans: one per kind, at most once per DELAY
local pending = {}
local function Soon(kind, fn)
    if pending[kind] then return end
    pending[kind] = true
    C_Timer.After(DELAY, function()
        pending[kind] = nil
        if Enabled() then fn() end
    end)
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    Soon("bags", ScanBags)
    Soon("equip", ScanEquip)
end)
ns:On("BAG_UPDATE_DELAYED", function()
    Soon("bags", ScanBags)
    if bankOpen then Soon("bank", ScanBank) end
end)
ns:On("PLAYER_EQUIPMENT_CHANGED", function() Soon("equip", ScanEquip) end)
ns:On("BANKFRAME_OPENED", function() bankOpen = true Soon("bank", ScanBank) end)
ns:On("PLAYERBANKSLOTS_CHANGED", function() if bankOpen then Soon("bank", ScanBank) end end)
ns:On("BANKFRAME_CLOSED", function() bankOpen = false end)
ns:On("MAIL_SHOW", function() mailOpen = true end)
ns:On("MAIL_INBOX_UPDATE", function() if mailOpen then Soon("mail", ScanMail) end end)
ns:On("MAIL_CLOSED", function()
    if mailOpen then ScanMail() end -- last state when leaving (taken items are gone)
    mailOpen = false
end)

-- Tooltip ---------------------------------------------------------------------------------------

local function ShortName(key)
    return (key or ""):match("^(.-) %- ") or key
end

local function AddLines(tooltip, itemID)
    local items = ns.root and ns.root.items
    if not items then return end
    local rows, total = {}, 0
    for key, entry in pairs(items) do
        local sum, parts = 0, {}
        for _, place in ipairs(PLACES) do
            local n = entry[place] and entry[place][itemID]
            if n and n > 0 then
                sum = sum + n
                if PLACE_LABEL[place] then parts[#parts + 1] = PLACE_LABEL[place] .. " " .. n end
            end
        end
        if sum > 0 then
            rows[#rows + 1] = { key = key, class = entry.class, sum = sum, detail = #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or "" }
            total = total + sum
        end
    end
    if #rows == 0 then return end
    table.sort(rows, function(a, b) return a.sum > b.sum end)
    if ns.TooltipSection then ns.TooltipSection(tooltip) else tooltip:AddLine(" ") end
    for _, row in ipairs(rows) do
        local color = row.class and RAID_CLASS_COLORS[row.class]
        local name = ShortName(row.key)
        tooltip:AddDoubleLine(color and color:WrapTextInColorCode(name) or name, row.sum .. row.detail, 1, 1, 1, 1, 1, 1)
    end
    if #rows > 1 then tooltip:AddDoubleLine(L["Total"], total, 0.56, 0.8, 0.71, 0.56, 0.8, 0.71) end
end

ns:On("PLAYER_LOGIN", function()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not Enabled() or not data then return end
        -- main tooltips only: comparison tooltips are built in a secure context
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local itemID = data.id
        if not ns.Readable(itemID) or type(itemID) ~= "number" or SKIP[itemID] then return end
        AddLines(tooltip, itemID)
    end)
end)
