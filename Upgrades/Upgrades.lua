-- Upgrade scoring ("mini Pawn", Retail): estimates how much more or less damage an item gives vs.
-- the equipped one for the active spec. Tooltip: "+2.4 %" green / "-1.1 %" red; bags: green arrow.
--   - Secondary stats: Bloodmallet sims (UpgradeData.lua), evaluated at the player's current stat
--     distribution - stacking one stat gives diminishing value.
--   - Overall value of a secondary rating point comes from the player's real stats (percent per
--     rating, current percentages); primary stat: 1 / current primary stat.
--   - Trinkets with effects: simulated gain per item level instead of their stats.
--   - Rings/trinkets vs. the weaker of both; two-handers vs. main + off hand.
--   - Only items Blizzard says the spec can use (armor type, primary stat, weapon).
-- Sockets and enchants are ignored (both sides treated the same).
local _, ns = ...
local L = ns.L

local DATA = ns.UPGRADE_DATA or { terms = {}, specs = {}, fallback = {} } -- not loaded on Forever
local Readable = ns.Readable
local STATS = { "crit", "haste", "mastery", "vers" }
-- Rating indices (CR_CRIT_MELEE, CR_HASTE_MELEE, CR_MASTERY, CR_VERSATILITY_DAMAGE_DONE)
local RATINGS = { crit = 9, haste = 18, mastery = 26, vers = 29 }
local ITEM_STATS = {
    crit = "ITEM_MOD_CRIT_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT", vers = "ITEM_MOD_VERSATILITY",
}
local PRIMARY = { [1] = "STRENGTH", [2] = "AGILITY", [4] = "INTELLECT" }
local GRID_MIN, GRID_MAX = 0.1, 0.7 -- Bloodmallet simulates 10-70 % per stat
local EPS = 0.01
local GREEN = { 0.25, 0.9, 0.35 }
local RED = { 1, 0.3, 0.3 }
ns.UPGRADE_COLOR = GREEN

local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
}
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local OFF_HAND = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
local MAIN_HAND, OFF_HAND_SLOT = 16, 17

-- Forever is scored by ForeverPawn.lua (own weights); this file only computes for Retail.
-- Mode: "damage" = % more total damage (default), "item" = % better than the equipped item
-- (like Pawn), "off" (legacy checkbox values true/false are mapped as well)
function ns.UpgradeMode()
    local mode = ns.db and ns.db.upgrades
    if mode == false or mode == "off" then return "off" end
    return mode == "item" and "item" or "damage"
end
local function Enabled() return ns.UpgradeMode() ~= "off" and not ns.IS_FOREVER end

local weights   -- value per point as fraction of extra damage, for the active spec
local scores = {} -- link -> score

-- Bloodmallet polynomial: DPS (fraction of base DPS) at shares x = { crit, haste, mastery }
local function Poly(fit, x)
    local sum = 0
    for i, term in ipairs(DATA.terms) do
        local v = fit[i]
        for _, k in ipairs(term) do v = v * x[k] end
        sum = sum + v
    end
    return sum
end

local function Clamp(v) return math.min(math.max(v, GRID_MIN), GRID_MAX) end

-- Average value of one secondary rating point: percent per rating (with diminishing returns)
-- divided by what the stat already gives. Mastery differs per spec and is left out - its
-- deviation from the others comes from the sims.
local function MeanRatingValue()
    local melee, spell, haste = GetCritChance(), GetSpellCritChance(), GetHaste()
    -- Some values are secret in combat: no result then, recompute later
    if not (Readable(melee) and Readable(spell) and Readable(haste)) then return nil end
    local current = {
        crit = math.max(melee or 0, spell or 0),
        haste = haste,
        vers = nil,
    }
    local versRating, versBonus = GetCombatRatingBonus(RATINGS.vers), GetVersatilityBonus(RATINGS.vers)
    if not (Readable(versRating) and Readable(versBonus)) then return nil end
    current.vers = (versRating or 0) + (versBonus or 0)
    local sum, count = 0, 0
    for stat, percent in pairs(current) do
        local rating = GetCombatRating(RATINGS[stat])
        if Readable(percent) and Readable(rating) and percent and rating then
            local from = GetCombatRatingBonusForCombatRatingValue(RATINGS[stat], rating)
            local to = GetCombatRatingBonusForCombatRatingValue(RATINGS[stat], rating + 100)
            if Readable(from) and Readable(to) and from and to then
                sum = sum + (to - from) / 100 / 100 / (1 + percent / 100)
                count = count + 1
            end
        end
    end
    return count > 0 and sum / count or nil
