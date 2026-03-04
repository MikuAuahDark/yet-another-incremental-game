---@class _JobDefRNG
---@field package name string
---@field package category string
---@field package compute [integer,integer] -- min, max
---@field package data [integer,integer] -- min, max
---@field package money [integer,integer] -- min, max

---Define list of RNG jobs here
---@type _JobDefRNG[]
local JOB_DEF = {
    {
        name = "Web Hosting",
        category = "general",
        compute = {2,5},
        data = {2,5},
        money = {1,5},
    },
    {
        name = "Video Encoding",
        category = "video",
        compute = {50, 300},
        data = {10, 60},
        money = {20, 100},
    },
    {
        name = "LLM Inference",
        category = "ai",
        compute = {350, 5000},
        data = {100, 2000},
        money = {1000, 10000},
    }
}

local jobByCategory = {}
-- Localize names
for _, v in ipairs(JOB_DEF) do
    v.name = loc(v.name, nil, {context = "A compute job for computer or server to process"})

    jobByCategory[v.category] = jobByCategory[v.category] or {}
    table.insert(jobByCategory[v.category], v)
end

---@class g.JobGen
local jobgen = {}

---@param weights table<string, number> Key is job category, value is weight value.
---@param rng (fun():number)?
function jobgen.generate(weights, rng)
    ---@type [_JobDefRNG[], number][]
    local itemsAndWeights = {}
    for k, v in pairs(weights) do
        itemsAndWeights[#itemsAndWeights + 1] = {assert(jobByCategory[k]), v}
    end

    local rngForChoice = nil
    if rng then
        ---@param max integer
        function rngForChoice(max)
            return math.floor(rng() * max) + 1
        end
    end

    local categoryPicked = helper.pickWeighted(itemsAndWeights, rng)
    local def = helper.randomChoice(categoryPicked, rngForChoice)

    local rngFunc = rng or love.math.random
    local compute = math.floor(helper.lerp(def.compute[1], def.compute[2], rngFunc()) + 0.5)
    local data = math.floor(helper.lerp(def.data[1], def.data[2], rngFunc()) + 0.5)
    local money = math.floor(helper.lerp(def.money[1], def.money[2], rngFunc()) + 0.5)

    ---@type g.Job
    local job = {
        name = def.name,
        category = def.category,
        computePower = compute,
        outputData = data,
        resource = {money = money},
        timeout = 30
    }
    return job
end

return jobgen
