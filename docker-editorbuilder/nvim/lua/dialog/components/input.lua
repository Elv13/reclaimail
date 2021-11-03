local label = require("dialog.components.label")
local keymap = require("sugar.keymap")
local sugar = require("sugar")

local module = {}

local base_keymap = keymap{
    keys = {
        ["BS"] = function(self)
           self._private.input:backspace()
           self:emit_signal("backspace")
        end
    }
}

for k, v in pairs(label) do
    module[k] = v
end


function module:draw(stack)
    label.draw(self, stack)

    self._private.stack = stack
    --TODO move the cursor

    if self._private.stack._private.last_buffer then
        local win = self._private.stack._private.last_buffer.window
        if win then
            win.cursor.column = self.x+self._private.len
            win.cursor.row = self.y
        end
    end
end

function module:get_keymap()
    return self._private.keymap
end

function module:get_value()
    return self._private.value
end

function module:set_value(value)
    self._private.value = value
    self.text = self._private.prefix..self._private.value
end

function module:clear()
    self._private.value = ""
    self.text = self._private.prefix
end

function module:backspace()
    if self._private.value == "" then return end

    local text = self._private.value
    local len = vim.str_utfindex(text, #text)
    local new_end = vim.str_byteindex(text, len-1)
    module.set_value(self, text:sub(1, new_end))

    if self._private.stack then
        self._private.stack:draw()
    end
end

function module:insert(str, pos)
    if pos then
        assert(false)
    else
        module.set_value(self, self._private.value..str)
    end
end

local function new(_, width, height, prefix)
    local ret = label(width, height, prefix, module)

    ret._private.value = ""
    ret._private.keymap = keymap{}
    ret._private.keymap._private.input = ret
    ret._private.keymap:inherit(base_keymap)

    ret._private.prefix = prefix or ""
    ret._private.max_len = 0
    module.set_text(ret, prefix)

    ret._private.keymap:connect_signal("key", function(_, key)
        ret:insert(key)
        if ret._private.stack then
            ret._private.stack:draw()
        end
    end)

    return ret
end

return setmetatable(module, {__call=new})
