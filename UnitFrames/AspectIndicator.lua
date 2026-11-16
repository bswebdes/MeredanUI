-- Speed aspect indicator (Forever, hunter, Comfort: aspectIndicator): while Aspect of the Cheetah
-- or Aspect of the Pack is up, its buff in the player buff bar (Auras/PlayerAuras.lua) gets a
-- Surf Green edge that pulses - both aspects daze you when hit, so they are easy to forget.
-- Entering combat with one of them up pulses faster for a few seconds. No sound, no text.
-- The buff buttons belong to Blizzard's AuraContainer: which aura a button shows is read with
-- pcall and only used when it isn't secret.
local _, ns = ...
if not ns.IS_FOREVER then return end

local ASPECTS = { [5118] = true, [13159] = true } -- Cheetah, Pack (single rank each)
local COMBAT_PULSE = 4 -- seconds of the strong pulse after entering combat

local isHunter = false
local strongUntil = 0
local pulses = {} -- [button] = overlay

local function Enabled() return isHunter and ns.db.aspectIndicator ~= false end

local function SetStrong(overlay, on)
    local anim = overlay.pulse.anim
    anim:SetDuration(on and 0.3 or 1)
    anim:SetFromAlpha(on and 0.15 or 0.3)
    if overlay.pulse:IsPlaying() then overlay.pulse:Stop(); overlay.pulse:Play() end -- timing applies on restart
end

-- Surf Green edge just outside the item frame plus a soft glow, breathing
function ns.AddAspectPulse(button, playNow)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button:GetFrameLevel() + 5)
    for _, edge in ipairs(ns.AddBorder(overlay, false, 2)) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    local glow = overlay:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(ns.MEDIA .. "SoftGlow")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.5)
    glow:SetPoint("CENTER")
    local size = button:GetWidth() * 1.9
    glow:SetSize(size, size)
    overlay.pulse = overlay:CreateAnimationGroup()
    overlay.pulse:SetLooping("BOUNCE")
    overlay.pulse.anim = overlay.pulse:CreateAnimation("Alpha")
    overlay.pulse.anim:SetToAlpha(1)
    SetStrong(overlay, false)
    if playNow then overlay.pulse:Play() else overlay:Hide() end
    return overlay
end

local function Plain(v) if not issecretvalue(v) then return v end end

-- Spell shown by a buff button, nil when unknown or secret
local function ButtonSpell(button)
    if not button.GetAuraInstance then return end
    local ok, _, data = pcall(button.GetAuraInstance, button)
    if not ok or issecretvalue(data) or type(data) ~= "table" then return end
    return Plain(data.spellId)
end

local function Update()
    local on = Enabled()
    local strong = GetTime() < strongUntil
    for _, button in ipairs(ns.playerBuffButtons or {}) do
        local id = on and ButtonSpell(button)
        local overlay = pulses[button]
        if id and ASPECTS[id] then
            overlay = overlay or ns.AddAspectPulse(button)
            pulses[button] = overlay
            SetStrong(overlay, strong)
            overlay:Show()
            if not overlay.pulse:IsPlaying() then overlay.pulse:Play() end
        elseif overlay and overlay:IsShown() then
            overlay.pulse:Stop()
            overlay:Hide()
        end
    end
end

-- the container reassigns its buttons on the same UNIT_AURA: look a moment later
local pending
local function RequestUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function() pending = false; Update() end)
end

function ns.UpdateAspectIndicator() RequestUpdate() end

-- Buff bar preview (Auras/PlayerAuras.lua): the first demo buff becomes Cheetah for hunters
function ns.AspectDemoSpell() return Enabled() and 5118 or nil end

ns:On("PLAYER_LOGIN", function()
    isHunter = select(2, UnitClass("player")) == "HUNTER"
    if not isHunter then return end
    RequestUpdate()
    ns:On("UNIT_AURA", function(_, unit) if unit == "player" then RequestUpdate() end end)
    ns:On("PLAYER_REGEN_DISABLED", function()
        strongUntil = GetTime() + COMBAT_PULSE
        RequestUpdate()
        C_Timer.After(COMBAT_PULSE + 0.1, Update)
    end)
end)
