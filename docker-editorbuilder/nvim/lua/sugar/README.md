# NeoVIM sugar: To hide all the low-level ugliness

This library wraps NeoVIM native Lua API (and part of VIM API) into an
object oriented high level API. When it makes sense, this library avoids
making choices or adding new feature. The goal is to be able to have a
sane `init.lua` that's actually *more readable* than the classic `.vimrc`
rather than being Lua for the sake of it.

### What does it do and how does it works

The library is based on the fact that `nvim` API makes sense. A lot
of the boilerplate is auto-generated, which makes the codebase very tiny
(but totally unreadable since there is no code for most things)

This example shows what really happens under the hood:

```txt

local val1 = vim.api.nvim_buf_get_option(vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()), "my_option")
--                   |                 | |                       |   |----------------------------| |        |
--                   |                 | |-----------------------|                  |               |        |
--                   |-----------------|             |                              |               |--------|
--                            |                      |                              |                    |
--                            |----------------------c------|                       |                    |
--                                                   |      |                       |                    |
--                               --------------------c------c-----------------------|                    |
--                               |                   |      |                                            |
--                         |------------|            |   |-----|     |-----------------------------------|
--                         |            | |------------| |     | |-------| 
local val2 = sugar.session.current_window.current_buffer.options.my_option

assert(val1 == val2, "This is the exact same code")

```

As you can probably see after staring at that spagatti for half an hour, the
object oriented API get rid of all nested handle getters. This reverse the
order from `specific(object(parent_object(parent_parent_object)))` to
`parent_parent_object.parent_object.object.specific`. This is done using
the Lua `metatable` concept. For example, a simplified implementation of
the example above is:

```lua
local _buffers = {}

local session = setmetatable({}, {
    __index = function(_, key)
        if key == "current_buffer" then
            local buf = vim.api.nvim_get_current_buf()
            if _buffers[buf] then return _buffers[buf] end

            _buffers[buf] = {
                options = setmetatable({}, {
                    __index = function(_, option)
                        return vim.api.nvim_buf_get_option(buf, option)
                    end,
                    __newindex = function(_, option, value)
                        vim.api.nvim_buf_set_option(buf, option, value)
                    end
                })
            }
        end
    end
})
```

In practive, it is a bit more complex since the wrapper also has to support
the methods, but it's close enough. Also, it isn't implemented directly, it's
a bunch of meta-code for each "pattern" (properties with getter/setter,
table-properties with random keys, numeric handle based properties, etc).

The API also get rid of the short names (like "win", "buf") in favor
of full class names ("window", "buffer") for consistency.

All magic is in the `nobject.lua` module. Each class has its own module.

### Examples

#### Access options or variables direcly

This works for all objects (buffers, windows, sessions, tabpage, etc):

```lua
-- Options
local width = sugar.session.options.shiftwidth

-- Variable
local myvar = sugar.session.myvar

```

#### Keyboard shortcuts

With `sugar`, all keyboard shortcuts support Lua code:

```lua
local modes  = require( "sugar.modes" )

-- Using Lua
modes.normal.keymap["<C-T>"] = function()
    print("CALLED!")
end

-- Classic
modes.normal.keymap["<C-S-T>"] = ":bprev<CR>"
```

#### Modify an existing buffers and cursors

No more handles, everything is an object:

```lua
local buf = sugar.session.current_window.current_buffer

-- Get some lines.
local lines = buf:get_line_range(row_start, row_end)

for k, line in ipairs(lines) do
    lines[k] = "PREFIX"..line
end

-- Set some lines.
buf:set_line_range(row_start, row_end, lines)

-- Move the cursor.
sugar.session.current_window.cursor.row    = 10
sugar.session.current_window.cursor.column = 20
```

It is possible to easily iterate existing objects:

```lua
for _, buffer in ipairs(sugar.session.buffers) do
    -- something
end
```

#### Create buffers

```lua
local buf = sugar.buffer {
    listed  = false,
    scratch = true,
    options = {
        buftype = "nofile"
    }
}

sugar.session.current_window.current_buffer = buf
```

#### Popups

It's possible to create popups by creating their object.

```lua
local win = sugar.window {
    buffer   = buf,
    relative = 'win', 
    width    = w, 
    height   = h, 
    row      = row,
    column   = col,
    style    = "minimal",
    options  = {
        number = false
    }
}

win:close()
```

#### Events / AutoCMDs

It use an AwesomeWM like syntax for global and objects events:

```lua
-- Connect to some global signals to detect when the mode changes.
for _, sig in ipairs { "buf_enter", "focus_gained", "insert_leave",
                       "buf_leave", "focus_lost"  , "insert_enter" } do
    sugar.connect_signal(sig, function() print("EVENT!") end)
end
```

#### Keygrabbing

There is a work-in-progress support for creating custom input handler,
but it's buggy:

```lua
local keymap = require("sugar.keymap")

local my_keymap = keymap {
    keys = {
        ["<C-A>"] = function() print("do things") end,
        ["<BS>" ] = function() print("BACKSPACE") end,
        ["<esc>"] = function(self) self:stop() end
        ["<CR>" ] = function(self) self:stop() end
    }
}

-- Start grabbing.
my_keymap:grab()

my_keymap.connect_signal("key", function(self, key)
    print(key, "added")
end)

my_keymap.connect_signal("started", function(self)
    print("started")
end)

my_keymap.connect_signal("started", function(self)
    print("stopped")
end)

-- It is also possible to inherit keys from one keymap into another.
local my_keymap2 = keymap {}
my_keymap2:inherit(my_keymap)

```

The main use case is to override the default command `prompt()` with something
with callbacks (implemented as signals) for changes. The problem is that getting
the modifiers is totally broken and thus a lot of `cmap` doesn't work...

### TODO

Right now this is pretty basic. About half of the API is exposed. I added what
I needed over the years. Adding everything else isn't that time consuming, but
would require a testing story since nothing in my config uses it. Any feature
that's not in the API is out of scope. I made some opiniated choices for the
"mode" objects because it isn't a "real" concept in the NeoVIM Lua API, but is
100% required for any moderately advanced config. The same can be said of
the statusbar, but I have another library to wrap it. The `session` singleton
object exists because I didn't want to add anything in `_G`.

Another aspect that needs work is the doc. Running `ldoc` on this "works", but
it is incomplete and the template used by AwesomeWM is required (it implements
some extra tags like @signal, @emits, @property and @method).

Finally, the library itself has no test. My config has some, thus indirectly
test a subset of the library. This isn't enough and it will need some true
`busted` tests eventually.
