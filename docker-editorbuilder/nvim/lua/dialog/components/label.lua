local widget = require("dialog.components.widget")

local module = {}

function module:draw(stack)
    stack:clip_widget(self)
    local txt = self._private.text

    assert(self.width>1)
    assert(self.height>=1)

    if self._private.max_len > self._private.len then
        for _=self._private.len, self._private.max_len do
            txt = txt .. " "
        end
    end

    stack:add_text(self.x, self.y, txt)

    -- The extra content has been erased, there is no point to do it many times.
    self._private.max_len = self._private.len

    stack:pop_clip()
end

function module:set_text(text)
    self._private.text = text

    -- Make sure the content is earased is the text is changed to a smaller one.
    self._private.len = vim.str_utfindex(text, #text)
    self._private.max_len = math.max(self._private.len, self._private.max_len)
end

function module:get_text()
    return self._private.text
end

local function new(_, width, height, text, _module)
    assert(width and height)
    text = text or ""
    local ret = widget(width, height, _module or module)

    ret._private.max_len = 0
    module.set_text(ret, text)

    return ret
end

return setmetatable(module, {__call=new})
