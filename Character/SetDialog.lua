-- Create/edit equipment set dialog: name + icon. Icons come from Blizzard's IconDataProvider
-- (Equipment): equipped items first, then all game icons (several thousand). Only visible rows are
-- drawn; the provider is released on close to free its memory.
--
--   New equipment set                 [x]
--   [Icon]  [ Name ............ ]
--   +------------------------------+ ^
--   | # # # # # # # # # #          | |
--   | ...                          | v
--   +------------------------------+
--                     [Cancel] [Save]
local _, ns = ...
local L = ns.L
local Char = ns.Char

local COLS, ROWS, SIZE, GAP = 10, 6, 36, 4
local dialog, provider
local state = {} -- id (nil = new), selected (index), offset (row)

local function Total() return provider and provider:GetNumIcons() or 0 end
local function RowCount() return math.ceil(Total() / COLS) end
local function MaxOffset() return math.max(RowCount() - ROWS, 0) end

local function Render()
    for i, button in ipairs(dialog.icons) do
        local index = state.offset * COLS + i
        local texture = index <= Total() and provider:GetIconByIndex(index)
        if texture then
            button.index = index
            button.icon:SetTexture(texture)
            for _, edge in ipairs(button.edges) do
                local on = index == state.selected
                edge:SetVertexColor(on and ns.UI.ACCENT[1] or 0, on and ns.UI.ACCENT[2] or 0, on and ns.UI.ACCENT[3] or 0, 1)
            end
            button:Show()
        else
            button:Hide()
        end
    end
    dialog.preview:SetTexture(state.selected and provider:GetIconByIndex(state.selected) or 134400)
    dialog.scrollbar:Update()
end

local function Close()
    dialog:Hide()
end

local function Save()
    local name = strtrim(dialog.name:GetText() or "")
    if name == "" then
        dialog.name:SetFocus()
        return
    end
    local icon = state.selected and provider:GetIconForSaving(state.selected) or 134400
    if state.id then
        local oldName = C_EquipmentSet.GetEquipmentSetInfo(state.id)
        local other = C_EquipmentSet.GetEquipmentSetID(name)
        if other and other ~= state.id then
            UIErrorsFrame:AddMessage(EQUIPMENT_SETS_CANT_RENAME, 1, 0.1, 0.1)
            return
        end
        C_EquipmentSet.ModifyEquipmentSet(state.id, name ~= oldName and name or oldName, icon)
    else
        local existing = C_EquipmentSet.GetEquipmentSetID(name)
        if existing then
            C_EquipmentSet.SaveEquipmentSet(existing, icon) -- same name: overwrite (like Blizzard)
        else
            C_EquipmentSet.CreateEquipmentSet(name, icon)
            if Char.SelectSet then Char.SelectSet(C_EquipmentSet.GetEquipmentSetID(name)) end
        end
    end
    Close()
end

