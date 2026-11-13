-- Keybind mode (/kb, idea from ElvUI, MUI look): hover an action button and press a key
-- (also mouse buttons 3-5, mouse wheel, with Shift/Ctrl/Alt). Esc clears the binding.
--
--  +- KEYBINDS ----------------------- x +   <- panel top center, movable
--  | Hover a button, press a key        |
--  | Esc clears the binding             |
--  | [ ] Character-specific             |
--  | [ Save ]            [ Discard ]    |
--  +------------------------------------+
--  [#] <- button under the mouse: Surf Green border, tooltip shows current binding
--
-- Binds Blizzard's commands (ACTIONBUTTON1, MULTIACTIONBAR1BUTTON1, BONUSACTIONBUTTON1 ...);
-- ActionBars.lua redirects them to our buttons. An unprotected catcher frame sits over the button,
-- so MUI never touches the secure buttons themselves. Out of combat only.
local _, ns = ...
local L = ns.L

local active = false
local dirty = false
local panel, catcher
local hooked = {}

-- keys that bind nothing on their own (modifiers only)
local IGNORE = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, UNKNOWN = true,
}
-- Blizzard's binding sets (constants are partly missing as globals)
local ACCOUNT, CHARACTER = ACCOUNT_BINDINGS or 1, CHARACTER_BINDINGS or 2
local MOUSE = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

-- Blizzard's order: ALT-CTRL-SHIFT-key
local function WithModifiers(key)
    local prefix = ""
    if IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    if IsMetaKeyDown and IsMetaKeyDown() then prefix = prefix .. "META-" end
    return prefix .. key
end

local function KeysText(command)
    local keys = { GetBindingKey(command) }
    if #keys == 0 then return nil end
    for i, key in ipairs(keys) do keys[i] = GetBindingText(key) end
    return table.concat(keys, ", ")
end

-- Tooltip: what the button does and which keys it has
local function ShowTooltip()
    local target = catcher.target
    if not target then return end
    GameTooltip:SetOwner(catcher, "ANCHOR_TOP")
    GameTooltip:SetText(_G["BINDING_NAME_" .. catcher.command] or catcher.command, unpack(ns.UI.ACCENT))
    local keys = KeysText(catcher.command)
    if keys then
        GameTooltip:AddLine(keys, 1, 1, 1)
    else
        GameTooltip:AddLine(L["Not bound"], unpack(ns.UI.MUTED))
    end
    GameTooltip:Show()
end

local function Bind(key)
    if not catcher.command or InCombatLockdown() then return end
    if key == "ESCAPE" then
        for _, old in ipairs({ GetBindingKey(catcher.command) }) do SetBinding(old) end
    else
        SetBinding(WithModifiers(key), catcher.command)
    end
    dirty = true
    ShowTooltip()
end

