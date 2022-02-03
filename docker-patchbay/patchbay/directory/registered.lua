local rest = require("rest")
local sip_accounts = require("patchbay.directory.sip_accounts")

local COMMAND = "sofia status profile internal reg"

local module = {}

function module.get_registered_devices()
    local result = rest.plain_text_command(COMMAND)

    local devs = {}

    -- Parse the plain text (this command does not have a XML or JSon mode yet)
    for line in result:gmatch("([^\n]*)") do
        local k, v = line:match("^([^:]+):[ \t]*(.*)")

        if k == "User" then
            local ext = v:match("^([^@]+)")

            local dev = sip_accounts.get_by_extension(ext)

            if dev then
                table.insert(devs, dev)
            end
        end
    end

    return devs
end

return module
