-- Stats for the character window (player and pet): same groups and entries as Blizzard's
-- PAPERDOLL_STATCATEGORIES, but computed ourselves. Many values can be secret
-- (SecretWhenUnitStatsRestricted) - then we show "-" instead of computing.
--
-- ns.Char.StatRows(unit) -> { { header = "General" }, { label, value, color, tip = function() ... } ... }
-- ns.Char.Resistances(unit) -> { { name, value, color, icon } x 5 }
local _, ns = ...
local L = ns.L
local Char = ns.Char

local GREEN = { 0.43, 0.82, 0.47 }
local RED = { 0.9, 0.35, 0.35 }

local function Secret(...)
    for i = 1, select("#", ...) do
        if issecretvalue(select(i, ...)) then return true end
    end
    return false
end

local function Pct(v) return (("%.1f %%"):format(v):gsub("%.", L["DECIMAL_SEPARATOR"], 1)) end
local function Num(v) return BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v) end

local function Tip(title, ...)
    local lines = { ... }
    return function()
        GameTooltip:SetText(title, 1, 1, 1)
        for _, line in ipairs(lines) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
end

local function BuffColor(pos, neg)
    if neg and neg < 0 then return RED end
    if pos and pos > 0 then return GREEN end
end

-- Groups ---------------------------------------------------------------------------------------

