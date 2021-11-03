--- Represents an (x, y) position in a window.
--
-- NeoVIM doesn't support multicursor, which is a shame. Apparently,
-- it is due to a mix of elitism "we do it a diffrent way" and
-- "vim was never intended for this, it would break everything".
--
-- Despite that, a cursor isn't "simple". There can be multiple of
-- them if you consider the selection. It can also be over multiple
-- rows in block visual mode. Plus, with some hacks, it is possible
-- to emulate true multi-cursor as long as you can restrict how they
-- are used.
local sugar = require("sugar._base")

local module = {}

local function get_position(pos)
    local ret =  sugar.global_functions.getpos(pos)

    return {
        buffer = ret[1],
        row    = ret[2],
        column = ret[3],
        off    = ret[4]
    }
end

local function get_main(self)
    local cur = vim.api.nvim_win_get_cursor(
        self._private.window._private.handle
    )

    return {
        row   = cur[1],
        column = cur[2],
        buffer = vim.api.nvim_win_get_buf(
            self._private.window._private.handle
        )
    }
end

local function get_cursor(self)
    if self._private.get_position then
        return get_position(self._private.get_position)
    else
        return get_main(self)
    end
end

--- The buffer object.
-- @property buffer

function module.get_buffer(self)
    local c = get_cursor(self)
    return c.buffer --TODO use the object, not the handle.
end


function module.get_row(self)
    local c = get_cursor(self)
    assert(type(c.row) == "number")
    return c.row
end

function module.set_row(self, row)
    assert(type(row) == "number")
    assert(type(self.column) == "number")

    if self._private.set_position then
        sugar.global_functions.setpos(self._private.set_position, {
            0, --self._private.window and self._private.window._private.handle or 0,
            row,
            self.column,
            0
        })
    else
        vim.api.nvim_win_set_cursor(self._private.window._private.handle, {row, self.column})
    end
end

function module.get_column(self)
    local c = get_cursor(self)
    assert(type(c.column) == "number")
    return c.column
end

function module.set_column(self, column)
    assert(type(column) == "number")
    assert(type(self.row) == "number")
    if self._private.set_position then
        local ret = sugar.global_functions.setpos(self._private.set_position, {
            0,--self._private.window and self._private.window._private.handle or 0,
            self.row,
            column,
            0,
            column
        })
        -- print("FOO", self._private.set_position, self.row, column, ret)
    else
        vim.api.nvim_win_set_cursor(self._private.window._private.handle, {self.row, column})
    end
end

--- The buffer (top) row.
-- @property row

--- The buffer column.
-- @property column

--- The cursor height. TODO
-- @property height

--- Return a new cursor.
-- @tparam table args
-- @tparam string args.get_position The argument to `getpos()`
-- @tparam string args.set_position The argument to `setpos()`
-- @tparam sugar.window args.window The window object.

local function new_cursor(_, args)
    args = args or {}
    assert(args.window, debug.traceback())

    local ret = {
        _private = {
            set_position = args.set_position,
            get_position = args.get_position,
            window       = args.window
        }
    }

    return setmetatable(ret, {
        __index = function(_, k)
            if module["get_"..k] then return module["get_"..k](ret) end
        end,
        __newindex = function(_, k, v)
            if module["set_"..k] then return module["set_"..k](ret, v) end
        end
        --TODO setters
    })
end

--     local row_begin = sugar.global_functions.getpos("v")[2]
--     local row_end   = sugar.global_functions.getpos(".")[2]

return setmetatable(module, {
    __call = new_cursor
})
