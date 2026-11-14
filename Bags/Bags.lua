-- Bags: one window replacing Blizzard's individual bags. Category sections flow left to right,
-- "New" on top and every free slot at the bottom (like one big bag).
--
--   +- Bags --------------------------- [] 42  [x] -+
--   | [Search ..................................]   |
--   | New              Gear                          |
--   | [#][#]           [#][#][#][#]                  |
--   | Flasks           Herbs            Consumable    |
--   | [#][#]           [#][#][#]        [#][#]        |
--   | Junk                                            |
--   | [#]                                             |
--   | Free                                            |
--   | [ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]                  |
--   | 12,345 g                                        |
--   +-------------------------------------------------+
--
-- Category priority: see CategoryFor. Bears database = BagsData.lua (herbs, ore, flasks ...).
-- Item buttons use Blizzard's ContainerFrameItemButtonTemplate, so use, drag, sell, tooltips and
-- comparisons work as usual - in combat too.
local _, ns = ...
local L = ns.L

local SIZE = 36                  -- item buttons
local GAP, PAD = 6, 14
local HEADER = 16                -- section header height
local SECTION_GAP = 10           -- gap between sections
local FLOW_MIN_SLOTS, FLOW_MAX_SLOTS = 10, 20 -- category view width in slots (widens while too tall)
local BAGS = { 0, 1, 2, 3, 4, 5 } -- backpack, bags 1-4, reagent bag
local REAGENT_BAG = 5
-- Forever has the classic keyring (own tab, only while it holds keys)
local KEYRING = ns.IS_FOREVER and Enum.BagIndex and Enum.BagIndex.Keyring or nil
if KEYRING then BAGS[#BAGS + 1] = KEYRING end
local view = "bags" -- tab: "bags" (backpack + bags), "reagents" (reagent bag), "keys" (keyring)

local function ViewOf(bag)
    if bag == REAGENT_BAG then return "reagents" elseif bag == KEYRING then return "keys" end
    return "bags"
end

local function HasKeys()
    if not (KEYRING and C_ActionBar.ShouldShowKeyring and C_ActionBar.ShouldShowKeyring()) then return false end
    for slot = 1, C_Container.GetContainerNumSlots(KEYRING) do
        if C_Container.GetContainerItemID(KEYRING, slot) then return true end
    end
    return false
end

-- special bags (quiver, ammo pouch, soul/herb bags ...): only accept matching items
local function IsSpecialBag(bag)
    if bag == 0 or bag == REAGENT_BAG or bag == KEYRING then return false end
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    return family ~= nil and family ~= 0
end

local NEW, JUNK, OTHER, FREE = "New", "Junk", "Other", "Free"
-- free slots in special bags (quiver, ammo pouch, soul/herb bags ...) are counted separately:
-- they only accept matching items, so they don't belong to "Free"
local QUIVER, SPECIAL = "Quiver", "Special bags"
local AMMO_FAMILIES = { [1] = true, [2] = true } -- quiver (arrows), ammo pouch (bullets)
-- heading for the empty slots of special bags: the bags' own names ("Small Ammo Pouch"), set by Collect
local specialLabel
local function SectionLabel(key)
    if (key == QUIVER or key == SPECIAL) and specialLabel then return specialLabel end
    return L[key]
end
local isEquipKey = {} -- gear sections (head, finger, two-hand ...): show item level, sorted early

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, content, searchBox, freeText, goldText
local bagSlots = {} -- bag bar bottom right
local holders, buttons = {}, {}  -- holders[bag]: frame with ID = bag number; buttons[bag][slot]
local headers = {}               -- header pool
local categoryOf                 -- item ID -> Bears category (built on first open)
local dirty = true

local function Enabled() return ns.ModuleOn("bags") end

-- Categories ----------------------------------------------------------------------------------

local function BuildLookup()
    categoryOf = {}
    for key, ids in pairs(ns.BAG_CATEGORY_ITEMS or {}) do
        for _, id in ipairs(ids) do categoryOf[id] = key end
    end
end

local function CustomCategories()
    ns.root.bagCategories = ns.root.bagCategories or {}
    return ns.root.bagCategories
end

-- New items (like BetterBags' "Recent Items"): each newly received item stays in "New" for
-- 5 minutes. Items are re-sorted only on close or via Sort, so nothing jumps while the bag is open.
local NEW_ITEM_TIME = 300
local recent = {}   -- item GUID -> time it became new
local known         -- GUIDs already in the bags (nil until the first scan)
local slotGUID = {} -- GUID per slot from the last scan (bag * 1000 + slot)

local function ItemGUID(bag, slot)
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return location:IsValid() and C_Item.GetItemGUID(location) or nil
end

-- scan bags: anything not seen before is new (even without Blizzard's new flag)
local function ScanNewItems()
    local now, seen = time(), {}
    wipe(slotGUID)
    for _, bag in ipairs(BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local guid = ItemGUID(bag, slot)
            slotGUID[bag * 1000 + slot] = guid
            if guid then
                seen[guid] = true
                if not recent[guid] and ((known and not known[guid]) or C_NewItems.IsNewItem(bag, slot)) then
                    recent[guid] = now
                end
            end
        end
    end
    known = seen
end

local function ExpireNewItems()
    local now = time()
    for guid, since in pairs(recent) do
        if now - since >= NEW_ITEM_TIME or not (known and known[guid]) then recent[guid] = nil end
    end
end

-- Category of an item - priority like BetterBags with "Bears Ultimate":
-- New > equipment set > custom > tools > Bears > junk > equip slot > item type
local function CategoryFor(bag, slot, info)
    local guid = slotGUID[bag * 1000 + slot]
    if guid and recent[guid] then return NEW end
    local inSet, setList = C_Container.GetContainerItemEquipmentSetInfo(bag, slot)
    if inSet and setList and setList ~= "" then
        return L["Gear: %s"]:format(strsplit(",", setList))
    end
    local custom = CustomCategories()[info.itemID]
    if custom then return custom end
    -- profession tools (fishing pole, skinning knife, mining pick ...) always together rather than
    -- split by weapon type; detection shared with ToolGuard.lua
    if ns.IsProfessionTool and ns.IsProfessionTool(info.itemID) then return "Tools" end
    local bears = categoryOf[info.itemID]
    if bears then return bears end
    if info.quality == Enum.ItemQuality.Poor then return JUNK end
    local _, itemType, subType, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
    if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        local slotName = _G[equipLoc]
        if slotName and slotName ~= "" then
            if classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon then isEquipKey[slotName] = true end
            return slotName
        end
    end
    -- consumables and trade goods by subtype (food & drink, potion, cloth, herb ...): the Bears list
    -- covers mostly new Retail items, so on Forever everything would land in one pile
    -- (not for generic/other subtypes: consumable 0 and 8, trade goods 11 - those keep the class)
    local generic = (classID == Enum.ItemClass.Consumable and (subClassID == 0 or subClassID == 8))
        or (classID == Enum.ItemClass.Tradegoods and subClassID == 11)
    if (classID == Enum.ItemClass.Consumable or classID == Enum.ItemClass.Tradegoods)
        and not generic and subType and subType ~= "" and subType ~= itemType then
        return subType
    end
    return itemType or (classID and C_Item.GetItemClassInfo(classID)) or OTHER
end

-- section order: New, gear, then alphabetical, junk and free at the end
local function SectionOrder(a, b)
    local function Rank(key)
        if key == NEW then return 1 elseif isEquipKey[key] then return 2
        elseif key == JUNK then return 4 elseif key == FREE then return 5
        elseif key == QUIVER or key == SPECIAL then return 6 end
        return 3
    end
    local ra, rb = Rank(a), Rank(b)
    if ra ~= rb then return ra < rb end
    return L[a] < L[b]
end

-- Item buttons --------------------------------------------------------------------------------

local function QualityColor(quality)
    if quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

local function StyleButton(button)
    button:SetSize(SIZE, SIZE)
    button.emptyBackgroundAtlas = nil -- empty slots: our slot background instead of Blizzard's art
    ns.AddSlotBackground(button)
    button.muiBorder = ns.AddItemFrame(button)
    -- inner 2px edge in the same color: with the outer edge a 3px frame for quality/quest items.
    -- On its own frame above the cooldown swipe, which would otherwise darken it.
    local edgeFrame = CreateFrame("Frame", nil, button)
    edgeFrame:SetAllPoints()
    edgeFrame:SetFrameLevel((button.Cooldown and button.Cooldown:GetFrameLevel() or button:GetFrameLevel()) + 1)
    button.muiBorderInner = ns.AddBorder(edgeFrame, true, 2)
    local normal = button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end -- our border shows quality
    ns.InsetItemIcon(button, button.icon)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Forever resets tex coords to (0, 1, 0, 1) on every icon change (SetItemButtonTexture):
    -- crop again, otherwise the icons' beveled edge comes back
    hooksecurefunc(button.icon, "SetTexCoord", function(icon, left)
        if left ~= 0.08 then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end)
    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:SetColorTexture(1, 1, 1, 0.2)
        pushed:SetAllPoints()
    end
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(1, 1, 1, 0.15)
        highlight:SetAllPoints()
    end
    if button.Count then
        button.Count:SetFont(ns.STYLE.font, ns.FontPx(12), "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    button.muiLevel = ns.CreateText(button, 11, "LEFT", "OUTLINE")
    button.muiLevel:SetPoint("BOTTOMLEFT", 2, 2)
    -- upgrade arrow (Upgrades.lua) with a dark shadow so it stands out on any icon
    button.muiUpgrade = CreateFrame("Frame", nil, button)
    button.muiUpgrade:SetSize(18, 18)
    button.muiUpgrade:SetPoint("TOPLEFT", 1, -1)
    button.muiUpgrade:SetFrameLevel(button:GetFrameLevel() + 5)
    local shadow = ns.UI.Icon(button.muiUpgrade, "Upgrade", 18, { 0, 0, 0, 0.9 })
    shadow:SetPoint("CENTER", 1, -1)
    shadow:SetDrawLayer("OVERLAY", 1)
    local arrow = ns.UI.Icon(button.muiUpgrade, "Upgrade", 18, ns.UPGRADE_COLOR)
    arrow:SetPoint("CENTER")
    arrow:SetDrawLayer("OVERLAY", 2)
    button.muiUpgrade:Hide()
    -- "fills empty slot" (Upgrades.lua): Surf Green border, dot top left, gentle pulse
    local fill = CreateFrame("Frame", nil, button)
    fill:SetAllPoints()
    fill:SetFrameLevel(button:GetFrameLevel() + 4)
    local edges = ns.AddBorder(fill, true, 2)
    for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    local dot = fill:CreateTexture(nil, "OVERLAY", nil, 2)
    dot:SetSize(7, 7)
    dot:SetPoint("TOPLEFT", 3, -3)
    dot:SetColorTexture(unpack(ns.UI.ACCENT))
    local dotShadow = fill:CreateTexture(nil, "OVERLAY", nil, 1)
    dotShadow:SetPoint("TOPLEFT", dot, -1, 1)
    dotShadow:SetPoint("BOTTOMRIGHT", dot, 1, -1)
    dotShadow:SetColorTexture(0, 0, 0, 1)
    local pulse = fill:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(1.2)
    fade:SetSmoothing("IN_OUT")
    fill:SetScript("OnShow", function() pulse:Play() end)
    fill:SetScript("OnHide", function() pulse:Stop() end)
    fill:Hide()
    button.muiFill = fill
end

local QUEST_COLOR = { 1, 0.82, 0 }
local HEARTH_COLOR = { 0.48, 0.60, 0.42 } -- darker sage: stands out against the light hearthstone icon

-- Border: gold for quest items, sage for hearthstones, quality color from Uncommon up (all 3px),
-- else thin black.
-- Item level on gear and upgrade arrow. Used by the bag, bank and guild bank windows.
function ns.DecorateItemButton(button, info, showLevel, bag, slot)
    local quality = info and info.quality
    local r, g, b = unpack(ns.ITEM_EDGE)
    local strong = false
    if not categoryOf then BuildLookup() end
    if info and button.muiQuest then
        r, g, b, strong = QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3], true
    elseif info and categoryOf[info.itemID] == "Hearthstones" then
        r, g, b, strong = HEARTH_COLOR[1], HEARTH_COLOR[2], HEARTH_COLOR[3], true
    elseif quality and quality >= Enum.ItemQuality.Uncommon then
        r, g, b = QualityColor(quality)
        strong = true
    end
    for _, edge in ipairs(button.muiBorder) do edge:SetVertexColor(r, g, b, 1) end
    for _, edge in ipairs(button.muiBorderInner) do
        edge:SetVertexColor(r, g, b, 1)
        edge:SetShown(strong)
    end

    button.muiLevel:SetText("")
    if info and showLevel then
        -- no bag slot (guild bank): item level from the link
        local level = bag and C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot))
            or (info.hyperlink and C_Item.GetDetailedItemLevelInfo(info.hyperlink))
        if level and level > 1 then
            button.muiLevel:SetText(level)
            button.muiLevel:SetTextColor(QualityColor(quality))
        end
    end
    local fills = info and info.hyperlink and ns.FillsEmptySlot and ns.FillsEmptySlot(info.hyperlink)
    if button.muiFill then button.muiFill:SetShown(fills and true or false) end
    -- empty slot: marker instead of arrow (no meaningful percentage against nothing)
    local upgrade = not fills and info and info.hyperlink and ns.UpgradePercent(info.hyperlink) -- also in "New"
    button.muiUpgrade:SetShown(upgrade and upgrade >= 0.05 or false)
end

ns.StyleBagButton = StyleButton -- also used by the bank window (Bank.lua)

local CategoryMenu, Layout -- defined below

local function GetButton(bag, slot)
    buttons[bag] = buttons[bag] or {}
    local button = buttons[bag][slot]
    if button then return button end
    local holder = holders[bag]
    if not holder then
        -- Blizzard's buttons read the bag number from the parent frame
        holder = CreateFrame("Frame", "MeredanUIBagHolder" .. bag, content)
        holder:SetID(bag)
        holder:SetAllPoints()
        holder.IsCombinedBagContainer = function() return false end
        holders[bag] = holder
    end
    button = CreateFrame("ItemButton", "MeredanUIBagItem" .. bag .. "_" .. slot, holder, "ContainerFrameItemButtonTemplate")
    -- No SetBagID: the value would come from addon code (taint) and Blizzard then blocks using the
    -- item in combat. Without bagID, GetBagID reads the parent's ID (holder:SetID), like Bagnon/Baganator.
    button:SetID(slot)
    StyleButton(button)
    -- Alt+right-click: custom category (Blizzard doesn't use Alt+right-click)
    button:HookScript("OnClick", function(self, mouse)
        if mouse == "RightButton" and IsAltKeyDown() and self.muiItemID then CategoryMenu(self) end
        -- Shift+right-click at a vendor: sell a protected profession tool anyway
        if mouse == "RightButton" and IsShiftKeyDown()
            and C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Merchant)
            and ns.IsProfessionTool and ns.IsProfessionTool(self.muiItemID) then
            ns.SellToolAnyway(self:GetBagID(), self:GetID())
        end
    end)
    buttons[bag][slot] = button
    return button
end

-- showLevel: show item level (default: only in gear sections)
local function UpdateButton(button, info, showLevel)
    local bag, slot = button:GetBagID(), button:GetID()
    local texture = info and info.iconFileID
    ClearItemButtonOverlay(button)
    button:SetHasItem(texture)
    button:SetItemButtonTexture(texture)
    -- empty: Blizzard sets its slot art here (bags-item-slot64); our slot background is enough
    if not texture then button.icon:Hide() end
    SetItemButtonQuality(button, info and info.quality, info and info.hyperlink, false, info and info.isBound)
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
    SetItemButtonCount(button, info and info.stackCount)
    SetItemButtonDesaturated(button, info and info.isLocked)
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    button:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
    -- quest items get our gold border instead of Blizzard's glow; quest starters keep the "!" badge
    local starter = quest.questID and not quest.isActive
    button.muiQuest = (quest.questID or quest.isQuestItem) and true or false
    if button.muiQuest and not starter then button.IconQuestTexture:Hide() end
    button:UpdateNewItem(info and info.quality)
    button:UpdateJunkItem(info and info.quality, info and info.hasNoValue)
    button:UpdateItemContextMatching()
    button:UpdateCooldown(texture)
    button:SetReadable(info and info.IsReadable)
    button:CheckUpdateTooltip(GameTooltip:GetOwner())

    if showLevel == nil then showLevel = isEquipKey[button.muiCategory] end
    ns.DecorateItemButton(button, info, showLevel, bag, slot)
    button.muiItemID = info and info.itemID
    button.muiName = info and info.hyperlink and (C_Item.GetItemNameByID(info.itemID) or ""):lower() or ""
end

ns.UpdateBagButton = UpdateButton

-- search: dim non-matching items
local function ApplySearch()
    local query = searchBox and searchBox:GetText():lower() or ""
    for _, list in pairs(buttons) do
        for _, button in pairs(list) do
            if button:IsShown() then
                local match = query == "" or (button.muiName or ""):find(query, 1, true) ~= nil
                button:SetMatchesSearch(match)
            end
        end
    end
end

-- Layout --------------------------------------------------------------------------------------

-- drop or click an item onto a header: the item belongs to that category from now on
local function DropOnHeader(header)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID or header.key == FREE or header.key == QUIVER or header.key == SPECIAL then return end
    CustomCategories()[itemID] = header.key
    ClearCursor()
    Layout()
end

local function GetHeader(index)
    local header = headers[index]
    if not header then
        header = CreateFrame("Button", nil, content)
        header:SetHeight(HEADER - 2)
        header.text = ns.UI.Heading(header, 12, "LEFT")
        header.text:SetPoint("LEFT")
        header:SetScript("OnClick", DropOnHeader)
        header:SetScript("OnReceiveDrag", DropOnHeader)
        header:SetScript("OnEnter", function(self)
            if GetCursorInfo() == "item" and self.key ~= FREE and self.key ~= QUIVER and self.key ~= SPECIAL then
                self.text:SetTextColor(1, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["Drop here to always sort this item into %s"]:format(L[self.key]), 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        header:SetScript("OnLeave", function(self)
            self.text:SetTextColor(unpack(ns.UI.HEADING))
            GameTooltip:Hide()
        end)
        headers[index] = header
    end
    return header
end

local measure -- measures headers so sections are at least as wide as their name
local function TextWidth(text)
    measure = measure or ns.CreateText(UIParent, 12, "LEFT", nil, "display") -- same font as the headings
    measure:Hide()
    measure:SetText(text)
    return math.ceil(measure:GetUnboundedStringWidth())
end

local function ItemSort(a, b)
    if a.quality ~= b.quality then return (a.quality or 0) > (b.quality or 0) end
    if a.name ~= b.name then return a.name < b.name end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

-- read all slots of visible bags: items (with category) and empty slots per bag
local function Collect()
    ScanNewItems()
    local items, empties, free = {}, {}, 0
    local special = { count = 0, key = nil }
    local names, seen = {}, {}
    for _, bag in ipairs(BAGS) do
        local numSlots = ViewOf(bag) == view and C_Container.GetContainerNumSlots(bag) or 0
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        local isSpecial = IsSpecialBag(bag)
        empties[bag] = {}
        for slot = 1, numSlots do
            local button = GetButton(bag, slot)
            local info = C_Container.GetContainerItemInfo(bag, slot)
            button:Hide()
            local entry = { button = button, info = info, bag = bag, slot = slot }
            if info and info.itemID then
                entry.key = CategoryFor(bag, slot, info)
                button.muiCategory = entry.key
                entry.itemID, entry.quality = info.itemID, info.quality
                entry.name = C_Item.GetItemNameByID(info.itemID) or ""
                entry.isNew = entry.key == NEW
                entry.classID = select(6, C_Item.GetItemInfoInstant(info.itemID)) or 99
                items[#items + 1] = entry
            elseif isSpecial then
                special.count = special.count + 1
                local bagName = C_Container.GetBagName(bag)
                if bagName and bagName ~= "" and not seen[bagName] then
                    seen[bagName] = true
                    names[#names + 1] = bagName
                end
                local key = AMMO_FAMILIES[family] and QUIVER or SPECIAL
                special.key = (special.key == nil or special.key == key) and key or SPECIAL
                button.muiCategory = special.key
                empties[bag][#empties[bag] + 1] = entry
            else
                free = free + 1
                button.muiCategory = FREE
                empties[bag][#empties[bag] + 1] = entry
            end
        end
        -- hide buttons for slots that no longer exist (smaller bag)
        for slot, button in pairs(buttons[bag] or {}) do
            if slot > numSlots then button:Hide() end
        end
    end
    specialLabel = #names > 0 and table.concat(names, " / ") or nil
    return items, empties, free, special
end

-- empty slots split into normal ones ("Free") and those of special bags (quiver ...)
local function SplitEmpties(empties)
    local free, special = {}, {}
    for _, bag in ipairs(BAGS) do
        for _, entry in ipairs(empties[bag] or {}) do
            local list = entry.button.muiCategory == FREE and free or special
            list[#list + 1] = entry
        end
    end
    return free, special
end

local function MaxContentHeight() return UIParent:GetHeight() - 2 * ns.SCREEN_MARGIN - 120 end

-- Empty slots are shown individually (like one big bag), so items can be dropped straight
-- onto a free slot; they keep bag order instead of being sorted.
local function LayoutCategories(items, empties, special)
    local sections, unsorted = {}, {}
    for _, entry in ipairs(items) do
        sections[entry.key] = sections[entry.key] or {}
        table.insert(sections[entry.key], entry)
    end
    local freeList, specialList = SplitEmpties(empties)
    if #freeList > 0 then sections[FREE], unsorted[FREE] = freeList, true end
    if #specialList > 0 and special.key then
        sections[special.key], unsorted[special.key] = specialList, true
    end
    local keys = {}
    for key in pairs(sections) do keys[#keys + 1] = key end
    table.sort(keys, SectionOrder)

    -- Flow layout: sections run left to right and wrap when the row is full; "New" (top) and
    -- "Free" (bottom) take whole rows. Starts FLOW_MIN_SLOTS wide, widens while too tall.
    local maxHeight = MaxContentHeight()
    local width, placed, placedHeight
    for slots = FLOW_MIN_SLOTS, FLOW_MAX_SLOTS do
        width = slots * (SIZE + GAP) - GAP
        placed, placedHeight = {}, 0
        local x, y, rowHeight = 0, 0, 0
        local function NewRow()
            if x > 0 then y, x, rowHeight = y + rowHeight + SECTION_GAP, 0, 0 end
        end
        local function Place(key, fullRow)
            local count = #sections[key]
            local cols = math.min(count, slots)
            local w = math.max(cols * (SIZE + GAP) - GAP, TextWidth(SectionLabel(key)) + 4)
            local h = HEADER + math.ceil(count / cols) * (SIZE + GAP) - GAP
            if fullRow or x + w > width then NewRow() end
            placed[#placed + 1] = { key = key, x = x, y = y, cols = cols }
            x, rowHeight = x + w + SECTION_GAP, math.max(rowHeight, h)
            placedHeight = math.max(placedHeight, y + h)
            if fullRow then NewRow() end
        end
        if sections[NEW] then Place(NEW, true) end
        for _, key in ipairs(keys) do
            if key ~= NEW and key ~= FREE then Place(key) end
        end
        if sections[FREE] then Place(FREE, true) end
        if placedHeight <= maxHeight then break end
    end

    for _, header in ipairs(headers) do header:Hide() end
    for index, section in ipairs(placed) do
        local header = GetHeader(index)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", content, "TOPLEFT", section.x, -section.y)
        header.key = section.key
        header.text:SetText(SectionLabel(section.key))
        header:SetWidth(math.max(header.text:GetUnboundedStringWidth(), 1))
        header:Show()
        local list = sections[section.key]
        if not unsorted[section.key] then table.sort(list, ItemSort) end
        for i, entry in ipairs(list) do
            local col, row = (i - 1) % section.cols, math.floor((i - 1) / section.cols)
            local button = entry.button ---@type table
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", content, "TOPLEFT",
                section.x + col * (SIZE + GAP), -(section.y + HEADER + row * (SIZE + GAP)))
            UpdateButton(button, entry.info)
            button:Show()
        end
    end

    return width, placedHeight
end

function Layout()
    if not window then return end
    if not categoryOf then BuildLookup() end
    dirty = false

    if (view == "reagents" and C_Container.GetContainerNumSlots(REAGENT_BAG) == 0)
        or (view == "keys" and not HasKeys()) then
        view = "bags"
    end
    for _, header in ipairs(headers) do header:Hide() end
    local items, empties, free, special = Collect()
    local width, height = LayoutCategories(items, empties, special)

    content:SetSize(width, height)
    window:SetSize(width + 2 * PAD, height + 2 * PAD + 58 + 30)
    -- free slots as icon + number instead of "17 free"; quiver/ammo pouch with an arrow icon
    -- next to it. Explanation in the tooltip.
    local function Icon(name) return ("|T%sIcons\\%s:13:13:0:0|t"):format(ns.MEDIA, name) end
    local freeLine = Icon("Square") .. " " .. free
    if special.count > 0 then
        freeLine = freeLine .. "   " .. Icon(special.key == QUIVER and "ReagentArrow" or "Bag") .. " " .. special.count
    end
    freeText:SetText(freeLine)
    freeText.muiFree, freeText.muiSpecial, freeText.muiSpecialKey = free, special.count, special.key
    goldText:Update()
    window.UpdateTabs()
    window.PlaceBagSlots()
    for bag, slotButton in pairs(bagSlots) do
        slotButton.icon:SetTexture(GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bag)))
    end
    ApplySearch()
end

-- Custom categories (Alt+right-click) ---------------------------------------------------------

StaticPopupDialogs["MEREDANUI_BAG_CATEGORY"] = {
    text = L["Name of the new category:"],
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self, itemID)
        local box = self.GetEditBox and self:GetEditBox() or self.editBox or self.EditBox
        local name = box and strtrim(box:GetText() or "")
        if name and name ~= "" then
            CustomCategories()[itemID] = name
            Layout()
        end
    end,
    EditBoxOnEnterPressed = function(box)
        local popup = box:GetParent()
        StaticPopupDialogs["MEREDANUI_BAG_CATEGORY"].OnAccept(popup, popup.data)
        popup:Hide()
    end,
    EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function CategoryMenu(button)
    local itemID = button.muiItemID
    local custom = CustomCategories()
    local names, seen = {}, {}
    for _, name in pairs(custom) do
        if not seen[name] then seen[name] = true; names[#names + 1] = name end
    end
    table.sort(names)
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(C_Item.GetItemNameByID(itemID) or L["Category"])
        for _, name in ipairs(names) do
            root:CreateRadio(name, function() return custom[itemID] == name end,
                function() custom[itemID] = name; Layout() end)
        end
        root:CreateButton(L["New category…"], function()
            StaticPopup_Show("MEREDANUI_BAG_CATEGORY", nil, nil, itemID)
        end)
        if custom[itemID] then
            root:CreateButton(L["Remove from category"], function() custom[itemID] = nil; Layout() end)
        end
    end)
end

-- Window --------------------------------------------------------------------------------------

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIBags", UIParent)
    window:SetFrameStrata("MEDIUM")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor, true)
    ns.RuneFrame(window)
    tinsert(UISpecialFrames, "MeredanUIBags") -- Esc closes

    local margin = ns.Snap(ns.SCREEN_MARGIN)
    -- bottom right above the micro menu (room for micro menu and bag buttons)
    -- the window frame's outer edge sits on the margin / above micro menu and bag bar
    local reach = ns.WindowFrameReach()
    window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -margin - reach, margin + 28 + 8 + 28 + 8 + reach)

    -- tabs: Bags | Reagents (only with a reagent bag)
    local tabs = {}
    local function Tab(key, label)
        local tab = CreateFrame("Button", nil, window)
        -- rune look: Cinzel title, the active tab marked by an accent diamond
        tab.text = UI.Title(tab, 16, "LEFT")
        tab.text:SetPoint("LEFT", 14, 0)
        tab.text:SetText(label)
        tab:SetSize(tab.text:GetUnboundedStringWidth() + 16, 22)
        tab.line = UI.Diamond(tab, 6)
        tab.line:SetPoint("LEFT", 2, 0)
        tab:SetScript("OnClick", function() window.ShowView(key) end)
        tabs[key] = tab
        return tab
    end
    Tab("bags", L["Bags"]):SetPoint("TOPLEFT", PAD, -PAD)
    Tab("reagents", L["Reagents"]):SetPoint("LEFT", tabs.bags, "RIGHT", 14, 0)
    Tab("keys", L["Keys"])
    function window.ShowView(key)
        if view ~= key then
            view = key
            Layout()
        end
    end
    function window.UpdateTabs()
        tabs.reagents:SetShown(C_Container.GetContainerNumSlots(REAGENT_BAG) > 0)
        tabs.keys:SetShown(HasKeys())
        tabs.keys:ClearAllPoints()
        tabs.keys:SetPoint("LEFT", tabs.reagents:IsShown() and tabs.reagents or tabs.bags, "RIGHT", 14, 0)
        for key, tab in pairs(tabs) do
            local active = key == view
            tab.text:SetTextColor(unpack(active and UI.TITLE or UI.MUTED))
            tab.line:SetShown(active)
        end
    end
    local close = UI.IconButton(window, "Close", function() window:Hide() end, 22)
    close:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 2)
    freeText = UI.Text(window, 12, "RIGHT", UI.MUTED)
    -- Sort: Blizzard's bag sort (merges stacks, moves reagents into the reagent bag)
    local sort = UI.IconButton(window, "Sort", function()
        -- sort new items in right away (clear Blizzard's new flag too, else they count as new
        -- again on the next scan)
        wipe(recent)
        C_NewItems.ClearAll()
        C_Container.SortBags()
        Layout()
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01 or SOUNDKIT.IG_BACKPACK_OPEN)
    end, 22)
    sort:SetPoint("RIGHT", close, "LEFT", -4, 0)
    sort:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Sort bags"], 1, 1, 1)
        GameTooltip:AddLine(L["Stacks items and moves reagents into the reagent bag."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    sort:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- show/hide bag slots bottom right (default: off)
    local function UpdateBagSlots()
        for _, slotButton in pairs(bagSlots) do slotButton:SetShown(ns.db.bagsShowSlots == true) end
    end
    window.UpdateBagSlots = UpdateBagSlots
    local slotsToggle = UI.IconButton(window, "Bag", function()
        ns.db.bagsShowSlots = not ns.db.bagsShowSlots
        UpdateBagSlots()
    end, 22)
    slotsToggle:SetPoint("RIGHT", sort, "LEFT", -4, 0)
    slotsToggle:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Bag slots"], 1, 1, 1)
        GameTooltip:AddLine(L["Shows or hides your bags at the bottom (swap by dragging onto them)."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    slotsToggle:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- fishing bag: only while a pole is equipped (Loot/Fishing.lua loads after us -> look up at runtime)
    local fishing = UI.IconButton(window, "Fishing", function()
        if ns.Fishing then ns.Fishing.Toggle() end
    end, 22)
    fishing:SetPoint("RIGHT", slotsToggle, "LEFT", -4, 0)
    fishing:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Fishing bag"], 1, 1, 1)
        GameTooltip:Show()
    end)
    fishing:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local function UpdateFishingButton()
        local F = ns.Fishing
        local on = F and F.Enabled() and F.PoleEquipped() or false
        fishing:SetShown(on)
        freeText:ClearAllPoints()
        freeText:SetPoint("RIGHT", on and fishing or slotsToggle, "LEFT", -8, 0)
    end
    UpdateFishingButton()
    window:HookScript("OnShow", UpdateFishingButton)
    ns:On("PLAYER_EQUIPMENT_CHANGED", function() if window:IsShown() then UpdateFishingButton() end end)
    -- tooltip over the display (FontStrings don't take mouse input)
    local freeHover = CreateFrame("Frame", nil, window)
    freeHover:SetAllPoints(freeText)
    freeHover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["%d free slots"]:format(freeText.muiFree or 0), 1, 1, 1)
        if (freeText.muiSpecial or 0) > 0 then
            GameTooltip:AddLine(SectionLabel(freeText.muiSpecialKey) .. ": " .. freeText.muiSpecial, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    freeHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

    goldText = ns.GoldDisplay(window) -- same as the info bar, tooltip with all characters
    goldText:SetPoint("BOTTOMLEFT", PAD, PAD + 4)

    -- bag bar bottom right: view bags, swap (drag onto), highlight contents
    for bag = 5, 1, -1 do
        local slotButton = CreateFrame("Button", nil, window)
        slotButton:SetSize(22, 22)
        ns.AddSlotBackground(slotButton)
        ns.AddItemFrame(slotButton, nil, 2)
        slotButton.icon = slotButton:CreateTexture(nil, "ARTWORK")
        ns.InsetItemIcon(slotButton, slotButton.icon, nil, 2)
        slotButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local inventorySlot = C_Container.ContainerIDToInventoryID(bag)
        slotButton:RegisterForDrag("LeftButton")
        local function Put()
            if CursorHasItem() then PutItemInBag(inventorySlot) else PickupBagFromSlot(inventorySlot) end
        end
        -- click on the reagent bag: show its tab (dragging still picks it up)
        slotButton:SetScript("OnClick", function()
            if bag == REAGENT_BAG and not CursorHasItem() and C_Container.GetContainerNumSlots(bag) > 0 then
                window.ShowView("reagents")
            else
                Put()
            end
        end)
        slotButton:SetScript("OnDragStart", function() PickupBagFromSlot(inventorySlot) end)
        slotButton:SetScript("OnReceiveDrag", Put)
        slotButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if not GameTooltip:SetInventoryItem("player", inventorySlot) then
                GameTooltip:SetText(bag == 5 and L["Reagent bag"] or L["Bag slot"], 1, 1, 1)
            end
            GameTooltip:Show()
            -- highlight this bag's items
            for b, list in pairs(buttons) do
                for _, button in pairs(list) do
                    if button:IsShown() then button:SetMatchesSearch(b == bag) end
                end
            end
        end)
        slotButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
            ApplySearch()
        end)
        bagSlots[bag] = slotButton
    end
    -- order left to right: normal bags, special bags (quiver, ammo pouch ...), reagent bag
    function window.PlaceBagSlots()
        -- grouped by what is in the slot (not by slot number): a normal bag in the reagent slot
        -- counts as a normal bag, an empty reagent slot stays at the end
        local function IsReagentBag(bag)
            local id = GetInventoryItemID("player", C_Container.ContainerIDToInventoryID(bag))
            if not id then return bag == REAGENT_BAG end
            local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
            return classID == Enum.ItemClass.Container and subclassID == Enum.ItemContainerSubclass.Reagent
        end
        local function Group(bag)
            if IsReagentBag(bag) then return 3 end
            return IsSpecialBag(bag) and 2 or 1
        end
        local order = {}
        for group = 1, 3 do
            for bag = 1, REAGENT_BAG do if Group(bag) == group then order[#order + 1] = bag end end
        end
        -- a wider gap between the groups, so special bags and the reagent slot read as separate
        local previous, previousBag
        for i = #order, 1, -1 do
            local slotButton = bagSlots[order[i]]
            slotButton:ClearAllPoints()
            if previous then
                slotButton:SetPoint("RIGHT", previous, "LEFT", Group(order[i]) ~= Group(previousBag) and -12 or -4, 0)
            else
                slotButton:SetPoint("BOTTOMRIGHT", -PAD, PAD)
            end
            previous, previousBag = slotButton, order[i]
        end
    end
    window.PlaceBagSlots()
    window.UpdateBagSlots()

    window:SetScript("OnShow", function()
        if dirty then Layout() end
        PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    end)
    window:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
        searchBox:SetText("")
        searchBox:ClearFocus()
        -- "New" lasts until close; on next open the items are sorted in
        C_NewItems.ClearAll() -- only the glow; "New" is handled by ExpireNewItems
        ExpireNewItems()
        view = "bags"
        dirty = true
        -- close Blizzard's bags too, else "B" needs two presses afterwards
        if IsAnyBagOpen() then CloseAllBags() end
    end)
end

-- Open/close: Blizzard's bag logic stays (B key, vendor, bank ...); its frames are parked
-- invisibly and our window just follows their state (IsAnyBagOpen).
local function Sync()
    if not window then return end
    local open = IsAnyBagOpen()
    if open and not window:IsShown() then
        window:Show()
    elseif not open and window:IsShown() then
        window:Hide()
    end
end

local function HideBlizzardBags()
    if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(hidden) end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame then frame:SetParent(hidden) end
    end
end

-- Vendor: sell junk and repair (guild bank first) ---------------------------------------------

local function SellJunkAndRepair()
    if ns.db.bagsAutoJunk == false then return end
    -- selling uses Blizzard's own "sell all junk" call (addons may not use items)
    local earned, sold = 0, 0
    for _, bag in ipairs(BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                local price = select(11, C_Item.GetItemInfo(info.itemID)) or 0
                earned = earned + price * (info.stackCount or 1)
                sold = sold + 1
            end
        end
    end
    if sold > 0 and C_MerchantFrame.SellAllJunkItems and pcall(C_MerchantFrame.SellAllJunkItems) then
        ns.Print(L["Sold junk for %s."]:format(GetMoneyString(earned, true)))
    end

    if CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost > 0 then
            local useGuild = ns.UseGuildRepair(cost)
            if useGuild or GetMoney() >= cost then
                RepairAllItems(useGuild)
                ns.Print((useGuild and L["Repaired for %s (guild bank)."] or L["Repaired for %s."])
                    :format(GetMoneyString(cost, true)))
            end
        end
    end
end

-- Guild bank pays only when the player turned it on (off by default) and the guild allows enough
function ns.UseGuildRepair(cost)
    if not ns.db.repairGuild or not IsInGuild() or not CanGuildBankRepair() then return false end
    local guildMoney = GetGuildBankWithdrawMoney()
    return guildMoney == -1 or guildMoney >= cost
end

-- Startup -------------------------------------------------------------------------------------

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    if C_AddOns.IsAddOnLoaded("BetterBags") then
        ns.Print(L["BetterBags is active – mUI bags stay off. Disable it to use ours."])
        return
    end
    CreateWindow()
    HideBlizzardBags()
    C_Timer.After(2, ScanNewItems) -- items present at login don't count as new
    for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "ToggleBackpack", "ToggleBag",
        "OpenBackpack", "CloseBackpack", "OpenBag", "CloseBag" }) do
        if _G[name] then hooksecurefunc(name, Sync) end
    end
    -- reagent bag clicked in the bag bar: open mUI bags on the reagents tab
    hooksecurefunc("ToggleBag", function(id)
        if id ~= REAGENT_BAG or C_Container.GetContainerNumSlots(id) == 0 then return end
        if not window:IsShown() then window:Show() end
        window.ShowView("reagents")
    end)
end)

-- Events arrive in bursts (equipping fires lock, bag, equipment events repeatedly ...): rebuild
-- once shortly after; with the bag closed, only on next open.
local pending
local function Refresh()
    if not window then return end
    if not window:IsShown() then
        dirty = true
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        if window:IsShown() then Layout() end
    end)
end

ns.RefreshBags = Refresh -- e.g. new upgrade scoring after a spec change
ns:On("BAG_UPDATE_DELAYED", Refresh)
ns:On("BAG_CONTAINER_UPDATE", Refresh)       -- bag swapped
ns:On("PLAYER_EQUIPMENT_CHANGED", Refresh)
ns:On("QUEST_ACCEPTED", Refresh)
ns:On("UNIT_QUEST_LOG_CHANGED", function(_, unit) if unit == "player" then Refresh() end end) -- fires for every group member
ns:On("ITEM_LOCK_CHANGED", function(_, bag, slot)
    local button = bag and slot and buttons[bag] and buttons[bag][slot]
    if button and button:IsShown() then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        SetItemButtonDesaturated(button, info and info.isLocked)
    end
end)
ns:On("BAG_UPDATE_COOLDOWN", function()
    if not (window and window:IsShown()) then return end
    for _, list in pairs(buttons) do
        for _, button in pairs(list) do
            if button:IsShown() and button.muiItemID then button:UpdateCooldown(button:HasItem()) end
        end
    end
end)
ns:On("MERCHANT_SHOW", function() if window then SellJunkAndRepair() end end)
