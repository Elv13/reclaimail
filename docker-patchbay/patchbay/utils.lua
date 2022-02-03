local transaction = require("patchbay._transaction")
local coxpcall    = require("coxpcall")
local json        = require("json")
local socket      = require("socket")

local module = {
    _delayed_calls = {}
}

function module.format(tab)
    return (tab.url:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

function module.pretty_print_table(tab, header)
    --TODO
end

function module.msleep(time)
    transaction.async_freeswitch_call("msleep", time)
end

function module.delayed_call(fct)
    table.insert(module._delayed_calls, fct)
end

function module._run_delayed_calls_now()
    if # module._delayed_calls == 0 then return end

    local delayed = module._delayed_calls

    -- The delayed calls may cause more delayed calls, so make sure
    -- they are tracked on their own.
    module._delayed_calls = {}

    for _, fct in ipairs(delayed) do
        --[[local tb = nil
        local ret, err = coxpcall.xpcall(fct, function(err)
            tb = debug.traceback(err)
            return err
        end)

        if not ret then
            require("patchbay").emit_signal("debug::error", err, tb, nil)
        end]]

        transaction(fct)
    end

    -- More delayed calls may have been created.
    module._run_delayed_calls_now()
end

function module.protected_call(fct)
    local tb = nil
    local ret, err = coxpcall.xpcall(fct, function(err)
        tb = debug.traceback(err)
        return err
    end)

    if not ret then
        require("patchbay").emit_signal("debug::error", err, tb, nil)
    end
end

function module.file_or_nil(path)
    local f=io.open(path,"r")
    if f then
        c:close()
        return path
    end
end

function module.decode_json_file(path)
    local f = io.open(path, 'rb')

    if not f then return {} end

    local content = f:read("*all")
    f:close()

    return json.decode(content)
end

function module.now()
    return socket.gettime()
end

function module.ts_to_iso(ts)
    ts = ts or 0
    local ms = math.floor((ts % 1)*100000)
    -- ts = ts / 1000000
    ts = math.floor(ts)
    return os.date("!%Y-%m-%dT%T", ts) .. "." .. ms .. "Z"
end

return module
