-- Queue status (group finder listing, applications, battlegrounds ...) as sticky entries on top of the
-- toast stack instead of Blizzard's eye at the minimap. Shows directly what the eye's hover shows:
--
--   [eye]  Listed - 2 pending applicants      12 min   <- status, time in queue
--          Deadmines, Wailing Caverns                  <- title
--
-- Content is read from Blizzard's own QueueStatusFrame entries after each of its updates, so every
-- queue type Blizzard knows shows up exactly as in its tooltip. The eye (QueueStatusButton, an Edit
-- Mode system) is never moved, only made invisible; clicks on our entry are passed to it
-- (left: open group finder / scoreboard, right: Blizzard's queue menu). Hovering shows Blizzard's
-- detailed tooltip next to the entry (role counts etc.).
local _, ns = ...

local entries, used = {}, 0
local ticker
local hooked = false

local function Enabled()
    return ns.IS_FOREVER and ns.db and ns.db.toasts ~= false
end

local function HideEye(hide)
    local eye = _G.QueueStatusButton
    if not eye then return end
    eye:SetAlpha(hide and 0 or 1)
    eye:EnableMouse(not hide)
end

local function TimeText(queuedTime)
    if not queuedTime then return "" end
    local elapsed = GetTime() - queuedTime
    if elapsed < 60 then return "<" .. SecondsToTime(60, true, false, 1) end
    return SecondsToTime(elapsed, true, false, 1)
end

local function CreateEntry()
    local UI = ns.UI
    local holder = ns.ToastHolder
    local entry = CreateFrame("Button", nil, holder)
    entry:SetSize(ns.Snap(ns.TOAST_WIDTH), ns.Snap(ns.TOAST_HEIGHT))
    entry:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local bg = entry:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    local gradient = entry:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetAllPoints()
    gradient:SetColorTexture(1, 1, 1, 1)
    local a = UI.ACCENT
    gradient:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], 0.3), CreateColor(a[1], a[2], a[3], 0))
    ns.AddBorder(entry)
    -- Surf Green stripe on the left: marks the entry as permanent (not a fading toast)
    local stripe = entry:CreateTexture(nil, "OVERLAY")
    stripe:SetColorTexture(a[1], a[2], a[3], 1)
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT")
    stripe:SetWidth(2 * ns.PixelSize())

    local size = ns.Snap(ns.TOAST_HEIGHT - 8)
    local box = CreateFrame("Frame", nil, entry)
    box:SetSize(size, size)
    box:SetPoint("LEFT", ns.Snap(4), 0)
    ns.AddSlotBackground(box)
    ns.AddBorder(box, true)
    local icon = UI.Icon(box, "LFG", size - 10, UI.ACCENT)
    icon:SetPoint("CENTER")

    entry.time = entry:CreateFontString(nil, "OVERLAY")
    entry.time:SetFont(ns.STYLE.font, ns.FontPx(11), "OUTLINE")
    entry.time:SetTextColor(unpack(UI.MUTED))
    entry.time:SetPoint("TOPRIGHT", -ns.Snap(8), -ns.Snap(6))
    entry.status = entry:CreateFontString(nil, "OVERLAY")
    entry.status:SetFont(ns.STYLE.font, ns.FontPx(10), "OUTLINE")
    entry.status:SetTextColor(unpack(UI.MUTED))
    entry.status:SetPoint("TOPLEFT", box, "TOPRIGHT", ns.Snap(8), -1)
    entry.status:SetPoint("RIGHT", entry.time, "LEFT", -ns.Snap(6), 0)
    entry.status:SetJustifyH("LEFT")
    entry.status:SetWordWrap(false)
    entry.title = entry:CreateFontString(nil, "OVERLAY")
    entry.title:SetFont(ns.STYLE.font, ns.FontPx(13), "OUTLINE")
    entry.title:SetTextColor(unpack(UI.TEXT))
    entry.title:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", ns.Snap(8), 1)
    entry.title:SetPoint("RIGHT", -ns.Snap(8), 0)
    entry.title:SetJustifyH("LEFT")
    entry.title:SetWordWrap(false)

    local function Enter()
        local tip = _G.QueueStatusFrame
        if not tip then return end
        tip:ClearAllPoints()
        tip:SetPoint("TOPLEFT", entry, "TOPRIGHT", ns.Snap(6), 0)
        tip:Show()
    end
    local function Leave()
        if _G.QueueStatusFrame then _G.QueueStatusFrame:Hide() end
    end
    entry:SetScript("OnEnter", Enter)
    entry:SetScript("OnLeave", Leave)
    -- Clicks go through a secure button that clicks Blizzard's eye: a click forwarded by addon code
    -- taints Blizzard's menu (e.g. "Unlist my group" -> C_LFGList.Search blocked). The catcher sits on
    -- UIParent at absolute coordinates (anchoring it to the toast holder would make the holder protected)
    -- and is re-synced out of combat.
    entry.muiEnter, entry.muiLeave = Enter, Leave
    return entry
