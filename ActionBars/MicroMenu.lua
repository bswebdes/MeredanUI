-- Mikromenü und Taschenknöpfe unten rechts (25 px vom Rand), flach im MUI-Look.
-- Blizzards Mikroknöpfe bleiben funktional (Klick, Tooltip, Tastenbelegung); ihre Optik wird
-- unsichtbar, darüber liegt ein eckiges Feld mit Symbol in Klassenfarbe. Die Taschen sind
-- eigene schlichte Knöpfe mit den echten Taschenbildern, rechtsbündig über dem Mikromenü.
--
--                              [Ruck][T1][T2][T3][T4][Reag]
--   [Char][Beruf][Zauber][Erfolge][Quest][Haus][Gilde][Suche][Samml.][Führer][Shop][Menü]
local _, ns = ...
local L = ns.L

local SIZE = 28        -- Mikroknöpfe und Taschen gleich groß
local overlays = {}    -- eigene Felder über Blizzards Mikroknöpfen
local GAP_PIXELS = 6   -- sichtbar 4 px (Rahmen liegen außen), wie bei den Aktionsleisten
local hidden = CreateFrame("Frame")
hidden:Hide()

-- Symbol je Blizzard-Knopf (Media/Icons/…)
local MICRO_ICONS = {
    CharacterMicroButton = "MicroCharacter",
    ProfessionMicroButton = "MicroProfession",
    PlayerSpellsMicroButton = "MicroSpells",
    SpellbookMicroButton = "MicroSpells",     -- Forever: Zauberbuch und Talente getrennt
    TalentMicroButton = "MicroTalents",
    LegacyMicroButton = "MicroLegacy",        -- Forever: Legacy-System
    AchievementMicroButton = "MicroAchievement",
    QuestLogMicroButton = "Quest",
    HousingMicroButton = "MicroHousing",
    GuildMicroButton = "Guild",
    LFDMicroButton = "MicroLFD",
    CollectionsMicroButton = "MicroCollections",
    EJMicroButton = "MicroJournal",
    StoreMicroButton = "MicroStore",
    MainMenuMicroButton = "MicroMenu",
}

local function ClassColor()
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS[class]
    if color then return { color.r, color.g, color.b } end
    return ns.UI.TEXT
end

-- Blizzard-Frame dauerhaft an einen Punkt setzen (Edit Mode verschiebt ihn sonst zurück)
local function Pin(frame, ...)
    local args = { ... }
    local waiting
    local function Apply()
        -- im Kampf gesperrt: nach dem Kampf nachholen (Blizzard setzt das Menü nach Fahrzeugen/
        -- Sonderleisten auf die Bearbeitungsmodus-Lage zurück – sonst blieb es bis /reload in der Mitte)
        if InCombatLockdown() then
            if not waiting then
                waiting = true
                ns.AfterCombat(function() waiting = false; Apply() end)
            end
            return
        end
        frame.muiPlacing = true
        frame:ClearAllPoints()
        frame:SetPoint(unpack(args))
        frame.muiPlacing = false
    end
    hooksecurefunc(frame, "SetPoint", function() if not frame.muiPlacing then Apply() end end)
    Apply()
end

