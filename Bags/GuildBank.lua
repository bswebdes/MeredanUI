-- Gildenbank (WoW Forever): eigenes Fenster im Taschen-Look wie die Bank (Bank.lua). Aufteilung wie
-- bei Blizzard – 98 Fächer je Fach in 7 Gruppen à 2×7, Fach-Reiter rechts, Log/Geldlog/Info –,
-- Optik wie unser Taschenfenster.
--
--   ┌ Gildenbank  Log  Geldlog  Info ───── Fach 1  Voller Zugriff [x] ┐ ┌──┐
--   │ [Suche .......................................................] │ │▣ │ Fach 1
--   │ [■][■]  [■][■]  [■][■]  [■][■]  [■][■]  [■][■]  [■][■]          │ ├──┤
--   │  … 7 Reihen …                                                   │ │+ │ Fach kaufen
--   │ Fach 1: 5 Stapel verbleibend             [Entnehmen][Einzahlen] │ └──┘
--   │ Verfügbarer Betrag: 12g                                  1.234g │
--   └─────────────────────────────────────────────────────────────────┘
--
-- Blizzards Gildenbankfenster wird nach dem Öffnen unsichtbar geparkt (wie Baganator) und beim
-- Schließen zurückgehängt; sein OnHide würde die Gildenbank schließen und wird deshalb entfernt. Fächer sind Blizzards
-- GuildBankItemButtonTemplate (Klick, Ziehen, Teilen, Tooltip wie gewohnt), im Look unserer Taschen.
-- Kaufen, Ein- und Auszahlen laufen über Blizzards eigene Dialoge.
local _, ns = ...
local L = ns.L

local SIZE, GAP, GROUP_GAP, PAD = 36, 6, 14, 14
local GROUPS, ROWS, PER_GROUP = 7, 7, 14
local SLOTS = 98
local GRID_WIDTH = GROUPS * (2 * SIZE + GAP) + (GROUPS - 1) * GROUP_GAP
local GRID_HEIGHT = ROWS * SIZE + (ROWS - 1) * GAP
local NEW_TAB_ICON = "Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab"

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, grid, searchBox, tabTitle, errorText
local logFrame, infoBox, infoSave, buyView
local limitText, availableText, guildMoneyText, withdrawButton, depositButton
local modeTabs, fachTabs, slots = {}, {}, {}
local mode = "bank" -- "bank", "log", "moneylog", "info"

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.bags ~= false
end

local function MaxTabs() return MAX_GUILDBANK_TABS or 8 end
local function MaxBuyTabs() return MAX_BUY_GUILDBANK_TABS or 6 end

-- Knopf-Look an/aus (UI.Button kennt keinen deaktivierten Zustand)
local function SetButtonEnabled(button, enabled)
    button:SetEnabled(enabled)
    button.Text:SetTextColor(unpack(enabled and ns.UI.TEXT or ns.UI.MUTED))
end

local function IsGear(link)
    if not link then return false end
    local classID = select(6, C_Item.GetItemInfoInstant(link))
    return classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
end

local function ApplySearch()
    local query = searchBox and searchBox:GetText():lower() or ""
    for _, button in ipairs(slots) do
        button:SetMatchesSearch(query == "" or (button.muiName or ""):find(query, 1, true) ~= nil)
    end
end

-- Zugriff -------------------------------------------------------------------------------------

local function FirstViewableTab()
    for i = 1, MaxTabs() do
        if select(3, GetGuildBankTabInfo(i)) then return i end
    end
end

local function NoViewableTabs()
    return GetNumGuildBankTabs() > 0 and not FirstViewableTab() and not IsGuildLeader()
end

local function AccessText(canDeposit, numWithdrawals)
    if not canDeposit and numWithdrawals == 0 then return GUILDBANK_TAB_LOCKED end
    if not canDeposit then return GUILDBANK_TAB_WITHDRAW_ONLY end
    if numWithdrawals == 0 then return GUILDBANK_TAB_DEPOSIT_ONLY end
    return GUILDBANK_TAB_FULL_ACCESS
end

-- Logs (wie Blizzard formatiert) ---------------------------------------------------------------

local function LogTime(year, month, day, hour)
    return GUILD_BANK_LOG_TIME:format(TimeUtil.GetRecentTimeDate(year, month, day, hour))
end

