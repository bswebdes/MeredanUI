-- Info bar at the bottom center of the screen (intentionally ignores the 25 px screen margin).
-- Outlined text only, no background. Fields are chosen in the settings; all fields share one
-- width and the bar grows with them (4 fields = width of the Shift bar).
--     [coins] 12.345    [bag] 42    [shield] 87 %    [gauge] 144
-- No labels: each field shows a small icon (spec field: the real spec icon).
local _, ns = ...
local L = ns.L

local HEIGHT = 18

local bar
local cells = {}
local sessionMoney = GetMoney()

-- Helpers ------------------------------------------------------------------------------------

-- Money as gold/silver/copper with colored suffixes ("1.234g 56s 78k"). Leading zero units are
-- dropped, inner ones kept (2g 0s 5k).
local COIN = { "|cffe6c35ag|r", "|cffc7cdd6s|r", "|cffd08a55k|r" }
local function Gold(copper)
    copper = math.max(math.floor(copper or 0), 0)
    local g, s, k = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return ("%s%s %d%s %d%s"):format(BreakUpLargeNumbers(g), COIN[1], s, COIN[2], k, COIN[3]) end
    if s > 0 then return ("%d%s %d%s"):format(s, COIN[2], k, COIN[3]) end
    return k .. COIN[3]
end

-- Shorter form for the bar: from 100 gold on, copper is omitted to keep the field narrow
local function GoldShort(copper)
    copper = math.max(math.floor(copper or 0), 0)
    if copper >= 1000000 then
        local g, s = math.floor(copper / 10000), math.floor(copper / 100) % 100
        return ("%s%s %d%s"):format(BreakUpLargeNumbers(g), COIN[1], s, COIN[2])
    end
    return Gold(copper)
end

-- Bag slots by type: only normal bags count for the field; quivers, ammo pouches and soul bags
-- are listed separately in the tooltip.
local SPECIAL_BAGS = { [1] = "Quiver", [2] = "Ammo pouch", [4] = "Soul bag" }
local function BagSlots()
    local normalFree, normalTotal, special = 0, 0, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local total = C_Container.GetContainerNumSlots(bag) or 0
        if total > 0 then
            local free, family = C_Container.GetContainerNumFreeSlots(bag)
            free, family = free or 0, family or 0
            if family == 0 then
                normalFree, normalTotal = normalFree + free, normalTotal + total
            else
                local key = SPECIAL_BAGS[family] or "Special bag"
                special[key] = special[key] or { free = 0, total = 0 }
                special[key].free = special[key].free + free
                special[key].total = special[key].total + total
            end
        end
    end
    return normalFree, normalTotal, special
end

local function FreeColor(free)
    if free == 0 then return "|cffff4040" end
    if free <= 4 then return "|cffffc040" end
    return "|cffffffff"
end

local function DurabilityColor(percent)
    if percent < 25 then return "|cffff4040" end
    if percent < 60 then return "|cffffc040" end
    return "|cffffffff"
end

-- Icons use the character's class color
local function ClassColor()
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS[class]
    if color then return { color.r, color.g, color.b } end
    return { 0.6, 0.59, 0.56 }
end

local function Line(label, value) GameTooltip:AddDoubleLine(label, value, 0.8, 0.8, 0.8, 1, 1, 1) end

-- Remember gold of all characters (for the tooltip)
local function SaveMoney()
    ns.root.gold = ns.root.gold or {}
    local _, class = UnitClass("player")
    ns.root.gold[ns.charKey] = { money = GetMoney(), class = class }
end

-- Fields: text() returns the content, tooltip/click optional -------------------------------

