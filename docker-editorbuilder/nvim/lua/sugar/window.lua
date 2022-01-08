local nobject = require( "sugar.nobject" )
local buffer  = require( "sugar.buffer"  )
local tabpage = require( "sugar.tabpage" )
local cursor  = require( "sugar.cursor"  )

local window_class = {_windows={}}

--- Get the current buffer.
-- @property current_buffer

nobject._wrap_handle_property(window_class , buffer, "win_", "buf_", "buf", "current_buffer", buffer._buffers)

--- The tabpage.
-- @property tabpage

nobject._wrap_handle_property(window_class , tabpage, "win_", "tabpage_", "tabpage", "tabpage", tabpage._tabpages)

--- The window height.
-- @property height

nobject.wrap_property(window_class, "win_", "height", "height")

--- The width.
-- @property width

nobject.wrap_property(window_class, "win_", "width", "width")

function window_class:get_selection_begin()
    local ret = cursor {window = self, get_position = "v", set_position="'v"}
    rawset(self, "selection_begin", ret)
    return ret
end

function window_class:get_selection_end()
    local ret = cursor {window = self, get_position = ".", set_position="."}
    rawset(self, "selection_end", ret)
    return ret
end

--- Get the selected text.
-- @property selected_text

function window_class:get_selected_text()
    if vim.api.nvim_get_mode().mode ~= "v" then return nil end

    local pos1 = vim.fn.getpos('v')
    local pos2 = vim.fn.getpos('.')
    local start  = { pos1[2] - 1, pos1[3] - 1 + pos1[4] }
    local finish = { pos2[2] - 1, pos2[3] - 1 + pos2[4] }
    local buf = self.current_buffer

    if not buf then return end

    local lines = buf:get_line_range(start[1], finish[1]+1)

    if #lines == 0 then return end

    if #lines == 1 then
        if start[2] < finish[2] then
            return  lines[1]:sub(start[2] + 1, finish[2])
        else
            return  lines[1]:sub(finish[2] + 1, start[2])
        end
    else
        local ret = {}

        table.insert(ret, table.remove(lines,1):sub(start[2]+1, #lines[1]))

        local last = table.remove(lines,#lines):sub(1, finish[2]+1)

        for _, line in ipairs(lines) do
            table.insert(ret, line)
        end

        return table.concat(ret, "\n")
    end
end

function window_class:get_cursor()
    local ret = cursor {window = self}
    rawset(self, "cursor", ret)
    return ret
end

--- Remove the selection and return it.
-- @method pop_selection

function window_class:pop_selection()
    if vim.api.nvim_get_mode().mode ~= "v" then return nil end

    local ret = self.selected_text

    vim.api.nvim_input('<BS>')

    return ret
end

--- Remove the selected lines and return the text.
-- @method pop_selected_lines

function window_class:pop_selected_lines()
    local sel_start, sel_end = self.selection_begin.row, self.selection_end.row
    sel_start, sel_end = math.min(sel_start, sel_end), math.max(sel_start, sel_end)

    local ret = self.current_buffer:get_line_range(sel_start-1, sel_end)
    self.current_buffer:set_line_range(sel_start-1, sel_end-1, {}, false)

    return ret
end

--- Get the current line text.
-- @property current_line

function window_class:get_current_line()
    local row = self.cursor.row

    return self.current_buffer:get_line_range(row-1, row+1)[1]
end

function window_class:set_current_line(content)
    local row = self.cursor.row
    self.current_buffer:set_line_range(row-1, row, {content})
end

--- Delete the current line.
-- @method delete_current_line

function window_class:delete_current_line()
    local row = self.cursor.row
    self.cursor.column = 0

    self.current_buffer:set_line_range(row-1, row, {})
end

--- The lenght (UTF ajusted) of the current line.
-- @property current_line_lenght

function window_class:get_current_line_lenght()
    return vim.str_utfindex(self.current_line)
end

--- Insert lines above the cursor.
-- @method insert_lines_above

function window_class:insert_lines_above(lines, replace)
    local row = self.cursor.row
    self.current_buffer:set_line_range(row-1,row-1+(replace and 1 or 0),lines)
    self.cursor.row = row + #lines
    self.cursor.column = 1
end

--- Close a window.
-- @method window:close
-- @tparam[opt=false] boolean force
function window_class:close(force)
    force = force or false
    vim.api.nvim_win_close(self._private.handle, force)
end

--- The window vertical position.
-- @property row

--- The window horizontal position.
-- @property column

function window_class:get_row()
    local pos = vim.api.nvim_win_get_position(self._private.handle)

    return pos[1]
end

function window_class:get_column()
    local pos = vim.api.nvim_win_get_position(self._private.handle)

    return pos[2]
end

local config_props = {
    focusable = true,
    row       = true,
    column    = true,
    external  = true,
    style     = true,
    relative  = true
}

for prop in pairs(config_props) do
    window_class["get_"..prop] = function()
        local cfg = vim.api.nvim_win_get_config(self._private.handle)
        return cfg[prop]
    end

    window_class["set_"..prop] = function(r)
        local cfg = vim.api.nvim_win_get_config(self._private.handle)
        cfg[prop] = r
        vim.api.nvim_win_set_config(self._private.handle, cfg)
    end
end

local function new(_, args)
    args = args or {}

    local buf = args.buffer and args.buffer._private.handle or 0

    local real_args = {
        focusable = args.focusable,
        external  = args.external ,
        style     = args.style    ,
        relative  = args.relative ,
        width     = args.width  or 10,
        height    = args.height or 10,
    }

    if args.relative and args.relative  == "editor" and args.row and args.column then
        real_args.row = args.row
        real_args.col = args.column
    elseif args.row and args.column then
        real_args.bufpos = {args.row, args.column}
    end

    local handle = vim.api.nvim_open_win(buf, false, real_args)
    local ret = nobject.object_common("win_", nil, handle, window_class)

    for k, v in pairs(args.options or {}) do
        ret.options[k] = v
    end

    return ret
end

return setmetatable(window_class, {__call=new})
