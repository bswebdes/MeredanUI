-- Gilden- und Communities-Fenster (CommunitiesFrame) im mUI-Look (Benny 2026-11-08). Gegenstück zum
-- eigenen Gildenfenster (Social/Guild.lua): Blizzards Fenster bleibt voll funktionsfähig (Gildeneinladung
-- & Co. sind geschützt und gehen nur aus Blizzards Code), wir ändern nur die Oberfläche.
-- Regeln (der erste Versuch wurde wegen geändertem Aufbau verworfen):
--  * Aufbau bleibt exakt Blizzards: kein SetPoint/SetSize/ClearAllPoints an Blizzard-Rahmen/-Regionen.
--  * Rahmen/Kanten (NineSlice, Knopf-Grafiken, Dropdown-/Scrollleisten-Art) nur per SetAlpha(0) weg,
--    unsere Flächen/Kanten als neue Regionen darüber/darunter.
--  * Flach wie die mUI-Fenster (Benny 2026-11-08, nach Vergleich mit EllesmereUI): Artworks
--    (Filigran, Listen-Hintergründe, Pergament, Zeilen-Grafiken) unsichtbar, eigene flache Flächen.
--    Symbole und Wappen bleiben.
--  * Keine SetScript, keine Felder an Blizzard-Tabellen, keine Blizzard-Funktionen aufrufen – nur
--    HookScript/hooksecurefunc. Eigener Zustand in schwachen Tabellen.
local _, ns = ...

local WHITE = "Interface\\Buttons\\WHITE8X8"
local BLACK = { 0, 0, 0, 1 }
local INPUT = { 0.04, 0.04, 0.05, 1 }

local HEAD_PAD, HEAD_ICON, HEAD_HEIGHT = 18, 46, 80 -- Kopf wie die mUI-Fenster; Inhalte ab HEAD_HEIGHT
-- Zielbild = eigenes mUI-Gildenfenster (Social/Guild.lua, Benny 2026-11-08: „1:1 so“): gleiche Maße
local WIN_W, WIN_H = 940, 640
local PAD, LIST_W, MEMBER_W = 18, 190, 180
local CONTENT_X = PAD + LIST_W + 12        -- Inhalt rechts der Community-Liste
local CONTENT_TOP = PAD + HEAD_ICON + 14   -- Inhalt unter dem Kopf (78)
local CONTENT_BOTTOM = 54                  -- Fußzeile darunter
local BOX = { 0.098, 0.098, 0.106, 1 }     -- Kästen (Nachricht des Tages, Info, Neuigkeiten)
local PlaceAll                             -- Gesamt-Layout (unten definiert)
local LIST_SLOT, LIST_TOP_PAD = 68, 40     -- Blizzards Zeilenhöhe/Rand der Community-Liste (ggf. angepasst)
local CARD_INSET = 4                       -- Karte = Zeile minus 2 × CARD_INSET (60 px, 8 px Abstand)
local memberDeco = {}                      -- Kasten der Mitgliederliste (nur Chat-Ansicht)
local SIDE_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }

local noBump = setmetatable({}, { __mode = "k" }) -- Bereiche mit festen Breiten (Info-Spalte)
local skinned = setmetatable({}, { __mode = "k" }) -- Objekt > true (schon bemalt)
local own = setmetatable({}, { __mode = "k" })     -- unsere Texturen (beim Ausblenden auslassen)
local fonts
local applied = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.guildWindow == false and ns.db.guildSkin ~= false
end

-- true beim ersten Mal, danach false (jedes Objekt nur einmal bemalen)
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

-- alle Texturen eines Rahmens durchsichtig (nicht die Kinder-Rahmen, nicht unsere, nicht keep)
local function FadeRegions(frame, keep)
    if type(frame) ~= "table" or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if IsTexture(region) and not own[region] and not (keep and keep[region]) then region:SetAlpha(0) end
    end
end


-- neue Textur an parent, als „unsere“ gemerkt
local function Tex(parent, layer, sublevel, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    if color then tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1) end
    own[tex] = true
    return tex
end

-- 1-px-Rahmen außen um target, Texturen liegen an parent (z. B. wenn target eine Textur ist)
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

