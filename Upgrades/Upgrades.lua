-- Upgrade-Bewertung („Mini-Pawn“): schätzt, wie viel mehr oder weniger Schaden ein Item
-- gegenüber dem angelegten bringt, für die aktive Spec. Tooltip: „+2,4 %“ grün bzw. „−1,1 %“ rot;
-- Tasche: grüner Pfeil auf Upgrades. Nichts einzustellen – alles automatisch:
--   • Sekundärwerte: Bloodmallet-Sims (UpgradeData.lua), ausgewertet an DEINER aktuellen
--     Aufteilung – zu viel von einem Wert bringt also weniger.
--   • Wie viel ein Punkt Sekundärwertung insgesamt bringt, kommt aus deinen echten Werten
--     (Prozent je Wertung, aktuelle Prozente); Hauptattribut: 1 / dein Hauptattribut.
--   • Schmuck mit Effekt: simulierter Zugewinn je Itemlevel statt nur der Werte.
--   • Ringe/Schmuck gegen den schwächeren der beiden; Zweihand gegen Haupt- + Nebenhand.
--   • Nur Items, die deine Spec laut Blizzard tragen kann (Rüstungstyp, Attribut, Waffe).
-- Sockel und Verzauberungen zählen nicht (beide Seiten gleich behandelt).
local _, ns = ...
local L = ns.L

local DATA = ns.UPGRADE_DATA
local Readable = ns.Readable
local STATS = { "crit", "haste", "mastery", "vers" }
-- Wertungs-Indizes (CR_CRIT_MELEE, CR_HASTE_MELEE, CR_MASTERY, CR_VERSATILITY_DAMAGE_DONE)
local RATINGS = { crit = 9, haste = 18, mastery = 26, vers = 29 }
local ITEM_STATS = {
    crit = "ITEM_MOD_CRIT_RATING_SHORT", haste = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT", vers = "ITEM_MOD_VERSATILITY",
}
local PRIMARY = { [1] = "STRENGTH", [2] = "AGILITY", [4] = "INTELLECT" }
local GRID_MIN, GRID_MAX = 0.1, 0.7 -- Bloodmallet simuliert 10–70 % je Wert
local EPS = 0.01
local GREEN = { 0.25, 0.9, 0.35 }
local RED = { 1, 0.3, 0.3 }
ns.UPGRADE_COLOR = GREEN

local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
}
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local OFF_HAND = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
local MAIN_HAND, OFF_HAND_SLOT = 16, 17

-- Forever bewertet ForeverPawn.lua (eigene Gewichte); dieser Teil hier rechnet nur für Retail
-- Modus: "damage" = % mehr Gesamtschaden (Standard), "item" = % besser als das angelegte Item
-- (wie Pawn), "off" (alte Häkchen-Werte true/false werden mit übersetzt)
function ns.UpgradeMode()
    local mode = ns.db and ns.db.upgrades
    if mode == false or mode == "off" then return "off" end
    return mode == "item" and "item" or "damage"
end
local function Enabled() return ns.UpgradeMode() ~= "off" and not ns.IS_FOREVER end

local weights   -- Wert je Punkt als Anteil mehr Schaden, für die aktive Spec
local scores = {} -- Link > Wert

-- Bloodmallet-Polynom: DPS (Anteil der Basis-DPS) bei Anteilen x = { Krit, Tempo, Meisterschaft }
local function Poly(fit, x)
    local sum = 0
    for i, term in ipairs(DATA.terms) do
        local v = fit[i]
        for _, k in ipairs(term) do v = v * x[k] end
        sum = sum + v
    end
    return sum
end

local function Clamp(v) return math.min(math.max(v, GRID_MIN), GRID_MAX) end

