-- Fishing bag (WoW Forever): opens when a fishing pole is equipped, closes when it is taken off.
--
--   +-[pole] Fishing bag ----------------------------- [x]-+
--   |        Westfall · session 49 min                      |
--   | [Bag] [Logbook]                                       |
--   | Fishing  ======================------   187 / 225 (+25)|
--   | [Lure 6:42] [Catches 34] [Per hour 41]                |
--   | Lures  [o][o][o]                                       |
--   | This session                                          |
--   | [][][][][][][][]                                      |
--   |                                       [New session]   |
--   +-------------------------------------------------------+
--
-- The bag is a view: catches stay in the real bags. Slots and lure buttons get secure overlays
-- (SecureActionButtonTemplate, parented to UIParent so the window itself never becomes protected,
-- shown out of combat only): right-click uses an item, a lure click applies it to the pole
-- ("target-slot" 16, see SecureTemplates.lua). Data per character in ns.char.fishing.
-- Comfort option: double right-click in the world casts Fishing (override binding, out of combat).
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT = 400, 560
local PAD = ns.NPC_PAD or 18
local POLE_SLOT = 16
local POLE_CLASS, POLE_SUBCLASS = 2, 20
local SESSION_IDLE = 3600 -- a new fishing trip starts after an hour without a catch
local COLS, SLOT, GAP = 8, 40, 5
local LOG_ROWS = 10
-- Fishing lures: item -> skill bonus (Classic/Forever)
local LURES = {
    [6529] = 25,  -- Shiny Bauble
    [6530] = 50,  -- Nightcrawlers
    [6532] = 75,  -- Bright Baubles
    [7307] = 75,  -- Flesh Eating Worm
    [6533] = 100, -- Aquadynamic Fish Attractor
    [6811] = 50,  -- Aquadynamic Fish Lens
}

local F = {}
ns.Fishing = F
local window, pages, tabs = nil, {}, {}
local tab, zoneFilter = "bag", "here"
local demo -- preview data while /mui t runs

local function Enabled() return ns.IS_FOREVER and ns.db and ns.db.fishingBag ~= false end

local function Data()
    ns.char.fishing = ns.char.fishing or {}
    local d = ns.char.fishing
    d.session = d.session or { start = time(), last = 0, catches = 0, items = {}, order = {} }
    d.log = d.log or {}
    d.tries = d.tries or {}
    return d
end

local function PoleEquipped()
    local id = GetInventoryItemID("player", POLE_SLOT)
    if not id then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(id)
    return classID == POLE_CLASS and subclassID == POLE_SUBCLASS
end
F.PoleEquipped = PoleEquipped
F.Enabled = function() return Enabled() end

local function MapID() return C_Map.GetBestMapForUnit("player") end

local function MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or (GetRealZoneText() or "")
end

-- Fishing skill: rank, max, bonus (pole + lure)
local function Skill()
    if not GetProfessions then return end
    local _, _, _, fish = GetProfessions()
    if not fish then return end
    local _, _, rank, maxRank, _, _, _, modifier = GetProfessionInfo(fish)
    return rank or 0, maxRank or 0, modifier or 0
end

-- Seconds left on the pole's temporary enchant (lure), nil without one
local function LureLeft()
    local info
    if C_Item.GetWeaponEnchantInfo and Enum.WeaponSlot then
        local result = C_Item.GetWeaponEnchantInfo(Enum.WeaponSlot.MainHand)
        if type(result) == "table" then info = result.hasEnchant ~= nil and result or result[1] end
        if info and info.hasEnchant and info.timeLeft then return info.timeLeft / 1000 end
        if info then return nil end
    end
    if GetWeaponEnchantInfo then
        local has, expiration = GetWeaponEnchantInfo()
        if has and expiration then return expiration / 1000 end
    end
end

local function Clock(seconds)
    seconds = math.max(math.floor(seconds or 0), 0)
    if seconds >= 3600 then return ("%d:%02d h"):format(seconds / 3600, (seconds % 3600) / 60) end
    return ("%d:%02d"):format(seconds / 60, seconds % 60)
