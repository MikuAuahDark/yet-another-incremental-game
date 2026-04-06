
---@param r kirigami.Region
---@param n integer
---@param dist number
---@param len number
---@param thickness number
local function drawDataInputDecorator(r, n, dist, len, thickness)
    -- Data input decoration is "arrow" pointing outwards
    local centerR = r:padRatio(0.75)
    local d = dist * math.sqrt(centerR.w * centerR.h)
    local width = len * math.sqrt(centerR.w * centerR.h)
    local height = thickness * math.sqrt(centerR.w * centerR.h)
    local hpx0 = height / 2
    for i = 1, n do
        local t = math.sin((love.timer.getTime() + i / 5) * math.pi) ^ 2
        local hpx = hpx0 + t * 2
        -- Top Left
        local baseX = centerR.x - (i - 1) * d
        local baseY = centerR.y - (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, width, height)
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, height, width)
        -- Top Right
        baseX = centerR.x + centerR.w + (i - 1) * d
        baseY = centerR.y - (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -width, height)
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -height, width)
        -- Bottom Right
        baseX = centerR.x + centerR.w + (i - 1) * d
        baseY = centerR.y + centerR.h + (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -width, -height)
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -height, -width)
        -- Bottom Left
        baseX = centerR.x - (i - 1) * d
        baseY = centerR.y + centerR.h + (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, width, -height)
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, height, -width)
    end

    return centerR
end

g.defineDataInput("basic_indata", "Basic Data Input", {
    price = 0,
    load = 1,
    queuesJob = "general",
    maxJobQueue = 1,
    wireLength = 2,
    color = objects.Color("#ebe8c1"), -- Color-coded
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        drawDataInputDecorator(r, 2, 0.25, 0.35, 0.05)
        col:pop()
    end,
})
g.PREUNLOCKED_ITEMS:add("basic_indata")

g.defineDataInput("indata_tier1", "General Data Input (Tier 1)", {
    price = 10,
    load = 7,
    queuesJob = "general",
    maxJobQueue = 5,
    wireLength = 4,
    color = objects.Color("#ebe883"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        drawDataInputDecorator(r, 2, 0.2, 0.4, 0.08)
        col:pop()
    end,
})

g.defineDataInput("indata_tier2", "General Data Input (Tier 2)", {
    price = 35,
    load = 15,
    queuesJob = "general",
    maxJobQueue = 7,
    wireLength = 6,
    color = objects.Color("#ebe883"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        drawDataInputDecorator(r, 3, 0.2, 0.5, 0.08)
        col:pop()
    end,
})



g.defineDataInput("video_indata", "Video Data Input (Tier 1)", {
    price = 50,
    load = 10,
    queuesJob = "video",
    maxJobQueue = 5,
    wireLength = 4,
    color = objects.Color("#6fb3e8"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("movie", drawDataInputDecorator(r, 2, 0.2, 0.4, 0.08):get())
        col:pop()
    end,
})

g.defineDataInput("video_indata_t2", "Video Data Input (Tier 2)", {
    price = 80,
    load = 10,
    queuesJob = "video",
    maxJobQueue = 8,
    wireLength = 5,
    color = objects.Color("#6fb3e8"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("movie", drawDataInputDecorator(r, 3, 0.2, 0.5, 0.08):get())
        col:pop()
    end,
})



g.defineDataInput("ai_indata", "AI Data Input", {
    price = 500,
    load = 20,
    queuesJob = "ai",
    maxJobQueue = 5,
    wireLength = 5,
    color = objects.Color("#e37036"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("network_intelligence", drawDataInputDecorator(r, 2, 0.2, 0.4, 0.08):get())
        col:pop()
    end,
})

g.defineDataInput("ai_indata_t2", "AI Data Input (Tier 2)", {
    price = 800,
    load = 25,
    queuesJob = "ai",
    maxJobQueue = 8,
    wireLength = 5,
    color = objects.Color("#e37036"),
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("network_intelligence", drawDataInputDecorator(r, 3, 0.2, 0.5, 0.08):get())
        col:pop()
    end,
})
