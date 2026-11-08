-- Aktionsleisten: eigene Leisten (LibActionButton) statt Blizzards, flach im MUI-Look.
-- Sie nutzen dieselben Aktionsplätze und Tastenbelegungen wie Blizzard – vorhandene Zauber
-- und Binds bleiben also, wo sie sind.
--
--                     [Haltung]
--                  [Klassenleiste]
--   [Spieler]   [ 1  2  3  4  5  6 ]   [Ziel]              ┃4┃5┃  rechts am Rand,
--   [Pet]       [ 7  8  9 10 11 12 ]                       ┃ ┃ ┃  senkrecht 12 × 1
--   [Pet-Leiste]
--
--             [ Alt-Leiste:   a-1 … a-V ]
--             [ Shift-Leiste: s-1 … s-V ]   ← 25 px über dem unteren Rand
--
-- Die Hauptleiste wechselt wie bei Blizzard die Seite: Gestalten (Druide), Verstohlenheit,
-- Himmelsreiten, Fahrzeug, Gedankenkontrolle, Shift+Mausrad-Seiten. Pet- und Haltungsleiste
-- sind Blizzards eigene Knöpfe (die Bibliothek kann keine Pet-Aktionen), nur umgesetzt und
-- umgestylt. Nichts davon im Kampf.
local _, ns = ...

local LAB = LibStub("LibActionButton-1.0")
local WHITE = "Interface\\Buttons\\WHITE8X8"

local SIZE = 36        -- Knopfgröße der Zusatzleisten

-- Breite einer waagrechten 12er-Leiste (Shift/Alt) – die Info-Leiste richtet sich danach
function ns.ExtraBarWidth()
    return 12 * ns.Snap(SIZE) + 11 * ns.MAIN_BAR.gapPixels * ns.PixelSize()
end
local SMALL_SIZE = 26  -- Haltungsleiste
local GAP_PIXELS = ns.MAIN_BAR.gapPixels -- in echten Pixeln, für alle Leisten gleich

-- page: feste Aktionsseite (Slots (page-1)*12+1 … +12), binding: Blizzards Binding-Name ohne Nummer
local BARS = {
    { key = "bar1", main = true, binding = "ACTIONBUTTON", cols = ns.MAIN_BAR.cols, size = ns.MAIN_BAR.size },
    { key = "bar2", page = 5, binding = "MULTIACTIONBAR2BUTTON", cols = 12 }, -- Shift (unten rechts bei Blizzard)
    { key = "bar3", page = 6, binding = "MULTIACTIONBAR1BUTTON", cols = 12 }, -- Alt (unten links bei Blizzard)
    { key = "bar4", page = 3, binding = "MULTIACTIONBAR3BUTTON", cols = 1 },  -- rechts außen
    { key = "bar5", page = 4, binding = "MULTIACTIONBAR4BUTTON", cols = 1 },  -- rechts innen
    -- Zusatzleisten 6–8 (Benny 2026-11-08): Blizzards Leisten 6–8 (Seiten 13–15), standardmäßig aus
    { key = "bar6", page = 13, binding = "MULTIACTIONBAR5BUTTON", cols = 1 }, -- rechts, dritte senkrechte
    { key = "bar7", page = 14, binding = "MULTIACTIONBAR6BUTTON", cols = 6 }, -- unten links, 6 × 2
    { key = "bar8", page = 15, binding = "MULTIACTIONBAR7BUTTON", cols = 6 }, -- unten rechts, 6 × 2
}

-- Seitenwechsel der Hauptleiste (wie ElvUI/Bartender). Fahrzeug, Override und temporäre Gestalt
-- liegen seit Dragonflight auf eigenen Seiten hinter den Zusatzleisten 5–7 (16–18) – die Nummern
-- kommen von Blizzard statt fest eingetragen; das Snippet prüft beim Wechsel, welche gerade gilt.
local VEHICLE_PAGE = C_ActionBar.GetVehicleBarIndex()
local OVERRIDE_PAGE = C_ActionBar.GetOverrideBarIndex()
local TEMP_SHAPESHIFT_PAGE = C_ActionBar.GetTempShapeshiftBarIndex()
local MAX_PAGE = math.max(14, VEHICLE_PAGE, OVERRIDE_PAGE, TEMP_SHAPESHIFT_PAGE)
local MAIN_PAGING = ("[overridebar] %d; [shapeshift] %d; [vehicleui][possessbar] %d; [bonusbar:5] 11; "):format(
        OVERRIDE_PAGE, TEMP_SHAPESHIFT_PAGE, VEHICLE_PAGE)
    .. "[bonusbar:4] 10; [bonusbar:3] 9; [bonusbar:2] 8; [bonusbar:1] 7; "
    .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
local MAIN_ONSTATE = ([[
    newstate = tonumber(newstate) or 1
    if newstate == %d or newstate == %d or newstate == %d then
        if HasVehicleActionBar() then
            newstate = GetVehicleBarIndex()
        elseif HasOverrideActionBar() then
            newstate = GetOverrideBarIndex()
        elseif HasTempShapeshiftActionBar() then
            newstate = GetTempShapeshiftBarIndex()
        end
    end
    self:SetAttribute("state", newstate)
    control:ChildUpdate("state", newstate)
]]):format(VEHICLE_PAGE, OVERRIDE_PAGE, TEMP_SHAPESHIFT_PAGE)

local hidden = CreateFrame("Frame")
hidden:Hide()
local bars = {}
ns.actionBars = bars -- für den Tastenbelegungs-Modus (KeyBind.lua)

