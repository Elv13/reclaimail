--- This class is a container for an incident/outage report.
--
-- These object track when some assets like a gateway goes down,
-- the network has issues or when a call/media cuts.
--
-- An incident is in one of those states:
--
-- * emergent: Some state transition are going the wrong way,
--    but the system is still in retry phase
-- * ongoing: Some assets are not working.
-- * recovering: There is attempt to restore service.
-- * recovered: Time for a post-mortem.
-- * failure: This is the end, nothing can be done to recover
--
-- This class can also be a base class if the `:attempt_recovery()`
-- is implemented.
local object = require("patchbay.object")
local utils  = require("patchbay.utils")

local module, actions = {}, {}

--- The incident severity.
--
-- * DEBUG
-- * INFO
-- * WARN
-- * ERROR
-- * FATAL
--
-- @property severity
-- @tparam string severity

function actions.finish(self, prev)
    self.ended = utils.now()
end

function actions.fail_recovery(self, prev)
    self.ended = utils.now()
end

function actions.announce(self, prev)
    self.began = utils.now()
end

function actions.error(self, prev)
    error()
end

function actions.update(self, prev)
    self.updated = utils.now()
end

function actions.abort(self, prev)
    self.began   = nil
    self.updated = nil
end

local state_actions = {
    EMERGENT   = {EMERGENT = nil          , ONGOING = actions.announce     , RECOVERING = nil           , RECOVERED = actions.abort , FAILURE = actions.finish},
    ONGOING    = {EMERGENT = actions.error, ONGOING = nil                  , RECOVERING = actions.update, RECOVERED = actions.finish, FAILURE = actions.finish},
    RECOVERING = {EMERGENT = actions.error, ONGOING = actions.fail_recovery, RECOVERING = nil           , RECOVERED = actions.finish, FAILURE = actions.finish},
    RECOVERED  = {EMERGENT = actions.error, ONGOING = nil                  , RECOVERING = actions.error , RECOVERED = nil           , FAILURE = actions.error },
    FAILURE    = {EMERGENT = actions.error, ONGOING = actions.error        , RECOVERING = actions.error , RECOVERED = actions.error , FAILURE = nil           },
}

local state_machine = {
    EMERGENT   = {EMERGENT = nil, ONGOING = nil, RECOVERING = nil, RECOVERED = nil, FAILURE = nil},
    ONGOING    = {EMERGENT = nil, ONGOING = nil, RECOVERING = nil, RECOVERED = nil, FAILURE = nil},
    RECOVERING = {EMERGENT = nil, ONGOING = nil, RECOVERING = nil, RECOVERED = nil, FAILURE = nil},
    RECOVERED  = {EMERGENT = nil, ONGOING = nil, RECOVERING = nil, RECOVERED = nil, FAILURE = nil},
    FAILURE    = {EMERGENT = nil, ONGOING = nil, RECOVERING = nil, RECOVERED = nil, FAILURE = nil},
}

local function change_state(self, new_state)
    assert(new_state)
    local old_state = self.state
    self._private.state = new_state
    state_actions[old_state][new_state](self, old_state)
    self:emit_signal("property::state", new_state, old_state)
end

--- When it stated.
-- @property began

--- When it stopped.
-- @property ended

--- When it was updated.
-- @property updated

--- The human readable summary.
-- @property summary
-- @tparam string

--TODO root_cause (parent) incident object

--TODO children incident (network->gateway->call)

function module:confirm_recovery()
    --TODO get end time
    change_state(self, "RECOVERED")
end

function module:failed_recovery()
    --TODO get time
    change_state(self, "ONGOING")
end

function module:confirm_outage()
    --TODO get time
    change_state(self, "ONGOING")
end

function module:confirm_failure()
    self.ended = utils.now()
    change_state(self, "FAILURE")
end

function module:confirm_update()
    --TODO get time
end

function module:get_duration()
    if not self.began then return "N/A" end

    local start, stop = self.began, self.ended or utils.now()

    local diff = stop - start

    local ret = ""

    if diff > 3600 then
        ret = math.floor(diff/3600) .. "h "
        diff = diff % 3600
    end

    if diff > 60 then
        ret = ret .. math.floor(diff/60) .. "m "
        diff = diff % 60
    end

    ret = ret .. math.ceil(diff) .. "s"

    return ret
end

local function new(_, args)
    assert(args and args.type)
    local ret = object {
        class = module,
    }

    ret.severity = args.severity or "WARN"
    ret.type = args.type
    ret.state = "EMERGENT"
    assert(ret.state == "EMERGENT")

    require("patchbay.outage")._register_incident(ret)

    return ret
end

return object.patch_table(module, {
    call      = new,
    is_module = true,
})
