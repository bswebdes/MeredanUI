-- Bagnon in the mUI look, through Bagnon's own skin API (Bagnon.Skins:Register, see the BagBrother
-- wiki "Skins API"): flat panel with a 1 px black border, mUI fonts, and the inventory where mUI's
-- bags sit (bottom right above the micro menu). Nothing of Bagnon's frames is touched directly;
-- the profile values (skin, colours, position) are Bagnon's own settings.
-- Switch: ns.db.bagnonStyle (Bags page, only while Bagnon is active). Like mUI's own windows the
-- inventory has a fixed spot: set on every login and locked with Bagnon's own lock option.
local _, ns = ...

local SKIN = "MeredanUI"
local FRAMES = { "inventory", "bank", "vault", "guild" }
local SPACING = 5          -- gap between item buttons (Bagnon's default is 2)
local CROP = { 0.08, 0.92, 0.08, 0.92 }
local BAG_CROP = { 0.12, 0.88, 0.12, 0.88 } -- bag icons have a wide bevel baked in
local HEADER_PAD = 10      -- header buttons: distance to the frame edge
local HEADER_STEP = 26     -- header buttons: 22 px + 4 px gap
local INSET = 6            -- Bagnon's content inset for this skin
local FOOTER_LIFT = 12     -- footer (gold, currencies) 10 px above the bottom edge instead of -2

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

-- Items and buttons ------------------------------------------------------------------------------
-- Visual regions only (textures, colours); no secure attribute or bag/slot ID is touched.

local function Styled() return ns.db and ns.db.bagnonStyle ~= false end

local function FlatHighlight(button)
    local hl = button.GetHighlightTexture and button:GetHighlightTexture()
    if hl then
        hl:SetColorTexture(1, 1, 1, 0.12)
        hl:SetAllPoints()
    end
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    if pushed then
        pushed:SetColorTexture(1, 1, 1, 0.08)
        pushed:SetAllPoints()
    end
end

-- Square icon, dark slot, 1 px border (quality colour, see ColorItem)
local function StyleItem(b)
    if b.muiStyled or not Styled() then return end
    b.muiStyled = true
    local normal = b:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    if b.IconBorder then b.IconBorder:SetAlpha(0) end
    if b.IconGlow then b.IconGlow:SetAlpha(0) end
    local icon = b.icon or b.Icon
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    ns.AddSlotBackground(b) -- same empty-slot art as mUI's bags and action bars
    b.muiEdges = ns.AddBorder(b, true)
    FlatHighlight(b)
end

local function ColorItem(b)
    if not b.muiEdges then return end
    local r, g, bl = 0, 0, 0
    if b.IconBorder and b.IconBorder:IsShown() then r, g, bl = b.IconBorder:GetVertexColor() end
    for _, edge in ipairs(b.muiEdges) do edge:SetVertexColor(r, g, bl, 1) end
end

local function UpdateItem(b)
    StyleItem(b)
    if not b.muiStyled then return end
    local icon = b.icon or b.Icon
    if icon then
        if b.hasItem then
            icon:SetTexCoord(unpack(CROP))
        else
            icon:SetTexture(nil) -- empty slot: the slot background shows
        end
    end
    ColorItem(b)
end

-- Header buttons that get an mUI icon instead of Blizzard's (class = Bagnon class name)
local HEADER_ICONS = { BagToggle = "Bag", SortButton = "Sort", SearchToggle = "Search", OptionsToggle = "Settings" }

local function HeaderIcon(b)
    local Bagnon = _G.Bagnon
    for class, icon in pairs(HEADER_ICONS) do
        local c = Bagnon and Bagnon[class]
        if c and rawget(c, "OnClick") and b.OnClick == rawget(c, "OnClick") then return icon end
    end
end

-- Bagnon's small icon buttons (bag toggle, sort, search, options ...) and bag slots
local function StyleButton(b)
    if b.muiStyled then return end
    b.muiStyled = true
    local mui = HeaderIcon(b)
    if mui then
        -- flat mUI symbol on the dark field, accent on hover
        b:SetSize(22, 22)
        b.Icon:SetAlpha(0)
        local glyph = ns.UI.Icon(b, mui, 14, ns.UI.TEXT)
        glyph:SetPoint("CENTER")
        b:HookScript("OnEnter", function() glyph:SetVertexColor(unpack(ns.UI.ACCENT)) end)
        b:HookScript("OnLeave", function() glyph:SetVertexColor(unpack(ns.UI.TEXT)) end)
    end
    local normal = b:GetNormalTexture()
    if normal then normal:SetAlpha(0) end
    if b.Bg then b.Bg:SetColorTexture(unpack(ns.UI.FIELD)) end
    local icon = b.Icon or b.icon
    if icon then
        icon:SetTexCoord(unpack(b.FilterIcon and BAG_CROP or CROP))
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    ns.AddBorder(b, true)
    FlatHighlight(b)
    local checked = b.GetCheckedTexture and b:GetCheckedTexture()
    if checked then
        local a = ns.UI.ACCENT
        checked:SetColorTexture(a[1], a[2], a[3], 0.25)
        checked:SetAllPoints()
    end
end

-- Close button: mUI's flat X instead of Blizzard's red one
local function StyleClose(close)
    if not close or close.muiStyled then return end
    close.muiStyled = true
    for _, get in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local tex = close[get] and close[get](close)
        if tex then tex:SetAlpha(0) end
    end
    -- like mUI's own window close button (ns.UI.IconButton): dark box, 1 px border, X
    close:SetSize(24, 24)
    local bg = ns.UI.Box(close)
    local icon = ns.UI.Icon(close, "Close", 16, ns.UI.TEXT)
    icon:SetPoint("CENTER")
    close:HookScript("OnEnter", function()
        bg:SetColorTexture(unpack(ns.UI.HOVER))
        icon:SetVertexColor(unpack(ns.UI.ACCENT))
    end)
    close:HookScript("OnLeave", function()
        bg:SetColorTexture(unpack(ns.UI.FIELD))
        icon:SetVertexColor(unpack(ns.UI.TEXT))
    end)
end

-- Search field: flat mUI input instead of the tooltip backdrop
local function StyleSearch(box)
    if box.muiStyled or not Styled() then return end
    box.muiStyled = true
    if box.NineSlice then box.NineSlice:SetAlpha(0) end
    local bg = box:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.UI.FIELD))
    ns.AddBorder(box)
    box:SetTextInsets(8, 8, 0, 0)
    local font = box:GetFontObject()
    if font then box:SetFont(ns.FontFor(), ns.FontPx(12), "") end
