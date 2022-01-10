local create_object = require("reclaim.routing.object")

local module, overrides = {}, {}

function module:export(device)
    local p = self._private

    local line = {}

    if self._private.cmdline_fct then
        self._private.cmdline_fct(self, line)
    end

    if self.quiet then
        table.insert(line, "quiet")
    end

    local cmd = table.concat(line, " ")

    local ret = "LABEL "..(p.label or p.kernel).."\n"

    ret = ret .. " MENU LABEL "..(p.label or p.kernel).."\n"

    ret = ret .. " LINUX "..p.kernel.."\n"

    if p.initrd then
        ret = ret .." INITRD "..p.initrd.."\n"
    end

    ret = ret .. " APPEND "..cmd.."\n"

    device._private.kernels[self._private.kernel] = self

    print(ret)

    return ret
end

function module:set_label(value)
    self._private.label = value
end

function module:set_quiet(value)
    self._private.drive = value
end

function module:set_kernel(value)
    self._private.kernel_real = value
end

function module:get_kernel()
    return self._private.kernel_real
end

function module:set_initrd(value)
    self._private.initrd = value
end

function module:get_default()
    print("\n============IN DEFAULT!", self._private.default)
    return self._private.default
end

function module:set_default(value)
    self._private.default = value
end

local function new(_, args)
    local ret = create_object {enable_properties = true}
    ret._private.kernel = "vmlinux"..math.ceil(math.random() * 10000)
    ret._private.default = false

    create_object.add_class(ret, module)

    create_object.apply_args(ret, args, {}, overrides)

    return ret
end

return setmetatable(module, {__call = new})
