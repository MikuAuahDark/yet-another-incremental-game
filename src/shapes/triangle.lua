---@class _TriangleData
---@field package shape [number,number][] 3 points, clockwise, normalized
---@field package vx number
---@field package vy number

---@param points [number,number][]
local function makeClockwise(points)
    local a, b, c = points[1], points[2], points[3]
    -- Calculate winding
    local cross = (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])
    if cross > 0 then
        -- Clockwise
        return points
    else
        -- Counter-clockwise, reverse
        return {a, c, b}
    end
end

local function genRandomTrianglePoints()
    local a1 = love.math.random() * 2 * math.pi
    local a2 = love.math.random() * 2 * math.pi
    local a3 = love.math.random() * 2 * math.pi

    local points = {
        {math.cos(a1), math.sin(a1)},
        {math.cos(a2), math.sin(a2)},
        {math.cos(a3), math.sin(a3)}
    }
    return makeClockwise(points)
end

---@param speed number
local function genRandomVelocity(speed)
    local angle = love.math.random() * 2 * math.pi
    return math.cos(angle) * speed, math.sin(angle) * speed
end

local function initTriangle(tok)
    local vx, vy = genRandomVelocity(helper.lerp(5, 10, love.math.random()))
    ---@type _TriangleData
    local data = {
        shape = genRandomTrianglePoints(),
        vx = vx,
        vy = vy
    }
    tok.data = data
end

g.defineToken("triangle_small", "Small Triangle", {
    image = "null_image",
    maxHealth = 5,
    resources = {triangle = 1},
    init = initTriangle,
    drawToken = function(tok)
        local RADIUS = 8
        ---@type _TriangleData
        local data = tok.data
        love.graphics.setColor(g.COLORS.SHAPE_COLORS.SMALL)
        love.graphics.polygon("fill",
            tok.x + data.shape[1][1] * RADIUS,
            tok.y + data.shape[1][2] * RADIUS,
            tok.x + data.shape[2][1] * RADIUS,
            tok.y + data.shape[2][2] * RADIUS,
            tok.x + data.shape[3][1] * RADIUS,
            tok.y + data.shape[3][2] * RADIUS
        )
    end
})

g.defineToken("triangle_medium", "Medium Triangle", {
    image = "null_image",
    maxHealth = 10,
    resources = {triangle = 5},
    init = initTriangle,
    drawToken = function(tok)
        local RADIUS = 16
        ---@type _TriangleData
        local data = tok.data
        love.graphics.setColor(g.COLORS.SHAPE_COLORS.MEDIUM)
        love.graphics.polygon("fill",
            tok.x + data.shape[1][1] * RADIUS,
            tok.y + data.shape[1][2] * RADIUS,
            tok.x + data.shape[2][1] * RADIUS,
            tok.y + data.shape[2][2] * RADIUS,
            tok.x + data.shape[3][1] * RADIUS,
            tok.y + data.shape[3][2] * RADIUS
        )
    end
})

g.defineToken("triangle_large", "Large Triangle", {
    image = "null_image",
    maxHealth = 20,
    resources = {triangle = 25},
    init = initTriangle,
    drawToken = function(tok)
        local RADIUS = 32
        ---@type _TriangleData
        local data = tok.data
        love.graphics.setColor(g.COLORS.SHAPE_COLORS.LARGE)
        love.graphics.polygon("fill",
            tok.x + data.shape[1][1] * RADIUS,
            tok.y + data.shape[1][2] * RADIUS,
            tok.x + data.shape[2][1] * RADIUS,
            tok.y + data.shape[2][2] * RADIUS,
            tok.x + data.shape[3][1] * RADIUS,
            tok.y + data.shape[3][2] * RADIUS
        )
    end
})
