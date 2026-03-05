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
---@field package draw (fun(itemData: g.World.DataProcessorData))?

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
        draw = function(itemData)
            ---@cast itemData g.World.DataProcessorData
            if def.draw then
                def.draw(itemData)
            end

            -- Draw connector lines across connected servevrs
            -- TODO: Make this fancy
            local lw = gsman.setLineWidth(4)
            love.graphics.setColor(1, 0.2, 0.2)
            for _, server in ipairs(itemData.connectsServers) do
                local reltx = server.tileX - itemData.tileX
                local relty = server.tileY - itemData.tileY
                love.graphics.line(0, 0, reltx * consts.WORLD_TILE_SIZE, relty * consts.WORLD_TILE_SIZE)
            end
            lw:pop()
        end
    })
end


defDP("basic_data", "Basic Data Processor", {
    price = 0,
    load = 1,
    dataPerSecond = 10,
    wireLength = 2,
    wireCount = 4,
    draw = function(itemData)
        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", 0, 0, consts.WORLD_TILE_SIZE * 0.375)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("line", 0, 0, consts.WORLD_TILE_SIZE * 0.375)
    end
})
