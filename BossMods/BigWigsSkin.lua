-- BigWigs in the mUI look - through BigWigs' own means: a bar style "MeredanUI" registered with
-- BigWigsAPI:RegisterBarStyle (see BigWigs_Plugins/BarStyles.lua, wiki "Custom Bar Styles") and
-- the Bars/Messages plugin profile values (texture, font, sizes, positions). Same spots as the DBM
-- look (BossMods/DBMSkin.lua): bars above the player's buff row, exactly as wide as the player
-- frame, growing up; big bars top centre.
-- Profile values set once per character (ns.char.bigwigsProfile); switch ns.db.bigwigsStyle.
local _, ns = ...
local BigWigs, BigWigsAPI -- globals of BigWigs, read when needed

local STYLE, PROFILE_VERSION = "MeredanUI", 2
local BAR_HEIGHT, HUGE_WIDTH, HUGE_HEIGHT = 22, 260, 26
local ICON_GAP, ABOVE_GAP = 4, 16

local function Styled() return ns.db and ns.db.bigwigsStyle ~= false end

-- Bar style: flat panel with a 1 px black border, cropped icon with its own border, texts inside
local function Backdrop()
    local px = ns.PixelSize()
    return { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = px,
        insets = { left = 0, right = 0, top = 0, bottom = 0 } }
end

local function RemoveStyle(bar)
    bar.candyBarBackdrop:Hide()
    bar.candyBarIconFrameBackdrop:Hide()
    local statusbar = bar.candyBarBar
    for _, text in ipairs({ bar.candyBarLabel, bar.candyBarDuration }) do
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", statusbar, "TOPLEFT", 2, 0)
        text:SetPoint("BOTTOMRIGHT", statusbar, "BOTTOMRIGHT", -2, 0)
    end
end

local function ApplyStyle(bar)
    local height = bar:GetHeight()
    local statusbar = bar.candyBarBar
    local panel = ns.STYLE.panelColor
    local backdrop = Backdrop()

    local bd = bar.candyBarBackdrop
    if bd.SetToDefaults then
        bd:SetToDefaults()
        bd:SetFrameLevel(0)
    end
    bd:ClearAllPoints()
    bd:SetBackdrop(backdrop)
    bd:SetBackdropColor(panel[1], panel[2], panel[3], 0.9)
    bd:SetBackdropBorderColor(0, 0, 0, 1)

    local reApplyIcon
    local iconFrame, iconBd = bar.candyBarIconFrame, bar.candyBarIconFrameBackdrop
    if iconFrame.IsAnchoringSecret and iconFrame:IsAnchoringSecret() then
        reApplyIcon = bar:GetIcon()
        iconFrame:SetToDefaults()
        iconBd:SetToDefaults()
        iconBd:SetFrameLevel(0)
    end
    iconFrame:ClearAllPoints()
    iconBd:ClearAllPoints()
    statusbar:ClearAllPoints()
    iconFrame:SetSize(height, height)
    if bar:GetIconPosition() == "RIGHT" then
        iconFrame:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        statusbar:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        statusbar:SetPoint("BOTTOMRIGHT", bar:IsIconVisible() and iconFrame or bar,
            bar:IsIconVisible() and "BOTTOMLEFT" or "BOTTOMRIGHT", bar:IsIconVisible() and -ICON_GAP or 0, 0)
    else
        iconFrame:SetPoint("LEFT", bar, "LEFT", 0, 0)
        statusbar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
        statusbar:SetPoint("TOPLEFT", bar:IsIconVisible() and iconFrame or bar,
            bar:IsIconVisible() and "TOPRIGHT" or "TOPLEFT", bar:IsIconVisible() and ICON_GAP or 0, 0)
    end
    -- frame one pixel outside the bar so the fill doesn't cover the border; dark mUI field behind
    local px = ns.PixelSize()
    bd:SetPoint("TOPLEFT", statusbar, "TOPLEFT", -px, px)
    bd:SetPoint("BOTTOMRIGHT", statusbar, "BOTTOMRIGHT", px, -px)
    bd:Show()
    if bar.candyBarBackground then
        bar.candyBarBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar.candyBarBackground:SetVertexColor(panel[1], panel[2], panel[3], 0.9)
    end

    iconBd:SetBackdrop(backdrop)
    iconBd:SetBackdropColor(0, 0, 0, 0)
    iconBd:SetBackdropBorderColor(0, 0, 0, 1)
    iconBd:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -px, px)
    iconBd:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", px, -px)
    iconBd:SetShown(bar:IsIconVisible())
    if reApplyIcon then iconFrame:SetTexture(reApplyIcon) end
    if iconFrame.SetTexCoord then iconFrame:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

    bar.candyBarLabel:ClearAllPoints()
    bar.candyBarLabel:SetPoint("LEFT", statusbar, "LEFT", 4, 0)
    bar.candyBarLabel:SetPoint("RIGHT", bar.candyBarDuration, "LEFT", -4, 0)
    bar.candyBarDuration:ClearAllPoints()
    bar.candyBarDuration:SetPoint("RIGHT", statusbar, "RIGHT", -4, 0)
