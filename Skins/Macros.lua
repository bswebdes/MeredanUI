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
-- OnEnter/OnLeave on Edit/Delete/New on every update; the skin kit's hover watcher handles that.
local _, ns = ...

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
local frame, subtitle
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
        if IsTexture(region) and not own[region] and not region.muiKit and not (keep and keep[region]) then region:SetAlpha(0) end
    end
end

local function Tex(parent, layer, sublevel, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    if color then tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    own[tex] = true
    return tex
end

-- Background + border + Surf Green top line
local function Panel(target)
    local c = ns.STYLE.panelColor
    local bg = Tex(target, "BACKGROUND", -8, { c[1], c[2], c[3], 0.97 })
    bg:SetAllPoints()
    ns.RuneFrame(target)
end

-- Controls: the shared skin kit (Skins/Kit.lua) gives Blizzard's widgets the rune look --------------
local Kit = ns.SkinKit

local function SkinButton(button) Kit.Button(button) end

local function HookScrollBox(box, fn)
    if type(box) ~= "table" or not box.ForEachFrame or not Once(box) then return end
    -- the list has no view until Blizzard fills it the first time (ForEachFrame would error)
    local function Each() if not box.GetView or box:GetView() then box:ForEachFrame(fn) end end
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
end

-- Macro / icon slot (SelectorButtonTemplate): item frame, accent outline when selected
local function UpdateSlot(button)
    local on = button.SelectedTexture and button.SelectedTexture:IsShown() and true or false
    Kit.SetSlotSelected(button, on)
    Fade(button.SelectedTexture)
end

local function SkinSlot(button)
    if type(button) ~= "table" or not button.Icon or not Once(button) then return end
    FadeRegions(button, { [button.Icon] = true })
    Fade(button.Highlight)
    Kit.Slot(button, button.Icon)
    if button.UpdateSelectedTexture then hooksecurefunc(button, "UpdateSelectedTexture", UpdateSlot) end
    if button.SelectedTexture then
        hooksecurefunc(button.SelectedTexture, "SetShown", function() UpdateSlot(button) end)
    end
    UpdateSlot(button)
end

-- Tabs (General / Character): rune-look tabs, the active one with a gem.
-- Blizzard disables the selected tab (and both while the icon popup is open).
local function UpdateTabs()
    if not frame then return end
    local selected = PanelTemplates_GetSelectedTab(frame)
    for i, tab in ipairs({ _G.MacroFrameTab1, _G.MacroFrameTab2 }) do
        if tab then
            tab:SetHeight(28)
            Kit.SetTabActive(tab, selected == i)
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

-- Icon popup (name + icon choice): framed panel like mUI windows
local function SkinPopup(popup)
    if type(popup) ~= "table" or not Once(popup) then return end
    Fade(popup.BG)
    local border = popup.BorderBox
    if border then
        FadeRegions(border)
        Fade(border.NineSlice)
        SkinButton(border.OkayButton)
        SkinButton(border.CancelButton)
        Kit.Dropdown(border.IconTypeDropdown)
        local edit = border.IconSelectorEditBox
        if edit then
            for _, key in ipairs({ "IconSelectorPopupNameLeft", "IconSelectorPopupNameMiddle", "IconSelectorPopupNameRight" }) do
                Fade(edit[key])
            end
            local field = CreateFrame("Frame", nil, edit)
            field:SetPoint("TOPLEFT", -6, 4)
            field:SetPoint("BOTTOMRIGHT", 2, -4)
            field:SetFrameLevel(math.max(edit:GetFrameLevel() - 1, 0))
            Kit.Field(field, edit)
        end
        local area = border.SelectedIconArea
        if area and area.SelectedIconButton then SkinSlot(area.SelectedIconButton) end
    end
    Panel(popup)
    local selector = popup.IconSelector
    if selector then
        Kit.ScrollBar(selector.ScrollBar)
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
    -- Blizzard's unnamed "Create Macros" title on the frame itself (our header shows the name)
    for _, region in ipairs({ f:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") and region:GetText() == _G.CREATE_MACROS then region:SetAlpha(0) end
    end
    if _G.MacroFramePortrait then _G.MacroFramePortrait:SetAlpha(0) end
    if f.Inset then Fade(f.Inset.Bg) Fade(f.Inset.NineSlice) end
    Panel(f)

    -- Header like mUI windows: framed icon, Cinzel title, divider below
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddItemFrame(holder, nil, 2)
    local portrait = holder:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(holder, portrait, nil, 2)
    portrait:SetTexture("Interface\\MacroFrame\\MacroFrame-Icon")
    portrait:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    local title = UI.Title(holder, 17, "LEFT")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    title:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
    title:SetText(MACROS or CREATE_MACROS or "")
    subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetPoint("RIGHT", title, "RIGHT")
    subtitle:SetWordWrap(false)
    local divider = UI.Divider(f)
    divider:SetPoint("TOPLEFT", PAD, -(PAD + ICON - 3))
    divider:SetPoint("TOPRIGHT", -PAD, -(PAD + ICON - 3))

    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -PAD - 36, 0)
    header:SetHeight(PAD + ICON + 6)
    ns.MakeWindowDraggable(f, header)

    local close = f.CloseButton or _G.MacroFrameCloseButton
    if close then
        Kit.IconButton(close, "Close", 22)
        close:SetSize(26, 26)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -PAD, -PAD)
    end

    Kit.Tab(_G.MacroFrameTab1)
    Kit.Tab(_G.MacroFrameTab2)
    if _G.MacroFrameTab1 then UI.TabBaseline(f, _G.MacroFrameTab1, PAD) end

    -- Macro grid set into the window
    local selector = f.MacroSelector
    if selector then
        local inset = CreateFrame("Frame", nil, f)
        inset:SetAllPoints(selector)
        inset:SetFrameLevel(math.max(selector:GetFrameLevel() - 1, 0))
        Kit.Inset(inset)
        Kit.ScrollBar(selector.ScrollBar)
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

    -- Text area: sunk field (groove), accent outline while typing, larger font
    local box = _G.MacroFrameTextBackground
    local text = _G.MacroFrameText
    if box then
        Fade(box.NineSlice)
        FadeRegions(box)
        Kit.Field(box, text)
    end
    if text then
        text:SetFont(ns.STYLE.font, ns.FontPx(13), "")
        text:SetTextColor(unpack(UI.TEXT))
    end
    local scroll = _G.MacroFrameScrollFrame
    if scroll then Kit.ScrollBar(scroll.ScrollBar) end

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
