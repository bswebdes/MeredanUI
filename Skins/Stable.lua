-- Hunter stable (PetStableFrame, Blizzard_StableUI Camelot variant) in mUI style. Blizzard's frame
-- does all the work (select, drag/swap pets, buy slots, 3D model); we only restyle and re-place it:
--
--   +-[i] Stables -------------------------------------------- [x]-+
--   |     Stable Master name                                       |
--   | [:)] Wolf Level 60 Wolf                          12g 34s 5c  |
--   |      Loyalty: Best Friend                                    |
--   | +----------------------------------------------------------+ |
--   | |          3D pet model (spec background), XP bar          | |
--   | +----------------------------------------------------------+ |
--   | Current pet   Stabled pets                                   |
--   | [pet]         [pet] [pet]                       Stable slot  |
--   | Cost: 1g                                         [Purchase]  |
--   +--------------------------------------------------------------+
--
-- Rules as in Skins/Macros.lua: art only via SetAlpha(0) or recolor, no SetScript on Blizzard
-- frames, no fields on Blizzard tables. Blizzard re-anchors PetStableCurrentPet ("TOP" point) on
-- every Update, so the slot row keeps that point and is re-placed after Update.
local _, ns = ...
local G = _G --[[@as table<string, any>]] -- Blizzard globals missing from the annotations

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = { 0, 0, 0, 1 }
local PAD, ICON = 18, 46
local WIDTH = 460
local TOOLBAR_TOP = PAD + ICON + 14   -- 78
local SCENE_TOP = TOOLBAR_TOP + 36 + 10
local FOOTER = 54
local SLOT = ICON
local SLOT_BOTTOM = FOOTER + 6        -- slot row bottom edge (from the bottom)
local SCENE_BOTTOM = SLOT_BOTTOM + SLOT + 34
local STABLED_X = PAD + SLOT + 60     -- first stabled slot

local skinned = setmetatable({}, { __mode = "k" })
local own = setmetatable({}, { __mode = "k" })
local slotParts = setmetatable({}, { __mode = "k" })
local frame, portrait, subtitle
local fonts
local applied = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.stableSkin ~= false
end

local function Once(object)
    if type(object) ~= "table" or skinned[object] then return false end
    if object.IsForbidden and object:IsForbidden() then return false end
    skinned[object] = true
    return true
end

local function IsTexture(region)
    return type(region) == "table" and region.IsObjectType and region:IsObjectType("Texture")
end

local function Fade(region)
    if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
end

local function FadeRegions(target, keep)
    if type(target) ~= "table" or not target.GetRegions then return end
    for _, region in ipairs({ target:GetRegions() }) do
        if IsTexture(region) and not own[region] and not (keep and keep[region]) then region:SetAlpha(0) end
    end
end

local function Tex(parent, layer, sublevel, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    if color then tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    own[tex] = true
    return tex
end

-- 1 px outer border around target (textures on parent)
local function Edges(parent, target, color, layer)
    local px = ns.PixelSize()
    local c = color or BLACK
    local edges = {}
    for i = 1, 4 do
        local edge = parent:CreateTexture(nil, layer or "BORDER")
        edge:SetTexture(WHITE)
        edge:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        edge:SetSnapToPixelGrid(false)
        edge:SetTexelSnappingBias(0)
        own[edge] = true
        edges[i] = edge
    end
    edges[1]:SetPoint("TOPLEFT", target, "TOPLEFT", -px, px)
    edges[1]:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", px, 0)
    edges[2]:SetPoint("TOPLEFT", target, "BOTTOMLEFT", -px, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, -px)
    edges[3]:SetPoint("TOPLEFT", target, "TOPLEFT", -px, 0)
    edges[3]:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", 0, 0)
    edges[4]:SetPoint("TOPLEFT", target, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, 0)
    return edges
end

local function Border(target, inside, thickness)
    local edges = ns.AddBorder(target, inside, thickness)
    for _, edge in ipairs(edges) do own[edge] = true end
    return edges
end

-- Background + border + Surf Green top line
local function Panel(target)
    local c = ns.STYLE.panelColor
    local bg = Tex(target, "BACKGROUND", -8, { c[1], c[2], c[3], 0.97 })
    bg:SetAllPoints()
    ns.RuneFrame(target)
end

local function Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, base, color)
        local font = CreateFont(name)
        font:CopyFontObject(base)
        font:SetTextColor(color[1], color[2], color[3])
        return font
    end
    fonts = {
        normal = Make("MeredanUIStableButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIStableButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUIStableButtonDisabled", GameFontDisable, UI.MUTED),
    }
    return fonts
end

local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
    "GetCheckedTexture", "GetDisabledCheckedTexture" }
