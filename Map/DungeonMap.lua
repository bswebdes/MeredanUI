-- Dungeon maps inside the mUI world map (WoW Forever has no dungeon maps of its own).
-- Clicking a dungeon swirl (Map/MapExtras.lua) shows the dungeon on the map area, with floor tabs;
-- right-click or the back arrow returns to the zone. Inside an instance the map opens on it.
--
--   +- map area -------------------------------------------------+
--   | [<] Blackrock Depths   [Detention Block] [Shadowforge City] |
--   |                                                            |
--   |                 Blizzard's drawn dungeon map               |
--   +------------------------------------------------------------+
--
-- Art: classic instances use Blizzard's map textures shipped with Forever (12 tiles, 1002x668
-- layer, Map/DungeonMapData.lua); Forever's new instances use own parchment maps
-- (Media/DungeonMaps, Map/DungeonMapDataForever.lua). Display only, nothing protected.
local _, ns = ...
local L = ns.L

local LAYER_W, LAYER_H, TILE = 1002, 668, 256
local view = {}
ns.DungeonMapView = view

local function FloorName(instance, floor)
    local name = GetLocale() == "deDE" and floor.de or floor.en
    if name and name ~= "" then return name end
    return GetRealZoneText and GetRealZoneText(instance) or ""
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
    for i, chip in ipairs(view.chips) do
        local on = i == index
        for _, e in ipairs(chip.edges) do e:SetShown(on) end
        chip.text:SetTextColor(unpack(on and ns.UI.ACCENT or ns.UI.TEXT))
    end
    if view.onChange then view.onChange() end
    if ns.DungeonPins then ns.DungeonPins.Refresh() end
end

local function LayoutChips()
    local data = ns.DUNGEON_MAPS[view.instance]
    local UI = ns.UI
    local prev = view.plate
    for i = 1, math.max(#data, #view.chips) do
        local chip = view.chips[i]
        if i <= #data and #data > 1 then
            if not chip then
                chip = CreateFrame("Button", nil, view.bar)
                chip:SetHeight(26)
                UI.Box(chip, { 0.06, 0.06, 0.06, 0.88 })
                ns.AddBorder(chip)
                chip.edges = ns.AddBorder(chip, true, 2)
                for _, e in ipairs(chip.edges) do e:SetVertexColor(unpack(UI.ACCENT)) end
                chip.text = UI.Text(chip, 12, "CENTER")
                chip.text:SetPoint("CENTER")
                local hover = chip:CreateTexture(nil, "HIGHLIGHT")
                hover:SetAllPoints()
                hover:SetColorTexture(1, 1, 1, 0.06)
                chip:SetScript("OnClick", function(self)
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    ShowFloor(self.index)
                end)
                view.chips[i] = chip
            end
            chip.index = i
            chip.text:SetText(FloorName(view.instance, data[i]))
            chip:SetWidth(chip.text:GetUnboundedStringWidth() + 20)
            chip:ClearAllPoints()
            chip:SetPoint("LEFT", prev, "RIGHT", prev == view.plate and 14 or 6, 0)
            chip:Show()
            prev = chip
        elseif chip then
            chip:Hide()
        end
    end
end

function view.Show(instance, floor)
    local data = instance and ns.DUNGEON_MAPS and ns.DUNGEON_MAPS[instance]
    if not (data and view.frame) then return false end
    view.instance = instance
    view.titleText:SetText(GetRealZoneText and GetRealZoneText(instance) or "")
    view.plate:SetWidth(view.titleText:GetUnboundedStringWidth() + 20)
    LayoutChips()
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
function view.Has(instance) return ns.DUNGEON_MAPS and ns.DUNGEON_MAPS[instance] ~= nil end

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
    view.tiles, view.chips = {}, {}
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
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then view.Hide() end
    end)
    frame:SetScript("OnSizeChanged", function() if frame:IsShown() and view.floor then ShowFloor(view.floor) end end)
    view.frame = frame

    -- top bar: back, name, floor tabs
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
    UI.Box(plate, { 0.06, 0.06, 0.06, 0.88 })
    ns.AddBorder(plate)
    view.titleText = UI.Text(plate, 14, "LEFT")
    ns.SetFont(view.titleText, 14, "", "bold")
    view.titleText:SetPoint("LEFT", 10, 0)
    view.titleText:SetTextColor(unpack(UI.ACCENT))
    view.plate = plate
end
