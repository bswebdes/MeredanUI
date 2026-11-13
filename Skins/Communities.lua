-- Guild and Communities frame (CommunitiesFrame) in mUI style. Blizzard's frame stays fully
-- functional (invite, promote etc. are protected and only work from Blizzard's code); we only
-- restyle it. Rules:
-- * Blizzard's frames are only repositioned/resized (PlaceAll, FitSize), never rebuilt.
-- * Borders (NineSlice, button art, dropdown/scrollbar art) only hidden via SetAlpha(0);
--   our backgrounds/edges are new regions above/below.
-- * Flat like mUI windows: artwork (filigree, list backgrounds, parchment, row art) hidden,
--   own flat backgrounds. Icons and crests stay.
-- * No SetScript, no fields on Blizzard tables, no calling Blizzard functions - only
--   HookScript/hooksecurefunc. Own state in weak tables.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = ns.BORDER_COLOR -- edge colour; bronze in the rune look (name kept)
local INPUT = { 0.04, 0.04, 0.05, 1 }

local HEAD_PAD, HEAD_ICON = 18, 46 -- header like mUI windows
-- Target layout and dimensions match mUI's former guild window
local WIN_W, WIN_H = 940, 640
local PAD, LIST_W, MEMBER_W = 18, 190, 180
local CONTENT_X = PAD + LIST_W + 12        -- content right of the community list
local CONTENT_TOP = PAD + HEAD_ICON + 14   -- content below the header (78)
local CONTENT_BOTTOM = 54                  -- footer below
local BOX = { 0.098, 0.098, 0.106, 1 }     -- boxes (message of the day, info, news)
local PlaceAll                             -- overall layout (defined below)
local LIST_TOP_PAD = 40 -- Blizzard's top padding of the community list (may be adjusted)
local CARD_INSET = 4                       -- card = row minus 2 x CARD_INSET (60 px, 8 px gap)
local memberDeco = {}                      -- member list box (chat view only)
local overview = { open = false, updates = {} } -- "Overview" tab (own content, display only)
local SIDE_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }

local noBump = setmetatable({}, { __mode = "k" }) -- areas with fixed widths (info column)
local skinned = setmetatable({}, { __mode = "k" }) -- object -> true (already skinned)
local own = setmetatable({}, { __mode = "k" })     -- our textures (skipped when fading)
local fonts
local applied = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.guildSkin ~= false
end

-- true the first time, false afterwards (skin each object only once)
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

-- make all textures of a frame transparent (not child frames, not ours, not keep)
local function FadeRegions(frame, keep)
    if type(frame) ~= "table" or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if IsTexture(region) and not own[region] and not (keep and keep[region]) then region:SetAlpha(0) end
    end
end


-- new texture on parent, remembered as ours
local function Tex(parent, layer, sublevel, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    if color then tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    own[tex] = true
    return tex
end

-- 1 px outer border around target; textures live on parent (e.g. when target is a texture)
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
    local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
    top:SetPoint("TOPLEFT", target, "TOPLEFT", -px, px)
    top:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", px, 0)
    bottom:SetPoint("TOPLEFT", target, "BOTTOMLEFT", -px, 0)
    bottom:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, -px)
    left:SetPoint("TOPLEFT", target, "TOPLEFT", -px, 0)
    left:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", 0, 0)
    right:SetPoint("TOPLEFT", target, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", px, 0)
    return edges
end

local function Border(frame, inside, thickness)
    local edges = ns.AddBorder(frame, inside, thickness)
    for _, edge in ipairs(edges) do own[edge] = true end
    return edges
end

-- Background + rune frame (windows and popups). target = visible area
-- (e.g. Blizzard's offset border frame), default: the frame itself.
local function Panel(frame, target)
    target = target or frame
    local c = ns.STYLE.panelColor
    local bg = Tex(frame, "BACKGROUND", -8, { c[1], c[2], c[3], 0.96 })
    bg:SetAllPoints(target)
    local rune = ns.RuneFrame(frame, { target = target })
    own[rune.shadow] = true
    for _, tex in ipairs(rune.lines) do own[tex] = true end
    for _, tex in ipairs(rune.corners) do own[tex] = true end
    return bg
end

-- Font objects for buttons: copies of Blizzard's font (same size -> same button width),
-- only the color as in mUI
local function Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, base, color)
        local font = CreateFont(name)
        if base then font:CopyFontObject(base) end
        font:SetTextColor(color[1], color[2], color[3])
        return font
    end
    fonts = {
        normal = Make("MeredanUIGuildSkinButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIGuildSkinButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUIGuildSkinButtonDisabled", GameFontDisable, UI.MUTED),
    }
    return fonts
end

local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
    "GetCheckedTexture", "GetDisabledCheckedTexture" }

local function FadeButtonTextures(button)
    for _, getter in ipairs(BUTTON_TEXTURES) do
        local fn = button[getter]
        if fn then Fade(fn(button)) end
    end
end

-- Controls ---------------------------------------------------------------------------------------

-- flat button (UIPanelButtonTemplate etc.): Blizzard's art hidden, background + 1 px border,
-- brightens on hover
local function SkinButton(button)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftSeparator", "RightSeparator" }) do Fade(button[key]) end
    FadeButtonTextures(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Border(button)
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() then bg:SetColorTexture(unpack(UI.HOVER)) end
    end)
    button:HookScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    if button:GetFontString() then
        local f = Fonts()
        button:SetNormalFontObject(f.normal)
        button:SetHighlightFontObject(f.highlight)
        button:SetDisabledFontObject(f.disabled)
    end
end

-- Icon button (close, maximize ...): flat box with our icon, Surf Green on hover
local function SkinIconButton(button, iconName, iconSize)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = UI.Icon(button, iconName, iconSize or 12)
    own[icon] = true
    icon:SetPoint("CENTER")
    local function Reflect()
        icon:SetAlpha(button:IsEnabled() and 1 or 0.35)
    end
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() then icon:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
    button:HookScript("OnEnable", Reflect)
    button:HookScript("OnDisable", Reflect)
    Reflect()
end

-- Edit box: Blizzard's edges removed, dark field, Surf Green border on focus.
-- inset = { left, top, right, bottom } relative to the box (default: Blizzard's Left/Right art)
local function SkinEditBox(box, inset, color)
    if type(box) ~= "table" or not box.IsObjectType or not box:IsObjectType("EditBox") then return end
    if not Once(box) then return end
    local UI = ns.UI
    local left, right = box.Left, box.Right
    for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do Fade(box[key]) end
    Fade(box.NineSlice)
    local bg = Tex(box, "BACKGROUND", -8, color or INPUT)
    if inset then
        bg:SetPoint("TOPLEFT", box, "TOPLEFT", inset[1], inset[2])
        bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", inset[3], inset[4])
    elseif IsTexture(left) and IsTexture(right) then
        bg:SetPoint("TOPLEFT", left, "TOPLEFT")
        bg:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT")
    else
        bg:SetAllPoints()
    end
    -- faint light edge so the field is visible on dark backgrounds; Surf Green on focus
    local IDLE = UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 }
    local edges = Edges(box, bg, IDLE)
    box:HookScript("OnEditFocusGained", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    box:HookScript("OnEditFocusLost", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1) end
    end)
end

-- multi-line edit box (InputScrollFrameTemplate): border art removed, dark field
local function SkinInputScroll(scroll)
    if type(scroll) ~= "table" or not scroll.GetRegions or not Once(scroll) then return end
    FadeRegions(scroll)
    local bg = Tex(scroll, "BACKGROUND", -8, INPUT)
    bg:SetPoint("TOPLEFT", -5, 5)
    bg:SetPoint("BOTTOMRIGHT", 5, -5)
    Edges(scroll, bg)
end

-- Checkbox: dark box, Surf Green check (like mUI settings)
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
    local hover = box:CreateTexture(nil, "ARTWORK")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    hover:Hide()
    local function Update()
        tick:SetShown(check:GetChecked() and true or false)
        tick:SetVertexColor(unpack(check:IsEnabled() and UI.ACCENT or UI.MUTED))
    end
    check:HookScript("OnEnter", function() hover:Show() end)
    check:HookScript("OnLeave", function() hover:Hide() end)
    check:HookScript("OnClick", Update)
    check:HookScript("OnShow", Update)
    check:HookScript("OnEnable", Update)
    check:HookScript("OnDisable", Update)
    hooksecurefunc(check, "SetChecked", Update)
    Update()
end

-- Dropdown (WowStyle1DropdownTemplate etc.): flat field, 1 px border, our arrow.
-- Arrow-only dropdowns (no text, e.g. "Add to chat") become a small icon box.
local function SkinDropdown(dropdown)
    if type(dropdown) ~= "table" or not dropdown.GetRegions or not Once(dropdown) then return end
    local UI = ns.UI
    Fade(dropdown.Background)
    Fade(dropdown.Arrow)
    local bg = Tex(dropdown, "BACKGROUND", -8, UI.FIELD)
    local arrow = UI.Icon(dropdown, "ChevronDown", 10, UI.MUTED)
    own[arrow] = true
    if dropdown.Text then
        bg:SetAllPoints()
        arrow:SetPoint("RIGHT", -7, 0)
    else
        bg:SetPoint("TOPLEFT", 3, -3)
        bg:SetPoint("BOTTOMRIGHT", -3, 3)
        arrow:SetPoint("CENTER", bg)
    end
    Edges(dropdown, bg)
    local hover = Tex(dropdown, "HIGHLIGHT", 0, { 1, 1, 1, 0.05 })
    hover:SetAllPoints(bg)
    local function Reflect()
        arrow:SetAlpha(dropdown:IsEnabled() and 1 or 0.35)
    end
    dropdown:HookScript("OnEnter", function(self)
        if self:IsEnabled() then arrow:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    dropdown:HookScript("OnLeave", function() arrow:SetVertexColor(unpack(UI.MUTED)) end)
    dropdown:HookScript("OnEnable", Reflect)
    dropdown:HookScript("OnDisable", Reflect)
    Reflect()
end

-- Scrollbar (MinimalScrollBar) like UI.Scrollbar: chevron arrows, thin track, Surf Green thumb
-- (wider on hover). Blizzard's parts stay (invisible) and do the work.
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
            local function Reflect()
                icon:SetAlpha(stepper:IsEnabled() and 1 or 0.3)
            end
            stepper:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
            stepper:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.MUTED)) end)
            stepper:HookScript("OnEnable", Reflect)
            stepper:HookScript("OnDisable", Reflect)
            Reflect()
        end
    end
    -- nothing to scroll: hide the bar (else an empty bar shows next to the community list)
    if bar.HasScrollableExtent then
        local function AutoHide()
            local ok, scrollable = pcall(bar.HasScrollableExtent, bar)
            bar:SetAlpha((not ok or scrollable) and 1 or 0)
        end
        if bar.Update then hooksecurefunc(bar, "Update", AutoHide) end
        bar:HookScript("OnShow", AutoHide)
        AutoHide()
    end
end

-- Content box (InsetFrameTemplate): Blizzard's edge and marble removed. withBorder: own 1 px border,
-- fill: dark background (only when the box lies beneath the content)
local function SkinInset(inset, withBorder, fill)
    if type(inset) ~= "table" or not inset.GetRegions or not Once(inset) then return end
    Fade(inset.NineSlice)
    Fade(inset.Bg)
    if fill then
        local bg = Tex(inset, "BACKGROUND", -6, fill)
        bg:SetAllPoints()
    end
    if withBorder then Border(inset) end
end

-- Box with tooltip border (notes, guild log content): border removed, dark field
local function SkinBackdropBox(box, alpha)
    if type(box) ~= "table" or not box.GetRegions or not Once(box) then return end
    Fade(box.NineSlice)
    FadeRegions(box)
    local bg = Tex(box, "BACKGROUND", -8, { INPUT[1], INPUT[2], INPUT[3], alpha or 0.9 })
    bg:SetAllPoints()
    Border(box)
end

-- Lists (ScrollBox) ---------------------------------------------------------------------------------

