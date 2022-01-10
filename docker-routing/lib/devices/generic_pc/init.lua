local create_object = require("reclaim.routing.object")
local base    = require("reclaim.routing.devices._base")

local module = {}

local DEFAULT_TFTP_ROOT = "syslinux/"

local function tftp_lookup(self, file, lease, content)
    print("FILE", file.path)
    if not self.syslinux then return end

    -- Assume the device rebooted and reset the state machine.
    if file.path == "pxelinux.0" then
        self._private.tftp_root = DEFAULT_TFTP_ROOT
        self._private.auto_forward = true
    end

    -- Upload the main menu.
    if file.path == "pxelinux.cfg/default" then
        content[true] = self.syslinux:export(self)
        return
    end

    -- We already got a request for syslinux, assume everything
    -- is for syslinux now. Then if `kernel._private.tftp_root`
    -- exists, then assume that menu entry has been selected
    -- and "chroot" there.
    if self._private.auto_forward then
        local kernel = self._private.kernels[file.path]
        if kernel then
            content[false] = kernel.kernel
            self._private.tftp_root = kernel._private.tftp_root
                or self._private.tftp_root
            return
        end

        content[false] = self._private.tftp_root..file.path
    end
end

local function new(_, args)
    local ret = base(args)

    ret._private.consoles2 = {}
    ret._private.outputs   = {}
    ret._private.kernels   = {}
    ret._private.tftp_root = DEFAULT_TFTP_ROOT

    create_object.add_class(ret, module)

    create_object.apply_args(ret, args, {}, overrides)

    ret:connect_signal("file::lookup", tftp_lookup)

    return ret
end

return create_object.load_submodules(module, "reclaim.routing.devices.generic_pc", {
    __call = new
})

