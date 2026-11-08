-- Tooltip in MUI style: flat, dark, 1px border, MUI font. Default bottom right above the
-- micro menu and bag bar; above the bag window when open (like ElvUI). Optionally at the
-- cursor, hideable in combat (Shift still shows it) - Settings > Tooltip.
--
--   +---------------------------+
--   | Koratal                   |  <- name in class color
--   | <Heavy Metal Bar> Officer |  <- guild + rank
--   | Level 80 Blood Elf Rogue  |
--   | Assassination Rogue       |  <- spec, shown by Blizzard
--   | iLvl 268                  |  <- loaded via inspect
--   | M+ 2450                   |  <- score in Blizzard's rarity color
--   | Target: Talon             |
--   +---------------------------+
--   =============================  <- thin health bar (class/reaction color)
--
-- Secret values (Midnight, instances) are never read or compared - the line is just omitted.
local _, ns = ...
local L = ns.L

local BAR_HEIGHT = 4
local BAR_GAP = 4                 -- gap between tooltip border and health bar
-- Background and border 4px INSIDE the tooltip edge (negative = inset): Blizzard places the
-- comparison tooltips roughly edge to edge, sometimes overlapping a few pixels - this keeps
-- a gap between the boxes. Never move the comparison tooltips themselves: Blizzard calls
-- them in a secure context in Midnight (secrets).
local PAD = -4
-- Inner padding: Blizzard's text sits 10px from the tooltip edge and PAD eats 4 of it,
-- so INNER is added on all sides
local INNER = 6
local BORDER_DEFAULT = { 0, 0, 0, 1 }
local MUTED = { 0.6, 0.59, 0.56 }
local FACTION_COLORS = {
    Horde = { 0.9, 0.18, 0.18 },
    Alliance = { 0.25, 0.55, 1 },
}
local GAP = 8                     -- gap to the bag bar / bag window
local MICRO_STACK = 28 + 8 + 28   -- micro menu + bag bar bottom right (see MicroMenu.lua)
local INSPECT_CACHE_SECONDS = 300

-- Additional tooltips (path in _G, also in load-on-demand Blizzard addons)
local EXTRA_TOOLTIPS = {
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "FriendsTooltip", "QuestScrollFrame.StoryTooltip",
    "QuestScrollFrame.CampaignTooltip", "WarCampaignTooltip", "ReputationParagonTooltip", "BattlePetTooltip",
    "FloatingBattlePetTooltip", "FloatingPetBattleAbilityTooltip", "PetBattlePrimaryUnitTooltip",
    "PetBattlePrimaryAbilityTooltip", "SettingsTooltip", "LibDBIconTooltip", "QueueStatusFrame",
    "GameSmallHeaderTooltip", "NamePlateTooltip", "GarrisonFollowerTooltip", "GarrisonFollowerAbilityTooltip",
    "GarrisonMissionMechanicTooltip", "GarrisonMissionMechanicFollowerCounterTooltip", "PerksProgramTooltip",
}

local Readable = ns.Readable
local function Enabled(key) return ns.db[key] ~= false end -- toggle that defaults to on

-- Round to real pixels - including 0 and negatives (ns.Snap always returns at least 1px)
local function Px(value)
    local px = ns.PixelSize()
    return math.floor(value / px + 0.5) * px
end
local function HealthBar() return _G["GameTooltipStatusBar"] end

-- Position -------------------------------------------------------------------------------

-- Bottom right above micro menu/bag bar, or above the open bag window
local function PlaceCorner(tooltip)
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    -- Leave room for the border around the tooltip plus the health bar below
    local below = Px(PAD + BAR_GAP + BAR_HEIGHT)
    local side = Px(PAD)
    tooltip:ClearAllPoints()
    local bags = _G["MeredanUIBags"]
    if bags and bags:IsShown() then
        tooltip:SetPoint("BOTTOMRIGHT", bags, "TOPRIGHT", -side, ns.Snap(GAP) + below)
    else
        tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -margin - side, margin + ns.Snap(MICRO_STACK + GAP) + below)
    end
end