-- ScrollBox rows: after each update skin all visible rows (new and recycled) once.
-- Update runs on data, scrolling and resize (ScrollBoxListMixin).
local function HookScrollBox(box, fn)
    if type(box) ~= "table" or not box.ForEachFrame or not Once(box) then return end
    local function Each() if not box.GetView or box:GetView() then box:ForEachFrame(fn) end end -- no view until Blizzard fills the list
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
end

-- Community list entry: Blizzard's blue card hidden, flat 52 px card (in Blizzard's 68 px slot),
-- 32 px icon in a box on the left, name (13) and type (11, grey) beside it, selection shown with
-- a Surf Green stripe on the left. Crest, icon and ring stay.
local function SkinListEntry(entry)
    if not Once(entry) then return end
    local UI = ns.UI
    Fade(entry.Background)
    Fade(entry.Selection)
    Fade(entry:GetHighlightTexture())
    for _, key in ipairs({ "Icon", "IconRing", "GuildTabardBackground", "GuildTabardEmblem", "GuildTabardBorder",
        "InvitationIcon" }) do Fade(entry[key]) end
    local card = Tex(entry, "BACKGROUND", -8, BOX)
    card:SetPoint("TOPLEFT", 0, -CARD_INSET)
    card:SetPoint("BOTTOMRIGHT", 0, CARD_INSET)
    Edges(entry, card)
    local selected = Tex(entry, "BACKGROUND", -7, { 0.122, 0.141, 0.133, 1 })
    selected:SetAllPoints(card)
    local marker = Tex(entry, "OVERLAY", 7, UI.ACCENT)
    marker:SetPoint("TOPLEFT", card, "TOPLEFT")
    marker:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT")
    marker:SetWidth(2)
    local hover = Tex(entry, "HIGHLIGHT", 0, { 1, 1, 1, 0.04 })
    hover:SetAllPoints(card)
    local holder = CreateFrame("Frame", nil, entry)
    holder:SetSize(32, 32)
    holder:SetPoint("LEFT", card, "LEFT", 10, 0)
    ns.AddBorder(holder)
    local iconBg = holder:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints()
    iconBg:SetColorTexture(0.15, 0.15, 0.16, 1)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    local kind = entry:CreateFontString(nil, "OVERLAY")
    own[kind] = true
    kind:SetFont(ns.FontFor(), ns.FontPx(11), "")
    kind:SetTextColor(unpack(UI.MUTED))
    local name = entry.Name
    if name then
        own[name] = true
        name:SetFont(ns.FontFor(), ns.FontPx(13), "")
        name:SetWordWrap(false)
        name:SetJustifyV("MIDDLE")
    end
    if entry.UnreadNotificationIcon then
        entry.UnreadNotificationIcon:ClearAllPoints()
        entry.UnreadNotificationIcon:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -4)
        entry.UnreadNotificationIcon:SetSize(16, 16)
    end
    local selection = entry.Selection
    local function Sync()
        local on = IsTexture(selection) and selection:IsShown() or false
        selected:SetShown(on)
        marker:SetShown(on)
        if name then name:SetTextColor(unpack(on and UI.ACCENT or UI.TEXT)) end
    end
    local function Style(_, data)
        data = data or {}
        local club = data.clubInfo
        for _, key in ipairs({ "Icon", "IconRing", "GuildTabardBackground", "GuildTabardEmblem",
            "GuildTabardBorder", "InvitationIcon" }) do Fade(entry[key]) end
        iconBg:SetColorTexture(0.15, 0.15, 0.16, 1)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetVertexColor(1, 1, 1)
        icon:SetDesaturated(false)
        icon:SetSize(30, 30)
        local kindText
        if club then
            if club.clubType == Enum.ClubType.Guild and SetLargeGuildTabardTextures then
                iconBg:SetTexture(WHITE)
                icon:SetSize(28, 28)
                SetLargeGuildTabardTextures("player", icon, iconBg)
                kindText = GUILD or "Guild"
            else
                -- Blizzard already set the icon (protected - don't call it ourselves): adopt it
                local src = entry.Icon
                if src then
                    icon:SetTexture(src:GetTexture())
                    icon:SetTexCoord(src:GetTexCoord())
                end
                kindText = club.clubType == Enum.ClubType.BattleNet and (COMMUNITIES_INVITATION_FRAME_TYPE or "Community")
                    or (COMMUNITIES_INVITATION_FRAME_TYPE_CHARACTER or "Community")
            end
        elseif data.setJoinCommunity or data.setAddCommunity then
            icon:SetTexture(ns.MEDIA .. "Icons\\Plus")
            icon:SetSize(16, 16)
            icon:SetVertexColor(unpack(UI.ACCENT))
        else
            local atlas = entry.Icon and entry.Icon.GetAtlas and entry.Icon:GetAtlas()
            if atlas then icon:SetAtlas(atlas) else icon:SetTexture(entry.Icon and entry.Icon:GetTexture()) end
        end
        kind:SetText(kindText or "")
        kind:SetShown(kindText ~= nil)
        if name then
            name:ClearAllPoints()
            if kindText then
                name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -2)
                kind:ClearAllPoints()
                kind:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
            else
                name:SetPoint("LEFT", holder, "RIGHT", 10, 0)
            end
            name:SetPoint("RIGHT", card, "RIGHT", -8, 0)
        end
        Sync()
    end
    if entry.Init then hooksecurefunc(entry, "Init", Style) end
    if IsTexture(selection) then
        hooksecurefunc(selection, "Show", Sync)
        hooksecurefunc(selection, "Hide", Sync)
        hooksecurefunc(selection, "SetShown", Sync)
    end
    Style(entry, entry.GetElementData and entry:GetElementData())
end

-- Member page columns: level 44, class 50, name 150, zone 120, rank 104, note the rest;
-- next to the chat the list is 180 wide. Only points/widths on Blizzard's rows.
local COL_X = { level = 10, class = 56, name = 104, zone = 254, rank = 374, note = 478 }
local COLUMN_WIDTHS = { 46, 52, 152, 122, 106 } -- Blizzard's headers overlap by 2 px each
local LIST_EXTRA = MEMBER_W - 165
local function RowLayout(row)
    local frame = row.NameFrame
    if type(frame) ~= "table" or not frame.Name then return end
    local name = frame.Name
    if row.expanded then
        if not (row.Class and row.Class:IsShown()) then return end
        row.Level:ClearAllPoints()
        row.Level:SetPoint("LEFT", row, "LEFT", COL_X.level, 0)
        row.Level:SetWidth(COL_X.class - COL_X.level - 8)
        row.Class:ClearAllPoints()
        row.Class:SetPoint("LEFT", row, "LEFT", COL_X.class, 0)
        row.Class:SetSize(18, 18)
        local width = COL_X.zone - COL_X.name - 14
        name:SetWidth(name:GetWidth() + (width - frame:GetWidth()))
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", row, "LEFT", COL_X.name, 0)
        frame:SetWidth(width)
        row.Zone:ClearAllPoints()
        row.Zone:SetPoint("LEFT", row, "LEFT", COL_X.zone, 0)
        row.Zone:SetWidth(COL_X.rank - COL_X.zone - 8)
        row.Rank:ClearAllPoints()
        row.Rank:SetPoint("LEFT", row, "LEFT", COL_X.rank, 0)
        row.Rank:SetWidth(COL_X.note - COL_X.rank - 8)
        if not (row.GuildInfo and row.GuildInfo:IsShown()) then
            row.Note:ClearAllPoints()
            row.Note:SetPoint("LEFT", row, "LEFT", COL_X.note, 0)
            row.Note:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        end
    else
        frame:SetWidth(frame:GetWidth() + LIST_EXTRA)
        name:SetWidth(name:GetWidth() + LIST_EXTRA)
    end
    local rank = frame.RankIcon
    if rank then
        local offset = frame.PresenceIcon and frame.PresenceIcon:IsShown() and frame.PresenceIcon:GetWidth() or 0
        rank:ClearAllPoints()
        rank:SetPoint("LEFT", frame, "LEFT", (name:IsTruncated() and name:GetWidth() or name:GetStringWidth()) + offset, 0)
    end
end

-- Inactive guild members: offline for 14+ days get a subtle red background; ranks with
-- "Twink"/"Alt" in their name are excluded (alts are often away longer). Data from Blizzard's member info.
local INACTIVE_DAYS = 14
-- Alt rank: "Twink" (German) or "Alt" (English) as a separate word, case-insensitive -
-- matches "GM(Twink)", "Officer Alt", "Alts", but not "Altruist"
local function IsAltRank(rank)
    if type(rank) ~= "string" or rank == "" then return false end
    local lower = " " .. rank:lower() .. " "
    return lower:find("%f[%a]twinks?%f[%A]") ~= nil or lower:find("%f[%a]alts?%f[%A]") ~= nil
end

local function IsInactive(info)
    if not info or ns.db.guildInactive == false or not info.guildRank then return false end
    if info.presence ~= Enum.ClubMemberPresence.Offline then return false end
    if IsAltRank(info.guildRank) then return false end
    local days = (info.lastOnlineYear or 0) * 365 + (info.lastOnlineMonth or 0) * 30
        + (info.lastOnlineDay or 0) + (info.lastOnlineHour or 0) / 24
    return days >= INACTIVE_DAYS
end

-- Member list row: Blizzard's stripes and blue hover removed, flat row, Surf Green hover
local function SkinMemberRow(row)
    if not Once(row) then return end
    Fade(row:GetNormalTexture())
    Fade(row:GetHighlightTexture())
    -- no row background, just a light hover
    local hover = Tex(row, "HIGHLIGHT", 0, { 1, 1, 1, 0.04 })
    hover:SetAllPoints()
    local inactive = Tex(row, "BACKGROUND", -7, { 0.85, 0.2, 0.2, 0.1 })
    inactive:SetAllPoints()
    inactive:Hide()
    local function Mark(self) inactive:SetShown(IsInactive(self.memberInfo)) end
    for _, method in ipairs({ "SetMember", "UpdateNameFrame", "RefreshExpandedColumns" }) do
        if row[method] then hooksecurefunc(row, method, Mark) end
    end
    if row.UpdateNameFrame then hooksecurefunc(row, "UpdateNameFrame", RowLayout) end
    if row.RefreshExpandedColumns then hooksecurefunc(row, "RefreshExpandedColumns", RowLayout) end
    local header = row.ProfessionHeader
    if type(header) == "table" then
        for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(header[key]) end
    end
end

-- Column headers (extended member list): flat fields with hover. Visuals only - no scripts on
-- the column bar (otherwise WoW later blocks editing notes/ranks).
local function SkinColumnHeaders(display)
    if type(display) ~= "table" or not display.GetChildren then return end
    for _, column in ipairs({ display:GetChildren() }) do
        -- Guild/character community (level + class in front): set column widths, widen name column like the rows
        if column:IsObjectType("Button") and column:IsShown() and COLUMN_WIDTHS[column:GetID()]
            and display:GetParent() and display:GetParent().columnInfo and #display:GetParent().columnInfo == 6 then
            column:SetWidth(COLUMN_WIDTHS[column:GetID()])
        end
        if column:IsObjectType("Button") and Once(column) then
            -- one continuous bar (on the column header bar), no dividers
            for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(column[key]) end
            Fade(column:GetHighlightTexture())
            FadeRegions(column)
            local hover = Tex(column, "HIGHLIGHT", 0, { 1, 1, 1, 0.04 })
            hover:SetAllPoints()
        end
    end
end

-- Rows with their own artwork (perks, rewards, news): artwork removed, flat row;
-- icons, lock and lock overlay unchanged (Blizzard tints them itself)
local ROW_KEEP = { "Icon", "icon", "Lock", "DisabledBG" }
local function FlatRow(row)
    if not Once(row) then return end
    local UI = ns.UI
    local keep = {}
    for _, key in ipairs(ROW_KEEP) do
        if row[key] then keep[row[key]] = true end
    end
    local highlight = row.GetHighlightTexture and row:GetHighlightTexture()
    if highlight then Fade(highlight) end
    FadeRegions(row, keep)
    for _, key in ipairs({ "NormalBorder", "DisabledBorder" }) do FadeRegions(row[key]) end
    local bg = Tex(row, "BACKGROUND", -8, { UI.FIELD[1], UI.FIELD[2], UI.FIELD[3], 0.6 })
    bg:SetPoint("TOPLEFT", 0, -1)
    bg:SetPoint("BOTTOMRIGHT", 0, 1)
    if row.IsObjectType and row:IsObjectType("Button") then
        local hover = Tex(row, "HIGHLIGHT", 0, { UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.12 })
        hover:SetAllPoints(bg)
    end
