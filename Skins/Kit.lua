-- Skin kit: the rune look's building blocks (Config/Widgets.lua) applied to Blizzard's own widgets,
-- shared by all window skins so they match mUI's own windows (bevel buttons, tabs, grooves, item
-- frames, bronze scrollbars).
-- Taint rules as in every skin: art only faded (SetAlpha) or added on top, no SetScript on Blizzard
-- frames. Blizzard re-sets OnEnter/OnLeave on many buttons (game menu, macro buttons) every update,
-- which wipes hooked scripts - hover states therefore come from one watcher of our own that polls
-- the registered widgets while they are visible.
local _, ns = ...

local Kit = {}
ns.SkinKit = Kit

local WHITE = "Interface\\Buttons\\WHITE8X8"
local done = setmetatable({}, { __mode = "k" })

local function Once(object, key)
    if type(object) ~= "table" then return false end
    if object.IsForbidden and object:IsForbidden() then return false end
    done[object] = done[object] or {}
    if done[object][key] then return false end
    done[object][key] = true
    return true
end

-- Regions the kit adds get region.muiKit = true, so a skin's own "fade all textures" helpers leave
-- them alone (they skip region.muiKit). Diff of the frame's regions before/after the build.
local function Track(frame, fn, ...)
    local before = {}
    for _, r in ipairs({ frame:GetRegions() }) do before[r] = true end
    local result = fn(...)
    for _, r in ipairs({ frame:GetRegions() }) do
        if not before[r] then r.muiKit = true end
    end
    return result
end
Kit.Track = Track

local function Fade(region)
    if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
end
Kit.Fade = Fade

local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
    "GetCheckedTexture", "GetDisabledCheckedTexture" }
function Kit.FadeButtonArt(button)
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator", "Center" }) do Fade(button[key]) end
    for _, getter in ipairs(BUTTON_TEXTURES) do
        local fn = button[getter]
        local tex = fn and fn(button)
        if tex then Fade(tex) end
    end
    local name = button.GetName and button:GetName()
    if name then Fade(_G[name .. "Border"]) end -- UI-Button-Borders art behind some footer buttons
end

-- Hover watcher ------------------------------------------------------------------------------------
local watched = {} -- widget -> { fn, hover }
local watcher = CreateFrame("Frame")
local elapsedSince = 0
watcher:Hide()
watcher:SetScript("OnUpdate", function(self, elapsed)
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.03 then return end
    elapsedSince = 0
    local any = false
    for widget, entry in pairs(watched) do
        if widget:IsVisible() then
            any = true
            local hover = widget:IsMouseOver() and (not widget.IsEnabled or widget:IsEnabled()) or false
            if entry.hover ~= hover then
                entry.hover = hover
                entry.fn(widget, hover)
            end
        elseif entry.hover then
            entry.hover = false
            entry.fn(widget, false)
        end
    end
    if not any then self:Hide() end
end)

-- fn(widget, hover) runs whenever the mouse enters or leaves the widget (also on hide)
function Kit.WatchHover(widget, fn)
    watched[widget] = { fn = fn, hover = false }
    fn(widget, false)
    widget:HookScript("OnShow", function() watcher:Show() end)
    if widget:IsVisible() then watcher:Show() end
end

-- Fonts --------------------------------------------------------------------------------------------
local fonts
function Kit.Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, base, color)
        local font = CreateFont(name)
        font:CopyFontObject(base)
        font:SetTextColor(color[1], color[2], color[3])
        return font
    end
    fonts = {
        normal = Make("MeredanUIKitButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIKitButtonHighlight", GameFontHighlight, { 1, 0.95, 0.84 }),
        disabled = Make("MeredanUIKitButtonDisabled", GameFontDisable, UI.MUTED),
        tab = Make("MeredanUIKitTab", GameFontHighlight, { 0.522, 0.478, 0.4 }),
        tabActive = Make("MeredanUIKitTabActive", GameFontHighlight, { 0.953, 0.902, 0.769 }),
    }
    return fonts
end

