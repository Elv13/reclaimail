-- Higher level library wrapping nvim.
local sugar  = require( "sugar"       )
local modes  = require( "sugar.modes" )
local keymap = require( "sugar.keymap")

-- Compat layer to use features/behavior I like from other editors.
local nano   = require( "nano"   )
local kate   = require( "kate"   )
local vscode = require( "vscode" )

-- Little helper functions to execute commands from insert mode
local function cmd2(command) return function() vim.api.nvim_command(command) end end

--------------------------------------------------------------------
--                     PLUGIN VARIABLES                           --
--------------------------------------------------------------------

-- Add the git changes bar
sugar.session.gitgutter_sign_added    = '┃'
sugar.session.gitgutter_sign_modified = '┃'
sugar.session.gitgutter_sign_removed  = '┃'
sugar.session.netrw_altfile = 1

--------------------------------------------------------------------
--                          OPTIONS                               --
--------------------------------------------------------------------

sugar.session.options.t_Co = "256"

-- Switch buffer without saving, the buffer management code will
-- take care of not exiting unsaved buffers.
sugar.session.options.hidden = true

-- sugar.session.options.iskeyword = "a-z,A-Z,48-57,_,.,-,>, "

--FIXME
--sugar.session.options.shiftwidth      = 4 -- does nothing
--sugar.session.options.number          = "relativenumber" -- wants a boolean
--sugar.session.options.colorscheme     = "elflord" -- rejected
--sugar.session.options.notermguicolors = true -- rejected

local default_win = sugar.session.current_window

default_win.options.number = true
default_win.options.relativenumber = true

local relative_modes = {
    n = true,
    v = true,
}

-- Use relative or absolute numbers depending on the mode.
local function set_number_absolute()
    default_win.options.relativenumber = relative_modes[sugar.session.mode] or false
end

-- Connect to some global signals to detect when the mode changes.
for _, sig in ipairs { "buf_enter", "focus_gained", "insert_leave",
                       "buf_leave", "focus_lost"  , "insert_enter" } do
    sugar.connect_signal(sig, set_number_absolute)
end

--------------------------------------------------------------------
--                           KEYMAP                               --
--------------------------------------------------------------------

-- The keys *everything* should honor.
global_keymap = keymap {}
modes.insert.keymap:inherit(global_keymap)
modes.normal.keymap:inherit(global_keymap)
modes.visual.keymap:inherit(global_keymap)
modes.command.keymap:inherit(global_keymap)

-- Move to the begening of the line
global_keymap["<C-e>"] = nano.cursor_to_end

-- map CTRL-A to beginning-of-line (insert mode)
global_keymap["<C-a>"] = nano.cursor_to_start
modes.insert.keymap["<Home>"] = kate.home

-- CTRL-U to uncut (paste the cut buffer)
global_keymap["<C-u>"] = nano.uncut

-- CTRL+O to save
global_keymap["<C-s>"] = nano.save

-- CTRL+o to Open
global_keymap["<C-o>"] = kate.open

-- CTRL+W to search (insert mode)
global_keymap["<C-w>"] = nano.search
global_keymap["<C-f>"] = nano.search
modes.normal.keymap["<esc>"] = cmd2 "silent noh"
modes.visual.keymap["<esc>"] = "<esc>"

-- map CTRL+R to search and replace
global_keymap["<C-r>"] = nano.replace

-- CTRL+_ goto line (insert mode)
global_keymap["<C-_>"] = nano.move_to_line
global_keymap["<C-g>"] = nano.move_to_line

-- CTRL+X to save and quit (do not use in visual mode, it gets annoying
-- to close rather tham cut using reflexes).
for _, m in ipairs {modes.insert, modes.normal, modes.command} do
    m.keymap["<C-x>"] = nano.close_buffer
end

-- map CTRL+K to act like nano "cut buffer" (insert mode)
global_keymap["<C-k>"] = nano.cut_and_yank_line

-- CTRL+BackSpace: remove word to the left
--modes.insert.keymap["<C-BS>"] = norm "hdvb"
--modes.insert.keymap <C-h> <esc>dvbi
--map <C-h> <esc>dvbi
modes.normal.keymap ["<C-BS>"] = "dvbi"
modes.command.keymap["<C-Bs>"] = "<C-w>"

-- Undo
global_keymap["<C-z>"  ] = sugar.commands.undo
global_keymap["<C-A-z>"] = sugar.commands.redo