end

-- dark background behind an area (replaces parchment/list background)
local function Fill(frame, alpha)
    if type(frame) ~= "table" or not frame.CreateTexture then return end
    local bg = Tex(frame, "BACKGROUND", -8, { 0, 0, 0, alpha or 0.35 })
    bg:SetAllPoints()
    return bg
end

-- Side tabs (chat, members, perks, info ...): like mUI window tabs - box in window color,
-- icon cropped, inactive desaturated, active with a 2 px Surf Green inner border.
-- Size, position and click stay Blizzard's.
local function SkinSideTab(tab)
    if type(tab) ~= "table" or not tab.Icon or not Once(tab) then return end
    local UI = ns.UI
    local keep = { [tab.Icon] = true }
    if tab.IconOverlay then keep[tab.IconOverlay] = true end
    FadeRegions(tab, keep)
    FadeButtonTextures(tab)
    local bg = Tex(tab, "BACKGROUND", -8, ns.STYLE.panelColor)
    bg:SetAllPoints()
    Border(tab)
    tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hover = Tex(tab, "HIGHLIGHT", 0, { 1, 1, 1, 0.08 })
    hover:SetAllPoints()
    local active = Border(tab, true, 2)
    for _, edge in ipairs(active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    local function Update()
        local on = tab:GetChecked() and not overview.open and true or false
        for _, edge in ipairs(active) do edge:SetShown(on) end
        tab.Icon:SetDesaturated(not on)
    end
    overview.updates[#overview.updates + 1] = Update
    -- Clicking a Blizzard tab closes the overview
    tab:HookScript("OnClick", function() if overview.Close then overview.Close() end end)
    hooksecurefunc(tab, "SetChecked", Update)
    tab:HookScript("OnClick", Update)
    tab:HookScript("OnShow", Update)
    Update()
end

-- Areas -------------------------------------------------------------------------------------------

local function SkinShell(f)
    FadeRegions(f) -- Blizzard's rock background and top strip
    Fade(f.NineSlice)
    Panel(f)
    local title = f.TitleContainer and f.TitleContainer.TitleText
    if title then
        local _, size = title:GetFont()
        title:SetFont(ns.FontFor("bold"), size or 12, "")
        title:SetTextColor(unpack(ns.UI.TEXT))
    end
    SkinIconButton(f.CloseButton, "Close", 18)
    -- Positioned like all mUI windows (above the chat, else right of other open windows).
    -- Blizzard's panel management (UIPanel, area "left") reset the frame to the top left on every
    -- tab/size change. Via SetUIPanelAttribute it gets no area: ShowUIPanel then only shows it and
    -- never moves it. Esc still closes it (UISpecialFrames).
    local function Unmanage()
        if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
        if SetUIPanelAttribute then SetUIPanelAttribute(f, "area", nil) end
        local listed = false
        for _, name in ipairs(UISpecialFrames) do if name == "CommunitiesFrame" then listed = true end end
        if not listed then tinsert(UISpecialFrames, "CommunitiesFrame") end
    end
    Unmanage()
    -- Side tabs stick out to the right: neighboring windows move behind them
    if ns.EXTRA_RIGHT then
        ns.EXTRA_RIGHT[f] = function(window)
            local right = window:GetRight()
            local edge = right
            for _, key in ipairs(SIDE_TABS) do
                local tab = window[key]
                if type(tab) == "table" and tab:IsShown() and tab:GetRight() then edge = math.max(edge, tab:GetRight()) end
            end
            return right and (edge - right) or 0
        end
    end
    -- Same height as mUI windows. Not via SetScale (that scaled all fonts 1.5x): Blizzard's large
    -- mode (814 x 426) is resized to 940 x 640, content stretches, fonts stay.
    -- The mini mode (322 x 406) stays Blizzard's.
    local BLIZZ_W, BLIZZ_H = 814, 426
    local function FitSize(self)
        if self:GetScale() ~= 1 then self:SetScale(1) end
        local w, h = self:GetSize()
        if math.abs(w - BLIZZ_W) < 1 and math.abs(h - BLIZZ_H) < 1 then
            self:SetSize(WIN_W, WIN_H) -- target size 940 x 640
        end
    end
    f:HookScript("OnSizeChanged", function(self)
        FitSize(self)
        if self:IsShown() and ns.ResetWindowPosition then
            ns.ResetWindowPosition(self, "guild")
        end
    end)
    FitSize(f)
    f:HookScript("OnShow", function(self)
        FitSize(self)
        C_Timer.After(0, function()
            if self:IsShown() and ns.ResetWindowPosition then
                ns.ResetWindowPosition(self, "guild", not InCombatLockdown()) -- don't close anything in combat
            end
        end)
    end)
    -- Close/minimize sized like mUI windows: visible 26 px (button 34, background inset 4 px),
    -- icon 18; placed in Blizzard's header band so nothing overlaps. Unprotected, no taint risk.
    if f.CloseButton then
        f.CloseButton:SetSize(34, 34)
        f.CloseButton:ClearAllPoints()
        f.CloseButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(HEAD_PAD - 4), -(HEAD_PAD - 4))
    end
    local maxMin = f.MaximizeMinimizeFrame
    -- Minimize isn't needed: hide it
    if maxMin then
        maxMin:SetAlpha(0)
        maxMin:EnableMouse(false)
        for _, button in ipairs({ maxMin.MaximizeButton, maxMin.MinimizeButton }) do
            if button then button:SetAlpha(0) button:EnableMouse(false) end
        end
    end
    SkinInset(f.Inset)
end

local function SkinCommunitiesList(list)
    if type(list) ~= "table" then return end
    -- Don't touch Blizzard's list (row height/padding): that taints it and WoW then blocks setting
    -- community icons during setup. Spacing is purely visual: 60 px card in the 68 px row.
    -- no column background, only the entry cards
    for _, key in ipairs({ "Bg", "TopFiligree", "BottomFiligree" }) do Fade(list[key]) end
    FadeRegions(list.FilligreeOverlay)
    SkinInset(list.InsetFrame)
    SkinScrollBar(list.ScrollBar)
    HookScrollBox(list.ScrollBox, SkinListEntry)
end

local function SkinChat(f)
    local chat = f.Chat
    if type(chat) == "table" then
        -- Box in mUI grey with a fine edge (background on the chat frame itself, so it is safely below
        -- the text), text with padding, scrollbar inside on the right (PlaceAll)
        SkinInset(chat.InsetFrame)
        local fill = Tex(chat, "BACKGROUND", -8, BOX)
        fill:SetAllPoints(chat)
        Border(chat)
        SkinScrollBar(chat.ScrollBar)
    end
    SkinButton(_G.JumpToUnreadButton)
    -- Blizzard's art is 32 high with lots of air; the visible field is about 22 high like Blizzard's
    SkinEditBox(f.ChatEditBox, { -4, -5, 4, 5 }, BOX)
end

local function SkinMemberList(members)
    if type(members) ~= "table" then return end
    local inset = members.InsetFrame
    if type(inset) == "table" then
        -- Box only next to the chat; no background on the member page
        SkinInset(inset)
        local fill = Tex(members, "BACKGROUND", -8, BOX)
        fill:SetAllPoints(inset)
        memberDeco.fill = fill
        memberDeco.edges = Border(inset)
    end
    SkinScrollBar(members.ScrollBar)
    SkinCheck(members.ShowOfflineButton)
    -- Position per view (chat/members) is set by PlaceAll; Blizzard resets it here
    if members.RefreshLayout then
        hooksecurefunc(members, "RefreshLayout", function(self) if PlaceAll then PlaceAll(self:GetParent()) end end)
    end
    local display = members.ColumnDisplay
    if type(display) == "table" then
        for _, key in ipairs({ "Background", "TopTileStreaks", "InsetBorderTopLeft", "InsetBorderTopRight",
            "InsetBorderBottomLeft", "InsetBorderTop", "InsetBorderLeft" }) do
            Fade(display[key])
        end
        local bar = Tex(display, "BACKGROUND", -8, BOX)
        bar:SetPoint("BOTTOMLEFT", display, "BOTTOMLEFT", 2, 0)
        bar:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", 0, 0)
        bar:SetHeight(26)
        SkinColumnHeaders(display)
        if display.LayoutColumns then
            hooksecurefunc(display, "LayoutColumns", SkinColumnHeaders)
        end
    end
    HookScrollBox(members.ScrollBox, SkinMemberRow)
end

local TAB_SIZE, TAB_STEP = 40, 46 -- like mUI window tabs (professions, spellbook)

-- Tabs like mUI windows: 40 px, 6 px from the window, stacked without gaps for hidden tabs.
-- Blizzard resets the points in UpdateCommunitiesTabs - we reorder afterwards.
-- The tabs are not protected.
local function LayoutTabs(f)
    local slot = 0
    for _, key in ipairs(SIDE_TABS) do
        local tab = f[key]
        if type(tab) == "table" and tab.SetPoint then
            tab:SetSize(TAB_SIZE, TAB_SIZE)
            if tab.Icon then
                -- exactly like mUI window tabs (professions): icon inset 2 px, dark border
                tab.Icon:ClearAllPoints()
                tab.Icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -2)
                tab.Icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
                -- don't round to whole pixels (the edge doesn't either) - else a 1 px gap on the left
                if tab.Icon.SetSnapToPixelGrid then
                    tab.Icon:SetSnapToPixelGrid(false)
                    tab.Icon:SetTexelSnappingBias(0)
                end
            end
            if tab:IsShown() then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, -60 - slot * TAB_STEP) -- like professions, spellbook, legacy
                slot = slot + 1
            end
        end
    end
    if overview.Layout then overview.Layout(slot) end
end

local function SkinTabs(f)
    for _, key in ipairs(SIDE_TABS) do SkinSideTab(f[key]) end
    if f.UpdateCommunitiesTabs then hooksecurefunc(f, "UpdateCommunitiesTabs", LayoutTabs) end
    f:HookScript("OnShow", LayoutTabs)
    LayoutTabs(f)
end

local function SkinControls(f)
    for _, key in ipairs({ "StreamDropdown", "CommunitiesListDropdown", "GuildMemberListDropdown",
        "CommunityMemberListDropdown", "AddToChatButton" }) do
        SkinDropdown(f[key])
    end
    SkinButton(f.InviteButton)
    SkinButton(f.GuildLogButton)
    local control = f.CommunitiesControlFrame
    if type(control) == "table" then
        SkinButton(control.CommunitiesSettingsButton)
        SkinButton(control.GuildControlButton)
        SkinButton(control.GuildRecruitmentButton)
    end
end

-- Guild reputation bar: Blizzard's border removed, flat Surf Green bar
local function SkinFactionBar(bar)
    if type(bar) ~= "table" or not bar.Progress or not Once(bar) then return end
    for _, key in ipairs({ "Left", "Middle", "Right", "Shadow", "BG" }) do Fade(bar[key]) end
    local trough = Tex(bar, "BACKGROUND", -8, INPUT)
    if IsTexture(bar.BG) then trough:SetAllPoints(bar.BG) else trough:SetAllPoints() end
    Edges(bar, trough)
    bar.Progress:SetTexture(ns.STYLE.barTexture or WHITE)
    local a = ns.UI.ACCENT
    bar.Progress:SetVertexColor(a[1] * 0.85, a[2] * 0.85, a[3] * 0.85)
end

local INSET_BORDERS = { "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft",
    "InsetBorderBottomRight", "InsetBorderLeft", "InsetBorderRight", "InsetBorderTopLeft2",
    "InsetBorderBottomLeft2", "InsetBorderLeft2" }

local function SkinBenefits(benefits)
    if type(benefits) ~= "table" then return end
    for _, key in ipairs(INSET_BORDERS) do Fade(benefits[key]) end
    for _, section in ipairs({ benefits.Perks, benefits.Rewards }) do
        if type(section) == "table" then
            FadeRegions(section)
            Fill(section)
            SkinScrollBar(section.ScrollBar)
            HookScrollBox(section.ScrollBox, FlatRow)
        end
    end
    SkinFactionBar(benefits.FactionFrame and benefits.FactionFrame.Bar)
