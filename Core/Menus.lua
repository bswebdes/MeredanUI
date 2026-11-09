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

-- Section titles: Blizzard colors them NORMAL_FONT_COLOR (yellow) in an initializer right after the
-- font string is created -> recolor one frame later in Surf Green. Custom title colors (e.g. the class
-- color of a unit menu) stay. The plain C method is used: the menu wraps SetTextColor and would cache
-- an addon-written color in its own tables.
local rawSetTextColor
local function RecolorTitle(frame)
    local fs = frame and frame.fontString
    if not (fs and fs.GetTextColor) then return end
    local r, g, b = fs:GetTextColor()
    local y = NORMAL_FONT_COLOR
    if math.abs(r - y.r) < 0.02 and math.abs(g - y.g) < 0.02 and math.abs(b - y.b) < 0.02 then
        if not rawSetTextColor then rawSetTextColor = UIParent:CreateFontString().SetTextColor end
        local a = ns.UI.ACCENT
        rawSetTextColor(fs, a[1], a[2], a[3])
    end
end

ns:On("PLAYER_LOGIN", function()
    for _, mixin in ipairs({ MenuStyle1Mixin, MenuStyle2Mixin }) do
        if mixin and mixin.Generate then hooksecurefunc(mixin, "Generate", FlattenMenu) end
    end
    if MenuVariants then
        -- hover row: Blizzard's yellow quest-title glow -> soft Surf Green
        if MenuVariants.CreateHighlight then
            hooksecurefunc(MenuVariants, "CreateHighlight", function(frame)
                local h = frame and frame.highlight
                if h and h.SetColorTexture then
                    local a = ns.UI.ACCENT
                    h:SetColorTexture(a[1], a[2], a[3], 0.2)
                    h:SetBlendMode("BLEND")
                    -- reach the menu's inner edges evenly (the row itself is inset)
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 0)
                    h:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, 0)
                end
            end)
        end
        if MenuVariants.CreateFontString then
            hooksecurefunc(MenuVariants, "CreateFontString", function(frame)
                C_Timer.After(0, function() RecolorTitle(frame) end)
            end)
        end
        -- submenu arrow: our chevron, muted, instead of Blizzard's yellow triangle
        if MenuVariants.CreateSubmenuArrow then
            hooksecurefunc(MenuVariants, "CreateSubmenuArrow", function(frame)
                local arrow = frame and frame.arrow
                if not arrow then return end
                arrow:SetTexture(ns.MEDIA .. "Icons\\ChevronDown")
                arrow:SetRotation(math.pi / 2)
                arrow:SetSize(12, 12)
                arrow:SetVertexColor(unpack(ns.UI.MUTED))
            end)
        end
        if MenuVariants.CreateRadio then
            hooksecurefunc(MenuVariants, "CreateRadio", function(_, frame) FlatSelection(frame, false) end)
        end
        if MenuVariants.CreateCheckbox then
            hooksecurefunc(MenuVariants, "CreateCheckbox", function(_, frame) FlatSelection(frame, true) end)
        end
    end
end)
