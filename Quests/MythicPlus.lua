-- Mythic+ helpers (Settings > Mythic+ Timer):
--   - Auto-insert the keystone when the keystone socket window opens
--   - Auto-gossip: inside an active key, a single gossip option (buff NPCs, doors ...) is picked
--     right away - only options with the chat icon, so never vendors etc.
--   - Group keystones next to the Mythic+ frame: key and rating of each member via LibKeystone
--     (same protocol as BigWigs). Not bundled (no license file); used only if another addon loads it.
--
--   +- Group keystones -------------------+
--   | Koratal     [#] +12 Depths...  2450 |
--   | Talon       [#] +10 Harbor...  2310 |
--   +-------------------------------------+
local _, ns = ...
if ns.IS_FOREVER then return end -- Forever has no Mythic+
local L = ns.L

local function On(key) return ns.db and ns.db[key] ~= false end

-- Keystone insertion -------------------------------------------------------------------------

local function SlotKeystone()
    if not On("mplusAutoKeystone") or CursorHasItem() then return end
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and C_Item.IsItemKeystoneByID(itemID) then
                C_Container.PickupContainerItem(bag, slot)
                if CursorHasItem() then C_ChallengeMode.SlotKeystone() end
                return
            end
        end
    end
end

-- Auto-gossip --------------------------------------------------------------------------------

local GOSSIP_ICONS = { [132053] = true, [1019848] = true } -- chat bubble: not a vendor or repair NPC
local NPC_SKIP = { [107435] = true, [112697] = true, [112699] = true, [101462] = true, [166663] = true }

local function InActiveKey()
    return select(10, C_Scenario.GetInfo()) == LE_SCENARIO_TYPE_CHALLENGE_MODE
        and C_ChallengeMode.GetActiveChallengeMapID() ~= nil
end

local function ShownPopup()
    local shown
    StaticPopup_ForEachShownDialog(function(dialog)
        if not shown and not dialog.hasFixedPosition then shown = dialog end
    end)
    return shown
end

local function OnGossip()
    if not On("mplusAutoGossip") or not InActiveKey() then return end
    local options = C_GossipInfo.GetOptions()
    if #options ~= 1 or not GOSSIP_ICONS[options[1].icon] then return end
    local npcID = UnitCreatureID("npc")
    if ns.Readable(npcID) and NPC_SKIP[npcID] then return end
    local before = ShownPopup()
    C_GossipInfo.SelectOption(options[1].gossipOptionID)
    local after = ShownPopup()
    if after and not before then -- confirm the follow-up popup ("Are you sure?") right away
        local button = after:GetButton1()
        if button then button:Click() end
    end
    C_GossipInfo.CloseGossip()
end

-- Group keystones ----------------------------------------------------------------------------

local LKS = LibStub and LibStub("LibKeystone", true)
local keys = {}  -- name -> { level, mapID, rating }
local panel, rows = nil, {}
local ROW_HEIGHT, WIDTH, PAD = 22, 260, 8

local function GroupNames()
    local names = { [UnitNameUnmodified("player")] = "player" }
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            local name = UnitNameUnmodified(unit)
            if ns.Readable(name) and name then names[name] = unit end
        end
    end
    return names
end

local function GetRow(index)
    local row = rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, panel)
    row:SetSize(WIDTH - 2 * PAD, ROW_HEIGHT)
    row.name = ns.CreateText(row, 12, "LEFT")
    row.name:SetPoint("LEFT")
    row.name:SetWidth(80)
    row.name:SetWordWrap(false)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.key = ns.CreateText(row, 12, "LEFT")
    row.key:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.key:SetPoint("RIGHT", -44, 0)
    row.key:SetWordWrap(false)
    row.rating = ns.CreateText(row, 12, "RIGHT")
    row.rating:SetPoint("RIGHT")
    rows[index] = row
    return row
end

local function UpdatePanel()
    if not panel or not panel:IsShown() then return end
    local names = GroupNames()
    local list = {}
    for name, unit in pairs(names) do list[#list + 1] = { name = name, unit = unit, info = keys[name] } end
    table.sort(list, function(a, b)
        local la, lb = a.info and a.info.level or -1, b.info and b.info.level or -1
        if la ~= lb then return la > lb end
        return a.name < b.name
    end)
    for _, row in ipairs(rows) do row:Hide() end
    for i, entry in ipairs(list) do
        local row = GetRow(i)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(PAD + 20 + (i - 1) * ROW_HEIGHT))
        local _, class = UnitClass(entry.unit)
        local color = class and RAID_CLASS_COLORS[class]
        row.name:SetText(entry.name)
        row.name:SetTextColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
        local info = entry.info
        local mapName, _, _, texture
        if info and info.mapID > 0 then mapName, _, _, texture = C_ChallengeMode.GetMapUIInfo(info.mapID) end
        if mapName and info.level > 0 then
            row.icon:SetTexture(texture)
            row.icon:Show()
            row.key:SetText(("|cff8ecbb4+%d|r %s"):format(info.level, mapName))
        else
            row.icon:Hide()
            row.key:SetText(info and L["No keystone"] or "|cff777777" .. L["unknown (no LibKeystone addon)"] .. "|r")
        end
        local rating = info and info.rating or 0
        if rating > 0 then
            local ratingColor = C_ChallengeMode.GetDungeonScoreRarityColor(rating) or HIGHLIGHT_FONT_COLOR
            row.rating:SetText(ratingColor:WrapTextInColorCode(tostring(rating)))
        else
            row.rating:SetText("")
        end
        row:Show()
    end
    panel:SetHeight(PAD * 2 + 20 + #list * ROW_HEIGHT)
end

local function CreatePanel()
    local parent = PVEFrame or ChallengesFrame
    panel = CreateFrame("Frame", "MeredanUIGroupKeystones", ChallengesFrame)
    panel:SetWidth(WIDTH)
    panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", ns.Snap(8), 0)
    ns.CreateBackground(panel)
    local title = ns.CreateText(panel, 13, "LEFT")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L["Group keystones"])
    title:SetTextColor(unpack(ns.UI.ACCENT))
    panel:SetScript("OnShow", function()
        if LKS then LKS.Request("PARTY") end
        UpdatePanel()
    end)
    panel:SetShown(On("mplusGroupKeys"))
end

function ns.UpdateGroupKeystones()
    if panel then panel:SetShown(On("mplusGroupKeys")) end
end

if LKS then
    LKS.Register(ns, function(level, mapID, rating, name)
        keys[name] = { level = level, mapID = mapID, rating = rating }
        UpdatePanel()
    end)
end

ns:On("GROUP_ROSTER_UPDATE", UpdatePanel)
ns:On("GOSSIP_SHOW", OnGossip)
ns:On("ADDON_LOADED", function(_, name)
    if name ~= "Blizzard_ChallengesUI" then return end
    if ChallengesKeystoneFrame then ChallengesKeystoneFrame:HookScript("OnShow", SlotKeystone) end
    if ChallengesFrame then CreatePanel() end
end)
