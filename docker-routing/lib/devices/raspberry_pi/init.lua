local create_object = require("reclaim.routing.object")
local utils   = require("reclaim.routing.utils")
local base    = require("reclaim.routing.devices._base")
local cmdline = require("reclaim.routing.devices.raspberry_pi.cmdline")
local config  = require("reclaim.routing.devices.raspberry_pi.config")
local console = require("reclaim.routing.devices.raspberry_pi.console")
local audio   = require("reclaim.routing.devices.raspberry_pi.audio")
local hdmi    = require("reclaim.routing.devices.raspberry_pi.output.hdmi")

local module, overrides, vfs, vfs_files = {}, {}, {}, {}

function module:get_config()
    if not self._private.config then
        self._private.config = config {}
    end

    return self._private.config
end

function module:get_audio()
    if not self._private.audio then
        self._private.audio = audio {}
    end

    return self._private.audio
end

function module:get_cmdline()
    if not self._private.config then
        self._private.cmdline = cmdline {}
    end

    return self._private.cmdline
end

-- Add some file to the VFS
for _, prop in ipairs { "kernel", "device_tree" } do
    module["get_"..prop] = function(self)
        return vfs[prop]
    end

    module["set_"..prop] = function(self, value)
        if not value then
            vfs[prop] = nil
            return
        end

        local fn = utils.filename(value)

        print("========================================================================", prop, value)
        self.config.entries[prop] = fn

        vfs[prop] = value
        vfs_files[fn] = value
    end
end

function module:add_console(console)
    table.insert(self._private.consoles2, console)
end

function module:get_consoles()
    -- We need a default.
    if #self._private.consoles2 == 0 then
        self:add_console(console {
            output = "tty1"
        })
    end

    return self._private.consoles2
end

function module:set_console()
    assert(false)
end

function module:get_outputs()
    -- We need a default.
    if #self._private.outputs == 0 then
        self:add_output(hdmi {
            port = 1
        })
    end

    return self._private.outputs
end

function module:add_output(output)
    table.insert(self._private.outputs, output)
end

function overrides:consoles(values)
    for _, c in ipairs(values) do
        if c._private and c._private.is_console then
            self:add_console(c)
        else
            self:add_console(console(c))
        end
    end
end

function overrides:outputs(values)
    for _, o in ipairs(values) do
        if o._private and o._private.is_output then
            self:add_output(o)
            o.enabled = true
        else
            assert(false)
        end
    end
end

function overrides:cmdline(value)
    if value.is_cmdline then
        self._private.cmdline = value
    else
        self._private.cmdline = cmdline(value)
    end
end

function overrides:audio(value)
    self._private.audio = value.is_audio and value or audio(value)
end

local file_requests = {}

file_requests["config.txt"] = function(device, file, lease, content)
    print("\n\nIN RPi4 config\n".. device.config:export(device))

    content[true] = device.config:export(device)
end

file_requests["cmdline.txt"] = function(device, file, lease, content)
    print("\n\nIN RPi4 cmd\n".. device.cmdline:export(device))

    content[true] = device.cmdline:export(device)
end

local function tftp_lookup(device, file, lease, content)
    print("RPI lookup", device, file.path, lease, content, file_requests[file.path], vfs[file], vfs_files[file])

    if file_requests[file.path] then
        file_requests[file.path](device, file, lease, content)
    end

    if vfs[file] then
        print("VFS", file, vfs[file])
        content[false] = vfs[file]
    elseif vfs_files[file] then
        content[false] = vfs_files[file]
    end

    if content[false] == nil and content[true] == nil then
        print("FALLBACK",  device.tftp_root.."/"..file.path)
        content[false] = device.tftp_root.."/"..file.path
    end
end

local function new(_, args)
    local ret = base(args)

    ret._private.consoles2 = {}
    ret._private.outputs  = {}
    ret._private.tftp_root = "rpi"

    create_object.add_class(ret, module)

    create_object.apply_args(ret, args, {}, overrides)

    ret:connect_signal("file::lookup", tftp_lookup)

    return ret
end

return create_object.load_submodules(module, "reclaim.routing.devices.raspberry_pi", {
    __call = new
})

