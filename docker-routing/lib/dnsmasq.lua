--!/usr/bin/lua
local unpack = unpack or table.unpack -- Lua 5.1 compat
local ip = unpack(require("reclaim.routing.proc_ip"))
local devices = require("reclaim.routing.devices._base")
local utils = require("reclaim.routing.utils")
local lease_obj = require("reclaim.routing.lease")
local create_object = require("reclaim.routing.object")

local leases, leases_by_mac = create_object(), {}
local hosts , saved_hosts   = create_object(), {}
local ethers, saved_ethers  = create_object(), {}
local device_objs = {}
local interfaces = {
    by_name = {},
    by_mac  = {},
    by_area = {}
}

local map = {
    add = "created", old = "renew", del = "expired"
}

local module = {
    _tftp_root = nil
}

local function get_lease(args)
    leases_by_mac[args.mac_address] = leases_by_mac[args.mac_address]
        or lease_obj._create_existing(args)

    return leases_by_mac[args.mac_address]
end

-- Called when a lease is created, expired or expireed
local function real_lease(event, args)
    if args.mac_address then
        local l = get_lease(args)

        if not l.created then
            l.created = os.time()
        end

        --l.expired = os.time()
        l.active  = event ~= "del"

        if event == "del" then
            -- leases_by_mac[args.mac_address] = nil
        end

        l:_update(map[event], args)

        leases.emit_signal("lease::"..map[event], args)
    end
end

function lease(...)
    real_lease(...)
    assert(next(leases_by_mac))
    --xpcall(real_lease, function(err) debug.traceback("Lease failure: "..err) end, ...)
end

local tfiles = create_object { class = true }

-- Called **BEFORE** Dnsmask check for the file on the disk.
local function real_tftp_lookup(path, args)
    -- It can happen if dnsmasq was just restarted or if there is
    -- spoofed requests.
    if not args.lease then return end

    local l, obj, l_files = get_lease(args.lease), nil, nil

    if l then
        assert(l, "Cannot find lease for " .. args.lease.mac_address)

        l_files = l._private.tfiles_by_path

        obj = l_files[path]
    end

    if not obj then
        obj = create_object {
            class = tfiles
        }

        -- Remove the prefix. Otherwise everything will need to know
        -- the prefix.
        obj.path = path

        if l then
            l_files[path] = obj
        end
    end

    local content = {}

    tfiles.emit_signal("file::lookup", l, obj, nil, content)

    -- Find all applicable devices in accordance to the PXE spec.
    local all_devs = {}
    for _, addr in ipairs(utils.hwaddr_to_sequ(args.lease.mac_address)) do
        for _, dev in ipairs(devices._device_by_mac[addr] or {}) do
            all_devs[dev] = true
        end
    end

    if l and l.device then
        all_devs[l.device] = true
    end

    -- Find all device objects and send the signals.
    for device in pairs(all_devs) do
        device:emit_signal("file::lookup", obj, nil, content)
    end

    if l then
        l:emit_signal("file::lookup",  obj, nil, content)
    end

    for k, v in pairs(content) do --FIXME
        return v, k
    end

end

function tftp_lookup(...)
    local ret = {
        xpcall(real_tftp_lookup, function(err) print(debug.traceback("TFTP lookup failure"), err) end, ...)
    }

    if not ret[1] then
        return
    else
        return ret[2], ret[3]
    end
    --return select(2, xpcall(real_tftp_lookup, function() debug.traceback("TFTP lookup failure") end, ...))

--     local moo = [[
-- UI menu.c32
-- PROMPT 0
--
-- MENU TITLE Boot Menu
-- TIMEOUT 50
-- DEFAULT arch
--
-- LABEL arch2
--         MENU LABEL Arch Linux
--         LINUX ../vmlinuz-linux
--         APPEND root=/dev/sda2 rw
--         INITRD ../initramfs-linux.img
--
-- LABEL archfallback2
--         MENU LABEL Arch Linux Fallback
--         LINUX ../vmlinuz-linux
--         APPEND root=/dev/sda2 rw
--         INITRD ../initramfs-linux-fallback.img
--
-- ]]

    -- local path, args = table.unpack({...})
    -- print("PATH", path)
    -- if path == "pxelinux.cfg/default" then
    --     return moo, true
    -- end

end


-- Called **AFTER** a file transfer, which is a bit useless compared to before...
local function real_tftp(args)
    if args == "failure" then return end --TODO
    if args == "tftp" then return end --TODO

    local f = args.file_name or create_object {class = tfiles}

    tfiles.emit_signal("file::transferred", args.destination_address)

    args.destination_address = nil

    -- Do it one-by-one so the signals are sent.
    for k,v in pairs(args) do
        l[k] = v
    end
