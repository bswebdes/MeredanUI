-- Attack with abilities (Comfort: attackWithAbilities): pressing a harmful spell on a mUI action
-- button also starts auto attack on a hostile target, like Retail. Out of mana/energy the spell
-- fails, but the auto attack still runs.
--
-- How: a secure wrapper on each button's OnClick (restricted code, works in combat). For a harmful
-- spell in the button's action slot it redirects the click to a macro
--     /startattack [@target,harm,nodead]
--     /cast <spell name(rank)>
-- Addons can't read mana at click time, so this happens on every press, not only when out of mana.
-- Spell names come from a list built out of combat (restricted code can't look names up); a spell
-- missing from it simply keeps the normal button behaviour. Crowd control and utility spells (Sap,
-- Polymorph, Hunter's Mark ...) and the auto attack toggles themselves are never redirected.
-- Hunters: autoRangedCombat makes /startattack switch between melee and Auto Shot (Blizzard's own
-- gamepad bar relies on the same CVar).
local _, ns = ...

local LAB = LibStub("LibActionButton-1.0")
-- the redirect uses a virtual mouse button "muiattack" (attributes *type-muiattack / *macrotext-muiattack)
local MAX_SLOT = 200

-- Rank 1 IDs; matched by name, so every rank counts
local NEVER = {
    6603, 75, 5019,                 -- Attack, Auto Shot, Shoot (wand): toggles
    6770, 1776, 2094, 921, 1725,    -- Sap, Gouge, Blind, Pick Pocket, Distract
    118, 28271, 28272, 2855,        -- Polymorph (+ turtle, pig), Detect Magic
    19503, 19386, 1130, 1513,       -- Scatter Shot, Wyvern Sting, Hunter's Mark, Scare Beast
    5782, 710, 1098,                -- Fear, Banish, Enslave Demon
    2637, 339, 2908,                -- Hibernate, Entangling Roots, Soothe Animal
    9484, 605, 453, 2096,           -- Shackle Undead, Mind Control, Mind Soothe, Mind Vision
    2878, 20066,                    -- Turn Undead, Repentance
    5246,                           -- Intimidating Shout
}

local controller
local wrapped = setmetatable({}, { __mode = "k" })

local function Enabled() return ns.db and ns.db.attackWithAbilities ~= false end

-- restricted pre-click body: decide per press whether to redirect
local PRE = [[
    if button ~= "LeftButton" or not owner:GetAttribute("enabled") then return end
    if IsModifiedClick("PICKUPACTION") then return end
    if self:GetAttribute("type") ~= "action" then return end
    local kind, id = GetActionInfo(self:GetAttribute("action"))
    if kind ~= "spell" or not id then return end
    local name = string.match(owner:GetAttribute("spells") or "", ";" .. id .. "=([^;]+);")
    if not name or not PlayerCanAttack("target") then return end
    local cast = owner:GetAttribute("mouseover") and "/cast [@mouseover,harm,nodead][] " or "/cast "
    self:SetAttribute("*type-muiattack", "macro")
    self:SetAttribute("*macrotext-muiattack", "/startattack [@target,harm,nodead]\n" .. cast .. name)
    return "muiattack"
]]

local function ExcludedNames()
    local names = {}
    for _, id in ipairs(NEVER) do
        local name = C_Spell.GetSpellName(id)
        if name then names[name] = true end
    end
    return names
end

local function LowRank(id)
    if not (C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.IsSpellBookItemLowRank) then return false end
    local slot, bank = C_SpellBook.FindSpellBookSlotForSpell(id, false, false, false, false)
    return slot and C_SpellBook.IsSpellBookItemLowRank(slot, bank) or false
end

-- "Arcane Shot(Rank 3)" for ranked spells, so a lower rank on the bar stays that rank. A plain
-- name casts the highest rank: fine for the top rank, so a low rank without its rank text (spell
-- text not loaded yet) is skipped until SPELL_TEXT_UPDATE rebuilds the list.
local function CastName(id)
    local name = C_Spell.GetSpellName(id)
    if not name or name:find("[;=]") then return nil end
    local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
    if type(sub) == "string" and sub:find("%d") then return ("%s(%s)"):format(name, sub) end
    if LowRank(id) then return nil end
    return name
end

local function BuildList()
    if InCombatLockdown() then return ns.AfterCombat(BuildList) end
    if not controller then return end
    local excluded = ExcludedNames()
    local parts, seen = { ";" }, {}
    for slot = 1, MAX_SLOT do
        if C_ActionBar.HasAction(slot) then
            local kind, id = GetActionInfo(slot)
            if kind == "spell" and id and not seen[id] then
                seen[id] = true
                local name = C_Spell.GetSpellName(id)
                if name and not excluded[name] and C_Spell.IsSpellHarmful(id) then
                    local cast = CastName(id)
                    if cast then parts[#parts + 1] = id .. "=" .. cast .. ";" end
                end
            end
        end
    end
    controller:SetAttribute("spells", table.concat(parts))
end

local function WrapButtons()
    if InCombatLockdown() then return ns.AfterCombat(WrapButtons) end
    for button in pairs(LAB:GetAllButtons()) do
        local name = button:GetName()
        if not wrapped[button] and name and name:find("^MeredanUI") then
            controller:WrapScript(button, "OnClick", PRE)
            wrapped[button] = true
        end
    end
end

function ns.ApplyAttackWithAbilities()
    if not controller then return end
    if InCombatLockdown() then return ns.AfterCombat(ns.ApplyAttackWithAbilities) end
    local on = Enabled()
    controller:SetAttribute("enabled", on or nil)
    controller:SetAttribute("mouseover", (ns.db and ns.db.mouseoverHeal) or nil)
    if on and select(2, UnitClass("player")) == "HUNTER" then
        ns.LookCVar("autoRangedCombat", "1") -- melee up close, Auto Shot at range
    end
    if on then
        WrapButtons()
        BuildList()
    end
end

local pending
local function BuildSoon()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        if Enabled() then BuildList() end
    end)
end

ns:On("PLAYER_LOGIN", function()
    controller = CreateFrame("Frame", "MeredanUIAttackController", UIParent, "SecureHandlerBaseTemplate")
    -- after the bars are built (ActionBars.lua, also PLAYER_LOGIN)
    C_Timer.After(0, ns.ApplyAttackWithAbilities)
    -- mouseover casting switched: the macro follows it
    if ns.ApplyMouseoverCast then hooksecurefunc(ns, "ApplyMouseoverCast", ns.ApplyAttackWithAbilities) end
end)
ns:On("ACTIONBAR_SLOT_CHANGED", BuildSoon)
ns:On("SPELLS_CHANGED", BuildSoon)
ns:On("LEARNED_SPELL_IN_SKILL_LINE", BuildSoon)
ns:On("PLAYER_ENTERING_WORLD", BuildSoon)
ns:On("SPELL_TEXT_UPDATE", BuildSoon)
