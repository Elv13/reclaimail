local unpack     = unpack or table.unpack -- Lua 5.1 compat
local router     = require("reclaim.routing.dnsmasq")
local interfaces = require("reclaim.routing.interfaces")
local ip         = unpack(require("reclaim.routing.proc_ip"))
local pxe        = require("reclaim.routing.pxe")
local devices    = require("reclaim.routing.devices")
local lease      = require("reclaim.routing.lease")
local database   = require("database")

require("reclaim.routing.isorepository")
require("reclaim.routing.firewall")

-- A FDQN you own so foo.domain is reserved for the Intranet services.
local domain = os.getenv("DOMAIN") or "domain.local"

local subnet_begin, subnet_end = "192.168.100.1", "192.168.100.255"
local netmask = "255.255.255.0"

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
    lan  = os.getenv("LAN_MAC" ) ~= "" and os.getenv("LAN_MAC" ) or nil,
    wan  = os.getenv("WAN_MAC" ) ~= "" and os.getenv("WAN_MAC" ) or nil,
    wlan = os.getenv("WLAN_MAC") ~= "" and os.getenv("WLAN_MAC") or nil,
}

-- It is necessary to have at least a local and wide interface.
assert(i_macs.wan and (i_macs.lan or i_macs.wlan), "Please setup the interfaces")

-- First, given half the hardware on this gateway doesn't
-- work properly and I don't want to secure it, disable IPv6.
ip.v6.conf.all.disable_ipv6 = 1

-- Begin to forward packets between interfaces.
ip.v4.ip_forward = 1

-- Persist the leases outside of the container.
database.leases.path = "/etc/dnsmasq.leases"
database.hosts.path = "/etc/dnsmasq.hosts"

-- The WAN isn't managed by dnsmasq, but needs initialization anyway.
if i_macs.wan then
    interfaces.wan {
        enabled = true,
        mac     = i_macs.wan,
        conf    = {
            -- Disable ping from the outside.
            icmp_echo_ignore_all = true
        },
    }
end

-- Enable the DHCP server on the LAN and Wifi (WLAN) NIC.
for i_type, i_mac in pairs { lan = i_macs.lan, wlan = i_macs.wlan } do
    interfaces.lan {
        enabled   = true,
        role      = i_type,
        mac       = i_mac,
        conf      = {
            -- Allow ping so watchdog scripts can work.
            icmp_echo_ignore_all = false
        },
        -- Share the same range for the Wifi and Wired LAN.
        ranges_v4 = {{
            begin_v4   = subnet_begin,
            end_v4     = subnet_end,
            netmask_v4 = netmask,
            renew      = "72h"
        }},
    }
end

-- Always give an hostname to the router when the domain is set.
if i_macs.lan and domain and not self_hostname:find("localhost") then
    database.hosts:add_host {
        ipaddr     = subnet_begin,
        hostname   = self_hostname.."."..domain,
        lease_time = "infinite",
        hwaddr     = {
            i_macs.lan,
        },
    }
end

-- Enable the TFTP/PXE server to provision the devices.
pxe {
    enabled  = true,
    root     = "/tftp/",
    payloads = {"pxelinux.0"},
}

-- Raspberri Pi specific options to enable PXE
router.add_dhcp_option(66, subnet_begin)
router.add_dhcp_option(43, "Raspberry Pi Boot")

-- Called *after* the config is applied.
router.session.connect_signal("init", function()
    print("Interfaces configured!")
end)

-- If the hostname claims to be in the domain, then bind the address and add
-- it to the DNS.
router.leases.connect_signal("property::hostname", function(lease, old_host)
    print("==> New hostname:", lease.hostname, old_host)

    if lease.hostname:gmatch("("..escape_uri(domain)..")$") then
        lease:bind()
        lease.host:bind()
    end
end)

-- Always bind all IPs to their Mac address by default.
router.leases.connect_signal("leases::created", function(lease)
    print("==> New lease created for", lease.address)

    -- This will polute the namespace **FAST** on public network,
    -- but for private "wired" network, this is fine.
    lease:bind()
end)

-- Purge older bound Mac addresses when space is running out.
router.ethers.connect_signal("added", function(pair)
    if pairs.count > 230 then
        --TODO purge /etc/ethers from entries not in /etc/hosts
    end
end)

-- Default PXE menu.
local default_ipxe = devices.generic_pc.syslinux.menu {
    compat       = true,
    title        = "Reclaim routing",
    timeout      = 10,
    save_default = false,
    menu_type    = "basic",
    background   = 44, -- blue
    entries      = {
        devices.generic_pc.syslinux.chainload {
            drive     = 1,
            partition = 0,
        },
        devices.generic_pc.syslinux.chainload {
            drive     = 2,
            partition = 0,
        },
        devices.generic_pc.syslinux.clonezilla {
            --default      = true,
            export_lease = false,
            label        = "Clonezilla",
        },
        devices.generic_pc.syslinux.gparted {
            default      = true,
            export_lease = false,
            label        = "GParted",
        },
        devices.generic_pc.syslinux.linux {
            export_lease = false,
            label        = "Ubuntu 20.04",
            root         = "nfs://192.168.100.1:/pxe/ubuntu2004/",
            quiet        = false,
        },
    },
}

router.tftp_files.connect_signal("file::lookup", function(lease, file)
    -- Create a PC device if an UEFI or BIOS PC tries to PXE boot.
    if file.path == "pxelinux.0" and not lease.device then
        lease.device = devices.generic_pc {
            syslinux_menu = default_ipxe,
            mac_address   = lease.mac_address,
            lease         = lease,
            syslinux      = default_ipxe
        }
    end
end)

-- Test Raspberry Pi 4
local rpi = devices.raspberry_pi {
    --tftp_root   = "pi_minimal",
    generation  = 4,
    mac_address = "dc:a6:32:e3:d6:dc",
    lease       = lease {
        ipv4 = "10.10.10.216",
    },
    consoles = {
        devices.raspberry_pi.console {
            output = "tty1",
        },
        devices.raspberry_pi.console {
            output = "serial0",
            baud   = 115200
        },
    },
    outputs = {
        devices.raspberry_pi.output.tv {
            enabled = true,
            mode    = devices.raspberry_pi.output.tv.modes.NTSC,
            ratio   = devices.raspberry_pi.output.tv.ratios.R4_3,
        },
        devices.raspberry_pi.output.hdmi {
            enabled = true,
            port    = 1,
        },
    },
    audio = devices.raspberry_pi.audio {
        enabled = true,
    },
    --device_tree = "/tftp/pi_minimal/bcm2711-rpi-4-b-UPSTREAM.dtb",
    --kernel      = "/tftp/pi_minimal/kernel.img",
    cmdline     = {
        kernel      = "path/to/kernel",
        init        = "script.sh",
        enable_uart = true,
    }
}

router.add_device(rpi)