-- Durchschnittlicher Wert eines Punkts Sekundärwertung: Prozent je Wertung (mit abnehmendem
-- Nutzen) geteilt durch das, was der Wert schon bringt. Meisterschaft ist je Spec anders und
-- bleibt deshalb außen vor – ihr Unterschied zu den anderen kommt aus den Sims.
local function MeanRatingValue()
    local melee, spell, haste = GetCritChance(), GetSpellCritChance(), GetHaste()
    -- im Kampf teils geschützt (Secrets): dann keine Aussage, später neu rechnen
    if not (Readable(melee) and Readable(spell) and Readable(haste)) then return nil end
    local current = {
        crit = math.max(melee or 0, spell or 0),
        haste = haste,
        vers = nil,
    }
    local versRating, versBonus = GetCombatRatingBonus(RATINGS.vers), GetVersatilityBonus(RATINGS.vers)
    if not (Readable(versRating) and Readable(versBonus)) then return nil end
    current.vers = (versRating or 0) + (versBonus or 0)
    local sum, count = 0, 0
    for stat, percent in pairs(current) do
        local rating = GetCombatRating(RATINGS[stat])
        if Readable(percent) and Readable(rating) and percent and rating then
            local from = GetCombatRatingBonusForCombatRatingValue(RATINGS[stat], rating)
            local to = GetCombatRatingBonusForCombatRatingValue(RATINGS[stat], rating + 100)
            if Readable(from) and Readable(to) and from and to then
                sum = sum + (to - from) / 100 / 100 / (1 + percent / 100)
                count = count + 1
            end
        end
    end
    return count > 0 and sum / count or nil
end

local function BuildWeights()
    local index = C_SpecializationInfo.GetSpecialization()
    if not index then return end
    local specID, _, _, _, _, primaryIndex = C_SpecializationInfo.GetSpecializationInfo(index)
    local _, primary = UnitStat("player", primaryIndex or 0)
    local mean = MeanRatingValue()
    if not (specID and PRIMARY[primaryIndex] and mean and Readable(primary) and primary > 0) then return end

    local w = { specID = specID, primaryKey = PRIMARY[primaryIndex], primary = 1 / primary }
    local spec = DATA.specs[specID]
    if spec then
        -- Steigung der Sims an deiner Aufteilung; Vielseitigkeit ist der Rest (fester Gesamtwert),
        -- deshalb nur Unterschiede zwischen den Werten – der Mittelwert kommt aus MeanRatingValue.
        local ratings, total = {}, 0
        for _, stat in ipairs(STATS) do
            local rating = GetCombatRating(RATINGS[stat])
            ratings[stat] = Readable(rating) and rating or 0
            total = total + ratings[stat]
        end
        local x = { 0.25, 0.25, 0.25 }
        if total > 0 then
            x = { Clamp(ratings.crit / total), Clamp(ratings.haste / total), Clamp(ratings.mastery / total) }
        end
        local slope = {}
        for k = 1, 3 do
            local up, down = { x[1], x[2], x[3] }, { x[1], x[2], x[3] }
            up[k], down[k] = x[k] + EPS, x[k] - EPS
            slope[k] = (Poly(spec.fit, up) - Poly(spec.fit, down)) / (2 * EPS)
        end
        local vers = -(slope[1] + slope[2] + slope[3]) / 4
        local deviation = { crit = slope[1] + vers, haste = slope[2] + vers, mastery = slope[3] + vers, vers = vers }
        for _, stat in ipairs(STATS) do
            w[stat] = math.max(mean + deviation[stat] / spec.total, 0)
        end
        w.trinkets = spec.trinkets
    else
        -- ohne Sims (Heiler u. a.): Verhältnis der Werte untereinander aus Pawn
        local _, _, classID = UnitClass("player")
        local ratio = DATA.fallback[classID .. "-" .. index]
        for _, stat in ipairs(STATS) do w[stat] = mean * (ratio and ratio[stat] or 1) end
    end
    weights = w
    wipe(scores)
    if DevLog then -- Dev-Hilfe: Gewichte relativ zum Hauptattribut (1 = so viel wie 1 Punkt Hauptattribut)
        DevLog("MeredanUI", ("Upgrade-Gewichte Spec %d (%s): Krit %.2f, Tempo %.2f, Meist. %.2f, Viels. %.2f"):format(
            specID, spec and "Bloodmallet" or "Pawn", w.crit / w.primary, w.haste / w.primary,
            w.mastery / w.primary, w.vers / w.primary))
    end
end

