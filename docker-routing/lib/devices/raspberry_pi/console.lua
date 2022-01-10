local create_object = require("reclaim.routing.object")

local module = {}

local function add_uart(self, device)
    local gen = device.generation
    -- For Pi 4 and Compute Module 4 (BCM2711)
    if gen == 4 then
        return {
            {"earlycon", "uart8250,mmio32,0xfe215040"},
            {"earlycon", "pl011,mmio32,0xfe201000"}
        }
    end

    -- For Pi 2, Pi 3 and Compute Module 3 (BCM2836 & BCM2837)
    if gen == 2 or gen == 3 then
        return {
            {"earlycon", "uart8250,mmio32,0x3f215040"},
            {"earlycon", "pl011,mmio32,0x3f201000"}
        }
    end

    -- For Pi 1, Pi Zero and Compute Module (BCM2835)
    if gen == 1 then
        return {
            {"earlycon", "uart8250,mmio32,0x20215040"},
            {"earlycon", "pl011,mmio32,0x20201000"}
        }
    end
end

function module:set_output(value)
    self._private.output = value
end

function module:get_output()
    print("get", self._private.output)
    return self._private.output
end

function module:set_baud(value)
    self._private.baud = value
end

function module:_export_cmdline(device)
    local ret = {}
    assert(self._private.output)
    local main_arg = self._private.output

    self._private.is_console = true

    if self._private.baud then
        main_arg = main_arg .. "," .. self._private.baud
    end

    table.insert(ret, {"console", main_arg})

    print("\n\nBOB", self.output)

    --FIXME It breaks the console on the Pi 4?
    --[[if self.output == "serial0" then
        for _, arg in ipairs(add_uart(self, device)) do
            print("===========", arg[0], arg[1])
            table.insert(ret, arg)
        end
    end]]

    return ret
end

function module:_export_uboot(device)
    if self.output == "serial0" then
        local ret = {}

        return {}, true
    end

    return {}, false
end


local function new(_, args)
    local ret = create_object()
    create_object.add_class(ret, module)
    ret.is_console = true

    create_object.apply_args(ret, args, {}, overrides)

    return ret
end

return setmetatable(module, { __call =  new})
