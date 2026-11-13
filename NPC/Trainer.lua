-- Trainer window (WoW Forever): replaces Blizzard's trainer frame for class, profession and pet
-- trainers - skill bar, filter, searchable list, detail panel with banner art.
-- Data comes from GetTrainerService*; all actions need the service index, which changes after every
-- TRAINER_UPDATE - so selection is tracked by name. Blizzard's frame is parked after it opens and
-- reparented on close (like the guild bank): Forever sometimes checks IsVisible on open, and its
-- OnHide would close the trainer.
local _, ns = ...
local L = ns.L

local WIDTH, PAD = 820, 18
local LIST_W = 380
local ROW_H, ROW_GAP, HEADER_H = 48, 4, 26
local BANNER_H = 110
local SKILL_BLUE = { 0.15, 0.45, 1 }

-- Localized profession name -> key for Blizzard's profession art atlases
local PROFESSIONS = {
    cooking = { "Cooking", "Kochkunst", "Kochen" }, firstaid = { "First Aid", "Erste Hilfe" },
    fishing = { "Fishing", "Angeln" }, blacksmithing = { "Blacksmithing", "Schmiedekunst" },
    leatherworking = { "Leatherworking", "Lederverarbeitung" }, tailoring = { "Tailoring", "Schneiderei" },
    alchemy = { "Alchemy", "Alchemie" }, enchanting = { "Enchanting", "Verzauberkunst" },
    engineering = { "Engineering", "Ingenieurskunst" }, mining = { "Mining", "Bergbau" },
    herbalism = { "Herbalism", "Kräuterkunde" }, skinning = { "Skinning", "Kürschnerei" },
}
local RANK_NAMES = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, searchBox, skillLabel, skillBar, skillRank, filterButton
local detail, footerText, gold, emptyText
local rows, headers = {}, {}
local collapsed = {}
local selectedName
local learnAll = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.trainerWindow ~= false
end

local function IsPetTrainer() return C_Trainer and C_Trainer.GetTrainerType() == Enum.TrainerType.Pet end

local function ProfessionKey(name)
    if not name then return end
    for key, names in pairs(PROFESSIONS) do
        for _, n in ipairs(names) do
            if n == name then return key end
        end
    end
end

local function AtlasExists(name) return name and C_Texture.GetAtlasInfo(name) ~= nil end

-- Banner atlas: profession art, else class background
local function BannerAtlas(skillLine)
    local key = ProfessionKey(skillLine)
    if key then
        for _, pattern in ipairs({ "profession-overview-card-%s-c60", "Profession-overview-Card-%s",
            "profession-overview-card-generic-%s-c60", "professions-recipe-background-%s" }) do
            local name = pattern:format(key)
            if AtlasExists(name) then return name end
        end
    end
    local _, class = UnitClass("player") -- class and pet trainers: own class
    local classAtlas = class and ("dressingroom-background-" .. class:lower())
    if AtlasExists(classAtlas) then return classAtlas end
end

ns.ProfessionBannerAtlas = BannerAtlas -- shared with the professions window
ns.PROFESSION_RANK_NAMES = RANK_NAMES

-- Data -------------------------------------------------------------------------------------------

