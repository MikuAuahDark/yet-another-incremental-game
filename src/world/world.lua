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
---@field removed boolean

---@class g.World.ServerData: g.World.ItemData
---@field currentJob g.Job?
---@field jobProgress number
---@field connectsTo g.World.DataProcessorData? (readonly; connect to this data processor, quick lookup only)
---@field computePerSecond number (readonly; updated every frame) CPS with heat, buff, and load applied
---@field finalCPS number (readonly; updated every frame) Actual CPS, taking data bottleneck into account

---@class g.World.DataProcessorData: g.World.ItemData
---@field connectsServers g.World.ServerData[] (readwrite; connects to this server, source of truth)
---@field dataPerSecond number (readonly; updated every frame)
---@field serversDataPerSecond number (readonly; updated every frame)

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
    ---@type table<integer, g.World.DataProcessorData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.dataProcessors = {}
    ---@type table<integer, g.World.ServerData> for quick lookup (key is 1D grid coord, use Grid:indexToCoords)
    self.servers = {}
    self.particles = ParticleService()
    self.timer = 0 -- For per second update
    self.seconds = 0 -- how many seconds have elapsed (perSecondUpdate)
    self.analyticsSendTime = 0
    self.loadPercentage = 1
    self.currentLoad = 0 -- Updated every frame
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
    table.clear(self.boosters)
    table.clear(self.boostersInTiles)
    table.clear(self.dataProcessors)
    table.clear(self.servers)
    ---@param item g.World.ItemData?
    self.items:foreach(function(item, x, y)
        if item then
            local itemInfo, category = g.getItemInfo(item.type)
            item.load = self:computeLoadModifier(itemInfo)
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
    self.currentLoad = loads
    self.loadPercentage = math.min(1, g.stats.MaxLoad / loads)

    -- Update tile heat
    zeroTileHeat(self.heat)
    self.items:foreach(function(itemData, x, y)
        if itemData then
            local itemInfo, category = g.getItemInfo(itemData.type)
            if category == "booster" then
                ---@cast itemInfo g.BoosterInfo
                local affectedTiles = worldutil.getSpreadTiles(itemInfo.radiateAlgorithm, itemInfo.radiate)
                for _, tile in ipairs(affectedTiles) do
                    local tx, ty = x + tile[1], y + tile[2]

                    if self.items:contains(tx, ty) then
                        local heat = itemInfo.getTileHeat(tile[1], tile[2]) * self.loadPercentage
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

    -- Run data processor update
    local dpsModifier = g.ask("getDataThroughputModifier") --[[@as number]]
    local dpsMultiplier = g.ask("getDataThroughputMultiplier") --[[@as number]]
    for _, dpData in pairs(self.dataProcessors) do
        local dpInfo = g.getItemInfo(dpData.type, "data")

        -- Disconnect servers which are out of range
        for i = #dpData.connectsServers, 1, -1 do
            local serverData = dpData.connectsServers[i]
            local sx, sy = serverData.tileX, serverData.tileY
            -- Enforce constraints (SSOT)
            serverData.connectsTo = dpData
            if worldutil.getDistance("chessboard", sx - dpData.tileX, sy - dpData.tileY) > dpInfo.wireLength then
                serverData.connectsTo = nil
                table.remove(dpData.connectsServers, i)
            end
        end

        if dpInfo.wireCount then
            -- Truncate connected servers to max wire count
            for i = #dpData.connectsServers, dpInfo.wireCount + 1, -1 do
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
    local cps = 0
    -- Pass 1: Compute CPS
    for _, serverData in pairs(self.servers) do
        local serverInfo = g.getItemInfo(serverData.type, "server")

        if serverData.connectsTo and serverData.connectsTo.removed then
            -- Data processor is gone
            serverData.connectsTo = nil
        end

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
        end

        -- Compute CPS
        serverData.computePerSecond = 0
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

        local finalMod = serverInfo.computePerSecond + perfMod + boosterMod
        local finalMul = perfMultiplier * self.loadPercentage * heatPerfMul * boosterMul
        serverData.computePerSecond = math.max(finalMod, 0) * finalMul
    end
    -- Pass 2: Update data processor total data transmit
    for _, dpData in pairs(self.dataProcessors) do
        local totalDPS = 0

        -- Compute theoretical DPS for all servers
        for _, serverData in ipairs(dpData.connectsServers) do
            local job = serverData.currentJob
            if job then
                local dps = serverData.computePerSecond * job.outputData / job.computePower
                totalDPS = totalDPS + dps
            end
        end

        dpData.serversDataPerSecond = totalDPS
    end
    -- Pass 3: Update job progress
    for _, serverData in pairs(self.servers) do
        serverData.finalCPS = 0
        local job = serverData.currentJob
        if job and serverData.connectsTo then
            local finalCPS = serverData.computePerSecond
            local dpData = assert(serverData.connectsTo)
            if dpData.serversDataPerSecond > dpData.dataPerSecond then
                local ratio = dpData.dataPerSecond / dpData.serversDataPerSecond
                -- Data bottleneck, reduce final CPSes
                finalCPS = finalCPS * ratio
            end

            serverData.finalCPS = finalCPS
            serverData.jobProgress = serverData.jobProgress + finalCPS * dt
            cps = cps + finalCPS * dt
            if serverData.jobProgress >= job.computePower then
                g.call("jobCompleted", serverData, job)
                g.addResources(job.resource)
                serverData.currentJob = nil
            end
        end
    end
    self.cpsCollector:insert(dt, cps)

    -- Run job poll
    local maxJobs = helper.round(g.stats.MaxJobQueue)
    for k, ji in pairs(g.VALID_JOBS) do
        if not self.jobPoller[k] then
            self.jobPoller[k] = {0, 0}
        end
        local jpinfo = self.jobPoller[k]

        local catname = g.getJobCategoryName(ji.category, true)
        -- Yea these stat name and evbus name is MSOT.
        -- Is there a better way?
        local stat = g.stats[catname.."JobFrequency"]
        local spawnChance = math.max(g.getProperty("getJobFrequency", stat), 0)
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
        local size = consts.WORLD_TILE_SIZE * World.TILE_SIZE
        love.graphics.setColor(objects.Color("#b0b0b0"))
        love.graphics.rectangle("fill", 0, 0, size, size)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(self.worldTexture)
    end

    -- Draw tile heat
    ---@param heat number
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

    -- Draw data processor connectors
    prof_push("dpcon_draw")
    love.graphics.setColor(0, 0, 0)
    local lw = gsman.setLineWidth(4)
    self.items:foreach(function(itemData, x, y)
        if itemData then
            local _, category = g.getItemInfo(itemData.type)
            if category == "data" then
                ---@cast itemData g.World.DataProcessorData
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
    if not self.items:contains(tx, ty) or self.items:get(tx, ty) then
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
            connectsTo = nil,
            computePerSecond = 0,
            finalCPS = 0,
        }
    elseif category == "data" then
        ---@type g.World.DataProcessorData
        itemData = {
            type = itemId,
            tileX = tx,
            tileY = ty,
            removed = false,
            load = itemInfo.load,
            connectsServers = {},
            dataPerSecond = 0,
            serversDataPerSecond = 0,
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
    else
        error("fixme category "..category)
    end

    self.items:set(tx, ty, itemData)
    return itemData
end



return World