end

-- Text link button ("[Click to edit]") as an icon like mUI windows: text invisible,
-- button 20 x 20, icon centered, explanation in the tooltip. Click stays Blizzard's.
local L_EDIT = GUILD_EDIT_TEXT_LINK and GUILD_EDIT_TEXT_LINK:gsub("[%[%]]", "") or EDIT
local L_FILTER = GUILD_SET_FILTERS_LINK and GUILD_SET_FILTERS_LINK:gsub("[%[%]]", "") or FILTER
local function IconLink(button, iconName, tooltip)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    local label = button:GetFontString()
    if label then label:SetAlpha(0) end
    button:SetSize(22, 22)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Border(button)
    local icon = UI.Icon(button, iconName, 12, UI.TEXT)
    own[icon] = true
    icon:SetPoint("CENTER")
    button:HookScript("OnEnter", function(self)
        icon:SetVertexColor(unpack(UI.ACCENT))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(tooltip or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function()
        icon:SetVertexColor(unpack(UI.TEXT))
        GameTooltip:Hide()
    end)
end

-- Preferred play settings (language, location): dropdowns and "Apply" as everywhere
-- Section heading: rune look (Cinzel, bronze-gold)
local function SectionTitle(fs)
    if not fs then return end
    own[fs] = true
    fs:SetFont(ns.FontFor("display"), ns.FontPx(13), "")
    fs:SetTextColor(unpack(ns.UI.HEADING))
end

-- find an unnamed font string of a frame by its text
local function FindText(frame, text)
    if type(frame) ~= "table" or not frame.GetRegions or not text then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= frame.TitleText and region.IsObjectType and region:IsObjectType("FontString")
            and region:GetText() == text then return region end
    end
end

-- dark box with border (optional Surf Green stripe on the left) - visuals only
local function MakeBox(parent, strip)
    local box = CreateFrame("Frame", nil, parent)
    box:SetFrameLevel(math.max(parent:GetFrameLevel() - 1, 0))
    local bg = box:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(BOX))
    ns.AddBorder(box)
    if strip then
        local line = box:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT")
        line:SetPoint("BOTTOMLEFT")
        line:SetWidth(2)
        line:SetColorTexture(unpack(ns.UI.ACCENT))
    end
    return box
end

-- Preferred play settings (language, location)
local function SkinPreferredPlay(frame)
    if type(frame) ~= "table" then return end
    SkinDropdown(frame.LocaleDropdown)
    SkinDropdown(frame.DatacenterDropdown)
    SkinButton(frame.LocaleApplyButton)
    SkinButton(frame.DatacenterApplyButton)
    SectionTitle(frame.LocaleLabel)
    SectionTitle(frame.DatacenterLabel)
    if frame.Title then
        own[frame.Title] = true
        frame.Title:SetFont(ns.FontFor("bold"), ns.FontPx(15), "")
        frame.Title:SetTextColor(unpack(ns.UI.TEXT))
    end
end

local function LayoutPreferredPlay(frame)
    if type(frame) ~= "table" then return end
    if frame.Title then
        frame.Title:ClearAllPoints()
        frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -8)
    end
    for _, pair in ipairs({ { frame.LocaleDropdown, frame.LocaleApplyButton }, { frame.DatacenterDropdown, frame.DatacenterApplyButton } }) do
        local dropdown, apply = pair[1], pair[2]
        if dropdown then dropdown:SetSize(270, 28) end
        if apply and dropdown then
            apply:SetSize(134, 28)
            apply:ClearAllPoints()
            apply:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)
        end
    end
end

-- Info page: two halves (12 px gap); left "Message of the Day" (box with Surf Green stripe)
-- and below it "Guild Information" (box 150 high), right "Guild News";
-- edit/filter as 22 px icon buttons right of the heading.
local infoParts = {}
local LayoutDetails -- defined below
local function SkinDetails(details)
    if type(details) ~= "table" then return end
    for _, key in ipairs(INSET_BORDERS) do Fade(details[key]) end
    local info, news = details.Info, details.News
    if type(info) ~= "table" or type(news) ~= "table" then return end
    FadeRegions(info) -- parchment, header bar, divider bar
    FadeRegions(news)
    IconLink(info.EditMOTDButton, "Edit", L_EDIT)
    IconLink(info.EditDetailsButton, "Edit", L_EDIT)
    IconLink(news.SetFiltersButton, "Filter", L_FILTER)
    for _, key in ipairs({ "MOTDScrollFrame", "DetailsFrame" }) do
        local scroll = info[key]
        if type(scroll) == "table" then SkinScrollBar(scroll.ScrollBar) end
    end
    SkinScrollBar(news.ScrollBar)
    HookScrollBox(news.ScrollBox, FlatRow)
    if info.TitleText then info.TitleText:SetAlpha(0) end
    if news.TitleText then news.TitleText:SetAlpha(0) end
    infoParts.motdLabel = info.Header1Label
    infoParts.detailsLabel = FindText(info, GUILD_INFORMATION)
    infoParts.newsLabel = FindText(news, GUILD_NEWS)
    SectionTitle(infoParts.motdLabel)
    SectionTitle(infoParts.detailsLabel)
    SectionTitle(infoParts.newsLabel)
    infoParts.header3 = info.GetName and info:GetName() and _G[info:GetName() .. "Header3"]
    infoParts.motdBox = MakeBox(info, true)
    infoParts.detailsBox = MakeBox(info)
    infoParts.newsBox = MakeBox(news)
    local empty = infoParts.detailsBox:CreateFontString(nil, "OVERLAY")
    empty:SetFont(ns.FontFor(), ns.FontPx(12), "")
    empty:SetTextColor(unpack(ns.UI.MUTED))
    empty:SetPoint("TOPLEFT", 12, -12)
    empty:SetText(ns.L["No guild information."])
    infoParts.empty = empty
    details:HookScript("OnShow", function()
        if PlaceAll then PlaceAll(details:GetParent()) C_Timer.After(0, function() PlaceAll(details:GetParent()) end) end
    end)
    -- On show (without challenges) Blizzard puts text and pen back at the old position -
    -- reapply our layout afterwards
    if CommunitiesGuildInfoFrame_HideChallenges then
        hooksecurefunc("CommunitiesGuildInfoFrame_HideChallenges", function(self)
            if self == info then LayoutDetails(details) end
        end)
    end
end

LayoutDetails = function(details)
    if type(details) ~= "table" or not infoParts.motdBox then return end
    local info, news = details.Info, details.News
    local width = details:GetWidth()
    if not width or width < 300 then return end
    local half = math.floor((width - 12) / 2)
    info:ClearAllPoints()
    info:SetPoint("TOPLEFT", details, "TOPLEFT")
    info:SetPoint("BOTTOMLEFT", details, "BOTTOMLEFT")
    info:SetWidth(half)
    news:ClearAllPoints()
    news:SetPoint("TOPRIGHT", details, "TOPRIGHT")
    news:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT")
    news:SetWidth(half)
    -- Message of the Day
    if infoParts.motdLabel then
        infoParts.motdLabel:ClearAllPoints()
        infoParts.motdLabel:SetPoint("LEFT", info, "TOPLEFT", 0, -11)
    end
    if info.EditMOTDButton then
        info.EditMOTDButton:ClearAllPoints()
        info.EditMOTDButton:SetPoint("TOPRIGHT", info, "TOPRIGHT", 0, 0)
    end
    -- invisible header bar: Blizzard anchors text and pen to it - placed so both fit
    if info.Header1 then
        info.Header1:ClearAllPoints()
        info.Header1:SetPoint("TOPLEFT", info, "TOPLEFT", -2, -15)
        info.Header1:SetSize(half, 22)
    end
    local motdBox = infoParts.motdBox
    motdBox:ClearAllPoints()
    motdBox:SetPoint("TOPLEFT", info, "TOPLEFT", 0, -28)
    motdBox:SetPoint("BOTTOMRIGHT", info, "BOTTOMRIGHT", 0, 186)
    local motd = info.MOTDScrollFrame
    if motd then
        motd:ClearAllPoints()
        motd:SetPoint("TOPLEFT", motdBox, "TOPLEFT", 12, -10)
        motd:SetPoint("BOTTOMRIGHT", motdBox, "BOTTOMRIGHT", -12, 10)
        if motd.MOTD and math.abs((motd.MOTD:GetWidth() or 0) - (half - 24)) > 0.5 then
            -- SimpleHTML only rewraps on the next text
            motd.MOTD:SetWidth(half - 24)
            if C_GuildInfo and C_GuildInfo.GetMOTD then motd.MOTD:SetText(C_GuildInfo.GetMOTD() or "", true) end
        end
    end
    -- Guild Information
    if infoParts.detailsLabel then
        infoParts.detailsLabel:ClearAllPoints()
        infoParts.detailsLabel:SetPoint("LEFT", info, "BOTTOMLEFT", 0, 167)
    end
    if info.EditDetailsButton then
        info.EditDetailsButton:ClearAllPoints()
        info.EditDetailsButton:SetPoint("BOTTOMRIGHT", info, "BOTTOMRIGHT", 0, 156)
    end
    local detailsBox = infoParts.detailsBox
    detailsBox:ClearAllPoints()
    detailsBox:SetPoint("BOTTOMLEFT", info, "BOTTOMLEFT")
    detailsBox:SetPoint("TOPRIGHT", info, "BOTTOMRIGHT", 0, 150)
    local scroll = info.DetailsFrame
    if scroll then
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", detailsBox, "TOPLEFT", 12, -10)
        scroll:SetPoint("BOTTOMRIGHT", detailsBox, "BOTTOMRIGHT", -16, 10)
        local child = scroll.GetScrollChild and scroll:GetScrollChild()
        if child then
            child:SetWidth(half - 32)
            if child.Details then
                child.Details:SetWidth(half - 32)
                infoParts.empty:SetShown((child.Details:GetText() or "") == "")
            end
        end
    end
    -- Guild News
    if infoParts.newsLabel then
        infoParts.newsLabel:ClearAllPoints()
        infoParts.newsLabel:SetPoint("LEFT", news, "TOPLEFT", 0, -11)
    end
    if news.SetFiltersButton then
        news.SetFiltersButton:ClearAllPoints()
        news.SetFiltersButton:SetPoint("TOPRIGHT", news, "TOPRIGHT", 0, 0)
    end
    local newsBox = infoParts.newsBox
    newsBox:ClearAllPoints()
    newsBox:SetPoint("TOPLEFT", news, "TOPLEFT", 0, -28)
    newsBox:SetPoint("BOTTOMRIGHT", news, "BOTTOMRIGHT")
    if news.Header then
        -- Blizzard anchors the list to the bottom of this (invisible) bar
        news.Header:ClearAllPoints()
        news.Header:SetPoint("TOPLEFT", newsBox, "TOPLEFT", 4, 18)
        news.Header:SetSize(half - 16, 22)
    end
    if news.ScrollBox then
        news.ScrollBox:SetPoint("BOTTOMRIGHT", newsBox, "BOTTOMRIGHT", -12, 4)
    end
end

-- Popups ------------------------------------------------------------------------------------------

