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

local SIDE_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }

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
local function SkinIconButton(button, iconName)
    if type(button) ~= "table" or not button.IsObjectType or not button:IsObjectType("Button") then return end
    if not Once(button) then return end
    local UI = ns.UI
    FadeButtonTextures(button)
    FadeRegions(button)
    local bg = Tex(button, "BACKGROUND", -8, UI.FIELD)
    bg:SetPoint("TOPLEFT", 4, -4)
    bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Edges(button, bg)
    local icon = UI.Icon(button, iconName, 12)
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
local function SkinEditBox(box, inset)
    if type(box) ~= "table" or not box.IsObjectType or not box:IsObjectType("EditBox") then return end
    if not Once(box) then return end
    local UI = ns.UI
    local left, right = box.Left, box.Right
    for _, key in ipairs({ "Left", "Middle", "Mid", "Right" }) do Fade(box[key]) end
    Fade(box.NineSlice)
    local bg = Tex(box, "BACKGROUND", -8, INPUT)
    if inset then
        bg:SetPoint("TOPLEFT", box, "TOPLEFT", inset[1], inset[2])
        bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", inset[3], inset[4])
    elseif IsTexture(left) and IsTexture(right) then
        bg:SetPoint("TOPLEFT", left, "TOPLEFT")
        bg:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT")
    else
        bg:SetAllPoints()
    end
    local edges = Edges(box, bg)
    box:HookScript("OnEditFocusGained", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end)
    box:HookScript("OnEditFocusLost", function()
        for _, edge in ipairs(edges) do edge:SetVertexColor(0, 0, 0, 1) end
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
local function SkinListEntry(entry)
    if not Once(entry) then return end
    local UI = ns.UI
    Fade(entry.Background)
    Fade(entry.Selection)
    Fade(entry:GetHighlightTexture())
    local card = Tex(entry, "BACKGROUND", -8, UI.FIELD)
    card:SetPoint("TOPLEFT", 4, -3)
    card:SetPoint("BOTTOMRIGHT", -4, 3)
    Edges(entry, card)
    local selected = Tex(entry, "BACKGROUND", -7, { UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.1 })
    selected:SetAllPoints(card)
    local marker = Tex(entry, "OVERLAY", 7, UI.ACCENT)
    marker:SetPoint("TOPLEFT", card, "TOPLEFT")
    marker:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT")
    marker:SetWidth(2)
    local hover = Tex(entry, "HIGHLIGHT", 0, { 1, 1, 1, 0.05 })
    hover:SetAllPoints(card)
    -- „Community beitreten oder gründen“: grelles Grün-Plus in Salbei (Benny 2026-11-08)
    local icon = entry.Icon
    if IsTexture(icon) then
        local function Tint()
            local plus = icon:GetAtlas() == "communities-icon-addgroupplus"
            icon:SetDesaturated(plus)
            if plus then icon:SetVertexColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3]) else icon:SetVertexColor(1, 1, 1) end
        end
        hooksecurefunc(icon, "SetAtlas", Tint)
        Tint()
    end
    local selection = entry.Selection
    local function Sync()
        local on = IsTexture(selection) and selection:IsShown() or false
        selected:SetShown(on)
        marker:SetShown(on)
    end
    if IsTexture(selection) then
        hooksecurefunc(selection, "Show", Sync)
        hooksecurefunc(selection, "Hide", Sync)
        hooksecurefunc(selection, "SetShown", Sync)
    end
    Sync()
end

-- Namensspalte der Mitgliederliste breiter, Notiz dafür schmaler (Benny 2026-11-08: Namen wurden
-- abgeschnitten). Zone, Rang und Notiz hängen an der Namensspalte und rücken mit; die Notiz füllt den
-- Rest. Nur Breiten, Blizzards Daten/Skripte bleiben unberührt.
local NAME_EXTRA = 40
local function WidenName(row)
    if not (row.expanded and row.Class and row.Class:IsShown()) then return end
    local frame = row.NameFrame
    if type(frame) ~= "table" or not frame.Name then return end
    frame:SetWidth(frame:GetWidth() + NAME_EXTRA)
    local name = frame.Name
    name:SetWidth(name:GetWidth() + NAME_EXTRA)
    local rank = frame.RankIcon
    if rank then
        local offset = frame.PresenceIcon and frame.PresenceIcon:IsShown() and frame.PresenceIcon:GetWidth() or 0
        rank:ClearAllPoints()
        rank:SetPoint("LEFT", frame, "LEFT", (name:IsTruncated() and name:GetWidth() or name:GetStringWidth()) + offset, 0)
    end