end

local function QualityColor(quality)
    local c = quality and ITEM_QUALITY_COLORS[quality]
    if c then return c.r, c.g, c.b end
    return 0.91, 0.9, 0.87
end

-- First bag slot holding an item (for tooltip, drag, use)
local function FindInBags(itemID)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            if C_Container.GetContainerItemID(bag, slot) == itemID then return bag, slot end
        end
    end
end

-- Recording ----------------------------------------------------------------------------------

local rareRecent = {} -- itemID -> GetTime() of a fishing catch (rare toast title)

local function NewSession()
    Data().session = { start = time(), last = 0, catches = 0, items = {}, order = {} }
end

local function Record(entries)
    local d = Data()
    local s = d.session
    if s.last > 0 and time() - s.last > SESSION_IDLE then NewSession(); s = d.session end
    local mapID = MapID() or 0
    d.log[mapID] = d.log[mapID] or {}
    d.tries[mapID] = d.tries[mapID] or { caught = 0, escaped = 0 }
    d.tries[mapID].caught = d.tries[mapID].caught + 1
    s.catches = s.catches + 1
    s.last = time()
    for _, e in ipairs(entries) do
        if not s.items[e.id] then s.order[#s.order + 1] = e.id end
        s.items[e.id] = (s.items[e.id] or 0) + e.count
        d.log[mapID][e.id] = (d.log[mapID][e.id] or 0) + e.count
        if e.quality and e.quality >= Enum.ItemQuality.Uncommon then
            rareRecent[e.id] = GetTime()
            if not d.best or e.quality > d.best.quality or (e.quality == d.best.quality) then
                d.best = { id = e.id, quality = e.quality, time = time() }
            end
        end
    end
end

-- Read the loot before it is taken: fast loot (FastLoot.lua) loots on LOOT_READY, so by LOOT_OPENED
-- the slots can already be empty (depends on latency). FastLoot calls F.Capture first; LOOT_READY
-- and LOOT_OPENED are fallbacks. One capture per loot window.
local captured = 0 -- GetTime() of the last capture; time limit in case LOOT_CLOSED is missed
ns:On("LOOT_CLOSED", function() captured = 0 end)

function F.Capture()
    if GetTime() - captured < 3 or not (ns.IS_FOREVER and ns.char and IsFishingLoot and IsFishingLoot()) then return end
    local entries = {}
    for i = 1, GetNumLootItems() do
        local link = GetLootSlotLink(i)
        local _, _, quantity, _, quality = GetLootSlotInfo(i)
        if link and not issecretvalue(link) and not issecretvalue(quantity) then
            local id = C_Item.GetItemInfoInstant(link)
            if id then entries[#entries + 1] = { id = id, count = quantity or 1, quality = quality } end
        end
    end
    if #entries == 0 then return end
    captured = GetTime()
    Record(entries)
    if window and window:IsShown() then F.Refresh() end
end
ns:On("LOOT_READY", function() F.Capture() end)
ns:On("LOOT_OPENED", function() F.Capture() end)

-- "Your fish got away": counts as a try in this zone (escape rate in the logbook)
ns:On("UI_ERROR_MESSAGE", function(_, _, message)
    if not (ns.char and ERR_FISH_ESCAPED) or issecretvalue(message) or message ~= ERR_FISH_ESCAPED then return end
    local d = Data()
    local mapID = MapID() or 0
    d.tries[mapID] = d.tries[mapID] or { caught = 0, escaped = 0 }
    d.tries[mapID].escaped = d.tries[mapID].escaped + 1
end)

-- Loot toasts (Toasts/Toasts.lua): title for green+ items just caught while fishing
function ns.FishingToastTitle(link)
    local id = link and C_Item.GetItemInfoInstant(link)
    local seen = id and rareRecent[id]
    if seen and GetTime() - seen < 15 then return L["Rare catch!"] end
end

-- Secure overlays ------------------------------------------------------------------------------
-- One pool for slot and lure buttons. Attributes and visibility only change out of combat.

local overlays = {}

local function Overlay(owner)
    local o = overlays[owner]
    if o then return o end
    o = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    o:SetFrameStrata("DIALOG")
    o:RegisterForClicks("AnyUp", "AnyDown")
    o:RegisterForDrag("LeftButton")
    local hover = o:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    o:SetScript("OnEnter", function() owner:GetScript("OnEnter")(owner) end)
    o:SetScript("OnLeave", function() GameTooltip:Hide() end)
    o:SetScript("OnDragStart", function()
        if not owner.itemID or InCombatLockdown() then return end
        local bag, slot = FindInBags(owner.itemID)
        if bag then C_Container.PickupContainerItem(bag, slot) end
    end)
    o:HookScript("OnClick", function(_, button, down)
        if down or button ~= "LeftButton" or not IsModifiedClick("CHATLINK") then return end
        local link = owner.itemID and select(2, C_Item.GetItemInfo(owner.itemID))
        if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) end
    end)
    o:Hide()
    overlays[owner] = o
    return o
end

local function SyncOverlays()
    if InCombatLockdown() then return end
    local visible = window and window:IsVisible()
    for owner, o in pairs(overlays) do
        local want = visible and owner:IsVisible() and owner.itemID ~= nil and owner:GetLeft() ~= nil
        if want then
            -- Protected frames may not be anchored to our (unprotected) buttons: place by coordinates
            local k = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
            o:ClearAllPoints()
            o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", owner:GetLeft() * k, owner:GetTop() * k)
            o:SetSize(owner:GetWidth() * k, owner:GetHeight() * k)
            if owner.lure then
                o:SetAttribute("type", "item")
                o:SetAttribute("item", "item:" .. owner.itemID)
                o:SetAttribute("target-slot", POLE_SLOT)
            else
                o:SetAttribute("type", nil)
                o:SetAttribute("type2", "item")
                o:SetAttribute("item2", "item:" .. owner.itemID)
                o:SetAttribute("target-slot", nil)
            end
        end
        o:SetShown(want)
    end
end
ns:On("PLAYER_REGEN_ENABLED", function() SyncOverlays() end)
ns:On("PLAYER_REGEN_DISABLED", function()
    for _, o in pairs(overlays) do
        o:Hide()
        o:ClearAllPoints() -- the window may be dragged in combat; protected frames must not follow
    end
end)

-- Widgets -------------------------------------------------------------------------------------

local function ItemButton(parent, size)
    local UI = ns.UI
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(size, size)
    b:EnableMouse(true)
    ns.AddSlotBackground(b)
    b.edges = ns.AddBorder(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = ns.CreateText(b, 12, "RIGHT", "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    b:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local bag, slot = FindInBags(self.itemID)
        if bag then GameTooltip:SetBagItem(bag, slot) else GameTooltip:SetItemByID(self.itemID) end
        if self.hint then GameTooltip:AddLine(self.hint, UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3]) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function b:SetItem(itemID, count, hint)
        self.itemID, self.hint = itemID, hint
        if not itemID then
            self.icon:SetTexture(nil)
            self.count:SetText("")
            for _, e in ipairs(self.edges) do e:SetVertexColor(0, 0, 0, 1) end
            return
        end
        self.icon:SetTexture(C_Item.GetItemIconByID(itemID))
        self.count:SetText(count and count > 1 and count or "")
        local quality = C_Item.GetItemQualityByID(itemID)
        local r, g, bl = QualityColor(quality)
        local colored = quality and quality ~= Enum.ItemQuality.Common
        for _, e in ipairs(self.edges) do
            if colored then e:SetVertexColor(r, g, bl, 1) else e:SetVertexColor(0, 0, 0, 1) end
        end
    end
    return b
end

local function Tile(parent, label)
    local UI = ns.UI
    local t = CreateFrame("Frame", nil, parent)
    t:SetHeight(42)
    UI.Box(t, { 0.04, 0.05, 0.05, 0.9 })
    ns.AddBorder(t)
    t.label = UI.Text(t, 11, "LEFT", UI.MUTED)
    t.label:SetPoint("TOPLEFT", 9, -6)
    t.label:SetText(label)
    t.value = UI.Text(t, 14, "LEFT")
    ns.SetFont(t.value, 14, "", "bold")
    t.value:SetPoint("BOTTOMLEFT", 9, 6)
    return t
end

local function Chip(parent, label, onClick)
    local UI = ns.UI
    local c = CreateFrame("Button", nil, parent)
    c:SetHeight(26)
    UI.Box(c)
    c.edges = ns.AddBorder(c, true)
    for _, e in ipairs(c.edges) do e:SetVertexColor(unpack(UI.ACCENT)) end
    c.text = UI.Text(c, 13, "CENTER")
    c.text:SetPoint("CENTER")
    local hover = c:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.05)
    c:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        onClick()
    end)
    function c:SetLabel(text)
        self.text:SetText(text)
        self:SetWidth(math.max(self.text:GetUnboundedStringWidth() + 24, 60))
    end
    function c:SetActive(on)
        for _, e in ipairs(self.edges) do e:SetShown(on) end
        self.text:SetTextColor(unpack(on and UI.ACCENT or UI.MUTED))
    end
    c:SetLabel(label)
    return c
