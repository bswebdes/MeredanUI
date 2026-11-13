-- Roleplay emote bar: icon buttons for Blizzard's animated emotes (wave, bow, kneel ...).
-- Click performs the emote (at the target, if any). Bottom left, mirroring the micro menu;
-- the chat moves above it. Emotes chosen in Settings > Chat; names from Blizzard's globals.
-- During chat lockdown (boss, M+, PvP) emotes are blocked for addons; a click only prints a hint.
local _, ns = ...
local L = ns.L

local SIZE = 28        -- same as the micro menu
local GAP_PIXELS = 6   -- 4px visible (borders sit outside), like micro menu and action bars

-- Emotes by theme (order = bar order). Animated ones from Blizzard's EmoteList plus RP
-- classics like thank, welcome, hug.
ns.EMOTE_GROUPS = {
    { title = "Greeting & farewell", list = { "WAVE", "HELLO", "WELCOME", "BOW", "CURTSEY", "SALUTE", "HUG", "BYE" } },
    { title = "Answers", list = { "YES", "NO", "AGREE", "THANK", "SORRY", "SHRUG", "QUESTION", "CONFUSED" } },
    { title = "Feelings", list = { "LAUGH", "GIGGLE", "SMILE", "CRY", "SAD", "SIGH", "SHY", "BLUSH", "ANGRY", "BORED" } },
    { title = "Celebrating & fun", list = { "CHEER", "APPLAUD", "DANCE", "CONGRATULATE", "VICTORY", "KISS", "FLIRT", "WINK", "CHICKEN", "RUDE" } },
    { title = "Posture & gestures", list = { "SIT", "STAND", "KNEEL", "SLEEP", "LEAN", "POINT", "FLEX", "BEG", "PRAY", "ROAR", "THREATEN", "TALK", "EAT", "DRINK" } },
}
ns.EMOTES = {}
for _, group in ipairs(ns.EMOTE_GROUPS) do
    for _, token in ipairs(group.list) do ns.EMOTES[#ns.EMOTES + 1] = token end
end
-- Defaults: the most common RP emotes (twelve, the bar's maximum)
ns.EMOTE_MAX = 12
ns.EMOTE_DEFAULTS = {
    WAVE = true, BOW = true, DANCE = true, APPLAUD = true, LAUGH = true, CRY = true, SALUTE = true,
    SHY = true, KISS = true, SIT = true, KNEEL = true, POINT = true,
}

local bar
local buttons = {}

-- "/wave" -> "Wave" (Blizzard's localized slash command)
local labels
function ns.EmoteLabel(token)
    if not labels then
        labels = {}
        for i = 1, (MAXEMOTEINDEX or 600) do
            local t = _G["EMOTE" .. i .. "_TOKEN"]
            if t then
                local cmd = _G["EMOTE" .. i .. "_CMD1"]
                if cmd then labels[t] = cmd:gsub("^/", ""):gsub("^%l", string.upper) end
            end
        end
    end
    return labels[token] or token:lower():gsub("^%l", string.upper)
end

local function Chosen(token)
    local choice = ns.db.emoteBarEmotes and ns.db.emoteBarEmotes[token]
    if choice == nil then return ns.EMOTE_DEFAULTS[token] or false end
    return choice
end
ns.EmoteChosen = Chosen

function ns.EmoteChosenCount()
    local count = 0
    for _, token in ipairs(ns.EMOTES) do if Chosen(token) then count = count + 1 end end
    return count
end

local function Perform(token)
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        ns.Print(L["Emotes are locked right now (boss fight, Mythic+ or PvP)."])
        return
    end
    C_ChatInfo.PerformEmote(token)
end

-- Icons use the chat emote color (orange by default; follows custom chat colors)
local function EmoteColor()
    local info = ChatTypeInfo and ChatTypeInfo.EMOTE
    if info and info.r then return { info.r, info.g, info.b } end
    return { 1, 0.5, 0.25 }
end

local function CreateButton(token)
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(ns.Snap(SIZE), ns.Snap(SIZE))
    local bg = ns.UI.Box(button, ns.STYLE.panelColor)
    button.icon = ns.UI.Icon(button, "Emote" .. token, SIZE - 8, EmoteColor())
    button.icon:SetPoint("CENTER")
    button:SetScript("OnEnter", function(self)
        bg:SetColorTexture(unpack(ns.UI.HOVER))
        self.icon:SetVertexColor(unpack(ns.UI.ACCENT))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.EmoteLabel(token), 1, 1, 1)
        if UnitExists("target") then
            GameTooltip:AddLine(L["At: %s"]:format(UnitName("target") or ""), unpack(ns.UI.MUTED))
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        bg:SetColorTexture(unpack(ns.STYLE.panelColor))
        self.icon:SetVertexColor(unpack(EmoteColor()))
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function() Perform(token) end)
    buttons[token] = button
    return button
end

-- Visibility; always shown in RP mode (Chat/RPMode.lua)
local function Mode()
    if ns.RPModeActive and ns.RPModeActive() then return "always" end
    return ns.VisibilityMode(ns.db.emoteBar or "hidden")
end

-- Mask button at the end toggles RP mode (accent-tinted while active)
local function RPButton()
    if ns.rpButton then return ns.rpButton end
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(ns.Snap(SIZE), ns.Snap(SIZE))
    local bg = ns.UI.Box(button, ns.STYLE.panelColor)
    button.icon = ns.UI.Icon(button, "RPMode", SIZE - 8, nil, true) -- the emote bar stays flat
    button.icon:SetPoint("CENTER")
    -- Icon is accent-colored when off (too dark otherwise); on = accent-tinted background
    local function Color()
        local on = ns.RPModeActive and ns.RPModeActive()
        button.icon:SetVertexColor(unpack(on and { 1, 1, 1 } or ns.UI.ACCENT))
        local a = ns.UI.ACCENT
        if on then bg:SetColorTexture(a[1], a[2], a[3], 0.45) else bg:SetColorTexture(unpack(ns.STYLE.panelColor)) end
    end
    button.UpdateColor = Color
    button:SetScript("OnEnter", function(self)
        bg:SetColorTexture(unpack(ns.UI.HOVER))
        self.icon:SetVertexColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["RP mode"], 1, 1, 1)
        GameTooltip:AddLine(L["Hides everything except chat and emotes. Again to show it all. Also: /rp"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        Color()
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function() if ns.ToggleRPMode then ns.ToggleRPMode() end end)
    Color()
    ns.rpButton = button
    return button
end

local function Layout()
    if not bar then return end
    local size, gap = ns.Snap(SIZE), GAP_PIXELS * ns.PixelSize()
    local x, shown = 0, 0
    for _, token in ipairs(ns.EMOTES) do
        local button = buttons[token] or CreateButton(token)
        if Chosen(token) and shown < ns.EMOTE_MAX then -- older picks beyond twelve stay hidden
            shown = shown + 1
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
            button:Show()
            x = x + size + gap
        else
            button:Hide()
        end
    end
    -- RP button last, same spacing
    local rp = RPButton()
    rp:ClearAllPoints()
    rp:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
    x = x + size + gap
    bar:SetSize(math.max(x - gap, size), size)
end

-- Visibility like the other bars: "always", "mouseover", "hidden"
function ns.UpdateEmoteBar()
    if not bar then return end
    local color = EmoteColor()
    for _, button in pairs(buttons) do button.icon:SetVertexColor(unpack(color)) end
    Layout()
    local mode = Mode()
    bar:SetShown(mode ~= "hidden")
    bar.muiMouseover = mode == "mouseover"
    if ns.PlaceMainChat then ns.PlaceMainChat() end -- chat makes room / moves back
end

-- Bottom left at the screen margin (mirrors the micro menu); chat sits above
local function PlaceDefault()
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    local cx, cy = UIParent:GetCenter()
    ns.PlaceFromCenter(bar, "BOTTOMLEFT", margin - cx, margin - cy)
end

-- Space the chat must leave free at the bottom (when the bar is visible)
function ns.EmoteBarReserve()
    if not bar then return 0 end
    if Mode() == "hidden" then return 0 end
    return ns.Snap(SIZE) + ns.Snap(28) -- gap to the chat
end

ns:On("PLAYER_LOGIN", function()
    bar = CreateFrame("Frame", "MeredanUIEmoteBar", UIParent)
    bar:SetFrameStrata("LOW")
    Layout()
    ns.layoutFrames.emotes = bar
    if ns.RegisterMouseover then ns.RegisterMouseover(bar) end
    ns.OnLayout(PlaceDefault)
    PlaceDefault()
    ns.UpdateEmoteBar()
end)

-- Chat colors changed: recolor icons
ns:On("UPDATE_CHAT_COLOR", function(_, chatType)
    if chatType == "EMOTE" or chatType == "TEXT_EMOTE" then ns.UpdateEmoteBar() end
end)
