---@param id string
---@param def g.ServerDefinition
local function defServer(id, def)
    return g.defineItem(id, {serverInfo = def})
end


defServer("basic_server", {
    name = "Basic Server",
    price = 0,
    computePerSecond = 1,
    computePreference = {"general"},
    load = 1,
    heatTolerance = {40, 60},
    heat = 40,
})
