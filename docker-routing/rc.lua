local unpack    = unpack or table.unpack -- Lua 5.1 compat
local router    = require("dnsmasq")
local interface = require("interface")
local ip        = unpack(require("proc_ip"))
local pxe       = require("pxe")
require("isorepository")

-- A FDQN you own so foo.domain is reserved for the Intranet services.
local domain = os.getenv("DOMAIN") or "domain.local"

-- Get the server hostname.
local f = io.open("/etc/hostname")
local self_hostname = f:read("*all*"):gmatch("([^\n]+)")()
f:close()

-- Add some \\ so gmatch don't bark on patterns.
local function escape_uri(uri)
    return uri:gsub("[.]", "\\.")
end

-- Define the role of each hardware interface (NICs).
local i_macs = {
    lan  = os.getenv("LAN_MAC" ),
    wan  = os.getenv("WAN_MAC" ),
    wlan = os.getenv("WLAN_MAC"),
}

-- It is necessary to have at least a local and wide interface.
assert(i_macs.wan and (i_macs.lan or i_macs.wlan), "Please setup the interfaces")

-- First, given half the hardware on this gateway doesn't
-- work properly and I don't want to secure it, disable IPv6.
ip.v6.conf.all.disable_ipv6 = 1

-- Begin to forward packets between interfaces.
ip.v4.ip_forward = 1

-- The WAN isn't managed by dnsmasq, but needs initialization anyway.
if i_macs.wan then
    interface {
        enabled = true,
        area    = "wide",
        mac     = i_macs.wan,
        role    = "wan",
        conf    = {
            -- Disable ping from the outside.
            icmp_echo_ignore_all = true
        },
    }
end

-- Enable the DHCP server on the LAN and Wifi (WLAN) NIC.
for i_type, i_mac in pairs { lan = i_macs.lan, wlan = i_macs.wlan } do
    interface {
        enabled   = true,
        area      = "local",
        role      = i_type,
        mac       = i_mac,
        conf      = {
            -- Allow ping so watchdog scripts can work.
            icmp_echo_ignore_all = false
        },
        -- Share the same range for the Wifi and Wired LAN.
        ranges_v4 = {{
            begin_v4   = "192.168.100.1",
            end_v4     = "192.168.100.250",
            netmask_v4 = "255.255.255.0",
            renew      = "72h"
        }},
    }
end

-- Always give an hostname to the router when the domain is set.
if i_macs.lan and domain and not self_hostname:find("localhost") then
    router:add_host {
        ipv4     = "192.168.100.1",
        hostname = self_hostname.."."..domain,
        expire   = "infinite",
        macs     = {
            i_macs.lan,
        },
    }
end

--#listen-address=::1,127.0.0.1,192.168.100.1
--router.config.expand_hosts = true

-- Enable the TFTP/PXE server to provision the devices.
pxe {
    enabled  = true,
    root     = "/tftp/",
    payloads = {"pxelinux.0"},
}

-- Called *after* the config is applied.
router.session.connect_signal("init", function()
    print("Configuring the interfaces, please wait...")

    -- Enable the firewall
    os.execute("iptables-apply")

    print("Interfaces configured!")
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