-- Move line up and down
global_keymap["<C-S-Up>"  ] = kate.move_lines_up
global_keymap["<C-S-Down>"] = kate.move_lines_down

-- Duplicate lines
global_keymap["<C-A-Up>"  ] = kate.duplicate_lines_up
global_keymap["<C-A-Down>"] = kate.duplicate_lines_down

-- Indentation (make sure not to touch command mode `<Tab>`)
for _, m in ipairs {modes.insert, modes.normal, modes.visual} do
    m.keymap["<Tab>"  ] = kate.indent( 1)
    m.keymap["<S-Tab>"] = kate.indent(-1)
end

-- Select chars when Shift is pressed
modes.normal.keymap["<S-Right>"] = "vl"
modes.insert.keymap["<S-Right>"] = "<esc>lvl"
modes.normal.keymap["<S-Up>"   ] = "vk"
modes.insert.keymap["<S-Up>"   ] = "<esc>vk"
modes.normal.keymap["<S-Down>" ] = "vj"
modes.insert.keymap["<S-Down>" ] = "<esc>vj"
modes.normal.keymap["<S-Left>" ] = "vh"
modes.insert.keymap["<S-Left>" ] = "<esc>vh"

-- Shift+Arrow Select the line above and below
modes.visual.keymap["<S-Up>"   ] = "<Up>"
modes.visual.keymap["<S-Down>" ] = "<Down>"
modes.visual.keymap["<S-Left>" ] = "<Left>"
modes.visual.keymap["<S-Right>"] = "<Right>"

-- Delete or cut selection.
modes.normal.keymap["<BS>" ] = "dh"
modes.visual.keymap["<BS>" ] = kate.backspace
modes.visual.keymap["d"    ] = kate.cut
modes.visual.keymap["<C-x>"] = kate.cut

-- Select next word
modes.normal.keymap["<C-S-Right>"] = "vw"
modes.insert.keymap["<C-S-Right>"] = "<esc>vw"
modes.normal.keymap["<C-S-Left>" ] = "v<C-Left>"
modes.insert.keymap["<C-S-Left>" ] = "<esc>v<C-Left>"
modes.visual.keymap["<C-S-Left>" ] = "<C-Left>"
modes.visual.keymap["<C-S-Right>"] = "<C-Right>"

-- Select line
modes.insert.keymap["<S-End>" ] = "<esc>v<End>"
modes.insert.keymap["<S-Home>"] = "<esc>v<Home>"
modes.visual.keymap["<S-Home>"] = kate.select_to_home
modes.visual.keymap["<Home>"  ] = kate.select_to_home
modes.visual.keymap["<S-End>" ] = kate.select_to_end
modes.visual.keymap["<End>"   ] = kate.select_to_end

-- Easy buffer switch
global_keymap["<C-T>"    ] = kate.previous_buffer
global_keymap["<C-S-T>"  ] = kate.next_buffer
global_keymap["<A-Left>" ] = kate.previous_buffer
global_keymap["<A-Right>"] = kate.next_buffer
global_keymap["<C-q>"    ] = vscode.buf_nav
--global_keymap["<C-Tab>"  ] = vscode.buf_nav

-- Configured on caps-lock for me, single tap enter NORMAL, 2
-- tap enter buffer select. F2 is the dumb terminals fallback
modes.normal.keymap["<F14>"] = vscode.buf_nav
modes.normal.keymap["<F2>" ] = vscode.buf_nav

-- Single command
global_keymap["<F14>"] = "<C-o>"
global_keymap["<F2>" ] = "<C-o>"

-- New buffer
global_keymap["<C-N>"] = kate.new

-- Comment / uncomment current line(s).
global_keymap["<C-d>"   ] = kate.comment
global_keymap["<C-A-d>" ] = kate.uncomment

-- Completion
global_keymap["<C-Space>"] = "<C-p>"

-- Copy (yank)
global_keymap["<C-c>"] = kate.copy

-- Paste.
global_keymap      ["<C-v>"] = kate.paste
modes.normal.keymap["p"    ] = kate.paste

-- Disable insert mode, it's always an accident.
modes.normal.keymap["<Insert>"] = function() end

-- Return to INSERT from VISUAL.
modes.visual.keymap["i"] = "<esc>i"

-- Allow <CR> in NORMAL mode.
modes.normal.keymap["<CR>"] = "i<CR><esc>"

