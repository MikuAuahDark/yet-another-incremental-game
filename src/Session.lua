


local World = require("src.world.world")
local Tree = require("src.upgrades.Tree")
local Z = require("lib.zorder")


---@class g.Session.TutorialState
---@field start integer (-1 = tutorial completed)
---@field upgrades boolean

---@class g.Session: objects.Class
---@field worldTime number
---@field playtime number
---@field idletime number
---@field prestige number
---@field resources g.Resources
---@field resourceUnlocks table<g.Resources, boolean?>
---@field mainWorld g.World
---@field metrics table<string, number>
---@field stats table<string, number>
---@field tree g.Tree
---@field paused boolean
---@field pauseReason? "button"|"debug"
---@field showTutorials g.Session.TutorialState
local Session = objects.Class("g:Session")



--[[

Session class.

IMPORTANT NOTE:
Session should be like a data-class.

Dont create complex getters.
just provide the raw data, keep it simple.

]]

function Session:init()
    self.worldTime = 0.
    self.prestige = 0
    self.playtime = 0
    self.idletime = 0

    self.resources = {}
    self.resourceUnlocks = {}

    for _,resId in ipairs(g.RESOURCE_LIST) do
        self.resources[resId] = 0
        self.resourceUnlocks[resId] = false
    end
    self.resourceUnlocks["money"] = true

    self.mainWorld = World()

    -- metrics are running-totals of stuff.
    -- E.g. "how much logs has been collected in total?"
    self.metrics = {--[[
        [metricName] -> number
    ]]}

    self.tree = Tree()

    -- reset stats:
    for k,sta in pairs(g.VALID_STATS) do
        g.stats[k] = sta.startingValue
    end

    self.paused = false

    self.showTutorials = {
        start = -1, --settings.isTutorialShown() and 0 or -1,
        upgrades = settings.isTutorialShown()
    }
end

if false then
    ---@return g.Session
    ---@diagnostic disable-next-line: cast-local-type, missing-return
    function Session() end
end



local function nilIsTrue(value)
    if value == nil then
        return true
    end

    return not not value
end



--- updates session and main world. should only be called once, (hence _)
---@param dt any
function Session:_update(dt)
    prof_push("Session:_update")

    if self.paused then
        dt = 0
    end

    for _,resId in ipairs(g.RESOURCE_LIST) do
        if self.resources[resId] > 0 then
            self.resourceUnlocks[resId] = true
        end
    end

    for stat, t in pairs(g.VALID_STATS) do
        local mod = g.ask(t.addQuestion) + t.startingValue
        local mult = g.ask(t.multQuestion)
        g.stats[stat] = mod*mult
    end
    self.worldTime = self.worldTime + dt
    self.playtime = self.playtime + dt
    self.mainWorld:_update(dt)

    prof_pop()
end


---@param reason? "button"|"debug"
function Session:setPaused(reason)
    if reason then
        self.paused = true
        self.pauseReason = reason
    else
        self.paused = false
        self.pauseReason = nil
    end
end


