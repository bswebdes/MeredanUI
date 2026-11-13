-- Collections > Toys: card grid with pages; click uses the toy.
-- UseToy is protected: each card is an InsecureActionButtonTemplate button (type "toy"), like
-- ToyBoxEnhanced. That template acts only out of combat and never makes our window protected, so
-- the window still opens/closes in combat. In combat the cards are disarmed (no blocked-action
-- spam) and paging stops.
local _, ns = ...
local L = ns.L
local C = ns.Collections

local COLS, CARD_H, GAP = 4, 52, 8
local page, grid, pageText, prevButton, nextButton, combatNote
local cards = {}
local items = {}
local mode = "all"
local pageIndex = 1
local perPage = 1

local function Collect()
    wipe(items)
    for i = 1, C_ToyBox.GetNumFilteredToys() do
        local itemID = C_ToyBox.GetToyFromIndex(i)
        if itemID and itemID > 0 then
            local _, name, icon, fav, _, quality = C_ToyBox.GetToyInfo(itemID)
            local owned = PlayerHasToy(itemID)
            local usable = owned and C_ToyBox.IsToyUsable(itemID)
            local keep = mode == "all" or (mode == "fav" and fav) or (mode == "missing" and not owned)
                or (mode == "usable" and usable)
            if keep and name then
                items[#items + 1] = { id = itemID, name = name, icon = icon, fav = fav, owned = owned,
                    usable = usable, quality = quality }
            end
        end
    end
end

local function Arm(card, item)
    local armed = item and item.owned and not InCombatLockdown()
    card:SetAttribute("type1", armed and "toy" or nil)
    card:SetAttribute("toy", armed and item.id or nil)
end

local function ApplyCooldown(cooldown, start, duration)
    cooldown:SetCooldown(start, duration)
end

local function FillCard(card, item)
    card.item = item
    if not item then card:Hide() return end
    card.icon:SetTexture(item.icon)
    card.icon:SetDesaturated(not item.owned)
    card.name:SetText(item.name .. (item.fav and " |TInterface\\Common\\FavoritesIcon:12:12:0:0|t" or ""))
    local c = item.owned and C.QualityColor(item.quality) or ns.UI.MUTED
    card.name:SetTextColor(c[1], c[2], c[3])
    if not item.owned then
        card.sub:SetText(L["Missing"])
    elseif not item.usable then
        card.sub:SetText(L["Not usable"])
    else
        card.sub:SetText("")
    end
    card:SetAlpha(item.owned and 1 or 0.55)
    -- cooldown values may be secret: hand them straight to the widget, never test them
    if not pcall(ApplyCooldown, card.cooldown, C_Container.GetItemCooldown(item.id)) then card.cooldown:Clear() end
    Arm(card, item)
    card:Show()
end

local function Render()
    if not grid then return end
    local rows = math.max(math.floor((grid:GetHeight() - 2 * 10 + GAP) / (CARD_H + GAP)), 1)
    perPage = rows * COLS
    local pages = math.max(math.ceil(#items / perPage), 1)
    pageIndex = math.min(math.max(pageIndex, 1), pages)
    if not InCombatLockdown() then
        local width = (grid:GetWidth() - 20 - (COLS - 1) * GAP) / COLS
        for i = 1, perPage do
            local card = cards[i]
            if card then
                card:SetSize(width, CARD_H)
                card:ClearAllPoints()
                local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
                card:SetPoint("TOPLEFT", 10 + col * (width + GAP), -10 - row * (CARD_H + GAP))
                FillCard(card, items[(pageIndex - 1) * perPage + i])
            end
        end
        for i = perPage + 1, #cards do FillCard(cards[i], nil) end
    end
    pageText:SetText(L["Page %d / %d"]:format(pageIndex, pages))
    prevButton:SetEnabled(pageIndex > 1 and not InCombatLockdown())
    nextButton:SetEnabled(pageIndex < pages and not InCombatLockdown())
    combatNote:SetShown(InCombatLockdown())
end

local function Refresh()
    if not page then return end
    Collect()
    Render()
end

local function CreateCard(index)
    local UI = ns.UI
    local card = CreateFrame("Button", nil, grid, "InsecureActionButtonTemplate")
    card:RegisterForClicks("AnyUp", "AnyDown")
    card:RegisterForDrag("LeftButton")
    UI.Card(card)
    local hover = card:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.06)
    local iconFrame = CreateFrame("Frame", nil, card)
    iconFrame:SetSize(36, 36)
    iconFrame:SetPoint("LEFT", 8, 0)
    ns.AddSlotBackground(iconFrame)
    ns.AddItemFrame(iconFrame, nil, 2)
    card.icon = iconFrame:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(iconFrame, card.icon, nil, 2)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.cooldown = CreateFrame("Cooldown", nil, iconFrame, "CooldownFrameTemplate")
    card.cooldown:SetAllPoints(card.icon)
    card.name = UI.Text(card, 13, "LEFT")
    card.name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 10, -2)
    card.name:SetPoint("RIGHT", -8, 0)
    card.name:SetWordWrap(false)
    card.sub = UI.Text(card, 11, "LEFT", UI.MUTED)
    card.sub:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMRIGHT", 10, 2)
    card.sub:SetPoint("RIGHT", -8, 0)
    card.sub:SetWordWrap(false)
    -- right-click: favorite (left click is the secure toy action)
    card:HookScript("OnClick", function(self, button, down)
        if button ~= "RightButton" or down or not self.item or not self.item.owned then return end
        C_ToyBox.SetIsFavorite(self.item.id, not self.item.fav)
    end)
    card:SetScript("OnDragStart", function(self)
        if self.item and self.item.owned then C_ToyBox.PickupToyBoxItem(self.item.id) end
    end)
    card:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetToyByItemID(self.item.id)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cards[index] = card
    return card
