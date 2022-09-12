local posix = require("posix")

local module = {}

local _pid = nil

local function get_pid()
    if _pid then return _pid end

    local f = io.read("/proc/self/status")

    for line in f:read("*line*") do
        local key, value = line:match("([a-zA-Z_]+):[ \t]*(.+)")

        if key == "Pid" then
            f:close()
            _pid = tonumber(value)
            return _pid
        end
    end

    f:close()
end

function module.parse(path)
    local ret = {}

    local f = io.open(path)

    if not f then return {} end

    for l in function() return f:read("*line*") end do
        if l:sub(1,1) ~= "#" or l:sub(1,6) == "#meta:" then
            table.insert(ret, l)
        end
    end

    return ret
end

function module.append(path, line)
    local f = io.open(path, "a")
    f:write(line.."\n")
    f:close()
end

--- Force DNSMASQ to read the *ALL* database again.
function module.refresh()
    local pid = get_pid()

    posix.signal.kill(pid, posix.signal.SIGHUP)
end

return module