local FIELDS = {
    {
        key = "gold", label = L["Gold"], icon = "Gold",
        text = function() return GoldShort(GetMoney()) end,
        click = function() ToggleAllBags() end,
        tooltip = function()
            GameTooltip:AddLine(L["Gold"], 1, 1, 1)
            local diff = GetMoney() - sessionMoney
            Line(L["This session"], (diff < 0 and "|cffff6060-" or "|cff60ff60+") .. Gold(math.abs(diff)) .. "|r")
            GameTooltip:AddLine(" ")
            local list, total = {}, 0
            for name, info in pairs(ns.root.gold or {}) do
                list[#list + 1] = { name = name, info = info }
                total = total + info.money
            end
            table.sort(list, function(a, b) return a.info.money > b.info.money end)
            for _, entry in ipairs(list) do
                local color = entry.info.class and RAID_CLASS_COLORS[entry.info.class]
                local label = ns.CharDisplayName(entry.name) -- "Koratal (RP)" instead of the full realm name
                local name = color and color:WrapTextInColorCode(label) or label
                Line(name, Gold(entry.info.money))
            end
            GameTooltip:AddLine(" ")
            Line(L["Total"], Gold(total))
        end,
    },
    {
        key = "bags", label = L["Bags"], icon = "Bag",
        text = function()
            local free = BagSlots()
            return FreeColor(free) .. free .. "|r"
        end,
        click = function() ToggleAllBags() end,
        tooltip = function()
            local free, total, special = BagSlots()
            GameTooltip:AddLine(L["Bags"], 1, 1, 1)
            Line(L["Free slots"], ("%d/%d"):format(free, total))
            for _, key in ipairs({ "Quiver", "Ammo pouch", "Soul bag", "Special bag" }) do
                local info = special[key]
                if info then Line(L[key], ("%d/%d"):format(info.free, info.total)) end
            end
            local ammo = INVSLOT_AMMO and GetInventoryItemID("player", INVSLOT_AMMO)
            if ammo then
                Line(L["Ammo"], tostring(GetInventoryItemCount("player", INVSLOT_AMMO) or 0))
            end
        end,
    },
    {
        key = "durability", label = L["Durability"], icon = "Durability",
        text = function()
            local lowest = 100
            for slot = 1, 18 do
                local cur, max = GetInventoryItemDurability(slot)
                if cur and max and max > 0 then lowest = math.min(lowest, cur / max * 100) end
            end
            return DurabilityColor(lowest) .. math.floor(lowest) .. " %|r"
        end,
        click = function() ToggleCharacter("PaperDollFrame") end,
        tooltip = function()
            GameTooltip:AddLine(L["Durability"], 1, 1, 1)
            local any = false
            for slot = 1, 18 do
                local cur, max = GetInventoryItemDurability(slot)
                if cur and max and max > 0 and cur < max then
                    local link = GetInventoryItemLink("player", slot)
                    local percent = cur / max * 100
                    Line(link or "?", DurabilityColor(percent) .. math.floor(percent) .. " %|r")
                    any = true
                end
            end
            if not any then GameTooltip:AddLine(L["Everything is fully repaired."], 0.8, 0.8, 0.8) end
        end,
    },
    {
        -- Frame rate and latency in one field: "101 | 23 ms" (world latency, else home)
        key = "fps", label = "FPS · ms", icon = "FPS",
        text = function()
            local _, _, home, world = GetNetStats()
            local latency = world or home
            local fps = tostring(math.floor(GetFramerate() + 0.5))
            if type(latency) ~= "number" then return fps end
            return ("%s |cff999999·|r %d ms"):format(fps, latency)
        end,
        tooltip = function()
            local _, _, home, world = GetNetStats()
            GameTooltip:AddLine(L["Latency"], 1, 1, 1)
            if type(home) == "number" then Line(L["Home"], home .. " ms") end
            if type(world) == "number" then Line(L["World"], world .. " ms") end
        end,
    },
    {
        key = "spec", label = L["Spec"], specIcon = true,
        text = function()
            local index = C_SpecializationInfo.GetSpecialization()
            local name = index and select(2, C_SpecializationInfo.GetSpecializationInfo(index))
            return name or "–"
        end,
        tooltip = function()
            local loot = GetLootSpecialization and GetLootSpecialization() or 0
            local lootName = loot > 0 and select(2, GetSpecializationInfoByID(loot)) or L["Current specialization"]
            GameTooltip:AddLine(L["Spec"], 1, 1, 1)
            Line(L["Loot specialization"], lootName or "–")
        end,
    },
    {
        key = "guild", label = L["Guild"], icon = "Guild",
        text = function()
            if not IsInGuild() then return "–" end
            local _, online = GetNumGuildMembers()
            return tostring(online or 0)
        end,
        click = function() if ToggleGuildFrame then ToggleGuildFrame() end end,
    },
    {
        key = "friends", label = L["Friends"], icon = "Friends",
        text = function()
            local online = C_FriendList.GetNumOnlineFriends() or 0
            local _, bnetOnline = BNGetNumFriends()
            return tostring(online + (bnetOnline or 0))
        end,
        click = function() ToggleFriendsFrame(1) end,
    },
    {
        -- Forever only: skill of the primary weapon ("212/300"); tooltip lists all, primary first.
        -- Retail has no weapon skills, so the field is hidden there.
        key = "weaponskill", label = L["Weapon skill"], icon = "Combat", foreverOnly = true,
        text = function()
            local skill = ns.WeaponSkillFocus and ns.WeaponSkillFocus()
            if not skill then return "–" end
            local color = skill.rank >= skill.maxRank and "|cff999999" or "|cffffffff"
            return ("%s%d/%d|r"):format(color, skill.rank, skill.maxRank)
        end,
        click = function() ToggleCharacter("PaperDollFrame") end,
        tooltip = function()
            GameTooltip:AddLine(L["Weapon skills"], 1, 1, 1)
            for _, skill in ipairs(ns.WeaponSkills and ns.WeaponSkills() or {}) do
                local done = skill.rank >= skill.maxRank
                local name = skill.equipped and (skill.name .. " |cff8ecbb4•|r") or skill.name
                GameTooltip:AddDoubleLine(name, ("%d/%d"):format(skill.rank, skill.maxRank),
                    0.8, 0.8, 0.8, done and 0.5 or 1, done and 0.5 or 1, done and 0.5 or 1)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["• = equipped weapon"], 0.6, 0.6, 0.6)
        end,
    },
    {
        key = "time", label = L["Time"], icon = "Clock",
        text = function() return date("%H:%M") end,
        click = function() ToggleCalendar() end,
    },
}