end

local function BuildWeights()
    local index = C_SpecializationInfo.GetSpecialization()
    if not index then return end
    local specID, _, _, _, _, primaryIndex = C_SpecializationInfo.GetSpecializationInfo(index)
    local _, primary = UnitStat("player", primaryIndex or 0)
    local mean = MeanRatingValue()
    if not (specID and PRIMARY[primaryIndex] and mean and Readable(primary) and primary > 0) then return end

    local w = { specID = specID, primaryKey = PRIMARY[primaryIndex], primary = 1 / primary }
    local spec = DATA.specs[specID]
    if spec then
        -- Sim slope at the current distribution; versatility is the remainder (fixed total), so this
        -- only yields differences between stats - the mean comes from MeanRatingValue.
        local ratings, total = {}, 0
        for _, stat in ipairs(STATS) do
            local rating = GetCombatRating(RATINGS[stat])
            ratings[stat] = Readable(rating) and rating or 0
            total = total + ratings[stat]
        end
        local x = { 0.25, 0.25, 0.25 }
        if total > 0 then
            x = { Clamp(ratings.crit / total), Clamp(ratings.haste / total), Clamp(ratings.mastery / total) }
        end
        local slope = {}
        for k = 1, 3 do
            local up, down = { x[1], x[2], x[3] }, { x[1], x[2], x[3] }
            up[k], down[k] = x[k] + EPS, x[k] - EPS
            slope[k] = (Poly(spec.fit, up) - Poly(spec.fit, down)) / (2 * EPS)
        end
        local vers = -(slope[1] + slope[2] + slope[3]) / 4
        local deviation = { crit = slope[1] + vers, haste = slope[2] + vers, mastery = slope[3] + vers, vers = vers }
        for _, stat in ipairs(STATS) do
            w[stat] = math.max(mean + deviation[stat] / spec.total, 0)
        end
        w.trinkets = spec.trinkets
    else
        -- No sims (healers etc.): stat ratios from Pawn
        local _, _, classID = UnitClass("player")
        local ratio = DATA.fallback[classID .. "-" .. index]
        for _, stat in ipairs(STATS) do w[stat] = mean * (ratio and ratio[stat] or 1) end
    end
    weights = w
    wipe(scores)
    if DevLog then -- dev aid: weights relative to primary stat (1 = worth 1 primary stat point)
        DevLog("MeredanUI", ("Upgrade-Gewichte Spec %d (%s): Krit %.2f, Tempo %.2f, Meist. %.2f, Viels. %.2f"):format(
            specID, spec and "Bloodmallet" or "Pawn", w.crit / w.primary, w.haste / w.primary,
            w.mastery / w.primary, w.vers / w.primary))
    end
end

