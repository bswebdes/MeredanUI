-- Kleine Gruppen-Helfer:
--   • Einladungen von Freunden (auch Battle.net) und Gildenmitgliedern annehmen – Standard AUS
--     (Benny 2026-10-25), Einstellungen > Gruppe & Schlachtzug.
--   • Rollenabfrage des Leiters: deine aktuelle Spec-Rolle automatisch bestätigen.
--   • Bereitschaftscheck: Toast, wenn Essen, Fläschchen oder Augmentrune fehlen
--     (Einstellungen > Dungeons & Schlachtzüge).
local _, ns = ...
local L = ns.L

-- Einladungen ---------------------------------------------------------------------------------

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

-- Rollenabfrage -------------------------------------------------------------------------------

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
    -- Blizzard zeigt sein Fenster im selben Ereignis – danach schließen
    C_Timer.After(0, function()
        if RolePollPopup and RolePollPopup:IsShown() then StaticPopupSpecial_Hide(RolePollPopup) end
    end)
end)

-- Bereitschaftscheck --------------------------------------------------------------------------

local FOOD_ICON = 136000 -- „Satt“-Symbol, haben fast alle Essens-Buffs
local FLASK_NAMES = { "Flask", "Phial", "Fläschchen", "Phiole" }
local RUNE_NAMES = { "Augment", "Augmentation" }

local function HasAny(name, list)
    for _, word in ipairs(list) do
        if name:find(word, 1, true) then return true end
    end
end

-- Was fehlt? Nur lesbare Auren zählen (außerhalb des Kampfes sind eigene Buffs lesbar)
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
