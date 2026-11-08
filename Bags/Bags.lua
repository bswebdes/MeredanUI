-- Taschen: ein Fenster statt Blizzards Einzeltaschen. Drei Stile (Einstellungen > Taschen):
-- Abschnitte nach Kategorien (unten, Standard), eine große sortierte Tasche oder je Tasche ein
-- Kasten – siehe „Stile“ weiter unten.
--
--   ┌ Taschen ──────────────────────── ▢ 42  [x] ┐
--   │ [Suche ...................................]   │
--   │ Neu              Ausrüstung                   │
--   │ [■][■]           [■][■][■][■]                 │
--   │ Fläschchen       Kräuter          Verbrauchbar│
--   │ [■][■]           [■][■][■]        [■][■]      │
--   │ Ramsch           Frei                         │
--   │ [■]              [42]                         │
--   │ 12.345 g                                      │
--   └───────────────────────────────────────────────┘
--
-- Kategorien (wichtigste zuerst): eigene Kategorie (Alt+Rechtsklick auf ein Item) > Neu >
-- Ramsch > Ausrüstung > Bears Datenbank (BagsData.lua: Kräuter, Erz, Fläschchen …) > Quest >
-- Blizzards Item-Klasse (Verbrauchbar, Handwerkswaren …).
-- Die Item-Knöpfe sind Blizzards eigene Vorlage (ContainerFrameItemButtonTemplate): Benutzen,
-- Ziehen, Verkaufen, Tooltips und Vergleiche funktionieren wie gewohnt – auch im Kampf.
local _, ns = ...
local L = ns.L

local SIZE = 36                  -- Item-Knöpfe
-- Abstand zwischen den Knöpfen und Innenabstand des Fensters: je nach Stil (ApplySpacing) –
-- „Abschnitte“ und „eine große Tasche“ luftiger, „Taschen einzeln“ kompakt wie Blizzard
local SPACING = { categories = { gap = 6, pad = 14 }, single = { gap = 6, pad = 14 }, separate = { gap = 4, pad = 10 } }
local GAP, PAD = 4, 10
local HEADER = 16                -- Höhe einer Abschnitts-Überschrift
local SECTION_GAP = 10           -- Abstand zwischen Abschnitten
local COLUMN_SLOTS = 7            -- Plätze je Spalte (wie BetterBags)
local COLUMN_GAP = 20             -- Abstand zwischen den Spalten
local MIN_COLUMNS, MAX_COLUMNS = 2, 4
local BAGS = { 0, 1, 2, 3, 4, 5 } -- Rucksack, Taschen 1–4, Reagenzientasche
local REAGENT_BAG = 5
local view = "bags" -- Reiter: "bags" (Rucksack + Taschen) oder "reagents" (Reagenzientasche)

local NEW, JUNK, OTHER, FREE = "New", "Junk", "Other", "Free"
-- freie Plätze in Spezialtaschen (Köcher, Munitionsbeutel, Seelen-/Kräutertaschen …) getrennt zählen:
-- dort passt nur Passendes hinein, sie gehören nicht zu „Frei“ (Benny, Jäger in Forever)
local QUIVER, SPECIAL = "Quiver", "Special bags"
local AMMO_FAMILIES = { [1] = true, [2] = true } -- Köcher (Pfeile), Munitionsbeutel (Kugeln)
local isEquipKey = {} -- Ausrüstungs-Abschnitte (Kopf, Finger, Zweihand …): Itemlevel, weit vorne

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, content, searchBox, freeText, goldText
local bagSlots = {} -- Taschenleiste unten rechts
local holders, buttons = {}, {}  -- holders[bag]: Frame mit ID = Taschen-Nr.; buttons[bag][slot]
local headers = {}               -- Überschriften-Pool
local categoryOf                 -- Item-ID > Bears-Kategorie (beim ersten Öffnen gebaut)
local dirty = true

local function Enabled() return ns.db and ns.db.bags ~= false end

-- Kategorien ----------------------------------------------------------------------------------

local function BuildLookup()
    categoryOf = {}
    for key, ids in pairs(ns.BAG_CATEGORY_ITEMS or {}) do
        for _, id in ipairs(ids) do categoryOf[id] = key end
    end
end

local function CustomCategories()
    ns.root.bagCategories = ns.root.bagCategories or {}
    return ns.root.bagCategories
end

