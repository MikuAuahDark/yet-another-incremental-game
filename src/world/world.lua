--[[

World

]]


local ParticleService = require(".particle.ParticleService")


---@param grid objects.Grid
local function zeroTileHeat(grid)
    for x = 0, grid.width-1 do
        for y = 0, grid.height-1 do
            grid:set(x,y, 0)
        end
    end
end


---Makes a rhombus pattern
---@param iteration integer
---@return [integer,integer][]
local function taxicabSpread(iteration)
    if iteration == 0 then
        return {{0, 0}}
    end

    local result = {}
    for dy = -iteration, iteration do
        for dx = -iteration, iteration do
            if math.abs(dx) + math.abs(dy) <= iteration then
                result[#result+1] = {dx, dy}
            end
        end
    end
    return result
end

---Makes a square pattern
---@param iteration integer
---@return [integer,integer][]
local function chessboardSpread(iteration)
    if iteration == 0 then
        return {{0, 0}}
    end

    local result = {}
    for dy = -iteration, iteration do
        for dx = -iteration, iteration do
            if math.max(math.abs(dx), math.abs(dy)) <= iteration then
                result[#result+1] = {dx, dy}
            end
        end
    end
    return result
end

---@type table<g.RadiateAlgorithm, fun(iteration:integer):[integer,integer][]>
local RADIANCE_ALGORITHM = {
    taxicab = helper.memoize(taxicabSpread),
    chessboard = helper.memoize(chessboardSpread),
}

---@class g.World.ItemData
---@field type string Item ID
---@field tileX integer (updated every frame)
---@field tileY integer (updated every frame)

---@class g.World.ServerData: g.World.ItemData
---@field currentJob g.Job
---@field jobProgress number
---@field connectsTo g.World.DataProcessorData? (connect to this data processor, quick lookup only)
---@field computePerSecond number (updated every frame) Does not account data bottleneck

---@class g.World.DataProcessorData: g.World.ItemData
---@field connectsServers g.World.ServerData[] (connects to this server, source of truth)
---@field dataPerSecond number (updated every frame)
---@field serversDataPerSecond number (updated every frame)

---@class g.World: objects.Class
local World = objects.Class("g:World")
World.TILE_SIZE = 101

function World:init()
    self.entities = objects.BufferedSet()
    self.items = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    self.heat = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    ---@type g.Job[]
    self.jobQueue = {}
    ---@type table<integer, g.World.ItemData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.boosters = {}
    ---@type table<integer, string[]>
    self.boostersInTiles = {}
    ---@type table<integer, g.World.DataProcessorData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.dataProcessors = {}
    ---@type table<integer, g.World.ServerData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.servers = {}
    self.particles = ParticleService()
    self.timer = 0 -- For per second update
    self.seconds = 0 -- how many seconds have elapsed (perSecondUpdate)
    self.analyticsSendTime = 0
    self.loadPercentage = 1
    zeroTileHeat(self.heat)
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


---@generic N: number|integer
---@param x1 N
---@param y1 N
---@param x2 N
---@param y2 N
---@return N
local function chessboardDistance(x1, y1, x2, y2)
    return math.max(math.abs(x1 - x2), math.abs(y1 - y2))
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

    -- Update job queues
    for i = #self.jobQueue, 1, -1 do
        local job = self.jobQueue[i]
        job.timeout = job.timeout - dt
        if job.timeout <= 0 then
            table.remove(self.jobQueue, i)
        end
    end

    -- Update electricity load
    local loads = 0
    table.clear(self.boosters)
    table.clear(self.boostersInTiles)
    table.clear(self.dataProcessors)
    table.clear(self.servers)
    ---@param item g.World.ItemData?
    self.items:foreach(function(item, x, y)
        if item then
            local itemInfo, category = g.getItemInfo(item.type)
            loads = loads + itemInfo.load
            local index = self.items:coordsToIndex(x, y)
            if category == "booster" then
                self.boosters[index] = item
                local boosterInfo = g.getItemInfo(item.type, "booster")
                local affectedTiles = RADIANCE_ALGORITHM[boosterInfo.radiateAlgorithm](boosterInfo.radiate)
                for _, tile in ipairs(affectedTiles) do
                    local tx, ty = x + tile[1], y + tile[2]
                    -- Insert booster tiles
                    if self.items:contains(tx, ty) then
                        local tindex = self.items:coordsToIndex(tx, ty)
                        self.boostersInTiles[tindex] = self.boostersInTiles[tindex] or {}
                        table.insert(self.boostersInTiles[tindex], item.type)
                    end
                end
            elseif category == "dataProcessor" then
                ---@cast item g.World.DataProcessorData
                self.dataProcessors[index] = item
            elseif category == "server" then
                ---@cast item g.World.ServerData
                self.servers[index] = item
            end

            -- Update tile positions
            item.tileX = x
            item.tileY = y
        end
    end)
    self.loadPercentage = math.min(1, loads / g.ask("getMaxLoadModifier"))

    -- Update tile heat
    zeroTileHeat(self.heat)
    for i, itemData in pairs(self.boosters) do
        local x, y = self.items:indexToCoords(i)
        local boosterInfo = g.getItemInfo(itemData.type, "booster")

        local affectedTiles = RADIANCE_ALGORITHM[boosterInfo.radiateAlgorithm](boosterInfo.radiate)
        for _, tile in ipairs(affectedTiles) do
            local tx, ty = x + tile[1], y + tile[2]

            if self.items:contains(tx, ty) then
                local heat = boosterInfo.getTileHeat(tile[1], tile[2]) * self.loadPercentage
                self.heat:set(tx, ty, self.heat:get(tx, ty) + heat)
            end
        end
    end

    -- Run data processor update
    local dpsModifier = g.ask("getDataThroughputModifier") --[[@as number]]
    local dpsMultiplier = g.ask("getDataThroughputMultiplier") --[[@as number]]
    for _, dpData in pairs(self.dataProcessors) do
        local dpInfo = g.getItemInfo(dpData.type, "data")

        -- Disconnect servers which are out of range
        for i = #dpData.connectsServers, 1, -1 do
            local serverData = dpData.connectsServers[i]
            local sx, sy = serverData.tileX, serverData.tileY
            if chessboardDistance(sx, sy, dpData.tileX, dpData.tileY) > dpInfo.wireLength then
                serverData.connectsTo = nil
                table.remove(dpData.connectsServers, i)
            end
        end

        if dpInfo.wireCount then
            -- Truncate connected servers to max wire count
            for i = #dpData.connectsServers, dpInfo.wireCount, -1 do
                local serverData = dpData.connectsServers[i]
                serverData.connectsTo = nil
                table.remove(dpData.connectsServers, i)
            end
        end

        dpData.dataPerSecond = math.max(dpInfo.dataPerSecond + dpsModifier, 0) * dpsMultiplier * self.loadPercentage
    end

    -- Run server update
    -- We need to do the server update in 3 pass: Computing the CPS, Compute data bottleneck, then updating the job
    -- progress. The data processor bottleneck calculation needs all server CPSes first.
    local perfMod = g.ask("getPerformanceModifier") --[[@as number]]
    local perfMultiplier = g.ask("getPerformanceMultiplier") --[[@as number]]
    -- Pass 1: Compute CPS
    for _, serverData in pairs(self.servers) do
        local serverInfo = g.getItemInfo(serverData.type, "server")

        if serverData.connectsTo then
            -- Pull job queue
            if not serverData.currentJob then
                local candidateIndex = nil
                local candidatePrio = math.huge
                for i, v in ipairs(self.jobQueue) do
                    local indices = helper.index(serverInfo.computePreference, v.category)
                    if indices and indices < candidatePrio then
                        candidateIndex = i
                        candidatePrio = indices
                    end
                end

                if candidateIndex then
                    serverData.currentJob = table.remove(self.jobQueue, candidateIndex)
                    serverData.jobProgress = 0
                end
            end

            -- Compute CPS
            serverData.computePerSecond = 0
            if serverData.currentJob then
                local heat = self.heat:get(serverData.tileX, serverData.tileY)
                local heatPerfMul = 1
                if heat > serverInfo.heatTolerance[2] then
                    -- Overheat. Reduce performance
                    heatPerfMul = serverInfo.heatTolerance[2] / heat
                elseif heat < serverInfo.heatTolerance[1] then
                    -- Chilling. Increase performance
                    local diff = serverInfo.heatTolerance[1] - heat
                    heatPerfMul = (serverInfo.heatTolerance[2] - serverInfo.heatTolerance[1]) / diff
                end
                local finalMul = perfMultiplier * self.loadPercentage * heatPerfMul
                serverData.computePerSecond = math.max(serverInfo.computePerSecond + perfMod, 0) * finalMul
            end
        end
    end
    -- Pass 2: Update data processor total data transmit
    for _, dpData in pairs(self.dataProcessors) do
        local dpInfo = g.getItemInfo(dpData.type, "data")
        local totalDPS = 0

        -- Compute theoretical DPS for all servers
        for _, serverData in ipairs(dpData.connectsServers) do
            if serverData.currentJob then
                local job = serverData.currentJob
                local dps = serverData.computePerSecond * job.outputData / job.computePower
                totalDPS = totalDPS + dps
            end
        end

        dpData.dataPerSecond = totalDPS
    end
    -- Pass 3: Update job progress
    for _, serverData in pairs(self.servers) do
        if serverData.currentJob then
            local job = serverData.currentJob
            local finalCPS = serverData.computePerSecond
            local dpData = assert(serverData.connectsTo)
            if dpData.serversDataPerSecond > dpData.dataPerSecond then
                local ratio = dpData.dataPerSecond / dpData.serversDataPerSecond
                -- Data bottleneck, reduce final CPSes
                finalCPS = finalCPS * ratio
            end

            serverData.jobProgress = serverData.jobProgress + finalCPS * dt
            if serverData.jobProgress >= job.computePower then
                g.call("jobCompleted", serverData, job)
                serverData.currentJob = nil
            end
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
end



---@param a g.Entity
---@param b g.Entity
local function sortOrder(a, b)
    local indexA = a.y + (a.drawOrder or 0)
    local indexB = b.y + (b.drawOrder or 0)
    return indexA < indexB
end


function World:_draw()
    prof_push("world:_draw")

    ---@type g.Entity[]
    local objlist = {}

    -- drawGround()

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
        drawEntity(e)
    end
    prof_pop() -- prof_push("entity draw")

    love.graphics.setColor(1, 1, 1)
    self.particles:draw()

    prof_pop() -- prof_push("world:_draw")
end



return World
