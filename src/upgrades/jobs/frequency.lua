
---@param uinfo g.UpgradeInfo
---@param level integer
local function getJobFrequency(uinfo, level)
    return uinfo:getValues(level)
end

---@param cat g.JobCategory
---@param startval number
---@param incr number
---@param maxLevel integer?
---@param suffix string?
local function defJobFreqMod(cat, img, startval, incr, maxLevel, suffix)
    local catname = g.getJobCategoryName(cat, true)
    local stat = assert(g.VALID_STATS[catname.."JobFrequency"])
    return g.defineUpgrade(cat.."_mod"..(suffix or ""), "Faster "..catname.." Job Spawn", {
        kind = "JOB",
        description = "Increase "..catname.." job spawn rate by %{1}/second.",
        image = img,
        maxLevel = maxLevel,
        getValues = helper.valueGetter(startval, incr),
        [stat.addQuestion] = getJobFrequency,
    })
end

---@param v number
local function percentageFormatter(v)
    return tostring(helper.round(v * 100, 2))
end
---@param uinfo g.UpgradeInfo
---@param level integer
local function getJobFreqMul(uinfo, level)
    return 1 + uinfo:getValues(level)
end

---@param cat g.JobCategory
---@param startval integer
---@param incr integer
---@param maxLevel integer?
---@param suffix string?
local function defJobFreqMul(cat, img, startval, incr, maxLevel, suffix)
    local catname = g.getJobCategoryName(cat, true)
    local stat = assert(g.VALID_STATS[catname.."JobFrequency"])
    return g.defineUpgrade(cat.."_mul"..(suffix or ""), "Faster "..catname.." Job Spawn", {
        kind = "JOB",
        description = "Increase "..catname.." job spawn frequency multiplier by %{1}%.",
        image = img,
        maxLevel = maxLevel,
        getValues = helper.percentageGetter(startval, incr),
        valueFormatter = {percentageFormatter},
        [stat.multQuestion] = getJobFreqMul,
    })
end

defJobFreqMod("general", "docs", 0.1, 0.1, 4)
defJobFreqMod("video", "movie", 0.1, 0.1, 5)
defJobFreqMod("ai", "network_intelligence", 0.1, 0.1, 5)

defJobFreqMul("general", "docs", 1, 1, 5)
defJobFreqMul("video", "movie", 1, 1, 5)
defJobFreqMul("ai", "network_intelligence", 1, 1, 5)