-- Default anchor (world, unit frames, buttons without own position) - like ElvUI: hide in
-- combat (unless Shift), otherwise at the cursor or bottom right
local function PlaceDefault(tooltip, parent)
    if ns.db.tooltipHideInCombat and InCombatLockdown() and not IsShiftKeyDown() then
        tooltip:Hide()
        return
    end
    if ns.db.tooltipAnchor == "cursor" and parent then
        tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        return
    end
    PlaceCorner(tooltip)
end

-- Items in the MUI bags: Blizzard places the tooltip next to the item (inside the bag
-- window) - put it above the bags instead
local function InMUIBags(frame)
    local bags = _G["MeredanUIBags"]
    while frame do
        if frame == bags then return true end
        frame = frame:GetParent()
    end
end

local function PlaceItemTooltip(button, tooltip)
    -- Cursor mode: Blizzard's position next to the item is near the cursor anyway
    if ns.db.tooltipAnchor == "cursor" or not InMUIBags(button) then return end
    -- Blizzard also sets an anchor type (left/right of item) that the game reapplies on show -
    -- clearing it leaves only our points
    tooltip:SetAnchorType("ANCHOR_NONE")
    PlaceCorner(tooltip)
end

-- "Equipped" header above the comparison tooltip: flat instead of Blizzard's art, above our border
local function SkinCompareHeader(tooltip)
    local header = tooltip.CompareHeader
    if not header or header.muiSkinned then return end
    header.muiSkinned = true
    for _, region in ipairs({ header:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    local pad = Px(PAD)
    header:ClearAllPoints()
    header:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", -pad, pad + ns.Snap(2))
    local bg = header:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddBorder(header)
end

-- Look -----------------------------------------------------------------------------------

-- More room around the text: Blizzard's own padding (for embedded item tooltips) is kept
-- and INNER added on top. Blizzard resets it on every show (GameTooltip_CalculatePadding),
-- so we reapply; if it already matches what we last set, do nothing.
local function ApplyPadding(tooltip)
    if not (tooltip.SetPadding and tooltip.GetPadding) or tooltip:IsForbidden() then return end
    local w, h = tooltip:GetPadding()
    local last = tooltip.muiPadding
    if last and math.abs(w - last[1]) < 0.5 and math.abs(h - last[2]) < 0.5 then return end
    tooltip.muiPadding = { w + INNER, h + INNER }
    tooltip:SetPadding(w + INNER, h + INNER, INNER, INNER)
end

-- Line groups with spacing (player tooltip: name+guild | level, class, faction | iLvl, M+ |
-- target). Blizzard has no per-line spacing and re-anchors lines on show, so we insert real
-- spacer lines in a tiny font: append a line, shift texts from the group line down by one,
-- and the freed line becomes the gap. Blizzard computes the height itself. The spacer font
-- is reset on clear (line objects are reused and would keep the tiny font).
local GROUP_GAP = 5
local spacerFont

local function InsertSpacer(tooltip, index)
    local name = tooltip:GetName()
    tooltip:AddLine(" ")
    for i = tooltip:NumLines(), index + 1, -1 do
        local from, to = _G[name .. "TextLeft" .. (i - 1)], _G[name .. "TextLeft" .. i]
        to:SetText(from:GetText())
        to:SetTextColor(from:GetTextColor())
        -- carry the font: spacer lines tiny, everything else normal
        to:SetFontObject(from:GetFontObject() == spacerFont and spacerFont or GameTooltipText)
    end
    local spacer = _G[name .. "TextLeft" .. index]
    spacer:SetText(" ")
    spacer:SetFontObject(spacerFont)
end

-- Reset all lines from 2 on to the normal font (line objects are reused; Blizzard doesn't
-- reset their font when refilling)
local function NormalizeFonts(tooltip)
    local name = tooltip:GetName()
    local i = 2
    while _G[name .. "TextLeft" .. i] do
        local line = _G[name .. "TextLeft" .. i]
        if line:GetFontObject() == spacerFont then line:SetFontObject(GameTooltipText) end
        i = i + 1
    end
end

-- starts: line numbers that get a gap before them - insert bottom-up so indices stay valid
local function GroupLines(tooltip, starts)
    if not spacerFont then
        spacerFont = CreateFont("MeredanUITooltipSpacer")
        spacerFont:SetFont(ns.STYLE.font, GROUP_GAP, "")
    end
    NormalizeFonts(tooltip)
    local list = {}
    for index in pairs(starts) do list[#list + 1] = index end
    table.sort(list, function(a, b) return a > b end)
    for _, index in ipairs(list) do
        if index > 1 and index <= tooltip:NumLines() then InsertSpacer(tooltip, index) end
    end
end

-- New content: spacer lines back to normal font
local function ResetGroups(tooltip)
    if spacerFont and tooltip:GetName() then NormalizeFonts(tooltip) end
end

local function Skin(tooltip)
    if not tooltip or tooltip.IsEmbedded then return end
    if tooltip.NineSlice then tooltip.NineSlice:SetAlpha(0) end
    if tooltip.muiSkinned then return end
    tooltip.muiSkinned = true
    if tooltip:GetObjectType() == "GameTooltip" then
        tooltip:HookScript("OnShow", ApplyPadding)
        ApplyPadding(tooltip)
    end
    -- Own border holder offset by PAD from the tooltip edge (negative = inset)
    local holder = CreateFrame("Frame", nil, tooltip)
    holder:SetFrameLevel(math.max(tooltip:GetFrameLevel() - 1, 0))
    local pad = Px(PAD)
    holder:SetPoint("TOPLEFT", tooltip, "TOPLEFT", -pad, pad)
    holder:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", pad, -pad)
    local bg = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    tooltip.muiBorder = ns.AddBorder(holder)
    tooltip.muiHolder = holder
end

-- Border in class or reaction color, otherwise black
local function SetBorderColor(tooltip, color)
    if not tooltip.muiBorder then return end
    local r, g, b = unpack(color or BORDER_DEFAULT)
    for _, edge in ipairs(tooltip.muiBorder) do edge:SetVertexColor(r, g, b, 1) end
    -- GameTooltip's health bar shares the border color
    local bar = tooltip == GameTooltip and _G["GameTooltipStatusBar"]
    if bar and bar.muiBorder then
        for _, edge in ipairs(bar.muiBorder) do edge:SetVertexColor(r, g, b, 1) end
    end
end

-- Buff tooltips of our aura frame are shown by Blizzard's secure aura system with its own
-- tooltip - only reachable through this official API (like ElvUI).
local function StyleAuraTooltip()
    local inbound = _G["AuraContainerInbound"]
    if not (inbound and inbound.SetTooltipBackdrop) then return end
    local WHITE = "Interface\\Buttons\\WHITE8X8"
    local r, g, b, a = unpack(ns.STYLE.panelColor)
    inbound.SetTooltipBackdrop({
        backdropInfo = { bgFile = WHITE, edgeFile = WHITE, edgeSize = ns.PixelSize() },
        borderColor = { r = 0, g = 0, b = 0, a = 1 },
        centerColor = { r = r, g = g, b = b, a = a },
    })
end

local function StyleFonts()
    -- Clear hierarchy: name slightly larger and bold, body text (mUI text) one step smaller
    GameTooltipHeaderText:SetFont(ns.FontFor("bold"), ns.FontPx(14), "")
    GameTooltipText:SetFont(ns.FontFor("text"), ns.FontPx(12), "")
    GameTooltipTextSmall:SetFont(ns.FontFor("text"), ns.FontPx(11), "")
end

-- Health bar: flat, thin, directly below the tooltip
local function StyleHealthBar()
    local bar = HealthBar()
    if not bar then return end
    bar:SetStatusBarTexture(ns.STYLE.barTexture)
    bar:ClearAllPoints()
    local pad = Px(PAD)
    -- Same width as the tooltip box, with a gap above
    bar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", -pad, -pad - ns.Snap(BAR_GAP))
    bar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", pad, -pad - ns.Snap(BAR_GAP))
    bar:SetHeight(ns.Snap(BAR_HEIGHT))
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.emptyColor or { 0.1, 0.1, 0.1 }))
    bar.muiBorder = ns.AddBorder(bar)
    -- Blizzard colors green->red by health percent; reapply our color
    bar:HookScript("OnValueChanged", function(self)
        if self.muiColor then self:SetStatusBarColor(unpack(self.muiColor)) end
    end)
end

-- Content --------------------------------------------------------------------------------

local function ClassColor(unit)
    local _, class = UnitClass(unit)
    if not Readable(class) then return end
    return C_ClassColor.GetClassColor(class)
end

local function UnitColor(unit)
    if ns.Plain(UnitIsPlayer(unit)) then
        local color = ClassColor(unit)
        if color then return { color.r, color.g, color.b } end
    end
    local reaction = UnitReaction(unit, "player")
    if Readable(reaction) then
        if ns.REP_COLORS[reaction] then return { ns.RepColor(reaction) } end
    end
end

-- Name in class color (players) or reaction color (NPCs)
local function ColoredName(unit)
    local name = UnitName(unit)
    if not Readable(name) then return end
    local color = UnitColor(unit)
    if not color then return name end
    return ("|cff%02x%02x%02x%s|r"):format(color[1] * 255, color[2] * 255, color[3] * 255, name)
end

-- Item level via inspect, cached per GUID for a while
local inspectCache = {}
local pendingGUID

-- Blizzard already shows the spec ("Assassination Rogue") - only add the item level
local function InspectLine(info)
    if info.ilvl then return ("%s %d"):format(L["iLvl"], info.ilvl) end
end

local function OwnInspectInfo()
    local info = {}
    local _, equipped = GetAverageItemLevel()
    if equipped and equipped > 0 then info.ilvl = math.floor(equipped) end
    return info
end

local function RequestInspect(unit, guid)
    if pendingGUID or not CanInspect(unit) then return end
    if InspectFrame and InspectFrame:IsShown() then return end -- don't interfere with Blizzard's inspect frame
    if ns.InspectBusy and ns.InspectBusy() then return end -- nor with ours
    pendingGUID = guid
    NotifyInspect(unit)
end

local function AddUnitLines(tooltip, unit)
    local isPlayer = ns.Plain(UnitIsPlayer(unit))
    local color = UnitColor(unit)
    local bar = HealthBar()
    if bar then
        bar.muiColor = color
        if color then bar:SetStatusBarColor(unpack(color)) end
    end
    SetBorderColor(tooltip, color)
    if not isPlayer then return end

    -- Name in class color
    local class = ClassColor(unit)
    if class then GameTooltipTextLeft1:SetTextColor(class.r, class.g, class.b) end

    -- Guild + rank: Blizzard shows only the guild name (line 2) - append the rank
    local guild, rank = GetGuildInfo(unit)
    if Readable(guild) and Readable(rank) then
        local line = GameTooltipTextLeft2
        local text = line and line:GetText()
        if Readable(text) and text:find(guild, 1, true) then
            line:SetText(("<%s> %s"):format(guild, rank))
        end
    end

    -- Faction line: Horde red, Alliance blue. Strip "(Player)" from the level line - the class says it.
    local starts = {} -- first line of each group (GroupLines)
    local faction, factionName = UnitFactionGroup(unit)
    local factionColor = Readable(faction) and FACTION_COLORS[faction]
    local playerTag = type(PLAYER) == "string" and ("%s*%(" .. PLAYER:gsub("%p", "%%%0") .. "%)")
    local levelTag = type(LEVEL) == "string" and ("^" .. LEVEL:gsub("%p", "%%%0"))
    for i = 2, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if Readable(text) then
            if levelTag and text:find(levelTag) then starts[i] = true end
            if factionColor and Readable(factionName) and text == factionName then
                line:SetTextColor(unpack(factionColor))
            elseif playerTag and text:find(playerTag) then
                line:SetText((text:gsub(playerTag, "")))
            end
        end
    end
    local statsStart

    -- Item level
    local guid = UnitGUID(unit)
    if Enabled("tooltipItemLevel") and Readable(guid) then
        local info
        if ns.Plain(UnitIsUnit(unit, "player")) then
            info = OwnInspectInfo()
        else
            local cached = inspectCache[guid]
            if cached and GetTime() - cached.time < INSPECT_CACHE_SECONDS then
                info = cached
            else
                RequestInspect(unit, guid)
            end
        end
        local text = info and InspectLine(info)
        if text then
            tooltip:AddLine(text, 1, 1, 1)
            statsStart = statsStart or tooltip:NumLines()
        end
    end

    -- Mythic+ score
    if not ns.IS_FOREVER and Enabled("tooltipMythic") and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        local score = summary and summary.currentSeasonScore
        if Readable(score) and score > 0 then
            local scoreColor = C_ChallengeMode.GetDungeonScoreRarityColor(score) or HIGHLIGHT_FONT_COLOR
            tooltip:AddLine(("%s %s"):format(L["M+"], scoreColor:WrapTextInColorCode(tostring(score))), 1, 1, 1)
            statsStart = statsStart or tooltip:NumLines()
        end
    end
    if statsStart then starts[statsStart] = true end

    -- Unit's target
    local target = unit .. "target"
    -- In instances both answers may be secret -> no line then.
    -- "Target" muted, the name in its color.
    if Enabled("tooltipTarget") and ns.Plain(UnitExists(target)) then
        local name = ns.Plain(UnitIsUnit(target, "player")) and ("|cffff4040" .. L["You"] .. "|r") or ColoredName(target)
        if name then
            local r, g, b = unpack(MUTED)
            tooltip:AddLine(("%s  %s"):format(L["Target"], name), r, g, b)
            starts[tooltip:NumLines()] = true
        end
    end
    GroupLines(tooltip, starts)
end

-- Mythic+: enemy forces the mob is worth (Blizzard provides the value per unit)
local function AddForcesLine(tooltip, unit)
    if ns.db.mplusMobTooltip == false or ns.Plain(UnitIsPlayer(unit)) ~= false
        or select(10, C_Scenario.GetInfo()) ~= LE_SCENARIO_TYPE_CHALLENGE_MODE then return end
    local _, _, percentString = C_ScenarioInfo.GetUnitCriteriaProgressValues(unit)
    if not (Readable(percentString) and percentString and percentString ~= "") then return end
    ns.AddForcesTooltipLine(tooltip, percentString)
end

-- also used by the Mythic+ demo
function ns.AddForcesTooltipLine(tooltip, percentString)
    local r, g, b = unpack(ns.UI.ACCENT)
    tooltip:AddDoubleLine(L["Enemy forces"], "+" .. percentString .. "%", 0.8, 0.8, 0.8, r, g, b)
end

local function OnUnitTooltip(tooltip)
    if tooltip ~= GameTooltip then return end
    local _, unit = tooltip:GetUnit()
    if not Readable(unit) then return end
    AddUnitLines(tooltip, unit)
    AddForcesLine(tooltip, unit)
end

-- Items: border in quality color (Uncommon and up; grey/white stay black)
local function OnItemTooltip(tooltip, data)
    if not tooltip.muiBorder or not data then return end
    local item = Readable(data.hyperlink) and data.hyperlink or (Readable(data.id) and data.id)
    if not item then return end
    local quality = C_Item.GetItemQualityByID(item)
    if ns.issecretvalue(quality) or not quality or quality < Enum.ItemQuality.Uncommon then return end
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if r then SetBorderColor(tooltip, { r, g, b }) end
end

-- IDs: grey "Spell ID   12345" line at the bottom (number in Surf Green). Not on comparison
-- tooltips (Blizzard builds them in a secure context). Secret IDs are just omitted.
local ID_LABELS = {
    [Enum.TooltipDataType.Item] = "Item ID",
    [Enum.TooltipDataType.Toy] = "Item ID",
    [Enum.TooltipDataType.Spell] = "Spell ID",
    [Enum.TooltipDataType.UnitAura] = "Spell ID",
    [Enum.TooltipDataType.Mount] = "Spell ID",
    [Enum.TooltipDataType.Currency] = "Currency ID",
    [Enum.TooltipDataType.Achievement] = "Achievement ID",
    [Enum.TooltipDataType.Quest] = "Quest ID",
}
local NPC_GUIDS = { Creature = true, Vehicle = true }
local ID_TEXTS = { [L["NPC ID"]] = true, [L["Mount ID"]] = true }
for _, label in pairs(ID_LABELS) do ID_TEXTS[L[label]] = true end

local function AddID(tooltip, label, id)
    if not Readable(id) or type(id) ~= "number" or id <= 0 then return end
    label = L[label]
    local name = tooltip:GetName()
    local hasIDs = false
    for i = 1, tooltip:NumLines() do -- already there (tooltip refilled without clearing)?
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line:GetText()
        if Readable(text) then
            if text == label then return end
            if ID_TEXTS[text] then hasIDs = true end
        end
    end
    if not hasIDs then tooltip:AddLine(" ") end -- blank line before the first ID
    local r, g, b = unpack(ns.UI.ACCENT)
    tooltip:AddDoubleLine(label, tostring(id), 0.6, 0.6, 0.6, r, g, b)
end

-- Buffs/debuffs: "From: Name" (class color) - who applied the aura, also solo. Works for auras
-- on unit frames, nameplates etc. (GameTooltip); Blizzard's secure buff frame has its own
-- tooltip that addons may not extend. Secret values (Retail instances) -> nothing.
local AURA_GETTERS = {
    GetUnitAura = function(unit, index, filter) return C_UnitAuras.GetAuraDataByIndex(unit, index, filter) end,
    GetUnitBuff = function(unit, index, filter) return C_UnitAuras.GetAuraDataByIndex(unit, index, filter or "HELPFUL") end,
    GetUnitDebuff = function(unit, index, filter) return C_UnitAuras.GetAuraDataByIndex(unit, index, filter or "HARMFUL") end,
    GetUnitAuraByAuraInstanceID = function(unit, id) return C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id) end,
    GetUnitBuffByAuraInstanceID = function(unit, id) return C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id) end,
    GetUnitDebuffByAuraInstanceID = function(unit, id) return C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id) end,
}

