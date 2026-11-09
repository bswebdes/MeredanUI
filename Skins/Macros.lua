-- Macro window (MacroFrame, Blizzard_MacroUI) in mUI style. Blizzard's frame does all the work
-- (create, edit, save, pick up - partly protected), we only restyle and re-place it. Blizzard's
-- cramped 338 px layout becomes two columns with a large edit area:
--
--   +-[i] Macros ------------------------------------------------------- [x]-+
--   |     General Macros                                                      |
--   | [General] [Character]                                                   |
--   | +-------------------------+  [icon] Macro name                          |
--   | | macro grid (6 columns)  |         [Change Name/Icon]                  |
--   | |                         |  Enter macro commands:            123/255   |
--   | |                         |  +--------------------------------------+   |
--   | |                         |  | /cast ...                            |   |
--   | +-------------------------+  +--------------------------------------+   |
--   | [Delete] [New]                                     [Cancel] [Save]      |
--   +-------------------------------------------------------------------------+
--
-- Rules as in Skins/Communities.lua: art only via SetAlpha(0) or recolor, no SetScript, no SetText on
-- Blizzard's edit boxes, no ScrollBox view changes (stride/padding stay Blizzard's). Blizzard sets
-- OnEnter/OnLeave on Edit/Delete/New on every update, so hover looks use HIGHLIGHT textures only.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = { 0, 0, 0, 1 }
local INPUT = { 0.04, 0.04, 0.05, 1 }
local BOX = { 0, 0, 0, 0.25 }
local PAD, ICON = 18, 46
local WIDTH = 740
local TOOLBAR_TOP = PAD + ICON + 14  -- 78
local CONTENT_TOP = TOOLBAR_TOP + 28 + 12 -- 118
local FOOTER = 54
local GRID_W = 319                    -- Blizzard's selector width (6 columns + scrollbar)
local RIGHT_X = PAD + GRID_W + 16     -- right column
local TEXT_TOP = CONTENT_TOP + ICON + 32

local skinned = setmetatable({}, { __mode = "k" })
local own = setmetatable({}, { __mode = "k" })
local selectedEdges = setmetatable({}, { __mode = "k" })
local frame, subtitle
local fonts
local applied = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.macroSkin ~= false
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
    Edges(target, target)
    local accent = Tex(target, "OVERLAY", 7, ns.UI.ACCENT)
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
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
        normal = Make("MeredanUIMacroButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIMacroButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUIMacroButtonDisabled", GameFontDisable, UI.MUTED),
        tab = Make("MeredanUIMacroTab", GameFontHighlight, UI.MUTED),
        tabActive = Make("MeredanUIMacroTabActive", GameFontHighlight, UI.ACCENT),
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

-- flat button (UIPanelButtonTemplate); hover via HIGHLIGHT layer (no scripts, see header)
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

local function SkinDropdown(dropdown)
    if type(dropdown) ~= "table" or not dropdown.GetRegions or not Once(dropdown) then return end
    local UI = ns.UI
    Fade(dropdown.Background)
    Fade(dropdown.Arrow)
    local bg = Tex(dropdown, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Edges(dropdown, bg)
    local arrow = UI.Icon(dropdown, "ChevronDown", 10, UI.MUTED)
    own[arrow] = true
    arrow:SetPoint("RIGHT", -8, 0)
    local hover = Tex(dropdown, "HIGHLIGHT", 0, { 1, 1, 1, 0.05 })
    hover:SetAllPoints(bg)
end

local function SkinScrollBar(bar)
    if type(bar) ~= "table" or not bar.Track or not Once(bar) then return end
    local UI = ns.UI
    Fade(bar.Background)
    local track = bar.Track
    FadeRegions(track)
    local line = Tex(track, "BACKGROUND", 0, { 1, 1, 1, 0.06 })
    line:SetPoint("TOP")
    line:SetPoint("BOTTOM")
    line:SetWidth(3)
    local thumb = track.Thumb or (bar.GetThumb and bar:GetThumb())
    if type(thumb) == "table" and thumb.GetRegions then
        FadeRegions(thumb)
        local grip = Tex(thumb, "OVERLAY", 0, { UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 1 })
        grip:SetPoint("TOP")
        grip:SetPoint("BOTTOM")
        grip:SetWidth(3)
        grip:SetAlpha(0.8)
        thumb:HookScript("OnEnter", function() grip:SetWidth(5) grip:SetAlpha(1) end)
        thumb:HookScript("OnLeave", function() grip:SetWidth(3) grip:SetAlpha(0.8) end)
    end
    for key, rotation in pairs({ Back = math.pi, Forward = 0 }) do
        local stepper = bar[key]
        if type(stepper) == "table" and stepper.GetRegions then
            FadeRegions(stepper)
            Fade(stepper.Texture)
            local icon = UI.Icon(stepper, "ChevronDown", 12, UI.MUTED)
            own[icon] = true
            icon:SetPoint("CENTER")
            icon:SetRotation(rotation)
            stepper:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
            stepper:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.MUTED)) end)
        end
    end
