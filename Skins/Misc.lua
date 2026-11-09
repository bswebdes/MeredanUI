-- Small, rarely used Blizzard windows in mUI style (WoW Forever). Each section has its own option key
-- and is applied when its Blizzard addon is loaded:
--   item socketing (socketSkin), tabard designer (tabardSkin), guild registrar + charter
--   (petitionSkin), clock + stopwatch (clockSkin), death recap (deathRecapSkin).
-- Blizzard's frames keep doing all the work; we only restyle and re-place them.
-- Rules as in Skins/Communities.lua: art only via SetAlpha(0) or recolor, no SetScript on Blizzard
-- frames, no fields on Blizzard tables (weak tables below), no SetText on Blizzard edit boxes, no
-- ScrollBox view changes, no protected calls. Hover looks use HIGHLIGHT textures where possible.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = { 0, 0, 0, 1 }
local INPUT = { 0.04, 0.04, 0.05, 1 }
local BOX = { 0, 0, 0, 0.25 }
local PAD, ICON = 18, 46
local HEADER_BOTTOM = PAD + ICON + 14 -- 78: content starts here
local FOOT_Y, FOOT_H = 14, 28         -- footer buttons

local skinned = setmetatable({}, { __mode = "k" })
local own = setmetatable({}, { __mode = "k" })
local fonts

local function Enabled(key)
    return ns.IS_FOREVER and ns.db and ns.db[key] ~= false
end

local function Once(object)
    if type(object) ~= "table" or skinned[object] then return false end
    if object.IsForbidden and object:IsForbidden() then return false end
    skinned[object] = true
    return true
end

local function IsTexture(region)
    return type(region) == "table" and region.IsObjectType and region:IsObjectType("Texture")
end

local function Fade(region)
    if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
end

local function FadeRegions(target, keep)
    if type(target) ~= "table" or not target.GetRegions then return end
    for _, region in ipairs({ target:GetRegions() }) do
        if IsTexture(region) and not own[region] and not (keep and keep[region]) then region:SetAlpha(0) end
    end
end