end

-- Zeile der Mitgliederliste: Blizzards Streifen und blauer Hover weg, flache Zeile, Hover in Surf Green
local function SkinMemberRow(row)
    if not Once(row) then return end
    local UI = ns.UI
    Fade(row:GetNormalTexture())
    Fade(row:GetHighlightTexture())
    local bg = Tex(row, "BACKGROUND", -8, { UI.FIELD[1], UI.FIELD[2], UI.FIELD[3], 0.6 })
    bg:SetPoint("TOPLEFT")
    bg:SetPoint("BOTTOMRIGHT", 0, 1)
    local hover = Tex(row, "HIGHLIGHT", 0, { UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.12 })
    hover:SetAllPoints(bg)
    if row.UpdateNameFrame then hooksecurefunc(row, "UpdateNameFrame", WidenName) end
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
        if column:IsObjectType("Button") and column:IsShown() and column:GetID() == 3
            and column:GetText() == COMMUNITIES_ROSTER_COLUMN_TITLE_NAME then
            column:SetWidth(100 + NAME_EXTRA)
        end
        if column:IsObjectType("Button") and Once(column) then
            for _, key in ipairs({ "Left", "Middle", "Right" }) do Fade(column[key]) end
            Fade(column:GetHighlightTexture())
            local bg = Tex(column, "BACKGROUND", -8, UI.FIELD)
            bg:SetPoint("TOPLEFT", 1, -1)
            bg:SetPoint("BOTTOMRIGHT", -1, 1)
            Edges(column, bg)
            local hover = Tex(column, "HIGHLIGHT", 0, { 1, 1, 1, 0.06 })
            hover:SetAllPoints(bg)
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
    tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
    SkinIconButton(f.CloseButton, "Close")
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
    -- gleich hoch wie die mUI-Fenster (Benny 2026-11-08): Maßstab = Standardhöhe / eigene Höhe, so
    -- treffen Ober- und Unterkante die Nachbarfenster. Blizzards Mini-Modus (sehr niedrig) bleibt 1.
    local function FitScale(self)
        local height = self:GetHeight()
        if not height or InCombatLockdown() then return end
        local scale = height < 400 and 1 or math.max(1, math.min(1.5, (ns.NPC_HEIGHT or 640) / height))
        if math.abs(self:GetScale() - scale) > 0.001 then self:SetScale(scale) end
    end
    f:HookScript("OnSizeChanged", function(self)
        FitScale(self)
        if self:IsShown() and not InCombatLockdown() and ns.ResetWindowPosition then
            ns.ResetWindowPosition(self, "guild")
        end
    end)
    FitScale(f)
    f:HookScript("OnShow", function(self)
        FitScale(self)
        C_Timer.After(0, function()
            if self:IsShown() and not InCombatLockdown() and ns.ResetWindowPosition then
                ns.ResetWindowPosition(self, "guild", true)
            end
        end)
    end)
    if f.CloseButton and not InCombatLockdown() then
        f.CloseButton:ClearAllPoints()
        f.CloseButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    end
    local maxMin = f.MaximizeMinimizeFrame
    if maxMin then
        SkinIconButton(maxMin.MaximizeButton, "Square")
        SkinIconButton(maxMin.MinimizeButton, "Minus")
    end
    SkinInset(f.Inset)
end

local function SkinCommunitiesList(list)
    if type(list) ~= "table" then return end
    -- Artwork der Spalte weg, flache dunkle Fläche
    for _, key in ipairs({ "Bg", "TopFiligree", "BottomFiligree" }) do Fade(list[key]) end
    FadeRegions(list.FilligreeOverlay)
    local fill = Tex(list, "BACKGROUND", -8, { 0, 0, 0, 0.35 })
    fill:SetAllPoints(type(list.InsetFrame) == "table" and list.InsetFrame or list)
    SkinInset(list.InsetFrame, true) -- liegt über den Einträgen: nur Rand, keine Fläche
    SkinScrollBar(list.ScrollBar)
    HookScrollBox(list.ScrollBox, SkinListEntry)
end

local function SkinChat(f)
    local chat = f.Chat
    if type(chat) == "table" then
        SkinInset(chat.InsetFrame, true, { 0, 0, 0, 0.35 })
        SkinScrollBar(chat.ScrollBar)
    end
    SkinButton(_G.JumpToUnreadButton)
    -- Blizzards Grafik ist 32 hoch mit viel Luft; sichtbares Feld wie bei Blizzard etwa 22 hoch
    SkinEditBox(f.ChatEditBox, { -4, -5, 4, 5 })
