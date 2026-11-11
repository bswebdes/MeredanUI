-- Sparkle (Comfort): glitter on the nearby object the game would interact with (herb, ore, quest
-- object, chest) or skinnable corpse. The client gives that "soft interact" object a nameplate when
-- SoftTargetIconGameObject is on; the effect is parented to that plate so it follows the object.
-- Only one object at a time - that is the client's selection, not ours.
-- Kind comes from the game's own interact cursor (works in every language, no name lists),
-- "unable" cursors mean out of range -> dimmed. Quest progress from the world tooltip (mouse-over).
local _, ns = ...
local L = ns.L
local Readable = ns.Readable

local UNIT = "softinteract"
local BOBBER_ID = 35591 -- fishing bobber: never sparkle

-- cvar -> value we need; originals are kept in ns.db.sparkleCVars and restored when turned off
local CVARS = {
    softTargetInteract = tostring(Enum.SoftTargetEnableFlags and Enum.SoftTargetEnableFlags.Any or 3),
    SoftTargetIconGameObject = "1",
    SoftTargetNameplateInteract = "1", -- corpses get no plate otherwise -> nothing to attach to
    SoftTargetInteractRange = "15", -- default 10 yd: you are already there when it shows
}

local COLORS = {
    herb = { 0.35, 1, 0.35 },
    skin = { 1, 0.3, 0.25 },
    ore = { 1, 0.55, 0.2 },
    quest = { 1, 0.82, 0 },
    other = { 1, 1, 1 },
}

local function Enabled() return ns.db and ns.db.sparkle == true end

-- Effect -----------------------------------------------------------------------------------------

local GLOW = 1063457 -- soft round glow (genericglow64)
local DOT = 1063561  -- small soft dot (t_vfx_glow01_64)
local RING = 131009  -- thin ring (cooldown/ping4)
local DOTS = { { -22, 14, 9, 0 }, { 20, 22, 7, 0.5 }, { 16, -12, 8, 1 } } -- x, y, size, delay