-- Blizzard's own title strings (replaced by our header)
local function FadeTexts(target, keep)
    if type(target) ~= "table" or not target.GetRegions then return end
    for _, region in ipairs({ target:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") and not own[region]
            and not (keep and keep[region]) then
            region:SetAlpha(0)
        end
    end
end

local function Tex(parent, layer, sublevel, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    if color then tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    own[tex] = true
    return tex
end

-- 1 px outer border around target (textures on parent)
local function Edges(parent, target, color, layer)
    local px = ns.PixelSize()
    local c = color or BLACK
    local edges = {}
    for i = 1, 4 do
        local edge = parent:CreateTexture(nil, layer or "BORDER")
        edge:SetTexture(WHITE)
        edge:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        edge:SetSnapToPixelGrid(false)
        edge:SetTexelSnappingBias(0)
        own[edge] = true
        edges[i] = edge
    end
    edges[1]:SetPoint("TOPLEFT", target, "TOPLEFT", -px, px)
    edges[1]:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", px, 0)
    edges[2]:SetPoint("TOPLEFT", target, "BOTTOMLEFT", -px, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, -px)
    edges[3]:SetPoint("TOPLEFT", target, "TOPLEFT", -px, 0)
    edges[3]:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", 0, 0)
    edges[4]:SetPoint("TOPLEFT", target, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, 0)
    return edges
end

local function Border(target, inside, thickness)
    local edges = ns.AddBorder(target, inside, thickness)
    for _, edge in ipairs(edges) do own[edge] = true end
    return edges
end

-- Background + border + Surf Green top line
local function Panel(target)
    local c = ns.STYLE.panelColor
    local bg = Tex(target, "BACKGROUND", -8, { c[1], c[2], c[3], 0.97 })
    bg:SetAllPoints()
    Edges(target, target)
    local accent = Tex(target, "OVERLAY", 7, ns.UI.ACCENT)
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
end

-- Parchment drawn on the frame itself (not a child frame): Blizzard's text lives in BACKGROUND/
-- ARTWORK layers of the frame and its children, a child panel could cover it.
local function Parchment(f)
    local base = Tex(f, "BACKGROUND", -7, { 0.1, 0.08, 0.06, 1 })
    local art = Tex(f, "BACKGROUND", -6)
    art:SetAllPoints(base)
    if not art:SetAtlas("QuestBG-Parchment") then art:SetColorTexture(0.6, 0.47, 0.32, 1) end
    art:SetVertexColor(0.3, 0.26, 0.22)
    Edges(f, base)
    return base
end

local function Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, base, color, size)
        local font = CreateFont(name)
        font:CopyFontObject(base)
        if size then font:SetFont(ns.STYLE.font, ns.FontPx(size), "") end
        font:SetTextColor(color[1], color[2], color[3])
        return font
    end
    fonts = {
        normal = Make("MeredanUIMiscButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIMiscButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUIMiscButtonDisabled", GameFontDisable, UI.MUTED),
        option = Make("MeredanUIMiscOption", GameFontHighlight, ns.PARCHMENT_TEXT or UI.TEXT, 13),
        optionHighlight = Make("MeredanUIMiscOptionHighlight", GameFontHighlight, UI.ACCENT, 13),
    }
    return fonts
end

local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
    "GetCheckedTexture", "GetDisabledCheckedTexture" }
local function FadeButtonTextures(button, keep)
    for _, getter in ipairs(BUTTON_TEXTURES) do
        local fn = button[getter]
        local tex = fn and fn(button)
        if tex and tex ~= keep then Fade(tex) end
    end
end

-- Controls ---------------------------------------------------------------------------------------

-- flat button (UIPanelButtonTemplate); hover via HIGHLIGHT layer (some have their own scripts)
local function SkinButton(button)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(button[key]) end
    FadeButtonTextures(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    local hover = Tex(button, "HIGHLIGHT", 0, UI.HOVER)
    hover:SetAllPoints()
    Border(button)
    if button:GetFontString() then
        local f = Fonts()
        button:SetNormalFontObject(f.normal)
        button:SetHighlightFontObject(f.highlight)
        button:SetDisabledFontObject(f.disabled)
    end
end

-- Icon button (close, arrows): flat box, our icon, Surf Green on hover
local function SkinIconButton(button, iconName, iconSize, inset, rotation)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    inset = inset or 4
    FadeButtonTextures(button)
    FadeRegions(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    Edges(button, bg)
    local hover = Tex(button, "HIGHLIGHT", 0, { 1, 1, 1, 0.06 })
    hover:SetAllPoints(bg)
    local icon = UI.Icon(button, iconName, iconSize or 14)
    own[icon] = true
    icon:SetPoint("CENTER", bg)
    if rotation then icon:SetRotation(rotation) end
    button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
    return icon
end

-- Dropdown (WowStyle1DropdownTemplate): flat field, our arrow
local function SkinDropdown(dropdown)
    if type(dropdown) ~= "table" or not dropdown.GetRegions or not Once(dropdown) then return end
    local UI = ns.UI
    Fade(dropdown.Background)
    Fade(dropdown.Arrow)
    local bg = Tex(dropdown, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Edges(dropdown, bg)
    local arrow = UI.Icon(dropdown, "ChevronDown", 10, UI.MUTED)
    own[arrow] = true
    arrow:SetPoint("RIGHT", -8, 0)
    local hover = Tex(dropdown, "HIGHLIGHT", 0, { 1, 1, 1, 0.05 })
    hover:SetAllPoints(bg)
    dropdown:HookScript("OnEnter", function(self)
        if self:IsEnabled() then arrow:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    dropdown:HookScript("OnLeave", function() arrow:SetVertexColor(unpack(UI.MUTED)) end)
end

local function SkinScrollBar(bar)
    if type(bar) ~= "table" or not bar.Track or not Once(bar) then return end
    local UI = ns.UI
    Fade(bar.Background)
    local track = bar.Track
    FadeRegions(track)
    local line = Tex(track, "BACKGROUND", 0, { 1, 1, 1, 0.06 })
    line:SetPoint("TOP")
    line:SetPoint("BOTTOM")
    line:SetWidth(3)
    local thumb = track.Thumb or (bar.GetThumb and bar:GetThumb())
    if type(thumb) == "table" and thumb.GetRegions then
        FadeRegions(thumb)
        local grip = Tex(thumb, "OVERLAY", 0, { UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 1 })
        grip:SetPoint("TOP")
        grip:SetPoint("BOTTOM")
        grip:SetWidth(3)
        grip:SetAlpha(0.8)
        thumb:HookScript("OnEnter", function() grip:SetWidth(5) grip:SetAlpha(1) end)
        thumb:HookScript("OnLeave", function() grip:SetWidth(3) grip:SetAlpha(0.8) end)
    end
    for key, rotation in pairs({ Back = math.pi, Forward = 0 }) do
        local stepper = bar[key]
        if type(stepper) == "table" and stepper.GetRegions then
            FadeRegions(stepper)
            Fade(stepper.Texture)
            local icon = UI.Icon(stepper, "ChevronDown", 12, UI.MUTED)
            own[icon] = true
            icon:SetPoint("CENTER")
            icon:SetRotation(rotation)
            stepper:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
            stepper:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.MUTED)) end)
        end
    end
end

local function HookScrollBox(box, fn)
    if type(box) ~= "table" or not box.ForEachFrame or not Once(box) then return end
    local function Each() box:ForEachFrame(fn) end
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
    return Each
end

-- Edit box: dark field, Surf Green border on focus (never SetText - taints Blizzard's saving)
local function SkinEditBox(box, left, right)
    if type(box) ~= "table" or not box.IsObjectType or not box:IsObjectType("EditBox") or not Once(box) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do Fade(box[key]) end
    FadeRegions(box)
    local bg = Tex(box, "BACKGROUND", -8, INPUT)
    bg:SetPoint("TOPLEFT", -(left or 6), 0)
    bg:SetPoint("BOTTOMRIGHT", right or 2, 0)
    local IDLE = UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 }
    local edges = Edges(box, bg, IDLE)
    box:HookScript("OnEditFocusGained", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    box:HookScript("OnEditFocusLost", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1) end
    end)
end

-- Checkbox: dark box, Surf Green check (state from GetChecked)
local function SkinCheck(check)
    if type(check) ~= "table" or not check.IsObjectType or not check:IsObjectType("CheckButton") then return end
    if not Once(check) then return end
    local UI = ns.UI
    FadeButtonTextures(check)
    local box = CreateFrame("Frame", nil, check)
    box:SetSize(16, 16)
    box:SetPoint("CENTER")
    UI.CheckBg(box)
    local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
    tick:SetPoint("CENTER")
    local hover = Tex(box, "ARTWORK", 0, { 1, 1, 1, 0.08 })
    hover:SetAllPoints()
    hover:Hide()
    check:HookScript("OnEnter", function() hover:Show() end)
    check:HookScript("OnLeave", function() hover:Hide() end)
    local function Update()
        tick:SetShown(check:GetChecked() and true or false)
        tick:SetVertexColor(unpack(check:IsEnabled() and UI.ACCENT or UI.MUTED))
    end
    check:HookScript("OnClick", Update)
    check:HookScript("OnShow", Update)
    hooksecurefunc(check, "SetChecked", Update)
    Update()
end

-- Shared window parts ------------------------------------------------------------------------------

-- Header like mUI windows: 46 px icon (texture, mUI icon or NPC model), title, subtitle, close box.
-- opts: texture, icon, npc (3D portrait), close (Blizzard close button), drag (default true)
local function Header(f, opts)
    local UI = ns.UI
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    local parts = { holder = holder }

    local portrait = holder:CreateTexture(nil, "ARTWORK")
    portrait:SetPoint("TOPLEFT", 1, -1)
    portrait:SetPoint("BOTTOMRIGHT", -1, 1)
    portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if opts.texture then portrait:SetTexture(opts.texture) end
    parts.portrait = portrait
    if opts.icon then
        portrait:Hide()
        local icon = UI.Icon(holder, opts.icon, 26, UI.TEXT)
        icon:SetPoint("CENTER")
    end
    if opts.npc then
        local model = CreateFrame("PlayerModel", nil, holder)
        model:SetPoint("TOPLEFT", 1, -1)
        model:SetPoint("BOTTOMRIGHT", -1, 1)
        parts.model = model
    end

    local title = UI.Text(holder, 16, "LEFT")
    ns.SetFont(title, 16, "", "bold")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    title:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
    title:SetWordWrap(false)
    if opts.title then title:SetText(opts.title) end
    local subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetPoint("RIGHT", title, "RIGHT")
    subtitle:SetWordWrap(false)
    parts.title, parts.subtitle = title, subtitle

    if opts.drag ~= false then
        local header = CreateFrame("Frame", nil, f)
        header:SetPoint("TOPLEFT")
        header:SetPoint("TOPRIGHT", -PAD - 36, 0)
        header:SetHeight(PAD + ICON + 6)
        ns.MakeWindowDraggable(f, header)
    end

    local close = opts.close
    if close then
        SkinIconButton(close, "Close", 18)
        close:SetSize(34, 34)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD - 4), -(PAD - 4))
    end
    return parts
end