-- Button (B9 bevel) --------------------------------------------------------------------------------
function Kit.Button(button)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button, "button") then return end
    Kit.FadeButtonArt(button)
    Track(button, ns.UI.Bevel, button)
    Kit.WatchHover(button, function(self, hover)
        if self.muiBevel then self.muiBevel(hover and "hover" or "normal") end
    end)
    if button.GetFontString and button:GetFontString() then
        local f = Kit.Fonts()
        button:SetNormalFontObject(f.normal)
        button:SetHighlightFontObject(f.highlight)
        button:SetDisabledFontObject(f.disabled)
    end
end

-- Close / icon button: flat icon without a box, accent on hover (like UI.IconButton)
function Kit.IconButton(button, iconName, size)
    if type(button) ~= "table" or not Once(button, "icon") then return end
    local UI = ns.UI
    Kit.FadeButtonArt(button)
    if button.GetRegions then
        for _, region in ipairs({ button:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
    end
    local icon = UI.Icon(button, iconName, size or 22)
    icon.muiKit = true
    icon:SetPoint("CENTER")
    Kit.WatchHover(button, function(_, hover) icon:SetVertexColor(unpack(hover and UI.ACCENT or UI.TEXT)) end)
    return icon
end

-- Field (B11 groove) with an accent outline while focused --------------------------------------
-- target: the frame that gets the groove; focus: the EditBox whose focus lights it (optional)
function Kit.Field(target, focus)
    if type(target) ~= "table" or not Once(target, "field") then return end
    local UI = ns.UI
    local fill = Track(target, UI.Groove, target)
    if not focus then return fill end
    local edges = {}
    for i, e in ipairs(ns.AddBorder(target, true)) do
        e.muiKit = true
        e:SetVertexColor(unpack(UI.ACCENT))
        e:Hide()
        edges[i] = e
    end
    focus:HookScript("OnEditFocusGained", function() for _, e in ipairs(edges) do e:Show() end end)
    focus:HookScript("OnEditFocusLost", function() for _, e in ipairs(edges) do e:Hide() end end)
    return fill
end

-- Groove drawn on an EditBox itself (so it stays behind the text), around anchor points of the
-- caller's choice: TOPLEFT at (l, t), BOTTOMRIGHT at (r, b) relative to the box, or around the
-- regions `from`/`to`. Accent outline while the box has focus.
function Kit.EditField(box, l, t, r, b, from, to)
    if type(box) ~= "table" or not box.IsObjectType or not box:IsObjectType("EditBox") then return end
    if not Once(box, "edit") then return end
    local UI = ns.UI
    local px = ns.PixelSize()
    local m = ns.Material()
    for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do Fade(box[key]) end
    Fade(box.NineSlice)
    local function Anchor(tex)
        if from and to then
            tex:SetPoint("TOPLEFT", from, "TOPLEFT")
            tex:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT")
        else
            tex:SetPoint("TOPLEFT", box, "TOPLEFT", l or 0, t or 0)
            tex:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", r or 0, b or 0)
        end
    end
    local function New(layer, sub)
        local tex = box:CreateTexture(nil, layer, nil, sub)
        tex:SetTexture(WHITE)
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        tex.muiKit = true
        return tex
    end
    -- an invisible frame-less rect: one texture carries the area, the edges hang on it
    local area = New("BACKGROUND", -8)
    Anchor(area)
    area:SetVertexColor(unpack(UI.FIELD))
    local shade = New("BACKGROUND", -7)
    shade:SetPoint("TOPLEFT", area)
    shade:SetPoint("TOPRIGHT", area)
    shade:SetHeight(ns.Snap(4))
    shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.7))
    local top, bottom, left, right = New("BORDER", -8), New("BORDER", -8), New("BORDER", -8), New("BORDER", -8)
    top:SetPoint("TOPLEFT", area) top:SetPoint("TOPRIGHT", area) top:SetHeight(px)
    bottom:SetPoint("BOTTOMLEFT", area) bottom:SetPoint("BOTTOMRIGHT", area) bottom:SetHeight(px)
    left:SetPoint("TOPLEFT", area) left:SetPoint("BOTTOMLEFT", area) left:SetWidth(px)
    right:SetPoint("TOPRIGHT", area) right:SetPoint("BOTTOMRIGHT", area) right:SetWidth(px)
    top:SetVertexColor(0, 0, 0, 1)
    left:SetVertexColor(0, 0, 0, 1)
    bottom:SetVertexColor(m.item[1], m.item[2], m.item[3], 0.85)
    right:SetGradient("VERTICAL", CreateColor(m.item[1], m.item[2], m.item[3], 0.85), CreateColor(0, 0, 0, 1))
    local focus = {}
    for i, spec in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local e = New("BORDER", -7)
        e:SetPoint(spec[1], area)
        e:SetPoint(spec[2], area)
        if spec[3] then e:SetHeight(px) else e:SetWidth(px) end
        e:SetVertexColor(unpack(UI.ACCENT))
        e:Hide()
        focus[i] = e
    end
    box:HookScript("OnEditFocusGained", function() for _, e in ipairs(focus) do e:Show() end end)
    box:HookScript("OnEditFocusLost", function() for _, e in ipairs(focus) do e:Hide() end end)
    return area
