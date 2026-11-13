-- Class reagents (Forever): ammo and spell reagents of your class as a vertical block of
-- class-colored icons + counts right of the player frame.
-- Color: white, yellow below the warn threshold, red below half, blinking red at 0; one toast
-- each when crossing the threshold and at 0. Retail never shows it; the preview shows all classes.
local _, ns = ...
local L = ns.L
local Readable = ns.Readable

local ICON = 16
local GAP = 8        -- gap to the player frame
local ITEM_GAP = 4   -- between two reagents (stacked)

-- Per class: item ID (Classic) + icon + warn threshold; "ammo" = equipped ammo (always shown).
-- buy = default restock amount at vendors (Bags/AutoBuy.lua); missing = not sold by vendors.
-- spells = rank 1 spells that use the reagent; it is only shown once you know one of them.
local CLASS_REAGENTS = {
    HUNTER = { { ammo = true } },
    WARLOCK = { { item = 6265, icon = "Shard", warn = 3,              -- Soul Shard
                  spells = { 697, 6201, 693, 698, 6353, 17877 } } },  -- Voidwalker, Healthstone, Soulstone, Ritual, Soul Fire, Shadowburn
    MAGE = { { item = 17020, icon = "Powder", warn = 5, buy = 20, spells = { 23028 } },  -- Arcane Powder: Arcane Brilliance
             { item = 17031, icon = "Rune", warn = 2, buy = 5,                           -- Rune of Teleportation
               spells = { 3561, 3562, 3565, 3567, 3563, 3566 } },
             { item = 17032, icon = "Rune", warn = 2, buy = 5,                           -- Rune of Portals
               spells = { 10059, 11416, 11419, 11417, 11418, 11420 } } },
    PRIEST = { { item = 17029, icon = "Candle", warn = 5, buy = 20, spells = { 21562, 27681, 27683 } }, -- Sacred Candle
               { item = 17028, icon = "Candle", warn = 5, buy = 20, spells = { 21562 } } },            -- Holy Candle
    DRUID = { { item = 17026, icon = "Berries", warn = 5, buy = 20, spells = { 21849 } } }, -- Wild Thornroot: Gift of the Wild
    PALADIN = { { item = 21177, icon = "Symbol", warn = 5, buy = 40,                     -- Symbol of Kings: greater blessings
                  spells = { 25782, 25894, 25898, 25895, 25890, 25899 } },
                { item = 17033, icon = "Symbol", warn = 2, buy = 5, spells = { 19752 } } }, -- Symbol of Divinity: Divine Intervention
    SHAMAN = { { item = 17030, icon = "Ankh", warn = 2, buy = 5, spells = { 20608 } } },  -- Ankh: Reincarnation
    ROGUE = { { item = 5140, icon = "Powder", warn = 5, buy = 10, spells = { 1856 } },    -- Flash Powder: Vanish
              { item = 5530, icon = "Powder", warn = 5, spells = { 2094 } } },          -- Blinding Powder: Blind
}

-- Do you know a spell that uses the reagent? (no list: always)
local function Needed(reagent)
    if not reagent.spells then return true end
    for _, id in ipairs(reagent.spells) do
        if C_SpellBook.IsSpellKnownOrInSpellBook(id) then return true end
    end
    return false
end
ns.CLASS_REAGENTS = CLASS_REAGENTS
local DEMO_ORDER = { "HUNTER", "WARLOCK", "MAGE", "PRIEST", "DRUID", "PALADIN", "SHAMAN", "ROGUE" }
local DEMO_COUNTS = { HUNTER = { 1240 }, WARLOCK = { 2 }, MAGE = { 38, 7, 0 }, PRIEST = { 12, 3 },
    DRUID = { 18 }, PALADIN = { 45, 1 }, SHAMAN = { 4 }, ROGUE = { 9, 15 } }

local holder
local cells = {}
local ammoSlot
local warned = {} -- key > "low"/"empty"
local demoClass   -- preview: show this class

local function Enabled() return ns.db.ammoCounter ~= false end
local function AmmoWarnAt() return 200 end -- fixed value

