local patchbay = require("patchbay")

local module = {}

local function create_asset_class(name)
    local ret = {_paths = {}}

    function ret.append_paths(paths)
        for _, path in ipairs(paths) do
            table.insert(ret._paths, path)
        end
    end

    function ret.append_path(path)
        table.insert(ret._paths, path)
    end

    function ret.get_first_path()
        return ret._paths[1]
    end

    function ret.get(file)
        for _, path in ipairs(ret._paths) do
            path = path.."/"..file
            local f = patchbay.utils.file_or_nil(path)

            if f then return path end
        end
    end

    return ret
end

module.recordings         = create_asset_class("recordings")
module.voicemails         = create_asset_class("voicemails")
module.voicemail_messages = create_asset_class("voicemail_messages")
module.ringtones          = create_asset_class("ringtones")
module.sms                = create_asset_class("sms")

return module
