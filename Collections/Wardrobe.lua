-- Collections > Wardrobe: appearances per slot as 3D tiles (pages), your character on the right
-- wearing the selected appearance; "Sets" mode lists sets and dresses the character in them.
-- Forever shows collected appearances only (Blizzard's Camelot override does the same).
-- Preview only in our own models: Blizzard's DressUpVisual opens a UI panel from addon code
-- (taint trap), so there is no "try on" hand-off.
local _, ns = ...
local L = ns.L
local C = ns.Collections

local COLS, ROWS = 6, 3
local GRID_W = 640
local SEARCH_ITEMS = Enum.TransmogSearchType and Enum.TransmogSearchType.Items or 1

-- Forever slot order (Blizzard's Camelot list); category per slot is looked up by name below
local SLOTS = {
    { "head", "HeadSlot" }, { "shoulder", "ShoulderSlot" }, { "back", "BackSlot" }, { "chest", "ChestSlot" },
    { "shirt", "ShirtSlot" }, { "tabard", "TabardSlot" }, { "wrist", "WristSlot" }, { "hands", "HandsSlot" },
    { "waist", "WaistSlot" }, { "legs", "LegsSlot" }, { "feet", "FeetSlot" }, { "mainhand", "MainHandSlot" },
    { "secondaryhand", "SecondaryHandSlot" },
}

local page, gridFrame, tiles, player, nameText, subText, pageText, prevButton, nextButton, linkButton
local slotButtons = {}
local setsList, itemsArea, setsArea, modeChips
local mode = "items"
local slotIndex = 1
local pageIndex = 1
local visuals = {}
local sets = {}
local selectedVisual, selectedSource, selectedSet

-- Transmog categories (Enum.TransmogCollectionType) per slot; weapon slots list every weapon type
local ARMOR = { head = "Head", shoulder = "Shoulder", back = "Back", chest = "Chest", shirt = "Shirt",
    tabard = "Tabard", wrist = "Wrist", hands = "Hands", waist = "Waist", legs = "Legs", feet = "Feet" }
local function Categories(slotKey)
    local T = Enum.TransmogCollectionType or {}
    local list = {}
    if ARMOR[slotKey] then
        if T[ARMOR[slotKey]] then list[1] = T[ARMOR[slotKey]] end
        return list
    end
    local first = T.Wand or 12
    local last = T.Warglaives or (first + 20)
    for id = first, last do
        local name, isWeapon, _, canMainHand, canOffHand = C_TransmogCollection.GetCategoryInfo(id)
        if name and isWeapon and ((slotKey == "mainhand" and canMainHand) or (slotKey == "secondaryhand" and canOffHand)) then
            list[#list + 1] = id
        end
    end
    if slotKey == "secondaryhand" then
        for _, key in ipairs({ "Shield", "Holdable" }) do
            if T[key] then list[#list + 1] = T[key] end
        end
    end
    return list
end

local categoryCache = {}
local function SlotCategories()
    local key = SLOTS[slotIndex][1]
    categoryCache[key] = categoryCache[key] or Categories(key)
    return categoryCache[key]
end

local function FirstSource(visualID)
    local sources = C_TransmogCollection.GetAllAppearanceSources(visualID)
    local best
    for _, sourceID in ipairs(sources or {}) do
        local info = C_TransmogCollection.GetSourceInfo(sourceID)
        if info and info.isCollected then return sourceID, info end
        best = best or sourceID
    end
    return best, best and C_TransmogCollection.GetSourceInfo(best)
end

local function CollectVisuals()
    wipe(visuals)
    for _, category in ipairs(SlotCategories()) do
        local _, isWeapon = C_TransmogCollection.GetCategoryInfo(category)
        for _, info in ipairs(C_TransmogCollection.GetCategoryAppearances(category) or {}) do
            if info.isCollected and not info.isHideVisual then
                visuals[#visuals + 1] = { visualID = info.visualID, category = category, isWeapon = isWeapon }
            end
        end
    end
end

local function Dress(model, sourceID, visual)
    model:SetUnit("player", false)
    if visual and visual.isWeapon then
        model:SetItemAppearance(visual.visualID)
    else
        model:Undress()
        if sourceID then model:TryOn(sourceID) end
    end
    local cameraID = visual and C_TransmogCollection.GetAppearanceCameraID(visual.visualID)
    if cameraID and cameraID > 0 and Model_ApplyUICamera then Model_ApplyUICamera(model, cameraID) end
end

local function ShowSelection()
    if mode == "sets" then
        local set = selectedSet and C_TransmogSets.GetSetInfo(selectedSet)
        player:SetUnit("player", false)
        player:Undress()
        if set then
            for _, appearance in ipairs(C_TransmogSets.GetSetPrimaryAppearances(selectedSet) or {}) do
                player:TryOn(appearance.appearanceID)
            end
            nameText:SetText(set.name or "")
            subText:SetText(set.label or set.description or "")
        else
            nameText:SetText("")
            subText:SetText("")
        end
        linkButton:Hide()
        return
    end
    player:SetUnit("player", false)
    if selectedSource then player:TryOn(selectedSource) end
    local info = selectedSource and C_TransmogCollection.GetSourceInfo(selectedSource)
    if info then
        nameText:SetText(info.name or "")
        local c = C.QualityColor(info.quality)
        nameText:SetTextColor(c[1], c[2], c[3])
        subText:SetText(info.sourceType and _G["TRANSMOG_SOURCE_" .. info.sourceType] or "")
    else
        nameText:SetText("")
        subText:SetText("")
    end
    linkButton:SetShown(info ~= nil)
end

local function RenderTiles()
    local perPage = COLS * ROWS
    local pages = math.max(math.ceil(#visuals / perPage), 1)
    pageIndex = math.min(math.max(pageIndex, 1), pages)
    for i, tile in ipairs(tiles) do
        local visual = visuals[(pageIndex - 1) * perPage + i]
        tile.visual = visual
        if visual then
            local sourceID = FirstSource(visual.visualID)
            tile.sourceID = sourceID
            Dress(tile.model, sourceID, visual)
            local on = visual.visualID == selectedVisual
            for _, e in ipairs(tile.active) do e:SetShown(on) end
            tile:Show()
        else
            tile:Hide()
        end
    end
    pageText:SetText(L["Page %d / %d"]:format(pageIndex, pages))
    prevButton:SetEnabled(pageIndex > 1)
    nextButton:SetEnabled(pageIndex < pages)
end

local function CollectSets()
    wipe(sets)
    for _, set in ipairs(C_TransmogSets.GetBaseSets() or {}) do
        sets[#sets + 1] = set
    end
    table.sort(sets, function(a, b)
        if (a.collected and true or false) ~= (b.collected and true or false) then return a.collected and true or false end
        return (a.name or "") < (b.name or "")
    end)
end

local function UpdateSlots()
    for i, button in ipairs(slotButtons) do
        local on = mode == "items" and i == slotIndex
        for _, e in ipairs(button.active) do e:SetShown(on) end
        button.icon:SetDesaturated(not on)
    end
end

local function Refresh()
    if not page then return end
    itemsArea:SetShown(mode == "items")
    setsArea:SetShown(mode == "sets")
    UpdateSlots()
    if mode == "items" then
        CollectVisuals()
        RenderTiles()
    else
        CollectSets()
        selectedSet = selectedSet or (sets[1] and sets[1].setID)
        setsList:SetItems(sets, true)
    end
    ShowSelection()
end

local function CreateTile(index)
    local tile = CreateFrame("Button", nil, gridFrame)
    ns.UI.Box(tile, { 0.06, 0.07, 0.075, 1 })
    ns.AddBorder(tile)
    tile.model = CreateFrame("DressUpModel", nil, tile)
    tile.model:SetPoint("TOPLEFT", 1, -1)
    tile.model:SetPoint("BOTTOMRIGHT", -1, 1)
    tile.model:SetMouseClickEnabled(false)
    tile.model:SetMouseMotionEnabled(false)
    tile.active = ns.AddBorder(tile, true, 2)
    for _, e in ipairs(tile.active) do
        e:SetVertexColor(unpack(ns.UI.ACCENT))
        e:SetDrawLayer("OVERLAY", 7)
    end
    local hover = tile:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    tile:SetScript("OnClick", function(self)
        if not self.visual then return end
        selectedVisual, selectedSource = self.visual.visualID, self.sourceID
        RenderTiles()
        ShowSelection()
    end)
    tile:SetScript("OnEnter", function(self)
        if not self.visual then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local sources = C_TransmogCollection.GetAllAppearanceSources(self.visual.visualID) or {}
        for i, sourceID in ipairs(sources) do
            local info = C_TransmogCollection.GetSourceInfo(sourceID)
            if info and info.name then
                local c = C.QualityColor(info.quality)
                GameTooltip:AddLine(info.name, c[1], c[2], c[3])
            end
            if i >= 6 then break end
        end
        GameTooltip:Show()
    end)
    tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tiles[index] = tile
end

local function LayoutTiles()
    local w = (gridFrame:GetWidth() - 20 - (COLS - 1) * 8) / COLS
    local h = (gridFrame:GetHeight() - 20 - (ROWS - 1) * 8) / ROWS
    for i, tile in ipairs(tiles) do
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        tile:SetSize(w, h)
        tile:ClearAllPoints()
        tile:SetPoint("TOPLEFT", 10 + col * (w + 8), -10 - row * (h + 8))
    end
end

local function Create(p)
    local UI = ns.UI
    page = p
    tiles = {}

    -- toolbar: slot buttons, search, items/sets
    local last
    for i, slot in ipairs(SLOTS) do
        local button = CreateFrame("Button", nil, p)
        button:SetSize(32, 32)
        UI.Box(button)
        ns.AddBorder(button)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        local _, texture = GetInventorySlotInfo(slot[2])
        button.icon:SetTexture(texture)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.active = ns.AddBorder(button, true, 2)
        for _, e in ipairs(button.active) do e:SetVertexColor(unpack(UI.ACCENT)) end
        if last then button:SetPoint("LEFT", last, "RIGHT", 4, 0) else button:SetPoint("TOPLEFT", C.PAD, -C.TOOLBAR_TOP) end
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(_G[slot[2]:upper()] or slot[1], 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            slotIndex, pageIndex, mode = i, 1, "items"
            modeChips:Set("items")
            selectedVisual, selectedSource = nil, nil
            Refresh()
            C.UpdateHeader()
        end)
        slotButtons[i] = button
        last = button
    end

    modeChips = C.Chips(p, {
        { value = "items", label = ITEMS or L["Items"] },
        { value = "sets", label = WARDROBE_SETS or L["Sets"] },
    }, function(value) mode = value Refresh() C.UpdateHeader() end)
    modeChips.buttons[#modeChips.buttons]:ClearAllPoints()
    modeChips.buttons[1]:SetPoint("TOPRIGHT", p, "TOPRIGHT", -C.PAD - modeChips.buttons[2]:GetWidth() - 6, -C.TOOLBAR_TOP)
    modeChips.buttons[2]:SetPoint("LEFT", modeChips.buttons[1], "RIGHT", 6, 0)
    local search = C.Search(p, 180, function(text)
        C_TransmogCollection.SetSearch(SEARCH_ITEMS, text)
    end)
    search:SetPoint("RIGHT", modeChips.buttons[1], "LEFT", -8, 0)

    -- items: tile grid
    itemsArea = CreateFrame("Frame", nil, p)
    itemsArea:SetPoint("TOPLEFT", C.PAD, -C.CONTENT_TOP)
    itemsArea:SetPoint("BOTTOMLEFT", C.PAD, 14)
    itemsArea:SetWidth(GRID_W)
    gridFrame = CreateFrame("Frame", nil, itemsArea)
    gridFrame:SetPoint("TOPLEFT")
    gridFrame:SetPoint("TOPRIGHT")
    gridFrame:SetPoint("BOTTOM", 0, C.FOOTER - 14)
    UI.Box(gridFrame, { 0, 0, 0, 0.25 })
    ns.AddBorder(gridFrame)
    for i = 1, COLS * ROWS do CreateTile(i) end
    gridFrame:SetScript("OnSizeChanged", LayoutTiles)
    gridFrame:EnableMouseWheel(true)
    gridFrame:SetScript("OnMouseWheel", function(_, delta) pageIndex = pageIndex - delta RenderTiles() end)
    nextButton = UI.IconButton(itemsArea, "ChevronDown", function() pageIndex = pageIndex + 1 RenderTiles() end, 28)
    nextButton.icon:SetRotation(math.pi / 2)
    nextButton:SetPoint("BOTTOMRIGHT", 0, 0)
    pageText = UI.Text(itemsArea, 13, "RIGHT", UI.MUTED)
    pageText:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
    prevButton = UI.IconButton(itemsArea, "ChevronDown", function() pageIndex = pageIndex - 1 RenderTiles() end, 28)
    prevButton.icon:SetRotation(-math.pi / 2)
    prevButton:SetPoint("RIGHT", pageText, "LEFT", -8, 0)
    local hint = UI.Text(itemsArea, 11, "LEFT", { 0.36, 0.39, 0.38 })
    hint:SetPoint("BOTTOMLEFT", 0, 8)
    hint:SetText(L["Click: show on your character · hover: where it drops"])

    -- sets: list
    setsArea = CreateFrame("Frame", nil, p)
    setsArea:SetAllPoints(itemsArea)
    setsList = C.List(setsArea, 44, function(row)
        C.CreateRow(row)
        row:SetScript("OnClick", function(self)
            if not self.item then return end
            selectedSet = self.item.setID
            setsList:Render()
            ShowSelection()
        end)
    end, function(row, set)
        local primaries = C_TransmogSets.GetSetPrimaryAppearances(set.setID) or {}
        local have = 0
        for _, appearance in ipairs(primaries) do
            if appearance.collected then have = have + 1 end
        end
        local icon
        local first = primaries[1] and C_TransmogCollection.GetSourceInfo(primaries[1].appearanceID)
        if first and first.itemID then icon = C_Item.GetItemIconByID(first.itemID) end
        C.FillRow(row, {
            icon = icon, name = set.name, missing = not set.collected,
            sub = (set.label or "") .. ((set.label and set.label ~= "") and " · " or "") .. L["%d / %d parts"]:format(have, #primaries),
            selected = set.setID == selectedSet,
        })
    end)
    setsList:SetPoint("TOPLEFT")
    setsList:SetPoint("BOTTOMRIGHT", 0, C.FOOTER - 14)

    -- right: your character
    local right = CreateFrame("Frame", nil, p)
    right:SetPoint("TOPLEFT", itemsArea, "TOPRIGHT", 14, 0)
    right:SetPoint("BOTTOMRIGHT", -C.PAD, C.FOOTER)
    UI.Box(right, { 0.045, 0.055, 0.055, 1 })
    ns.AddBorder(right)
    player = CreateFrame("DressUpModel", nil, right)
    player:SetPoint("TOPLEFT", 6, -58)
    player:SetPoint("BOTTOMRIGHT", -6, 46)
    player:SetUnit("player", false)
    local facing = 0
    player:EnableMouse(true)
    player:SetScript("OnMouseDown", function(self)
        local startX, startFacing = GetCursorPosition(), facing
        self:SetScript("OnUpdate", function()
            facing = startFacing + (GetCursorPosition() - startX) / 80
            self:SetFacing(facing)
        end)
    end)
    player:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    nameText = UI.Text(right, 14, "LEFT")
    ns.SetFont(nameText, 14, "", "bold")
    nameText:SetPoint("TOPLEFT", 12, -10)
    nameText:SetPoint("RIGHT", -12, 0)
    nameText:SetWordWrap(false)
    subText = UI.Text(right, 11, "LEFT", UI.MUTED)
    subText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)
    subText:SetPoint("RIGHT", -12, 0)
    -- back to what you are wearing (without the previewed piece)
    local undress = UI.Button(right, L["Reset"], function()
        player:SetUnit("player", false)
    end, 100)
    undress:SetHeight(28)
    undress:SetPoint("BOTTOMLEFT", 10, 10)
    linkButton = UI.Button(right, L["Link"], function()
        if not selectedSource then return end
        -- 12.x returns a table; into an open chat line, else open one with the link
        local info = C_TransmogCollection.GetAppearanceSourceInfo(selectedSource)
        local link = type(info) == "table" and (info.itemLink ~= "" and info.itemLink or info.transmoglink) or nil
        if not link or link == "" then return end
        if not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) and ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
    end, 100)
    linkButton:SetHeight(28)
    linkButton:SetPoint("BOTTOMRIGHT", -10, 10)

    C_TransmogCollection.SetCollectedShown(true)
    C_TransmogCollection.SetUncollectedShown(false)
end

C.Register({
    key = "wardrobe", order = 5, name = WARDROBE or L["Wardrobe"],
    icon = "Interface\\Icons\\UI_Transmog_ShowEquippedGear",
    available = function() return C_TransmogCollection ~= nil end,
    Create = Create,
    Refresh = function() Refresh() end,
    HeaderText = function(have, total)
        local name = WARDROBE or L["Wardrobe"]
        if mode == "sets" then return L["%s · %d of %d collected"]:format(name .. " · " .. (WARDROBE_SETS or L["Sets"]), have, total) end
        local slot = SLOTS[slotIndex]
        return L["%s · %s · %d appearances"]:format(name, _G[slot[2]:upper()] or slot[1], have)
    end,
    OnHide = function() if C_TransmogCollection.ClearSearch then C_TransmogCollection.ClearSearch(SEARCH_ITEMS) end end,
    Progress = function()
        if mode == "sets" then
            local have, total = 0, 0
            for _, set in ipairs(C_TransmogSets.GetBaseSets() or {}) do
                total = total + 1
                if set.collected then have = have + 1 end
            end
            return have, total
        end
        local have = 0
        for _, category in ipairs(SlotCategories()) do
            have = have + (C_TransmogCollection.GetCategoryCollectedCount(category) or 0)
        end
        return have, 0 -- Forever hides uncollected: show the count only
    end,
})

ns:On("TRANSMOG_SEARCH_UPDATED", function() C.RefreshTab("wardrobe") end)
ns:On("TRANSMOG_COLLECTION_UPDATED", function() C.RefreshTab("wardrobe") end)