-- NPC in the header: 3D portrait, else 2D portrait (as in NPC/NpcWindow.lua)
local function ShowNpc(parts)
    local model, portrait = parts.model, parts.portrait
    local exists = UnitExists("npc")
    local hasModel = false
    if model then
        model:ClearModel()
        if exists then
            model:SetUnit("npc")
            model:SetPortraitZoom(1)
            model:SetCamDistanceScale(1)
            hasModel = model:GetModelFileID() ~= nil
        end
        model:SetShown(hasModel)
    end
    portrait:SetShown(not hasModel)
    if not hasModel and exists then
        SetPortraitTexture(portrait, "npc")
        portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    end
    if exists then
        parts.title:SetText(UnitName("npc") or "")
        parts.subtitle:SetText(ns.NpcTitle("npc"))
    end
end

-- ButtonFrameTemplate shell: Blizzard art off, flat panel
local function SkinShell(f, keep)
    FadeRegions(f, keep)
    Fade(f.NineSlice)
    Fade(f.PortraitContainer)
    Fade(f.TitleContainer)
    Fade(f.TopTileStreaks)
    Fade(f.Bg)
    Fade(f.Inset)
    Panel(f)
end

-- No UIPanel slot (our window row places it); Esc still closes
local function Unmanage(f, name)
    if InCombatLockdown() then return ns.AfterCombat(function() Unmanage(f, name) end) end
    if SetUIPanelAttribute then SetUIPanelAttribute(f, "area", nil) end
    for _, special in ipairs(UISpecialFrames) do
        if special == name then return end
    end
    tinsert(UISpecialFrames, name)
end

-- Keys stay out of NpcWindow's CLOSABLE list: closing these would end the NPC interaction
local function Reposition(f, key, opening)
    if f:IsShown() and ns.ResetWindowPosition then
        ns.ResetWindowPosition(f, key, opening and not InCombatLockdown())
    end
end

local function Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

-- Footer button at a bottom corner of f
local function Foot(button, f, point, x, width)
    if type(button) ~= "table" then return end
    button:ClearAllPoints()
    button:SetPoint(point, f, point, x, FOOT_Y)
    button:SetSize(width or 120, FOOT_H)
end

-- Item socketing (ItemSocketingFrame, Blizzard_ItemSocketingUI) ----------------------------------------
--
--   +-[item] Item Socketing ------------- [x]-+
--   |        Helm of Valor                     |
--   | +--------------------------------------+ |
--   | | item tooltip (Blizzard, scrolls)     | |
--   | +--------------------------------------+ |
--   | |      [gem]    [gem]    [gem]         | |  <- border in socket color
--   | +--------------------------------------+ |
--   |                               [Apply]    |
--   +------------------------------------------+

local SOCKET_W = 338                  -- Blizzard's width (tooltip child is 259 px)
local SOCKET_DESC_H = 266             -- Blizzard's 258 px scroll frame + 4 px inset
local SOCKET_BAND_TOP = HEADER_BOTTOM + SOCKET_DESC_H + 8
local SOCKET_BAND_H = 68
local SOCKET_H = SOCKET_BAND_TOP + SOCKET_BAND_H + 54
local SOCKET_COLORS = {
    Red = { 1, 0.47, 0.47 }, Yellow = { 0.97, 0.82, 0.29 }, Blue = { 0.47, 0.67, 1 },
    PunchcardRed = { 1, 0.47, 0.47 }, PunchcardYellow = { 0.97, 0.82, 0.29 }, PunchcardBlue = { 0.47, 0.67, 1 },
    SingingThunder = { 0.97, 0.82, 0.29 }, SingingSea = { 0.47, 0.67, 1 }, SingingWind = { 1, 0.47, 0.47 },
}

local socketApplied = false
local socketEdges = setmetatable({}, { __mode = "k" })
local socketParts

local function SkinSocket(socket)
    if type(socket) ~= "table" or not socket.Icon or not Once(socket) then return end
    local UI = ns.UI
    -- Filigree, socket ring and color background off; gem icon, shine and colorblind text stay
    FadeRegions(socket, { [socket.Icon] = true })
    FadeButtonTextures(socket)
    local bracket = socket.BracketFrame
    if bracket then
        Fade(bracket.ClosedBracket)
        Fade(bracket.OpenBracket)
    end
    local bg = Tex(socket, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Border(socket)
    socket.Icon:ClearAllPoints()
    socket.Icon:SetPoint("TOPLEFT", 2, -2)
    socket.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
    socket.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hover = Tex(socket, "HIGHLIGHT", 0, { 1, 1, 1, 0.12 })
    hover:SetAllPoints()
    local edges = Border(socket, true, 2)
    for _, edge in ipairs(edges) do edge:SetDrawLayer("OVERLAY", 7) end
    socketEdges[socket] = edges
end

local function UpdateSockets()
    local frame = _G.ItemSocketingFrame
    local container = frame and frame.SocketingContainer
    if not container or not container.SocketFrames then return end
    local UI = ns.UI
    for i, socket in ipairs(container.SocketFrames) do
        local edges = socketEdges[socket]
        if edges then
            local kind = C_ItemSocketInfo and C_ItemSocketInfo.GetSocketTypes(i)
            local c = kind and SOCKET_COLORS[kind] or UI.MUTED
            for _, edge in ipairs(edges) do edge:SetVertexColor(c[1], c[2], c[3], 1) end
        end
    end
end

local function UpdateSocketHeader()
    if not socketParts or not C_ItemSocketInfo then return end
    local name, icon, quality = C_ItemSocketInfo.GetSocketItemInfo()
    socketParts.portrait:SetTexture(icon)
    socketParts.subtitle:SetText(name or "")
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        socketParts.subtitle:SetTextColor(color.r, color.g, color.b)
    else
        socketParts.subtitle:SetTextColor(unpack(ns.UI.MUTED))
    end
end

local function PlaceSocketing()
    local f = _G.ItemSocketingFrame
    f:SetSize(SOCKET_W, SOCKET_H)
    local scroll = f.ScrollFrame
    if scroll then
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -(HEADER_BOTTOM + 4))
    end
    -- Sockets: Blizzard re-sets Socket1's BOTTOM point (y 33) on every update; the container decides
    local container = f.SocketingContainer
    if container then
        container:ClearAllPoints()
        container:SetPoint("BOTTOM", f, "BOTTOM", 0, SOCKET_H - SOCKET_BAND_TOP - SOCKET_BAND_H / 2 - 20 - 33)
        local apply = container.ApplySocketsButton
        if apply then
            apply:ClearAllPoints()
            apply:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, FOOT_Y)
            apply:SetSize(150, FOOT_H)
        end
    end
end

