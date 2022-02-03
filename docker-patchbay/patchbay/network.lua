--- This class represents the network.
--
-- It is mostly for the module-level signals.
local object = require("patchbay.object")

local module = {}

--- When the network goes down.
-- @signal state::down

--- When the network does up.
-- @signal state::up

return object.patch_table(module, {
    is_module = true,
    class     = module
})
