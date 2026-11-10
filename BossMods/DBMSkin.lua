-- Deadly Boss Mods in the mUI look - through DBM's own settings, in a DBM profile "MeredanUI"
-- (the player's previous profile stays untouched and can be picked again in DBM).
-- Look: flat bars with a 1 px border, mUI texture and font; warnings and info frame in the mUI
-- font. Spots from mUI's layout: bars left of the player frame (top-aligned, growing down), big
-- bars top centre, warnings above them, info frame right of the target frame.
-- Only bar icons get code skinning (DBM has no setting to crop them).
-- Set once per character (ns.char.dbmProfile); switch ns.db.dbmStyle (Modules page / setup).
local _, ns = ...

local PROFILE, PROFILE_VERSION = "MeredanUI", 1
local BAR_WIDTH, BAR_HEIGHT, HUGE_WIDTH, HUGE_HEIGHT = 220, 22, 260, 26
local ICON_GAP = 4

local function Available()
    return DBM ~= nil and DBT ~= nil and DBM.Options ~= nil and DBT.Options ~= nil
end
local function Styled() return ns.db and ns.db.dbmStyle ~= false end

local function BarLook()
    local r, g, b = unpack(ns.STYLE.panelColor)
    return {
        Texture = ns.STYLE.barTexture, Font = ns.STYLE.font, FontSize = 12, FontFlag = "OUTLINE",
        FontShadow = false, Spark = false, BarStyle = "NoAnim", Scale = 1, Alpha = 1,
        Height = BAR_HEIGHT, Width = BAR_WIDTH, BarYOffset = 4, TextXOffset = 0, TextYOffset = 0,
        IconLeft = true, IconRight = false, IconLocked = true,
        BackgroundColorR = r, BackgroundColorG = g, BackgroundColorB = b, BackgroundAlpha = 0.9,
        BorderEnabled = true, BorderSize = 1, BorderColorR = 0, BorderColorG = 0, BorderColorB = 0, BorderAlpha = 1,
        HugeScale = 1, HugeAlpha = 1, HugeWidth = HUGE_WIDTH, HugeHeight = HUGE_HEIGHT, HugeBarYOffset = 4,
        HugeBackgroundColorR = r, HugeBackgroundColorG = g, HugeBackgroundColorB = b, HugeBackgroundAlpha = 0.9,
        HugeBorderEnabled = true, HugeBorderSize = 1, HugeBorderColorR = 0, HugeBorderColorG = 0,
        HugeBorderColorB = 0, HugeBorderAlpha = 1,
    }
end

local function CoreLook(options)
    options.WarningFont = ns.STYLE.font
    options.WarningFontStyle = "OUTLINE"
    options.WarningFontShadow = false
    options.SpecialWarningFont = ns.STYLE.font
    options.SpecialWarningFontStyle = "THICKOUTLINE"
    options.InfoFrameFont = ns.STYLE.font
    options.InfoFrameFontStyle = "OUTLINE"
end

-- DBM anchors everything with the same point on UIParent: offset for point from screen coordinates
local function Offset(point, x, y)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local ox = point:find("LEFT") and x or point:find("RIGHT") and x - w or x - w / 2
    local oy = point:find("BOTTOM") and y or point:find("TOP") and y - h or y - h / 2
    return ox, oy
end

local function Positions(bars, options)
    local h = UIParent:GetHeight()
    local player = ns.frames and ns.frames.player
    if player and player:GetLeft() and ns.LeftOfPlayerEdge then
        -- as wide as possible (max BAR_WIDTH), the icon keeps the screen margin
        local right = ns.LeftOfPlayerEdge()
        local width = math.floor(math.min(BAR_WIDTH, right - ns.SCREEN_MARGIN - BAR_HEIGHT - ICON_GAP))
        bars.Width = width
        bars.TimerPoint, bars.ExpandUpwards = "BOTTOMLEFT", false
        bars.TimerX, bars.TimerY = Offset("BOTTOMLEFT", right - width / 2, player:GetTop())
    end
    local hugeTop = -math.floor(h * 0.26)
    bars.HugeTimerPoint, bars.HugeTimerX, bars.HugeTimerY, bars.ExpandUpwardsLarge = "TOP", 0, hugeTop, false
    options.WarningPoint, options.WarningX, options.WarningY = "TOP", 0, hugeTop + 70
    options.SpecialWarningPoint, options.SpecialWarningX, options.SpecialWarningY = "TOP", 0, hugeTop + 140
    local target = ns.frames and ns.frames.target
    if target and target:GetRight() and ns.RightOfTargetEdge then
        options.InfoFramePoint = "BOTTOMLEFT"
        options.InfoFrameX, options.InfoFrameY = Offset("BOTTOMLEFT", ns.RightOfTargetEdge(), target:GetBottom())
    end
end

-- Bar icons like everywhere in mUI: cropped, 1 px border, small gap to the bar
local function SkinIcon(icon, side)
    if not icon or icon.muiBorder then return end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local bar = icon:GetParent()
    icon:ClearAllPoints()
    if side == "left" then
        icon:SetPoint("RIGHT", bar, "LEFT", -ns.Snap(ICON_GAP), 0)
    else
        icon:SetPoint("LEFT", bar, "RIGHT", ns.Snap(ICON_GAP), 0)
    end
    local holder = CreateFrame("Frame", nil, bar)
    holder:SetAllPoints(icon)
    holder:SetFrameLevel(bar:GetFrameLevel() + 2)
    icon.muiBorder = ns.AddBorder(holder, true)
    local function Follow() holder:SetShown(icon:IsShown()) end
    hooksecurefunc(icon, "Show", Follow)
    hooksecurefunc(icon, "Hide", Follow)
    hooksecurefunc(icon, "SetShown", Follow)
    Follow()
end

local function SkinBars()
    if not (DBT and DBT.GetBarIterator) or DBM_UsedProfile ~= PROFILE then return end
    for bar in DBT:GetBarIterator() do
        local frame = bar.frame
        local name = frame and frame:GetName()
        if name and not frame.muiSkinned then
            frame.muiSkinned = true
            SkinIcon(_G[name .. "BarIcon1"], "left")
            SkinIcon(_G[name .. "BarIcon2"], "right")
        end
    end
end

function ns.ApplyDBMProfile(force)
    if not Available() or not Styled() or InCombatLockdown() then return end
    if not force and (ns.char.dbmProfile or 0) >= PROFILE_VERSION then return end
    ns.char.dbmProfile = PROFILE_VERSION
    if DBM_UsedProfile ~= PROFILE then
        if DBM_AllSavedOptions and DBM_AllSavedOptions[PROFILE] then
            DBM:ApplyProfile(PROFILE)
        elseif DBM.CreateProfile then
            DBM:CreateProfile(PROFILE)
        end
    end
    local bars = BarLook()
    Positions(bars, DBM.Options)
    for key, value in pairs(bars) do DBT:SetOption(key, value, true) end
    if DBT.Rearrange then DBT:Rearrange() end
    if DBT.UpdateBars then DBT:UpdateBars(true) end
    CoreLook(DBM.Options)
    if DBM.RepositionFrames then DBM:RepositionFrames() end
    if DBM.InfoFrame and DBM.InfoFrame.UpdateStyle then DBM.InfoFrame:UpdateStyle() end
    SkinBars()
end

ns:On("PLAYER_LOGIN", function()
    if not C_AddOns.IsAddOnLoaded("DBM-Core") or not Available() then return end
    if DBT.CreateBar then hooksecurefunc(DBT, "CreateBar", SkinBars) end
    -- after mUI has built its unit frames (positions come from them)
    C_Timer.After(2, function() ns.ApplyDBMProfile() end)
end)