-- Simulated trinket gain at an item level (linear between sim levels, extrapolated with the
-- slope of the outermost levels)
local function TrinketGain(byLevel, level)
    local levels = byLevel.sorted
    if not levels then
        levels = {}
        for l in pairs(byLevel) do if type(l) == "number" then levels[#levels + 1] = l end end
        table.sort(levels)
        byLevel.sorted = levels
    end
    if #levels == 1 then return byLevel[levels[1]] end
    local i = 1
    while i < #levels - 1 and level > levels[i + 1] do i = i + 1 end
    local a, b = levels[i], levels[i + 1]
    return byLevel[a] + (byLevel[b] - byLevel[a]) * (level - a) / (b - a)
end

-- Item score (fraction of extra damage), nil = data not loaded yet
local function Score(link)
    if not link then return 0 end
    local cached = scores[link]
    if cached then return cached end
    local itemID = C_Item.GetItemInfoInstant(link)
    local level = C_Item.GetDetailedItemLevelInfo(link)
    local trinket = weights.trinkets and itemID and weights.trinkets[itemID]
    local score
    if trinket and level then
        score = TrinketGain(trinket, level)
    else
        ---@diagnostic disable-next-line: redundant-parameter
        local stats = C_Item.GetItemStats(link, {}) -- with a table, like Pawn
        if not stats then return nil end
        local primary = 0
        for key, value in pairs(stats) do
            if key:find(weights.primaryKey, 1, true) then primary = math.max(primary, value) end
        end
        score = primary * weights.primary
        for _, stat in ipairs(STATS) do score = score + (stats[ITEM_STATS[stat]] or 0) * weights[stat] end
    end
    scores[link] = score
    return score
end

local function Equipped(slot) return GetInventoryItemLink("player", slot) end

-- Trinket with sim data? Without sims only stats count, not the effect - any comparison with a
-- simulated trinket would be skewed, so give no result instead.
local function Simulated(link)
    if not link then return true end -- empty slot
    local itemID = C_Item.GetItemInfoInstant(link)
    return weights.trinkets ~= nil and itemID ~= nil and weights.trinkets[itemID] ~= nil
end

local function EquipLoc(link)
    if not link then return end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    return equipLoc
end

-- Score of what the new item would replace (nil = not meaningfully comparable)
local function ReplacedScore(equipLoc, link)
    local slots = SLOTS[equipLoc]
    if slots then
        local worst
        for _, slot in ipairs(slots) do
            local current = Equipped(slot)
            if current == link then return end -- this is the equipped item itself
            local score = Score(current)
            if not score then return end
            worst = worst and math.min(worst, score) or score
        end
        return worst
    end
    local main, off = Equipped(MAIN_HAND), Equipped(OFF_HAND_SLOT)
    if link == main or link == off then return end
    local mainScore, offScore = Score(main), Score(off)
    if not (mainScore and offScore) then return end
    local mainIsTwoHand = TWO_HAND[EquipLoc(main)]
    if TWO_HAND[equipLoc] then return mainScore + offScore end
    if OFF_HAND[equipLoc] then
        if mainIsTwoHand then return end -- an off hand alone doesn't replace a two-hander
        return offScore
    end
    if equipLoc == "INVTYPE_WEAPONMAINHAND" then return mainScore end
    if equipLoc == "INVTYPE_WEAPON" then
        -- One-hander: when dual wielding compare against the weaker weapon, else the main hand
        if not mainIsTwoHand and off and CanDualWield() and not OFF_HAND[EquipLoc(off)] then
            return math.min(mainScore, offScore)
        end
        return mainScore
    end
end

local function UsableBySpec(link)
    local specs = C_Item.GetItemSpecInfo(link)
    if not specs or #specs == 0 then return true end -- unrestricted (rings, neck ...)
    for _, id in ipairs(specs) do
        if id == weights.specID then return true end
    end
    return false
end

-- Difference in percent (+ better, - worse) depending on mode; nil = no result
function ns.UpgradePercent(link)
    -- Forever: own scoring (ForeverPawn.lua), same display
    if ns.IS_FOREVER then
        if ns.UpgradeMode() == "off" or not Readable(link) or not link then return end
        return ns.ForeverUpgradePercent and ns.ForeverUpgradePercent(link)
    end
    if not Enabled() or not Readable(link) or not link then return end
    if not weights then BuildWeights() end
    if not weights then return end
    local equipLoc = EquipLoc(link)
    if not equipLoc or equipLoc == "" or not (SLOTS[equipLoc] or TWO_HAND[equipLoc] or OFF_HAND[equipLoc]
        or equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND") then return end
    if not UsableBySpec(link) then return end
    if equipLoc == "INVTYPE_TRINKET" and not (Simulated(link) and Simulated(Equipped(13)) and Simulated(Equipped(14))) then
        return
    end
    local score = Score(link)
    if not score or score <= 0 then return end
    local replaced = ReplacedScore(equipLoc, link)
    if not replaced then return end
    if ns.UpgradeMode() == "item" then
        if replaced <= 0 then return end -- empty slot: no meaningful percentage
        return (score - replaced) / replaced * 100
    end
    return (score - replaced) * 100
end

-- Empty gear slots (common while leveling): items that would fill one get a bag marker and a
-- "Fills empty slot: ..." tooltip line. Only wearable items (no red tooltip lines: class, armor
-- type, level). Shirt, tabard, ammo and bags don't count; off hand only without a two-hander.
local RANGED_TYPES = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true }
local rangedSlot
local function RangedSlot()
    if rangedSlot == nil then
        local ok, id = pcall(GetInventorySlotInfo, "RANGEDSLOT")
        rangedSlot = ok and id or false
    end
    return rangedSlot
end

-- Base proficiencies per class (classic rules; the tooltip alone doesn't catch e.g. a shield for a
-- rogue). Armor (class 4): 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield, 7 libram, 8 idol, 9 totem;
-- 0 (trinkets, rings, held in off hand) is allowed for all. Weapons (class 2): 0 1H axe, 1 2H axe,
-- 2 bow, 3 gun, 4 1H mace, 5 2H mace, 6 polearm, 7 1H sword, 8 2H sword, 10 staff, 13 fist weapon,
-- 15 dagger, 16 thrown, 18 crossbow, 19 wand. Level requirements (mail at 40 ...) are checked
-- afterwards via the tooltip.
local ARMOR, WEAPON = 4, 2
local function Set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local PROFICIENCY = {
    WARRIOR = { [ARMOR] = Set(0, 1, 2, 3, 4, 6), [WEAPON] = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18) },
    PALADIN = { [ARMOR] = Set(0, 1, 2, 3, 4, 6, 7), [WEAPON] = Set(0, 1, 4, 5, 6, 7, 8) },
    HUNTER  = { [ARMOR] = Set(0, 1, 2, 3), [WEAPON] = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18) },
    ROGUE   = { [ARMOR] = Set(0, 1, 2), [WEAPON] = Set(2, 3, 4, 7, 13, 15, 16, 18) },
    PRIEST  = { [ARMOR] = Set(0, 1), [WEAPON] = Set(4, 10, 15, 19) },
    SHAMAN  = { [ARMOR] = Set(0, 1, 2, 3, 6, 9), [WEAPON] = Set(0, 1, 4, 5, 10, 13, 15) },
    MAGE    = { [ARMOR] = Set(0, 1), [WEAPON] = Set(7, 10, 15, 19) },
    WARLOCK = { [ARMOR] = Set(0, 1), [WEAPON] = Set(7, 10, 15, 19) },
    DRUID   = { [ARMOR] = Set(0, 1, 2, 8), [WEAPON] = Set(4, 5, 10, 13, 15) },
}
local playerClass

