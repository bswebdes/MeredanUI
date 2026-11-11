-- Forever Pawn: upgrade scoring for WoW Forever (level 60, Classic stats). Same display as Retail
-- (arrow in bags/loot/rolls, "+x %" in the tooltip), but own scoring:
--   - Weights per class and talent tree from ForeverWeights.lua (WoWSims + Forever Codex).
--   - Item stats from C_Item.GetItemStats; what is missing there (hit, crit, spell damage ... are
--     often only "Equip: ..." lines in Forever) is parsed from the tooltip by German/English
--     keywords. Percent -> rating as in WoWSims (14 = 1 % crit, 10 = 1 % hit).
--   - Weapon DPS: weight from the data, else Classic rule of thumb 1 DPS ~ 14 attack power.
--   - Percent = difference to the replaced item, relative to the value of all equipped gear.
-- Sockets, enchants and set bonuses are ignored. Only items the player can wear (no red text).
local _, ns = ...
local Readable = ns.Readable

local RATING_PER_PERCENT = { crit = 14, hit = 10, haste = 10, exp = 10 }
-- Default talent tree while no points are spent (typical leveling spec)
local DEFAULT_TREE = { WARRIOR = 1, ROGUE = 2, PRIEST = 3, DRUID = 2, SHAMAN = 2, PALADIN = 3 }

local API_STATS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_MANA_REGEN_SHORT = "mp5",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit", ITEM_MOD_HIT_SPELL_RATING_SHORT = "hit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "crit",
    ITEM_MOD_HASTE_RATING_SHORT = "haste", ITEM_MOD_EXPERTISE_RATING_SHORT = "exp",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "arp", ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "def",
    ITEM_MOD_DODGE_RATING_SHORT = "dodge", ITEM_MOD_PARRY_RATING_SHORT = "parry",
    ITEM_MOD_BLOCK_VALUE_SHORT = "blockvalue", ITEM_MOD_SPELL_PENETRATION_SHORT = "spellpen",
    RESISTANCE0_NAME = "armor",
}
-- "Spell damage and healing" counts for both
local API_BOTH = { ITEM_MOD_SPELL_POWER_SHORT = true, ITEM_MOD_SPELL_POWER = true }
local API_PERCENT = { -- percent variants without "rating"
    ITEM_MOD_HIT_SHORT = "hit", ITEM_MOD_HIT_SPELL_SHORT = "hit", ITEM_MOD_CRIT_SHORT = "crit",
    ITEM_MOD_CRIT_SPELL_SHORT = "crit", ITEM_MOD_HASTE_SHORT = "haste",
}

-- School keywords (de/en) -> weight key
local SCHOOLS = {
    { "feuer", "fire", key = "fire" }, { "frost", "frost", key = "frost" },
    { "schatten", "shadow", key = "shadow" }, { "arkan", "arcane", key = "arcane" },
    { "natur", "nature", key = "nature" }, { "heilig", "holy", key = "holy" },
}

local function Has(text, ...)
    for i = 1, select("#", ...) do
        if text:find((select(i, ...)), 1, true) then return true end
    end
    return false
end

-- Parse one "Equip:" line (already lowercased) into stats
local function ParseEquipLine(text, stats)
    -- Ignore bonuses against one creature type ("+4 attack power against humanoids") - otherwise the
    -- item would be scored as if it had full attack power
    if Has(text, " gegen ", " against ", "when fighting", "im kampf gegen") then return end
    local number = tonumber((text:match("(%d+[%.,]?%d*)") or ""):gsub(",", "."), 10)
    if not number then return end
    local percent = text:find("%", 1, true) ~= nil
    local function Put(key, value)
        if percent and RATING_PER_PERCENT[key] then value = value * RATING_PER_PERCENT[key] end
        stats[key] = math.max(stats[key] or 0, value)
    end
    if percent then
        if Has(text, "kritisch", "critical") then return Put("crit", number) end
        if Has(text, "tempo", "haste", "attack speed", "angriffsgeschwindigkeit") then return Put("haste", number) end
        if Has(text, "treffer", "hit") then return Put("hit", number) end
        return
    end
    if Has(text, "angriffskraft", "attack power") then
        return Put(Has(text, "distanz", "ranged") and "rap" or "ap", number)
    end
    if Has(text, "mana") and Has(text, "5 sek", "5 sec") then return Put("mp5", number) end
    local healing = Has(text, "heilung", "healing")
    local damage = Has(text, "schaden", "damage")
    if healing and damage then Put("sp", number); return Put("heal", number) end
    if healing then return Put("heal", number) end
    if damage and Has(text, "zauber", "spell") then
        for _, school in ipairs(SCHOOLS) do
            if Has(text, school[1], school[2]) then return Put(school.key, number) end
        end
        return Put("sp", number)
    end
    if Has(text, "verteidigung", "defense") then return Put("def", number) end