local function SkinMemberDetail(detail)
    if type(detail) ~= "table" or not Once(detail) then return end
    local border = detail.Border
    FadeRegions(border) -- dialog border (NineSlice) and dark background
    Panel(detail, type(border) == "table" and border or nil)
    SkinIconButton(detail.CloseButton, "Close")
    SkinButton(detail.RemoveButton)
    SkinButton(detail.GroupInviteButton)
    SkinDropdown(detail.RankDropdown)
    SkinBackdropBox(detail.NoteBackground, 0.8)
    SkinBackdropBox(detail.OfficerNoteBackground, 0.8)
    -- wider, clear hierarchy: big name, small grey labels/level, normal values, smaller note text
    local UI, W = ns.UI, 260
    detail:SetWidth(W)
    local function Font(fs, size, role, color)
        if type(fs) ~= "table" or not fs.SetFont then return end
        ns.SetFont(fs, size, "", role)
        if color then fs:SetTextColor(unpack(color)) end
    end
    Font(detail.Name, 15, "bold", UI.TEXT)
    Font(detail.Level, 11, nil, UI.MUTED)
    for _, key in ipairs({ "ZoneLabel", "RankLabel", "OnlineLabel", "NoteLabel", "OfficerNoteLabel" }) do
        Font(detail[key], 11, nil, UI.MUTED)
    end
    for _, key in ipairs({ "ZoneText", "RankText", "OnlineText" }) do Font(detail[key], 12, nil, UI.TEXT) end
    for _, pair in ipairs({ { "NoteBackground", "PersonalNoteText" }, { "OfficerNoteBackground", "OfficerNoteText" } }) do
        local box = detail[pair[1]]
        if type(box) == "table" then
            box:SetWidth(W - 32)
            local text = box[pair[2]] or detail[pair[2]]
            if type(text) == "table" then text:SetWidth(W - 48) Font(text, 11, nil, UI.TEXT) end
        end
    end
    local remove, invite = detail.RemoveButton, detail.GroupInviteButton
    if remove and invite then
        local bw = (W - 32 - 8) / 2
        remove:SetWidth(bw)
        invite:SetWidth(bw)
        invite:ClearAllPoints()
        invite:SetPoint("LEFT", remove, "RIGHT", 8, 0)
    end
    -- Blizzard sizes the frame for its own (smaller) fonts: grow it so the buttons sit below the notes
    local function Fit()
        local top = detail:GetTop()
        local box = detail.OfficerNoteBackground
        if not (type(box) == "table" and box:IsShown()) then box = detail.NoteBackground end
        local bottom = type(box) == "table" and box:GetBottom()
        if not (top and bottom) then return end
        local need = top - bottom + 12 + 22 + 12 -- gap, button, bottom margin
        if need > detail:GetHeight() + 0.5 then detail:SetHeight(need) end
    end
    -- Placed like the other guild sub-windows: top edge shared, right of the side tabs
    local function Place()
        if detail:IsShown() and ns.ResetWindowPosition then ns.ResetWindowPosition(detail, "guildsub", false) end
        Fit()
    end
    detail:HookScript("OnShow", function() C_Timer.After(0, Place) end)
    if detail.DisplayMember then hooksecurefunc(detail, "DisplayMember", function() C_Timer.After(0, Fit) end) end
end

-- old dialog template (guild log, edit text, news filter): corner border removed, mUI popup
local function SkinOldDialog(frame)
    if type(frame) ~= "table" or not frame.GetRegions or not Once(frame) then return end
    FadeRegions(frame)
    Panel(frame)
    -- two buttons can be called "Close": the X at the top (no text) and the text button at the bottom
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("CheckButton") then -- check before "Button": CheckButton is also a Button
            SkinCheck(child)
        elseif child:IsObjectType("Button") then
            local label = child:GetFontString()
            local text = label and label:GetText()
            if text and text ~= "" then
                SkinButton(child)
            else
                local normal = child:GetNormalTexture()
                local atlas = normal and normal.GetAtlas and normal:GetAtlas()
                if atlas and atlas:find("RedButton%-Exit") then SkinIconButton(child, "Close") end
            end
        end
    end
    local container = frame.Container
    if type(container) == "table" then
        SkinBackdropBox(container, 0.9)
        local scroll = container.ScrollFrame
        if type(scroll) == "table" then SkinScrollBar(scroll.ScrollBar) end
    end
    for _, check in ipairs(frame.GuildNewsFilterButtons or {}) do SkinCheck(check) end
end

local function SkinSettingsDialog(dialog)
    if type(dialog) ~= "table" or not Once(dialog) then return end
    FadeRegions(dialog.BG)
    Panel(dialog)
    SkinEditBox(dialog.NameEdit)
    SkinEditBox(dialog.ShortNameEdit)
    SkinInputScroll(dialog.MessageOfTheDay)
    SkinInputScroll(dialog.Description)
    for _, key in ipairs({ "ChangeAvatarButton", "Delete", "Accept", "Cancel" }) do SkinButton(dialog[key]) end
    for _, key in ipairs({ "ClubFocusDropdown", "LookingForDropdown", "LanguageDropdown" }) do
        SkinDropdown(dialog[key])
    end
    local cross = dialog.CrossFactionToggle
    if type(cross) == "table" then SkinCheck(cross.CheckButton) end
    for _, key in ipairs({ "ShouldListClub", "AutoAcceptApplications", "MaxLevelOnly", "MinIlvlOnly" }) do
        local row = dialog[key]
        if type(row) == "table" then SkinCheck(row.Button) end
    end
    local ilvl = dialog.MinIlvlOnly
    if type(ilvl) == "table" then SkinEditBox(ilvl.EditBox) end
end

-- Startup -------------------------------------------------------------------------------------------

-- each area on its own: if something is missing in Forever or Blizzard changes something, the rest stays skinned
-- Header: round portrait removed, title on the left "Guild name - Guild & Communities" in mUI bold;
-- chat in mUI font; Blizzard's yellow/green text in mUI colors (class colors stay untouched).
local YELLOW, GREEN = { 1, 0.82, 0 }, { 0.1, 1, 0.1 }
local function Near(r, g, b, c) return math.abs(r - c[1]) < 0.05 and math.abs(g - c[2]) < 0.05 and math.abs(b - c[3]) < 0.05 end
local recolored = setmetatable({}, { __mode = "k" })
local function Recolor(fs)
    if recolored[fs] == "busy" then return end
    local r, g, b = fs:GetTextColor()
    if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return end
    if r and (Near(r, g, b, YELLOW) or Near(r, g, b, GREEN)) then
        recolored[fs] = "busy"
        fs:SetTextColor(unpack(ns.UI.TEXT))
        recolored[fs] = true
    end
end
-- Blizzard's small fonts (10-12 px) slightly larger in the big window; headings (13 px and up)
-- stay. Blizzard sometimes resets font objects - then reapply.
local FONT_BUMP = 2
local bumping = false
local function Bump(fs)
    if bumping then return end
    local file, size, flags = fs:GetFont()
    if not (file and size) or size >= 13 then return end
    bumping = true
    fs:SetFont(file, size + FONT_BUMP, flags or "")
    bumping = false
end

local function RecolorTree(frame, depth, fixed)
    if depth > 12 or not frame.GetRegions then return end
    fixed = fixed or noBump[frame]
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") and not own[region] then
            if not recolored[region] then
                recolored[region] = true
                hooksecurefunc(region, "SetTextColor", Recolor)
                if not fixed then
                    hooksecurefunc(region, "SetFontObject", Bump)
                    Bump(region)
                end
            end
            Recolor(region)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do RecolorTree(child, depth + 1, fixed) end
end

local function SkinLikeOwnWindow(f)
    local UI = ns.UI
    -- portrait and Blizzard's title off, own title on the left
    if f.PortraitOverlay then f.PortraitOverlay:SetAlpha(0) end
    if f.PortraitContainer then f.PortraitContainer:SetAlpha(0) end
    local title = f.TitleContainer and f.TitleContainer.TitleText
    if title then title:SetAlpha(0) end
    -- Header like mUI windows (professions): crest 46 px on the left, name (bold 16) and
    -- "Guild & Communities" below; X/minimize on the right, microphone next to it, online count
    -- below. Content starts below the header.
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(HEAD_ICON, HEAD_ICON)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", HEAD_PAD, -HEAD_PAD)
    if ns.AddSlotBackground then ns.AddSlotBackground(holder) end
    ns.AddBorder(holder)
    local crestBg = holder:CreateTexture(nil, "BACKGROUND", nil, 2)
    own[crestBg] = true
    crestBg:SetPoint("TOPLEFT", 2, -2)
    crestBg:SetPoint("BOTTOMRIGHT", -2, 2)
    local crest = holder:CreateTexture(nil, "ARTWORK")
    own[crest] = true
    crest:SetPoint("CENTER")
    local name = holder:CreateFontString(nil, "OVERLAY")
    own[name] = true
    name:SetFont(ns.FontFor("bold"), ns.FontPx(16), "")
    name:SetTextColor(unpack(UI.TEXT))
    name:SetJustifyH("LEFT")
    name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    name:SetPoint("RIGHT", f, "RIGHT", -200, 0)
    local sub = holder:CreateFontString(nil, "OVERLAY")
    own[sub] = true
    sub:SetFont(ns.FontFor(), ns.FontPx(12), "")
    sub:SetTextColor(unpack(UI.MUTED))
    sub:SetJustifyH("LEFT")
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -5)
    local lastClub
    local function UpdateTitle()
        local id = f.GetSelectedClubId and f:GetSelectedClubId()
        local info = id and C_Club.GetClubInfo(id)
        name:SetText(info and info.name or (title and title:GetText()) or "")
        -- "Guild & Communities - 11 of 24 online"
        local online, total
        if info and info.clubType == Enum.ClubType.Guild and GetNumGuildMembers then
            local all, on = GetNumGuildMembers()
            total, online = all, on
        end
        local base = title and title:GetText() or ""
        if total and total > 0 then
            local count = ns.L["%d of %d online"]:format(online or 0, total)
            sub:SetText(base .. "  ·  " .. count)
        else
            sub:SetText(base)
        end
        if info and id ~= lastClub then
            lastClub = id
            local size = HEAD_ICON - 4
            if info.clubType == Enum.ClubType.Guild and SetLargeGuildTabardTextures then
                crestBg:SetTexture("Interface\\Buttons\\WHITE8X8")
                crestBg:Show()
                crest:SetSize(size, size)
                SetLargeGuildTabardTextures("player", crest, crestBg)
            else
                crestBg:Hide()
                crest:SetTexCoord(0, 1, 0, 1)
                crest:SetVertexColor(1, 1, 1)
                crest:SetSize(size, size)
                crest:SetTexture(nil) -- setting the community icon is protected
            end
        end
    end
    local function HeaderLayout()
        local close = f.CloseButton
        if close then
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(HEAD_PAD - 4), -(HEAD_PAD - 4))
        end
        if PlaceAll then PlaceAll(f) end
    end
    f:HookScript("OnSizeChanged", HeaderLayout)
    f:HookScript("OnShow", function() HeaderLayout() C_Timer.After(0, HeaderLayout) end)
    HeaderLayout()
    -- Chat in mUI font
    local messages = f.Chat and f.Chat.MessageFrame
    local function ChatFont()
        -- like the mUI chat (chat font size setting)
        local size = ns.ChatFontSize and ns.ChatFontSize() or 13
        if messages and messages.SetFont then messages:SetFont(ns.FontFor("text"), ns.FontPx(size), "") end
    end
    local elapsed = 0
    f:HookScript("OnShow", function()
        UpdateTitle()
        ChatFont()
        RecolorTree(f, 0)
    end)
    -- Club change, new rows (members, entries): refresh lightly, only while open
    f:HookScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.5 then return end
        elapsed = 0
        UpdateTitle()
        RecolorTree(f, 0)
    end)
    if f:IsShown() then UpdateTitle() ChatFont() RecolorTree(f, 0) end
end

-- Overall layout per the target design. Runs on resize/show/view change;
-- only sets points/sizes on Blizzard's frames.
local function FooterButton(f, button)
    if not button then return end
    local label = button.GetFontString and button:GetFontString()
    local textWidth = label and label:GetUnboundedStringWidth() or 0
    button:SetSize(math.max(150, textWidth + 28), 28)
end

