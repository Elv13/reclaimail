local object     = require("patchbay.object")
local call       = require("patchbay.call")
local rpc        = require("patchbay.rpc")
local utils      = require("patchbay.utils")
local call_rules = require("patchbay.rules.call")

local module = {}

local logger = require("patchbay.logging") {
    name = "session",
}

local active_calls, calls, pending_bridge = {}, {}, {}

local function bridge_loopup(attributes)
    for k, bridge in ipairs(pending_bridge) do
        -- print("CHECK", attributes["Channel-Name"], bridge.internal_gateway_path, bridge.external_gateway_path)
        if attributes["Channel-Name"] == bridge.internal_gateway_path then
            table.remove(pending_bridge, k)
            return bridge
        end

        if attributes["Channel-Name"] == bridge.external_gateway_path then
            table.remove(pending_bridge, k)
            return bridge
        end
    end
end

function module._get_call(uuid, attributes, silent)
    silent = silent == true

    assert(uuid, "Called without UUID")

    local c = calls[uuid]

    if c then return c end

    if not attributes then
        logger:warn("UUID " .. tostring(uuid) .." isn't known\n\n")
        return nil
    end

    logger:info("Creating call " .. uuid)
    c = call(attributes)
    calls[uuid] = c
    table.insert(active_calls, c)

    -- When a device call FreeSWITCH, it use the "default" dialplan,
    -- but the call is still inbound. So an outbound call is a bridge.
    local origin = c.origin

    c.is_bridge = origin == "bridge" --TODO remove this property

    if origin == "bridge" then
        local sibling = bridge_loopup(attributes)

        if sibling then
            c:_add_bridged_sibling(sibling.sibling)
            sibling.sibling:_add_bridged_sibling(c)
            c._private.did = c._private.did or sibling.did
            c._private.device = c._private.device or sibling.device
        end
    end

    call_rules.apply(c)

    --if attributes["Channel-Call-State"] == "HANGUP" then return c end


    -- Do something with the calls.
    --[[utils.delayed_call(function()
        print("\n\n\nSELECT DIAL!", c.state)
        if c.dialplan then
            c:dialplan()
            return
        end


        if is_bridge and not silent then
            if not silent then
                -- module.emit_signal("call::bridge", c)
                c:emit_signal("request::dialplan::bridged")
            end
        elseif attributes.dialplan == "public" and not silent then
            -- module.emit_signal("call::incoming", c)
            c:emit_signal("request::dialplan::inbound")
        elseif not silent then
            -- module.emit_signal("call::outgoing", c)
            c:emit_signal("request::dialplan::outbound")
        end
    end)]]

   return c
end

function module._register_bridged_call(details)
    local parent = module._get_call(details.parent_uuid)

    if details.busy then
        parent:emit_signal("peer::busy")
    end

    local c = module._get_call(details.uuid, details, true)


    if parent then
        parent:_add_bridged_sibling(c)
        c:_add_bridged_sibling(parent)
    end

    call.emit_signal("call::bridge", c)
end

function module._register_pending_bridge(args)
    table.insert(pending_bridge, args)
end

-- Used to sanely terminate the FreeSWITCH dialplans.
function module._is_active(uuid)
    for _, c in ipairs(active_calls) do
        if c.uuid == uuid then return true end
    end

    return false
end

call.connect_signal("finished", function(c)
    local failed_bridges = {}

    -- Cleanup any bridges which might have failed.
    for k,v in ipairs(pending_bridge) do
        if v.sibling == c then
            table.insert(failed_bridges, k)
        end
    end

    for i= #failed_bridges, 1, -1 do
        table.remove(pending_bridge, failed_bridges[i])
    end

    -- Remove from the active calls.
    for k, c2 in ipairs(active_calls) do
        if c2.uuid == uuid then
            table.remove(active_calls, k)
            break
        end
    end

    calls[c.uuid] = nil
end)

function module._pickup(uuid, direction)
    local c = module._get_call(uuid)

    c:emit_signal("state::changed", "pickup", direction)
    module.emit_signal("call::pickup", c, direction)
end

function module._receive_dtmf(uuid, digit)
    local c = module._get_call(uuid)

    --TODO create a dtmf object
    c:emit_signal("dtmf", digit)
    module.emit_signal("call::dtmf", c, digit)
end

function module.get_has_active_call()
    for _, c in ipairs(active_calls) do
        if c.state == "ACTIVE" then
            return true
        end
    end

    return false
end

function module.start()
    rpc.start()
end

return object.patch_table(module, {
    is_module = true,
    class     = module
})
