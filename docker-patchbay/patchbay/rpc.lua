--- A dummy JSON-RPC server receiving requests on a ZeroMQ socket

local coxpcall = require("coxpcall")

-- JSON and RPC
local json    = require('json')
local jsonrpc = require('json-rpc')
local utils   = require('patchbay.utils')

-- Signal handling requires luaposix
local signal = require("posix.signal")

-- ZMQ for the networking
local zmq   = require("lzmq")
local timer = require("lzmq.timer")

--local log_console = require"logging.console"
--local logger      = log_console()

local module = {}

function module.start()
    -- Global var to control the run status
    -- Set CTRL-C to stop the running
    local run = true

    signal.signal(signal.SIGINT, function(signum)
        run = false
    end)


    -- Our dummy "remote" procedures
    local procedures = require("api")

    -- Set up the socket
    local context = zmq.context()
    local responder, err = context:socket{zmq.REP, bind = "tcp://*:6543"}
    zmq.assert(responder, err)

    -- The "event loop" ...

    while run do
        local req, err = responder:recv()
        if err == false then
            local err, res = coxpcall.xpcall(function ()
                return jsonrpc.server_response(procedures, req)
            end, debug.traceback)

            if not err then
                print("Packging JSON failed", res)
            end

            res = json.encode(res)
            zmq.assert(responder:send(res))
        else
            print("'recv()' failed: " .. tostring(err))
            timer.sleep(100) -- in ms
        end

        utils._run_delayed_calls_now()
    end
    print("exiting...")

    responder:close(0)
    context:shutdown(0)
end

return module
