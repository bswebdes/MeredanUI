-- Toasts: slim mUI notifications replacing Blizzard's large popups - loot, gold, currencies,
-- renown, achievements, quests, level up, new collectibles/recipes. Stacked downward right of the
-- damage meter; identical items merge (x2). Held back during boss encounters. Taken-over events
-- are unregistered from AlertFrame; Blizzard keeps the rest (garrison, dungeon completion ...).
--
--   [icon]  Loot                 x2   <- title: small, muted
--   [icon]  Blade of the Storm        <- name and border in quality color
local _, ns = ...
local L = ns.L
local Readable = ns.Readable

local WIDTH, HEIGHT, GAP = 240, 40, 4
local MAX_SHOWN = 5
local HOLD = 5             -- seconds visible (paused while hovered)
local FADE_IN, FADE_OUT = 0.2, 0.5
local SLIDE_SPEED = 12     -- slide: fraction of remaining distance per second (ease-out)
local FLASH_TIME = 0.4     -- flash duration when a count goes up
local MERGE_WINDOW = 3     -- seconds: dedupe the same loot from chat and loot toast
-- Retail: Rare and up; Forever: Uncommon and up (greens are real upgrades while leveling)
local MIN_QUALITY = ns.IS_FOREVER and Enum.ItemQuality.Uncommon or Enum.ItemQuality.Rare
local DEFAULT_ICON = 134400 -- question mark

local function Enabled() return ns.db.toasts ~= false end

-- Background: gradient in the toast color (quality or text color), strong left, fading right.
-- Blizzard's toast art does not work cropped to a thin strip (only border/icon fragments show).
local GRADIENT_ALPHA = 0.35

-- Events mUI takes over (unregistered from Blizzard's AlertFrame)
local TAKEN_OVER = {
    "ACHIEVEMENT_EARNED", "CRITERIA_EARNED", "LOOT_ITEM_ROLL_WON", "SHOW_LOOT_TOAST",
    "SHOW_LOOT_TOAST_UPGRADE", "SHOW_LOOT_TOAST_LEGENDARY_LOOTED", "QUEST_TURNED_IN", "QUEST_LOOT_RECEIVED",
    "NEW_PET_ADDED", "NEW_MOUNT_ADDED", "NEW_TOY_ADDED", "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED", "NEW_RECIPE_LEARNED",
}

-- Holder ------------------------------------------------------------------------------------
-- right of the first damage meter window; top left corner without a meter

local holder = CreateFrame("Frame", "MeredanUIToasts", UIParent)
holder:SetSize(WIDTH, HEIGHT)
holder:SetFrameStrata("HIGH")

local function PlaceHolder()
    holder:ClearAllPoints()
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    -- mUI meter (DamageMeter/DamageMeter.lua), else Details' first window, else Blizzard's
    local meter, meterTop = ns.layoutFrames.damagemeter, nil
    if not (meter and meter:IsVisible()) and ns.DetailsMeterFrame then meter, meterTop = ns.DetailsMeterFrame() end
    meter = meter or DamageMeterSessionWindow1
    -- only next to a visible meter; top edge keeps the screen margin
    if meter and meter:IsVisible() and meter:GetLeft() and meter:GetTop() then
        local top = math.min(meterTop or meter:GetTop(), UIParent:GetTop() - margin)
        holder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", meter:GetRight() + ns.Snap(10), top)
    else
        holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", margin, -margin)
    end
end

ns.PlaceToastHolder = PlaceHolder -- called by the mUI meter on show/hide
ns.TOAST_WIDTH, ns.TOAST_HEIGHT, ns.TOAST_GAP = WIDTH, HEIGHT, GAP
ns.ToastHolder = holder

-- Toast frames ------------------------------------------------------------------------------

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
            self.UpdateTooltip = self:GetScript("OnEnter") -- refresh on Shift while hovered
        end
    end)
    -- Toasts with an action (data.onClick): click runs it, then the toast fades out
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
        self.age = math.min(self.age, HOLD) -- stay briefly after mouse leaves
        GameTooltip:Hide()
    end)
    -- Fade via OnUpdate alpha; hovering pauses the timer
    toast:SetScript("OnUpdate", function(self, elapsed)
        -- slide to stack position
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
    -- Quality-colored border only for Uncommon+ items, otherwise black
    local colored = data.quality and data.quality >= Enum.ItemQuality.Uncommon
    for _, edge in ipairs(toast.edges) do
        if colored then edge:SetVertexColor(r, g, b, 1) else edge:SetVertexColor(unpack(ns.BORDER_COLOR)) end
    end
    local count = data.countText or (data.count and data.count > 1 and ("×" .. data.count)) or ""
    toast.count:SetText(count)
end

-- Stack positions: new toasts snap in place, existing ones slide up in OnUpdate
function Layout()
    local top = ns.toastReserve or 0 -- space taken by sticky entries (Toasts/QueueStatus.lua)
    for i, toast in ipairs(shown) do
        toast.targetY = -top - (i - 1) * (ns.Snap(HEIGHT) + ns.Snap(GAP))
        if not toast.y then
            toast.y = toast.targetY
            toast:ClearAllPoints()
            toast:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, toast.y)
        end
    end
