-- MeredanUI-Optik: flache, dunkle Flächen mit 1-px-Rahmen. Farben kommen aus dem Theme
-- (Klassenfarbe, Dunkel, Klassisch grün), Schrift und Balken-Textur aus LibSharedMedia.
local ADDON_NAME, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

ns.STYLE = {
    font = STANDARD_TEXT_FONT,
    fontSize = 11,
    barTexture = WHITE,
    panelColor = { 0.06, 0.06, 0.06, 0.9 },
    bgMultiplier = 0.25, -- leerer Teil = Balkenfarbe × Faktor (Theme „Klassisch grün“)
    castColor = { 0.85, 0.65, 0.2 },              -- eigene Zauber
    castInterruptibleColor = { 0.25, 0.8, 0.95 }, -- Ziel: unterbrechbar (türkis)
    castLockedColor = { 0.5, 0.5, 0.5 },          -- Ziel: nicht unterbrechbar (grau)
    castLatencyColor = { 0.9, 0.2, 0.2, 0.6 },    -- Spieler: Latenz am Ende der Zauberleiste
    -- Status-Symbole (weiß angelegt, hier eingefärbt)
    combatColor = { 0.95, 0.3, 0.25 },     -- Kampf
    restingColor = { 0.55, 0.78, 1 },      -- Ausruhen
    deadColor = { 0.9, 0.9, 0.9 },         -- Tot
    ghostColor = { 0.7, 0.85, 1 },         -- Geist
    resurrectColor = { 0.35, 1, 0.45 },    -- Wiederbelebung kommt
    questColor = { 1, 0.82, 0.1 },         -- Quest-Gegner
    phaseColor = { 0.85, 0.85, 0.85 },     -- andere Phase
    offlineColor = { 0.6, 0.6, 0.6 },      -- Offline (Gruppenframes)
    afkColor = { 0.75, 0.75, 0.75 },       -- AFK (Gruppenframes)
    leaderColor = { 1, 1, 1 },             -- Gruppenleiter (Krone; weiß mit Schatten liest sich auf jeder Klassenfarbe)
    assistantColor = { 0.9, 0.9, 0.9 },    -- Assistent (Krone, Umriss)
    readyColors = {                        -- Bereitschaftscheck: bereit / nicht bereit / wartet
        ready = { 0.35, 1, 0.45 }, notready = { 1, 0.3, 0.25 }, waiting = { 0.85, 0.85, 0.85 },
    },
    summonColors = {                       -- Beschwörung: wartet / angenommen / abgelehnt
        { 0.75, 0.5, 1 }, { 0.35, 1, 0.45 }, { 1, 0.3, 0.25 },
    },
}
local STYLE = ns.STYLE

-- Themes: nur Farben.
--   classHealth: Lebensbalken von Spielern in Klassenfarbe (NPCs nach Gesinnung)
--   emptyColor:  leerer Teil der Balken neutral statt abgedunkelte Balkenfarbe
--   darkHealth:  Lebensbalken dunkel gefüllt, fehlendes Leben etwas heller (healthEmpty)
--   powerClassColor: Ressource von Spielern in Klassenfarbe
ns.THEMES = {
    class = {
        name = L["Class colour"],
        panelColor = { 0.06, 0.06, 0.06, 0.9 },
        healthColor = { 111 / 255, 181 / 255, 154 / 255 }, -- Surf-Palette (Benny 2026-11-07)
        classHealth = true,
        emptyColor = { 0.1, 0.1, 0.1 },
    },
    dark = {
        name = L["Dark"],
        panelColor = { 0.02, 0.02, 0.02, 0.95 },
        healthColor = { 111 / 255, 181 / 255, 154 / 255 }, -- Surf-Palette (Benny 2026-11-07)
        emptyColor = { 0.12, 0.12, 0.12 },
        darkHealth = { 0.1, 0.1, 0.1 },
        healthEmpty = { 0.3, 0.3, 0.3 },
        powerClassColor = true,
    },
    green = {
        name = L["Classic green"],
        panelColor = { 0.06, 0.06, 0.06, 0.9 },
        healthColor = { 111 / 255, 181 / 255, 154 / 255 }, -- Surf-Palette (Benny 2026-11-07)
    },
}
ns.THEME_ORDER = { "class", "dark", "green" }

-- Balken-Textur: nur die eigene, flache (WHITE8X8). Fremde Texturen (SharedMedia/Eltruism) sind
-- raus – ungeklärte Lizenzen, CurseForge-Moderation (Benny 2026-11-08). In LibSharedMedia angemeldet.
ns.DEFAULT_TEXTURE = "MeredanUI Flat"
local STATUSBARS = {
    ["MeredanUI Flat"] = WHITE,
}
for name, file in pairs(STATUSBARS) do
    local path = file == WHITE and WHITE or "Interface\\AddOns\\MeredanUI\\Media\\Statusbar\\" .. file
    STATUSBARS[name] = path
    if LSM then LSM:Register(LSM.MediaType.STATUSBAR, name, path) end
end
ns.DEFAULT_TEXTURE_PATH = STATUSBARS[ns.DEFAULT_TEXTURE]

-- mUI-Schriften (Benny 2026-11-07): eigene Schrift auf Basis von Blue Highway (Raymond Larabie,
-- CC0 – frei verwendbar, umbenannt). Wie bei Websites: Namen/Überschriften „mUI Bold“, Fließtext
-- (Chat, Tooltips) „mUI Text“ mit +1 % Zeichenabstand, alles andere „mUI“. Gebaut mit fontTools
-- aus _fonts/bluehighway (Skript im Workspace). Auch für andere Addons in LibSharedMedia angemeldet.
ns.DEFAULT_FONT_NAME = "mUI"
ns.MEDIA = "Interface\\AddOns\\MeredanUI\\Media\\"
ns.DEFAULT_FONT = ns.MEDIA .. "Fonts\\mUI.ttf"
ns.TEXT_FONT = ns.MEDIA .. "Fonts\\mUI-Text.ttf"
ns.BOLD_FONT = ns.MEDIA .. "Fonts\\mUI-Bold.ttf"
ns.DISPLAY_FONT = ns.MEDIA .. "Cinzel-Bold.ttf" -- Schmuckschrift: Logo, große Überschriften (nur Großbuchstaben-Stil)
if LSM then
    LSM:Register(LSM.MediaType.FONT, "mUI", ns.DEFAULT_FONT)
    LSM:Register(LSM.MediaType.FONT, "mUI Text", ns.TEXT_FONT)
    LSM:Register(LSM.MediaType.FONT, "mUI Bold", ns.BOLD_FONT)
end

-- Rahmen: eine schwarze 1-px-Linie. Debuffs färben sie nach Dispel-Art (dann 2 px).
ns.BORDER_PIXELS = 1
local BORDER_COLOR = { 0, 0, 0, 1 }

-- Alles, was Theme, Schrift oder Textur nutzt, damit Änderungen sofort greifen.
local registry = { texts = {}, bars = {}, panels = {} }

-- Gespeicherte Einstellungen (Theme, Schrift, Textur) in STYLE übernehmen.
function ns.ApplySettings()
    local db = ns.db
    local theme = ns.THEMES[db.theme] or ns.THEMES.class
    STYLE.panelColor = theme.panelColor
    STYLE.classHealth = theme.classHealth
    STYLE.emptyColor = theme.emptyColor
    STYLE.darkHealth = theme.darkHealth
    STYLE.healthEmpty = theme.healthEmpty
    STYLE.powerClassColor = theme.powerClassColor
    ns.HEALTH_COLOR = theme.healthColor

    -- Schrift und Textur sind fest (Einstellungen verschlankt, Benny 2026-11-07)
    STYLE.font = ns.DEFAULT_FONT
    STYLE.textFont = ns.TEXT_FONT
    STYLE.boldFont = ns.BOLD_FONT
    STYLE.barTexture = ns.DEFAULT_TEXTURE_PATH
end

