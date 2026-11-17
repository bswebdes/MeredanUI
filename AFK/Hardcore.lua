-- Hardcore mode (fun, opt-in: hardcoreMode): on death the screen darkens, "YOU DIED" in red Cinzel,
-- "Try again" logs out to character select (20 s countdown outside rested areas). A quiet "Keep playing"
-- bottom right cancels it and Blizzard's release popup takes over as usual.
-- Below: who killed you and with what (Blizzard's death recap), and a mocking quote from a
-- famous NPC (AFK/HardcoreQuotes.lua).
-- Logout() only works right from a click (from the death event it is ADDON_ACTION_FORBIDDEN), so it
-- starts on "Try again": instant in cities and inns, otherwise the game counts 20 seconds.
-- The interface fades out while the death screen fades in, and comes back when it closes.
-- Off on Blizzard's real hardcore realms. Settings > Appearance has a test button (never logs out).
local _, ns = ...
local L = ns.L

local COUNTDOWN = 20
local FADE_IN, FADE_OUT = 1.5, 0.4
local RED = { 0.86, 0.16, 0.12 }

local screen, deathNum, title, sub, killer, killerIcon, quote, speaker, countdown, retry, keep, testLabel
local progress, target = 0, 0 -- 0 = interface visible, 1 = death screen
local minimapHidden
local active, test, loggingOut, deadline, ticker

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
    if not deadline then return end
    local left = math.max(0, math.ceil(deadline - GetTime()))
    countdown:SetFormattedText(L["Logging out in %d s"], left)
    if left > 0 then return end
    if test then Hide() end -- a real logout is done by the game
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
    if cancel and loggingOut then CancelLogout() end
    active, test, loggingOut, deadline = false, false, false, nil
    if ticker then ticker:Cancel(); ticker = nil end
    Fade(0)
end

local function Create()
    -- in UIParent's tree (so it reliably sits above every interface button and catches clicks),
    -- but ignoring its alpha since UIParent gets faded out
    screen = CreateFrame("Frame", "MeredanUIHardcore", UIParent)
    screen:SetIgnoreParentAlpha(true)
    screen:SetAllPoints(UIParent)
    screen:SetToplevel(true)
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

    -- death number above the title ("#23")
    deathNum = screen:CreateFontString(nil, "OVERLAY")
    deathNum:SetFont(ns.DISPLAY_FONT, 26, "")
    deathNum:SetTextColor(0.79, 0.70, 0.48)
    deathNum:SetShadowOffset(0, -2)
    deathNum:SetShadowColor(0, 0, 0, 1)
    deathNum:SetPoint("BOTTOM", title, "TOP", 0, 2)

    sub = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(sub, 15, "")
    sub:SetTextColor(0.75, 0.72, 0.66)
    sub:SetShadowOffset(1, -1)
    sub:SetPoint("TOP", title, "BOTTOM", 0, -10)

    -- killer: spell icon + "Hogger · Melee"
    killer = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(killer, 14, "")
    killer:SetTextColor(0.9, 0.86, 0.78)
    killer:SetShadowOffset(1, -1)
    killer:SetPoint("TOP", sub, "BOTTOM", 10, -14)
    killerIcon = screen:CreateTexture(nil, "OVERLAY")
    killerIcon:SetSize(20, 20)
    killerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    killerIcon:SetPoint("RIGHT", killer, "LEFT", -6, 0)

    retry = ns.UI.Button(screen, L["Try again"], function()
        if test then return Hide() end
        if loggingOut then return end
        loggingOut = true
        Logout() -- from this click: allowed (instant when resting, else the game's 20 s)
        if not IsResting() then
            deadline = GetTime() + COUNTDOWN
            Tick()
        end
    end, 220)
    retry:SetHeight(32)
    retry.Text:SetFont(ns.DISPLAY_FONT, 15, "")
    retry:SetPoint("TOP", sub, "BOTTOM", 0, -60)

    countdown = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(countdown, 13, "")
    countdown:SetTextColor(0.6, 0.58, 0.54)
    countdown:SetPoint("TOP", retry, "BOTTOM", 0, -12)

    -- the quote, set apart further down
    quote = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(quote, 20, "")
    quote:SetTextColor(0.85, 0.82, 0.76)
    quote:SetShadowOffset(1, -1)
    quote:SetWidth(720)
    quote:SetPoint("TOP", countdown, "BOTTOM", 0, -90)
    speaker = screen:CreateFontString(nil, "OVERLAY")
    speaker:SetFont(ns.DISPLAY_FONT, 14, "")
    speaker:SetTextColor(0.79, 0.67, 0.45) -- bronze gold like section titles
    speaker:SetShadowOffset(1, -1)
    speaker:SetPoint("TOP", quote, "BOTTOM", 0, -10)

    -- quiet way out, bottom right: a real button, faint until hovered
    keep = ns.UI.Button(screen, L["Keep playing"], function() Hide(true) end, 150)
    keep:SetPoint("BOTTOMRIGHT", -40, 40)
    keep:SetAlpha(0.45)
    keep:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
    keep:HookScript("OnLeave", function(self) self:SetAlpha(0.45) end)

    testLabel = screen:CreateFontString(nil, "OVERLAY")
    ns.SetFont(testLabel, 12, "")
    testLabel:SetTextColor(unpack(ns.UI.ACCENT))
    testLabel:SetPoint("TOP", 0, -40)
    testLabel:SetText(L["Test – you won't be logged out"])
end

-- Last event of Blizzard's death recap: who and what. Values can be secret; then nothing shows.
local function Plain(v) if not issecretvalue(v) then return v end end

local function KillerInfo()
    if not (C_DeathRecap and C_DeathRecap.HasRecapEvents and C_DeathRecap.HasRecapEvents()) then return end
    local events = C_DeathRecap.GetRecapEvents()
    local e = type(events) == "table" and events[1]
    if not e then return end
    local kind, spellId = Plain(e.event), Plain(e.spellId)
    local source = not Plain(e.hideCaster) and Plain(e.sourceName) or nil
    local what, icon
    if kind == "SWING_DAMAGE" then
        what = ACTION_SWING or L["Melee"]
        icon = C_Spell.GetSpellTexture(Constants.DeathRecapConsts and Constants.DeathRecapConsts.SWING_DAMAGE_SPELL_ID or 6603)
    elseif kind == "ENVIRONMENTAL_DAMAGE" then
        local env = Plain(e.environmentalType)
        what = env and _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. env:upper()]
        icon = "Interface\\Icons\\ability_creature_cursed_05"
    else
        what = Plain(e.spellName)
        icon = spellId and C_Spell.GetSpellTexture(spellId)
    end
    return source, what, icon
end

local function ShowKiller(source, what, icon)
    local text = source and what and (source .. "  ·  " .. what) or source or what
    killer:SetText(text or "")
    killerIcon:SetTexture(icon)
    killerIcon:SetShown(text ~= nil and icon ~= nil)
end

local lastQuote
local function PickQuote()
    local list = ns.HARDCORE_QUOTES
    local i
    repeat i = math.random(#list) until i ~= lastQuote or #list < 2
    lastQuote = i
    local q = list[i]
    local de = GetLocale() == "deDE"
    quote:SetText(de and ("„" .. q[4] .. "“") or ("\"" .. q[3] .. "\""))
    speaker:SetText("— " .. (de and q[2] or q[1]))
end

-- Deaths of this character: Blizzard's statistic "Total deaths" (id 60, counts from before mUI),
-- else mUI's own count from PLAYER_DEAD. The statistic can lag the death event by a moment.
local TOTAL_DEATHS = 60
local function DeathCount()
    local stat = GetStatistic and ns.Plain(GetStatistic(TOTAL_DEATHS))
    local n = tonumber(stat)
    local own = ns.char and ns.char.deaths or 0
    if n and n > 0 then return math.max(n, own) end
    return own > 0 and own or nil
end
local function UpdateDeathNum()
    if not deathNum then return end
    local n = DeathCount()
    deathNum:SetText(n and ("#" .. n) or "")
end

local function Show(isTest)
    if not screen then Create() end
    active, test = true, isTest and true or false
    local name, level = UnitName("player"), UnitLevel("player")
    sub:SetFormattedText(L["%s's journey ends at level %d."], name or "", level or 0)
    testLabel:SetShown(test)
    UpdateDeathNum()
    C_Timer.After(1, function() if active then UpdateDeathNum() end end) -- statistic catches up
    PickQuote()
    if test then
        ShowKiller(L["Hogger"], ACTION_SWING or L["Melee"], C_Spell.GetSpellTexture(6603))
    else
        ShowKiller(nil)
        -- the recap is filled right after death
        C_Timer.After(0.3, function() if active and not test then ShowKiller(KillerInfo()) end end)
    end
    loggingOut = false
    countdown:SetText("")
    -- the test counts down by itself and closes; a real death waits for "Try again"
    deadline = test and (GetTime() + COUNTDOWN) or nil
    Tick()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.25, Tick)
    if not screen:IsShown() then screen:SetAlpha(0) end
    screen:Show()
    Fade(1)
end

function ns.HardcoreTest()
    if ns.HideSettings then ns.HideSettings() end
    Show(true)
end

ns:On("PLAYER_DEAD", function()
    if ns.char then ns.char.deaths = (ns.char.deaths or 0) + 1 end
    if not Enabled() or RealHardcore() then return end
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" or instanceType == "arena" then return end -- battlegrounds don't count
    Show(false)
end)
-- brought back before the countdown ran out (resurrected, soulstone): stay in the game
ns:On("PLAYER_ALIVE", function() if active and not test and not UnitIsDeadOrGhost("player") then Hide(true) end end)
ns:On("PLAYER_UNGHOST", function() if active and not test then Hide(true) end end)
