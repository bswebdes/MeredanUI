-- Player buffs and debuffs top right, left of the minimap (replaces Blizzard's frame).
--
--   [B][B][B][B][B][B] | Minimap |  <- buffs, grow left, two rows; weapon enchants first
--   12m 45  3m  1h      |         |
--      [ D ][ D ][ D ]              <- debuffs, border in dispel color
--             [P][P]                <- private auras (boss mechanics), drawn by Blizzard;
--                                      replaces their anchors in the hidden Blizzard debuff frame
--
-- Built on Blizzard's AuraContainer (12.1): duration, stacks, dispel color, tooltip and
-- right-click cancel are handled by Blizzard - even with secret values. Same approach as ElvUI.
-- Size, count, time position and cancel are fixed at creation: changes apply after a reload;
-- the demo (Settings > Buffs & Debuffs) previews them immediately.
local _, ns = ...

local BUFF_ROWS, DEBUFF_ROWS = 2, 1
local SPACING = 4          -- between icons
local TIME_HEIGHT = 14     -- space for the duration below the icon
local GAP = 10             -- gap to the minimap
local GROUP_GAP = 18       -- between buffs, debuffs and private auras
local PRIVATE_COUNT = 6    -- number of anchors Blizzard creates

local hidden = CreateFrame("Frame")
hidden:Hide()

-- Fake element for ns.StyleAuraButton (only needs the oUF colors for dispel borders)
local styleElement = { __owner = { colors = ns.oUF.colors } }

local function TimeInside() return ns.db.auraTime == "inside" end
-- "Bar" mode: a thin draining bar below the icon instead of a number; color goes from
-- accent via yellow to red as time runs out
local function TimeBar() return ns.db.auraTime == "bar" end
local BAR_HEIGHT, BAR_GAP = 5, 4
local SAGE, YELLOW, RED = { 0.557, 0.796, 0.706 }, { 0.93, 0.79, 0.36 }, { 0.88, 0.36, 0.32 }
local barCurve
if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
    barCurve = C_CurveUtil.CreateColorCurve()
    barCurve:AddPoint(0, CreateColor(RED[1], RED[2], RED[3]))
    barCurve:AddPoint(0.15, CreateColor(RED[1], RED[2], RED[3]))
    barCurve:AddPoint(0.35, CreateColor(YELLOW[1], YELLOW[2], YELLOW[3]))
    barCurve:AddPoint(0.6, CreateColor(SAGE[1], SAGE[2], SAGE[3]))
    barCurve:AddPoint(1, CreateColor(SAGE[1], SAGE[2], SAGE[3]))
end
local timeBars = {} -- [bar] = aura button
local function ColorBar(bar, color) bar:SetStatusBarColor(color:GetRGB()) end -- reused: no closure per tick
-- Recolor every 0.2s from Blizzard's duration object (values may be secret: pass through only)
C_Timer.NewTicker(0.2, function()
    if not barCurve then return end
    for bar, button in pairs(timeBars) do
        -- Aura button visibility is secret - don't check it, just color all
        if button.GetAuraDuration then
            local ok, duration = pcall(button.GetAuraDuration, button)
            if ok and duration and duration.EvaluateRemainingPercent then
                local okColor, color = pcall(duration.EvaluateRemainingPercent, duration, barCurve)
                -- Color may be secret: pass through only, swallow errors (bar stays accent-colored)
                if okColor and color then pcall(ColorBar, bar, color) end
            end
        end
    end
end)

-- Container metrics - shared by the real containers and the demo
local function Metrics(size, perRow, rows)
    local iconSize, spacing = ns.Snap(size), ns.Snap(SPACING)
    local timeBelow = TimeBar() and ns.Snap(BAR_HEIGHT + BAR_GAP + 1) or (not TimeInside() and ns.Snap(TIME_HEIGHT) or 0)
    local lineSpacing = spacing + timeBelow
    local width = perRow * iconSize + (perRow - 1) * spacing
    local height = rows * iconSize + (rows - 1) * lineSpacing + timeBelow
    return iconSize, spacing, lineSpacing, width, height
end

-- Size as a step for both (buff, debuff); fixed count per row
local AURA_SIZES = { small = { 30, 34 }, medium = { 36, 40 }, large = { 42, 46 } }
local BUFFS_PER_ROW, DEBUFFS_PER_ROW = 12, 10
local function Sizes() return AURA_SIZES[ns.db.auraSize] or AURA_SIZES.medium end
local function BuffMetrics() return Metrics(Sizes()[1], BUFFS_PER_ROW, BUFF_ROWS) end
local function DebuffMetrics() return Metrics(Sizes()[2], DEBUFFS_PER_ROW, DEBUFF_ROWS) end

-- Duration below or inside the icon, stacks bottom right
local function PlaceTexts(button, time, count)
    time:ClearAllPoints()
    if TimeInside() then
        time:SetPoint("CENTER", button, "CENTER", 0, 0)
    else
        time:SetPoint("TOP", button, "BOTTOM", 0, -ns.Snap(2))
    end
    count:ClearAllPoints()
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ns.Snap(1), ns.Snap(2))
end

