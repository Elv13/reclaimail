local counter = 1

local base = require("sugar._base")

local function add_real_key(name, key, value)
    -- Create a (private) global variables for the function
    if type(value) == "function" then
        local var = "_keymap_fct_"..counter
        counter = counter + 1
        _G[var] = value

        -- Replace the function by its global name
        if name == "imap" or name == "inoremap" then
            -- Always break the undo sequence on custom functions.
            value = "<C-G>u<cmd>:lua "..var.."()<cr>"
        elseif name ~= "map" and name ~= "noremap" then
            value = "<cmd>:lua "..var.."()<cr>"
        else
            value = ":silent lua "..var.."()<cr>"
            name = name .. " <silent>"
        end
    end
    vim.api.nvim_command(name.." "..key.." "..value)
end

-- the `getchar` function doesn't return UTF-8 character nor
-- a byte. It's a weird mix. The table below help convert it
-- back to the same convention map/cmap/imap use.
local getchar_to_key = {
    kb = "BS"  , -- BackSpace
    kd = "Down", -- Down arrow
    ku = "Up"  , -- Up arrow
    kl = "Left", -- Left arrow
    kr = "Right" -- Right arrow
}

local keycode_to_key = {
    [27]                = "<esc>",
    [string.byte("\r")] = "<CR>",
    [string.byte("\t")] = "<Tab>"
}

local prefixes = {
    [4 ] = "C-",
    [8 ] = "A-",
    [6 ] = "C-S-",
    [12] = "C-A-",
}

-- Function keys
for i=1, 36 do
    getchar_to_key["k"..i] = "<F"..i..">"
end

local function stop(self)
    self._private.stopped = true
    self:emit_signal("stopped")
end

local function connect_signal(self, signal, callback)
    self._private.connections[signal] = self._private.connections[signal] or {}
    table.insert(self._private.connections[signal], callback)
end

local function disconnect_signal(self, signal, callback)
    assert(false)
end

local function emit_signal(self, signal, ...)
    for _, cb in ipairs(self._private.connections[signal] or {}) do
        cb(self, ...)
    end
end

local function inherit(self, other)
    for key, value in pairs(other._private.keys) do
        self[key] = value
    end
    table.insert(other._private.children, self)
end

local function grab(keymap)
    local runner = nil

    local exit_reverse = {}

    for _, v in ipairs(exit_seq or {}) do
        exit_reverse[v] = true
    end

    runner = function()
        local c = base.global_functions.getchar()

        --FIXME doesn't seem to do anything
        local mod = base.global_functions.getcharmod()

        local key = nil

        if type(c) == "string" then
            local event = string.sub(c,2,3)
            if getchar_to_key[event] then
                key = getchar_to_key[event]
            end
        else
            if keycode_to_key[c] then
                key = keycode_to_key[c]
            else
                key = base.global_functions.nr2char(c)
            end
        end

        if not key then
            base.schedule.delayed(runner)
            return
        end

        if prefixes[mod] then
            key = "<"..prefixes[mod]..key..">"
        end

        if keymap[key] then
            keymap[key](keymap)
        else
            keymap:emit_signal("key", key)
        end

        if keymap._private.stopped then
            keymap._private.stopped = false
            return
        end

        base.schedule.delayed(runner)
    end

    keymap:emit_signal("started")
    base.schedule.delayed(runner)
end

local maps = {}

--- Create a keymap object.
-- @function sugar.keymap
-- @tparam table args
-- @tparam table args.keys A table with the key combo (like `<C-S-B>`) as key and actions as values.

local function gen_map(_, args)
    args = args or {}

    local priv = {keys={},connections={}, children={}}

    local obj = {
        _private          = priv,
        stop              = stop,
        grab              = grab,
        connect_signal    = connect_signal,
        disconnect_signal = disconnect_signal,
        emit_signal       = emit_signal,
        inherit           = inherit,
    }

    local ret = setmetatable(obj, {
        __newindex = function(_, k, v)
            local map = rawget(_, "_name")
            if map then
                add_real_key(map, k, v)
            end
            priv.keys[k] = v

            for _, child in ipairs(priv.children) do
                if not child._private.keys[k] then
                    child[k] = v
                end
            end
        end,
        __index = priv.keys,
        __call = function(_)
            grab(_, args.on_key, args.auto_exit)
        end
    })

    if args.keys then
        base.schedule.delayed(function()
            for key, value in pairs(args.keys) do
                ret[key] = value
            end
        end)
    end

    return ret
end

return setmetatable({}, {__call = gen_map})
