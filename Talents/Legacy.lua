-- Legacy (WoW Forever "Legacy System"): own window replacing Blizzard's LegacySystemFrame.
-- Tabs on the right: Rewards (score, level bar, reward cards), Challenges (categories | cards with
-- criteria, tracking), Tree (three trees | nodes with ranks, apply/reset).
--
-- Data (from Blizzard_LegacySystem):
--   Rewards = renown track of faction 2802 (C_MajorFactions); points = renown level.
--   Challenges = regular achievements (GetCategoryList/GetAchievementInfo); points per achievement via
--     C_Traits.GetTraitCurrencyForAchievement(4225, id); tracking via C_ContentTracking.
--   Tree = three trait trees (1187/1188/1189), shared currency 4225, purchases staged until
--     CommitConfig. None of it is protected.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT, PAD = 980, 640, 18
local FACTION, CURRENCY = 2802, 4225
local GOLD = { 0.85, 0.71, 0.42 }
local TREES = {
    { id = 1187, atlas = "UI-Legacy-Tree-Professions", name = function() return LEGACY_TREE_PROFESSIONS or L["Professions"] end },
    { id = 1188, atlas = "UI-Legacy-Tree-Adventure", name = function() return LEGACY_TREE_ADVENTURE or L["Adventure"] end },
    { id = 1189, atlas = "UI-Legacy-Tree-Progression", name = function() return LEGACY_TREE_PROGRESSION or L["Ingenuity"] end },
}
local TABS = {
    { key = "rewards", label = "Rewards", icon = "Interface/Icons/UI_Chat" },
    { key = "challenges", label = "Challenges", icon = "Interface/Icons/achievement_guildperk_honorablemention" },
    { key = "tree", label = "Tree", icon = "Interface/Icons/achievement_guildperk_everybodysfriend" },
}

local window, tabs, pages = nil, {}, {}
local current = "rewards"
local Refresh

local function Enabled() return ns.IS_FOREVER and ns.db and ns.db.legacyWindow ~= false end
local function Points() return C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel(FACTION) or 0 end
local function Unlocked() return Points() > 0 end

-- Tree background crop: drops Blizzard's left column (vertical divider) and top edge
local BOARD_CROP = { 120, 24, 64, 24 }

-- Fill with Blizzard art edge to edge: crop its own decorative frame (inset px) and crop the rest to
-- the area's aspect ratio instead of stretching. inset: number (all sides) or { left, right, top, bottom }
-- in image pixels.
local function CoverAtlas(tex, atlas, inset)
    local info = C_Texture.GetAtlasInfo(atlas)
    local w, h = tex:GetParent():GetSize()
    if not info or not info.file or w <= 0 or h <= 0 then return tex:SetAtlas(atlas) end
    local il, ir, it, ib
    if type(inset) == "table" then il, ir, it, ib = inset[1], inset[2], inset[3], inset[4]
    else il, ir, it, ib = inset, inset, inset, inset end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local du, dv = (r - l) / info.width, (b - t) / info.height
    l, r, t, b = l + il * du, r - ir * du, t + it * dv, b - ib * dv
    local aw, ah = info.width - il - ir, info.height - it - ib
    if aw / ah > w / h then
        local cut = (aw - ah * w / h) / 2 * du
        l, r = l + cut, r - cut
    else
        local cut = (ah - aw * h / w) / 2 * dv
        t, b = t + cut, b - cut
    end
    tex:SetTexture(info.file)
    tex:SetTexCoord(l, r, t, b)
end

-- Small flat shield with a number (points)
local function Shield(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size + 4)
    ns.UI.Box(f, ns.UI.FIELD)
    f.edges = ns.AddBorder(f)
    for _, e in ipairs(f.edges) do e:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.8) end
    f.text = ns.UI.Text(f, math.floor(size * 0.5), "CENTER")
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetTextColor(unpack(GOLD))
    return f
end

-- 1. Rewards -------------------------------------------------------------------------------------

local function BuildRewards(page)
    local UI = ns.UI
    -- Blizzard's Legacy art, dimmed, as background
    page.art = page:CreateTexture(nil, "BACKGROUND")
    page.art:SetAllPoints()
    page:SetScript("OnSizeChanged", function() CoverAtlas(page.art, "Legacy-Rewards-Tracker-background", 28) end)
    page.art:SetVertexColor(0.45, 0.45, 0.45)
    -- top center: large score, label and next reward below
    page.big = UI.Text(page, 52, "CENTER")
    if ns.DISPLAY_FONT then page.big:SetFont(ns.DISPLAY_FONT, ns.FontPx and ns.FontPx(52) or 52, "") end
    page.big:SetTextColor(unpack(GOLD))
    page.big:SetPoint("TOP", 0, -14)
    page.label = UI.Text(page, 16, "CENTER")
    page.label:SetPoint("TOP", page.big, "BOTTOM", 0, -6)
    page.next = UI.Text(page, 13, "CENTER", UI.MUTED)
    page.next:SetPoint("TOP", page.label, "BOTTOM", 0, -6)

    page.bar = CreateFrame("StatusBar", nil, page)
    page.bar:SetHeight(12)
    page.bar:SetPoint("TOPLEFT", 16, -140) -- 16 px inset from the background art
    page.bar:SetPoint("TOPRIGHT", -16, -140)
    page.bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    page.bar:SetStatusBarColor(unpack(GOLD))
    page.bar:SetMinMaxValues(0, 1)
    UI.Box(page.bar, { 0.04, 0.05, 0.05, 1 })
    ns.AddBorder(page.bar)
    page.ticks, page.cards = {}, {}
end

