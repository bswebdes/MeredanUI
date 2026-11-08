-- Anprobe (DressUpFrame, WoW Forever) im mUI-Look (Benny 2026-11-08). Ein Nachbau lohnt nicht:
-- Blizzards Fenster zieht Gegenstände, Sets, Reittiere und Haustiere über seine 3D-Szene an – das
-- bleibt alles Blizzards. Wir ändern nur Optik und Platz:
--
--   ┌ [▣] Anprobe                                               [x] ┐
--   │     Robe des Erzmagiers                                       │  ← zuletzt angezogen
--   │ [Outfits           v] [Speichern]                        [≡]  │
--   │ ┌───────────────────────────────────────────────────────────┐ │
--   │ │                     3D-Modell (Volk-Hintergrund)          │ │
--   │ └───────────────────────────────────────────────────────────┘ │
--   │ [Verlinken]                        [Zurücksetzen] [Schließen] │
--   └───────────────────────────────────────────────────────────────┘
--
-- Platz: wie alle mUI-Fenster (über dem Chat, sonst rechts neben den anderen offenen Fenstern).
-- Blizzards Fensterverwaltung (Bereich „left“) wird per SetUIPanelAttribute abgeschaltet – dann
-- zeigt ShowUIPanel das Fenster nur noch an. Größe/Anker setzt Blizzard in ConfigureSize neu,
-- danach legen wir unser Layout wieder darüber (hooksecurefunc). Keine Felder an Blizzards Tabellen.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = { 0, 0, 0, 1 }
local PAD, ICON = 18, 46
local WIDTH = 460
local TOOLBAR_TOP = PAD + ICON + 14   -- 78: Leiste unter dem Kopf
local SCENE_TOP = TOOLBAR_TOP + 28 + 12
local FOOTER = 56                     -- Fuß mit Knöpfen (28 hoch, 14 vom Rand)
local BLIZZ_SCENE_H, BLIZZ_BG_BOTTOM = 454, 90 -- Blizzards Maße für den Volk-Hintergrund

local skinned = setmetatable({}, { __mode = "k" })
local own = setmetatable({}, { __mode = "k" })
local frame, portrait, subtitle
local fonts

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.dressUpSkin ~= false
end

local function Once(object)
    if type(object) ~= "table" or skinned[object] then return false end
    if object.IsForbidden and object:IsForbidden() then return false end
    skinned[object] = true
    return true
end

local function Fade(region)
    if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
end

