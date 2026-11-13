-- PvP tab (Forever rank system): rank badge with a progress ring and bar; details show weekly cap
-- and next reward. Data via C_MajorFactions, faction 2800 = rank points (as in Blizzard's
-- PVPRankFrame.lua). Display only.
local _, ns = ...
local L = ns.L
local Char = ns.Char

local FACTION = 2800
local BLUE = { 0.24, 0.44, 0.82 }
local ticker

local function RankName(rank)
    if not rank or rank <= 0 then return PVP_RANK_0_NAME or "" end
    local alliance = UnitFactionGroup("player") == "Alliance" and 1 or 0
    return GetText("PVP_RANK_" .. (Enum.PvPRanks.Rank_1 + rank - 1) .. "_" .. alliance, UnitSex("player")) or ""
end

local function Create(view)
    local UI = ns.UI
    local left = CreateFrame("Frame", nil, view)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(Char.LIST_W)
    -- Center the block vertically
    local block = CreateFrame("Frame", nil, left)
    block:SetSize(Char.LIST_W, 360)
    block:SetPoint("CENTER", 0, 10)
    left = block
    view.season = UI.Text(left, 13, "CENTER", UI.MUTED)
    view.season:SetPoint("TOP", 0, 0)
    -- Progress ring around the badge (Cooldown frame used as a percentage display)
    local ring = CreateFrame("Frame", nil, left)
    ring:SetSize(160, 160)
    ring:SetPoint("TOP", view.season, "BOTTOM", 0, -18)
    local back = ring:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetTexture("Interface\\Masks\\CircleMaskScalable")
    back:SetVertexColor(0.2, 0.22, 0.22, 1)
    view.cooldown = CreateFrame("Cooldown", nil, ring)
    view.cooldown:SetAllPoints()
    view.cooldown:SetSwipeTexture("Interface\\Masks\\CircleMaskScalable")
    view.cooldown:SetSwipeColor(0.557, 0.796, 0.706, 1)
    view.cooldown:SetReverse(true)
    view.cooldown:SetDrawEdge(false)
    view.cooldown:SetHideCountdownNumbers(true)
    local inner = ring:CreateTexture(nil, "OVERLAY")
    inner:SetSize(140, 140)
    inner:SetPoint("CENTER")
    inner:SetTexture("Interface\\Masks\\CircleMaskScalable")
    inner:SetVertexColor(0.06, 0.06, 0.07, 1)
    local badgeHolder = CreateFrame("Frame", nil, ring)
    badgeHolder:SetAllPoints()
    badgeHolder:SetFrameLevel(view.cooldown:GetFrameLevel() + 2)
    view.badge = badgeHolder:CreateTexture(nil, "ARTWORK")
    view.badge:SetSize(110, 110)
    view.badge:SetPoint("CENTER")
    view.rank = UI.Text(left, 20, "CENTER")
    ns.SetFont(view.rank, 20, "", "bold")
    view.rank:SetPoint("TOP", ring, "BOTTOM", 0, -16)
    view.rankNumber = UI.Text(left, 13, "CENTER", UI.MUTED)
    view.rankNumber:SetPoint("TOP", view.rank, "BOTTOM", 0, -6)
    view.barLabel = UI.Text(left, 12, "LEFT", UI.MUTED)
    view.barLabel:SetPoint("TOPLEFT", view.rankNumber, "BOTTOM", -130, -16)
    view.barLabel:SetText(L["Rank points"])
    view.bar = Char.Bar(left, 20)
    view.bar:SetSize(260, 20)
    view.bar:SetPoint("TOP", view.rankNumber, "BOTTOM", 0, -34)

    view.detail = Char.Detail(view)
    view.detail:SetPoint("TOPLEFT", Char.LIST_W + 14, 0)
    view.detail:SetPoint("BOTTOMRIGHT")
    -- Reward card below the text
    local reward = CreateFrame("Frame", nil, view.detail)
    reward:SetHeight(44)
    UI.Card(reward)
    reward.icon = reward:CreateTexture(nil, "ARTWORK")
    reward.icon:SetSize(32, 32)
    reward.icon:SetPoint("LEFT", 6, 0)
    reward.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    reward.text = UI.Text(reward, 13, "LEFT")
    reward.text:SetPoint("LEFT", reward.icon, "RIGHT", 10, 0)
    reward.text:SetPoint("RIGHT", -8, 0)
    reward:EnableMouse(true)
    reward:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    reward:SetScript("OnLeave", function() GameTooltip:Hide() end)
    reward.vendor = UI.Text(view.detail, 11, "LEFT", UI.MUTED)
    reward.vendor:SetWordWrap(true)
    view.reward = reward
end

local function UpdateSeason(view)
    -- Not EXPANSION_SEASON_NAME: it expects an expansion name, which is empty in Forever ("Season 1 of")
    local season = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
    local text = season > 0 and L["Season %d"]:format(season) or ""
    local left = C_SeasonInfo and C_SeasonInfo.GetTimeUntilCurrentPVPSeasonEnd and C_SeasonInfo.GetTimeUntilCurrentPVPSeasonEnd()
    if left and not issecretvalue(left) and left > 0 then
        text = text .. (text ~= "" and " · " or "") .. SecondsToTime(left, true, true, 2)
    end
    view.season:SetText(text)
end