end

local function SkinMemberList(members)
    if type(members) ~= "table" then return end
    local inset = members.InsetFrame
    if type(inset) == "table" then
        -- der Kasten liegt über den Zeilen (Ebene 100): Rand am Kasten, Fläche an der Liste darunter
        SkinInset(inset, true)
        local fill = Tex(members, "BACKGROUND", -8, { 0, 0, 0, 0.35 })
        fill:SetAllPoints(inset)
    end
    SkinScrollBar(members.ScrollBar)
    SkinCheck(members.ShowOfflineButton)
    local display = members.ColumnDisplay
    if type(display) == "table" then
        for _, key in ipairs({ "Background", "TopTileStreaks", "InsetBorderTopLeft", "InsetBorderTopRight",
            "InsetBorderBottomLeft", "InsetBorderTop", "InsetBorderLeft" }) do
            Fade(display[key])
        end
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
            if tab.Icon then tab.Icon:SetSize(TAB_SIZE - 4, TAB_SIZE - 4) end
            if tab:IsShown() then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, -60 - slot * TAB_STEP)
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

-- Bevorzugte Spieleinstellungen (Sprache, Standort): Dropdowns und „Übernehmen“ wie überall
local function SkinPreferredPlay(frame)
    if type(frame) ~= "table" then return end
    SkinDropdown(frame.LocaleDropdown)
    SkinDropdown(frame.DatacenterDropdown)
    SkinButton(frame.LocaleApplyButton)
    SkinButton(frame.DatacenterApplyButton)
end

local function SkinDetails(details)
    if type(details) ~= "table" then return end
    for _, key in ipairs(INSET_BORDERS) do Fade(details[key]) end
    local info, news = details.Info, details.News
    if type(info) == "table" then
        FadeRegions(info) -- Pergament, Kopfzeilen, Trennbalken
        Fill(info)
        for _, key in ipairs({ "MOTDScrollFrame", "DetailsFrame" }) do
            local scroll = info[key]
            if type(scroll) == "table" then SkinScrollBar(scroll.ScrollBar) end
        end
    end
    if type(news) == "table" then
        FadeRegions(news)
        Fill(news)
        SkinScrollBar(news.ScrollBar)
        HookScrollBox(news.ScrollBox, FlatRow)
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
local function RecolorTree(frame, depth)
    if depth > 12 or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") and not own[region] then
            if not recolored[region] then
                recolored[region] = true
                hooksecurefunc(region, "SetTextColor", Recolor)
            end
            Recolor(region)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do RecolorTree(child, depth + 1) end
end

local function SkinLikeOwnWindow(f)
    local UI = ns.UI
    -- Porträt und Blizzards Titel aus, eigener Titel links
    if f.PortraitOverlay then f.PortraitOverlay:SetAlpha(0) end
    if f.PortraitContainer then f.PortraitContainer:SetAlpha(0) end
    local title = f.TitleContainer and f.TitleContainer.TitleText
    if title then title:SetAlpha(0) end
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", 14, -9)
    head:SetPoint("RIGHT", f, "RIGHT", -80, 0)
    head:SetHeight(18)
    local name = head:CreateFontString(nil, "OVERLAY")
    own[name] = true
    name:SetFont(ns.FontFor("bold"), ns.FontPx(15), "")
    name:SetTextColor(unpack(UI.TEXT))
    name:SetPoint("LEFT")
    local sub = head:CreateFontString(nil, "OVERLAY")
    own[sub] = true
    sub:SetFont(ns.FontFor(), ns.FontPx(12), "")
    sub:SetTextColor(unpack(UI.MUTED))
    sub:SetPoint("LEFT", name, "RIGHT", 10, -1)
    local function UpdateTitle()
        local id = f.GetSelectedClubId and f:GetSelectedClubId()
        local info = id and C_Club.GetClubInfo(id)
        name:SetText(info and info.name or (title and title:GetText()) or "")
        sub:SetText(title and title:GetText() or "")
    end
    -- Chat in mUI-Schrift
    local messages = f.Chat and f.Chat.MessageFrame
    local function ChatFont()
        if messages and messages.SetFont then messages:SetFont(ns.FontFor("text"), ns.FontPx(13), "") end
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
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_Communities" then Apply() end
end)

ns:On("PLAYER_LOGIN", function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Communities") then Apply() end
end)
