local create_object = require("reclaim.routing.object")

local module = {}

--function module:set_enable_uart(value)

--end

--function module:get_uart_enabled()
--    return self._private.uart_enabled
--end

-- local function add_console(self)
--     if self.uart_enabled then
--         return "console=serial0,115200 console=tty1"
--     else
--         return "console=tty1"
--     end
-- end
--
-- local function add_uart(self)
--     local gen = device.generation
--     -- For Pi 4 and Compute Module 4 (BCM2711)
--     if gen == 4 then
--         return "earlycon=uart8250,mmio32,0xfe215040 earlycon=pl011,mmio32,0xfe201000"
--     end
--
--     -- For Pi 2, Pi 3 and Compute Module 3 (BCM2836 & BCM2837)
--     if gen == 2 or gen == 3 then
--         return "earlycon=uart8250,mmio32,0x3f215040 earlycon=pl011,mmio32,0x3f201000"
--     end
--
--     -- For Pi 1, Pi Zero and Compute Module (BCM2835)
--     if gen == 1 then
--         return "earlycon=uart8250,mmio32,0x20215040 earlycon=pl011,mmio32,0x20201000"
--     end
-- end

function module:export(device)
    local ret = {}

    -- The uBoot config has to match the kernel settings for this to work.
    -- if device.config.enable_uart then
        -- table.insert(ret, add_uart(self))
    -- end

    -- Consoles have both a kernel and uBoot components.
    for _, console in ipairs(device.consoles) do
        for _, row in ipairs(console:_export_cmdline(device)) do
            print("M++++",  row[1].."="..row[2])
            table.insert(ret, row[1].."="..row[2])
        end
    end

    for arg in ipairs(self._private.arguments) do
        if args.value then
            table.insert(ret, arg.key.."="..arg.value)
        else
            table.insert(ret, arg.key)
        end
    end

    for _, output in ipairs(device.outputs) do
        for _, row in ipairs(output:_export_cmdline(device)) do
            table.insert(ret, row[1].."="..row[2])
        end
    end

    table.insert(ret, "root=/dev/nfs")
    table.insert(ret, "nfsroot=10.10.10.1:/,vers=4,proto=tcp")
    --table.insert(ret, "rootdelay=2")
    table.insert(ret, "rw")
    table.insert(ret, "ip=dhcp")
    table.insert(ret, "rootwait")
    table.insert(ret, "elevator=deadlin")
    table.insert(ret, "init=/sbin/init ")

    return table.concat(ret, " ")
end

-- console=serial0,115200 console=tty1 root=PARTUUID=067e19d7-02 rootfstype=ext4 elevator=deadline fsck.repair=yes
-- rootwait init=/usr/lib/raspi-config/init_resize.sh earlycon=uart8250,mmio32,0xfe215040 video=Composite-1

function module:append_argument(key, value)
    assert(key)
    table.insert(self._private.arguments, {key = key, value = value})
end

local function new(_, args)
    assert(args)
    local ret = create_object  {enable_properties = true}
    ret._private.is_cmdline = true
    ret._private.arguments = {}

    create_object.add_class(ret, module)

    create_object.apply_args(ret, args, {}, overrides)

    assert(ret.export)

    return ret
end

return setmetatable(module, {__call = new})
