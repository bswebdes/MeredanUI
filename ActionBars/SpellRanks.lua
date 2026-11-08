-- Spell ranks & trainer (Forever): subtle reminders via toasts.
--   - Rank watcher: if an action bar holds a lower rank of a spell you know a higher rank of,
--     show ONE toast ("2 spells ... higher rank - click: update") and a small gold arrow on
--     the button. Clicking the toast swaps the ranks (out of combat only, with an empty cursor).
--   - Trainer: on level-up, ONE toast if new spells await at the trainer (future spells in the
--     spellbook whose level you have reached).
-- Retail has no ranks, so the module stays off there.
local _, ns = ...
local L = ns.L

local MAX_ACTION_SLOT = 180
local MARK_SIZE = 16 -- badge (arrow inside is 12 px)
local GOLD = { 1, 0.82, 0 }

local lowSlots = {}  -- action slot -> spell ID of the highest rank
local toastedFor = {} -- slot -> spell already reminded about (don't repeat constantly)

local function RanksEnabled() return ns.db.spellRanks ~= false and ns.IS_FOREVER end
local function TrainerEnabled() return ns.db.trainerReminder ~= false and ns.IS_FOREVER end

-- highest known rank of a spell (same name, not a "lower rank")
local function HighestRank(spellID)
    local name = C_Spell.GetSpellName(spellID)
    if not name then return end
    local slot, bank = C_SpellBook.FindSpellBookSlotForSpell(spellID, false, false, false, false)
    if not slot or not C_SpellBook.IsSpellBookItemLowRank(slot, bank) then return end
    -- search the spellbook for the same name that isn't a lower rank
    for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
        if line then
            for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
                if info and info.spellID and info.name == name and info.itemType == Enum.SpellBookItemType.Spell
                    and not C_SpellBook.IsSpellBookItemLowRank(i, Enum.SpellBookSpellBank.Player) then
                    return info.spellID
                end
            end
        end
    end
end

-- check all action slots
local function Scan()
    wipe(lowSlots)
    if not RanksEnabled() then return 0 end
    local count = 0
    for slot = 1, MAX_ACTION_SLOT do
        local kind, id = GetActionInfo(slot)
        if kind == "spell" and id then
            local best = HighestRank(id)
            if best and best ~= id then
                lowSlots[slot] = best
                count = count + 1
            end
        end
    end
    return count
end

-- small gold arrow top left on affected MUI buttons (keybind is on the right)
local function UpdateMarks()
    for _, bar in ipairs(ns.actionBars or {}) do
        for _, button in ipairs(bar.buttons) do
            local slot = button._state_type == "action" and button._state_action
            local low = type(slot) == "number" and lowSlots[slot]
            if low and not button.muiRankMark then
                -- small badge: dark tile, gold 1 px border, gold arrow - visible on any icon
                -- (keybind sits top right)
                local mark = CreateFrame("Frame", nil, button)
                mark:SetSize(ns.Snap(MARK_SIZE), ns.Snap(MARK_SIZE))
                mark:SetPoint("TOPLEFT", 1, -1)
                mark:SetFrameLevel(button:GetFrameLevel() + 5)
                local bg = mark:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, 0.85)
                for _, edge in ipairs(ns.AddBorder(mark, true)) do edge:SetVertexColor(unpack(GOLD)) end
                local arrow = ns.UI.Icon(mark, "RankUp", MARK_SIZE - 4, GOLD)
                arrow:SetPoint("CENTER")
                button.muiRankMark = mark
            end
            if button.muiRankMark then button.muiRankMark:SetShown(low and true or false) end
        end
    end
end

-- replace old ranks on the bars with the highest one (out of combat only)
local function UpgradeAll()
    if InCombatLockdown() then
        ns.Print(L["Not possible in combat."])
        return
    end
    if GetCursorInfo() then return end -- cursor must be empty
    local done = 0
    for slot, best in pairs(lowSlots) do
        C_Spell.PickupSpell(best)
        if GetCursorInfo() == "spell" then
            PlaceAction(slot)
            ClearCursor()
            done = done + 1
        end
    end
    ClearCursor()
    if done > 0 then ns.Print(L["Updated %d spells to their highest rank."], done) end
end

local function Refresh(announce)
    local count = Scan()
    UpdateMarks()
    if not announce or count == 0 or not ns.AddToast then return end
    -- only remind when something is NEWLY outdated (not the same thing on every reload)
    local fresh = false
    for slot, best in pairs(lowSlots) do
        if toastedFor[slot] ~= best then fresh = true end
        toastedFor[slot] = best
    end
    if not fresh then return end
    ns.AddToast({
        key = "spellranks", title = L["Spell ranks"] .. " · " .. L["Click: update"],
        text = L["%d spells on your bars have a higher rank"]:format(count),
        icon = 136243, color = GOLD,
        onClick = UpgradeAll,
    })
end

-- Trainer: future spells whose level has been reached
local function TrainerSpells()
    local level, count = UnitLevel("player"), 0
    for index = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(index)
        if line and not line.offSpecID and not line.shouldHide then
            for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(i, Enum.SpellBookSpellBank.Player)
                if info and info.itemType == Enum.SpellBookItemType.FutureSpell then
                    local needed = C_SpellBook.GetSpellBookItemLevelLearned(i, Enum.SpellBookSpellBank.Player)
                    if needed and needed > 0 and needed <= level then count = count + 1 end
                end
            end
        end
    end
    return count
end

ns:On("PLAYER_LEVEL_UP", function()
    if not TrainerEnabled() then return end
    -- the spellbook is only up to date a moment after leveling
    C_Timer.After(2, function()
        local count = TrainerSpells()
        if count > 0 and ns.AddToast then
            ns.AddToast({ title = L["Class trainer"], text = L["New spells to learn: %d"]:format(count),
                icon = 136243, color = { 1, 0.82, 0 } })
        end
    end)
end)

-- newly learned (trainer) -> check and maybe remind; bars changed -> only refresh arrows
local pending
local function Request(announce)
    if pending then return end
    pending = true
    C_Timer.After(0.5, function() pending = false; Refresh(announce) end)
end

ns:On("PLAYER_LOGIN", function()
    if not ns.IS_FOREVER then return end
    C_Timer.After(2, function()
        -- on login just mark silently and remember (no reminder on every login)
        Refresh(false)
        for slot, best in pairs(lowSlots) do toastedFor[slot] = best end
    end)
    ns:On("LEARNED_SPELL_IN_SKILL_LINE", function() Request(true) end)
    ns:On("SPELLS_CHANGED", function() Request(true) end)
    ns:On("ACTIONBAR_SLOT_CHANGED", function() Request(false) end)
end)

ns.RefreshSpellRanks = function() Refresh(false) end