-- Weapon skills (Forever) ---------------------------------------------------------------------
-- Weapon subclass -> skill line ID (Classic values)
local WEAPON_SKILL = {
    [0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43, [8] = 55,
    [10] = 136, [13] = 473, [15] = 173, [16] = 176, [18] = 226, [19] = 228,
}
local WEAPON_SLOTS = { 16, 17, 18 } -- main hand, off hand, ranged

-- Equipped weapon skills and the primary one: ranged for hunters, main hand for everyone else
-- (otherwise rogues would see their thrown weapon); falls back to the other slot.
local function EquippedSkillIDs()
    local ids = {}
    local primary = select(2, UnitClass("player")) == "HUNTER" and 18 or 16
    local fallback = primary == 18 and 16 or 18
    local bySlot = {}
    for _, slot in ipairs(WEAPON_SLOTS) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
            local id = classID == Enum.ItemClass.Weapon and WEAPON_SKILL[subClassID]
            if id then
                ids[id] = true
                bySlot[slot] = id
            end
        end
    end
    return ids, bySlot[primary] or bySlot[fallback]
end

-- All weapon skills the character has (equipped first)
function ns.WeaponSkills()
    if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines) then return {} end
    local weapon = {}
    for _, id in pairs(WEAPON_SKILL) do weapon[id] = true end
    local equipped, main = EquippedSkillIDs()
    local list = {}
    for i = 1, C_SkillInfo.GetNumSkillLines() do
        local info = C_SkillInfo.GetSkillLineInfo(i)
        if info and not info.isHeader and weapon[info.skillID] and info.maxRank and info.maxRank > 0 then
            list[#list + 1] = { name = info.name, rank = info.rank, maxRank = info.maxRank,
                equipped = equipped[info.skillID] or false, main = info.skillID == main }
        end
    end
    table.sort(list, function(a, b)
        if a.main ~= b.main then return a.main end
        if a.equipped ~= b.equipped then return a.equipped end
        return a.name < b.name
    end)
    return list
end

