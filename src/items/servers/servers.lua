g.defineServer("basic_server", "Basic Server", {
    price = 0,
    computePerSecond = 1,
    computePreference = {"general"},
    load = 1,
    heatTolerance = {40, 60},
    heat = 40,
    color = objects.Color("#e4e67c"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local _, decorR = r:splitHorizontal(2, 1, 2)
        local a, _, b = decorR:set(nil, nil, nil, decorR.h * 0.1)
            :attachToBottomOf(decorR)
            :moveRatio(0, -1)
            :splitHorizontal(1, 3, 1)
        love.graphics.rectangle("fill", a:get())
        love.graphics.rectangle("fill", b:get())
        col:pop()
    end,
})
g.PREUNLOCKED_ITEMS:add("basic_server")

g.defineServer("normal_server", "Normal Server", {
    price = 10,
    computePerSecond = 10,
    computePreference = {"general"},
    load = 4,
    heatTolerance = {40, 60},
    heat = 40,
    color = objects.Color("FFB6E67C"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local _, decorR = r:splitHorizontal(2, 1, 2)
        local a, _, b = decorR:set(nil, nil, nil, decorR.h * 0.1)
            :attachToBottomOf(decorR)
            :moveRatio(0, -1)
            :splitHorizontal(1, 3, 1)
        love.graphics.rectangle("fill", a:get())
        love.graphics.rectangle("fill", b:get())
        col:pop()
    end,
})

g.defineServer("advanced_server", "Advanced Server", {
    price = 100,
    computePerSecond = 25,
    computePreference = {"general", "video"},
    load = 10,
    heatTolerance = {30, 80},
    heat = 50,
    color = objects.Color("#12aae6"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local _, decorR = r:splitHorizontal(2, 1, 2)
        local a, _, b, _, c = decorR:set(nil, nil, nil, decorR.h * 0.1)
            :attachToBottomOf(decorR)
            :moveRatio(0, -1)
            :splitHorizontal(1, 2, 1, 2, 1)
        love.graphics.rectangle("fill", a:get())
        love.graphics.rectangle("fill", b:get())
        love.graphics.rectangle("fill", c:get())
        col:pop()
    end,
})

g.defineServer("ai_server", "AI Server", {
    price = 1000,
    computePerSecond = 10000,
    computePreference = {"ai"},
    load = 50,
    heatTolerance = {20, 90},
    heat = 60,
    color = objects.Color("#e37036"),
    draw = function(r)
        local col = gsman.setColor(0, 0, 0)
        local _, decorR = r:splitHorizontal(2, 1, 2)
        local a, _, b, _, c, _, d, _, e = decorR:set(nil, nil, nil, decorR.h * 0.1)
            :attachToBottomOf(decorR)
            :moveRatio(0, -1)
            :splitHorizontal(1, 1, 1, 1, 1, 1, 1, 1, 1)
        love.graphics.rectangle("fill", a:get())
        love.graphics.rectangle("fill", b:get())
        love.graphics.rectangle("fill", c:get())
        love.graphics.rectangle("fill", d:get())
        love.graphics.rectangle("fill", e:get())
        col:pop()
    end,
})
