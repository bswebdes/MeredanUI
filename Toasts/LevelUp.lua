-- Level-up display (rune look): replaces Blizzard's level-up banner and the level-up toast.
-- Top centre, no box: a soft dark shadow, a bronze divider with a gem, "LEVEL UP" and the new level
-- in Cinzel, below up to four unlocks the game reports for that level (spells, dungeons ...) with
-- their icon in an item frame. Fades in, holds, fades out; hovering pauses it, right-click closes.
-- Follows the toast setting: toasts off = Blizzard's banner stays.
local _, ns = ...
local L = ns.L

local WIDTH = 560
local TOP = 160          -- from the top edge, where Blizzard shows its banner
local ICON = 34
local MAX_ROWS = 4
local FADE_IN, HOLD, FADE_OUT = 0.4, 6, 0.8
local LIGHT = { 0.953, 0.902, 0.769 }

-- Blizzard's level-up toast types (Enum.EventToastEventType)
local LEVEL_TYPES = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [15] = true }

local function Enabled() return ns.db and ns.db.toasts ~= false end
ns.LevelUpDisplayOn = Enabled

local frame, rows, more
local state, timer -- "in", "hold", "out"; seconds in the current state
local demo = false

local function Divider(parent, inset, gem)
    local m = ns.Material()
    local r, g, b = m.lit[1], m.lit[2], m.lit[3]
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(16)
    for i = 1, 2 do
        local line = holder:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(1, 1, 1, 1)
        line:SetHeight(ns.PixelSize())
        line:SetPoint(i == 1 and "LEFT" or "RIGHT", holder, i == 1 and "LEFT" or "RIGHT", i == 1 and inset or -inset, 0)
        line:SetPoint(i == 1 and "RIGHT" or "LEFT", holder, "CENTER", i == 1 and (gem and -10 or 0) or (gem and 10 or 0), 0)
        local faded, full = CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.9)
        if i == 1 then line:SetGradient("HORIZONTAL", faded, full) else line:SetGradient("HORIZONTAL", full, faded) end
    end
    if gem then ns.UI.Diamond(holder, 8):SetPoint("CENTER") end
    return holder
end

local function Row(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, frame.list)
    row:SetHeight(ICON)
    row.holder = CreateFrame("Frame", nil, row)
    row.holder:SetSize(ICON, ICON)
    row.holder:SetPoint("LEFT")
    ns.AddSlotBackground(row.holder)
    ns.AddItemFrame(row.holder, nil, 2)
    row.icon = row.holder:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(row.holder, row.icon, nil, 2)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = ns.CreateText(row, 14, "LEFT", "OUTLINE")
    row.name:SetPoint("BOTTOMLEFT", row.holder, "RIGHT", 12, 1)
    row.sub = ns.CreateText(row, 12, "LEFT", "OUTLINE")
    row.sub:SetPoint("TOPLEFT", row.holder, "RIGHT", 12, -2)
    row.sub:SetTextColor(unpack(ns.UI.MUTED))
    rows[i] = row
    return row
end

local function Create()
    frame = CreateFrame("Frame", "MeredanUILevelUp", UIParent)
    frame:SetSize(WIDTH, 200)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -ns.Snap(TOP))
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:Hide()
    rows = {}

    -- soft dark shadow behind everything, no box
    local shadow = frame:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture(ns.MEDIA .. "Glow")
    shadow:SetVertexColor(0, 0, 0, 0.75)
    shadow:SetPoint("TOPLEFT", -120, 60)
    shadow:SetPoint("BOTTOMRIGHT", 120, -60)

    frame.top = Divider(frame, 0, true)
    frame.top:SetPoint("TOPLEFT")
    frame.top:SetPoint("TOPRIGHT")
    frame.label = ns.UI.Heading(frame, 14, "CENTER")
    frame.label:SetPoint("TOP", frame.top, "BOTTOM", 0, -10)
    frame.label:SetText(L["Level up"])
    frame.level = ns.CreateText(frame, 48, "CENTER", nil, "display")
    frame.level:SetTextColor(unpack(LIGHT))
    frame.level:SetShadowOffset(0, -2)
    frame.level:SetPoint("TOP", frame.label, "BOTTOM", 0, -6)
    frame.bottom = Divider(frame, 60, false)
    frame.bottom:SetPoint("TOPLEFT", frame.level, "BOTTOM", -WIDTH / 2, -8)
    frame.bottom:SetPoint("TOPRIGHT", frame.level, "BOTTOM", WIDTH / 2, -8)
    frame.list = CreateFrame("Frame", nil, frame)
    frame.list:SetPoint("TOP", frame.bottom, "BOTTOM", 0, -8)
    more = ns.CreateText(frame, 12, "CENTER", "OUTLINE")
    more:SetTextColor(unpack(ns.UI.MUTED))

    frame:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then state, timer = "out", 0 end end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if demo then self:SetAlpha(1) return end
        if state == "hold" and self:IsMouseOver() then return end -- hovering pauses it
        timer = timer + elapsed
        if state == "in" then
            self:SetAlpha(math.min(timer / FADE_IN, 1))
            if timer >= FADE_IN then state, timer = "hold", 0 end
        elseif state == "hold" then
            if timer >= HOLD then state, timer = "out", 0 end
        else
            self:SetAlpha(math.max(1 - timer / FADE_OUT, 0))
            if timer >= FADE_OUT then self:Hide() end
        end
    end)
end

