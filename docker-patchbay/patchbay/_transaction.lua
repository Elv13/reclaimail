--- This module contains the boilerplate code to call the FreeSWITCH API in cotoutines.
--
-- This uses REST to push the request and FreeSWITCH events to (later) get the result.
local rest = require("rest")
local unpack = unpack or table.unpack

-- pcall and xpcall are not compatible with coroutines.
local coxpcall = require("coxpcall")

local module = {}

local coroutines_by_uuid, uuid_by_coroutine = setmetatable({}, {__mode=""}), setmetatable({}, {__mode = "k"})
local pending_results, pending_callbacks = {}, {}

local function get_current_uuid()
    local co = coxpcall.running()

    assert(co)

    return uuid_by_coroutine[co]
end

function module.detached_script(callback, script, ...)
    local transact = rest.generate_uuid()

    if callback then
        pending_callbacks[transact] = callback
    end

    rest.send_async_command {
        scope        = "api",
        detach       = true,
        object_uuid  = "",
        script       = script,
        request_uuid = transact,
        thread_id    = get_current_uuid(),
        command      = command,
        command_args = {...},
    }

    return
end

function module.async_api_call(command, ...)
    local transact = rest.generate_uuid()

    rest.send_async_command {
        scope        = "api",
        detach       = false,
        object_uuid  = "",
        request_uuid = transact,
        thread_id    = get_current_uuid(),
        command      = command,
        command_args = {...},
    }

    coroutine.yield()

    local ret = pending_results[transact] or {}

    pending_results[transact] = nil

    return unpack(ret)
end

function module.async_freeswitch_call(command, ...)
    local transact = rest.generate_uuid()

    rest.send_async_command {
        scope        = "freeswitch",
        detach       = false,
        object_uuid  = "",
        request_uuid = transact,
        thread_id    = get_current_uuid(),
        command      = command,
        command_args = {...},
    }

    coroutine.yield()

    local ret = pending_results[transact] or {}

    pending_results[transact] = nil

    return unpack(ret)
end

local function session_call_common(call_args, c, command, ...)
    local session =  c.uuid
    local transact = rest.generate_uuid()

    rest.send_async_command {
        scope        = "session",
        detach       = call_args.detach or false,
        sync_timeout = call_args.timeout or (call_args.async and 0.05 or 10),
        object_uuid  = session,
        request_uuid = transact,
        thread_id    = get_current_uuid(),
        command      = command,
        command_args = {...},
    }

    coroutine.yield()

    local ret = pending_results[transact] or {}

    pending_results[transact] = nil

    return unpack(ret)
end

function module.async_session_call(c, command, ...)
    local call_args = {
        async = true
    }

    return session_call_common(call_args, c, command, ...)
end

function module.sync_session_call(c, command, ...)
    local call_args = {
        async = false
    }

    return session_call_common(call_args, c, command, ...)
end

function module.sync_session_call(c, command, ...)
    local call_args = {
        async  = true,
        detach = true,
    }

    return session_call_common(call_args, c, command, ...)
end

function module.xpcall_resume(co)
    local ret = {coroutine.resume(co)}

    if ret[1]  == false then
        -- print(ret[2], debug.traceback(co)) -- Uncomment when the debug code explodes
        require("patchbay").emit_signal("debug::error", ret[2] or "", debug.traceback(co), nil)
    end

    if coroutine.status(co) == "dead" then
        local uuid = uuid_by_coroutine[co]
        uuid_by_coroutine[co] = nil
        coroutines_by_uuid[uuid] = nil
    end
end

function module.resume(uuid, request, ret_vals)
    local co = coroutines_by_uuid[uuid]

    if co then
        assert(co)

        pending_results[request] = ret_vals or {}

        module.xpcall_resume(co)
    elseif pending_callbacks[request] then
        pending_callbacks[request](unpack(ret_vals))
        pending_callbacks[request] = false
    end
end

function module.abort(uuid)
    local co = coroutines_by_uuid[uuid]

    local tb = nil

    if co then
        tb = debug.traceback(co)
        uuid_by_coroutine[co] = nil
    end

    coroutines_by_uuid[uuid] =nil

    return tb
end

local function new(_, fct)
    local uuid = rest.generate_uuid()

    local co = coroutine.create(fct)

    coroutines_by_uuid[uuid] = co
    uuid_by_coroutine[co]    = uuid

    module.xpcall_resume(co)

    --TODO return a future you can block on.
end

return setmetatable(module, { __call = new })
