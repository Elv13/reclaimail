-- Re-implement some Kate features I like.
-- There is already plugins for most of them, but I would
-- prefer to use proper Lua libraries rather than vimscript
-- plugins.

local sugar = require("sugar")
local nano = require("nano")

local module = {}

--TODO introspect the syntax file
local comments = {
    cpp    = "//",
    c      = "//",
    lua    = "--",
    python = "#",
    sh     = "#",
    rpm    = "#",
}

-- Open netrw and mitigate the pesky <Empty> buffer bug.
function module.open()
    if sugar.session.mode == "i" then
        vim.api.nvim_input("<esc>")
    end

    local bufs1 = nano.get_real_buffers()
    sugar.commands.enew()
    sugar.commands.edit(".")
    sugar.schedule.delayed(function()
        local bufs2 = nano.get_real_buffers()
        if #bufs1 ~= #bufs2 then
            assert(bufs2[#bufs2].file_name == "")
            bufs2[#bufs2]:wipeout()
        end
    end)
end

function module.new()
    sugar.commands.enew()
end

-- Copy text.
function module.copy()
    -- Calling "yank" would quit visual mode.
    if sugar.session.mode == "v" then
        vim.api.nvim_input("y")
    else
        vim.api.nvim_command("write")
    end
end

--- Take the selection and comment it.
function module.comment()
    local buf  = sugar.session.current_window.current_buffer
    local lang = buf.current_syntax

    if not comments[lang] then return end

    local min, is_commented = 9999, true

    -- To be able to concatenate patterns.
    local escaped_comment = comments[lang]
        :gsub('%-', '%%-')
        :gsub('%*', '%%*')
        :gsub('%[', '%%[')
        :gsub('%]', '%%]')

    -- First pass: Identify correct indent.
    nano.for_selected_lines(function(line)
        local size = select(2, line:find("^[ ]+"))
            or select(2, line:find("^[ ]+$"))

        min = math.min(min or 0, size or 0)

        -- There is still many ways to blow up the pattern, so wrap it.
        local ret = pcall(function()
            is_commented = is_commented and line:match("^([ ]*"..escaped_comment..")") ~= nil
        end)

        -- Disable comment detection is it blew up.
        is_commented = is_commented and ret

        return line
    end)

    -- Nothing to do (do not double-comment).
    if is_commented then return end

    -- Second pass: apply the comments.
    nano.for_selected_lines(function(line)
        return line:sub(1, min)..comments[lang].." "..line:sub(min+1)
    end)
end

--- Take the selection and uncomment it.
function module.uncomment()
    local buf  = sugar.session.current_window.current_buffer
    local lang = buf.current_syntax

    if not comments[lang] then return end

    local escaped_comment = comments[lang]
        :gsub('%-', '%%-')
        :gsub('%*', '%%*')
        :gsub('%[', '%%[')
        :gsub('%]', '%%]')

    nano.for_selected_lines(function(line)
        local _, ends = line:find("^[ \t]*"..escaped_comment.."[ \t]?")
        return ends and line:sub(ends+1) or line
    end)
end

-- Handle indentation like everything else in the universe.
function module.indent(step)
    return function()
        local width = sugar.session.options.shiftwidth

        local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
        local row_start, row_end = nano.selected_range()

        -- Before everything, see if we can use the indent plugin itself.
        --if row_start == row_end and sugar.session.current_window.current_line == "" and step > 0 then
        --    vim.api.nvim_input("<esc>cc")
        --    return
        --end

        -- Use a different modifier for the cursor position.
        local shift_override = nil

        nano.for_selected_lines(function(line)
            -- Handle "empty" lines and normal ones.
            local size = select(2, line:find("^[ ]+"))

            if step > 0 then
                local ret = ""
                shift_override = (size and size % width > 0) and (step-1)*width + (width - size % width) or width*step

                for i=1, shift_override do
                     ret = ret .. " "
                end

                return ret..line
            else
                -- Do nothing when there is no indentation.
                if not size then
                    shift_override = 0
                    return line
                end

                -- Align partial indents.
                if size % width > 0 then
                    shift_override = -((step+1)*width + (size % width))
                    return line:sub(math.min(size-1, -shift_override)+1)
                else
                    shift_override = -math.min(size, (-step)*width)
                    return line:sub(-shift_override+1)
                end
            end
        end)

        local newpos = math.max(cur_col + shift_override, 0)

        vim.api.nvim_win_set_cursor(0, {cur_row, newpos})
    end
end

-- Select the previous buffer (as seen in tabbar).
function module.next_buffer()
    -- Otherwise it will select all the text until the other cursor.
    if sugar.session.mode == "v" then
        vim.api.nvim_input("<esc>")
    end

    local bufs = nano.get_real_buffers()
    local cur = sugar.session.current_window.current_buffer

    for k, buf in ipairs(bufs) do
        if buf == cur then
            local next = bufs[k+1] or bufs[1]
            sugar.session.current_window.current_buffer = next
            return
        end
    end

    -- Fallback
    vim.api.nvim_command("bnext")
end

-- Select the next buffer (as seen in tabbar).
function module.previous_buffer()
    -- Otherwise it will select all the text until the other cursor.
    if sugar.session.mode == "v" then
        vim.api.nvim_input("<esc>")
    end

    local bufs = nano.get_real_buffers()
    local cur = sugar.session.current_window.current_buffer

    for k, buf in ipairs(bufs) do
        if buf == cur then
            local next = bufs[k-1] or bufs[#bufs]
            sugar.session.current_window.current_buffer = next
            return
        end
    end

    -- Fallback
    vim.api.nvim_command("bprev")
end

-- Move the selected (or current) line up.
function module.move_lines_up()
    if sugar.session.mode == "v" then
        vim.api.nvim_input(":m -2<CR>gv")
    else
        vim.api.nvim_command("move -2")
    end
end

-- Move the selected (or current) line down.
function module.move_lines_down()
    local win = sugar.session.current_window
    if sugar.session.mode == "v" then
        vim.api.nvim_input(":m '>+1<CR>gv")
    else
        local lc = win.current_buffer.line_count
        local cur_line = win.cursor.row

        -- Don't move past the end.
        --TODO maybe add extra lines automatically?t
        if lc == cur_line then return end

        vim.api.nvim_command("move +1")
    end
end

local function duplicate_common(up)
    local win = sugar.session.current_window
    local buf = win.current_buffer
    local sel_begin = win.selection_begin.row
    local sel_end   = win.selection_end.row
    local row, column = win.cursor.row, win.cursor.column

    sel_begin, sel_end = math.min(sel_begin, sel_end), math.max(sel_begin, sel_end)

    assert(sel_begin and sel_end)

    local lines = buf:get_line_range(sel_begin-1, sel_end)

    if up then
        buf:set_line_range(sel_begin-1, sel_begin-1, lines)
        win.cursor.row, win.cursor.column = sel_begin, column
    else
        buf:set_line_range(sel_begin-1, sel_begin-1, lines)
        win.cursor.column = column
    end
end

function module.duplicate_lines_up()
    duplicate_common(true)
end

function module.duplicate_lines_down()
    duplicate_common(false)
end

-- A bit different from Ctrl-A as it honors indentation.
function module.home()
    if sugar.session.mode == "v" then
        vim.api.nvim_input("!silent <esc>")
    end

    if sugar.session.mode == "n" then
        vim.api.nvim_input("i")
    end

    local line = sugar.session.current_window.current_line
    local _, indent_end = line:find("^[ ]*")

    if indent_end then
        sugar.session.current_window.cursor.column = indent_end
    end
end

function module.select_to_home()
    sugar.session.current_window.selection_begin.column = 0
    sugar.session.current_window.selection_end.column = 22
end

function module.select_to_end()
    sugar.session.current_window.selection_end.column = 22
end

-- Paste correctly depending on the mode.
function module.paste()
    vim.api.nvim_command("normal! Pl")
end

local function delete_selection_common(keep)
    if sugar.session.mode == "v" then
        local deleter = keep and 'd' or '"_d'

        local win = sugar.session.current_window

        if win.cursor.column > win.current_line_lenght + 1 then
            sugar.normal('h'..deleter)
        else
            sugar.normal(deleter)
        end

        -- Return to input mode.
        vim.api.nvim_input("<esc>i")
    end
end

-- Backspace should not delete the newline.
function module.backspace()
    delete_selection_common(false)
end

-- Same as backspace, but do not blackhole the selection.
function module.cut()
   delete_selection_common(true)
end

return module
