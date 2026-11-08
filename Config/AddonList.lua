-- Addon list (WoW Forever) as a mUI window replacing Blizzard's AddonList.
-- Centered like Blizzard's, same window family as Friends/Merchant:
--
--   +-[i] Addons --------------------------------------------- [x]-+
--   |     24 of 31 loaded                                          |
--   | [Search...                         ] [This character    v]   |
--   | - User Interface                                       3 / 4 |  <- category (collapsible)
--   | [x] [i] MeredanUI                      Reload    v0.3.0      |
--   | [x] [i]   MeredanUI_Options                      v0.3.0      |  <- group child
--   | [ ] [i] Details!                                 v12.1       |  <- disabled = grey
--   | [All on] [All off]  [ ] Load out of date       [ Reload ]    |
--   +--------------------------------------------------------------+
--
-- As in Blizzard's list, clicking a row toggles the addon for the selected character (or all);
-- takes effect after a reload. Changes are saved immediately (no "Cancel").
-- Blizzard's frame stays parked; opening it (Game Menu > AddOns) opens ours instead.
local ADDON_NAME, ns = ...
local L = ns.L

local WIDTH, PAD, ROW_H, HEAD_H = 600, 18, 30, 26
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, searchBox, searchHint, charButton, forceCheck, reloadButton, reloadEdges, emptyText
local rows = {}
local startEnabled, startVersionCheck = {}, nil
local allCharacters = false -- Blizzard's default: this character

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.addonListWindow ~= false
end

local function Character()
    if allCharacters then return nil end
    return UnitGUID("player")
end

local function IsEnabled(index, character)
    return C_AddOns.GetAddOnEnableState(index, character) > Enum.AddOnEnableState.None
end