local function SkinSocketing(f)
    SkinShell(f)
    FadeTexts(f) -- Blizzard's title
    socketParts = Header(f, { title = ITEM_SOCKETING or "", close = f.CloseButton })

    -- Tooltip area and socket band as dark boxes
    local desc = Tex(f, "BACKGROUND", -7, BOX)
    desc:SetPoint("TOPLEFT", PAD, -HEADER_BOTTOM)
    desc:SetPoint("TOPRIGHT", -PAD, -HEADER_BOTTOM)
    desc:SetHeight(SOCKET_DESC_H)
    Edges(f, desc)
    local band = Tex(f, "BACKGROUND", -7, BOX)
    band:SetPoint("TOPLEFT", PAD, -SOCKET_BAND_TOP)
    band:SetPoint("TOPRIGHT", -PAD, -SOCKET_BAND_TOP)
    band:SetHeight(SOCKET_BAND_H)
    Edges(f, band)

    if f.ScrollFrame then SkinScrollBar(f.ScrollFrame.ScrollBar) end
    local container = f.SocketingContainer
    if container then
        for _, socket in ipairs(container.SocketFrames or {}) do SkinSocket(socket) end
        SkinButton(container.ApplySocketsButton)
    end
end

local function ApplySocketing()
    if socketApplied or not Enabled("socketSkin") or type(_G.ItemSocketingFrame) ~= "table" then return end
    socketApplied = true
    local f = _G.ItemSocketingFrame
    Try(SkinSocketing, f)
    Unmanage(f, "ItemSocketingFrame")
    Try(PlaceSocketing)
    if f.SocketingContainer and f.SocketingContainer.Update then
        hooksecurefunc(f.SocketingContainer, "Update", UpdateSockets)
    end
    if _G.ItemSocketingFrame_Update then hooksecurefunc("ItemSocketingFrame_Update", UpdateSocketHeader) end
    f:HookScript("OnShow", function()
        PlaceSocketing()
        UpdateSocketHeader()
        UpdateSockets()
        C_Timer.After(0, function() Reposition(f, "socket", true) end)
    end)
end

-- Tabard designer (TabardFrame) ----------------------------------------------------------------------
--
--   +-[npc] Name ---------------------------------------- [x]-+
--   |       <Tabard Vendor>                                    |
--   | Greeting text                                            |
--   | +----------------------------+  [ Cost        1g ]       |
--   | |                            |  [<]  Emblem       [>]    |
--   | |     3D model (player)      |  [<]  Emblem color [>]    |
--   | |                            |  ... 5 rows               |
--   | |                            |  +----------------------+ |
--   | | [<][>]                     |  |   crest preview      | |
--   | +----------------------------+  +----------------------+ |
--   | money                                 [Accept] [Cancel]  |
--   +----------------------------------------------------------+

local TABARD_W = 480
local TABARD_TOP = HEADER_BOTTOM + 48       -- below the greeting
local TABARD_MODEL_W = 260
local TABARD_COL_X = PAD + TABARD_MODEL_W + 16
local TABARD_COL_W = TABARD_W - PAD - TABARD_COL_X
local TABARD_ROW_H, TABARD_ROW_STEP = 28, 34
local TABARD_CREST_TOP = TABARD_TOP + 34 + 5 * TABARD_ROW_STEP + 12

local tabardApplied = false
local tabardParts

local function PlaceTabard()
    local f = _G.TabardFrame
    f:SetSize(TABARD_W, ns.NPC_HEIGHT)

    local greeting = _G.TabardFrameGreetingText
    if greeting then
        greeting:ClearAllPoints()
        greeting:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -HEADER_BOTTOM)
        greeting:SetWidth(TABARD_W - 2 * PAD)
        greeting:SetJustifyH("LEFT")
    end

    local model = _G.TabardModel
    if model then
        model:ClearAllPoints()
        model:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -TABARD_TOP)
        model:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", PAD + TABARD_MODEL_W, 54)
    end
    local rotateLeft, rotateRight = _G.TabardCharacterModelRotateLeftButton, _G.TabardCharacterModelRotateRightButton
    if rotateLeft and model then
        rotateLeft:ClearAllPoints()
        rotateLeft:SetPoint("BOTTOMLEFT", model, "BOTTOMLEFT", 6, 6)
        rotateLeft:SetSize(28, 28)
    end
    if rotateRight and rotateLeft then
        rotateRight:ClearAllPoints()
        rotateRight:SetPoint("LEFT", rotateLeft, "RIGHT", 4, 0)
        rotateRight:SetSize(28, 28)
    end

    local cost = _G.TabardFrameCostFrame
    if cost then
        cost:ClearAllPoints()
        cost:SetPoint("TOPLEFT", f, "TOPLEFT", TABARD_COL_X, -TABARD_TOP)
        cost:SetSize(TABARD_COL_W, TABARD_ROW_H)
    end
    local costMoney = _G.TabardFrameCostMoneyFrame
    if costMoney then
        costMoney:ClearAllPoints()
        costMoney:SetPoint("RIGHT", cost, "RIGHT", -6, 0)
    end

    for i = 1, 5 do
        local row = _G["TabardFrameCustomization" .. i]
        if row then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", f, "TOPLEFT", TABARD_COL_X, -(TABARD_TOP + 34 + (i - 1) * TABARD_ROW_STEP))
            row:SetSize(TABARD_COL_W, TABARD_ROW_H)
            local text = _G["TabardFrameCustomization" .. i .. "Text"]
            if text then
                text:ClearAllPoints()
                text:SetPoint("CENTER", row, "CENTER")
                text:SetWidth(TABARD_COL_W - 2 * TABARD_ROW_H - 8)
            end
            local left, right = _G["TabardFrameCustomization" .. i .. "LeftButton"], _G["TabardFrameCustomization" .. i .. "RightButton"]
            if left then
                left:ClearAllPoints()
                left:SetPoint("LEFT", row, "LEFT", 0, 0)
                left:SetSize(TABARD_ROW_H, TABARD_ROW_H)
            end
            if right then
                right:ClearAllPoints()
                right:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                right:SetSize(TABARD_ROW_H, TABARD_ROW_H)
            end
        end
    end

    -- Crest preview (Blizzard's emblem halves, ADD blend at Blizzard's alpha), scaled into the column
    local topRight = _G.TabardFrameEmblemTopRight
    if topRight then
        local k = TABARD_COL_W / 200
        topRight:ClearAllPoints()
        topRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(TABARD_CREST_TOP + 6))
        for name, h in pairs({ TopRight = 119, TopLeft = 119, BottomRight = 74, BottomLeft = 74 }) do
            local emblem = _G["TabardFrameEmblem" .. name]
            if emblem then emblem:SetSize(100 * k, h * k) end
        end
    end

    local money = _G.TabardFrameMoneyFrame
    if money then
        money:ClearAllPoints()
        money:SetPoint("LEFT", f, "BOTTOMLEFT", PAD, FOOT_Y + FOOT_H / 2)
    end
    local cancel, accept = _G.TabardFrameCancelButton, _G.TabardFrameAcceptButton
    Foot(cancel, f, "BOTTOMRIGHT", -PAD)
    if accept and cancel then
        accept:ClearAllPoints()
        accept:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
        accept:SetSize(120, FOOT_H)
    end
