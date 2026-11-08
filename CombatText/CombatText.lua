-- Kampftext: Blizzards eigener schwebender Kampftext (Zahlen über Gegnern, Text über dir) in der
-- MUI-Schrift. Selbst gezeichnet wird nichts: Addons dürfen in Instanzen weder das Kampflog lesen
-- noch Schadenswerte rechnen (Midnight/Forever) – Blizzards Text funktioniert dagegen überall.
--   • Zahlen über Gegnern: DAMAGE_TEXT_FONT – liest das Spiel nur beim Start (Neustart nötig).
--   • Text über dir: CombatTextFont – sofort.
-- Die Schalter (Einstellungen > Kampftext) sind Blizzards eigene Werte (wie Optionen > Gameplay →
-- Kampf), nur an einer Stelle gesammelt.
local ADDON_NAME, ns = ...

local function Enabled() return ns.db ~= nil end -- fest an (früher Schalter)

local function ApplyCombatTextFont()
    if not Enabled() or not CombatTextFont then return end
    local _, size = CombatTextFont:GetFont()
    CombatTextFont:SetFont(ns.STYLE.font or ns.DEFAULT_FONT, size or 25, "OUTLINE")
    CombatTextFont:SetShadowOffset(0, 0)
end
ns.ApplyCombatTextFont = ApplyCombatTextFont

-- Zahlen über Gegnern: muss vor dem Betreten der Welt gesetzt sein (ADDON_LOADED reicht)
ns:On("ADDON_LOADED", function(_, name)
    if name == ADDON_NAME and Enabled() then DAMAGE_TEXT_FONT = ns.DEFAULT_FONT end
    -- Blizzards Kampftext lädt erst bei Bedarf und setzt dabei seine Schrift
    if name == "Blizzard_CombatText" then ApplyCombatTextFont() end
end)
ns:On("PLAYER_LOGIN", ApplyCombatTextFont)

function ns.HasCVar(name) return GetCVar(name) ~= nil end
