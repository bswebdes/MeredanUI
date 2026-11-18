-- "Templates" tab in the mUI macro window: ready-made class macros (Skins/MacroTemplatesData.lua)
-- that the player creates as character macros with one click. Only templates whose spells the
-- character knows can be created; spell names are filled in from spell ids, so the macro text is
-- in the client's language.
--
-- The tab is our own button next to Blizzard's two tabs (never added to PanelTemplates: Blizzard
-- disables the selected tab and would fight over the selection). The panel covers the macro grid,
-- edit area and footer while it is shown. Macros are created with CreateMacro/EditMacro, which
-- addons may call out of combat.
local _, ns = ...

local M = {}
ns.MacroTemplates = M

local DE = GetLocale() == "deDE"
local function Loc(pair) return pair and pair[DE and 2 or 1] or "" end

local TEXT = {
    tab = { "Templates", "Vorlagen" },
    subtitle = { "Ready-made macros for your class", "Fertige Makros für deine Klasse" },
    how = { "How it works", "So geht's" },
    macro = { "Macro", "Makro" },
    create = { "Create", "Anlegen" },
    update = { "Update", "Erneuern" },
    ready = { "Ready", "Bereit" },
    exists = { "Created", "Angelegt" },
    fromLevel = { "From level %d", "Ab Stufe %d" },
    notLearned = { "Not learned yet: %s", "Noch nicht gelernt: %s" },
    taken = { "A macro named \"%s\" already exists", "Es gibt schon ein Makro \"%s\"" },
    full = { "No free character macro slot", "Kein freier Platz für Charakter-Makros" },
    combat = { "Not possible in combat", "Im Kampf nicht möglich" },
    tooLong = { "Macro too long in this language", "Makro in dieser Sprache zu lang" },
    slots = { "Character macros: %d/%d", "Charakter-Makros: %d/%d" },
    none = { "No templates for your class yet.", "Für deine Klasse gibt es noch keine Vorlagen." },
    hint = { "Saved for this character only. Spell names follow your game language.",
             "Wird nur für diesen Charakter gespeichert. Zaubernamen folgen deiner Spielsprache." },
}
local function T(key) return Loc(TEXT[key]) end

local QUESTION_MARK = 134400 -- macro icon "?" lets #showtooltip pick the icon itself
local MAX_BODY = 255
local ROW_H = 44

-- Localized words that are not spell names --------------------------------------------------------
local WORDS = {
    PET_VOIDWALKER = { "Voidwalker", "Leerwandler" },
    PET_SUCCUBUS = { "Succubus", "Sukkubus" },
    PET_FELHUNTER = { "Felhunter", "Teufelsjäger" },
}
local function Word(key)
    if key == "SHIELDS" then
        local name = C_Item and C_Item.GetItemSubClassInfo and Enum.ItemClass and Enum.ItemArmorSubclass
            and C_Item.GetItemSubClassInfo(Enum.ItemClass.Armor, Enum.ItemArmorSubclass.Shield)
        return (name and name ~= "") and name or Loc({ "Shields", "Schilde" })
    end
    return WORDS[key] and Loc(WORDS[key])
end

-- Spells -----------------------------------------------------------------------------------------
local function Known(id)
    if C_SpellBook.IsSpellKnownOrInSpellBook then return C_SpellBook.IsSpellKnownOrInSpellBook(id) and true or false end
    return C_SpellBook.IsSpellKnown(id) and true or false
end

local function SpellName(id) return C_Spell.GetSpellName(id) end

