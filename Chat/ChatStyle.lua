-- Glass-style chat (inspired by "ls: Glass"): no box, shadowed text over the game world;
-- older messages fade and return on mouseover. Bottom left at the screen margin.
-- Features modeled after Prat3.
--
--   General  Combat Log                 [Copy]   <- tabs in channel color, copy on hover
--   12:04 [G] Koratal: Hi!
--   12:05 [1] Trader: selling ... https://...    <- clickable links (copy)
--   [ flat edit box, only while typing ]
--
-- Blizzard's background, borders, side buttons and tab/edit box art are removed; the windows
-- themselves (tabs, docking, scrolling) stay Blizzard's. Protected messages (Midnight chat
-- lockdown) are never modified.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT = 440, 160 -- narrower on small screens (never into the extra bar)
local TAB_HEIGHT = 22
local TAB_GAP = 10 -- space between tabs and first chat line (Blizzard: 3)
local EDIT_HEIGHT = 22
local FADE_SECONDS = 3
local TABS_LINGER = 1.5        -- tabs stay this long after the mouse leaves, then fade
local GLASS_FADE = 0.3         -- tab fade in/out (seconds)
local SLIDE_SECONDS = 0.18     -- new line slides in from below
local CHANNEL_GAP = 6          -- extra gap when the next message is from another channel

local hidden = CreateFrame("Frame")
hidden:Hide()

local function Kill(region)
    if region then region:SetParent(hidden) end
end

-- Clear all textures of a frame (font strings stay)
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

-- Strip color/link/texture codes (for copying)
local function PlainText(text)
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn.-:", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", L["(protected)"]):gsub("|n", " ")
    -- Escape remaining pipes - a single unknown code would blank the whole edit box
    return (text:gsub("|", "||"))
end

-- Copy window: text to select and copy (Ctrl+C) ------------------------------------------

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
    -- Width from the window size (the scroll child is still 0 wide on first open)
    box:SetWidth(window:GetWidth() - 34)
    box:SetMaxLetters(0)
    box:SetText(text)
    box:SetFocus()
    box:HighlightText()
    C_Timer.After(0, function() -- text height is only known after layout
        window.scroll:SetContentHeight(box:GetHeight())
        window.scroll:SetVerticalScroll(math.max(box:GetHeight() - window.scroll:GetHeight(), 0))
    end)
end

-- Small window for a clicked link: URL highlighted in a flat edit box, sized to fit;
-- Ctrl+C copies, Enter/Escape closes.
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
    -- Width: text + box insets (2x8) + window padding (2x14) + room for the cursor
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
ns.ShowLinkWindow = ShowLinkWindow -- also used by the quest tracker (Wowhead link)