end

local registered = false
local function RegisterStyle()
    BigWigsAPI = _G.BigWigsAPI
    if registered or not (BigWigsAPI and BigWigsAPI.RegisterBarStyle) then return end
    registered = true
    BigWigsAPI:RegisterBarStyle(STYLE, {
        apiVersion = 1,
        version = 3,
        barHeight = BAR_HEIGHT,
        fontSizeNormal = 12,
        fontSizeEmphasized = 13,
        -- no GetSpacing: BigWigs then uses the profile's spacing (4 px) between bars
        ApplyStyle = ApplyStyle,
        BarStopped = RemoveStyle,
        GetStyleName = function() return "MeredanUI" end,
    })
end

-- Profile values: same spots as the DBM look
local function Positions(profile)
    local player = ns.frames and ns.frames.player
    if player and player:GetLeft() then
        local S = player.Sizes or {}
        local above = (S.aurasAbove or 20) + (S.buff or 30) + ns.Snap(ABOVE_GAP)
        profile.normalWidth = math.floor(player:GetWidth() + 0.5)
        profile.normalPosition = { "BOTTOMLEFT", "BOTTOMLEFT", player:GetLeft(), player:GetTop() + above, "UIParent" }
    end
    -- big bars below BigWigs' message area: its messages start 262 px below the top edge (clear of
    -- Blizzard's error, raid warning and boss emote texts, see BigWigs_Plugins/Messages.lua), room
    -- for about four message lines, then the big bars growing down
    profile.expPosition = { "TOP", "TOP", 0, -(262 + 100), "UIParent" }
end

function ns.ApplyBigWigsProfile(force)
    BigWigs = _G.BigWigs
    if not Styled() or InCombatLockdown() or not BigWigs then return end
    if not force and (ns.char.bigwigsProfile or 0) >= PROFILE_VERSION then return end
    -- BigWigs:GetPlugin only hands out a few functions: read the plugin settings from BigWigs'
    -- database namespace instead ("BigWigs_Plugins_<name>", BigWigs_Core/Core.lua NewPlugin)
    local root = _G.BigWigsLoader and _G.BigWigsLoader.db
    local function Profile(name)
        local db = root and root.GetNamespace and root:GetNamespace("BigWigs_Plugins_" .. name, true)
        return db and db.profile
    end
    local profile = Profile("Bars")
    if not profile then return end
    ns.char.bigwigsProfile = PROFILE_VERSION
    profile.barStyle = STYLE
    profile.texture = ns.DEFAULT_TEXTURE
    profile.fontName, profile.fontSize, profile.fontSizeEmph, profile.outline = "mUI", 12, 13, "OUTLINE"
    profile.normalHeight, profile.expWidth, profile.expHeight = BAR_HEIGHT, HUGE_WIDTH, HUGE_HEIGHT
    profile.growup, profile.emphasizeGrowup = true, false
    profile.icon, profile.iconPosition, profile.spacing = true, "LEFT", 4
    Positions(profile)
    local mp = Profile("Messages")
    if mp then mp.fontName, mp.emphFontName = "mUI", "mUI" end
    -- let the plugins re-read their profile, the way BigWigs' own profile import does it
    if BigWigs.SendMessage then BigWigs:SendMessage("BigWigs_ProfileUpdate") end
end

-- BigWigs loads its plugins on demand (in instances or with /bw): style and profile then
ns:On("ADDON_LOADED", function(_, name)
    if name == "BigWigs" or name == "BigWigs_Core" then RegisterStyle() end
    if name == "BigWigs_Plugins" then
        RegisterStyle()
        -- plugins register their settings a moment later: try a few times
        local tries = 0
        local function Try()
            tries = tries + 1
            if (ns.char.bigwigsProfile or 0) >= PROFILE_VERSION or tries > 10 then return end
            ns.ApplyBigWigsProfile()
            C_Timer.After(1, Try)
        end
        C_Timer.After(0, Try)
    end
end)
ns:On("PLAYER_LOGIN", function()
    RegisterStyle()
    if C_AddOns.IsAddOnLoaded("BigWigs_Plugins") then C_Timer.After(2, function() ns.ApplyBigWigsProfile() end) end
end)