-- Tall card: level on top, large icon, wrapping name, status at the bottom
local function RewardCard(page, i)
    if page.cards[i] then return page.cards[i] end
    local UI = ns.UI
    local card = CreateFrame("Frame", nil, page)
    UI.Box(card, { 0.06, 0.07, 0.07, 0.94 })
    card:SetClipsChildren(true)
    -- subtle gradient instead of an image (an upscaled icon looks blurry)
    card.shade = card:CreateTexture(nil, "BACKGROUND", nil, 3)
    card.shade:SetAllPoints()
    card.shade:SetColorTexture(1, 1, 1, 1)
    card.shade:SetGradient("VERTICAL", CreateColor(0.05, 0.06, 0.06, 0.6), CreateColor(0.1, 0.12, 0.12, 0.6))
    card.edges = ns.AddBorder(card)
    card.tag = CreateFrame("Frame", nil, card)
    card.tag:SetSize(84, 20)
    card.tag:SetPoint("TOP", 0, -12)
    UI.Box(card.tag, { 0.56, 0.8, 0.71, 0.18 })
    card.tag.text = UI.Text(card.tag, 11, "CENTER", UI.ACCENT)
    card.tag.text:SetPoint("CENTER")
    card.tag.text:SetText(L["NEXT"])
    card.level = CreateFrame("Frame", nil, card)
    card.level:SetSize(46, 24)
    card.level:SetPoint("TOP", 0, 12)
    card.level:SetFrameLevel(card:GetFrameLevel() + 2)
    UI.Box(card.level, ns.UI.FIELD)
    card.level.edges = ns.AddBorder(card.level)
    card.level.text = UI.Text(card.level, 13, "CENTER")
    card.level.text:SetPoint("CENTER")
    local holder = CreateFrame("Frame", nil, card)
    holder:SetSize(72, 72)
    holder:SetPoint("BOTTOM", card, "CENTER", 0, 14) -- icon just above card center, text below
    ns.AddSlotBackground(holder)
    card.iconEdges = ns.AddBorder(holder, false, 2)
    card.icon = holder:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints()
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.kind = UI.Text(card, 11, "CENTER", UI.MUTED)
    card.kind:SetPoint("TOP", holder, "BOTTOM", 0, -14)
    card.name = UI.Text(card, 16, "CENTER")
    card.name:SetPoint("TOP", card.kind, "BOTTOM", 0, -6)
    card.name:SetPoint("LEFT", 12, 0)
    card.name:SetPoint("RIGHT", -12, 0)
    card.name:SetWordWrap(true)
    card.need = UI.Text(card, 13, "CENTER", UI.MUTED)
    card.need:SetPoint("TOP", card.name, "BOTTOM", 0, -10)
    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        if not self.title then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.title, 1, 1, 1)
        if self.desc and self.desc ~= "" then GameTooltip:AddLine(self.desc, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page.cards[i] = card
    return card
end

local function RefreshRewards(page)
    local UI = ns.UI
    local points = Points()
    local levels = C_MajorFactions and C_MajorFactions.GetRenownLevels(FACTION)
    page.big:SetText(points)
    page.label:SetText(L["Legacy points"])
    for _, card in ipairs(page.cards) do card:Hide() end
    for _, tick in ipairs(page.ticks) do tick:Hide() end
    if not levels or #levels == 0 then
        page.next:SetText("")
        page.bar:SetValue(0)
        C_Timer.After(1, function() if window and window:IsShown() and current == "rewards" then Refresh() end end)
        return
    end
    local nextLevel
    for _, li in ipairs(levels) do
        if li.level > points then nextLevel = li.level break end
    end
    page.next:SetText(nextLevel and L["Next reward at %d"]:format(nextLevel) or L["All rewards earned"])
    -- Cards evenly spaced; one marker centered above each card, the fill runs card to card
    local gap, inset = 16, 16 -- gap between cards and inset from the background art
    local width, height = page:GetWidth() - 2 * inset, page:GetHeight()
    local cardW = (width - (#levels - 1) * gap) / #levels
    local cardTop = 186 -- right below the bar; cards extend to the bottom
    local cardH = math.max(height - cardTop - inset, 200)
    local fill, prevLevel, prevX = 0, 0, 0
    for i, li in ipairs(levels) do
        local center = (i - 1) * (cardW + gap) + cardW / 2 -- the bar itself starts at inset
        -- Flat diamond with the level on the bar: border = larger diamond, fill = smaller one on top
        local tick = page.ticks[i]
        if not tick then
            tick = CreateFrame("Frame", nil, page)
            tick:SetSize(46, 46)
            tick:SetFrameLevel(page.bar:GetFrameLevel() + 3)
            tick.edge = tick:CreateTexture(nil, "ARTWORK", nil, 1)
            ns.SetIcon(tick.edge, "Diamond")
            tick.edge:SetAllPoints()
            tick.fill = tick:CreateTexture(nil, "ARTWORK", nil, 2)
            ns.SetIcon(tick.fill, "Diamond")
            tick.fill:SetPoint("TOPLEFT", 3, -3)
            tick.fill:SetPoint("BOTTOMRIGHT", -3, 3)
            tick.fill:SetVertexColor(0.07, 0.085, 0.085, 1)
            tick.text = UI.Text(tick, 14, "CENTER")
            tick.text:SetPoint("CENTER", 0, 0)
            page.ticks[i] = tick
        end
        local reached = li.level <= points
        tick.edge:SetVertexColor(unpack(reached and GOLD or { 0.3, 0.33, 0.32, 1 }))
        tick.text:SetText(li.level)
        tick.text:SetTextColor(unpack(reached and GOLD or UI.MUTED))
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", page.bar, "LEFT", center, 0)
        tick:Show()
        if points >= li.level then
            fill = center
        elseif points > prevLevel then
            fill = prevX + (center - prevX) * (points - prevLevel) / (li.level - prevLevel)
        end
        prevLevel, prevX = li.level, center

        local card = RewardCard(page, i)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", inset + (i - 1) * (cardW + gap), -cardTop)
        card:SetSize(cardW, cardH)
        local earned = li.level <= points
        local rewards = C_MajorFactions.GetRenownRewardsForLevel(FACTION, li.level) or {}
        local reward = rewards[1]
        local icon, name, desc
        if reward and RenownRewardUtil and RenownRewardUtil.GetRenownRewardInfo then
            icon, name, desc = RenownRewardUtil.GetRenownRewardInfo(reward, function()
                if window and window:IsShown() then Refresh() end
            end)
        end
        local isNext = li.level == nextLevel
        card.icon:SetTexture(icon or 134400)
        card.icon:SetDesaturated(not earned)
        card.icon:SetAlpha(earned and 1 or 0.7)
        card.name:SetText(name or "")
        card.name:SetTextColor(unpack((earned or isNext) and UI.TEXT or UI.MUTED))
        card.level:Hide() -- level is shown as a diamond on the bar
        -- Reward kind (pet, mount, tabard ...): item subtype, else item type
        local kind
        if reward and reward.itemID then
            local _, itemType, itemSubType = C_Item.GetItemInfoInstant(reward.itemID)
            kind = itemSubType ~= "" and itemSubType or itemType
        end
        card.kind:SetText(kind and kind:upper() or "")
        card.tag:SetShown(isNext)
        card.need:SetText(earned and (ns.UI.ACCENT_HEX .. L["Earned"] .. "|r")
            or L["%d more points"]:format(li.level - points))
        local edge = (earned or isNext) and UI.ACCENT or { 0.15, 0.18, 0.17, 1 }
        for _, e in ipairs(card.edges) do e:SetVertexColor(unpack(edge)) end
        for _, e in ipairs(card.iconEdges) do e:SetVertexColor(unpack(earned and GOLD or edge)) end
        card.title, card.desc = name, desc
        card:Show()
    end
    page.bar:SetMinMaxValues(0, math.max(page.bar:GetWidth(), 1))
    page.bar:SetValue(fill)
end

-- 2. Challenges -----------------------------------------------------------------------------

local collapsed, selectedCategory, expanded = {}, nil, nil
local showCompleted, showIncomplete = true, true
local searchSet -- nil = no search

local function ChallengePoints(id)
    return C_Traits and C_Traits.GetTraitCurrencyForAchievement and C_Traits.GetTraitCurrencyForAchievement(CURRENCY, id) or 0
end

local function Challenge(category, index)
    local id, name, _, completed, month, day, year, description, flags, icon, rewardText, _, wasEarnedByMe =
        GetAchievementInfo(category, index)
    if not id then return end
    return { id = id, name = name, done = completed and wasEarnedByMe, month = month, day = day, year = year,
        description = description, icon = icon, reward = rewardText, points = ChallengePoints(id),
        account = flags and ACHIEVEMENT_FLAGS_ACCOUNT and bit.band(flags, ACHIEVEMENT_FLAGS_ACCOUNT) ~= 0 }
end

local function Visible(c)
    if searchSet and not searchSet[c.id] then return false end
    if c.done then return showCompleted end
    return showIncomplete
end

local function CategoryChallenges(category)
    local list = {}
    local total = GetCategoryNumAchievements(category) or 0
    for i = 1, total do
        local c = Challenge(category, i)
        if c and Visible(c) then list[#list + 1] = c end
    end
    return list
end

local function CategoryCount(category)
    local done, total = 0, 0
    for i = 1, GetCategoryNumAchievements(category) or 0 do
        local c = Challenge(category, i)
        if c then
            total = total + 1
            if c.done then done = done + 1 end
        end
    end
    return done, total
end

-- Category tree: top level (parent -1) with subcategories; empty ones hidden
local function CategoryTree()
    local tops, children = {}, {}
    for _, id in ipairs(GetCategoryList() or {}) do
        local name, parent = GetCategoryInfo(id)
        local entry = { id = id, name = name, count = #CategoryChallenges(id) }
        if parent == -1 then
            tops[#tops + 1] = entry
        else
            children[parent] = children[parent] or {}
            table.insert(children[parent], entry)
        end
    end
    local rows = {}
    for _, top in ipairs(tops) do
        local kids = {}
        local sum = top.count
        for _, kid in ipairs(children[top.id] or {}) do
            if kid.count > 0 then kids[#kids + 1] = kid; sum = sum + kid.count end
        end
        if sum > 0 then
            rows[#rows + 1] = { entry = top, top = true, hasKids = #kids > 0 }
            if not collapsed[top.id] then
                for _, kid in ipairs(kids) do rows[#rows + 1] = { entry = kid } end
            end
        end
    end
    return rows
end

local function BuildChallenges(page)
    local UI = ns.UI
    page.search = UI.EditBox(page, 28)
    page.search:SetPoint("TOPLEFT", 0, 0)
    page.search:SetWidth(200)
    local hint = UI.Text(page.search, 12, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search"])
    page.search:HookScript("OnTextChanged", function(self)
        local text = self:GetText()
        hint:SetShown(text == "")
        if text == "" then searchSet = nil; Refresh() else SetAchievementSearchString(text) end
    end)
    page.filter = UI.IconButton(page, "Filter", function(self)
        local function Item(key, label, on)
            return { value = key, label = (on and UI.IconMarkup("Check", 12, UI.ACCENT, 1) or "   ") .. "  " .. label }
        end
        UI.OpenList(self, {
            Item("done", ACHIEVEMENTFRAME_FILTER_COMPLETED or L["Completed"], showCompleted),
            Item("open", ACHIEVEMENTFRAME_FILTER_INCOMPLETE or L["Incomplete"], showIncomplete),
        }, nil, function(value)
            if value == "done" then showCompleted = not showCompleted else showIncomplete = not showIncomplete end
            if not showCompleted and not showIncomplete then showCompleted, showIncomplete = true, true end
            Refresh()
        end, { menu = true })
    end, 28)
    page.filter.icon:SetSize(14, 14)
    page.filter:SetPoint("LEFT", page.search, "RIGHT", 6, 0)

    page.cats = UI.ScrollArea(page)
    page.cats:SetPoint("TOPLEFT", page.search, "BOTTOMLEFT", 0, -8)
    page.cats:SetPoint("BOTTOMLEFT", 0, 0)
    page.cats:SetWidth(226)
    page.cats.child:SetWidth(226)
    page.catRows = {}

    page.total = UI.Text(page, 13, "LEFT", UI.MUTED)
    page.total:SetPoint("TOPLEFT", 262, -6)
    page.totalBar = CreateFrame("StatusBar", nil, page)
    page.totalBar:SetHeight(8)
    page.totalBar:SetPoint("LEFT", page.total, "RIGHT", 10, 0)
    page.totalBar:SetPoint("RIGHT", page, "RIGHT", -14, 0)
    page.totalBar:SetPoint("TOP", page.total, "TOP", 0, -4)
    page.totalBar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    page.totalBar:SetStatusBarColor(unpack(GOLD))
    page.totalBar:SetMinMaxValues(0, 1)
    UI.Box(page.totalBar, { 0.04, 0.05, 0.05, 1 })

    page.list = UI.ScrollArea(page)
    page.list:SetPoint("TOPLEFT", 262, -36)
    page.list:SetPoint("BOTTOMRIGHT", -14, 0)
    page.listRows = {}
    page.empty = UI.Text(page, 13, "CENTER", UI.MUTED)
    page.empty:SetPoint("CENTER", page.list, "CENTER")
    page.empty:SetText(LEGACY_NO_CHALLENGES or L["No challenges found."])

    page:RegisterEvent("ACHIEVEMENT_SEARCH_UPDATED")
    page:RegisterEvent("ACHIEVEMENT_EARNED")
    page:RegisterEvent("CRITERIA_UPDATE")
    page:RegisterEvent("CONTENT_TRACKING_UPDATE")
    page:SetScript("OnEvent", function(_, event)
        if event == "ACHIEVEMENT_SEARCH_UPDATED" then
            if page.search:GetText() == "" then searchSet = nil else
                searchSet = {}
                for i = 1, GetNumFilteredAchievements() do searchSet[GetFilteredAchievementID(i)] = true end
            end
        end
        if window and window:IsShown() and current == "challenges" then Refresh() end
    end)
end

local function CategoryRow(page, i)
    if page.catRows[i] then return page.catRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, page.cats.child)
    row:SetHeight(24)
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(unpack(UI.HOVER))
    hover:Hide()
    row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(1, 1, 1, 0.05)
    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    row.strip:SetColorTexture(unpack(UI.ACCENT))
    row.text = UI.Text(row, 13, "LEFT")
    row.count = UI.Text(row, 11, "RIGHT", UI.MUTED)
    row.count:SetPoint("RIGHT", -8, 0)
    row.sign = UI.Text(row, 13, "RIGHT", UI.MUTED)
    row:SetScript("OnEnter", function() hover:Show() end)
    row:SetScript("OnLeave", function() hover:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.top and self.hasKids then collapsed[self.id] = not collapsed[self.id] end
        if self.top and self.hasKids and #CategoryChallenges(self.id) == 0 then Refresh() return end
        selectedCategory, expanded = self.id, nil
        Refresh()
    end)
    page.catRows[i] = row
    return row
end

local function ChallengeRow(page, i)
    if page.listRows[i] then return page.listRows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, page.list.child)
    -- Inner border: an outer one gets clipped by the scroll list and collides with neighbor cards
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.078, 0.094, 0.094, 1)
    row.edges = ns.AddBorder(row, true)
    row:SetScript("OnEnter", function() bg:SetColorTexture(0.1, 0.12, 0.12, 1) end)
    row:SetScript("OnLeave", function() bg:SetColorTexture(0.078, 0.094, 0.094, 1) end)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(40, 40)
    holder:SetPoint("TOPLEFT", 10, -10)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    row.icon = holder:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.shield = Shield(row, 26)
    row.shield:SetPoint("TOPRIGHT", -10, -12)
    row.track = CreateFrame("Button", nil, row)
    row.track:SetSize(14, 14)
    row.track:SetPoint("RIGHT", row.shield, "LEFT", -12, 0)
    UI.CheckBg(row.track)
    row.track.tick = UI.Icon(row.track, "Check", 10, UI.ACCENT)
    row.track.tick:SetPoint("CENTER")
    row.track:SetScript("OnClick", function(self) self:GetParent():ToggleTrack() end)
    row.track:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(TRACK_ACHIEVEMENT or L["Track"], 1, 1, 1)
        GameTooltip:Show()
    end)
    row.track:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.title = UI.Text(row, 14, "LEFT")
    row.title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 12, -2)
    row.title:SetPoint("RIGHT", row.track, "LEFT", -10, 0)
    row.desc = UI.Text(row, 12, "LEFT", UI.MUTED)
    row.desc:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.desc:SetPoint("RIGHT", row.shield, "LEFT", -10, 0)
    row.desc:SetWordWrap(true)
    row.date = UI.Text(row, 11, "RIGHT", UI.ACCENT)
    row.date:SetPoint("TOPRIGHT", row.shield, "BOTTOMRIGHT", 0, -6)
    row.criteria = {}
    function row:ToggleTrack()
        local c = self.challenge
        local T = Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
        if not (c and T and C_ContentTracking) then return end
        if C_ContentTracking.IsTracking(T, c.id) then
            C_ContentTracking.StopTracking(T, c.id, Enum.ContentTrackingStopType.Manual)
        elseif c.done then
            UIErrorsFrame:AddMessage(ERR_ACHIEVEMENT_WATCH_COMPLETED or "", 1, 0.1, 0.1)
        elseif #C_ContentTracking.GetTrackedIDs(T) >= ((Constants.ContentTrackingConsts or {}).MaxTrackedAchievements or 10) then
            UIErrorsFrame:AddMessage((ACHIEVEMENT_WATCH_TOO_MANY or ""):format(10), 1, 0.1, 0.1)
        else
            local err = C_ContentTracking.StartTracking(T, c.id)
            if err and ContentTrackingUtil and ContentTrackingUtil.DisplayTrackingError then ContentTrackingUtil.DisplayTrackingError(err) end
        end
        Refresh()
    end
    row:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and self.challenge then
            local link = GetAchievementLink(self.challenge.id)
            if link then ChatEdit_InsertLink(link) end
            return
        end
        if IsModifiedClick("QUESTWATCHTOGGLE") then self:ToggleTrack() return end
        expanded = expanded ~= self.challenge.id and self.challenge.id or nil
        Refresh()
    end)
    row.shield:EnableMouse(true)
    row.shield:SetScript("OnEnter", function(self)
        local c = row.challenge
        if not c then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["%d legacy points"]:format(c.points), 1, 1, 1)
        if c.reward and c.reward ~= "" then GameTooltip:AddLine(c.reward, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    row.shield:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page.listRows[i] = row
    return row
end

-- Criteria of an expanded challenge: text or a "q / req" bar
local function FillCriteria(row, width)
    for _, line in ipairs(row.criteria) do line:Hide() end
    local id = row.challenge.id
    local n = GetAchievementNumCriteria(id) or 0
    local y = 0
    for c = 1, n do
        local text, _, done, quantity, required, _, flags = GetAchievementCriteriaInfo(id, c)
        local line = row.criteria[c]
        if not line then
            line = CreateFrame("Frame", nil, row)
            line:SetHeight(20)
            line.text = ns.UI.Text(line, 12, "LEFT")
            line.text:SetPoint("LEFT")
            line.bar = CreateFrame("StatusBar", nil, line)
            line.bar:SetHeight(10)
            line.bar:SetPoint("LEFT", line, "LEFT", 0, 0)
            line.bar:SetWidth(200)
            line.bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
            line.bar:SetStatusBarColor(unpack(ns.UI.ACCENT))
            ns.UI.Box(line.bar, { 0.04, 0.05, 0.05, 1 })
            line.barText = ns.UI.Text(line, 11, "LEFT", ns.UI.MUTED)
            line.barText:SetPoint("LEFT", line.bar, "RIGHT", 8, 0)
            row.criteria[c] = line
        end
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", row.desc, "BOTTOMLEFT", 0, -10 - y)
        line:SetWidth(width)
        local isBar = flags and EVALUATION_TREE_FLAG_PROGRESS_BAR and bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) ~= 0
            and (required or 0) > 0
        line.bar:SetShown(isBar and true or false)
        line.barText:SetShown(isBar and true or false)
        line.text:SetShown(not isBar)
        if isBar then
            line.bar:SetMinMaxValues(0, required)
            line.bar:SetValue(quantity or 0)
            line.barText:SetText((quantity or 0) .. " / " .. required)
        else
            line.text:SetText((done and ns.UI.IconMarkup("Check", 11, ns.UI.ACCENT, 1) .. " " or "•  ") .. (text or ""))
            line.text:SetTextColor(unpack(done and ns.UI.TEXT or ns.UI.MUTED))
        end
        line:Show()
        y = y + 22
    end
    return n > 0 and (y + 10) or 0
end

local function RefreshChallenges(page)
    local UI = ns.UI
    local max = C_Traits and C_Traits.GetMaxAvailableTraitCurrency and C_Traits.GetMaxAvailableTraitCurrency(CURRENCY, false) or 0
    page.total:SetText(L["Legacy points %d / %d"]:format(Points(), max))
    page.totalBar:SetValue(max > 0 and math.min(Points() / max, 1) or 0)

    -- categories
    if not selectedCategory then
        local _, class = UnitClass("player")
        local key = class and ("LEGACY_DEFAULT_CATEGORY_" .. class)
        selectedCategory = key and Constants.LegacyConsts and Constants.LegacyConsts[key]
    end
    local y = 0
    local rows = CategoryTree()
    for _, r in ipairs(page.catRows) do r:Hide() end
    for i, r in ipairs(rows) do
        local row = CategoryRow(page, i)
        local done, total = CategoryCount(r.entry.id)
        row.id, row.top, row.hasKids = r.entry.id, r.top, r.hasKids
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", r.top and 8 or 22, 0)
        row.text:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
        row.text:SetText(r.entry.name)
        row.text:SetTextColor(unpack(r.top and UI.ACCENT or UI.TEXT))
        row.count:SetText(total > 0 and (done .. "/" .. total) or "")
        row.sign:SetText(r.hasKids and (collapsed[r.entry.id] and "+" or "−") or "")
        row.sign:ClearAllPoints()
        row.sign:SetPoint("RIGHT", row.count, total > 0 and "LEFT" or "RIGHT", total > 0 and -6 or 0, 0)
        local sel = r.entry.id == selectedCategory
        row.sel:SetShown(sel)
        row.strip:SetShown(sel)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", page.cats.child, "RIGHT")
        row:Show()
        y = y + 25
    end
    page.cats:SetContentHeight(y)

    -- challenges of the selected category
    local list = selectedCategory and CategoryChallenges(selectedCategory) or {}
    for _, r in ipairs(page.listRows) do r:Hide() end
    local width = page.list:GetWidth()
    page.list.child:SetWidth(width)
    y = 0
    local T = Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
    for i, c in ipairs(list) do
        local row = ChallengeRow(page, i)
        row.challenge = c
        row.icon:SetTexture(c.icon)
        row.icon:SetDesaturated(not c.done)
        row.title:SetText(c.name)
        row.title:SetTextColor(unpack(c.done and UI.ACCENT or UI.TEXT))
        row.desc:SetText(c.description or "")
        row.shield:SetShown(c.points > 0)
        row.shield.text:SetText(c.points)
        row.date:SetText(c.done and c.day and FormatShortDate and FormatShortDate(c.day, c.month, c.year) or "")
        local tracking = T and C_ContentTracking and C_ContentTracking.IsTracking(T, c.id)
        row.track:SetShown(not c.done)
        row.track.tick:SetShown(tracking and true or false)
        for _, e in ipairs(row.edges) do e:SetVertexColor(unpack(expanded == c.id and UI.ACCENT or (c.done and { 0.18, 0.29, 0.25, 1 } or { 0.15, 0.18, 0.17, 1 }))) end
        row:SetWidth(width)
        local textH = row.title:GetStringHeight() + 4 + row.desc:GetStringHeight()
        local extra = 0
        if expanded == c.id then
            extra = FillCriteria(row, width - 90)
        else
            for _, line in ipairs(row.criteria) do line:Hide() end
        end
        local h = math.max(60, 14 + textH + extra + 12)
        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:Show()
        y = y + h + 6
    end
    page.list:SetContentHeight(y)
    page.empty:SetShown(#list == 0)
end

-- 3. Tree ---------------------------------------------------------------------------------------

local selectedTree = 1
local NODE = 48

-- Enough currency for the next rank? (otherwise the purchase fails with an "internal error")
local function CanAfford(configID, nodeID, treeID)
    local have = {}
    for _, c in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, false) or {}) do have[c.traitCurrencyID] = c.quantity end
    for _, cost in ipairs(C_Traits.GetNodeCost(configID, nodeID) or {}) do
        if (have[cost.ID] or 0) < cost.amount then return false end
    end
    return true
end

local function TreeCurrency(configID, treeID)
    local info = configID and C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    return info and info[1]
end

local function BuildTree(page)
    local UI = ns.UI
    page.selectors = {}
    for i, tree in ipairs(TREES) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(176, 62)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 70)
        UI.Box(b, { 0.078, 0.094, 0.094, 1 })
        b.edges = ns.AddBorder(b)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(46, 46)
        b.icon:SetPoint("LEFT", 8, 0)
        b.icon:SetAtlas(tree.atlas)
        b.name = UI.Text(b, 14, "LEFT")
        b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, -6)
        b.name:SetPoint("RIGHT", -6, 0)
        b.sub = UI.Text(b, 12, "LEFT", UI.MUTED)
        b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
        b:SetScript("OnClick", function()
            selectedTree = i
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Refresh()
        end)
        page.selectors[i] = b
    end
    page.board = CreateFrame("Frame", nil, page)
    page.board:SetPoint("TOPLEFT", 192, 0)
    page.board:SetPoint("BOTTOMRIGHT", 0, 44)
    UI.Box(page.board, { 0.078, 0.094, 0.094, 1 })
    ns.AddBorder(page.board)
    page.boardArt = page.board:CreateTexture(nil, "BACKGROUND", nil, 1)
    page.boardArt:SetAllPoints()
    page.boardArt:SetVertexColor(0.5, 0.5, 0.5)
    page.board:SetScript("OnSizeChanged", function() CoverAtlas(page.boardArt, "Legacy-Tree-Frame-background", BOARD_CROP) end)
    -- large tree icon on the left with spent points below (as in Blizzard's UI)
    page.bigIcon = page.board:CreateTexture(nil, "ARTWORK")
    page.bigIcon:SetSize(96, 96)
    page.bigIcon:SetPoint("LEFT", 36, 10)
    page.spent = CreateFrame("Frame", nil, page.board)
    page.spent:SetSize(40, 26)
    page.spent:SetPoint("TOP", page.bigIcon, "BOTTOM", 0, -8)
    UI.Box(page.spent, UI.FIELD)
    page.spent.edges = ns.AddBorder(page.spent)
    for _, e in ipairs(page.spent.edges) do e:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.8) end
    page.spent.text = UI.Text(page.spent, 15, "CENTER")
    page.spent.text:SetPoint("CENTER")
    page.spent.text:SetTextColor(unpack(GOLD))
    page.boardTitle = UI.Text(page.board, 16, "LEFT")
    page.boardTitle:SetPoint("TOPLEFT", 14, -12)
    page.boardPoints = UI.Text(page.board, 13, "RIGHT", UI.MUTED)
    page.boardPoints:SetPoint("TOPRIGHT", -14, -14)
    page.nodes, page.lines = {}, {}

    page.apply = UI.Button(page, TALENT_FRAME_APPLY_BUTTON_TEXT or L["Apply"], function()
        local configID = page.configID
        if not configID then return end
        if InCombatLockdown() then return UIErrorsFrame:AddMessage(L["Not possible in combat."], 1, 0.1, 0.1) end
        C_Traits.CommitConfig(configID)
    end, 140)
    page.apply:SetHeight(28)
    page.apply:SetPoint("BOTTOMRIGHT", 0, 6)
    page.undo = UI.Button(page, L["Undo"], function()
        if page.configID then C_Traits.RollbackConfig(page.configID) end
        Refresh()
    end, 120)
    page.undo:SetHeight(28)
    page.undo:SetPoint("RIGHT", page.apply, "LEFT", -8, 0)
    page.reset = UI.Button(page, L["Reset"], function()
        if page.configID then C_Traits.ResetTree(page.configID, TREES[selectedTree].id) end
        Refresh()
    end, 120)
    page.reset:SetHeight(28)
    page.reset:SetPoint("RIGHT", page.apply, "LEFT", -8, 0)
    -- width fits the text (24 px padding per side), at least 140
    for _, b in ipairs({ page.apply, page.undo, page.reset }) do
        b:SetWidth(math.max(140, math.ceil(b.Text:GetUnboundedStringWidth()) + 48))
    end
    page.hint = UI.Text(page, 12, "LEFT", UI.MUTED)
    page.hint:SetPoint("BOTTOMLEFT", page.board, "BOTTOMLEFT", 0, -26)
    page.hint:SetText(L["Click: add point · Right-click: remove"])

    for _, event in ipairs({ "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED",
        "CONFIG_COMMIT_FAILED", "TRAIT_TREE_CHANGED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" }) do
        pcall(page.RegisterEvent, page, event)
    end
    local pending
    page:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if window and window:IsShown() then Refresh() end
        end)
    end)
