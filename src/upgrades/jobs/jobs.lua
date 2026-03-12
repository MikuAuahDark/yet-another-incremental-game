---@param t [integer,integer]|integer
local function genRollFunc(t)
    if type(t) == "number" then
        return function() return t end
    else
        return function()
            return helper.round(helper.lerp(t[1], t[2], love.math.random()))
        end
    end
end

---@class _JobDef
---@field package image string
---@field package compute [integer,integer]|integer -- min, max
---@field package data [integer,integer]|integer -- min, max
---@field package money [integer,integer]|integer -- min, max

---@param id string
---@param name string
---@param category g.JobCategory
---@param def _JobDef
local function defJob(id, name, category, def)
    local rollCompute = genRollFunc(def.compute)
    local rollData = genRollFunc(def.data)
    local rollMoney = genRollFunc(def.money)
    local catname = g.getJobCategoryName(category, true)

    g.defineUpgrade(id, name, {
        description = "Increase "..name.." compute job chance to show by %{1}.",
        descriptionContext = "A compute job for computer or server to process",
        kind = "JOB",
        maxLevel = 1,
        image = def.image,
        getValues = function(uinfo, level)
            return level
        end,
        ---@param uinfo g.UpgradeInfo
        ---@param level integer
        ---@param jobs g.Job[]
        ["populate"..catname.."JobCandidates"] = function(uinfo, level, jobs)
            for _ = 1, level do
                ---@type g.Job
                local job = {
                    name = uinfo.name,
                    category = category,
                    computePower = rollCompute(),
                    outputData = rollData(),
                    resource = {money = rollMoney()},
                    timeout = 30,
                }
                jobs[#jobs+1] = job
            end
        end,
    })
end



----------
-- General
----------
defJob("webhost", "Web Hosting", "general", {
    image = "language",
    compute = {2,5},
    data = {2,5},
    money = {1,5},
})
defJob("image_processing", "Image Processing", "general", {
    image = "blur_on",
    compute = {3,11},
    data = {3,6},
    money = {2,6},
})

--------
-- Video
--------
defJob("video_encode", "Video Encode", "video", {
    image = "movie_edit",
    compute = 160,
    data = {30, 60},
    money = {45, 100}
})
defJob("livestream", "Livestream", "video", {
    image = "camera_video",
    compute = {70, 500},
    data = {30, 100},
    money = {40, 150},
})

-------------
-- AI :skull:
-------------
---@class _JobDef2
---@field package name string
---@field package compute [integer,integer]|integer -- min, max
---@field package data [integer,integer]|integer -- min, max
---@field package money [integer,integer]|integer -- min, max

---@param id string
---@param name string
---@param category g.JobCategory
---@param image string
---@param def _JobDef2[]
local function defAIJob(id, name, category, image, def)
    ---@type {rc:(fun():integer),rd:(fun():integer),rm:(fun():integer),name:string}[]
    local internalJobDef = {}
    local catname = g.getJobCategoryName(category, true)

    for _, v in ipairs(def) do
        internalJobDef[#internalJobDef+1] = {
            rc = genRollFunc(v.compute),
            rd = genRollFunc(v.data),
            rm = genRollFunc(v.money),
            name = loc(v.name, nil, {context = "A compute job for computer or server to process"})
        }
    end

    g.defineUpgrade(id, name, {
        description = "Increase "..name.." compute job chance to show by %{1}.",
        descriptionContext = "A compute job for computer or server to process",
        kind = "JOB",
        maxLevel = 1,
        image = image,
        getValues = function(uinfo, level)
            return level
        end,
        ---@param uinfo g.UpgradeInfo
        ---@param level integer
        ---@param jobs g.Job[]
        ["populate"..catname.."JobCandidates"] = function(uinfo, level, jobs)
            for _ = 1, level do
                for _, v in ipairs(internalJobDef) do
                    ---@type g.Job
                    local job = {
                        name = uinfo.name,
                        category = category,
                        computePower = v.rc(),
                        outputData = v.rd(),
                        resource = {money = v.rm()},
                        timeout = 30,
                    }
                    jobs[#jobs+1] = job
                end
            end
        end,
    })
end

defAIJob("research_model", "Research Model", "ai", "batch_prediction", {
    {
        name = "Research Model Training",
        compute = {3500, 5000},
        data = {1000, 5000},
        money = {10000, 50000},
    },
    {
        name = "Research Model Inference",
        compute = {200, 300},
        data = {100, 500},
        money = {500, 1000},
    },
})
defAIJob("llm", "LLM", "ai", "article_shortcut", {
    {
        name = "LLM Training",
        compute = {10000, 500000},
        data = {45000, 60000},
        money = {80000, 950000},
    },
    {
        name = "LLM Inference",
        compute = {2500, 10000},
        data = {4500, 6000},
        money = {7000, 50000},
    },
})
defJob("physics_simulation", "Physics Simulation", "ai", {
    image = "draw_abstract",
    compute = {5000, 7000},
    data = 3500,
    money = {12000, 50000},
})
