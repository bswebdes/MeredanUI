-- Gemeinsamer Baustein für alle Fenster, in denen man mit einem NPC spricht (Händler, Lehrer,
-- Gespräch, Quest …) – Benny 2026-11-06: „einheitliche Fenster bei denen mit NPC interagiert wird“.
--
--   ┌──────────────────────────────────────────────┐  ← Surf-Green-Kante
--   │ [Modell]  Brannol Eaglemoon             [x]  │  ← NPC als kleines 3D-Porträt, Name,
--   │           Tuchmacher                         │     darunter sein Titel (aus dem Tooltip)
--   │ … Inhalt des Fensters …                      │
--
-- Ziehen an der Kopfzeile verschiebt das Fenster frei (wie unter Windows); beim nächsten Öffnen
-- steht es wieder an seinem festen Platz (über dem Chat).
local _, ns = ...

local PAD = 18
local PORTRAIT = 46
ns.NPC_PAD = PAD
ns.NPC_HEADER_BOTTOM = PAD + PORTRAIT -- Unterkante der Kopfzeile (von oben)
ns.NPC_HEIGHT = 640 -- alle NPC-Fenster gleich hoch (Benny 2026-11-06), Breite je Fenster

-- Titel eines NPCs aus seinem Tooltip (zweite Zeile, z. B. „<Tuchmacher>“); Stufen-Zeilen zählen nicht
function ns.NpcTitle(unit)
    local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit or "npc")
    local line = data and data.lines and data.lines[2]
    local text = line and line.leftText
    if not text or (issecretvalue and issecretvalue(text)) or text:find("%d") then return "" end
    return (text:gsub("^<(.*)>$", "%1"))
end

-- Unsere Fenster (Händler, Lehrer, Gespräch, Quest, Bank, Gildenbank) in Öffnungs-Reihenfolge
local managed, order = {}, {}

-- Reiter außerhalb von Blizzard-Fenstern (z. B. Gilde): dort keine Felder an Blizzards Tabelle,
-- deshalb hier gemerkt – Zahl oder Funktion(window) → Zahl
ns.EXTRA_RIGHT = setmetatable({}, { __mode = "k" })
local function ExtraRight(window)
    local extra = window.extraRight or ns.EXTRA_RIGHT[window]
    if type(extra) == "function" then extra = extra(window) end
    return extra or 0
end

-- Frei ziehen an einer Fläche (Kopfzeile); Lage wird nicht gespeichert
function ns.MakeWindowDraggable(window, region)
    window:SetMovable(true)
    if window.SetDontSavePosition then window:SetDontSavePosition(true) end
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", function()
        if InCombatLockdown() and window:IsProtected() then return end
        window.dragged = true -- selbst gezogen: nicht mehr automatisch beiseiterücken
        window:StartMoving()
    end)
    region:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
end

