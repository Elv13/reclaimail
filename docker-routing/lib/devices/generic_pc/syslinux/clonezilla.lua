local linux = require("reclaim.routing.devices.generic_pc.syslinux.linux")

local module = {}

local function cmdline(self, line)
    local lan = require("reclaim.routing.dnsmasq").interfaces.by_area["local"][1]

    assert(lan) --TODO remove
    if not lan then return end

    local first_range = lan._args.ranges_v4 and lan._args.ranges_v4[1] or nil

    assert(first_range) --TODO remove
    if not first_range then return end

    local ip = first_range.begin_v4

    table.insert(line,"initrd=initrd.img")
    table.insert(line,"boot=live")
    table.insert(line,"username=user")
    table.insert(line,"union=overlay")
    table.insert(line,"config")
    table.insert(line,"components")
    table.insert(line,"noswap")
    table.insert(line,"edd=on")
    table.insert(line,"nomodeset")
    table.insert(line,"nodmraid")
    table.insert(line,"locales=")
    table.insert(line,"keyboard-layouts=")
    table.insert(line, 'ocs_live_run="ocs-live-general"')
    table.insert(line,'ocs_live_extra_param=""')
    table.insert(line,"ocs_live_batch=no")
    table.insert(line,"net.ifnames=0")
    table.insert(line,"nosplash")
    table.insert(line,"noprompt")
    table.insert(line,"fetch=tftp://".. ip .."/filesystem.squashfs")
end

local function new(_, args)
    local ret = linux(args)

    ret.kernel = "/tftp/clonezilla/vmlinuz"
    ret._private.tftp_root = "clonezilla/"
    --ret.initrd = "/tftp/clonezilla/initrd.img"
    ret._private.cmdline_fct = cmdline

    return ret
end

return setmetatable(module, {__call = new})