-- Fläche + Rahmen + 2-px-Surf-Green-Linie oben (Fenster und Popups). target = sichtbare Fläche
-- (z. B. Blizzards Rand-Rahmen, der versetzt sitzt), Standard: der Rahmen selbst.
local function Panel(frame, target)
    target = target or frame
    local c = ns.STYLE.panelColor
    local bg = Tex(frame, "BACKGROUND", -8, { c[1], c[2], c[3], 0.96 })
    bg:SetAllPoints(target)
    Edges(frame, target)
    local accent = Tex(frame, "OVERLAY", 7, ns.UI.ACCENT)
    accent:SetPoint("TOPLEFT", target, "TOPLEFT")
    accent:SetPoint("TOPRIGHT", target, "TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    return bg
end

-- Schriftobjekte für Knöpfe: Kopien von Blizzards Schrift (gleiche Größe > keine andere Knopfbreite),
-- nur die Farbe wie mUI
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

-- Bedienelemente ----------------------------------------------------------------------------------

-- flacher Knopf (UIPanelButtonTemplate & Co.): Blizzards Grafik unsichtbar, Fläche + 1-px-Rand,
-- Hover hellt auf
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

-- Symbol-Knopf (Schließen, Maximieren …): flaches Kästchen mit unserem Symbol, Hover in Surf Green
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

-- Eingabefeld: Blizzards Kanten weg, dunkles Feld, Fokus mit Surf-Green-Rand.
-- inset = { links, oben, rechts, unten } relativ zum Feld (Standard: Blizzards Left/Right-Grafik)
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
    -- leichte helle Kante, damit das Feld auf dunklem Grund erkennbar ist; mit Fokus Surf Green
    local IDLE = UI.CHECK_EDGE or { 0.36, 0.36, 0.38, 1 }
    local edges = Edges(box, bg, IDLE)
    box:HookScript("OnEditFocusGained", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    box:HookScript("OnEditFocusLost", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1) end
    end)
end

-- mehrzeiliges Eingabefeld (InputScrollFrameTemplate): Rahmen-Grafik weg, dunkles Feld
local function SkinInputScroll(scroll)
    if type(scroll) ~= "table" or not scroll.GetRegions or not Once(scroll) then return end
    FadeRegions(scroll)
    local bg = Tex(scroll, "BACKGROUND", -8, INPUT)
    bg:SetPoint("TOPLEFT", -5, 5)
    bg:SetPoint("BOTTOMRIGHT", 5, -5)
    Edges(scroll, bg)
end

-- Häkchen: dunkles Kästchen, Haken in Surf Green (wie in den mUI-Einstellungen)
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

-- Dropdown (WowStyle1DropdownTemplate & Co.): flaches Feld, 1-px-Rand, unser Pfeil.
-- Reine Pfeil-Dropdowns (ohne Text, z. B. „Zum Chat hinzufügen“) werden ein kleines Symbol-Kästchen.
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

-- Scrollleiste (MinimalScrollBar) wie UI.Scrollbar: Pfeile als Chevron, schmale Spur, Griff in
-- Surf Green (Hover breiter). Blizzards Teile bleiben (unsichtbar) und tun die Arbeit.
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
    -- nichts zu scrollen: Leiste unsichtbar (Benny 2026-11-08: leere Leiste neben der Community-Liste)
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

-- Inhaltskasten (InsetFrameTemplate): Blizzards Kante und Marmor weg. withBorder: eigener 1-px-Rand,
-- fill: dunkle Fläche (nur, wenn der Kasten unter dem Inhalt liegt)
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

-- Kasten mit Tooltip-Rand (Notizen, Gildenlog-Inhalt): Rand weg, dunkles Feld
local function SkinBackdropBox(box, alpha)
    if type(box) ~= "table" or not box.GetRegions or not Once(box) then return end
    Fade(box.NineSlice)
    FadeRegions(box)
    local bg = Tex(box, "BACKGROUND", -8, { INPUT[1], INPUT[2], INPUT[3], alpha or 0.9 })
    bg:SetAllPoints()
    Border(box)
end

-- Listen (ScrollBox) --------------------------------------------------------------------------------

-- Zeilen einer ScrollBox: nach jedem Update alle sichtbaren Zeilen (neue und wiederverwendete)
-- einmalig bemalen. Update läuft bei Daten, Scrollen und Größe (ScrollBoxListMixin).
local function HookScrollBox(box, fn)
    if type(box) ~= "table" or not box.ForEachFrame or not Once(box) then return end
    local function Each() box:ForEachFrame(fn) end
    if box.Update then hooksecurefunc(box, "Update", Each) end
    Each()
end

-- Eintrag der Community-Liste links: Blizzards blaue Karte unsichtbar, flache Karte, Auswahl mit
-- Surf-Green-Streifen links. Wappen, Symbol und Ring bleiben.
-- Eintrag der Community-Liste wie im eigenen Fenster: Karte 52 px (in Blizzards 68-px-Platz), Symbol
-- 32 px im Kästchen links, Name (13) und Art (11, grau) daneben, gewählt mit Surf-Green-Streifen
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
                -- Blizzard hat das Symbol schon gesetzt (geschützt – nicht selbst aufrufen): übernehmen
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

-- Spalten der Mitgliederseite wie im eigenen Fenster (Stufe 44, Klasse 50, Name 150, Zone 120, Rang 104,
-- Notiz Rest); neben dem Chat ist die Liste 180 breit. Nur Punkte/Breiten an Blizzards Zeilen.
local COL_X = { level = 10, class = 56, name = 104, zone = 254, rank = 374, note = 478 }
local COLUMN_WIDTHS = { 46, 52, 152, 122, 106 } -- Köpfe überlappen bei Blizzard je 2 px
local LIST_EXTRA = MEMBER_W - 165
local function RowLayout(row)
    if InCombatLockdown() then return end
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

-- Zeile der Mitgliederliste:-- Zeile der Mitgliederliste: Blizzards Streifen und blauer Hover weg, flache Zeile, Hover in Surf Green
local function SkinMemberRow(row)
    if not Once(row) then return end
    local UI = ns.UI
    Fade(row:GetNormalTexture())
    Fade(row:GetHighlightTexture())
    -- wie im eigenen Fenster: keine Zeilen-Fläche, nur heller Hover
    local hover = Tex(row, "HIGHLIGHT", 0, { 1, 1, 1, 0.04 })
    hover:SetAllPoints()
    if row.UpdateNameFrame then hooksecurefunc(row, "UpdateNameFrame", RowLayout) end
    if row.RefreshExpandedColumns then hooksecurefunc(row, "RefreshExpandedColumns", RowLayout) end
    local header = row.ProfessionHeader
    if type(header) == "table" then
        for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(header[key]) end
    end
end

-- Spaltenköpfe (erweiterte Mitgliederliste): flache Felder mit Hover. Nur Optik – keine Skripte an
-- die Spaltenleiste (sonst blockiert WoW später Notiz/Rang ändern).
local function SkinColumnHeaders(display)
    if type(display) ~= "table" or not display.GetChildren then return end
    local UI = ns.UI
    for _, column in ipairs({ display:GetChildren() }) do
        -- Namensspalte mit Stufe/Klasse davor (Gilde, Charakter-Community) wie die Zeilen verbreitern
        -- Gilde/Charakter-Community (Stufe + Klasse davor): Spaltenbreiten wie im eigenen Fenster
        if column:IsObjectType("Button") and column:IsShown() and COLUMN_WIDTHS[column:GetID()]
            and display:GetParent() and display:GetParent().columnInfo and #display:GetParent().columnInfo == 6 then
            column:SetWidth(COLUMN_WIDTHS[column:GetID()])
        end
        if column:IsObjectType("Button") and Once(column) then
            -- wie im eigenen Fenster: ein durchgehender Balken (an der Spaltenleiste), keine Trennlinien
            for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(column[key]) end
            Fade(column:GetHighlightTexture())
            FadeRegions(column)
            local hover = Tex(column, "HIGHLIGHT", 0, { 1, 1, 1, 0.04 })
            hover:SetAllPoints()
        end
    end
end

-- Zeilen mit eigener Artwork (Vorteile, Belohnungen, Neuigkeiten): Artwork weg, flache Zeile;
-- Symbole, Schloss und Sperr-Schleier unverändert (Blizzard färbt sie selbst)
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

-- dunkle Fläche hinter einem Bereich (ersetzt Pergament/Listen-Hintergrund)
local function Fill(frame, alpha)
    if type(frame) ~= "table" or not frame.CreateTexture then return end
    local bg = Tex(frame, "BACKGROUND", -8, { 0, 0, 0, alpha or 0.35 })
    bg:SetAllPoints()
    return bg
end

-- Reiter rechts (Chat, Mitglieder, Vorteile, Info …): wie die Reiter der mUI-Fenster – Kasten in
-- Fensterfarbe, Symbol beschnitten, inaktiv entsättigt, aktiv mit 2-px-Surf-Green-Rand innen.
-- Größe, Position und Klick bleiben Blizzards.
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
    tab.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    local hover = Tex(tab, "HIGHLIGHT", 0, { 1, 1, 1, 0.08 })
    hover:SetAllPoints()
    local active = Border(tab, true, 2)
    for _, edge in ipairs(active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    local function Update()
        local on = tab:GetChecked() and true or false
        for _, edge in ipairs(active) do edge:SetShown(on) end
        tab.Icon:SetDesaturated(not on)
    end
    hooksecurefunc(tab, "SetChecked", Update)
    tab:HookScript("OnClick", Update)
    tab:HookScript("OnShow", Update)
    Update()
end

-- Bereiche ----------------------------------------------------------------------------------------

local function SkinShell(f)
    FadeRegions(f) -- Blizzards Fels-Hintergrund und Streifen oben
    Fade(f.NineSlice)
    Panel(f)
    local title = f.TitleContainer and f.TitleContainer.TitleText
    if title then
        local _, size = title:GetFont()
        title:SetFont(ns.FontFor("bold"), size or 12, "")
        title:SetTextColor(unpack(ns.UI.TEXT))
    end
    SkinIconButton(f.CloseButton, "Close", 18)
    -- Einzige Ausnahme von „nichts verschieben“ (Benny 2026-11-08): Schließen sitzt sonst auf Blizzards
    -- (entferntem) dicken Rahmen direkt an der Kante. Wie bei den mUI-Fenstern 10 px eingerückt (der
    -- sichtbare Kasten liegt 4 px innerhalb des Knopfs). Minimieren hängt an Schließen und rückt mit.
    -- Ungeschützte Knöpfe, kein Taint-Risiko.
    -- Platz wie alle mUI-Fenster (über dem Chat, sonst rechts neben anderen offenen Fenstern) statt
    -- Blizzards Standardplatz oben links (Benny 2026-11-08). Nach Blizzards Aufbau einen Takt später.
    -- Platz wie alle mUI-Fenster (über dem Chat, sonst rechts neben anderen offenen Fenstern).
    -- Blizzards Fensterverwaltung (UIPanel, Bereich „left“) setzte das Fenster bei jedem Reiter-/
    -- Größenwechsel zurück nach oben links (Benny 2026-11-08: „springt“). Über Blizzards eigenen Weg
    -- (SetUIPanelAttribute) bekommt es keinen Bereich mehr: ShowUIPanel zeigt es dann nur noch an und
    -- verschiebt es nie. Esc schließt es weiter (UISpecialFrames).
    local function Unmanage()
        if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
        if SetUIPanelAttribute then SetUIPanelAttribute(f, "area", nil) end
        local listed = false
        for _, name in ipairs(UISpecialFrames) do if name == "CommunitiesFrame" then listed = true end end
        if not listed then tinsert(UISpecialFrames, "CommunitiesFrame") end
    end
    Unmanage()
    -- Reiter rechts außerhalb des Fensters: Nachbarfenster rücken dahinter (Benny 2026-11-08)
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
    -- gleich hoch wie die mUI-Fenster (Benny 2026-11-08). Erst per Maßstab gelöst – dann waren alle
    -- Schriften 1,5-fach. Jetzt echte Größe: Blizzards großer Modus (814 × 426) wird auf dieselbe
    -- Fläche wie vorher vergrößert (1,5-fach = 1220 × 640), Inhalt dehnt sich mit, Schriften bleiben.
    -- Der Mini-Modus (322 × 406) bleibt Blizzards.
    local BLIZZ_W, BLIZZ_H = 814, 426
    local function FitSize(self)
        if InCombatLockdown() then return end
        if self:GetScale() ~= 1 then self:SetScale(1) end
        local w, h = self:GetSize()
        if math.abs(w - BLIZZ_W) < 1 and math.abs(h - BLIZZ_H) < 1 then
            self:SetSize(WIN_W, WIN_H) -- wie das eigene Gildenfenster
        end
    end
    f:HookScript("OnSizeChanged", function(self)
        FitSize(self)
        if self:IsShown() and not InCombatLockdown() and ns.ResetWindowPosition then
            ns.ResetWindowPosition(self, "guild")
        end
    end)
    FitSize(f)
    f:HookScript("OnShow", function(self)
        FitSize(self)
        C_Timer.After(0, function()
            if self:IsShown() and not InCombatLockdown() and ns.ResetWindowPosition then
                ns.ResetWindowPosition(self, "guild", true)
            end
        end)
    end)
    -- Schließen/Minimieren so groß wie bei den mUI-Fenstern (Benny 2026-11-08): sichtbar 26 px
    -- (Knopf 34, Fläche 4 px eingerückt), Symbol 18; oben in Blizzards Kopfband, damit nichts überlappt
    if f.CloseButton and not InCombatLockdown() then
        f.CloseButton:SetSize(34, 34)
        f.CloseButton:ClearAllPoints()
        f.CloseButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(HEAD_PAD - 4), -(HEAD_PAD - 4))
    end
    local maxMin = f.MaximizeMinimizeFrame
    if maxMin then
        SkinIconButton(maxMin.MaximizeButton, "Square", 16)
        SkinIconButton(maxMin.MinimizeButton, "ChevronDown", 16) -- wie im eigenen Fenster
        if not InCombatLockdown() then
            maxMin:SetSize(34, 34)
            for _, button in ipairs({ maxMin.MaximizeButton, maxMin.MinimizeButton }) do
                if button then
                    button:SetSize(34, 34)
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", maxMin, "CENTER")
                end
            end
            if f.CloseButton then
                maxMin:ClearAllPoints()
                maxMin:SetPoint("RIGHT", f.CloseButton, "LEFT", 2, 0)
            end
        end
    end
    SkinInset(f.Inset)
end

local function SkinCommunitiesList(list)
    if type(list) ~= "table" then return end
    -- Blizzards Liste (Zeilenhöhe/Ränder) nicht anfassen: das „verseucht“ sie, dann blockiert WoW beim
    -- Aufbau das Setzen der Community-Symbole. Abstand rein optisch: Karte 60 in der 68-px-Zeile.
    -- wie im eigenen Fenster: keine Spalten-Fläche, nur die Karten der Einträge
    for _, key in ipairs({ "Bg", "TopFiligree", "BottomFiligree" }) do Fade(list[key]) end
    FadeRegions(list.FilligreeOverlay)
    SkinInset(list.InsetFrame)
    SkinScrollBar(list.ScrollBar)
    HookScrollBox(list.ScrollBox, SkinListEntry)
end

local function SkinChat(f)
    local chat = f.Chat
    if type(chat) == "table" then
        -- wie im eigenen Fenster: Kasten im mUI-Grau mit feiner Kante (Fläche am Chat selbst, liegt
        -- damit sicher unter dem Text), Text mit Innenabstand, Scrollleiste innen rechts (PlaceAll)
        SkinInset(chat.InsetFrame)
        local fill = Tex(chat, "BACKGROUND", -8, BOX)
        fill:SetAllPoints(chat)
        Border(chat)
        SkinScrollBar(chat.ScrollBar)
    end
    SkinButton(_G.JumpToUnreadButton)
    -- Blizzards Grafik ist 32 hoch mit viel Luft; sichtbares Feld wie bei Blizzard etwa 22 hoch
    SkinEditBox(f.ChatEditBox, { -4, -5, 4, 5 }, BOX)
end

local function SkinMemberList(members)
    if type(members) ~= "table" then return end
    local inset = members.InsetFrame
    if type(inset) == "table" then
        -- Kasten nur neben dem Chat (wie im eigenen Fenster); auf der Mitgliederseite ohne Fläche
        SkinInset(inset)
        local fill = Tex(members, "BACKGROUND", -8, BOX)
        fill:SetAllPoints(inset)
        memberDeco.fill = fill
        memberDeco.edges = Border(inset)
    end
    SkinScrollBar(members.ScrollBar)
    SkinCheck(members.ShowOfflineButton)
    -- Lage je Ansicht (Chat/Mitglieder) setzt PlaceAll; Blizzard setzt sie hier neu
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

local TAB_SIZE, TAB_STEP = 40, 46 -- wie die Reiter der mUI-Fenster (Berufe, Zauberbuch)

-- Reiter wie bei den mUI-Fenstern: 40 groß, 6 px vom Fenster, untereinander ohne Lücken für
-- versteckte Reiter (Benny 2026-11-08). Blizzard setzt die Punkte in UpdateCommunitiesTabs neu –
-- danach ordnen wir wieder. Die Reiter sind nicht geschützt.
local function LayoutTabs(f)
    if InCombatLockdown() then return end
    local slot = 0
    for _, key in ipairs(SIDE_TABS) do
        local tab = f[key]
        if type(tab) == "table" and tab.SetPoint then
            tab:SetSize(TAB_SIZE, TAB_SIZE)
            if tab.Icon then
                -- Symbol füllt den ganzen Kasten (die 1-px-Kante liegt darüber) – kein Spalt
                tab.Icon:ClearAllPoints()
                tab.Icon:SetAllPoints(tab)
            end
            if tab:IsShown() then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 4, -60 - slot * TAB_STEP) -- wie im eigenen Fenster
                slot = slot + 1
            end
        end
    end
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

