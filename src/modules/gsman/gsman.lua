-- Graphics state maanger

local love = require("love")

local gsman = {}

---@class gsman.LineWidth: objects.Class
local LineWidth = objects.Class("gsman.LineWidth")

---@param lw number
function LineWidth:init(lw)
    self.lw = love.graphics.getLineWidth()
    love.graphics.setLineWidth(lw)
end

function LineWidth:pop()
    love.graphics.setLineWidth(self.lw)
end

---@param lw number
---@return gsman.LineWidth
function gsman.setLineWidth(lw)
    return LineWidth(lw)
end

return gsman