end

local function HookScrollBox(box, fn)
    if type(box) ~= "table" or not box.ForEachFrame or not Once(box) then return end
    local function Each() box:ForEachFrame(fn) end
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
end

-- Name edit box in the icon popup: dark field, Surf Green border on focus
local function SkinEditBox(box, regions)
    if type(box) ~= "table" or not box.IsObjectType or not box:IsObjectType("EditBox") or not Once(box) then return end
    local UI = ns.UI
    for _, key in ipairs(regions) do Fade(box[key]) end
    local bg = Tex(box, "BACKGROUND", -8, INPUT)
    bg:SetPoint("TOPLEFT", -6, 4)
    bg:SetPoint("BOTTOMRIGHT", 2, -4)
    local IDLE = UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 }
    local edges = Edges(box, bg, IDLE)
    box:HookScript("OnEditFocusGained", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    box:HookScript("OnEditFocusLost", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1) end
    end)
end

-- Macro / icon slot (SelectorButtonTemplate): dark slot, cropped icon, Surf Green border when selected
local function UpdateSlot(button)
    local edges = selectedEdges[button]
    if not edges then return end
    local on = button.SelectedTexture and button.SelectedTexture:IsShown() and true or false
    for _, edge in ipairs(edges) do edge:SetShown(on) end
    Fade(button.SelectedTexture)
end

local function SkinSlot(button)
    if type(button) ~= "table" or not button.Icon or not Once(button) then return end
    local UI = ns.UI
    FadeRegions(button, { [button.Icon] = true })
    Fade(button.Highlight)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Border(button)
    button.Icon:ClearAllPoints()
    button.Icon:SetPoint("TOPLEFT", 1, -1)
    button.Icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hover = Tex(button, "HIGHLIGHT", 0, { 1, 1, 1, 0.12 })
    hover:SetAllPoints()
    local edges = Border(button, true, 2)
    for _, edge in ipairs(edges) do
        edge:SetVertexColor(unpack(UI.ACCENT))
        edge:SetDrawLayer("OVERLAY", 7)
    end
    selectedEdges[button] = edges
    if button.UpdateSelectedTexture then hooksecurefunc(button, "UpdateSelectedTexture", UpdateSlot) end
    if button.SelectedTexture then
        hooksecurefunc(button.SelectedTexture, "SetShown", function() UpdateSlot(button) end)
    end
    UpdateSlot(button)
end