local function FadeRegions(target)
    if type(target) ~= "table" or not target.GetRegions then return end
    for _, region in ipairs({ target:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") and not own[region] then region:SetAlpha(0) end
    end
end

local function Tex(parent, layer, sublevel, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    if color then tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    own[tex] = true
    return tex
end

-- 1-px-Rahmen außen um target (Texturen an parent)
local function Edges(parent, target, color)
    local px = ns.PixelSize()
    local c = color or BLACK
    local edges = {}
    for i = 1, 4 do
        local edge = parent:CreateTexture(nil, "BORDER")
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

-- Fläche + Rahmen + Surf-Green-Linie oben
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
        font:SetFont(ns.STYLE.font, ns.FontPx(13), "")
        font:SetTextColor(color[1], color[2], color[3])
        return font
    end
    fonts = {
        normal = Make("MeredanUIDressUpButton", GameFontHighlight, UI.TEXT),
        highlight = Make("MeredanUIDressUpButtonHighlight", GameFontHighlight, UI.ACCENT),
        disabled = Make("MeredanUIDressUpButtonDisabled", GameFontDisable, UI.MUTED),
    }
    return fonts
end

local BUTTON_TEXTURES = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local function FadeButtonTextures(button)
    for _, getter in ipairs(BUTTON_TEXTURES) do
        local fn = button[getter]
        if fn then Fade(fn(button)) end
    end
end

-- flacher Knopf (UIPanelButtonTemplate)
local function SkinButton(button)
    if not Once(button) or not button.IsObjectType then return end
    local UI = ns.UI
    for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(button[key]) end
    FadeButtonTextures(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetAllPoints()
    for _, edge in ipairs(ns.AddBorder(button)) do own[edge] = true end
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() then bg:SetColorTexture(unpack(UI.HOVER)) end
    end)
    button:HookScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    if button.GetFontString and button:GetFontString() then
        local f = Fonts()
        button:SetNormalFontObject(f.normal)
        button:SetHighlightFontObject(f.highlight)
        button:SetDisabledFontObject(f.disabled)
    end
end

-- Symbol-Knopf (Schließen, Outfit-Liste): flaches Kästchen, unser Symbol, Hover Surf Green
local function SkinIconButton(button, iconName, iconSize)
    if not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = UI.Icon(button, iconName, iconSize or 14)
    own[icon] = true
    icon:SetPoint("CENTER")
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() then icon:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(UI.TEXT)) end)
end

-- Dropdown (WowStyle1DropdownTemplate): flaches Feld, unser Pfeil
local function SkinDropdown(dropdown)
    if not Once(dropdown) then return end
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

-- Seitenteile (Outfit-Details, Set-Auswahl): flach wie das Fenster
local function SkinSidePanel(panel)
    if not Once(panel) then return end
    FadeRegions(panel)
    Fade(panel.NineSlice)
    Panel(panel)
end

-- Kopf: Porträt, „Anprobe“, darunter das zuletzt Angezogene (sonst der eigene Name)
local function UpdateHeader()
    if not portrait then return end
    SetPortraitTexture(portrait, "player")
    local link = frame.GetLastLink and frame:GetLastLink()
    local text = type(link) == "string" and link:find("|H") and link:gsub("[%[%]]", "") or UnitName("player")
    subtitle:SetText(text or "")
end

-- Gesamt-Layout; nach Blizzards ConfigureSize (Maximieren/Minimieren) erneut
local function Place()
    local f = frame
    f:SetSize(WIDTH, ns.NPC_HEIGHT)
    local scene = f.ModelScene
    scene:ClearAllPoints()
    scene:SetPoint("TOPLEFT", PAD, -SCENE_TOP)
    scene:SetPoint("BOTTOMRIGHT", -PAD, FOOTER)
    -- Volk-Hintergrund: unteres Band im gleichen Verhältnis wie bei Blizzard
    local bottom = BLIZZ_BG_BOTTOM * (ns.NPC_HEIGHT - SCENE_TOP - FOOTER) / BLIZZ_SCENE_H
    if scene.BGBottomLeft then scene.BGBottomLeft:SetHeight(bottom) end
    if scene.BGBottomRight then scene.BGBottomRight:SetHeight(bottom) end

    local dropdown = f.CustomSetDropdown
    if dropdown then
        dropdown:ClearAllPoints()
        dropdown:SetPoint("TOPLEFT", PAD, -TOOLBAR_TOP)
        dropdown:SetSize(220, 28)
        local save = dropdown.SaveButton
        if save then
            save:ClearAllPoints()
            save:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)
            save:SetSize(100, 28)
        end
    end
    local toggle = f.ToggleCustomSetDetailsButton
    if toggle then
        toggle:ClearAllPoints()
        toggle:SetPoint("TOPRIGHT", -(PAD - 4), -(TOOLBAR_TOP - 4))
        toggle:SetSize(36, 36)
    end

    local cancel = DressUpFrameCancelButton
    if cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", -PAD, 14)
        cancel:SetSize(110, 28)
    end
    if f.ResetButton then
        f.ResetButton:ClearAllPoints()
        f.ResetButton:SetPoint("RIGHT", cancel or f, cancel and "LEFT" or "BOTTOMRIGHT", -6, 0)
        f.ResetButton:SetSize(110, 28)
    end
    if f.LinkButton then
        f.LinkButton:ClearAllPoints()
        f.LinkButton:SetPoint("BOTTOMLEFT", PAD, 14)
        f.LinkButton:SetSize(170, 28)
    end

    -- Seitenteile rechts daneben, gleiche Oberkante und Höhe
    for _, panel in ipairs({ f.CustomSetDetailsPanel, f.SetSelectionPanel }) do
        if panel then
            panel:ClearAllPoints()
            panel:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, 0)
            panel:SetHeight(ns.NPC_HEIGHT)
        end
    end
end

local function Reposition(opening)
    if frame:IsShown() and ns.ResetWindowPosition then
        ns.ResetWindowPosition(frame, "dressup", opening and not InCombatLockdown())
    end
end

