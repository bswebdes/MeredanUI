-- Role layouts: where elements sit and which behavior is role-specific. Stored per profile
-- (ns.db.layout). Melee DPS is the base; other layouts only set flags that modules query via
-- ns.LayoutFlag("..."). Switching needs no reload: all positions go through ns.OnLayout.
local _, ns = ...
local L = ns.L

ns.LAYOUTS = {
    {
        id = "melee", name = L["Melee DPS"],
        flags = {
            questlogAboveFocus = true,    -- quest log ends above the focus frame (overlaps on 16:9 otherwise)
            questlogUnderBosses = true,   -- if boss frames cover the quest log (16:9), move it below them, instance quests only
        },
    },
    {
        id = "ranged", name = L["Ranged DPS"],
        flags = {
            questlogAboveFocus = true,
            questlogUnderBosses = true,
            castbarAboveBars = true,      -- large castbar above the bottom bars (not in the player frame)
        },
    },
    {
        id = "tank", name = L["Tank"],
        flags = {
            questlogAboveFocus = true,
            questlogUnderBosses = true,
            tank = true,                  -- threat: lead over second place; nameplates: red = aggro lost
            bigDebuffs = true,            -- larger own debuffs (pet frame moves down; needs reload)
        },
    },
    {
        id = "healer", name = L["Healer"],
        flags = {
            questlogAboveFocus = true,
            questlogUnderBosses = true,
            healerGroups = true,          -- group 5-40 centered between player and target (needs reload)
            healPrediction = true,        -- heal prediction in group frames
            healerBars = true,            -- main bar as a 12-button row at the bottom above Alt/Shift, stance bar to its left
            castbarAboveBars = true,      -- large castbar above the bottom bars (like ranged)
        },
    },
}

local byId = {}
for _, layout in ipairs(ns.LAYOUTS) do byId[layout.id] = layout end

function ns.CurrentLayout()
    return byId[ns.db and ns.db.layout] or byId[ns.DEFAULT_LAYOUT]
end

function ns.LayoutFlag(flag)
    return ns.CurrentLayout().flags[flag] == true
end

-- "Stacked" bar arrangement: main bar as a 12-button row at the bottom above Alt/Shift.
-- Always for healers; otherwise ns.db.barVariant ("center" = centered 2x6, "stacked"). Applied at build time.
function ns.StackedBars()
    return ns.LayoutFlag("healerBars") or ns.db.barVariant == "stacked"
end

-- Anchor for swing timer/threat bar below the main bar: returns (top, width). When stacked the main
-- bar is at the bottom, so use where it would be when centered (top edge of the unit frames).
function ns.BelowMainBar(gap)
    local main = ns.actionBars and ns.actionBars[1]
    if not (main and main:GetBottom()) then return end
    local _, cy = UIParent:GetCenter()
    if ns.StackedBars() then
        local player = ns.frames and ns.frames.player
        local top = player and player:GetTop() and (player:GetTop() - cy) or -ns.Snap(ns.FRAME_TOP_Y)
        return top, ns.Snap(ns.MainBarWidth())
    end
    return main:GetBottom() - cy - gap, ns.Snap(main:GetWidth())
end

-- Re-apply positions and quest log hiding (deferred until after combat)
function ns.ApplyLayout()
    if ns.Relayout then ns.Relayout() end
    if ns.UpdateQuestlogHiding then ns.UpdateQuestlogHiding() end
    if ns.ClampQuestlogHeight then ns.ClampQuestlogHeight() end
end

function ns.SetLayout(id)
    if not byId[id] then return end
    ns.db.layout = id
    ns.ApplyLayout()
end

-- Healer layout metrics in one place; bars, unit frames, group, class bar, threat and swing timer
-- all use them. Bottom to top: 3 bars of 12 (Shift, Alt, main) > large castbar > group (4 rows) >
-- threat/swing timer/class bar. Player and target sit left/right of the group, top-aligned.
ns.HEALER = {
    barSize = 36,      -- same as the extra bars
    castHeight = 32, castGap = 6,
    groupGap = 10,     -- castbar > group
    frameH = 61, rows = 4, gap = 4,
    groupWidth = 551,  -- 5 x 107 or 10 x 51 incl. gaps
    sideGap = 32,      -- group > player/target (room for reagents next to the player)
}
function ns.HealerGeometry()
    local H = ns.HEALER
    local px = ns.PixelSize()
    local barGap = ns.MAIN_BAR.gapPixels * px
    local bottom = (UIParent:GetBottom() or 0) + ns.Snap(ns.SCREEN_MARGIN)
    local barsTop = bottom + 3 * ns.Snap(H.barSize) + 2 * barGap
    local castTop = barsTop + ns.Snap(H.castGap) + ns.Snap(H.castHeight)
    local groupBottom = castTop + ns.Snap(H.groupGap)
    local groupHeight = H.rows * ns.Snap(H.frameH) + (H.rows - 1) * ns.Snap(H.gap)
    local width = ns.Snap(H.groupWidth)
    return {
        groupTop = groupBottom + groupHeight, groupBottom = groupBottom, groupWidth = width,
        innerX = width / 2 + ns.Snap(H.sideGap), -- distance of the player/target inner edge from center
    }
end
