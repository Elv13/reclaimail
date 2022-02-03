--- This module track the calls state machine.
--
-- The call can be active or finished. However, this class
-- does not track calls from previous sessions.
--
local object = require("patchbay.object")
local directory = require("patchbay.directory")
local transaction = require("patchbay._transaction")
local json = require("json")
local utils = require("patchbay.utils")
local libphonenumber = require("luaphonenumber")

local module = {}

local logger = require("patchbay.logging") {
    name = "call"
}

local state_names = {
    "ACTIVE",
    "RINGING",
    "DOWN",
    "EARLY",
    "HANGUP",
    "DIALING",
    "HELD",
    "RING_WAIT",
    "UNHELD"
}

-- Paused coroutines waiting for a state change.
local blockers = {
    HANGUP = {}
}

local function get_extension(self)
    local chan = self._private.variables["Channel-Name"]

    local ext = chan:match("sofia/internal/(.*)")

    return directory.sip_accounts.get_by_extension(ext)
end

--- Get the phonenumber country.
--
-- This is a 2 letter code, not the full country name.
--
-- @property country
-- @tparam string
-- @see bias_country
-- @see location

function module:get_country()
    if self._private.country then return self._private.country end

    if self._private.probable_country then return self._private.probable_country end

    self._private.probable_country = libphonenumber.get_country(
        self.peer_number,
        self.bias_country or "US"
    )

    return self._private.probable_country
end

--- Get the phonenumber location.
--
-- This an educated guess `libphonenumber` takes. For some countries,
-- numbers have area codes. But note that a lot of this is rather
-- historical in the age of mobile phones. Aeons ago, the houses/apartments
-- had a phone number (literally) hardwired to them. The location of a phone
-- was very predictable down to the neighbourhood. Nowaday, you can relocate
-- to a different continent and keep your old phone number (toll may apply).
--
-- Phone numbers are also used for 2 factor auth, so changing it is not only
-- a pain, but a security risk.
--
-- So, this property returns something, but don't trust it too much.
--
-- @property location
-- @tparam string

function module:get_location()
    if self._private.probable_location then return self._private.probable_location end

    self._private.probable_location = libphonenumber.get_location(
        self.peer_number,
        self.bias_country or "US",
        "en",
        "US"
    )

    return self._private.probable_location
end

--- Get/Set the bias country.
--
-- The is the 2 letter country code (like US/CA/BG/FR) used to
-- guide the phone number parser toward a correct result. For
-- example, some country allow shorter phone number (at least
-- down to 7 digit, maybe less) for local numbers. By setting
-- this, there is still "hope" it gets parsed property.
--
-- @property bias_country
-- @property string

--- Get the dialplan for this call.
--
-- This is a function which will be called instead of requesting
-- a dialplan using `request::dialplan::internal`/`request::dialplan::external`/
-- `request::dialplan::bridge`.
--
-- It gives fine grained control over what happens. For example, it
-- can be used to implement bots extension (ie, to record new voicemails
-- or set some global variables).
--
-- @property dialplan
-- @tparam nil|function

--- Request an outgoing dialplan for a call.
-- @signal request::dialplan::internal

--- Request an incoming dialplan for a call.
-- @signal request::dialplan::external

--- Request an bridged dialplan for a call.
-- @signal request::dialplan::bridge

--- Play a voicemail.
-- @signal request::voicemail

--- Set a voicemail message.
-- @property voicemail
-- @tparam string voicemail A file path.

function module:decline()
    self:emit_signal("request::voicemail")
end

--- Get the call DID object.
--
-- This is the "self" phone number of the call.
-- @property did
-- @tparam patchbay.did

function module:get_did()
    if self._private.did then return self._private.did end

    local origin = self.origin

    -- Use the dialplan to know where the call originates. It has
    -- less corner case than dealing with the sibling tree.
    if origin == "internal" then
        return nil
    elseif origin == "external" then
        self._private.did = directory._get_did(
            self._private.variables["Caller-Destination-Number"]
        )
        assert(self._private.did)
    else
        for _, sibling in ipairs(self.bridged_siblings) do
            if self._private.variables.dialplan == "public" then
                self._private.did = directory._get_did(
                    self._private.variables["Caller-Destination-Number"]
                )
            end
        end
    end

    return self._private.did
