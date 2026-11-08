-- Need/greed roll frames in mUI style replacing Blizzard's group loot frames. One slim row per
-- roll, stacked downwards:
--
--   +--------------------------------------------------------+
--   |[#] Sword of Slumber      ^ +2.4%   [N][G][D][x]         |  <- need, greed (or transmog),
--   |    Binds when picked up                                |     disenchant (if possible), pass
--   |================================                        |  <- time left in quality color
--   +--------------------------------------------------------+
--
-- Unavailable buttons are dimmed (tooltip gives the reason). Blizzard's frames are reparented to a
-- hidden frame (only the frames, not their container, which is part of Blizzard's layout).
-- Confirmations ("Binds when picked up") are still shown by Blizzard. Settings > Bags.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT = 340, 48
local ICON = 38
local BUTTON = 24
local GAP = 6
local MAX = 6

local holder
local frames = {}
local hidden = CreateFrame("Frame")
hidden:Hide()

local function Enabled() return ns.db.lootRolls ~= false end

-- roll types: RollOnLoot id, icon, label
local ROLLS = {
    need = { id = 1, icon = "RollNeed", label = NEED or "Need" },
    greed = { id = 2, icon = "Gold", label = GREED or "Greed" },
    transmog = { id = 4, icon = "RollTransmog", label = TRANSMOGRIFICATION or "Transmog" },
    disenchant = { id = 3, icon = "RollDisenchant", label = ROLL_DISENCHANT or "Disenchant" },
    pass = { id = 0, icon = "Close", label = PASS or "Pass" },
}

local function QualityColor(quality)
    local r, g, b = C_Item.GetItemQualityColor(quality or Enum.ItemQuality.Common)
    return r or 1, g or 1, b or 1
end

-- Button -----------------------------------------------------------------------------------

local function ButtonEnter(button)
    button.icon:SetVertexColor(unpack(ns.UI.ACCENT))
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.kind.label, 1, 1, 1)
    if button.reason then GameTooltip:AddLine(button.reason, 1, 0.3, 0.3, true) end
    GameTooltip:Show()
end

local function ButtonLeave(button)
    button.icon:SetVertexColor(unpack(ns.UI.TEXT))
    GameTooltip:Hide()
end

local function ButtonClick(button)
    local frame = button:GetParent()
    if frame.demo or not frame.rollID then return end
    RollOnLoot(frame.rollID, button.kind.id)
end

local function CreateButton(frame, kind)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(ns.Snap(BUTTON), ns.Snap(BUTTON))
    button.kind = kind
    button.icon = ns.UI.Icon(button, kind.icon, BUTTON - 4, ns.UI.TEXT)
    button.icon:SetPoint("CENTER")
    button:SetScript("OnEnter", ButtonEnter)
    button:SetScript("OnLeave", ButtonLeave)
    button:SetScript("OnClick", ButtonClick)
    return button
end

local function SetButtonEnabled(button, enabled, reasonIndex)
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or 0.3)
    button.reason = not enabled and reasonIndex and _G["LOOT_ROLL_INELIGIBLE_REASON" .. reasonIndex] or nil
end

-- Row --------------------------------------------------------------------------------------

local function IconEnter(iconFrame)
    local frame = iconFrame:GetParent()
    GameTooltip:SetOwner(iconFrame, "ANCHOR_RIGHT")
    if frame.demo then
        GameTooltip:SetItemByID(frame.demo)
    else
        GameTooltip:SetLootRollItem(frame.rollID)
    end
    ns.ShowItemCompare(GameTooltip)
    GameTooltip:Show()
    iconFrame.UpdateTooltip = IconEnter -- refresh when Shift changes while hovering
end

