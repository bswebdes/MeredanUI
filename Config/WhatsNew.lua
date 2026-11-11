-- "New in mUI": after an update with a big new feature, a small window pages through what's new
-- (picture, title, two sentences), once per account. Again via /mui news.
--
--   +- mUI · New ● ● ○ ------------------ [x] -+
--   |        [ picture 512x256 ]                |
--   |   Dungeon loot                            |
--   |   Click a boss on the dungeon map ...     |
--   +- [Back] ----------------------- [Next] --+
--
-- Pictures: Media/WhatsNew/<name>.blp (512x256), made from screenshots (names and chat blurred).
-- Seen entries: MeredanUIDB.newsSeen[id]. Fresh installs mark everything as seen (nothing is "new").
local _, ns = ...
local L = ns.L

-- Newest last. id stays fixed once released. draft = picture missing: only via /mui news, no popup.
-- setting = ns.db key: the page gets a "Turn on" checkbox (same value as in the settings), apply runs after.
ns.WHATS_NEW = {
    { id = "dungeon-loot", image = "DungeonLoot", title = "Dungeon loot",
      text = "Click a boss on the dungeon map to see its loot with drop chances, filtered for your class." },
    { id = "wishlist", image = "Wishlist", title = "Wishlist",
      text = "Star the loot you want. The wishlist shows where it drops, lets you try it on and ticks it off once you have it." },
    { id = "dungeon-quests", image = "DungeonQuests", title = "Dungeon quests",
      text = "All quests of a dungeon at a glance: done, still open, or where the quest giver stands." },
    { id = "sparkle", image = "Sparkle", title = "Sparkle", setting = "sparkle",
      text = "Herbs, ore, skinnable corpses and quest objects near you glitter in their own colour. Also in the settings under Quests > Helpers.",
      apply = function() if ns.UpdateSparkle then ns.UpdateSparkle() end end },
    { id = "class-quests", image = "ClassQuests", title = "Class quests",
      setting = "classQuestReminder", foreverOnly = true,
      text = "A message tells you when a class quest for a new ability is ready and where it starts. Click it for a map pin. Also in the settings under Quests > Helpers." },
}

local W, H, PIC_W, PIC_H = 600, 500, 512, 256
local window, pages, index

local function Seen()
    MeredanUIDB.newsSeen = MeredanUIDB.newsSeen or {}
    return MeredanUIDB.newsSeen
end

