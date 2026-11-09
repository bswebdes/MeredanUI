-- Collections > Mounts: list (search, chips), 3D preview, summon / random favorite.
-- Uses Blizzard's journal display list (C_MountJournal) - its filter state is ours now since
-- Blizzard's journal no longer opens. SetIsFavorite/Pickup take that display index.
local _, ns = ...
local L = ns.L
local C = ns.Collections

local FILTER_COLLECTED = LE_MOUNT_JOURNAL_FILTER_COLLECTED or 1
local FILTER_NOT_COLLECTED = LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED or 2
local FILTER_UNUSABLE = LE_MOUNT_JOURNAL_FILTER_UNUSABLE or 3

local page, list, preview, chips, summonButton
local selectedID
local mode = "all"
local items = {}
local counts = { have = 0, total = 0, dirty = true }

local function CountMounts()
    if not counts.dirty then return end
    counts.dirty = false
    local have, total = 0, 0
    for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local _, _, _, _, _, _, _, _, _, hide, collected = C_MountJournal.GetMountInfoByID(id)
        if not hide then
            total = total + 1
            if collected then have = have + 1 end
        end
    end
    counts.have, counts.total = have, total
end

local function Collect()
    wipe(items)
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        local name, _, icon, active, usable, _, fav, _, _, hide, collected, mountID = C_MountJournal.GetDisplayedMountInfo(i)
        if name and not hide then
            local keep = mode == "all" or (mode == "fav" and fav) or (mode == "missing" and not collected)
                or (mode == "usable" and collected and usable)
            if keep then
                items[#items + 1] = { index = i, id = mountID, name = name, icon = icon, active = active,
                    usable = usable, fav = fav, collected = collected }
            end
        end
    end
    -- collected first, then name (Blizzard already sorts favorites/collected; keep its order)
end

local function Selected()
    for _, item in ipairs(items) do
        if item.id == selectedID then return item end
    end
end

local function ShowPreview()
    local item = Selected()
    if not item then
        item = items[1]
        selectedID = item and item.id
    end
    if not item then
        preview:ShowEntry({ name = L["Nothing found."] })
        summonButton:Disable()
        return
    end
    local displayID, description, source = C_MountJournal.GetMountInfoExtraByID(item.id)
    preview:ShowEntry({
        name = item.name,
        color = item.collected and ns.UI.TEXT or ns.UI.MUTED,
        sub = item.collected and (MOUNT or L["Mount"]) or (NOT_COLLECTED or L["Not collected"]),
        displayID = displayID, source = source, lore = description,
    })
    summonButton.Text:SetText(item.active and (BINDING_NAME_DISMOUNT or L["Dismount"]) or (MOUNT or L["Mount"]))
    summonButton:SetEnabled(item.collected and (item.usable or item.active))
    summonButton:SetAlpha(summonButton:IsEnabled() and 1 or 0.45)
end

local function Refresh()
    if not page then return end
    Collect()
    list:SetItems(items, true)
    ShowPreview()
end

local function ToggleFavorite(item)
    local _, canFavorite = C_MountJournal.GetIsFavorite(item.index)
    if canFavorite then C_MountJournal.SetIsFavorite(item.index, not item.fav) end
end