-- Ruf-Leiste der Gilde: Blizzards Rahmen weg, flache Leiste in Surf Green
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

-- Text-Link-Knopf („[Zum Bearbeiten anklicken]“) als Symbol wie bei den mUI-Fenstern: Text unsichtbar,
-- Knopf 20 × 20, Symbol mittig, Erklärung im Tooltip. Klick bleibt Blizzards.
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

-- Bevorzugte Spieleinstellungen (Sprache, Standort): Dropdowns und „Übernehmen“ wie überall
-- Überschrift eines Bereichs wie im eigenen Fenster: Surf Green, 12, fett
local function SectionTitle(fs)
    if not fs then return end
    own[fs] = true
    fs:SetFont(ns.FontFor("bold"), ns.FontPx(12), "")
    fs:SetTextColor(unpack(ns.UI.ACCENT))
end

-- unbenannte Schrift eines Rahmens anhand ihres Texts finden
local function FindText(frame, text)
    if type(frame) ~= "table" or not frame.GetRegions or not text then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= frame.TitleText and region.IsObjectType and region:IsObjectType("FontString")
            and region:GetText() == text then return region end
    end
end

-- dunkler Kasten mit Rand (optional Surf-Green-Streifen links) – nur Optik
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

-- Bevorzugte Spieleinstellungen (Sprache, Standort): wie im eigenen Fenster
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
    if type(frame) ~= "table" or InCombatLockdown() then return end
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

