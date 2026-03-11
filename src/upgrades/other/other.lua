
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
