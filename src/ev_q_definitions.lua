
local reducers = require("src.modules.reducers")

g.defineEvent("draw")
g.defineEvent("update")
g.defineEvent("perSecondUpdate")

g.defineEvent("jobCompleted") -- args: g.World.ServerData, g.Job

g.defineQuestion("getMaxJobQueueModifier", reducers.ADD, 1)
g.defineQuestion("getPerformanceModifier", reducers.ADD, 0) -- For server only. arguments: g.ServerInfo
g.defineQuestion("getPerformanceMultiplier", reducers.MULTIPLY, 1) -- For server only. arguments: g.ServerInfo
g.defineQuestion("getLoadModifier", reducers.ADD, 0) -- arguments: g.ItemInfo
g.defineQuestion("getLoadMultiplier", reducers.MULTIPLY, 1) -- arguments: g.ItemInfo
g.defineQuestion("getDataThroughputModifier", reducers.ADD, 0)
g.defineQuestion("getDataThroughputMultiplier", reducers.MULTIPLY, 1)
g.defineQuestion("isItemUnlocked", reducers.OR, false) -- arguments: string (item ID)
