-- Speed aspect indicator (Forever, hunter, Comfort: aspectIndicator): while Aspect of the Cheetah
-- or Aspect of the Pack is up, its button on the action bars (and stance bar) gets a Surf Green
-- edge that pulses - both aspects daze you when hit, so they are easy to forget. Entering combat
-- with one of them up pulses faster for a few seconds. No sound, no text.
-- (Blizzard's buff bar can't be used: its buttons hide which aura they show from addons.)
local _, ns = ...
if not ns.IS_FOREVER then return end

local ASPECTS = { [5118] = true, [13159] = true } -- Cheetah, Pack (single rank each)
local COMBAT_PULSE = 4 -- seconds of the strong pulse after entering combat

local isHunter = false
local demo = false
local strongUntil = 0
local pulses = {} -- [button] = overlay

local function Enabled() return isHunter and ns.db.aspectIndicator ~= false end

local function Active(id)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    return not issecretvalue(aura) and aura and true or false
end

local function SetStrong(overlay, on)
    local anim = overlay.pulse.anim
    anim:SetDuration(on and 0.3 or 1)
    anim:SetFromAlpha(on and 0.15 or 0.3)
    if overlay.pulse:IsPlaying() then overlay.pulse:Stop(); overlay.pulse:Play() end -- timing applies on restart
end

-- Surf Green edge just outside the button plus a soft glow, breathing
local function CreatePulse(button)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(button:GetFrameLevel() + 6)
    for _, edge in ipairs(ns.AddBorder(overlay, false, 2)) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    local glow = overlay:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(ns.MEDIA .. "SoftGlow")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.5)
    glow:SetPoint("CENTER")
    local size = button:GetWidth() * 1.8
    glow:SetSize(size, size)
    overlay.pulse = overlay:CreateAnimationGroup()
    overlay.pulse:SetLooping("BOUNCE")
    overlay.pulse.anim = overlay.pulse:CreateAnimation("Alpha")
    overlay.pulse.anim:SetToAlpha(1)
    SetStrong(overlay, false)
    overlay:Hide()
    return overlay
end

local function SetPulse(button, on, strong)
    local overlay = pulses[button]
    if on then
        overlay = overlay or CreatePulse(button)
        pulses[button] = overlay
        SetStrong(overlay, strong)
        overlay:Show()
        if not overlay.pulse:IsPlaying() then overlay.pulse:Play() end
    elseif overlay and overlay:IsShown() then
        overlay.pulse:Stop()
        overlay:Hide()
    end
end

-- Spell on an mUI action button (LibActionButton), nil for anything else
local function ButtonSpell(button)
    local slot = button._state_type == "action" and button._state_action
    if type(slot) ~= "number" then return end
    local kind, id = GetActionInfo(slot)
    if kind == "spell" and not issecretvalue(id) then return id end
end

local function Update()
    local on = Enabled()
    local strong = GetTime() < strongUntil
    local function Check(button, id)
        local match = on and id and ASPECTS[id] and (demo or Active(id))
        SetPulse(button, match and true or false, strong)
    end
    for _, bar in ipairs(ns.actionBars or {}) do
        for _, button in ipairs(bar.buttons) do Check(button, ButtonSpell(button)) end
    end
    -- stance bar (Blizzard buttons, styled by mUI) in case aspects sit there
    for i = 1, NUM_STANCE_SLOTS or 10 do
        local button = _G["StanceButton" .. i]
        if button then
            local spellID = select(4, GetShapeshiftFormInfo(i))
            Check(button, not issecretvalue(spellID) and spellID or nil)
        end
    end
end

local pending
local function RequestUpdate()
    if pending then return end
    pending = true
    C_Timer.After(0.05, function() pending = false; Update() end)
end

function ns.UpdateAspectIndicator() RequestUpdate() end

-- Preview (Core/Preview.lua): aspect buttons pulse even when the aspect is off
ns.AspectDemo = {
    Start = function() demo = true; Update() end,
    Stop = function() demo = false; Update() end,
    IsActive = function() return demo end,
}

ns:On("PLAYER_LOGIN", function()
    isHunter = select(2, UnitClass("player")) == "HUNTER"
    if not isHunter then return end
    C_Timer.After(0.5, Update) -- after the bars are built
    ns:On("UNIT_AURA", function(_, unit) if unit == "player" then RequestUpdate() end end)
    for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
        "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "LEARNED_SPELL_IN_SKILL_LINE" }) do
        ns:On(event, RequestUpdate)
    end
    ns:On("PLAYER_REGEN_DISABLED", function()
        strongUntil = GetTime() + COMBAT_PULSE
        RequestUpdate()
        C_Timer.After(COMBAT_PULSE + 0.1, Update)
    end)
end)
