local create_object = require("reclaim.routing.object")

local module, overrides = {}, {}

function module:export()
    local p = self._private
    return "LABEL "..(p.label or "Chainload").."\n"..
        " MENU LABEL "..(p.label or "Chainload").."\n"..
        " KERNEL chain.c32\n"..
        " APPEND hd"..p.drive.." "..(p.partition or 0)
end

function module:set_label(value)
    self._private.label = value
end

function module:set_drive(value)
    self._private.drive = value
end

function module:set_partition(value)
    self._private.partition = value
end

function module:get_default()
    return self._private.default
end

function module:set_default(value)
    self._private.default = value
end

local function new(_, args)
    local ret = create_object {enable_properties = true}
    ret._private.is_output = true
    ret._private.default = false

    create_object.add_class(ret, module)

    create_object.apply_args(ret, args, {}, overrides)

    return ret
end

return setmetatable(module, {__call = new})
