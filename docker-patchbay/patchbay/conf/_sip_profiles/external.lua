local directory = require("patchbay.directory")
local common = require("patchbay.conf._common")

local HEADER1 = table.concat({
    '        <profile name="external">',
    '            <gateways>',
}, "\n")

local HEADER2 = table.concat({
    '            </gateways>',
    '            <settings>'
}, "\n")

local FOOTER = '            </settings>\n        </profile>'

local DEFAULTS = {
    ["auth-calls"] = "false",
    ["debug"] = "0",
    ["dialplan"] = "XML",
    ["context"] = "public",
    ["codec-prefs"] = "$${global_codec_prefs}",
    ["rtp-ip"] = "$${local_ip_v4}",
    ["sip-ip"] = "$${local_ip_v4}",
    ["ext-rtp-ip"] = "auto-nat",
    ["ext-sip-ip"] = "auto-nat",
    ["sip-port"] = "$${external_sip_port}",
    ["nat-options-ping"] = "true",
    ["all-reg-options-ping"] = "true",
    ["registration-thread-frequency"] = "20",
    ["all-options-ping"] = "true",
}

local module = {
    object = common()
}

function module._to_xml()
    local gateways = {}

    for _, gateway in ipairs(directory._get_dids()) do
        table.insert(gateways, gateway:_to_xml())
    end

    local header = table.concat({
        HEADER1,
        table.concat(gateways, "\n"),
        HEADER2,
    }, "\n")

    return common._to_xml(
        module.object, DEFAULTS, header, FOOTER
    )
end

return module
