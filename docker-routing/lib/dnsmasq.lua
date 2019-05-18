--!/usr/bin/lua

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
local hosts, saved_hosts = create_object(), {}
local ethers, saved_ethers = create_object(), {}

local map = {
    add = "created", old = "renewed", del = "expired"
}

-- Called when a lease is created, expired or renewed
function lease(event, args)
    local l = leases_by_mac[args.mac_address] or create_object {
        class = leases,
    }

    if not l.created then
        l.created = os.date("%s")
    end

    l.renewed = os.date("%s")
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

local session = create_object()

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
        if l:sub(1,6) == "#meta:" then
            local k, v = decode_metadata(l)
            metadata[k] = v
        else
            local ip = l:match("^[^ ]+")

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

return {
    leases     = leases,
    hosts      = load_hosts(),
    tftp_files = tfiles,
    arp        = {},
    session    = session,
    ethers     = load_eithers(),
}
