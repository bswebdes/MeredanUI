-- Chat im Glass-Stil (Vorbild: Glass / ls: Glass): kein Kasten, Text mit Schatten direkt über
-- der Spielwelt, ältere Nachrichten blenden aus und kommen beim Drüberfahren zurück. Unten
-- links, 25 px Rand. Funktionen nach Prat-Vorbild (Prat3).
--
--   Allgemein  Kampflog                                [Kopieren]   ← Tabs in Kanalfarbe,
--                                                                      Kopieren beim Hover
--   12:04 [G] Benny: Hi!
--   12:05 [1] Händler: verkaufe … https://…               ← Links anklickbar (Kopieren)
--   ┌ Eingabezeile, flach (nur beim Tippen) ┐
--
-- Blizzards Hintergrund, Rahmen, Seitenknöpfe und Tab-/Eingabe-Grafiken verschwinden; die
-- Fenster selbst (Tabs, Docken, Scrollen) bleiben Blizzards. Geschützte Nachrichten
-- (Midnight-Chatsperre) werden nie verändert.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT = 440, 160 -- auf kleinen Bildschirmen schmaler (nie in die Shift-Leiste hinein); Benny 2026-11-07: einen Tick kleiner (vorher 480 × 180)
local TAB_HEIGHT = 22
local TAB_GAP = 10 -- Luft zwischen Tabs und erster Chatzeile (Blizzard: 3)
local EDIT_HEIGHT = 22
local FADE_SECONDS = 3
local TABS_LINGER = 1.5        -- Tabs bleiben nach dem Wegfahren noch so lange, dann blenden sie aus
local GLASS_FADE = 0.3         -- Ein-/Ausblenden der Tabs (Sekunden)
local SLIDE_SECONDS = 0.18     -- neue Zeile gleitet von unten herein
local CHANNEL_GAP = 6          -- zusätzliche Lücke, wenn die nächste Nachricht aus einem anderen Kanal kommt

local hidden = CreateFrame("Frame")
hidden:Hide()

local function Kill(region)
    if region then region:SetParent(hidden) end
end

