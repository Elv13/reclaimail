local create_object = require("reclaim.routing.object")

local module = {}

return create_object.load_submodules(module, "reclaim.routing.devices.generic_pc.syslinux")