local function ParseIds(inner)
    local ids = {}
    for n in inner:gmatch("%d+") do ids[#ids + 1] = tonumber(n) end
    return ids
end

-- req entry: a spell id, or a table = any of these
local function ReqKnown(entry)
    if type(entry) == "table" then
        for _, id in ipairs(entry) do if Known(id) then return true end end
        return false
    end
    return Known(entry)
end

local function FirstMissing(t)
    for _, entry in ipairs(t.req or {}) do
        if not ReqKnown(entry) then return type(entry) == "table" and entry[1] or entry end
    end
end

-- Is every spell referenced in a body fragment known? ({a|b} = any of them)
local function FragmentKnown(fragment)
    for inner in fragment:gmatch("{([%d|r]+)}") do
        local any = false
        for _, id in ipairs(ParseIds(inner)) do if Known(id) then any = true break end end
        if not any then return false end
    end
    return true
end

-- Resolve one {token}; returns nil when a spell has no name (wrong id for this client)
local function Resolve(inner)
    local best = inner:match("^BEST:(.+)$")
    if best then
        local item
        for spell, itemID in best:gmatch("(%d+)=(%d+)") do
            if not item or Known(tonumber(spell)) then item = itemID end
        end
        return item and ("item:" .. item)
    end
    if inner:match("^%u[%u_]+$") then return Word(inner) end
    local ranked = inner:match("^(%d+)r$")
    if ranked then
        local id = tonumber(ranked)
        local name = SpellName(id)
        if not name then return nil end
        local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
        return (sub and sub ~= "") and ("%s(%s)"):format(name, sub) or name
    end
    local ids = ParseIds(inner)
    local pick = ids[1]
    for _, id in ipairs(ids) do if Known(id) then pick = id break end end
    return pick and SpellName(pick)
end

-- Build the macro text; dropAll removes every optional <<...>> part (used when too long)
local function Build(t, dropAll)
    local body = t.body:gsub("<<(.-)>>", function(part)
        if not dropAll and FragmentKnown(part) then return part end
        return ""
    end)
    local failed = false
    body = body:gsub("{([^}]+)}", function(inner)
        local value = Resolve(inner)
        if not value then failed = true return "" end
        return value
    end)
    if failed then return nil end
    return body
end

local function BodyFor(t)
    local body = Build(t)
    if body and #body > MAX_BODY then body = Build(t, true) end
    if body and #body > MAX_BODY then return nil, "tooLong" end
    return body
end

-- Character macros -------------------------------------------------------------------------------
local function CharRange()
    local base = Constants.MacroConsts.MAX_ACCOUNT_MACROS
    local _, numChar = GetNumMacros()
    return base, numChar, Constants.MacroConsts.MAX_CHARACTER_MACROS
end

local function FindCharMacro(name)
    local base, numChar = CharRange()
    for i = base + 1, base + numChar do
        if GetMacroInfo(i) == name then return i end
    end
end

local function Record()
    if not ns.char then return {} end
    ns.char.macroTemplates = ns.char.macroTemplates or {}
    return ns.char.macroTemplates
end

local function MacroName(t) return Loc(t.name):sub(1, 16) end

-- State of a template: "ready" | "exists" (ours, can update) | "taken" | "missing" | "broken"
local function StateOf(t)
    local missing = FirstMissing(t)
    if missing then return "missing", missing end
    local body, err = BodyFor(t)
    if not body then return "broken", err end
    local index = FindCharMacro(MacroName(t))
    if index then
        if Record()[t.id] == MacroName(t) then return "exists", index end
        return "taken"
    end
    return "ready"
end

-- UI ---------------------------------------------------------------------------------------------
local frame, layout, tab, panel, list, rows, detail
local shown, selectedId = false, nil
local templates = {}

local function ClassTemplates()
    wipe(templates)
    local class = select(2, UnitClass("player"))
    for _, t in ipairs(ns.MACRO_TEMPLATES or {}) do
        if t.class == class then
            -- skip templates whose spells this client doesn't know at all (wrong id)
            local ok = true
            for _, entry in ipairs(t.req or {}) do
                local id = type(entry) == "table" and entry[1] or entry
                if not SpellName(id) then ok = false break end
            end
            if ok then templates[#templates + 1] = t end
        end
    end
    -- usable first, then by level
    local rank = { exists = 0, ready = 0, taken = 1, broken = 2, missing = 3 }
    table.sort(templates, function(a, b)
        local ra, rb = rank[(StateOf(a))] or 3, rank[(StateOf(b))] or 3
        if ra ~= rb then return ra < rb end
        if a.lvl ~= b.lvl then return a.lvl < b.lvl end
        return Loc(a.name) < Loc(b.name)
    end)
end

local function IconOf(t)
    local entry = t.icon or (t.req and t.req[1])
    local id = type(entry) == "table" and entry[1] or entry
    return id and C_Spell.GetSpellTexture(id) or QUESTION_MARK
end

local function StatusText(t)
    local state, extra = StateOf(t)
    if state == "missing" then
        if (UnitLevel("player") or 1) < (t.lvl or 1) then return T("fromLevel"):format(t.lvl), false end
        return T("notLearned"):format(SpellName(extra) or "?"), false
    end
    if state == "broken" then return T(extra or "tooLong"), false end
    if state == "taken" then return T("taken"):format(MacroName(t)), false end
    if state == "exists" then return T("exists"), true end
    return T("ready"), true
end

local function Find(id)
    for _, t in ipairs(templates) do if t.id == id then return t end end
end

local RefreshDetail

local function RefreshList()
    if not list then return end
    local UI = ns.UI
    for i, t in ipairs(templates) do
        local row = rows[i]
        if not row then
            row = CreateFrame("Button", nil, list.child)
            row:SetHeight(ROW_H)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.hover = row:CreateTexture(nil, "HIGHLIGHT")
            row.hover:SetAllPoints()
            row.hover:SetColorTexture(1, 1, 1, 0.05)
            row.slot = CreateFrame("Frame", nil, row)
            row.slot:SetSize(32, 32)
            row.slot:SetPoint("LEFT", 8, 0)
            ns.AddSlotBackground(row.slot)
            ns.AddItemFrame(row.slot, nil, 2)
            row.icon = row.slot:CreateTexture(nil, "ARTWORK")
            ns.InsetItemIcon(row.slot, row.icon, nil, 2)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.name = UI.Text(row, 13, "LEFT")
            ns.SetFont(row.name, 13, "", "bold")
            row.name:SetPoint("TOPLEFT", row.slot, "TOPRIGHT", 10, -1)
            row.name:SetPoint("RIGHT", -8, 0)
            row.status = UI.Text(row, 11, "LEFT", UI.MUTED)
            row.status:SetPoint("BOTTOMLEFT", row.slot, "BOTTOMRIGHT", 10, 1)
            row.status:SetPoint("RIGHT", -8, 0)
            row:SetScript("OnClick", function(self)
                selectedId = self.templateId
                RefreshList()
                RefreshDetail()
            end)
            rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("RIGHT", list.child, "RIGHT")
        row.templateId = t.id
        row.icon:SetTexture(IconOf(t))
        row.name:SetText(Loc(t.name))
        local status, usable = StatusText(t)
        row.status:SetText(status)
        row.icon:SetDesaturated(not usable)
        row.name:SetTextColor(unpack(usable and UI.TEXT or UI.MUTED))
        if t.id == selectedId then
            row.bg:SetColorTexture(unpack(UI.HOVER))
        else
            row.bg:SetColorTexture(0, 0, 0, 0)
        end
        row:Show()
    end
    for i = #templates + 1, #rows do rows[i]:Hide() end
    list:SetContentHeight(#templates * ROW_H)
    detail.empty:SetShown(#templates == 0)
end

local function SetButton(enabled, label)
    local button = detail.button
    button.Text:SetText(label)
    if enabled then
        button:Enable()
        button.Text:SetTextColor(unpack(ns.UI.TEXT))
    else
        button:Disable()
        button.Text:SetTextColor(unpack(ns.UI.MUTED))
    end
end

RefreshDetail = function()
    if not detail then return end
    local t = Find(selectedId)
    detail.content:SetShown(t ~= nil)
    local _, numChar, max = CharRange()
    detail.slots:SetText(T("slots"):format(numChar, max))
    if not t then return end
    detail.title:SetText(Loc(t.name))
    detail.desc:SetText(Loc(t.desc))
    detail.how:SetText(Loc(t.how))
    local body = BodyFor(t) or Build(t, true) or t.body
    detail.code:SetText(body)
    local state = StateOf(t)
    local status, usable = StatusText(t)
    detail.status:SetText(usable and T("hint") or status)
    detail.status:SetTextColor(unpack(usable and ns.UI.MUTED or ns.UI.TAG))
    if InCombatLockdown() then
        SetButton(false, T("create"))
        detail.status:SetText(T("combat"))
    elseif state == "exists" then
        SetButton(true, T("update"))
    elseif state == "ready" then
        SetButton(numChar < max, T("create"))
        if numChar >= max then detail.status:SetText(T("full")) end
    else
        SetButton(false, T("create"))
    end
end

local function Refresh()
    if not shown then return end
    ClassTemplates()
    if not Find(selectedId) then selectedId = templates[1] and templates[1].id end
    RefreshList()
    RefreshDetail()
end

local function CreateSelected()
    local t = Find(selectedId)
    if not t or InCombatLockdown() then return end
    local state, index = StateOf(t)
    local body = BodyFor(t)
    if not body then return end
    -- keep unsaved edits in Blizzard's edit box: UPDATE_MACROS reloads the selected macro's text
    if frame.SaveMacro then frame:SaveMacro() end
    local name = MacroName(t)
    if state == "exists" then
        EditMacro(index, name, QUESTION_MARK, body)
    elseif state == "ready" then
        index = CreateMacro(name, QUESTION_MARK, body, true)
    else
        return
    end
    if not index then return end
    Record()[t.id] = name
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    -- show the new macro in the character tab, ready to drag onto a bar
    M.Hide()
    if frame.ChangeTab then frame:ChangeTab(2) end
    if frame.SelectMacro then frame:SelectMacro(index - Constants.MacroConsts.MAX_ACCOUNT_MACROS, true) end
end

local function BuildPanel()
    local UI = ns.UI
    local Kit = ns.SkinKit
    local PAD, TOP, FOOTER, GRID_W, RIGHT_X = layout.PAD, layout.CONTENT_TOP, layout.FOOTER, layout.GRID_W, layout.RIGHT_X

    -- covers grid, edit area and footer; children are placed in window coordinates
    panel = CreateFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -(TOP - 6))
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    panel:SetFrameLevel(frame:GetFrameLevel() + 60)
    panel:EnableMouse(true)
    local c = ns.STYLE.panelColor
    local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(c[1], c[2], c[3], 1)
    panel:Hide()

    -- left: template list set into the window like the macro grid
    local inset = CreateFrame("Frame", nil, panel)
    inset:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP)
    inset:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, FOOTER)
    inset:SetWidth(GRID_W)
    Kit.Inset(inset)
    list = UI.ScrollArea(inset)
    list:SetPoint("TOPLEFT", 4, -4)
    list:SetPoint("BOTTOMRIGHT", -20, 4)
    rows = {}

    -- right: details of the selected template
    detail = CreateFrame("Frame", nil, panel)
    detail:SetPoint("TOPLEFT", frame, "TOPLEFT", RIGHT_X, -TOP)
    detail:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER)
    detail.empty = UI.Text(detail, 12, "LEFT", UI.MUTED)
    detail.empty:SetPoint("TOPLEFT")
    detail.empty:SetText(T("none"))

    local content = CreateFrame("Frame", nil, detail)
    content:SetAllPoints()
    detail.content = content
    detail.title = UI.Title(content, 16, "LEFT")
    detail.title:SetPoint("TOPLEFT")
    detail.title:SetPoint("RIGHT")
    detail.desc = UI.Text(content, 12, "LEFT")
    detail.desc:SetWordWrap(true)
    detail.desc:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -8)
    detail.desc:SetPoint("RIGHT")

    local howHead = UI.Heading(content, 12, "LEFT")
    howHead:SetPoint("TOPLEFT", detail.desc, "BOTTOMLEFT", 0, -14)
    howHead:SetText(T("how"))
    detail.how = UI.Text(content, 12, "LEFT")
    detail.how:SetWordWrap(true)
    detail.how:SetPoint("TOPLEFT", howHead, "BOTTOMLEFT", 0, -5)
    detail.how:SetPoint("RIGHT")

    local codeHead = UI.Heading(content, 12, "LEFT")
    codeHead:SetPoint("TOPLEFT", detail.how, "BOTTOMLEFT", 0, -14)
    codeHead:SetText(T("macro"))
    local box = CreateFrame("Frame", nil, content)
    box:SetPoint("TOPLEFT", codeHead, "BOTTOMLEFT", 0, -6)
    box:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    UI.Groove(box)
    detail.code = UI.Text(box, 12, "LEFT")
    detail.code:SetFont(ns.STYLE.font, ns.FontPx(12), "")
    detail.code:SetWordWrap(true)
    detail.code:SetJustifyV("TOP")
    detail.code:SetSpacing(2)
    detail.code:SetPoint("TOPLEFT", 10, -9)
    detail.code:SetPoint("BOTTOMRIGHT", -10, 9)

    -- footer: slot count + status left, create button where Blizzard's Save sits
    detail.button = UI.Button(panel, T("create"), CreateSelected, 120)
    detail.button:SetHeight(28)
    detail.button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 14)
    -- UI.Button brightens on hover; a disabled button stays muted
    detail.button:HookScript("OnEnter", function(self)
        if not self:IsEnabled() then self.Text:SetTextColor(unpack(UI.MUTED)) end
    end)
    detail.slots = UI.Text(panel, 11, "LEFT", UI.MUTED)
    detail.slots:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 22)
    detail.status = UI.Text(panel, 11, "RIGHT", UI.MUTED)
    detail.status:SetPoint("RIGHT", detail.button, "LEFT", -12, 0)
    detail.status:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD + GRID_W + 16, 28)