end

--- The current device object attached to this call.
--
-- This can be directly or via a bridge. It may change over time.
--
-- @property current_device
-- @tparam string

function module:get_current_device()
    if self._private.device then return self._private.device end

    if self._private.variables.dialplan == "default" then
        self._private.device = get_extension(self)
    else
        for _, sibling in ipairs(self.bridged_siblings) do
            if sibling._private.variables.dialplan == "default" then
                self._private.device = get_extension(sibling)
            end
        end
    end

    return self._private.device
end

--- The call context.
--
-- `local` or `public`
--
-- @property context
-- @tparam string

function module:get_context()
    -- It could use `Caller-Context` too
    return self._private.variables.dialplan == "public" and "public" or "local"
end

--- The call spoken language.
--
-- For example: "en" or "fr". This is used when calling `say` and
-- other TTS methods.
--
-- @property language
-- @tparam string language
-- @see did.language

function module:set_language(value)
    self._private.language = value
end

function module:get_language()
    --TODO use libphonenumber
    return self._private.language or "en"
end

--- The call direction (outbound or inbound).
-- @property direction
-- @tparam string

function module:get_direction()
    return self._private.variables["Caller-Direction"]
end

--- The call origin.
--
-- Either "internal", "external" or "bridge"
-- @property origin
-- @tparam string

function module:get_origin()
    if self._private.origin then return self._private.origin end

    local vars = self._private.variables
    local dp   = vars.dialplan or vars["Caller-Context"]
    local dir  = self.direction

    assert(dp and dir, "Missed critical metadata " .. tostring(dp) .." "..tostring(dir))

    if dp == "public" and dir == "inbound" then
        self._private.origin = "external"
    elseif  dp == "default" and dir == "inbound" then
        self._private.origin = "internal"
    else
        self._private.origin = "bridge"
    end

    assert(self._private.origin)

    return self._private.origin
end

--- Get the peer phone number.
--
-- For inbound call, this is whatever is in the caller_id. Note
-- that caller ids are rather unreliable. For outbound calls,
-- this is the number you are calling
--
-- @property peer_phone_number
-- @tparam string

