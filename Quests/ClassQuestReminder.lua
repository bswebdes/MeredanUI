-- Class quest reminder (Comfort, Forever): a toast when a class quest that unlocks an ability becomes
-- available (Bear Form, Voidwalker, totems ...), with the nearest start for the player's race.
-- Click sets Blizzard's map pin (with the on-screen arrow) on the quest giver.
--
--   [class icon] Class quest: Bear Form
--                Denatharion, Darnassus
--
-- On level-up for quests of exactly that level; after login once a day for all still open ones.
-- Silent when the reward quest is done or any quest of the chain is in the log. Data: Quests/ClassQuests.lua.
local _, ns = ...
local L = ns.L

local MAX_LOGIN_TOASTS = 2

local function Enabled() return ns.IS_FOREVER and ns.db and ns.db.classQuestReminder == true end

local function Done(m)
    for _, id in ipairs(m.finals) do
        if C_QuestLog.IsQuestFlaggedCompleted(id) then return true end
    end
    return false
end

local function InLog(m)
    for _, id in ipairs(m.ids) do
        if C_QuestLog.GetLogIndexForQuestID(id) then return true end
    end
    return false
end

local function Start(m)
    local raceID = select(3, UnitRace("player"))
    return raceID and m.starts[raceID]
end

local german = GetLocale() == "deDE"

local function Label(m, s)
    -- priests: each race has its own spell, the quest carries its name
    if m.reward == "Racial spell" then return german and s.name or s.nameEN end
    return L[m.reward]
end

local function Where(s)
    local npc = german and s.npc or s.npcEN
    local info = s.map and C_Map.GetMapInfo(s.map)
    if npc and info then return ("%s, %s"):format(npc, info.name) end
    return german and s.name or s.nameEN -- start unknown: at least the quest name
end

local function SetPin(s)
    if not (s.map and C_Map.CanSetUserWaypointOnMap(s.map)) then return end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(s.map, s.x / 100, s.y / 100))
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    ns.Print(L["Map pin set: %s"], Where(s))
end

local function Toast(m, s)
    if not ns.AddToast then return end
    local _, classFile = UnitClass("player")
    local c = RAID_CLASS_COLORS[classFile]
    ns.AddToast({
        title = L["Class quest: %s"]:format(Label(m, s)),
        text = Where(s),
        icon = "Interface\\Icons\\ClassIcon_" .. classFile,
        color = c and { c.r, c.g, c.b } or ns.UI.ACCENT,
        onClick = s.map and function() SetPin(s) end or nil,
    })
end

-- open milestones up to `level`; exact = only those of exactly that level
local function Open(level, exact)
    local _, classFile = UnitClass("player")
    local list = {}
    for _, m in ipairs(ns.CLASS_QUESTS and ns.CLASS_QUESTS[classFile] or {}) do
        local s = Start(m)
        if s and m.level <= level and (not exact or m.level == level) and not Done(m) and not InLog(m) then
            list[#list + 1] = { m, s }
        end
    end
    return list
end

local function OnLogin()
    if not Enabled() then return end
    local today = date("%Y-%m-%d")
    if ns.char.classQuestDay == today then return end
    local list = Open(UnitLevel("player"))
    if #list == 0 then return end
    ns.char.classQuestDay = today
    for i = 1, math.min(#list, MAX_LOGIN_TOASTS) do Toast(list[i][1], list[i][2]) end
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    C_Timer.After(8, OnLogin) -- after the other login toasts
end)

ns:On("PLAYER_LEVEL_UP", function(_, level)
    if not Enabled() then return end
    C_Timer.After(3, function() -- after the level-up banner
        for _, entry in ipairs(Open(level, true)) do Toast(entry[1], entry[2]) end
    end)
end)