-- Skill of the primary weapon
function ns.WeaponSkillFocus()
    for _, skill in ipairs(ns.WeaponSkills()) do
        if skill.main then return skill end
    end
end

-- Display ------------------------------------------------------------------------------------

local function Refresh()
    if not bar then return end
    for _, cell in ipairs(cells) do
        if cell:IsShown() then
            cell.text:SetText(cell.field.text())
            if cell.field.specIcon then
                local index = C_SpecializationInfo.GetSpecialization()
                local icon = index and select(4, C_SpecializationInfo.GetSpecializationInfo(index))
                cell.icon:SetTexture(icon)
                cell.icon:SetShown(icon ~= nil)
            end
        end
    end
end

-- Lay out visible fields evenly across the bar
function ns.UpdateInfoBar()
    if not bar then return end
    local mode = ns.VisibilityMode(ns.db.infoBar.mode)
    bar:SetShown(mode ~= "hidden")
    bar.muiMouseover = mode == "mouseover"
    local shown = {}
    for _, cell in ipairs(cells) do
        local on = ns.db.infoBar.fields[cell.field.key] and true or false
        if cell.field.foreverOnly and not ns.IS_FOREVER then on = false end
        cell:SetShown(on)
        if on then shown[#shown + 1] = cell end
    end
    -- Fixed field width: 4 fields = Shift bar width, more fields make the bar wider (centered)
    local width = math.floor(ns.ExtraBarWidth() / 4 / ns.PixelSize()) * ns.PixelSize()
    bar:SetWidth(math.max(#shown, 1) * width)
    for i, cell in ipairs(shown) do
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * width, 0)
        cell:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", (i - 1) * width, 0)
        cell:SetWidth(width)
    end
    Refresh()
end

local function CreateCell(field)
    local cell = CreateFrame("Button", nil, bar)
    cell.field = field
    cell.text = ns.CreateText(cell, 12, "CENTER", "OUTLINE")
    -- Icon left of the value; both centered together in the cell
    if field.icon then
        cell.icon = ns.UI.Icon(cell, field.icon, 12, ClassColor())
    elseif field.specIcon then
        cell.icon = cell:CreateTexture(nil, "OVERLAY")
        cell.icon:SetSize(13, 13)
        cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if cell.icon then
        cell.icon:SetPoint("RIGHT", cell.text, "LEFT", -4, 0)
        cell.text:SetPoint("CENTER", 8, 0)
    else
        cell.text:SetPoint("CENTER")
    end
    cell:SetScript("OnEnter", function(self)
        cell:SetAlpha(0.75) -- subtle hover feedback
        if field.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 4)
            field.tooltip()
            GameTooltip:Show()
        end
    end)
    cell:SetScript("OnLeave", function()
        cell:SetAlpha(1)
        GameTooltip:Hide()
    end)
    if field.click then cell:SetScript("OnClick", function() field.click() end) end
    return cell
end

ns:On("PLAYER_LOGIN", function()
    SaveMoney()
    bar = CreateFrame("Frame", "MeredanUIInfoBar", UIParent)
    bar:SetSize(ns.ExtraBarWidth(), ns.Snap(HEIGHT))
    bar:SetFrameStrata("LOW")
    for _, field in ipairs(FIELDS) do cells[#cells + 1] = CreateCell(field) end

    -- Bottom center, intentionally without the 25 px margin
    ns.OnLayout(function()
        ns.PlaceFromCenter(bar, "BOTTOM", 0, -UIParent:GetHeight() / 2 + 4 * ns.PixelSize())
    end)
    ns.layoutFrames.infobar = bar
    ns.RegisterMouseover(bar)

    ns.UpdateInfoBar()
    C_Timer.NewTicker(1, Refresh) -- FPS and clock
    if IsInGuild() then C_GuildInfo.GuildRoster() end
end)

ns:On("PLAYER_MONEY", function() SaveMoney(); Refresh() end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "UPDATE_INVENTORY_DURABILITY", "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_LOOT_SPEC_UPDATED", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "BN_FRIEND_INFO_CHANGED" }) do
    ns:On(event, Refresh)
end
