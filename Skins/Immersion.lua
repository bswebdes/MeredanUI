-- Immersion (gossip/quest addon) in the mUI look: talk box, answer buttons, objectives and rewards.
--
--   [ answer 1 ]          <- answers as mUI bevel plates, focus = lit edge
--   [ answer 2 ]
--   +------------------------------------+
--   | [model]  NAME (display font)       |  <- talk box: mUI panel + deep frame, model in an item frame
--   |          text ...                  |
--   |====================================|  <- reading progress as a thin gold line on the bottom edge
--   +------------------------------------+
--   +------------------------------------+
--   | Objectives / rewards               |  <- second panel below, reward items in item frames + upgrade arrow
--   +------------------------------------+
--
-- Art only: Immersion's own textures are hidden through vertex alpha 0 (its fade-in animations reset
-- region alpha, see Display/Frame.xml there), mUI parts are drawn below/around them. No Immersion
-- function is replaced; we only hook after its own calls. Positions Immersion never re-anchors
-- (elements panel, progress bar, highlight frames) are moved slightly to fit the frame.
-- Switch: ns.db.immersionStyle (Skins page, after a reload).
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local INSET = 10       -- Immersion's background art leaves this margin around the talk box
local ELEMENTS_GAP = 12 -- extra room between talk box and elements panel for both frames

local function Styled() return ns.IS_FOREVER and ns.db and ns.db.immersionStyle ~= false end

local function Hide(tex)
    if tex and tex.SetVertexColor then tex:SetVertexColor(1, 1, 1, 0) end
end

local function Tex(frame, layer, sub)
    local t = frame:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(WHITE)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
    return t
end

-- 1 px frame of four lines, `inset` px inside the frame's bounds (negative = outside)
local function Lines(frame, layer, sub, inset, r, g, b, a)
    local px = ns.PixelSize()
    local o = (inset or 0) * px
    local top, bottom, left, right = Tex(frame, layer, sub), Tex(frame, layer, sub), Tex(frame, layer, sub), Tex(frame, layer, sub)
    top:SetPoint("TOPLEFT", o, -o) top:SetPoint("TOPRIGHT", -o, -o) top:SetHeight(px)
    bottom:SetPoint("BOTTOMLEFT", o, o) bottom:SetPoint("BOTTOMRIGHT", -o, o) bottom:SetHeight(px)
    left:SetPoint("TOPLEFT", o, -o) left:SetPoint("BOTTOMLEFT", o, o) left:SetWidth(px)
    right:SetPoint("TOPRIGHT", -o, -o) right:SetPoint("BOTTOMRIGHT", -o, o) right:SetWidth(px)
    for _, t in ipairs({ top, bottom, left, right }) do t:SetVertexColor(r, g, b, a or 1) end
    return { top, bottom, left, right }
end

-- mUI window surface plus the deep frame around it
local function Panel(frame, l, t, r, b)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOPLEFT", ns.Snap(l), -ns.Snap(t))
    bg:SetPoint("BOTTOMRIGHT", -ns.Snap(r), ns.Snap(b))
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.RuneFrame(frame, { target = bg })
    return bg
end

-- Item frame around an icon-sized area: black outline outside, material edge inside
local function ItemRing(parent, target, level)
    local ring = CreateFrame("Frame", nil, parent)
    local px = ns.PixelSize()
    ring:SetPoint("TOPLEFT", target, "TOPLEFT", -2 * px, 2 * px)
    ring:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2 * px, -2 * px)
    ring:SetFrameLevel((level or parent:GetFrameLevel()) + 1)
    local item = ns.Material().item
    Lines(ring, "OVERLAY", 1, 0, 0, 0, 0, 1)
    Lines(ring, "OVERLAY", 2, 1, item[1], item[2], item[3], 1)
    return ring
end

-- Focus/hover edges Immersion fades in and out (its "Hilite" frames carry a backdrop)
local function LitEdge(frame)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop({ edgeFile = WHITE, edgeSize = ns.PixelSize() })
    local lit = ns.Material().lit
    frame:SetBackdropBorderColor(lit[1], lit[2], lit[3], 0.9)
