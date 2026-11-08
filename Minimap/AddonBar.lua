-- Addon-Leiste: alle Addons mit Minimap-Knopf (LibDBIcon) oder Eintrag in Blizzards Addon-Menü
-- als Reihe im Mikromenü-Look, rechtsbündig über dem Mikromenü (bzw. über den Taschenknöpfen).
--
--                                  [WA][Pawn][BugSack][MUI]   ← MUI ganz rechts, dann nach links;
--                                                                einzelne ausblendbar (Einstellungen)
--   [Char][Beruf][Zauber] … [Shop][Menü]                       ← Mikromenü
--
-- Eigene Knöpfe statt fremde umzubauen: Symbol, Klick und Tooltip kommen aus dem
-- LibDataBroker-Objekt bzw. dem Eintrag im Addon-Menü. Die originalen Minimap-Knöpfe hängen an
-- einem versteckten Rahmen (LibDBIcon hängt sie nach dem Anlegen nie wieder um). Steht ein Addon
-- in beiden Quellen, gibt es nur einen Knopf (der mit dem Minimap-Knopf).
local _, ns = ...

local SIZE = 28        -- wie das Mikromenü
local GAP_PIXELS = 6   -- sichtbar 4 px (Rahmen liegen außen)
local ICON_ZOOM = 0.15 -- Addon-Symbole sind meist rund: Rand abschneiden

local hidden = CreateFrame("Frame")
hidden:Hide()

local bar
local buttons = {} -- Schlüssel > Knopf

-- Vergleichsname: ohne Farbcodes, Leerzeichen und Groß/klein ("|cff33bbffMeredan|rUI" = "meredanui")
local function Plain(text)
    text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text:lower():gsub("[%s%p]", "")
end

-- Quellen -------------------------------------------------------------------------------------

local function DataObject(name)
    local ldb = LibStub("LibDataBroker-1.1", true)
    return ldb and ldb:GetDataObjectByName(name)
end

-- LibDataBroker-Objekt (Addon mit Minimap-Knopf)
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

-- Eintrag aus Blizzards Addon-Menü (TOC „AddonCompartmentFunc“ oder RegisterAddon)
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
        -- wie Blizzards Menü: func(Eintrag, { buttonName = Maustaste })
        Click = function(_, mouse) if data.func then data.func(data, { buttonName = mouse }) end end,
    }
end

-- Knöpfe --------------------------------------------------------------------------------------

local function UpdateIcon(button)
    local icon, coords = button.source.Icon()
    if type(icon) == "string" and C_Texture.GetAtlasInfo(icon) then
        button.icon:SetAtlas(icon)
        coords = nil
    else
        button.icon:SetTexture(icon or 134400) -- Fragezeichen, falls keins
    end
    if coords then
        -- eigener Ausschnitt des Addons, darin trotzdem reinzoomen
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
    ns.AddBorder(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    local hover = button:CreateTexture(nil, "OVERLAY")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    hover:Hide()
    button:SetScript("OnEnter", function(self) hover:Show(); source.Enter(self) end)
    button:SetScript("OnLeave", function(self) hover:Hide(); source.Leave(self) end)
    button:SetScript("OnClick", function(self, mouse) source.Click(self, mouse) end)
    UpdateIcon(button)
    return button
end

local MUI_KEY = "meredanui"

-- Reihenfolge: MeredanUI immer zuerst, dann alphabetisch
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

-- Alle Addons der Leiste (auch ausgeblendete) für die Einstellungen: { key, label }
function ns.AddonBarEntries()
    local entries = {}
    for _, button in ipairs(Sorted()) do
        entries[#entries + 1] = { key = button.key, label = button.source.label or button.key }
    end
    return entries
end

-- sichtbare Knöpfe rechtsbündig in eine Reihe (MUI ganz rechts), ausgeblendete verstecken
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
        -- rechtsbündig: das erste (MUI) ganz rechts, die übrigen nach links
        button:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -(i - 1) * (size + gap), 0)
    end
    bar:SetSize(math.max(#list * size + math.max(#list - 1, 0) * gap, 1), size)
    bar:SetShown(#list > 0 and ns.VisibilityMode(ns.db.addonBar) ~= "hidden")
end

-- Minimap-Knopf eines Addons übernehmen: Original verstecken, eigenen Knopf anlegen
---@param name string
---@param minimapButton Frame?
local function AdoptBroker(name, minimapButton)
    if minimapButton then minimapButton:SetParent(hidden) end
    local key = Plain(name)
    -- stand das Addon schon aus dem Addon-Menü drin: durch den Minimap-Knopf ersetzen
    if buttons[key] and buttons[key].fromCompartment then
        buttons[key]:Hide()
        buttons[key] = nil
    end
    if not buttons[key] then
        buttons[key] = CreateButton(BrokerSource(name))
        buttons[key].key = key
    end
end

-- Einträge aus Blizzards Addon-Menü übernehmen (Addons mit Minimap-Knopf nicht doppelt)
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

-- über dem Mikromenü, oder über den Taschenknöpfen, wenn die sichtbar sind
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
        -- GetButtonList liefert Namen (die Annotation sagt fälschlich Knöpfe)
        local names = icons:GetButtonList() --[[@as string[] ]]
        for _, name in ipairs(names) do AdoptBroker(name, icons:GetMinimapButton(name)) end
        -- später geladene Addons (CallbackHandler ruft Funktionen mit Ereignisname zuerst auf)
        ---@diagnostic disable-next-line: param-type-mismatch
        icons.RegisterCallback(bar, "LibDBIcon_IconCreated", function(_, button, name)
            AdoptBroker(name, button)
            ns.UpdateAddonBar()
        end)
    end
    -- Addons, die ihr Symbol wechseln (z. B. BugSack bei neuen Fehlern)
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

    -- Blizzards Addon-Menü füllt sich beim Betreten der Welt; spätere Anmeldungen laufen über
    -- UpdateDisplay
    AdoptCompartment()
    if AddonCompartmentFrame then
        hooksecurefunc(AddonCompartmentFrame, "UpdateDisplay", function()
            AdoptCompartment()
            ns.UpdateAddonBar()
        end)
    end

    -- Taschenknöpfe an/aus verschiebt die Leiste
    hooksecurefunc(ns, "UpdateMicroMenu", ns.UpdateAddonBar)
    ns.OnLayout(ns.UpdateAddonBar)
end

-- nach dem Mikromenü (das richtet sich einen Frame nach dem Login ein)
ns:On("PLAYER_LOGIN", function() C_Timer.After(0.1, Setup) end)
