local widget = require("dialog.components.widget")
local layout = require("dialog.components.layout")

local module = {}

local LEFT_DELIM = "[" -- "┤"
local RIGHT_DELIM = "]" -- "├"

function module:add_horizontal_box_label(x, y, text)
    local lbl = LEFT_DELIM..text..RIGHT_DELIM

    return self:add_text(x, y, lbl)
end

function module:draw(stack)
    stack:clip_widget(self)
    stack:add_box(self.x, self.y, self.width, self.height)

    for pos, labels in pairs(self._private.labels or {}) do
        local left_off, right_off = 0, 0
        local row = pos == "top" and self.y or (self.y+self.height-1)

        for align, labels2 in pairs(labels) do
            for _, label in ipairs(labels2) do
                local lbl = LEFT_DELIM..label.text..RIGHT_DELIM
                local len = vim.str_utfindex(lbl, #lbl)

                if align == "left" then
                    stack:add_text(self.x + left_off + 2, row, lbl)
                    left_off = left_off + len
                elseif align == "right" then
                    right_off = right_off + len
                    stack:add_text(self.x + self.width - right_off - 2, row, lbl)
                else
                    stack:add_text(self.x + math.floor((self.width-len)/2), row, lbl)
                end
            end
        end
    end

    if self._private.layout then
        self._private.layout:meta_draw(stack)
    end

    stack:pop_clip()
end

local valid_pos = {top=true, bottom=true}
local valid_align = {left=true, center=true, right = true}

function module:add_label(text, align, position)
    assert(type(text) == "string")
    align    = align or "center"
    position = position or "top"
    assert(valid_pos[position] and valid_align[align])
    self._private.labels[position] = self._private.labels[position] or {}
    self._private.labels[position][align] = self._private.labels[position][align] or {}

    table.insert(self._private.labels[position][align], {
        text = text
    })
end

function module:get_layout()
    if not self._private.layout then
        self._private.layout = layout(self.width-2, self.height-2, true)
        self._private.layout.x = self.x+1
        self._private.layout.y = self.y+1
    end

    return self._private.layout
end

local function new(_, width, height)
    local ret = widget(width, height, module)

    ret._private.labels = {}

    return ret
end

return setmetatable(module, {__call=new})
