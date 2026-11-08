-- AFK "cinema" screen: while AFK, black letterbox bars slide in, the UI fades out and the camera
-- slowly circles the character like a cutscene. Ends on movement (AFK ends), click or combat.
-- Settings > Appearance.
--
--   +----------------------------------------------------------+
--   |          GOLDSHIRE - ELWYNN FOREST           2 whispers  |  <- top bar
--   +----------------------------------------------------------+
--   |                 (game world, camera circles)             |
--   +----------------------------------------------------------+
--   | MEREDANUI          Meredan                        21:42  |  <- bottom bar
--   |                    Level 80 - Blackrock     AFK for 4:12 |
--   +----------------------------------------------------------+
local _, ns = ...
local L = ns.L

local BAR_RATIO = 0.13     -- height of one bar as a fraction of screen height
local SLIDE_IN, SLIDE_OUT = 1.2, 0.4
local CAMERA_SPEED = 0.02  -- slow, like a camera pan
local MARGIN = 48

local screen, topBar, bottomBar
local clock, since, zone, whisperText, nameText, infoText
local active, startTime, whispers = false, 0, 0
local progress, target = 0, 0 -- 0 = hidden, 1 = fully shown
local ticker

local function Text(parent, size, justify, color, display)
    local text = parent:CreateFontString(nil, "OVERLAY")
    if display then
        text:SetFont(ns.DISPLAY_FONT, size, "")
    else
        ns.SetFont(text, size, "")
    end
    text:SetJustifyH(justify)
    text:SetTextColor(unpack(color or ns.UI.TEXT))
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    return text
end

local function Bar(edge)
    local bar = CreateFrame("Frame", nil, screen)
    local fill = bar:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0, 0, 0, 1)
    -- thin Surf Green line on the inner edge
    local line = bar:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(ns.UI.ACCENT[1], ns.UI.ACCENT[2], ns.UI.ACCENT[3], 0.6)
    line:SetHeight(ns.PixelSize())
    line:SetPoint(edge == "TOP" and "BOTTOMLEFT" or "TOPLEFT")
    line:SetPoint(edge == "TOP" and "BOTTOMRIGHT" or "TOPRIGHT")
    return bar
end

local function FormatSince(seconds)
    seconds = math.floor(seconds)
    if seconds >= 3600 then
        return ("%d:%02d:%02d"):format(seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    end
    return ("%d:%02d"):format(seconds / 60, seconds % 60)
end

local function UpdateTexts()
    clock:SetText(date("%H:%M"))
    since:SetText(L["AFK for %s"]:format(FormatSince(GetTime() - startTime)))
    if whispers > 0 then
        whisperText:SetText(whispers == 1 and L["1 whisper"] or L["%d whispers"]:format(whispers))
        whisperText:Show()
    else
        whisperText:Hide()
    end
end

-- bars slide in/out while the UI fades the opposite way
local function Layout()
    local height = screen:GetHeight() * BAR_RATIO
    topBar:SetHeight(height)
    bottomBar:SetHeight(height)
    local eased = 1 - (1 - progress) ^ 3 -- ease out
    topBar:ClearAllPoints()
    topBar:SetPoint("BOTTOMLEFT", screen, "TOPLEFT", 0, -height * eased)
    topBar:SetPoint("BOTTOMRIGHT", screen, "TOPRIGHT", 0, -height * eased)
    bottomBar:ClearAllPoints()
    bottomBar:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, height * eased)
    bottomBar:SetPoint("TOPRIGHT", screen, "BOTTOMRIGHT", 0, height * eased)
    UIParent:SetAlpha((ns.RPModeAlpha and ns.RPModeAlpha() or 1) * (1 - progress)) -- respect RP mode alpha
end

local function OnUpdate(_, elapsed)
    local speed = target > progress and 1 / SLIDE_IN or 1 / SLIDE_OUT
    if target > progress then
        progress = math.min(target, progress + elapsed * speed)
    else
        progress = math.max(target, progress - elapsed * speed)
    end
    Layout()
    if progress == target then
        screen:SetScript("OnUpdate", nil)
        if progress == 0 then screen:Hide() end
    end
end