local function InitButton(button, size, harmful)
    button:SetSize(size, size)
    button:SetTooltipAnchorPoint("ANCHOR_BOTTOMLEFT", 0, 0)
    if not harmful then
        -- Right-click cancels the buff (Blizzard does this securely)
        button:SetCancelAuraButtons(C_CVar.GetCVarBool("ActionButtonUseKeyDown") and "RightButtonDown" or "RightButtonUp")
    end

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    button.Cooldown = cooldown
    button:SetDurationCooldown(cooldown)

    local icon = button:CreateTexture(nil, "BORDER")
    icon:SetAllPoints()
    button.Icon = icon
    button:SetIcon(icon)

    -- Texts above the cooldown swipe
    local texts = CreateFrame("Frame", nil, button)
    texts:SetAllPoints()
    texts:SetFrameLevel(cooldown:GetFrameLevel() + 1)

    -- Create with a font: Blizzard writes text as soon as it's connected (MUI font applied later)
    local count = texts:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.Count = count
    button:SetApplicationCount(count, {})

    local time = texts:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.Time = time
    if TimeBar() then
        -- Bar instead of number: Blizzard drains it itself (SetTimerDuration). Child of the duration
        -- cooldown: Blizzard clears (hides) that for auras without a duration, so the bar goes with it
        local bar = CreateFrame("StatusBar", nil, cooldown)
        -- Inset by the border width: the border sits outside and then lines up with the icon
        local inset = ns.BORDER_PIXELS * ns.PixelSize()
        bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", inset, -ns.Snap(BAR_GAP))
        bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -inset, -ns.Snap(BAR_GAP))
        bar:SetHeight(ns.Snap(BAR_HEIGHT))
        bar:SetReverseFill(true) -- drains left to right
        bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
        bar:SetStatusBarColor(unpack(SAGE))
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.06, 0.06, 0.9)
        ns.AddBorder(bar)
        button:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime })
        timeBars[bar] = button
        time:Hide()
    else
        button:SetDurationText(time, { textFormatter = ns.DurationFormatter })
    end

    -- MUI look like the unit frames (border, dispel color for debuffs, swipe, font)
    ns.StyleAuraButton(styleElement, button, { dispelBand = harmful and "harmful" or nil })
    PlaceTexts(button, time, count)
end

