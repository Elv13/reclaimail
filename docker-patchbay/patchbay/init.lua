local object = require("patchbay.object")

local module = object.patch_table({}, {
    is_module = true
})

local ret =  object.load_submodules(module, "patchbay")

-- Initialization.
ret.utils.delayed_call(function()
    --TODO add a return value to `:emit_signal` on which you
    --     can block/wait until all slot coroutines are
    --     completed.

    ret.directory.emit_signal("request::initialization")
    ret.rules.call.emit_signal("request::rules")
end)

return ret
