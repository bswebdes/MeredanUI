-- Collections > Pets (Forever: companions only, Blizzard's classic pet journal API).
-- Summon/dismiss are #nocombat: the button is disabled in combat. Uses the journal's filtered
-- index list (its filter state is ours now).
local _, ns = ...
local L = ns.L
local C = ns.Collections

local page, list, preview, summonButton
local selected -- petID (owned) or "s"..speciesID (not owned)
local mode = "all"
local items = {}

local function Key(item) return item.petID or ("s" .. item.speciesID) end

local function Collect()
    wipe(items)
    local summoned = C_PetJournal.GetSummonedPetGUID and C_PetJournal.GetSummonedPetGUID()
    for i = 1, (C_PetJournal.GetNumPets()) do
        local petID, speciesID, owned, customName, _, fav, revoked, name, icon = C_PetJournal.GetPetInfoByIndex(i)
        if speciesID then
            local keep = mode == "all" or (mode == "fav" and fav) or (mode == "missing" and not owned)
            if keep then
                items[#items + 1] = { index = i, petID = owned and petID or nil, speciesID = speciesID,
                    name = (customName and customName ~= "") and customName or name, icon = icon, owned = owned,
                    fav = fav, revoked = revoked, active = owned and petID == summoned }
            end
        end
    end
end

local function Selected()
    for _, item in ipairs(items) do
        if Key(item) == selected then return item end
    end
end

local function UpdateSummon(item)
    local active = item and item.active
    summonButton.Text:SetText(active and (PET_DISMISS or L["Dismiss"]) or (SUMMON or L["Summon"]))
    local usable = item and item.owned and not item.revoked and not InCombatLockdown()
    if usable and not active and C_PetJournal.GetPetSummonInfo then
        usable = C_PetJournal.GetPetSummonInfo(item.petID) and true or false
    end
    summonButton:SetEnabled(usable and true or false)
    summonButton:SetAlpha(usable and 1 or 0.45)
end

local function ShowPreview()
    local item = Selected() or items[1]
    selected = item and Key(item)
    if not item then
        preview:ShowEntry({ name = L["Nothing found."] })
        UpdateSummon(nil)
        return
    end
    local name, _, _, creatureID, source, description, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoBySpeciesID(item.speciesID)
    preview:ShowEntry({
        name = item.name or name,
        color = item.owned and ns.UI.TEXT or ns.UI.MUTED,
        sub = item.owned and (COMPANIONS or L["Companion"]) or (NOT_COLLECTED or L["Not collected"]),
        displayID = displayID, creatureID = creatureID, source = source, lore = description,
    })
    UpdateSummon(item)
end

local function Refresh()
    if not page then return end
    Collect()
    list:SetItems(items, true)
    ShowPreview()
end

local function ToggleFavorite(item)
    if item.petID then C_PetJournal.SetFavorite(item.petID, item.fav and 0 or 1) end
end

local function Summon(item)
    if not (item and item.petID) or InCombatLockdown() then return end
    if item.active then
        C_PetJournal.DismissSummonedPet(item.petID)
    else
        if C_PetJournal.PetNeedsFanfare and C_PetJournal.PetNeedsFanfare(item.petID) then
            C_PetJournal.ClearFanfare(item.petID)
        end
        C_PetJournal.SummonPetByGUID(item.petID)
    end
end

local function Wire(row)
    row:SetScript("OnClick", function(self, button)
        local item = self.item
        if not item then return end
        if button == "RightButton" then ToggleFavorite(item) return end
        selected = Key(item)
        list:Render()
        ShowPreview()
    end)
    row:SetScript("OnDoubleClick", function(self) Summon(self.item) end)
    row:SetScript("OnDragStart", function(self)
        local item = self.item
        if item and item.petID then C_PetJournal.PickupPet(item.petID) end
    end)
    row:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(item.name or "", 1, 1, 1)
        local source = select(5, C_PetJournal.GetPetInfoBySpeciesID(item.speciesID))
        if source and source ~= "" then GameTooltip:AddLine(source, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Create(p)
    local UI = ns.UI
    page = p
    local search = C.Search(p, 236, function(text)
        C_PetJournal.SetSearchFilter(text)
        Refresh()
    end)
    search:SetPoint("TOPLEFT", C.PAD, -C.TOOLBAR_TOP)
    local chips = C.Chips(p, {
        { value = "all", label = ALL or L["All"] },
        { value = "fav", label = FAVORITES or L["Favorites"] },
        { value = "missing", label = L["Missing"] },
    }, function(value) mode = value Refresh() end)
    chips:SetPoint("LEFT", search, "RIGHT", 8, 0)

    list = C.List(p, 44, function(row) C.CreateRow(row) Wire(row) end, function(row, item)
        C.FillRow(row, {
            icon = item.icon, name = item.name, fav = item.fav, missing = not item.owned or item.revoked,
            sub = item.active and L["Active"] or (not item.owned and (NOT_COLLECTED or L["Not collected"]) or ""),
            right = nil,
            selected = Key(item) == selected,
        })
    end)
    list:SetPoint("TOPLEFT", C.PAD, -C.CONTENT_TOP)
    list:SetPoint("BOTTOMLEFT", C.PAD, C.FOOTER)
    list:SetWidth(C.LIST_W)

    preview = C.Preview(p)
    preview:SetPoint("TOPLEFT", list, "TOPRIGHT", 14, 0)
    preview:SetPoint("BOTTOMRIGHT", -C.PAD, C.FOOTER)
    local fav = UI.IconButton(preview, "Star", function()
        local item = Selected()
        if item then ToggleFavorite(item) end
    end, 28)
    fav:SetPoint("TOPRIGHT", -12, -12)

    summonButton = C.FooterButton(p, SUMMON or L["Summon"], function() Summon(Selected()) end, true)
    summonButton:SetPoint("BOTTOMRIGHT", -C.PAD, 14)
    local hint = UI.Text(p, 11, "CENTER", { 0.36, 0.39, 0.38 })
    hint:SetPoint("BOTTOMLEFT", C.PAD, 22)
    hint:SetPoint("RIGHT", summonButton, "LEFT", -10, 0)
    hint:SetText(L["Drag onto the action bar · right-click: favorite · double-click: summon"])

    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED or 1, true)
    C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED or 2, true)
    C_PetJournal.SetSearchFilter("")
end

local counts = { have = 0, total = 0 }

C.Register({
    key = "pets", order = 2, name = PET_JOURNAL or L["Pets"],
    icon = "Interface\\Icons\\INV_ArfusPet_Classic",
    Create = Create,
    Refresh = function() Refresh() end,
    Progress = function()
        -- GetNumPets is filtered; owned species are counted over the whole list
        local total, owned = C_PetJournal.GetNumPets()
        counts.total, counts.have = total or 0, owned or 0
        return counts.have, counts.total
    end,
})

local function Changed() C.RefreshTab("pets") end
ns:On("PET_JOURNAL_LIST_UPDATE", Changed)
ns:On("COMPANION_UPDATE", Changed)
ns:On("NEW_PET_ADDED", Changed)
ns:On("PLAYER_REGEN_DISABLED", Changed)
ns:On("PLAYER_REGEN_ENABLED", Changed)