local function FadeButtonTextures(button, keep)
    for _, getter in ipairs(BUTTON_TEXTURES) do
        local fn = button[getter]
        local tex = fn and fn(button)
        if tex and tex ~= keep then Fade(tex) end
    end
end

-- Controls ---------------------------------------------------------------------------------------

-- flat button (UIPanelButtonTemplate); hover via HIGHLIGHT layer
local function SkinButton(button)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(button[key]) end
    FadeButtonTextures(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    local hover = Tex(button, "HIGHLIGHT", 0, UI.HOVER)
    hover:SetAllPoints()
    Border(button)
    if button:GetFontString() then
        local f = Fonts()
        button:SetNormalFontObject(f.normal)
        button:SetHighlightFontObject(f.highlight)
        button:SetDisabledFontObject(f.disabled)
    end
end

local function SkinIconButton(button, iconName, iconSize)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = UI.Icon(button, iconName, iconSize or 14)
    own[icon] = true
    icon:SetPoint("CENTER", bg)
    button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
end

-- Model toolbar (zoom, rotate, reset; appears on hover): flat with our icons, as in Skins/DressUp.lua
local SCENE_ICONS = {
    zoomInButton = { "Plus" }, zoomOutButton = { "Minus" },
    rotateLeftButton = { "ChevronDown", -math.pi / 2 }, rotateRightButton = { "ChevronDown", math.pi / 2 },
    resetButton = { "Reset" },
}
local function SkinSceneControls(control)
    if type(control) ~= "table" or not Once(control) then return end
    local UI = ns.UI
    for key, def in pairs(SCENE_ICONS) do
        local button = control[key]
        if button and Once(button) then
            FadeButtonTextures(button)
            Fade(button.Icon)
            local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
            bg:SetPoint("TOPLEFT", 5, -5)
            bg:SetPoint("BOTTOMRIGHT", -5, 5)
            Edges(button, bg)
            local icon = UI.Icon(button, def[1], 12)
            own[icon] = true
            icon:SetPoint("CENTER", bg)
            if def[2] then icon:SetRotation(def[2]) end
            button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
            button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
        end
    end
end

-- Pet slots -----------------------------------------------------------------------------------------

local function SlotIcon(slot)
    local name = slot:GetName()
    return name and _G[name .. "IconTexture"]
end

-- State from Blizzard's own (faded) textures: locked / empty / selected
local function UpdateSlot(slot)
    local parts = slotParts[slot]
    if not parts then return end
    local locked = slot.lockedBackground and slot.lockedBackground:IsShown()
    local icon = SlotIcon(slot)
    local texture = icon and icon:GetTexture()
    local empty = not texture or texture == 0
    parts.empty:SetShown(empty and not locked)
    parts.bg:SetAlpha(locked and 0.45 or 1)
    local on = slot:GetChecked() and true or false
    for _, edge in ipairs(parts.selected) do edge:SetShown(on) end
end

local function UpdateSlots()
    for slot in pairs(slotParts) do UpdateSlot(slot) end
end

local function SkinSlot(slot)
    if type(slot) ~= "table" or not Once(slot) then return end
    local UI = ns.UI
    local icon = SlotIcon(slot)
    -- Keep the pet icon and the lock; frames, glow and the generic empty-slot paw go
    FadeRegions(slot, { [icon or slot] = true, [slot.lockIcon or slot] = true })
    FadeButtonTextures(slot)
    local bg = Tex(slot, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Border(slot)
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local empty = UI.Icon(slot, "Pet", 20, UI.MUTED)
    empty:SetDrawLayer("BACKGROUND", 0)
    empty:SetAlpha(0.5)
    own[empty] = true
    empty:SetPoint("CENTER")
    local hover = Tex(slot, "HIGHLIGHT", 0, { 1, 1, 1, 0.12 })
    hover:SetAllPoints()
    local selected = Border(slot, true, 2)
    for _, edge in ipairs(selected) do
        edge:SetVertexColor(unpack(UI.ACCENT))
        edge:SetDrawLayer("OVERLAY", 7)
    end
    slotParts[slot] = { bg = bg, empty = empty, selected = selected }
    if slot.Text then
        ns.SetFont(slot.Text, 12, "", "bold")
        slot.Text:SetTextColor(unpack(UI.MUTED))
    end
    if slot.Update then hooksecurefunc(slot, "Update", UpdateSlot) end
    -- CheckButtons toggle themselves on click (also while swapping); re-read the state afterwards
    slot:HookScript("OnClick", function() UpdateSlots() end)
    UpdateSlot(slot)
end

-- XP bar (ColoredProgressBarTemplate): flat track, our fill; Blizzard sets the percent every frame
local function SkinExpBar(bar)
    if type(bar) ~= "table" or not bar.FillArea or not Once(bar) then return end
    local UI = ns.UI
    FadeRegions(bar)
    local area = bar.FillArea
    local track = Tex(bar, "BACKGROUND", -8, { 0.04, 0.04, 0.05, 0.85 })
    track:SetPoint("LEFT", area, "LEFT")
    track:SetPoint("RIGHT", area, "RIGHT")
    track:SetHeight(14)
    Edges(bar, track)
    local fill = Tex(bar, "BORDER", 0, { UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.85 })
    fill:SetPoint("TOPLEFT", track, "TOPLEFT")
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
    local function SetFill(_, percent)
        local p = math.min(1, math.max(0, tonumber(percent) or 0))
        local w = area:GetWidth() or 0
        fill:SetShown(p > 0 and w > 0)
        fill:SetWidth(math.max(1, p * w))
    end
    if bar.SetFillPercent then hooksecurefunc(bar, "SetFillPercent", SetFill) end
    if bar.Text then
        ns.SetFont(bar.Text, 11, "OUTLINE")
        bar.Text:SetTextColor(unpack(UI.TEXT))
    end
end

-- Layout ----------------------------------------------------------------------------------------------

-- Slot row; Blizzard re-sets the "TOP" point of the current pet slot in Update, so we use that point too
local function PlaceSlots()
    local f = frame
    local current, stabled1, stabled2 = G.PetStableCurrentPet, G.PetStableStabledPet1, G.PetStableStabledPet2
    local top = -(ns.NPC_HEIGHT - SLOT_BOTTOM - SLOT)
    if current then
        current:ClearAllPoints()
        current:SetPoint("TOP", f, "TOPLEFT", PAD + SLOT / 2, top)
        current:SetSize(SLOT, SLOT)
    end
    if stabled1 then
        stabled1:ClearAllPoints()
        stabled1:SetPoint("TOP", f, "TOPLEFT", STABLED_X + SLOT / 2, top)
        stabled1:SetSize(SLOT, SLOT)
    end
    if stabled2 then
        stabled2:ClearAllPoints()
        stabled2:SetPoint("LEFT", stabled1 or f, stabled1 and "RIGHT" or "LEFT", 8, 0)
        stabled2:SetSize(SLOT, SLOT)
    end
    for _, slot in ipairs({ current, stabled1 }) do
        if slot and slot.Text then
            slot.Text:ClearAllPoints()
            slot.Text:SetPoint("BOTTOMLEFT", slot, "TOPLEFT", 0, 6)
        end
    end
end

local function Place()
    local f = frame
    f:SetSize(WIDTH, ns.NPC_HEIGHT)
    f:SetHitRectInsets(0, 0, 0, 0) -- Blizzard lets clicks through its bottom 75 px

    -- Pet info: happiness, name/level/family, loyalty; player money on the right
    local diet = f.diet
    if diet then
        diet:ClearAllPoints()
        diet:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(TOOLBAR_TOP + 6))
    end
    local money = G.PetStableMoneyFrame
    if money then
        money:ClearAllPoints()
        money:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD + 12, -(TOOLBAR_TOP + 4))
    end
    local level, loyalty = G.PetStableLevelText, G.PetStableLoyaltyText
    if level then
        level:ClearAllPoints()
        level:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 34, -(TOOLBAR_TOP + 2))
        level:SetPoint("RIGHT", f, "RIGHT", -(PAD + 150), 0)
        level:SetJustifyH("LEFT")
    end
    if loyalty then
        loyalty:ClearAllPoints()
        loyalty:SetPoint("TOPLEFT", level or f, level and "BOTTOMLEFT" or "TOPLEFT", 0, -4)
        loyalty:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
        loyalty:SetJustifyH("LEFT")
    end

    local scene = f.modelScene
    if scene then
        scene:ClearAllPoints()
        scene:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -SCENE_TOP)
        scene:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, SCENE_BOTTOM)
    end
    local bar = f.expBar
    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOM", scene or f, "BOTTOM", 0, 8)
        bar:SetWidth(WIDTH - 2 * PAD - 60)
    end

    PlaceSlots()

    local slotText = G.PetStableSlotText
    if slotText then
        slotText:ClearAllPoints()
        slotText:SetPoint("RIGHT", f, "BOTTOMRIGHT", -PAD, SLOT_BOTTOM + SLOT / 2)
        slotText:SetJustifyH("RIGHT")
    end

    -- Footer: cost left, purchase right (cost money stays anchored to its label, as Blizzard does)
    local purchase = f.purchaseButton
    if purchase then
        purchase:ClearAllPoints()
        purchase:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 14)
        purchase:SetSize(150, 28)
    end
    local costLabel = G.PetStableCostLabel
    if costLabel then
        costLabel:ClearAllPoints()
        costLabel:SetPoint("LEFT", f, "BOTTOMLEFT", PAD, 28)
    end
    local cost = G.PetStableCostMoneyFrame
    if cost and costLabel then
        cost:ClearAllPoints()
        cost:SetPoint("LEFT", costLabel, "RIGHT", 4, 0)
    end

    local close = f.CloseButton
    if close then
        close:SetSize(34, 34)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -(PAD - 4), -(PAD - 4))
    end