end

local function Show(data)
    if #shown == 0 then PlaceHolder() end -- meter may have moved
    local toast = table.remove(pool) or CreateToast()
    toast.data, toast.age, toast.hovered, toast.flashLeft = data, 0, false, 0
    toast:SetAlpha(0)
    Render(toast)
    shown[#shown + 1] = toast
    Layout()
    toast:Show()
    if DevLog then -- silent trace: where the toast lands
        DevLog("MeredanUI", ("Toast gezeigt: %s @ %s/%s sichtbar=%s"):format(tostring(data.title),
            tostring(holder:GetLeft()), tostring(holder:GetTop()), tostring(toast:IsVisible())))
    end
end

-- Midnight: C_InstanceEncounter; older clients: global function
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

-- New toast; same key updates the existing one (shown or queued) instead
local function Add(data)
    if data.key then
        for _, toast in ipairs(shown) do
            local old = toast.data
            if old.key == data.key then
                if data.merge then data.merge(old, data) end
                toast.age = math.min(toast.age, FADE_IN) -- restart timer
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

-- Loot -------------------------------------------------------------------------------------

local recentLoot = {} -- link -> time (chat and loot toast report the same loot)

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
            key = "item:" .. link, title = title or (ns.FishingToastTitle and ns.FishingToastTitle(link)) or L["Loot"],
            text = item:GetItemName(), link = link,
            icon = item:GetItemIcon(), quality = quality, count = quantity or 1, merge = MergeCount,
        })
    end)
end

-- Own loot from chat (mobs, chests, quest rewards): link and quantity parsed locale-independently,
-- player via GUID. In instances the text may be a secret value -> skip.
ns:On("CHAT_MSG_LOOT", function(_, text, _, _, _, _, _, _, _, _, _, _, guid)
    if not Enabled() or issecretvalue(text) or issecretvalue(guid) then return end
    local link = text:match("|c.-|Hitem:.-|h.-|h|r") or text:match("|Hitem:.-|h.-|h")
    if not link then return end
    if guid ~= UnitGUID("player") then
        if ns.GroupLootFromChat then ns.GroupLootFromChat(link, guid) end
        return
    end
    local quantity = tonumber(text:match("|hx(%d+)") or text:match("|h|rx(%d+)")) or 1 -- "%sx%d"
    AddItem(link, quantity)
end)

-- Group loot ------------------------------------------------------------------------------
-- Roll results from C_LootHistory (winner, all rolls) and loot party members get without a roll
-- (chat). Group only, same quality threshold as own loot. Hovering a roll toast lists all rolls.
local function GroupLootEnabled() return Enabled() and ns.db.toastsGroupLoot ~= false and IsInGroup() end
local wonLinks = {} -- link -> time: don't repeat it as party member loot

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

-- Tooltip lines "Name   Need 87 [check]"
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
        if winner.isSelf then recentLoot[link] = GetTime() end -- avoid a duplicate own loot toast
    end
    Add({
        key = "drop:" .. encounterID .. ":" .. lootListKey, title = title, text = text, link = link,
        icon = C_Item.GetItemIconByID(link), quality = quality, rolls = info.rollInfos,
    })
end)

-- Party member loot (chat): wait briefly - if it came from a roll, the roll toast covers it
function ns.GroupLootFromChat(link, guid)
    -- some loot lines (e.g. after rolls) come without a player GUID
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

-- Gold: every gain, merged
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

-- Currencies
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

ns:On("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", function(_, factionID, level)
    if not Enabled() then return end
    local data = C_MajorFactions.GetMajorFactionData(factionID)
    if not data then return end
    Add({ title = L["Renown"], text = data.name, icon = 236681, color = ns.UI.ACCENT, countText = tostring(level) })
end)

-- Events taken over from Blizzard ------------------------------------------------------------

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
            -- no force: Forever reports all loot here, including grey and white
            AddItem(link, quantity)
        elseif typeID == "currency" and isPersonal then
            AddItem(link, quantity, nil, true)
        end -- gold comes via PLAYER_MONEY
    end,
    SHOW_LOOT_TOAST_UPGRADE = function(link, quantity) recentLoot[link] = nil; AddItem(link, quantity, L["Upgraded"], true) end,
    SHOW_LOOT_TOAST_LEGENDARY_LOOTED = function(link) recentLoot[link] = nil; AddItem(link, 1, L["Legendary"], true) end,
    QUEST_TURNED_IN = function(questID, xp, money)
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if not title then return end
        Add({ title = L["Quest completed"], text = title, icon = 236669, color = { 1, 0.82, 0 },
            countText = xp and xp > 0 and (BreakUpLargeNumbers(xp) .. " " .. L["XP"]) or nil })
    end,
    QUEST_LOOT_RECEIVED = function() end, -- rewards arrive as loot via chat
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
        -- always transmog pink: appearances are often white/grey and look colorless
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

