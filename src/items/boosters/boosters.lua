---@param r kirigami.Region
---@param npipes integer
local function drawConnectableDecor(r, npipes)
    local LENGTH = 0.6
    local col = gsman.mulColor(objects.Color("FFE58609"))
    local radius = math.sqrt(r.w * r.h) / 2
    local cx, cy = r:getCenter()
    local lw = gsman.setLineWidth(0.1 * radius)

    for i = 0, npipes - 1 do
        local a = i / npipes * 2 * math.pi + math.pi / 2
        local x = math.cos(a)
        local y = math.sin(a)
        love.graphics.line(cx + x * radius, cy + y * radius, cx + x * radius * LENGTH, cy + y * radius * LENGTH)
    end

    lw:pop()
    col:pop()
end



------------------
-- Heat-related --
------------------

g.defineBooster("water_cooler", "Water Cooler", {
    description = "Reduces tile heat by 10.",
    price = 100,
    load = 7,
    radiate = 1,
    radiateAlgorithm = "chessboard",
    color = objects.Color("FF58AEDD"),
    draw = function(r)
        -- Draw decor
        g.drawImageContained("water_drop", r:padRatio(0.25):get())
    end,
    getTileHeat = function(reltx, relty)
        return -10
    end,
})

g.defineBooster("piped_water_cooler", "Piped Water Cooler", {
    description = "Reduces tile heat by 10.",
    price = 30,
    load = 4,
    radiate = 1,
    radiateAlgorithm = "chessboard",
    color = objects.Color("FF58AEDD"),
    connectable = {
        max = 4,
        target = "server"
    },
    draw = function(r)
        -- Draw decor
        drawConnectableDecor(r, 4)
        g.drawImageContained("water_drop", r:padRatio(0.25):get())
    end,
    getTileHeat = function(reltx, relty)
        return -10
    end,
})

g.defineBooster("ice_cooler", "Ice Cooler", {
    description = "Reduces tile heat by 40.",
    price = 350,
    load = 18,
    radiate = 4,
    radiateAlgorithm = "taxicab",
    color = objects.Color("FF93D7E5"),
    draw = function(r)
        -- Draw decor
        g.drawImageContained("snowflake", r:padRatio(0.25):get())
    end,
    getTileHeat = function(reltx, relty)
        return -40
    end,
})

g.defineBooster("piped_ice_cooler", "Piped Ice Cooler", {
    description = "Reduces tile heat by 30.",
    price = 150,
    load = 10,
    radiate = 4,
    radiateAlgorithm = "taxicab",
    color = objects.Color("FF93D7E5"),
    connectable = {
        max = 6,
        target = "server"
    },
    draw = function(r)
        -- Draw decor
        drawConnectableDecor(r, 6)
        g.drawImageContained("snowflake", r:padRatio(0.25):get())
    end,
    getTileHeat = function(reltx, relty)
        return -30
    end,
})



------------------
-- Load-related --
------------------

g.defineBooster("power_efficiency", "Power Efficiency", {
    description = "Reduces server load by 20% but reduces performance by 8%.",
    price = 200,
    load = 1,
    radiate = 3,
    radiateAlgorithm = "taxicab",
    color = objects.Color("FF5FD35F"),
    draw = function(r)
        -- Draw decor
        g.drawImageContained("energy_savings_leaf", r:padRatio(0.25):get())
    end,
    getLoadMultiplier = function(reltx, relty)
        return 0.80
    end,
    getPerformanceMultiplier = function(reltx, relty)
        return 0.92
    end,
})

g.defineBooster("pfc", "Power Factor Correction", {
    description = "Reduces server load by 15% but reduces performance by 5%.",
    price = 100,
    load = 1,
    radiate = 2,
    radiateAlgorithm = "chessboard",
    color = objects.Color("FF499A49"),
    connectable = {
        max = 6,
        target = "server",
    },
    draw = function(r)
        -- Draw decor
        drawConnectableDecor(r, 6)
        g.drawImageContained("energy_savings_leaf", r:padRatio(0.5):get())
    end,
    getLoadMultiplier = function(reltx, relty)
        return 0.85
    end,
    getPerformanceMultiplier = function(reltx, relty)
        return 0.95
    end,
})

g.defineBooster("wired_pe", "Wired Power Efficiency", {
    description = "Reduces server load by 35% but reduces performance by 13%.",
    price = 100,
    load = 1,
    radiate = 2,
    radiateAlgorithm = "chessboard",
    color = objects.Color("FF34AD73"),
    connectable = {
        max = 8,
        target = "server",
    },
    draw = function(r)
        -- Draw decor
        drawConnectableDecor(r, 8)
        g.drawImageContained("energy_program_saving", r:padRatio(0.25):get())
    end,
    getLoadMultiplier = function(reltx, relty)
        return 0.65
    end,
    getPerformanceMultiplier = function(reltx, relty)
        return 0.87
    end,
})



-------------------
-- Speed-related --
-------------------

g.defineBooster("overclocker", "Overclock", {
    description = "Increase server performance by 25% but increases load by 10%.",
    price = 10,
    load = 1,
    radiate = 1,
    radiateAlgorithm = "taxicab",
    color = objects.Color("FFD24D38"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1)
        g.drawImageContained("quick_reorder", r:padRatio(0.25):get())
        col:pop()
    end,
    getPerformanceMultiplier = function(reltx, relty)
        return 1.25
    end,
    getLoadMultiplier = function(reltx, relty)
        return 1.1
    end
})

g.defineBooster("selective_tweaks", "Selective Tweaks", {
    description = "Increase server performance by 20% but increases load by 7%.",
    price = 10,
    load = 1,
    radiate = 2,
    radiateAlgorithm = "chessboard",
    color = objects.Color("FF9973EC"),
    connectable = {
        max = 6,
        target = "server",
    },
    draw = function(r)
        -- Draw decor
        drawConnectableDecor(r, 6)
        g.drawImageContained("quick_reorder", r:padRatio(0.5):get())
    end,
    getPerformanceMultiplier = function(reltx, relty)
        return 1.2
    end,
    getLoadMultiplier = function(reltx, relty)
        return 1.07
    end
})
