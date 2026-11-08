-- "mUI font everywhere" (Settings > Look): applies the mUI typeface to every game font object
-- (GetFonts: GameFontNormal, SystemFont_*, NumberFont_* ...), keeping Blizzard's size and outline.
-- Global paths (STANDARD_TEXT_FONT ...) stay untouched - Blizzard reads them in protected code.
local _, ns = ...

local function Enabled() return ns.db.fontEverywhere ~= false end

function ns.ApplyGlobalFonts()
    if not Enabled() or not GetFonts then return end
    local font = ns.STYLE.font
    for _, name in ipairs(GetFonts()) do
        local object = _G[name]
        -- Skip chat fonts: the mUI chat sets them itself (otherwise the edit box loses font and cursor)
        if type(object) == "table" and object.GetFont and not name:find("^ChatFont") then
            pcall(function()
                local _, size, flags = object:GetFont()
                if size and size > 0 then object:SetFont(font, size, flags or "") end
            end)
        end
    end
end

ns:On("PLAYER_LOGIN", function()
    ns.ApplyGlobalFonts()
    -- Re-apply whenever the font setting changes
    if ns.RefreshStyle then
        local refresh = ns.RefreshStyle
        ns.RefreshStyle = function(...)
            refresh(...)
            ns.ApplyGlobalFonts()
        end
    end
end)