-- Info-Seite wie im eigenen Fenster: zwei Hälften (12 px Abstand); links „Nachricht des Tages“ (Kasten
-- mit Surf-Green-Streifen) und unten „Gildeninformation“ (Kasten 150 hoch), rechts „Gildenneuigkeiten“;
-- Bearbeiten/Filter als 22-px-Symbolknöpfe rechts neben der Überschrift.
local infoParts = {}
local LayoutDetails -- unten definiert
local function SkinDetails(details)
    if type(details) ~= "table" then return end
    for _, key in ipairs(INSET_BORDERS) do Fade(details[key]) end
    local info, news = details.Info, details.News
    if type(info) ~= "table" or type(news) ~= "table" then return end
    FadeRegions(info) -- Pergament, Kopfbalken, Trennbalken
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
    -- Blizzard setzt beim Anzeigen (ohne Herausforderungen) Text und Stift neu an den alten Platz –
    -- danach wieder unser Layout
    if CommunitiesGuildInfoFrame_HideChallenges then
        hooksecurefunc("CommunitiesGuildInfoFrame_HideChallenges", function(self)
            if self == info then LayoutDetails(details) end
        end)
    end
end

LayoutDetails = function(details)
    if type(details) ~= "table" or InCombatLockdown() or not infoParts.motdBox then return end
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
    -- Nachricht des Tages
    if infoParts.motdLabel then
        infoParts.motdLabel:ClearAllPoints()
        infoParts.motdLabel:SetPoint("LEFT", info, "TOPLEFT", 0, -11)
    end
    if info.EditMOTDButton then
        info.EditMOTDButton:ClearAllPoints()
        info.EditMOTDButton:SetPoint("TOPRIGHT", info, "TOPRIGHT", 0, 0)
    end
    -- unsichtbarer Kopfbalken: Blizzard hängt Text und Stift daran – so gesetzt, dass beides passt
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
            -- SimpleHTML bricht erst beim nächsten Text neu um
            motd.MOTD:SetWidth(half - 24)
            if C_GuildInfo and C_GuildInfo.GetMOTD then motd.MOTD:SetText(C_GuildInfo.GetMOTD() or "", true) end
        end
    end
    -- Gildeninformation
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
    -- Gildenneuigkeiten
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
        -- Blizzard hängt die Liste an die Unterkante dieses (unsichtbaren) Balkens
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
    FadeRegions(border) -- Dialog-Rand (NineSlice) und dunkler Hintergrund
    Panel(detail, type(border) == "table" and border or nil)
    SkinIconButton(detail.CloseButton, "Close")
    SkinButton(detail.RemoveButton)
    SkinButton(detail.GroupInviteButton)
    SkinDropdown(detail.RankDropdown)
    SkinBackdropBox(detail.NoteBackground, 0.8)
    SkinBackdropBox(detail.OfficerNoteBackground, 0.8)