end

local function UpdateHeader()
    if not portrait then return end
    local unit = UnitExists("npc") and "npc" or "player"
    SetPortraitTexture(portrait, unit)
    local name = UnitName(unit)
    if issecretvalue and issecretvalue(name) then name = "" end
    subtitle:SetText(name or "")
end

local function Reposition(opening)
    if frame:IsShown() and ns.ResetWindowPosition then
        ns.ResetWindowPosition(frame, "stable", opening and not InCombatLockdown())
    end
end

local function SkinShell(f)
    local UI = ns.UI
    FadeRegions(f) -- header/footer strips, inner frame
    Fade(f.NineSlice)
    Fade(f.Bg)
    Fade(f.PortraitContainer)
    Fade(f.TitleContainer)
    Fade(f.TopTileStreaks)
    if f.BottomDividerFrame then Fade(f.BottomDividerFrame.horzDivider) end
    if f.TopDividerFrame then Fade(f.TopDividerFrame.horzDivider) end
    Panel(f)

    -- Header like mUI windows
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    portrait = holder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", 1, -1)
    portrait:SetPoint("BOTTOMRIGHT", -1, 1)
    portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    local title = UI.Text(holder, 16, "LEFT")
    ns.SetFont(title, 16, "", "bold")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    title:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
    title:SetText(G.STABLES or "")
    subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetPoint("RIGHT", title, "RIGHT")
    subtitle:SetWordWrap(false)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -PAD - 36, 0)
    header:SetHeight(PAD + ICON + 6)
    ns.MakeWindowDraggable(f, header)

    SkinIconButton(f.CloseButton, "Close", 18)

    -- Pet info
    local level, loyalty = G.PetStableLevelText, G.PetStableLoyaltyText
    if level then ns.SetFont(level, 15, "", "bold") level:SetTextColor(unpack(UI.TEXT)) level:SetWordWrap(false) end
    if loyalty then ns.SetFont(loyalty, 12) loyalty:SetTextColor(unpack(UI.MUTED)) end
    local money = G.PetStableMoneyFrame
    if money and money.Border then FadeRegions(money.Border) end

    -- Model: Blizzard's scene and spec background stay; inset art and corner shadow go
    local scene = f.modelScene
    if scene then
        if scene.Inset then FadeRegions(scene.Inset) Fade(scene.Inset.NineSlice) Fade(scene.Inset.Bg) end
        if scene.PetModelSceneShadow then FadeRegions(scene.PetModelSceneShadow) end
        Edges(f, scene)
        SkinSceneControls(scene.ControlFrame)
    end
    SkinExpBar(f.expBar)

    SkinSlot(G.PetStableCurrentPet)
    SkinSlot(G.PetStableStabledPet1)
    SkinSlot(G.PetStableStabledPet2)

    local slotText = G.PetStableSlotText
    if slotText then ns.SetFont(slotText, 12) slotText:SetTextColor(unpack(UI.MUTED)) end
    local costLabel = G.PetStableCostLabel
    if costLabel then ns.SetFont(costLabel, 12) costLabel:SetTextColor(unpack(UI.MUTED)) end
    SkinButton(f.purchaseButton)
end

local function Unmanage()
    if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
    if G.SetUIPanelAttribute then G.SetUIPanelAttribute(frame, "area", nil) end
    for _, name in ipairs(UISpecialFrames) do
        if name == "PetStableFrame" then return end
    end
    tinsert(UISpecialFrames, "PetStableFrame") -- Esc still closes (OnHide ends the interaction)
end

local function Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local function Apply()
    if applied or not Enabled() or type(G.PetStableFrame) ~= "table" then return end
    applied = true
    frame = G.PetStableFrame
    Try(SkinShell, frame)
    Unmanage()
    Try(Place)

    if frame.Update then
        hooksecurefunc(frame, "Update", function()
            PlaceSlots()
            UpdateSlots()
        end)
    end
    if frame.SelectPet then hooksecurefunc(frame, "SelectPet", UpdateSlots) end
    frame:HookScript("OnShow", function()
        Place()
        UpdateHeader()
        UpdateSlots()
        C_Timer.After(0, function() Reposition(true) end)
    end)
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_StableUI" then Apply() end
end)

ns:On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_StableUI") then Apply() end
end)
