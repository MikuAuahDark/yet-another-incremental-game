---@class _ServerDef
---@field package nameContext string?
---@field package rawDescription string?
---@field package description string?
---@field package descriptionContext string?
---@field package price number
---@field package load number
---@field package computePerSecond number
---@field package computePreference string[]
---@field package heatTolerance [number, number]
---@field package heat number
---@field package draw (fun(itemData: g.World.ItemData))?

---@param id string
---@param name string
---@param def _ServerDef
local function defServer(id, name, def)
    return g.defineItem(id, {
        category = "server",
        name = name,
        nameContext = def.nameContext,
        rawDescription = def.rawDescription,
        description = def.description,
        descriptionContext = def.descriptionContext,
        load = def.load,
        price = def.price,
        computePerSecond = def.computePerSecond,
        computePreference = def.computePreference,
        heatTolerance = def.heatTolerance,
        heat = def.heat,
        draw = def.draw,
    })
end


defServer("basic_server", "Basic Server", {
    price = 0,
    computePerSecond = 1,
    computePreference = {"general"},
    load = 1,
    heatTolerance = {40, 60},
    heat = 40,
})
