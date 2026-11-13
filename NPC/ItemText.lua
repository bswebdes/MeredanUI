-- Reading window (letters, seals, books, signs): replaces Blizzard's ItemTextFrame in quest window style.
-- Blizzard's frame stays parked invisibly and still controls opening. Text may be HTML (books with
-- headings), hence SimpleHTML. Paging buttons only show for multi-page texts. Toggle: questWindow.
local _, ns = ...

local WIDTH, PAD = 520, 18
local BOOK_ICON = "Interface\\QuestFrame\\UI-QuestLog-BookIcon"

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, html, prevButton, nextButton, pageText

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.questWindow ~= false
end

-- Item icon if the game knows the item by name (bag item), otherwise a book
local function ItemIcon(name)
    if name and C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, name)
        if ok and icon then return icon end
    end
    return BOOK_ICON
end

local function SetupFonts()
    local text, gold = ns.PARCHMENT_TEXT, { 1, 0.82, 0 }
    for tag, size in pairs({ P = 14, H1 = 22, H2 = 18, H3 = 16 }) do
        local role = tag ~= "P" and "bold" or nil
        html:SetFont(tag, ns.FontFor(role), ns.FontPx(size), "")
        local color = tag == "P" and text or gold
        html:SetTextColor(tag, color[1], color[2], color[3])
        html:SetSpacing(tag, 4)
    end
end

local function Layout()
    local page, hasNext = ItemTextGetPage() or 1, ItemTextHasNextPage()
    local title = ItemTextGetItem() or ""
    window:SetNpc(nil, title, "", ItemIcon(title))

    local text = ItemTextGetText() or ""
    local creator = ItemTextGetCreator()
    if creator then text = text .. "\n\n" .. ITEM_TEXT_FROM .. "\n" .. creator end
    html:SetWidth(list:GetWidth())
    SetupFonts()
    html:SetText(text)
    html:SetHeight(math.max(html:GetContentHeight(), 1))
    list:SetContentHeight(html:GetContentHeight() + 8)
    list:ScrollToTop()

    local paging = hasNext or page > 1
    prevButton:SetShown(paging)
    nextButton:SetShown(paging)
    pageText:SetShown(paging)
    prevButton:SetEnabled(page > 1)
    nextButton:SetEnabled(hasNext and true or false)
    pageText:SetText(page)
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIItemText", WIDTH, ns.NPC_HEIGHT, "itemtext")
    ns.WatchBlizzardFrame(window, function() return ItemTextFrame end)
    -- Title like the quest window: large gold text, centered on the icon
    window.npcName:ClearAllPoints()
    window.npcName:SetPoint("LEFT", window.header, "TOPLEFT", PAD + 46 + 14, -PAD - 23)
    window.npcName:SetPoint("RIGHT", window.header, "RIGHT", -PAD - 36, 0)
    ns.SetFont(window.npcName, 17, "", "display")
    window.npcName:SetTextColor(1, 0.82, 0)

    local paper = ns.CreateParchmentPanel(window)
    paper:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 22)
    paper:SetPoint("BOTTOMRIGHT", -PAD, 56)
    list = UI.ScrollArea(paper)
    list:SetPoint("TOPLEFT", 34, -30)
    list:SetPoint("BOTTOMRIGHT", -40, 28)
    html = CreateFrame("SimpleHTML", nil, list.child)
    html:SetPoint("TOPLEFT")

    -- Paging bottom right: [<] page [>]
    nextButton = UI.ArrowButton(window, "right", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ItemTextNextPage()
    end, 30)
    nextButton:SetPoint("BOTTOMRIGHT", -PAD, 12)
    pageText = UI.Text(window, 14, "CENTER")
    pageText:SetWidth(36)
    pageText:SetPoint("RIGHT", nextButton, "LEFT", -4, 0)
    prevButton = UI.ArrowButton(window, "left", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ItemTextPrevPage()
    end, 30)
    prevButton:SetPoint("RIGHT", pageText, "LEFT", -4, 0)

    window:HookScript("OnHide", function()
        if ItemTextFrame:IsShown() then CloseItemText() end
    end)
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not ItemTextFrame then return end
    CreateWindow()
    -- Park invisibly: Blizzard only checks IsShown
    ItemTextFrame:SetParent(hidden)
    ns:On("ITEM_TEXT_READY", function()
        C_Timer.After(0, function()
            if not ItemTextFrame:IsShown() then return end -- Blizzard did not open it
            if not window:IsShown() then window:Show() end
            Layout()
        end)
    end)
    ns:On("ITEM_TEXT_CLOSED", function() if window:IsShown() then window:Hide() end end)
end)