end

local function Create(p)
    local UI = ns.UI
    page = p
    local search = C.Search(p, 236, function(text)
        C_ToyBox.SetFilterString(text)
        pageIndex = 1
        Refresh()
    end)
    search:SetPoint("TOPLEFT", C.PAD, -C.TOOLBAR_TOP)
    local chips = C.Chips(p, {
        { value = "all", label = ALL or L["All"] },
        { value = "fav", label = FAVORITES or L["Favorites"] },
        { value = "usable", label = L["Usable"] },
        { value = "missing", label = L["Missing"] },
    }, function(value) mode = value pageIndex = 1 Refresh() end)
    chips:SetPoint("LEFT", search, "RIGHT", 8, 0)

    grid = CreateFrame("Frame", nil, p)
    grid:SetPoint("TOPLEFT", C.PAD, -C.CONTENT_TOP)
    grid:SetPoint("BOTTOMRIGHT", -C.PAD, C.FOOTER)
    UI.Inset(grid, { 0, 0, 0, 0.25 })
    for i = 1, 40 do CreateCard(i) end
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta)
        if InCombatLockdown() then return end
        pageIndex = pageIndex - delta
        Render()
    end)
    grid:SetScript("OnSizeChanged", Render)

    combatNote = UI.Text(p, 12, "CENTER", { 0.9, 0.35, 0.3 })
    combatNote:SetPoint("BOTTOM", grid, "BOTTOM", 0, 8)
    combatNote:SetText(L["Toys can't be used from this window in combat."])

    nextButton = UI.IconButton(p, "ChevronDown", function() pageIndex = pageIndex + 1 Render() end, 28)
    nextButton.icon:SetRotation(math.pi / 2)
    nextButton:SetPoint("BOTTOMRIGHT", -C.PAD, 14)
    pageText = UI.Text(p, 13, "RIGHT", UI.MUTED)
    pageText:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
    prevButton = UI.IconButton(p, "ChevronDown", function() pageIndex = pageIndex - 1 Render() end, 28)
    prevButton.icon:SetRotation(-math.pi / 2)
    prevButton:SetPoint("RIGHT", pageText, "LEFT", -8, 0)
    local hint = UI.Text(p, 11, "LEFT", { 0.36, 0.39, 0.38 })
    hint:SetPoint("BOTTOMLEFT", C.PAD, 22)
    hint:SetText(L["Click: use · drag onto the action bar · right-click: favorite"])

    C_ToyBox.SetCollectedShown(true)
    C_ToyBox.SetUncollectedShown(true)
    C_ToyBox.SetUnusableShown(true)
    C_ToyBox.SetFilterString("")
end

local counts = { have = 0, total = 0 }

C.Register({
    key = "toys", order = 3, name = TOY_BOX or L["Toys"],
    icon = "Interface\\Icons\\INV_SideTab_ToyBox_c60",
    Create = Create,
    Refresh = function() Refresh() end,
    Progress = function()
        counts.have = C_ToyBox.GetNumLearnedDisplayedToys and C_ToyBox.GetNumLearnedDisplayedToys() or 0
        counts.total = C_ToyBox.GetNumTotalDisplayedToys and C_ToyBox.GetNumTotalDisplayedToys() or 0
        return counts.have, counts.total
    end,
})

local function Changed() C.RefreshTab("toys") end
ns:On("TOYS_UPDATED", Changed)
ns:On("NEW_TOY_ADDED", Changed)
ns:On("SPELL_UPDATE_COOLDOWN", function() if page and page:IsVisible() then Render() end end)
ns:On("PLAYER_REGEN_DISABLED", function()
    -- disarm visible cards before lockdown starts biting
    for _, card in ipairs(cards) do card:SetAttribute("type1", nil) end
    if page and page:IsVisible() then Render() end
end)
ns:On("PLAYER_REGEN_ENABLED", Changed)
