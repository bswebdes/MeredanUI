-- Trade window (WoW Forever) in mUI style: two columns (player / target) with gold, 6 item slots and
-- the "will not be traded" slot. Offering gold is protected for addons (C_TradeInfo.SetTradeMoney etc.)
-- and TradePlayerInputMoneyFrame is forbidden. So Blizzard's TradeFrame stays open with everything
-- hidden except the gold input. Our window is a TradeFrame child on top; over the gold input we draw
-- three mouse-transparent fields (clicks reach the real input) showing GetPlayerTradeMoney
-- (PLAYER_TRADE_MONEY fires on every keystroke).
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT, PAD = 560, 520, 18
local COL_GAP = 16
local COL = (WIDTH - 2 * PAD - COL_GAP) / 2
local GOLD_Y = 76                     -- gold field top edge (from top)
local CARD_H, CARD_GAP = 40, 6
local ITEMS_Y = GOLD_Y + 32
local MAX_ITEMS = MAX_TRADABLE_ITEMS or 6
local ENCHANT = TRADE_ENCHANT_SLOT or 7
-- Positions of the three inputs in Blizzard's gold field (MoneyInputFrame_SetCompact(self, 62, 7, 35))
local FIELDS = { { x = 0, w = 62 }, { x = 72, w = 35 }, { x = 117, w = 35 } }
local COIN = { { 0.85, 0.69, 0.29 }, { 0.72, 0.74, 0.77 }, { 0.75, 0.48, 0.27 } }

local window
local cards = { player = {}, target = {} }
local fields = {}
local focusField, caretTime = nil, 0

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.tradeWindow ~= false and TradeFrame and TradePlayerInputMoneyFrame
end

local function Split(copper)
    copper = copper or 0
    return math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
end

-- Slots ---------------------------------------------------------------------------------------

local function Card(side, id, x, y)
    local UI = ns.UI
    local card = CreateFrame("Button", nil, window)
    card:SetSize(COL, CARD_H)
    card:SetPoint("TOPLEFT", x, -y)
    card:SetFrameLevel(TradeFrame:GetFrameLevel() + 10)
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card:RegisterForDrag("LeftButton")
    card.bg = UI.Box(card, { 0.098, 0.098, 0.106, 1 })
    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(CARD_H - 8, CARD_H - 8)
    holder:SetPoint("LEFT", 4, 0)
    ns.AddSlotBackground(holder)
    card.border = ns.AddBorder(holder)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = ns.CreateText(holder, 11, "RIGHT", "OUTLINE")
    card.count:SetPoint("BOTTOMRIGHT", -2, 2)
    card.name = UI.Text(card, 13, "LEFT")
    card.name:SetPoint("LEFT", holder, "RIGHT", 10, 0)
    card.name:SetPoint("RIGHT", -8, 0)
    card.name:SetWordWrap(false)
    card.side, card.id = side, id
    local function Link()
        if side == "player" then return GetTradePlayerItemLink(id) end
        return GetTradeTargetItemLink(id)
    end
    card:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.133, 0.133, 0.149, 1)
        if not self.filled then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if side == "player" then GameTooltip:SetTradePlayerItem(id) else GameTooltip:SetTradeTargetItem(id) end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.098, 0.098, 0.106, 1)
        GameTooltip:Hide()
    end)
    card:SetScript("OnClick", function()
        if IsModifiedClick() and HandleModifiedItemClick(Link()) then return end
        if side == "player" then ClickTradeButton(id) end -- ClickTargetTradeButton is protected
    end)
    if side == "player" then
        card:SetScript("OnDragStart", function() ClickTradeButton(id) end)
        card:SetScript("OnReceiveDrag", function() ClickTradeButton(id) end)
    end
    cards[side][id] = card
    return card
end