-- Maßstab eines Fensters gegenüber UIParent (z. B. Gilde vergrößert); Lagen in UIParent-Einheiten
local function Ratio(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function Rect(frame)
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not l then return end
    local k = Ratio(frame)
    return l * k, r * k, t * k, b * k
end

local function Overlaps(a, b)
    local al, ar, at, ab = Rect(a)
    local bl, br, bt, bb = Rect(b)
    if not (al and bl) then return false end
    return al < br and ar > bl and ab < bt and at > bb
end

-- Was gerade offen ist und Platz braucht: unsere anderen Fenster (das Gespräch nicht – Quest/Händler
-- ersetzen es) und Blizzards Fenster links/mittig (Charakter, Zauberbuch …)
local placing -- beim Aufrücken: nur die davor geöffneten Fenster zählen (Menge)
local function Occupied(window)
    local list = {}
    for _, other in ipairs(order) do
        if other ~= window and other:IsVisible() and not other.replaceable and (not placing or placing[other]) then
            list[#list + 1] = other
        end
    end
    if GetUIPanel then
        for _, area in ipairs({ "left", "center", "doublewide", "right" }) do
            local panel = GetUIPanel(area)
            -- geskinnte Blizzard-Fenster (Gilde) sind selbst UIPanels: nicht vor sich selbst ausweichen
            if panel and panel ~= window and panel:IsVisible() then list[#list + 1] = panel end
        end
    end
    return list
end

-- Fenster, die sich schließen dürfen, wenn kein Platz mehr ist (wie Blizzards UIPanel-Verwaltung:
-- passt ein neues Fenster nicht mehr daneben, geht das älteste zu). NPC-Gespräche (Händler, Post,
-- Bank, Lehrer, Quest, Auktionshaus …) nie – das würde die Unterhaltung beenden. Benny 2026-11-08.
local CLOSABLE = {
    legacy = true, spellbook = true, talents = true, professions = true, character = true,
    inspect = true, guild = true, friends = true,
}

-- Platz suchen; liefert die gewünschte rechte Kante (inkl. Reiter außen), bevor WoW ans Bild klemmt
-- Rechnet in UIParent-Einheiten (Fenster können eigenen Maßstab haben, z. B. Gilde 1,2-fach);
-- gibt die gewünschte rechte Kante (inkl. Reiter) in UIParent-Einheiten zurück.
local function Place(window)
    local k = Ratio(window)
    window:ClearAllPoints()
    -- gemeinsame Oberkante (Benny 2026-11-08): niedrigere Fenster (z. B. Gilde) hängen oben an der
    -- Linie der Standardhöhe statt unten über dem Chat; höhere (Talente) bleiben unten über dem Chat
    if window:GetHeight() * k < ns.NPC_HEIGHT then
        window:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap((90 + ns.NPC_HEIGHT) / k))
    else
        window:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(90 / k))
    end
    local wantedRight = ((window:GetLeft() or 0) + window:GetWidth()) * k
    -- solange etwas überlappt: rechts daneben, Oberkante wie das andere Fenster (Benny 2026-11-06:
    -- mit Unterkante über dem Chat rutschte es rechts über Aktionsleisten und Einheitenfenster)
    for _ = 1, 6 do
        local right, top
        for _, other in ipairs(Occupied(window)) do
            -- extraRight: Reiter außerhalb des Fensters (Berufe, Zauberbuch) zählen mit
            local ko = Ratio(other)
            local edge = (other:GetRight() + ExtraRight(other)) * ko
            if Overlaps(window, other) and edge > (right or 0) then
                right, top = edge, other:GetTop() * ko
            end
        end
        if not right then break end
        top = math.min(top or window:GetTop() * k, UIParent:GetTop() - ns.SCREEN_MARGIN)
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ns.Snap((right + 12) / k), ns.Snap(top / k))
        wantedRight = right + 12 + window:GetWidth() * k
    end
    return wantedRight + ExtraRight(window) * k
end

-- Fester Platz: über dem Chat (Höhe der Schlachtzug-Frames). Ist dort schon ein Fenster offen, rechts daneben (Benny: „sonst sind die
-- übereinander“). Beim Öffnen aufrufen – setzt freies Verschieben zurück. opening = gerade geöffnet:
-- passt es dann nicht mehr auf den Bildschirm, schließt sich das älteste schließbare mUI-Fenster.
-- Aufrücken (Benny 2026-11-08, wie Blizzard): schließt ein Fenster, ordnen sich die übrigen offenen in
-- Öffnungs-Reihenfolge neu – jedes sieht dabei nur die Fenster, die vor ihm geöffnet wurden.
local function Relayout()
    placing = {}
    for _, window in ipairs(order) do
        if window:IsShown() then
            if not window.dragged and not (InCombatLockdown() and window:IsProtected()) then Place(window) end
            placing[window] = true
        end
    end
    placing = nil
end

