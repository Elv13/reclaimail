local create_object = require("reclaim.routing.object")

local module, overrides = {}, {}

function module:set_enabled(value)
    self._private.enabled = value
end

function module:_export_cmdline(device)
    local ret = {}

    return ret
end

function module:_export_uboot(device)
    local ret = {}

    return ret
end

local function new(_, args)
    local ret = create_object {enable_properties = true}
    ret._private.is_output = true

    create_object.add_class(ret, module)

    create_object.apply_args(ret, args, {}, overrides)

    return ret
end

return setmetatable(module, {__call = new})
