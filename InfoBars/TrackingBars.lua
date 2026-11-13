-- Progress bars below the minimap, same width: reputation > honor > house favor.
-- Honor and house are shown regardless of Blizzard's "watch" checkbox (house: the tracked one,
-- else the player's own). Reputation needs a watched faction ("Show as experience bar").
-- Hidden or empty bars collapse without gaps. The XP bar lives at the top center (XPBar.lua).
local _, ns = ...
local L = ns.L

local HEIGHT = 10
local GAP_PIXELS = 6 -- 4 px visible (borders sit outside), same as the action bars
local ORDER = { "reputation", "honor", "house" }

local COLORS = {
    renown = { 0.33, 0.65, 1 },
    paragon = { 0.33, 0.65, 1 },
    friendship = { 0.0, 0.6, 0.1 },
    honor = { 1, 0.45, 0.1 },
    house = { 0.85, 0.55, 1 },
}

local bars = {}
local houseFavor -- last payload of HOUSE_LEVEL_FAVOR_UPDATED

local function BarColor(reaction)
    if not ns.REP_COLORS[reaction] then return { 0.5, 0.5, 0.5 } end
    return { ns.RepColor(reaction) }
end

-- Data per bar: nil = nothing to show, else { value, max, color, title, lines = {...} }

local function ReputationData()
    local data = C_Reputation.GetWatchedFactionData()
    if not data or not data.name or data.name == "" then return end
    local id = data.factionID
    local value, max = data.currentStanding - data.currentReactionThreshold,
        data.nextReactionThreshold - data.currentReactionThreshold
    local color, standing = BarColor(data.reaction), _G["FACTION_STANDING_LABEL" .. data.reaction] or ""

    if C_Reputation.IsFactionParagonForCurrentPlayer and C_Reputation.IsFactionParagonForCurrentPlayer(id) then
        local current, threshold, _, rewardPending = C_Reputation.GetFactionParagonInfo(id)
        if current and threshold and threshold > 0 then
            value, max = current % threshold, threshold
            if rewardPending then value = threshold end
        end
        color, standing = COLORS.paragon, L["Paragon"] .. (rewardPending and (" · " .. L["Reward ready!"]) or "")
    elseif C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(id) then
        local major = C_MajorFactions.GetMajorFactionData(id)
        if major then
            value, max = major.renownReputationEarned, major.renownLevelThreshold
            standing = L["Renown %d"]:format(major.renownLevel)
        end
        color = COLORS.renown
    else
        local friend = C_GossipInfo and C_GossipInfo.GetFriendshipReputation(id)
        if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
            standing = friend.reaction or standing
            if friend.nextThreshold then
                value, max = friend.standing - friend.reactionThreshold, friend.nextThreshold - friend.reactionThreshold
            else
                value, max = 1, 1
            end
            color = COLORS.friendship
        end
    end
    if max <= 0 then value, max = 1, 1 end
    return {
        value = value, max = max, color = color, title = data.name,
        lines = { { standing, "" }, { L["Progress"], ("%s / %s"):format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max)) } },
    }
end

local function HonorData()
    if not UnitHonorMax then return end
    local max = UnitHonorMax("player")
    if not max or max <= 0 then return end
    local value = UnitHonor("player")
    return {
        value = value, max = max, color = COLORS.honor, title = L["Honor"],
        lines = {
            { L["Honor level %d"]:format(UnitHonorLevel("player")), "" },
            { L["Progress"], ("%s / %s"):format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max)) },
        },
    }
end

local function HouseData()
    if not (C_Housing and houseFavor and houseFavor.houseLevel) then return end
    local level = houseFavor.houseLevel
    local low = C_Housing.GetHouseLevelFavorForLevel(level) or 0
    local high = C_Housing.GetHouseLevelFavorForLevel(level + 1) or 0
    local maxed = C_Housing.GetMaxHouseLevel and level >= C_Housing.GetMaxHouseLevel()
    local value, max = houseFavor.houseFavor - low, high - low
    if maxed or max <= 0 then value, max = 1, 1 end
    return {
        value = value, max = max, color = COLORS.house, title = L["House favor"],
        lines = {
            { L["House level %d"]:format(level), "" },
            { L["Progress"], maxed and L["Max level"] or ("%s / %s"):format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max)) },
        },
    }
end

local SOURCES = { reputation = ReputationData, honor = HonorData, house = HouseData }

-- Display ------------------------------------------------------------------------------------

local holder

