g.defineDataProcessor("basic_data", "Basic Data Processor", {
    price = 0,
    load = 1,
    dataPerSecond = 10,
    wireLength = 2,
    wireCount = 4,
    color = objects.Color("#ebc965"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        for i = 0, 3 do
            local a = (i * math.pi) / 4
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