end

function M.IsShown() return shown end
function M.Subtitle() return T("subtitle") end

function M.Show()
    if not panel then return end
    if _G.MacroPopupFrame and _G.MacroPopupFrame:IsShown() then return end
    shown = true
    if _G.MacroFrameText then _G.MacroFrameText:ClearFocus() end
    -- rank names (Earth Shock rank 1 etc.) may not be loaded yet
    if C_Spell.RequestLoadSpellData then
        for _, t in ipairs(ns.MACRO_TEMPLATES or {}) do
            for inner in t.body:gmatch("{(%d+)r}") do C_Spell.RequestLoadSpellData(tonumber(inner)) end
        end
    end
    panel:Show()
    Refresh()
    -- Blizzard's selected tab is disabled; enable it so a click brings the macros back
    for _, blizz in ipairs({ _G.MacroFrameTab1, _G.MacroFrameTab2 }) do blizz:Enable() end
    if M.onChange then M.onChange() end
end

function M.Hide()
    if not shown then return end
    shown = false
    panel:Hide()
    if M.onChange then M.onChange() end
end

-- Called by Skins/Macros.lua once the macro window is skinned.
-- lay: PAD, CONTENT_TOP, FOOTER, GRID_W, RIGHT_X; onChange: re-style tabs + subtitle
function M.Attach(macroFrame, lay, onChange)
    if tab then return tab end
    frame, layout, M.onChange = macroFrame, lay, onChange
    tab = CreateFrame("Button", nil, frame)
    tab:SetHeight(28)
    tab:SetNormalFontObject(GameFontHighlight)
    tab:SetText(T("tab"))
    ns.SkinKit.Tab(tab)
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        M.Show()
    end)
    BuildPanel()

    -- Blizzard's tabs bring the macros back; opening the window always starts on them
    for _, blizz in ipairs({ _G.MacroFrameTab1, _G.MacroFrameTab2 }) do
        blizz:HookScript("OnClick", function() M.Hide() end)
    end
    frame:HookScript("OnShow", function() M.Hide() end)
    frame:HookScript("OnHide", function() M.Hide() end)

    local events = CreateFrame("Frame", nil, panel)
    events:RegisterEvent("UPDATE_MACROS")
    events:RegisterEvent("SPELLS_CHANGED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("SPELL_TEXT_UPDATE")
    events:SetScript("OnEvent", function()
        if shown then Refresh() end
    end)
    return tab
end
