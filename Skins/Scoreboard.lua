-- Battleground scoreboard (PVPMatchScoreboard) and match results (PVPMatchResults), Blizzard_PVPMatch
-- Camelot variant, in mUI style. Both stay Blizzard UI panels (area "center", placed by Blizzard):
-- no mUI window spot, no dragging. We only restyle and re-arrange the inside:
--
--   +-[i] Warsong Gulch / Alliance Wins ------------------------------------------ [x]-+
--   |     12 min / Warsong Gulch                                                       |
--   | [All] [Alliance (10)] [Horde (10)]                                               |
--   | +------------------------------------------------------------------------------+ |
--   | | Name                 KB   HK   Deaths   Damage   Healing   ...    (headers)   | |
--   | | rows, flat faction tint                                                       | |
--   | +------------------------------------------------------------------------------+ |
--   |                                                         [Leave Battleground 1m] |  <- results only
--   +----------------------------------------------------------------------------------+
--
-- Rules as in Skins/Macros.lua: art only via SetAlpha(0) or recolor, no SetScript on Blizzard
-- frames, no fields on Blizzard tables, no ScrollBox view changes. Rows are pooled and recolored by
-- Blizzard (SetVertexColor on their background art), so our flat tint follows that call.
-- The leave button keeps Blizzard's script (it may open a confirm popup); we only restyle/anchor it.
local _, ns = ...
local G = _G --[[@as table<string, any>]] -- Blizzard globals missing from the annotations

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = { 0, 0, 0, 1 }
local BOX = { 0, 0, 0, 0.25 }
local PAD, ICON = 18, 46
local TOOLBAR_TOP = PAD + ICON + 14   -- 78
local CONTENT_TOP = TOOLBAR_TOP + 28 + 12 -- 118
local FOOTER = 54
local TAB_MIN_W = 120

local skinned = setmetatable({}, { __mode = "k" })
local own = setmetatable({}, { __mode = "k" })
local tabParts = setmetatable({}, { __mode = "k" })
local windows = setmetatable({}, { __mode = "k" }) -- frame -> config + our header parts
local fonts
local hooked = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.scoreboardSkin ~= false
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
    Edges(target, target)
    local accent = Tex(target, "OVERLAY", 7, ns.UI.ACCENT)
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
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
        normal = Make("MeredanUIScoreButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIScoreButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUIScoreButtonDisabled", GameFontDisable, UI.MUTED),
        tab = Make("MeredanUIScoreTab", GameFontHighlight, UI.MUTED),
        tabActive = Make("MeredanUIScoreTabActive", GameFontHighlight, UI.ACCENT),
    }
    return fonts
end

local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local function FadeButtonTextures(button)
    for _, getter in ipairs(BUTTON_TEXTURES) do
        local fn = button[getter]
        local tex = fn and fn(button)
        if tex then Fade(tex) end
    end
end

-- Controls ---------------------------------------------------------------------------------------

-- flat button (UIPanelButton / ThreeSlice); hover via HIGHLIGHT layer. ThreeSlice re-sets its atlases
-- on every state change, but SetAtlas keeps our alpha.
local function SkinButton(button)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Right", "Center" }) do Fade(button[key]) end
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

