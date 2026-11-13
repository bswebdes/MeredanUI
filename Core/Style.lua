-- MeredanUI look: flat dark panels with 1px borders. Colors come from the theme
-- (class color, dark, sage); fonts and bar texture are registered with LibSharedMedia.
local ADDON_NAME, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

ns.STYLE = {
    font = STANDARD_TEXT_FONT,
    fontSize = 11,
    barTexture = WHITE,
    panelColor = { 0.06, 0.06, 0.06, 0.9 },
    bgMultiplier = 0.25, -- empty part = bar color x factor (sage theme)
    castColor = { 0.85, 0.65, 0.2 },              -- own casts
    castInterruptibleColor = { 0.25, 0.8, 0.95 }, -- target: interruptible (turquoise)
    castLockedColor = { 0.5, 0.5, 0.5 },          -- target: not interruptible (gray)
    castLatencyColor = { 0.9, 0.2, 0.2, 0.6 },    -- player: latency at the end of the castbar
    -- Status icons (white textures, tinted here)
    combatColor = { 0.95, 0.3, 0.25 },     -- combat
    restingColor = { 0.55, 0.78, 1 },      -- resting
    deadColor = { 0.9, 0.9, 0.9 },         -- dead
    ghostColor = { 0.7, 0.85, 1 },         -- ghost
    resurrectColor = { 0.35, 1, 0.45 },    -- incoming resurrection
    questColor = { 1, 0.82, 0.1 },         -- quest mob
    phaseColor = { 0.85, 0.85, 0.85 },     -- other phase
    offlineColor = { 0.6, 0.6, 0.6 },      -- offline (group frames)
    afkColor = { 0.75, 0.75, 0.75 },       -- AFK (group frames)
    leaderColor = { 1, 1, 1 },             -- group leader (crown; white with shadow reads on any class color)
    assistantColor = { 0.9, 0.9, 0.9 },    -- assistant (crown outline)
    readyColors = {                        -- ready check: ready / not ready / waiting
        ready = { 0.35, 1, 0.45 }, notready = { 1, 0.3, 0.25 }, waiting = { 0.85, 0.85, 0.85 },
    },
    summonColors = {                       -- summon: pending / accepted / declined
        { 0.75, 0.5, 1 }, { 0.35, 1, 0.45 }, { 1, 0.3, 0.25 },
    },
}
local STYLE = ns.STYLE

-- Themes: colors only.
--   classHealth: player health bars in class color (NPCs by reaction)
--   emptyColor:  neutral empty bar part instead of darkened bar color
--   darkHealth:  dark health fill, missing health slightly lighter (healthEmpty)
--   powerClassColor: player power bars in class color
ns.THEMES = {
    class = {
        name = L["Class colour"],
        panelColor = { 0.086, 0.075, 0.059, 0.93 }, -- rune look: warm dark brown
        healthColor = { 111 / 255, 181 / 255, 154 / 255 }, -- Surf palette
        classHealth = true,
        emptyColor = { 0.1, 0.1, 0.1 },
    },
    dark = {
        name = L["Dark"],
        panelColor = { 0.02, 0.02, 0.02, 0.95 },
        healthColor = { 111 / 255, 181 / 255, 154 / 255 }, -- Surf palette
        emptyColor = { 0.12, 0.12, 0.12 },
        darkHealth = { 0.1, 0.1, 0.1 },
        healthEmpty = { 0.3, 0.3, 0.3 },
        powerClassColor = true,
    },
    blizzard = {
        name = L["Blizzard"], -- Blizzard's default frame colours: green health, Blizzard power colours, bronze borders
        panelColor = { 0.086, 0.075, 0.059, 0.93 }, -- rune look: warm dark brown
        healthColor = { 0, 0.8, 0 },
        emptyColor = { 0.1, 0.08, 0.06 },
        blizzardPower = true,
        borderColor = { 0.5, 0.4, 0.24, 1 }, -- = ns.GOLD_BORDER
    },
    green = {
        name = L["mUI (sage)"], -- single-color sage
        panelColor = { 0.086, 0.075, 0.059, 0.93 }, -- rune look: warm dark brown
        healthColor = { 111 / 255, 181 / 255, 154 / 255 }, -- Surf palette
    },
}
ns.THEME_ORDER = { "class", "blizzard", "dark", "green" }

-- Bar texture: only our own flat one (WHITE8X8), registered with LibSharedMedia. No third-party
-- textures (unclear licenses, CurseForge moderation).
ns.DEFAULT_TEXTURE = "MeredanUI Flat"
local STATUSBARS = {
    ["MeredanUI Flat"] = WHITE,
}
for name, file in pairs(STATUSBARS) do
    local path = file == WHITE and WHITE or "Interface\\AddOns\\MeredanUI\\Media\\Statusbar\\" .. file
    STATUSBARS[name] = path
    if LSM then LSM:Register(LSM.MediaType.STATUSBAR, name, path) end
end
ns.DEFAULT_TEXTURE_PATH = STATUSBARS[ns.DEFAULT_TEXTURE]

-- mUI fonts: based on Blue Highway (Raymond Larabie, CC0, renamed). Names/headings "mUI Bold",
-- body text (chat, tooltips) "mUI Text" with +1% letter spacing, everything else "mUI".
-- Also registered with LibSharedMedia for other addons.
ns.DEFAULT_FONT_NAME = "mUI"
ns.MEDIA = "Interface\\AddOns\\MeredanUI\\Media\\"
ns.DEFAULT_FONT = ns.MEDIA .. "Fonts\\mUI.ttf"
ns.TEXT_FONT = ns.MEDIA .. "Fonts\\mUI-Text.ttf"
ns.BOLD_FONT = ns.MEDIA .. "Fonts\\mUI-Bold.ttf"
ns.DISPLAY_FONT = ns.MEDIA .. "Cinzel-Bold.ttf" -- display font: logo, large headings (capitals style only)
if LSM then
    LSM:Register(LSM.MediaType.FONT, "mUI", ns.DEFAULT_FONT)
    LSM:Register(LSM.MediaType.FONT, "mUI Text", ns.TEXT_FONT)
    LSM:Register(LSM.MediaType.FONT, "mUI Bold", ns.BOLD_FONT)
end

-- Border: a thin bronze line (rune look). Debuffs tint it by dispel type (then 2px).
ns.BORDER_PIXELS = 1
local BORDER_COLOR = { 0.5, 0.4, 0.24, 1 }
ns.GOLD_BORDER = { 0.5, 0.4, 0.24, 1 }
ns.BORDER_COLOR = BORDER_COLOR

-- Everything using theme, font or texture, so changes apply immediately.
local registry = { texts = {}, bars = {}, panels = {} }

-- Background opacity levels (windows, tooltips, unit frames ...); unlisted = theme value
local PANEL_OPACITY = { solid = 1, light = 0.75 }

-- Copy saved settings (theme, opacity) into STYLE.
function ns.ApplySettings()
    local db = ns.db
    local theme = ns.THEMES[db.theme] or ns.THEMES.class
    -- Background opacity: "normal" = theme value
    local alpha = PANEL_OPACITY[db.panelOpacity] or theme.panelColor[4]
    local c = theme.panelColor
    STYLE.panelColor = { c[1], c[2], c[3], alpha }
    STYLE.classHealth = theme.classHealth
    STYLE.emptyColor = theme.emptyColor
    STYLE.darkHealth = theme.darkHealth
    STYLE.healthEmpty = theme.healthEmpty
    STYLE.powerClassColor = theme.powerClassColor
    STYLE.blizzardPower = theme.blizzardPower
    ns.HEALTH_COLOR = theme.healthColor
    -- Border colour: in place, borders take it when they are created (theme switch: reload)
    local b = theme.borderColor or ns.GOLD_BORDER
    for i = 1, 4 do ns.BORDER_COLOR[i] = b[i] end

    -- Font and texture are fixed
    STYLE.font = ns.DEFAULT_FONT
    STYLE.textFont = ns.TEXT_FONT
    STYLE.boldFont = ns.BOLD_FONT
    STYLE.barTexture = ns.DEFAULT_TEXTURE_PATH
