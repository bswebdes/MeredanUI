-- Schnelles Plündern: Ist automatisches Plündern aktiv (bzw. per Taste umgeschaltet), sammelt MUI
-- die Beute sofort ein – ohne auf das Beutefenster zu warten. Einstellungen > Taschen.
local _, ns = ...

local lastLoot = 0

ns:On("LOOT_READY", function(_, autoLoot)
    if ns.db.fastLoot == false or not autoLoot then return end
    -- LOOT_READY kommt pro Leiche manchmal doppelt
    local now = GetTime()
    if now - lastLoot < 0.2 then return end
    lastLoot = now
    for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end)
