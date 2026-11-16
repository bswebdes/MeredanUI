-- Blizzard's top center widgets (battleground flag/score, world PvP objectives ...):
--   Blizzard anchors them 15 px below the screen edge, right on top of the XP bar. Move them below
--   the lowest visible top bar. The faction score rows become one versus board (below).
-- Only alpha on Blizzard regions; our art lives in our own frame (Blizzard's Setup resets the
-- texture kit on every update, our hook runs after it).
local _, ns = ...

local GAP = 6
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EMBLEM = { alliance = "AllianceEmblem", horde = "HordeEmblem" }
local FACTION_RGB = { alliance = { 0.30, 0.55, 1 }, horde = { 0.90, 0.22, 0.20 } }

local function Place()
    local container = UIWidgetTopCenterContainerFrame
    if not container then return end
    local below = ns.XPBarBottom and ns.XPBarBottom()
    container:ClearAllPoints()
    if below then
        container:SetPoint("TOP", below, "BOTTOM", 0, -(ns.Snap(GAP) + 2 * ns.ThinShellReach()))
    else
        container:SetPoint("TOP", UIParent, "TOP", 0, -ns.Snap(ns.SCREEN_MARGIN))
    end
end
ns.PlaceTopWidgets = Place

-- "alliance_icon_horde_flag" -> team alliance, carried flag horde; "x_icon_and_flag" -> own flag
local function ParseKit(atlas)
    if type(atlas) ~= "string" then return end
    local team, flag = atlas:lower():match("^(%a+)_icon_(%a+)_flag")
    if not team then return atlas:lower():match("^(%a+)_") end
    return team, flag == "and" and team or flag
end

-- One versus board instead of Blizzard's two stacked rows:
--
--   [A-emblem] 2  <> <> <>    <>    <> <> <>  1 [H-emblem]
--      ^flag (pulses while the team holds a flag)
--
-- Scores like "2/3" become gems (filled = captured); any other text (other battlegrounds) is shown
-- as text. Alliance always left, Horde right. Blizzard's widgets stay (layout, tooltips) but invisible.
local BOARD_W, BOARD_H, EMBLEM_SIZE, GEM = 300, 40, 40, 6
local MAX_GEMS = 5
local board
local data = {}        -- team -> { score, max, text, flag }
local hidden = setmetatable({}, { __mode = "k" })

local function Side(team, mirror)
    local side = {}
    local c = FACTION_RGB[team]
    local sign = mirror and -1 or 1
    local edge = mirror and "RIGHT" or "LEFT"
    local inward = mirror and "LEFT" or "RIGHT"
    local glow = board:CreateTexture(nil, "BORDER")
    glow:SetTexture(WHITE)
    glow:SetPoint("TOP" .. edge)
    glow:SetPoint("BOTTOM" .. edge)
    glow:SetWidth(ns.Snap(BOARD_W * 0.45))
    local strong, none = CreateColor(c[1], c[2], c[3], 0.45), CreateColor(c[1], c[2], c[3], 0)
    if mirror then glow:SetGradient("HORIZONTAL", none, strong) else glow:SetGradient("HORIZONTAL", strong, none) end
    local line = board:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetPoint("TOP" .. edge)
    line:SetPoint("BOTTOM" .. edge)
    line:SetWidth(2 * ns.PixelSize())
    line:SetVertexColor(c[1], c[2], c[3], 1)

    side.emblem = board:CreateTexture(nil, "OVERLAY")
    side.emblem:SetAtlas(EMBLEM[team])
    side.emblem:SetSize(ns.Snap(EMBLEM_SIZE + 8), ns.Snap(EMBLEM_SIZE + 8))
    side.emblem:SetPoint("CENTER", board, edge, sign * ns.Snap(EMBLEM_SIZE / 2 - 2), 0)
    side.score = ns.CreateText(board, 22, mirror and "RIGHT" or "LEFT", "OUTLINE", "bold")
    side.score:SetPoint(edge, board, edge, sign * ns.Snap(EMBLEM_SIZE + 6), 0)
    side.score:SetTextColor(1, 1, 1)
    side.text = ns.CreateText(board, 13, mirror and "RIGHT" or "LEFT", "OUTLINE", "bold")
    side.text:SetPoint(edge, board, edge, sign * ns.Snap(EMBLEM_SIZE + 6), 0)
    side.text:SetPoint(inward, board, "CENTER", -sign * ns.Snap(14), 0)
    side.text:SetTextColor(1, 1, 1)
    side.gems = {}
    for i = 1, MAX_GEMS do
        local gem = ns.UI.Diamond(board, GEM, c)
        gem:SetPoint("CENTER", side.score, inward, sign * ns.Snap(14 + (i - 1) * 17), 0)
        side.gems[i] = gem
    end

    -- carried flag on the emblem's inner top corner, pulsing
    local flag = board:CreateTexture(nil, "OVERLAY", nil, 3)
    flag:SetTexture(ns.MEDIA .. "Icons\\Flag")
    flag:SetSize(ns.Snap(16), ns.Snap(16))
    flag:SetPoint("CENTER", side.emblem, "TOP" .. inward, -sign * ns.Snap(8), -ns.Snap(8))
    local pulse = flag:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.6)
    flag:Hide()
    side.flag, side.pulse = flag, pulse
    return side