end

-- Pages -----------------------------------------------------------------------------------------

local TOP = (ns.NPC_HEADER_BOTTOM or 64) + 14 + 26 + 14 -- below header and tabs

local function CreateBag(page)
    local UI = ns.UI
    local skillLabel = UI.Text(page, 13, "LEFT", UI.MUTED)
    skillLabel:SetPoint("TOPLEFT", PAD, -TOP)
    skillLabel:SetText(PROFESSIONS_FISHING or L["Fishing"])
    page.skill = UI.Text(page, 13, "RIGHT")
    ns.SetFont(page.skill, 13, "", "bold")
    page.skill:SetPoint("TOPRIGHT", -PAD, -TOP)
    local bar = CreateFrame("Frame", nil, page)
    bar:SetPoint("TOPLEFT", PAD, -TOP - 20)
    bar:SetPoint("TOPRIGHT", -PAD, -TOP - 20)
    bar:SetHeight(8)
    UI.Box(bar, { 0.04, 0.05, 0.05, 1 })
    ns.AddBorder(bar)
    page.fill = bar:CreateTexture(nil, "ARTWORK")
    page.fill:SetPoint("TOPLEFT")
    page.fill:SetPoint("BOTTOMLEFT")
    page.fill:SetColorTexture(unpack(UI.ACCENT))
    page.bar = bar

    local tileW = (WIDTH - 2 * PAD - 12) / 3
    page.lure = Tile(page, L["Lure"])
    page.catches = Tile(page, L["Catches"])
    page.rate = Tile(page, L["Per hour"])
    for i, t in ipairs({ page.lure, page.catches, page.rate }) do
        t:SetWidth(tileW)
        t:SetPoint("TOPLEFT", PAD + (i - 1) * (tileW + 6), -TOP - 40)
    end

    -- Lure bar: every lure in the bags; click applies it to the pole
    local lureLabel = UI.Text(page, 13, "LEFT", UI.MUTED)
    lureLabel:SetPoint("TOPLEFT", PAD, -TOP - 100)
    lureLabel:SetText(L["Lures"])
    page.lureLabel = lureLabel
    page.lureNone = UI.Text(page, 12, "LEFT", { 0.36, 0.39, 0.38 })
    page.lureNone:SetPoint("LEFT", lureLabel, "RIGHT", 12, 0)
    page.lureNone:SetText(L["No lures in your bags"])
    page.lures = {}
    for i = 1, 6 do
        local b = ItemButton(page, 32)
        b.lure = true
        b:SetPoint("LEFT", lureLabel, "LEFT", 70 + (i - 1) * 38, 0)
        page.lures[i] = b
        Overlay(b)
    end

    local sessionLabel = UI.Text(page, 13, "LEFT", UI.MUTED)
    sessionLabel:SetPoint("TOPLEFT", PAD, -TOP - 140)
    sessionLabel:SetText(L["This fishing trip"])
    page.since = UI.Text(page, 12, "RIGHT", { 0.36, 0.39, 0.38 })
    page.since:SetPoint("TOPRIGHT", -PAD, -TOP - 141)
    page.slots = {}
    for i = 1, COLS * 4 do
        local b = ItemButton(page, SLOT)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        b:SetPoint("TOPLEFT", PAD + col * (SLOT + GAP), -TOP - 162 - row * (SLOT + GAP))
        page.slots[i] = b
        Overlay(b)
    end
    page.hint = UI.Text(page, 11, "LEFT", { 0.36, 0.39, 0.38 })
    page.hint:SetPoint("TOPLEFT", PAD, -TOP - 162 - 4 * (SLOT + GAP) - 2)
    page.hint:SetText(L["Right-click: use · drag: into trade or bag"])

    local reset = UI.Button(page, L["New fishing trip"], function()
        NewSession()
        F.Refresh()
    end, WIDTH - 2 * PAD)
    reset:SetHeight(28)
    reset:SetPoint("BOTTOMLEFT", PAD, PAD)
