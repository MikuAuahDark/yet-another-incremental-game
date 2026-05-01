-- Simple file containing list translation text
-- This is to ensure all translation text are in one place as possible.

-- If you need to apply effect to whole text, don't apply it here.
-- Apply it in the code that uses such text instead!

---@class TEXTLIST
local text = {
    JOB_QUEUE_INFO = loc("Tasks", nil, {
        context = "Used in place to list available task categories"}),
    MONEY = loc("Money", nil, {
        context = "A resource"}),
    MONEY_DESCRIPTION = loc("Use the money to buy servers, data output, boosters, and unlock upgrades.", nil, {
        context = "A description on what \"Money\" (a resource in-game) is usable for."}),
    CPS = loc("Compute Per Second", nil, {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation."}),
    CPS_DESCRIPTION = loc("This is how fast all your servers perform computation for its job. The win condition is to reach {b}1 million{/b} CPS.", nil, {
        context = "A description on what \"CPS\" (Compute Per Second) is for."}),

    CATEGORY_LIST = interp("Category: %{categories}", {
        context = "Denoting list of category, the ${categories} will be replaced with the actual list of items later"}),
    CATEGORY_SERVER = loc("Servers", nil, {
        context = "Denotes the category of server buildings"}),
    CATEGORY_DATA = loc("Data I/O", nil, {
        context = "Denotes the category of data input or data output buildings"}),
    CATEGORY_BOOSTER = loc("Boosters", nil, {
        context = "Denotes the category of booster buildings used to boost server performance"}),
    CATEGORY_POWER = loc("Power", nil, {
        context = "Denotes the category of power buildings used to provide power to other buildings"}),

    CPS_NUMBER = interp("%{cps} {dns}/second", {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation. {dns} reflects \"Compute\" icon in-game."}),
    SERVER_HEAT_NUMBER = interp("%{heat}/%{max_heat} Heat", {
        context = "Denotes heat of a machine."}),
    DPS_NUMBER = interp("%{dps} {database}/second", {
        context = "DPS (Data Per Second) is a measurement how fast data output can process data. {database} reflects \"Data\" icon in-game."}),
    WIRE_DPS = interp("Wire {COLORS_UI_TEXT_DPS}%{dps} {database}/second{/COLORS_UI_TEXT_DPS}", {
        context = "Denotes the speed of data transfer."}),
    WIRE_COUNT = interp("Connections: %{count}/%{max}", {
        context = "Denotes the (max) number of connections that can be handled by this machine/item."}),
    EFFECTIVITY = interp("Effectivity: %{effectivity}%", {
        context = "Denotes the effectivity of a booster. The %{effectivity} is percentage of the booster efficiency."}),
    HEAT_TOLERANCE = interp("Heat Tolerance: %{min_heat}-%{max_heat}", {
        context = "Denotes the heat tolerance range of a machine."}),
    LOAD_TOOLTIP = interp("Load: {COLORS_UI_TEXT_POWER_RELATED}%{load}{bolt}{/COLORS_UI_TEXT_POWER_RELATED}", {
        context = "How many load this item uses?"}),
    PROVIDE_LOAD_TOOLTIP = interp("Generates: {COLORS_UI_TEXT_POWER_RELATED}%{load}{bolt}{/COLORS_UI_TEXT_POWER_RELATED}", {
        context = "How many load this item generates/provides?"}),
    TOTAL_LOAD_TOOLTIP = interp("Power Network: %{s}", {
        context = "How many load is used and power available across the whole power network? %{s} will be replaced by `load/total`."}),
    LEVEL_TOOLTIP = interp("Level: %{level}", {
        context = "Denotes the level of an upgrade."}),
    JOB_FREQUENCY_MODIFIER = interp("+%{modifier}s %{jobtype} tasks.", {
        context = "Denotes the job frequency modifier of a data input."}),
    JOB_FREQUENCY_MULTIPLIER = interp("%{multiplier}% %{jobtype} tasks.", {
        context = "Denotes the job frequency multiplier of a data input."}),

    MENU_CONTINUE = loc("Continue", nil, {
        context = "A button to continue the game from title screen"}),
    MENU_NEW_GAME = loc("New Game", nil, {
        context = "A button to start a new game from title screen"}),
    MENU_SETTINGS = loc("Settings", nil, {
        context = "A button to open game settings, either from title screen or from pause menu"}),
    MENU_QUIT_GAME = loc("Quit", nil, {
        context = "A button to quit/exit the game"}),

    SETTING_TITLE = loc("Settings", nil, {
        context = "Title of the settings screen"}),
    SETTING_GENERAL = loc("General", nil, {
        context = "Category of settings"}),
    SETTING_AUDIO = loc("Audio", nil, {
        context = "Category of settings"}),

    TUTORIAL_SKIP = loc("Skip", nil, {
        context = "A button to skip the current tutorial step"}),
    TUTORIAL_SKIP_ALL = loc("Skip Tutorial", nil, {
        context = "A button to skip the tutorial entirely"}),
    TUTORIAL_NEXT = loc("Next", nil, {
        context = "A button to advance to the next step in the tutorial"}),
    TUTORIAL_FINISH = loc("Finish", nil, {
        context = "A button that finishes the tutorial"}),
    -- FIXME: My English for this tutorial
    TUTORIAL_0_1 = loc("TUTORIAL:", nil, {
        context = "Tutorial on the basic controls."}),
    TUTORIAL_0_2 = loc("Mouse wheel to zoom in/out.", nil, {
        context = "Tutorial on the basic controls."}),
    TUTORIAL_0_3 = loc("Click and drag your mouse to move around.", nil, {
        context = "Tutorial on the basic controls."}),
    TUTORIAL_0_4 = interp("Hovering your mouse gives you more information. Try it on the %{main_power} in the center.", {
        context = "Tutorial on the basic controls."}),
    TUTORIAL_1_1 = loc("Start by placing a server;", nil, {
        context = "Tutorial on placing server"}),
    TUTORIAL_1_2 = interp("Click the {c r=0.8 g=0.8 b=1}%{server}{/c} on the bottom and click anywhere to place it.", {
        context = "Tutorial on placing server"}),
    TUTORIAL_2_1 = loc("Now, place a {c r=0.8 g=0.8 b=1}Data-Input{/c}: servers must be connected to perform tasks.", nil, {
        context = "Tutorial on placing data inputs"}),
    TUTORIAL_2_2 = interp("(Press the {c r=0.8 g=0.8 b=1}\"%{CATEGORY_DATA}\"{/c} to show available)", {
        context = "Tutorial on placing data inputs"}),
    TUTORIAL_2_3 = interp("Click the {c r=0.8 g=0.8 b=1}%{di}{/c} on the bottom and click near the server on the world to place it.", {
        context = "Tutorial on placing data inputs"}),
    TUTORIAL_3_1 = loc("Now, place a {c r=0.8 g=0.8 b=1}Data-Output{/c}. This is where server sends data after it's done processing.", nil, {
        context = "Tutorial on placing data outputs"}),
    TUTORIAL_3_2 = interp("Click the {c r=0.8 g=0.8 b=1}%{do}{/c} on the bottom and place it near the world.", {
        context = "Tutorial on placing data outputs"}),
    TUTORIAL_4_1 = loc("You should now see data flowing from the {c r=0.8 g=0.8 b=1}Data-Input{/c}, to the {c r=0.8 g=0.8 b=1}Server{/c}, and then to the {c r=0.8 g=0.8 b=1}Data-Output{/c}! (If not, you probably placed them too far away.)", nil, {
        context = "Tutorial on verifying pipeline"}),
    TUTORIAL_4_2 = loc("yellow or red indicator above the items means something's wrong. Hover to see more information.", nil, {
        context = "Tutorial on verifying pipeline"}),
    TUTORIAL_5_1 = loc("Remove buildings by using the {c r=1 g=0 b=0}Delete{/c} tool on bottom right.", nil, {
        context = "Tutorial on removing buildings"}),
    TUTORIAL_5_2 = loc("To remove a building, click on it. Once removed, it'll be put into your inventory.", nil, {
        context = "Tutorial on removing buildings"}),
    TUTORIAL_6_0 = loc("Now let's head to the tech tree!", nil, {
        context = "Tutorial on the tech tree."}),
    TUTORIAL_6_1 = loc("Tech tree has permanent upgrades, and it's also where you buy new Servers/Machines.", nil, {
        context = "Tutorial on the tech tree."}),
    TUTORIAL_6_2 = loc("Click and drag mouse to look around."),
    -- TUTORIAL_7_1 = TUTORIAL_6_1
    TUTORIAL_7_2 = interp("For now, let's get another {COLORS_JOBS_GENERAL}%{bs}{/COLORS_JOBS_GENERAL}, {COLORS_JOBS_GENERAL}%{di}{/COLORS_JOBS_GENERAL}, and {COLORS_JOBS_GENERAL}%{do}{/COLORS_JOBS_GENERAL}. You may need to wait until you have enough {money} money to buy them.", {
        context = "Tutorial on the tech tree."}),
    TUTORIAL_8_1 = loc("You can also buy other sorts of upgrades in here, unlocking the tech tree.", nil, {
        context = "Tutorial on the tech tree."}),
    TUTORIAL_8_2 = loc("You can hover your cursor to the upgrades to view more information about it.", nil, {
        context = "Tutorial on the tech tree."}),
    TUTORIAL_9_0 = loc("Now let's get back to the area!", nil, {
        context = "Tutorial on the other mechanics."}),
    TUTORIAL_9_1 = loc("Servers and data inputs can only connect within their same colored types or icons, or task types.", nil, {
        context = "Tutorial on task types."}),
    TUTORIAL_9_2 = loc("{COLORS_JOBS_GENERAL}Yellow {change_history_fill_20dp}{/COLORS_JOBS_GENERAL} - General Tasks", nil, {
        context = "Tutorial on task types."}),
    TUTORIAL_9_3 = loc("{COLORS_JOBS_VIDEO}Blue {crop_square_fill_20dp}{/COLORS_JOBS_VIDEO} - Video Tasks", nil, {
        context = "Tutorial on task types."}),
    TUTORIAL_9_4 = loc("{COLORS_JOBS_AI}Red {circle_fill_20dp}{/COLORS_JOBS_AI} - AI Tasks", nil, {
        context = "Tutorial on task types."}),
}
text.TUTORIAL_7_1 = text.TUTORIAL_6_1
return text