end

local function CreateBoard()
    board = CreateFrame("Frame", "MeredanUIScoreBoard", UIParent)
    board:SetSize(ns.Snap(BOARD_W), ns.Snap(BOARD_H))
    board:SetFrameStrata("LOW")
    local bg = board:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.04, 0.03, 0.88)
    local shine = board:CreateTexture(nil, "BACKGROUND", nil, 1)
    shine:SetTexture(WHITE)
    shine:SetPoint("TOPLEFT")
    shine:SetPoint("TOPRIGHT")
    shine:SetHeight(ns.Snap(BOARD_H / 2))
    shine:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.06))
    ns.RuneFrame(board, { small = true })
    local center = ns.UI.Diamond(board, 5)
    center:SetPoint("CENTER")
    board.sides = { alliance = Side("alliance", false), horde = Side("horde", true) }
    board:Hide()
end

local function Render()
    if not board then CreateBoard() end
    local any = false
    for team, side in pairs(board.sides) do
        local d = data[team]
        local score, max = d and d.score, d and d.max
        local gems = score and max and max <= MAX_GEMS
        side.score:SetShown(gems and true or false)
        side.text:SetShown(not gems and d ~= nil)
        if gems then
            side.score:SetText(score)
        else
            side.text:SetText(d and d.text or "")
        end
        for i, gem in ipairs(side.gems) do
            gem:SetShown(gems and i <= max or false)
            if gems and i <= max then
                local on = i <= score
                gem:SetDesaturated(not on)
                gem:SetAlpha(on and 1 or 0.35)
            end
        end
        local fc = d and d.flag and FACTION_RGB[d.flag]
        if fc then
            side.flag:SetVertexColor(fc[1], fc[2], fc[3], 1)
            side.flag:Show()
            if not side.pulse:IsPlaying() then side.pulse:Play() end
        else
            side.pulse:Stop()
            side.flag:Hide()
        end
        side.emblem:SetDesaturated(d == nil)
        any = any or d ~= nil
    end
    board:ClearAllPoints()
    board:SetPoint("TOP", UIWidgetTopCenterContainerFrame, "TOP", 0, 0)
    board:SetShown(any)
end

local function Conceal(widget, conceal)
    local a = conceal and 0 or 1
    widget.Icon:SetAlpha(a)
    widget.Text:SetAlpha(a)
    local dynamic = widget.DynamicIconButton
    if dynamic and dynamic.Icon then dynamic.Icon:SetAlpha(a) end
    if widget.Flash then widget.Flash:SetAlpha(a) end
end

local function Style(widget, container)
    if container ~= UIWidgetTopCenterContainerFrame or not (widget.Icon and widget.Text) then return end
    local team, carried = ParseKit(widget.Icon:GetAtlas())
    if not (team and EMBLEM[team]) then -- other icon-and-text widgets stay Blizzard's
        if hidden[widget] then Conceal(widget, false) end
        return
    end
    if not hidden[widget] then
        hidden[widget] = team
        widget:HookScript("OnHide", function(self)
            local t = hidden[self]
            if t and data[t] and data[t].widget == self then data[t] = nil; Render() end
        end)
    end
    hidden[widget] = team
    Conceal(widget, true)
    local text = widget.Text:GetText() or ""
    local score, max = text:match("^%s*(%d+)%s*/%s*(%d+)%s*$")
    local dynamic = widget.DynamicIconButton
    local holding = dynamic and dynamic:IsShown() and dynamic.Icon and dynamic.Icon:IsShown()
        and dynamic.Icon:GetAtlas()
    local flag
    if holding then
        local _, f = ParseKit(holding)
        flag = f or carried
    end
    data[team] = { widget = widget, text = text, score = tonumber(score), max = tonumber(max), flag = flag }
    Render()
end

ns:On("PLAYER_LOGIN", function()
    if not UIWidgetTopCenterContainerFrame then return end
    if UIWidgetTemplateIconAndTextMixin and UIWidgetTemplateIconAndTextMixin.Setup then
        hooksecurefunc(UIWidgetTemplateIconAndTextMixin, "Setup", Style)
    end
    -- widgets built before our hook (/reload inside a battleground)
    -- (they copied the unhooked Setup at creation, so hook them directly)
    for _, widget in pairs(UIWidgetTopCenterContainerFrame.widgetFrames or {}) do
        if widget.Icon and widget.Text and widget.Setup then hooksecurefunc(widget, "Setup", Style) end
        Style(widget, UIWidgetTopCenterContainerFrame)
    end
    -- the XP and pet bars come and go (level, pet, visibility mode)
    for _, name in ipairs({ "MeredanUIXPBar", "MeredanUIPetXPBar" }) do
        local bar = _G[name]
        if bar then
            bar:HookScript("OnShow", Place)
            bar:HookScript("OnHide", Place)
        end
    end
    ns.OnLayout(Place)
    Place()
end)
