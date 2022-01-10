local base    = require( "reclaim.routing.interfaces._base" )
local dnsmasq = require( "reclaim.routing.dnsmasq"          )
local utils   = require( "reclaim.routing.utils"            )


-- This interface isn't really related to the wan/lan/wlan.
-- The idea is to keep the API consistent, but it share little
-- code with them.
local module, methods = {}, {}

local iname_counter = 0

function methods:set_ranges_v4(ranges_v4)
    local args = self._args

    for _, range in ipairs(args.ranges_v4 or {}) do
        assert(args.area == "local", "Only local area can use dhcp")
        --TODO tags and sets
        assert(range.begin_v4 and range.end_v4)
        local expire = args.expire or "72h"
        local range = range.begin_v4..","..range.end_v4

        if args.netmask_v4 then
            range = range .. ","..args.netmask_v4
        end

        range = range..","..expire

        print("Adding range" .. range .." to "..args.name)
        table.insert(dnsmasq.config._buffer, "dhcp-range="..range)
    end

    --TODO IPv6 ranges
end

local function init(args)
    --ip address add dev wg0 192.168.100.1/24

    -- Apply the other config in a **RANDOM** order.
    for k, v in pairs(args) do
        if methods["set_"..k] then
            methods["set_"..k](ret, v)
        end
    end

    local function create()
        local wan = dnsmasq.interfaces.by_area["wide" ][1]
        local name = args.name or ("wg"..iname_counter)
        local dns  = wan._addr
        local mask = utils.netmask_to_cidr(wan._mask)
        iname_counter = iname_counter + 1

        os.execute("ip address add dev "..name.." "..dns.."/"..mask)

        --cos.execute("ip -4 route add up dev "..name.." table $table")
        --os.execute("ip -4 rule add not fwmark $table table $table")
        --os.execute("ip -4 rule add table main suppress_prefixlength 0")
    end


    -- Some people might try to create the interface too early.
    -- Allow to delay until we have all the information required.
    if dnsmasq.interfaces.by_area["wide" ][1] then
        create()
    else
        dnsmasq.session.connect_signal("interface::added", create)
    end

end

return module