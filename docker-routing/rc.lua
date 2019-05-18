local unpack = unpack or table.unpack -- Lua 5.1 compat

-- Higher level binding to create objects from
-- the callbacks paramaters.
local router = require("dnsmasq")

-- Binding for /proc/sys/net to be able to read and write
-- the config.
local ip, interfaces = unpack(require("proc_ip"))

-- A table with a `lan` and `wan` key and interface name as value.
local i_name = {}

-- A FDQN you own so foo.domain is reserved for the Intranet services.
local domain = os.getenv("DOMAIN") or "domain.local"

-- Add some \\ so gmatch don't bark on patterns.
local function escape_uri(uri)
    return uri:gsub("[.]", "\\.")
end

-- Called *after* the config is applied.
router.session.connect_signal("init", function()
    print("Configuring the interfaces, please wait...")

    -- First, given half the hardware on this gateway doesn't
    -- work properly and I don't want to secure it, disable IPv6.
    ip.v6.conf.all.disable_ipv6 = 1

    -- This Lua file is expected to be used in Docker with some
    -- variables set by the host when starting the container.
    local i_mac = {
        lan  = os.getenv("LAN_MAC" ), 
        wan  = os.getenv("WAN_MAC" ),
        wlan = os.getenv("WLAN_MAC"),
    }

    -- Find the interface names for the Mac addresses
    for i, conf in pairs(interfaces) do
        local ma = conf.address:gmatch("([^\n]+)")()
        assert(ma, "This script expect /sys/class/net to exist")

        for i_type, m in pairs(i_mac) do
            if m == ma then
                i_name[i_type] = i
            end
        end
    end

    -- Routing only works with at least 2 interfaces
    assert(i_name.lan and i_name.wan)

    -- WAN (DHCP)
    os.execute("ifup "..i_name.wan)

    -- LAN (static)
    os.execute("ifup "..i_name.lan)

    -- Enable the firewall
    os.execute("iptables-apply")

    -- Enable routing between the interfaces
    ip.v4.ip_forward = 1

    -- Disable ping on the WAN, enable on LAN
    ip.v6.conf[i_name.wan].icmp_echo_ignore_all = 1
    ip.v6.conf[i_name.lan].icmp_echo_ignore_all = 0

    print("Interfaces configured!")
end)

router.session.connect_signal("shutdown", function()
    print("LUA SHUTDOWN")

    --TODO serialize some stuff
end)

-- If the hostname claims to be in the domain, then bind the address and add
-- it to the DNS.
router.leases.connect_signal("property::hostname", function(lease, old_host)
    print("LUA HOSTNAME", lease.hostname, old_host)

    if lease.hostname:gmatch("("..escape_uri(domain)..")$") then
        lease:bind()
        lease.host:bind()
    end
end)

-- Always bind all IPs to their Mac address by default.
router.leases.connect_signal("leases::created", function(lease)
    print("LUA NEW LEASE", lease.address)

    -- This will polute the namespace **FAST** on public network,
    -- but for private "wired" network, this is fine.
    lease:bind()
end)

-- Purge older binded Mac addresses when space is running out.
router.ethers.connect_signal("added", function(pair)
    if pairs.count > 230 then
        --TODO purge /etc/ethers from entries not in /etc/hosts
    end
end)
