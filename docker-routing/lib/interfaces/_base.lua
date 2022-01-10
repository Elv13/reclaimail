
local dnsmasq = require("reclaim.routing.dnsmasq")
local unpack    = unpack or table.unpack -- Lua 5.1 compat
local procip, sysip = unpack(require("reclaim.routing.proc_ip"))
local debian = require("reclaim.routing.debian")
local module, methods = {}, {}

local current_interfaces = {}

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

local function find_interface_name(mac)
    for i, conf in pairs(sysip) do
        local ma = conf.address:gmatch("([^\n]+)")()
        assert(ma, "This script expects /sys/class/net to exist")

        if mac == ma then
            return i
        end
    end
end

-- Those are the type of supported interfaces.
local areas = {
    ["local"] = true,
    wide      = true,
    wireguard = true,
}

--- Register a network interface.
local function add_interface(_, args)
    -- It's better than having to wrap in a pcall
    if (not args.mac) and (not args.name) then return nil end

    assert(areas[args.area])
    assert(args.mac or args.name)
    args.name = args.name or find_interface_name(args.mac)
    assert(args.name, "Could not find the interface name for "..args.mac)
    assert(not current_interfaces[args.name], "Interface "..args.name.." already exists")

    local ret = {
        _args = args,
        conf  = sysip[args.name]
    }

    current_interfaces[args.name] = ret

    if args.area == "local" or args.area == "wlan" then
        local first_range = args.ranges_v4 and args.ranges_v4[1] or nil
        local mask = first_range and first_range.netmask_v4 or "255.255.255.0"
        local addr = first_range and first_range.begin_v4 or "192.168.100.1"
        ret._addr = addr
        ret._mask = mask
        debian.add_static_iface(args.name, addr, mask)
    elseif args.area == "wide" then
        debian.add_dhcp_iface(args.name)
    end

    -- First, turn it on. At some point this should become a library based on the
    -- syscalls like the `ip` command.
    if args.enabled then
        os.execute("ifup "..find_interface_name(os.getenv("LAN_MAC")))
    end

    -- Configure the interface (proc).
    for _, i in ipairs {"conf"} do --TODO add more proxy config
        for k, v in pairs(args[i] or {}) do
            ret[i][k] = v
        end
    end

    if args.area == "local" then
        print("Adding DHCP interface to "..args.name)
        table.insert(dnsmasq.config._buffer, "interface="..args.name)
    end

    -- Apply the other config in a **RANDOM** order.
    for k, v in pairs(args) do
        if methods["set_"..k] then
            methods["set_"..k](ret, v)
        end
    end

    dnsmasq.session.emit_signal("interface::added", ret)

    return ret
end

module.find_interface_name = find_interface_name

return setmetatable(module, {__call = add_interface})