local function ClassColor(class)
    local color = RAID_CLASS_COLORS[class]
    return color and { color.r, color.g, color.b } or ns.UI.TEXT
end

local function ItemName(id) return C_Item.GetItemNameByID(id) or "" end

-- The ranged weapon decides the ammo type: bow/crossbow -> arrows (subclass 2), gun -> bullets (3).
-- If the ammo slot is empty or holds the wrong type, count matching ammo in the bags and equip
-- the best one (out of combat).
local ARROWS, BULLETS = 2, 3
local AMMO_FOR_WEAPON = {
    [Enum.ItemWeaponSubclass.Bows] = ARROWS, [Enum.ItemWeaponSubclass.Crossbow] = ARROWS,
    [Enum.ItemWeaponSubclass.Guns] = BULLETS,
}
local RANGED_SLOT = INVSLOT_RANGED or 18

-- Ammo subclass for the equipped weapon (nil = no ranged weapon that uses ammo)
function ns.WantedAmmoClass()
    local weapon = GetInventoryItemID("player", RANGED_SLOT)
    if not weapon then return end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(weapon)
    if classID ~= Enum.ItemClass.Weapon then return end
    return AMMO_FOR_WEAPON[subClassID]
end

local function AmmoClassOf(itemID)
    if not itemID then return end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if classID == Enum.ItemClass.Projectile then return subClassID end
end

-- Total ammo of a type in the bags + best kind (highest required level <= own level)
local function AmmoInBags(ammoClass)
    local total, best, bestLevel = 0, nil, -1
    local myLevel = UnitLevel("player")
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and AmmoClassOf(info.itemID) == ammoClass then
                total = total + (info.stackCount or 0)
                local _, _, _, _, minLevel = C_Item.GetItemInfo(info.itemID)
                minLevel = minLevel or 0
                if minLevel <= myLevel and minLevel > bestLevel then best, bestLevel = info.itemID, minLevel end
            end
        end
    end
    return total, best
end

-- Equip matching ammo (one attempt per item until the slot changes)
local equipTried
local function EquipAmmo(itemID)
    if not itemID or equipTried == itemID or InCombatLockdown() or CursorHasItem() then return end
    equipTried = itemID
    C_Item.EquipItemByName(itemID)
end

local function AmmoIcon(ammoClass) return ammoClass == BULLETS and "Bullet" or "Arrow" end

-- Shown? Per-reagent user choice, default: only the first (most important) of the class
function ns.ReagentKey(reagent) return reagent.ammo and "ammo" or reagent.item end
function ns.ReagentShown(reagent, index)
    local choice = ns.db.reagentShow and ns.db.reagentShow[ns.ReagentKey(reagent)]
    if choice == nil then return index == 1 end
    return choice
end

