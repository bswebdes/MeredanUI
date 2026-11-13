-- Group finder (LFGParentFrame from Blizzard_GroupFinder_VanillaStyle, WoW Forever) in mUI style.
-- Blizzard's frames stay fully functional (listing, search, invite and /who are Blizzard's code);
-- we only restyle and re-place them:
--
--   +-[eye] Group Finder --------------------------------------- [x]-+  [List]
--   |       Browse Groups                                            |  [Browse]
--   | [Category v] [Activity           v] [R]                   [o]  |  [Who]
--   | +--------------------------------------------------------------+ |
--   | | rows (flat)                                                  | |
--   | +--------------------------------------------------------------+ |
--   | [Send Message]                                  [Invite]       |
--   +-----------------------------------------------------------------+
--
-- The three pages (LFGListingFrame, LFGBrowseFrame, LFGWhoListFrame) fill the parent in Blizzard's
-- layout; we inset them below our header, so their own internal offsets keep working.
-- Rules as in Skins/Communities.lua: art only via SetAlpha(0) or recolor, no SetScript, no fields on
-- Blizzard tables, no ScrollBox view changes, no SetText on Blizzard edit boxes.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = ns.BORDER_COLOR -- edge colour; bronze in the rune look (name kept)
local INPUT = { 0.04, 0.04, 0.05, 1 }
local BOX = { 0, 0, 0, 0.25 }
local PAD, ICON = 18, 46
local WIDTH = 482                  -- pages keep Blizzard's 458 px width (12 px inset per side)
local SIDE = 12                    -- page inset left/right
local TOOLBAR_TOP = PAD + ICON + 14 -- 78
local FOOTER = 14                  -- page bottom; Blizzard's lists end 40 px above it (= 54)
local LIST_TOP = TOOLBAR_TOP + 28 + 12 -- 118: list area below the toolbar
local TAB_SIZE, TAB_STEP = 40, 46

-- Page tops: Listing keeps its role row below the header; Browse is pulled up so its list
-- (Blizzard: 112 px below the page top) starts at LIST_TOP.
local LISTING_TOP = 48
local BROWSE_TOP = LIST_TOP - 112
local WHO_TOP = 48

-- Category icons for the listing's category cards (Blizzard's category IDs, LFGVanilla_Constants)
local CATEGORY_ICONS = { [2] = "Entrance", [114] = "Combat", [116] = "Quest", [118] = "PvP", [120] = "Star" }

local skinned = setmetatable({}, { __mode = "k" })
local own = setmetatable({}, { __mode = "k" })
local partOf = setmetatable({}, { __mode = "k" }) -- Blizzard object -> our extra regions
local frame, subtitle, holder
local fonts
local applied = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.groupFinderSkin ~= false
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
    ns.RuneFrame(target)
end

-- Dark content box with border on page (list areas)
local function ContentBox(page, left, top, right, bottom)
    local bg = Tex(page, "BACKGROUND", -7, BOX)
    bg:SetPoint("TOPLEFT", left, -top)
    bg:SetPoint("BOTTOMRIGHT", -right, bottom)
    Edges(page, bg)
    return bg
end

local function Fonts()
    if fonts then return fonts end
    local UI = ns.UI
    local function Make(name, base, color)
        local font = CreateFont(name)
        font:CopyFontObject(base)
        font:SetTextColor(color[1], color[2], color[3])
        return font
    end
    fonts = {
        normal = Make("MeredanUIGroupFinderButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIGroupFinderButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUIGroupFinderButtonDisabled", GameFontDisable, UI.MUTED),
        category = Make("MeredanUIGroupFinderCategory", GameFontHighlightLarge or GameFontHighlight, UI.TEXT),
        categoryHover = Make("MeredanUIGroupFinderCategoryHover", GameFontHighlightLarge or GameFontHighlight, UI.ACCENT),
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

-- flat button (UIPanelButtonTemplate)
local function SkinButton(button)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(button[key]) end
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

-- Icon button: flat box, our icon (or Blizzard's kept icon), Surf Green on hover
local function SkinIconButton(button, iconName, iconSize, keepIcon)
    if type(button) ~= "table" or not button.IsObjectType or not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button, keepIcon and { [keepIcon] = true } or nil)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = keepIcon
    if not icon then
        icon = UI.Icon(button, iconName, iconSize or 14)
        own[icon] = true
        icon:SetPoint("CENTER", bg)
    end
    local function Reflect()
        icon:SetAlpha(button:IsEnabled() and 1 or 0.35)
    end
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() then
            if keepIcon then bg:SetColorTexture(unpack(UI.HOVER)) else icon:SetVertexColor(unpack(UI.ACCENT)) end
        end
    end)
    button:HookScript("OnLeave", function()
        if keepIcon then bg:SetColorTexture(unpack(UI.FIELD)) else icon:SetVertexColor(unpack(UI.TEXT)) end
    end)
    if button.IsEnabled then
        button:HookScript("OnEnable", Reflect)
        button:HookScript("OnDisable", Reflect)
        Reflect()
    end