end

-- Answer buttons ----------------------------------------------------------------------------------

local PLATE_FILL = {
    normal = { { 0.235, 0.188, 0.133 }, { 0.149, 0.114, 0.078 } },
    hover = { { 0.329, 0.263, 0.184 }, { 0.2, 0.153, 0.106 } },
}

-- UI.Bevel look, but with a small gap above and below: Immersion stacks its buttons edge to edge
local function Plate(button)
    local px, gap, m = ns.PixelSize(), ns.Snap(3), ns.Material()
    local outline = Tex(button, "BACKGROUND", -8)
    outline:SetPoint("TOPLEFT", 0, -gap)
    outline:SetPoint("BOTTOMRIGHT", 0, gap)
    outline:SetVertexColor(0, 0, 0, 1)
    local edge = Tex(button, "BACKGROUND", -7)
    edge:SetPoint("TOPLEFT", outline, "TOPLEFT", px, -px)
    edge:SetPoint("BOTTOMRIGHT", outline, "BOTTOMRIGHT", -px, px)
    edge:SetGradient("VERTICAL", CreateColor(unpack(m.dark)), CreateColor(unpack(m.lit)))
    local fill = Tex(button, "BACKGROUND", -6)
    fill:SetPoint("TOPLEFT", edge, "TOPLEFT", px, -px)
    fill:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT", -px, px)
    local shine = Tex(button, "BACKGROUND", -5)
    shine:SetPoint("TOPLEFT", fill)
    shine:SetPoint("TOPRIGHT", fill)
    shine:SetHeight(px)
    shine:SetVertexColor(1, 0.9, 0.7, 0.18)
    local function State(hover)
        local c = hover and PLATE_FILL.hover or PLATE_FILL.normal
        fill:SetGradient("VERTICAL", CreateColor(c[2][1], c[2][2], c[2][3], 1), CreateColor(c[1][1], c[1][2], c[1][3], 1))
    end
    State(false)
    button:HookScript("OnEnter", function() State(true) end)
    button:HookScript("OnLeave", function() State(false) end)
    return outline
end

local skinned = setmetatable({}, { __mode = "k" })