end

-- Tooltip lines: read equip effects, detect red text (not wearable)
local function ReadTooltip(link, stats)
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink(link)
    if not data or not data.lines then return true end
    local equip = (ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:"):lower()
    local usable = true
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if Readable(text) and text and text ~= "" then
            local color = line.leftColor
            if color and color.r and color.r > 0.99 and color.g < 0.2 and color.b < 0.2 then usable = false end
            local lower = text:lower()
            if lower:sub(1, #equip) == equip then ParseEquipLine(lower:sub(#equip + 1), stats) end
        end
    end
    return usable
end

-- Item stats (nil = data not loaded yet); second return value: wearable?
local itemCache, itemCount = {}, 0
local ITEM_MAX = 1000 -- auction house browsing adds hundreds of links: start over at the cap
local function ItemStats(link)
    local cached = itemCache[link]
    if cached then return cached.stats, cached.usable end
    -- Only score once the item is loaded (otherwise tooltip lines are missing and we'd cache garbage)
    local itemID = C_Item.GetItemInfoInstant(link)
    if itemID and not C_Item.IsItemDataCachedByID(itemID) then
        C_Item.RequestLoadItemDataByID(itemID)
        return
    end
    local api = C_Item.GetItemStats(link)
    if not api then return end
    local stats = {}
    for key, value in pairs(api) do
        if Readable(key) and Readable(value) and type(value) == "number" then
            if API_STATS[key] then stats[API_STATS[key]] = (stats[API_STATS[key]] or 0) + value
            elseif API_BOTH[key] then stats.sp = (stats.sp or 0) + value; stats.heal = (stats.heal or 0) + value
            elseif API_PERCENT[key] then
                local stat = API_PERCENT[key]
                stats[stat] = (stats[stat] or 0) + value * RATING_PER_PERCENT[stat]
            elseif key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT" then stats.dps = value end
        end
    end
    local usable = ReadTooltip(link, stats)
    itemCount = itemCount + 1
    if itemCount > ITEM_MAX then
        wipe(itemCache)
        itemCount = 1
    end
    itemCache[link] = { stats = stats, usable = usable }
    return stats, usable
end

-- Wearable? (no red tooltip lines; nil = not loaded yet) - used for "fills empty slot"
function ns.ItemUsable(link)
    local _, usable = ItemStats(link)
    return usable
end

-- Talent tree with the most points (else the class default)
local function ActiveTree(class)
    local best, bestPoints = nil, 0
    if GetNumTalentTabs and GetTalentTabInfo then
        for tab = 1, GetNumTalentTabs() do
            local r = { pcall(GetTalentTabInfo, tab) }
            if r[1] then
                -- Classic: name, icon, points ...; newer clients: id, name, description, icon, points ...
                local points = type(r[2]) == "string" and r[4] or r[6]
                if type(points) == "number" and points > bestPoints then best, bestPoints = tab, points end
            end
        end
    end
    return best or DEFAULT_TREE[class] or 1
end

local weights
local function Weights()
    if weights then return weights end
    local _, class = UnitClass("player")
    local byTree = ns.FOREVER_WEIGHTS and ns.FOREVER_WEIGHTS[class]
    if not byTree then return end
    weights = byTree[ActiveTree(class)] or byTree[1]
    return weights
end

local function Score(link, slotKind)
    if not link then return 0 end
    local stats = ItemStats(link)
    if not stats then return nil end
    local w = Weights()
    if not w then return 0 end
    local score = 0
    for key, value in pairs(stats) do
        if key ~= "dps" and w[key] then score = score + value * w[key] end
    end
    if stats.dps then
        -- Weapon DPS: own weight, else Classic rule of thumb 1 DPS ~ 14 attack power
        local dpsWeight
        if slotKind == "ranged" then dpsWeight = w.rangeddps or (w.rap or w.ap or 0) * 14
        elseif slotKind == "off" then dpsWeight = w.ohdps or (w.mhdps or (w.ap or 0) * 14) * 0.5
        else dpsWeight = w.mhdps or (w.ap or 0) * 14 end
        score = score + stats.dps * dpsWeight
    end
    return score
end

local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local OFF_HAND = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

local function Equipped(slot) return GetInventoryItemLink("player", slot) end
local function EquipLoc(link) return link and select(4, C_Item.GetItemInfoInstant(link)) end

-- Score of what the new item would replace (nil = not comparable)
local function Replaced(equipLoc, link)
    local slots = SLOTS[equipLoc]
    if slots then
        local worst
        for _, slot in ipairs(slots) do
            local current = Equipped(slot)
            if current == link then return end
            local score = Score(current, RANGED[equipLoc] and "ranged" or nil)
            if not score then return end
            worst = worst and math.min(worst, score) or score
        end
        return worst
    end
    local main, off = Equipped(16), Equipped(17)
    if link == main or link == off then return end
    local mainScore, offScore = Score(main, "main"), Score(off, "off")
    if not (mainScore and offScore) then return end
    if equipLoc == "INVTYPE_2HWEAPON" then return mainScore + offScore end
    if OFF_HAND[equipLoc] then
        if EquipLoc(main) == "INVTYPE_2HWEAPON" then return end
        return offScore
    end
    if equipLoc == "INVTYPE_WEAPONMAINHAND" then return mainScore end
    if equipLoc == "INVTYPE_WEAPON" then
        if off and EquipLoc(main) ~= "INVTYPE_2HWEAPON" and CanDualWield and CanDualWield() and not OFF_HAND[EquipLoc(off)] then
            return math.min(mainScore, offScore)
        end
        return mainScore
    end
end

-- Score of all equipped gear (baseline for the percentages)
local function GearScore()
    local total = 0
    for slot = 1, 18 do
        local kind = slot == 18 and "ranged" or slot == 17 and "off" or slot == 16 and "main" or nil
        total = total + (Score(Equipped(slot), kind) or 0)
    end
    return total
end

function ns.ForeverUpgradePercent(link)
    if not Weights() then return end
    local equipLoc = EquipLoc(link)
    if not equipLoc or equipLoc == "" then return end
    if not (SLOTS[equipLoc] or OFF_HAND[equipLoc] or equipLoc == "INVTYPE_2HWEAPON"
        or equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND") then return end
    local _, usable = ItemStats(link)
    if usable == false then return end
    local kind = RANGED[equipLoc] and "ranged" or OFF_HAND[equipLoc] and "off" or "main"
    local score = Score(link, kind)
    if not score or score <= 0 then return end
    local total = math.max(GearScore(), score)
    -- One-hander while dual wielding: score it for the hand it would go into (off hand DPS counts
    -- less), best of both hands
    local main, off = Equipped(16), Equipped(17)
    if equipLoc == "INVTYPE_WEAPON" and off and link ~= main and link ~= off and EquipLoc(main) ~= "INVTYPE_2HWEAPON"
        and CanDualWield and CanDualWield() and not OFF_HAND[EquipLoc(off)] then
        local mainScore, offScore, asOff = Score(main, "main"), Score(off, "off"), Score(link, "off")
        if not (mainScore and offScore and asOff) then return end
        return math.max(score - mainScore, asOff - offScore) / total * 100
    end
    local replaced = Replaced(equipLoc, link)
    if not replaced then return end
    return (score - replaced) / total * 100
end

-- Gear, level or talents changed -> recompute
local function Reset()
    wipe(itemCache)
    weights = nil
    if ns.RefreshBags then ns.RefreshBags() end
end
ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED",
        "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }) do
        pcall(ns.On, ns, event, function() C_Timer.After(0.3, Reset) end)
    end
end)
