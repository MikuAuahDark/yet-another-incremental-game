---@param id string
---@param def g.DataDefinition
local function defDP(id, def)
    return g.defineItem(id, {dataInfo = def})
end


defDP("basic_data", {
    name = "Data Processor",
    price = 0,
    dataPerSecond = 10,
    wireLength = 2,
    wireCount = 4
})