-- Blizzards Leisten verschwinden (Pet und Haltung werden unten umgesetzt) ----------------

local BLIZZARD_BARS = {
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7", "OverrideActionBar", "PossessActionBar",
}
local BLIZZARD_BUTTONS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local function HideBlizzard()
    for _, name in ipairs(BLIZZARD_BARS) do
        local bar = _G[name]
        if bar then bar:SetParent(hidden) end
    end
    for _, prefix in ipairs(BLIZZARD_BUTTONS) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then
                button:UnregisterAllEvents() -- spart Rechenzeit; die Knöpfe sind unsichtbar
                button:SetAttribute("statehidden", true)
            end
        end
    end
end

-- Flacher Look für einen Aktionsknopf (eigene wie Blizzards) ------------------------------

local function ShortKey(text)
    if not text or issecretvalue(text) then return text end
    return (text:gsub("SHIFT%-", "s"):gsub("ALT%-", "a"):gsub("CTRL%-", "c"):gsub("META%-", "m")
        :gsub("MOUSEWHEELUP", "MwU"):gsub("MOUSEWHEELDOWN", "MwD"):gsub("BUTTON", "M")
        :gsub("NUMPAD", "N"):gsub("SPACE", "Spc"))
end

local function Hide(region)
    if region then region:SetAlpha(0) end -- Alpha statt Hide: Blizzard/LAB zeigen sie sonst wieder
end

-- Abklingzeit-Zahlen (Blizzard-Countdown) in unserer Schrift; Größe folgt der Knopfgröße.
local function StyleCooldownText(button, size)
    size = size or button.muiSize or 36
    for _, cooldown in ipairs({ button.cooldown or button.Cooldown, button.chargeCooldown }) do
        local text = cooldown and cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
        if text then ns.SetFont(text, math.floor(size * 0.4), "OUTLINE") end
    end
end

-- Hervorhebungen, die Blizzard an jeden Aktionsknopf hängt, eckig nachbauen: Blizzards
-- Grafik wird unsichtbar, ihr Ein-/Ausblenden schaltet unseren Rahmen.
local CreateOutline, AddPulse, AddSpecialHighlights -- unten definiert

local function Mirror(region, outline, extraCheck)
    region:SetAlpha(0)
    local function Sync()
        local on = region:IsShown() and (not extraCheck or extraCheck())
        outline:SetShown(on)
        if outline.pulse then
            if on then outline.pulse:Play() else outline.pulse:Stop() end
        end
    end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
        if region[method] then hooksecurefunc(region, method, Sync) end
    end
    return Sync
end

AddSpecialHighlights = function(button)
    -- Zauberbuch-Hover: Platz des Zaubers blitzt weiß auf
    if button.SpellHighlightTexture then
        local outline = CreateOutline(button, { 1, 1, 1 }, 8)
        AddPulse(outline, 0.2, 0.35)
        Mirror(button.SpellHighlightTexture, outline)
        -- Blizzards Blink-Animation würde die Grafik wieder sichtbar machen
        if button.SpellHighlightAnim then
            hooksecurefunc(button.SpellHighlightAnim, "Play", function(anim) anim:Stop() end)
        end
    end
    -- Angriff des Begleiters: Blizzard lässt eine rote Fläche blinken, solange er angreift
    -- (Benny 2026-11-06: „blinkt dauernd“) – stattdessen ruhiger, dünner roter Rahmen
    if button.Flash and button.StartFlash and button.StopFlash then
        button.Flash:SetAlpha(0)
        local outline = CreateOutline(button, { 0.9, 0.25, 0.25 }, 5, true)
        outline:Hide()
        hooksecurefunc(button, "StartFlash", function() outline:Show() end)
        hooksecurefunc(button, "StopFlash", function() outline:Hide() end)
        if button.IsFlashing and button:IsFlashing() then outline:Show() end
    end
    -- Pet-Autocast: dünner, langsam pulsierender Rahmen, solange Autocast an ist
    local autoCast = button.AutoCastOverlay
    if autoCast then
        local accent = ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 }
        local outline = CreateOutline(button, accent, 5, true)
        AddPulse(outline, 0.3, 0.8)
        local enabled = false
        local Sync = Mirror(autoCast, outline, function() return enabled end)
        hooksecurefunc(autoCast, "ShowAutoCastEnabled", function(_, on)
            enabled = on and true or false
            Sync()
        end)
    end
end

