--- Base class for a device.
-- It allows to set the DHCP lease and must be extended
-- by other devices.
--
local utils = require("reclaim.routing.utils")
local create_object = require("reclaim.routing.object")

local module, overrides = {}, {}

function module:set_lease(lease)
    --TODO
end

local function new(_, args)
    args = args or {}
    local ret = create_object { enable_properties = true }

    create_object.add_class(ret, module)

    if args.lease then
        ret.lease = args.lease
    end

    -- Breakdown the MAC address into 2 bytes and add an entry
    -- for each.
    if args.mac_address then
        for _, addr in ipairs(utils.hwaddr_to_sequ(args.mac_address)) do
            module._device_by_mac[addr] = module._device_by_mac[addr]
                or setmetatable({}, {__mode = "v"})

            table.insert(module._device_by_mac[addr], ret)
        end
    end

    return ret
end

-- Keep a weak index of the devices.
module._device_by_mac = {}

return setmetatable(module, {__call = new})