-- Alle Grafiken eines Frames unsichtbar (Texte bleiben)
local function ClearTextures(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetTexture(nil) end
    end
end

local function ChatFrames()
    local frames = {}
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[name]
        if frame then frames[#frames + 1] = frame end
    end
    return frames
end

-- Text ohne Farb-/Link-/Bildcodes (zum Kopieren)
local function PlainText(text)
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", L["(protected)"]):gsub("|n", " ")
    -- übrige „|“ wörtlich nehmen – ein einziger unbekannter Code lässt sonst das ganze Textfeld leer
    return (text:gsub("|", "||"))
end

-- Kopierfenster: ein Text zum Markieren und Kopieren (Strg+C) --------------------------------

local copyWindow

local function ShowCopyWindow(title, text)
    local UI = ns.UI
    if not copyWindow then
        copyWindow = CreateFrame("Frame", "MeredanUIChatCopy", UIParent)
        copyWindow:SetFrameStrata("DIALOG")
        copyWindow:SetClampedToScreen(true)
        copyWindow:EnableMouse(true)
        copyWindow:SetMovable(true)
        copyWindow:RegisterForDrag("LeftButton")
        copyWindow:SetScript("OnDragStart", copyWindow.StartMoving)
        copyWindow:SetScript("OnDragStop", copyWindow.StopMovingOrSizing)
        UI.Box(copyWindow, { 0.05, 0.05, 0.06, 0.97 })
        tinsert(UISpecialFrames, "MeredanUIChatCopy")
        copyWindow.title = UI.Text(copyWindow, 14, "LEFT", UI.ACCENT)
        copyWindow.title:SetPoint("TOPLEFT", 12, -10)
        UI.IconButton(copyWindow, "Close", function() copyWindow:Hide() end, 22):SetPoint("TOPRIGHT", -8, -8)
        copyWindow.hint = UI.Text(copyWindow, 11, "LEFT", UI.MUTED)
        copyWindow.hint:SetPoint("TOPLEFT", copyWindow.title, "BOTTOMLEFT", 0, -4)

        local scroll = UI.ScrollArea(copyWindow)
        scroll:SetPoint("TOPLEFT", 12, -50)
        scroll:SetPoint("BOTTOMRIGHT", -22, 12)
        local box = CreateFrame("EditBox", nil, scroll.child)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFont(ns.STYLE.font, ns.FontPx(12), "")
        box:SetTextColor(unpack(UI.TEXT))
        box:SetPoint("TOPLEFT")
        box:SetScript("OnEscapePressed", function() copyWindow:Hide() end)
        copyWindow.box, copyWindow.scroll = box, scroll
    end
    local window, box = copyWindow, copyWindow.box
    window:SetSize(620, 420)
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    window.title:SetText(title)
    window.hint:SetText(L["Select with Ctrl+A, copy with Ctrl+C."])
    window:Show()
    -- Breite direkt aus der Fenstergröße (die Scroll-Fläche ist beim ersten Öffnen noch 0 breit)
    box:SetWidth(window:GetWidth() - 34)
    box:SetMaxLetters(0)
    box:SetText(text)
    box:SetFocus()
    box:HighlightText()
    C_Timer.After(0, function() -- Höhe des Textes steht erst nach dem Zeichnen fest
        window.scroll:SetContentHeight(box:GetHeight())
        window.scroll:SetVerticalScroll(math.max(box:GetHeight() - window.scroll:GetHeight(), 0))
    end)
end

-- Kleines Fenster für einen angeklickten Link: Adresse markiert in einem flachen Eingabefeld,
-- so breit wie nötig; Strg+C kopiert, Enter/Escape schließt.
local linkWindow

local function ShowLinkWindow(url)
    local UI = ns.UI
    if not linkWindow then
        linkWindow = CreateFrame("Frame", "MeredanUIChatLink", UIParent)
        linkWindow:SetFrameStrata("DIALOG")
        linkWindow:SetClampedToScreen(true)
        linkWindow:EnableMouse(true)
        linkWindow:SetMovable(true)
        linkWindow:RegisterForDrag("LeftButton")
        linkWindow:SetScript("OnDragStart", linkWindow.StartMoving)
        linkWindow:SetScript("OnDragStop", linkWindow.StopMovingOrSizing)
        UI.Box(linkWindow, { 0.05, 0.05, 0.06, 0.97 })
        tinsert(UISpecialFrames, "MeredanUIChatLink")
        local title = UI.Text(linkWindow, 14, "LEFT", UI.ACCENT)
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText(L["Copy link"])
        UI.IconButton(linkWindow, "Close", function() linkWindow:Hide() end, 22):SetPoint("TOPRIGHT", -8, -8)
        local box = UI.EditBox(linkWindow, 28)
        box:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        box:SetPoint("RIGHT", linkWindow, "RIGHT", -14, 0)
        box:SetScript("OnEscapePressed", function() linkWindow:Hide() end)
        box:SetScript("OnEnterPressed", function() linkWindow:Hide() end)
        local hint = UI.Text(linkWindow, 11, "LEFT", UI.MUTED)
        hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
        hint:SetText(L["Ctrl+C copies, Enter closes."])
        local measure = UI.Text(linkWindow, 12, "LEFT")
        measure:Hide()
        linkWindow.box, linkWindow.measure = box, measure
    end
    local window, box = linkWindow, linkWindow.box
    window.measure:SetText(url)
    -- Breite: Text + Feld-Innenabstand (2×8) + Fensterrand (2×14) + etwas Luft für den Cursor
    local width = math.max(math.min(window.measure:GetStringWidth() + 16 + 28 + 10, 640), 260)
    window:SetSize(ns.Snap(width), ns.Snap(98))
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    window:Show()
    box:SetMaxLetters(0)
    box:SetText(url)
    box:SetCursorPosition(0)
    box:SetFocus()
    box:HighlightText()
end

-- Verlauf des sichtbaren Chatfensters kopieren
local function CopyChat(frame)
    local lines = {}
    for i = 1, frame:GetNumMessages() do
        local text = frame:GetMessageInfo(i)
        if text and not issecretvalue(text) then lines[#lines + 1] = PlainText(text) end
    end
    ShowCopyWindow(L["Chat history"] .. " – " .. (frame.name or ""), table.concat(lines, "\n"))
end

-- Links (URLs) anklickbar machen -------------------------------------------------------------

-- Jede zusammenhängende Folge von URL-Zeichen (ohne „|“, also nie in Blizzards Link-/Farbcodes)
-- wird verlinkt, wenn sie mit http(s):// oder www. beginnt – ein Durchlauf, damit ein
-- „www.“ innerhalb einer https-Adresse nicht nochmal verlinkt wird.
local URL_RUN = "[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+"

-- eigener Link-Typ „muiurl“: Blizzards Link-System (LinkUtil) ruft dafür unseren Handler
local URL_LINK = "muiurl"

local function LinkURLs(text)
    return (text:gsub(URL_RUN, function(run)
        if not (run:match("^https?://%w") or run:match("^www%.[%w%-]+%.")) then return nil end
        local url = run:gsub("[%.,;:%)]+$", "") -- Satzzeichen am Ende gehören nicht zur Adresse
        local rest = run:sub(#url + 1)
        return ("|cff8ecbb4|H%s:%s|h[%s]|h|r%s"):format(URL_LINK, url, url, rest)
    end))
end

-- Klick auf einen unserer Links: Kopierfenster. (12.1.5: SetItemRef feuert kein Ereignis mehr,
-- unbekannte Links landen im ItemRefTooltip – ein eigener Handler fängt sie vorher ab.)
if LinkUtil and LinkUtil.RegisterLinkHandler and not LinkUtil.IsLinkHandlerRegistered(URL_LINK) then
    LinkUtil.RegisterLinkHandler(URL_LINK, function(_, _, linkData)
        if linkData.options and linkData.options ~= "" then ShowLinkWindow(linkData.options) end
        return LinkProcessorResponse.Handled
    end)
end

-- Kanäle kürzen ------------------------------------------------------------------------------

local SHORT = {
    GUILD = "G", OFFICER = "O", PARTY = "P", PARTY_LEADER = "P", RAID = "R", RAID_LEADER = "R",
    RAID_WARNING = "RW", INSTANCE_CHAT = "I", INSTANCE_CHAT_LEADER = "I",
}

local function ShortenChannels(text)
    return (text:gsub("|Hchannel:([^|]-)|h%[(.-)%]|h", function(link, name)
        local kind = link:match("^(%u[%u_]*)")
        local short = SHORT[kind]
        if not short then
            short = name:match("^(%d+)%.") or name:match("^(%d+)") -- „1. Allgemein - Ort“ > 1
        end
        if not short then return nil end -- unbekannt: unverändert lassen
        return ("|Hchannel:%s|h[%s]|h"):format(link, short)
    end))
end

-- AddMessage der Chatfenster umleiten: nur lesbare Texte anfassen
-- Verlauf über /reload und Logout hinaus (wie Prat): pro Charakter und Chatfenster die
-- letzten Zeilen merken und beim Login wieder einsetzen. Geschützte Zeilen nie.
local HISTORY_LINES = 200
local FlashTab, OnNewMessage, LayoutLines -- unten definiert

local function RecordLine(frame, text, r, g, b)
    local history = ns.char.chatHistory
    if not history then
        history = {}
        ns.char.chatHistory = history
    end
    local lines = history[frame:GetName()]
    if not lines then
        lines = {}
        history[frame:GetName()] = lines
    end
    lines[#lines + 1] = { text, r, g, b }
    if #lines > HISTORY_LINES then table.remove(lines, 1) end
end

local function RestoreHistory(frame)
    local lines = ns.char.chatHistory and ns.char.chatHistory[frame:GetName()]
    if not (lines and frame.muiOriginalAddMessage) then return end
    for _, line in ipairs(lines) do
        -- Links aus älteren Versionen (addon:MeredanUI:url:…) auf den neuen Typ heben
        local text = line[1]:gsub("|Haddon:MeredanUI:url:", "|H" .. URL_LINK .. ":")
        frame.muiOriginalAddMessage(frame, text, line[2], line[3], line[4])
    end
end

-- Neue Gesprächsnachricht in einem Tab, der gerade nicht offen ist: Beschriftung pulsieren
-- lassen (Blizzard blinkt in Midnight nur noch bei Flüstern). Beute, Handel, System, Kampflog
-- lösen nichts aus – nur Gespräche (siehe CONVERSATION unten).
FlashTab = function(frame)
    local tab = frame and _G[frame:GetName() .. "Tab"]
    if tab and tab.muiFlash and frame ~= SELECTED_CHAT_FRAME and not tab.muiFlash:IsPlaying() then
        tab.muiFlash:Play()
    end
end

local function WrapAddMessage(frame)
    local original = frame.AddMessage
    frame.muiOriginalAddMessage = original
    frame.AddMessage = function(self, text, r, g, b, ...)
        if type(text) == "string" and not issecretvalue(text) then
            if ns.db.chatShortChannels ~= false then text = ShortenChannels(text) end
            text = LinkURLs(text)
            if not issecretvalue(r) then RecordLine(self, text, r, g, b) end
        end
        original(self, text, r, g, b, ...)
        OnNewMessage(self)
    end
end

-- Zeitstempel: Blizzards eigene Funktion (schlicht „12:04“), an/aus in den MUI-Einstellungen
function ns.ApplyChatTimestamps()
    SetCVar("showTimestamps", ns.db.chatTimestamps and "%H:%M " or "none")
end

-- Look -----------------------------------------------------------------------------------------

local anchor -- unsichtbarer Rahmen um Chat + Tabs (Eingabezeile, Hover-Erkennung)
local HookCombatLog, ApplyEditBoxFont -- unten definiert
local copyButton

-- Tab-Text in der Farbe dessen, was das Fenster zeigt: Gilde grün, Handel/Allgemein in ihrer
-- Kanalfarbe, Beute in Beutefarbe, Kampflog grau. Erkannt am Inhalt, nicht am Namen.
local function ChannelColor(name)
    local id = name and GetChannelName(name)
    local info = id and id > 0 and ChatTypeInfo["CHANNEL" .. id]
    return info
end

local function TabColor(frame)
    if frame == ChatFrame2 then return { r = 0.7, g = 0.7, b = 0.7 } end
    local social = frame:ContainsMessageGroup("SAY")
    if not social then
        if frame:ContainsMessageGroup("GUILD") then return ChatTypeInfo.GUILD end
        if frame:ContainsMessageGroup("LOOT") then return ChatTypeInfo.LOOT end
        if TRADE and frame:ContainsChannel(TRADE) then return ChannelColor(TRADE) end
    end
    -- Allgemein (und alles Übrige): immer mUI-Salbei, nicht über die Kanalfarbe – die gibt es erst,
    -- wenn der Kanal „Allgemein“ beigetreten ist (beim Login später) bzw. „Chat einrichten“ lief;
    -- vorher war der Tab weiß (Benny 2026-11-07: „nicht stabil genug“)
    local accent = ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 }
    return { r = accent[1], g = accent[2], b = accent[3] }
end

local TAB_FONT_SIZE = 14

-- Tab einfärben; der aktive Tab bekommt volle Farbe und einen Strich darunter
local function ColorTab(frame, selected)
    local tab = _G[frame:GetName() .. "Tab"]
    if not (tab and tab.muiLabel) then return end
    if selected == nil then selected = frame == SELECTED_CHAT_FRAME end
    if selected and tab.muiFlash then tab.muiFlash:Stop() end -- angesehen: Blinken aus
    local color = TabColor(frame) or { r = 1, g = 1, b = 1 }
    tab.muiLabel:SetTextColor(color.r, color.g, color.b)
    tab.muiLabel:SetAlpha(selected and 1 or 0.6)
    tab.muiUnderline:SetColorTexture(color.r, color.g, color.b, 1)
    tab.muiUnderline:SetShown(selected)
end

-- Blizzard färbt den Tab-Text bei Hover/Auswahl selbst um – deshalb eine eigene Beschriftung,
-- die nur wir steuern (Blizzards Text bleibt unsichtbar für die Tab-Breite erhalten).
local function StyleTab(tab)
    if not tab or tab.muiStyled then return end
    tab.muiStyled = true
    ClearTextures(tab)
    local text = tab.Text or _G[tab:GetName() .. "Text"]
    if not text then return end
    ns.SetFont(text, TAB_FONT_SIZE, "OUTLINE")
    text:SetAlpha(0)
    local label = ns.CreateText(tab, TAB_FONT_SIZE, "CENTER", "OUTLINE")
    label:SetPoint("CENTER", text, "CENTER")
    label:SetText(text:GetText())
    hooksecurefunc(text, "SetText", function(_, value) label:SetText(value) end)
    tab.muiLabel = label
    local underline = tab:CreateTexture(nil, "OVERLAY")
    underline:SetHeight(2 * ns.PixelSize())
    underline:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    underline:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -2)
    underline:Hide()
    tab.muiUnderline = underline
    -- Neue Nachricht in einem anderen Tab: Beschriftung pulsiert (statt Blizzards Tab-Glanz)
    local flash = label:CreateAnimationGroup()
    flash:SetLooping("BOUNCE")
    local fade = flash:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.25)
    fade:SetDuration(0.6)
    flash:SetScript("OnStop", function() label:SetAlpha(1) end)
    tab.muiFlash = flash
end

-- Chat-Schriftgröße als Stufe; Ausblendzeit, Zeilenabstand und Kanal-Lücke sind fest (Benny 2026-11-07)
local CHAT_FONT_SIZES = { small = 12, medium = 14, large = 17 }
local CHAT_FADE_SECONDS, CHAT_LINE_SPACING = 20, 3
function ns.ChatFontSize() return CHAT_FONT_SIZES[ns.db.chatFontSize] or CHAT_FONT_SIZES.medium end

-- Eingabe und Kanal-Vorspann („Gilde:“) in derselben Schrift und Größe wie der Chat
ApplyEditBoxFont = function(editBox)
    local size = ns.ChatFontSize()
    editBox:SetFont(ns.FontFor("text"), size, "")
    for _, key in ipairs({ "header", "headerSuffix", "NewcomerHint", "prompt" }) do
        local region = editBox[key]
        if region and region.SetFont then region:SetFont(ns.FontFor("text"), size, "") end
    end
end

local function ApplyChatFont(frame)
    local size = ns.ChatFontSize()
    if FCF_SetChatWindowFontSize then FCF_SetChatWindowFontSize(nil, frame, size) end
    frame:SetFont(ns.FontFor("text"), size, "") -- Chat = Fließtext: mUI Text
end

local function StyleEditBox(editBox)
    if not editBox or editBox.muiStyled then return end
    editBox.muiStyled = true
    ClearTextures(editBox)
    local bg = editBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    local border = ns.AddBorder(editBox)
    -- nur sichtbar, solange wirklich getippt wird (unabhängig von Blizzards Chat-Stil)
    local function ShowWhileTyping()
        local typing = editBox:HasFocus()
        bg:SetShown(typing)
        for _, edge in ipairs(border) do edge:SetShown(typing) end
        editBox:SetAlpha(typing and 1 or 0)
    end
    editBox:HookScript("OnEditFocusGained", ShowWhileTyping)
    editBox:HookScript("OnEditFocusLost", ShowWhileTyping)
    editBox:HookScript("OnShow", ShowWhileTyping)
    ShowWhileTyping()
    editBox:ClearAllPoints()
    editBox:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, ns.Snap(4))
    editBox:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, ns.Snap(4))
    editBox:SetHeight(ns.Snap(EDIT_HEIGHT))
    ApplyEditBoxFont(editBox)
