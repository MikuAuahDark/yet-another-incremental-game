---@param r kirigami.Region
---@param n integer
---@param dist number
local function drawRelay(r, n, dist)
    local sz = math.sqrt(r.w * r.h)
    local lw = gsman.setLineWidth(0.025 * sz)
    local cx, cy = r:getCenter()
    local t0 = love.timer.getTime()

    for j = 1, n do
        local radius = (j + 0.4) * sz * dist
        local t = math.sin((t0 + (n - j) / 5) * math.pi) ^ 2
        local col = gsman.mulColor(1, 1, 1, t)
        for i = 0, 3 do
            local a1 = math.rad(20 + i * 90)
            local a2 = math.rad(-20 + i * 90)
            love.graphics.arc("line", "open", cx, cy, radius, a1, a2)
        end
        col:pop()
    end
    lw:pop()
end

g.definePowerGenerator("basic_generator", "Generator", {
    color = objects.Color.GRAY,
    price = 100,
    power = 2,
    wireLength = 2,
    draw = function(r)
        local col = gsman.mulColor(1, 1, 1)
        g.drawImageContained("bolt", r:padRatio(0.67):get())
        col:pop()
    end
})

g.definePowerGenerator("efficient_generator", "Efficient Generator", {
    color = objects.Color("#909090"),
    price = 500,
    power = 10,
    wireLength = 3,
    draw = function(r)
        local t0 = love.timer.getTime()
        local opacity = helper.remap(math.sin(t0 * math.pi / 2) ^ 2, 0, 1, 0.7, 1)
        local col = gsman.mulColor(1, 1, 1, opacity)
        g.drawImageContained("bolt", r:padRatio(0.3):get())
        col:pop()
    end
})

g.definePowerGenerator("advanced_generator", "Advanced Generator", {
    color = objects.Color("#a0a0a0"),
    price = 2500,
    power = 40,
    wireLength = 4,
    draw = function(r)
        local t0 = love.timer.getTime()
        local opacity = helper.remap(math.sin(t0 * math.pi / 2) ^ 2, 0, 1, 0.7, 1)
        local col = gsman.mulColor(1, 1, 1, opacity)
        g.drawImageContained("bolt", r:padRatio(0.3):get())
        col:pop()
        local sz = math.sqrt(r.w * r.h)
        local cx, cy = r:getCenter()
        for i = 0, 3 do
            local a = math.rad(i * 90)
            local x = math.cos(a) * 0.36 * sz
            local y = math.sin(a) * 0.36 * sz
            local t = math.sin((t0 + i / 2) * math.pi) ^ 2
            local col2 = gsman.mulColor(1, 1, 1, t)
            g.drawImage("bolt", cx + x, cy + y, 0, 0.003 * sz)
            col2:pop()
        end
    end
})


---@param n integer
local function makeDrawDecorForPowerlines(n)
    local splits = {}
    for i = 1, 2 * n - 1 do
        splits[#splits+1] = (i % 2 == 1 and 1 or 3)
    end
    table.insert(splits, 1, 5)
    splits[#splits+1] = 5

    local baseR = Kirigami(0, 0, 1, 1)
    local top, c1, bottom = baseR:splitVertical(1, 4, 1)
    local left, c2, right = baseR:splitHorizontal(1, 4, 1)

    local topListBase = {top:splitHorizontal(unpack(splits))}
    local leftListBase = {left:splitVertical(unpack(splits))}
    local bottomListBase = {bottom:splitHorizontal(unpack(splits))}
    local rightListBase = {right:splitVertical(unpack(splits))}
    ---@type kirigami.Region[]
    local topList = {}
    for i = 2, #topListBase, 2 do
        topList[#topList+1] = topListBase[i]
    end
    ---@type kirigami.Region[]
    local leftList = {}
    for i = 2, #leftListBase, 2 do
        leftList[#leftList+1] = leftListBase[i]
    end
    ---@type kirigami.Region[]
    local bottomList = {}
    for i = 2, #bottomListBase, 2 do
        bottomList[#bottomList+1] = bottomListBase[i]
    end
    ---@type kirigami.Region[]
    local rightList = {}
    for i = 2, #rightListBase, 2 do
        rightList[#rightList+1] = rightListBase[i]
    end

    local centerR = c1:intersection(c2)
    local niter = math.min(#topList, #leftList, #bottomList, #rightList)

    ---@param r kirigami.Region
    return function(r)
        for i = 1, niter do
            local tp = helper.denormalizeRegion(r, topList[i])
            local lf = helper.denormalizeRegion(r, leftList[i])
            local bt = helper.denormalizeRegion(r, bottomList[i])
            local ri = helper.denormalizeRegion(r, rightList[i])
            love.graphics.rectangle("fill", tp:get())
            love.graphics.rectangle("fill", lf:get())
            love.graphics.rectangle("fill", bt:get())
            love.graphics.rectangle("fill", ri:get())
        end

        return helper.denormalizeRegion(r, centerR)
    end
end

local _mainPowerDecor = makeDrawDecorForPowerlines(3)
g.definePowerGenerator("main_power", "Main Datacenter Power", {
    tags = {"datacenter_power"},
    color = objects.Color.WHITE,
    price = 0,
    power = 100,
    wireLength = 4,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        local centerR = _mainPowerDecor(r)
        g.drawImageContained("bolt", centerR:padRatio(0.25):get())
        col:pop()
    end
})

local _subPowerDecor = makeDrawDecorForPowerlines(2)
g.definePowerGenerator("sub_power", "Sub Datacenter Power", {
    tags = {"datacenter_power"},
    color = objects.Color.WHITE,
    price = 0,
    power = 30,
    wireLength = 2,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        local centerR = _subPowerDecor(r)
        g.drawImageContained("bolt", centerR:padRatio(0.5):get())
        col:pop()
    end
})



g.definePowerRelay("basic_relay", "Relay", {
    color = objects.Color.GRAY,
    price = 150,
    wireLength = 3,
    draw = function(r)
        drawRelay(r, 3, 0.075)
    end
})

g.definePowerRelay("advanced_relay", "Advanced Relay", {
    color = objects.Color("#707070"),
    price = 1000,
    wireLength = 6,
    draw = function(r)
        local sz = math.sqrt(r.w * r.h)
        do
            local col = gsman.mulColor(0, 0, 0, 0.5)
            local _, a, _ = r:splitHorizontal(14, 1, 14)
            love.graphics.rectangle("fill", a:get())
            _, a, _ = r:splitVertical(14, 1, 14)
            love.graphics.rectangle("fill", a:get())
            col:pop()
        end
        drawRelay(r, 5, 0.0625)
        local cx, cy = r:getCenter()
        love.graphics.circle("fill", cx, cy, 0.04 * sz)
    end
})

g.definePowerRelay("he_relay", "High-End Relay", {
    color = objects.Color("#606060"),
    price = 15000,
    wireLength = 9,
    draw = function(r)
        local sz = math.sqrt(r.w * r.h)
        do
            local col = gsman.mulColor(0, 0, 0, 0.5)
            local _, a, _, b, _ = r:splitHorizontal(14, 1, 3, 1, 14)
            love.graphics.rectangle("fill", a:get())
            love.graphics.rectangle("fill", b:get())
            _, a, _, b, _ = r:splitVertical(14, 1, 3, 1, 14)
            love.graphics.rectangle("fill", a:get())
            love.graphics.rectangle("fill", b:get())
            col:pop()
        end
        drawRelay(r, 7, 0.055)
        local cx, cy = r:getCenter()
        love.graphics.circle("fill", cx, cy, 0.04 * sz)
    end
})
