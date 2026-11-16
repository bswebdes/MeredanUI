-- Hardcore mode (fun, opt-in: hardcoreMode): on death the screen darkens, "YOU DIED" in red Cinzel,
-- "Try again" logs out to character select after a 20 second countdown. A quiet "Keep playing"
-- bottom right cancels it and Blizzard's release popup takes over as usual.
-- Logout timing: outside rested areas the game itself counts 20 seconds after Logout(), so it is
-- called right away; in cities and inns it would be instant, so we count down first.
-- The interface fades out while the death screen fades in, and comes back when it closes.
-- Off on Blizzard's real hardcore realms. Settings > Appearance has a test button (never logs out).
local _, ns = ...
local L = ns.L

local COUNTDOWN = 20
local FADE_IN, FADE_OUT = 1.5, 0.4
local RED = { 0.86, 0.16, 0.12 }

local screen, title, sub, countdown, retry, keep, testLabel
local progress, target = 0, 0 -- 0 = interface visible, 1 = death screen
local minimapHidden
local active, test, ownTimer, deadline, ticker

local function Enabled() return ns.db.hardcoreMode == true end

local function RealHardcore()
    return C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive()
end

local function Edge(point, horizontal, size)
    local tex = screen:CreateTexture(nil, "BACKGROUND", nil, 1)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetPoint(point)
    if horizontal then
        tex:SetPoint(point == "TOP" and "TOPLEFT" or "BOTTOMLEFT")
        tex:SetPoint(point == "TOP" and "TOPRIGHT" or "BOTTOMRIGHT")
        tex:SetHeight(size)
    else
        tex:SetPoint(point == "LEFT" and "TOPLEFT" or "TOPRIGHT")
        tex:SetPoint(point == "LEFT" and "BOTTOMLEFT" or "BOTTOMRIGHT")
        tex:SetWidth(size)
    end
    local dark, clear = CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0)
    -- gradients run left->right / bottom->top
    if point == "LEFT" then tex:SetGradient("HORIZONTAL", dark, clear)
    elseif point == "RIGHT" then tex:SetGradient("HORIZONTAL", clear, dark)
    elseif point == "BOTTOM" then tex:SetGradient("VERTICAL", dark, clear)
    else tex:SetGradient("VERTICAL", clear, dark) end
end

local Hide

local function Tick()
    if not active then return end
    local left = math.max(0, math.ceil(deadline - GetTime()))
    countdown:SetFormattedText(L["Logging out in %d s"], left)
    if left > 0 then return end
    if test then
        Hide()
    elseif ownTimer then
        ownTimer = false
        Logout()
    end
end

-- UIParent and the death screen cross-fade; respects the RP mode's own UI alpha
local function BaseAlpha() return ns.RPModeAlpha and ns.RPModeAlpha() or 1 end

-- The minimap's player arrow and blips ignore alpha, so its (unprotected) holder is hidden
local function SetMinimapHidden(hide)
    local holder = MeredanUIMinimap or MinimapCluster
    if not holder or InCombatLockdown() and holder:IsProtected() then return end
    if hide and holder:IsShown() then
        holder:Hide()
        minimapHidden = true
    elseif not hide and minimapHidden then
        holder:Show()
        minimapHidden = false
    end
end

local function OnUpdate(self, elapsed)
    if target > progress then
        progress = math.min(target, progress + elapsed / FADE_IN)
    else
        progress = math.max(target, progress - elapsed / FADE_OUT)
    end
    local eased = 1 - (1 - progress) ^ 3
    self:SetAlpha(eased)
    UIParent:SetAlpha(BaseAlpha() * (1 - eased))
    if progress == target then
        self:SetScript("OnUpdate", nil)
        if progress == 0 then
            self:Hide()
            UIParent:SetAlpha(BaseAlpha())
        end
    end
end

local function Fade(to)
    target = to
    if to == 0 then SetMinimapHidden(false) else SetMinimapHidden(true) end
    screen:SetScript("OnUpdate", OnUpdate)
end

function Hide(cancel)
    if not screen then return end
    if cancel and not test and not ownTimer then CancelLogout() end
    active, test, ownTimer = false, false, false
    if ticker then ticker:Cancel(); ticker = nil end
    Fade(0)
end

