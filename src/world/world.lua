--[[

World

]]


local ParticleService = require(".particle.ParticleService")
local DataCollector = require(".data_collector")


---@param grid objects.Grid
local function zeroTileHeat(grid)
    for x = 0, grid.width-1 do
        for y = 0, grid.height-1 do
            grid:set(x,y, 0)
        end
    end
end


---@class g.World.ItemData
---@field type string Item ID
---@field tileX integer (readonly; updated every frame)
---@field tileY integer (readonly; updated every frame)
---@field load number (readonly; updated every frame)
---@field powerNetwork g.World.PowerNetwork? (readonly; if nil = not connected to any network)
---@field removed boolean
---@field removable boolean

---@class g.World.BoosterData: g.World.ItemData
---@field connectsTo g.World.ItemData[]
---@field effectiveness number
---@field package animationTime number (duration cycles)

---@class g.World.ServerData: g.World.ItemData
---@field currentJob g.Job?
---@field dataTotalEmitted number (readwrite; if same as currentJob.dataOutput then done)
---@field connectedOutputs g.World.DataOutputWire[] (readonly; connected data outputs, quick lookup only)
---@field connectedInputs g.World.DataInputWire[] (readonly; connected data inputs, quick lookup only)
---@field computePerSecond number (readonly; updated every frame) CPS with heat, buff, and load applied
---@field nextInput integer (wraparound, 0-based)
---@field nextOutput integer (wraparound, 0-based)
---@field dataBottlenecked boolean

---@class g.World.DataInputData: g.World.ItemData
---@field wireDPS number (readonly; updated every frame)
---@field connects g.World.DataInputWire[] (readwrite; connects to this server, source of truth)
---@field next integer (wraparound, 0-based)

---@class g.World.DataOutputData: g.World.ItemData
---@field connects g.World.DataOutputWire[] (readwrite; connects to this server, source of truth)
---@field dataPerSecond number (readonly; updated every frame)
---@field wireDPS number (readonly; updated every frame)
---@field dataRemaining number
---@field reward number
---@field rewardToShow number
---@field next integer (wraparound, 0-based)
---@field package requestedLoad number
---@field package dataScale number

---@class g.World.PowerData: g.World.ItemData
---@field power number (readonly; updated every frame)
---@field connectsTo g.World.ItemData[] (readwrite; connected power consumers)
---@field connectsPowerNodes g.World.PowerData[] (readonly; connected power nodes generated dynamically)

---@class g.World.PowerNetwork
---@field generators g.World.PowerData[]
---@field relays g.World.PowerData[]
---@field consumers g.World.ItemData[]
---@field totalPower number (readonly; updated every frame)
---@field totalLoad number (readonly; updated every frame)

---@generic U, T: g.World.ItemData
---@class g.World.Wire<T, U>
---@field source T
---@field server g.World.ServerData
---@field objects U[]
---@field positions number[] normalized [0, 1]

---@alias g.World.DataInputWire g.World.Wire<g.World.DataInputData, g.Job>
---@alias g.World.DataOutputWire g.World.Wire<g.World.DataOutputData, number>


---@class g.World: objects.Class
local World = objects.Class("g:World")
World.TILE_SIZE = 101


local UNHIGHLIGHT_ALPHA = 0.2
local HIGHLIGHT_ALPHA = 1