end

-- Dropdown (WowStyle1DropdownTemplate / FilterDropdown): flat field, our arrow
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
    local function Reflect() arrow:SetAlpha(dropdown:IsEnabled() and 1 or 0.35) end
    dropdown:HookScript("OnEnter", function(self)
        if self:IsEnabled() then arrow:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    dropdown:HookScript("OnLeave", function() arrow:SetVertexColor(unpack(UI.MUTED)) end)
    dropdown:HookScript("OnEnable", Reflect)
    dropdown:HookScript("OnDisable", Reflect)
    Reflect()
end

-- Checkbox: dark box, Surf Green check (state from GetChecked)
local function CheckBox(check, size)
    local UI = ns.UI
    local box = CreateFrame("Frame", nil, check)
    box:SetSize(size or 16, size or 16)
    box:SetPoint("CENTER")
    UI.CheckBg(box)
    local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
    tick:SetPoint("CENTER")
    local partial = UI.Icon(box, "Minus", 10, UI.ACCENT)
    partial:SetPoint("CENTER")
    partial:Hide()
    local hover = box:CreateTexture(nil, "ARTWORK")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    hover:Hide()
    check:HookScript("OnEnter", function() hover:Show() end)
    check:HookScript("OnLeave", function() hover:Hide() end)
    return { box = box, tick = tick, partial = partial, hover = hover }
end

local function SkinCheck(check)
    if type(check) ~= "table" or not check.IsObjectType or not check:IsObjectType("CheckButton") then return end
    if not Once(check) then return end
    local UI = ns.UI
    FadeButtonTextures(check)
    local parts = CheckBox(check)
    local function Update()
        parts.tick:SetShown(check:GetChecked() and true or false)
        parts.tick:SetVertexColor(unpack(check:IsEnabled() and UI.ACCENT or UI.MUTED))
    end
    check:HookScript("OnClick", Update)
    check:HookScript("OnShow", Update)
    check:HookScript("OnEnable", Update)
    check:HookScript("OnDisable", Update)
    hooksecurefunc(check, "SetChecked", Update)
    Update()
    return parts
end

-- Search box (SearchBoxTemplate): dark field, Surf Green border on focus
local function SkinEditBox(box)
    if type(box) ~= "table" or not box.IsObjectType or not box:IsObjectType("EditBox") or not Once(box) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do Fade(box[key]) end
    local bg = Tex(box, "BACKGROUND", -8, INPUT)
    bg:SetPoint("TOPLEFT", -6, 4)
    bg:SetPoint("BOTTOMRIGHT", 2, -4)
    local IDLE = UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 }
    local edges = Edges(box, bg, IDLE)
    box:HookScript("OnEditFocusGained", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    box:HookScript("OnEditFocusLost", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1) end
    end)
end

-- Multi-line edit box (UIPanelInputScrollFrameTemplate): border art removed, dark field
local function SkinInputScroll(scroll)
    if type(scroll) ~= "table" or not scroll.GetRegions or not Once(scroll) then return end
    FadeRegions(scroll)
    local bg = Tex(scroll, "BACKGROUND", -8, INPUT)
    bg:SetPoint("TOPLEFT", -5, 5)
    bg:SetPoint("BOTTOMRIGHT", 5, -5)
    Edges(scroll, bg, ns.UI.CHECK_EDGE)
end

-- Scrollbar (MinimalScrollBar): chevron arrows, thin track, Surf Green thumb
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
            local function Reflect() icon:SetAlpha(stepper:IsEnabled() and 1 or 0.3) end
            stepper:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
            stepper:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.MUTED)) end)
            stepper:HookScript("OnEnable", Reflect)
            stepper:HookScript("OnDisable", Reflect)
            Reflect()
        end
    end
end

