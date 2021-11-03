local module = {
    schedule = {},
    display  = {},
    input    = {}
}

-- Proxy vimscript functions as Lua functions.
module.global_functions = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            return vim.api.nvim_call_function(k, {...})
        end
    end
})

-- Concatenate function name and arguments into a string
-- and execute it.
module.commands = setmetatable({}, {
    __index = function(_, k)
        return function(...)
            vim.api.nvim_command(k.." "..table.concat({...}, " "))
        end
    end
})

-- Execute normal mode key sequences without the remap.
function module.normal(text)
    module.commands["normal!"](text)
end

function module.schedule.delayed(fct)
    local timer = vim.loop.new_timer()
    timer:start(0, 0, vim.schedule_wrap(fct))
end

return module
