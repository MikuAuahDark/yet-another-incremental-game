
local reducers = require("src.modules.reducers")

g.defineEvent("draw")
g.defineEvent("update")
g.defineEvent("perSecondUpdate")

g.defineProperty("getPerformance") -- For server only. arguments: g.ServerInfo
g.defineProperty("getLoad") -- arguments: g.ItemInfo
g.defineProperty("getGeneratorLoad") -- arguments: g.PowerGenInfo
g.defineProperty("getDataThroughput") -- arguments: g.DataOutInfo
g.defineQuestion("isItemUnlocked", reducers.OR, false) -- arguments: string (item ID)
g.defineQuestion("getItemTotalInventory", reducers.ADD, 0) -- arguments: string (item ID)

g.defineQuestion("getUpgradePriceMultiplier", reducers.MULTIPLY, 1) -- arguments: g.UpgradeInfo, integer (level)