-- Neue Items (wie BetterBags' „Recent Items“): jedes neu erhaltene Item bleibt 5 Minuten im
-- Abschnitt „Neu“. Einsortiert wird nur beim Schließen oder per „Sortieren“ – bei offener
-- Tasche springt sonst nichts.
local NEW_ITEM_TIME = 300
local recent = {}   -- Item-GUID > Zeitpunkt, seit dem es neu ist
local known         -- GUIDs, die schon in den Taschen waren (nil bis zum ersten Durchlauf)
local slotGUID = {} -- GUID je Platz aus dem letzten Durchlauf (bag * 1000 + slot)

local function ItemGUID(bag, slot)
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    return location:IsValid() and C_Item.GetItemGUID(location) or nil
end

-- Taschen durchgehen: was vorher nicht da war, ist neu (auch ohne Blizzards Neu-Markierung)
local function ScanNewItems()
    local now, seen = time(), {}
    wipe(slotGUID)
    for _, bag in ipairs(BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local guid = ItemGUID(bag, slot)
            slotGUID[bag * 1000 + slot] = guid
            if guid then
                seen[guid] = true
                if not recent[guid] and ((known and not known[guid]) or C_NewItems.IsNewItem(bag, slot)) then
                    recent[guid] = now
                end
            end
        end
    end
    known = seen
end

local function ExpireNewItems()
    local now = time()
    for guid, since in pairs(recent) do
        if now - since >= NEW_ITEM_TIME or not (known and known[guid]) then recent[guid] = nil end
    end
end

-- Kategorie eines Items – Rangfolge wie BetterBags mit „Bears Ultimate“:
-- Neu > Ausrüstungsset > eigene Zuweisung > Werkzeuge > Bears > Ramsch > Ausrüstungsplatz > Item-Typ
local function CategoryFor(bag, slot, info)
    local guid = slotGUID[bag * 1000 + slot]
    if guid and recent[guid] then return NEW end
    local inSet, setList = C_Container.GetContainerItemEquipmentSetInfo(bag, slot)
    if inSet and setList and setList ~= "" then
        return L["Gear: %s"]:format(strsplit(",", setList))
    end
    local custom = CustomCategories()[info.itemID]
    if custom then return custom end
    -- Berufswerkzeug (Angelrute, Kürschnermesser, Spitzhacke, Schmiedehammer …) immer zusammen,
    -- nicht nach Waffenart verteilt (Benny 2026-11-07); Erkennung wie der Löschschutz (ToolGuard.lua)
    if ns.IsProfessionTool and ns.IsProfessionTool(info.itemID) then return "Tools" end
    local bears = categoryOf[info.itemID]
    if bears then return bears end
    if info.quality == Enum.ItemQuality.Poor then return JUNK end
    local _, itemType, subType, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(info.itemID)
    if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
        local slotName = _G[equipLoc]
        if slotName and slotName ~= "" then
            if classID == Enum.ItemClass.Armor or classID == Enum.ItemClass.Weapon then isEquipKey[slotName] = true end
            return slotName
        end
    end
    -- Verbrauchbares und Handwerkswaren nach Unterart (Essen & Trinken, Trank, Stoff, Kräuter …):
    -- die Bears-Liste kennt fast nur neue Retail-Items, in Forever landete sonst alles in einem Topf
    -- (nicht bei „Allgemein“/„Sonstiges“: Verbrauchbar 0 und 8, Handwerkswaren 11 – dann bleibt die Art)
    local generic = (classID == Enum.ItemClass.Consumable and (subClassID == 0 or subClassID == 8))
        or (classID == Enum.ItemClass.Tradegoods and subClassID == 11)
    if (classID == Enum.ItemClass.Consumable or classID == Enum.ItemClass.Tradegoods)
        and not generic and subType and subType ~= "" and subType ~= itemType then
        return subType
    end
    return itemType or (classID and C_Item.GetItemClassInfo(classID)) or OTHER
end

-- Reihenfolge der Abschnitte: Neu, Ausrüstung, dann alphabetisch, Ramsch und Frei am Ende
local function SectionOrder(a, b)
    local function Rank(key)
        if key == NEW then return 1 elseif isEquipKey[key] then return 2
        elseif key == JUNK then return 4 elseif key == FREE then return 5
        elseif key == QUIVER or key == SPECIAL then return 6 end
        return 3
    end
    local ra, rb = Rank(a), Rank(b)
    if ra ~= rb then return ra < rb end
    return L[a] < L[b]
end

-- Item-Knöpfe ---------------------------------------------------------------------------------

local function QualityColor(quality)
    if quality then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then return r, g, b end
    end
    return 1, 1, 1
end

local function StyleButton(button)
    button:SetSize(SIZE, SIZE)
    button.emptyBackgroundAtlas = nil -- leere Plätze: unser Slot-Hintergrund statt Blizzards Flügel
    ns.AddSlotBackground(button)
    button.muiBorder = ns.AddBorder(button)
    local normal = button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end -- Qualität zeigt unser Rahmen
    button.icon:ClearAllPoints()
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Forever setzt den Ausschnitt bei jedem Symbolwechsel auf (0, 1, 0, 1) zurück (SetItemButtonTexture):
    -- dann wieder zuschneiden, sonst kommt der gewölbte Rand der Symbole zurück
    hooksecurefunc(button.icon, "SetTexCoord", function(icon, left)
        if left ~= 0.08 then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end)
    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:SetColorTexture(1, 1, 1, 0.2)
        pushed:SetAllPoints()
    end
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetColorTexture(1, 1, 1, 0.15)
        highlight:SetAllPoints()
    end
    if button.Count then
        button.Count:SetFont(ns.STYLE.font, ns.FontPx(12), "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    button.muiLevel = ns.CreateText(button, 11, "LEFT", "OUTLINE")
    button.muiLevel:SetPoint("BOTTOMLEFT", 2, 2)
    -- Upgrade-Pfeil (Upgrades.lua) mit dunklem Schatten, damit er auf jedem Symbol auffällt
    button.muiUpgrade = CreateFrame("Frame", nil, button)
    button.muiUpgrade:SetSize(18, 18)
    button.muiUpgrade:SetPoint("TOPLEFT", 1, -1)
    button.muiUpgrade:SetFrameLevel(button:GetFrameLevel() + 5)
    local shadow = ns.UI.Icon(button.muiUpgrade, "Upgrade", 18, { 0, 0, 0, 0.9 })
    shadow:SetPoint("CENTER", 1, -1)
    shadow:SetDrawLayer("OVERLAY", 1)
    local arrow = ns.UI.Icon(button.muiUpgrade, "Upgrade", 18, ns.UPGRADE_COLOR)
    arrow:SetPoint("CENTER")
    arrow:SetDrawLayer("OVERLAY", 2)
    button.muiUpgrade:Hide()
    -- „Füllt leeren Platz“ (Upgrades.lua): Rahmen in Surf Green, Punkt oben links, ruhiges Pulsieren
    local fill = CreateFrame("Frame", nil, button)
    fill:SetAllPoints()
    fill:SetFrameLevel(button:GetFrameLevel() + 4)
    local edges = ns.AddBorder(fill, true, 2)
    for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    local dot = fill:CreateTexture(nil, "OVERLAY", nil, 2)
    dot:SetSize(7, 7)
    dot:SetPoint("TOPLEFT", 3, -3)
    dot:SetColorTexture(unpack(ns.UI.ACCENT))
    local dotShadow = fill:CreateTexture(nil, "OVERLAY", nil, 1)
    dotShadow:SetPoint("TOPLEFT", dot, -1, 1)
    dotShadow:SetPoint("BOTTOMRIGHT", dot, 1, -1)
    dotShadow:SetColorTexture(0, 0, 0, 1)
    local pulse = fill:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(1.2)
    fade:SetSmoothing("IN_OUT")
    fill:SetScript("OnShow", function() pulse:Play() end)
    fill:SetScript("OnHide", function() pulse:Stop() end)
    fill:Hide()
    button.muiFill = fill
    button.muiFree = ns.CreateText(button, 13, "CENTER", "OUTLINE")
    button.muiFree:SetPoint("CENTER")
    button.muiFree:SetTextColor(0.7, 0.7, 0.7)
end

-- Rahmen in Qualitätsfarbe (ab „Selten“, sonst schwarz), Itemlevel auf Ausrüstung und Upgrade-Pfeil.
-- Gilt für die Knöpfe im Taschen- und im Bankfenster (Bank.lua).
function ns.DecorateItemButton(button, info, showLevel, bag, slot)
    local quality = info and info.quality
    local r, g, b = 0, 0, 0
    if quality and quality >= Enum.ItemQuality.Uncommon then r, g, b = QualityColor(quality) end
    for _, edge in ipairs(button.muiBorder) do edge:SetVertexColor(r, g, b, 1) end

    button.muiLevel:SetText("")
    if info and showLevel then
        -- ohne Taschenplatz (Gildenbank): Itemlevel aus dem Link
        local level = bag and C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot))
            or (info.hyperlink and C_Item.GetDetailedItemLevelInfo(info.hyperlink))
        if level and level > 1 then
            button.muiLevel:SetText(level)
            button.muiLevel:SetTextColor(QualityColor(quality))
        end
    end
    local fills = info and info.hyperlink and ns.FillsEmptySlot and ns.FillsEmptySlot(info.hyperlink)
    if button.muiFill then button.muiFill:SetShown(fills and true or false) end
    -- leerer Platz: Markierung statt Pfeil (gegen „nichts“ gibt es keinen sinnvollen Prozentwert)
    local upgrade = not fills and info and info.hyperlink and ns.UpgradePercent(info.hyperlink) -- auch in „Neu“
    button.muiUpgrade:SetShown(upgrade and upgrade >= 0.05 or false)
end

ns.StyleBagButton = StyleButton -- auch für das Bankfenster (Bank.lua)

local CategoryMenu, Layout -- weiter unten

local function GetButton(bag, slot)
    buttons[bag] = buttons[bag] or {}
    local button = buttons[bag][slot]
    if button then return button end
    local holder = holders[bag]
    if not holder then
        -- Blizzards Knöpfe lesen die Taschen-Nr. vom Elternframe
        holder = CreateFrame("Frame", "MeredanUIBagHolder" .. bag, content)
        holder:SetID(bag)
        holder:SetAllPoints()
        holder.IsCombinedBagContainer = function() return false end
        holders[bag] = holder
    end
    button = CreateFrame("ItemButton", "MeredanUIBagItem" .. bag .. "_" .. slot, holder, "ContainerFrameItemButtonTemplate")
    -- KEIN SetBagID: der Wert käme aus Addon-Code (Taint) und Blizzard blockt dann das Benutzen im
    -- Kampf. GetBagID liest ohne bagID die ID des Elternrahmens (holder:SetID), wie bei Bagnon/Baganator.
    button:SetID(slot)
    StyleButton(button)
    -- Alt+Rechtsklick: eigene Kategorie (Blizzard macht mit Alt+Rechtsklick nichts)
    button:HookScript("OnClick", function(self, mouse)
        if mouse == "RightButton" and IsAltKeyDown() and self.muiItemID then CategoryMenu(self) end
        -- Shift+Rechtsklick beim Händler: geschütztes Berufswerkzeug trotzdem verkaufen
        if mouse == "RightButton" and IsShiftKeyDown()
            and C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.Merchant)
            and ns.IsProfessionTool and ns.IsProfessionTool(self.muiItemID) then
            ns.SellToolAnyway(self:GetBagID(), self:GetID())
        end
    end)
    buttons[bag][slot] = button
    return button
