g.defineUpgrade("faster_servers", "Faster Servers", {
    description = "Increases server Compute Per Second by %{1}.",
    kind = "EFFICIENCY",
    image = "dns",
    getValues = helper.valueGetter(5, 10),
    valueFormatter = helper.PERCENTAGE_FORMATTER,
    drawUI = helper.genDrawUIIntuition("arrow_shape_up", "theme", "theme"),
    getPerformanceMultiplier = function(uinfo, level)
        local val = uinfo:getValues(level)
        return 1 + val / 100
    end
})