---@param data table
function Session.deserialize(data)
    local sess = Session()

    -- Load current prestige/level
    sess.prestige = assert(data.prestige) + 0
    sess.playtime = (data.playtime or 0) + 0
    sess.idletime = (data.idletime or 0) + 0

    -- Load resources
    for _,resId in ipairs(g.RESOURCE_LIST) do
        sess.resources[resId] = tonumber(data.resources[resId]) or 0
        sess.resourceUnlocks[resId] = not not data.resourceUnlocks[resId]
    end

    -- Metrics
    for metric, v in pairs(data.metrics) do
        sess.metrics[metric] = assert(tonumber(v))
    end

    -- Stats
    for k,sta in pairs(g.VALID_STATS) do
        g.stats[k] = helper.assert(tonumber(data.stats[k] or sta.startingValue), "invalid stat value", k)
    end

    -- Upgrade trees
    if data.tree then
        sess.tree = Tree.deserialize(data.tree)
    end

    -- Tutorial messages
    if data.showTutorials then
        sess.showTutorials.start = tonumber(data.showTutorials.start) or -1
        sess.showTutorials.upgrades = nilIsTrue(data.showTutorials.upgrades)
    end

    -- World
    if data.world then
        ---@type table<integer, boolean>
        local persistenceLookup = {}
        if data.world.persistence then
            for _,z in ipairs(data.world.persistence) do
                persistenceLookup[z] = true
            end
        end

        -- Spawn objects
        ---@type table<integer, g.World.MachineData?>
        local machines = {}
        if data.world.items then
            for k,v in pairs(data.world.items) do
                ---@cast k string
                ---@cast v string
                if g.isValidMachine(v) then
                    local z = assert(tonumber(k))
                    local x, y = Z.decode(z)
                    machines[z] = sess.mainWorld:putItem(v, x, y, not persistenceLookup[z])
                else
                    log.warn("got invalid item '"..v.."'")
                end
            end
        end

        -- Connect
        if data.world.wires then
            for _, wz in ipairs(data.world.wires) do
                local dstz, srcz = Z.decode_positive(wz)

                if not g.connectWire(machines[dstz], machines[srcz]) then
                    log.warn("Could not connect wire at "..tostring(dstz).." -> "..tostring(srcz))
                end
            end
        end

        -- Connect power networks
        if data.world.powerNetworks then
            for _, machinesInPN in ipairs(data.world.powerNetworks) do
                ---@type g.World.PowerNetwork
                local powerNetwork = {
                    machines = objects.Set(),
                    totalLoad = 0,
                    totalPower = 0,
                }

                for _, z in ipairs(machinesInPN) do
                    local m = machines[z]
                    if not m then
                        log.warn("Could not find machine at "..tostring(z))
                    elseif m.powerGenerate or m.powerLoad then
                        m.powerNetwork = powerNetwork
                        powerNetwork.machines:add(m)
                    else
                        log.warn("Machine at "..tostring(z).." is not eligible for power network.")
                    end
                end
            end
        end
    end

    return sess
end

function Session:serialize()
    -- Save stats
    local stats = {}
    for k in pairs(g.VALID_STATS) do
        stats[k] = g.stats[k]
    end

    -- Save the world? Save the cat!
    -- Save items
    local items = {}
    ---@type integer[]
    local persistence = {}
    self.mainWorld.items:foreach(function(item, x, y)
        if item then
            local z = Z.encode(x, y)
            items[tostring(z)] = item.type
            if not item.removable then
                persistence[#persistence+1] = z
            end
        end
    end)

    -- Save data wires
    ---@type objects.Set<integer>
    local wires = objects.Set()
    for _, wireList in pairs(self.mainWorld.wireInput) do
        for _, wire in ipairs(wireList) do
            local srcz = Z.encode(wire.from.tileX, wire.from.tileY)
            local dstz = Z.encode(wire.to.tileX, wire.to.tileY)
            local uniquenum = Z.encode_positive(dstz, srcz)
            wires:add(uniquenum)
        end
    end
    local wiresDataInteger = wires:totable()
    table.sort(wiresDataInteger)

    -- Save power network sets.
    ---@type integer[][]
    local newPN = {}
    for _, pn in ipairs(self.mainWorld.powerNetworks) do
        local machines = {}
        for _, m in ipairs(pn.machines) do
            machines[#machines+1] = Z.encode(m.tileX, m.tileY)
        end
        table.sort(machines)
        newPN[#newPN+1] = machines
    end

    return {
        prestige = self.prestige,
        playtime = self.playtime,
        idletime = self.idletime,
        resources = self.resources,
        resourceUnlocks = self.resourceUnlocks,
        metrics = self.metrics,
        stats = stats,
        tree = self.tree:serialize(),
        showTutorials = helper.shallowCopy(self.showTutorials),
        world = {
            items = items,
            persistence = persistence,
            wires = wiresDataInteger,
            powerNetworks = newPN
        }
    }
end


return Session