-- ScrollBox rows: after each update skin all visible rows (new and recycled) once
local function HookScrollBox(box, fn)
    if type(box) ~= "table" or not box.ForEachFrame or not Once(box) then return end
    local function Each() if not box.GetView or box:GetView() then box:ForEachFrame(fn) end end -- no view until Blizzard fills the list
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
end

-- Row backgrounds: Blizzard's atlases recolored flat (Blizzard only shows/hides these later)
local function FlatRowTextures(row, bg, highlight, selected)
    local UI = ns.UI
    if IsTexture(bg) then bg:SetColorTexture(UI.FIELD[1], UI.FIELD[2], UI.FIELD[3], 0.9) end
    if IsTexture(highlight) then
        highlight:SetColorTexture(1, 1, 1, 0.05)
        highlight:SetBlendMode("BLEND")
    end
    if IsTexture(selected) then
        selected:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.16)
        selected:SetBlendMode("BLEND")
        -- Surf Green stripe on the left while selected
        local stripe = row:CreateTexture(nil, "OVERLAY", nil, 7)
        stripe:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 1)
        stripe:SetPoint("TOPLEFT", selected, "TOPLEFT")
        stripe:SetPoint("BOTTOMLEFT", selected, "BOTTOMLEFT")
        stripe:SetWidth(2)
        own[stripe] = true
        stripe:SetShown(selected:IsShown())
        hooksecurefunc(selected, "Show", function() stripe:Show() end)
        hooksecurefunc(selected, "Hide", function() stripe:Hide() end)
        hooksecurefunc(selected, "SetShown", function(_, shown) stripe:SetShown(shown and true or false) end)
    end
end

-- Header ------------------------------------------------------------------------------------------

local function PageTitle()
    local tab = frame.selectedTab or 1
    if tab == 2 then return LFG_LIST_TAB_2 end
    if tab == 3 then return LFG_LIST_TAB_3 end
    return C_LFGList.HasActiveEntryInfo() and LFG_LIST_EDIT or LFG_LIST_TAB_1
end

local function UpdateHeader()
    if subtitle then subtitle:SetText(PageTitle() or "") end
end