local function OnAuraTooltip(tooltip)
    if not Enabled("tooltipAuraSource") or tooltip:IsForbidden() or not tooltip.GetPrimaryTooltipInfo then return end
    local info = tooltip:GetPrimaryTooltipInfo()
    local getter = info and AURA_GETTERS[info.getterName]
    local args = info and info.getterArgs
    if not (getter and args) then return end
    local ok, aura = pcall(getter, args[1], args[2], args[3])
    if not ok or not aura then return end
    local source = aura.sourceUnit
    if not Readable(source) or not source or not UnitExists(source) then return end
    local name = UnitName(source)
    if not Readable(name) or not name then return end
    local r, g, b = 1, 1, 1
    local _, class = UnitClass(source)
    local color = UnitIsPlayer(source) and class and RAID_CLASS_COLORS[class]
    if color then r, g, b = color.r, color.g, color.b end
    -- Pets: "Wolf (Koratal)"
    if UnitIsUnit(source, "pet") or source:find("pet") then
        local owner = source == "pet" and "player" or source:gsub("pet", "")
        local ownerName = UnitExists(owner) and UnitName(owner)
        if Readable(ownerName) and ownerName then name = ("%s (%s)"):format(name, ownerName) end
    end
    tooltip:AddLine(L["From: %s"]:format(name), r, g, b)
    tooltip:Show()
