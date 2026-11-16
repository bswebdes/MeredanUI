-- Blizzard's top center widgets (battleground flag/score, world PvP objectives ...):
--   Blizzard anchors them 15 px below the screen edge, right on top of the XP bar. Move them below
--   the lowest visible top bar and restyle the icon-and-text ones as mUI plates:
--
--     [emblem]  0/3  [flag]      <- dark plate, faction edge on the left, flag = carried flag
--
-- Only alpha/color/font on Blizzard regions; our art sits in our own textures (Blizzard's Setup
-- resets the texture kit on every update, our hook runs after it).
local _, ns = ...

local GAP = 6
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EMBLEM = { alliance = "AllianceEmblem", horde = "HordeEmblem" }
local FACTION_RGB = { alliance = { 0.30, 0.55, 1 }, horde = { 0.90, 0.22, 0.20 } }

local function Place()
    local container = UIWidgetTopCenterContainerFrame
    if not container then return end
    local below = ns.XPBarBottom and ns.XPBarBottom()
    container:ClearAllPoints()
    if below then
        container:SetPoint("TOP", below, "BOTTOM", 0, -(ns.Snap(GAP) + 2 * ns.ThinShellReach()))
    else
        container:SetPoint("TOP", UIParent, "TOP", 0, -ns.Snap(ns.SCREEN_MARGIN))
    end
end
ns.PlaceTopWidgets = Place

-- "alliance_icon_horde_flag" -> team alliance, carried flag horde; "x_icon_and_flag" -> own flag
local function ParseKit(atlas)
    if type(atlas) ~= "string" then return end
    local team, flag = atlas:lower():match("^(%a+)_icon_(%a+)_flag")
    if not team then return atlas:lower():match("^(%a+)_") end
    return team, flag == "and" and team or flag
end

local parts = setmetatable({}, { __mode = "k" })
local PLATE_W, PLATE_H, EMBLEM_SIZE, FLAG_SIZE = 104, 22, 22, 14

-- Our own row on top of Blizzard's widget (its icon art is 42 px tall with empty space and overlaps
-- the next widget, so we do not reuse its layout): fixed width, so all rows line up.
local function Build(widget)
    local p = {}
    local px = ns.PixelSize()
    local plate = CreateFrame("Frame", nil, widget)
    plate:SetSize(ns.Snap(PLATE_W), ns.Snap(PLATE_H))
    plate:SetPoint("CENTER", widget, "CENTER", 0, 0)
    p.plate = plate
    local bg = plate:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetGradient("HORIZONTAL", CreateColor(0.05, 0.04, 0.03, 0.9), CreateColor(0.05, 0.04, 0.03, 0.6))
    p.tint = plate:CreateTexture(nil, "BORDER")
    p.tint:SetTexture(WHITE)
    p.tint:SetPoint("TOPLEFT")
    p.tint:SetPoint("BOTTOMLEFT")
    p.tint:SetWidth(ns.Snap(56))
    p.edge = plate:CreateTexture(nil, "ARTWORK")
    p.edge:SetTexture(WHITE)
    p.edge:SetPoint("TOPLEFT")
    p.edge:SetPoint("BOTTOMLEFT")
    p.edge:SetWidth(2 * px)
    ns.AddBorder(plate)

    p.emblem = plate:CreateTexture(nil, "OVERLAY")
    p.emblem:SetSize(ns.Snap(EMBLEM_SIZE + 6), ns.Snap(EMBLEM_SIZE + 6)) -- the emblem art has a soft edge
    p.emblem:SetPoint("CENTER", plate, "LEFT", ns.Snap(4 + EMBLEM_SIZE / 2), 0)
    p.text = ns.CreateText(plate, 15, "LEFT", "OUTLINE", "bold")
    p.text:SetPoint("LEFT", plate, "LEFT", ns.Snap(4 + EMBLEM_SIZE + 8), 0)
    p.flag = plate:CreateTexture(nil, "OVERLAY")
    p.flag:SetTexture(ns.MEDIA .. "Icons\\Flag")
    p.flag:SetSize(ns.Snap(FLAG_SIZE), ns.Snap(FLAG_SIZE))
    p.flag:SetPoint("RIGHT", plate, "RIGHT", -ns.Snap(6), 0)
    p.flag:Hide()
    parts[widget] = p
    return p
end

local function Style(widget, container)
    if container ~= UIWidgetTopCenterContainerFrame or not (widget.Icon and widget.Text) then return end
    local team, carried = ParseKit(widget.Icon:GetAtlas())
    local emblem = team and EMBLEM[team]
    local p = parts[widget]
    local dynamic = widget.DynamicIconButton
    if not emblem then -- other icon-and-text widgets stay Blizzard's
        if p then
            p.plate:Hide()
            widget.Icon:SetAlpha(1)
            widget.Text:SetAlpha(1)
            if dynamic and dynamic.Icon then dynamic.Icon:SetAlpha(1) end
        end
        return
    end
    p = p or Build(widget)
    widget.Icon:SetAlpha(0)
    widget.Text:SetAlpha(0)
    p.emblem:SetAtlas(emblem)
    local c = FACTION_RGB[team]
    p.edge:SetVertexColor(c[1], c[2], c[3], 1)
    p.tint:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.4), CreateColor(c[1], c[2], c[3], 0))
    p.text:SetText(widget.Text:GetText() or "")

    -- carried flag: Blizzard shows its dynamic icon only while the team holds a flag
    local holding = dynamic and dynamic:IsShown() and dynamic.Icon and dynamic.Icon:IsShown()
        and dynamic.Icon:GetAtlas()
    if dynamic and dynamic.Icon then dynamic.Icon:SetAlpha(0) end
    if holding then
        local _, flag = ParseKit(holding)
        local fc = FACTION_RGB[flag or carried] or c
        p.flag:SetVertexColor(fc[1], fc[2], fc[3], 1)
        p.flag:Show()
    else
        p.flag:Hide()
    end
    p.plate:Show()
end

ns:On("PLAYER_LOGIN", function()
    if not UIWidgetTopCenterContainerFrame then return end
    if UIWidgetTemplateIconAndTextMixin and UIWidgetTemplateIconAndTextMixin.Setup then
        hooksecurefunc(UIWidgetTemplateIconAndTextMixin, "Setup", Style)
    end
    -- widgets built before our hook (/reload inside a battleground)
    -- (they copied the unhooked Setup at creation, so hook them directly)
    for _, widget in pairs(UIWidgetTopCenterContainerFrame.widgetFrames or {}) do
        if widget.Icon and widget.Text and widget.Setup then hooksecurefunc(widget, "Setup", Style) end
        Style(widget, UIWidgetTopCenterContainerFrame)
    end
    -- the XP and pet bars come and go (level, pet, visibility mode)
    for _, name in ipairs({ "MeredanUIXPBar", "MeredanUIPetXPBar" }) do
        local bar = _G[name]
        if bar then
            bar:HookScript("OnShow", Place)
            bar:HookScript("OnHide", Place)
        end
    end
    ns.OnLayout(Place)
    Place()
end)