local function Requirements(index, reqLevel)
    local parts = {}
    local unit = IsPetTrainer() and "pet" or "player"
    if reqLevel and reqLevel > 1 then
        local ok = UnitLevel(unit) >= reqLevel
        parts[#parts + 1] = ((ok and TRAINER_REQ_LEVEL or TRAINER_REQ_LEVEL_RED) or "%d"):format(reqLevel)
    end
    local skill, rank, hasSkill = GetTrainerServiceSkillReq(index)
    if skill then
        parts[#parts + 1] = ((hasSkill and TRAINER_REQ_SKILL_RANK or TRAINER_REQ_SKILL_RANK_RED) or "%s (%d)"):format(skill, rank)
    end
    for i = 1, (GetTrainerServiceNumAbilityReq(index) or 0) do
        local ability, has = GetTrainerServiceAbilityReq(index, i)
        if ability then parts[#parts + 1] = ((has and TRAINER_REQ_ABILITY or TRAINER_REQ_ABILITY_RED) or "%s"):format(ability) end
    end
    return table.concat(parts, ", "), skill, rank, hasSkill
end

local function Entries(query)
    local stepIndex = GetTrainerServiceStepIndex and GetTrainerServiceStepIndex()
    local unit = IsPetTrainer() and "pet" or "player"
    local step, groups, order, learnable, total = nil, {}, {}, 0, 0
    for index = 1, GetNumTrainerServices() do
        local name, serviceType, texture, reqLevel, subText, category = GetTrainerServiceInfo(index)
        if name and (query == "" or name:lower():find(query, 1, true)) then
            local req, skill, rank, hasSkill = Requirements(index, reqLevel)
            local cost, isProfession = GetTrainerServiceCost(index)
            local entry = {
                index = index, name = name, kind = serviceType, texture = texture, subText = subText,
                key = name .. "\1" .. (subText or "") .. "\1" .. (reqLevel or 0), -- ranks share the same name
                req = req, cost = cost or 0, isProfession = isProfession, reqLevel = reqLevel,
            }
            -- Grey line: "Cooking (50)" with green/red rank, else level, else "known"
            if serviceType == "used" then
                entry.line = ITEM_SPELL_KNOWN or "Known"
            elseif skill then
                entry.line = skill .. " " .. (hasSkill and "|cff33ff33" or "|cffff5050") .. "(" .. rank .. ")|r"
            elseif reqLevel and reqLevel > 1 then
                local ok = UnitLevel(unit) >= reqLevel
                entry.line = (ok and "|cff33ff33" or "|cffff5050") .. L["Level %d"]:format(reqLevel) .. "|r"
            else
                entry.line = subText and subText ~= "" and subText or ""
            end
            total = total + 1
            if serviceType == "available" then learnable = learnable + 1 end
            if index == stepIndex then
                step = entry
            else
                local group = (not IsPetTrainer() and category and category ~= "") and category or ""
                if not groups[group] then
                    groups[group] = {}
                    order[#order + 1] = group
                end
                table.insert(groups[group], entry)
            end
        end
    end
    table.sort(order)
    return step, groups, order, learnable, total
end

-- Rows -------------------------------------------------------------------------------------------

local function Select(entry)
    selectedName = entry and entry.key
    if entry then SelectTrainerService(entry.index) end
end

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(ROW_H)
    row.bg = UI.Card(row)
    row.strip = row:CreateTexture(nil, "OVERLAY")
    row.strip:SetColorTexture(unpack(UI.ACCENT))
    row.strip:SetPoint("TOPLEFT")
    row.strip:SetPoint("BOTTOMLEFT")
    row.strip:SetWidth(2)
    local holder = CreateFrame("Frame", nil, row)
    holder:SetSize(34, 34)
    holder:SetPoint("LEFT", 8, 0)
    ns.AddSlotBackground(holder)
    ns.AddItemFrame(holder, nil, 2)
    row.icon = holder:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(holder, row.icon, nil, 2)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.cost = UI.Text(row, 12, "RIGHT")
    row.cost:SetPoint("RIGHT", -10, 0)
    row.name = UI.Text(row, 13, "LEFT")
    row.name:SetPoint("TOPLEFT", holder, "TOPRIGHT", 10, -2)
    row.name:SetPoint("RIGHT", row.cost, "LEFT", -8, 0)
    row.line = UI.Text(row, 11, "LEFT", UI.MUTED)
    row.line:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", 10, 2)
    row.line:SetPoint("RIGHT", row.cost, "LEFT", -8, 0)
    row:SetScript("OnEnter", function(self)
        if not self.selected then self.bg:SetColorTexture(0.133, 0.133, 0.149, 1) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetTrainerService(self.entry.index)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if not self.selected then self.bg:SetColorTexture(0.098, 0.098, 0.106, 1) end
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self)
        local link = GetTrainerServiceItemLink and GetTrainerServiceItemLink(self.entry.index)
        if link and HandleModifiedItemClick(link) then return end
        Select(self.entry)
        window.Layout()
    end)
    rows[i] = row
    return row
end

local function CostText(cost)
    if not cost or cost <= 0 then return "" end
    if IsPetTrainer() then return L["%d TP"]:format(cost) end
    return GetMoneyString(cost, true)
end

local function FillRow(row, entry)
    row.entry = entry
    row.icon:SetTexture(entry.texture)
    local available = entry.kind == "available"
    row.icon:SetDesaturated(not available)
    row.icon:SetAlpha(available and 1 or 0.5)
    row.name:SetText(entry.name)
    row.name:SetTextColor(unpack(available and ns.UI.TEXT or { 0.48, 0.47, 0.45 }))
    row.line:SetText(entry.line)
    row.cost:SetText(entry.kind ~= "used" and CostText(entry.cost) or "")
    if not IsPetTrainer() and entry.cost > GetMoney() then row.cost:SetTextColor(1, 0.3, 0.3) else row.cost:SetTextColor(unpack(ns.UI.TEXT)) end
    row.selected = entry.key == selectedName
    row.strip:SetShown(row.selected)
    row.bg:SetColorTexture(unpack(row.selected and { 0.133, 0.133, 0.149, 1 } or { 0.098, 0.098, 0.106, 1 }))
end

local function Header(i)
    if headers[i] then return headers[i] end
    local UI = ns.UI
    local header = CreateFrame("Button", nil, list.child)
    header:SetHeight(HEADER_H)
    header.text = UI.Heading(header, 12, "LEFT")
    header.text:SetPoint("LEFT", 8, 0)
    header.sign = UI.Icon(header, "Minus", 12, UI.MUTED)
    header.sign:SetPoint("RIGHT", -8, 0)
    header:SetScript("OnClick", function(self)
        if not self.key then return end
        collapsed[self.key] = not collapsed[self.key]
        window.Layout()
    end)
    headers[i] = header
    return header
end

-- Details ----------------------------------------------------------------------------------------

local function TooltipBody(index)
    local data = C_TooltipInfo and C_TooltipInfo.GetTrainerService and C_TooltipInfo.GetTrainerService(index)
    if not (data and data.lines) then return "" end
    local out = {}
    for n = 2, #data.lines do -- line 1 is the name
        local line = data.lines[n]
        local text = line.leftText
        if text and not (issecretvalue and issecretvalue(text)) and text ~= "" then
            local color = line.leftColor
            out[#out + 1] = color and color.WrapTextInColorCode and color:WrapTextInColorCode(text) or text
        end
    end
    return table.concat(out, "\n")
end

local function UpdateDetail(entry)
    detail:SetShown(entry ~= nil)
    if not entry then return end
    detail.icon:SetTexture(entry.texture)
    detail.name:SetText(entry.name)
    detail.sub:SetText(entry.subText and entry.subText ~= "" and entry.subText or "")
    detail.req:SetText(entry.req ~= "" and ((REQUIRES_LABEL or "Requires:") .. " " .. entry.req) or "")
    detail.body:SetText(TooltipBody(entry.index))
    detail.cost:SetText(entry.kind ~= "used" and entry.cost > 0 and ((COSTS_LABEL or "Cost:") .. " " .. CostText(entry.cost)) or "")
    local canLearn = entry.kind == "available" and (IsPetTrainer() or entry.cost <= GetMoney())
    detail.learn:SetEnabled(canLearn)
    detail.learn.Text:SetTextColor(unpack(canLearn and ns.UI.ACCENT or ns.UI.MUTED))
    for _, edge in ipairs(detail.learn.edges) do edge:SetShown(canLearn) end
end

local function Learn(entry)
    if not entry or entry.kind ~= "available" then return end
    if IsTradeskillTrainer() and entry.isProfession then
        StaticPopup_Show("MEREDANUI_CONFIRM_PROFESSION", GetTrainerServiceSkillLine(entry.index), nil, entry.index)
        return
    end
    BuyTrainerService(entry.index)
end

-- "All learnable": one at a time - indices change after each purchase (TRAINER_UPDATE)
local function LearnNext()
    if not learnAll then return end
    for index = 1, GetNumTrainerServices() do
        local _, kind = GetTrainerServiceInfo(index)
        local cost, isProfession = GetTrainerServiceCost(index)
        if kind == "available" and not isProfession and (IsPetTrainer() or (cost or 0) <= GetMoney()) then
            BuyTrainerService(index)
            return
        end
    end
    learnAll = false
end

-- Build -------------------------------------------------------------------------------------------

local function UpdateBanner(skillLine)
    local atlas = BannerAtlas(skillLine)
    detail.banner.art:SetShown(atlas ~= nil)
    if not atlas then return end
    local info = C_Texture.GetAtlasInfo(atlas)
    detail.banner.art:SetAtlas(atlas)
    -- Cover-fit, centered (the banner clips)
    local w, h = detail.banner:GetWidth(), BANNER_H
    local ratio = info.height / info.width
    if w * ratio >= h then
        detail.banner.art:SetSize(w, w * ratio)
    else
        detail.banner.art:SetSize(h / ratio, h)
    end
end

local function Layout()
    if not (window and window:IsShown()) then return end

    local step, groups, order, learnable, total = Entries(searchBox:GetText():lower())

    -- Profession: rank bar; pet trainer: training points
    local rank, maxRank = GetTrainerTradeskillRankValues()
    local skillLine = step and GetTrainerServiceSkillLine(step.index)
        or (GetNumTrainerServices() > 0 and GetTrainerServiceSkillLine(1)) or nil
    if rank and rank > 0 then
        skillLabel:SetText(skillLine or "")
        skillBar:SetMinMaxValues(0, maxRank)
        skillBar:SetValue(rank)
        skillBar.text:SetText(rank .. " / " .. maxRank)
        skillRank:SetText(RANK_NAMES[maxRank] and L[RANK_NAMES[maxRank]] or "")
        skillBar:Show()
    elseif IsPetTrainer() and C_PetInfo and C_PetInfo.GetPetTrainingPoints then
        local points, used = C_PetInfo.GetPetTrainingPoints()
        skillLabel:SetText(L["Training points"])
        skillRank:SetText(L["%d free"]:format((points or 0) - (used or 0)))
        skillBar:Hide()
    else
        skillLabel:SetText("")
        skillRank:SetText("")
        skillBar:Hide()
    end
    window.npcTitle:SetText(window.tooltipTitle and window.tooltipTitle ~= "" and window.tooltipTitle
        or (skillLine and IsTradeskillTrainer() and skillLine or (IsPetTrainer() and L["Pet trainer"] or L["Class trainer"])))

    -- List: rank step on top, then groups (categories alphabetical; uncategorized without header)
    local y, r, h = 0, 0, 0
    local all = {}
    local function AddHeader(text, key)
        h = h + 1
        local header = Header(h)
        header.key = key
        header.text:SetText(text)
        header.sign:SetShown(key ~= nil)
        ns.SetIcon(header.sign, (key and collapsed[key] and "Plus" or "Minus"))
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", 0, -y)
        header:SetPoint("RIGHT", list.child, "RIGHT")
        header:Show()
        y = y + HEADER_H
    end
    local function AddRow(entry)
        r = r + 1
        local row = Row(r)
        FillRow(row, entry)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", list.child, "RIGHT")
        row:Show()
        y = y + ROW_H + ROW_GAP
        all[#all + 1] = entry
    end
    if step then
        AddHeader(L["Rank"])
        AddRow(step)
    end
    for _, group in ipairs(order) do
        if group ~= "" then AddHeader(group, group) end
        if group == "" or not collapsed[group] then
            for _, entry in ipairs(groups[group]) do AddRow(entry) end
        end
    end
    for i = r + 1, #rows do rows[i]:Hide() end
    for i = h + 1, #headers do headers[i]:Hide() end
    list:SetContentHeight(y)
    emptyText:SetShown(r == 0)

    -- Keep selection (name + rank); else first learnable, else first
    local selected
    for _, entry in ipairs(all) do
        if entry.key == selectedName then selected = entry end
    end
    if not selected then
        for _, entry in ipairs(all) do
            if not selected and entry.kind == "available" then selected = entry end
        end
        selected = selected or all[1]
        if selected then
            Select(selected)
            for i = 1, r do FillRow(rows[i], rows[i].entry) end
        end
    end
    UpdateBanner(skillLine)
    UpdateDetail(selected)
    detail.learnAll:SetShown(learnable > 1)
    detail.learnAll.Text:SetText(L["All learnable (%d)"]:format(learnable))
    footerText:SetText(L["%d of %d learnable"]:format(learnable, total))
    gold:SetText(IsPetTrainer() and "" or GetMoneyString(GetMoney(), true))
    window.selected = selected
end

local pending
local function Refresh()
    if not (window and window:IsShown()) or pending then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        Layout()
    end)
end

-- Filter: Blizzard's service type filter (available / unavailable / used)
local FILTERS = {
    { value = "available", label = "Learnable only", set = { available = true, unavailable = false, used = false } },
    { value = "both", label = "Learnable and not yet", set = { available = true, unavailable = true, used = false } },
    { value = "all", label = "All, also known", set = { available = true, unavailable = true, used = true } },
}

local function CurrentFilter()
    local a, u, k = GetTrainerServiceTypeFilter("available"), GetTrainerServiceTypeFilter("unavailable"),
        GetTrainerServiceTypeFilter("used")
    if a and u and k then return FILTERS[3] end
    if a and u then return FILTERS[2] end
    return FILTERS[1]
end

local function CreateWindow()
    local UI = ns.UI
    -- Shared NPC header (NPC/NpcWindow.lua): portrait, name, title, close, draggable
    window = ns.CreateNpcWindow("MeredanUITrainer", WIDTH, ns.NPC_HEIGHT, "trainer")
    ns.WatchBlizzardFrame(window, function() return ClassTrainerFrame end)
    window.Layout = Layout

    -- Profession / progress / filter
    skillLabel = UI.Text(window, 13, "LEFT")
    skillLabel:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 22)
    skillBar = CreateFrame("StatusBar", nil, window)
    skillBar:SetSize(220, 16)
    skillBar:SetPoint("LEFT", skillLabel, "RIGHT", 12, 0)
    skillBar:SetStatusBarTexture(ns.MEDIA .. "BarShade")
    skillBar:SetStatusBarColor(unpack(SKILL_BLUE))
    ns.UI.Groove(skillBar)
    skillBar.text = UI.Text(skillBar, 11, "CENTER")
    skillBar.text:SetPoint("CENTER")
    skillRank = UI.Text(window, 12, "LEFT", UI.MUTED)
    skillRank:SetPoint("LEFT", skillBar, "RIGHT", 10, 0)
    filterButton = UI.Button(window, "", function(self)
        UI.OpenList(self, (function()
            local items = {}
            for _, f in ipairs(FILTERS) do items[#items + 1] = { value = f.value, label = L[f.label] } end
            return items
        end)(), CurrentFilter().value, function(value)
            for _, f in ipairs(FILTERS) do
                if f.value == value then
                    for kind, on in pairs(f.set) do SetTrainerServiceTypeFilter(kind, on) end
                end
            end
            filterButton.Text:SetText(L[CurrentFilter().label])
        end)
    end, 170)
    filterButton:SetHeight(28)
    filterButton:SetPoint("TOPRIGHT", -PAD, -ns.NPC_HEADER_BOTTOM - 15)

    -- Left: search and list
    searchBox = UI.EditBox(window, 30)
    searchBox:SetPoint("TOPLEFT", PAD, -ns.NPC_HEADER_BOTTOM - 56)
    searchBox:SetWidth(LIST_W)
    local hint = UI.Text(searchBox, 13, "LEFT", UI.MUTED)
    hint:SetPoint("LEFT", 10, 0)
    hint:SetText(L["Search"])
    searchBox:HookScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        Layout()
    end)
    list = UI.ScrollArea(window)
    list:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -10)
    list:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", PAD, 50)
    list:SetWidth(LIST_W - 10)
    emptyText = UI.Text(window, 13, "CENTER", UI.MUTED)
    emptyText:SetPoint("TOP", list, "TOP", 0, -40)
    emptyText:SetText(L["Nothing to learn here."])

    -- Right: details
    detail = CreateFrame("Frame", nil, window)
    detail:SetPoint("TOPLEFT", searchBox, "TOPRIGHT", 14, 0)
    detail:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 50)
    UI.Inset(detail)
    detail.banner = CreateFrame("Frame", nil, detail)
    detail.banner:SetPoint("TOPLEFT")
    detail.banner:SetPoint("TOPRIGHT")
    detail.banner:SetHeight(BANNER_H)
    detail.banner:SetClipsChildren(true)
    detail.banner.art = detail.banner:CreateTexture(nil, "ARTWORK")
    detail.banner.art:SetPoint("CENTER")
    detail.banner.art:SetVertexColor(0.55, 0.55, 0.55) -- dimmed art
    local fade = detail.banner:CreateTexture(nil, "OVERLAY")
    fade:SetPoint("BOTTOMLEFT")
    fade:SetPoint("BOTTOMRIGHT")
    fade:SetHeight(40)
    fade:SetColorTexture(1, 1, 1, 1)
    fade:SetGradient("VERTICAL", CreateColor(0.078, 0.078, 0.086, 1), CreateColor(0.078, 0.078, 0.086, 0))
    local iconHolder = CreateFrame("Frame", nil, detail)
    iconHolder:SetSize(56, 56)
    iconHolder:SetPoint("TOPLEFT", detail.banner, "BOTTOMLEFT", 16, 28)
    iconHolder:SetFrameLevel(detail.banner:GetFrameLevel() + 5)
    ns.AddSlotBackground(iconHolder)
    ns.AddItemFrame(iconHolder, nil, 2)
    detail.icon = iconHolder:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(iconHolder, detail.icon, nil, 2)
    detail.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    detail.name = UI.Text(detail, 17, "LEFT")
    detail.name:SetPoint("TOPLEFT", iconHolder, "BOTTOMLEFT", 0, -10)
    detail.name:SetPoint("RIGHT", -16, 0)
    detail.sub = UI.Text(detail, 12, "LEFT", UI.MUTED)
    detail.sub:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -4)
    detail.req = UI.Text(detail, 12, "LEFT", UI.MUTED)
    detail.req:SetPoint("TOPLEFT", detail.sub, "BOTTOMLEFT", 0, -8)
    detail.req:SetPoint("RIGHT", -16, 0)
    detail.req:SetWordWrap(true)
    detail.body = UI.Text(detail, 12, "LEFT", { 0.79, 0.78, 0.75 })
    detail.body:SetPoint("TOPLEFT", detail.req, "BOTTOMLEFT", 0, -10)
    detail.body:SetPoint("RIGHT", -16, 0)
    detail.body:SetPoint("BOTTOM", detail, "BOTTOM", 0, 52)
    detail.body:SetWordWrap(true)
    detail.body:SetJustifyV("TOP")
    detail.body:SetSpacing(3)
    detail.learn = UI.Button(detail, TRAIN or "Train", function() Learn(window.selected) end, 110)
    detail.learn:SetHeight(30)
    detail.learn:SetPoint("BOTTOMRIGHT", -14, 14)
    detail.learn.edges = {} -- bevel button: accent text only
    detail.learnAll = UI.Button(detail, "", function()
        learnAll = true
        LearnNext()
    end, 150)
    detail.learnAll:SetHeight(30)
    detail.learnAll:SetPoint("RIGHT", detail.learn, "LEFT", -8, 0)
    detail.cost = UI.Text(detail, 13, "LEFT")
    detail.cost:SetPoint("LEFT", detail, "BOTTOMLEFT", 16, 29)

    -- Footer
    footerText = UI.Text(window, 12, "LEFT", UI.MUTED)
    footerText:SetPoint("BOTTOMLEFT", PAD, 20)
    gold = UI.Text(window, 13, "RIGHT")
    gold:SetPoint("BOTTOMRIGHT", -PAD, 20)

    window:HookScript("OnShow", function()
        selectedName = nil
        learnAll = false
        filterButton.Text:SetText(L[CurrentFilter().label])
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        list:ScrollToTop()
        Layout()
    end)
    window:HookScript("OnHide", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
        learnAll = false
        StaticPopup_Hide("MEREDANUI_CONFIRM_PROFESSION")
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        -- Only end our own, still running interaction (otherwise it would hit the next NPC)
        if ns.StillInteracting("Trainer", ClassTrainerFrame) then CloseTrainer() end
    end)
