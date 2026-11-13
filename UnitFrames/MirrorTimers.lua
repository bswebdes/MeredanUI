-- Restyles Blizzard's mirror timers (breath, exhaustion, feign death) in the MUI look.
-- Visual only: Blizzard's bars stay (Edit Mode still moves them). Blizzard resets the bar
-- texture on every start (Setup), so we reapply ours there.
local _, ns = ...

local HEIGHT = 18
local COLORS = {
    BREATH = { 0.15, 0.55, 1 },
    EXHAUSTION = { 1, 0.7, 0.1 },      -- swimming too far out
    FEIGNDEATH = { 0.45, 0.8, 0.35 },
    DEATH = { 0.85, 0.25, 0.25 },
}

local function ApplyBar(frame)
    local bar = frame.StatusBar
    bar:SetStatusBarTexture(ns.MEDIA .. "BarShade")
    local color = COLORS[frame.timer] or COLORS.BREATH
    bar:SetStatusBarColor(color[1], color[2], color[3])
end

local function Style(frame)
    local bar = frame.StatusBar
    if not bar then return end
    -- Hide Blizzard's border, text box and background
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    bar:SetHeight(HEIGHT)
    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.04, 0.05, 0.9)
    ns.AddThinShell(bar)
    -- Text centered inside the bar instead of the box below
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
