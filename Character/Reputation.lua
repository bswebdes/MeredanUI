-- Reiter „Ruf“: Liste mit Gruppen (auf-/zuklappbar, „Inaktiv“ als eigene Gruppe – kommt so von
-- Blizzard), Balken in den mUI-Ruffarben, rechts Details mit Im Krieg / Inaktiv / Als Leiste.
-- Achtung: Blizzard arbeitet mit Listen-Indizes; nach Inaktiv/Auf-Zu verschieben sie sich, darum
-- merken wir die Auswahl per factionID.
local _, ns = ...
local L = ns.L
local Char = ns.Char

local selectedID -- factionID

local function StandingText(reaction)
    return GetText("FACTION_STANDING_LABEL" .. reaction, UnitSex("player")) or ""
end

-- Werte für Balken: Standard oder Freundschaft
local function Progress(data)
    local friendship = C_GossipInfo and C_GossipInfo.GetFriendshipReputation and C_GossipInfo.GetFriendshipReputation(data.factionID)
    if friendship and friendship.friendshipFactionID and friendship.friendshipFactionID > 0 then
        local low, high = friendship.reactionThreshold or 0, friendship.nextThreshold
        local max = high and (high - low) or 1
        local value = high and (friendship.standing - low) or 1
        return value, max, friendship.reaction or "", { ns.RepColor(5) }, high == nil
    end
    local reaction = data.reaction or 4
    local low, high = data.currentReactionThreshold or 0, data.nextReactionThreshold or 1
    local done = reaction >= (MAX_REPUTATION_REACTION or 8)
    local max = done and 1 or math.max(high - low, 1)
    local value = done and 1 or (data.currentStanding or 0) - low
    return value, max, StandingText(reaction), { ns.RepColor(reaction) }, done
end

local function Refresh(view)
    local entries = {}
    local selectedData, selectedIndex
    for i = 1, C_Reputation.GetNumFactions() do
        local data = C_Reputation.GetFactionDataByIndex(i)
        if data and data.name then
            local index = i
            if data.isHeader and not data.isHeaderWithRep then
                entries[#entries + 1] = {
                    header = true, text = data.name, collapsed = data.isCollapsed,
                    onClick = function()
                        if data.isCollapsed then C_Reputation.ExpandFactionHeader(index) else C_Reputation.CollapseFactionHeader(index) end
                    end,
                }
            else
                local value, max, standing, color = Progress(data)
                local selected = data.factionID == selectedID
                if selected then selectedData, selectedIndex = data, index end
                entries[#entries + 1] = {
                    text = data.name, indent = data.isChild and 12 or 0, selected = selected,
                    color = data.atWarWith and { 0.9, 0.4, 0.4 } or nil,
                    bar = { value = value, max = max, color = color, text = standing },
                    onClick = function()
                        selectedID = data.factionID
                        C_Reputation.SetSelectedFaction(index)
                        Char.Refresh()
                    end,
                    onEnter = function(row)
                        -- Zahlen beim Drüberfahren (wie Blizzard)
                        if max > 1 then row.bar.text:SetText(("%s/%s"):format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max))) end
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:SetText(data.name, 1, 1, 1)
                        GameTooltip:AddLine(standing, color[1], color[2], color[3])
                        if data.isAccountWide and REPUTATION_TOOLTIP_ACCOUNT_WIDE_LABEL then
                            GameTooltip:AddLine(REPUTATION_TOOLTIP_ACCOUNT_WIDE_LABEL, 0.51, 0.77, 1)
                        end
                        GameTooltip:Show()
                        row:SetScript("OnLeave", function(self)
                            self.bar.text:SetText(standing)
                            GameTooltip:Hide()
                            self:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        end)
                    end,
                }
            end
        end
    end
    view.list:SetData(entries)

    if not selectedData then
        view.detail:Empty(Char.G("REPUTATION_DETAIL_SELECT_PROMPT", "Select a faction to see its details."))
        return
    end
    local data, index = selectedData, selectedIndex
    local value, max, standing, color, done = Progress(data)
    local active = C_Reputation.IsFactionActive(index)
    local watched = data.isWatched
    view.detail:Fill({
        title = data.name, sub = standing, subColor = color,
        bar = { value = value, max = max, color = color, text = done and standing or ("%s/%s"):format(BreakUpLargeNumbers(value), BreakUpLargeNumbers(max)) },
        text = data.description,
        checks = {
            { label = Char.G("AT_WAR", "At war"), checked = data.atWarWith, enabled = data.canToggleAtWar and not data.isHeader,
              onClick = function() C_Reputation.ToggleFactionAtWar(index) end },
            { label = Char.G("MOVE_TO_INACTIVE", "Inactive"), checked = not active, enabled = data.canSetInactive,
              onClick = function() C_Reputation.SetFactionActive(index, not active) end },
            { label = L["Show as bar"], checked = watched,
              onClick = function()
                  C_Reputation.SetWatchedFactionByIndex(watched and 0 or index)
                  if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then StatusTrackingBarManager:UpdateBarsShown() end
              end },
        },
    })
end

Char.AddTab({
    key = "reputation", order = 2, tip = Char.G("CHARACTER_FRAME_TAB_REPUTATION", "Reputation"), icon = 8197103,
    Create = Char.ListAndDetail, Refresh = Refresh,
    OnHide = function() selectedID = nil end,
    events = { "UPDATE_FACTION", "QUEST_LOG_UPDATE", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "MAJOR_FACTION_UNLOCKED" },
})