local function SkinIconButton(button, iconName, iconSize)
    if type(button) ~= "table" or not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = UI.Icon(button, iconName, iconSize or 14)
    own[icon] = true
    icon:SetPoint("CENTER", bg)
    button:HookScript("OnEnter", function() icon:SetVertexColor(unpack(UI.ACCENT)) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
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
    local function Each() if not box.GetView or box:GetView() then box:ForEachFrame(fn) end end -- no view until Blizzard fills the list
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
end

-- Rows (PVPTableRowTemplate): Blizzard tints its highlight art per faction via SetVertexColor;
-- we hide that art and mirror the tint onto a flat fill.
local ROW_ALPHA = 0.16
local function SkinRow(row)
    if type(row) ~= "table" or not row.Backgrounds or not Once(row) then return end
    for _, background in ipairs(row.Backgrounds) do Fade(background) end
    local fill = Tex(row, "BACKGROUND", -8, { 1, 1, 1, ROW_ALPHA })
    fill:SetAllPoints()
    local line = Tex(row, "BACKGROUND", -7, { 0, 0, 0, 0.35 })
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(ns.PixelSize())
    local source = row.backgroundCenter or row.Backgrounds[1]
    if source then
        local r, g, b = source:GetVertexColor()
        fill:SetColorTexture(r or 1, g or 1, b or 1, ROW_ALPHA)
        hooksecurefunc(source, "SetVertexColor", function(_, nr, ng, nb)
            fill:SetColorTexture(nr or 1, ng or 1, nb or 1, ROW_ALPHA)
        end)
    end
end

-- Column headers (sort buttons): built per match by ConstructPVPMatchTable, pooled by the table builder
local function SkinHeaders(categories)
    if type(categories) ~= "table" or not categories.GetChildren then return end
    local UI = ns.UI
    for _, header in ipairs({ categories:GetChildren() }) do
        if header.IsObjectType and header:IsObjectType("Button") and Once(header) then
            local hover = Tex(header, "HIGHLIGHT", 0, { 1, 1, 1, 0.08 })
            hover:SetPoint("TOPLEFT", -4, 2)
            hover:SetPoint("BOTTOMRIGHT", 4, -2)
            if header.text then header.text:SetTextColor(unpack(UI.TEXT)) end
        end
    end
end

-- Tabs (All / Alliance / Horde): flat buttons in the toolbar; active one Surf Green.
-- Blizzard disables the selected tab and resizes tabs to their text on show.
local function SkinTab(tab)
    if type(tab) ~= "table" or not Once(tab) then return end
    local UI = ns.UI
    FadeRegions(tab)
    local bg = Tex(tab, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    local hover = Tex(tab, "HIGHLIGHT", 0, { 1, 1, 1, 0.05 })
    hover:SetAllPoints()
    Border(tab)
    local active = Border(tab, true, 2)
    for _, edge in ipairs(active) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    tabParts[tab] = active
end

local function UpdateTabs(window)
    local f = Fonts()
    local selected = PanelTemplates_GetSelectedTab(window.frame)
    for i, tab in ipairs(window.tabs) do
        local edges = tabParts[tab]
        if edges then
            local on = selected == i
            for _, edge in ipairs(edges) do edge:SetShown(on) end
            FadeRegions(tab)
            local font = on and f.tabActive or f.tab
            tab:SetNormalFontObject(font)
            tab:SetDisabledFontObject(font)
            tab:SetHighlightFontObject(f.tabActive)
            if tab.Text then
                tab.Text:ClearAllPoints()
                tab.Text:SetPoint("CENTER", 0, 0)
            end
            tab:SetHeight(28)
            if tab:GetWidth() < TAB_MIN_W then tab:SetWidth(TAB_MIN_W) end
        end
    end
end

-- Header ---------------------------------------------------------------------------------------------

local function FactionIcon()
    -- Banner icons: 01 Horde, 02 Alliance
    return UnitFactionGroup("player") == "Horde" and 132485 or 132486
end

local function UpdateHeader(window)
    if not window.subtitle then return end
    window.icon:SetTexture(FactionIcon())
    local text = ""
    if window.results then
        text = GetRealZoneText() or ""
    elseif C_PvP and C_PvP.GetActiveMatchDuration and G.PVPMatchUtil and G.PVPMatchUtil.MatchTimeFormatter then
        local seconds = C_PvP.GetActiveMatchDuration()
        if type(seconds) == "number" and not (issecretvalue and issecretvalue(seconds)) and seconds > 0 then
            text = G.PVPMatchUtil.MatchTimeFormatter:Format(seconds)
        end
    end
    window.subtitle:SetText(text)
end

-- Layout ----------------------------------------------------------------------------------------------

local function Place(window)
    local f = window.frame
    -- Not protected today; if Blizzard ever makes it secure, re-anchoring must wait for combat end
    if InCombatLockdown() and f:IsProtected() then return ns.AfterCombat(function() Place(window) end) end
    f:SetSize(window.width, CONTENT_TOP + window.contentH + window.footer)

    local header = window.header
    if header and window.holder then
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", window.holder, "TOPRIGHT", 14, -4)
        header:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
        header:SetHeight(20)
        if header.Text then
            header.Text:ClearAllPoints()
            header.Text:SetPoint("LEFT")
            header.Text:SetPoint("RIGHT")
            header.Text:SetJustifyH("LEFT")
        end
    end

    local close = window.close
    if close then
        close:SetSize(34, 34)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", -(PAD - 4), -(PAD - 4))
    end

    local previous
    for _, tab in ipairs(window.tabs) do
        tab:ClearAllPoints()
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            tab:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -TOOLBAR_TOP)
        end
        previous = tab
    end

    local content = window.content
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -CONTENT_TOP)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, window.footer)

    local leave = window.leave
    if leave and not (InCombatLockdown() and leave:IsProtected()) then
        leave:ClearAllPoints()
        leave:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 14)
        leave:SetHeight(28)
    end
    UpdateTabs(window)
