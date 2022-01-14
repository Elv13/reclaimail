-- Higher level library wrapping nvim.
local sugar  = require( "sugar"       )
local modes  = require( "sugar.modes" )
local keymap = require( "sugar.keymap")

-- Compat layer to use features/behavior I like from other editors.
local nano      = require( "nano"      )
local kate      = require( "kate"      )
local vscode    = require( "vscode"    )
local selection = require( "selection" )

require("theme")

-- Little helper functions to execute commands from insert mode
local function cmd2(command) return function() vim.api.nvim_command(command) end end
local function norm(command) return function() vim.api.nvim_command("normal! "..command) end end

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

-- Sane selection
sugar.session.options.selection = "exclusive"
sugar.session.options.virtualedit = "onemore"

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
local has_numbers = true

default_win.options.number = has_numbers
default_win.options.relativenumber = has_numbers

local relative_modes = {
    n = true,
    v = true,
}

local function toggle_numbers()
    has_numbers = not has_numbers

    if not has_numbers then
        default_win.options.number = false
        default_win.options.relativenumber = false
    else
        default_win.options.number = true
        default_win.options.relativenumber = relative_modes[sugar.session.mode] or false
    end
end

-- Use relative or absolute numbers depending on the mode.
local function set_number_absolute()
    if has_numbers then
        default_win.options.relativenumber = relative_modes[sugar.session.mode] or false
    end
end

-- Connect to some global signals to detect when the mode changes.
for _, sig in ipairs { "buf_enter", "focus_gained", "insert_leave",
                       "buf_leave", "focus_lost"  , "insert_enter" } do
    sugar.connect_signal(sig, set_number_absolute)
end

sugar.connect_signal("mode_change", set_number_absolute)

-- Hack for `noremap <c-o>` to work properly...
sugar.connect_signal("force_absolute", function()
    sugar.schedule.delayed(function()
        if has_numbers then
            default_win.options.relativenumber = true
        end
    end)
end)

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

-- Toggle line numbers.
global_keymap["<F10>"] = toggle_numbers

-- CTRL+W to search (insert mode)
global_keymap["<C-w>"] = nano.search
global_keymap["<C-f>"] = nano.search
modes.normal.keymap["<esc>"] = cmd2 "silent noh"
modes.visual.keymap["<esc>"] = "<esc>"
modes.visual.keymap["n"] = nano.search_selected
modes.visual.keymap["N"] = function() nano.search_selected(true) end
modes.visual.keymap["m"] = function() nano.search_selected(true) end
modes.normal.keymap["m"] = "N"

-- map CTRL+R to search and replace
global_keymap["<C-r>"] = nano.replace
modes.visual.keymap['r'] = nano.replace_selected

-- CTRL+_ goto line (insert mode)
global_keymap["<C-_>"] = nano.move_to_line
global_keymap["<C-g>"] = nano.move_to_line

-- CTRL+X to save and quit (do not use in visual mode, it gets annoying
-- to close rather tham cut using reflexes).
for _, m in ipairs {modes.insert, modes.normal, modes.command, modes.visual} do
    m.keymap["<C-x>"] = nano.close_buffer
end

-- map CTRL+K to act like nano "cut buffer" (insert mode)
global_keymap["<C-k>"] = nano.cut_and_yank_line

-- CTRL+BackSpace: remove word to the left
modes.insert.keymap["<C-H>"] = norm "db" -- Konsole
modes.normal.keymap["<C-H>"] = "dvb" -- konsole
--modes.insert.keymap <C-h> <esc>dvbi
--modes.normal.keymap ["<C-BS>"] = "dvbi"
--modes.command.keymap["<C-Bs>"] = "<C-w>"

-- Undo
global_keymap["<C-z>"  ] = sugar.commands.undo
global_keymap["<C-A-z>"] = sugar.commands.redo

