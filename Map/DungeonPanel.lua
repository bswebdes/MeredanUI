-- Dungeon panel in the world map's right column while a dungeon map is shown (replaces the quest log):
-- "Bosses" tab + wishlist button, bosses as an accordion in map pin order. Clicking a boss (row or its
-- pin on the map) opens its loot below it with a "For me / All" filter; the star keeps an item on the
-- wishlist (Character/Wishlist.lua, own window docked right of the map).
--
--   +- right column ---------------------------+
--   | [ Bosses                    ] [* 3]       |
--   | <1> Lady Anacondra              3 items   |
--   |   [For me] [All]                          |
--   |   [icon] Belt of the Fang     Leather  *  |
--   | <2> Lord Cobrahn                3 items   |
--   | Drop chances from classic data ...        |
local _, ns = ...
local L = ns.L

local P = {}
ns.DungeonPanel = P

local BOSS_ROW, LOOT_ROW, GAP = 42, 38, 4
local frame, list, tab, wishButton, filterBar, note
local bossRows, lootRows = {}, {}
local selected -- encounter ID or "rare:<npcID>"
local shownInstance
local hiddenFrames = {}

local GOLD = { 0.85, 0.71, 0.42 }
local BLACK = { 0, 0, 0, 1 }
local SELECTED_BG = { 0.10, 0.145, 0.137, 1 }
local ROW_BG = { 0.08, 0.094, 0.094, 1 }

-- "For me": best armour type and usable weapons per class (classic proficiencies, trainable ones count).
-- Weapon subclasses (Enum.ItemWeaponSubclass): 0 axe1H, 1 axe2H, 2 bow, 3 gun, 4 mace1H, 5 mace2H,
-- 6 polearm, 7 sword1H, 8 sword2H, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local ARMOUR = { WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local function Set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WEAPONS = {
    WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE = Set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST = Set(4, 10, 15, 19),
    SHAMAN = Set(0, 1, 4, 5, 10, 13, 15),
    MAGE = Set(7, 10, 15, 19),
    WARLOCK = Set(7, 10, 15, 19),
    DRUID = Set(4, 5, 10, 13, 15),
}
local ANY_SLOT = Set("INVTYPE_CLOAK", "INVTYPE_NECK", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_HOLDABLE")

local function ForMe(itemID)
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    local class = select(2, UnitClass("player"))
    if classID == Enum.ItemClass.Armor then
        if ANY_SLOT[equipLoc] or subclassID == 0 then return true end
        if subclassID == 6 then return SHIELD[class] or false end
        if subclassID >= 1 and subclassID <= 4 then return subclassID == ARMOUR[class] end
        return true
    elseif classID == Enum.ItemClass.Weapon then
        return WEAPONS[class] == nil or WEAPONS[class][subclassID] or false
    end
    return true -- bags, recipes, quest items
end

local function FilterMine() return not (ns.char and ns.char.dungeonLootAll) end

-- Bosses of the instance in pin/number order, plus rares that have loot
local function Sources(instance)
    local out = {}
    local loot = ns.DUNGEON_LOOT[instance] or {}
    local pins = ns.DUNGEON_PINS and ns.DUNGEON_PINS[instance] or {}
    local display = {}
    for _, p in ipairs(pins) do if p.kind == "boss" then display[p.id] = p.display end end
    for i, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[instance] or {}) do
        out[#out + 1] = { key = b[1], number = i, name = GetLocale() == "deDE" and b[3] or b[2], items = loot[b[1]] or {},
            display = display[b[1]] }
    end
    for _, p in ipairs(pins) do
        local key = "rare:" .. p.id
        if p.kind == "rare" and loot[key] then
            out[#out + 1] = { key = key, rare = true, name = p.name, items = loot[key], display = p.display }
        end
    end
    return out
end

local function Visible(items)
    if not FilterMine() then return items end
    local out = {}
    for _, entry in ipairs(items) do if ForMe(entry[1]) then out[#out + 1] = entry end end
    return out
end

-- Instances whose boss pins Benny checked in the game; released one by one (Map/DungeonLoot.lua has more)
local READY = { [43] = true }

-- Items seen dropping in Forever (account-wide): looting in an instance marks its listed items
local function Seen()
    MeredanUIDB.lootSeen = MeredanUIDB.lootSeen or {}
    return MeredanUIDB.lootSeen
end
ns:On("LOOT_OPENED", function()
    local inInstance = IsInInstance()
    local instance = inInstance and select(8, GetInstanceInfo())
    local loot = instance and ns.DUNGEON_LOOT[instance]
    if not loot then return end
    local listed = {}
    for _, items in pairs(loot) do for _, entry in ipairs(items) do listed[entry[1]] = true end end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local id = link and not ns.issecretvalue(link) and C_Item.GetItemInfoInstant(link)
        if id and listed[id] then Seen()[id] = true end
    end
end)

-- Flat button with 1px border; TabStyle marks the active one (accent border + text)
local function SmallButton(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.098, 0.098, 0.11, 1)
    b.edges = ns.AddBorder(b)
    b.text = ns.UI.Text(b, 12, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    return b
end

local function TabStyle(button, active)
    for _, e in ipairs(button.edges) do e:SetVertexColor(unpack(active and ns.UI.ACCENT or BLACK)) end
    button.text:SetTextColor(unpack(active and ns.UI.ACCENT or ns.UI.MUTED))
end

local function BossRow(i)
    if bossRows[i] then return bossRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(BOSS_ROW)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    ns.AddBorder(row)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT")
    row.bar:SetWidth(2)
    row.bar:SetColorTexture(unpack(UI.ACCENT))
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    -- same round boss portrait + number badge as the pin on the map (Map/DungeonPins.lua)
    row.pin = CreateFrame("Frame", nil, row)
    row.pin:SetPoint("LEFT", 6, 0)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 54, 0)
    row.name:SetPoint("RIGHT", -70, 0)
    row.name:SetWordWrap(false)
    row.count = UI.Text(row, 11, "RIGHT", UI.MUTED)
    row.count:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnClick", function(self)
        if selected == self.key then P.Select(nil) else P.Select(self.key) end
    end)
    bossRows[i] = row
    return row
end

local function LootRow(i)
    if lootRows[i] then return lootRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(LOOT_ROW)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ROW_BG))
    ns.AddBorder(row)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.Text(row, 13, "LEFT")
    ns.SetFont(row.name, 13, "", "bold")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", -38, 0)
    row.name:SetWordWrap(false)
    row.kind = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.kind:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.kind:SetPoint("RIGHT", -38, 0)
    row.kind:SetWordWrap(false)
    row.star = SmallButton(row, "", 24, 24)
    row.star:SetPoint("RIGHT", -6, 0)
    row.star.icon = UI.Icon(row.star, "Star", 14, GOLD)
    row.star.icon:SetPoint("CENTER")
    row.star:SetScript("OnClick", function()
        ns.Wishlist.Toggle(row.itemID, ns.DungeonMapView.instance, selected)
    end)
    row.star:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.Wishlist.Has(row.itemID) and L["Remove from wishlist"] or L["Add to wishlist"], 1, 1, 1)
        GameTooltip:Show()
    end)
    row.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") then
            local _, link = C_Item.GetItemInfo(self.itemID)
            if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
        end
    end)
    lootRows[i] = row
    return row
