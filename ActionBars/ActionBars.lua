-- Action bars: own LibActionButton bars replace Blizzard's, flat MUI look.
-- They use Blizzard's action slots and keybindings, so existing spells and binds stay put.
--
--                     [Stance]
--                  [Class bar]
--   [Player]    [ 1  2  3  4  5  6 ]   [Target]            |4|5|  right edge,
--   [Pet]       [ 7  8  9 10 11 12 ]                       | | |  vertical 12 x 1
--   [Pet bar]
--
--             [ Alt bar:   a-1 ... a-V ]
--             [ Shift bar: s-1 ... s-V ]   <- 25 px above the bottom edge
--
-- The main bar pages like Blizzard's: forms (druid), stealth, skyriding, vehicle, mind control,
-- Shift+mouse wheel pages. Pet and stance bars are Blizzard's own buttons (LAB cannot do pet
-- actions), just reparented and restyled. No layout changes in combat.
local _, ns = ...

local LAB = LibStub("LibActionButton-1.0")
local WHITE = "Interface\\Buttons\\WHITE8X8"

local SIZE = 36        -- extra bar button size

-- Width of a horizontal 12-button bar (Shift/Alt); the info bar matches it
function ns.ExtraBarWidth()
    return 12 * ns.Snap(SIZE) + 11 * ns.MAIN_BAR.gapPixels * ns.PixelSize()
end
local SMALL_SIZE = 26  -- stance bar
local GAP_PIXELS = ns.MAIN_BAR.gapPixels -- in physical pixels, same for all bars