local function Create()
    local UI = ns.UI
    local width = COLS * SIZE + (COLS - 1) * GAP + 2 * 18 + 20
    dialog = CreateFrame("Frame", "MeredanUIEquipmentSetDialog", UIParent)
    dialog:SetSize(width, 470)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:SetClampedToScreen(true)
    UI.Box(dialog, ns.STYLE.panelColor, true)
    ns.RuneFrame(dialog, { small = true })
    tinsert(UISpecialFrames, "MeredanUIEquipmentSetDialog")
    dialog:Hide()

    dialog.title = UI.Text(dialog, 15, "LEFT")
    ns.SetFont(dialog.title, 15, "", "bold")
    dialog.title:SetPoint("TOPLEFT", 18, -18)
    local close = UI.IconButton(dialog, "Close", Close, 24)
    close:SetPoint("TOPRIGHT", -14, -14)

    local previewBox = CreateFrame("Frame", nil, dialog)
    previewBox:SetSize(44, 44)
    previewBox:SetPoint("TOPLEFT", 18, -52)
    ns.AddSlotBackground(previewBox)
    ns.AddItemFrame(previewBox, nil, 2)
    dialog.preview = previewBox:CreateTexture(nil, "ARTWORK")
    ns.InsetItemIcon(previewBox, dialog.preview, nil, 2)
    dialog.preview:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    dialog.name = UI.EditBox(dialog, 28)
    dialog.name:SetPoint("LEFT", previewBox, "RIGHT", 12, 0)
    dialog.name:SetPoint("RIGHT", -18, 0)
    dialog.name:SetMaxLetters(16)
    dialog.name:SetScript("OnEnterPressed", Save)
    dialog.name:SetScript("OnEscapePressed", Close)
    local nameLabel = UI.Text(dialog, 11, "LEFT", UI.MUTED)
    nameLabel:SetPoint("BOTTOMLEFT", dialog.name, "TOPLEFT", 2, 4)
    nameLabel:SetText(L["Name"])

    local hint = UI.Text(dialog, 11, "LEFT", UI.MUTED)
    hint:SetPoint("TOPLEFT", previewBox, "BOTTOMLEFT", 0, -14)
    hint:SetText(L["Choose an icon"])

    local grid = CreateFrame("Frame", nil, dialog)
    grid:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    grid:SetSize(COLS * SIZE + (COLS - 1) * GAP, ROWS * SIZE + (ROWS - 1) * GAP)
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta)
        state.offset = math.min(math.max(state.offset - delta, 0), MaxOffset())
        Render()
    end)
    dialog.icons = {}
    for i = 1, COLS * ROWS do
        local button = CreateFrame("Button", nil, grid)
        button:SetSize(SIZE, SIZE)
        button:SetPoint("TOPLEFT", ((i - 1) % COLS) * (SIZE + GAP), -math.floor((i - 1) / COLS) * (SIZE + GAP))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.edges = ns.AddBorder(button, true, 2)
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.15)
        button:SetScript("OnClick", function(self)
            state.selected = self.index
            Render()
        end)
        dialog.icons[i] = button
    end
    dialog.scrollbar = UI.Scrollbar(dialog, {
        GetRange = MaxOffset,
        GetOffset = function() return state.offset end,
        SetOffset = function(value)
            state.offset = math.floor(value + 0.5)
            Render()
        end,
        GetRatio = function()
            local rows = RowCount()
            return rows > 0 and math.min(ROWS / rows, 1) or 1
        end,
        step = 1,
        page = ROWS,
    })
    dialog.scrollbar:SetPoint("TOPLEFT", grid, "TOPRIGHT", 6, 0)
    dialog.scrollbar:SetPoint("BOTTOMLEFT", grid, "BOTTOMRIGHT", 6, 0)

    local save = UI.Button(dialog, SAVE, Save, 110)
    save:SetPoint("BOTTOMRIGHT", -18, 18)
    save.Text:SetTextColor(unpack(UI.ACCENT))
    local cancel = UI.Button(dialog, CANCEL, Close, 110)
    cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)

    dialog:SetScript("OnHide", function()
        if provider then
            provider:Release()
            provider = nil
        end
    end)
end

-- id = nil: new set; otherwise edit
function Char.EditSet(id)
    if not dialog then Create() end
    if not id and C_EquipmentSet.GetNumEquipmentSets() >= (MAX_EQUIPMENT_SETS_PER_PLAYER or 10) then
        UIErrorsFrame:AddMessage(EQUIPMENT_SETS_TOO_MANY, 1, 0.1, 0.1)
        return
    end
    if not provider then provider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Equipment) end
    state.id, state.offset = id, 0
    local name, icon = "", nil
    if id then name, icon = C_EquipmentSet.GetEquipmentSetInfo(id) end
    state.selected = icon and provider:GetIndexOfIcon(icon) or 2 -- new: first equipment icon
    if state.selected then state.offset = math.min(math.max(math.floor((state.selected - 1) / COLS) - 1, 0), MaxOffset()) end
    dialog.title:SetText(id and Char.G("EQUIPMENT_SET_EDIT", "Edit set") or Char.G("PAPERDOLL_NEWEQUIPMENTSET", "New set"))
    dialog.name:SetText(name or "")
    dialog:ClearAllPoints()
    local anchor = Char.window and Char.window:IsShown() and Char.window or UIParent
    dialog:SetPoint("CENTER", anchor, "CENTER")
    dialog:Show()
    Render()
    dialog.name:SetFocus()
    dialog.name:HighlightText()
end
