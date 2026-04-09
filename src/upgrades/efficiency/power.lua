g.defineUpgrade("efficient_machine", "Eco-friendly Machine", {
    description = "Reduces power consumption by %{1}.",
    kind = "EFFICIENCY",
    image = "energy_program_saving",
    getValues = helper.valueGetter(5, 5),
    valueFormatter = helper.PERCENTAGE_FORMATTER,

    ---@param uinfo g.UpgradeInfo
    ---@param level integer
    getLoadMultiplier = function(uinfo, level)
        local val = uinfo:getValues(level)
        return 1 - val / 100
    end
})
