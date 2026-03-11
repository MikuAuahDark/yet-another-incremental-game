-- Simple file containing list translation text
-- This is to ensure all translation text are in one place as possible.

---@class TEXTLIST
local text = {
    HORIZONTAL_LIST_SEPARATOR = loc(", ", nil, {
        context = "A separator symbol used to denote item list in single horizontal text"}),

    JOB_QUEUE_NUMBER = interp("Job Queue: %{njobs}/%{maxjobs}", {
        context = "Used in place to list job queue, with specific maximum amount of queueable jobs"}),

    CATEGORY_LIST = interp("Category: %{categories}", {
        context = "Denoting list of category, the ${categories} will be replaced with the actual list of items later"}),
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
    DPS_NUMBER = interp("%{dps} {database}/second", {
        context = "DPS (Data Per Second) is a measurement how fast data processor can process data. {database} reflects \"Data\" icon in-game."}),
    WIRE_RANGE = interp("Wire Range: %{range} Tiles", {
        context = "Denotes the maximum range of data processor wire connection"}),
    WIRE_COUNT = interp("Connections: %{s}", {
        context = "Denotes the number of servers connected to this data processor. The %{s} will be replaced with `current_connections` or `current_connections/max_connections` later in-game."}),
    MAX_WIRE_COUNT = interp("Max Connections: %{s}", {
        context = "Denotes the maximum number of servers that can be connected to this data processor."}),
    EFFECTIVITY = interp("Effectivity: %{effectivity}", {
        context = "Denotes the effectivity of a booster. The %{effectivity} is percentage of the booster efficiency."}),
    HEAT_TOLERANCE = interp("Heat Tolerance: %{min_heat}-%{max_heat}", {
        context = "Denotes the heat tolerance range of a machine."}),
    LOAD = interp("Load: %{load}{bolt}", {
        context = "How many load this item uses?"}),
}
return text
