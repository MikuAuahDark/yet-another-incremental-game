
---@param r kirigami.Region
---@param n integer
---@param dist number
---@param len number
---@param thickness number
---@param extradist number?
local function drawDataInputDecorator(r, n, dist, len, thickness, extradist)
    -- Data input decoration is "arrow" pointing outwards
    local centerR = r:padRatio(0.5)
    local sz = math.sqrt(centerR.w * centerR.h)
    local d = dist * sz
    local width = len * sz
    local height = thickness * sz
    local hpx0 = height / 2
    local ed = (extradist or 0) * sz
    for i = 1, n do
        local t = math.sin((love.timer.getTime() + i / 5) * math.pi) ^ 2
        local hpx = hpx0 + t * sz / 45
        -- Top Left
        local baseX = centerR.x - ed - (i - 1) * d
        local baseY = centerR.y - ed - (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, width, height)
        love.graphics.rectangle("fill", baseX - hpx, baseY - hpx, height, width)
        -- Top Right
        baseX = centerR.x + centerR.w + ed + (i - 1) * d
        baseY = centerR.y - ed - (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -width, height)
        love.graphics.rectangle("fill", baseX + hpx, baseY - hpx, -height, width)
        -- Bottom Right
        baseX = centerR.x + centerR.w + ed + (i - 1) * d
        baseY = centerR.y + centerR.h + ed + (i - 1) * d
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -width, -height)
        love.graphics.rectangle("fill", baseX + hpx, baseY + hpx, -height, -width)
        -- Bottom Left
        baseX = centerR.x - ed - (i - 1) * d
        baseY = centerR.y + centerR.h + ed + (i - 1) * d
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, width, -height)
        love.graphics.rectangle("fill", baseX - hpx, baseY + hpx, height, -width)
    end

    return centerR:padRatio(0.3)
end

g.defineDataInput("basic_indata", "Basic Data Input", {
    price = 1,
    getPriceMultiplier = helper.valueGetterNoSelf(0.1, 1),
    load = 1,
    queuesJob = "general",
    maxJobQueue = 1,
    wireLength = 1,
    color = objects.Color("#ebe8c1"), -- Color-coded
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        drawDataInputDecorator(r, 2, 0.1075, 0.325, 0.0375, -0.1375)
        col:pop()
    end,
})

g.defineDataInput("indata_tier1", "General Data Input (Tier 1)", {
    price = 25,
    getPriceMultiplier = helper.valueGetterNoSelf(0.05, 1),
    jobFrequencyModifier = 0.05,
    load = 4,
    queuesJob = "general",
    maxJobQueue = 5,
    wireLength = 2,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        drawDataInputDecorator(r, 2, 0.1075, 0.325, 0.075, -0.1375)
        col:pop()
    end,
})

g.defineDataInput("indata_tier2", "General Data Input (Tier 2)", {
    price = 60,
    getPriceMultiplier = helper.valueGetterNoSelf(0.05, 1),
    jobFrequencyModifier = 0.075,
    jobFrequencyMultiplier = 1.1,
    load = 7,
    queuesJob = "general",
    maxJobQueue = 7,
    wireLength = 2,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        drawDataInputDecorator(r, 3, 0.1075, 0.325, 0.075, -0.1375)
        col:pop()
    end,
})



g.defineDataInput("video_indata", "Video Data Input (Tier 1)", {
    price = 80,
    getPriceMultiplier = helper.valueGetterNoSelf(0.15, 1),
    jobFrequencyModifier = 0.05,
    load = 6,
    queuesJob = "video",
    maxJobQueue = 5,
    wireLength = 2,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("movie", drawDataInputDecorator(r, 2, 0.1075, 0.325, 0.075, -0.1375):get())
        col:pop()
    end,
})

g.defineDataInput("video_indata_t2", "Video Data Input (Tier 2)", {
    price = 150,
    getPriceMultiplier = helper.valueGetterNoSelf(0.15, 1),
    jobFrequencyModifier = 0.06,
    jobFrequencyMultiplier = 1.075,
    load = 10,
    queuesJob = "video",
    maxJobQueue = 8,
    wireLength = 3,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("movie", drawDataInputDecorator(r, 3, 0.1075, 0.325, 0.075, -0.1375):get())
        col:pop()
    end,
})



g.defineDataInput("ai_indata", "AI Data Input", {
    price = 500,
    getPriceMultiplier = helper.valueGetterNoSelf(0.25, 1),
    jobFrequencyModifier = 0.0325,
    load = 25,
    queuesJob = "ai",
    maxJobQueue = 5,
    wireLength = 3,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("network_intelligence", drawDataInputDecorator(r, 2, 0.1075, 0.325, 0.075, -0.1375):get())
        col:pop()
    end,
})

g.defineDataInput("ai_indata_t2", "AI Data Input (Tier 2)", {
    price = 800,
    getPriceMultiplier = helper.valueGetterNoSelf(0.25, 1),
    jobFrequencyModifier = 0.05,
    jobFrequencyMultiplier = 1.05,
    load = 36,
    queuesJob = "ai",
    maxJobQueue = 8,
    wireLength = 4,
    draw = function(r)
        local col = gsman.mulColor(0, 0, 0)
        g.drawImageContained("network_intelligence", drawDataInputDecorator(r, 3, 0.1075, 0.325, 0.075, -0.1375):get())
        col:pop()
    end,
})
