-- Optional artwork (Look page): end caps at both ends of the bottom action bars, like the default
-- interface. Classes with their own art (Media/EndCaps) get their creature, everyone else Blizzard's
-- gryphons (Alliance) or wyverns (Horde). Parented to the bottom bar, so they hide and fade with it.
-- Size and position can be tuned in developer mode (/mui endcap) while the art is being designed.
local _, ns = ...
local L = ns.L

local GRYPHON_ASPECT = 178 / 167 -- atlas size
-- Own art: drawn facing right (the left cap), mirrored for the right one. 512x512 files with the
-- creature at the bottom; top = empty rows above it. scale/x/y: tuned in game with /mui endcap.
local CLASS_ART = {
    ROGUE = { file = "EndCaps\\Rogue", top = 77 / 512, aspect = 512 / 435, scale = 1.3, x = 34, y = 2 },
}
local left, right

local function Art()
    local class = select(2, UnitClass("player"))
    return CLASS_ART[class]
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
        if side == "left" then frame.tex:SetTexCoord(0, 1, art.top, 1) else frame.tex:SetTexCoord(1, 0, art.top, 1) end
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
    local scale = ns.db.endcapScale or (art and art.scale) or 1
    local dx = ns.db.endcapX or (art and art.x) or 0
    local dy = ns.db.endcapY or (art and art.y) or 0
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

local function Values()
    return ("scale %.2f  x %d  y %d"):format(ns.db.endcapScale or 1, ns.db.endcapX or 0, ns.db.endcapY or 0)
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
            ns.db[key] = value
            ns.UpdateGryphons()
        end
    end
    page:AddSlider(L["Size"], 0.3, 2.5, 0.05, function() return ns.db.endcapScale or 1 end, Setter("endcapScale"), function(v) return ("%.2f"):format(v) end, 1)
    page:AddSlider(L["Horizontal"], -80, 80, 1, function() return ns.db.endcapX or 0 end, Setter("endcapX"), function(v) return ("%d"):format(v) end, 0)
    page:AddSlider(L["Vertical"], -80, 80, 1, function() return ns.db.endcapY or 0 end, Setter("endcapY"), function(v) return ("%d"):format(v) end, 0)
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