end

-- Apply changed settings to all existing elements at once. oUF then recomputes bar
-- colors (ns.OnStyleRefreshed in UnitFrames/UnitFrames.lua).
function ns.RefreshStyle()
    ns.ApplySettings()
    for text, font in pairs(registry.texts) do text:SetFont(ns.FontFor(font[3]), ns.FontPx(font[1]), font[2]) end
    for _, bg in ipairs(registry.panels) do bg:SetColorTexture(unpack(STYLE.panelColor)) end
    for _, bar in ipairs(registry.bars) do
        bar:SetStatusBarTexture(STYLE.barTexture)
        bar.bg:SetTexture(STYLE.barTexture)
        if bar.baseColor then bar:SetStatusBarColor(unpack(bar.baseColor)) end
        if bar.panelBackground then
            local r, g, b = unpack(STYLE.panelColor)
            bar.bg:SetVertexColor(r, g, b, 1)
        elseif bar.PostUpdateColor or bar.followsTheme then
            ns.ColorBarBackground(bar)
        end
    end
    if ns.OnStyleRefreshed then ns.OnStyleRefreshed() end
end

-- Size of one physical screen pixel in UI units. Compute borders and gaps in it,
-- otherwise WoW rounds them to 1 or 2 pixels depending on position.
function ns.PixelSize()
    return PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
end

-- Minimum distance of all elements to the screen edge (exception: the thin info bar
-- below the action bars).
ns.SCREEN_MARGIN = 25

-- Named layout elements (bar1 ... bar5, minimap, questlog, classpower ...) so modules can
-- align to each other. No frame moving: positions come only from the layout.
ns.layoutFrames = {}

-- Place a frame relative to screen center, anchored BOTTOMLEFT and rounded to whole pixels:
-- the center can sit on a half pixel, where 1px lines would render 0 or 2px thick.
function ns.PlaceFromCenter(frame, point, x, y)
    local px = ns.PixelSize()
    local cx, cy = UIParent:GetCenter()
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, "BOTTOMLEFT",
        math.floor((cx + x) / px + 0.5) * px, math.floor((cy + y) / px + 0.5) * px)
end

-- Round to whole screen pixels (at least 1 pixel).
function ns.Snap(value)
    local px = ns.PixelSize()
    return math.max(math.floor(value / px + 0.5), 1) * px
end

-- Visibility setting (progress bars; action bars use secure state drivers):
-- "always", "mouseover", "combat", "nocombat", "hidden". Legacy true/false
-- means "always"/"hidden".
function ns.VisibilityMode(value)
    if value == true or value == nil then return "always" end
    if value == false then return "hidden" end
    if value == "combat" or value == "nocombat" then return "always" end -- legacy combat variants
    return value
end

-- Does the bar take up space? (mouseover counts, otherwise it couldn't be found)
function ns.ShownByMode(value)
    local mode = ns.VisibilityMode(value)
    return mode ~= "hidden"
end

-- Own overlay above a Blizzard button whose art is hidden via alpha 0 (micro menu, minimap
-- buttons). Not parented to the button (it would inherit alpha 0) but to our own layer under
-- UIParent, so it hides with the whole UI (AFK screen, RP mode) while following the button's
-- visibility.
local overlayRoot
function ns.CreateButtonOverlay(button)
    if not overlayRoot then
        overlayRoot = CreateFrame("Frame", nil, UIParent)
        overlayRoot:SetAllPoints()
    end
    local overlay = CreateFrame("Frame", nil, overlayRoot)
    overlay:SetFrameStrata(button:GetFrameStrata())
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)
    local function Follow()
        overlay:SetScale(button:GetEffectiveScale() / UIParent:GetEffectiveScale())
        overlay:SetShown(button:IsVisible())
    end
    button:HookScript("OnShow", Follow)
    button:HookScript("OnHide", Follow)
    Follow()
    return overlay
end

-- Mouseover fading for simple frames: frame.muiMouseover = true -> alpha 0 until hovered
local mouseoverFrames = {}
function ns.RegisterMouseover(frame)
    mouseoverFrames[frame] = true
end
-- Mouse over frame - but not if another window in front has the mouse (e.g. the bag
-- window over the addon bar); IsMouseOver only checks the area.
local function Hovered(frame)
    if not (frame:IsVisible() and frame:IsMouseOver(4, -4, -4, 4)) then return false end
    local focus = GetMouseFoci()[1]
    if not focus or focus == WorldFrame then return true end -- gap between buttons
    while focus do
        if focus == frame then return true end
        if focus:IsForbidden() then return false end -- forbidden: not ours
        focus = focus:GetParent()
    end
    return false
end
C_Timer.NewTicker(0.1, function()
    for frame in pairs(mouseoverFrames) do
        if frame.muiMouseover then
            local alpha = Hovered(frame) and 1 or 0
            if frame:GetAlpha() ~= alpha then frame:SetAlpha(alpha) end
        elseif frame:GetAlpha() < 1 then
            frame:SetAlpha(1)
        end
    end
end)

-- Main action bar metrics in one place, since the class bar matches them
ns.MAIN_BAR = { size = 42, cols = 6, gapPixels = 6 } -- 6px gap = 4px visible (borders sit outside)

-- Main bar width (excluding the outer borders) - also used for the class bar
function ns.MainBarWidth()
    local bar = ns.MAIN_BAR
    return bar.cols * ns.Snap(bar.size) + (bar.cols - 1) * bar.gapPixels * ns.PixelSize()
end

-- Border of four edges around a region, thickness pixels. inside = true draws it on the
-- inner edge (e.g. for tightly packed icons), otherwise outside.
-- Edges are white textures with vertex color so Blizzard can recolor them (dispel type).
-- Returns the four edges.
function ns.AddBorder(region, inside, thickness)
    local px = ns.PixelSize()
    thickness = thickness or ns.BORDER_PIXELS
    local inner = inside and -thickness or 0
    local i, o = inner * px, (inner + thickness) * px
    local layer = inside and "OVERLAY" or "BORDER"
    local function Edge()
        local tex = region:CreateTexture(nil, layer)
        tex:SetTexture(WHITE)
        tex:SetVertexColor(unpack(BORDER_COLOR))
        -- Off the pixel grid, WoW rounds 1px edges to 0 at times (missing edges); disabling
        -- snapping keeps them visible
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        return tex
    end
    local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
    top:SetPoint("TOPLEFT", region, "TOPLEFT", -o, o)
    top:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", o, i)
    bottom:SetPoint("TOPLEFT", region, "BOTTOMLEFT", -o, -i)
    bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", o, -o)
    left:SetPoint("TOPLEFT", region, "TOPLEFT", -o, i)
    left:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", -i, -i)
    right:SetPoint("TOPLEFT", region, "TOPRIGHT", i, i)
    right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", o, -i)
    return { top, bottom, left, right }
end

