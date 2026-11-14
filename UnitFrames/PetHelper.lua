-- Pet helper (Forever, hunter): paw button left of the pet frame, colored by happiness.
-- Click feeds the pet the best suitable food from the bags (Feed Pet 6991 + /use bag slot via
-- a secure macro button; attributes only out of combat). Toast when happiness drops.
-- Retail has no pet happiness, so the module is off there.
local _, ns = ...
local L = ns.L

local FEED_PET_SPELL_ID = 6991

local MOOD = {
    [1] = { text = PET_HAPPINESS1, color = { 1, 0.25, 0.25 } },  -- unhappy
    [2] = { text = PET_HAPPINESS2, color = { 1, 0.82, 0 } },     -- content
    [3] = { text = PET_HAPPINESS3, color = { 0.45, 0.85, 0.45 } }, -- happy
}

local button
local lastMood
local food -- { bag, slot, itemID, name, count }

local function Supported() return C_PetInfo and C_PetInfo.GetPetHappiness and C_PetInfo.CanPetEatItem end
local function Enabled() return ns.db.petHelper ~= false end

local function HunterPet()
    if not UnitExists("pet") then return false end
    local _, isHunterPet = HasPetUI()
    return isHunterPet and true or false
end

local function Mood()
    local happiness, damage, loyalty = C_PetInfo.GetPetHappiness()
    if not ns.Readable(happiness) or not MOOD[happiness] then return end
    return happiness, ns.Readable(damage) and damage or nil, ns.Readable(loyalty) and loyalty or nil
end

local function FeedSpellName()
    if not C_SpellBook.IsSpellKnown(FEED_PET_SPELL_ID) then return end
    return C_Spell.GetSpellName(FEED_PET_SPELL_ID)
end

-- Highest item level first (pets refuse food that is too low level)
local function FindFood()
    local best, bestLevel
    for bag = Enum.BagIndex.Backpack, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and C_PetInfo.CanPetEatItem(id) then
                local level = select(4, C_Item.GetItemInfo(id)) or 0
                if not best or level > bestLevel then
                    best = { bag = bag, slot = slot, itemID = id, name = info.itemName, count = C_Item.GetItemCount(id) }
                    bestLevel = level
                end
            end
        end
    end
    return best
end

-- Secure attributes and visibility - out of combat only
local function ApplySecure()
    if not button then return end
    local show = Enabled() and HunterPet()
    button:SetShown(show)
    local spell = FeedSpellName()
    if show and spell and food then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", ("/cast %s\n/use %d %d"):format(spell, food.bag, food.slot))
    else
        button:SetAttribute("type", nil)
        button:SetAttribute("macrotext", nil)
    end
end

local function UpdateMood()
    if not button then return end
    local happiness = HunterPet() and Mood()
    button.icon:SetVertexColor(unpack(happiness and MOOD[happiness].color or ns.UI.TEXT))
end

local function Refresh()
    if not button then return end
    food = HunterPet() and FindFood() or nil
    UpdateMood()
    ns.AfterCombat(ApplySecure)
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local happiness, damage, loyalty = Mood()
    local mood = happiness and MOOD[happiness]
    GameTooltip:SetText(mood and mood.text or L["Pet"], unpack(mood and mood.color or { 1, 1, 1 }))
    if damage then GameTooltip:AddLine(PET_DAMAGE_PERCENTAGE:format(damage), 0.8, 0.8, 0.8) end
    if loyalty and loyalty < 0 then
        GameTooltip:AddLine(LOSING_LOYALTY, 1, 0.25, 0.25)
    elseif loyalty and loyalty > 0 then
        GameTooltip:AddLine(GAINING_LOYALTY, 0.45, 0.85, 0.45)
    end
    local diet = C_PetInfo.GetPetFoodTypes and C_PetInfo.GetPetFoodTypes() or {}
    GameTooltip:AddLine(PET_DIET_TEMPLATE:format(#diet > 0 and table.concat(diet, PET_FOOD_DELIMIT) or NONE), 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    if not FeedSpellName() then
        GameTooltip:AddLine(L["You don't know Feed Pet yet."], 0.6, 0.6, 0.6, true)
    elseif food then
        GameTooltip:AddDoubleLine(L["Click: feed"], ("%s (%d)"):format(food.name or "?", food.count or 0), 1, 0.82, 0, 1, 1, 1)
    else
        GameTooltip:AddLine(L["No suitable food in your bags."], 1, 0.25, 0.25, true)
    end
    GameTooltip:Show()
end

-- One toast when happiness drops
local function OnHappiness()
    local happiness = HunterPet() and Mood()
    UpdateMood()
    if happiness and lastMood and happiness < lastMood and Enabled() and ns.AddToast then
        local text = happiness == 1 and L["Your pet is angry and may run away – feed it!"]
            or L["Your pet is getting hungry."]
        if not food then text = text .. " " .. L["No suitable food in your bags."] end
        ns.AddToast({ title = UnitName("pet") or L["Pet"], text = text, color = MOOD[happiness].color,
            icon = ns.IconPath("Pet") })
    end
    lastMood = happiness or nil
end

local function Create(petFrame)
    button = CreateFrame("Button", "MeredanUIPetFeed", petFrame, "SecureActionButtonTemplate")
    local size = ns.Snap(petFrame:GetHeight() > 0 and petFrame:GetHeight() or 20)
    button:SetSize(size, size)
    -- right of the pet frame like the class reagents beside the player frame, clear of its deep
    -- shell (4 lines + 2 units band)
    button:SetPoint("LEFT", petFrame, "RIGHT", ns.Snap(8) + 4 * ns.PixelSize() + ns.Snap(2), 0)
    button:RegisterForClicks("AnyUp", "AnyDown")
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(ns.STYLE.panelColor))
    ns.AddItemFrame(button, nil, 1)
    button.icon = ns.UI.Icon(button, "Pet", math.floor(size * 0.8), nil, true) -- flat: the colour shows the mood
    button.icon:SetPoint("CENTER")
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", ns.ItemInset(nil, 1), -ns.ItemInset(nil, 1))
    hl:SetPoint("BOTTOMRIGHT", -ns.ItemInset(nil, 1), ns.ItemInset(nil, 1))
    hl:SetColorTexture(1, 1, 1, 0.08)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:Hide()
end

function ns.UpdatePetHelper() Refresh() end

ns:On("PLAYER_LOGIN", function()
    if not Supported() or select(2, UnitClass("player")) ~= "HUNTER" then return end
    local petFrame = ns.smallFrames and ns.smallFrames.pet
    if not petFrame then return end
    Create(petFrame)
    lastMood = HunterPet() and Mood() or nil
    Refresh()
    ns:On("UNIT_PET", function(_, unit) if unit == "player" then lastMood = nil; Refresh(); lastMood = HunterPet() and Mood() or nil end end)
    ns:On("UNIT_HAPPINESS", function(_, unit) if not unit or unit == "pet" then OnHappiness() end end)
    ns:On("BAG_UPDATE_DELAYED", Refresh)
    ns:On("LEARNED_SPELL_IN_SKILL_LINE", Refresh)
end)
