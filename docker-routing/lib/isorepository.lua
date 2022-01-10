-- This module get a list of ISO files and make them available over the network.
--
-- For now, it uses TFTP, but eventually moving to a static, micro http server
-- is a better idea. NFS is even better, but I don't like adding such thing
-- on a gateway, it's risky.

local router = require("reclaim.routing.dnsmasq")

--README:
-- Keep in mind this software is designed to run within a specific Docker
-- image where /tftp/ exists and contain a syslinux binary.

local header = [[
default vesamenu.c32
prompt 0
timeout 0

]]

local function scandir(path)
    local f, ret = io.popen("ls "..path), {}

    for i in f:read("*all*"):gmatch("([^ \n]+)") do
        table.insert(ret, i)
    end

    f:close()

    return ret
end

-- Avoid the repetitive boilerplate.
local function popen_lines(command)
-- find /mnt/testiso1/ -type f -iname vmlinuz -perm +x
    local f = io.popen(command)
    if not f then return {} end

    local ret = {}

    for l in function() return f:read("*line*") end do
        table.insert(ret, l)
    end

    f:close()

    return ret
end

local function find_kernel(path, iso_name)
    local candidates = popen_lines("find "..path.." -type f -iname vmlinuz")

    for _, candidate in ipairs(candidates) do
        if candidate:gmatch("[/]*(vmlinuz)$")() then
            print("Found vmlinuz for ", iso_name)
            return candidate
        end
    end

    for _, candidate in ipairs(candidates) do
        if candidate:gmatch("[/]*(bzImage)$")() then
            print("Found vmlinuz for ", iso_name)
            return candidate
        end
    end

    -- Older Linuxes.
    for _, candidate in ipairs(candidates) do
        if candidate:gmatch("[/]*(linux2[64])$")() then
            print("Found vmlinuz for ", iso_name)
            return candidate
        end
    end

    print("Could not find a kernel for", iso_name)
end

local function find_initrd(path, iso_name)
    local candidates = popen_lines("find "..path.." -type f -iname 'initrd.*'")

    for _, candidate in ipairs(candidates) do
        if candidate:gmatch("[/]*(initrd[.].+)$")() then
            return candidate
        end
    end

    print("Could not find an initrd for", iso_name)
end

local function generate_entry(name, path)
    local f = io.open("/ISO/"..name..".lua")

    -- First, check if there's a script for this ISO. There is no generic way
    -- to load them beside full chainloading with grub and NFS. HTTP doesn't
    -- "really" have random access beside programatic "chunks" over multiple
    -- requests, but it isn't standard. To mitigate this, support loading
    -- scripts for the ISO name. The script must return the syslinux entry. It
    -- is a script because it might have to bind mount some directories to work
    -- and other workaround for chainloading other syslinux or grub2 bootloaders
    if f then
        f:close()
        print("Loading script for", name)
        local ret = loadfile("/ISO/"..name..".lua")(name, "192.168.100.1", lease).."\n\n" --TODO lease
        print("Loaded script for", name)
        return ret
    end

    local kernel, init = find_kernel(path, name), find_initrd(path, name)

    if (not kernel) or (not init) then return "" end

    local relpath = path:gmatch("/tftp(.*)")()

    --FIXME get the IP from the config
    return table.concat {
        "LABEL ",path,"\n",
        "kernel ", find_kernel(path), "\n",
        "append ", find_initrd(path), " boot=casper netboot=tftp://192.168.100.1",relpath,
        "\n\n"
    }
end

local nodcounter, mount_points, nodes = 8, {}, {}

local function mount_iso()
    local isos = popen_lines("ls "..(os.getenv("ISO_PATH") or "/ISO/").."*.iso")
    --FIXME do not hardcode

    if not isos then return end

    os.execute("mkdir /tftp/iso/ -p")

    local config = ""

    for _, file in ipairs(isos) do
        local filename  = file:gmatch("[/]*([^/]*)$")()
        local mountname = filename:gsub("[-\\\\/.]", "")

        os.execute("mkdir -p /tftp/iso/"..mountname)

        -- Docker containers cannot use /dev/loop0 to /dev/loop7, make more
        os.execute("mknod -m 0660 /dev/loop"..nodcounter.." b 7 "..nodcounter)

        -- Make sure mount will pick a loop device that works.
        os.execute("losetup /dev/loop"..nodcounter.." /ISO/"..filename)

        -- Now mount the ISO.
        os.execute("mount -o loop,ro /ISO/"..filename.." /tftp/iso/"..mountname)

        -- Add the device to the syslinus menu.
        config = config .. generate_entry(filename, "/tftp/iso/"..mountname)
        table.insert(mount_points, "/tftp/iso/"..mountname)
        table.insert(nodes, "/dev/loop"..nodcounter)
        nodcounter = nodcounter + 1
    end

    os.execute("mkdir -p /tftp/pxelinux.cfg/")

    local f = io.open("/tftp/pxelinux.cfg/default", "w")
    f:write(header..config)
    f:close()
end

-- Startup.
router.session.connect_signal("init", mount_iso)

-- Cleanup.
router.session.connect_signal("shutdown", function()
    print("Cleaning up iso mount points")
    for _, mp in ipairs(mount_points) do
        os.execute("umount "..mp)
    end
    for _, n in ipairs(nodes) do
        os.execute("losetup -d "..n)
        os.execute("rm "..n)
    end
end)
