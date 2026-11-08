-- Shared base for all NPC interaction windows (merchant, trainer, gossip, quest, ...): Surf Green top
-- edge, header with 3D portrait, NPC name and title (from the tooltip), close button.
-- Dragging the header moves the window freely; the next open puts it back at its fixed spot above chat.
local _, ns = ...

local PAD = 18
local PORTRAIT = 46
ns.NPC_PAD = PAD
ns.NPC_HEADER_BOTTOM = PAD + PORTRAIT -- header bottom edge (from top)
ns.NPC_HEIGHT = 640 -- all NPC windows share this height; width varies per window

-- NPC title from its tooltip (second line, e.g. "<Tailor>"); level lines are ignored
function ns.NpcTitle(unit)
    local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit or "npc")
    local line = data and data.lines and data.lines[2]
    local text = line and line.leftText
    if not text or (issecretvalue and issecretvalue(text)) or text:find("%d") then return "" end
    return (text:gsub("^<(.*)>$", "%1"))
end

-- Our windows (merchant, trainer, gossip, quest, bank, guild bank) in opening order
local managed, order = {}, {}

-- Tabs sticking out of Blizzard frames (e.g. guild): kept here to avoid writing fields onto Blizzard's
-- table (taint). Value is a number or function(window) -> number.
ns.EXTRA_RIGHT = setmetatable({}, { __mode = "k" })
local function ExtraRight(window)
    local extra = window.extraRight or ns.EXTRA_RIGHT[window]
    if type(extra) == "function" then extra = extra(window) end
    return extra or 0
end

-- Free dragging via a region (header); position is not saved
function ns.MakeWindowDraggable(window, region)
    window:SetMovable(true)
    if window.SetDontSavePosition then window:SetDontSavePosition(true) end
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", function()
        if InCombatLockdown() and window:IsProtected() then return end
        window.dragged = true -- user-moved: stop auto-placing it
        window:StartMoving()
    end)
    region:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
end

-- Window scale relative to UIParent (e.g. enlarged guild frame); positions are in UIParent units
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

