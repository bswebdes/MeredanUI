-- Wishlist: items starred in the dungeon panel (Map/DungeonPanel.lua), per character.
-- Shown in its own window docked right of the world map (star button in the dungeon panel), as a
-- character window tab and as a line in item tooltips. Grouped by dungeon; "Owned" = in bags/bank
-- or equipped.
--
--   ns.char.wishlist[itemID] = { instance = 43, source = encounterID or "rare:<npcID>" }
local _, ns = ...
local L = ns.L
local Char = ns.Char

local W = {}
ns.Wishlist = W

local GOLD = { 0.85, 0.71, 0.42 }
local ROW_BG = { 0.08, 0.094, 0.094, 1 }
local ROW, HEAD, GAP = 40, 24, 4
local listeners = {}

local function List()
    ns.char.wishlist = ns.char.wishlist or {}
    return ns.char.wishlist
end

local function Owned(id) return C_Item.GetItemCount(id, true) > 0 end

function W.Has(itemID) return ns.char ~= nil and itemID ~= nil and List()[itemID] ~= nil end

function W.Count()
    if not ns.char then return 0 end
    local n = 0
    for _ in pairs(List()) do n = n + 1 end
    return n
end

function W.AddListener(fn) listeners[#listeners + 1] = fn end

local function Changed()
    for _, fn in ipairs(listeners) do fn() end
    if Char.window and Char.window:IsShown() and Char.Current() == "wishlist" then Char.Refresh() end
end

function W.Toggle(itemID, instance, source)
    local list = List()
    list[itemID] = not list[itemID] and { instance = instance, source = source } or nil
    PlaySound(list[itemID] and SOUNDKIT.IG_CHARACTER_INFO_TAB or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    Changed()
end

local function BossName(entry)
    if type(entry.source) == "number" then
        for _, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[entry.instance] or {}) do
            if b[1] == entry.source then return GetLocale() == "deDE" and b[3] or b[2] end
        end
    elseif type(entry.source) == "string" then
        local npc = tonumber(entry.source:match("rare:(%d+)"))
        for _, p in ipairs(ns.DUNGEON_PINS and ns.DUNGEON_PINS[entry.instance] or {}) do
            if p.kind == "rare" and p.id == npc then return p.name end
        end
    end
end

local function ZoneName(instance) return GetRealZoneText and GetRealZoneText(instance) or "" end

-- Drop chance from the dungeon loot data (Map/DungeonLoot.lua)
local function Chance(entry, id)
    local loot = ns.DUNGEON_LOOT and ns.DUNGEON_LOOT[entry.instance]
    for _, e in ipairs(loot and loot[entry.source] or {}) do
        if e[1] == id then return e[2] end
    end
end

local function LinkToChat(id)
    local _, link = C_Item.GetItemInfo(id)
    if not link then return end
    local done = ChatFrameUtil and ChatFrameUtil.InsertLink and ChatFrameUtil.InsertLink(link)
    if not done and ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
end

-- Dungeon map with the item's boss chosen in the dungeon panel
local function ShowOnMap(entry)
    if not (entry and ns.OpenDungeonMap) then return end
    ns.OpenDungeonMap(entry.instance)
    C_Timer.After(0, function()
        if ns.DungeonPanel and entry.source then ns.DungeonPanel.Select(entry.source) end
    end)
end

-- "Lord Cobrahn · Wailing Caverns"
function W.SourceText(entry)
    if not entry then return "" end
    local boss, zone = BossName(entry), ZoneName(entry.instance)
    return boss and (boss .. "  ·  " .. zone) or zone
end

-- Shared list view (window and character tab) ----------------------------------------------------

local function NewRow(view)
    local UI = ns.UI
    local row = CreateFrame("Button", nil, view.scroll.child)
    row:SetHeight(ROW)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ROW_BG))
    ns.AddBorder(row)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW - 10, ROW - 10)
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.Text(row, 13, "LEFT")
    ns.SetFont(row.name, 13, "", "bold")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetPoint("RIGHT", -88, 0)
    row.name:SetWordWrap(false)
    row.source = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.source:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
    row.source:SetPoint("RIGHT", -88, 0)
    row.source:SetWordWrap(false)
    -- small buttons right: map, chat link, star (remove)
    local function Small(icon, color, tip, onClick)
        local b = CreateFrame("Button", nil, row)
        b:SetSize(24, 24)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.098, 0.098, 0.11, 1)
        ns.AddBorder(b)
        b.icon = UI.Icon(b, icon, 14, color)
        b.icon:SetPoint("CENTER")
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(tip, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    row.star = Small("Star", GOLD, L["Remove from wishlist"], function() W.Toggle(row.itemID) end)
    row.star:SetPoint("RIGHT", -6, 0)
    row.chat = Small("Copy", UI.TEXT, L["Link in chat"], function() LinkToChat(row.itemID) end)
    row.chat:SetPoint("RIGHT", row.star, "LEFT", -4, 0)
    row.map = Small("Map", UI.TEXT, L["Show on the dungeon map"], function() ShowOnMap(List()[row.itemID]) end)
    row.map:SetPoint("RIGHT", row.chat, "LEFT", -4, 0)
    row.selected = row:CreateTexture(nil, "ARTWORK")
    row.selected:SetPoint("TOPLEFT")
    row.selected:SetPoint("BOTTOMLEFT")
    row.selected:SetWidth(2)
    row.selected:SetColorTexture(unpack(UI.ACCENT))
    row.selected:Hide()
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") then return LinkToChat(self.itemID) end
        if view.OnSelect then view.OnSelect(self.itemID) end
    end)
    return row
