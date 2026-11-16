-- Speed aspect indicator (Forever, hunter, Comfort: aspectIndicator): while Aspect of the Cheetah
-- or Aspect of the Pack is up, a small medallion (dark disc, bronze ring, white running icon) sits
-- in the player frame's status row with a soft Surf Green glow pulsing behind it - readable on any
-- bar colour - both daze you when hit, so they are easy to forget. Entering combat with one
-- of them up pulses harder for a few seconds. No sound, no text.
local _, ns = ...
if not ns.IS_FOREVER then return end

local ASPECTS = { 5118, 13159 } -- Cheetah, Pack (single rank each)
local SIZE = 24 -- medallion; neighbours in the status row are 18 + 4 apart, so it just clears them
local COMBAT_PULSE = 4 -- seconds of the strong pulse after entering combat

local icon, glow, pulse, strong
local demo = false
local strongUntil = 0

local function Enabled() return ns.db.aspectIndicator ~= false end

local function AspectUp()
    for _, id in ipairs(ASPECTS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if not issecretvalue(aura) and aura then return true end
    end
    return false
end

local function SetStrong(on)
    strong = on
    if not pulse then return end
    local duration, size = on and 0.35 or 1.1, on and 1.45 or 1.15
    pulse.anim:SetDuration(duration)
    pulse.anim:SetToAlpha(on and 1 or 0.7)
    pulse.scale:SetDuration(duration)
    pulse.scale:SetScaleTo(size, size)
    if pulse:IsPlaying() then pulse:Stop(); pulse:Play() end -- new timing only applies on restart
end

local function Update()
    if not icon then return end
    local show = demo or (Enabled() and AspectUp())
    icon:SetShown(show)
    if show then
        if not pulse:IsPlaying() then pulse:Play() end
    else
        pulse:Stop()
    end
    if strong and GetTime() >= strongUntil then SetStrong(false) end
end

local function Create(player)
    local row, layer = player.muiStatusRow, player.muiStatusLayer
    local px = ns.PixelSize()
    icon = CreateFrame("Frame", nil, layer)
    icon:SetSize(SIZE, SIZE)
    icon:SetFrameLevel(layer:GetFrameLevel() + 2)

    -- soft glow behind the medallion that breathes outward
    glow = icon:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ns.MEDIA .. "SoftGlow")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(unpack(ns.UI.ACCENT))
    glow:SetPoint("CENTER")
    glow:SetSize(SIZE * 1.7, SIZE * 1.7)

    local shadow = icon:CreateTexture(nil, "BORDER", nil, 0)
    shadow:SetTexture(ns.MEDIA .. "Disc")
    shadow:SetVertexColor(0, 0, 0, 0.6)
    shadow:SetPoint("CENTER", 0, -2 * px)
    shadow:SetSize(SIZE + 4 * px, SIZE + 4 * px)
    local ring = icon:CreateTexture(nil, "BORDER", nil, 1)
    ring:SetTexture(ns.MEDIA .. "Disc")
    ring:SetVertexColor(ns.ITEM_EDGE[1], ns.ITEM_EDGE[2], ns.ITEM_EDGE[3], 1)
    ring:SetAllPoints()
    local disc = icon:CreateTexture(nil, "ARTWORK")
    disc:SetTexture(ns.MEDIA .. "Disc")
    disc:SetVertexColor(0.086, 0.075, 0.059, 1)
    disc:SetPoint("TOPLEFT", ns.Snap(2), -ns.Snap(2))
    disc:SetPoint("BOTTOMRIGHT", -ns.Snap(2), ns.Snap(2))
    local runner = icon:CreateTexture(nil, "OVERLAY")
    ns.SetIcon(runner, "Speed")
    runner:SetVertexColor(1, 1, 1)
    runner:SetPoint("CENTER")
    runner:SetSize(SIZE * 0.62, SIZE * 0.62)

    row.Add(icon)

    pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    pulse.anim = pulse:CreateAnimation("Alpha")
    pulse.anim:SetFromAlpha(0.15)
    pulse.scale = pulse:CreateAnimation("Scale")
    pulse.scale:SetScaleFrom(1, 1)
    pulse.scale:SetOrigin("CENTER", 0, 0)
    SetStrong(false)
end

function ns.UpdateAspectIndicator() Update() end

-- Preview (Core/Preview.lua)
ns.AspectDemo = {
    Start = function() demo = true; Update() end,
    Stop = function() demo = false; Update() end,
    IsActive = function() return demo end,
}

ns:On("PLAYER_LOGIN", function()
    if select(2, UnitClass("player")) ~= "HUNTER" then return end
    C_Timer.After(0.1, function() -- the player frame is spawned on PLAYER_LOGIN as well
        local player = ns.frames and ns.frames.player
        if not (player and player.muiStatusRow) then return end
        Create(player)
        Update()
    end)
    ns:On("UNIT_AURA", function(_, unit) if unit == "player" then Update() end end)
    ns:On("PLAYER_REGEN_DISABLED", function()
        if not (Enabled() and AspectUp()) then return end
        strongUntil = GetTime() + COMBAT_PULSE
        SetStrong(true)
        C_Timer.After(COMBAT_PULSE, Update)
    end)
end)
