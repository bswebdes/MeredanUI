-- Tooltip in MUI style: dark box in a deep shell (no window rim), class colour as an inner line, MUI font. Default bottom right above the
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

local BAR_HEIGHT = 12             -- health bar inside the tooltip (draft)
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
    "QuestieWaypointMinimapTooltip", "QuestieGamepadMapTooltip", -- Questie (created on first use)
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
    -- the deep shell around the box counts too (the health bar sits inside the box)
    local side = Px(PAD) + ns.ShellReach(1)
    local below = side
    tooltip:ClearAllPoints()
    local bags = _G["MeredanUIBags"]
    if not (bags and bags:IsShown()) then bags = ns.BagnonInventory and ns.BagnonInventory() end
    if bags then
        tooltip:SetPoint("BOTTOMRIGHT", bags, "TOPRIGHT", -side + ns.WindowFrameReach(), ns.Snap(GAP) + below + ns.WindowFrameReach())
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
    local bagnon = ns.BagnonInventory and ns.BagnonInventory()
    while frame do
        if frame == bags or (bagnon and frame == bagnon) then return true end
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

-- Unit tooltip divider: a spacer line in its own font with a texture across it (lines are
-- reused by Blizzard, so the font is reset when the tooltip is refilled).
-- Reset all lines from 2 on to the normal font (line objects are reused; Blizzard doesn't
-- reset their font when refilling)
local dividerFont -- a spacer line tall enough for the divider (unit tooltip)

local function NormalizeFonts(tooltip)
    local name = tooltip:GetName()
    local i = 2
    while _G[name .. "TextLeft" .. i] do
        local line = _G[name .. "TextLeft" .. i]
        local font = line:GetFontObject()
        local fontName = font and font.GetName and font:GetName()
        -- our divider / bar spacer fonts back to normal (line objects are reused)
        if fontName and fontName:find("^MeredanUITooltip") then line:SetFontObject(GameTooltipText) end
        i = i + 1
    end
    if tooltip.muiDivider then tooltip.muiDivider:Hide() end
end

-- Divider line (unit tooltip): a thin line in the frame material across the box, centred on a
-- dedicated spacer line
local function PlaceDivider(tooltip, line)
    if not dividerFont then
        dividerFont = CreateFont("MeredanUITooltipDivider")
        dividerFont:SetFont(ns.STYLE.font, 14, "")
    end
    line:SetText(" ")
    line:SetFontObject(dividerFont)
    -- B14: material line fading out to both ends, a small gem in the middle
    local d = tooltip.muiDivider
    if not d then
        d = {}
        local m = ns.Material()
        for i = 1, 2 do
            local t = tooltip:CreateTexture(nil, "ARTWORK")
            t:SetTexture("Interface\\Buttons\\WHITE8X8")
            t:SetHeight(ns.PixelSize())
            local faded, full = CreateColor(m.item[1], m.item[2], m.item[3], 0), CreateColor(m.lit[1], m.lit[2], m.lit[3], 1)
            if i == 1 then t:SetGradient("HORIZONTAL", faded, full) else t:SetGradient("HORIZONTAL", full, faded) end
            d[i] = t
        end
        d.gem = ns.UI.Diamond(tooltip, 5)
        function d.Hide() d[1]:Hide() d[2]:Hide() d.gem:Hide() end
        tooltip.muiDivider = d
    end
    d[1]:ClearAllPoints()
    d[1]:SetPoint("LEFT", tooltip, "LEFT", ns.Snap(12), 0)
    d[1]:SetPoint("RIGHT", tooltip, "CENTER", -ns.Snap(9), 0)
    d[1]:SetPoint("TOP", line, "CENTER", 0, 0)
    d[2]:ClearAllPoints()
    d[2]:SetPoint("LEFT", tooltip, "CENTER", ns.Snap(9), 0)
    d[2]:SetPoint("RIGHT", tooltip, "RIGHT", -ns.Snap(12), 0)
    d[2]:SetPoint("TOP", line, "CENTER", 0, 0)
    d.gem:ClearAllPoints()
    d.gem:SetPoint("CENTER", d[1], "RIGHT", ns.Snap(9), 0)
    d[1]:Show() d[2]:Show() d.gem:Show()
end

