-- Hinweise bewusst kurz (Stichwort, der Ring zeigt die Stelle; Benny 2026-11-08).
-- Außen-Eingänge von Instanzen, deren Portal versteckt liegt (Höhle, Berg, Gebäude) – für die gepunktete
-- Linie auf der Weltkarte (Map/MapExtras.lua). [Instanz-Map] = { { uiMapID, x, y (0–1), Hinweis }, … }
-- Quellen (Recherche 2026-11-08): HandyNotes_DungeonLocations (Classic, forever.lua – gleiche Werte wie
-- Vanilla), warcraft.wiki.gg, Zockify/MMONerds (Uldaman). Umgerechnete Kontinentwerte sind ±1–2 genau;
-- Maraudon ist am unsichersten (Quellen widersprechen sich) – im Spiel prüfen.
local _, ns = ...
local L = ns.L

ns.DUNGEON_APPROACHES = {
    [43] = { { 1413, 0.4597, 0.3634, L["Cave above oasis"] } },                -- Höhlen des Wehklagens
    [36] = { { 1436, 0.4257, 0.7171, L["Moonbrook mine"] } },         -- Todesminen
    [48] = { { 1440, 0.1400, 0.1310, L["Shore ruins"] } },           -- Tiefschwarze Grotte
    [90] = { { 1426, 0.2446, 0.3981, L["Gate"] } },                  -- Gnomeregan
    [47] = { { 1413, 0.4189, 0.8950, L["Thorn thicket"] } },          -- Kral der Klingenhauer
    [129] = { { 1413, 0.4913, 0.9348, L["Thorn hill"] } },  -- Hügel der Klingenhauer
    [70] = {                                                                       -- Uldaman
        { 1418, 0.4453, 0.1212, L["Front entrance"] },
        { 1418, 0.6505, 0.4337, L["Back entrance"] },
    },
    [189] = { { 1420, 0.8530, 0.3220, L["Courtyard"] } },    -- Scharlachrotes Kloster
    [349] = {                                                                      -- Maraudon (unsicher)
        { 1443, 0.2910, 0.6250, L["Stone door"] },
        { 1443, 0.3016, 0.5462, L["Purple"] },
        { 1443, 0.3600, 0.6430, L["Orange"] },
    },
    [429] = {                                                                      -- Düsterbruch
        { 1444, 0.5911, 0.4328, L["Path up"] },
        { 1444, 0.7706, 0.3695, L["Back door (key)"] },                  -- Tunnel unter dem Lariss-Pavillon
    },
    [109] = { { 1435, 0.6950, 0.5250, L["Temple in the lake"] } },           -- Versunkener Tempel
    [329] = {                                                                      -- Stratholme
        { 1423, 0.2930, 0.1680, L["Main gate"] },                  -- Benny 2026-11-08: Brücke weiter links
        { 1423, 0.4300, 0.1800, L["Side gate (key)"] },
    },
    [389] = { { 1454, 0.5240, 0.5800, L["Cleft of Shadow"] } },      -- Ragefireabgrund
    [249] = { { 1445, 0.5290, 0.7770, L["Cave"] } },                    -- Onyxias Hort
}
-- Schwarzfels: Schwarzfelstiefen, -spitze, Geschmolzener Kern, Pechschwingenhort teilen die Zugänge
local BLACKROCK = {
    { 1427, 0.3470, 0.8600, L["Blackrock Mountain"] },
    { 1428, 0.2994, 0.4778, L["Blackrock Mountain"] },
}
for _, id in ipairs({ 229, 230, 409, 469 }) do ns.DUNGEON_APPROACHES[id] = BLACKROCK end