local function CreateContainer(name, filter, perRow, rows, iconSize, spacing, lineSpacing, width, height)
    local container = CreateFrame("AuraContainer", name, UIParent, "CustomAuraContainerTemplate")
    container:SetFrameStrata("LOW")
    container.muiHeight = height
    container:SetSize(width, height)
    -- Start top right, grow left, then down
    container:SetFlowLayoutAnchorPoint("TOPRIGHT")
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutMaximumLineSize(width + ns.PixelSize() / 2) -- half a pixel against rounding errors
    container:SetFlowLayoutPadding(0, 0, 0, 0)

    local harmful = filter == "HARMFUL"
    local layout = { elementSpacing = spacing, lineSpacing = lineSpacing }
    local function Init(button) InitButton(button, iconSize, harmful) end
    container:AddAuraGroup(filter, filter, {
        maxFrameCount = perRow * rows,
        -- grows left from the right edge: permanent auras rightmost, then longest to shortest remaining
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        layout = layout,
        initializeFrame = Init,
    })
    if not harmful then
        -- Weapon enchants (poisons, oils ...) before the buffs
        for _, slot in ipairs({ AuraContainerItemEnchantmentSlot.MainHand, AuraContainerItemEnchantmentSlot.OffHand }) do
            container:AddItemEnchantment(slot, { initializeFrame = Init })
        end
        container:SetItemEnchantmentLayout({
            placement = CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups,
            elementSpacing = spacing,
            lineSpacing = lineSpacing,
        })
    end
    container:SetUnit("player")
    container:SetEnabled(true)
    container:Show()
    return container
end

-- Private auras: anchor frames only; Blizzard fills in icon, border and duration
local function CreatePrivateAuras(iconSize, spacing)
    local holder = CreateFrame("Frame", "MeredanUIPlayerPrivateAuras", UIParent)
    holder:SetFrameStrata("LOW")
    holder.muiHeight = iconSize
    holder:SetSize(PRIVATE_COUNT * iconSize + (PRIVATE_COUNT - 1) * spacing, iconSize)
    holder.slots = {}
    for index = 1, PRIVATE_COUNT do
        local aura = CreateFrame("Frame", nil, holder)
        holder.slots[index] = aura
        aura:SetSize(iconSize, iconSize)
        aura:SetPoint("TOPLEFT", holder, "TOPLEFT", (index - 1) * (iconSize + spacing), 0) -- grows right
        C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = "player",
            auraIndex = index,
            parent = aura,
            isContainer = false,
            showCountdownFrame = true,
            showCountdownNumbers = true,
            iconInfo = {
                iconWidth = iconSize,
                iconHeight = iconSize,
                iconAnchor = { point = "CENTER", relativeTo = aura, relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
            },
        })
    end
    return holder
end

local buffs, debuffs, privates

-- Top aligned with the minimap (or screen edge without minimap); buffs, debuffs and private
-- auras stacked. Never anchor own frames to an aura container: it is forbidden - so each
-- row is anchored to the same anchor with a computed offset.
local function StackAnchor()
    local minimap = _G["MeredanUIMinimap"]
    if minimap then return minimap, "TOPLEFT", -ns.Snap(GAP), 0 end
    return UIParent, "TOPRIGHT", -ns.Snap(ns.SCREEN_MARGIN), -ns.Snap(ns.SCREEN_MARGIN)
end

-- Stack rows; returns the next free offset (for private auras without the boss module)
local function Stack(frames)
    local anchor, point, x, y = StackAnchor()
    for _, frame in ipairs(frames) do
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("TOPRIGHT", anchor, point, x, y)
            y = y - frame.muiHeight - ns.Snap(GROUP_GAP)
        end
    end
    return anchor, point, x, y
end

