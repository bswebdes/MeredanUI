-- Micro menu and bag buttons bottom right (25 px from the edge), flat MUI look.
-- Blizzard's micro buttons stay functional (click, tooltip, keybind); their art is made
-- invisible and a square tile with a class-colored icon sits on top. The bags are simple
-- custom buttons with the real bag icons, right-aligned above the micro menu.
--
--                             [Pack][B1][B2][B3][B4][Reag]
--  [Char][Prof][Spells][Achiev][Quest][House][Guild][LFG][Coll][Guide][Shop][Menu]
local _, ns = ...
local L = ns.L

local SIZE = 28        -- micro buttons and bags share the size
local overlays = {}    -- our tiles over Blizzard's micro buttons
local GAP_PIXELS = 6   -- visibly 4 px (borders sit outside), like the action bars
local hidden = CreateFrame("Frame")
hidden:Hide()

-- icon per Blizzard button (Media/Icons/...)
local MICRO_ICONS = {
    CharacterMicroButton = "MicroCharacter",
    ProfessionMicroButton = "MicroProfession",
    PlayerSpellsMicroButton = "MicroSpells",
    SpellbookMicroButton = "MicroSpells",     -- Forever: spellbook and talents are separate
    TalentMicroButton = "MicroTalents",
    LegacyMicroButton = "MicroLegacy",        -- Forever: legacy system
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

-- Pin a Blizzard frame to a point permanently (Edit Mode would move it back otherwise)
local function Pin(frame, ...)
    local args = { ... }
    local waiting
    local function Apply()
        -- locked in combat: redo after combat (Blizzard resets the menu to its Edit Mode position after
        -- vehicles/special bars - otherwise it stayed centered until /reload)
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

-- Micro button: Blizzard art invisible, square tile with class-colored icon on top
local function SkinMicroButton(button, iconName)
    button:SetAlpha(0)
    -- Blizzard resets alpha on enable/disable (OnEnable -> 1, OnDisable -> 0.5), which lets its
    -- background peek out behind our tile. Reset to 0 immediately.
    hooksecurefunc(button, "SetAlpha", function(self, alpha)
        if alpha ~= 0 then self:SetAlpha(0) end
    end)
    local overlay = ns.CreateButtonOverlay(button)
    local size = ns.Snap(SIZE)
    overlay:SetAllPoints(button)
    local bg = overlay:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    -- fully opaque: remnants of Blizzard's button must not show through
    local r, g, b = unpack(ns.STYLE.panelColor)
    bg:SetColorTexture(r, g, b, 1)
    ns.AddBorder(overlay)
    local color = ClassColor()
    local icon = ns.UI.Icon(overlay, iconName, math.floor(size * 0.6), color, true) -- flat: easier to tell apart than painted
    icon:SetPoint("CENTER")
    button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(ns.UI.ACCENT)) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(color)) end)
    button.muiOverlay = overlay
    overlays[#overlays + 1] = overlay
end

-- Custom bag buttons (Blizzard's bag bar is hard to restyle cleanly): backpack, bags 1-4,
-- reagent bag - bag icon, click opens it, tooltip shows it.
-- The backpack shows free slots across all bags.
local BAGS = { 0, 1, 2, 3, 4, 5 } -- 5 = reagent bag
local bagBar
local bagButtons = {}

local function FreeSlots()
    local free = 0
    for _, bag in ipairs(BAGS) do
        -- regular bags only: quivers and other special bags (family ~= 0) don't count
        local count, family = C_Container.GetContainerNumFreeSlots(bag)
        if not family or family == 0 then free = free + (count or 0) end
    end
    return free
end

local function UpdateBagButtons()
    for _, button in ipairs(bagButtons) do
        local texture
        if button.bag == 0 then
            texture = 133633 -- backpack
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
    -- right-aligned above the micro menu, backpack rightmost
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

-- Lay out the micro buttons in one row (Blizzard's order), same size and spacing as the
-- action bars. Reruns after every Blizzard layout pass.
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

-- Visibility: "always", "mouseover", "hidden"
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
    if bagBar then ApplyVisibility(bagBar, "hidden") end -- bag buttons always off (bags open with B)
end

local function Setup()
    if ns.ModuleOn and not ns.ModuleOn("actionBarModule") then return end -- bar addon brings its own
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    local container = MicroMenuContainer
    if container then
        for name, iconName in pairs(MICRO_ICONS) do
            local button = _G[name]
            if button then SkinMicroButton(button, iconName) end
        end
        if HelpMicroButton then HelpMicroButton:SetAlpha(0) end
        -- Forever: hide Blizzard's frame and background around the micro menu
        if MicroMenu then
            if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
            if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
        end
        -- bottom right, 25 px from the edge; buttons in our own row
        Pin(container, "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -margin, margin)
        if MicroMenu then
            Pin(MicroMenu, "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
            hooksecurefunc(MicroMenu, "Layout", LayoutMicroButtons)
            if container.Layout then hooksecurefunc(container, "Layout", LayoutMicroButtons) end
            LayoutMicroButtons()
        end
        ns.RegisterMouseover(container)
        -- The tiles aren't parented to the (invisible) Blizzard buttons, so they don't inherit the
        -- menu's alpha. Pass mouseover fading on to them explicitly.
        hooksecurefunc(container, "SetAlpha", function(_, alpha)
            for _, overlay in ipairs(overlays) do overlay:SetAlpha(alpha) end
        end)
    end

    -- hide Blizzard's bag bar, custom bag buttons above the micro menu
    if BagsBar then BagsBar:SetParent(hidden) end
    CreateBagBar(container or UIParent)
    ns.UpdateMicroMenu()
end

ns:On("PLAYER_LOGIN", function() ns.AfterCombat(Setup) end) -- immediately: also works on /reload in combat