end

-- "Waist · Leather · 25 %" from the instant item data (no server round trip); a check mark when the
-- item was seen dropping in Forever
local function KindText(itemID, chance)
    local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(itemID)
    local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
    local parts = {}
    if slot then parts[#parts + 1] = slot end
    if subType and subType ~= "" and subType ~= slot then parts[#parts + 1] = subType end
    if chance then parts[#parts + 1] = ("%s %%"):format(chance) end
    local text = table.concat(parts, "  ·  ")
    if Seen()[itemID] then text = text .. "  |T" .. ns.MEDIA .. "Icons\\Check:11:11:0:0:64:64:0:64:0:64:142:203:180|t" end
    return text
end

local function FillLoot(row, entry)
    local id = entry[1]
    row.itemID = id
    row.icon:SetTexture(C_Item.GetItemIconByID(id))
    row.kind:SetText(KindText(id, entry[2]))
    row.name:SetText("")
    row.star.icon:SetAlpha(ns.Wishlist.Has(id) and 1 or 0.3)
    local item = Item:CreateFromItemID(id)
    item:ContinueOnItemLoad(function()
        if row.itemID ~= id then return end
        row.name:SetText(item:GetItemName() or "")
        local color = item:GetItemQualityColor()
        if color then row.name:SetTextColor(color.r, color.g, color.b) end
    end)
end

local function Place(region, y, indent)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", list.child, "TOPLEFT", indent or 0, -y)
    region:SetPoint("RIGHT", list.child, "RIGHT")
end

local function Layout(instance)
    for _, r in ipairs(bossRows) do r:Hide() end
    for _, r in ipairs(lootRows) do r:Hide() end
    filterBar:Hide()
    local y, nLoot = 0, 0
    for i, s in ipairs(Sources(instance)) do
        local row = BossRow(i)
        local open = s.key == selected
        local visible = Visible(s.items)
        row.key = s.key
        ns.DungeonPins.StylePin(row.pin, s.rare and "rare" or "boss", s.number, s.display)
        row.name:SetText(s.name or "")
        row.name:SetTextColor(unpack(open and ns.UI.ACCENT or ns.UI.TEXT))
        row.bg:SetColorTexture(unpack(open and SELECTED_BG or ROW_BG))
        row.bar:SetShown(open)
        row.count:SetText(#s.items == 0 and "" or #visible == 1 and L["1 item"] or L["%d items"]:format(#visible))
        Place(row, y)
        row:Show()
        y = y + BOSS_ROW + GAP
        if open then
            Place(filterBar, y + 2, 8)
            filterBar:Show()
            y = y + 24 + GAP + 4
            for _, entry in ipairs(visible) do
                nLoot = nLoot + 1
                local loot = LootRow(nLoot)
                FillLoot(loot, entry)
                Place(loot, y, 8)
                loot:Show()
                y = y + LOOT_ROW + GAP
            end
            y = y + 6
        end
    end
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", list.child, "TOPLEFT", 2, -(y + 6))
    note:SetPoint("RIGHT", list.child, "RIGHT", -2, 0)
    list.child:SetHeight(y + 40)
end

local function UpdateHeader()
    wishButton.text:SetText(ns.Wishlist.Count())
    local open = ns.Wishlist.IsWindowShown()
    for _, e in ipairs(wishButton.edges) do e:SetVertexColor(unpack(open and GOLD or BLACK)) end
    TabStyle(filterBar.mine, FilterMine())
    TabStyle(filterBar.all, not FilterMine())
end

function P.Selected() return frame and frame:IsShown() and selected or nil end

function P.Refresh()
    if not frame then return end
    local view = ns.DungeonMapView
    local instance = view and view.IsShown() and view.instance
    local active = instance and READY[instance] and ns.DUNGEON_LOOT[instance] ~= nil or false
    frame:SetShown(active)
    for _, f in ipairs(hiddenFrames) do f:SetAlpha(active and 0 or 1) end
    if not active then return end
    if instance ~= shownInstance then selected, shownInstance = nil, instance end
    UpdateHeader()
    Layout(instance)
end

-- Called by a boss pin click (Map/DungeonPins.lua) or a list row; nil closes the open boss
function P.Select(key)
    selected = key
    PlaySound(key and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    P.Refresh()
    if ns.DungeonPins then ns.DungeonPins.Refresh() end
end

-- Build over the quest log column. topLeft/bottomRight = corner frames of that column; hide = the
-- quest log's own widgets (faded out while the panel shows, so nothing shines through)
function P.Attach(parent, topLeft, bottomRight, hide)
    local UI = ns.UI
    hiddenFrames = hide or {}
    frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", topLeft, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMRIGHT", 8, 0)
    frame:SetFrameLevel(parent:GetFrameLevel() + 50)
    frame:EnableMouse(true)
    frame:Hide()

    tab = SmallButton(frame, L["Bosses"], 10, 30)
    tab:SetPoint("TOPLEFT")
    tab:SetPoint("TOPRIGHT", -70, 0)
    ns.SetFont(tab.text, 13, "", "bold")
    TabStyle(tab, true)

    wishButton = SmallButton(frame, "0", 64, 30)
    wishButton:SetPoint("TOPRIGHT")
    wishButton.text:ClearAllPoints()
    wishButton.text:SetPoint("LEFT", wishButton, "CENTER", 0, 0)
    wishButton.text:SetTextColor(unpack(GOLD))
    ns.SetFont(wishButton.text, 13, "", "bold")
    local star = UI.Icon(wishButton, "Star", 14, GOLD)
    star:SetPoint("RIGHT", wishButton, "CENTER", -4, 0)
    wishButton:SetScript("OnClick", function()
        ns.Wishlist.ToggleWindow()
        UpdateHeader()
    end)
    wishButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Wishlist"], 1, 1, 1)
        GameTooltip:Show()
    end)
    wishButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    list = UI.ScrollArea(frame)
    list:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -8)
    list:SetPoint("BOTTOMRIGHT", -8, 0)
    list.child:SetWidth(1)
    list:SetScript("OnSizeChanged", function(self, w) self.child:SetWidth(w) end)

    filterBar = CreateFrame("Frame", nil, list.child)
    filterBar:SetHeight(24)
    filterBar.mine = SmallButton(filterBar, L["For me"], 80, 24)
    filterBar.mine:SetPoint("LEFT")
    filterBar.all = SmallButton(filterBar, L["All"], 60, 24)
    filterBar.all:SetPoint("LEFT", filterBar.mine, "RIGHT", 4, 0)
    local function SetAll(all)
        if ns.char then ns.char.dungeonLootAll = all or nil end
        P.Refresh()
    end
    filterBar.mine:SetScript("OnClick", function() SetAll(false) end)
    filterBar.all:SetScript("OnClick", function() SetAll(true) end)

    note = UI.Text(list.child, 11, "LEFT", UI.MUTED)
    note:SetWordWrap(true)
    note:SetText(L["Drop chances from classic data, Forever can differ. Check mark: seen dropping in Forever."])

    ns.Wishlist.AddListener(function()
        if frame:IsShown() then P.Refresh() end
    end)
    parent:HookScript("OnHide", function() ns.Wishlist.HideWindow() end)
end
