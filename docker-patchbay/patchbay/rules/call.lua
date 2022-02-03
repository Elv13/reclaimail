local utils     = require("patchbay.utils")
local object    = require("patchbay.object")
local directory = require("patchbay.directory")
local gmatcher  = require("patchbay.gears.matcher")

local module = {}

local logger = require("patchbay.logging") {
    name = "call_rules"
}

local matcher = gmatcher()

--TODO make request::dialplan::inbound
--TODO make request::dialplan::outbound
-- Use 24h format HHMM numbers to set automatic do-not-disturb settings.
--TODO rule: source_number / caller_id_name
--TODO rule: locality / country
--TODO rule: start/stop time
--TODO rule: Number of consecutive calls from a source (other message about how to reach me) (press 1 to receive email address by SMS)
--TODO rule: When there is zero devices registered
--TODO property: silent -> do not emit call::*/request::* signals
--TODO property preferred_did
--TODO property devices
--TODO action: allow longer ringing delays
--TODO action: Different email subject
--TODO action: email labels
--TODO action: Send to single extension.
--TODO action: Send to single user agent match
--TODO action: Voicemail dialplan
--TODO action: Normal dialplan
--TODO action: transfer
--TODO action: Bridge-in some bots

-- delayed
--  * decline
--  * hangup
--  * answer

-- early
--  * language
--  * did

-- Apply some rules early to allow other callbacks to use them
local early = {
    language = true,
    did      = true,
    country  = true,
    location = true,
}

-- Do those at the end. They are mostly actions, not properties.
local delayed = {
    decline   = true,
    hangup    = true,
    answer    = true,
    record    = true,
    bridge_to = true
}

-- Handled with imperative code.
local ignored = {
}

local special_rules, special_setters = {}, {}

function special_rules.busy(c, value, props, matcher)
    return require("patchbay.session").has_active_call
end

function special_rules.time_interval(c, time_interval, props, matcher)
    --TODO
    return false
end

function special_rules.device_count(c, value, props, matcher)
    local ret = #directory.registered_devices

    return matcher(ret, value)
end

function special_setters.bridge_to(c, value)
    if value.bridge_call then
        value:bridge_call(c)
    else
        for _, dev in ipairs(value) do
            dev:bridge_call(c)
        end
    end
end

for prop, handler in pairs(special_rules) do
    matcher:add_property_matcher(prop, handler)
end

for prop, handler in pairs(special_setters) do
    matcher:add_property_setter(prop, handler)
end

local exec = matcher._execute

-- Override execute to handle early/delayed props
matcher._execute = function(self, c, props, callbacks)
    local early_props, normal_props, delayed_props = {}, {}, {}

    local msg = {"Rules applied for "..c.uuid..":"}

    for prop, value in pairs(props) do
        if early[prop] then
            early_props[prop] = value
        elseif delayed[prop] then
            delayed_props[prop] = value
        elseif not ignored[prop] then
            normal_props[prop] = value
        end
        table.insert(msg, " * " .. prop .. " = " ..tostring(value))
    end

    logger:info(table.concat(msg, "\n"))

    exec(self, c, early_props  , {}       )
    exec(self, c, normal_props , {}       )
    exec(self, c, delayed_props, callbacks)

    -- A dialplan is necessary. If none is present, request one.
    utils.delayed_call(function()
        if c.dialplan then
            logger:info("Using custom dialplan for "..c.uuid)
            c:dialplan()
        elseif not silent then
            c:emit_signal("request::dialplan::"..c.origin)
        end
    end)
end

function module.append_rule(rule)
    return matcher:append_rule("default", rule)
end

function module.append_rules(rules)
    return matcher:append_rules("default", rules)
end

function module.apply(c)
    local known_state = c._private.variables["Channel-Call-State"]

    -- Never allow this, it will cause infinite loops and crash everything.
    if known_state == "HANGUP" then return end

    matcher:apply(c)
end

-- rule to implement
--  * busy
--  * time_interval
--  * device_count
--  * TODO declined (store alternate properties for declined in case they are needed later)
--     * same for missed

--utils.delayed_call(function()
--    module.emit_signal("request::rules")
--end)

matcher:connect_signal("rule::match", function(_, c, rule)
    module.emit_signal("rule::match", c, rule)
end)

return object.patch_table(module, {
    is_module = true,
    class     = module,
})