end

local function StyleChatFrame(frame)
    if not frame or frame.muiStyled then return end
    frame.muiStyled = true
    local name = frame:GetName()
    for _, suffix in ipairs(CHAT_FRAME_TEXTURES or {}) do Kill(_G[name .. suffix]) end
    Kill(_G[name .. "ButtonFrame"])
    -- Scrollbalken ganz weg (Blizzard blendet ihn beim Drüberfahren ein und zeigt ihn bei jeder
    -- Aktualisierung neu – darum umhängen statt verstecken); Mausrad und „nach unten“-Pfeil bleiben
    Kill(frame.ScrollBar)
    StyleTab(_G[name .. "Tab"])
    StyleEditBox(_G[name .. "EditBox"])
    -- Text in MUI-Schrift, Größe aus den MUI-Einstellungen, Schatten statt Kasten
    ApplyChatFont(frame)
    frame:SetShadowOffset(1, -1)
    frame:SetShadowColor(0, 0, 0, 1)
    -- Glass: Nachrichten blenden aus, beim Drüberfahren kommen sie zurück (siehe Ticker)
    frame:SetFading(true)
    frame:SetTimeVisible(CHAT_FADE_SECONDS) -- so lange bleibt eine neue Nachricht voll sichtbar
    frame:SetFadeDuration(FADE_SECONDS)
    -- Zeilen nach jedem Neuzeichnen neu stapeln (Abstand, Lücke bei Kanalwechsel)
    hooksecurefunc(frame, "RefreshDisplay", function(self) LayoutLines(self) end)
    if frame ~= ChatFrame2 then -- Kampflog nicht anfassen
        -- Glass: neue Zeile gleitet herein – der ganze Text startet eine Zeile tiefer und rutscht hoch
        local slide = frame:CreateAnimationGroup()
        local down = slide:CreateAnimation("Translation")
        down:SetDuration(0)
        down:SetOrder(1)
        local up = slide:CreateAnimation("Translation")
        up:SetDuration(SLIDE_SECONDS)
        up:SetOrder(2)
        up:SetSmoothing("OUT")
        frame.muiSlide, frame.muiSlideDown, frame.muiSlideUp = slide, down, up
        WrapAddMessage(frame)
        RestoreHistory(frame)
    end
    ColorTab(frame)