local function CreateCatcher()
    catcher = CreateFrame("Button", "MeredanUIKeyBindCatcher", UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:EnableKeyboard(true)
    catcher:EnableMouseWheel(true)
    catcher:RegisterForClicks("AnyUp")
    local fill = catcher:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    fill:SetColorTexture(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.2)
    for _, edge in ipairs(ns.AddBorder(catcher, true, 2)) do edge:SetVertexColor(unpack(ns.UI.ACCENT)) end
    catcher:SetScript("OnKeyDown", function(_, key)
        if not IGNORE[key] then Bind(key) end
    end)
    catcher:SetScript("OnMouseDown", function(_, button)
        if MOUSE[button] then Bind(MOUSE[button]) end -- left/right stay free
    end)
    catcher:SetScript("OnMouseWheel", function(_, delta) Bind(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
    catcher:SetScript("OnLeave", function(self)
        self:Hide()
        self.target, self.command = nil, nil
        GameTooltip:Hide()
    end)
    catcher:Hide()
end

local function OnButtonEnter(button)
    if not active or InCombatLockdown() or not hooked[button] then return end
    catcher.target, catcher.command = button, hooked[button]
    catcher:ClearAllPoints()
    catcher:SetAllPoints(button)
    catcher:Show()
    ShowTooltip()
end

local function Hook(button, command)
    if not button or hooked[button] then return end
    hooked[button] = command
    button:HookScript("OnEnter", OnButtonEnter)
end

-- All bindable buttons: MUI bars, Blizzard's pet, stance and extra buttons
local function HookButtons()
    for _, bar in ipairs(ns.actionBars or {}) do
        for i, button in ipairs(bar.buttons) do Hook(button, bar.def.binding .. i) end
    end
    for i = 1, 10 do
        Hook(_G["PetActionButton" .. i], "BONUSACTIONBUTTON" .. i)
        Hook(_G["StanceButton" .. i], "SHAPESHIFTBUTTON" .. i)
    end
    Hook(_G.ExtraActionButton1, "EXTRAACTIONBUTTON1")
end

-- Small checkbox in MUI look
local function Checkbox(parent, label, onClick)
    local UI = ns.UI
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(ns.Snap(16), ns.Snap(16))
    local bg = UI.Box(button)
    local check = UI.Icon(button, "Check", 14, UI.ACCENT)
    check:SetPoint("CENTER")
    local text = UI.Text(parent, 12, "LEFT")
    text:SetPoint("LEFT", button, "RIGHT", 8, 0)
    text:SetText(label)
    function button:SetChecked(value) self.checked = value; check:SetShown(value) end
    button:SetScript("OnEnter", function() bg:SetColorTexture(unpack(UI.HOVER)) end)
    button:SetScript("OnLeave", function() bg:SetColorTexture(unpack(UI.FIELD)) end)
    button:SetScript("OnClick", function(self) self:SetChecked(not self.checked); if onClick then onClick(self.checked) end end)
    return button
end

local Stop

local function CreatePanel()
    local UI = ns.UI
    panel = CreateFrame("Frame", "MeredanUIKeyBindPanel", UIParent)
    panel:SetSize(ns.Snap(280), ns.Snap(142))
    panel:SetPoint("TOP", UIParent, "TOP", 0, -ns.Snap(120))
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    UI.Box(panel, { 0.05, 0.05, 0.06, 0.97 })

    local title = UI.Title(panel, 14, "LEFT")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(L["Key bindings"])
    local close = UI.IconButton(panel, "Close", function() Stop(false) end, 20)
    close:SetPoint("TOPRIGHT", -8, -8)

    local hint = UI.Text(panel, 12, "LEFT", UI.MUTED)
    hint:SetPoint("TOPLEFT", 12, -36)
    hint:SetPoint("RIGHT", -12, 0)
    hint:SetText(L["Hover a button and press a key."] .. "\n" .. L["Esc clears the binding."])

    panel.perCharacter = Checkbox(panel, L["Only for this character"])
    panel.perCharacter:SetPoint("TOPLEFT", 12, -78)

    local save = UI.Button(panel, L["Save"], function() Stop(true) end, 122)
    save:SetPoint("BOTTOMLEFT", 12, 12)
    local discard = UI.Button(panel, L["Discard"], function() Stop(false) end, 122)
    discard:SetPoint("BOTTOMRIGHT", -12, 12)
    panel:Hide()
end

function Stop(save)
    if not active then return end
    active = false
    if save then
        SaveBindings(panel.perCharacter.checked and CHARACTER or ACCOUNT)
        ns.Print(L["Key bindings saved."])
    elseif dirty then
        LoadBindings(GetCurrentBindingSet()) -- discard changes
        ns.Print(L["Key binding changes discarded."])
    end
    dirty = false
    panel:Hide()
    catcher:Hide()
    GameTooltip:Hide()
end

local function Start()
    if InCombatLockdown() then return ns.Print(L["Not possible in combat."]) end
    if active then return Stop(false) end
    if not panel then CreatePanel(); CreateCatcher() end
    HookButtons()
    active, dirty = true, false
    panel.perCharacter:SetChecked(GetCurrentBindingSet() == CHARACTER)
    panel:Show()
end
ns.ToggleKeyBind = Start

-- Combat starts: end the mode, keep changes made so far (saved)
ns:On("PLAYER_REGEN_DISABLED", function() if active then Stop(true) end end)

ns.AddCommand("kb", L["Key bindings: hover a button, press a key"], Start)
SLASH_MEREDANUIKB1 = "/kb"
SlashCmdList["MEREDANUIKB"] = Start
