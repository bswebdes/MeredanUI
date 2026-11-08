-- Berufswerkzeug schützen (Benny 2026-11-07: Kürschnermesser, Schmiedehammer usw. versehentlich
-- gelöscht). Zwei Stufen, Einstellung „Bags > Berufswerkzeug schützen“:
--   an (Standard): Löschen wird abgebrochen – Werkzeug zurück in die Tasche, deutlicher Hinweis.
--   aus:           Blizzards Lösch-Dialog bekommt ein großes rotes Warnband „Berufswerkzeug!“.
-- Erkennung: feste Liste der Werkzeuge (Classic/Forever) plus alle Angelruten.
local _, ns = ...
local L = ns.L

local TOOLS = {
    [7005] = true,  -- Kürschnermesser
    [2901] = true,  -- Spitzhacke
    [5956] = true,  -- Schmiedehammer
    [6219] = true,  -- Bogenlichtschraubenschlüssel
    [10498] = true, -- Gyromatischer Mikrojustierer
    [6218] = true, [6339] = true, [11130] = true, [11145] = true, [16207] = true, -- Runenverzierte Ruten (Verzauberkunst)
    [5060] = true,  -- Diebeswerkzeug (Schlossknacken)
    [4471] = true,  -- Zunderkästchen (Kochen am eigenen Feuer)
    [9149] = true,  -- Stein der Weisen (Alchemie-Transmutationen)
    [6256] = true, [6365] = true, [6366] = true, [6367] = true, [12225] = true, [19022] = true, [19970] = true, -- Angelruten
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

-- Eigener Hinweis: etwas kleiner als die Schlachtzugswarnung, etwas tiefer als Blizzards
-- Fehlerzeile, nur sanft ein- und ausblenden – kein Hochpulsieren (Benny 2026-11-07).
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

-- Warnband über dem Lösch-Dialog
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
    -- Blizzard zeigt den Dialog im selben Ereignis – einen Takt später ist er sicher da
    C_Timer.After(0, function()
        local dialog, which = VisibleDeleteDialog()
        if ns.db.protectTools ~= false then
            if which then StaticPopup_Hide(which) end
            ClearCursor() -- Werkzeug bleibt in der Tasche
            Alert(L["%s is a profession tool and protected."]:format(itemName or ""))
        elseif dialog then
            ShowBanner(dialog, itemName)
        end
    end)
end)

-- Verkaufen beim Händler: dort gibt es keinen Dialog zum Abfangen. Landet ein Werkzeug in der
-- Rückkauf-Liste, sofort zurückkaufen (kostet genau den Verkaufserlös, also nichts) und warnen.
-- Absichtlich verkaufen (z. B. die zweite Angel): Shift+Rechtsklick in der Tasche (Benny 2026-11-07).
local buyingBack, allowSale = false, false

function ns.SellToolAnyway(bag, slot)
    allowSale = true
    C_Container.UseContainerItem(bag, slot)
    C_Timer.After(1, function() allowSale = false end)
end

-- Nur auf einen frischen Verkauf reagieren (Rückkauf-Liste wird länger bzw. ist voll und vorne
-- kam etwas Neues dazu). Eigenes Zurückkaufen macht die Liste kürzer → kein Hinweis.
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