local function CreateFrameRow(index)
    local frame = CreateFrame("Frame", nil, holder)
    frame:SetSize(ns.Snap(WIDTH), ns.Snap(HEIGHT))
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddBorder(frame)

    frame.iconFrame = CreateFrame("Button", nil, frame)
    frame.iconFrame:SetSize(ns.Snap(ICON), ns.Snap(ICON))
    frame.iconFrame:SetPoint("LEFT", 5, 0)
    frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.border = ns.AddBorder(frame.iconFrame)
    frame.count = ns.CreateText(frame.iconFrame, 12, "RIGHT", "OUTLINE")
    frame.count:SetPoint("BOTTOMRIGHT", -1, 2)
    frame.iconFrame:SetScript("OnEnter", IconEnter)
    frame.iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.iconFrame:SetScript("OnClick", function()
        local link = frame.demo and select(2, C_Item.GetItemInfo(frame.demo)) or (frame.rollID and GetLootRollItemLink(frame.rollID))
        if link and IsModifiedClick() then HandleModifiedItemClick(link) end
    end)

    -- buttons on the right, pass outermost
    frame.buttons = {}
    for _, key in ipairs({ "pass", "disenchant", "greed", "transmog", "need" }) do
        frame.buttons[key] = CreateButton(frame, ROLLS[key])
    end

    frame.name = ns.CreateText(frame, 13, "LEFT")
    frame.name:SetPoint("TOPLEFT", frame.iconFrame, "TOPRIGHT", 8, -3)
    frame.name:SetWordWrap(false)
    frame.info = ns.UI.Text(frame, 11, "LEFT", ns.UI.MUTED)
    frame.info:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -3)
    frame.upgrade = ns.UI.Icon(frame, "Upgrade", 14, ns.UPGRADE_COLOR or ns.UI.ACCENT)

    frame.timer = CreateFrame("StatusBar", nil, frame)
    frame.timer:SetPoint("BOTTOMLEFT", 1, 1)
    frame.timer:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.timer:SetHeight(ns.Snap(3))
    frame.timer:SetStatusBarTexture(ns.STYLE.barTexture or "Interface\\Buttons\\WHITE8X8")
    frame.timer:SetScript("OnUpdate", function(bar, elapsed)
        if frame.demo then
            frame.demoLeft = math.max((frame.demoLeft or 0) - elapsed, 0)
            bar:SetValue(frame.demoLeft)
        elseif frame.rollID then
            bar:SetValue(GetLootRollTimeLeft(frame.rollID) or 0)
        end
    end)

    frames[index] = frame
    return frame
end

