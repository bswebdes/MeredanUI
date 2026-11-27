-- Second chat window (setting chatSecond, off by default): Trade chat gets its own window bottom
-- right, mirroring the main chat (same size, at most "medium"). (Forever has no Looking for Group channel.)
--
--                                          [Addon bar]
--   +-------------+                        +-------------+
--   | Chat 1      |                        | Chat 2      |
--   +-------------+                        | Trade       |
--                                          +-------------+
--   [Emote bar]                            [Micro menu]
--
-- The micro menu keeps the bottom row (like the emote bar on the left), both chats share the same
-- bottom line (ns.ChatBottomReserve), the addon bar, tooltip and bag window move above the window
-- (ns.SecondChatTop). It is a normal Blizzard chat window (FCF_OpenNewWindow), undocked and locked.
local _, ns = ...
local L = ns.L

local TRADE = 2  -- zoneChannelID (see Chat/ChatStyle.lua)
-- Channel names as AddChannel wants them, for channels not joined right now (outside cities)
local FALLBACK = {
    deDE = { [TRADE] = "Handel" },
    enUS = { [TRADE] = "Trade" },
    enGB = { [TRADE] = "Trade" },
}
local TAB_SPACE = 22 + 10 -- tab height + gap above a chat window (Chat/ChatStyle.lua)

local frame   -- the window while the setting is on
local placing

local function Enabled() return ns.db and ns.db.chatSecond == true end
local function WindowName() return L["Trade"] end
local function MaxWindows()
    return Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows or NUM_CHAT_WINDOWS or 10
end

-- Our window from an earlier session (Blizzard saves chat windows per character)
local function FindWindow()
    local saved = ns.char and ns.char.chatSecondID
    for i = 3, MaxWindows() do
        local name, _, _, _, _, _, shown = GetChatWindowInfo(i)
        if shown and (i == saved or name == WindowName()) then return _G["ChatFrame" .. i] end
    end
end

local function ChannelNames()
    local names = {}
    local list = { GetChannelList() } -- id, name, disabled, id, name, ...
    for i = 2, #list, 3 do
        local name = tostring(list[i])
        local info = C_ChatInfo.GetChannelInfoFromIdentifier(name)
        if info and info.zoneChannelID == TRADE then names[TRADE] = name end
    end
    local fallback = FALLBACK[GetLocale()]
    if fallback then
        names[TRADE] = names[TRADE] or fallback[TRADE]
    end
    return names
end

local function Has(chatFrame, name)
    for _, value in pairs(chatFrame.channelList or {}) do
        if strupper(value) == strupper(name) then return true end
    end
    return false
end

-- Trade into the second window and out of the main chat (or back). Only changes what differs:
-- adding a channel fires CHANNEL_UI_UPDATE again, which calls this.
local function MoveChannels(on)
    for _, name in pairs(ChannelNames()) do
        if on then
            if not Has(frame, name) then frame:AddChannel(name) end
            if Has(ChatFrame1, name) then ChatFrame1:RemoveChannel(name) end
        elseif not Has(ChatFrame1, name) then
            ChatFrame1:AddChannel(name)
        end
    end
end

local function Relayout()
    if ns.UpdateAddonBar then ns.UpdateAddonBar() end
    if ns.PlaceBagWindow then ns.PlaceBagWindow() end
end

