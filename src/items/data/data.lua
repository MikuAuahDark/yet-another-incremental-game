---@param r kirigami.Region
---@param n integer
---@param dist number
---@param len number
---@param thickness number
---@param extradist number?
local function drawDataOutputDecorator(r, n, dist, len, thickness, extradist)
    -- Data output decoration is "arrow" pointing inwards
    local centerR = r:padRatio(0.5)
    local sz = math.sqrt(centerR.w * centerR.h)
    local d = dist * sz
    local width = len * sz
    local height = thickness * sz
    local hpx0 = height / 2
    local ed = (extradist or 0) * sz
    for i = 1, n do
        local t = math.sin((love.timer.getTime() + i / 5) * math.pi) ^ 2
        local hpx = hpx0 + t * sz / 40
        -- Top Left
        local baseX = centerR.x - ed - (i - 1) * d
        local baseY = centerR.y - ed - (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -width, -height)
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -height, -width)
        -- Top Right
        baseX = centerR.x + centerR.w + ed + (i - 1) * d
        baseY = centerR.y - ed - (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, width, -height)
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, height, -width)
        -- Bottom Right
        baseX = centerR.x + centerR.w + ed + (i - 1) * d
        baseY = centerR.y + centerR.h + ed + (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, width, height)
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, height, width)
        -- Bottom Left
        baseX = centerR.x - ed - (i - 1) * d
        baseY = centerR.y + centerR.h + ed + (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -width, height)
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -height, width)
    end

    return centerR:padRatio(0.25)
end


g.defineDataOutput("basic_data", "Basic Data Output", {
    price = 1,
    getPriceMultiplier = helper.valueGetterNoSelf(0.1, 1),
    load = 1,
    dataPerSecond = 4,
    wireLength = 2,
    wireDPS = 10,
    color = objects.Color("#ebc965"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 1, 0.125, 0.2, 0.04, -0.2)
        col:pop()
    end,
})

g.defineDataOutput("normal_data", "Data Output", {
    price = 150,
    getPriceMultiplier = helper.valueGetterNoSelf(0.1, 1),
    load = 2,
    dataPerSecond = 45,
    wireLength = 2,
    color = objects.Color("FFBAEB65"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 2, 0.15, 0.2, 0.04, -0.275)
        col:pop()
    end,
})

g.defineDataOutput("advanced_data", "Advanced Data Output", {
    price = 1000,
    getPriceMultiplier = helper.valueGetterNoSelf(0.2, 1),
    load = 10,
    dataPerSecond = 150,
    wireLength = 3,
    wireDPS = 50,
    color = objects.Color("#95c9c7"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 2, 0.15, 0.2, 0.075, -0.325)
        col:pop()
    end,
})

g.defineDataOutput("he_data", "High-End Data Output", {
    price = 6000,
    getPriceMultiplier = helper.valueGetterNoSelf(0.3, 1),
    load = 30,
    dataPerSecond = 750,
    wireLength = 4,
    wireDPS = 100,
    color = objects.Color("#E13B49"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 3, 0.15, 0.2, 0.075, -0.36)
        col:pop()
    end,
})

g.defineDataOutput("quantum_data", "Quantum Data Output", {
    price = 20000,
    getPriceMultiplier = helper.valueGetterNoSelf(0.5, 1),
    load = 50,
    dataPerSecond = 4000,
    wireLength = 5,
    wireDPS = 100,
    color = objects.Color("#DAB5C1"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(0, 0, 0)
        drawDataOutputDecorator(r, 3, 0.15, 0.3, 0.075, -0.4)
        col:pop()
    end,
})
