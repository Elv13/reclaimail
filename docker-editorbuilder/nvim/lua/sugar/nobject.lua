--- Wrap the flat API into an object oriented one.

local cursor = require("sugar.cursor")

local module = {}

local accessors = {}
-- All objects functions have an handle, but not the global session.
local function opt_call(name, pop, ...)
    local args = {select(pop and 2 or 1, ...)}
    assert(vim.api[name], name.." doesn't exist")
    return vim.api[name](unpack(args))
end

-- All getter function follow the same naming convention, abuse that fact.
function accessors.get_(name, fct, object, attribute)
    return opt_call("nvim_"..name..fct, name == "", object, attribute)
end

-- All setter function follow the same naming convention, abuse that fact.
function accessors.set_(name, fct, object, attribute, value)
    opt_call("nvim_"..name..fct, name == "", object, attribute, value)
end

local function nop() end

local common_class = {}

-- Works for both __index and __newindex
local function meta_common(prefix, name, class)
    return function(ret, attr, ...)
        if class and class[prefix..attr] then
            return class[prefix..attr](ret, ...)
        elseif class and class[attr] then
            return class[attr]
        elseif common_class[prefix..attr] then
            return common_class[prefix..attr](ret, name, ...) 
        else
            return accessors[prefix](name, prefix.."var", ret._private.handle, attr, ...)
        end
    end
end

function module.object_common(name, parent, handle, class)
    assert(handle, debug.traceback())
    return setmetatable({ _private = { parent = parent, handle = handle } }, {
        __index    = meta_common("get_", name, class),
        __newindex = meta_common("set_", name, class)
    })
end

-- Some API element have namespaced get_foo/set_foo, turn that into a property.
local function wrap_accessor(self, name, accessor, property)
    local ret = setmetatable({}, {
        __index = function(_, attr)
            return accessors.get_(name, "get_"..accessor, self._private.handle, attr)
        end,
        __newindex = function(_, attr, value)
            return accessors.set_(name, "set_"..accessor, self._private.handle, attr, value)
        end
    })
    
    -- lazy load only once
    rawset(self, property, ret)
    
    return ret
end

-- Some API element have get_foo/set_foo, turn that into a property.
-- The difference with wrap_accessor is that these property are not namespaced.
function module.wrap_property(class, name, api_name, property, skip_get)
    class["get_"..property] = function(self)
        return accessors.get_(name, (skip_get and "" or "get_")..api_name, self._private.handle)
    end

    if not skip_get then
        class["set_"..property] = function(self, value)
            return accessors.set_(name, "set_"..api_name, self._private.handle, value)
        end
    end
end

-- Same as above, but for properties that return an handle
-- to an object.
function module._wrap_handle_property(class_src, class_dest, name_src, name_dest, api_name, property, pool)
    class_src["get_"..property] = function(self)
        local handle = accessors.get_(name_src, "get_"..api_name, self._private.handle)
        if pool[handle] then return pool[handle] end
        pool[handle] = module.object_common(name_dest, nil, handle, class_dest)
        return pool[handle]
    end
    class_src["set_"..property] = function(self, value)
        return accessors.set_(
            name_src, "set_"..api_name, self._private.handle, value._private.handle
        )
    end
end

-- All nvim object have options.
function common_class.get_options(self, name)
    return wrap_accessor(self, name, "option", "options")
end
common_class.set_options = nop

return module