end

local function SkinTabardRow(row, i)
    if type(row) ~= "table" or not Once(row) then return end
    local UI = ns.UI
    FadeRegions(row)
    local bg = Tex(row, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Edges(row, bg)
    local text = _G["TabardFrameCustomization" .. i .. "Text"]
    if text then
        ns.SetFont(text, 12)
        text:SetTextColor(unpack(UI.TEXT))
    end
    SkinIconButton(_G["TabardFrameCustomization" .. i .. "LeftButton"], "ChevronDown", 10, 3, -math.pi / 2)
    SkinIconButton(_G["TabardFrameCustomization" .. i .. "RightButton"], "ChevronDown", 10, 3, math.pi / 2)
end

local function SkinTabard(f)
    local UI = ns.UI
    local keep = {}
    for _, name in ipairs({ "TopRight", "TopLeft", "BottomRight", "BottomLeft" }) do
        local emblem = _G["TabardFrameEmblem" .. name]
        if emblem then keep[emblem] = true end
    end
    SkinShell(f, keep)
    Fade(_G.TabardFrameNameText)
    tabardParts = Header(f, { npc = true, close = f.CloseButton })

    local greeting = _G.TabardFrameGreetingText
    if greeting then greeting:SetTextColor(unpack(UI.TEXT)) end

    -- Model in a dark box
    local model = _G.TabardModel
    if model then
        local box = Tex(f, "BACKGROUND", -7, BOX)
        box:SetAllPoints(model)
        Edges(f, box)
    end
    SkinIconButton(_G.TabardCharacterModelRotateLeftButton, "ChevronDown", 12, 3, -math.pi / 2)
    SkinIconButton(_G.TabardCharacterModelRotateRightButton, "ChevronDown", 12, 3, math.pi / 2)

    -- Cost: flat field
    local cost = _G.TabardFrameCostFrame
    if cost then
        Fade(cost.NineSlice)
        FadeRegions(cost)
        local bg = Tex(cost, "BACKGROUND", -8, UI.FIELD)
        bg:SetAllPoints()
        Edges(cost, bg)
        local label = _G.TabardFrameCostLabel
        if label then label:SetTextColor(unpack(UI.MUTED)) end
    end

    Fade(_G.TabardFrameCustomizationBorder)
    for i = 1, 5 do SkinTabardRow(_G["TabardFrameCustomization" .. i], i) end

    -- Crest preview box
    local crest = Tex(f, "BACKGROUND", -7, BOX)
    crest:SetPoint("TOPLEFT", f, "TOPLEFT", TABARD_COL_X, -TABARD_CREST_TOP)
    crest:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 54)
    Edges(f, crest)

    -- Player money: Blizzard shows/hides these per tabard type; only their art goes
    local inset = _G.TabardFrameMoneyInset
    if inset then
        Fade(inset.NineSlice)
        Fade(inset.Bg)
        FadeRegions(inset)
    end
    FadeRegions(_G.TabardFrameMoneyBg)

    SkinButton(_G.TabardFrameAcceptButton)
    SkinButton(_G.TabardFrameCancelButton)
end

local function ApplyTabard()
    if tabardApplied or not Enabled("tabardSkin") or type(_G.TabardFrame) ~= "table" then return end
    tabardApplied = true
    local f = _G.TabardFrame
    Try(SkinTabard, f)
    Unmanage(f, "TabardFrame")
    Try(PlaceTabard)
    -- TabardFrame_Open is held by the interaction manager (a hook would not run): use OnShow
    f:HookScript("OnShow", function()
        PlaceTabard()
        if tabardParts then ShowNpc(tabardParts) end
        C_Timer.After(0, function() Reposition(f, "tabard", true) end)
    end)
end

-- Guild registrar + guild charter (GuildRegistrarFrame, PetitionFrame) -------------------------------
-- Both like the mUI gossip/quest windows: header, one parchment for the content, buttons below.

local PAPER_W = 520
local PAPER_TOP = HEADER_BOTTOM + 8
local PAPER_INNER = PAPER_W - 2 * PAD - 40 -- text width on the parchment
local OPTION_H, OPTION_GAP = 40, 6

local petitionApplied = false
local registrarParts, petitionParts

-- Registrar options (QuestTitleButtonTemplate): parchment cards like mUI gossip rows
local function SkinOption(button)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button, button.Icon)
    local bg = Tex(button, "BACKGROUND", -8, ns.PARCHMENT_CARD or BOX)
    bg:SetAllPoints()
    local hover = Tex(button, "HIGHLIGHT", 0, { 0, 0, 0, 0.2 })
    hover:SetAllPoints()
    local icon = button.Icon or _G[(button:GetName() or "") .. "QuestIcon"]
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", button, "LEFT", 12, 0)
        icon:SetSize(16, 16)
    end
    local arrow = UI.Icon(button, "ChevronDown", 10, UI.MUTED)
    own[arrow] = true
    arrow:SetPoint("RIGHT", -12, 0)
    arrow:SetRotation(math.pi / 2)
    local text = button:GetFontString()
    if text then
        text:ClearAllPoints()
        text:SetPoint("LEFT", button, "LEFT", 40, 0)
        text:SetWidth(PAPER_INNER - 64)
        text:SetJustifyH("LEFT")
    end
    local f = Fonts()
    button:SetNormalFontObject(f.option)
    button:SetHighlightFontObject(f.optionHighlight)
end

