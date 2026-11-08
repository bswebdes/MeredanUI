-- Combat text: restyles Blizzard's floating combat text in the mUI font instead of drawing our own
-- (addons may not read the combat log or compute damage in instances on Midnight/Forever).
--   - Numbers over enemies: DAMAGE_TEXT_FONT - read only at startup (needs a restart).
--   - Text over the player: CombatTextFont - applies immediately.
-- The toggles in Settings > Combat Text are Blizzard's own CVars, just gathered in one place.
local ADDON_NAME, ns = ...

local function Enabled() return ns.db ~= nil end -- always on

local function ApplyCombatTextFont()
    if not Enabled() or not CombatTextFont then return end
    local _, size = CombatTextFont:GetFont()
    CombatTextFont:SetFont(ns.STYLE.font or ns.DEFAULT_FONT, size or 25, "OUTLINE")
    CombatTextFont:SetShadowOffset(0, 0)
end
ns.ApplyCombatTextFont = ApplyCombatTextFont

-- Numbers over enemies: must be set before entering the world (ADDON_LOADED is early enough)
ns:On("ADDON_LOADED", function(_, name)
    if name == ADDON_NAME and Enabled() then DAMAGE_TEXT_FONT = ns.DEFAULT_FONT end
    -- Blizzard_CombatText loads on demand and sets its own font then
    if name == "Blizzard_CombatText" then ApplyCombatTextFont() end
end)
ns:On("PLAYER_LOGIN", ApplyCombatTextFont)

function ns.HasCVar(name) return GetCVar(name) ~= nil end