end

-- Content area set into the window (lists, grids)
function Kit.Inset(target, color)
    if type(target) ~= "table" or not Once(target, "inset") then return end
    return Track(target, ns.UI.Inset, target, color)
end

-- Item / icon slot (SelectorButtonTemplate and alike): item frame, icon inset, accent when selected.
-- isSelected(button) -> bool is polled by the caller via Kit.UpdateSlot.
function Kit.Slot(button, icon)
    if type(button) ~= "table" or not Once(button, "slot") then return end
    local UI = ns.UI
    Track(button, ns.AddSlotBackground, button)
    Track(button, ns.AddItemFrame, button, nil, 2)
    if icon then
        ns.InsetItemIcon(button, icon, nil, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover.muiKit = true
    hover:SetColorTexture(1, 1, 1, 0.1)
    if icon then hover:SetAllPoints(icon) else hover:SetAllPoints() end
    local selected = ns.AddBorder(button, true, 2)
    for _, e in ipairs(selected) do
        e.muiKit = true
        e:SetVertexColor(unpack(UI.ACCENT))
        e:SetDrawLayer("OVERLAY", 7)
        e:Hide()
    end
    button.muiSelectedEdges = selected
end

function Kit.SetSlotSelected(button, on)
    for _, e in ipairs(button.muiSelectedEdges or {}) do e:SetShown(on and true or false) end
end

-- Tab (B10) on a Blizzard tab button: box open at the bottom, gem + bright text when active ------
function Kit.Tab(tab)
    if type(tab) ~= "table" or not Once(tab, "tab") then return end
    local px = ns.PixelSize()
    local m = ns.Material()
    Kit.FadeButtonArt(tab)
    if tab.GetRegions then
        for _, region in ipairs({ tab:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
    end
    local before = {}
    for _, r in ipairs({ tab:GetRegions() }) do before[r] = true end
    local fill = tab:CreateTexture(nil, "BACKGROUND", nil, 2)
    fill:SetTexture(WHITE)
    fill:SetPoint("TOPLEFT", px, -px)
    fill:SetPoint("BOTTOMRIGHT", -px, 0)
    local top = tab:CreateTexture(nil, "BORDER", nil, 2)
    top:SetTexture(WHITE)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(px)
    top:SetVertexColor(unpack(m.item))
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local e = tab:CreateTexture(nil, "BORDER", nil, 2)
        e:SetTexture(WHITE)
        e:SetPoint("TOP" .. side)
        e:SetPoint("BOTTOM" .. side)
        e:SetWidth(px)
        e:SetGradient("VERTICAL", CreateColor(unpack(m.dark)), CreateColor(unpack(m.item)))
    end
    local gem = ns.UI.Diamond(tab, 5)
    gem:SetPoint("LEFT", 12, 0)
    tab.muiTabFill, tab.muiTabGem = fill, gem
    for _, r in ipairs({ tab:GetRegions() }) do
        if not before[r] then r.muiKit = true end
    end
    Kit.SetTabActive(tab, false)
end

local TAB_FILL = {
    on = { { 0.227, 0.18, 0.125 }, { 0.11, 0.086, 0.063 } },
    off = { { 0.133, 0.102, 0.071 }, { 0.082, 0.067, 0.047 } },
}
function Kit.SetTabActive(tab, on)
    local fill = tab.muiTabFill
    if not fill then return end
    tab.muiTabActive = on and true or false
    local c = TAB_FILL[on and "on" or "off"]
    fill:SetGradient("VERTICAL", CreateColor(c[2][1], c[2][2], c[2][3], 1), CreateColor(c[1][1], c[1][2], c[1][3], 1))
    tab.muiTabGem:SetShown(on and true or false)
    local f = Kit.Fonts()
    local font = on and f.tabActive or f.tab
    tab:SetNormalFontObject(font)
    tab:SetDisabledFontObject(font)
    tab:SetHighlightFontObject(on and f.tabActive or f.normal)
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", on and 28 or 14, 0)
        local width = text:GetUnboundedStringWidth() + (on and 44 or 28)
        tab:SetWidth(math.floor(width + 0.5))
    end
end

-- Scrollbar (B13) on Blizzard's MinimalScrollBar: narrow groove, material grip, chevron steppers --
function Kit.ScrollBar(bar)
    if type(bar) ~= "table" or not bar.Track or not Once(bar, "scroll") then return end
    local UI = ns.UI
    Fade(bar.Background)
    local track = bar.Track
    for _, region in ipairs({ track:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    local groove = CreateFrame("Frame", nil, track)
    groove:SetPoint("TOP")
    groove:SetPoint("BOTTOM")
    groove:SetWidth(ns.Snap(6))
    groove:SetFrameLevel(math.max(track:GetFrameLevel() - 1, 0))
    UI.Groove(groove)
    local parts = { groove } -- hidden while there is nothing to scroll (Blizzard keeps the bar)
    local thumb = track.Thumb or (bar.GetThumb and bar:GetThumb())
    if type(thumb) == "table" and thumb.GetRegions then
        for _, region in ipairs({ thumb:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
        local m = ns.Material()
        local grip = thumb:CreateTexture(nil, "OVERLAY")
        grip.muiKit = true
        grip:SetTexture(WHITE)
        grip:SetPoint("TOP")
        grip:SetPoint("BOTTOM")
        grip:SetWidth(ns.Snap(6))
        grip:SetGradient("HORIZONTAL", CreateColor(unpack(m.dark)), CreateColor(unpack(m.lit)))
        parts[#parts + 1] = grip
        Kit.WatchHover(thumb, function(_, hover) grip:SetAlpha(hover and 1 or 0.8) end)
    end
    for key, rotation in pairs({ Back = math.pi, Forward = 0 }) do
        local stepper = bar[key]
        if type(stepper) == "table" and stepper.GetRegions then
            for _, region in ipairs({ stepper:GetRegions() }) do
                if region.IsObjectType and region:IsObjectType("Texture") then region:SetAlpha(0) end
            end
            Fade(stepper.Texture)
            local icon = UI.Icon(stepper, "ChevronDown", 14, UI.MUTED)
            icon.muiKit = true
            icon:SetPoint("CENTER")
            icon:SetRotation(rotation)
            Kit.WatchHover(stepper, function(_, hover) icon:SetVertexColor(unpack(hover and UI.ACCENT or UI.MUTED)) end)
            parts[#parts + 1] = icon
        end
    end
    local function Refresh()
        local on = not bar.HasScrollableExtent or bar:HasScrollableExtent()
        for _, part in ipairs(parts) do part:SetShown(on and true or false) end
    end
    if bar.Update then hooksecurefunc(bar, "Update", Refresh) end
    Refresh()
end

-- Dropdown (WowStyle1DropdownTemplate): bevel like a button, chevron on the right
function Kit.Dropdown(dropdown)
    if type(dropdown) ~= "table" or not dropdown.GetRegions or not Once(dropdown, "dropdown") then return end
    local UI = ns.UI
    Fade(dropdown.Background)
    Fade(dropdown.Arrow)
    Track(dropdown, UI.Bevel, dropdown)
    local arrow = UI.Icon(dropdown, "ChevronDown", 10, UI.MUTED)
    arrow.muiKit = true
    arrow:SetPoint("RIGHT", -8, 0)
    Kit.WatchHover(dropdown, function(self, hover)
        if self.muiBevel then self.muiBevel(hover and "hover" or "normal") end
        arrow:SetVertexColor(unpack(hover and UI.ACCENT or UI.MUTED))
    end)
end