local function General(rows, unit)
    local health = UnitHealthMax(unit)
    rows[#rows + 1] = { label = HEALTH, value = Secret(health) and "–" or Num(health) }
    -- Item level: average of equipped gear
    if unit == "player" then
        local best, equipped = GetAverageItemLevel()
        if equipped and not Secret(equipped, best) and equipped > 0 then
            rows[#rows + 1] = { label = L["Item level"], value = tostring(math.floor(equipped)),
                tip = best and best > equipped + 0.5 and Tip(L["Item level"] .. " " .. math.floor(equipped),
                    L["With your best items from your bags: %d"]:format(math.floor(best))) or nil }
        end
    end
    local powerType, token = UnitPowerType(unit)
    if unit == "player" or (unit == "pet" and select(2, UnitClass("player")) == "WARLOCK") then
        local max = UnitPowerMax(unit, powerType)
        if not Secret(max) and max > 0 then
            rows[#rows + 1] = { label = _G[token] or MANA, value = Num(max) }
        end
    end
    local _, run, _, swim = GetUnitSpeed(unit)
    if not Secret(run, swim) and run then
        local speed = (unit == "player" and IsSwimming() and swim or run) / 7 * 100
        rows[#rows + 1] = { label = Char.G("STAT_MOVEMENT_SPEED", "Speed"), value = ("%d %%"):format(speed + 0.5) }
    end
end

local function Primary(rows, unit)
    for i = 1, 5 do
        local _, effective, pos, neg = UnitStat(unit, i)
        local name = _G["SPELL_STAT" .. i .. "_NAME"] or ("Stat " .. i)
        if Secret(effective, pos, neg) then
            rows[#rows + 1] = { label = name, value = "–" }
        else
            local base = effective - pos - neg
            rows[#rows + 1] = {
                label = name, value = Num(effective), color = BuffColor(pos, neg),
                tip = (pos ~= 0 or neg ~= 0) and Tip(name .. " " .. effective,
                    ("%s %d  %s  %s"):format(L["Base"], base, pos > 0 and ("|cff6ed278+" .. pos .. "|r") or "",
                        neg < 0 and ("|cffe65959" .. neg .. "|r") or "")) or nil,
            }
        end
    end
end

local function DamageText(low, high)
    return ("%d–%d"):format(math.max(math.floor(low), 1), math.ceil(high))
end

local function Weapons(rows, unit)
    local minMain, maxMain, minOff, maxOff, pos, neg = UnitDamage(unit)
    if not Secret(minMain, maxMain) and minMain then
        local speed, offSpeed = UnitAttackSpeed(unit)
        local label = unit == "pet" and DAMAGE or Char.G("INVTYPE_WEAPONMAINHAND", "Main hand")
        local tip
        if not Secret(speed) and speed and speed > 0 then
            tip = Tip(label, ("%s %.2f"):format(Char.G("WEAPON_SPEED", "Speed"), speed),
                ("%s %.1f"):format(L["DPS"], (minMain + maxMain) / 2 / speed))
        end
        rows[#rows + 1] = { label = label, value = DamageText(minMain, maxMain), color = not Secret(pos, neg) and BuffColor(pos, neg) or nil, tip = tip }
        if unit == "player" and IsDualWielding() and not Secret(minOff, maxOff) and minOff and maxOff > 0 then
            rows[#rows + 1] = { label = Char.G("INVTYPE_WEAPONOFFHAND", "Off hand"), value = DamageText(minOff, maxOff),
                tip = (not Secret(offSpeed) and offSpeed) and Tip(Char.G("INVTYPE_WEAPONOFFHAND", "Off hand"),
                    ("%s %.2f"):format(Char.G("WEAPON_SPEED", "Speed"), offSpeed)) or nil }
        end
    end
    if unit == "player" and IsRangedWeapon and IsRangedWeapon() then
        local speed, low, high = UnitRangedDamage(unit)
        if not Secret(speed, low, high) and high and high > 0 then
            rows[#rows + 1] = { label = Char.G("INVTYPE_RANGED", "Ranged"), value = DamageText(low, high),
                tip = speed > 0 and Tip(Char.G("INVTYPE_RANGED", "Ranged"), ("%s %.2f"):format(Char.G("WEAPON_SPEED", "Speed"), speed),
                    ("%s %.1f"):format(L["DPS"], (low + high) / 2 / speed)) or nil }
        end
    end
    local ap, apPos, apNeg = UnitAttackPower(unit)
    if not Secret(ap, apPos, apNeg) and ap then
        local total = ap + apPos + apNeg
        if total > 0 then
            rows[#rows + 1] = { label = Char.G("STAT_ATTACK_POWER", "Attack power"), value = Num(total), color = BuffColor(apPos, apNeg),
                tip = Tip(Char.G("STAT_ATTACK_POWER", "Attack power") .. " " .. total, L["Adds %.1f damage per second."]:format(total / 14)) }
        end
    end
    if unit == "player" and IsRangedWeapon and IsRangedWeapon() then
        local rap, rPos, rNeg = UnitRangedAttackPower(unit)
        if not Secret(rap, rPos, rNeg) and rap then
            local total = rap + rPos + rNeg
            if total > 0 then
                rows[#rows + 1] = { label = Char.G("RANGED_ATTACK_POWER", "Ranged attack power"), value = Num(total), color = BuffColor(rPos, rNeg),
                    tip = Tip(Char.G("RANGED_ATTACK_POWER", "Ranged attack power") .. " " .. total, L["Adds %.1f damage per second."]:format(total / 14)) }
            end
        end
    end
end

-- Highest readable value of several queries (like Blizzard: melee, ranged, spell ...)
local function MaxOf(...)
    local best
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v and not issecretvalue(v) and (not best or v > best) then best = v end
    end
    return best
end

local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
end

-- Sum of readable values; nil as soon as one is secret (some are secret in combat)
local function Sum(...)
    local total = 0
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil and issecretvalue(v) then return nil end
        total = total + (v or 0)
    end
    return total
end

local function Modifiers(rows, unit)
    local function Add(label, value, tip)
        if value and not issecretvalue(value) and value > 0 then rows[#rows + 1] = { label = label, value = Pct(value), tip = tip } end
    end
    if unit == "player" then
        local hit = MaxOf(Sum(SafeCall(GetCombatRatingBonus, CR_HIT_MELEE), SafeCall(GetHitModifier)),
            Sum(SafeCall(GetCombatRatingBonus, CR_HIT_RANGED), SafeCall(GetRangedHitModifier)),
            Sum(SafeCall(GetCombatRatingBonus, CR_HIT_SPELL), SafeCall(GetSpellHitModifier)))
        Add(Char.G("STAT_HIT_CHANCE", "Hit"), hit)
        local spellCrit
        for school = 2, 7 do spellCrit = MaxOf(spellCrit, SafeCall(GetSpellCritChance, school)) end
        Add(Char.G("STAT_CRITICAL_STRIKE", "Critical strike"), MaxOf(SafeCall(GetCritChance), SafeCall(GetRangedCritChance), spellCrit))
        Add(Char.G("STAT_HASTE", "Haste"), MaxOf(SafeCall(GetMeleeHaste), SafeCall(GetRangedHaste), SafeCall(UnitSpellHaste, unit)))
        local expertise = SafeCall(GetExpertise)
        if expertise and not issecretvalue(expertise) and expertise > 0 then
            rows[#rows + 1] = { label = Char.G("STAT_EXPERTISE", "Expertise"), value = tostring(expertise) }
        end
        Add(Char.G("STAT_ARMOR_PENETRATION", "Armor penetration"), SafeCall(GetArmorPenetration))
        local spellPower
        for school = 2, 7 do
            local v = SafeCall(GetSpellBonusDamage, school)
            if v and not issecretvalue(v) then spellPower = spellPower and math.min(spellPower, v) or v end
        end
        if spellPower and spellPower > 0 then rows[#rows + 1] = { label = Char.G("STAT_SPELLPOWER", "Spell power"), value = Num(spellPower) } end
        local healing = SafeCall(GetSpellBonusHealing)
        if healing and not issecretvalue(healing) and healing > 0 then
            rows[#rows + 1] = { label = Char.G("STAT_SPELLHEALING", "Healing"), value = Num(healing) }
        end
        local pen = SafeCall(GetSpellPenetration)
        if pen and not issecretvalue(pen) and pen > 0 then
            rows[#rows + 1] = { label = Char.G("STAT_SPELL_PENETRATION", "Spell penetration"), value = Num(pen) }
        end
    else
        Add(Char.G("STAT_CRITICAL_STRIKE", "Critical strike"), SafeCall(GetPetCritChance))
    end
end

local function Defense(rows, unit)
    if unit == "player" then
        local base, mod = UnitDefenseSkill(unit)
        if not Secret(base, mod) and base then
            rows[#rows + 1] = { label = Char.G("DEFENSE", "Defense"), value = ("%d/%d"):format(base + mod, UnitLevel(unit) * 5),
                color = BuffColor(mod, mod) }
        end
        local function Add(label, value)
            if value and not issecretvalue(value) and value > 0 then rows[#rows + 1] = { label = label, value = Pct(value) } end
        end
        Add(Char.G("STAT_DODGE", "Dodge"), SafeCall(GetDodgeChance))
        if C_PaperDollInfo.OffhandHasShield and C_PaperDollInfo.OffhandHasShield() then Add(Char.G("STAT_BLOCK", "Block"), SafeCall(GetBlockChance)) end
        Add(Char.G("STAT_PARRY", "Parry"), SafeCall(GetParryChance))
    elseif unit == "pet" then
        local dodge = SafeCall(GetPetDodgeChance)
        if dodge and not issecretvalue(dodge) and dodge > 0 then rows[#rows + 1] = { label = Char.G("STAT_DODGE", "Dodge"), value = Pct(dodge) } end
    end
    local base, effective = UnitArmor(unit)
    if not Secret(base, effective) and effective then
        rows[#rows + 1] = { label = Char.G("STAT_ARMOR", "Armor"), value = Num(effective), color = effective > base and GREEN or nil }
    end
end

function Char.StatRows(unit)
    local rows = {}
    local function Header(text) rows[#rows + 1] = { header = text } end
    if unit == "pet" then
        Header(Char.G("STAT_CATEGORY_GENERAL", "General"))
        General(rows, unit)
        Header(Char.G("STAT_CATEGORY_COMBAT", "Combat"))
        Defense(rows, unit) -- armor (and dodge) first, like Blizzard
        Weapons(rows, unit)
        Modifiers(rows, unit)
        return rows
    end
    Header(Char.G("STAT_CATEGORY_GENERAL", "General"))
    General(rows, unit)
    Header(Char.G("STAT_CATEGORY_PRIMARY_ATTRIBUTES", "Attributes"))
    Primary(rows, unit)
    Header(Char.G("STAT_CATEGORY_WEAPONS", "Weapons"))
    Weapons(rows, unit)
    local before = #rows
    Header(Char.G("STAT_CATEGORY_MODIFIERS", "Modifiers"))
    Modifiers(rows, unit)
    if #rows == before + 1 then rows[#rows] = nil end -- drop empty group
    Header(Char.G("STAT_CATEGORY_DEFENSE", "Defense"))
    Defense(rows, unit)
    return rows
end

-- Resistances via Enum.Damageclass: { enum name, fallback name, color };
-- DAMAGE_SCHOOL<n> = enum value + 1 (3 Fire ... 7 Arcane)
local RESISTANCES = {
    { "Arcane", "Arcane", { 0.79, 0.72, 1 } }, { "Fire", "Fire", { 0.88, 0.34, 0.18 } },
    { "Frost", "Frost", { 0.37, 0.66, 0.91 } }, { "Nature", "Nature", { 0.37, 0.75, 0.29 } },
    { "Shadow", "Shadow", { 0.6, 0.35, 0.78 } },
}

function Char.Resistances(unit)
    local list = {}
    for _, def in ipairs(RESISTANCES) do
        local class = Enum.Damageclass and Enum.Damageclass[def[1]]
        local value
        if class then
            local _, effective = UnitResistance(unit, class)
            value = effective
        end
        local name = (class and _G["DAMAGE_SCHOOL" .. (class + 1)]) or L[def[2]]
        list[#list + 1] = { name = name, value = (value == nil or issecretvalue(value)) and "–" or tostring(value), color = def[3] }
    end
    return list
end
