-- Layouts (Benny 2026-11-07): Ein Layout legt fest, WO die Teile sitzen und was rollenabhängig
-- ist. Es ist eine Einstellung im Profil (ns.db.layout) – ein Profil speichert also, was man sich
-- eingestellt hat, und welches Layout es nutzt. Nahkampf-DPS ist die Basis; weitere Layouts (Tank,
-- Fernkampf, Heiler) ändern nur, was bei ihnen anders ist – über Schalter (flags), die die Module
-- abfragen: ns.LayoutFlag("…"). Wechsel ohne Neuladen: alle Plätze laufen über ns.OnLayout.
local _, ns = ...
local L = ns.L

ns.LAYOUTS = {
    {
        id = "melee", name = L["Melee DPS"],
        flags = {
            questlogAboveFocus = true,    -- Questlog endet über dem Fokus (16:9: sonst überlappt er)
            questlogUnderBosses = true,   -- liegen Bossframes auf dem Questlog (16:9): es rückt darunter, nur Instanz-Quests
        },
    },
    {
        id = "ranged", name = L["Ranged DPS"],
        flags = {
            questlogAboveFocus = true,
            questlogUnderBosses = true,
            castbarAboveBars = true,      -- große Zauberleiste über den unteren Leisten (nicht im Spielerframe)
        },
    },
    {
        id = "tank", name = L["Tank"],
        flags = {
            questlogAboveFocus = true,
            questlogUnderBosses = true,
            tank = true,                  -- Bedrohung: Vorsprung vor dem Zweiten; Plaketten: rot = Aggro verloren
            bigDebuffs = true,            -- eigene Debuffs größer (Begleiter rutscht tiefer; braucht Neuladen)
        },
    },
    {
        id = "healer", name = L["Healer"],
        flags = {
            questlogAboveFocus = true,
            questlogUnderBosses = true,
            healerGroups = true,          -- Gruppe 5–40 mittig zwischen Spieler und Ziel (braucht Neuladen)
            healPrediction = true,        -- Heil-Vorhersage in den Gruppenframes
            healerBars = true,            -- Hauptleiste als 12er-Reihe unten über Alt/Shift, Haltung links daneben
            castbarAboveBars = true,      -- große Zauberleiste über den unteren Leisten (wie Fernkampf)
        },
    },
}

local byId = {}
for _, layout in ipairs(ns.LAYOUTS) do byId[layout.id] = layout end

function ns.CurrentLayout()
    return byId[ns.db and ns.db.layout] or byId[ns.DEFAULT_LAYOUT]
end

function ns.LayoutFlag(flag)
    return ns.CurrentLayout().flags[flag] == true
end

-- Leisten-Anordnung „Gestapelt“: Hauptleiste als 12er-Reihe unten über Alt/Shift (wie Heiler).
-- Heiler immer; sonst Einstellung ns.db.barVariant ("center" = Mittig 2×6, "stacked"). Greift beim Aufbau.
function ns.StackedBars()
    return ns.LayoutFlag("healerBars") or ns.db.barVariant == "stacked"
end

-- Wo Schlagtimer/Bedrohungsleiste beginnen: unter der Hauptleiste (Oberkante, Breite). Gestapelt
-- sitzt die Hauptleiste unten – dann dort, wo sie bei „Mittig“ wäre (Oberkante der Unitframes).
function ns.BelowMainBar(gap)
    local main = ns.actionBars and ns.actionBars[1]
    if not (main and main:GetBottom()) then return end
    local _, cy = UIParent:GetCenter()
    if ns.StackedBars() then
        local player = ns.frames and ns.frames.player
        local top = player and player:GetTop() and (player:GetTop() - cy) or -ns.Snap(ns.FRAME_TOP_Y)
        return top, ns.Snap(ns.MainBarWidth())
    end
    return main:GetBottom() - cy - gap, ns.Snap(main:GetWidth())
end

-- Neu ausrichten (Plätze, Questlog-Ausblenden); im Kampf erst danach
function ns.ApplyLayout()
    if ns.Relayout then ns.Relayout() end
    if ns.UpdateQuestlogHiding then ns.UpdateQuestlogHiding() end
    if ns.ClampQuestlogHeight then ns.ClampQuestlogHeight() end
end

function ns.SetLayout(id)
    if not byId[id] then return end
    ns.db.layout = id
    ns.ApplyLayout()
end

-- Heiler-Layout (Benny 2026-11-07, Skizze „Spielwiese Heiler“): Maße an einer Stelle, alle Module
-- (Leisten, Unitframes, Gruppe, Klassenleiste, Bedrohung, Schlagtimer) rechnen damit. Von unten:
--   3 Leisten à 12 (Shift, Alt, Hauptleiste) > große Zauberleiste > Gruppe (4 Reihen) > darüber
--   Bedrohung/Schlagtimer/Klassenleiste; Spieler und Ziel links/rechts der Gruppe, oben bündig.
ns.HEALER = {
    barSize = 36,      -- wie die Zusatzleisten
    castHeight = 32, castGap = 6,
    groupGap = 10,     -- Zauberleiste > Gruppe
    frameH = 61, rows = 4, gap = 4,
    groupWidth = 551,  -- 5 × 107 bzw. 10 × 51 samt Abständen
    sideGap = 32,      -- Gruppe > Spieler/Ziel (Platz für die Reagenzien neben dem Spieler)
}
function ns.HealerGeometry()
    local H = ns.HEALER
    local px = ns.PixelSize()
    local barGap = ns.MAIN_BAR.gapPixels * px
    local bottom = (UIParent:GetBottom() or 0) + ns.Snap(ns.SCREEN_MARGIN)
    local barsTop = bottom + 3 * ns.Snap(H.barSize) + 2 * barGap
    local castTop = barsTop + ns.Snap(H.castGap) + ns.Snap(H.castHeight)
    local groupBottom = castTop + ns.Snap(H.groupGap)
    local groupHeight = H.rows * ns.Snap(H.frameH) + (H.rows - 1) * ns.Snap(H.gap)
    local width = ns.Snap(H.groupWidth)
    return {
        groupTop = groupBottom + groupHeight, groupBottom = groupBottom, groupWidth = width,
        innerX = width / 2 + ns.Snap(H.sideGap), -- Abstand der Spieler-/Zielkante zur Mitte
    }
end
