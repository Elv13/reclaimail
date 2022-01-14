--- This module simplify the nvim highlight API.
--
-- Set a single color:
--
--    sugar.highlight.Pmenu.ctermbg = "yellow"
--
-- Set an entire ground:
--
--    sugar.highlight.Pmenu = {
--         ctermbg = "yellow"
--    }

local set_hl_ns = vim.api.nvim__set_hl_ns or vim.api.nvim_set_hl_ns
local namespace = vim.api.nvim_create_namespace("sugar")

local module = {}

local groups = {}

local pending = false

local translator = {
    background = "ctermbg",
    foreground = "ctermfg",
}

local function reload()
    if pending then return end

    vim.schedule(function()
        set_hl_ns(namespace)
        pending = false
    end)

    pending = true
end

local function translate(name)
    local work, codes = pcall(vim.api.nvim_get_hl_by_name, name, false)

    if not work then
        vim.api.nvim_get_hl_id_by_name(name)
        codes = vim.api.nvim_get_hl_by_name(name, false)
    end

    local ret = {}

    for k, v in pairs(codes) do
        ret[translator[k] or k] = v
    end

    return ret
end

local function set_safe_hl(name, data)
    local work = pcall(vim.api.nvim_set_hl, namespace, name, data)

    -- This will create the group.
    if not work then
        vim.api.nvim_get_hl_id_by_name(name)
        pcall(vim.api.nvim_set_hl, namespace, name, data)
    end
end

local function get_hl_group(_, name)
    groups[name] = groups[name] or setmetatable({}, {
        __index    = function(self, key)
            if not rawget(self, "_data") then
                rawset(self, "_data", translate(name))
            end
            return self._data[key]
        end,
        __newindex = function(self, k, v)
            if not self._data then
                rawset(self, "_data", translate(name))
            end
            self._data[k] = v
            set_safe_hl(name, self._data)
            reload()
        end
    })

    return groups[name]
end

local function set_hl_group(_, name, values)
    get_hl_group(nil, name)._data = values
    set_safe_hl(name, values)
    reload()
end

return setmetatable(module, {
    __index    = get_hl_group,
    __newindex = set_hl_group,
})