end

local function NodeName(configID, info)
    local entry = info.activeEntry or (info.entryIDs and info.entryIDs[1] and { entryID = info.entryIDs[1] })
    local e = entry and configID and C_Traits.GetEntryInfo(configID, entry.entryID)
    local def = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
    if not def then return "", 134400, entry end
    local name = def.overrideName or (def.spellID and C_Spell.GetSpellName(def.spellID)) or ""
    local icon = def.overrideIcon or (def.spellID and C_Spell.GetSpellTexture(def.spellID)) or 134400
    return name, icon, entry
end

local function NodeButton(page, i)
    if page.nodes[i] then return page.nodes[i] end
    local UI = ns.UI
    local b = CreateFrame("Button", nil, page.board)
    b:SetSize(NODE, NODE)
    b:SetFrameLevel(page.board:GetFrameLevel() + 3)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns.AddSlotBackground(b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edges = ns.AddBorder(b, true, 2)
    b.rank = CreateFrame("Frame", nil, b)
    b.rank:SetSize(30, 16)
    b.rank:SetPoint("BOTTOMRIGHT", 8, -6)
    b.rank:SetFrameLevel(b:GetFrameLevel() + 2)
    UI.Box(b.rank, { 0.03, 0.04, 0.04, 1 })
    b.rank.text = UI.Text(b.rank, 11, "CENTER")
    b.rank.text:SetPoint("CENTER")
    b:SetScript("OnClick", function(self, button)
        local configID, info = page.configID, self.info
        if not (configID and info) then return end
        if InCombatLockdown() then return UIErrorsFrame:AddMessage(L["Not possible in combat."], 1, 0.1, 0.1) end
        local ok = true
        if button == "RightButton" then
            if info.canRefundRank and (info.ranksPurchased or 0) > 0 then ok = C_Traits.RefundRank(configID, info.ID) end
        elseif info.canPurchaseRank and info.meetsEdgeRequirements then
            if not CanAfford(configID, info.ID, TREES[selectedTree].id) then
                return UIErrorsFrame:AddMessage(L["Not enough legacy points."], 1, 0.1, 0.1)
            end
            ok = C_Traits.PurchaseRank(configID, info.ID)
        end
        if ok == false then UIErrorsFrame:AddExternalErrorMessage(GENERIC_TRAIT_FRAME_INTERNAL_ERROR or "") end
        Refresh()
    end)
    b:SetScript("OnEnter", function(self)
        local info = self.info
        if not info then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.name or "", 1, 1, 1)
        GameTooltip:AddLine((TALENT_BUTTON_TOOLTIP_RANK_FORMAT or "%d/%d"):format(info.currentRank or 0, info.maxRanks or 0), 1, 1, 1)
        local entry = self.entry
        if entry and entry.entryID and GameTooltip.AppendInfo then
            GameTooltip:AppendInfo("GetTraitEntry", entry.entryID, math.max(entry.rank or 1, 1))
        end
        if info.nextEntry and (info.ranksPurchased or 0) > 0 and GameTooltip.AppendInfo then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(TALENT_BUTTON_TOOLTIP_NEXT_RANK or L["Next rank:"], 1, 1, 1)
            GameTooltip:AppendInfo("GetTraitEntry", info.nextEntry.entryID, info.nextEntry.rank)
        end
        if page.configID then
            GameTooltip:AddLine(" ")
            if info.canPurchaseRank then GameTooltip:AddLine(TALENT_BUTTON_TOOLTIP_PURCHASE_INSTRUCTIONS or "", 0.56, 0.8, 0.71) end
            if info.canRefundRank and (info.ranksPurchased or 0) > 0 then
                GameTooltip:AddLine(TALENT_BUTTON_TOOLTIP_REFUND_INSTRUCTIONS or "", 1, 0.4, 0.4)
            end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page.nodes[i] = b
    return b
end

local function RefreshTree(page)
    local UI = ns.UI
    local tree = TREES[selectedTree]
    local configID = C_Traits.GetConfigIDByTreeID(tree.id)
    page.configID = configID
    for i, b in ipairs(page.selectors) do
        local cur = TreeCurrency(C_Traits.GetConfigIDByTreeID(TREES[i].id), TREES[i].id)
        b.name:SetText(TREES[i].name())
        b.sub:SetText(L["%d points"]:format(cur and cur.spentInTree or 0))
        for _, e in ipairs(b.edges) do e:SetVertexColor(unpack(i == selectedTree and UI.ACCENT or { 0.15, 0.18, 0.17, 1 })) end
    end
    page.boardTitle:SetText(tree.name())
    page.bigIcon:SetAtlas(tree.atlas)
    local cur = TreeCurrency(configID, tree.id)
    page.spent.text:SetText(cur and cur.spentInTree or 0)
    page.boardPoints:SetText(L["%d available"]:format(cur and cur.quantity or 0))

    -- collect nodes and center them on the board
    local infos = {}
    local minX, minY, maxX, maxY
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(tree.id) or {}) do
        local info = configID and C_Traits.GetNodeInfo(configID, nodeID)
        if info and info.isVisible then
            infos[#infos + 1] = info
            local x, y = info.posX / 10, info.posY / 10
            minX, maxX = math.min(minX or x, x), math.max(maxX or x, x)
            minY, maxY = math.min(minY or y, y), math.max(maxY or y, y)
        end
    end
    for _, b in ipairs(page.nodes) do b:Hide() end
    for _, l in ipairs(page.lines) do l:Hide() end
    if #infos == 0 then
        page.apply:Disable()
        page.undo:Hide()
        page.reset:Hide()
        return
    end
    local bw, bh = page.board:GetWidth(), page.board:GetHeight()
    local left = 170 -- right of the large tree icon
    local scale = math.min(1.7, (bw - left - 90) / math.max(maxX - minX, 1), (bh - 130) / math.max(maxY - minY, 1))
    local ox = left + (bw - left - (maxX - minX) * scale) / 2
    local oy = (bh - (maxY - minY) * scale) / 2 + 14
    local pos = {}
    for i, info in ipairs(infos) do
        local b = NodeButton(page, i)
        local x = ox + (info.posX / 10 - minX) * scale
        local y = oy + (info.posY / 10 - minY) * scale
        b:ClearAllPoints()
        b:SetPoint("CENTER", page.board, "TOPLEFT", x, -y)
        pos[info.ID] = { x, y }
        b.info = info
        local name, icon, entry = NodeName(configID, info)
        b.name, b.entry = name, info.activeEntry or entry
        b.icon:SetTexture(icon)
        local maxed = (info.activeRank or 0) >= (info.maxRanks or 1)
        local selectable = info.canPurchaseRank and info.meetsEdgeRequirements and CanAfford(configID, info.ID, tree.id)
        local owned = (info.activeRank or 0) > 0
        b.icon:SetDesaturated(not (owned or selectable))
        b.icon:SetAlpha((owned or selectable) and 1 or 0.55)
        local edge = maxed and GOLD or (selectable and UI.ACCENT) or (owned and GOLD) or { 0.15, 0.18, 0.17, 1 }
        for _, e in ipairs(b.edges) do e:SetVertexColor(unpack(edge)) end
        b.rank.text:SetText((info.currentRank or 0) .. "/" .. (info.maxRanks or 0))
        b.rank.text:SetTextColor(unpack(maxed and GOLD or UI.TEXT))
        b:Show()
    end
    -- edges (lines between nodes)
    local n = 0
    for _, info in ipairs(infos) do
        for _, edgeInfo in ipairs(info.visibleEdges or {}) do
            local a, t = pos[info.ID], pos[edgeInfo.targetNode]
            if a and t then
                n = n + 1
                local line = page.lines[n]
                if not line then
                    line = page.board:CreateLine(nil, "ARTWORK")
                    line:SetThickness(3)
                    page.lines[n] = line
                end
                line:SetStartPoint("TOPLEFT", page.board, a[1], -a[2])
                line:SetEndPoint("TOPLEFT", page.board, t[1], -t[2])
                line:SetColorTexture(unpack(edgeInfo.isActive and UI.ACCENT or { 0.3, 0.33, 0.32, 1 }))
                line:Show()
            end
        end
    end
    -- Buttons: Apply only with staged changes; Undo replaces Reset while something is staged
    local staged = configID and C_Traits.ConfigHasStagedChanges(configID)
    if staged then page.apply:Enable() else page.apply:Disable() end
    page.undo:SetShown(staged and true or false)
    page.reset:SetShown(not staged)
    local anyBought = false
    for _, info in ipairs(infos) do if (info.ranksPurchased or 0) > 0 then anyBought = true break end end
    if anyBought then page.reset:Enable() else page.reset:Disable() end
end

-- Window ------------------------------------------------------------------------------------------

Refresh = function()
    if not window then return end
    local points = Points()
    window:SetNpc(nil, L["Legacy"], L["%d legacy points"]:format(points), "Interface/Icons/achievement_guildperk_honorablemention")
    for _, tab in ipairs(tabs) do
        for _, e in ipairs(tab.active) do e:SetShown(tab.key == current) end
        tab.icon:SetDesaturated(tab.key ~= current) -- inactive tabs desaturated (as everywhere)
    end
    for key, page in pairs(pages) do page:SetShown(key == current) end
    if current == "rewards" then RefreshRewards(pages.rewards)
    elseif current == "challenges" then RefreshChallenges(pages.challenges)
    else RefreshTree(pages.tree) end
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUILegacy", WIDTH, HEIGHT, "legacy")
    -- Positioned like all mUI windows (above the chat, else beside it), not centered, so it does not
    -- cover other windows
    window.extraRight = 46 -- tabs on the right (40 + 6): neighbor windows keep extra distance
    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        -- the client drops search results on every loading screen: re-run the search
        local text = pages.challenges and pages.challenges.search:GetText() or ""
        if text ~= "" then SetAchievementSearchString(text) end
        Refresh()
    end)
    window:HookScript("OnHide", function() PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)

    local top = ns.NPC_HEADER_BOTTOM + 18
    for key, build in pairs({ rewards = BuildRewards, challenges = BuildChallenges, tree = BuildTree }) do
        local page = CreateFrame("Frame", nil, window)
        page:SetPoint("TOPLEFT", PAD, -top)
        page:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        build(page)
        pages[key] = page
    end

    -- tabs outside on the right, as in all mUI windows (spellbook, professions, character)
    for i, t in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, window)
        tab:SetSize(40, 40)
        tab:SetPoint("TOPLEFT", window, "TOPRIGHT", ns.SideTabX(), -60 - (i - 1) * 46)
        UI.Box(tab, ns.STYLE.panelColor)
        tab.icon = tab:CreateTexture(nil, "ARTWORK")
        tab.icon:SetPoint("TOPLEFT", 2, -2)
        tab.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tab.icon:SetTexture(t.icon)
        tab.active = ns.AddBorder(tab, true, 2)
        for _, e in ipairs(tab.active) do e:SetVertexColor(unpack(UI.ACCENT)) end
        tab.key = t.key
        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[t.label], 1, 1, 1)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
        tab:SetScript("OnClick", function()
            current = t.key
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            Refresh()
        end)
        tabs[i] = tab
    end