-- Side tabs (Listing / Browse / Who): like mUI window tabs. Blizzard's icon is masked and resized on
-- every SetChecked, so we draw our own copy and hide theirs.
local tabIcons = setmetatable({}, { __mode = "k" })
local function SkinSideTab(tab)
    if type(tab) ~= "table" or not tab.Icon or not Once(tab) then return end
    local UI = ns.UI
    FadeRegions(tab)
    Fade(tab.Icon)
    local bg = Tex(tab, "BACKGROUND", -8, ns.STYLE.panelColor)
    bg:SetAllPoints()
    Border(tab)
    local icon = tab:CreateTexture(nil, "ARTWORK", nil, 2)
    own[icon] = true
    icon:SetTexture(tab.iconTexture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetSnapToPixelGrid(false)
    icon:SetTexelSnappingBias(0)
    tabIcons[tab] = icon
    local hover = Tex(tab, "HIGHLIGHT", 0, { 1, 1, 1, 0.08 })
    hover:SetAllPoints()
    local active = Border(tab, true, 2)
    for _, edge in ipairs(active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    local function Update(_, checked)
        local on = checked and true or false
        for _, edge in ipairs(active) do edge:SetShown(on) end
        icon:SetDesaturated(not on)
        Fade(tab.Icon)
        Fade(tab.SelectedTexture)
    end
    hooksecurefunc(tab, "SetChecked", Update)
    Update(nil, tab:GetID() == (frame.selectedTab or 1))
end

local TAB_KEYS = { "ListingTab", "BrowsingTab", "WhoListingTab" }
local function LayoutTabs()
    for i, key in ipairs(TAB_KEYS) do
        local tab = frame[key]
        if type(tab) == "table" then
            tab:SetSize(TAB_SIZE, TAB_SIZE)
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", ns.SideTabX(), -60 - (i - 1) * TAB_STEP)
        end
    end
end

-- Pages ---------------------------------------------------------------------------------------------

-- Shared page shell: PortraitFrameTemplate art, title and portrait hidden
local function SkinPage(page)
    if type(page) ~= "table" or not Once(page) then return end
    FadeRegions(page)
    Fade(page.NineSlice)
    Fade(page.Bg)
    Fade(page.TitleContainer)
    Fade(page.PortraitContainer)
    Fade(page.TopTileStreaks)
end

-- Listing activity row: flat check (with partial state), our plus/minus
local RefreshAfterClick
local function SkinActivityRow(row)
    if type(row) ~= "table" or not row.CheckButton or not Once(row) then return end
    local UI = ns.UI
    local check = row.CheckButton
    FadeButtonTextures(check)
    partOf[row] = { check = CheckBox(check) }
    check:HookScript("OnMouseUp", function() RefreshAfterClick(row) end)
    if row.NameButton then row.NameButton:HookScript("OnClick", function() RefreshAfterClick(row) end) end
    local toggle = row.ExpandOrCollapseButton
    if toggle then
        FadeButtonTextures(toggle)
        local sign = UI.Icon(toggle, "Minus", 10, UI.MUTED)
        own[sign] = true
        sign:SetPoint("CENTER", 2, 0)
        partOf[row].sign = sign
        toggle:HookScript("OnEnter", function() sign:SetVertexColor(unpack(UI.ACCENT)) end)
        toggle:HookScript("OnLeave", function() sign:SetVertexColor(unpack(UI.MUTED)) end)
    end
end

local UpdateActivityRow

-- Group row (activity group header) or single activity, from the row's tree node
local function RowState(row)
    local node = row.GetElementData and row:GetElementData()
    local data = node and node.GetData and node:GetData()
    if type(data) ~= "table" then return false, false end
    if data.activityID == nil and data.activityGroupID and LFGListingFrame then
        return true, not LFGListingFrame:AreAllActivitiesForActivityGroupSelected(data.activityGroupID)
    end
    return false, false
end

-- A click toggles the check natively; Blizzard re-inits only the group row. Their OnClick script is
-- replaced on every init (SetScript), so we listen to OnMouseUp / the name button instead.
function RefreshAfterClick(row)
    C_Timer.After(0, function()
        local _, partial = RowState(row)
        UpdateActivityRow(row, partial, nil)
    end)
end

function UpdateActivityRow(row, partial, collapsed)
    SkinActivityRow(row)
    local parts = partOf[row]
    if not parts then return end
    local UI = ns.UI
    local check = row.CheckButton
    -- Blizzard re-sets these textures on every init
    FadeButtonTextures(check)
    local checked = check:GetChecked() and true or false
    parts.check.tick:SetShown(checked and not partial)
    parts.check.partial:SetShown(checked and partial and true or false)
    local color = check:IsEnabled() and UI.ACCENT or UI.MUTED
    parts.check.tick:SetVertexColor(unpack(color))
    parts.check.partial:SetVertexColor(unpack(color))
    if parts.sign and row.ExpandOrCollapseButton then
        FadeButtonTextures(row.ExpandOrCollapseButton)
        if collapsed ~= nil then
            ns.SetIcon(parts.sign, (collapsed and "Plus" or "Minus"))
        end
    end
end

-- Category card (Dungeons, Raids, Quests ...): flat card, mUI icon on the left
local function SkinCategoryButton(button)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    Fade(button.Icon)
    Fade(button.Cover)
    FadeButtonTextures(button)
    local bg = Tex(button, "BACKGROUND", -6, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = UI.Icon(button, "Quest", 22, UI.ACCENT)
    own[icon] = true
    icon:SetPoint("LEFT", bg, "LEFT", 14, 0)
    partOf[button] = { icon = icon }
    local label = button.Label or button:GetFontString()
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", icon, "RIGHT", 12, 0)
        local f = Fonts()
        button:SetNormalFontObject(f.category)
        button:SetHighlightFontObject(f.categoryHover)
    end
    button:HookScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
    button:HookScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
end

local function UpdateCategoryButtons(view)
    for _, button in ipairs(view and view.CategoryButtons or {}) do
        SkinCategoryButton(button)
        local parts = partOf[button]
        if parts then
            Fade(button.Icon)
            ns.SetIcon(parts.icon, (CATEGORY_ICONS[button.categoryID] or "Quest"))
        end
    end
end

local function SkinRoleButton(button)
    if type(button) ~= "table" or not Once(button) then return end
    Fade(button.Background)
    if button.CheckButton then SkinCheck(button.CheckButton) end
end

local function SkinListing(page)
    SkinPage(page)
    FadeRegions(page.RolesSection)
    if page.Inset then
        FadeRegions(page.Inset)
        Fade(page.Inset.Bg)
        Fade(page.Inset.NineSlice)
    end
    if page.DividerFrame then FadeRegions(page.DividerFrame) end
    ContentBox(page, 6, 120, 6, 36)

    for _, button in ipairs(page.SoloRoleButtons and page.SoloRoleButtons.RoleButtons or {}) do SkinRoleButton(button) end
    local group = page.GroupRoleButtons
    if group then
        if group.RoleIcon then Fade(group.RoleIcon.Background) end
        SkinButton(group.RolePollButton)
        SkinDropdown(group.RoleDropdown)
    end
    local newbie = page.NewPlayerFriendlyButton
    if newbie and newbie.CheckButton then SkinCheck(newbie.CheckButton) end

    SkinButton(page.BackButton)
    SkinButton(page.PostButton)

    UpdateCategoryButtons(page.CategoryView)
    hooksecurefunc("LFGListingCategorySelection_UpdateCategoryButtons", UpdateCategoryButtons)

    local view = page.ActivityView
    if view then
        Fade(view.BarTop)
        Fade(view.BarMiddle)
        SkinDropdown(view.PlayStyleDropdown)
        SkinDropdown(view.VoiceChatDropdown)
        if view.LevelRangesCheckbox then SkinCheck(view.LevelRangesCheckbox.Checkbox) end
        SkinScrollBar(view.ScrollBar)
        HookScrollBox(view.ScrollBox, SkinActivityRow)
        if view.Comment then
            SkinInputScroll(view.Comment)
            SkinScrollBar(view.Comment.ScrollBar)
        end
    end
    hooksecurefunc("LFGListingActivityView_InitActivityGroupButton", function(row, data, collapsed)
        local partial = data and data.activityGroupID and LFGListingFrame
            and not LFGListingFrame:AreAllActivitiesForActivityGroupSelected(data.activityGroupID)
        UpdateActivityRow(row, partial, collapsed and true or false)
    end)
    hooksecurefunc("LFGListingActivityView_InitActivityButton", function(row) UpdateActivityRow(row, false, nil) end)
end

-- Browse result rows (solo, group, nested) and the "Groups"/"Solo players" headers
local function SkinBrowseRow(row)
    if type(row) ~= "table" or not Once(row) then return end
    local UI = ns.UI
    if row.CategoryLabel then
        -- header row: faint band, our plus/minus
        if IsTexture(row.ResultBG) then row.ResultBG:SetColorTexture(1, 1, 1, 0.04) end
        if IsTexture(row.Highlight) then
            row.Highlight:SetColorTexture(1, 1, 1, 0.04)
            row.Highlight:SetBlendMode("BLEND")
        end
        for key, name in pairs({ ExpandIcon = "Plus", CollapseIcon = "Minus" }) do
            local tex = row[key]
            if IsTexture(tex) then
                ns.SetIcon(tex, name)
                tex:SetSize(10, 10)
                tex:SetVertexColor(unpack(UI.MUTED))
            end
        end
        row.CategoryLabel:SetTextColor(unpack(UI.ACCENT))
        return
    end
    FlatRowTextures(row, row.ResultBG, row.Highlight, row.Selected)
    local delist = row.DataDisplay and row.DataDisplay.DelistButton
    if delist then FadeRegions(delist, { [delist.Icon] = true }) FadeButtonTextures(delist) end
end

local function SkinBrowse(page)
    SkinPage(page)
    Fade(page.BackgroundArt)
    Fade(page.Bg)
    Fade(page.BarTop)
    Fade(page.BarMiddle)
    if page.Inset then FadeRegions(page.Inset) end
    ContentBox(page, 6, LIST_TOP - BROWSE_TOP - 6, 6, 36)
    SkinDropdown(page.CategoryDropdown)
    SkinDropdown(page.ActivityDropdown)
    if page.ActivityDropdown and page.ActivityDropdown.ResetButton then
        page.ActivityDropdown.ResetButton:SetFrameLevel(page.ActivityDropdown:GetFrameLevel() + 3)
    end
    -- Blizzard's icons removed for good (the options button resets their alpha on hover)
    if page.RefreshButton and IsTexture(page.RefreshButton.Icon) then page.RefreshButton.Icon:SetTexture(nil) end
    if page.OptionsButton and IsTexture(page.OptionsButton.Icon) then page.OptionsButton.Icon:SetTexture(nil) end
    SkinIconButton(page.RefreshButton, "Reset", 14)
    SkinIconButton(page.OptionsButton, "Settings", 14)
    SkinButton(page.SendMessageButton)
    SkinButton(page.GroupInviteButton)
    SkinScrollBar(page.ScrollBar)
    HookScrollBox(page.ScrollBox, SkinBrowseRow)
    if page.SearchingSpinner and page.SearchingSpinner.Label then
        page.SearchingSpinner.Label:SetTextColor(unpack(ns.UI.MUTED))
    end
end

-- Who list row: flat card, invite as icon box
local function SkinWhoRow(row)
    if type(row) ~= "table" or not Once(row) then return end
    FlatRowTextures(row, row.Background, row.GetHighlightTexture and row:GetHighlightTexture(), row.Selected)
    local invite = row.InviteButton
    if invite then SkinIconButton(invite, nil, nil, invite.Icon) end
end

local function SkinWho(page)
    SkinPage(page)
    Fade(page.BackgroundArt)
    Fade(page.headerBackground)
    Fade(page.insideFrame)
    Fade(page.BarTop)
    Fade(page.BarMiddle)
    local box = Tex(page, "BACKGROUND", -7, BOX)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -LIST_TOP)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 50)
    Edges(page, box)
    SkinEditBox(page.EditBox)
    if page.WhoSearch then SkinIconButton(page.WhoSearch, nil, nil, page.WhoSearch.Icon) end
    SkinDropdown(page.FilterDropdown)
    SkinScrollBar(page.ScrollBar)
    HookScrollBox(page.ScrollBox, SkinWhoRow)
end

-- Layout ----------------------------------------------------------------------------------------------

local function PlacePage(page, top)
    if type(page) ~= "table" then return end
    page:ClearAllPoints()
    page:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE, -top)
    page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -SIDE, FOOTER)