-- Move line up and down
modes.normal.keymap["<C-S-Up>"  ] = kate.move_lines_up
modes.insert.keymap["<C-S-Up>"  ] = kate.move_lines_up
modes.insert.keymap["<C-S-Down>"] = kate.move_lines_down
--modes.normal.keymap["<C-S-Down>"] = kate.move_lines_down

modes.visual.keymap["<C-S-Up>"  ] = ":m -2<CR>gv" -- kate.move_lines_up
modes.visual.keymap["<C-S-Down>"  ] = ":m '>+1<CR>gv" -- kate.move_lines_up

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
--modes.visual.keymap["<C-x>"] = kate.cut

-- Select next word
--TODO "iw" is very cool, but doesn't work backward the same way it
--works forward. `iskeyword` needs to be modified?
modes.normal.keymap["<C-S-Right>"] = "vw"
modes.insert.keymap["<C-S-Right>"] = "<esc>lvw" --FIXME need a function to check for ^ and $
modes.normal.keymap["<C-S-Left>" ] = "vb"
modes.insert.keymap["<C-S-Left>" ] = "<esc>lvb"
modes.visual.keymap["<C-S-Left>" ] = "b"
modes.visual.keymap["<C-S-Right>"] = "w"
modes.visual.keymap["<C-Right>"  ] = "w"

--modes.visual.keymap["<C-Left>"   ] = "b"

-- Move to next word. --FIXME
modes.normal.keymap["<C-Right>"  ] = "w" -- yes, the iskeyword is different
modes.normal.keymap["<C-Left>"   ] = "b"
-- modes.insert.keymap["<C-Right>"] = norm "iw"
-- modes.normal.keymap["<C-Right>"] = "iw"
-- modes.insert.keymap["<C-Left>" ] = norm "b"
-- modes.normal.keymap["<C-Left>" ] = "b"


-- Select line
modes.insert.keymap["<S-End>" ] = "<esc>lv$"
modes.insert.keymap["<S-Home>"] = "<esc>lv^"
modes.visual.keymap["<S-Home>"] = "^" --kate.select_to_home
modes.visual.keymap["<Home>"  ] = "^"
modes.visual.keymap["<S-End>" ] = "$" --kate.select_to_end
modes.visual.keymap["<End>"   ] = "$"
modes.normal.keymap["<S-End>" ] = "v$"
modes.normal.keymap["<S-Home>"] = "lv^"

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
modes.insert.keymap["<F14>"] = "<C-o>:lua require('sugar').emit_signal('force_absolute')<CR><C-o>"
modes.insert.keymap["<F2>" ] = "<C-o>:lua require('sugar').emit_signal('force_absolute')<CR><C-o>"
modes.visual.keymap["<F14>"] = "<esc><esc><C-o>"
modes.visual.keymap["<F2>"] = "<esc><esc><C-o>"

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
--modes.normal.keymap["i"] = function() sugar.commands.startinsert() end

-- Allow <CR> in NORMAL mode.
modes.normal.keymap["<CR>"] = "i<CR><esc>"

-- Fix PageUp to behave like veryone (including Vim PageDown)
global_keymap["<PageUp>"] = nano.page_up

-- Match bracket
modes.normal.keymap["\\"] = "%"

-- Disable F1 because it is close to escape and I keep hitting it
global_keymap["<F1>"] = function() end

-- Select block.
for mode, prefix in pairs {normal = "v", visual = ""} do
    modes[mode].keymap['"'] = prefix.."i'"
    modes[mode].keymap["'"] = prefix..'i"'
    modes[mode].keymap["`"] = prefix..'i`'
    modes[mode].keymap[','] = "<esc>F,lvf,h"
    modes[mode].keymap['.'] = "<esc>F.lvf.h"
    modes[mode].keymap['('] = prefix.."i("
    modes[mode].keymap[')'] = prefix.."i("
    modes[mode].keymap['['] = prefix.."i["
    modes[mode].keymap[']'] = prefix.."i["
    modes[mode].keymap['{'] = prefix.."i{"
    modes[mode].keymap['}'] = prefix.."i}"

    -- 'a' is close to caps-lock, which is assigned to C-o somewhere else
    -- in this file. This is an "express" way to select to current word.
    modes[mode].keymap['a'] = prefix.."iw"
