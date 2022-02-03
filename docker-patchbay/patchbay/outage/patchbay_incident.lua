local incident = require("patchbay.outage.incident")
local object   = require("patchbay.object")
local utils    = require("patchbay.utils")

local module = {}


local function new(_, args)
    args = args or {}
    local inc = incident {
        type     = "PATCHBAY",
        severity = args.severity,
    }

    inc.summary = args.summary
    inc.type = "PATCHBAY"

    -- This type of incident doesn't have any state transition.
    inc:confirm_failure()

    return inc
end

return object.patch_table(module, {
    call      = new,
    is_module = true,
})
