--- This class models a phone devices.
--
-- The objects for this class are managed by the `directory` module.
local object = require("patchbay.object")
local transaction = require("patchbay._transaction")

local module = {}

local logger = require("patchbay.logging") {
    name = "device"
}

local params_whitelist = {
    ["password"    ] = true,
    ["vm-password" ] = true,
    ["extension"   ] = true,
}

--[[<include>
  <user id="1001">
    <params>
      <param name="vm-password" value="1001"/>
    </params>
    <variables>
      <variable name="toll_allow" value="domestic,international,local"/>
      <variable name="accountcode" value="1001"/>
    </variables>
  </user>
</include>]]

-- <!--<variable name="callgroup" value="techsupport"/>-->

local DEFAULT_PARAMS = {
    password = "$${default_password}"
}

local DEFAULT_VARIABLES = {
    user_context              = "default",
    outbound_caller_id_name   = "$${outbound_caller_name}",
    outbound_caller_id_number = "$${outbound_caller_id}",
}

--TODO make dynamic
local ipv4_address = nil

--- The device extension (non-routed phone number).
--
-- @property extension
-- @tparam string

function module:get_extension()
    return self._private.extension
end


--- The device accountcode (FreeSWITCH identifier).
--
-- @property accountcode
-- @tparam string

function module:get_accountcode()
    return self._private.accountcode
end

--- Which realm can change a toll.
-- @property toll_allow
-- @tparam table args
-- @tparam boolean args.domestic
-- @tparam boolean args.international
-- @tparam boolean args.area

function module:set_toll_allow(value)
    self._private.allow_toll = ""

    for k, v in pairs(value) do
        if v then
            self._private.allow_toll =  self._private.allow_toll
                .. (#self._private.allow_toll == 0 and "" or ",") .. k
        end
    end
end

function module:set_vm_password(value)
    self._private["vm-password"] = value
end

--- Bridge an existing call to this device.
-- @method bridge_call
-- @tparam patchbay.call c The call.

local function bridge_callback(...)
    --TODO
end

function module:bridge_call(c)
    ipv4_address = ipv4_address
        or transaction.async_freeswitch_call("getGlobalVariable", "local_ip_v4")

    logger:info("Bridging "..ipv4_address.." to "..self.extension)

    local args = {
        call_uuid     = c.uuid,
        local_gateway = "sofia/"..ipv4_address.."/"..self.extension
    }

    local external_gateway_path = "sofia/external/"..self.extension

    require("patchbay.session")._register_pending_bridge {
        sibling               = c,
        parent_uuid           = c.uuid,
        internal_gateway_path = args.local_gateway,
        external_gateway_path = external_gateway_path,
        local_gateway         = args.local_gateway,
        device                = self,
        destination           = self.extension,
    }

    transaction.detached_script(bridge_callback, "bridge_device.lua", args)

    --TODO check every few seconds, maybe the device is dead and we don't know
end

function module:_to_xml()
    local code = self._private.accountcode or self._private.extension

    assert(code, "The extension or accountcode property is required")

    local params = {}
    object.shallow_copy(params, DEFAULT_PARAMS)

    params.password = self._private.password or params.password
    params["vm-password"] = self._private["vm-password"]

    local vars = {}
    object.shallow_copy(vars, DEFAULT_VARIABLES)

    for k, v in pairs(self._private) do
        if not params_whitelist[k] then
            vars[k] = v
        end
    end

    local params_xml, vars_xml = {}, {}

    for k, v in pairs(params) do
        table.insert(params_xml, '            <param name="'..k..'" value="'..v..'"/>')
    end

    for k, v in pairs(vars) do
        table.insert(vars_xml, '            <variable name="'..k..'" value="'..v..'"/>')
    end

    return table.concat({
        '    <user id="'..code..'">',
        '        <params>',
                    table.concat(params_xml, "\n"),
        '        </params>',
        '        <variables>',
                    table.concat(vars_xml, "\n"),
        '        </variables>',
        '    </user>',
    }, "\n")
end

function module:_pre_reg(event)

end

function module:_reg_attempt(event)

end

function module:_reg(event)
    if self._private.state == "REG" then return end

    self:emit_signal("registered")

    self._private.state = "REG"
end

local function new(_, args)
    local ret = object{
        class = module
    }

    assert(args.extension, "The extension property is mandatory")

    object.apply_args(ret, args)

    for k,v in pairs(ret._private) do
    end

    return ret
end

return object.patch_table(module, {
    call       = new ,
    is_module = true,
    class     = module
})
