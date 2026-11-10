-- Details! in the mUI look, through Details' own skin API (Details:InstallSkin, see Details'
-- functions/skins.lua): flat dark panel, 1 px border, mUI fonts and the flat mUI bar texture,
-- class-coloured bars. Built on Details' "ElvUI Style II" values. Applied to every window once per
-- window (instance.skin) while the switch is on; afterwards Details' own options stay usable.
-- Window 1 sits where mUI's damage meter sits (top left, same width, 5 rows) and is locked - set on
-- every login, like mUI's fixed layouts.
-- Switch: ns.db.detailsStyle (Dungeons & raids page, only while Details is active).
local _, ns = ...

local SKIN = "MeredanUI"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Styled() return ns.db and ns.db.detailsStyle ~= false end

local WIDTH = 335          -- as mUI's damage meter (DamageMeter/DamageMeter.lua)
local ROWS_HEIGHT = 5 * 21 + 4 -- five 20 px rows with 1 px gaps
local TITLE = 20           -- Details' title bar sits above the window frame

local function Place(instance)
    local frame = instance.baseframe
    if not frame or InCombatLockdown() then return end
    local margin = ns.Snap(ns.SCREEN_MARGIN)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", margin, -(margin + TITLE))
    instance:SetSize(WIDTH, ROWS_HEIGHT) -- also saves the position in Details
    if instance.LockInstance and not instance.isLocked then instance:LockInstance(true) end
end