local function PlaceRegistrar()
    local f = _G.GuildRegistrarFrame
    f:SetSize(PAPER_W, ns.NPC_HEIGHT)
    local paper = registrarParts and registrarParts.paper
    if not paper then return end

    local services = _G.AvailableServicesText
    if services then
        services:ClearAllPoints()
        services:SetPoint("TOPLEFT", paper, "TOPLEFT", 20, -20)
        services:SetWidth(PAPER_INNER)
    end
    local button1, button2 = _G.GuildRegistrarButton1, _G.GuildRegistrarButton2
    if button1 and services then
        button1:ClearAllPoints()
        button1:SetPoint("TOPLEFT", services, "BOTTOMLEFT", 0, -12)
        button1:SetSize(PAPER_INNER, OPTION_H)
    end
    if button2 and button1 then
        button2:ClearAllPoints()
        button2:SetPoint("TOPLEFT", button1, "BOTTOMLEFT", 0, -OPTION_GAP)
        button2:SetSize(PAPER_INNER, OPTION_H)
    end

    local text = _G.GuildRegistrarPurchaseText
    if text then
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", paper, "TOPLEFT", 20, -20)
        text:SetWidth(PAPER_INNER)
    end
    local label = _G.GuildRegistrarCostLabel
    if label and text then
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
    end
    local box = _G.GuildRegistrarFrameEditBox
    if box and label then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 6, -12)
        box:SetSize(240, 26)
    end

    Foot(_G.GuildRegistrarFrameGoodbyeButton, f, "BOTTOMRIGHT", -PAD)
    Foot(_G.GuildRegistrarFrameCancelButton, f, "BOTTOMRIGHT", -PAD)
    Foot(_G.GuildRegistrarFramePurchaseButton, f, "BOTTOMLEFT", PAD, 160)
end

local function SkinRegistrar(f)
    local UI = ns.UI
    SkinShell(f)
    Fade(_G.GuildRegistrarText)
    Fade(_G.GuildRegistrarFrameNpcNameText)
    if f.ScrollBar then f.ScrollBar:Hide() end -- cosmetic only, never scrolls
    registrarParts = Header(f, { npc = true, close = f.CloseButton })
    local paper = Parchment(f)
    paper:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAPER_TOP)
    paper:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 54)
    registrarParts.paper = paper

    local services = _G.AvailableServicesText
    if services then services:SetTextColor(unpack(UI.ACCENT)) end
    SkinOption(_G.GuildRegistrarButton1)
    SkinOption(_G.GuildRegistrarButton2)
    local text = _G.GuildRegistrarPurchaseText
    if text then text:SetTextColor(unpack(ns.PARCHMENT_TEXT or UI.TEXT)) end
    local label = _G.GuildRegistrarCostLabel
    if label then label:SetTextColor(unpack(UI.ACCENT)) end
    SkinEditBox(_G.GuildRegistrarFrameEditBox, 6, 6)

    SkinButton(_G.GuildRegistrarFrameGoodbyeButton)
    SkinButton(_G.GuildRegistrarFrameCancelButton)
    SkinButton(_G.GuildRegistrarFramePurchaseButton)
end

local PETITION_TITLES = { "PetitionFrameCharterTitle", "PetitionFrameMasterTitle", "PetitionFrameMemberTitle" }
local PETITION_TEXTS = { "PetitionFrameCharterName", "PetitionFrameMasterName", "PetitionFrameInstructions" }
for i = 1, 9 do PETITION_TEXTS[#PETITION_TEXTS + 1] = "PetitionFrameMemberName" .. i end

local function PlacePetition()
    local f = _G.PetitionFrame
    f:SetSize(PAPER_W, ns.NPC_HEIGHT)
    local paper = petitionParts and petitionParts.paper
    if not paper then return end
    local first = _G.PetitionFrameCharterTitle
    if first then
        first:ClearAllPoints()
        first:SetPoint("TOPLEFT", paper, "TOPLEFT", 20, -20)
    end
    for _, list in ipairs({ PETITION_TITLES, PETITION_TEXTS }) do
        for _, name in ipairs(list) do
            local text = _G[name]
            if text then text:SetWidth(PAPER_INNER) end
        end
    end

    local cancel, sign, request = _G.PetitionFrameCancelButton, _G.PetitionFrameSignButton, _G.PetitionFrameRequestButton
    Foot(cancel, f, "BOTTOMRIGHT", -PAD)
    Foot(sign, f, "BOTTOMLEFT", PAD, 160)
    Foot(request, f, "BOTTOMLEFT", PAD, 160)
    local rename = _G.PetitionFrameRenameButton
    if rename and request and cancel then
        rename:ClearAllPoints()
        rename:SetPoint("LEFT", request, "RIGHT", 6, 0)
        rename:SetPoint("RIGHT", cancel, "LEFT", -6, 0)
        rename:SetHeight(FOOT_H)
    end
end

local function UpdatePetitionHeader()
    if not petitionParts then return end
    local npcName = _G.PetitionFrameNpcNameText
    petitionParts.title:SetText(npcName and npcName:GetText() or "")
    local minSignatures = select(7, GetPetitionInfo())
    if type(minSignatures) == "number" and minSignatures > 0 then
        petitionParts.subtitle:SetText(("%s %d/%d"):format(MEMBERS or "", GetNumPetitionNames() or 0, minSignatures))
    else
        petitionParts.subtitle:SetText("")
    end
end

local function SkinPetition(f)
    local UI = ns.UI
    SkinShell(f)
    Fade(_G.PetitionFrameNpcNameText)
    if f.ScrollBar then f.ScrollBar:Hide() end -- cosmetic only, never scrolls
    petitionParts = Header(f, { texture = "Interface\\PetitionFrame\\GuildCharter-Icon", close = f.CloseButton })
    petitionParts.portrait:SetTexCoord(0, 1, 0, 1)
    local paper = Parchment(f)
    paper:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAPER_TOP)
    paper:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 54)
    petitionParts.paper = paper

    for _, name in ipairs(PETITION_TITLES) do
        local text = _G[name]
        if text then text:SetTextColor(unpack(UI.ACCENT)) end
    end
    for _, name in ipairs(PETITION_TEXTS) do
        local text = _G[name]
        if text then text:SetTextColor(unpack(ns.PARCHMENT_TEXT or UI.TEXT)) end
    end
    for _, name in ipairs({ "PetitionFrameCancelButton", "PetitionFrameSignButton", "PetitionFrameRequestButton",
        "PetitionFrameRenameButton" }) do
        SkinButton(_G[name])
    end
end

local function ApplyPetition()
    if petitionApplied or not Enabled("petitionSkin") then return end
    local registrar, petition = _G.GuildRegistrarFrame, _G.PetitionFrame
    if type(registrar) ~= "table" and type(petition) ~= "table" then return end
    petitionApplied = true

    if type(registrar) == "table" then
        Try(SkinRegistrar, registrar)
        Unmanage(registrar, "GuildRegistrarFrame")
        Try(PlaceRegistrar)
        registrar:HookScript("OnShow", function()
            PlaceRegistrar()
            if registrarParts then ShowNpc(registrarParts) end
            C_Timer.After(0, function() Reposition(registrar, "registrar", true) end)
        end)
    end

    if type(petition) == "table" then
        Try(SkinPetition, petition)
        Unmanage(petition, "PetitionFrame")
        Try(PlacePetition)
        if _G.PetitionFrame_Update then hooksecurefunc("PetitionFrame_Update", UpdatePetitionHeader) end
        petition:HookScript("OnShow", function()
            PlacePetition()
            C_Timer.After(0, function() Reposition(petition, "petition", true) end)
        end)
    end
