
---@class _JobDef3
---@field package image string
---@field package compute [integer,integer]|integer -- min, max
---@field package data [integer,integer]|integer -- min, max
---@field package money [integer,integer]|integer -- min, max

---@param id string
---@param name string
---@param category g.JobCategory
---@param def _JobDef3
local function defJob(id, name, category, def)
    -- Define job
    g.defineJob(id, name, category, {
        compute = def.compute,
        data = def.data,
        money = def.money,
    })
    -- Define upgrades
    -- Job Frequency Modifier
    g.defineUpgrade(id, name, {
        description = "Increases spawn rate of "..name.." compute job by %{1} seconds.",
        descriptionContext = "A compute job for computer or server to process",
        kind = "JOB",
        image = def.image,
        getValues = helper.valueGetter(0.05),
        valueFormatter = {"+%.14g"},
        ---@param uinfo g.UpgradeInfo
        ---@param level integer
        ---@param jobid string
        getJobFrequencyModifier = function(uinfo, level, jobid)
            if jobid == id then
                return (uinfo:getValues(level))
            end
            return 0
        end,
    })
    -- Job Frequency Multiplier
    g.defineUpgrade(id.."_mul", "Faster "..name.." Spawn", {
        description = "Increases spawn rate of "..name.." compute job by %{1}.",
        descriptionContext = "A compute job for computer or server to process",
        kind = "JOB",
        image = def.image,
        getValues = helper.valueGetter(0.05, 1),
        valueFormatter = {function(v) return string.format("%.14g%%", v * 100) end},
        ---@param uinfo g.UpgradeInfo
        ---@param level integer
        ---@param jobid string
        getJobFrequencyMultiplier = function(uinfo, level, jobid)
            if jobid == id then
                return (uinfo:getValues(level))
            end
            return 1
        end,
        drawUI = helper.genDrawUIIntuition("timer_arrow_down", "theme", g.COLORS.UI.BUFF),
    })
    -- Job Frequency Reward
    g.defineUpgrade(id.."_money", "Expensive "..name, {
        description = "Increases money yield from "..name.." compute job by %{1}.",
        descriptionContext = "A compute job for computer or server to process",
        kind = "JOB",
        image = def.image,
        getValues = helper.valueGetter(0.05, 1),
        valueFormatter = {function(v) return string.format("%.14g%%", v * 100) end},
        ---@param uinfo g.UpgradeInfo
        ---@param level integer
        ---@param job g.Job
        jobCreated = function(uinfo, level, job)
            if job.type == id then
                local m = assert(job.resource.money)
                job.resource.money = helper.round(m * (1 + uinfo:getValues(level)))
            end
        end,
        drawUI = helper.genDrawUIIntuition("attach_money", "theme", g.COLORS.MONEY),
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
defJob("cdn", "Content Delivery Network", "general", {
    image = "host",
    compute = {2,5},
    data = {20,50},
    money = {3,5},
})
defJob("image_processing", "Image Processing", "general", {
    image = "blur_on",
    compute = {8,20},
    data = {3,6},
    money = {3,8},
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
defJob("physics_simulation", "Physics Simulation", "ai", {
    image = "draw_abstract",
    compute = {5000, 7000},
    data = 3500,
    money = {12000, 50000},
})
defJob("research_model", "Research Model", "ai", {
    image = "batch_prediction",
    compute = {3500, 5000},
    data = {1000, 5000},
    money = {10000, 50000},
})
defJob("llm", "LLM", "ai", {
    image = "article_shortcut",
    compute = {10000, 500000},
    data = {45000, 60000},
    money = {80000, 950000},
})