-- Fix PageUp to behave like veryone (including Vim PageDown)
global_keymap["<PageUp>"] = nano.page_up

-- Test

global_keymap["<C-b>"] = function()
    -- sugar.session.current_window.selection_begin.column = 0
    sugar.session.current_window.cursor.column = 10
    sugar.session.current_window.cursor.row = 10
    -- sugar.session.current_window.selection_begin.row = 22
    -- sugar.session.current_window.selection_begin.column = 22

    --sugar.session.current_window.options.laststatus = 0
    --sugar.session.current_window.options.statusline = "lol\nbar"
    --
    print(sugar.global_functions.setpos("'>", {
        0,--self._private.window and self._private.window._private.handle or 0,
        22,
        22,
        0,
        0
    }))

    print(sugar.global_functions.setpos("'<", {
        0,--self._private.window and self._private.window._private.handle or 0,
        33,
        33,
        0,
        0
    }))


end



local function ertertert()
    local stack = require("dialog._stack")
    local input = require("dialog.components.input")
    local frame = require("dialog.components.frame")
    local s = stack{height=3, width=80}
    local f = frame(80, 3)
    f:add_label("Buffer switcher", "center", "top")
    f.layout.widget = input(40, 1, "test!")
    s:add_widget(f)

    f.layout.widget.keymap["<esc>"] = function(self) self:stop() end

    s:print()

    f.layout.widget.keymap:grab()
end

-- Add a color
local function add_highlight(args)
    local param = " "

    for k, v in pairs(args) do
        if k ~= "name" then
            param = param .. k.."="..v.." "
        end
    end

    vim.api.nvim_command("hi "..args.name..param)
end

-- Powerline like mode names
local mode_names = {
    ['n' ] = 'Normal'   ,
    ['no'] = 'Normal·OP',
    ['v' ] = 'Visual'   ,
    ['V' ] = 'V·Line'   ,
    ['^V'] = 'V·Block'  ,
    ['s' ] = 'Select'   ,
    ['S' ] = 'S·Line'   ,
    ['^S'] = 'S·Block'  ,
    ['i' ] = 'Insert'   ,
    ['R' ] = 'Replace'  ,
    ['Rv'] = 'V·Replace',
    ['c' ] = 'Command'  ,
    ['cv'] = 'Vim Ex'   ,
    ['ce'] = 'Ex'       ,
    ['r' ] = 'Prompt'   ,
    ['rm'] = 'More'     ,
    ['r?'] = 'Confirm'  ,
    ['!' ] = 'Shell'    ,
    ['t' ] = 'Terminal' ,
}

sugar.session.currentmode = mode_names

local line_number_color = {
    ['Normal'   ] = {
        LineNr      = {ctermfg = 255, ctermbg = 124 }, PowerColor1 = {ctermfg = 255, ctermbg = 124},
        PowerColor2 = {ctermfg = 255, ctermbg = 202 }, PowerColor3 = {ctermfg = 255, ctermbg = 172},
        PowerColor4 = {ctermfg = 255, ctermbg = 28  }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 234 }, TopStatus   = {ctermfg = 255, ctermbg = 196, cterm="bold" }
    },
    ['Normal·OP'] = {
        LineNr      = {ctermfg = 67 , ctermbg = 233}, PowerColor1 = {ctermfg = 255, ctermbg = 52 },
        PowerColor2 = {ctermfg = 67 , ctermbg = 233}, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 13 }, TopStatus   = {ctermfg = 255, ctermbg = 124, cterm="bold" }
    },
    ['Visual'   ] = {
        LineNr      = {ctermfg = 255, ctermbg = 54 }, PowerColor1 = {ctermfg = 255, ctermbg = 54, cterm="bold" },
        PowerColor2 = {ctermfg = 16 , ctermbg = 33 }, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 18 }, TopStatus   = {ctermfg = 255, ctermbg = 93, cterm="bold" }
    },
    ['V·Line'   ] = {
        LineNr      = {ctermfg = 67 , ctermbg = 233}, PowerColor1 = {ctermfg = 255, ctermbg = 52 },
        PowerColor2 = {ctermfg = 67 , ctermbg = 233}, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 13 }, TopStatus   = {ctermfg = 255, ctermbg = 124, cterm="bold" }
    },
    ['V·Block'  ] = {
        LineNr      = {ctermfg = 67 , ctermbg = 233}, PowerColor1 = {ctermfg = 255, ctermbg = 52 },
        PowerColor2 = {ctermfg = 67 , ctermbg = 233}, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 13 }, TopStatus   = {ctermfg = 255, ctermbg = 124, cterm="bold" }
    },
    ['Insert'   ] = {
        LineNr      = {ctermfg = 16 , ctermbg = 33  }, PowerColor1 = {ctermfg = 255 , ctermbg = 33, cterm="bold" },
        PowerColor2 = {ctermfg = 255, ctermbg = 201 }, PowerColor3 = {ctermfg = 255, ctermbg = 28 },
        PowerColor4 = {ctermfg = 255, ctermbg = 201 }, PowerColor0 = {ctermfg = 67 , ctermbg = 233},
        Middle      = {ctermfg = 12 , ctermbg = 7   }, TopStatus   = {ctermfg = 255, ctermbg = 25, cterm="bold" }
    },
}

