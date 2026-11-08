-- Auktionshaus · Verlauf (Entwurf Ansicht 6, neu). Accountweit in ns.root.ahLedger.
-- Quellen:
--   Gekauft:     sofort beim Kauf (Sofortkauf, Massenware); gewonnene Gebote über die Rechnung in der Post
--   Verkauft:    Verkaufsrechnung in der Post (Erlös = Gebot, Gebühr = AH-Anteil)
--   Abgebrochen: AUCTION_CANCELED → Einzahlung verloren
--   Abgelaufen:  AUCTION_HOUSE_AUCTIONS_EXPIRED → Einzahlung verloren
-- Einzahlungen merken wir uns beim Einstellen pro Auktion (AH.RecordPosted).
local _, ns = ...
local L = ns.L
local AH = ns.AH

local led = { period = "month", filter = "all", allChars = true }
AH.ledger = led

local KINDS = {
    posted = { label = "Listed", color = { 0.91, 0.9, 0.87 } },
    sold = { label = "Sold", color = { 0.56, 0.8, 0.71 } },
    bought = { label = "Bought", color = { 0.43, 0.56, 0.81 } },
    expired = { label = "Expired", color = { 0.6, 0.59, 0.56 } },
    cancelled = { label = "Cancelled", color = { 0.85, 0.5, 0.4 } },
}

local function Data()
    ns.root.ahLedger = ns.root.ahLedger or { entries = {}, seen = {}, deposits = {} }
    local d = ns.root.ahLedger
    d.entries, d.seen, d.deposits = d.entries or {}, d.seen or {}, d.deposits or {}
    return d
end

local function Char()
    return UnitName("player") .. "-" .. (GetNormalizedRealmName() or "")
end

local function Add(kind, name, qty, price, fee, net, key)
    local d = Data()
    if key then
        if d.seen[key] then return end
        d.seen[key] = time()
    end
    table.insert(d.entries, 1, { t = time(), kind = kind, name = name or "?", qty = qty or 1,
        price = price or 0, fee = fee or 0, net = net or 0, char = Char() })
    if AH.window and AH.window:IsShown() and AH.current == "ledger" then AH.RefreshLedger() end
end

-- Einstellen: Einzahlung merken (für Abbrechen/Ablaufen)
function AH.RecordPosted(auctionID, p)
    if not auctionID then return end
    Data().deposits[auctionID] = { name = p.name, qty = p.qty, deposit = p.deposit or 0, t = time() }
    -- „Eingestellt“: Angebotswert, Einzahlung als Gebühr (zählt nicht zu den Summen)
    local value = p.commodity and (p.price or 0) * (p.qty or 1) or (p.buyout or p.bid or 0)
    Add("posted", p.name, p.qty, value, p.deposit or 0, 0, "post:" .. auctionID)
end

-- Abbrechen aus „Meine Auktionen“: Name/Menge/Abbruchgebühr vorher merken (auch für Auktionen, die
-- nicht über mUI eingestellt wurden)
local pendingCancels, lastCancel = {}, nil
function AH.MarkPendingCancel(auctionID, name, qty)
    if not auctionID then return end
    local entry = { id = auctionID, name = name, qty = qty, cost = C_AuctionHouse.GetCancelCost(auctionID) or 0, t = GetTime() }
    pendingCancels[auctionID] = entry
    lastCancel = entry
end

-- Wirklich abgebrochen = Abbrechen bestätigt (C_AuctionHouse.CancelAuction, auch aus Blizzards
-- Dialog). Forever meldet AUCTION_CANCELED auch, wenn eine Auktion abläuft ODER verkauft wird
-- (Benny 2026-11-07: Mystikerarmreifen nach 8 Std. „abgebrochen“, Stachelkeule verkauft und als
-- „abgelaufen“ gezählt). Ohne bestätigten Abbruch wird AUCTION_CANCELED daher ignoriert; was
-- wirklich passiert ist, sagt AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION (verkauft/abgelaufen, mit
-- Auktionsnummer) bzw. offline die Post („Auktion abgelaufen: …“).
local confirmedCancel -- { id, t }
hooksecurefunc(C_AuctionHouse, "CancelAuction", function(auctionID)
    confirmedCancel = { id = auctionID, t = GetTime() }
    if auctionID and not pendingCancels[auctionID] then
        pendingCancels[auctionID] = { id = auctionID, cost = C_AuctionHouse.GetCancelCost(auctionID) or 0, t = GetTime() }
    end
end)
-- nur das Zeitfenster zählt: Massenware meldet beim Abbrechen evtl. eine andere Nummer
local function WasConfirmed()
    return confirmedCancel ~= nil and GetTime() - confirmedCancel.t <= 30