-- Same bottom line and size as the main chat, at the right screen margin
local function Place()
    if not frame or InCombatLockdown() then return end
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    placing = true
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -margin, margin + ns.ChatBottomReserve())
    -- follows the main chat, but never beyond "medium": the right side also holds the quest tracker
    -- and the right action bars
    -- (flush with the micro menu below while it is shown)
    local limit = ns.CHAT_SIZE_MEDIUM or { 440, 160 }
    local width = ns.ChatWidthFromBar(ns.MicroMenuWidth and ns.MicroMenuWidth())
        or math.min(ChatFrame1:GetWidth(), ns.Snap(limit[1]))
    frame:SetSize(width, math.min(ChatFrame1:GetHeight(), ns.Snap(limit[2])))
    -- Undocking leaves the tab where the dock had put it (left, among the main chat's tabs):
    -- hang it over this window, same gap as the main chat's tabs
    local tab = _G[frame:GetName() .. "Tab"]
    if tab then
        tab:ClearAllPoints()
        tab:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, ns.Snap(10))
    end
    -- copy button on the tab line, top right (like the main chat)
    if not frame.muiCopy and ns.CreateChatCopyButton then
        frame.muiCopy = ns.CreateChatCopyButton(frame, function() return frame end, ns.Snap(TAB_SPACE) - 2)
    end
    if ns.ApplyChatGlass then ns.ApplyChatGlass() end -- tab fades with the main chat's tabs
    placing = false
    if FCF_SavePositionAndDimensions then FCF_SavePositionAndDimensions(frame) end
    Relayout() -- chat size changed: addon bar and bag window follow the new top edge
end
ns.PlaceSecondChat = Place

-- Top edge of the window incl. its tab (UIParent units from the screen bottom), nil while off
function ns.SecondChatTop()
    if not (frame and frame:IsShown()) then return nil end
    return ns.Snap(ns.SCREEN_MARGIN) + ns.ChatBottomReserve() + frame:GetHeight() + ns.Snap(TAB_SPACE)
end

function ns.SecondChatFrame() return frame end

local function Create()
    local window, index = FCF_OpenNewWindow(WindowName(), true)
    if not window then return nil end
    ns.char.chatSecondID = index
    return window
end

function ns.ApplySecondChat()
    if InCombatLockdown() then return ns.AfterCombat(ns.ApplySecondChat) end
    local existing = FindWindow()
    if Enabled() then
        local created = not existing
        frame = existing or Create()
        if not frame then
            ns.db.chatSecond = false
            return ns.Print(L["No free chat window left. Close one and try again."])
        end
        if created then ns.Print(L["Second chat window set up: Trade is now bottom right."]) end
        if frame.isDocked then FCF_UnDockFrame(frame) end
        if FCF_SetWindowName and frame.name ~= WindowName() then FCF_SetWindowName(frame, WindowName()) end -- older name
        if FCF_SetLocked then FCF_SetLocked(frame, true) end -- fixed layout, no dragging
        MoveChannels(true)
        Place()
        if DevLog then
            DevLog("MeredanUI", ("SecondChat %s docked=%s shown=%s right=%.0f bottom=%.0f size=%.0fx%.0f"):format(
                frame:GetName(), tostring(frame.isDocked), tostring(frame:IsShown()), frame:GetRight() or -1,
                frame:GetBottom() or -1, frame:GetWidth(), frame:GetHeight()))
        end
    elseif existing then
        frame = existing
        MoveChannels(false)
        FCF_Close(existing)
        frame = nil
        ns.char.chatSecondID = nil
        ns.Print(L["Second chat window removed, Trade is back in the main chat."])
    else
        frame = nil
    end
    Relayout()
end

ns:On("PLAYER_LOGIN", function()
    C_Timer.After(0, function()
        if Enabled() or FindWindow() then ns.ApplySecondChat() end
    end)
    -- Blizzard restores the saved window names after login (UPDATE_CHAT_WINDOWS): rename again
    ns:On("UPDATE_CHAT_WINDOWS", function()
        if frame and Enabled() and frame.name ~= WindowName() and not InCombatLockdown() then
            FCF_SetWindowName(frame, WindowName())
        end
    end)
    -- Trade is only joined in cities: move it once it shows up
    local pending
    ns:On("CHANNEL_UI_UPDATE", function()
        if not (Enabled() and frame) or pending then return end
        pending = true
        C_Timer.After(1, function()
            pending = false
            if Enabled() and frame and not InCombatLockdown() then MoveChannels(true) end
        end)
    end)
end)

-- Something else moved the window (Blizzard restores saved positions): put it back
ns:On("UI_SCALE_CHANGED", function() C_Timer.After(0, Place) end)
hooksecurefunc("FCF_RestorePositionAndDimensions", function(chatFrame)
    if chatFrame == frame and not placing then C_Timer.After(0, Place) end
end)