-- Tabs (General / Character): flat buttons in the toolbar; active one Surf Green.
-- Blizzard disables the selected tab (and both while the icon popup is open).
local tabParts = setmetatable({}, { __mode = "k" })
local function SkinTab(tab)
    if type(tab) ~= "table" or not Once(tab) then return end
    local UI = ns.UI
    FadeRegions(tab)
    local bg = Tex(tab, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    local hover = Tex(tab, "HIGHLIGHT", 0, { 1, 1, 1, 0.05 })
    hover:SetAllPoints()
    Border(tab)
    local active = Border(tab, true, 2)
    for _, edge in ipairs(active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    tabParts[tab] = active
end

local function UpdateTabs()
    if not frame then return end
    local selected = PanelTemplates_GetSelectedTab(frame)
    local f = Fonts()
    for i, tab in ipairs({ _G.MacroFrameTab1, _G.MacroFrameTab2 }) do
        local edges = tabParts[tab]
        if edges then
            local on = selected == i
            for _, edge in ipairs(edges) do edge:SetShown(on) end
            FadeRegions(tab)
            local font = on and f.tabActive or f.tab
            tab:SetNormalFontObject(font)
            tab:SetDisabledFontObject(font)
            tab:SetHighlightFontObject(f.tabActive)
            if tab.Text then
                tab.Text:ClearAllPoints()
                tab.Text:SetPoint("LEFT", 10, 0)
                tab.Text:SetPoint("RIGHT", -10, 0)
            end
            tab:SetSize(160, 28)
        end
    end
    if subtitle then
        subtitle:SetText(selected == 2 and (CHARACTER_SPECIFIC_MACROS or "%s"):format(UnitName("player") or "")
            or GENERAL_MACROS or "")
    end
end

-- Layout ----------------------------------------------------------------------------------------------

local function Place()
    local f = frame
    f:SetSize(WIDTH, ns.NPC_HEIGHT)

    local tab1, tab2 = _G.MacroFrameTab1, _G.MacroFrameTab2
    if tab1 then
        tab1:ClearAllPoints()
        tab1:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -TOOLBAR_TOP)
    end
    if tab2 then
        tab2:ClearAllPoints()
        tab2:SetPoint("LEFT", tab1 or f, tab1 and "RIGHT" or "LEFT", 6, 0)
    end

    local selector = f.MacroSelector
    if selector then
        selector:ClearAllPoints()
        selector:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -CONTENT_TOP)
        selector:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, FOOTER)
        selector:SetWidth(GRID_W)
    end

    -- Selected macro: icon, name, change button
    local background = _G.MacroFrameSelectedMacroBackground
    if background then
        background:ClearAllPoints()
        background:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X, -CONTENT_TOP)
        background:SetSize(ICON, ICON)
    end
    local selected = f.SelectedMacroButton
    if selected then
        selected:ClearAllPoints()
        selected:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X, -CONTENT_TOP)
        selected:SetSize(ICON, ICON)
    end
    local name = _G.MacroFrameSelectedMacroName
    if name then
        name:ClearAllPoints()
        name:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X + ICON + 12, -(CONTENT_TOP + 2))
        name:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    end
    local edit = _G.MacroEditButton
    if edit then
        edit:ClearAllPoints()
        edit:SetPoint("BOTTOMLEFT", f, "TOPLEFT", RIGHT_X + ICON + 12, -(CONTENT_TOP + ICON))
        edit:SetSize(200, 24)
    end

    -- Edit area: label + count above, large text box below
    local label = _G.MacroFrameEnterMacroText
    if label then
        label:ClearAllPoints()
        label:SetPoint("BOTTOMLEFT", f, "TOPLEFT", RIGHT_X, -(TEXT_TOP - 6))
    end
    local count = _G.MacroFrameCharLimitText
    if count then
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -PAD, -(TEXT_TOP - 6))
    end
    local box = _G.MacroFrameTextBackground
    if box then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X, -TEXT_TOP)
        box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOTER)
    end
    local scroll, text, textButton = _G.MacroFrameScrollFrame, _G.MacroFrameText, _G.MacroFrameTextButton
    local textW = WIDTH - PAD - RIGHT_X - 8 - 26
    local textH = ns.NPC_HEIGHT - TEXT_TOP - FOOTER - 16
    if scroll then
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", RIGHT_X + 8, -(TEXT_TOP + 8))
        scroll:SetSize(textW, textH)
    end
    if text then text:SetWidth(textW) end
    if textButton then textButton:SetSize(textW, textH) end

    -- Footer: delete / new left, cancel / save right; Exit is the close button
    local function Foot(button, point, x)
        if not button then return end
        button:ClearAllPoints()
        button:SetPoint(point, f, point, x, 14)
        button:SetSize(120, 28)
    end
    Foot(_G.MacroDeleteButton, "BOTTOMLEFT", PAD)
    Foot(_G.MacroNewButton, "BOTTOMLEFT", PAD + 126)
    Foot(_G.MacroSaveButton, "BOTTOMRIGHT", -PAD)
    Foot(_G.MacroCancelButton, "BOTTOMRIGHT", -(PAD + 126))
    if _G.MacroExitButton then _G.MacroExitButton:Hide() end

    local popup = _G.MacroPopupFrame
    if popup then
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, 0)
    end
end

local function Reposition(opening)
    if frame:IsShown() and ns.ResetWindowPosition then
        ns.ResetWindowPosition(frame, "macros", opening and not InCombatLockdown())
    end
end

-- Icon popup (name + icon choice): flat panel like mUI windows
local function SkinPopup(popup)
    if type(popup) ~= "table" or not Once(popup) then return end
    Fade(popup.BG)
    local border = popup.BorderBox
    if border then
        FadeRegions(border)
        Fade(border.NineSlice)
        SkinButton(border.OkayButton)
        SkinButton(border.CancelButton)
        SkinDropdown(border.IconTypeDropdown)
        SkinEditBox(border.IconSelectorEditBox,
            { "IconSelectorPopupNameLeft", "IconSelectorPopupNameMiddle", "IconSelectorPopupNameRight" })
        local area = border.SelectedIconArea
        if area and area.SelectedIconButton then SkinSlot(area.SelectedIconButton) end
    end
    Panel(popup)
    local selector = popup.IconSelector
    if selector then
        SkinScrollBar(selector.ScrollBar)
        HookScrollBox(selector.ScrollBox, SkinSlot)
    end
end

