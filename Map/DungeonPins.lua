-- Pins on the dungeon maps (bosses, rares) and a development editor to place them in game.
-- Classic instances: positions generated from server spawn data (tools/build_dungeon_pins.py);
-- the rest (event bosses, Forever's new dungeons) is placed by hand:
--   /mui debug (developer mode), then /mui pins -> edit mode: a tray with the dungeon's bosses at the bottom of the map; drag one onto
--                the map to place it, drag pins to move them, right-click removes. "Target as pin" adds
--                your current target (a rare) to the tray.
-- Placed pins are saved account-wide (MeredanUIDB.dungeonPins) and later copied into
-- Map/DungeonPinData.lua (ns.DUNGEON_PINS) so every player gets them. Positions are relative to the
-- map art (0..1), per instance and floor. Display only, nothing protected.
local _, ns = ...
local L = ns.L

local P = {}
ns.DungeonPins = P
local editing = false
local pins, trayButtons = {}, {}
local tray, targetButton, hint
local PIN = 24

local function Saved()
    MeredanUIDB.dungeonPins = MeredanUIDB.dungeonPins or {}
    return MeredanUIDB.dungeonPins
end

-- All pins of an instance: shipped data, then own placements (own ones win by key)
local function PinsOf(instance)
    local list, byKey = {}, {}
    for _, src in ipairs({ ns.DUNGEON_PINS and ns.DUNGEON_PINS[instance] or {}, Saved()[instance] or {} }) do
        for _, p in ipairs(src) do
            local key = p.kind .. ":" .. p.id
            if byKey[key] then list[byKey[key]] = p else list[#list + 1] = p; byKey[key] = #list end
        end
    end
    return list
end

local function BossName(instance, id)
    for i, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[instance] or {}) do
        if b[1] == id then return GetLocale() == "deDE" and b[3] or b[2], i end
    end
end

local function SavePin(instance, entry)
    local list = Saved()[instance] or {}
    Saved()[instance] = list
    for i, p in ipairs(list) do
        if p.kind == entry.kind and p.id == entry.id then list[i] = entry return end
    end
    list[#list + 1] = entry
end

local function RemovePin(instance, kind, id)
    local list = Saved()[instance]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i].kind == kind and list[i].id == id then table.remove(list, i) end
    end
    -- a shipped pin can't be deleted from data; mark it hidden for this account
    if ns.DUNGEON_PINS and ns.DUNGEON_PINS[instance] then
        for _, p in ipairs(ns.DUNGEON_PINS[instance]) do
            if p.kind == kind and p.id == id then
                list[#list + 1] = { kind = kind, id = id, floor = 0, x = 0, y = 0, hidden = true }
            end
        end
    end
end

local GOLD, SILVER, DARK = { 0.85, 0.71, 0.42 }, { 0.8, 0.82, 0.86 }, { 0.07, 0.085, 0.085 }
local DIAMOND = ns.MEDIA .. "Icons\\Diamond"
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- Diamond with border (same look as the Legacy window's level ticks)
local function Diamond(parent, size, layer)
    local d = CreateFrame("Frame", nil, parent)
    d:SetSize(size, size)
    d.edge = d:CreateTexture(nil, layer or "ARTWORK", nil, 1)
    d.edge:SetTexture(DIAMOND)
    d.edge:SetAllPoints()
    d.fill = d:CreateTexture(nil, layer or "ARTWORK", nil, 2)
    d.fill:SetTexture(DIAMOND)
    d.fill:SetPoint("TOPLEFT", 2, -2)
    d.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    d.fill:SetVertexColor(unpack(DARK))
    d.text = ns.UI.Text(d, 11, "CENTER")
    d.text:SetPoint("CENTER", 0, 0)
    ns.SetFont(d.text, 11, "OUTLINE", "bold")
    d.text:SetShadowOffset(0, 0) -- outline only: a drop shadow on top makes the small number mushy
    return d
end

-- Round creature portrait in a ring (boss gold, rare silver) with a small diamond badge
-- (boss number / rare star); without a display ID (Forever's new bosses): dark disc with "?".
local function StylePin(button, kind, number, display)
    if not button.ring then
        button.ring = button:CreateTexture(nil, "BACKGROUND")
        button.ring:SetAllPoints()
        button.ring:SetTexture(CIRCLE)
        button.portrait = button:CreateTexture(nil, "BORDER")
        button.portrait:SetPoint("TOPLEFT", 2, -2)
        button.portrait:SetPoint("BOTTOMRIGHT", -2, 2)
        button.unknown = button:CreateFontString(nil, "ARTWORK")
        ns.SetFont(button.unknown, 18, "OUTLINE", "bold")
        button.unknown:SetPoint("CENTER", 0, 0)
        button.unknown:SetText("?")
        button.hover = button:CreateTexture(nil, "HIGHLIGHT")
        button.hover:SetAllPoints(button.portrait)
        button.hover:SetTexture(CIRCLE)
        button.hover:SetVertexColor(1, 1, 1, 0.25)
        button.badge = Diamond(button, 18)
        button.badge:SetFrameLevel(button:GetFrameLevel() + 2)
        button.badge:SetPoint("CENTER", button, "BOTTOMRIGHT", -5, 5)
    end
    local color = kind == "rare" and SILVER or GOLD
    local mark = kind == "rare" and ("|T" .. ns.MEDIA .. "Icons\\Star:10:10:0:0|t") or (number or "")
    local known = display and display > 0
    button:SetSize(PIN + 10, PIN + 10)
    button.ring:SetVertexColor(unpack(color))
    if known then
        SetPortraitTextureFromCreatureDisplayID(button.portrait, display)
        button.portrait:SetVertexColor(1, 1, 1)
    else
        button.portrait:SetTexture(CIRCLE)
        button.portrait:SetTexCoord(0, 1, 0, 1)
        button.portrait:SetVertexColor(0, 0, 0)
    end
    button.unknown:SetShown(not known)
    button.unknown:SetTextColor(unpack(color))
    button.badge.edge:SetVertexColor(unpack(color))
    button.badge.text:SetText(mark)
    button.badge.text:SetTextColor(unpack(color))
end

local function Tooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(button.entry.name or "", 1, 1, 1)
    GameTooltip:AddLine(button.entry.kind == "rare" and L["Rare"] or (BOSS or L["Boss"]), 0.6, 0.59, 0.56)
    if editing then GameTooltip:AddLine(L["Drag to move · right-click: remove"], 0.56, 0.8, 0.71) end
    GameTooltip:Show()
end

-- Position inside the map art from the cursor (0..1); nil when outside
local function CursorToMap(art)
    local x, y = GetCursorPosition()
    local scale = art:GetEffectiveScale()
    x, y = x / scale, y / scale
    local left, top, w, h = art:GetLeft(), art:GetTop(), art:GetWidth(), art:GetHeight()
    if not left or w <= 0 then return end
    local nx, ny = (x - left) / w, (top - y) / h
    if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return end
    return nx, ny
end

local Refresh

local function MakePin(i)
    local view = ns.DungeonMapView
    local button = CreateFrame("Button", nil, view.art)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetFrameLevel(view.art:GetFrameLevel() + 5)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnMouseDown", function(self, mouse)
        if not editing or mouse ~= "LeftButton" then return end
        self:SetScript("OnUpdate", function(pin)
            local x, y = CursorToMap(view.art)
            if x then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", view.art, "TOPLEFT", x * view.art:GetWidth(), -y * view.art:GetHeight())
            end
        end)
    end)
    button:SetScript("OnMouseUp", function(self, mouse)
        self:SetScript("OnUpdate", nil)
        local e = self.entry
        if not editing and e and mouse == "LeftButton" and ns.DungeonPanel then
            ns.DungeonPanel.Select(e.kind == "rare" and ("rare:" .. e.id) or e.id)
            return
        end
        if not (editing and e) then return end
        if mouse == "RightButton" then
            RemovePin(view.instance, e.kind, e.id)
        else
            local x, y = CursorToMap(view.art)
            if x then SavePin(view.instance, { kind = e.kind, id = e.id, name = e.name, display = e.display, floor = view.floor, x = x, y = y }) end
        end
        Refresh()
    end)
    pins[i] = button
    return button
end

-- Tray (edit mode): list at the right edge with every boss not yet on this floor's map
local ghost
local function Ghost()
    if not ghost then
        ghost = CreateFrame("Frame", nil, UIParent)
        ghost:SetFrameStrata("TOOLTIP")
        ghost:Hide()
    end
    return ghost
end

local ROW = 30
local function TrayButton(i)
    local view = ns.DungeonMapView
    local row = trayButtons[i]
    if row then return row end
    row = CreateFrame("Button", nil, tray.list)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
    row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW)
    row:RegisterForDrag("LeftButton")
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.06)
    row.icon = CreateFrame("Button", nil, row)
    row.icon:EnableMouse(false)
    row.icon:SetPoint("LEFT", 4, 0)
    row.name = ns.UI.Text(row, 12, "LEFT")
    row.name:SetPoint("LEFT", 40, 0)
    row.name:SetPoint("RIGHT", -4, 0)
    row.name:SetWordWrap(false)
    -- drag: a pin follows the cursor, dropping it on the map places it on the shown floor
    row:SetScript("OnDragStart", function(self)
        local g = Ghost()
        g.pin = g.pin or CreateFrame("Button", nil, g)
        g.pin:EnableMouse(false)
        StylePin(g.pin, self.entry.kind, self.entry.number, self.entry.display)
        g:SetSize(g.pin:GetSize())
        g.pin:SetAllPoints()
        g:Show()
        g:SetScript("OnUpdate", function(f)
            local x, y = GetCursorPosition()
            local s = f:GetEffectiveScale()
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
        end)
    end)
    row:SetScript("OnDragStop", function(self)
        local g = Ghost()
        g:SetScript("OnUpdate", nil)
        g:Hide()
        local x, y = CursorToMap(view.art)
        local e = self.entry
        if x and e then SavePin(view.instance, { kind = e.kind, id = e.id, name = e.name, display = e.display, floor = view.floor, x = x, y = y }) end
        Refresh()
    end)
    trayButtons[i] = row
    return row
end

function Refresh()
    local view = ns.DungeonMapView
    for _, b in ipairs(pins) do b:Hide() end
    for _, b in ipairs(trayButtons) do b:Hide() end
    if tray then tray:SetShown(editing and view.IsShown()) end
    if not (view.IsShown() and view.instance) then return end
    local instance, floor = view.instance, view.floor
    local placed, n = {}, 0
    for _, p in ipairs(PinsOf(instance)) do
        if not p.hidden then placed[p.kind .. ":" .. p.id] = true end
        if not p.hidden and p.floor == floor then
            n = n + 1
            local button = pins[n] or MakePin(n)
            local name, number = p.name, nil
            if p.kind == "boss" then name, number = BossName(instance, p.id) end
            button.entry = { kind = p.kind, id = p.id, name = name or p.name, display = p.display }
            StylePin(button, p.kind, number, p.display)
            -- boss chosen in the panel (Map/DungeonPanel.lua): bigger, accent ring
            local key = p.kind == "rare" and ("rare:" .. p.id) or p.id
            local chosen = not editing and ns.DungeonPanel and ns.DungeonPanel.Selected() == key
            button:SetScale(chosen and 1.25 or 1)
            button:SetFrameLevel(view.art:GetFrameLevel() + (chosen and 8 or 5))
            if chosen then button.ring:SetVertexColor(unpack(ns.UI.ACCENT)) end
            button:ClearAllPoints()
            local scale = button:GetScale() -- offsets count in the pin's own (scaled) units
            button:SetPoint("CENTER", view.art, "TOPLEFT", p.x * view.art:GetWidth() / scale, -p.y * view.art:GetHeight() / scale)
            button:Show()
        end
    end
    if not editing then return end
    -- tray: bosses not placed on any floor yet, then rares added from the target
    local here = placed
    local list = {}
    for i, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[instance] or {}) do
        local key = "boss:" .. b[1]
        if not here[key] then
            list[#list + 1] = { kind = "boss", id = b[1], number = i }
        end
    end
    for _, r in ipairs(P.pendingRares or {}) do
        if r.instance == instance and not here["rare:" .. r.id] then
            list[#list + 1] = { kind = "rare", id = r.id, name = r.name }
        end
    end
    for i, e in ipairs(list) do
        local row = TrayButton(i)
        local name = e.name
        if e.kind == "boss" then name = BossName(instance, e.id) end
        row.entry = { kind = e.kind, id = e.id, name = name, number = e.number }
        StylePin(row.icon, e.kind, e.number)
        row.icon:ClearAllPoints()
        row.icon:SetPoint("CENTER", row, "LEFT", 20, 0)
        row.name:SetText(name or "?")
        row:Show()
    end
    tray.empty:SetShown(#list == 0)
    tray:SetHeight(64 + math.max(#list, 1) * ROW)
end
P.Refresh = Refresh
P.StylePin = function(...) return StylePin(...) end -- also used by the boss list (Map/DungeonPanel.lua)

local function CreateTray()
    local UI = ns.UI
    local view = ns.DungeonMapView
    -- beside the map, over the quest log column. Parented to UIParent: the map area clips its children,
    -- so a child placed outside it was invisible
    tray = CreateFrame("Frame", nil, UIParent)
    tray:SetFrameStrata("DIALOG")
    tray:SetPoint("TOPLEFT", view.frame, "TOPRIGHT", 12, 0)
    tray:SetWidth(230)
    view.frame:HookScript("OnHide", function() tray:Hide() end)
    tray:EnableMouse(true)
    UI.Box(tray, { 0.04, 0.04, 0.04, 0.92 })
    ns.AddBorder(tray)
    hint = UI.Text(tray, 12, "LEFT", UI.ACCENT)
    hint:SetPoint("TOPLEFT", 10, -10)
    hint:SetPoint("TOPRIGHT", -10, -10)
    hint:SetText(L["Pin editor: drag onto the map"])
    tray.list = CreateFrame("Frame", nil, tray)
    tray.list:SetPoint("TOPLEFT", 6, -30)
    tray.list:SetPoint("BOTTOMRIGHT", -6, 36)
    tray.empty = UI.Text(tray.list, 12, "LEFT", UI.MUTED)
    tray.empty:SetPoint("TOPLEFT", 6, -8)
    tray.empty:SetText(L["All bosses placed."])
    targetButton = UI.Button(tray, L["Target as pin"], function()
        if not UnitExists("target") or UnitIsPlayer("target") then return ns.Print(L["Target a rare first."]) end
        local guid = UnitGUID("target")
        local npcID = guid and tonumber(select(6, strsplit("-", guid)))
        if not npcID then return end
        P.pendingRares = P.pendingRares or {}
        table.insert(P.pendingRares, { instance = view.instance, id = npcID, name = UnitName("target") })
        Refresh()
    end, 120)
    targetButton:SetHeight(24)
    targetButton:SetPoint("BOTTOMLEFT", 8, 8)
    targetButton:SetPoint("BOTTOMRIGHT", -8, 8)
    tray:Hide()
end

function P.ToggleEdit()
    local view = ns.DungeonMapView
    if not view.IsShown() then return ns.Print(L["Open a dungeon map first (click a dungeon swirl on the map)."]) end
    if not tray then CreateTray() end
    editing = not editing
    ns.Print(editing and L["Pin editor on."] or L["Pin editor off. Pins are saved."])
    Refresh()
end

-- Development tool (to show where bosses are): developer mode only, removed again once all pins are in
ns.AddCommand("pins", L["Dungeon map: place boss/rare pins"], function() P.ToggleEdit() end, true)