end

StaticPopupDialogs["MEREDANUI_CONFIRM_PROFESSION"] = {
    text = PROFESSION_CONFIRMATION1 or "Learn %s?",
    button1 = ACCEPT, button2 = CANCEL,
    OnAccept = function(_, index) if index then BuyTrainerService(index) end end,
    showAlert = 1, timeout = 0, hideOnEscape = 1,
}

-- Park Blizzard's frame only once it is open (else Forever closes it right away), with OnHide removed;
-- on close reparent to UIParent (hidden by then, so no OnShow)
local function Park()
    local frame = ClassTrainerFrame
    if not frame or frame:GetParent() == hidden then return end
    frame:SetScript("OnHide", nil)
    frame:SetParent(hidden)
end

local function Unpark()
    local frame = ClassTrainerFrame
    if not frame or frame:GetParent() ~= hidden then return end
    if frame:IsShown() then return C_Timer.After(0, Unpark) end
    frame:SetParent(UIParent)
end

local function Open(retried)
    if not (ClassTrainerFrame and ClassTrainerFrame:IsShown()) then
        if not retried then C_Timer.After(0, function() Open(true) end) end
        return
    end
    Park()
    window.tooltipTitle = ns.NpcTitle("npc")
    window:SetNpc("npc", nil, window.tooltipTitle)
    window:Show()
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    CreateWindow()
    ns:On("TRAINER_SHOW", function() C_Timer.After(0, function() Open(false) end) end)
    ns:On("TRAINER_CLOSED", function()
        window:Hide()
        Unpark()
    end)
    ns:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, kind)
        if kind == Enum.PlayerInteractionType.Trainer then
            window:Hide()
            Unpark()
        end
    end)
    for _, event in ipairs({ "TRAINER_DESCRIPTION_UPDATE", "TRAINER_SERVICE_INFO_NAME_UPDATE", "PLAYER_MONEY",
        "UNIT_PET_TRAINING_POINTS", "SKILL_LINES_CHANGED" }) do
        ns:On(event, Refresh)
    end
    ns:On("TRAINER_UPDATE", function()
        Refresh()
        if learnAll then C_Timer.After(0.2, LearnNext) end
    end)
end)