local function StyleButton(button)
    if button.muiStyled then return end
    button.muiStyled = true
    button.MasqueSkinned = true -- LibActionButton fasst die Knopf-Optik dann nicht mehr an

    Hide(button.NormalTexture or button:GetNormalTexture())
    Hide(button.SlotBackground)
    Hide(button.SlotArt)
    Hide(button.FloatingBG)
    Hide(button.Border)
    Hide(button.NewActionTexture)
    if button.IconMask then button.icon:RemoveMaskTexture(button.IconMask) end
    button.icon:ClearAllPoints()
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Hintergrund leerer Plätze: Blizzards Slot-Grafik, an den Rändern beschnitten (deren
    -- Rundungen/Rahmen), damit sie in unseren eckigen Rahmen passt; ohne Atlas schlicht dunkel.
    -- Die Slot-Grafik ist halbtransparent: deckende dunkle Fläche darunter.
    ns.AddSlotBackground(button)
    ns.AddBorder(button)

    local function Flat(texture, r, g, b, a)
        if not texture then return end
        texture:SetTexture(WHITE)
        texture:SetVertexColor(r, g, b, a)
        texture:ClearAllPoints()
        texture:SetAllPoints()
    end
    Flat(button:GetPushedTexture(), 1, 1, 1, 0.25)
    Flat(button:GetHighlightTexture(), 1, 1, 1, 0.15)
    if button.GetCheckedTexture then
        local accent = ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 }
        Flat(button:GetCheckedTexture(), accent[1], accent[2], accent[3], 0.35)
    end

    local cooldown = button.cooldown or button.Cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints()
    end
    StyleCooldownText(button)
    -- „Bereit“-Blitz am Ende einer Abklingzeit: eckiges Aufhellen statt Blizzards Stern
    if cooldown and cooldown.SetBlingTexture then cooldown:SetBlingTexture(WHITE, 1, 1, 1, 0.35) end
    AddSpecialHighlights(button)

    if button.HotKey then
        ns.SetFont(button.HotKey, 11, "OUTLINE")
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", -2, -3)
        button.HotKey:SetJustifyH("RIGHT")
        hooksecurefunc(button.HotKey, "SetText", function(self, text)
            if self.muiSetting then return end
            -- Blizzards eigene Knöpfe (Extra-Aktion) schreiben die lange Klartext-Taste
            -- („s-Mittlere Maustaste“) – dann die rohe Belegung kürzen
            local raw = button.commandName and GetBindingKey(button.commandName)
            local short = ShortKey(raw or text)
            if short ~= text then
                self.muiSetting = true
                self:SetText(short)
                self.muiSetting = false
            end
        end)
        button.HotKey:SetText(button.HotKey:GetText())
    end
    if button.Count then
        ns.SetFont(button.Count, 12, "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", -2, 3)
    end
    if button.Name then
        ns.SetFont(button.Name, 10, "OUTLINE")
        button.Name:ClearAllPoints()
        button.Name:SetPoint("BOTTOMLEFT", 2, 3)
        button.Name:SetPoint("BOTTOMRIGHT", -2, 3)
    end
end

-- Eckige Hervorhebungen statt Blizzards runder -----------------------------------------
--   Proc (Zauber leuchtet auf, z. B. durch Talent-Effekt): goldener Rahmen, leuchtend, pulsierend
--   Rotationshilfe (Blizzards „nächster empfohlener Zauber“): cyanfarbener Rahmen, leuchtend,
--   langsam pulsierend
local PROC_COLOR = { 1, 0.82, 0.2 }
local ASSIST_COLOR = { 0.3, 0.75, 1 }
local highlightButtons = {}

-- Leuchten, aber eckig: innen 2 px voll, außen Ringe mit abnehmender Deckkraft.
local GLOW_ALPHAS = { 0.55, 0.3, 0.12 }

local function Ring(frame, offsetPx, color, alpha)
    local px = ns.PixelSize()
    local o, i = (offsetPx + 1) * px, offsetPx * px -- äußere/innere Kante des Rings
    local function Edge()
        local tex = frame:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(WHITE)
        tex:SetVertexColor(color[1], color[2], color[3], alpha)
        return tex
    end
    local top, bottom, left, right = Edge(), Edge(), Edge(), Edge()
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, o)
    top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", o, i)
    bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -o, -i)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -o)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", -o, i)
    left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -i, -i)
    right:SetPoint("TOPLEFT", frame, "TOPRIGHT", i, i)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", o, -i)
end

-- thin: nur 1 px innen, ohne Leuchten (für dezente Hinweise)
CreateOutline = function(button, color, level, thin)
    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints()
    frame:SetFrameLevel(button:GetFrameLevel() + level)
    for _, edge in ipairs(ns.AddBorder(frame, true, thin and 1 or 2)) do edge:SetVertexColor(unpack(color)) end
    -- Ring 0 liegt auf unserem 1-px-Rahmen, danach nach außen
    if not thin then
        for n, alpha in ipairs(GLOW_ALPHAS) do Ring(frame, n - 1, color, alpha) end
    end
    frame:Hide()
    return frame
end

-- Langsames Pulsieren (Deckkraft) für eine Hervorhebung
AddPulse = function(frame, low, duration)
    local pulse = frame:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(low)
    fade:SetDuration(duration)
    frame.pulse = pulse
end

