-- Boss panel in the world map's right column while a dungeon map is shown (instead of the quest log):
-- boss list in map pin order, click a boss (in the list or its pin on the map) for its loot, filter
-- by armour type, star items for the wishlist (Character/Wishlist.lua).
--
--   +- right column -------------------------+
--   | Bosses              [All armour v]     |   list: number, name, loot count
--   | (1) Lady Anacondra               3 >   |
--   | ...                                    |
--   +----------------------------------------+
--   | [<] Lady Anacondra                      |   detail: loot rows with star
--   | [icon] Belt of the Fang   Leather Waist * |
--   | Loot from AtlasLoot data, not confirmed |
local _, ns = ...
local L = ns.L

local P = {}
ns.DungeonPanel = P

local ROW, LOOT_ROW = 32, 40
local frame, list, title, back, filterButton, note
local rows, lootRows = {}, {}
local selected -- encounter ID or "rare:<npcID>"
local shownInstance
local filter = "all"

-- Armour filter: Item class 4 (armour) subclasses; weapons and the rest have their own entries
local FILTERS = {
    { value = "all", label = "All loot" },
    { value = 1 }, { value = 2 }, { value = 3 }, { value = 4 }, -- labels from the client (GetItemSubClassInfo)
    { value = "weapon", label = "Weapons & shields" },
    { value = "other", label = "Other" },
}

local function FilterLabel(f)
    if f.label then return L[f.label] end
    return C_Item.GetItemSubClassInfo(Enum.ItemClass.Armor, f.value) or tostring(f.value)
end

local function Matches(itemID)
    if filter == "all" then return true end
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    local armour = classID == Enum.ItemClass.Armor
    if filter == "weapon" then return classID == Enum.ItemClass.Weapon or (armour and subclassID == 6) end
    if filter == "other" then return not armour and classID ~= Enum.ItemClass.Weapon or (armour and (subclassID == 0 or equipLoc == "INVTYPE_CLOAK")) end
    return armour and subclassID == filter and equipLoc ~= "INVTYPE_CLOAK"
end

-- Bosses of the instance in pin/number order, plus rares that have loot
local function Sources(instance)
    local out = {}
    local loot = ns.DUNGEON_LOOT[instance] or {}
    for i, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[instance] or {}) do
        out[#out + 1] = { key = b[1], number = i, name = GetLocale() == "deDE" and b[3] or b[2], items = loot[b[1]] or {} }
    end
    for _, p in ipairs(ns.DUNGEON_PINS and ns.DUNGEON_PINS[instance] or {}) do
        local key = "rare:" .. p.id
        if p.kind == "rare" and loot[key] then out[#out + 1] = { key = key, rare = true, name = p.name, items = loot[key] } end
    end
    return out
end

local function SourceByKey(instance, key)
    for _, s in ipairs(Sources(instance)) do if s.key == key then return s end end
end

local function NumberMark(row, s)
    if s.rare then
        row.mark:SetText("|T" .. ns.MEDIA .. "Icons\\Star:11:11:0:0|t")
    else
        row.mark:SetText(s.number)
    end
end

local function BossRow(i)
    local row = rows[i]
    if row then return row end
    local UI = ns.UI
    row = CreateFrame("Button", nil, list.child)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW + 2))
    row:SetPoint("RIGHT", list.child, "RIGHT")
    UI.Box(row, { 0.08, 0.08, 0.09, 0.9 })
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    row.diamond = UI.Icon(row, "Diamond", 22, { 0.85, 0.71, 0.42 })
    row.diamond:SetPoint("LEFT", 6, 0)
    row.mark = UI.Text(row, 11, "CENTER", { 0.07, 0.07, 0.07 })
    ns.SetFont(row.mark, 11, "", "bold")
    row.mark:SetPoint("CENTER", row.diamond, "CENTER", 0, 0)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("LEFT", row.diamond, "RIGHT", 10, 0)
    row.name:SetPoint("RIGHT", -60, 0)
    row.name:SetWordWrap(false)
    row.count = UI.Text(row, 12, "RIGHT", UI.MUTED)
    row.count:SetPoint("RIGHT", -26, 0)
    row.chevron = UI.Icon(row, "ChevronDown", 10, UI.MUTED)
    row.chevron:SetRotation(math.pi / 2)
    row.chevron:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnClick", function(self) P.Select(self.key) end)
    rows[i] = row
    return row
end

local function LootRow(i)
    local row = lootRows[i]
    if row then return row end
    local UI = ns.UI
    row = CreateFrame("Button", nil, list.child)
    row:SetHeight(LOOT_ROW)
    row:SetPoint("RIGHT", list.child, "RIGHT")
    UI.Box(row, { 0.08, 0.08, 0.09, 0.9 })
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(LOOT_ROW - 10, LOOT_ROW - 10)
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
    row.name:SetPoint("RIGHT", -38, 0)
    row.name:SetWordWrap(false)
    row.kind = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.kind:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
    row.kind:SetPoint("RIGHT", -38, 0)
    row.kind:SetWordWrap(false)
    row.star = CreateFrame("Button", nil, row)
    row.star:SetSize(26, 26)
    row.star:SetPoint("RIGHT", -6, 0)
    row.star.icon = UI.Icon(row.star, "Star", 16, UI.MUTED)
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

-- "Leather · Waist" from the instant item data (no server round trip)
local function KindText(itemID)
    local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(itemID)
    local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
    if slot and subType and subType ~= "" then return subType .. "  ·  " .. slot end
    return slot or subType or ""
end

