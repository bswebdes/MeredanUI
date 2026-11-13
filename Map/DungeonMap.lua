-- Dungeon maps inside the mUI world map (WoW Forever has no dungeon maps of its own).
-- Clicking a dungeon swirl (Map/MapExtras.lua) shows the dungeon on the map area, with a floor dropdown;
-- right-click or the back arrow returns to the zone. Inside an instance the map opens on it.
--
--   +- map area -------------------------------------------------+
--   | [<] Blackrock Depths   [Detention Block v]                   |
--   |                                                            |
--   |                 Blizzard's drawn dungeon map               |
--   +------------------------------------------------------------+
--
-- Art: classic instances use Blizzard's map textures shipped with Forever (12 tiles, 1002x668
-- layer, Map/DungeonMapData.lua); Forever's new instances use own parchment maps
-- (Media/DungeonMaps, Map/DungeonMapDataForever.lua): Santiago Reyes' Atlas de Azeroth maps (used with his
-- permission: watermark untouched, credit shown on the map), own parchment maps where he has none yet.
-- Display only, nothing protected.
local _, ns = ...
local L = ns.L

local LAYER_W, LAYER_H, TILE = 1002, 668, 256
local view = {}
ns.DungeonMapView = view

-- A floor named like the instance itself (Dire Maul's wing overview) reads as "Overview"
local function FloorName(instance, floor)
    local name = GetLocale() == "deDE" and floor.de or floor.en
    local zone = GetRealZoneText and GetRealZoneText(instance) or ""
    if not name or name == "" or name == zone then return L["Overview"] end
    return name
end

-- Fit the 3:2 map into the area (letterbox if the area isn't exactly 3:2)
local function Fit(area)
    local w, h = area:GetWidth(), area:GetHeight()
    local s = math.min(w / LAYER_W, h / LAYER_H)
    return s, (w - LAYER_W * s) / 2, (h - LAYER_H * s) / 2
end

local function ShowFloor(index)
    local data = view.instance and ns.DUNGEON_MAPS[view.instance]
    local floor = data and data[index]
    if not floor then return end
    view.floor = index
    local area = view.frame
    local s, ox, oy = Fit(area)
    for _, tex in ipairs(view.tiles) do tex:Hide() end
    if floor.tiles then
        for i, fileID in ipairs(floor.tiles) do
            local tex = view.tiles[i]
            if not tex then
                tex = view.art:CreateTexture(nil, "ARTWORK")
                view.tiles[i] = tex
            end
            tex:SetTexture(fileID)
            tex:SetTexCoord(0, 1, 0, 1)
            local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", area, "TOPLEFT", ox + col * TILE * s, -(oy + row * TILE * s))
            tex:SetSize(TILE * s, TILE * s)
            tex:Show()
        end
    elseif floor.file then
        local tex = view.tiles[1]
        if not tex then
            tex = view.art:CreateTexture(nil, "ARTWORK")
            view.tiles[1] = tex
        end
        tex:SetTexture(floor.file)
        tex:SetTexCoord(unpack(floor.texCoord or { 0, 1, 0, 1 }))
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", area, "TOPLEFT", ox, -oy)
        tex:SetSize(LAYER_W * s, LAYER_H * s)
        tex:Show()
    end
    -- the art's own frame edge sits outside the letterbox: clip to the map rectangle
    view.art:ClearAllPoints()
    view.art:SetPoint("TOPLEFT", area, "TOPLEFT", ox, -oy)
    view.art:SetSize(LAYER_W * s, LAYER_H * s)
    view.credit:SetShown(floor.credit == true)
    local count = #ns.DUNGEON_MAPS[view.instance]
    local drop = view.floorDrop
    drop:SetShown(count > 1)
    if count > 1 then
        drop.text:SetText(FloorName(view.instance, floor))
        drop:SetWidth(drop.text:GetUnboundedStringWidth() + 38)
    end
    if view.onChange then view.onChange() end
    if ns.DungeonPins then ns.DungeonPins.Refresh() end
end

function view.Show(instance, floor)
    local data = instance and ns.DUNGEON_MAPS and ns.DUNGEON_MAPS[instance]
    if not (data and view.frame) then return false end
    view.instance = instance
    view.titleText:SetText(GetRealZoneText and GetRealZoneText(instance) or "")
    view.plate:SetWidth(view.titleText:GetUnboundedStringWidth() + 20)
    view.frame:Show()
    ShowFloor(math.min(floor or 1, #data))
    return true
end

function view.Hide()
    if not view.frame or not view.frame:IsShown() then return end
    view.frame:Hide()
    view.instance = nil
    if view.onChange then view.onChange() end
    if ns.DungeonPins then ns.DungeonPins.Refresh() end
end

function view.IsShown() return view.frame and view.frame:IsShown() or false end
-- not for instances that aren't in the game (yet): see ns.InstanceState in Map/MapExtras.lua
function view.Has(instance)
    if ns.InstanceState and ns.InstanceState(instance) then return false end
    return ns.DUNGEON_MAPS and ns.DUNGEON_MAPS[instance] ~= nil
end

function view.CurrentName()
    if not view.IsShown() then return nil end
    local data = ns.DUNGEON_MAPS[view.instance]
    local zone = GetRealZoneText and GetRealZoneText(view.instance) or ""
    if #data > 1 then return zone .. "  ·  " .. FloorName(view.instance, data[view.floor]) end
    return zone
end

-- Build inside the map holder; onChange = footer/breadcrumb refresh in Map/WorldMap.lua
function view.Attach(holder, onChange)
    local UI = ns.UI
    view.onChange = onChange
    view.tiles = {}
    local frame = CreateFrame("Frame", nil, holder)
    frame:SetAllPoints(holder)
    frame:SetFrameLevel(9100) -- above map pins and the pin/coords buttons
    frame:EnableMouse(true)
    frame:Hide()
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.04, 0.03, 1)
    view.art = CreateFrame("Frame", nil, frame)
    view.art:SetClipsChildren(true)
    -- artist credit (Santiago Reyes' maps), above the pins
    local creditFrame = CreateFrame("Frame", nil, frame)
    creditFrame:SetAllPoints(view.art)
    creditFrame:SetFrameLevel(frame:GetFrameLevel() + 30)
    view.credit = creditFrame:CreateFontString(nil, "OVERLAY")
    ns.SetFont(view.credit, 11, "OUTLINE")
    view.credit:SetPoint("TOPRIGHT", view.art, "TOPRIGHT", -10, -8)
    view.credit:SetTextColor(0.94, 0.88, 0.74, 0.9)
    view.credit:SetText(L["Map: Santiago Reyes · sreyesmaps.com"])
    view.credit:Hide()
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then view.Hide() end
    end)
    frame:SetScript("OnSizeChanged", function() if frame:IsShown() and view.floor then ShowFloor(view.floor) end end)
    view.frame = frame

    -- top bar: back, name, floor dropdown
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", 12, -12)
    bar:SetSize(10, 26)
    bar:SetFrameLevel(frame:GetFrameLevel() + 10)
    view.bar = bar
    local back = UI.IconButton(bar, "ChevronDown", function() view.Hide() end, 26)
    back.icon:SetRotation(-math.pi / 2)
    back:SetPoint("LEFT")
    back:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Back to the zone"], 1, 1, 1)
        GameTooltip:Show()
    end)
    back:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local plate = CreateFrame("Frame", nil, bar)
    plate:SetHeight(26)
    plate:SetPoint("LEFT", back, "RIGHT", 6, 0)
    UI.Inset(plate, { 0.06, 0.06, 0.06, 0.88 })
    view.titleText = UI.Text(plate, 14, "LEFT")
    ns.SetFont(view.titleText, 14, "", "bold")
    view.titleText:SetPoint("LEFT", 10, 0)
    view.titleText:SetTextColor(unpack(UI.ACCENT))
    view.plate = plate

    -- floor picker: one dropdown instead of a tab per floor (Dire Maul has 7)
    local drop = CreateFrame("Button", nil, bar)
    drop:SetHeight(26)
    drop:SetPoint("LEFT", plate, "RIGHT", 6, 0)
    UI.Inset(drop, { 0.06, 0.06, 0.06, 0.88 })
    drop.text = UI.Text(drop, 12, "LEFT")
    drop.text:SetPoint("LEFT", 10, 0)
    drop.text:SetTextColor(unpack(UI.TEXT))
    local chevron = UI.Icon(drop, "ChevronDown", 10, UI.MUTED)
    chevron:SetPoint("RIGHT", -10, 0)
    local hover = drop:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.06)
    drop:SetScript("OnClick", function(self)
        local data = ns.DUNGEON_MAPS[view.instance]
        local items = {}
        for i, floor in ipairs(data) do items[i] = { value = i, label = FloorName(view.instance, floor) } end
        UI.OpenList(self, items, view.floor, function(value)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            ShowFloor(value)
        end)
    end)
    drop:Hide()
    view.floorDrop = drop
end
