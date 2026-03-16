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