-- Private auras (boss mechanics, drawn by Blizzard): above the topmost boss bar, left edge
-- aligned with the bar icons, growing right. BossMods reports the column in ns.bossBarColumn
-- and calls this after every rebuild. Without the boss module: below the debuffs.
local PRIVATE_BOSS_GAP = 6
function ns.PlacePrivateAuras()
    if not privates then return end
    privates:ClearAllPoints()
    local column = ns.bossBarColumn
    if column then
        -- Duration "below the icon" needs room to the topmost bar (demo placeholders; Blizzard
        -- writes the real number inside the icon)
        local gap = ns.Snap(PRIVATE_BOSS_GAP) + (TimeInside() and 0 or ns.Snap(TIME_HEIGHT))
        privates:SetPoint("BOTTOMLEFT", column.holder, "TOPRIGHT", -ns.Snap(column.width), gap)
    else
        -- NEVER anchor to the debuff container (forbidden -> "Anchoring disallowed"): compute height
        local anchor, point, x, y = StackAnchor()
        for _, frame in ipairs({ buffs, debuffs }) do
            if frame then y = y - frame.muiHeight - ns.Snap(GROUP_GAP) end
        end
        privates:SetPoint("TOPRIGHT", anchor, point, x, y)
    end
end

-- Bottom edge of the aura stack top right (buffs, debuffs, private auras only without the boss
-- module - with it they sit above the boss bars). Used by the quest log below. Computed, not
-- measured: aura containers are forbidden.
function ns.AuraStackBottom()
    if not (buffs or debuffs) then return end
    local anchor, _, _, y = StackAnchor()
    local top = anchor:GetTop() -- minimap top or screen top (both TOP* points)
    if not top then return end
    local frames = { buffs, debuffs }
    if privates and not ns.bossBarColumn then frames[#frames + 1] = privates end
    local bottom = top + y
    for _, frame in ipairs(frames) do
        if frame then bottom = bottom - frame.muiHeight - ns.Snap(GROUP_GAP) end
    end
    return bottom + ns.Snap(GROUP_GAP)
end

local function Place()
    Stack({ buffs, debuffs })
    ns.PlacePrivateAuras()
end

local function HideBlizzard()
    for _, frame in ipairs({ BuffFrame, DebuffFrame }) do
        if frame then
            frame:UnregisterAllEvents()
            frame:SetParent(hidden)
            frame:Hide()
        end
    end
    -- otherwise Edit Mode raises an error (same as ElvUI)
    if BuffFrame then BuffFrame.numHideableBuffs = 0 end
end

-- Demo: sample icons with the current settings (even ones not yet reloaded) --------------

local DEMO_BUFFS = { 21562, 1459, 6673, 1126, 381748, 462854, 2825, 465, 1022, 774, 17, 139 }
local DEMO_DEBUFFS = { 589, 172, 8936, 980, 1079, 6788 }
local DEMO_TIMES = { "58m", "12m", "45", "3m", "1h", "9", "27", "2m" }
local DEMO_DISPEL = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

local demoActive = false
local demoFrames = {}

local function DemoIcon(parent, spellID, size, harmful, index)
    local button = CreateFrame("Frame", nil, parent)
    button:SetSize(size, size)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(C_Spell.GetSpellTexture(spellID) or 134400)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = ns.AddBorder(button, true, harmful and 2 or ns.BORDER_PIXELS)
    local color = harmful and ns.oUF.colors.dispel[DEMO_DISPEL[(index - 1) % #DEMO_DISPEL + 1]]
    if color then
        for _, edge in ipairs(border) do edge:SetVertexColor(color:GetRGB()) end
    end
    local time = ns.CreateText(button, ns.STYLE.fontSize + 1, "CENTER", "OUTLINE")
    time:SetText(DEMO_TIMES[(index - 1) % #DEMO_TIMES + 1])
    if TimeBar() then
        time:SetText("")
        local bar = CreateFrame("StatusBar", nil, button)
        -- Inset by the border width: the border sits outside and then lines up with the icon
        local inset = ns.BORDER_PIXELS * ns.PixelSize()
        bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", inset, -ns.Snap(BAR_GAP))
        bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -inset, -ns.Snap(BAR_GAP))
        bar:SetHeight(ns.Snap(BAR_HEIGHT))
        bar:SetReverseFill(true) -- drains left to right
        bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
        bar:SetMinMaxValues(0, 1)
        local fill = ({ 0.9, 0.55, 0.3, 0.1 })[(index - 1) % 4 + 1]
        bar:SetValue(fill)
        local c = fill > 0.6 and SAGE or fill > 0.25 and YELLOW or RED
        bar:SetStatusBarColor(unpack(c))
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.06, 0.06, 0.9)
        ns.AddBorder(bar)
    end
    local count = ns.CreateText(button, ns.STYLE.fontSize - 2, "RIGHT", "OUTLINE")
    count:SetText(index % 4 == 0 and "3" or "")
    PlaceTexts(button, time, count)
    return button
end

-- Private aura placeholders (BossMods demo): Blizzard draws the real ones and a demo can't
-- fake them - this only shows WHERE they appear.
local DEMO_PRIVATE = { 589, 172, 8936 }
local privateDemo
function ns.PrivateAurasDemo(show)
    if not privates then return end
    if show and not privateDemo then
        privateDemo = {}
        for index, spellID in ipairs(DEMO_PRIVATE) do
            local icon = DemoIcon(privates, spellID, privates.muiHeight, false, index)
            icon:SetPoint("CENTER", privates.slots[index], "CENTER")
            privateDemo[index] = icon
        end
    end
    for _, icon in ipairs(privateDemo or {}) do icon:SetShown(show) end
end

local function DemoRow(spells, perRow, rows, harmful, metrics)
    local iconSize, spacing, lineSpacing, width, height = metrics()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetSize(width, height)
    frame.muiHeight = height
    for index = 1, perRow * rows do
        local icon = DemoIcon(frame, spells[(index - 1) % #spells + 1], iconSize, harmful, index)
        local col, row = (index - 1) % perRow, math.floor((index - 1) / perRow)
        icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -col * (iconSize + spacing), -row * (iconSize + lineSpacing))
    end
    return frame
end

local function StopDemo()
    for _, frame in ipairs(demoFrames) do frame:Hide() end
    wipe(demoFrames)
    for _, frame in ipairs({ buffs, debuffs, privates }) do frame:Show() end
    demoActive = false
end

local function StartDemo()
    if demoActive then StopDemo() end
    for _, frame in ipairs({ buffs, debuffs, privates }) do frame:Hide() end
    demoFrames = {
        DemoRow(DEMO_BUFFS, BUFFS_PER_ROW, BUFF_ROWS, false, BuffMetrics),
        DemoRow(DEMO_DEBUFFS, DEBUFFS_PER_ROW, DEBUFF_ROWS, true, DebuffMetrics),
    }
    Stack(demoFrames)
    demoActive = true
end

ns.AurasDemo = {
    Start = StartDemo,
    Stop = StopDemo,
    IsActive = function() return demoActive end,
}

-- Setting changed: rebuild the running demo with the new values
function ns.RefreshAurasDemo()
    if demoActive then StartDemo() end
end

ns:On("PLAYER_LOGIN", function()
    if not AuraContainerSortMethod then return end -- client without AuraContainer: Blizzard's frame stays
    HideBlizzard()
    local buffSize, buffSpacing, buffLines, buffWidth, buffHeight = BuffMetrics()
    buffs = CreateContainer("MeredanUIPlayerBuffs", "HELPFUL", BUFFS_PER_ROW, BUFF_ROWS,
        buffSize, buffSpacing, buffLines, buffWidth, buffHeight)
    local debuffSize, debuffSpacing, debuffLines, debuffWidth, debuffHeight = DebuffMetrics()
    debuffs = CreateContainer("MeredanUIPlayerDebuffs", "HARMFUL", DEBUFFS_PER_ROW, DEBUFF_ROWS,
        debuffSize, debuffSpacing, debuffLines, debuffWidth, debuffHeight)
    if C_UnitAuras.AddPrivateAuraAnchor then privates = CreatePrivateAuras(debuffSize, debuffSpacing) end
    ns.OnLayout(Place)
end)