local function ShowTooltip(bar)
    local data = bar.data
    if not data then return end
    GameTooltip:SetOwner(bar, "ANCHOR_LEFT", -4, 0)
    GameTooltip:AddLine(data.title, 1, 1, 1)
    for _, line in ipairs(data.lines) do
        if line[2] == "" then
            GameTooltip:AddLine(line[1], 0.8, 0.8, 0.8)
        else
            GameTooltip:AddDoubleLine(line[1], line[2], 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function CreateBar(key)
    local bar = ns.CreateBar(holder, ns.Snap(HEIGHT))
    bar.followsTheme = true
    bar.PostUpdateColor = nil
    bar:SetStatusBarTexture(ns.MEDIA .. "BarShade") -- shaded, in a thin deep shell
    bar.muiShaded = true
    ns.AddThinShell(bar)
    bar:SetMinMaxValues(0, 1)
    bar:EnableMouse(true)
    bar:SetScript("OnEnter", ShowTooltip)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bar.key = key
    return bar
end

-- Stack visible bars top to bottom without gaps
function ns.UpdateTrackingBars()
    if not holder then return end
    local px = ns.PixelSize()
    -- room for both shells between bars, and for the minimap's frame above the first one
    local height, gap = ns.Snap(HEIGHT), GAP_PIXELS * px + 2 * ns.ThinShellReach()
    local y = ns.MinimapFrameReach() + ns.ThinShellReach() + GAP_PIXELS * px
    -- Visible bars first, mouseover bars last, so an invisible mouseover bar never leaves a gap
    -- between two visible ones
    local order = {}
    for _, key in ipairs(ORDER) do
        if ns.VisibilityMode(ns.db.xpBar.mode) ~= "mouseover" then order[#order + 1] = key end
    end
    for _, key in ipairs(ORDER) do
        if ns.VisibilityMode(ns.db.xpBar.mode) == "mouseover" then order[#order + 1] = key end
    end
    for _, key in ipairs(order) do
        local bar = bars[key]
        local setting = ns.db.xpBar.mode -- one visibility setting for all progress bars
        local data = ns.ShownByMode(setting) and SOURCES[key]() or nil
        bar.muiMouseover = ns.VisibilityMode(setting) == "mouseover"
        bar.data = data
        bar:SetShown(data ~= nil)
        if data then
            bar:SetMinMaxValues(0, data.max)
            bar:SetValue(data.value, ns.SMOOTH)
            bar:SetStatusBarColor(unpack(data.color))
            ns.ColorBarBackground(bar)
            bar:ClearAllPoints()
            -- outer edges line up with the minimap's window frame
            local out = ns.MinimapFrameReach() - ns.ThinShellReach()
            bar:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", -out, -y)
            bar:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", out, -y)
            y = y + height + gap
        end
    end
end

ns:On("PLAYER_LOGIN", function()
    holder = ns.layoutFrames.minimap -- bars hang below the minimap
    if not holder then return end
    for _, key in ipairs(ORDER) do
        bars[key] = CreateBar(key)
        ns.RegisterMouseover(bars[key])
    end
    ns.UpdateTrackingBars()
end)

-- Request house favor (answer arrives as HOUSE_LEVEL_FAVOR_UPDATED). Needed on entering the
-- world and when "Show as experience bar" is toggled in the housing menu.
local houseGUID -- tracked house, or the player's own if none is tracked

local function RequestHouseFavor()
    if not (C_Housing and C_Housing.GetTrackedHouseGuid) then return end
    houseGUID = C_Housing.GetTrackedHouseGuid() or houseGUID
    if DevLog then DevLog("MeredanUI HouseFavor request", houseGUID) end
    if houseGUID then
        C_Housing.GetCurrentHouseLevelFavor(houseGUID)
    elseif C_Housing.GetPlayerOwnedHouses then
        C_Housing.GetPlayerOwnedHouses() -- answer: PLAYER_HOUSE_LIST_UPDATED
    end
end

-- No tracked house: use the first owned one
ns:On("PLAYER_HOUSE_LIST_UPDATED", function(_, houses)
    if houseGUID or not houses or not houses[1] then return end
    houseGUID = houses[1].houseGUID
    if houseGUID then C_Housing.GetCurrentHouseLevelFavor(houseGUID) end
end)
ns:On("PLAYER_ENTERING_WORLD", RequestHouseFavor)
-- "Show as experience bar" checkbox in the housing menu calls SetTrackedHouseGuid
if C_Housing and C_Housing.SetTrackedHouseGuid then
    hooksecurefunc(C_Housing, "SetTrackedHouseGuid", function(guid)
        if guid then houseGUID = guid end -- unchecked: keep the own house
        C_Timer.After(0.2, RequestHouseFavor)
    end)
end

ns:On("HOUSE_LEVEL_FAVOR_UPDATED", function(_, info)
    if DevLog then DevLog("MeredanUI HouseFavor event", info and info.houseGUID, info and info.houseLevel) end
    if info and (info.houseGUID == houseGUID or (C_Housing.GetTrackedHouseGuid
        and info.houseGUID == C_Housing.GetTrackedHouseGuid())) then
        houseFavor = info
        ns.UpdateTrackingBars()
    end
end)
for _, event in ipairs({ "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "HONOR_XP_UPDATE", "HONOR_LEVEL_UPDATE",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    ns:On(event, function() ns.UpdateTrackingBars() end)
end