end

-- Dungeon heading: name in accent + thin line; click opens that dungeon on the map
local function NewHead(view)
    local UI = ns.UI
    local head = CreateFrame("Button", nil, view.scroll.child)
    head:SetHeight(HEAD)
    head.text = UI.Heading(head, 12, "LEFT")
    head.text:SetPoint("LEFT", 0, 0)
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.12, 0.145, 0.14, 1)
    line:SetHeight(1)
    line:SetPoint("LEFT", head.text, "RIGHT", 8, 0)
    line:SetPoint("RIGHT")
    head:SetScript("OnClick", function(self)
        if ns.OpenDungeonMap and self.instance then ns.OpenDungeonMap(self.instance) end
    end)
    return head
end

local function Populate(view, filter)
    local list = List()
    local groups, order = {}, {}
    for id, entry in pairs(list) do
        local owned = Owned(id)
        if filter == "all" or (filter == "owned") == owned then
            local key = entry.instance or 0
            if not groups[key] then groups[key] = {}; order[#order + 1] = key end
            table.insert(groups[key], id)
        end
    end
    table.sort(order, function(a, b) return ZoneName(a) < ZoneName(b) end)
    for _, r in ipairs(view.rows) do r:Hide() end
    for _, h in ipairs(view.heads) do h:Hide() end
    local y, nRow, nHead = 0, 0, 0
    local width = view.scroll.child:GetWidth()
    for _, key in ipairs(order) do
        nHead = nHead + 1
        local head = view.heads[nHead] or NewHead(view)
        view.heads[nHead] = head
        head.instance = key
        head.text:SetText(ZoneName(key))
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", 0, -y)
        head:SetWidth(width)
        head:Show()
        y = y + HEAD + 2
        table.sort(groups[key])
        for _, id in ipairs(groups[key]) do
            nRow = nRow + 1
            local row = view.rows[nRow] or NewRow(view)
            view.rows[nRow] = row
            row.itemID = id
            row.icon:SetTexture(C_Item.GetItemIconByID(id))
            local boss = BossName(list[id])
            local owned = Owned(id)
            local chance = Chance(list[id], id)
            row.source:SetText((boss or "") .. (chance and ("  ·  " .. chance .. " %") or "")
                .. (owned and ("  ·  |cff8ecbb4" .. L["Owned"] .. "|r") or ""))
            row.selected:SetShown(view.selected == id)
            row:SetAlpha(owned and filter == "all" and 0.55 or 1)
            row.name:SetText("")
            local item = Item:CreateFromItemID(id)
            item:ContinueOnItemLoad(function()
                if row.itemID ~= id then return end
                local color = item:GetItemQualityColor()
                row.name:SetText(item:GetItemName() or "")
                if color then row.name:SetTextColor(color.r, color.g, color.b) end
            end)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetWidth(width)
            row:Show()
            y = y + ROW + GAP
        end
        y = y + 8
    end
    view.scroll.child:SetHeight(math.max(y, 1))
    view.empty:SetShown(nRow == 0)
    view.empty:SetText(next(list) and L["Nothing for this filter."] or L["Nothing on your wishlist yet."])
end

-- Open / Owned / All
local FILTERS = { { "open", "Open" }, { "owned", "Owned" }, { "all", "All" } }

local function FilterButtons(view, parent, width)
    view.filterButtons = {}
    local w = (width - 2 * 6) / 3
    for i, f in ipairs(FILTERS) do
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(w, 26)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.098, 0.098, 0.11, 1)
        b.edges = ns.AddBorder(b)
        b.text = ns.UI.Text(b, 12, "CENTER")
        b.text:SetPoint("CENTER")
        b.text:SetText(L[f[2]])
        b.value = f[1]
        b:SetScript("OnClick", function()
            view.filter = f[1]
            view.Refresh()
        end)
        view.filterButtons[i] = b
    end
    view.StyleFilters = function()
        for _, b in ipairs(view.filterButtons) do
            local on = b.value == view.filter
            for _, e in ipairs(b.edges) do e:SetVertexColor(unpack(on and ns.UI.ACCENT or { 0, 0, 0, 1 })) end
            b.text:SetTextColor(unpack(on and ns.UI.ACCENT or ns.UI.MUTED))
        end
    end
    return view.filterButtons