end

-- showLevel: Itemlevel zeigen (Standard: nur in Ausrüstungs-Abschnitten)
local function UpdateButton(button, info, showLevel)
    local bag, slot = button:GetBagID(), button:GetID()
    local texture = info and info.iconFileID
    ClearItemButtonOverlay(button)
    button:SetHasItem(texture)
    button:SetItemButtonTexture(texture)
    -- leer: Blizzard setzt hier seine Flügel-Grafik (bags-item-slot64) – unser Slot-Hintergrund reicht
    if not texture then button.icon:Hide() end
    SetItemButtonQuality(button, info and info.quality, info and info.hyperlink, false, info and info.isBound)
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
    SetItemButtonCount(button, info and info.stackCount)
    SetItemButtonDesaturated(button, info and info.isLocked)
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    button:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
    button:UpdateNewItem(info and info.quality)
    button:UpdateJunkItem(info and info.quality, info and info.hasNoValue)
    button:UpdateItemContextMatching()
    button:UpdateCooldown(texture)
    button:SetReadable(info and info.IsReadable)
    button:CheckUpdateTooltip(GameTooltip:GetOwner())

    if showLevel == nil then showLevel = isEquipKey[button.muiCategory] end
    ns.DecorateItemButton(button, info, showLevel, bag, slot)
    button.muiFree:SetText("")
    button.muiItemID = info and info.itemID
    button.muiName = info and info.hyperlink and (C_Item.GetItemNameByID(info.itemID) or ""):lower() or ""
end

ns.UpdateBagButton = UpdateButton

-- Suche: nicht passende Items abdunkeln
local function ApplySearch()
    local query = searchBox and searchBox:GetText():lower() or ""
    for _, list in pairs(buttons) do
        for _, button in pairs(list) do
            if button:IsShown() then
                local match = query == "" or (button.muiName or ""):find(query, 1, true) ~= nil
                button:SetMatchesSearch(match)
            end
        end
    end
end

-- Aufbau --------------------------------------------------------------------------------------

-- Item auf eine Überschrift ziehen oder damit draufklicken: das Item gehört ab jetzt dorthin
local function DropOnHeader(header)
    local kind, itemID = GetCursorInfo()
    if kind ~= "item" or not itemID or header.key == FREE or header.key == QUIVER or header.key == SPECIAL then return end
    CustomCategories()[itemID] = header.key
    ClearCursor()
    Layout()
end