-- lay out visible buttons (greed OR transmog, disenchant optional)
local function LayoutButtons(frame)
    local order = { "pass" }
    if frame.buttons.disenchant:IsShown() then order[#order + 1] = "disenchant" end
    order[#order + 1] = frame.buttons.transmog:IsShown() and "transmog" or "greed"
    order[#order + 1] = "need"
    local previous
    for _, key in ipairs(order) do
        local button = frame.buttons[key]
        button:ClearAllPoints()
        if previous then
            button:SetPoint("RIGHT", previous, "LEFT", -ns.Snap(GAP), 0)
        else
            button:SetPoint("RIGHT", -6, 2)
        end
        previous = button
    end
    frame.name:SetPoint("RIGHT", previous, "LEFT", -8, 0)
    frame.upgrade:ClearAllPoints()
    frame.upgrade:SetPoint("RIGHT", previous, "LEFT", -6, 0)
end

local function Fill(frame, data)
    frame.icon:SetTexture(data.texture)
    frame.name:SetText(data.name or "")
    local r, g, b = QualityColor(data.quality)
    frame.name:SetTextColor(r, g, b)
    for _, edge in ipairs(frame.border) do edge:SetVertexColor(r, g, b, 1) end
    frame.timer:SetStatusBarColor(r, g, b)
    frame.timer:SetMinMaxValues(0, data.duration or 60000)
    frame.count:SetText(data.count and data.count > 1 and data.count or "")
    frame.info:SetText(data.bindOnPickUp and (ITEM_BIND_ON_PICKUP or "Binds when picked up") or "")

    SetButtonEnabled(frame.buttons.need, data.canNeed, data.reasonNeed)
    frame.buttons.transmog:SetShown(data.canTransmog and true or false)
    frame.buttons.greed:SetShown(not data.canTransmog)
    SetButtonEnabled(frame.buttons.greed, data.canGreed, data.reasonGreed)
    frame.buttons.disenchant:SetShown(data.canDisenchant and true or false)
    SetButtonEnabled(frame.buttons.pass, true)
    LayoutButtons(frame)

    local upgrade = data.link and ns.UpgradePercent and ns.UpgradePercent(data.link)
    frame.upgrade:SetShown(upgrade and upgrade >= 0.05 or false)
end

local function Restack()
    local y = 0
    for _, frame in ipairs(frames) do
        if frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("TOP", holder, "TOP", 0, -y)
            y = y + ns.Snap(HEIGHT) + ns.Snap(4)
        end
    end
end

local function FreeFrame()
    for _, frame in ipairs(frames) do
        if not frame:IsShown() then return frame end
    end
    if #frames < MAX then return CreateFrameRow(#frames + 1) end
end

-- Rolls ------------------------------------------------------------------------------------

local function AddRoll(rollID, duration)
    for _, frame in ipairs(frames) do
        if frame:IsShown() and frame.rollID == rollID then return end
    end
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed,
        reasonGreed, _, _, canTransmog = GetLootRollItemInfo(rollID)
    if not name then return end
    local frame = FreeFrame()
    if not frame then return end
    frame.rollID, frame.demo = rollID, nil
    Fill(frame, {
        texture = texture, name = name, count = count, quality = quality, bindOnPickUp = bindOnPickUp,
        canNeed = canNeed, canGreed = canGreed, canDisenchant = canDisenchant, canTransmog = canTransmog,
        reasonNeed = reasonNeed, reasonGreed = reasonGreed, duration = duration,
        link = GetLootRollItemLink(rollID),
    })
    frame:Show()
    Restack()
end

local function RemoveRoll(rollID)
    for _, frame in ipairs(frames) do
        if frame.rollID == rollID and not frame.demo then
            frame:Hide()
            frame.rollID = nil
        end
    end
    Restack()
end

local function RemoveAll()
    for _, frame in ipairs(frames) do
        if not frame.demo then frame:Hide(); frame.rollID = nil end
    end
    Restack()
end

-- hide Blizzard's frames (only the frames; their container stays in Blizzard's layout)
local function HideBlizzard()
    for i = 1, 4 do
        local frame = _G["GroupLootFrame" .. i]
        if frame then frame:SetParent(hidden) end
    end
end

-- Test mode (/mui t): two sample rolls ------------------------------------------------------

local DEMO = {
    { item = 19019, quality = Enum.ItemQuality.Legendary, canNeed = true, canGreed = true, bindOnPickUp = true },
    { item = 16795, quality = Enum.ItemQuality.Epic, canNeed = false, canGreed = true, canDisenchant = true, reasonNeed = 1 },
}

function ns.LootRollTestStart()
    if not holder or not Enabled() then return end
    for _, demo in ipairs(DEMO) do
        local frame = FreeFrame()
        if not frame then break end
        frame.rollID, frame.demo, frame.demoLeft = nil, demo.item, 60
        Fill(frame, {
            texture = C_Item.GetItemIconByID(demo.item), name = C_Item.GetItemNameByID(demo.item) or L["Example item"],
            quality = demo.quality, count = 1, bindOnPickUp = demo.bindOnPickUp, canNeed = demo.canNeed,
            canGreed = demo.canGreed, canDisenchant = demo.canDisenchant, reasonNeed = demo.reasonNeed, duration = 60,
        })
        frame:Show()
    end
    Restack()
end

function ns.LootRollTestStop()
    for _, frame in ipairs(frames) do
        if frame.demo then frame:Hide(); frame.demo = nil end
    end
    Restack()
end

-- Setup ------------------------------------------------------------------------------------

-- top center in the upper third, stacks downwards
local function PlaceDefault()
    local _, cy = UIParent:GetCenter()
    ns.PlaceFromCenter(holder, "TOP", 0, cy * 0.55)
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() then return end
    holder = CreateFrame("Frame", "MeredanUILootRolls", UIParent)
    holder:SetSize(ns.Snap(WIDTH), ns.Snap(HEIGHT))
    holder:SetFrameStrata("HIGH")
    ns.layoutFrames.lootroll = holder
    ns.OnLayout(PlaceDefault)
    PlaceDefault()
    HideBlizzard()
    for _, demo in ipairs(DEMO) do C_Item.RequestLoadItemDataByID(demo.item) end -- preload names for the demo

    ns:On("START_LOOT_ROLL", function(_, rollID, duration) AddRoll(rollID, duration) end)
    ns:On("CANCEL_LOOT_ROLL", function(_, rollID) RemoveRoll(rollID) end)
    ns:On("CANCEL_ALL_LOOT_ROLLS", RemoveAll)
    -- rolls already in progress (e.g. after /reload)
    for _, rollID in ipairs(GetActiveLootRollIDs and GetActiveLootRollIDs() or {}) do
        AddRoll(rollID, C_Loot.GetLootRollDuration(rollID))
    end
end)
