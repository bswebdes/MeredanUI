-- Optional artwork (Look page): Blizzard's gryphons (Alliance) or wyverns (Horde) at both ends of the
-- bottom action bars, like the default interface. Parented to the bottom bar, so they hide and fade with it.
local _, ns = ...

local ASPECT = 178 / 167 -- atlas size
local left, right

local function Atlas(side)
    local horde = UnitFactionGroup("player") == "Horde"
    return ("ui-hud-actionbar-%s-%s"):format(horde and "wyvern" or "gryphon", side)
end

local function Create(parent, side)
    local f = CreateFrame("Frame", nil, parent)
    -- over every bar (the bars are LOW strata, each with its own levels), like Blizzard's end caps
    f:SetFrameStrata("MEDIUM")
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetAtlas(Atlas(side))
    return f
end

function ns.UpdateGryphons()
    if InCombatLockdown() then return ns.AfterCombat(ns.UpdateGryphons) end
    local bars = ns.actionBars
    local bottom = bars and bars[2] -- Shift bar, the lowest row
    if not bottom then return end
    local on = ns.db and ns.db.actionBarArt == true
    if not on then
        if left then left:Hide(); right:Hide() end
        return
    end
    left = left or Create(bottom, "left")
    right = right or Create(bottom, "right")
    -- outside the 6 x 2 extra blocks when they are shown
    -- (from the settings, not IsShown: after a reload in combat the bars aren't set up yet)
    local function On(key) return ns.ActionBarMode and ns.ActionBarMode(key) ~= "hidden" end
    local leftEdge = (bars[7] and On("bar7")) and bars[7] or bottom
    local rightEdge = (bars[8] and On("bar8")) and bars[8] or bottom
    local size = ns.Snap(36) -- one button row of the bottom bars (ActionBars.lua SIZE)
    local h = ns.Snap(size * 2.6)
    local w = ns.Snap(h * ASPECT)
    local overlap = ns.Snap(w * 0.2) -- the gryphon sits over the bar end
    left:SetSize(w, h)
    right:SetSize(w, h)
    left:ClearAllPoints()
    left:SetPoint("BOTTOMRIGHT", leftEdge, "BOTTOMLEFT", overlap, -ns.Snap(size * 0.15))
    right:ClearAllPoints()
    right:SetPoint("BOTTOMLEFT", rightEdge, "BOTTOMRIGHT", -overlap, -ns.Snap(size * 0.15))
    left:Show()
    right:Show()
end

ns:On("PLAYER_LOGIN", function()
    if ns.OnLayout then ns.OnLayout(function() C_Timer.After(0, ns.UpdateGryphons) end) end
    C_Timer.After(0, ns.UpdateGryphons)
end)
