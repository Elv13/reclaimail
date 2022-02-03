local object = require("patchbay.object")

local module = {_instances = {}}

-- Mash into a global profile.
function module._to_xml(obj, defaults, header, footer)
    assert(obj and defaults and header and footer)

    local params_kv, params = {}, {}

    object.shallow_copy(params_kv, defaults)

    for param, value in pairs(obj._private) do
        params_kv[param] = value
    end

    for param, value in pairs(params_kv) do
        table.insert(params, '                 <param name="'.. param ..'" value="'.. tostring(value) ..'"/>')
    end

    return table.concat({
        header,
        table.concat(params, "\n"),
        footer
    }, "\n")
end

local function new(_, args)
    args =  args or {}
    local ret = {_private = {}}

    object.shallow_copy(ret._private, args)

    return setmetatable(ret, {
        __newindex = function(self, k, v)
            self._private[k] = v
            --TODO reloadxml
        end
    })
end

return setmetatable(module, { __call = new})
