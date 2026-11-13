-- Character tab: gear slots around the model on the left (item name, item level and enchant next
-- to each slot), four sub-views on the right (icons on top): stats, equipment sets, titles, pet.
--
--   [Head] Name       +-------+       Name [Hands]    [S][E][T][P]  Stats
--          Level      | Model |      Level            General ...
--   ...               +-------+         ...           resistances as color chips
--     [Main] Name   [Off] Name   [Ranged] Name   [Ammo]
--
-- Slots: left click/drag = pick up/equip (PickupInventoryItem), shift/ctrl click = link/dress up.
-- No right click "use": UseInventoryItem is protected for addons.
-- In the sets view each slot has an arrow opening matching bag items to swap in.
local _, ns = ...
local L = ns.L
local Char = ns.Char
local UI

local SLOT, SLOT_GAP = 40, 6
local LEFT_W = 580
local LABEL_W = 170      -- item text next to the side slots (over the model's edge)
local RIGHT_X = LEFT_W + 14
local SUB = 30

local LEFT_SLOTS = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "BACKSLOT", "CHESTSLOT", "SHIRTSLOT", "TABARDSLOT", "WRISTSLOT" }
local RIGHT_SLOTS = { "HANDSSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT" }
local BOTTOM_SLOTS = { "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT", "AMMOSLOT" }
local NO_LEVEL = { [INVSLOT_BODY or 4] = true, [INVSLOT_TABARD or 19] = true } -- shirt, tabard

local view
local slots = {}
local sub = "stats"
local selectedSet

local function IsHunterPet()
    local hasUI, isHunter = HasPetUI()
    return hasUI, isHunter
end

-- Slots ------------------------------------------------------------------------------------------

local function SlotTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if GetInventoryItemLink("player", button.slot) then
        GameTooltip:SetInventoryItem("player", button.slot)
    else
        GameTooltip:SetText(_G[button.slotName] or button.slotName, 1, 1, 1)
    end
    GameTooltip:Show()
end

local Flyout -- defined below

local function CreateSlot(parent, slotName, side)
    local slot, texture = C_PaperDollInfo.GetInventorySlotInfo(slotName)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SLOT, SLOT)
    button.slot, button.slotName, button.emptyTexture, button.side = slot, slotName, texture, side
    ns.AddSlotBackground(button)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.border = ns.AddBorder(button)
    button.count = ns.CreateText(button, 12, "RIGHT", "OUTLINE")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.12)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(self, mouse)
        -- A spell awaiting an item target (lure, oil, enchant) is handled by the secure overlay
        if SpellIsTargeting() then return end
        local link = GetInventoryItemLink("player", self.slot)
        if link and HandleModifiedItemClick(link) then return end
        if mouse == "LeftButton" then PickupInventoryItem(self.slot) end
    end)
    button:SetScript("OnDragStart", function(self) PickupInventoryItem(self.slot) end)
    button:SetScript("OnReceiveDrag", function(self) PickupInventoryItem(self.slot) end)
    button:SetScript("OnEnter", SlotTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Swap button for the sets view (not for ammo): a thin strip along the full slot height
    -- (bottom row: width) so it is easy to hit
    if slotName ~= "AMMOSLOT" then
        local arrow = CreateFrame("Button", nil, parent)
        local bg = UI.Box(arrow)
        local icon = UI.Icon(arrow, "ChevronDown", 12, UI.ACCENT)
        icon:SetPoint("CENTER")
        if side == "left" then
            arrow:SetSize(11, SLOT)
            arrow:SetPoint("LEFT", button, "RIGHT", 2, 0)
            icon:SetRotation(math.pi / 2)
        elseif side == "right" then
            arrow:SetSize(11, SLOT)
            arrow:SetPoint("RIGHT", button, "LEFT", -2, 0)
            icon:SetRotation(-math.pi / 2)
        else
            arrow:SetSize(SLOT, 11)
            arrow:SetPoint("BOTTOM", button, "TOP", 0, 2)
            icon:SetRotation(math.pi)
        end
        arrow:SetScript("OnEnter", function(self)
            bg:SetColorTexture(unpack(UI.HOVER))
            icon:SetVertexColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["Swap item"], 1, 1, 1)
            GameTooltip:Show()
        end)
        arrow:SetScript("OnLeave", function()
            bg:SetColorTexture(unpack(UI.FIELD))
            icon:SetVertexColor(unpack(UI.ACCENT))
            GameTooltip:Hide()
        end)
        arrow:SetScript("OnClick", function() Flyout(button) end)
        arrow:Hide()
        button.arrow = arrow
    end
    slots[#slots + 1] = button
    return button
end

local function UpdateSlot(button)
    local slot = button.slot
    local texture = GetInventoryItemTexture("player", slot)
    local quality = GetInventoryItemQuality("player", slot)
    if texture then
        button.icon:SetTexture(texture)
        button.icon:SetDesaturated(IsInventoryItemLocked(slot) and true or false)
        local broken = GetInventoryItemBroken("player", slot)
        button.icon:SetVertexColor(1, broken and 0.3 or 1, broken and 0.3 or 1)
        button.icon:SetAlpha(1)
    else
        button.icon:SetTexture(button.emptyTexture)
        button.icon:SetDesaturated(true)
        button.icon:SetVertexColor(1, 1, 1)
        button.icon:SetAlpha(0.35)
    end
    local r, g, b = 0, 0, 0
    if texture and quality and quality > 1 then r, g, b = C_Item.GetItemQualityColor(quality) end
    for _, edge in ipairs(button.border) do edge:SetVertexColor(r, g, b, 1) end
    -- name, item level (same option as Upgrades/ItemLevels.lua) and enchant next to the slot
    local level
    if texture and ns.db.characterItemLevels ~= false and not NO_LEVEL[slot] and button.slotName ~= "AMMOSLOT" then
        level = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot))
        if issecretvalue(level) or not level or level <= 1 then level = nil end
    end
    local link = texture and GetInventoryItemLink("player", slot)
    if issecretvalue(link) then link = nil end
    Char.UpdateSlotLabel(button, "player", link, quality, level)
    local count = button.slotName == "AMMOSLOT" and texture and GetInventoryItemCount("player", slot) or 0
    button.count:SetText(count > 0 and (count > 999 and "*" or count) or "")
