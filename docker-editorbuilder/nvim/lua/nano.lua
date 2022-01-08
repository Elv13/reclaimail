--- Vim modal style is nice and all, but mode/context switch
-- for trivial tasks is not faster than a combo. This module
-- re-implement most of GNU nano behavior so the INPUT mode
-- can have "normal" combo-style bindings.
--
-- This mode tries to have nice and interactive messages when
-- possible.

local sugar = require("sugar")

local module = {}

-- Selection direction can go either way. It makes a lot of code
-- harder. This wrapper simplifies this be returning the lower number
-- first.
function module.selected_range()
    local sel_begin = sugar.session.current_window.selection_begin.row
    local sel_end   = sugar.session.current_window.selection_end.row

    -- The rows are the direction it was selected, it can be reversed.
    local row_start = math.min(sel_begin, sel_end)
    local row_end   = math.max(sel_begin, sel_end)

    return row_start, row_end
end

-- Boilerplate for identical changes over multiple lines in the
-- current buffer.
--
-- The callback gets the current line and line number as parameters.
-- It must return the modified line.
--
function module.for_selected_lines(f)
    local buf = sugar.session.current_window.current_buffer
    local row_start, row_end = module.selected_range()

    row_start = row_start - 1

    local lines = buf:get_line_range(row_start, row_end)

    for k, line in ipairs(lines) do
        lines[k] = f(line, k)
    end

    buf:set_line_range(row_start, row_end, lines)
end

-- Move the cursor to the start (and remove the selection, if any).
function module.cursor_to_start()
    if sugar.session.mode == "v" then
        vim.api.nvim_input("!silent <esc>")
    end

    if sugar.session.mode == "n" then
        vim.api.nvim_input("i")
    end

    sugar.session.current_window.cursor.column = 0
end

-- Move the cursor to the end (and remove the selection, if any).
function module.cursor_to_end()
    -- Note that <End> behaves differently. It will select to the end.
    if sugar.session.mode == "v" then
        vim.api.nvim_input("!silent <esc>")
    end

    -- Its unclear why it works and not vim.str_utfindex(sugar.session.current_window.current_line)
    local len = #sugar.session.current_window.current_line

    -- When in normal mode, it isn't possible to place the cursor at the
    -- end. So we have to wait until the mode switch is completed.
    if sugar.session.mode == "n" then
        vim.api.nvim_input("i")
        sugar.schedule.delayed(function()
            sugar.session.current_window.cursor.column = len
        end)
    else
        sugar.session.current_window.cursor.column = len
    end

end

--- Bring sanity back to search, no idiotic magic by default
function module.search()
    local res = sugar.input.prompt("Search: ")
        :gsub("/", "\\/")

    -- Cancel when the string is empty
    if (not res) or res == "" then return end

    -- "Better" but still broken alternative if magic is enabled
    --vim.api.nvim_input("<cmd>/\\V"..res.."/<cr><esc>n")

    -- This works because nomagic is set.
    local ret, err = pcall(vim.api.nvim_command, "/"..res)
    vim.api.nvim_input("<esc>n")

    if (not ret) and err:find('Pattern not found') then
        sugar.display.warning('[ Pattern not found ]', 2000)
    end
end

function module.search_selected(backward)
    if sugar.session.mode ~= "v" then return end

    local txt = sugar.session.current_window.selected_text:gsub("/", "\\/")

    if #txt == 0 then
        sugar.display.warning('[ The selection is empty! ]', 2000)
        return
    end

    local ret, err = pcall(vim.api.nvim_command, "/"..txt)

    -- Return to normal mode if this was a <c-o> command.
    if sugar.session.mode == "niI" or sugar.session.mode == "v" then
        vim.api.nvim_input("<esc>")
    end

    vim.api.nvim_input("<esc>" .. (backward and "N" or "n"))
end

--- Search and replace without idiotic magic.
-- no more dozen of backslashes per minute...
function module.replace()
    --FIXME support find and replace in a range.
    if sugar.session.mode == "v" then
        vim.api.nvim_input("<esc>:lua require('nano').replace()<cr>")
    end

    local str = sugar.input.prompt("Search: "):gsub("/", "\\/")

    -- Cancel when the string is empty
    if (not str) or str == "" then return end

    local rep = sugar.input.prompt("Replace " ..str.." with: "):gsub("/", "\\/")

    vim.api.nvim_input("<cmd>,$s/\\V"..str.."/"..rep.."/gc<cr>")
end

function module.replace_selected()
    local word = sugar.session.current_window.selected_text:gsub("/", "\\/")

    if #word == 0 then
        sugar.display.warning('[ The selection is empty! ]', 2000)
        return
    end

    local rep = sugar.input.prompt("Replace " ..word.." with: "):gsub("/", "\\/")

    vim.api.nvim_input("<esc><esc>:,$s/\\V"..word.."/"..rep.."/gc<cr>")
end

-- Move to a line (more safely than `<esc>:`).
function module.move_to_line()
    local line = sugar.input.prompt("Enter line number: ")

    if line == "" or not line then
        sugar.display.clear_prompt()
    elseif line:find("^[0-9]+$") then
        vim.api.nvim_input("<cmd>:"..line.."<cr>")
    else
        sugar.display.warning('[ Be reasonable! ]', 2000)
    end
end