end

function tftp(...)
    xpcall(real_tftp, function(err) print(debug.traceback("TFTP failure"), err) end, ...)
end


local config = {_buffer = {}}

local conf_handler = {
    --TODO
}

function conf_handler:tftp_root(value)
    tftp_root = value
    return "tftp-root="..value
end

setmetatable(config, {
    __newindex = function(_, key, value)
        local t = type(value)
        local fixed_key = key:gsub("_", "-")

        if t == "boolean" then
            table.insert(config._buffer, fixed_key)
        elseif t == "string" or t == "number" then
            table.insert(config._buffer, fixed_key.."="..value)
        elseif t == "table" then
            assert(conf_handler[key])
            table.insert(config._buffer, fixed_key, conf_handler[key](value))
        end
    end
})

local session = create_object {class = true}

-- Make it easier to track interfaces from other modules.
session.connect_signal("interface::added", function(i)
    local area, name, mac = i._args.area, i._args.name, i._args.mac
    interfaces.by_area[area] = interfaces.by_area[area] or {}
    table.insert(interfaces.by_area[area], i)

    if name then
        interfaces.by_name[name] = i
    end

    interfaces.by_mac[mac] = i
end)

function configure()
   -- When a config value must have a comma separated list, it's necessary to
   -- tell when to push it.
   session.emit_signal("finish::config")

   return config._buffer
end

function init()
    session.emit_signal("init")
end

function shutdown()
    session.emit_signal("shutdown")
end

function arp_old(args)

end

-- The doc claims the function is called "arp-old", I have doubt and didn't test,
-- but I do as the doc says.
_G["arp-old"] = arp_old

-- Parse /etc/hosts and /etc/ethers.
-- Allow a machine parsable meta tag for database information.
local function parse(path)
    local ret = {}

    local f = io.open(path)

    if not f then return {} end

    for l in function() return f:read("*line*") end do
        if l:sub(1,1) ~= "#" or l:sub(1,6) == "#meta:" then
            table.insert(ret, l)
        end
    end

    return ret
end

local function decode_metadata(md)
    return md:match("meta:[ ]*([^ =]+)"), md:match("=[ ]*(.+)$")
end

local function load_hosts()
    local db = parse("/etc/hosts")

    local metadata = {}

    for _, l in ipairs(db) do
        local ip = l:match("^[^ ]+")

        if l:sub(1,6) == "#meta:" then
            local k, v = decode_metadata(l)
            metadata[k] = v
        elseif ip then

            for host in l:gmatch(" ([^ ]+)") do
                local h = hosts[host] or create_object{class = hosts}

                h.ip    = ip
                h.saved = true

                for k, v in pairs(metadata) do
                    h[k] = v
                end
            end

            saved_hosts[ip] = saved_hosts[ip] or {}

            table.insert(saved_hosts[ip], h)

            metadata = {}
        end
    end

    return hosts
end

local function load_eithers()
    local db = parse("/etc/ether")

    local metadata = {}

    for _, l in ipairs(db) do
        if l:sub(1,6) == "#meta:" then
            local k, v = decode_metadata(l)
            metadata[k] = v
        else
            local mac, ip = l:match("^[^ ]+"), l:match(" ([^ ]+)")

            local e = ethers[ip] or create_object{class = ethers}

            ethers[ip] = e

            for k, v in pairs(metadata) do
                e[k] = v
            end

            table.insert(saved_ethers[mac], e)

            metadata = {}
        end
    end

    return ethers
end

local i_mac = {
    lan  = os.getenv("LAN_MAC" ),
    wan  = os.getenv("WAN_MAC" ),
    wlan = os.getenv("WLAN_MAC"),
}

local function add_host(args)
    --syntax: mac1,mac2..macn,hostname,ipv4,expire

    local host = ""

    for _, mac in ipairs(args.macs or {}) do
        host = host .. mac .. ","
    end

    if args.hostname then
        host = host .. args.hostname .. ","
    end

    if args.ipv4 then
        host = host .. args.ipv4 .. ","
    end

    if args.expire then
        host = host .. args.expire
    end

    table.insert(config._buffer, "dhcp-host="..host)

    --TODO all the other options and magic values
end

local function add_dhcp_option(option, value)
    table.insert(config._buffer, "dhcp-option="..option..","..value)
end

-- It only prevents the garbage collection...
local function add_device(dev)
    table.insert(device_objs, dev)
end

module.leases          = leases
module.interfaces      = interfaces
module.hosts           = load_hosts()
module.tftp_files      = tfiles
module.arp             = {}
module.session         = session
module.config          = config
module.ethers          = load_eithers()
module.add_host        = add_host
module.add_dhcp_option = add_dhcp_option
module.add_device      = add_device

return module