end

-- Schriftgröße geändert (Einstellungen > Chat)
function ns.ApplyChatFont()
    for _, frame in ipairs(ChatFrames()) do
        ApplyChatFont(frame)
        local editBox = _G[frame:GetName() .. "EditBox"]
        if editBox then ApplyEditBoxFont(editBox) end
    end
end

local chatWaitsForFrames = false
local placingChat -- true, solange wir selbst setzen (Wächter unten ignoriert das)
local function PlaceMainChat()
    if InCombatLockdown() then return end
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    -- Emote-Leiste unten links (Chat/EmoteBar.lua): Chat sitzt darüber
    local reserve = ns.EmoteBarReserve and ns.EmoteBarReserve() or 0
    placingChat = true
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", margin, margin + reserve)
    placingChat = false
    -- höchstens bis kurz vor die Shift-Leiste (unten mittig) und nie unter Spieler/Begleiter (bei
    -- „Groß“ auf 16:9 reichen die Unitframes so weit nach links; gleiche Kante wie die Gruppe)
    local space = UIParent:GetWidth() / 2 - (ns.ExtraBarWidth and ns.ExtraBarWidth() / 2 or 250) - 2 * margin
        - (ns.LeftBlockReserve and ns.LeftBlockReserve() or 0) -- Leiste 7 unten links an
    local edge = ns.LeftOfPlayerEdge and ns.LeftOfPlayerEdge()
    if edge then
        space = math.min(space, edge - (UIParent:GetLeft() or 0) - 2 * margin)
    elseif not chatWaitsForFrames then
        chatWaitsForFrames = true -- Unitframes stehen noch nicht: kurz danach nochmal
        C_Timer.After(1, PlaceMainChat)
    end
    ChatFrame1:SetSize(ns.Snap(math.min(WIDTH, space)), ns.Snap(HEIGHT))
    if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(ChatFrame1) end
