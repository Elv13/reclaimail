local create_object = require("reclaim.routing.object")

local module = {}

local gen_basic = {}

-- There is some inconsistencies. Some use of/off while
-- other 1/0.
local BOOL_TO_INT = {
    enable_uart = true,
}

local PI4BASIC = [[
[pi4]
dtoverlay=vc4-fkms-v3d
max_framebuffers=2

]]

gen_basic[4] = function(_)
    return PI4BASIC
end

function module:set_enable_uart(value)
    self._private.entries.enable_uart = value
end

function module:export(device)
    local ret = {}

    local gen = device.generation
    local needs_uart = self._private.enable_uart or false

    -- Consoles have both a kernel and uBoot components.
    for _, console in ipairs(device.consoles) do
        local args, dev_needs_uart = console:_export_uboot(device)

        for _, arg in ipairs(args) do
            table.insert(ret, arg[1].."="..arg[2])
        end

        needs_uart = needs_uart or dev_needs_uart
    end

    -- Add the outputs.
    for _, output in ipairs(device.outputs) do
        for _, arg in ipairs(output:_export_uboot(device)) do
            table.insert(ret, arg[1].."="..arg[2])
        end
    end

    if device._private.audio then
        for _, arg in ipairs(device._private.audio:_export_uboot(device)) do
            table.insert(ret, arg[1].."="..arg[2])
        end
    end

    -- Override the uart if there is a dependency on it.
    self._private.enable_uart = needs_uart

    for name, value in pairs(self._private.entries) do
        if BOOL_TO_INT[name] then
            table.insert(ret, name.."="..(value and 1 or 0))
        else
            table.insert(ret, name.."="..value)
        end
    end

    if self._private.enable_uart then
        table.insert(ret, "enable_uart=1")
        table.insert(ret, "core_freq=250")
    end

    if gen_basic[gen] then
        table.insert(ret, gen_basic[gen](self))
    end

    return table.concat(ret, "\n\n")
end

local function new(_, args)
    assert(args)

    local ret = create_object {enable_properties = true}
    ret._private.entries = {}
    assert(ret._private.entries)

    create_object.add_class(ret, module)
    assert(ret._private.entries)

    create_object.apply_args(ret, args, {}, overrides)

    assert(ret._private.entries)

    return ret
end

return create_object.load_submodules(module, "reclaim.routing.config", { __call = new })
