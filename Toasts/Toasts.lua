-- Toasts (wie „ls: Toasts“): schlanke MUI-Benachrichtigungen statt Blizzards großer Popups –
-- Beute (ab Selten, in Forever ab Gut; Quest-Items immer), Gold, Währungen, Ruf, Erfolge, Quests, Stufenaufstieg,
-- neue Reittiere/Haustiere/Spielzeuge/Vorlagen/Rezepte. Rechts neben dem Damage Meter, oben bündig,
-- stapeln nach unten (Benny, 2026-10-23). Gleiche Dinge werden zusammengefasst (Gold, ×2 …).
-- Im Bosskampf wird gesammelt und danach gezeigt. Blizzard behält nur, was MUI nicht übernimmt
-- (Garnison, Dungeon-Abschluss …): die übernommenen Ereignisse werden an AlertFrame abgemeldet.
--
--   ┌───────────────────────────────┐
--   │▣  Beute                    ×2│  ← Überschrift klein und gedämpft
--   │▣  Klinge des Sturms           │  ← Name in Qualitätsfarbe, Rahmen ebenso
--   └───────────────────────────────┘
local _, ns = ...
local L = ns.L
local Readable = ns.Readable

local WIDTH, HEIGHT, GAP = 240, 40, 4
local MAX_SHOWN = 5
local HOLD = 5             -- Sekunden sichtbar (Maus drauf hält an)
local FADE_IN, FADE_OUT = 0.2, 0.5
local SLIDE_SPEED = 12     -- Nachrücken: Anteil der Reststrecke pro Sekunde (weiches Abbremsen)
local FLASH_TIME = 0.4     -- Aufleuchten beim Hochzählen (Sekunden)
local MERGE_WINDOW = 3     -- Sekunden: gleiche Beute aus Chat und Loot-Toast nur einmal
-- Retail ab Selten; Forever ab Gut (beim Leveln sind Grüne oft echte Verbesserungen, Benny 2026-11-05)
local MIN_QUALITY = ns.IS_FOREVER and Enum.ItemQuality.Uncommon or Enum.ItemQuality.Rare
local DEFAULT_ICON = 134400 -- Fragezeichen

local function Enabled() return ns.db.toasts ~= false end

-- Hintergrund: Farbverlauf in der Farbe des Toasts (Qualität bzw. Textfarbe), links kräftig, nach
-- rechts auslaufend. Blizzards Toast-Grafiken probiert und verworfen (2026-10-23): als schmaler
-- Streifen zugeschnitten sieht man nur deren Rahmen- und Icon-Bruchstücke.
local GRADIENT_ALPHA = 0.35

-- Ereignisse, die MUI übernimmt (Blizzards AlertFrame meldet sie ab)
local TAKEN_OVER = {
    "ACHIEVEMENT_EARNED", "CRITERIA_EARNED", "LOOT_ITEM_ROLL_WON", "SHOW_LOOT_TOAST",
    "SHOW_LOOT_TOAST_UPGRADE", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED", "QUEST_TURNED_IN", "QUEST_LOOT_RECEIVED",
    "NEW_PET_ADDED", "NEW_MOUNT_ADDED", "NEW_TOY_ADDED", "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED", "NEW_RECIPE_LEARNED",
}

-- Halter ------------------------------------------------------------------------------------
-- rechts neben dem ersten Damage-Meter-Fenster; ohne Meter oben links am Rand

local holder = CreateFrame("Frame", "MeredanUIToasts", UIParent)
holder:SetSize(WIDTH, HEIGHT)
holder:SetFrameStrata("HIGH")

local function PlaceHolder()
    holder:ClearAllPoints()
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    -- mUI-Meter (DamageMeter/DamageMeter.lua), sonst Blizzards erstes Fenster
    local meter = ns.layoutFrames.damagemeter or DamageMeterSessionWindow1
    -- nur an einem sichtbaren Meter; Oberkante nie näher als 25 px an der Bildschirmkante
    if meter and meter:IsVisible() and meter:GetLeft() and meter:GetTop() then
        local top = math.min(meter:GetTop(), UIParent:GetTop() - margin)
        holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", meter:GetRight() + ns.Snap(10), top)
    else
        holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", margin, -margin)
    end