end

-- Docked window right of the world map -----------------------------------------------------------

local WIN_W, PAD = 330, 16
local win

local function CreateWindow()
    local UI = ns.UI
    local map = _G["MeredanUIWorldMap"]
    win = CreateFrame("Frame", "MeredanUIWishlist", map or UIParent)
    win:SetSize(WIN_W, map and map:GetHeight() or 600)
    win:SetPoint("TOPLEFT", map or UIParent, map and "TOPRIGHT" or "CENTER", 6, 0)
    win:SetFrameStrata("HIGH")
    win:EnableMouse(true)
    win:Hide()
    UI.Box(win, ns.STYLE.panelColor, true)
    ns.RuneFrame(win)

    local star = UI.Icon(win, "Star", 20, GOLD)
    star:SetPoint("TOPLEFT", PAD, -PAD - 2)
    local title = UI.Text(win, 16, "LEFT")
    ns.SetFont(title, 16, "", "bold")
    title:SetPoint("TOPLEFT", star, "TOPRIGHT", 10, 3)
    title:SetText(L["Wishlist"])
    win.sub = UI.Text(win, 12, "LEFT", UI.MUTED)
    win.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    local close = UI.IconButton(win, "Close", function() W.HideWindow() end, 26)
    close:SetPoint("TOPRIGHT", -PAD, -PAD + 2)

    win.view = { rows = {}, heads = {}, filter = "open" }
    local view = win.view
    local buttons = FilterButtons(view, win, WIN_W - 2 * PAD)
    for i, b in ipairs(buttons) do
        if i == 1 then b:SetPoint("TOPLEFT", PAD, -64) else b:SetPoint("LEFT", buttons[i - 1], "RIGHT", 6, 0) end
    end
    view.scroll = UI.ScrollArea(win)
    view.scroll:SetPoint("TOPLEFT", PAD, -102)
    view.scroll:SetPoint("BOTTOMRIGHT", -PAD - 8, 44)
    view.scroll.child:SetWidth(WIN_W - 2 * PAD - 8)
    view.empty = UI.Text(win, 13, "CENTER", UI.MUTED)
    view.empty:SetPoint("CENTER", view.scroll, "CENTER")
    local hint = UI.Text(win, 11, "LEFT", UI.MUTED)
    hint:SetPoint("BOTTOMLEFT", PAD, 14)
    hint:SetPoint("BOTTOMRIGHT", -PAD, 14)
    hint:SetWordWrap(true)
    hint:SetText(L["Click a dungeon to show it on the map."])
    view.Refresh = function()
        view.StyleFilters()
        win.sub:SetText(L["%d items · all dungeons"]:format(W.Count()))
        Populate(view, view.filter)
    end
    win:SetScript("OnShow", view.Refresh)
    win:RegisterEvent("BAG_UPDATE_DELAYED")
    win:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    win:SetScript("OnEvent", function(self) if self:IsShown() then view.Refresh() end end)
    W.AddListener(function() if win:IsShown() then view.Refresh() end end)
end

