g.defineUpgrade("data_compression", "Data Compression", {
    description = "Reduces data output of jobs by %{1}.",
    kind = "EFFICIENCY",
    image = "compress",
    maxLevel = 10,
    getValues = helper.valueGetter(5, 5),
    valueFormatter = helper.PERCENTAGE_FORMATTER,
    getJobOutputDataMultiplier = function(uinfo, level)
        local val = uinfo:getValues(level)
        return 1 - val / 100
    end
})

g.defineUpgrade("higher_dps", "More Bandwidth", {
    description = "Increases data throughput by %{1}.",
    kind = "EFFICIENCY",
    image = "database",
    getValues = helper.valueGetter(5, 10),
    valueFormatter = helper.PERCENTAGE_FORMATTER,
    getDataThroughputMultiplier = function(uinfo, level)
        local val = uinfo:getValues(level)
        return 1 + val / 100
    end
})

g.defineUpgrade("higher_wire_dps", "More Wire Bandwidth", {
    description = "Increases wire data throughput by %{1}.",
    kind = "EFFICIENCY",
    image = "cable",
    getValues = helper.valueGetter(5, 10),
    valueFormatter = helper.PERCENTAGE_FORMATTER,
    drawUI = helper.genDrawUIIntuition("arrow_shape_up", "theme", "theme"),
    getWireThroughputMultiplier = function(uinfo, level)
        local val = uinfo:getValues(level)
        return 1 + val / 100
    end
})