end

-- Spells on gear (fishing lure, weapon oil, sharpening stone, enchant) ---------------------------
-- Only allowed from secure code: PickupInventoryItem with a pending targeting spell is protected
-- for addons. So secure buttons are laid over the slots while targeting: no action, just
-- "target-slot" - SecureActionButton applies the pending spell to that slot (SecureTemplates.lua).
-- They are parented to UIParent (parenting to our window would lock it in combat) and are only
-- shown out of combat.
local targets = {}

local function TargetButton(button)
    local overlay = targets[button]
    if overlay then return overlay end
    overlay = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    overlay:SetFrameStrata("DIALOG")
    overlay:RegisterForClicks("AnyUp", "AnyDown")
    overlay:SetAttribute("target-slot", button.slot)
    local glow = overlay:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetColorTexture(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.18)
    overlay:SetScript("OnEnter", function() SlotTooltip(button) end)
    overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)
    overlay:Hide()
    targets[button] = overlay
    return overlay
end

local function HideTargets()
    if InCombatLockdown() then return end
    for _, overlay in pairs(targets) do overlay:Hide() end
end

local function UpdateTargets()
    if InCombatLockdown() then return end
    local want = view and view:IsVisible() and sub ~= "pet" and SpellCanTargetItem()
    if not want then return HideTargets() end
    local scale = UIParent:GetEffectiveScale()
    for _, button in ipairs(slots) do
        local overlay = TargetButton(button)
        if button:IsVisible() and button:GetLeft() then
            local s = button:GetEffectiveScale() / scale
            overlay:ClearAllPoints()
            overlay:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", button:GetLeft() * s, button:GetTop() * s)
            overlay:SetSize(button:GetWidth() * s, button:GetHeight() * s)
            overlay:Show()
        else
            overlay:Hide()
        end
    end
end

-- Swap flyout (sets view): matching items from the bags ------------------------------------------

local flyout
local FLY = 34

local function CreateFlyout()
    flyout = CreateFrame("Frame", nil, view)
    flyout:SetFrameStrata("DIALOG")
    UI.Box(flyout, { 0.03, 0.03, 0.03, 0.97 })
    flyout.buttons = {}
    flyout:EnableMouse(true)
    flyout:SetScript("OnUpdate", function(self)
        if not self:IsMouseOver(8, -8, -8, 8) and not (self.owner and self.owner:IsMouseOver())
            and not (self.owner and self.owner.arrow and self.owner.arrow:IsMouseOver()) then
            self:Hide()
        end
    end)
end

