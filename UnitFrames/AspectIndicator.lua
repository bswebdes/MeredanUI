-- Speed aspect indicator (Forever, hunter, Comfort: aspectIndicator): while Aspect of the Cheetah
-- or Aspect of the Pack is up, the aspect's own spell icon sits in an item frame half over the
-- player frame's top edge on the far side (like the name on the near side), with a Surf Green
-- edge that pulses - both aspects daze you when hit, so they are easy to forget. Entering combat
-- with one of them up pulses faster for a few seconds. No sound, no text.
local _, ns = ...
if not ns.IS_FOREVER then return end

local ASPECTS = { 5118, 13159 } -- Cheetah, Pack (single rank each)
local SIZE = 24
local COMBAT_PULSE = 4 -- seconds of the strong pulse after entering combat
local DEMO_ID = 5118

local button, icon, pulse, player
local demo = false
local strongUntil = 0

local function Enabled() return ns.db.aspectIndicator ~= false end

local function ActiveAspect()
    for _, id in ipairs(ASPECTS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
        if not issecretvalue(aura) and aura then return id end
    end
end

local function SetStrong(on)
    if not pulse then return end
    pulse.anim:SetDuration(on and 0.3 or 1)
    pulse.anim:SetFromAlpha(on and 0.2 or 0.35)
    if pulse:IsPlaying() then pulse:Stop(); pulse:Play() end -- new timing only applies on restart
end

-- Top far corner, half over the edge; moves left of the resting icon while that shows
local function Place()
    local resting = player.RestingIndicator
    local x = -ns.Snap(14) - (resting and resting:IsShown() and ns.Snap(26) or 0)
    button:ClearAllPoints()
    button:SetPoint("CENTER", player, "TOPRIGHT", x, ns.Snap(5))
end

local function Update()
    if not button then return end
    local id = ActiveAspect() or (demo and DEMO_ID)
    local show = id and (demo or Enabled()) and true or false
    if show then
        icon:SetTexture(C_Spell.GetSpellTexture(id))
        Place()
        button:Show()
        if not pulse:IsPlaying() then pulse:Play() end
    else
        button:Hide()
        pulse:Stop()
    end
    if GetTime() >= strongUntil then SetStrong(false) end
end

local function Create()
    local layer = player.muiStatusLayer
    button = CreateFrame("Frame", nil, layer)
    button:SetSize(ns.Snap(SIZE), ns.Snap(SIZE))
    button:SetFrameLevel(layer:GetFrameLevel() + 2)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.07, 0.055, 0.043, 1)
    ns.AddItemFrame(button, nil, 1)
    icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetAllPoints()
    ns.InsetItemIcon(button, icon, nil, 1)

    -- Surf Green edge just outside the bronze one, breathing
    local ring = CreateFrame("Frame", nil, button)
    ring:SetAllPoints()
    for _, edge in ipairs(ns.AddBorder(ring, false, 2)) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    local glow = ring:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(ns.MEDIA .. "SoftGlow")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.6)
    glow:SetPoint("CENTER")
    glow:SetSize(SIZE * 2, SIZE * 2)
    ring:SetFrameLevel(math.max(button:GetFrameLevel() - 1, 0)) -- glow behind the icon

    pulse = ring:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    pulse.anim = pulse:CreateAnimation("Alpha")
    pulse.anim:SetToAlpha(1)
    SetStrong(false)
    button:Hide()

    local resting = player.RestingIndicator
    if resting then
        hooksecurefunc(resting, "Show", function() if button:IsShown() then Place() end end)
        hooksecurefunc(resting, "Hide", function() if button:IsShown() then Place() end end)
    end
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
        player = ns.frames and ns.frames.player
        if not (player and player.muiStatusLayer) then return end
        Create()
        Update()
    end)
    ns:On("UNIT_AURA", function(_, unit) if unit == "player" then Update() end end)
    ns:On("PLAYER_REGEN_DISABLED", function()
        if not (Enabled() and ActiveAspect()) then return end
        strongUntil = GetTime() + COMBAT_PULSE
        SetStrong(true)
        C_Timer.After(COMBAT_PULSE, Update)
    end)
end)
