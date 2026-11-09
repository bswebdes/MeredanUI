-- Confirmation dialogs (StaticPopup1-4) in mUI style: "Destroy item?", timed trades, group invites ...
-- No replacement frames possible - the buttons partly trigger protected actions (resurrect, bind
-- item ...). So visuals only: Blizzard's border/background hidden, our background with a Surf Green
-- edge underneath, flat buttons, edit box and timer bar. Nothing is written to Blizzard's tables,
-- only textures/fonts plus HookScript/hooksecurefunc - keeps everything taint-free.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local skinned = {} -- frame -> true (don't store as a field on Blizzard's frame)
local fonts

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.skinDialogs ~= false
end

local function Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, color)
        local font = CreateFont(name)
        font:SetFont(ns.STYLE.font, ns.FontPx(13), "")
        font:SetTextColor(unpack(color))
        font:SetShadowOffset(1, -1)
        font:SetShadowColor(0, 0, 0, 1)
        return font
    end
    fonts = {
        normal = Make("MeredanUIDialogButton", UI.TEXT),
        highlight = Make("MeredanUIDialogButtonHighlight", UI.ACCENT),
        disabled = Make("MeredanUIDialogButtonDisabled", UI.MUTED),
    }
    return fonts
end

-- flat button: Blizzard's art hidden, background + 1 px border underneath, brightens on hover
local function SkinButton(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    local UI = ns.UI
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(),
        button:GetHighlightTexture() }) do
        if texture then texture:SetAlpha(0) end
    end
    for _, key in ipairs({ "Left", "Middle", "Right" }) do -- UIPanelButtonTemplate art
        if button[key] then button[key]:SetAlpha(0) end
    end
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.FIELD))
    ns.AddBorder(button)
    button:HookScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
    button:HookScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    local f = Fonts()
    button:SetNormalFontObject(f.normal)
    button:SetHighlightFontObject(f.highlight)
    button:SetDisabledFontObject(f.disabled)
end

local function SkinCloseButton(button)
    if not button or skinned[button] then return end
    skinned[button] = true
    local UI = ns.UI
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(),
        button:GetHighlightTexture() }) do
        if texture then texture:SetAlpha(0) end
    end
    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    bg:SetColorTexture(unpack(UI.FIELD))
    local icon = UI.Icon(button, "Close", 14)
    icon:SetPoint("CENTER")
    button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
end

local function SkinEditBox(editBox)
    if not editBox or skinned[editBox] then return end
    skinned[editBox] = true
    local UI = ns.UI
    if editBox.NineSlice then editBox.NineSlice:SetAlpha(0) end
    local bg = editBox:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.FIELD))
    ns.AddBorder(editBox)
    local focus = ns.AddBorder(editBox, true)
    for _, edge in ipairs(focus) do
        edge:SetVertexColor(unpack(UI.ACCENT))
        edge:Hide()
    end
    editBox:HookScript("OnEditFocusGained", function() for _, e in ipairs(focus) do e:Show() end end)
    editBox:HookScript("OnEditFocusLost", function() for _, e in ipairs(focus) do e:Hide() end end)
end

-- Timer bar (e.g. trades): Blizzard's border removed, flat Surf Green bar
local function SkinProgressBar(popup)
    local border, fill = popup.ProgressBarBorder, popup.ProgressBarFill
    if not (border and fill) or skinned[border] then return end
    skinned[border] = true
    local UI = ns.UI
    border:SetAlpha(0)
    fill:SetTexture(ns.STYLE.barTexture or WHITE)
    fill:SetVertexColor(unpack(UI.ACCENT))
    local back = CreateFrame("Frame", nil, popup)
    back:SetPoint("TOPLEFT", border, "TOPLEFT", 4, -4)
    back:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -4, 4)
    back:SetFrameLevel(popup:GetFrameLevel())
    local bg = back:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.05, 1)
    ns.AddBorder(back)
    local function Sync() back:SetShown(border:IsShown()) end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do hooksecurefunc(border, method, Sync) end
    Sync()
end

local function ApplyText(popup)
    for _, region in ipairs({ popup.Text, popup.ConfirmText, popup.SubText }) do
        if region then
            local _, size = region:GetFont()
            region:SetFont(ns.STYLE.font, math.max(math.floor((size or 13) + 0.5), 12), "")
        end
    end
end

