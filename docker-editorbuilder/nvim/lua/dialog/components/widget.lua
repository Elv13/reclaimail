--- The base widget.
-- Their size is "fixed", but can be changed. The goal is
-- not to re-implement GTK/Qt, it's to draw a simple dialog.
--
-- If a feature is not used by dialog, then, it's out of scope.

local module = {}

local highlights, names = {}, 1

local function add_highlight(args)
    local param = " "

    local name = "SugarWidgetColor"..names
    names = names + 1

    for _, v in ipairs {"ctermfg", "ctermbg", "cterm"} do
        if args[v] then
            param = param .. k.."="..v.." "
        end
    end

    vim.api.nvim_command("hi "..name..param)

    return name
end

local function init_highlight(self)
    if self._private.hl_group_name then return end

    self._private.hl_group_name = tostring(self):gmatch("x.+$")()

    -- Create one hl group per widget. This way it's easy to
    -- clear.
    self._private.hl_group = vim.api.nvim_create_namespace(
        self._private.hl_group_name
    )

end

function module:draw(stack)
    assert(false, "Not implemented")
end

function module:meta_draw(stack)
    self:draw(stack)

    for _, h in ipairs(self._private.highlights) do
        stack:_add_highlight(h)
    end
end

function module:highlight(args)
    local x,y,w,h = args.x, args.y, args.width, args.height
    assert(x and y and w and h, "Geometry is mandatory")


    init_highlight(self)

    local bg, fg, style = args.ctermfg, args.ctermbg, args.cterm

    highlights[bg or false] = highlights[bg or false] or {}
    highlights[bg or false][fg or false] = highlights[bg or false][fg or false] or {}

    local hl = highlights[bg or false][fg or false][style or false] or add_highlight(args)

    table.insert(self._private.highlights, {
        name = name,
        geo  = {x,y,w,h}
    })
end

local function new(_, width, height, class)
    assert(type(width) == "number")
    assert(type(height) == "number")

    local ret = {
        x        = 1,
        y        = 1,
        width    = width,
        height   = height,
        _private = {
            highlights = {}
        }
    }

    return setmetatable(ret, {
        __index = function(self, key)
            for _, o in ipairs { class, module } do
                if o["get_"..key] then
                    return o["get_"..key](self)
                elseif o[key] then
                    return o[key]
                end
            end
        end,
        __newindex = function(self, key, value)
            if module["set_"..key] then
                module["set_"..key](self, value)
            elseif class["set_"..key] then
                class["set_"..key](self, value)
            else
                rawset(self, key, value)
            end
        end
    })
end

return setmetatable(module, {__call=new})
