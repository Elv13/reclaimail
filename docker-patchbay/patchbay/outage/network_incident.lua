local incident = require("patchbay.incident")
local object   = require("patchbay.object")
local utils    = require("patchbay.utils")

local module = {}

local current = nil

function module:attempt_recovery()
    --TODO check incoming/outgoing
    --TODO create new bridges
end

function module:confirm_recovery()
    current = nil
    incident.confirm_recovery(self)
end

function module:confirm_outage()
    incident.confirm_outage(self)
end

local function new(_, args)
    local inc = incident {
        type     = "NETWORK",
        severity = args.severity,
    }

    object.shallow_copy(inc, module)
    inc.call = args.call

    return inc
end

function module._get_current()
    if not current then
        current = new(_, {})
    end

    return current
end

return object.patch_table(module, {
    call      = new,
    is_module = true,
})