local function FillItemLog()
    logFrame:Clear()
    local tab = GetCurrentGuildBankTab()
    for i = 1, GetNumGuildBankTransactions(tab) do
        local kind, name, itemLink, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i)
        name = NORMAL_FONT_COLOR_CODE .. (name or UNKNOWN) .. FONT_COLOR_CODE_CLOSE
        local msg
        if kind == "deposit" then
            msg = GUILDBANK_DEPOSIT_FORMAT:format(name, itemLink)
            if count > 1 then msg = msg .. GUILDBANK_LOG_QUANTITY:format(count) end
        elseif kind == "withdraw" then
            msg = GUILDBANK_WITHDRAW_FORMAT:format(name, itemLink)
            if count > 1 then msg = msg .. GUILDBANK_LOG_QUANTITY:format(count) end
        elseif kind == "move" then
            msg = GUILDBANK_MOVE_FORMAT:format(name, itemLink, count, GetGuildBankTabInfo(tab1), GetGuildBankTabInfo(tab2))
        end
        if msg then logFrame:AddMessage(msg .. LogTime(year, month, day, hour)) end
    end
end

local MONEY_FORMATS = {
    deposit = "GUILDBANK_DEPOSIT_MONEY_FORMAT", withdraw = "GUILDBANK_WITHDRAW_MONEY_FORMAT",
    repair = "GUILDBANK_REPAIR_MONEY_FORMAT", withdrawForTab = "GUILDBANK_WITHDRAWFORTAB_MONEY_FORMAT",
    buyTab = "GUILDBANK_BUYTAB_MONEY_FORMAT", buyRename = "GUILDBANK_GUILD_RENAME_PURCHASE",
    refundRename = "GUILDBANK_GUILD_RENAME_REFUND",
}

local function FillMoneyLog()
    logFrame:Clear()
    for i = 1, GetNumGuildBankMoneyTransactions() do
        local kind, name, amount, year, month, day, hour = GetGuildBankMoneyTransaction(i)
        amount = amount or 0
        name = NORMAL_FONT_COLOR_CODE .. (name or UNKNOWN) .. FONT_COLOR_CODE_CLOSE
        local money = GetDenominationsFromCopper(amount)
        local msg
        if kind == "buyTab" and amount <= 0 then
            msg = GUILDBANK_UNLOCKTAB_FORMAT:format(name)
        elseif kind == "depositSummary" then
            msg = GUILDBANK_AWARD_MONEY_SUMMARY_FORMAT:format(money)
        elseif MONEY_FORMATS[kind] and _G[MONEY_FORMATS[kind]] then
            msg = _G[MONEY_FORMATS[kind]]:format(name, money)
        end
        if msg then logFrame:AddMessage(msg .. LogTime(year, month, day, hour)) end
    end
end

-- Aktualisieren -------------------------------------------------------------------------------

local function UpdateItems(tab)
    for i, button in ipairs(slots) do
        local texture, count, locked, _, quality = GetGuildBankItemInfo(tab, i)
        local link = texture and GetGuildBankItemLink(tab, i)
        SetItemButtonTexture(button, texture)
        if not texture then button.icon:Hide() end -- leer: unser Slot-Hintergrund
        SetItemButtonCount(button, count)
        SetItemButtonDesaturated(button, locked)
        SetItemButtonQuality(button, quality, link)
        if button.IconBorder then button.IconBorder:SetAlpha(0) end
        local info = texture and { quality = quality, hyperlink = link } or nil
        ns.DecorateItemButton(button, info, IsGear(link))
        button.muiName = link and (link:match("%[(.-)%]") or ""):lower() or ""
    end
    ApplySearch()
end