end

-- Einzahlung zu einer Auktion: erst über die Nummer, sonst über Gegenstand + Menge (Massenware
-- meldet beim Abbrechen eine andere Nummer als beim Einstellen)
local function TakeDeposit(auctionID, name, qty)
    local d = Data()
    if d.deposits[auctionID] then
        local dep = d.deposits[auctionID]
        d.deposits[auctionID] = nil
        return dep
    end
    if not name then return end
    local bestID, best
    for id, dep in pairs(d.deposits) do
        if dep.name == name and (not qty or dep.qty == qty) and (not best or dep.t > best.t) then bestID, best = id, dep end
    end
    if bestID then d.deposits[bestID] = nil end
    return best
end

-- Sofortkauf: Daten merken, eingetragen wird bei AUCTION_HOUSE_PURCHASE_COMPLETED
local pendingBuyouts = {}
function AH.MarkPendingBuyout(result, itemKey)
    if not result or not result.auctionID then return end
    local info = itemKey and AH.KeyInfo(itemKey)
    local name = info and info.itemName
    if not name and result.itemLink then name = C_Item.GetItemInfo(result.itemLink) end
    pendingBuyouts[result.auctionID] = { name = name, qty = result.quantity or 1, price = result.buyoutAmount or 0 }
end

function AH.OnPurchaseCompleted(auctionID)
    local p = pendingBuyouts[auctionID]
    if not p then return end
    pendingBuyouts[auctionID] = nil
    Add("bought", p.name, p.qty, p.price, 0, -p.price)
    Data().seen["buy:" .. (p.name or "") .. ":" .. p.price] = time() -- Rechnung in der Post später nicht doppelt zählen
end

function AH.RecordPurchase(name, _, qty, total)
    Add("bought", name, qty, total, 0, -total)
    Data().seen["buy:" .. (name or "") .. ":" .. total] = time()
end

-- Abgelaufen: über die Nummer, sonst über den Namen (Post kennt keine Nummer)
local function RecordExpired(auctionID, name)
    local dep = TakeDeposit(auctionID or 0, name)
    if not dep then return end
    Add("expired", dep.name, dep.qty, 0, dep.deposit, -dep.deposit,
        "expire:" .. tostring(auctionID or (dep.name .. ":" .. (dep.t or 0))))
end

ns:On("AUCTION_CANCELED", function(_, auctionID)
    -- kein bestätigter Abbruch > verkauft oder abgelaufen, das klären Meldung bzw. Post (s. o.)
    if not WasConfirmed() then return end
    confirmedCancel = nil
    -- welche Auktion? Nummer passt bei Massenware nicht → den gerade bestätigten Abbruch nehmen
    local pend = auctionID and pendingCancels[auctionID]
    if not pend and lastCancel and GetTime() - lastCancel.t < 30 then pend = lastCancel end
    if pend then
        pendingCancels[pend.id] = nil
        if lastCancel == pend then lastCancel = nil end
    end
    local dep = TakeDeposit(auctionID or 0, pend and pend.name, pend and pend.qty)
    if not dep and not pend then return end
    local fee = (dep and dep.deposit or 0) + (pend and pend.cost or 0)
    Add("cancelled", (dep and dep.name) or (pend and pend.name), (dep and dep.qty) or (pend and pend.qty), 0, fee, -fee,
        "cancel:" .. tostring(pend and pend.id or auctionID))
end)

ns:On("AUCTION_HOUSE_AUCTIONS_EXPIRED", function(_, auctionID) RecordExpired(auctionID) end)