local function ShowList(instance)
    for _, r in ipairs(lootRows) do r:Hide() end
    back:Hide()
    title:ClearAllPoints()
    title:SetPoint("LEFT", frame.header, "LEFT", 2, 0)
    title:SetText(L["Bosses"])
    local sources = Sources(instance)
    for _, r in ipairs(rows) do r:Hide() end
    for i, s in ipairs(sources) do
        local row = BossRow(i)
        row.key = s.key
        NumberMark(row, s)
        row.diamond:SetVertexColor(unpack(s.rare and { 0.8, 0.82, 0.86 } or { 0.85, 0.71, 0.42 }))
        row.name:SetText(s.name or "")
        local n = 0
        for _, id in ipairs(s.items) do if Matches(id) then n = n + 1 end end
        row.count:SetText(#s.items > 0 and n or "–")
        row:Show()
    end
    list.child:SetHeight(math.max(#sources * (ROW + 2), 1))
    note:Hide()
end

local function ShowLoot(s)
    for _, r in ipairs(rows) do r:Hide() end
    back:Show()
    title:ClearAllPoints()
    title:SetPoint("LEFT", back, "RIGHT", 8, 0)
    title:SetText(s.name or "")
    for _, r in ipairs(lootRows) do r:Hide() end
    local n, y = 0, 0
    for _, id in ipairs(s.items) do
        if Matches(id) then
            n = n + 1
            local row = LootRow(n)
            row.itemID = id
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", list.child, "RIGHT")
            row.icon:SetTexture(C_Item.GetItemIconByID(id))
            row.kind:SetText(KindText(id))
            row.name:SetText("")
            local wished = ns.Wishlist.Has(id)
            row.star.icon:SetVertexColor(unpack(wished and ns.UI.ACCENT or ns.UI.MUTED))
            row.star.icon:SetAlpha(wished and 1 or 0.55)
            local item = Item:CreateFromItemID(id)
            item:ContinueOnItemLoad(function()
                if row.itemID ~= id then return end
                row.name:SetText(item:GetItemName() or "")
                local color = item:GetItemQualityColor()
                if color then row.name:SetTextColor(color.r, color.g, color.b) end
            end)
            row:Show()
            y = y + LOOT_ROW + 2
        end
    end
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", list.child, "TOPLEFT", 2, -(y + 8))
    note:SetPoint("RIGHT", list.child, "RIGHT", -2, 0)
    note:SetText(n == 0 and L["Nothing for this filter."] or L["Loot from AtlasLoot data, not confirmed in Forever yet."])
    note:Show()
    list.child:SetHeight(y + 40)
end

function P.Refresh()
    local view = ns.DungeonMapView
    local instance = view and view.IsShown() and view.instance
    local active = frame and instance and ns.DUNGEON_LOOT[instance] ~= nil
    if not frame then return end
    frame:SetShown(active and true or false)
    if not active then return end
    if instance ~= shownInstance then selected, shownInstance = nil, instance end
    local s = selected and SourceByKey(instance, selected)
    if s then ShowLoot(s) else selected = nil ShowList(instance) end
    local label
    for _, f in ipairs(FILTERS) do if f.value == filter then label = FilterLabel(f) end end
    filterButton.text:SetText(label or "")
end

-- Called by a boss pin click (Map/DungeonPins.lua) or a list row
function P.Select(key)
    selected = key
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    P.Refresh()
end

-- Build over the quest log column: anchors = top-left and bottom-right frames of that column
function P.Attach(parent, topLeft, bottomRight)
    local UI = ns.UI
    frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", topLeft, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMRIGHT", 8, 0)
    frame:SetFrameLevel(parent:GetFrameLevel() + 50)
    frame:EnableMouse(true)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    frame:Hide()

    frame.header = CreateFrame("Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT")
    frame.header:SetPoint("TOPRIGHT")
    frame.header:SetHeight(30)
    back = UI.IconButton(frame.header, "ChevronDown", function()
        selected = nil
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        P.Refresh()
    end, 26)
    back.icon:SetRotation(-math.pi / 2)
    back:SetPoint("LEFT")
    title = UI.Text(frame.header, 15, "LEFT")
    ns.SetFont(title, 15, "", "bold")
    title:SetPoint("RIGHT", frame.header, "RIGHT", -140, 0)
    title:SetWordWrap(false)

    filterButton = CreateFrame("Button", nil, frame.header)
    filterButton:SetSize(130, 26)
    filterButton:SetPoint("RIGHT")
    UI.Box(filterButton, { 0.06, 0.06, 0.06, 0.88 })
    ns.AddBorder(filterButton)
    filterButton.text = UI.Text(filterButton, 12, "LEFT")
    filterButton.text:SetPoint("LEFT", 8, 0)
    filterButton.text:SetPoint("RIGHT", -22, 0)
    filterButton.text:SetWordWrap(false)
    local chevron = UI.Icon(filterButton, "ChevronDown", 10, UI.MUTED)
    chevron:SetPoint("RIGHT", -8, 0)
    filterButton:SetScript("OnClick", function(self)
        local items = {}
        for i, f in ipairs(FILTERS) do items[i] = { value = f.value, label = FilterLabel(f) } end
        UI.OpenList(self, items, filter, function(value)
            filter = value
            P.Refresh()
        end)
    end)

    list = UI.ScrollArea(frame)
    list:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -10)
    list:SetPoint("BOTTOMRIGHT", -8, 0)
    list.child:SetWidth(1)
    list:SetScript("OnSizeChanged", function(self, w) self.child:SetWidth(w) end)
    note = UI.Text(list.child, 11, "LEFT", UI.MUTED)
    note:SetWordWrap(true)

    ns.Wishlist.onChange = function() if frame:IsShown() then P.Refresh() end end
end
