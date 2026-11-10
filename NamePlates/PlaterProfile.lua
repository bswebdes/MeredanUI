-- Plater in the mUI look - only through Plater's own profile settings (Plater.db.profile):
-- mUI font for every text, the flat mUI bar texture for health and cast bars on a faint dark
-- background, 1 px black border. Sizes, colours and Plater's logic stay Plater's.
-- Set once per character (ns.char.platerProfile); afterwards Plater's options decide.
-- Switch: ns.db.platerStyle (Nameplates page, only while Plater is active).
local _, ns = ...

local PROFILE_VERSION = 4
local BAR_BG = { 0, 0, 0, 0.5 }

-- Every font setting Plater knows (keys ending in "_font", found in its defaults) -> "mUI"
local function SetFonts(defaults, profile)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(profile[key]) == "table" then SetFonts(value, profile[key]) end
        elseif type(value) == "string" and key:find("_font$") then
            profile[key] = "mUI"
        end
    end
end

function ns.ApplyPlaterProfile(force)
    local Plater = _G.Plater
    local profile = Plater and Plater.db and Plater.db.profile
    if not profile or ns.db.platerStyle == false then return end
    if not force and (ns.char.platerProfile or 0) >= PROFILE_VERSION then return end
    ns.char.platerProfile = PROFILE_VERSION

    if type(_G.PLATER_DEFAULT_SETTINGS) == "table" and _G.PLATER_DEFAULT_SETTINGS.profile then
        SetFonts(_G.PLATER_DEFAULT_SETTINGS.profile, profile)
    end
    profile.health_statusbar_texture = ns.DEFAULT_TEXTURE
    profile.health_statusbar_bgtexture = ns.DEFAULT_TEXTURE
    profile.health_statusbar_bgcolor = BAR_BG
    profile.health_selection_overlay = ns.DEFAULT_TEXTURE
    profile.cast_statusbar_texture = ns.DEFAULT_TEXTURE
    profile.cast_statusbar_bgtexture = ns.DEFAULT_TEXTURE
    profile.cast_statusbar_bgcolor = BAR_BG
    profile.border_color = { 0, 0, 0, 1 }
    profile.border_thickness = 1

    -- Enemy plates like mUI's: wider, taller bar, name inside on the left, percent inside on the
    -- right (no decimals, no raw health), no level text, border stays black (no aggro colour)
    if type(profile.aggro_modifies) == "table" then profile.aggro_modifies.border_color = false end
    for _, kind in ipairs({ "enemynpc", "enemyplayer" }) do
        local cfg = profile.plate_config and profile.plate_config[kind]
        if type(cfg) == "table" then
            cfg.health = { 140, 16 }
            cfg.cast = { 140, 12 }
            cfg.actorname_text_size = 12
            cfg.actorname_text_anchor = { side = 10, x = 3, y = 0 }  -- inside left
            cfg.percent_text_enabled = true
            cfg.percent_show_percent = true
            cfg.percent_show_health = false
            cfg.percent_text_show_decimals = false
            cfg.percent_text_size = 11
            cfg.percent_text_anchor = { side = 11, x = -3, y = 0 }   -- inside right
            cfg.level_text_enabled = false
        end
    end

    -- Friendly plates like mUI's: only the name, players in class colour, NPCs in mUI's accent,
    -- 14 px like mUI's "medium" name size ("big_" = Plater's name-only mode)
    local plates = profile.plate_config
    local player, npc = plates and plates.friendlyplayer, plates and plates.friendlynpc
    local function Size(cfg)
        cfg.actorname_text_size = 14
        if cfg.big_actorname_text_size ~= nil then cfg.big_actorname_text_size = 14 end
    end
    if type(player) == "table" then
        player.only_thename = true
        player.actorname_use_class_color = true
        if player.big_actorname_use_class_color ~= nil then player.big_actorname_use_class_color = true end
        Size(player)
    end
    if type(npc) == "table" then
        npc.only_names = true
        local a = ns.UI.ACCENT
        npc.big_actorname_text_color = { a[1], a[2], a[3] }
        npc.big_actortitle_text_color = { 1, 1, 1 } -- titles / "<Owner's Pet>" white like mUI's
        Size(npc)
    end

    if Plater.RefreshDBUpvalues then Plater.RefreshDBUpvalues() end
    if Plater.UpdateAllPlates then Plater.UpdateAllPlates(true) end
end

ns:On("PLAYER_LOGIN", function()
    if not C_AddOns.IsAddOnLoaded("Plater") then return end
    C_Timer.After(2, function() ns.ApplyPlaterProfile() end)
end)
