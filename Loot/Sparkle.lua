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

local function CreateEffect(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(48, 48)
    f:SetIgnoreParentAlpha(true) -- mUI hides object plates via alpha
    f:Hide()

    f.glow = f:CreateTexture(nil, "BACKGROUND")
    f.glow:SetTexture(131010) -- interface/cooldown/star4
    f.glow:SetBlendMode("ADD")
    f.glow:SetPoint("CENTER")
    f.glow:SetSize(64, 64)

    f.star = f:CreateTexture(nil, "ARTWORK")
    f.star:SetAtlas("shop-toast-sparkle")
    f.star:SetBlendMode("ADD")
    f.star:SetPoint("CENTER")
    f.star:SetSize(32, 32)

    f.small = f:CreateTexture(nil, "ARTWORK")
    f.small:SetAtlas("shop-toast-sparkle")
    f.small:SetBlendMode("ADD")
    f.small:SetPoint("CENTER", 14, 10)
    f.small:SetSize(14, 14)

    -- glow breathes, big star turns slowly, small star twinkles
    local pulse = f.glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local a = pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(0.35); a:SetToAlpha(0.9); a:SetDuration(0.9); a:SetSmoothing("IN_OUT")
    f.pulse = pulse

    local spin = f.star:CreateAnimationGroup()
    spin:SetLooping("REPEAT")
    local r = spin:CreateAnimation("Rotation")
    r:SetDegrees(-360); r:SetDuration(6)
    f.spin = spin

    local twinkle = f.small:CreateAnimationGroup()
    twinkle:SetLooping("BOUNCE")
    local t = twinkle:CreateAnimation("Alpha")
    t:SetFromAlpha(0); t:SetToAlpha(1); t:SetDuration(0.6); t:SetStartDelay(0.3)
    f.twinkle = twinkle

    f.text = f:CreateFontString(nil, "OVERLAY")
    ns.SetFont(f.text, 12, "OUTLINE")
    f.text:SetPoint("TOP", f, "BOTTOM", 0, 4)

    function f:Set(kind, inRange, progress)
        local c = COLORS[kind] or COLORS.other
        for _, tex in ipairs({ self.glow, self.star, self.small }) do tex:SetVertexColor(c[1], c[2], c[3]) end
        self:SetAlpha(inRange and 1 or 0.4)
        self.text:SetText(progress or "")
        self.text:SetTextColor(c[1], c[2], c[3])
    end

    function f:Play()
        self:Show()
        self.pulse:Play(); self.spin:Play(); self.twinkle:Play()
    end

    function f:Stop()
        self.pulse:Stop(); self.spin:Stop(); self.twinkle:Stop()
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

local lastDebug
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
    if DevLog then
        local line = ("Sparkle atlas=%s tex=%s -> %s %s"):format(tostring(atlas), tostring(tex), kind, tostring(inRange))
        if line ~= lastDebug then lastDebug = line; DevLog("MeredanUI", line) end
    end
    return kind, inRange
end

local function ObjectID()
    local guid = UnitGUID(UNIT)
    if not Readable(guid) or not guid then return nil end
    return tonumber((select(6, strsplit("-", guid))))
end

-- "3/8" style quest line, only when the world tooltip shows this very object (mouse-over)
local QUEST_LINE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8
local function Progress()
    local name = UnitName(UNIT)
    if not Readable(name) or not name or not C_TooltipInfo.GetWorldCursor then return nil end
    local data = C_TooltipInfo.GetWorldCursor()
    local lines = data and data.lines
    if not lines or not lines[1] or not Readable(lines[1].leftText) or lines[1].leftText ~= name then return nil end
    for i = #lines, 2, -1 do
        local line = lines[i]
        if line.type == QUEST_LINE and Readable(line.leftText) and line.leftText then
            return line.leftText:match("(%d+%s*/%s*%d+)") or line.leftText
        end
    end
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
    local plate = C_NamePlate.GetNamePlateForUnit(UNIT)
    local kind, inRange = Classify()
    if DevLog and kind and not plate then DevLog("MeredanUI", "Sparkle: no plate for " .. UNIT) end
    if not plate or not kind then return Hide() end
    -- units: only skinnable corpses (living NPCs and loot-only corpses stay plain)
    if not isObject and kind ~= "skin" then return Hide() end
    effect = effect or CreateEffect(UIParent)
    if effect:GetParent() ~= plate then
        effect:SetParent(plate)
        effect:ClearAllPoints()
        effect:SetPoint("CENTER", plate, "CENTER", 0, 0)
    end
    effect:Set(kind, inRange, Progress())
    if not effect:IsShown() then effect:Play() end
    -- range and quest text change while walking; light 4x/s poll only while something sparkles
    ticker = ticker or C_Timer.NewTicker(0.25, function()
        if not effect:IsShown() then return end
        local k, r = Classify()
        if k then effect:Set(k, r, Progress()) end
    end)
end

-- CVars ------------------------------------------------------------------------------------------

local function ApplyCVars()
    if InCombatLockdown() then return ns.AfterCombat(ApplyCVars) end
    local saved = ns.db.sparkleCVars
    if Enabled() then
        if not saved then
            saved = {}
            for cvar in pairs(CVARS) do saved[cvar] = C_CVar.GetCVar(cvar) end
            ns.db.sparkleCVars = saved
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
