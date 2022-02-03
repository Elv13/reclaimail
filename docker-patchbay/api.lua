--- Remote function exosed so FreeSWITCH can talk to Patchbay.
-- There is an attempt to return nothing when possible. All
-- calls which return something cannot be delayed. All delayed
-- calls might cause coroutine spaghetti.

local session  = require("patchbay.session")
local patchbay = require("patchbay")
local object   = require("patchbay.object")
local json     = require("json")
local events   = require("patchbay._events")

local logger = require("patchbay.logging") {
    name = "api"
}

local remote_procedures = {}

local CONF_HEADER = [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>
    <document type="freeswitch/xml">
        <section name="configuration">
]]

local CONF_FOOTER = [[
    </section>
</document>
]]

function remote_procedures.enter_dialplan_callback(call_details)
    patchbay.utils.delayed_call(function()
        session._get_call(call_details["Unique-ID"], call_details)
    end)
end

function remote_procedures.leave_dialplan_callback(args)
    patchbay.utils.delayed_call(function()
        logger:info("Leaving dialplan for " .. args["Unique-ID"])
    end)
end

--[[function remote_procedures.hangup_callback(args)
    patchbay.utils.delayed_call(function()
        logger:info("HANGUP", args["Unique-ID"], args.reason)
        session._hangup(args["Unique-ID"])
    end)
end]]

function remote_procedures.pickup_callback(args)
    patchbay.utils.delayed_call(function()
        session._pickup(args["Unique-ID"], args.direction)
    end)
end

function remote_procedures.dtmf_callback(args)
    patchbay.utils.delayed_call(function()
        logger:info("DTMF")
        session._receive_dtmf(args["Unique-ID"], args.digit)
    end)
end

function remote_procedures.bridge_completed(args)
    patchbay.utils.delayed_call(function()
        logger:info("Bridge complete for "..tostring(args.uuid))
    end)
end

function remote_procedures.get_configuration(args)
    --TODO
    if args.params then
        args.params = json.decode(args.params)
    end

    --[[if args.params then
        logger:info("\n\nCONF!!!", args.section)
        for k,v in pairs(args.params) do
            logger:info("    param" , k, v)
        end
    end]]

    if args.section == "configuration" then
        local mod_name = args.key_value:gsub("[.]conf$", "")

        local mod = object.load_submodules({}, "patchbay.conf")["_"..mod_name]

        if mod then
            local xml = mod._to_xml(args)

            if type(xml) ~= "string" or #xml == 0 then
                logger:error("The generator for patchbay.conf." .. mod_name .. " failed")
                return nil, ""
            else
                return nil, CONF_HEADER..xml..CONF_FOOTER
            end
        else
            assert(false, args.key_value .. " is missing")
        end
    elseif args.section == "directory" then
        return nil, patchbay.directory._to_xml(args)
    end
end

function remote_procedures.process_event(args)
    patchbay.utils.delayed_call(function()
        events(args)
    end)
end

function remote_procedures.get_default_session_variables(args)
    if args.incoming then
        return nil, patchbay.call._get_default_variables(false)
    else
        return nil, patchbay.call._get_default_variables(true)
    end
end

function remote_procedures.register_bridged_call(args)
    patchbay.utils.delayed_call(function()
        session._register_bridged_call(args)
    end)
end

return remote_procedures
