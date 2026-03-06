-- Simple file containing list translation text
-- This is to ensure all translation text are in one place as possible.

return {
    HORIZONTAL_LIST_SEPARATOR = loc(", ", nil, {
        context = "A separator symbol used to denote item list in single horizontal text"}),
    CATEGORY_LIST = interp("Category: %{categories}", {
        context = "Denoting list of category, the ${categories} will be replaced with the actual list of items later"}),
}