end

local function OnAnyTooltip(tooltip, data)
    if not data or tooltip:IsForbidden() or not tooltip:GetName()
        or tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2 then return end
    ns.AddUpgradeLine(tooltip, data) -- "+2.4 %" (Upgrades.lua), before the IDs
    if not Enabled("tooltipIDs") then return end
    local kind = data.type
    if not Readable(kind) then return end
    if kind == Enum.TooltipDataType.Unit then
        local guid = data.guid
        if not Readable(guid) then return end
        local guidType, _, _, _, _, npcID = strsplit("-", guid)
        if NPC_GUIDS[guidType] then AddID(tooltip, "NPC ID", tonumber(npcID)) end
        return
    end
    local label = ID_LABELS[kind]
    if not label then return end
    AddID(tooltip, label, data.id)
    if kind == Enum.TooltipDataType.Mount and Readable(data.id) then
        AddID(tooltip, "Mount ID", C_MountJournal.GetMountFromSpell(data.id))
    end
end

-- Inspect done: cache it and rebuild the tooltip if the same unit is still under the mouse
ns:On("INSPECT_READY", function(_, guid)
    if not Readable(guid) or guid ~= pendingGUID then return end
    pendingGUID = nil
    local mouseGUID = ns.Plain(UnitExists("mouseover")) and ns.Plain(UnitGUID("mouseover"))
    local unit = mouseGUID and mouseGUID == guid and "mouseover"
    if not unit then return end
    local info = { time = GetTime() }
    local ilvl = C_PaperDollInfo.GetInspectItemLevel(unit)
    if Readable(ilvl) and ilvl > 0 then info.ilvl = math.floor(ilvl) end
    inspectCache[guid] = info
    local _, shownUnit = GameTooltip:GetUnit()
    if GameTooltip:IsShown() and Readable(shownUnit) then
        GameTooltip:SetUnit(unit) -- rebuild, now with the cached line
    end
end)

