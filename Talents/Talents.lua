-- Talent window (WoW Forever): own window replacing Blizzard's talent frame.
--
--   [icon] Talents                 [Search talents] [Display v] [x]
--          Hunter - Level 14
--   Primary active   Secondary                       Unspent points 5
--   +- Beast Mastery 0 -+ +- Marksmanship 0 -+ +- Survival 0 -+
--   |  [] []            | | [] [] []         | |  [] []       |  <- Blizzard's tree art, dimmed
--   Beast Mastery 0 ...    Click: point - Right-click: undo  [Reset][Apply]
--
-- Forever builds the classic three trees on the modern trait system: one treeID with three groups
-- (C_Traits.GetGroupDisplayInfoByTreeID); points are staged (PurchaseRank/RefundRank) and only
-- committed via C_ClassTalents.CommitConfig. None of this is protected. The talent key and micro
-- button open this window directly. Never touch Blizzard's PlayerSpellsFrame - HideUIPanel from
-- addon code taints the UI panel manager. Inspecting other players stays Blizzard's.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT, PAD = 1240, 740, 18
local TOP = ns.NPC_HEADER_BOTTOM + 52   -- top edge of the trees
local BOTTOM = 58                       -- space for the footer
local GAP = 12
local TREE_HEAD = 58
local NODE = 40
local GOLD = { 1, 0.82, 0 }
local GREY_LINE = { 0.29, 0.29, 0.29 }

local window, panels, tabs = nil, {}, {}
local viewTab              -- displayed spec group (1 = primary, 2 = secondary)
local committing           -- commit in progress
local pendingRefresh
local nodes = {}           -- nodeID -> data of the current view
local searchBox, optionsButton, options, unspentBox, unspentText, summary, applyButton, resetButton, emptyText
local adviceButton, adviceTake, advicePending -- advisor (leveling builds from Talents/Builds.lua)
local ADVICE = { 1, 0.62, 0.15 }             -- "next up" marker (warm orange, stands out)

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.talentWindow ~= false and C_Traits and C_ClassTalents
end

local function Settings()
    ns.db.talentView = ns.db.talentView or { hidePassive = false, showRanks = true }
    return ns.db.talentView
end

local function ActiveTab()
    return C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup() or 1
end

local function ConfigID()
    if viewTab == ActiveTab() then
        return C_ClassTalents.GetActiveConfigID() or C_SpecializationInfo.GetCombatConfigIDForSpecGroup(viewTab)
    end
    return C_SpecializationInfo.GetCombatConfigIDForSpecGroup(viewTab)
end

local function Editable()
    return viewTab == ActiveTab() and not committing and C_ClassTalents.CanEditTalents and C_ClassTalents.CanEditTalents() ~= false
end

-- Background: Blizzard's class art (three panels side by side), one third per tree
local function TreeArt(texture, index)
    local _, class = UnitClass("player")
    local info = C_Texture.GetAtlasInfo("talent-background-" .. class:lower())
    if not info then
        texture:SetColorTexture(0.06, 0.06, 0.07, 1)
        return
    end
    local l, r = info.leftTexCoord, info.rightTexCoord
    local step = (r - l) / 3
    texture:SetTexture(info.file)
    texture:SetTexCoord(l + step * (index - 1), l + step * index, info.topTexCoord, info.bottomTexCoord)
    texture:SetVertexColor(0.5, 0.5, 0.5) -- dimmed
end

-- Data --------------------------------------------------------------------------------------------

local function SpellOf(configID, info)
    local entryID = (info.activeEntry and info.activeEntry.entryID) or (info.entryIDs and info.entryIDs[1])
    local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
    local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
    local spellID = def and def.spellID
    -- Preload spell data: otherwise WoW rebuilds the tooltip on first hover when the data arrives
    -- and our added lines (name, rank, click hint) are lost
    if spellID and C_Spell.RequestLoadSpellData and not C_Spell.IsSpellDataCached(spellID) then
        C_Spell.RequestLoadSpellData(spellID)
    end
    local name = def and def.overrideName and def.overrideName ~= "" and def.overrideName or (spellID and C_Spell.GetSpellName(spellID)) or ""
    local icon = def and def.overrideIcon and def.overrideIcon ~= 0 and def.overrideIcon or (spellID and C_Spell.GetSpellTexture(spellID))
    return entryID, entry, spellID, name, icon
end