local function FlyoutButton(i)
    local button = flyout.buttons[i]
    if button then return button end
    button = CreateFrame("Button", nil, flyout)
    button:SetSize(FLY, FLY)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.border = ns.AddBorder(button)
    -- Upgrade arrow as in the bags (Upgrades.lua), percentage below
    button.upgrade = CreateFrame("Frame", nil, button)
    button.upgrade:SetSize(16, 16)
    button.upgrade:SetPoint("TOPLEFT", 1, -1)
    button.upgrade:SetFrameLevel(button:GetFrameLevel() + 5)
    local shadow = UI.Icon(button.upgrade, "Upgrade", 16, { 0, 0, 0, 0.9 })
    shadow:SetPoint("CENTER", 1, -1)
    shadow:SetDrawLayer("OVERLAY", 1)
    local arrow = UI.Icon(button.upgrade, "Upgrade", 16, ns.UPGRADE_COLOR)
    arrow:SetPoint("CENTER")
    arrow:SetDrawLayer("OVERLAY", 2)
    button.percent = ns.CreateText(button.upgrade, 10, "CENTER", "OUTLINE")
    button.percent:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
    button.percent:SetTextColor(unpack(ns.UPGRADE_COLOR))
    button.upgrade:Hide()
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.15)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.setTooltip then self.setTooltip() else GameTooltip:SetText(self.label or "", 1, 1, 1) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self)
        if InCombatLockdown() and not (INVSLOTS_EQUIPABLE_IN_COMBAT and INVSLOTS_EQUIPABLE_IN_COMBAT[flyout.owner.slot]) then
            UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1, 0.1, 0.1)
            return
        end
        local action
        if self.location then
            action = EquipmentManager_EquipItemByLocation(self.location, flyout.owner.slot)
        else
            action = EquipmentManager_UnequipItemInSlot(flyout.owner.slot)
        end
        if action then EquipmentManager_RunAction(action) end
        flyout:Hide()
    end)
    flyout.buttons[i] = button
    return button
end

Flyout = function(owner)
    if not flyout then CreateFlyout() end
    if flyout:IsShown() and flyout.owner == owner then flyout:Hide() return end
    flyout.owner = owner
    local items = {}
    GetInventoryItemsForSlot(owner.slot, items)
    local entries = {}
    for location in pairs(items) do
        local _, name, texture, _, _, _, _, _, _, _, _, setTooltip, quality = EquipmentManager_GetItemInfoByLocation(location)
        -- Bags and other equipped slots only (e.g. ring 2 -> ring 1), not the bank
        local data = EquipmentManager_GetLocationData(location)
        if texture and not data.isBank and (data.isBags or (data.isPlayer and data.slot ~= owner.slot)) then
            local link = data.isBags and C_Container.GetContainerItemLink(data.bag, data.slot) or GetInventoryItemLink("player", data.slot)
            local upgrade = link and ns.UpgradePercent and ns.UpgradePercent(link)
            entries[#entries + 1] = { location = location, texture = texture, setTooltip = setTooltip, quality = quality, name = name,
                upgrade = (upgrade and upgrade >= 0.05) and upgrade or nil }
        end
    end
    -- Upgrades first (largest first), then by quality
    table.sort(entries, function(a, b)
        if (a.upgrade ~= nil) ~= (b.upgrade ~= nil) then return a.upgrade ~= nil end
        if a.upgrade and b.upgrade and a.upgrade ~= b.upgrade then return a.upgrade > b.upgrade end
        return (a.quality or 0) > (b.quality or 0)
    end)
    if GetInventoryItemLink("player", owner.slot) then
        entries[#entries + 1] = { texture = "Interface\\PaperDollInfoFrame\\UI-GearManager-ItemIntoBag", label = Char.G("EQUIPMENT_MANAGER_PLACE_IN_BAGS", "Put in bags") }
    end
    if #entries == 0 then
        entries[1] = { texture = 134400, label = L["No matching items in your bags"], disabled = true }
    end
    local perRow = 5
    for i, entry in ipairs(entries) do
        local button = FlyoutButton(i)
        button.location, button.setTooltip, button.label = entry.location, entry.setTooltip, entry.label
        button.icon:SetTexture(entry.texture)
        button:SetEnabled(not entry.disabled)
        button.upgrade:SetShown(entry.upgrade ~= nil)
        if entry.upgrade then
            local text = (entry.upgrade < 1 and "%.1f" or "%.0f"):format(entry.upgrade):gsub("%.", L["DECIMAL_SEPARATOR"])
            button.percent:SetText("+" .. text)
        end
        local r, g, b = 0, 0, 0
        if entry.quality and entry.quality > 1 then r, g, b = C_Item.GetItemQualityColor(entry.quality) end
        for _, edge in ipairs(button.border) do edge:SetVertexColor(r, g, b, 1) end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 6 + ((i - 1) % perRow) * (FLY + 4), -6 - math.floor((i - 1) / perRow) * (FLY + 4))
        button:Show()
    end
    for i = #entries + 1, #flyout.buttons do flyout.buttons[i]:Hide() end
    local cols, rows = math.min(#entries, perRow), math.ceil(#entries / perRow)
    flyout:SetSize(12 + cols * FLY + (cols - 1) * 4, 12 + rows * FLY + (rows - 1) * 4)
    flyout:ClearAllPoints()
    if owner.side == "bottom" then
        -- Bottom weapon slots: open upwards above the arrow (otherwise it covers neighboring slots)
        flyout:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 17)
    elseif owner.side == "right" then
        flyout:SetPoint("TOPRIGHT", owner, "TOPLEFT", -14, 0) -- right column: open to the left, into the window
    else
        flyout:SetPoint("TOPLEFT", owner, "TOPRIGHT", 14, 0)
    end
    flyout:Show()
