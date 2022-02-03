--- Ingest the FreeSWITCH events.
--
-- Some custom events are used for async execution, some
-- to reflect the call state machine and some other are
-- used for housekeeping.
local json        = require("json")
local rest        = require("rest")
local patchbay    = require("patchbay")
local transaction = require("patchbay._transaction")

local module = {}

local handlers = {}

function handlers.HEARTBEAT(event)

    --[[transaction(function()
        print("PING before")
        local a,b,c = transaction.async_freeswitch_call("consoleLog", "NOTICE", "MESSAGE FROM LUA!!!")
        print("PING later", a,b,c)
    end)]]
end

function handlers.RE_SCHEDULE(event)
    return --nop
end

handlers["sofia::gateway_state"] = function(event)
    local state = event.headers.State
    local ping_status = event.headers["Ping-Status"]
    local gateway = event.headers.Gateway

    local did = patchbay.directory._get_did(gateway)

    if did then
        did:_set_state(state)
        did:_set_ping_status(ping_status)
    else
        error("DID "..gateway.." not found")
    end
end

handlers["patchbay::async_result"] = function(event)
    --print("IN RESUME LOOKUP", event.headers.thread_uuid, event.headers.request_uuid)
    if event.headers.runtime_error == "true" then
        local tb = transaction.abort(event.headers.thread_uuid)
        patchbay.emit_signal("debug::error", event.headers.error_message, tb, event.headers.error_traceback)
        return
    end

    transaction.resume(
        event.headers.thread_uuid,
        event.headers.request_uuid,
        json.decode(event.body)
    )
end

handlers["sofia::pre_register"] = function(event)
    local dev = patchbay.directory.get_device_by_extension(event.headers['from-user'])

    if dev then
        dev:_pre_reg(event)
    end
end

handlers["sofia::register_attempt"] = function(event)
    local dev = patchbay.directory.get_device_by_extension(event.headers['username'])

    if dev then
        dev:_reg_attempt(event)
    end
end

handlers["sofia::register"] = function(event)
    local dev = patchbay.directory.get_device_by_accountcode(event.headers['accountcode'])

    if dev then
        dev:_reg(event)
    end
end

function handlers.CUSTOM(event)
    local subclass = event.headers["Event-Subclass"]

    -- print("EVENT!", subclass, event)

    if handlers[subclass] then
        handlers[subclass](event)
    end
end

function handlers.TRAP(event)
    local ipv4_state = event.headers["network-status-v4"]
    if ipv4_state == "disconnected" then
        patchbay.network.emit_signal("state::down")
        --TODO outage.network_incident
    elseif ipv4_state == "" then
        --
    end
end

function handlers.STARTUP(event)

end

function handlers.CHANNEL_STATE(event)

end

function handlers.CHANNEL_CALLSTATE(event)
    --for k, v in pairs(event.headers) do
    --    print("  CS", "'"..k.."'", v)
    --end
    --print("\n\nHERE", event.headers["Unique-ID"], event.headers["is_patchbay_bridge"])
    local c = patchbay.session._get_call(event.headers["Unique-ID"], event.headers)

    if c then
        c:_update_variables(event.headers)
    end
end

function handlers.CHANNEL_HANGUP_COMPLETE(event)
    --
end

function handlers.CHANNEL_EXECUTE(event)

end

function handlers.CHANNEL_CREATE(event)

end

local function ingest(_, event)
    -- print("EVENT!", event.type, event.headers, event.body)
    -- for k, v in pairs(event.headers) do
        -- print("  HEAD", k, v)
    -- end

    if handlers[event.type] then
        handlers[event.type](event)
    end
end

return setmetatable(module, { __call = ingest })