local function UpdateFachTabs()
    local numTabs, current = GetNumGuildBankTabs(), GetCurrentGuildBankTab()
    local buyIndex = numTabs < MaxBuyTabs() and IsGuildLeader() and numTabs + 1 or nil
    local shown = 0
    for i = 1, MaxTabs() do
        local tab = fachTabs[i]
        local name, icon, isViewable = GetGuildBankTabInfo(i)
        if i == buyIndex then
            tab.icon:SetTexture(NEW_TAB_ICON)
            tab.tooltip = BUY_GUILDBANK_TAB
            tab.usable = mode ~= "log" and mode ~= "moneylog" and mode ~= "info"
        elseif i <= numTabs then
            tab.icon:SetTexture(icon)
            tab.tooltip = (name and name ~= "") and name or GUILDBANK_TAB_NUMBER:format(i)
            tab.usable = isViewable and mode ~= "moneylog"
        else
            tab:Hide()
            tab.usable = nil
        end
        if tab.usable ~= nil then
            shown = shown + 1
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 4, -PAD - 58 - (shown - 1) * (SIZE + GAP))
            local active = i == current and tab.usable -- gesperrte Reiter (Kauf-Fach im Log) nie markiert
            tab.marker:SetShown(active)
            local shade = active and 1 or 0.6
            tab.icon:SetVertexColor(shade, shade, shade)
            tab.icon:SetDesaturated(not active) -- inaktive (und gesperrte) Reiter grau (wie überall)
            tab:Show()
        end
    end
end

local function UpdateMoney()
    local limit = GetGuildBankWithdrawMoney()
    if limit >= 0 then
        local amount = CanWithdrawGuildBankMoney() and GetGuildBankMoney() or 0
        limit = math.min(limit, amount)
        availableText:SetText((GUILDBANK_AVAILABLE_MONEY or "") .. " " .. GetMoneyString(limit, true))
        SetButtonEnabled(withdrawButton, limit > 0)
    else
        availableText:SetText((GUILDBANK_AVAILABLE_MONEY or "") .. " " .. (UNLIMITED or ""))
        SetButtonEnabled(withdrawButton, CanWithdrawGuildBankMoney())
    end
    guildMoneyText:SetText(GetMoneyString(GetGuildBankMoney(), true))
end

local function Update()
    if not (window and window:IsShown()) then return end
    local numTabs, current = GetNumGuildBankTabs(), GetCurrentGuildBankTab()
    local name, _, isViewable, canDeposit, numWithdrawals, remaining = GetGuildBankTabInfo(current)
    local isBuyTab = current > numTabs

    for key, tab in pairs(modeTabs) do
        local active = key == mode
        tab.text:SetTextColor(unpack(active and ns.UI.ACCENT or ns.UI.MUTED))
        tab.line:SetShown(active)
    end
    UpdateFachTabs()

    -- Titel rechts oben: nur Fachname und Zugriff eines echten Fachs (kein „Geldlog“, kein Kauf-Titel –
    -- das sagen schon die Reiter)
    local title
    if mode ~= "moneylog" and not isBuyTab and isViewable then
        name = (name and name ~= "") and name or GUILDBANK_TAB_NUMBER:format(current)
        title = name .. "  " .. AccessText(canDeposit, numWithdrawals)
    end
    tabTitle:SetText(title or "")

    -- Inhalt je Modus
    grid:Hide()
    logFrame:Hide()
    infoBox:GetParent():Hide()
    buyView:Hide()
    errorText:Hide()
    searchBox:SetShown(mode == "bank")
    if mode == "bank" then
        if NoViewableTabs() then
            errorText:SetText(NO_VIEWABLE_GUILDBANK_TABS)
            errorText:Show()
        elseif isBuyTab then
            if IsGuildLeader() then
                local cost = GetGuildBankTabCost()
                buyView.purchased:SetText(NUM_GUILDBANK_TABS_PURCHASED:format(numTabs, MaxBuyTabs()))
                buyView.cost:SetText(cost and GetMoneyString(cost, true) or "")
                local affordable = cost and GetGuildBankMoney() >= cost or false
                if affordable then
                    buyView.cost:SetTextColor(unpack(ns.UI.TEXT))
                else
                    buyView.cost:SetTextColor(1, 0.3, 0.3)
                end
                SetButtonEnabled(buyView.button, affordable)
                buyView:Show()
            else
                errorText:SetText(NO_GUILDBANK_TABS)
                errorText:Show()
            end
        else
            UpdateItems(current)
            grid:Show()
        end
    elseif mode == "log" or mode == "moneylog" then
        if mode == "log" and NoViewableTabs() then
            errorText:SetText(NO_VIEWABLE_GUILDBANK_LOGS)
            errorText:Show()
        else
            logFrame:Show()
        end
    elseif mode == "info" then
        local canEdit = CanEditGuildTabInfo(current)
        infoBox:EnableMouse(canEdit)
        infoBox:SetEnabled(canEdit)
        infoSave:SetShown(canEdit)
        infoBox:GetParent():Show()
    end

    -- unten: verbleibende Abhebungen dieses Fachs, Geld
    if (mode == "bank" or mode == "log") and isViewable and not isBuyTab then
        local stacks = remaining > 0 and STACKS:format(remaining) or (remaining == 0 and NONE or UNLIMITED)
        limitText:SetText(GUILDBANK_REMAINING_MONEY:format(name, stacks))
    else
        limitText:SetText("")
    end
    UpdateMoney()
