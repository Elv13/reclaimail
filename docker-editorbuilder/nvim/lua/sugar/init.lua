-- Syntax sugar to make the nvim API feel like real Lua.

local nobject = require("sugar.nobject")

local module  = require("sugar._base")
local session = require("sugar.session")
local window  = require("sugar.window")
local buffer  = require("sugar.buffer")

local global_signals = {}

module.session = session.get_session()
module.window  = window
module.buffer  = buffer

--- Run a function in the next event loop iteration.
-- @tparam function fct A function (takes no parameters).
-- @function sugar.schedule.delayed

--- Clear the promptbar.
function module.display.clear_prompt()
    module.schedule.delayed(function()
        vim.api.nvim_command('echomsg ""')
    end)
end

local function pad_message(message, win)
    local w = (win or module.session.current_window).width

    if w < #message then return message end

    local count, ret = math.floor((w-#message)/2), {}

    for i=1, count do
        table.insert(ret, " ")
    end

    return table.concat(ret) .. message
end

--- Display a prompt warning for some time.
function module.display.warning(message, timeout)
    module.schedule.delayed(function()
        vim.api.nvim_command('echomsg ""')
        vim.api.nvim_err_writeln(pad_message(message))

        if timeout then
            local timer = vim.loop.new_timer()
                timer:start(timeout, 0, vim.schedule_wrap(function()
                    vim.api.nvim_command('echomsg ""')
                end)
            )
        end
    end)
end

-- Get a string from the command prompt.
function module.input.prompt(message)
    return vim.api.nvim_call_function("input", {message})
end

-- Listen to changes and emit signals.
local global_counter, autocmd = 1, {}

local function get_command(name)
-- Convert to CamelCase.
    local words, cur_word = {}, ""

    for i = 1, #name do
        local c = name:sub(i,i)

        if c == "_" then
            table.insert(words, cur_word)
            cur_word = ""
        else
            cur_word = cur_word..(cur_word == "" and c:upper() or c)
        end
    end

    table.insert(words, cur_word)

    return table.concat(words)
end

--- Connect to an autocmd signal.
-- @tparam string name The autocmd name.
-- @tparam function callback The function to call.
function module.connect_signal(name, callback)
    local command = get_command(name)

    -- Create one global Lua function per autocmd.
    if not autocmd[command] then
        autocmd[command] = {}

        local gname = "autocmd_callbacks_"..global_counter

        _G[gname] = function()
            for _, cb in ipairs(autocmd[command]) do
                cb()
            end
        end

        local success = pcall(module.commands.autocmd, command, "*", "lua", gname, "()")

        -- Allow the config itself to have global signals.
        if not success then
            global_signals[name] = global_signals[name] or {}
            table.insert(global_signals[name], callback)
        end

        global_counter = global_counter + 1
    end

    table.insert(autocmd[command], callback)
end

function module.emit_signal(name, ...)
    local command = get_command(name)

    for _, cb in ipairs(autocmd[command] or global_signals[name]) do
        cb(...)
    end
end

return setmetatable(module, {
    __index = function(_, key)
        return vim.api.nvim_get_var(key)
    end,
    __newindex = function(_, key, value)
        vim.api.nvim_set_var(key, value)
    end
})