end

-- Model -------------------------------------------------------------------------------------------

local function CreateModel(parent)
    local model = CreateFrame("PlayerModel", nil, parent)
    model.zoom = 1
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
    model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
    model:SetScript("OnUpdate", function(self)
        if not self.dragX then return end
        local x = GetCursorPosition()
        self:SetFacing(self:GetFacing() + (x - self.dragX) * 0.012)
        self.dragX = x
    end)
    model:SetScript("OnMouseWheel", function(self, delta)
        self.zoom = math.min(math.max(self.zoom - delta * 0.1, 0.5), 1.4)
        self:SetCamDistanceScale(self.zoom)
    end)
    -- Dropping an item on the model equips it
    model:SetScript("OnReceiveDrag", function()
        if C_PaperDollInfo.CanAutoEquipCursorItem() then AutoEquipCursorItem() end
    end)
    return model
end

local function ShowUnit(unit)
    local model = view.model
    model:ClearModel()
    model:SetUnit(unit)
    model:SetCamDistanceScale(model.zoom)
    model.unit = unit
end

-- Sub-views --------------------------------------------------------------------------------------

-- Stats (player or pet): rows + a row of resistance chips
local function CreateStats(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame.list = UI.ScrollArea(frame)
    frame.list:SetPoint("TOPLEFT")
    frame.list:SetPoint("BOTTOMRIGHT", -10, 34)
    frame.rows = {}
    frame.resist = {}
    for i = 1, 5 do
        local chip = CreateFrame("Frame", nil, frame)
        chip:SetHeight(26)
        UI.Box(chip, { 0.1, 0.1, 0.11, 1 })
        chip.color = chip:CreateTexture(nil, "ARTWORK")
        chip.color:SetSize(12, 12)
        chip.color:SetPoint("LEFT", 7, 0)
        chip.text = UI.Text(chip, 12, "LEFT")
        chip.text:SetPoint("LEFT", chip.color, "RIGHT", 6, 0)
        chip:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.name or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.resist[i] = chip
    end
    frame:SetScript("OnSizeChanged", function(self, width)
        local w = (width - 4 * 6) / 5
        for i, chip in ipairs(self.resist) do
            chip:ClearAllPoints()
            chip:SetPoint("BOTTOMLEFT", (i - 1) * (w + 6), 0)
            chip:SetWidth(w)
        end
    end)
    return frame
end

local function StatRow(frame, i)
    local row = frame.rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, frame.list.child)
    row:SetPoint("RIGHT", frame.list.child, "RIGHT")
    row.label = UI.Text(row, 13, "LEFT")
    row.label:SetPoint("LEFT")
    row.value = UI.Text(row, 13, "RIGHT")
    row.value:SetPoint("RIGHT", -2, 0)
    row.line = row:CreateTexture(nil, "BORDER")
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    row.line:SetHeight(ns.PixelSize())
    row.line:SetColorTexture(0.17, 0.17, 0.18, 1)
    row:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        self.tip()
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.rows[i] = row
    return row
end

local function FillStats(frame, unit)
    local y = 0
    local entries = Char.StatRows(unit)
    for i, entry in ipairs(entries) do
        local row = StatRow(frame, i)
        local header = entry.header ~= nil
        local gap = header and i > 1 and 8 or 0
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(y + gap))
        row:SetPoint("RIGHT", frame.list.child, "RIGHT")
        row:SetHeight(header and 24 or 21)
        row.label:SetText(header and entry.header or entry.label)
        ns.SetFont(row.label, header and 12 or 13, "", header and "bold" or nil)
        row.label:SetTextColor(unpack(header and UI.ACCENT or { 0.79, 0.78, 0.75 }))
        row.value:SetText(entry.value or "")
        row.value:SetTextColor(unpack(entry.color or UI.TEXT))
        row.line:SetShown(header)
        row.tip = entry.tip
        row:EnableMouse(entry.tip ~= nil)
        row:Show()
        y = y + gap + (header and 24 or 21) + 2
    end
    for i = #entries + 1, #frame.rows do frame.rows[i]:Hide() end
    frame.list:SetContentHeight(y)
    for i, data in ipairs(Char.Resistances(unit)) do
        local chip = frame.resist[i]
        chip.name = data.name
        chip.color:SetColorTexture(data.color[1], data.color[2], data.color[3], 1)
        chip.text:SetText(data.value)
    end
end