end

local function SkinWindow(window)
    local f = window.frame
    if not Once(f) then return end
    local UI = ns.UI
    FadeRegions(f)
    Fade(f.NineSlice)
    Panel(f)

    -- Header like mUI windows; Blizzard's title (map name / outcome) becomes our title line
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    window.holder, window.icon = holder, icon
    local header = window.header
    if header and header.Text then
        ns.SetFont(header.Text, 16, "", "bold")
        header.Text:SetTextColor(unpack(UI.TEXT))
        header.Text:SetWordWrap(false)
    end
    local subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -29)
    subtitle:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
    subtitle:SetWordWrap(false)
    window.subtitle = subtitle

    SkinIconButton(window.close, "Close", 18)
    for _, tab in ipairs(window.tabs) do SkinTab(tab) end

    -- Table: dark box, flat header band with a bottom line
    local content = window.content
    FadeRegions(content)
    local box = Tex(f, "BACKGROUND", -7, BOX)
    box:SetAllPoints(content)
    Edges(f, box)
    local categories = window.categories
    if categories then
        FadeRegions(categories)
        local band = Tex(f, "BACKGROUND", -6, UI.FIELD)
        band:SetPoint("TOPLEFT", content, "TOPLEFT")
        band:SetPoint("RIGHT", content, "RIGHT")
        band:SetPoint("BOTTOM", categories, "BOTTOM")
        local line = Tex(f, "BACKGROUND", -5, BLACK)
        line:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
        line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
        line:SetHeight(ns.PixelSize())
        SkinHeaders(categories)
    end
    SkinScrollBar(window.scrollBar)
    HookScrollBox(window.scrollBox, SkinRow)

    if window.leave then SkinButton(window.leave) end
end

local function Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local function Setup(frame, config)
    if type(frame) ~= "table" or windows[frame] then return end
    config.frame = frame
    windows[frame] = config
    Try(SkinWindow, config)
    Try(Place, config)
    Try(UpdateHeader, config)
    frame:HookScript("OnShow", function()
        Place(config)
        UpdateHeader(config)
        SkinHeaders(config.categories)
    end)
    if frame.UpdateTable then hooksecurefunc(frame, "UpdateTable", function() UpdateHeader(config) end) end
end

local function Apply()
    if not Enabled() then return end
    local board = G.PVPMatchScoreboard
    if type(board) == "table" and board.Content then
        local content = board.Content
        local group = content.TabContainer and content.TabContainer.TabGroup
        Setup(board, {
            width = 1024, contentH = 392, footer = PAD,
            content = content, categories = content.ScrollCategories,
            scrollBox = content.ScrollBox, scrollBar = content.ScrollBar,
            tabs = group and { group.Tab1, group.Tab2, group.Tab3 } or {},
            close = board.ClosePanelButton, header = board.HeaderContainer,
        })
    end
    local results = G.PVPMatchResults
    if type(results) == "table" and results.content then
        local content = results.content
        local group = content.tabContainer and content.tabContainer.tabGroup
        Setup(results, {
            width = 1024, contentH = 442, footer = FOOTER, results = true,
            content = content, categories = content.scrollCategories,
            scrollBox = content.scrollBox, scrollBar = content.scrollBar,
            tabs = group and { group.tab1, group.tab2, group.tab3 } or {},
            close = results.CloseButton, header = results.HeaderContainer,
            leave = results.buttonContainer and results.buttonContainer.leaveButton,
        })
    end

    if hooked or not next(windows) then return end
    hooked = true
    hooksecurefunc("PanelTemplates_UpdateTabs", function(owner)
        local window = windows[owner]
        if window then UpdateTabs(window) end
    end)
    hooksecurefunc("PanelTemplates_TabResize", function(tab)
        if tabParts[tab] then
            tab:SetHeight(28)
            if tab:GetWidth() < TAB_MIN_W then tab:SetWidth(TAB_MIN_W) end
        end
    end)
    if G.ConstructPVPMatchTable then
        hooksecurefunc("ConstructPVPMatchTable", function()
            for _, window in pairs(windows) do SkinHeaders(window.categories) end
        end)
    end
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_PVPMatch" then Apply() end
end)

ns:On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_PVPMatch") then Apply() end
end)