end

local function SaveInfo()
    local tab = GetCurrentGuildBankTab()
    if infoBox:IsVisible() and CanEditGuildTabInfo(tab) and infoBox:GetText() ~= (infoBox.original or "") then
        SetGuildBankText(tab, infoBox:GetText())
        infoBox.original = infoBox:GetText()
    end
end

local function QueryCurrent()
    local tab = GetCurrentGuildBankTab()
    if mode == "bank" then
        QueryGuildBankTab(tab)
    elseif mode == "log" then
        QueryGuildBankTab(tab) -- für die verbleibenden Abhebungen
        QueryGuildBankLog(tab)
    elseif mode == "moneylog" then
        QueryGuildBankLog(MaxTabs() + 1)
    elseif mode == "info" then
        QueryGuildBankText(tab)
    end
end

local function SetMode(key)
    SaveInfo()
    mode = key
    if key == "log" or key == "moneylog" then logFrame:Clear() end
    -- im Log gibt es kein Kauf-Fach: auf Fach 1 wechseln
    if key ~= "bank" and GetCurrentGuildBankTab() > GetNumGuildBankTabs() and GetNumGuildBankTabs() > 0 then
        SetCurrentGuildBankTab(1)
    end
    QueryCurrent()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    Update()
end

local function SelectTab(i)
    SaveInfo()
    if GetCurrentGuildBankTab() ~= i then PlaySound(SOUNDKIT.GUILD_BANK_OPEN_BAG) end
    SetCurrentGuildBankTab(i)
    QueryCurrent()
    Update()
end

local function SelectAvailableTab()
    local current = GetCurrentGuildBankTab()
    if current <= GetNumGuildBankTabs() and not select(3, GetGuildBankTabInfo(current)) then
        local first = FirstViewableTab()
        if first then SetCurrentGuildBankTab(first) end
    end
end

-- Fach umbenennen/Symbol (Rechtsklick, mit Recht): Blizzards Auswahlfenster an unserem Fenster
local function EditTab(i)
    if not (GuildBankPopupFrame and CanEditGuildBankTabInfo() and i <= GetNumGuildBankTabs()) then return end
    SelectTab(i)
    GuildBankPopupFrame:SetParent(window)
    GuildBankPopupFrame.mode = IconSelectorPopupFrameModes.Edit
    GuildBankPopupFrame:Show()
    GuildBankPopupFrame:Update()
    GuildBankPopupFrame:ClearAllPoints()
    GuildBankPopupFrame:SetPoint("TOPLEFT", window, "TOPRIGHT", SIZE + 12, 0)
    GuildBankPopupFrame:SetFrameLevel(window:GetFrameLevel() + 50)
end

-- Fenster -------------------------------------------------------------------------------------