local function SkinShell(f)
    local UI = ns.UI
    FadeRegions(f) -- Hintergrund, Streifen oben (ModelBackground ist in Forever ohnehin aus)
    Fade(f.NineSlice)
    Fade(f.Inset)
    Fade(f.PortraitContainer)
    Fade(f.TitleContainer)
    if DressUpFramePortrait then DressUpFramePortrait:SetAlpha(0) end
    Panel(f)

    -- Kopf wie die mUI-Fenster
    local holder = CreateFrame("Frame", nil, f)
    holder:SetSize(ICON, ICON)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    portrait = holder:CreateTexture(nil, "ARTWORK")
    portrait:SetAllPoints()
    portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    local title = UI.Text(holder, 16, "LEFT")
    ns.SetFont(title, 16, "", "bold")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    title:SetPoint("RIGHT", f, "RIGHT", -PAD - 36, 0)
    title:SetText(DRESSUP_FRAME or "")
    subtitle = UI.Text(holder, 12, "LEFT", UI.MUTED)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    subtitle:SetPoint("RIGHT", title, "RIGHT")
    subtitle:SetWordWrap(false)

    -- Ziehen an der Kopfzeile wie bei den mUI-Fenstern
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT", -PAD - 36, 0)
    header:SetHeight(PAD + ICON + 6)
    ns.MakeWindowDraggable(f, header)

    if f.CloseButton then
        SkinIconButton(f.CloseButton, "Close", 18)
        f.CloseButton:SetSize(34, 34)
        f.CloseButton:ClearAllPoints()
        f.CloseButton:SetPoint("TOPRIGHT", -(PAD - 4), -(PAD - 4))
    end
    -- Minimieren braucht es nicht (feste Größe wie alle mUI-Fenster)
    local maxMin = f.MaximizeMinimizeFrame
    if maxMin then
        maxMin:SetAlpha(0)
        maxMin:EnableMouse(false)
        for _, button in ipairs({ maxMin.MaximizeButton, maxMin.MinimizeButton }) do
            if button then
                button:SetAlpha(0)
                button:EnableMouse(false)
            end
        end
    end

    -- Modell mit 1-px-Rahmen
    Edges(f, f.ModelScene)

    SkinButton(DressUpFrameCancelButton)
    SkinButton(f.ResetButton)
    SkinButton(f.LinkButton)
    if f.CustomSetDropdown then
        SkinDropdown(f.CustomSetDropdown)
        SkinButton(f.CustomSetDropdown.SaveButton)
    end
    SkinIconButton(f.ToggleCustomSetDetailsButton, "Sort", 14)
    SkinSidePanel(f.CustomSetDetailsPanel)
    SkinSidePanel(f.SetSelectionPanel)
end

local function Unmanage()
    if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
    if SetUIPanelAttribute then SetUIPanelAttribute(frame, "area", nil) end
    for _, name in ipairs(UISpecialFrames) do
        if name == "DressUpFrame" then return end
    end
    tinsert(UISpecialFrames, "DressUpFrame") -- Esc schließt weiter
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not DressUpFrame then return end
    frame = DressUpFrame
    SkinShell(frame)
    Unmanage()
    Place()

    -- Seitenteile hängen rechts außen: Nachbarfenster rücken dahinter
    if ns.EXTRA_RIGHT then
        ns.EXTRA_RIGHT[frame] = function(window)
            local right, extra = window:GetRight(), 0
            if not right then return 0 end
            for _, panel in ipairs({ window.CustomSetDetailsPanel, window.SetSelectionPanel }) do
                if panel and panel:IsShown() and panel:GetRight() then extra = math.max(extra, panel:GetRight() - right) end
            end
            return extra
        end
    end

    if frame.ConfigureSize then hooksecurefunc(frame, "ConfigureSize", Place) end
    if frame.SetShownCustomSetDetailsPanel then
        hooksecurefunc(frame, "SetShownCustomSetDetailsPanel", function() C_Timer.After(0, function() Reposition() end) end)
    end
    if frame.SetLastLink then hooksecurefunc(frame, "SetLastLink", UpdateHeader) end
    if frame.SetSelectionPanel then
        frame.SetSelectionPanel:HookScript("OnShow", function() C_Timer.After(0, function() Reposition() end) end)
        frame.SetSelectionPanel:HookScript("OnHide", function() C_Timer.After(0, function() Reposition() end) end)
    end
    frame:HookScript("OnShow", function()
        Place()
        UpdateHeader()
        C_Timer.After(0, function() Reposition(true) end)
    end)
end)
