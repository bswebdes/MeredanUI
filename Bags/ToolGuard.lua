-- Protects profession tools from accidental deletion (setting "Bags > Protect profession tools"):
--   on (default): deletion is cancelled, the tool stays in the bag and an alert is shown.
--   off:          Blizzard's delete dialog gets a big red "PROFESSION TOOL!" banner.
-- Detection: fixed list of tools (Classic/Forever) plus all fishing poles.
local _, ns = ...
local L = ns.L

local TOOLS = {
    [7005] = true,  -- Skinning Knife
    [2901] = true,  -- Mining Pick
    [5956] = true,  -- Blacksmith Hammer
    [6219] = true,  -- Arclight Spanner
    [10498] = true, -- Gyromatic Micro-Adjustor
    [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true, -- Runed rods (Enchanting)
    [5060] = true,  -- Thieves' Tools (Lockpicking)
    [4471] = true,  -- Flint and Tinder (own cooking fire)
    [9149] = true,  -- Philosopher's Stone (alchemy transmutes)
    [6256] = true, [6365] = true, [6366] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true, -- fishing poles
}
local FISHING_POLE_CLASS, FISHING_POLE_SUBCLASS = 2, 20

local DIALOGS = { "DELETE_ITEM", "DELETE_GOOD_ITEM", "DELETE_QUEST_ITEM", "DELETE_GOOD_QUEST_ITEM", "DELETE_GOOD_ITEM_GAMEPAD" }

local function IsTool(itemID)
    if not itemID then return false end
    if TOOLS[itemID] then return true end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    return classID == FISHING_POLE_CLASS and subclassID == FISHING_POLE_SUBCLASS
end
ns.IsProfessionTool = IsTool

local function CursorItem()
    local kind, itemID = GetCursorInfo()
    if kind == "item" then return itemID end
end

-- Own alert: slightly smaller than raid warnings, slightly below Blizzard's error line,
-- with a soft fade in/out (no pulse).
local alert
local function Alert(text)
    if not alert then
        alert = CreateFrame("Frame", nil, UIParent)
        alert:SetFrameStrata("HIGH")
        alert:SetSize(900, 60)
        alert:SetPoint("TOP", 0, -230)
        alert.text = alert:CreateFontString(nil, "OVERLAY")
        ns.SetFont(alert.text, 20, "OUTLINE", "bold")
        alert.text:SetPoint("TOP")
        alert.text:SetWidth(900)
        alert.text:SetSpacing(3)
        alert.text:SetTextColor(1, 0.35, 0.3)
        alert.anim = alert:CreateAnimationGroup()
        local fadeIn = alert.anim:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0) fadeIn:SetToAlpha(1) fadeIn:SetDuration(0.25) fadeIn:SetOrder(1)
        local fadeOut = alert.anim:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1) fadeOut:SetToAlpha(0) fadeOut:SetDuration(0.8) fadeOut:SetStartDelay(3) fadeOut:SetOrder(2)
        alert.anim:SetScript("OnFinished", function() alert:Hide() end)
    end
    alert.text:SetText(text)
    alert.anim:Stop()
    alert:Show()
    alert.anim:Play()
    PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE or 857)
end

-- warning banner above the delete dialog
local banner
local function ShowBanner(dialog, itemName)
    if not banner then
        local UI = ns.UI
        banner = CreateFrame("Frame", nil, UIParent)
        banner:SetFrameStrata("FULLSCREEN_DIALOG")
        banner:SetHeight(58)
        local bg = banner:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.55, 0.05, 0.05, 0.95)
        ns.AddBorder(banner)
        for _, edge in ipairs(ns.AddBorder(banner, true, 2)) do edge:SetVertexColor(1, 0.35, 0.3) end
        local icon = banner:CreateTexture(nil, "ARTWORK")
        icon:SetSize(30, 30)
        icon:SetPoint("LEFT", 12, 0)
        icon:SetAtlas("services-icon-warning")
        banner.title = UI.Text(banner, 16, "LEFT", { 1, 0.95, 0.9 })
        banner.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 2)
        banner.title:SetPoint("RIGHT", -12, 0)
        banner.text = UI.Text(banner, 12, "LEFT", { 1, 0.8, 0.75 })
        banner.text:SetPoint("TOPLEFT", banner.title, "BOTTOMLEFT", 0, -4)
        banner.text:SetPoint("RIGHT", -12, 0)
        banner:SetScript("OnUpdate", function(self)
            if not (self.dialog and self.dialog:IsShown()) then self:Hide() end
        end)
    end
    banner.dialog = dialog
    banner.title:SetText(L["PROFESSION TOOL!"])
    banner.text:SetText(L["%s is needed for your profession. Really delete it?"]:format(itemName or ""))
    banner:ClearAllPoints()
    banner:SetPoint("BOTTOMLEFT", dialog, "TOPLEFT", 0, 6)
    banner:SetPoint("BOTTOMRIGHT", dialog, "TOPRIGHT", 0, 6)
    banner:Show()
    PlaySound(SOUNDKIT.RAID_WARNING or 8959)
end

local function VisibleDeleteDialog()
    for _, which in ipairs(DIALOGS) do
        local dialog = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
        if dialog then return dialog, which end
    end
end

ns:On("DELETE_ITEM_CONFIRM", function(_, itemName)
    local itemID = CursorItem()
    if not IsTool(itemID) then return end
    -- Blizzard shows the dialog during this same event; one frame later it is guaranteed to exist
    C_Timer.After(0, function()
        local dialog, which = VisibleDeleteDialog()
        if ns.db.protectTools ~= false then
            if which then StaticPopup_Hide(which) end
            ClearCursor() -- tool stays in the bag
            Alert(L["%s is a profession tool and protected."]:format(itemName or ""))
        elseif dialog then
            ShowBanner(dialog, itemName)
        end
    end)
end)

-- Vendor sales have no dialog to intercept. If a tool lands in the buyback list, buy it back
-- immediately (costs exactly the sale price, i.e. nothing) and warn.
-- Intentional sale (e.g. a spare fishing pole): Shift+right-click in the bag.
local buyingBack, allowSale = false, false

function ns.SellToolAnyway(bag, slot)
    allowSale = true
    C_Container.UseContainerItem(bag, slot)
    C_Timer.After(1, function() allowSale = false end)
end

-- Only react to a fresh sale (buyback list grew, or is full and its newest entry changed).
-- Our own buyback shrinks the list, so it triggers no alert.
local lastCount, lastLink = 0, nil
local function Snapshot()
    lastCount = GetNumBuybackItems and GetNumBuybackItems() or 0
    lastLink = lastCount > 0 and GetBuybackItemLink(lastCount) or nil
end
ns:On("MERCHANT_SHOW", Snapshot)

ns:On("MERCHANT_UPDATE", function()
    local prevCount, prevLink = lastCount, lastLink
    Snapshot()
    if ns.db.protectTools == false or buyingBack then return end
    local count, link = lastCount, lastLink
    local sold = count > prevCount or (count == prevCount and count >= (BUYBACK_ITEMS_PER_PAGE or 12) and link ~= prevLink)
    if not sold or not link then return end
    local itemID = C_Item.GetItemInfoInstant(link)
    if not IsTool(itemID) then return end
    if allowSale then allowSale = false return end
    buyingBack = true
    BuybackItem(count)
    C_Timer.After(0.5, function() buyingBack = false Snapshot() end)
    Alert(L["%s is a profession tool and protected."]:format(C_Item.GetItemNameByID(itemID) or link)
        .. "\n" .. L["Shift+right-click sells it anyway."])
end)
