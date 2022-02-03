local object       = require("patchbay.object")
local registered   = require("patchbay.directory.registered")
local sip_accounts = require("patchbay.directory.sip_accounts")

local CONF_HEADER = [[<configuration name="directory.conf" description="Directory">
  <settings>
  </settings>
  <profiles>
    <profile name="default">]]

local CONF_DEFAULTS = {
      ["max-menu-attempts"] = "3",
      ["min-search-digits"] = "3",
      ["terminator-key"] = "#",
      ["digit-timeout"] = "3000",
      ["max-result"] = "5",
      ["next-key"] = "6",
      ["prev-key"] = "4",
      ["switch-order-key"] = "*",
      ["select-name-key"] = "1",
      ["new-search-key"] = "3",
      ["search-order"] = "last_name",
}

local CONF_FOOTER = [[
    </profile>
  </profiles>
</configuration>
]]

local DIR_HEADER = [[
<domain name="$${domain}">
    <params>
      <param name="dial-string" value="{^^:sip_invite_domain=${dialed_domain}:presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})},${verto_contact(${dialed_user}@${dialed_domain})}"/>
      <!-- These are required for Verto to function properly -->
      <param name="jsonrpc-allowed-methods" value="verto"/>
      <!-- <param name="jsonrpc-allowed-event-channels" value="demo,conference,presence"/> -->
    </params>

    <variables>
      <variable name="record_stereo" value="true"/>
      <variable name="default_gateway" value="$${default_provider}"/>
      <variable name="default_areacode" value="$${default_areacode}"/>
      <variable name="transfer_fallback_extension" value="operator"/>
    </variables>

    <groups>
      <group name="default">
        <users>
]]

--<X-PRE-PROCESS cmd="include" data="default/*.xml"/>

local DIR_FOOTER = [[        </users>
      </group>
    </groups>
</domain>
]]

local module = {}

local dids, did_by_phonenumber, did_by_gateway = {}, {}, {}

function module.get_all_devices()
    return sip_accounts._get_devices()
end

function module.get_device_by_accountcode(ac)
    return sip_accounts.get_by_accountcode(ac)
end

function module.get_device_by_extension(ac)
    return sip_accounts.get_by_extension(ac)
end

function module.add_device(device)
    sip_accounts.add(device)
end

function module.add_did(did)
    table.insert(dids, did)
    did_by_phonenumber[did.phone_number] = did

    if did._private.gateway_name then
        did_by_gateway[did._private.gateway_name] = did
    end
end

function module._get_did(ext)
    return did_by_phonenumber[ext] or did_by_gateway[ext]
end

function module._get_dids() --TODO remove
    return dids
end

function module.get_dids()
    return dids
end

function module.get_registered_devices()
    return registered.get_registered_devices()
end

function module.get_preferred_did(args)
    args = args or {}

    if args.country then
        for _, did in ipairs(dids) do
            if did.bias_country == args.country and did.state == "REGED" then
                return did
            end
        end
    end

    for _, did in ipairs(dids) do
        if  did.state == "REGED" then
            return did
        end
    end
end

function module._to_xml()
    local dev_xml = {}

    for _, dev in ipairs(sip_accounts._get_devices()) do
        table.insert(dev_xml, dev:_to_xml())
    end

    return table.concat({
        DIR_HEADER,
        table.concat(dev_xml, "\n"),
        DIR_FOOTER
    }, "\n")
end

return object.patch_table(module, {
    class     = module,
    is_module = true,
})
