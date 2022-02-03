
local module = {}

local devices = {}

local by_extension, by_accountcode = {}, {}

function module.get_devices()
    return devices
end

--- Add a device (SIP account) to FreeSWITCH.
function module.add(device)
    table.insert(devices, device)

    by_extension[tostring(device.extension)] = device
    by_accountcode[tostring(device.accountcode)] = device
end

function module.get_by_extension(ext)
    ext = tostring(ext)
    return by_extension[ext]
end

function module.get_by_accountcode(ac)
    return by_accountcode[tostring(ac)]
end

function module._get_devices()
    return devices
end

return module