-- Blizzards Meldung „Käufer gefunden“ / „abgelaufen“ (kommt auch bei geschlossenem Auktionshaus)
local NOTE = Enum.AuctionHouseNotification
ns:On("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION", function(_, notification, text, auctionID)
    if not NOTE then return end
    if notification == NOTE.AuctionExpired then
        RecordExpired(auctionID, text)
    elseif notification == NOTE.AuctionSold then
        TakeDeposit(auctionID or 0, text) -- Einzahlung kommt mit der Verkaufsrechnung zurück, nichts eintragen
    end
end)

-- Post-Betreff „Auktion abgelaufen: <Gegenstand>“ > Gegenstand (für Ablauf, während du offline warst)
local function ExpiredMailItem(subject)
    if not (subject and AUCTION_EXPIRED_MAIL_SUBJECT) then return end
    local pre, post = AUCTION_EXPIRED_MAIL_SUBJECT:match("^(.-)%%s(.*)$")
    if not pre or #subject <= #pre + #post then return end
    if subject:sub(1, #pre) ~= pre or (post ~= "" and subject:sub(-#post) ~= post) then return end
    return subject:sub(#pre + 1, #subject - #post)
end

-- Post: Rechnungen auswerten. Schlüssel aus Inhalt + ungefährer Sendezeit (Stunde), damit dieselbe
-- Rechnung beim nächsten Öffnen nicht noch einmal zählt.
local function ScanMail()
    local d = Data()
    local now = time()
    for i = 1, GetInboxNumItems() do
        local invoiceType, itemName, _, bid, buyout, deposit, consignment, _, _, _, count = GetInboxInvoiceInfo(i)
        local expiredItem = not invoiceType and ExpiredMailItem(select(4, GetInboxHeaderInfo(i)))
        if expiredItem then RecordExpired(nil, expiredItem) end -- nur wenn die Einzahlung noch offen ist
        if invoiceType == "seller" or invoiceType == "buyer" then
            local daysLeft = select(7, GetInboxHeaderInfo(i)) or 0
            local sent = math.floor((now - (30 - daysLeft) * 86400) / 3600)
            local key = table.concat({ invoiceType, itemName or "", bid or 0, buyout or 0, consignment or 0, count or 1, sent }, ":")
            if not d.seen[key] then
                if invoiceType == "seller" then
                    local net = (bid or 0) + (deposit or 0) - (consignment or 0)
                    -- Einzahlung kommt zurück → nicht als Gebühr; Gebühr = AH-Anteil
                    Add("sold", itemName, count, bid or 0, consignment or 0, net - (deposit or 0), key)
                else
                    -- Sofortkäufe sind schon eingetragen; hier nur gewonnene Gebote
                    if d.seen["buy:" .. (itemName or "") .. ":" .. (bid or 0)] then
                        d.seen[key] = now
                    else
                        Add("bought", itemName, count, bid or 0, 0, -(bid or 0), key)
                    end
                end
            end
        end
    end
    -- alte Merker aufräumen (60 Tage)
    for key, t in pairs(d.seen) do if now - t > 60 * 86400 then d.seen[key] = nil end end
    for id, dep in pairs(d.deposits) do if now - (dep.t or 0) > 4 * 86400 then d.deposits[id] = nil end end
end
ns:On("MAIL_INBOX_UPDATE", ScanMail)

-- Anzeige --------------------------------------------------------------------------------------

local PERIODS = {
    { key = "today", label = "Today" }, { key = "week", label = "Week" }, { key = "month", label = "Month" },
    { key = "year", label = "Year" }, { key = "all", label = "All time" },
}
local FILTERS = { "all", "posted", "sold", "bought", "expired", "cancelled" }

local function PeriodStart()
    local now = date("*t")
    if led.period == "today" then return time({ year = now.year, month = now.month, day = now.day, hour = 0 }) end
    if led.period == "week" then
        local wday = (now.wday + 5) % 7 -- Montag = 0
        return time({ year = now.year, month = now.month, day = now.day - wday, hour = 0 })
    end
    if led.period == "month" then return time({ year = now.year, month = now.month, day = 1, hour = 0 }) end
    if led.period == "year" then return time({ year = now.year, month = 1, day = 1, hour = 0 }) end
    return 0
end

local function Visible(e, from, query)
    if e.t < from then return false end
    if not led.allChars and e.char ~= Char() then return false end
    if query ~= "" and not strlower(e.name or ""):find(query, 1, true) then return false end
    return true
end

function AH.RefreshLedger()
    if not led.list then return end
    local UI = ns.UI
    local from = PeriodStart()
    local query = strlower(strtrim(led.search:GetText() or ""))
    local income, expense, fees, sales, buys = 0, 0, 0, 0, 0
    local rows = {}
    for _, e in ipairs(Data().entries) do
        if Visible(e, from, query) then
            if e.kind == "sold" then income, sales = income + e.price, sales + 1 fees = fees + e.fee
            elseif e.kind == "bought" then expense, buys = expense + e.price, buys + 1
            elseif e.kind ~= "posted" then fees = fees + e.fee end
            if led.filter == "all" or led.filter == e.kind then rows[#rows + 1] = e end
        end
    end
    led.cards.income.value:SetText(AH.Money(income))
    led.cards.income.sub:SetText(L["%d sales"]:format(sales))
    led.cards.expense.value:SetText(AH.Money(expense))
    led.cards.expense.sub:SetText(L["%d purchases"]:format(buys))
    led.cards.fees.value:SetText(AH.Money(fees))
    local profit = income - fees - expense
    led.cards.profit.value:SetText((profit >= 0 and "|cff8ecbb4+ " or "|cffe65050− ") .. GetMoneyString(math.abs(profit), true) .. "|r")

    led.list:Fill(rows, function(row, e)
        local kind = KINDS[e.kind]
        row.cells[1]:SetText(date("%d.%m. %H:%M", e.t))
        row.cells[1]:SetTextColor(unpack(UI.MUTED))
        row.cells[2]:SetText(L[kind.label])
        row.cells[2]:SetTextColor(unpack(kind.color))
        row.cells[3]:SetText(e.name .. ((led.allChars and e.char ~= Char()) and ("  |cff77756e" .. (e.char:match("^[^-]+") or "") .. "|r") or ""))
        row.cells[4]:SetText(e.qty)
        row.cells[5]:SetText(e.price > 0 and AH.Money(e.price) or "|cff99978f–|r")
        if e.kind == "posted" then
            -- Einzahlung: kommt bei Verkauf zurück, daher grau
            row.cells[6]:SetText(e.fee > 0 and ("|cff99978f" .. GetMoneyString(e.fee, true) .. "|r") or "|cff99978f–|r")
        else
            row.cells[6]:SetText(e.fee > 0 and ("|cffe6a050− " .. GetMoneyString(e.fee, true) .. "|r") or "|cff99978f–|r")
        end
        row.cells[7]:SetText(e.net == 0 and "|cff99978f–|r" or ((e.net > 0 and "|cff8ecbb4+ " or "|cffe65050− ") .. GetMoneyString(math.abs(e.net), true) .. "|r"))
        row:SetSelected(false)
        row:SetScript("OnClick", nil)
    end)
    led.empty:SetShown(#rows == 0)
    for _, chip in ipairs(led.periodChips) do
        local on = chip.key == led.period
        for _, edge in ipairs(chip.active) do edge:SetShown(on) end
        chip.Text:SetTextColor(unpack(on and UI.ACCENT or UI.TEXT))
    end
    for _, chip in ipairs(led.filterChips) do
        local on = chip.key == led.filter
        for _, edge in ipairs(chip.active) do edge:SetShown(on) end
        chip.Text:SetTextColor(unpack(on and UI.ACCENT or UI.TEXT))
    end
    led.charButton.Text:SetText((led.allChars and L["All characters"] or UnitName("player")) .. "  " .. AH.IconMarkup("ChevronDown", 12))
end

function AH.ShowLedger()
    AH.window.npcTitle:SetText(L["Auction house"] .. "  ·  " .. L["History"])
    AH.RefreshLedger()
    AH.SetFooter(L["Sales are counted when the invoice arrives in your mailbox."])
end

function AH.CreateLedgerView(view)
    local UI = ns.UI
    local function Chip(parent, key, text, onClick)
        local chip = UI.Button(parent, text, onClick, 10)
        chip:SetWidth(chip.Text:GetUnboundedStringWidth() + 24)
        chip:SetHeight(26)
        chip.key = key
        chip.active = ns.AddBorder(chip, true)
        for _, edge in ipairs(chip.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        return chip
    end
    -- Zeitraum
    led.periodChips = {}
    local last
    for _, p in ipairs(PERIODS) do
        local chip = Chip(view, p.key, L[p.label], function() led.period = p.key AH.RefreshLedger() end)
        if last then chip:SetPoint("LEFT", last, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT") end
        led.periodChips[#led.periodChips + 1] = chip
        last = chip
    end
    led.charButton = UI.Button(view, "", function(self)
        UI.OpenList(self, { { value = true, label = L["All characters"] }, { value = false, label = UnitName("player") } },
            led.allChars, function(value) led.allChars = value AH.RefreshLedger() end)
    end, 170)
    led.charButton:SetHeight(26)
    led.charButton:SetPoint("TOPRIGHT")

    -- Karten
    led.cards = {}
    local cardHolder = CreateFrame("Frame", nil, view)
    cardHolder:SetPoint("TOPLEFT", 0, -36)
    cardHolder:SetPoint("TOPRIGHT", 0, -36)
    cardHolder:SetHeight(70)
    local defs = {
        { "income", L["Income"] }, { "expense", L["Expenses"] },
        { "fees", L["Fees"], L["AH cut + lost deposits"] }, { "profit", L["Profit"] },
    }
    local cards = {}
    for i, def in ipairs(defs) do
        local card = AH.Panel(cardHolder)
        card.title = UI.Text(card, 12, "LEFT", UI.MUTED)
        card.title:SetPoint("TOPLEFT", 12, -10)
        card.title:SetText(def[2])
        card.value = UI.Text(card, 16, "LEFT")
        ns.SetFont(card.value, 16, "", "bold")
        card.value:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
        card.sub = UI.Text(card, 11, "LEFT", UI.MUTED)
        card.sub:SetPoint("TOPLEFT", card.value, "BOTTOMLEFT", 0, -4)
        card.sub:SetText(def[3] or "")
        led.cards[def[1]] = card
        cards[i] = card
    end
    cardHolder:SetScript("OnSizeChanged", function(self, width)
        local w = (width - 3 * 8) / 4
        for i, card in ipairs(cards) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", (i - 1) * (w + 8), 0)
            card:SetSize(w, 70)
        end
    end)

    -- Filter und Suche
    led.filterChips = {}
    last = nil
    for _, key in ipairs(FILTERS) do
        local label = key == "all" and L["All"] or L[KINDS[key].label]
        local chip = Chip(view, key, label, function() led.filter = key AH.RefreshLedger() end)
        if last then chip:SetPoint("LEFT", last, "RIGHT", 4, 0) else chip:SetPoint("TOPLEFT", 0, -118) end
        led.filterChips[#led.filterChips + 1] = chip
        last = chip
    end
    led.search = UI.EditBox(view, 26)
    led.search:SetWidth(200)
    led.search:SetPoint("TOPRIGHT", 0, -118)
    led.search:SetScript("OnTextChanged", function() AH.RefreshLedger() end)
    led.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local hint = UI.Text(led.search, 12, "LEFT", { 0.47, 0.46, 0.43 })
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search item"])
    led.search:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)

    -- Liste
    led.list = AH.List(view, {
        { title = L["Date"], width = 110 }, { title = L["Type"], width = 100 }, { title = L["Item"] },
        { title = L["Qty"], width = 50, align = "RIGHT" }, { title = L["Price"], width = 120, align = "RIGHT" },
        { title = L["Fee"], width = 100, align = "RIGHT" }, { title = L["Net"], width = 120, align = "RIGHT" },
    })
    led.list.header:SetPoint("TOPLEFT", 0, -152)
    led.list.header:SetPoint("TOPRIGHT", -16, -152)
    led.list.area:SetPoint("BOTTOMRIGHT", -16, 0)
    led.empty = UI.Text(view, 13, "CENTER", UI.MUTED)
    led.empty:SetPoint("TOP", led.list.header, "BOTTOM", 0, -50)
    led.empty:SetText(L["Nothing recorded in this period yet."])
end
