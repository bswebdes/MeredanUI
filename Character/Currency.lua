-- Currency tab: grouped list with amounts (gray at 0), details with caps and the "Show on backpack" /
-- "Unused" toggles (see Blizzard_TokenUI). Blizzard's API uses list indices, which shift - so the
-- selection is tracked by currencyID.
local _, ns = ...
local L = ns.L
local Char = ns.Char

local selectedID

local function Refresh(view)
    local entries = {}
    local selected, selectedIndex
    for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)
        if info and info.name then
            if info.isHeader then
                entries[#entries + 1] = {
                    header = true, text = info.name, collapsed = not info.isHeaderExpanded,
                    onClick = function() C_CurrencyInfo.ExpandCurrencyList(index, not info.isHeaderExpanded) end,
                }
            else
                local isSelected = info.currencyID == selectedID
                if isSelected then selected, selectedIndex = info, index end
                entries[#entries + 1] = {
                    text = info.name, icon = info.iconFileID, selected = isSelected,
                    indent = math.max((info.currencyListDepth or 1) - 1, 0) * 12,
                    color = (info.quantity or 0) == 0 and ns.UI.MUTED or nil,
                    right = BreakUpLargeNumbers(info.quantity or 0),
                    rightColor = (info.quantity or 0) == 0 and ns.UI.MUTED or ns.UI.TEXT,
                    onClick = function()
                        if IsModifiedClick("CHATLINK") then
                            local link = C_CurrencyInfo.GetCurrencyListLink(index)
                            if link then HandleModifiedItemClick(link) end
                            return
                        end
                        selectedID = info.currencyID
                        Char.Refresh()
                    end,
                    onEnter = function(row)
                        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                        GameTooltip:SetCurrencyToken(index)
                        GameTooltip:Show()
                    end,
                }
            end
        end
    end
    view.list:SetData(entries)
    view.emptyList:SetShown(#entries == 0)
    if not selected then
        view.detail:Empty(Char.G("TOKEN_DETAIL_SELECT_PROMPT", "Select a currency to see its details."))
        return
    end
    local info, index = selected, selectedIndex
    local grid = {}
    if info.maxQuantity and info.maxQuantity > 0 then
        grid[#grid + 1] = { a = L["Maximum"], c = ("%s/%s"):format(BreakUpLargeNumbers(info.quantity), BreakUpLargeNumbers(info.maxQuantity)) }
    end
    if info.canEarnPerWeek and info.maxWeeklyQuantity and info.maxWeeklyQuantity > 0 then
        grid[#grid + 1] = { a = L["This week"], c = ("%s/%s"):format(BreakUpLargeNumbers(info.quantityEarnedThisWeek or 0), BreakUpLargeNumbers(info.maxWeeklyQuantity)) }
    end
    view.detail:Fill({
        title = info.name, sub = BreakUpLargeNumbers(info.quantity or 0), subColor = ns.UI.TEXT,
        text = C_CurrencyInfo.GetCurrencyDescription and C_CurrencyInfo.GetCurrencyDescription(info.currencyID) or nil,
        grid = grid,
        checks = {
            { label = Char.G("SHOW_ON_BACKPACK", "Show on backpack"), checked = info.isShowInBackpack,
              onClick = function()
                  local max = BackpackTokenFrame and BackpackTokenFrame.GetMaxTokensWatched and BackpackTokenFrame:GetMaxTokensWatched()
                  if not info.isShowInBackpack and max then
                      local watched = 0
                      for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
                          local other = C_CurrencyInfo.GetCurrencyListInfo(i)
                          if other and other.isShowInBackpack then watched = watched + 1 end
                      end
                      if watched >= max then
                          UIErrorsFrame:AddMessage(TOO_MANY_WATCHED_TOKENS and TOO_MANY_WATCHED_TOKENS:format(max) or "", 1, 0.1, 0.1)
                          return
                      end
                  end
                  C_CurrencyInfo.SetCurrencyBackpack(index, not info.isShowInBackpack)
                  if BackpackTokenFrame and BackpackTokenFrame.Update then BackpackTokenFrame:Update() end
                  Char.Refresh()
              end },
            { label = Char.G("UNUSED", "Unused"), checked = info.isTypeUnused,
              onClick = function()
                  C_CurrencyInfo.SetCurrencyUnused(index, not info.isTypeUnused)
                  Char.Refresh()
              end },
        },
    })
end

Char.AddTab({
    key = "currency", order = 5, tip = Char.G("CHARACTER_FRAME_TAB_CURRENCY", "Currency"), icon = 8197078,
    Create = function(view)
        Char.ListAndDetail(view)
        view.emptyList = ns.UI.Text(view, 13, "CENTER", { 0.47, 0.46, 0.43 })
        view.emptyList:SetPoint("CENTER", view.list, "CENTER")
        view.emptyList:SetText(L["No currencies yet."])
    end,
    Refresh = Refresh,
    OnHide = function() selectedID = nil end,
    events = { "CURRENCY_DISPLAY_UPDATE", "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED" },
})
