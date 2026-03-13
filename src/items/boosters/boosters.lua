g.defineBooster("water_cooler", "Water Cooler", {
    description = "Reduces tile heat by 10.",
    price = 10,
    load = 1,
    radiate = 1,
    radiateAlgorithm = "chessboard",
    color = objects.Color("#a2e5f2"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        g.drawImageContained("water_drop", r:get())
        col:pop()
    end,
    getTileHeat = function(reltx, relty)
        return -10
    end,
    isItemUnlocked = function(uinfo, level, iid)
        return iid == "water_cooler"
    end
})

g.defineBooster("ice_cooler", "Ice Cooler", {
    description = "Reduces tile heat by 50.",
    price = 10,
    load = 1,
    radiate = 4,
    radiateAlgorithm = "taxicab",
    color = objects.Color("#a2e5f2"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        g.drawImageContained("water_drop", r:get())
        col:pop()
    end,
    getTileHeat = function(reltx, relty)
        return -50
    end,
    isItemUnlocked = function(uinfo, level, iid)
        return iid == "ice_cooler"
    end
})

g.defineBooster("overclocker", "Overclock", {
    description = "Increase server performance by 25%.",
    price = 10,
    load = 1,
    radiate = 1,
    radiateAlgorithm = "taxicab",
    color = objects.Color("#a2e5f2"),
    draw = function(r)
        -- Draw decor
        local col = gsman.mulColor(1, 1, 1, 0.4)
        g.drawImageContained("quick_reorder", r:get())
        col:pop()
    end,
    getPerformanceMultiplier = function(reltx, relty)
        return 1.25
    end,
    isItemUnlocked = function(uinfo, level, iid)
        return iid == "overclocker"
    end
})