end

ns.PlaceToastHolder = PlaceHolder -- das mUI-Meter ruft es beim Ein-/Ausblenden

-- Toast-Frames ------------------------------------------------------------------------------

local pool, shown, queue = {}, {}, {}
local Layout, Release

local function CreateToast()
    local toast = CreateFrame("Button", nil, holder)
    toast:SetSize(ns.Snap(WIDTH), ns.Snap(HEIGHT))
    local bg = toast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    toast.gradient = toast:CreateTexture(nil, "BACKGROUND", nil, 1)
    toast.gradient:SetAllPoints()
    toast.gradient:SetColorTexture(1, 1, 1, 1)
    toast.edges = ns.AddBorder(toast)
    toast.flash = toast:CreateTexture(nil, "BORDER")
    toast.flash:SetAllPoints()
    toast.flash:SetColorTexture(1, 1, 1, 1)
    toast.flash:SetBlendMode("ADD")
    toast.flash:SetAlpha(0)

    local size = ns.Snap(HEIGHT - 8)
    toast.icon = CreateFrame("Frame", nil, toast)
    toast.icon:SetSize(size, size)
    toast.icon:SetPoint("LEFT", ns.Snap(4), 0)
    toast.icon.tex = toast.icon:CreateTexture(nil, "ARTWORK")
    toast.icon.tex:SetAllPoints()
    toast.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns.AddBorder(toast.icon, true)

    toast.count = toast:CreateFontString(nil, "OVERLAY")
    toast.count:SetFont(ns.STYLE.font, ns.FontPx(13), "OUTLINE")
    toast.count:SetPoint("RIGHT", -ns.Snap(8), 0)
    toast.title = toast:CreateFontString(nil, "OVERLAY")
    toast.title:SetFont(ns.STYLE.font, ns.FontPx(10), "OUTLINE")
    toast.title:SetTextColor(unpack(ns.UI.MUTED))
    toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", ns.Snap(8), -1)
    toast.title:SetPoint("RIGHT", toast.count, "LEFT", -ns.Snap(6), 0)
    toast.title:SetJustifyH("LEFT")
    toast.text = toast:CreateFontString(nil, "OVERLAY")
    toast.text:SetFont(ns.STYLE.font, ns.FontPx(13), "OUTLINE")
    toast.text:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", ns.Snap(8), 1)
    toast.text:SetPoint("RIGHT", toast.count, "LEFT", -ns.Snap(6), 0)
    toast.text:SetJustifyH("LEFT")
    toast.text:SetWordWrap(false)

    toast:SetScript("OnEnter", function(self)
        self.hovered = true
        self:SetAlpha(1)
        local data = self.data
        if data and data.link then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, self:GetHeight())
            GameTooltip:SetHyperlink(data.link)
            if data.rolls and ns.AddRollLines then ns.AddRollLines(GameTooltip, data.rolls) end
            if data.link:find("|Hitem:") then ns.ShowItemCompare(GameTooltip) end
            GameTooltip:Show()
            self.UpdateTooltip = self:GetScript("OnEnter") -- Shift während der Maus drauf ist
        end
    end)
    -- Toasts mit Aktion (data.onClick, z. B. Zauberränge aktualisieren): Klick führt sie aus und
    -- lässt den Toast danach ausblenden
    toast:SetScript("OnMouseUp", function(self, button)
        local data = self.data
        if button == "LeftButton" and data and data.onClick and not data.demo then
            data.onClick()
            self.hovered = false
            self.age = math.max(self.age, HOLD)
        end
    end)
    toast:SetScript("OnLeave", function(self)
        self.hovered = false
        self.age = math.min(self.age, HOLD) -- nach dem Verlassen noch kurz stehen lassen
        GameTooltip:Hide()
    end)
    -- Ein-/Ausblenden per OnUpdate (Alpha), Maus drauf hält die Zeit an
    toast:SetScript("OnUpdate", function(self, elapsed)
        -- zum Platz im Stapel gleiten
        if self.y ~= self.targetY then
            local rest = self.targetY - self.y
            self.y = math.abs(rest) < 0.5 and self.targetY or self.y + rest * math.min(1, elapsed * SLIDE_SPEED)
            self:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, self.y)
        end
        if self.flashLeft > 0 then
            self.flashLeft = math.max(self.flashLeft - elapsed, 0)
            self.flash:SetAlpha(0.35 * self.flashLeft / FLASH_TIME)
        end
        if self.hovered then return end
        self.age = self.age + elapsed
        if self.age < FADE_IN then
            self:SetAlpha(self.age / FADE_IN)
        elseif self.age < FADE_IN + HOLD then
            self:SetAlpha(1)
        elseif self.age < FADE_IN + HOLD + FADE_OUT then
            self:SetAlpha(1 - (self.age - FADE_IN - HOLD) / FADE_OUT)
        else
            Release(self)
        end
    end)
    return toast