end

local function RefreshBag(page)
    local d = demo or Data()
    local s = d.session
    local rank, maxRank, bonus = Skill()
    if demo then rank, maxRank, bonus = 187, 225, 25 end
    if rank and maxRank and maxRank > 0 then
        page.skill:SetText(("%d / %d"):format(rank, maxRank) .. (bonus > 0 and ("  |cff8ecbb4+" .. bonus .. "|r") or ""))
        page.fill:SetWidth(math.max(page.bar:GetWidth() * rank / maxRank, 0.01))
    else
        page.skill:SetText("–")
        page.fill:SetWidth(0.01)
    end
    local left = demo and 402 or LureLeft()
    page.lure.value:SetText(left and Clock(left) or L["None"])
    page.lure.value:SetTextColor(unpack(left and { 0.85, 0.71, 0.42 } or ns.UI.MUTED))
    page.catches.value:SetText(s.catches)
    local elapsed = math.max(time() - s.start, 600)
    page.rate.value:SetText(s.catches > 0 and math.floor(s.catches / elapsed * 3600 + 0.5) or "–")
    page.since:SetText(s.catches > 0 and L["for %d min"]:format(math.floor((time() - s.start) / 60)) or "")

    -- lures in the bags (known list), sorted by bonus
    local found = {}
    if demo then
        found = { { id = 6529, count = 8 }, { id = 6530, count = 3 } }
    else
        for id, bonus2 in pairs(LURES) do
            local count = C_Item.GetItemCount(id)
            if count > 0 then found[#found + 1] = { id = id, count = count, bonus = bonus2 } end
        end
        table.sort(found, function(a, b) return a.bonus > b.bonus end)
    end
    for i, b in ipairs(page.lures) do
        local e = found[i]
        b:SetShown(e ~= nil)
        if e then b:SetItem(e.id, e.count, L["Click: put on the fishing pole"] .. "  (+" .. (LURES[e.id] or 0) .. ")") end
    end
    page.lureNone:SetShown(#found == 0)

    for i, b in ipairs(page.slots) do
        local id = s.order[i]
        b:SetItem(id, id and s.items[id])
    end
end

local function CreateLog(page)
    local UI = ns.UI
    page.here = Chip(page, "", function() zoneFilter = "here"; F.Refresh() end)
    page.here:SetPoint("TOPLEFT", PAD, -TOP)
    page.all = Chip(page, L["All zones"], function() zoneFilter = "all"; F.Refresh() end)
    page.all:SetPoint("LEFT", page.here, "RIGHT", 6, 0)
    page.total = UI.Text(page, 12, "RIGHT", UI.MUTED)
    page.total:SetPoint("RIGHT", page, "TOPRIGHT", -PAD, -TOP - 13)

    local info = CreateFrame("Frame", nil, page)
    info:SetPoint("TOPLEFT", PAD, -TOP - 38)
    info:SetPoint("TOPRIGHT", -PAD, -TOP - 38)
    info:SetHeight(32)
    UI.Box(info, { 0.04, 0.05, 0.05, 0.9 })
    ns.AddBorder(info)
    info.text = UI.Text(info, 12, "LEFT")
    info.text:SetPoint("LEFT", 10, 0)
    info.text:SetPoint("RIGHT", -10, 0)
    page.info = info

    page.rows = {}
    for i = 1, LOG_ROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetHeight(32)
        row:SetPoint("TOPLEFT", PAD, -TOP - 80 - (i - 1) * 34)
        row:SetPoint("TOPRIGHT", -PAD, -TOP - 80 - (i - 1) * 34)
        row.item = ItemButton(row, 26)
        row.item:SetPoint("LEFT")
        row.name = UI.Text(row, 13, "LEFT")
        row.name:SetPoint("TOPLEFT", row.item, "TOPRIGHT", 10, -1)
        row.name:SetPoint("RIGHT", -96, 0)
        row.name:SetWordWrap(false)
        row.count = UI.Text(row, 13, "RIGHT")
        ns.SetFont(row.count, 13, "", "bold")
        row.count:SetPoint("TOPRIGHT", -44, -1)
        row.share = UI.Text(row, 11, "RIGHT", UI.MUTED)
        row.share:SetPoint("RIGHT", 0, 0)
        local track = CreateFrame("Frame", nil, row)
        track:SetPoint("BOTTOMLEFT", row.item, "BOTTOMRIGHT", 10, 2)
        track:SetPoint("RIGHT", -44, 0)
        track:SetHeight(3)
        UI.Box(track, { 0.1, 0.1, 0.11, 1 })
        row.bar = track:CreateTexture(nil, "ARTWORK")
        row.bar:SetPoint("TOPLEFT")
        row.bar:SetPoint("BOTTOMLEFT")
        row.bar:SetColorTexture(unpack(UI.ACCENT))
        row.track = track
        page.rows[i] = row
    end
    page.empty = UI.Text(page, 12, "LEFT", UI.MUTED)
    page.empty:SetPoint("TOPLEFT", PAD, -TOP - 86)
    page.empty:SetText(L["Nothing caught here yet."])

    page.best = UI.Text(page, 12, "LEFT", UI.MUTED)
    page.best:SetPoint("BOTTOMLEFT", PAD, PAD + 4)
    page.best:SetPoint("RIGHT", -PAD, 0)
end

local function RefreshLog(page)
    local d = demo or Data()
    local mapID = demo and 0 or (MapID() or 0)
    local zone = demo and "Westfall" or MapName(mapID)
    page.here:SetLabel(L["Here: %s"]:format(zone))
    page.here:SetActive(zoneFilter == "here")
    page.all:SetActive(zoneFilter == "all")
    page.all:ClearAllPoints()
    page.all:SetPoint("LEFT", page.here, "RIGHT", 6, 0)

    local counts = {}
    if zoneFilter == "here" then
        for id, n in pairs(d.log[mapID] or {}) do counts[id] = n end
    else
        for _, items in pairs(d.log) do
            for id, n in pairs(items) do counts[id] = (counts[id] or 0) + n end
        end
    end
    local list, total, max = {}, 0, 0
    for id, n in pairs(counts) do
        list[#list + 1] = { id = id, n = n }
        total, max = total + n, math.max(max, n)
    end
    table.sort(list, function(a, b) return a.n > b.n end)
    page.total:SetText(L["%s caught"]:format(BreakUpLargeNumbers(total)))

    page.info:SetShown(zoneFilter == "here")
    local tries = d.tries[mapID]
    local attempts = tries and (tries.caught + tries.escaped) or 0
    if attempts >= 10 then
        local rate = tries.escaped / attempts
        page.info.text:SetText(rate == 0 and ("|cff8ecbb4" .. L["Nothing gets away here anymore"] .. "|r")
            or L["Gets away here: %d %%"]:format(math.floor(rate * 100 + 0.5)))
    else
        page.info.text:SetText("|cff8a918e" .. L["Escape rate shows after 10 casts here"] .. "|r")
    end
    local top = TOP + (zoneFilter == "here" and 80 or 42)
    page.empty:SetPoint("TOPLEFT", PAD, -top - 6)
    for i, row in ipairs(page.rows) do
        local e = list[i]
        row:SetShown(e ~= nil)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", PAD, -top - (i - 1) * 34)
        row:SetPoint("TOPRIGHT", -PAD, -top - (i - 1) * 34)
        if e then
            row.item:SetItem(e.id)
            local name = C_Item.GetItemNameByID(e.id) or ""
            row.name:SetText(name)
            row.name:SetTextColor(QualityColor(C_Item.GetItemQualityByID(e.id)))
            row.count:SetText(BreakUpLargeNumbers(e.n))
            row.share:SetText(math.floor(e.n / total * 100 + 0.5) .. " %")
            row.bar:SetWidth(math.max(row.track:GetWidth() * e.n / max, 0.01))
        end
    end
    page.empty:SetShown(#list == 0)
    local best = d.best
    if best then
        local r, g, b = QualityColor(best.quality)
        page.best:SetText(L["Rarest catch:"] .. "  " .. ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
            .. (C_Item.GetItemNameByID(best.id) or "") .. "|r  |cff5d6462" .. date("%d.%m.", best.time) .. "|r")
    else
        page.best:SetText("")
    end
end

-- Window ----------------------------------------------------------------------------------------

local function Select(key)
    tab = key
    for k, page in pairs(pages) do page:SetShown(k == key) end
    for k, chip in pairs(tabs) do chip:SetActive(k == key) end
    F.Refresh()
end

local function CreateWindow()
    window = ns.CreateNpcWindow("MeredanUIFishing", WIDTH, HEIGHT, "fishing")
    window:SetNpc(nil, L["Fishing bag"], "", 136245)
    tabs.bag = Chip(window, L["Bag"], function() Select("bag") end)
    tabs.bag:SetPoint("TOPLEFT", PAD, -(ns.NPC_HEADER_BOTTOM or 64) - 14)
    tabs.log = Chip(window, L["Logbook"], function() Select("log") end)
    tabs.log:SetPoint("LEFT", tabs.bag, "RIGHT", 6, 0)
    pages.bag = CreateFrame("Frame", nil, window)
    pages.bag:SetAllPoints()
    CreateBag(pages.bag)
    pages.log = CreateFrame("Frame", nil, window)
    pages.log:SetAllPoints()
    CreateLog(pages.log)
    window:HookScript("OnShow", function(self)
        ns.ResetWindowPosition(self, "fishing", true)
        Select(tab)
    end)
    window:HookScript("OnHide", function() SyncOverlays() end)
    -- overlays sit at fixed coordinates: follow when the window was dragged
    window:HookScript("OnUpdate", function(self)
        local x, y = self:GetLeft(), self:GetTop()
        if x and (x ~= self.muiLastX or y ~= self.muiLastY) then
            self.muiLastX, self.muiLastY = x, y
            SyncOverlays()
        end
    end)
    -- lure timer and per-hour rate tick while open
    local elapsed = 0
    window:HookScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        if tab == "bag" then RefreshBag(pages.bag) end
    end)
end

function F.Refresh()
    if not (window and window:IsShown()) then return end
    local d = demo or Data()
    local s = d.session
    local zone = demo and "Westfall" or MapName(MapID())
    window.npcTitle:SetText(s.catches > 0 and (zone .. "  ·  " .. L["%d catches"]:format(s.catches)) or zone)
    if tab == "bag" then RefreshBag(pages.bag) else RefreshLog(pages.log) end
    C_Timer.After(0, SyncOverlays) -- after layout, so visibility is known
end

function F.Show()
    if not Enabled() then return end
    if not window then CreateWindow() end
    window:Show()
end

function F.Toggle()
    if not Enabled() then return ns.Print(L["The fishing bag is turned off (settings > Bags)."]) end
    if window and window:IsShown() then window:Hide() else F.Show() end
end

ns.AddCommand("angeln", L["open the fishing bag"], F.Toggle)

-- Pole on: open; pole off: close
local hadPole
local function CheckPole()
    if not Enabled() then return end
    local has = PoleEquipped()
    if has and not hadPole then F.Show()
    elseif not has and hadPole and window then window:Hide() end
    hadPole = has
end
ns:On("PLAYER_EQUIPMENT_CHANGED", function(_, slot) if slot == POLE_SLOT then CheckPole() end end)
ns:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(1, CheckPole) end)
ns:On("BAG_UPDATE_DELAYED", function() if window and window:IsShown() then F.Refresh() end end)
ns:On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" and window and window:IsShown() then F.Refresh() end end)

-- Double right-click casts Fishing (Comfort) ------------------------------------------------------
-- The second right press binds BUTTON2 to a secure cast button; its release casts, then the binding
-- is cleared. Only with a pole equipped and out of combat.
local caster, lastRight = nil, 0

local function FishingSpell() return C_Spell.GetSpellName(7620) end

local function Caster()
    if caster then return caster end
    caster = CreateFrame("Button", "MeredanUIFishingCast", UIParent, "SecureActionButtonTemplate")
    caster:RegisterForClicks("AnyUp", "AnyDown")
    caster:SetAttribute("useOnKeyDown", false)
    caster:SetAttribute("type", "spell")
    caster:HookScript("PostClick", function()
        C_Timer.After(0, function() if not InCombatLockdown() then ClearOverrideBindings(caster) end end)
    end)
    return caster
end

WorldFrame:HookScript("OnMouseDown", function(_, button)
    if button ~= "RightButton" or not (ns.IS_FOREVER and ns.db and ns.db.fishingDoubleClick) then return end
    if InCombatLockdown() or not PoleEquipped() or IsMounted() then return end
    local now = GetTime()
    if now - lastRight < 0.4 then
        local spell = FishingSpell()
        if spell then
            local b = Caster()
            b:SetAttribute("spell", spell)
            SetOverrideBindingClick(b, true, "BUTTON2", "MeredanUIFishingCast")
            C_Timer.After(1, function() if not InCombatLockdown() then ClearOverrideBindings(b) end end)
        end
        lastRight = 0
    else
        lastRight = now
    end
end)

-- Preview (/mui t) ------------------------------------------------------------------------------

ns.FishingDemo = {
    Start = function()
        if not ns.IS_FOREVER then return end
        demo = {
            session = { start = time() - 49 * 60, last = time(), catches = 34,
                items = { [6358] = 14, [6308] = 9, [6289] = 6, [6359] = 3, [6291] = 4, [6522] = 1 },
                order = { 6358, 6308, 6289, 6359, 6291, 6522 } },
            log = { [0] = { [6358] = 212, [6308] = 140, [6289] = 96, [6359] = 41, [6291] = 30, [6522] = 6 } },
            tries = { [0] = { caught = 120, escaped = 10 } },
            best = { id = 6522, quality = 2, time = time() - 86400 * 3 },
        }
        if not window then CreateWindow() end
        window:Show()
        F.Refresh()
    end,
    Stop = function()
        demo = nil
        if window then
            if PoleEquipped() then F.Refresh() else window:Hide() end
        end
    end,
    IsActive = function() return demo ~= nil end,
}