local function CanWear(link, itemID)
    playerClass = playerClass or select(2, UnitClass("player"))
    local allowed = PROFICIENCY[playerClass]
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    if allowed and allowed[classID] and not allowed[classID][subclassID] then return false end
    if ns.ItemUsable then return ns.ItemUsable(link) end -- Forever: tooltip check (ForeverPawn.lua)
    return C_PlayerInfo.CanUseItem and C_PlayerInfo.CanUseItem(itemID)
end

-- Returns the empty slot's name (e.g. "Wrist") or nil
function ns.FillsEmptySlot(link)
    if ns.db and ns.db.emptySlots == false then return end
    if not link or not Readable(link) then return end
    local itemID, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    if not itemID or not equipLoc or equipLoc == "" then return end
    local empty
    if SLOTS[equipLoc] then
        for _, slot in ipairs(SLOTS[equipLoc]) do
            if not Equipped(slot) then empty = true break end
        end
    elseif RANGED_TYPES[equipLoc] and RangedSlot() then
        empty = not Equipped(RangedSlot())
    else
        local main, off = Equipped(MAIN_HAND), Equipped(OFF_HAND_SLOT)
        local mainIsTwoHand = main and TWO_HAND[EquipLoc(main)]
        local mainName = INVTYPE_WEAPONMAINHAND or "Main Hand"
        local offName = INVTYPE_WEAPONOFFHAND or "Off Hand"
        if TWO_HAND[equipLoc] or equipLoc == "INVTYPE_WEAPONMAINHAND" then
            empty = not main and mainName
        elseif equipLoc == "INVTYPE_WEAPON" then
            empty = (not main and mainName) or (not off and not mainIsTwoHand and CanDualWield() and offName)
        elseif OFF_HAND[equipLoc] then
            -- Off-hand weapons need dual wield (warrior/hunter from 20); shields and held items
            -- are checked via the tooltip (red when not wearable)
            local needsDualWield = equipLoc == "INVTYPE_WEAPONOFFHAND" and not CanDualWield()
            empty = not off and not mainIsTwoHand and not needsDualWield and offName
        end
    end
    if not empty or not CanWear(link, itemID) then return end
    return type(empty) == "string" and empty or _G[equipLoc] or equipLoc
