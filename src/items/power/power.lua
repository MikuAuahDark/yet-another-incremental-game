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
g.PREUNLOCKED_ITEMS:add("basic_generator")

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



g.definePowerRelay("basic_relay", "Relay", {
    color = objects.Color.GRAY,
    price = 75,
    wireLength = 5,
    draw = function(r)
        drawRelay(r, 3, 0.075)
    end
})
g.PREUNLOCKED_ITEMS:add("basic_relay")

g.definePowerRelay("advanced_relay", "Advanced Relay", {
    color = objects.Color("#707070"),
    price = 200,
    wireLength = 7,
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
    price = 500,
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
