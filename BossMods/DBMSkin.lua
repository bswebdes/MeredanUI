-- Deadly Boss Mods in the mUI look - through DBM's own settings, in a DBM profile "MeredanUI"
-- (the player's previous profile stays untouched and can be picked again in DBM).
-- Look (rune look): shaded bars in a thin deep shell, icons in item frames, mUI font; warnings
-- and info frame in the mUI font. Spots from mUI's layout: bars above the player frame (left-aligned, growing up), big
-- bars top centre, warnings above them, info frame right of the target frame.
-- Code skinning only for what DBM has no setting for: the shell around each bar and the icon frames.
-- Set once per character (ns.char.dbmProfile); switch ns.db.dbmStyle (Modules page / setup).
local _, ns = ...

local PROFILE, PROFILE_VERSION = "MeredanUI", 7
local BAR_WIDTH, BAR_HEIGHT, HUGE_WIDTH, HUGE_HEIGHT = 220, 22, 260, 26
local ICON_GAP = 8          -- clear of the bar shell and the icon frame
local ABOVE_GAP = 16      -- between the player's buff row and the bars

local function Available()
    return DBM ~= nil and DBT ~= nil and DBM.Options ~= nil and DBT.Options ~= nil
end
local function Styled() return ns.db and ns.db.dbmStyle ~= false end

local function BarLook()
    local r, g, b = unpack(ns.STYLE.panelColor)
    return {
        Texture = ns.MEDIA .. "BarShade", Font = ns.STYLE.font, FontSize = 12, FontFlag = "OUTLINE",
        FontShadow = false, Spark = false, BarStyle = "NoAnim", Scale = 1, Alpha = 1,
        Height = BAR_HEIGHT, Width = BAR_WIDTH, BarYOffset = 4, TextXOffset = 0, TextYOffset = 0,
        IconLeft = true, IconRight = false, IconLocked = true,
        -- the grey "~" part (timer that can fire earlier or later): flat mUI texture, softer
        VarianceTexture = ns.MEDIA .. "BarShade", VarianceAlpha = 0.35,
        BackgroundColorR = r, BackgroundColorG = g, BackgroundColorB = b, BackgroundAlpha = 0.9,
        -- DBM's own border off: the thin deep shell (SkinBars) frames the bar
        BorderEnabled = false, BorderSize = 1, BorderColorR = 0, BorderColorG = 0, BorderColorB = 0, BorderAlpha = 1,
        HugeScale = 1, HugeAlpha = 1, HugeWidth = HUGE_WIDTH, HugeHeight = HUGE_HEIGHT, HugeBarYOffset = 4,
        HugeBackgroundColorR = r, HugeBackgroundColorG = g, HugeBackgroundColorB = b, HugeBackgroundAlpha = 0.9,
        HugeBorderEnabled = false, HugeBorderSize = 1, HugeBorderColorR = 0, HugeBorderColorG = 0,
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
    if player and player:GetLeft() then
        -- icon flush with the player frame's left edge, bar after it: together exactly as wide as the frame
        local left = player:GetLeft() + BAR_HEIGHT + ICON_GAP
        local width = math.floor(player:GetRight() - left + 0.5)
        bars.Width = width
        bars.TimerPoint, bars.ExpandUpwards = "BOTTOMLEFT", true
        -- above the player's buff row (UnitFrames.lua: one row at aurasAbove, icon size buff)
        local S = player.Sizes or {}
        -- DBM places the bar's vertical centre on the anchor: half a bar more
        local above = (S.aurasAbove or 20) + (S.buff or 30) + ns.Snap(ABOVE_GAP) + BAR_HEIGHT / 2
        bars.TimerX, bars.TimerY = Offset("BOTTOMLEFT", left + width / 2, player:GetTop() + above)
    end
    -- big bars a bit higher; warnings stacked tighter above them, clear of Blizzard's error and
    -- zone texts (top -122 to about -180)
    local hugeTop = -math.floor(h * 0.22)
    bars.HugeTimerPoint, bars.HugeTimerX, bars.HugeTimerY, bars.ExpandUpwardsLarge = "TOP", 0, hugeTop, false
    options.WarningPoint, options.WarningX, options.WarningY = "TOP", 0, hugeTop + 50
    options.SpecialWarningPoint, options.SpecialWarningX, options.SpecialWarningY = "TOP", 0, hugeTop + 100
    local target = ns.frames and ns.frames.target
    if target and target:GetRight() and ns.RightOfTargetEdge then
        options.InfoFramePoint = "BOTTOMLEFT"
        options.InfoFrameX, options.InfoFrameY = Offset("BOTTOMLEFT", ns.RightOfTargetEdge(), target:GetBottom())
    end
end

-- Bar icons like everywhere in mUI: in an item frame, a gap to the bar's shell
local function SkinIcon(icon, side)
    if not icon or icon.muiBorder then return end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local bar = icon:GetParent()
    local holder = CreateFrame("Frame", nil, bar)
    -- as tall as the bar, square; follows the bar when DBM enlarges it (huge bars)
    if side == "left" then
        holder:SetPoint("TOPRIGHT", bar, "TOPLEFT", -ns.Snap(ICON_GAP), 0)
        holder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -ns.Snap(ICON_GAP), 0)
    else
        holder:SetPoint("TOPLEFT", bar, "TOPRIGHT", ns.Snap(ICON_GAP), 0)
        holder:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", ns.Snap(ICON_GAP), 0)
    end
    holder:SetWidth(bar:GetHeight())
    bar:HookScript("OnSizeChanged", function(_, _, h) holder:SetWidth(h) end)
    holder:SetFrameLevel(bar:GetFrameLevel() + 2) -- frame only: a background here would cover the icon
    icon.muiBorder = ns.AddItemFrame(holder, nil, 2)
    ns.InsetItemIcon(holder, icon, nil, 2)
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
            local statusbar = _G[name .. "Bar"]
            if statusbar then ns.AddThinShell(statusbar) end
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

-- DBM's bar object exists as soon as DBM-StatusBarTimers is loaded, its options only later: hook the
-- bars right away, apply the profile once the options are there (a few tries)
ns:On("PLAYER_LOGIN", function()
    if not C_AddOns.IsAddOnLoaded("DBM-Core") then return end
    if DBT and DBT.CreateBar then hooksecurefunc(DBT, "CreateBar", SkinBars) end
    -- after mUI has built its unit frames (positions come from them)
    local tries = 0
    local function Try()
        tries = tries + 1
        if Available() then ns.ApplyDBMProfile() elseif tries < 15 then C_Timer.After(1, Try) end
    end
    C_Timer.After(2, Try)
end)
