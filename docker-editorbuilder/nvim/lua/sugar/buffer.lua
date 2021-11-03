local nobject = require("sugar.nobject")
-- local modes   = require("sugar.modes")

local module = {}

module._buffers = {}


--- Get lines from a buffer.
--
-- If you need more than 1 line, this is much more efficient
-- than using the `lines` property.
--
-- @method get_line_range
-- @tparam number first
-- @tparam number last
-- @tparam[opt=false] boolean strict_indexing
-- @treturn table The lines.

function module:get_line_range(first, last, strict_indexing)
    strict_indexing = strict_indexing or false
    return vim.api.nvim_buf_get_lines(self._private.handle, first, last, strict_indexing)
end

function module:set_line_range(first, last, lines, strict_indexing)
    strict_indexing = strict_indexing or false
    return vim.api.nvim_buf_set_lines(self._private.handle, first, last, strict_indexing, lines)
end

--- Add new lines at the end of the buffer.
-- @method append_lines

function module:append_lines(lines)
    local offset = self:get_line_range(self.line_count-1, self.line_count)[1]=="" and 1 or 0

    self:set_line_range(self.line_count-offset, self.line_count+#lines-offset, lines, false)
end

--- Get the number of lines.
-- @property line_count

nobject.wrap_property(module, "buf_", "line_count", "line_count", true)

--- Delete the buffer keymap.
-- @method :delete_keymap()
function module:delete_keymap()
--     for _, mode in ipairs(modes._mode_names) do
--         vim.api.nvim_set_keymap(self._private.handle, mode)
--     end
end

--- Set the buffer content.
-- @property text

function module:set_text()
    --
end

--- Get the full file name of the buffer.
-- @property file_name

function module:get_file_name()
    return vim.api.nvim_buf_get_name(self._private.handle)
end

--- Return true if the buffer is valid.
-- @property valid

function module:get_valid()
    return vim.api.nvim_buf_is_valid(self._private.handle)
end

--- Get the window currently displaying this buffer.
-- @property window

function module:get_window()
    local sugar = require("sugar")

    local wins = sugar.session.windows

    for _, win in ipairs(wins) do
        if win.current_buffer == self then
            return win
        end
    end

    return nil
end

--- Delete a buffer.
-- @method delete

--- Wipeout a buffer.
-- @method wipeout

function module:wipeout()
    vim.api.nvim_command(":bwipeout! "..self._private.handle)
end

function module:delete()
    vim.api.nvim_command(":bdelete! "..self._private.handle)
end

local function new(_, args)
    --nvim_create_buf
    args = args or {}

    local listed  = args.listed  or false
    local scratch = args.scratch or false

    local handle = vim.api.nvim_create_buf(listed, scratch)

    local ret = nobject.object_common("buf_", nil, handle, module)

    for k, v in pairs(args.options or {}) do
        ret.options[k] = v
    end

    module._buffers[handle] = ret

    return ret
end

return setmetatable(module, {__call = new})