local function FillCard(card)
    local name, texture, count, quality, enchantment
    if card.side == "player" then
        name, texture, count, quality, enchantment = GetTradePlayerItemInfo(card.id)
    else
        local _
        name, texture, count, quality, _, enchantment = GetTradeTargetItemInfo(card.id)
    end
    card.filled = texture ~= nil
    card.icon:SetTexture(texture)
    card.icon:SetShown(texture ~= nil)
    card.count:SetText(count and count > 1 and count or "")
    local edge = (texture and quality and quality >= Enum.ItemQuality.Uncommon) and { C_Item.GetItemQualityColor(quality) } or { 0, 0, 0 }
    for _, e in ipairs(card.border) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
    if card.id == ENCHANT and name then
        card.name:SetText(enchantment and ("|cff1eff00" .. enchantment .. "|r") or (TRADEFRAME_NOT_MODIFIED_TEXT or ""))
        card.name:SetTextColor(1, 1, 1)
    else
        card.name:SetText(name or "")
        local r, g, b = C_Item.GetItemQualityColor(name and quality or 1) -- returns 4 values (4th is a hex string)
        card.name:SetTextColor(r or 1, g or 1, b or 1)
    end
end

-- Gold field (over Blizzard's real input) -------------------------------------------------------

local function UpdateMoney()
    local g, s, c = Split(GetPlayerTradeMoney())
    for i, value in ipairs({ g, s, c }) do
        local field = fields[i]
        local caret = focusField == i and (math.floor(caretTime * 2) % 2 == 0) and (ns.UI.ACCENT_HEX .. "|||r") or ""
        field.text:SetText((value > 0 or focusField == i) and (value > 0 and value or "") .. caret or "0")
        field.text:SetTextColor(unpack(value > 0 and ns.UI.TEXT or ns.UI.MUTED))
        for _, e in ipairs(field.focus) do e:SetShown(focusField == i) end
    end
    -- Coin atlases instead of a bullet glyph (Expressway lacks it, renders as a box)
    local tg, ts, tc = Split(GetTargetTradeMoney())
    window.targetMoney:SetText(("%d |A:coin-gold:12:12|a   %d |A:coin-silver:12:12|a   %d |A:coin-copper:12:12|a"):format(tg, ts, tc))
end

local function CreateMoneyFields(parent, x, y)
    local UI = ns.UI
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetPoint("TOPLEFT", x, -y)
    overlay:SetSize(152, 20)
    overlay:SetFrameLevel(TradeFrame:GetFrameLevel() + 20) -- above Blizzard's input, no mouse
    overlay:EnableMouse(false)
    -- Opaque cover: Blizzard's input borders stick out a few pixels past our fields
    local cover = overlay:CreateTexture(nil, "BACKGROUND")
    cover:SetPoint("TOPLEFT", -8, 5)
    cover:SetPoint("BOTTOMRIGHT", 12, -5)
    local c = ns.STYLE.panelColor
    cover:SetColorTexture(c[1], c[2], c[3], 1)
    for i, info in ipairs(FIELDS) do
        local field = CreateFrame("Frame", nil, overlay)
        field:SetPoint("TOPLEFT", info.x, 0)
        field:SetSize(info.w, 20)
        field:EnableMouse(false)
        UI.Box(field, UI.FIELD)
        field.focus = ns.AddBorder(field, true)
        for _, e in ipairs(field.focus) do
            e:SetVertexColor(unpack(UI.ACCENT))
            e:Hide()
        end
        local dot = field:CreateTexture(nil, "OVERLAY")
        dot:SetSize(11, 11)
        dot:SetPoint("RIGHT", -4, 0)
        if not dot:SetAtlas(({ "coin-gold", "coin-silver", "coin-copper" })[i]) then
            dot:SetTexture("Interface\\COMMON\\Indicator-Gray")
            dot:SetVertexColor(unpack(COIN[i]))
        end
        field.text = UI.Text(field, 12, "RIGHT")
        field.text:SetPoint("RIGHT", dot, "LEFT", -3, 0)
        fields[i] = field
    end
    overlay:SetScript("OnUpdate", function(_, elapsed)
        if not focusField then return end
        caretTime = caretTime + elapsed
        UpdateMoney()
    end)
    -- Fake the focus: the real input is unreadable for addons, so track where the user clicked
    overlay:RegisterEvent("GLOBAL_MOUSE_DOWN")
    overlay:SetScript("OnEvent", function()
        if not window:IsVisible() then return end
        focusField = nil
        for i, field in ipairs(fields) do
            if field:IsMouseOver() then focusField = i end
        end
        caretTime = 0
        UpdateMoney()
    end)
end

-- Build -----------------------------------------------------------------------------------------

local function Refresh()
    if not (window and window:IsVisible()) then return end
    for _, side in ipairs({ "player", "target" }) do
        for id = 1, ENCHANT do FillCard(cards[side][id]) end
    end
    window.playerName:SetText(GetUnitName("player"))
    window.targetName:SetText(GetUnitName("NPC") or "")
    SetPortraitTexture(window.playerPortrait, "player")
    SetPortraitTexture(window.targetPortrait, "NPC")
    window.warning:SetShown(C_TradeInfo.ShouldShowTradeOfferWarning and C_TradeInfo.ShouldShowTradeOfferWarning() or false)
    UpdateMoney()
end

local function SetAccept(player, target)
    local UI = ns.UI
    for side, on in pairs({ player = player == 1, target = target == 1 }) do
        local column = window[side .. "Column"]
        for _, e in ipairs(column.edges) do
            e:SetVertexColor(on and 0.12 or 0, on and 1 or 0, 0, on and 0.8 or 0)
        end
        window[side .. "Ready"]:SetShown(on)
    end
    window.accept:SetEnabled(player ~= 1)
    window.accept.Text:SetTextColor(unpack(player == 1 and UI.MUTED or UI.ACCENT))
end

local function Header(x, nameKey, portraitKey, readyKey)
    local UI = ns.UI
    local holder = CreateFrame("Frame", nil, window)
    holder:SetSize(40, 40)
    holder:SetPoint("TOPLEFT", x, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    window[portraitKey] = holder:CreateTexture(nil, "ARTWORK")
    window[portraitKey]:SetAllPoints()
    window[portraitKey]:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    window[nameKey] = UI.Text(window, 14, "LEFT")
    window[nameKey]:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -4)
    window[nameKey]:SetWidth(COL - 60)
    window[nameKey]:SetWordWrap(false)
    -- "ready" with a check icon (Expressway has no check mark glyph)
    local ready = CreateFrame("Frame", nil, window)
    ready:SetSize(80, 14)
    ready:SetPoint("TOPLEFT", window[nameKey], "BOTTOMLEFT", 0, -5)
    local tick = UI.Icon(ready, "Check", 12, { 0.12, 1, 0 })
    tick:SetPoint("LEFT")
    local text = UI.Text(ready, 12, "LEFT", { 0.12, 1, 0 })
    text:SetPoint("LEFT", tick, "RIGHT", 4, 0)
    text:SetText(L["ready"])
    ready:Hide()
    window[readyKey] = ready
end

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUITrade", TradeFrame)
    window:SetSize(WIDTH, HEIGHT)
    -- Fixed spot like the other windows (above chat). Blizzard's invisible TradeFrame is pinned to our
    -- window (see PinTradeFrame) so its gold input (TradeFrame TOPLEFT +11/-61) lies exactly under
    -- our fields (PAD/-GOLD_Y)
    window:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(90))
    ns.layoutFrames.trade = window
    window:SetFrameLevel(math.max(TradeFrame:GetFrameLevel() - 1, 0)) -- background below Blizzard's input
    window:EnableMouse(true) -- catch clicks outside TradeFrame (else they hit the world)
    UI.Box(window, ns.STYLE.panelColor, true)
    ns.RuneFrame(window)

    local left, right = PAD, PAD + COL + COL_GAP
    Header(left, "playerName", "playerPortrait", "playerReady")
    Header(right, "targetName", "targetPortrait", "targetReady")
    local close = UI.IconButton(window, "Close", function() CloseTrade() end, 26)
    close:SetPoint("TOPRIGHT", -PAD, -PAD)
    close:SetFrameLevel(TradeFrame:GetFrameLevel() + 10)

    -- Column border (green once that side has accepted)
    for side, x in pairs({ player = left, target = right }) do
        local column = CreateFrame("Frame", nil, window)
        column:SetPoint("TOPLEFT", x - 6, -(GOLD_Y - 8))
        column:SetSize(COL + 12, HEIGHT - GOLD_Y - 54)
        column:SetFrameLevel(TradeFrame:GetFrameLevel() + 25) -- above the gold cover (+20), no mouse
        column:EnableMouse(false)
        column.edges = ns.AddBorder(column)
        for _, e in ipairs(column.edges) do e:SetVertexColor(0, 0, 0, 0) end
        window[side .. "Column"] = column
    end

    CreateMoneyFields(window, left, GOLD_Y)
    window.targetMoney = UI.Text(window, 13, "LEFT")
    window.targetMoney:SetPoint("TOPLEFT", right, -GOLD_Y - 3)

    for id = 1, MAX_ITEMS do
        local y = ITEMS_Y + (id - 1) * (CARD_H + CARD_GAP)
        Card("player", id, left, y)
        Card("target", id, right, y)
    end
    local enchantY = ITEMS_Y + MAX_ITEMS * (CARD_H + CARD_GAP) + 22
    for side, x in pairs({ player = left, target = right }) do
        local label = UI.Text(window, 11, "LEFT", UI.MUTED)
        label:SetPoint("TOPLEFT", x, -(enchantY - 16))
        label:SetText(TRADEFRAME_ENCHANT_SLOT_LABEL or L["Will not be traded"])
        Card(side, ENCHANT, x, enchantY)
    end

    local cancel = UI.Button(window, CANCEL or L["Cancel"], function()
        if TradeFrame.acceptState == 1 then CancelTradeAccept() else CloseTrade() end
    end, 110)
    cancel:SetHeight(30)
    cancel:SetPoint("BOTTOMRIGHT", -PAD, 16)
    cancel:SetFrameLevel(TradeFrame:GetFrameLevel() + 10)
    window.accept = UI.Button(window, TRADE or L["Trade"], function() AcceptTrade() end, 120)
    window.accept:SetHeight(30)
    window.accept:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    window.accept:SetFrameLevel(TradeFrame:GetFrameLevel() + 10)
    for _, e in ipairs(ns.AddBorder(window.accept, true)) do e:SetVertexColor(unpack(UI.ACCENT)) end
    window.accept.Text:SetTextColor(unpack(UI.ACCENT))
    window.warning = UI.Text(window, 12, "LEFT", { 1, 0.5, 0.3 })
    window.warning:SetPoint("BOTTOMLEFT", PAD, 24)
    window.warning:SetPoint("RIGHT", window.accept, "LEFT", -10, 0)
    window.warning:SetText(L["The other player changed the offer."])
    window.warning:Hide()

    window:HookScript("OnShow", function()
        focusField = nil
        SetAccept(0, 0)
        Refresh()
    end)
