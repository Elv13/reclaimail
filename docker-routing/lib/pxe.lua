
local dnsmasq = require("reclaim.routing.dnsmasq")
local module = {}

local methods = {}

local payloads = {}

dnsmasq.config.dhcp_boot   = "pxelinux.0"
dnsmasq.config.enable_tftp = true

function module:add_boot_payload(p)
    table.insert(payloads, p)
end

function module:enable()
    dnsmasq.config.enable_tftp = true
end

function methods:set_root(v)
    dnsmasq.config.tftp_root = v
    dnsmasq._tftp_root = v
end

function methods:set_enabled(v)
    if v then
        module:enable()
    end
end

function methods:set_payloads(pl)
    for _, p in ipairs(pl) do
        table.insert(payloads, p)
    end
end

-- This is a singleton, this metamethod call is just syntax sugar.
local function setup(_, args)
    for k, v in pairs(args) do
        if methods["set_"..k] then
            methods["set_"..k](module, v)
        end
    end

    return module
end

-- Make sure the lists are generated en time.
dnsmasq.session.connect_signal("finish::config", function()
    local dhcp_boot = ""

    for _, p in ipairs(payloads) do
        dhcp_boot = dhcp_boot .. (dhcp_boot ~= "" and "," or "") .. p
    end

    dnsmasq.config.dhcp_boot = dhcp_boot
end)

return setmetatable(module, {__call = setup})