-- Simulierter Schmuck-Zugewinn bei einem Itemlevel (zwischen den Stufen linear, außerhalb
-- mit der Steigung der Randstufen weiter)
local function TrinketGain(byLevel, level)
    local levels = byLevel.sorted
    if not levels then
        levels = {}
        for l in pairs(byLevel) do if type(l) == "number" then levels[#levels + 1] = l end end
        table.sort(levels)
        byLevel.sorted = levels
    end
    if #levels == 1 then return byLevel[levels[1]] end
    local i = 1
    while i < #levels - 1 and level > levels[i + 1] do i = i + 1 end
    local a, b = levels[i], levels[i + 1]
    return byLevel[a] + (byLevel[b] - byLevel[a]) * (level - a) / (b - a)
end

-- Wert eines Items (Anteil mehr Schaden), nil = Daten noch nicht geladen
local function Score(link)
    if not link then return 0 end
    local cached = scores[link]
    if cached then return cached end
    local itemID = C_Item.GetItemInfoInstant(link)
    local level = C_Item.GetDetailedItemLevelInfo(link)
    local trinket = weights.trinkets and itemID and weights.trinkets[itemID]
    local score
    if trinket and level then
        score = TrinketGain(trinket, level)
    else
        ---@diagnostic disable-next-line: redundant-parameter
        local stats = C_Item.GetItemStats(link, {}) -- mit Tabelle wie Pawn
        if not stats then return nil end
        local primary = 0
        for key, value in pairs(stats) do
            if key:find(weights.primaryKey, 1, true) then primary = math.max(primary, value) end
        end
        score = primary * weights.primary
        for _, stat in ipairs(STATS) do score = score + (stats[ITEM_STATS[stat]] or 0) * weights[stat] end
    end
    scores[link] = score
    return score
end

local function Equipped(slot) return GetInventoryItemLink("player", slot) end

-- Schmuck mit Sim-Daten? Ohne Sims zählen nur die Werte, nicht der Effekt – dann wäre jeder
-- Vergleich mit einem simulierten Schmuckstück schief, also lieber keine Aussage.
local function Simulated(link)
    if not link then return true end -- leerer Platz
    local itemID = C_Item.GetItemInfoInstant(link)
    return weights.trinkets ~= nil and itemID ~= nil and weights.trinkets[itemID] ~= nil
end

local function EquipLoc(link)
    if not link then return end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    return equipLoc
end

-- Wert dessen, was das neue Item ersetzt (nil = nicht sinnvoll vergleichbar)
local function ReplacedScore(equipLoc, link)
    local slots = SLOTS[equipLoc]
    if slots then
        local worst
        for _, slot in ipairs(slots) do
            local current = Equipped(slot)
            if current == link then return end -- das ist das angelegte Item selbst
            local score = Score(current)
            if not score then return end
            worst = worst and math.min(worst, score) or score
        end
        return worst
    end
    local main, off = Equipped(MAIN_HAND), Equipped(OFF_HAND_SLOT)
    if link == main or link == off then return end
    local mainScore, offScore = Score(main), Score(off)
    if not (mainScore and offScore) then return end
    local mainIsTwoHand = TWO_HAND[EquipLoc(main)]
    if TWO_HAND[equipLoc] then return mainScore + offScore end
    if OFF_HAND[equipLoc] then
        if mainIsTwoHand then return end -- Nebenhand allein ersetzt keine Zweihand
        return offScore
    end
    if equipLoc == "INVTYPE_WEAPONMAINHAND" then return mainScore end
    if equipLoc == "INVTYPE_WEAPON" then
        -- Einhänder: beidhändig mit zwei Waffen > gegen die schwächere, sonst Haupthand
        if not mainIsTwoHand and off and CanDualWield() and not OFF_HAND[EquipLoc(off)] then
            return math.min(mainScore, offScore)
        end
        return mainScore
    end
end

local function UsableBySpec(link)
    local specs = C_Item.GetItemSpecInfo(link)
    if not specs or #specs == 0 then return true end -- ohne Einschränkung (Ringe, Hals …)
    for _, id in ipairs(specs) do
        if id == weights.specID then return true end
    end
    return false
end

-- Unterschied in Prozent (+ besser, − schlechter) je nach Modus; nil = keine Aussage
function ns.UpgradePercent(link)
    -- Forever: eigene Bewertung (ForeverPawn.lua), gleiche Anzeige
    if ns.IS_FOREVER then
        if ns.UpgradeMode() == "off" or not Readable(link) or not link then return end
        return ns.ForeverUpgradePercent and ns.ForeverUpgradePercent(link)
    end
    if not Enabled() or not Readable(link) or not link then return end
    if not weights then BuildWeights() end
    if not weights then return end
    local equipLoc = EquipLoc(link)
    if not equipLoc or equipLoc == "" or not (SLOTS[equipLoc] or TWO_HAND[equipLoc] or OFF_HAND[equipLoc]
        or equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND") then return end
    if not UsableBySpec(link) then return end
    if equipLoc == "INVTYPE_TRINKET" and not (Simulated(link) and Simulated(Equipped(13)) and Simulated(Equipped(14))) then
        return
    end
    local score = Score(link)
    if not score or score <= 0 then return end
    local replaced = ReplacedScore(equipLoc, link)
    if not replaced then return end
    if ns.UpgradeMode() == "item" then
        if replaced <= 0 then return end -- leerer Platz: kein sinnvoller Prozentwert
        return (score - replaced) / replaced * 100
    end
    return (score - replaced) * 100
end

-- Leere Ausrüstungsplätze (Benny 2026-11-08, beim Leveln oft): Items, die einen leeren Platz füllen
-- würden, bekommen in der Tasche eine Markierung und im Tooltip „Füllt leeren Platz: …“. Nur was du
-- tragen kannst (keine roten Tooltip-Zeilen: Klasse, Rüstungsart, Stufe). Hemd, Wappenrock, Munition
-- und Taschen zählen nicht; Nebenhand nur, wenn keine Zweihandwaffe in der Haupthand liegt.
local RANGED_TYPES = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true }
local rangedSlot
local function RangedSlot()
    if rangedSlot == nil then
        local ok, id = pcall(GetInventorySlotInfo, "RANGEDSLOT")
        rangedSlot = ok and id or false
    end
    return rangedSlot
end

-- Was jede Klasse überhaupt tragen kann (klassische Regeln; Benny 2026-11-08: Schurke bekam ein
-- Schild markiert). Rüstung (Klasse 4): 1 Stoff, 2 Leder, 3 Kette, 4 Platte, 6 Schild, 7 Buchband,
-- 8 Götze, 9 Totem – 0 (Schmuck, Ringe, Nebenhand-Gegenstände) darf jeder. Waffen (Klasse 2):
-- 0 Einhandaxt, 1 Zweihandaxt, 2 Bogen, 3 Gewehr, 4 Einhandstreitkolben, 5 Zweihandstreitkolben,
-- 6 Stangenwaffe, 7 Einhandschwert, 8 Zweihandschwert, 10 Stab, 13 Faustwaffe, 15 Dolch, 16 Wurfwaffe,
-- 18 Armbrust, 19 Zauberstab. Ob eine Stufe fehlt (Kette ab 40 …), prüft danach der Tooltip.
local ARMOR, WEAPON = 4, 2
local function Set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local PROFICIENCY = {
    WARRIOR = { [ARMOR] = Set(0, 1, 2, 3, 4, 6), [WEAPON] = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18) },
    PALADIN = { [ARMOR] = Set(0, 1, 2, 3, 4, 6, 7), [WEAPON] = Set(0, 1, 4, 5, 6, 7, 8) },
    HUNTER  = { [ARMOR] = Set(0, 1, 2, 3), [WEAPON] = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18) },
    ROGUE   = { [ARMOR] = Set(0, 1, 2), [WEAPON] = Set(2, 3, 4, 7, 13, 15, 16, 18) },
    PRIEST  = { [ARMOR] = Set(0, 1), [WEAPON] = Set(4, 10, 15, 19) },
    SHAMAN  = { [ARMOR] = Set(0, 1, 2, 3, 6, 9), [WEAPON] = Set(0, 1, 4, 5, 10, 13, 15) },
    MAGE    = { [ARMOR] = Set(0, 1), [WEAPON] = Set(7, 10, 15, 19) },
    WARLOCK = { [ARMOR] = Set(0, 1), [WEAPON] = Set(7, 10, 15, 19) },
    DRUID   = { [ARMOR] = Set(0, 1, 2, 8), [WEAPON] = Set(4, 5, 10, 13, 15) },
}
local playerClass

