-- Screen noise reduction (Settings > Look > Messages):
--   - Combat error messages ("Not enough energy", "Out of range" ...) incl. sound; all other messages stay.
--   - Talking Head: invisible (incl. 3D model) and click-through, but the voice keeps playing.
--     Don't close it: that also cuts NPC voice lines (incl. in-game cutscenes).
local _, ns = ...

-- Only combat noise is filtered; important messages ("Inventory is full") must stay. Never unregister
-- UI_ERROR_MESSAGE entirely - that drops important messages and sounds attached to some (e.g. taming).
-- Matched by Blizzard's message key (GetGameMessageInfo -> "ERR_OUT_OF_ENERGY"), locale-independent.
local COMBAT_NOISE = {}
for _, key in ipairs({
    "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_RAGE", "ERR_OUT_OF_FOCUS", "ERR_OUT_OF_MANA", "ERR_OUT_OF_RUNIC_POWER",
    "ERR_OUT_OF_HOLY_POWER", "ERR_OUT_OF_COMBO_POINTS", "ERR_OUT_OF_RANGE", "ERR_SPELL_OUT_OF_RANGE",
    "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN", "ERR_ITEM_COOLDOWN", "ERR_NO_ATTACK_TARGET",
    "ERR_GENERIC_NO_TARGET", "ERR_INVALID_ATTACK_TARGET", "ERR_BADATTACKFACING", "ERR_BADATTACKPOS",
    "ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS", "ERR_SPELL_FAILED_NOT_READY", "ERR_SPELL_FAILED_UNIT_NOT_INFRONT",
    "ERR_SPELL_FAILED_MOVING", "ERR_NOT_WHILE_MOVING", "ERR_AUTOFOLLOW_TOO_FAR", "ERR_ATTACK_PACIFIED",
    "ERR_ATTACK_STUNNED", "ERR_ATTACK_CHARMED", "ERR_ATTACK_CONFUSED", "ERR_ATTACK_FLEEING",
    "ERR_SPELL_FAILED_NO_COMBO_POINTS", "ERR_USE_TOO_FAR", "ERR_TOO_FAR_TO_INTERACT",
}) do COMBAT_NOISE[key] = true end
-- Same as numeric types (LE_GAME_ERR_...), in case GetGameMessageInfo returns no name
local NOISE_TYPES = {}
for key in pairs(COMBAT_NOISE) do
    local id = _G["LE_GAME_" .. key]
    if id then NOISE_TYPES[id] = true end
end

local function IsNoise(messageType)
    if ns.db.hideErrors == false then return false end
    if NOISE_TYPES[messageType] then return true end
    local name = GetGameMessageInfo and GetGameMessageInfo(messageType)
    return name ~= nil and COMBAT_NOISE[name] == true
end

local hooked
function ns.ApplyErrorMessages()
    if not UIErrorsFrame then return end
    -- Re-register in case an older version unregistered it
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    if not hooked and UIErrorsFrame.ShouldDisplayMessageType then
        hooked = true
        local original = UIErrorsFrame.ShouldDisplayMessageType
        UIErrorsFrame.ShouldDisplayMessageType = function(self, messageType, message)
            if IsNoise(messageType) then return false end -- no text, no voice, no sound
            return original(self, messageType, message)
        end
    end
    -- Error speech is left to Blizzard's own setting (Audio > Error Speech); clear the legacy flag
    ns.db.errorSpeechByUs = nil
end

ns:On("PLAYER_LOGIN", function()
    ns.ApplyErrorMessages()
    local head = TalkingHeadFrame
    if head and head.PlayCurrent then
        local function Hide(self)
            local hidden = ns.db.hideTalkingHead ~= false
            self:SetAlpha(hidden and 0 or 1)
            self:EnableMouse(not hidden)
            -- The head is a 3D model that ignores frame alpha, so hide it directly
            -- (Blizzard never re-shows it; the voice comes via PlaySound)
            local model = self.MainFrame and self.MainFrame.Model
            if model then model:SetShown(not hidden) end
        end
        hooksecurefunc(head, "PlayCurrent", Hide)
        head:HookScript("OnShow", Hide)
    end
end)