-- Entries with counts for the own class (or the preview)
local function Entries()
    local list = {}
    local class = demoClass or select(2, UnitClass("player"))
    for index, reagent in ipairs(CLASS_REAGENTS[class] or {}) do
        local entry = { key = reagent.ammo and "ammo" or reagent.item, warn = reagent.warn or 5, icon = reagent.icon }
        if not ns.ReagentShown(reagent, index) then -- luacheck: ignore 542 (deselected)
        elseif demoClass then
            entry.count = DEMO_COUNTS[class][index] or 10
            entry.icon = entry.icon or AmmoIcon(ns.WantedAmmoClass())
            entry.warn = reagent.ammo and AmmoWarnAt() or entry.warn
            entry.name = reagent.item and ItemName(reagent.item) or L["Ammunition"]
            list[#list + 1] = entry
        elseif reagent.ammo then
            if UnitUsesAmmo and UnitUsesAmmo("player") and ammoSlot then
                local id = GetInventoryItemID("player", ammoSlot)
                local wanted = ns.WantedAmmoClass()
                local fits = id and (not wanted or AmmoClassOf(id) == wanted)
                local count
                if fits then
                    count = GetInventoryItemCount("player", ammoSlot)
                    count = Readable(count) and count or 0
                    equipTried = nil
                elseif wanted then
                    -- Empty slot or wrong type (arrows with a gun): count bags, equip the best
                    local best
                    count, best = AmmoInBags(wanted)
                    EquipAmmo(best)
                else
                    count = 0
                end
                entry.count = count
                entry.warn = AmmoWarnAt()
                entry.icon = AmmoIcon(wanted or AmmoClassOf(id))
                entry.equipped = fits and true or false
                entry.name = fits and ItemName(id) or L["Ammunition"]
                list[#list + 1] = entry
            end
        elseif Needed(reagent) then
            local count = C_Item.GetItemCount(reagent.item)
            entry.count = Readable(count) and count or 0
            entry.name = ItemName(reagent.item)
            list[#list + 1] = entry
        end
    end
    return list, class
end

local function CountColor(count, warn)
    if count == 0 then return 1, 0.2, 0.2 end
    if count < math.max(1, math.floor(warn / 2)) then return 1, 0.25, 0.25 end
    if count < warn then return 1, 0.82, 0 end
    return 1, 1, 1
end

local function Toast(entry, text, color)
    if not ns.AddToast then return end
    ns.AddToast({ title = entry.name ~= "" and entry.name or L["Reagents"], text = text, color = color,
        icon = ns.IconPath("Reagent" .. entry.icon) })
end

local function Warn(entry)
    local state = warned[entry.key]
    if entry.count >= entry.warn then warned[entry.key] = nil return end
    if entry.count == 0 then
        if state ~= "empty" then
            warned[entry.key] = "empty"
            local text = (entry.key == "ammo" and not entry.equipped) and L["No ammunition equipped!"] or L["None left!"]
            Toast(entry, text, { 1, 0.2, 0.2 })
        end
    elseif not state then
        warned[entry.key] = "low"
        Toast(entry, L["Only %s left"]:format(BreakUpLargeNumbers(entry.count)), { 1, 0.82, 0 })
    end
end

-- Tooltip: the item itself; for ammo also roughly how many minutes of Auto Shot it lasts
local function CellEnter(cell)
    local entry = cell.entry
    if not entry then return end
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    if demoClass then
        GameTooltip:SetText(entry.name ~= "" and entry.name or L["Ammunition"], 1, 1, 1)
    elseif entry.key == "ammo" then
        if entry.equipped then
            GameTooltip:SetInventoryItem("player", ammoSlot)
            local speed = UnitRangedDamage("player")
            if Readable(speed) and speed and speed > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(L["Lasts for Auto Shot"],
                    L["approx. %d min"]:format(math.floor(entry.count * speed / 60 + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
            end
        else
            GameTooltip:SetText(L["No ammunition equipped!"], 1, 0.2, 0.2)
            GameTooltip:AddLine(L["Put arrows or bullets into the ammo slot (character window)."], 0.8, 0.8, 0.8, true)
        end
    else
        GameTooltip:SetItemByID(entry.key)
    end
    GameTooltip:Show()
end

local function Cell(index)
    if cells[index] then return cells[index] end
    local cell = CreateFrame("Frame", nil, holder)
    cell:SetHeight(ns.Snap(ICON))
    cell:EnableMouse(true)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(ns.Snap(ICON), ns.Snap(ICON))
    cell.icon:SetPoint("LEFT")
    cell.text = ns.CreateText(cell, 13, "LEFT", "OUTLINE")
    cell.text:SetPoint("LEFT", cell.icon, "RIGHT", 4, 0)
    cell:SetScript("OnEnter", CellEnter)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[index] = cell
    return cell
end

local function Update()
    if not holder then return end
    -- Forever only (Retail has no such reagents) - the preview works everywhere
    if not demoClass and (not Enabled() or not ns.IS_FOREVER) then return holder:Hide() end
    local list, class = Entries()
    local color = ClassColor(class)
    local y, width = 0, 1
    for i, entry in ipairs(list) do
        local cell = Cell(i)
        cell.entry = entry
        ns.SetIcon(cell.icon, "Reagent" .. entry.icon)
        cell.icon:SetVertexColor(unpack(color))
        cell.text:SetText(BreakUpLargeNumbers(entry.count))
        cell.text:SetTextColor(CountColor(entry.count, entry.warn))
        cell.blink = entry.count == 0
        local cellWidth = ns.Snap(ICON) + 4 + cell.text:GetUnboundedStringWidth()
        cell:SetWidth(cellWidth)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
        cell:Show()
        y = y + ns.Snap(ICON) + ns.Snap(ITEM_GAP)
        width = math.max(width, cellWidth)
        if not demoClass then Warn(entry) end
    end
    for i = #list + 1, #cells do cells[i]:Hide() end
    holder:SetSize(width, math.max(y - ns.Snap(ITEM_GAP), 1)) -- keeps the block centered next to the frame
    -- Preview: class name above
    holder.demoLabel:SetShown(demoClass ~= nil)
    if demoClass then
        holder.demoLabel:SetText(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[demoClass] or demoClass)
        holder.demoLabel:SetTextColor(unpack(color))
    end
    holder:SetShown(#list > 0)
end
ns.UpdateAmmoCounter = Update

local pending
local function RequestUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function() pending = false; Update() end)
end

-- Right of the player frame, vertically centered (anchored to the frame)
local function Place()
    local player = ns.frames and ns.frames.player
    if not (holder and player) then return end
    holder:ClearAllPoints()
    if ns.LayoutFlag and ns.LayoutFlag("healerGroups") then
        -- Healer layout: the group sits right of the player, so go left (the cast bar is not
        -- there in this layout)
        holder:SetPoint("RIGHT", player, "LEFT", -ns.Snap(GAP), 0)
    else
        holder:SetPoint("LEFT", player, "RIGHT", ns.Snap(GAP), 0)
    end
end

local function Create()
    holder = CreateFrame("Frame", "MeredanUIReagents", UIParent)
    holder:SetSize(1, ns.Snap(ICON))
    holder:SetFrameStrata("MEDIUM")
    holder.demoLabel = ns.CreateText(holder, 11, "LEFT", "OUTLINE")
    holder.demoLabel:SetPoint("BOTTOMLEFT", holder, "TOPLEFT", 0, 4)
    holder.demoLabel:Hide()
    -- Blink at 0
    local t = 0
    holder:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        local alpha = 0.35 + 0.65 * math.abs(math.sin(t * 3))
        for _, cell in ipairs(cells) do
            if cell:IsShown() then cell.text:SetAlpha(cell.blink and alpha or 1) end
        end
    end)
    holder:Hide()
end

-- Preview (Settings > Unit Frames): all classes in turn
local demoTicker
ns.ReagentsDemo = {
    Start = function()
        if not holder then return end
        local index = 0
        local function Next()
            index = index % #DEMO_ORDER + 1
            demoClass = DEMO_ORDER[index]
            Update()
        end
        if demoTicker then demoTicker:Cancel() end
        demoTicker = C_Timer.NewTicker(2.5, Next)
        Next()
    end,
    Stop = function()
        if demoTicker then demoTicker:Cancel(); demoTicker = nil end
        demoClass = nil
        Update()
    end,
    IsActive = function() return demoClass ~= nil end,
}

ns:On("PLAYER_LOGIN", function()
    local ok, slot = pcall(GetInventorySlotInfo, "AmmoSlot")
    if ok then ammoSlot = slot end
    Create()
    ns.layoutFrames.ammo = holder
    -- Preload item names for tooltip/toast
    for _, list in pairs(CLASS_REAGENTS) do
        for _, reagent in ipairs(list) do
            if reagent.item then C_Item.RequestLoadItemDataByID(reagent.item) end
        end
    end
    C_Timer.After(0.1, function()
        ns.OnLayout(Place)
        Place()
        Update()
    end)
    ns:On("BAG_UPDATE", RequestUpdate)
    ns:On("SPELLS_CHANGED", RequestUpdate) -- new spell learned: reagent may be needed now
    ns:On("BAG_UPDATE_DELAYED", RequestUpdate)
    ns:On("PLAYER_EQUIPMENT_CHANGED", RequestUpdate)
    ns:On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then RequestUpdate() end end)
end)
