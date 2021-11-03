-- Re-implement some useful VSCode features.
local sugar = require( "sugar"                 )
local nano  = require( "nano"                  )
local stack = require("dialog._stack"          )
local frame = require("dialog.components.frame")
local label = require("dialog.components.label")
local list  = require("dialog.components.list" )
local input = require("dialog.components.input")

local module = {}

local default_win, global_counter = sugar.session.current_window, 1
local ui = nil

-- Associate an ever increasing number with each buffer. The most recently used
-- has the highest number.
local history = setmetatable({}, {__mode = "k"})

local function get_name(buf)
    local name = buf.file_name

    if name == "" then
        local lines = buf:get_line_range(1,1)
        name = lines[1] and lines[1]:sub(1, 20) or ""
    end

    return name
end

local function gen_display_names()
    local buffers, filtered, valid_buffers = {}, {}, {}
    local bufs, to_crop, most_recent, random_path, idx = nano.get_real_buffers(), 1, 0, {}, 999

    local random_buf = nil

    -- Make sure the buffer we use for comparison is not <Empty>
    for i=1, #bufs do
        random_buf = bufs[1]
        if random_buf.file_name ~= "" then break end
    end

    -- Take the first entry and convert its path into a table.
    for part in vim.gsplit(random_buf and random_buf.file_name or "", "/") do
        table.insert(random_path, tostring(part))
    end

    -- Find the most distant common directory and crop there.
    for _, buf in ipairs(bufs) do
        if buf.file_name ~= "" then
            local common, k, match = 0, 1, false

            for dir in vim.gsplit(buf.file_name, "/") do
                match = true

                if random_path[k] == dir then
                    common = k
                else
                    break
                end
                k = k +1
            end

            if match then
                idx = math.min(idx, common)
                table.insert(valid_buffers, buf)
            end
        end
    end

    idx = math.min(idx, #random_path)

    -- Otherwise it will display an empty name when there's only 1 buffer.
    if #valid_buffers == 1 then
        idx = idx - 1
    end

    -- Compute the number of characters to remove from each buffer name.
    for i=1, idx do
        to_crop = to_crop + string.len(random_path[i] or "") + 1
    end

    -- Sort the entries by most recently visited.
    for _, buf in ipairs(bufs) do
        if buf.options.modifiable then
            local idx = ((history[buf] or 0) > most_recent) and 1 or #buffers+1
            table.insert(buffers, idx, buf)
            table.insert(filtered, idx, buf)
            most_recent = math.max(history[buf] or 0, most_recent)
        end
    end

    -- Display the buffers.
    for _, buf in ipairs(filtered) do
        if buf.valid then
            local name = get_name(buf)

            if buf.file_name == "" then
                local lines = buf:get_line_range(1,1)
                name = lines[1] and lines[1]:sub(1, 20) or "<Empty>"
            else
                name = name:sub(to_crop)
            end
            rawset(buf,"short_file_name", name)
        end
    end

    return buffers, filtered
end

local function increment_global()
    local buf = sugar.session.current_window.current_buffer
    if history[buf] == global_counter then return end

    history[buf] = global_counter
    global_counter = global_counter + 1

    local short_name = rawget(buf, "short_file_name")

    -- Refresh the relative paths.
    if (not short_name) or (short_name == "<Empty>" and buf.file_name ~= "") then
        gen_display_names()
    end
end

-- Count the buffer change "ticks" for ordering.
sugar.connect_signal("buf_enter", increment_global)
sugar.connect_signal("buf_file_post", increment_global)
sugar.connect_signal("filetype", increment_global)

local search_modes, current_search_mode = {
    "Open", "Project", "Git"
}, 1

local function create_ui(w, h)
    if ui then return ui end

    ui = {}

    local s = stack{height=h, width=w}
    local f = frame(w, h)

    f:add_label("Buffer switcher", "center", "top")
    f:add_label("center", "center", "bottom")
    f:add_label("left", "left", "top")
    f:add_label("left", "left", "bottom")
    f:add_label("right", "right", "top")
    f:add_label("right", "right", "bottom")

    local lst  = list(10, 10)
    local lbl2 = label(10, 1, search_modes[current_search_mode])
    local lbl3 = label(10, 1, "Use <Tab> and <Up/Down> to navigate")
    local lbl4 = input(10, 1, "Filter: ")

    local h1, h2 = f.layout:horizontal_split_top(1, true, true)
    local v1, v2 = h1:vertical_split_right(10, true, true)

    v2.widget = lbl2
    v1.widget = lbl3

    local h3, h4 = h2:horizontal_split_bottom(1, true,true)
    h4.widget = lst
    h3.widget = lbl4

    s:add_widget(f)

    ui.lst = lst
    ui.mode = lbl2
    ui.stack = s
    ui.filter = lbl4


    ui.filter.keymap:inherit(global_keymap)

    ui.filter.keymap["Up"] = function()
        ui.lst:select_up()
        ui.stack:draw(ui.buf)
    end

    ui.filter.keymap["Down"] = function()
        ui.lst:select_down()
        ui.stack:draw(ui.buf)
    end

    ui.filter.keymap["Left"] = function()
        print("Left")
    end

    ui.filter.keymap["Right"] = function()
        print("Right")
    end

    ui.filter.keymap["<esc>"] = function(self) self:stop() end
    ui.filter.keymap["<CR>" ] = function(self)
        local sel = ui.lst.selected
        if not ui.filtered[sel] then
            self:stop()
            return
        end
        assert(ui.filtered[sel])
        sugar.session.current_window.current_buffer = ui.filtered[sel]
        self:stop()
        increment_global()
    end

    ui.filter.keymap["<Tab>"] = function()
        current_search_mode = current_search_mode + 1
        if current_search_mode == 4 then current_search_mode = 1 end
        ui.mode.text = search_modes[current_search_mode]
        ui.stack:draw(ui.buf)
    end

    local function filter()
        ui.filtered = {}

        ui.lst:clear()

        for _, buf in ipairs(ui.buffers) do
            local name = get_name(buf)
            if ui.filter.value == "" or name:lower():find(ui.filter.value:lower()) then
                table.insert(ui.filtered, buf)
                local n = rawget(buf, "short_file_name")
                ui.lst:append_line((n == "" or not n)  and "<Empty>" or n)
            end
        end

        ui.stack:draw(ui.buf)
    end

    ui.filter.keymap:connect_signal("key", filter)
    ui.filter.keymap:connect_signal("backspace", filter)

    ui.filter.keymap:connect_signal("stopped", function(self, key)
        if ui.latest_win then
            ui.latest_win:close()
        end
        ui.latest_win = nil
    end)


end

function module.buf_nav()

    local buf = sugar.buffer {
        listed  = false,
        scratch = true,
        options = {
            buftype = "nofile"
        }
    }

    local w, h = 60, 20

    buf.options.modifiable = false
    buf.options.readonly = true
--     buf.options.mouse = "c"

    create_ui(w, h)
    ui.buf = buf

    ui.lst:clear()
    ui.filter:clear()

    local buffers, filtered = gen_display_names()
    ui.buffers, ui.filtered = buffers, filtered

    for _, buf in ipairs(ui.filtered) do
        local n = rawget(buf, "short_file_name")
        ui.lst:append_line((n == "" or not n)  and "<Empty>" or n)
    end

    if #buffers >  1 then
        ui.lst.selected = 2
    end

    ui.stack:draw(buf)

    --vim.api.nvim_buf_add_highlight(buf._private.handle, -1, Normal

    local col = math.floor((default_win.width  - w) / 2)
    local row = math.floor((default_win.height - h) / 2)

    ui.latest_win = sugar.window {
        buffer   = buf,
        relative = 'editor',
        width    = w,
        height   = h,
        row      = row,
        column   = col,
        style    = "minimal",
        options  = {
            number = false
        }
    }
    ui.filter.keymap:grab()
end

gen_display_names()

return module
