-- Profiles: create (copy of the active one), rename, delete, switch; optionally per specialization.
-- Switching asks to reload the UI, since sizes and positions affect the whole layout.
local _, ns = ...
local L = ns.L

local Profiles = {}
ns.Profiles = Profiles

-- Built-in profiles first (fixed order), then custom profiles alphabetically.
function Profiles.IsBuiltin(name)
    return tIndexOf(ns.BUILTIN_PROFILES, name) ~= nil
end

function Profiles.List()
    local names = CopyTable(ns.BUILTIN_PROFILES)
    local own = {}
    for name in pairs(ns.root.profiles) do
        if not Profiles.IsBuiltin(name) then own[#own + 1] = name end
    end
    table.sort(own, function(a, b) return a:lower() < b:lower() end)
    for _, name in ipairs(own) do names[#names + 1] = name end
    return names
end

function Profiles.Exists(name)
    return ns.root.profiles[name] ~= nil
end

-- Trimmed name, or nil if empty or taken.
local function ValidName(name)
    name = name and strtrim(name) or ""
    if name == "" or Profiles.Exists(name) then return nil end
    return name
end

-- New profile as a copy of the active one. Returns the name (or nil).
function Profiles.Create(name)
    name = ValidName(name)
    if not name then return end
    ns.root.profiles[name] = CopyTable(ns.db)
    return name
end

-- Rename (not built-ins); updates all character and spec assignments.
function Profiles.Rename(old, new)
    new = ValidName(new)
    if not new or not Profiles.Exists(old) or Profiles.IsBuiltin(old) then return end
    ns.root.profiles[new] = ns.root.profiles[old]
    ns.root.profiles[old] = nil
    for _, char in pairs(ns.root.chars) do
        if char.profile == old then char.profile = new end
        for spec, profile in pairs(char.specProfiles or {}) do
            if profile == old then char.specProfiles[spec] = new end
        end
    end
    if ns.profileName == old then ns.profileName = new end
    if ns.root.newCharProfile == old then ns.root.newCharProfile = new end
    return new
end

-- Delete (not the active one or built-ins); its users fall back to the default profile.
function Profiles.Delete(name)
    if name == ns.profileName or Profiles.IsBuiltin(name) or not Profiles.Exists(name) then return end
    ns.root.profiles[name] = nil
    if ns.root.newCharProfile == name then ns.root.newCharProfile = nil end
    for _, char in pairs(ns.root.chars) do
        if char.profile == name then char.profile = ns.DEFAULT_PROFILE end
        for spec, profile in pairs(char.specProfiles or {}) do
            if profile == name then char.specProfiles[spec] = nil end
        end
    end
    return true
end

local function AskReload(text)
    StaticPopup_ShowCustomGenericConfirmation({
        text = text,
        callback = ReloadUI,
        acceptText = L["Reload now"],
        cancelText = L["Later"],
    })
end

-- Switch this character's profile; takes effect after reload.
function Profiles.Switch(name)
    if not Profiles.Exists(name) or name == ns.char.profile then return end
    ns.char.profile = name
    if name ~= ns.profileName then
        AskReload(L["Switch to profile \"%s\"? The UI will be reloaded."]:format(name))
    end
end

-- Character specializations: { { index, name }, ... } (empty if none)
function Profiles.Specs()
    local specs = {}
    local _, _, classID = UnitClass("player")
    local count = C_SpecializationInfo.GetNumSpecializationsForClassID
        and C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    for index = 1, count do
        local name = GetSpecializationInfoForClassID and select(2, GetSpecializationInfoForClassID(classID, index))
        specs[#specs + 1] = { index = index, name = name or tostring(index) }
    end
    return specs
end

-- Auto-switch to the profile assigned to the active specialization
local function CheckSpec()
    if not ns.char.specAuto then return end
    local spec = C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
    local target = spec and ns.char.specProfiles[spec]
    if target and Profiles.Exists(target) and target ~= ns.profileName then
        ns.char.profile = target
        AskReload(L["Your specialization uses profile \"%s\". Reload the UI now?"]:format(target))
    end
end

ns:On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", CheckSpec)
ns:On("PLAYER_ENTERING_WORLD", function(_, isLogin, isReload)
    if isLogin or isReload then CheckSpec() end
end)