PlaceAll = function(f)
    if type(f) ~= "table" then return end
    local list, members, chat = f.CommunitiesList, f.MemberList, f.Chat
    -- Community list: first card (Blizzard: 40 px top padding + 8 px card margin) at content height
    if list then
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(CONTENT_TOP - LIST_TOP_PAD - CARD_INSET))
        list:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", PAD + LIST_W, CONTENT_BOTTOM)
    end
    -- Member list: 180 wide next to the chat, below header + columns on the member page
    if members then
        members:ClearAllPoints()
        if members.expandedDisplay then
            members:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -(CONTENT_TOP + 64))
        else
            members:SetPoint("TOPLEFT", f, "TOPRIGHT", -(PAD + MEMBER_W), -(CONTENT_TOP + 36))
        end
        members:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, CONTENT_BOTTOM)
        -- list and scrollbar inside, box = list area
        if members.InsetFrame then
            members.InsetFrame:ClearAllPoints()
            members.InsetFrame:SetAllPoints(members)
        end
        if members.ScrollBox then
            members.ScrollBox:ClearAllPoints()
            members.ScrollBox:SetPoint("TOPLEFT", members, "TOPLEFT", 4, -2)
            members.ScrollBox:SetPoint("BOTTOMRIGHT", members, "BOTTOMRIGHT", -14, 2)
        end
        if members.ScrollBar then
            members.ScrollBar:ClearAllPoints()
            members.ScrollBar:SetPoint("TOPRIGHT", members, "TOPRIGHT", -4, -4)
            members.ScrollBar:SetPoint("BOTTOMRIGHT", members, "BOTTOMRIGHT", -4, 4)
        end
        local boxed = not members.expandedDisplay
        if memberDeco.fill then memberDeco.fill:SetShown(boxed) end
        for _, edge in ipairs(memberDeco.edges or {}) do edge:SetShown(boxed) end
        local offline = members.ShowOfflineButton
        if offline then
            offline:ClearAllPoints()
            offline:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -(CONTENT_TOP + 4))
        end
        local columns = members.ColumnDisplay
        if columns then
            columns:ClearAllPoints()
            columns:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X - 2, -(CONTENT_TOP + 36))
            columns:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(CONTENT_TOP + 36))
            columns:SetHeight(28)
        end
        -- "6/24 online" is already in the header - hide it here
        if members.MemberCount then members.MemberCount:SetAlpha(0) end
        for _, key in ipairs({ "GuildMemberListDropdown", "CommunityMemberListDropdown" }) do
            local dropdown = f[key]
            if dropdown and offline then
                dropdown:ClearAllPoints()
                dropdown:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
                dropdown:SetPoint("TOP", offline, "TOP", 0, 0)
            end
        end
    end
    -- Channel dropdown top left in the content, microphone left of the online count
    local stream = f.StreamDropdown
    if stream then
        stream:ClearAllPoints()
        stream:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -CONTENT_TOP) -- background fills the whole button
        stream:SetSize(220, 28)
    end
    local headset = f.VoiceChatHeadset
    if headset then
        -- far right, level with the channel dropdown
        headset:ClearAllPoints()
        headset:SetPoint("RIGHT", f, "TOPRIGHT", -PAD, -(CONTENT_TOP + 14))
    end
    -- Chat box and edit box below (8 px gap, field 28 high on the footer line)
    if chat and members then
        chat:ClearAllPoints()
        chat:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -(CONTENT_TOP + 36))
        chat:SetPoint("BOTTOMRIGHT", members, "BOTTOMLEFT", -8, 36)
        if chat.InsetFrame then
            chat.InsetFrame:ClearAllPoints()
            chat.InsetFrame:SetAllPoints(chat)
        end
        if chat.MessageFrame then
            chat.MessageFrame:ClearAllPoints()
            chat.MessageFrame:SetPoint("TOPLEFT", chat, "TOPLEFT", 10, -8)
            chat.MessageFrame:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", -18, 8)
        end
        if chat.ScrollBar then
            chat.ScrollBar:ClearAllPoints()
            chat.ScrollBar:SetPoint("TOPRIGHT", chat, "TOPRIGHT", -4, -6)
            chat.ScrollBar:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", -4, 6)
        end
        local input = f.ChatEditBox
        if input then
            input:ClearAllPoints()
            input:SetPoint("TOPLEFT", chat, "BOTTOMLEFT", 4, -3)
            input:SetPoint("TOPRIGHT", chat, "BOTTOMRIGHT", -4, -3)
            input:SetHeight(38)
        end
    end
    -- Info / Perks / Play settings areas
    for _, key in ipairs({ "GuildBenefitsFrame", "GuildDetailsFrame", "GuildPreferredPlaySettingsFrame" }) do
        local area = f[key]
        if area then
            area:ClearAllPoints()
            area:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -CONTENT_TOP)
            area:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, CONTENT_BOTTOM)
        end
    end
    LayoutDetails(f.GuildDetailsFrame)
    LayoutPreferredPlay(f.GuildPreferredPlaySettingsFrame)
    -- Footer buttons bottom right, 28 high, at least 150 wide
    if f.InviteButton then
        FooterButton(f, f.InviteButton)
        f.InviteButton:ClearAllPoints()
        f.InviteButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 14)
    end
    local control = f.CommunitiesControlFrame
    if control then
        for _, key in ipairs({ "GuildControlButton", "GuildRecruitmentButton", "CommunitiesSettingsButton" }) do
            FooterButton(f, control[key])
        end
        control:SetHeight(28)
        control:ClearAllPoints()
        control:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 14)
    end
    if f.GuildLogButton then
        FooterButton(f, f.GuildLogButton)
        f.GuildLogButton:ClearAllPoints()
        f.GuildLogButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 14)
    end
end

-- "Overview" tab: members per class and per level range, plus members, online and average
-- level. Own content above the content area, display only (no actions).
local OVERVIEW_ICON = 134441 -- inv_misc_spyglass_02
local function GuildSelected(f)
    local id = f.GetSelectedClubId and f:GetSelectedClubId()
    local info = id and C_Club.GetClubInfo(id)
    return info and info.clubType == Enum.ClubType.Guild and id or nil
end