-- Geänderte Einstellungen sofort auf alle bestehenden Teile anwenden. Die Balkenfarben
-- rechnet danach oUF neu (ns.OnStyleRefreshed in UnitFrames/UnitFrames.lua).
function ns.RefreshStyle()
    ns.ApplySettings()
    for text, font in pairs(registry.texts) do text:SetFont(ns.FontFor(font[3]), ns.FontPx(font[1]), font[2]) end
    for _, bg in ipairs(registry.panels) do bg:SetColorTexture(unpack(STYLE.panelColor)) end
    for _, bar in ipairs(registry.bars) do
        bar:SetStatusBarTexture(STYLE.barTexture)
        bar.bg:SetTexture(STYLE.barTexture)
        if bar.baseColor then bar:SetStatusBarColor(unpack(bar.baseColor)) end
        if bar.panelBackground then
            local r, g, b = unpack(STYLE.panelColor)
            bar.bg:SetVertexColor(r, g, b, 1)
        elseif bar.PostUpdateColor or bar.followsTheme then
            ns.ColorBarBackground(bar)
        end
    end
    if ns.OnStyleRefreshed then ns.OnStyleRefreshed() end
end

-- Größe eines echten Bildschirmpixels in UI-Einheiten. Rahmen und Abstände
-- darin rechnen, sonst rundet WoW sie je nach Position auf 1 oder 2 Pixel.
function ns.PixelSize()
    return PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
end

-- Punkt eines Frames setzen, Position relativ zur Bildschirmmitte. Verankert an der
-- linken unteren Ecke und auf ganze Pixel gerundet: Die Mitte liegt je nach Auflösung
-- auf einem halben Pixel, 1-px-Linien würden dort 0 oder 2 px dick.
-- Mindestabstand aller Elemente zum Bildschirmrand, rundum (Ausnahme später: die
-- schmale Info-Leiste unter den Aktionsleisten).
ns.SCREEN_MARGIN = 25

-- Benannte Layout-Elemente (bar1 … bar5, minimap, questlog, classpower …), damit Module
-- sich aneinander ausrichten können. Verschieben gibt es nicht: Plätze kommen nur aus dem Layout.
ns.layoutFrames = {}

function ns.PlaceFromCenter(frame, point, x, y)
    local px = ns.PixelSize()
    local cx, cy = UIParent:GetCenter()
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, "BOTTOMLEFT",
        math.floor((cx + x) / px + 0.5) * px, math.floor((cy + y) / px + 0.5) * px)
end

-- Wert auf ganze Bildschirmpixel runden (mindestens 1 Pixel).
function ns.Snap(value)
    local px = ns.PixelSize()
    return math.max(math.floor(value / px + 0.5), 1) * px
end

-- Sichtbarkeit nach Einstellung (Fortschrittsleisten; die Aktionsleisten nutzen sichere
-- Zustandstreiber): "always", "mouseover", "combat", "nocombat", "hidden". Ältere
-- Einstellungen mit true/false werden als „immer“/„aus“ gelesen.
function ns.VisibilityMode(value)
    if value == true or value == nil then return "always" end
    if value == false then return "hidden" end
    if value == "combat" or value == "nocombat" then return "always" end -- alte Kampf-Varianten (bis 2026-11-07)
    return value
end

-- Belegt die Leiste gerade Platz? (Mouseover zählt mit, sonst ließe sie sich nicht finden)
function ns.ShownByMode(value)
    local mode = ns.VisibilityMode(value)
    return mode ~= "hidden"
end

-- Eigenes Feld über einem Blizzard-Knopf, dessen Optik per Alpha 0 versteckt ist (Mikromenü,
-- Minimap-Knöpfe). Das Feld hängt NICHT am Knopf (sonst erbt es dessen Alpha 0), sondern an einer
-- eigenen Ebene unter UIParent – so blendet es mit dem ganzen UI aus (AFK-Bildschirm, RP-Modus),
-- liegt aber über dem Knopf und folgt dessen Sichtbarkeit.
local overlayRoot
function ns.CreateButtonOverlay(button)
    if not overlayRoot then
        overlayRoot = CreateFrame("Frame", nil, UIParent)
        overlayRoot:SetAllPoints()
    end
    local overlay = CreateFrame("Frame", nil, overlayRoot)
    overlay:SetFrameStrata(button:GetFrameStrata())
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)
    local function Follow()
        overlay:SetScale(button:GetEffectiveScale() / UIParent:GetEffectiveScale())
        overlay:SetShown(button:IsVisible())
    end
    button:HookScript("OnShow", Follow)
    button:HookScript("OnHide", Follow)
    Follow()
    return overlay
end

-- Mouseover-Ausblenden für einfache Frames: frame.muiMouseover = true > Alpha 0 bis Hover
local mouseoverFrames = {}
function ns.RegisterMouseover(frame)
    mouseoverFrames[frame] = true
end
-- Maus über frame – aber nicht, wenn ein anderes Fenster davor die Maus hat (z. B. das
-- Taschenfenster über der Addon-Leiste); IsMouseOver prüft nur die Fläche.
local function Hovered(frame)
    if not (frame:IsVisible() and frame:IsMouseOver(4, -4, -4, 4)) then return false end
    local focus = GetMouseFoci()[1]
    if not focus or focus == WorldFrame then return true end -- Lücke zwischen den Knöpfen
    while focus do
        if focus == frame then return true end
        if focus:IsForbidden() then return false end -- abgeschirmt: gehört nicht zu uns
        focus = focus:GetParent()
    end
    return false
end
C_Timer.NewTicker(0.1, function()
    for frame in pairs(mouseoverFrames) do
        if frame.muiMouseover then
            frame:SetAlpha(Hovered(frame) and 1 or 0)
        elseif frame:GetAlpha() < 1 then
            frame:SetAlpha(1)
        end
    end
end)

-- Hauptaktionsleiste: Maße an einer Stelle, weil sich die Klassenleiste danach richtet
ns.MAIN_BAR = { size = 42, cols = 6, gapPixels = 6 } -- 6 px Abstand = sichtbar 4 px (Rahmen liegen außen)

-- Breite der Hauptleiste (ohne die außen liegenden Rahmen) – gleich für die Klassenleiste
function ns.MainBarWidth()
    local bar = ns.MAIN_BAR
    return bar.cols * ns.Snap(bar.size) + (bar.cols - 1) * bar.gapPixels * ns.PixelSize()
end

-- Rahmen aus vier Kanten um eine Region, thickness Pixel dick. inside = true legt ihn
-- innen auf die Kante (z. B. für dicht gesetzte Icons), sonst außen herum.
-- Kanten sind weiße Texturen mit Vertex-Farbe, damit Blizzard sie umfärben kann (Dispel-Art).
-- Gibt die vier Kanten zurück.
function ns.AddBorder(region, inside, thickness)
    local px = ns.PixelSize()
    thickness = thickness or ns.BORDER_PIXELS
    local inner = inside and -thickness or 0
    local i, o = inner * px, (inner + thickness) * px
    local layer = inside and "OVERLAY" or "BORDER"
    local function Edge()
        local tex = region:CreateTexture(nil, layer)
        tex:SetTexture(WHITE)
        tex:SetVertexColor(unpack(BORDER_COLOR))
        -- liegt der Rahmen nicht exakt auf dem Pixelraster, rundet WoW 1-px-Kanten sonst teils auf 0
        -- (fehlende Kanten im Vermächtnisfenster, Benny 2026-11-08); ohne Einrasten bleiben sie sichtbar
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        return tex
    end
    local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
    top:SetPoint("TOPLEFT", region, "TOPLEFT", -o, o)
    top:SetPoint("BOTTOMRIGHT", region, "TOPRIGHT", o, i)
    bottom:SetPoint("TOPLEFT", region, "BOTTOMLEFT", -o, -i)
    bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", o, -o)
    left:SetPoint("TOPLEFT", region, "TOPLEFT", -o, i)
    left:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", -i, -i)
    right:SetPoint("TOPLEFT", region, "TOPRIGHT", i, i)
    right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", o, -i)
    return { top, bottom, left, right }
end

