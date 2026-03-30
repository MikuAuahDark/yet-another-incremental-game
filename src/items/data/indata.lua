g.defineDataInput("basic_indata", "Basic Data Input", {
    price = 0,
    load = 1,
    queuesJob = "general",
    maxJobQueue = 10,
    wireLength = 2,
    color = objects.Color("#b0b0b0"), -- Black/Grey for input
    draw = function(r)
        -- Draw decor: Inverse of Data Output (pointing inwards)
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        for i = 0, 3 do
            local a = (i * math.pi * 2) / 4
            local x1 = cx + r.w / 5 * math.cos(a)
            local y1 = cy + r.h / 5 * math.sin(a)
            local x2 = cx + r.w / 3 * math.cos(a)
            local y2 = cy + r.h / 3 * math.sin(a)
            love.graphics.line(x1, y1, x2, y2)
        end
        lw:pop()
        col:pop()
    end,
})

g.defineDataInput("video_indata", "Video Data Input", {
    price = 50,
    load = 5,
    queuesJob = "video",
    maxJobQueue = 20,
    wireLength = 3,
    color = objects.Color("#6fb3e8"),
    draw = function(r)
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        for i = 0, 3 do
            local a = (i * math.pi * 2) / 4 + math.pi / 4
            local x1 = cx + r.w / 6 * math.cos(a)
            local y1 = cy + r.h / 6 * math.sin(a)
            local x2 = cx + r.w / 3 * math.cos(a)
            local y2 = cy + r.h / 3 * math.sin(a)
            love.graphics.line(x1, y1, x2, y2)
        end
        lw:pop()
        col:pop()
    end,
})

g.defineDataInput("ai_indata", "AI Data Input", {
    price = 500,
    load = 20,
    queuesJob = "ai",
    maxJobQueue = 50,
    wireLength = 5,
    color = objects.Color("#e37036"),
    draw = function(r)
        local col = gsman.mulColor(1, 1, 1, 0.4)
        local cx, cy = r:getCenter()
        local lw = gsman.setLineWidth(4)
        love.graphics.circle("line", cx, cy, r.w / 4)
        for i = 0, 7 do
            local a = (i * math.pi * 2) / 8
            local x1 = cx + r.w / 8 * math.cos(a)
            local y1 = cy + r.h / 8 * math.sin(a)
            local x2 = cx + r.w / 4 * math.cos(a)
            local y2 = cy + r.h / 4 * math.sin(a)
            love.graphics.line(x1, y1, x2, y2)
        end
        lw:pop()
        col:pop()
    end,
})
