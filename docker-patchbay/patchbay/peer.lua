local object = require("patchbay.object")

local module = {}

local function new(_, args)
    local ret = object{}

    return ret
end

return setmetatable(module, { __call = new })
