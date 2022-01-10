-- This file writes the debian style /etc/network/interface.
-- Until udhcpc is pried off busybox, this file is still needed
-- to configure ifup/ifdown.

local module = {}

local ifaces = {}

local function generate_content()
    local ret = ""

    for _, iface in ipairs(ifaces) do
        ret = ret .. iface.entry .. "\n"
    end

    return ret
end

local function write()
    local f       = io.open("/etc/network/interfaces", "w")
    local content = generate_content()

    f:write(generate_content())
    f:close()
end

function module.add_dhcp_iface(name)
    table.insert(ifaces, {
        name  = name,
        entry = "iface "..name.." inet dhcp\n"
    })
    write()
end

function module.add_static_iface(name, address, netmask)
    table.insert(ifaces, {
        name  = name,
        entry = "iface "..name.." inet static\n"..
                "\taddress "..address.."\n"..
                "\tnetmask "..netmask.."\n"
    })
    write()
end

return module
