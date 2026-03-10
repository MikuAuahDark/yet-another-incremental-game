-- Simple file containing list translation text
-- This is to ensure all translation text are in one place as possible.

return {
    HORIZONTAL_LIST_SEPARATOR = loc(", ", nil, {
        context = "A separator symbol used to denote item list in single horizontal text"}),
    CATEGORY_LIST = interp("Category: %{categories}", {
        context = "Denoting list of category, the ${categories} will be replaced with the actual list of items later"}),
    JOB_QUEUE_NUMBER = interp("Job Queue: %{njobs}/%{maxjobs}", {
        context = "Used in place to list job queue, with specific maximum amount of queueable jobs"}),
    CATEGORY_SERVER = loc("Servers", nil, {
        context = "Denotes the category of server buildings"}),
    CATEGORY_DATA = loc("Data Processors", nil, {
        context = "Denotes the category of data processor buildings"}),
    CATEGORY_BOOSTER = loc("Boosters", nil, {
        context = "Denotes the category of booster buildings used to boost server performance"}),
    CPS_NUMBER = interp("%{cps} {dns}/second", {
        context = "CPS (Compute Per Second) is a measurement how fast server can process computation. {dns} reflects \"Compute\" icon in-game."}),
    SERVER_HEAT_NUMBER = interp("%{heat}/%{max_heat} Heat", {
        context = "Denotes heat of a machine."}),
    OVERHEAT = loc("{emergency_heat} Overheat", nil, {
        context = "Denotes when a machine is overheating. `{emergency_heat}` will be replaced by symbol in-game."}),
    OVERHEAT_DESCRIPTION = loc("The server exceeded the heat tolerance it can handle, performance reduced!", nil, {
        context = "Denotes when a machine is overheating. will be replaced by symbol in-game."}),
}
