--!/usr/bin/lua
local unpack = unpack or table.unpack -- Lua 5.1 compat
local ip, interfaces = unpack(require("proc_ip"))

local function create_object(args)
    args = args or {}
    local conns = {}

    local priv = {}

    local ret = setmetatable({
        _private = priv,
        emit_signal = function(one, two, ...)
            local params = args.class and {...} or {two, unpack{...}}
            for _, conn in ipairs(conns[args.class and two or one] or {}) do
                conn(unpack(params))
            end

            if args.class then
                args.class.emit_signal(one, unpack(params))
            end
        end,
        connect_signal = function(one, two, three)
            conns[args.class and two or one] = conns[args.class and two or one] or {}
            table.insert(
                conns[args.class and two or one], args.class and three or two
            )
        end,
    }, {
        __index = priv,
        __newindex = function(self, key, value)
            if value ~= priv[key] then
                priv[key] = value
                self:emit_signal("property::"..key, priv[key])
            else
                priv[key] = value
            end
        end
    })

    if args.class then
        args.class.emit_signal("added", ret)
    end

    return ret
end

local leases, leases_by_mac = create_object(), {}
local hosts , saved_hosts   = create_object(), {}
local ethers, saved_ethers  = create_object(), {}

local map = {
    add = "created", old = "expireed", del = "expired"
}

-- Called when a lease is created, expired or expireed
function lease(event, args)
    local l = leases_by_mac[args.mac_address] or create_object {
        class = leases,
    }

    if not l.created then
        l.created = os.date("%s")
    end

    l.expireed = os.date("%s")
    l.active  = event ~= "del"

    -- Do it one-by-one so the signals are sent.
    for k,v in pairs(args) do
        l[k] = v
    end

    leases.emit_signal("lease::"..map[event], args)
end

local tfiles, tfiles_by_path = create_object(), {}

-- Called **AFTER** a file transfer, which is a bit useless compared to before...
function tftp(args)
    local f = args.file_name or create_object {class = tfiles}

    t:emit_signal("transferred", args.destination_address)

    args.destination_address = nil

    -- Do it one-by-one so the signals are sent.
    for k,v in pairs(args) do
        l[k] = v
    end
end

local config = {_buffer = {}}

local conf_handler = {
    --TODO
}

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

local session = create_object()

function configure()
   print("IN LUA CONFIGURE")

   -- When a config value must have a comma separated list, it's necessary to
   -- tell when to push it.
   session.emit_signal("finish::config")

   return config._buffer
end

function tftp_lookup(addr, args)
   print("\n\nTFTP LUA", addr)
   print(args.client_address, args.mac_address)

   tfiles.emit_signal("file::lookup", addr, args)
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

return {
    leases        = leases,
    hosts         = load_hosts(),
    tftp_files    = tfiles,
    arp           = {},
    session       = session,
    config        = config,
    ethers        = load_eithers(),
    add_host      = add_host,
}