end

local function PlaceFooter(left, right)
    if left then
        left:ClearAllPoints()
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 14)
        left:SetSize(150, 28)
    end
    if right then
        right:ClearAllPoints()
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 14)
        right:SetSize(150, 28)
    end
end

local function Place()
    local f = frame
    f:SetSize(WIDTH, ns.NPC_HEIGHT)
    f:SetHitRectInsets(0, 0, 0, 0)

    local listing, browse, who = _G.LFGListingFrame, _G.LFGBrowseFrame, _G.LFGWhoListFrame
    PlacePage(listing, LISTING_TOP)
    PlacePage(browse, BROWSE_TOP)
    PlacePage(who, WHO_TOP)

    if listing then
        PlaceFooter(listing.BackButton, listing.PostButton)
        -- no portrait inside the page any more: role buttons move left
        if listing.SoloRoleButtons then
            listing.SoloRoleButtons:ClearAllPoints()
            listing.SoloRoleButtons:SetPoint("TOPLEFT", 40, -41)
        end
        if listing.GroupRoleButtons then
            listing.GroupRoleButtons:ClearAllPoints()
            listing.GroupRoleButtons:SetPoint("TOPLEFT", 75, -41)
        end
    end

    if browse then
        PlaceFooter(browse.SendMessageButton, browse.GroupInviteButton)
        local y = -(TOOLBAR_TOP - BROWSE_TOP)
        local category, activity = browse.CategoryDropdown, browse.ActivityDropdown
        if category then
            category:ClearAllPoints()
            category:SetPoint("TOPLEFT", browse, "TOPLEFT", PAD - SIDE, y)
            category:SetSize(150, 28)
        end
        if activity then
            activity:ClearAllPoints()
            activity:SetPoint("LEFT", category or browse, category and "RIGHT" or "LEFT", 6, 0)
            activity:SetSize(190, 28)
        end
        if browse.RefreshButton then
            browse.RefreshButton:ClearAllPoints()
            browse.RefreshButton:SetPoint("LEFT", activity or browse, activity and "RIGHT" or "LEFT", 2, 0)
            browse.RefreshButton:SetSize(36, 36)
        end
        if browse.OptionsButton then
            browse.OptionsButton:ClearAllPoints()
            browse.OptionsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD - 4), -(TOOLBAR_TOP - 4))
            browse.OptionsButton:SetSize(36, 36)
        end
        -- spinner and "no results" are anchored to this (hidden) texture: make it the list area
        if browse.BackgroundArt then
            browse.BackgroundArt:ClearAllPoints()
            browse.BackgroundArt:SetPoint("TOPLEFT", browse, "TOPLEFT", 0, -(LIST_TOP - BROWSE_TOP))
            browse.BackgroundArt:SetPoint("BOTTOMRIGHT", browse, "BOTTOMRIGHT", 0, 40)
        end
    end

    if who then
        local edit = who.EditBox
        if edit then
            edit:ClearAllPoints()
            edit:SetPoint("LEFT", frame, "TOPLEFT", PAD + 8, -(TOOLBAR_TOP + 14))
            edit:SetWidth(240)
        end
        if who.WhoSearch then
            who.WhoSearch:ClearAllPoints()
            who.WhoSearch:SetPoint("LEFT", edit or who, edit and "RIGHT" or "LEFT", 4, 0)
            who.WhoSearch:SetSize(36, 36)
        end
        if who.FilterDropdown then
            who.FilterDropdown:ClearAllPoints()
            who.FilterDropdown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -TOOLBAR_TOP)
            who.FilterDropdown:SetHeight(28)
        end
        if who.ScrollBox then
            who.ScrollBox:ClearAllPoints()
            who.ScrollBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, -(LIST_TOP + 4))
            who.ScrollBox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + 18), 54)
        end
        if who.WhoFrameTotals then
            who.WhoFrameTotals:ClearAllPoints()
            who.WhoFrameTotals:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
            who.WhoFrameTotals:SetHeight(28)
        end
    end

    LayoutTabs()
