--- **VERY** naïve layout system.
--
-- This is not the full AwesomeWM style layouts. It's just
-- a splitting the container into 2 (b-tree) parts. One part has a
-- fixed size and the other takes the remaining space. There
-- is also an optional offset for a frame.
--
-- The main (and only) use case are some static "card form"
-- style boxed division.
local widget = require("dialog.components.widget")

local module = {}

local function frame_offset(self)
    return self._private.has_frame and 1 or 0
end

local function new(_, width, height, has_frame)
    has_frame = has_frame or false
    local ret = widget(width, height, module)

    rawset(ret, "has_frame", has_frame)

    return ret
end

function module:draw(stack)
    stack:clip_widget(self)
    if self._private.widget then
        for _, prop in ipairs {"x", "y", "width"--[[, "height"]] } do --FIXME
            self._private.widget[prop] = self[prop]
        end

        self._private.widget:meta_draw(stack)
        return
    end

    if self._private.child_a then
        self._private.child_a._private.parent = self
    end
    if self._private.child_b then
        self._private.child_b._private.parent = self
    end

    if self.has_frame and self._private.child_a and self._private.child_b then
        stack:unclip()
        if self._private.orientation == "h" then
            local y = self._private.child_a.y + self._private.child_a.height
            stack:add_horizontal_line(y, self.x, self.width)
            if self._private.child_a._private.parent and self._private.child_a._private.parent.has_frame then
                stack:add_text(self.x-1, y, "├")
                stack:add_text(self.x+self.width, y, "┤")
            end
        else
            local x = self._private.child_a.x + self._private.child_a.width + 1
            stack:add_vertical_line(x, self.y, self.height)
            if self._private.child_a._private.parent and self._private.child_a._private.parent.has_frame then
                stack:add_text(x,self.y-1, "┬")
                stack:add_text(x,self.y+self.height, "┴")
            end
        end
        stack:pop_clip()
    end

    if self._private.child_a then
        self._private.child_a:meta_draw(stack)
    end
    if self._private.child_b then
        self._private.child_b:meta_draw(stack)
    end

    stack:pop_clip()
end

--- Return 2 new layouts (fixed area at the top).
-- @tparam number height The height of the fized section (in character units).
-- @tparam boolean has_frame_top If the new top widget has a frame.
-- @tparam boolean has_frame_bottom If the new bottom widget has a frame.
-- @treturn sugar.layout The top (fixed) layout.
-- @treturn sugar.layout The bottom (variable) layout.
function module:horizontal_split_top(height, has_frame_top, has_frame_bottom)
    assert(type(height) == "number")
    assert(type(self.height) == "number")
    assert(height < self.height+frame_offset(self))
    assert(not self._private.widget)
    assert((not self._private.child_a) and (not self._private.child_b))

    local new_h = self.height - height - (self.has_frame and 1 or 0)
    self._private.child_a = new(nil, self.width, height, has_frame_top)
    self._private.child_b = new(nil, self.width, new_h , has_frame_bottom)

    self._private.child_a.x, self._private.child_a.y = self.x, self.y
    self._private.child_b.x, self._private.child_b.y = self.x, self.y+height+frame_offset(self)+1

    self._private.orientation = "h"

    return self._private.child_a, self._private.child_b
end

function module:horizontal_split_bottom(height, has_frame_top, has_frame_bottom)
    local a, b = module.horizontal_split_top(self, height, has_frame_bottom, has_frame_top)
    self._private.child_a, self._private.child_b = b, a

    self._private.child_a.x, self._private.child_a.y = self.x, self.y+self.height-height+frame_offset(self)
    self._private.child_b.x, self._private.child_b.y = self.x, self.y

    return b, a
end

function module:vertical_split_left(width, has_frame_left, has_frame_right)
    assert(width < self.width+frame_offset(self))
    assert(not self._private.widget)
    assert((not self._private.child_a) and (not self._private.child_b))

    local new_w = self.width - width - (self.has_frame and 1 or 0)
    self._private.child_a = new(nil, width, self.height, has_frame_left)
    self._private.child_b = new(nil, new_w, self.height, has_frame_right)

    self._private.child_a.x, self._private.child_a.y = self.x+width+frame_offset(self), self.y
    self._private.child_b.x, self._private.child_b.y = self.x, self.y

    self._private.orientation = "v"

    return self._private.child_a, self._private.child_b
end

function module:vertical_split_right(width, has_frame_left, has_frame_right)
    local a, b = module.vertical_split_left(self, width, has_frame_right, has_frame_left)
    self._private.child_a, self._private.child_b = b, a

    self._private.child_a.x, self._private.child_a.y = self.x, self.y
    self._private.child_b.x, self._private.child_b.y = self.x+self.width-width-frame_offset(self)+1, self.y

    return b, a
end

--- The layout widget.
--
-- Once there is a widget, it is no longer possible to split.
--
-- @property widget

function module:set_widget(w)
    assert(not self._private.child_a)
    self._private.widget = w
end

function module:get_widget()
    return self._private.widget
end

return setmetatable({}, {__call=new})
