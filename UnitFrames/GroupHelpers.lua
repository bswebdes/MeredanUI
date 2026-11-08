-- Small group helpers:
--   - Auto-accept invites from friends (incl. Battle.net) and guild members (default off).
--   - Role poll: auto-confirm your current spec role.
--   - Ready check: toast when food, flask or augment rune is missing.
local _, ns = ...
local L = ns.L

-- Invites -------------------------------------------------------------------------------------

local function Trusted(guid)
    if not guid or issecretvalue(guid) then return false end
    return C_FriendList.IsFriend(guid) or C_BattleNet.GetGameAccountInfoByGUID(guid) ~= nil
        or (IsInGuild() and IsGuildMember(guid))
end

ns:On("PARTY_INVITE_REQUEST", function(_, name, _, _, _, _, _, guid, questSessionActive)
    if ns.db.autoInvite ~= true or questSessionActive or not Trusted(guid) then return end
    AcceptGroup()
    C_Timer.After(0, function() StaticPopup_Hide("PARTY_INVITE") end)
    if not issecretvalue(name) and name then ns.Print(L["Accepted group invite from %s."]:format(name)) end
end)

-- Role poll ----------------------------------------------------------------------------------

ns:On("ROLE_POLL_BEGIN", function()
    if ns.db.autoRole == false then return end
    local spec = C_SpecializationInfo.GetSpecialization()
    local role = spec and GetSpecializationRoleEnum(spec)
    if not role then return end
    local canTank, canHeal, canDamage = UnitGetAvailableRoles("player")
    local allowed = (role == Enum.LFGRole.Tank and canTank) or (role == Enum.LFGRole.Healer and canHeal)
        or (role == Enum.LFGRole.Damage and canDamage)
    if not allowed then return end
    UnitSetRoleEnum("player", role)
    -- Blizzard shows its popup in the same event - close it afterwards
    C_Timer.After(0, function()
        if RolePollPopup and RolePollPopup:IsShown() then StaticPopupSpecial_Hide(RolePollPopup) end
    end)
end)

-- Ready check ----------------------------------------------------------------------------------

local FOOD_ICON = 136000 -- "Well Fed" icon, used by almost all food buffs
local FLASK_NAMES = { "Flask", "Phial", "Fläschchen", "Phiole" }
local RUNE_NAMES = { "Augment", "Augmentation" }

local function HasAny(name, list)
    for _, word in ipairs(list) do
        if name:find(word, 1, true) then return true end
    end
end

-- Only readable auras count (own buffs are readable out of combat)
local function MissingConsumables()
    local food, flask, rune = false, false, false
    local wellFed = C_Spell.GetSpellName(19705)
    for i = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end
        local name, icon = aura.name, aura.icon
        if not issecretvalue(name) and not issecretvalue(icon) and name then
            if icon == FOOD_ICON or name == wellFed then food = true end
            if HasAny(name, FLASK_NAMES) then flask = true end
            if HasAny(name, RUNE_NAMES) then rune = true end
        end
    end
    local missing = {}
    if not food then missing[#missing + 1] = L["Food"] end
    if not flask then missing[#missing + 1] = L["Flask"] end
    if not rune then missing[#missing + 1] = L["Augment rune"] end
    return missing
end

ns:On("READY_CHECK", function()
    if ns.db.readyCheckReminder == false or InCombatLockdown() then return end
    local missing = MissingConsumables()
    if #missing == 0 then return end
    local text = L["Missing: %s"]:format(table.concat(missing, ", "))
    local toast = { title = L["Ready check"], text = text, icon = 136000, color = { 0.95, 0.3, 0.25 } }
    if not ns.AddToast(toast) then ns.Print(text) end
end)