local function GetHeader(index)
    local header = headers[index]
    if not header then
        header = CreateFrame("Button", nil, content)
        header:SetHeight(HEADER - 2)
        header.text = ns.CreateText(header, 12, "LEFT", "OUTLINE")
        header.text:SetPoint("LEFT")
        header.text:SetTextColor(unpack(ns.UI.ACCENT))
        header:SetScript("OnClick", DropOnHeader)
        header:SetScript("OnReceiveDrag", DropOnHeader)
        header:SetScript("OnEnter", function(self)
            if GetCursorInfo() == "item" and self.key ~= FREE and self.key ~= QUIVER and self.key ~= SPECIAL then
                self.text:SetTextColor(1, 1, 1)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L["Drop here to always sort this item into %s"]:format(L[self.key]), 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        header:SetScript("OnLeave", function(self)
            self.text:SetTextColor(unpack(ns.UI.ACCENT))
            GameTooltip:Hide()
        end)
        headers[index] = header
    end
    return header
end

local measure -- misst Überschriften, damit Abschnitte mindestens so breit wie ihr Name sind
local function TextWidth(text)
    measure = measure or ns.CreateText(UIParent, 12, "LEFT", "OUTLINE")
    measure:Hide()
    measure:SetText(text)
    return math.ceil(measure:GetUnboundedStringWidth())
end

local function ItemSort(a, b)
    if a.quality ~= b.quality then return (a.quality or 0) > (b.quality or 0) end
    if a.name ~= b.name then return a.name < b.name end
    if a.itemID ~= b.itemID then return a.itemID < b.itemID end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

-- Stile (Einstellungen > Taschen):
--   "categories" – Abschnitte wie BetterBags (Standard)
--   "single"     – ein sortiertes Raster ohne Überschriften (Neu zuerst, dann Item-Klasse)
--   "separate"   – je Tasche ein Kasten in Taschen-Reihenfolge; das Fenster ist der Rucksack,
--                  die anderen Taschen stapeln sich darüber (wie bei Blizzard)
-- Spalten: kombinierte Tasche 10 (wie Blizzard), einzelne Taschen 5 (Blizzard: 4 – wirkt mit
-- dem MUI-Rahmen zu schmal)
local SINGLE_MIN_COLS, SINGLE_MAX_COLS = 10, 16
local SEPARATE_COLS = 5
local SLOTS_MIN_WIDTH = 240 -- Rucksack-Fenster mit eingeblendeten Taschenplätzen (neben dem Gold)
local BOX_GAP = 8
local bagBoxes = {} -- „separate“: Kasten je Tasche (außer Rucksack)

local function BagStyle()
    local style = ns.db.bagsStyle
    return (style == "single" or style == "separate") and style or "categories"
end

-- alle Plätze der sichtbaren Taschen einlesen: Items (mit Kategorie) und leere Plätze je Tasche
local function Collect(allBags)
    ScanNewItems()
    local items, empties, free = {}, {}, 0
    local special = { count = 0, key = nil, button = nil }
    for _, bag in ipairs(BAGS) do
        local inView = allBags or ((bag == REAGENT_BAG) == (view == "reagents"))
        local numSlots = inView and C_Container.GetContainerNumSlots(bag) or 0
        local _, family = C_Container.GetContainerNumFreeSlots(bag)
        local isSpecial = bag ~= 0 and bag ~= REAGENT_BAG and family and family ~= 0
        empties[bag] = {}
        for slot = 1, numSlots do
            local button = GetButton(bag, slot)
            local info = C_Container.GetContainerItemInfo(bag, slot)
            button:Hide()
            local entry = { button = button, info = info, bag = bag, slot = slot }
            if info and info.itemID then
                entry.key = CategoryFor(bag, slot, info)
                button.muiCategory = entry.key
                entry.itemID, entry.quality = info.itemID, info.quality
                entry.name = C_Item.GetItemNameByID(info.itemID) or ""
                entry.isNew = entry.key == NEW
                entry.classID = select(6, C_Item.GetItemInfoInstant(info.itemID)) or 99
                items[#items + 1] = entry
            elseif isSpecial then
                special.count = special.count + 1
                local key = AMMO_FAMILIES[family] and QUIVER or SPECIAL
                special.key = (special.key == nil or special.key == key) and key or SPECIAL
                special.button = special.button or button
                button.muiCategory = special.key
                empties[bag][#empties[bag] + 1] = entry
            else
                free = free + 1
                button.muiCategory = FREE
                empties[bag][#empties[bag] + 1] = entry
            end
        end
        -- Knöpfe für Plätze, die es nicht mehr gibt (kleinere Tasche), verstecken
        for slot, button in pairs(buttons[bag] or {}) do
            if slot > numSlots then button:Hide() end
        end
    end
    return items, empties, free, special
end

-- erster leerer NORMALER Platz (Spezialtaschen haben ihre eigene Kachel)
local function FirstEmpty(empties)
    for _, bag in ipairs(BAGS) do
        for _, entry in ipairs(empties[bag] or {}) do
            if entry.button.muiCategory == FREE then return entry.button end
        end
    end
end

-- Liste als Raster mit cols Spalten ab (x, y) in relative (Standard: content); Höhe zurück
local function PlaceGrid(list, cols, x, y, relative)
    for i, entry in ipairs(list) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local button = entry.button ---@type table
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", relative or content, "TOPLEFT", x + col * (SIZE + GAP), -(y + row * (SIZE + GAP)))
        UpdateButton(button, entry.info)
        button:Show()
    end
    return math.max(math.ceil(#list / cols) * (SIZE + GAP) - GAP, 1)
end

local function MaxContentHeight() return UIParent:GetHeight() - 2 * ns.SCREEN_MARGIN - 120 end

local function LayoutCategories(items, freeButton, free, special)
    local sections = {}
    for _, entry in ipairs(items) do
        sections[entry.key] = sections[entry.key] or {}
        table.insert(sections[entry.key], entry)
    end
    local keys = {}
    for key in pairs(sections) do keys[#keys + 1] = key end
    if freeButton then keys[#keys + 1] = FREE end
    if special and special.button then keys[#keys + 1] = special.key end
    table.sort(keys, SectionOrder)

    -- Aufbau wie BetterBags: Spalten mit je COLUMN_SLOTS Plätzen; Abschnitte laufen von oben nach
    -- unten, kleine Abschnitte stehen nebeneinander. Zwei Spalten, bei Bedarf mehr.
    local colWidth = COLUMN_SLOTS * (SIZE + GAP) - GAP
    -- 1) alle Abschnitte in Zeilen einer Spaltenbreite packen
    local rows, row = {}, nil
    for _, key in ipairs(keys) do
        if key ~= NEW then -- „Neu“ bekommt eine eigene Zeile ganz oben (siehe unten)
            local count = (key == FREE or (special and key == special.key and not sections[key])) and 1 or #sections[key]
            local secCols = math.min(count, COLUMN_SLOTS)
            local w = math.max(secCols * (SIZE + GAP) - GAP, TextWidth(L[key]) + 4)
            local h = HEADER + math.ceil(count / COLUMN_SLOTS) * (SIZE + GAP) - GAP
            if not row or row.width + w > colWidth then
                row = { width = 0, height = 0, items = {} }
                rows[#rows + 1] = row
            end
            row.items[#row.items + 1] = { key = key, x = row.width, cols = secCols }
            row.width = row.width + w + SECTION_GAP
            row.height = math.max(row.height, h)
        end
    end
    local total = 0
    for _, r in ipairs(rows) do total = total + r.height + SECTION_GAP end
    -- 2) Zeilen gleichmäßig auf die Spalten verteilen; mehr Spalten, wenn es zu hoch wird
    local maxHeight = MaxContentHeight()
    local columns, placed, placedHeight = MIN_COLUMNS, {}, 0
    for cols = MIN_COLUMNS, MAX_COLUMNS do
        columns = cols
        placed, placedHeight = {}, 0
        -- „Neu“ über die ganze Breite oben
        local top = 0
        if sections[NEW] then
            local fullWidth = cols * colWidth + (cols - 1) * COLUMN_GAP
            local slots = math.floor((fullWidth + GAP) / (SIZE + GAP))
            local count = #sections[NEW]
            placed[1] = { key = NEW, x = 0, y = 0, cols = math.min(count, slots) }
            top = HEADER + math.ceil(count / slots) * (SIZE + GAP) - GAP + SECTION_GAP
            placedHeight = top - SECTION_GAP
        end
        local target, col, y = total / cols, 0, top
        for _, r in ipairs(rows) do
            if y > top and y - top + r.height / 2 > target and col < cols - 1 then
                col, y = col + 1, top
            end
            local x0 = col * (colWidth + COLUMN_GAP)
            for _, item in ipairs(r.items) do
                placed[#placed + 1] = { key = item.key, x = x0 + item.x, y = y, cols = item.cols }
            end
            y = y + r.height + SECTION_GAP
            placedHeight = math.max(placedHeight, y - SECTION_GAP)
        end
        if placedHeight <= maxHeight then break end
    end

    for _, header in ipairs(headers) do header:Hide() end
    for index, section in ipairs(placed) do
        local header = GetHeader(index)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", content, "TOPLEFT", section.x, -section.y)
        header.key = section.key
        header.text:SetText(L[section.key])
        header:SetWidth(math.max(header.text:GetUnboundedStringWidth(), 1))
        header:Show()
        local list
        if section.key == FREE then
            list = { { button = freeButton } }
        elseif special and section.key == special.key and not sections[section.key] then
            list = { { button = special.button } }
        else
            list = sections[section.key]
            table.sort(list, ItemSort)
        end
        for i, entry in ipairs(list) do
            local col, row = (i - 1) % section.cols, math.floor((i - 1) / section.cols)
            local button = entry.button ---@type table
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", content, "TOPLEFT",
                section.x + col * (SIZE + GAP), -(section.y + HEADER + row * (SIZE + GAP)))
            UpdateButton(button, entry.info)
            if section.key == FREE then button.muiFree:SetText(free) end
            if special and button == special.button then button.muiFree:SetText(special.count) end
            button:Show()
        end
    end

    return columns * colWidth + (columns - 1) * COLUMN_GAP, placedHeight
end

local function SingleSort(a, b)
    if a.isNew ~= b.isNew then return a.isNew end
    if a.classID ~= b.classID then return a.classID < b.classID end
    return ItemSort(a, b)
end

-- Eine große Tasche: alle Plätze einzeln, auch die leeren (Benny 2026-11-07: kein „17 frei“-Feld)
local function LayoutSingle(items, empties)
    table.sort(items, SingleSort)
    for _, bag in ipairs(BAGS) do
        for _, entry in ipairs(empties[bag] or {}) do
            if entry.button.muiFree then entry.button.muiFree:SetText("") end
            items[#items + 1] = entry
        end
    end
    local cols = SINGLE_MIN_COLS
    while cols < SINGLE_MAX_COLS and math.ceil(#items / cols) * (SIZE + GAP) > MaxContentHeight() do cols = cols + 1 end
    local height = PlaceGrid(items, cols, 0, 0)
    return cols * (SIZE + GAP) - GAP, height
end

local function GetBox(bag)
    local box = bagBoxes[bag]
    if box then return box end
    box = CreateFrame("Frame", nil, window)
    box:SetFrameLevel(window:GetFrameLevel())
    ns.UI.Box(box, ns.STYLE.panelColor)
    box.title = ns.CreateText(box, 12, "LEFT", "OUTLINE")
    box.title:SetPoint("TOPLEFT", PAD, -PAD)
    box.title:SetTextColor(unpack(ns.UI.ACCENT))
    bagBoxes[bag] = box
    return box
end

local function LayoutSeparate(items, empties)
    local perBag = {}
    for _, bag in ipairs(BAGS) do perBag[bag] = {} end
    for _, entry in ipairs(items) do table.insert(perBag[entry.bag], entry) end
    for _, bag in ipairs(BAGS) do
        for _, entry in ipairs(empties[bag]) do table.insert(perBag[bag], entry) end
        table.sort(perBag[bag], function(a, b) return a.slot < b.slot end)
    end
    -- Rucksack im Fenster (Raster links, Fenster mindestens so breit wie seine Knöpfe)
    local gridWidth = SEPARATE_COLS * (SIZE + GAP) - GAP
    local width = ns.db.bagsShowSlots and math.max(gridWidth, SLOTS_MIN_WIDTH) or gridWidth
    local height = PlaceGrid(perBag[0], SEPARATE_COLS, 0, 0)
    local windowHeight = height + 2 * PAD + 58 + 30
    -- übrige Taschen als Kästen: erst über dem Fenster nach oben, dann Spalten links daneben
    -- Spalte 0 über dem Fenster (rechtsbündig), weitere Spalten links neben dem Fenster
    local boxWidth = gridWidth + 2 * PAD
    local windowWidth = width + 2 * PAD
    local _, _, _, _, bottom = window:GetPoint(1) -- Abstand der Unterkante zum Bildschirm (fest verankert)
    bottom = bottom or 0
    local limit = UIParent:GetHeight() - ns.SCREEN_MARGIN
    local col, y = 0, windowHeight + BOX_GAP
    for i = 1, #BAGS - 1 do
        local bag = BAGS[i + 1]
        local list = perBag[bag]
        local box = GetBox(bag)
        if #list == 0 then
            box:Hide()
        else
            local gridHeight = PlaceGrid(list, SEPARATE_COLS, PAD, PAD + HEADER, box)
            local boxHeight = gridHeight + 2 * PAD + HEADER
            if bottom + y + boxHeight > limit and y > 0 then col, y = col + 1, 0 end
            box:SetSize(boxWidth, boxHeight)
            box:ClearAllPoints()
            local x = col == 0 and 0 or -(windowWidth + BOX_GAP + (col - 1) * (boxWidth + BOX_GAP))
            box:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", x, y)
            box.title:SetText(bag == REAGENT_BAG and L["Reagent bag"] or C_Container.GetBagName(bag) or "")
            box:Show()
            y = y + boxHeight + BOX_GAP
        end
    end
    return width, height
end

function Layout()
    if not window then return end
    if not categoryOf then BuildLookup() end
    dirty = false

    local style = BagStyle()
    local spacing = SPACING[style]
    if spacing.gap ~= GAP or spacing.pad ~= PAD then
        GAP, PAD = spacing.gap, spacing.pad
        window.ApplyPad()
    end
    if view == "reagents" and (style == "separate" or C_Container.GetContainerNumSlots(REAGENT_BAG) == 0) then
        view = "bags"
    end
    for _, header in ipairs(headers) do header:Hide() end
    for _, box in pairs(bagBoxes) do box:Hide() end
    local items, empties, free, special = Collect(style == "separate")
    local width, height
    if style == "single" then
        width, height = LayoutSingle(items, empties)
    elseif style == "separate" then
        width, height = LayoutSeparate(items, empties)
    else
        width, height = LayoutCategories(items, FirstEmpty(empties), free, special)
    end

    content:SetSize(width, height)
    window:SetSize(width + 2 * PAD, height + 2 * PAD + 58 + 30)
    -- freie Plätze als Symbol + Zahl statt „17 frei“ (Benny 2026-11-07: ein UI erklärt sich übers
    -- Aussehen); Köcher/Munitionsbeutel mit Pfeil daneben. Erklärung im Tooltip.
    local function Icon(name) return ("|T%sIcons\\%s:13:13:0:0|t"):format(ns.MEDIA, name) end
    local freeLine = Icon("Square") .. " " .. free
    if special.count > 0 then
        freeLine = freeLine .. "   " .. Icon(special.key == QUIVER and "ReagentArrow" or "Bag") .. " " .. special.count
    end
    freeText:SetText(freeLine)
    freeText.muiFree, freeText.muiSpecial, freeText.muiSpecialKey = free, special.count, special.key
    goldText:SetText(GetMoneyString(GetMoney(), true))
    window.UpdateTabs()
    for bag, slotButton in pairs(bagSlots) do
        slotButton.icon:SetTexture(GetInventoryItemTexture("player", C_Container.ContainerIDToInventoryID(bag)))
    end
    ApplySearch()
end

-- Eigene Kategorien (Alt+Rechtsklick) ---------------------------------------------------------

StaticPopupDialogs["MEREDANUI_BAG_CATEGORY"] = {
    text = L["Name of the new category:"],
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 32,
    OnAccept = function(self, itemID)
        local box = self.GetEditBox and self:GetEditBox() or self.editBox or self.EditBox
        local name = box and strtrim(box:GetText() or "")
        if name and name ~= "" then
            CustomCategories()[itemID] = name
            Layout()
        end
    end,
    EditBoxOnEnterPressed = function(box)
        local popup = box:GetParent()
        StaticPopupDialogs["MEREDANUI_BAG_CATEGORY"].OnAccept(popup, popup.data)
        popup:Hide()
    end,
    EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function CategoryMenu(button)
    local itemID = button.muiItemID
    local custom = CustomCategories()
    local names, seen = {}, {}
    for _, name in pairs(custom) do
        if not seen[name] then seen[name] = true; names[#names + 1] = name end
    end
    table.sort(names)
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(C_Item.GetItemNameByID(itemID) or L["Category"])
        for _, name in ipairs(names) do
            root:CreateRadio(name, function() return custom[itemID] == name end,
                function() custom[itemID] = name; Layout() end)
        end
        root:CreateButton(L["New category…"], function()
            StaticPopup_Show("MEREDANUI_BAG_CATEGORY", nil, nil, itemID)
        end)
        if custom[itemID] then
            root:CreateButton(L["Remove from category"], function() custom[itemID] = nil; Layout() end)
        end
    end)
end

-- Fenster -------------------------------------------------------------------------------------

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIBags", UIParent)
    window:SetFrameStrata("MEDIUM")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor)
    tinsert(UISpecialFrames, "MeredanUIBags") -- Esc schließt

    local margin = ns.Snap(ns.SCREEN_MARGIN)
    -- unten rechts über dem Mikromenü (Platz für Mikromenü und Taschenknöpfe)
    window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -margin, margin + 28 + 8 + 28 + 8)

    -- Reiter: Taschen | Reagenzien (nur mit Reagenzientasche)
    local tabs = {}
    local function Tab(key, label)
        local tab = CreateFrame("Button", nil, window)
        tab.text = UI.Text(tab, 14, "LEFT")
        tab.text:SetPoint("LEFT")
        tab.text:SetText(label)
        tab:SetSize(tab.text:GetUnboundedStringWidth() + 2, 20)
        tab.line = tab:CreateTexture(nil, "OVERLAY")
        tab.line:SetColorTexture(unpack(UI.ACCENT))
        tab.line:SetPoint("BOTTOMLEFT", 0, -2)
        tab.line:SetPoint("BOTTOMRIGHT", 0, -2)
        tab.line:SetHeight(2)
        tab:SetScript("OnClick", function() window.ShowView(key) end)
        tabs[key] = tab
        return tab
    end
    Tab("bags", L["Bags"]):SetPoint("TOPLEFT", PAD, -PAD)
    Tab("reagents", L["Reagents"]):SetPoint("LEFT", tabs.bags, "RIGHT", 14, 0)
    function window.ShowView(key)
        if view ~= key then
            view = key
            Layout()
        end
    end
    function window.UpdateTabs()
        -- „Taschen einzeln“: die Reagenzientasche hat ihren eigenen Kasten statt eines Reiters
        tabs.reagents:SetShown(BagStyle() ~= "separate" and C_Container.GetContainerNumSlots(REAGENT_BAG) > 0)
        for key, tab in pairs(tabs) do
            local active = key == view
            tab.text:SetTextColor(unpack(active and UI.ACCENT or UI.MUTED))
            tab.line:SetShown(active)
        end
    end
    local close = UI.IconButton(window, "Close", function() window:Hide() end, 22)
    close:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 2)
    freeText = UI.Text(window, 12, "RIGHT", UI.MUTED)
    -- Sortieren: Blizzards Taschen-Sortierung (Stapel zusammenlegen, Reagenzien in die Reagenzientasche)
    local sort = UI.IconButton(window, "Sort", function()
        -- neue Items gleich mit einsortieren (auch Blizzards Neu-Markierung weg, sonst gelten sie
        -- beim nächsten Durchlauf wieder als neu)
        wipe(recent)
        C_NewItems.ClearAll()
        C_Container.SortBags()
        Layout()
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01 or SOUNDKIT.IG_BACKPACK_OPEN)
    end, 22)
    sort:SetPoint("RIGHT", close, "LEFT", -4, 0)
    sort:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Sort bags"], 1, 1, 1)
        GameTooltip:AddLine(L["Stacks items and moves reagents into the reagent bag."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    sort:HookScript("OnLeave", function() GameTooltip:Hide() end)
    -- Taschenplätze unten rechts ein-/ausblenden (Standard: aus)
    local function UpdateBagSlots()
        for _, slotButton in pairs(bagSlots) do slotButton:SetShown(ns.db.bagsShowSlots == true) end
    end
    window.UpdateBagSlots = UpdateBagSlots
    local slotsToggle = UI.IconButton(window, "Bag", function()
        ns.db.bagsShowSlots = not ns.db.bagsShowSlots
        UpdateBagSlots()
        if BagStyle() == "separate" then Layout() end -- Fensterbreite hängt davon ab
    end, 22)
    slotsToggle:SetPoint("RIGHT", sort, "LEFT", -4, 0)
    slotsToggle:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Bag slots"], 1, 1, 1)
        GameTooltip:AddLine(L["Shows or hides your bags at the bottom (swap by dragging onto them)."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    slotsToggle:HookScript("OnLeave", function() GameTooltip:Hide() end)
    freeText:SetPoint("RIGHT", slotsToggle, "LEFT", -8, 0)
    -- Tooltip über der Anzeige (FontStrings fangen keine Maus)
    local freeHover = CreateFrame("Frame", nil, window)
    freeHover:SetAllPoints(freeText)
    freeHover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["%d free slots"]:format(freeText.muiFree or 0), 1, 1, 1)
        if (freeText.muiSpecial or 0) > 0 then
            GameTooltip:AddLine(L[freeText.muiSpecialKey] .. ": " .. freeText.muiSpecial, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    freeHover:SetScript("OnLeave", function() GameTooltip:Hide() end)

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

    content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", PAD, -PAD - 58)
    content:SetSize(1, 1)

    goldText = UI.Text(window, 12, "LEFT")
    goldText:SetPoint("BOTTOMLEFT", PAD, PAD + 4)

    -- Taschenleiste unten rechts: Taschen sehen, tauschen (draufziehen), Inhalt hervorheben
    local previous
    for bag = 5, 1, -1 do
        local slotButton = CreateFrame("Button", nil, window)
        slotButton:SetSize(22, 22)
        if previous then
            slotButton:SetPoint("RIGHT", previous, "LEFT", -4, 0)
        else
            slotButton:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        end
        previous = slotButton
        ns.AddSlotBackground(slotButton)
        ns.AddBorder(slotButton)
        slotButton.icon = slotButton:CreateTexture(nil, "ARTWORK")
        slotButton.icon:SetAllPoints()
        slotButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local inventorySlot = C_Container.ContainerIDToInventoryID(bag)
        slotButton:RegisterForDrag("LeftButton")
        local function Put()
            if CursorHasItem() then PutItemInBag(inventorySlot) else PickupBagFromSlot(inventorySlot) end
        end
        -- Klick auf die Reagenzientasche: gleich deren Reiter zeigen (Ziehen nimmt sie weiterhin auf)
        slotButton:SetScript("OnClick", function()
            if bag == REAGENT_BAG and not CursorHasItem() and C_Container.GetContainerNumSlots(bag) > 0 then
                window.ShowView("reagents")
            else
                Put()
            end
        end)
        slotButton:SetScript("OnDragStart", function() PickupBagFromSlot(inventorySlot) end)
        slotButton:SetScript("OnReceiveDrag", Put)
        slotButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if not GameTooltip:SetInventoryItem("player", inventorySlot) then
                GameTooltip:SetText(bag == 5 and L["Reagent bag"] or L["Bag slot"], 1, 1, 1)
            end
            GameTooltip:Show()
            -- Items dieser Tasche hervorheben
            for b, list in pairs(buttons) do
                for _, button in pairs(list) do
                    if button:IsShown() then button:SetMatchesSearch(b == bag) end
                end
            end
        end)
        slotButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
            ApplySearch()
        end)
        bagSlots[bag] = slotButton
    end
    window.UpdateBagSlots()

    -- Innenabstand ändert sich mit dem Stil: alles am Rand neu ausrichten
    function window.ApplyPad()
        tabs.bags:ClearAllPoints()
        tabs.bags:SetPoint("TOPLEFT", PAD, -PAD)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -PAD + 2, -PAD + 2)
        searchBox:ClearAllPoints()
        searchBox:SetPoint("TOPLEFT", PAD, -PAD - 24)
        searchBox:SetPoint("TOPRIGHT", -PAD, -PAD - 24)
        content:ClearAllPoints()
        content:SetPoint("TOPLEFT", PAD, -PAD - 58)
        goldText:ClearAllPoints()
        goldText:SetPoint("BOTTOMLEFT", PAD, PAD + 4)
        bagSlots[5]:ClearAllPoints()
        bagSlots[5]:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    end

    window:SetScript("OnShow", function()
        if dirty then Layout() end
        PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    end)
    window:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
        searchBox:SetText("")
        searchBox:ClearFocus()
        -- „Neu“ gilt bis zum Schließen; beim nächsten Öffnen sind die Items einsortiert
        C_NewItems.ClearAll() -- nur das Leuchten; „Neu“ läuft über ExpireNewItems
        ExpireNewItems()
        view = "bags"
        dirty = true
        -- Blizzards Taschen mit schließen, sonst braucht „B“ danach zwei Drücke
        if IsAnyBagOpen() then CloseAllBags() end
    end)
end

-- Öffnen/Schließen: Blizzards Taschenlogik bleibt (Taste B, Händler, Bank …); ihre Fenster sind
-- unsichtbar geparkt, unser Fenster folgt einfach ihrem Zustand (IsAnyBagOpen).
local function Sync()
    if not window then return end
    local open = IsAnyBagOpen()
    if open and not window:IsShown() then
        window:Show()
    elseif not open and window:IsShown() then
        window:Hide()
    end
end

local function HideBlizzardBags()
    if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(hidden) end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame then frame:SetParent(hidden) end
    end
end

-- Händler: Ramsch verkaufen und reparieren (Gildenbank zuerst) --------------------------------

local function SellJunkAndRepair()
    if ns.db.bagsAutoJunk == false then return end
    -- Verkaufen macht Blizzards eigener „Ramsch verkaufen“-Befehl (Items benutzen darf ein Addon nicht)
    local earned, sold = 0, 0
    for _, bag in ipairs(BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                local price = select(11, C_Item.GetItemInfo(info.itemID)) or 0
                earned = earned + price * (info.stackCount or 1)
                sold = sold + 1
            end
        end
    end
    if sold > 0 and C_MerchantFrame.SellAllJunkItems and pcall(C_MerchantFrame.SellAllJunkItems) then
        ns.Print(L["Sold junk for %s."]:format(GetMoneyString(earned, true)))
    end

    if CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost > 0 then
            local guildMoney = IsInGuild() and CanGuildBankRepair() and GetGuildBankWithdrawMoney() or 0
            local useGuild = guildMoney == -1 or guildMoney >= cost
            if useGuild or GetMoney() >= cost then
                RepairAllItems(useGuild)
                ns.Print((useGuild and L["Repaired for %s (guild bank)."] or L["Repaired for %s."])
                    :format(GetMoneyString(cost, true)))
            end
        end
    end
end

-- Start ---------------------------------------------------------------------------------------

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    if C_AddOns.IsAddOnLoaded("BetterBags") then
        ns.Print(L["BetterBags is active – mUI bags stay off. Disable it to use ours."])
        return
    end
    CreateWindow()
    HideBlizzardBags()
    C_Timer.After(2, ScanNewItems) -- was beim Einloggen schon da ist, gilt nicht als neu
    for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "ToggleBackpack", "ToggleBag",
        "OpenBackpack", "CloseBackpack", "OpenBag", "CloseBag" }) do
        if _G[name] then hooksecurefunc(name, Sync) end
    end
    -- Reagenzientasche in der Taschenleiste angeklickt: MUI-Tasche mit dem Reagenzien-Reiter
    hooksecurefunc("ToggleBag", function(id)
        if id ~= REAGENT_BAG or C_Container.GetContainerNumSlots(id) == 0 then return end
        if not window:IsShown() then window:Show() end
        window.ShowView("reagents")
    end)
end)

-- Viele Ereignisse kommen gebündelt (Anlegen: Sperre, Tasche, Ausrüstung mehrfach …) – neu
-- aufgebaut wird nur einmal, kurz danach; bei geschlossener Tasche erst beim Öffnen.
local pending
local function Refresh()
    if not window then return end
    if not window:IsShown() then
        dirty = true
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        if window:IsShown() then Layout() end
    end)
end

ns.RefreshBags = Refresh -- z. B. neue Upgrade-Bewertung nach Spec-Wechsel
ns:On("BAG_UPDATE_DELAYED", Refresh)
ns:On("BAG_CONTAINER_UPDATE", Refresh)       -- Tasche getauscht
ns:On("PLAYER_EQUIPMENT_CHANGED", Refresh)
ns:On("QUEST_ACCEPTED", Refresh)
ns:On("UNIT_QUEST_LOG_CHANGED", Refresh)
ns:On("ITEM_LOCK_CHANGED", function(_, bag, slot)
    local button = bag and slot and buttons[bag] and buttons[bag][slot]
    if button and button:IsShown() then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        SetItemButtonDesaturated(button, info and info.isLocked)
    end
end)
ns:On("BAG_UPDATE_COOLDOWN", function()
    if not (window and window:IsShown()) then return end
    for _, list in pairs(buttons) do
        for _, button in pairs(list) do
            if button:IsShown() and button.muiItemID then button:UpdateCooldown(button:HasItem()) end
        end
    end
end)
ns:On("PLAYER_MONEY", function() if goldText then goldText:SetText(GetMoneyString(GetMoney(), true)) end end)
ns:On("MERCHANT_SHOW", function() if window then SellJunkAndRepair() end end)
