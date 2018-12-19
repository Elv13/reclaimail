
--FIXME remove this hack
local delimiter = "⮀"

-- Mutt crash when the color are not complete, make sure they are
local function set_color(col, args)
    assert(args._is_color)
    local bg, fg = args.bg or "default", args.fg or "default"

    -- As of 2018, Mutt segfault when adding nil args
    if args.num then
        mutt.command.color(col, fg, bg, args.when, args.num)
    elseif args.when then
        mutt.command.color(col, fg, bg, args.when)
    else
        mutt.command.color(col, fg, bg)
    end
end

local theme = setmetatable({
        color = function(args)
            args._is_color = true
            return args
        end,
    }, {
        __index    = function(_, k) assert(false) end, --TODO
        __newindex = function(_, k, args)
            for _, c in ipairs( args._is_color and {args} or args) do
                assert(args._is_color or c.when)
                set_color(k, c)
            end
        end
    }
)

-- Generate a powerline section
local function powerline_section(bar, sec, k, next_offset)
    local next = bar.left[k+next_offset]

    local st = sec.label .. " ".. sec.section[1].. " "..delimiter.." "

    local regex = "[ ]?"..sec.label.."[\\ ]+"..sec.section[2].."[ ]*"

    -- Play regex golf to set the right color
    theme.status = theme.color {
        bg = sec.bg, fg = sec.fg, when = '"'..regex..'"', num = 0
    }

    local next_color = next and next.bg or "default"
    local delim_regex, delim_idx = "",1

    -- Invert the color for the delimiter
    if next then
        delim_regex = "("..bar.left_separator..")"

        -- If the next part is known, add it to the regex
        delim_regex = delim_regex .. (next and "( "..next.label..")" or "")

    else
        delim_regex = bar.left_separator.." ("..sec.label.." "..sec.section[2].." )("..bar.left_separator..")"
        delim_idx = 2
    end

    if delim_regex ~= "" and next_offset == 1 then
        theme.status = theme.color {
            bg = next_color, fg = sec.bg, when = '"'..delim_regex..'"', num = delim_idx
        }
    end

    return st
end

-- Generate a powerline bar
local function gen_powerline(bar)
    local st = ""
    for k, sec in ipairs(bar.left) do
        st = st .. powerline_section(bar, sec, k, 1)
    end
    st = st.."%>"..(center and center.fill or " ")
    for k, sec in ipairs(bar.right) do
        st = st .. powerline_section(bar, sec, k, -1)
    end

    return st
end

rawset(theme, "gen_powerline", gen_powerline)

return theme
