
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



-----------
-- Max Load
-----------


g.defineUpgrade("max_load_mul", "Max Load+", {
    kind = "MISC",
    description = "Increase power multiplier of generators to %{1}.",
    image = "bolt",
    maxLevel = 10,
    getValues = helper.valueGetter(5, 110),
    valueFormatter = helper.PERCENTAGE_FORMATTER,
    ---@param uinfo g.UpgradeInfo
    ---@param level integer
    ---@param itemdata g.World.PowerData
    getGeneratorLoadMultiplier = function(uinfo, level, itemdata)
        local itemInfo, cat = g.getItemInfo(itemdata.type)
        if cat == "powergen" and not itemInfo.tags:has("datacenter_power") then
            return uinfo:getValues(level) / 100
        end

        return 1
    end
})


g.defineUpgrade("datacenter_load_mul", "Datacenter Load+", {
    kind = "MISC",
    description = "Increase power multiplier of datacenter power to %{1}.",
    image = "energy",
    maxLevel = 10,
    getValues = helper.valueGetter(5, 105),
    valueFormatter = helper.PERCENTAGE_FORMATTER,
    ---@param uinfo g.UpgradeInfo
    ---@param level integer
    ---@param itemdata g.World.PowerData
    getGeneratorLoadMultiplier = function(uinfo, level, itemdata)
        local itemInfo, cat = g.getItemInfo(itemdata.type)
        if cat == "powergen" and itemInfo.tags:has("datacenter_power") then
            return uinfo:getValues(level) / 100
        end

        return 1
    end,
    drawUI = helper.genDrawUIIntuition("bolt", "theme", "theme")
})

---------------
-- Max Money --
---------------

g.defineUpgrade("money_limit", "Money Limit", {
    kind = "MISC",
    description = "Increase money limit.",
    image = "attach_money",
    maxLevel = 10,
    getValues = function(uinfo, level)
        return 10 ^ level
    end,
    getMoneyLimitMultiplier = function(uinfo, level)
        return uinfo:getValues(level)
    end
})