-- Equipment sets
local function SetPopup(which, text, onAccept, withName, default)
    local key = "MEREDANUI_EQUIPSET_" .. which
    StaticPopupDialogs[key] = {
        text = text, button1 = ACCEPT, button2 = CANCEL, hasEditBox = withName, maxLetters = 16,
        OnShow = function(self)
            if withName then
                local box = self.EditBox or self.editBox
                box:SetText(default or "")
                box:HighlightText()
            end
        end,
        OnAccept = function(self)
            local box = self.EditBox or self.editBox
            onAccept(withName and strtrim(box:GetText() or "") or nil)
        end,
        EditBoxOnEnterPressed = function(box)
            local parent = box:GetParent()
            onAccept(strtrim(box:GetText() or ""))
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show(key)
end

local function NewSet() Char.EditSet(nil) end
local function RenameSet(id) Char.EditSet(id) end
function Char.SelectSet(id)
    selectedSet = id
    Char.Refresh()
end

local function DeleteSet(id)
    local name = C_EquipmentSet.GetEquipmentSetInfo(id)
    SetPopup("DELETE", (CONFIRM_DELETE_EQUIPMENT_SET or "%s?"):format(name or ""), function()
        C_EquipmentSet.DeleteEquipmentSet(id)
        if selectedSet == id then selectedSet = nil end
    end)
end

local function SaveSet(id)
    local name = C_EquipmentSet.GetEquipmentSetInfo(id)
    SetPopup("SAVE", (CONFIRM_SAVE_EQUIPMENT_SET or "%s?"):format(name or ""), function()
        C_EquipmentSet.SaveEquipmentSet(id)
    end)
end

local function EquipSet(id)
    if not id then return end
    if C_EquipmentSet.EquipmentSetContainsLockedItems(id) or UnitCastingInfo("player") then
        UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1, 0.1, 0.1)
        return
    end
    C_EquipmentSet.UseEquipmentSet(id)
end

local function CreateSets(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame.list = Char.List(frame)
    frame.list:SetPoint("TOPLEFT")
    frame.list:SetPoint("BOTTOMRIGHT", -10, 40)
    local function Button(icon, tip, onClick, color)
        local b = UI.IconButton(frame, icon, onClick, 30)
        if color then b.icon:SetVertexColor(unpack(color)) end
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tip, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function(self)
            GameTooltip:Hide()
            if color then self.icon:SetVertexColor(unpack(color)) end
        end)
        return b
    end
    frame.equip = Button("Check", Char.G("EQUIPSET_EQUIP", "Equip"), function() EquipSet(selectedSet) end, UI.ACCENT)
    frame.equip:SetPoint("BOTTOMRIGHT")
    frame.save = Button("Save", Char.G("SAVE", "Save"), function() if selectedSet then SaveSet(selectedSet) end end)
    frame.save:SetPoint("RIGHT", frame.equip, "LEFT", -6, 0)
    frame.edit = Button("Edit", Char.G("EQUIPMENT_SET_EDIT", "Edit"), function() if selectedSet then RenameSet(selectedSet) end end)
    frame.edit:SetPoint("RIGHT", frame.save, "LEFT", -6, 0)
    frame.new = Button("Plus", Char.G("PAPERDOLL_NEWEQUIPMENTSET", "New set"), NewSet, UI.ACCENT)
    frame.new:SetPoint("RIGHT", frame.edit, "LEFT", -6, 0)
    frame.empty = UI.Text(frame, 13, "CENTER", { 0.47, 0.46, 0.43 })
    frame.empty:SetPoint("CENTER", 0, 20)
    frame.empty:SetText(L["No equipment sets yet."])
    return frame
end

