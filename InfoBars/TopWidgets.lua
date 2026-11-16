-- Blizzard's top center widgets (battleground flag/score, world PvP objectives ...):
--   Blizzard anchors them 15 px below the screen edge, right on top of the XP bar. Move them below
--   the lowest visible top bar and give their text the mUI font.
local _, ns = ...

local GAP = 6

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

local function StyleText(text)
    if not text or text.muiStyled then return end
    text.muiStyled = true
    ns.SetFont(text, 13, "OUTLINE")
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
end

local function StyleWidget(widget, container)
    if container ~= UIWidgetTopCenterContainerFrame then return end
    StyleText(widget.Text)
end

ns:On("PLAYER_LOGIN", function()
    if not UIWidgetTopCenterContainerFrame then return end
    if UIWidgetTemplateIconAndTextMixin and UIWidgetTemplateIconAndTextMixin.Setup then
        hooksecurefunc(UIWidgetTemplateIconAndTextMixin, "Setup", function(self, _, container)
            StyleWidget(self, container)
        end)
    end
    -- widgets built before our hook (/reload inside a battleground)
    for _, widget in pairs(UIWidgetTopCenterContainerFrame.widgetFrames or {}) do
        StyleText(widget.Text)
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
