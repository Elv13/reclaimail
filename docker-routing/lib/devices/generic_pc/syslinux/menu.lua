local create_object = require("reclaim.routing.object")

local module, overrides = {}, {}

function module:add_entry(entry)
    if not self._private.entries then
        self._private.entries = {}
    end

    table.insert(self._private.entries, entry)
end

function module:set_entries(entries)
    self._private.entries = entries
end

function module:set_title(value)
    self._private.title = value
end

function module:set_timeout(value)
    self._private.timeout = value
end

function module:set_menu_type(value)
    self._private.menu_type = value
end

function module:set_background(value)
    self._private.background = value
end

function module:set_compat(value)
    self._private.compat = value
end

local prop_to_header = {
    background = "MENU BACKGROUND ",
    title      = "MENU TITLE ",
    timeout    = "TIMEOUT ",
    prompt     = "PROMPT ",
}

function module:export(device)
    local header, content, ret = {}, {}, {}

    if (self._private.menu_type or "basic") == "basic" and not self._private.compat then
        table.insert(header, "UI menu.c32")
    end

    for _, entry in ipairs(self._private.entries or {}) do
        local txt = entry:export(device)
        table.insert(content, txt)

        print("\nDEFAULT?", entry.default,  txt:match("^LABEL ([^\n]+)"))
        if entry.default then
            local lbl = txt:match("^LABEL ([^\n]+)")
            table.insert(header, "DEFAULT "..lbl)
        end
    end

    table.insert(header, "\n")

    for _, prop in ipairs {"title", "timeout", "save_default", "background" } do
        if self._private[prop] ~= nil and prop_to_header[prop] then
            local v = self._private[prop]

            if type(v) == "boolean" then
                v = v and 1 or 0
            end

            table.insert(header, prop_to_header[prop]..v)
        end
    end

    table.insert(ret, table.concat(header, "\n"))

    for _, entry in ipairs(self._private.entries or {}) do
    end

    for _, entry_txt in ipairs(content) do
        table.insert(ret, entry_txt)
    end

    print(table.concat(ret, "\n\n"))

    return table.concat(ret, "\n\n"), true
end

local function new(_, args)
    local ret = create_object {enable_properties = true}
    ret._private.menu_type = "basic"
    ret._private.timeout   = 10

    create_object.add_class(ret, module)

    create_object.apply_args(ret, args, {}, overrides)

    return ret
end

return setmetatable(module, {__call = new})
