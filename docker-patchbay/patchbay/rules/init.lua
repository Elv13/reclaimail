local object = require("patchbay.object")

local module = object.patch_table({}, {
    is_module = true
})

return object.load_submodules(module, "patchbay.rules")
