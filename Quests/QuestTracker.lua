-- Retail only (Forever has its own tracker: Quests/Tracker.lua).
-- Blizzard's objective tracker in mUI style, right of the inner action bar below buffs/debuffs.
--
--   ALL OBJECTIVES             -   <- header without gold art, flat - (collapsed: +)
--   -----------------------------   <- thin Surf Green line
--   CAMPAIGN                   v
--  |? Quest name                    <- left stripe = quest type (campaign gold, important purple,
--  |  - 0/1 objective                  legendary orange, daily blue); glyph gray, tracked Surf Green
--     - 0/1 objective       [Item]  <- quest item flat with border; objective nubs/checks flat
--     [######----- 60 %]            <- flat progress bar, mUI texture
--
-- Hidden during boss fights and in arenas (not in Mythic+).
-- Visuals and position only, never Blizzard's data or flow: the quest item button calls a protected
-- function. If mUI made the tracker rebuild itself (or changed Blizzard's color tables), the button
-- would be tainted and quest items would stop working. So: only hooksecurefunc after Blizzard's own
-- calls, change textures/fonts on widgets, position via SetPointBase (no Edit Mode side effects).
-- Modeled after ElvUI.
local _, ns = ...
local L = ns.L

local GAP = 10        -- gap to the buffs
local SIDE_GAP = 60   -- gap to the right action bar (Blizzard's tracker has almost no right margin)
local ICON_SIZE = 14  -- + / - expand/collapse
local MODULES = {
    "ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
    "QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
    "MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
    "BonusObjectiveTracker", "WorldQuestObjectiveTracker",
}

-- Font: Blizzard resets the font objects on every text size change (Edit Mode); afterwards swap only
-- the font face, the size stays Blizzard's.
local function KeepFont(fontObject, color)
    if not fontObject then return end
    local function Apply()
        local _, size = fontObject:GetFont()
        fontObject:SetFont(ns.STYLE.font, size or 12, "")
        fontObject:SetShadowOffset(1, -1)
        if color then fontObject:SetTextColor(unpack(color)) end
    end
    hooksecurefunc(fontObject, "SetFontObject", Apply)
    Apply()
end

-- Collapse button: hide Blizzard's art, own flat - / +.
-- Blizzard keeps resetting the art's alpha to full, so hide it via vertex color alpha 0 instead,
-- which Blizzard leaves alone.
local function HideButtonArt(button)
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
        if texture then texture:SetVertexColor(1, 1, 1, 0) end
    end
end

local function SkinMinimizeButton(button)
    if not button or button.muiIcon then return end
    HideButtonArt(button)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(ns.MEDIA .. "Icons\\Minus")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER")
    icon:SetVertexColor(unpack(ns.UI.ACCENT))
    button.muiIcon = icon
    button:HookScript("OnEnter", function() icon:SetVertexColor(1, 1, 1) end)
    button:HookScript("OnLeave", function() icon:SetVertexColor(unpack(ns.UI.ACCENT)) end)
end

-- - = expanded, + = collapsed (after Blizzard's SetCollapsed)
local function UpdateCollapsedIcon(header, collapsed)
    local button = header.MinimizeButton
    local icon = button and button.muiIcon
    if icon then icon:SetTexture(ns.MEDIA .. "Icons\\" .. (collapsed and "Plus" or "Minus")) end
    if button then HideButtonArt(button) end -- Blizzard swaps the textures on toggle
end

-- Header: remove gold art, shine and glow (clear textures - Blizzard's fade-in animation only sets
-- alpha), thin line below, flat arrow
local function SkinHeader(header, textColor)
    if not header or header.muiSkinned then return end
    header.muiSkinned = true
    for _, key in ipairs({ "Background", "Shine", "Glow" }) do
        if header[key] then header[key]:SetTexture(nil) end
    end
    if header.Text and textColor then header.Text:SetTextColor(unpack(textColor)) end
    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetHeight(ns.PixelSize())
    line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, ns.Snap(2))
    line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, ns.Snap(2))
    local r, g, b = unpack(ns.UI.ACCENT)
    line:SetColorTexture(r, g, b, 0.5)
    SkinMinimizeButton(header.MinimizeButton)
    UpdateCollapsedIcon(header, header.isCollapsed)
    hooksecurefunc(header, "SetCollapsed", UpdateCollapsedIcon)
end

-- Quest item button, visuals only: slightly larger, cropped edge, 1 px border, flat cooldown (dark
-- swipe, mUI font), count and range dot in mUI font. Click, fields and attributes stay Blizzard's
-- (protected function, see above). mUI sets the size once on creation; Blizzard re-measures on rebuild.
local ITEM_SIZE = 32

local function SkinItemButton(button)
    if not button or button.muiSkinned then return end
    button.muiSkinned = true
    button:SetSize(ns.Snap(ITEM_SIZE), ns.Snap(ITEM_SIZE))
    for _, texture in ipairs({ button:GetNormalTexture(), button:GetPushedTexture() }) do
        if texture then texture:SetAlpha(0) end
    end
    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetColorTexture(1, 1, 1, 0.2) end
    if button.icon then
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon:ClearAllPoints()
        button.icon:SetAllPoints()
    end
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddBorder(button, true)
    local cooldown = button.Cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(button.icon or button)
        cooldown:SetDrawEdge(false)
        cooldown:SetSwipeColor(0, 0, 0, 0.7)
        local text = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
        if text then text:SetFont(ns.STYLE.font, ns.FontPx(14), "OUTLINE") end
    end
    if button.Count then
        button.Count:SetFont(ns.STYLE.font, ns.FontPx(12), "OUTLINE")
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", -ns.Snap(2), ns.Snap(2))
    end
    if button.HotKey then
        button.HotKey:SetFont(ns.STYLE.font, ns.FontPx(10), "OUTLINE")
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", -ns.Snap(2), -ns.Snap(2))
        button.HotKey:SetJustifyH("RIGHT")
    end
end

-- Does the color match a Blizzard color from OBJECTIVE_TRACKER_COLOR? (read only)
local function Same(r, g, b, color)
    return color and math.abs(r - color.r) + math.abs(g - color.g) + math.abs(b - color.b) < 0.01
end

-- Objective icons: gold nub -> small square, check -> mUI check in Surf Green, fail -> red cross.
-- Blizzard sets the art via SetAtlas; we swap it afterwards.
local OBJECTIVE_ICONS = {
    ["ui-questtracker-objective-nub"] = { "Square", "MUTED" },
    ["ui-questtracker-tracker-check"] = { "Check", "ACCENT" },
    ["ui-questtracker-objective-fail"] = { "Close", { 0.9, 0.25, 0.25 } },
}

local function FlatObjectiveIcon(icon, atlas)
    local flat = OBJECTIVE_ICONS[atlas and atlas:lower() or ""]
    if not flat then return icon:SetVertexColor(1, 1, 1) end
    icon:SetTexture(ns.MEDIA .. "Icons\\" .. flat[1])
    local color = type(flat[2]) == "table" and flat[2] or ns.UI[flat[2]]
    icon:SetVertexColor(unpack(color))
end

local function RecolorObjective(text, r, g, b)
    if text.muiRecoloring then return end
    local color
    if Same(r, g, b, OBJECTIVE_TRACKER_COLOR["Normal"]) then
        color = ns.UI.MUTED
    elseif Same(r, g, b, OBJECTIVE_TRACKER_COLOR["NormalHighlight"]) then
        color = ns.UI.TEXT
    end
    if not color then return end
    text.muiRecoloring = true
    text:SetTextColor(unpack(color))
    text.muiRecoloring = false
end

local function SkinLine(line)
    if not line or line.muiSkinned then return end
    line.muiSkinned = true
    for _, text in ipairs({ line.Text, line.Dash }) do
        if text then
            hooksecurefunc(text, "SetTextColor", RecolorObjective)
            RecolorObjective(text, text:GetTextColor())
        end
    end
    if line.Icon then
        hooksecurefunc(line.Icon, "SetAtlas", FlatObjectiveIcon)
        FlatObjectiveIcon(line.Icon, line.Icon:GetAtlas())
    end
    if line.CheckGlow then line.CheckGlow:SetTexture(nil) end -- glow on completion
end

-- Quest POI button before the title: glyph only (..., ?, !), slightly larger, desaturated gray; the
-- tracked quest in Surf Green. World quest icons stay colored. Shield/circle/glow removed.
local POI_SCALE = 1.3
local STRIPE_WIDTH = 2
local QUEST_TYPE_COLORS = { -- left stripe per quest type; none for normal and world quests
    [Enum.QuestClassification.Campaign] = { 1, 0.78, 0.2 },
    [Enum.QuestClassification.Important] = { 0.7, 0.4, 1 },
    [Enum.QuestClassification.Legendary] = { 1, 0.5, 0.1 },
    [Enum.QuestClassification.Recurring] = { 0.3, 0.6, 1 },
    [Enum.QuestClassification.Calling] = { 0.3, 0.6, 1 },
    [Enum.QuestClassification.Meta] = { 0.4, 0.85, 0.85 },
}

-- stripe spans the whole quest (title + objectives), left of the glyph
local function UpdateStripe(button)
    local stripe = button.muiStripe
    if not stripe then
        stripe = button:CreateTexture(nil, "BACKGROUND")
        stripe:SetWidth(ns.Snap(STRIPE_WIDTH))
        stripe:SetPoint("TOPRIGHT", button, "TOPLEFT", -ns.Snap(3), -5) -- top edge = title (button sits 5 px higher)
        button.muiStripe = stripe
    end
    local color = QUEST_TYPE_COLORS[button.GetQuestClassification and button:GetQuestClassification() or -1]
    local block = button:GetParent()
    local height = block and tonumber(block.height)
    if not color or not height or height <= 0 then return stripe:Hide() end
    stripe:SetHeight(height)
    stripe:SetColorTexture(color[1], color[2], color[3], 1)
    stripe:Show()
end
local function FlattenPOI(button)
    for _, key in ipairs({ "NormalTexture", "PushedTexture", "HighlightTexture", "Glow" }) do
        if button[key] then button[key]:SetAlpha(0) end
    end
    UpdateStripe(button)
    local icon = button.Display and button.Display.Icon
    if not icon then return end
    button.Display:SetScale(POI_SCALE)
    -- tracked quest: Blizzard uses smaller brown dots - always use the normal ones
    if icon:GetAtlas() == "Quest-In-Progress-Icon-Brown" then icon:SetAtlas("Quest-In-Progress-Icon-yellow", true) end
    local style = button.GetStyle and button:GetStyle()
    if style == POIButtonUtil.Style.WorldQuest then
        icon:SetDesaturated(false)
        icon:SetVertexColor(1, 1, 1)
    else
        icon:SetDesaturated(true)
        icon:SetVertexColor(unpack(button:IsSelected() and ns.UI.ACCENT or ns.UI.MUTED))
    end
end

local function SkinPOIButton(button)
    if not button then return end
    if not button.muiHooked then
        button.muiHooked = true
        hooksecurefunc(button, "UpdateButtonStyle", FlattenPOI)
    end
    FlattenPOI(button)
end

-- Texts: Blizzard colors -> mUI. Title light (tracked quest Surf Green), on hover Surf Green or white;
-- objectives gray, light on hover. Other colors (complete, failed) stay. Blizzard recolors on every
-- rebuild and hover, so recolor afterwards.
local function RecolorTitle(text, r, g, b)
    if text.muiRecoloring then return end
    local tracked = text:GetParent() and text:GetParent().poiIsSuperTracked
    local color
    if Same(r, g, b, OBJECTIVE_TRACKER_COLOR["Header"]) then
        color = tracked and ns.UI.ACCENT or ns.UI.TEXT
    elseif Same(r, g, b, OBJECTIVE_TRACKER_COLOR["HeaderHighlight"]) then
        color = tracked and { 1, 1, 1 } or ns.UI.ACCENT
    end
    if not color then return end
    text.muiRecoloring = true
    text:SetTextColor(unpack(color))
    text.muiRecoloring = false
end

-- Quest title 2 pt larger than the lines (follows Blizzard's Edit Mode text size). Set before the next
-- rebuild - Blizzard measures the height when the text is set.
local TITLE_EXTRA = 2
local titleTexts = setmetatable({}, { __mode = "k" })

local function ApplyTitleFont(text)
    local _, size = ObjectiveTrackerLineFont:GetFont()
    text:SetFont(ns.STYLE.font, (size or 12) + TITLE_EXTRA, "")
    text:SetShadowOffset(1, -1)
end

local function OnAddObjective(block, objectiveKey)
    SkinLine(block.usedLines and block.usedLines[objectiveKey])
end

-- hover: highlight the whole block (glyph, title, objectives)
local function AddBlockHover(block)
    if not (block.OnHeaderEnter and block.OnHeaderLeave) then return end
    local hover = block:CreateTexture(nil, "BACKGROUND")
    hover:SetPoint("TOPLEFT", block, "TOPLEFT", -ns.Snap(30), ns.Snap(3))
    hover:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", 0, -ns.Snap(3))
    hover:SetColorTexture(1, 1, 1, 0.06)
    hover:Hide()
    hooksecurefunc(block, "OnHeaderEnter", function() hover:Show() end)
    hooksecurefunc(block, "OnHeaderLeave", function() hover:Hide() end)
end

local function OnAddBlock(_, block)
    if not block then return end
    SkinItemButton(block.ItemButton)
    if block.muiHooked then return end
    block.muiHooked = true
    AddBlockHover(block)
    if block.HeaderText then
        titleTexts[block.HeaderText] = true
        ApplyTitleFont(block.HeaderText)
        hooksecurefunc(block.HeaderText, "SetTextColor", RecolorTitle)
        RecolorTitle(block.HeaderText, block.HeaderText:GetTextColor())
    end
    if block.AddObjective then hooksecurefunc(block, "AddObjective", OnAddObjective) end
    for _, line in pairs(block.usedLines or {}) do SkinLine(line) end
    if block.AddPOIButton then
        hooksecurefunc(block, "AddPOIButton", function(self) SkinPOIButton(self.poiButton) end)
        SkinPOIButton(block.poiButton)
    end
end

-- Flat progress/timer bars: remove border, rings, shine and flashes; mUI texture and border
local function FlattenBar(bar)
    if not bar or bar.muiSkinned then return end
    bar.muiSkinned = true
    local fill = bar:GetStatusBarTexture()
    for _, region in ipairs({ bar:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= fill and region ~= bar.Icon then
            region:SetTexture(nil)
        end
    end
    -- flash/shine animations live on child frames
    for _, child in ipairs({ bar:GetChildren() }) do child:SetAlpha(0) end
    bar:SetStatusBarTexture(ns.STYLE.barTexture)
    bar:SetStatusBarColor(unpack(ns.UI.ACCENT))
    ns.CreateBackground(bar)
    if bar.Icon then
        -- bonus objectives/world quests: icon right of the bar, square with 1 px border instead of a ring
        local icon = bar.Icon
        -- scenario bars: icon uses Blizzard's round mask, cropping fails there (then keep it round; an error
        -- must not abort the tracker build)
        pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
        icon:SetSize(bar:GetHeight() + ns.Snap(6), bar:GetHeight() + ns.Snap(6))
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", bar, "RIGHT", ns.Snap(6), 0)
        local frame = CreateFrame("Frame", nil, bar)
        frame:SetAllPoints(icon)
        ns.AddBorder(frame, true)
        frame:SetShown(icon:IsShown())
        hooksecurefunc(icon, "Show", function() frame:Show() end)
        hooksecurefunc(icon, "Hide", function() frame:Hide() end)
    end
    if bar.Label then
        ns.SetFont(bar.Label, 11, "OUTLINE")
        bar.Label:ClearAllPoints()
        bar.Label:SetPoint("CENTER", bar, "CENTER")
    end
end

local function InChallengeMode()
    return select(10, C_Scenario.GetInfo()) == LE_SCENARIO_TYPE_CHALLENGE_MODE
end

-- Enemy forces in Mythic+ more precise: "62.47% - 287/460" instead of Blizzard's integer.
-- The absolute count is only in the text (quantityString); quantity is already the percentage.
local function ForcesText()
    local numCriteria = select(3, C_Scenario.GetStepInfo()) or 0
    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and info.isWeightedProgress and ns.Readable(info.quantityString) and info.quantityString then
            local current = tonumber(info.quantityString:match("%d+"))
            local total = info.totalQuantity
            if current and ns.Readable(total) and total and total > 0 then
                return ("%.2f%% · %d/%d"):format(current / total * 100, current, total)
            end
        end
    end
end

local function OnForcesValue(progress)
    if not InChallengeMode() or ns.db.mplusForces == "percent" then return end
    local text = ForcesText()
    if text then progress.Bar.Label:SetText(text) end
end

local function OnProgressBar(module, key)
    local progress = module.usedProgressBars and module.usedProgressBars[key]
    if not progress then return end
    FlattenBar(progress.Bar)
    if module == ScenarioObjectiveTracker and not progress.muiForces and progress.SetValue then
        progress.muiForces = true
        hooksecurefunc(progress, "SetValue", OnForcesValue)
    end
end

local function OnTimerBar(module, key)
    local timer = module.usedTimerBars and module.usedTimerBars[key]
    if timer then FlattenBar(timer.Bar) end
end

-- Mythic+ block -------------------------------------------------------------------------------
--
--   +-----------------------------+
--   | +12            [#][#][#]    |  <- level (Surf Green), flat affixes with border
--   | 24:37                 X 3   |  <- time left (large), deaths
--   | [#############-|----|----]  |  <- timer: marks at +3 (40 % left) and +2 (20 % left),
--   +-----------------------------+     color shows the best chest still reachable
--
-- Blizzard only sets texts, values and affix positions (anew for every key); mUI re-anchors
-- everything else once. Also used by the demo (same parts, same function).
local MPLUS_TIERS = { -- share of time left -> color
    { 0.4, { 0.557, 0.796, 0.706 } }, -- +3: Surf Green
    { 0.2, { 0.95, 0.8, 0.3 } },      -- +2
    { 0.001, { 1, 0.55, 0.2 } },      -- +1
    { 0, { 0.9, 0.25, 0.25 } },       -- out of time
}
local AFFIX_SIZE = 20

local function Hex(color) return ("|cff%02x%02x%02x"):format(color[1] * 255, color[2] * 255, color[3] * 255) end

-- after every Blizzard update: bar color, time left for +3/+2, overtime
local function UpdateTimer(block, elapsed, timeLimit)
    if not (ns.Readable(elapsed) and ns.Readable(timeLimit) and elapsed and timeLimit and timeLimit > 0) then return end
    local timeLeft = math.max(0, timeLimit - elapsed)
    local share = timeLeft / timeLimit
    for _, tier in ipairs(MPLUS_TIERS) do
        if share >= tier[1] then
            block.StatusBar:SetStatusBarColor(unpack(tier[2]))
            break
        end
    end
    local parts = {}
    for i, chest in ipairs({ { 3, 0.4 }, { 2, 0.2 } }) do
        local left = timeLeft - chest[2] * timeLimit
        if left > 0 then
            parts[#parts + 1] = ("%s+%d %s|r"):format(Hex(MPLUS_TIERS[i][2]), chest[1], SecondsToClock(left))
        end
    end
    block.muiChests:SetText(ns.db.mplusChests ~= false and table.concat(parts, "  ") or "")
    if timeLeft == 0 then -- out of time: show overtime instead of 0:00
        block.TimeLeft:SetText("+" .. SecondsToClock(elapsed - timeLimit))
    end
end

-- affixes top right in key order
local function LayoutAffixes(block, frames)
    local previous
    for i = #frames, 1, -1 do
        local affix = frames[i]
        if not affix.muiSkinned then
            affix.muiSkinned = true
            if affix.Border then affix.Border:SetAlpha(0) end
            affix.Portrait:ClearAllPoints()
            affix.Portrait:SetAllPoints()
            affix.Portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            ns.AddBorder(affix, true)
            -- tooltip at the cursor (Blizzard anchors it to the right)
            affix:HookScript("OnEnter", function()
                if GameTooltip:IsOwned(affix) then GameTooltip:SetAnchorType("ANCHOR_CURSOR") end
            end)
        end
        affix:SetSize(AFFIX_SIZE, AFFIX_SIZE)
        affix:ClearAllPoints()
        if previous then
            affix:SetPoint("RIGHT", previous, "LEFT", -ns.Snap(4), 0)
        else
            affix:SetPoint("TOPRIGHT", block.muiPanel, "TOPRIGHT", -ns.Snap(8), -ns.Snap(8))
        end
        previous = affix
    end
end

-- header: the scenario module header - the panel is as wide as it (flush with the rest of the
-- tracker instead of Blizzard's narrower block)
local function SkinChallengeBlock(block, header)
    if not block or block.muiSkinned then return end
    block.muiSkinned = true
    -- hide Blizzard's art (background, border); fonts stay
    for _, region in ipairs({ block:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    local panel = CreateFrame("Frame", nil, block)
    -- height stays Blizzard's block (the tracker layout reads it), width matches the header
    panel:SetPoint("TOP", block, "TOP", 0, -ns.Snap(2))
    panel:SetPoint("BOTTOM", block, "BOTTOM", 0, ns.Snap(2))
    panel:SetPoint("LEFT", header or block, "LEFT")
    panel:SetPoint("RIGHT", header or block, "RIGHT")
    panel:SetFrameLevel(math.max(block:GetFrameLevel() - 1, 0))
    ns.CreateBackground(panel)
    block.muiPanel = panel

    ns.SetFont(block.Level, 14, "OUTLINE")
    block.Level:SetTextColor(unpack(ns.UI.ACCENT))
    block.Level:ClearAllPoints()
    block.Level:SetPoint("TOPLEFT", panel, "TOPLEFT", ns.Snap(8), -ns.Snap(9))
    ns.SetFont(block.TimeLeft, 22, "OUTLINE")
    block.TimeLeft:ClearAllPoints()
    block.TimeLeft:SetPoint("TOPLEFT", block.Level, "BOTTOMLEFT", 0, -ns.Snap(4))

    local death = block.DeathCount
    death:ClearAllPoints()
    death:SetPoint("RIGHT", panel, "RIGHT", -ns.Snap(8), 0)
    death:SetPoint("BOTTOM", block.TimeLeft, "BOTTOM", 0, 0)
    if death.Count then ns.SetFont(death.Count, 12, "OUTLINE") end

    -- time left for +3/+2 right of the timer
    block.muiChests = ns.CreateText(panel, 12, "LEFT", "OUTLINE")
    block.muiChests:SetPoint("BOTTOMLEFT", block.TimeLeft, "BOTTOMRIGHT", ns.Snap(10), ns.Snap(2))

    local bar = block.StatusBar
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", ns.Snap(8), ns.Snap(8))
    bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -ns.Snap(8), ns.Snap(8))
    bar:SetHeight(ns.Snap(10))
    bar:SetStatusBarTexture(ns.STYLE.barTexture)
    bar:SetStatusBarColor(unpack(ns.UI.ACCENT))
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.5)
    ns.AddBorder(bar)
    -- marks: left of them the time for +3 / +2 is no longer enough
    for _, share in ipairs({ 0.4, 0.2 }) do
        local mark = bar:CreateTexture(nil, "OVERLAY")
        mark:SetColorTexture(1, 1, 1, 0.7)
        mark:SetWidth(ns.PixelSize())
        mark:SetPoint("TOP")
        mark:SetPoint("BOTTOM")
        mark:SetPoint("LEFT", bar, "LEFT", bar:GetWidth() * share, 0)
        bar:HookScript("OnSizeChanged", function(self) mark:SetPoint("LEFT", self, "LEFT", self:GetWidth() * share, 0) end)
    end
end

-- Boss splits: when each objective (boss) was completed, right in its line. The lines are Blizzard's
-- (shared pool) - mUI only adds its own font string and hides it when the line returns to the pool,
-- so it doesn't show up in quest lines.
local splits = {} -- objective index -> seconds since start (true = completed before load)

local function ChallengeElapsed()
    for i = 1, select("#", GetWorldElapsedTimers()) do
        local timerID = select(i, GetWorldElapsedTimers())
        local _, elapsed, kind = GetWorldElapsedTime(timerID)
        if kind == Enum.WorldElapsedTimerTypes.ChallengeMode and ns.Readable(elapsed) then return elapsed end
    end
end

local function SplitText(line)
    if not line.muiSplit then
        line.muiSplit = ns.CreateText(line, 11, "RIGHT", "OUTLINE")
        line.muiSplit:SetPoint("RIGHT", line, "RIGHT", 0, 0)
        line.muiSplit:SetTextColor(unpack(ns.UI.ACCENT))
    end
    return line.muiSplit
end

local function UpdateSplits(module, numCriteria)
    if not InChallengeMode() or not numCriteria then return end
    local show = ns.db.mplusSplits ~= false
    local elapsed = ChallengeElapsed()
    for i = 1, numCriteria do
        local info = C_ScenarioInfo.GetCriteriaInfo(i)
        if info and not info.isWeightedProgress then
            if info.completed and splits[i] == nil then splits[i] = elapsed or true end
            local line = module.ObjectivesBlock:GetExistingLine(i)
            if line then
                local time = splits[i]
                local text = SplitText(line)
                text:SetText(type(time) == "number" and SecondsToClock(time) or "")
                text:SetShown(show)
            end
        end
    end
end

-- Scenario and delve header ------------------------------------------------------------------
--
-- Normal scenarios: Blizzard's StageBlock ("Stage 2/3" + name) - gold art removed, mUI panel as wide
-- as the header. Delves etc.: own header widgets (tier, affixes, reward), all of which go through
-- UIWidgetBaseScenarioHeaderTemplateMixin.Setup - same treatment after it.
-- Visuals only: hide textures, font/color, own background behind.
local function AddPanel(frame, header)
    if frame.muiPanel then return frame.muiPanel end
    local panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOP", frame, "TOP", 0, -ns.Snap(2))
    panel:SetPoint("BOTTOM", frame, "BOTTOM", 0, ns.Snap(2))
    panel:SetPoint("LEFT", header or frame, "LEFT")
    panel:SetPoint("RIGHT", header or frame, "RIGHT")
    panel:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
    ns.CreateBackground(panel)
    frame.muiPanel = panel
    return panel
end

local function KeepFace(text, color)
    if not text then return end
    local _, size = text:GetFont()
    text:SetFont(ns.STYLE.font, size or 14, "")
    text:SetShadowOffset(1, -1)
    if color then text:SetTextColor(unpack(color)) end
end

local function SkinStageBlock()
    local block = ScenarioObjectiveTracker.StageBlock
    if not block then return end
    for _, key in ipairs({ "NormalBG", "FinalBG", "GlowTexture", "ThemeOverlay" }) do
        if block[key] then block[key]:SetAlpha(0) end
    end
    AddPanel(block, ScenarioObjectiveTracker.Header)
    -- Blizzard resets text and color on every stage
    local function Restyle(self)
        KeepFace(self.Stage, ns.UI.ACCENT)
        KeepFace(self.Name, ns.UI.TEXT)
    end
    hooksecurefunc(block, "UpdateStageBlock", Restyle)
    Restyle(block) -- already built (e.g. /reload inside a scenario)
end

-- Affix icons and currencies (lives) in the header: square, cropped, 1 px border instead of ring and
-- round mask; numbers in mUI font. Blizzard creates them from a pool on every Setup.
local skinnedParts = setmetatable({}, { __mode = "k" })

local function SkinHeaderParts(widget)
    for spell in (widget.spellPool and widget.spellPool:EnumerateActive() or nop) do
        if not skinnedParts[spell] and spell.Icon then
            skinnedParts[spell] = true
            for _, mask in ipairs({ spell.IconMask, spell.CircleMask }) do
                if mask then spell.Icon:RemoveMaskTexture(mask) end
            end
            pcall(spell.Icon.SetTexCoord, spell.Icon, 0.08, 0.92, 0.08, 0.92) -- in case it is still masked
            local border = CreateFrame("Frame", nil, spell)
            border:SetAllPoints(spell.Icon)
            ns.AddBorder(border, true)
        end
        if spell.Border then spell.Border:SetAlpha(0) end -- Blizzard resets the ring on every Setup
        if spell.DebuffBorder then spell.DebuffBorder:SetAlpha(0) end
        KeepFace(spell.StackCount)
    end
    for currency in (widget.currencyPool and widget.currencyPool:EnumerateActive() or nop) do
        KeepFace(currency.Text)
    end
end

local function SkinScenarioHeaderWidget(widget)
    if not widget or not widget.Frame then return end
    -- parts (affixes, lives) are created in Setup after this hook: own hook per widget
    if not skinnedParts[widget] and widget.Setup then
        skinnedParts[widget] = true
        hooksecurefunc(widget, "Setup", SkinHeaderParts)
    end
    SkinHeaderParts(widget)
    widget.Frame:SetAlpha(0)
    if widget.DecorationBottomLeft then widget.DecorationBottomLeft:SetAlpha(0) end
    if widget.ThemeOverlay then widget.ThemeOverlay:SetAlpha(0) end
    AddPanel(widget, ScenarioObjectiveTracker.Header)
    KeepFace(widget.HeaderText, ns.UI.ACCENT)
    local tier = widget.TierFrame -- delves: tier without flag, large in Surf Green
    if tier then
        if tier.Flag then tier.Flag:SetAlpha(0) end
        KeepFace(tier.Text, ns.UI.ACCENT)
    end
end

local function SetupScenarioHeader()
    if ScenarioObjectiveTracker then SkinStageBlock() end
    if UIWidgetBaseScenarioHeaderTemplateMixin and UIWidgetBaseScenarioHeaderTemplateMixin.Setup then
        hooksecurefunc(UIWidgetBaseScenarioHeaderTemplateMixin, "Setup", SkinScenarioHeaderWidget)
    end
    -- existing header widgets (e.g. /reload inside a delve: Blizzard builds them before our hook and
    -- only rebuilds on the next change)
    local container = ScenarioObjectiveTracker and ScenarioObjectiveTracker.StageBlock
        and ScenarioObjectiveTracker.StageBlock.WidgetContainer
    for _, widget in pairs(container and container.widgetFrames or {}) do
        if widget.Frame and widget.HeaderText then SkinScenarioHeaderWidget(widget) end
    end
end

local function SetupSplits()
    if not (ScenarioObjectiveTracker and ScenarioObjectiveTracker.UpdateCriteria) then return end
    hooksecurefunc(ScenarioObjectiveTracker, "UpdateCriteria", UpdateSplits)
    if ObjectiveTrackerManager and ObjectiveTrackerManager.ReleaseFrame then
        hooksecurefunc(ObjectiveTrackerManager, "ReleaseFrame", function(_, frame)
            if frame and frame.muiSplit then frame.muiSplit:Hide() end
        end)
    end
    -- logging in mid-key: completed objectives without time (true); new key: clear
    if C_ChallengeMode.IsChallengeModeActive() then
        for i = 1, select(3, C_Scenario.GetStepInfo()) or 0 do
            local info = C_ScenarioInfo.GetCriteriaInfo(i)
            if info and info.completed then splits[i] = true end
        end
    end
    ns:On("CHALLENGE_MODE_START", function() wipe(splits) end)
    ns:On("CHALLENGE_MODE_RESET", function() wipe(splits) end)
end

local function SetupChallengeBlock()
    local block = ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock
    if not block then return end
    SkinChallengeBlock(block, ScenarioObjectiveTracker.Header)
    hooksecurefunc(block, "UpdateTime", function(self, elapsed) UpdateTimer(self, elapsed, self.timeLimit) end)
    hooksecurefunc(block, "SetUpAffixes", function(self, affixes)
        local frames = {}
        for affix in self.affixPool:EnumerateActive() do frames[#frames + 1] = affix end
        local order = {}
        for i, id in ipairs(affixes or {}) do order[id] = i end
        table.sort(frames, function(a, b) return (order[a.affixID] or 0) < (order[b.affixID] or 0) end)
        LayoutAffixes(self, frames)
    end)
end

-- Demo (Settings > Quest log): replica of the block from the same parts, above the tracker.
-- Starting Blizzard's real block with fake values would taint the tracker.
local demo
local DEMO_LIMIT, DEMO_LEFT = 33 * 60, 21 * 60 + 37
local DEMO_BOSSES = {
    { name = "First boss", time = 4 * 60 + 12 },
    { name = "Second boss", time = 9 * 60 + 48 },
    { name = "Third boss" },
    { name = "Final boss" },
}

local function CreateDemo()
    demo = CreateFrame("Frame", "MeredanUIMythicPlusDemo", UIParent)
    local realHeader = ScenarioObjectiveTracker and ScenarioObjectiveTracker.Header
    local width = realHeader and realHeader:GetWidth() or 0
    if width < 100 then width = 260 end
    demo:SetSize(width, 87 + 40)
    demo:SetFrameStrata("MEDIUM")
    demo:Hide()

    -- header like in the tracker (text + thin line, see SkinHeader)
    local header = CreateFrame("Frame", nil, demo)
    header:SetSize(width, ns.Snap(26))
    header:SetPoint("TOPLEFT")
    local title = header:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerHeaderFont")
    title:SetPoint("LEFT", ns.Snap(8), 0)
    title:SetText(L["Mythic+ demo"])
    local line = header:CreateTexture(nil, "ARTWORK")
    line:SetHeight(ns.PixelSize())
    line:SetPoint("BOTTOMLEFT", 0, ns.Snap(2))
    line:SetPoint("BOTTOMRIGHT", 0, ns.Snap(2))
    local r, g, b = unpack(ns.UI.ACCENT)
    line:SetColorTexture(r, g, b, 0.5)

    local block = CreateFrame("Frame", nil, demo)
    block:SetSize(251, 87)
    block:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -ns.Snap(2))
    block.Level = block:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
    block.TimeLeft = block:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    block.DeathCount = CreateFrame("Frame", nil, block)
    block.DeathCount:SetSize(30, 16)
    block.DeathCount.Icon = block.DeathCount:CreateTexture(nil, "ARTWORK")
    block.DeathCount.Icon:SetAtlas("poi-graveyard-neutral", true)
    block.DeathCount.Icon:SetPoint("LEFT")
    block.DeathCount.Count = block.DeathCount:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall2")
    block.DeathCount.Count:SetPoint("LEFT", block.DeathCount.Icon, "RIGHT", 1, 0)
    block.StatusBar = CreateFrame("StatusBar", nil, block)
    SkinChallengeBlock(block, header)

    block.Level:SetText(CHALLENGE_MODE_POWER_LEVEL:format(12))
    block.TimeLeft:SetText(SecondsToClock(DEMO_LEFT))
    block.DeathCount.Count:SetText("3")
    block.StatusBar:SetMinMaxValues(0, DEMO_LIMIT)
    block.StatusBar:SetValue(DEMO_LEFT)
    UpdateTimer(block, DEMO_LIMIT - DEMO_LEFT, DEMO_LIMIT)
    local frames = {}
    for _, entry in ipairs(C_MythicPlus.GetCurrentAffixes() or {}) do
        local affixID = entry.id
        local _, _, icon = C_ChallengeMode.GetAffixInfo(affixID)
        if icon then
            local affix = CreateFrame("Frame", nil, block, "ScenarioChallengeModeAffixTemplate")
            affix:SetUp(affixID)
            frames[#frames + 1] = affix
        end
    end
    LayoutAffixes(block, frames)

    -- objectives like the real tracker: bosses (completed with time), then enemy forces
    local previous = block
    for i, boss in ipairs(DEMO_BOSSES) do
        local line = CreateFrame("Frame", nil, demo)
        line:SetSize(ns.Snap(215), ns.Snap(16))
        if previous == block then
            line:SetPoint("TOPLEFT", block, "BOTTOMLEFT", ns.Snap(20), -ns.Snap(6))
        else
            line:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -ns.Snap(2))
        end
        local icon = line:CreateTexture(nil, "ARTWORK")
        icon:SetAtlas(boss.time and "ui-questtracker-tracker-check" or "ui-questtracker-objective-nub", false)
        icon:SetSize(12, 12)
        icon:SetPoint("LEFT")
        local text = line:CreateFontString(nil, "OVERLAY", "ObjectiveTrackerLineFont")
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        text:SetText(("%d/1 %s"):format(boss.time and 1 or 0, L[boss.name]))
        if boss.time then text:SetTextColor(0.6, 0.6, 0.6) end
        demo.muiSplitLines = demo.muiSplitLines or {}
        demo.muiSplitLines[i] = { line = line, time = boss.time }
        previous = line
    end
    local forces = CreateFrame("StatusBar", nil, demo)
    forces:SetSize(ns.Snap(190), ns.Snap(14))
    forces:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", ns.Snap(10), -ns.Snap(6))
    forces:SetMinMaxValues(0, 100)
    forces:SetValue(62.47)
    forces.Label = forces:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    FlattenBar(forces)
    demo.muiForces = forces
    demo.muiBlock = block
end

-- update demo from settings (chest times, forces text, boss splits)
local function RefreshDemo()
    if not demo then return end
    UpdateTimer(demo.muiBlock, DEMO_LIMIT - DEMO_LEFT, DEMO_LIMIT)
    demo.muiForces.Label:SetText(ns.db.mplusForces == "percent" and "62.47%" or "62.47% · 287/460")
    for _, entry in ipairs(demo.muiSplitLines) do
        local text = SplitText(entry.line)
        text:SetText(entry.time and SecondsToClock(entry.time) or "")
        text:SetShown(ns.db.mplusSplits ~= false)
    end
end
function ns.RefreshMythicPlusDemo()
    if demo and demo:IsShown() then ns.QuestDemo.Start() end
end

ns.QuestDemo = {
    Start = function()
        if not demo then CreateDemo() end
        RefreshDemo()
        local tracker = ObjectiveTrackerFrame
        demo:ClearAllPoints()
        demo:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 0, 0)
        tracker:SetAlpha(0) -- only hide, never change the tracker itself
        demo:Show()
        -- sample enemy tooltip at the configured tooltip position
        if ns.db.mplusMobTooltip ~= false then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:SetText(L["Demo enemy"], 1, 0.25, 0.25)
            GameTooltip:AddLine(L["Level ?? Humanoid (Elite)"], 1, 1, 1)
            ns.AddForcesTooltipLine(GameTooltip, "0.84")
            GameTooltip:Show()
        else
            GameTooltip:Hide()
        end
    end,
    Stop = function()
        if demo then demo:Hide() end
        GameTooltip:Hide()
        ObjectiveTrackerFrame:SetAlpha(1)
    end,
    IsActive = function() return demo ~= nil and demo:IsShown() end,
}

-- Position ------------------------------------------------------------------------------------

local placing = false
-- Placeholder the tracker hangs from by its top right corner. Blizzard's Edit Mode does not move it;
-- mUI moves the tracker back.
local anchor
local ANCHOR_HEIGHT = 200

-- Default spot: right edge left of the inner right bar (or the screen edge if missing), top edge below
-- buffs/debuffs/private auras (or below the minimap)
local function PlaceAnchorDefault()
    local margin, gap = ns.Snap(ns.SCREEN_MARGIN), ns.Snap(GAP)
    local right = UIParent:GetRight() - margin
    -- innermost visible right bar (with bar 6 the tracker moves further left)
    local bar = ns.InnermostRightBar and ns.InnermostRightBar() or (ns.layoutFrames and ns.layoutFrames.bar5)
    if bar and bar:IsVisible() and bar:GetLeft() then right = bar:GetLeft() - ns.Snap(SIDE_GAP) end
    local top = UIParent:GetTop() - margin
    -- below buffs/debuffs (private auras sit elsewhere with the boss module), otherwise below the minimap
    local auraBottom = ns.AuraStackBottom and ns.AuraStackBottom()
    local minimap = _G["MeredanUIMinimap"]
    if auraBottom then
        top = auraBottom - gap
    elseif minimap and minimap:GetBottom() then
        top = minimap:GetBottom() - gap
    end
    -- top edge flush with the right action bars, but never above the buffs/minimap
    if bar and bar:GetTop() then top = math.min(top, bar:GetTop()) end
    local cx, cy = UIParent:GetCenter()
    ns.PlaceFromCenter(anchor, "TOPRIGHT", right - cx, top - cy)
end

local function Place()
    local tracker = ObjectiveTrackerFrame
    if not (tracker and tracker.SetPointBase and anchor and anchor:GetRight()) then return end
    placing = true
    tracker:ClearAllPointsBase()
    -- from the top right screen corner (negative offset): in the default position Blizzard computes the
    -- height as "parent height + Y offset" - this keeps it on screen
    tracker:SetPointBase("TOPRIGHT", UIParent, "TOPRIGHT",
        anchor:GetRight() - UIParent:GetRight(), anchor:GetTop() - UIParent:GetTop())
    placing = false
end

-- Boss fights and arenas: hide the tracker (like ElvUI). A secure state driver detects boss/arena
-- units; hiding is done by reparenting to a hidden frame - never collapse via code (that rebuilds the
-- tracker and locks quest items). Stays visible in Mythic+ (timer and progress live there).
-- The hidden frame is screen-sized: Blizzard computes the tracker height as "parent height + Y
-- offset" - with height 0 it shrank to 20 px and stayed empty afterwards.
local hidden = CreateFrame("Frame")
hidden:SetAllPoints(UIParent)
hidden:Hide()
local savedParent

local function HideForBoss()
    local tracker = ObjectiveTrackerFrame
    if savedParent or tracker:GetParent() == hidden then return end
    local inInstance = IsInInstance()
    -- instances only: Forever reports boss units outdoors too (tracker kept disappearing)
    if not inInstance then return end
    local _, _, difficulty = GetInstanceInfo()
    if difficulty == 8 then return end -- Mythic+
    savedParent = tracker:GetParent()
    tracker:SetParent(hidden)
end

local function ShowAfterBoss()
    if not savedParent then return end
    ObjectiveTrackerFrame:SetParent(savedParent)
    savedParent = nil
end

local function SetupBossHiding()
    -- Blizzard reparents the tracker itself on updates: during the fight, move it back
    hooksecurefunc(ObjectiveTrackerFrame, "SetParent", function(self, parent)
        if savedParent and parent ~= hidden then
            savedParent = parent
            self:SetParent(hidden)
        end
    end)
    -- no parent: videos, cinematics and Alt+Z hide UIParent - that must not count as a boss fight
    -- (tracker would stay hidden afterwards)
    local watcher = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
    watcher:SetAttribute("_onstate-muiboss", "if newstate == 1 then self:Hide() else self:Show() end")
    watcher:SetScript("OnHide", HideForBoss)
    watcher:SetScript("OnShow", ShowAfterBoss)
    RegisterStateDriver(watcher, "muiboss",
        "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists]"
        .. "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists][@boss5,exists] 1;0")
end

local function Setup()
    local tracker = ObjectiveTrackerFrame
    if not tracker or ns.IS_FOREVER then return end -- Forever: own tracker (Quests/Tracker.lua)

    KeepFont(ObjectiveTrackerLineFont)
    hooksecurefunc(ObjectiveTrackerLineFont, "SetFontObject", function()
        for text in pairs(titleTexts) do ApplyTitleFont(text) end
    end)
    KeepFont(ObjectiveTrackerHeaderFont, ns.UI.TEXT)

    SkinHeader(tracker.Header, ns.UI.ACCENT)
    for _, name in ipairs(MODULES) do
        local module = _G[name]
        if module then
            SkinHeader(module.Header, ns.UI.TEXT)
            if module.AddBlock then hooksecurefunc(module, "AddBlock", OnAddBlock) end
            -- existing blocks and bars (created before our hook, e.g. /reload inside a scenario);
            -- each part guarded: one error must not abort the rest of the setup
            local function Safe(fn, ...)
                local ok, err = pcall(fn, ...)
                if not ok then geterrorhandler()(err) end
            end
            for _, blocks in pairs(module.usedBlocks or {}) do
                for _, block in pairs(blocks) do Safe(OnAddBlock, module, block) end
            end
            for key in pairs(module.usedProgressBars or {}) do Safe(OnProgressBar, module, key) end
            for key in pairs(module.usedTimerBars or {}) do Safe(OnTimerBar, module, key) end
            if module.GetProgressBar then hooksecurefunc(module, "GetProgressBar", OnProgressBar) end
            if module.GetTimerBar then hooksecurefunc(module, "GetTimerBar", OnTimerBar) end
        end
    end

    -- Height: Blizzard computes "parent height + Y offset". In Forever the parent
    -- (RightManagedFrameContainer) is not screen-high and shrinks e.g. when targeting, leaving almost no
    -- room so the tracker hid itself. Hence always compute from UIParent.
    if tracker.UpdateHeight then
        hooksecurefunc(tracker, "UpdateHeight", function(self)
            -- base height: from UIParent in Blizzard's default position (the parent is not screen-high in
            -- Forever), otherwise whatever Blizzard set (moved in Edit Mode)
            local height = self:GetHeight()
            if not (self.IsInDefaultPosition and not self:IsInDefaultPosition()) then
                local _, _, _, _, offsetY = self:GetPoint(1)
                if offsetY then height = UIParent:GetHeight() + offsetY end
            end
            if height and height > 0 then self:SetHeight(math.max(height, 20)) end
        end)
    end
    -- Blizzard re-anchors the tracker on almost every update: restore our position afterwards
    hooksecurefunc(tracker, "SetPoint", function() if not placing then Place() end end)
    anchor = CreateFrame("Frame", "MeredanUIQuestAnchor", UIParent)
    anchor:SetSize(math.max(tracker:GetWidth(), 200), ANCHOR_HEIGHT)
    -- moved or reset: tracker follows (next frame, once the position is settled)
    hooksecurefunc(anchor, "SetPoint", function() C_Timer.After(0, Place) end)
    ns.OnLayout(PlaceAnchorDefault)
    ns.layoutFrames.questlog = anchor
    if ns.PlaceBossFrames then ns.PlaceBossFrames() end -- boss frames to the left of it
    -- scenario objectives hang on a fixed block that doesn't go through AddBlock
    local objectives = ScenarioObjectiveTracker and ScenarioObjectiveTracker.ObjectivesBlock
    if objectives then OnAddBlock(ScenarioObjectiveTracker, objectives) end
    ns.AfterCombat(SetupBossHiding)  -- state drivers can't be set up in combat
    SetupChallengeBlock()
    SetupSplits()
    SetupScenarioHeader()
end

-- after buffs and action bars (they set up on login)
ns:On("PLAYER_LOGIN", function() C_Timer.After(0.2, Setup) end)