-- Dark panel with 1px border behind a region.
function ns.CreateBackground(region)
    local bg = region:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(STYLE.panelColor))
    registry.panels[#registry.panels + 1] = bg
    ns.AddBorder(region)
    return bg
end

-- Rune look (v0.5) for windows: soft shadow instead of a black outline, a thin bronze line inset
-- from the edge and accent corner brackets. Call after the background (UI.Box with noBorder).
-- opts.small: menus, tooltips, dialogs (tighter inset and corners).
ns.BRONZE = { 0.72, 0.59, 0.36 }
ns.RUNE_BG = { 0.086, 0.075, 0.059 } -- window background (themes keep it, "Dark" goes near-black)
ns.SHADOW_TEXTURE = ns.MEDIA .. "Shadow"
function ns.RuneFrame(frame, opts)
    local small = opts and opts.small
    local px = ns.PixelSize()
    local inset, corner, spread = small and 3 or 5, small and 10 or 14, small and 10 or 16

    local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetTexture(ns.SHADOW_TEXTURE)
    shadow:SetTextureSliceMargins(24, 24, 24, 24)
    if Enum.UITextureSliceMode then shadow:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched) end
    shadow:SetPoint("TOPLEFT", -spread, spread)
    shadow:SetPoint("BOTTOMRIGHT", spread, -spread)

    local function Line(layer, r, g, b, a)
        local tex = frame:CreateTexture(nil, layer)
        tex:SetTexture(WHITE)
        tex:SetVertexColor(r, g, b, a)
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        return tex
    end
    -- inner bronze line
    local br, bg, bb = unpack(ns.BRONZE)
    local lines = {}
    for i = 1, 4 do lines[i] = Line("BORDER", br, bg, bb, 0.4) end
    lines[1]:SetPoint("TOPLEFT", inset, -inset)
    lines[1]:SetPoint("TOPRIGHT", -inset, -inset)
    lines[1]:SetHeight(px)
    lines[2]:SetPoint("BOTTOMLEFT", inset, inset)
    lines[2]:SetPoint("BOTTOMRIGHT", -inset, inset)
    lines[2]:SetHeight(px)
    lines[3]:SetPoint("TOPLEFT", inset, -inset)
    lines[3]:SetPoint("BOTTOMLEFT", inset, inset)
    lines[3]:SetWidth(px)
    lines[4]:SetPoint("TOPRIGHT", -inset, -inset)
    lines[4]:SetPoint("BOTTOMRIGHT", -inset, inset)
    lines[4]:SetWidth(px)

    -- accent corner brackets: two bars per corner, flush with the outer edge
    local ar, ag, ab = unpack(ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 })
    local thick = 2 * px
    local corners = {}
    for _, c in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
        local point = c[1]
        local h = Line("OVERLAY", ar, ag, ab, 1)
        h:SetPoint(point)
        h:SetSize(corner, thick)
        local v = Line("OVERLAY", ar, ag, ab, 1)
        v:SetPoint(point)
        v:SetSize(thick, corner)
        corners[#corners + 1], corners[#corners + 2] = h, v
    end
    local parts = { shadow = shadow, lines = lines, corners = corners }
    function parts:SetShown(shown)
        shadow:SetShown(shown)
        for _, tex in ipairs(lines) do tex:SetShown(shown) end
        for _, tex in ipairs(corners) do tex:SetShown(shown) end
    end
    return parts
end

-- Bars glide to new values (Blizzard's built-in interpolation - works with secret values);
-- oUF elements read .smoothing. On unit change they jump instantly (SnapBars).
ns.SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut

-- New target / nameplate: don't glide from the previous unit's value
local function SnapBars(frame)
    for _, key in ipairs({ "Health", "Power", "AdditionalPower", "Stagger" }) do
        local bar = frame[key]
        if bar and bar.SetToTargetValue then bar:SetToTargetValue() end
    end
end

function ns.SnapBarsOnUnitChange(frame)
    hooksecurefunc(frame, "UpdateAllElements", SnapBars)
end

-- Subtle highlight over region while the mouse is over frame (unit and group frames).
function ns.AddHoverHighlight(frame, region, alpha)
    local highlight = region:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, alpha or 0.06)
    highlight:Hide()
    frame:HookScript("OnEnter", function() highlight:Show() end)
    frame:HookScript("OnLeave", function() highlight:Hide() end)
    return highlight
end

function ns.CreateBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height)
    bar.smoothing = ns.SMOOTH
    bar:SetStatusBarTexture(STYLE.barTexture)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(STYLE.barTexture)
    bg:SetVertexColor(0.1, 0.1, 0.1)
    bar.bg = bg
    bar.PostUpdateColor = ns.ColorBarBackground
    registry.bars[#registry.bars + 1] = bar
    return bar
end

-- oUF callback, empty bar part: neutral (theme) or darkened bar color.
-- Read the color from the bar itself - also covers special resources oUF sets
-- without a color object.
function ns.ColorBarBackground(bar)
    if STYLE.darkHealth and bar.isHealth then
        bar:SetStatusBarColor(unpack(STYLE.darkHealth))
        bar.bg:SetVertexColor(unpack(STYLE.healthEmpty))
        return
    end
    if STYLE.emptyColor then
        bar.bg:SetVertexColor(unpack(STYLE.emptyColor))
        return
    end
    local r, g, b = bar:GetStatusBarColor()
    if not ns.Readable(r) then return end
    local m = STYLE.bgMultiplier
    bar.bg:SetVertexColor(r * m, g * m, b * m)
end

-- oUF callback for the power bar: class color for players in the dark theme.
function ns.ColorPowerBar(bar, unit)
    if STYLE.powerClassColor and unit then
        local isPlayer = UnitIsPlayer(unit)
        if ns.Readable(isPlayer) and isPlayer then
            local _, class = UnitClass(unit)
            local color = ns.Readable(class) and ns.oUF.colors.class[class]
            if color then bar:SetStatusBarColor(color:GetRGB()) end
        end
    end
    ns.ColorBarBackground(bar)
end

-- Shorten long names: leading words to their initial ("S. D. d. Elder"), the last word stays.
-- Measures the real text width in the FontString's font, so it works for any language.
-- Without spaces (e.g. Chinese) or if it still doesn't fit, WoW truncates with "...".
-- Secret names stay as they are.
local UTF8_CHAR = "^[%z\1-\127\194-\244][\128-\191]*"
local nameProbe
local shortNames, shortCount = {}, 0
local SHORT_MAX = 500 -- nameplates bring new names all the time: start over at the cap

-- maxWidth optional: nameplates must not be measured, so the width is passed in.
function ns.ShortenName(name, fontString, maxWidth)
    if not ns.Readable(name) or name == "" then return name end
    -- If the field already held a secret name, its width is secret too: do nothing
    maxWidth = maxWidth or fontString:GetWidth()
    if not ns.Readable(maxWidth) or maxWidth <= 1 then return name end
    local font, size, flags = fontString:GetFont()
    if not font then return name end
    local key = ("%s|%s|%d|%s|%d"):format(name, font, size, flags or "", maxWidth)
    if shortNames[key] then return shortNames[key] end

    nameProbe = nameProbe or UIParent:CreateFontString(nil, "BACKGROUND")
    nameProbe:Hide()
    nameProbe:SetFont(font, size, flags)
    local function Fits(text)
        nameProbe:SetText(text)
        return nameProbe:GetUnboundedStringWidth() <= maxWidth
    end

    local result = name
    if not Fits(name) then
        local words = {}
        for word in name:gmatch("%S+") do words[#words + 1] = word end
        for i = 1, #words - 1 do
            words[i] = (words[i]:match(UTF8_CHAR) or words[i]) .. "."
            result = table.concat(words, " ")
            if Fits(result) then break end
        end
    end
    shortCount = shortCount + 1
    if shortCount > SHORT_MAX then
        wipe(shortNames)
        shortCount = 1
    end
    shortNames[key] = result
    return result
end

-- Empty slot background (action bars, bags): Blizzard's slot art, cropped at the edges
-- (rounded corners/frame) to fit our square border. The art is semi-transparent,
-- so an opaque dark base goes underneath.
local SLOT_ATLAS = "ui-hud-actionbar-iconframe-slot"
local SLOT_CROP = 0.15 -- fraction cropped on each side
local SLOT_ALPHA = 0.4 -- just a hint, the black should dominate

function ns.AddSlotBackground(frame)
    local base = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    base:SetAllPoints()
    base:SetColorTexture(0.04, 0.04, 0.05, 1)
    local slot = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    slot:SetAllPoints()
    slot:SetAtlas(SLOT_ATLAS)
    local ulx, uly, _, lly, urx = slot:GetTexCoord()
    local w, h = urx - ulx, lly - uly
    slot:SetTexCoord(ulx + w * SLOT_CROP, urx - w * SLOT_CROP, uly + h * SLOT_CROP, lly - h * SLOT_CROP)
    slot:SetAlpha(SLOT_ALPHA)
    return base, slot
end

-- Font face per role: "bold" (names, headings), "text" (body text), otherwise mUI.
function ns.FontFor(role)
    if role == "bold" then return STYLE.boldFont or ns.BOLD_FONT end
    if role == "text" then return STYLE.textFont or ns.TEXT_FONT end
    return STYLE.font
end

-- Font size: small/medium/large scales all mUI texts proportionally (headings stay larger than
-- body text). Floor: no text below 10 physical pixels - WoW font sizes are UI units, so a
-- "10" would be ~9px on 1080p.
ns.FONT_SCALES = { small = 0.9, medium = 1, large = 1.12 }
local MIN_FONT_PIXELS = 10
function ns.FontPx(size)
    local factor = ns.FONT_SCALES[ns.db and ns.db.fontSize or "medium"] or 1
    local value = math.max(size * factor, MIN_FONT_PIXELS * ns.PixelSize())
    return math.floor(value * 2 + 0.5) / 2 -- half steps
end

function ns.SetFont(text, size, flags, role)
    registry.texts[text] = { size, flags or "", role }
    text:SetFont(ns.FontFor(role), ns.FontPx(size), flags or "")
end

function ns.CreateText(parent, size, justify, flags, role)
    local text = parent:CreateFontString(nil, "OVERLAY")
    ns.SetFont(text, size or STYLE.fontSize, flags, role)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

-- Compact time left: seconds without unit (59), above that 2m or 1h.
-- The time is a secret in combat, so a Blizzard formatter does the formatting, not Lua.
local function CreateDurationFormatter()
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local UP = Enum.NumericRuleFormatRounding.Up
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    ---@diagnostic disable-next-line: undefined-field -- 12.1 API, missing from annotations
    formatter:SetBreakpoints({
        { threshold = 0, step = 1, rounding = UP, format = "%.0f" },
        { threshold = 90, format = "%.0fm", components = { { div = 60, step = 1, rounding = UP } } },
        { threshold = 5400, format = "%.0fh", components = { { div = 3600, step = 1, rounding = UP } } },
    })
    return formatter
end
ns.DurationFormatter = CreateDurationFormatter()

-- Aura border colors by dispel type; "None" = black like the normal border.
local function DispelBorderColors(colors)
    local map = {}
    for name, color in pairs(colors.dispel) do map[name] = color end
    map.None = CreateColor(unpack(BORDER_COLOR))
    return map
end

-- oUF callback for new aura buttons: 1px border inside the icon.
-- options.dispelBand: "harmful" or "helpful" - the border becomes 2px and Blizzard
-- tints it by dispel type (magic blue, poison green ...). The type is a secret in combat,
-- so Blizzard does the coloring, not us.
-- ("preview" in test mode: thickness only, test mode sets the color.)
-- options.desaturate: gray icon (e.g. other players' debuffs on the target).
function ns.StyleAuraButton(element, button, options)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon:SetDesaturated(options and options.desaturate or false)

    local dispelBand = options and options.dispelBand
    local borderPixels = dispelBand and 2 or ns.BORDER_PIXELS
    local border = ns.AddBorder(button, true, borderPixels)
    button.FrameBorder = border

    if dispelBand and button.AddDispelTypeTexture then
        element.dispelBorderColors = element.dispelBorderColors or DispelBorderColors(element.__owner.colors)
        for _, edge in ipairs(border) do
            button:AddDispelTypeTexture(edge, {
                style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                showWhenHarmful = dispelBand == "harmful",
                showWhenHelpful = dispelBand == "helpful",
                showWithoutDispelType = dispelBand == "harmful",
                customDispelColorMap = element.dispelBorderColors,
            })
        end
    end

    -- Swipe darkens over time instead of starting dark; only our text shows the time left.
    -- It stays inside the border.
    local cooldown = button.Cooldown
    if cooldown then
        local inset = borderPixels * ns.PixelSize()
        cooldown:ClearAllPoints()
        cooldown:SetPoint("TOPLEFT", inset, -inset)
        cooldown:SetPoint("BOTTOMRIGHT", -inset, inset)
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetReverse(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetSwipeColor(0, 0, 0, 0.6)
    end

    if button.Time then
        button.Time:ClearAllPoints()
        button.Time:SetPoint("CENTER", button, "CENTER", 0, 0)
        ns.SetFont(button.Time, STYLE.fontSize + 1, "OUTLINE")
    end
    if button.Count then
        button.Count:ClearAllPoints()
        button.Count:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        ns.SetFont(button.Count, STYLE.fontSize - 2, "OUTLINE")
    end
end

-- Class resource (combo points, holy power ...) as a row of equal-width segments.
local CHARGED_COLOR = { 0.35, 0.75, 1 } -- charged combo points

-- Own class resource colors where Blizzard's don't fit (oUF.colors.power[token]).
-- Reputation colors per standing (1 Hated ... 8 Exalted) in the Surf palette:
-- red -> orange -> sand -> greens, Exalted in mUI green.
-- Never modify Blizzard's FACTION_BAR_COLORS (changing a global table = taint).
local function Hex(hex) return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 } end
ns.REP_COLORS = {
    [1] = Hex("b8564e"), [2] = Hex("c66a62"), [3] = Hex("d39a6a"), [4] = Hex("dcc98a"),
    [5] = Hex("9cc27e"), [6] = Hex("7fbf8e"), [7] = Hex("6fb8a6"), [8] = Hex("8ecbb4"),
}
function ns.RepColor(reaction)
    local color = ns.REP_COLORS[reaction] or ns.REP_COLORS[8]
    return color[1], color[2], color[3]
end

-- Power colors in the Surf palette: pastels matching Surf Green instead of Blizzard's bright tones.
ns.POWER_COLORS = {
    ARCANE_CHARGES = { 0.64, 0.42, 0.98 },          -- arcane charges: spell purple instead of Blizzard blue
    MANA = { 111 / 255, 143 / 255, 207 / 255 },     -- #6F8FCF
    RAGE = { 198 / 255, 106 / 255, 98 / 255 },      -- #C66A62
    ENERGY = { 220 / 255, 201 / 255, 138 / 255 },   -- #DCC98A
    FOCUS = { 211 / 255, 154 / 255, 106 / 255 },    -- #D39A6A
}

-- Combo points graded yellow > orange > red, hotter as they fill.
local COMBO_GRADIENT = {
    { 1, 0.85, 0.2 },
    { 1, 0.5, 0.1 },
    { 0.9, 0.15, 0.1 },
}

-- Color for segment index of max (linear blend between stops).
function ns.ComboPointColor(index, max)
    local pos = (max > 1) and (index - 1) / (max - 1) * (#COMBO_GRADIENT - 1) + 1 or 1
    local lower = math.min(math.floor(pos), #COMBO_GRADIENT - 1)
    local f = pos - lower
    local a, b = COMBO_GRADIENT[lower], COMBO_GRADIENT[lower + 1]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- Distribute segments over the current count in whole pixels. With element.width the bar has a
-- fixed width (= main action bar, same for all classes) and boxes adapt. The rounding
-- remainder goes 1px per box, alternating from the outside in, so the outer edges line up
-- exactly with the action bar.
function ns.LayoutClassPower(element, max)
    local px = ns.PixelSize()
    local strip = element.strip
    local gapPx = element.gapPixels
    if element.width then strip:SetWidth(element.width) end
    local totalPx = math.floor(strip:GetWidth() / px + 0.5)
    local segmentPx = math.floor((totalPx - (max - 1) * gapPx) / max)
    local restPx = totalPx - max * segmentPx - (max - 1) * gapPx

    local widths = {}
    for i = 1, max do widths[i] = segmentPx end
    if element.boxes then
        local left, right = 1, max
        for n = 1, restPx do
            if n % 2 == 1 then
                widths[left] = widths[left] + 1
                left = left + 1
            else
                widths[right] = widths[right] + 1
                right = right - 1
            end
        end
    else
        widths[max] = widths[max] + restPx -- no boxes: remainder goes to the last segment
    end

    local x = 0
    for i = 1, max do
        local bar = element[i]
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", strip, "TOPLEFT", x * px, 0)
        bar:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x * px, 0)
        bar:SetWidth(widths[i] * px)
        x = x + widths[i] + gapPx
    end
end

local function ClassPower_PostUpdateColor(element, color)
    element.color = color
end

local function ClassPower_PostUpdate(element, _, max, _, hasMaxChanged, powerType, ...)
    if hasMaxChanged and max and max > 0 then ns.LayoutClassPower(element, max) end

    local color = element.color
    if powerType == "COMBO_POINTS" and max and max > 0 then
        for i = 1, max do element[i]:SetStatusBarColor(ns.ComboPointColor(i, max)) end
    elseif color then
        for i = 1, #element do element[i]:SetStatusBarColor(color:GetRGB()) end
    end
    for n = 1, select("#", ...) do
        local bar = element[select(n, ...)]
        if bar then bar:SetStatusBarColor(unpack(CHARGED_COLOR)) end
    end
    for i = 1, #element do ns.ColorBarBackground(element[i]) end
end

-- Show the bar only while the class has a class resource.
local function ClassPower_PostVisibility(element, isVisible)
    element.strip:SetShown(isVisible)
end

-- Class resource (position set by the layout via element.strip).
--   without width: one bordered bar, segments separated by a thin dark line
--   with width:    individual boxes with their own 1px border, bar always width wide
function ns.CreateClassPower(parent, height, width)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(height)
    if not width then ns.CreateBackground(strip) end

    local element = { strip = strip, width = width, boxes = width ~= nil, gapPixels = width and 4 or 1 }
    -- Set width immediately: without it the strip has no position, and everything anchored
    -- to it (stagger, center power) would be invisible.
    if width then strip:SetWidth(width) end
    for i = 1, 10 do
        local bar = ns.CreateBar(strip, height)
        bar.PostUpdateColor = nil -- color comes from ClassPower_PostUpdate
        bar.followsTheme = true
        if width then ns.AddBorder(bar) end
        element[i] = bar
    end
    element.PostUpdateColor = ClassPower_PostUpdateColor
    element.PostUpdate = ClassPower_PostUpdate
    element.PostVisibility = ClassPower_PostVisibility
    return element
end

-- Monk (Brewmaster): stagger as a bar in place of the class bar, fraction of max health;
-- green/yellow/red like Blizzard (from 30% / 60%).
local STAGGER_COLORS = { { 0.52, 1, 0.52 }, { 1, 0.98, 0.72 }, { 1, 0.42, 0.42 } }
ns.STAGGER_COLORS = STAGGER_COLORS

function ns.StaggerColor(percent)
    if percent >= 0.6 then return STAGGER_COLORS[3] end
    if percent > 0.3 then return STAGGER_COLORS[2] end
    return STAGGER_COLORS[1]
end

-- Replaces oUF's color logic: uses readable values only (secret -> color unchanged).
local function Stagger_UpdateColor(frame)
    local element = frame.Stagger
    local cur, max = element.cur, element.max
    if not (ns.Readable(cur) and ns.Readable(max)) or max <= 0 then return end
    element:SetStatusBarColor(unpack(ns.StaggerColor(cur / max)))
    ns.ColorBarBackground(element)
end

local function Stagger_PostUpdate(element, cur, max)
    element.cur, element.max = cur, max
    element.Text:SetText(AbbreviateNumbers(cur)) -- secret-safe
end

function ns.CreateStagger(parent, height, width)
    local bar = ns.CreateBar(parent, height)
    bar:SetWidth(width)
    bar.followsTheme = true
    ns.AddBorder(bar)
    bar.Text = ns.CreateText(bar, 10, "CENTER", "OUTLINE")
    bar.Text:SetPoint("CENTER", 0, 0)
    bar.UpdateColor = Stagger_UpdateColor
    bar.PostUpdate = Stagger_PostUpdate
    bar.PostUpdateColor = nil
    return bar
end

-- Center power (Balance, Shadow, Elemental): the spec resource moves to the class bar slot and
-- the player frame's power bar shows mana. Based on spec - also in caster form where the
-- displayed resource is mana - but not in cat/bear (energy/rage as usual).
local CENTER_POWER = {
    [102] = Enum.PowerType.LunarPower, -- Balance druid: Astral Power
    [258] = Enum.PowerType.Insanity,   -- Shadow priest: Insanity
    [262] = Enum.PowerType.Maelstrom,  -- Elemental shaman: Maelstrom
}
local centerPowerType -- resource of the current spec or nil

local function UpdateCenterPowerType()
    local index = C_SpecializationInfo.GetSpecialization()
    local specID = index and C_SpecializationInfo.GetSpecializationInfo(index)
    centerPowerType = specID and CENTER_POWER[specID]
end

-- Center resource while the displayed resource is mana or the spec resource.
function ns.CenterPowerType(unit)
    if unit ~= "player" or not centerPowerType then return end
    local displayed = UnitPowerType("player")
    if not ns.Readable(displayed) then return end
    if displayed == Enum.PowerType.Mana or displayed == centerPowerType then return centerPowerType end
end

function ns.UsesCenterPower(unit)
    return ns.CenterPowerType(unit) ~= nil
end

-- Bordered bar with value text; updates itself via events.
function ns.CreateCenterPower(parent, height, width)
    local bar = ns.CreateBar(parent, height)
    bar:SetWidth(width)
    bar.followsTheme = true
    ns.AddBorder(bar)
    bar.Text = ns.CreateText(bar, 10, "CENTER", "OUTLINE")
    bar.Text:SetPoint("CENTER", 0, 0)
    bar:Hide()

    function bar:Update(event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" or not event then
            UpdateCenterPowerType()
        end
        if self.testing then return end
        local powerType = ns.CenterPowerType("player")
        self:SetShown(powerType ~= nil)
        if not powerType then return end
        local color = ns.oUF.colors.power[powerType]
        if color and color.GetRGB then self:SetStatusBarColor(color:GetRGB()) end
        ns.ColorBarBackground(self)
        self:SetMinMaxValues(0, UnitPowerMax("player", powerType))
        self:SetValue(UnitPower("player", powerType), ns.SMOOTH)
        self.Text:SetText(AbbreviateNumbers(UnitPower("player", powerType))) -- secret-safe
    end

    bar:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    bar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    bar:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    bar:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    bar:RegisterEvent("PLAYER_ENTERING_WORLD")
    bar:SetScript("OnEvent", bar.Update)
    bar:Update()
    return bar
end

-- Death Knight runes: 6 boxes like the class bar (position via element.strip).
-- Fill while recharging; color by spec (Blood/Frost/Unholy).
function ns.CreateRunes(parent, height, width)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(height)
    local element = { strip = strip, width = width, boxes = true, gapPixels = 4 }
    for i = 1, 6 do
        local bar = ns.CreateBar(strip, height)
        bar.PostUpdateColor = nil -- oUF colors all runes, then Runes.PostUpdateColor
        bar.followsTheme = true
        ns.AddBorder(bar)
        element[i] = bar
    end
    element.colorSpec = true
    element.sortOrder = "asc" -- ready runes first
    element.PostUpdateColor = function(runes)
        for i = 1, #runes do ns.ColorBarBackground(runes[i]) end
    end
    ns.LayoutClassPower(element, 6)
    return element
end

-- Status icon (Media/Icons/<name>.tga, white) tinted in color, with a dark drop shadow
-- for readability on light bars. The shadow follows the icon's Show/Hide.
-- Icons: Material Design Icons / Material Symbols, Apache 2.0 (Media/Icons/CREDITS.txt).
function ns.CreateStatusIcon(parent, name, size, color)
    local px = ns.PixelSize()
    local icon = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetSize(size, size)
    icon:SetTexture(ns.MEDIA .. "Icons\\" .. name)
    icon:SetVertexColor(unpack(color))

    local shadow = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    shadow:SetTexture(ns.MEDIA .. "Icons\\" .. name)
    shadow:SetVertexColor(0, 0, 0, 0.9)
    shadow:SetPoint("TOPLEFT", icon, "TOPLEFT", -px, px)
    shadow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2 * px, -2 * px)
    hooksecurefunc(icon, "Show", function() shadow:Show() end)
    hooksecurefunc(icon, "Hide", function() shadow:Hide() end)
    hooksecurefunc(icon, "SetShown", function(_, shown) shadow:SetShown(shown) end)
    shadow:Hide()
    icon.shadow = shadow
    return icon
end

-- Change a status icon's texture (shadow follows), e.g. ready check.
function ns.SetStatusIcon(icon, name)
    icon:SetTexture(ns.MEDIA .. "Icons\\" .. name)
    if icon.shadow then icon.shadow:SetTexture(ns.MEDIA .. "Icons\\" .. name) end
end

-- Row of status icons centered on anchor: visible icons close ranks,
-- whichever are currently active.
function ns.CreateStatusRow(anchor, size, spacing)
    local row = { icons = {} }
    function row.Layout()
        local shown = {}
        for _, icon in ipairs(row.icons) do
            if icon:IsShown() then shown[#shown + 1] = icon end
        end
        local total = #shown * size + math.max(#shown - 1, 0) * spacing
        for i, icon in ipairs(shown) do
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", anchor, "CENTER", -total / 2 + size / 2 + (i - 1) * (size + spacing), 0)
        end
    end
    function row.Add(icon)
        row.icons[#row.icons + 1] = icon
        icon:SetPoint("CENTER", anchor, "CENTER")
        hooksecurefunc(icon, "Show", row.Layout)
        hooksecurefunc(icon, "Hide", row.Layout)
        hooksecurefunc(icon, "SetShown", row.Layout)
        icon:Hide()
        return icon
    end
    return row
end

-- Health.PostUpdate: skull when dead, ghost in ghost form (no oUF element for this).
-- Show nothing for secret values.
function ns.UpdateDeathIcons(health, unit)
    local frame = health.__owner
    local dead, ghost = UnitIsDead(unit), UnitIsGhost(unit)
    dead = ns.Readable(dead) and dead or false
    ghost = ns.Readable(ghost) and ghost or false
    frame.DeadIcon:SetShown(dead and not ghost)
    frame.GhostIcon:SetShown(ghost)
end

-- SummonIndicator.PostUpdate: oUF sets Blizzard's texture on every update; switch back to
-- our icon, colored by status (pending / accepted / declined).
function ns.UpdateSummonIcon(icon, status)
    if not status or status == Enum.SummonStatus.None then return end
    icon:SetTexture(ns.MEDIA .. "Icons\\Summon")
    local color = ns.STYLE.summonColors[status] or ns.STYLE.summonColors[1]
    icon:SetVertexColor(unpack(color))
end

-- Castbar, visible only while casting; overlays the health bar (which provides the border).
-- Spell icon outside next to it, iconGap apart. Own casts gold; on the target turquoise =
-- interruptible, gray = not. Interruptibility is a secret in combat, so oUF fades in the
-- gray layer (.Shield) via SetAlphaFromBoolean.
-- Empowered casts (Evoker): stage boundaries as thin light lines instead of Blizzard art.
-- oUF sets the position (top/bottom of the bar), we only provide the line.
local function CreatePip(castbar)
    local pip = CreateFrame("Frame", nil, castbar)
    pip:SetWidth(2 * ns.PixelSize())
    pip:SetFrameLevel(castbar:GetFrameLevel() + 2)
    local line = pip:CreateTexture(nil, "OVERLAY")
    line:SetAllPoints()
    line:SetColorTexture(1, 1, 1, 0.85)
    return pip
end
ns.CreateCastbarPip = CreatePip

function ns.CreateCastbar(parent, height, mirrored, showInterruptible, iconGap)
    local near, far = mirrored and "RIGHT" or "LEFT", mirrored and "LEFT" or "RIGHT"
    local dir = mirrored and -1 or 1

    local castbar = ns.CreateBar(parent, height)
    castbar.smoothing = Enum.StatusBarInterpolation.Immediate -- driven by Blizzard's timer, already smooth
    castbar.PostUpdateColor = nil
    castbar:SetReverseFill(mirrored)
    castbar.baseColor = showInterruptible and STYLE.castInterruptibleColor or STYLE.castColor
    castbar:SetStatusBarColor(unpack(castbar.baseColor))
    castbar.panelBackground = true -- background in panel color
    local r, g, b = unpack(STYLE.panelColor)
    castbar.bg:SetVertexColor(r, g, b, 1)

    local fill = castbar:GetStatusBarTexture()
    if showInterruptible then
        local shield = castbar:CreateTexture(nil, "ARTWORK", nil, 1)
        shield:SetTexture(WHITE)
        shield:SetVertexColor(unpack(STYLE.castLockedColor))
        shield:SetAllPoints(fill)
        castbar.Shield = shield
    end

    local spark = castbar:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:SetTexture(WHITE)
    spark:SetVertexColor(1, 1, 1, 0.8)
    spark:SetWidth(2 * ns.PixelSize())
    spark:SetPoint("TOP", fill, "TOP" .. far)
    spark:SetPoint("BOTTOM", fill, "BOTTOM" .. far)
    castbar.Spark = spark

    -- Texts on the same baseline as health and power in the health bar (bottom, 4 units)
    local time = ns.CreateText(castbar, STYLE.fontSize + 1, far, "OUTLINE")
    time:SetPoint("BOTTOM" .. far, castbar, "BOTTOM" .. far, -5 * dir, 4)
    castbar.Time = time

    local text = ns.CreateText(castbar, STYLE.fontSize + 1, near, "OUTLINE")
    text:SetPoint("BOTTOM" .. near, castbar, "BOTTOM" .. near, 5 * dir, 4)
    text:SetPoint("BOTTOM" .. far, time, "BOTTOM" .. near, -4 * dir, 0)
    castbar.Text = text

    -- Icon outside next to the bar, as tall as the bar, own 1px border
    local iconFrame = CreateFrame("Frame", nil, castbar)
    iconFrame:SetSize(height, height)
    iconFrame:SetPoint(far, castbar, near, -(iconGap or 0) * dir, 0)
    ns.AddBorder(iconFrame)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon

    castbar.CreatePip = CreatePip
    castbar.timeToHold = 0.5 -- briefly keep interrupted casts visible
    return castbar
end

-- Heal prediction and absorb shield for unit frames (player, target, focus, bosses ...):
--   - incoming heals green right after the fill (only as far as health is missing)
--   - absorb light blue from the bar end over health - visible even at full health
--     (oUF otherwise clamps absorbs to missing health, so none would show at full health).
--     Light blue instead of white so it stands out on priest white.
-- oUF passes all values to Blizzard's bars (secret-safe).
local HEAL_PREDICTION_COLOR = { 0.3, 0.9, 0.4, 0.45 }
local ABSORB_COLOR = { 0.35, 0.75, 1, 0.6 }
-- absorbOnly: absorbs only, no heal prediction (group frames for DPS/tank)
-- split: healer - own incoming heals strong, others' fainter behind, plus heal absorb
local HEAL_OWN_COLOR, HEAL_OTHER_COLOR, HEAL_ABSORB_COLOR = { 0.35, 0.95, 0.45, 0.85 }, { 0.35, 0.8, 0.45, 0.4 }, { 0.55, 0.05, 0.08, 0.8 }
function ns.AddHealPrediction(health, mirrored, absorbOnly, split)
    local fill = health:GetStatusBarTexture()
    if split then
        local own = CreateFrame("StatusBar", nil, health)
        own:SetPoint("TOP")
        own:SetPoint("BOTTOM")
        own:SetPoint("LEFT", fill, "RIGHT")
        own:SetWidth(health:GetWidth())
        own:SetStatusBarTexture(STYLE.barTexture)
        own:SetStatusBarColor(unpack(HEAL_OWN_COLOR))
        own:SetFrameLevel(health:GetFrameLevel() + 1)
        local other = CreateFrame("StatusBar", nil, health)
        other:SetPoint("TOP")
        other:SetPoint("BOTTOM")
        other:SetPoint("LEFT", own:GetStatusBarTexture(), "RIGHT")
        other:SetWidth(health:GetWidth())
        other:SetStatusBarTexture(STYLE.barTexture)
        other:SetStatusBarColor(unpack(HEAL_OTHER_COLOR))
        other:SetFrameLevel(health:GetFrameLevel() + 1)
        health.HealingPlayer, health.HealingOther = own, other
        health.incomingHealOverflow = 1
        -- Heal absorb: dark red from the end of health inward
        local healAbsorb = CreateFrame("StatusBar", nil, health)
        healAbsorb:SetPoint("TOP")
        healAbsorb:SetPoint("BOTTOM")
        healAbsorb:SetPoint("RIGHT", fill, "RIGHT")
        healAbsorb:SetWidth(health:GetWidth())
        healAbsorb:SetReverseFill(true)
        healAbsorb:SetStatusBarTexture(WHITE)
        healAbsorb:SetStatusBarColor(unpack(HEAL_ABSORB_COLOR))
        healAbsorb:SetFrameLevel(health:GetFrameLevel() + 2)
        health.HealAbsorb = healAbsorb
    end
    if absorbOnly or split then
        local absorb = CreateFrame("StatusBar", nil, health)
        absorb:SetAllPoints(health)
        absorb:SetReverseFill(not mirrored)
        absorb:SetStatusBarTexture(WHITE)
        absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
        absorb:SetFrameLevel(health:GetFrameLevel() + 2)
        health.DamageAbsorb = absorb
        health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MaximumHealth
        return
    end
    local healing = CreateFrame("StatusBar", nil, health)
    healing:SetPoint("TOP")
    healing:SetPoint("BOTTOM")
    if mirrored then
        healing:SetPoint("RIGHT", fill, "LEFT")
    else
        healing:SetPoint("LEFT", fill, "RIGHT")
    end
    healing:SetWidth(health:GetWidth()) -- oUF adjusts the width when the bar changes
    healing:SetReverseFill(mirrored or false)
    healing:SetStatusBarTexture(STYLE.barTexture)
    healing:SetStatusBarColor(unpack(HEAL_PREDICTION_COLOR))
    healing:SetFrameLevel(health:GetFrameLevel() + 1)
    health.HealingAll = healing
    health.incomingHealOverflow = 1 -- never past the bar edge

    local absorb = CreateFrame("StatusBar", nil, health)
    absorb:SetAllPoints(health)
    absorb:SetReverseFill(not mirrored)
    absorb:SetStatusBarTexture(WHITE)
    absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
    absorb:SetFrameLevel(health:GetFrameLevel() + 2)
    health.DamageAbsorb = absorb
    health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MaximumHealth
end

-- Global cooldown (player): thin line at the bottom edge, fills inside-out during the GCD.
-- Blizzard does the math (Duration object) - we never touch secret values.
local GCD_SPELL = 61304
local gcdBars = {}

-- Is the GCD still running? Always ask Blizzard anew - a cached Duration object doesn't
-- report zero after expiring (the line would stay full). May be secret.
local function GCDOver()
    local duration = C_Spell.GetSpellCooldownDuration(GCD_SPELL)
    if not duration then return true end
    return duration:IsZero(), duration
end

local function UpdateGCD(bar)
    if ns.db.castbar == "simple" then return bar:Hide() end -- "simple" castbar: no GCD line
    local over, duration = GCDOver()
    if not duration or (not issecretvalue(over) and over) then return bar:Hide() end
    bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
    bar:SetAlphaFromBoolean(over, 0, 1)
    bar:Show()
end

function ns.CreateGCDBar(parent, mirrored)
    local px = ns.PixelSize()
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bar:SetHeight(2 * px)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(1, 1, 1, 0.75)
    bar:SetReverseFill(mirrored or false)
    -- GCD end has no event - poll briefly while visible, then hide
    local elapsedSince = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < 0.05 then return end
        elapsedSince = 0
        local over = GCDOver()
        if not issecretvalue(over) and over then return self:Hide() end
        self:SetAlphaFromBoolean(over, 0, 1) -- secret: Blizzard decides
    end)
    bar:Hide()
    gcdBars[bar] = true
    return bar
end
ns:On("SPELL_UPDATE_COOLDOWN", function()
    for bar in pairs(gcdBars) do UpdateGCD(bar) end
end)

-- Tick marks on channeled spells (player): shows when the next damage/heal tick lands,
-- so you don't cancel early. Count per spell (haste shortens intervals evenly).
local CHANNEL_TICKS = {
    [15407] = 6,   -- Mind Flay
    [391403] = 4,  -- Mind Flay: Insanity
    [47540] = 3,   -- Penance
    [64843] = 4,   -- Divine Hymn
    [234153] = 5,  -- Drain Life
    [198590] = 5,  -- Drain Soul
    [755] = 5,     -- Health Funnel
    [5143] = 5,    -- Arcane Missiles
    [205021] = 5,  -- Ray of Frost
    [12051] = 4,   -- Evocation
    [257044] = 7,  -- Rapid Fire
    [113656] = 5,  -- Fists of Fury
    [117952] = 4,  -- Crackling Jade Lightning
    [101546] = 4,  -- Spinning Crane Kick
    [115175] = 8,  -- Soothing Mist
    [740] = 4,     -- Tranquility
    [356995] = 4,  -- Disintegrate
    [198013] = 10, -- Eye Beam
}
function ns.UpdateChannelTicks(castbar, unit, spellID)
    local ticks = castbar.channelTicks
    if not ticks then return end
    for _, tick in ipairs(ticks) do tick:Hide() end
    if ns.db.castbar == "simple" or issecretvalue(spellID) or not spellID then return end
    local channel = UnitChannelInfo(unit)
    if issecretvalue(channel) or not channel then return end
    local count = CHANNEL_TICKS[spellID]
    if not count then return end
    local width = castbar:GetWidth()
    local side = castbar:GetReverseFill() and "RIGHT" or "LEFT"
    local dir = side == "LEFT" and 1 or -1
    for i = 1, count - 1 do
        local tick = ticks[i]
        if not tick then
            tick = castbar:CreateTexture(nil, "OVERLAY", nil, 1)
            tick:SetColorTexture(0, 0, 0, 0.75)
            tick:SetWidth(2 * ns.PixelSize())
            ticks[i] = tick
        end
        tick:ClearAllPoints()
        tick:SetPoint("TOP", castbar, "TOP" .. side, dir * width * i / count, 0)
        tick:SetPoint("BOTTOM", castbar, "BOTTOM" .. side, dir * width * i / count, 0)
        tick:Show()
    end
end

-- Execute line: white mark in the health bar at the threshold where your class may use its
-- execute ability. Fixed position - health itself (often secret) is never read.
-- Highest known value wins; no matching ability, no line.
local EXECUTE_SPELLS = {
    { 281001, 35 }, { 206315, 35 }, -- Massacre (Fury, Arms)
    { 343294, 35 },                 -- Soul Reaper (Death Knight)
    { 269644, 30 },                 -- Searing Touch (Fire)
    { 5308, 20 }, { 163201, 20 }, { 280735, 20 }, -- Execute
    { 53351, 20 }, { 320976, 20 },  -- Kill Shot
    { 24275, 20 },                  -- Hammer of Wrath
    { 32379, 20 },                  -- Shadow Word: Death
}
local executePercent
local executeLines = {}

local function PlaceExecuteLine(line)
    local bar = line.bar
    local show = executePercent and ns.db.executeLine ~= false
    if show and line.unit then -- unit frame: enemies only
        local attackable = UnitCanAttack("player", line.unit)
        show = not issecretvalue(attackable) and attackable or false
    end
    if not show then return line:Hide() end
    local side = bar:GetReverseFill() and "RIGHT" or "LEFT"
    local offset = (side == "LEFT" and 1 or -1) * bar:GetWidth() * executePercent / 100
    line:ClearAllPoints()
    line:SetPoint("TOP", bar, "TOP" .. side, offset, 0)
    line:SetPoint("BOTTOM", bar, "BOTTOM" .. side, offset, 0)
    line:Show()
end

function ns.UpdateExecuteLines()
    executePercent = nil
    for _, entry in ipairs(EXECUTE_SPELLS) do
        if (not executePercent or entry[2] > executePercent) and C_SpellBook.IsSpellKnownOrInSpellBook(entry[1]) then
            executePercent = entry[2]
        end
    end
    for line in pairs(executeLines) do PlaceExecuteLine(line) end
end

-- unit: only show if this unit is attackable (target frame); plates don't need it
function ns.AddExecuteLine(bar, unit)
    local line = bar:CreateTexture(nil, "OVERLAY", nil, 3)
    line:SetColorTexture(1, 1, 1, 0.8)
    line:SetWidth(2 * ns.PixelSize())
    line.bar, line.unit = bar, unit
    executeLines[line] = true
    bar:HookScript("OnSizeChanged", function() PlaceExecuteLine(line) end)
    PlaceExecuteLine(line)
    return line
end

ns:On("PLAYER_LOGIN", ns.UpdateExecuteLines)
ns:On("SPELLS_CHANGED", ns.UpdateExecuteLines)
ns:On("PLAYER_TARGET_CHANGED", function()
    for line in pairs(executeLines) do if line.unit then PlaceExecuteLine(line) end end
end)

-- Screen size or UI scale changed (other monitor, scale slider): mUI computes positions and
-- 1px borders at load, so offer a reload, like ElvUI does.
StaticPopupDialogs["MEREDANUI_RELOAD_SCALE"] = {
    text = ns.L["Screen size or UI scale changed. Reload the interface so mUI can rearrange everything?"],
    button1 = ns.L["Reload UI"],
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Placements that depend on screen size (centered, at edges): each module registers its placer
-- here; it runs immediately and again on every size/scale change (after combat if in
-- lockdown - action bars are protected).
local placers = {}
function ns.OnLayout(fn)
    placers[#placers + 1] = fn
    fn()
end
function ns.Relayout()
    if InCombatLockdown() then return ns.AfterCombat(ns.Relayout) end
    for _, fn in ipairs(placers) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end

local layoutSize, layoutPixel -- size and pixel size at the last layout pass
local function SizeKey() return ("%.0f:%.0f"):format(UIParent:GetWidth(), UIParent:GetHeight()) end
local function PixelKey() return ("%.4f"):format(ns.PixelSize()) end
ns:On("PLAYER_LOGIN", function()
    layoutSize, layoutPixel = SizeKey(), PixelKey()
end)
-- Size changed: re-layout immediately. Scale changed: also offer a reload - 1px borders are
-- snapped to whole pixels at build time and would blur otherwise.
local checkPending = false
local function CheckLayoutSize()
    if not layoutSize or checkPending then return end
    checkPending = true
    C_Timer.After(0.5, function()
        checkPending = false
        local size, pixel = SizeKey(), PixelKey()
        if size ~= layoutSize or pixel ~= layoutPixel then
            layoutSize = size
            ns.Relayout()
        end
        if pixel ~= layoutPixel then
            layoutPixel = pixel
            StaticPopup_Show("MEREDANUI_RELOAD_SCALE")
        end
    end)
end
-- UI size (like ElvUI): mUI sets the scale itself (UIParent), so Blizzard's slider has no
-- effect. The layout is built for "medium" (65%); "small" goes below Blizzard's minimum
-- (more room), "large" is the maximum where nothing overlaps on 16:9.
-- Account-wide (depends on the monitor, not the profile): MeredanUIDB.uiSize.
ns.UI_SIZES = { small = 0.58, medium = 0.65, large = 0.71 }
function ns.UIScaleValue()
    return ns.UI_SIZES[ns.root and ns.root.uiSize or "medium"] or ns.UI_SIZES.medium
end
local function ApplyUIScale()
    if InCombatLockdown() then return ns.AfterCombat(ApplyUIScale) end
    local scale = ns.UIScaleValue()
    if math.abs(UIParent:GetScale() - scale) > 0.001 then UIParent:SetScale(scale) end
end
ns.ApplyUIScale = ApplyUIScale
ns:On("ADDON_LOADED", function(_, name) if name == ADDON_NAME then ApplyUIScale() end end)
-- Blizzard resets the scale on its own changes (slider, window size) -> reapply ours
ns:On("UI_SCALE_CHANGED", ApplyUIScale)
ns:On("DISPLAY_SIZE_CHANGED", ApplyUIScale)
ns:On("UI_SCALE_CHANGED", CheckLayoutSize)
ns:On("DISPLAY_SIZE_CHANGED", CheckLayoutSize)

-- Block Blizzard's Edit Mode (mUI has fixed layouts). Blizzard's own mechanism, as in pet
-- battles: a frame in the block list makes CanEnterEditMode() false (no Esc menu button,
-- /editmode does nothing). If a taint error in Blizzard's options (IsUserOAuthed) shows up
-- with this block, remove it here.
ns:On("PLAYER_LOGIN", function()
    if EditModeManagerFrame and EditModeManagerFrame.BlockEnteringEditMode then
        EditModeManagerFrame:BlockEnteringEditMode(CreateFrame("Frame", "MeredanUIEditModeBlocker"))
    end
end)
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, CheckLayoutSize) end)


-- Item comparison like Blizzard: Shift (or "always compare") shows the equipped item alongside.
-- Call after filling the tooltip; with owner.UpdateTooltip = OnEnter function, Shift also works
-- when pressed while already hovering (GameTooltip calls it continuously).
function ns.ShowItemCompare(tooltip)
    tooltip = tooltip or GameTooltip
    if IsModifiedClick("COMPAREITEMS") or C_CVar.GetCVarBool("alwaysCompareItems") then
        if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(tooltip) end
    elseif GameTooltip_HideShoppingTooltips then
        GameTooltip_HideShoppingTooltips(tooltip)
    end
end
