-- Itemlevel an den Ausrüstungsplätzen im Charakterfenster und beim Betrachten (Inspect):
-- kleine Zahl unten im Platz, in Qualitätsfarbe. Nur eine Zahl obendrauf – Blizzards Fenster
-- bleibt, wie es ist. Einstellungen > Tooltip.
local _, ns = ...

local NO_LEVEL = { [INVSLOT_BODY or 4] = true, [INVSLOT_TABARD or 19] = true } -- Hemd, Wappenrock

local function LevelText(button)
    local text = button.muiItemLevel
    if not text then
        text = ns.CreateText(button, 12, "CENTER", "OUTLINE")
        text:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
        button.muiItemLevel = text
    end
    return text
end

local function Show(button, level, quality)
    local text = LevelText(button)
    if ns.db.characterItemLevels == false or not level or issecretvalue(level) or level <= 1 then
        return text:Hide()
    end
    local color = quality and not issecretvalue(quality) and ITEM_QUALITY_COLORS[quality]
    if color then text:SetTextColor(color.r, color.g, color.b) else text:SetTextColor(1, 1, 1) end
    text:SetText(level)
    text:Show()
end

-- eigenes Charakterfenster (Blizzard_UIPanels_Game ist meist schon geladen – dann sofort)
EventUtil.ContinueOnAddOnLoaded("Blizzard_UIPanels_Game", function()
    hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
        local slot = button:GetID()
        if NO_LEVEL[slot] or not GetInventoryItemLink("player", slot) then return Show(button) end
        local level = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromEquipmentSlot(slot))
        Show(button, level, GetInventoryItemQuality("player", slot))
    end)
end)

-- Betrachten (lädt erst bei Bedarf)
EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", function()
    hooksecurefunc("InspectPaperDollItemSlotButton_Update", function(button)
        local unit = InspectFrame and InspectFrame.unit
        local slot = button:GetID()
        local link = unit and GetInventoryItemLink(unit, slot)
        if NO_LEVEL[slot] or not link or issecretvalue(link) then return Show(button) end
        local level = C_Item.GetDetailedItemLevelInfo(link)
        local _, _, quality = C_Item.GetItemInfo(link)
        Show(button, level, quality)
    end)
end)