end

local function Render(toast)
    local data = toast.data
    toast.icon.tex:SetTexture(data.icon or DEFAULT_ICON)
    toast.title:SetText(data.title)
    toast.text:SetText(data.text)
    local r, g, b = 1, 1, 1
    if data.quality and ITEM_QUALITY_COLORS[data.quality] then
        local color = ITEM_QUALITY_COLORS[data.quality]
        r, g, b = color.r, color.g, color.b
    elseif data.color then
        r, g, b = unpack(data.color)
    end
    toast.text:SetTextColor(r, g, b)
    toast.gradient:SetShown(true)
    toast.gradient:SetGradient("HORIZONTAL", CreateColor(r, g, b, GRADIENT_ALPHA), CreateColor(r, g, b, 0))
    -- Rahmen in Qualitätsfarbe nur bei Items mit Qualität ab Ungewöhnlich, sonst schwarz
    local colored = data.quality and data.quality >= Enum.ItemQuality.Uncommon
    for _, edge in ipairs(toast.edges) do
        if colored then edge:SetVertexColor(r, g, b, 1) else edge:SetVertexColor(0, 0, 0, 1) end
    end
    local count = data.countText or (data.count and data.count > 1 and ("×" .. data.count)) or ""
    toast.count:SetText(count)
end

-- Stapel-Plätze: neue Toasts stehen sofort, vorhandene gleiten im OnUpdate nach oben
function Layout()
    for i, toast in ipairs(shown) do
        toast.targetY = -(i - 1) * (ns.Snap(HEIGHT) + ns.Snap(GAP))
        if not toast.y then
            toast.y = toast.targetY
            toast:ClearAllPoints()
            toast:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, toast.y)
        end
    end
end

