-- Berufsfenster (WoW Forever): eigenes Fenster statt Blizzards ProfessionsFrame
-- (Entwurf „Berufe“, Benny 2026-11-06: „stark“).
--
--   ┌ [▣] Kochkunst                                       [x] ┐ [Ü]  ← Reiter rechts: Übersicht und
--   │     Lehrling                                             │ [L]    alle Berufe (Angeln ohne
--   │ [■■■■□□□□ 33 / 75]                          [Filter ˅] │ [K]    Rezepte: blass)
--   │ [Rezepte durchsuchen]   │ [Banner: Blizzards Berufsbild]   │ …
--   │ FAVORITEN               │ [▣] Gewürztes Wolfsfleisch  ★   │
--   │ [▣ Gewürztes Wolf… [3]] │ Benötigt: Kochfeuer             │
--   │ FLEISCH …               │ Beschreibung · Reagenzien 3/1   │
--   │                         │ [Alle erstellen (3)] [−][1][+] [Erstellen] │
--
-- Startseite (Reiter „Übersicht“, Taste K ohne offenen Beruf): Haupt- und Nebenberufe als Karten
-- mit Rangleiste, Zauberknöpfen (sichere Knöpfe: Angeln, Sonnen …) und „Verlernen“.
--
-- Technik: Blizzards ProfessionsFrame wird beim Laden unsichtbar geparkt (prüft nur IsShown, wie
-- Händler/Lehrer). Taste K und der Mikroknopf öffnen direkt unser Fenster (Override-Belegung) –
-- Blizzards Fenster wird nie per Code geöffnet/geschlossen (HideUIPanel verseucht). Rezepte über
-- C_TradeSkillUI (nicht geschützt); Berufswechsel per OpenTradeSkill(skillLine).
local _, ns = ...
local L = ns.L

local WIDTH, PAD = 820, 18
local LIST_W = 340
local ROW_H, ROW_GAP, HEADER_H = 40, 4, 26
local BANNER_H = 110
local SKILL_BLUE = { 0.15, 0.45, 1 }
local DIFFICULTY = { -- Enum.TradeskillRelativeDifficulty: Optimal, Medium, Easy, Trivial
    [0] = { 1, 0.5, 0.25 }, [1] = { 1, 1, 0 }, [2] = { 0.25, 0.75, 0.25 }, [3] = { 0.5, 0.5, 0.5 },
}
local DIFFICULTY_HINT = { [0] = "Sure skill point", [1] = "Usually a skill point", [2] = "Rarely a skill point", [3] = "No skill point" }

-- Blizzards Pfeile für Fertigkeitspunkte (wie im Original-Berufsfenster): orange 3, gelb 2, grün 1
local SKILL_ATLAS = { [0] = "Professions-Icon-Skill-High", [1] = "Professions-Icon-Skill-Medium", [2] = "Professions-Icon-Skill-Low" }

-- Rangleiste: mUI-Rahmen (flach, 1 px) und unsere Schrift, darin Blizzards Füllung aus dem
-- Forever-Berufsbuch (ProfessionsRankBarTemplate: Flipbook-Bild je Beruf, kurze Animation,
-- heller Lichtpunkt an der Spitze) – Benny 2026-11-07: „nur die Textur, nicht den Border“.
-- Von der Vorlage bleiben Füllung, Maske und Lichtpunkt; Rahmen, Hintergrund und Text blenden wir aus.
local function CreateRankBar(parent, width, height)
    local UI = ns.UI
    height = height or 16
    if not C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsTemplates") then C_AddOns.LoadAddOn("Blizzard_ProfessionsTemplates") end
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or 200, height)
    UI.Box(holder, UI.FIELD)
    local ok, bar = pcall(CreateFrame, "Frame", nil, holder, "ProfessionsRankBarTemplate")
    if ok and bar then
        bar.ownerManagesEvents = true -- wir rufen Update selbst auf
        bar:SetAllPoints(holder)
        bar:SetFrameStrata(holder:GetFrameStrata())
        bar:SetFrameLevel(holder:GetFrameLevel() + 1)
        bar.Border:SetAlpha(0)
        bar.Background:SetAlpha(0)
        bar.Rank:Hide()
        if bar.ExpansionDropdownButton then bar.ExpansionDropdownButton:Hide() end
        -- Blizzards Maske ist für ihre 18-px-Leiste gemacht und lässt bei uns nur einen Strich durch.
        -- Stattdessen: Füllung und Lichtpunkt in einen Ausschnitt-Rahmen, dessen Breite der
        -- Maskenbreite folgt (inkl. Blizzards weicher Animation beim Fortschritt).
        local clip = CreateFrame("Frame", nil, holder)
        clip:SetPoint("TOPLEFT", 1, -1)
        clip:SetPoint("BOTTOMLEFT", 1, 1)
        clip:SetWidth(0.01)
        clip:SetClipsChildren(true)
        clip:SetFrameLevel(holder:GetFrameLevel() + 2)
        local inner = CreateFrame("Frame", nil, clip)
        -- Blizzards Füllung hat leicht abgerundete Ecken: 2 px größer als der Ausschnitt (oben,
        -- unten, links), die Rundung liegt so außerhalb und wird abgeschnitten (Benny 2026-11-07)
        inner:SetPoint("TOPLEFT", holder, "TOPLEFT", -1, 1)
        inner:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 1, -1)
        for _, texture in ipairs({ bar.Fill, bar.Flare }) do
            if texture.RemoveMaskTexture then texture:RemoveMaskTexture(bar.Mask) end
            texture:SetParent(inner)
        end
        bar.Fill:ClearAllPoints()
        bar.Fill:SetAllPoints(inner)
        bar.Flare:ClearAllPoints()
        bar.Flare:SetPoint("RIGHT", clip, "RIGHT", 0, 0)
        bar.Flare:SetHeight(height - 2)
        bar.Mask:Hide()
        bar.overrideMaskRightOffset = -2 -- Innenrand unseres Rahmens
        hooksecurefunc(bar.Mask, "SetWidth", function(_, w) clip:SetWidth(math.max(w or 0, 0.01)) end)
        holder.bar = bar
    else
        holder.fill = holder:CreateTexture(nil, "ARTWORK")
        holder.fill:SetPoint("TOPLEFT", 1, -1)
        holder.fill:SetPoint("BOTTOMLEFT", 1, 1)
        holder.fill:SetColorTexture(unpack(SKILL_BLUE))
    end
    -- Text über der Füllung
    local overlay = CreateFrame("Frame", nil, holder)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(holder:GetFrameLevel() + 5)
    holder.text = UI.Text(overlay, height >= 16 and 11 or 10, "CENTER")
    holder.text:SetPoint("CENTER")
    holder.text:SetShadowOffset(1, -1)

    local function Apply(self, force)
        local data = self.data
        if not data then return end
        if self.bar then
            if force then self.bar.ratio = nil end
            if not pcall(self.bar.Update, self.bar, data) then self.bar:Hide() end
        elseif self.fill then
            local ratio = data.maxSkillLevel > 0 and math.min(data.skillLevel / data.maxSkillLevel, 1) or 0
            self.fill:SetShown(ratio > 0)
            self.fill:SetWidth(math.max(self:GetWidth() - 2, 1) * math.max(ratio, 0.001))
        end
    end
    function holder:SetBarWidth(w) self:SetWidth(w) end
    -- info = { name, rank, maxRank, skillLine }
    function holder:SetProfession(info)
        local professionInfo = info.skillLine and C_TradeSkillUI.GetProfessionInfoBySkillLineID
            and C_TradeSkillUI.GetProfessionInfoBySkillLineID(info.skillLine) or nil
        local data = professionInfo and CopyTable(professionInfo) or {}
        data.professionName = info.name or data.professionName or ""
        data.skillLevel = info.rank or data.skillLevel or 0
        data.maxSkillLevel = info.maxRank or data.maxSkillLevel or 0
        data.skillModifier = data.skillModifier or 0
        data.profession = data.profession or info.skillLine
        self.data = data
        self.text:SetText(data.skillLevel .. " / " .. data.maxSkillLevel)
        Apply(self)
    end
    -- neue Breite: Maske neu berechnen
    holder:SetScript("OnSizeChanged", function(self) Apply(self, true) end)
    return holder