-- Flush held-back toasts after the encounter
ns:On("ENCOUNTER_END", function() C_Timer.After(0.5, Pump) end)
ns:On("PLAYER_REGEN_ENABLED", Pump)

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    PlaceHolder()
    if DamageMeterSessionWindow1 then
        -- Meter moved/resized -> toasts follow (position is only recomputed on show)
        DamageMeterSessionWindow1:HookScript("OnShow", PlaceHolder)
    end
    for _, event in ipairs(TAKEN_OVER) do
        if AlertFrame then AlertFrame:UnregisterEvent(event) end
        ns:On(event, function(_, ...) HANDLERS[event](...) end)
    end
end)

-- Demo (Settings > Toasts): looping live sequence through the real Add path - toasts arrive one
-- by one (queued past five), gold and an item count up with a flash, expired ones fade out.

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
        -- group roll result (hover: all rolls)
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
        -- Battle.net (Toasts/BNetToasts.lua): friend online / broadcast / offline
        { demo = true, title = "Jaina#2104", color = { 0.51, 0.773, 1 }, icon = ns.MEDIA .. "Icons\\Friends",
            text = "Jaina, Stufe 60 Magierin – |cff33ff33" .. (BN_TOAST_ONLINE or "online") .. "|r" },
        { demo = true, title = "Thrall#1337", color = { 0.51, 0.773, 1 }, icon = ns.MEDIA .. "Icons\\Friends",
            text = "Heute Abend Onyxia?" },
        -- durability (Toasts/Extras.lua) and profession reminder (Toasts/ProfessionReminder.lua)
        { demo = true, title = L["Repair soon"], text = L["Lowest item at %d %%"]:format(18),
            icon = "Interface\\Icons\\Trade_BlackSmithing", color = { 1, 0.6, 0.1 } },
        { demo = true, title = "Schmiedekunst 75/75", icon = ns.MEDIA .. "Icons\\Crafting", color = accent,
            text = L["%s can be learned at the trainer"]:format(L["Journeyman"]) },
        { demo = true, title = "Uther#4711", color = { 0.6, 0.59, 0.56 }, icon = ns.MEDIA .. "Icons\\Friends",
            text = BN_TOAST_OFFLINE or "offline" },
        -- buff reminder (Toasts/BuffReminder.lua, Forever)
        { demo = true, title = L["Buff missing"], text = "Arkane Intelligenz, " .. L["%s (old rank)"]:format("Frostrüstung"),
            icon = 135932, color = { 1, 0.82, 0 } },
        -- class quest reminder (Quests/ClassQuestReminder.lua, Forever)
        { demo = true, title = L["Class quest: %s"]:format(L["Bear Form"]), text = "Denatharion, Darnassus",
            icon = "Interface\\Icons\\ClassIcon_Druid", color = { 1, 0.49, 0.04 } },
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
        demoStep = 0 -- all expired -> restart
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

-- Sticky entries changed their height: move the toast stack (slides like a removed toast)
function ns.ToastRelayout()
    if #shown == 0 then PlaceHolder() end
    Layout()
end

-- For other modules: returns true if a toast is shown; false (toasts off) means show a fallback
function ns.AddToast(data)
    if not Enabled() then return false end
    Add(data)
    return true
end

-- Blizzard HelpTips anchor to buttons mUI hides or replaces (bags, micro menu) and would float
-- somewhere on screen. If the anchor is invisible, show the tip as a toast and acknowledge it.
local function AnchorHidden(region)
    if type(region) ~= "table" or not region.IsVisible then return false end
    if region.IsForbidden and region:IsForbidden() then return false end
    return not region:IsVisible() or (region.GetEffectiveAlpha and region:GetEffectiveAlpha() < 0.05)
end

if HelpTip and HelpTip.Show then
    hooksecurefunc(HelpTip, "Show", function(_, parent, info, relativeRegion)
        if not (Enabled() and info and info.text) then return end
        if not AnchorHidden(relativeRegion or parent) then return end
        local text = info.text
        C_Timer.After(0, function()
            if HelpTip.Acknowledge then pcall(HelpTip.Acknowledge, HelpTip, parent, text) end
            if HelpTip.Hide then pcall(HelpTip.Hide, HelpTip, parent, text) end
        end)
        Add({ title = L["Tip"], text = (text:gsub("\n+", " ")), icon = ns.MEDIA .. "Icons\\Assistant", color = { 0.56, 0.8, 0.71 } })
    end)
end