-- Dunkle Fläche mit 1-px-Rahmen hinter einer Region.
function ns.CreateBackground(region)
    local bg = region:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(STYLE.panelColor))
    registry.panels[#registry.panels + 1] = bg
    ns.AddBorder(region)
    return bg
end

-- Balken gleiten weich zum neuen Wert (Blizzards eingebaute Glättung – geht auch mit geschützten
-- Werten); oUF-Elemente lesen .smoothing. Beim Einheitenwechsel springen sie sofort (SnapBars).
ns.SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut

-- Neues Ziel / neue Namensplakette: Balken nicht vom alten Wert herübergleiten lassen
local function SnapBars(frame)
    for _, key in ipairs({ "Health", "Power", "AdditionalPower", "Stagger" }) do
        local bar = frame[key]
        if bar and bar.SetToTargetValue then bar:SetToTargetValue() end
    end
end

function ns.SnapBarsOnUnitChange(frame)
    hooksecurefunc(frame, "UpdateAllElements", SnapBars)
end

-- Leichter Schimmer über region, solange die Maus auf frame liegt (Unit- und Gruppenframes).
function ns.AddHoverHighlight(frame, region, alpha)
    local highlight = region:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, alpha or 0.06)
    highlight:Hide()
    frame:HookScript("OnEnter", function() highlight:Show() end)
    frame:HookScript("OnLeave", function() highlight:Hide() end)
    return highlight
end

