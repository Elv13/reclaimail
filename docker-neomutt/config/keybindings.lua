local keybindings = {}

-- Return a macro object
function keybindings.macro(args)
    assert(#args == 4 or #args == 5)
    return {type="macro", content = args}
end

local function build_keybindings(args)
    local mods, key, ret = args[2], args[3], ""
    assert(mods and type(mods) == "table")
    assert(ret)

    if #mods > 0 and mods[1]:lower() == "control" then
        ret = ret .. "\\C"
    end

    return ret .. key
end

-- Add some keybindings to mutt
function keybindings.add(args)
    for _, k in ipairs(args) do
        local menu_types = table.concat(k.content[1], ",")

        mutt.call(
            k.type, menu_types, build_keybindings(k.content), k.content[4]
            --FIXME , k.content[4] and k.content[4] or k.content[3]
        )
    end
end

return keybindings
