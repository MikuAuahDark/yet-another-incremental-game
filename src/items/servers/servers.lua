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
---@field package draw (fun(itemData: g.World.ServerData))?

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
    draw = function(itemData)
        local size = consts.WORLD_TILE_SIZE * 0.75
        local col = gsman.mulColor(1, 1, 1)
        love.graphics.rectangle("fill", -size/2, -size/2, size, size)
        col:pop()
        col = gsman.mulColor(0, 0, 0)
        love.graphics.rectangle("line", -size/2, -size/2, size, size)
        if itemData.connectsTo then
            if itemData.currentJob then
                -- Working
                love.graphics.print("OK", g.getMainFont(16), -8, -8)
            else
                -- Idle
                love.graphics.print("IL", g.getMainFont(16), -8, -8)
            end
        else
            -- Not connected
            love.graphics.print("NC", g.getMainFont(16), -8, -8)
        end
        col:pop()
    end
})
