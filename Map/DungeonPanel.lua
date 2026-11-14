-- Dungeon panel in the world map's right column while a dungeon map is shown (replaces the quest log):
-- "Bosses" tab + wishlist button, bosses as an accordion in map pin order. Clicking a boss (row or its
-- pin on the map) opens its loot below it with a "For me / All" filter; the star keeps an item on the
-- wishlist (Character/Wishlist.lua, own window docked right of the map).
--
--   +- right column ---------------------------+
--   | [ Bosses                    ] [* 3]       |
--   | <1> Lady Anacondra              3 items   |
--   |   [For me] [All]                          |
--   |   [icon] Belt of the Fang     Leather  *  |
--   | <2> Lord Cobrahn                3 items   |
--   | Drop chances from classic data ...        |
local _, ns = ...
local L = ns.L

local P = {}
ns.DungeonPanel = P

local BOSS_ROW, LOOT_ROW, GAP = 42, 38, 4
local frame, list, bossTab, questTab, wishButton, filterBar, note
local current = "bosses" -- tab: "bosses" or "quests"
local bossRows, lootRows = {}, {}
local selected -- encounter ID or "rare:<npcID>"
local shownInstance
local hiddenFrames = {}

local GOLD = { 0.85, 0.71, 0.42 }
local BLACK = ns.BORDER_COLOR -- edge colour; bronze in the rune look (name kept)
local SELECTED_BG = { 1, 0.9, 0.7, 0.06 } -- open boss: warm light tint over the card
local ROW_BG = { 0, 0, 0, 0 } -- rows are cards; closed = no tint

