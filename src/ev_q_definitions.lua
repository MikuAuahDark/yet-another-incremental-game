
local reducers = require("src.modules.reducers")

---@class g.BusCommon
---@field public update function?
---@field public drawBelow function?
---@field public draw function? For thing that has draws implicitly, this is drawAfter
---@field public perSecondUpdate function?

g.defineEvent("draw")
g.defineEvent("update")
g.defineEvent("perSecondUpdate")

g.defineQuestion("getWorldTileSize", reducers.ADD, 3)