end

local function FormatPercent(value)
    local text = ("%.1f"):format(math.abs(value)):gsub("%.", L["DECIMAL_SEPARATOR"])
    return (value >= 0 and "+" or "−") .. text .. " %"
end

-- Item tooltip line (called from Tooltip.lua before the IDs)
function ns.AddUpgradeLine(tooltip, data)
    if data.type ~= Enum.TooltipDataType.Item then return end
    -- Like TooltipUtil.GetDisplayedItem: bag items only carry the GUID
    local link
    if Readable(data.guid) and data.guid then link = C_Item.GetItemLinkByGUID(data.guid) end
    if not link and Readable(data.hyperlink) then link = data.hyperlink end
    if not link then return end
    local emptySlot = ns.FillsEmptySlot(link)
    if emptySlot then
        tooltip:AddLine(" ")
        tooltip:AddLine(L["Fills empty slot: %s"]:format(emptySlot), 0.56, 0.8, 0.71)
        return
    end
    local function Line(percent, label)
        local color = percent > 0 and GREEN or RED
        -- Flat triangle prefix: green pointing up, red pointing down
        local icon = ns.UI.IconMarkup(percent > 0 and "Upgrade" or "Downgrade", 11, color, 2)
        if label then
            tooltip:AddDoubleLine(icon .. " " .. label, FormatPercent(percent), color[1], color[2], color[3], color[1], color[2], color[3])
        else
            tooltip:AddLine(icon .. " " .. FormatPercent(percent), unpack(color))
        end
    end
    -- One-hander while dual wielding (Forever): both hands
    if ns.IS_FOREVER and ns.UpgradeMode() ~= "off" and ns.ForeverUpgradeHands then
        local mainPct, offPct = ns.ForeverUpgradeHands(link)
        if mainPct then
            tooltip:AddLine(" ")
            Line(mainPct, INVTYPE_WEAPONMAINHAND or "Main Hand")
            Line(offPct, INVTYPE_WEAPONOFFHAND or "Off Hand")
            return
        end
    end
    local percent = ns.UpgradePercent(link)
    if not percent or math.abs(percent) < 0.05 then return end
    tooltip:AddLine(" ")
    Line(percent)
end

-- Stats change with gear and spec; wait briefly until the new values settle
local pending
local queued
local function Rebuild()
    -- Some stats are secret in combat: recompute once after combat
    if InCombatLockdown() then
        if not queued then
            queued = true
            ns.AfterCombat(function() queued = false; Rebuild() end)
        end
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        if not ns.IS_FOREVER then BuildWeights() end
        if ns.RefreshBags then ns.RefreshBags() end
    end)
end
-- Save memory: keep only the player's class specs (the table holds ~40 specs with ~70 trinkets
-- each); the rest is garbage collected
ns:On("PLAYER_LOGIN", function()
    local _, _, classID = UnitClass("player")
    if not classID or ns.IS_FOREVER then return end
    local keep = {}
    for index = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
        local specID = GetSpecializationInfoForClassID(classID, index)
        if specID then keep[specID] = true end
    end
    for specID in pairs(DATA.specs) do
        if not keep[specID] then DATA.specs[specID] = nil end
    end
    for key in pairs(DATA.fallback) do
        if not key:find("^" .. classID .. "%-") then DATA.fallback[key] = nil end
    end
end)
ns:On("PLAYER_ENTERING_WORLD", Rebuild)
ns:On("PLAYER_EQUIPMENT_CHANGED", Rebuild)
ns:On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", Rebuild)
ns:On("GET_ITEM_INFO_RECEIVED", function() if ns.RefreshBags then ns.RefreshBags() end end)