line_number_color['Select'    ] = line_number_color.Normal
line_number_color['S·Line'    ] = line_number_color.Normal
line_number_color['S·Block'   ] = line_number_color.Normal
line_number_color['Replace'   ] = line_number_color.Normal
line_number_color['V·Replace' ] = line_number_color.Normal
line_number_color['Command'   ] = line_number_color.Normal
line_number_color['Vim Ex'    ] = line_number_color.Normal
line_number_color['Ex'        ] = line_number_color.Normal
line_number_color['Prompt'    ] = line_number_color.Normal
line_number_color['More'      ] = line_number_color.Normal
line_number_color['Confirm'   ] = line_number_color.Normal
line_number_color['Shell'     ] = line_number_color.Normal
line_number_color['Terminal'  ] = line_number_color.Normal

-- Change the line number bar color and relative_ln depending on the mode
local function update_numbar(mode)
    if not mode then return end

    local theme = line_number_color[mode]

    add_highlight {
        name    = "LineNr",
        ctermfg = theme.LineNr.ctermfg,
        ctermbg = theme.LineNr.ctermbg,
    }

    add_highlight {
        name    = "LineNrInvert",
        ctermbg = theme.LineNr.ctermfg,
        ctermfg = theme.LineNr.ctermbg,
    }

    add_highlight {
        name    = "TopStatus",
        ctermfg = theme.TopStatus.ctermfg,
        ctermbg = theme.TopStatus.ctermbg,
        cterm   = theme.TopStatus.cterm,
    }

    add_highlight {
        name    = "TopStatusInvert",
        ctermfg = theme.TopStatus.ctermbg,
        ctermbg = theme.LineNr.ctermbg,
    }

    -- All powerline colors
    for i=0, 4, 2 do
        local idx = math.floor(i/2) + 1

        add_highlight {
            name    = "StatusLine"..(i+1),
            cterm   = theme["PowerColor"..idx].cterm,
            ctermfg = theme["PowerColor"..idx].ctermfg,
            ctermbg = theme["PowerColor"..idx].ctermbg,
        }
        add_highlight {
            name    = "StatusLineL"..(i+2),
            ctermfg = theme["PowerColor"..(idx  )].ctermbg,
            ctermbg = theme["PowerColor"..(idx+1)].ctermbg,
        }
        add_highlight {
            name    = "StatusLineR"..(i+2),
            ctermbg = theme["PowerColor"..(idx  )].ctermbg,
            ctermfg = theme["PowerColor"..(idx+1)].ctermbg,
        }
    end

    local timer = vim.loop.new_timer()
    timer:start(0, 0, vim.schedule_wrap(function()
        vim.api.nvim_command("redraw!")
    end))

    -- Use relative number for everything but insert mode
    sugar.session.options.relativenumber = mode ~= "Insert"
end

add_highlight {
    name    = "StatusLine",
    ctermfg = 123,
    ctermbg = 111,
}

add_highlight {
    name    = "User1",
    ctermfg = 241,
    ctermbg = 28,
}

local prev_mode = ""

local left_delim, right_delim = "", ""

