-- Spellbook (WoW Forever): own window replacing Blizzard's spellbook.
--
--   [icon] Spellbook       [Search spells] [Display v] [x]   [G]  <- tabs on the right: General,
--          Hunter - Level 14                                 [T]     the trees, pet
--   +- parchment ------------------------------------------+
--   | Survival                                              |
--   | [Track Humanoids] [Track Beasts] [...]                |
--   | [Raptor Strike  Rank 2] [Wing Clip  Rank 1] ...       |
--   +----------------------------------- Page 1/1 [<][>] --+
--   12 spells          Drag: action bar - Click: cast ...
--
-- Spell cards are secure buttons (cast; pet: right-click toggles autocast). They live on a separate
-- layer (parented to UIParent) with a "[combat] hide" state driver - otherwise the whole window
-- would become protected and could not be opened/closed in combat. The P key and the micro button
-- open this window via override bindings; Blizzard's frame is left untouched.
local _, ns = ...
local L = ns.L

local WIDTH, PAD = 820, 18
local COLS, CARD_H, GAP = 3, 48, 6
local PLAYER = Enum.SpellBookSpellBank.Player
local PET = Enum.SpellBookSpellBank.Pet

local window, panel, title, footer, pageText, prevButton, nextButton, searchBox, options, optionsButton, layer, combatNote
local tabs, cards = {}, {}
local currentTab = 2 -- first class tree
local page = 1
local pendingRefresh

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.spellbookWindow ~= false and C_SpellBook
end

local function Settings()
    ns.db.spellbookView = ns.db.spellbookView or { passives = true, lowRanks = false }
    return ns.db.spellbookView
end

-- Tabs: skill lines (General, trees) and pet --------------------------------------------

local function TabList()
    local list = {}
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if info and not info.shouldHide and (info.numSpellBookItems or 0) > 0 then
            list[#list + 1] = { name = info.name, icon = info.iconID, offset = info.itemIndexOffset or 0,
                count = info.numSpellBookItems or 0, bank = PLAYER, index = i }
        end
    end
    -- Second value is a token ("PET", "DEMON"), not a name: use the pet's name, else Blizzard's type text
    local numPet, petToken = C_SpellBook.HasPetSpells()
    if numPet and numPet > 0 then
        local icon = C_SpellBook.GetSpellBookItemTexture and C_SpellBook.GetSpellBookItemTexture(1, PET)
        local petName = ns.Plain(UnitName("pet"))
        if not petName or petName == "" or petName == UNKNOWNOBJECT then
            petName = petToken and _G["PET_TYPE_" .. petToken] or _G.PET or L["Pet"]
        end
        list[#list + 1] = { name = petName, icon = icon or 132161, offset = 0, count = numPet,
            bank = PET, pet = true, index = "pet" }
    end
    return list
end

-- Spells of one tab (or of all tabs when searching)
local function Spells(tabEntries, query)
    local view = Settings()
    local list = {}
    for _, tab in ipairs(tabEntries) do
        for slot = tab.offset + 1, tab.offset + tab.count do
            local info = C_SpellBook.GetSpellBookItemInfo(slot, tab.bank)
            if info and info.itemType ~= Enum.SpellBookItemType.Flyout and info.name then
                local lowRank = C_SpellBook.IsSpellBookItemLowRank and C_SpellBook.IsSpellBookItemLowRank(slot, tab.bank)
                local future = info.itemType == Enum.SpellBookItemType.FutureSpell
                local keep = (view.passives or not info.isPassive) and (view.lowRanks or not lowRank)
                    and (query == "" or info.name:lower():find(query, 1, true))
                if keep then
                    local entry = { slot = slot, bank = tab.bank, info = info, future = future, pet = tab.pet, lowRank = lowRank }
                    if future then
                        entry.level = C_SpellBook.GetSpellBookItemLevelLearned and C_SpellBook.GetSpellBookItemLevelLearned(slot, tab.bank)
                    end
                    if tab.pet then
                        local allowed, enabled = C_SpellBook.GetSpellBookItemAutoCast(slot, tab.bank)
                        entry.autoAllowed, entry.autoOn = allowed, enabled
                    end
                    list[#list + 1] = entry
                end
            end
        end
    end
    return list
end

-- Spell card (secure button) --------------------------------------------------------------------

local function Card(i)
    if cards[i] then return cards[i] end
    local UI = ns.UI
    local card = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    card:RegisterForClicks("AnyUp", "AnyDown")
    card:RegisterForDrag("LeftButton")
    card:SetHeight(CARD_H)
    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    card.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD))
    ns.AddBorder(card)
    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(36, 36)
    holder:SetPoint("LEFT", 6, 0)
    ns.AddSlotBackground(holder)
    card.edges = ns.AddBorder(holder)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.mask = holder:CreateMaskTexture()
    card.mask:SetAllPoints()
    card.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    card.name = UI.Text(card, 13, "LEFT", ns.PARCHMENT_TEXT)
    card.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -3)
    card.name:SetPoint("RIGHT", -8, 0)
    card.name:SetWordWrap(false)
    card.sub = UI.Text(card, 11, "LEFT", { 0.7, 0.65, 0.56 })
    card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
    card:HookScript("OnEnter", function(self)
        self.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD_HOVER))
        if not self.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellBookItem(self.entry.slot, self.entry.bank)
        GameTooltip:Show()
    end)
    card:HookScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD))
        GameTooltip:Hide()
    end)
    -- Shift-click: link into chat (secure action does nothing on shift)
    card:HookScript("OnClick", function(self, _, down)
        if down or not (self.entry and IsModifiedClick("CHATLINK")) then return end
        local link = C_SpellBook.GetSpellBookItemLink(self.entry.slot, self.entry.bank)
        if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
    end)
    card:SetScript("OnDragStart", function(self)
        if self.entry and not self.entry.future and not InCombatLockdown() then
            C_SpellBook.PickupSpellBookItem(self.entry.slot, self.entry.bank)
        end
    end)
    cards[i] = card
    return card
