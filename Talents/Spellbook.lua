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

local window, panel, title, footer, pageText, prevButton, nextButton, searchBox, options, optionsButton, layer, combatNote, emptyText, footerHint
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

-- Class trainer tab: what the class trainer teaches, remembered per character from the last visit
-- (Forever's spellbook lists no future spells). Learned spells drop out via IsSpellKnown.
local TRAINER_ICON = 134939 -- inv_scroll_03: a scroll to learn from
local function TrainerCache()
    ns.char.trainerSpells = ns.char.trainerSpells or {}
    return ns.char.trainerSpells
end

local function SnapshotTrainer()
    if not ns.char or (IsTradeskillTrainer and IsTradeskillTrainer()) then return end
    if C_Trainer and C_Trainer.GetTrainerType and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet then return end
    local cache = TrainerCache()
    for index = 1, GetNumTrainerServices() do
        local name, kind, texture, reqLevel, subText = GetTrainerServiceInfo(index)
        local data = C_TooltipInfo.GetTrainerService(index)
        local spellID = data and ns.Readable(data.id) and data.id
        if name and kind ~= "header" and type(spellID) == "number" then
            cache[spellID] = { name = name, rank = subText ~= "" and subText or nil, icon = texture,
                level = reqLevel or 1, cost = (GetTrainerServiceCost(index)) or 0 }
        end
    end
    if window and window:IsShown() then window.Refresh() end
end

-- not learned yet: learnable now first, then by level. From the class data (Talents/TrainerInfo.lua,
-- with advice; upcoming ones for the next few levels), else from the last trainer visit
local AHEAD = 6
local function TrainerEntries()
    local level, list = UnitLevel("player"), {}
    if ns.TrainerInfo and ns.TrainerInfo.Has() then
        for _, w in ipairs(ns.TrainerInfo.Waiting(level, AHEAD)) do
            list[#list + 1] = { trainer = true, future = true, spellID = w.id, ready = w.ready, advice = w.advice,
                spell = { name = w.name, rank = w.rank, icon = w.icon, level = w.level, cost = w.cost, quest = w.quest } }
        end
    else
        for spellID, spell in pairs(TrainerCache()) do
            if not C_SpellBook.IsSpellKnown(spellID) then
                list[#list + 1] = { trainer = true, future = true, spellID = spellID, spell = spell, ready = spell.level <= level }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.ready ~= b.ready then return a.ready end
        if a.spell.level ~= b.spell.level then return a.spell.level < b.spell.level end
        return a.spell.name < b.spell.name
    end)
    return list
end

-- for the level-up display (Toasts/LevelUp.lua): trainer spells reached by now and not learned
function ns.TrainerWaiting(level)
    local list = {}
    if ns.TrainerInfo and ns.TrainerInfo.Has() then return list end -- the level-up display asks TrainerInfo
    if not (ns.char and ns.char.trainerSpells) then return list end
    for _, entry in ipairs(TrainerEntries()) do
        if entry.spell.level <= level then
            local spell = entry.spell
            list[#list + 1] = { name = spell.name, rank = spell.rank, icon = spell.icon, level = spell.level }
        end
    end
    return list
end

-- Tabs: skill lines (General, trees), class trainer and pet ----------------------------------

local function TabList()
    local list = {}
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
        if info and not info.shouldHide and (info.numSpellBookItems or 0) > 0 then
            list[#list + 1] = { name = info.name, icon = info.iconID, offset = info.itemIndexOffset or 0,
                count = info.numSpellBookItems or 0, bank = PLAYER, index = i }
        end
    end
    list[#list + 1] = { name = L["Class trainer"], icon = TRAINER_ICON, trainer = true, index = "trainer", offset = 0, count = 0 }
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
        for slot = tab.offset + 1, tab.trainer and tab.offset or (tab.offset + tab.count) do
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
    card.edges = ns.AddItemFrame(holder, nil, 2)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(holder, card.icon, nil, 2)
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
        if self.entry.trainer then
            self.muiAdviceID = self.entry.spellID -- advice lines: TrainerInfo's tooltip postcall
            GameTooltip:SetSpellByID(self.entry.spellID)
        else
            self.muiAdviceID = nil
            GameTooltip:SetSpellBookItem(self.entry.slot, self.entry.bank)
        end
        GameTooltip:Show()
    end)
    card:HookScript("OnLeave", function(self)
        self.bg:SetColorTexture(unpack(ns.PARCHMENT_CARD))
        GameTooltip:Hide()
    end)
    -- Shift-click: link into chat (secure action does nothing on shift)
    card:HookScript("OnClick", function(self, _, down)
        if down or not (self.entry and IsModifiedClick("CHATLINK")) then return end
        local link = self.entry.trainer and C_Spell.GetSpellLink(self.entry.spellID)
            or C_SpellBook.GetSpellBookItemLink(self.entry.slot, self.entry.bank)
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

local function FillTrainerCard(card, entry)
    local spell = entry.spell
    card.entry = entry
    card.icon:SetTexture(spell.icon)
    card.icon:SetDesaturated(not entry.ready)
    card.icon:RemoveMaskTexture(card.mask)
    card.name:SetText(spell.name)
    local parts = {}
    if spell.rank then parts[#parts + 1] = spell.rank end
    if not entry.ready then
        parts[#parts + 1] = "|cffff5050" .. L["Level %d"]:format(spell.level) .. "|r"
    elseif spell.quest then
        parts[#parts + 1] = "|cffffd100" .. L["Class quest"] .. "|r"
    elseif entry.advice == "s" then
        parts[#parts + 1] = L["You can skip it"]
    else
        parts[#parts + 1] = "|cff33ff33" .. L["Learnable now"] .. "|r"
    end
    if spell.cost > 0 and not spell.quest then parts[#parts + 1] = GetMoneyString(spell.cost, true) end
    card.sub:SetText(table.concat(parts, "  ·  "))
    card.sub:SetTextColor(0.7, 0.65, 0.56)
    -- recommended: gem edge on the icon (accent), skip: dimmed like the upcoming ones
    local edge = entry.advice == "r" and ns.UI.ACCENT or { 0, 0, 0 }
    for _, e in ipairs(card.edges) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
    card:SetAlpha((entry.ready and entry.advice ~= "s") and 1 or 0.55)
    card:SetAttribute("type1", nil)
    card:SetAttribute("spell1", nil)
    card:SetAttribute("shift-type1", "none")
    card:SetAttribute("type2", nil)
    card:SetAttribute("spell2", nil)
end

local function FillCard(card, entry)
    if entry.trainer then return FillTrainerCard(card, entry) end
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
            tab:SetPoint("TOPLEFT", window, "TOPRIGHT", ns.SideTabX(), -60 - (i - 1) * 46)
            ns.AddSlotBackground(tab)
            ns.AddItemFrame(tab, nil, 2)
            tab.icon = tab:CreateTexture(nil, "ARTWORK")
            ns.InsetItemIcon(tab, tab.icon, nil, 2)
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

    local trainerTab = query == "" and list[currentTab] and list[currentTab].trainer
    local entries = query ~= "" and Spells(list, query) or (trainerTab and TrainerEntries()) or Spells({ list[currentTab] }, "")
    emptyText:SetShown(trainerTab and #entries == 0 and not InCombatLockdown())
    footerHint:SetShown(not trainerTab) -- drag/cast hints don't apply to trainer spells
    if trainerTab then
        emptyText:SetText(next(TrainerCache()) and L["Everything learned."]
            or L["Visit your class trainer once to see what you can learn here."])
    end
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
    UI.Box(options, ns.STYLE.panelColor, true)
    ns.RuneFrame(options, { small = true })
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
    emptyText = UI.Text(panel, 13, "CENTER", ns.PARCHMENT_TEXT)
    emptyText:SetPoint("CENTER")
    emptyText:SetWidth(420)
    emptyText:Hide()
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
    footerHint = UI.Text(window, 12, "RIGHT", UI.MUTED)
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
    ns:On("TRAINER_SHOW", function() C_Timer.After(0, SnapshotTrainer) end)
    ns:On("TRAINER_UPDATE", function() C_Timer.After(0, SnapshotTrainer) end)
    ns:On("PLAYER_REGEN_ENABLED", function()
        C_Timer.After(0, SyncLayer)
        if window:IsShown() then Refresh() end
    end)
end)