local function Render()
    local UI = ns.UI
    local entry = pages[index]
    window.picture:SetTexture(ns.MEDIA .. "WhatsNew\\" .. entry.image)
    window.title:SetText(L[entry.title])
    window.text:SetText(L[entry.text])
    for i, dot in ipairs(window.dots) do
        dot:SetShown(i <= #pages and #pages > 1)
        dot:SetColorTexture(unpack(i == index and UI.ACCENT or { 1, 1, 1, 0.15 }))
    end
    local setting = entry.setting and not (entry.foreverOnly and not ns.IS_FOREVER) and entry.setting
    window.toggle:SetShown(setting and true or false)
    if setting then window.toggle:SetChecked(ns.db and ns.db[setting] == true) end
    window.back:SetShown(index > 1)
    window.next.Text:SetText(index < #pages and L["Next"] or L["Done"])
end

local function Close() window:Hide() end -- OnHide marks the pages as seen

local function CreateWindow()
    local UI = ns.UI
    window = CreateFrame("Frame", "MeredanUIWhatsNew", UIParent)
    window:SetSize(W, H)
    window:SetPoint("CENTER", 0, 60)
    window:SetFrameStrata("FULLSCREEN_DIALOG") -- above the settings window it can be opened from
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    UI.Box(window, { 0.05, 0.06, 0.06, 0.98 })
    tinsert(UISpecialFrames, "MeredanUIWhatsNew")
    window:SetScript("OnHide", function()
        for _, e in ipairs(pages or {}) do if not e.draft then Seen()[e.id] = true end end
    end)
    local accent = window:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT")
    accent:SetPoint("TOPRIGHT")
    accent:SetHeight(2)
    accent:SetColorTexture(unpack(UI.ACCENT))

    local head = UI.Text(window, 15, "LEFT")
    head:SetPoint("TOPLEFT", 16, -16)
    head:SetText("m|cff8ecbb4UI|r  ·  " .. L["New"])
    window.dots = {}
    for i = 1, 8 do
        local dot = window:CreateTexture(nil, "ARTWORK")
        dot:SetSize(7, 7)
        dot:SetPoint("LEFT", head, "RIGHT", 14 + (i - 1) * 13, 0)
        window.dots[i] = dot
    end
    local close = UI.IconButton(window, "Close", Close, 26)
    close:SetPoint("TOPRIGHT", -10, -10)
    local headLine = window:CreateTexture(nil, "ARTWORK")
    headLine:SetColorTexture(1, 1, 1, 0.08)
    headLine:SetPoint("TOPLEFT", 0, -44)
    headLine:SetPoint("TOPRIGHT", 0, -44)
    headLine:SetHeight(1)

    local frame = CreateFrame("Frame", nil, window)
    frame:SetSize(PIC_W, PIC_H)
    frame:SetPoint("TOP", 0, -62)
    ns.AddBorder(frame)
    window.picture = frame:CreateTexture(nil, "ARTWORK")
    window.picture:SetAllPoints()

    window.title = window:CreateFontString(nil, "OVERLAY")
    window.title:SetFont(ns.DISPLAY_FONT, 20, "")
    window.title:SetTextColor(unpack(UI.TEXT))
    window.title:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -16)
    window.text = UI.Text(window, 13, "LEFT", UI.MUTED)
    window.text:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -8)
    window.text:SetWidth(PIC_W)
    window.text:SetWordWrap(true)

    -- "Turn on" for features that are off after an update; same value as the settings checkbox
    window.toggle = UI.LabelCheck(window, L["Turn on"], function(_, on)
        local entry = pages[index]
        if not (entry and entry.setting and ns.db) then return end
        ns.db[entry.setting] = on
        if entry.apply then entry.apply() end
    end)
    window.toggle:SetPoint("TOPLEFT", window.text, "BOTTOMLEFT", 0, -12)

    local footLine = window:CreateTexture(nil, "ARTWORK")
    footLine:SetColorTexture(1, 1, 1, 0.08)
    footLine:SetPoint("BOTTOMLEFT", 0, 48)
    footLine:SetPoint("BOTTOMRIGHT", 0, 48)
    footLine:SetHeight(1)
    window.back = UI.Button(window, L["Back"], function()
        index = math.max(1, index - 1)
        Render()
    end, 110)
    window.back:SetPoint("BOTTOMLEFT", 12, 12)
    window.next = UI.Button(window, L["Next"], function()
        if index < #pages then
            index = index + 1
            Render()
        else
            Close()
        end
    end, 160)
    window.next:SetPoint("BOTTOMRIGHT", -12, 12)
    window.next.Text:SetTextColor(unpack(UI.ACCENT))
end

-- Settings button badge: newest entry not opened via the button yet
local function Newest()
    for i = #ns.WHATS_NEW, 1, -1 do if not ns.WHATS_NEW[i].draft then return ns.WHATS_NEW[i].id end end
end
function ns.WhatsNewUnopened() return Newest() ~= nil and MeredanUIDB.newsOpened ~= Newest() end

-- entries = list to page through (default: all released); fromButton = opened from the settings
function ns.ShowWhatsNew(entries, fromButton)
    if fromButton then MeredanUIDB.newsOpened = Newest() end
    if not entries then
        entries = {}
        for _, e in ipairs(ns.WHATS_NEW) do if not e.draft then entries[#entries + 1] = e end end
    end
    pages = entries
    if #pages == 0 then return end
    if not window then CreateWindow() end
    index = 1
    Render()
    window:Show()
    window:Raise()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
end

ns.AddCommand("news", L["What's new in mUI"], function() ns.ShowWhatsNew() end)

-- After login: unseen entries, unless the setup wizard is up (fresh character) - then later
ns:On("PLAYER_LOGIN", function()
    C_Timer.After(4, function()
        local seen = Seen()
        local known = false
        for _, data in pairs(MeredanUIDB.chars or {}) do if data.setupDone then known = true end end
        if not known then -- fresh install: nothing is new
            for _, e in ipairs(ns.WHATS_NEW) do seen[e.id] = true end
            MeredanUIDB.newsOpened = Newest()
            return
        end
        local setup = _G["MeredanUISetup"]
        if (setup and setup:IsShown()) or InCombatLockdown() then return end
        local unseen = {}
        for _, e in ipairs(ns.WHATS_NEW) do if not seen[e.id] and not e.draft then unseen[#unseen + 1] = e end end
        if #unseen > 0 then ns.ShowWhatsNew(unseen) end
    end)
end)