local function SkinTitleButton(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    if button.SetBackdrop then button:SetBackdrop(nil) end
    if button.Overlay and button.Overlay.SetBackdrop then button.Overlay:SetBackdrop(nil) end
    local outline = Plate(button)
    if button.Hilite then
        LitEdge(button.Hilite)
        button.Hilite:ClearAllPoints()
        button.Hilite:SetAllPoints(outline)
    end
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end
    if button.Label then ns.SetFont(button.Label, 14) end
    if button.Counter then
        ns.SetFont(button.Counter, 12, nil, "bold")
        button.Counter:SetTextColor(unpack(ns.UI.HEADING))
    end
end

-- Talk box ------------------------------------------------------------------------------------------

local talkboxBG -- the talk box surface; the elements panel below takes its width

local function SkinTalkBox(talkbox)
    local bg = Panel(talkbox, INSET, INSET, INSET, INSET)
    talkboxBG = bg
    local backgroundFrame = talkbox.BackgroundFrame
    if backgroundFrame then
        Hide(backgroundFrame.TextBackground)
        Hide(backgroundFrame.SolidBackground)
        -- quest theme art: Immersion shows it per quest and re-colours it with a gradient, which
        -- overrides any vertex alpha - so keep it hidden instead
        local kit = backgroundFrame.OverlayKit
        if kit then
            kit:Hide()
            hooksecurefunc(kit, "Show", function(self) self:Hide() end)
        end
    end
    if talkbox.PortraitFrame then Hide(talkbox.PortraitFrame.Portrait) end
    local main = talkbox.MainFrame
    if main then
        Hide(main.Sheen)
        Hide(main.TextSheen)
        if main.Overlay then
            Hide(main.Overlay.Glow_TopBar)
            Hide(main.Overlay.Glow_LeftBar)
            Hide(main.Overlay.Glow_RightBar)
        end
        local model = main.Model
        if model then
            Hide(model.ModelShadow)
            local portraitBG = model.PortraitBG -- shown/hidden by Immersion's "disable portrait"
            if portraitBG then
                portraitBG:SetTexture(WHITE)
                portraitBG:ClearAllPoints()
                portraitBG:SetAllPoints(model)
                portraitBG:SetGradient("VERTICAL", CreateColor(0.06, 0.045, 0.03, 1), CreateColor(0.2, 0.155, 0.1, 1))
            end
            local ring = ItemRing(model, model)
            if portraitBG then
                ring:SetShown(portraitBG:IsShown())
                hooksecurefunc(portraitBG, "SetShown", function(_, shown) ring:SetShown(shown and true or false) end)
            end
        end
        if main.CloseButton and ns.SkinKit then ns.SkinKit.IconButton(main.CloseButton, "Close", 12) end
    end
    if talkbox.Hilite then
        LitEdge(talkbox.Hilite)
        talkbox.Hilite:ClearAllPoints()
        talkbox.Hilite:SetAllPoints(bg)
    end
    local name = talkbox.NameFrame and talkbox.NameFrame.Name
    if name then
        ns.SetFont(name, 20, nil, "display")
        name:SetTextColor(unpack(ns.UI.TITLE))
    end
    local progress = talkbox.TextFrame and talkbox.TextFrame.SpeechProgress
    if progress then
        ns.SetFont(progress, 13, nil, "bold")
        progress:SetTextColor(unpack(ns.UI.HEADING))
    end
    -- reading progress: a thin gold line on the bottom edge of the panel
    local bar = talkbox.ProgressionBar
    if bar then
        local fill = bar:GetStatusBarTexture()
        for _, region in ipairs({ bar:GetRegions() }) do
            if region ~= fill and region.IsObjectType and region:IsObjectType("Texture") then Hide(region) end
        end
        local px = ns.PixelSize()
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", px, px)
        bar:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -px, px)
        bar:SetHeight(ns.Snap(3))
        if fill then
            fill:SetTexture(WHITE)
            fill:SetGradient("VERTICAL", CreateColor(0.627, 0.447, 0.267, 1), CreateColor(0.91, 0.76, 0.48, 1))
        end
    end
end

-- Objectives and rewards ------------------------------------------------------------------------

local function SkinItemButton(button, withUpgrade)
    if not button or skinned[button] then return end
    skinned[button] = true
    local icon = button.Icon
    if button.NameFrame then button.NameFrame:SetTexture(nil) end -- its vertex colour is reset per item
    if button.Border then button.Border:SetTexture(nil) end
    if icon then
        if button.Mask then icon:RemoveMaskTexture(button.Mask) end
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local px = ns.PixelSize()
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 4 * px, -4 * px)
        icon:SetSize(ns.Snap(44), ns.Snap(44))
        ItemRing(button, icon)
        -- name on a dark plate to the right, like mUI's own quest window
        local plate = Tex(button, "BACKGROUND", -6)
        plate:SetPoint("TOPLEFT", icon, "TOPRIGHT", 2 * px, 0)
        plate:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 2 * px, 0)
        plate:SetPoint("RIGHT", button, "RIGHT", -4 * px, 0)
        plate:SetColorTexture(unpack(ns.UI.FIELD))
    end
    if button.Name then ns.SetFont(button.Name, 13) end
    if button.Count then ns.SetFont(button.Count, 12, "OUTLINE", "bold") end
    if withUpgrade then
        local holder = CreateFrame("Frame", nil, button)
        holder:SetSize(18, 18)
        holder:SetPoint("TOPLEFT", icon or button, "TOPLEFT", 1, -1)
        holder:SetFrameLevel(button:GetFrameLevel() + 5)
        local shadow = ns.UI.Icon(holder, "Upgrade", 18, { 0, 0, 0, 0.9 })
        shadow:SetPoint("CENTER", 1, -1)
        shadow:SetDrawLayer("OVERLAY", 1)
        local arrow = ns.UI.Icon(holder, "Upgrade", 18, ns.UPGRADE_COLOR)
        arrow:SetPoint("CENTER")
        arrow:SetDrawLayer("OVERLAY", 2)
        holder:Hide()
        button.muiUpgrade = holder
    end
