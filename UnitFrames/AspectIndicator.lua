-- Speed aspect indicator (Forever, hunter, Comfort: aspectIndicator): while Aspect of the Cheetah
-- or Aspect of the Pack is up, a running icon sits in the player frame's status row with a soft
-- Surf Green pulse - both daze you when hit, so they are easy to forget. Entering combat with one
-- of them up pulses harder for a few seconds. No sound, no text.
local _, ns = ...
if not ns.IS_FOREVER then return end

local ASPECTS = { 5118, 13159 } -- Cheetah, Pack (single rank each)
local SIZE = 18
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
    local duration, size = on and 0.35 or 1.1, on and 1.6 or 1.25
    pulse.anim:SetDuration(duration)
    pulse.anim:SetToAlpha(on and 1 or 0.55)
    pulse.scale:SetDuration(duration)
    pulse.scale:SetScaleTo(size, size)
    if pulse:IsPlaying() then pulse:Stop(); pulse:Play() end -- new timing only applies on restart
end

local function Update()
    if not icon then return end
    local show = demo or (Enabled() and AspectUp())
    icon:SetShown(show)
    glow:SetShown(show)
    if show then
        if not pulse:IsPlaying() then pulse:Play() end
    else
        pulse:Stop()
    end
    if strong and GetTime() >= strongUntil then SetStrong(false) end
end

local function Create(player)
    local row, layer = player.muiStatusRow, player.muiStatusLayer
    icon = ns.CreateStatusIcon(layer, "Speed", SIZE, ns.UI.ACCENT)
    row.Add(icon)

    -- additive copy behind the icon that breathes outward
    glow = layer:CreateTexture(nil, "OVERLAY", nil, 5)
    glow:SetTexture(ns.IconPath("Speed"))
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(unpack(ns.UI.ACCENT))
    glow:SetPoint("CENTER", icon, "CENTER")
    glow:SetSize(SIZE, SIZE)
    glow:Hide()

    pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    pulse.anim = pulse:CreateAnimation("Alpha")
    pulse.anim:SetFromAlpha(0)
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