local function BuildOverview(f)
    if overview.panel then return end
    local UI = ns.UI
    -- Tab like the others (40 px, icon inset 2 px, green edge when active, grey when inactive)
    local tab = CreateFrame("Button", nil, f)
    tab:SetSize(TAB_SIZE, TAB_SIZE)
    local tabBg = tab:CreateTexture(nil, "BACKGROUND")
    tabBg:SetAllPoints()
    tabBg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddBorder(tab)
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(OVERVIEW_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    local active = ns.AddBorder(tab, true, 2)
    for _, edge in ipairs(active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.L["Overview"], 1, 1, 1)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Content: covers the content area (Blizzard's view stays underneath, unchanged)
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -CONTENT_TOP)
    panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 14)
    -- on top of everything: Blizzard's chat scrollbar sits one strata higher (HIGH), the input at 1200
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(f:GetFrameLevel() + 1300)
    panel:EnableMouse(true)
    local cover = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    cover:SetPoint("TOPLEFT", -4, 4)
    cover:SetPoint("BOTTOMRIGHT", 4, -4)
    local c = ns.STYLE.panelColor
    cover:SetColorTexture(c[1], c[2], c[3], 1)
    panel:Hide()

    local function Column(anchor, title)
        local label = panel:CreateFontString(nil, "OVERLAY")
        label:SetFont(ns.FontFor("bold"), ns.FontPx(12), "")
        label:SetTextColor(unpack(UI.ACCENT))
        label:SetPoint("LEFT", panel, anchor, anchor == "TOPLEFT" and 0 or 6, -11)
        label:SetText(title)
        local box = MakeBox(panel)
        box:SetFrameLevel(panel:GetFrameLevel() + 1) -- above the content cover
        return box
    end
    local classBox = Column("TOPLEFT", ns.L["Classes"])
    local levelBox = Column("TOP", ns.L["Levels"])
    classBox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -28)
    classBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -6, 40)
    levelBox:SetPoint("TOPLEFT", panel, "TOP", 6, -28)
    levelBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 40)
    local summary = panel:CreateFontString(nil, "OVERLAY")
    summary:SetFont(ns.FontFor(), ns.FontPx(12), "")
    summary:SetTextColor(unpack(UI.MUTED))
    summary:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 6)
    local Refresh -- defined below
    -- "Mains only": hide alt ranks ("Twink"/"Alt")
    local mainsOnly = CreateFrame("Button", nil, panel)
    mainsOnly:SetHeight(20)
    mainsOnly:SetPoint("RIGHT", panel, "TOPRIGHT", 0, -11)
    local box = CreateFrame("Frame", nil, mainsOnly)
    box:SetSize(14, 14)
    box:SetPoint("RIGHT")
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(0.04, 0.04, 0.05, 1)
    for _, edge in ipairs(ns.AddBorder(box, true)) do edge:SetVertexColor(unpack(UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 })) end
    local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
    tick:SetPoint("CENTER")
    local mainsLabel = mainsOnly:CreateFontString(nil, "OVERLAY")
    mainsLabel:SetFont(ns.FontFor(), ns.FontPx(12), "")
    mainsLabel:SetTextColor(unpack(UI.TEXT))
    mainsLabel:SetPoint("RIGHT", box, "LEFT", -8, 0)
    mainsLabel:SetText(ns.L["Main characters only"])
    mainsOnly:SetWidth(mainsLabel:GetUnboundedStringWidth() + 22)
    local function SyncTick() tick:SetShown(ns.db.guildOverviewMains == true) end
    mainsOnly:SetScript("OnClick", function()
        ns.db.guildOverviewMains = not ns.db.guildOverviewMains
        SyncTick()
        PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
        if Refresh then Refresh() end
    end)
    mainsOnly:SetScript("OnEnter", function() mainsLabel:SetTextColor(unpack(UI.ACCENT)) end)
    mainsOnly:SetScript("OnLeave", function() mainsLabel:SetTextColor(unpack(UI.TEXT)) end)
    SyncTick()

    local founded = panel:CreateFontString(nil, "OVERLAY")
    founded:SetFont(ns.FontFor(), ns.FontPx(12), "")
    founded:SetTextColor(unpack(UI.MUTED))
    founded:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 6)

    -- Founding date and real players (accounts) are only available via /ginfo as a system message:
    -- query silently, parse the message and hide it from chat
    local guildFacts, asking, askedAt = {}, false, 0
    local function Parse(text)
        local date = text:match("(%d+[%./]%d+[%./]%d+)")
        local numbers = {}
        for n in text:gsub("%d+[%./]%d+[%./]%d+", ""):gmatch("%d+") do numbers[#numbers + 1] = tonumber(n) end
        if not date or #numbers < 2 then return false end
        guildFacts.founded = date
        guildFacts.characters = numbers[#numbers - 1]
        guildFacts.accounts = numbers[#numbers]
        return true
    end
    local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if addFilter then
        addFilter("CHAT_MSG_SYSTEM", function(_, _, text)
            if not asking or type(text) ~= "string" then return end
            if Parse(text) then
                asking = false
                if Refresh then C_Timer.After(0, Refresh) end
                return true -- don't show in chat
            end
            -- /ginfo first prints "Guild: <name>" - hide that too during the silent query
            local guildName = GetGuildInfo and GetGuildInfo("player")
            if guildName and text:find(guildName, 1, true) then return true end
        end)
    end
    local function AskGuildInfo()
        if not GuildInfo or GetTime() - askedAt < 60 then return end
        askedAt, asking = GetTime(), true
        C_Timer.After(3, function() asking = false end)
        GuildInfo()
    end

    local rows = {}
    local function Row(box, i)
        rows[box] = rows[box] or {}
        local row = rows[box][i]
        if row then return row end
        row = CreateFrame("Frame", nil, box)
        row:SetHeight(26)
        row:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -10 - (i - 1) * 30)
        row:SetPoint("RIGHT", box, "RIGHT", -12, 0)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT")
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFont(ns.FontFor(), ns.FontPx(12), "")
        row.name:SetJustifyH("LEFT")
        row.name:SetWidth(110)
        row.count = row:CreateFontString(nil, "OVERLAY")
        row.count:SetFont(ns.FontFor("bold"), ns.FontPx(12), "")
        row.count:SetJustifyH("RIGHT")
        row.count:SetPoint("RIGHT")
        row.count:SetWidth(30)
        row.track = row:CreateTexture(nil, "BACKGROUND")
        row.track:SetColorTexture(1, 1, 1, 0.05)
        row.track:SetHeight(8)
        row.track:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
        row.track:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetTexture(ns.STYLE.barTexture or WHITE)
        row.bar:SetHeight(8)
        row.bar:SetPoint("LEFT", row.track, "LEFT")
        rows[box][i] = row
        return row
    end
    local function Fill(box, list, maxCount)
        for i, entry in ipairs(list) do
            local row = Row(box, i)
            row.icon:SetShown(entry.icon ~= nil)
            if entry.icon then
                row.icon:SetTexture(entry.icon)
                row.icon:SetTexCoord(unpack(entry.coords or { 0, 1, 0, 1 }))
            end
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", entry.icon and 26 or 0, 0)
            row.name:SetText(entry.name)
            row.name:SetTextColor(unpack(entry.color or UI.TEXT))
            row.count:SetText(entry.count)
            local width = row.track:GetWidth() or 0
            row.bar:SetWidth(math.max(1, width * (maxCount > 0 and entry.count / maxCount or 0)))
            row.bar:SetVertexColor(unpack(entry.color or UI.ACCENT))
            row.bar:SetShown(entry.count > 0) -- no segment at 0
            row:Show()
        end
        for i = #list + 1, #(rows[box] or {}) do rows[box][i]:Hide() end
    end

    function Refresh()
        local clubId = GuildSelected(f)
        if not clubId or not panel:IsShown() then return end
        local classes, total, online, levelSum = {}, 0, 0, 0
        -- show the checkbox only if the guild has alt ranks; otherwise it has no effect
        local anyAlt, mainCount, altCount = false, 0, 0
        local filterAlts = ns.db.guildOverviewMains == true
        if GuildControlGetNumRanks and GuildControlGetRankName then
            for r = 1, GuildControlGetNumRanks() do
                if IsAltRank(GuildControlGetRankName(r)) then anyAlt = true break end
            end
        end
        mainsOnly:SetShown(anyAlt)
        if not anyAlt then filterAlts = false end
        local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 60
        local brackets = {}
        local step = maxLevel >= 60 and 20 or 10
        for low = 1, maxLevel - 1, step do
            brackets[#brackets + 1] = { low = low, high = math.min(low + step - 1, maxLevel - 1) }
        end
        brackets[1].low = 1
        brackets[#brackets + 1] = { low = maxLevel, high = maxLevel }
        for _, b in ipairs(brackets) do b.count = 0 end
        for _, memberId in ipairs(C_Club.GetClubMembers(clubId) or {}) do
            local info = C_Club.GetMemberInfo(clubId, memberId)
            local twink = info and IsAltRank(info.guildRank)
            if twink then anyAlt = true end
            if info and info.level and info.level > 0 then
                if twink then altCount = altCount + 1 else mainCount = mainCount + 1 end
            end
            if info and info.level and info.level > 0 and not (filterAlts and twink) then
                total = total + 1
                levelSum = levelSum + info.level
                if info.presence ~= Enum.ClubMemberPresence.Offline then online = online + 1 end
                if info.classID then classes[info.classID] = (classes[info.classID] or 0) + 1 end
                for _, b in ipairs(brackets) do
                    if info.level >= b.low and info.level <= b.high then b.count = b.count + 1 break end
                end
            end
        end
        local classList, maxClass = {}, 0
        for classID, count in pairs(classes) do
            local classInfo = C_CreatureInfo and C_CreatureInfo.GetClassInfo(classID)
            local file = classInfo and classInfo.classFile
            local color = file and C_ClassColor and C_ClassColor.GetClassColor(file)
            local coords = file and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file]
            classList[#classList + 1] = {
                name = classInfo and classInfo.className or "?", count = count,
                color = color and { color.r, color.g, color.b } or nil,
                icon = coords and "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes" or nil,
                coords = coords,
            }
            maxClass = math.max(maxClass, count)
        end
        table.sort(classList, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.name < b.name end)
        local levelList, maxBracket = {}, 0
        for i = #brackets, 1, -1 do
            local b = brackets[i]
            levelList[#levelList + 1] = {
                name = b.low == b.high and ns.L["Level %d"]:format(b.low) or ns.L["Level %d–%d"]:format(b.low, b.high),
                count = b.count,
            }
            maxBracket = math.max(maxBracket, b.count)
        end
        Fill(classBox, classList, maxClass)
        Fill(levelBox, levelList, maxBracket)
        -- Members and online are already in the header - here only players, mains/alts, avg level
        local parts = {}
        if guildFacts.accounts then parts[#parts + 1] = ("%s %d"):format(ns.L["Players"], guildFacts.accounts) end
        if anyAlt then
            parts[#parts + 1] = ("%s %d"):format(ns.L["Mains"], mainCount)
            parts[#parts + 1] = ("%s %d"):format(ns.L["Alts"], altCount)
        end
        parts[#parts + 1] = ("%s %s"):format(ns.L["Average level"], total > 0 and ("%.1f"):format(levelSum / total) or "–")
        summary:SetText(table.concat(parts, "  ·  "))
        founded:SetText(guildFacts.founded and ns.L["Founded on %s"]:format(guildFacts.founded) or "")
    end

    local function Visuals()
        for _, edge in ipairs(active) do edge:SetShown(overview.open) end
        icon:SetDesaturated(not overview.open)
        for _, update in ipairs(overview.updates) do update() end
    end
    function overview.Close()
        if not overview.open then return end
        overview.open = false
        panel:Hide()
        Visuals()
    end
    local function Open()
        overview.open = true
        panel:Show()
        Visuals()
        Refresh()
        C_Timer.After(0, Refresh) -- bar width is only known after layout
        AskGuildInfo()
    end
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        if overview.open then overview.Close() else Open() end
    end)
    function overview.Layout(slot)
        local show = ns.db.guildOverview ~= false and GuildSelected(f) ~= nil
        tab:SetShown(show)
        if show then
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, -60 - slot * TAB_STEP)
        else
            overview.Close()
        end
    end
    f:HookScript("OnHide", overview.Close)
    ns:On("GUILD_ROSTER_UPDATE", function() if overview.open then Refresh() end end)
    ns:On("CLUB_MEMBER_PRESENCE_UPDATED", function() if overview.open then Refresh() end end)
    overview.panel = panel
    Visuals()
end

local function Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local function Apply()
    if applied or not Enabled() then return end
    local f = _G.CommunitiesFrame
    if type(f) ~= "table" then return end
    applied = true
    Try(SkinShell, f)
    Try(SkinLikeOwnWindow, f)
    Try(SkinCommunitiesList, f.CommunitiesList)
    Try(SkinChat, f)
    Try(SkinMemberList, f.MemberList)
    Try(BuildOverview, f)
    Try(SkinTabs, f)
    Try(SkinControls, f)
    Try(SkinBenefits, f.GuildBenefitsFrame)
    Try(SkinDetails, f.GuildDetailsFrame)
    Try(SkinPreferredPlay, f.GuildPreferredPlaySettingsFrame)
    Try(SkinMemberDetail, f.GuildMemberDetailFrame)
    Try(SkinOldDialog, _G.CommunitiesGuildLogFrame)
    Try(SkinOldDialog, _G.CommunitiesGuildTextEditFrame)
    Try(SkinOldDialog, _G.CommunitiesGuildNewsFiltersFrame)
    Try(SkinSettingsDialog, _G.CommunitiesSettingsDialog)
    if f.SetDisplayMode then
        hooksecurefunc(f, "SetDisplayMode", function(self) C_Timer.After(0, function() PlaceAll(self) end) end)
    end
    Try(PlaceAll, f)
end

-- Guild settings (GuildControlUI): flat window, Surf Green title, rank fields flat with a fixed
-- mUI font (names were otherwise invisible), arrows/delete as 22 px icon boxes,
-- buttons/dropdowns/checkboxes flat. Clicks stay Blizzard's.
local function SquareIcon(button, iconName, rotation)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button)
    -- remove Blizzard's arrow texture entirely (otherwise it reappears when enabled)
    if button.icon then button.icon:SetTexture(nil) button.icon:SetAlpha(0) end
    button:SetSize(24, 24)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    Border(button)
    local icon = UI.Icon(button, iconName, 14, UI.TEXT)
    own[icon] = true
    icon:SetPoint("CENTER")
    if rotation then icon:SetRotation(rotation) end
    local function Reflect() icon:SetAlpha(button:IsEnabled() and 1 or 0.3) end
    button:HookScript("OnEnable", Reflect)
    button:HookScript("OnDisable", Reflect)
    button:HookScript("OnEnter", function(self) if self:IsEnabled() then bg:SetColorTexture(unpack(UI.HOVER)) end end)
    button:HookScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    Reflect()
end

-- Guild permission checkboxes: text 12, light
local function ControlCheck(check)
    if type(check) ~= "table" then return end
    SkinCheck(check)
    local label = check.text or (check.GetName and check:GetName() and _G[check:GetName() .. "Text"])
    if label then
        own[label] = true
        label:SetFont(ns.FontFor(), ns.FontPx(12), "")
        label:SetTextColor(unpack(ns.UI.TEXT))
    end
end

-- "Guild Ranks" page: rows 28 high on a 34 px grid, "Rank 1:" 56 wide right-aligned, name 150,
-- up/down 24 (4 gap), delete 14 next to them
local function SkinRankRows()
    local UI = ns.UI
    local order = _G.GuildControlUIRankOrderFrame
    if not order then return end
    for i = 1, MAX_GUILDRANKS or 10 do
        local row = _G["GuildControlUIRankOrderFrameRank" .. i]
        if row then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", order, "TOPLEFT", 0, -(i - 1) * 34)
            row:SetPoint("RIGHT", order, "RIGHT")
            row:SetHeight(28)
            local box = row.nameBox
            if box then
                SkinEditBox(box, { -6, -4, 2, 4 }, BOX)
                box:ClearAllPoints()
                box:SetPoint("LEFT", row, "LEFT", 70, 0)
                box:SetSize(146, 36)
                box:SetFont(ns.FontFor(), ns.FontPx(13), "")
                box:SetTextColor(1, 1, 1, 1)
                -- NEVER set the text ourselves: text written by addons is tainted and WoW then blocks
                -- GuildControlSetRank on rename.
                -- Blizzard sets the names while the frame has no width yet - the cursor at the end then
                -- scrolls the text out of the field. Move the cursor to the start (doesn't change the text).
                if not box:HasFocus() then box:SetCursorPosition(0) end
            end
            if row.rankLabel then
                row.rankLabel:ClearAllPoints()
                row.rankLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.rankLabel:SetWidth(56)
                row.rankLabel:SetJustifyH("RIGHT")
                row.rankLabel:SetFont(ns.FontFor(), ns.FontPx(12), "")
                row.rankLabel:SetTextColor(unpack(UI.ACCENT))
            end
            SquareIcon(row.upButton, "ChevronDown", math.pi)
            SquareIcon(row.downButton, "ChevronDown", 0)
            SquareIcon(row.deleteButton, "Phase")
            local x = 64 + 150 + 8
            for _, entry in ipairs({ { row.upButton, 0 }, { row.downButton, 28 }, { row.deleteButton, 28 + 24 + 14 } }) do
                if entry[1] then
                    entry[1]:ClearAllPoints()
                    entry[1]:SetPoint("LEFT", row, "LEFT", x + entry[2], 0)
                end
            end
        end
    end
    local new = order.newButton
    if new then
        new:ClearAllPoints()
        new:SetPoint("BOTTOMLEFT", order, "BOTTOMLEFT")
        new:SetSize(math.max(130, (new:GetFontString() and new:GetFontString():GetUnboundedStringWidth() or 0) + 28), 28)
    end
end

-- "Rank Permissions" page: authenticator on top, boxes officer / basic permissions / guild bank
local permBoxes = {}
local BASE_FLAGS, BANK_FLAGS = { 5, 6, 7, 8, 2, 21 }, { 15, 19, 16 }
local function LayoutPerms(page)
    if type(page) ~= "table" then return end
    local UI = ns.UI
    if not permBoxes.officer then
        for _, key in ipairs({ "OfficerBg", "RosterBg", "BankBg" }) do Fade(_G["GuildControlUIRankSettingsFrame" .. key]) end
        permBoxes.officer, permBoxes.base, permBoxes.bank = MakeBox(page), MakeBox(page), MakeBox(page)
        ControlCheck(page.OfficerCheckbox)
        ControlCheck(_G.GuildControlUIRankSettingsFrameCheckbox18)
        for _, id in ipairs(BASE_FLAGS) do ControlCheck(_G["GuildControlUIRankSettingsFrameCheckbox" .. id]) end
        for _, id in ipairs(BANK_FLAGS) do ControlCheck(_G["GuildControlUIRankSettingsFrameCheckbox" .. id]) end
        if page.goldBox then SkinEditBox(page.goldBox, nil, BOX) end
        local goldLabel = _G.parentLabel -- Blizzard really names the font like this
        if goldLabel then
            goldLabel:SetFont(ns.FontFor(), ns.FontPx(12), "")
            goldLabel:SetTextColor(unpack(UI.MUTED))
        end
        local bankLabel = _G.GuildControlUIRankSettingsFrameBankLabel
        if bankLabel then
            bankLabel:SetFont(ns.FontFor(), ns.FontPx(12), "")
            bankLabel:SetTextColor(unpack(UI.ACCENT))
        end
        if page.OfficerPermissions then
            page.OfficerPermissions:SetFont(ns.FontFor(), ns.FontPx(11), "")
            page.OfficerPermissions:SetTextColor(0.79, 0.78, 0.75)
            page.OfficerPermissions:SetSpacing(2)
        end
    end
    local auth = _G.GuildControlUIRankSettingsFrameCheckbox18
    if auth then
        auth:ClearAllPoints()
        auth:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    end
    local officer = permBoxes.officer
    officer:ClearAllPoints()
    officer:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    officer:SetPoint("RIGHT", page, "RIGHT")
    if page.OfficerCheckbox then
        page.OfficerCheckbox:ClearAllPoints()
        page.OfficerCheckbox:SetPoint("TOPLEFT", officer, "TOPLEFT", 10, -8)
    end
    local textHeight = 0
    if page.OfficerPermissions then
        page.OfficerPermissions:ClearAllPoints()
        page.OfficerPermissions:SetPoint("TOPLEFT", officer, "TOPLEFT", 32, -32)
        page.OfficerPermissions:SetPoint("RIGHT", officer, "RIGHT", -10, 0)
        textHeight = page.OfficerPermissions:GetStringHeight() or 0
    end
    officer:SetHeight(44 + textHeight)
    local base = permBoxes.base
    base:ClearAllPoints()
    base:SetPoint("TOPLEFT", officer, "BOTTOMLEFT", 0, -8)
    base:SetPoint("RIGHT", page, "RIGHT")
    base:SetHeight(84)
    for index, id in ipairs(BASE_FLAGS) do
        local check = _G["GuildControlUIRankSettingsFrameCheckbox" .. id]
        if check then
            local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", base, "TOPLEFT", 10 + column * 160, -10 - line * 24)
        end
    end
    local bank = permBoxes.bank
    bank:ClearAllPoints()
    bank:SetPoint("TOPLEFT", base, "BOTTOMLEFT", 0, -8)
    bank:SetPoint("RIGHT", page, "RIGHT")
    bank:SetHeight(86)
    local bankLabel = _G.GuildControlUIRankSettingsFrameBankLabel
    if bankLabel then
        bankLabel:ClearAllPoints()
        bankLabel:SetPoint("TOPLEFT", bank, "TOPLEFT", 10, -8)
    end
    local bankShown = bankLabel and bankLabel:IsShown()
    bank:SetShown(bankShown ~= false)
    for index, id in ipairs(BANK_FLAGS) do
        local check = _G["GuildControlUIRankSettingsFrameCheckbox" .. id]
        if check then
            local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
            check:ClearAllPoints()
            check:SetPoint("TOPLEFT", bank, "TOPLEFT", 10 + column * 160, -30 - line * 24)
        end
    end
    if page.goldBox then
        page.goldBox:ClearAllPoints()
        page.goldBox:SetPoint("TOPLEFT", bank, "TOPLEFT", 170, -52)
        page.goldBox:SetSize(70, 24)
    end
end

-- "Bank Permissions" and "Discord" pages: backgrounds, checkboxes, buttons and dropdowns flat
local function SkinChildren(frame, depth)
    if type(frame) ~= "table" or not frame.GetChildren or (depth or 0) > 5 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("CheckButton") then
            ControlCheck(child)
        elseif child:IsObjectType("EditBox") then
            SkinEditBox(child, nil, BOX)
        elseif child:IsObjectType("Button") and child.Left and child.Middle and child.Right then
            SkinButton(child)
        elseif child.SetupMenu and child.Background then
            SkinDropdown(child)
        end
        SkinChildren(child, (depth or 0) + 1)
    end
end

-- Overall structure: 380 x 600, title top left, "Options" + dropdown, on rank pages
-- "Change rank" + dropdown below, divider, content with 16 px margin
local function LayoutGuildControl(control)
    if type(control) ~= "table" then return end
    local tab = control.selectedTab or 1
    local withRank = tab == 2 or tab == 3
    control:SetSize(380, 600)
    local title = _G.GuildControlUITitle
    if title then
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", control, "TOPLEFT", 16, -18)
    end
    if control.optionsLabel then
        control.optionsLabel:ClearAllPoints()
        control.optionsLabel:SetPoint("LEFT", control, "TOPLEFT", 16, -66)
    end
    if control.dropdown then
        control.dropdown:ClearAllPoints()
        control.dropdown:SetPoint("TOPRIGHT", control, "TOPRIGHT", -16, -52)
        control.dropdown:SetSize(240, 28)
    end
    for _, key in ipairs({ "rankPermFrame", "bankTabFrame" }) do
        local page = control[key]
        local dropdown = page and page.dropdown
        if dropdown then
            dropdown:ClearAllPoints()
            dropdown:SetPoint("TOPRIGHT", control, "TOPRIGHT", -16, -88)
            dropdown:SetSize(240, 28)
        end
    end
    local hbar = _G.GuildControlUIHbar
    if hbar then
        hbar:ClearAllPoints()
        hbar:SetPoint("TOPLEFT", control, "TOPLEFT", 16, withRank and -124 or -88)
        hbar:SetPoint("TOPRIGHT", control, "TOPRIGHT", -16, withRank and -124 or -88)
        hbar:SetHeight(1)
    end
    for _, key in ipairs({ "orderFrame", "rankPermFrame", "bankTabFrame", "discordFrame" }) do
        local page = control[key]
        if page then
            page:ClearAllPoints()
            page:SetPoint("TOPLEFT", control, "TOPLEFT", 16, withRank and -132 or -96)
            page:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", -16, 16)
        end
    end
    local bank = control.bankTabFrame
    if bank and bank.inset then
        bank.inset:ClearAllPoints()
        bank.inset:SetPoint("TOPLEFT", bank, "TOPLEFT")
        bank.inset:SetPoint("BOTTOMRIGHT", bank, "BOTTOMRIGHT")
    end
    SkinRankRows()
    if tab == 2 then LayoutPerms(control.rankPermFrame) end
    if tab == 3 or tab == 4 then SkinChildren(control[tab == 3 and "bankTabFrame" or "discordFrame"]) end
end

local function SkinGuildControl(control)
    if type(control) ~= "table" or not Once(control) then return end
    local UI = ns.UI
    Fade(control.NineSlice)
    FadeRegions(control)
    Panel(control)
    SkinIconButton(control.CloseButton, "Close", 18)
    if control.CloseButton then
        control.CloseButton:SetSize(34, 34)
        control.CloseButton:ClearAllPoints()
        control.CloseButton:SetPoint("TOPRIGHT", control, "TOPRIGHT", -10, -10)
    end
    local title = _G.GuildControlUITitle
    if title then
        own[title] = true
        title:SetFont(ns.FontFor("bold"), ns.FontPx(15), "")
        title:SetTextColor(unpack(UI.TEXT))
    end
    -- "Options" before the dropdown
    local optionsLabel = control:CreateFontString(nil, "OVERLAY")
    optionsLabel:SetFont(ns.FontFor(), ns.FontPx(12), "")
    optionsLabel:SetTextColor(unpack(UI.ACCENT))
    optionsLabel:SetText(GUILDCONTROL or "Options")
    control.optionsLabel = nil
    permBoxes.optionsLabel = optionsLabel
    local hbar = _G.GuildControlUIHbar
    if hbar then
        FadeRegions(hbar)
        local line = Tex(hbar, "ARTWORK", 0, { 1, 1, 1, 0.08 })
        line:SetAllPoints()
    end
    SkinDropdown(control.dropdown)
    for _, key in ipairs({ "orderFrame", "bankTabFrame", "rankPermFrame", "discordFrame" }) do
        local frame = control[key]
        if type(frame) == "table" then
            SkinDropdown(frame.dropdown)
            SkinButton(frame.newButton)
            SkinButton(frame.dupButton)
            -- Label of the rank dropdown ("Change rank:") in Surf Green
            local dropdown = frame.dropdown
            if dropdown and dropdown.GetRegions then
                for _, region in ipairs({ dropdown:GetRegions() }) do
                    if region:IsObjectType("FontString") and region ~= dropdown.Text then
                        region:SetFont(ns.FontFor(), ns.FontPx(12), "")
                        region:SetTextColor(unpack(UI.ACCENT))
                    end
                end
            end
        end
    end
    local bank = control.bankTabFrame
    if bank and bank.inset then
        SkinInset(bank.inset, true, BOX)
        if bank.inset.scrollFrame then SkinScrollBar(bank.inset.scrollFrame.ScrollBar) end
    end
    local function Relayout()
        LayoutGuildControl(control)
        if permBoxes.optionsLabel then
            permBoxes.optionsLabel:ClearAllPoints()
            permBoxes.optionsLabel:SetPoint("LEFT", control, "TOPLEFT", 16, -66)
        end
    end
    if GuildControlUI_SetupSelected then hooksecurefunc("GuildControlUI_SetupSelected", Relayout) end
    if GuildControlUI_RankOrder_Update then hooksecurefunc("GuildControlUI_RankOrder_Update", SkinRankRows) end
    if GuildControlUI_RankPermissions_Update then
        hooksecurefunc("GuildControlUI_RankPermissions_Update", function(page) LayoutPerms(page) end)
    end
    if GuildControlUI_BankTabPermissions_Update then
        hooksecurefunc("GuildControlUI_BankTabPermissions_Update", function(page) SkinChildren(page) end)
    end
    control:HookScript("OnShow", function()
        Relayout()
        C_Timer.After(0.05, SkinRankRows) -- after placing: scroll names to the start of the field
    end)
    -- Page switching via the dropdown goes through an internal Blizzard function: re-arrange
    -- when pages are shown (rank dropdown above the divider, content below)
    for _, key in ipairs({ "orderFrame", "rankPermFrame", "bankTabFrame", "discordFrame" }) do
        local page = control[key]
        if page then page:HookScript("OnShow", function() C_Timer.After(0, Relayout) end) end
    end
    Relayout()
end

-- Guild sub-windows (ranks, log, edit text, news filter, recruitment): Blizzard registers them
-- all as "left" panels, which pushed our guild frame to the top right. Take them all out of
-- panel management and open them to the right via our own arrangement.
local SUBPANELS = { "GuildControlUI", "CommunitiesGuildLogFrame", "CommunitiesGuildTextEditFrame",
    "CommunitiesGuildNewsFiltersFrame", "ClubFinderGuildRecruitmentDialog" }
local adopted = {}
local function AdoptSubpanels()
    if not Enabled() then return end
    for _, name in ipairs(SUBPANELS) do
        local panel = _G[name]
        if type(panel) == "table" and not adopted[name] then
            adopted[name] = true
            local function Unmanage()
                if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
                if SetUIPanelAttribute then SetUIPanelAttribute(panel, "area", nil) end
                local listed = false
                for _, special in ipairs(UISpecialFrames) do if special == name then listed = true end end
                if not listed then tinsert(UISpecialFrames, name) end
            end
            Unmanage()
            if name == "GuildControlUI" then SkinGuildControl(panel) end
            panel:HookScript("OnShow", function(self)
                C_Timer.After(0, function()
                    if self:IsShown() and ns.ResetWindowPosition then
                        ns.ResetWindowPosition(self, "guildsub", not InCombatLockdown())
                    end
                end)
            end)
        end
    end
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_Communities" then Apply() end
    if name == "Blizzard_GuildControlUI" or name == "Blizzard_Communities" then AdoptSubpanels() end
end)

ns:On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Communities") then Apply() end
    AdoptSubpanels()
end)
