--- This file contains the char buffer used to render the popup.
--
-- In classic DOS mode, a double buffer would have been the way to
-- go since it has basic compositing capabilities. However Lua
-- doesn't have raw pointers and fast enough arrays. Another
-- option would be to use tons of nvim popups and compose them.
-- However that's unmaintainable.
--
-- This implementation creates a virtual character matrix to write on, a
-- clipping area, damage detection and ncurses like minimal primitives. The
-- minimal primitives are used by an higher level widget toolkit. This isn't
-- very fast or modern ways to implement widgets, but it is short and simple.

local module = {}

local line_mt, col_mt = {}, {}

-- Prevent widget from writing outside of their area *or* outside of the matrix.
local function filter_clip(self, col, value)
    local clip = self._stack._private.clip[#self._stack._private.clip]

    if not clip then return true end

    -- Damage is currently line based because cell based would be slower.
    if v then
        self._stack._private.damaged[self._line] = true
    end

    return col <= self._stack.width and self._line <= self._stack.height
        and self._line >= clip.y
--         and self._line < clip.y+clip.height --FIXME ???
        and col >= clip.x
        and col < clip.x + clip.width
end

-- Metamagic to lazy-load the matrix, apply clip and generate damage areas.
local function matrix_common(contructor, filter)
    return function(self, k, v)
        local count = #self._real
        assert(type(k) == "number")

        local pass = ((not filter) or filter(self, k, v))

        if k > count and pass then
            for i=count+1, k do
                rawset(self._real, i, contructor(self, k))
            end
        end

        if v and pass then
            rawset(self._real, k, v)
        end

        return rawget(self._real, k)
    end
end

line_mt.__newindex = matrix_common(function() return " " end, filter_clip)
col_mt.__newindex  = matrix_common(function(parent,line) return setmetatable({_real={},_line=line,_stack=parent._stack}, line_mt) end)
line_mt.__index = line_mt.__newindex
col_mt.__index  = col_mt.__newindex

-- Make sure there is no holes
local function concat_line(self, line)
    return table.concat(self.content[line] and self.content[line]._real or {})
end

function module:push_clip(x, y, width, height)
    table.insert(self._private.clip, {x=x,y=x,width=width,height=height})
end

function module:pop_clip()
    self._private.clip[#self._private.clip] = nil
end

function module:unclip()
    table.insert(self._private.clip, false)
end

function module:reset_clip()
    self._private.clip = {}
end

function module:clip_widget(widget)
    self:push_clip(
        widget.x,
        widget.y,
        widget.width,
        widget.height
    )
end

function module:_add_highlight(hl)
    if self._private.highlights_by_name[hl] then return end

    table.insert(self._private.active_highlights, hl)
    self._private.highlights_by_name[hl] = true
end

function module:_remove_highlight(hl)
    if not self._private.highlights_by_name[hl] then return end

    for k, other in ipairs(self._private.active_highlights) do
        if other == hl then
            table.remove(self._private.active_highlights, k)
        end
    end

    self._private.highlights_by_name[hl] = nil
end

-- Convert the UI matrix into text.
function module:draw(buffer)
    self:reset_clip()
    buffer = buffer or self._private.last_buffer

    if buffer == "print" then
        return self:print()
    end

    for _, w in ipairs(self._private.widgets) do
        w:meta_draw(self)
    end

    local ret, mod,ro = {}, buffer.options.modifiable,buffer.options.readonly

    for i=1, self.height do
        table.insert(ret, concat_line(self, i))
    end

    -- Apply the highlights.
    if buffer ~= "print" then
        for _, hl in ipairs(self._private.active_highlights) do
            vim.api.nvim_buf_add_highlight()
        end
        --
    end

    buffer.options.modifiable = true
    buffer.options.readonly = false
    buffer:set_line_range(0, self.height, ret)
    buffer.options.modifiable = mod
    buffer.options.readonly = ro

    self._private.last_buffer = buffer
    self._private.damaged = {}
end

--- Print into the command pane.
function module:print()
    local ret = {}

    for _, w in ipairs(self._private.widgets) do
        w:draw(self)
    end

    for i=1, self.height do
        table.insert(ret, concat_line(self, i))
    end

    table.insert(ret, "")

    vim.api.nvim_out_write(table.concat(ret, "\n"))
    self._private.last_buffer = "print"
end

function module:add_vertical_line(column, row, height)
    for i=0, height-1 do
        self.content[row+i][column] = "│"
    end
end

function module:add_horizontal_line(row, column, width)
    for i=0, width-1 do
        self.content[row][column+i] = "─"
    end
end

function module:add_box(x, y, width, height)
    assert(type(width) == "number")
    assert(type(height) == "number")
    self:add_horizontal_line(y, x, width)
    self:add_horizontal_line(y+height-1, x, width)
    self:add_vertical_line(x, y, height)
    self:add_vertical_line(x+width-1, y, height)
    self.content[y][x] = "┌"
    self.content[y][x+width-1] = "┐"
    self.content[y+height-1][x] = "└"
    self.content[y+height-1][x+width-1] = "┘"
end

function module:add_text(x, y, text)
    -- UTF-8 aware, any other encoding is unsupported, deal with it.
    local len = vim.str_utfindex(text, #text)

    for i=1, len do
        local start = vim.str_byteindex(text, i-1)
        local stop = vim.str_byteindex(text, i)-1
--       print("CHAR", start, stop, len, text:sub(start+1, stop+1), text)
--         io.popen("read")
        self.content[y][x+i-1] = text:sub(start+1, stop+1)
    end

--     self.content[y][x+len] = text:sub(stop+1, len+1)

    return len
end

function module:add_widget(widget)
    table.insert(self._private.widgets, widget)
end

local function new(_, args)
    assert(args and args.height and args.width)
    local ret = {
        height   = args.height,
        width    = args.width,
        _private = {
            widgets            = {},
            damaged            = {},
            clip               = {},
            active_highlights  = {},
            highlights_by_name = {}
        }
    }

    ret.content =  setmetatable({_real={},_stack=ret}, col_mt)

    return setmetatable(ret, { __index = module })
end

return setmetatable(module, {__call=new})
