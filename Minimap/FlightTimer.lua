-- Flight timer: slim bar at the top center while on a flight path.
--   [plane] Darnassus          1:42   <- known route: time left, bar fills up
--   [plane] Darnassus          0:34   <- first flight: elapsed time (gets remembered)
-- Start and destination come from the taxi map (TakeTaxiNode); durations are measured on the
-- first flight and stored account-wide (ns.root.flightTimes, "from > to"). Forever and Retail.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT = 260, 20

local bar
local pending   -- { from, to } - selected, not yet departed
local flight    -- { from, to, start, known }

local function Enabled() return ns.db.flightTimer ~= false end

local function Times()
    ns.root.flightTimes = ns.root.flightTimes or {}
    return ns.root.flightTimes
end

local function RouteKey(from, to) return (from or "?") .. " > " .. (to or "?") end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- Short destination name ("Darnassus, Teldrassil" -> "Darnassus")
local function Short(name) return name and name:match("^([^,]+)") or name end

local function CurrentNode()
    for i = 1, NumTaxiNodes() do
        if TaxiNodeGetType(i) == "CURRENT" then return TaxiNodeName(i) end
    end
end

local function OnUpdate()
    if not flight then return end
    local elapsed = GetTime() - flight.start
    if flight.known then
        bar:SetValue(math.min(elapsed / flight.known, 1))
        bar.time:SetText(FormatTime(flight.known - elapsed))
    else
        bar:SetValue(0)
        bar.time:SetText(FormatTime(elapsed)) -- first flight: counts up, bar stays empty
    end
end

local Place -- defined below

local function Start()
    if not Enabled() or flight then return end
    local route = pending or {}
    pending = nil
    flight = { from = route.from, to = route.to, start = GetTime() }
    if route.from and route.to then flight.known = Times()[RouteKey(route.from, route.to)] or route.base end
    bar.label:SetText(Short(route.to) or L["Flight"])
    Place()
    bar:Show()
end