end

ns.PlaceMainChat = PlaceMainChat

-- Glass ----------------------------------------------------------------------------------------
-- Tabs (+ Kopier-Knopf, Kampflog-Filter) nur bei Bedarf: Maus über dem Chat, Tippen oder ein
-- pulsierender Tab. Hinter jeder sichtbaren Zeile ein Glass-Streifen.

local tabsAlpha, tabsTarget = 0, 0
local lastActive = 0

-- Blizzards Chat zeichnet jede Nachricht als eigenen Text (frame.visibleLines), der einzeln
-- ausblendet – auch geschützte. Wir stapeln die Zeilen neu (Abstand, Lücke bei Kanalwechsel);
-- nur Anker, nichts wird vermessen. Blizzards Textbehälter schneidet oben ab, was nicht passt.

-- Woran man den Kanal einer Zeile erkennt: Blizzards Chat-Typ-Nummer, sonst die Farbe
local function LineKind(info)
    local id = info.extraData and info.extraData[1]
    if type(id) == "number" and not issecretvalue(id) then return id end
    if info.r and not issecretvalue(info.r) and not issecretvalue(info.g) and not issecretvalue(info.b) then
        return ("%.2f%.2f%.2f"):format(info.r, info.g, info.b)
    end
end

-- Nach jedem Neuzeichnen: Zeilen neu stapeln
LayoutLines = function(frame)
    local lines = frame.visibleLines
    if not lines or frame:GetInsertMode() == SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP then return end
    local spacing = CHAT_LINE_SPACING
    local channelGap = ns.Snap(CHANNEL_GAP)
    local previous, previousKind
    for _, line in ipairs(lines) do
        local info = line.messageInfo
        local kind = info and LineKind(info)
        local gap = 0
        if previous then
            gap = spacing
            if channelGap > 0 and kind and previousKind and kind ~= previousKind then gap = gap + channelGap end
            line:ClearAllPoints()
            line:SetPoint("BOTTOMLEFT", previous, "TOPLEFT", 0, gap)
        else
            line:ClearAllPoints()
            line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        end
        line:SetSpacing(spacing) -- auch zwischen umbrochenen Zeilen einer Nachricht
        previous, previousKind = line, kind
    end
end

OnNewMessage = function(frame)
    local slide = frame.muiSlide
    if not (slide and frame == SELECTED_CHAT_FRAME and frame:IsVisible() and frame:AtBottom()) then return end
    local _, size = frame:GetFont()
    local height = (size or 16) + CHAT_LINE_SPACING
    frame.muiSlideDown:SetOffset(0, -height)
    frame.muiSlideUp:SetOffset(0, height)
    slide:Stop()
    slide:Play()
end

local function SetGlassAlpha()
    GeneralDockManager:SetAlpha(tabsAlpha)
    copyButton:SetAlpha(tabsAlpha)
    copyButton:EnableMouse(tabsAlpha > 0.5)
    if CombatLogQuickButtonFrame_Custom then CombatLogQuickButtonFrame_Custom:SetAlpha(tabsAlpha) end
end

local function Toward(value, target, step)
    if value < target then return math.min(value + step, target) end
    return math.max(value - step, target)
end

local function GlassOnUpdate(_, elapsed)
    if tabsAlpha == tabsTarget then return end
    tabsAlpha = Toward(tabsAlpha, tabsTarget, elapsed / GLASS_FADE)
    SetGlassAlpha()
