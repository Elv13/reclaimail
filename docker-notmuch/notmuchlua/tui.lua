local tui   = require( "stream_tui" )
local lpeg  = require( "lpeg"  )
local ep    = require( "email" )

local rstate, lstate = "", ""

local separator = tui.widget{row=2}

local sep_txt = "----------------"

function separator:draw()

    while sep_txt:len() < tui.get_width() do
        sep_txt = sep_txt..sep_txt
    end

    tui.primitives.add_line()
    tui.atomic.print_on_line_cropped {text=sep_txt:sub(1, width)}
    tui.primitives.add_line()
end

local remote_state = tui.widget{}

function remote_state:draw()
    tui.primitives.carriage_return()
    tui.primitives.clear_to_end()
    tui.atomic.print_on_line_cropped {text = function()
        return "OfflineIMAP: "..rstate
    end}
    tui.atomic.print_on_line_cropped {text="10 minutes ago", align="right"}
    tui.primitives.add_line()
end

local local_state = tui.widget{}

function local_state:draw()
    tui.primitives.carriage_return()
    tui.primitives.clear_to_end()
    tui.atomic.print_on_line_cropped {text = function()
        return lstate
    end}
    tui.atomic.print_on_line_cropped {text="OK", align="right"}
    tui.primitives.add_line()
end

tui.footer:push_widget(separator)
tui.footer:push_widget(remote_state)
tui.footer:push_widget(local_state)

local from_name = ""
local from_addr = ""
local subject   = ""
local date      = ""

local mess = tui.message {has_box=true}
mess:push_left(function() return subject end)
mess:push_line()

mess:push_left("From: ")
mess:push_left(function() return from_name .. "<" .. from_addr .. ">" end)
-- mess:push_right("message4 ")
-- mess:push_right("message6 ")


local module = {}

function module.print_message(path)
    local f       = io.open(path)
    if not f then return end

    local content = f:read("*all*")
    if not content == "" then return end

    local ret = lpeg.match(ep, content)

    from_name = ret.from[1].name
    from_addr = ret.from[1].address
    subject   = ret.subject
    date = ret.date.weekday .. ret.date.month .. " " .. ret.date.day.." "..
        ret.date.hour..":"..ret.date.min

    mess:print()
end

function module.set_remote_state(s)
    rstate = s
    tui.footer:redraw()
end

function module.set_local_state(s)
    lstate = s
    tui.footer:redraw()
end

return module
