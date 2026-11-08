-- Auktionshaus (WoW Forever) statt Blizzards AuctionHouseFrame – Entwurf „Auktionshaus“ (Benny
-- 2026-11-07). Ein Fenster in der NPC-Familie, Tabs rechts: Kaufen · Verkaufen · Meine Auktionen ·
-- Verlauf. Diese Datei: Fenster, Öffnen/Schließen, gemeinsame Bausteine und Kaufen (Suche,
-- Einzelstück, Massenware). Verkaufen, Meine Auktionen und Verlauf stehen in eigenen Dateien.
--
-- Technik: Blizzards Fenster wird beim Laden unsichtbar geparkt (vor dem ersten Zeigen, damit sein
-- OnShow/OnHide nie läuft – OnHide würde das Auktionshaus schließen). Kaufen, Bieten, Abbrechen
-- laufen über Blizzards eigene Bestätigungsdialoge (BUYOUT_AUCTION, BID_AUCTION, CANCEL_AUCTION).
local _, ns = ...
local L = ns.L

local AH = {}
ns.AH = AH

local WIDTH = 960
local PAD = ns.NPC_PAD
local TOP = ns.NPC_HEADER_BOTTOM + 14
local BOTTOM = 54
local TAB_SIZE, TAB_STEP = 40, 46
local ROW_H = 30
local CAT_W = 180

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, footerText, goldText
local tabs, views = {}, {}
AH.current = "buy"

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.auctionWindow ~= false and C_AuctionHouse ~= nil
end
AH.Enabled = Enabled

-- Symbole im Text: die mUI-Schrift hat kein ▾/✓/★ – stattdessen kleine Grafiken
function AH.IconMarkup(name, size, color)
    local c = color or ns.UI.TEXT
    return ("|T%sIcons\\%s:%d:%d:0:0:16:16:0:16:0:16:%d:%d:%d|t"):format(ns.MEDIA, name, size, size,
        c[1] * 255, c[2] * 255, c[3] * 255)
end
local function Chevron() return AH.IconMarkup("ChevronDown", 12) end
local function Tick() return AH.IconMarkup("Check", 12, ns.UI.ACCENT) end

-- Bausteine -------------------------------------------------------------------------------------

function AH.Money(copper)
    if not copper or copper <= 0 then return "–" end
    return GetMoneyString(copper, true)
end

function AH.QualityColor(quality)
    local r, g, b = C_Item.GetItemQualityColor(quality or 1)
    return r or 1, g or 1, b or 1
end

-- Geldeingabe: Gold, Silber, Kupfer (Kupfer nur, wenn das Auktionshaus Kupfer kennt)
function AH.MoneyInput(parent, onChange)
    local UI = ns.UI
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(200, 30)
    local boxes = {}
    local specs = { { "g", { 0.9, 0.76, 0.35 }, 70, 7 }, { "s", { 0.78, 0.8, 0.84 }, 46, 2 }, { "k", { 0.82, 0.54, 0.33 }, 46, 2 } }
    local x = 0
    for i, spec in ipairs(specs) do
        local box = UI.EditBox(frame, 30)
        box:SetWidth(spec[3])
        box:SetPoint("LEFT", x, 0)
        box:SetNumeric(true)
        box:SetMaxLetters(spec[4])
        box:SetTextInsets(8, 18, 0, 0)
        local unit = UI.Text(box, 12, "RIGHT", spec[2])
        unit:SetPoint("RIGHT", -6, 0)
        unit:SetText(spec[1])
        box:SetScript("OnTextChanged", function(_, user) if user and onChange then onChange(frame:GetValue()) end end)
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box:SetScript("OnTabPressed", function() local nextBox = boxes[i % 3 + 1] if nextBox:IsShown() then nextBox:SetFocus() end end)
        boxes[i] = box
        x = x + spec[3] + 4
    end
    frame.boxes = boxes
    function frame:GetValue()
        local g = tonumber(boxes[1]:GetText()) or 0
        local s = tonumber(boxes[2]:GetText()) or 0
        local k = boxes[3]:IsShown() and (tonumber(boxes[3]:GetText()) or 0) or 0
        return g * 10000 + s * 100 + k
    end
    function frame:SetValue(copper)
        copper = math.max(math.floor(copper or 0), 0)
        boxes[1]:SetText(tostring(math.floor(copper / 10000)))
        boxes[2]:SetText(tostring(math.floor(copper / 100) % 100))
        boxes[3]:SetText(tostring(copper % 100))
    end
    function frame:SetCopperShown(on)
        boxes[3]:SetShown(on)
        self:SetWidth(on and 170 or 120)
    end
    frame:SetCopperShown(true)
    return frame
end

-- Kupfer erlaubt? Sonst auf Silber runden (wie Blizzards SanitizeAuctionHousePrice)
function AH.Sanitize(copper)
    if C_AuctionHouse.SupportsCopperValues and C_AuctionHouse.SupportsCopperValues() then return copper end
    return math.ceil((copper or 0) / 100) * 100
end

function AH.Step()
    return (C_AuctionHouse.SupportsCopperValues and C_AuctionHouse.SupportsCopperValues()) and 1 or 100
end

-- Name, Symbol und Qualität eines ItemKeys (kann erst nach ITEM_KEY_ITEM_INFO_RECEIVED da sein)
function AH.KeyInfo(itemKey)
    return itemKey and C_AuctionHouse.GetItemKeyInfo(itemKey)
end

function AH.TimeLeftText(band)
    local E = Enum.AuctionHouseTimeLeftBand
    if band == E.Short then return "|cffe65050" .. (TIME_LEFT_SHORT or "Kurz") .. "|r" end
    if band == E.Medium then return TIME_LEFT_MEDIUM or "Mittel" end
    if band == E.Long then return TIME_LEFT_LONG or "Lang" end
    if band == E.VeryLong then return TIME_LEFT_VERY_LONG or "Sehr lang" end
    return ""
end

function AH.IsOwn(owners)
    for _, owner in ipairs(owners or {}) do
        if owner == "player" then return true end
    end
    return false
end