end

-- Vergleich mit Ausgerüstetem wie bei Blizzard (Shift bzw. „immer vergleichen“)
local function ShowCompare(tooltip)
    if IsModifiedClick("COMPAREITEMS") or C_CVar.GetCVarBool("alwaysCompareItems") then
        if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(tooltip) end
    elseif GameTooltip_HideShoppingTooltips then
        GameTooltip_HideShoppingTooltips(tooltip)
    end
end

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, tabs = nil, {}
local mode                 -- "overview" oder "recipes"
local tradeOpen            -- Blizzard hat einen Beruf offen (TRADE_SKILL_SHOW … CLOSE)
local keepWindow           -- Wechsel Rezepte > Übersicht: Schließen des Berufs soll das Fenster nicht zumachen
local selectedID, amount = nil, 1
local recipe, overview = {}, {}
local rows, headers, collapsed = {}, {}, {}
local pendingRefresh

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.professionWindow ~= false and C_TradeSkillUI
end

local function Has(name) return C_TradeSkillUI[name] ~= nil end

-- Berufe des Charakters -------------------------------------------------------------------------

-- Haupt- und Nebenberufe in Anzeige-Reihenfolge; spellID des Berufs (erster Zauber) für die Prüfung,
-- ob er ein Rezeptfenster hat (Angeln nicht)
local function Professions()
    local prof1, prof2, faid, fish, cook = GetProfessions()
    local list = {}
    local function Add(index, primary, slot)
        local entry = { primary = primary, slot = slot }
        if index then
            local name, texture, rank, maxRank, numSpells, spellOffset, skillLine, rankModifier = GetProfessionInfo(index)
            entry.name, entry.icon, entry.rank, entry.maxRank = name, texture, rank or 0, maxRank or 0
            entry.numSpells, entry.spellOffset, entry.skillLine, entry.modifier = numSpells or 0, spellOffset or 0, skillLine, rankModifier
            local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
            if info and info.maxSkillLevel and info.maxSkillLevel > 0 then
                entry.rank, entry.maxRank = info.skillLevel, info.maxSkillLevel
            end
            -- Rezepte hat der Beruf, wenn einer seiner Zauber das Rezeptfenster öffnet (Kürschnerei:
            -- erst „Sonnen“, dann „Kürschnerei“ – nicht immer der erste)
            entry.hasRecipes = false
            for i = 1, numSpells or 0 do
                local item = C_SpellBook.GetSpellBookItemInfo(spellOffset + i, Enum.SpellBookSpellBank.Player)
                if item and item.spellID and C_TradeSkillUI.CanTradeSkillShowCraftingUI
                    and C_TradeSkillUI.CanTradeSkillShowCraftingUI(item.spellID) then
                    entry.hasRecipes, entry.spellID = true, item.spellID
                end
            end
        end
        list[#list + 1] = entry
    end
    Add(prof1, true, 1)
    Add(prof2, true, 2)
    Add(cook, false, 3)
    Add(fish, false, 4)
    Add(faid, false, 5)
    return list
end

local function RankName(maxRank)
    local key = ns.PROFESSION_RANK_NAMES and ns.PROFESSION_RANK_NAMES[maxRank]
    return key and L[key] or ""
end

local function OpenProfession(entry)
    if not (entry and entry.skillLine and entry.hasRecipes) then return end
    C_TradeSkillUI.OpenTradeSkill(entry.skillLine)
end

-- Rezeptdaten -----------------------------------------------------------------------------------

local function CurrentProfession()
    local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    if not info or (info.professionID or 0) == 0 then return end
    local rank, maxRank = info.skillLevel or 0, info.maxSkillLevel or 0
    local entryIcon, skillLine
    for _, entry in ipairs(Professions()) do
        if entry.name == info.professionName or entry.skillLine == info.profession then
            entryIcon, skillLine = entry.icon, entry.skillLine
            if maxRank == 0 then rank, maxRank = entry.rank, entry.maxRank end -- Forever liefert teils 0/0
        end
    end
    return { name = info.professionName or "", rank = rank, maxRank = maxRank, icon = entryIcon, skillLine = skillLine }
end

local function CategoryName(id)
    local info = id and C_TradeSkillUI.GetCategoryInfo(id)
    if not info then return "", 0 end
    -- bis zur obersten benannten Kategorie (Blizzard zeigt die Kategorie direkt über dem Rezept)
    return info.name or "", info.uiOrder or 0
end

local function Recipes()
    local groups, order, favorites = {}, {}, {}
    local total, makeable = 0, 0
    for _, id in ipairs(C_TradeSkillUI.GetFilteredRecipeIDs() or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(id)
        if info and info.learned and not info.isDummyRecipe then
            local count = Has("GetCraftableCount") and C_TradeSkillUI.GetCraftableCount(id) or 0
            local entry = { id = id, info = info, count = count or 0 }
            total = total + 1
            if entry.count > 0 then makeable = makeable + 1 end
            if info.favorite then favorites[#favorites + 1] = entry end
            local name, uiOrder = CategoryName(info.categoryID)
            if not groups[name] then
                groups[name] = { name = name, order = uiOrder, entries = {} }
                order[#order + 1] = groups[name]
            end
            table.insert(groups[name].entries, entry)
        end
    end
    table.sort(order, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
    if #favorites > 0 then table.insert(order, 1, { name = L["Favorites"], entries = favorites, favorites = true }) end
    return order, total, makeable
end

local function Reagents(id)
    local list = {}
    local schematic = C_TradeSkillUI.GetRecipeSchematic(id, false)
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local reagent = slot.reagents and slot.reagents[1]
        local basic = not Enum.CraftingReagentType or slot.reagentType == Enum.CraftingReagentType.Basic
        if reagent and reagent.itemID and basic and slot.required ~= false then
            local itemID = reagent.itemID
            list[#list + 1] = { itemID = itemID, need = slot.quantityRequired or 1,
                have = C_Item.GetItemCount(itemID, false) or 0, -- nur Taschen (Benny 2026-11-06)
                name = C_Item.GetItemNameByID(itemID), icon = C_Item.GetItemIconByID(itemID) }
        end
    end
    return list
end

-- Rezeptliste -----------------------------------------------------------------------------------

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, recipe.list.child)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.bg = UI.Box(row, { 0.098, 0.098, 0.106, 1 })
    row.strip = row:CreateTexture(nil, "OVERLAY")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.strip:SetColorTexture(unpack(UI.ACCENT))
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(28, 28)
    holder:SetPoint("LEFT", 6, 0)
    ns.AddBorder(holder)
    row.icon = holder:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.count = UI.Text(row, 12, "RIGHT", UI.MUTED)
    row.count:SetPoint("RIGHT", -10, 0)
    row.star = UI.Text(row, 12, "RIGHT", { 1, 0.82, 0 })
    row.star:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.skill = row:CreateTexture(nil, "ARTWORK")
    row.skill:SetSize(14, 14)
    row.skill:SetPoint("LEFT", holder, "RIGHT", 8, 0)
    row.holder = holder
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("LEFT", holder, "RIGHT", 10, 0)
    row.name:SetPoint("RIGHT", row.star, "LEFT", -6, 0)
    row.name:SetWordWrap(false)
    row:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetColorTexture(0.133, 0.133, 0.149, 1) end end)
    row:SetScript("OnLeave", function(self) if not self.selected then self.bg:SetColorTexture(0.098, 0.098, 0.106, 1) end end)
    row:SetScript("OnClick", function(self, button)
        local id = self.entry and self.entry.id
        if not id then return end
        if IsModifiedClick("CHATLINK") then
            local link = C_TradeSkillUI.GetRecipeLink(id)
            if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
            return
        end
        if button == "RightButton" then -- Favorit an/aus
            C_TradeSkillUI.SetRecipeFavorite(id, not self.entry.info.favorite)
            return
        end
        selectedID, amount = id, 1
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        window.Refresh()
    end)
    rows[i] = row
    return row
end

local function Header(i)
    if headers[i] then return headers[i] end
    local UI = ns.UI
    local header = CreateFrame("Button", nil, recipe.list.child)
    header:SetHeight(HEADER_H)
    header.text = UI.Text(header, 12, "LEFT", UI.ACCENT)
    header.text:SetPoint("LEFT", 8, 0)
    header.sign = UI.Text(header, 14, "RIGHT", UI.MUTED)
    header.sign:SetPoint("RIGHT", -8, 0)
    header:SetScript("OnClick", function(self)
        collapsed[self.key] = not collapsed[self.key] or nil
        window.Refresh()
    end)
    headers[i] = header
    return header
end

-- Details ---------------------------------------------------------------------------------------

local function Banner(name)
    local atlas = ns.ProfessionBannerAtlas and ns.ProfessionBannerAtlas(name)
    local art = recipe.banner.art
    art:SetShown(atlas ~= nil)
    if not atlas then return end
    local info = C_Texture.GetAtlasInfo(atlas)
    art:SetAtlas(atlas)
    local w, h = recipe.banner:GetWidth(), BANNER_H
    local ratio = info.height / info.width
    if w * ratio >= h then art:SetSize(w, w * ratio) else art:SetSize(h / ratio, h) end
end

local function MatCard(i)
    if recipe.mats[i] then return recipe.mats[i] end
    local UI = ns.UI
    local card = CreateFrame("Button", nil, recipe.detail)
    card:SetHeight(34)
    UI.Box(card, { 0.098, 0.098, 0.106, 1 })
    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(26, 26)
    holder:SetPoint("LEFT", 4, 0)
    ns.AddBorder(holder)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.count = UI.Text(card, 12, "RIGHT")
    card.count:SetPoint("RIGHT", -8, 0)
    card.name = UI.Text(card, 12, "LEFT")
    card.name:SetPoint("LEFT", holder, "RIGHT", 8, 0)
    card.name:SetPoint("RIGHT", card.count, "LEFT", -6, 0)
    card.name:SetWordWrap(false)
    card:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card:SetScript("OnClick", function(self)
        if self.itemID and IsModifiedClick() then
            local _, link = C_Item.GetItemInfo(self.itemID)
            HandleModifiedItemClick(link)
        end
    end)
    recipe.mats[i] = card
    return card
end

local function UpdateDetail(entry)
    local UI = ns.UI
    local d = recipe
    d.detail:SetShown(entry ~= nil)
    d.empty:SetShown(entry == nil)
    if not entry then return end
    local id, info = entry.id, entry.info
    local output = Has("GetRecipeOutputItemData") and C_TradeSkillUI.GetRecipeOutputItemData(id) or nil
    d.icon:SetTexture((output and output.icon) or info.icon)
    d.iconButton.link = output and output.hyperlink
    d.name:SetText(info.name or "")
    local color = DIFFICULTY[info.relativeDifficulty or 3] or UI.TEXT
    d.name:SetTextColor(unpack(color))
    -- gesperrt (z. B. Fertigkeit zu niedrig): Blizzards Grund statt „Kein Fertigkeitspunkt mehr“
    -- (Benny 2026-11-08: Dunkle Lederstiefel bei Fertigkeit 40 sahen „fertig“ aus)
    if info.disabled then
        d.hint:SetText("|cffff5050" .. (info.disabledReason or L["Not available yet"]) .. "|r")
    else
        d.hint:SetText(info.relativeDifficulty and L[DIFFICULTY_HINT[info.relativeDifficulty]] or "")
    end
    d.star:SetTextColor(unpack(info.favorite and { 1, 0.82, 0 } or UI.MUTED))
    -- Voraussetzungen (Ort, Werkzeug) und Abklingzeit
    local parts, missing = {}, false
    for _, req in ipairs(Has("GetRecipeRequirements") and C_TradeSkillUI.GetRecipeRequirements(id) or {}) do
        parts[#parts + 1] = (req.met and "|cffe8e6de" or "|cffff5050") .. (req.name or "") .. "|r"
        if not req.met then missing = true end
    end
    local cooldown = Has("GetRecipeCooldown") and C_TradeSkillUI.GetRecipeCooldown(id)
    local text = #parts > 0 and (L["Requires:"] .. " " .. table.concat(parts, ", ")) or ""
    if cooldown and cooldown > 0 then
        text = text .. (text ~= "" and "   " or "") .. "|cffff5050" .. L["Cooldown: %s"]:format(SecondsToTime(cooldown)) .. "|r"
    end
    d.require:SetText(text)
    local description = Has("GetRecipeDescription") and C_TradeSkillUI.GetRecipeDescription(id, {}) or ""
    d.desc:SetText(description or "")
    -- Reagenzien in zwei Spalten
    local mats = Reagents(id)
    local colW = (d.detail:GetWidth() - 32 - 6) / 2
    for i, mat in ipairs(mats) do
        local card = MatCard(i)
        card.itemID = mat.itemID
        card:SetWidth(colW)
        card:ClearAllPoints()
        local col, rowIndex = (i - 1) % 2, math.floor((i - 1) / 2)
        card:SetPoint("TOPLEFT", d.matsLabel, "BOTTOMLEFT", col * (colW + 6), -6 - rowIndex * 40)
        card.icon:SetTexture(mat.icon)
        card.name:SetText(mat.name or "")
        local ok = mat.have >= mat.need
        card.name:SetTextColor(unpack(ok and UI.TEXT or UI.MUTED))
        card.count:SetText(mat.have .. "/" .. mat.need)
        card.count:SetTextColor(unpack(ok and UI.TEXT or { 1, 0.31, 0.31 }))
        card.icon:SetDesaturated(not ok)
        card:Show()
    end
    for i = #mats + 1, #d.mats do d.mats[i]:Hide() end
    d.matsLabel:SetShown(#mats > 0)
    -- Verfolgen, Menge, Erstellen
    local tracked = Has("IsRecipeTracked") and C_TradeSkillUI.IsRecipeTracked(id, false)
    d.trackTick:SetShown(tracked and true or false)
    d.track:SetShown(Has("SetRecipeTracked") and #mats > 0 and not info.isGatheringRecipe)
    local craftable = entry.count
    local canCraft = info.craftable ~= false and not info.disabled and craftable > 0 and not missing
        and not (cooldown and cooldown > 0) and not info.isGatheringRecipe
    amount = math.max(1, math.min(amount, math.max(craftable, 1)))
    d.amount:SetText(amount)
    d.createAll.Text:SetText(L["Create all (%d)"]:format(craftable))
    d.createAll:SetShown(info.canCreateMultiple ~= false and not info.isGatheringRecipe)
    d.createAll.Text:SetTextColor(unpack(canCraft and UI.TEXT or UI.MUTED))
    d.create.Text:SetText(info.abilityVerb ~= "" and info.abilityVerb or (CREATE_PROFESSION or L["Create"]))
    d.create.Text:SetTextColor(unpack(canCraft and UI.ACCENT or UI.MUTED))
    for _, e in ipairs(d.create.accent) do e:SetShown(canCraft) end
    d.canCraft = canCraft
    d.entry = entry
end

local function Craft(count)
    local entry = recipe.entry
    if not (entry and recipe.canCraft) then return end
    C_TradeSkillUI.CraftRecipe(entry.id, count)
end

-- Startseite ------------------------------------------------------------------------------------

-- Zauberknopf (sicher: Angeln, Sonnen, Köder und Angelzubehör …) – Attribute nur außerhalb des Kampfs
-- Zauberkarte wie im mUI-Zauberbuch: Symbol, Name, darunter grau, was der Zauber tut; lässt sich
-- auf die Aktionsleiste ziehen (Benny 2026-11-07: „Mini-Knopf ist nicht gut“)
local SPELL_CARD_H = 48
local function SpellButton(parent, i)
    parent.spells = parent.spells or {}
    if parent.spells[i] then return parent.spells[i] end
    local UI = ns.UI
    -- eigene Ebene (UIParent), damit das Fenster selbst nicht „geschützt“ wird
    local button = CreateFrame("Button", nil, overview.spellLayer, "SecureActionButtonTemplate")
    -- beide Richtungen: mit „Aktionstasten beim Drücken“ (Standard) wirkt der sichere Knopf nur beim
    -- Drücken – nur „AnyUp“ hieß: Klick tut gar nichts (Benny 2026-11-07)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        if self.spellID and not InCombatLockdown() then C_Spell.PickupSpell(self.spellID) end
    end)
    button:SetHeight(SPELL_CARD_H)
    local bg = UI.Box(button)
    local holder = CreateFrame("Frame", nil, button)
    holder:SetSize(36, 36)
    holder:SetPoint("LEFT", 6, 0)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    button.icon = holder:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.text = UI.Text(button, 13, "LEFT")
    button.text:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -3)
    button.text:SetPoint("RIGHT", -8, 0)
    button.text:SetWordWrap(false)
    button.sub = UI.Text(button, 11, "LEFT", UI.MUTED)
    button.sub:SetPoint("TOPLEFT", button.text, "BOTTOMLEFT", 0, -4)
    button.sub:SetPoint("RIGHT", -8, 0)
    button.sub:SetWordWrap(false)
    button:HookScript("OnEnter", function(self)
        bg:SetColorTexture(unpack(UI.HOVER))
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Drag onto an action bar to place it there."], 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end
    end)
    button:HookScript("OnLeave", function()
        bg:SetColorTexture(unpack(UI.FIELD))
        GameTooltip:Hide()
    end)
    parent.spells[i] = button
    return button
end

-- Berufsbild füllt die Karte: eigener Rahmen und runde Ecken der Blizzard-Grafik abgeschnitten
-- (INSET px rundum), Rest auf das Seitenverhältnis der Karte zugeschnitten statt verzerrt
-- (Benny 2026-11-08: kein „Kasten im Kasten“)
local ART_INSET = 12
local function FillArt(tex, atlas)
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    local w, h = tex:GetParent():GetSize()
    if not info or not info.file or w <= 0 or h <= 0 then
        if atlas then tex:SetAtlas(atlas) end
        return
    end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local du, dv = (r - l) / info.width, (b - t) / info.height -- Texturkoordinaten je Bildpixel
    l, r, t, b = l + ART_INSET * du, r - ART_INSET * du, t + ART_INSET * dv, b - ART_INSET * dv
    local artW, artH = info.width - 2 * ART_INSET, info.height - 2 * ART_INSET
    if artW / artH > w / h then -- Bild breiter als Karte: links/rechts weiter kürzen
        local cut = (artW - artH * w / h) / 2 * du
        l, r = l + cut, r - cut
    else                         -- Bild höher: oben/unten kürzen
        local cut = (artH - artW * h / w) / 2 * dv
        t, b = t + cut, b - cut
    end
    tex:SetTexture(info.file)
    tex:SetTexCoord(l, r, t, b)
end

local function Card(slot)
    local UI = ns.UI
    local primary = slot <= 2
    local card = CreateFrame("Frame", nil, overview.frame)
    UI.Box(card, { 0.078, 0.078, 0.086, 1 })
    card.art = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.art:SetAllPoints()
    card.art:SetVertexColor(0.6, 0.6, 0.6) -- Berufsbild sichtbar, aber gedämpft (Benny 2026-11-06)
    card:SetScript("OnSizeChanged", function(self) if self.atlas then FillArt(self.art, self.atlas) end end)
    card.shade = card:CreateTexture(nil, "BACKGROUND", nil, 2)
    card.shade:SetAllPoints()
    card.shade:SetColorTexture(1, 1, 1, 1)
    if primary then
        card.shade:SetGradient("HORIZONTAL", CreateColor(0.06, 0.06, 0.07, 0.9), CreateColor(0.06, 0.06, 0.07, 0.2))
    else
        -- Motiv sitzt unten: oben dunkel (Text), unten hell
        card.shade:SetGradient("VERTICAL", CreateColor(0.06, 0.06, 0.07, 0.15), CreateColor(0.06, 0.06, 0.07, 0.85))
    end
    local holder = CreateFrame("Button", nil, card)
    holder:SetSize(primary and 46 or 36, primary and 46 or 36)
    if primary then holder:SetPoint("LEFT", 14, 0) else holder:SetPoint("TOPLEFT", 14, -14) end
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder:SetScript("OnClick", function() OpenProfession(card.entry) end)
    -- Symbol ziehen = Rezept-Zauber des Berufs (z. B. „Sonnen“) auf die Aktionsleiste
    holder:RegisterForDrag("LeftButton")
    holder:SetScript("OnDragStart", function()
        local entry = card.entry
        if entry and entry.spellID and not InCombatLockdown() then C_Spell.PickupSpell(entry.spellID) end
    end)
    holder:SetScript("OnEnter", function(self)
        if not (card.entry and card.entry.hasRecipes) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        -- Rezept-Zauber heißt teils anders als der Beruf (Kürschnerei: „Sonnen“) – dann dazuschreiben
        local spellName = card.entry.spellID and C_Spell.GetSpellName(card.entry.spellID)
        local extra = spellName and spellName ~= card.entry.name and (" (" .. spellName .. ")") or ""
        GameTooltip:SetText(L["Open recipes"] .. extra, 1, 1, 1)
        GameTooltip:AddLine(L["Drag onto an action bar to place it there."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.holder = holder
    card.name = UI.Text(card, primary and 15 or 14, "LEFT")
    card.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -4)
    card.rankName = UI.Text(card, primary and 12 or 11, "LEFT", UI.MUTED)
    card.rankName:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
    if primary then
        -- wie Blizzard: oben der Berufsname, links darunter die Fähigkeiten untereinander
        -- (Kürschnerei: „Sonnen“ = Rezepte, „Kürschnerei“ = Fähigkeit), rechts die Leiste
        holder:Hide()
        card.name:ClearAllPoints()
        card.name:SetPoint("TOPLEFT", 14, -10)
        card.rankName:ClearAllPoints()
        card.rankName:SetPoint("BOTTOMLEFT", card.name, "BOTTOMRIGHT", 8, 0)
    end
    card.bar = CreateFrame("StatusBar", nil, card)
    card.bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    card.bar:SetStatusBarColor(unpack(SKILL_BLUE))
    card.bar:SetHeight(primary and 16 or 14)
    UI.Box(card.bar, UI.FIELD)
    card.bar.text = UI.Text(card.bar, primary and 11 or 10, "CENTER")
    card.bar.text:SetPoint("CENTER")
    card.rankBar = CreateRankBar(card, 200, primary and 16 or 14)
    card.rankBar:SetAllPoints(card.bar)
    if primary then
        card.bar:SetPoint("LEFT", card, "LEFT", 270, 6)
        card.bar:SetPoint("RIGHT", card, "RIGHT", -50, 0)
        -- Verlernen: rotes X wie bei Blizzard (Benny 2026-11-06), auf Höhe der Rangleiste
        local RED, RED_HOVER = { 0.9, 0.25, 0.25 }, { 1, 0.45, 0.45 }
        card.unlearn = CreateFrame("Button", nil, card)
        card.unlearn:SetSize(22, 22)
        card.unlearn:SetPoint("LEFT", card.bar, "RIGHT", 14, 0)
        local unlearnBg = UI.Box(card.unlearn)
        local cross = UI.Icon(card.unlearn, "Close", 14, RED)
        cross:SetPoint("CENTER")
        card.unlearn:SetScript("OnClick", function()
            if card.entry then StaticPopup_Show("UNLEARN_SKILL", card.entry.name, nil, card.entry.skillLine) end
        end)
        card.unlearn:SetScript("OnEnter", function(self)
            unlearnBg:SetColorTexture(unpack(UI.HOVER))
            cross:SetVertexColor(unpack(RED_HOVER))
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Unlearn"], 1, 0.38, 0.38)
            GameTooltip:Show()
        end)
        card.unlearn:SetScript("OnLeave", function()
            unlearnBg:SetColorTexture(unpack(UI.FIELD))
            cross:SetVertexColor(unpack(RED))
            GameTooltip:Hide()
        end)
    else
        card.bar:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -12)
        card.bar:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    end
    card.empty = UI.Text(card, 12, "LEFT", UI.MUTED)
    card.empty:SetPoint("LEFT", holder, "RIGHT", 10, 0)
    card.empty:SetText(L["No profession learned"])
    card.primary = primary
    overview.cards[slot] = card
    return card
end

local function FillCard(card, entry)
    card.entry = entry.name and entry or nil
    local has = card.entry ~= nil
    card.empty:SetShown(not has)
    card.name:SetShown(has)
    card.rankName:SetShown(has)
    card.bar:SetShown(has)
    if card.rankBar then card.rankBar:SetShown(has) end
    if card.unlearn then card.unlearn:SetShown(has) end
    card.icon:SetTexture(has and entry.icon or 134400)
    card.icon:SetDesaturated(not has)
    if card.primary then card.holder:SetShown(not has) end
    local atlas = has and ns.ProfessionBannerAtlas and ns.ProfessionBannerAtlas(entry.name)
    card.art:SetShown(atlas and true or false)
    card.atlas = atlas or nil
    if atlas then FillArt(card.art, atlas) end
    if not has then
        if not InCombatLockdown() then
            for _, button in ipairs(card.spells or {}) do button:Hide() end
        end
        return
    end
    card.name:SetText(entry.name)
    card.rankName:SetText(RankName(entry.maxRank))
    card.bar:SetMinMaxValues(0, math.max(entry.maxRank, 1))
    card.bar:SetValue(entry.rank)
    card.bar.text:SetText(entry.rank .. " / " .. entry.maxRank)
    if card.rankBar then
        -- Original-Leiste über der schlichten (gleiche Lage und Breite)
        card.bar:SetAlpha(0)
        card.rankBar:SetProfession({ name = entry.name, rank = entry.rank, maxRank = entry.maxRank, skillLine = entry.skillLine })
        card.rankBar:Show()
    end
    -- Zauber des Berufs (ohne den Beruf selbst – den öffnet das Symbol), nur außerhalb des Kampfs setzen
    if InCombatLockdown() then return end
    ns.MirrorRect(overview.spellLayer, overview.frame)
    -- Zauber des Berufs als Karten – ohne den Rezept-Zauber (den öffnet das Berufssymbol links)
    local spells = {}
    for i = 1, entry.numSpells do
        local item = C_SpellBook.GetSpellBookItemInfo(entry.spellOffset + i, Enum.SpellBookSpellBank.Player)
        if item and item.spellID and not item.isPassive then
            if item.spellID ~= entry.spellID then spells[#spells + 1] = item
            elseif card.primary then table.insert(spells, 1, item) end -- Hauptberuf: Rezept-Zauber oben links
        end
    end
    local shown = 0
    for _, item in ipairs(spells) do
        shown = shown + 1
        local button = SpellButton(card, shown)
        button.spellID = item.spellID
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", item.spellID)
        button.icon:SetTexture(item.iconID)
        button.text:SetText(item.name or "")
        -- Rang steht schon oben beim Beruf – hier nur sagen, dass es eine Fähigkeit ist (Benny 2026-11-07:
        -- zweimal „Kürschnerei · Lehrling“ verwirrt)
        local sub = item.spellID == entry.spellID and L["Open recipes"] or L["Ability"]
        button.sub:SetText(sub or "")
        button.text:ClearAllPoints()
        button.text:SetPoint(sub and "TOPLEFT" or "LEFT", button.icon, sub and "TOPRIGHT" or "RIGHT", 10, sub and -3 or 0)
        button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button:ClearAllPoints()
        if card.primary then
            button:SetWidth(236)
            button:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -32 - (shown - 1) * (SPELL_CARD_H + 6))
        else
            button:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 12 + (shown - 1) * (SPELL_CARD_H + 6))
            button:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        end
        -- Lage an der Karte ausrechnen, dann nur an der Ebene verankern (sonst wäre das Fenster geschützt)
        ns.MirrorRect(button, button, overview.spellLayer)
        button:Show()
    end
    for i = shown + 1, #(card.spells or {}) do card.spells[i]:Hide() end
end

-- Zauberknöpfe nur mit sichtbarer Startseite (außerhalb des Kampfs; im Kampf blendet der
-- Zustandstreiber die Ebene ohnehin aus)
-- Der Zustandstreiber („im Kampf aus“) läuft nur, solange die Startseite offen ist – sonst würde er
-- die Ebene beim Einloggen bzw. nach dem Kampf zeigen, auch ohne Fenster (Benny 2026-11-06)
local function SyncSpellLayer()
    local layer = overview.spellLayer
    if not layer or InCombatLockdown() then return end
    local wanted = window and window:IsShown() and mode == "overview" or false
    if wanted and not layer.driven then
        RegisterStateDriver(layer, "visibility", "[combat] hide; show")
        layer.driven = true
    elseif not wanted and layer.driven then
        UnregisterStateDriver(layer, "visibility")
        layer.driven = nil
    end
    layer:SetShown(wanted)
end

local function LayoutOverview()
    local list = Professions()
    local primaries, secondaries = 0, 0
    for _, entry in ipairs(list) do
        FillCard(overview.cards[entry.slot], entry)
        if entry.name then
            if entry.primary then primaries = primaries + 1 else secondaries = secondaries + 1 end
        end
    end
    window:SetNpc(nil, PROFESSIONS_BUTTON or TRADE_SKILLS or L["Professions"],
        L["%d primary · %d secondary professions"]:format(primaries, secondaries), "Interface\\Icons\\INV_Misc_Book_09")
end

-- Reiter rechts ---------------------------------------------------------------------------------

local function Tab(i)
    if tabs[i] then return tabs[i] end
    local UI = ns.UI
    local tab = CreateFrame("Button", nil, window)
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
        if self.entry and not self.entry.hasRecipes then GameTooltip:AddLine(L["No recipes – use the spell on the overview."], 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tab:SetScript("OnClick", function(self)
        if self.overview then
            if tradeOpen then
                keepWindow = true
                C_TradeSkillUI.CloseTradeSkill()
            end
            mode = "overview"
            window.Refresh()
        else
            OpenProfession(self.entry)
        end
    end)
    tabs[i] = tab
    return tab
end

local function LayoutTabs(currentName)
    local overviewTab = Tab(1)
    overviewTab.overview, overviewTab.label = true, L["Overview"]
    overviewTab.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    for _, e in ipairs(overviewTab.active) do e:SetShown(mode == "overview") end
    overviewTab.icon:SetDesaturated(mode ~= "overview") -- inaktive Reiter grau (wie überall)
    local n = 1
    for _, entry in ipairs(Professions()) do
        if entry.name then
            n = n + 1
            local tab = Tab(n)
            tab.entry, tab.label = entry, entry.name
            tab.icon:SetTexture(entry.icon)
            local active = mode == "recipes" and entry.name == currentName
            tab.icon:SetDesaturated(not active or not entry.hasRecipes)
            tab.icon:SetAlpha(entry.hasRecipes and 1 or 0.5)
            for _, e in ipairs(tab.active) do e:SetShown(active) end
            tab:Show()
        end
    end
    for i = n + 1, #tabs do tabs[i]:Hide() end
end

-- Aufbau ----------------------------------------------------------------------------------------

local function LayoutRecipes()
    local UI = ns.UI
    local profession = CurrentProfession()
    if not profession then return end
    window:SetNpc(nil, profession.name, RankName(profession.maxRank), profession.icon)
    recipe.bar:SetMinMaxValues(0, math.max(profession.maxRank, 1))
    recipe.bar:SetValue(profession.rank)
    recipe.bar.text:SetText(profession.rank .. " / " .. profession.maxRank)
    if recipe.rankBar then recipe.rankBar:SetProfession(profession) end
    Banner(profession.name)

    local groups, total, makeable = Recipes()
    local y, r, h = 0, 0, 0
    local selected, first
    for _, group in ipairs(groups) do
        local key = group.favorites and "__fav" or group.name
        if group.name ~= "" then
            h = h + 1
            local header = Header(h)
            header.key = key
            header.text:SetText(group.name:upper())
            header.sign:SetText(collapsed[key] and "+" or "−")
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", 0, -y)
            header:SetPoint("RIGHT", recipe.list.child, "RIGHT")
            header:Show()
            y = y + HEADER_H
        end
        if not collapsed[key] then
            for _, entry in ipairs(group.entries) do
                r = r + 1
                local row = Row(r)
                row.entry = entry
                local info = entry.info
                row.icon:SetTexture(info.icon)
                row.name:SetText(info.name)
                row.name:SetTextColor(unpack(DIFFICULTY[info.relativeDifficulty or 3] or UI.TEXT))
                local skillAtlas = info.canSkillUp ~= false and SKILL_ATLAS[info.relativeDifficulty or 3]
                if info.disabled then
                    -- gesperrt: Schloss wie bei Blizzard (UI-LFG-ICON-LOCK), Name gedämpft
                    row.skill:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
                    row.name:SetTextColor(unpack(UI.MUTED))
                    skillAtlas = true
                elseif skillAtlas then
                    row.skill:SetAtlas(skillAtlas)
                end
                row.skill:SetShown(skillAtlas and true or false)
                row.name:SetPoint("LEFT", skillAtlas and row.skill or row.holder, "RIGHT", skillAtlas and 4 or 10, 0)
                row.count:SetText(entry.count > 0 and ("[" .. entry.count .. "]") or "")
                row.star:SetText(info.favorite and "*" or "")
                row.selected = entry.id == selectedID
                row.strip:SetShown(row.selected)
                row.bg:SetColorTexture(unpack(row.selected and { 0.133, 0.133, 0.149, 1 } or { 0.098, 0.098, 0.106, 1 }))
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y)
                row:SetPoint("RIGHT", recipe.list.child, "RIGHT")
                row:Show()
                y = y + ROW_H + ROW_GAP
                if row.selected then selected = entry end
                first = first or entry
            end
        end
    end
    for i = r + 1, #rows do rows[i]:Hide() end
    for i = h + 1, #headers do headers[i]:Hide() end
    recipe.list:SetContentHeight(y)
    if not selected and first then -- erstes Rezept wählen
        selected, selectedID = first, first.id
        for i = 1, r do rows[i].selected = rows[i].entry.id == selectedID end
        LayoutRecipes()
        return
    end
    UpdateDetail(selected)
    recipe.footer:SetText(L["%d recipes · %d makeable"]:format(total, makeable))
end

local function Layout()
    if not (window and window:IsShown()) then return end
    recipe.frame:SetShown(mode == "recipes")
    overview.frame:SetShown(mode == "overview")
    local current = mode == "recipes" and CurrentProfession()
    LayoutTabs(current and current.name)
    if mode == "recipes" then LayoutRecipes() else LayoutOverview() end
    SyncSpellLayer()
end

local function Refresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0, function()
        pendingRefresh = nil
        Layout()
    end)
end

local function ResetFilters()
    if Has("SetRecipeItemNameFilter") then C_TradeSkillUI.SetRecipeItemNameFilter(nil) end
    if Has("SetOnlyShowMakeableRecipes") then C_TradeSkillUI.SetOnlyShowMakeableRecipes(false) end
    if Has("SetOnlyShowSkillUpRecipes") then C_TradeSkillUI.SetOnlyShowSkillUpRecipes(false) end
end

local function CreateFilter()
    local UI = ns.UI
    local button = UI.Button(recipe.frame, L["Filter"], nil, 130)
    button:SetHeight(28)
    local chevron = UI.Icon(button, "ChevronDown", 12, UI.MUTED)
    chevron:SetPoint("RIGHT", -8, 0)
    local menu = CreateFrame("Frame", nil, recipe.frame)
    menu:SetSize(220, 2 * 28 + 12)
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -4)
    menu:SetFrameLevel(recipe.frame:GetFrameLevel() + 40)
    UI.Box(menu, { 0.078, 0.078, 0.086, 1 })
    menu:Hide()
    local options = {
        { label = L["Only with skill point"], get = "GetOnlyShowSkillUpRecipes", set = "SetOnlyShowSkillUpRecipes" },
        { label = L["Only makeable"], get = "GetOnlyShowMakeableRecipes", set = "SetOnlyShowMakeableRecipes" },
    }
    local function Update()
        local any = false
        for _, entry in ipairs(options) do
            local on = Has(entry.get) and C_TradeSkillUI[entry.get]() or false
            entry.tick:SetShown(on)
            any = any or on
        end
        for _, e in ipairs(button.focusEdges) do e:SetShown(any) end
    end
    button.focusEdges = ns.AddBorder(button, true)
    for _, e in ipairs(button.focusEdges) do e:SetVertexColor(unpack(UI.ACCENT)) end
    for i, entry in ipairs(options) do
        local row = CreateFrame("Button", nil, menu)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", 0, -6 - (i - 1) * 28)
        row:SetPoint("RIGHT", menu, "RIGHT")
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.06)
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 12, 0)
        UI.CheckBg(box)
        entry.tick = UI.Icon(box, "Check", 12, UI.ACCENT)
        entry.tick:SetPoint("CENTER")
        local text = UI.Text(row, 13, "LEFT")
        text:SetPoint("LEFT", box, "RIGHT", 10, 0)
        text:SetText(entry.label)
        row:SetScript("OnClick", function()
            if not (Has(entry.get) and Has(entry.set)) then return end
            C_TradeSkillUI[entry.set](not C_TradeSkillUI[entry.get]())
            Update()
        end)
    end
    button:SetScript("OnClick", function()
        Update()
        menu:SetShown(not menu:IsShown())
    end)
    menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
    menu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not button:IsMouseOver() then self:Hide() end
    end)
    recipe.filterUpdate = Update
    recipe.filterMenu = menu
    return button
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIProfessions", WIDTH, ns.NPC_HEIGHT, "professions")
    window.Refresh = Refresh
    window.extraRight = 46 -- Reiter rechts (40 + 6): Nachbarfenster rücken weiter weg
    ns.WatchBlizzardFrame(window, function()
        -- nur solange ein Beruf offen ist: Blizzards (geparktes) Fenster gibt den Takt vor
        return mode == "recipes" and tradeOpen and ProfessionsFrame or nil
    end)
    local top = ns.NPC_HEADER_BOTTOM + 16

    -- Rezeptseite
    recipe.frame = CreateFrame("Frame", nil, window)
    recipe.frame:SetPoint("TOPLEFT", 0, -top)
    recipe.frame:SetPoint("BOTTOMRIGHT")
    recipe.rankBar = CreateRankBar(recipe.frame, LIST_W, 16) -- so breit wie die Suche darunter
    recipe.rankBar:SetPoint("TOPLEFT", PAD, 0)
    recipe.bar = CreateFrame("StatusBar", nil, recipe.frame)
    recipe.bar:SetSize(LIST_W, 16)
    recipe.bar:SetPoint("TOPLEFT", PAD, 0)
    recipe.bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    recipe.bar:SetStatusBarColor(unpack(SKILL_BLUE))
    UI.Box(recipe.bar, UI.FIELD)
    recipe.bar.text = UI.Text(recipe.bar, 11, "CENTER")
    recipe.bar.text:SetPoint("CENTER")
    recipe.bar:SetShown(recipe.rankBar == nil)
    local filter = CreateFilter()
    filter:SetPoint("TOPRIGHT", -PAD, 6)

    recipe.search = UI.EditBox(recipe.frame, 30)
    recipe.search:SetPoint("TOPLEFT", PAD, -30)
    recipe.search:SetWidth(LIST_W)
    local hint = UI.Text(recipe.search, 13, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search recipes"])
    recipe.search:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        hint:SetShown(text == "")
        if Has("SetRecipeItemNameFilter") then C_TradeSkillUI.SetRecipeItemNameFilter(text ~= "" and text or nil) end
    end)
    recipe.list = UI.ScrollArea(recipe.frame)
    recipe.list:SetPoint("TOPLEFT", recipe.search, "BOTTOMLEFT", 0, -8)
    recipe.list:SetPoint("BOTTOMLEFT", PAD, 46)
    recipe.list:SetWidth(LIST_W - 8)
    recipe.list.child:SetWidth(LIST_W - 8)

    -- Details rechts
    local panel = CreateFrame("Frame", nil, recipe.frame)
    panel:SetPoint("TOPLEFT", recipe.search, "TOPRIGHT", 14, 0)
    panel:SetPoint("BOTTOMRIGHT", -PAD, 46)
    UI.Box(panel, { 0.078, 0.078, 0.086, 1 })
    recipe.banner = CreateFrame("Frame", nil, panel)
    recipe.banner:SetPoint("TOPLEFT", 1, -1)
    recipe.banner:SetPoint("TOPRIGHT", -1, -1)
    recipe.banner:SetHeight(BANNER_H)
    recipe.banner:SetClipsChildren(true)
    recipe.banner.art = recipe.banner:CreateTexture(nil, "BACKGROUND")
    recipe.banner.art:SetPoint("CENTER")
    recipe.banner.art:SetVertexColor(0.45, 0.45, 0.45)
    local line = recipe.banner:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(ns.PixelSize())
    line:SetColorTexture(0, 0, 0, 1)
    recipe.detail = CreateFrame("Frame", nil, panel)
    recipe.detail:SetAllPoints()
    recipe.empty = UI.Text(panel, 13, "CENTER", UI.MUTED)
    recipe.empty:SetPoint("CENTER", 0, -30)
    recipe.empty:SetText(L["No recipes."])
    local d = recipe
    d.iconButton = CreateFrame("Button", nil, d.detail)
    d.iconButton:SetSize(56, 56)
    d.iconButton:SetPoint("TOPLEFT", 16, -(BANNER_H - 28))
    d.iconButton:SetFrameLevel(recipe.banner:GetFrameLevel() + 5)
    ns.AddSlotBackground(d.iconButton)
    ns.AddBorder(d.iconButton)
    d.icon = d.iconButton:CreateTexture(nil, "ARTWORK")
    d.icon:SetAllPoints()
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.iconButton:SetScript("OnEnter", function(self)
        if not d.entry then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if GameTooltip.SetRecipeResultItem then GameTooltip:SetRecipeResultItem(d.entry.id) elseif self.link then GameTooltip:SetHyperlink(self.link) end
        GameTooltip:Show()
        ShowCompare(GameTooltip)
        self:RegisterEvent("MODIFIER_STATE_CHANGED")
    end)
    d.iconButton:SetScript("OnLeave", function(self)
        self:UnregisterEvent("MODIFIER_STATE_CHANGED")
        GameTooltip:Hide()
    end)
    d.iconButton:SetScript("OnEvent", function(self)
        if GameTooltip:IsOwned(self) then ShowCompare(GameTooltip) end
    end)
    d.iconButton:SetScript("OnClick", function(self) if self.link and IsModifiedClick() then HandleModifiedItemClick(self.link) end end)
    d.starButton = CreateFrame("Button", nil, d.detail)
    d.starButton:SetSize(26, 26)
    d.starButton:SetPoint("TOPRIGHT", -10, -10)
    d.starButton:SetFrameLevel(recipe.banner:GetFrameLevel() + 5)
    UI.Box(d.starButton, { 0, 0, 0, 0.55 })
    d.star = UI.Text(d.starButton, 16, "CENTER")
    d.star:SetPoint("CENTER", 0, -2)
    d.star:SetText("*")
    d.starButton:SetScript("OnClick", function()
        if d.entry then C_TradeSkillUI.SetRecipeFavorite(d.entry.id, not d.entry.info.favorite) end
    end)
    d.starButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["Favorite"], 1, 1, 1)
        GameTooltip:Show()
    end)
    d.starButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    d.name = UI.Text(d.detail, 17, "LEFT")
    d.name:SetPoint("TOPLEFT", d.iconButton, "BOTTOMLEFT", 0, -10)
    d.name:SetPoint("RIGHT", -16, 0)
    d.hint = UI.Text(d.detail, 12, "LEFT", UI.MUTED)
    d.hint:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
    d.require = UI.Text(d.detail, 12, "LEFT", UI.MUTED)
    d.require:SetPoint("TOPLEFT", d.hint, "BOTTOMLEFT", 0, -10)
    d.require:SetPoint("RIGHT", -16, 0)
    d.desc = UI.Text(d.detail, 12, "LEFT", { 0.79, 0.78, 0.75 })
    d.desc:SetPoint("TOPLEFT", d.require, "BOTTOMLEFT", 0, -8)
    d.desc:SetPoint("RIGHT", -16, 0)
    d.desc:SetWordWrap(true)
    d.desc:SetSpacing(2)
    d.matsLabel = UI.Text(d.detail, 12, "LEFT", UI.ACCENT)
    d.matsLabel:SetPoint("TOPLEFT", d.desc, "BOTTOMLEFT", 0, -12)
    d.matsLabel:SetText(L["Reagents"])
    d.mats = {}
    -- unten: Verfolgen, Alle erstellen, Menge, Erstellen
    d.create = UI.Button(d.detail, "", function() Craft(amount) end, 110)
    d.create:SetHeight(30)
    d.create:SetPoint("BOTTOMRIGHT", -14, 14)
    d.create.accent = ns.AddBorder(d.create, true)
    for _, e in ipairs(d.create.accent) do e:SetVertexColor(unpack(UI.ACCENT)) end
    local plus = UI.Button(d.detail, "+", function()
        amount = amount + 1
        UpdateDetail(d.entry)
    end, 26)
    plus:SetHeight(30)
    plus:SetPoint("RIGHT", d.create, "LEFT", -8, 0)
    local box = CreateFrame("Frame", nil, d.detail)
    box:SetSize(44, 30)
    box:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    UI.Box(box, UI.FIELD)
    d.amount = UI.Text(box, 13, "CENTER")
    d.amount:SetPoint("CENTER")
    local minus = UI.Button(d.detail, "−", function()
        amount = math.max(1, amount - 1)
        UpdateDetail(d.entry)
    end, 26)
    minus:SetHeight(30)
    minus:SetPoint("RIGHT", box, "LEFT", -4, 0)
    d.createAll = UI.Button(d.detail, "", function() if d.entry then Craft(d.entry.count) end end, 10)
    d.createAll:SetHeight(30)
    d.createAll:SetWidth(130)
    d.createAll:SetPoint("BOTTOMLEFT", 14, 14)
    d.track = CreateFrame("Button", nil, d.detail)
    d.track:SetSize(260, 18)
    d.track:SetPoint("BOTTOMLEFT", d.createAll, "TOPLEFT", 0, 10)
    local trackBox = CreateFrame("Frame", nil, d.track)
    trackBox:SetSize(14, 14)
    trackBox:SetPoint("LEFT")
    UI.CheckBg(trackBox)
    d.trackTick = UI.Icon(trackBox, "Check", 12, UI.ACCENT)
    d.trackTick:SetPoint("CENTER")
    local trackText = UI.Text(d.track, 12, "LEFT", UI.MUTED)
    trackText:SetPoint("LEFT", trackBox, "RIGHT", 8, 0)
    trackText:SetText(L["Track in quest log (missing reagents)"])
    d.track:SetScript("OnClick", function()
        if not d.entry then return end
        C_TradeSkillUI.SetRecipeTracked(d.entry.id, not C_TradeSkillUI.IsRecipeTracked(d.entry.id, false), false)
        UpdateDetail(d.entry)
    end)
    recipe.footer = UI.Text(recipe.frame, 12, "LEFT", UI.MUTED)
    recipe.footer:SetPoint("BOTTOMLEFT", PAD, 20)
    local footerHint = UI.Text(recipe.frame, 12, "RIGHT", UI.MUTED)
    footerHint:SetPoint("BOTTOMRIGHT", -PAD, 20)
    footerHint:SetText(L["Right-click: favorite · Shift-click: into chat"])

    -- Startseite
    overview.frame = CreateFrame("Frame", nil, window)
    overview.frame:SetPoint("TOPLEFT", PAD, -top)
    overview.frame:SetPoint("BOTTOMRIGHT", -PAD, 16)
    overview.cards = {}
    overview.spellLayer = CreateFrame("Frame", "MeredanUIProfessionSpells", UIParent, "SecureHandlerStateTemplate")
    overview.spellLayer:SetFrameStrata("DIALOG") -- immer über dem Fenster, auch wenn es nach vorn geholt wird
    ns.FollowFrame(overview.spellLayer, overview.frame) -- nicht SetAllPoints (Core.lua)
    overview.spellLayer:Hide()
    local primaryLabel = UI.Text(overview.frame, 12, "LEFT", UI.ACCENT)
    primaryLabel:SetPoint("TOPLEFT")
    primaryLabel:SetText(L["Primary professions"])
    for slot = 1, 2 do
        local card = Card(slot)
        card:SetHeight(144)
        card:SetPoint("TOPLEFT", 0, -20 - (slot - 1) * 152)
        card:SetPoint("RIGHT", overview.frame, "RIGHT")
    end
    local secondaryLabel = UI.Text(overview.frame, 12, "LEFT", UI.ACCENT)
    secondaryLabel:SetPoint("TOPLEFT", 0, -20 - 2 * 152 - 6)
    secondaryLabel:SetText(L["Secondary professions"])
    local colW = (WIDTH - 2 * PAD - 20) / 3
    for i = 1, 3 do
        local card = Card(2 + i)
        card:SetSize(colW, 166)
        card:SetPoint("TOPLEFT", (i - 1) * (colW + 10), -20 - 2 * 152 - 26)
    end
    local overviewHint = UI.Text(overview.frame, 11, "LEFT", UI.MUTED)
    overviewHint:SetPoint("BOTTOMLEFT", 0, 4)
    overviewHint:SetText(L["Click a profession icon to open its recipes · buttons cast the spell (Fishing …)"])

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        Layout()
    end)
    window:HookScript("OnHide", function()
        SyncSpellLayer()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        recipe.filterMenu:Hide()
        recipe.search:SetText("")
        ResetFilters()
        if tradeOpen then C_TradeSkillUI.CloseTradeSkill() end
    end)
