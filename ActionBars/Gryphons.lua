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
    f:SetFrameLevel(math.max(parent:GetFrameLevel() - 1, 0)) -- behind the buttons: icons and key texts stay readable
    f.tex = f:CreateTexture(nil, "BACKGROUND")
    f.tex:SetAllPoints()
    f.tex:SetAtlas(Atlas(side))
    return f
end

function ns.UpdateGryphons()
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
    local leftEdge = (bars[7] and bars[7]:IsShown()) and bars[7] or bottom
    local rightEdge = (bars[8] and bars[8]:IsShown()) and bars[8] or bottom
    local size = bottom:GetHeight() > 0 and bottom:GetHeight() or 36 -- one button row
    local h = ns.Snap(size * 2.6)
    local w = ns.Snap(h * ASPECT)
    local overlap = ns.Snap(w * 0.22) -- the inner part tucks behind the end buttons
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
