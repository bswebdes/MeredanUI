-- Loot window in mUI style replacing Blizzard's loot frame; opens at the cursor.
--
--   +- Kobold Miner ------------- x -+   <- title: target name (else "Loot")
--   | [#] Linen Cloth           x3   |   <- icon border and name in quality color
--   | [#] Sword of Slumber      ^    |   <- ^ = upgrade (as in bags), ! = quest item
--   | [o] 12 Silver 40 Copper        |
--   +--------------------------------+
--
-- Click loots (LootSlot), Shift/Ctrl-click as usual (link, dressing room), Esc closes.
-- Locked slots (others' loot) are red. With auto loot the window only appears if something is
-- left after a short delay (full bags, locked ...). Blizzard's frame stays unused: its loot events
-- are unregistered (like ElvUI). Settings > Bags.
local _, ns = ...
local L = ns.L

local WIDTH = 280
local ROW = 40          -- row height
local ICON = 34
local PAD = 7
local TITLE = 28

local window
local rows = {}

local function Enabled() return ns.db.lootWindow ~= false end

local function QualityColor(quality)
    local r, g, b = C_Item.GetItemQualityColor(quality or Enum.ItemQuality.Common)
    return r or 1, g or 1, b or 1
end

-- Row --------------------------------------------------------------------------------------

local function RowOnEnter(row)
    row.hover:Show()
    local slotType = GetLootSlotType(row.slot)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if slotType == Enum.LootSlotType.Currency then
        GameTooltip:SetLootCurrency(row.slot)
    elseif slotType == Enum.LootSlotType.Item then
        GameTooltip:SetLootItem(row.slot)
        ns.ShowItemCompare(GameTooltip)
    else
        GameTooltip:Hide()
    end
    CursorUpdate(row)
    row.UpdateTooltip = RowOnEnter -- refresh when Shift changes while hovering
end

local function RowOnLeave(row)
    row.hover:Hide()
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    ResetCursor()
end

local function RowOnClick(row)
    if IsModifiedClick() then
        HandleModifiedItemClick(GetLootSlotLink(row.slot))
    else
        StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
        LootSlot(row.slot)
    end
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, window)
    row:SetHeight(ns.Snap(ROW))
    row:SetPoint("TOPLEFT", ns.Snap(PAD), -ns.Snap(TITLE + (index - 1) * ROW))
    row:SetPoint("RIGHT", -ns.Snap(PAD), 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.08)
    row.hover:Hide()

    row.iconFrame = CreateFrame("Frame", nil, row)
    row.iconFrame:SetSize(ns.Snap(ICON), ns.Snap(ICON))
    row.iconFrame:SetPoint("LEFT", 2, 0)
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.border = ns.AddBorder(row.iconFrame)
    row.count = ns.CreateText(row.iconFrame, 13, "RIGHT", "OUTLINE")
    row.count:SetPoint("BOTTOMRIGHT", -1, 2)
    row.quest = ns.CreateText(row.iconFrame, 20, "LEFT", "OUTLINE")
    row.quest:SetPoint("TOPLEFT", 2, -1)
    row.quest:SetText("!")
    row.quest:SetTextColor(1, 0.82, 0)

    row.upgrade = ns.UI.Icon(row, "Upgrade", 18, ns.UPGRADE_COLOR or ns.UI.ACCENT)
    row.upgrade:SetPoint("RIGHT", -4, 0)
    row.name = ns.CreateText(row, 14, "LEFT")
    row.name:SetPoint("LEFT", row.iconFrame, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.upgrade, "LEFT", -4, 0)
    row.name:SetWordWrap(false)

    row:SetScript("OnEnter", RowOnEnter)
    row:SetScript("OnLeave", RowOnLeave)
    row:SetScript("OnClick", RowOnClick)
    rows[index] = row
    return row
end

local function FillRow(row, slot)
    row.slot = slot
    local texture, item, quantity, currencyID, quality, locked, isQuestItem, questID = GetLootSlotInfo(slot)
    if currencyID and CurrencyContainerUtil then
        item, texture, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, item, texture, quality)
    end
    local isMoney = GetLootSlotType(slot) == Enum.LootSlotType.Money
    row.icon:SetTexture(texture)
    row.name:SetText(isMoney and (item or ""):gsub("\n", " ") or item or "")
    local r, g, b = QualityColor(quality)
    if isMoney then r, g, b = 1, 0.82, 0 end
    row.name:SetTextColor(r, g, b)
    local colored = not isMoney and quality and quality >= Enum.ItemQuality.Uncommon
    for _, edge in ipairs(row.border) do
        if colored then edge:SetVertexColor(r, g, b, 1) else edge:SetVertexColor(unpack(ns.BORDER_COLOR)) end
    end
    row.count:SetText(quantity and quantity > 1 and quantity or "")
    row.quest:SetShown(isQuestItem or questID ~= nil)
    if locked then row.icon:SetVertexColor(0.9, 0.2, 0.2) else row.icon:SetVertexColor(1, 1, 1) end
    local link = not isMoney and GetLootSlotLink(slot)
    local upgrade = link and ns.UpgradePercent and ns.UpgradePercent(link)
    row.upgrade:SetShown(upgrade and upgrade >= 0.05 or false)
    row:Show()
end

-- Window -----------------------------------------------------------------------------------

local function CreateWindow()
    window = CreateFrame("Frame", "MeredanUILootFrame", UIParent)
    window:SetWidth(ns.Snap(WIDTH))
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    local bg = window:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddBorder(window)
    window.title = ns.UI.Text(window, 13, "LEFT", ns.UI.MUTED)
    window.title:SetPoint("TOPLEFT", ns.Snap(PAD + 2), -ns.Snap(8))
    window.title:SetPoint("RIGHT", -28, 0)
    window.title:SetWordWrap(false)
    local close = ns.UI.IconButton(window, "Close", function() window:Hide() end, 20)
    close:SetPoint("TOPRIGHT", -5, -4)
    -- closing ends looting (as Blizzard does)
    window:SetScript("OnHide", function()
        StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
        CloseLoot()
    end)
    tinsert(UISpecialFrames, "MeredanUILootFrame") -- Esc closes
    window:Hide()
end

local function Layout()
    local shown = 0
    for slot = 1, GetNumLootItems() do
        if GetLootSlotType(slot) ~= Enum.LootSlotType.None then
            shown = shown + 1
            FillRow(rows[shown] or CreateRow(shown), slot)
        end
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    window:SetHeight(ns.Snap(TITLE + math.max(shown, 1) * ROW + PAD))
    return shown
end

-- at the cursor (top edge slightly above), clamped to screen
local function PlaceAtCursor()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    window:ClearAllPoints()
    window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale - 20, y / scale + 16)