-- Open windows that occupy space: our other windows (not gossip - quest/merchant replace it) and
-- Blizzard's UI panels (character, spellbook, ...)
local placing -- during Relayout: set of windows opened earlier; only those count
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
            -- Skinned Blizzard frames (guild) are UIPanels themselves: don't avoid yourself
            if panel and panel ~= window and panel:IsVisible() then list[#list + 1] = panel end
        end
    end
    return list
end

-- Windows that may close when space runs out (like Blizzard's UIPanel manager: the oldest closes).
-- Never NPC interactions (merchant, mail, bank, trainer, quest, AH, ...) - that would end the interaction.
local CLOSABLE = {
    legacy = true, spellbook = true, talents = true, professions = true, character = true,
    inspect = true, guild = true, friends = true, dressup = true,
}

-- Find a spot. Returns the desired right edge (incl. outside tabs) in UIParent units, before WoW
-- clamps to the screen. Windows may have their own scale (e.g. guild at 1.2x).
local function Place(window)
    local k = Ratio(window)
    window:ClearAllPoints()
    -- Shared top edge: shorter windows (e.g. guild) hang from the standard-height top line; taller
    -- ones (talents) sit on top of the chat
    if window:GetHeight() * k < ns.NPC_HEIGHT then
        window:SetPoint("TOPLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap((90 + ns.NPC_HEIGHT) / k))
    else
        window:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, ns.Snap(90 / k))
    end
    local wantedRight = ((window:GetLeft() or 0) + window:GetWidth()) * k
    -- While overlapping: move to the right, aligned to the other window's top (bottom-aligning slid it
    -- over action bars and unit frames)
    for _ = 1, 6 do
        local right, top
        for _, other in ipairs(Occupied(window)) do
            -- extraRight: tabs outside the window (professions, spellbook) count too
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

-- Fixed spot above chat (raid frame height); if a window is already there, place to its right.
-- Call on open - resets free dragging. opening = just opened: if it no longer fits on screen, the
-- oldest closable mUI window closes. Relayout (like Blizzard): when a window closes, the rest
-- re-place in opening order, each only seeing windows opened before it.
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
        for _, other in ipairs(order) do -- order: first opened first
            if other ~= window and other:IsShown() and CLOSABLE[managed[other]] then oldest = other break end
        end
        if not oldest then return end
        oldest:Hide()
    end
end

-- Watchdog: our window lives only while Blizzard's hidden-parked counterpart is shown. Events like
-- MERCHANT_CLOSED don't always arrive (e.g. switching straight to the next NPC); if our window stayed
-- open, the game would treat the old interaction as active and not open the new one.
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

-- Track opening order (last opened = last)
local function Opened(window)
    for i, other in ipairs(order) do
        if other == window then table.remove(order, i) break end
    end
    order[#order + 1] = window
end
ns.WindowOpened = Opened
-- Is an interaction of this kind still running? The parked frame alone is not enough: if Esc closed
-- it first, the interaction stays open in-game and the NPC stops responding to clicks. Only checks
-- its own kind, so a new interaction of another kind (next NPC) is left alone.
function ns.StillInteracting(kind, frame)
    if frame and frame:IsShown() then return true end
    local id = Enum.PlayerInteractionType and Enum.PlayerInteractionType[kind]
    return id ~= nil and C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType(id) or false
end

-- A Blizzard panel opened: re-place our open (not user-moved) windows
hooksecurefunc("ShowUIPanel", function()
    C_Timer.After(0, function()
        for _, window in ipairs(order) do
            if window:IsShown() and not window.dragged then ns.ResetWindowPosition(window, managed[window] ~= true and managed[window] or nil) end
        end
    end)
end)

-- Parchment panel as background for a window's whole content (quest, gossip), like a letter.
-- Returns the panel; place content with 20/18 px inner padding.
ns.PARCHMENT_CARD = { 0, 0, 0, 0.35 }       -- cards/options on parchment
ns.PARCHMENT_CARD_HOVER = { 0, 0, 0, 0.55 }
ns.PARCHMENT_TEXT = { 0.94, 0.9, 0.82 }     -- warm white
function ns.CreateParchmentPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    local base = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    base:SetAllPoints()
    base:SetColorTexture(0.1, 0.08, 0.06, 1)
    local art = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    art:SetAllPoints()
    if not art:SetAtlas("QuestBG-Parchment") then art:SetColorTexture(0.6, 0.47, 0.32, 1) end
    art:SetVertexColor(0.3, 0.26, 0.22) -- dark, warm
    ns.AddBorder(panel)
    for _, edge in ipairs(ns.AddBorder(panel, true)) do edge:SetVertexColor(1, 0.86, 0.63, 0.07) end
    return panel
end

-- Window with background, accent edge, NPC header and close button. key = layoutFrames name.
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
    tinsert(UISpecialFrames, name) -- Esc closes

    -- Header: drag region holding portrait, name, title and close
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
    ns.SetFont(window.npcName, 16, "", "bold") -- window title (NPC, guild, ...): mUI Bold
    window.npcName:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -6)
    window.npcName:SetPoint("RIGHT", header, "RIGHT", -PAD - 36, 0)
    window.npcTitle = UI.Text(header, 12, "LEFT", UI.MUTED)
    window.npcTitle:SetPoint("TOPLEFT", window.npcName, "BOTTOMLEFT", 0, -5)
    window.npcTitle:SetPoint("RIGHT", window.npcName, "RIGHT")

    local close = UI.IconButton(header, "Close", function() window:Hide() end, 26)
    close:SetPoint("TOPRIGHT", -PAD, -PAD)
    window.close = close

    -- Show the NPC: 3D portrait, else 2D portrait (e.g. objects, signs).
    -- icon: fixed image instead of a portrait (e.g. mailbox)
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
        -- If the unit is gone right now (gossip -> trainer switch), reuse the last shown NPC
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
        -- Own fixed spot (e.g. centered addon list): skip the window row placement
        if self.ownPoint then
            self:ClearAllPoints()
            self:SetPoint(unpack(self.ownPoint))
            return
        end
        Opened(self)
        ns.ResetWindowPosition(self, self.positionKey, true)
    end)
    if onClose then window:HookScript("OnHide", onClose) end
    return window
end