end

local function AnyTabFlashing()
    for _, frame in ipairs(ChatFrames()) do
        local tab = _G[frame:GetName() .. "Tab"]
        if tab and tab.muiFlash and tab.muiFlash:IsPlaying() then return true end
    end
    return false
end

-- Maus über dem Chat oder Tippen: alle Nachrichten sichtbar halten, Tabs und Kopier-Knopf zeigen.
-- Dafür das Ausblenden EINMAL aus- und beim Verlassen wieder einschalten – nicht laufend
-- ResetAllFadeTimes: das zeichnet jede Zeile neu (SetText) und verschluckt so Klicks auf Links.
local showingAll = false

local function HoverTicker()
    local over = anchor:IsMouseOver()
    -- tippen = eine Eingabezeile hat wirklich den Fokus („aktives Fenster“ bleibt auch ohne gesetzt)
    local typing = false
    for _, frame in ipairs(ChatFrames()) do
        local editBox = _G[frame:GetName() .. "EditBox"]
        if editBox and editBox:HasFocus() then typing = true end
    end
    local active = over or typing
    if active ~= showingAll then
        showingAll = active
        for _, frame in ipairs(ChatFrames()) do
            frame:SetFading(not active)
            if not active then frame:ResetAllFadeTimes() end -- ab jetzt wieder die normale Zeit sichtbar
        end
    end
    local now = GetTime()
    if over or typing or AnyTabFlashing() then lastActive = now end
    tabsTarget = now - lastActive < TABS_LINGER and 1 or 0
end

-- Tab-Leiste mit etwas Abstand über den Chat (Blizzard hängt sie mit 3 px direkt dran)
local function PlaceTabs(dock, chatFrame)
    dock:ClearAllPoints()
    dock:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, ns.Snap(TAB_GAP))
    dock:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 0, ns.Snap(TAB_GAP))
end

local function Setup()
    anchor = CreateFrame("Frame", "MeredanUIChatAnchor", UIParent)
    anchor:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(TAB_HEIGHT + TAB_GAP))
    anchor:SetPoint("BOTTOMRIGHT", ChatFrame1, "BOTTOMRIGHT", 0, 0)

    for _, frame in ipairs(ChatFrames()) do StyleChatFrame(frame) end
    if GeneralDockManager and GeneralDockManager.primary then PlaceTabs(GeneralDockManager, GeneralDockManager.primary) end
    if FCFDock_SetPrimary then hooksecurefunc("FCFDock_SetPrimary", PlaceTabs) end
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            for _, frame in ipairs(ChatFrames()) do StyleChatFrame(frame) end
        end)
    end

    -- Seitenknöpfe und Sozial-Knopf weg (Menü per /-Befehle, Freunde über die Info-Leiste)
    for _, button in ipairs({ ChatFrameMenuButton, ChatFrameChannelButton, QuickJoinToastButton,
        ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton, TextToSpeechButtonFrame }) do
        Kill(button)
    end

    -- Kopier-Knopf oben rechts (nur bei Maus über dem Chat): kopiert das gerade gewählte Fenster
    copyButton = CreateFrame("Button", nil, anchor)
    copyButton:SetSize(18, 18)
    copyButton:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, -2)
    copyButton:SetFrameStrata("MEDIUM")
    local icon = ns.UI.Icon(copyButton, "Copy", 14)
    icon:SetPoint("CENTER")
    copyButton:SetScript("OnEnter", function(self)
        icon:SetVertexColor(unpack(ns.UI.ACCENT))
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(L["Copy chat"], 1, 1, 1)
        GameTooltip:Show()
    end)
    copyButton:SetScript("OnLeave", function()
        icon:SetVertexColor(unpack(ns.UI.TEXT))
        GameTooltip:Hide()
    end)
    copyButton:SetScript("OnClick", function()
        CopyChat(SELECTED_CHAT_FRAME or ChatFrame1)
    end)
    SetGlassAlpha()
    anchor:SetScript("OnUpdate", GlassOnUpdate)
    C_Timer.NewTicker(0.2, HoverTicker)
    -- Flüstern: Blizzards eigener Hinweis > bei uns ebenfalls pulsieren
    if FCF_StartAlertFlash then hooksecurefunc("FCF_StartAlertFlash", FlashTab) end
    -- Blizzard färbt Tabs beim Auswählen/Blinken neu: danach wieder unsere Farbe
    if FCFTab_UpdateColors then
        hooksecurefunc("FCFTab_UpdateColors", function(tab, selected)
            -- auch Blizzards Chat-Einstellungsfenster nutzt das, mit namenlosen Tabs
            local name = tab and tab.GetName and tab:GetName()
            local frame = name and name:match("^(ChatFrame%d+)Tab$") and _G[name:match("^(ChatFrame%d+)Tab$")]
            if frame then ColorTab(frame, selected and true or false) end
        end)
    end

    if C_AddOns.IsAddOnLoaded("Blizzard_CombatLog") then HookCombatLog() end
    ns.OnLayout(PlaceMainChat) -- auch bei Größen-/Skalierungswechsel
    -- Wächter (Benny 2026-11-07: Chat rutschte nach einem Stufenaufstieg nach oben): verschiebt
    -- jemand anderes den Chat, sofort zurück an unseren Platz und den Verursacher ins DevLog schreiben.
    -- Nicht im Bearbeitungsmodus; höchstens alle 0,5 s (kein Ping-Pong mit Blizzard).
    local lastFix = 0
    hooksecurefunc(ChatFrame1, "SetPoint", function()
        if placingChat then return end
        if EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive() then return end
        if DevLog then DevLog("MeredanUI", "Chat verschoben von: " .. (debugstack(2, 3, 0) or "?"):gsub("\n", " | ")) end
        local now = GetTime()
        if now - lastFix < 0.5 then return end
        lastFix = now
        if InCombatLockdown() then ns.AfterCombat(PlaceMainChat) else C_Timer.After(0, PlaceMainChat) end
    end)
    ns.ApplyChatTimestamps()
    -- Eingabezeile nur beim Tippen (Blizzards „Sofortnachrichten“-Stil statt „Klassisch“)
    SetCVar("chatStyle", "im")
