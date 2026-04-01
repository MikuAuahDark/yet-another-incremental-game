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
---@field load integer (readonly; updated every frame)
---@field powerNetwork g.World.PowerNetwork? (readonly; if nil = not connected to any network)
---@field removed boolean

---@class g.World.ServerData: g.World.ItemData
---@field currentJob g.Job?
---@field jobProgress number
---@field connectedOutputs g.World.DataOutputData[] (readonly; connected data outputs, quick lookup only)
---@field connectedInputs g.World.DataInputData[] (readonly; connected data inputs, quick lookup only)
---@field activeOutput g.World.DataOutputData? (readonly; the data output used this frame)
---@field computePerSecond number (readonly; updated every frame) CPS with heat, buff, and load applied

---@class g.World.DataInputData: g.World.ItemData
---@field connectsServers g.World.ServerData[] (readwrite; connects to this server, source of truth)

---@class g.World.DataOutputData: g.World.ItemData
---@field connectsServers g.World.ServerData[] (readwrite; connects to this server, source of truth)
---@field dataPerSecond number (readonly; updated every frame)
---@field wireDPS number (readonly; updated every frame)

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


---@class g.World: objects.Class
local World = objects.Class("g:World")
World.TILE_SIZE = 101


---@param seed integer
local function generateWorldTexture(seed)
    -- Create tile "texture"
    local rng = love.math.newRandomGenerator(seed)
    ---@type [number,number,number,number,number?,number?,number?,number?][]
    local vertices = {}
    local wtz = consts.WORLD_TILE_SIZE * World.TILE_SIZE
    for _ = 1, 20000 do
        local radius = helper.lerp(4, 24, rng:random())
        local a1 = rng:random() * math.pi * 2
        local a2 = rng:random() * math.pi * 2
        local a3 = rng:random() * math.pi * 2
        -- Sort a1 through a3 to be largest first
        if a1 < a2 then
            a1, a2 = a2, a1
        end
        if a2 < a3 then
            a2, a3 = a3, a2
        end
        if a1 < a2 then
            a1, a2 = a2, a1
        end

        local ox = helper.lerp(radius, wtz - radius, rng:random())
        local oy = helper.lerp(radius, wtz - radius, rng:random())
        local x = ox + math.cos(a1) * radius
        local y = oy + math.sin(a1) * radius
        vertices[#vertices+1] = {x, y, x / wtz, y / wtz, 0.5, 0.5, 0.5, helper.lerp(0.3, 0.7, rng:random())}
        x = ox + math.cos(a2) * radius
        y = oy + math.sin(a2) * radius
        vertices[#vertices+1] = {x, y, x / wtz, y / wtz, 0.5, 0.5, 0.5, helper.lerp(0.3, 0.7, rng:random())}
        x = ox + math.cos(a3) * radius
        y = oy + math.sin(a3) * radius
        vertices[#vertices+1] = {x, y, x / wtz, y / wtz, 0.5, 0.5, 0.5, helper.lerp(0.3, 0.7, rng:random())}
    end

    return love.graphics.newMesh(vertices, "triangles", "static")
end

---@param itemData g.World.ItemData
local function getLoadPercentage(itemData)
    if itemData.powerNetwork and itemData.powerNetwork.totalPower > 0 then
        -- If the totalLoad is 0, it will be 1/0 -> inf -> 1 again
        return math.min(itemData.powerNetwork.totalPower / itemData.powerNetwork.totalLoad)
    end
    return 0
end


local function drawPowerLines(pool)
    local wtz = consts.WORLD_TILE_SIZE
    for _, node in pairs(pool) do
        local x1 = (node.tileX + 0.5) * wtz
        local y1 = (node.tileY + 0.5) * wtz
        for _, other in ipairs(node.connectsPowerNodes) do
            love.graphics.line(x1, y1, (other.tileX + 0.5) * wtz, (other.tileY + 0.5) * wtz)
        end
        for _, consumer in ipairs(node.connectsTo) do
            love.graphics.line(x1, y1, (consumer.tileX + 0.5) * wtz, (consumer.tileY + 0.5) * wtz)
        end
    end
end


function World:init()
    self.entities = objects.BufferedSet()
    self.items = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    self.heat = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    ---@type g.Job[]
    self.jobQueue = {}
    ---@type table<integer, g.World.ItemData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
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
    self.maxJobs = 0 -- (read-only) Updated every frame
    zeroTileHeat(self.heat)

    self.cpsCollector = DataCollector(60)
    ---@type table<string, {dirty:boolean,modifier:number,multiplier:number}>
    self.loadModifiers = {}
    ---@type table<string, [number,number]> 1st value is current time, 2nd value is spawn time
    self.jobPoller = {}

    self.worldTexture = generateWorldTexture(12345)
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
    local maxJobs = 0
    table.clear(self.boosters)
    table.clear(self.boostersInTiles)
    table.clear(self.dataProcessors)
    table.clear(self.dataInputs)
    table.clear(self.servers)
    table.clear(self.powerGens)
    table.clear(self.powerRelays)
    table.clear(self.powerNetworks)
    ---@param item g.World.ItemData?
    self.items:foreach(function(item, x, y)
        if item then
            local itemInfo, category = g.getItemInfo(item.type)
            item.load = self:computeLoadModifier(itemInfo)
            item.powerNetwork = nil

            loads = loads + item.load
            local index = self.items:coordsToIndex(x, y)

            if category == "booster" then
                self.boosters[index] = item
                ---@cast itemInfo g.BoosterInfo

                local affectedTiles = worldutil.getSpreadTiles(itemInfo.radiateAlgorithm, itemInfo.radiate)
                for _, tile in ipairs(affectedTiles) do
                    local tx, ty = x + tile[1], y + tile[2]
                    -- Insert booster tiles
                    if self.items:contains(tx, ty) then
                        local tindex = self.items:coordsToIndex(tx, ty)
                        self.boostersInTiles[tindex] = self.boostersInTiles[tindex] or {}
                        table.insert(self.boostersInTiles[tindex], item)
                    end
                end
            elseif category == "data" then
                ---@cast item g.World.DataOutputData
                self.dataProcessors[index] = item
            elseif category == "indata" then
                ---@cast item g.World.DataInputData
                ---@cast itemInfo g.DataInInfo
                self.dataInputs[index] = item
                maxJobs = maxJobs + itemInfo.maxJobQueue
            elseif category == "server" then
                ---@cast item g.World.ServerData
                self.servers[index] = item
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
    self.maxJobs = maxJobs

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
                    if not visited[other] then
                        local otherInfo = g.getItemInfo(other.type)
                        ---@cast otherInfo g.PowerGenInfo | g.PowerRelayInfo
                        local dist = worldutil.getDistance("chessboard", node.tileX - other.tileX, node.tileY - other.tileY)
                        if dist <= math.max(nodeInfo.wireLength, otherInfo.wireLength) then
                            visited[other] = true
                            queue[#queue+1] = other
                            node.connectsPowerNodes[#node.connectsPowerNodes+1] = other
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
                ---@cast itemInfo g.BoosterInfo
                local affectedTiles = worldutil.getSpreadTiles(itemInfo.radiateAlgorithm, itemInfo.radiate)
                for _, tile in ipairs(affectedTiles) do
                    local tx, ty = x + tile[1], y + tile[2]

                    if self.items:contains(tx, ty) then
                        local heat = itemInfo.getTileHeat(tile[1], tile[2]) * getLoadPercentage(itemData)
                        self.heat:set(tx, ty, self.heat:get(tx, ty) + heat)
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

        -- Disconnect servers which are out of range or invalid
        for i = #dpData.connectsServers, 1, -1 do
            local serverData = dpData.connectsServers[i]
            local sx, sy = serverData.tileX, serverData.tileY
            if serverData.removed or worldutil.getDistance("chessboard", sx - dpData.tileX, sy - dpData.tileY) > dpInfo.wireLength then
                table.remove(dpData.connectsServers, i)
            end
        end

        -- Connect servers which are in range
        local range = dpInfo.wireLength
        for dx = -range, range do
            for dy = -range, range do
                local tx, ty = dpData.tileX + dx, dpData.tileY + dy
                local item = self.items:get(tx, ty)
                if item and not item.removed then
                    local _, category = g.getItemInfo(item.type)
                    if category == "server" then
                        ---@cast item g.World.ServerData
                        -- Check if already in connectsServers
                        if not helper.index(dpData.connectsServers, item) then
                            dpData.connectsServers[#dpData.connectsServers+1] = item
                        end
                    end
                end
            end
        end

        --- Compute DPS
        dpData.dataPerSecond = g.getProperty("getDataThroughput", dpInfo.dataPerSecond, getLoadPercentage(dpData), dpInfo)
        dpData.wireDPS = g.getProperty("getWireThroughput", dpInfo.wireDPS, 1, dpInfo)
    end

    -- Run data input update
    for _, diData in pairs(self.dataInputs) do
        local diInfo = g.getItemInfo(diData.type, "indata")

        -- Disconnect servers which are out of range or invalid
        for i = #diData.connectsServers, 1, -1 do
            local serverData = diData.connectsServers[i]
            local sx, sy = serverData.tileX, serverData.tileY
            if serverData.removed or worldutil.getDistance("chessboard", sx - diData.tileX, sy - diData.tileY) > diInfo.wireLength then
                table.remove(diData.connectsServers, i)
            end
        end

        -- Connect servers which are in range
        local range = diInfo.wireLength
        for dx = -range, range do
            for dy = -range, range do
                local tx, ty = diData.tileX + dx, diData.tileY + dy
                local item = self.items:get(tx, ty)
                if item and not item.removed then
                    local _, category = g.getItemInfo(item.type)
                    if category == "server" then
                        ---@cast item g.World.ServerData
                        -- Check if already in connectsServers
                        if not helper.index(diData.connectsServers, item) then
                            diData.connectsServers[#diData.connectsServers+1] = item
                        end
                    end
                end
            end
        end

        -- Sync connectedInputs for quick lookup
        for _, serverData in ipairs(diData.connectsServers) do
            if not helper.index(serverData.connectedInputs, diData) then
                serverData.connectedInputs[#serverData.connectedInputs+1] = diData
            end
        end
    end

    -- Clear connectedOutputs/Inputs first to be rebuild
    for _, serverData in pairs(self.servers) do
        table.clear(serverData.connectedOutputs)
        table.clear(serverData.connectedInputs)
    end
    for _, dpData in pairs(self.dataProcessors) do
        for _, serverData in ipairs(dpData.connectsServers) do
            serverData.connectedOutputs[#serverData.connectedOutputs+1] = dpData
        end
    end
    for _, diData in pairs(self.dataInputs) do
        for _, serverData in ipairs(diData.connectsServers) do
            serverData.connectedInputs[#serverData.connectedInputs+1] = diData
        end
    end

    -- Run server update
    -- We need to do the server update in multiple pass: Computing the CPS, then updating the job progress.
    local perfMod = g.ask("getPerformanceModifier") --[[@as number]]
    local perfMultiplier = g.ask("getPerformanceMultiplier") --[[@as number]]
    local cps = 0
    -- Pass 1: Compute CPS
    for _, serverData in pairs(self.servers) do
        local serverInfo = g.getItemInfo(serverData.type, "server")

        if #serverData.connectedOutputs > 0 and #serverData.connectedInputs > 0 then
            -- Pull job queue
            if not serverData.currentJob then
                local candidateIndex = nil
                local candidatePrio = math.huge
                for i, v in ipairs(self.jobQueue) do
                    -- Check if any connected input can handle this job category
                    local canHandle = false
                    for _, diData in ipairs(serverData.connectedInputs) do
                        local diInfo = g.getItemInfo(diData.type, "indata")
                        if diInfo.queuesJob == v.category then
                            canHandle = true
                            break
                        end
                    end

                    if canHandle then
                        local indices = helper.index(serverInfo.computePreference, v.category)
                        if indices and indices < candidatePrio then
                            candidateIndex = i
                            candidatePrio = indices
                        end
                    end
                end

                if candidateIndex then
                    serverData.currentJob = table.remove(self.jobQueue, candidateIndex)
                    serverData.jobProgress = 0
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
                local boosterInfo = g.getItemInfo(booster.type, "booster")
                local reltx = serverData.tileX - booster.tileX
                local relty = serverData.tileY - booster.tileY
                boosterMod = boosterMod + boosterInfo.getPerformanceModifier(reltx, relty)
                boosterMul = boosterMul * boosterInfo.getPerformanceMultiplier(reltx, relty)
            end
        end

        -- Compute CPS
        local finalMod = serverInfo.computePerSecond + perfMod + boosterMod
        local finalMul = perfMultiplier * getLoadPercentage(serverData) * heatPerfMul * boosterMul
        serverData.computePerSecond = math.max(finalMod, 0) * finalMul
    end
    -- Pass 2: Data transmit logic (packing)
    ---@type table<g.World.DataOutputData, number>
    local currentTransmit = {}
    for _, serverData in pairs(self.servers) do
        serverData.activeOutput = nil
        local job = serverData.currentJob
        if job and #serverData.connectedOutputs > 0 then
            local requiredDPS = serverData.computePerSecond * job.outputData / job.computePower
            for _, dpData in ipairs(serverData.connectedOutputs) do
                local dpInfo = g.getItemInfo(dpData.type, "data")
                local wireDPS = dpInfo.wireDPS or (dpInfo.dataPerSecond / 4)
                local capacity = dpData.dataPerSecond
                local used = currentTransmit[dpData] or 0

                if requiredDPS <= wireDPS and requiredDPS <= (capacity - used) then
                    serverData.activeOutput = dpData
                    currentTransmit[dpData] = used + requiredDPS
                    break
                end
            end
        end
    end
    -- Pass 3: Update job progress
    for _, serverData in pairs(self.servers) do
        local job = serverData.currentJob
        if job and serverData.activeOutput then
            serverData.jobProgress = serverData.jobProgress + serverData.computePerSecond * dt
            cps = cps + serverData.computePerSecond * dt
            if serverData.jobProgress >= job.computePower then
                g.call("jobCompleted", serverData, job)
                g.addResources(job.resource)
                serverData.currentJob = nil
            end
        end
    end
    self.cpsCollector:insert(dt, cps)

    -- Run job poll
    for k, ji in pairs(g.VALID_JOBS) do
        if not self.jobPoller[k] then
            self.jobPoller[k] = {0, 0}
        end
        local jpinfo = self.jobPoller[k]

        if g.ask("isJobUnlocked", k) then
            local catname = g.getJobCategoryName(ji.category, true)
            -- Yea these stat name and evbus name is MSOT.
            -- Is there a better way?
            local stat = g.VALID_STATS[catname.."JobFrequency"]
            -- TODO: Cache this
            local jobFreqMod = g.ask(stat.addQuestion)
            local jobFreqMul = g.ask(stat.multQuestion)
            local spawnChance = g.getProperty("getJobFrequency", jobFreqMod, jobFreqMul, k)
            jpinfo[2] = spawnChance
            if spawnChance > 0 then
                local time = 1 / spawnChance -- the stat is frequency
                jpinfo[1] = jpinfo[1] + dt

                while jpinfo[1] >= time do
                    if #self.jobQueue < maxJobs then
                        local job = g.genJob(k)
                        g.queueJob(job)
                    end

                    jpinfo[1] = jpinfo[1] - time
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
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.worldTexture)
        love.graphics.setStencilMode() -- should be harmless
    end

    -- Draw tile heat
    local wtz = consts.WORLD_TILE_SIZE
    ---@param heat number
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

    ---@type g.Entity[]
    local objlist = {}

    -- Draw items
    prof_push("item_draw")
    ---@param itemData g.World.ItemData?
    self.items:foreach(function(itemData, x, y)
        if itemData then
            local itemInfo = g.getItemInfo(itemData.type)
            local trans = gsman.transform((x + 0.5) * wtz, (y + 0.5) * wtz)
            love.graphics.setColor(1, 1, 1)
            itemInfo.draw(itemData)
            trans:pop()
        end
    end)
    prof_pop() -- prof_push("item_draw")

    -- Draw data output connectors
    prof_push("dpcon_draw")
    love.graphics.setColor(0, 0, 0)
    local lw = gsman.setLineWidth(4)
    self.items:foreach(function(itemData, x, y)
        if itemData then
            local _, category = g.getItemInfo(itemData.type)
            if category == "data" then
                ---@cast itemData g.World.DataOutputData
                for _, svr in ipairs(itemData.connectsServers) do
                    love.graphics.line(
                        (x + 0.5) * wtz,
                        (y + 0.5) * wtz,
                        (svr.tileX + 0.5) * wtz,
                        (svr.tileY + 0.5) * wtz
                    )
                end
            elseif category == "indata" then
                ---@cast itemData g.World.DataInputData
                -- TODO: Change Data Input wire color to distinguish it from Data Output
                love.graphics.setColor(0, 0, 0)
                for _, svr in ipairs(itemData.connectsServers) do
                    love.graphics.line(
                        (x + 0.5) * wtz,
                        (y + 0.5) * wtz,
                        (svr.tileX + 0.5) * wtz,
                        (svr.tileY + 0.5) * wtz
                    )
                end
            end
        end
    end)
    lw:pop()
    prof_pop() -- prof_push("dpcon_draw")

    -- Draw power network connectors
    prof_push("power_draw")
    love.graphics.setColor(objects.Color("#83d6d3"))
    local lw2 = gsman.setLineWidth(4)
    drawPowerLines(self.powerGens)
    drawPowerLines(self.powerRelays)
    lw2:pop()
    prof_pop() -- prof_push("power_draw")

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
        local col = gsman.setColor(1, 1, 1)
        drawEntity(e)
        col:pop()
    end
    prof_pop() -- prof_push("entity draw")

    love.graphics.setColor(1, 1, 1)
    self.particles:draw()

    prof_pop() -- prof_push("world:_draw")
end



---@param itemInfo g.ItemInfo
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
function World:canPutItem(tx, ty)
    -- Is coords on grid?
    if not self.items:contains(tx, ty) or self.items:get(tx, ty) then
        return false
    end

    -- Check world size constraints
    local center = math.floor(World.TILE_SIZE / 2)
    local worldSize = g.stats.WorldTileSize
    if math.abs(tx - center) > worldSize or math.abs(ty - center) > worldSize then
        return false
    end

    return true
end

---@param itemId string
---@param tx integer
---@param ty integer
function World:putItem(itemId, tx, ty)
    if not self:canPutItem(tx, ty) then
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
            load = itemInfo.load,
            currentJob = nil,
            jobProgress = 0,
            connectedOutputs = {},
            connectedInputs = {},
            activeOutput = nil,
            computePerSecond = 0,
        }
    elseif category == "data" then
        ---@type g.World.DataOutputData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            load = itemInfo.load,
            connectsServers = {},
            dataPerSecond = 0,
            wireDPS = 0,
        }
    elseif category == "booster" then
        ---@type g.World.ItemData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            load = itemInfo.load,
        }
    elseif category == "indata" then
        ---@type g.World.DataInputData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            load = itemInfo.load,
            connectsServers = {},
        }
    elseif category == "powergen" or category == "powerrelay" then
        ---@type g.World.PowerData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            load = itemInfo.load,
            power = 0,
            connectsTo = {},
            connectsPowerNodes = {},
        }
    else
        error("fixme category "..category)
    end

    self.items:set(tx, ty, itemData)
    return itemData
end



return World
