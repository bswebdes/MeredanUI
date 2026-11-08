-- Ruhe auf dem Bildschirm (Einstellungen > Look > Meldungen):
--   • Kampf-Fehlermeldungen („Nicht genug Energie“, „Außer Reichweite“, „Noch nicht bereit“ …) samt
--     Ton; alle anderen Meldungen bleiben. Die Sprachausgabe regelt Blizzards eigene Einstellung.
--   • Talking Head (sprechender NPC-Kopf mit Text): unsichtbar (samt 3D-Kopf) und nicht anklickbar, die Stimme läuft
--     weiter (Benny, 2026-10-24 – vorher sofort geschlossen, dann fehlten NPC-Stimmen, auch in
--     Zwischensequenzen im Spiel). Blizzard schließt das Fenster nach der Zeile selbst.
local _, ns = ...

-- Ohne Blizzards Ereignis fehlten auch die Geräusche, die an manchen Meldungen hängen (z. B. beim
-- Zähmen, Benny 2026-11-06). Wir spielen sie selbst ab – nur Text und Stimme bleiben still.
-- Nur der Kampf-Lärm wird ausgeblendet (Benny 2026-11-07: „keine Energie“, „außer Reichweite“ beim
-- Tastendrücken nervt – alle anderen Meldungen wie „Taschen voll“ müssen bleiben). Vorher war
-- UI_ERROR_MESSAGE komplett abgemeldet: dann fehlten auch wichtige Meldungen.
-- Erkennung über Blizzards Kennung (GetGameMessageInfo → z. B. "ERR_OUT_OF_ENERGY"), sprachunabhängig.
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
-- dieselben als Zahlen (LE_GAME_ERR_…), falls GetGameMessageInfo keinen Namen liefert
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
    -- früher abgemeldet – immer wieder anmelden, damit wichtige Meldungen kommen
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
    if not hooked and UIErrorsFrame.ShouldDisplayMessageType then
        hooked = true
        local original = UIErrorsFrame.ShouldDisplayMessageType
        UIErrorsFrame.ShouldDisplayMessageType = function(self, messageType, message)
            if IsNoise(messageType) then return false end -- kein Text, keine Stimme, kein Ton
            return original(self, messageType, message)
        end
    end
    -- Sprachausgabe („Ich habe keine Energie“) regelt Blizzards eigene Einstellung
    -- (Audio > Fehler-Sprachausgabe) – mUI fasst sie nicht an (Benny 2026-11-07)
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
            -- Der Kopf ist ein 3D-Modell, das die Transparenz des Fensters ignoriert > selbst
            -- verstecken (Blizzard zeigt es nie wieder an; die Stimme kommt per PlaySound)
            local model = self.MainFrame and self.MainFrame.Model
            if model then model:SetShown(not hidden) end
        end
        hooksecurefunc(head, "PlayCurrent", Hide)
        head:HookScript("OnShow", Hide)
    end
end)

