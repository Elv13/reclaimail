--- Create objects for each mode.
--
-- The long term goal is to use this to store the statusbar object.
-- It also abstract-out the "real" modes versus custom keygrabber
-- based ones.

local sugar  = require("sugar")
local keymap = require("sugar.keymap")

local module = {}

module._mode_names = {
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

local real_modes, modes_normalized = {
    ['Normal'   ] = { keymap_name = "noremap"  },
    ['Normal·OP'] = { keymap_name = "noremap"  },
    ['Visual'   ] = { keymap_name = "vnoremap" },
    ['V·Line'   ] = { keymap_name = "vnoremap" },
    ['V·Block'  ] = { keymap_name = "vnoremap" },
    ['Insert'   ] = { keymap_name = "inoremap" },
    ['Select'   ] = { keymap_name = nil    },
    ['S·Line'   ] = { keymap_name = nil    },
    ['S·Block'  ] = { keymap_name = nil    },
    ['Replace'  ] = { keymap_name = nil    },
    ['V·Replace'] = { keymap_name = nil    },
    ['Command'  ] = { keymap_name = "cnoremap" },
    ['Vim Ex'   ] = { keymap_name = nil    },
    ['Ex'       ] = { keymap_name = nil    },
    ['Prompt'   ] = { keymap_name = nil    },
    ['More'     ] = { keymap_name = nil    },
    ['Confirm'  ] = { keymap_name = nil    },
    ['Shell'    ] = { keymap_name = nil    },
    ['Terminal' ] = { keymap_name = nil    },
}, {}

-- The modes are named in a way that's inconsistent with Lua variable
-- conventions. Nobody want to add all the extra [].
for mode in pairs(real_modes) do
    local new_name = mode:lower():gsub("-", "_")
    modes_normalized[new_name] = mode
end

local function meta_common(prefix, name)
    return function(ret, attr, value)
        if module[prefix..attr] then
            return module[prefix..attr](ret, value)
        elseif name == "set_" then
            rawset(ret, sttr, value)
        end
    end
end

--- Get the keymap for the mode.
-- @property keymap

-- This is a fallback if none is passed to the constructor.
function module.get_keymap(self)
    local kname = real_modes[self.name]

    assert(kname)

    local ret = keymap()
    rawset(ret, "_name", kname.keymap_name)

    rawset(self, "keymap", ret)

    return ret
end

local function create_mode(name, real, keymap)
    local ret = {
        name   = name,
        keymap = keymap,
        _private = {
            real = real,
        }
    }

    return setmetatable(ret, {
        __index    = meta_common("get_", name),
        __newindex = meta_common("set_", name)
    })
end

-- @tparam
function module.create_mode(name, keymap)
    --
end

function module.get_current_mode()
    return sugar.global_functions.mode()
end

local function find_mode(name)
    local new_name = name:lower():gsub("-", "_")

    return modes_normalized[new_name], new_name, name
end

return setmetatable(module, {
    __index = function(_, mode)
        local real_name, normalized, original = find_mode(mode)
        if real_modes[real_name] then
            -- Make sure all 3 "common" variables point to the same object.
            rawset(module, real_name, create_mode(real_name, true, nil))
            rawset(module, normalized, module[real_name])
            rawset(module, original  , module[real_name])
        end

        return rawget(module, real_name)
    end,
    __call = function(_, args)
        --TODO
    end
})