function module:get_peer_number()
    if self._private.peer_number then return self._private.peer_number end

    if self.origin == "internal" then
        self._private.peer_number = self._private.variables["Caller-Destination-Number"]
    else
        self._private.peer_number = self.caller_id_number
    end

    assert(self._private.peer_number, "ORIGIN: " .. self.origin .. " br: "..#self.bridged_siblings)

    return self._private.peer_number
end

--- Get "your" phone number.
--
-- One leg is the call is the peer, that number is `peer_number`. This
-- property returns the other leg. This property works across both
-- bridges ends.
--
-- @property did_number
-- @tparam string

function module:get_did_number()
    local origin = self.origin

    if origin == "external" then
        return self.did.phone_number
    elseif origin == "internal" then
        return "????"--self._private.variables["Caller-Destination-Number"]
    elseif origin == "bridge" then
        for _, bridge in ipairs(self.bridged_siblings) do
            if bridge.did then
                return bridge.did.phone_number
            end
        end
    end

    -- This is a bug
    --print("\nCALL", self.direction, self.origin, #self.bridged_siblings)
    -- error() --TODO ???
    return "???"
end

-- Get the caller_id.
--
-- This isn't always possible to get. Some numbers are
-- private/annoymous. Some SIP registrar don't give this to you
-- unless you pay an extra fee.
--
-- @property caller_id_number
-- @tparam string

function module:get_caller_id_number()
    return self._private.variables["Caller-Caller-ID-Number"]
        or self._private.variables["Caller-Orig-Caller-ID-Number"]
end

--- The caller id name.
-- @property caller_id_name
-- @tparam string

function module:get_caller_id_name()
    return self._private.variables["Caller-Caller-ID-Name"]
        or self._private.variables["Caller-Orig-Caller-ID-Name"]
end

--- The caller destination number.
-- @property destination_number
-- @tparam string

function module:get_destination_number()
    return self._private.variables["Caller-Destination-Number"]
end

--- The call UUID.
--
-- This is how FreeSWITCH identify calls.
--
-- @property uuid
-- @tparam string

function module:get_uuid()
    return self._private.variables["Unique-ID"]
end

function module:bridge_calls(other_call)
    --TODO
    error("Not implemented")
end

--function module:bridge_device()
    --
--end

function module:hangup(reason)
    if self._private.variables["Channel-Call-State"] == "HANGUP" then
        return
    end

    transaction.async_session_call(self, "hangup", reason)
end

--- Transfer the call.
--
-- This is semi-unatended transfer. The call will end and a new
-- one will be created. Bridging might be the better option.
--
-- @method transfer

function module:transfer(device)
    local ext = type(device) == "string" and device or device.extension
    transaction.async_session_call(self, "transfer", ext, "XML", "transfer")
end

function module:answer()
    transaction.async_session_call(self, "answer")
end

function module:speak(message)
    --transaction.async_session_call(self, "set_tts_param", "flite", "kal")
    transaction.async_session_call(self, "speak", message)
end

function module:get_is_ready()
    return transaction.async_session_call(self, "ready")
end

function module:get_is_answered()
    return transaction.async_session_call(self, "answered")
end

function module:get_is_bridged()
    return transaction.async_session_call(self, "bridged")
end

function module:get_are_media_ready()
    return transaction.async_session_call(self, "mediaReady")
end

function module:wait_until_ready()
    while not transaction.async_session_call(self, "ready") do
        transaction.async_freeswitch_call("msleep", 500)

        -- Otherwise, it will be infinite
        if self._private.variables["Channel-Call-State"] == "HANGUP" then
            return false
        end
    end

    return true
end

function module:wait_until_answered()
    while not transaction.async_session_call(self, "answered") do
        transaction.async_freeswitch_call("msleep", 100)

        -- Otherwise, it will be infinite
        if self._private.variables["Channel-Call-State"] == "HANGUP" then
            return false
        end
    end

    return true
end

function module:wait_until_media()
    while not transaction.async_session_call(self, "mediaReady") do
        transaction.async_freeswitch_call("msleep", 100)

        -- Otherwise, it will be infinite
        if self._private.variables["Channel-Call-State"] == "HANGUP" then
            return false
        end
    end

    return true
end

function module:wait_until_answer()
    transaction.async_session_call(self, "waitForAnswer")

    return self._private.variables["Channel-Call-State"] ~= "HANGUP"
end

function module:sleep(ms)
    transaction.async_session_call(self, "sleep", ms)
end


---.
-- @method wait_until_active

---.
-- @method wait_until_ringing

---.
-- @method wait_until_down

---.
-- @method wait_until_early

---.
-- @method wait_until_hangup

---.
-- @method wait_until_dialing

---.
-- @method wait_until_held

---.
-- @method wait_until_ring_wait

---.
-- @method wait_until_unheld


for _, state_name in ipairs(state_names) do
    module["wait_until_"..state_name:lower()] = function(self)
        blockers[state_name] = blockers[state_name] or {}

        blockers[state_name][self] = blockers[state_name][self]
            or setmetatable({}, {__mode="v"})

        local co = coroutine.running()
        assert(co, "`wait_until_*` methods can only be called in a coroutine")

        table.insert(blockers[state_name][self], co)

        coroutine.yield(co)

        for k, co2 in ipairs(blockers[state_name][self] or {}) do
            if co2 == co then
                table.remove(blockers[state_name][self], k)
                break
            end
        end

        local state = self._private.variables["Channel-Call-State"]

        -- Return `false` when the call ended before the state change.
        return state ~= "HANGUP" or state_name == "HANGUP"
    end
end

function module:say(message, say_type, say_method)
    say_type = say_type or "number"
    say_method = say_method or "pronounced"
    return transaction.async_session_call(
        self,
        "say",
        self.language,
        say_type,
        say_method
    )
end

function module:stream_file(path, sample_count)
    local state = self._private.variables["Channel-Call-State"]

    assert(state ~= "HANGUP", "Caanot stream to an hung-up call")

    transaction.async_session_call(self, "streamFile", path)
end

function module:play_file(path)
    transaction.async_api_call("executeString", "uuid_broadcast "..self.uuid.." "..path.." aleg")
end

function module:get_hangup_timestamp()
    return self._private.hangup_ts
end

function module:get_creation_timestamp()
    return self._private.create_ts
end

--- Auto hangup the call when the dialplan finishes.
-- @property auto_hangup
-- @tparam boolean auto_hangup_after_dialplan

function module:set_auto_hangup_after_dialplan(value)
    transaction.async_session_call(self, "setAutoHangup", false)
end

function module:_add_bridged_sibling(other_c)
    for _, bridge in ipairs(self._private.siblings) do
        if bridge == other_c then return end
    end

    table.insert(self._private.siblings, other_c)
end

function module:get_bridged_siblings()
    return self._private.siblings
end

--- Auto hangup when the second to last bridged peer hangup.
-- @property auto_hangup_after_bridge
-- @tparam boolean auto_hangup_after_bridge

local function get_session_variable(self, variable)

end

local function set_session_variable_sync(self, variable, value)
    transaction.sync_session_call(self, "setVariable", variable, tostring(value))
end

local function set_session_variable_async(self, variable, value)
    transaction.async_session_call(self, "setVariable", variable, tostring(value))
end

function module:set_auto_hangup_after_bridge(value)
    transaction.async_session_call(self, "setAutoHangup", false)
end

--- Why the call ended.
--
-- @property hangup_cause
-- @tparam string hangup_cause

function module:get_hangup_cause()
    -- Once it is known, it never changes.
    if self._private.hangup_cause then return self._private.hangup_cause end

    local is_hangup = self._private.variables["Channel-Call-State"] == "HANGUP"

    -- It is too late to query the API, but we should already have the
    -- cause. However there is a race condition if the event is still queued.
    if is_hangup and self._private.variables["Hangup-Cause"] then
        self._private.hangup_cause = self._private.variables["Hangup-Cause"]
        return self._private.hangup_cause
    end

    local ret = transaction.async_session_call(self, "hangupCause")

    if self._private.variables["Channel-Call-State"] == "HANGUP" then
        self._private.hangup_cause = ret
    end

    return ret
end

--- The call state.
--
-- * ACTIVE
-- * RINGING
-- * DOWN
-- * EARLY
-- * HANGUP
-- * DIALING
-- * HELD
-- * RING_WAIT
-- * UNHELD
--
-- @property state
-- @tparam string

function module:get_state()
    -- While self._private.variables["Channel-Call-State"] is
    -- supposed to have it, there might be some pending events
    -- to update it. Going async will process them, but while
    -- at it, better call getState directly. It won't be any
    -- slower.

    -- Don't query FreeSWITCH, this call cannot have changed.
    if self._private.variables["Channel-Call-State"] == "HANGUP" then
        return "HANGUP"
    end

    --local ret = transaction.async_session_call(self, "getVariable", "Channel-Call-State")
    local ret = transaction.async_api_call("executeString",
        'eval uuid:' .. self.uuid .. ' ${Channel-Call-State}')

    return ret
end

-- Block the dialplan *before* any signal is sent to patchbay.
-- In theory, all of those variables are set before anything
-- is done.
local defaults = {
    incoming            = {},
    outgoing            = {},
    incoming_serialized = nil,
    outgoing_serialized = nil,
}

module.default_incoming_parameters = setmetatable({}, {
    __index = function(_, key)
        return defaults.incoming[key]
    end,
    __newindex = function(_, key, value)
        defaults.incoming_serialized = nil
        defaults.incoming[key] = value
    end
})

module.default_outgoing_parameters = setmetatable({}, {
    __index = function(_, key)
        return defaults.outgoing[key]
    end,
    __newindex = function(_, key, value)
        defaults.outgoing_serialized = nil
        defaults.outgoing[key] = value
    end
})

function module._get_default_variables(outgoing)
    if outgoing then
        if not defaults.outgoing_serialized then
            defaults.outgoing_serialized = json.encode(defaults.outgoing)
        end

        return defaults.outgoing_serialized
    else
        if not defaults.incoming_serialized then
            defaults.incoming_serialized = json.encode (defaults.incoming)
        end

        return defaults.incoming_serialized
    end
end

local actions = {}

function actions.hangup(c, prev)
    c._private.hangup_ts = c._private.variables['Event-Date-Timestamp']

    c:emit_signal("finished")
end

function actions.missed(c, prev)
    actions.hangup(c, prev)
    c:emit_signal("missed")
end

function actions.pickup(c, prev)
end

-- Vertical = previous, horizontal = current
local state_matrix = {
    ACTIVE    = {ACTIVE = nil           , RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = actions.hangup,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    RINGING   = {ACTIVE = actions.pickup, RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = actions.missed,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    DOWN      = {ACTIVE = nil           , RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = nil           ,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    EARLY     = {ACTIVE = nil           , RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = actions.missed,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    HANGUP    = {ACTIVE = nil           , RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = nil           ,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    DIALING   = {ACTIVE = nil           , RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = nil           ,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    HELD      = {ACTIVE = nil           , RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = actions.hangup,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    RING_WAIT = {ACTIVE = nil           , RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = actions.hangup,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
    UNHELD    = {ACTIVE = actions.pickup, RINGING = nil, DOWN = nil,  EARLY = nil,  HANGUP = actions.hangup,  DIALING = nil,  HELD = nil,   RING_WAIT = nil, UNHELD = nil},
}

function module:_update_variables(new_vars)
    -- Not all variables are sent in each CHANNEL_CALLSTATE events.
    -- A full copy is needed

    self._private.create_ts = self._private.create_ts or new_vars['Event-Date-Timestamp']

    local old_state = new_vars["Original-Channel-Call-State"] or self._private.variables["Channel-Call-State"] or "EARLY"
    local new_state = new_vars["Channel-Call-State"]

    object.shallow_copy(self._private.variables, new_vars)

    -- print("STATE CHANGE", old_state, "'"..tostring(new_state).."'", state_matrix[old_state] ,   state_matrix[old_state] and state_matrix[old_state][new_state] or "-1")

    -- Execute the state machine.
    if old_state and new_state then
        local f = state_matrix[old_state] and state_matrix[old_state][new_state]

        if f then
            f(self)
        end

        self:emit_signal("property::state", old_state, new_state)
        logger:info("Call ".. self.uuid .. " State changed from "..old_state.." to "..new_state)
        self:emit_signal("state::"..new_state:lower(), old_state)
    end

    -- Wakeup the waiters.
    if blockers[new_state] and blockers[new_state][self] and #blockers[new_state][self] > 0 then
        utils.delayed_call(function()
            for _, co in ipairs(blockers[new_state][self]) do
                transaction.xpcall_resume(co)
            end
        end)
    end

    -- Release the locks on all remaining coroutines.
    if new_state == "HANGUP" then
        local routines = {}

        for state, calls in pairs(blockers) do
            for call, cos in pairs(calls) do
                for _, co in ipairs(cos) do
                    table.insert(routines, co)
                end
            end
        end

        for _, routine in ipairs(routines) do
            transaction.xpcall_resume(routine)
        end
    end
end

local function new(_, args)
    local ret = object{
        class = module
    }

    ret._private.siblings  = {}
    ret._private.variables = {}

    module._update_variables(ret, args)

    return ret
end

return object.patch_table(module, {
    class     = module,
    is_module = true,
    call      = new
})