end

-- Clock + stopwatch (TimeManagerFrame, StopwatchFrame; Blizzard_TimeManager) -------------------------
-- Clock window keeps Blizzard's spot below the minimap (not a UIPanel); laid out top to bottom:
-- alarm time, message, alarm on, 24 h / local time, stopwatch toggle.

local CLOCK_W = 260
local CLOCK_H = 310

local clockApplied = false
local stopwatchCheckEdges

local function PlaceClock()
    local f = _G.TimeManagerFrame
    f:SetSize(CLOCK_W, CLOCK_H)

    local alarm = f.AlarmTimeFrame
    if alarm then
        alarm:ClearAllPoints()
        alarm:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -HEADER_BOTTOM)
        for _, key in ipairs({ "HourDropdown", "MinuteDropdown", "AMPMDropdown" }) do
            if alarm[key] then alarm[key]:SetHeight(26) end
        end
    end
    local edit = _G.TimeManagerAlarmMessageEditBox
    if edit then edit:SetSize(CLOCK_W - 2 * PAD - 4, 22) end

    local enabled = _G.TimeManagerAlarmEnabledButton
    if enabled then
        enabled:ClearAllPoints()
        enabled:SetPoint("TOPLEFT", f, "TOPLEFT", PAD - 4, -172)
    end
    local military, localTime = _G.TimeManagerMilitaryTimeCheck, _G.TimeManagerLocalTimeCheck
    if military then
        military:ClearAllPoints()
        military:SetPoint("TOPLEFT", f, "TOPLEFT", PAD - 4, -210)
    end
    if localTime then
        localTime:ClearAllPoints()
        localTime:SetPoint("TOPLEFT", f, "TOPLEFT", PAD - 4, -236)
    end
    -- Blizzard puts these two labels left of the box; we want them right like the alarm check
    for _, name in ipairs({ "TimeManagerMilitaryTimeCheckText", "TimeManagerLocalTimeCheckText" }) do
        local text = _G[name]
        local check = name == "TimeManagerMilitaryTimeCheckText" and military or localTime
        if text and check then
            text:ClearAllPoints()
            text:SetPoint("LEFT", check, "RIGHT", 4, 0)
        end
    end

    local stopwatch = _G.TimeManagerStopwatchFrame
    if stopwatch then
        stopwatch:ClearAllPoints()
        stopwatch:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -268)
        stopwatch:SetSize(CLOCK_W - 2 * PAD, 30)
        local label = _G.TimeManagerStopwatchFrameText
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT", stopwatch, "LEFT", 0, 0)
            label:SetJustifyH("LEFT")
        end
        local check = _G.TimeManagerStopwatchCheck
        if check then
            check:ClearAllPoints()
            check:SetPoint("RIGHT", stopwatch, "RIGHT", 0, 0)
            check:SetSize(28, 28)
        end
    end
end

local function UpdateStopwatchCheck()
    local check = _G.TimeManagerStopwatchCheck
    if not (check and stopwatchCheckEdges) then return end
    local on = check:GetChecked() and true or false
    for _, edge in ipairs(stopwatchCheckEdges) do edge:SetShown(on) end
end

local function SkinClock(f)
    local UI = ns.UI
    local ticker = _G.TimeManagerFrameTicker
    SkinShell(f)
    FadeTexts(f, ticker and { [ticker] = true })
    Fade(_G.TimeManagerGlobe)
    local parts = Header(f, { icon = "Clock", title = TIMEMANAGER_TITLE or "", close = f.CloseButton, drag = false })
    -- Current time as subtitle (Blizzard keeps updating it)
    if ticker then
        ticker:ClearAllPoints()
        ticker:SetPoint("TOPLEFT", parts.title, "BOTTOMLEFT", 0, -5)
        ticker:SetJustifyH("LEFT")
        ns.SetFont(ticker, 12)
        ticker:SetTextColor(unpack(UI.MUTED))
    end

    for _, name in ipairs({ "TimeManagerAlarmTimeLabel", "TimeManagerAlarmMessageLabel", "TimeManagerStopwatchFrameText" }) do
        local label = _G[name]
        if label then label:SetTextColor(unpack(UI.MUTED)) end
    end
    local alarm = f.AlarmTimeFrame
    if alarm then
        SkinDropdown(alarm.HourDropdown)
        SkinDropdown(alarm.MinuteDropdown)
        SkinDropdown(alarm.AMPMDropdown)
    end
    SkinEditBox(_G.TimeManagerAlarmMessageEditBox)
    for _, name in ipairs({ "TimeManagerAlarmEnabledButton", "TimeManagerMilitaryTimeCheck", "TimeManagerLocalTimeCheck" }) do
        SkinCheck(_G[name])
        local text = _G[name .. "Text"]
        if text then text:SetTextColor(unpack(UI.TEXT)) end
    end

    -- Divider between alarm and display settings
    local line = Tex(f, "ARTWORK", 0, { 1, 1, 1, 0.08 })
    line:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -202)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -202)
    line:SetHeight(ns.PixelSize())

    -- Stopwatch toggle: pocket watch icon stays, flat slot, Surf Green border while checked
    local check = _G.TimeManagerStopwatchCheck
    if check and Once(check) then
        local normal = check:GetNormalTexture()
        FadeButtonTextures(check, normal)
        if normal then
            normal:ClearAllPoints()
            normal:SetPoint("TOPLEFT", 1, -1)
            normal:SetPoint("BOTTOMRIGHT", -1, 1)
            normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        local bg = Tex(check, "BACKGROUND", -8, UI.FIELD)
        bg:SetAllPoints()
        Border(check)
        local hover = Tex(check, "HIGHLIGHT", 0, { 1, 1, 1, 0.12 })
        hover:SetAllPoints()
        stopwatchCheckEdges = Border(check, true, 2)
        for _, edge in ipairs(stopwatchCheckEdges) do
            edge:SetVertexColor(unpack(UI.ACCENT))
            edge:SetDrawLayer("OVERLAY", 7)
        end
        check:HookScript("OnClick", UpdateStopwatchCheck)
        hooksecurefunc(check, "SetChecked", UpdateStopwatchCheck)
        UpdateStopwatchCheck()
    end
end