local function Create()
    -- parented to WorldFrame since UIParent gets faded out; scaled like the UI
    screen = CreateFrame("Frame", "MeredanUIAFKScreen", WorldFrame)
    screen:SetFrameStrata("FULLSCREEN")
    screen:SetScale(UIParent:GetScale())
    screen:SetAllPoints(UIParent)
    screen:EnableMouse(true)
    screen:Hide()

    topBar, bottomBar = Bar("TOP"), Bar("BOTTOM")

    -- top: zone centered, whispers right
    zone = Text(topBar, 16, "CENTER", ns.UI.MUTED, true)
    zone:SetPoint("CENTER", 0, 0)
    whisperText = Text(topBar, 14, "RIGHT", ns.UI.ACCENT)
    whisperText:SetPoint("RIGHT", -MARGIN, 0)

    -- bottom left: logo
    local logo = Text(bottomBar, 34, "LEFT", { 0.914, 0.902, 0.867 }, true)
    logo:SetPoint("LEFT", MARGIN, 0)
    logo:SetText("Meredan")
    local logoUI = Text(bottomBar, 34, "LEFT", ns.UI.ACCENT, true)
    logoUI:SetPoint("LEFT", logo, "RIGHT", 2, 0)
    logoUI:SetText("UI")

    -- bottom center: character
    nameText = Text(bottomBar, 22, "CENTER")
    nameText:SetPoint("BOTTOM", bottomBar, "CENTER", 0, 2)
    infoText = Text(bottomBar, 13, "CENTER", ns.UI.MUTED)
    infoText:SetPoint("TOP", bottomBar, "CENTER", 0, -4)

    -- bottom right: clock and AFK time
    clock = Text(bottomBar, 34, "RIGHT", nil, true)
    clock:SetPoint("BOTTOMRIGHT", bottomBar, "RIGHT", -MARGIN, -2)
    since = Text(bottomBar, 13, "RIGHT", ns.UI.MUTED)
    since:SetPoint("TOPRIGHT", bottomBar, "RIGHT", -MARGIN, -6)

    -- click hides the screen (AFK stays until the player moves)
    screen:SetScript("OnMouseDown", function() ns.StopAFKScreen() end)
end

local function FillCharacter()
    local name = UnitName("player")
    local _, class = UnitClass("player")
    local color = RAID_CLASS_COLORS[class]
    nameText:SetText(name)
    if color then nameText:SetTextColor(color.r, color.g, color.b) end
    local info = L["Level %d"]:format(UnitLevel("player"))
    local guild = GetGuildInfo("player")
    if guild then info = info .. " · " .. guild end
    infoText:SetText(info)
    local subzone, mainZone = GetSubZoneText(), GetRealZoneText()
    zone:SetText((subzone ~= "" and subzone ~= mainZone) and (subzone .. " · " .. mainZone) or mainZone)
end

local function Start()
    if active or ns.db.afkScreen == false or InCombatLockdown() then return end
    if MovieFrame and MovieFrame:IsShown() then return end
    if not screen then Create() end
    active, startTime, whispers = true, GetTime(), 0
    FillCharacter()
    UpdateTexts()
    ticker = C_Timer.NewTicker(1, UpdateTexts)
    screen:SetScale(UIParent:GetScale())
    screen:Show()
    target = 1
    screen:SetScript("OnUpdate", OnUpdate)
    MoveViewLeftStart(CAMERA_SPEED)
end

function ns.StopAFKScreen(instant)
    if not active then return end
    active = false
    if ticker then ticker:Cancel() ticker = nil end
    MoveViewLeftStop()
    target = 0
    if instant then -- combat: restore the UI immediately
        progress = 0
        Layout()
        screen:SetScript("OnUpdate", nil)
        screen:Hide()
    else
        screen:SetScript("OnUpdate", OnUpdate)
    end
end

ns:On("PLAYER_FLAGS_CHANGED", function(_, unit)
    if unit ~= "player" then return end
    if UnitIsAFK("player") then Start() else ns.StopAFKScreen() end
end)
ns:On("PLAYER_REGEN_DISABLED", function() ns.StopAFKScreen(true) end)
ns:On("PLAYER_LEAVING_WORLD", function() ns.StopAFKScreen(true) end)
for _, event in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do
    ns:On(event, function()
        if not active then return end
        whispers = whispers + 1
        UpdateTexts()
    end)
end
