-- The shape has size of 1x1 at the center.
local PLAYER_SHIP = love.graphics.newMesh({
    {0, -0.5, 0.5, 0},
    {0.5, 0.5, 1, 1},
    {0, 0.25, 0.5, 0.75},
    {-0.5, 0.5, 0, 1},
}, "fan", "static")

---@class PlayerShipEntity: g.Entity
local PlayerShipEntity = {}

function PlayerShipEntity:init(x, y)
end

function PlayerShipEntity:draw()
    love.graphics.setColor(g.COLORS.PLAYER_SPACESHIP)
    love.graphics.draw(PLAYER_SHIP, self.x, self.y, 0, 32, 32)
end

g.defineEntity("player_spaceship", PlayerShipEntity)
