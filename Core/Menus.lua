-- Skins all Blizzard menus (MenuUtil, dropdowns): flat dark panel with a 1px border, radio and
-- check marks as flat Surf Green boxes.
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

-- Radio/checkbox: flat dark box, selected mark in Surf Green (radio: square, checkbox: mUI check).
-- Blizzard recreates both textures per entry (leftTexture1 = box, leftTexture2 = only when selected).
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
    -- Consistent gap between box and text (Blizzard uses 1px for radio, 7px for checkbox)
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