local function CreateFachTab(i)
    local tab = CreateFrame("Button", nil, window)
    tab:SetSize(SIZE, SIZE)
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetAllPoints()
    tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns.AddBorder(tab)
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.12)
    tab.marker = tab:CreateTexture(nil, "OVERLAY")
    tab.marker:SetColorTexture(unpack(ns.UI.ACCENT))
    tab.marker:SetPoint("TOPLEFT")
    tab.marker:SetPoint("BOTTOMLEFT")
    tab.marker:SetWidth(2 * ns.PixelSize())
    tab:SetScript("OnClick", function(_, mouse)
        if not tab.usable then return end
        if mouse == "RightButton" then EditTab(i) else SelectTab(i) end
    end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltip or "", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:Hide()
    fachTabs[i] = tab
end

local function CreateSlots()
    -- Blizzards Reihenfolge: je Gruppe erst die linke Spalte (1–7), dann die rechte (8–14)
    for i = 1, SLOTS do
        local button = CreateFrame("ItemButton", "MeredanUIGuildBankItem" .. i, grid, "GuildBankItemButtonTemplate")
        button:SetID(i)
        ns.StyleBagButton(button)
        local index = i - 1
        local group = math.floor(index / PER_GROUP)
        local inGroup = index % PER_GROUP
        local col, row = math.floor(inGroup / ROWS), inGroup % ROWS
        local x = group * (2 * SIZE + GAP + GROUP_GAP) + col * (SIZE + GAP)
        button:SetPoint("TOPLEFT", grid, "TOPLEFT", x, -row * (SIZE + GAP))
        slots[i] = button
    end
end

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIGuildBank", UIParent)
    window:SetFrameStrata("HIGH") -- über Chat und Schlachtzug-Frames
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor)
    tinsert(UISpecialFrames, "MeredanUIGuildBank") -- Esc schließt (und damit die Gildenbank)
    -- Standard: dort, wo die Schlachtzug-Frames sitzen (90 px über dem Chat, links bündig)
    window:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(90))
    window:SetSize(2 * PAD + GRID_WIDTH, PAD + 58 + GRID_HEIGHT + 14 + 24 + 10 + 14 + PAD)

    -- Kopfzeile packen = frei ziehen (wie unter Windows); beim Öffnen wieder am festen Platz
    local dragArea = CreateFrame("Frame", nil, window)
    dragArea:SetPoint("TOPLEFT")
    dragArea:SetPoint("TOPRIGHT")
    dragArea:SetHeight(PAD + 22)
    dragArea:SetFrameLevel(window:GetFrameLevel())
    ns.MakeWindowDraggable(window, dragArea)
    ns.WatchBlizzardFrame(window, function() return GuildBankFrame end)
    -- Kopfzeile: Modus-Reiter wie im Taschenfenster, rechts Fachname und Schließen
    local previous
    for _, entry in ipairs({ { "bank", GUILD_BANK }, { "log", GUILD_BANK_LOG }, { "moneylog", GUILD_BANK_MONEY_LOG },
        { "info", GUILD_BANK_TAB_INFO } }) do
        local key, label = entry[1], entry[2]
        local tab = CreateFrame("Button", nil, window)
        tab.text = UI.Text(tab, 14, "LEFT")
        tab.text:SetPoint("LEFT")
        tab.text:SetText(label or key)
        tab:SetSize(tab.text:GetUnboundedStringWidth() + 2, 20)
        tab.line = tab:CreateTexture(nil, "OVERLAY")
        tab.line:SetColorTexture(unpack(UI.ACCENT))
        tab.line:SetPoint("BOTTOMLEFT", 0, -2)
        tab.line:SetPoint("BOTTOMRIGHT", 0, -2)
        tab.line:SetHeight(2)
        tab:SetScript("OnClick", function() if mode ~= key then SetMode(key) end end)
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 14, 0)
        else
            tab:SetPoint("TOPLEFT", PAD, -PAD)
        end
        previous = tab
        modeTabs[key] = tab
    end
    local close = UI.IconButton(window, "Close", function() window:Hide() end, 22)
    close:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 2)
    tabTitle = UI.Text(window, 12, "RIGHT", UI.MUTED)
    tabTitle:SetPoint("RIGHT", close, "LEFT", -8, 0)

    searchBox = UI.EditBox(window, 22)
    searchBox:SetPoint("TOPLEFT", PAD, -PAD - 24)
    searchBox:SetPoint("TOPRIGHT", -PAD, -PAD - 24)
    local hint = UI.Text(searchBox, 12, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 8, 0)
    hint:SetText(L["Search"])
    searchBox:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        ApplySearch()
    end)

    -- Inhaltsbereich: Fächer, Log, Info oder Kaufen
    local area = CreateFrame("Frame", nil, window)
    area:SetPoint("TOPLEFT", PAD, -PAD - 58)
    area:SetSize(GRID_WIDTH, GRID_HEIGHT)
    grid = CreateFrame("Frame", nil, area)
    grid:SetAllPoints()

    logFrame = CreateFrame("ScrollingMessageFrame", nil, area)
    logFrame:SetAllPoints()
    logFrame:SetFont(ns.STYLE.font, ns.FontPx(12), "")
    logFrame:SetShadowOffset(1, -1)
    logFrame:SetJustifyH("LEFT")
    logFrame:SetFading(false)
    logFrame:SetMaxLines(500)
    logFrame:SetHyperlinksEnabled(true)
    logFrame:EnableMouseWheel(true)
    logFrame:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    logFrame:SetScript("OnHyperlinkEnter", function(self, link)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    logFrame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    logFrame:SetScript("OnHyperlinkClick", function(_, link, text) HandleModifiedItemClick(text or link) end)

    local infoArea = CreateFrame("Frame", nil, area)
    infoArea:SetAllPoints()
    UI.Box(infoArea)
    infoBox = CreateFrame("EditBox", nil, infoArea)
    infoBox:SetPoint("TOPLEFT", 10, -10)
    infoBox:SetPoint("BOTTOMRIGHT", -10, 40)
    infoBox:SetMultiLine(true)
    infoBox:SetAutoFocus(false)
    infoBox:SetMaxLetters(500)
    infoBox:SetFont(ns.STYLE.font, ns.FontPx(13), "")
    infoBox:SetTextColor(unpack(UI.TEXT))
    infoBox:SetScript("OnEscapePressed", infoBox.ClearFocus)
    infoSave = UI.Button(infoArea, SAVE_CHANGES or "Save", function()
        SaveInfo()
        infoBox:ClearFocus()
    end, 140)
    infoSave:SetPoint("BOTTOMRIGHT", -10, 10)

    buyView = CreateFrame("Frame", nil, area)
    buyView:SetAllPoints()
    local question = UI.Text(buyView, 14, "CENTER")
    question:SetPoint("CENTER", 0, 40)
    question:SetText(PURCHASE_TAB_TEXT or "")
    buyView.purchased = UI.Text(buyView, 12, "CENTER", UI.MUTED)
    buyView.purchased:SetPoint("TOP", question, "BOTTOM", 0, -6)
    local costLabel = UI.Text(buyView, 12, "RIGHT", UI.MUTED)
    costLabel:SetText(COSTS_LABEL or "")
    buyView.cost = UI.Text(buyView, 12, "LEFT")
    buyView.button = UI.Button(buyView, BANKSLOTPURCHASE or "Purchase", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        StaticPopup_Show("CONFIRM_BUY_GUILDBANK_TAB")
    end, 120)
    buyView.button:SetPoint("TOP", buyView.purchased, "BOTTOM", 50, -18)
    buyView.cost:SetPoint("RIGHT", buyView.button, "LEFT", -16, 0)
    costLabel:SetPoint("RIGHT", buyView.cost, "LEFT", -6, 0)

    errorText = UI.Text(area, 13, "CENTER", UI.MUTED)
    errorText:SetPoint("CENTER")
    errorText:SetWidth(GRID_WIDTH - 40)
    errorText:SetWordWrap(true)

    -- unten: Abhebungen/Knöpfe, darunter verfügbarer Betrag und Gildenkasse
    depositButton = UI.Button(window, DEPOSIT or "Deposit", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        StaticPopup_Hide("GUILDBANK_WITHDRAW")
        if StaticPopup_Visible("GUILDBANK_DEPOSIT") then StaticPopup_Hide("GUILDBANK_DEPOSIT") else StaticPopup_Show("GUILDBANK_DEPOSIT") end
    end, 110)
    depositButton:SetPoint("TOPRIGHT", area, "BOTTOMRIGHT", 0, -14)
    withdrawButton = UI.Button(window, WITHDRAW or "Withdraw", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        StaticPopup_Hide("GUILDBANK_DEPOSIT")
        if StaticPopup_Visible("GUILDBANK_WITHDRAW") then StaticPopup_Hide("GUILDBANK_WITHDRAW") else StaticPopup_Show("GUILDBANK_WITHDRAW") end
    end, 110)
    withdrawButton:SetPoint("RIGHT", depositButton, "LEFT", -6, 0)
    limitText = UI.Text(window, 12, "LEFT")
    limitText:SetPoint("LEFT", area, "BOTTOMLEFT", 0, -14 - 12)
    availableText = UI.Text(window, 12, "LEFT", UI.MUTED)
    availableText:SetPoint("BOTTOMLEFT", PAD, PAD)
    guildMoneyText = UI.Text(window, 12, "RIGHT")
    guildMoneyText:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    for i = 1, MaxTabs() do CreateFachTab(i) end

    window:SetScript("OnShow", function()
        ns.WindowOpened(window)
        ns.ResetWindowPosition(window, "guildbank", true)
        mode = "bank"
        SelectAvailableTab()
        QueryCurrent()
        Update()
        OpenAllBags(window) -- Taschen gehen mit auf, wie bei der Bank
    end)
    window:SetScript("OnHide", function()
        SaveInfo()
        searchBox:SetText("")
        searchBox:ClearFocus()
        if GuildBankPopupFrame then GuildBankPopupFrame:Hide() end
        StaticPopup_Hide("GUILDBANK_WITHDRAW")
        StaticPopup_Hide("GUILDBANK_DEPOSIT")
        StaticPopup_Hide("CONFIRM_BUY_GUILDBANK_TAB")
        PlaySound(SOUNDKIT.GUILD_VAULT_CLOSE)
        CloseAllBags(window)
        if ns.StillInteracting("GuildBanker", GuildBankFrame) then CloseGuildBankFrame() end -- nur die eigene Unterhaltung
    end)
end

-- Ereignisse ----------------------------------------------------------------------------------

local pending
local function Refresh()
    if not (window and window:IsShown()) or pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        Update()
    end)