-- New content: spacer lines back to normal font
local function ResetGroups(tooltip)
    if tooltip:GetName() then NormalizeFonts(tooltip) end
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
    -- deep shell around the box (no translucent rim: only windows get that); the class/reaction
    -- colour shows as a thin line just inside it
    ns.AddDeepShell(holder, ns.Snap(1), { shadow = 10 })
    tooltip.muiBorder = ns.AddBorder(holder, true)
    tooltip.muiHolder = holder
end

-- Border in class or reaction color, otherwise black
local function SetBorderColor(tooltip, color)
    if not tooltip.muiBorder then return end
    local r, g, b = unpack(color or BORDER_DEFAULT)
    for _, edge in ipairs(tooltip.muiBorder) do edge:SetVertexColor(r, g, b, 1) end
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

-- Health bar: shaded, in a groove inside the tooltip at the bottom (placed per unit, see
-- PlaceHealthBar), the health percent inside it
local function StyleHealthBar()
    local bar = HealthBar()
    if not bar then return end
    bar:SetStatusBarTexture(ns.MEDIA .. "BarShade")
    ns.UI.Groove(bar)
    bar.muiText = ns.CreateText(bar, 11, "RIGHT", "OUTLINE")
    bar.muiText:SetPoint("RIGHT", -ns.Snap(5), 0)
    -- Blizzard colors green->red by health percent; reapply our color and the percent
    bar:HookScript("OnValueChanged", function(self)
        if self.muiColor then self:SetStatusBarColor(unpack(self.muiColor)) end
        local _, unit = GameTooltip:GetUnit()
        if Readable(unit) and unit and UnitHealthPercent and CurveConstants then
            self.muiText:SetFormattedText("%d %%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
        end
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
local inspectCount = 0
local pendingGUID

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

-- NPCs: "Rare" / "Elite" / "Rare Elite" / "Boss" right of the name (draft: same line, own colour)
local CLASSIFICATION = {
    rare = { "Rare", "ffc0c4cc" },
    rareelite = { "Rare Elite", "ffc0c4cc" },
    elite = { "Elite", "ffd9b56b" },
    worldboss = { "Boss", "ffe0604a" },
}

-- Line helpers ------------------------------------------------------------------------------
-- The layout works on Blizzard's own lines: lines that are taken out (class, faction) move the
-- rest up and leave free lines at the end, which the rows below reuse before new lines are added.

local function Left(tooltip, i) return _G[tooltip:GetName() .. "TextLeft" .. i] end
local function Right(tooltip, i) return _G[tooltip:GetName() .. "TextRight" .. i] end

local function CopyLine(tooltip, from, to)
    local fl, fr, tl, tr = Left(tooltip, from), Right(tooltip, from), Left(tooltip, to), Right(tooltip, to)
    tl:SetText(fl:GetText())
    tl:SetTextColor(fl:GetTextColor())
    if fr and tr then
        local text = fr:IsShown() and fr:GetText() or nil
        tr:SetText(text)
        tr:SetTextColor(fr:GetTextColor())
        tr:SetShown(text ~= nil and text ~= "")
    end
end

-- Takes line index out: the lines below move up one, the last line becomes free
local function RemoveLine(tooltip, layout, index)
    local last = tooltip:NumLines() - layout.free
    for i = index, last - 1 do CopyLine(tooltip, i + 1, i) end
    Left(tooltip, last):SetText("")
    local r = Right(tooltip, last)
    if r then r:SetText(nil) r:Hide() end
    layout.free = layout.free + 1
end

-- Next line for a row: a free one if there is one, else a new one
local function NextLine(tooltip, layout)
    if layout.free > 0 then
        local index = tooltip:NumLines() - layout.free + 1
        layout.free = layout.free - 1
        return index
    end
    tooltip:AddLine(" ")
    return tooltip:NumLines()
end

local function AddRow(tooltip, layout, label, value)
    local i = NextLine(tooltip, layout)
    local l, r = Left(tooltip, i), Right(tooltip, i)
    l:SetText(label)
    l:SetTextColor(unpack(MUTED))
    r:SetText(value)
    r:SetTextColor(1, 1, 1)
    r:Show()
end

-- Name in Cinzel (B6) for units; restored on clear
local nameFont
local function SetNameFont(tooltip)
    if not nameFont then
        nameFont = CreateFont("MeredanUITooltipName")
        nameFont:SetFont(ns.DISPLAY_FONT, ns.FontPx(15), "")
        nameFont:SetShadowOffset(1, -1)
        nameFont:SetShadowColor(0, 0, 0, 1)
    end
    local line = Left(tooltip, 1)
    if line then line:SetFontObject(nameFont) tooltip.muiNameFont = true end
end

-- Icon in an item frame left of the first two lines (player: class, item: the item). The game lays
-- out the tooltip lines itself (moving them does not stick), so lines 1 and 2 start with a
-- transparent inline spacer and the icon frame hangs from line 1.
local ICON = 32
local INDENT = ICON + 10
local SPACER = ("|T1319037:1:%d|t"):format(INDENT) -- interface\common\spacer, transparent
local function ShowIcon(tooltip, texture, atlas, edge)
    local l1, l2 = Left(tooltip, 1), Left(tooltip, 2)
    if not (l1 and l2) then return end
    if not tooltip.muiIcon then
        local f = CreateFrame("Frame", nil, tooltip)
        f:SetSize(ICON, ICON)
        ns.AddSlotBackground(f)
        f.edges = ns.AddItemFrame(f, nil, 2)
        f.tex = f:CreateTexture(nil, "ARTWORK")
        ns.InsetItemIcon(f, f.tex, nil, 2)
        tooltip.muiIcon = f
    end
    for _, line in ipairs({ l1, l2 }) do
        local text = line:GetText()
        if Readable(text) and text and not text:find(SPACER, 1, true) then line:SetText(SPACER .. text) end
    end
    local f = tooltip.muiIcon
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", l1, "TOPLEFT", 0, 1)
    if atlas then
        f.tex:SetAtlas(atlas)
        f.tex:SetTexCoord(0, 1, 0, 1)
    else
        f.tex:SetTexture(texture)
        f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local c = edge or ns.Material().item
    for _, e in ipairs(f.edges) do e:SetVertexColor(c[1], c[2], c[3], 1) end
    f:Show()
end

local function ClearIcon(tooltip)
    if not tooltip:GetName() then return end
    if tooltip.muiNameFont then
        Left(tooltip, 1):SetFontObject(GameTooltipHeaderText)
        tooltip.muiNameFont = nil
    end
    if tooltip.muiIcon then tooltip.muiIcon:Hide() end
end
ns.ClearTooltipIcon = ClearIcon

-- Class icon (Forever's round group finder set)
local function ClassAtlas(unit)
    local _, class = UnitClass(unit)
    if not Readable(class) or not class then return end
    local atlas = "groupfinder-icon-class-" .. class:lower() .. "-c60-2x"
    if not (C_Texture.GetAtlasInfo(atlas)) then atlas = "groupfinder-icon-class-" .. class:lower() end
    if C_Texture.GetAtlasInfo(atlas) then return atlas end
end

-- Health bar inside the tooltip (draft): a spacer line at the very end carries it
local spacerFont
local function PlaceHealthBar(tooltip, layout, unit)
    local bar = tooltip == GameTooltip and HealthBar()
    if not bar then return end -- Blizzard shows it for every unit; always reserve its line
    if not spacerFont then
        spacerFont = CreateFont("MeredanUITooltipBarSpacer")
        spacerFont:SetFont(ns.STYLE.font, 16, "")
    end
    local i = NextLine(tooltip, layout)
    local line, right = Left(tooltip, i), Right(tooltip, i)
    line:SetText(" ")
    line:SetFontObject(spacerFont)
    right:SetText(" ")
    right:Show()
    -- left text starts at the left padding, the right text ends at the right padding
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", line, "TOPLEFT", 0, -3)
    bar:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    bar:SetHeight(ns.Snap(BAR_HEIGHT))
    -- percent inside the bar (secret-safe: formatted by the game, never compared)
    if UnitHealthPercent and CurveConstants then
        bar.muiText:SetFormattedText("%d %%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
    else
        bar.muiText:SetText("")
    end
end

-- Players and NPCs alike: divider with a gem, the unit's target as a label/value row, then the
-- health bar inside the box
local function FinishUnitLines(tooltip, unit, layout)
    local target = unit .. "target"
    if Enabled("tooltipTarget") and ns.Plain(UnitExists(target)) then
        local name = ns.Plain(UnitIsUnit(target, "player")) and ("|cffff4040" .. L["You"] .. "|r") or ColoredName(target)
        if name then layout.rows[#layout.rows + 1] = { L["Target"], name } end
    end
    NormalizeFonts(tooltip)
    if #layout.rows > 0 then
        PlaceDivider(tooltip, Left(tooltip, NextLine(tooltip, layout)))
        for _, row in ipairs(layout.rows) do AddRow(tooltip, layout, row[1], row[2]) end
    end
    PlaceHealthBar(tooltip, layout, unit)
    -- lines left over at the end stay empty (no gap)
    for _ = 1, layout.free do
        local i = NextLine(tooltip, layout)
        Left(tooltip, i):SetText("")
    end
end

local function AddUnitLines(tooltip, unit)
    local isPlayer = ns.Plain(UnitIsPlayer(unit))
    local color = UnitColor(unit)
    local bar = HealthBar()
    if bar then
        bar.muiColor = color
        if color then bar:SetStatusBarColor(unpack(color)) end
    end
    SetBorderColor(tooltip, nil) -- no class/reaction coloured frame (Benny)
    local layout = { free = 0, rows = {} }
    SetNameFont(tooltip)
    local levelTag = type(LEVEL) == "string" and ("^" .. LEVEL:gsub("%p", "%%%0"))

    if not isPlayer then
        -- classification right of the name
        local tag = Enabled("tooltipClassification") and CLASSIFICATION[ns.Plain(UnitClassification(unit)) or ""]
        if tag then
            local r = Right(tooltip, 1)
            r:SetText("|c" .. tag[2] .. L[tag[1]] .. "|r")
            r:Show()
        end
        -- level number in the difficulty colour, the rest of the level line unchanged
        local level = UnitLevel(unit)
        if Readable(level) and level and level > 0 and GetCreatureDifficultyColor then
            local c = GetCreatureDifficultyColor(level)
            for i = 2, tooltip:NumLines() do
                local line = Left(tooltip, i)
                local text = line and line:GetText()
                if Readable(text) and levelTag and text:find(levelTag) and c then
                    local num = tostring(level)
                    local from, to = text:find(num, 1, true)
                    if from then
                        line:SetText(("%s|cff%02x%02x%02x%s|r%s"):format(text:sub(1, from - 1), c.r * 255, c.g * 255,
                            c.b * 255, num, text:sub(to + 1)))
                    end
                    break
                end
            end
        end
        FinishUnitLines(tooltip, unit, layout)
        tooltip:Show()
        return
    end

    -- Name in class color
    local class = ClassColor(unit)
    if class then Left(tooltip, 1):SetTextColor(class.r, class.g, class.b) end

    -- Guild + rank in the accent colour: Blizzard shows only the guild name (line 2)
    local guild, rank = GetGuildInfo(unit)
    if Readable(guild) and Readable(rank) and guild then
        local line = Left(tooltip, 2)
        local text = line and line:GetText()
        if Readable(text) and text and text:find(guild, 1, true) then
            line:SetText(("<%s> %s"):format(guild, rank))
            line:SetTextColor(unpack(ns.UI.ACCENT))
        end
    end

    -- Level line: "(Player)" out, class (Forever: own line) appended in its colour, faction on the
    -- right of the same line
    local faction, factionName = UnitFactionGroup(unit)
    local factionColor = Readable(faction) and FACTION_COLORS[faction]
    local playerTag = type(PLAYER) == "string" and ("%s*%(" .. PLAYER:gsub("%p", "%%%0") .. "%)")
    local className = UnitClass(unit)
    local levelIndex, classIndex, factionIndex
    for i = 2, tooltip:NumLines() do
        local text = Left(tooltip, i):GetText()
        if Readable(text) and text then
            if not levelIndex and levelTag and text:find(levelTag) then levelIndex = i end
            if Readable(className) and text == className then classIndex = i end
            if Readable(factionName) and factionName and text == factionName then factionIndex = i end
        end
    end
    if levelIndex then
        local line = Left(tooltip, levelIndex)
        local text = line:GetText()
        if playerTag then text = text:gsub(playerTag, "") end
        -- Skyborne: long faction-specific race names - show a short one
        local race, raceFile = UnitRace(unit)
        if Readable(race) and race and raceFile == "Skyborne" then
            local short = L["Skyborne"]
            for word in race:gmatch("%S+") do
                local lower = word:lower()
                if lower:find("skyborn") or lower:find("himmel") then short = word end
            end
            local from, to = text:find(race, 1, true)
            if from and short ~= race then text = text:sub(1, from - 1) .. short .. text:sub(to + 1) end
        end
        if classIndex and class and Readable(className) then
            text = ("%s |cff%02x%02x%02x%s|r"):format(text, class.r * 255, class.g * 255, class.b * 255, className)
        end
        line:SetText(text)
        if factionIndex and factionColor then
            local r = Right(tooltip, levelIndex)
            r:SetText(factionName)
            r:SetTextColor(unpack(factionColor))
            r:Show()
        end
        -- take the class and faction lines out (higher index first, so the other stays valid)
        local out = {}
        if classIndex then out[#out + 1] = classIndex end
        if factionIndex and factionColor then out[#out + 1] = factionIndex end
        table.sort(out, function(a, b) return a > b end)
        for _, index in ipairs(out) do RemoveLine(tooltip, layout, index) end
    end

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
        if info and info.ilvl then layout.rows[#layout.rows + 1] = { L["iLvl"], tostring(info.ilvl) } end
    end

    -- Mythic+ score (Retail)
    if not ns.IS_FOREVER and Enabled("tooltipMythic") and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        local score = summary and summary.currentSeasonScore
        if Readable(score) and score > 0 then
            local scoreColor = C_ChallengeMode.GetDungeonScoreRarityColor(score) or HIGHLIGHT_FONT_COLOR
            layout.rows[#layout.rows + 1] = { L["M+"], scoreColor:WrapTextInColorCode(tostring(score)) }
        end
    end

    -- class icon left of name and guild (after the lines above are final)
    if Enabled("tooltipClassIcon") then
        local atlas = ClassAtlas(unit)
        if atlas then ShowIcon(tooltip, nil, atlas) end
    end
    FinishUnitLines(tooltip, unit, layout)
    tooltip:Show() -- relayout: widths changed
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

-- Items (draft): icon in an item frame with the quality colour on its edge left of the name, the
-- item level right under the name; mUI's own lines go below a divider (ns.TooltipSection)
local itemLevelPattern = type(ITEM_LEVEL) == "string" and ("^" .. ITEM_LEVEL:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%%%d", "%%d+"))
local function OnItemTooltip(tooltip, data)
    if not data or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then return end
    local item = Readable(data.hyperlink) and data.hyperlink or (Readable(data.id) and data.id)
    if not item then return end
    local icon = C_Item.GetItemIconByID(item)
    if not icon or tooltip:NumLines() < 3 then return end
    -- item level line up to line 2 (muted)
    if itemLevelPattern then
        for k = 2, math.min(tooltip:NumLines(), 8) do
            local line = Left(tooltip, k)
            local text = line and line:GetText()
            if Readable(text) and text and text:find(itemLevelPattern) then
                if k > 2 then
                    for i = k, 3, -1 do CopyLine(tooltip, i - 1, i) end
                    Left(tooltip, 2):SetText(text)
                    local r = Right(tooltip, 2)
                    if r then r:SetText(nil) r:Hide() end
                end
                Left(tooltip, 2):SetTextColor(unpack(MUTED))
                break
            end
        end
    end
    local quality = C_Item.GetItemQualityByID(item)
    local edge
    if not ns.issecretvalue(quality) and quality and quality >= Enum.ItemQuality.Uncommon then
        local r, g, b = C_Item.GetItemQualityColor(quality)
        if r then edge = { r, g, b } end
    end
    ShowIcon(tooltip, icon, nil, edge)
    tooltip:Show() -- relayout with the minimum width
end

-- mUI's own lines on item tooltips (upgrade, auction house, characters, wishlist): the first block
-- starts with the gem divider, the rest follow right below it
function ns.TooltipSection(tooltip)
    if tooltip.muiSection then return end
    tooltip.muiSection = true
    tooltip:AddLine(" ")
    PlaceDivider(tooltip, Left(tooltip, tooltip:NumLines()))
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
    -- drop expired entries now and then (the cache was never cleaned)
    inspectCount = (inspectCount or 0) + 1
    if inspectCount >= 50 then
        inspectCount = 0
        local now = GetTime()
        for key, entry in pairs(inspectCache) do
            if now - entry.time >= INSPECT_CACHE_SECONDS then inspectCache[key] = nil end
        end
    end
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
    ClearIcon(self)
    self.muiSection = nil
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
    -- SetText without a color = Blizzard's yellow default (calendar hints, many UI buttons): our text
    -- color instead. Explicit colors (item quality, titles) stay untouched.
    hooksecurefunc(GameTooltip, "SetText", function(self, _, r)
        if issecretvalue and issecretvalue(r) then return end -- check first: even r == nil errors on a secret
        if r ~= nil then return end
        local line = _G[self:GetName() .. "TextLeft1"]
        if line then line:SetTextColor(unpack(ns.UI.TEXT)) end
    end)
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
