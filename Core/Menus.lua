-- Blizzards Menüs (MenuUtil, Dropdowns) im mUI-Look: flache dunkle Fläche mit 1-px-Rahmen statt
-- der Rahmen-Grafik, Radio/Häkchen als flaches Kästchen in Surf Green. Gilt für alle Menüs im
-- Spiel (lag früher im Damage-Meter-Skin).
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local styledMenus = setmetatable({}, { __mode = "k" })

local function FlattenMenu(style)
    for _, region in ipairs({ style:GetRegions() }) do
        if region:IsObjectType("Texture") and not styledMenus[region] then
            region:SetTexture(WHITE)
            region:SetVertexColor(unpack(ns.STYLE.panelColor))
            region:SetAlpha(1)
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", style, "TOPLEFT", -ns.Snap(2), ns.Snap(2))
            region:SetPoint("BOTTOMRIGHT", style, "BOTTOMRIGHT", ns.Snap(2), -ns.Snap(2))
        end
    end
    if not styledMenus[style] then
        styledMenus[style] = true
        local border = CreateFrame("Frame", nil, style)
        border:SetPoint("TOPLEFT", -ns.Snap(2), ns.Snap(2))
        border:SetPoint("BOTTOMRIGHT", ns.Snap(2), -ns.Snap(2))
        for _, edge in ipairs(ns.AddBorder(border, true)) do styledMenus[edge] = true end
    end
end

-- Radio-Knöpfe und Häkchen: flaches dunkles Kästchen, ausgewählt Surf Green (Radio: Quadrat,
-- Checkbox: mUI-Häkchen) – wie in den mUI-Einstellungen. Blizzard legt die zwei Grafiken bei
-- jedem Eintrag neu an (leftTexture1 = Kästchen, leftTexture2 = nur wenn gewählt).
local BOX = 12

local function FlatSelection(frame, isCheckbox)
    local box, mark = frame.leftTexture1, frame.leftTexture2
    if box then
        box:SetTexture(WHITE)
        box:SetVertexColor(0.15, 0.15, 0.15, 1)
        box:SetSize(BOX, BOX)
    end
    if mark and box then
        mark:ClearAllPoints()
        mark:SetPoint("CENTER", box, "CENTER")
        if isCheckbox then
            mark:SetTexture(ns.MEDIA .. "Icons\\Check")
            mark:SetSize(BOX, BOX)
        else
            mark:SetTexture(WHITE)
            mark:SetSize(BOX - 6, BOX - 6)
        end
        mark:SetVertexColor(unpack(ns.UI.ACCENT))
    end
    -- etwas Luft zwischen Kästchen und Text (Blizzard: Radio 1 px, Checkbox 7 px)
    local text = frame.fontString
    if text and box then pcall(text.SetPoint, text, "LEFT", box, "RIGHT", ns.Snap(6), 0) end
end

ns:On("PLAYER_LOGIN", function()
    for _, mixin in ipairs({ MenuStyle1Mixin, MenuStyle2Mixin }) do
        if mixin and mixin.Generate then hooksecurefunc(mixin, "Generate", FlattenMenu) end
    end
    if MenuVariants then
        if MenuVariants.CreateRadio then
            hooksecurefunc(MenuVariants, "CreateRadio", function(_, frame) FlatSelection(frame, false) end)
        end
        if MenuVariants.CreateCheckbox then
            hooksecurefunc(MenuVariants, "CreateCheckbox", function(_, frame) FlatSelection(frame, true) end)
        end
    end
end)
