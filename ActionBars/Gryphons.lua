-- Optional artwork (Look page): end caps at both ends of the bottom action bars, like the default
-- interface. Classes with their own art (Media/EndCaps) get their creature, everyone else Blizzard's
-- gryphons (Alliance) or wyverns (Horde). Parented to the bottom bar, so they hide and fade with it.
-- Size and position can be tuned in developer mode (/mui endcap) while the art is being designed.
local _, ns = ...
local L = ns.L

local GRYPHON_ASPECT = 178 / 167 -- atlas size
-- Class animals: drawn facing right (the right cap, looking outward), mirrored for the left one. Tight crops at the
-- bottom-left of a 512x512 texture; right/top = tex coords of the art, aspect = art width / height.
-- scale/x/y: tuned in game with /mui endcap.
local CLASS_ART = {
    WARRIOR = { file = "EndCaps\\Warrior", right = 419 / 512, top = 0, aspect = 419 / 512, scale = 1.15 },
    PALADIN = { file = "EndCaps\\Paladin", right = 1, top = 18 / 512, aspect = 512 / 494, scale = 0.95 },
    HUNTER = { file = "EndCaps\\Hunter", right = 477 / 512, top = 0, aspect = 477 / 512, scale = 1.1 },
    ROGUE = { file = "EndCaps\\Rogue", right = 1, top = 215 / 512, aspect = 512 / 297, scale = 0.8 },
    PRIEST = { file = "EndCaps\\Priest", right = 1, top = 12 / 512, aspect = 512 / 500, scale = 1.05 },
    SHAMAN = { file = "EndCaps\\Shaman", right = 462 / 512, top = 0, aspect = 462 / 512, scale = 1.1 },
    MAGE = { file = "EndCaps\\Mage", right = 388 / 512, top = 0, aspect = 388 / 512, scale = 1.15 },
    WARLOCK = { file = "EndCaps\\Warlock", right = 436 / 512, top = 0, aspect = 436 / 512, scale = 1.1 },
    DRUID = { file = "EndCaps\\Druid", right = 328 / 512, top = 0, aspect = 328 / 512, scale = 1.15 },
}
local left, right

local function Class() return select(2, UnitClass("player")) end
local function Art() return CLASS_ART[Class()] end

-- developer tuning per class, so fitting one animal doesn't move the others
local function Tune()
    ns.db.endcapTune = ns.db.endcapTune or {}
    local t = ns.db.endcapTune[Class()] or {}
    ns.db.endcapTune[Class()] = t
    return t
end

local function Create(parent)
    local f = CreateFrame("Frame", nil, parent)
    -- over every bar (the bars are LOW strata, each with its own levels), like Blizzard's end caps
    f:SetFrameStrata("MEDIUM")
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints()
    return f
end

local function Texture(frame, side, art)
    if art then
        frame.tex:SetTexture(ns.MEDIA .. art.file)
        local r = art.right or 1
        -- like Blizzard's gryphons the animals look away from the bar, so the left one is mirrored
        if side == "left" then frame.tex:SetTexCoord(r, 0, art.top, 1) else frame.tex:SetTexCoord(0, r, art.top, 1) end
    else
        local horde = UnitFactionGroup("player") == "Horde"
        frame.tex:SetTexCoord(0, 1, 0, 1)
        frame.tex:SetAtlas(("ui-hud-actionbar-%s-%s"):format(horde and "wyvern" or "gryphon", side))
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
    left = left or Create(bottom)
    right = right or Create(bottom)
    local art = Art()
    Texture(left, "left", art)
    Texture(right, "right", art)
    -- outside the 6 x 2 extra blocks when they are shown
    -- (from the settings, not IsShown: after a reload in combat the bars aren't set up yet)
    local function On(key) return ns.ActionBarMode and ns.ActionBarMode(key) ~= "hidden" end
    local leftEdge = (bars[7] and On("bar7")) and bars[7] or bottom
    local rightEdge = (bars[8] and On("bar8")) and bars[8] or bottom
    local size = ns.Snap(36) -- one button row of the bottom bars (ActionBars.lua SIZE)
    -- per-art defaults; developer tuning (/mui endcap) overrides them while new art is fitted
    local tune = Tune()
    local scale = tune.scale or (art and art.scale) or 1
    local dx = tune.x or (art and art.x) or 0
    local dy = tune.y or (art and art.y) or 0
    local h = ns.Snap(size * 2.6 * scale)
    local w = ns.Snap(h * (art and art.aspect or GRYPHON_ASPECT))
    local overlap = ns.Snap(art and size * 0.15 or w * 0.2) -- the cap sits over the bar end
    left:SetSize(w, h)
    right:SetSize(w, h)
    left:ClearAllPoints()
    left:SetPoint("BOTTOMRIGHT", leftEdge, "BOTTOMLEFT", overlap + dx, -ns.Snap(size * 0.15) + dy)
    right:ClearAllPoints()
    right:SetPoint("BOTTOMLEFT", rightEdge, "BOTTOMRIGHT", -overlap - dx, -ns.Snap(size * 0.15) + dy)
    left:Show()
    right:Show()
end

-- Developer panel: size and position of the end caps, values saved and printed on close ------------

local panel

local function Current(key)
    local art = Art()
    return Tune()[key] or (art and art[key]) or (key == "scale" and 1 or 0)
end

local function Values()
    return ("%s  scale %.2f  x %d  y %d"):format(Class(), Current("scale"), Current("x"), Current("y"))
end

local function CreatePanel()
    local UI = ns.UI
    panel = CreateFrame("Frame", "MeredanUIEndcapTuner", UIParent)
    panel:SetSize(340, 176)
    panel:SetPoint("CENTER", 0, 120)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    UI.Box(panel, ns.STYLE.panelColor, true)
    ns.RuneFrame(panel, { small = true })
    local title = UI.Title(panel, 14, "LEFT")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L["End caps (developer)"])
    UI.IconButton(panel, "Close", function() panel:Hide() end, 22):SetPoint("TOPRIGHT", -10, -10)
    panel:SetScript("OnHide", function() ns.Print(L["End caps: %s"], Values()) end)

    local holder = CreateFrame("Frame", nil, panel)
    holder:SetPoint("TOPLEFT", 16, -46)
    holder:SetPoint("BOTTOMRIGHT", -16, 12)
    local page = UI.Page(holder)
    local function Setter(key)
        return function(value)
            Tune()[key] = value
            ns.UpdateGryphons()
        end
    end
    page:AddSlider(L["Size"], 0.3, 2.5, 0.05, function() return Current("scale") end, Setter("scale"), function(v) return ("%.2f"):format(v) end, 1)
    page:AddSlider(L["Horizontal"], -80, 80, 1, function() return Current("x") end, Setter("x"), function(v) return ("%d"):format(v) end, 0)
    page:AddSlider(L["Vertical"], -80, 80, 1, function() return Current("y") end, Setter("y"), function(v) return ("%d"):format(v) end, 0)
    tinsert(UISpecialFrames, "MeredanUIEndcapTuner")
end

ns.AddCommand("endcap", L["End caps: size and position"], function()
    if not ns.db.actionBarArt then ns.Print(L["Turn on the action bar art first (Look page)."]) end
    -- a new frame starts shown, so toggling it right away would close it again
    if not panel then CreatePanel() return end
    panel:SetShown(not panel:IsShown())
end, true)

ns:On("PLAYER_LOGIN", function()
    if ns.OnLayout then ns.OnLayout(function() C_Timer.After(0, ns.UpdateGryphons) end) end
    C_Timer.After(0, ns.UpdateGryphons)
end)