end

local function FillCard(card, entry)
    local UI = ns.UI
    local info = entry.info
    card.entry = entry
    card.icon:SetTexture(info.iconID)
    card.icon:SetDesaturated(entry.future)
    -- passive: round icon
    if info.isPassive then card.icon:AddMaskTexture(card.mask) else card.icon:RemoveMaskTexture(card.mask) end
    card.name:SetText(info.name)
    local sub = info.subName ~= "" and info.subName or nil
    if entry.future then
        card.sub:SetText(entry.level and entry.level > 0 and L["Level %d"]:format(entry.level) or "")
        card.sub:SetTextColor(1, 0.5, 0.25)
    elseif info.isPassive then
        card.sub:SetText(SPELL_PASSIVE or L["Passive"])
        card.sub:SetTextColor(0.7, 0.65, 0.56)
    else
        local text = sub or ""
        if entry.pet and entry.autoAllowed then
            text = text .. (text ~= "" and " · " or "") .. (entry.autoOn and L["Auto on"] or L["Auto off"])
        end
        card.sub:SetText(text)
        card.sub:SetTextColor(0.7, 0.65, 0.56)
    end
    local edge = (entry.pet and entry.autoOn) and UI.ACCENT or { 0, 0, 0 }
    for _, e in ipairs(card.edges) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
    card:SetAlpha(entry.future and 0.55 or 1)
    -- Cast by spell ID; pet spells: right-click toggles autocast
    local castable = not entry.future and not info.isPassive and info.spellID
    card:SetAttribute("type1", castable and "spell" or nil)
    card:SetAttribute("spell1", castable and info.spellID or nil)
    card:SetAttribute("shift-type1", "none")
    if entry.pet and entry.autoAllowed then
        card:SetAttribute("type2", "macro")
        card:SetAttribute("macrotext2", "/petautocasttoggle " .. info.name)
    else
        card:SetAttribute("type2", castable and "spell" or nil)
        card:SetAttribute("spell2", castable and info.spellID or nil)
    end
end

-- Layout -----------------------------------------------------------------------------------------

local function PerPage()
    local height = panel:GetHeight() - 64 - 44
    return COLS * math.max(1, math.floor((height + GAP) / (CARD_H + GAP)))
end

local function SyncLayer()
    if InCombatLockdown() then return end
    local wanted = window and window:IsShown() or false
    if wanted and not layer.driven then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
        layer.driven = true
    elseif not wanted and layer.driven then
        UnregisterStateDriver(layer, "visibility")
        layer.driven = nil
    end
    layer:SetShown(wanted)
end

