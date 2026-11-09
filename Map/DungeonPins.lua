-- Pins on the dungeon maps (bosses, rares) and a development editor to place them in game.
-- Classic instances: positions generated from server spawn data (tools/build_dungeon_pins.py);
-- the rest (event bosses, Forever's new dungeons) is placed by hand:
--   /mui debug, then /mui pins -> edit mode (dev only, not in the help): a tray with the dungeon's bosses at the bottom of the map; drag one onto
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
    return d
end

-- Round creature portrait in a ring (boss gold, rare silver) with a small diamond badge
-- (boss number / rare star); without a display ID: a plain diamond with the number.
local function StylePin(button, kind, number, display)
    if not button.ring then
        button.ring = button:CreateTexture(nil, "BACKGROUND")
        button.ring:SetAllPoints()
        button.ring:SetTexture(CIRCLE)
        button.portrait = button:CreateTexture(nil, "BORDER")
        button.portrait:SetPoint("TOPLEFT", 2, -2)
        button.portrait:SetPoint("BOTTOMRIGHT", -2, 2)
        button.hover = button:CreateTexture(nil, "HIGHLIGHT")
        button.hover:SetAllPoints(button.portrait)
        button.hover:SetTexture(CIRCLE)
        button.hover:SetVertexColor(1, 1, 1, 0.25)
        button.badge = Diamond(button, 18)
        button.badge:SetFrameLevel(button:GetFrameLevel() + 2)
        button.big = Diamond(button, PIN)
        button.big:SetPoint("CENTER")
    end
    local color = kind == "rare" and SILVER or GOLD
    local mark = kind == "rare" and ("|T" .. ns.MEDIA .. "Icons\\Star:10:10:0:0|t") or (number or "")
    local round = display and display > 0
    button.ring:SetShown(round)
    button.portrait:SetShown(round)
    button.badge:SetShown(round)
    button.big:SetShown(not round)
    if round then
        button:SetSize(PIN + 10, PIN + 10)
        button.ring:SetVertexColor(unpack(color))
        SetPortraitTextureFromCreatureDisplayID(button.portrait, display)
        button.badge:ClearAllPoints()
        button.badge:SetPoint("CENTER", button, "BOTTOMRIGHT", -5, 5)
        button.badge.edge:SetVertexColor(unpack(color))
        button.badge.text:SetText(mark)
        button.badge.text:SetTextColor(unpack(color))
        button.hover:SetTexture(CIRCLE)
        button.hover:SetAllPoints(button.portrait)
    else
        button:SetSize(PIN, PIN)
        button.big.edge:SetVertexColor(unpack(color))
        button.big.text:SetText(mark)
        button.big.text:SetTextColor(unpack(color))
        button.hover:SetTexture(DIAMOND)
        button.hover:SetAllPoints(button.big)
    end
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

-- Tray (edit mode): unplaced bosses + rares added from the target
local function TrayButton(i)
    local view = ns.DungeonMapView
    local button = trayButtons[i]
    if button then return button end
    button = CreateFrame("Button", nil, tray)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- drag from the tray: follow the cursor, drop on the map places the pin
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(b)
            local x, y = GetCursorPosition()
            local s = b:GetEffectiveScale()
            b:ClearAllPoints()
            b:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        local x, y = CursorToMap(view.art)
        local e = self.entry
        if x and e then SavePin(view.instance, { kind = e.kind, id = e.id, name = e.name, display = e.display, floor = view.floor, x = x, y = y }) end
        Refresh()
    end)
    trayButtons[i] = button
    return button
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
            button:ClearAllPoints()
            button:SetPoint("CENTER", view.art, "TOPLEFT", p.x * view.art:GetWidth(), -p.y * view.art:GetHeight())
            button:Show()
        end
    end
    if not editing then return end
    -- tray: bosses not yet placed, then pending rares
    local list = {}
    for i, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[instance] or {}) do
        if not placed["boss:" .. b[1]] then list[#list + 1] = { kind = "boss", id = b[1], number = i } end
    end
    for _, r in ipairs(P.pendingRares or {}) do
        if r.instance == instance and not placed["rare:" .. r.id] then list[#list + 1] = { kind = "rare", id = r.id, name = r.name } end
    end
    local prev
    for i, e in ipairs(list) do
        local button = TrayButton(i)
        local name = e.name
        if e.kind == "boss" then name = BossName(instance, e.id) end
        button.entry = { kind = e.kind, id = e.id, name = name }
        StylePin(button, e.kind, e.number)
        button:ClearAllPoints()
        if prev then button:SetPoint("LEFT", prev, "RIGHT", 6, 0) else button:SetPoint("LEFT", hint, "RIGHT", 10, 0) end
        button:Show()
        prev = button
    end
end
P.Refresh = Refresh

local function CreateTray()
    local UI = ns.UI
    local view = ns.DungeonMapView
    tray = CreateFrame("Frame", nil, view.frame)
    tray:SetPoint("BOTTOMLEFT", 12, 12)
    tray:SetPoint("BOTTOMRIGHT", -12, 12)
    tray:SetHeight(40)
    tray:SetFrameLevel(view.frame:GetFrameLevel() + 20)
    UI.Box(tray, { 0.04, 0.04, 0.04, 0.92 })
    ns.AddBorder(tray)
    hint = UI.Text(tray, 12, "LEFT", UI.ACCENT)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Pin editor: drag onto the map"])
    targetButton = UI.Button(tray, L["Target as pin"], function()
        if not UnitExists("target") or UnitIsPlayer("target") then return ns.Print(L["Target a rare first."]) end
        local guid = UnitGUID("target")
        local npcID = guid and tonumber(select(6, strsplit("-", guid)))
        if not npcID then return end
        P.pendingRares = P.pendingRares or {}
        table.insert(P.pendingRares, { instance = view.instance, id = npcID, name = UnitName("target") })
        Refresh()
    end, 120)
    targetButton:SetHeight(26)
    targetButton:SetPoint("RIGHT", -8, 0)
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

-- Development tool (to show where bosses are): hidden from /mui help, needs /mui debug on
ns.AddCommand("pins", "dungeon map: place boss/rare pins (dev)", function()
    if not (ns.db and ns.db.debug) then return end
    P.ToggleEdit()
end, true)
