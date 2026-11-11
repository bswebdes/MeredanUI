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
    f:SetFrameLevel(parent:GetFrameLevel() + 20) -- over the buttons, like Blizzard's end caps
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    f.tex:SetAtlas(Atlas(side))
    return f
end

-- Key binding, count and macro texts above the gryphons: own layer per button (out of combat only;
-- anchors stay on the button)
local function LiftTexts(bar, level)
    for _, button in ipairs(bar and bar.buttons or {}) do
        if not button.muiTextLayer then
            local layer = CreateFrame("Frame", nil, button)
            layer:SetAllPoints()
            for _, key in ipairs({ "HotKey", "Count", "Name" }) do
                if button[key] then button[key]:SetParent(layer) end
            end
            button.muiTextLayer = layer
        end
        button.muiTextLayer:SetFrameLevel(level)
    end
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
    local leftEdge = (bars[7] and bars[7]:IsShown()) and bars[7] or bottom
    local rightEdge = (bars[8] and bars[8]:IsShown()) and bars[8] or bottom
    local size = bottom:GetHeight() > 0 and bottom:GetHeight() or 36 -- one button row
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
    for _, i in ipairs({ 2, 3, 7, 8 }) do LiftTexts(bars[i], left:GetFrameLevel() + 1) end
end

ns:On("PLAYER_LOGIN", function()
    if ns.OnLayout then ns.OnLayout(function() C_Timer.After(0, ns.UpdateGryphons) end) end
    C_Timer.After(0, ns.UpdateGryphons)
end)