function ns.ResetWindowPosition(window, key, opening)
    if not managed[window] then
        managed[window] = key or true
        order[#order + 1] = window
        window:HookScript("OnHide", function() C_Timer.After(0, Relayout) end)
    end
    window.dragged = nil
    for _ = 1, #order do
        local wantedRight = Place(window)
        if not opening or wantedRight <= UIParent:GetRight() - ns.SCREEN_MARGIN then return end
        local oldest
        for _, other in ipairs(order) do -- order: zuerst geöffnet zuerst
            if other ~= window and other:IsShown() and CLOSABLE[managed[other]] then oldest = other break end
        end
        if not oldest then return end
        oldest:Hide()
    end
end

-- Wächter: unser Fenster lebt nur, solange Blizzards (unsichtbar geparktes) Gegenstück offen ist.
-- Ereignisse wie MERCHANT_CLOSED kommen nicht immer an (z. B. beim direkten Wechsel zum nächsten
-- NPC) – bliebe unser Fenster offen, hielte das Spiel die alte Unterhaltung für aktiv und öffnete
-- die neue nicht (Benny: Lehrer ging erst nach Schließen des Händlers auf).
function ns.WatchBlizzardFrame(window, getFrame)
    local elapsed = 0
    window:HookScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        local frame = getFrame()
        if frame and not frame:IsShown() then self:Hide() end
    end)
end

