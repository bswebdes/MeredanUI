-- Bagnon in the mUI look, through Bagnon's own skin API (Bagnon.Skins:Register, see the BagBrother
-- wiki "Skins API"): flat panel with a 1 px black border, mUI fonts, and the inventory where mUI's
-- bags sit (bottom right above the micro menu). Nothing of Bagnon's frames is touched directly;
-- the profile values (skin, colours, position) are Bagnon's own settings.
-- Switch: ns.db.bagnonStyle (Bags page, only while Bagnon is active). Like mUI's own windows the
-- inventory has a fixed spot: set on every login and locked with Bagnon's own lock option.
local _, ns = ...

local SKIN = "MeredanUI"
local FRAMES = { "inventory", "bank", "vault", "guild" }

local titleFont, titleFontH

local function Fonts()
    if titleFont then return end
    titleFont = CreateFont("MeredanUIBagnonTitle")
    titleFont:SetFont(ns.FontFor("bold"), ns.FontPx(13), "")
    titleFont:SetTextColor(unpack(ns.UI.TEXT))
    titleFont:SetShadowOffset(1, -1)
    titleFont:SetShadowColor(0, 0, 0, 1)
    titleFontH = CreateFont("MeredanUIBagnonTitleHighlight")
    titleFontH:CopyFontObject(titleFont)
    titleFontH:SetTextColor(unpack(ns.UI.ACCENT))
end

-- Bagnon's colour pickers are ignored on purpose: the mUI panel colour and black border always win
local function Paint(bg)
    bg.Center:SetColorTexture(unpack(ns.STYLE.panelColor))
    for _, key in ipairs({ "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }) do
        if bg[key] then bg[key]:SetColorTexture(0, 0, 0, 1) end
    end
end

local function Register(Bagnon)
    Fonts()
    Bagnon.Skins:Register({
        id = SKIN,
        template = "BagnonOnePixelTemplate", -- ships with Bagnon: Center + four 1 px edges
        font = titleFont, fontH = titleFontH,
        x = 1, y = 1, x1 = -1, y1 = -1, margin = 2,
        closeX = Bagnon.IsMainline and -4 or nil, closeY = Bagnon.IsMainline and -4 or nil,
        load = Paint,
        centerColor = Paint,
        borderColor = Paint,
    })
end

-- Profiles in use: the account-wide one plus the current character's own (if it has one)
local function Profiles(Bagnon)
    local list = { Bagnon.sets and Bagnon.sets.global }
    local realm = GetRealmName()
    local own = Bagnon.sets and Bagnon.sets.profiles and Bagnon.sets.profiles[realm]
    for _, profile in pairs(own or {}) do list[#list + 1] = profile end
    return list
end

local function Apply(Bagnon, on)
    for _, profile in ipairs(Profiles(Bagnon)) do
        for _, id in ipairs(FRAMES) do
            local frame = profile[id]
            if type(frame) == "table" then
                if on then
                    frame.skin = SKIN
                elseif frame.skin == SKIN then
                    frame.skin = Bagnon.Skins.Default
                end
            end
        end
        local inv = profile.inventory
        if on and type(inv) == "table" then
            local margin = ns.Snap(ns.SCREEN_MARGIN)
            inv.point, inv.x, inv.y = "BOTTOMRIGHT", -margin, margin + 72
        end
    end
    if on then Bagnon.sets.locked = true end
    if Bagnon.Frames and Bagnon.Frames.Update then Bagnon.Frames:Update() end
end

function ns.ApplyBagnonStyle()
    local Bagnon = _G.Bagnon
    if not (Bagnon and Bagnon.Skins and Bagnon.sets) then return end
    Apply(Bagnon, ns.db.bagnonStyle ~= false)
end

-- Bagnon's inventory window while it is open (the tooltip goes above it, like above mUI's bags)
function ns.BagnonInventory()
    local Bagnon = _G.Bagnon
    local frame = Bagnon and Bagnon.Frames and Bagnon.Frames.Get and Bagnon.Frames:Get("inventory")
    if frame and frame[0] and frame:IsShown() then return frame end
end

local function Setup()
    local Bagnon = _G.Bagnon
    if not (Bagnon and Bagnon.Skins and Bagnon.Skins.Register) then return end
    Register(Bagnon)
    -- Bagnon reads its settings on load; ours apply once both are ready
    C_Timer.After(0, ns.ApplyBagnonStyle)
end

ns:On("PLAYER_LOGIN", function()
    if C_AddOns.IsAddOnLoaded("Bagnon") then Setup() end
end)
