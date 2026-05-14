--[[

World

]]


local ParticleService = require(".particle.ParticleService")
local DataCollector = require(".data_collector")
local Z = require("lib.zorder")


---@param grid objects.Grid<number>
local function zeroTileHeat(grid)
    for x = 0, grid.width-1 do
        for y = 0, grid.height-1 do
            grid:set(x,y, 0)
        end
    end
end

---@class g.World.QueuedInput: g._InputSetWithAmount
---@field queue [g.Shape, g.ShapeColor][]


---@class g.World.MachineData
---@field type string Item ID
---@field tileX integer (readonly; updated every frame)
---@field tileY integer (readonly; updated every frame)
---@field heat number (readwrite)
---@field powerLoad number? (readonly; updated every frame)
---@field powerGenerate? number (readonly; updated every frame; if exist, can be in power network)
---@field powerNetwork g.World.PowerNetwork? (readonly; if nil = not connected to any network)
---@field processTime number? (readwrite; in seconds)
---@field processTimeCurrent number (readwrite; in seconds)
---@field processSpeedMultiplier number (readwrite)
---@field problems objects.Set<g.ItemProblems> (readwrite; updated every frame)
---@field input g.World.QueuedInput[]
---@field inputCycle integer round-robin indices cycle for the wire input
---@field output g._InputSetWithAmount? (readwrite; only applicable if it has outputs)
---@field outputCycle integer round-robin indices cycle for the wire output
---@field wireSpeedMultiplier number (readwrite)
---@field removed boolean
---@field removable boolean

---@class g.World.GeneratorData: g.World.MachineData
---@field duration number (readwrite; duration of the generating)
---@field timeout number (readwrite; if 0 = no power)


---@class g.World.PowerNetwork
---@field machines objects.Set<g.World.MachineData>
---@field totalPower number (readonly; updated every frame)
---@field totalLoad number (readonly; updated every frame)


