---@param r kirigami.Region
---@param n integer
---@param dist number
---@param len number
---@param thickness number
local function drawDataOutputDecorator(r, n, dist, len, thickness)
    -- Data output decoration is "arrow" pointing inwards
    local centerR = r:padRatio(0.75)
    local sz = math.sqrt(centerR.w * centerR.h)
    local d = dist * sz
    local width = len * sz
    local height = thickness * sz
    local hpx0 = height / 2
    for i = 1, n do
        local t = math.sin((love.timer.getTime() + i / 5) * math.pi) ^ 2
        local hpx = hpx0 + t * sz / 20
        -- Top Left
        local baseX = centerR.x - (i - 1) * d
        local baseY = centerR.y - (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -width, -height)
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -height, -width)
        -- Top Right
        baseX = centerR.x + centerR.w + (i - 1) * d
        baseY = centerR.y - (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, width, -height)
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, height, -width)
        -- Bottom Right
        baseX = centerR.x + centerR.w + (i - 1) * d
        baseY = centerR.y + centerR.h + (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, width, height)
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, height, width)
        -- Bottom Left
        baseX = centerR.x - (i - 1) * d
        baseY = centerR.y + centerR.h + (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -width, height)
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -height, width)
    end

    return centerR
end


g.defineDataOutput("basic_data", "Basic Data Output", {
    price = 0,
    load = 1,
    dataPerSecond = 10,
    wireLength = 2,
    color = objects.Color("#ebc965"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 2, 0.25, 0.35, 0.05)
        col:pop()
    end,
})
g.PREUNLOCKED_ITEMS:add("basic_data")

g.defineDataOutput("normal_data", "Data Output", {
    price = 150,
    load = 2,
    dataPerSecond = 500,
    wireLength = 2,
    color = objects.Color("FFBAEB65"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 2, 0.15, 0.4, 0.08)
        col:pop()
    end,
})

g.defineDataOutput("advanced_data", "Advanced Data Output", {
    price = 1000,
    load = 10,
    dataPerSecond = 5000,
    wireLength = 3,
    color = objects.Color("#95c9c7"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 3, 0.15, 0.4, 0.08)
        col:pop()
    end,
})

g.defineDataOutput("he_data", "High-End Data Output", {
    price = 6000,
    load = 30,
    dataPerSecond = 30000,
    wireLength = 4,
    color = objects.Color("#E13B49"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 4, 0.15, 0.45, 0.08)
        col:pop()
    end,
})

g.defineDataOutput("quantum_data", "Quantum Data Output", {
    price = 20000,
    load = 50,
    dataPerSecond = 100000,
    wireLength = 6,
    color = objects.Color("#DAB5C1"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        local centerR = drawDataOutputDecorator(r, 4, 0.15, 0.45, 0.08)
        local t = math.sin(love.timer.getTime() * math.pi) ^ 2
        g.drawImageContained("blur_on", centerR:padRatio(-0.3):padRatio(-0.1 * t):get())
        col:pop()
    end,
})