-- entries: { { icon, name, sub } ... }; restart = fade in again (else only the content changes)
local function Show(level, entries, keepFade)
    if not frame then Create() end
    frame.level:SetText((LEVEL or "Level") .. " " .. level)
    local width, height = 0, 0
    for i = 1, math.min(#entries, MAX_ROWS) do
        local e, row = entries[i], Row(i)
        row.icon:SetTexture(e.icon or 134400)
        row.name:SetText(e.name or "")
        row.sub:SetText(e.sub or "")
        local w = ICON + 12 + math.max(row.name:GetUnboundedStringWidth(), row.sub:GetUnboundedStringWidth())
        width = math.max(width, w)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (ICON + 8))
        row:Show()
        height = i * (ICON + 8) - 8
    end
    for i = #entries + 1, #rows do rows[i]:Hide() end
    for i = MAX_ROWS + 1, #rows do rows[i]:Hide() end
    for i = 1, #rows do rows[i]:SetWidth(math.max(width, 1)) end
    frame.list:SetSize(math.max(width, 1), math.max(height, 1))
    frame.list:SetShown(#entries > 0)
    more:ClearAllPoints()
    more:SetPoint("TOP", frame.list, "BOTTOM", 0, -6)
    more:SetShown(#entries > MAX_ROWS)
    if #entries > MAX_ROWS then more:SetText(L["+%d more"]:format(#entries - MAX_ROWS)) end
    frame.bottom:SetShown(#entries > 0)
    -- height for the shadow and the mouse area: dividers, label, level, list, "+N more"
    local listHeight = #entries > 0 and (8 + 16 + 8 + height + (#entries > MAX_ROWS and 20 or 0)) or 0
    frame:SetHeight(16 + 10 + 18 + 6 + 56 + listHeight)
    if keepFade and frame:IsShown() then return end
    -- in combat it must not block clicks on the world (hover/right-click work out of combat)
    frame:EnableMouse(not InCombatLockdown())
    state, timer = "in", 0
    frame:SetAlpha(0)
    frame:Show()
end

-- What the game reports for this level, without the "level reached" entry itself
local function Entries(level)
    local list = {}
    local infos = C_EventToastManager and C_EventToastManager.GetLevelUpDisplayToastsFromLevel
        and C_EventToastManager.GetLevelUpDisplayToastsFromLevel(level) or {}
    for _, info in ipairs(infos) do
        if info.eventType ~= 0 then
            local sub = (info.subtitle and info.subtitle ~= "" and info.subtitle) or info.instructionText
            list[#list + 1] = { icon = info.iconFileID, name = info.title, sub = sub }
        end
    end
    return list
end

-- Plus the trainer spells waiting: new at this level first, then older ones not learned yet. From
-- the spellbook (future spells, if the game lists them) and the trainer list remembered at the last
-- visit (Talents/Spellbook.lua)
local function Unlocks(level)
    local entries, seen = Entries(level), {}
    for _, e in ipairs(entries) do seen[e.name or ""] = true end
    local spells = {}
    for _, spell in ipairs(ns.NewTrainerSpells and ns.NewTrainerSpells(level) or {}) do
        spell.level = level
        spells[#spells + 1] = spell
    end
    for _, spell in ipairs(ns.TrainerWaiting and ns.TrainerWaiting(level) or {}) do spells[#spells + 1] = spell end
    table.sort(spells, function(a, b) return (a.level or 0) > (b.level or 0) end)
    for _, spell in ipairs(spells) do
        local name = spell.rank and ("%s |cffa89d86(%s)|r"):format(spell.name, spell.rank) or spell.name
        if not seen[name] then
            seen[name] = true
            local sub = spell.level == level and L["New at the class trainer"] or L["Still to learn at the class trainer"]
            entries[#entries + 1] = { icon = spell.icon, name = name, sub = sub }
        end
    end
    return entries
end

ns:On("PLAYER_LEVEL_UP", function(_, level)
    if not Enabled() or not level then return end
    Show(level, Unlocks(level))
    -- the spellbook knows the new trainer spells only a moment later: add them then
    C_Timer.After(2, function()
        if frame and frame:IsShown() then Show(level, Unlocks(level), true) end
    end)
end)

-- Blizzard's level-up banner: invisible and click-through while it shows a level-up toast (the
-- queue keeps running, so other event toasts still appear)
ns:On("PLAYER_LOGIN", function()
    local manager = EventToastManagerFrame
    if not (manager and manager.DisplayToast) then return end
    hooksecurefunc(manager, "DisplayToast", function(self)
        local toast = self.currentDisplayingToast
        local info = toast and toast.toastInfo
        local hide = Enabled() and info and LEVEL_TYPES[info.eventType] or false
        self:SetAlpha(hide and 0 or 1)
        self:EnableMouse(not hide)
    end)
end)

-- Preview (/mui t): a sample level with unlocks, shown until the preview ends
ns.LevelUpDemo = {
    Start = function()
        if not Enabled() then return end
        demo = true
        local function Spell(id) return C_Spell.GetSpellName(id) or "?" end
        Show(18, {
            { icon = 132330, name = Spell(2643) .. " |cffa89d86(" .. (RANK or "Rank") .. " 2)|r", sub = L["New at the class trainer"] },
            { icon = 136076, name = Spell(13165) .. " |cffa89d86(" .. (RANK or "Rank") .. " 2)|r", sub = L["New at the class trainer"] },
            { icon = 135130, name = Spell(1978) .. " |cffa89d86(" .. (RANK or "Rank") .. " 1)|r", sub = L["Still to learn at the class trainer"] },
            { icon = 136243, name = L["Sample dungeon"], sub = L["Dungeon unlocked"] },
        })
    end,
    Stop = function()
        demo = false
        if frame then frame:Hide() end
    end,
    IsActive = function() return demo end,
}
