-- This file contains a simple implementation of "ncurses-like" TUI, but
-- for streams of messages with a static bottom widget. NCURSES is good
-- at full screen TUI while this attempt to handle the flowing streams
-- TUI

local ffi = require("ffi")

-- Get the Linux terminal/TTY size
ffi.cdef([[
    struct winsize {
        unsigned short ws_row;	/* rows, in characters */
        unsigned short ws_col;	/* columns, in characters */
        unsigned short ws_xpixel;	/* horizontal size, pixels */
        unsigned short ws_ypixel;	/* vertical size, pixels */
    };

    struct term_constants {
        static const int STDOUT_FILENO = 1;	/* Standard output.  */
        static const int TIOCGWINSZ = 0x5413;	/*/usr/include/asm-generic/ioctls.h */
    };

    extern int ioctl (int __fd, unsigned long int __request, ...);
]])

local K, win = ffi.new("struct term_constants"), ffi.new("struct winsize")

ffi.C.ioctl(K.STDOUT_FILENO, K.TIOCGWINSZ, win)

-- The terminal size
local width, height = win.ws_col, win.ws_row

print(width, height)

--- Low level primitives to move across the screen
local primitives = {
    carriage_return = function (     ) io.write( "\r"              ) end,
    add_line        = function (     ) io.write( "\n"              ) end,
    go_up           = function (lines) io.write( '\27['..lines.."A") end,
    go_down         = function (lines) io.write( '\27['..lines.."B") end,
    go_left         = function (lines) io.write( '\27['..lines.."D") end,
    go_right        = function (lines) io.write( '\27['..lines.."C") end,
    clear_to_end    = function (     ) io.write( '\27[K'           ) end,
    move_to         = function (c, r ) io.write( '\27['..r..';'..c ) end,
}

primitives.finish = function () primitives.move_to(width, height) end

-- Stateless helper function to display content.
local atomic = {}

function atomic.print_on_line_cropped(args)
    args.align = args.align or "left"
    args.left_pad, args.right_pad = args.left_pad or 0, args.right_pad or 0

    local text = type(args.text) == "function" and args.text() or args.text

    primitives.carriage_return()

    if args.left_pad > 0 then
        primitives.go_right(args.left_pad)
    end

    local w = width - args.left_pad - args.right_pad
    local str = text:len() > w and text:sub(1, w-3).."..." or text

    if args.align == "right" then
        primitives.go_right(w - str:len())
    end

    io.write(str)
end

function atomic.colored_print(text, fg, bg)
    io.write(text)
end

function atomic.reserve_line(count)
    local ret = {}
    for i=1, count do table.insert(ret, '\n') end
    io.write(table.concat(ret))
end

local _cols_lsd = {
    Black      = 0,
    Blue       = 4,
    Green      = 2,
    Cyan       = 6,
    Red        = 1,
    Purple     = 5,
    Brown      = 3,
    Light_Gray = 7,
}

local _cols_msd = {
    Fg    = 3,
    Bg    = 4,
    Dark  = '0;',
    Light = '1;',
}

function gen_fg(color, light)
    return '\27[m'..(light and _cols_msd.Light or _cols_msd.Dark) ..
        _cols_msd.Fg.._cols_lsd[color]..'m'
end

local FG = {
    BLACK            = gen_fg("Black", false),
    BLUE             = gen_fg("Blue", false),
    GREEN            = gen_fg("Green", false),
    CYAN             = gen_fg("Cyan", false),
    RED              = gen_fg("Red", false),
    PURPLE           = gen_fg("Purple", false),
    BROWN            = gen_fg("Brown", false),
    LIGHT_GRAY       = gen_fg("Light_Gray", false),
    LIGHT_BLACK      = gen_fg("Black", true),
    LIGHT_BLUE       = gen_fg("Blue", true),
    LIGHT_GREEN      = gen_fg("Green", true),
    LIGHT_CYAN       = gen_fg("Cyan", true),
    LIGHT_RED        = gen_fg("Red", true),
    LIGHT_PURPLE     = gen_fg("Purple", true),
    LIGHT_BROWN      = gen_fg("Brown", true),
    LIGHT_LIGHT_GRAY = gen_fg("Light_Gray", true),
}

local screen = {
    first_print = false
}

function screen.draw()

end

local box_line = "───────────────────────"

