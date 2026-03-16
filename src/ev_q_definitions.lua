
local reducers = require("src.modules.reducers")

g.defineEvent("draw")
g.defineEvent("update")
g.defineEvent("perSecondUpdate")

g.defineEvent("jobCreated") -- args: g.Job
g.defineEvent("jobCompleted") -- args: g.World.ServerData, g.Job

g.defineProperty("getPerformance") -- For server only. arguments: g.ServerInfo
g.defineProperty("getLoad") -- arguments: g.ItemInfo
g.defineProperty("getDataThroughput") -- arguments: g.ItemInfo
g.defineQuestion("isItemUnlocked", reducers.OR, false) -- arguments: string (item ID)

g.defineProperty("getJobFrequency") -- arguements: string (job ID)
g.defineProperty("getJobOutputData") -- arguements: string (job ID)
g.defineProperty("getJobMoneyReward") -- arguements: string (job ID)
g.defineProperty("getJobComputePower") -- arguements: string (job ID)
g.defineProperty("getJobTimeout", 30) -- arguements: string (job ID)

g.defineQuestion("getUpgradePriceMultiplier", reducers.MULTIPLY, 1) -- arguments: g.UpgradeInfo, integer (level)