-- Save and hide the message 1 second later.
-- This adds a nice interactive feedback. Some people will use
-- this over unstable ssh connections, it is nice to "feel" that
-- it is really saved and not just frozen.
function module.save()
    local buf = sugar.session.current_window.current_buffer

    local line = sugar.session.current_window.current_line

    if buf.file_name == "" then
        local fn = sugar.input.prompt("Enter file name:")
        if fn == "" then return end

        vim.api.nvim_command("write "..fn)

        sugar.emit_signal("filetype")
    else
        vim.api.nvim_command("write")
    end

    -- Restore the empty line indentation.
    if line:find("^[ ]+$") then
        sugar.session.current_window.current_line = line
        sugar.session.current_window.cursor.column = #line
    end

    -- Clear 1 second later
    local timer = vim.loop.new_timer()
    timer:start(1000, 0, vim.schedule_wrap(function()
        vim.api.nvim_command('echomsg ""')
    end))
end

local is_ck_connected, is_ck_transaction, is_ck_skip = false, false, false

-- Remove the current line(s) and add it to the current yank buffer.
-- If the cursor moves, then the previous transaction is dropped
-- and a new one is created.
function module.cut_and_yank_line()
    -- The transaction is only valid while the cursor doesn't move.
    if not is_ck_connected then
        sugar.connect_signal("cursor_moved_i", function()
            if is_ck_transaction and not is_ck_skip then
                is_ck_transaction = false
            end
        end)
        is_ck_connected = true
    end

    is_ck_skip = true

    local win, add_line = sugar.session.current_window, false

    local sel_start, sel_end = module.selected_range()

    sel_start, sel_end = math.min(sel_start, sel_end), math.max(sel_start, sel_end)

    if win.current_buffer.line_count == win.cursor.row then
        -- Cutting normally moves the cursor down. There is nothing down
        -- when the line if empty and it is the end of the file. If the line
        -- is *not* empty, then replace it with an empty one.
    if sugar.session.current_window.current_line == "" and sel_start == sel_end then
            sugar.display.warning('[ Nothing to cut ]', 2000)
            return
        end
        add_line = true
    end

    -- Get the current yank register.
    local v = is_ck_transaction and sugar.global_functions.getreg('"') or ""

    -- Handle visual mode.
    if sel_start ~= sel_end then
        local lines = win:pop_selected_lines()

        for _, line in ipairs(lines) do
            v = v .. "\n" .. line
        end

        -- Quit visual mode now that there is no selection.
        vim.api.nvim_input("!silent <esc>")
    else
        v = v .. "\n" .. sugar.session.current_window.current_line
    end

    -- Update the current yank register.
    sugar.global_functions.setreg('"', v)
    is_ck_transaction = true

    -- Delete the line (into a blackhole).
    vim.api.nvim_del_current_line()

    -- Make sure deleting the last line doesn't cause the cursor to move up
    -- rather than down like it normally would.
    if add_line then
        win.current_buffer:append_lines({""})
        win.cursor.row = win.current_buffer.line_count
    end

    -- Reset the cursor.
    sugar.session.current_window.cursor.column = 0

    -- Delay until the next event loop because `:delete` has
    -- not been done yet.
    sugar.schedule.delayed(function()
        is_ck_skip = false
    end)
end

-- Get rid of the popups, plugins, explorer buffers.
function module.get_real_buffers()
    local ret = {}

    for _, buffer in ipairs(sugar.session.buffers) do
        local _, fn = pcall(function() return buffer.file_name end)
        if buffer.valid and vim.fn.isdirectory(fn) ~= 1 then
            local _, s = pcall(function() return buffer.current_syntax end)
            if buffer.options.modifiable or fn ~= "" and s ~= "netrwlist" then
                table.insert(ret, buffer)
            end
        end
    end

    return ret
end

-- Close the current buffer or quit (ask if modified)
function module.close_buffer()
    local bufs = module.get_real_buffers()
    local count = #bufs

    if count > 1 then
        vim.api.nvim_command("confirm bwipeout")
    elseif count == 1 then
        local _, syntax = pcall(function() return bufs[1].current_syntax end)
        if syntax == "netrwlist" then
            vim.api.nvim_command("quit!")
        else
            vim.api.nvim_command("confirm quit")
        end
    end
end

-- Scroll up all the way to line 1.
function module.scroll_up()
    --
end

-- "Classic" nano style "uncut"
function module.uncut()
    if sugar.session.mode == "v" then
        vim.api.nvim_input('"_d<esc><Home>i')
    end

    local lines = vim.gsplit(sugar.global_functions.getreg('"'), "\n")

    local ll = {}

    for line in lines do
        if not (line == "" and #ll == 0) then
            table.insert(ll, line)
        end
    end

    -- If the current line is empty, delete it. Otherwise, the
    -- auto-indent will clash witht the content and it will have
    -- unexpected extra indent.
    if sugar.session.current_window.current_line:find("^[ ]+$") then
        sugar.session.current_window.cursor.column = 0
        sugar.session.current_window.current_line = ""
    end

    local col = sugar.session.current_window.cursor.column

    -- Allow to paste into random columns.
    if col > 1 then
        local cur = sugar.session.current_window.current_line
        local one, two = cur:sub(1, col), cur:sub(col+1)
        ll[1], ll[#ll] = one..ll[1], ll[#ll]..two
    end

    sugar.session.current_window:insert_lines_above(ll, col > 1)
    sugar.session.current_window.cursor.column = 0
end

-- Replace the default <PageUp> with something that goes to line 1.
function module.page_up()
    local height = sugar.session.current_window.height

    --vim.api.nvim_command("normal! "..height
    sugar.normal(math.floor(height/2).."k")
end

return module