end

local function Reposition(opening)
    if frame:IsShown() and ns.ResetWindowPosition then
        ns.ResetWindowPosition(frame, "groupfinder", opening and not InCombatLockdown())
    end
end

local function SkinShell(f)
    local UI = ns.UI
    FadeRegions(f)
    Panel(f)

    -- Header like mUI windows; Blizzard's LFG eye (shows/opens your listing status) is the icon
    holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    local eye = _G.LFGParentFramePortrait
    if eye then
        eye:ClearAllPoints()
        eye:SetPoint("CENTER", holder, "CENTER")
        eye:SetScale(ICON / 64)
    end
    local title = UI.Text(holder, 16, "LEFT")
    ns.SetFont(title, 16, "", "bold")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    title:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
    title:SetText(LFG_TITLE or "")
    subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetPoint("RIGHT", title, "RIGHT")
    subtitle:SetWordWrap(false)

    -- Drag by the header; above the pages (Browse reaches up into the header band)
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -PAD - 36, 0)
    header:SetHeight(PAD + ICON + 6)
    header:SetFrameLevel(f:GetFrameLevel() + 30)
    ns.MakeWindowDraggable(f, header)

    local close = _G.LFGParentFrameCloseButton
    if close then
        SkinIconButton(close, "Close", 18)
        close:SetSize(34, 34)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -(PAD - 4), -(PAD - 4))
        close:SetFrameLevel(f:GetFrameLevel() + 30)
    end

    for _, key in ipairs(TAB_KEYS) do SkinSideTab(f[key]) end