local function AddHighlights(button)
    button.muiProc = CreateOutline(button, PROC_COLOR, 6)
    AddPulse(button.muiProc, 0.35, 0.5)
    button.muiAssist = CreateOutline(button, ASSIST_COLOR, 7)
    AddPulse(button.muiAssist, 0.55, 0.9)
    button.muiRotation = CreateOutline(button, ASSIST_COLOR, 7) -- Ein-Tasten-Assistent
    highlightButtons[#highlightButtons + 1] = button
end

local function SpellID(button)
    local id = button:GetSpellId()
    if ns.Readable(id) then return id end
end

local function UpdateProc(button)
    local id = SpellID(button)
    local on = id and C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed(id)
    on = ns.Readable(on) and on or false
    button.muiProc:SetShown(on)
    if on then button.muiProc.pulse:Play() else button.muiProc.pulse:Stop() end
end

local function UpdateAssist(button)
    -- Blizzards eigene (runde) Hervorhebung, falls sie sie an unseren Knopf hängt: unsichtbar
    if button.AssistedCombatHighlightFrame then button.AssistedCombatHighlightFrame:SetAlpha(0) end
    local next = AssistedCombatManager and AssistedCombatManager.lastNextCastSpellID
    local id = SpellID(button)
    local on = ns.Readable(next) and id ~= nil and id == next
    button.muiAssist:SetShown(on)
    if on then button.muiAssist.pulse:Play() else button.muiAssist.pulse:Stop() end
end

-- Ein-Tasten-Assistent: Blizzards Rahmen um diesen Knopf unsichtbar, unserer cyan
local function UpdateRotation(button)
    local frame = button.AssistedCombatRotationFrame
    if frame then frame:SetAlpha(0) end
    button.muiRotation:SetShown(frame ~= nil and frame:IsShown())
end

local function UpdateAllHighlights()
    for _, button in ipairs(highlightButtons) do
        UpdateProc(button)
        UpdateAssist(button)
        UpdateRotation(button)
    end
end

local highlightEvents = CreateFrame("Frame")
highlightEvents:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
highlightEvents:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
highlightEvents:SetScript("OnEvent", function() for _, button in ipairs(highlightButtons) do UpdateProc(button) end end)
if EventRegistry then
    EventRegistry:RegisterCallback("AssistedCombatManager.OnAssistedHighlightSpellChange", UpdateAllHighlights, highlightEvents)
    EventRegistry:RegisterCallback("AssistedCombatManager.OnSetUseAssistedHighlight", UpdateAllHighlights, highlightEvents)
    EventRegistry:RegisterCallback("ActionButton.OnAssistedCombatRotationFrameChanged", UpdateAllHighlights, highlightEvents)
end
LAB.RegisterCallback(highlightEvents, "OnButtonUpdate", function(_, button)
    if button.muiProc then
        UpdateProc(button)
        UpdateAssist(button)
        UpdateRotation(button)
    end
    StyleCooldownText(button) -- Aufladungs-Abklingzeit legt die Bibliothek erst bei Bedarf an
end)

-- Knöpfe im Raster anordnen: cols Spalten, 1. Knopf oben links.
local function Arrange(holder, buttons, cols, size)
    local rows = math.ceil(#buttons / cols)
    size = ns.Snap(size)
    local gap = GAP_PIXELS * ns.PixelSize()
    holder:SetSize(cols * size + (cols - 1) * gap, rows * size + (rows - 1) * gap)
    for i, button in ipairs(buttons) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        button:ClearAllPoints()
        button:SetSize(size, size)
        button.muiSize = size
        StyleCooldownText(button, size)
        button:SetPoint("TOPLEFT", holder, "TOPLEFT", col * (size + gap), -row * (size + gap))
    end
end

-- Flyouts (Gifte, Portale, Pet rufen …) ----------------------------------------------------
-- Die Bibliothek baut eigene Flyout-Knöpfe: im MUI-Look, ohne Blizzards Hintergrund-Schiene.
LAB.RegisterCallback(highlightEvents, "OnFlyoutButtonCreated", function(_, button) StyleButton(button) end)
for _, button in ipairs(LAB.FlyoutButtons or {}) do StyleButton(button) end

-- Richtung je nach Leiste: senkrechte Leisten zur Bildschirmmitte hin seitlich, waagrechte
-- nach oben bzw. (obere Bildschirmhälfte) nach unten. Folgt verschobenen Leisten.
local function UpdateFlyoutDirection(bar)
    if InCombatLockdown() then return end
    local x, y = bar:GetCenter()
    if not x then return end
    local midX, midY = UIParent:GetCenter()
    local dir
    if bar.def.cols == 1 then
        dir = x > midX and "LEFT" or "RIGHT"
    else
        dir = y > midY and "DOWN" or "UP"
    end
    for _, button in ipairs(bar.buttons) do
        if button.config.flyoutDirection ~= dir then
            button.config.flyoutDirection = dir
            button:SetAttribute("flyoutDirection", dir)
            button:UpdateFlyout()
        end
    end
end

-- Eigene Leisten --------------------------------------------------------------------------

-- Texte auf den Knöpfen je Leiste (Benny 2026-11-08): Tastenbelegung und Makroname, Standard an.
-- Anzahl/Ladungen und Abklingzeit bleiben immer sichtbar.
local function TextShown(key, what)
    local t = ns.db and ns.db.actionBarTexts and ns.db.actionBarTexts[key]
    return not (t and t[what] == false)
end
ns.ActionBarTextShown = TextShown

-- Schriftgröße der Tastenbelegung für alle Leisten (Benny 2026-11-08): Klein = früher, Groß = so
-- wie die Knopf-Bibliothek sie setzt. Makroname und Anzahl bleiben unverändert.
local HOTKEY_SIZES = { small = 11, medium = 12, large = 14 }
local function HotkeySize() return HOTKEY_SIZES[ns.db and ns.db.actionBarFont or "large"] or 14 end
local function HotkeyText()
    return { hotkey = {
        font = { font = ns.FontFor and ns.FontFor() or ns.STYLE.font, size = ns.FontPx(HotkeySize()), flags = "OUTLINE" },
        position = { anchor = "TOPRIGHT", relAnchor = "TOPRIGHT", offsetX = -2, offsetY = -3 },
    } }
end

local function ButtonConfig(def, index)
    return {
        showGrid = true,
        keyBoundTarget = def.binding .. index,
        -- als Blizzard-Aktionsknopf melden: Rotationshilfe & Co. kennen dann unsere Knöpfe;
        -- deren runde Optik ersetzen wir unten durch eckige Rahmen
        actionButtonUI = true,
        assistedHighlight = false,
        hideElements = { macro = not TextShown(def.key, "macro"), hotkey = not TextShown(def.key, "hotkey"),
            equipped = true, border = true, borderIfEmpty = true },
        text = HotkeyText(),
    }
end

local function CreateBar(def)
    local name = "MeredanUI" .. def.key:gsub("^%l", string.upper)
    local header = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
    header:SetFrameStrata("LOW")
    header.buttons = {}
    header.muiKey = def.key
    for i = 1, 12 do
        local button = LAB:CreateButton(i, name .. "Button" .. i, header, ButtonConfig(def, i))
        if def.main then
            for page = 1, MAX_PAGE do button:SetState(page, "action", (page - 1) * 12 + i) end
        else
            button:SetState(0, "action", (def.page - 1) * 12 + i)
        end
        -- Mouseover-Zauber wie bei Blizzards Knöpfen; ob er greift, entscheidet der CVar
        -- enableMouseoverCast (Einstellung „Mouseover-Heilen“, ns.ApplyMouseoverCast)
        button:SetAttribute("checkmouseovercast", true)
        StyleButton(button)
        AddHighlights(button)
        header.buttons[i] = button
    end
    if def.main then
        header:SetAttribute("_onstate-page", MAIN_ONSTATE)
        RegisterStateDriver(header, "page", MAIN_PAGING)
    else
        header:SetAttribute("state", 0)
    end
    for _, button in ipairs(header.buttons) do button:UpdateAction(true) end
    Arrange(header, header.buttons, def.cols, def.size or SIZE)
    header.def = def
    -- Platzierung landet in SetPoint (Kopfzeilen-Ziehen in StopMovingOrSizing)
    local function Update() UpdateFlyoutDirection(header) end
    hooksecurefunc(header, "SetPoint", Update)
    hooksecurefunc(header, "StopMovingOrSizing", Update)
    return header
end

-- Tasten: Blizzards Binds (ACTIONBUTTON1, MULTIACTIONBAR1BUTTON1 …) klicken unsere Knöpfe.
local bindOwner = CreateFrame("Frame")
local function UpdateBindings()
    if InCombatLockdown() then return ns.AfterCombat(UpdateBindings) end
    ClearOverrideBindings(bindOwner)
    for _, bar in ipairs(bars) do
        for i, button in ipairs(bar.buttons) do
            for _, key in ipairs({ GetBindingKey(bar.def.binding .. i) }) do
                SetOverrideBindingClick(bindOwner, false, key, button:GetName(), "LeftButton")
            end
        end
    end
end

-- Pet- und Haltungsleiste: Blizzards Knöpfe in unserem Halter -------------------------------

-- Blizzard-Leiste dauerhaft in den Halter setzen; Blizzard verschiebt sie bei Edit-Mode-
-- Änderungen und ordnet die Knöpfe neu – beides holen wir per Haken zurück.
local adopted = {} -- [Leisten-Schlüssel] = Blizzard-Knöpfe (Pet, Haltung)
local function AdoptBlizzardBar(bar, holder, prefix, count, cols, size, key)
    if not bar then return end
    local buttons = {}
    if key then adopted[key] = buttons end
    for i = 1, count do
        local button = _G[prefix .. i]
        if button then
            StyleButton(button)
            buttons[#buttons + 1] = button
        end
    end
    local function Apply()
        if InCombatLockdown() then return end
        bar.muiPlacing = true
        bar:SetParent(holder)
        bar:ClearAllPoints()
        bar:SetAllPoints(holder)
        Arrange(holder, buttons, cols, size)
        bar.muiPlacing = false
    end
    hooksecurefunc(bar, "SetPoint", function() if not bar.muiPlacing then Apply() end end)
    if bar.UpdateGridLayout then hooksecurefunc(bar, "UpdateGridLayout", Apply) end
    Apply()
end

-- Sichtbarkeit (Einstellungen > Aktionsleisten) -------------------------------------------
-- Ein-/Ausblenden läuft über sichere Zustandstreiber (geht auch im Kampf), Mouseover über
-- Transparenz (Knöpfe und Tasten funktionieren dann trotzdem). Im Haustierkampf sind alle
-- Leisten weg, die Hauptleiste ist im Fahrzeug immer da.
local framesByKey = {}

local VISIBILITY = {
    always = "show",
    mouseover = "show",
    combat = "show", -- im Kampf sichtbar, außerhalb wie Mouseover (bleibt per Maus erreichbar)
    hidden = "hide",
}

-- Einstellung einer Aktionsleiste lesen: wie überall, nur „combat“ gibt es hier wirklich
-- (Benny 2026-11-08: außerhalb des Kampfes ausgeblendet, aber per Maus darüber sichtbar)
local function BarMode(key)
    local raw = ns.db.actionBars[key]
    if raw == "combat" then return "combat" end
    return ns.VisibilityMode(raw)
end
ns.ActionBarMode = BarMode

-- Innerste sichtbare rechte Leiste (6 vor 5 vor 4): daran richtet sich der Questtracker aus
function ns.InnermostRightBar()
    for _, key in ipairs({ "bar6", "bar5", "bar4" }) do
        local bar = ns.layoutFrames and ns.layoutFrames[key]
        if bar and bar:IsVisible() and bar:GetLeft() then return bar end
    end
end

-- Platz, den Leiste 7 (unten links) neben den 12er-Reihen braucht – der Chat wird entsprechend
-- schmaler, damit er nie darunter rutscht (0, wenn sie aus ist)
function ns.LeftBlockReserve()
    if not ns.db or BarMode("bar7") == "hidden" then return 0 end
    return 6 * ns.Snap(SIZE) + 5 * GAP_PIXELS * ns.PixelSize() + ns.Snap(12)
end

local function VisibilityRule(key, mode)
    local rule = VISIBILITY[mode] or "show"
    if key == "bar1" and mode ~= "hidden" then rule = "[vehicleui][overridebar][possessbar] show; " .. rule end
    return "[petbattle] hide; " .. rule
end

-- Weiches Ein-/Ausblenden (Benny 2026-11-08): jede Leiste hat ein Ziel (muiTarget), ein OnUpdate
-- führt die Transparenz in FADE_TIME dorthin. Transparenz darf man auch im Kampf setzen.
local FADE_TIME = 0.15
local fader = CreateFrame("Frame")
fader:SetScript("OnUpdate", function(_, elapsed)
    local step = elapsed / FADE_TIME
    for _, frame in pairs(framesByKey) do
        local target = frame.muiTarget
        if target then
            local alpha = frame:GetAlpha()
            if alpha < target then frame:SetAlpha(math.min(target, alpha + step))
            elseif alpha > target then frame:SetAlpha(math.max(target, alpha - step)) end
        end
    end
end)

-- Tasten-/Makrotexte nach Einstellung (LAB-Knöpfe über ihre Konfiguration, Blizzards Pet-/
-- Haltungsknöpfe über Transparenz)
function ns.ApplyActionBarTexts()
    if InCombatLockdown() then return ns.AfterCombat(ns.ApplyActionBarTexts) end
    for _, header in ipairs(bars) do
        local key = header.muiKey
        for _, button in ipairs(header.buttons or {}) do
            local config = CopyTable(button.config)
            config.hideElements.hotkey = not TextShown(key, "hotkey")
            config.hideElements.macro = not TextShown(key, "macro")
            local text = HotkeyText()
            config.text.hotkey.font = text.hotkey.font
            config.text.hotkey.position = text.hotkey.position
            button:UpdateConfig(config)
        end
    end
    for key, buttons in pairs(adopted) do
        for _, button in ipairs(buttons) do
            if button.HotKey then
                button.HotKey:SetAlpha(TextShown(key, "hotkey") and 1 or 0)
                ns.SetFont(button.HotKey, HotkeySize(), "OUTLINE")
            end
            if button.Name then button.Name:SetAlpha(TextShown(key, "macro") and 1 or 0) end
        end
    end
end

function ns.ApplyActionBarVisibility()
    if InCombatLockdown() then return ns.AfterCombat(ns.ApplyActionBarVisibility) end
    for key, frame in pairs(framesByKey) do
        local mode = BarMode(key) -- Immer, Im Kampf, Mouseover oder Aus
        local rule = VisibilityRule(key, mode)
        frame.muiMouseover = mode == "mouseover"
        frame.muiCombat = mode == "combat"
        if mode == "hidden" and frame:IsShown() and frame:GetAlpha() > 0 then
            -- erst ausblenden, dann wirklich weg (der Zustandstreiber versteckt sofort)
            frame.muiTarget = 0
            C_Timer.After(FADE_TIME, function()
                if InCombatLockdown() or BarMode(key) ~= "hidden" then return end
                RegisterStateDriver(frame, "visibility", rule)
            end)
        else
            if not frame:IsShown() then frame:SetAlpha(0) end -- frisch eingeschaltet: weich einblenden
            RegisterStateDriver(frame, "visibility", rule)
            if not (frame.muiMouseover or frame.muiCombat) then frame.muiTarget = 1 end
        end
    end
    -- Questtracker (rechts) und Chat (links) rücken zur Seite bzw. zurück
    C_Timer.After(0, function() if ns.Relayout then ns.Relayout() end end)
end

-- Offenes Flyout hängt am Knopf seiner Leiste und liegt daneben: Maus darauf zählt als „über der Leiste“
local function MouseOverFlyout(frame)
    local flyout = LAB:GetSpellFlyoutFrame()
    if not (flyout and flyout:IsVisible() and flyout:IsMouseOver(4, -4, -4, 4)) then return false end
    local parent = flyout:GetParent()
    while parent do
        if parent == frame then return true end
        parent = parent:GetParent()
    end
    return false
end

-- Mouseover: alle 0,1 s prüfen (Alpha darf man auch im Kampf setzen)
C_Timer.NewTicker(0.1, function()
    local inCombat = InCombatLockdown()
    for _, frame in pairs(framesByKey) do
        if frame.muiCombat and inCombat then
            frame.muiTarget = 1
        elseif frame.muiMouseover or frame.muiCombat then
            local over = frame:IsVisible() and (frame:IsMouseOver(4, -4, -4, 4) or MouseOverFlyout(frame))
            frame.muiTarget = over and 1 or 0
        end
    end
end)

-- Aufbau ------------------------------------------------------------------------------------

local function Place(frame, key, point, x, y)
    ns.PlaceFromCenter(frame, point, x, y)
    ns.layoutFrames[key] = frame
    framesByKey[key] = frame
end

-- Boss-Knopf (Extra-Aktionsknopf) und Zonen-Knöpfe (Zonenfähigkeiten): Blizzards Deko-Grafik am
-- Knopf weg (sie hat ein festes Quadrat um den Knopf), beim Boss-Knopf als Nachbau dahinter (s. u.),
-- der Knopf selbst im MUI-Look wie
-- die Aktionsleisten (eckig, 1-px-Rahmen, MUI-Schrift). Blizzard setzt die Deko je Fähigkeit neu
-- (SetTexture/SetAtlas/Show) – danach leeren wir sie wieder.
local function HideDecoration(texture, onTexture)
    if not texture then return end
    texture:SetTexture(nil)
    texture:Hide()
    if not texture.muiHidden then
        texture.muiHidden = true
        -- nach jedem Neusetzen/Zeigen durch Blizzard sofort wieder leer und versteckt; die neue
        -- Grafik geht an unseren Nachbau (onTexture)
        for _, method in ipairs({ "SetTexture", "SetAtlas", "Show" }) do
            hooksecurefunc(texture, method, function(self, file)
                if self.muiHiding then return end
                if onTexture and method ~= "Show" and file then onTexture(method, file) end
                self.muiHiding = true
                self:SetTexture(nil)
                self:Hide()
                self.muiHiding = false
            end)
        end
    end
end

-- Boss-Knopf: Blizzards Wolke als eigener Nachbau HINTER dem Knopf; der Knopf ist so groß, dass er
-- Blizzards eingezeichnetes Quadrat genau abdeckt (Benny mag die Wolke, nicht das Quadrat – ein
-- extra dunkler Ring war ihm zu klobig). Hängt am ExtraActionBarFrame: blendet mit ihm ein und aus.
local BOSS_BUTTON_SIZE = 60

local function BuildBossDecoration(button)
    local bar = button:GetParent()
    local deco = CreateFrame("Frame", nil, bar)
    deco:SetFrameLevel(math.max(button:GetFrameLevel() - 2, 0))
    deco:SetSize(256, 128)
    deco:SetPoint("CENTER", button, "CENTER")
    deco.art = deco:CreateTexture(nil, "BACKGROUND")
    deco.art:SetAllPoints()
    button:SetSize(ns.Snap(BOSS_BUTTON_SIZE), ns.Snap(BOSS_BUTTON_SIZE)) -- nur außerhalb des Kampfes (Setup)
    local function SetArt(method, file)
        if method == "SetAtlas" then deco.art:SetAtlas(file) else deco.art:SetTexture(file) end
    end
    -- aktuelle Grafik übernehmen (Blizzard setzt sie beim Erscheinen jeder Fähigkeit)
    SetArt("SetTexture", C_ActionBar.GetOverrideBarSkin and C_ActionBar.GetOverrideBarSkin() or "Interface\\ExtraButton\\Default") -- Blizzards Standard (dort lokal)
    return SetArt
end

local SkinZoneButtons
function SkinZoneButtons(frame)
    local container = frame and frame.SpellButtonContainer
    if not (container and container.EnumerateActive) then return end
    if InCombatLockdown() then return ns.AfterCombat(function() SkinZoneButtons(frame) end) end
    for button in container:EnumerateActive() do
        if not button.muiStyled then
            button.icon = button.icon or button.Icon -- StyleButton erwartet .icon
            StyleButton(button)
        end
        -- Wolke liegt bei Zonenfähigkeiten schon HINTER den Knöpfen (Grafik am Rahmen) – sie bleibt;
        -- der Knopf deckt wie beim Boss-Knopf das eingezeichnete Quadrat ab
        button:SetSize(ns.Snap(BOSS_BUTTON_SIZE), ns.Snap(BOSS_BUTTON_SIZE))
    end
    if container.MarkDirty then container:MarkDirty() end
end

local function SkinExtraButtons()
    if ExtraActionButton1 then
        StyleButton(ExtraActionButton1)
        HideDecoration(ExtraActionButton1.style, BuildBossDecoration(ExtraActionButton1))
    end
    if ZoneAbilityFrame and ZoneAbilityFrame.UpdateDisplayedZoneAbilities then
        hooksecurefunc(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", SkinZoneButtons)
        SkinZoneButtons(ZoneAbilityFrame)
    end
end

local function Setup()
    HideBlizzard()
    local gap = GAP_PIXELS * ns.PixelSize()
    -- Gestapelt (Heiler oder gewählt): Hauptleiste als eine Reihe à 12 in Zusatzleisten-Größe (unten über Alt/Shift)
    local healer = ns.StackedBars()
    local noClassBar = ns.LayoutFlag("healerBars") -- kein Forever-Heiler hat eine Klassenleiste (Benny 2026-11-07)
    if healer then
        BARS[1].cols, BARS[1].size = 12, SIZE
    end

    for _, def in ipairs(BARS) do bars[#bars + 1] = CreateBar(def) end
    -- Blizzards goldene Flyout-Schiene hinter den Knöpfen weg (gibt es erst nach dem 1. Knopf)
    local flyout = LAB:GetSpellFlyoutFrame()
    if flyout and flyout.Background then flyout.Background:SetAlpha(0) end
    local main, shift, alt, right, inner, third, leftBlock, rightBlock = unpack(bars)

    -- Plätze aus der Bildschirmgröße – laufen bei Größen-/Skalierungswechsel erneut
    ns.OnLayout(function()
        local halfW, halfH = UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
        local margin = ns.Snap(ns.SCREEN_MARGIN)
        local size, barGap = ns.Snap(SIZE), GAP_PIXELS * ns.PixelSize()
        local classBar = ns.layoutFrames.classpower
        if healer then
            -- unterste drei Reihen: Shift, Alt, Hauptleiste (siehe unten); Klassenleiste über der Gruppe
            Place(main, "bar1", "BOTTOM", 0, -halfH + margin + 2 * (size + barGap))
            if classBar and noClassBar then
                classBar:SetAlpha(0)
            elseif classBar then
                -- gestapelt ohne Heiler: Klassenleiste bleibt über den Unitframes (wie bei Mittig)
                local player = ns.frames and ns.frames.player
                local top = player and player:GetTop() and (player:GetTop() - halfH) or -ns.Snap(ns.FRAME_TOP_Y)
                classBar:SetAlpha(1)
                ns.PlaceFromCenter(classBar, "BOTTOM", 0, top + ns.Snap(12))
            end
        else
            -- Hauptleiste mittig, Oberkante auf Höhe des Spielerframes
            local player = ns.frames and ns.frames.player
            local mainTop = player and player:GetTop() and (player:GetTop() - halfH) or -ns.Snap(ns.FRAME_TOP_Y)
            Place(main, "bar1", "TOP", 0, mainTop)
            -- Klassenleiste mit Abstand darüber
            if classBar then
                classBar:SetAlpha(1)
                ns.PlaceFromCenter(classBar, "BOTTOM", 0, main:GetTop() - halfH + ns.Snap(12))
            end
        end
        -- unten: Shift ganz unten, Alt darüber
        Place(shift, "bar2", "BOTTOM", 0, -halfH + margin)
        Place(alt, "bar3", "BOTTOM", 0, -halfH + margin + size + barGap)
        -- rechts: erste Leiste am Rand, zweite innen daneben (senkrecht mittig)
        Place(right, "bar4", "RIGHT", halfW - margin, 0)
        Place(inner, "bar5", "RIGHT", halfW - margin - size - barGap, 0)
        -- Zusatzleisten: dritte senkrechte rechts; unten je ein 6 × 2-Block links und rechts neben
        -- den 12er-Reihen, unten bündig (Benny 2026-11-08, Screenshot)
        Place(third, "bar6", "RIGHT", halfW - margin - 2 * (size + barGap), 0)
        local sideGap = ns.Snap(12)
        local half = ns.ExtraBarWidth() / 2
        Place(leftBlock, "bar7", "BOTTOMRIGHT", -half - sideGap, -halfH + margin)
        Place(rightBlock, "bar8", "BOTTOMLEFT", half + sideGap, -halfH + margin)
    end)

    -- Pet-Leiste unter dem Pet-Frame, genau so breit
    local pet = ns.smallFrames and ns.smallFrames.pet
    if PetActionBar and pet then
        local petHolder = CreateFrame("Frame", "MeredanUIPetBar", UIParent, "SecureHandlerStateTemplate")
        local petSize = (ns.FrameWidth() - 9 * gap) / 10
        AdoptBlizzardBar(PetActionBar, petHolder, "PetActionButton", 10, 10, petSize, "petbar")
        petHolder:SetPoint("TOPLEFT", pet, "BOTTOMLEFT", 0, -gap)
        -- Knöpfe werden auf ganze Pixel gerundet > Reihe ist ein paar Pixel schmaler/breiter als der
        -- Pet-Frame. Frame an die Reihe angleichen, damit beide bündig enden (Benny 2026-11-08).
        ns.AfterCombat(function() pet:SetWidth(petHolder:GetWidth()) end)
        ns.layoutFrames.petbar = petHolder
        framesByKey.petbar = petHolder
    end

    -- Haltungsleiste links über der Alt-Leiste, wächst nach rechts (Standard: Mouseover)
    if StanceBar then
        local stanceHolder = CreateFrame("Frame", "MeredanUIStanceBar", UIParent, "SecureHandlerStateTemplate")
        AdoptBlizzardBar(StanceBar, stanceHolder, "StanceButton", 10, 10, SMALL_SIZE, "stancebar")
        if healer then
            -- Heiler: links neben den unteren Reihen, auf Höhe der Hauptleiste (darüber sitzt die Zauberleiste)
            stanceHolder:SetPoint("BOTTOMRIGHT", main, "BOTTOMLEFT", -ns.Snap(12), 0)
        else
            stanceHolder:SetPoint("BOTTOMLEFT", alt, "TOPLEFT", 0, gap)
        end
        ns.layoutFrames.stancebar = stanceHolder
        framesByKey.stancebar = stanceHolder
    end

    -- Fahrzeug verlassen: Blizzards Knopf rechts neben der Hauptleiste
    local leave = MainMenuBarVehicleLeaveButton
    if leave then
        local function PlaceLeave()
            leave.muiPlacing = true
            leave:SetParent(UIParent)
            leave:ClearAllPoints()
            leave:SetPoint("LEFT", main, "RIGHT", gap, 0)
            leave.muiPlacing = false
        end
        hooksecurefunc(leave, "SetPoint", function() if not leave.muiPlacing and not InCombatLockdown() then PlaceLeave() end end)
        PlaceLeave()
    end

    UpdateBindings()
    ns.ApplyActionBarVisibility()
    ns.ApplyActionBarTexts() -- Pet-/Haltungsknöpfe nach Einstellung
    SkinExtraButtons()
end

ns:On("UPDATE_BINDINGS", UpdateBindings)
-- Mouseover-Heilen: Blizzards Schalter (Optionen > Kampf) folgt der mUI-Einstellung
function ns.ApplyMouseoverCast()
    if GetCVar("enableMouseoverCast") == nil then return end
    SetCVar("enableMouseoverCast", ns.db.mouseoverHeal and "1" or "0")
end

ns:On("PLAYER_LOGIN", function()
    if ns.db.mouseoverHeal then ns.ApplyMouseoverCast() end -- aus: Blizzards eigene Wahl nicht überschreiben
    -- Abklingzeit-Zahlen sind Teil des mUI-Looks: Blizzards Schalter dafür immer an.
    if not C_CVar.GetCVarBool("countdownForCooldowns") then C_CVar.SetCVar("countdownForCooldowns", "1") end
    -- Direkt beim Login (oUF hat seine Frames da schon gebaut): auch nach einem /reload im Kampf
    -- gilt die Kampfsperre erst nach dem Laden – später (Timer) wären die Leisten bis Kampfende weg.
    ns.AfterCombat(Setup)
end)
