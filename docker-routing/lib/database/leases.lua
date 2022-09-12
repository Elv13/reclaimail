local dnsmasq = require("reclaim.routing.dnsmasq")
local objects = require("reclaim.routing.objects")
local base    = require("reclaim.routing.database._base")

local class, _path = {}, nil

function class.set_path(path)
    _path = path
    dnsmasq["dhcp-leasefile"] = _path
end

function class.get_path()
    return _path
end

local module = objects {
    class             = true,
    enable_properties = true
}

objects.add_class(module, class)

return module
