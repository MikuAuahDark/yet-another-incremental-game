g.defineDataOutput("basic_data", "Basic Data Output", {
    price = 0,
    load = 1,
    dataPerSecond = 10,
    wireLength = 2,
    color = objects.Color("#ebc965"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        for i = 0, 3 do
            local a = (i * math.pi * 2) / 4
            local x1 = cx + r.w / 10 * math.cos(a)
            local y1 = cy + r.h / 10 * math.sin(a)
            local x2 = cx + r.w / 5 * math.cos(a)
            local y2 = cy + r.h / 5 * math.sin(a)
            love.graphics.line(x1, y1, x2, y2)
        end
        lw:pop()
        col:pop()
    end,
})
g.PREUNLOCKED_ITEMS:add("basic_data")

g.defineDataOutput("normal_data", "Data Output", {
    price = 7,
    load = 2,
    dataPerSecond = 100,
    wireLength = 2,
    color = objects.Color("FFBAEB65"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        for i = 0, 3 do
            local a = (i * math.pi * 2) / 4
            local x1 = cx + r.w / 10 * math.cos(a)
            local y1 = cy + r.h / 10 * math.sin(a)
            local x2 = cx + r.w / 5 * math.cos(a)
            local y2 = cy + r.h / 5 * math.sin(a)
            love.graphics.line(x1, y1, x2, y2)
        end
        lw:pop()
        col:pop()
    end,
})

g.defineDataOutput("advanced_data", "Advanced Data Output", {
    price = 25,
    load = 10,
    dataPerSecond = 500,
    wireLength = 4,
    color = objects.Color("#95c9c7"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        for i = 0, 7 do
            local a = (i * math.pi * 2) / 8
            local x1 = cx + r.w / 10 * math.cos(a)
            local y1 = cy + r.h / 10 * math.sin(a)
            local x2 = cx + r.w / 5 * math.cos(a)
            local y2 = cy + r.h / 5 * math.sin(a)
            love.graphics.line(x1, y1, x2, y2)
        end
        lw:pop()
        col:pop()
    end,
})

g.defineDataOutput("he_data", "High-End Data Output", {
    price = 1000,
    load = 30,
    dataPerSecond = 10000,
    wireLength = 6,
    color = objects.Color("#e06e92"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        love.graphics.circle("line", cx, cy, r.w / 5)
        lw:pop()
        col:pop()
    end,
})
