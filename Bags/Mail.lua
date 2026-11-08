-- Mailbox: hooks Blizzard's "Open All" (OpenAllMail), counts gold and items taken and prints
-- a summary to chat afterwards ("Mail: 1,234g and 7 items.").
local _, ns = ...
local L = ns.L

local opening, startMoney, items = false, 0, 0

local function Start()
    opening, startMoney, items = true, GetMoney(), 0
end

local function Stop()
    if not opening then return end
    opening = false
    -- the last gold arrives a moment after the last letter
    C_Timer.After(1, function()
        local earned = GetMoney() - startMoney
        if earned <= 0 and items == 0 then return end
        local parts = {}
        if earned > 0 then parts[#parts + 1] = GetMoneyString(earned, true) end
        if items > 0 then parts[#parts + 1] = L["%d items"]:format(items) end
        ns.Print(L["Mail: %s."]:format(table.concat(parts, " " .. L["and"] .. " ")))
    end)
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_MailFrame", function()
    if not OpenAllMail then return end
    hooksecurefunc(OpenAllMail, "StartOpening", Start)
    hooksecurefunc(OpenAllMail, "StopOpening", Stop)
    hooksecurefunc("TakeInboxItem", function() if opening then items = items + 1 end end)
end)