local function Layout()
    if not (window and window:IsShown()) then return end
    local UI = ns.UI
    local list = TabList()
    local query = strtrim(searchBox:GetText() or ""):lower()
    if currentTab > #list then currentTab = math.min(2, #list) end
    -- tabs on the right
    for i, entry in ipairs(list) do
        local tab = tabs[i]
        if not tab then
            tab = CreateFrame("Button", nil, window)
            tab:SetSize(40, 40)
            tab:SetPoint("TOPLEFT", window, "TOPRIGHT", 6, -60 - (i - 1) * 46)
            UI.Box(tab, ns.STYLE.panelColor)
            tab.icon = tab:CreateTexture(nil, "ARTWORK")
            tab.icon:SetPoint("TOPLEFT", 2, -2)
            tab.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tab.active = ns.AddBorder(tab, true, 2)
            for _, e in ipairs(tab.active) do e:SetVertexColor(unpack(UI.ACCENT)) end
            tab:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.label or "", 1, 1, 1)
                GameTooltip:Show()
            end)
            tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
            tab:SetScript("OnClick", function(self)
                currentTab, page = self.index, 1
                searchBox:SetText("")
                PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
                window.Refresh()
            end)
            tabs[i] = tab
        end
        tab.index, tab.label = i, entry.name
        tab.icon:SetTexture(entry.icon)
        local active = i == currentTab and query == ""
        for _, e in ipairs(tab.active) do e:SetShown(active) end
        tab.icon:SetDesaturated(not active) -- inactive tabs desaturated (as everywhere)
        tab:Show()
    end
    for i = #list + 1, #tabs do tabs[i]:Hide() end

    local entries = query ~= "" and Spells(list, query) or Spells({ list[currentTab] }, "")
    title:SetText(query ~= "" and L["Search"] or (list[currentTab] and list[currentTab].name or ""))
    local perPage = PerPage()
    local pages = math.max(1, math.ceil(#entries / perPage))
    page = math.min(page, pages)
    pageText:SetText(L["Page %d/%d"]:format(page, pages))
    prevButton:SetEnabled(page > 1)
    nextButton:SetEnabled(page < pages)
    pageText:SetShown(pages > 1)
    prevButton:SetShown(pages > 1)
    nextButton:SetShown(pages > 1)
    footer:SetText(L["%d spells"]:format(#entries))
    combatNote:SetShown(InCombatLockdown())
    if InCombatLockdown() then return end -- secure cards may only be touched out of combat
    local colW = (panel:GetWidth() - 40 - (COLS - 1) * GAP) / COLS
    ns.MirrorRect(layer, panel) -- layer covers the parchment exactly; cards anchor only to it
    local shown = 0
    for n = (page - 1) * perPage + 1, math.min(#entries, page * perPage) do
        shown = shown + 1
        local card = Card(shown)
        card:SetWidth(colW)
        card:ClearAllPoints()
        local col, row = (shown - 1) % COLS, math.floor((shown - 1) / COLS)
        card:SetPoint("TOPLEFT", layer, "TOPLEFT", 20 + col * (colW + GAP), -64 - row * (CARD_H + GAP))
        FillCard(card, entries[n])
        card:Show()
    end
    for i = shown + 1, #cards do cards[i]:Hide() end
    SyncLayer()
end

local function Refresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0, function()
        pendingRefresh = nil
        Layout()
    end)
end

local function CreateOptions()
    local UI = ns.UI
    options = CreateFrame("Frame", nil, window)
    options:SetSize(230, 2 * 28 + 12)
    options:SetPoint("TOPRIGHT", optionsButton, "BOTTOMRIGHT", 0, -4)
    options:SetFrameLevel(window:GetFrameLevel() + 60)
    options:SetFrameStrata("DIALOG")
    UI.Box(options, { 0.078, 0.078, 0.086, 1 })
    options:Hide()
    for i, entry in ipairs({ { key = "passives", label = L["Show passives"] }, { key = "lowRanks", label = L["Show lower ranks"] } }) do
        local row = CreateFrame("Button", nil, options)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", 0, -6 - (i - 1) * 28)
        row:SetPoint("RIGHT", options, "RIGHT")
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.06)
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 12, 0)
        UI.CheckBg(box)
        local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
        tick:SetPoint("CENTER")
        local text = UI.Text(row, 13, "LEFT")
        text:SetPoint("LEFT", box, "RIGHT", 10, 0)
        text:SetText(entry.label)
        row.Update = function() tick:SetShown(Settings()[entry.key] and true or false) end
        row:SetScript("OnClick", function()
            local view = Settings()
            view[entry.key] = not view[entry.key]
            row.Update()
            Refresh()
        end)
        options[i] = row
    end
    options:RegisterEvent("GLOBAL_MOUSE_DOWN")
    options:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not optionsButton:IsMouseOver() then self:Hide() end
    end)
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUISpellbook", WIDTH, ns.NPC_HEIGHT, "spellbook")
    window.Refresh = Refresh
    window.extraRight = 46 -- tabs on the right (40 + 6): neighbor windows keep extra distance

    searchBox = UI.EditBox(window.header, 26)
    searchBox:SetWidth(220)
    local hint = UI.Text(searchBox, 12, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search spells"])
    searchBox:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        page = 1
        Refresh()
    end)
    optionsButton = UI.Button(window.header, L["Display"], function()
        options:SetShown(not options:IsShown())
        for _, row in ipairs(options) do row.Update() end
    end, 100)
    optionsButton:SetHeight(26)
    optionsButton:SetPoint("RIGHT", window.close, "LEFT", -8, 0)
    local chevron = UI.Icon(optionsButton, "ChevronDown", 12, UI.MUTED)
    chevron:SetPoint("RIGHT", -8, 0)
    optionsButton.Text:ClearAllPoints()
    optionsButton.Text:SetPoint("CENTER", -6, 0)
    searchBox:SetPoint("RIGHT", optionsButton, "LEFT", -8, 0)
    CreateOptions()

    -- content on parchment
    panel = ns.CreateParchmentPanel(window)
    panel:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 18)
    panel:SetPoint("BOTTOMRIGHT", -PAD, 46)
    title = UI.Text(panel, 20, "LEFT", { 1, 0.82, 0 })
    title:SetPoint("TOPLEFT", 20, -18)
    pageText = UI.Text(panel, 12, "RIGHT", ns.PARCHMENT_TEXT)
    nextButton = UI.ArrowButton(panel, "right", function() page = page + 1; Refresh() end, 26)
    nextButton:SetPoint("BOTTOMRIGHT", -14, 12)
    prevButton = UI.ArrowButton(panel, "left", function() page = math.max(1, page - 1); Refresh() end, 26)
    prevButton:SetPoint("RIGHT", nextButton, "LEFT", -6, 0)
    pageText:SetPoint("RIGHT", prevButton, "LEFT", -10, 0)
    combatNote = UI.Text(panel, 13, "CENTER", ns.PARCHMENT_TEXT)
    combatNote:SetPoint("CENTER")
    combatNote:SetText(L["Spells are locked in combat."])
    combatNote:Hide()
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        page = math.max(1, page - delta)
        Refresh()
    end)

    -- spell cards on their own layer (see header)
    layer = CreateFrame("Frame", "MeredanUISpellbookCards", UIParent, "SecureHandlerStateTemplate")
    layer:SetFrameStrata("DIALOG")
    ns.FollowFrame(layer, panel) -- not SetAllPoints: would make the window protected too (Core.lua)
    layer:Hide()

    footer = UI.Text(window, 12, "LEFT", UI.MUTED)
    footer:SetPoint("BOTTOMLEFT", PAD, 20)
    local footerHint = UI.Text(window, 12, "RIGHT", UI.MUTED)
    footerHint:SetPoint("BOTTOMRIGHT", -PAD, 20)
    footerHint:SetText(L["Drag: onto the action bar · Click: cast · Shift-click: into chat"])

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        local icon = "Interface\\Icons\\ClassIcon_" .. class:sub(1, 1) .. class:sub(2):lower()
        window:SetNpc(nil, SPELLBOOK or L["Spellbook"], (color and color:WrapTextInColorCode(UnitClass("player")) or UnitClass("player"))
            .. "  ·  " .. L["Level %d"]:format(UnitLevel("player")), icon)
        Layout()
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
        options:Hide()
        searchBox:SetText("")
        SyncLayer()
    end)
end

local function Toggle()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
end
ns.ToggleSpellbook = Toggle

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    local toggle = CreateFrame("Button", "MeredanUISpellbookToggle", UIParent)
    toggle:SetScript("OnClick", Toggle)
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        ClearOverrideBindings(toggle)
        for _, key in ipairs({ GetBindingKey("TOGGLESPELLBOOK") }) do
            SetOverrideBindingClick(toggle, false, key, "MeredanUISpellbookToggle", "LeftButton")
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)
    if SpellbookMicroButton then SpellbookMicroButton:SetScript("OnClick", Toggle) end
    for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PET_BAR_UPDATE", "UNIT_PET",
        "PLAYER_LEVEL_UP" }) do
        ns:On(event, function() if window:IsShown() then Refresh() end end)
    end
    ns:On("PLAYER_REGEN_DISABLED", function() if window:IsShown() then Refresh() end end)
    ns:On("PLAYER_REGEN_ENABLED", function()
        C_Timer.After(0, SyncLayer)
        if window:IsShown() then Refresh() end
    end)
end)