local function CanWear(link, itemID)
    playerClass = playerClass or select(2, UnitClass("player"))
    local allowed = PROFICIENCY[playerClass]
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(link)
    if allowed and allowed[classID] and not allowed[classID][subclassID] then return false end
    if ns.ItemUsable then return ns.ItemUsable(link) end -- Forever: Tooltip-Prüfung (ForeverPawn.lua)
    return C_PlayerInfo.CanUseItem and C_PlayerInfo.CanUseItem(itemID)
end

-- Gibt den Namen des leeren Platzes zurück (z. B. „Handgelenke“) oder nil
function ns.FillsEmptySlot(link)
    if ns.db and ns.db.emptySlots == false then return end
    if not link or not Readable(link) then return end
    local itemID, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    if not itemID or not equipLoc or equipLoc == "" then return end
    local empty
    if SLOTS[equipLoc] then
        for _, slot in ipairs(SLOTS[equipLoc]) do
            if not Equipped(slot) then empty = true break end
        end
    elseif RANGED_TYPES[equipLoc] and RangedSlot() then
        empty = not Equipped(RangedSlot())
    else
        local main, off = Equipped(MAIN_HAND), Equipped(OFF_HAND_SLOT)
        local mainIsTwoHand = main and TWO_HAND[EquipLoc(main)]
        local mainName = INVTYPE_WEAPONMAINHAND or "Main Hand" -- „Waffenhand“
        local offName = INVTYPE_WEAPONOFFHAND or "Off Hand"   -- „Schildhand“
        if TWO_HAND[equipLoc] or equipLoc == "INVTYPE_WEAPONMAINHAND" then
            empty = not main and mainName
        elseif equipLoc == "INVTYPE_WEAPON" then
            empty = (not main and mainName) or (not off and not mainIsTwoHand and CanDualWield() and offName)
        elseif OFF_HAND[equipLoc] then
            -- Nebenhand-Waffen erst mit Beidhändigkeit (Krieger/Jäger ab 20); Schild und
            -- Nebenhand-Gegenstände prüft der Tooltip (rot, wenn nicht tragbar)
            local needsDualWield = equipLoc == "INVTYPE_WEAPONOFFHAND" and not CanDualWield()
            empty = not off and not mainIsTwoHand and not needsDualWield and offName
        end
    end
    if not empty or not CanWear(link, itemID) then return end
    return type(empty) == "string" and empty or _G[equipLoc] or equipLoc