---@class g.World.Wire2
---@field from g.World.MachineData (note: it's unidirectional)
---@field to g.World.MachineData (note: it's unidirectional)
---@field criterion g._InputSet (the set in this is passed by reference)
---@field shapes g.Shape[]
---@field colors g.ShapeColor[]
---@field positions number[] normalized [0, 1]


---@class g.World: objects.Class
local World = objects.Class("g:World")
World.TILE_SIZE = 101
World.WIRE_DPS = 100


local UNHIGHLIGHT_ALPHA = 0.33
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
    local col = gsman.mulColor(1, 1, 1, alpha)
    for _, tile in ipairs(tiles) do
        local absTx = tile[1] + tx
        local absTy = tile[2] + ty
        local x = (absTx) * consts.WORLD_TILE_SIZE
        local y = (absTy) * consts.WORLD_TILE_SIZE
        love.graphics.rectangle("fill", x, y, consts.WORLD_TILE_SIZE, consts.WORLD_TILE_SIZE)
    end
    col:pop()
end


---@param m g.World.MachineData
local function isGeneratorMachine(m)
    return m.powerGenerate ~= nil and m.powerLoad == nil
end

---@param m g.World.MachineData
local function isConsumerMachine(m)
    return m.powerGenerate == nil and m.powerLoad ~= nil
end

---@param m g.World.MachineData
local function isRelayMachine(m)
    return m.powerGenerate ~= nil and m.powerLoad ~= nil
end

local POWER_COLOR = objects.Color("#83d6d3")



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



function World:init()
    self.entities = objects.BufferedSet()
    ---@type objects.Grid<g.World.MachineData?>
    self.items = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    ---@type objects.Grid<number>
    self.heat = objects.Grid(World.TILE_SIZE, World.TILE_SIZE)
    ---@type table<g.World.MachineData, g.World.Wire2[]> `from == key`
    self.wireOutput = setmetatable({}, {__mode = "k"})
    ---@type table<g.World.MachineData, g.World.Wire2[]> `to == key`
    self.wireInput = setmetatable({}, {__mode = "k"})

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
end



---@param e g.Entity
local function drawEntity(e)
    if e.drawBelow then
        local col = gsman.setColor(1, 1, 1)
        e:drawBelow()
        col:pop()
    end

    local sx,sy = e.sx or 1, e.sy or 1
    if e.bulgeAnimation then
        local blg = assert(e.bulgeAnimation)
        local mag = 1 + (blg.time/blg.duration)*blg.magnitude
        sx = sx * mag
        sy = sy * mag
    end

    if e.image then
        local blend = gsman.setBlendMode(e.blendmode or "alpha", e.blendalphamode or "alphamultiply")
        local col = gsman.setColor(1, 1, 1, e.alpha or 1)
        g.drawImage(e.image, e.x+(e.ox or 0), e.y+(e.oy or 0), e.rot or 0, sx,sy)
        blend:pop()
        col:pop()
    end

    if e.draw then
        local col = gsman.setColor(1, 1, 1)
        e:draw()
        col:pop()
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

    -- Reset stuff
    table.clear(self.powerNetworks)
    table.clear(self.itemCounts)
    table.clear(self.itemInventoryCounts)
    ---@type g.World.MachineData[]
    local allMachines = {}
    self.items:foreach(function(machine, x, y)
        if machine then
            if machine.removed then
                self.wireInput[machine] = nil
                self.wireOutput[machine] = nil
                self.items:set(x, y, nil)
            else
                local minfo = g.getMachineInfo(machine.type)
                -- Update (SSOT)
                machine.tileX = x
                machine.tileY = y
                machine.powerLoad = minfo.powerLoad
                machine.powerGenerate = minfo.powerGenerate
                machine.heat = minfo.heat
                machine.wireSpeedMultiplier = 1
                machine.processSpeedMultiplier = 1
                machine.problems:clear()
                allMachines[#allMachines+1] = machine
            end
        end
    end)

    -- Update power consumption
    for _, machine in ipairs(allMachines) do
        local minfo = g.getMachineInfo(machine.type)
        if minfo.onUpdatePowerStage then
            minfo.onUpdatePowerStage(machine, dt)
        end
    end

    -- Update heat
    zeroTileHeat(self.heat)
    for _, machine in ipairs(allMachines) do
        local minfo = g.getMachineInfo(machine.type)
        if minfo.onUpdateHeatStage then
            minfo.onUpdateHeatStage(machine, dt)
        end
    end
    for _, machine in ipairs(allMachines) do
        local minfo = g.getMachineInfo(machine.type)
        if minfo.onUpdateTileHeatStage then
            minfo.onUpdateTileHeatStage(machine, dt)
        end
    end
    -- Radiate heat
    for _, machine in ipairs(allMachines) do
        local minfo = g.getMachineInfo(machine.type)
        for _, tile in ipairs(worldutil.getSpreadTiles("taxicab", minfo.heatRadiate)) do
            local tx, ty = machine.tileX + tile[1], machine.tileY + tile[2]

            if self.items:contains(tx, ty) then
                local divider = 2 ^ worldutil.getDistance("taxicab", tile[1], tile[2])
                local heat = machine.heat / divider
                self.heat:set(tx, ty, self.heat:get(tx, ty) + heat)
            end
        end
    end

    -- Update most properties for all machines
    for _, machine in ipairs(allMachines) do
        local minfo = g.getMachineInfo(machine.type)
        if minfo.onUpdate then
            minfo.onUpdate(machine, dt)
        end
    end

    --[[ TODO: Move this to individual machine
    -- Update power generator power
    for _, powerGen in pairs(self.powerGens) do
        local powerGenInfo = g.getItemInfo(powerGen.type, "powergen")
        powerGen.power = g.getProperty("getGeneratorLoad", powerGenInfo.power, 1, powerGenInfo)
    end
    ]]

    -- Run power network update
    ---@type objects.Set<g.World.PowerNetwork>
    local allPowerNodes = objects.Set()
    for _, machine in ipairs(allMachines) do
        if machine.powerNetwork then
            allPowerNodes:add(machine.powerNetwork)
        end
    end

    for _, powerNetwork in ipairs(allPowerNodes) do
        local totalLoad = 0
        local totalPower = 0

        for _, machine in ipairs(powerNetwork.machines) do
            if machine.powerGenerate then
                totalPower = totalPower + machine.powerGenerate
            end
            if machine.powerLoad then
                totalLoad = totalLoad + machine.powerLoad
            end
        end

        powerNetwork.totalPower = totalPower
        powerNetwork.totalLoad = totalLoad
    end

    -- Run wire update
    local wireSet = objects.Set() --[[@as objects.Set<g.World.Wire2>]]
    for _, wire in pairs(self.wireInput) do
        wireSet:add(wire)
    end
    for _, wire in pairs(self.wireOutput) do
        wireSet:add(wire)
    end
    -- Update data in wires
    for _, wire in ipairs(wireSet) do
        local srcLP = worldutil.getLoadPercentage(wire.from)
        local dstLP = worldutil.getLoadPercentage(wire.to)
        local lp1 = (wire.from.wireSpeedMultiplier + wire.to.wireSpeedMultiplier) / 2
        local lp2 = srcLP * dstLP * lp1
        local wireLength = worldutil.getWireLength(wire)
        local padding = worldutil.PHYSICAL_DATA_SIZE_IN_WIRE / wireLength
        local ndt = (World.WIRE_DPS * dt * lp2) / wireLength

        for i = #wire.positions, 1, -1 do
            local wall
            if wire.positions[i + 1] then
                wall = wire.positions[i + 1] - padding
            else
                wall = 1
            end

            wire.positions[i] = helper.clamp(wire.positions[i] + ndt, 0, wall)
        end
    end
    -- Poll data from wire inputs
    for _, machine in ipairs(allMachines) do
        if #machine.input > 0 and self.wireInput[machine] then
            for _, iset in ipairs(machine.input) do
                if #iset.queue < iset.amount then
                    local wis = self.wireInput[machine]
                    for j = 1, #wis do
                        local i = (machine.inputCycle + j) % #wis + 1
                        machine.inputCycle = i - 1

                        local wire = wis[i]
                        if g.isDataWireCompatible(wire, iset) then
                            local pos1 = helper.index(wire.positions, 1)
                            if pos1 then
                                iset.queue[#iset.queue+1] = {
                                    table.remove(wire.shapes, pos1),
                                    table.remove(wire.colors, pos1)
                                }
                                table.remove(wire.positions, pos1)
                            end

                            if #iset.queue >= iset.amount then
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    -- Run "processing" step
    for _, machine in ipairs(allMachines) do
        if machine.processTime then
            local processWasAdvanced = false
            if machine.processTimeCurrent >= machine.processTime then
                processWasAdvanced = self:_tryAdvanceProcess(machine)
            end

            local inputSatisfied = true
            for _, iset in ipairs(machine.input) do
                if #iset.queue < iset.amount then
                    inputSatisfied = false
                    break
                end
            end

            if inputSatisfied then
                machine.processTimeCurrent = math.min(
                    machine.processTimeCurrent + dt * machine.processSpeedMultiplier,
                    machine.processTime or 0
                )

                if not processWasAdvanced and machine.processTimeCurrent >= machine.processTime then
                    processWasAdvanced = self:_tryAdvanceProcess(machine)
                end

                if not processWasAdvanced then
                    machine.problems:add("data_bottleneck")
                end
            end
        end
    end

    -- Update machine problems
    for _, machine in ipairs(allMachines) do
        -- Power network
        if not machine.powerGenerate and machine.powerLoad > 0 then
            if not machine.powerNetwork then
                machine.problems:add("no_power")
            elseif machine.powerNetwork.totalLoad > machine.powerNetwork.totalPower then
                machine.problems:add("overloaded")
            end
        end

        -- Input wire
        -- TODO
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

        for _, machine in ipairs(allMachines) do
            local minfo = g.getMachineInfo(machine.type)
            if minfo.perSecondUpdate then
                minfo.perSecondUpdate(machine, self.seconds)
            end
        end

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
            local minfo = g.getMachineInfo(itemData.type)
            if minfo.wireLength > 0 then
                love.graphics.setColor(0, 1, 0)
                drawRangeVisualization(self.htx, self.hty, "chessboard", minfo.wireLength)
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
    local wiresToBeDrawn = objects.Set() --[[@as objects.Set<g.World.Wire2>]]
    local powerNetworks = objects.Set() --[[@as objects.Set<g.World.PowerNetwork>]]
    self.items:foreachInArea(
        center - worldSize,
        center - worldSize,
        center + worldSize,
        center + worldSize,
        function(machine, x, y)
            if machine then
                local cx, cy = (x + 0.5) * wtz, (y + 0.5) * wtz
                if machine.powerNetwork then
                    powerNetworks:add(machine.powerNetwork)
                end

                if visibleAreaPadded:containsCoords(cx, cy) then
                    if not machine.removable then
                        love.graphics.setColor(0, 0, 0)
                        love.graphics.draw(NONREMOVABLE_MESH, x * wtz, y * wtz, 0, wtz, wtz)
                    end

                    local probs = g.getMachineProblems(machine)
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
                    else
                        love.graphics.setColor(0.3, 0.3, 1)
                    end

                    love.graphics.draw(STATUS_MESH, cx, cy, 0, wtz * 1.1, wtz * 1.1, 0.5, 0.5)

                    love.graphics.setColor(0, 1, 0)
                    local minfo = g.getMachineInfo(machine.type)
                    if self.htx == x and self.hty == y then
                        if minfo.wireLength then
                            drawRangeVisualization(x, y, "chessboard", minfo.wireLength)
                        end
                    end

                    local trans = gsman.transform(cx, cy)
                    love.graphics.setColor(1, 1, 1)
                    minfo.onDraw(machine)
                    trans:pop()

                    for _, wire in ipairs(self.wireInput[machine] or {}) do
                        wiresToBeDrawn:add(wire)
                    end
                    for _, wire in ipairs(self.wireOutput[machine] or {}) do
                        wiresToBeDrawn:add(wire)
                    end
                end
            end
        end
    )
    prof_pop() -- prof_push("item_draw")

    -- Draw power network connectors
    prof_push("power_draw")
    for _, v in ipairs(powerNetworks) do
        self:_drawPowerLines(v, visibleArea, self.htx, self.hty)
    end
    prof_pop() -- prof_push("power_draw")

    -- Draw wire connectors
    prof_push("wire_draw")
    local t = love.timer.getTime()
    love.graphics.setColor(0, 0, 0)
    for _, wire in ipairs(wiresToBeDrawn) do
        local selectedSrc = self.htx == wire.from.tileX and self.hty == wire.from.tileY
        local selectedDst = self.htx == wire.to.tileX and self.hty == wire.to.tileY
        if selectedSrc or selectedDst then
            love.graphics.setColor(0, 0, 0, HIGHLIGHT_ALPHA)
        else
            love.graphics.setColor(0, 0, 0, UNHIGHLIGHT_ALPHA)
        end

        -- Draw line
        local x1 = (wire.from.tileX + 0.5) * wtz
        local y1 = (wire.from.tileY + 0.5) * wtz
        local x2 = (wire.to.tileX + 0.5) * wtz
        local y2 = (wire.to.tileY + 0.5) * wtz
        drawLine(x1, y1, x2, y2, 3)
        -- Draw arrow
        drawArrows(x1, y1, x2, y2, 6, t % 1)
    end
    prof_pop() -- prof_push("wire_draw")

    -- Draw packets
    prof_push("packet_draw")
    for _, wire in ipairs(wiresToBeDrawn) do
        for i, pos in ipairs(wire.positions) do
            local x = helper.lerp(wire.from.tileX + 0.5, wire.to.tileX + 0.5, pos) * wtz
            local y = helper.lerp(wire.from.tileY + 0.5, wire.to.tileY + 0.5, pos) * wtz
            love.graphics.setColor(g.SHAPE_COLORS[wire.colors[i]])
            -- TODO: Wire position
            g.drawImage(g.SHAPES[wire.shapes[i]].image, x, y, 0, 0.2, 0.2)
        end
    end
    prof_pop()

    -- Draw item problems status icons
    prof_push("item_problems_draw")
    love.graphics.setColor(1, 1, 1)
    local statusIconF = g.getMainFont(12)
    self.items:foreach(function(machine, tx, ty)
        if machine then
            local problems = g.getMachineProblems(machine)

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


---@param powerNetwork g.World.PowerNetwork
---@param visibleArea kirigami.Region
---@param htx integer?
---@param hty integer?
function World:_drawPowerLines(powerNetwork, visibleArea, htx, hty)
    local wtz = consts.WORLD_TILE_SIZE
    local t = g.getSn().worldTime % 1

    ---@type objects.Set<integer>
    local wires = objects.Set()

    for _, machine in ipairs(powerNetwork.machines) do
        if machine.powerGenerate or machine.powerLoad then
            local minfo = g.getMachineInfo(machine.type)
            local m1pos = self.items:coordsToIndex(machine.tileX, machine.tileY)
            local m1isgen = isGeneratorMachine(machine)
            local m1isrelay = isRelayMachine(machine)

            for _, tile in worldutil.getSpreadTiles("chessboard", minfo.wireLength) do
                local tx = tile[1] + machine.tileX
                local ty = tile[2] + machine.tileY
                -- The direction is encoded as Z.encode(from, to)
                -- from = Z.encode(machine1)
                -- to = Z.encode(machine2)
                local machine2 = self.items:contains(tx, ty) and self.items:get(tx, ty)

                if machine2 then
                    -- Rules:
                    -- Generator <-> Relay
                    -- Generator -> Consumer
                    -- Relay <-> Relay
                    -- Relay -> Consumer
                    local m2pos = self.items:coordsToIndex(tx, ty)
                    local m2isrelay = isRelayMachine(machine2)
                    if (m1isgen and m2isrelay) or (m1isrelay and m2isrelay) then
                        -- Bi-directional
                        wires:add(Z.encode_positive(m1pos, m2pos))
                        wires:add(Z.encode_positive(m2pos, m1pos))
                    elseif (m1isgen or m1isrelay) and isConsumerMachine(machine2) then
                        -- Uni-directional
                        wires:add(Z.encode_positive(m1pos, m2pos))
                    end
                end
            end
        end
    end

    -- Now draw them
    for _, wire in ipairs(wires) do
        local from, to = Z.decode_positive(wire)
        local m1x, m1y = self.items:indexToCoords(from)
        local m2x, m2y = self.items:indexToCoords(to)
        local x1, y1 = (m1x + 0.5) * wtz, (m1y + 0.5) * wtz
        local x2, y2 = (m2x + 0.5) * wtz, (m2y + 0.5) * wtz
        -- FIXME: Do this check when iterating machines instead of wires?
        if visibleArea:containsCoords(x1, y1) or visibleArea:containsCoords(x2, y2) then
            if htx == m1x and hty == m1y or htx == m2x and hty == m2y then
                love.graphics.setColor(POWER_COLOR)
                drawArrows(x1, y1, x2, y2, 6, t)
                drawArrows(x2, y2, x1, y1, 6, t)
            end
        end
    end
end


---@param tx integer?
---@param ty integer?
function World:_setHoveredTile(tx, ty)
    self.htx, self.hty = tx, ty
end



---@param machine g.World.MachineData
function World:_tryAdvanceProcess(machine)
    local minfo = g.getMachineInfo(machine.type)
    if not minfo.onProcessFinished then
        return true
    end

    if minfo.onProcessFinished(machine) then
        machine.processTimeCurrent = 0

        -- Destroy input datas
        for _, iset in ipairs(machine.input) do
            table.clear(iset.queue)
        end

        return true
    end

    return false
end



---@param minfo g.MachineInfo
---@param mod number?
---@param mul number?
function World:computeLoadModifier(minfo, mod, mul)
    local v = self.loadModifiers[minfo.type]
    if not v then
        v = {dirty = true, modifier = 0, multiplier = 1}
        self.loadModifiers[minfo.type] = v
    end

    if v.dirty then
        v.modifier = g.ask("getLoadModifier", minfo)
        v.multiplier = g.ask("getLoadMultiplier", minfo)
        v.dirty = false
    end

    return math.max(math.max(minfo.powerLoad + v.modifier + (mod or 0), 0) * v.multiplier * (mul or 1), 0)
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
        if g.isMachineUnlocked(itemid) then
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

    local minfo = g.getMachineInfo(itemId)
    ---@type g.World.MachineData
    local machine = {
        type = itemId,
        tileX = tx,
        tileY = ty,
        heat = minfo.heat,
        powerLoad = minfo.powerLoad,
        powerGenerate = minfo.powerGenerate,
        powerNetwork = nil,
        processTime = minfo.processTime,
        processTimeCurrent = 0,
        processSpeedMultiplier = 1,
        problems = objects.Set(),
        input = {},
        inputCycle = 1,
        output = nil,
        outputCycle = 1,
        wireSpeedMultiplier = 1,
        removed = false,
        removable = removable,
    }

    for _, v in ipairs(minfo.input) do
        machine.input[#machine.input+1] = {
            queue = {},
            amount = v.amount,
            shapes = objects.Set(v.shapes),
            colors = objects.Set(v.colors),
        }
    end

    if minfo.output then
        machine.output = {
            queue = {},
            amount = minfo.output.amount,
            shapes = objects.Set(minfo.output.shapes),
            colors = objects.Set(minfo.output.colors),
        }
    end

    if minfo.init then
        minfo.init(machine)
    end

    self.items:set(tx, ty, machine)

    return machine
end

---@param wire g.World.Wire2
function World:_disconnectWire(wire)
    for i, w in ipairs(self.wireInput[wire.to]) do
        if w == wire then
            table.remove(self.wireInput[wire.to], i)
            break
        end
    end

    for i, w in ipairs(self.wireOutput[wire.from]) do
        if w == wire then
            table.remove(self.wireOutput[wire.from], i)
            break
        end
    end
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


--- Buses

--- End Buses



return World
