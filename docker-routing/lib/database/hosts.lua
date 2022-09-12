--- This module manages /etc/hosts and /etc/dnsmasq.hosts
--
-- /etc/hosts maps IP addresses to hostnames
-- /etc/dnsmasq.hosts maps MAC addresses to IPs *and* hostnames
--
-- /etc/dnsmasq.hosts is a superset of /etc/ethers and /etc/hosts.
-- It is also the "static" version of /etc/dnsmasq.leases
--
-- In the long run, this module will be low-level and the `lease`
-- class would be the high level API to manage the database.
local dnsmasq = require("reclaim.routing.dnsmasq")
local base    = require("reclaim.routing.database._base")
local objects = require("reclaim.routing.objects")
local ethers  = require("reclaim.routing.database.ethers")

local class = {}

local entries, entries_by_hwaddr, path = nil, {}, nil
local  hosts, hosts_by_ip = nil, {}

local function parse_entry(str)
    local ret = {}

    -- Format:
    --[<hwaddr>][,id:<client_id>|*][,set:<tag>][tag:<tag>]
    --[,<ipaddr>][,<hostname>][,<lease_time>][,ignore]

    local parts = {}

    for part in str:gmatch("([^,]+)") do
        table.insert(parts, part)
    end

    ret.hwaddr = table.remove(parts, 1)

    -- Get all optional extra elements
    repeat
        local key, value = parts[1]:match("([a-z]+):(.*)")

        if key then
            table.remove(parts, 1)
            ret[key] = value
        end
    until(not key)

    ret.ipaddr     = table.remove(parts, 1)
    ret.hostname   = table.remove(parts, 1)
    ret.lease_time = table.remove(parts, 1)
    ret.ignore     = table.remove(parts, 1)

    return ret
end

local function serialize(args)
    local host = ""

    local hwaddr = type(args.hwaddr) == "string" and {args.hwaddr} or args.hwaddr or {}

    for idx, mac in ipairs(hwaddr) do
        host = host .. mac .. (idx ~= #hwaddr and "," or "")
    end

    if args.hostname then
        host = host .. args.hostname .. ","
    end

    for _, extra in ipairs {"is", "set", "tag" } do
        if args[extra] then
            host = host .. extra .. ":" .. args[extra] .. ","
        end
    end

    if args.ipaddr then
        host = host .. args.ipaddr .. ","
    end

    if args.expire then
        host = host .. args.expire
    end

    return host
end

local function load_entries()
    if not path then return end

    if entries then return entries end

    local lines = base.parse(path)

    entries = {}

    for _, line in ipairs(lines) do
        local entry = parse_entry(line)
        table.insert(entries, entry)
        entries_by_hwaddr[entry.hwaddr] = entry
    end

    return entries
end

local function load_hosts()
    if hosts then return hosts end

    local lines = base.parse("/etc/hosts")

    hosts = {}

    for line in ipairs(lines) do
        local parts = {}

        for part in line:gmatch("([^ ]+)") do
            table.insert(parts, part)
        end

        if line:sub(1,1) == "#" or line == "" then
            table.insert(hosts, line)
        else
            local ip = table.remove(parts, 1)
            hosts_by_ip[ip] =  hosts_by_ip[ip] or {}

            for _, host in ipairs(parts) do
                hosts_by_ip[ip][host] = true
            end
            table.insert(hosts, {ip=ip, hostnames = hosts_by_ip[ip]})

        end

    end
end

local function serialize_hosts()
    -- Nothing changed.
    if not hosts then return end

    -- Some ips can have multiple line. They will be merged.
    -- This can have the side effect of messing with comments.
    local saved = {}

    local f = io.open("/etc/hosts", "w")

    for _, line in ipairs(hosts) do
        if type(line) == "string" then
            f:write(line .. "\n")
        else
            if not saved[line.ip] then
                local names = {}

                for name in pairs(line.hostnames) do
                    table.insert(names, name)
                end

                table.sort(names)

                f:write(line.ip .. " " .. table.concat(names, " "))
            end
        end
    end

    f:close()
end

--- Add a static host.
--
-- @function database.hosts.add_host
-- @tparam table args
-- @tparam string args.hostname
-- @tparam string args.ipaddr
-- @tparam string args.hwaddr
-- @tparam string args.set
-- @tparam string args.tag
-- @tparam string args.id
-- @tparam string args.ignore
-- @tparam number|string args.lease_time Number in seconds or "infinite".
-- @tparam boolean args.persistent
function class.add_host(args)
    --syntax: mac1,mac2..macn,hostname,ipv4,expire

    local host = serialize(args)

    table.insert(dnsmasq.config._buffer, "dhcp-host="..host)

    -- Load the database to check for duplicates
    if not entries then
        load_entries()
    end

    if not hosts then
        load_hosts()
    end

    local refresh = false

    --TODO support changing the hostname
    if args.persistent and path and not entries_by_hwaddr[args.hwaddr] then
        base.append(path, host)
        refresh = true

        if args.hostname and args.hwaddr then
            ethers.add_ether(args)
        end
    end

    if args.expose and args.ipaddr and args.hostname then

        if not (hosts_by_ip[args.ipaddr] or {})[args.hostname] then

            if hosts_by_ip[args.ipaddr] then
                hosts_by_ip[args.ipaddr][args.hostname] = true
                serialize_hosts()
            else
                hosts_by_ip[args.ipaddr] = {}
                hosts_by_ip[args.ipaddr][args.hostname] = true
                base.append("/etc/hosts", args.ipaddr .. " " .. args.hostname)
            end

            refresh = true
        end
    end

    if refresh then
        base.refresh()
    end
end

function class._persist(lease)
    local args = {
        ipaddr   = lease.ip_address,
        hwaddr   = lease.mac_address,
        hostname = lease.hostname,
        id       = lease.client_id,
    }

    class.add_host(args)
end

function class.set_path(_path)
    path = _path
    dnsmasq["dhcp-leasefile"] = _path
end

function class.get_path()
    return path
end

local module = objects {
    class             = true,
    enable_properties = true
}

objects.add_class(module, class)

return module
