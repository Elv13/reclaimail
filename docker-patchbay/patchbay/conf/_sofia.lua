local common = require("patchbay.conf._common")
local internal = require("patchbay.conf._sip_profiles.internal")
local external = require("patchbay.conf._sip_profiles.external")

local HEADER = table.concat({
    '<configuration name="sofia.conf" description="sofia Endpoint">',
    "    <global_settings>",
}, "\n")

local DEFAULTS = {
    ["log-level"] = 0,
    ["tracelevel"] = "DEBUG",
    ["nat-options-ping"] = true,
    ["all-reg-options-ping"] = true,
    ["registration-thread-frequency"] = 30,
}

local FOOTER1 = table.concat({
    "    </global_settings>",
    "    <profiles>",
}, "\n")

local FOOTER2 = table.concat({
    '    </profiles>',
    '</configuration>'
}, "\n")

local module = {
    object = common()
}

function module._to_xml(args)
    --[[if args and args.params and args.params["Event-Calling-Function"] ~= "config_sofia" then
        return ""
    end]]

    local footer = table.concat({
        FOOTER1,
        internal._to_xml(),
        external._to_xml(),
        FOOTER2
    }, "\n")

    return common._to_xml(
        module.object, DEFAULTS, HEADER, footer
    )
end

return module
