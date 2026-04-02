local FreeCameraScene = require("src.scenes.FreeCameraScene")

---@class TitleScene: FreeCameraScene
local TitleScene = FreeCameraScene()

function TitleScene:init()
    self.allowMousePan = false
end

function TitleScene:update(dt)
end

local BUTTON_COLORS = {
    CONTINUE = objects.Color("FFDC8929"),
    NEW_GAME = objects.Color("FF6ED25C"),
    SETTINGS = objects.Color("FF4A4A4A"),
    QUIT = objects.Color("FF4A4A4A"),
}

function TitleScene:draw()
    love.graphics.clear(objects.Color("#b0b0b0"))
    ui.startUI()

    local r = ui.getFullScreenRegion()
    local f = g.getThickFont(18)
    local topR, bottomR = r:splitVertical(4, 5)
    local logoR = topR:padRatio(0.25)
        :shrinkToAspectRatio(9, 5)
        :center(topR)
    local buttonsR = bottomR:padRatio(0.1)
        :set(nil, nil, 172, (f:getHeight() + ui.TOOLTIP_OUTLINE_WIDTH * 2 + 4) * 4)
        :center(bottomR)
    local buttons = buttonsR:grid(1, 4)
    local hasSaved = g.hasSavedSession()

    ------------
    -- Draw logo
    ------------
    ui.debugRegion(logoR, "fill")
    love.graphics.setColor(0, 0, 0)
    ui.printRichInRegion("TODO: Make A DATACENTER Logo here", f, logoR:padRatio(0.1), true, "center", "center")
    love.graphics.setColor(1, 1, 1)

    ---------------
    -- Draw buttons
    ---------------
    if hasSaved then
        -- Draw continue
        local continueButtonR = buttons[1]:padUnit(4, 4)
        if ui.Button2("{wavy}{o thickness=0.75}"..TEXT.MENU_CONTINUE.."{/o}{/wavy}", f, BUTTON_COLORS.CONTINUE, continueButtonR) then
            g.loadSession()
            g.gotoScene("main_scene")
        end
    end

    -- Draw new game
    local newGameButtonR = buttons[2]:padUnit(4, 4)
    local newGameText = "{o thickness=0.75}"..TEXT.MENU_NEW_GAME.."{/o}"
    if not hasSaved then
        newGameText = "{wavy}"..newGameText.."{/wavy}"
    end
    if ui.Button2(newGameText, f, BUTTON_COLORS.NEW_GAME, newGameButtonR) then
        g.newSession().tree = g.loadTree("mvp")
        g.gotoScene("main_scene")
    end

    -- Draw settings
    local settingsButtonR = buttons[3]:padUnit(4, 4)
    if ui.Button2("{o thickness=0.75}"..TEXT.MENU_SETTINGS.."{/o}", f, BUTTON_COLORS.SETTINGS, settingsButtonR) then
        g.gotoScene("setting_scene")
    end

    -- Draw quit
    local quitButtonR = buttons[4]:padUnit(4, 4)
    if ui.Button2("{o thickness=0.75}"..TEXT.MENU_QUIT_GAME.."{/o}", f, BUTTON_COLORS.QUIT, quitButtonR) then
        love.event.quit()
    end

    ui.debugRegion(topR)
    ui.debugRegion(bottomR)

    ui.endUI()
end

return TitleScene
