-- Statistics tab: one full-width list (Blizzard's right side is always empty there) with
-- collapsible groups and subgroups. Gold values arrive as text with coin icons - Blizzard shows
-- "--" for them (tonumber fails), we show the text itself.
local _, ns = ...
local Char = ns.Char

local ROOT = -1
local collapsed = {} -- categoryID -> true (kept until reload)

-- Category tree in Blizzard's order
local function Categories()
    local source = GetStatisticsCategoryList() or {}
    local ordered = {}
    for index, id in pairs(source) do
        if type(index) == "number" and id then ordered[#ordered + 1] = { index = index, id = id } end
    end
    table.sort(ordered, function(a, b) return a.index < b.index end)
    local roots, children = {}, {}
    for _, entry in ipairs(ordered) do
        local _, parent = GetCategoryInfo(entry.id)
        if parent == ROOT then
            roots[#roots + 1] = entry.id
        else
            children[parent] = children[parent] or {}
            table.insert(children[parent], entry.id)
        end
    end
    return roots, children
end

local function ValueText(quantity)
    local number = tonumber(quantity)
    if number then return number > 0 and BreakUpLargeNumbers(number) or "–" end
    if type(quantity) == "string" and quantity ~= "" and quantity ~= "--" and quantity ~= "0" then return quantity end
    return "–"
end

local function Refresh(view)
    local entries = {}
    local roots, children = Categories()
    local function AddStats(categoryID, depth)
        for i = 1, GetCategoryNumAchievements(categoryID) do
            local quantity, skip, statID = GetStatistic(categoryID, i)
            if not skip and statID then
                local name = select(2, GetAchievementInfo(statID)) or UNKNOWN
                local value = ValueText(quantity)
                entries[#entries + 1] = {
                    text = name, indent = depth * 16, height = 24, right = value,
                    color = { 0.79, 0.78, 0.75 }, rightColor = value == "–" and ns.UI.MUTED or ns.UI.TEXT,
                    onEnter = function(row)
                        if not row.text:IsTruncated() then return end
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:SetText(name, 1, 1, 1, 1, true)
                        GameTooltip:Show()
                    end,
                }
            end
        end
    end
    local function AddCategory(id, depth)
        local name = GetCategoryInfo(id) or UNKNOWN
        local isCollapsed = collapsed[id]
        local toggle = function()
            collapsed[id] = not isCollapsed or nil
            Char.Refresh()
        end
        if depth == 0 then
            entries[#entries + 1] = { header = true, text = name, collapsed = isCollapsed, onClick = toggle }
        else
            entries[#entries + 1] = {
                text = (isCollapsed and (ns.UI.ACCENT_HEX .. "+|r  ") or (ns.UI.ACCENT_HEX .. "−|r  ")) .. name, indent = depth * 16, height = 26,
                onClick = toggle,
            }
        end
        if isCollapsed then return end
        AddStats(id, depth + 1)
        for _, child in ipairs(children[id] or {}) do AddCategory(child, depth + 1) end
    end
    for _, id in ipairs(roots) do AddCategory(id, 0) end
    view.list:SetData(entries)
end

Char.AddTab({
    key = "statistics", order = 6, tip = Char.G("CHARACTER_FRAME_TAB_STATISTICS", "Statistics"), icon = 8197104,
    Create = function(view)
        view.list = Char.List(view)
        view.list:SetPoint("TOPLEFT")
        view.list:SetPoint("BOTTOMRIGHT", -12, 0)
    end,
    Refresh = Refresh,
    events = { "CRITERIA_UPDATE" },
})
