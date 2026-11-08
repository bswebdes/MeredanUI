-- Addon-Liste (WoW Forever) als eigenes mUI-Fenster statt Blizzards AddonList (Benny 2026-11-08).
-- Eigener Platz in der Bildmitte (wie Blizzards), Fenster-Familie wie Freunde/Händler:
--
--   ┌ [▣] Addons                                                   [x] ┐
--   │     24 von 31 geladen                                            │
--   │ [Suchen …                              ] [Dieser Charakter   v]  │
--   │ [x] [▣] MeredanUI                          Neu laden   v0.3.0    │
--   │ [x] [▣]   MeredanUI_Options                            v0.3.0    │  ← gehört zu einer Gruppe
--   │ [ ] [▣] Details!                                       v12.1     │  ← aus = grau
--   │ [Alle an] [Alle aus]  [ ] Veraltete laden          [ Neu laden ] │
--   └──────────────────────────────────────────────────────────────────┘
--
-- Wie bei Blizzard: Klick auf eine Zeile schaltet das Addon für den gewählten Charakter (bzw. alle)
-- an oder aus; wirksam nach dem Neuladen. Gespeichert wird sofort (kein „Abbrechen“).
-- Blizzards Fenster bleibt geparkt; sein Öffnen (Spielmenü > Addons) öffnet unseres.
local ADDON_NAME, ns = ...
local L = ns.L

local WIDTH, PAD, ROW_H = 600, 18, 30
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, list, searchBox, searchHint, charButton, forceCheck, reloadButton, reloadEdges, emptyText
local rows = {}
local startEnabled, startVersionCheck = {}, nil
local allCharacters = false -- Blizzard im Spiel: Standard = dieser Charakter

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

-- Titel ohne Farb-/Bild-Codes (Suche, Sortierung, graue Anzeige)
local function Plain(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("^%s+", "")
end

-- Stand beim Einloggen: Änderungen dagegen brauchen ein Neuladen
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

-- Einträge: Gruppen-Eltern alphabetisch, ihre Kinder eingerückt darunter (Blizzards „Group“)
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
    -- Kinder ohne vorhandenen Elternteil: normal einsortieren
    for group, kids in pairs(children) do
        if not byName[group] then
            for _, kid in ipairs(kids) do parents[#parents + 1] = kid end
            children[group] = nil
        end
    end
    local function ByTitle(a, b) return a.plain < b.plain end
    table.sort(parents, ByTitle)
    local result = {}
    for _, entry in ipairs(parents) do
        local kids = entry.group and children[entry.group] or {}
        table.sort(kids, ByTitle)
        local match = filter == "" or entry.plain:find(filter, 1, true)
        local kidMatches = {}
        for _, kid in ipairs(kids) do
            if match or kid.plain:find(filter, 1, true) then kidMatches[#kidMatches + 1] = kid end
        end
        if match or #kidMatches > 0 then
            result[#result + 1] = entry
            for _, kid in ipairs(kidMatches) do
                kid.child = true
                result[#result + 1] = kid
            end
        end
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
            window.memoryAt = GetTime() -- teuer: höchstens alle 15 s (wie Blizzard)
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

local function Toggle(row)
    local index = row.index
    if not index then return end
    local character = Character()
    if C_AddOns.GetAddOnEnableState(index, character) == Enum.AddOnEnableState.All then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        C_AddOns.DisableAddOn(index, character)
    else
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        C_AddOns.EnableAddOn(index, character)
    end
    C_AddOns.SaveAddOns()
    Refresh()
end

local function Row(i)
    if rows[i] then return rows[i] end
    local UI = ns.UI
    local row = CreateFrame("Button", nil, list.child)
    row:SetHeight(ROW_H)
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.04)
    hover:Hide()
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
    row.title:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    row.title:SetPoint("RIGHT", row.status, "LEFT", -10, 0)
    row.title:SetWordWrap(false)
    row:SetScript("OnEnter", function(self)
        hover:Show()
        ShowTooltip(self)
    end)
    row:SetScript("OnLeave", function()
        hover:Hide()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", Toggle)
    rows[i] = row
    return row
end

local function FillRow(row, entry)
    local UI = ns.UI
    local index = entry.index
    local character = Character()
    row.index = index
    row.box:ClearAllPoints()
    row.box:SetPoint("LEFT", entry.child and 26 or 6, 0)

    local state = C_AddOns.GetAddOnEnableState(index, character)
    local enabled = state > Enum.AddOnEnableState.None
    row.tick:SetShown(enabled)
    -- nur für manche Charaktere an (Ansicht „Alle Charaktere“): Haken grau
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

    -- rechts: „Neu laden“ (geändert) oder warum es nicht lädt (veraltet, Abhängigkeit fehlt …)
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
    for i, entry in ipairs(entries) do
        local row = Row(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetWidth(width)
        FillRow(row, entry)
        row:Show()
    end
    for i = #entries + 1, #rows do rows[i]:Hide() end
    list:SetContentHeight(#entries * ROW_H)
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

    -- Neu laden: Surf-Green-Rand, sobald etwas geändert ist
    local changed = AnyChanged()
    for _, edge in ipairs(reloadEdges) do edge:SetShown(changed) end
    reloadButton.Text:SetTextColor(unpack(changed and UI.ACCENT or UI.TEXT))
end

local function CreateWindow()
    local UI = ns.UI
    window = ns.CreateNpcWindow("MeredanUIAddonList", WIDTH, ns.NPC_HEIGHT)
    window.ownPoint = { "CENTER", UIParent, "CENTER", 0, 0 } -- eigener Platz wie Blizzards Liste
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
    list:SetPoint("BOTTOMRIGHT", -PAD - 17, 56) -- Platz für die Scrollleiste
    emptyText = UI.Text(window, 13, "CENTER", UI.MUTED)
    emptyText:SetPoint("TOP", list, "TOP", 0, -60)
    emptyText:SetText(L["Nothing found."])

    -- Fuß: Alle an / Alle aus, Veraltete laden, Neu laden
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
        -- mUI selbst bleibt an (sonst wäre nach dem Neuladen auch diese Liste weg)
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
    -- Blizzards Liste: keine Fensterverwaltung mehr (ShowUIPanel ruft dann nur Show), unsichtbar
    -- geparkt; jedes Öffnen öffnet unsere und legt Blizzards gleich wieder weg (ohne OnHide –
    -- Blizzard würde sonst ungespeicherte Änderungen zurücksetzen)
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