-- 3 byte per UTF-8 char
local function box_top(left, middle, right)
    while box_line:len()/3 < width do box_line = box_line..box_line end

    primitives.carriage_return()
    io.write("┌"..box_line:sub(1, width*3-6).."┐")
    primitives.add_line()
end

local function box_bottom()
    while box_line:len()/3 < width do box_line = box_line..box_line end

    primitives.carriage_return()
    io.write("└"..box_line:sub(1, width*3-6).."┘")
    primitives.add_line()
end

local function clear_footer()
    -- Get the footer height
--     if not screen.first_print then
        local footer_height = 0
        for _, w in ipairs(screen.footer.widgets) do
            footer_height = footer_height + w.row
        end

        -- Clear the header
        primitives.go_up(footer_height)
        primitives.carriage_return()
        primitives.clear_to_end()
--     end
end


function screen.draw_footer()
    -- Print the footer
    for _, w in ipairs(screen.footer.widgets) do
        w:draw()
    end
    screen.first_print = true
end

function screen.print_message(message)

    clear_footer()

    -- Print the message

    if message.has_box then
        box_top(message.box_left, message.box_middle, message.box_right)
    end

    local mess_width = message.has_box and width - 2 or width

    for _, line in ipairs(message.lines) do
        local remaining_space = mess_width

        primitives.carriage_return()
        primitives.clear_to_end()

        if message.has_box then
            io.write("│")
        end

        -- Left
        for _, lfield in ipairs(line.left) do
            local text = type(lfield.text) == "function" and
                lfield.text() or lfield.text

            remaining_space = remaining_space - text:len()

            if remaining_space <= 0 then break end

            atomic.colored_print(text)
        end

        -- Right
        local right_size, current_pos = mess_width-remaining_space, 0
        for _, rfield in ipairs(line.right) do
            local text = type(rfield.text) == "function" and
                rfield.text() or rfield.text

            remaining_space = remaining_space - text:len()
            if remaining_space <= 0 then break end

            right_size = right_size + text:len()
        end

        primitives.go_right(mess_width - current_pos - right_size)

        for _, rfield in ipairs(line.right) do
            local text = type(rfield.text) == "function" and
                rfield.text() or rfield.text

            atomic.colored_print(text)
        end

        if message.has_box then
            primitives.carriage_return()
            primitives.go_right(width-1)
            io.write("│")
        end

        primitives.add_line()
    end

    if message.has_box then
        box_bottom()
    end

    screen.draw_footer()
end

local widget = setmetatable({

}, {__call = function(_, args)
    local ret = {
        row    = 1,
        column = 1,
        draw   = function() end,
    }

    for k, v in pairs(args) do ret[k] = v end

    return ret
end})

local message = setmetatable({

    }, {
    __call = function(_, args)
        args = args or {}

        local ret = {
            lines       = {},
            has_box     = false,
            box_left    = "",
            box_middle  = "",
            box_right   = "",
        }

        for k, v in pairs(_) do ret[k] = v end
        for k, v in pairs(args) do ret[k] = v end

        return ret
    end,
})

function message:push_left(text, fg, bg)
    if #self.lines == 0 then self:push_line() end
    table.insert(self.lines[#self.lines].left, {text = text, fg = fg, bg = bg})
end

function message:push_right(text, fg, bg)
    if #self.lines == 0 then self:push_line() end
    table.insert(self.lines[#self.lines].right, {text = text, fg = fg, bg = bg})
end

function message:push_line()
    table.insert(self.lines, {
        left        = {},
        right       = {},
        left_width  = 0,
        right_width = 0,
    })
end

function message:print()
    screen.print_message(self)
end

local footer = {}

local function create_footer(args)
    args = args or {}

    local ret = {
        widgets = {}
    }

    for k, v in pairs(footer) do ret[k] = v end
    for k, v in pairs(args) do ret[k] = v end

    return ret
end


function footer:push_widget(w)
    table.insert(self.widgets, w)
end

function footer:redraw()
    clear_footer()
    screen.draw_footer()
end

screen.footer = create_footer()

return {
    primitives = primitives,
    atomic     = atomic,
    widget     = widget,
    message    = message,
    footer     = screen.footer,
    FG         = FG,
    BG         = BG,
    get_width  = function() return width end,
    get_height = function() return height end,
}