end

-- Walk a Bagnon frame once it shows: header buttons and the close button
local function StyleFrame(frame)
    if not Styled() then return end
    StyleClose(frame.CloseButton)
    local function Walk(parent, depth)
        for _, child in ipairs({ parent:GetChildren() }) do
            if child.IconBorder then
                UpdateItem(child)
            elseif child.Icon and (child.Border or child.FilterIcon) and child:IsObjectType("Button") then
                StyleButton(child) -- header buttons and bag slots
            elseif child:IsObjectType("EditBox") and child.NineSlice then
                StyleSearch(child)
            end
            if depth < 4 then Walk(child, depth + 1) end
        end
    end
    Walk(frame, 1)
end

local function HookClasses(Bagnon)
    local Bag, Search = Bagnon.Bag, Bagnon.SearchBar
    if Bag and rawget(Bag, "Update") then
        hooksecurefunc(Bag, "Update", function(self)
            if not Styled() then return end
            StyleButton(self)
            if self.Icon then self.Icon:SetTexCoord(unpack(BAG_CROP)) end
        end)
    end
    -- Header layout (Bagnon/src/frame.lua): no character portrait, roomier spacing, search field
    -- as tall as the buttons. Wrapped once; each wrapper falls back to Bagnon when switched off.
    local F = Bagnon.Frame
    if F and F.PlaceMenuButtons and F.HasOfflineSelector then
        local hasOffline, placeMenu = F.HasOfflineSelector, F.PlaceMenuButtons
        local placeOptions, placeSearch = F.PlaceOptionsToggle, F.PlaceSearchBar
        F.HasOfflineSelector = function(self)
            if Styled() then return false end
            return hasOffline(self)
        end
        F.PlaceMenuButtons = function(self)
            local w, h = placeMenu(self)
            if not Styled() then return w, h end
            for i, button in ipairs(self.MenuButtons) do
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", self, "TOPLEFT", HEADER_PAD + (i - 1) * HEADER_STEP, -HEADER_PAD)
            end
            return HEADER_STEP * #self.MenuButtons + 4, 22
        end
        if placeOptions then
            F.PlaceOptionsToggle = function(self)
                local w, h = placeOptions(self)
                if Styled() and self.OptionsToggle and self.OptionsToggle:IsShown() then
                    self.OptionsToggle:ClearAllPoints()
                    self.OptionsToggle:SetPoint("TOPRIGHT", self, "TOPRIGHT", -(HEADER_PAD + 24 + 6), -HEADER_PAD)
                end
                return w, h
            end
        end
        if placeSearch then
            F.PlaceSearchBar = function(self)
                placeSearch(self)
                if Styled() then self.SearchBar:SetHeight(22) end
            end
        end
    end
    if Search and rawget(Search, "OnShow") then hooksecurefunc(Search, "OnShow", StyleSearch) end
    for _, class in ipairs({ Bagnon.Item, Bagnon.ContainerItem }) do
        if class and rawget(class, "Update") then hooksecurefunc(class, "Update", UpdateItem) end
        if class and rawget(class, "UpdateBorder") then hooksecurefunc(class, "UpdateBorder", ColorItem) end
    end