end

local function Title()
    if UnitExists("target") and UnitIsDead("target") then return UnitName("target") end
    if IsFishingLoot and IsFishingLoot() then return L["Fishing"] end
    return L["Loot"]
end

local function Open(autoLoot)
    if Layout() == 0 then
        if not autoLoot then CloseLoot() end
        return
    end
    window.title:SetText(Title())
    PlaceAtCursor()
    window:Show()
    window:Raise()
end

-- Loot events ------------------------------------------------------------------------------

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    -- keep Blizzard's frame from receiving loot events
    if LootFrame then
        LootFrame:UnregisterEvent("LOOT_OPENED")
        LootFrame:UnregisterEvent("LOOT_CLOSED")
    end

    ns:On("LOOT_OPENED", function(_, autoLoot)
        if autoLoot then
            -- auto loot takes everything: only show what is left afterwards
            C_Timer.After(0.3, function()
                if GetNumLootItems() > 0 then Open(true) end
            end)
        else
            Open(false)
        end
    end)
    ns:On("LOOT_SLOT_CLEARED", function()
        if window:IsShown() and Layout() == 0 then window:Hide() end
    end)
    ns:On("LOOT_SLOT_CHANGED", function() if window:IsShown() then Layout() end end)
    ns:On("LOOT_CLOSED", function()
        window:SetScript("OnHide", nil) -- loot already closed: avoid a second CloseLoot
        window:Hide()
        window:SetScript("OnHide", function()
            StaticPopup_Hide("CONFIRM_LOOT_DISTRIBUTION")
            CloseLoot()
        end)
        GameTooltip:Hide()
    end)
end)
