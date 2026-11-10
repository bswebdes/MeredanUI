-- Small comfort helpers (modelled on Leatrix Plus):
--   - Camera: maximum zoom-out distance, for everyone (only raised, never lowered)
--   - autoSummon (Comfort): accept summons out of combat after a short grace time (cancel = decline)
--   - autoResurrect (Comfort): accept resurrections unless the caster is in combat
--   - declineDuels (Comfort): decline duels, except from friends and guild members
--   - skipCinematics (Comfort): skip movies and in-game cinematics you have seen before
--     (remembered account-wide in MeredanUIDB.seenCinematics)
local _, ns = ...
local L = ns.L

local function On(key) return ns.db and ns.db[key] == true end

-- Camera ------------------------------------------------------------------------------------------

local MAX_ZOOM = 2.6 -- engine maximum; higher values are clamped

local function RaiseZoom()
    if InCombatLockdown() then return ns.AfterCombat(RaiseZoom) end
    local current = tonumber(GetCVar("cameraDistanceMaxZoomFactor")) or 0
    if current < MAX_ZOOM then SetCVar("cameraDistanceMaxZoomFactor", MAX_ZOOM) end
end
ns:On("PLAYER_LOGIN", RaiseZoom)

-- Summon ------------------------------------------------------------------------------------------

local SUMMON_DELAY = 5 -- seconds to cancel by declining the popup

ns:On("CONFIRM_SUMMON", function()
    if not On("autoSummon") or UnitAffectingCombat("player") then return end
    local who, where = C_SummonInfo.GetSummonConfirmSummoner(), C_SummonInfo.GetSummonConfirmAreaName()
    if not (ns.Readable(who) and ns.Readable(where)) then return end
    ns.Print(L["Accepting the summon from %s (%s) in %d seconds."]:format(who or "?", where or "?", SUMMON_DELAY))
    C_Timer.After(SUMMON_DELAY, function()
        if UnitAffectingCombat("player") then return end
        -- declined or replaced meanwhile: the summoner/area no longer match
        if C_SummonInfo.GetSummonConfirmTimeLeft() <= 0 then return end
        if C_SummonInfo.GetSummonConfirmSummoner() ~= who or C_SummonInfo.GetSummonConfirmAreaName() ~= where then return end
        C_SummonInfo.ConfirmSummon()
        StaticPopup_Hide("CONFIRM_SUMMON")
    end)
end)

-- Resurrection ------------------------------------------------------------------------------------

ns:On("RESURRECT_REQUEST", function(_, caster)
    if not On("autoResurrect") or not ns.Readable(caster) or not caster then return end
    -- only players in combat are a risk (rezzed into a running fight); out-of-group casters read false
    if UnitAffectingCombat(caster) then return end
    AcceptResurrect()
    for _, which in ipairs({ "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }) do
        StaticPopup_Hide(which)
    end
end)

-- Duels -------------------------------------------------------------------------------------------

local function Trusted(name)
    if not name then return false end
    if C_FriendList.IsFriend and C_FriendList.GetFriendInfo and C_FriendList.GetFriendInfo(name) then return true end
    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local member = GetGuildRosterInfo(i)
            if member and Ambiguate(member, "none") == Ambiguate(name, "none") then return true end
        end
    end
    return false
end

ns:On("DUEL_REQUESTED", function(_, name)
    if not On("declineDuels") or not ns.Readable(name) or Trusted(name) then return end
    CancelDuel()
    StaticPopup_Hide("DUEL_REQUESTED")
end)

-- Cinematics --------------------------------------------------------------------------------------

local function Seen()
    local db = _G["MeredanUIDB"]
    if type(db) ~= "table" then return nil end
    db.seenCinematics = db.seenCinematics or {}
    return db.seenCinematics
end

ns:On("PLAY_MOVIE", function(_, movieID)
    local seen = Seen()
    if not (seen and movieID) then return end
    local key = "m" .. movieID
    if seen[key] and On("skipCinematics") then
        -- MovieFrame started it in the same event: finish it one frame later
        C_Timer.After(0, function()
            if MovieFrame and MovieFrame:IsShown() and MovieFrame.FinishMovie then MovieFrame:FinishMovie() end
        end)
    end
    seen[key] = true
end)

ns:On("CINEMATIC_START", function(_, canBeCancelled)
    local seen = Seen()
    if not seen then return end
    local key = "c" .. (C_Map.GetBestMapForUnit("player") or 0) .. ":" .. (GetSubZoneText() or "")
    if seen[key] and canBeCancelled and On("skipCinematics") then
        C_Timer.After(0.1, function()
            if InCinematic() and CinematicFrame_CancelCinematic then CinematicFrame_CancelCinematic() end
        end)
    end
    seen[key] = true
end)
