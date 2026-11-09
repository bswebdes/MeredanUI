-- Collections > Heirlooms. Only shown when the server offers heirlooms
-- (C_HeirloomInfo.HeirloomsAvailable, same check as Blizzard's journal) - probably not on Forever.
-- Create puts the item into the bags (C_Heirloom.CreateHeirloom, not protected).
local _, ns = ...
local L = ns.L
local C = ns.Collections

local page, list, preview, createButton
local selectedID
local mode = "all"
local items = {}

local WEAPON_SLOTS = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_SHIELD = true,
    INVTYPE_HOLDABLE = true, INVTYPE_THROWN = true }

local function Available()
    return C_HeirloomInfo and C_HeirloomInfo.HeirloomsAvailable and C_HeirloomInfo.HeirloomsAvailable()
        and C_Heirloom and true or false
end

local function Collect()
    wipe(items)
    for i = 1, C_Heirloom.GetNumDisplayedHeirlooms() do
        local itemID = C_Heirloom.GetHeirloomItemIDFromDisplayedIndex(i)
        if itemID then
            local name, slot, _, icon, level, source, _, _, minLevel, maxLevel = C_Heirloom.GetHeirloomInfo(itemID)
            local owned = C_Heirloom.PlayerHasHeirloom(itemID)
            local keep = mode == "all" or (mode == "missing" and not owned) or (mode == "weapons" and WEAPON_SLOTS[slot])
                or (mode == "armor" and not WEAPON_SLOTS[slot])
            if name and keep then
                items[#items + 1] = { id = itemID, name = name, slot = slot, icon = icon, level = level or 0,
                    maxUpgrade = C_Heirloom.GetHeirloomMaxUpgradeLevel(itemID) or 0, source = source,
                    minLevel = minLevel, maxLevel = maxLevel, owned = owned }
            end
        end
    end
end

local function Selected()
    for _, item in ipairs(items) do
        if item.id == selectedID then return item end
    end
end

local HEIRLOOM_COLOR = { 0, 0.8, 1 }

local function ShowPreview()
    local item = Selected() or items[1]
    selectedID = item and item.id
    if not item then
        preview:ShowEntry({ name = L["Nothing found."] })
        createButton:Disable()
        return
    end
    local levels = item.minLevel and item.maxLevel and L["Levels %d-%d"]:format(item.minLevel, item.maxLevel) or ""
    preview:ShowEntry({
        name = item.name, color = item.owned and HEIRLOOM_COLOR or ns.UI.MUTED,
        sub = (_G[item.slot or ""] or "") .. (levels ~= "" and (" · " .. levels) or ""),
        source = item.source,
        lore = item.owned and L["Upgrade %d of %d"]:format(item.level, item.maxUpgrade) or (NOT_COLLECTED or L["Not collected"]),
    })
    createButton:SetEnabled(item.owned)
    createButton:SetAlpha(item.owned and 1 or 0.45)
end

local function Refresh()
    if not page then return end
    Collect()
    list:SetItems(items, true)
    ShowPreview()
end

local function Wire(row)
    row:SetScript("OnClick", function(self)
        if not self.item then return end
        selectedID = self.item.id
        list:Render()
        ShowPreview()
    end)
    row:SetScript("OnDoubleClick", function(self)
        if self.item and self.item.owned then C_Heirloom.CreateHeirloom(self.item.id) end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.item.id)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Create(p)
    local UI = ns.UI
    page = p
    local search = C.Search(p, 236, function(text)
        C_Heirloom.SetSearch(text)
        Refresh()
    end)
    search:SetPoint("TOPLEFT", C.PAD, -C.TOOLBAR_TOP)
    local chips = C.Chips(p, {
        { value = "all", label = ALL or L["All"] },
        { value = "weapons", label = WEAPON or L["Weapons"] },
        { value = "armor", label = ARMOR or L["Armor"] },
        { value = "missing", label = L["Missing"] },
    }, function(value) mode = value Refresh() end)
    chips:SetPoint("LEFT", search, "RIGHT", 8, 0)

    list = C.List(p, 44, function(row) C.CreateRow(row) Wire(row) end, function(row, item)
        C.FillRow(row, {
            icon = item.icon, name = item.name, color = HEIRLOOM_COLOR, missing = not item.owned,
            sub = item.owned and L["Upgrade %d of %d"]:format(item.level, item.maxUpgrade) or (NOT_COLLECTED or L["Not collected"]),
            selected = item.id == selectedID,
        })
    end)
    list:SetPoint("TOPLEFT", C.PAD, -C.CONTENT_TOP)
    list:SetPoint("BOTTOMLEFT", C.PAD, C.FOOTER)
    list:SetWidth(C.LIST_W)

    preview = C.Preview(p)
    preview:SetPoint("TOPLEFT", list, "TOPRIGHT", 14, 0)
    preview:SetPoint("BOTTOMRIGHT", -C.PAD, C.FOOTER)

    createButton = C.FooterButton(p, L["Create"], function()
        local item = Selected()
        if item and item.owned then C_Heirloom.CreateHeirloom(item.id) end
    end, true)
    createButton:SetPoint("BOTTOMRIGHT", -C.PAD, 14)
    local hint = UI.Text(p, 11, "LEFT", { 0.36, 0.39, 0.38 })
    hint:SetPoint("BOTTOMLEFT", C.PAD, 22)
    hint:SetText(L["Create puts the heirloom into your bags · double-click: create"])

    if C_Heirloom.SetCollectedHeirloomFilter then C_Heirloom.SetCollectedHeirloomFilter(true) end
    if C_Heirloom.SetUncollectedHeirloomFilter then C_Heirloom.SetUncollectedHeirloomFilter(true) end
    C_Heirloom.SetSearch("")
end

C.Register({
    key = "heirlooms", order = 4, name = HEIRLOOMS or L["Heirlooms"],
    icon = "Interface\\Icons\\INV_Misc_Bag_EnchantedRunecloth",
    available = Available,
    Create = Create,
    Refresh = function() Refresh() end,
    Progress = function()
        local have, total = 0, 0
        for _, id in ipairs(C_Heirloom.GetHeirloomItemIDs and C_Heirloom.GetHeirloomItemIDs() or {}) do
            total = total + 1
            if C_Heirloom.PlayerHasHeirloom(id) then have = have + 1 end
        end
        return have, total
    end,
})

ns:On("HEIRLOOMS_UPDATED", function() C.RefreshTab("heirlooms") end)