local function SkinPopup(popup)
    if not popup or skinned[popup] then return end
    skinned[popup] = true
    local UI = ns.UI
    if popup.BG then popup.BG:SetAlpha(0) end -- Blizzard's border and background (atlas)
    local bg = popup:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    local c = ns.STYLE.panelColor
    bg:SetColorTexture(c[1], c[2], c[3], 0.96)
    ns.AddBorder(popup)
    local accent = popup:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    local container = popup.ButtonContainer
    for _, button in ipairs(container and container.Buttons or {}) do SkinButton(button) end
    SkinButton(popup.ExtraButton)
    SkinCloseButton(popup.CloseButton)
    SkinEditBox(popup.EditBox)
    SkinProgressBar(popup)
    if popup.ItemFrame and popup.ItemFrame.NameFrame then popup.ItemFrame.NameFrame:SetAlpha(0) end
    popup:HookScript("OnShow", ApplyText)
    -- Wider edit boxes: Blizzard's default (130 px) is too narrow for names and notes
    -- (e.g. "Add guild member"). Applied one frame after Blizzard's setup.
    popup:HookScript("OnShow", function(self)
        C_Timer.After(0, function()
            local edit = self.EditBox
            if self:IsShown() and edit and edit:IsShown() and edit:GetWidth() < 240 then
                edit:SetWidth(260)
                if self:GetWidth() < 300 then self:SetWidth(320) end
            end
        end)
    end)
    if popup:IsShown() then ApplyText(popup) end
end

-- Quantity dialog (buy more at a merchant, split a stack): Blizzard's money-frame art and NineSlice
-- border hidden (alpha only - Blizzard toggles the two backgrounds with Show/Hide), our panel, a
-- value field between the arrows, chevron arrows, flat buttons.
local function SkinStackSplit(frame)
    if not frame or skinned[frame] then return end
    skinned[frame] = true
    local UI = ns.UI
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do -- a NineSlice border frame, if any
        if child.TopLeftCorner or child.Center then child:SetAlpha(0) end
    end
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    local c = ns.STYLE.panelColor
    bg:SetColorTexture(c[1], c[2], c[3], 0.96)
    ns.AddBorder(frame)
    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    local left, right = frame.LeftButton, frame.RightButton
    if left and right then
        local field = CreateFrame("Frame", nil, frame)
        field:SetFrameLevel(frame:GetFrameLevel())
        field:SetPoint("LEFT", left, "RIGHT", 4, 0)
        field:SetPoint("RIGHT", right, "LEFT", -4, 0)
        field:SetHeight(22)
        local fbg = field:CreateTexture(nil, "BACKGROUND")
        fbg:SetAllPoints()
        fbg:SetColorTexture(unpack(UI.FIELD))
        ns.AddBorder(field)
        for _, pair in ipairs({ { left, -math.pi / 2 }, { right, math.pi / 2 } }) do
            local button, rotation = pair[1], pair[2]
            for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
                local t = button[get](button)
                if t then
                    t:SetTexture(ns.MEDIA .. "Icons\\ChevronDown")
                    t:SetRotation(rotation)
                    t:SetVertexColor(unpack(get == "GetDisabledTexture" and UI.MUTED or UI.TEXT))
                    if get == "GetDisabledTexture" then t:SetAlpha(0.4) end
                end
            end
        end
    end
    -- OK with text, cancel as a red X (the German "Abbrechen" doesn't fit); both centred
    local okay, cancel = frame.OkayButton, frame.CancelButton
    SkinButton(okay)
    SkinButton(cancel)
    if okay and cancel then
        cancel:SetSize(24, 24)
        local label = cancel:GetFontString()
        if label then label:SetAlpha(0) end
        local x = cancel:CreateTexture(nil, "ARTWORK")
        x:SetTexture(ns.MEDIA .. "Icons\\Close")
        x:SetSize(14, 14)
        x:SetPoint("CENTER")
        local red = { 0.85, 0.35, 0.35 }
        x:SetVertexColor(unpack(red))
        cancel:HookScript("OnEnter", function()
            x:SetVertexColor(1, 0.5, 0.5)
            GameTooltip:SetOwner(cancel, "ANCHOR_TOP")
            GameTooltip:SetText(CANCEL, 1, 1, 1)
            GameTooltip:Show()
        end)
        cancel:HookScript("OnLeave", function()
            x:SetVertexColor(unpack(red))
            GameTooltip:Hide()
        end)
        okay:SetSize(72, 24)
        okay:ClearAllPoints()
        okay:SetPoint("BOTTOM", frame, "BOTTOM", -15, 12)
        cancel:ClearAllPoints()
        cancel:SetPoint("LEFT", okay, "RIGHT", 6, 0)
    end
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    for i = 1, 4 do SkinPopup(_G["StaticPopup" .. i]) end
    SkinStackSplit(_G.StackSplitFrame)
end)