local function FillSets(frame)
    local ids = C_EquipmentSet.GetEquipmentSetIDs() or {}
    local entries = {}
    local selectedExists = false
    for _, id in ipairs(ids) do
        local name, icon, _, equipped, _, _, _, missing = C_EquipmentSet.GetEquipmentSetInfo(id)
        if id == selectedSet then selectedExists = true end
        entries[#entries + 1] = {
            text = name, icon = icon or 134400, height = 34, selected = id == selectedSet,
            color = (missing and missing > 0) and { 0.88, 0.38, 0.38 } or nil,
            right = equipped and UI.IconMarkup("Check", 14, UI.ACCENT) or ((missing and missing > 0) and (L["%d missing"]):format(missing) or ""),
            onClick = function(_, mouse)
                selectedSet = id
                if mouse == "RightButton" then
                    MenuUtil.CreateContextMenu(frame, function(_, root)
                        root:CreateButton(Char.G("EQUIPSET_EQUIP", "Equip"), function() EquipSet(id) end)
                        root:CreateButton(Char.G("EQUIPMENT_SET_EDIT", "Edit"), function() RenameSet(id) end)
                        root:CreateButton("|cffff6060" .. DELETE .. "|r", function() DeleteSet(id) end)
                    end)
                end
                Char.Refresh()
            end,
            onEnter = function(row)
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetEquipmentSet(id)
                GameTooltip:Show()
            end,
        }
    end
    if not selectedExists then selectedSet = nil end
    frame.list:SetData(entries)
    frame.empty:SetShown(#entries == 0)
    local has = selectedSet ~= nil
    local equipped = has and select(4, C_EquipmentSet.GetEquipmentSetInfo(selectedSet))
    frame.equip:SetEnabled(has and not equipped)
    frame.save:SetEnabled(has)
    frame.edit:SetEnabled(has)
    for _, b in ipairs({ frame.equip, frame.save, frame.edit }) do b:SetAlpha(b:IsEnabled() and 1 or 0.4) end
end

-- Titles
local function CreateTitles(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame.list = Char.List(frame)
    frame.list:SetPoint("TOPLEFT")
    frame.list:SetPoint("BOTTOMRIGHT", -10, 0)
    return frame
end

local function FillTitles(frame)
    local current = GetCurrentTitle()
    local titles = {}
    for i = 1, GetNumTitles() do
        if IsTitleKnown(i) then
            local name = GetTitleName(i)
            if name and name ~= "" then titles[#titles + 1] = { name = strtrim(name), id = i } end
        end
    end
    table.sort(titles, function(a, b) return a.name < b.name end)
    table.insert(titles, 1, { name = Char.G("PLAYER_TITLE_NONE", "No title"), id = -1 })
    local entries = {}
    for _, title in ipairs(titles) do
        local active = title.id == current or (title.id == -1 and (current == 0 or current == -1))
        entries[#entries + 1] = {
            text = title.name, selected = active, color = active and UI.ACCENT or nil,
            right = active and UI.IconMarkup("Check", 14, UI.ACCENT) or "",
            onClick = function() SetCurrentTitle(title.id) end,
        }
    end
    frame.list:SetData(entries)
end

-- Layout ------------------------------------------------------------------------------------------

local SUBS = {
    { key = "stats", tip = function() return Char.G("PAPERDOLL_SIDEBAR_STATS", "Attributes") end, icon = 8197104 },
    { key = "sets", tip = function() return Char.G("PAPERDOLL_EQUIPMENTMANAGER", "Equipment sets") end,
      icon = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs", coords = { 0.0156, 0.5312, 0.4687, 0.6054 } },
    { key = "titles", tip = function() return Char.G("PAPERDOLL_SIDEBAR_TITLES", "Titles") end, icon = 8197118 },
    { key = "pet", tip = function() return PET end, pet = true },
}

local function SubAvailable(key)
    if key == "pet" then return HasPetUI() and true or false end
    return true
end

local function Layout()
    local pet = sub == "pet"
    for _, button in ipairs(slots) do
        button:SetShown(not pet)
        if button.arrow then button.arrow:SetShown(not pet and sub == "sets") end
    end
    if pet then
        view.ammo:SetShown(false)
    end
    view.petInfo:SetShown(pet)
    if flyout and sub ~= "sets" then flyout:Hide() end
    local target = pet and "pet" or "player"
    if view.model.unit ~= target or not view.model:GetModelFileID() then ShowUnit(target) end
    for key, frame in pairs(view.subs) do frame:SetShown(key == sub) end
    for _, button in ipairs(view.subButtons) do
        local active = button.def.key == sub
        for _, edge in ipairs(button.active) do edge:SetShown(active) end
        button:SetAlpha(SubAvailable(button.def.key) and 1 or 0.35)
    end
    for _, def in ipairs(SUBS) do
        if def.key == sub then view.subName:SetText(def.tip()) end
    end
end

local function UpdatePetInfo()
    local info = view.petInfo
    if not UnitExists("pet") then
        info.line:SetText(Char.G("ERR_NO_PET", "No pet"))
        info.xp:Hide()
        info.happy:Hide()
        return
    end
    local family = UnitCreatureFamily("pet") or ""
    local name = UnitName("pet") or ""
    local loyalty = C_PetInfo.GetPetLoyalty and C_PetInfo.GetPetLoyalty()
    if loyalty and not issecretvalue(loyalty) then loyalty = loyalty:gsub("^%((.*)%)$", "%1") end -- Blizzard already wraps it in parentheses
    info.line:SetText(("%s · %s %d %s"):format(name, LEVEL, UnitLevel("pet"), family))
    info.loyalty:SetText(loyalty or "")
    local current, nextXP = GetPetExperience()
    if nextXP and nextXP > 0 then
        info.xp:Set(current, nextXP, { 0.56, 0.44, 0.77 }, ("EP %s/%s"):format(BreakUpLargeNumbers(current), BreakUpLargeNumbers(nextXP)))
        info.xp:Show()
    else
        info.xp:Hide()
    end
    local _, isHunter = IsHunterPet()
    local happiness = isHunter and C_PetInfo.GetPetHappiness and C_PetInfo.GetPetHappiness()
    if happiness and not issecretvalue(happiness) then
        info.happy:SetAtlas(({ "UI-PetMad", "UI-PetNeutral", "UI-PetHappiness" })[happiness] or "UI-PetNeutral")
        info.happy.level = happiness
        info.happy:Show()
    else
        info.happy:Hide()
    end
end

local function Refresh()
    if not view then return end
    if sub ~= "stats" and not SubAvailable(sub) then sub = "stats" end
    if sub ~= "pet" then
        for _, button in ipairs(slots) do UpdateSlot(button) end
        view.ranged:SetShown(not C_PaperDollInfo.IsRangedSlotShown or C_PaperDollInfo.IsRangedSlotShown())
        local ammo = (not C_PaperDollInfo.AmmoNeeded or C_PaperDollInfo.AmmoNeeded() ~= false) and (not UnitUsesAmmo or UnitUsesAmmo("player"))
        view.ammo:SetShown(ammo and true or false)
    end
    Layout()
    if sub == "stats" then
        FillStats(view.subs.stats, "player")
    elseif sub == "pet" then
        UpdatePetInfo()
        FillStats(view.subs.stats, "pet")
        view.subs.stats:Show()
    elseif sub == "sets" then
        FillSets(view.subs.sets)
    elseif sub == "titles" then
        FillTitles(view.subs.titles)
    end
end

local function Create(frame)
    UI = ns.UI
    view = frame
    local left = CreateFrame("Frame", nil, frame)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(LEFT_W)
    view.left = left

    -- Model between the slot columns
    local stage = CreateFrame("Frame", nil, left)
    stage:SetPoint("TOPLEFT", SLOT + 14, 0)
    stage:SetPoint("BOTTOMRIGHT", -(SLOT + 14), SLOT + 22)
    UI.Box(stage, { 0.08, 0.08, 0.09, 1 })
    Char.RaceBackdrop(stage):SetUnit("player")
    view.model = CreateModel(stage)
    view.model:SetPoint("TOPLEFT", 1, -1)
    view.model:SetPoint("BOTTOMRIGHT", -1, 1)

    -- item texts on their own layer above the model
    local labels = CreateFrame("Frame", nil, left)
    labels:SetAllPoints()
    labels:SetFrameLevel(view.model:GetFrameLevel() + 5)
    for i, name in ipairs(LEFT_SLOTS) do
        local b = CreateSlot(left, name, "left")
        b:SetPoint("TOPLEFT", 0, -(i - 1) * (SLOT + SLOT_GAP))
        Char.AddSlotLabel(b, "left", LABEL_W, labels)
    end
    for i, name in ipairs(RIGHT_SLOTS) do
        local b = CreateSlot(left, name, "right")
        b:SetPoint("TOPRIGHT", 0, -(i - 1) * (SLOT + SLOT_GAP))
        Char.AddSlotLabel(b, "right", LABEL_W, labels)
    end
    -- bottom row: weapons with text to the right, ammo as a bare slot at the end; the weapon
    -- texts share the full width
    local weapons = #BOTTOM_SLOTS - 1
    local BOTTOM_LABEL_W = math.floor((LEFT_W - SLOT - #BOTTOM_SLOTS * 14) / weapons) - SLOT - 8
    local bottom, widths, total = {}, {}, 0
    for i, name in ipairs(BOTTOM_SLOTS) do
        bottom[i] = CreateSlot(left, name, "bottom")
        widths[i] = name == "AMMOSLOT" and SLOT or SLOT + 8 + BOTTOM_LABEL_W
        if name ~= "AMMOSLOT" then Char.AddSlotLabel(bottom[i], "bottom", BOTTOM_LABEL_W, labels) end
        total = total + widths[i] + (i > 1 and 14 or 0)
    end
    local x = (LEFT_W - total) / 2
    for i, b in ipairs(bottom) do
        b:SetPoint("BOTTOMLEFT", x, 0)
        x = x + widths[i] + 14
    end
    view.ranged, view.ammo = bottom[3], bottom[4]

    -- Pet info row below the model (replaces the bottom slots)
    local petInfo = CreateFrame("Frame", nil, left)
    petInfo:SetPoint("BOTTOMLEFT", SLOT + 14, 0)
    petInfo:SetPoint("BOTTOMRIGHT", -(SLOT + 14), 0)
    petInfo:SetHeight(SLOT + 14)
    petInfo.happy = petInfo:CreateTexture(nil, "ARTWORK")
    petInfo.happy:SetSize(18, 18)
    petInfo.happy:SetPoint("TOPLEFT")
    local happyHit = CreateFrame("Frame", nil, petInfo)
    happyHit:SetAllPoints(petInfo.happy)
    happyHit:SetScript("OnEnter", function(self)
        local level, damage, loyaltyRate = C_PetInfo.GetPetHappiness()
        if not level or issecretvalue(level) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(_G["PET_HAPPINESS" .. level] or "", 1, 1, 1)
        if damage and PET_DAMAGE_PERCENTAGE then GameTooltip:AddLine(PET_DAMAGE_PERCENTAGE:format(damage), 0.8, 0.8, 0.8) end
        if loyaltyRate and loyaltyRate ~= 0 then
            GameTooltip:AddLine(loyaltyRate < 0 and LOSING_LOYALTY or GAINING_LOYALTY, 0.8, 0.8, 0.8)
        end
        local foods = C_PetInfo.GetPetFoodTypes and C_PetInfo.GetPetFoodTypes()
        if foods and #foods > 0 and PET_DIET_TEMPLATE then
            GameTooltip:AddLine(PET_DIET_TEMPLATE:format(table.concat(foods, PET_FOOD_DELIMIT or ", ")), 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    happyHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    petInfo.line = UI.Text(petInfo, 13, "LEFT")
    petInfo.line:SetPoint("LEFT", petInfo.happy, "RIGHT", 8, 0)
    petInfo.loyalty = UI.Text(petInfo, 12, "RIGHT", UI.MUTED)
    petInfo.loyalty:SetPoint("TOPRIGHT")
    petInfo.xp = Char.Bar(petInfo, 16)
    petInfo.xp:SetPoint("BOTTOMLEFT")
    petInfo.xp:SetPoint("BOTTOMRIGHT")
    petInfo:Hide()
    view.petInfo = petInfo

    -- Right side: sub-views
    local right = CreateFrame("Frame", nil, frame)
    right:SetPoint("TOPLEFT", RIGHT_X, 0)
    right:SetPoint("BOTTOMRIGHT")
    view.subButtons = {}
    for i, def in ipairs(SUBS) do
        local button = CreateFrame("Button", nil, right)
        button:SetSize(SUB, SUB)
        button:SetPoint("TOPLEFT", (i - 1) * (SUB + 6), 0)
        UI.Box(button, { 0.1, 0.1, 0.11, 1 })
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        if def.pet then
            button.icon:SetTexture(ns.MEDIA .. "Icons\\Pet")
            button.icon:SetVertexColor(unpack(UI.TEXT))
        else
            button.icon:SetTexture(def.icon)
            if def.coords then button.icon:SetTexCoord(unpack(def.coords)) else button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        end
        button.active = ns.AddBorder(button, true, 2)
        for _, edge in ipairs(button.active) do edge:SetVertexColor(unpack(UI.ACCENT)) end
        button.def = def
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(def.tip(), 1, 1, 1)
            if not SubAvailable(def.key) then GameTooltip:AddLine(Char.G("ERR_NO_PET", "No pet"), 1, 0.3, 0.3) end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function()
            if not SubAvailable(def.key) then return end
            sub = def.key
            Char.Refresh()
        end)
        view.subButtons[i] = button
    end
    view.subName = UI.Text(right, 12, "RIGHT", UI.MUTED)
    view.subName:SetPoint("TOPRIGHT", 0, -8)
    local content = CreateFrame("Frame", nil, right)
    content:SetPoint("TOPLEFT", 0, -(SUB + 12))
    content:SetPoint("BOTTOMRIGHT")
    view.subs = {
        stats = CreateStats(content),
        sets = CreateSets(content),
        titles = CreateTitles(content),
    }
    -- Poll for targeting spells while the tab is open (every 0.1 s, a single call)
    local elapsed = 0
    frame:HookScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        UpdateTargets()
    end)
    frame:HookScript("OnHide", HideTargets)
end

Char.AddTab({
    key = "character", order = 1, tip = Char.G("CHARACTER_FRAME_TAB_CHARACTER", "Character"),
    icon = function(texture)
        SetPortraitTexture(texture, "player")
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end,
    Create = Create, Refresh = Refresh,
    OnHide = function() if flyout then flyout:Hide() end end,
    events = {
        "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED",
        "UNIT_STATS", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE", "UNIT_ATTACK", "UNIT_RANGED_ATTACK_POWER",
        "UNIT_ATTACK_POWER", "UNIT_SPELL_HASTE", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "UNIT_AURA", "UNIT_RESISTANCES",
        "COMBAT_RATING_UPDATE", "SPEED_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "SPELL_POWER_CHANGED", "SKILL_LINES_CHANGED",
        "PET_STATS_UPDATE", "UNIT_PET", "UNIT_PET_EXPERIENCE", "UNIT_HAPPINESS", "EQUIPMENT_SETS_CHANGED",
        "EQUIPMENT_SWAP_FINISHED", "KNOWN_TITLES_UPDATE", "UNIT_MODEL_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE",
    },
})

-- Entering combat: hide secure overlays while still allowed (fires before lockdown)
ns:On("PLAYER_REGEN_DISABLED", HideTargets)

-- Reload the model when appearance changes (shapeshift, gear)
ns:On("UNIT_MODEL_CHANGED", function(_, unit)
    if view and view:IsVisible() and (unit == "player" or unit == "pet") and view.model.unit == unit then ShowUnit(unit) end
end)
