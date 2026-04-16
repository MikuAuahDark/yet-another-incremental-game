


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
        sess.showTutorials.harvest = nilIsTrue(data.showTutorials.harvest)
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
        if data.world.items then
            for k,v in pairs(data.world.items) do
                ---@cast k string
                ---@cast v string
                if g.isValidItem(v) then
                    local z = assert(tonumber(k))
                    local x, y = Z.decode(z)
                    sess.mainWorld:putItem(v, x, y, not persistenceLookup[z])
                else
                    log.warn("got invalid item '"..v.."'")
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
    local items = {}
    ---@type integer[]
    local persistence = {}
    ---@param item g.World.ItemData?
    self.mainWorld.items:foreach(function(item, x, y)
        if item then
            local z = Z.encode(x, y)
            items[tostring(z)] = item.type
            if not item.removable then
                persistence[#persistence+1] = z
            end
        end
    end)

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
            persistence = persistence
        }
    }
end


return Session
