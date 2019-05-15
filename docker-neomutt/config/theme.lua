local unpack = unpack or table.unpack --lua 5.1 compat

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


-- Generate a "complex" regex golf to encapsulate the tags
local function generate_tags(tags)
    local tag_transoform, tag_formats, used_tag_format, tag_format = {}, {}, {}, ""

    -- Each alias has to be unique, they are never shown, but the shorter the better
    local function generate_alias(name)
        local alias = "G" .. name:sub(1,1):upper()

        while used_tag_format[alias] do
            alias = alias .. name:sub(1,1):upper()
        end

        used_tag_format[alias] = true

        return alias
    end

    for _, v in ipairs(tags) do
        -- Add the sidebar
        mutt.call("virtual-mailboxes", v.name, "notmuch://?query=tag:"..v.name)

        table.insert(tag_transoform, v.name)
        table.insert(tag_transoform, "⢾"..v.name:upper().."⡷⠀ ")

        -- Set an unique alias for each tag
        local alias = generate_alias(v.name)
        table.insert(tag_formats, v.name)
        table.insert(tag_formats, alias )

        -- Some tags, like archive or inbox make no sense to display
        if v.display_tag then
            tag_format = tag_format .. "%?" .. alias .. "?%" .. alias .. " &?"

            -- Right now it seems patterns are broken
            --theme.index_tag = theme.color {
            --    bg = "red", fg = "blue", when = '"\\[('..v.name:upper()..')\\]"'
            --}

            -- Add the tag color
            theme.index_tag = theme.color {
                bg = v.bg, fg = v.fg, when = v.name:upper()
            }
        end
    end

    -- Give them a name for the index view
    mutt.call("tag-formats"   , unpack(tag_formats   ))
    mutt.call("tag-transforms", unpack(tag_transoform))

    return tag_format
end

rawset(theme, "gen_powerline", gen_powerline)
rawset(theme, "generate_tags", generate_tags)

return theme