end

local function Register(Bagnon)
    Fonts()
    Bagnon.Skins:Register({
        id = SKIN,
        template = "BagnonOnePixelTemplate", -- ships with Bagnon: Center + four 1 px edges
        font = titleFont, fontH = titleFontH,
        x = 1, y = 1, x1 = -1, y1 = -1, margin = 2,
        inset = INSET, -- more room between header, items and footer
        -- after each Bagnon layout: taller frame and the footer lifted by the same amount
        layout = function(bg)
            local frame = bg:GetParent()
            if not (frame and frame.Footer) then return end
            frame:SetHeight(frame:GetHeight() + FOOTER_LIFT)
            frame.Footer:ClearAllPoints()
            frame.Footer:SetPoint("BOTTOMLEFT", INSET, 4 - INSET + FOOTER_LIFT)
            frame.Footer:SetPoint("BOTTOMRIGHT", -INSET, 4 - INSET + FOOTER_LIFT)
        end,
        closeX = -(HEADER_PAD - 2), closeY = -(HEADER_PAD - 2), -- Bagnon adds -2 itself
        load = function(bg)
            Paint(bg)
            local frame = bg:GetParent()
            if frame and not frame.muiHooked then
                frame.muiHooked = true
                frame:HookScript("OnShow", function(self) C_Timer.After(0, function() StyleFrame(self) end) end)
            end
            if frame then C_Timer.After(0, function() StyleFrame(frame) end) end
        end,
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

-- mUI profile for Bagnon: set once (Bagnon.sets.muiProfile), afterwards the player's changes stay.
-- One clean grid like mUI's bags: no gaps between bags, newest items first, no sidebar or broker.
local PROFILE_VERSION = 1
local PROFILE = {
    inventory = { bagBreak = 0, reverseSlots = true, sidebar = false, broker = false },
    bank = { bagBreak = 0, reverseSlots = true, sidebar = false, broker = false },
    vault = { broker = false },
    guild = { broker = false },
}
local function ApplyProfileOnce(Bagnon, profile)
    for id, values in pairs(PROFILE) do
        local frame = profile[id]
        if type(frame) == "table" then
            for key, value in pairs(values) do frame[key] = value end
        end
    end
end

-- Fixed spots like mUI's windows: inventory bottom right above the micro menu (where mUI's bags
-- are), bank, vault and guild bank where mUI's bank opens (left, 90 px above the chat)
local function Place(profile)
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    local inv = profile.inventory
    if type(inv) == "table" then inv.point, inv.x, inv.y = "BOTTOMRIGHT", -margin, margin + 72 end
    local chat = ChatFrame1
    local left, top = chat and chat:GetLeft(), chat and chat:GetTop()
    if not (left and top) then return end
    for _, id in ipairs({ "bank", "vault", "guild" }) do
        local frame = profile[id]
        if type(frame) == "table" then
            frame.point, frame.x, frame.y = "BOTTOMLEFT", ns.Snap(left), ns.Snap(top + 90)
        end
    end
end

local function Apply(Bagnon, on)
    for _, profile in ipairs(Profiles(Bagnon)) do
        for _, id in ipairs(FRAMES) do
            local frame = profile[id]
            if type(frame) == "table" then
                if on then
                    frame.skin, frame.spacing = SKIN, SPACING
                elseif frame.skin == SKIN then
                    frame.skin = Bagnon.Skins.Default
                    if frame.spacing == SPACING then frame.spacing = 2 end
                end
            end
        end
        if on then
            if (Bagnon.sets.muiProfile or 0) < PROFILE_VERSION then ApplyProfileOnce(Bagnon, profile) end
            Place(profile)
        end
    end
    if on then
        Bagnon.sets.locked = true
        if (Bagnon.sets.muiProfile or 0) < PROFILE_VERSION then
            Bagnon.sets.slotBackground = 1
            Bagnon.sets.muiProfile = PROFILE_VERSION
        end
    end
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
    HookClasses(Bagnon)
    -- Bagnon reads its settings on load; ours apply once both are ready
    C_Timer.After(1, ns.ApplyBagnonStyle) -- after mUI has placed the chat (bank spot)
end

ns:On("PLAYER_LOGIN", function()
    if C_AddOns.IsAddOnLoaded("Bagnon") then Setup() end
end)
