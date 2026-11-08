-- MUI-Schrift überall (Einstellungen > Look): alle Schrift-Objekte des Spiels (GetFonts – z. B.
-- GameFontNormal, SystemFont_*, NumberFont_*) bekommen die MUI-Schriftart, Größe und Kontur bleiben
-- Blizzards. Fast alle Fenster, Menüs und Texte nutzen diese Objekte (außer den Chat-Schriften). Die globalen Pfade
-- (STANDARD_TEXT_FONT …) bleiben unangetastet – Blizzard liest sie auch in geschütztem Code.
local _, ns = ...

local function Enabled() return ns.db.fontEverywhere ~= false end

function ns.ApplyGlobalFonts()
    if not Enabled() or not GetFonts then return end
    local font = ns.STYLE.font
    for _, name in ipairs(GetFonts()) do
        local object = _G[name]
        -- Chat-Schriften nicht: der MUI-Chat stellt Schrift und Größe selbst ein (sonst verliert
        -- das Eingabefeld seine Schrift samt Cursor)
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
    -- andere Schrift in den Einstellungen gewählt: überall nachziehen
    if ns.RefreshStyle then
        local refresh = ns.RefreshStyle
        ns.RefreshStyle = function(...)
            refresh(...)
            ns.ApplyGlobalFonts()
        end
    end
end)
