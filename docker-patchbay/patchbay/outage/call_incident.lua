local incident = require("patchbay.incident")
local object   = require("patchbay.object")
local utils    = require("patchbay.utils")

local module = {}

function module:attempt_recovery()
    --TODO check incoming/outgoing
    --TODO create new bridges
end

local function new(_, args)
    assert(args and args.call)

    local inc = incident {
        type     = "CALL",
        severity = args.severity,
    }

    inc.call = args.call

    return inc
end

return object.patch_table(module, {
    call      = new,
    is_module = true,
})