end

-- Öffnen/Schließen ------------------------------------------------------------------------------

local function ShowOverview()
    if not window then CreateWindow() end
    mode = "overview"
    if window:IsShown() then Refresh() else window:Show() end
end

-- Die Startseite hat sichere Zauberknöpfe: damit gilt das Fenster als geschützt und lässt sich im
-- Kampf nicht öffnen/schließen – dann nach dem Kampf
local function Blocked(fn)
    if InCombatLockdown() and window and window:IsProtected() then
        ns.AfterCombat(fn)
        return true
    end
end

local function Toggle()
    if Blocked(Toggle) then return end
    if window and window:IsShown() then
        window:Hide()
    else
        ShowOverview()
    end
end
ns.ToggleProfessions = Toggle

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    -- Blizzards Fenster unsichtbar parken, sobald es geladen ist (lädt bei Bedarf)
    EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
        if ProfessionsFrame then ProfessionsFrame:SetParent(hidden) end
    end)
    -- Taste K und der Mikroknopf: direkt unser Fenster (Startseite)
    local toggle = CreateFrame("Button", "MeredanUIProfessionsToggle", UIParent)
    toggle:SetScript("OnClick", Toggle)
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        ClearOverrideBindings(toggle)
        for _, key in ipairs({ GetBindingKey("TOGGLEPROFESSIONBOOK") }) do
            SetOverrideBindingClick(toggle, false, key, "MeredanUIProfessionsToggle", "LeftButton")
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)
    if ProfessionMicroButton then ProfessionMicroButton:SetScript("OnClick", Toggle) end

    ns:On("TRADE_SKILL_SHOW", function()
        tradeOpen = true
        mode = "recipes"
        selectedID, amount = nil, 1
        local function Open()
            if Blocked(Open) then return end
            if window:IsShown() then Refresh() else window:Show() end
        end
        C_Timer.After(0, Open)
    end)
    ns:On("TRADE_SKILL_CLOSE", function()
        tradeOpen = false
        C_Timer.After(0.1, function()
            if tradeOpen then return end -- Wechsel zu einem anderen Beruf
            if keepWindow then
                keepWindow = nil
                return
            end
            if mode == "recipes" and window:IsShown() and not (InCombatLockdown() and window:IsProtected()) then window:Hide() end
        end)
    end)
    ns:On("TRADE_SKILL_DATA_SOURCE_CHANGED", function() selectedID = nil; Refresh() end)
    ns:On("TRADE_SKILL_LIST_UPDATE", function()
        if C_TradeSkillUI.IsDataSourceChanging and C_TradeSkillUI.IsDataSourceChanging() then return end
        if window:IsShown() then Refresh() end
    end)
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "TRADE_SKILL_FAVORITES_CHANGED", "TRACKED_RECIPE_UPDATE",
        "SKILL_LINES_CHANGED", "UPDATE_TRADESKILL_CAST_STOPPED", "GET_ITEM_INFO_RECEIVED" }) do
        ns:On(event, function() if window:IsShown() then Refresh() end end)
    end
    -- nach dem Kampf zeigt der Zustandstreiber die Zauber-Ebene wieder – passend zum Fenster setzen
    ns:On("PLAYER_REGEN_ENABLED", function()
        C_Timer.After(0, SyncSpellLayer)
        if window:IsShown() then Refresh() end
    end)
end)
