-- Wishlist: items starred in the dungeon panel (Map/DungeonPanel.lua), per character.
-- Shown as a character window tab and as a line in item tooltips.
--
--   ns.char.wishlist[itemID] = { instance = 43, source = encounterID or "rare:<npcID>" }
local _, ns = ...
local L = ns.L
local Char = ns.Char

local W = {}
ns.Wishlist = W

local function List()
    ns.char.wishlist = ns.char.wishlist or {}
    return ns.char.wishlist
end

function W.Has(itemID) return ns.char ~= nil and List()[itemID] ~= nil end

function W.Toggle(itemID, instance, source)
    local list = List()
    list[itemID] = not list[itemID] and { instance = instance, source = source } or nil
    PlaySound(list[itemID] and SOUNDKIT.IG_CHARACTER_INFO_TAB or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    if W.onChange then W.onChange() end
    if Char.window and Char.window:IsShown() and Char.Current() == "wishlist" then Char.Refresh() end
end

-- "Lord Cobrahn · Wailing Caverns"
function W.SourceText(entry)
    if not entry then return "" end
    local boss
    if type(entry.source) == "number" then
        for _, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[entry.instance] or {}) do
            if b[1] == entry.source then boss = GetLocale() == "deDE" and b[3] or b[2] end
        end
    elseif type(entry.source) == "string" then
        local npc = tonumber(entry.source:match("rare:(%d+)"))
        for _, p in ipairs(ns.DUNGEON_PINS and ns.DUNGEON_PINS[entry.instance] or {}) do
            if p.kind == "rare" and p.id == npc then boss = p.name end
        end
    end
    local zone = GetRealZoneText and GetRealZoneText(entry.instance) or ""
    return boss and (boss .. "  ·  " .. zone) or zone
end

-- Character window tab --------------------------------------------------------------------------

local ROW = 40

local function Row(view, i)
    local row = view.rows[i]
    if row then return row end
    local UI = ns.UI
    row = CreateFrame("Button", nil, view.scroll.child)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * (ROW + 2))
    row:SetPoint("RIGHT", view.scroll.child, "RIGHT")
    UI.Box(row, { 0.08, 0.08, 0.09, 0.9 })
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW - 10, ROW - 10)
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
    row.name:SetPoint("RIGHT", -40, 0)
    row.name:SetWordWrap(false)
    row.source = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.source:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
    row.source:SetPoint("RIGHT", -40, 0)
    row.source:SetWordWrap(false)
    row.star = CreateFrame("Button", nil, row)
    row.star:SetSize(24, 24)
    row.star:SetPoint("RIGHT", -8, 0)
    row.star.icon = UI.Icon(row.star, "Star", 16, UI.ACCENT)
    row.star.icon:SetPoint("CENTER")
    row.star:SetScript("OnClick", function() W.Toggle(row.itemID) end)
    row.star:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["Remove from wishlist"], 1, 1, 1)
        GameTooltip:Show()
    end)
    row.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
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
    view.rows[i] = row
    return row
end

local function Refresh(view)
    local ids = {}
    for id in pairs(List()) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, row in ipairs(view.rows) do row:Hide() end
    for i, id in ipairs(ids) do
        local row = Row(view, i)
        row.itemID = id
        row.icon:SetTexture(C_Item.GetItemIconByID(id))
        row.source:SetText(W.SourceText(List()[id]))
        local item = Item:CreateFromItemID(id)
        item:ContinueOnItemLoad(function()
            if row.itemID ~= id then return end
            local color = item:GetItemQualityColor()
            row.name:SetText(item:GetItemName() or "")
            if color then row.name:SetTextColor(color.r, color.g, color.b) end
        end)
        row:Show()
    end
    view.scroll.child:SetHeight(math.max(#ids * (ROW + 2), 1))
    view.empty:SetShown(#ids == 0)
end

Char.AddTab({
    key = "wishlist", order = 7, tip = L["Wishlist"], icon = "Interface\\Icons\\INV_Misc_Note_05",
    Create = function(view)
        local UI = ns.UI
        view.rows = {}
        view.title = UI.Text(view, 14, "LEFT")
        ns.SetFont(view.title, 14, "", "bold")
        view.title:SetPoint("TOPLEFT", 4, -4)
        view.title:SetText(L["Wishlist"])
        view.hint = UI.Text(view, 12, "LEFT", UI.MUTED)
        view.hint:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -4)
        view.hint:SetText(L["Star loot in a dungeon map to keep it here."])
        view.scroll = UI.ScrollArea(view)
        view.scroll:SetPoint("TOPLEFT", 0, -50)
        view.scroll:SetPoint("BOTTOMRIGHT", -12, 0)
        view.scroll.child:SetWidth(view:GetWidth() > 0 and view:GetWidth() - 12 or 600)
        view:SetScript("OnSizeChanged", function(self, w) self.scroll.child:SetWidth(w - 12) end)
        view.empty = UI.Text(view, 13, "CENTER", UI.MUTED)
        view.empty:SetPoint("CENTER")
        view.empty:SetText(L["Nothing on your wishlist yet."])
    end,
    Refresh = Refresh,
    events = { "GET_ITEM_INFO_RECEIVED" },
})

-- Tooltip line on wished items -------------------------------------------------------------------

if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local id = data and data.id
        if not id or (issecretvalue and issecretvalue(id)) or not W.Has(id) then return end
        local entry = List()[id]
        tooltip:AddLine("|T" .. ns.MEDIA .. "Icons\\Star:12:12:0:0|t " .. L["On your wishlist"] .. "  |cff99978f" .. W.SourceText(entry) .. "|r", 0.56, 0.8, 0.71)
    end)
end