-- Row scripts (rows come from C.List; set once per row on first fill)
local function Wire(row)
    row:SetScript("OnClick", function(self, button)
        local item = self.item
        if not item then return end
        if button == "RightButton" then
            if item.collected then ToggleFavorite(item) end
            return
        end
        selectedID = item.id
        list:Render()
        ShowPreview()
    end)
    row:SetScript("OnDoubleClick", function(self)
        local item = self.item
        if item and item.collected and not InCombatLockdown() then C_MountJournal.SummonByID(item.id) end
    end)
    row:SetScript("OnDragStart", function(self)
        local item = self.item
        if item and item.collected then C_MountJournal.Pickup(item.index) end
    end)
    row:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then return end
        local spellID = select(2, C_MountJournal.GetMountInfoByID(item.id))
        if spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetMountBySpellID(spellID)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Create(p)
    local UI = ns.UI
    page = p
    local search = C.Search(p, 236, function(text)
        C_MountJournal.SetSearch(text)
        Refresh()
    end)
    search:SetPoint("TOPLEFT", C.PAD, -C.TOOLBAR_TOP)

    chips = C.Chips(p, {
        { value = "all", label = ALL or L["All"] },
        { value = "fav", label = FAVORITES or L["Favorites"] },
        { value = "usable", label = L["Usable"] },
        { value = "missing", label = L["Missing"] },
    }, function(value) mode = value Refresh() end)
    chips:SetPoint("LEFT", search, "RIGHT", 8, 0)

    list = C.List(p, 44, function(row) C.CreateRow(row) Wire(row) end, function(row, item)
        C.FillRow(row, {
            icon = item.icon, name = item.name, fav = item.fav, missing = not item.collected,
            sub = item.active and (L["Active"]) or (item.collected and (item.usable and "" or L["Not usable here"]) or (NOT_COLLECTED or L["Not collected"])),
            right = nil,
            selected = item.id == selectedID,
        })
    end)
    list:SetPoint("TOPLEFT", C.PAD, -C.CONTENT_TOP)
    list:SetPoint("BOTTOMLEFT", C.PAD, C.FOOTER)
    list:SetWidth(C.LIST_W)

    preview = C.Preview(p)
    preview:SetPoint("TOPLEFT", list, "TOPRIGHT", 14, 0)
    preview:SetPoint("BOTTOMRIGHT", -C.PAD, C.FOOTER)

    -- favorite toggle in the preview's corner
    local fav = UI.IconButton(preview, "Star", function()
        local item = Selected()
        if item and item.collected then ToggleFavorite(item) end
    end, 28)
    fav:SetPoint("TOPRIGHT", -12, -12)

    local random = C.FooterButton(p, L["Random favorite"], function()
        if InCombatLockdown() then return end
        C_MountJournal.SummonByID(0)
    end)
    random:SetPoint("BOTTOMLEFT", C.PAD, 14)
    summonButton = C.FooterButton(p, MOUNT or L["Mount"], function()
        local item = Selected()
        if not item then return end
        if item.active then C_MountJournal.Dismiss() else C_MountJournal.SummonByID(item.id) end
    end, true)
    summonButton:SetPoint("BOTTOMRIGHT", -C.PAD, 14)
    local hint = UI.Text(p, 11, "CENTER", { 0.36, 0.39, 0.38 })
    hint:SetPoint("LEFT", random, "RIGHT", 10, 0)
    hint:SetPoint("RIGHT", summonButton, "LEFT", -10, 0)
    hint:SetText(L["Drag onto the action bar · right-click: favorite · double-click: mount"])

    -- default filters: everything visible, our chips filter further
    C_MountJournal.SetCollectedFilterSetting(FILTER_COLLECTED, true)
    C_MountJournal.SetCollectedFilterSetting(FILTER_NOT_COLLECTED, true)
    C_MountJournal.SetCollectedFilterSetting(FILTER_UNUSABLE, true)
    C_MountJournal.SetSearch("")
end

C.Register({
    key = "mounts", order = 1, name = MOUNTS or L["Mounts"],
    icon = "Interface\\Icons\\INV_Horse3Saddle008_Chestnut",
    Create = Create,
    Refresh = function() Refresh() end,
    Progress = function() CountMounts() return counts.have, counts.total end,
})

local function Changed()
    counts.dirty = true
    C.RefreshTab("mounts")
end
ns:On("MOUNT_JOURNAL_SEARCH_UPDATED", Changed) -- Forever has no MOUNT_JOURNAL_LIST_UPDATE
ns:On("NEW_MOUNT_ADDED", Changed)
ns:On("COMPANION_UPDATE", function() C.RefreshTab("mounts") end)
ns:On("MOUNT_JOURNAL_USABILITY_CHANGED", function() C.RefreshTab("mounts") end)
