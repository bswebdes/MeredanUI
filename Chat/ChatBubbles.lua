-- Chat bubbles in MUI style: flat dark box with 1px border, flat tail at Blizzard's tail position,
-- MUI font. Bubbles are skinned via C_ChatBubbles.GetAllChatBubbles() (non-forbidden only).
-- In dungeons/raids bubbles are forbidden to addons; only the font applies there (shared ChatBubbleFont).
local _, ns = ...

local SCAN_INTERVAL = 0.15
local TAIL = ns.MEDIA .. "BubbleTail" -- triangle pointing down
local TAIL_W, TAIL_H = 18, 11
local skinned = setmetatable({}, { __mode = "k" })
local NINE_SLICE = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

local function Enabled() return ns.db and ns.db.chatBubbles ~= false end

local function ApplyFont()
    if not ChatBubbleFont then return end
    local _, size = ChatBubbleFont:GetFont()
    ChatBubbleFont:SetFont(ns.FontFor("text"), size or 14, "")
    ChatBubbleFont:SetShadowOffset(1, -1)
    ChatBubbleFont:SetShadowColor(0, 0, 0, 0.8)
end

local function Skin(frame)
    for _, key in ipairs(NINE_SLICE) do
        local piece = frame[key]
        if piece then piece:SetAlpha(0) end
    end
    if frame.Tail then frame.Tail:SetAlpha(0) end
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    local r, g, b = unpack(ns.STYLE.panelColor)
    bg:SetColorTexture(r, g, b, 1) -- same opacity as the tail (no seam)
    ns.AddBorder(frame)
    -- Tail: black triangle (border) behind a slightly smaller box-colored one; both cover the
    -- bottom border so box and tail blend into each other
    local px = ns.PixelSize()
    local outline = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    outline:SetTexture(TAIL)
    outline:SetVertexColor(0, 0, 0, 1)
    outline:SetSize(ns.Snap(TAIL_W) + 3 * px, ns.Snap(TAIL_H) + 2 * px)
    local fill = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    fill:SetTexture(TAIL)
    fill:SetVertexColor(r, g, b, 1)
    fill:SetSize(ns.Snap(TAIL_W), ns.Snap(TAIL_H))
    skinned[frame] = { outline = outline, fill = fill }
end

-- Follow Blizzard's (hidden) tail position, which varies per bubble
local function PlaceTail(frame, tail)
    local blizz = frame.Tail
    local left, center = frame:GetLeft(), blizz and blizz:GetCenter()
    local x = (left and center) and (center - left) or (frame:GetWidth() or 0) / 2
    local px = ns.PixelSize()
    tail.outline:ClearAllPoints()
    tail.outline:SetPoint("TOP", frame, "BOTTOMLEFT", x, 2 * px)
    tail.fill:ClearAllPoints()
    tail.fill:SetPoint("TOP", frame, "BOTTOMLEFT", x, 2 * px)
end

local function Scan()
    if not Enabled() then return end
    for _, bubble in ipairs(C_ChatBubbles.GetAllChatBubbles(false) or {}) do
        if not bubble:IsForbidden() then
            local frame = bubble:GetChildren()
            if frame and not frame:IsForbidden() then
                if not skinned[frame] then Skin(frame) end
                PlaceTail(frame, skinned[frame])
            end
        end
    end
end

ns:On("PLAYER_LOGIN", function()
    if not Enabled() or not C_ChatBubbles then return end
    ApplyFont()
    C_Timer.NewTicker(SCAN_INTERVAL, Scan)
end)
