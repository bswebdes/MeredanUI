-- Small notices (Settings > Notifications):
--   - Durability: warn once when the worst item drops below 20% (toast, or chat line if toasts
--     are off). Re-armed once everything is repaired.
--   - Screenshot on each new achievement (delayed so Blizzard's alert is in the picture).
local _, ns = ...
local L = ns.L

local WARN_BELOW = 0.2
local REPAIR_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local WARN_COLOR = { 0.95, 0.3, 0.25 }

local warned = false

local function LowestDurability()
    local lowest
    for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 19 do
        local current, maximum = GetInventoryItemDurability(slot)
        if current and maximum and maximum > 0 then
            local ratio = current / maximum
            if not lowest or ratio < lowest then lowest = ratio end
        end
    end
    return lowest
end

local function CheckDurability()
    local lowest = LowestDurability()
    if not lowest or lowest >= WARN_BELOW then
        warned = false
        return
    end
    if warned or ns.db.durabilityWarning == false then return end
    warned = true
    local text = L["Lowest item at %d %%"]:format(math.floor(lowest * 100 + 0.5))
    local toast = { title = L["Repair soon"], text = text, icon = REPAIR_ICON, color = WARN_COLOR }
    if not ns.AddToast(toast) then ns.Print(L["Repair soon"] .. ": " .. text) end
end

-- Fires once per item -> batch the check
local pending = false
ns:On("UPDATE_INVENTORY_DURABILITY", function()
    if pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        CheckDurability()
    end)
end)

ns:On("ACHIEVEMENT_EARNED", function()
    if ns.db.achievementScreenshot == false then return end
    -- Forever does not expose Screenshot() to addons (nil)
    if type(Screenshot) ~= "function" then return end
    C_Timer.After(1, function() Screenshot() end)
end)