-- Öffnungs-Reihenfolge merken (zuletzt geöffnet = hinten)
local function Opened(window)
    for i, other in ipairs(order) do
        if other == window then table.remove(order, i) break end
    end
    order[#order + 1] = window
end
ns.WindowOpened = Opened
-- Läuft die Unterhaltung dieser Art noch? Blizzards geparkter Rahmen allein reicht nicht: schließt
-- Esc ihn zuerst, bliebe die Unterhaltung im Spiel offen und der NPC reagierte nicht mehr auf
-- Klicks (Benny 2026-11-06). Fragt nur nach der eigenen Art – eine neue Unterhaltung anderer Art
-- (Wechsel zum nächsten NPC) bleibt unberührt.
function ns.StillInteracting(kind, frame)
    if frame and frame:IsShown() then return true end
    local id = Enum.PlayerInteractionType and Enum.PlayerInteractionType[kind]
    return id ~= nil and C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType(id) or false
end

-- Blizzard-Fenster geht auf: unsere offenen (nicht selbst gezogenen) Fenster neu einordnen
hooksecurefunc("ShowUIPanel", function()
    C_Timer.After(0, function()
        for _, window in ipairs(order) do
            if window:IsShown() and not window.dragged then ns.ResetWindowPosition(window, managed[window] ~= true and managed[window] or nil) end
        end
    end)
end)

-- Pergament-Panel als Hintergrund für den ganzen Inhalt eines Fensters (Quest, Gespräch): wie ein
-- Brief – Text, Ziele, Belohnungen und Optionen stehen darauf (Benny 2026-11-06: „find ich toll“).
-- Gibt das Panel zurück; Inhalt mit 20/18 px Innenabstand hineinsetzen.
ns.PARCHMENT_CARD = { 0, 0, 0, 0.35 }       -- Karten/Optionen auf dem Pergament
ns.PARCHMENT_CARD_HOVER = { 0, 0, 0, 0.55 }
ns.PARCHMENT_TEXT = { 0.94, 0.9, 0.82 }     -- warmes Weiß
function ns.CreateParchmentPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    local base = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    base:SetAllPoints()
    base:SetColorTexture(0.1, 0.08, 0.06, 1)
    local art = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    art:SetAllPoints()
    if not art:SetAtlas("QuestBG-Parchment") then art:SetColorTexture(0.6, 0.47, 0.32, 1) end
    art:SetVertexColor(0.3, 0.26, 0.22) -- dunkel, warm
    ns.AddBorder(panel)
    for _, edge in ipairs(ns.AddBorder(panel, true)) do edge:SetVertexColor(1, 0.86, 0.63, 0.07) end
    return panel
end

-- Fenster mit Fläche, Kante, NPC-Kopfzeile und Schließen. key = Name des Fensters (layoutFrames).
function ns.CreateNpcWindow(name, width, height, key, onClose)
    local UI = ns.UI
    local window = CreateFrame("Frame", name, UIParent)
    window:SetSize(width, height)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor)
    local accent = window:CreateTexture(nil, "OVERLAY")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())
    tinsert(UISpecialFrames, name) -- Esc schließt

    -- Kopfzeile: Fläche zum Ziehen, darauf Porträt, Name, Titel und Schließen
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(PAD + PORTRAIT + 6)
    ns.MakeWindowDraggable(window, header)
    window.header = header

    local holder = CreateFrame("Frame", nil, header)
    holder:SetSize(PORTRAIT, PORTRAIT)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    local model = CreateFrame("PlayerModel", nil, holder)
    model:SetAllPoints()
    local fallback = holder:CreateTexture(nil, "ARTWORK")
    fallback:SetAllPoints()
    fallback:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    fallback:Hide()

    window.npcName = UI.Text(header, 16, "LEFT")
    ns.SetFont(window.npcName, 16, "", "bold") -- Fenstertitel (NPC, Gilde …): mUI Bold
    window.npcName:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    window.npcName:SetPoint("RIGHT", header, "RIGHT", -PAD - 36, 0)
    window.npcTitle = UI.Text(header, 12, "LEFT", UI.MUTED)
    window.npcTitle:SetPoint("TOPLEFT", window.npcName, "BOTTOMLEFT", 0, -5)
    window.npcTitle:SetPoint("RIGHT", window.npcName, "RIGHT")

    local close = UI.IconButton(header, "Close", function() window:Hide() end, 26)
    close:SetPoint("TOPRIGHT", -PAD, -PAD)
    window.close = close

    -- NPC zeigen: 3D-Porträt, sonst sein 2D-Porträt (z. B. Gegenstände, Schilder)
    -- icon: festes Bild statt Porträt (z. B. Briefkasten)
    function window:SetNpc(unit, nameText, titleText, icon)
        if icon then
            model:Hide()
            fallback:SetTexture(icon)
            fallback:Show()
            self.npcName:SetText(nameText or "")
            self.npcTitle:SetText(titleText or "")
            return
        end
        unit = unit or "npc"
        -- kennt das Spiel den NPC gerade nicht (Wechsel Gespräch > Lehrer), den zuletzt gezeigten nehmen
        if UnitExists(unit) then
            ns.lastNpc = { name = UnitName(unit), title = ns.NpcTitle(unit) }
        elseif ns.lastNpc then
            nameText = nameText or ns.lastNpc.name
            if not titleText or titleText == "" then titleText = ns.lastNpc.title end
        end
        model:ClearModel()
        local hasModel = false
        if UnitExists(unit) then
            model:SetUnit(unit)
            model:SetPortraitZoom(1)
            model:SetCamDistanceScale(1)
            hasModel = model:GetModelFileID() ~= nil
        end
        model:SetShown(hasModel)
        fallback:SetShown(not hasModel)
        if not hasModel then
            if UnitExists(unit) then
                SetPortraitTexture(fallback, unit)
            else
                fallback:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
            end
        end
        self.npcName:SetText(nameText or UnitName(unit) or "")
        self.npcTitle:SetText(titleText or ns.NpcTitle(unit))
    end

    window.positionKey = key
    if key then
        ns.layoutFrames[key] = window
        ns.ResetWindowPosition(window, key)
    end
    window:HookScript("OnShow", function(self)
        Opened(self)
        ns.ResetWindowPosition(self, self.positionKey, true)
    end)
    if onClose then window:HookScript("OnHide", onClose) end
    return window
end
