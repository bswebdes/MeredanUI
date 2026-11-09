-- Fast loot: when auto loot is active (or toggled via modifier), take all loot immediately
-- without waiting for the loot window. Settings > Bags.
local _, ns = ...

local lastLoot = 0

ns:On("LOOT_READY", function(_, autoLoot)
    if ns.db.fastLoot == false or not autoLoot then return end
    -- LOOT_READY sometimes fires twice per corpse
    local now = GetTime()
    if now - lastLoot < 0.2 then return end
    lastLoot = now
    if ns.Fishing and ns.Fishing.Capture then ns.Fishing.Capture() end -- before the slots empty
    for slot = GetNumLootItems(), 1, -1 do LootSlot(slot) end
end)