-- Mikroknopf: Blizzard-Optik unsichtbar, darüber eckiges Feld mit Symbol in Klassenfarbe
local function SkinMicroButton(button, iconName)
    button:SetAlpha(0)
    -- Blizzard setzt die Transparenz beim Aktivieren/Deaktivieren zurück (OnEnable > 1,
    -- OnDisable > 0,5) – dann schaut sein Hintergrund hinter unserem Feld hervor. Sofort wieder 0.
    hooksecurefunc(button, "SetAlpha", function(self, alpha)
        if alpha ~= 0 then self:SetAlpha(0) end
    end)
    local overlay = ns.CreateButtonOverlay(button)
    local size = ns.Snap(SIZE)
    overlay:SetAllPoints(button)
    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    -- voll deckend: Reste von Blizzards Knopf dürfen nicht durchscheinen
    local r, g, b = unpack(ns.STYLE.panelColor)
    bg:SetColorTexture(r, g, b, 1)
    ns.AddBorder(overlay)
    local color = ClassColor()
    local icon = ns.UI.Icon(overlay, iconName, math.floor(size * 0.6), color)
    icon:SetPoint("CENTER")
    button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(ns.UI.ACCENT)) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(color)) end)
    button.muiOverlay = overlay
    overlays[#overlays + 1] = overlay
end

-- Eigene Taschenknöpfe (Blizzards Taschenleiste lässt sich kaum sauber umstylen):
-- Rucksack, Tasche 1–4, Reagenzientasche – Bild der Tasche, Klick öffnet sie, Tooltip zeigt sie.
-- Der Rucksack zeigt die freien Plätze aller Taschen.
local BAGS = { 0, 1, 2, 3, 4, 5 } -- 5 = Reagenzientasche
local bagBar
local bagButtons = {}

local function FreeSlots()
    local free = 0
    for _, bag in ipairs(BAGS) do
        -- nur normale Taschen: Köcher & andere Spezialtaschen (family ~= 0) zählen nicht mit
        local count, family = C_Container.GetContainerNumFreeSlots(bag)
        if not family or family == 0 then free = free + (count or 0) end
    end
    return free
end

local function UpdateBagButtons()
    for _, button in ipairs(bagButtons) do
        local texture
        if button.bag == 0 then
            texture = 133633 -- Rucksack
        else
            local slot = C_Container.ContainerIDToInventoryID(button.bag)
            texture = slot and GetInventoryItemTexture("player", slot)
        end
        button.icon:SetTexture(texture)
        button.icon:SetShown(texture ~= nil)
        if button.bag == 0 then button.count:SetText(FreeSlots()) end
    end
end

local function CreateBagButton(bag)
    local button = CreateFrame("Button", nil, bagBar)
    button.bag = bag
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddBorder(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.count = ns.CreateText(button, 11, "RIGHT", "OUTLINE")
    button.count:SetPoint("BOTTOMRIGHT", -1, 2)
    local hover = button:CreateTexture(nil, "OVERLAY")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    hover:Hide()
    button:SetScript("OnEnter", function(self)
        hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if bag == 0 then
            GameTooltip:AddLine(BACKPACK_TOOLTIP or L["Backpack"], 1, 1, 1)
            GameTooltip:AddLine(L["%d free slots"]:format(FreeSlots()), 0.8, 0.8, 0.8)
        else
            local slot = C_Container.ContainerIDToInventoryID(bag)
            if not (slot and GameTooltip:SetInventoryItem("player", slot)) then
                GameTooltip:AddLine(bag == 5 and L["Reagent bag"] or L["Bag slot"], 0.8, 0.8, 0.8)
            end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        hover:Hide()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function()
        if bag == 0 then ToggleBackpack() else ToggleBag(bag) end
    end)
    return button
end

local function CreateBagBar(anchor)
    bagBar = CreateFrame("Frame", "MeredanUIBagBar", UIParent)
    local size, gap = ns.Snap(SIZE), GAP_PIXELS * ns.PixelSize()
    bagBar:SetSize(#BAGS * size + (#BAGS - 1) * gap, size)
    -- rechtsbündig über dem Mikromenü, Rucksack ganz rechts
    bagBar:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, ns.Snap(8))
    for i, bag in ipairs(BAGS) do
        local button = CreateBagButton(bag)
        button:SetSize(size, size)
        button:SetPoint("BOTTOMRIGHT", bagBar, "BOTTOMRIGHT", -(i - 1) * (size + gap), 0)
        bagButtons[#bagButtons + 1] = button
    end
    ns.RegisterMouseover(bagBar)
    UpdateBagButtons()
end

ns:On("BAG_UPDATE_DELAYED", UpdateBagButtons)
ns:On("PLAYER_EQUIPMENT_CHANGED", UpdateBagButtons)

-- Mikroknöpfe selbst in eine Reihe legen (nach Blizzards Reihenfolge), gleiche Größe und
-- Abstände wie die Aktionsleisten. Läuft nach jedem Blizzard-Layout erneut.
local function LayoutMicroButtons()
    if InCombatLockdown() or not MicroMenu then return end
    local buttons = {}
    for _, child in ipairs({ MicroMenu:GetChildren() }) do
        if child.layoutIndex and child.muiOverlay and child:IsShown() then buttons[#buttons + 1] = child end
    end
    table.sort(buttons, function(a, b) return a.layoutIndex < b.layoutIndex end)
    local size, gap = ns.Snap(SIZE), GAP_PIXELS * ns.PixelSize()
    for i, button in ipairs(buttons) do
        button:ClearAllPoints()
        button:SetSize(size, size)
        button:SetPoint("BOTTOMLEFT", MicroMenu, "BOTTOMLEFT", (i - 1) * (size + gap), 0)
    end
    local width = #buttons * size + math.max(#buttons - 1, 0) * gap
    MicroMenu:SetSize(math.max(width, 1), size)
    if MicroMenuContainer then MicroMenuContainer:SetSize(math.max(width, 1), size) end
end

-- Sichtbarkeit: "always", "mouseover", "hidden"
local function ApplyVisibility(frame, setting)
    local mode = ns.VisibilityMode(setting)
    frame.muiMouseover = mode == "mouseover"
    if mode == "hidden" then
        frame:SetParent(hidden)
    else
        frame:SetParent(UIParent)
    end
end

function ns.UpdateMicroMenu()
    if InCombatLockdown() then return ns.AfterCombat(ns.UpdateMicroMenu) end
    if MicroMenuContainer then ApplyVisibility(MicroMenuContainer, ns.db.microMenu) end
    if bagBar then ApplyVisibility(bagBar, "hidden") end -- Taschenknöpfe fest aus (Taschen öffnet man mit B)
end

local function Setup()
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    local container = MicroMenuContainer
    if container then
        for name, iconName in pairs(MICRO_ICONS) do
            local button = _G[name]
            if button then SkinMicroButton(button, iconName) end
        end
        if HelpMicroButton then HelpMicroButton:SetAlpha(0) end
        -- Forever: Blizzards Rahmen und Hintergrund ums Mikromenü ausblenden
        if MicroMenu then
            if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
            if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
        end
        -- unten rechts, 25 px vom Rand; Knöpfe in eigener Reihe
        Pin(container, "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -margin, margin)
        if MicroMenu then
            Pin(MicroMenu, "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
            hooksecurefunc(MicroMenu, "Layout", LayoutMicroButtons)
            if container.Layout then hooksecurefunc(container, "Layout", LayoutMicroButtons) end
            LayoutMicroButtons()
        end
        ns.RegisterMouseover(container)
        -- Die Felder hängen nicht an den (unsichtbaren) Blizzard-Knöpfen, erben die Transparenz
        -- des Menüs also nicht. Mouseover-Ausblenden deshalb ausdrücklich an sie weitergeben.
        hooksecurefunc(container, "SetAlpha", function(_, alpha)
            for _, overlay in ipairs(overlays) do overlay:SetAlpha(alpha) end
        end)
    end

    -- Blizzards Taschenleiste weg, eigene Taschenknöpfe über dem Mikromenü
    if BagsBar then BagsBar:SetParent(hidden) end
    CreateBagBar(container or UIParent)
    ns.UpdateMicroMenu()
end

ns:On("PLAYER_LOGIN", function() ns.AfterCombat(Setup) end) -- direkt: auch bei /reload im Kampf