-- Spalten setzen: feste Spalten links vom flexiblen von links, rechts davon von rechts; die eine
-- Spalte ohne Breite nimmt den Rest (darf auch in der Mitte stehen).
local function PlaceColumns(frame, columns, place)
    local flex
    for i, column in ipairs(columns) do if not column.width then flex = i break end end
    flex = flex or #columns + 1
    local x = 10
    for i = 1, math.min(flex - 1, #columns) do
        place(i, "LEFT", x, columns[i].width)
        x = x + columns[i].width
    end
    local right = 10
    for i = #columns, flex + 1, -1 do
        place(i, "RIGHT", -right, columns[i].width)
        right = right + columns[i].width
    end
    if columns[flex] then place(flex, "FLEX", x, nil, right) end
end
AH.PlaceColumns = PlaceColumns

-- Tabellenkopf mit Spalten { title, width (nil = Rest), align }
function AH.Header(parent, columns)
    local UI = ns.UI
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(26)
    UI.Box(header, { 0.098, 0.098, 0.106, 1 })
    PlaceColumns(header, columns, function(i, side, x, width, right)
        local column = columns[i]
        local text = UI.Text(header, 12, column.align or "LEFT", UI.MUTED)
        if side == "FLEX" then
            text:SetPoint("LEFT", x, 0)
            text:SetPoint("RIGHT", -right - 8, 0)
        elseif side == "LEFT" then
            text:SetPoint("LEFT", x, 0)
            text:SetWidth(width - 8)
        else
            text:SetPoint("RIGHT", x, 0)
            text:SetWidth(width - 8)
        end
        text:SetText(column.title)
    end)
    return header
end

-- Zeile mit Zellen passend zu AH.Header; row.cells[i] (Text), optional Symbol in Zelle 1
function AH.Row(parent, columns, withIcon)
    local UI = ns.UI
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0, 0, 0, 0)
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.strip:SetColorTexture(unpack(UI.ACCENT))
    row.strip:Hide()
    row.cells = {}
    PlaceColumns(row, columns, function(i, side, x, width, right)
        local column = columns[i]
        local offset = 0
        if i == 1 and withIcon then
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(22, 22)
            row.icon:SetPoint("LEFT", x, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            offset = 28
        end
        local text = UI.Text(row, 13, column.align or "LEFT")
        text:SetWordWrap(false)
        if side == "FLEX" then
            text:SetPoint("LEFT", x + offset, 0)
            text:SetPoint("RIGHT", -right - 8, 0)
        elseif side == "LEFT" then
            text:SetPoint("LEFT", x + offset, 0)
            text:SetWidth(width - 8 - offset)
        else
            text:SetPoint("RIGHT", x, 0)
            text:SetWidth(width - 8)
        end
        row.cells[i] = text
    end)
    row:SetScript("OnEnter", function(self)
        if not self.selected then self.bg:SetColorTexture(1, 1, 1, 0.04) end
        if self.OnHover then self:OnHover() end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.selected then self.bg:SetColorTexture(0, 0, 0, 0) end
        GameTooltip:Hide()
    end)
    function row:SetSelected(on)
        self.selected = on
        self.strip:SetShown(on)
        self.bg:SetColorTexture(unpack(on and { 0.122, 0.141, 0.133, 1 } or { 0, 0, 0, 0 }))
    end
    return row
end

-- Liste aus Zeilen in einer ScrollArea; fill(row, data, i) füllt eine Zeile
function AH.List(parent, columns, withIcon)
    local UI = ns.UI
    local list = { rows = {} }
    list.header = AH.Header(parent, columns)
    list.area = UI.ScrollArea(parent)
    list.area:SetPoint("TOPLEFT", list.header, "BOTTOMLEFT", 0, -2)
    function list:Fill(items, fill)
        local width = self.area:GetWidth()
        for i, item in ipairs(items) do
            local row = self.rows[i]
            if not row then
                row = AH.Row(self.area.child, columns, withIcon)
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetWidth(width)
            row.data = item
            fill(row, item, i)
            row:Show()
        end
        for i = #items + 1, #self.rows do self.rows[i]:Hide() end
        self.area.child:SetWidth(width)
        self.area:SetContentHeight(#items * ROW_H)
    end
    return list
end

function AH.Panel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    ns.UI.Box(panel, { 0.078, 0.078, 0.086, 1 })
    return panel
end

-- Symbolknopf „Aktualisieren“
function AH.RefreshButton(parent, onClick)
    local UI = ns.UI
    local button = UI.IconButton(parent, "Reset", onClick, 28)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(REFRESH or L["Refresh"], 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

function AH.SetFooter(text) if footerText then footerText:SetText(text or "") end end

-- Kaufen: Kategorien --------------------------------------------------------------------------------

local buy = { catRows = {}, results = {}, mode = "browse" }
AH.buy = buy

local function CategoryPath()
    local a, b, c = buy.cat1, buy.cat2, buy.cat3
    local categories = AuctionCategories or {}
    local node = a and categories[a]
    if node and b then node = node.subCategories and node.subCategories[b] end
    if node and c then node = node.subCategories and node.subCategories[c] end
    return node
end

local function VisibleCategories()
    local list = {}
    list[#list + 1] = { label = CreateAtlasMarkup("auctionhouse-icon-favorite", 14, 13) .. " " .. (FAVORITES or L["Favorites"]), favorites = true, depth = 0 }
    for i, cat in ipairs(AuctionCategories or {}) do
        if not (cat.flags and cat.flags.WOW_TOKEN_FLAG) then
            list[#list + 1] = { label = cat.name, depth = 0, path = { i }, open = buy.cat1 == i }
            if buy.cat1 == i then
                for j, sub in ipairs(cat.subCategories or {}) do
                    list[#list + 1] = { label = sub.name, depth = 1, path = { i, j }, open = buy.cat2 == j }
                    if buy.cat2 == j then
                        for k, sub2 in ipairs(sub.subCategories or {}) do
                            list[#list + 1] = { label = sub2.name, depth = 2, path = { i, j, k }, open = buy.cat3 == k }
                        end
                    end
                end
            end
        end
    end
    return list
end

local function CatRow(i)
    if buy.catRows[i] then return buy.catRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, buy.catArea.child)
    row:SetHeight(26)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.strip:SetColorTexture(unpack(UI.ACCENT))
    row.text = UI.Text(row, 13, "LEFT")
    row.text:SetPoint("RIGHT", -6, 0)
    row.text:SetWordWrap(false)
    row:SetScript("OnEnter", function(self) if not self.active then self.bg:SetColorTexture(1, 1, 1, 0.04) end end)
    row:SetScript("OnLeave", function(self) if not self.active then self.bg:SetColorTexture(0, 0, 0, 0) end end)
    row:SetScript("OnClick", function(self)
        local entry = self.entry
        if entry.favorites then
            buy.cat1, buy.cat2, buy.cat3, buy.favorites = nil, nil, nil, true
        else
            local p = entry.path
            local same = buy.cat1 == p[1] and buy.cat2 == p[2] and buy.cat3 == p[3]
            buy.favorites = false
            if same and #p == 1 then
                buy.cat1, buy.cat2, buy.cat3 = nil, nil, nil -- zuklappen
            else
                buy.cat1, buy.cat2, buy.cat3 = p[1], p[2], p[3]
            end
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        AH.Search()
    end)
    buy.catRows[i] = row
    return row
end

local function LayoutCategories()
    local UI = ns.UI
    local list = VisibleCategories()
    local width = buy.catArea:GetWidth()
    for i, entry in ipairs(list) do
        local row = CatRow(i)
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
        row:SetWidth(width)
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", 10 + entry.depth * 12, 0)
        row.text:SetPoint("RIGHT", -6, 0)
        local p = entry.path
        local active = entry.favorites and buy.favorites
            or (p and not buy.favorites and buy.cat1 == p[1] and buy.cat2 == p[2] and buy.cat3 == p[3])
        row.active = active and true or false
        row.text:SetText((entry.depth == 2 and "› " or "") .. (entry.label or ""))
        row.text:SetTextColor(unpack(active and UI.ACCENT or (entry.open and UI.TEXT or (entry.depth > 0 and UI.MUTED or UI.TEXT))))
        row.bg:SetColorTexture(unpack(active and { 0.122, 0.141, 0.133, 1 } or { 0, 0, 0, 0 }))
        row.strip:SetShown(active and true or false)
        row:Show()
    end
    for i = #list + 1, #buy.catRows do buy.catRows[i]:Hide() end
    buy.catArea.child:SetWidth(width)
    buy.catArea:SetContentHeight(#list * 26)
end

-- Kaufen: Suche und Ergebnisse ----------------------------------------------------------------------

local SORT = { { sortOrder = 0, reverseSort = false }, { sortOrder = 1, reverseSort = false } } -- Preis, Name

local function DefaultFilters()
    local list = {}
    local E = Enum.AuctionHouseFilter
    for _, key in ipairs({ "PoorQuality", "CommonQuality", "UncommonQuality", "RareQuality", "EpicQuality", "LegendaryQuality" }) do
        if E[key] and not (buy.hideQuality and buy.hideQuality[key]) then list[#list + 1] = E[key] end
    end
    if buy.usableOnly and E.UsableOnly then list[#list + 1] = E.UsableOnly end
    if buy.uncollectedOnly and E.UncollectedOnly then list[#list + 1] = E.UncollectedOnly end
    return list
end

function AH.Search()
    if not window or not window:IsShown() then return end
    buy.mode = "browse"
    buy.results = {}
    AH.ShowBuyMode()
    LayoutCategories()
    if buy.favorites then
        C_AuctionHouse.SearchForFavorites(SORT)
        AH.SetFooter(L["Loading …"])
        return
    end
    local text = strtrim(buy.search:GetText() or "")
    local node = CategoryPath()
    if text == "" and not node then
        AH.RefreshResults()
        return
    end
    local filters = DefaultFilters()
    if node and node.implicitFilter then filters[#filters + 1] = node.implicitFilter end
    C_AuctionHouse.SendBrowseQuery({
        searchString = text,
        sorts = SORT,
        filters = filters,
        itemClassFilters = node and node.filters or nil,
        minLevel = buy.minLevel or 0,
        maxLevel = buy.maxLevel or 0,
    })
    AH.SetFooter(L["Searching …"])
    if text ~= "" then
        local recent = ns.root.ahRecent or {}
        for i = #recent, 1, -1 do if recent[i] == text then table.remove(recent, i) end end
        table.insert(recent, 1, text)
        while #recent > 6 do table.remove(recent) end
        ns.root.ahRecent = recent
    end
end

local RESULT_COLUMNS
local function ResultColumns()
    RESULT_COLUMNS = RESULT_COLUMNS or {
        { title = L["Item"] },
        { title = L["Level"], width = 60 },
        { title = L["Available"], width = 90 },
        { title = L["From price"], width = 150, align = "RIGHT" },
    }
    return RESULT_COLUMNS
end

function AH.RefreshResults()
    if buy.mode ~= "browse" or not buy.list then return end
    local UI = ns.UI
    local results = buy.results
    buy.list:Fill(results, function(row, result)
        local info = AH.KeyInfo(result.itemKey)
        if info then
            row.icon:SetTexture(info.iconFileID)
            row.cells[1]:SetText(info.itemName or "")
            row.cells[1]:SetTextColor(AH.QualityColor(info.quality))
        else
            row.icon:SetTexture(134400)
            row.cells[1]:SetText("…")
            row.cells[1]:SetTextColor(unpack(UI.MUTED))
        end
        local level = C_AuctionHouse.GetItemKeyRequiredLevel and C_AuctionHouse.GetItemKeyRequiredLevel(result.itemKey)
        row.cells[2]:SetText(level and level > 1 and level or "")
        row.cells[3]:SetText(result.totalQuantity or "")
        row.cells[4]:SetText(AH.Money(result.minPrice))
        row:SetSelected(false)
        row.OnHover = function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemKey(result.itemKey.itemID, result.itemKey.itemLevel, result.itemKey.itemSuffix)
            GameTooltip:Show()
        end
        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                local favorite = C_AuctionHouse.IsFavoriteItem(result.itemKey)
                if C_AuctionHouse.FavoritesAreAvailable() and (favorite or not C_AuctionHouse.HasMaxFavorites()) then
                    C_AuctionHouse.SetFavoriteItem(result.itemKey, not favorite)
                end
                return
            end
            if IsModifiedClick("CHATLINK") then
                local _, link = C_Item.GetItemInfo(result.itemKey.itemID)
                if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
                return
            end
            AH.OpenItem(result.itemKey, info and info.isCommodity, result.minPrice)
        end)
    end)
    local count = #results
    buy.empty:SetShown(count == 0)
    buy.more:SetShown(count > 0 and not C_AuctionHouse.HasFullBrowseResults())
    AH.SetFooter(count > 0 and L["%d items found"]:format(count)
        or L["Right-click an item: favorite"])
end

-- Kaufen: Einzelstück -------------------------------------------------------------------------------

local item = {}
buy.item = item

local function ItemColumns()
    return {
        { title = AUCTION_HOUSE_BROWSE_HEADER_BID or L["Current bid"], width = 170 },
        { title = AUCTION_HOUSE_BROWSE_HEADER_BUYOUT or L["Buyout"], width = 170 },
        { title = L["Time left"], width = 120 },
        { title = "" },
    }
end

function AH.RefreshItem()
    if buy.mode ~= "item" or not buy.itemKey then return end
    local key = buy.itemKey
    local rows = {}
    for i = 1, C_AuctionHouse.GetNumItemSearchResults(key) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(key, i)
        if result then rows[#rows + 1] = result end
    end
    if not buy.selectedAuction and rows[1] then buy.selectedAuction = rows[1].auctionID end
    local selected
    item.list:Fill(rows, function(row, result)
        local own = AH.IsOwn(result.owners)
        row.cells[1]:SetText(result.bidAmount and AH.Money(result.bidAmount) or (result.minBid and ("|cff99978f" .. AH.Money(result.minBid) .. "|r") or "|cff99978f–|r"))
        row.cells[2]:SetText(result.buyoutAmount and AH.Money(result.buyoutAmount) or "|cff99978f–|r")
        row.cells[3]:SetText(AH.TimeLeftText(result.timeLeft))
        row.cells[4]:SetText(own and ("|cff8ecbb4" .. L["You"] .. "|r") or "")
        local isSelected = result.auctionID == buy.selectedAuction
        row:SetSelected(isSelected)
        if isSelected then selected = result end
        row.OnHover = function(self)
            if not result.itemLink then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(result.itemLink)
            GameTooltip:Show()
        end
        row:SetScript("OnClick", function()
            buy.selectedAuction = result.auctionID
            buy.bidTouched = false
            AH.RefreshItem()
        end)
    end)
    item.count:SetText(L["%d available"]:format(#rows))
    item.empty:SetShown(#rows == 0)
    -- unten: Gebot und Sofortkauf
    item.selected = selected
    local canBid = selected and not AH.IsOwn(selected.owners) and selected.minBid ~= nil
    local canBuy = selected and not AH.IsOwn(selected.owners) and selected.buyoutAmount ~= nil
    if selected and not buy.bidTouched then item.bid:SetValue(selected.minBid or 0) end
    item.bidButton:SetEnabled(canBid and true or false)
    item.bidButton:SetAlpha(canBid and 1 or 0.45)
    item.buyButton:SetEnabled(canBuy and true or false)
    item.buyButton:SetAlpha(canBuy and 1 or 0.45)
    item.buyButton.Text:SetText((BUYOUT or L["Buyout"]) .. (canBuy and ("  ·  " .. AH.Money(selected.buyoutAmount)) or ""))
end

function AH.OpenItem(itemKey, isCommodity, minPrice)
    buy.itemKey = itemKey
    buy.selectedAuction = nil
    buy.bidTouched = false
    buy.mode = isCommodity and "commodity" or "item"
    local info = AH.KeyInfo(itemKey)
    local target = isCommodity and buy.commodity or item
    target.icon:SetTexture(info and info.iconFileID or 134400)
    target.name:SetText(info and info.itemName or "")
    target.name:SetTextColor(AH.QualityColor(info and info.quality))
    local level = C_AuctionHouse.GetItemKeyRequiredLevel and C_AuctionHouse.GetItemKeyRequiredLevel(itemKey)
    target.sub:SetText(level and level > 1 and L["Level %d"]:format(level) or "")
    target.star:SetFavorite(C_AuctionHouse.IsFavoriteItem(itemKey))
    if isCommodity then
        buy.commodity.quantity:SetText("1")
    end
    AH.ShowBuyMode()
    C_AuctionHouse.SendSearchQuery(itemKey, { { sortOrder = 4, reverseSort = false }, { sortOrder = 3, reverseSort = false } }, false)
    AH.SetFooter(L["Loading …"])
end

-- Kaufen: Massenware --------------------------------------------------------------------------------

local commodity = { ladderRows = {} }
buy.commodity = commodity

local function CommodityQuantity()
    return math.max(tonumber(commodity.quantity:GetText()) or 0, 0)
end

function AH.RefreshCommodity()
    if buy.mode ~= "commodity" or not buy.itemKey then return end
    local itemID = buy.itemKey.itemID
    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    local quantity = CommodityQuantity()
    -- Preis für die gewünschte Menge (Blizzards Rechnung: günstigste zuerst, eigene nicht mitzählen)
    local total, totalPrice, used = 0, 0, 0
    local rows = {}
    for i = 1, count do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
        if result then
            rows[#rows + 1] = result
            local available = result.quantity - (result.numOwnerItems or 0)
            if total < quantity and available > 0 then
                local take = math.min(available, quantity - total)
                total = total + take
                totalPrice = totalPrice + take * result.unitPrice
                used = #rows
            end
        end
    end
    commodity.ladder:Fill(rows, function(row, result, i)
        row.cells[1]:SetText(AH.Money(result.unitPrice))
        row.cells[2]:SetText(result.quantity)
        row.cells[3]:SetText((result.numOwnerItems or 0) > 0 and ("|cff8ecbb4" .. L["You"] .. "|r") or "")
        row:SetSelected(i <= used and quantity > 0)
        row:SetScript("OnClick", function()
            -- alles bis zu dieser Preisstufe kaufen
            local sum = 0
            for j = 1, i do sum = sum + rows[j].quantity - (rows[j].numOwnerItems or 0) end
            commodity.quantity:SetText(tostring(math.max(sum, 1)))
            AH.RefreshCommodity()
        end)
    end)
    local available = C_AuctionHouse.GetCommoditySearchResultsQuantity and C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID) or 0
    commodity.count:SetText(L["%d available"]:format(available))
    local unit = total > 0 and AH.Sanitize(math.floor(totalPrice / total)) or 0
    commodity.unit:SetText(total > 0 and AH.Money(unit) or "–")
    commodity.total:SetText(total > 0 and AH.Money(totalPrice) or "–")
    commodity.short:SetShown(quantity > total and count > 0)
    commodity.totalPrice, commodity.totalQuantity = totalPrice, total
    local canBuy = total > 0 and total == quantity and GetMoney() >= totalPrice
    commodity.buyButton:SetEnabled(canBuy)
    commodity.buyButton:SetAlpha(canBuy and 1 or 0.45)
    commodity.buyButton.Text:SetText((PURCHASE or L["Buy"]) .. (total > 0 and ("  ·  " .. AH.Money(totalPrice)) or ""))
    commodity.empty:SetShown(count == 0)
end

-- Kaufbestätigung für Massenware (Blizzard: erst Preis anfragen, dann bestätigen)
local dialog
local function CloseDialog()
    if dialog and dialog:IsShown() then dialog:Hide() end
end

local function OpenCommodityDialog()
    local UI = ns.UI
    local itemID = buy.itemKey and buy.itemKey.itemID
    local quantity = commodity.totalQuantity or 0
    if not itemID or quantity <= 0 then return end
    if not dialog then
        dialog = CreateFrame("Frame", "MeredanUIAuctionBuyDialog", UIParent)
        dialog:SetSize(380, 150)
        dialog:SetFrameStrata("DIALOG")
        dialog:SetToplevel(true)
        dialog:EnableMouse(true)
        UI.Box(dialog, ns.STYLE.panelColor)
        local accent = dialog:CreateTexture(nil, "OVERLAY")
        accent:SetColorTexture(unpack(UI.ACCENT))
        accent:SetPoint("TOPLEFT")
        accent:SetPoint("TOPRIGHT")
        accent:SetHeight(2 * ns.PixelSize())
        tinsert(UISpecialFrames, "MeredanUIAuctionBuyDialog")
        dialog.title = UI.Text(dialog, 15, "CENTER")
        dialog.title:SetPoint("TOP", 0, -18)
        ns.SetFont(dialog.title, 15, "", "bold")
        dialog.price = UI.Text(dialog, 15, "CENTER")
        dialog.price:SetPoint("TOP", dialog.title, "BOTTOM", 0, -10)
        dialog.state = UI.Text(dialog, 12, "CENTER", UI.MUTED)
        dialog.state:SetPoint("TOP", dialog.price, "BOTTOM", 0, -6)
        dialog.state:SetWidth(340)
        dialog.confirm = UI.Button(dialog, L["Buy now"], function()
            if dialog.ready then
                dialog.ready = false
                dialog.confirm:SetEnabled(false)
                dialog.state:SetText(L["Buying …"])
                C_AuctionHouse.ConfirmCommoditiesPurchase(dialog.itemID, dialog.quantity)
            end
        end, 160)
        dialog.confirm:SetHeight(30)
        dialog.confirm:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 16)
        dialog.confirm:SetMotionScriptsWhileDisabled(true)
        local cancel = UI.Button(dialog, CANCEL or L["Cancel"], function() dialog:Hide() end, 160)
        cancel:SetHeight(30)
        cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 16)
        dialog:SetScript("OnHide", function()
            C_AuctionHouse.CancelCommoditiesPurchase()
            dialog.ready = false
            if buy.mode == "commodity" and buy.itemKey then C_AuctionHouse.RefreshCommoditySearchResults(buy.itemKey.itemID) end
        end)
        dialog:SetScript("OnUpdate", function(self)
            if not self.ready then return end
            local remaining = C_AuctionHouse.GetQuoteDurationRemaining and C_AuctionHouse.GetQuoteDurationRemaining() or 30
            if remaining <= 0 then self:Hide() return end
            if remaining <= 10 then self.state:SetText(L["Price held for %d sec."]:format(math.ceil(remaining))) end
        end)
    end
    local info = AH.KeyInfo(buy.itemKey)
    dialog.itemID, dialog.quantity, dialog.preview = itemID, quantity, commodity.totalPrice
    dialog.title:SetText((info and info.itemName or "") .. "  × " .. quantity)
    dialog.price:SetText(AH.Money(commodity.totalPrice))
    dialog.state:SetText(L["Checking price …"])
    dialog.ready = false
    dialog.confirm:SetEnabled(false)
    dialog:ClearAllPoints()
    dialog:SetPoint("CENTER", window, "CENTER", 0, 40)
    dialog:Show()
    C_AuctionHouse.StartCommoditiesPurchase(itemID, quantity)
end

ns:On("COMMODITY_PRICE_UPDATED", function(_, unitPrice, totalPrice)
    if not (dialog and dialog:IsShown()) then return end
    if dialog.preview and totalPrice > dialog.preview * 1.05 then
        dialog.state:SetText("|cffe65050" .. L["Price is no longer available."] .. "|r")
        return
    end
    dialog.totalPrice = totalPrice
    dialog.price:SetText(AH.Money(totalPrice))
    dialog.state:SetText(totalPrice > (dialog.preview or 0) and ("|cffe6a050" .. L["Price went up a little."] .. "|r") or "")
    dialog.ready = true
    dialog.confirm:SetEnabled(true)
end)
ns:On("COMMODITY_PRICE_UNAVAILABLE", function()
    if dialog and dialog:IsShown() then dialog.state:SetText("|cffe65050" .. L["Price is no longer available."] .. "|r") end
end)
ns:On("COMMODITY_PURCHASE_SUCCEEDED", function()
    if not (dialog and dialog:IsShown()) then return end
    PlaySound(SOUNDKIT.LOOT_WINDOW_COIN_SOUND)
    if AH.RecordPurchase then
        local info = AH.KeyInfo(buy.itemKey)
        AH.RecordPurchase(info and info.itemName or "?", dialog.itemID, dialog.quantity, dialog.totalPrice or dialog.preview or 0)
    end
    dialog:Hide()
end)
ns:On("COMMODITY_PURCHASE_FAILED", function()
    if dialog and dialog:IsShown() then dialog.state:SetText("|cffe65050" .. L["Price is no longer available."] .. "|r") end
end)

-- Kaufen: Aufbau ------------------------------------------------------------------------------------

local function Star(parent)
    local star = CreateFrame("Button", nil, parent)
    star:SetSize(26, 26)
    star.icon = star:CreateTexture(nil, "ARTWORK")
    star.icon:SetAllPoints()
    function star:SetFavorite(on)
        self.on = on
        self.icon:SetAtlas(on and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off")
        self.icon:SetDesaturated(not on)
    end
    star:SetScript("OnClick", function(self)
        local key = buy.itemKey
        if not key then return end
        if C_AuctionHouse.FavoritesAreAvailable() and (self.on or not C_AuctionHouse.HasMaxFavorites()) then
            C_AuctionHouse.SetFavoriteItem(key, not self.on)
            self:SetFavorite(not self.on)
        end
    end)
    star:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.on and L["Remove from favorites"] or L["Add to favorites"], 1, 1, 1)
        GameTooltip:Show()
    end)
    star:SetScript("OnLeave", function() GameTooltip:Hide() end)
    star:SetFavorite(false)
    return star
end

local function ItemHeader(parent, target)
    local UI = ns.UI
    local top = CreateFrame("Frame", nil, parent)
    top:SetHeight(30)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    local back = UI.Button(top, "‹  " .. (BACK or L["Back"]), function()
        buy.mode = "browse"
        AH.ShowBuyMode()
        AH.RefreshResults()
    end, 100)
    back:SetHeight(28)
    back:SetPoint("LEFT")
    local refresh = AH.RefreshButton(top, function()
        if not buy.itemKey then return end
        if buy.mode == "commodity" then C_AuctionHouse.RefreshCommoditySearchResults(buy.itemKey.itemID)
        else C_AuctionHouse.RefreshItemSearchResults(buy.itemKey) end
    end)
    refresh:SetPoint("RIGHT")
    target.count = UI.Text(top, 12, "RIGHT", UI.MUTED)
    target.count:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
    local card = AH.Panel(parent)
    card:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -8)
    card:SetPoint("RIGHT")
    card:SetHeight(64)
    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(44, 44)
    holder:SetPoint("LEFT", 12, 0)
    ns.AddBorder(holder)
    target.icon = holder:CreateTexture(nil, "ARTWORK")
    target.icon:SetAllPoints()
    target.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder:EnableMouse(true)
    holder:SetScript("OnEnter", function(self)
        if not buy.itemKey then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemKey(buy.itemKey.itemID, buy.itemKey.itemLevel, buy.itemKey.itemSuffix)
        GameTooltip:Show()
    end)
    holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    target.name = UI.Text(card, 16, "LEFT")
    ns.SetFont(target.name, 16, "", "bold")
    target.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 12, -4)
    target.sub = UI.Text(card, 12, "LEFT", UI.MUTED)
    target.sub:SetPoint("TOPLEFT", target.name, "BOTTOMLEFT", 0, -5)
    target.star = Star(card)
    target.star:SetPoint("RIGHT", -12, 0)
    return card
end

local function CreateBuyView(view)
    local UI = ns.UI
    -- Suche
    local favButton = UI.IconButton(view, "Close", function()
        buy.cat1, buy.cat2, buy.cat3, buy.favorites = nil, nil, nil, true
        AH.Search()
    end, 30)
    favButton.icon:SetAtlas("auctionhouse-icon-favorite")
    favButton:SetPoint("TOPLEFT")
    favButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(FAVORITES or L["Favorites"], 1, 1, 1)
        GameTooltip:Show()
    end)
    favButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local searchButton = UI.Button(view, SEARCH or L["Search"], function() buy.favorites = false AH.Search() end, 110)
    searchButton:SetHeight(30)
    searchButton:SetPoint("TOPRIGHT")
    local filter = UI.Button(view, L["Filter"] .. "  " .. Chevron(), function(self) AH.OpenFilter(self) end, 90)
    filter:SetHeight(30)
    filter:SetPoint("RIGHT", searchButton, "LEFT", -6, 0)
    buy.search = UI.EditBox(view, 30)
    buy.search:SetFont(ns.STYLE.font, ns.FontPx(13), "")
    buy.search:SetPoint("LEFT", favButton, "RIGHT", 6, 0)
    buy.search:SetPoint("RIGHT", filter, "LEFT", -6, 0)
    buy.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() buy.favorites = false AH.Search() end)
    local hint = UI.Text(buy.search, 13, "LEFT", { 0.47, 0.46, 0.43 })
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search … (e.g. leather, copper ore)"])
    buy.search:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
    buy.search:HookScript("OnEditFocusGained", function(self)
        local recent = ns.root.ahRecent or {}
        if self:GetText() ~= "" or #recent == 0 then return end
        local items = {}
        for _, text in ipairs(recent) do items[#items + 1] = { value = text, label = text } end
        UI.OpenList(self, items, nil, function(value) self:SetText(value) self:ClearFocus() buy.favorites = false AH.Search() end)
    end)

    -- Kategorien
    local catPanel = AH.Panel(view)
    catPanel:SetPoint("TOPLEFT", 0, -38)
    catPanel:SetPoint("BOTTOMLEFT")
    catPanel:SetWidth(CAT_W)
    buy.catArea = UI.ScrollArea(catPanel)
    buy.catArea:SetPoint("TOPLEFT", 2, -4)
    buy.catArea:SetPoint("BOTTOMRIGHT", -14, 4)

    -- Ergebnisse
    local area = CreateFrame("Frame", nil, view)
    area:SetPoint("TOPLEFT", catPanel, "TOPRIGHT", 10, 0)
    area:SetPoint("BOTTOMRIGHT")
    buy.browseFrame = area
    buy.list = AH.List(area, ResultColumns(), true)
    buy.list.header:SetPoint("TOPLEFT")
    buy.list.header:SetPoint("TOPRIGHT", -16, 0)
    buy.list.area:SetPoint("BOTTOMRIGHT", -16, 30)
    buy.empty = UI.Text(area, 13, "CENTER", UI.MUTED)
    buy.empty:SetPoint("TOP", 0, -80)
    buy.empty:SetWidth(460)
    buy.empty:SetWordWrap(true)
    buy.empty:SetText(L["Search for something or pick a category. Right-click adds favorites – they show up right away when you open the auction house."])
    buy.more = UI.Button(area, L["Load more"], function() C_AuctionHouse.RequestMoreBrowseResults() end, 140)
    buy.more:SetHeight(26)
    buy.more:SetPoint("BOTTOM", 0, 0)

    -- Einzelstück
    local itemFrame = CreateFrame("Frame", nil, view)
    itemFrame:SetPoint("TOPLEFT", catPanel, "TOPRIGHT", 10, 0)
    itemFrame:SetPoint("BOTTOMRIGHT")
    buy.itemFrame = itemFrame
    local card = ItemHeader(itemFrame, item)
    item.list = AH.List(itemFrame, ItemColumns())
    item.list.header:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -8)
    item.list.header:SetPoint("RIGHT", -16, 0)
    item.list.area:SetPoint("BOTTOMRIGHT", -16, 44)
    item.empty = UI.Text(itemFrame, 13, "CENTER", UI.MUTED)
    item.empty:SetPoint("TOP", item.list.header, "BOTTOM", 0, -40)
    item.empty:SetText(L["No offers right now."])
    local bidLabel = UI.Text(itemFrame, 12, "LEFT", UI.MUTED)
    bidLabel:SetPoint("BOTTOMLEFT", 0, 8)
    bidLabel:SetText(L["Your bid"])
    item.bid = AH.MoneyInput(itemFrame, function() buy.bidTouched = true end)
    item.bid:SetPoint("LEFT", bidLabel, "RIGHT", 10, 0)
    item.bidButton = UI.Button(itemFrame, BID or L["Bid"], function()
        local selected = item.selected
        if not selected then return end
        local amount = item.bid:GetValue()
        if selected.buyoutAmount and amount >= selected.buyoutAmount then
            StaticPopup_Show("BUYOUT_AUCTION", nil, nil, { auctionID = selected.auctionID, buyout = selected.buyoutAmount })
            if AH.MarkPendingBuyout then AH.MarkPendingBuyout(selected, buy.itemKey) end
        elseif selected.minBid and amount < selected.minBid then
            UIErrorsFrame:AddExternalErrorMessage(AUCTION_HOUSE_BID_AMOUNT_IS_TOO_LOW or L["Bid is too low."])
        else
            StaticPopup_Show("BID_AUCTION", nil, nil, { auctionID = selected.auctionID, bid = amount })
        end
    end, 90)
    item.bidButton:SetHeight(30)
    item.bidButton:SetPoint("LEFT", item.bid, "RIGHT", 6, 0)
    item.bidButton:SetMotionScriptsWhileDisabled(true)
    item.buyButton = UI.Button(itemFrame, BUYOUT or L["Buyout"], function()
        local selected = item.selected
        if not (selected and selected.buyoutAmount) then return end
        StaticPopup_Show("BUYOUT_AUCTION", nil, nil, { auctionID = selected.auctionID, buyout = selected.buyoutAmount })
        if AH.MarkPendingBuyout then AH.MarkPendingBuyout(selected, buy.itemKey) end
    end, 200)
    item.buyButton:SetHeight(30)
    item.buyButton:SetPoint("BOTTOMRIGHT", -16, 0)
    item.buyButton:SetMotionScriptsWhileDisabled(true)
    for _, b in ipairs({ item.buyButton }) do
        for _, e in ipairs(ns.AddBorder(b, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end
    end

    -- Massenware
    local comFrame = CreateFrame("Frame", nil, view)
    comFrame:SetPoint("TOPLEFT", catPanel, "TOPRIGHT", 10, 0)
    comFrame:SetPoint("BOTTOMRIGHT")
    buy.commodityFrame = comFrame
    local comTop = ItemHeader(comFrame, commodity)
    local ladderW = 250
    comTop:SetPoint("RIGHT", -(ladderW + 10), 0)
    commodity.ladder = AH.List(comFrame, {
        { title = L["Price / unit"], width = 130 }, { title = L["Qty"], width = 70, align = "RIGHT" }, { title = "" },
    })
    commodity.ladder.header:SetPoint("TOPRIGHT", -16, -38)
    commodity.ladder.header:SetWidth(ladderW - 16)
    commodity.ladder.area:SetPoint("BOTTOMRIGHT", -16, 0)
    commodity.empty = UI.Text(comFrame, 13, "CENTER", UI.MUTED)
    commodity.empty:SetPoint("TOP", commodity.ladder.header, "BOTTOM", 0, -40)
    commodity.empty:SetText(L["No offers right now."])
    local form = AH.Panel(comFrame)
    form:SetPoint("TOPLEFT", comTop, "BOTTOMLEFT", 0, -10)
    form:SetPoint("BOTTOMRIGHT", -(ladderW + 10), 0)
    local function Label(text, y)
        local label = UI.Text(form, 13, "LEFT", UI.MUTED)
        label:SetPoint("TOPLEFT", 16, y)
        label:SetText(text)
        return label
    end
    Label(L["Quantity"], -24)
    commodity.quantity = UI.EditBox(form, 30)
    commodity.quantity:SetNumeric(true)
    commodity.quantity:SetMaxLetters(6)
    commodity.quantity:SetWidth(90)
    commodity.quantity:SetPoint("TOPLEFT", 140, -16)
    commodity.quantity:SetScript("OnTextChanged", function() AH.RefreshCommodity() end)
    commodity.quantity:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local add20 = UI.Button(form, "+20", function() commodity.quantity:SetText(tostring(CommodityQuantity() + 20)) end, 54)
    add20:SetHeight(30)
    add20:SetPoint("LEFT", commodity.quantity, "RIGHT", 6, 0)
    local add100 = UI.Button(form, "+100", function() commodity.quantity:SetText(tostring(CommodityQuantity() + 100)) end, 60)
    add100:SetHeight(30)
    add100:SetPoint("LEFT", add20, "RIGHT", 4, 0)
    Label(L["Price / unit"], -66)
    commodity.unit = UI.Text(form, 13, "LEFT")
    commodity.unit:SetPoint("TOPLEFT", 140, -66)
    Label(L["Total price"], -98)
    commodity.total = UI.Text(form, 14, "LEFT")
    ns.SetFont(commodity.total, 14, "", "bold")
    commodity.total:SetPoint("TOPLEFT", 140, -98)
    commodity.short = UI.Text(form, 12, "LEFT", { 0.9, 0.4, 0.3 })
    commodity.short:SetPoint("TOPLEFT", 16, -126)
    commodity.short:SetText(L["Not that many on offer."])
    local hintText = UI.Text(form, 12, "LEFT", UI.MUTED)
    hintText:SetPoint("TOPLEFT", 16, -150)
    hintText:SetPoint("RIGHT", -16, 0)
    hintText:SetWordWrap(true)
    hintText:SetText(L["The marked price steps on the right are what you buy. Click a step to buy everything up to that price."])
    commodity.buyButton = UI.Button(form, PURCHASE or L["Buy"], OpenCommodityDialog, 220)
    commodity.buyButton:SetHeight(32)
    commodity.buyButton:SetPoint("BOTTOM", 0, 16)
    commodity.buyButton:SetMotionScriptsWhileDisabled(true)
    for _, e in ipairs(ns.AddBorder(commodity.buyButton, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end
end

function AH.ShowBuyMode()
    if not buy.browseFrame then return end
    buy.browseFrame:SetShown(buy.mode == "browse")
    buy.itemFrame:SetShown(buy.mode == "item")
    buy.commodityFrame:SetShown(buy.mode == "commodity")
    if buy.mode ~= "commodity" then CloseDialog() end
end

-- Filter-Menü: Stufen, nutzbar, Seltenheit (wie Blizzards Filter)
function AH.OpenFilter(owner)
    local items = {
        { value = "usable", label = (buy.usableOnly and (Tick() .. "  ") or "      ") .. (AUCTION_HOUSE_FILTER_USABLE_ONLY or L["Usable only"]) },
        { value = "uncollected", label = (buy.uncollectedOnly and (Tick() .. "  ") or "      ") .. (AUCTION_HOUSE_FILTER_UNCOLLECTED_ONLY or L["Uncollected only"]) },
    }
    local qualities = { { "PoorQuality", 0 }, { "CommonQuality", 1 }, { "UncommonQuality", 2 }, { "RareQuality", 3 }, { "EpicQuality", 4 }, { "LegendaryQuality", 5 } }
    for _, q in ipairs(qualities) do
        local hiddenQ = buy.hideQuality and buy.hideQuality[q[1]]
        local r, g, b = AH.QualityColor(q[2])
        items[#items + 1] = { value = q[1], label = (hiddenQ and "      " or (Tick() .. "  "))
            .. ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) .. (_G["ITEM_QUALITY" .. q[2] .. "_DESC"] or q[1]) .. "|r" }
    end
    ns.UI.OpenList(owner, items, nil, function(value)
        if value == "usable" then buy.usableOnly = not buy.usableOnly
        elseif value == "uncollected" then buy.uncollectedOnly = not buy.uncollectedOnly
        else
            buy.hideQuality = buy.hideQuality or {}
            buy.hideQuality[value] = not buy.hideQuality[value] or nil
        end
        C_Timer.After(0, function() AH.OpenFilter(owner) end)
    end)
end

-- Fenster, Tabs, Öffnen ---------------------------------------------------------------------------

local TABS = {
    { key = "buy", icon = "Interface\\Icons\\INV_Misc_Coin_02", name = L["Buy"] },
    { key = "sell", icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue", name = L["Sell"] },
    { key = "owned", icon = "Interface\\Icons\\INV_Letter_15", name = L["My auctions"] },
    { key = "ledger", icon = "Interface\\Icons\\INV_Misc_Book_04", name = L["History"] },
}

function AH.SelectTab(key)
    AH.current = key
    for i, def in ipairs(TABS) do
        local on = def.key == key
        for _, edge in ipairs(tabs[i].active) do edge:SetShown(on) end
        tabs[i].icon:SetDesaturated(not on)
        tabs[i].icon:SetAlpha(on and 1 or 0.75)
    end
    for k, view in pairs(views) do view:SetShown(k == key) end
    window.npcTitle:SetText(L["Auction house"] .. "  ·  " .. (TABS[key == "buy" and 1 or key == "sell" and 2 or key == "owned" and 3 or 4].name))
    AH.SetFooter("")
    if key == "buy" then
        if buy.mode == "browse" then AH.RefreshResults() end
    elseif key == "sell" and AH.ShowSell then AH.ShowSell()
    elseif key == "owned" and AH.ShowOwned then AH.ShowOwned()
    elseif key == "ledger" and AH.ShowLedger then AH.ShowLedger()
    end
    ns.UI.CloseList()
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIAuctionHouse", WIDTH, ns.NPC_HEIGHT, "auction")
    window.extraRight = TAB_STEP
    AH.window = window
    ns.WatchBlizzardFrame(window, function() return AuctionHouseFrame end)

    for i, def in ipairs(TABS) do
        local button = CreateFrame("Button", nil, window)
        button:SetSize(TAB_SIZE, TAB_SIZE)
        button:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, -(60 + (i - 1) * TAB_STEP))
        UI.Box(button, ns.STYLE.panelColor)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetTexture(def.icon)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.active = ns.AddBorder(button, true, 2)
        for _, edge in ipairs(button.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(def.name, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            AH.SelectTab(def.key)
        end)
        tabs[i] = button
    end
    for _, def in ipairs(TABS) do
        local view = CreateFrame("Frame", nil, window)
        view:SetPoint("TOPLEFT", PAD, -TOP)
        view:SetPoint("BOTTOMRIGHT", -PAD, BOTTOM)
        view:Hide()
        views[def.key] = view
    end
    AH.views = views
    CreateBuyView(views.buy)
    if AH.CreateSellView then AH.CreateSellView(views.sell) end
    if AH.CreateOwnedView then AH.CreateOwnedView(views.owned) end
    if AH.CreateLedgerView then AH.CreateLedgerView(views.ledger) end

    footerText = UI.Text(window, 12, "LEFT", UI.MUTED)
    footerText:SetPoint("BOTTOMLEFT", PAD, 20)
    footerText:SetPoint("RIGHT", window, "RIGHT", -240, 0)
    goldText = UI.Text(window, 13, "RIGHT")
    goldText:SetPoint("BOTTOMRIGHT", -PAD, 20)
    AH.footerRight = CreateFrame("Frame", nil, window) -- Platz für Knöpfe der Ansichten (links vom Gold)
    AH.footerRight:SetSize(1, 28)
    AH.footerRight:SetPoint("RIGHT", goldText, "LEFT", -12, 0)

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN or SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        goldText:SetText(GetMoneyString(GetMoney(), true))
        buy.mode = "browse"
        AH.ShowBuyMode()
        AH.SelectTab("buy")
        LayoutCategories()
        if C_AuctionHouse.HasFavorites() then
            buy.favorites = true
            AH.Search()
        else
            buy.results = {}
            AH.RefreshResults()
        end
        OpenAllBags(window)
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.AUCTION_WINDOW_CLOSE or SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        CloseDialog()
        ns.UI.CloseList()
        for _, popup in ipairs({ "BUYOUT_AUCTION", "BID_AUCTION", "CANCEL_AUCTION", "MEREDANUI_AH_POST_WARNING" }) do
            if StaticPopup_Visible(popup) then StaticPopup_Hide(popup) end
        end
        CloseAllBags(window)
        AH.ReleaseBlizzardItem()
        if ns.StillInteracting("Auctioneer", AuctionHouseFrame) then C_AuctionHouse.CloseAuctionHouse() end
    end)
end

function AH.UpdateGold()
    if goldText and window and window:IsShown() then goldText:SetText(GetMoneyString(GetMoney(), true)) end
end

-- Sperre aus Blizzards geparktem Verkaufsfenster lösen (sein OnHide, das das sonst tut, läuft nie)
function AH.ReleaseBlizzardItem()
    if AuctionHouseFrame and AuctionHouseFrame.ClearPostItem then AuctionHouseFrame:ClearPostItem() end
end

local function Park()
    -- vor dem ersten Zeigen parken: dann läuft Blizzards OnShow/OnHide nie (OnHide schlösse das AH)
    if AuctionHouseFrame and AuctionHouseFrame:GetParent() ~= hidden then
        AuctionHouseFrame:SetParent(hidden)
        -- Blizzards Rückfrage beim Einstellen hängt an seinem eigenen Verkaufsfenster – wir fragen selbst
        AuctionHouseFrame:UnregisterEvent("AUCTION_HOUSE_POST_WARNING")
        AuctionHouseFrame:UnregisterEvent("AUCTION_HOUSE_POST_ERROR")
        -- Rechtsklick auf Taschen-Gegenstände ruft AuctionHouseFrame:SetPostItem auf. Blizzards Fassung
        -- sperrt den Gegenstand in seinem (geparkten, nie eingerichteten) Verkaufsfenster und stürzt bei
        -- Massenware ab (QueryItem: searchContext nil) – Folge: Gegenstand ausgegraut, Wechseln
        -- unmöglich, Server lehnt das Einstellen ab (Benny 2026-11-07). Deshalb direkt zu uns.
        AuctionHouseFrame.SetPostItem = function(_, itemLocation)
            if not (window and window:IsShown() and AH.SetSellItem) then return end
            if not (itemLocation and itemLocation:IsValid()) then return end
            AH.SelectTab("sell")
            AH.SetSellItem(itemLocation)
        end
    end
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", Park)

    ns:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
        if kind ~= Enum.PlayerInteractionType.Auctioneer then return end
        if not window then CreateWindow() end
        Park()
        window:SetNpc("npc")
        window:Show()
    end)
    ns:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
        if kind == Enum.PlayerInteractionType.Auctioneer and window then window:Hide() end
    end)
    ns:On("AUCTION_HOUSE_CLOSED", function() if window then window:Hide() end end)

    ns:On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", function()
        buy.results = C_AuctionHouse.GetBrowseResults() or {}
        AH.RefreshResults()
    end)
    ns:On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", function(_, added)
        for _, result in ipairs(added or {}) do buy.results[#buy.results + 1] = result end
        AH.RefreshResults()
    end)
    ns:On("AUCTION_HOUSE_BROWSE_FAILURE", function()
        AH.SetFooter("|cffe65050" .. (ERR_AUCTION_DATABASE_ERROR or L["Search failed."]) .. "|r")
    end)
    ns:On("ITEM_KEY_ITEM_INFO_RECEIVED", function()
        if window and window:IsShown() and AH.current == "buy" then AH.RefreshResults() end
    end)
    ns:On("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey)
        if buy.mode == "item" then AH.RefreshItem() AH.SetFooter("") end
        if AH.OnSellResults then AH.OnSellResults(itemKey) end
    end)
    ns:On("ITEM_SEARCH_RESULTS_ADDED", function(_, itemKey)
        if buy.mode == "item" then AH.RefreshItem() end
        if AH.OnSellResults then AH.OnSellResults(itemKey) end
    end)
    ns:On("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID)
        if buy.mode == "commodity" then AH.RefreshCommodity() AH.SetFooter("") end
        if AH.OnSellResults then AH.OnSellResults(nil, itemID) end
    end)
    ns:On("COMMODITY_SEARCH_RESULTS_ADDED", function(_, itemID)
        if buy.mode == "commodity" then AH.RefreshCommodity() end
        if AH.OnSellResults then AH.OnSellResults(nil, itemID) end
    end)
    ns:On("AUCTION_HOUSE_PURCHASE_COMPLETED", function(_, auctionID)
        if AH.OnPurchaseCompleted then AH.OnPurchaseCompleted(auctionID) end
        if buy.mode == "item" and buy.itemKey then C_AuctionHouse.RefreshItemSearchResults(buy.itemKey) end
    end)
    ns:On("AUCTION_HOUSE_SHOW_ERROR", function(_, err)
        if DevLog then DevLog("MeredanUI", "AH error " .. tostring(err)) end
        local text = AuctionHouseUtil and AuctionHouseUtil.GetErrorText and AuctionHouseUtil.GetErrorText(err)
        if text then UIErrorsFrame:AddExternalErrorMessage(text) end
    end)
    ns:On("AUCTION_HOUSE_FAVORITES_UPDATED", function()
        if buy.favorites and window and window:IsShown() and buy.mode == "browse" then AH.Search() end
    end)
    ns:On("PLAYER_MONEY", function()
        AH.UpdateGold()
        if buy.mode == "commodity" then AH.RefreshCommodity() end
    end)
end)