end

-- alte Dialog-Vorlage (Gildenlog, Text bearbeiten, News-Filter): Ecken-Rahmen weg, mUI-Popup
local function SkinOldDialog(frame)
    if type(frame) ~= "table" or not frame.GetRegions or not Once(frame) then return end
    FadeRegions(frame)
    Panel(frame)
    -- zwei Knöpfe können „Close“ heißen: das X oben (ohne Text) und der Text-Knopf unten
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("CheckButton") then -- vor „Button“ prüfen: CheckButton ist auch ein Button
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

-- Start ---------------------------------------------------------------------------------------------

-- jeder Bereich für sich: fehlt etwas in Forever oder ändert Blizzard etwas, bleibt der Rest bemalt
-- Wie das eigene mUI-Gildenfenster (Benny 2026-11-08: „so wie das eigene Fenster“) -------------
-- Kopf: rundes Porträt weg, Titel links „Gildenname · Gilde & Communitys“ in mUI Bold; Chat in
-- mUI-Schrift; Blizzards gelbe/grüne Schrift in mUI-Farben (Klassenfarben bleiben unangetastet).
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
-- Blizzards kleine Schriften (10–12 px) im großen Fenster einen Tick größer (Benny 2026-11-08);
-- Überschriften (ab 13 px) bleiben. Blizzard setzt Schriftobjekte teils neu – dann erneut.
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
    -- Porträt und Blizzards Titel aus, eigener Titel links
    if f.PortraitOverlay then f.PortraitOverlay:SetAlpha(0) end
    if f.PortraitContainer then f.PortraitContainer:SetAlpha(0) end
    local title = f.TitleContainer and f.TitleContainer.TitleText
    if title then title:SetAlpha(0) end
    -- Kopf wie die mUI-Fenster (Benny 2026-11-08, Vorlage Berufe): Wappen 46 px links, Name (fett 16)
    -- und „Gilde & Communitys“ darunter; rechts X/Minimieren, daneben das Mikrofon, darunter die
    -- Online-Zahl. Inhalte beginnen unter dem Kopf.
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
        -- wie im eigenen Fenster: „Gilde & Communitys · 11 von 24 online“
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
                crest:SetTexture(nil) -- Community-Symbol setzen ist geschützt
            end
        end
    end
    local function HeaderLayout()
        if InCombatLockdown() then return end
        local close, maxMin = f.CloseButton, f.MaximizeMinimizeFrame
        if close then
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(HEAD_PAD - 4), -(HEAD_PAD - 4))
        end
        if PlaceAll then PlaceAll(f) end
    end
    f:HookScript("OnSizeChanged", HeaderLayout)
    f:HookScript("OnShow", function() HeaderLayout() C_Timer.After(0, HeaderLayout) end)
    HeaderLayout()
    -- Chat in mUI-Schrift
    local messages = f.Chat and f.Chat.MessageFrame
    local function ChatFont()
        -- wie der mUI-Chat (Einstellung Chat-Schriftgröße)
        local size = ns.ChatFontSize and ns.ChatFontSize() or 13
        if messages and messages.SetFont then messages:SetFont(ns.FontFor("text"), ns.FontPx(size), "") end
    end
    local elapsed = 0
    f:HookScript("OnShow", function()
        UpdateTitle()
        ChatFont()
        RecolorTree(f, 0)
    end)
    -- Club-Wechsel, neue Zeilen (Mitglieder, Einträge): leicht nachziehen, nur solange offen
    f:HookScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.5 then return end
        elapsed = 0
        UpdateTitle()
        RecolorTree(f, 0)
    end)
    if f:IsShown() then UpdateTitle() ChatFont() RecolorTree(f, 0) end
