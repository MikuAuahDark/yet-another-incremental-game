
local reducers = require("src.modules.reducers")

g.defineEvent("draw")
g.defineEvent("update")
g.defineEvent("perSecondUpdate")

g.defineEvent("jobCompleted") -- args: g.World.ServerData, g.Job

g.defineQuestion("getWorldTileSizeModifier", reducers.ADD, 3)
g.defineQuestion("getMaxLoadModifier", reducers.ADD, 10)
g.defineQuestion("getMaxJobQueueModifier", reducers.ADD, 1)
g.defineQuestion("getPerformanceModifier", reducers.ADD, 0)
g.defineQuestion("getPerformanceMultiplier", reducers.MULTIPLY, 1)
g.defineQuestion("getLoadModifier", reducers.ADD, 0) -- arguments: g.ItemInfo
g.defineQuestion("getLoadMultiplier", reducers.MULTIPLY, 1) -- arguments: g.ItemInfo
g.defineQuestion("getDataThroughputModifier", reducers.ADD, 0)
g.defineQuestion("getDataThroughputMultiplier", reducers.MULTIPLY, 1)
g.defineQuestion("getJobFrequencyModifier", reducers.ADD, 0) -- arguments: g.JobCategory
g.defineQuestion("getJobFrequencyMultiplier", reducers.MULTIPLY, 1) -- arguments: g.JobCategory
g.defineQuestion("isItemUnlocked", reducers.OR, false) -- arguments: string (item ID)
