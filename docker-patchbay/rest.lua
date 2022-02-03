local http   = require("socket.http")
local socket = require("socket")
local ltn12  = require("ltn12")
local json   = require("json")

local USER     = "freeswitch"
local PASSWORD = "freeswitch"
local IP       = "192.168.100.135"

--URL = 'http://freeswitch:freeswitch@192.168.100.135:8080/xmlapi/sofia?status%20profile%20internal%20reg'
local URL_BUILDER = 'http://${username}:${password}@${ip}:8080/xmlapi/${command}?${args}'

local module = {}

-- python like format
local function format_url(tab)
    return (tab.url:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

-- access the rest api
local function freeswitch_request(exec_string)
    local parts = {}

    for part in exec_string:gmatch("([^ ]+)") do
        table.insert(parts, part)
    end

    local cmd = table.remove(parts, 1)

    local url = format_url {
        url      = URL_BUILDER,
        ip       = IP,
        username = USER,
        password = PASSWORD,
        command  = cmd,
        args     = table.concat(parts, "%20")
    }

    return url
end

function module.generate_uuid()
    --https://gist.github.com/jrus/3197011
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

function module.plain_text_command(command)
    local content = {}

    local _, retcode, data, _ = http.request {
        url  = freeswitch_request(command),
        sink = ltn12.sink.table(content)
    }

    return table.concat(content)
end

function module.send_async_command(args)
    -- Don't pass `args` directly, it might contain other stuff.
    local body = json.encode({
        scope        = args.scope,
        object_uuid  = args.object_uuid,
        request_uuid = args.request_uuid,
        thread_uuid  = args.thread_id,
        command      = args.command,
        args         = args.command_args or {},
    })

    local size    = #body
    local script  = args.script or "async.lua"
    local timeout = args.sync_timeout or 0.05

    -- Create "less blocking" request. mod_xml_rpc is fragile.
    -- Those header are reverse-engineered from working examples.
    -- Anything else (add or remove something), will just not work.
    http.request {
        url    = freeswitch_request("lua "..script),
        method = "POST",
        source = ltn12.source.string(body),
        create = function()
            local ret = socket.tcp()
            ret:settimeout(timeout, 't')
            return ret
        end,
        headers = {
            ["Content-Type"  ] = "text/json",
            ["User-Agent"    ] = "curl/7.68.0",
            ["Content-Length"] = size,
            ["Accept"        ] = "*/*",
        },
    }
end

-- for k,v in pairs(data) do
    -- print("K", k, v)
-- end

-- print(content)

return module