-- Copy the history of the given chat frame
local function CopyChat(frame)
    local lines = {}
    for i = 1, frame:GetNumMessages() do
        local text = frame:GetMessageInfo(i)
        if text and not issecretvalue(text) then lines[#lines + 1] = PlainText(text) end
    end
    ShowCopyWindow(L["Chat history"] .. " – " .. (frame.name or ""), table.concat(lines, "\n"))
end

-- Clickable URLs -----------------------------------------------------------------------

-- Each run of URL characters (no pipe, so never inside Blizzard's link/color codes) is linked
-- if it starts with http(s):// or www. - single pass, so a "www." inside an https URL is
-- not linked twice.
local URL_RUN = "[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+"

-- Custom link type "muiurl": Blizzard's LinkUtil calls our handler for it
local URL_LINK = "muiurl"

local function LinkURLs(text)
    return (text:gsub(URL_RUN, function(run)
        if not (run:match("^https?://%w") or run:match("^www%.[%w%-]+%.")) then return nil end
        local url = run:gsub("[%.,;:%)]+$", "") -- trailing punctuation is not part of the URL
        local rest = run:sub(#url + 1)
        return ((ns.UI.ACCENT_HEX .. "|H%s:%s|h[%s]|h|r%s")):format(URL_LINK, url, url, rest)
    end))
end

-- Click on one of our links opens the link window. Since 12.1.5 SetItemRef fires no event and
-- unknown links end up in ItemRefTooltip, so a registered handler catches them first.
if LinkUtil and LinkUtil.RegisterLinkHandler and not LinkUtil.IsLinkHandlerRegistered(URL_LINK) then
    LinkUtil.RegisterLinkHandler(URL_LINK, function(_, _, linkData)
        if linkData.options and linkData.options ~= "" then ShowLinkWindow(linkData.options) end
        return LinkProcessorResponse.Handled
    end)
end

-- Short channel names --------------------------------------------------------------------

local SHORT = {
    GUILD = "G", OFFICER = "O", PARTY = "P", PARTY_LEADER = "P", RAID = "R", RAID_LEADER = "R",
    RAID_WARNING = "RW", INSTANCE_CHAT = "I", INSTANCE_CHAT_LEADER = "I",
}

local function ShortenChannels(text)
    return (text:gsub("|Hchannel:([^|]-)|h%[(.-)%]|h", function(link, name)
        local kind = link:match("^(%u[%u_]*)")
        local short = SHORT[kind]
        if not short then
            short = name:match("^(%d+)%.") or name:match("^(%d+)") -- "1. General - Zone" -> 1
        end
        if not short then return nil end -- unknown: leave unchanged
        return ("|Hchannel:%s|h[%s]|h"):format(link, short)
    end))
end

-- Wrap the chat frames' AddMessage; only readable (non-secret) text is touched.
-- History survives /reload and logout (like Prat): last lines per character and chat frame
-- are saved and restored on login. Protected lines never.
local HISTORY_LINES = 200
local FlashTab, OnNewMessage, LayoutLines -- defined below

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
        -- Upgrade links from older versions (addon:MeredanUI:url:...) to the new type
        local text = line[1]:gsub("|Haddon:MeredanUI:url:", "|H" .. URL_LINK .. ":")
        frame.muiOriginalAddMessage(frame, text, line[2], line[3], line[4])
    end
end

-- New conversation message in an unselected tab: pulse the label (Midnight only flashes
-- for whispers). Loot, trade, system and combat log don't trigger it - see CONVERSATION.
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
            if ns.ChatClassIcons then text = ns.ChatClassIcons(text) end
            text = LinkURLs(text)
            if not issecretvalue(r) then RecordLine(self, text, r, g, b) end
        end
        original(self, text, r, g, b, ...)
        OnNewMessage(self)
    end
end

-- Timestamps: Blizzard's own (plain "12:04"), toggled in the MUI settings
function ns.ApplyChatTimestamps()
    ns.LookCVar("showTimestamps", ns.db.chatTimestamps and "%H:%M " or "none")
end

-- Look -----------------------------------------------------------------------------------------

local anchor -- invisible frame around chat + tabs (edit box anchor, hover detection)
local HookCombatLog, ApplyEditBoxFont -- defined below
local copyButton

-- Tab text colored by what the window shows: guild green, trade in its channel color, loot
-- in loot color, combat log grey. Detected by content, not by name.
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
    -- General (and everything else): always the accent color. The channel color only exists
    -- once General is joined (late at login) or chat setup ran, so the tab would start white.
    local accent = ns.UI and ns.UI.ACCENT or { 0.557, 0.796, 0.706 }
    return { r = accent[1], g = accent[2], b = accent[3] }
end

local TAB_FONT_SIZE = 14

-- Color a tab; the selected tab gets full color and an underline
local function ColorTab(frame, selected)
    local tab = _G[frame:GetName() .. "Tab"]
    if not (tab and tab.muiLabel) then return end
    if selected == nil then selected = frame == SELECTED_CHAT_FRAME end
    if selected and tab.muiFlash then tab.muiFlash:Stop() end -- seen: stop flashing
    local color = TabColor(frame) or { r = 1, g = 1, b = 1 }
    tab.muiLabel:SetTextColor(color.r, color.g, color.b)
    tab.muiLabel:SetAlpha(selected and 1 or 0.6)
    tab.muiUnderline:SetColorTexture(color.r, color.g, color.b, 1)
    tab.muiUnderline:SetShown(selected)
end

-- Blizzard recolors the tab text on hover/select itself, so we use our own label;
-- Blizzard's text stays (invisible) to keep the tab width.
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
    -- New message in another tab: label pulses (instead of Blizzard's tab glow)
    local flash = label:CreateAnimationGroup()
    flash:SetLooping("BOUNCE")
    local fade = flash:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.25)
    fade:SetDuration(0.6)
    flash:SetScript("OnStop", function() label:SetAlpha(1) end)
    tab.muiFlash = flash
end

-- Chat font size as a step; fade time, line spacing and channel gap are fixed
local CHAT_FONT_SIZES = { small = 12, medium = 14, large = 17 }
local CHAT_FADE_SECONDS, CHAT_LINE_SPACING = 20, 3
function ns.ChatFontSize() return CHAT_FONT_SIZES[ns.db.chatFontSize] or CHAT_FONT_SIZES.medium end

-- Edit box and channel header ("Guild:") use the same font and size as the chat
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
    frame:SetFont(ns.FontFor("text"), size, "") -- chat is body text: mUI text font
end

local function StyleEditBox(editBox)
    if not editBox or editBox.muiStyled then return end
    editBox.muiStyled = true
    ClearTextures(editBox)
    local bg = editBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    local border = ns.AddBorder(editBox)
    -- only visible while actually typing (independent of Blizzard's chat style)
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
    -- Remove the scrollbar entirely (Blizzard re-shows it on hover and on every update, so
    -- reparent instead of hide); mouse wheel and scroll-to-bottom button remain
    Kill(frame.ScrollBar)
    StyleTab(_G[name .. "Tab"])
    StyleEditBox(_G[name .. "EditBox"])
    -- MUI font, size from MUI settings, shadow instead of a box
    ApplyChatFont(frame)
    frame:SetShadowOffset(1, -1)
    frame:SetShadowColor(0, 0, 0, 1)
    -- Glass: messages fade, mouseover brings them back (see HoverTicker)
    frame:SetFading(true)
    frame:SetTimeVisible(CHAT_FADE_SECONDS) -- how long a new message stays fully visible
    frame:SetFadeDuration(FADE_SECONDS)
    -- Restack lines after every redraw (spacing, channel gap)
    hooksecurefunc(frame, "RefreshDisplay", function(self) LayoutLines(self) end)
    if frame ~= ChatFrame2 then -- leave the combat log alone
        -- Glass: new line slides in - the whole text starts one line lower and slides up
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

-- Font size changed (Settings > Chat)
function ns.ApplyChatFont()
    for _, frame in ipairs(ChatFrames()) do
        ApplyChatFont(frame)
        local editBox = _G[frame:GetName() .. "EditBox"]
        if editBox then ApplyEditBoxFont(editBox) end
    end
end

local chatWaitsForFrames = false
local placingChat -- true while we set the point ourselves (ignored by the guard below)
local function PlaceMainChat()
    if InCombatLockdown() then return end
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    -- Emote bar bottom left (Chat/EmoteBar.lua): chat sits above it
    local reserve = ns.EmoteBarReserve and ns.EmoteBarReserve() or 0
    placingChat = true
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", margin, margin + reserve)
    placingChat = false
    -- At most up to the extra bar (bottom center) and never under player/pet frames (large
    -- unit frames on 16:9 reach that far left; same edge as the party frames)
    local space = UIParent:GetWidth() / 2 - (ns.ExtraBarWidth and ns.ExtraBarWidth() / 2 or 250) - 2 * margin
        - (ns.LeftBlockReserve and ns.LeftBlockReserve() or 0) -- action bar 7 bottom left
    local edge = ns.LeftOfPlayerEdge and ns.LeftOfPlayerEdge()
    if edge then
        space = math.min(space, edge - (UIParent:GetLeft() or 0) - 2 * margin)
    elseif not chatWaitsForFrames then
        chatWaitsForFrames = true -- unit frames not placed yet: retry shortly
        C_Timer.After(1, PlaceMainChat)
    end
    ChatFrame1:SetSize(ns.Snap(math.min(WIDTH, space)), ns.Snap(HEIGHT))
    if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(ChatFrame1) end
end

ns.PlaceMainChat = PlaceMainChat

-- Glass --------------------------------------------------------------------------------
-- Tabs (+ copy button, combat log filters) only when needed: mouse over chat, typing or
-- a pulsing tab.

local tabsAlpha, tabsTarget = 0, 0
local lastActive = 0

-- Blizzard draws each message as its own font string (frame.visibleLines), each fading on
-- its own - protected ones too. We only re-anchor them (spacing, channel gap), no measuring;
-- Blizzard's container clips what doesn't fit at the top.

-- Channel identity of a line: Blizzard's chat type id, otherwise its color
local function LineKind(info)
    local id = info.extraData and info.extraData[1]
    if type(id) == "number" and not issecretvalue(id) then return id end
    if info.r and not issecretvalue(info.r) and not issecretvalue(info.g) and not issecretvalue(info.b) then
        return ("%.2f%.2f%.2f"):format(info.r, info.g, info.b)
    end
end

-- After every redraw: restack lines
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
        line:SetSpacing(spacing) -- also between wrapped lines of one message
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

-- Polled every 0.2 s: walk CHAT_FRAMES directly and cache the tab/edit box lookups (no garbage per tick)
local tabOf, editBoxOf = {}, {}
local function ChatPart(cache, name, suffix)
    local part = cache[name]
    if not part then
        part = _G[name .. suffix]
        cache[name] = part
    end
    return part
end

local function AnyTabFlashing()
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local tab = ChatPart(tabOf, name, "Tab")
        if tab and tab.muiFlash and tab.muiFlash:IsPlaying() then return true end
    end
    return false
end

-- Mouse over chat or typing: keep all messages visible, show tabs and copy button.
-- Toggle fading ONCE on enter/leave - calling ResetAllFadeTimes continuously re-sets every
-- line's text and swallows clicks on links.
local showingAll = false

local function HoverTicker()
    local over = anchor:IsMouseOver()
    -- typing = an edit box really has focus (the "active window" stays set without focus)
    local typing = false
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local editBox = ChatPart(editBoxOf, name, "EditBox")
        if editBox and editBox:HasFocus() then typing = true break end
    end
    local active = over or typing
    if active ~= showingAll then
        showingAll = active
        for _, frame in ipairs(ChatFrames()) do
            frame:SetFading(not active)
            if not active then frame:ResetAllFadeTimes() end -- normal visible time from now on
        end
    end
    local now = GetTime()
    if over or typing or AnyTabFlashing() then lastActive = now end
    tabsTarget = now - lastActive < TABS_LINGER and 1 or 0
end

-- Tab dock with some gap above the chat (Blizzard attaches it 3px directly above)
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

    -- Remove side buttons and social button (menu via slash commands, friends via the info bar)
    for _, button in ipairs({ ChatFrameMenuButton, ChatFrameChannelButton, QuickJoinToastButton,
        ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton, TextToSpeechButtonFrame }) do
        Kill(button)
    end

    -- Copy button top right (on chat mouseover): copies the selected chat frame
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
    -- Whispers: Blizzard's own alert -> pulse our tab too
    if FCF_StartAlertFlash then hooksecurefunc("FCF_StartAlertFlash", FlashTab) end
    -- Blizzard recolors tabs on select/flash: reapply our color
    if FCFTab_UpdateColors then
        hooksecurefunc("FCFTab_UpdateColors", function(tab, selected)
            -- Blizzard's chat config window uses this too, with unnamed tabs
            local name = tab and tab.GetName and tab:GetName()
            local frame = name and name:match("^(ChatFrame%d+)Tab$") and _G[name:match("^(ChatFrame%d+)Tab$")]
            if frame then ColorTab(frame, selected and true or false) end
        end)
    end

    if C_AddOns.IsAddOnLoaded("Blizzard_CombatLog") then HookCombatLog() end
    ns.OnLayout(PlaceMainChat) -- also on resolution/scale changes
    -- Guard: if anything else moves the chat (seen after a level-up), move it back and log the
    -- caller to DevLog. Not in Edit Mode; at most every 0.5s (no ping-pong with Blizzard).
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
    -- Edit box only while typing (Blizzard's "IM" style instead of "Classic")
    ns.LookCVar("chatStyle", "im")
end

-- Combat log filter buttons ("My actions" ...) in MUI font: muted, white on hover.
-- Blizzard builds them with the load-on-demand combat log and rebuilds them on every change.
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
        button:SetWidth(button:GetTextWidth() + 13) -- fit width to the new font
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

-- Sound when someone mentions you (nickname or character name) in guild, officer, party,
-- raid, instance or say. Whispers have Blizzard's own sound. Protected messages ignored.
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
    -- Own messages never play a sound (other addons prefix your nickname to your lines).
    -- Checked via GUID (12th arg) plus name without realm.
    local guid = select(10, ...)
    if guid and not issecretvalue(guid) and guid == UnitGUID("player") then return end
    if author and (Ambiguate(author, "none") == UnitName("player") or author:match("^[^%-]+") == UnitName("player")) then return end
    if not (Mentions(message, UnitName("player")) or Mentions(message, ns.root.nickname)) then return end
    if GetTime() - lastMentionSound < 2 then return end
    lastMentionSound = GetTime()
    PlaySound(SOUNDKIT.TELL_MESSAGE, "Master")
end
for _, event in ipairs(MENTION_EVENTS) do ns:On(event, OnMention) end

-- Conversations: event -> message group; all tabs showing that group pulse
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

-- Demo (Settings > Chat): test guild message with your name in the guild tab (or General)
-- - shows mention sound and tab pulsing.
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
-- Blizzard restores saved chat positions on entering the world: place after that
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, PlaceMainChat) end)
-- Blizzard applies its chat position when Edit Mode closes: reapply ours shortly after,
-- outside Blizzard's call chain
EventRegistry:RegisterCallback("EditMode.Exit", function() C_Timer.After(0.1, PlaceMainChat) end, PlaceMainChat) -- own owner key

-- Chat setup (Settings > Chat) ------------------------------------------------------------
-- No custom tabs: Blizzard's default (General + Combat Log) plus MUI channel colors.
-- Leaves the Services channel (boost/sales spam). Reset = Blizzard default.

local SERVICES_ZONE_CHANNEL = 42 -- Blizzard's fixed channel id for Services (name is localized)

local function LeaveServicesChannel()
    local list = { GetChannelList() } -- id, name, disabled, id, name, ...
    for i = 2, #list, 3 do
        local name = tostring(list[i])
        local info = C_ChatInfo.GetChannelInfoFromIdentifier(name)
        if info and info.zoneChannelID == SERVICES_ZONE_CHANNEL then LeaveChannelByName(name) end
    end
end

-- Channel colors by channel kind, not name/number (Forever renumbers channels on zone
-- changes). zoneChannelID: 1 General, 2 Trade, 22 LocalDefense, 23 WorldDefense,
-- 26 LookingForGroup. Reapplied on every channel update.
local CHANNEL_COLORS = {
    [1] = function() return ns.UI.ACCENT end, -- General: Surf Green accent
    [2] = { 1, 0.62, 0.36 },                  -- Trade: orange (Blizzard uses the same pink as General)
    [22] = { 1, 0.45, 0.42 },                 -- LocalDefense: red (attacks)
    [23] = { 1, 0.45, 0.42 },                 -- WorldDefense
    [26] = { 0.55, 0.75, 1 },                 -- LookingForGroup: blue
}
local function ApplyChannelColors()
    local list = { GetChannelList() } -- id, name, disabled, id, name, ...
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
    FCF_ResetChatWindows() -- baseline: General + Combat Log, extra tabs removed
    ApplyChannelColors()
    LeaveServicesChannel()
    FCF_SelectDockFrame(ChatFrame1)
    for _, frame in ipairs(ChatFrames()) do
        StyleChatFrame(frame)
        ColorTab(frame)
    end
    ns.db.chatFontSize = "medium" -- default
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

-- Diagnostics: /mui chatbuttons temporarily restores Blizzard's chat buttons (until /reload)
-- and prints their names to chat + DevLog.
ns.AddCommand("chatbuttons", L["Show Blizzard's chat buttons until /reload"], function()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    local function Report(frame, depth)
        local name = frame:GetName() or ("<" .. (frame:GetObjectType() or "?") .. ">")
        ns.Print("%s%s", string.rep("  ", depth), name)
        if DevLog then DevLog("MUI CHATBTN", depth, name) end
        for _, child in ipairs({ frame:GetChildren() }) do Report(child, depth + 1) end
    end
    -- in a row at screen center (left of the chat would be off screen)
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
end, true)
