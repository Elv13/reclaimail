-- Make getting and setting mutt variable less convoluted
local options = {}

-- Use Lua tables instead of global options
function options.add_namespace(path)
    local ns = ""

    for _, n in ipairs(path) do
        ns = ns .. (ns == "" and "" or "_")..n
    end

    return setmetatable({}, {
        __index    = function(_, k) return mutt.get(ns.."_"..k) end,
        __newindex = function(_, k, v) mutt.set(ns.."_"..k, v) end
    })
end

return setmetatable(options, {
    __index    = function(_, k) return mutt.get(k) end,
    __newindex = function(_, k, v) mutt.set(k, v) end
})
