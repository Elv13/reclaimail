-- This file is a temporary wrapper around iptables until
-- bpfilter matures in the kernel.
local dnsmasq = require("reclaim.routing.dnsmasq")

local module = {}

local rules = {}

local function load_template(name)
    local rtmpl = io.open("/iptables_template/"..name..".rules", "r")
    local routing = rtmpl:read("*all*")
    rtmpl:close()

    --TODO support multiple LAN/WLAN
    local wan = dnsmasq.interfaces.by_area["wide" ][1]._args.name
    local lan = dnsmasq.interfaces.by_area["local"][1]._args.name
    assert(wan and lan)

    routing = routing:gsub("WAN_TEMPLATE", wan)
    routing = routing:gsub("LAN_TEMPLATE", lan)

    return routing
end

-- Create the full content of the rules.
local function build_rules()
    local ret = {}

    for _, rule in ipairs(rules) do
        table.insert(ret, rule)
    end

    table.insert(ret, "COMMIT\n")

    return table.concat(ret, "\n\n")
end

local function flush()
    os.execute("iptables -F")
end

local function apply()
    local out = io.open("/etc/network/iptables", "w")
    out:write(build_rules())
    out:close()
    os.execute("bash -c 'iptables-restore < /etc/network/iptables'")
end

function module.forward()
    --TODO
end

-- Reset the rules after each interface change.
dnsmasq.session.connect_signal("interface::added", function()
    local areas = dnsmasq.interfaces.by_area
    -- There is no point of adding until there is a WAN and LAN.
    -- Worst case scenario is that there is no LAN and all traffic
    -- is open on the WAN.
    if not areas["wide" ] then return end
    if (not areas["local"]) and (not areas["wlan"]) then return end

    rules = {}

    table.insert(rules, load_template "routing")

    apply()
end)

return module
