local transaction = require("patchbay._transaction")
local coxpcall = require("coxpcall")
unpack = unpack or table.unpack

local module = {}

local function get_submodule(mod, prefix, key)
    if type(key) ~= "string" then return end

    local parts = {}

    for part in key:gmatch("([^.]+)[.]*") do
        table.insert(parts, part)
    end

    local m = require(prefix.."."..parts[1])

    if type(m) == "boolean" then
        print("WARNING: Invalid module ".. prefix.."."..key)
    end

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
        return get_submodule(mod, prefix, key)
    end

    setmetatable(mod, mt)

    return mod
end

local function magic_getter(self, key)
    if rawget(self, "get_"..key) then
        return self["get_"..key](self)
    elseif rawget(self, "_class") and rawget(self._class, "get_"..key) then
        return self._class["get_"..key](self)
    elseif rawget(self, "_class") and rawget(self._class, key) then
        return rawget(self._class, key)
    elseif self._private[key] then
        return self._private[key]
    elseif self._private.load_submodules then
        local exist, ret = pcall(get_submodule, self, self._private.load_submodules, key)

        if exist then
            return ret
        end
    end
end

local function magic_setter(self, key, value, emit)
    if rawget(self, "set_"..key) then
        rawget(self, "set_"..key)(self, value)
    elseif rawget(self, "_class") and rawget(self._class, "set_"..key) then
        rawget(self._class, "set_"..key)(self, value)
    else
        local changed = self._private[key] ~= value
        self._private[key] = value

        if changed and emit then
            self:emit_signal("property::"..key, value)
        end
    end
end

function module.shallow_copy(target, source)
    for k, v in pairs(source) do
        rawset(target, k, v)
    end
end

function module.patch_table(tab, args)
    args = args or {}
    local enable_properties = args.enable_properties ~= false

    local conns = {}

    local priv = tab._private or {}

    tab._class = args.class
    tab._private = priv
    tab._private.load_submodules = args.load_submodules

    tab.emit_signal = function(one, two, ...)
        local params = args.is_module and {two, unpack{...}} or {one, unpack({...})}
        local signal = args.is_module and one or two

        for _, conn in ipairs(conns[signal] or {}) do
            -- Run in a new coroutine to seach connection can happen in "parallel".
            transaction(function() conn(unpack(params)) end)

            --local tb = nil
            --local pass, err = coxpcall.xpcall(function() conn(unpack(params)) end, function(err)
            --    tb = debug.traceback(err)
            --    return err
            --end)

            --if not pass then
            --    require("patchbay").emit_signal("debug::error", err, tb, nil)
            --end

            --conn(unpack(params))
        end

        local cls = args.class or tab._private.class

        if cls and cls.emit_signal and cls ~= tab then
            cls.emit_signal(signal, unpack(params))
        end
    end

    tab.connect_signal = function(one, two, three)
        local signal = args.is_module and one or two
        conns[signal] = conns[signal] or {}
        local conn = args.is_module and two or three

        assert(
            type(conn) == "function",
            args.is_module and "Call connect_signal with `.`, not `:`" or "Call connect_signal with `:`, not `.`"
        )

        table.insert(
            conns[signal], args.is_module and two or three
        )
    end

    tab.disconnect_signal = function(one, two, three)
        local signal = args.is_module and one or two
        local conn   = args.is_module and two or three

        for k, conn2 in ipairs(conns[signal] or {}) do
            if conn2 == conn then
                table.remove(conns[signal], k)
                return
            end
        end
    end

    setmetatable(tab, {
        __call     = args.call,
        __index    = enable_properties and magic_getter or priv,
        __newindex = function(self, key, value)
            if enable_properties then
                magic_setter(self, key, value, args.emit_signals)
            elseif value ~= priv[key] then
                priv[key] = value
                if args.emit_signals then
                    self:emit_signal("property::"..key, priv[key])
                    local cls = args.class or tab._private.class

                    if cls and type(cls) ~= "boolean" and cls.emit_signal then
                        cls.emit_signal("property::"..key, tab, value)
                    end
                end
            else
                priv[key] = value
            end
        end
    })

    if args.class and type(args.class) ~= "boolean" and args.class.emit_signal then
        args.class.emit_signal("added", tab)
    end

    return tab
end

local function new(_, args)
    return module.patch_table({}, args)
end

return setmetatable(module, {__call = new})