end

-- Kampflog-Filterknöpfe („Meine Aktionen“ …) in MUI-Schrift: gedämpft, beim Hover weiß.
-- Die Knöpfe baut Blizzard erst mit dem Kampflog (lädt bei Bedarf) und bei jeder Änderung neu.
local quickNormal, quickHighlight
local function StyleCombatLogButtons()
    if not quickNormal then
        quickNormal = CreateFont("MeredanUIChatQuickButtonFont")
        quickNormal:SetFont(ns.STYLE.font, ns.FontPx(13), "OUTLINE")
        quickNormal:SetTextColor(unpack(ns.UI.MUTED))
        quickHighlight = CreateFont("MeredanUIChatQuickButtonHighlightFont")
        quickHighlight:SetFont(ns.STYLE.font, ns.FontPx(13), "OUTLINE")
        quickHighlight:SetTextColor(1, 1, 1)
    end
    local i = 1
    while _G["CombatLogQuickButtonFrameButton" .. i] do
        local button = _G["CombatLogQuickButtonFrameButton" .. i]
        button:SetNormalFontObject(quickNormal)
        button:SetHighlightFontObject(quickHighlight)
        button:SetWidth(button:GetTextWidth() + 13) -- Breite zur neuen Schrift passend
        i = i + 1
    end
end

HookCombatLog = function()
    if not Blizzard_CombatLog_Update_QuickButtons then return end
    hooksecurefunc("Blizzard_CombatLog_Update_QuickButtons", StyleCombatLogButtons)
    StyleCombatLogButtons()
end

ns:On("ADDON_LOADED", function(_, name)
    if name == "Blizzard_CombatLog" then HookCombatLog() end
end)

-- Ton, wenn jemand dich erwähnt (Spitzname oder Charaktername) – Gilde, Offizier, Gruppe,
-- Raid, Instanz, Sagen. Flüstern hat Blizzards eigenen Ton. Geschützte Nachrichten ignoriert.
local MENTION_EVENTS = { "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_SAY" }
local lastMentionSound = 0

local function Mentions(text, name)
    if not name or name == "" then return false end
    local escaped = name:lower():gsub("(%W)", "%%%1")
    return text:lower():find("%f[%w]" .. escaped .. "%f[%W]") ~= nil
end

local function OnMention(_, message, author, ...)
    if not ns.db.chatMentionSound then return end
    if issecretvalue(message) or issecretvalue(author) then return end
    -- eigene Nachricht: nie ein Ton (Benny 2026-11-07: andere Addons schreiben deinen Spitznamen
    -- vor jede deiner Zeilen). Sicher über die GUID (12. Wert), dazu der Name ohne Server.
    local guid = select(10, ...)
    if guid and not issecretvalue(guid) and guid == UnitGUID("player") then return end
    if author and (Ambiguate(author, "none") == UnitName("player") or author:match("^[^%-]+") == UnitName("player")) then return end
    if not (Mentions(message, UnitName("player")) or Mentions(message, ns.root.nickname)) then return end
    if GetTime() - lastMentionSound < 2 then return end
    lastMentionSound = GetTime()
    PlaySound(SOUNDKIT.TELL_MESSAGE, "Master")
end
for _, event in ipairs(MENTION_EVENTS) do ns:On(event, OnMention) end

-- Gespräche: Ereignis > Nachrichtengruppe; pulsieren lassen alle Tabs, die diese Gruppe zeigen
local CONVERSATION = {
    CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "OFFICER",
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT_LEADER",
    CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER",
}
for event, group in pairs(CONVERSATION) do
    ns:On(event, function()
        for _, frame in ipairs(ChatFrames()) do
            if frame:ContainsMessageGroup(group) then FlashTab(frame) end
        end
    end)
end

-- Demo (Einstellungen > Chat): eine Test-Gildennachricht mit deinem Namen in den Gilden-Tab
-- (falls vorhanden, sonst Allgemein) – zeigt Erwähnungs-Ton und Pulsieren des Tabs.
local function GuildFrame()
    for _, frame in ipairs(ChatFrames()) do
        if frame ~= ChatFrame1 and frame:ContainsMessageGroup("GUILD") then return frame end
    end
    return ChatFrame1
end

ns.ChatDemo = {
    Start = function()
        local frame = GuildFrame()
        local name = ns.root.nickname or UnitName("player")
        local info = ChatTypeInfo.GUILD
        local text = ("|Hchannel:GUILD|h[Guild]|h Test: %s"):format(L["Hey %s, are you there?"]:format(name))
        frame:AddMessage(text, info.r, info.g, info.b)
        FlashTab(frame)
        lastMentionSound = 0
        OnMention(nil, text, "Test")
    end,
    Stop = function() end,
    IsActive = function() return false end,
}

