-- Addon bar: every addon with a minimap button (LibDBIcon) or an entry in Blizzard's addon
-- compartment, as a micro-menu-style row right-aligned above the micro menu (or the bag buttons).
--
--                [WA][Pawn][BugSack][MUI]   <- MUI rightmost, then leftwards; each can be hidden
--   [Char][Prof][Spells] ... [Shop][Menu]   <- micro menu
--
-- Builds its own buttons instead of reskinning foreign ones: icon, click and tooltip come from
-- the LibDataBroker object or the compartment entry. Original minimap buttons are parked on a
-- hidden frame (LibDBIcon never reparents them after creation). An addon present in both sources
-- gets a single button (the minimap one).
local _, ns = ...

local SIZE = 28        -- same as the micro menu
local GAP_PIXELS = 6   -- 4 px visible (borders sit outside)
local ICON_ZOOM = 0.15 -- addon icons are mostly round: crop the edge

local hidden = CreateFrame("Frame")
hidden:Hide()

local bar
local buttons = {} -- key -> button

-- Comparison key: no color codes, spaces or case ("|cff33bbffMeredan|rUI" = "meredanui")
local function Plain(text)
    text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:lower():gsub("[%s%p]", "")
end

-- Sources ------------------------------------------------------------------------------------

local function DataObject(name)
    local ldb = LibStub("LibDataBroker-1.1", true)
    return ldb and ldb:GetDataObjectByName(name)
end

-- LibDataBroker object (addon with a minimap button)
local function BrokerSource(name)
    return {
        sortName = name,
        label = name,
        Icon = function()
            local object = DataObject(name)
            return object and object.icon, object and object.iconCoords
        end,
        Enter = function(button)
            local object = DataObject(name)
            if object and object.OnEnter then return object.OnEnter(button) end
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            if object and object.OnTooltipShow then
                object.OnTooltipShow(GameTooltip)
            else
                GameTooltip:AddLine(object and (object.label or object.text) or name, 1, 1, 1)
            end
            GameTooltip:Show()
        end,
        Leave = function(button)
            local object = DataObject(name)
            if object and object.OnLeave then object.OnLeave(button) else GameTooltip:Hide() end
        end,
        Click = function(button, mouse)
            local object = DataObject(name)
            if object and object.OnClick then object.OnClick(button, mouse) end
        end,
    }
end

-- Entry from Blizzard's addon compartment (TOC "AddonCompartmentFunc" or RegisterAddon)
local function CompartmentSource(data)
    return {
        sortName = Plain(data.text),
        label = data.text,
        Icon = function() return data.icon end,
        Enter = function(button)
            if data.funcOnEnter then return data.funcOnEnter(button) end
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:AddLine(data.text or "?", 1, 1, 1)
            GameTooltip:Show()
        end,
        Leave = function(button)
            if data.funcOnLeave then data.funcOnLeave(button) else GameTooltip:Hide() end
        end,
        -- Same signature as Blizzard's menu: func(entry, { buttonName = mouseButton })
        Click = function(_, mouse) if data.func then data.func(data, { buttonName = mouse }) end end,
    }
end

-- Buttons ------------------------------------------------------------------------------------

local function UpdateIcon(button)
    local icon, coords = button.source.Icon()
    if type(icon) == "string" and C_Texture.GetAtlasInfo(icon) then
        button.icon:SetAtlas(icon)
        coords = nil
    else
        button.icon:SetTexture(icon or 134400) -- question mark if none
    end
    if coords then
        -- Addon's own crop region, still zoomed in
        local l, r, t, b = unpack(coords)
        local dx, dy = (r - l) * ICON_ZOOM, (b - t) * ICON_ZOOM
        button.icon:SetTexCoord(l + dx, r - dx, t + dy, b - dy)
    else
        button.icon:SetTexCoord(ICON_ZOOM, 1 - ICON_ZOOM, ICON_ZOOM, 1 - ICON_ZOOM)
    end
end

local function CreateButton(source)
    local button = CreateFrame("Button", nil, bar)
    button.source = source
    button:RegisterForClicks("AnyUp")
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddItemFrame(button, nil, 2)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(button, button.icon, nil, 2)
    local hover = button:CreateTexture(nil, "OVERLAY")
    hover:SetAllPoints(button.icon)
    hover:SetColorTexture(1, 1, 1, 0.15)
    hover:Hide()
    button:SetScript("OnEnter", function(self) hover:Show(); source.Enter(self) end)
    button:SetScript("OnLeave", function(self) hover:Hide(); source.Leave(self) end)
    button:SetScript("OnClick", function(self, mouse) source.Click(self, mouse) end)
    UpdateIcon(button)
    return button
end

local MUI_KEY = "meredanui"