end

local function Unmanage()
    if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
    if SetUIPanelAttribute then SetUIPanelAttribute(frame, "area", nil) end
    for _, name in ipairs(UISpecialFrames) do
        if name == "LFGParentFrame" then return end
    end
    tinsert(UISpecialFrames, "LFGParentFrame") -- Esc still closes
end

local function Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local function Apply()
    if applied or not Enabled() or type(_G.LFGParentFrame) ~= "table" then return end
    applied = true
    frame = _G.LFGParentFrame
    Try(SkinShell, frame)
    Try(SkinListing, _G.LFGListingFrame)
    Try(SkinBrowse, _G.LFGBrowseFrame)
    Try(SkinWho, _G.LFGWhoListFrame)
    Unmanage()
    Try(Place)

    -- Side tabs hang on the outer right: neighboring windows move behind them
    if ns.EXTRA_RIGHT then ns.EXTRA_RIGHT[frame] = 6 + TAB_SIZE end

    if frame.UpdateTabs then hooksecurefunc(frame, "UpdateTabs", UpdateHeader) end
    frame:HookScript("OnShow", function()
        Place()
        UpdateHeader()
        C_Timer.After(0, function() Reposition(true) end)
    end)
    -- Listing's OnShow re-anchors Blizzard's (hidden) bottom tabs only; nothing of ours, but the
    -- activity view re-anchors its comment box per category - our box follows it automatically.
    UpdateHeader()
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_GroupFinder_VanillaStyle" then Apply() end
end)

ns:On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder_VanillaStyle") then Apply() end
end)
