
----------------------
--- World Size Upgrade
----------------------

---@param uinfo g.UpgradeInfo
---@param level integer
local function getWorldSizeModifier(uinfo, level)
    return uinfo:getValues(level)
end

---@param nsize integer
local function defWZUpgrade(nsize)
    return g.defineUpgrade("world_size_"..nsize, "World Size +"..nsize, {
        kind = "MISC",
        description = "Increase world size by %{1} tiles in all directions.",
        image = "zoom_out_map",
        maxLevel = 3,
        getValues = helper.valueGetter(nsize, nsize),
        getWorldTileSizeModifier = getWorldSizeModifier
    })
end

for i = 1, 3 do
    defWZUpgrade(i)
end



----------------
-- Max Job Queue
----------------

g.defineUpgrade("max_job", "Job Queue+", {
    kind = "MISC",
    description = "Increase max job queue by %{1}.",
    image = "add_to_queue",
    maxLevel = 10,
    getValues = helper.valueGetter(1, 1),
    getMaxJobQueueModifier = getWorldSizeModifier
})

g.defineUpgrade("max_job_mul", "Job Queue++", {
    kind = "MISC",
    description = "Increase max job queue multiplier by %{1}.",
    image = "add_to_queue",
    maxLevel = 10,
    getValues = helper.percentageGetter(1, 2),
    getMaxJobQueueMultiplier = getWorldSizeModifier
})


-----------
-- Max Load
-----------

g.defineUpgrade("max_load", "Max Load+", {
    kind = "MISC",
    description = "Increase max load by %{1}.",
    image = "bolt",
    maxLevel = 10,
    getValues = helper.valueGetter(1, 1),
    getMaxLoadModifier = getWorldSizeModifier
})

g.defineUpgrade("max_load_mul", "Max Load++", {
    kind = "MISC",
    description = "Increase max load multiplier by %{1}.",
    image = "bolt",
    maxLevel = 10,
    getValues = helper.percentageGetter(1, 2),
    getMaxLoadMultiplier = getWorldSizeModifier
})