local function SkinShell(f)
    local UI = ns.UI
    FadeRegions(f)
    Fade(f.NineSlice)
    Fade(f.Inset)
    Fade(f.PortraitContainer)
    Fade(f.TitleContainer)
    Fade(f.TopTileStreaks)
    if _G.MacroFramePortrait then _G.MacroFramePortrait:SetAlpha(0) end
    if f.Inset then Fade(f.Inset.Bg) Fade(f.Inset.NineSlice) end
    Panel(f)

    -- Header like mUI windows
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    local portrait = holder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", 1, -1)
    portrait:SetPoint("BOTTOMRIGHT", -1, 1)
    portrait:SetTexture("Interface\\MacroFrame\\MacroFrame-Icon")
    portrait:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    local title = UI.Text(holder, 16, "LEFT")
    ns.SetFont(title, 16, "", "bold")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    title:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
    title:SetText(MACROS or CREATE_MACROS or "")
    subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetPoint("RIGHT", title, "RIGHT")
    subtitle:SetWordWrap(false)

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -PAD - 36, 0)
    header:SetHeight(PAD + ICON + 6)
    ns.MakeWindowDraggable(f, header)

    local close = f.CloseButton or _G.MacroFrameCloseButton
    if close then
        SkinIconButton(close, "Close", 18)
        close:SetSize(34, 34)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -(PAD - 4), -(PAD - 4))
    end

    SkinTab(_G.MacroFrameTab1)
    SkinTab(_G.MacroFrameTab2)

    -- Macro grid in a dark box
    local selector = f.MacroSelector
    if selector then
        local box = Tex(f, "BACKGROUND", -7, BOX)
        box:SetAllPoints(selector)
        Edges(f, box)
        SkinScrollBar(selector.ScrollBar)
        HookScrollBox(selector.ScrollBox, SkinSlot)
    end

    -- Selected macro: dark slot (Blizzard's empty-slot art hidden)
    Fade(_G.MacroFrameSelectedMacroBackground)
    if f.SelectedMacroButton then SkinSlot(f.SelectedMacroButton) end
    local name = _G.MacroFrameSelectedMacroName
    if name then ns.SetFont(name, 15, "", "bold") name:SetTextColor(unpack(UI.TEXT)) end
    local label = _G.MacroFrameEnterMacroText
    if label then label:SetTextColor(unpack(UI.MUTED)) end
    local count = _G.MacroFrameCharLimitText
    if count then count:SetTextColor(unpack(UI.MUTED)) end

    -- Text area: dark field, light border, larger font
    local box = _G.MacroFrameTextBackground
    if box then
        Fade(box.NineSlice)
        FadeRegions(box)
        local bg = Tex(box, "BACKGROUND", -8, INPUT)
        bg:SetAllPoints()
        local IDLE = UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 }
        local edges = Edges(box, bg, IDLE)
        local text = _G.MacroFrameText
        if text then
            text:SetFont(ns.STYLE.font, ns.FontPx(13), "")
            text:SetTextColor(unpack(UI.TEXT))
            text:HookScript("OnEditFocusGained", function()
                for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
            end)
            text:HookScript("OnEditFocusLost", function()
                for _, edge in ipairs(edges) do edge:SetVertexColor(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1) end
            end)
        end
    end
    local scroll = _G.MacroFrameScrollFrame
    if scroll then SkinScrollBar(scroll.ScrollBar) end

    for _, button in ipairs({ _G.MacroEditButton, _G.MacroDeleteButton, _G.MacroNewButton,
        _G.MacroSaveButton, _G.MacroCancelButton }) do
        SkinButton(button)
    end

    SkinPopup(_G.MacroPopupFrame)
end

local function Unmanage()
    if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
    if SetUIPanelAttribute then SetUIPanelAttribute(frame, "area", nil) end
    for _, name in ipairs(UISpecialFrames) do
        if name == "MacroFrame" then return end
    end
    tinsert(UISpecialFrames, "MacroFrame") -- Esc still closes
end

local function Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local function Apply()
    if applied or not Enabled() or type(_G.MacroFrame) ~= "table" then return end
    applied = true
    frame = _G.MacroFrame
    Try(SkinShell, frame)
    Unmanage()
    Try(Place)
    Try(UpdateTabs)

    -- The icon popup hangs on the right: neighboring windows move behind it
    if ns.EXTRA_RIGHT then
        ns.EXTRA_RIGHT[frame] = function()
            local popup = _G.MacroPopupFrame
            return popup and popup:IsShown() and (popup:GetWidth() + 8) or 0
        end
    end

    hooksecurefunc("PanelTemplates_UpdateTabs", function(owner) if owner == frame then UpdateTabs() end end)
    if frame.ChangeTab then hooksecurefunc(frame, "ChangeTab", UpdateTabs) end
    local popup = _G.MacroPopupFrame
    if popup then
        -- Blizzard re-sizes its UI panel slot when the popup opens; keep our spot and re-place neighbors
        popup:HookScript("OnShow", function() C_Timer.After(0, function() Place() Reposition() end) end)
        popup:HookScript("OnHide", function() C_Timer.After(0, function() Reposition() end) end)
    end
    frame:HookScript("OnShow", function()
        Place()
        UpdateTabs()
        C_Timer.After(0, function() Reposition(true) end)
    end)
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_MacroUI" then Apply() end
end)

ns:On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_MacroUI") then Apply() end
end)
