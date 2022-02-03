local incident = require("patchbay.outage.incident")
local object   = require("patchbay.object")
local utils    = require("patchbay.utils")

local module = {}

function module:attempt_recovery()
    self.did:unregister()
    self._private.start_recovery = true
    utils.msleep(1000)
    self.did:register()
end

local function new(_, args)
    assert(args and args.did)

    local inc = incident {
        type     = "DID",
        severity = args.severity,
    }

    inc.did = args.did

    function inc._private.cb_state()
        local state = did.state

        if did.state == "REGED" then
            inc:confirm_recovery()
            did:disconnect_signal("property::state", inc._private.cb_state)
        elseif state == "REGISTER" then
            --
        elseif state == "DOWN" then
            self._private.start_recoveury = false
        elseif state == "FAIL_WAIT" then
            --
        elseif state == "FAILED" then
            self._private.start_recovery = false
        elseif state  == "UNREGED" then
            --
        elseif state == "TRYING" then
            --
        end
    end

    return inc
end

return object.patch_table(module, {
    call      = new,
    is_module = true,
})