-- Title without color/texture codes (search, sorting, grey display)
local function Plain(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("^%s+", "")
end

-- State at login; changes against it require a reload
local function Snapshot()
    local character = UnitGUID("player")
    for i = 1, C_AddOns.GetNumAddOns() do startEnabled[i] = IsEnabled(i, character) end
    startVersionCheck = C_AddOns.IsAddonVersionCheckEnabled()
end

local function NeedsReload(index)
    local reason = select(5, C_AddOns.GetAddOnInfo(index))
    return IsEnabled(index, UnitGUID("player")) ~= startEnabled[index] and reason ~= "DEP_DISABLED"
end

local function AnyChanged()
    if C_AddOns.IsAddonVersionCheckEnabled() ~= startVersionCheck then return true end
    for i = 1, C_AddOns.GetNumAddOns() do
        if NeedsReload(i) then return true end
    end
    return false
end

-- Order like Blizzard: categories first (TOC "## Category", alphabetical, collapsible),
-- then addons without category. Within: group parents alphabetical, their children indented
-- (Blizzard's "Group"). While searching all categories are expanded.
local function Collapsed()
    ns.db.addonListCollapsed = ns.db.addonListCollapsed or {}
    return ns.db.addonListCollapsed
end

local function Entries(filter)
    local parents, children = {}, {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, title, _, _, _, security = C_AddOns.GetAddOnInfo(i)
        if security ~= "SECURE" then
            local group = C_AddOns.GetAddOnMetadata(i, "Group") or name
            local entry = { index = i, name = name, title = title or name, plain = Plain(title or name):lower() }
            if group == name then
                parents[#parents + 1] = entry
                entry.group = name
            else
                children[group] = children[group] or {}
                table.insert(children[group], entry)
            end
        end
    end
    local byName = {}
    for _, entry in ipairs(parents) do byName[entry.name] = true end
    -- Children whose parent is missing: sort in normally
    for group, kids in pairs(children) do
        if not byName[group] then
            for _, kid in ipairs(kids) do parents[#parents + 1] = kid end
            children[group] = nil
        end
    end
    local function ByTitle(a, b) return a.plain < b.plain end
    table.sort(parents, ByTitle)

    -- Category applies to the whole group (parent's category, like Blizzard)
    local categories, order, loose = {}, {}, {}
    for _, entry in ipairs(parents) do
        local category = C_AddOns.GetAddOnMetadata(entry.index, "Category")
        if category and category ~= "" then
            if not categories[category] then
                categories[category] = {}
                order[#order + 1] = category
            end
            table.insert(categories[category], entry)
        else
            loose[#loose + 1] = entry
        end
    end
    table.sort(order, function(a, b)
        if strcmputf8i then return strcmputf8i(a, b) < 0 end
        return a:lower() < b:lower()
    end)

    -- Append group (parent + matching children) to out; returns the entries
    local function Group(entry, categoryMatch)
        local kids = entry.group and children[entry.group] or {}
        table.sort(kids, ByTitle)
        local match = categoryMatch or filter == "" or entry.plain:find(filter, 1, true)
        local block = {}
        for _, kid in ipairs(kids) do
            if match or kid.plain:find(filter, 1, true) then
                kid.child = true
                block[#block + 1] = kid
            end
        end
        if match or #block > 0 then table.insert(block, 1, entry) return block end
        return {}
    end

    local result = {}
    local collapsed = Collapsed()
    for _, category in ipairs(order) do
        local categoryMatch = filter ~= "" and category:lower():find(filter, 1, true) ~= nil
        local items = {}
        for _, entry in ipairs(categories[category]) do
            for _, item in ipairs(Group(entry, categoryMatch)) do items[#items + 1] = item end
        end
        if #items > 0 then
            local shut = filter == "" and collapsed[category]
            result[#result + 1] = { header = true, category = category, items = categories[category], collapsed = shut }
            if not shut then
                for _, item in ipairs(items) do result[#result + 1] = item end
            end
        end
    end
    for _, entry in ipairs(loose) do
        for _, item in ipairs(Group(entry)) do result[#result + 1] = item end
    end
    return result
end

local function ShowTooltip(row)
    local index = row.index
    if not index then return end
    local name, title, notes = C_AddOns.GetAddOnInfo(index)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddDoubleLine(title or name, C_AddOns.GetAddOnMetadata(index, "Version") or "", 1, 1, 1, 0.6, 0.6, 0.6)
    if notes and notes ~= "" then GameTooltip:AddLine(notes, 0.91, 0.9, 0.87, true) end
    local deps = { C_AddOns.GetAddOnDependencies(index) }
    if #deps > 0 then
        GameTooltip:AddLine((ADDON_DEPENDENCIES or "") .. table.concat(deps, ", "), 1, 0.82, 0, true)
    end
    local author = C_AddOns.GetAddOnMetadata(index, "Author")
    if author and author ~= "" then GameTooltip:AddLine(author, 0.6, 0.6, 0.6) end
    if C_AddOns.IsAddOnLoaded(index) and GetAddOnMemoryUsage then
        if UpdateAddOnMemoryUsage and (not window.memoryAt or GetTime() - window.memoryAt > 15) then
            window.memoryAt = GetTime() -- expensive: at most every 15 s (like Blizzard)
            UpdateAddOnMemoryUsage()
        end
        local kb = GetAddOnMemoryUsage(name)
        if kb and kb > 0 then
            local text = kb > 1024 and ("%.1f MB"):format(kb / 1024) or ("%d KB"):format(kb)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(text, 0.6, 0.6, 0.6)
        end
    end
    GameTooltip:Show()
end

local Refresh

local function SetEnabled(index, character, on)
    if on then C_AddOns.EnableAddOn(index, character) else C_AddOns.DisableAddOn(index, character) end
end

local function Toggle(row)
    local index = row.index
    if not index then return end
    local character = Character()
    local on = C_AddOns.GetAddOnEnableState(index, character) ~= Enum.AddOnEnableState.All
    PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    SetEnabled(index, character, on)
    C_AddOns.SaveAddOns()
    Refresh()
end

-- Toggle a whole category (incl. group children) - right-click on the header (like Blizzard)
local function SetCategory(entry, on)
    local character = Character()
    for _, parent in ipairs(entry.items) do
        SetEnabled(parent.index, character, on)
        local group = parent.group
        if group then
            for i = 1, C_AddOns.GetNumAddOns() do
                local name = C_AddOns.GetAddOnName(i)
                if name ~= group and C_AddOns.GetAddOnMetadata(i, "Group") == group then SetEnabled(i, character, on) end
            end
        end
    end
    PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    C_AddOns.SaveAddOns()
    Refresh()
end

local function HeaderClick(row, button)
    local entry = row.entry
    if button == "RightButton" then
        ns.UI.OpenList(row, {
            { value = "on", label = L["Enable category"] },
            { value = "off", label = L["Disable category"] },
        }, nil, function(value) SetCategory(entry, value == "on") end, { menu = true, title = entry.category })
        return
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    local collapsed = Collapsed()
    collapsed[entry.category] = not collapsed[entry.category] or nil
    Refresh()
end

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHeight(ROW_H)
    -- Category header: background + line like the groups in the character frame
    row.headBg = row:CreateTexture(nil, "BACKGROUND")
    row.headBg:SetAllPoints()
    row.headBg:SetColorTexture(0.1, 0.1, 0.11, 1)
    row.headLine = row:CreateTexture(nil, "BORDER")
    row.headLine:SetPoint("BOTTOMLEFT")
    row.headLine:SetPoint("BOTTOMRIGHT")
    row.headLine:SetHeight(ns.PixelSize())
    row.headLine:SetColorTexture(0, 0, 0, 1)
    row.sign = UI.Text(row, 13, "LEFT", UI.ACCENT)
    row.sign:SetPoint("LEFT", 8, 0)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    row.box = CreateFrame("Frame", nil, row)
    row.box:SetSize(16, 16)
    UI.CheckBg(row.box)
    row.tick = UI.Icon(row.box, "Check", 12, UI.ACCENT)
    row.tick:SetPoint("CENTER")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row.box, "RIGHT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.version = UI.Text(row, 12, "RIGHT", UI.MUTED)
    row.version:SetPoint("RIGHT", -6, 0)
    row.version:SetWidth(110)
    row.version:SetWordWrap(false)
    row.status = UI.Text(row, 12, "RIGHT")
    row.status:SetPoint("RIGHT", row.version, "LEFT", -10, 0)
    row.title = UI.Text(row, 13, "LEFT")
    row.title:SetPoint("RIGHT", row.status, "LEFT", -10, 0)
    row.title:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        if not self.entry.header then ShowTooltip(self) end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        if self.entry.header then HeaderClick(self, button) elseif button == "LeftButton" then Toggle(self) end
    end)
    rows[i] = row
    return row
end

local function FillHeader(row, entry)
    local UI = ns.UI
    row.index = nil
    row.headBg:Show()
    row.headLine:Show()
    row.sign:Show()
    row.sign:SetText(entry.collapsed and "+" or "−")
    row.box:Hide()
    row.icon:Hide()
    row.status:SetText("")
    row.title:ClearAllPoints()
    row.title:SetPoint("LEFT", 24, 0)
    row.title:SetPoint("RIGHT", row.status, "LEFT", -10, 0)
    row.title:SetText(entry.category)
    ns.SetFont(row.title, 13, "", "bold")
    row.title:SetTextColor(unpack(UI.ACCENT))
    -- right: how many of the category are enabled
    local character, on = Character(), 0
    for _, item in ipairs(entry.items) do
        if IsEnabled(item.index, character) then on = on + 1 end
    end
    row.version:SetText(("%d / %d"):format(on, #entry.items))
end

local function FillRow(row, entry)
    local UI = ns.UI
    local index = entry.index
    local character = Character()
    row.index = index
    row.headBg:Hide()
    row.headLine:Hide()
    row.sign:Hide()
    row.box:Show()
    row.icon:Show()
    row.box:ClearAllPoints()
    row.box:SetPoint("LEFT", entry.child and 26 or 6, 0)
    row.title:ClearAllPoints()
    row.title:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    row.title:SetPoint("RIGHT", row.status, "LEFT", -10, 0)
    ns.SetFont(row.title, 13)

    local state = C_AddOns.GetAddOnEnableState(index, character)
    local enabled = state > Enum.AddOnEnableState.None
    row.tick:SetShown(enabled)
    -- Enabled only for some characters ("All characters" view): grey check
    row.tick:SetVertexColor(unpack(state == Enum.AddOnEnableState.Some and UI.MUTED or UI.ACCENT))

    local icon = C_AddOns.GetAddOnMetadata(index, "IconTexture")
    local atlas = C_AddOns.GetAddOnMetadata(index, "IconAtlas")
    if icon then
        row.icon:SetTexture(icon)
    elseif not (atlas and row.icon:SetAtlas(atlas)) then
        row.icon:SetTexture(QUESTION)
    end
    row.icon:SetDesaturated(not enabled)
    row.icon:SetAlpha(enabled and 1 or 0.6)

    local loadable, reason = C_AddOns.IsAddOnLoadable(index, character)
    if enabled then
        row.title:SetText(entry.title)
        row.title:SetTextColor(unpack(UI.TEXT))
    else
        row.title:SetText(Plain(entry.title))
        row.title:SetTextColor(unpack(UI.MUTED))
    end

    -- right: "Reload" (changed) or why it does not load (out of date, missing dependency ...)
    local status, color = "", UI.MUTED
    if NeedsReload(index) then
        status, color = L["Reload"], UI.TAG
    elseif enabled and not loadable and reason and reason ~= "DEMAND_LOADED" and reason ~= "DEP_DEMAND_LOADED" then
        status, color = _G["ADDON_" .. reason] or reason, { 0.9, 0.35, 0.3 }
    end
    row.status:SetText(status)
    row.status:SetTextColor(unpack(color))
    row.version:SetText(C_AddOns.GetAddOnMetadata(index, "Version") or "")
end

function Refresh()
    if not window or not window:IsShown() then return end
    local UI = ns.UI
    local filter = (searchBox:GetText() or ""):lower()
    local entries = Entries(filter)
    local width = list:GetWidth()
    local y = 0
    for i, entry in ipairs(entries) do
        local row = Row(i)
        row.entry = entry
        local height = entry.header and HEAD_H or ROW_H
        if entry.header and i > 1 then y = y + 6 end -- spacing before each category
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetSize(width, height)
        if entry.header then FillHeader(row, entry) else FillRow(row, entry) end
        row:Show()
        y = y + height
    end
    for i = #entries + 1, #rows do rows[i]:Hide() end
    list:SetContentHeight(y)
    emptyText:SetShown(#entries == 0)

    local total, loaded = 0, 0
    for i = 1, C_AddOns.GetNumAddOns() do
        if select(6, C_AddOns.GetAddOnInfo(i)) ~= "SECURE" then
            total = total + 1
            if C_AddOns.IsAddOnLoaded(i) then loaded = loaded + 1 end
        end
    end
    window.npcTitle:SetText(L["%d of %d loaded"]:format(loaded, total))
    charButton.label:SetText(allCharacters and (ALL_CHARACTERS or L["All characters"]) or (UnitName("player") or ""))
    forceCheck:SetChecked(not C_AddOns.IsAddonVersionCheckEnabled())

    -- Reload: Surf Green border once something has changed
    local changed = AnyChanged()
    for _, edge in ipairs(reloadEdges) do edge:SetShown(changed) end
    reloadButton.Text:SetTextColor(unpack(changed and UI.ACCENT or UI.TEXT))
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIAddonList", WIDTH, ns.NPC_HEIGHT)
    window.ownPoint = { "CENTER", UIParent, "CENTER", 0, 0 } -- own position like Blizzard's list
    window:SetNpc(nil, ADDONS or L["Addons"], "", "Interface\\Icons\\INV_Misc_Gear_01")

    local top = -(ns.NPC_HEADER_BOTTOM + 14)
    charButton = CreateFrame("Button", nil, window)
    charButton:SetSize(180, 28)
    charButton:SetPoint("TOPRIGHT", -PAD, top)
    local charBg = UI.Box(charButton)
    charButton.label = UI.Text(charButton, 13, "LEFT")
    charButton.label:SetPoint("LEFT", 10, 0)
    charButton.label:SetPoint("RIGHT", -24, 0)
    charButton.label:SetWordWrap(false)
    local chevron = UI.Icon(charButton, "ChevronDown", 10, UI.MUTED)
    chevron:SetPoint("RIGHT", -8, 0)
    charButton:SetScript("OnEnter", function() charBg:SetColorTexture(unpack(UI.HOVER)) end)
    charButton:SetScript("OnLeave", function() charBg:SetColorTexture(unpack(UI.FIELD)) end)
    charButton:SetScript("OnClick", function(self)
        local items = {
            { value = "me", label = UnitName("player") or "" },
            { value = "all", label = ALL_CHARACTERS or L["All characters"] },
        }
        UI.OpenList(self, items, allCharacters and "all" or "me", function(value)
            allCharacters = value == "all"
            Refresh()
        end)
    end)

    searchBox = UI.EditBox(window, 28)
    searchBox:SetPoint("TOPLEFT", PAD, top)
    searchBox:SetPoint("RIGHT", charButton, "LEFT", -8, 0)
    searchHint = UI.Text(searchBox, 13, "LEFT", UI.MUTED)
    searchHint:SetPoint("LEFT", 10, 0)
    searchHint:SetText(SEARCH or L["Search"])
    searchBox:HookScript("OnTextChanged", function(self)
        searchHint:SetShown(self:GetText() == "")
        Refresh()
    end)

    list = UI.ScrollArea(window)
    list:SetPoint("TOPLEFT", PAD, top - 28 - 12)
    list:SetPoint("BOTTOMRIGHT", -PAD - 17, 56) -- room for the scrollbar
    emptyText = UI.Text(window, 13, "CENTER", UI.MUTED)
    emptyText:SetPoint("TOP", list, "TOP", 0, -60)
    emptyText:SetText(L["Nothing found."])

    -- Footer: All on / All off, Load out of date, Reload
    local allOn = UI.Button(window, L["Enable all"], function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        C_AddOns.EnableAllAddOns(Character())
        C_AddOns.SaveAddOns()
        Refresh()
    end, 110)
    allOn:SetHeight(28)
    allOn:SetPoint("BOTTOMLEFT", PAD, 14)
    local allOff = UI.Button(window, L["Disable all"], function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        C_AddOns.DisableAllAddOns(Character())
        -- mUI itself stays enabled (otherwise this list would be gone after the reload too)
        C_AddOns.EnableAddOn(ADDON_NAME, Character())
        C_AddOns.SaveAddOns()
        Refresh()
    end, 110)
    allOff:SetHeight(28)
    allOff:SetPoint("LEFT", allOn, "RIGHT", 6, 0)
    forceCheck = UI.LabelCheck(window, ADDON_FORCE_LOAD or L["Load out of date addons"], function(_, checked)
        C_AddOns.SetAddonVersionCheck(not checked)
        Refresh()
    end)
    forceCheck:SetPoint("LEFT", allOff, "RIGHT", 16, 0)

    reloadButton = UI.Button(window, RELOADUI or L["Reload UI"], function() ReloadUI() end, 150)
    reloadButton:SetHeight(28)
    reloadButton:SetPoint("BOTTOMRIGHT", -PAD, 14)
    reloadEdges = ns.AddBorder(reloadButton, true)
    for _, edge in ipairs(reloadEdges) do edge:SetVertexColor(unpack(UI.ACCENT)) end

    window:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        Refresh()
    end)
    window:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        UI.CloseList()
        C_AddOns.SaveAddOns()
    end)
end

local function Open()
    if not window then CreateWindow() end
    window:Show()
    window:Raise()
end
ns.OpenAddonList = Open

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not AddonList then return end
    Snapshot()
    -- Blizzard's list: no panel management (ShowUIPanel then just calls Show), parked invisibly.
    -- Every open opens ours and hides Blizzard's right away (without OnHide - Blizzard would
    -- otherwise revert unsaved changes).
    local function Unmanage()
        if InCombatLockdown() then return ns.AfterCombat(Unmanage) end
        if SetUIPanelAttribute then SetUIPanelAttribute(AddonList, "area", nil) end
    end
    Unmanage()
    AddonList:SetParent(hidden)
    hooksecurefunc(AddonList, "Show", function(self)
        self:Hide()
        Open()
    end)
end)