-- Drop the pending request if no answer comes (otherwise inspecting waits forever)
GameTooltip:HookScript("OnHide", function() pendingGUID = nil end)
-- New content: border back to black, forget grouping
local function ResetBorder(self)
    SetBorderColor(self)
    ResetGroups(self)
end

-- Demo (Settings > Tooltip): your own tooltip at the configured position
local demoActive = false
ns.TooltipDemo = {
    Start = function()
        demoActive = true
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetUnit("player")
    end,
    Stop = function()
        demoActive = false
        GameTooltip:Hide()
    end,
    IsActive = function() return demoActive and GameTooltip:IsShown() end,
}

-- Setting changed: re-show the running demo
function ns.RefreshTooltipDemo()
    if demoActive then ns.TooltipDemo.Start() end
end

-- Link tooltip (click on a chat link): stays at Blizzard's position bottom center (not moved
-- to the corner), only a flat close button instead of Blizzard's red X.
local function StyleItemRef()
    local tooltip = ItemRefTooltip
    local close = tooltip and tooltip.CloseButton
    if not close then return end
    local UI = ns.UI
    for _, region in ipairs({ close:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetTexture(nil) end
    end
    close:SetSize(18, 18)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", -Px(6), -Px(6))
    local bg = UI.Box(close)
    local icon = UI.Icon(close, "Close", 10)
    icon:SetPoint("CENTER")
    close:HookScript("OnEnter", function()
        bg:SetColorTexture(unpack(UI.HOVER))
        icon:SetVertexColor(unpack(UI.ACCENT))
    end)
    close:HookScript("OnLeave", function()
        bg:SetColorTexture(unpack(UI.FIELD))
        icon:SetVertexColor(unpack(UI.TEXT))
    end)
end

ns:On("PLAYER_LOGIN", function()
    StyleItemRef()
    -- Compare with equipped gear only with Shift (Blizzard default)
    C_CVar.SetCVar("alwaysCompareItems", "0")
    StyleFonts()
    StyleHealthBar()
    StyleAuraTooltip()
    hooksecurefunc("SharedTooltip_SetBackdropStyle", Skin)
    -- More Blizzard tooltips in MUI style (most already go through SharedTooltip_SetBackdropStyle)
    ns.SkinExtraTooltips = function()
        for _, path in ipairs(EXTRA_TOOLTIPS) do
            local object = _G
            for key in path:gmatch("[^%.]+") do object = object and object[key] end
            if type(object) == "table" and object.GetObjectType then Skin(object) end
        end
    end
    ns.SkinExtraTooltips()
    for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        Skin(tooltip)
        tooltip:HookScript("OnTooltipCleared", ResetBorder)
    end
    hooksecurefunc("GameTooltip_SetDefaultAnchor", PlaceDefault)
    hooksecurefunc("ContainerFrameItemButton_CalculateItemTooltipAnchors", PlaceItemTooltip)
    -- Blizzard recalculates its padding on show and for embedded item tooltips
    hooksecurefunc("GameTooltip_CalculatePadding", ApplyPadding)
    if ItemRefTooltip.ItemRefSetHyperlink then hooksecurefunc(ItemRefTooltip, "ItemRefSetHyperlink", ApplyPadding) end
    SkinCompareHeader(ShoppingTooltip1)
    SkinCompareHeader(ShoppingTooltip2)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, OnAuraTooltip)
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, OnAnyTooltip)
end)

-- Also catch tooltips from load-on-demand Blizzard addons (collections, garrison ...)
ns:On("ADDON_LOADED", function(_, name)
    if ns.SkinExtraTooltips and name:find("^Blizzard_") then ns.SkinExtraTooltips() end
end)
