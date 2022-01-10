local create_object = require("reclaim.routing.object")

local module, overrides = {}, {}

-- Doc:
-- https://www.raspberrypi.org/documentation/configuration/config-txt/video.md

module.modes = {
    NTSCi    = 0,
    NTSCi_JP = 1,
    PALi     = 2,
    PALi_BR  = 3,
    NTSCp    = 16,
    PALp     = 18,
}

module.ratios = {
    R4_3  = 1,
    R14_9 = 2,
    R16_9 = 3,
}

local DEFAULT_MODE = module.modes.NTSCi
local DEFAULT_RATIO = module.ratios.R4_3

function module:set_enabled(value)
    self._private.enabled = value
end

function module:_export_cmdline(device)
    if not self._private.enabled then return {} end

    local ret = {
        {"video", "Composite-1"}
    }

    return ret
end

function module:_export_uboot(device)
    if not self._private.enabled then return {} end

    local ret = {}

    table.insert(ret, {"sdtv_mode"  , self._private.mode or DEFAULT_MODE})
    table.insert(ret, {"sdtv_aspect", self._private.mode or DEFAULT_RATIO})

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
