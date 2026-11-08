-- Ready check (WoW Forever) as a mUI window replacing Blizzard's ReadyCheckFrame.
-- Same position as Blizzard's (screen center), styled like the confirmation dialogs:
--
--   +----------------------------------------------+  <- Surf Green edge
--   | [Portrait]  Ready Check                      |
--   |             Koratal has initiated a ready    |
--   |             check. Are you ready?            |
--   | ==============================.........      |  <- time left
--   |        [ Ready ]    [ Not Ready ]            |
--   +----------------------------------------------+
--
-- Blizzard's frame stays parked invisibly so it keeps its events (e.g. the "You were away" chat
-- line). Answers like Blizzard's buttons: ConfirmReadyCheck + hide Blizzard's frame.
local _, ns = ...
local L = ns.L

local WIDTH, PAD, PORTRAIT = 360, 18, 46

local hidden = CreateFrame("Frame")
hidden:Hide()

local window, portrait, title, text, bar, readyButton, notReadyButton
local demo = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.readyCheckWindow ~= false
end

-- Name in class color (initiator is a unit or a name)
local function ColoredName(initiator)
    local name = initiator and UnitName(initiator) or initiator or ""
    local _, class = UnitClass(initiator or "")
    local color = class and RAID_CLASS_COLORS[class]
    return color and color:WrapTextInColorCode(name) or name
end

-- like Blizzard: in instances with switchable difficulty, append the difficulty
local function Message(initiator)
    local message = (READY_CHECK_MESSAGE or "%s"):format(ColoredName(initiator))
    local _, _, difficultyID = GetInstanceInfo()
    if not difficultyID or difficultyID == 0 then
        difficultyID = UnitInRaid("player") and GetRaidDifficultyID() or GetDungeonDifficultyID()
    end
    if difficultyID then
        local difficultyName, _, _, _, _, _, toggleID = GetDifficultyInfo(difficultyID)
        if toggleID and toggleID > 0 and difficultyName then
            message = message .. "\n|cff999890" .. (RAID_DIFFICULTY or "") .. ": " .. difficultyName .. "|r"
        end
    end
    return message
end

local function Answer(isReady)
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if not demo then
        C_PartyInfo.ConfirmReadyCheck(isReady)
        if ReadyCheckFrame then ReadyCheckFrame:Hide() end
    end
    window:Hide()
end

local function Button(label, accent, onClick)
    local UI = ns.UI
    local button = UI.Button(window, label, onClick, 140)
    button:SetHeight(28)
    if accent then
        for _, edge in ipairs(ns.AddBorder(button, true)) do edge:SetVertexColor(unpack(UI.ACCENT)) end
    end
    return button
end

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIReadyCheck", UIParent)
    window:SetSize(WIDTH, 150)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, -10) -- Blizzard's position
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetClampedToScreen(true)
    window:Hide()
    UI.Box(window, ns.STYLE.panelColor)
    local accent = window:CreateTexture(nil, "OVERLAY")
    accent:SetColorTexture(unpack(UI.ACCENT))
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2 * ns.PixelSize())

    local holder = CreateFrame("Frame", nil, window)
    holder:SetSize(PORTRAIT, PORTRAIT)
    holder:SetPoint("TOPLEFT", PAD, -PAD)
    ns.AddSlotBackground(holder)
    ns.AddBorder(holder)
    portrait = holder:CreateTexture(nil, "ARTWORK")
    portrait:SetAllPoints()
    portrait:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    title = UI.Text(window, 15, "LEFT")
    ns.SetFont(title, 15, "", "bold")
    title:SetPoint("TOPLEFT", holder, "TOPRIGHT", 14, -2)
    title:SetPoint("RIGHT", -PAD, 0)
    title:SetText(READY_CHECK or L["Ready check"])
    text = UI.Text(window, 13, "LEFT")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    text:SetPoint("RIGHT", -PAD, 0)
    text:SetWordWrap(true)
    text:SetSpacing(3)

    -- Time left: thin Surf Green bar that drains
    bar = CreateFrame("StatusBar", nil, window)
    bar:SetHeight(6)
    bar:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(unpack(UI.ACCENT))
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0.04, 0.04, 0.05, 1)
    ns.AddBorder(bar)
    bar:SetScript("OnUpdate", function(self)
        if not self.ends then return end
        local left = self.ends - GetTime()
        self:SetValue(math.max(left, 0))
        if left <= 0 then self.ends = nil end
    end)

    readyButton = Button(GetText("READY", UnitSex("player")) or READY, true, function() Answer(true) end)
    notReadyButton = Button(GetText("NOT_READY", UnitSex("player")) or NOT_READY, false, function() Answer(false) end)
    readyButton:SetPoint("BOTTOMRIGHT", window, "BOTTOM", -5, PAD)
    notReadyButton:SetPoint("BOTTOMLEFT", window, "BOTTOM", 5, PAD)
    bar:SetPoint("BOTTOMLEFT", PAD, PAD + 28 + 14)
    bar:SetPoint("BOTTOMRIGHT", -PAD, PAD + 28 + 14)

    window:SetScript("OnHide", function() demo = false end)
end

-- Height by text length (difficulty = second line)
local function Fit()
    local textBottom = PAD + 2 + title:GetStringHeight() + 6 + text:GetStringHeight()
    local top = math.max(PAD + PORTRAIT, textBottom) + 16
    window:SetHeight(math.floor(top + 6 + 14 + 28 + PAD + 0.5))
end

local function Show(initiator, timeLeft)
    if not window then CreateWindow() end
    SetPortraitTexture(portrait, initiator)
    text:SetText(Message(initiator))
    local duration = tonumber(timeLeft) or 35
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(duration)
    bar.ends = GetTime() + duration
    window:Show()
    Fit() -- measure while shown (hidden font strings sometimes measure 0)
    PlaySound(SOUNDKIT.READY_CHECK)
    if FlashClientIcon then FlashClientIcon() end
end

-- Preview (/mui t): window with the own character as initiator, buttons do nothing
ns.ReadyCheckDemo = {
    Start = function()
        if not Enabled() then return end
        Show("player", 35)
        demo = true
    end,
    Stop = function() if window and demo then window:Hide() end end,
    IsActive = function() return demo end,
}

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not ReadyCheckFrame then return end
    ReadyCheckFrame:SetParent(hidden) -- park invisibly, events keep running
    ns:On("READY_CHECK", function(_, initiator, timeLeft)
        if not initiator or UnitIsUnit("player", initiator) then return end -- started by ourselves: no window
        Show(initiator, timeLeft)
    end)
    local function Close()
        if window and window:IsShown() and not demo then window:Hide() end
    end
    ns:On("READY_CHECK_FINISHED", Close)
    ns:On("GROUP_LEFT", Close)
    -- answered elsewhere (e.g. via the group frames): close the window
    ns:On("READY_CHECK_CONFIRM", function(_, unit)
        if unit and UnitIsUnit(unit, "player") then Close() end
    end)
end)