local function add_color_section(ret, text, color_idx, last, left_or_right)
    local color1 = "%#StatusLine"..(color_idx+1).."#"
    local color2 = "%#StatusLine"..(left_or_right == "left" and "L" or "R")..(color_idx).."#"

    local delim = left_or_right == "right" and right_delim or left_delim

    assert(left_or_right == "right" or left_or_right == "left")

    if left_or_right == "right" and color_idx == 0 then
        ret = ret.."%#StatusMiddleR#"..delim..color1
    elseif left_or_right == "right" then
        ret = ret..color2..delim..color1
    end

    if color_idx > 0 and left_or_right == "left" then
        ret = ret.." "..color2..delim.." "
    elseif left_or_right == "right" then
        ret = ret..text.." "..color2
    end

    if left_or_right == "left" then
        ret = ret..color1..text

        if last then
            ret = ret.." %#StatusMiddleL#"..delim
        end
    end

    return ret, color_idx+2
end

local append_fcts = {
    left   = function(q,e,r,t) return add_color_section(q,e,r,t, "left") end,
    middle = function(ret) return ret .. "%#StatusMiddleL# %= " end,
    right  = function(q,e,r,t) return add_color_section(q,e,r,t, "right") end
}

-- Cheap trick to know when the mode changes...
function status_update_callback(mode_raw)
    local stacks = {left = {}, right = {}, middle = {}}

    -- Rather than trying to create the statusline string directly,
    -- build the structure, then concatenate it later.
    local function push_to_stack(stack, content, args)
        -- Allow future `args` to extend the system.
        table.insert(stack, {content=content,args=args})
    end

    local mode = mode_names[mode_raw:gmatch("[ ]*([^ ]+)")()] or "Normal"

    if prev_mode ~= mode then
        update_numbar(mode)
        prev_mode = mode
    end

    local ret, color_idx = "", 0

    push_to_stack(stacks.left, " "..mode:upper())
    push_to_stack(stacks.left, "%f")
    push_to_stack(stacks.left, "%Y")

    push_to_stack(stacks.middle, "%=")

    push_to_stack(stacks.right, " Shift: "..sugar.session.options.shiftwidth)
    push_to_stack(stacks.right, " %l/%L (%p%%) : %c ")
    push_to_stack(stacks.right, "  NeoVIM %{SearchCount()} ")

    -- Before creating the content, set the final colors.
    local theme = line_number_color[mode]

    add_highlight {
        name    = "StatusMiddleL",
        ctermfg = theme["PowerColor"..#stacks.left].ctermbg,
        ctermbg = theme.Middle.ctermbg,
    }

    add_highlight {
        name    = "StatusMiddleR",
        ctermfg = theme["PowerColor1"].ctermbg,
        ctermbg = theme.Middle.ctermbg,
    }

    for _, dir in ipairs {"left", "middle", "right" } do
        color_idx = 0
        local section = ""
        for k, elem in ipairs(stacks[dir]) do
            local is_last = k == #stacks[dir] --(dir == "left" and k == #stacks[dir]) or (dir == "right" and k == 1)
            section, color_idx = append_fcts[dir](section, elem.content, color_idx, is_last)
        end
        ret = ret..section
    end

    --assert(false,ret)
    print(ret)
    return ""
end

function tab_update_callback(mode_raw, buf_num)
    local ret= ""
    local bufs = nano.get_real_buffers()

    buf_num = buf_num:gmatch("[ ]*([^ ]+)")()

    buf_num1 = string.byte(buf_num:sub(1,1))..string.byte(buf_num:sub(2,2))

    local buf = sugar.session.current_window.current_buffer
    local cur = buf._private.handle

    for _, buf in ipairs(bufs) do
        local name = rawget(buf, "short_file_name") or buf.file_name
        name = name == "" and "<Empty>" or name
        if buf._private.handle ~= cur then
            ret = ret .. "| " .. (rawget(buf, "short_file_name") or name) .. " "
        else
            ret = ret .. "|%#LineNrInvert# " .. (rawget(buf, "short_file_name") or name).." %#LineNr#"
        end
    end

    local kw = "TODO" --sugar.session.options.iskeyword

    -- Add some +++ to align the tabs with the window content
    local lc,prefix = buf.line_count/100, "   "
    while lc > 10 do
        prefix = prefix .. " "
        lc = lc / 10
    end

    print("%#LineNr#"..prefix..ret.." %= %#TopStatusInvert#%#TopStatus# %f  "..kw.."  NeoVIM  ")
end

sugar.session.options.statusline = "%!StatusUpdateCallback(mode(),mode())"

sugar.session.options.showtabline = 2
sugar.session.options.tabline = "%!TabUpdateCallback(mode(),'%n')"