end

-- Pin TradeFrame to our window. Blizzard's panel manager repositions it on open - snap back right
-- away (hooksecurefunc only, no Blizzard function replaced)
local pinning
local function PinTradeFrame()
    if pinning then return end
    pinning = true
    TradeFrame:ClearAllPoints()
    TradeFrame:SetPoint("TOPLEFT", window, "TOPLEFT", PAD - 11, 61 - GOLD_Y)
    pinning = false
end

-- Make Blizzard's trade frame invisible: regions at alpha 0, children parked - only the protected gold
-- input and our window remain. TradeFrame stays open and clickable (dropping cursor items or gold).
local function HideBlizzard()
    local hidden = CreateFrame("Frame")
    hidden:Hide()
    for _, region in ipairs({ TradeFrame:GetRegions() }) do region:SetAlpha(0) end
    for _, child in ipairs({ TradeFrame:GetChildren() }) do
        if child ~= TradePlayerInputMoneyFrame and child ~= window then
            pcall(child.SetParent, child, hidden)
        end
    end
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    HideBlizzard()
    PinTradeFrame()
    hooksecurefunc(TradeFrame, "SetPoint", function() if not pinning then PinTradeFrame() end end)
    for _, event in ipairs({ "TRADE_SHOW", "TRADE_UPDATE", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED",
        "GET_ITEM_INFO_RECEIVED", "TRADE_UPDATE_WARNINGS" }) do
        ns:On(event, function() C_Timer.After(0, Refresh) end)
    end
    ns:On("PLAYER_TRADE_MONEY", function() if window:IsVisible() then UpdateMoney() end end)
    ns:On("TRADE_MONEY_CHANGED", function() if window:IsVisible() then UpdateMoney() end end)
    ns:On("TRADE_ACCEPT_UPDATE", function(_, player, target) SetAccept(player, target) end)
end)