end

-- Listings in the vanilla-style group finder often have no name: name the activities instead
local function ActivityNames()
    local info = C_LFGList.GetActiveEntryInfo and C_LFGList.GetActiveEntryInfo()
    local ids = info and info.activityIDs
    if not ids or #ids == 0 then return nil end
    local names = {}
    for i = 1, math.min(#ids, 2) do
        local activity = C_LFGList.GetActivityInfoTable(ids[i])
        local name = activity and (activity.shortName ~= "" and activity.shortName or activity.fullName)
        if name and name ~= "" then names[#names + 1] = name end
    end
    local text = table.concat(names, ", ")
    if #ids > 2 then text = text .. " +" .. (#ids - 2) end
    return text ~= "" and text or nil
end

local function Shown(region)
    return region and region:IsShown() and region:GetText() and region:GetText() ~= ""
end

local function UpdateTimes()
    local any = false
    for i = 1, used do
        local entry = entries[i]
        if entry.queuedTime then
            entry.time:SetText(TimeText(entry.queuedTime))
            any = true
        end
    end
    if not any and ticker then ticker:Cancel() ticker = nil end
end

local sorted = {}
local function ByOrder(a, b)
    if (a.active and true or false) ~= (b.active and true or false) then return a.active and true or false end
    return (a.orderIndex or 0) < (b.orderIndex or 0)
end

local rows = {}
local demo, demoStart = false, 0

-- Blizzard's entries -> plain rows { title, line, queuedTime }
local function CollectRows()
    for _, row in ipairs(rows) do row.title, row.line, row.queuedTime = nil, nil, nil end
    local count = 0
    local frame = _G.QueueStatusFrame
    wipe(sorted)
    if frame and frame.statusEntriesPool and _G.QueueStatusButton and _G.QueueStatusButton:IsShown() then
        for blizz in frame.statusEntriesPool:EnumerateActive() do sorted[#sorted + 1] = blizz end
        table.sort(sorted, ByOrder)
    end
    for _, blizz in ipairs(sorted) do
        count = count + 1
        local row = rows[count] or {}
        rows[count] = row
        local title = blizz.Title and blizz.Title:GetText() or ""
        local status = Shown(blizz.Status) and blizz.Status:GetText() or nil
        local sub = Shown(blizz.SubTitle) and blizz.SubTitle:GetText() or nil
        if title == "" and status == QUEUED_STATUS_LISTED then title = ActivityNames() or "" end
        local line = status
        if sub then line = line and (line .. " · " .. sub) or sub end
        row.line = line or QUEUED_STATUS_IN_PROGRESS or ""
        row.title = title ~= "" and title or (status or "")
        -- queuedTime survives pool reuse on Blizzard's side: only trust it while the time line shows
        row.queuedTime = blizz.TimeInQueue and blizz.TimeInQueue:IsShown() and blizz.queuedTime or nil
    end
    if count == 0 and demo then
        count = 1
        rows[1] = rows[1] or {}
        rows[1].title = ns.L["Deadmines, Wailing Caverns"]
        rows[1].line = (QUEUED_STATUS_LISTED or "Listed") .. " · " .. (LFG_LIST_PENDING_APPLICANTS or "%d"):format(2)
        rows[1].queuedTime = demoStart
    end
    return count
end

local function MakeCatcher(entry)
    local eye = _G.QueueStatusButton
    if not eye then return end
    local catcher = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    catcher:SetAttribute("type", "click")
    catcher:SetAttribute("clickbutton", eye)
    catcher:SetAttribute("useOnKeyDown", false)
    catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    catcher:SetFrameStrata(entry:GetFrameStrata())
    catcher:SetFrameLevel(entry:GetFrameLevel() + 10)
    catcher:SetScript("OnEnter", entry.muiEnter)
    catcher:SetScript("OnLeave", entry.muiLeave)
    catcher:Hide()
    entry.catcher = catcher
end

local function SyncCatchers()
    if InCombatLockdown() then return end
    local ui = UIParent:GetEffectiveScale()
    for _, entry in ipairs(entries) do
        if not entry.catcher and entry:IsVisible() then MakeCatcher(entry) end
        local c = entry.catcher
        if c then
            if entry:IsVisible() and entry:GetLeft() then
                local k = entry:GetEffectiveScale() / ui
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", entry:GetLeft() * k, entry:GetTop() * k)
                c:SetSize(entry:GetWidth() * k, entry:GetHeight() * k)
                c:Show()
            else
                c:Hide()
            end
        end
    end
end

local syncPending = false
local function QueueSync()
    if syncPending then return end
    syncPending = true
    local function Run() syncPending = false; SyncCatchers() end
    if InCombatLockdown() then ns.AfterCombat(Run) else C_Timer.After(0, Run) end
end

local function Refresh()
    if not Enabled() or not ns.ToastHolder then return end
    if not ns.ToastHolder.muiCatcherHook then
        ns.ToastHolder.muiCatcherHook = true
        hooksecurefunc(ns.ToastHolder, "SetPoint", QueueSync)
    end
    local timed = false
    used = CollectRows()
    for i = 1, used do
        local row = rows[i]
        local entry = entries[i] or CreateEntry()
        entries[i] = entry
        entry.status:SetText(row.line)
        entry.title:SetText(row.title)
        entry.queuedTime = row.queuedTime
        entry.time:SetText(TimeText(row.queuedTime))
        timed = timed or row.queuedTime ~= nil
        entry:ClearAllPoints()
        entry:SetPoint("TOPLEFT", ns.ToastHolder, "TOPLEFT", 0,
            -(i - 1) * (ns.Snap(ns.TOAST_HEIGHT) + ns.Snap(ns.TOAST_GAP)))
        entry:Show()
    end
    for i = used + 1, #entries do entries[i]:Hide() end
    QueueSync()

    if timed and not ticker then ticker = C_Timer.NewTicker(1, UpdateTimes) end
    HideEye(true)

    local reserve = used > 0 and used * (ns.Snap(ns.TOAST_HEIGHT) + ns.Snap(ns.TOAST_GAP)) or 0
    if reserve ~= (ns.toastReserve or 0) then
        ns.toastReserve = reserve
        if ns.ToastRelayout then ns.ToastRelayout() end
    elseif used > 0 and ns.PlaceToastHolder then
        ns.PlaceToastHolder()
    end
end

ns.QueueStatusDemo = {
    Start = function() demo, demoStart = true, GetTime() - 320 Refresh() end,
    Stop = function() demo = false Refresh() end,
    IsActive = function() return demo end,
}

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or hooked then return end
    local frame, eye = _G.QueueStatusFrame, _G.QueueStatusButton
    if not (frame and frame.Update and eye) then return end
    hooked = true
    hooksecurefunc(frame, "Update", function() C_Timer.After(0, Refresh) end)
    eye:HookScript("OnShow", function() C_Timer.After(0, Refresh) end)
    eye:HookScript("OnHide", function() C_Timer.After(0, Refresh) end)
    Refresh()
end)
