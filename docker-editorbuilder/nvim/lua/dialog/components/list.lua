--- String list with scrollbar.

local widget = require("dialog.components.widget")

local module = {}

local function gen_clear(len)
    local ret = ""
    for _=1, len do ret = ret .. " " end
    return ret
end

function module:draw(stack)
    stack:clip_widget(self)
    local line_begin = self._private.view
    local line_end = math.min(#self._private.lines, self._private.view+self.height-1)

    -- Clear the old content.
    if self._private.old_count then
        -- The +2 is for the "> " prefix.
        local clr = gen_clear(self._private.old_len+2)
        for i=1, math.min(self._private.old_count, self._private.view+self.height-1) do
            stack:add_text(self.x, self.y+line_begin+i-2, clr)
        end

        self._private.old_count = nil
        self._private.old_len  = nil

        if self._private.selected > #self._private.lines then
            self._private.selected = 1
            self._private.view = 1
            line_begin = 1
        end
    end

    for i=1, line_end-line_begin+1 do
        local txt = self._private.lines[line_begin+i-1]
        if not txt then break end

        if line_begin+i-1 == self._private.selected then
            txt = "> " .. txt
        else
            txt = txt .. "  "
        end

        stack:add_text(self.x, self.y+line_begin+i-2, txt.."  ")
    end

    stack:pop_clip()
end

function module:append_lines(lines)
    for _, line in ipairs(lines) do
        self:append_line(line)
    end
end

function module:append_line(line)
    table.insert(self._private.lines, line)
end

function module:set_lines(lines)
    self._private.lines = lines
end

function module:clear()
    self._private.old_count = #self._private.lines
    self._private.old_len  = 0

    for _, line in ipairs(self._private.lines) do
        self._private.old_len = math.max(
            self._private.old_len,
            vim.str_utfindex(line, #line)
        )
    end

    self._private.lines = {}
end

function module:select_up()
    if self._private.selected == 1 then
        self._private.selected = #self._private.lines
    else
        self._private.selected = self._private.selected - 1
    end

    if self._private.selected < self._private.view then
        self._private.view = self._private.selected
    end
end

function module:select_down()
    if self._private.selected == #self._private.lines then
        self._private.selected = 1
    else
        self._private.selected = self._private.selected + 1
    end

    if self._private.selected > self._private.view+self.height then
        self._private.view = self._private.selected
    end
end

function module:get_selected()
    return self._private.selected
end

function module:set_selected(value)
    if value > #self._private.lines or value < 1 then return end
    self._private.selected = value
end

local function new(_, width, height)
    local ret = widget(width, height, module)
    ret._private.selected = 1
    ret._private.view = 1
    ret._private.lines = {}
    return ret
end

return setmetatable({}, {__call=new})
