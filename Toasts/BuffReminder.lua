-- Buff reminder (Forever, Comfort: buffReminder) via toasts:
--   - own class buffs missing (Arcane Intellect, Inner Fire, Mark of the Wild, armor, aspect ...),
--     or cast by you with an outdated rank
--   - temporary weapon enchant (oil, sharpening stone, poison, shaman imbue) ran out
-- Never in combat, dead, on a flight, while resting (cities, inns); each reminder at most every
-- 5 minutes. The ready check reminder (UnitFrames/GroupHelpers.lua) covers food and elixirs.
local _, ns = ...
if not ns.IS_FOREVER then return end
local L = ns.L

local COOLDOWN = 300
local CHECK_EVERY = 20

-- Per class: groups of spells; a group is satisfied by any buff with one of these names.
-- IDs are rank 1 (the name is the same for every rank).
local CLASS_BUFFS = {
    MAGE = { { 1459 }, { 168, 7302, 6117 } },                    -- Arcane Intellect; Frost/Ice/Mage Armor
    PRIEST = { { 1243 }, { 588 } },                              -- Fortitude; Inner Fire
    DRUID = { { 1126 } },                                        -- Mark of the Wild
    WARLOCK = { { 687, 706 } },                                  -- Demon Skin/Armor
    SHAMAN = { { 324 } },                                        -- Lightning Shield
    PALADIN = { { 19740, 19742, 20217, 1038, 19977, 20911 } },   -- any Blessing
    HUNTER = { { 13165, 5118, 13163, 20043, 13159 } },           -- any Aspect
}

local lastShown = {}  -- key -> time
local hadTempEnchant = {} -- weapon slot -> true while a temporary enchant was on it

local function Enabled() return ns.db and ns.db.buffReminder ~= false end

local function Quiet()
    return InCombatLockdown() or UnitIsDeadOrGhost("player") or UnitOnTaxi("player") or IsResting()
        or UnitInVehicle("player")
end

local function Due(key)
    local last = lastShown[key]
    if last and GetTime() - last < COOLDOWN then return false end
    lastShown[key] = GetTime()
    return true
end

-- Own helpful auras by name (only readable ones; out of combat own buffs are readable)
local function PlayerBuffs()
    local byName = {}
    for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        local name, spellID, source = aura.name, aura.spellId, aura.sourceUnit
        if not issecretvalue(name) and name and not issecretvalue(spellID) then
            local mine = not issecretvalue(source) and source == "player"
            byName[name] = { spellID = spellID, mine = mine }
        end
    end
    return byName
end

local function LowRank(spellID)
    if not (spellID and C_SpellBook.FindSpellBookSlotForSpell) then return false end
    local slot, bank = C_SpellBook.FindSpellBookSlotForSpell(spellID, false, false, false, false)
    return slot and C_SpellBook.IsSpellBookItemLowRank(slot, bank) or false
end

local function CheckClassBuffs()
    local _, class = UnitClass("player")
    local groups = CLASS_BUFFS[class]
    if not groups then return end
    local buffs = PlayerBuffs()
    local missing, icon = {}, nil
    for _, group in ipairs(groups) do
        local known, found, foundOld, firstName, firstID = false, false, false, nil, nil
        for _, id in ipairs(group) do
            if IsPlayerSpell(id) then
                local name = C_Spell.GetSpellName(id)
                if name then
                    known = true
                    firstName, firstID = firstName or name, firstID or id
                    local buff = buffs[name]
                    if buff then
                        found = true
                        if buff.mine and LowRank(buff.spellID) then foundOld = name end
                    end
                end
            end
        end
        if known and not found then
            missing[#missing + 1] = firstName
            icon = icon or C_Spell.GetSpellTexture(firstID)
        elseif foundOld then
            missing[#missing + 1] = L["%s (old rank)"]:format(foundOld)
            icon = icon or C_Spell.GetSpellTexture(firstID)
        end
    end
    if #missing == 0 or not Due("buffs:" .. table.concat(missing, ",")) then return end
    local toast = { title = L["Buff missing"], text = table.concat(missing, ", "), icon = icon or 136243,
        color = { 1, 0.82, 0 } }
    if not ns.AddToast(toast) then ns.Print(L["Buff missing"] .. ": " .. toast.text) end
end

local TEMP = { [Enum.ItemEnchantType.Temporary] = true, [Enum.ItemEnchantType.Imbue] = true }

local function CheckWeapons()
    for _, slot in ipairs({ Enum.WeaponSlot.MainHand, Enum.WeaponSlot.OffHand }) do
        local has = false
        for _, enchant in ipairs(C_Item.GetWeaponEnchantInfo(slot) or {}) do
            if enchant.hasEnchant and TEMP[enchant.enchantType] then has = true end
        end
        if hadTempEnchant[slot] and not has and Due("weapon:" .. slot) then
            local invSlot = slot == Enum.WeaponSlot.MainHand and INVSLOT_MAINHAND or INVSLOT_OFFHAND
            local toast = { title = L["Weapon enchant expired"],
                text = slot == Enum.WeaponSlot.MainHand and L["Main hand"] or L["Off hand"],
                icon = GetInventoryItemTexture("player", invSlot) or 135225, color = { 1, 0.6, 0.1 } }
            if not ns.AddToast(toast) then ns.Print(L["Weapon enchant expired"] .. ": " .. toast.text) end
        end
        hadTempEnchant[slot] = has or nil
    end
end

local function Check()
    if not Enabled() or Quiet() then return end
    CheckClassBuffs()
    CheckWeapons()
end

local function CheckSoon(delay) C_Timer.After(delay, Check) end

ns:On("PLAYER_ENTERING_WORLD", function() CheckSoon(8) end)
ns:On("PLAYER_REGEN_ENABLED", function() CheckSoon(3) end)
ns:On("ZONE_CHANGED_NEW_AREA", function() CheckSoon(5) end)
ns:On("PLAYER_LOGIN", function()
    -- weapon enchants expire silently: a slow poll out of combat (cheap: two small API calls)
    C_Timer.NewTicker(CHECK_EVERY, function()
        if Enabled() and not InCombatLockdown() then
            if Quiet() then return end
            CheckWeapons()
            CheckClassBuffs() -- buffs run out while questing; the cooldown keeps it rare
        end
    end)
end)