end

-- Blizzard prüft beim Öffnen, ob sein Fenster SICHTBAR ist, und schließt sonst sofort wieder. Deshalb
-- erst nach dem Öffnen parken und beim Schließen zurückhängen (dann ist es versteckt: kein OnShow).
local function Park()
    if not GuildBankFrame:GetScript("OnHide") then return end
    -- erst OnHide entfernen, sonst schließt das Parken die Gildenbank beim Server
    GuildBankFrame:SetScript("OnHide", nil)
    GuildBankFrame:SetParent(hidden)
end

local function Unpark()
    if not GuildBankFrame or GuildBankFrame:GetParent() ~= hidden then return end
    if GuildBankFrame:IsShown() then
        C_Timer.After(0, Unpark) -- Blizzard versteckt es gleich (HideUIPanel)
        return
    end
    GuildBankFrame:SetParent(UIParent)
end

local function Open(retried)
    if not (GuildBankFrame and GuildBankFrame:IsShown()) then
        -- Blizzards Verwaltung war evtl. noch nicht dran: einen Frame später nochmal
        if not retried then C_Timer.After(0, function() Open(true) end) end
        return
    end
    if GuildBankFrame:GetParent() ~= hidden then
        Park()
        GuildBankFrame:SetParent(hidden)
    end
    if #slots == 0 then CreateSlots() end
    window:Show()
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or C_AddOns.IsAddOnLoaded("BetterBags") then return end
    -- Fenster gleich anlegen (Fächer erst beim Öffnen, Blizzards Vorlage lädt mit der Gildenbank)
    CreateWindow()
    ns.layoutFrames.guildbank = window
    -- läuft nach Blizzards Interaktions-Verwaltung (früher registriert), die das Fenster lädt und zeigt
    ns:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, kind)
        if kind == Enum.PlayerInteractionType.GuildBanker then Open() end
    end)
    ns:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
        if kind ~= Enum.PlayerInteractionType.GuildBanker then return end
        if window then window:Hide() end
        Unpark()
    end)
    for _, event in ipairs({ "GUILDBANKBAGSLOTS_CHANGED", "GUILDBANK_ITEM_LOCK_CHANGED", "GUILDBANK_UPDATE_MONEY",
        "GUILDBANK_UPDATE_WITHDRAWMONEY" }) do
        ns:On(event, Refresh)
    end
    for _, event in ipairs({ "GUILDBANK_UPDATE_TABS", "GUILD_ROSTER_UPDATE" }) do
        ns:On(event, function()
            if not (window and window:IsShown()) then return end
            SelectAvailableTab()
            Refresh()
        end)
    end
    ns:On("GUILDBANKLOG_UPDATE", function()
        if not (window and window:IsShown()) then return end
        if mode == "log" then FillItemLog() elseif mode == "moneylog" then FillMoneyLog() end
    end)
    ns:On("GUILDBANK_UPDATE_TEXT", function(_, tab)
        if not (window and window:IsShown()) or tab ~= GetCurrentGuildBankTab() then return end
        local text = GetGuildBankText(tab) or ""
        infoBox:SetText(text)
        infoBox.original = text
    end)
    ns:On("GUILDBANK_TEXT_CHANGED", function(_, tab)
        if window and window:IsShown() and tonumber(tab) == GetCurrentGuildBankTab() then QueryGuildBankText(tab) end
    end)
end)
