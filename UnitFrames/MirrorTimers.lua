-- Atem-, Erschöpfungs- und Totstellen-Leiste (Blizzards „Mirror Timer“) im MUI-Look: flacher Balken
-- mit unserer Textur, dunkler Hintergrund, 1-px-Rahmen, Text in der Leiste (Benny 2026-11-06).
-- Nur Optik: Blizzards Leiste bleibt (Bearbeitungsmodus „Timerleisten“ verschiebt sie weiter);
-- Blizzard setzt bei jedem Start die Balkentextur neu (Setup) – dann unsere wieder.
local _, ns = ...

local HEIGHT = 18
local COLORS = {
    BREATH = { 0.15, 0.55, 1 },        -- Atem
    EXHAUSTION = { 1, 0.7, 0.1 },      -- Erschöpfung (zu weit draußen)
    FEIGNDEATH = { 0.45, 0.8, 0.35 },  -- Totstellen
    DEATH = { 0.85, 0.25, 0.25 },
}

local function ApplyBar(frame)
    local bar = frame.StatusBar
    bar:SetStatusBarTexture(ns.STYLE.barTexture)
    local color = COLORS[frame.timer] or COLORS.BREATH
    bar:SetStatusBarColor(color[1], color[2], color[3])
end

local function Style(frame)
    local bar = frame.StatusBar
    if not bar then return end
    -- Blizzards Rahmen, Textkasten und Hintergrund durchsichtig
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    bar:SetHeight(HEIGHT)
    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.05, 0.9)
    ns.AddBorder(bar)
    -- Text mittig in der Leiste statt im Kasten darunter
    local text = frame.Text
    if text then
        text:SetParent(bar)
        text:ClearAllPoints()
        text:SetPoint("CENTER", bar, "CENTER", 0, 0)
        ns.SetFont(text, 12, "OUTLINE")
        text:SetTextColor(1, 1, 1)
        text:SetDrawLayer("OVERLAY", 7)
    end
    ApplyBar(frame)
    hooksecurefunc(frame, "Setup", ApplyBar)
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER or not MirrorTimerContainer then return end
    for _, frame in ipairs(MirrorTimerContainer.mirrorTimers or {}) do Style(frame) end
end)