end

modes.normal.keymap['<Space>'] = selection.select_current_construct
modes.visual.keymap['<Space>'] = selection.select_current_construct

-- Jump to previous/next location.
modes.normal.keymap["-"] = "g;"
modes.normal.keymap["="] = "g,"

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
        Middle      = {ctermfg = 12 , ctermbg = 234 }, TopStatus   = {ctermfg = 255, ctermbg = 196, bold= true },
        MsgArea     = {ctermfg = 255, ctermbg = 234 }
    },
    ['Normal·OP'] = {
        LineNr      = {ctermfg = 67 , ctermbg = 233}, PowerColor1 = {ctermfg = 255, ctermbg = 52 },
        PowerColor2 = {ctermfg = 67 , ctermbg = 233}, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 13 }, TopStatus   = {ctermfg = 255, ctermbg = 124, bold= true },
        MsgArea     = {ctermfg = 255, ctermbg = 234 }
    },
    ['Visual'   ] = {
        LineNr      = {ctermfg = 255, ctermbg = 54 }, PowerColor1 = {ctermfg = 255, ctermbg = 54, bold= true },
        PowerColor2 = {ctermfg = 16 , ctermbg = 33 }, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 18 }, TopStatus   = {ctermfg = 255, ctermbg = 93, bold= true },
        MsgArea     = {ctermfg = 255, ctermbg = 54 }
    },
    ['V·Line'   ] = {
        LineNr      = {ctermfg = 67 , ctermbg = 233}, PowerColor1 = {ctermfg = 255, ctermbg = 52 },
        PowerColor2 = {ctermfg = 67 , ctermbg = 233}, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 13 }, TopStatus   = {ctermfg = 255, ctermbg = 124, bold= true },
        MsgArea     = {ctermfg = 255, ctermbg = 54 }
    },
    ['V·Block'  ] = {
        LineNr      = {ctermfg = 67 , ctermbg = 233}, PowerColor1 = {ctermfg = 255, ctermbg = 52 },
        PowerColor2 = {ctermfg = 67 , ctermbg = 233}, PowerColor3 = {ctermfg = 255, ctermbg = 52 },
        PowerColor4 = {ctermfg = 255, ctermbg = 28 }, PowerColor5 = {ctermfg = 255, ctermbg = 52 },
        Middle      = {ctermfg = 12 , ctermbg = 13 }, TopStatus   = {ctermfg = 255, ctermbg = 124, bold= true },
        MsgArea     = {ctermfg = 255, ctermbg = 54 }
    },
    ['Insert'   ] = {
        LineNr      = {ctermfg = 16 , ctermbg = 33  }, PowerColor1 = {ctermfg = 255 , ctermbg = 33, bold= true },
        PowerColor2 = {ctermfg = 255, ctermbg = 201 }, PowerColor3 = {ctermfg = 255, ctermbg = 28 },
        PowerColor4 = {ctermfg = 255, ctermbg = 201 }, PowerColor0 = {ctermfg = 67 , ctermbg = 233},
        Middle      = {ctermfg = 12 , ctermbg = 7   }, TopStatus   = {ctermfg = 255, ctermbg = 25, bold= true },
        MsgArea     = {ctermfg = 255, ctermbg = 17  }
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

local prev_mode = nil

-- Change the line number bar color and relative_ln depending on the mode
local function update_numbar(mode)
    if not mode then return end

    local theme = line_number_color[mode]

    sugar.highlight.LineNr = {
        ctermfg = theme.LineNr.ctermfg,
        ctermbg = theme.LineNr.ctermbg,
    }

    sugar.highlight.LineNrInvert = {
        ctermbg = theme.LineNr.ctermfg,
        ctermfg = theme.LineNr.ctermbg,
    }

    sugar.highlight.MsgArea.ctermfg = theme.MsgArea.ctermfg
    sugar.highlight.MsgArea.ctermbg = theme.MsgArea.ctermbg

    sugar.highlight.TopStatus = {
        ctermfg = theme.TopStatus.ctermfg,
        ctermbg = theme.TopStatus.ctermbg,
        bold    = theme.TopStatus.bold,
    }

    sugar.highlight.TopStatusInvert = {
        ctermfg = theme.TopStatus.ctermbg,
        ctermbg = theme.LineNr.ctermbg,
    }

    -- All powerline colors
    for i=0, 4, 2 do
        local idx = math.floor(i/2) + 1

        sugar.highlight["StatusLine"..(i+1)] = {
            bold    = theme["PowerColor"..idx].bold,
            ctermfg = theme["PowerColor"..idx].ctermfg,
            ctermbg = theme["PowerColor"..idx].ctermbg,
        }

        sugar.highlight["StatusLineL"..(i+2)] = {
            ctermfg = theme["PowerColor"..(idx  )].ctermbg,
            ctermbg = theme["PowerColor"..(idx+1)].ctermbg,
        }

        sugar.highlight["StatusLineR"..(i+2)] = {
            ctermbg = theme["PowerColor"..(idx  )].ctermbg,
            ctermfg = theme["PowerColor"..(idx+1)].ctermbg,
        }
    end

    local timer = vim.loop.new_timer()
    timer:start(0, 0, vim.schedule_wrap(function()
        vim.api.nvim_command("redraw!")
    end))

    --set_number_absolute()
end

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
        sugar.emit_signal("mode_change")
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
    push_to_stack(stacks.right, "  NeoVIM")

    -- Before creating the content, set the final colors.
    local theme = line_number_color[mode]

    sugar.highlight.StatusMiddleL = {
        ctermfg = theme["PowerColor"..#stacks.left].ctermbg,
        ctermbg = theme.Middle.ctermbg,
    }

    sugar.highlight.StatusMiddleR = {
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

    local names, total = {}, 0

    -- Make 2 passes in case it needs extra cropping.
    for _, buf in ipairs(bufs) do
        local name = rawget(buf, "short_file_name") or buf.file_name

        total = total + vim.str_utfindex(name, #name)

        names[buf] = name
    end

    local kw = "TODO"
    local suffix = " %= %#TopStatusInvert#%#TopStatus# %f  "..kw.."  NeoVIM "

    total = total + vim.str_utfindex(suffix, #suffix)

    -- The "5" is to account for up to five figure of line count prefix.
    local crop = sugar.session.current_window.width < total + 5

    -- Further reduce the size.
    if crop then
        for buf, name in pairs(names) do
            names[buf] = name:match("([^/]*)$") or name
        end
    end

    for _, buf in ipairs(bufs) do
        local name = names[buf]
        name = name == "" and "<Empty>" or name
        if buf._private.handle ~= cur then
            ret = ret .. "| " .. name .. " "
        else
            ret = ret .. "|%#LineNrInvert# " .. name .." %#LineNr#"
        end
    end

    -- Add some +++ to align the tabs with the window content
    local lc,prefix = buf.line_count/100, "   "
    while lc > 10 do
        prefix = prefix .. " "
        lc = lc / 10
    end

    if not crop then
        print("%#LineNr#"..prefix..ret..suffix)
    else
        print("%#LineNr#"..prefix..ret)
    end
end

sugar.session.options.statusline = "%!StatusUpdateCallback(mode(),mode())"

sugar.session.options.showtabline = 2
sugar.session.options.tabline = "%!TabUpdateCallback(mode(),'%n')"