end

-- Gesamt-Layout nach dem Zielbild (eigenes Gildenfenster). Läuft bei Größe/Anzeigen/Ansichtswechsel;
-- setzt nur Punkte/Größen an Blizzards Rahmen.
local function FooterButton(f, button)
    if not button then return end
    local label = button.GetFontString and button:GetFontString()
    local textWidth = label and label:GetUnboundedStringWidth() or 0
    button:SetSize(math.max(150, textWidth + 28), 28)
end

PlaceAll = function(f)
    if type(f) ~= "table" or InCombatLockdown() then return end
    local list, members, chat = f.CommunitiesList, f.MemberList, f.Chat
    -- Community-Liste: erste Karte (Blizzard: 40 px Rand oben + 8 px Kartenrand) auf Inhaltshöhe
    if list then
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(CONTENT_TOP - LIST_TOP_PAD - CARD_INSET))
        list:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", PAD + LIST_W, CONTENT_BOTTOM)
    end
    -- Mitgliederliste: neben dem Chat 180 breit, auf der Mitgliederseite unter Kopfzeile + Spalten
    if members then
        members:ClearAllPoints()
        if members.expandedDisplay then
            members:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -(CONTENT_TOP + 64))
        else
            members:SetPoint("TOPLEFT", f, "TOPRIGHT", -(PAD + MEMBER_W), -(CONTENT_TOP + 36))
        end
        members:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, CONTENT_BOTTOM)
        -- Liste und Scrollleiste innen (wie im eigenen Fenster), Kasten = Listenfläche
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
        local count = members.MemberCount
        if count then
            count:ClearAllPoints()
            count:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(CONTENT_TOP + 8))
            count:SetJustifyH("RIGHT")
        end
        for _, key in ipairs({ "GuildMemberListDropdown", "CommunityMemberListDropdown" }) do
            local dropdown = f[key]
            if dropdown and offline then
                dropdown:ClearAllPoints()
                dropdown:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
                dropdown:SetPoint("TOP", offline, "TOP", 0, 0)
            end
        end
    end
    -- Kanal-Dropdown oben links im Inhalt, Mikrofon links neben der Online-Zahl
    local stream = f.StreamDropdown
    if stream then
        stream:ClearAllPoints()
        stream:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -CONTENT_TOP) -- Fläche füllt den ganzen Knopf
        stream:SetSize(220, 28)
    end
    local headset = f.VoiceChatHeadset
    if headset and members and members.MemberCount then
        headset:ClearAllPoints()
        headset:SetPoint("RIGHT", members.MemberCount, "LEFT", -6, 0)
    end
    -- Chat-Kasten und Eingabefeld darunter (8 px Luft, Feld 28 hoch auf der Fußlinie)
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
    -- Bereiche Info / Vorteile / Spieleinstellungen
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
    -- Fußknöpfe unten rechts, 28 hoch, mindestens 150 breit
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

-- Gilden-Unterfenster (Ränge, Log, Texte bearbeiten, Neuigkeitenfilter, Rekrutierung): Blizzard meldet
-- sie alle als „linke“ Fenster an – unser Gildenfenster wich dann nach rechts oben aus (Benny
-- 2026-11-08). Alle aus der Fensterverwaltung nehmen und über unsere Anordnung rechts daneben öffnen.
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
            panel:HookScript("OnShow", function(self)
                C_Timer.After(0, function()
                    if self:IsShown() and not InCombatLockdown() and ns.ResetWindowPosition then
                        ns.ResetWindowPosition(self, "guildsub", true)
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