local function Refresh(view)
    UpdateSeason(view)
    local info = C_MajorFactions.GetMajorFactionProgressionInfo(FACTION)
    local reward = view.reward
    if not info then
        view.rank:SetText(PVP_RANK_0_NAME or "")
        view.rankNumber:SetText("")
        view.bar:Hide()
        view.detail:Empty(Char.G("PVP_RANK_DETAIL_UNAVAILABLE", "No rank information."))
        reward:Hide(); reward.vendor:Hide()
        return
    end
    local rank = info.renownLevel or 0
    local points, threshold = info.renownReputationEarned or 0, info.renownLevelThreshold or 0
    view.rank:SetText(RankName(rank))
    view.rankNumber:SetText(rank > 0 and (PVP_RANK_NUMBER or "%d"):format(rank) or "")
    view.bar:Set(points, threshold, BLUE, ("%s/%s"):format(BreakUpLargeNumbers(points), BreakUpLargeNumbers(threshold)))
    view.bar:Show()
    if rank > 0 then
        view.badge:SetAtlas(("UI-Character-Info-Honor-Icon-%d"):format(rank))
    else
        view.badge:SetAtlas(UnitFactionGroup("player") == "Horde" and "UI-Character-Info-Honor-Icon-Horde" or "UI-Character-Info-Honor-Icon-Alliance")
    end
    local pct = threshold > 0 and points / threshold or 0
    if CooldownFrame_SetDisplayAsPercentage then CooldownFrame_SetDisplayAsPercentage(view.cooldown, pct) end

    -- Detail pane: season target, weekly cap, next reward
    local maxRank = info.maxLevel or 0
    local total = C_MajorFactions.GetTotalReputationForRenownLevel
    local thisWeek = total(FACTION, info.currentWeekProgressiveMaxLevel or 0) - total(FACTION, info.previousWeekProgressiveMaxLevel or 0)
    -- Same grid style as skills: accent header with rule, muted labels, bright values
    local N = BreakUpLargeNumbers
    local UI = ns.UI
    local myTotal = total(FACTION, rank) + points
    local weekCap = total(FACTION, info.currentWeekProgressiveMaxLevel or 0)
    local grid = {
        { a = L["Points"], header = true },
        { a = L["Your points"], c = N(myTotal), aColor = UI.MUTED },
        { a = L["Max this week"], c = weekCap > 0 and N(weekCap) or "–", aColor = UI.MUTED },
        { a = L["Max in the season"], c = N(total(FACTION, maxRank)), aColor = UI.MUTED },
        { a = L["Highest rank"], c = tostring(maxRank), aColor = UI.MUTED },
    }
    if thisWeek > 0 then
        grid[#grid + 1] = { a = L["Limit raised this week"], c = "+" .. N(thisWeek), aColor = UI.MUTED, cColor = { 0.43, 0.82, 0.47 } }
    end
    -- Next reward: own header in the same grid, card below
    local nextRank, rewards
    for test = rank + 1, maxRank do
        local list = C_MajorFactions.GetRenownRewardsForLevel(FACTION, test)
        if list and #list > 0 then nextRank, rewards = test, list break end
    end
    local first = rewards and rewards[1]
    local hasReward = first and (first.name or first.description)
    if hasReward then grid[#grid + 1] = { a = (PVP_RANK_NEXT_REWARD or "%d"):format(nextRank), header = true } end
    view.detail:Fill({ title = L["Progress"], sub = view.season:GetText(), grid = grid })

    if hasReward then
        reward:ClearAllPoints()
        reward:SetPoint("TOPLEFT", view.detail.lastAnchor, "BOTTOMLEFT", 0, -10)
        reward:SetPoint("RIGHT", view.detail, "RIGHT", -16, 0)
        reward.icon:SetTexture(first.icon or 134400)
        reward.text:SetText(first.name or first.description)
        reward.itemID = first.itemID
        local quality = first.itemID and C_Item.GetItemQualityByID(first.itemID)
        if quality then reward.text:SetTextColor(C_Item.GetItemQualityColor(quality)) else reward.text:SetTextColor(unpack(ns.UI.TEXT)) end
        reward.vendor:SetText(UnitFactionGroup("player") == "Horde" and (PVP_RANK_REWARDS_VENDOR_HORDE or "") or (PVP_RANK_REWARDS_VENDOR_ALLIANCE or ""))
        reward.vendor:ClearAllPoints()
        reward.vendor:SetPoint("TOPLEFT", reward, "BOTTOMLEFT", 0, -8)
        reward.vendor:SetPoint("RIGHT", reward, "RIGHT")
        reward:Show(); reward.vendor:Show()
    else
        reward:Hide(); reward.vendor:Hide()
    end
end

Char.AddTab({
    key = "pvp", order = 4, tip = Char.G("CHARACTER_FRAME_TAB_PVP", "PvP"),
    icon = function(texture)
        texture:SetTexture(UnitFactionGroup("player") == "Horde" and 8197098 or 8197097)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end,
    Create = function(view)
        Create(view)
        -- Season countdown: update every minute, only while the tab is open
        view:HookScript("OnShow", function()
            if ticker then ticker:Cancel() end
            ticker = C_Timer.NewTicker(60, function() UpdateSeason(view) end)
        end)
        view:HookScript("OnHide", function() if ticker then ticker:Cancel() ticker = nil end end)
        if ticker then ticker:Cancel() end
        ticker = C_Timer.NewTicker(60, function() UpdateSeason(view) end)
    end,
    Refresh = Refresh,
    events = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_PVP_RANK_CHANGED" },
})
