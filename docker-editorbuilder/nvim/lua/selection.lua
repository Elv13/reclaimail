-- Helper function to select language specific constructs.
local sugar = require("sugar")

local module = {}

local CONSTRUCT_PATTERN = "[\t ():;%[%]{},]"

--- Select stuff between spaces or other "section" delimiters.
function module.select_current_construct()
    if sugar.session.mode ~= "v" then
        vim.api.nvim_command(":normal! v")
    end

    local line = sugar.session.current_window.current_line
    local prefix = sugar.session.mode == "v" and "" or "v"

    local col = sugar.session.current_window.cursor.column

    local before = line:sub(1, col)
    local after  = line:sub(col, #line)

    local pos1 = #before - (before:reverse():find(CONSTRUCT_PATTERN) or (#before + 1)) + 1
    local pos2 = (after:find(CONSTRUCT_PATTERN) or (#after + 1)) - 2

    vim.api.nvim_input((pos1 - col).."ho"..(pos2).."l")
end

--- Like i[, but for commas.
function module.select_comma_block()
    -- [,[^=<>!~]*=()]

end

return module