-- Read the tree: groups (= the three trees) and their nodes with position, rank and edges
local function ReadTree()
    local configID = ConfigID()
    local config = configID and C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return end
    local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID) or {}
    table.sort(groups, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    local groupIndex, groupIDs = {}, {}
    for i, group in ipairs(groups) do
        if i <= 3 then
            groupIndex[group.groupID] = i
            groupIDs[#groupIDs + 1] = group.groupID
        end
    end
    local spent = {}
    for _, info in ipairs(C_Traits.GetGroupCurrencyInfo(configID, groupIDs) or {}) do
        local currency = info.currencyInfos and info.currencyInfos[1]
        spent[info.traitNodeGroupID] = currency and currency.spent or 0
    end
    local list = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local info = C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.ID ~= 0 and info.isVisible then
            -- tree membership comes from position (Layout); groupIDs are not unique
            local entryID, entry, spellID, name, icon = SpellOf(configID, info)
            if spellID and name ~= "" then -- helper nodes without a spell are skipped
                list[#list + 1] = { id = nodeID, info = info, entryID = entryID, entry = entry,
                    spellID = spellID, name = name, icon = icon }
            end
        end
    end
    local currency = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    local committed = C_Traits.GetTreeCurrencyInfo(configID, treeID, true)
    local unspent = currency and currency[1] and currency[1].quantity or 0
    local before = committed and committed[1] and committed[1].quantity or unspent
    return { configID = configID, treeID = treeID, groups = groups, spent = spent, nodes = list,
        unspent = unspent, staged = math.max(before - unspent, 0) }
end

-- Display ----------------------------------------------------------------------------------------

local function Matches(node, query, hidePassive)
    if hidePassive and node.spellID and C_Spell.IsSpellPassive(node.spellID) then return false end
    return query == "" or node.name:lower():find(query, 1, true) ~= nil
end

local function ShowTooltip(button)
    local node = button.node
    if not node then return end
    -- Data not loaded yet: wait, then build the full tooltip
    if node.spellID and not C_Spell.IsSpellDataCached(node.spellID) and Spell then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:AddLine(node.name, 1, 1, 1)
        GameTooltip:Show()
        Spell:CreateFromSpellID(node.spellID):ContinueOnSpellLoad(function()
            if GameTooltip:IsOwned(button) and button.node == node then ShowTooltip(button) end
        end)
        return
    end
    local info = node.info
    local rank, max = info.ranksPurchased or 0, info.maxRanks or 1
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(node.name, 1, 1, 1)
    GameTooltip:AddLine(L["Rank %d/%d"]:format(rank, max), unpack(ns.UI.MUTED))
    if node.entryID then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip:AppendInfo("GetTraitEntry", node.entryID, math.max(rank, 1))
        if rank > 0 and rank < max then
            GameTooltip_AddBlankLineToTooltip(GameTooltip)
            GameTooltip:AddLine(L["Next rank:"], 1, 1, 1)
            GameTooltip:AppendInfo("GetTraitEntry", node.entryID, rank + 1)
        end
    end
    -- Requirements: points in tree (Blizzard's text) and prerequisite talent
    local configID = window.data and window.data.configID
    local groupName = window.data and window.data.groups[node.group] and window.data.groups[node.group].displayName
    local conditions = {}
    for _, id in ipairs(info.conditionIDs or {}) do conditions[#conditions + 1] = id end
    for _, id in ipairs(node.entry and node.entry.conditionIDs or {}) do conditions[#conditions + 1] = id end
    local gate, gateNeed
    for _, id in ipairs(conditions) do
        local cond = configID and C_Traits.GetConditionInfo(configID, id, false, groupName)
        if cond and not cond.isMet and cond.tooltipText then
            if cond.isGate then
                if not gateNeed or (cond.spentAmountRequired or 0) > gateNeed then gate, gateNeed = cond.tooltipText, cond.spentAmountRequired or 0 end
            else
                GameTooltip:AddLine(cond.tooltipText, 1, 0.31, 0.31, true)
            end
        end
    end
    if gate then GameTooltip:AddLine(gate, 1, 0.31, 0.31, true) end
    if not info.meetsEdgeRequirements then
        -- linked talents in both directions; the prerequisite is the upper one that is not maxed
        local linked = {}
        for _, edge in ipairs(info.visibleEdges or {}) do
            if nodes[edge.targetNode] then linked[#linked + 1] = nodes[edge.targetNode] end
        end
        for _, other in pairs(nodes) do
            for _, edge in ipairs(other.info.visibleEdges or {}) do
                if edge.targetNode == node.id then linked[#linked + 1] = other end
            end
        end
        for _, other in ipairs(linked) do
            if other.posY < node.posY and (other.info.ranksPurchased or 0) < (other.info.maxRanks or 1) then
                GameTooltip:AddLine(L["Requires %d points in %s"]:format(other.info.maxRanks or 1, other.name), 1, 0.31, 0.31, true)
            end
        end
    end
    if node.adviceLevels then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        local levels = table.concat(node.adviceLevels, ", ")
        GameTooltip:AddLine((node.adviceNext and (L["Next up"] .. " · ") or "") .. L["Level %s"]:format(levels),
            ADVICE[1], ADVICE[2], ADVICE[3], true)
    end
    if Editable() and (info.canPurchaseRank or info.canRefundRank) then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
        GameTooltip:AddLine(L["Click: add point · Right-click: undo"], unpack(ns.UI.ACCENT))
    end
    GameTooltip:Show()
end

local function NodeButton(panel, i)
    panel.buttons = panel.buttons or {}
    if panel.buttons[i] then return panel.buttons[i] end
    local button = CreateFrame("Button", nil, panel)
    button:SetFrameLevel(panel:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.glow = button:CreateTexture(nil, "BACKGROUND")
    button.glow:SetPoint("TOPLEFT", -3, 3)
    button.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    button.glow:SetColorTexture(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.35)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.border = ns.AddBorder(button)
    button.badge = CreateFrame("Frame", nil, button)
    button.badge:SetSize(24, 14)
    button.badge:SetPoint("BOTTOMRIGHT", 6, -6)
    button.badge:SetFrameLevel(button:GetFrameLevel() + 6) -- above the advisor marker (+3)
    ns.UI.Box(button.badge, { 0.06, 0.06, 0.06, 1 })
    button.rank = ns.UI.Text(button.badge, 10, "CENTER")
    button.rank:SetPoint("CENTER", 0, 0)
    button:SetScript("OnEnter", ShowTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self, mouse)
        local node = self.node
        if not node then return end
        if IsModifiedClick("CHATLINK") and node.spellID then
            local link = C_Spell.GetSpellLink(node.spellID)
            if link and ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link) elseif link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
            return
        end
        if not Editable() then return end
        local configID = window.data.configID
        if mouse == "RightButton" then
            if node.info.canRefundRank then C_Traits.RefundRank(configID, node.id) end
        elseif node.info.canPurchaseRank then
            if C_Traits.PurchaseRank(configID, node.id) and SOUNDKIT.UI_CLASS_TALENT_NODE_SPEND then PlaySound(SOUNDKIT.UI_CLASS_TALENT_NODE_SPEND) end
        end
        window.Refresh()
        if self:IsMouseMotionFocus() then ShowTooltip(self) end
    end)
    panel.buttons[i] = button
    return button
end

-- Advisor ----------------------------------------------------------------------------------------

local function ClassBuilds()
    local _, class = UnitClass("player")
    return ns.TALENT_BUILDS and ns.TALENT_BUILDS[class] or {}
end

-- Own builds per class (account-wide): { name, own = true, order = { spell IDs } }
local function OwnBuilds()
    local _, class = UnitClass("player")
    ns.root.talentBuilds = ns.root.talentBuilds or {}
    ns.root.talentBuilds[class] = ns.root.talentBuilds[class] or {}
    return ns.root.talentBuilds[class]
end

local function BuildKey(build)
    return (build.own and "own:" or "") .. build.name
end

-- Selected build (per character); nil = never chosen -> first build, false = off
local function CurrentBuild()
    local choice = ns.char and ns.char.talentBuild
    if choice == false then return nil end
    for _, build in ipairs(OwnBuilds()) do
        if BuildKey(build) == choice then return build end
    end
    local builds = ClassBuilds()
    for _, build in ipairs(builds) do
        if build.name == choice then return build end
    end
    return builds[1]
end

-- Save the current allocation as an own build, row by row (top first) so the order stays valid
-- (points per row; arrow prerequisites are always higher up)
local function SaveOwnBuild(name)
    name = strtrim(name or "")
    local data = window and window.data
    if name == "" or not data then return end
    local list = {}
    for _, node in ipairs(data.nodes) do
        if (node.info.ranksPurchased or 0) > 0 and node.spellID then list[#list + 1] = node end
    end
    table.sort(list, function(a, b)
        if a.posY ~= b.posY then return a.posY < b.posY end
        if a.group ~= b.group then return a.group < b.group end
        return a.posX < b.posX
    end)
    local order = {}
    for _, node in ipairs(list) do
        for _ = 1, node.info.ranksPurchased do order[#order + 1] = node.spellID end
    end
    if #order == 0 then return end
    local own = OwnBuilds()
    for i = #own, 1, -1 do
        if own[i].name == name then table.remove(own, i) end -- same name: replace
    end
    own[#own + 1] = { name = name, own = true, firstLevel = 10, order = order }
    ns.char.talentBuild = "own:" .. name
    window.Refresh()
end
ns.SaveOwnTalentBuild = SaveOwnBuild

-- Map a build onto the real tree nodes (by spell ID, else by name). If any entry does not fit
-- (missing talent, rank above max), the whole build is rejected.
local function ResolveBuild(build, list)
    local bySpell, byName = {}, {}
    for _, node in ipairs(list) do
        if node.spellID then bySpell[node.spellID] = node end
        byName[node.name] = node
    end
    -- Rows: all three trees share the same heights -> row = index in the sorted height list.
    -- Blizzard offsets some talents in a row slightly (5730/5740) -> close heights form one row.
    local heights, rowOf = {}, {}
    for _, node in ipairs(list) do heights[node.posY] = true end
    local sorted = {}
    for y in pairs(heights) do sorted[#sorted + 1] = y end
    table.sort(sorted)
    local row, last = -1, nil
    for _, y in ipairs(sorted) do
        if not last or y - last > 300 then row = row + 1 end
        rowOf[y] = row
        last = y
    end
    -- Arrow prerequisites: Forever stores some edges reversed (Intimidation -> Bestial Wrath),
    -- so the prerequisite is always the upper talent of the pair
    local byId, sources = {}, {}
    for _, node in ipairs(list) do byId[node.id] = node end
    for _, node in ipairs(list) do
        for _, edge in ipairs(node.info.visibleEdges or {}) do
            local other = byId[edge.targetNode]
            if other then
                local upper, lower = node, other
                if other.posY < node.posY then upper, lower = other, node end
                sources[lower.id] = sources[lower.id] or {}
                if not tContains(sources[lower.id], upper) then table.insert(sources[lower.id], upper) end
            end
        end
    end
    -- Simulate the learning order: rank <= max, 5 points per row in the tree, arrow prerequisite maxed
    local steps, count, inTree = {}, {}, {}
    for i, id in ipairs(build.order) do
        local node = bySpell[id] or byName[C_Spell.GetSpellName(id) or ""]
        local where = L["Point %d"]:format(i) .. ": "
        if not node then return nil, where .. (C_Spell.GetSpellName(id) or tostring(id)) .. " – " .. L["talent not found"] end
        if (inTree[node.group] or 0) < (rowOf[node.posY] or 0) * 5 then return nil, where .. node.name .. " – " .. L["too few points in the tree"] end
        for _, source in ipairs(sources[node.id] or {}) do
            if (count[source.id] or 0) < (source.info.maxRanks or 1) then return nil, where .. node.name .. " – " .. L["requires %s"]:format(source.name) end
        end
        count[node.id] = (count[node.id] or 0) + 1
        if count[node.id] > (node.info.maxRanks or 1) then return nil, where .. node.name .. " – " .. L["rank above maximum"] end
        inTree[node.group] = (inTree[node.group] or 0) + 1
        steps[i] = { node = node, rank = count[node.id], level = (build.firstLevel or 10) + i - 1 }
    end
    return steps
end

local function AdviceMark(button)
    if button.advice then return button.advice end
    local mark = CreateFrame("Frame", nil, button)
    mark:SetAllPoints()
    mark:SetFrameLevel(button:GetFrameLevel() + 3)
    mark.edges = ns.AddBorder(mark, false, 2)
    local box = CreateFrame("Frame", nil, mark)
    box:SetSize(16, 16)
    box:SetPoint("TOPLEFT", -6, 6)
    box:SetFrameLevel(mark:GetFrameLevel() + 1)
    mark.bg = box:CreateTexture(nil, "BACKGROUND")
    mark.bg:SetAllPoints()
    ns.AddBorder(box)
    mark.number = ns.UI.Text(box, 10, "CENTER", { 0, 0, 0 })
    mark.number:SetPoint("CENTER", 0, 0)
    mark.pulse = mark:CreateAnimationGroup()
    mark.pulse:SetLooping("BOUNCE")
    local fade = mark.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.7)
    button.advice = mark
    return mark
end

local function Line(panel, i)
    panel.lines = panel.lines or {}
    if not panel.lines[i] then
        local line = panel:CreateLine(nil, "ARTWORK")
        line:SetThickness(2)
        panel.lines[i] = line
    end
    return panel.lines[i]
end

local function Layout()
    if not (window and window:IsShown()) then return end
    local UI = ns.UI
    local data = ReadTree()
    window.data = data
    wipe(nodes)
    for _, panel in ipairs(panels) do
        for _, b in ipairs(panel.buttons or {}) do b:Hide() end
        for _, l in ipairs(panel.lines or {}) do l:Hide() end
    end
    emptyText:SetShown(not data)
    for _, panel in ipairs(panels) do panel:SetShown(data ~= nil) end
    -- tabs
    local active = ActiveTab()
    local dual = (GetNumSpecGroups and GetNumSpecGroups() or 1) > 1
    for i, tab in ipairs(tabs) do
        local enabled = i == 1 or dual
        tab:SetEnabled(enabled)
        tab.text:SetTextColor(unpack(i == viewTab and UI.ACCENT or (enabled and UI.MUTED or { 0.45, 0.45, 0.43 })))
        tab.line:SetShown(i == viewTab)
        tab.note:SetText(i == active and L["active"] or (enabled and "" or L["locked"]))
        tab:SetWidth(tab.text:GetUnboundedStringWidth() + tab.note:GetUnboundedStringWidth() + 12)
    end
    if not data then
        unspentText:SetText("0")
        summary:SetText("")
        applyButton:Hide()
        resetButton:Hide()
        adviceTake:Hide()
        return
    end

    -- Positions: Blizzard's node coordinates (posX/posY in 1/10 px), each tree centered in its panel
    local view = Settings()
    local query = strtrim(searchBox:GetText() or ""):lower()
    -- Blizzard places the three trees 400 px (posX/10) apart in one coordinate space:
    -- tree = 400-wide slice from the left edge. Outliers (e.g. hidden helper nodes) must not drive
    -- the scale, so left/top start from the median, not the minimum.
    local xs, ys = {}, {}
    for _, node in ipairs(data.nodes) do
        xs[#xs + 1] = node.info.posX
        ys[#ys + 1] = node.info.posY
    end
    table.sort(xs)
    table.sort(ys)
    local TREE_W = 400
    local midX = xs[math.max(1, math.floor(#xs / 2))] or 0
    local minX = midX - 1.5 * TREE_W * 10 -- middle tree around the median
    local midY = ys[math.max(1, math.floor(#ys / 2))] or 0
    local minY = midY
    for _, y in ipairs(ys) do -- first row: smallest value not far above the median
        if y >= midY - 4500 then minY = y break end
    end
    ns.root.talentDebug = nil
    -- Blizzard's data occasionally has an extra zero (Hunter: Lightning Reflexes posX 102800
    -- instead of 10280, Improved Serpent Sting posY 39300 instead of 3930) - scale back
    local function Fix(value, low, high)
        while value > high and value / 10 >= low do value = value / 10 end
        return value
    end
    for _, node in ipairs(data.nodes) do
        node.posX = Fix(node.info.posX, minX, minX + 3 * TREE_W * 10)
        node.posY = Fix(node.info.posY, minY, minY + 10000)
    end
    local kept = {}
    for _, node in ipairs(data.nodes) do
        local x = (node.posX - minX) / 10
        local y = (node.posY - minY) / 10
        if x >= 0 and x < 3 * TREE_W and y >= 0 and y < 1000 then
            node.group = math.floor(x / TREE_W) + 1
            node.localX = x - (node.group - 1) * TREE_W
            kept[#kept + 1] = node
        end
    end
    data.nodes = kept
    local maxY = minY
    for _, node in ipairs(kept) do maxY = math.max(maxY, node.posY) end
    local bounds = {}
    for _, node in ipairs(kept) do
        local b = bounds[node.group] or {}
        bounds[node.group] = b
        b.minX = math.min(b.minX or node.localX, node.localX)
        b.maxX = math.max(b.maxX or node.localX, node.localX)
    end
    local panelW, panelH = panels[1]:GetWidth(), panels[1]:GetHeight()
    local spanX = 1
    for _, b in pairs(bounds) do spanX = math.max(spanX, b.maxX - b.minX) end
    local spanY = math.max(((maxY or 0) - (minY or 0)) / 10, 1)
    local scale = math.min(1, (panelW - 40 - NODE) / math.max(spanX, 200), (panelH - TREE_HEAD - 60 - NODE) / math.max(spanY, 300))
    local size = math.max(28, math.floor(NODE * math.min(1, scale + 0.15)))

    local counters = {}
    local editable = Editable()
    local staged = C_Traits.GetStagedChanges and { C_Traits.GetStagedChanges(data.configID) } or {}
    local pendingNodes = {}
    for _, id in ipairs(staged[1] or {}) do pendingNodes[id] = true end
    for _, id in ipairs(staged[2] or {}) do pendingNodes[id] = true end
    for _, node in ipairs(data.nodes) do
        local panel = panels[node.group]
        local b = bounds[node.group]
        counters[node.group] = (counters[node.group] or 0) + 1
        local button = NodeButton(panel, counters[node.group])
        button.node = node
        nodes[node.id] = node
        local info = node.info
        local x = panelW / 2 + (node.localX - (b.minX + b.maxX) / 2) * scale - size / 2
        local y = TREE_HEAD + 30 + ((node.posY - minY) / 10) * scale
        button:SetSize(size, size)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", ns.Snap(x), -ns.Snap(y))
        node.button = button
        local rank, max = info.ranksPurchased or 0, info.maxRanks or 1
        local available = info.isAvailable and info.meetsEdgeRequirements
        local maxed = rank >= max
        local edge = { 0, 0, 0 }
        if maxed then
            edge = GOLD
        elseif available and (data.unspent > 0 or rank > 0) and viewTab == active then
            edge = UI.ACCENT
        end
        for _, e in ipairs(button.border) do e:SetVertexColor(edge[1], edge[2], edge[3], 1) end
        button.icon:SetTexture(node.icon or 134400)
        local dim = not available and rank == 0
        button.icon:SetDesaturated(dim)
        button.icon:SetVertexColor(dim and 0.6 or 1, dim and 0.6 or 1, dim and 0.6 or 1)
        button.glow:SetShown(pendingNodes[node.id] == true)
        button.rank:SetText(rank .. "/" .. max)
        button.rank:SetTextColor(unpack(maxed and GOLD or ((available and viewTab == active) and UI.ACCENT or UI.MUTED)))
        button.badge:SetShown(view.showRanks)
        local shown = not view.hidePassive or not (node.spellID and C_Spell.IsSpellPassive(node.spellID))
        button:SetShown(shown)
        node.shown = shown
        button:SetAlpha((query == "" or Matches(node, query, view.hidePassive)) and (dim and 0.75 or 1) or 0.25)
        button:EnableMouse(true)
        button:SetEnabled(true)
        if not editable then button.glow:SetShown(false) end
    end
    -- Advisor: build points still missing, in order
    advicePending = {}
    local build = CurrentBuild()
    local steps, problem
    if build then steps, problem = ResolveBuild(build, data.nodes) end
    for _, node in ipairs(data.nodes) do
        node.adviceLevels = nil
        if node.button.advice then
            node.button.advice:Hide()
            node.button.advice.pulse:Stop()
        end
        node.adviceNext = nil
    end
    if steps then
        local planned = {}
        for _, step in ipairs(steps) do
            local node = step.node
            node.adviceLevels = node.adviceLevels or {}
            table.insert(node.adviceLevels, step.level)
            planned[node.id] = step.rank
            if (node.info.ranksPurchased or 0) < step.rank then advicePending[#advicePending + 1] = step end
        end
        -- Already learned per build: orange border instead of accent/gold; ranks beyond the plan don't count
        for _, node in ipairs(data.nodes) do
            local rank = node.info.ranksPurchased or 0
            if rank > 0 and planned[node.id] and rank <= planned[node.id] then
                for _, e in ipairs(node.button.border) do e:SetVertexColor(ADVICE[1], ADVICE[2], ADVICE[3], 1) end
            end
        end
        -- Mark only the next talent (further numbers mislead: builds often add ranks to the same
        -- talent first); pulse only while a point is free
        local step = advicePending[1]
        if step and step.node.shown and viewTab == active then
            local mark = AdviceMark(step.node.button)
            local free = data.unspent > 0
            local alpha = free and 1 or 0.6
            for _, e in ipairs(mark.edges) do e:SetVertexColor(ADVICE[1], ADVICE[2], ADVICE[3], alpha) end
            mark.number:GetParent():Hide() -- no number: there is only one marker
            mark:Show()
            if free then mark.pulse:Play() end
            step.node.adviceNext = true
        end
    end
    adviceButton.Text:SetText(build and (build.own and (L["Own"] .. " · " .. build.name) or (L["Leveling"] .. " · " .. (build.name:match("^(.-)%s*%(") or build.name)
        .. (build.recommended and ("  " .. ns.UI.IconMarkup("Star", 11, ns.UI.ACCENT, 2)) or ""))) or L["Off"])
    adviceButton.Text:SetTextColor(unpack((build and not steps) and { 1, 0.4, 0.4 } or UI.TEXT))
    adviceButton.invalid = build ~= nil and steps == nil
    adviceButton.problem = problem
    local canTake = steps and editable and data.unspent > 0 and #advicePending > 0
    adviceTake:SetShown(steps ~= nil and viewTab == active)
    adviceTake.Text:SetTextColor(unpack(canTake and ADVICE or UI.MUTED))
    adviceTake:SetEnabled(canTake and true or false)
    -- edges (prerequisites)
    local lineCount = {}
    for _, node in ipairs(data.nodes) do
        for _, edge in ipairs(node.info.visibleEdges or {}) do
            local target = nodes[edge.targetNode]
            if target and target.group == node.group and node.shown and target.shown then
                lineCount[node.group] = (lineCount[node.group] or 0) + 1
                local line = Line(panels[node.group], lineCount[node.group])
                line:SetStartPoint("BOTTOM", node.button, 0, -2)
                line:SetEndPoint("TOP", target.button, 0, 2)
                local color = edge.isActive and UI.ACCENT or GREY_LINE
                line:SetColorTexture(color[1], color[2], color[3], 1)
                line:Show()
            end
        end
    end
    -- tree headers
    local parts = {}
    for i, panel in ipairs(panels) do
        local group = data.groups[i]
        local points = group and data.spent[group.groupID] or 0
        panel.name:SetText(group and group.displayName or "")
        panel.icon:SetTexture(group and group.icon or nil)
        panel.points:SetText(points)
        panel.points:SetTextColor(unpack(points > 0 and UI.ACCENT or UI.MUTED))
        panel.hint:SetText(points > 0 and L["%d points spent"]:format(points) or L["no points yet"])
        if group then parts[#parts + 1] = group.displayName .. " " .. points end
    end
    summary:SetText(table.concat(parts, "  ·  "))
    -- points and buttons
    unspentText:SetText(data.unspent)
    unspentText:SetTextColor(unpack(data.unspent > 0 and { 0.12, 1, 0 } or UI.MUTED))
    for _, e in ipairs(unspentBox.edges) do
        if data.unspent > 0 then e:SetVertexColor(0.12, 1, 0, 0.45) else e:SetVertexColor(0, 0, 0, 1) end
    end
    local hasStaged = C_Traits.ConfigHasStagedChanges(data.configID)
    resetButton:SetShown(viewTab == active and hasStaged)
    applyButton:Show()
    if viewTab ~= active then
        applyButton.Text:SetText(L["Activate"])
        applyButton.Text:SetTextColor(unpack(UI.ACCENT))
        for _, e in ipairs(applyButton.accent) do e:Show() end
    else
        applyButton.Text:SetText(committing and L["Applying …"] or (data.staged > 0 and L["Apply changes (%d)"]:format(data.staged) or L["Apply changes"]))
        applyButton.Text:SetTextColor(unpack(hasStaged and UI.ACCENT or UI.MUTED))
        for _, e in ipairs(applyButton.accent) do e:SetShown(hasStaged) end
    end
end

local function Refresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0, function()
        pendingRefresh = nil
        Layout()
    end)
end

-- Build UI ----------------------------------------------------------------------------------------

local function Apply()
    if viewTab ~= ActiveTab() then
        C_SpecializationInfo.SetActiveSpecGroup(viewTab)
        return
    end
    local data = window.data
    if committing or not (data and C_Traits.ConfigHasStagedChanges(data.configID)) then return end
    local can, reason = C_ClassTalents.CanChangeTalents()
    if not can then
        if reason and reason ~= "" then UIErrorsFrame:AddExternalErrorMessage(reason) end
        return
    end
    if C_ClassTalents.CommitConfig() then
        committing = true
        if SOUNDKIT.UI_CLASS_TALENT_APPLY_CHANGES then PlaySound(SOUNDKIT.UI_CLASS_TALENT_APPLY_CHANGES) end
        C_Timer.After(8, function() if committing then committing = nil; Refresh() end end)
    end
    Refresh()
end

-- Take advice: stage the build's open points in order while points are free
local function TakeAdvice()
    local data = window.data
    if not (data and Editable() and advicePending) then return end
    local free = data.unspent
    for _, step in ipairs(advicePending) do
        if free <= 0 then break end
        if not C_Traits.PurchaseRank(data.configID, step.node.id) then break end
        free = free - 1
    end
    if SOUNDKIT.UI_CLASS_TALENT_NODE_SPEND then PlaySound(SOUNDKIT.UI_CLASS_TALENT_NODE_SPEND) end
    Refresh()
end

local function CreateOptions()
    local UI = ns.UI
    options = CreateFrame("Frame", nil, window)
    options:SetSize(200, 2 * 28 + 12)
    options:SetPoint("TOPRIGHT", optionsButton, "BOTTOMRIGHT", 0, -4)
    options:SetFrameLevel(window:GetFrameLevel() + 60)
    UI.Box(options, { 0.078, 0.078, 0.086, 1 })
    options:Hide()
    local rows = {
        { key = "hidePassive", label = L["Hide passives"] },
        { key = "showRanks", label = L["Show ranks"] },
    }
    for i, entry in ipairs(rows) do
        local row = CreateFrame("Button", nil, options)
        row:SetHeight(28)
        row:SetPoint("TOPLEFT", 0, -6 - (i - 1) * 28)
        row:SetPoint("RIGHT", options, "RIGHT")
        local hover = row:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.06)
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 12, 0)
        UI.CheckBg(box)
        local tick = UI.Icon(box, "Check", 12, UI.ACCENT)
        tick:SetPoint("CENTER")
        local text = UI.Text(row, 13, "LEFT")
        text:SetPoint("LEFT", box, "RIGHT", 10, 0)
        text:SetText(entry.label)
        row.Update = function() tick:SetShown(Settings()[entry.key] and true or false) end
        row:SetScript("OnClick", function()
            local view = Settings()
            view[entry.key] = not view[entry.key]
            row.Update()
            Refresh()
        end)
        row.Update()
        options[i] = row
    end
    options:RegisterEvent("GLOBAL_MOUSE_DOWN")
    options:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not optionsButton:IsMouseOver() then self:Hide() end
    end)
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUITalents", WIDTH, HEIGHT, "talents")
    window.Refresh = Refresh
    window:HookScript("OnShow", function(self)
        -- centered instead of above the chat (the window is large)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        self.dragged = true -- don't dock next to Blizzard's frames (NpcWindow); stay centered
    end)

    -- header right: search and display options left of the X
    searchBox = UI.EditBox(window.header, 26)
    searchBox:SetWidth(220)
    local hint = UI.Text(searchBox, 12, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search talents"])
    searchBox:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        Refresh()
    end)
    optionsButton = UI.Button(window.header, L["Display"], function()
        options:SetShown(not options:IsShown())
        for _, row in ipairs(options) do row.Update() end
    end, 100)
    optionsButton:SetHeight(26)
    optionsButton:SetPoint("RIGHT", window.close, "LEFT", -8, 0)
    local chevron = UI.Icon(optionsButton, "ChevronDown", 12, UI.MUTED)
    chevron:SetPoint("RIGHT", -8, 0)
    optionsButton.Text:ClearAllPoints()
    optionsButton.Text:SetPoint("CENTER", -6, 0)
    searchBox:SetPoint("RIGHT", optionsButton, "LEFT", -8, 0)
    CreateOptions()

    -- tabs primary / secondary
    local labels = { DUAL_SPEC_PRIMARY or L["Primary"], DUAL_SPEC_SECONDARY or L["Secondary"] }
    for i, label in ipairs(labels) do
        local tab = CreateFrame("Button", nil, window)
        tab:SetHeight(20)
        tab.text = UI.Text(tab, 14, "LEFT")
        tab.text:SetPoint("LEFT")
        tab.text:SetText(label)
        tab.note = UI.Text(tab, 11, "LEFT", UI.MUTED)
        tab.note:SetPoint("LEFT", tab.text, "RIGHT", 6, 0)
        tab.line = tab:CreateTexture(nil, "OVERLAY")
        tab.line:SetColorTexture(unpack(UI.ACCENT))
        tab.line:SetPoint("BOTTOMLEFT", 0, -3)
        tab.line:SetPoint("BOTTOMRIGHT", tab.text, "BOTTOMRIGHT", 0, -6)
        tab.line:SetHeight(2)
        tab:SetScript("OnClick", function()
            viewTab = i
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Refresh()
        end)
        if i == 1 then tab:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 18) else tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 22, 0) end
        tabs[i] = tab
    end

    -- unspent points
    unspentBox = CreateFrame("Frame", nil, window)
    unspentBox:SetSize(40, 28)
    unspentBox:SetPoint("TOPRIGHT", -PAD, -ns.NPC_HEADER_BOTTOM - 14)
    local bg = unspentBox:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.FIELD))
    unspentBox.edges = ns.AddBorder(unspentBox)
    unspentText = UI.Text(unspentBox, 17, "CENTER")
    unspentText:SetPoint("CENTER", 0, 0)
    local unspentLabel = UI.Text(window, 12, "RIGHT", UI.MUTED)
    unspentLabel:SetPoint("RIGHT", unspentBox, "LEFT", -10, 0)
    unspentLabel:SetText(L["Unspent points"])

    -- advisor: pick and apply a build
    adviceTake = UI.Button(window, L["Take advice"], TakeAdvice, 110)
    adviceTake:SetHeight(26)
    adviceTake:SetPoint("RIGHT", unspentLabel, "LEFT", -28, 0)
    adviceTake:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Take advice"], 1, 1, 1)
        GameTooltip:AddLine(L["Puts the recommended points up to your level – then apply the changes."], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    adviceTake:HookScript("OnLeave", function() GameTooltip:Hide() end)
    adviceButton = UI.Button(window, "", function(self)
        GameTooltip:Hide()
        -- by category: Leveling / PvE / PvP / Own, each listing only the tree name
        local ACCENT_HEX, GREY = "|cff8ecbb4", "|cff6a6a66"
        local items = { { value = "__off", label = L["Off"] } }
        local trees = {}
        items[#items + 1] = { value = "__h1", inert = true, label = ACCENT_HEX .. L["Leveling"]:upper() .. "|r" }
        for _, build in ipairs(ClassBuilds()) do
            local tree = build.name:match("^(.-)%s*%(") or build.name
            if not tContains(trees, tree) then trees[#trees + 1] = tree end
            -- accent star = recommended starting build (Builds.lua: recommended)
            local star = build.recommended and ("  " .. UI.IconMarkup("Star", 11, UI.ACCENT, 2)) or ""
            items[#items + 1] = { value = build.name, label = "   " .. tree .. star }
        end
        for _, kind in ipairs({ "PvE", "PvP" }) do
            items[#items + 1] = { value = "__h" .. kind, inert = true, label = ACCENT_HEX .. kind:upper() .. "|r  " .. GREY .. L["coming later"] .. "|r" }
            for _, tree in ipairs(trees) do
                items[#items + 1] = { value = "__h" .. kind .. tree, inert = true, label = GREY .. "   " .. tree .. "|r" }
            end
        end
        items[#items + 1] = { value = "__hown", inert = true, label = ACCENT_HEX .. L["Own"]:upper() .. "|r" }
        for _, build in ipairs(OwnBuilds()) do
            -- icons as in Blizzard's loadouts: rename (pen) and delete (X)
            items[#items + 1] = { value = BuildKey(build), label = "   " .. build.name, actions = {
                { icon = "Close", tooltip = DELETE or L["Delete"], onClick = function()
                    StaticPopup_Show("MEREDANUI_DELETE_TALENTS", build.name, nil, build)
                end },
                { icon = "Edit", tooltip = L["Rename"], onClick = function()
                    StaticPopup_Show("MEREDANUI_RENAME_TALENTS", build.name, nil, build)
                end },
            } }
        end
        items[#items + 1] = { value = "__save", label = "   + " .. L["Save current talents"] }
        local current = CurrentBuild()
        UI.OpenList(self, items, current and BuildKey(current) or "__off", function(value)
            if value == "__save" then
                StaticPopup_Show("MEREDANUI_SAVE_TALENTS")
            elseif value:sub(1, 3) ~= "__h" then -- headers and "coming later" do nothing
                ns.char.talentBuild = value ~= "__off" and value or false
                Refresh()
            end
        end)
    end, 230)
    adviceButton:SetHeight(26)
    adviceButton:SetPoint("RIGHT", adviceTake, "LEFT", -8, 0)
    adviceButton.Text:ClearAllPoints()
    adviceButton.Text:SetPoint("LEFT", 10, 0)
    adviceButton.Text:SetPoint("RIGHT", -24, 0)
    adviceButton.Text:SetJustifyH("LEFT")
    local adviceChevron = UI.Icon(adviceButton, "ChevronDown", 12, UI.MUTED)
    adviceChevron:SetPoint("RIGHT", -8, 0)
    adviceButton:HookScript("OnEnter", function(self)
        -- anchored on top so the opened list stays clear
        local build = CurrentBuild()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["Advisor"], 1, 1, 1)
        if build then
            GameTooltip:AddLine(build.name, unpack(ADVICE))
            if build.recommended then
                GameTooltip:AddLine(UI.IconMarkup("Star", 11, UI.ACCENT, 2) .. " " .. L["Recommended for leveling"], unpack(UI.ACCENT))
            end
            if self.invalid then
                GameTooltip:AddLine(L["Doesn't fit the current talent tree – hidden."], 1, 0.4, 0.4, true)
                if self.problem then GameTooltip:AddLine(self.problem, 0.8, 0.8, 0.8, true) end
            end
        else
            GameTooltip:AddLine(L["Pick a build: the next talents get a numbered frame."], nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    adviceButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local adviceLabel = UI.Text(window, 12, "RIGHT", UI.MUTED)
    adviceLabel:SetPoint("RIGHT", adviceButton, "LEFT", -10, 0)
    adviceLabel:SetText(L["Advisor"])

    -- three trees
    local areaW = WIDTH - 2 * PAD
    local panelW = (areaW - 2 * GAP) / 3
    for i = 1, 3 do
        local panel = CreateFrame("Frame", nil, window)
        panel:SetPoint("TOPLEFT", window, "TOPLEFT", PAD + (i - 1) * (panelW + GAP), -TOP)
        panel:SetPoint("BOTTOM", window, "BOTTOM", 0, BOTTOM)
        panel:SetWidth(panelW)
        panel:SetClipsChildren(true)
        local art = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
        art:SetAllPoints()
        TreeArt(art, i)
        local shade = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
        shade:SetAllPoints()
        shade:SetColorTexture(1, 1, 1, 1)
        shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0.3)) -- darker at the bottom
        ns.AddBorder(panel)
        local head = CreateFrame("Frame", nil, panel)
        head:SetPoint("TOPLEFT")
        head:SetPoint("TOPRIGHT")
        head:SetHeight(TREE_HEAD)
        local headBg = head:CreateTexture(nil, "BACKGROUND")
        headBg:SetAllPoints()
        headBg:SetColorTexture(0, 0, 0, 0.45)
        local line = head:CreateTexture(nil, "BORDER")
        line:SetPoint("BOTTOMLEFT")
        line:SetPoint("BOTTOMRIGHT")
        line:SetHeight(ns.PixelSize())
        line:SetColorTexture(0, 0, 0, 1)
        local holder = CreateFrame("Frame", nil, head)
        holder:SetSize(34, 34)
        holder:SetPoint("LEFT", 16, 0)
        ns.AddBorder(holder)
        panel.icon = holder:CreateTexture(nil, "ARTWORK")
        panel.icon:SetAllPoints()
        panel.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        panel.name = UI.Text(head, 15, "LEFT")
        panel.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 12, -2)
        panel.hint = UI.Text(head, 11, "LEFT", UI.MUTED)
        panel.hint:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", 12, 2)
        panel.points = UI.Text(head, 18, "RIGHT")
        panel.points:SetPoint("RIGHT", -16, 0)
        panels[i] = panel
    end
    emptyText = UI.Text(window, 13, "CENTER", UI.MUTED)
    emptyText:SetPoint("CENTER")
    emptyText:SetText(L["Talents are not available yet."])

    -- footer
    summary = UI.Text(window, 12, "LEFT", UI.MUTED)
    summary:SetPoint("BOTTOMLEFT", PAD, 24)
    applyButton = UI.Button(window, L["Apply changes"], Apply, 190)
    applyButton:SetHeight(30)
    applyButton:SetPoint("BOTTOMRIGHT", -PAD, 16)
    applyButton.accent = ns.AddBorder(applyButton, true)
    for _, e in ipairs(applyButton.accent) do e:SetVertexColor(unpack(UI.ACCENT)) end
    resetButton = UI.Button(window, L["Reset"], function()
        if window.data then C_Traits.RollbackConfig(window.data.configID) end
        Refresh()
    end, 120)
    resetButton:SetHeight(30)
    resetButton:SetPoint("RIGHT", applyButton, "LEFT", -8, 0)
    local clickHint = UI.Text(window, 12, "RIGHT", UI.MUTED)
    clickHint:SetPoint("RIGHT", resetButton, "LEFT", -12, 0)
    clickHint:SetText(L["Click: add point · Right-click: undo"])

    window:HookScript("OnShow", function()
        viewTab = ActiveTab()
        searchBox:SetText("")
        options:Hide()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        local icon = "Interface\\Icons\\ClassIcon_" .. class:sub(1, 1) .. class:sub(2):lower()
        window:SetNpc(nil, TALENTS or L["Talents"], (color and color:WrapTextInColorCode(UnitClass("player")) or UnitClass("player"))
            .. "  ·  " .. L["Level %d"]:format(UnitLevel("player")), icon)
        Layout()
    end)
    window:HookScript("OnHide", function()
        options:Hide()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)
end

-- Respect Blizzard's lock: talents only from the unlock level (earlier in Forever due to the Legacy
-- tree; TalentMicroButton:GetTalentUnlockLevel, Camelot override). Locked: Blizzard's red error.
local function TalentsLocked()
    local button = TalentMicroButton or PlayerSpellsMicroButton
    local unlock = button and button.GetTalentUnlockLevel and button:GetTalentUnlockLevel()
        or (Constants and Constants.LevelConstsExposed and Constants.LevelConstsExposed.MIN_TALENT_LEVEL) or 10
    if UnitLevel("player") >= unlock then return false end
    local text = FEATURE_BECOMES_AVAILABLE_AT_LEVEL and FEATURE_BECOMES_AVAILABLE_AT_LEVEL:format(unlock)
        or (button and button.disabledTooltip)
    if text then UIErrorsFrame:AddMessage(text, 1, 0.1, 0.1) end
    return true
end

local function Toggle()
    if not window then CreateWindow() end
    if not window:IsShown() and TalentsLocked() then return end
    window:SetShown(not window:IsShown())
end
ns.ToggleTalents = Toggle

-- Preview: open the Legacy window even while still locked (view only)
ns.AddCommand("legacy", L["open the Legacy window (preview)"], function()
    if InCombatLockdown() then return end
    -- mUI window (Talents/Legacy.lua), shown as preview even while locked
    if ns.ToggleLegacy and ns.db.legacyWindow ~= false then return ns.ToggleLegacy(true) end
    if not LegacySystemFrame and LegacySystemFrame_LoadUI then LegacySystemFrame_LoadUI() end
    if LegacySystemFrame then ShowUIPanel(LegacySystemFrame) end
end, true)

ns:On("PLAYER_LOGIN", function()
    ns.root.talentLog = nil
    if not Enabled() then return end
    -- N and the talent button open this window directly. Blizzard's frame stays closed: closing it
    -- via HideUIPanel taints the UI panel manager (Settings then raise ADDON_ACTION_FORBIDDEN).
    local toggle = CreateFrame("Button", "MeredanUITalentsToggle", UIParent)
    toggle:SetScript("OnClick", function() Toggle() end)
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        ClearOverrideBindings(toggle)
        for _, key in ipairs({ GetBindingKey("TOGGLETALENTS") }) do
            SetOverrideBindingClick(toggle, false, key, "MeredanUITalentsToggle", "LeftButton")
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)
    if TalentMicroButton then
        -- only the click is replaced; tooltip and look stay Blizzard's
        TalentMicroButton:SetScript("OnClick", function() Toggle() end)
    end
    for _, event in ipairs({ "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_LIST_UPDATED",
        "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_LEVEL_UP",
        "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
        ns:On(event, function() if window and window:IsShown() then Refresh() end end)
    end
    ns:On("TRAIT_CONFIG_UPDATED", function()
        committing = nil
        if window and window:IsShown() then Refresh() end
    end)
    ns:On("CONFIG_COMMIT_FAILED", function()
        committing = nil
        if window and window:IsShown() then Refresh() end
    end)
end)