-- 1 px black border around the window (Details' side bars are off)
local function Border(instance)
    local frame = instance and instance.baseframe
    if not frame or frame.muiBorder then return end
    frame.muiBorder = ns.AddBorder(frame)
end

local function SkinTable()
    local panel = ns.STYLE.panelColor
    local text = ns.UI.TEXT
    return {
        file = [[Interface\AddOns\Details\images\skins\elvui_opaque.blp]],
        author = "MeredanUI",
        version = "1.0",
        site = "",
        desc = "Flat MeredanUI look.",
        no_cache = true,

        can_change_alpha_head = true,
        icon_anchor_main = { -4, -5 },
        icon_anchor_plugins = { -7, -13 },
        icon_plugins_size = { 19, 18 },
        micro_frames = { color = { text[1], text[2], text[3], 1 }, font = "mUI", size = 11, textymod = 1 },
        icon_point_anchor = { -35, -0.5 },
        left_corner_anchor = { -107, 0 },
        right_corner_anchor = { 96, 0 },
        icon_point_anchor_bottom = { -37, 12 },
        left_corner_anchor_bottom = { -107, 0 },
        right_corner_anchor_bottom = { 96, 0 },
        icon_on_top = true,
        icon_ignore_alpha = true,
        icon_titletext_position = { 2, 5 },
        callback = function(_, instance) Border(instance) end,

        instance_cprops = {
            menu_icons_alpha = 0.92,
            show_statusbar = false,
            color = { panel[1], panel[2], panel[3], 1 },
            menu_anchor = { 17, 2, side = 2 },
            bg_r = panel[1], bg_g = panel[2], bg_b = panel[3], bg_alpha = panel[4],
            color_buttons = { 1, 1, 1, 1 },
            bars_sort_direction = 1,
            instance_button_anchor = { -27, 1 },
            row_info = {
                texts = {
                    [1] = { color = { byClass = false } },
                    [2] = { color = { byClass = false } },
                    [3] = { color = { byClass = false } },
                    [4] = { color = { byClass = false } },
                },
                textR_outline = false,
                textL_outline = false,
                textL_outline_small = true,
                textR_outline_small = true,
                use_spec_icons = true,
                textL_enable_custom_text = false,
                icon_file = "Interface\\AddOns\\Details\\images\\spec_icons_normal",
                texture_background_file = WHITE,
                start_after_icon = true,
                texture_highlight = "Interface\\FriendsFrame\\UI-FriendsList-Highlight",
                textR_enable_custom_text = false,
                textR_custom_text = "{data1} ({data2}, {data3}%)",
                percent_type = 1,
                fixed_text_color = { text[1], text[2], text[3], 1 },
                space = { right = -3, right_noborder = -3, left = 1, left_noborder = 1, between = 1 },
                texture = ns.DEFAULT_TEXTURE,
                texture_file = WHITE,
                texture_background_class_color = false,
                fixed_texture_background_color = { 0.1, 0.1, 0.11, 0.6 },
                font_face = "mUI",
                font_face_file = ns.DEFAULT_FONT,
                alpha = 1,
                backdrop = { enabled = false, size = 1, color = { 0, 0, 0, 1 }, texture = "Details BarBorder 1" },
                texture_background = ns.DEFAULT_TEXTURE,
                textL_custom_text = "{data1}. {data3}{data2}",
                no_icon = false,
                font_size = 12,
                height = 20,
                texture_class_colors = true,
                textL_show_number = true,
                fixed_texture_color = { 0.86, 0.86, 0.86, 1 },
            },
            bars_grow_direction = 1,
            menu_alpha = { enabled = false, onleave = 1, ignorebars = false, iconstoo = true, onenter = 1 },
            total_bar = { enabled = false, only_in_group = true, icon = "Interface\\ICONS\\INV_Sigil_Thorim", color = { 1, 1, 1 } },
            plugins_grow_direction = 1,
            strata = "LOW",
            show_sidebars = false,
            show_sidebars_need_resize_by = 1,
            hide_in_combat_alpha = 0,
            menu_icons = { true, true, true, true, true, false, space = -1, shadow = true },
            desaturated_menu = true,
            auto_hide_menu = { left = false, right = false },
            window_scale = 1.0,
            grab_on_top = false,
            menu_anchor_down = { 16, -2 },
            statusbar_info = { alpha = 1, overlay = { 1, 1, 1 } },
            hide_icon = true,
            micro_displays_side = 2,
            auto_current = true,
            toolbar_side = 1,
            backdrop_texture = "Details Ground",
            hide_in_combat = false,
            skin = SKIN,
            menu_icons_size = 0.85,
            wallpaper = { enabled = false, anchor = "all", alpha = 1, texture = WHITE, overlay = { 1, 1, 1, 1 },
                texcoord = { 0, 1, 0, 1 }, width = 266, height = 226 },
            stretch_button_side = 1,
            attribute_text = {
                enabled = true, shadow = true, side = 1, enable_custom_text = false, custom_text = "{name}",
                text_face = "mUI Bold", anchor = { -18, 5 }, text_color = { text[1], text[2], text[3], 1 }, text_size = 13,
            },
        },
    }
end

local installed = false
local function Install()
    local Details = _G.Details
    if installed or not (Details and Details.InstallSkin and Details.IsLoaded and Details.IsLoaded()) then return end
    installed = Details:InstallSkin(SKIN, SkinTable()) and true or false
end

-- Every open window gets the skin once; a window already on it just gets its border back
function ns.ApplyDetailsStyle()
    local Details = _G.Details
    if not (Details and Details.GetInstance) then return end
    Install()
    if not installed then return end
    for id = 1, (Details.GetNumInstances and Details:GetNumInstances() or 10) do
        local instance = Details:GetInstance(id)
        if instance and instance.baseframe then
            if Styled() and instance.skin ~= SKIN then
                instance:ChangeSkin(SKIN)
            elseif not Styled() and instance.skin == SKIN then
                instance:ChangeSkin("Minimalistic")
            end
            if instance.skin == SKIN then
                Border(instance)
                if id == 1 then Place(instance) end
            end
        end
    end
end

ns:On("PLAYER_LOGIN", function()
    if not C_AddOns.IsAddOnLoaded("Details") then return end
    -- Details finishes loading its windows a moment after login
    local tries = 0
    local function Try()
        tries = tries + 1
        local Details = _G.Details
        if Details and Details.IsLoaded and Details.IsLoaded() then
            ns.ApplyDetailsStyle()
        elseif tries < 20 then
            C_Timer.After(1, Try)
        end
    end
    C_Timer.After(1, Try)
end)