-- page: fixed action page (slots (page-1)*12+1 .. +12), binding: Blizzard binding name without index
local BARS = {
    { key = "bar1", main = true, binding = "ACTIONBUTTON", cols = ns.MAIN_BAR.cols, size = ns.MAIN_BAR.size },
    { key = "bar2", page = 5, binding = "MULTIACTIONBAR2BUTTON", cols = 12 }, -- Shift (bottom right in Blizzard's layout)
    { key = "bar3", page = 6, binding = "MULTIACTIONBAR1BUTTON", cols = 12 }, -- Alt (bottom left in Blizzard's layout)
    { key = "bar4", page = 3, binding = "MULTIACTIONBAR3BUTTON", cols = 1 },  -- right, outer
    { key = "bar5", page = 4, binding = "MULTIACTIONBAR4BUTTON", cols = 1 },  -- right, inner
    -- Extra bars 6-8: Blizzard's bars 6-8 (pages 13-15), off by default
    { key = "bar6", page = 13, binding = "MULTIACTIONBAR5BUTTON", cols = 1 }, -- right, third vertical
    { key = "bar7", page = 14, binding = "MULTIACTIONBAR6BUTTON", cols = 6 }, -- bottom left, 6 x 2
    { key = "bar8", page = 15, binding = "MULTIACTIONBAR7BUTTON", cols = 6 }, -- bottom right, 6 x 2
}

-- Main bar paging (like ElvUI/Bartender). Since Dragonflight, vehicle, override and temp shapeshift
-- live on their own pages after extra bars 5-7 (16-18). Indices come from Blizzard instead of being
-- hardcoded; the snippet checks on each switch which one currently applies.
local VEHICLE_PAGE = C_ActionBar.GetVehicleBarIndex()
local OVERRIDE_PAGE = C_ActionBar.GetOverrideBarIndex()
local TEMP_SHAPESHIFT_PAGE = C_ActionBar.GetTempShapeshiftBarIndex()
local MAX_PAGE = math.max(14, VEHICLE_PAGE, OVERRIDE_PAGE, TEMP_SHAPESHIFT_PAGE)
local MAIN_PAGING = ("[overridebar] %d; [shapeshift] %d; [vehicleui][possessbar] %d; [bonusbar:5] 11; "):format(
        OVERRIDE_PAGE, TEMP_SHAPESHIFT_PAGE, VEHICLE_PAGE)
    .. "[bonusbar:4] 10; [bonusbar:3] 9; [bonusbar:2] 8; [bonusbar:1] 7; "
    .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
local MAIN_ONSTATE = ([[
    newstate = tonumber(newstate) or 1
    if newstate == %d or newstate == %d or newstate == %d then
        if HasVehicleActionBar() then
            newstate = GetVehicleBarIndex()
        elseif HasOverrideActionBar() then
            newstate = GetOverrideBarIndex()
        elseif HasTempShapeshiftActionBar() then
            newstate = GetTempShapeshiftBarIndex()
        end
    end
    self:SetAttribute("state", newstate)
    control:ChildUpdate("state", newstate)
]]):format(VEHICLE_PAGE, OVERRIDE_PAGE, TEMP_SHAPESHIFT_PAGE)

local hidden = CreateFrame("Frame")
hidden:Hide()
local bars = {}
ns.actionBars = bars -- for keybind mode (KeyBind.lua)

-- Hide Blizzard's bars (pet and stance are reparented below) ------------------------------

local BLIZZARD_BARS = {
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7", "OverrideActionBar", "PossessActionBar",
}
local BLIZZARD_BUTTONS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local function HideBlizzard()
    for _, name in ipairs(BLIZZARD_BARS) do
        local bar = _G[name]
        if bar then bar:SetParent(hidden) end
    end
    for _, prefix in ipairs(BLIZZARD_BUTTONS) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                button:UnregisterAllEvents() -- saves CPU; the buttons are invisible
                button:SetAttribute("statehidden", true)
            end
        end
    end
end

-- Flat look for an action button (ours and Blizzard's) -------------------------------------

local function ShortKey(text)
    if not text or issecretvalue(text) then return text end
    return (text:gsub("SHIFT%-", "s"):gsub("ALT%-", "a"):gsub("CTRL%-", "c"):gsub("META%-", "m")
        :gsub("MOUSEWHEELUP", "MwU"):gsub("MOUSEWHEELDOWN", "MwD"):gsub("BUTTON", "M")
        :gsub("NUMPAD", "N"):gsub("SPACE", "Spc"))
end

local function Hide(region)
    if region then region:SetAlpha(0) end -- alpha instead of Hide: Blizzard/LAB would show them again
end

-- Cooldown countdown numbers in our font; size follows button size.
local function StyleCooldownText(button, size)
    size = size or button.muiSize or 36
    for _, cooldown in ipairs({ button.cooldown or button.Cooldown, button.chargeCooldown }) do
        local text = cooldown and cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
        if text then ns.SetFont(text, math.floor(size * 0.4), "OUTLINE") end
    end
end

-- Rebuild Blizzard's button highlights as square outlines: Blizzard's texture goes invisible,
-- its show/hide toggles our outline.
local CreateOutline, AddPulse, AddSpecialHighlights -- defined below

local function Mirror(region, outline, extraCheck)
    region:SetAlpha(0)
    local function Sync()
        local on = region:IsShown() and (not extraCheck or extraCheck())
        outline:SetShown(on)
        if outline.pulse then
            if on then outline.pulse:Play() else outline.pulse:Stop() end
        end
    end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        if region[method] then hooksecurefunc(region, method, Sync) end
    end
    return Sync
end

AddSpecialHighlights = function(button)
    -- Spellbook hover: the spell's slot flashes white
    if button.SpellHighlightTexture then
        local outline = CreateOutline(button, { 1, 1, 1 }, 8)
        AddPulse(outline, 0.2, 0.35)
        Mirror(button.SpellHighlightTexture, outline)
        -- Blizzard's blink animation would make the texture visible again
        if button.SpellHighlightAnim then
            hooksecurefunc(button.SpellHighlightAnim, "Play", function(anim) anim:Stop() end)
        end
    end
    -- Pet attack: Blizzard flashes a red area constantly while attacking; use a calm thin red outline
    if button.Flash and button.StartFlash and button.StopFlash then
        button.Flash:SetAlpha(0)
        local outline = CreateOutline(button, { 0.9, 0.25, 0.25 }, 5, true)
        outline:Hide()
        hooksecurefunc(button, "StartFlash", function() outline:Show() end)
        hooksecurefunc(button, "StopFlash", function() outline:Hide() end)
        if button.IsFlashing and button:IsFlashing() then outline:Show() end
    end
    -- Pet autocast: thin, slowly pulsing outline while autocast is on
    local autoCast = button.AutoCastOverlay
    if autoCast then
        local accent = ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 }
        local outline = CreateOutline(button, accent, 5, true)
        AddPulse(outline, 0.3, 0.8)
        local enabled = false
        local Sync = Mirror(autoCast, outline, function() return enabled end)
        hooksecurefunc(autoCast, "ShowAutoCastEnabled", function(_, on)
            enabled = on and true or false
            Sync()
        end)
    end
end

local function StyleButton(button)
    if button.muiStyled then return end
    button.muiStyled = true
    button.MasqueSkinned = true -- LibActionButton then leaves the button art alone

    Hide(button.NormalTexture or button:GetNormalTexture())
    Hide(button.SlotBackground)
    Hide(button.SlotArt)
    Hide(button.FloatingBG)
    Hide(button.Border)
    Hide(button.NewActionTexture)
    if button.IconMask then button.icon:RemoveMaskTexture(button.IconMask) end
    button.icon:ClearAllPoints()
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Empty slot background: Blizzard's slot art cropped at the edges (rounded corners/border) to fit
    -- our square frame; plain dark without the atlas. The slot art is semi-transparent, so an
    -- opaque dark fill sits beneath it.
    ns.AddSlotBackground(button)
    ns.AddBorder(button)

    local function Flat(texture, r, g, b, a)
        if not texture then return end
        texture:SetTexture(WHITE)
        texture:SetVertexColor(r, g, b, a)
        texture:ClearAllPoints()
        texture:SetAllPoints()
    end
    Flat(button:GetPushedTexture(), 1, 1, 1, 0.25)
    Flat(button:GetHighlightTexture(), 1, 1, 1, 0.15)
    if button.GetCheckedTexture then
        local accent = ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 }
        Flat(button:GetCheckedTexture(), accent[1], accent[2], accent[3], 0.35)
    end

    local cooldown = button.cooldown or button.Cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints()
    end
    StyleCooldownText(button)
    -- "Ready" flash at cooldown end: square brighten instead of Blizzard's star
    if cooldown and cooldown.SetBlingTexture then cooldown:SetBlingTexture(WHITE, 1, 1, 1, 0.35) end
    AddSpecialHighlights(button)

    if button.HotKey then
        ns.SetFont(button.HotKey, 11, "OUTLINE")
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", -2, -3)
        button.HotKey:SetJustifyH("RIGHT")
        hooksecurefunc(button.HotKey, "SetText", function(self, text)
            if self.muiSetting then return end
            -- Blizzard's own buttons (extra action) write the long key name ("s-Middle Mouse"),
            -- so shorten the raw binding instead
            local raw = button.commandName and GetBindingKey(button.commandName)
            local short = ShortKey(raw or text)
            if short ~= text then
                self.muiSetting = true
                self:SetText(short)
                self.muiSetting = false
            end
        end)
        button.HotKey:SetText(button.HotKey:GetText())
    end
    if button.Count then
        ns.SetFont(button.Count, 12, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", -2, 3)
    end
    if button.Name then
        ns.SetFont(button.Name, 10, "OUTLINE")
        button.Name:ClearAllPoints()
        button.Name:SetPoint("BOTTOMLEFT", 2, 3)
        button.Name:SetPoint("BOTTOMRIGHT", -2, 3)
    end
end

-- Square highlights instead of Blizzard's round ones -------------------------------------
--   Proc (spell lights up, e.g. from a talent effect): gold outline, glowing, pulsing
--   Rotation assist (Blizzard's "next recommended spell"): cyan outline, glowing,
--   slowly pulsing
local PROC_COLOR = { 1, 0.82, 0.2 }
local ASSIST_COLOR = { 0.3, 0.75, 1 }
local highlightButtons = {}

-- Square glow: 2 px solid inside, outer rings with decreasing opacity.
local GLOW_ALPHAS = { 0.55, 0.3, 0.12 }

local function Ring(frame, offsetPx, color, alpha)
    local px = ns.PixelSize()
    local o, i = (offsetPx + 1) * px, offsetPx * px -- outer/inner edge of the ring
    local function Edge()
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(WHITE)
        tex:SetVertexColor(color[1], color[2], color[3], alpha)
        return tex
    end
    local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
    top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", o, i)
    bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -o, -i)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, i)
    left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -i, -i)
    right:SetPoint("TOPLEFT", frame, "TOPRIGHT", i, i)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -i)