-- Stopwatch: flat bar, flat title tab (Blizzard fades the tab in on hover); play/reset icons stay
local function SkinStopwatch(f)
    if not Once(f) then return end
    local UI = ns.UI
    FadeRegions(f)
    local c = ns.STYLE.panelColor
    local bg = Tex(f, "BACKGROUND", -8, { c[1], c[2], c[3], 0.97 })
    bg:SetPoint("BOTTOMLEFT")
    bg:SetPoint("BOTTOMRIGHT")
    bg:SetHeight(29)
    Edges(f, bg)
    local accent = Tex(f, "OVERLAY", 7, UI.ACCENT)
    accent:SetPoint("TOPLEFT", bg, "TOPLEFT")
    accent:SetPoint("TOPRIGHT", bg, "TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())

    local tab = _G.StopwatchTabFrame
    if tab then
        FadeRegions(tab)
        local tabBg = Tex(tab, "BACKGROUND", -8, UI.FIELD)
        tabBg:SetPoint("TOPLEFT")
        tabBg:SetPoint("BOTTOMRIGHT", 0, 1)
        Edges(tab, tabBg)
        local title = _G.StopwatchTitle
        if title then title:SetTextColor(unpack(UI.MUTED)) end
    end
    local close = _G.StopwatchCloseButton
    if close then
        SkinIconButton(close, "Close", 8, 3)
        close:SetSize(16, 16)
        close:ClearAllPoints()
        close:SetPoint("RIGHT", tab or f, "RIGHT", 0, 0)
    end
    for _, name in ipairs({ "StopwatchResetButton", "StopwatchPlayPauseButton" }) do
        local button = _G[name]
        if button then
            Fade(button:GetHighlightTexture())
            local hover = Tex(button, "HIGHLIGHT", 0, { 1, 1, 1, 0.12 })
            hover:SetAllPoints()
        end
    end
end

local function ApplyClock()
    if clockApplied or not Enabled("clockSkin") or type(_G.TimeManagerFrame) ~= "table" then return end
    clockApplied = true
    local f = _G.TimeManagerFrame
    Try(SkinClock, f)
    Try(PlaceClock)
    if type(_G.StopwatchFrame) == "table" then Try(SkinStopwatch, _G.StopwatchFrame) end
    f:HookScript("OnShow", function()
        PlaceClock()
        UpdateStopwatchCheck()
    end)
end

-- Death recap (DeathRecapFrame, Blizzard_DeathRecap) ----------------------------------------------------
-- Centered popup (Blizzard's spot); our header above Blizzard's list. The list hangs from the
-- (hidden) divider and the frame bottom, so moving the divider moves the list.

local RECAP_W, RECAP_H = 410, 374 -- Blizzard: 410 x 326, plus room for the header
local RECAP_DIVIDER_Y = PAD + ICON + 4

local recapApplied = false
local recapParts

local function SkinRecapEntry(entry)
    if type(entry) ~= "table" or not entry.SpellInfo or not Once(entry) then return end
    local spell = entry.SpellInfo
    Fade(spell.IconBorder)
    if spell.Icon then
        spell.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        spell.Icon:SetSize(30, 30)
        Edges(spell, spell.Icon)
    end
    local bg = Tex(entry, "BACKGROUND", -8, { 1, 1, 1, 0.03 })
    bg:SetAllPoints()
end

local function PlaceRecap()
    local f = _G.DeathRecapFrame
    f:SetSize(RECAP_W, RECAP_H)
    if f.Divider then
        f.Divider:ClearAllPoints()
        f.Divider:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -RECAP_DIVIDER_Y)
        f.Divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -RECAP_DIVIDER_Y)
    end
    if f.DragButton then
        f.DragButton:ClearAllPoints()
        f.DragButton:SetPoint("TOPLEFT")
        f.DragButton:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -PAD - 36, -(PAD + ICON + 4))
    end
    if f.CloseButton then
        f.CloseButton:ClearAllPoints()
        f.CloseButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
        f.CloseButton:SetSize(150, 26)
    end
end

local function ReadableText(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then return nil end
    return type(value) == "string" and value ~= "" and value or nil
end

-- Subtitle: the killing blow (first recap event) and who cast it
local function UpdateRecapHeader()
    if not recapParts then return end
    local f = _G.DeathRecapFrame
    local events = C_DeathRecap and f.GetRecapID and C_DeathRecap.GetRecapEvents(f:GetRecapID())
    local first = type(events) == "table" and events[1]
    local text = ""
    if type(first) == "table" then
        local event = ReadableText(first.event)
        local name = ReadableText(first.spellName)
        if event == "SWING_DAMAGE" then
            name = ACTION_SWING
        elseif event == "ENVIRONMENTAL_DAMAGE" then
            local kind = ReadableText(first.environmentalType)
            name = kind and _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. kind:upper()] or name
        end
        local caster = not first.hideCaster and ReadableText(first.sourceName)
        text = name and caster and (name .. " - " .. caster) or name or ""
    end
    recapParts.subtitle:SetText(text)
end

local function SkinRecap(f)
    FadeRegions(f) -- raid border, background, glow, divider
    Fade(f.Title)
    Panel(f)
    recapParts = Header(f, { icon = "Dead", title = DEATH_RECAP_TITLE or "", close = f.CloseXButton, drag = false })
    if f.CloseXButton then f.CloseXButton:SetFrameLevel(f:GetFrameLevel() + 10) end
    SkinScrollBar(f.ScrollBar)
    SkinButton(f.CloseButton)
    return HookScrollBox(f.ScrollBox, SkinRecapEntry)
end

local function ApplyRecap()
    if recapApplied or not Enabled("deathRecapSkin") or type(_G.DeathRecapFrame) ~= "table" then return end
    recapApplied = true
    local f = _G.DeathRecapFrame
    local ok, each = pcall(SkinRecap, f)
    if not ok then geterrorhandler()(each) each = nil end
    Try(PlaceRecap)
    if f.OpenRecap then
        hooksecurefunc(f, "OpenRecap", function()
            if each then each() end
            UpdateRecapHeader()
        end)
    end
    f:HookScript("OnShow", PlaceRecap)
end

-- Loading ------------------------------------------------------------------------------------------

local BY_ADDON = {
    Blizzard_ItemSocketingUI = ApplySocketing,
    Blizzard_TimeManager = ApplyClock,
    Blizzard_DeathRecap = ApplyRecap,
}

ns:On("ADDON_LOADED", function(_, name)
    local apply = BY_ADDON[name]
    if apply then apply() end
end)

ns:On("PLAYER_LOGIN", function()
    -- Tabard, registrar and charter are part of Blizzard_UIPanels_Game (always loaded)
    ApplyTabard()
    ApplyPetition()
    if not (C_AddOns and C_AddOns.IsAddOnLoaded) then return end
    for addon, apply in pairs(BY_ADDON) do
        if C_AddOns.IsAddOnLoaded(addon) then apply() end
    end
end)