end

-- Arrow on reward items that beat what's equipped (same rule as the bags: any gain counts)
local function UpdateUpgrade(button)
    if not button.muiUpgrade then return end
    local upgrade
    if button:IsShown() and button.objectType == "item" and (button.type == "choice" or button.type == "reward") then
        local link = GetQuestItemLink(button.type, button:GetID())
        upgrade = link and ns.UpgradePercent and ns.UpgradePercent(link)
    end
    button.muiUpgrade:SetShown(upgrade and upgrade > 0 or false)
end

local function SkinItemButtons(prefix, withUpgrade)
    local i = 1
    while _G[prefix .. i] do
        local button = _G[prefix .. i]
        SkinItemButton(button, withUpgrade)
        UpdateUpgrade(button)
        i = i + 1
    end
end

local function SkinHeader(text)
    if not text then return end
    ns.SetFont(text, 15, nil, "display")
    text:SetTextColor(unpack(ns.UI.HEADING))
end

local function SkinElements(talkbox)
    local elements = talkbox.Elements
    if not elements then return end
    if elements.SetBackdrop then
        elements:SetBackdrop(nil)
        -- Immersion's "solid background" option sets it again
        hooksecurefunc(elements, "SetBackdrop", function(self, backdrop)
            if backdrop then self:SetBackdrop(nil) end
        end)
    end
    elements:ClearAllPoints()
    -- left-aligned with the talk box (Immersion centres it), so the content lines up with the text
    elements:SetPoint("TOPLEFT", talkbox, "BOTTOMLEFT", 0, 8 - ELEMENTS_GAP)
    -- Immersion shrinks the frame to its content; the panel keeps the talk box's full width
    local bg = elements:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOP", elements, "TOP", 0, -ns.Snap(6))
    bg:SetPoint("BOTTOM", elements, "BOTTOM")
    if talkboxBG then
        bg:SetPoint("LEFT", talkboxBG, "LEFT")
        bg:SetPoint("RIGHT", talkboxBG, "RIGHT")
    else
        bg:SetPoint("LEFT", elements, "LEFT", ns.Snap(INSET), 0)
        bg:SetPoint("RIGHT", elements, "RIGHT", -ns.Snap(INSET), 0)
    end
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.RuneFrame(elements, { target = bg })
    local content, progress = elements.Content, elements.Progress
    local rewards = content and content.RewardsFrame
    local highlight = rewards and rewards.ItemHighlight
    if highlight then
        Hide(highlight.Icon)
        Hide(highlight.NameTag)
        Hide(highlight.TextSheen)
        local lit = ns.Material().lit
        Lines(highlight, "OVERLAY", 3, 0, lit[1], lit[2], lit[3], 1)
    end
    local function Headers()
        SkinHeader(content and content.ObjectivesHeader)
        SkinHeader(rewards and rewards.Header)
        SkinHeader(progress and progress.ReqText)
    end
    Headers()
    -- SetMaterial recolours the headers whenever the material changes
    if elements.SetMaterial then hooksecurefunc(elements, "SetMaterial", Headers) end
    if elements.Display then
        hooksecurefunc(elements, "Display", function() SkinItemButtons("ImmersionQuestInfoItem", true) end)
    end
    if elements.ShowProgress then
        hooksecurefunc(elements, "ShowProgress", function() SkinItemButtons("ImmersionProgressItem", false) end)
    end
end

-- Setup -------------------------------------------------------------------------------------------

local function Setup()
    local frame = ImmersionFrame
    if not frame or not Styled() then return end
    local talkbox, titles = frame.TalkBox, frame.TitleButtons
    if talkbox then
        SkinTalkBox(talkbox)
        SkinElements(talkbox)
    end
    if titles and titles.GetButton then
        for _, button in pairs(titles.Buttons or {}) do SkinTitleButton(button) end
        hooksecurefunc(titles, "GetButton", function(self, index) SkinTitleButton(self.Buttons[index]) end)
    end
end

ns:On("PLAYER_LOGIN", function()
    if C_AddOns.IsAddOnLoaded("Immersion") then Setup() end
end)
