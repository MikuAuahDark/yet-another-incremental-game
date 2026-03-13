


local World = require("src.world.world")
local Tree = require("src.upgrades.Tree")
local Z = require("lib.zorder")


---@class g.Session.TutorialState
---@field harvest boolean
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
        harvest = true,
        upgrades = true
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
        sess.showTutorials.harvest = nilIsTrue(data.showTutorials.harvest)
        sess.showTutorials.upgrades = nilIsTrue(data.showTutorials.upgrades)
    end

    -- World
    if data.world then
        -- Spawn objects
        ---@type g.World.DataProcessorData[]
        local dp = {}
        if data.world.items then
            for k,v in pairs(data.world.items) do
                ---@cast k string
                ---@cast v string
                if g.isValidItem(v) then
                    local x, y = Z.decode(assert(tonumber(k)))
                    local itemData = sess.mainWorld:putItem(v, x, y)
                    local _, cat = g.getItemInfo(v)
                    if cat == "data" then
                        ---@cast itemData g.World.DataProcessorData
                        dp[#dp+1] = itemData
                    end
                else
                    log.warn("got invalid item '"..v.."'")
                end
            end
        end

        -- Connect data processors
        if data.world.connections then
            for _, dpData in ipairs(dp) do
                local key = tostring(Z.encode(dpData.tileX, dpData.tileY))
                local connections = data.world.connections[key]
                if connections then
                    for _, conn in ipairs(connections) do
                        local cx, cy = Z.decode(conn)
                        local itemData = sess.mainWorld.items:get(cx, cy)
                        local ok = false

                        if itemData then
                            local _, cat = g.getItemInfo(itemData.type)
                            if cat == "server" then
                                ---@cast itemData g.World.ServerData
                                if g.canConnectDataWire(itemData, dpData) then
                                    g.connectDataWire(itemData, dpData)
                                    ok = true
                                end
                            end
                        end

                        if not ok then
                            local f = string.format(
                                "invalid data processor connection '%s' (%d, %d) connect to (%d, %d)",
                                dpData.type,
                                dpData.tileX,
                                dpData.tileY,
                                cx, cy
                            )
                            log.warn(f)
                        end
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

    -- Save world
    ---@type g.World.DataProcessorData[]
    local dp = {}
    local items = {}
    local connections = {}
    ---@param item g.World.ItemData?
    self.mainWorld.items:foreach(function(item, x, y)
        if item then
            items[tostring(Z.encode(x, y))] = item.type
            local _, cat = g.getItemInfo(item.type)
            if cat == "data" then
                ---@cast item g.World.DataProcessorData
                dp[#dp+1] = item
            end
        end
    end)
    for _, dpData in ipairs(dp) do
        if #dpData.connectsServers > 0 then
            local coords = {}
            for _, serverData in ipairs(dpData.connectsServers) do
                coords[#coords+1] = Z.encode(serverData.tileX, serverData.tileY)
            end
            connections[tostring(Z.encode(dpData.tileX, dpData.tileY))] = coords
        end
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
            connections = connections,
        }
    }
end


return Session
