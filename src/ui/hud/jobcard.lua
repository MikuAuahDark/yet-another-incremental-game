---@param job g.Job
local function getJobName(job)
    local ctype = job.category
    local ctypeup = ctype:upper()
    local symbol = "{TYPE_"..ctypeup.."}{"..g.getJobCategoryInfo(ctype).symbol.."}{/TYPE_"..ctypeup.."}"
    return symbol..job.name..symbol
end


---@class g.HUD.JobCard: objects.Class
local JobCard = objects.Class("g:HUD.JobCard")

---@param job g.Job
---@param progress number?
function JobCard:init(job, progress)
    self.job = job
    self.progress = progress
end

if false then
    ---@param job g.Job
    ---@param progress number?
    ---@return g.HUD.JobCard
    ---@diagnostic disable-next-line: cast-local-type, missing-return
    function JobCard(job, progress) end
end

---@param width number
function JobCard:getHeight(width)
    local titleF = g.getMainFont(16)
    local catF = g.getMainFont(10)
    local height = 0

    -- Title text
    local title = getJobName(self.job)
    local _, titleLines = richtext.getWrap(title, titleF, width - 8)
    height = height + titleLines * titleF:getHeight()

    -- Outputs
    height = height + catF:getHeight()

    -- If there's progress, then progress percentage and progress bar
    if self.progress then
        -- Progress percentage is 1 catF
        -- Progress bar is 1 catF too
        height = height + catF:getHeight() * 2
    end

    return height
end

---@param theme "dark"|"light"
---@param x number
---@param y number
---@param width number
function JobCard:render(theme, x, y, width)
    local titleF = g.getMainFont(16)
    local catF = g.getMainFont(10)
    local height = 0
    love.graphics.setColor(g.COLORS.UI.MAIN[theme].TEXT)

    -- Draw title text
    local title = getJobName(self.job)
    local _, titleLines = richtext.getWrap(title, titleF, width - 8)
    richtext.printRich(title, titleF, x, y + height, width, "center")
    height = height + titleLines * titleF:getHeight()

    -- Draw outputs
    local outR = Kirigami(x, y + height, width, catF:getHeight())
    local computeR, dataR, moneyR = outR:splitHorizontal(1, 1, 1)
    ui.printRichInRegion(g.formatNumber(self.job.computePower).."{dns}", catF, computeR, true, "left")
    ui.printRichInRegion(g.formatNumber(self.job.outputData).."{database}", catF, dataR, true, "center")
    -- We only have "money"
    -- FIXME: Change it if we have more than 1 resources
    ui.printRichInRegion("{money}"..g.formatNumber(self.job.resource.money), catF, moneyR, true, "right")
    height = height + catF:getHeight()

    -- Progress
    if self.progress then
        -- Progress percentage text
        love.graphics.printf(math.floor(self.progress * 100).."%", catF, x, y + height, width, "center")
        height = height + catF:getHeight()

        -- Progress bar
        local barR = Kirigami(x, y + height, width, catF:getHeight())
            :padUnit(0, 3)
        local barWidth = barR.w * self.progress
        love.graphics.rectangle("fill", barR.x, barR.y, barWidth, barR.h)
        height = height + catF:getHeight()
    end
end

return JobCard
