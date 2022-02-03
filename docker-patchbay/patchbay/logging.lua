--- Patchbay logging utilities.
--
-- Knowing when something goes wrong and why is critical. This
-- logging service sits at an higher level than FreeSWITCH logs.
-- It is meant to be human readable.
--
local ffi     = require("ffi")
local socket  = require("socket")
local logging = require("logging")
local object  = require("patchbay.object")

local module = {
    loggers = {}
}

local logger_levels = {
    DEBUG  = "\27[44mDEBUG\27[0m\27[90m ",
    INFO   = "\27[44mINFO\27[0m\27[90m " ,
    WARN   = "\27[43mWARN\27[0m\27[90m " ,
    ERROR  = "\27[41mERROR\27[0m\27[90m ",
    FATAL  = "\27[41mFATAL\27[0m\27[90m ",
}

local logger_messages = {
    DEBUG  = "\27[34m",
    INFO   = "\27[0m" ,
    WARN   = "\27[33m",
    ERROR  = "\27[31m",
    FATAL  = "\27[31m",
}

-- Linux ioctl
local TIOCGWINSZ    = 0x5413
local STDOUT_FILENO = 1

-- Access the terminal size information.
if ffi.os == "Linux" then
    ffi.cdef[[
struct winsize {
    unsigned short int ws_row;
    unsigned short int ws_col;
    unsigned short int ws_xpixel;
    unsigned short int ws_ypixel;
};

int ioctl(int, long unsigned int, void*) __attribute__((nothrow, leaf));
]]
end

local prev_date = nil

local function short_current_datetime(time)
    return os.date("!%m-%d %H:%M", time)
end

local function current_date(time)
    return tonumber(os.date("!%d"))
end

local function get_terminal_width()
    if ffi.os ~= "Linux" then return 9999 end

    local info = ffi.new('winsize')

    local ok = ffi.C.ioctl(STDOUT_FILENO, TIOCGWINSZ, info)

    if ok ~= 0 then return 9999
    end

    local ret = info.ws_col

    ffi.gc(info)

    return ret == 0 and 9999 or ret
end

local function daily_header(time, width)
    local d = current_date(time)
    if prev_date == d then return end

    local ret = "\27[35m"

    local line = {}

    for i=1, width do
        table.insert(line, "=")
    end


    local full_date = os.date("!%Y-%m-%d")

    local pad = {}

    for i=1, math.floor((width - #full_date - 2)/2) do
        table.insert(pad, " ")
    end

    line, pad = table.concat(line), table.concat(pad)

    print("\27[35m" .. line .. "\n=" .. pad .. full_date .. pad .. "=" .. line .. "\27[0m")

    prev_date = d
end

-- Make sure long lines are indented.
local function split_line(line, width, prefix_len, padding)
    padding = padding or prefix_len

    local pad = {}

    for i=1, padding do
        table.insert(pad, " ")
    end

    pad = table.concat(pad)

    line = line:gsub("\t", "    ")

    if #line + prefix_len < width then return {line} end

    local ret, cur = {}, line:match("[ ]*")

    for word in line:gmatch("([^ ]+)[ ]?") do
        local w_len = #word + 2

        if #cur + w_len >= width - prefix_len then
            table.insert(ret, cur)
            cur = pad .. word .. " "
        else
            cur = cur .. word .. " "
        end
    end

    table.insert(ret, cur)

    if ret[#ret]:match("^[ ]+$") then
        table.remove(ret, #ret)
    end

    return ret
end

local function colorful_logging_printer(self, level, message)
    local width = get_terminal_width()
    local lines = {}

    for line in message:gmatch("([^\n]*)[\n]?") do
        table.insert(lines, line)
    end

    if lines[#lines] == "" then
        table.remove(lines, #lines)
    end

    local time = socket.gettime()

    daily_header(time, width)

    local date   = short_current_datetime(time)
    local prefix = logger_levels[level].. date .. "\27[0m  "
    local pad    = #level + #date + 2

    if #lines == 1 then
        local chunks = split_line(prefix.. logger_messages[level] ..message, width, 0, pad)

        chunks[#chunks] = chunks[#chunks] .. "\27[0m"

        for _, chunk in ipairs(chunks) do
            print(chunk)
        end
    else
        print(prefix .. logger_messages[level] .. "  " .. (#lines) .. " lines:")

        for k, line in ipairs(lines) do
            local chunks = split_line(line, width, 3)
            for _, chunk in ipairs(chunks) do
                print("| "..chunk)
            end
        end

        print("\27[0m")
    end

    return true
end

local function new(_, args)
    assert(args and args.name, "A logger needs a `name` constrcutor parameter.")

    assert(not module.loggers[args.name], "Logger " .. args.name .. " already exists")

    local l = logging.new(colorful_logging_printer)

    module.loggers[args.name] = ret

    return l
end

return object.patch_table(module, {
    class     = module,
    is_module = true,
    call      = new,
})