end

local function FormatPercent(value)
    local text = ("%.1f"):format(math.abs(value)):gsub("%.", L["DECIMAL_SEPARATOR"])
    return (value >= 0 and "+" or "−") .. text .. " %"
end

-- Zeile im Item-Tooltip (von Tooltip.lua vor den IDs aufgerufen)
function ns.AddUpgradeLine(tooltip, data)
    if data.type ~= Enum.TooltipDataType.Item then return end
    -- wie Blizzards TooltipUtil.GetDisplayedItem: Taschen-Items haben nur die GUID
    local link
    if Readable(data.guid) and data.guid then link = C_Item.GetItemLinkByGUID(data.guid) end
    if not link and Readable(data.hyperlink) then link = data.hyperlink end
    if not link then return end
    local emptySlot = ns.FillsEmptySlot(link)
    if emptySlot then
        tooltip:AddLine(" ")
        tooltip:AddLine(L["Fills empty slot: %s"]:format(emptySlot), 0.56, 0.8, 0.71)
        return
    end
    local percent = ns.UpgradePercent(link)
    if not percent or math.abs(percent) < 0.05 then return end
    local color = percent > 0 and GREEN or RED
    tooltip:AddLine(" ")
    -- flaches Dreieck davor: grün nach oben, rot nach unten (Benny 2026-11-08)
    local icon = ns.UI.IconMarkup(percent > 0 and "Upgrade" or "Downgrade", 11, color, 2)
    tooltip:AddLine(icon .. " " .. FormatPercent(percent), unpack(color))
end

-- Werte ändern sich mit Ausrüstung und Spec; kurz warten, bis die neuen Werte stehen
local pending
local queued
local function Rebuild()
    -- Werte im Kampf teils geschützt: einmal nach dem Kampf neu rechnen
    if InCombatLockdown() then
        if not queued then
            queued = true
            ns.AfterCombat(function() queued = false; Rebuild() end)
        end
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        BuildWeights()
        if ns.RefreshBags then ns.RefreshBags() end
    end)
end
-- Speicher sparen: nur die Specs der eigenen Klasse behalten (die Tabelle hat alle ~40 Specs mit
-- je ~70 Schmuckstücken); der Rest wird vom Garbage Collector freigegeben
ns:On("PLAYER_LOGIN", function()
    local _, _, classID = UnitClass("player")
    if not classID then return end
    local keep = {}
    for index = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
        local specID = GetSpecializationInfoForClassID(classID, index)
        if specID then keep[specID] = true end
    end
    for specID in pairs(DATA.specs) do
        if not keep[specID] then DATA.specs[specID] = nil end
    end
    for key in pairs(DATA.fallback) do
        if not key:find("^" .. classID .. "%-") then DATA.fallback[key] = nil end
    end
end)
ns:On("PLAYER_ENTERING_WORLD", Rebuild)
ns:On("PLAYER_EQUIPMENT_CHANGED", Rebuild)
ns:On("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", Rebuild)
ns:On("GET_ITEM_INFO_RECEIVED", function() if ns.RefreshBags then ns.RefreshBags() end end)
