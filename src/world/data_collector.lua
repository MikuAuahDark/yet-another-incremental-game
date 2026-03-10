
---@class g.DataCollector: objects.Class
local DataCollector = objects.Class("g:DataCollector")

local table_new = require("table.new")

---@param duration integer
function DataCollector:init(duration)
    assert(duration > 0)
    self.total = 0 -- Note: This is MSOT with `sum(self.buffer[...][1])` for performance reasons.
    self.duration = duration
    ---@type [number,number][]
    self.buffer = {}
end

if false then
    ---@param duration integer
    ---@return g.DataCollector
    ---@diagnostic disable-next-line: cast-local-type, missing-return
    function DataCollector(duration) end
end

---@param dt number
---@param value number
function DataCollector:insert(dt, value)
    self.total = self.total + dt
    -- Remove old (to reduce strain on shifting with table.remove)
    while self.total > self.duration do
        local buf = table.remove(self.buffer, 1) --[=[@as [number,number]]=]
        self.total = self.total - buf[1]
    end
    self.buffer[#self.buffer+1] = {dt, value}
end

---@return number
function DataCollector:getAverage()
    local result = 0
    local durT = 0

    for _, v in ipairs(self.buffer) do
        durT = durT + v[1]
        result = result + v[2]
    end

    if durT == 0 then
        return 0
    end
    return result / durT
end

return DataCollector