ns:On("PLAYER_LOGIN", Setup)
-- Blizzard stellt gespeicherte Chat-Positionen beim Betreten der Welt wieder her: danach setzen
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, PlaceMainChat) end)
-- Blizzard wendet beim Schließen des Bearbeitungsmodus seine Chat-Position an: danach wieder unsere
-- (einen Moment später, außerhalb von Blizzards Ablauf)
EventRegistry:RegisterCallback("EditMode.Exit", function() C_Timer.After(0.1, PlaceMainChat) end, PlaceMainChat) -- eigener Besitzer

-- Chat einrichten (Einstellungen > Chat) -------------------------------------------------------
-- Keine eigenen Tabs: Blizzards Standard (alles in Allgemein + Kampflog), dazu MUI-Kanalfarben.
-- Den Services-Kanal (Boost-/Verkaufs-Spam) verlassen wir. Zurücksetzen = Blizzard-Standard.

local SERVICES_ZONE_CHANNEL = 42 -- Blizzards feste Kanal-ID für „Services“ (Name ist lokalisiert)

local function LeaveServicesChannel()
    local list = { GetChannelList() } -- id, name, disabled, id, name, …
    for i = 2, #list, 3 do
        local name = tostring(list[i])
        local info = C_ChatInfo.GetChannelInfoFromIdentifier(name)
        if info and info.zoneChannelID == SERVICES_ZONE_CHANNEL then LeaveChannelByName(name) end
    end
end

-- Kanalfarben nach Kanal-Art statt Name/Nummer (Forever vergibt Nummern bei Zonenwechseln neu; Benny
-- 2026-11-08). zoneChannelID: 1 Allgemein, 2 Handel, 22 Lokale Verteidigung, 23 Weltverteidigung,
-- 26 Suche nach Gruppe. Wird bei jedem Kanal-Update neu gesetzt.
local CHANNEL_COLORS = {
    [1] = function() return ns.UI.ACCENT end, -- Allgemein: Surf Green wie mUI
    [2] = { 1, 0.62, 0.36 },                  -- Handel: Orange (bei Blizzard wie Allgemein rosa)
    [22] = { 1, 0.45, 0.42 },                 -- Lokale Verteidigung: Rot (Angriffe)
    [23] = { 1, 0.45, 0.42 },                 -- Weltverteidigung
    [26] = { 0.55, 0.75, 1 },                 -- Suche nach Gruppe: Blau
}
local function ApplyChannelColors()
    local list = { GetChannelList() } -- id, name, disabled, id, name, …
    for i = 1, #list, 3 do
        local id, name = list[i], list[i + 1]
        local info = name and C_ChatInfo.GetChannelInfoFromIdentifier(tostring(name))
        local color = info and CHANNEL_COLORS[info.zoneChannelID]
        if type(color) == "function" then color = color() end
        if color and id then ChangeChatColor("CHANNEL" .. id, unpack(color)) end
    end
end
ns:On("CHANNEL_UI_UPDATE", function() C_Timer.After(0.5, ApplyChannelColors) end)
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, ApplyChannelColors) end)

function ns.SetupChat()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    FCF_ResetChatWindows() -- Ausgangslage: Allgemein + Kampflog, frühere Zusatz-Tabs verschwinden
    ApplyChannelColors()
    LeaveServicesChannel()
    FCF_SelectDockFrame(ChatFrame1)
    for _, frame in ipairs(ChatFrames()) do
        StyleChatFrame(frame)
        ColorTab(frame)
    end
    ns.db.chatFontSize = "medium" -- Standard (Benny 2026-11-07: 16 war zu groß)
    ns.ApplyChatFont()
    PlaceMainChat()
    ns.Print(L["Chat set up with mUI colors."])
end

function ns.ResetChat()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    FCF_ResetChatWindows()
    for _, frame in ipairs(ChatFrames()) do StyleChatFrame(frame) end
    PlaceMainChat()
    ns.Print(L["Chat reset to Blizzard's default."])
end

-- Diagnose (Forever, Phasen-Knopf gesucht): /mui chatbuttons holt Blizzards Chat-Knopfleiste und
-- die versteckten Knöpfe vorübergehend zurück (bis /reload) und schreibt ihre Namen in Chat + DevLog.
ns.AddCommand("chatbuttons", "show Blizzard's chat buttons until /reload (diagnostics)", function()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    local function Report(frame, depth)
        local name = frame:GetName() or ("<" .. (frame:GetObjectType() or "?") .. ">")
        ns.Print("%s%s", string.rep("  ", depth), name)
        if DevLog then DevLog("MUI CHATBTN", depth, name) end
        for _, child in ipairs({ frame:GetChildren() }) do Report(child, depth + 1) end
    end
    -- als Reihe mitten auf den Bildschirm (links vom Chat wäre außerhalb des Bildes)
    local x = -150
    for _, button in ipairs({ ChatFrameMenuButton, ChatFrameChannelButton, QuickJoinToastButton,
        ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton, TextToSpeechButtonFrame }) do
        if button then
            button:SetParent(UIParent)
            button:ClearAllPoints()
            button:SetPoint("CENTER", UIParent, "CENTER", x, 100)
            button:SetFrameStrata("DIALOG")
            button:SetAlpha(1)
            button:Show()
            x = x + 50
            Report(button, 0)
        end
    end
    ns.Print("Chat-Knöpfe sind bis zum nächsten /reload sichtbar (Bildschirmmitte).")
end)
