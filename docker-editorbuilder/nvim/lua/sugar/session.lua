local nobject = require("sugar.nobject")
local window_class = require("sugar.window")
local buffer = require("sugar.buffer")

local session_class, singleton = {}, nil

local function get_buf(buf)
    if buffer._buffers[buf] then return buffer._buffers[buf] end

    local ret = nobject.object_common("buf_", nil, buf, buffer)

    buffer._buffers[buf] = ret

    return ret
end

local function get_win(win)
    if window_class._windows[win] then return window_class._windows[win] end

    local ret = nobject.object_common("win_", nil, win, window_class)
    assert(ret._private.handle == win)

    window_class._windows[win] = ret

    return ret
end



--- Get all buffers.
-- @property buffers

function session_class:get_buffers()
    local ret, bufs = {}, vim.api.nvim_list_bufs()

    for _, buf in ipairs(bufs) do
        table.insert(ret, get_buf(buf))
    end

    return ret
end

--- Get the list of windows.
-- @property windows

function session_class:get_windows()
    local ret, wins = {}, vim.api.nvim_list_wins()

    for _, win in ipairs(wins) do
        table.insert(ret, get_win(win))
    end

--     local b1 = vim.api.nvim_win_get_buf(ret[1]._private.handle)
--     local b2 = vim.api.nvim_win_get_buf(ret[2]._private.handle)

    return ret
end

--- Get the current window.
-- @property session.current_window

nobject._wrap_handle_property(session_class, window_class, "", "win_", "current_win", "current_window", window_class._windows)


--- Get the current mode.
-- @property mode

--- Get if the session is waiting for an input.
-- @property blocked

function session_class:get_mode()
    local ret = vim.api.nvim_get_mode()
    return ret.mode
end

function session_class:get_blocked()
    local ret = vim.api.nvim_get_mode()
    return ret.blocking
end

function session_class.get_session()
    if not singleton then
        singleton = nobject.object_common("", window, -42, session_class)
    end

    return singleton
end

return session_class
