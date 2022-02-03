local object      = require("patchbay.object")
local transaction = require("patchbay._transaction")
local assets      = require("patchbay.assets")
local utils       = require("patchbay.utils")

--TODO implement all the knobs https://freeswitch.org/confluence/display/FREESWITCH/mod_dptools%3A+record_session

local module = {}

local logger = require("patchbay.logging") {
    name = "recording"
}

local function download(self)
    --TODO spawn some luascript to fetch the file over REST
    --when the script finish, notice over the lzmq api
    print("\nDOWNLOAD ", self._private.call.uuid, self._private.path)

    self._private.stopped_ts = utils.now()
    self:emit_signal("finished")
end

--- The call object associated with this recording.
-- @property call
-- @tparam patchbay.call call

--- The recording filename.
--
-- By default, it is the `<call_hangup_timestamp>.wav`
--
-- @property filename
-- @tparam string

function module:get_filename()
    if self._private.filename then return self._private.filename end

    self._private.filename = self._private.call.creation_timestamp .. ".wav"

    return self._private.filename
end

--- The recording path.
-- @property path
-- @tparam string

function module:get_path()
    if self._private.path then return self._private.path end


    local dir

    --FIXME The FreeSWITCH path and the patchbay paths are
    --      not living on the same filesystem.
    --[[if self._private.type == "voicemail" then
        dir = assets.voicemails.get_first_path()
    else
        dir = assets.recordings.get_first_path()
    end]]

    dir = "/tmp"

    assert(dir)

    self._private.path = dir .. "/" .. self.filename

    return self._private.path
end

function module:set_path(path)
    --TODO move the files
    self._private.path     = path
    self._private.filename = path:match("([^/]+)$")
end

--- The recording type.
--
-- The recording will be stored in different places depending
-- on the type.
--
-- Valid types are:
--
-- * voicemail
-- * session
--
-- @property type
-- @tparam string

--TODO handle both legs of the call as separate recordings objects

--- Delete the recording.
-- @method delete

function module:delete()
    --TODO
end

--- When the recording started.
--
-- @property started_ts
-- @tparam number started_ts Microsecond timestamp

--- When the recording started.
--
-- @property started_ts
-- @tparam number stopped_ts Microsecond timestamp

--- Duration (in seconds).
--
-- @property duration
-- @tparam number duration In seconds (floating point).

function module:get_duration()
    if not self._private.started_ts then return 0 end

    local stop_ts = self._private.stopped_ts or utils.now()
    local diff = stop_ts - self._private.started_ts

    return diff / 1000000.0
end

function module:start()
    local state = self._private.call._private.variables["Channel-Call-State"]

    assert(state ~= "HANGUP", "Trying to record an hung-up call")

    self._private.started_ts = utils.now()

    if self._private.type == "voicemail" then
        transaction.async_session_call(
            self._private.call,
            "recordFile",
            self.path,
            self._private.max_len_secs,
            self._private.silence_threshold,
            self._private.silence_secs
        )
        logger:warn(table.concat({
            "Starting to record session " .. self._private.call.uuid .. ":",
            " * path = " .. tostring(self.path),
            " * max_len_secs = " .. tostring(self._private.max_len_secs),
            " * silence_threshold = " .. tostring(self._private.silence_threshold),
            " * silence_secs = " .. tostring(self._private.silence_secs)
        }, "\n"))
    else
        transaction.async_session_call(
            self._private.call,
            "execute",
            "record_session",
            self.path
        )

        logger:info("Starting to record A/B legs of " .. self._private.call.uuid .. " to "..tostring(self.path))
    end
end

function module:stop()
    self._private.stopped_ts = utils.now()

    transaction.async_session_call(
        self._private.call,
        "execute",
        "stop_record_session",
        self._private.path
    )

    download(self)
end

local function new(_, args)
    assert(args and args.type and args.call)

    local ret = object {
        class = module
    }

    object.shallow_copy(ret._private, args)

    assert(ret._private.call)

    args.call:connect_signal("state::hangup", function() download(ret) end)

    return ret
end

return object.patch_table(module, {
    call      = new,
    class     = module,
    is_module = true,
})