---@param cx number
---@param cy number
---@param r number
---@param marginDeg number
---@param rng love.RandomGenerator
local function generateTriangle(cx, cy, r, marginDeg, rng)
    marginDeg = marginDeg or 20
    ---@type [number,number][]
    local vertices = {}
    local sectorSize = 360 / 3

    for i = 0, 2 do
        local start = i * sectorSize + marginDeg
        local finish = (i + 1) * sectorSize - marginDeg

        local angle = rng:random() * (finish - start) + start
        local angleRad = math.rad(angle)

        local px = cx + r * math.cos(angleRad)
        local py = cy + r * math.sin(angleRad)

        vertices[#vertices+1] = {px, py}
    end

    return vertices
end

---@param seed integer
local function generateWorldTexture(seed)
    -- Create tile "texture"
    local rng = love.math.newRandomGenerator(seed)
    ---@type [number,number,number,number,number?,number?,number?,number?][]
    local vertices = {}
    local wtz = consts.WORLD_TILE_SIZE * World.TILE_SIZE
    for _ = 1, 5000 do
        local radius = helper.lerp(4, 24, rng:random()) * 2
        local ox = helper.lerp(radius, wtz - radius, rng:random())
        local oy = helper.lerp(radius, wtz - radius, rng:random())
        local verts = generateTriangle(ox, oy, radius, 20, rng)

        for _, v in ipairs(verts) do
            vertices[#vertices+1] = {v[1], v[2], v[1]/wtz, v[2]/wtz, 0.5, 0.5, 0.5, helper.lerp(0.3, 0.7, rng:random())}
        end
    end

    return love.graphics.newMesh(vertices, "triangles", "static")
end


---@param x1 number from X
---@param y1 number from Y
---@param x2 number to X
---@param y2 number to Y
---@param spacing number
---@param offset number?
local function drawArrows(x1, y1, x2, y2, spacing, offset)
    offset = offset or 0.5
    local dist = helper.magnitude(x2 - x1, y2 - y1)
    local narrows = math.max(math.floor(dist / spacing), 1)
    local r = math.atan2(y2 - y1, x2 - x1)

    for i = 0, narrows - 1 do
        local t = (i + offset) / narrows
        local treal = t * dist
        local alpha = 1
        if treal < spacing then
            alpha = treal / spacing
        elseif treal > dist - spacing then
            alpha = (dist - treal) / spacing
        end
        local c = gsman.mulColor(1, 1, 1, helper.EASINGS.sineOut(alpha))
        local cx = helper.lerp(x1, x2, t)
        local cy = helper.lerp(y1, y2, t)
        g.drawImage("arrow_right", cx, cy, r, 0.2, 0.2)
        c:pop()
    end
end

---@param tx integer
---@param ty integer
---@param algo g.RadiateAlgorithm
---@param dist integer
local function drawRangeVisualization(tx, ty, algo, dist)
    local t = math.sin((love.timer.getTime() % 1) * math.pi) ^ 2
    local alpha = helper.remap(t, 0, 1, 0.025, 0.1)

    local tiles = worldutil.getSpreadTiles(algo, dist)
    local col = gsman.setColor(0, 1, 0, alpha)
    for _, tile in ipairs(tiles) do
        local absTx = tile[1] + tx
        local absTy = tile[2] + ty
        local x = (absTx) * consts.WORLD_TILE_SIZE
        local y = (absTy) * consts.WORLD_TILE_SIZE
        love.graphics.rectangle("fill", x, y, consts.WORLD_TILE_SIZE, consts.WORLD_TILE_SIZE)
    end
    col:pop()
end


local POWER_COLOR = objects.Color("#83d6d3")

---@param powerNetwork g.World.PowerNetwork
---@param visibleArea kirigami.Region
---@param htx integer?
---@param hty integer?
local function drawPowerLines(powerNetwork, visibleArea, htx, hty)
    local wtz = consts.WORLD_TILE_SIZE
    local t = g.getSn().worldTime % 1

    -- Generator always one way. Generator -> Relay/Consumer.
    for _, node in ipairs(powerNetwork.generators) do
        local nodeSelected = htx == node.tileX and hty == node.tileY
        local x1 = (node.tileX + 0.5) * wtz
        local y1 = (node.tileY + 0.5) * wtz
        local nodeHasCoords = visibleArea:containsCoords(x1, y1)

        for _, other in ipairs(node.connectsPowerNodes) do
            local x2, y2 = (other.tileX + 0.5) * wtz, (other.tileY + 0.5) * wtz

            if nodeHasCoords or visibleArea:containsCoords(x2, y2) then
                if nodeSelected or htx == other.tileX and hty == other.tileY then
                    love.graphics.setColor(POWER_COLOR)
                    drawArrows(x1, y1, x2, y2, 6, t)
                end
            end
        end

        for _, other in ipairs(node.connectsTo) do
            local _, cat = g.getItemInfo(other.type)
            if cat ~= "powergen" then
                local x2, y2 = (other.tileX + 0.5) * wtz, (other.tileY + 0.5) * wtz

                if nodeHasCoords or visibleArea:containsCoords(x2, y2) then
                    if nodeSelected or htx == other.tileX and hty == other.tileY then
                        love.graphics.setColor(POWER_COLOR)
                        drawArrows(x1, y1, x2, y2, 6, t)
                    end
                end
            end
        end
    end

    -- Relay is
    -- * Two-way for Relay <-> Relay.
    -- * One-way for Relay -> Consumer.
    for _, node in ipairs(powerNetwork.relays) do
        local nodeSelected = htx == node.tileX and hty == node.tileY
        local x1 = (node.tileX + 0.5) * wtz
        local y1 = (node.tileY + 0.5) * wtz
        local nodeHasCoords = visibleArea:containsCoords(x1, y1)

        for _, other in ipairs(node.connectsPowerNodes) do
            local _, cat = g.getItemInfo(other.type)
            if cat ~= "powergen" then
                local x2, y2 = (other.tileX + 0.5) * wtz, (other.tileY + 0.5) * wtz

                if nodeHasCoords or visibleArea:containsCoords(x2, y2) then
                    if nodeSelected or htx == other.tileX and hty == other.tileY then
                        love.graphics.setColor(POWER_COLOR)
                        drawArrows(x1, y1, x2, y2, 6, t)
                    end
                end
            end
        end

        for _, other in ipairs(node.connectsTo) do
            local _, cat = g.getItemInfo(other.type)
            if cat ~= "powergen" then
                local x2, y2 = (other.tileX + 0.5) * wtz, (other.tileY + 0.5) * wtz

                if nodeHasCoords or visibleArea:containsCoords(x2, y2) then
                    if nodeSelected or htx == other.tileX and hty == other.tileY then
                        love.graphics.setColor(POWER_COLOR)
                        drawArrows(x1, y1, x2, y2, 6, t)
                    end
                end
            end
        end
    end
end


---This uses 1x1 from `g.drawImage` instead of `love.graphics.line` to improve batching.
---@param x1 number from X
---@param y1 number from Y
---@param x2 number to X
---@param y2 number to Y
---@param thickness number
local function drawLine(x1, y1, x2, y2, thickness)
    local mx = (x1 + x2) / 2
    local my = (y1 + y2) / 2
    local angle = math.atan2(y2 - y1, x2 - x1)
    local dist = helper.magnitude(x2 - x1, y2 - y1)
    g.drawImage("1x1", mx, my, angle, dist, thickness / 2)
end


local PHYSICAL_DATA_SIZE = 5

---@param wire g.World.Wire<g.World.ItemData, any>
local function getWireLength(wire)
    return helper.magnitude(
        wire.server.tileX - wire.source.tileX,
        wire.server.tileY - wire.source.tileY
    ) * consts.WORLD_TILE_SIZE
end

---@param lp number
---@param wdps number
---@param dt number
---@param wire g.World.Wire<g.World.ItemData, any>
local function updateWire(lp, wdps, dt, wire)
    local lp2 = math.max(worldutil.getLoadPercentage(wire.server), lp)
    local wireLength = getWireLength(wire)
    local padding = PHYSICAL_DATA_SIZE / wireLength
    local ndt = (wdps * dt * lp2) / wireLength

    for i = #wire.positions, 1, -1 do
        local wall
        if wire.positions[i + 1] then
            wall = wire.positions[i + 1] - padding
        else
            wall = 1 -- Make sure exact value
        end

        wire.positions[i] = helper.clamp(wire.positions[i] + ndt, 0, wall)
    end
end

---@param category g.JobCategory
local function makeDataInputFilter(category)
    ---@param item g.World.ItemData
    return function(item)
        local itemInfo, cat = g.getItemInfo(item.type)
        if cat == "indata" then
            ---@cast itemInfo g.DataInInfo
            if itemInfo.queuesJob == category then
                ---@cast item g.World.DataInputData
                for _, wire in ipairs(item.connects) do
                    local maxWireCap = math.floor(getWireLength(wire) / PHYSICAL_DATA_SIZE)
                    if #wire.objects < maxWireCap then
                        return true
                    end
                end
            end
        end

        return false
    end
end

---@param grid objects.Grid<g.World.ItemData[]>
---@param item g.World.ItemData
---@param length integer
local function markExistInArea(grid, item, length)
    for _, tile in ipairs(worldutil.getSpreadTiles("chessboard", length)) do
        local tx, ty = tile[1] + item.tileX, tile[2] + item.tileY
        if grid:contains(tx, ty) then
            table.insert(grid:get(tx, ty), item)
        end
    end
end

---@type table<g.JobCategory, fun(g.World.ItemData):boolean>
local DATA_INPUT_CYCLE_FILTER = {
    general = makeDataInputFilter("general"),
    video = makeDataInputFilter("video"),
    ai = makeDataInputFilter("ai")
}


function World:init()
    self.entities = objects.BufferedSet()
    ---@type objects.Grid<g.World.ItemData?>
    self.items = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    ---@type objects.Grid<number>
    self.heat = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    ---@type table<g.JobCategory, number>
    self.jobFreqModByCategory = setmetatable({}, {__index = function() return 0 end})
    ---@type table<g.JobCategory, number>
    self.jobFreqMulByCategory = setmetatable({}, {__index = function() return 1 end})

    ---@type table<integer, g.World.BoosterData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.boosters = {}
    ---@type table<integer, g.World.ItemData[]>
    self.boostersInTiles = {}
    ---@type table<integer, g.World.DataOutputData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.dataProcessors = {}
    ---@type table<integer, g.World.DataInputData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.dataInputs = {}
    ---@type table<integer, g.World.ServerData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.servers = {}
    ---@type table<integer, g.World.PowerData>
    self.powerGens = {}
    ---@type table<integer, g.World.PowerData>
    self.powerRelays = {}
    ---@type g.World.PowerNetwork[]
    self.powerNetworks = {}
    self.particles = ParticleService()
    self.timer = 0 -- For per second update
    self.seconds = 0 -- how many seconds have elapsed (perSecondUpdate)
    self.analyticsSendTime = 0
    zeroTileHeat(self.heat)

    self.cpsCollector = DataCollector(60)
    ---@type table<string, {dirty:boolean,modifier:number,multiplier:number}>
    self.loadModifiers = {}
    -- 1st value is current time, 2nd value is spawn time, 3rd value is coordinate cycle (0-based)
    ---@type table<string, [number,number,number]>
    self.jobPoller = {}
    for jobType in pairs(g.VALID_JOBS) do
        self.jobPoller[jobType] = {0, 0, 0}
    end

    self.worldTexture = generateWorldTexture(12345)

    ---@type integer?
    self.htx = nil
    ---@type integer?
    self.hty = nil

    ---@type table<string, integer>
    self.itemCounts = setmetatable({}, {__index = function() return 0 end})
    ---@type table<string, integer?> Putting it in world for caching
    self.itemInventoryCounts = {}

    self.averageCPS = 0 -- (read-only)
    self.peakCPS = 0 -- (read-only)

    ---@type objects.Grid<g.World.DataInputData[]>
    self.diAreaAutoConnect = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    self.diAreaAutoConnect:foreach(function(v, x, y) self.diAreaAutoConnect:set(x, y, {}) end)
    ---@type objects.Grid<g.World.DataOutputData[]>
    self.doAreaAutoConnect = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    self.doAreaAutoConnect:foreach(function(v, x, y) self.doAreaAutoConnect:set(x, y, {}) end)
    self.autowire = true
end



---@param e g.Entity
local function drawEntity(e)
    if e.drawBelow then
        love.graphics.setColor(1, 1, 1)
        e:drawBelow()
    end

    local sx,sy = e.sx or 1, e.sy or 1
    if e.bulgeAnimation then
        local blg = assert(e.bulgeAnimation)
        local mag = 1 + (blg.time/blg.duration)*blg.magnitude
        sx = sx * mag
        sy = sy * mag
    end

    if e.image then
        -- We need this need blendmode boolean check.
        -- LOVE doesn't check the blending mode internally
        -- and will always break batching even if the specified
        -- blend mode in `setBlendMode` is same as `getBlendMode`.
        local needblendmode = e.blendmode or e.blendalphamode

        love.graphics.setColor(1, 1, 1, e.alpha or 1)

        if needblendmode then
            love.graphics.setBlendMode(e.blendmode or "alpha", e.blendalphamode or "alphamultiply")
        end

        g.drawImage(e.image, e.x+(e.ox or 0), e.y+(e.oy or 0), e.rot or 0, sx,sy)

        if needblendmode then
            love.graphics.setBlendMode("alpha", "alphamultiply")
        end
    end

    if e.draw then
        love.graphics.setColor(1, 1, 1)
        e:draw()
    end
end


---@param dt number
function World:_update(dt)
    self.entities:flush()

    for _, e in ipairs(self.entities) do
        ---@cast e g.Entity
        if e.update then
            e:update(dt)
        end

        if e.bulgeAnimation then
            local blg = assert(e.bulgeAnimation)
            blg.time = math.max(0, blg.time - dt)
        end

        if e.lifetime then
            e.lifetime = e.lifetime - dt
            if e.lifetime <= 0 then
                self.entities:removeBuffered(e)
            end
        end
    end

    -- Mark cached modifier as dirty
    -- It's less garbage to mark it dirty than table.clearing it.
    for _, v in pairs(self.loadModifiers) do
        v.dirty = true
    end

    -- Update electricity load
    local loads = 0
    table.clear(self.jobFreqModByCategory)
    table.clear(self.jobFreqMulByCategory)
    table.clear(self.boosters)
    table.clear(self.boostersInTiles)
    table.clear(self.dataProcessors)
    table.clear(self.dataInputs)
    self.diAreaAutoConnect:foreach(table.clear)
    self.doAreaAutoConnect:foreach(table.clear)
    table.clear(self.servers)
    table.clear(self.powerGens)
    table.clear(self.powerRelays)
    table.clear(self.powerNetworks)
    table.clear(self.itemCounts)
    table.clear(self.itemInventoryCounts)
    ---@param item g.World.ItemData?
    self.items:foreach(function(item, x, y)
        if item then
            local itemInfo, category = g.getItemInfo(item.type)
            item.load = self:computeLoadModifier(itemInfo)
            item.powerNetwork = nil
            self.itemCounts[item.type] = self.itemCounts[item.type] + 1

            loads = loads + item.load
            local index = self.items:coordsToIndex(x, y)

            if category == "booster" then
                ---@cast item g.World.BoosterData
                self.boosters[index] = item
                item.effectiveness = 1
                table.clear(item.connectsTo)
            elseif category == "data" then
                ---@cast item g.World.DataOutputData
                ---@cast itemInfo g.DataOutInfo
                self.dataProcessors[index] = item
                markExistInArea(self.doAreaAutoConnect, item, itemInfo.wireLength)
            elseif category == "indata" then
                ---@cast item g.World.DataInputData
                ---@cast itemInfo g.DataInInfo
                self.dataInputs[index] = item
                self.jobFreqModByCategory[itemInfo.queuesJob] = self.jobFreqModByCategory[itemInfo.queuesJob] + itemInfo.jobFrequencyModifier
                self.jobFreqMulByCategory[itemInfo.queuesJob] = self.jobFreqMulByCategory[itemInfo.queuesJob] * itemInfo.jobFrequencyMultiplier
                markExistInArea(self.diAreaAutoConnect, item, itemInfo.wireLength)
            elseif category == "server" then
                ---@cast item g.World.ServerData
                self.servers[index] = item
                item.dataBottlenecked = false
                table.clear(item.connectedInputs)
                table.clear(item.connectedOutputs)
            elseif category == "powergen" then
                ---@cast item g.World.PowerData
                self.powerGens[index] = item
            elseif category == "powerrelay" then
                ---@cast item g.World.PowerData
                self.powerRelays[index] = item
            end

            -- Update tile positions
            item.tileX = x
            item.tileY = y
        end
    end)

    -- Update booster connections and effectiveness
    for _, booster in pairs(self.boosters) do
        ---@cast booster g.World.BoosterData
        local boosterInfo = g.getItemInfo(booster.type, "booster")
        if boosterInfo.connectable then
            local range = boosterInfo.radiate -- Use radiate as range
            for dx = -range, range do
                for dy = -range, range do
                    local dist = worldutil.getDistance(boosterInfo.radiateAlgorithm, dx, dy)
                    if dist <= range then
                        local tx, ty = booster.tileX + dx, booster.tileY + dy
                        if self:isWithinWorldLimit(booster.tileX, booster.tileY) and self:isWithinWorldLimit(tx, ty) then
                            local targetItem = self.items:get(tx, ty) --[[@as g.World.ItemData?]]
                            if targetItem and not targetItem.removed then
                                local _, category = g.getItemInfo(targetItem.type)
                                if category == boosterInfo.connectable.target then
                                    table.insert(booster.connectsTo, targetItem)
                                end
                            end
                        end
                    end
                end
            end

            -- Effectiveness scales down if overloaded
            if #booster.connectsTo > 0 then
                ---@cast booster g.World.BoosterData
                booster.effectiveness = math.min(boosterInfo.connectable.max / #booster.connectsTo, 1)
                for _, target in ipairs(booster.connectsTo) do
                    local tindex = self.items:coordsToIndex(target.tileX, target.tileY)
                    self.boostersInTiles[tindex] = self.boostersInTiles[tindex] or {}
                    table.insert(self.boostersInTiles[tindex], booster)
                end
            end
        else
            -- Radiating booster
            local affectedTiles = worldutil.getSpreadTiles(boosterInfo.radiateAlgorithm, boosterInfo.radiate)
            for _, tile in ipairs(affectedTiles) do
                local tx, ty = booster.tileX + tile[1], booster.tileY + tile[2]
                if self:isWithinWorldLimit(booster.tileX, booster.tileY) and self:isWithinWorldLimit(tx, ty) then
                    local tindex = self.items:coordsToIndex(tx, ty)
                    self.boostersInTiles[tindex] = self.boostersInTiles[tindex] or {}
                    table.insert(self.boostersInTiles[tindex], booster)
                end
            end
        end

        booster.animationTime = (booster.animationTime + dt * booster.effectiveness) % 1
    end

    -- Apply booster load multipliers
    for _, machine in pairs(self.servers) do self:_applyBoosterLoad(machine) end
    for _, machine in pairs(self.dataProcessors) do self:_applyBoosterLoad(machine) end
    for _, machine in pairs(self.dataInputs) do self:_applyBoosterLoad(machine) end

    -- Update power generator power
    for _, powerGen in pairs(self.powerGens) do
        local powerGenInfo = g.getItemInfo(powerGen.type, "powergen")
        powerGen.power = g.getProperty("getGeneratorLoad", powerGenInfo.power, 1, powerGenInfo)
    end

    -- Run power network update
    ---@type g.World.PowerData[]
    local allPowerNodes = {}
    for _, node in pairs(self.powerGens) do
        table.clear(node.connectsPowerNodes)
        allPowerNodes[#allPowerNodes+1] = node
    end
    for _, node in pairs(self.powerRelays) do
        table.clear(node.connectsPowerNodes)
        allPowerNodes[#allPowerNodes+1] = node
    end

    ---@type table<g.World.PowerData, boolean?>
    local visited = {}
    for _, startNode in ipairs(allPowerNodes) do
        if not visited[startNode] then
            -- TODO: Table pooling
            ---@type g.World.PowerNetwork
            local network = {
                generators = {},
                relays = {},
                consumers = {},
                totalPower = 0,
                totalLoad = 0,
            }
            ---@type table<g.World.ItemData, boolean?>
            local consumerSet = {} -- To avoid duplicates in network.consumers

            -- BFS to find connected power nodes
            local queue = {startNode}
            visited[startNode] = true
            local head = 1
            while head <= #queue do
                local node = queue[head]
                head = head + 1

                local nodeInfo = g.getItemInfo(node.type)
                ---@cast nodeInfo g.PowerGenInfo | g.PowerRelayInfo
                if nodeInfo.category == "powergen" then
                    network.generators[#network.generators+1] = node
                else
                    network.relays[#network.relays+1] = node
                end
                node.powerNetwork = network

                -- Find connected power nodes
                for _, other in ipairs(allPowerNodes) do
                    if node ~= other then
                        local otherInfo = g.getItemInfo(other.type)
                        ---@cast otherInfo g.PowerGenInfo | g.PowerRelayInfo
                        local dist = worldutil.getDistance("chessboard", node.tileX - other.tileX, node.tileY - other.tileY)
                        if
                            self:isWithinWorldLimit(node.tileX, node.tileY) and
                            self:isWithinWorldLimit(other.tileX, other.tileY) and
                            dist <= math.max(nodeInfo.wireLength, otherInfo.wireLength)
                        then
                            -- Always record the connection for drawing
                            if not helper.index(node.connectsPowerNodes, other) then
                                node.connectsPowerNodes[#node.connectsPowerNodes+1] = other
                            end

                            if not visited[other] then
                                visited[other] = true
                                queue[#queue+1] = other
                            end
                        end
                    end
                end
            end

            -- Find consumers for this network
            for _, node in ipairs(queue) do
                node.powerNetwork = network
                local nodeInfo = g.getItemInfo(node.type)
                ---@cast nodeInfo g.PowerGenInfo | g.PowerRelayInfo
                table.clear(node.connectsTo)

                local range = nodeInfo.wireLength
                for dx = -range, range do
                    for dy = -range, range do
                        local tx, ty = node.tileX + dx, node.tileY + dy
                        if self:isWithinWorldLimit(node.tileX, node.tileY) and self:isWithinWorldLimit(tx, ty) then
                            local item = self.items:get(tx, ty) --[[@as g.World.ItemData]]
                            if item and not item.removed and item.load > 0 then
                                -- Only add unique consumers to network
                                if not consumerSet[item] then
                                    item.powerNetwork = network
                                    network.consumers[#network.consumers+1] = item
                                    consumerSet[item] = true
                                end
                                -- Keep track of what this node is specifically powering
                                node.connectsTo[#node.connectsTo+1] = item
                            end
                        end
                    end
                end
            end

            -- Calculate power usage and total power
            local totalLoad = 0
            for _, consumer in ipairs(network.consumers) do
                totalLoad = totalLoad + consumer.load
            end
            network.totalLoad = totalLoad

            local totalPower = 0
            for _, generator in ipairs(network.generators) do
                totalPower = totalPower + generator.power
            end
            network.totalPower = totalPower

            self.powerNetworks[#self.powerNetworks+1] = network
        end
    end

    -- Update tile heat
    zeroTileHeat(self.heat)
    ---@param itemData g.World.ItemData
    self.items:foreach(function(itemData, x, y)
        if itemData then
            local itemInfo, category = g.getItemInfo(itemData.type)
            if category == "booster" then
                ---@cast itemData g.World.BoosterData
                ---@cast itemInfo g.BoosterInfo
                itemData.effectiveness = itemData.effectiveness * worldutil.getLoadPercentage(itemData)

                if itemInfo.connectable then
                    for _, target in ipairs(itemData.connectsTo) do
                        local reltx = target.tileX - x
                        local relty = target.tileY - y
                        ---@cast itemData g.World.BoosterData
                        local heat = itemInfo.getTileHeat(reltx, relty) * itemData.effectiveness
                        self.heat:set(target.tileX, target.tileY, self.heat:get(target.tileX, target.tileY) + heat)
                    end
                else
                    local affectedTiles = worldutil.getSpreadTiles(itemInfo.radiateAlgorithm, itemInfo.radiate)
                    for _, tile in ipairs(affectedTiles) do
                        local tx, ty = x + tile[1], y + tile[2]

                        if self.items:contains(tx, ty) then
                            local heat = itemInfo.getTileHeat(tile[1], tile[2]) * worldutil.getLoadPercentage(itemData)
                            self.heat:set(tx, ty, self.heat:get(tx, ty) + heat)
                        end
                    end
                end
            elseif category == "server" then
                ---@cast itemData g.World.ServerData
                ---@cast itemInfo g.ServerInfo
                if itemInfo.heatRadiate > 0 then
                    local affectedTiles = worldutil.getSpreadTiles(itemInfo.heatRadiateAlgorithm, itemInfo.heatRadiate)
                    for _, tile in ipairs(affectedTiles) do
                        local divider = 2 ^ worldutil.getDistance(itemInfo.heatRadiateAlgorithm, tile[1], tile[2])
                        local tx, ty = x + tile[1], y + tile[2]

                        if self.items:contains(tx, ty) then
                            local heat = itemInfo.heat / divider
                            self.heat:set(tx, ty, self.heat:get(tx, ty) + heat)
                        end
                    end
                end
            end
        end
    end)

    -- Run data output update
    for _, dpData in pairs(self.dataProcessors) do
        local dpInfo = g.getItemInfo(dpData.type, "data")

        --- Compute booster
        local boosterMod = 0
        local boosterMul = 1
        local biTiles = self.boostersInTiles[self.items:coordsToIndex(dpData.tileX, dpData.tileY)]
        if biTiles then
            for _, booster in ipairs(biTiles) do
                ---@cast booster g.World.BoosterData
                local boosterInfo = g.getItemInfo(booster.type, "booster")
                local reltx = dpData.tileX - booster.tileX
                local relty = dpData.tileY - booster.tileY
                local bMod = boosterInfo.getPerformanceModifier(reltx, relty)
                local bMul = boosterInfo.getPerformanceMultiplier(reltx, relty)
                boosterMod = boosterMod + bMod * booster.effectiveness
                boosterMul = boosterMul * (1 + (bMul - 1) * booster.effectiveness)
            end
        end

        --- Compute DPS
        local loadPercentage = worldutil.getLoadPercentage(dpData)
        dpData.dataPerSecond = g.getProperty(
            "getDataThroughput",
            dpInfo.dataPerSecond + boosterMod,
            loadPercentage * boosterMul,
            dpInfo
        )
        dpData.wireDPS = g.getProperty("getWireThroughput", dpInfo.wireDPS, 1, dpInfo)

        --- Update data output wires
        if loadPercentage > 0 then
            for _, wire in ipairs(dpData.connects) do
                table.insert(wire.server.connectedOutputs, wire)
                updateWire(loadPercentage, dpData.wireDPS, dt, wire)
            end
        end

        --- Update data output
        if dpData.dataRemaining > 0 then
            local dataToProcess = dpData.dataPerSecond * dt
            local remaining = dpData.dataRemaining - dataToProcess
            dpData.rewardToShow = 0
            if remaining <= 0 then
                dataToProcess = -remaining
                g.addResource("money", dpData.reward)
                dpData.dataRemaining = 0
                dpData.rewardToShow = dpData.rewardToShow + dpData.reward
                dpData.reward = 0
            else
                dpData.dataRemaining = remaining
            end
        end

        if dpData.dataRemaining <= 0 then
            -- Poll wire
            for _ = 1, #dpData.connects do
                local i = (dpData.next + 1) % #dpData.connects + 1
                dpData.next = i - 1
                local wire = dpData.connects[i]
                if #wire.positions > 0 and wire.positions[#wire.positions] >= 1 then
                    table.remove(wire.positions)
                    dpData.reward = table.remove(wire.objects)
                    dpData.dataRemaining = 1
                    break
                end
            end
        end
    end

    -- Run data input update
    for _, diData in pairs(self.dataInputs) do
        local diInfo = g.getItemInfo(diData.type, "indata")
        local loadPercentage = worldutil.getLoadPercentage(diData)
        -- TODO: Data input wire DPS?
        local DI_WIRE_DPS = 25
        diData.wireDPS = g.getProperty("getWireThroughput", DI_WIRE_DPS, 1, diInfo)

        if loadPercentage > 0 then
            for _, wire in ipairs(diData.connects) do
                table.insert(wire.server.connectedInputs, wire)
                updateWire(loadPercentage, diData.wireDPS, dt, wire)
            end
        end
    end

    -- Run server update
    -- We need to do the server update in multiple pass: Computing the CPS, then updating the job progress.
    local cps = 0
    -- Pass 1: Compute CPS
    for _, serverData in pairs(self.servers) do
        local serverInfo = g.getItemInfo(serverData.type, "server")

        if #serverData.connectedOutputs > 0 and #serverData.connectedInputs > 0 and not serverData.currentJob then
            -- Pull job queue from data input wires
            for _ = 1, #serverData.connectedInputs do
                local i = (serverData.nextInput + 1) % #serverData.connectedInputs + 1
                serverData.nextInput = i - 1
                local wire = serverData.connectedInputs[i]
                if #wire.positions > 0 and wire.positions[#wire.positions] >= 1 then
                    table.remove(wire.positions)
                    serverData.currentJob = table.remove(wire.objects)
                    serverData.dataTotalEmitted = 0
                    break
                end
            end
        end

        -- Compute heat
        local heat = self.heat:get(serverData.tileX, serverData.tileY)
        local heatPerfMul = 1
        local heatdiff = serverInfo.heatTolerance[2] - serverInfo.heatTolerance[1]
        if heat > serverInfo.heatTolerance[2] then
            -- Overheat. Reduce performance
            local diff = heat - serverInfo.heatTolerance[2]
            heatPerfMul = 2 ^ (-diff / heatdiff)
        elseif heat < serverInfo.heatTolerance[1] then
            -- Chilling. Increase performance
            local diff = serverInfo.heatTolerance[1] - heat
            heatPerfMul = 1 + diff / heatdiff
        end

        -- Compute booster
        local boosterMod = 0
        local boosterMul = 1
        local biTiles = self.boostersInTiles[self.items:coordsToIndex(serverData.tileX, serverData.tileY)]
        if biTiles then
            for _, booster in ipairs(biTiles) do
                ---@cast booster g.World.BoosterData
                local boosterInfo = g.getItemInfo(booster.type, "booster")
                local reltx = serverData.tileX - booster.tileX
                local relty = serverData.tileY - booster.tileY
                local bMod = boosterInfo.getPerformanceModifier(reltx, relty)
                local bMul = boosterInfo.getPerformanceMultiplier(reltx, relty)
                boosterMod = boosterMod + bMod * booster.effectiveness
                boosterMul = boosterMul * (1 + (bMul - 1) * booster.effectiveness)
            end
        end

        -- Compute CPS
        local perfMod = g.ask("getPerformanceModifier", serverInfo) --[[@as number]]
        local perfMultiplier = g.ask("getPerformanceMultiplier", serverInfo) --[[@as number]]
        local finalMod = serverInfo.computePerSecond + perfMod + boosterMod
        local finalMul = perfMultiplier * worldutil.getLoadPercentage(serverData) * heatPerfMul * boosterMul
        serverData.computePerSecond = math.max(finalMod, 0) * finalMul
    end
    -- Pass 2: Data transmit logic (bottlenecking & proportional scaling)
    for _, serverData in pairs(self.servers) do
        local job = serverData.currentJob
        if job and #serverData.connectedOutputs > 0 then
            -- Process job
            local reward = job.resource.money / job.outputData
            local stagedDataTotalEmitted = serverData.dataTotalEmitted
            local maxDataEmit = job.outputData - stagedDataTotalEmitted
            local dataEmitted = math.min(serverData.computePerSecond * job.outputData * dt / job.computePower, maxDataEmit)
            -- Get fractional from the totalDataEmitted and add it
            dataEmitted = dataEmitted + (stagedDataTotalEmitted % 1)
            stagedDataTotalEmitted = math.floor(stagedDataTotalEmitted)

            local dataEmittedInt = math.floor(dataEmitted)
            local hasSent = false
            if dataEmittedInt > 0 then
                for _ = 1, #serverData.connectedOutputs do
                    local i = (serverData.nextOutput + 1) % #serverData.connectedOutputs + 1
                    serverData.nextOutput = i - 1

                    local wire = serverData.connectedOutputs[i]
                    local maxSend = math.floor(getWireLength(wire) / PHYSICAL_DATA_SIZE) - #wire.objects

                    if maxSend > 0 then
                        hasSent = true

                        for _ = 1, math.min(maxSend, dataEmittedInt) do
                            -- Push data to wire
                            table.insert(wire.objects, 1, reward)
                            table.insert(wire.positions, 1, 0)
                            dataEmittedInt = dataEmittedInt - 1
                            dataEmitted = dataEmitted - 1
                            stagedDataTotalEmitted = stagedDataTotalEmitted + 1
                        end
                    end

                    if dataEmittedInt == 0 then
                        break
                    end
                end
            else
                -- Actually there's none but "virtually" fraction of the data is being processed
                hasSent = true
            end

            serverData.dataBottlenecked = not hasSent
            if hasSent then
                -- (dataEmitted - dataEmittedInt) will only contain the fractional part
                local newDataTotalEmitted = stagedDataTotalEmitted + (dataEmitted - dataEmittedInt)
                local dd = newDataTotalEmitted - serverData.dataTotalEmitted
                serverData.dataTotalEmitted = newDataTotalEmitted
                cps = cps + dd * serverData.computePerSecond / job.outputData
            end

            if dataEmittedInt > 0 then
                serverData.dataBottlenecked = true
            elseif serverData.dataTotalEmitted >= job.outputData then
                -- Job done
                g.call("jobCompleted", serverData, job)
                serverData.currentJob = nil
            end
        end
    end
    if dt > 0 then
        self.cpsCollector:insert(dt, cps)
    end

    -- Run job poll
    for k, ji in pairs(g.VALID_JOBS) do
        local jpinfo = self.jobPoller[k]

        if g.ask("isJobUnlocked", k) then
            local info = g.getJobCategoryInfo(ji.category)
            -- Yea these stat name and evbus name is MSOT.
            -- Is there a better way?
            local stat = g.VALID_STATS[info.nameRaw.."JobFrequency"]
            -- TODO: Cache this
            local jobFreqMod = g.ask(stat.addQuestion)
            local jobFreqMul = g.ask(stat.multQuestion)
            local spawnChance = g.getProperty("getJobFrequency", jobFreqMod, jobFreqMul, k)
            jpinfo[2] = spawnChance
            if spawnChance > 0 then
                local time = 1 / spawnChance -- the stat is frequency
                jpinfo[1] = jpinfo[1] + dt

                while jpinfo[1] >= time do
                    jpinfo[1] = jpinfo[1] - time

                    local job = g.genJob(k)
                    if not self:_queueJob(job) then
                        break
                    end
                end
            else
                jpinfo[1] = 0
            end
        else
            jpinfo[1] = 0
            jpinfo[2] = 0
        end
    end

    -- Run per second update event bus on upgrades
    self.timer = self.timer + dt
    while self.timer >= 1 do
        self.seconds = self.seconds + 1

        achievements.emitPerSecondUpdate()

        for _, ent in ipairs(self.entities) do
            if ent.perSecondUpdate then
                ent:perSecondUpdate(self.seconds)
            end
        end

        g.call("perSecondUpdate", self.seconds)
        self.timer = self.timer - 1

        self.analyticsSendTime = self.analyticsSendTime + 1
        if self.analyticsSendTime >= consts.ANALYTICS_UPDATE_INTERVAL then
            analytics.send("update")
            self.analyticsSendTime = 0
        end
    end

    self.particles:update(dt)

    self.averageCPS = self.cpsCollector:getAverage()
    self.peakCPS = math.max(self.averageCPS, self.peakCPS)
end



---@param a g.Entity
---@param b g.Entity
local function sortOrder(a, b)
    local indexA = a.y + (a.drawOrder or 0)
    local indexB = b.y + (b.drawOrder or 0)
    return indexA < indexB
end

local NONREMOVABLE_MESH
local STATUS_MESH
do
local FOOT_LEN = 0.2
NONREMOVABLE_MESH = love.graphics.newMesh({
    {0.5, 0.5, 0.5, 0.5},
    -- Top-left
    {0, FOOT_LEN, 0, FOOT_LEN},
    {0, 0, 0, 0},
    {FOOT_LEN, 0, FOOT_LEN, 0},
    -- Top-right
    {1 - FOOT_LEN, 0, 1 - FOOT_LEN, 0},
    {1, 0, 1, 0},
    {1, FOOT_LEN, 1, FOOT_LEN},
    -- Bottom-right
    {1, 1 - FOOT_LEN, 1, 1 - FOOT_LEN},
    {1, 1, 1, 1},
    {1 - FOOT_LEN, 1, 1 - FOOT_LEN, 1},
    -- Bottom-left
    {FOOT_LEN, 1, FOOT_LEN, 1},
    {0, 1, 0, 1},
    {0, 1 - FOOT_LEN, 0, 1 - FOOT_LEN},
}, "triangles", "static")
NONREMOVABLE_MESH:setVertexMap({1, 2, 3, 1, 3, 4, 1, 5, 6, 1, 6, 7, 1, 8, 9, 1, 9, 10, 1, 11, 12, 1, 12, 13})

local FOOT2_LEN = 0.3
STATUS_MESH = love.graphics.newMesh({
    {0.5, 0.5, 0.5, 0.5},
    -- Top
    {FOOT2_LEN, 0, FOOT2_LEN, 0, 1, 1, 1, 0},
    {1 - FOOT2_LEN, 0, 1 - FOOT2_LEN, 0, 1, 1, 1, 0},
    -- Right
    {1, FOOT2_LEN, 1, FOOT2_LEN, 1, 1, 1, 0},
    {1, 1 - FOOT2_LEN, 1, 1 - FOOT2_LEN, 1, 1, 1, 0},
    -- Bottom
    {1 - FOOT2_LEN, 1, 1 - FOOT2_LEN, 1, 1, 1, 1, 0},
    {FOOT2_LEN, 1, FOOT2_LEN, 1, 1, 1, 1, 0},
    -- Left
    {0, 1 - FOOT2_LEN, 0, 1 - FOOT2_LEN, 1, 1, 1, 0},
    {0, FOOT2_LEN, 0, FOOT2_LEN, 1, 1, 1, 0},
}, "triangles", "static")
STATUS_MESH:setVertexMap({1, 2, 3, 1, 4, 5, 1, 6, 7, 1, 8, 9})
end


function World:_draw()
    local visibleArea
    -- Get visible area
    do
        local x1, y1 = love.graphics.inverseTransformPoint(0, 0)
        local x2, y2 = love.graphics.inverseTransformPoint(love.graphics.getDimensions())
        visibleArea = Kirigami(x1, y1, x2 - x1, y2 - y1)
    end
    prof_push("world:_draw")

    -- Draw the actual world
    do
        -- Draw white rectnagle across the world
        local size = consts.WORLD_TILE_SIZE * World.TILE_SIZE
        love.graphics.setColor(g.COLORS.UI.MAIN[g.getSystemTheme()].WORLD_BACKGROUND)
        love.graphics.rectangle("fill", 0, 0, size, size)

        -- Draw world blocked area
        local center = math.floor(World.TILE_SIZE / 2)
        local worldSize = g.stats.WorldTileSize
        if center > worldSize then
            -- Draw stencil relative to the center of world
            love.graphics.setStencilMode("draw", 1)
            love.graphics.rectangle("fill",
                (center - worldSize) * consts.WORLD_TILE_SIZE,
                (center - worldSize) * consts.WORLD_TILE_SIZE,
                (worldSize * 2 + 1) * consts.WORLD_TILE_SIZE,
                (worldSize * 2 + 1) * consts.WORLD_TILE_SIZE
            )
            love.graphics.setStencilMode("test", 1)
        end
        -- Draw world area
        love.graphics.setColor(objects.Color("#b0b0b0"))
        love.graphics.rectangle("fill", 0, 0, size, size)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.draw(self.worldTexture)
        love.graphics.setStencilMode() -- should be harmless
    end

    -- Draw tile heat
    local wtz = consts.WORLD_TILE_SIZE
    self.heat:foreach(function(heat, tx, ty)
        local heatmul = helper.round(heat / 10)
        if heatmul ~= 0 then
            local x, y = tx * wtz, ty * wtz
            local col = heat < 0 and g.COLORS.TILE_COLD or g.COLORS.TILE_HOT
            local col2 = helper.multiplyAlpha(col, math.min(math.abs(heatmul), 10) / 10)
            love.graphics.setColor(col2)
            love.graphics.rectangle("fill", x, y, wtz, wtz)
        end
    end)

    -- Draw tile highlight
    if self.htx and self.hty then
        local itemData = self.items:get(self.htx, self.hty)
        if itemData then
            local itemInfo, cat = g.getItemInfo(itemData.type)
            if cat == "booster" then
                ---@cast itemInfo g.BoosterInfo
                drawRangeVisualization(self.htx, self.hty, itemInfo.radiateAlgorithm, itemInfo.radiate)
            elseif cat == "data" or cat == "indata" or cat == "powergen" or cat == "powerrelay" then
                ---@cast itemInfo g.PowerGenInfo|g.PowerRelayInfo|g.DataOutInfo|g.DataInInfo
                drawRangeVisualization(self.htx, self.hty, "chessboard", itemInfo.wireLength)
            end
        end
    end

    ---@type g.Entity[]
    local objlist = {}

    -- Draw items
    prof_push("item_draw")
    local center = math.floor(World.TILE_SIZE / 2)
    local worldSize = g.stats.WorldTileSize
    local visibleAreaPadded = visibleArea:padUnit(-consts.WORLD_TILE_SIZE)
    self.items:foreachInArea(
        center - worldSize,
        center - worldSize,
        center + worldSize,
        center + worldSize,
        function(itemData, x, y)
            if itemData then
                local cx, cy = (x + 0.5) * wtz, (y + 0.5) * wtz
                if visibleAreaPadded:containsCoords(cx, cy) then
                    if not itemData.removable then
                        love.graphics.setColor(0, 0, 0)
                        love.graphics.draw(NONREMOVABLE_MESH, x * wtz, y * wtz, 0, wtz, wtz)
                    end

                    local itemInfo, cat = g.getItemInfo(itemData.type)
                    if cat == "server" then
                        ---@cast itemData g.World.ServerData
                        local probs = g.getItemProblems(itemData)
                        local hasError = false
                        for _, prob in ipairs(probs) do
                            local probInfo = g.getItemProblemInfo(prob)
                            if probInfo.error then
                                hasError = true
                                break
                            end
                        end

                        if hasError then
                            love.graphics.setColor(1, 0.3, 0.3)
                        elseif itemData.currentJob then
                            love.graphics.setColor(0.3, 1, 0.3)
                        else
                            love.graphics.setColor(0.3, 0.3, 1)
                        end

                        love.graphics.draw(STATUS_MESH, cx, cy, 0, wtz * 1.1, wtz * 1.1, 0.5, 0.5)
                    end

                    if self.htx == x and self.hty == y then
                        if cat == "booster" then
                            ---@cast itemInfo g.BoosterInfo
                            drawRangeVisualization(x, y, itemInfo.radiateAlgorithm, itemInfo.radiate)
                        elseif cat == "data" or cat == "indata" or cat == "powergen" or cat == "powerrelay" then
                            ---@cast itemInfo g.PowerGenInfo|g.PowerRelayInfo|g.DataOutInfo|g.DataInInfo
                            drawRangeVisualization(x, y, "chessboard", itemInfo.wireLength)
                        end
                    end
                    local trans = gsman.transform(cx, cy)
                    love.graphics.setColor(1, 1, 1)
                    ---@cast itemInfo g.ItemInfo<g.World.ItemData>
                    itemInfo.draw(itemData)
                    trans:pop()
                end
            end
        end
    )
    prof_pop() -- prof_push("item_draw")

    local lw = gsman.setLineWidth(2)

    -- Draw power network connectors
    prof_push("power_draw")
    for _, v in ipairs(self.powerNetworks) do
        drawPowerLines(v, visibleArea, self.htx, self.hty)
    end
    prof_pop() -- prof_push("power_draw")

    -- Draw data output connectors
    prof_push("dataoutput_draw")
    love.graphics.setColor(0, 0, 0)
    for _, itemData in pairs(self.dataProcessors) do
        local x, y = itemData.tileX, itemData.tileY
        local dpSelected = self.htx == x and self.hty == y
        local dpx, dpy = (x + 0.5) * wtz, (y + 0.5) * wtz
        local dpVisible = visibleAreaPadded:containsCoords(dpx, dpy)
        for _, wire in ipairs(itemData.connects) do
            local svr = wire.server
            local svrx, svry = (svr.tileX + 0.5) * wtz, (svr.tileY + 0.5) * wtz
            if dpVisible or visibleAreaPadded:containsCoords(svrx, svry) then
                local alpha = UNHIGHLIGHT_ALPHA
                if dpSelected or self.htx == svr.tileX and self.hty == svr.tileY then
                    alpha = HIGHLIGHT_ALPHA
                end

                -- Draw wire
                love.graphics.setColor(0, 0, 0, alpha)
                drawLine(svrx, svry, dpx, dpy, 3)

                -- Draw physical data
                local svrInfo = g.getItemInfo(svr.type, "server")
                local catinfo = g.getJobCategoryInfo(svrInfo.computeType)
                love.graphics.setColor(helper.multiplyAlpha(catinfo.color, alpha))
                for _, pos in ipairs(wire.positions) do
                    local objx = helper.lerp(svrx, dpx, pos)
                    local objy = helper.lerp(svry, dpy, pos)
                    -- TODO: rotation
                    g.drawImage(catinfo.symbol, objx, objy, 0, 0.2, 0.2)
                end
            end
        end

        if itemData.rewardToShow > 0 then
            worldutil.spawnText(
                "{o}+{money}"..g.formatNumber(itemData.rewardToShow).."{/o}",
                (x + 0.5) * wtz,
                (y + 0.5) * wtz,
                0.3,
                15
            )
            itemData.rewardToShow = 0
        end
    end
    prof_pop() -- prof_push("dataoutput_draw")

    prof_push("datainput_draw")
    for _, itemData in pairs(self.dataInputs) do
        local x, y = itemData.tileX, itemData.tileY
        local diSelected = self.htx == x and self.hty == y
        local dix, diy = (x + 0.5) * wtz, (y + 0.5) * wtz
        local diVisible = visibleAreaPadded:containsCoords(dix, diy)
        for _, wire in ipairs(itemData.connects) do
            local svr = wire.server
            local svrx, svry = (svr.tileX + 0.5) * wtz, (svr.tileY + 0.5) * wtz
            if diVisible or visibleAreaPadded:containsCoords(svrx, svry) then
                local alpha = UNHIGHLIGHT_ALPHA
                if diSelected or self.htx == svr.tileX and self.hty == svr.tileY then
                    alpha = HIGHLIGHT_ALPHA
                end

                -- Draw wire
                love.graphics.setColor(0, 0, 0, alpha)
                drawLine(dix, diy, svrx, svry, 3)

                -- Draw physical data
                local svrInfo = g.getItemInfo(svr.type, "server")
                local catinfo = g.getJobCategoryInfo(svrInfo.computeType)
                love.graphics.setColor(helper.multiplyAlpha(catinfo.color, alpha))
                for _, pos in ipairs(wire.positions) do
                    local objx = helper.lerp(dix, svrx, pos)
                    local objy = helper.lerp(diy, svry, pos)
                    -- TODO: rotation
                    g.drawImage(catinfo.symbol, objx, objy, 0, 0.2, 0.2)
                end
            end
        end
    end
    prof_pop() -- prof_push("datainput_draw")

    -- Draw booster connectors
    prof_push("boostercon_draw")
    for _, booster in pairs(self.boosters) do
        local boosterSelected = self.htx == booster.tileX and self.hty == booster.tileY

        local bx, by = (booster.tileX + 0.5) * wtz, (booster.tileY + 0.5) * wtz
        local boosterVisible = visibleAreaPadded:containsCoords(bx, by)

        for _, target in ipairs(booster.connectsTo) do
            local tx, ty = (target.tileX + 0.5) * wtz, (target.tileY + 0.5) * wtz
            if boosterVisible or visibleAreaPadded:containsCoords(tx, ty) then
                local alpha = UNHIGHLIGHT_ALPHA
                local targetSelected = self.htx == target.tileX and self.hty == target.tileY
                if boosterSelected or targetSelected then
                    alpha = HIGHLIGHT_ALPHA
                end
                love.graphics.setColor(1, 0, 0, alpha)
                drawArrows(bx, by, tx, ty, 6, booster.animationTime)
            end
        end
    end
    prof_pop() -- prof_push("boostercon_draw")
    lw:pop()

    -- Draw item problems status icons
    prof_push("item_problems_draw")
    love.graphics.setColor(1, 1, 1)
    local statusIconF = g.getMainFont(18)
    self.items:foreach(function(itemData, tx, ty)
        if itemData then
            local problems = g.getItemProblems(itemData)
            if #problems > 0 then
                -- Get error texts
                local txt = {}
                for _, prob in ipairs(problems) do
                    local problemInfo = g.getItemProblemInfo(prob)
                    local col = problemInfo.error and g.COLORS.UI.DEBUFF or g.COLORS.UI.WARNING
                    txt[#txt+1] = helper.wrapRichtextColor(col, "{"..problemInfo.icon.."}")
                end
                -- Draw error text above it
                local finalText = "{w}{o thickness=0.5}"..table.concat(txt).."{/o}{/w}"
                local x = (tx + 0.5) * wtz
                local y = (ty + 0.5) * wtz
                local w = richtext.getWidth(finalText, statusIconF)
                richtext.printRich(
                    finalText, statusIconF,
                    x - w / 2, y - wtz / 2, w, "center",
                    0, 1, 1, 0, statusIconF:getHeight() * 0.5
                )
            end
        end
    end)
    prof_pop() -- prof_push("item_problems_draw")

    prof_push("entity sort")
    -- Add entitiy to be drawn
    for _, e in ipairs(self.entities) do
        objlist[#objlist+1] = e
    end

    -- Sort by Y bottom first
    table.sort(objlist, sortOrder)
    prof_pop() -- prof_push("entity sort")

    -- Draw everything.
    prof_push("entity draw")
    for _, e in ipairs(objlist) do
        local draw = true
        if e.boundingBox then
            draw = visibleArea:intersection(Kirigami(e.boundingBox)):exists()
        end

        if draw then
            local col = gsman.setColor(1, 1, 1)
            drawEntity(e)
            col:pop()
        end
    end
    prof_pop() -- prof_push("entity draw")

    love.graphics.setColor(1, 1, 1)
    self.particles:draw()

    prof_pop() -- prof_push("world:_draw")
end



---@param itemData g.World.ItemData
function World:_applyBoosterLoad(itemData)
    local biTiles = self.boostersInTiles[self.items:coordsToIndex(itemData.tileX, itemData.tileY)]
    if biTiles then
        local mul = 1
        for _, booster in ipairs(biTiles) do
            ---@cast booster g.World.BoosterData
            local bInfo = g.getItemInfo(booster.type, "booster")
            local reltx, relty = itemData.tileX - booster.tileX, itemData.tileY - booster.tileY
            local bMul = bInfo.getLoadMultiplier(reltx, relty)
            ---@cast booster g.World.BoosterData
            mul = mul * (1 + (bMul - 1) * booster.effectiveness)
        end
        itemData.load = itemData.load * mul
    end
end

---@param tx integer?
---@param ty integer?
function World:_setHoveredTile(tx, ty)
    self.htx, self.hty = tx, ty
end



---@param itemInfo g.ItemInfo<any>
---@param mod number?
---@param mul number?
function World:computeLoadModifier(itemInfo, mod, mul)
    local v = self.loadModifiers[itemInfo.id]
    if not v then
        v = {dirty = true, modifier = 0, multiplier = 1}
        self.loadModifiers[itemInfo.id] = v
    end

    if v.dirty then
        v.modifier = g.ask("getLoadModifier", itemInfo)
        v.multiplier = g.ask("getLoadMultiplier", itemInfo)
        v.dirty = false
    end

    return math.max(math.max(itemInfo.load + v.modifier + (mod or 0), 0) * v.multiplier * (mul or 1), 0)
end

---@param tx integer
---@param ty integer
---@return boolean
function World:isWithinWorldLimit(tx, ty)
    local center = math.floor(World.TILE_SIZE / 2)
    local worldSize = g.stats.WorldTileSize
    return math.abs(tx - center) <= worldSize and math.abs(ty - center) <= worldSize
end


---The "NOTABUS" suffix is intentional. Do not remove it!
---@param itemid string
function World:getItemTotalInventory_NOTABUS(itemid)
    if not self.itemInventoryCounts[itemid] then
        if g.isItemUnlocked(itemid) then
            self.itemInventoryCounts[itemid] = g.ask("getItemTotalInventory", itemid)
        else
            self.itemInventoryCounts[itemid] = 0
        end
    end

    return self.itemInventoryCounts[itemid]
end


---@param tx integer
---@param ty integer
---@param ignoreworldlimit boolean?
function World:canPutItem(tx, ty, ignoreworldlimit)
    -- Is coords on grid?
    if not self.items:contains(tx, ty) or self.items:get(tx, ty) then
        return false
    end

    -- Check world size constraints
    if not (ignoreworldlimit or self:isWithinWorldLimit(tx, ty)) then
        return false
    end

    return true
end

---@param itemId string
---@param tx integer
---@param ty integer
---@param removable boolean?
function World:putItem(itemId, tx, ty, removable)
    if removable == nil then
        removable = true
    end

    if not self:canPutItem(tx, ty, not removable) then
        error("Cannot put item '"..itemId.."' at '"..tx..","..ty.."'")
    end

    local itemInfo, category = g.getItemInfo(itemId)
    local itemData
    if category == "server" then
        ---@type g.World.ServerData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            removable = removable,
            load = itemInfo.load,
            currentJob = nil,
            dataTotalEmitted = 0,
            connectedOutputs = {},
            connectedInputs = {},
            nextInput = 0,
            nextOutput = 0,
            computePerSecond = 0,
            dataBottlenecked = false,
            canSend = false,
        }
    elseif category == "data" then
        ---@type g.World.DataOutputData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            removable = removable,
            load = itemInfo.load,
            connects = {},
            dataRemaining = 0,
            reward = 0,
            rewardToShow = 0,
            next = 0,
            dataPerSecond = 0,
            wireDPS = 0,
            requestedLoad = 0,
            dataScale = 1,
        }
    elseif category == "booster" then
        ---@type g.World.BoosterData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            removable = removable,
            load = itemInfo.load,
            connectsTo = {},
            effectiveness = 1,
            animationTime = 0,
        }
    elseif category == "indata" then
        ---@type g.World.DataInputData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            removable = removable,
            load = itemInfo.load,
            connects = {},
            next = 0,
            wireDPS = 0,
        }
    elseif category == "powergen" or category == "powerrelay" then
        ---@type g.World.PowerData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            removable = removable,
            load = itemInfo.load,
            power = 0,
            connectsTo = {},
            connectsPowerNodes = {},
        }
    else
        error("fixme category "..category)
    end

    self.items:set(tx, ty, itemData)

    -- Auto-wiring
    if self.autowire then
        if category == "server" then
            ---@cast itemData g.World.ServerData
            -- Find input and output datas
            for _, di in ipairs(self.diAreaAutoConnect:get(tx, ty)) do
                g.connectDataWire(itemData, di)
            end
            for _, doobj in ipairs(self.doAreaAutoConnect:get(tx, ty)) do
                g.connectDataWire(itemData, doobj)
            end
        elseif category == "data" or category == "indata" then
            ---@cast itemData g.World.DataInputData|g.World.DataOutputData
            ---@cast itemInfo g.DataInInfo|g.DataOutInfo
            for _, tile in ipairs(worldutil.getSpreadTiles("chessboard", itemInfo.wireLength)) do
                local x, y = tile[1] + tx, tile[2] + ty
                if self.items:contains(x, y) then
                    local targetItem = self.items:get(x, y)

                    if targetItem then
                        local _, targetCat = g.getItemInfo(targetItem.type)
                        if targetCat == "server" then
                            ---@cast targetItem g.World.ServerData
                            g.connectDataWire(targetItem, itemData)
                        end
                    end
                end
            end

            local targetT = category == "data" and self.doAreaAutoConnect or self.diAreaAutoConnect
            markExistInArea(targetT, itemData, itemInfo.wireLength)
        end
    end
    return itemData
end




function World:_setupPlaceables()
    local center = math.floor(World.TILE_SIZE / 2)
    self:putItem("main_power", center, center, false)
    local wz = math.floor(World.TILE_SIZE / 2)

    for i = 5, wz, 4 do
        self:putItem("sub_power", center+i, center+i, false)
        self:putItem("sub_power", center+i, center-i, false)
        self:putItem("sub_power", center-i, center+i, false)
        self:putItem("sub_power", center-i, center-i, false)
    end
end




---@generic T
---@param counterVal integer
---@param criteria fun(t:g.World.ItemData):boolean
function World:_cycleNextItem(counterVal, criteria)
    local sz = self.items.width * self.items.height
    local j = counterVal
    for _ = 1, sz do
        local i = (j + 1) % sz + 1
        j = i - 1

        local x, y = self.items:indexToCoords(i)
        local val = self.items:get(x, y)
        if val and self:isWithinWorldLimit(val.tileX, val.tileY) and criteria(val) then
            return j, val
        end
    end
    return counterVal, nil
end

---@param job g.Job
function World:_queueJob(job)
    local jpinfo = self.jobPoller[job.type]
    local targetIndata
    jpinfo[3], targetIndata = self:_cycleNextItem(jpinfo[3], DATA_INPUT_CYCLE_FILTER[job.category])
    if not targetIndata then
        return false
    end
    ---@cast targetIndata g.World.DataInputData

    -- Find a wire that has space
    ---@type g.World.DataInputWire|nil
    local wire = nil
    for j = 1, #targetIndata.connects do
        local i = (j + targetIndata.next) % #targetIndata.connects + 1
        local w = targetIndata.connects[i]
        local maxWireCap = math.floor(getWireLength(w) / PHYSICAL_DATA_SIZE)
        if #w.objects < maxWireCap then
            wire = w
            targetIndata.next = i - 1
            break
        end
    end

    if not wire then
        return false
    end

    table.insert(wire.objects, 1, job)
    table.insert(wire.positions, 1, 0)
    return true
end




--- Buses

---@param cat string
local function defJobFreqBus(cat)
    local catlow = cat:lower()
    ---@param self g.World
    World["get"..cat.."JobFrequencyModifier"] = function(self)
        return self.jobFreqModByCategory[catlow]
    end
    ---@param self g.World
    World["get"..cat.."JobFrequencyMultiplier"] = function(self)
        return self.jobFreqMulByCategory[catlow]
    end
end

-- These are MSOT unfortunately, but is there a way?
-- Will think of it later. Gotta move fast.
-- Just make sure to sync this with g.defineJobCategory
defJobFreqBus("General")
defJobFreqBus("Video")
defJobFreqBus("AI")

--- End Buses



return World
