unpack = unpack or table.unpack

local module = {}

function module.add_class(object, class)
    for name, method in pairs(class) do
        rawset(object, name, method)
    end
end

function module.apply_args(object, args, ignore, override)
    ignore, override = ignore or {}, override or {}

    for arg, value in pairs(args or {}) do
        if override[arg] then
            override[arg](object, value)
        elseif not ignore[arg] then
            object[arg] = value
        end
    end
end

function module.load_submodules(mod, prefix, mt)
    local mt = getmetatable(mod) or mt or {}

    mt.__index = function(_, key)
        if type(key) ~= "string" then return end

        local parts = {}

        for part in key:gmatch("([^.]+)[.]*") do
            table.insert(parts, part)
        end

        local m = require(prefix.."."..parts[1])

        if m then
            rawset(mod, parts[1], m)
        end

        if #parts > 1 then
            for i=2, #parts do
                m = m[parts[i]]
            end
        end

        return m
    end

    setmetatable(mod, mt)

    return mod
end

local function magic_getter(self, key)
    if rawget(self, "get_"..key) then
        return self["get_"..key](self)
    else
        return self._private[key]
    end
end

local function magic_setter(self, key, value, emit)
    if rawget(self, "set_"..key) then
        self["set_"..key](self, value)
    else
        local changed = self._private[key] ~= value
        self._private[key] = value

        if changed and emit then
            self:emit_signal("property::"..key, value)
        end
    end
end

local function new(_, args)
    args = args or {}
    local conns = {}

    local priv = {
        tfiles_by_path = {}
    }

    local ret
    ret = setmetatable({
        _private = priv,
        emit_signal = function(one, two, ...)
            local params = args.class and {two, unpack{...}} or {one, unpack({...})}
            local signal = args.class and one or two
            for _, conn in ipairs(conns[signal] or {}) do
                conn(unpack(params))
            end

            local cls = args.class or ret._private.class
            if cls and type(cls) ~= "boolean" then
                cls.emit_signal(one, unpack(params))
            end
        end,
        connect_signal = function(one, two, three)
            local signal = args.class and one or two
            conns[signal] = conns[signal] or {}
            table.insert(
                conns[signal], args.class and two or three
            )
        end,
    }, {
        __index = args.enable_properties and magic_getter or priv,
        __newindex = function(self, key, value)
            if args.enable_properties then
                magic_setter(self, key, value, args.emit_signals)
            elseif value ~= priv[key] then
                priv[key] = value
                if args.emit_signals then
                    self:emit_signal("property::"..key, priv[key])
                    local cls = args.class or ret._private.class

                    if cls and type(cls) ~= "boolean" then
                        cls.emit_signal("property::"..key, ret, value)
                    end
                end
            else
                priv[key] = value
            end
        end
    })

    if args.class and type(args.class) ~= "boolean" then
        args.class.emit_signal("added", ret)
    end

    return ret
end

return setmetatable(module, {__call = new})