-- Base times (Minimap/FlightTimeData.lua): Classic times per faction, otherwise summed from
-- direct hops. Own measurements take precedence. Node IDs come from C_TaxiMap, slot numbers
-- (TakeTaxiNode, GetNumRoutes) from the open taxi map.
local function NodeIDs()
    local ids, current = {}, nil
    local maps = {}
    local best = C_Map.GetBestMapForUnit("player")
    if best and MapUtil and MapUtil.GetMapParentInfo then
        local continent = MapUtil.GetMapParentInfo(best, Enum.UIMapType.Continent, true)
        if continent then maps[#maps + 1] = continent.mapID end
    end
    if GetTaxiMapID then maps[#maps + 1] = GetTaxiMapID() end
    for _, mapID in ipairs(maps) do
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(mapID) or {}) do
            if node.slotIndex and node.nodeID then
                ids[node.slotIndex] = node.nodeID
                if node.state == Enum.FlightPathState.Current then current = node.nodeID end
            end
        end
    end
    return ids, current
end

-- Legacy talent "Frequent Flyer" (adventure tree, node 110300): flight paths 20 % faster
local function SpeedFactor()
    local ok, factor = pcall(function()
        local tree = Constants.LegacyConsts and Constants.LegacyConsts.LEGACY_TREE_ADVENTURE_ID
        local configID = tree and C_Traits.GetConfigIDByTreeID(tree)
        local info = configID and C_Traits.GetNodeInfo(configID, 110300)
        return (info and (info.activeRank or 0) > 0) and (1 / 1.2) or 1
    end)
    return ok and factor or 1
end

local function BaseTime(slot)
    local data = ns.FLIGHT_TIME_DATA
    if not data or not slot then return end
    local ids, from = NodeIDs()
    local to = ids[slot]
    if not (from and to) then return end
    local faction = data[UnitFactionGroup("player") or ""]
    local seconds = faction and faction[from] and faction[from][to]
    if not seconds then -- sum the route from its direct hops
        local hops = GetNumRoutes(slot) or 0
        if hops == 0 then return end
        seconds = 0
        for hop = 1, hops do
            local a, b = ids[TaxiGetNodeSlot(slot, hop, true)], ids[TaxiGetNodeSlot(slot, hop, false)]
            local part = a and b and data.direct[a] and data.direct[a][b]
            if not part then return end
            seconds = seconds + part
        end
    end
    return seconds * SpeedFactor()
end

-- Flight time to a destination on the open taxi map: seconds and whether it is an estimate
function ns.FlightTimeForSlot(slot)
    if not Enabled() or not slot then return end
    local learned = Times()[RouteKey(CurrentNode(), TaxiNodeName(slot))]
    if learned then return learned, false end
    local base = BaseTime(slot)
    if base then return base, true end
end

-- Line "Flight time: 1:42" (measured), "approx. 1:42" (base time) or "unknown"
function ns.AddFlightTimeLine(tooltip, slot)
    if not Enabled() or not slot then return end
    local seconds, estimate = ns.FlightTimeForSlot(slot)
    local text = seconds and L["Flight time: %s"]:format((estimate and L["approx. "] or "") .. FormatTime(seconds))
        or L["Flight time: unknown"]
    tooltip:AddLine(text, 0.6, 0.59, 0.56)
    tooltip:Show()
end

local function Land()
    if not flight then return end
    local duration = GetTime() - flight.start
    -- Only remember real flights (both ends known, not aborted/too short)
    if flight.from and flight.to and duration > 5 then
        local key = RouteKey(flight.from, flight.to)
        local old = Times()[key]
        Times()[key] = old and (old + duration) / 2 or duration
    end
    flight = nil
    bar:Hide()
end

local function Create()
    bar = CreateFrame("StatusBar", "MeredanUIFlightTimer", UIParent)
    bar:SetSize(ns.Snap(WIDTH), ns.Snap(HEIGHT))
    bar:SetFrameStrata("MEDIUM")
    bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.6)
    bar:SetMinMaxValues(0, 1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddBorder(bar)
    local icon = ns.UI.Icon(bar, "Flight", 14, ns.UI.ACCENT)
    icon:SetPoint("LEFT", 5, 0)
    bar.label = ns.CreateText(bar, 12, "LEFT", "OUTLINE")
    bar.label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    bar.time = ns.CreateText(bar, 12, "RIGHT", "OUTLINE")
    bar.time:SetPoint("RIGHT", -6, 0)
    bar:SetScript("OnUpdate", OnUpdate)
    bar:Hide()
end

-- Top center, 25 px from the edge; directly below the XP bar if it is shown
Place = function()
    local below = ns.XPBarBottom and ns.XPBarBottom()
    if below then
        bar:ClearAllPoints()
        bar:SetPoint("TOP", below, "BOTTOM", 0, -ns.Snap(8))
        return
    end
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    local _, cy = UIParent:GetCenter()
    ns.PlaceFromCenter(bar, "TOP", 0, cy - margin)
end

-- Preview (settings): a sample flight
ns.FlightTimerDemo = {
    Start = function()
        if not bar then return end
        flight = { from = "Demo", to = "Darnassus", start = GetTime(), known = 95 }
        bar.label:SetText("Darnassus")
        Place()
        bar:Show()
    end,
    Stop = function()
        if flight and flight.from == "Demo" then flight = nil; bar:Hide() end
    end,
    IsActive = function() return flight ~= nil and flight.from == "Demo" end,
}

ns:On("PLAYER_LOGIN", function()
    Create()
    ns.layoutFrames.flight = bar
    ns.OnLayout(Place)
    Place()
    -- Remember the destination when it is clicked (old and new taxi map)
    if TakeTaxiNode then
        hooksecurefunc("TakeTaxiNode", function(index)
            pending = { from = CurrentNode(), to = TaxiNodeName(index), base = Enabled() and BaseTime(index) or nil }
        end)
    end
    -- After /reload mid-flight: keep counting without a destination
    if UnitOnTaxi("player") then Start() end
end)

-- Takeoff and landing: control lost/regained while on a taxi?
ns:On("PLAYER_CONTROL_LOST", function()
    C_Timer.After(0.2, function() if UnitOnTaxi("player") then Start() end end)
end)
ns:On("PLAYER_CONTROL_GAINED", function()
    C_Timer.After(0.2, function() if not UnitOnTaxi("player") then Land() end end)
end)
