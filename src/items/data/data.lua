---@class _DataDef
---@field package nameContext string?
---@field package rawDescription string?
---@field package description string?
---@field package descriptionContext string?
---@field package price number
---@field package load number
---@field package dataPerSecond number
---@field package wireLength integer
---@field package wireCount integer|nil
---@field package draw (fun(itemData: g.World.ItemData))?

---@param id string
---@param name string
---@param def _DataDef
local function defDP(id, name, def)
    return g.defineItem(id, {
        category = "data",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        price = def.price,
        load = def.load,
        dataPerSecond = def.dataPerSecond,
        wireLength = def.wireLength,
        wireCount = def.wireCount,
        draw = def.draw
    })
end


defDP("basic_data", "Basic Data Processor", {
    price = 0,
    load = 1,
    dataPerSecond = 10,
    wireLength = 2,
    wireCount = 4
})