function W.IsWindowShown() return win ~= nil and win:IsShown() end
function W.HideWindow() if win then win:Hide() end end
function W.ToggleWindow()
    if not win then CreateWindow() end
    win:SetShown(not win:IsShown())
    PlaySound(win:IsShown() and SOUNDKIT.IG_CHARACTER_INFO_OPEN or SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
end

-- Character window tab --------------------------------------------------------------------------

Char.AddTab({
    key = "wishlist", order = 7, tip = L["Wishlist"], icon = "Interface\\Icons\\INV_Misc_Gift_02",
    Create = function(view)
        local UI = ns.UI
        view.rows, view.heads, view.filter = {}, {}, "open"
        local buttons = FilterButtons(view, view, 300)
        for i, b in ipairs(buttons) do
            if i == 1 then b:SetPoint("TOPRIGHT", view, "TOPRIGHT", -2 * (b:GetWidth() + 6), 0)
            else b:SetPoint("LEFT", buttons[i - 1], "RIGHT", 6, 0) end
        end
        -- right: try-on preview of the chosen item + progress; left: the list
        local side = CreateFrame("Frame", nil, view)
        side:SetPoint("TOPRIGHT", 0, -40)
        side:SetPoint("BOTTOMRIGHT")
        UI.Box(side, { 0, 0, 0, 0.25 })
        view.side = side
        local model = CreateFrame("DressUpModel", nil, side)
        model:SetPoint("TOPLEFT", 1, -1)
        model:SetPoint("BOTTOMRIGHT", -1, 70)
        model:SetUnit("player", false)
        model:EnableMouse(true)
        -- drag to turn
        model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
        model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
        model:SetScript("OnUpdate", function(self)
            if not self.dragX then return end
            local x = GetCursorPosition()
            self:SetFacing((self:GetFacing() or 0) + (x - self.dragX) * 0.02)
            self.dragX = x
        end)
        view.model = model
        local hint = UI.Text(side, 12, "CENTER", UI.MUTED)
        hint:SetPoint("BOTTOM", model, "BOTTOM", 0, 10)
        hint:SetText(L["Click an item to try it on"])
        view.hint = hint
        view.progress = UI.Text(side, 12, "LEFT", UI.TEXT)
        view.progress:SetPoint("BOTTOMLEFT", 12, 40)
        local bar = CreateFrame("StatusBar", nil, side)
        bar:SetPoint("BOTTOMLEFT", 12, 18)
        bar:SetPoint("BOTTOMRIGHT", -12, 18)
        bar:SetHeight(10)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetStatusBarColor(unpack(UI.ACCENT))
        local bbg = bar:CreateTexture(nil, "BACKGROUND")
        bbg:SetAllPoints()
        bbg:SetColorTexture(0.12, 0.12, 0.13, 1)
        ns.AddBorder(bar)
        view.bar = bar

        view.scroll = UI.ScrollArea(view)
        view.scroll:SetPoint("TOPLEFT", 0, -40)
        view.scroll:SetPoint("BOTTOMRIGHT", side, "BOTTOMLEFT", -22, 0)
        local function Size(w)
            side:SetWidth(math.floor(w * 0.38))
            view.scroll.child:SetWidth(w - math.floor(w * 0.38) - 22)
        end
        Size(view:GetWidth() > 0 and view:GetWidth() or 900)
        view:SetScript("OnSizeChanged", function(_, w) Size(w) end)
        view.empty = UI.Text(view, 13, "CENTER", UI.MUTED)
        view.empty:SetPoint("CENTER", view.scroll, "CENTER")
        view.OnSelect = function(id)
            view.selected = id
            model:SetUnit("player", false)
            model:TryOn("item:" .. id)
            hint:Hide()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            view.Refresh()
        end
        view.Refresh = function()
            view.StyleFilters()
            Populate(view, view.filter)
            local total, owned = 0, 0
            for id in pairs(List()) do
                total = total + 1
                if Owned(id) then owned = owned + 1 end
            end
            view.progress:SetText(L["%d of %d owned"]:format(owned, total))
            bar:SetMinMaxValues(0, math.max(total, 1))
            bar:SetValue(owned)
        end
    end,
    Refresh = function(view) view.Refresh() end,
    events = { "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED" },
})

-- Tooltip line on wished items -------------------------------------------------------------------

if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        local id = data and data.id
        if not id or (issecretvalue and issecretvalue(id)) or not W.Has(id) then return end
        tooltip:AddLine("|T" .. ns.MEDIA .. "Icons\\Star:12:12:0:0|t " .. L["On your wishlist"] .. "  |cff99978f" .. W.SourceText(List()[id]) .. "|r", 0.56, 0.8, 0.71)
    end)
end
