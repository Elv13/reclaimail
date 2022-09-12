local create_object = require("reclaim.routing.object")
local database = require("reclaim.routing.database")

local class = {}

local module = create_object { class = true }

--[[

"client_duid"       STRING IP6 only
"server_duid"       STRING IP6 only
"iaid"              STRING IP6 only
"client_id"         STRING IP4 only
"interface"         STRING
"lease_length"      NUMBER (deprecated)
"lease_expires"     NUMBER
"hostname"          STRING
"domain"            STRING
"vendor_class"      STRING IP4 OPTIONAL
"supplied_hostname" STRING  OPTIONAL
"cpewan_oui"        STRING IP4 OPTIONAL
"cpewan_serial"     STRING IP4 OPTIONAL
"cpewan_class"      STRING IP4 OPTIONAL
"circuit_id"        STRING IP4 OPTIONAL
"subscriber_id"     STRING IP4 OPTIONAL
"remote_id"         STRING IP4 OPTIONAL
"tags"              STRING OPTIONAL
"relay_address"     STRING IP6 OPTIONAL
"relay_address"     STRING IP4
"time_remaining"    NUMBER
"old_hostname"      STRING
"mac_address"       STRING IP4
"ip_address"        STRING IP4

--]]

function module:_update(event, data)
    if data.old_hostname then
        self.hostname = data.hostname
        self:emit_singal("property::hostname", data.hostname, data.old_hostname)
        table.insert(self._private.previous_hostname, data.old_hostname)
    end

    local vendors, users = {}, {}
    local i = 0

    while data["vendor_class"..i] do
        table.append(vendors, data["vendor_class"..i])
        data["vendor_class"..i] = nil
        i = i + 1
    end

    i = 0

    while data["user_class"..i] do
        table.append(users, data["user_class"..i])
        data["user_class"..i] = nil
        i = i + 1
    end

    data.vendor_classes = vendors
    data.user_classes = users

    create_object.apply_args(ret, args, {}, nil)
end

-- Called by dnsmasq.lua
function module._create_existing(args)
    local ret = create_object {enable_properties = true}
    ret._private.tfiles_by_path = {}
    ret._private.previous_hostname = {}
    ret._private.class = module

    create_object.add_class(ret, module)

    ret:_update("created", args)

    return ret
end

function class:persist()
    database.hosts._persist(self)
end

local function new()
    --
end

local mt = getmetatable(module)

mt.__call = new

return module