-- "For me": best armour type and usable weapons per class (classic proficiencies, trainable ones count).
-- Weapon subclasses (Enum.ItemWeaponSubclass): 0 axe1H, 1 axe2H, 2 bow, 3 gun, 4 mace1H, 5 mace2H,
-- 6 polearm, 7 sword1H, 8 sword2H, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local ARMOUR = { WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local function Set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WEAPONS = {
    WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE = Set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST = Set(4, 10, 15, 19),
    SHAMAN = Set(0, 1, 4, 5, 10, 13, 15),
    MAGE = Set(7, 10, 15, 19),
    WARLOCK = Set(7, 10, 15, 19),
    DRUID = Set(4, 5, 10, 13, 15),
}
local ANY_SLOT = Set("INVTYPE_CLOAK", "INVTYPE_NECK", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_HOLDABLE")

local function ForMe(itemID)
    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    local class = select(2, UnitClass("player"))
    if classID == Enum.ItemClass.Armor then
        if ANY_SLOT[equipLoc] or subclassID == 0 then return true end
        if subclassID == 6 then return SHIELD[class] or false end
        if subclassID >= 1 and subclassID <= 4 then return subclassID == ARMOUR[class] end
        return true
    elseif classID == Enum.ItemClass.Weapon then
        return WEAPONS[class] == nil or WEAPONS[class][subclassID] or false
    end
    return true -- bags, recipes, quest items
end

local function FilterMine() return not (ns.char and ns.char.dungeonLootAll) end

-- Bosses of the instance in pin/number order, plus rares that have loot
local function Sources(instance)
    local out = {}
    local loot = ns.DUNGEON_LOOT[instance] or {}
    local pins = ns.DUNGEON_PINS and ns.DUNGEON_PINS[instance] or {}
    local display = {}
    for _, p in ipairs(pins) do if p.kind == "boss" then display[p.id] = p.display end end
    for i, b in ipairs(ns.DUNGEON_BOSSES and ns.DUNGEON_BOSSES[instance] or {}) do
        out[#out + 1] = { key = b[1], number = i, name = GetLocale() == "deDE" and b[3] or b[2], items = loot[b[1]] or {},
            display = display[b[1]] }
    end
    for _, p in ipairs(pins) do
        local key = "rare:" .. p.id
        if p.kind == "rare" and loot[key] then
            out[#out + 1] = { key = key, rare = true, name = p.name, items = loot[key], display = p.display }
        end
    end
    return out
end

local function Visible(items)
    if not FilterMine() then return items end
    local out = {}
    for _, entry in ipairs(items) do if ForMe(entry[1]) then out[#out + 1] = entry end end
    return out
end

-- Instances whose boss pins Benny checked in the game; released one by one (Map/DungeonLoot.lua has more)
local READY = { [43] = true, [389] = true }

-- Items seen dropping in Forever (account-wide): looting in an instance marks its listed items
local function Seen()
    MeredanUIDB.lootSeen = MeredanUIDB.lootSeen or {}
    return MeredanUIDB.lootSeen
end
ns:On("LOOT_OPENED", function()
    local inInstance = IsInInstance()
    local instance = inInstance and select(8, GetInstanceInfo())
    local loot = instance and ns.DUNGEON_LOOT[instance]
    if not loot then return end
    local listed = {}
    for _, items in pairs(loot) do for _, entry in ipairs(items) do listed[entry[1]] = true end end
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local id = link and not ns.issecretvalue(link) and C_Item.GetItemInfoInstant(link)
        if id and listed[id] then Seen()[id] = true end
    end
end)

-- Flat button with 1px border; TabStyle marks the active one (accent border + text)
local function SmallButton(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    ns.UI.Bevel(b)
    b.edges = ns.AddBorder(b, true) -- active tab: accent edge
    b.text = ns.UI.Text(b, 12, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    return b
end

local function TabStyle(button, active)
    for _, e in ipairs(button.edges) do e:SetVertexColor(unpack(active and ns.UI.ACCENT or { 0, 0, 0, 0 })) end
    button.text:SetTextColor(unpack(active and ns.UI.ACCENT or ns.UI.MUTED))
end

local function BossRow(i)
    if bossRows[i] then return bossRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(BOSS_ROW)
    UI.Card(row)
    row.bg = row:CreateTexture(nil, "BACKGROUND", nil, 2) -- state tint over the card
    row.bg:SetAllPoints()
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("TOPLEFT")
    row.bar:SetPoint("BOTTOMLEFT")
    row.bar:SetWidth(2)
    row.bar:SetColorTexture(unpack(UI.ACCENT))
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    -- same round boss portrait + number badge as the pin on the map (Map/DungeonPins.lua)
    row.pin = CreateFrame("Frame", nil, row)
    row.pin:SetPoint("LEFT", 6, 0)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 54, 0)
    row.name:SetPoint("RIGHT", -70, 0)
    row.name:SetWordWrap(false)
    row.count = UI.Text(row, 11, "RIGHT", UI.MUTED)
    row.count:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnClick", function(self)
        if selected == self.key then P.Select(nil) else P.Select(self.key) end
    end)
    bossRows[i] = row
    return row
end

local function LootRow(i)
    if lootRows[i] then return lootRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(LOOT_ROW)
    ns.UI.Card(row)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = UI.Text(row, 13, "LEFT")
    ns.SetFont(row.name, 13, "", "bold")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", -38, 0)
    row.name:SetWordWrap(false)
    row.kind = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.kind:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.kind:SetPoint("RIGHT", -38, 0)
    row.kind:SetWordWrap(false)
    row.star = SmallButton(row, "", 24, 24)
    row.star:SetPoint("RIGHT", -6, 0)
    row.star.icon = UI.Icon(row.star, "Star", 14, GOLD)
    row.star.icon:SetPoint("CENTER")
    row.star:SetScript("OnClick", function()
        ns.Wishlist.Toggle(row.itemID, ns.DungeonMapView.instance, selected)
    end)
    row.star:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(ns.Wishlist.Has(row.itemID) and L["Remove from wishlist"] or L["Add to wishlist"], 1, 1, 1)
        GameTooltip:Show()
    end)
    row.star:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") then
            local _, link = C_Item.GetItemInfo(self.itemID)
            if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
        end
    end)
    lootRows[i] = row
    return row
end

-- "Waist · Leather · 25 %" from the instant item data (no server round trip); a check mark when the
-- item was seen dropping in Forever
local function KindText(itemID, chance)
    local _, _, subType, equipLoc = C_Item.GetItemInfoInstant(itemID)
    local slot = equipLoc and equipLoc ~= "" and _G[equipLoc] or nil
    local parts = {}
    if slot then parts[#parts + 1] = slot end
    if subType and subType ~= "" and subType ~= slot then parts[#parts + 1] = subType end
    if chance then parts[#parts + 1] = ("%s %%"):format(chance) end
    local text = table.concat(parts, "  ·  ")
    if Seen()[itemID] then text = text .. "  |T" .. ns.MEDIA .. "Icons\\Check:11:11:0:0:64:64:0:64:0:64:142:203:180|t" end
    return text
end

local function FillLoot(row, entry)
    local id = entry[1]
    row.itemID = id
    row.icon:SetTexture(C_Item.GetItemIconByID(id))
    row.kind:SetText(KindText(id, entry[2]))
    row.name:SetText("")
    row.star.icon:SetAlpha(ns.Wishlist.Has(id) and 1 or 0.3)
    local item = Item:CreateFromItemID(id)
    item:ContinueOnItemLoad(function()
        if row.itemID ~= id then return end
        row.name:SetText(item:GetItemName() or "")
        local color = item:GetItemQualityColor()
        if color then row.name:SetTextColor(color.r, color.g, color.b) end
    end)
end

local function Place(region, y, indent)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", list.child, "TOPLEFT", indent or 0, -y)
    region:SetPoint("RIGHT", list.child, "RIGHT")
end

local QUEST_NOTE, LOOT_NOTE

local function Layout(instance)
    note:SetText(LOOT_NOTE)
    for _, r in ipairs(bossRows) do r:Hide() end
    for _, r in ipairs(lootRows) do r:Hide() end
    filterBar:Hide()
    local y, nLoot = 0, 0
    for i, s in ipairs(Sources(instance)) do
        local row = BossRow(i)
        local open = s.key == selected
        local visible = Visible(s.items)
        row.key = s.key
        ns.DungeonPins.StylePin(row.pin, s.rare and "rare" or "boss", s.number, s.display)
        row.name:SetText(s.name or "")
        row.name:SetTextColor(unpack(open and ns.UI.ACCENT or ns.UI.TEXT))
        row.bg:SetColorTexture(unpack(open and SELECTED_BG or ROW_BG))
        row.bar:SetShown(open)
        row.count:SetText(#s.items == 0 and "" or #visible == 1 and L["1 item"] or L["%d items"]:format(#visible))
        Place(row, y)
        row:Show()
        y = y + BOSS_ROW + GAP
        if open then
            Place(filterBar, y + 2, 8)
            filterBar:Show()
            y = y + 24 + GAP + 4
            for _, entry in ipairs(visible) do
                nLoot = nLoot + 1
                local loot = LootRow(nLoot)
                FillLoot(loot, entry)
                Place(loot, y, 8)
                loot:Show()
                y = y + LOOT_ROW + GAP
            end
            y = y + 6
        end
    end
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", list.child, "TOPLEFT", 2, -(y + 6))
    note:SetPoint("RIGHT", list.child, "RIGHT", -2, 0)
    list.child:SetHeight(y + 40)
end

-- Quest tab ---------------------------------------------------------------------------------------
-- All quests of the dungeon (Quests/DungeonQuests.lua) for this race/class: ready to turn in, open (in
-- the quest log), not done yet (with giver and zone; click = map pin on the giver), completed.

local QUEST_ROW = 44
local questRows = {}
local YELLOW = { 1, 0.82, 0 }
local ORDER = { ready = 1, open = 2, avail = 3, done = 4 }

local function ForPlayer(q)
    local race, class = select(3, UnitRace("player")), select(3, UnitClass("player"))
    if q.races ~= 0 and q.races ~= 255 and race and bit.band(q.races, bit.lshift(1, race - 1)) == 0 then return false end
    if q.classes ~= 0 and class and bit.band(q.classes, bit.lshift(1, class - 1)) == 0 then return false end
    return true
end

-- Race bit masks: Alliance = human, dwarf, night elf, gnome; Horde = orc, undead, tauren, troll
local ALLIANCE_RACES, HORDE_RACES = 77, 178
local function QuestFaction(q)
    local r = q.races or 0
    if r == 0 or (bit.band(r, ALLIANCE_RACES) ~= 0 and bit.band(r, HORDE_RACES) ~= 0) then return { "alliancesymbol", "hordesymbol" } end
    return bit.band(r, HORDE_RACES) ~= 0 and { "hordesymbol" } or { "alliancesymbol" }
end

local function QuestState(id)
    if C_QuestLog.GetLogIndexForQuestID(id) then return C_QuestLog.IsComplete(id) and "ready" or "open" end
    if C_QuestLog.IsQuestFlaggedCompleted(id) then return "done" end
    return "avail"
end

-- Giver position from continent + world x/y (map pin and zone name)
-- (continent first, then the zone at that spot, coordinates in that zone)
local function GiverPlace(q)
    if not (q.map and C_Map.GetMapPosFromWorldPos) then return end
    local world = CreateVector2D(q.x, q.y)
    local ok, uiMap, pos = pcall(C_Map.GetMapPosFromWorldPos, q.map, world)
    if not (ok and uiMap and pos) then return end
    local zone = C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(uiMap, pos.x, pos.y)
    if zone and zone.mapID and zone.mapID ~= uiMap then
        local ok2, zoneMap, zonePos = pcall(C_Map.GetMapPosFromWorldPos, q.map, world, zone.mapID)
        if ok2 and zoneMap and zonePos then return zoneMap, zonePos end
    end
    return uiMap, pos
end

local function QuestTitle(q)
    local title = C_QuestLog.GetTitleForQuestID(q.id)
    if not title or title == "" then
        if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(q.id) end
        title = q.title
    end
    return title
end

local function QuestSub(q, state)
    if state == "ready" then return L["Ready to turn in"] end
    if state == "done" then return L["Completed"] end
    if state == "open" then
        for _, o in ipairs(C_QuestLog.GetQuestObjectives(q.id) or {}) do
            if not o.finished and o.text and o.text ~= "" then return L["In your quest log"] .. "  ·  " .. o.text end
        end
        return L["In your quest log"]
    end
    if q.item then
        return L["Starts from an item: %s"]:format(C_Item.GetItemNameByID(q.item) or ("#" .. q.item))
    end
    -- new Forever quests: only the giver's zone is known (no position)
    local uiMap = GiverPlace(q) or q.zone
    local info = uiMap and C_Map.GetMapInfo(uiMap)
    if not q.giver then return info and info.name or "" end
    return L["Quest giver: %s"]:format(q.giver) .. (info and ("  ·  " .. info.name) or "")
end

local function QuestRow(i)
    if questRows[i] then return questRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(QUEST_ROW)
    row.bg = ns.UI.Card(row)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    row.badge = UI.Text(row, 18, "CENTER")
    ns.SetFont(row.badge, 18, "OUTLINE", "bold")
    row.badge:SetShadowOffset(0, 0)
    row.badge:SetPoint("CENTER", row, "LEFT", 18, 0)
    row.check = UI.Icon(row, "Check", 16, UI.ACCENT)
    row.check:SetPoint("CENTER", row, "LEFT", 18, 0)
    row.cross = UI.Icon(row, "Close", 12, { 0.75, 0.35, 0.3 })
    row.cross:SetPoint("CENTER", row, "LEFT", 18, 0)
    row.name = UI.Text(row, 13, "LEFT")
    ns.SetFont(row.name, 13, "", "bold")
    row.name:SetPoint("TOPLEFT", 36, -7)
    row.name:SetWordWrap(false)
    row.factions = {}
    for k = 1, 2 do
        local tex = row:CreateTexture(nil, "ARTWORK")
        tex:SetSize(16, 16)
        row.factions[k] = tex
    end
    row.factions[1]:SetPoint("TOPRIGHT", -6, -5)
    row.factions[2]:SetPoint("RIGHT", row.factions[1], "LEFT", -1, 0)
    row.sub = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.sub:SetPoint("BOTTOMLEFT", 36, 7)
    row.sub:SetPoint("RIGHT", -8, 0)
    row.sub:SetWordWrap(false)
    row:SetScript("OnClick", function(self)
        local q, state = self.quest, self.state
        if state == "open" or state == "ready" then
            C_SuperTrack.SetSuperTrackedQuestID(q.id)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        elseif state == "avail" then
            local uiMap, pos = GiverPlace(q)
            if not (uiMap and pos) then return end
            local target = { name = q.giver, uiMapID = uiMap, x = pos.x * 100, y = pos.y * 100 }
            local set = ns.Questie and ns.Questie.SetWaypoint and ns.Questie.SetWaypoint(target)
            if not set and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(uiMap) then
                C_Map.SetUserWaypoint({ uiMapID = uiMap, position = pos })
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                set = true
            end
            if set then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
        end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(self.name:GetText() or "", 1, 1, 1)
        GameTooltip:AddLine(self.sub:GetText() or "", 0.6, 0.59, 0.56, true)
        if self.state == "avail" and self.quest.map then
            local uiMap, pos = GiverPlace(self.quest)
            local info = uiMap and C_Map.GetMapInfo(uiMap)
            if info and pos then
                GameTooltip:AddLine(("%s  %.1f, %.1f"):format(info.name, pos.x * 100, pos.y * 100), 1, 1, 1)
            end
        end
        local hint = (self.state == "open" or self.state == "ready") and L["Click: active quest in the tracker"]
            or (self.state == "avail" and self.quest.map and L["Click: map pin on the quest giver"])
        if hint then GameTooltip:AddLine(hint, 0.56, 0.8, 0.71) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    questRows[i] = row
    return row
end

local function QuestLayout(instance)
    note:SetText(QUEST_NOTE)
    local list_ = {}
    for _, q in ipairs(ns.DUNGEON_QUESTS and ns.DUNGEON_QUESTS[instance] or {}) do
        if ForPlayer(q) then list_[#list_ + 1] = { q = q, state = QuestState(q.id) } end
    end
    table.sort(list_, function(a, b)
        if a.state ~= b.state then return ORDER[a.state] < ORDER[b.state] end
        return a.q.level < b.q.level
    end)
    for _, r in ipairs(questRows) do r:Hide() end
    local y = 0
    for i, e in ipairs(list_) do
        local row, q, state = QuestRow(i), e.q, e.state
        row.quest, row.state = q, state
        -- done: sage check; not done yet: X; in the quest log: yellow ! (open) or ? (ready)
        local done = state == "done"
        row.check:SetShown(done)
        row.cross:SetShown(state == "avail")
        row.badge:SetShown(state == "open" or state == "ready")
        row.badge:SetText(state == "ready" and "?" or "!")
        row.badge:SetTextColor(unpack(YELLOW))
        local atlases = QuestFaction(q)
        for k, tex in ipairs(row.factions) do
            tex:SetShown(atlases[k] ~= nil)
            if atlases[k] then tex:SetAtlas(atlases[#atlases - k + 1]) end
        end
        row.name:SetPoint("RIGHT", row.factions[#atlases], "LEFT", -4, 0)
        local color = q.level > 0 and GetQuestDifficultyColor and GetQuestDifficultyColor(q.level)
        local level = q.level <= 0 and "" or color and ("|cff%02x%02x%02x[%d]|r "):format(color.r * 255, color.g * 255, color.b * 255, q.level) or ("[%d] "):format(q.level)
        row.name:SetText(level .. (QuestTitle(q) or ""))
        row.name:SetTextColor(unpack(ns.UI.TEXT))
        row.sub:SetText(QuestSub(q, state))
        row:SetAlpha(1)
        Place(row, y)
        row:Show()
        y = y + QUEST_ROW + GAP
    end
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", list.child, "TOPLEFT", 2, -(y + 6))
    note:SetPoint("RIGHT", list.child, "RIGHT", -2, 0)
    list.child:SetHeight(y + 40)
end

local function UpdateHeader()
    wishButton.text:SetText(ns.Wishlist.Count())
    local open = ns.Wishlist.IsWindowShown()
    for _, e in ipairs(wishButton.edges) do e:SetVertexColor(unpack(open and GOLD or BLACK)) end
    TabStyle(bossTab, current == "bosses")
    TabStyle(questTab, current == "quests")
    TabStyle(filterBar.mine, FilterMine())
    TabStyle(filterBar.all, not FilterMine())
end

function P.Selected() return frame and frame:IsShown() and selected or nil end

function P.Refresh()
    if not frame then return end
    local view = ns.DungeonMapView
    local instance = view and view.IsShown() and view.instance
    local active = instance and READY[instance] and ns.DUNGEON_LOOT[instance] ~= nil or false
    frame:SetShown(active)
    for _, f in ipairs(hiddenFrames) do f:SetAlpha(active and 0 or 1) end
    if not active then return end
    if instance ~= shownInstance then selected, shownInstance = nil, instance end
    local hasQuests = ns.DUNGEON_QUESTS and ns.DUNGEON_QUESTS[instance] ~= nil
    questTab:SetEnabled(hasQuests)
    if not hasQuests then current = "bosses" end
    UpdateHeader()
    if current == "quests" then
        for _, r in ipairs(bossRows) do r:Hide() end
        for _, r in ipairs(lootRows) do r:Hide() end
        filterBar:Hide()
        QuestLayout(instance)
    else
        for _, r in ipairs(questRows) do r:Hide() end
        Layout(instance)
    end
end

-- Called by a boss pin click (Map/DungeonPins.lua) or a list row; nil closes the open boss
function P.Select(key)
    selected = key
    if key then current = "bosses" end
    PlaySound(key and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    P.Refresh()
    if ns.DungeonPins then ns.DungeonPins.Refresh() end
end

-- Build over the quest log column. topLeft/bottomRight = corner frames of that column; hide = the
-- quest log's own widgets (faded out while the panel shows, so nothing shines through)
function P.Attach(parent, topLeft, bottomRight, hide)
    local UI = ns.UI
    hiddenFrames = hide or {}
    frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", topLeft, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMRIGHT", 8, 0)
    frame:SetFrameLevel(parent:GetFrameLevel() + 50)
    frame:EnableMouse(true)
    frame:Hide()

    bossTab = SmallButton(frame, L["Bosses"], 10, 30)
    bossTab:SetPoint("TOPLEFT")
    questTab = SmallButton(frame, L["Quests"], 10, 30)
    questTab:SetPoint("TOPRIGHT", -70, 0)
    bossTab:SetPoint("RIGHT", questTab, "LEFT", -6, 0)
    frame:SetScript("OnSizeChanged", function(_, w) questTab:SetWidth(math.max((w - 70 - 6) / 2, 10)) end)
    for key, b in pairs({ bosses = bossTab, quests = questTab }) do
        ns.SetFont(b.text, 13, "", "bold")
        b:SetScript("OnClick", function()
            current = key
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            P.Refresh()
        end)
    end

    wishButton = SmallButton(frame, "0", 64, 30)
    wishButton:SetPoint("TOPRIGHT")
    wishButton.text:ClearAllPoints()
    wishButton.text:SetPoint("LEFT", wishButton, "CENTER", 0, 0)
    wishButton.text:SetTextColor(unpack(GOLD))
    ns.SetFont(wishButton.text, 13, "", "bold")
    local star = UI.Icon(wishButton, "Star", 14, GOLD)
    star:SetPoint("RIGHT", wishButton, "CENTER", -4, 0)
    wishButton:SetScript("OnClick", function()
        ns.Wishlist.ToggleWindow()
        UpdateHeader()
    end)
    wishButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Wishlist"], 1, 1, 1)
        GameTooltip:Show()
    end)
    wishButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    list = UI.ScrollArea(frame)
    list:SetPoint("TOPLEFT", bossTab, "BOTTOMLEFT", 0, -8)
    list:SetPoint("BOTTOMRIGHT", -8, 0)
    list.child:SetWidth(1)
    list:SetScript("OnSizeChanged", function(self, w) self.child:SetWidth(w) end)

    filterBar = CreateFrame("Frame", nil, list.child)
    filterBar:SetHeight(24)
    filterBar.mine = SmallButton(filterBar, L["For me"], 80, 24)
    filterBar.mine:SetPoint("LEFT")
    filterBar.all = SmallButton(filterBar, L["All"], 60, 24)
    filterBar.all:SetPoint("LEFT", filterBar.mine, "RIGHT", 4, 0)
    local function SetAll(all)
        if ns.char then ns.char.dungeonLootAll = all or nil end
        P.Refresh()
    end
    filterBar.mine:SetScript("OnClick", function() SetAll(false) end)
    filterBar.all:SetScript("OnClick", function() SetAll(true) end)

    note = UI.Text(list.child, 11, "LEFT", UI.MUTED)
    note:SetWordWrap(true)
    LOOT_NOTE = L["Drop chances from classic data, Forever can differ. Check mark: seen dropping in Forever."]
    QUEST_NOTE = L["Quest data from classic, Forever can differ."]
    -- quest log changes and late quest titles refresh the quest tab
    for _, event in ipairs({ "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT", "QUEST_TURNED_IN" }) do frame:RegisterEvent(event) end
    frame:SetScript("OnEvent", function(self)
        if self:IsShown() and current == "quests" and not self.pending then
            self.pending = true
            C_Timer.After(0.2, function() self.pending = nil; P.Refresh() end)
        end
    end)

    ns.Wishlist.AddListener(function()
        if frame:IsShown() then P.Refresh() end
    end)
    parent:HookScript("OnHide", function() ns.Wishlist.HideWindow() end)
end