local function CreateEffect(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(64, 64)
    f:SetIgnoreParentAlpha(true) -- mUI hides object plates via alpha
    f:Hide()
    f.textures, f.anims = {}, {}

    local function Tex(file, size, x, y, layer)
        local t = f:CreateTexture(nil, layer or "ARTWORK")
        t:SetTexture(file)
        t:SetBlendMode("ADD")
        t:SetPoint("CENTER", x or 0, y or 0)
        t:SetSize(size, size)
        f.textures[#f.textures + 1] = t
        return t
    end

    -- soft glow, breathing
    local glow = Tex(GLOW, 96, 0, 0, "BACKGROUND")
    local g = glow:CreateAnimationGroup()
    g:SetLooping("BOUNCE")
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(0.45); a:SetToAlpha(0.85); a:SetDuration(1.2); a:SetSmoothing("IN_OUT")
    f.anims[#f.anims + 1] = g

    -- bright core
    local core = Tex(DOT, 26)
    core:SetAlpha(0.9)

    -- ring that widens and fades, like a ripple
    local ring = Tex(RING, 70)
    local r = ring:CreateAnimationGroup()
    r:SetLooping("REPEAT")
    local s = r:CreateAnimation("Scale")
    s:SetScaleFrom(0.35, 0.35); s:SetScaleTo(1.15, 1.15); s:SetDuration(1.6); s:SetSmoothing("OUT")
    local fade = r:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.8); fade:SetToAlpha(0); fade:SetDuration(1.6); fade:SetSmoothing("IN")
    f.anims[#f.anims + 1] = r

    -- small dots twinkling one after another
    for _, d in ipairs(DOTS) do
        local dot = Tex(DOT, d[3] * 2, d[1], d[2], "OVERLAY")
        dot:SetAlpha(0)
        local t = dot:CreateAnimationGroup()
        t:SetLooping("REPEAT")
        local up = t:CreateAnimation("Alpha")
        up:SetFromAlpha(0); up:SetToAlpha(1); up:SetDuration(0.35); up:SetStartDelay(d[4]); up:SetOrder(1)
        local down = t:CreateAnimation("Alpha")
        down:SetFromAlpha(1); down:SetToAlpha(0); down:SetDuration(0.6); down:SetOrder(2)
        local rise = t:CreateAnimation("Translation")
        rise:SetOffset(0, 8); rise:SetDuration(0.95); rise:SetStartDelay(d[4]); rise:SetOrder(1)
        local pause = t:CreateAnimation("Alpha")
        pause:SetFromAlpha(0); pause:SetToAlpha(0); pause:SetDuration(0.6 - d[4] * 0.4); pause:SetOrder(3)
        f.anims[#f.anims + 1] = t
    end

    f.text = f:CreateFontString(nil, "OVERLAY")
    ns.SetFont(f.text, 12, "OUTLINE")
    f.text:SetPoint("TOP", f, "BOTTOM", 0, 2)

    function f:Set(kind, inRange, progress)
        local c = COLORS[kind] or COLORS.other
        for _, tex in ipairs(self.textures) do tex:SetVertexColor(c[1], c[2], c[3]) end
        self:SetAlpha(inRange and 1 or 0.45)
        self.text:SetText(progress or "")
        self.text:SetTextColor(c[1], c[2], c[3])
    end

    function f:Play()
        self:Show()
        for _, anim in ipairs(self.anims) do anim:Play() end
    end

    function f:Stop()
        for _, anim in ipairs(self.anims) do anim:Stop() end
        self:Hide()
    end

    return f
end

-- Detection --------------------------------------------------------------------------------------

local probe = UIParent:CreateTexture(nil, "BACKGROUND")
probe:Hide()

-- cursor textures come back as file IDs, not paths: map them (classic files + 2x atlas sheets)
local FILE_KINDS = {
    [131018] = "herb", [7958141] = "herb",                                   -- gatherherbs, uicursorgather2x
    [131025] = "ore", [7958147] = "ore",                                     -- mine, uicursormine2x
    [131035] = "skin", [131036] = "skin", [131037] = "skin", [235498] = "skin", [7958194] = "skin",
    [131030] = "quest", [1006596] = "quest", [131032] = "quest", [6009167] = "quest",
    [131052] = "ore", [131062] = "skin", [131064] = "skin", [131057] = "quest", -- unable* variants
}
local FILE_UNABLE = { [131052] = true, [131062] = true, [131064] = true, [131057] = true }

local function KindFromName(name)
    name = name:lower()
    local kind = (name:find("herb") and "herb") or (name:find("gather") and "herb") or (name:find("mine") and "ore")
        or (name:find("skin") and "skin") or (name:find("quest") and "quest") or "other"
    return kind, not name:find("unable")
end

-- kind + in range from the interact cursor the game would show for the unit
local function Classify()
    if not SetUnitCursorTexture(probe, UNIT, nil, nil, true) then return nil end
    local atlas, tex = probe:GetAtlas(), probe:GetTexture()
    if not Readable(atlas) then atlas = nil end
    if not Readable(tex) then tex = nil end
    local kind, inRange
    if type(atlas) == "string" and atlas ~= "" then
        kind, inRange = KindFromName(atlas)
    elseif type(tex) == "number" then
        kind, inRange = FILE_KINDS[tex] or "other", not FILE_UNABLE[tex]
    elseif type(tex) == "string" then
        kind, inRange = KindFromName(tex)
    else
        kind, inRange = "other", true
    end
    return kind, inRange
end

local function ObjectID()
    local guid = UnitGUID(UNIT)
    if not Readable(guid) or not guid then return nil end
    return tonumber((select(6, strsplit("-", guid))))
end

-- "3/8" style quest line of the object's tooltip: the soft-interact unit tooltip if the client gives
-- one, else the world tooltip while the mouse points at this very object
local QUEST_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8
local function QuestLine(data, name)
    local lines = data and data.lines
    if not lines or not lines[1] or not Readable(lines[1].leftText) or lines[1].leftText ~= name then return nil end
    for i = #lines, 2, -1 do
        local line = lines[i]
        if line.type == QUEST_LINE and Readable(line.leftText) and line.leftText then
            return line.leftText:match("(%d+%s*/%s*%d+)") or line.leftText
        end
    end
end

local questObjects = {} -- object IDs seen with a quest line this session (yellow before mouse-over)
local function Progress()
    local name = UnitName(UNIT)
    if not Readable(name) or not name then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnit, UNIT)
    local progress = ok and QuestLine(data, name)
    if not progress and C_TooltipInfo.GetWorldCursor then progress = QuestLine(C_TooltipInfo.GetWorldCursor(), name) end
    local id = ObjectID()
    if progress and id then questObjects[id] = true end
    return progress
end
ns:On("QUEST_REMOVED", function() wipe(questObjects) end)
ns:On("QUEST_TURNED_IN", function() wipe(questObjects) end)

-- the plate is registered under its "nameplateN" token, not "softinteract": search by unit
local function FindPlate()
    local plate = C_NamePlate.GetNamePlateForUnit(UNIT)
    if plate then return plate end
    for _, p in ipairs(C_NamePlate.GetNamePlates()) do
        local token = p.GetUnit and p:GetUnit() or p.namePlateUnitToken
        if token then
            local same = UnitIsUnit(token, UNIT)
            if Readable(same) and same then return p end
        end
    end
end

-- quest objects often use the plain "interact" cursor: ask the quest log, or use the tooltip progress
local function QuestKind(kind, progress)
    if kind ~= "other" then return kind end
    if progress then return "quest" end
    local id = ObjectID()
    if id and questObjects[id] then return "quest" end
    local related = C_QuestLog.UnitIsRelatedToActiveQuest and C_QuestLog.UnitIsRelatedToActiveQuest(UNIT)
    if Readable(related) and related then return "quest" end
    return kind
end

-- Gathering only for those who can: herbs need Herbalism, ore Mining, corpses Skinning.
-- Spell ranks (Apprentice..Artisan) plus the skill line as second source.
local PROFESSION = {
    herb = { skill = 182, spells = { 2366, 2368, 3570, 11993 } },
    ore = { skill = 186, spells = { 2575, 2576, 3564, 10248 } },
    skin = { skill = 393, spells = { 8613, 8617, 8618, 10768 } },
}
local known
local function HasProfession(kind)
    local p = PROFESSION[kind]
    if not p then return true end
    if not known then
        known = {}
        for k, data in pairs(PROFESSION) do
            for _, id in ipairs(data.spells) do
                if C_SpellBook.IsSpellKnown(id) then known[k] = true end
            end
        end
        if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
            for i = 1, C_SkillInfo.GetNumSkillLines() do
                local info = C_SkillInfo.GetSkillLineInfo(i)
                for k, data in pairs(PROFESSION) do
                    if info and info.skillID == data.skill then known[k] = true end
                end
            end
        end
    end
    return known[kind] or false
end
for _, event in ipairs({ "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED" }) do
    ns:On(event, function() known = nil end)
end

-- Update -----------------------------------------------------------------------------------------

local effect
local ticker

local function Hide()
    if effect then effect:Stop() end
    if ticker then ticker:Cancel(); ticker = nil end
end

local function Update()
    if not Enabled() or UnitAffectingCombat("player") then return Hide() end
    local isObject = UnitIsGameObject(UNIT)
    isObject = Readable(isObject) and isObject
    if isObject and ObjectID() == BOBBER_ID then return Hide() end
    local plate = FindPlate()
    local kind, inRange = Classify()
    -- corpse without a readable cursor: dead + nothing left to loot = skinnable
    if not kind and not isObject and UnitExists(UNIT) then
        local dead = UnitIsDead(UNIT)
        local guid = UnitGUID(UNIT)
        if Readable(dead) and dead and Readable(guid) and guid then
            local hasLoot = CanLootUnit(guid)
            if not (Readable(hasLoot) and hasLoot) then kind, inRange = "skin", true end
        end
    end
    if not plate or not kind then return Hide() end
    -- units: only skinnable corpses (living NPCs and loot-only corpses stay plain)
    if not isObject and kind ~= "skin" then return Hide() end
    local progress = Progress()
    kind = QuestKind(kind, progress)
    if kind == "other" and not ns.db.sparkleOther then return Hide() end
    if not HasProfession(kind) then return Hide() end
    effect = effect or CreateEffect(UIParent)
    if effect:GetParent() ~= plate then
        effect:SetParent(plate)
        effect:ClearAllPoints()
        effect:SetPoint("CENTER", plate, "CENTER", 0, 0)
    end
    effect:Set(kind, inRange, progress)
    if not effect:IsShown() then effect:Play() end
    -- range and quest text change while walking; light 4x/s poll only while something sparkles
    ticker = ticker or C_Timer.NewTicker(0.25, function()
        if not effect:IsShown() then return end
        local k, r = Classify()
        if k then
            local progress = Progress()
            k = QuestKind(k, progress)
            if (k == "other" and not ns.db.sparkleOther) or not HasProfession(k) then return Hide() end
            effect:Set(k, r, progress)
        end
    end)
end

-- CVars ------------------------------------------------------------------------------------------

local function ApplyCVars()
    if InCombatLockdown() then return ns.AfterCombat(ApplyCVars) end
    local saved = ns.db.sparkleCVars
    if Enabled() then
        saved = saved or {}
        ns.db.sparkleCVars = saved
        for cvar in pairs(CVARS) do
            if saved[cvar] == nil then saved[cvar] = C_CVar.GetCVar(cvar) end
        end
        for cvar, value in pairs(CVARS) do
            if C_CVar.GetCVar(cvar) and C_CVar.GetCVar(cvar) ~= value then C_CVar.SetCVar(cvar, value) end
        end
    elseif saved then
        for cvar, value in pairs(saved) do
            if value and C_CVar.GetCVar(cvar) then C_CVar.SetCVar(cvar, value) end
        end
        ns.db.sparkleCVars = nil
    end
end

function ns.UpdateSparkle()
    ApplyCVars()
    Update()
end

ns:On("PLAYER_LOGIN", ApplyCVars)
ns:On("PLAYER_SOFT_INTERACT_CHANGED", Update)
ns:On("NAME_PLATE_UNIT_ADDED", function(_, unit)
    if not unit then return end
    local same = UnitIsUnit(unit, UNIT)
    if Readable(same) and same then Update() end
end)
ns:On("NAME_PLATE_UNIT_REMOVED", function() C_Timer.After(0, Update) end)
ns:On("PLAYER_REGEN_DISABLED", Hide)
ns:On("PLAYER_REGEN_ENABLED", Update)

-- Preview (/mui t): one sample per kind plus a dimmed one --------------------------------------

local demo
ns.SparkleDemo = {
    Start = function()
        if not demo then
            demo = CreateFrame("Frame", nil, UIParent)
            demo:SetSize(6 * 70, 70)
            demo:SetPoint("CENTER", 0, 160)
            demo.items = {}
            local samples = {
                { "herb", true }, { "ore", true }, { "quest", true, "3/8" }, { "skin", true }, { "other", true }, { "herb", false },
            }
            for i, s in ipairs(samples) do
                local e = CreateEffect(demo)
                e:SetPoint("CENTER", demo, "LEFT", 35 + (i - 1) * 70, 0)
                e:Set(s[1], s[2], s[3])
                demo.items[i] = e
            end
        end
        demo:Show()
        for _, e in ipairs(demo.items) do e:Play() end
    end,
    Stop = function()
        if not demo then return end
        for _, e in ipairs(demo.items) do e:Stop() end
        demo:Hide()
    end,
    IsActive = function() return demo and demo:IsShown() end,
}