local function Create()
    -- parented to WorldFrame since UIParent gets faded out; scaled like the UI
    screen = CreateFrame("Frame", "MeredanUIHardcore", WorldFrame)
    screen:SetScale(UIParent:GetScale())
    screen:SetAllPoints(UIParent)
    screen:SetFrameStrata("FULLSCREEN_DIALOG")
    screen:EnableMouse(true) -- the world stays out of reach while the choice is open
    screen:EnableKeyboard(true)
    screen:SetScript("OnKeyDown", function(self, key)
        -- Escape closes the test only; every other key reaches the game
        local close = test and key == "ESCAPE"
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(not close) end
        if close then Hide() end
    end)
    screen:Hide()

    local shade = screen:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.6)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    Edge("LEFT", false, w * 0.25)
    Edge("RIGHT", false, w * 0.25)
    Edge("TOP", true, h * 0.3)
    Edge("BOTTOM", true, h * 0.3)

    title = screen:CreateFontString(nil, "OVERLAY")
    title:SetFont(ns.DISPLAY_FONT, 72, "")
    title:SetTextColor(unpack(RED))
    title:SetShadowOffset(0, -3)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetPoint("CENTER", 0, 90)
    title:SetText(L["YOU DIED"])

    sub = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(sub, 15, "")
    sub:SetTextColor(0.75, 0.72, 0.66)
    sub:SetShadowOffset(1, -1)
    sub:SetPoint("TOP", title, "BOTTOM", 0, -10)

    retry = ns.UI.Button(screen, L["Try again"], function()
        if test then return Hide() end
        if IsResting() or ownTimer then ownTimer = false; Logout() end -- outside, the game's countdown already runs
    end, 220)
    retry:SetHeight(32)
    retry.Text:SetFont(ns.DISPLAY_FONT, 15, "")
    retry:SetPoint("TOP", sub, "BOTTOM", 0, -36)

    countdown = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(countdown, 13, "")
    countdown:SetTextColor(0.6, 0.58, 0.54)
    countdown:SetPoint("TOP", retry, "BOTTOM", 0, -12)

    -- quiet way out, bottom right
    keep = CreateFrame("Button", nil, screen)
    keep:SetSize(140, 24)
    keep:SetPoint("BOTTOMRIGHT", -40, 32)
    keep.text = keep:CreateFontString(nil, "OVERLAY")
    ns.SetFont(keep.text, 12, "")
    keep.text:SetPoint("RIGHT")
    keep.text:SetText(L["Keep playing"])
    keep.text:SetTextColor(0.5, 0.48, 0.45, 0.8)
    keep:SetScript("OnEnter", function(self) self.text:SetTextColor(0.85, 0.82, 0.76, 1) end)
    keep:SetScript("OnLeave", function(self) self.text:SetTextColor(0.5, 0.48, 0.45, 0.8) end)
    keep:SetScript("OnClick", function() Hide(true) end)

    testLabel = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(testLabel, 12, "")
    testLabel:SetTextColor(unpack(ns.UI.ACCENT))
    testLabel:SetPoint("TOP", 0, -40)
    testLabel:SetText(L["Test – you won't be logged out"])
end

local function Show(isTest)
    if not screen then Create() end
    active, test = true, isTest and true or false
    local name, level = UnitName("player"), UnitLevel("player")
    sub:SetFormattedText(L["%s's journey ends at level %d."], name or "", level or 0)
    testLabel:SetShown(test)
    deadline = GetTime() + COUNTDOWN
    ownTimer = false
    if not test then
        if IsResting() then ownTimer = true else Logout() end
    end
    Tick()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.25, Tick)
    screen:SetScale(UIParent:GetScale())
    if not screen:IsShown() then screen:SetAlpha(0) end
    screen:Show()
    Fade(1)
end

function ns.HardcoreTest()
    if ns.HideSettings then ns.HideSettings() end
    Show(true)
end

ns:On("PLAYER_DEAD", function()
    if not Enabled() or RealHardcore() then return end
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" or instanceType == "arena" then return end -- battlegrounds don't count
    Show(false)
end)
-- brought back before the countdown ran out (resurrected, soulstone): stay in the game
ns:On("PLAYER_ALIVE", function() if active and not test and not UnitIsDeadOrGhost("player") then Hide(true) end end)
ns:On("PLAYER_UNGHOST", function() if active and not test then Hide(true) end end)