local function Show(data)
    if #shown == 0 then PlaceHolder() end -- Meter könnte verschoben worden sein
    local toast = table.remove(pool) or CreateToast()
    toast.data, toast.age, toast.hovered, toast.flashLeft = data, 0, false, 0
    toast:SetAlpha(0)
    Render(toast)
    shown[#shown + 1] = toast
    Layout()
    toast:Show()
    if DevLog then -- stille Spur: wo der Toast landet
        DevLog("MeredanUI", ("Toast gezeigt: %s @ %s/%s sichtbar=%s"):format(tostring(data.title),
            tostring(holder:GetLeft()), tostring(holder:GetTop()), tostring(toast:IsVisible())))
    end
end

-- Midnight: C_InstanceEncounter; ältere Clients: globale Funktion
local EncounterInProgress = (C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress) or IsEncounterInProgress
local function Paused() return EncounterInProgress and EncounterInProgress() or false end

local function Pump()
    while #queue > 0 and #shown < MAX_SHOWN and not Paused() do
        Show(table.remove(queue, 1))
    end
end

function Release(toast)
    toast:Hide()
    toast.data, toast.y = nil, nil
    for i, t in ipairs(shown) do
        if t == toast then table.remove(shown, i) break end
    end
    pool[#pool + 1] = toast
    Layout()
    Pump()
end

-- Neuer Toast; gleicher key = vorhandenen aktualisieren (sichtbar oder wartend) statt neu
local function Add(data)
    if data.key then
        for _, toast in ipairs(shown) do
            local old = toast.data
            if old.key == data.key then
                if data.merge then data.merge(old, data) end
                toast.age = math.min(toast.age, FADE_IN) -- Zeit neu starten
                toast.flashLeft = FLASH_TIME
                Render(toast)
                return
            end
        end
        for _, old in ipairs(queue) do
            if old.key == data.key then
                if data.merge then data.merge(old, data) end
                return
            end
        end
    end
    queue[#queue + 1] = data
    Pump()
end

local function MergeCount(old, new) old.count = (old.count or 1) + (new.count or 1) end

-- Beute -------------------------------------------------------------------------------------

local recentLoot = {} -- link > Zeit (Chat und Loot-Toast melden dieselbe Beute)

local function SeenRecently(link)
    local now, seen = GetTime(), recentLoot[link]
    recentLoot[link] = now
    return seen and now - seen < MERGE_WINDOW
end

local function AddItem(link, quantity, title, force)
    if not link or SeenRecently(link) then return end
    local item = Item:CreateFromItemLink(link)
    if item:IsItemEmpty() then return end
    item:ContinueOnItemLoad(function()
        local quality = item:GetItemQuality() or 0
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(link)
        if not force and quality < MIN_QUALITY and classID ~= Enum.ItemClass.Questitem then return end
        Add({
            key = "item:" .. link, title = title or L["Loot"], text = item:GetItemName(), link = link,
            icon = item:GetItemIcon(), quality = quality, count = quantity or 1, merge = MergeCount,
        })
    end)
end

-- Eigene Beute aus dem Chat (Mobs, Truhen, Questbelohnungen): Link und Menge sprachunabhängig
-- aus dem Text, Spieler über die GUID. In Instanzen kann der Text geschützt sein > dann nichts.
ns:On("CHAT_MSG_LOOT", function(_, text, _, _, _, _, _, _, _, _, _, _, guid)
    if not Enabled() or issecretvalue(text) or issecretvalue(guid) then return end
    local link = text:match("|c.-|Hitem:.-|h.-|h|r") or text:match("|Hitem:.-|h.-|h")
    if not link then return end
    if guid ~= UnitGUID("player") then
        if ns.GroupLootFromChat then ns.GroupLootFromChat(link, guid) end
        return
    end
    local quantity = tonumber(text:match("|hx(%d+)") or text:match("|h|rx(%d+)")) or 1 -- „%sx%d“
    AddItem(link, quantity)
end)

-- Beute der Gruppe ------------------------------------------------------------------------
-- Würfel-Ergebnisse aus Blizzards Beuteverlauf (C_LootHistory: Gewinner, alle Würfe) und Beute,
-- die Mitspieler ohne Würfeln bekommen (Chat). Nur in einer Gruppe, ab derselben Qualität wie die
-- eigene Beute. Maus über einen Würfel-Toast zeigt alle Würfe unter dem Item.
local function GroupLootEnabled() return Enabled() and ns.db.toastsGroupLoot ~= false and IsInGroup() end
local wonLinks = {} -- link > Zeit: dieselbe Beute nicht noch einmal als „Mitspieler-Beute“

local ROLL_STATE = {}
local function RollStateText(state)
    if not next(ROLL_STATE) and Enum.EncounterLootDropRollState then
        local S = Enum.EncounterLootDropRollState
        ROLL_STATE[S.NeedMainSpec] = NEED or "Need"
        ROLL_STATE[S.NeedOffSpec] = (NEED or "Need") .. " (" .. L["off-spec"] .. ")"
        ROLL_STATE[S.Transmog] = TRANSMOGRIFICATION or "Transmog"
        ROLL_STATE[S.Greed] = GREED or "Greed"
        ROLL_STATE[S.NoRoll] = L["no roll yet"]
        ROLL_STATE[S.Pass] = PASS or "Pass"
    end
    return ROLL_STATE[state] or "?"
end

local function ClassColored(name, class)
    local color = class and RAID_CLASS_COLORS[class]
    return color and color:WrapTextInColorCode(name) or name
end

-- Zeilen „Name   Bedarf 87 ✓“ (Tooltip des Toasts)
function ns.AddRollLines(tooltip, rolls)
    tooltip:AddLine(" ")
    for _, roll in ipairs(rolls) do
        local right = RollStateText(roll.state) .. (roll.roll and (" " .. roll.roll) or "")
        if roll.isWinner then right = right .. " |A:common-icon-checkmark:12:12|a" end
        local r, g, b = 0.8, 0.8, 0.8
        if roll.isWinner then r, g, b = unpack(ns.UI.ACCENT) end
        tooltip:AddDoubleLine(ClassColored(roll.playerName or "?", roll.playerClass), right, 1, 1, 1, r, g, b)
    end
end

local function Quality(link)
    local quality = C_Item.GetItemQualityByID(link)
    return Readable(quality) and quality or nil
end

ns:On("LOOT_HISTORY_UPDATE_DROP", function(_, encounterID, lootListKey)
    if not GroupLootEnabled() or not C_LootHistory then return end
    local info = C_LootHistory.GetSortedInfoForDrop(encounterID, lootListKey)
    if not info or not (info.winner or info.allPassed) or not Readable(info.itemHyperlink) then return end
    local link = info.itemHyperlink
    local quality = Quality(link)
    if quality and quality < MIN_QUALITY then return end
    local winner = info.winner
    local title, text = L["Everyone passed"], C_Item.GetItemNameByID(link) or link
    if winner then
        title = L["Won · %s"]:format(RollStateText(winner.state) .. (winner.roll and (" " .. winner.roll) or ""))
        local who = winner.isSelf and L["you"] or winner.playerName or "?"
        text = text .. "  " .. ns.UI.ArrowMarkup(11) .. "  " .. ClassColored(who, winner.playerClass)
        wonLinks[link] = GetTime()
        if winner.isSelf then recentLoot[link] = GetTime() end -- eigener Beute-Toast nicht doppelt
    end
    Add({
        key = "drop:" .. encounterID .. ":" .. lootListKey, title = title, text = text, link = link,
        icon = C_Item.GetItemIconByID(link), quality = quality, rolls = info.rollInfos,
    })
end)

-- Mitspieler bekommt Beute (Chat): kurz warten – kam sie aus einem Wurf, zeigt das schon der Würfel-Toast
function ns.GroupLootFromChat(link, guid)
    -- manche Beute-Zeilen (z. B. nach dem Würfeln) kommen ohne Spieler-GUID
    if not GroupLootEnabled() or not Readable(guid) or guid == "" then return end
    C_Timer.After(1.5, function()
        local won = wonLinks[link]
        if won and GetTime() - won < 15 then return end
        local quality = Quality(link)
        if not quality or quality < MIN_QUALITY then return end
        local _, class, _, _, _, name = GetPlayerInfoByGUID(guid)
        if not Readable(name) or not name then return end
        Add({
            key = "group:" .. guid .. ":" .. link, title = L["Loot · %s"]:format(ClassColored(name, class)),
            text = C_Item.GetItemNameByID(link) or link, link = link, icon = C_Item.GetItemIconByID(link),
            quality = quality, count = 1, merge = MergeCount,
        })
    end)
end

-- Gold: jede Zunahme, kurz gesammelt
local lastMoney

local function MoneyText(copper)
    return C_CurrencyInfo.GetCoinTextureString(copper)
end

ns:On("PLAYER_ENTERING_WORLD", function() lastMoney = GetMoney() end)
ns:On("PLAYER_MONEY", function()
    local money = GetMoney()
    local gain = lastMoney and money - lastMoney or 0
    lastMoney = money
    if not Enabled() or gain <= 0 then return end
    Add({
        key = "money", title = L["Gold"], icon = 133784, amount = gain, text = MoneyText(gain),
        color = { 1, 0.82, 0 },
        merge = function(old, new) old.amount = old.amount + new.amount; old.text = MoneyText(old.amount) end,
    })
end)

-- Währungen
ns:On("CURRENCY_DISPLAY_UPDATE", function(_, currencyID, _, change)
    if not Enabled() or not currencyID or not change or change <= 0 then return end
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if not info or info.isHeader or not info.discovered or not info.name or info.name == "" then return end
    Add({
        key = "currency:" .. currencyID, title = L["Currency"], text = info.name, icon = info.iconFileID,
        quality = info.quality, count = change, countText = "+" .. BreakUpLargeNumbers(change),
        link = C_CurrencyInfo.GetCurrencyLink(currencyID),
        merge = function(old, new)
            old.count = old.count + new.count
            old.countText = "+" .. BreakUpLargeNumbers(old.count)
        end,
    })
end)

-- Ruf: kein Toast mehr (Benny 2026-11-06 – bekommt eine eigene Anzeige)

ns:On("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", function(_, factionID, level)
    if not Enabled() then return end
    local data = C_MajorFactions.GetMajorFactionData(factionID)
    if not data then return end
    Add({ title = L["Renown"], text = data.name, icon = 236681, color = ns.UI.ACCENT, countText = tostring(level) })
end)

-- Blizzards übernommene Ereignisse ----------------------------------------------------------

local function ShouldToastAchievement(id, alreadyEarned)
    local _, _, _, _, _, _, _, _, flags, _, _, isGuild = GetAchievementInfo(id)
    if not isGuild and alreadyEarned then
        return bit.band(flags or 0, ACHIEVEMENT_FLAGS_TOAST_ON_REPEAT_COMPLETION or 0) ~= 0
    end
    return true
end

local HANDLERS = {
    ACHIEVEMENT_EARNED = function(id, alreadyEarned)
        if not ShouldToastAchievement(id, alreadyEarned) then return end
        local _, name, points, _, _, _, _, _, _, icon, _, isGuild = GetAchievementInfo(id)
        Add({ title = isGuild and L["Guild achievement"] or L["Achievement"], text = name, icon = icon,
            color = { 1, 0.82, 0 }, countText = points and points > 0 and tostring(points) or nil,
            link = GetAchievementLink(id) })
    end,
    CRITERIA_EARNED = function(id, description, alreadyEarned)
        if not ShouldToastAchievement(id, alreadyEarned) then return end
        local _, name, _, _, _, _, _, _, _, icon = GetAchievementInfo(id)
        Add({ title = L["Achievement progress"] .. ": " .. (name or ""), text = description, icon = icon,
            link = GetAchievementLink(id) })
    end,
    LOOT_ITEM_ROLL_WON = function(link, quantity) AddItem(link, quantity, L["Roll won"], true) end,
    SHOW_LOOT_TOAST = function(typeID, link, quantity, _, _, isPersonal)
        if typeID == "item" then
            -- nicht erzwingen: Forever meldet hierüber jede Beute, auch graue und weiße
            AddItem(link, quantity)
        elseif typeID == "currency" and isPersonal then
            AddItem(link, quantity, nil, true)
        end -- Gold kommt über PLAYER_MONEY
    end,
    SHOW_LOOT_TOAST_UPGRADE = function(link, quantity) recentLoot[link] = nil; AddItem(link, quantity, L["Upgraded"], true) end,
    SHOW_LOOT_TOAST_LEGENDARY_LOOTED = function(link) recentLoot[link] = nil; AddItem(link, 1, L["Legendary"], true) end,
    QUEST_TURNED_IN = function(questID, xp, money)
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if not title then return end
        Add({ title = L["Quest completed"], text = title, icon = 236669, color = { 1, 0.82, 0 },
            countText = xp and xp > 0 and (BreakUpLargeNumbers(xp) .. " " .. L["XP"]) or nil })
    end,
    QUEST_LOOT_RECEIVED = function() end, -- Belohnungen kommen als Beute über den Chat
    NEW_MOUNT_ADDED = function(mountID)
        local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
        Add({ title = L["New mount"], text = name, icon = icon, color = ns.UI.ACCENT,
            link = spellID and C_Spell.GetSpellLink(spellID) or nil })
    end,
    NEW_PET_ADDED = function(petGUID)
        local info = C_PetJournal.GetPetInfoTableByPetID(petGUID)
        if not info then return end
        Add({ title = L["New pet"], text = info.customName or info.name, icon = info.icon, color = ns.UI.ACCENT })
    end,
    NEW_TOY_ADDED = function(itemID)
        local _, name, icon = C_ToyBox.GetToyInfo(itemID)
        Add({ title = L["New toy"], text = name, icon = icon, color = ns.UI.ACCENT,
            link = C_ToyBox.GetToyLink and C_ToyBox.GetToyLink(itemID) or nil })
    end,
    TRANSMOG_COLLECTION_SOURCE_ADDED = function(sourceID)
        local info = C_TransmogCollection.GetSourceInfo(sourceID)
        if not info or not info.itemID then return end
        -- immer in Transmog-Farbe (Blizzards Rosa): Vorlagen sind oft weiß/grau und sahen farblos aus
        local tm = TRANSMOGRIFY_FONT_COLOR
        Add({ key = "transmog:" .. sourceID, title = L["New appearance"], text = info.name,
            icon = C_Item.GetItemIconByID(info.itemID), color = tm and { tm.r, tm.g, tm.b } or { 1, 0.5, 1 } })
    end,
    NEW_RECIPE_LEARNED = function(recipeID)
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if not info then return end
        Add({ title = L["New recipe"], text = info.name, icon = info.icon, color = ns.UI.ACCENT })
    end,
}
HANDLERS.TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED = HANDLERS.TRANSMOG_COLLECTION_SOURCE_ADDED

ns:On("PLAYER_LEVEL_UP", function(_, level)
    if not Enabled() then return end
    Add({ title = L["Level up"], text = (LEVEL or "Level") .. " " .. level, icon = 236567, color = { 1, 0.82, 0 } })
end)

-- Nach dem Bosskampf Gesammeltes zeigen
ns:On("ENCOUNTER_END", function() C_Timer.After(0.5, Pump) end)
ns:On("PLAYER_REGEN_ENABLED", Pump)

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    PlaceHolder()
    if DamageMeterSessionWindow1 then
        -- Meter verschoben/vergrößert > Toasts wandern mit (Anker ist relativ, nur beim Erscheinen neu)
        DamageMeterSessionWindow1:HookScript("OnShow", PlaceHolder)
    end
    for _, event in ipairs(TAKEN_OVER) do
        if AlertFrame then AlertFrame:UnregisterEvent(event) end
        ns:On(event, function(_, ...) HANDLERS[event](...) end)
    end
end)

-- Demo (Einstellungen > Toasts): Live-Ablauf in Schleife – Toasts kommen nacheinander (ab dem
-- sechsten wartend), Gold und ein Item zählen mit Aufleuchten hoch, abgelaufene blenden aus und
-- der Rest gleitet nach. Läuft über denselben Weg wie echte Toasts (Add).

local DEMO_STEP = 0.7
local demoTicker, demoStep

local function DemoMoney(amount)
    return { key = "demo:money", demo = true, title = L["Gold"], icon = 133784, color = { 1, 0.82, 0 },
        amount = amount, text = MoneyText(amount),
        merge = function(old, new) old.amount = old.amount + new.amount; old.text = MoneyText(old.amount) end }
end

local function DemoItem(text, icon, quality, key)
    return { key = key, demo = true, title = L["Loot"], text = text, icon = icon, quality = quality, count = 1,
        merge = MergeCount }
end

local function DemoActions()
    local accent = ns.UI.ACCENT
    return {
        DemoItem("Klinge des Sturms", 135349, Enum.ItemQuality.Epic, "demo:blade"),
        DemoItem("Sturmgeschmiedeter Schulterschutz", 135056, Enum.ItemQuality.Rare, "demo:shoulder"),
        DemoMoney(1234567),
        { demo = true, title = L["Achievement"], text = "Der Sturm bricht los", icon = 236669, color = { 1, 0.82, 0 }, countText = "10" },
        DemoMoney(254321),
        DemoItem("Sturmgeschmiedeter Schulterschutz", 135056, Enum.ItemQuality.Rare, "demo:shoulder"),
        DemoItem("Sturmbrecher", 135350, Enum.ItemQuality.Legendary, "demo:legendary"),
        -- Würfel-Ergebnis der Gruppe (Maus drüber: alle Würfe)
        { key = "demo:roll", demo = true, title = L["Won · %s"]:format((NEED or "Need") .. " 87"),
            text = (C_Item.GetItemNameByID(19019) or "Donnerzorn") .. "  " .. ns.UI.ArrowMarkup(11) .. "  " .. RAID_CLASS_COLORS.SHAMAN:WrapTextInColorCode("Thrall"),
            icon = C_Item.GetItemIconByID(19019), quality = Enum.ItemQuality.Legendary, link = "item:19019",
            rolls = {
                { playerName = "Thrall", playerClass = "SHAMAN", state = 0, roll = 87, isWinner = true },
                { playerName = "Jaina", playerClass = "MAGE", state = 0, roll = 54 },
                { playerName = "Koratal", playerClass = "HUNTER", state = 3, roll = 92 },
                { playerName = "Uther", playerClass = "PALADIN", state = 5 },
            } },
        DemoMoney(98765),
        -- Battle.net (Toasts/BNetToasts.lua): Freund online / Statusnachricht / offline
        { demo = true, title = "Jaina#2104", color = { 0.51, 0.773, 1 }, icon = ns.MEDIA .. "Icons\\Friends",
            text = "Jaina, Stufe 60 Magierin – |cff33ff33" .. (BN_TOAST_ONLINE or "online") .. "|r" },
        { demo = true, title = "Thrall#1337", color = { 0.51, 0.773, 1 }, icon = ns.MEDIA .. "Icons\\Friends",
            text = "Heute Abend Onyxia?" },
        -- Haltbarkeit (Toasts/Extras.lua) und Berufe-Erinnerung (Toasts/ProfessionReminder.lua)
        { demo = true, title = L["Repair soon"], text = L["Lowest item at %d %%"]:format(18),
            icon = "Interface\\Icons\\Trade_BlackSmithing", color = { 1, 0.6, 0.1 } },
        { demo = true, title = "Schmiedekunst 75/75", icon = ns.MEDIA .. "Icons\\Crafting", color = accent,
            text = L["%s can be learned at the trainer"]:format(L["Journeyman"]) },
        { demo = true, title = "Uther#4711", color = { 0.6, 0.59, 0.56 }, icon = ns.MEDIA .. "Icons\\Friends",
            text = BN_TOAST_OFFLINE or "offline" },
        { demo = true, title = L["New mount"], text = "Sturmkrallengreif", icon = 132265, color = accent },
        { demo = true, title = L["Quest completed"], text = "Ein Sturm zieht auf", icon = 236669, color = { 1, 0.82, 0 }, countText = "12.500 EP" },
    }
end

local function DemoTick()
    local actions = DemoActions()
    demoStep = demoStep + 1
    if actions[demoStep] then
        Add(actions[demoStep])
    elseif #shown == 0 and #queue == 0 then
        demoStep = 0 -- alles abgelaufen > von vorn
    end
end

ns.ToastsDemo = {
    Start = function()
        PlaceHolder()
        demoStep = 0
        if demoTicker then demoTicker:Cancel() end
        demoTicker = C_Timer.NewTicker(DEMO_STEP, DemoTick)
        DemoTick()
    end,
    Stop = function()
        if demoTicker then demoTicker:Cancel() end
        demoTicker = nil
        for i = #queue, 1, -1 do
            if queue[i].demo then table.remove(queue, i) end
        end
        for i = #shown, 1, -1 do
            if shown[i].data and shown[i].data.demo then Release(shown[i]) end
        end
    end,
    IsActive = function() return demoTicker ~= nil end,
}

-- Für andere Module (Haltbarkeit, Bereitschaftscheck …): true, wenn ein Toast kommt – sonst
-- (Toasts aus) selbst etwas anderes zeigen
function ns.AddToast(data)
    if not Enabled() then return false end
    Add(data)
    return true
end
