-- Learned spells on the bars (Forever, Comfort):
--   autoSpellRanks:  a new rank replaces the previous highest rank on your bars. Only that rank:
--                    an older rank you keep on purpose (downranking heals) stays where it is.
--   autoPlaceSpells: a brand new spell goes to the first free slot of the visible mUI bars (main
--                    bar first, then the others in order), with a short glow. Passives and the
--                    General tab are skipped; a toast says so when every slot is taken.
-- Bars can only change out of combat and with an empty cursor: work waits for both.
-- SpellRanks.lua keeps marking old ranks; with autoSpellRanks it no longer toasts about them.
local _, ns = ...
if not ns.IS_FOREVER then return end
local L = ns.L

local MAX_ACTION_SLOT = 180
local GOLD = { 1, 0.82, 0 }
local queue = {} -- learned spells waiting: { id, line }
local scheduled
local ready = false -- loading screens can report spells as learned: only listen once settled

local function RanksOn() return ns.db.autoSpellRanks ~= false end
local function PlaceOn() return ns.db.autoPlaceSpells ~= false end

-- same-name spells of the player's class tabs in spellbook order (ranks ascend)
local function Ranks(name)
    local list = {}
    for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
        if line and not line.shouldHide then
            for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
                if info and info.spellID and info.name == name and info.itemType == Enum.SpellBookItemType.Spell then
                    list[#list + 1] = info.spellID
                end
            end
        end
    end
    return list
end

local function IsLowRank(id)
    local slot, bank = C_SpellBook.FindSpellBookSlotForSpell(id, false, false, false, false)
    return slot and C_SpellBook.IsSpellBookItemLowRank and C_SpellBook.IsSpellBookItemLowRank(slot, bank) or false
end

local function Place(id, slot)
    C_Spell.PickupSpell(id)
    if GetCursorInfo() ~= "spell" then ClearCursor() return false end
    PlaceAction(slot)
    ClearCursor()
    return true
end

-- the button currently showing a slot glows briefly (mUI hides Blizzard's "new" marker)
local function Glow(slot)
    for _, bar in ipairs(ns.actionBars or {}) do
        for _, button in ipairs(bar.buttons) do
            if button._state_type == "action" and button._state_action == slot then
                if not button.muiNewGlow then
                    local glow = button:CreateTexture(nil, "OVERLAY", nil, 6)
                    glow:SetPoint("TOPLEFT", -6, 6)
                    glow:SetPoint("BOTTOMRIGHT", 6, -6)
                    glow:SetTexture(ns.MEDIA .. "SoftGlow")
                    glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
                    glow:SetBlendMode("ADD")
                    glow:Hide()
                    local anim = glow:CreateAnimationGroup()
                    local fade = anim:CreateAnimation("Alpha")
                    fade:SetFromAlpha(1)
                    fade:SetToAlpha(0.15)
                    fade:SetDuration(0.5)
                    anim:SetLooping("BOUNCE")
                    local loops = 0
                    anim:SetScript("OnLoop", function(self)
                        loops = loops + 1
                        if loops >= 6 then self:Stop() glow:Hide() end
                    end)
                    button.muiNewGlow = { glow = glow, anim = anim, reset = function() loops = 0 end }
                end
                local g = button.muiNewGlow
                g.reset()
                g.glow:Show()
                g.anim:Play()
            end
        end
    end
end

-- first empty slot a visible mUI button shows right now (main bar first, bars in their order)
local function FreeSlot()
    for _, bar in ipairs(ns.actionBars or {}) do
        if bar:IsVisible() then
            for _, button in ipairs(bar.buttons) do
                local slot = button._state_type == "action" and tonumber(button._state_action)
                if slot and not C_ActionBar.HasAction(slot) then return slot end
            end
        end
    end
end

local function OnBars(id)
    if C_ActionBar.FindSpellActionButtons then
        local slots = C_ActionBar.FindSpellActionButtons(id)
        if slots and #slots > 0 then return true end
    end
    for slot = 1, MAX_ACTION_SLOT do
        local kind, sid = GetActionInfo(slot)
        if kind == "spell" and sid == id then return true end
    end
    return false
end

local function RankNumber(id)
    local sub = C_Spell.GetSpellSubtext(id)
    return type(sub) == "string" and tonumber(sub:match("%d+")) or 0
end

-- fallback when the spellbook doesn't list the old ranks: the highest rank of that name on the bars
local function TopRankOnBars(name, except)
    local best, bestRank
    for slot = 1, MAX_ACTION_SLOT do
        local kind, sid = GetActionInfo(slot)
        if kind == "spell" and sid and sid ~= except and C_Spell.GetSpellName(sid) == name then
            local rank = RankNumber(sid)
            if not bestRank or rank > bestRank then best, bestRank = sid, rank end
        end
    end
    return best
end

local function Upgrade(old, new)
    local done = 0
    for slot = 1, MAX_ACTION_SLOT do
        local kind, sid = GetActionInfo(slot)
        if kind == "spell" and sid == old and Place(new, slot) then done = done + 1 end
    end
    return done
end

local function Handle(entry)
    local id = entry.id
    local name = C_Spell.GetSpellName(id)
    if not name or C_Spell.IsSpellPassive(id) then return end
    local ranks = Ranks(name)
    local previous
    for i, rid in ipairs(ranks) do
        if rid == id then previous = ranks[i - 1] break end
    end
    if not previous and #ranks > 0 and ranks[#ranks] ~= id then previous = ranks[#ranks] end
    previous = previous or TopRankOnBars(name, id)
    if previous and previous ~= id then
        -- a new rank: only when it really is the top one now
        if RanksOn() and not IsLowRank(id) then Upgrade(previous, id) end
        return
    end
    if not PlaceOn() or OnBars(id) then return end
    -- only the class tabs (General holds racials, professions and the like)
    local line = entry.line and C_SpellBook.GetSpellBookSkillLineInfo(entry.line)
    if not line or entry.line == 1 or line.offSpecID or line.shouldHide then return end
    local slot = FreeSlot()
    if slot then
        if Place(id, slot) then Glow(slot) end
    elseif ns.AddToast then
        ns.AddToast({ title = L["Action bars"], text = L["No free slot for %s"]:format(name),
            icon = C_Spell.GetSpellTexture(id) or 136243, color = GOLD })
    end
end

local Process
Process = function()
    scheduled = false
    if #queue == 0 then return end
    if InCombatLockdown() then return ns.AfterCombat(Process) end
    if GetCursorInfo() then -- holding something: try again shortly
        scheduled = true
        C_Timer.After(1, Process)
        return
    end
    local list = queue
    queue = {}
    for _, entry in ipairs(list) do Handle(entry) end
    if ns.RefreshSpellRanks then ns.RefreshSpellRanks() end
end

ns:On("LEARNED_SPELL_IN_SKILL_LINE", function(_, id, line, isGuildPerk)
    if not ready or isGuildPerk or not id or not (RanksOn() or PlaceOn()) then return end
    queue[#queue + 1] = { id = id, line = line }
    -- the spellbook (ranks, low-rank flags) is only up to date a moment later; "train all"
    -- fires many events at once
    if not scheduled then
        scheduled = true
        C_Timer.After(1, Process)
    end
end)

ns:On("PLAYER_ENTERING_WORLD", function()
    ready = false
    C_Timer.After(10, function() ready = true end)
end)
ns:On("PLAYER_LEAVING_WORLD", function() ready = false end)