end

-- Open only once unlocked, like Blizzard's; force = preview via /mui legacy
local function Toggle(force)
    if window and window:IsShown() then window:Hide() return end
    if not force and not Unlocked() then
        UIErrorsFrame:AddMessage(LEGACY_MICRO_BUTTON_LOCKED_TOOLTIP or L["Not available yet"], 1, 0.1, 0.1)
        return
    end
    if not window then CreateWindow() end
    window:Show()
end
ns.ToggleLegacy = Toggle

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    -- key binding (TOGGLELEGACYSYSTEM) and micro button open this window
    local toggle = CreateFrame("Button", "MeredanUILegacyToggle", UIParent)
    toggle:SetScript("OnClick", function() Toggle() end)
    local function BindKeys()
        if InCombatLockdown() then return ns.AfterCombat(BindKeys) end
        ClearOverrideBindings(toggle)
        for _, key in ipairs({ GetBindingKey("TOGGLELEGACYSYSTEM") }) do
            SetOverrideBindingClick(toggle, false, key, "MeredanUILegacyToggle", "LeftButton")
        end
    end
    BindKeys()
    ns:On("UPDATE_BINDINGS", BindKeys)
    if LegacyMicroButton then LegacyMicroButton:SetScript("OnClick", function() Toggle() end) end
end)