-- Order: MeredanUI always first, then alphabetical
local function Sorted()
    local list = {}
    for _, button in pairs(buttons) do list[#list + 1] = button end
    table.sort(list, function(a, b)
        if (a.key == MUI_KEY) ~= (b.key == MUI_KEY) then return a.key == MUI_KEY end
        return Plain(a.source.sortName) < Plain(b.source.sortName)
    end)
    return list
end

local function IsHidden(key) return ns.db.addonBarHidden and ns.db.addonBarHidden[key] end

-- All bar addons (including hidden ones) for the settings: { key, label }
function ns.AddonBarEntries()
    local entries = {}
    for _, button in ipairs(Sorted()) do
        entries[#entries + 1] = { key = button.key, label = button.source.label or button.key }
    end
    return entries
end

-- Right-align visible buttons in one row (MUI rightmost), hide disabled ones
local function Layout()
    local list = {}
    for _, button in ipairs(Sorted()) do
        button:SetShown(not IsHidden(button.key))
        if button:IsShown() then list[#list + 1] = button end
    end
    local size, gap = ns.Snap(SIZE), GAP_PIXELS * ns.PixelSize()
    for i, button in ipairs(list) do
        button:ClearAllPoints()
        button:SetSize(size, size)
        -- Right-aligned: the first (MUI) rightmost, the rest leftwards
        button:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -(i - 1) * (size + gap), 0)
    end
    bar:SetSize(math.max(#list * size + math.max(#list - 1, 0) * gap, 1), size)
    bar:SetShown(#list > 0 and ns.VisibilityMode(ns.db.addonBar) ~= "hidden")
end

-- Take over an addon's minimap button: hide the original, create our own
---@param name string
---@param minimapButton Frame?
local function AdoptBroker(name, minimapButton)
    if minimapButton then minimapButton:SetParent(hidden) end
    local key = Plain(name)
    -- Already added from the compartment: replace with the minimap button version
    if buttons[key] and buttons[key].fromCompartment then
        buttons[key]:Hide()
        buttons[key] = nil
    end
    if not buttons[key] then
        buttons[key] = CreateButton(BrokerSource(name))
        buttons[key].key = key
    end
end

-- Take over compartment entries (addons with a minimap button are not duplicated)
local function AdoptCompartment()
    local compartment = AddonCompartmentFrame
    if not (compartment and compartment.registeredAddons) then return end
    for _, data in ipairs(compartment.registeredAddons) do
        local key = Plain(data.text)
        if key ~= "" and not buttons[key] then
            local button = CreateButton(CompartmentSource(data))
            button.key = key
            button.fromCompartment = true
            buttons[key] = button
        end
    end
end

-- Above the micro menu, or above the bag buttons when those are visible
local function Place()
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    local below = _G["MeredanUIBagBar"]
    if not (below and below:IsVisible()) then below = MicroMenuContainer end
    bar:ClearAllPoints()
    if below then
        bar:SetPoint("BOTTOMRIGHT", below, "TOPRIGHT", 0, ns.Snap(8))
    else
        bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -margin, margin)
    end
end

function ns.UpdateAddonBar()
    if not bar then return end
    bar.muiMouseover = ns.VisibilityMode(ns.db.addonBar) == "mouseover"
    Layout()
    Place()
end

local function Setup()
    bar = CreateFrame("Frame", "MeredanUIAddonBar", UIParent)
    bar:SetFrameStrata("LOW")
    ns.RegisterMouseover(bar)

    local icons = LibStub("LibDBIcon-1.0", true)
    if icons then
        -- GetButtonList returns names (its annotation wrongly says buttons)
        local names = icons:GetButtonList() --[[@as string[] ]]
        for _, name in ipairs(names) do AdoptBroker(name, icons:GetMinimapButton(name)) end
        -- Addons loaded later (CallbackHandler passes the event name first)
        ---@diagnostic disable-next-line: param-type-mismatch
        icons.RegisterCallback(bar, "LibDBIcon_IconCreated", function(_, button, name)
            AdoptBroker(name, button)
            ns.UpdateAddonBar()
        end)
    end
    -- Addons that change their icon (e.g. BugSack on new errors)
    local ldb = LibStub("LibDataBroker-1.1", true)
    if ldb then
        local function IconChanged(_, name)
            local button = buttons[Plain(name)]
            if button then UpdateIcon(button) end
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        ldb.RegisterCallback(bar, "LibDataBroker_AttributeChanged__icon", IconChanged)
        ---@diagnostic disable-next-line: param-type-mismatch
        ldb.RegisterCallback(bar, "LibDataBroker_AttributeChanged__iconCoords", IconChanged)
    end

    -- The compartment fills on entering the world; later registrations go through UpdateDisplay
    AdoptCompartment()
    if AddonCompartmentFrame then
        hooksecurefunc(AddonCompartmentFrame, "UpdateDisplay", function()
            AdoptCompartment()
            ns.UpdateAddonBar()
        end)
    end

    -- Toggling the bag buttons moves the bar
    hooksecurefunc(ns, "UpdateMicroMenu", ns.UpdateAddonBar)
    ns.OnLayout(ns.UpdateAddonBar)
end

-- After the micro menu (which sets itself up one frame after login)
ns:On("PLAYER_LOGIN", function() C_Timer.After(0.1, Setup) end)