function ns.CreateBar(parent, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetHeight(height)
    bar.smoothing = ns.SMOOTH
    bar:SetStatusBarTexture(STYLE.barTexture)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(STYLE.barTexture)
    bg:SetVertexColor(0.1, 0.1, 0.1)
    bar.bg = bg
    bar.PostUpdateColor = ns.ColorBarBackground
    registry.bars[#registry.bars + 1] = bar
    return bar
end

-- oUF-Callback, leerer Teil eines Balkens: neutral (Theme) oder abgedunkelte Balkenfarbe.
-- Die Farbe direkt vom Balken lesen – deckt auch Sonder-Ressourcen ab, die oUF
-- ohne Farbobjekt setzt.
function ns.ColorBarBackground(bar)
    if STYLE.darkHealth and bar.isHealth then
        bar:SetStatusBarColor(unpack(STYLE.darkHealth))
        bar.bg:SetVertexColor(unpack(STYLE.healthEmpty))
        return
    end
    if STYLE.emptyColor then
        bar.bg:SetVertexColor(unpack(STYLE.emptyColor))
        return
    end
    local r, g, b = bar:GetStatusBarColor()
    if not ns.Readable(r) then return end
    local m = STYLE.bgMultiplier
    bar.bg:SetVertexColor(r * m, g * m, b * m)
end

-- oUF-Callback der Ressourcenleiste: im dunklen Theme bei Spielern in Klassenfarbe.
function ns.ColorPowerBar(bar, unit)
    if STYLE.powerClassColor and unit then
        local isPlayer = UnitIsPlayer(unit)
        if ns.Readable(isPlayer) and isPlayer then
            local _, class = UnitClass(unit)
            local color = ns.Readable(class) and ns.oUF.colors.class[class]
            if color then bar:SetStatusBarColor(color:GetRGB()) end
        end
    end
    ns.ColorBarBackground(bar)
end

-- Zu lange Namen kürzen: vordere Wörter auf den Anfangsbuchstaben („S. D. d. Ältere“), das
-- letzte bleibt ganz. Gemessen wird die echte Textbreite in der Schrift des FontStrings –
-- so passt es für jede Sprache. Ohne Leerzeichen (z. B. Chinesisch) oder wenn es dann immer
-- noch nicht passt, schneidet WoW wie gewohnt mit „…“ ab. Geschützte Namen bleiben, wie sie sind.
local UTF8_CHAR = "^[%z\1-\127\194-\244][\128-\191]*"
local nameProbe
local shortNames = {}

-- maxWidth optional: Nameplates dürfen nicht vermessen werden, dort wird die Breite mitgegeben.
function ns.ShortenName(name, fontString, maxWidth)
    if not ns.Readable(name) or name == "" then return name end
    -- Hatte das Feld schon einen geschützten Namen, ist auch seine Breite geschützt: dann nichts tun
    maxWidth = maxWidth or fontString:GetWidth()
    if not ns.Readable(maxWidth) or maxWidth <= 1 then return name end
    local font, size, flags = fontString:GetFont()
    if not font then return name end
    local key = ("%s|%s|%d|%s|%d"):format(name, font, size, flags or "", maxWidth)
    if shortNames[key] then return shortNames[key] end

    nameProbe = nameProbe or UIParent:CreateFontString(nil, "BACKGROUND")
    nameProbe:Hide()
    nameProbe:SetFont(font, size, flags)
    local function Fits(text)
        nameProbe:SetText(text)
        return nameProbe:GetUnboundedStringWidth() <= maxWidth
    end

    local result = name
    if not Fits(name) then
        local words = {}
        for word in name:gmatch("%S+") do words[#words + 1] = word end
        for i = 1, #words - 1 do
            words[i] = (words[i]:match(UTF8_CHAR) or words[i]) .. "."
            result = table.concat(words, " ")
            if Fits(result) then break end
        end
    end
    shortNames[key] = result
    return result
end

-- Hintergrund leerer Plätze (Aktionsleisten, Taschen): Blizzards Slot-Grafik, an den Rändern
-- beschnitten (deren Rundungen/Rahmen), damit sie in unseren eckigen Rahmen passt. Die Grafik
-- ist halbtransparent: deckende dunkle Fläche darunter.
local SLOT_ATLAS = "ui-hud-actionbar-iconframe-slot"
local SLOT_CROP = 0.15 -- Anteil, der rundum abgeschnitten wird
local SLOT_ALPHA = 0.4 -- nur angedeutet, das Schwarz soll bleiben

function ns.AddSlotBackground(frame)
    local base = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    base:SetAllPoints()
    base:SetColorTexture(0.04, 0.04, 0.05, 1)
    local slot = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    slot:SetAllPoints()
    slot:SetAtlas(SLOT_ATLAS)
    local ulx, uly, _, lly, urx = slot:GetTexCoord()
    local w, h = urx - ulx, lly - uly
    slot:SetTexCoord(ulx + w * SLOT_CROP, urx - w * SLOT_CROP, uly + h * SLOT_CROP, lly - h * SLOT_CROP)
    slot:SetAlpha(SLOT_ALPHA)
    return base, slot
end

-- Schrift setzen und für spätere Schriftwechsel merken.
-- Schnitt je Rolle: "bold" (Namen, Überschriften), "text" (Fließtext), sonst mUI
function ns.FontFor(role)
    if role == "bold" then return STYLE.boldFont or ns.BOLD_FONT end
    if role == "text" then return STYLE.textFont or ns.TEXT_FONT end
    return STYLE.font
end

-- Schriftgröße (Benny 2026-11-07): Stufe Klein/Mittel/Groß vergrößert alle mUI-Texte im gleichen
-- Verhältnis (Überschriften bleiben größer als Fließtext). Untergrenze: kein Text kleiner als 10
-- echte Bildschirm-Pixel – WoW-Schriftgrößen sind UI-Einheiten, auf 1080p wäre eine „10“ sonst ~9 px.
ns.FONT_SCALES = { small = 0.9, medium = 1, large = 1.12 }
local MIN_FONT_PIXELS = 10
function ns.FontPx(size)
    local factor = ns.FONT_SCALES[ns.db and ns.db.fontSize or "medium"] or 1
    local value = math.max(size * factor, MIN_FONT_PIXELS * ns.PixelSize())
    return math.floor(value * 2 + 0.5) / 2 -- halbe Schritte
end

function ns.SetFont(text, size, flags, role)
    registry.texts[text] = { size, flags or "", role }
    text:SetFont(ns.FontFor(role), ns.FontPx(size), flags or "")
end

function ns.CreateText(parent, size, justify, flags, role)
    local text = parent:CreateFontString(nil, "OVERLAY")
    ns.SetFont(text, size or STYLE.fontSize, flags, role)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(false)
    return text
end

-- Restzeit kompakt: Sekunden ohne Einheit (59), darüber 2m bzw. 1h.
-- Die Zeit ist im Kampf ein Secret, deshalb formatiert ein Blizzard-Formatter statt Lua.
local function CreateDurationFormatter()
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return end
    local UP = Enum.NumericRuleFormatRounding.Up
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    ---@diagnostic disable-next-line: undefined-field -- 12.1-API, fehlt in den Annotationen
    formatter:SetBreakpoints({
        { threshold = 0, step = 1, rounding = UP, format = "%.0f" },
        { threshold = 90, format = "%.0fm", components = { { div = 60, step = 1, rounding = UP } } },
        { threshold = 5400, format = "%.0fh", components = { { div = 3600, step = 1, rounding = UP } } },
    })
    return formatter
end
ns.DurationFormatter = CreateDurationFormatter()

-- Farben für den Aura-Rahmen nach Dispel-Art; "None" = schwarz wie der normale Rahmen.
local function DispelBorderColors(colors)
    local map = {}
    for name, color in pairs(colors.dispel) do map[name] = color end
    map.None = CreateColor(unpack(BORDER_COLOR))
    return map
end

-- oUF-Callback für neue Aura-Buttons: 1-px-Rahmen innen auf dem Icon.
-- options.dispelBand: "harmful" oder "helpful" – der Rahmen wird 2 px dick und Blizzard
-- färbt ihn nach Dispel-Art (Magie blau, Gift grün, …). Die Art ist im Kampf ein Secret,
-- deshalb färbt Blizzard und nicht wir.
-- ("preview" im Testmodus: nur die Dicke, die Farbe setzt der Testmodus.)
-- options.desaturate: Icon grau (z. B. Debuffs anderer Spieler am Ziel).
function ns.StyleAuraButton(element, button, options)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon:SetDesaturated(options and options.desaturate or false)

    local dispelBand = options and options.dispelBand
    local borderPixels = dispelBand and 2 or ns.BORDER_PIXELS
    local border = ns.AddBorder(button, true, borderPixels)
    button.FrameBorder = border

    if dispelBand and button.AddDispelTypeTexture then
        element.dispelBorderColors = element.dispelBorderColors or DispelBorderColors(element.__owner.colors)
        for _, edge in ipairs(border) do
            button:AddDispelTypeTexture(edge, {
                style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                showWhenHarmful = dispelBand == "harmful",
                showWhenHelpful = dispelBand == "helpful",
                showWithoutDispelType = dispelBand == "harmful",
                customDispelColorMap = element.dispelBorderColors,
            })
        end
    end

    -- Spirale dunkelt mit der Zeit ab statt von Anfang an; Restzeit zeigt nur unser Text.
    -- Sie bleibt innerhalb des Rahmens.
    local cooldown = button.Cooldown
    if cooldown then
        local inset = borderPixels * ns.PixelSize()
        cooldown:ClearAllPoints()
        cooldown:SetPoint("TOPLEFT", inset, -inset)
        cooldown:SetPoint("BOTTOMRIGHT", -inset, inset)
        cooldown:SetHideCountdownNumbers(true)
        cooldown:SetReverse(true)
        cooldown:SetDrawEdge(false)
        cooldown:SetSwipeColor(0, 0, 0, 0.6)
    end

    if button.Time then
        button.Time:ClearAllPoints()
        button.Time:SetPoint("CENTER", button, "CENTER", 0, 0)
        ns.SetFont(button.Time, STYLE.fontSize + 1, "OUTLINE")
    end
    if button.Count then
        button.Count:ClearAllPoints()
        button.Count:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        ns.SetFont(button.Count, STYLE.fontSize - 2, "OUTLINE")
    end
end

-- Klassenressource (Combo-Punkte, Heilige Kraft, …) als Reihe gleich breiter Segmente.
local CHARGED_COLOR = { 0.35, 0.75, 1 } -- aufgeladene Combo-Punkte

-- Eigene Farben für Klassenressourcen, wo Blizzards Farbe nicht passt (oUF.colors.power[Token])
-- Ruf-Farben je Stufe (1 Hasserfüllt … 8 Ehrfürchtig) in der Surf-Palette wie die Kräfte-Farben:
-- Rot → Orange → Sand → Grüntöne, Ehrfürchtig in mUI-Grün (Benny 2026-11-07, „Pastell mUI“).
-- Blizzards FACTION_BAR_COLORS bleibt unangetastet (globale Tabelle ändern = Taint).
local function Hex(hex) return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 } end
ns.REP_COLORS = {
    [1] = Hex("b8564e"), [2] = Hex("c66a62"), [3] = Hex("d39a6a"), [4] = Hex("dcc98a"),
    [5] = Hex("9cc27e"), [6] = Hex("7fbf8e"), [7] = Hex("6fb8a6"), [8] = Hex("8ecbb4"),
}
function ns.RepColor(reaction)
    local color = ns.REP_COLORS[reaction] or ns.REP_COLORS[8]
    return color[1], color[2], color[3]
end

-- Kräfte in der Surf-Palette: Pastelltöne passend zu Surf Green statt Blizzards Grelltönen (Benny 2026-11-07).
ns.POWER_COLORS = {
    ARCANE_CHARGES = { 0.64, 0.42, 0.98 },          -- Arkan-Ladungen: Zauber-Lila statt Blizzard-Blau
    MANA = { 111 / 255, 143 / 255, 207 / 255 },     -- #6F8FCF
    RAGE = { 198 / 255, 106 / 255, 98 / 255 },      -- #C66A62
    ENERGY = { 220 / 255, 201 / 255, 138 / 255 },   -- #DCC98A
    FOCUS = { 211 / 255, 154 / 255, 106 / 255 },    -- #D39A6A
}

-- Combo-Punkte gestaffelt: Gelb > Orange > Rot, je voller desto „heißer“.
local COMBO_GRADIENT = {
    { 1, 0.85, 0.2 },
    { 1, 0.5, 0.1 },
    { 0.9, 0.15, 0.1 },
}

-- Farbe für Segment index von max (lineare Mischung zwischen den Stufen).
function ns.ComboPointColor(index, max)
    local pos = (max > 1) and (index - 1) / (max - 1) * (#COMBO_GRADIENT - 1) + 1 or 1
    local lower = math.min(math.floor(pos), #COMBO_GRADIENT - 1)
    local f = pos - lower
    local a, b = COMBO_GRADIENT[lower], COMBO_GRADIENT[lower + 1]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

-- Segmente auf die aktuelle Anzahl verteilen, ganze Pixel. Mit element.width hat die
-- Leiste eine feste Breite (= Hauptaktionsleiste, für alle Klassen gleich), die Kästchen
-- passen sich an. Der Rundungsrest geht als je 1 px an Kästchen, abwechselnd von außen
-- nach innen – so schließen die Außenkanten exakt mit der Aktionsleiste ab.
function ns.LayoutClassPower(element, max)
    local px = ns.PixelSize()
    local strip = element.strip
    local gapPx = element.gapPixels
    if element.width then strip:SetWidth(element.width) end
    local totalPx = math.floor(strip:GetWidth() / px + 0.5)
    local segmentPx = math.floor((totalPx - (max - 1) * gapPx) / max)
    local restPx = totalPx - max * segmentPx - (max - 1) * gapPx

    local widths = {}
    for i = 1, max do widths[i] = segmentPx end
    if element.boxes then
        local left, right = 1, max
        for n = 1, restPx do
            if n % 2 == 1 then
                widths[left] = widths[left] + 1
                left = left + 1
            else
                widths[right] = widths[right] + 1
                right = right - 1
            end
        end
    else
        widths[max] = widths[max] + restPx -- ohne Kästchen: Rest an das letzte Segment
    end

    local x = 0
    for i = 1, max do
        local bar = element[i]
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", strip, "TOPLEFT", x * px, 0)
        bar:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", x * px, 0)
        bar:SetWidth(widths[i] * px)
        x = x + widths[i] + gapPx
    end
end

local function ClassPower_PostUpdateColor(element, color)
    element.color = color
end

local function ClassPower_PostUpdate(element, _, max, _, hasMaxChanged, powerType, ...)
    if hasMaxChanged and max and max > 0 then ns.LayoutClassPower(element, max) end

    local color = element.color
    if powerType == "COMBO_POINTS" and max and max > 0 then
        for i = 1, max do element[i]:SetStatusBarColor(ns.ComboPointColor(i, max)) end
    elseif color then
        for i = 1, #element do element[i]:SetStatusBarColor(color:GetRGB()) end
    end
    for n = 1, select("#", ...) do
        local bar = element[select(n, ...)]
        if bar then bar:SetStatusBarColor(unpack(CHARGED_COLOR)) end
    end
    for i = 1, #element do ns.ColorBarBackground(element[i]) end
end

-- Leiste nur zeigen, wenn die Klasse gerade eine Klassenressource hat.
local function ClassPower_PostVisibility(element, isVisible)
    element.strip:SetShown(isVisible)
end

-- Klassenressource (Position setzt das Layout über element.strip).
--   ohne width: eine Leiste mit Rahmen, Segmente durch eine feine dunkle Linie getrennt
--   mit width:  einzelne Kästchen mit eigenem 1-px-Rahmen, Leiste immer width breit
function ns.CreateClassPower(parent, height, width)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(height)
    if not width then ns.CreateBackground(strip) end

    local element = { strip = strip, width = width, boxes = width ~= nil, gapPixels = width and 4 or 1 }
    -- Breite sofort setzen: Ohne Breite hat die Leiste keine Position, und alles, was an ihr
    -- hängt (Staffelung, Ressource in der Mitte), wäre unsichtbar.
    if width then strip:SetWidth(width) end
    for i = 1, 10 do
        local bar = ns.CreateBar(strip, height)
        bar.PostUpdateColor = nil -- Farbe kommt aus ClassPower_PostUpdate
        bar.followsTheme = true
        if width then ns.AddBorder(bar) end
        element[i] = bar
    end
    element.PostUpdateColor = ClassPower_PostUpdateColor
    element.PostUpdate = ClassPower_PostUpdate
    element.PostVisibility = ClassPower_PostVisibility
    return element
end

-- Mönch (Braumeister): Staffelung als Balken an der Stelle der Klassenleiste, Anteil am
-- maximalen Leben; Farbe grün/gelb/rot wie bei Blizzard (ab 30 % bzw. 60 %).
local STAGGER_COLORS = { { 0.52, 1, 0.52 }, { 1, 0.98, 0.72 }, { 1, 0.42, 0.42 } }
ns.STAGGER_COLORS = STAGGER_COLORS

function ns.StaggerColor(percent)
    if percent >= 0.6 then return STAGGER_COLORS[3] end
    if percent > 0.3 then return STAGGER_COLORS[2] end
    return STAGGER_COLORS[1]
end

-- Ersetzt oUFs Farbwahl: rechnet nur mit lesbaren Werten (Secrets > Farbe bleibt).
local function Stagger_UpdateColor(frame)
    local element = frame.Stagger
    local cur, max = element.cur, element.max
    if not (ns.Readable(cur) and ns.Readable(max)) or max <= 0 then return end
    element:SetStatusBarColor(unpack(ns.StaggerColor(cur / max)))
    ns.ColorBarBackground(element)
end

local function Stagger_PostUpdate(element, cur, max)
    element.cur, element.max = cur, max
    element.Text:SetText(AbbreviateNumbers(cur)) -- verträgt auch Secrets
end

function ns.CreateStagger(parent, height, width)
    local bar = ns.CreateBar(parent, height)
    bar:SetWidth(width)
    bar.followsTheme = true
    ns.AddBorder(bar)
    bar.Text = ns.CreateText(bar, 10, "CENTER", "OUTLINE")
    bar.Text:SetPoint("CENTER", 0, 0)
    bar.UpdateColor = Stagger_UpdateColor
    bar.PostUpdate = Stagger_PostUpdate
    bar.PostUpdateColor = nil
    return bar
end

-- Hauptressource in der Mitte (Gleichgewicht, Shadow, Elementar): Die Spec-Ressource
-- wandert an den Platz der Klassenleiste, der Ressourcenbalken am Spielerframe zeigt Mana.
-- Gilt nach Spezialisierung – auch in Caster-Form, wo die angezeigte Ressource Mana ist –,
-- aber nicht in Katze/Bär (dann Energie/Wut wie gewohnt).
local CENTER_POWER = {
    [102] = Enum.PowerType.LunarPower, -- Druide Gleichgewicht: Astrale Macht
    [258] = Enum.PowerType.Insanity,   -- Priester Schatten: Wahnsinn
    [262] = Enum.PowerType.Maelstrom,  -- Schamane Elementar: Mahlstrom
}
local centerPowerType -- Ressource der aktuellen Spezialisierung oder nil

local function UpdateCenterPowerType()
    local index = C_SpecializationInfo.GetSpecialization()
    local specID = index and C_SpecializationInfo.GetSpecializationInfo(index)
    centerPowerType = specID and CENTER_POWER[specID]
end

-- Ressource für die Mitte, solange die angezeigte Ressource Mana oder die Spec-Ressource ist.
function ns.CenterPowerType(unit)
    if unit ~= "player" or not centerPowerType then return end
    local displayed = UnitPowerType("player")
    if not ns.Readable(displayed) then return end
    if displayed == Enum.PowerType.Mana or displayed == centerPowerType then return centerPowerType end
end

function ns.UsesCenterPower(unit)
    return ns.CenterPowerType(unit) ~= nil
end

-- Balken mit Rahmen und Zahl; aktualisiert sich selbst über Events.
function ns.CreateCenterPower(parent, height, width)
    local bar = ns.CreateBar(parent, height)
    bar:SetWidth(width)
    bar.followsTheme = true
    ns.AddBorder(bar)
    bar.Text = ns.CreateText(bar, 10, "CENTER", "OUTLINE")
    bar.Text:SetPoint("CENTER", 0, 0)
    bar:Hide()

    function bar:Update(event)
        if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" or not event then
            UpdateCenterPowerType()
        end
        if self.testing then return end
        local powerType = ns.CenterPowerType("player")
        self:SetShown(powerType ~= nil)
        if not powerType then return end
        local color = ns.oUF.colors.power[powerType]
        if color and color.GetRGB then self:SetStatusBarColor(color:GetRGB()) end
        ns.ColorBarBackground(self)
        self:SetMinMaxValues(0, UnitPowerMax("player", powerType))
        self:SetValue(UnitPower("player", powerType), ns.SMOOTH)
        self.Text:SetText(AbbreviateNumbers(UnitPower("player", powerType))) -- verträgt auch Secrets
    end

    bar:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
    bar:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    bar:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    bar:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    bar:RegisterEvent("PLAYER_ENTERING_WORLD")
    bar:SetScript("OnEvent", bar.Update)
    bar:Update()
    return bar
end

-- Todesritter-Runen: 6 Kästchen wie die Klassenleiste (Position über element.strip).
-- Füllen sich beim Aufladen; Farbe nach Spezialisierung (Blut/Frost/Unheilig).
function ns.CreateRunes(parent, height, width)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetHeight(height)
    local element = { strip = strip, width = width, boxes = true, gapPixels = 4 }
    for i = 1, 6 do
        local bar = ns.CreateBar(strip, height)
        bar.PostUpdateColor = nil -- Farbe setzt oUF für alle Runen, danach Runes.PostUpdateColor
        bar.followsTheme = true
        ns.AddBorder(bar)
        element[i] = bar
    end
    element.colorSpec = true
    element.sortOrder = "asc" -- bereite Runen zuerst
    element.PostUpdateColor = function(runes)
        for i = 1, #runes do ns.ColorBarBackground(runes[i]) end
    end
    ns.LayoutClassPower(element, 6)
    return element
end

-- Status-Symbol (Media/Icons/<name>.tga, weiß) in color, mit dunklem Schatten darunter,
-- damit es auch auf hellen Balken lesbar bleibt. Der Schatten folgt Show/Hide des Symbols.
-- Symbole: Material Design Icons / Material Symbols, Apache 2.0 (Media/Icons/CREDITS.txt).
function ns.CreateStatusIcon(parent, name, size, color)
    local px = ns.PixelSize()
    local icon = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetSize(size, size)
    icon:SetTexture(ns.MEDIA .. "Icons\\" .. name)
    icon:SetVertexColor(unpack(color))

    local shadow = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    shadow:SetTexture(ns.MEDIA .. "Icons\\" .. name)
    shadow:SetVertexColor(0, 0, 0, 0.9)
    shadow:SetPoint("TOPLEFT", icon, "TOPLEFT", -px, px)
    shadow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2 * px, -2 * px)
    hooksecurefunc(icon, "Show", function() shadow:Show() end)
    hooksecurefunc(icon, "Hide", function() shadow:Hide() end)
    hooksecurefunc(icon, "SetShown", function(_, shown) shadow:SetShown(shown) end)
    shadow:Hide()
    icon.shadow = shadow
    return icon
end

-- Symbol eines Status-Symbols wechseln (Schatten zieht mit), z. B. Bereitschaftscheck.
function ns.SetStatusIcon(icon, name)
    icon:SetTexture(ns.MEDIA .. "Icons\\" .. name)
    if icon.shadow then icon.shadow:SetTexture(ns.MEDIA .. "Icons\\" .. name) end
end

-- Reihe von Status-Symbolen, mittig auf anchor: Sichtbare Symbole rücken zusammen,
-- egal welche gerade aktiv sind.
function ns.CreateStatusRow(anchor, size, spacing)
    local row = { icons = {} }
    function row.Layout()
        local shown = {}
        for _, icon in ipairs(row.icons) do
            if icon:IsShown() then shown[#shown + 1] = icon end
        end
        local total = #shown * size + math.max(#shown - 1, 0) * spacing
        for i, icon in ipairs(shown) do
            icon:ClearAllPoints()
            icon:SetPoint("CENTER", anchor, "CENTER", -total / 2 + size / 2 + (i - 1) * (size + spacing), 0)
        end
    end
    function row.Add(icon)
        row.icons[#row.icons + 1] = icon
        icon:SetPoint("CENTER", anchor, "CENTER")
        hooksecurefunc(icon, "Show", row.Layout)
        hooksecurefunc(icon, "Hide", row.Layout)
        hooksecurefunc(icon, "SetShown", row.Layout)
        icon:Hide()
        return icon
    end
    return row
end

-- Health.PostUpdate: Schädel bei Tot, Geist bei Geistform (kein oUF-Element dafür).
-- Bei geschützten Werten (Secrets) lieber nichts anzeigen.
function ns.UpdateDeathIcons(health, unit)
    local frame = health.__owner
    local dead, ghost = UnitIsDead(unit), UnitIsGhost(unit)
    dead = ns.Readable(dead) and dead or false
    ghost = ns.Readable(ghost) and ghost or false
    frame.DeadIcon:SetShown(dead and not ghost)
    frame.GhostIcon:SetShown(ghost)
end

-- SummonIndicator.PostUpdate: oUF setzt bei jedem Update Blizzards Grafik; zurück auf
-- unser Symbol, Farbe nach Status (wartet / angenommen / abgelehnt).
function ns.UpdateSummonIcon(icon, status)
    if not status or status == Enum.SummonStatus.None then return end
    icon:SetTexture(ns.MEDIA .. "Icons\\Summon")
    local color = ns.STYLE.summonColors[status] or ns.STYLE.summonColors[1]
    icon:SetVertexColor(unpack(color))
end

-- Zauberleiste, nur sichtbar, solange gezaubert wird; liegt als Overlay über dem
-- Lebensbalken (der Rahmen kommt von dort). Zauber-Icon außen daneben, iconGap Abstand.
-- Eigene Zauber gold, beim Ziel türkis = unterbrechbar, grau = nicht. Ob ein Zauber
-- unterbrechbar ist, ist im Kampf ein Secret – oUF blendet deshalb die graue Fläche
-- (.Shield) per SetAlphaFromBoolean ein.
-- Ermächtigungszauber (Rufer): Stufengrenzen als dünne helle Linien statt Blizzard-Optik.
-- oUF setzt die Position (oben/unten am Balken), wir liefern nur die Linie.
local function CreatePip(castbar)
    local pip = CreateFrame("Frame", nil, castbar)
    pip:SetWidth(2 * ns.PixelSize())
    pip:SetFrameLevel(castbar:GetFrameLevel() + 2)
    local line = pip:CreateTexture(nil, "OVERLAY")
    line:SetAllPoints()
    line:SetColorTexture(1, 1, 1, 0.85)
    return pip
end
ns.CreateCastbarPip = CreatePip

function ns.CreateCastbar(parent, height, mirrored, showInterruptible, iconGap)
    local near, far = mirrored and "RIGHT" or "LEFT", mirrored and "LEFT" or "RIGHT"
    local dir = mirrored and -1 or 1

    local castbar = ns.CreateBar(parent, height)
    castbar.smoothing = Enum.StatusBarInterpolation.Immediate -- läuft über Blizzards Timer, schon flüssig
    castbar.PostUpdateColor = nil
    castbar:SetReverseFill(mirrored)
    castbar.baseColor = showInterruptible and STYLE.castInterruptibleColor or STYLE.castColor
    castbar:SetStatusBarColor(unpack(castbar.baseColor))
    castbar.panelBackground = true -- Hintergrund in Flächenfarbe
    local r, g, b = unpack(STYLE.panelColor)
    castbar.bg:SetVertexColor(r, g, b, 1)

    local fill = castbar:GetStatusBarTexture()
    if showInterruptible then
        local shield = castbar:CreateTexture(nil, "ARTWORK", nil, 1)
        shield:SetTexture(WHITE)
        shield:SetVertexColor(unpack(STYLE.castLockedColor))
        shield:SetAllPoints(fill)
        castbar.Shield = shield
    end

    local spark = castbar:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:SetTexture(WHITE)
    spark:SetVertexColor(1, 1, 1, 0.8)
    spark:SetWidth(2 * ns.PixelSize())
    spark:SetPoint("TOP", fill, "TOP" .. far)
    spark:SetPoint("BOTTOM", fill, "BOTTOM" .. far)
    castbar.Spark = spark

    -- Texte auf derselben Grundlinie wie Leben und Energie im Lebensbalken (unten, 4 Einheiten)
    local time = ns.CreateText(castbar, STYLE.fontSize + 1, far, "OUTLINE")
    time:SetPoint("BOTTOM" .. far, castbar, "BOTTOM" .. far, -5 * dir, 4)
    castbar.Time = time

    local text = ns.CreateText(castbar, STYLE.fontSize + 1, near, "OUTLINE")
    text:SetPoint("BOTTOM" .. near, castbar, "BOTTOM" .. near, 5 * dir, 4)
    text:SetPoint("BOTTOM" .. far, time, "BOTTOM" .. near, -4 * dir, 0)
    castbar.Text = text

    -- Icon außen neben dem Balken, so hoch wie der Balken, eigener 1-px-Rahmen
    local iconFrame = CreateFrame("Frame", nil, castbar)
    iconFrame:SetSize(height, height)
    iconFrame:SetPoint(far, castbar, near, -(iconGap or 0) * dir, 0)
    ns.AddBorder(iconFrame)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    castbar.Icon = icon

    castbar.CreatePip = CreatePip
    castbar.timeToHold = 0.5 -- abgebrochene Zauber kurz stehen lassen
    return castbar
end

-- Heil-Vorhersage und Absorb-Schild für Unitframes (Spieler, Ziel, Fokus, Bosse …):
--   • eingehende Heilung grün direkt hinter der Füllung (nur so weit, wie Leben fehlt)
--   • Schild hellblau vom Balkenende her über das Leben gelegt – auch bei vollem Leben sichtbar
--     (oUF klemmt Schilde sonst auf das fehlende Leben: bei vollem Leben sähe man nie einen).
--     Hellblau statt Weiß, damit er auch auf Priester-Weiß auffällt.
-- Alle Werte reicht oUF an Blizzards Balken weiter (Secret-sicher).
local HEAL_PREDICTION_COLOR = { 0.3, 0.9, 0.4, 0.45 }
local ABSORB_COLOR = { 0.35, 0.75, 1, 0.6 }
-- absorbOnly: nur Schilde, keine Heil-Vorhersage (Gruppenframes für DD/Tank, Benny 2026-11-07)
-- split: Heiler – eigene eingehende Heilung kräftig, fremde blasser dahinter, dazu Heilabsorb
local HEAL_OWN_COLOR, HEAL_OTHER_COLOR, HEAL_ABSORB_COLOR = { 0.35, 0.95, 0.45, 0.85 }, { 0.35, 0.8, 0.45, 0.4 }, { 0.55, 0.05, 0.08, 0.8 }
function ns.AddHealPrediction(health, mirrored, absorbOnly, split)
    local fill = health:GetStatusBarTexture()
    if split then
        local own = CreateFrame("StatusBar", nil, health)
        own:SetPoint("TOP")
        own:SetPoint("BOTTOM")
        own:SetPoint("LEFT", fill, "RIGHT")
        own:SetWidth(health:GetWidth())
        own:SetStatusBarTexture(STYLE.barTexture)
        own:SetStatusBarColor(unpack(HEAL_OWN_COLOR))
        own:SetFrameLevel(health:GetFrameLevel() + 1)
        local other = CreateFrame("StatusBar", nil, health)
        other:SetPoint("TOP")
        other:SetPoint("BOTTOM")
        other:SetPoint("LEFT", own:GetStatusBarTexture(), "RIGHT")
        other:SetWidth(health:GetWidth())
        other:SetStatusBarTexture(STYLE.barTexture)
        other:SetStatusBarColor(unpack(HEAL_OTHER_COLOR))
        other:SetFrameLevel(health:GetFrameLevel() + 1)
        health.HealingPlayer, health.HealingOther = own, other
        health.incomingHealOverflow = 1
        -- Heilabsorb: dunkelrot vom Ende des Lebens nach innen
        local healAbsorb = CreateFrame("StatusBar", nil, health)
        healAbsorb:SetPoint("TOP")
        healAbsorb:SetPoint("BOTTOM")
        healAbsorb:SetPoint("RIGHT", fill, "RIGHT")
        healAbsorb:SetWidth(health:GetWidth())
        healAbsorb:SetReverseFill(true)
        healAbsorb:SetStatusBarTexture(WHITE)
        healAbsorb:SetStatusBarColor(unpack(HEAL_ABSORB_COLOR))
        healAbsorb:SetFrameLevel(health:GetFrameLevel() + 2)
        health.HealAbsorb = healAbsorb
    end
    if absorbOnly or split then
        local absorb = CreateFrame("StatusBar", nil, health)
        absorb:SetAllPoints(health)
        absorb:SetReverseFill(not mirrored)
        absorb:SetStatusBarTexture(WHITE)
        absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
        absorb:SetFrameLevel(health:GetFrameLevel() + 2)
        health.DamageAbsorb = absorb
        health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MaximumHealth
        return
    end
    local healing = CreateFrame("StatusBar", nil, health)
    healing:SetPoint("TOP")
    healing:SetPoint("BOTTOM")
    if mirrored then
        healing:SetPoint("RIGHT", fill, "LEFT")
    else
        healing:SetPoint("LEFT", fill, "RIGHT")
    end
    healing:SetWidth(health:GetWidth()) -- oUF passt die Breite an, wenn sich der Balken ändert
    healing:SetReverseFill(mirrored or false)
    healing:SetStatusBarTexture(STYLE.barTexture)
    healing:SetStatusBarColor(unpack(HEAL_PREDICTION_COLOR))
    healing:SetFrameLevel(health:GetFrameLevel() + 1)
    health.HealingAll = healing
    health.incomingHealOverflow = 1 -- nie über den Balkenrand

    local absorb = CreateFrame("StatusBar", nil, health)
    absorb:SetAllPoints(health)
    absorb:SetReverseFill(not mirrored)
    absorb:SetStatusBarTexture(WHITE)
    absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
    absorb:SetFrameLevel(health:GetFrameLevel() + 2)
    health.DamageAbsorb = absorb
    health.damageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode.MaximumHealth
end

-- Globale Abklingzeit (Spieler): dünne Linie an der Unterkante, läuft während des GCD von innen
-- nach außen voll. Blizzard rechnet (Duration-Objekt) – geschützte Werte fassen wir nie an.
local GCD_SPELL = 61304
local gcdBars = {}

-- Läuft der GCD noch? Immer neu bei Blizzard fragen – ein einmal geholtes Duration-Objekt
-- meldet nach Ablauf nicht „null“ (Linie blieb sonst voll stehen). Kann geschützt sein.
local function GCDOver()
    local duration = C_Spell.GetSpellCooldownDuration(GCD_SPELL)
    if not duration then return true end
    return duration:IsZero(), duration
end

local function UpdateGCD(bar)
    if ns.db.castbar == "simple" then return bar:Hide() end -- Zauberleiste „Schlicht“: ohne GCD-Linie
    local over, duration = GCDOver()
    if not duration or (not issecretvalue(over) and over) then return bar:Hide() end
    bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
    bar:SetAlphaFromBoolean(over, 0, 1)
    bar:Show()
end

function ns.CreateGCDBar(parent, mirrored)
    local px = ns.PixelSize()
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bar:SetHeight(2 * px)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(1, 1, 1, 0.75)
    bar:SetReverseFill(mirrored or false)
    -- Ende des GCD: kein eigenes Ereignis – solange sichtbar kurz nachfragen, dann verstecken
    local elapsedSince = 0
    bar:SetScript("OnUpdate", function(self, elapsed)
        elapsedSince = elapsedSince + elapsed
        if elapsedSince < 0.05 then return end
        elapsedSince = 0
        local over = GCDOver()
        if not issecretvalue(over) and over then return self:Hide() end
        self:SetAlphaFromBoolean(over, 0, 1) -- geschützt: Blizzard entscheidet
    end)
    bar:Hide()
    gcdBars[bar] = true
    return bar
end
ns:On("SPELL_UPDATE_COOLDOWN", function()
    for bar in pairs(gcdBars) do UpdateGCD(bar) end
end)

-- Tick-Striche bei kanalisierten Zaubern (Spieler): zeigt, wann der nächste Schaden-/Heil-Tick
-- kommt – nicht zu früh abbrechen. Anzahl je Zauber (Tempo verkürzt die Abstände gleichmäßig).
local CHANNEL_TICKS = {
    [15407] = 6,   -- Gedankenschinden
    [391403] = 4,  -- Gedankenschinden: Wahnsinn
    [47540] = 3,   -- Sühne
    [64843] = 4,   -- Göttliche Hymne
    [234153] = 5,  -- Blutsauger
    [198590] = 5,  -- Seelendieb
    [755] = 5,     -- Lebenslinie
    [5143] = 5,    -- Arkane Geschosse
    [205021] = 5,  -- Frostblitz-Strahl
    [12051] = 4,   -- Hervorrufung
    [257044] = 7,  -- Schnellfeuer
    [113656] = 5,  -- Furorfäuste
    [117952] = 4,  -- Knisternder Jadeblitz
    [101546] = 4,  -- Wirbelnder Kranichtritt
    [115175] = 8,  -- Beruhigender Nebel
    [740] = 4,     -- Gelassenheit
    [356995] = 4,  -- Disintegrieren
    [198013] = 10, -- Augenstrahl
}
function ns.UpdateChannelTicks(castbar, unit, spellID)
    local ticks = castbar.channelTicks
    if not ticks then return end
    for _, tick in ipairs(ticks) do tick:Hide() end
    if ns.db.castbar == "simple" or issecretvalue(spellID) or not spellID then return end
    local channel = UnitChannelInfo(unit)
    if issecretvalue(channel) or not channel then return end
    local count = CHANNEL_TICKS[spellID]
    if not count then return end
    local width = castbar:GetWidth()
    local side = castbar:GetReverseFill() and "RIGHT" or "LEFT"
    local dir = side == "LEFT" and 1 or -1
    for i = 1, count - 1 do
        local tick = ticks[i]
        if not tick then
            tick = castbar:CreateTexture(nil, "OVERLAY", nil, 1)
            tick:SetColorTexture(0, 0, 0, 0.75)
            tick:SetWidth(2 * ns.PixelSize())
            ticks[i] = tick
        end
        tick:ClearAllPoints()
        tick:SetPoint("TOP", castbar, "TOP" .. side, dir * width * i / count, 0)
        tick:SetPoint("BOTTOM", castbar, "BOTTOM" .. side, dir * width * i / count, 0)
        tick:Show()
    end
end

-- Execute-Linie: weißer Strich im Lebensbalken bei der Lebensgrenze, ab der deine Klasse ihre
-- Hinrichtungs-Fähigkeit nutzen darf. Fest gesetzt – das Leben selbst (oft geschützt) wird nie gelesen.
-- Höchster bekannter Wert gewinnt; ohne passende Fähigkeit keine Linie.
local EXECUTE_SPELLS = {
    { 281001, 35 }, { 206315, 35 }, -- Massaker (Furor, Waffen)
    { 343294, 35 },                 -- Seelenernter (Todesritter)
    { 269644, 30 },                 -- Sengende Berührung (Feuer)
    { 5308, 20 }, { 163201, 20 }, { 280735, 20 }, -- Hinrichten
    { 53351, 20 }, { 320976, 20 },  -- Tödlicher Schuss
    { 24275, 20 },                  -- Hammer des Zorns
    { 32379, 20 },                  -- Schattenwort: Tod
}
local executePercent
local executeLines = {}

local function PlaceExecuteLine(line)
    local bar = line.bar
    local show = executePercent and ns.db.executeLine ~= false
    if show and line.unit then -- Unitframe: nur bei Gegnern
        local attackable = UnitCanAttack("player", line.unit)
        show = not issecretvalue(attackable) and attackable or false
    end
    if not show then return line:Hide() end
    local side = bar:GetReverseFill() and "RIGHT" or "LEFT"
    local offset = (side == "LEFT" and 1 or -1) * bar:GetWidth() * executePercent / 100
    line:ClearAllPoints()
    line:SetPoint("TOP", bar, "TOP" .. side, offset, 0)
    line:SetPoint("BOTTOM", bar, "BOTTOM" .. side, offset, 0)
    line:Show()
end

function ns.UpdateExecuteLines()
    executePercent = nil
    for _, entry in ipairs(EXECUTE_SPELLS) do
        if (not executePercent or entry[2] > executePercent) and C_SpellBook.IsSpellKnownOrInSpellBook(entry[1]) then
            executePercent = entry[2]
        end
    end
    for line in pairs(executeLines) do PlaceExecuteLine(line) end
end

-- unit: nur zeigen, wenn diese Einheit angreifbar ist (Ziel-Frame); Plates brauchen das nicht
function ns.AddExecuteLine(bar, unit)
    local line = bar:CreateTexture(nil, "OVERLAY", nil, 3)
    line:SetColorTexture(1, 1, 1, 0.8)
    line:SetWidth(2 * ns.PixelSize())
    line.bar, line.unit = bar, unit
    executeLines[line] = true
    bar:HookScript("OnSizeChanged", function() PlaceExecuteLine(line) end)
    PlaceExecuteLine(line)
    return line
end

ns:On("PLAYER_LOGIN", ns.UpdateExecuteLines)
ns:On("SPELLS_CHANGED", ns.UpdateExecuteLines)
ns:On("PLAYER_TARGET_CHANGED", function()
    for line in pairs(executeLines) do if line.unit then PlaceExecuteLine(line) end end
end)

-- Bildschirmgröße oder UI-Skalierung geändert (anderer Monitor, Skalierungs-Regler): MUI berechnet
-- Plätze und 1-px-Rahmen beim Laden – deshalb, wie bei ElvUI, einmal neu laden anbieten.
StaticPopupDialogs["MEREDANUI_RELOAD_SCALE"] = {
    text = ns.L["Screen size or UI scale changed. Reload the interface so mUI can rearrange everything?"],
    button1 = ns.L["Reload UI"],
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Platzierungen, die von der Bildschirmgröße abhängen (mittig, an Rändern): jedes Modul meldet
-- seine Platzierung hier an; sie läuft sofort und bei jeder Größen-/Skalierungsänderung erneut
-- (im Kampf erst danach – die Aktionsleisten sind geschützt). Danach gelten gespeicherte Positionen.
local placers = {}
function ns.OnLayout(fn)
    placers[#placers + 1] = fn
    fn()
end
function ns.Relayout()
    if InCombatLockdown() then return ns.AfterCombat(ns.Relayout) end
    for _, fn in ipairs(placers) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end

local layoutSize, layoutPixel -- Größe und Pixelgröße beim letzten Ausrichten
local function SizeKey() return ("%.0f:%.0f"):format(UIParent:GetWidth(), UIParent:GetHeight()) end
local function PixelKey() return ("%.4f"):format(ns.PixelSize()) end
ns:On("PLAYER_LOGIN", function()
    layoutSize, layoutPixel = SizeKey(), PixelKey()
end)
-- Andere Größe: sofort neu ausrichten. Andere Skalierung: zusätzlich Neuladen anbieten – die
-- 1-px-Rahmen werden beim Aufbau auf ganze Pixel gelegt und wären sonst unscharf.
local checkPending = false
local function CheckLayoutSize()
    if not layoutSize or checkPending then return end
    checkPending = true
    C_Timer.After(0.5, function()
        checkPending = false
        local size, pixel = SizeKey(), PixelKey()
        if size ~= layoutSize or pixel ~= layoutPixel then
            layoutSize = size
            ns.Relayout()
        end
        if pixel ~= layoutPixel then
            layoutPixel = pixel
            StaticPopup_Show("MEREDANUI_RELOAD_SCALE")
        end
    end)
end
-- Größe der Oberfläche (Benny 2026-11-07, wie ElvUI): mUI setzt die Skalierung selbst (UIParent),
-- Blizzards Regler wirkt dann nicht mehr. Das Layout ist für „Mittel“ (65 %) gebaut; „Klein“ geht
-- unter Blizzards Minimum (mehr Platz), „Groß“ ist das Maximum, bei dem auf 16:9 nichts überlappt.
-- Account-weit (hängt am Monitor, nicht am Profil): MeredanUIDB.uiSize.
ns.UI_SIZES = { small = 0.58, medium = 0.65, large = 0.71 }
function ns.UIScaleValue()
    return ns.UI_SIZES[ns.root and ns.root.uiSize or "medium"] or ns.UI_SIZES.medium
end
local function ApplyUIScale()
    if InCombatLockdown() then return ns.AfterCombat(ApplyUIScale) end
    local scale = ns.UIScaleValue()
    if math.abs(UIParent:GetScale() - scale) > 0.001 then UIParent:SetScale(scale) end
end
ns.ApplyUIScale = ApplyUIScale
ns:On("ADDON_LOADED", function(_, name) if name == ADDON_NAME then ApplyUIScale() end end)
-- Blizzard setzt die Skalierung bei eigenen Änderungen (Regler, Fenstergröße) zurück > wieder unsere
ns:On("UI_SCALE_CHANGED", ApplyUIScale)
ns:On("DISPLAY_SIZE_CHANGED", ApplyUIScale)
ns:On("UI_SCALE_CHANGED", CheckLayoutSize)
ns:On("DISPLAY_SIZE_CHANGED", CheckLayoutSize)

-- Blizzards Bearbeitungsmodus sperren (Benny 2026-11-07: mUI hat feste Layouts). Blizzards eigener
-- Weg, wie beim Haustierkampf: ein Rahmen in der Sperrliste > CanEnterEditMode() ist falsch (kein
-- Knopf im Esc-Menü, /editmode geht nicht). TEST: Am 2026-11-07 kurz entfernt, weil ein Taint-Fehler
-- in Blizzards Optionen (IsUserOAuthed) verdächtig war – Ursache war dann der Listen-Eintrag in den
-- Optionen (Config/Settings.lua). Kommt der Fehler mit der Sperre wieder, diese hier entfernen.
ns:On("PLAYER_LOGIN", function()
    if EditModeManagerFrame and EditModeManagerFrame.BlockEnteringEditMode then
        EditModeManagerFrame:BlockEnteringEditMode(CreateFrame("Frame", "MeredanUIEditModeBlocker"))
    end
end)
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, CheckLayoutSize) end)


-- Item-Vergleich wie bei Blizzard: Shift (bzw. „Immer vergleichen“) zeigt das Angelegte daneben.
-- Nach dem Füllen des Tooltips aufrufen; owner.UpdateTooltip = OnEnter-Funktion sorgt dafür, dass
-- Shift auch wirkt, wenn man es erst drückt, während die Maus schon drauf ist (GameTooltip ruft es laufend).
function ns.ShowItemCompare(tooltip)
    tooltip = tooltip or GameTooltip
    if IsModifiedClick("COMPAREITEMS") or C_CVar.GetCVarBool("alwaysCompareItems") then
        if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(tooltip) end
    elseif GameTooltip_HideShoppingTooltips then
        GameTooltip_HideShoppingTooltips(tooltip)
    end
end