end

-- thin: 1 px inside only, no glow (for subtle hints)
CreateOutline = function(button, color, level, thin)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints()
    frame:SetFrameLevel(button:GetFrameLevel() + level)
    for _, edge in ipairs(ns.AddBorder(frame, true, thin and 1 or 2)) do edge:SetVertexColor(unpack(color)) end
    -- ring 0 sits on our 1 px border, then outward
    if not thin then
        for n, alpha in ipairs(GLOW_ALPHAS) do Ring(frame, n - 1, color, alpha) end
    end
    frame:Hide()
    return frame
end

-- Slow opacity pulse for a highlight
AddPulse = function(frame, low, duration)
    local pulse = frame:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(low)
    fade:SetDuration(duration)
    frame.pulse = pulse
end

local function AddHighlights(button)
    button.muiProc = CreateOutline(button, PROC_COLOR, 6)
    AddPulse(button.muiProc, 0.35, 0.5)
    button.muiAssist = CreateOutline(button, ASSIST_COLOR, 7)
    AddPulse(button.muiAssist, 0.55, 0.9)
    button.muiRotation = CreateOutline(button, ASSIST_COLOR, 7) -- single-button assistant
    highlightButtons[#highlightButtons + 1] = button
end

local function SpellID(button)
    local id = button:GetSpellId()
    if ns.Readable(id) then return id end
end

local function UpdateProc(button)
    local id = SpellID(button)
    local on = id and C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed(id)
    on = ns.Readable(on) and on or false
    button.muiProc:SetShown(on)
    if on then button.muiProc.pulse:Play() else button.muiProc.pulse:Stop() end
end

local function UpdateAssist(button)
    -- Hide Blizzard's own (round) highlight if it attaches one to our button
    if button.AssistedCombatHighlightFrame then button.AssistedCombatHighlightFrame:SetAlpha(0) end
    local next = AssistedCombatManager and AssistedCombatManager.lastNextCastSpellID
    local id = SpellID(button)
    local on = ns.Readable(next) and id ~= nil and id == next
    button.muiAssist:SetShown(on)
    if on then button.muiAssist.pulse:Play() else button.muiAssist.pulse:Stop() end
end

-- Single-button assistant: hide Blizzard's frame around this button, show our cyan one
local function UpdateRotation(button)
    local frame = button.AssistedCombatRotationFrame
    if frame then frame:SetAlpha(0) end
    button.muiRotation:SetShown(frame ~= nil and frame:IsShown())
end

local function UpdateAllHighlights()
    for _, button in ipairs(highlightButtons) do
        UpdateProc(button)
        UpdateAssist(button)
        UpdateRotation(button)
    end
end

local highlightEvents = CreateFrame("Frame")
highlightEvents:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
highlightEvents:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
highlightEvents:SetScript("OnEvent", function() for _, button in ipairs(highlightButtons) do UpdateProc(button) end end)
if EventRegistry then
    EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", UpdateAllHighlights, highlightEvents)
    EventRegistry:RegisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", UpdateAllHighlights, highlightEvents)
    EventRegistry:RegisterCallback("ActionButton.OnAssistedCombatRotationFrameChanged", UpdateAllHighlights, highlightEvents)
end
LAB.RegisterCallback(highlightEvents, "OnButtonUpdate", function(_, button)
    if button.muiProc then
        UpdateProc(button)
        UpdateAssist(button)
        UpdateRotation(button)
    end
    StyleCooldownText(button) -- LAB creates the charge cooldown lazily
end)

-- Arrange buttons in a grid: cols columns, first button top left.
local function Arrange(holder, buttons, cols, size)
    local rows = math.ceil(#buttons / cols)
    size = ns.Snap(size)
    local gap = GAP_PIXELS * ns.PixelSize()
    holder:SetSize(cols * size + (cols - 1) * gap, rows * size + (rows - 1) * gap)
    for i, button in ipairs(buttons) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        button:ClearAllPoints()
        button:SetSize(size, size)
        button.muiSize = size
        StyleCooldownText(button, size)
        button:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (size + gap), -row * (size + gap))
    end
end

-- Flyouts (poisons, portals, call pet ...) --------------------------------------------------
-- LAB builds its own flyout buttons: MUI look, without Blizzard's background rail.
LAB.RegisterCallback(highlightEvents, "OnFlyoutButtonCreated", function(_, button) StyleButton(button) end)
for _, button in ipairs(LAB.FlyoutButtons or {}) do StyleButton(button) end

-- Direction per bar: vertical bars open sideways toward screen center, horizontal ones up
-- (or down in the upper screen half). Follows moved bars.
local function UpdateFlyoutDirection(bar)
    if InCombatLockdown() then return end
    local x, y = bar:GetCenter()
    if not x then return end
    local midX, midY = UIParent:GetCenter()
    local dir
    if bar.def.cols == 1 then
        dir = x > midX and "LEFT" or "RIGHT"
    else
        dir = y > midY and "DOWN" or "UP"
    end
    for _, button in ipairs(bar.buttons) do
        if button.config.flyoutDirection ~= dir then
            button.config.flyoutDirection = dir
            button:SetAttribute("flyoutDirection", dir)
            button:UpdateFlyout()
        end
    end
end

-- Own bars --------------------------------------------------------------------------------

-- Per-bar button texts: keybind and macro name, on by default.
-- Count/charges and cooldown are always shown.
local function TextShown(key, what)
    local t = ns.db and ns.db.actionBarTexts and ns.db.actionBarTexts[key]
    return not (t and t[what] == false)
end
ns.ActionBarTextShown = TextShown

-- Keybind font size for all bars: small = legacy size, large = LAB's default.
-- Macro name and count are unchanged.
local HOTKEY_SIZES = { small = 11, medium = 12, large = 14 }
local function HotkeySize() return HOTKEY_SIZES[ns.db and ns.db.actionBarFont or "medium"] or 12 end
local function HotkeyText()
    return { hotkey = {
        font = { font = ns.FontFor and ns.FontFor() or ns.STYLE.font, size = ns.FontPx(HotkeySize()), flags = "OUTLINE" },
        position = { anchor = "TOPRIGHT", relAnchor = "TOPRIGHT", offsetX = -2, offsetY = -3 },
    } }
end

local function ButtonConfig(def, index)
    return {
        showGrid = true,
        keyBoundTarget = def.binding .. index,
        -- report as a Blizzard action button so rotation assist & co. know our buttons;
        -- their round visuals are replaced by square outlines below
        actionButtonUI = true,
        assistedHighlight = false,
        hideElements = { macro = not TextShown(def.key, "macro"), hotkey = not TextShown(def.key, "hotkey"),
            equipped = true, border = true, borderIfEmpty = true },
        text = HotkeyText(),
    }
end

local function CreateBar(def)
    local name = "MeredanUI" .. def.key:gsub("^%l", string.upper)
    local header = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
    header:SetFrameStrata("LOW")
    header.buttons = {}
    header.muiKey = def.key
    for i = 1, 12 do
        local button = LAB:CreateButton(i, name .. "Button" .. i, header, ButtonConfig(def, i))
        if def.main then
            for page = 1, MAX_PAGE do button:SetState(page, "action", (page - 1) * 12 + i) end
        else
            button:SetState(0, "action", (def.page - 1) * 12 + i)
        end
        -- Mouseover casting like Blizzard's buttons; whether it applies is decided by the
        -- enableMouseoverCast CVar ("Mouseover healing" setting, ns.ApplyMouseoverCast)
        button:SetAttribute("checkmouseovercast", true)
        StyleButton(button)
        AddHighlights(button)
        header.buttons[i] = button
    end
    if def.main then
        header:SetAttribute("_onstate-page", MAIN_ONSTATE)
        RegisterStateDriver(header, "page", MAIN_PAGING)
    else
        header:SetAttribute("state", 0)
    end
    for _, button in ipairs(header.buttons) do button:UpdateAction(true) end
    Arrange(header, header.buttons, def.cols, def.size or SIZE)
    header.def = def
    -- placement ends up in SetPoint (header dragging in StopMovingOrSizing)
    local function Update() UpdateFlyoutDirection(header) end
    hooksecurefunc(header, "SetPoint", Update)
    hooksecurefunc(header, "StopMovingOrSizing", Update)
    return header
end

-- Keys: Blizzard's binds (ACTIONBUTTON1, MULTIACTIONBAR1BUTTON1 ...) click our buttons.
local bindOwner = CreateFrame("Frame")
local function UpdateBindings()
    if InCombatLockdown() then return ns.AfterCombat(UpdateBindings) end
    ClearOverrideBindings(bindOwner)
    for _, bar in ipairs(bars) do
        for i, button in ipairs(bar.buttons) do
            for _, key in ipairs({ GetBindingKey(bar.def.binding .. i) }) do
                SetOverrideBindingClick(bindOwner, false, key, button:GetName(), "LeftButton")
            end
        end
    end
end

-- Pet and stance bars: Blizzard's buttons in our holder ---------------------------------

-- Keep a Blizzard bar in the holder permanently; Blizzard moves it on Edit Mode changes and
-- re-lays out the buttons - hooks undo both.
local adopted = {} -- [bar key] = Blizzard buttons (pet, stance)
local function AdoptBlizzardBar(bar, holder, prefix, count, cols, size, key)
    if not bar then return end
    local buttons = {}
    if key then adopted[key] = buttons end
    for i = 1, count do
        local button = _G[prefix .. i]
        if button then
            StyleButton(button)
            buttons[#buttons + 1] = button
        end
    end
    local function Apply()
        if InCombatLockdown() then return end
        bar.muiPlacing = true
        bar:SetParent(holder)
        bar:ClearAllPoints()
        bar:SetAllPoints(holder)
        Arrange(holder, buttons, cols, size)
        bar.muiPlacing = false
    end
    hooksecurefunc(bar, "SetPoint", function() if not bar.muiPlacing then Apply() end end)
    if bar.UpdateGridLayout then hooksecurefunc(bar, "UpdateGridLayout", Apply) end
    Apply()
end

-- Visibility (Settings > Action Bars) ----------------------------------------------------
-- Show/hide uses secure state drivers (works in combat), mouseover uses alpha (buttons and keys
-- still work). All bars hide in pet battles; the main bar always shows in vehicles.
local framesByKey = {}

local VISIBILITY = {
    always = "show",
    mouseover = "show",
    combat = "show", -- visible in combat, otherwise like mouseover (still reachable by mouse)
    hidden = "hide",
}

-- Read a bar's setting: like everywhere else, but "combat" really exists only here
-- (hidden out of combat, visible on mouseover)
local function BarMode(key)
    local raw = ns.db.actionBars[key]
    if raw == "combat" then return "combat" end
    return ns.VisibilityMode(raw)
end
ns.ActionBarMode = BarMode

-- Innermost visible right bar (6 before 5 before 4): the quest tracker aligns to it
function ns.InnermostRightBar()
    for _, key in ipairs({ "bar6", "bar5", "bar4" }) do
        local bar = ns.layoutFrames and ns.layoutFrames[key]
        if bar and bar:IsVisible() and bar:GetLeft() then return bar end
    end
end

-- Space bar 7 (bottom left) needs beside the 12-button rows; the chat shrinks accordingly so it
-- never slides underneath (0 when the bar is off)
function ns.LeftBlockReserve()
    if not ns.db or BarMode("bar7") == "hidden" then return 0 end
    return 6 * ns.Snap(SIZE) + 5 * GAP_PIXELS * ns.PixelSize() + ns.Snap(12)
end

local function VisibilityRule(key, mode)
    local rule = VISIBILITY[mode] or "show"
    if key == "bar1" and mode ~= "hidden" then rule = "[vehicleui][overridebar][possessbar] show; " .. rule end
    return "[petbattle] hide; " .. rule
end

-- Smooth fading: each bar has a target (muiTarget), an OnUpdate moves alpha toward it over
-- FADE_TIME. Alpha may be set in combat.
local FADE_TIME = 0.15
-- The fader hides itself once every bar reached its target; WakeFader restarts it.
local fader = CreateFrame("Frame")
fader:SetScript("OnUpdate", function(self, elapsed)
    local step = elapsed / FADE_TIME
    local busy = false
    for _, frame in pairs(framesByKey) do
        local target = frame.muiTarget
        if target then
            local alpha = frame:GetAlpha()
            if alpha < target then
                frame:SetAlpha(math.min(target, alpha + step))
                busy = true
            elseif alpha > target then
                frame:SetAlpha(math.max(target, alpha - step))
                busy = true
            end
        end
    end
    if not busy then self:Hide() end
end)
local function WakeFader()
    if fader:IsShown() then return end
    for _, frame in pairs(framesByKey) do
        if frame.muiTarget and frame:GetAlpha() ~= frame.muiTarget then return fader:Show() end
    end
end

-- Keybind/macro texts per setting (LAB buttons via their config, Blizzard pet/stance buttons
-- via alpha)
function ns.ApplyActionBarTexts()
    if InCombatLockdown() then return ns.AfterCombat(ns.ApplyActionBarTexts) end
    for _, header in ipairs(bars) do
        local key = header.muiKey
        for _, button in ipairs(header.buttons or {}) do
            local config = CopyTable(button.config)
            config.hideElements.hotkey = not TextShown(key, "hotkey")
            config.hideElements.macro = not TextShown(key, "macro")
            local text = HotkeyText()
            config.text.hotkey.font = text.hotkey.font
            config.text.hotkey.position = text.hotkey.position
            button:UpdateConfig(config)
        end
    end
    for key, buttons in pairs(adopted) do
        for _, button in ipairs(buttons) do
            if button.HotKey then
                button.HotKey:SetAlpha(TextShown(key, "hotkey") and 1 or 0)
                ns.SetFont(button.HotKey, HotkeySize(), "OUTLINE")
            end
            if button.Name then button.Name:SetAlpha(TextShown(key, "macro") and 1 or 0) end
        end
    end
end

function ns.ApplyActionBarVisibility()
    if InCombatLockdown() then return ns.AfterCombat(ns.ApplyActionBarVisibility) end
    for key, frame in pairs(framesByKey) do
        local mode = BarMode(key) -- always, combat, mouseover or hidden
        local rule = VisibilityRule(key, mode)
        frame.muiMouseover = mode == "mouseover"
        frame.muiCombat = mode == "combat"
        if mode == "hidden" and frame:IsShown() and frame:GetAlpha() > 0 then
            -- fade out first, then really hide (the state driver hides instantly)
            frame.muiTarget = 0
            C_Timer.After(FADE_TIME, function()
                if InCombatLockdown() or BarMode(key) ~= "hidden" then return end
                RegisterStateDriver(frame, "visibility", rule)
            end)
        else
            if not frame:IsShown() then frame:SetAlpha(0) end -- just enabled: fade in
            RegisterStateDriver(frame, "visibility", rule)
            if not (frame.muiMouseover or frame.muiCombat) then frame.muiTarget = 1 end
        end
    end
    fader:Show()
    -- quest tracker (right) and chat (left) move aside or back
    C_Timer.After(0, function() if ns.Relayout then ns.Relayout() end end)
end

-- An open flyout is parented to its bar's button and sits beside it: mouse over it counts as over the bar
local function MouseOverFlyout(frame)
    local flyout = LAB:GetSpellFlyoutFrame()
    if not (flyout and flyout:IsVisible() and flyout:IsMouseOver(4, -4, -4, 4)) then return false end
    local parent = flyout:GetParent()
    while parent do
        if parent == frame then return true end
        parent = parent:GetParent()
    end
    return false
end

-- Mouseover: poll every 0.1 s (alpha may be set in combat)
C_Timer.NewTicker(0.1, function()
    local inCombat = InCombatLockdown()
    for _, frame in pairs(framesByKey) do
        if frame.muiCombat and inCombat then
            frame.muiTarget = 1
        elseif frame.muiMouseover or frame.muiCombat then
            local over = frame:IsVisible() and (frame:IsMouseOver(4, -4, -4, 4) or MouseOverFlyout(frame))
            frame.muiTarget = over and 1 or 0
        end
    end
    WakeFader()
end)

-- Setup -------------------------------------------------------------------------------------

local function Place(frame, key, point, x, y)
    ns.PlaceFromCenter(frame, point, x, y)
    ns.layoutFrames[key] = frame
    framesByKey[key] = frame
end

-- Extra action button and zone ability buttons: remove Blizzard's decoration (it draws a fixed
-- square around the button); for the extra button it is rebuilt behind it (see below). The
-- button itself gets the MUI look like the action bars. Blizzard resets the decoration per
-- ability (SetTexture/SetAtlas/Show), so we clear it again afterwards.
local function HideDecoration(texture, onTexture)
    if not texture then return end
    texture:SetTexture(nil)
    texture:Hide()
    if not texture.muiHidden then
        texture.muiHidden = true
        -- after every set/show by Blizzard, clear and hide it again; the new texture goes to
        -- our rebuild (onTexture)
        for _, method in ipairs({ "SetTexture", "SetAtlas", "Show" }) do
            hooksecurefunc(texture, method, function(self, file)
                if self.muiHiding then return end
                if onTexture and method ~= "Show" and file then onTexture(method, file) end
                self.muiHiding = true
                self:SetTexture(nil)
                self:Hide()
                self.muiHiding = false
            end)
        end
    end
end

-- Extra button: Blizzard's cloud art rebuilt BEHIND the button; the button is sized to exactly
-- cover the square drawn into Blizzard's art. Parented to ExtraActionBarFrame so it shows/hides
-- with it.
local BOSS_BUTTON_SIZE = 60

local function BuildBossDecoration(button)
    local bar = button:GetParent()
    local deco = CreateFrame("Frame", nil, bar)
    deco:SetFrameLevel(math.max(button:GetFrameLevel() - 2, 0))
    deco:SetSize(256, 128)
    deco:SetPoint("CENTER", button, "CENTER")
    deco.art = deco:CreateTexture(nil, "BACKGROUND")
    deco.art:SetAllPoints()
    button:SetSize(ns.Snap(BOSS_BUTTON_SIZE), ns.Snap(BOSS_BUTTON_SIZE)) -- out of combat only (setup)
    local function SetArt(method, file)
        if method == "SetAtlas" then deco.art:SetAtlas(file) else deco.art:SetTexture(file) end
    end
    -- take over the current art (Blizzard sets it whenever an ability appears)
    SetArt("SetTexture", C_ActionBar.GetOverrideBarSkin and C_ActionBar.GetOverrideBarSkin() or "Interface\\ExtraButton\\Default") -- Blizzard's default (local there)
    return SetArt
end

local SkinZoneButtons
function SkinZoneButtons(frame)
    local container = frame and frame.SpellButtonContainer
    if not (container and container.EnumerateActive) then return end
    if InCombatLockdown() then return ns.AfterCombat(function() SkinZoneButtons(frame) end) end
    for button in container:EnumerateActive() do
        if not button.muiStyled then
            button.icon = button.icon or button.Icon -- StyleButton expects .icon
            StyleButton(button)
        end
        -- for zone abilities the cloud already sits BEHIND the buttons (frame art) and stays;
        -- the button covers the drawn square like the extra button
        button:SetSize(ns.Snap(BOSS_BUTTON_SIZE), ns.Snap(BOSS_BUTTON_SIZE))
    end
    if container.MarkDirty then container:MarkDirty() end
end

local function SkinExtraButtons()
    if ExtraActionButton1 then
        StyleButton(ExtraActionButton1)
        HideDecoration(ExtraActionButton1.style, BuildBossDecoration(ExtraActionButton1))
    end
    if ZoneAbilityFrame and ZoneAbilityFrame.UpdateDisplayedZoneAbilities then
        hooksecurefunc(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", SkinZoneButtons)
        SkinZoneButtons(ZoneAbilityFrame)
    end
end

local function Setup()
    -- Bartender4/Dominos (or the switch) take over: no mUI bars at all (Core/OtherAddons.lua)
    if ns.ModuleOn and not ns.ModuleOn("actionBarModule") then return end
    HideBlizzard()
    local gap = GAP_PIXELS * ns.PixelSize()
    -- Stacked (healer or chosen): main bar as one row of 12 at extra-bar size (bottom, above Alt/Shift)
    local healer = ns.StackedBars()
    local noClassBar = ns.LayoutFlag("healerBars") -- no Forever healer has a class bar
    if healer then
        BARS[1].cols, BARS[1].size = 12, SIZE
    end

    for _, def in ipairs(BARS) do bars[#bars + 1] = CreateBar(def) end
    -- remove Blizzard's golden flyout rail behind the buttons (exists only after the first button)
    local flyout = LAB:GetSpellFlyoutFrame()
    if flyout and flyout.Background then flyout.Background:SetAlpha(0) end
    local main, shift, alt, right, inner, third, leftBlock, rightBlock = unpack(bars)

    -- Positions from screen size - rerun on size/scale changes
    ns.OnLayout(function()
        local halfW, halfH = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
        local margin = ns.Snap(ns.SCREEN_MARGIN)
        local size, barGap = ns.Snap(SIZE), GAP_PIXELS * ns.PixelSize()
        local classBar = ns.layoutFrames.classpower
        if healer then
            -- bottom three rows: Shift, Alt, main bar (see below); class bar above the group
            Place(main, "bar1", "BOTTOM", 0, -halfH + margin + 2 * (size + barGap))
            if classBar and noClassBar then
                classBar:SetAlpha(0)
            elseif classBar then
                -- stacked without healer: class bar stays above the unit frames (like centered layout)
                local player = ns.frames and ns.frames.player
                local top = player and player:GetTop() and (player:GetTop() - halfH) or -ns.Snap(ns.FRAME_TOP_Y)
                classBar:SetAlpha(1)
                ns.PlaceFromCenter(classBar, "BOTTOM", 0, top + ns.Snap(12))
            end
        else
            -- main bar centered, top edge level with the player frame
            local player = ns.frames and ns.frames.player
            local mainTop = player and player:GetTop() and (player:GetTop() - halfH) or -ns.Snap(ns.FRAME_TOP_Y)
            Place(main, "bar1", "TOP", 0, mainTop)
            -- class bar above it with a gap
            if classBar then
                classBar:SetAlpha(1)
                ns.PlaceFromCenter(classBar, "BOTTOM", 0, main:GetTop() - halfH + ns.Snap(12))
            end
        end
        -- bottom: Shift at the very bottom, Alt above it
        Place(shift, "bar2", "BOTTOM", 0, -halfH + margin)
        Place(alt, "bar3", "BOTTOM", 0, -halfH + margin + size + barGap)
        -- right: first bar at the edge, second inside next to it (vertically centered)
        Place(right, "bar4", "RIGHT", halfW - margin, 0)
        Place(inner, "bar5", "RIGHT", halfW - margin - size - barGap, 0)
        -- extra bars: third vertical on the right; at the bottom a 6 x 2 block left and right of
        -- the 12-button rows, bottom-aligned
        Place(third, "bar6", "RIGHT", halfW - margin - 2 * (size + barGap), 0)
        local sideGap = ns.Snap(12)
        local half = ns.ExtraBarWidth() / 2
        Place(leftBlock, "bar7", "BOTTOMRIGHT", -half - sideGap, -halfH + margin)
        Place(rightBlock, "bar8", "BOTTOMLEFT", half + sideGap, -halfH + margin)
    end)

    -- pet bar below the pet frame, same width
    local pet = ns.smallFrames and ns.smallFrames.pet
    if PetActionBar and pet then
        local petHolder = CreateFrame("Frame", "MeredanUIPetBar", UIParent, "SecureHandlerStateTemplate")
        local petSize = (ns.FrameWidth() - 9 * gap) / 10
        AdoptBlizzardBar(PetActionBar, petHolder, "PetActionButton", 10, 10, petSize, "petbar")
        petHolder:SetPoint("TOPLEFT", pet, "BOTTOMLEFT", 0, -gap)
        -- buttons are rounded to whole pixels, so the row ends up a few pixels off the pet frame width;
        -- match the frame to the row so both end flush
        ns.AfterCombat(function() pet:SetWidth(petHolder:GetWidth()) end)
        ns.layoutFrames.petbar = petHolder
        framesByKey.petbar = petHolder
    end

    -- stance bar above the Alt bar, one button in from the left, grows right (default: mouseover)
    if StanceBar then
        local stanceHolder = CreateFrame("Frame", "MeredanUIStanceBar", UIParent, "SecureHandlerStateTemplate")
        AdoptBlizzardBar(StanceBar, stanceHolder, "StanceButton", 10, 10, SMALL_SIZE, "stancebar")
        if healer then
            -- healer: left of the bottom rows, level with the main bar (cast bar sits above)
            stanceHolder:SetPoint("BOTTOMRIGHT", main, "BOTTOMLEFT", -ns.Snap(12), 0)
        else
            -- one button in from the bar's left end: clear of the end cap's paws
            stanceHolder:SetPoint("BOTTOMLEFT", alt, "TOPLEFT", ns.Snap(SIZE) + gap, gap)
        end
        ns.layoutFrames.stancebar = stanceHolder
        framesByKey.stancebar = stanceHolder
    end

    -- leave vehicle: Blizzard's button right of the main bar
    local leave = MainMenuBarVehicleLeaveButton
    if leave then
        local function PlaceLeave()
            leave.muiPlacing = true
            leave:SetParent(UIParent)
            leave:ClearAllPoints()
            leave:SetPoint("LEFT", main, "RIGHT", gap, 0)
            leave.muiPlacing = false
        end
        hooksecurefunc(leave, "SetPoint", function() if not leave.muiPlacing and not InCombatLockdown() then PlaceLeave() end end)
        PlaceLeave()
    end

    UpdateBindings()
    ns.ApplyActionBarVisibility()
    ns.ApplyActionBarTexts() -- pet/stance buttons per setting
    SkinExtraButtons()
end

ns:On("UPDATE_BINDINGS", UpdateBindings)
-- Mouseover healing: Blizzard's toggle (Options > Combat) follows the mUI setting
function ns.ApplyMouseoverCast()
    if GetCVar("enableMouseoverCast") == nil then return end
    SetCVar("enableMouseoverCast", ns.db.mouseoverHeal and "1" or "0")
end

ns:On("PLAYER_LOGIN", function()
    if ns.db.mouseoverHeal then ns.ApplyMouseoverCast() end -- off: don't override Blizzard's own choice
    -- Cooldown numbers are part of the mUI look: keep Blizzard's toggle on.
    ns.LookCVar("countdownForCooldowns", "1")
    -- Right at login (oUF has built its frames by then): after a /reload in combat the lockdown only
    -- applies after loading - a later timer would leave the bars missing until combat ends.
    ns.AfterCombat(Setup)
end)
