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
